# Session 6: Battle UI — Implementation Prompt

## Project Context

Glyphrift is a dungeon-crawling monster-fusion RPG built in Godot 4.6.1 with GDScript. Sessions 1–5 are complete with 347 tests passing across 4 test suites. The entire game logic layer works — combat, mastery, fusion, dungeon crawling, and game state — and is playable as a text adventure (`tests/test_full_loop.gd`). No `.tscn` scenes exist yet. Session 6 is the first UI work.

**Environment:** Godot 4.6.1 at `~/bin/godot`. Run tests: `~/bin/godot --headless --script res://tests/test_<name>.gd`

**Docs:** `glyphrift-design-doc-v0.3.md` (GDD), `glyphrift-tdd-v1.1.md` (TDD)

## Project File Structure

```
resources/
  glyph_species.gd      # GlyphSpecies Resource (@export props)
  technique_def.gd       # TechniqueDef Resource
  boss_def.gd            # BossDef Resource
  rift_template.gd       # RiftTemplate Resource
  item_def.gd            # ItemDef Resource
  status_effect_def.gd   # StatusEffectDef Resource
data/
  glyphs.json            # 15 species (6 T1 + 3 T2 + 3 T3 + 3 T4)
  techniques.json        # 39 techniques
  fusion_table.json      # 33 fusion pairs
  mastery_pools.json     # Tier 1/2/3 random objective pools
  items.json             # 5 item types
  rift_templates.json    # 7 rifts (tutorial, 2 minor, 2 standard, 1 major, 1 apex)
  bosses.json            # 7 boss definitions
  codex_entries.json, npc_dialogue.json, crawler_upgrades.json
core/
  data_loader.gd         # Loads all JSON → Resource objects. Properties: species{}, techniques{}, items{}, bosses{}, rift_templates[], etc.
  game_state.gd          # GameState: State enum {TITLE, BASTION, RIFT, COMBAT, PUZZLE}, phase advancement, start_new_game/start_rift/complete_rift
  combat/
    combat_engine.gd     # CombatEngine (extends Node): start_battle(), set_formation(), submit_action(), auto_battle flag. 18 signals.
    damage_calculator.gd # Static damage math (GDD 8.8 formula)
    turn_queue.gd        # SPD-based turn ordering, boss-last round 1, get_preview(count)
    status_manager.gd    # Status apply/tick/expire/immunity
    ai_controller.gd     # Enemy AI: static decide() → {action, technique, target}
  glyph/
    glyph_instance.gd    # GlyphInstance (RefCounted): runtime glyph with stats, combat state, mastery state
    mastery_tracker.gd   # MasteryTracker (RefCounted): connects to CombatEngine signals, evaluates 18+ objective types
    fusion_engine.gd     # FusionEngine (extends Node): can_fuse/preview_fusion/execute_fusion
  dungeon/
    dungeon_state.gd     # DungeonState (RefCounted): floor/room navigation, fog of war, hazard damage
    crawler_state.gd     # CrawlerState (extends Node): hull/energy/items, abilities
    capture_calculator.gd # Static capture probability formula
    rift_generator.gd    # Static floor generation from templates
  progression/
    codex_state.gd       # CodexState (extends Node): discovered species, fusion log, rifts cleared
    roster_state.gd      # RosterState (extends Node): glyph collection, active squad
tests/
  test_data_loader.gd    # 20 tests
  test_combat.gd         # 78 tests
  test_mastery_fusion.gd # 135 tests
  test_dungeon.gd        # 114 tests
  test_full_loop.gd      # Interactive text adventure (playable via stdin)
```

## Key Patterns

- **Static typing everywhere** per TDD 2.2
- **Injectable dependencies** — all systems accept deps as properties, no reliance on autoloads (tests instantiate manually). CombatEngine has `data_loader` property; FusionEngine has `data_loader`, `codex_state`, `roster_state`.
- **Signal-driven architecture** — CombatEngine emits signals for every event; UI should connect to these.
- Test scripts extend `SceneTree` and use `_init()` + `await process_frame`
- New `class_name` files need `godot --headless --editor --quit` to update class cache before tests can resolve them

## Session 6 Goal

Render the combat system visually. Build the Battle UI scene that connects to the existing CombatEngine. **All combat logic already works** — Session 6 is purely presentation.

**Approach from TDD:** Start with placeholder colored rectangles for Glyph sprites. Focus on:
1. Formation drag-and-drop (or click-to-assign)
2. Turn order bar updates
3. Action menu flow (Attack → technique list → target select → resolve)
4. HP bar animations
5. Interrupt visual flash

## CombatEngine API

### Starting a Battle
```gdscript
# CombatEngine is an extends Node with these key members:
var phase: int  # BattlePhase enum
var data_loader: Node
var player_squad: Array[GlyphInstance]
var enemy_squad: Array[GlyphInstance]
var turn_queue: TurnQueue
var current_actor: GlyphInstance
var auto_battle: bool  # false for player control
var is_boss_battle: bool

enum BattlePhase { INACTIVE, FORMATION, TURN_ACTIVE, ANIMATING, VICTORY, DEFEAT }

func start_battle(p_squad: Array[GlyphInstance], e_squad: Array[GlyphInstance], boss_def: BossDef = null) -> void
func set_formation(player_positions: Dictionary = {}, enemy_positions: Dictionary = {}) -> void
  # player_positions = {glyph_instance_id: "front"/"back"}. Empty = auto-assign.
func submit_action(action: Dictionary) -> void
  # action = {"action": "attack"|"guard"|"swap", "technique": TechniqueDef, "target": GlyphInstance}
  # For guard: {"action": "guard"}
  # For swap: {"action": "swap", "target": GlyphInstance}
```

### Signals (connect to these for UI updates)
```gdscript
signal battle_started(player_squad: Array[GlyphInstance], enemy_squad: Array[GlyphInstance])
signal turn_started(glyph: GlyphInstance, turn_index: int)
signal technique_used(user: GlyphInstance, technique: TechniqueDef, target: GlyphInstance, damage: int)
signal glyph_ko(glyph: GlyphInstance, attacker: GlyphInstance)
signal glyph_dealt_finishing_blow(attacker: GlyphInstance, target: GlyphInstance)
signal interrupt_triggered(defender: GlyphInstance, technique: TechniqueDef, attacker: GlyphInstance)
signal status_applied(target: GlyphInstance, status_id: String)
signal status_expired(target: GlyphInstance, status_id: String)
signal status_resisted(target: GlyphInstance, status_id: String)
signal status_immune(target: GlyphInstance, status_id: String)
signal affinity_advantage_hit(attacker: GlyphInstance, target: GlyphInstance)
signal guard_activated(glyph: GlyphInstance)
signal swap_performed(glyph_a: GlyphInstance, glyph_b: GlyphInstance)
signal battle_won(player_squad: Array[GlyphInstance], turns_taken: int, ko_list: Array[GlyphInstance])
signal battle_lost(player_squad: Array[GlyphInstance])
signal turn_queue_updated(queue: Array[GlyphInstance])
signal phase_transition(boss: GlyphInstance)
signal burn_damage(glyph: GlyphInstance, damage: int)
signal round_started(round_number: int)
```

### Flow
1. `battle_started` fires after `start_battle()`
2. Engine waits at `FORMATION` phase until `set_formation()` is called
3. After `set_formation()`, engine enters `TURN_ACTIVE` and auto-advances enemy turns
4. On player turns, engine pauses at `current_actor` — UI calls `submit_action()` to continue
5. `battle_won` or `battle_lost` fires when one side is fully KO'd

### TurnQueue
```gdscript
turn_queue.get_preview(6)  # Returns Array[GlyphInstance] — next 6 actors
turn_queue.get_all()       # Full queue for the round
```

## GlyphInstance Key Properties
```gdscript
var species: GlyphSpecies     # .id, .name, .tier, .affinity, .gp_cost, .base_hp/atk/def/spd/res
var techniques: Array[TechniqueDef]
var max_hp, current_hp, atk, def_stat, spd, res: int
var row_position: String      # "front" or "back"
var side: String              # "player" or "enemy"
var is_knocked_out: bool
var is_guarding: bool
var active_statuses: Dictionary  # status_id → turns remaining
var cooldowns: Dictionary        # technique_id → turns remaining
var is_boss: bool
var boss_phase: int              # 1 or 2
var is_mastered: bool
func is_technique_ready(tech: TechniqueDef) -> bool
func get_gp_cost() -> int
```

## TechniqueDef Key Properties
```gdscript
var id, name, category, affinity, range_type: String
var power, cooldown, status_accuracy: int
var status_effect, interrupt_trigger, support_effect, description: String
var support_value: float
# category: "offensive", "status", "support", "interrupt"
# range_type: "melee", "ranged", "aoe", "piercing"
# affinity: "volt", "terra", "flux", "neutral"
```

## Scene Tree (from TDD 7.1)

```
BattleScene (Control)
├── Background (TextureRect)
├── FormationSetup (Control)                 # Shown at battle start, hidden during combat
│   ├── PlayerSlots (HBoxContainer)
│   │   ├── FrontSlot1 (GlyphPortrait)
│   │   ├── FrontSlot2 (GlyphPortrait)
│   │   └── BackSlot (GlyphPortrait)
│   └── ConfirmButton (Button)
├── BattleField (Control)                    # Main combat display
│   ├── EnemySide (HBoxContainer)
│   │   ├── EnemyFrontRow (HBoxContainer)
│   │   └── EnemyBackRow (HBoxContainer)
│   └── PlayerSide (HBoxContainer)
│       ├── PlayerFrontRow (HBoxContainer)
│       └── PlayerBackRow (HBoxContainer)
├── TurnOrderBar (HBoxContainer)             # Top of screen — next 6 turns as portraits
├── ActionMenu (VBoxContainer)               # Bottom — Attack / Guard / Swap
├── TechniqueList (VBoxContainer)            # Slides in when Attack pressed
├── TargetHighlights (Control)               # Overlay for target selection
├── CombatLog (ScrollContainer)
│   └── LogText (RichTextLabel)
└── PhaseTransitionOverlay (ColorRect)       # Flash + text for boss phase 2
```

## UI Requirements (from GDD/TDD)

**Battle View:**
- Two sides, each with front/back row. Placeholder colored rectangles for Glyph sprites (Volt=yellow, Terra=green, Flux=purple).
- **HP bars** above each Glyph showing current/max HP
- **Status effect icons** below HP bars
- **Turn order bar** across the top showing next 6 turns as portraits (like FFX)
- **Action menu**: Attack (opens technique list) / Guard / Swap
- **Technique list** shows: name, affinity color, range icon, power, cooldown status, status effect
- **Target selection**: highlight eligible targets when technique is selected, click to confirm
- **Interrupt trigger**: visual flash + text overlay ("STATIC GUARD!"), brief pause
- **Damage numbers** float above targets
- **Phase transition**: screen flash + "PHASE 2" text overlay
- **Combat log** (scrollable text showing all events)

**Formation Setup:**
- At battle start, player assigns each Glyph to front/back row
- Click slots or drag-and-drop
- Default: first 2 front, rest back
- Confirm button starts combat

**Affinity Colors:** Volt = yellow (#FFD700), Terra = green (#4CAF50), Flux = purple (#9C27B0)

**Row Rules for Target Selection:**
- Melee: can only target front row (unless front row empty)
- Ranged: can target any enemy
- AoE: hits all enemies (no target selection needed)
- Piercing: can target any enemy, ignores back-row reduction
- Support: target allies

## Signal Flow for UI

1. `battle_started` → Show FormationSetup
2. Player assigns rows → `set_formation({glyph_id: "front"/"back", ...})` → FormationSetup hides, BattleField shows
3. `round_started` → Update round counter
4. `turn_queue_updated` → Refresh TurnOrderBar portraits
5. `turn_started` → If player side: show ActionMenu. If enemy: wait for auto-resolve.
6. Player clicks Attack → Show TechniqueList (filter: skip interrupts, skip cooldown, skip melee-from-back-row)
7. Player selects technique → Show TargetHighlights on eligible enemies
8. Player clicks target → `submit_action({action: "attack", technique: tech, target: target})`
9. `technique_used` → Play damage animation, update HP bar, show damage number
10. `glyph_ko` → Play KO animation, grey out portrait
11. `status_applied` → Show status icon on glyph panel
12. `guard_activated` → Show guard visual on glyph
13. `interrupt_triggered` → Flash + text overlay, brief pause
14. `phase_transition` → Screen flash + "PHASE 2" overlay
15. `battle_won` / `battle_lost` → Show result screen

## Important Implementation Notes

- CombatEngine auto-resolves enemy turns immediately after `submit_action()` chains through. Multiple signals may fire rapidly between player turns. Queue animations or use tweens with `await`.
- The engine sets `current_actor` to the active glyph. When it's a player glyph, the engine pauses and waits for `submit_action()`.
- `auto_battle` should be `false` for normal gameplay. When `true`, AI controls both sides (used in tests).
- Formation uses `glyph.instance_id` (int) as the key, not the glyph object itself.
- `turn_queue.get_preview(6)` returns the next N actors in the current round. The bar should refresh on every `turn_queue_updated` signal.
- Boss battles: boss acts last in round 1 (handled by TurnQueue). Phase 2 triggers at 50% HP.

## Deliverables

1. `ui/battle/battle_scene.tscn` + `ui/battle/battle_scene.gd` — Main battle scene
2. Supporting component scripts/scenes as needed (GlyphPanel, TurnPortrait, TechniqueButton, etc.)
3. The scene should be testable standalone: create a test script or scene that instantiates DataLoader + CombatEngine, creates test squads, and launches the battle scene.

## Verification

- Formation assignment works (click to assign rows, confirm)
- Turn order bar shows correct order, updates each round
- Action menu → technique list → target selection → submit works
- HP bars animate on damage
- Status icons appear/disappear
- KO visuals work
- Guard visual shows
- Interrupt flash triggers
- Boss phase transition visual triggers
- Battle win/loss screens show
- No crashes over multiple battles
