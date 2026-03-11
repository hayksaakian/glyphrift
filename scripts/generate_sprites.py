#!/usr/bin/env python3
"""Generate glyph sprite images using Gemini 3 Pro.

Usage:
    python3 scripts/generate_sprites.py <species_id> [--candidates N] [--raw-dir DIR]
    python3 scripts/generate_sprites.py --list

Reads prompts from docs/glyph-sprite-prompts.md and API key from .env file.
Saves raw output to raw/ directory (or --raw-dir). Generate multiple candidates
with --candidates N for human review.

After generating, run scripts/process_sprites.sh to convert to game-ready assets.
"""

import argparse
import base64
import os
import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
PROMPTS_FILE = PROJECT_DIR / "docs" / "glyph-sprite-prompts.md"
ENV_FILE = PROJECT_DIR / ".env"
DEFAULT_RAW_DIR = PROJECT_DIR / "raw"

MODEL = "gemini-3-pro-image-preview"


def load_api_key() -> str:
    """Load GEMINI_API_KEY from .env file."""
    if not ENV_FILE.exists():
        print(f"ERROR: {ENV_FILE} not found. Create it with GEMINI_API_KEY=your_key")
        sys.exit(1)
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if line.startswith("GEMINI_API_KEY="):
            return line.split("=", 1)[1].strip()
    print("ERROR: GEMINI_API_KEY not found in .env")
    sys.exit(1)


def parse_prompts() -> dict[str, str]:
    """Parse species prompts from the markdown file.

    Returns dict mapping species_id (lowercase) -> full prompt text.
    """
    if not PROMPTS_FILE.exists():
        print(f"ERROR: {PROMPTS_FILE} not found")
        sys.exit(1)

    text = PROMPTS_FILE.read_text()
    prompts = {}

    # Match sections like "### 1. Zapplet" followed by blockquoted text
    pattern = r"###\s+\d+\.\s+(\w+)\s*\n(.*?)(?=\n---|\n##|\Z)"
    for match in re.finditer(pattern, text, re.DOTALL):
        name = match.group(1).strip().lower()
        body = match.group(2).strip()
        # Extract blockquote content (lines starting with >)
        prompt_lines = []
        for line in body.splitlines():
            line = line.strip()
            if line.startswith(">"):
                prompt_lines.append(line.lstrip("> ").strip())
            elif prompt_lines and line == "":
                prompt_lines.append("")
        prompt = "\n".join(prompt_lines).strip()
        if prompt:
            prompts[name] = prompt

    return prompts


def generate_image(api_key: str, prompt: str) -> bytes | None:
    """Call Gemini API to generate an image. Returns PNG bytes or None."""
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        print("ERROR: google-genai not installed. Run: pip3 install google-genai")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
            ),
        )
    except Exception as e:
        print(f"  API error: {e}")
        return None

    # Extract image from response
    if not response.candidates:
        print("  No candidates in response")
        return None

    for part in response.candidates[0].content.parts:
        if part.inline_data and part.inline_data.mime_type.startswith("image/"):
            return part.inline_data.data

    print("  No image in response (text only)")
    if response.candidates[0].content.parts:
        for part in response.candidates[0].content.parts:
            if part.text:
                print(f"  Response text: {part.text[:200]}")
    return None


def main():
    parser = argparse.ArgumentParser(description="Generate glyph sprites via Gemini")
    parser.add_argument("species", nargs="?", help="Species ID to generate (e.g. gritstone)")
    parser.add_argument("--list", action="store_true", help="List available species prompts")
    parser.add_argument("--candidates", type=int, default=1, help="Number of candidates to generate (default: 1)")
    parser.add_argument("--raw-dir", type=str, default=str(DEFAULT_RAW_DIR), help="Output directory for raw images")
    parser.add_argument("--all-missing", action="store_true", help="Generate all species that don't have raw images yet")
    args = parser.parse_args()

    prompts = parse_prompts()

    if args.list:
        print(f"Available species ({len(prompts)}):")
        for name in sorted(prompts.keys()):
            raw_path = Path(args.raw_dir) / f"{name}.png"
            status = "  [exists]" if raw_path.exists() else ""
            print(f"  {name}{status}")
        return

    if args.all_missing:
        raw_dir = Path(args.raw_dir)
        raw_dir.mkdir(parents=True, exist_ok=True)
        missing = [name for name in sorted(prompts.keys()) if not (raw_dir / f"{name}.png").exists()]
        if not missing:
            print("All species already have raw images!")
            return
        print(f"Generating {len(missing)} missing species: {', '.join(missing)}")
        api_key = load_api_key()
        for species_id in missing:
            print(f"\n{'=' * 50}")
            print(f"Generating: {species_id}")
            print(f"{'=' * 50}")
            _generate_species(api_key, species_id, prompts[species_id], raw_dir, 1)
        return

    if not args.species:
        parser.print_help()
        return

    species_id = args.species.lower()
    if species_id not in prompts:
        print(f"ERROR: No prompt found for '{species_id}'")
        print(f"Available: {', '.join(sorted(prompts.keys()))}")
        sys.exit(1)

    raw_dir = Path(args.raw_dir)
    raw_dir.mkdir(parents=True, exist_ok=True)

    api_key = load_api_key()
    _generate_species(api_key, species_id, prompts[species_id], raw_dir, args.candidates)


def _generate_species(api_key: str, species_id: str, prompt: str, raw_dir: Path, candidates: int):
    """Generate one or more candidates for a species."""
    for i in range(candidates):
        suffix = f"_v{i + 1}" if candidates > 1 else ""
        out_path = raw_dir / f"{species_id}{suffix}.png"

        label = f"  candidate {i + 1}/{candidates}" if candidates > 1 else f"  generating..."
        print(label)

        image_data = generate_image(api_key, prompt)
        if image_data is None:
            print(f"  FAILED — no image returned")
            continue

        out_path.write_bytes(image_data)
        size_kb = len(image_data) / 1024
        print(f"  saved: {out_path} ({size_kb:.0f} KB)")

    print(f"\nDone. Run ./scripts/process_sprites.sh {raw_dir} to process into game assets.")


if __name__ == "__main__":
    main()
