#!/bin/bash
set -euo pipefail

## Process raw AI-generated animation strips into game-ready sprite sheets.
##
## Usage:
##   ./scripts/process_sprite_sheet.sh [species_id]
##   ./scripts/process_sprite_sheet.sh --all
##
## Expects raw strips in raw/sheets/{species_id}/{state}.png
## (idle.png, attack.png, hurt.png, ko.png)
##
## Output:
##   assets/sprites/glyphs/sheets/{species_id}_sheet.png  (512x512, 4x4 grid, transparent bg)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RAW_DIR="$PROJECT_DIR/raw/sheets"
SHEET_DIR="$PROJECT_DIR/assets/sprites/glyphs/sheets"

FRAME_SIZE=128
COLS=4
ROWS=4
SHEET_SIZE=$((FRAME_SIZE * COLS))  ## 512

STATE_ORDER=(idle attack hurt ko)

FUZZ="15%"

## Get expected frame count for a state
frame_count_for() {
  case "$1" in
    idle)   echo 4 ;;
    attack) echo 4 ;;
    hurt)   echo 2 ;;
    ko)     echo 3 ;;
    *)      echo 0 ;;
  esac
}

## ---------------------------------------------------------------------------

remove_magenta_bg() {
  ## Remove magenta background via flood-fill from corners + edge decontamination.
  ## Same approach as process_icons.sh.
  local img="$1"
  local out="$2"

  ## Detect magenta in top-left corner
  local bg_sample is_magenta=0 r g b
  bg_sample="$(magick "$img" -crop 1x1+5+5 +repage -format '%[hex:p{0,0}]' info: 2>/dev/null)"
  r=$(printf '%d' "0x${bg_sample:0:2}" 2>/dev/null || echo 0)
  g=$(printf '%d' "0x${bg_sample:2:2}" 2>/dev/null || echo 0)
  b=$(printf '%d' "0x${bg_sample:4:2}" 2>/dev/null || echo 0)
  if [ "$r" -gt 200 ] && [ "$g" -lt 80 ] && [ "$b" -gt 200 ]; then
    is_magenta=1
  fi

  if [ "$is_magenta" -eq 1 ]; then
    local src_dims src_w src_h br_x br_y
    src_dims="$(magick identify -format '%w %h' "$img")"
    src_w="$(echo "$src_dims" | cut -d' ' -f1)"
    src_h="$(echo "$src_dims" | cut -d' ' -f2)"
    br_x=$((src_w))
    br_y=$((src_h))

    local tmp_flood tmp_rgb tmp_mask
    tmp_flood="$(mktemp /tmp/sheet_flood_XXXXXX.png)"
    tmp_rgb="$(mktemp /tmp/sheet_rgb_XXXXXX.png)"
    tmp_mask="$(mktemp /tmp/sheet_mask_XXXXXX.png)"

    ## Flood-fill from all corners
    magick "$img" \
      -bordercolor "rgb($r,$g,$b)" -border 1 \
      -fuzz "$FUZZ" -fill none \
      -floodfill +0+0 "rgb($r,$g,$b)" \
      -floodfill "+0+${br_y}" "rgb($r,$g,$b)" \
      -floodfill "+${br_x}+0" "rgb($r,$g,$b)" \
      -floodfill "+${br_x}+${br_y}" "rgb($r,$g,$b)" \
      -shave 1x1 \
      "$tmp_flood"

    ## Decontaminate edge RGB + erode alpha slightly
    magick "$tmp_flood" -background black -alpha remove -alpha off "$tmp_rgb"
    magick "$tmp_flood" -alpha extract -morphology Erode Disk:1 "$tmp_mask"
    magick "$tmp_rgb" "$tmp_mask" -compose CopyOpacity -composite "$out"

    rm -f "$tmp_flood" "$tmp_rgb" "$tmp_mask"
  else
    ## Non-magenta: try white background removal
    local src_dims src_w src_h br_x br_y
    src_dims="$(magick identify -format '%w %h' "$img")"
    src_w="$(echo "$src_dims" | cut -d' ' -f1)"
    src_h="$(echo "$src_dims" | cut -d' ' -f2)"
    br_x=$((src_w))
    br_y=$((src_h))

    magick "$img" \
      -bordercolor white -border 1 \
      -fuzz "$FUZZ" -fill none \
      -floodfill +0+0 white \
      -floodfill "+0+${br_y}" white \
      -floodfill "+${br_x}+0" white \
      -floodfill "+${br_x}+${br_y}" white \
      -shave 1x1 \
      "$out"
  fi
}

split_into_frames() {
  ## Split a raw strip/grid image into individual frame PNGs.
  ## Handles both horizontal strips and 2x2 grids (Gemini produces both).
  local src="$1"
  local frame_count="$2"
  local out_prefix="$3"  ## e.g. /tmp/frames/idle -> idle_0.png, idle_1.png, ...

  local dims w h
  dims="$(magick identify -format '%w %h' "$src")"
  w="$(echo "$dims" | cut -d' ' -f1)"
  h="$(echo "$dims" | cut -d' ' -f2)"

  local aspect
  aspect="$(echo "$w $h" | awk '{printf "%.2f", $1/$2}')"

  if [[ "$frame_count" -eq 4 ]]; then
    ## 4 frames: could be 2x2 grid or 1x4 strip
    ## If aspect ratio < 1.5, assume 2x2 grid
    local is_grid
    is_grid="$(echo "$aspect" | awk '{print ($1 < 1.5) ? 1 : 0}')"

    if [[ "$is_grid" -eq 1 ]]; then
      ## 2x2 grid: split into quadrants
      local fw=$((w / 2))
      local fh=$((h / 2))
      magick "$src" -crop "${fw}x${fh}+0+0" +repage "${out_prefix}_0.png"
      magick "$src" -crop "${fw}x${fh}+${fw}+0" +repage "${out_prefix}_1.png"
      magick "$src" -crop "${fw}x${fh}+0+${fh}" +repage "${out_prefix}_2.png"
      magick "$src" -crop "${fw}x${fh}+${fw}+${fh}" +repage "${out_prefix}_3.png"
      echo "  Layout: 2x2 grid (${fw}x${fh} per frame)"
    else
      ## 1x4 horizontal strip
      local fw=$((w / 4))
      for i in 0 1 2 3; do
        local ox=$((i * fw))
        magick "$src" -crop "${fw}x${h}+${ox}+0" +repage "${out_prefix}_${i}.png"
      done
      echo "  Layout: 1x4 strip (${fw}x${h} per frame)"
    fi
  elif [[ "$frame_count" -eq 2 ]]; then
    ## 2 frames: split horizontally
    local fw=$((w / 2))
    magick "$src" -crop "${fw}x${h}+0+0" +repage "${out_prefix}_0.png"
    magick "$src" -crop "${fw}x${h}+${fw}+0" +repage "${out_prefix}_1.png"
    echo "  Layout: 1x2 strip (${fw}x${h} per frame)"
  elif [[ "$frame_count" -eq 3 ]]; then
    ## 3 frames: split horizontally into thirds
    local fw=$((w / 3))
    for i in 0 1 2; do
      local ox=$((i * fw))
      magick "$src" -crop "${fw}x${h}+${ox}+0" +repage "${out_prefix}_${i}.png"
    done
    echo "  Layout: 1x3 strip (${fw}x${h} per frame)"
  fi
}

process_species() {
  local species_id="$1"
  local species_raw="$RAW_DIR/$species_id"
  local output="$SHEET_DIR/${species_id}_sheet.png"

  if [[ ! -d "$species_raw" ]]; then
    echo "ERROR: No raw directory for '$species_id' at $species_raw"
    return 1
  fi

  echo ""
  echo "Processing: $species_id"
  echo "----------------------------------------"

  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/sheet_${species_id}_XXXXXX)"

  ## Collect processed frame paths for final assembly
  local all_row_strips=()

  for state in "${STATE_ORDER[@]}"; do
    local raw_strip="$species_raw/${state}.png"
    local frame_count
    frame_count="$(frame_count_for "$state")"

    if [[ ! -f "$raw_strip" ]]; then
      echo "  WARNING: Missing $state.png — filling row with transparent frames"
      ## Create a transparent row
      magick -size "${SHEET_SIZE}x${FRAME_SIZE}" xc:none "$tmp_dir/row_${state}.png"
      all_row_strips+=("$tmp_dir/row_${state}.png")
      continue
    fi

    echo "  $state ($frame_count frames):"

    ## Step 1: Remove magenta background from entire strip
    local clean_strip="$tmp_dir/${state}_clean.png"
    remove_magenta_bg "$raw_strip" "$clean_strip"

    ## Step 2: Split into individual frames
    split_into_frames "$clean_strip" "$frame_count" "$tmp_dir/${state}"

    ## Step 3: Trim, resize, and center each frame to 128x128
    local frame_files=()
    for i in $(seq 0 $((frame_count - 1))); do
      local frame_in="$tmp_dir/${state}_${i}.png"
      local frame_out="$tmp_dir/${state}_final_${i}.png"

      magick "$frame_in" \
        -trim +repage \
        -resize "${FRAME_SIZE}x${FRAME_SIZE}" \
        -gravity center -background none -extent "${FRAME_SIZE}x${FRAME_SIZE}" \
        "$frame_out"

      frame_files+=("$frame_out")
    done

    ## Step 4: Pad to 4 columns with transparent frames if needed
    local pad_count=$((COLS - frame_count))
    if [ "$pad_count" -gt 0 ]; then
      for i in $(seq 1 $pad_count); do
        local pad_frame="$tmp_dir/${state}_pad_${i}.png"
        magick -size "${FRAME_SIZE}x${FRAME_SIZE}" xc:none "$pad_frame"
        frame_files+=("$pad_frame")
      done
    fi

    ## Step 5: Assemble row (4 frames side by side)
    local row_out="$tmp_dir/row_${state}.png"
    magick "${frame_files[@]}" +append "$row_out"
    all_row_strips+=("$row_out")

    echo "  -> row assembled (${frame_count} frames + ${pad_count} padding)"
  done

  ## Step 6: Stack all 4 rows vertically into the final 512x512 sheet
  magick "${all_row_strips[@]}" -append "$output"
  echo ""
  echo "  Sheet: $output"

  ## Verify dimensions
  local final_dims
  final_dims="$(magick identify -format '%wx%h' "$output")"
  echo "  Dimensions: $final_dims (expected ${SHEET_SIZE}x${SHEET_SIZE})"

  ## Cleanup
  rm -rf "$tmp_dir"
}

## ---------------------------------------------------------------------------

mkdir -p "$SHEET_DIR"

if [[ "${1:-}" == "--all" ]]; then
  shopt -s nullglob
  species_dirs=("$RAW_DIR"/*)
  shopt -u nullglob

  if [[ ${#species_dirs[@]} -eq 0 ]]; then
    echo "No species directories found in $RAW_DIR"
    exit 1
  fi

  processed=0
  for species_dir in "${species_dirs[@]}"; do
    if [[ -d "$species_dir" ]]; then
      species_id="$(basename "$species_dir")"
      process_species "$species_id" && processed=$((processed + 1))
    fi
  done

  echo ""
  echo "=========================================="
  echo "Done: $processed species processed"
elif [[ -n "${1:-}" ]]; then
  process_species "$1"
else
  echo "Usage: ./scripts/process_sprite_sheet.sh <species_id>"
  echo "       ./scripts/process_sprite_sheet.sh --all"
  exit 1
fi

echo ""
echo "Running Godot headless import..."
GODOT="${GODOT:-godot}"
if command -v "$GODOT" &>/dev/null; then
  "$GODOT" --headless --import 2>/dev/null
  echo "Import complete — sprite sheets are ready to use."
else
  echo "WARNING: godot not found in PATH. Run 'godot --headless --import' manually."
fi
echo ""
