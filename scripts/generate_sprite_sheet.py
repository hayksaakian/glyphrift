#!/usr/bin/env python3
"""Generate glyph animation sprite strips using Gemini.

Usage:
    python3 scripts/generate_sprite_sheet.py --id zapplet
    python3 scripts/generate_sprite_sheet.py --id zapplet --state idle
    python3 scripts/generate_sprite_sheet.py --all
    python3 scripts/generate_sprite_sheet.py --list

Reads animation briefs from data/glyph_animations.json.
Uses the existing portrait from assets/sprites/glyphs/portraits/ as a style reference.
Saves raw strips to raw/sheets/{species_id}/.
After generating, run scripts/process_sprite_sheet.sh to assemble into game-ready sheets.
"""

import argparse
import json
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_DIR / ".env"
ANIMATIONS_FILE = PROJECT_DIR / "data" / "glyph_animations.json"
PORTRAITS_DIR = PROJECT_DIR / "assets" / "sprites" / "glyphs" / "portraits"
TEMPLATES_DIR = PROJECT_DIR / "raw" / "templates"
DEFAULT_RAW_DIR = PROJECT_DIR / "raw" / "sheets"

MODEL = "gemini-3-pro-image-preview"

# Animation states with their frame counts and grid template filenames
ANIM_STATES = {
    "idle":   {"frames": 4, "description": "idle breathing/ambient loop", "grid": "grid_2x2.png"},
    "attack": {"frames": 4, "description": "wind-up, strike, follow-through, settle", "grid": "grid_2x2.png"},
    "hurt":   {"frames": 2, "description": "flinch/recoil", "grid": "grid_1x2.png"},
    "ko":     {"frames": 3, "description": "collapse/dissolution", "grid": "grid_1x3.png"},
}

SHARED_STYLE = (
    "Same character exactly as the reference image — same species, same proportions, "
    "same colors, same design details. Bold black outlines, flat color fills, no gradients, "
    "no soft brushwork. 3/4 view facing right. Solid magenta (#FF00FF) background. "
    "No text, no labels, no frame borders, no environment, no ground shadow."
)


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


def load_animations() -> dict:
    """Load animation briefs from JSON. Returns dict keyed by species_id."""
    if not ANIMATIONS_FILE.exists():
        print(f"ERROR: {ANIMATIONS_FILE} not found")
        sys.exit(1)
    data = json.loads(ANIMATIONS_FILE.read_text())
    return {entry["species_id"]: entry for entry in data}


def load_portrait_bytes(species_id: str) -> bytes | None:
    """Load the portrait PNG as bytes for use as reference image."""
    portrait_path = PORTRAITS_DIR / f"{species_id}.png"
    if not portrait_path.exists():
        print(f"  WARNING: No portrait found at {portrait_path}")
        return None
    return portrait_path.read_bytes()


def load_grid_template(state: str) -> bytes | None:
    """Load the grid template image for a given animation state."""
    grid_file = ANIM_STATES[state]["grid"]
    grid_path = TEMPLATES_DIR / grid_file
    if not grid_path.exists():
        print(f"  WARNING: No grid template at {grid_path}")
        return None
    return grid_path.read_bytes()


def build_prompt(species: dict, state: str) -> str:
    """Build the generation prompt for a specific animation state."""
    anim_info = ANIM_STATES[state]
    frame_count = anim_info["frames"]
    brief = species[state]

    if frame_count == 4:
        grid_desc = (
            "The second image is a GRID TEMPLATE with a 2x2 grid of 4 cells on a magenta background. "
            "Draw one pose per cell, filling each cell. The character in every cell must be "
            "the SAME SIZE and CENTERED in the cell. Read order: top-left=frame 1, "
            "top-right=frame 2, bottom-left=frame 3, bottom-right=frame 4."
        )
    elif frame_count == 2:
        grid_desc = (
            "The second image is a GRID TEMPLATE with 2 cells stacked vertically on a magenta background. "
            "Draw one pose per cell, filling each cell. The character in every cell must be "
            "the SAME SIZE and CENTERED in the cell. Top cell=frame 1, bottom cell=frame 2."
        )
    elif frame_count == 3:
        grid_desc = (
            "The second image is a GRID TEMPLATE with 3 cells on a magenta background: "
            "2 cells on top (side by side) and 1 wide cell on the bottom. "
            "Draw one pose per cell, filling each cell. The character in every cell must be "
            "the SAME SIZE and CENTERED in the cell. Top-left=frame 1, top-right=frame 2, bottom=frame 3."
        )
    else:
        grid_desc = ""

    prompt = (
        f"I need a sprite sheet for a creature called \"{species['name']}\" "
        f"(a {species['body_type']}, {species['affinity']} affinity).\n\n"
        f"The first image is the CHARACTER REFERENCE — this is what the creature looks like. "
        f"Match this character exactly: same species, same proportions, same colors.\n\n"
        f"{grid_desc}\n\n"
        f"CRITICAL: Fill the grid template cells with the character. Each cell must contain "
        f"the character drawn at the SAME SCALE and CENTERED. Do not draw the character "
        f"at different sizes in different cells.\n\n"
        f"Animation state: {state.upper()} ({anim_info['description']})\n"
        f"Animation description: {brief}\n\n"
        f"Each frame should show a distinct pose progressing through the animation.\n\n"
        f"{SHARED_STYLE}"
    )
    return prompt


def generate_strip(api_key: str, prompt: str, portrait_bytes: bytes | None,
                    grid_bytes: bytes | None = None) -> bytes | None:
    """Call Gemini API with prompt + reference images. Returns PNG bytes or None."""
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        print("ERROR: google-genai not installed. Run: pip3 install google-genai")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    # Build contents: portrait reference + grid template + text prompt
    contents = []
    if portrait_bytes:
        contents.append(types.Part.from_bytes(data=portrait_bytes, mime_type="image/png"))
    if grid_bytes:
        contents.append(types.Part.from_bytes(data=grid_bytes, mime_type="image/png"))
    contents.append(prompt)

    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=contents,
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


def generate_species(api_key: str, species: dict, raw_dir: Path, states: list[str]):
    """Generate animation strips for one species."""
    species_id = species["species_id"]
    species_dir = raw_dir / species_id
    species_dir.mkdir(parents=True, exist_ok=True)

    portrait_bytes = load_portrait_bytes(species_id)
    if portrait_bytes:
        print(f"  Using portrait as style reference ({len(portrait_bytes) / 1024:.0f} KB)")
    else:
        print(f"  No portrait reference — generating without style guide")

    for state in states:
        out_path = species_dir / f"{state}.png"
        print(f"\n  {state.upper()} ({ANIM_STATES[state]['frames']} frames)...")

        prompt = build_prompt(species, state)
        grid_bytes = load_grid_template(state)
        if grid_bytes:
            print(f"  Using grid template: {ANIM_STATES[state]['grid']}")
        image_data = generate_strip(api_key, prompt, portrait_bytes, grid_bytes)

        if image_data is None:
            print(f"  FAILED — no image returned for {state}")
            continue

        out_path.write_bytes(image_data)
        size_kb = len(image_data) / 1024
        print(f"  Saved: {out_path} ({size_kb:.0f} KB)")


def main():
    parser = argparse.ArgumentParser(description="Generate glyph animation strips via Gemini")
    parser.add_argument("--id", type=str, default=None, help="Species ID to generate (e.g. zapplet)")
    parser.add_argument("--state", type=str, default=None,
                        choices=list(ANIM_STATES.keys()),
                        help="Generate only a specific animation state")
    parser.add_argument("--all", action="store_true", help="Generate all species")
    parser.add_argument("--list", action="store_true", help="List available species")
    parser.add_argument("--raw-dir", type=str, default=str(DEFAULT_RAW_DIR),
                        help="Output directory for raw strips")
    args = parser.parse_args()

    animations = load_animations()

    if args.list:
        print(f"Available species ({len(animations)}):")
        for sid, spec in sorted(animations.items()):
            print(f"  {sid} (T{spec['tier']} {spec['affinity']}, {spec['body_type']})")
        return

    states = [args.state] if args.state else list(ANIM_STATES.keys())
    raw_dir = Path(args.raw_dir)

    if args.all:
        api_key = load_api_key()
        for species_id in sorted(animations.keys()):
            print(f"\n{'=' * 50}")
            print(f"Generating: {species_id}")
            print(f"{'=' * 50}")
            generate_species(api_key, animations[species_id], raw_dir, states)
        print(f"\nDone. Run ./scripts/process_sprite_sheet.sh to assemble into game-ready sheets.")
        return

    if not args.id:
        parser.print_help()
        return

    species_id = args.id.lower()
    if species_id not in animations:
        print(f"ERROR: No animation data for '{species_id}'")
        print(f"Available: {', '.join(sorted(animations.keys()))}")
        sys.exit(1)

    api_key = load_api_key()
    print(f"\n{'=' * 50}")
    print(f"Generating: {species_id}")
    print(f"{'=' * 50}")
    generate_species(api_key, animations[species_id], raw_dir, states)
    print(f"\nDone. Run ./scripts/process_sprite_sheet.sh to assemble into game-ready sheets.")


if __name__ == "__main__":
    main()
