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
CHASSIS_IDS=(standard ironclad scout hauler)
EQUIPMENT_IDS=(scan_amplifier energy_recycler affinity_filter capacitor_cell hull_plating cargo_rack repair_drone trophy_mount resonance_core)

FUZZ="35%"
TARGET_SIZE=128

process_icon() {
  local src="$1"
  local output="$2"

  ## Detect background color from top-left corner
  local bg_sample
  bg_sample="$(magick "$src" -crop 1x1+5+5 +repage -format '%[hex:p{0,0}]' info: 2>/dev/null)"

  ## Check for magenta-ish background (Gemini often produces near-magenta like FE06FA)
  local r g b is_magenta=0
  r=$((16#${bg_sample:0:2}))
  g=$((16#${bg_sample:2:2}))
  b=$((16#${bg_sample:4:2}))
  if (( r > 200 && g < 50 && b > 200 )); then
    is_magenta=1
  fi

  ## Remove background: flood-fill from corners for magenta (preserves purple/pink
  ## interior colors that global -transparent would strip), then decontaminate edges
  if (( is_magenta )); then
    local src_dims src_w src_h br_x br_y
    src_dims="$(magick identify -format '%w %h' "$src")"
    src_w="$(echo "$src_dims" | cut -d' ' -f1)"
    src_h="$(echo "$src_dims" | cut -d' ' -f2)"
    br_x=$((src_w))
    br_y=$((src_h))

    local tmp_flood tmp_rgb tmp_mask tmp_clean
    tmp_flood="$(mktemp /tmp/icon_flood_XXXXXX.png)"
    tmp_rgb="$(mktemp /tmp/icon_rgb_XXXXXX.png)"
    tmp_mask="$(mktemp /tmp/icon_mask_XXXXXX.png)"
    tmp_clean="$(mktemp /tmp/icon_clean_XXXXXX.png)"

    ## Flood-fill from corners only — won't touch interior purple/pink
    magick "$src" \
      -bordercolor "rgb($r,$g,$b)" -border 1 \
      -fuzz 15% -fill none \
      -floodfill +0+0 "rgb($r,$g,$b)" \
      -floodfill "+0+${br_y}" "rgb($r,$g,$b)" \
      -floodfill "+${br_x}+0" "rgb($r,$g,$b)" \
      -floodfill "+${br_x}+${br_y}" "rgb($r,$g,$b)" \
      -shave 1x1 \
      "$tmp_flood"

    ## Decontaminate edge RGB (flatten onto black) + erode alpha
    magick "$tmp_flood" -background black -alpha remove -alpha off "$tmp_rgb"
    magick "$tmp_flood" -alpha extract -morphology Erode Disk:1 "$tmp_mask"
    magick "$tmp_rgb" "$tmp_mask" -compose CopyOpacity -composite "$tmp_clean"
    magick "$tmp_clean" -trim +repage \
      -resize "${TARGET_SIZE}x${TARGET_SIZE}" \
      -gravity center -background none -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
      "$output"
    rm -f "$tmp_flood" "$tmp_rgb" "$tmp_mask" "$tmp_clean"
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
    icon_id="$(basename "$f" .png | tr '[:upper:]' '[:lower:]')"

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
  chassis)
    process_set "chassis" "${CHASSIS_IDS[@]}"
    ;;
  equipment)
    process_set "equipment" "${EQUIPMENT_IDS[@]}"
    ;;
  all)
    process_set "status" "${STATUS_IDS[@]}"
    process_set "room" "${ROOM_IDS[@]}"
    process_set "chassis" "${CHASSIS_IDS[@]}"
    process_set "equipment" "${EQUIPMENT_IDS[@]}"
    ;;
  *)
    echo "Usage: ./scripts/process_icons.sh {status|room|chassis|equipment|all}"
    exit 1
    ;;
esac

echo ""
echo "Running Godot headless import..."
GODOT="${GODOT:-godot}"
if command -v "$GODOT" &>/dev/null; then
  "$GODOT" --headless --import 2>/dev/null
  echo "Import complete — new icons are ready to use."
else
  echo "WARNING: godot not found in PATH. Run 'godot --headless --import' manually."
fi
echo ""
echo "All done."
