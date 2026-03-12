# Overnight Session Plan — 2026-03-11

## Stage 1: Art Direction Document
**Goal**: Define a unified visual style guide for all non-glyph art assets
**Status**: Complete

### Context:
The 18 glyph portraits use a consistent style: bold black outlines, flat color fills, no gradients, limited palette, reads at 64x64. All other visual elements (NPC portraits, status icons, room icons) are text/color placeholders. Need a cohesive art direction that matches the glyph style.

### Deliverable: `docs/art-direction.md`
- **Shared principles**: bold outlines, flat fills, limited palettes, high contrast, must read at small sizes
- **NPC portraits** (80x80 render, 512x512 source): character design briefs for Kael (Veteran Warden, red), Lira (Rift Researcher, teal), Maro (Crawler Mechanic, amber). Half-body, expressive faces, distinct silhouettes.
- **Status effect icons** (22x22 render, 128x128 source): 6 status types (Burn, Stun, Weaken, Slow, Corrode, Shield). Simple symbolic icons, colored to match debuff/buff distinction.
- **Room type icons** (24x24 render, 128x128 source): 9 room types (start, exit, enemy, hazard, puzzle, cache, hidden, boss, empty). Distinct shapes, colored per room type.
- **Generation specs**: source resolution, background color (magenta), style prompt fragments

**Success Criteria**: Doc written, reviewed, ready to inform generation prompts

---

## Stage 2: Asset Generation Pipelines
**Goal**: Build `generate_npc_portraits.py`, `generate_icons.py` scripts following `generate_sprites.py` pattern
**Status**: Complete

### Scripts:

#### A. `scripts/generate_npc_portraits.py`
- Reads prompts from art direction doc (or inline)
- Generates 512x512 NPC portraits via Gemini
- Saves raw to `raw/npcs/`
- Processing: background removal, trim, resize to 512x512 (same as glyph pipeline)
- Output: `assets/sprites/npcs/{npc_id}.png`
- Usage: `python3 scripts/generate_npc_portraits.py kael` or `--all`

#### B. `scripts/generate_icons.py`
- Generates status effect and room type icon sets via Gemini
- Two modes: `--type status` and `--type room`
- Generates 128x128 icons with magenta background
- Processing: background removal, resize to final size
- Output: `assets/sprites/icons/status/{status_id}.png`, `assets/sprites/icons/rooms/{room_type}.png`
- Usage: `python3 scripts/generate_icons.py --type status` or `--type room`

### Processing:
- `scripts/process_npc_portraits.sh` — same pipeline as glyph sprites (bg removal + trim + resize)
- `scripts/process_icons.sh` — simpler pipeline (bg removal + resize, no AI cleanup needed at 128x128)

**Success Criteria**: Scripts run, produce PNGs, processing yields clean transparent assets

---

## Stage 3: Integrate NPC Portraits
**Goal**: Load real NPC portrait PNGs in NpcPanel, bastion hub cards
**Status**: Complete

### Implementation:
1. Add NPC art loading to a utility (new `NpcArt` static class or extend existing pattern)
   - Path: `res://assets/sprites/npcs/{npc_id}.png`
   - Fallback: existing colored square + letter (current behavior)
   - Cache like GlyphArt
2. `ui/bastion/npc_panel.gd` — Replace placeholder ColorRect with TextureRect when asset exists
3. `ui/bastion/bastion_scene.gd` — Update NPC hub buttons with portrait thumbnails
4. Tests: verify fallback still works when assets missing, verify texture loads when present

**Success Criteria**: NPC portraits display in bastion, fallback works if PNGs missing

---

## Stage 4: Integrate Status Effect Icons
**Goal**: Load real status icon PNGs in GlyphPanel
**Status**: Complete

### Implementation:
1. Status icon loading utility
   - Path: `res://assets/sprites/icons/status/{status_id}.png`
   - Status IDs: burn, stun, weaken, slow, corrode, shield
   - Fallback: existing colored square + letter
2. `ui/battle/glyph_panel.gd` `_refresh_statuses()` — Try loading icon texture, fall back to letter badge
3. Keep turn count overlay on top of icon (e.g. "2" in corner)
4. Keep buff/debuff border color distinction
5. Tests: verify icons render, verify fallback

**Success Criteria**: Status icons display in battle, turn counts still visible, fallback works

---

## Stage 5: Integrate Room Type Icons
**Goal**: Load real room icon PNGs in RoomNode
**Status**: Complete

### Implementation:
1. Room icon loading utility
   - Path: `res://assets/sprites/icons/rooms/{room_type}.png`
   - Room types: start, exit, enemy, hazard, puzzle, cache, hidden, boss, empty
   - Fallback: existing unicode symbols
2. `ui/dungeon/room_node.gd` — Try loading icon texture, fall back to unicode label
3. Maintain opacity behavior (50% when REVEALED, 100% when VISITED/CURRENT)
4. Tests: verify icons render, verify fallback, verify opacity states

**Success Criteria**: Room icons display in dungeon, state-based opacity works, fallback works

---

## Stage 6: Crawler Equipment Slots
**Goal**: Add Computer + Accessory equipment slots to crawler, with Crawler Bay UI
**Status**: Complete

### Design (from roadmap):
- **Computer slot** — scanning/energy upgrades:
  - Scan Amplifier: scan reveals all rooms on current floor (not just adjacent)
  - Energy Recycler: regenerate 25% energy per floor transition
  - Affinity Filter: +25% capture chance for chosen affinity
  - Capacitor Cell: +40 max energy
- **Accessory slot** — durability/cargo/utility:
  - Hull Plating: +25 hull HP
  - Cargo Rack: +1 bench slot
  - Repair Drone: auto-heal 15 hull HP per floor transition
  - Trophy Mount: +20% capture chance (all affinities)

### Data:
1. `data/crawler_equipment.json` — Equipment definitions with id, name, slot, description, effect
2. Equipment as rare cache drops (weighted random, 15% chance per cache room)
3. 2 milestone-unlocked pieces (Scan Amplifier from clearing 3 rifts, Repair Drone from clearing a major rift)

### Implementation:
1. `data/crawler_equipment.json` — 8 equipment definitions
2. `core/dungeon/crawler_state.gd`:
   - `equipped_computer: String = ""` and `equipped_accessory: String = ""`
   - `owned_equipment: Array[String] = []`
   - `equip(slot, equipment_id)` / `unequip(slot)`
   - `begin_run()` applies equipment bonuses (like chassis bonuses)
   - Hook into `get_effective_hull_hp()`, `get_ability_cost()`, capture calc, energy regen
3. `core/data_loader.gd` — Load equipment data
4. `ui/bastion/crawler_bay.gd` — New Crawler Bay sub-screen (or extend existing chassis UI):
   - Show chassis + computer + accessory slots
   - Click slot → picker popup with owned equipment for that slot type
   - Show stat preview with equipment bonuses
   - Equip before entering a rift
5. `ui/bastion/bastion_scene.gd` — Wire Crawler Bay into bastion nav
6. `ui/dungeon/dungeon_scene.gd` — Equipment effects:
   - Scan Amplifier: modify scan behavior
   - Energy Recycler: add energy on floor transition
   - Affinity Filter: pass bonus to capture calculator
   - Repair Drone: heal hull on floor transition
7. `core/save_manager.gd` — Serialize owned_equipment, equipped slots
8. Cache room drops: add equipment to possible cache rewards
9. Tests: equip/unequip, stat bonuses, save/load, cache drops, effects during rift

**Success Criteria**: 8 equipment pieces, Crawler Bay UI, equip before rift, effects work in dungeon, save/load persists, tests pass

---

## Verification (after each stage)
- `~/bin/godot --headless --script res://tests/test_runner.gd` — all tests pass
- Commit after each stage
- Update `docs/roadmap.md` checkboxes as items complete
