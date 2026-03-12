#!/usr/bin/env python3
"""Generate NPC portrait images using Gemini.

Usage:
    python3 scripts/generate_npc_portraits.py kael
    python3 scripts/generate_npc_portraits.py --all
    python3 scripts/generate_npc_portraits.py --list

Reads NPC design from inline prompts and API key from .env file.
Saves raw output to raw/npcs/ directory.
After generating, run scripts/process_npc_portraits.sh to convert to game-ready assets.
"""

import argparse
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_DIR / ".env"
DEFAULT_RAW_DIR = PROJECT_DIR / "raw" / "npcs"

MODEL = "gemini-3-pro-image-preview"

STYLE_BLOCK = (
    "Clean vector/cartoon style. Bold black outlines, flat color fills. "
    "No gradients, no soft brushwork, no painterly texture. Limited color palette. "
    "The design should be simple enough to read clearly when scaled down to 48x48 pixels. "
    "512x512 image. Half-body portrait (head, shoulders, upper torso), facing slightly "
    "right in a 3/4 view. Character should fill roughly 80% of the canvas, centered, "
    "with even padding on all sides. Solid magenta (#FF00FF) background. "
    "No ground shadow, no environment, no effects, no text, no UI elements, no watermarks."
)

NPC_PROMPTS = {
    "kael": (
        'Half-body portrait of a grizzled fantasy soldier called "Kael" for a 2D RPG. '
        "Veteran Warden — a seasoned monster-tamer and combat instructor. "
        "Weathered face, scar across left eyebrow, short dark hair greying at temples. "
        "Wears a deep red warden's cloak over dark plate armor. "
        "Arms crossed, steady confident expression — tough but fair. Mid-40s human male.\n\n"
        f"Style rules: {STYLE_BLOCK}"
    ),
    "lira": (
        'Half-body portrait of a young fantasy scientist called "Lira" for a 2D RPG. '
        "Rift Researcher — studies the creatures and dimensional rifts. "
        "Bright curious eyes behind round glasses, dark hair in a messy bun with a "
        "pencil in it. Wears a white researcher's coat with teal trim and glowing "
        "rift-energy patterns on the collar. Holding a glowing tablet, leaning forward "
        "with eager expression. Late 20s human female.\n\n"
        f"Style rules: {STYLE_BLOCK}"
    ),
    "maro": (
        'Half-body portrait of a stocky fantasy mechanic called "Maro" for a 2D RPG. '
        "Crawler Mechanic — maintains and upgrades the exploration vehicle. "
        "Broad friendly grin, short beard, goggles pushed up on forehead. "
        "Wears a thick leather apron over amber-brown work clothes with a tool belt "
        "(wrenches, energy cells). Holding a wrench, relaxed approachable expression. "
        "Early 30s human male.\n\n"
        f"Style rules: {STYLE_BLOCK}"
    ),
}


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
    parser = argparse.ArgumentParser(description="Generate NPC portraits via Gemini")
    parser.add_argument("npc", nargs="?", help="NPC ID to generate (kael, lira, maro)")
    parser.add_argument("--list", action="store_true", help="List available NPCs")
    parser.add_argument("--all", action="store_true", help="Generate all NPCs")
    parser.add_argument("--candidates", type=int, default=1,
                        help="Number of candidates per NPC (default: 1)")
    parser.add_argument("--raw-dir", type=str, default=str(DEFAULT_RAW_DIR),
                        help="Output directory for raw images")
    args = parser.parse_args()

    if args.list:
        print("Available NPCs:")
        for npc_id in sorted(NPC_PROMPTS.keys()):
            raw_path = Path(args.raw_dir) / f"{npc_id}.png"
            status = "  [exists]" if raw_path.exists() else ""
            print(f"  {npc_id}{status}")
        return

    raw_dir = Path(args.raw_dir)
    raw_dir.mkdir(parents=True, exist_ok=True)

    if args.all:
        npc_ids = sorted(NPC_PROMPTS.keys())
    elif args.npc:
        npc_id = args.npc.lower()
        if npc_id not in NPC_PROMPTS:
            print(f"ERROR: Unknown NPC '{npc_id}'. Available: {', '.join(sorted(NPC_PROMPTS.keys()))}")
            sys.exit(1)
        npc_ids = [npc_id]
    else:
        parser.print_help()
        return

    api_key = load_api_key()

    for npc_id in npc_ids:
        print(f"\n{'=' * 50}")
        print(f"Generating: {npc_id}")
        print(f"{'=' * 50}")

        for i in range(args.candidates):
            suffix = f"_v{i + 1}" if args.candidates > 1 else ""
            out_path = raw_dir / f"{npc_id}{suffix}.png"

            label = f"  candidate {i + 1}/{args.candidates}" if args.candidates > 1 else "  generating..."
            print(label)

            image_data = generate_image(api_key, NPC_PROMPTS[npc_id])
            if image_data is None:
                print("  FAILED — no image returned")
                continue

            out_path.write_bytes(image_data)
            size_kb = len(image_data) / 1024
            print(f"  saved: {out_path} ({size_kb:.0f} KB)")

    print(f"\nDone. Run ./scripts/process_npc_portraits.sh to process into game assets.")


if __name__ == "__main__":
    main()
