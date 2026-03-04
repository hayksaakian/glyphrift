# Glyphrift Sprite Asset Specification

Technical standards for all Glyph creature artwork. Source art is AI-generated as clean vector/cartoon-style character illustrations, then processed into game-ready assets.

---

## 1. Source Art Requirements

| Property | Value |
|----------|-------|
| **Resolution** | 512x512 px |
| **Aspect ratio** | 1:1 (square) |
| **Color mode** | sRGB, 8-bit |
| **Format** | PNG (lossless, transparency supported) |
| **Background** | Transparent (preferred) or solid white (for removal) |
| **Style** | Clean vector/cartoon — flat shading, bold outlines, limited palette |
| **Framing** | Full-body, centered, facing right (3/4 view), ~80% fill of the canvas |
| **Outline weight** | 2-4px dark outline on the character at 512px scale |

### Why 512x512

The largest display context is 80x80 CSS pixels at 2x window scale (160 device pixels). 512px source gives clean 4x downscaling headroom with no interpolation artifacts. It's large enough to crop details for future needs (e.g. close-up portraits) without being wasteful. Going higher (1024px) doubles file size with no visible benefit at our viewport resolution.

### Prompt Guidance for AI Generation

- Request the creature on a **plain white or transparent background** with no ground shadow, no environment, no effects
- Specify **full body visible** with consistent padding on all sides
- Request **bold black outlines** and **flat color fills** — avoid gradients, soft brushwork, or painterly texture
- Mention the creature's affinity visually: Electric creatures have sparks/angular shapes, Ground creatures have rocky/earthy forms, Water creatures have fluid/smooth forms
- Keep poses neutral/idle — dynamic poses will be handled by animation frames later

---

## 2. UI Contexts and Display Sizes

Every location in the game where a Glyph image appears, mapped from the codebase and design documents.

### Primary Contexts (frequent, player-facing)

| Context | Display Size | File | Notes |
|---------|-------------|------|-------|
| **Battle — GlyphPanel** | 60x60 | `ui/battle/glyph_panel.gd` | Main combat display. Front/back row. HP bar + status icons adjacent. |
| **Battle — GlyphPortrait** | 64x64 (80x80 highlighted) | `ui/battle/glyph_portrait.gd` | Formation setup slots. Grows to 80x80 with 4px white border on active turn. |
| **Battle — Turn Order Bar** | 64x64 | `ui/battle/glyph_portrait.gd` | Top-of-screen bar showing next 6 turns. Uses GlyphPortrait. Not yet built. |
| **Bastion — GlyphCard** | 60x60 | `ui/shared/glyph_card.gd` | 120x160 card used in Barracks, Fusion Chamber, squad preview. Art is top portion. |
| **Codex — Species Grid** | 60x60 | `ui/bastion/codex_browser.gd` | 5-column grid of all 15 species. Undiscovered show as silhouette. |
| **Detail Popup** | 64x64 | `ui/shared/glyph_detail_popup.gd` | Modal popup from any context — codex, battle, barracks, squad overlay. |

### Secondary Contexts (smaller, less prominent)

| Context | Display Size | File | Notes |
|---------|-------------|------|-------|
| **Dungeon — Squad Overlay** | 20x20 (squad), 16x16 (cargo) | `ui/dungeon/squad_overlay.gd` | Side panel during exploration. Very small — needs to be recognizable as a silhouette. |
| **Dungeon — Capture Popup** | 48x48 | `ui/dungeon/capture_popup.gd` | Post-combat capture prompt. |
| **Puzzle — Echo Encounter** | 60x60 | `ui/dungeon/puzzle_echo.gd` | Uses GlyphCard internally. |

### Planned / Future Contexts

| Context | Display Size | Source |
|---------|-------------|--------|
| **Fusion — Discovery Overlay** | 128x128 (recommended) | GDD 7.7 — "New Glyph revealed with species name, sprite, full stats." Centerpiece of the reveal animation. |
| **Codex — Expanded Entry** | 128x128 (recommended) | GDD 10.1 — "Discovered species show full sprite." Larger than the grid thumbnail. |
| **Dungeon Map — Enemy Preview** | 16x16 to 24x24 | GDD 8.10 — "Enemy squads visible as silhouette icons. Icon size: small=T1, medium=T2, large=T3, glowing=T4." |
| **Codex — Silhouette** | 60x60 | GDD 10.1 — Undiscovered species as dark silhouette with cryptic hint. |

### Size Summary

All display sizes in logical pixels (multiply by 2 for device pixels at the 2x window override):

```
16px ─ Squad overlay cargo icons
20px ─ Squad overlay active squad icons
24px ─ Dungeon map enemy preview (largest tier)
48px ─ Capture popup
60px ─ GlyphPanel, GlyphCard, Codex grid (most common size)
64px ─ GlyphPortrait, Detail popup, Turn order bar
80px ─ GlyphPortrait highlighted state
128px ─ Fusion discovery, Codex expanded entry (future)
```

---

## 3. Scaling Strategy

**Decision: Single source image, Godot scales per context.**

Each species gets one 512x512 PNG. The UI code loads it as a `Texture2D` and displays it at the required size via `TextureRect` (with `expand_mode` and `stretch_mode`) or as an `AtlasTexture` region.

### Why single-source scaling

- **15 species** is a small enough set that texture memory is not a concern
- 512x512 RGBA at 32bpp = ~1 MB uncompressed per species, ~15 MB total — trivial
- Godot's canvas renderer handles downscaling cleanly with the right filter mode
- Pre-exporting 8+ sizes per species (120+ files) adds maintenance burden with no visual benefit
- The stretch mode `canvas_items` in project.godot already handles DPI scaling

### Texture sizing math

At 2x window scale (2560x1440 window for 1280x720 viewport), a 60x60 logical display = 120x120 device pixels. Scaling 512 → 120 is a 4.27x reduction — clean enough to avoid aliasing with linear filtering.

---

## 4. Godot Import Settings

### Per-texture `.import` file settings

Create `assets/sprites/glyphs/.gdimport_defaults` or configure via the Import dock. Each glyph PNG should import with:

```
[remap]
type="CompressedTexture2D"

[deps]
source_file="res://assets/sprites/glyphs/zapplet.png"

[params]
compress/mode=0                    # Lossless (PNG quality preserved)
compress/high_quality=false
compress/lossy_quality=0.7
compress/normal_map=0
flags/repeat=0                     # No repeat/tiling
flags/filter=true                  # Linear filtering ON (smooth downscaling)
mipmaps/generate=true              # Mipmaps ON (clean scaling at all sizes)
mipmaps/limit=-1
process/fix_alpha_border=true      # Prevent dark fringing on transparent edges
process/premult_alpha=false
process/size_limit=0               # No size limit (keep 512x512)
```

### Key settings explained

| Setting | Value | Why |
|---------|-------|-----|
| `compress/mode` | 0 (Lossless) | Preserves clean vector art edges. File size is small enough (15 species). |
| `flags/filter` | true | Linear filtering prevents pixelation when scaling 512 → 60/64/20. |
| `mipmaps/generate` | true | Pre-computed downscaled versions. Critical for the 16-20px squad overlay icons — without mipmaps, 512→16 scaling produces shimmer/aliasing. |
| `process/fix_alpha_border` | true | Extends edge pixels into transparent areas to prevent dark halos from alpha blending. |

### Project-level defaults

Add to `project.godot` if not already present:

```ini
[rendering/textures]
canvas_textures/default_texture_filter=1    # Linear (already the default)
```

### Atlas packing

**Not needed.** With only 15 species at 512x512 each, individual textures are fine. Atlas packing adds complexity with no draw call benefit — Godot's 2D renderer batches automatically. If the species count grows past 30+, reconsider.

---

## 5. Sprite Sheet Format (Animations)

### Phase 1: Static portraits (current scope)

For the initial art pass, each species is a **single static PNG** — no sprite sheet. This replaces all the ColorRect+Label placeholders with actual creature art.

### Phase 2: Animated sprites (future)

When adding idle/attack/hit/KO animations, use this format:

#### Frame dimensions

| Property | Value |
|----------|-------|
| **Frame size** | 128x128 px |
| **Sheet layout** | Horizontal strip (1 row per animation) |
| **Sheet width** | 128 * N frames |
| **Sheet height** | 128 * 4 rows (one per animation type) |

#### Animation rows

| Row | Animation | Frames | FPS | Loop |
|-----|-----------|--------|-----|------|
| 0 | **Idle** | 4 | 4 | Yes |
| 1 | **Attack** | 4 | 8 | No |
| 2 | **Hit** | 2 | 6 | No |
| 3 | **KO** | 3 | 4 | No (hold last frame) |

#### Example sheet: `zapplet_sheet.png`

```
┌────────┬────────┬────────┬────────┐
│ idle_0 │ idle_1 │ idle_2 │ idle_3 │  Row 0: Idle (4 frames, loops)
├────────┼────────┼────────┼────────┤
│ atk_0  │ atk_1  │ atk_2  │ atk_3  │  Row 1: Attack (4 frames)
├────────┼────────┼────────┼────────┤
│ hit_0  │ hit_1  │        │        │  Row 2: Hit (2 frames)
├────────┼────────┼────────┼────────┤
│ ko_0   │ ko_1   │ ko_2   │        │  Row 3: KO (3 frames, hold last)
└────────┴────────┴────────┴────────┘
Total sheet size: 512x512 (4 cols x 4 rows of 128x128)
```

#### SpriteFrames configuration

For `AnimatedSprite2D`, create a `.tres` SpriteFrames resource per species:

```gdscript
# Loading a sprite sheet programmatically
var sheet: Texture2D = load("res://assets/sprites/glyphs/sheets/zapplet_sheet.png")
var frames: SpriteFrames = SpriteFrames.new()

# Add idle animation (row 0, 4 frames)
frames.add_animation("idle")
frames.set_animation_speed("idle", 4.0)
frames.set_animation_loop("idle", true)
for i in range(4):
    var atlas: AtlasTexture = AtlasTexture.new()
    atlas.atlas = sheet
    atlas.region = Rect2(i * 128, 0, 128, 128)
    frames.add_frame("idle", atlas)
```

#### Why 128x128 frames (not 512x512)

Animation sheets at 512x512 per frame would be 512x2048 per sheet — large for 15 species. 128x128 frames are 4x the largest common display size (64x64 at 2x = 128 device pixels), providing pixel-perfect rendering at the most important sizes while keeping sheets compact.

---

## 6. File Naming and Folder Structure

```
assets/sprites/glyphs/
├── portraits/                    # Phase 1: static portraits (512x512)
│   ├── zapplet.png
│   ├── stonepaw.png
│   ├── driftwisp.png
│   ├── sparkfin.png
│   ├── mossling.png
│   ├── pebblix.png
│   ├── voltrake.png
│   ├── ironbark.png
│   ├── tidecaller.png
│   ├── thunderclaw.png
│   ├── quartzmaw.png
│   ├── coralynth.png
│   ├── stormhowl.png
│   ├── tectonix.png
│   └── nullweaver.png
├── silhouettes/                  # Auto-generated from portraits (black fill + alpha)
│   ├── zapplet_silhouette.png
│   └── ...
└── sheets/                       # Phase 2: animation sprite sheets (future)
    ├── zapplet_sheet.png
    └── ...
```

### Naming rules

- **Lowercase**, underscore-separated: `thunder_claw.png` — wait, species IDs in `data/species.json` use no underscores (e.g. `thunderclaw`). **Match the species ID exactly.**
- Portrait: `{species_id}.png` (e.g. `zapplet.png`)
- Silhouette: `{species_id}_silhouette.png`
- Sheet: `{species_id}_sheet.png`
- No tier or affinity in the filename — that metadata lives in the data layer

### Loading convention

```gdscript
# In a helper function or on GlyphInstance/GlyphSpecies
func get_portrait_texture(species_id: String) -> Texture2D:
    var path: String = "res://assets/sprites/glyphs/portraits/%s.png" % species_id
    if ResourceLoader.exists(path):
        return load(path) as Texture2D
    return null  # Falls back to placeholder
```

---

## 7. Background Removal and Padding

### If source has a white background

1. Remove white background to transparent using any tool (Photoshop, GIMP, or batch script with ImageMagick)
2. ImageMagick one-liner for batch processing:
   ```bash
   for f in raw/*.png; do
     magick "$f" -fuzz 10% -transparent white \
       -trim +repage \
       -gravity center -extent 512x512 \
       "portraits/$(basename $f)"
   done
   ```
   - `-fuzz 10%` catches near-white pixels from anti-aliasing
   - `-trim +repage` removes excess transparent border
   - `-extent 512x512` re-centers in a 512x512 canvas with padding

### If source already has transparency

Just trim and re-center:
```bash
magick "$f" -trim +repage -gravity center -extent 512x512 "portraits/$(basename $f)"
```

### Padding rules

| Rule | Value |
|------|-------|
| **Canvas** | 512x512, always |
| **Character fill** | ~80% of canvas (roughly 410px tall/wide) |
| **Minimum margin** | 50px on all sides |
| **Centering** | Gravity center after trim. Feet should sit at ~85% down from top (not dead center — slight bottom-heavy feels more grounded). |
| **No clipping** | No part of the creature (tail, wings, antennae) should touch the canvas edge |

### Transparency requirements

- **Alpha channel**: 8-bit, clean edges
- **No semi-transparent halos**: The `fix_alpha_border` import setting helps, but source art should have clean alpha to begin with
- **No background artifacts**: Verify at 4x zoom that no white fringing remains around the character outline

### Silhouette generation

For the Codex undiscovered state, auto-generate silhouettes from portraits:

```bash
# Generate solid black silhouette preserving alpha shape
magick "portraits/zapplet.png" \
  -alpha extract -threshold 0 -negate \
  \( +clone -fill "rgba(30,30,40,1)" -colorize 100% \) \
  +swap -compose CopyOpacity -composite \
  "silhouettes/zapplet_silhouette.png"
```

This produces a dark shape matching the creature's outline — recognizable but not revealing details.

---

## 8. Integration Checklist

When replacing placeholders with real art, update each component in this order:

1. **Drop PNGs** into `assets/sprites/glyphs/portraits/` — Godot auto-imports
2. **Verify import settings** — check `.import` files match Section 4
3. **Add texture loading** — helper on `GlyphSpecies` or a shared utility
4. **GlyphPanel** — replace `ColorRect` + `Label` with `TextureRect`, keep affinity color as tint or border
5. **GlyphPortrait** — same replacement, preserve highlight/border logic
6. **GlyphCard** — replace art area, keep mastery bar and stat labels
7. **GlyphDetailPopup** — replace art area
8. **CodexBrowser** — replace grid panels, use silhouette for undiscovered
9. **CapturePopup** — replace art area
10. **SquadOverlay** — replace tiny icons (test readability at 16-20px)
11. **Run all tests** — placeholders are tested by structure, not by visual content, so tests should pass unchanged

---

## Appendix: Species Reference

All 15 species with their affinity, for art direction:

| ID | Name | Affinity | Tier | Visual Direction |
|----|------|----------|------|-----------------|
| zapplet | Zapplet | Electric | 1 | Small, sparky critter |
| stonepaw | Stonepaw | Ground | 1 | Sturdy, rocky quadruped |
| driftwisp | Driftwisp | Water | 1 | Floating, fluid form |
| sparkfin | Sparkfin | Electric | 1 | Finned, electric aquatic |
| mossling | Mossling | Ground | 1 | Mossy, plant-like creature |
| pebblix | Pebblix | Water | 1 | Small, pebble-shelled water creature |
| voltrake | Voltrake | Electric | 2 | Larger, draconic electric beast |
| ironbark | Ironbark | Ground | 2 | Armored, tree-like guardian |
| tidecaller | Tidecaller | Water | 2 | Mystical water shaman |
| thunderclaw | Thunderclaw | Electric | 3 | Powerful, clawed storm predator |
| quartzmaw | Quartzmaw | Ground | 3 | Massive, crystal-jawed earth beast |
| coralynth | Coralynth | Water | 3 | Coral-encrusted deep sea titan |
| stormhowl | Stormhowl | Electric | 4 | Apex storm entity |
| tectonix | Tectonix | Ground | 4 | Apex tectonic colossus |
| nullweaver | Nullweaver | Water | 4 | Apex void-water weaver |
