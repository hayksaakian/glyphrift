#!/bin/bash
set -euo pipefail

## Process raw NPC portrait images into game-ready assets.
##
## Usage:
##   ./scripts/process_npc_portraits.sh [raw_dir]
##
## Expects PNGs in raw_dir (default: raw/npcs/) named kael.png, lira.png, maro.png.
##
## Output:
##   assets/sprites/npcs/{npc_id}.png  (512x512, transparent bg)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RAW_DIR="${1:-$PROJECT_DIR/raw/npcs}"
OUTPUT_DIR="$PROJECT_DIR/assets/sprites/npcs"

VALID_IDS=(kael lira maro)
FUZZ="35%"
TARGET_SIZE=512
FILL_PCT=80

is_valid_id() {
  local id="$1"
  for valid in "${VALID_IDS[@]}"; do
    if [[ "$valid" == "$id" ]]; then
      return 0
    fi
  done
  return 1
}

process_one() {
  local src="$1"
  local npc_id="$2"
  local output="$OUTPUT_DIR/${npc_id}.png"

  ## Detect background color from top-left corner
  local bg_sample
  bg_sample="$(magick "$src" -crop 1x1+5+5 +repage -format '%[hex:p{0,0}]' info: 2>/dev/null)"
  local bg_color="white"
  local is_magenta=0

  ## Check for magenta-ish background (Gemini often produces near-magenta like FE06FA)
  local r g b
  r=$((16#${bg_sample:0:2}))
  g=$((16#${bg_sample:2:2}))
  b=$((16#${bg_sample:4:2}))
  if (( r > 200 && g < 50 && b > 200 )); then
    is_magenta=1
    bg_color="rgb($r,$g,$b)"
    echo "  background: magenta-like ($bg_sample)"
  fi

  ## Remove background: use -transparent for magenta (covers all regions),
  ## flood-fill from edges for white backgrounds
  if (( is_magenta )); then
    ## Decontamination pipeline: global -transparent (safe for NPC portraits which
    ## have no purple/pink interior fills) + flatten onto black + erode alpha
    local tmp_alpha tmp_rgb tmp_mask tmp_clean
    tmp_alpha="$(mktemp /tmp/npc_alpha_XXXXXX.png)"
    tmp_rgb="$(mktemp /tmp/npc_rgb_XXXXXX.png)"
    tmp_mask="$(mktemp /tmp/npc_mask_XXXXXX.png)"
    tmp_clean="$(mktemp /tmp/npc_clean_XXXXXX.png)"

    magick "$src" -fuzz "$FUZZ" -transparent "$bg_color" "$tmp_alpha"
    magick "$tmp_alpha" -background black -alpha remove -alpha off "$tmp_rgb"
    magick "$tmp_alpha" -alpha extract -morphology Erode Disk:1 "$tmp_mask"
    magick "$tmp_rgb" "$tmp_mask" -compose CopyOpacity -composite "$tmp_clean"
    magick "$tmp_clean" -trim +repage \
      -resize "${TARGET_SIZE}x${TARGET_SIZE}" \
      -gravity center -background none -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
      "$output"
    rm -f "$tmp_alpha" "$tmp_rgb" "$tmp_mask" "$tmp_clean"
  else
    local src_dims
    src_dims="$(magick identify -format '%w %h' "$src")"
    local src_w src_h
    src_w="$(echo "$src_dims" | cut -d' ' -f1)"
    src_h="$(echo "$src_dims" | cut -d' ' -f2)"
    local br_x=$((src_w))
    local br_y=$((src_h))

    magick "$src" \
      -bordercolor white -border 1 \
      -fuzz "$FUZZ" -fill none \
      -floodfill +0+0 white \
      -floodfill "+0+${br_y}" white \
      -floodfill "+${br_x}+0" white \
      -floodfill "+${br_x}+${br_y}" white \
      -shave 1x1 \
      -trim +repage \
      -resize "${TARGET_SIZE}x${TARGET_SIZE}" \
      -gravity center -background none -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
      "$output"
  fi

  ## Note: AI cleanup (cleanup_sprites.py) not needed — decontamination pipeline
  ## already handles edge fringe via flood-fill + black flatten + alpha erosion

  echo "  output: $output"
}

## ---------------------------------------------------------------------------

if [[ ! -d "$RAW_DIR" ]]; then
  echo "ERROR: Raw directory not found: $RAW_DIR"
  echo "Usage: ./scripts/process_npc_portraits.sh [raw_dir]"
  exit 1
fi

shopt -s nullglob
files=("$RAW_DIR"/*.png "$RAW_DIR"/*.PNG)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No PNG files found in $RAW_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo ""
echo "Processing ${#files[@]} NPC portraits from $RAW_DIR"
echo "=========================================="

processed=0
for f in "${files[@]}"; do
  npc_id="$(basename "$f" .png | tr '[:upper:]' '[:lower:]' | sed -E 's/[_ -].*//')"

  echo ""
  echo "$(basename "$f") -> $npc_id"

  if ! is_valid_id "$npc_id"; then
    echo "  SKIPPED: '$npc_id' is not a valid NPC ID"
    continue
  fi

  process_one "$f" "$npc_id"
  processed=$((processed + 1))
done

echo ""
echo "=========================================="
echo "Done: $processed processed"
if [[ $processed -gt 0 ]]; then
  echo ""
  echo "Running Godot headless import..."
  GODOT="${GODOT:-godot}"
  if command -v "$GODOT" &>/dev/null; then
    "$GODOT" --headless --import 2>/dev/null
    echo "Import complete — new portraits are ready to use."
  else
    echo "WARNING: godot not found in PATH. Run 'godot --headless --import' manually."
  fi
fi
echo ""
