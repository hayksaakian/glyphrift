#!/usr/bin/env python3
"""AI-assisted sprite cleanup using Gemini vision.

Finds opaque white regions in processed sprites, asks Gemini to classify
each as "background pocket" vs "intentional feature", then flood-fills
the pockets to make them transparent.

Usage:
    python3 scripts/cleanup_sprites.py <portrait_path> [options]
    python3 scripts/cleanup_sprites.py assets/sprites/glyphs/portraits/*.png
    python3 scripts/cleanup_sprites.py portraits/ironbark.png --dry-run

Options:
    --bg-color white|magenta   Expected trapped background color (default: white)
    --fuzz PERCENT             Flood-fill fuzz tolerance (default: 12% white, 5% magenta)
    --dry-run                  Print classifications without applying flood-fills
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_DIR / ".env"

MODEL = "gemini-2.5-pro"

# Minimum CC area (pixels) to consider for cleanup
MIN_CC_AREA = 50


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


def find_white_ccs(image_path: Path, bg_color: str) -> list[dict]:
    """Find interior opaque white/magenta connected components.

    Uses ImageMagick to build a mask of background-colored opaque pixels,
    then finds connected components. Returns list of dicts with
    x, y (centroid), w, h, cx, cy (bounding box origin), area.
    """
    img = str(image_path)

    # Build mask: opaque pixels that match background color
    if bg_color == "magenta":
        # Magenta: R > 200, G < 80, B > 200, alpha > 200
        mask_cmd = [
            "magick", img,
            "(", "+clone", "-channel", "R", "-separate", "-threshold", "78%", ")",
            "(", "+clone", "-channel", "G", "-separate", "-negate", "-threshold", "70%", ")",
            "(", "+clone", "-channel", "B", "-separate", "-threshold", "78%", ")",
            "-compose", "darken", "-composite",
            "-compose", "darken", "-composite",
            "(", img, "-alpha", "extract", "-threshold", "78%", ")",
            "-compose", "multiply", "-composite",
        ]
    else:
        # White: min(R,G,B) > 88%, alpha > 78%
        mask_cmd = [
            "magick", img,
            "-channel", "RGB", "-separate",
            "-evaluate-sequence", "min",
            "-threshold", "88%",
            "(", img, "-alpha", "extract", "-threshold", "78%", ")",
            "-compose", "multiply", "-composite",
        ]

    # Run CC analysis on the mask
    result = subprocess.run(
        mask_cmd + [
            "-define", f"connected-components:area-threshold={MIN_CC_AREA}",
            "-define", "connected-components:verbose=true",
            "-connected-components", "8",
            "null:",
        ],
        capture_output=True, text=True,
    )

    # Get image dimensions
    dims_result = subprocess.run(
        ["magick", "identify", "-format", "%w %h", img],
        capture_output=True, text=True,
    )
    w, h = 512, 512
    if dims_result.returncode == 0:
        parts = dims_result.stdout.strip().split()
        if len(parts) == 2:
            w, h = int(parts[0]), int(parts[1])

    # Parse CC output
    ccs = []
    output = result.stdout + result.stderr
    for line in output.splitlines():
        m = re.search(
            r"(\d+)x(\d+)\+(\d+)\+(\d+).*?\s(\d+)\s+"
            r"(?:gray\(255\)|srgb\(255,255,255\))",
            line,
        )
        if not m:
            continue

        cw, ch = int(m.group(1)), int(m.group(2))
        cx, cy = int(m.group(3)), int(m.group(4))
        area = int(m.group(5))

        # Skip border-touching CCs (these are background, not pockets)
        if cx <= 0 or cy <= 0 or (cx + cw) >= w or (cy + ch) >= h:
            continue

        # Centroid
        fx = cx + cw // 2
        fy = cy + ch // 2

        ccs.append({
            "x": fx, "y": fy,
            "cx": cx, "cy": cy,
            "w": cw, "h": ch,
            "area": area,
        })

    return ccs


def classify_with_gemini(api_key: str, image_path: Path,
                         ccs: list[dict], bg_color: str) -> list[bool]:
    """Ask Gemini to classify each white CC as pocket (True) or feature (False).

    Sends the image plus a numbered list of CC locations. Gemini returns
    which ones are trapped background pockets.
    """
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        print("ERROR: google-genai not installed. Run: pip3 install google-genai")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    image_bytes = image_path.read_bytes()
    image_part = types.Part.from_bytes(data=image_bytes, mime_type="image/png")

    bg_desc = "magenta/pink" if bg_color == "magenta" else "white"

    # Build region list
    region_lines = []
    for i, cc in enumerate(ccs):
        region_lines.append(
            f"  Region {i + 1}: center=({cc['x']},{cc['y']}), "
            f"size={cc['w']}x{cc['h']}, area={cc['area']}px"
        )
    regions_text = "\n".join(region_lines)

    prompt = f"""\
This is a 512x512 game sprite with a transparent background. I found \
{len(ccs)} opaque {bg_desc} regions inside the creature that survived \
edge-based background removal:

{regions_text}

For each region, classify it as either:
- "pocket": trapped background between body parts (arms, legs, tentacles, \
antlers, tail, etc.) that SHOULD be made transparent
- "feature": an intentional part of the creature's design (eyes, teeth, \
lightning, stars, highlights, white markings, glowing effects) that should \
be KEPT

Respond ONLY with a JSON array of strings, one per region, in order. \
Example for 3 regions: ["pocket", "feature", "pocket"]"""

    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=[image_part, prompt],
            config=types.GenerateContentConfig(
                response_modalities=["TEXT"],
                temperature=0.0,
            ),
        )
    except Exception as e:
        print(f"  API error: {e}")
        return [False] * len(ccs)

    if not response.candidates:
        print("  No response from Gemini")
        return [False] * len(ccs)

    text = ""
    for part in response.candidates[0].content.parts:
        if part.text:
            text += part.text

    return parse_classifications(text, len(ccs))


def parse_classifications(text: str, expected: int) -> list[bool]:
    """Parse Gemini's classification response. Returns list of bools (True=pocket)."""
    text = re.sub(r"```json\s*", "", text)
    text = re.sub(r"```\s*", "", text)
    text = text.strip()

    match = re.search(r"\[.*\]", text, re.DOTALL)
    if not match:
        print(f"  Could not parse response: {text[:200]}")
        return [False] * expected

    try:
        labels = json.loads(match.group())
    except json.JSONDecodeError as e:
        print(f"  JSON parse error: {e}")
        return [False] * expected

    if len(labels) != expected:
        print(f"  WARNING: expected {expected} labels, got {len(labels)}")
        # Pad or truncate
        labels = labels[:expected] + ["feature"] * max(0, expected - len(labels))

    return [str(label).lower().strip() == "pocket" for label in labels]


def flood_fill(image_path: Path, x: int, y: int, bg_color: str, fuzz: str) -> bool:
    """Apply flood-fill at coordinates to make background transparent."""
    fill_target = "rgb(255,0,255)" if bg_color == "magenta" else "white"
    result = subprocess.run(
        [
            "magick", str(image_path),
            "-fuzz", fuzz,
            "-fill", "none",
            "-floodfill", f"+{x}+{y}", fill_target,
            str(image_path),
        ],
        capture_output=True, text=True,
    )
    return result.returncode == 0


def cleanup_one(api_key: str, image_path: Path, bg_color: str, fuzz: str,
                dry_run: bool) -> int:
    """Clean up one portrait. Returns number of pockets removed."""
    # Step 1: Find all interior white/magenta CCs
    ccs = find_white_ccs(image_path, bg_color)
    if not ccs:
        print(f"  no white regions found")
        return 0

    print(f"  found {len(ccs)} interior white region(s)")

    # Step 2: Ask Gemini to classify each as pocket vs feature
    print(f"  classifying with Gemini...")
    is_pocket = classify_with_gemini(api_key, image_path, ccs, bg_color)

    # Step 3: Flood-fill the pockets
    removed = 0
    for cc, pocket in zip(ccs, is_pocket):
        label = "pocket" if pocket else "feature"
        x, y = cc["x"], cc["y"]
        size_str = f"{cc['w']}x{cc['h']} area={cc['area']}"

        if not pocket:
            print(f"    ({x},{y}) {size_str} — keep (feature)")
            continue

        if dry_run:
            print(f"    ({x},{y}) {size_str} — remove (dry run)")
            removed += 1
        else:
            if flood_fill(image_path, x, y, bg_color, fuzz):
                print(f"    ({x},{y}) {size_str} — removed")
                removed += 1
            else:
                print(f"    ({x},{y}) {size_str} — flood-fill failed")

    return removed


def main():
    parser = argparse.ArgumentParser(
        description="AI-assisted sprite pocket cleanup via Gemini vision")
    parser.add_argument("portraits", nargs="+", help="Portrait PNG path(s)")
    parser.add_argument("--bg-color", choices=["white", "magenta"],
                        default="white", help="Trapped background color (default: white)")
    parser.add_argument("--fuzz", type=str, default=None,
                        help="Flood-fill fuzz tolerance (default: 12%% white, 5%% magenta)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print coordinates without applying flood-fills")
    args = parser.parse_args()

    if args.fuzz is None:
        args.fuzz = "5%" if args.bg_color == "magenta" else "12%"

    api_key = load_api_key()

    total_removed = 0
    for path_str in args.portraits:
        image_path = Path(path_str)
        if not image_path.exists():
            print(f"WARNING: {image_path} not found, skipping")
            continue

        print(f"\n{image_path.name}")
        removed = cleanup_one(api_key, image_path, args.bg_color, args.fuzz,
                              args.dry_run)
        total_removed += removed

    action = "would remove" if args.dry_run else "removed"
    print(f"\nDone: {action} {total_removed} pocket(s) across {len(args.portraits)} sprite(s)")


if __name__ == "__main__":
    main()
