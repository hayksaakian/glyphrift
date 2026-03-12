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
  vesper equinox
  thunderclaw ironbark vortail solstice stormfang terradon riftmaw
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
  ## 2nd-pass: Remove white pockets that survived the edge flood-fill.
  ##
  ## Two complementary strategies:
  ##
  ## A. LOOSE MASK + EDGE PROXIMITY (catches narrow pockets between limbs/tentacles)
  ##    Uses max-of-RGB > 90% mask — loose enough that on spiky creatures (zapplet),
  ##    white areas merge with bright body into large CCs that exceed the 5% area cap.
  ##    But on creatures with dark outlines (lithosurge, riftmaw), narrow white pockets
  ##    stay as small separate CCs and get caught by the centroid proximity check.
  ##
  ## B. STRICT MASK + MORPHOLOGICAL CLOSING (catches large deep-interior pockets)
  ##    Uses min-of-RGB > 88% mask + Disk:30 closing. Small holes (eyes, teeth <~50px)
  ##    get filled back; large holes (pockets >~60px) survive. Catches pockets too far
  ##    from transparency for edge dilation to reach (e.g. thunderclaw belly).
  local img="$1"
  local tmp_mask_loose="/tmp/sprite_mask_loose_$$.png"
  local tmp_mask_strict="/tmp/sprite_mask_strict_$$.png"
  local tmp_edge="/tmp/sprite_edge_$$.png"
  local tmp_cc="/tmp/sprite_cc_$$.txt"
  local tmp_holed="/tmp/sprite_holed_$$.png"
  local tmp_closed="/tmp/sprite_closed_$$.png"

  ## Get image dimensions
  local dims
  dims="$(magick identify -format '%w %h' "$img")"
  local w h
  w="$(echo "$dims" | cut -d' ' -f1)"
  h="$(echo "$dims" | cut -d' ' -f2)"
  local total_pixels=$((w * h))
  local max_pocket_area=$((total_pixels * 5 / 100))  ## 5% area cap for strategy A

  ## --- Strategy A: loose mask + edge proximity ---

  ## Loose mask: any channel > 90%. Catches bright whites but also merges with
  ## bright yellows, making large CCs on spiky creatures that get area-capped.
  magick "$img" \
    -channel RGB -separate -evaluate-sequence max -threshold 90% \
    \( "$img" -alpha extract -threshold 78% \) \
    -compose multiply -composite \
    "$tmp_mask_loose" 2>/dev/null || { rm -f "$tmp_mask_loose"; return; }

  ## Edge proximity mask: dilate transparent regions by ~40px.
  ## Reaches pockets that are up to 40px deep inside the creature outline.
  ## Safe for spiky creatures (zapplet) because Strategy A's loose mask merges
  ## bright body + white into large CCs that exceed the 5% area cap.
  magick "$img" -alpha extract -negate \
    -morphology Dilate Disk:40 \
    "$tmp_edge" 2>/dev/null || { rm -f "$tmp_mask_loose" "$tmp_edge"; return; }

  ## Find CCs on loose mask
  magick "$tmp_mask_loose" \
    -define connected-components:verbose=true \
    -define connected-components:area-threshold=500 \
    -connected-components 8 \
    null: > "$tmp_cc" 2>&1 || true

  local pockets_found=0

  while IFS= read -r line; do
    local cw ch cx cy area
    if [[ "$line" =~ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*\ ([0-9]+)\ gray\(255\) ]]; then
      cw="${BASH_REMATCH[1]}"; ch="${BASH_REMATCH[2]}"
      cx="${BASH_REMATCH[3]}"; cy="${BASH_REMATCH[4]}"; area="${BASH_REMATCH[5]}"
    elif [[ "$line" =~ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*\ ([0-9]+)\ srgb\(255,255,255\) ]]; then
      cw="${BASH_REMATCH[1]}"; ch="${BASH_REMATCH[2]}"
      cx="${BASH_REMATCH[3]}"; cy="${BASH_REMATCH[4]}"; area="${BASH_REMATCH[5]}"
    else
      continue
    fi

    ## Skip border-touching or too-large regions
    if [[ "$cx" -le 0 || "$cy" -le 0 || $((cx + cw)) -ge $w || $((cy + ch)) -ge $h ]]; then
      continue
    fi
    if [[ "$area" -gt "$max_pocket_area" ]]; then
      continue
    fi

    ## Check centroid against edge proximity mask
    local sample_x=$((cx + cw / 2))
    local sample_y=$((cy + ch / 2))
    local edge_val
    edge_val="$(magick "$tmp_edge" -crop "1x1+${sample_x}+${sample_y}" +repage \
      -format '%[fx:intensity]' info: 2>/dev/null)" || continue

    if (( $(echo "$edge_val > 0.5" | bc -l 2>/dev/null || echo "0") )); then
      magick "$img" \
        -fuzz "$FUZZ" -fill none \
        -floodfill "+${sample_x}+${sample_y}" white \
        "$img" 2>/dev/null && pockets_found=$((pockets_found + 1))
    fi
  done < "$tmp_cc"

  ## --- Strategy B: strict mask + morphological closing ---

  ## Strict mask: ALL channels > 88%. Only pure whites, no bright yellows.
  magick "$img" \
    -channel RGB -separate -evaluate-sequence min -threshold 88% \
    \( "$img" -alpha extract -threshold 78% \) \
    -compose multiply -composite \
    "$tmp_mask_strict" 2>/dev/null || { rm -f "$tmp_mask_loose" "$tmp_edge" "$tmp_mask_strict"; return; }

  ## Punch holes at strict-white locations, close with Disk:30.
  magick "$img" -alpha extract \
    \( "$tmp_mask_strict" -negate \) \
    -compose multiply -composite \
    "$tmp_holed" 2>/dev/null || true
  magick "$tmp_holed" -morphology Close Disk:30 \
    "$tmp_closed" 2>/dev/null || true

  ## Find CCs on strict mask
  magick "$tmp_mask_strict" \
    -define connected-components:verbose=true \
    -define connected-components:area-threshold=500 \
    -connected-components 8 \
    null: > "$tmp_cc" 2>&1 || true

  while IFS= read -r line; do
    local cw ch cx cy area
    if [[ "$line" =~ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*\ ([0-9]+)\ gray\(255\) ]]; then
      cw="${BASH_REMATCH[1]}"; ch="${BASH_REMATCH[2]}"
      cx="${BASH_REMATCH[3]}"; cy="${BASH_REMATCH[4]}"; area="${BASH_REMATCH[5]}"
    elif [[ "$line" =~ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*\ ([0-9]+)\ srgb\(255,255,255\) ]]; then
      cw="${BASH_REMATCH[1]}"; ch="${BASH_REMATCH[2]}"
      cx="${BASH_REMATCH[3]}"; cy="${BASH_REMATCH[4]}"; area="${BASH_REMATCH[5]}"
    else
      continue
    fi

    if [[ "$cx" -le 0 || "$cy" -le 0 || $((cx + cw)) -ge $w || $((cy + ch)) -ge $h ]]; then
      continue
    fi

    local fill_x=$((cx + cw / 2))
    local fill_y=$((cy + ch / 2))
    local is_pocket=0

    ## Check B1: Disk:30 closing — catches large pockets (>~60px wide)
    local closed_val
    closed_val="$(magick "$tmp_closed" -crop "1x1+${fill_x}+${fill_y}" +repage \
      -format '%[fx:intensity]' info: 2>/dev/null)" || continue
    if (( $(echo "$closed_val < 0.5" | bc -l 2>/dev/null || echo "0") )); then
      is_pocket=1
    fi

    ## Check B2: edge proximity OR small area.
    ## Pockets within 40px of transparency are caught by the edge mask.
    ## Deeper pockets (>40px) are caught by area < 800 — all genuine
    ## features (e.g. zapplet eyes/body whites) at that depth are larger.
    if [[ $is_pocket -eq 0 ]]; then
      local edge_val_b
      edge_val_b="$(magick "$tmp_edge" -crop "1x1+${fill_x}+${fill_y}" +repage \
        -format '%[fx:intensity]' info: 2>/dev/null)" || continue

      if (( $(echo "$edge_val_b > 0.5" | bc -l 2>/dev/null || echo "0") )); then
        is_pocket=1
      elif [[ "$area" -lt 800 ]]; then
        is_pocket=1
      fi
    fi

    if [[ $is_pocket -eq 1 ]]; then
      magick "$img" \
        -fuzz "$FUZZ" -fill none \
        -floodfill "+${fill_x}+${fill_y}" white \
        "$img" 2>/dev/null && pockets_found=$((pockets_found + 1))
    fi
  done < "$tmp_cc"

  if [[ $pockets_found -gt 0 ]]; then
    echo "  interior pockets removed: $pockets_found"
  fi

  rm -f "$tmp_mask_loose" "$tmp_mask_strict" "$tmp_edge" "$tmp_cc" "$tmp_holed" "$tmp_closed"
}


process_one() {
  local src="$1"
  local species_id="$2"
  local portrait="$PORTRAIT_DIR/${species_id}.png"
  local silhouette="$SILHOUETTE_DIR/${species_id}_silhouette.png"

  ## Step 1: Detect background color (magenta or white)
  local bg_sample
  bg_sample="$(magick "$src" -crop 1x1+5+5 +repage -format '%[hex:p{0,0}]' info: 2>/dev/null)"
  local bg_color="white"
  local bg_fuzz="$FUZZ"
  if [[ "$bg_sample" == *"FF00FF"* ]] || [[ "$bg_sample" == *"ff00ff"* ]]; then
    bg_color="magenta"
    bg_fuzz="5%"
    echo "  background: magenta"
  fi

  ## Step 2: Remove background + trim + resize + re-center
  ##
  ## Flood-fill from all four edges to remove the background while
  ## preserving interior pixels. The bordercolor+border+floodfill+shave
  ## trick seeds the flood from a 1px border frame.
  local src_dims
  src_dims="$(magick identify -format '%w %h' "$src")"
  local src_w src_h
  src_w="$(echo "$src_dims" | cut -d' ' -f1)"
  src_h="$(echo "$src_dims" | cut -d' ' -f2)"
  local br_x=$((src_w))  ## +1 border offset handled by border command
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
    "$portrait"

  ## Step 3: AI-assisted interior pocket cleanup
  ## Uses Gemini vision to identify trapped background pockets and
  ## applies targeted flood-fills. Falls back to heuristic method
  ## if the cleanup script is unavailable.
  if [[ -n "${SKIP_AI_CLEANUP:-}" ]]; then
    ## Manual override: SKIP_AI_CLEANUP=1 ./scripts/process_sprites.sh
    if [[ "$bg_color" == "white" ]]; then
      remove_interior_pockets "$portrait"
    fi
  elif command -v python3 &>/dev/null && [[ -f "$SCRIPT_DIR/cleanup_sprites.py" ]]; then
    python3 "$SCRIPT_DIR/cleanup_sprites.py" "$portrait" \
      --bg-color "$bg_color" --fuzz "$bg_fuzz" 2>&1 | sed 's/^/  /' || {
      echo "  AI cleanup failed, falling back to heuristic"
      if [[ "$bg_color" == "white" ]]; then
        remove_interior_pockets "$portrait"
      fi
    }
  else
    echo "  WARNING: cleanup_sprites.py not available"
    if [[ "$bg_color" == "white" ]]; then
      remove_interior_pockets "$portrait"
    fi
  fi

  ## Step 4: Generate silhouette (solid dark shape preserving alpha)
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
