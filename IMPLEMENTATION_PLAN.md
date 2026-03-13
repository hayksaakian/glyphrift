## Glyph Animation Pipeline — Implementation Plan

**Goal:** Build the sprite sheet generation pipeline and Godot integration, using Zapplet as the test case. Once proven, the pipeline works for all 18 species.

**Test species:** Zapplet (T1 Electric, small quadruped, signature: jolt_rush)

---

### Stage 1: Generation Script
**Goal:** `scripts/generate_sprite_sheet.py` that produces 4 raw animation strip images per species.
**Success Criteria:** Running `python3 scripts/generate_sprite_sheet.py zapplet` produces 4 PNGs in `raw/sheets/zapplet/` (idle.png, attack.png, hurt.png, ko.png), each showing a horizontal strip of frames in the same art style as the existing portrait.
**Tests:** Manual — visually inspect the 4 strips match Zapplet's portrait style.

Implementation:
- Read `data/glyph_animations.json` for the species animation briefs
- Read the existing portrait from `assets/sprites/glyphs/portraits/{species_id}.png` and pass it as a reference image to Gemini
- For each animation state (idle, attack, hurt, ko), build a prompt:
  - Include the portrait as style/character reference
  - Request a horizontal strip of N frames (4, 4, 2, 3 respectively) at 512x512 total
  - Include the animation brief text from the JSON
  - Include shared style directives: "Same character exactly, same art style, bold black outlines, flat color fills, 3/4 view facing right, solid magenta (#FF00FF) background, no text"
  - Specify frame count and strip layout: "Draw exactly N poses of this character side by side in a single horizontal strip"
- Use the same Gemini API pattern as `generate_sprites.py` and `generate_icons.py`
- Support `--id zapplet` for single species, `--all` for batch, `--state idle` for single state
- Output to `raw/sheets/{species_id}/{state}.png`

**Status:** Complete

---

### Stage 2: Assembly + Processing Script
**Goal:** `scripts/process_sprite_sheet.sh` that assembles 4 strips into a single 512x512 sheet with magenta removal.
**Success Criteria:** Running the script on Zapplet's raw strips produces `assets/sprites/glyphs/sheets/zapplet_sheet.png` — a 512x512 PNG with 4 rows × 4 cols of 128x128 transparent-background frames.
**Tests:** Manual — verify frame dimensions, transparency, no magenta bleed, visual quality at 64px display size.

Implementation:
- Input: 4 strip images from `raw/sheets/{species_id}/`
- For each strip:
  - Remove magenta background (reuse flood-fill pattern from `process_icons.sh`)
  - Split into individual frames (divide strip width by expected frame count)
  - Resize each frame to 128x128
  - Pad strips with fewer frames (hurt=2, ko=3) to 4 cols with transparent padding
- Assemble into 4×4 grid (512x512 total) using ImageMagick montage or append
- Output to `assets/sprites/glyphs/sheets/{species_id}_sheet.png`
- Run `godot --headless --import` at the end
- Support single species or batch processing
- **Note:** Gemini produces 2x2 grids (not strips) for 4-frame states. Script auto-detects grid vs strip layout based on aspect ratio.

**Status:** Complete

---

### Stage 3: GlyphAnimator Godot Component
**Goal:** A reusable `GlyphAnimator` class that loads sprite sheets and plays animations.
**Success Criteria:** Unit tests pass — GlyphAnimator loads Zapplet's sheet, plays idle/attack/hurt/ko animations with correct frame counts, timing, and loop behavior. Falls back to static portrait if no sheet exists.
**Tests:** New test file `tests/test_glyph_animator.gd` with tests for:
- Loads sheet and creates SpriteFrames with correct animation names
- idle: 4 frames, 4 FPS, loops
- attack: 4 frames, 8 FPS, no loop
- hurt: 2 frames, 6 FPS, no loop
- ko: 3 frames, 4 FPS, no loop (holds last)
- Falls back to static TextureRect when no sheet exists
- `instant_mode`: skips to final frame of each animation
- `play("attack")` → `animation_finished` signal when done

Implementation:
- `ui/shared/glyph_animator.gd` — extends `Control`
- Loads sheet from `res://assets/sprites/glyphs/sheets/{species_id}_sheet.png`
- Programmatically creates `SpriteFrames` with `AtlasTexture` regions (per the spec in sprite-asset-spec.md)
- Contains an `AnimatedSprite2D` child for playback
- API:
  - `setup(species_id: String)` — loads sheet or falls back to portrait
  - `play(anim: String)` — plays animation, emits `animation_finished` when done
  - `set_species(species_id: String)` — change species (for reuse)
  - `instant_mode: bool` — for headless testing
  - `has_animations: bool` — true if sheet loaded, false if fallback
- Animation config stored as const dict (not loaded from file):
  ```
  ANIMS = {
    "idle": {row=0, frames=4, fps=4, loop=true},
    "attack": {row=1, frames=4, fps=8, loop=false},
    "hurt": {row=2, frames=2, fps=6, loop=false},
    "ko": {row=3, frames=3, fps=4, loop=false}
  }
  ```
- Frame size: 128x128, sheet is 512x512 (4 cols × 4 rows)
- Fallback: if sheet doesn't exist, creates a TextureRect with the static portrait instead

**Status:** Complete (43 tests pass)

---

### Stage 4: Battle Scene Integration
**Goal:** Replace static GlyphPanel portraits with GlyphAnimator, wired to combat events.
**Success Criteria:** In battle, Zapplet plays idle loop, attack animation on technique use, hurt on taking damage, KO on death. All existing tween effects (damage numbers, flash, shake) continue to work on top. All 1745+ existing tests still pass.
**Tests:** Update `tests/test_battle_ui.gd` with animation-specific tests:
- GlyphPanel uses GlyphAnimator when sheet exists
- GlyphPanel falls back to static portrait when no sheet
- Attack event triggers attack animation
- Damage event triggers hurt animation
- KO event triggers ko animation + existing grey-out tween
- `instant_mode` skips animations in headless tests

Implementation:
- Modify `ui/battle/glyph_panel.gd`:
  - Replace the portrait `TextureRect` with a `GlyphAnimator` instance
  - Size the animator to match current portrait display size (60-64px)
  - On setup, call `animator.setup(species_id)`
  - Default to idle animation loop
- Wire AnimationQueue events to GlyphAnimator:
  - `attack_started` → `animator.play("attack")`, continue queue on `animation_finished`
  - `damage_dealt` → `animator.play("hurt")`, existing damage number tween plays simultaneously
  - `glyph_ko` → `animator.play("ko")`, then existing grey-out modulate tween
  - All other events (guard, status, etc.) keep using tweens on the animator node
- Ensure `instant_mode` propagation: BattleScene.instant_mode → AnimationQueue.instant_mode → GlyphAnimator.instant_mode
- Fallback: if GlyphAnimator has no sheet, all events just play tweens as before (no regression)

**Status:** Complete (55 tests, 1800 total)

---

### Stage 5: Generate All 18 Species
**Goal:** Run the pipeline for all 18 species, visually verify, commit.
**Success Criteria:** `assets/sprites/glyphs/sheets/` contains 18 `*_sheet.png` files. All pass visual inspection. All tests pass. Battle scenes render animated sprites for all species.
**Tests:** Full test suite passes. Visual spot-check via `launch-game`.

Implementation:
- Run `python3 scripts/generate_sprite_sheet.py --all` (may need retries for quality)
- Run `bash scripts/process_sprite_sheet.sh --all`
- Visual review each sheet — regenerate any that don't match portrait style
- Play-test a full rift to verify animations in context
- Commit all sheets + any script tweaks

**Status:** Complete (18 species generated + processed, 1802 tests pass)
