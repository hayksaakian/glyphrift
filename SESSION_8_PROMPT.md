# Session 8 — Bastion UI + Game Loop Integration

## Context

Sessions 1–7 are complete (662 tests passing). All core logic is headless-tested. Battle UI and Dungeon UI work independently. This session builds the **Bastion hub** (home base between rift runs) and **wires everything together** into a playable end-to-end game loop.

Key references:
- **TDD Section 7.3** — FusionChamber scene tree
- **GDD Sections 7.7, 11.1** — Fusion UX flow, Bastion facilities
- Existing core: `core/game_state.gd`, `core/progression/roster_state.gd`, `core/progression/codex_state.gd`, `core/glyph/fusion_engine.gd`
- Existing UI: `ui/battle/battle_scene.gd`, `ui/dungeon/dungeon_scene.gd`

## What to Build

### 1. GlyphCard (`ui/shared/glyph_card.gd`)
Reusable compact glyph display used across Barracks, Fusion, and squad views.

**Layout (120x160):**
```
┌──────────────┐
│  [Affinity   │
│   colored    │
│   square +   │
│   initial]   │
│              │
│  Zapplet     │
│  Electric T1 │
│  GP: 2       │
│  HP:25 ATK:8 │
│  ████████ ✓  │  ← mastery bar + checkmark if mastered
└──────────────┘
```

- Affinity-colored art placeholder (same pattern as GlyphPanel: color + initial letter)
- Species name, affinity, tier
- GP cost
- Key stats (HP, ATK)
- Mastery progress bar (filled if mastered, with ✓ icon)
- Signal: `card_clicked(glyph: GlyphInstance)`
- Visual states: normal, selected (highlighted border), disabled (greyed out, for non-mastered in fusion)

### 2. Barracks (`ui/bastion/barracks.gd`)
View and manage your glyph roster + active squad.

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│  BARRACKS                                               │
│                                                         │
│  Active Squad (GP: 6/12)          Reserves              │
│  ┌────┐ ┌────┐ ┌────┐           ┌────┐ ┌────┐         │
│  │Card│ │Card│ │Card│           │Card│ │Card│         │
│  │    │ │    │ │    │           │    │ │    │         │
│  └────┘ └────┘ └────┘           └────┘ └────┘         │
│  [Front] [Back] [Front]                                 │
│                                                         │
│  Click a glyph to move between squad ↔ reserves         │
│  GP Capacity: 6/12  |  Squad: 3/3  |  Reserves: 2/2   │
│                                                         │
│  [Done]                                                 │
└─────────────────────────────────────────────────────────┘
```

- Shows active squad (up to `crawler_state.slots`) and reserves (up to `crawler_state.cargo_slots`)
- Click a squad glyph → moves to reserves (if reserve slots available)
- Click a reserve glyph → moves to squad (if squad not full AND GP fits within `crawler_state.capacity`)
- Row assignment: each squad glyph has a [Front]/[Back] toggle button beneath it
- GP counter updates live: "GP: {current_total}/{crawler_state.capacity}"
- Squad/reserve counters: "Squad: {n}/{slots} | Reserves: {n}/{cargo_slots}"
- Formation persists on the GlyphInstance via `row_position` property ("front"/"back")
- Signal: `done_pressed()`

### 3. FusionChamber (`ui/bastion/fusion_chamber.gd`)
Select two mastered glyphs, preview result, confirm fusion.

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│  FUSION CHAMBER                                         │
│                                                         │
│  Parent A          +          Parent B                  │
│  ┌────────┐                  ┌────────┐                │
│  │  Card  │                  │  Card  │                │
│  │  slot  │                  │  slot  │                │
│  └────────┘                  └────────┘                │
│                                                         │
│  ── Available Glyphs (mastered only) ──                 │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                  │
│  │Card│ │Card│ │Card│ │Card│ │Card│                  │
│  └────┘ └────┘ └────┘ └────┘ └────┘                  │
│                                                         │
│  ── Preview ──                          [Fuse!]         │
│  Result: Thunderclaw (Electric T2)                      │
│  Stats: HP+3 ATK+2 DEF+1 SPD+1 RES+1                  │
│  Techniques: [pick up to 4]                             │
│  GP: 4  ⚠ Over capacity!                              │
│                                                         │
│  [Back]                                                 │
└─────────────────────────────────────────────────────────┘
```

**Flow:**
1. Show mastered glyphs in the picker grid (non-mastered greyed out with "Not Mastered" label)
2. Click a glyph → fills Parent A slot (or Parent B if A is filled)
3. Click a filled parent slot → clears it back to picker
4. When both parents set, call `fusion_engine.can_fuse(a, b)`:
   - If invalid → show reason text (e.g., "T4 cannot fuse")
   - If valid → call `fusion_engine.preview_fusion(a, b)` and show preview panel
5. Preview shows: result tier, affinity, species name (or "???" if undiscovered), stat inheritance bonuses, technique selection
6. Technique selection: show all inheritable techniques from both parents. Player toggles up to `num_technique_slots` (typically 4). Selected techniques have highlight.
7. GP warning: if result GP > `crawler_state.capacity`, show yellow "⚠ Over capacity!" text
8. [Fuse!] button: calls `fusion_engine.execute_fusion(a, b, selected_technique_ids)`
9. Discovery overlay: if new species, flash "NEW DISCOVERY!" animation then show result GlyphCard
10. Signal: `back_pressed()`

### 4. RiftGate (`ui/bastion/rift_gate.gd`)
Select and enter available rifts.

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│  RIFT GATE                                              │
│                                                         │
│  ┌──────────────────────┐  ┌──────────────────────┐   │
│  │ Initiation Rift      │  │ The Frayed Edge      │   │
│  │ Minor · 3 Floors     │  │ Minor · 4 Floors     │   │
│  │ Boss: Thunderclaw    │  │ Boss: Ironbark        │   │
│  │ ✓ CLEARED            │  │                       │   │
│  │ [Enter]              │  │ [Enter]               │   │
│  └──────────────────────┘  └──────────────────────┘   │
│                                                         │
│  [Back]                                                 │
└─────────────────────────────────────────────────────────┘
```

- Lists rifts from `game_state.get_available_rifts()`
- Each rift card shows: name, tier, floor count, boss species name
- Cleared rifts show "✓ CLEARED" marker (from `codex_state.is_rift_cleared()`)
- [Enter] button → emit signal to start the rift
- Signals: `rift_selected(template: RiftTemplate)`, `back_pressed()`

### 5. BastionScene (`ui/bastion/bastion_scene.gd`)
Hub screen with navigation to facilities.

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│                     BASTION                             │
│                                                         │
│  [Rift Gate]     [Barracks]     [Fusion Chamber]       │
│                                                         │
│  Phase 1 · 0 Rifts Cleared · 3 Glyphs · 20% Codex    │
│                                                         │
│  ── Active Squad ──                                     │
│  ┌────┐ ┌────┐ ┌────┐                                 │
│  │Card│ │Card│ │Card│                                 │
│  └────┘ └────┘ └────┘                                 │
└─────────────────────────────────────────────────────────┘
```

- Three facility buttons that switch to the corresponding sub-screen
- Status bar: phase, rifts cleared, glyph count, codex discovery %
- Quick squad preview at bottom (read-only GlyphCards of active squad)
- Sub-screens (Barracks, FusionChamber, RiftGate) are shown/hidden as children — not separate scenes
- Signals: `rift_selected(template: RiftTemplate)`

### 6. MainScene (`ui/main_scene.gd`)
Top-level orchestrator that manages the full game loop.

**Scene tree (all programmatic):**
```
MainScene (Control)
├── BastionScene
├── DungeonScene
├── BattleScene
└── TransitionOverlay (ColorRect for fade transitions)
```

**State machine (follows GameState.State):**
- `BASTION` → BastionScene visible, others hidden
- `RIFT` → DungeonScene visible
- `COMBAT` → BattleScene visible

**Flow:**
1. `start_game()` → `game_state.start_new_game()` → show BastionScene
2. BastionScene emits `rift_selected(template)` → fade to DungeonScene → `game_state.start_rift(template)` → `dungeon_scene.start_rift(game_state.current_dungeon)`
3. DungeonScene emits `combat_requested(enemies, boss_def)` → fade to BattleScene → `battle_scene.start_battle(roster_state.active_squad, enemies, boss_def)`
4. BattleScene emits `battle_finished(won)` → fade back to DungeonScene → `dungeon_scene.on_combat_finished(won, enemies)`
5. DungeonScene emits `capture_requested(glyph)` → handle capture (add to roster if successful)
6. DungeonScene emits `rift_completed(won)` → if won: `game_state.complete_rift(rift_id)` → heal all glyphs → fade to BastionScene
7. Repeat from step 2

**Scene transitions:** Use fade-to-black (0.15s fade out, 0.15s fade in, same as floor transition speed).

**HP persistence:** Glyph HP persists during a rift (between battles). Heal all glyphs when returning to Bastion (between rifts).

**Squad info during dungeon:** Add a small squad status panel to DungeonScene showing active squad glyph names + HP bars. This lets the player see their team's state while exploring.

### 7. SquadOverlay (`ui/dungeon/squad_overlay.gd`)
Small panel showing squad status during dungeon exploration.

**Layout (right side of screen, vertical):**
```
┌──────────┐
│ Zapplet  │
│ ████░ 20 │
│ Stonepaw │
│ ████░ 25 │
│ Driftwisp│
│ ███░░ 15 │
└──────────┘
```

- Shows each glyph in active squad: name + HP bar + current HP number
- HP bars color-coded (green > yellow > red, same thresholds as CrawlerHUD)
- Read-only during exploration — just informational
- Updates when HP changes during combat

## Test Plan (`tests/test_bastion_ui.gd`)

Follow existing test pattern (extends SceneTree, _init + await process_frame).

**Test groups:**
1. **GlyphCard** — construction, display values, click signal, selected/disabled states, mastery indicator
2. **Barracks** — roster display, squad ↔ reserve moves, GP capacity enforcement, row assignment, slot limits
3. **FusionChamber** — parent selection, can_fuse validation, preview display, technique selection, execute fusion, discovery flag, GP warning
4. **RiftGate** — rift list from game_state, cleared markers, enter signal
5. **BastionScene** — facility navigation, status bar values, squad preview
6. **MainScene** — full game loop: bastion → rift → combat → back to bastion, state transitions, HP persistence
7. **SquadOverlay** — displays squad HP, updates on damage

**Target: ~80–120 tests**

## Architecture Notes

- **Same patterns as Sessions 6–7**: all UI built programmatically in GDScript (no .tscn files), injectable dependencies, instant_mode for testing
- **MainScene owns all sub-scenes** — creates them once, shows/hides as needed
- **GameState drives transitions** — MainScene listens to `game_state.state_changed` and switches visible scene
- **All dependencies injected** — no autoloads in UI classes (except DataLoader which is the one true autoload)
- **Fade transitions** — reuse the same pattern as DungeonScene floor transitions (ColorRect tween)
- **Child mouse_filter** — remember to set `MOUSE_FILTER_IGNORE` on decorative children inside clickable controls (lesson from Session 7)

## Key API Reference

**GameState:**
```
start_new_game() → initializes roster with 3 starters, discovers them in codex
get_available_rifts() → Array[RiftTemplate] based on game_phase
start_rift(template) → creates DungeonState, transitions to RIFT
complete_rift(rift_id) → marks cleared, checks phase advancement
transition_to(State) → changes state, emits state_changed
```

**RosterState:**
```
all_glyphs: Array[GlyphInstance]
active_squad: Array[GlyphInstance]
add_glyph(glyph), remove_glyph(glyph), set_active_squad(squad)
get_mastered_glyphs() → Array[GlyphInstance]
```

**FusionEngine:**
```
can_fuse(a, b) → {valid: bool, reason: String}
preview_fusion(a, b) → {result_tier, result_affinity, result_species_name, inheritance_bonuses, inheritable_techniques_a/b, num_technique_slots, result_gp}
execute_fusion(a, b, inherited_technique_ids) → GlyphInstance
```

**CrawlerState:**
```
capacity: int = 12 (max GP in squad)
slots: int = 3 (max squad size)
cargo_slots: int = 2 (reserve slots)
```

**BattleScene:**
```
combat_engine: Node (set before start_battle)
start_battle(player_squad, enemy_squad, boss_def = null)
signal battle_finished(won: bool)
```

**DungeonScene:**
```
data_loader: Node (set before start_rift)
start_rift(dungeon_state)
on_combat_finished(won, enemies)
on_capture_done()
signal combat_requested(enemies, boss_def)
signal capture_requested(wild_glyph)
signal rift_completed(won)
instant_mode: bool (for testing)
```

## Execution Order

1. GlyphCard (shared component, testable in isolation)
2. Barracks (depends on GlyphCard, RosterState, CrawlerState)
3. FusionChamber (depends on GlyphCard, FusionEngine)
4. RiftGate (depends on GameState, CodexState)
5. BastionScene (orchestrates Barracks, FusionChamber, RiftGate)
6. SquadOverlay (small dungeon addition)
7. MainScene (top-level orchestrator, wires full game loop)
8. Tests for all components
9. Launch script: `launch-game` (runs MainScene as main scene)

## Verification

1. `~/bin/godot --headless --script res://tests/test_bastion_ui.gd` — ~80-120 tests pass
2. All prior test suites still pass (662 existing)
3. `./launch-game` — playable end-to-end: start → bastion → pick rift → explore dungeon → fight enemies → capture glyphs → defeat boss → return to bastion → fuse → repeat
