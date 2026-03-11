#!/bin/bash
set -euo pipefail

## Process raw AI-generated glyph images into game-ready assets.
##
## Usage:
##   ./scripts/process_sprites.sh [raw_dir]
##
## Expects PNGs in raw_dir (default: raw/) named to match species IDs.
## Filenames are lowercased and stripped of non-alphanumeric suffixes.
##
## Outputs:
##   assets/sprites/glyphs/portraits/{species_id}.png   (512x512, transparent bg)
##   assets/sprites/glyphs/silhouettes/{species_id}_silhouette.png  (dark shape)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RAW_DIR="${1:-$PROJECT_DIR/raw}"

PORTRAIT_DIR="$PROJECT_DIR/assets/sprites/glyphs/portraits"
SILHOUETTE_DIR="$PROJECT_DIR/assets/sprites/glyphs/silhouettes"

## Valid species IDs (from data/glyphs.json)
VALID_IDS=(
  zapplet sparkfin stonepaw mossling driftwisp glitchkit
  gritstone shimmer
  thunderclaw ironbark vortail monolith stormfang terradon riftmaw
  voltarion lithosurge nullweaver
)

FUZZ="12%"       ## Background removal tolerance (10-15% catches antialiasing)
TARGET_SIZE=512   ## Output canvas size
FILL_PCT=80       ## Target creature fill percentage

## ---------------------------------------------------------------------------

is_valid_id() {
  local id="$1"
  for valid in "${VALID_IDS[@]}"; do
    if [[ "$valid" == "$id" ]]; then
      return 0
    fi
  done
  return 1
}

normalize_filename() {
  ## Lowercase, strip extension, strip anything after first space/dash/underscore
  ## that isn't part of a known species ID.
  local base
  base="$(basename "$1" .png)"
  base="$(echo "$base" | tr '[:upper:]' '[:lower:]')"

  ## Try exact match first
  if is_valid_id "$base"; then
    echo "$base"
    return
  fi

  ## Try stripping common AI suffixes (e.g., "zapplet_v2", "zapplet - electric")
  local stripped
  stripped="$(echo "$base" | sed -E 's/[_ -].*//')"
  if is_valid_id "$stripped"; then
    echo "$stripped"
    return
  fi

  ## Return as-is; caller will warn about unknown ID
  echo "$base"
}

remove_interior_pockets() {
  ## 2nd-pass: Remove white pockets between limbs/body parts that survived edge flood-fill.
  ##
  ## Strategy: only remove white regions that are NEAR the transparent background (i.e.,
  ## close to the creature's silhouette edge). Eye whites, teeth, and other intentional
  ## features are deep inside the creature, far from any transparency. We detect proximity
  ## by dilating the transparent areas and checking overlap with each white region.
  local img="$1"
  local tmp_mask="/tmp/sprite_mask_$$.png"
  local tmp_edge="/tmp/sprite_edge_$$.png"
  local tmp_cc="/tmp/sprite_cc_$$.txt"

  ## Get image dimensions
  local dims
  dims="$(magick identify -format '%w %h' "$img")"
  local w h
  w="$(echo "$dims" | cut -d' ' -f1)"
  h="$(echo "$dims" | cut -d' ' -f2)"
  local total_pixels=$((w * h))
  local max_pocket_area=$((total_pixels * 5 / 100))  ## 5% threshold

  ## Create binary mask: white = near-white AND opaque pixels, black = everything else.
  magick "$img" \
    -channel RGB -separate -evaluate-sequence max -threshold 90% \
    \( "$img" -alpha extract -threshold 78% \) \
    -compose multiply -composite \
    "$tmp_mask" 2>/dev/null || { rm -f "$tmp_mask"; return; }

  ## Create edge proximity mask: dilate transparent regions by ~15px.
  ## White pixels in this mask = "near the creature's edge / transparent background."
  ## Regions far from any transparency (eyes, teeth) won't overlap with this.
  magick "$img" -alpha extract -negate \
    -morphology Dilate Disk:15 \
    "$tmp_edge" 2>/dev/null || { rm -f "$tmp_mask" "$tmp_edge"; return; }

  ## Get connected components on the white mask
  magick "$tmp_mask" \
    -define connected-components:verbose=true \
    -define connected-components:area-threshold=500 \
    -connected-components 8 \
    null: > "$tmp_cc" 2>&1 || { rm -f "$tmp_mask" "$tmp_edge" "$tmp_cc"; return; }

  ## Parse connected components: find white regions near transparency edge
  local pockets_found=0

  while IFS= read -r line; do
    ## Parse lines like: "2: 89x297+642+927 690.0,1065.2 16274 gray(255)"
    local cw ch cx cy area

    if [[ "$line" =~ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*\ ([0-9]+)\ gray\(255\) ]]; then
      cw="${BASH_REMATCH[1]}"
      ch="${BASH_REMATCH[2]}"
      cx="${BASH_REMATCH[3]}"
      cy="${BASH_REMATCH[4]}"
      area="${BASH_REMATCH[5]}"
    elif [[ "$line" =~ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*\ ([0-9]+)\ srgb\(255,255,255\) ]]; then
      cw="${BASH_REMATCH[1]}"
      ch="${BASH_REMATCH[2]}"
      cx="${BASH_REMATCH[3]}"
      cy="${BASH_REMATCH[4]}"
      area="${BASH_REMATCH[5]}"
    else
      continue
    fi

    ## Skip if touches image border
    if [[ "$cx" -le 0 || "$cy" -le 0 || $((cx + cw)) -ge $w || $((cy + ch)) -ge $h ]]; then
      continue
    fi

    ## Skip if too large
    if [[ "$area" -gt "$max_pocket_area" ]]; then
      continue
    fi

    ## Check if this region's centroid is near transparent background.
    ## Sample the edge proximity mask at the centroid — white (255) means near edge.
    local sample_x=$((cx + cw / 2))
    local sample_y=$((cy + ch / 2))
    local edge_val
    edge_val="$(magick "$tmp_edge" -crop "1x1+${sample_x}+${sample_y}" +repage \
      -format '%[fx:intensity]' info: 2>/dev/null)" || continue

    ## Only remove if near transparency (edge_val > 0.5 means within dilated region)
    if (( $(echo "$edge_val > 0.5" | bc -l 2>/dev/null || echo "0") )); then
      local fill_x=$sample_x
      local fill_y=$sample_y
      magick "$img" \
        -fuzz "$FUZZ" -fill none \
        -floodfill "+${fill_x}+${fill_y}" white \
        "$img" 2>/dev/null && pockets_found=$((pockets_found + 1))
    fi
  done < "$tmp_cc"

  if [[ $pockets_found -gt 0 ]]; then
    echo "  interior pockets removed: $pockets_found"
  fi

  rm -f "$tmp_mask" "$tmp_edge" "$tmp_cc"
}


process_one() {
  local src="$1"
  local species_id="$2"
  local portrait="$PORTRAIT_DIR/${species_id}.png"
  local silhouette="$SILHOUETTE_DIR/${species_id}_silhouette.png"

  ## Step 1: Remove background + trim + resize + re-center
  ##
  ## Strategy: flood-fill from all four edges to remove the background
  ## while preserving any white pixels inside the creature. This is safer
  ## than global -transparent which would punch holes in white features
  ## (eyes, teeth, lightning, etc.).
  ##
  ## The bordercolor+border+floodfill+shave trick seeds the flood from a
  ## 1px border frame, ensuring all four edges are reached even if the
  ## creature is near one side.
  ## Use image dimensions for border flood-fill coordinates
  local src_dims
  src_dims="$(magick identify -format '%w %h' "$src")"
  local src_w src_h
  src_w="$(echo "$src_dims" | cut -d' ' -f1)"
  src_h="$(echo "$src_dims" | cut -d' ' -f2)"
  local br_x=$((src_w))  ## +1 border offset handled by border command
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
    "$portrait"

  ## Step 2: Remove interior white pockets (between limbs, body parts)
  ## Runs on the resized 512x512 portrait for performance
  remove_interior_pockets "$portrait"

  ## Step 3: Generate silhouette (solid dark shape preserving alpha)
  magick "$portrait" \
    -fill "rgb(30,30,40)" -colorize 100% \
    "$silhouette"

  echo "  portrait:   $portrait"
  echo "  silhouette: $silhouette"
}

## ---------------------------------------------------------------------------

if [[ ! -d "$RAW_DIR" ]]; then
  echo "ERROR: Raw directory not found: $RAW_DIR"
  echo "Usage: ./scripts/process_sprites.sh [raw_dir]"
  exit 1
fi

shopt -s nullglob
files=("$RAW_DIR"/*.png "$RAW_DIR"/*.PNG "$RAW_DIR"/*.jpg "$RAW_DIR"/*.JPEG "$RAW_DIR"/*.jpeg)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No image files found in $RAW_DIR"
  exit 1
fi

mkdir -p "$PORTRAIT_DIR" "$SILHOUETTE_DIR"

processed=0
skipped=0

echo ""
echo "Processing ${#files[@]} images from $RAW_DIR"
echo "=========================================="

for f in "${files[@]}"; do
  species_id="$(normalize_filename "$f")"
  echo ""
  echo "$(basename "$f") -> $species_id"

  if ! is_valid_id "$species_id"; then
    echo "  SKIPPED: '$species_id' is not a valid species ID"
    echo "  Valid IDs: ${VALID_IDS[*]}"
    skipped=$((skipped + 1))
    continue
  fi

  process_one "$f" "$species_id"
  processed=$((processed + 1))
done

echo ""
echo "=========================================="
echo "Done: $processed processed, $skipped skipped"
if [[ $processed -gt 0 ]]; then
  echo ""
  echo "Running Godot headless import..."
  GODOT="${GODOT:-godot}"
  if command -v "$GODOT" &>/dev/null; then
    "$GODOT" --headless --import 2>/dev/null
    echo "Import complete — new sprites are ready to use."
  else
    echo "WARNING: godot not found in PATH. Run 'godot --headless --import' manually."
  fi
fi
echo ""
