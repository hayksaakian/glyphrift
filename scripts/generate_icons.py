#!/usr/bin/env python3
"""Generate status effect and room type icons using Gemini.

Usage:
    python3 scripts/generate_icons.py --type status
    python3 scripts/generate_icons.py --type room
    python3 scripts/generate_icons.py --type status --id burn
    python3 scripts/generate_icons.py --list

Saves raw output to raw/icons/ directory.
After generating, run scripts/process_icons.sh to convert to game-ready assets.
"""

import argparse
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_DIR / ".env"
DEFAULT_RAW_DIR = PROJECT_DIR / "raw" / "icons"

MODEL = "gemini-3-pro-image-preview"

ICON_STYLE = (
    "Bold black outlines, flat color fills. No gradients, no soft brushwork. "
    "The icon should be instantly readable when scaled down to 22 pixels. "
    "Keep the shape bold and simple with no fine details. "
    "128x128 image. Solid magenta (#FF00FF) background. "
    "No text, no effects, no shadow, no environment."
)

STATUS_PROMPTS = {
    "burn": (
        "A single game UI icon: a bold flame shape. Bright red-orange (#FF4444) "
        "with a yellow-white core. Simple teardrop flame silhouette, centered on canvas. "
        f"{ICON_STYLE}"
    ),
    "stun": (
        "A single game UI icon: three small star/spark bursts in a tight cluster. "
        "Bright yellow (#FFDD44) with white centers. Classic 'dizzy stars' indicator, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "weaken": (
        "A single game UI icon: a sword or blade cracked and broken in the middle. "
        "Orange (#FF8800) blade with dark hilt accents. Conveys reduced attack power, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "slow": (
        "A single game UI icon: a bold downward-pointing arrow with a horizontal line "
        "through it, like a speed-reduction symbol. Blue (#4488FF) with darker blue accents. "
        f"Centered on canvas. {ICON_STYLE}"
    ),
    "corrode": (
        "A single game UI icon: an acid droplet or dripping liquid drop. "
        "Dark brown-green (#8B6914) with lighter drip marks. Conveys corrosion and decay, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "shield": (
        "A single game UI icon: a simple heraldic shield shape. Bright cyan (#00DDDD) "
        "with a white highlight stripe. Conveys protection and damage reduction, "
        f"centered on canvas. {ICON_STYLE}"
    ),
}

ROOM_PROMPTS = {
    "start": (
        "A single game UI icon: a small triangular flag or banner on a short pole. "
        "Green (#44AA44) flag with white detail, on a brown pole. Marks a starting point, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "exit": (
        "A single game UI icon: a bold downward-pointing arrow inside a square or arch shape. "
        "Solid blue (#4488FF) arrow on a darker blue background shape. Flat color only — "
        "absolutely no gradient, no shading, no 3D effect. Indicates a floor exit or descent, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "enemy": (
        "A single game UI icon: two small swords crossed in an X shape. "
        "Red (#FF4444) blades with dark grey hilts. Indicates a combat encounter, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "hazard": (
        "A single game UI icon: a warning triangle with an exclamation mark inside. "
        "Orange (#FF8800) triangle with a dark interior exclamation mark. Classic danger sign, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "puzzle": (
        "A single game UI icon: a large solid purple (#AA44FF) filled circle with a bold white "
        "question mark '?' in the center. The purple circle must be FILLED with color, not just "
        "an outline. The question mark is bright white. Think of a purple coin or badge with a "
        f"white '?' on it. Centered on canvas. {ICON_STYLE}"
    ),
    "cache": (
        "A single game UI icon: a small closed treasure chest in cartoon vector style. "
        "Gold (#FFD700) lid and clasp with brown (#8B4513) chest body. Smooth curved outlines, "
        "NOT pixel art — smooth anti-aliased vector lines like a mobile game icon. "
        f"Indicates loot or treasure, centered on canvas. {ICON_STYLE}"
    ),
    "hidden": (
        "A single game UI icon: a stylized eye symbol. "
        "Cyan (#00DDDD) with a white pupil or iris. Indicates something hidden or discoverable, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "boss": (
        "A single game UI icon: a crowned skull — simple skull shape wearing a small crown. "
        "Bright red (#FF2222) with white crown and teeth details. Indicates a powerful boss enemy, "
        f"centered on canvas. {ICON_STYLE}"
    ),
    "empty": (
        "A single game UI icon: a simple small solid grey circle or dot. "
        "Flat grey (#888888) fill with a black outline. No gradient, no 3D effect, no ring shape — "
        "just a plain filled circle. Indicates an empty or unremarkable location, "
        f"centered on canvas. {ICON_STYLE}"
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
    parser = argparse.ArgumentParser(description="Generate game icons via Gemini")
    parser.add_argument("--type", choices=["status", "room"], required=False,
                        help="Icon type to generate")
    parser.add_argument("--id", type=str, default=None,
                        help="Generate a specific icon by ID")
    parser.add_argument("--list", action="store_true", help="List available icons")
    parser.add_argument("--candidates", type=int, default=1,
                        help="Number of candidates per icon (default: 1)")
    parser.add_argument("--raw-dir", type=str, default=str(DEFAULT_RAW_DIR),
                        help="Output directory for raw images")
    args = parser.parse_args()

    if args.list:
        print("Status icons:")
        for icon_id in sorted(STATUS_PROMPTS.keys()):
            print(f"  {icon_id}")
        print("\nRoom icons:")
        for icon_id in sorted(ROOM_PROMPTS.keys()):
            print(f"  {icon_id}")
        return

    if not args.type:
        parser.print_help()
        return

    prompts = STATUS_PROMPTS if args.type == "status" else ROOM_PROMPTS
    raw_dir = Path(args.raw_dir) / args.type
    raw_dir.mkdir(parents=True, exist_ok=True)

    if args.id:
        icon_id = args.id.lower()
        if icon_id not in prompts:
            print(f"ERROR: Unknown {args.type} icon '{icon_id}'. "
                  f"Available: {', '.join(sorted(prompts.keys()))}")
            sys.exit(1)
        icon_ids = [icon_id]
    else:
        icon_ids = sorted(prompts.keys())

    api_key = load_api_key()

    for icon_id in icon_ids:
        print(f"\n{'=' * 40}")
        print(f"Generating {args.type} icon: {icon_id}")
        print(f"{'=' * 40}")

        for i in range(args.candidates):
            suffix = f"_v{i + 1}" if args.candidates > 1 else ""
            out_path = raw_dir / f"{icon_id}{suffix}.png"

            label = f"  candidate {i + 1}/{args.candidates}" if args.candidates > 1 else "  generating..."
            print(label)

            image_data = generate_image(api_key, prompts[icon_id])
            if image_data is None:
                print("  FAILED — no image returned")
                continue

            out_path.write_bytes(image_data)
            size_kb = len(image_data) / 1024
            print(f"  saved: {out_path} ({size_kb:.0f} KB)")

    print(f"\nDone. Run ./scripts/process_icons.sh {args.type} to process into game assets.")


if __name__ == "__main__":
    main()
