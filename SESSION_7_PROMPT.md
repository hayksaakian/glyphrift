# Session 7 — Dungeon UI

## Context

Sessions 1–6 are complete (481 tests passing). All core logic is headless-tested. Battle UI is done. This session builds the **dungeon exploration UI** — the visual layer on top of `DungeonState`, `CrawlerState`, and `CaptureCalculator`.

Key references:
- **TDD Section 7.2** — DungeonScene tree structure
- **GDD Section 9** — Rift Dungeons (room types, connectivity, fog of war, hazards, items, puzzles)
- Existing core: `core/dungeon/dungeon_state.gd`, `core/dungeon/crawler_state.gd`, `core/dungeon/capture_calculator.gd`, `core/dungeon/rift_generator.gd`

## What to Build

### 1. RoomNode (`ui/dungeon/room_node.gd`)
A clickable Control representing one room on the floor map.

**States:**
- **Unrevealed** — grey "?" icon, type hidden
- **Revealed but unvisited** — type icon at 50% opacity, clickable if adjacent
- **Visited** — type icon at full opacity
- **Current** — highlighted border (player is here)

**Room type icons** (use colored squares with text labels for now — same placeholder pattern as GlyphPanel):

| Type | Icon/Letter | Color |
|------|-------------|-------|
| start | "S" | #44AA44 (green) |
| exit | "E" | #4488FF (blue) |
| enemy | "!" | #FF4444 (red) |
| hazard | "⚠" | #FF8800 (orange) |
| puzzle | "?" | #AA44FF (purple) |
| cache | "◆" | #FFD700 (gold) |
| hidden | "H" | #00DDDD (cyan) |
| boss | "★" | #FF2222 (bright red) |
| empty | "○" | #666666 (grey) |
| unrevealed | "?" | #444444 (dark grey) |

**Size:** 64x64 px per room node.

**Signals:** `room_clicked(room_id: String)`

### 2. FloorMap (`ui/dungeon/floor_map.gd`)
Renders the current floor as a node graph.

- Spawns RoomNode instances positioned at `(room.x * cell_size, room.y * cell_size)` where `cell_size = 100`.
- Draws connections between rooms as `Line2D` segments (dashed for unrevealed rooms, solid for revealed).
- Listens to `DungeonState.room_revealed` and `DungeonState.room_entered` to update room visuals.
- Centers the map in the available viewport area.

### 3. CrawlerHUD (`ui/dungeon/crawler_hud.gd`)
HUD overlay showing Crawler resources and abilities.

**Layout (top of screen, horizontal bar):**
```
[Hull: ████████░░ 80/100]  [Energy: ██████░░░░ 30/50]  [Items: 2/5]  | [Scan] [Reinforce] [Repair] [Purge] [Warp]
```

- Hull bar: green > yellow (25%) > red (10%)
- Energy bar: blue, dims when low
- Ability buttons: show energy cost, greyed out if insufficient energy
- Item slots: show item count, clickable to open item list
- Listens to `CrawlerState.hull_changed` and `CrawlerState.energy_changed`

**Ability costs** (from CrawlerState):
- Scan: 5 energy
- Reinforce: 8 energy
- Field Repair: 12 energy
- Purge: 15 energy
- Emergency Warp: 20 energy

### 4. RoomPopup (`ui/dungeon/room_popup.gd`)
Modal popup when entering a room, showing room details and action button.

**Content by room type:**
- **Enemy:** "Wild Glyphs Ahead!" + [Fight] button → triggers combat
- **Cache:** "Supply Cache Found!" + [Open] button → adds item, shows what was found
- **Hazard:** "Hazard Zone! Crawler takes {N} damage." + [Continue] button (damage already applied by DungeonState)
- **Puzzle:** "Puzzle Room" + description + [Attempt] button (puzzles are Session 9 — for now stub with auto-complete)
- **Boss:** "RIFT GUARDIAN: {species_name}" + [Challenge] button → triggers boss combat
- **Empty:** "Nothing here." + [Continue] button
- **Exit:** "Descend to next floor?" + [Descend] button → triggers floor transition
- **Hidden (after reveal):** Like cache but with rare items

### 5. DungeonScene (`ui/dungeon/dungeon_scene.gd`)
Main orchestrator (mirrors BattleScene pattern).

**Scene tree (all programmatic, no .tscn):**
```
DungeonScene (Control)
├── Background (ColorRect)
├── FloorMap (Control)
├── CrawlerHUD (CanvasLayer or Control at top)
├── RoomPopup (PanelContainer, centered, hidden by default)
└── FloorTransitionOverlay (ColorRect + Label, for floor change animation)
```

**Flow:**
1. `start_rift(dungeon_state: DungeonState)` — receives initialized DungeonState
2. FloorMap renders current floor from `dungeon_state.floors[current_floor]`
3. Player clicks adjacent RoomNode → `dungeon_state.move_to_room(id)`
4. DungeonState emits `room_entered` → DungeonScene shows RoomPopup
5. If enemy/boss room → RoomPopup [Fight] → emit `combat_requested(enemy_squad, boss_def)` signal (parent scene handles starting BattleScene)
6. If exit room → `dungeon_state.move_to_room()` handles floor transition → FloorMap rebuilds
7. If hull reaches 0 → `dungeon_state.forced_extraction()` → emit `rift_failed` signal

**Signals:**
- `combat_requested(enemies: Array[GlyphInstance], boss_def: BossDef)`
- `capture_requested(wild_glyph: GlyphInstance)` — after winning a wild battle
- `rift_completed(won: bool)`
- `floor_changed(floor_number: int)`

### 6. CapturePopup (`ui/dungeon/capture_popup.gd`)
After winning a wild glyph battle, show capture opportunity.

```
┌─────────────────────────────────┐
│     WILD GLYPH DEFEATED!        │
│                                 │
│  [art placeholder]  Stonepaw    │
│                     Ground T1   │
│                                 │
│  Capture Chance: 65%            │
│                                 │
│  [Attempt Capture]  [Release]   │
│                                 │
│  Result: CAPTURED! / ESCAPED!   │
└─────────────────────────────────┘
```

- Uses `CaptureCalculator.calculate()` for probability display
- On capture attempt: roll against probability, show result
- Captured glyph → emit signal for parent to add to roster/cargo

## Test Plan (`tests/test_dungeon_ui.gd`)

Follow existing test pattern (extends SceneTree, _init + await process_frame).

**Test groups:**
1. **RoomNode** — construction, state changes (unrevealed/revealed/visited/current), click signal
2. **FloorMap** — room positioning from template data, connection lines exist, room state updates on signals
3. **CrawlerHUD** — hull/energy bar values, ability button enable/disable based on energy, cost labels
4. **RoomPopup** — correct content per room type, action button text, visibility toggle
5. **DungeonScene** — full flow: start rift → click room → popup → continue → floor transition
6. **CapturePopup** — probability display, capture/release buttons, result display
7. **Signal wiring** — DungeonState signals update UI correctly (room_revealed, room_entered, crawler_damaged, floor_changed)
8. **Fog of war** — unrevealed rooms show "?", scan reveals adjacent, room entry reveals type

**Target: ~80–100 tests**

## Architecture Notes

- **Same patterns as BattleScene**: all UI built programmatically in GDScript (no .tscn files), injectable dependencies, instant_mode for testing
- **DungeonScene does NOT own DungeonState** — it receives it via `start_rift()`, same as BattleScene receives CombatEngine
- **Combat integration**: DungeonScene emits `combat_requested` signal. The parent game scene handles switching to BattleScene and back. DungeonScene does not import or instantiate BattleScene.
- **Wild glyph generation**: Use existing logic from `test_full_loop.gd` — pick species from `template.wild_glyph_pool`, filter by `enemy_tier_pool`, create 1–3 enemies
- **Item pickup**: When opening a cache, pick a random item from `DataLoader.items` and call `crawler_state.add_item()`
- **Puzzle rooms**: Stub for now — auto-complete with a reward. Puzzle UI is Session 9.

## Execution Order

1. RoomNode (standalone component, testable in isolation)
2. FloorMap (renders rooms, depends on RoomNode)
3. CrawlerHUD (standalone, depends on CrawlerState signals)
4. RoomPopup (standalone modal)
5. CapturePopup (standalone modal)
6. DungeonScene (orchestrator, wires everything together)
7. Tests for all components
8. Screenshot harness for visual verification

## Verification

1. `~/bin/godot --headless --script res://tests/test_dungeon_ui.gd` — ~80-100 pass
2. All prior test suites still pass (481 existing)
3. Visual verification via screenshot harness
