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
FUZZ="12%"
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

  ## Detect background color
  local bg_sample
  bg_sample="$(magick "$src" -crop 1x1+5+5 +repage -format '%[hex:p{0,0}]' info: 2>/dev/null)"
  local bg_color="white"
  local bg_fuzz="$FUZZ"
  if [[ "$bg_sample" == *"FF00FF"* ]] || [[ "$bg_sample" == *"ff00ff"* ]]; then
    bg_color="magenta"
    bg_fuzz="5%"
    echo "  background: magenta"
  fi

  ## Background removal from edges
  local src_dims
  src_dims="$(magick identify -format '%w %h' "$src")"
  local src_w src_h
  src_w="$(echo "$src_dims" | cut -d' ' -f1)"
  src_h="$(echo "$src_dims" | cut -d' ' -f2)"
  local br_x=$((src_w))
  local br_y=$((src_h))

  local fill_target="white"
  local border_col="white"
  if [[ "$bg_color" == "magenta" ]]; then
    fill_target="rgb(255,0,255)"
    border_col="rgb(255,0,255)"
  fi

  magick "$src" \
    -bordercolor "$border_col" -border 1 \
    -fuzz "$bg_fuzz" -fill none \
    -floodfill +0+0 "$fill_target" \
    -floodfill "+0+${br_y}" "$fill_target" \
    -floodfill "+${br_x}+0" "$fill_target" \
    -floodfill "+${br_x}+${br_y}" "$fill_target" \
    -shave 1x1 \
    -trim +repage \
    -resize "${TARGET_SIZE}x${TARGET_SIZE}" \
    -gravity center -background none -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
    "$output"

  ## AI cleanup for interior pockets (same as glyph pipeline)
  if command -v python3 &>/dev/null && [[ -f "$SCRIPT_DIR/cleanup_sprites.py" ]]; then
    python3 "$SCRIPT_DIR/cleanup_sprites.py" "$output" \
      --bg-color "$bg_color" --fuzz "$bg_fuzz" 2>&1 | sed 's/^/  /' || true
  fi

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
echo ""
