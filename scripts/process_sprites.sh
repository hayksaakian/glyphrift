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
  thunderclaw ironbark vortail stormfang terradon riftmaw
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
  magick "$src" \
    -bordercolor white -border 1 \
    -fuzz "$FUZZ" -fill none \
    -floodfill +0+0 white \
    -floodfill +0+513 white \
    -floodfill +513+0 white \
    -floodfill +513+513 white \
    -shave 1x1 \
    -trim +repage \
    -resize "${TARGET_SIZE}x${TARGET_SIZE}" \
    -gravity center -background none -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
    "$portrait"

  ## Step 2: Generate silhouette (solid dark shape preserving alpha)
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
  echo "Next: open the project in Godot to trigger .import for new PNGs."
  echo "The game will automatically use the new sprites everywhere."
fi
echo ""
