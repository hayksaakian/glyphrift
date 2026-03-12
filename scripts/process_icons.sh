#!/bin/bash
set -euo pipefail

## Process raw icon images into game-ready assets.
##
## Usage:
##   ./scripts/process_icons.sh status   # Process status effect icons
##   ./scripts/process_icons.sh room     # Process room type icons
##   ./scripts/process_icons.sh all      # Process both
##
## Expects PNGs in raw/icons/{status,room}/ named by ID (burn.png, enemy.png, etc).
##
## Output:
##   assets/sprites/icons/status/{id}.png  (128x128, transparent bg)
##   assets/sprites/icons/rooms/{id}.png   (128x128, transparent bg)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

STATUS_IDS=(burn stun weaken slow corrode shield)
ROOM_IDS=(start exit enemy hazard puzzle cache hidden boss empty)

FUZZ="5%"
TARGET_SIZE=128

process_icon() {
  local src="$1"
  local output="$2"

  ## Detect background color
  local bg_sample
  bg_sample="$(magick "$src" -crop 1x1+5+5 +repage -format '%[hex:p{0,0}]' info: 2>/dev/null)"
  local bg_fuzz="$FUZZ"
  local fill_target="white"
  local border_col="white"

  if [[ "$bg_sample" == *"FF00FF"* ]] || [[ "$bg_sample" == *"ff00ff"* ]]; then
    fill_target="rgb(255,0,255)"
    border_col="rgb(255,0,255)"
  fi

  ## Background removal + resize to target
  local src_dims
  src_dims="$(magick identify -format '%w %h' "$src")"
  local src_w src_h
  src_w="$(echo "$src_dims" | cut -d' ' -f1)"
  src_h="$(echo "$src_dims" | cut -d' ' -f2)"
  local br_x=$((src_w))
  local br_y=$((src_h))

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
}

process_set() {
  local icon_type="$1"
  shift
  local valid_ids=("$@")

  local raw_dir="$PROJECT_DIR/raw/icons/$icon_type"
  local out_dir="$PROJECT_DIR/assets/sprites/icons"
  if [[ "$icon_type" == "room" ]]; then
    out_dir="$out_dir/rooms"
  else
    out_dir="$out_dir/$icon_type"
  fi

  if [[ ! -d "$raw_dir" ]]; then
    echo "No raw directory: $raw_dir — skipping $icon_type icons"
    return
  fi

  mkdir -p "$out_dir"

  shopt -s nullglob
  local files=("$raw_dir"/*.png "$raw_dir"/*.PNG)
  shopt -u nullglob

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No PNG files in $raw_dir — skipping $icon_type icons"
    return
  fi

  echo ""
  echo "Processing $icon_type icons from $raw_dir"
  echo "=========================================="

  local processed=0
  for f in "${files[@]}"; do
    local icon_id
    icon_id="$(basename "$f" .png | tr '[:upper:]' '[:lower:]' | sed -E 's/[_ -].*//')"

    echo "  $(basename "$f") -> $icon_id"

    local valid=0
    for vid in "${valid_ids[@]}"; do
      if [[ "$vid" == "$icon_id" ]]; then
        valid=1
        break
      fi
    done

    if [[ $valid -eq 0 ]]; then
      echo "    SKIPPED: unknown $icon_type icon '$icon_id'"
      continue
    fi

    process_icon "$f" "$out_dir/${icon_id}.png"
    echo "    -> $out_dir/${icon_id}.png"
    processed=$((processed + 1))
  done

  echo "  Done: $processed $icon_type icons processed"
}

## ---------------------------------------------------------------------------

case "${1:-all}" in
  status)
    process_set "status" "${STATUS_IDS[@]}"
    ;;
  room)
    process_set "room" "${ROOM_IDS[@]}"
    ;;
  all)
    process_set "status" "${STATUS_IDS[@]}"
    process_set "room" "${ROOM_IDS[@]}"
    ;;
  *)
    echo "Usage: ./scripts/process_icons.sh {status|room|all}"
    exit 1
    ;;
esac

echo ""
echo "All done."
