# Overnight Session Plan

## Stage 1: Fix Open Bugs
**Goal**: Fix BUG-023 and BUG-024
**Status**: Complete (commit 7303123)

### BUG-023: KO'd attacker still resolves after interrupt
- In `combat_engine.gd` `_resolve_interrupt`: after `_check_ko(attacker, defender)`, check `if attacker.is_knocked_out: return true` to cancel the attack
- Apply to both `static_guard` and `null_counter` interrupt paths
- Write test: set up guard interrupt that KOs attacker, verify attacker's move doesn't resolve

### BUG-024: Terradon solo mastery too easy
- Change terradon's solo objective in `glyphs.json` to require T2+ enemies
- Add tier check in `mastery_tracker.gd` for the solo win evaluation
- Write test: solo win against T1 should NOT count, solo win against T2+ should count

**Success Criteria**: Both bugs fixed, tests pass, bugs.md updated

---

## Stage 2: Battle Loss Penalty Rework
**Goal**: Make losing a battle cost energy instead of being free
**Status**: Complete (commit d278b8e)

### Design (confirmed with Hayk):
- **On loss**: Force-open Field Repair picker. Player MUST heal at least 1 glyph before closing. If not enough energy for 1 heal → emergency warp out of rift.
- **On flee**: No penalty, no benefit. Room stays uncleared.
- **Partial progress**: Enemies defeated during the fight don't re-appear. Surviving enemies fully heal.
- **No free revives** mid-rift. Remove current "revive all KOs + heal to 30% HP" on loss.
- **Boss special-case**: Remove if general logic covers it (loss = forced heal or extraction).

### Implementation:
1. `dungeon_scene.gd` — `on_combat_finished(won=false)`:
   - Remove free revive/heal logic
   - Track which enemies were KO'd during battle (need to compare pre/post enemy lists)
   - Update room data to remove defeated enemies
   - Check energy ≥ field_repair cost → force-open repair picker in "must heal" mode
   - If energy < cost → trigger emergency warp
2. `dungeon_scene.gd` — `_show_repair_picker()`:
   - Add `forced: bool` parameter. When forced, hide Cancel button, require at least 1 heal before allowing close.
3. `dungeon_scene.gd` — flee handling:
   - Room stays uncleared (type stays "enemy"/"boss"), player returns to map
4. Room enemy persistence:
   - Store defeated enemy IDs in room dict so re-entering generates fewer enemies
5. Tests: loss → forced heal, loss with no energy → extraction, flee → room uncleared, partial enemy persistence

**Success Criteria**: Losing costs energy, no free revives, flee is safe but doesn't clear room, tests pass

---

## Stage 3: T4 Mastery Objectives
**Goal**: Give Voltarion, Lithosurge, Nullweaver meaningful endgame mastery tracks
**Status**: Complete (commit 903953a)

### Design direction (confirmed with Hayk):
- Each T4 gets 1 boss-related mastery objective + endurance/difficulty challenges
- Should be hard but not impossible — test T3+ encounters, not T1 cheese
- Thematic to each species' identity

### Proposed objectives:

**Voltarion** (Electric T4 — aggressive attacker):
- Fixed 1: "Defeat a Ground-type boss with this Glyph in squad" (type disadvantage boss kill)
- Fixed 2: "Win a battle in 3 turns or fewer" (blitz challenge)
- Random pool: [KO 3+ enemies in one battle, deal 100+ damage in a single hit, win without using support techniques]

**Lithosurge** (Ground T4 — defensive wall):
- Fixed 1: "Defeat a Water-type boss with this Glyph in squad" (type disadvantage boss kill)
- Fixed 2: "Clear a standard+ rift with all squad glyphs at full HP at the end" (endurance)
- Random pool: [take 200+ total damage in one battle without being KO'd, win a battle using Guard 3+ times, win solo against T2+ enemies]

**Nullweaver** (Water T4 — control/debuff):
- Fixed 1: "Defeat an Electric-type boss with this Glyph in squad" (type disadvantage boss kill)
- Fixed 2: "Win a battle where all enemies had a status effect when KO'd" (control mastery)
- Random pool: [apply 5+ status effects in one battle, win without any squad member being KO'd, KO an enemy with a status effect tick]

### Implementation:
1. `data/glyphs.json` — Add mastery objectives for the 3 T4 species
2. `core/glyph/mastery_tracker.gd` — Add evaluation logic for new objective types:
   - `defeat_boss_affinity` — check boss KO + boss affinity matches target
   - `win_in_n_turns` — check turn count ≤ N
   - `clear_rift_full_hp` — check on rift completion (all squad at max HP)
   - `enemies_statused_on_ko` — track status state at KO time
   - `solo_win_min_tier` — existing solo check + enemy tier ≥ N
3. Tests for each new objective type

**Success Criteria**: All 3 T4 species have 2 fixed + 3 random mastery objectives, tracker evaluates them, tests pass

---

## Stage 4: Neutral Affinity Type
**Goal**: Add 2 neutral T1 species that fuse into 1 neutral T2
**Status**: Not Started

### Design (confirmed with Hayk):

**Aesthetic**: Monochrome arcane — slate grey body, charcoal outlines, silver/pale blue accent marks (rune lines, crystalline veins). "Raw material of the rift" — ancient, stable, adaptable.

**Species**:
- **T1 Melee**: ~"Gritstone" or similar — a small dense creature, melee attacker + utility move
- **T1 Ranged**: ~"Shimmer" or similar — a wispy creature, ranged attacker + support move
- **T2 Fusion result**: ~"Monolith" or similar — balanced generalist, utility toolkit

**Techniques** (4-5 new neutral techniques):
- Melee attack (T1 melee native)
- Ranged attack (T1 ranged native)
- Utility move — e.g. Brace equivalent or stat buff
- Support move — e.g. minor heal or cleanse
- T2 signature — stronger utility or AoE

**Fusion logic**:
- Neutral + Neutral → Neutral T2 (explicit fusion table entry)
- Neutral + any non-neutral → same result as non-neutral + non-neutral (wildcard). Implementation: in `lookup_fusion`, if one parent is neutral, substitute the other parent's species ID for both parents in the lookup.

**Type interactions**: Already handled — `get_affinity_multiplier` returns 1.0x for neutral attack/defense. No SE advantage or disadvantage.

**Affinity color**: Already defined as `#888888` with ⚪ emoji in `core/affinity.gd`. Update to silver/cool grey `#A0A8B0` to match the monochrome arcane aesthetic.

### Implementation:
1. `data/glyphs.json` — Add 3 species (2 T1 + 1 T2) with stats, mastery objectives
2. `data/techniques.json` — Add 4-5 neutral techniques
3. `data/fusion_table.json` — Add neutral + neutral → T2 entry
4. `core/data_loader.gd` — Update `lookup_fusion` to handle neutral wildcard: if one parent is neutral affinity, treat as if both parents are the non-neutral species
5. `core/affinity.gd` — Update neutral color to `#A0A8B0`
6. `data/rift_templates.json` — Add neutral T1s to early rift wild_glyph_pools (tutorial, minor rifts)
7. `docs/glyph-sprite-prompts.md` — Write prompts for the 3 new species following existing format
8. Tests: fusion wildcard logic, damage calc neutrality, species load correctly

**Success Criteria**: 3 new species in game, fusion wildcard works, neutral appears in early rifts, all tests pass

---

## Stage 5: Sprite Transparency Fix
**Goal**: Fix interior white pockets in existing glyph sprites
**Status**: Complete (commit a47b09d)

### Problem:
`scripts/process_sprites.sh` only flood-fills from the 4 image edges, so enclosed white pockets between limbs/body parts survive. Affected: ironbark (arm/torso gap), thunderclaw (tail/hind leg gap), others.

### Implementation:
1. Enhance `scripts/process_sprites.sh` with a 2nd pass after edge flood-fill
2. Use ImageMagick `-connected-components` to identify remaining white/near-white regions
3. Remove regions below a size threshold (e.g. <5% of image area) that don't touch the border
4. Preserve intentional white features (eyes, teeth, lightning) by only targeting small interior pockets
5. Re-process all 15 existing sprites and verify results

**Success Criteria**: Interior white pockets removed from all sprites, no intentional features damaged

---

## Stage 6: Font Size Setting
**Goal**: Add font size accessibility option
**Status**: Not Started

### Implementation:
1. `core/game_settings.gd` — Add `font_size` setting (Small/Normal/Large) with values like 0.85/1.0/1.2
2. `ui/shared/settings_popup.gd` — Add font size toggle to settings UI
3. Apply font scale globally via theme override or root control scale
4. Persist to `user://settings.json` alongside battle_speed

**Success Criteria**: Font size setting works, persists across sessions, all UI readable at each size

---

## Stage 7: Neutral Boss Rift
**Goal**: Add a new minor rift with the neutral T2 as boss
**Status**: Not Started

### Design:
- Tier: minor (same as minor_01 through minor_03)
- Boss: neutral T2 species (from Stage 4)
- Wild pool: mix of neutral T1s + existing T1s from other affinities
- 3-4 floors, similar layout complexity to existing minor rifts
- Hazard damage: 10 (minor tier standard)
- Phase unlock: available alongside other minor rifts (phase 1-2)

### Implementation:
1. `data/rift_templates.json` — Add new rift template with floors, rooms, connections, boss config
2. `data/bosses.json` or inline boss config — Define neutral T2 boss with appropriate techniques and phase 2 bonus
3. `core/game_state.gd` — Ensure new rift appears in rift availability at appropriate phase
4. Tests: rift loads, boss generates correctly, wild pool works

**Success Criteria**: New rift playable, boss encounter works, appears at correct phase

---

## Stage 8: Sprite Generation Pipeline + Neutral Sprites (DEFERRED — needs billing upgrade)
**Goal**: Build automated sprite generation script, generate sprites for the 3 new neutral species
**Status**: Blocked — free tier rate limits. Hayk to link Google Cloud billing for Tier 1 access.

### Setup:
- Gemini API key stored in `.env` (gitignored)
- Python script: `scripts/generate_sprites.py`
- Uses `google-genai` SDK (install via pip if needed)

### Script features:
- Takes species ID + prompt text (or looks up from `docs/glyph-sprite-prompts.md`)
- Calls Gemini API to generate image
- Saves raw output to `raw/` directory
- Optionally generates multiple candidates (3-5) for human review
- Fails gracefully with clear message if key is missing or API errors

### Pipeline integration:
- Raw PNG → `scripts/process_sprites.sh` (background removal, trim, resize to 512x512, silhouette generation)
- Output: `assets/sprites/glyphs/{species_id}_portrait.png` + `{species_id}_silhouette.png`
- Test: `GlyphArt.get_portrait()` returns the new texture instead of placeholder

### Sprite prompts for neutral species:
- Write prompts following existing format in `docs/glyph-sprite-prompts.md`
- Monochrome arcane aesthetic: slate grey body, charcoal outlines, silver/pale blue accent marks
- Generate sprites for all 3 neutral species
- Save multiple candidates if quality varies — best one goes into `assets/`

**Success Criteria**: `generate_sprites.py` works end-to-end, 3 neutral species have real portraits, process pipeline produces clean results

---

## Verification (after each stage)
- `~/bin/godot --headless --script res://tests/test_runner.gd` — all tests pass
- Update `docs/bugs.md` for bug fixes
- Commit after each stage
- Update memory file after significant completions
