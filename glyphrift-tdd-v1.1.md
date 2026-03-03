# GLYPHRIFT — Technical Design Document

**Version:** 1.1
**Engine:** Godot 4.6 (GDScript)
**Reference:** Glyphrift Game Design Document v0.3
**Purpose:** Implementation specification for prototype development via Claude Code

---

## 1. Document Scope

This TDD translates the Glyphrift GDD v0.3 into Godot 4.6-specific architecture, project structure, scene trees, signal wiring, and a phased build plan. A developer (or Claude Code agent) should be able to read this document and the GDD together and produce a working prototype without design ambiguity.

This document does **not** restate game design rules — it references the GDD by section number. If there's a conflict between this TDD and the GDD, the GDD is authoritative for game logic and the TDD is authoritative for implementation approach.

---

## 2. Architecture Principles

### 2.1 — Separation of Data, Logic, and Presentation

The codebase is organized into three layers:

| Layer | Responsibility | Godot Mechanism | Dependencies |
|---|---|---|---|
| **Data** | Static game content (species, techniques, templates). Loaded once at startup. | `Resource` subclasses + JSON files | None |
| **Logic** | Game state, combat resolution, fusion math, mastery tracking, dungeon state. No rendering. | Autoload singletons + pure GDScript classes | Data layer only |
| **Presentation** | Scene trees, UI, animations, input handling. Reads from and sends commands to Logic. | Scenes (`.tscn`) + attached scripts | Data + Logic layers |

**The Logic layer never references any Node, Scene, or UI element.** It operates entirely on data classes and emits signals when state changes. Presentation listens to those signals and updates visuals. This means the entire game can be validated in headless/test mode without rendering.

### 2.2 — Static Typing Everywhere

All GDScript files use full static typing. Enable the following in Project Settings → Debug → GDScript:

- `UNTYPED_DECLARATION` → **Error**
- `INFERRED_DECLARATION` → **Warning** (prefer explicit types, but inferred is acceptable for obvious cases like `var x := 5`)
- `UNSAFE_CAST` → **Warning**

This is critical for Claude Code reliability — static types give the agent (and future developers) clear contracts between systems.

### 2.3 — Signals Over Direct Calls (Upward Communication)

Godot's signal system replaces the custom event bus described in the GDD's architecture sketch. The rules:

- **Downward calls (parent → child, logic → data):** Direct function calls are fine.
- **Upward calls (child → parent, logic → presentation):** Always use signals.
- **Lateral calls (sibling → sibling):** Route through a shared parent or an Autoload singleton.

### 2.4 — Autoloads for Global State, Resources for Static Data

- **Autoloads** (`ProjectSettings → Autoload`) are used for runtime game state that persists across scene changes: the player's roster, Crawler state, Codex progress, current rift session.
- **Resources** (`.tres` files or loaded JSON) are used for immutable game content: species definitions, technique stats, fusion tables, rift templates.

---

## 3. Project Structure

```
glyphrift/
├── project.godot
│
├── data/                              # Raw JSON data files (GDD Section 13.1)
│   ├── glyphs.json
│   ├── techniques.json
│   ├── fusion_table.json
│   ├── mastery_pools.json
│   ├── items.json
│   ├── rift_templates.json
│   ├── bosses.json
│   ├── crawler_upgrades.json
│   ├── codex_entries.json
│   └── npc_dialogue.json
│
├── resources/                         # Godot Resource definitions
│   ├── glyph_species.gd              # Resource class: GlyphSpecies
│   ├── technique_def.gd              # Resource class: TechniqueDef
│   ├── status_effect_def.gd          # Resource class: StatusEffectDef
│   ├── item_def.gd                   # Resource class: ItemDef
│   ├── rift_template.gd              # Resource class: RiftTemplate
│   └── boss_def.gd                   # Resource class: BossDef
│
├── core/                              # Logic layer — no Node dependencies
│   ├── data_loader.gd                # Autoload: parses JSON → Resource instances
│   ├── game_state.gd                 # Autoload: top-level state machine
│   ├── combat/
│   │   ├── combat_engine.gd          # Autoload: combat resolution
│   │   ├── combat_state.gd           # Data class: snapshot of a battle in progress
│   │   ├── damage_calculator.gd      # Pure functions: damage formula (GDD 8.8)
│   │   ├── turn_queue.gd             # Turn ordering logic
│   │   ├── status_manager.gd         # Status effect tick/expire/immunity
│   │   └── ai_controller.gd          # Enemy decision-making (GDD 8.10)
│   ├── glyph/
│   │   ├── glyph_instance.gd         # Runtime Glyph: stats + mastery + technique state
│   │   ├── mastery_tracker.gd        # Objective evaluation against combat events
│   │   └── fusion_engine.gd          # Autoload: fusion lookup, stat/technique inheritance
│   ├── dungeon/
│   │   ├── rift_generator.gd         # Generates a rift session from templates
│   │   ├── dungeon_state.gd          # Runtime floor/room graph + fog + crawler position
│   │   ├── crawler_state.gd          # Runtime Crawler: hull, energy, items, CP
│   │   └── capture_calculator.gd     # Pure functions: capture probability (GDD 8.11)
│   └── progression/
│       ├── codex_state.gd            # Autoload: discovered species, fusion log
│       ├── roster_state.gd           # Autoload: all owned Glyphs, active squad, reserve
│       └── milestone_tracker.gd      # Crawler upgrade milestone detection
│
├── ui/                                # Presentation layer
│   ├── battle/
│   │   ├── battle_scene.tscn         # Root battle scene
│   │   ├── battle_scene.gd
│   │   ├── turn_order_bar.tscn       # HBoxContainer of Glyph portraits
│   │   ├── turn_order_bar.gd
│   │   ├── glyph_panel.tscn          # Single Glyph display (sprite, HP bar, status icons)
│   │   ├── glyph_panel.gd
│   │   ├── formation_setup.tscn      # Pre-battle formation picker
│   │   ├── formation_setup.gd
│   │   ├── action_menu.tscn          # Attack/Guard/Swap selector
│   │   ├── action_menu.gd
│   │   ├── technique_list.tscn       # Technique selection submenu
│   │   ├── technique_list.gd
│   │   ├── target_selector.gd        # Highlights valid targets, handles click
│   │   └── combat_log.tscn           # Scrollable text log of combat events
│   ├── dungeon/
│   │   ├── dungeon_scene.tscn        # Root dungeon scene
│   │   ├── dungeon_scene.gd
│   │   ├── room_node.tscn            # Visual representation of a single room
│   │   ├── room_node.gd
│   │   ├── crawler_hud.tscn          # Hull HP, Energy, Item bar overlay
│   │   ├── crawler_hud.gd
│   │   └── puzzle_scenes/            # One .tscn per puzzle type
│   │       ├── sequence_lock.tscn
│   │       ├── conduit_bridge.tscn
│   │       └── echo_battle.tscn
│   ├── bastion/
│   │   ├── bastion_scene.tscn        # Hub menu
│   │   ├── bastion_scene.gd
│   │   ├── fusion_chamber.tscn       # Fusion UI (GDD 7.7)
│   │   ├── fusion_chamber.gd
│   │   ├── barracks.tscn             # Squad/roster management
│   │   ├── barracks.gd
│   │   ├── crawler_bay.tscn          # Crawler config
│   │   ├── crawler_bay.gd
│   │   ├── rift_gate.tscn            # Rift selection
│   │   ├── rift_gate.gd
│   │   ├── codex_view.tscn           # Codex browser
│   │   ├── codex_view.gd
│   │   └── npc_dialogue.tscn         # NPC dialogue popup
│   ├── shared/                        # Reusable UI components
│   │   ├── hp_bar.tscn
│   │   ├── hp_bar.gd
│   │   ├── glyph_portrait.tscn       # Small portrait with affinity color border
│   │   ├── glyph_portrait.gd
│   │   ├── stat_display.tscn         # Stat label block
│   │   ├── tooltip.tscn
│   │   └── confirmation_dialog.tscn
│   └── screens/
│       ├── title_screen.tscn
│       ├── title_screen.gd
│       └── transition.tscn           # Fade/wipe between scenes
│
├── assets/                            # Art, audio, fonts (placeholder for prototype)
│   ├── sprites/
│   │   ├── glyphs/                   # One .png per species (placeholder colored shapes)
│   │   └── ui/
│   ├── audio/
│   └── fonts/
│
└── tests/                             # GDScript test files (run headless)
    ├── test_damage_calc.gd
    ├── test_combat_engine.gd
    ├── test_fusion.gd
    ├── test_mastery.gd
    ├── test_rift_generation.gd
    └── test_runner.gd                 # Entry point: runs all tests, prints results
```

---

## 4. Autoload Registry

These scripts are registered as Autoloads in `project.godot` and are accessible globally by name.

| Autoload Name | Script | Purpose |
|---|---|---|
| `DataLoader` | `core/data_loader.gd` | Parses all JSON at startup. Provides `get_species(id)`, `get_technique(id)`, etc. |
| `GameState` | `core/game_state.gd` | Top-level state machine (TITLE → BASTION → RIFT → COMBAT). Manages scene transitions. |
| `CombatEngine` | `core/combat/combat_engine.gd` | Runs turn-based combat. Emits signals for every event (GDD 13.3). |
| `FusionEngine` | `core/glyph/fusion_engine.gd` | Performs fusion lookups and stat calculations. |
| `RosterState` | `core/progression/roster_state.gd` | Owns the player's Glyph collection, active squad, formation presets. |
| `CodexState` | `core/progression/codex_state.gd` | Tracks discovered species, fusion log, rift completions. |
| `CrawlerState` | `core/dungeon/crawler_state.gd` | Runtime Crawler stats, energy, hull, items, upgrades. Persists between rift runs (upgrades) and resets per-run (energy, hull, items). |

**Load order matters.** `DataLoader` must load first (it has no dependencies). All other Autoloads depend on `DataLoader`. Set the order in Project Settings → Autoload by dragging `DataLoader` to the top.

---

## 5. Data Layer — Resource Classes

Each Resource class maps to a JSON data file. `DataLoader` reads JSON and instantiates these at startup.

### 5.1 — GlyphSpecies

```gdscript
# resources/glyph_species.gd
class_name GlyphSpecies
extends Resource

@export var id: String
@export var name: String
@export var tier: int                        # 1–4
@export var affinity: String                 # "electric", "ground", "water"
@export var gp_cost: int                     # 2, 4, 6, or 8
@export var base_hp: int
@export var base_atk: int
@export var base_def: int
@export var base_spd: int
@export var base_res: int
@export var technique_ids: Array[String]     # IDs into techniques.json
@export var fixed_mastery_objectives: Array[Dictionary]  # [{type, params, description}]
```

### 5.2 — TechniqueDef

```gdscript
# resources/technique_def.gd
class_name TechniqueDef
extends Resource

@export var id: String
@export var name: String
@export var category: String          # "offensive", "status", "support", "interrupt"
@export var affinity: String          # "electric", "ground", "water", "neutral"
@export var range_type: String        # "melee", "ranged", "aoe", "piercing"
@export var power: int
@export var cooldown: int
@export var status_effect: String     # "" if none, otherwise status ID
@export var status_accuracy: int      # 0–100
@export var interrupt_trigger: String # "" if not interrupt, otherwise "ON_MELEE", etc.
@export var support_effect: String    # "" if not support, otherwise effect description key
@export var support_value: float      # heal %, buff %, etc.
@export var description: String       # Player-facing tooltip text
```

### 5.3 — StatusEffectDef

Defined in code rather than JSON since there are only 6 and their behavior is programmatic:

```gdscript
# resources/status_effect_def.gd
class_name StatusEffectDef
extends Resource

@export var id: String                # "burn", "stun", "slow", "weaken", "corrode", "shield"
@export var display_name: String
@export var duration: int             # turns
@export var is_buff: bool             # true for shield, false for debuffs
@export var description: String
```

### 5.4 — ItemDef

```gdscript
# resources/item_def.gd
class_name ItemDef
extends Resource

@export var id: String
@export var name: String
@export var effect_type: String       # "repair_hull", "restore_energy", "heal_glyph",
                                      # "status_immunity", "capture_bonus"
@export var effect_value: float       # Amount (25 hull, 10 energy, 100% heal, 25% capture, etc.)
@export var description: String
@export var usable_in_combat: bool    # false for all prototype items
```

### 5.5 — RiftTemplate

```gdscript
# resources/rift_template.gd
class_name RiftTemplate
extends Resource

@export var rift_id: String
@export var name: String
@export var tier: String                           # "minor", "standard", "major", "apex"
@export var floors: Array[Dictionary]              # [{floor_number, rooms, connections, content_pools}]
@export var boss: Dictionary                       # {species_id, stat_modifier, phase2_techniques}
@export var hazard_damage: int
@export var enemy_tier_pool: Array[int]            # [1], [1,2], [2,3], etc.
@export var wild_glyph_pool: Array[String]         # species IDs capturable here
```

### 5.6 — BossDef

```gdscript
# resources/boss_def.gd
class_name BossDef
extends Resource

@export var species_id: String
@export var stat_modifier: float                   # 1.2 for wild variants
@export var phase1_technique_ids: Array[String]
@export var phase2_technique_ids: Array[String]
@export var phase2_stat_bonus: Dictionary           # {"atk": 0.1, "spd": 0.1}
```

---

## 6. Logic Layer — Core Systems

### 6.1 — DataLoader

```gdscript
# core/data_loader.gd
extends Node

var species: Dictionary = {}          # id → GlyphSpecies
var techniques: Dictionary = {}       # id → TechniqueDef
var fusion_table: Dictionary = {}     # "speciesA_id|speciesB_id" → result_species_id
var mastery_pools: Dictionary = {}    # tier (int) → Array[Dictionary]
var items: Dictionary = {}            # id → ItemDef
var rift_templates: Array[RiftTemplate] = []
var bosses: Dictionary = {}           # rift_id → BossDef
var codex_entries: Dictionary = {}    # species_id → {hint, lore}
var npc_dialogue: Dictionary = {}     # npc_id → {phase → Array[String]}
var crawler_upgrades: Array[Dictionary] = []

func _ready() -> void:
    _load_techniques()
    _load_species()
    _load_fusion_table()
    _load_mastery_pools()
    _load_items()
    _load_rift_templates()
    _load_bosses()
    _load_codex()
    _load_npc_dialogue()
    _load_crawler_upgrades()

func get_species(id: String) -> GlyphSpecies:
    return species[id]

func get_technique(id: String) -> TechniqueDef:
    return techniques[id]

func lookup_fusion(species_a_id: String, species_b_id: String) -> String:
    # Fusion is order-independent: normalize by sorting IDs alphabetically
    var key_1: String = species_a_id + "|" + species_b_id
    var key_2: String = species_b_id + "|" + species_a_id
    if fusion_table.has(key_1):
        return fusion_table[key_1]
    if fusion_table.has(key_2):
        return fusion_table[key_2]
    return _default_fusion(species_a_id, species_b_id)

func _default_fusion(a_id: String, b_id: String) -> String:
    # GDD 7.6 fallback: result matches affinity of parent with higher total base stats
    var a: GlyphSpecies = species[a_id]
    var b: GlyphSpecies = species[b_id]
    var a_total: int = a.base_hp + a.base_atk + a.base_def + a.base_spd + a.base_res
    var b_total: int = b.base_hp + b.base_atk + b.base_def + b.base_spd + b.base_res
    var target_affinity: String = a.affinity if a_total >= b_total else b.affinity
    var target_tier: int = _fusion_result_tier(a.tier, b.tier)
    # Find the species of that affinity and tier
    for sp: GlyphSpecies in species.values():
        if sp.affinity == target_affinity and sp.tier == target_tier:
            return sp.id
    return a_id  # absolute fallback, should never reach here

func _fusion_result_tier(tier_a: int, tier_b: int) -> int:
    # GDD 7.1: same tier → tier+1, adjacent tiers → max tier
    if tier_a == tier_b:
        return mini(tier_a + 1, 4)
    return maxi(tier_a, tier_b)

# --- Private loader functions ---
# Each reads the corresponding JSON from "res://data/" using FileAccess,
# parses with JSON.parse_string(), and populates the dictionaries above.
# Implementation is straightforward file I/O — omitted here for brevity
# but must be fully implemented.
```

**Key implementation note:** The fusion table stores both orderings for each pair (`a|b` and `b|a`) for O(1) lookup. `lookup_fusion("zapplet", "stonepaw")` and `lookup_fusion("stonepaw", "zapplet")` both resolve correctly.

### 6.2 — GlyphInstance (Runtime Glyph)

This is the most-referenced class in the codebase. It represents a single Glyph the player owns, with all runtime state.

```gdscript
# core/glyph/glyph_instance.gd
class_name GlyphInstance
extends RefCounted

var instance_id: int = 0                    # Auto-incrementing unique ID
var species: GlyphSpecies = null            # Reference to static species data
var techniques: Array[TechniqueDef] = []    # Native + inherited techniques (max 4)

# Current stats (base + inheritance bonuses + mastery bonus)
var max_hp: int = 0
var current_hp: int = 0
var atk: int = 0
var def_stat: int = 0                       # "def" is a GDScript keyword
var spd: int = 0
var res: int = 0

# Inheritance tracking (for display and future fusions)
var bonus_hp: int = 0
var bonus_atk: int = 0
var bonus_def: int = 0
var bonus_spd: int = 0
var bonus_res: int = 0

# Mastery
var mastery_objectives: Array[Dictionary] = []  # [{type, params, description, completed}]
var is_mastered: bool = false
var mastery_bonus_applied: bool = false
var took_turn_this_battle: bool = false

# Combat transient state (reset each battle)
var cooldowns: Dictionary = {}              # technique_id → turns remaining
var active_statuses: Dictionary = {}        # status_id → turns remaining
var status_immunities: Dictionary = {}      # status_id → turns remaining (1-turn immunity)
var is_guarding: bool = false
var is_knocked_out: bool = false
var took_turn_this_round: bool = false
var row_position: String = "front"          # "front" or "back"

# Side tag for combat — "player" or "enemy"
var side: String = ""

# Boss tracking
var is_boss: bool = false
var boss_phase: int = 1

# Auto-incrementing ID counter
static var _next_id: int = 1

func _init() -> void:
    instance_id = _next_id
    _next_id += 1

func calculate_stats() -> void:
    if species == null:
        return
    max_hp = species.base_hp + bonus_hp
    atk = species.base_atk + bonus_atk
    def_stat = species.base_def + bonus_def
    spd = species.base_spd + bonus_spd
    res = species.base_res + bonus_res
    # GDD 6.4: Mastered Glyphs gain permanent +2 to all stats
    if mastery_bonus_applied:
        max_hp += 2
        atk += 2
        def_stat += 2
        spd += 2
        res += 2
    current_hp = max_hp

func get_effective_spd() -> float:
    var base: float = float(spd)
    if active_statuses.has("slow"):
        base *= 0.7
    return base

func get_effective_atk() -> float:
    var base: float = float(atk)
    if active_statuses.has("weaken"):
        base *= 0.75
    return base

func get_effective_def() -> float:
    var base: float = float(def_stat)
    if active_statuses.has("corrode"):
        base *= 0.75
    return base

func get_gp_cost() -> int:
    if species == null:
        return 0
    return species.gp_cost

func reset_combat_state() -> void:
    cooldowns.clear()
    active_statuses.clear()
    status_immunities.clear()
    is_guarding = false
    is_knocked_out = false
    took_turn_this_round = false
    took_turn_this_battle = false
    boss_phase = 1

static func create_from_species(sp: GlyphSpecies, dl: Node) -> GlyphInstance:
    var g: GlyphInstance = GlyphInstance.new()
    g.species = sp
    for tid: String in sp.technique_ids:
        var tech: TechniqueDef = dl.get_technique(tid)
        if tech != null:
            g.techniques.append(tech)
    g.calculate_stats()
    return g
```

**Implementation notes:**
- `instance_id` uses an `int` auto-incrementing counter (not String UUIDs) — simpler and sufficient for prototype.
- `active_statuses` and `status_immunities` use `Dictionary` (keyed by status ID) for O(1) lookup, not `Array[Dictionary]`.
- Inheritance bonus fields use shortened names (`bonus_hp` not `inheritance_bonus_hp`) for conciseness.
- `get_effective_*` returns `float` (needed for SPD-based turn ordering fractional comparisons).
- `create_from_species(sp, dl)` is a static factory that resolves techniques from DataLoader.

### 6.3 — CombatEngine

The combat engine is the most complex system. It operates as a state machine driven by commands from the UI (or from the AI controller for enemies).

```gdscript
# core/combat/combat_engine.gd
extends Node

# --- Signals (GDD Section 13.3 event hooks) ---
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
signal capture_opportunity(fragment_species: GlyphSpecies, capture_chance: float)
signal turn_queue_updated(queue: Array[GlyphInstance])
signal phase_transition(boss: GlyphInstance)

# --- State ---
enum BattlePhase { INACTIVE, FORMATION, TURN_ACTIVE, ANIMATING, VICTORY, DEFEAT }
var phase: BattlePhase = BattlePhase.INACTIVE
var player_squad: Array[GlyphInstance] = []
var enemy_squad: Array[GlyphInstance] = []
var turn_queue: TurnQueue = TurnQueue.new()
var turn_count: int = 0
var player_ko_list: Array[GlyphInstance] = []
var is_boss_battle: bool = false
var boss_phase: int = 1
var boss_def: BossDef = null

# --- Public API ---
func start_battle(
    p_squad: Array[GlyphInstance],
    e_squad: Array[GlyphInstance],
    boss: BossDef = null
) -> void:
    player_squad = p_squad
    enemy_squad = e_squad
    is_boss_battle = boss != null
    boss_def = boss
    boss_phase = 1
    turn_count = 0
    player_ko_list.clear()

    for g: GlyphInstance in player_squad + enemy_squad:
        g.reset_combat_state()

    phase = BattlePhase.FORMATION
    battle_started.emit(player_squad, enemy_squad)

func set_formation(assignments: Dictionary) -> void:
    # assignments = {glyph_instance_id: "front" or "back"}
    for g: GlyphInstance in player_squad:
        if assignments.has(g.instance_id):
            g.row_position = assignments[g.instance_id]
    _build_turn_queue()
    phase = BattlePhase.TURN_ACTIVE
    _advance_turn()

func submit_action(action: Dictionary) -> void:
    # Called by UI when player chooses an action.
    # action = {type: "attack"|"guard"|"swap", technique_id: "", target_id: ""}
    _execute_action(_get_current_glyph(), action)

# --- Private: Turn Flow ---
func _build_turn_queue() -> void:
    var all_glyphs: Array[GlyphInstance] = []
    for g: GlyphInstance in player_squad + enemy_squad:
        if not g.is_knocked_out:
            all_glyphs.append(g)
    turn_queue.build(all_glyphs, is_boss_battle and turn_count == 0)
    turn_queue_updated.emit(turn_queue.get_preview(6))

func _advance_turn() -> void:
    if _check_battle_end():
        return

    var current: GlyphInstance = turn_queue.next()
    if current.is_knocked_out:
        _advance_turn()
        return

    current.took_turn_this_battle = true
    _tick_cooldowns(current)

    turn_started.emit(current, turn_count)

    if _is_enemy(current):
        # AI takes action
        var action: Dictionary = AIController.decide(current, player_squad, enemy_squad)
        _execute_action(current, action)
    # else: wait for UI to call submit_action()

func _execute_action(actor: GlyphInstance, action: Dictionary) -> void:
    phase = BattlePhase.ANIMATING

    match action["type"]:
        "attack":
            _execute_attack(actor, action)
        "guard":
            _execute_guard(actor)
        "swap":
            _execute_swap(actor, action)

    _tick_statuses(actor)

    if turn_queue.is_round_complete():
        turn_count += 1
        _build_turn_queue()

    phase = BattlePhase.TURN_ACTIVE
    _advance_turn()

func _execute_attack(actor: GlyphInstance, action: Dictionary) -> void:
    var technique: TechniqueDef = DataLoader.get_technique(action["technique_id"])
    var targets: Array[GlyphInstance] = _resolve_targets(actor, technique, action.get("target_id", ""))

    # Check for interrupts from defending side
    _check_interrupts(actor, technique, targets)

    for target: GlyphInstance in targets:
        if target.is_knocked_out:
            continue
        var damage: int = DamageCalculator.calculate(actor, target, technique)
        target.current_hp = maxi(0, target.current_hp - damage)
        technique_used.emit(actor, technique, target, damage)

        if DamageCalculator.has_affinity_advantage(technique.affinity, target.species.affinity):
            affinity_advantage_hit.emit(actor, target)

        if technique.status_effect != "":
            _try_apply_status(target, technique)

        if target.current_hp <= 0:
            _handle_ko(target, actor)

    # Set cooldown
    if technique.cooldown > 0:
        actor.cooldowns[technique.id] = technique.cooldown

    # Boss phase check
    if is_boss_battle and boss_phase == 1:
        for e: GlyphInstance in enemy_squad:
            if e.current_hp > 0 and e.current_hp <= e.max_hp / 2:
                _trigger_boss_phase_2(e)

func _execute_guard(actor: GlyphInstance) -> void:
    actor.is_guarding = true
    guard_activated.emit(actor)

func _execute_swap(actor: GlyphInstance, action: Dictionary) -> void:
    var target: GlyphInstance = _get_glyph_by_id(action["target_id"])
    var temp: String = actor.row_position
    actor.row_position = target.row_position
    target.row_position = temp
    swap_performed.emit(actor, target)

# --- Interrupt Resolution ---
func _check_interrupts(
    attacker: GlyphInstance,
    technique: TechniqueDef,
    _targets: Array[GlyphInstance]
) -> void:
    var defending_squad: Array[GlyphInstance] = (
        player_squad if _is_enemy(attacker) else enemy_squad
    )
    var triggered: Array[GlyphInstance] = []

    for defender: GlyphInstance in defending_squad:
        if not defender.is_guarding or defender.is_knocked_out:
            continue
        for tech: TechniqueDef in defender.techniques:
            if tech.category != "interrupt":
                continue
            if defender.cooldowns.get(tech.id, 0) > 0:
                continue
            if _interrupt_matches(tech.interrupt_trigger, technique, attacker, defender):
                triggered.append(defender)
                break

    # Only highest SPD defender triggers (GDD 8.6)
    if triggered.size() > 0:
        triggered.sort_custom(func(a: GlyphInstance, b: GlyphInstance) -> bool:
            return a.get_effective_spd() > b.get_effective_spd()
        )
        var interrupter: GlyphInstance = triggered[0]
        var interrupt_tech: TechniqueDef = _get_interrupt_technique(interrupter)
        _resolve_interrupt(interrupter, interrupt_tech, attacker)

func _interrupt_matches(
    trigger: String,
    incoming_tech: TechniqueDef,
    _attacker: GlyphInstance,
    _defender: GlyphInstance
) -> bool:
    match trigger:
        "ON_MELEE":
            return incoming_tech.range_type == "melee"
        "ON_RANGED":
            return incoming_tech.range_type == "ranged"
        "ON_AOE":
            return incoming_tech.range_type == "aoe"
        "ON_SUPPORT":
            return incoming_tech.category == "support"
    return false

# --- Status Effects ---
func _try_apply_status(target: GlyphInstance, technique: TechniqueDef) -> void:
    if technique.status_effect in target.status_immunities:
        status_immune.emit(target, technique.status_effect)
        return

    var apply_chance: float = clampf(
        (technique.status_accuracy - target.res / 2.0) / 100.0,
        0.1, 0.9
    )
    if randf() <= apply_chance:
        StatusManager.apply(target, technique.status_effect)
        status_applied.emit(target, technique.status_effect)
    else:
        status_resisted.emit(target, technique.status_effect)

func _tick_statuses(glyph: GlyphInstance) -> void:
    StatusManager.tick(glyph)

# --- Boss Phase 2 ---
func _trigger_boss_phase_2(boss_glyph: GlyphInstance) -> void:
    boss_phase = 2
    # Clear all status effects (GDD 9.5)
    boss_glyph.active_statuses.clear()
    # Apply stat bonuses
    if boss_def:
        boss_glyph.atk = int(boss_glyph.atk * (1.0 + boss_def.phase2_stat_bonus.get("atk", 0.0)))
        boss_glyph.spd = int(boss_glyph.spd * (1.0 + boss_def.phase2_stat_bonus.get("spd", 0.0)))
        # Add phase 2 techniques
        for tech_id: String in boss_def.phase2_technique_ids:
            var tech: TechniqueDef = DataLoader.get_technique(tech_id)
            if tech not in boss_glyph.techniques and boss_glyph.techniques.size() < 4:
                boss_glyph.techniques.append(tech)
    phase_transition.emit(boss_glyph)

# --- Battle End ---
func _check_battle_end() -> bool:
    var player_alive: bool = false
    for g: GlyphInstance in player_squad:
        if not g.is_knocked_out:
            player_alive = true
            break

    var enemy_alive: bool = false
    for g: GlyphInstance in enemy_squad:
        if not g.is_knocked_out:
            enemy_alive = true
            break

    if not enemy_alive:
        phase = BattlePhase.VICTORY
        battle_won.emit(player_squad, turn_count, player_ko_list)
        return true
    if not player_alive:
        phase = BattlePhase.DEFEAT
        battle_lost.emit(player_squad)
        return true
    return false

# --- Helpers ---
func _is_enemy(glyph: GlyphInstance) -> bool:
    return glyph in enemy_squad

func _get_current_glyph() -> GlyphInstance:
    return turn_queue.current()

func _get_glyph_by_id(id: String) -> GlyphInstance:
    for g: GlyphInstance in player_squad + enemy_squad:
        if g.instance_id == id:
            return g
    return null

func _handle_ko(target: GlyphInstance, attacker: GlyphInstance) -> void:
    target.is_knocked_out = true
    glyph_ko.emit(target, attacker)
    glyph_dealt_finishing_blow.emit(attacker, target)
    if target in player_squad:
        player_ko_list.append(target)

func _get_interrupt_technique(glyph: GlyphInstance) -> TechniqueDef:
    for tech: TechniqueDef in glyph.techniques:
        if tech.category == "interrupt" and glyph.cooldowns.get(tech.id, 0) <= 0:
            return tech
    return null

func _resolve_interrupt(
    interrupter: GlyphInstance,
    interrupt_tech: TechniqueDef,
    attacker: GlyphInstance
) -> void:
    interrupt_triggered.emit(interrupter, interrupt_tech, attacker)
    # Apply interrupt-specific effects based on technique
    # (damage, block, status — handled per technique definition)
    if interrupt_tech.power > 0:
        var damage: int = DamageCalculator.calculate(interrupter, attacker, interrupt_tech)
        attacker.current_hp = maxi(0, attacker.current_hp - damage)
        if attacker.current_hp <= 0:
            _handle_ko(attacker, interrupter)
    interrupter.cooldowns[interrupt_tech.id] = interrupt_tech.cooldown

func _tick_cooldowns(glyph: GlyphInstance) -> void:
    var to_remove: Array[String] = []
    for tech_id: String in glyph.cooldowns:
        glyph.cooldowns[tech_id] -= 1
        if glyph.cooldowns[tech_id] <= 0:
            to_remove.append(tech_id)
    for tech_id: String in to_remove:
        glyph.cooldowns.erase(tech_id)

func _resolve_targets(
    actor: GlyphInstance,
    technique: TechniqueDef,
    target_id: String
) -> Array[GlyphInstance]:
    var opposing: Array[GlyphInstance] = (
        enemy_squad if actor in player_squad else player_squad
    )
    var allied: Array[GlyphInstance] = (
        player_squad if actor in player_squad else enemy_squad
    )

    match technique.range_type:
        "aoe":
            if technique.category == "support":
                return allied.filter(func(g: GlyphInstance) -> bool: return not g.is_knocked_out)
            return opposing.filter(func(g: GlyphInstance) -> bool: return not g.is_knocked_out)
        _:
            var target: GlyphInstance = _get_glyph_by_id(target_id)
            if target:
                return [target]
            return []
```

### 6.4 — DamageCalculator

Pure static functions. No state. Easy to unit test.

```gdscript
# core/combat/damage_calculator.gd
class_name DamageCalculator

static func calculate(
    attacker: GlyphInstance,
    defender: GlyphInstance,
    technique: TechniqueDef
) -> int:
    if technique.category == "support":
        return 0

    var raw: float = (technique.power * (attacker.get_effective_atk() / maxf(defender.get_effective_def(), 1.0)))
    raw *= get_affinity_multiplier(technique.affinity, defender.species.affinity)
    raw *= get_row_modifier(defender, technique)
    raw *= get_shield_modifier(defender)
    raw *= get_guard_modifier(defender)
    raw *= randf_range(0.9, 1.1)  # ±10% variance

    return maxi(1, int(raw))

static func get_affinity_multiplier(attack_affinity: String, defend_affinity: String) -> float:
    if attack_affinity == "neutral" or defend_affinity == "neutral":
        return 1.0
    if attack_affinity == defend_affinity:
        return 1.0
    # Electric > Water, Water > Ground, Ground > Electric
    var advantages: Dictionary = {"electric": "water", "water": "ground", "ground": "electric"}
    if advantages.get(attack_affinity, "") == defend_affinity:
        return 1.5
    return 0.65

static func has_affinity_advantage(attack_affinity: String, defend_affinity: String) -> bool:
    return get_affinity_multiplier(attack_affinity, defend_affinity) > 1.0

static func get_row_modifier(defender: GlyphInstance, technique: TechniqueDef) -> float:
    if defender.row_position == "back":
        if technique.range_type in ["aoe", "piercing"]:
            return 1.0  # AoE and Piercing ignore row defense (GDD 8.2, 8.8)
        return 0.7      # Melee and Ranged reduced
    return 1.0

static func get_shield_modifier(defender: GlyphInstance) -> float:
    for status: Dictionary in defender.active_statuses:
        if status["id"] == "shield":
            return 0.75
    return 1.0

static func get_guard_modifier(defender: GlyphInstance) -> float:
    return 0.5 if defender.is_guarding else 1.0
```

### 6.5 — TurnQueue

```gdscript
# core/combat/turn_queue.gd
class_name TurnQueue
extends RefCounted

var queue: Array[GlyphInstance] = []
var index: int = 0

func build(glyphs: Array[GlyphInstance], boss_battle_first_round: bool = false) -> void:
    queue = glyphs.duplicate()
    queue.sort_custom(TurnQueue.compare_spd)
    # Deterministic tiebreak cascade (GDD 8.3):
    # 1. Higher tier  2. Affinity: electric > ground > water
    # 3. Lower HP%    4. Player side wins  5. Alphabetical name

    # Boss acts last on turn 1 (GDD 9.5)
    if boss_battle_first_round:
        for i: int in range(queue.size()):
            # Assume boss is the enemy with highest max_hp (heuristic)
            if queue[i].max_hp == queue.map(
                func(g: GlyphInstance) -> int: return g.max_hp
            ).max():
                var boss: GlyphInstance = queue[i]
                queue.remove_at(i)
                queue.append(boss)
                break

    index = 0

func current() -> GlyphInstance:
    return queue[index]

func next() -> GlyphInstance:
    var g: GlyphInstance = queue[index]
    index += 1
    return g

func is_round_complete() -> bool:
    return index >= queue.size()

func get_preview(count: int) -> Array[GlyphInstance]:
    var preview: Array[GlyphInstance] = []
    for i: int in range(mini(count, queue.size() - index)):
        preview.append(queue[index + i])
    return preview
```

### 6.6 — StatusManager

```gdscript
# core/combat/status_manager.gd
class_name StatusManager

## Status durations from GDD 8.7
const DURATIONS: Dictionary = {
    "burn": 3, "stun": 1, "slow": 3,
    "weaken": 3, "corrode": 3, "shield": 2
}

static func apply(glyph: GlyphInstance, status_id: String) -> void:
    # Check if already active — refresh duration, don't stack
    for status: Dictionary in glyph.active_statuses:
        if status["id"] == status_id:
            status["turns_remaining"] = DURATIONS[status_id]
            return
    glyph.active_statuses.append({
        "id": status_id,
        "turns_remaining": DURATIONS[status_id]
    })

static func tick(glyph: GlyphInstance) -> void:
    # Called at end of glyph's turn
    # Process burn damage
    for status: Dictionary in glyph.active_statuses:
        if status["id"] == "burn":
            var burn_damage: int = maxi(1, int(glyph.max_hp * 0.08))
            glyph.current_hp = maxi(0, glyph.current_hp - burn_damage)

    # Handle stun (skip turn) — this is checked by the engine before action
    # Tick down all durations
    var expired: Array[String] = []
    var to_remove: Array[int] = []
    for i: int in range(glyph.active_statuses.size()):
        glyph.active_statuses[i]["turns_remaining"] -= 1
        if glyph.active_statuses[i]["turns_remaining"] <= 0:
            expired.append(glyph.active_statuses[i]["id"])
            to_remove.append(i)

    # Remove expired (reverse order to preserve indices)
    to_remove.reverse()
    for i: int in to_remove:
        glyph.active_statuses.remove_at(i)

    # Grant 1-turn immunity to expired statuses (GDD 8.7)
    for status_id: String in expired:
        if status_id not in glyph.status_immunities:
            glyph.status_immunities.append(status_id)

    # Clear guard at start of next turn
    glyph.is_guarding = false

static func clear_immunities_tick(glyph: GlyphInstance) -> void:
    # Called at start of glyph's turn — clears immunities set last turn
    glyph.status_immunities.clear()

static func is_stunned(glyph: GlyphInstance) -> bool:
    for status: Dictionary in glyph.active_statuses:
        if status["id"] == "stun":
            return true
    return false
```

### 6.7 — AIController

```gdscript
# core/combat/ai_controller.gd
class_name AIController

## Enemy AI priority system (GDD 8.10)
static func decide(
    actor: GlyphInstance,
    player_squad: Array[GlyphInstance],
    _enemy_squad: Array[GlyphInstance]
) -> Dictionary:
    var alive_targets: Array[GlyphInstance] = player_squad.filter(
        func(g: GlyphInstance) -> bool: return not g.is_knocked_out
    )
    if alive_targets.is_empty():
        return {"type": "guard"}

    var best_technique: TechniqueDef = _pick_technique(actor)
    var target: GlyphInstance = _pick_target(actor, alive_targets, best_technique)

    return {
        "type": "attack",
        "technique_id": best_technique.id,
        "target_id": target.instance_id
    }

static func _pick_technique(actor: GlyphInstance) -> TechniqueDef:
    # Highest power technique that's off cooldown and not an interrupt
    var available: Array[TechniqueDef] = []
    for tech: TechniqueDef in actor.techniques:
        if tech.category == "interrupt":
            continue
        if actor.cooldowns.get(tech.id, 0) > 0:
            continue
        # Check row restrictions
        if tech.range_type == "melee" and actor.row_position == "back":
            continue
        available.append(tech)

    if available.is_empty():
        # Fallback: basic tackle or guard
        return DataLoader.get_technique("tackle")

    available.sort_custom(func(a: TechniqueDef, b: TechniqueDef) -> bool:
        return a.power > b.power
    )
    return available[0]

static func _pick_target(
    actor: GlyphInstance,
    targets: Array[GlyphInstance],
    technique: TechniqueDef
) -> GlyphInstance:
    if technique.range_type == "aoe":
        return targets[0]  # AoE hits all, target is irrelevant

    # Priority 1: Can KO a target this turn
    for t: GlyphInstance in targets:
        if not _is_targetable(t, technique):
            continue
        var est_damage: int = DamageCalculator.calculate(actor, t, technique)
        if est_damage >= t.current_hp:
            return t

    # Priority 2: Affinity advantage
    for t: GlyphInstance in targets:
        if not _is_targetable(t, technique):
            continue
        if DamageCalculator.has_affinity_advantage(technique.affinity, t.species.affinity):
            return t

    # Priority 3: Lowest HP
    var targetable: Array[GlyphInstance] = targets.filter(
        func(g: GlyphInstance) -> bool: return _is_targetable(g, technique)
    )
    if targetable.is_empty():
        return targets[0]

    targetable.sort_custom(func(a: GlyphInstance, b: GlyphInstance) -> bool:
        return a.current_hp < b.current_hp
    )
    return targetable[0]

static func _is_targetable(target: GlyphInstance, technique: TechniqueDef) -> bool:
    if technique.range_type == "melee" and target.row_position == "back":
        # Can only target back row with melee if front row is empty
        return false  # Simplified — full check needs squad context
    return true
```

### 6.8 — FusionEngine

```gdscript
# core/glyph/fusion_engine.gd
class_name FusionEngine
extends Node

signal fusion_completed(result: GlyphInstance)
signal new_species_discovered(species: GlyphSpecies)

# Injectable dependencies (autoloads unavailable in --script tests)
var data_loader: Node = null
var codex_state: Node = null     # CodexState
var roster_state: Node = null    # RosterState

func _ready() -> void:
    if has_node("/root/DataLoader"):
        data_loader = get_node("/root/DataLoader")
    if has_node("/root/CodexState"):
        codex_state = get_node("/root/CodexState")
    if has_node("/root/RosterState"):
        roster_state = get_node("/root/RosterState")

func can_fuse(a: GlyphInstance, b: GlyphInstance) -> Dictionary:
    # Returns {valid: bool, reason: String}
    if not a.is_mastered:
        return {"valid": false, "reason": a.species.name + " is not mastered."}
    if not b.is_mastered:
        return {"valid": false, "reason": b.species.name + " is not mastered."}
    if not _tiers_compatible(a.species.tier, b.species.tier):
        return {"valid": false, "reason": "These tiers cannot fuse together."}
    return {"valid": true, "reason": ""}

func preview_fusion(a: GlyphInstance, b: GlyphInstance) -> Dictionary:
    var result_species_id: String = data_loader.lookup_fusion(a.species.id, b.species.id)
    var result_species: GlyphSpecies = data_loader.get_species(result_species_id)
    var is_discovered: bool = false
    if codex_state != null:
        is_discovered = codex_state.is_species_discovered(result_species_id)
    var bonuses: Dictionary = _calculate_inheritance(a, b)

    return {
        "result_tier": result_species.tier,
        "result_affinity": result_species.affinity,
        "result_species_name": result_species.name if is_discovered else "???",
        "result_species_id": result_species_id if is_discovered else "",
        "result_gp": result_species.gp_cost,
        "inheritance_bonuses": bonuses,
        "inheritable_techniques_a": _get_inheritable_techniques(a, result_species),
        "inheritable_techniques_b": _get_inheritable_techniques(b, result_species),
        "num_technique_slots": _get_inheritance_slots(result_species),
    }

func execute_fusion(
    a: GlyphInstance,
    b: GlyphInstance,
    inherited_technique_ids: Array[String]
) -> GlyphInstance:
    var result_species_id: String = data_loader.lookup_fusion(a.species.id, b.species.id)
    var result_species: GlyphSpecies = data_loader.get_species(result_species_id)
    var bonuses: Dictionary = _calculate_inheritance(a, b)

    var result: GlyphInstance = GlyphInstance.new()
    result.species = result_species

    # Apply inheritance bonuses (field names: bonus_hp, bonus_atk, etc.)
    result.bonus_hp = bonuses["hp"]
    result.bonus_atk = bonuses["atk"]
    result.bonus_def = bonuses["def"]
    result.bonus_spd = bonuses["spd"]
    result.bonus_res = bonuses["res"]

    # Build technique list: native first, then inherited (4-technique cap)
    for tech_id: String in result_species.technique_ids:
        var tech: TechniqueDef = data_loader.get_technique(tech_id)
        if tech != null:
            result.techniques.append(tech)
    for tech_id: String in inherited_technique_ids:
        if result.techniques.size() < 4:
            var tech: TechniqueDef = data_loader.get_technique(tech_id)
            if tech != null:
                result.techniques.append(tech)

    # Build mastery track (delegates to MasteryTracker static method)
    result.mastery_objectives = MasteryTracker.build_mastery_track(
        result_species, data_loader.mastery_pools
    )

    result.calculate_stats()

    # Update game state if state managers are available
    if roster_state != null:
        roster_state.remove_glyph(a)
        roster_state.remove_glyph(b)
        roster_state.add_glyph(result)

    if codex_state != null:
        codex_state.log_fusion(a.species.id, b.species.id, result_species_id)
        var was_new: bool = codex_state.discover_species(result_species_id)
        if was_new:
            new_species_discovered.emit(result_species)

    fusion_completed.emit(result)
    return result

# --- Private ---
func _tiers_compatible(tier_a: int, tier_b: int) -> bool:
    if tier_a == 4 or tier_b == 4:
        return false
    return absi(tier_a - tier_b) <= 1

func _calculate_inheritance(a: GlyphInstance, b: GlyphInstance) -> Dictionary:
    # GDD 7.2: floor((ParentA_Stat + ParentB_Stat) * 0.15) per stat
    # Uses current stats (includes prior inheritance + mastery bonuses)
    return {
        "hp":  int((a.max_hp + b.max_hp) * 0.15),
        "atk": int((a.atk + b.atk) * 0.15),
        "def": int((a.def_stat + b.def_stat) * 0.15),
        "spd": int((a.spd + b.spd) * 0.15),
        "res": int((a.res + b.res) * 0.15),
    }

func _get_inheritance_slots(sp: GlyphSpecies) -> int:
    var native_count: int = sp.technique_ids.size()
    match native_count:
        2: return 2
        3: return 1
        _: return 0

func _get_inheritable_techniques(
    parent: GlyphInstance,
    result_species: GlyphSpecies
) -> Array[TechniqueDef]:
    var result: Array[TechniqueDef] = []
    for tech: TechniqueDef in parent.techniques:
        if tech.id not in result_species.technique_ids:
            result.append(tech)
    return result
```

**Implementation notes:**
- All dependencies (`data_loader`, `codex_state`, `roster_state`) are injectable properties for testability. In autoload mode they're resolved from `/root/` in `_ready()`.
- Instance IDs are auto-generated by `GlyphInstance._init()` (no `_generate_id()` needed).
- Mastery track building is delegated to `MasteryTracker.build_mastery_track()` (static method) since mastery logic belongs on the mastery class.
- `_calculate_inheritance` uses current stats (which include prior bonuses and mastery) per GDD 7.2: "Inherited stats are baked in permanently... carry forward into future fusions."

### 6.9 — MasteryTracker

```gdscript
# core/glyph/mastery_tracker.gd
class_name MasteryTracker
extends RefCounted

## Connects to CombatEngine signals and evaluates mastery objectives
## for all player Glyphs.

signal objective_completed(glyph: GlyphInstance, objective_index: int)
signal glyph_mastered(glyph: GlyphInstance)

# Injectable combat engine reference (autoloads unavailable in --script tests)
var combat_engine: Node = null

# Per-battle tracking
var _battle_flags: Dictionary = {}              # instance_id → {had_advantage, finishing_blows, ...}
var _enemy_squad: Array[GlyphInstance] = []
var _first_actor_id: int = -1
var _last_technique_by_glyph: Dictionary = {}   # instance_id → TechniqueDef

func connect_to_combat(engine: Node) -> void:
    combat_engine = engine
    engine.battle_started.connect(_on_battle_started)
    engine.battle_won.connect(_on_battle_won)
    engine.technique_used.connect(_on_technique_used)
    engine.affinity_advantage_hit.connect(_on_affinity_advantage_hit)
    engine.interrupt_triggered.connect(_on_interrupt_triggered)
    engine.glyph_dealt_finishing_blow.connect(_on_finishing_blow)
    engine.status_applied.connect(_on_status_applied)
    engine.turn_started.connect(_on_turn_started)

func disconnect_from_combat() -> void:
    # Disconnects all signal handlers (for test cleanup)
    ...

# --- Static: Mastery Track Builder ---

static func build_mastery_track(sp: GlyphSpecies, mastery_pools: Dictionary) -> Array[Dictionary]:
    if sp.tier == 4:
        return []
    var objectives: Array[Dictionary] = []
    for obj: Dictionary in sp.fixed_mastery_objectives:
        var copy: Dictionary = obj.duplicate(true)
        copy["completed"] = false
        objectives.append(copy)
    var pool: Array = mastery_pools.get(sp.tier, [])
    if pool.size() > 0:
        var random_obj: Dictionary = pool[randi() % pool.size()].duplicate(true)
        random_obj["completed"] = false
        objectives.append(random_obj)
    return objectives

# --- Signal Handlers ---

func _on_battle_started(_p_squad: Array[GlyphInstance], e_squad: Array[GlyphInstance]) -> void:
    _battle_flags.clear()
    _last_technique_by_glyph.clear()
    _first_actor_id = -1
    _enemy_squad = e_squad

func _on_turn_started(glyph: GlyphInstance, _turn_idx: int) -> void:
    if _first_actor_id == -1:
        _first_actor_id = glyph.instance_id

func _on_battle_won(
    squad: Array[GlyphInstance],
    turns_taken: int,
    ko_list: Array[GlyphInstance]
) -> void:
    for glyph: GlyphInstance in squad:
        if not glyph.took_turn_this_battle or glyph.is_mastered:
            continue
        var flags: Dictionary = _get_flags(glyph.instance_id)
        # Only count player KOs for squad_no_ko (ko_list contains both sides)
        var player_kos: Array[GlyphInstance] = []
        for ko: GlyphInstance in ko_list:
            if ko.side == "player":
                player_kos.append(ko)
        _evaluate_objectives(glyph, "battle_won", {
            "turns": turns_taken,
            "no_ko": not ko_list.has(glyph),
            "squad_no_ko": player_kos.is_empty(),
            "solo": ...,    # Check only glyph took turns
            "row": glyph.row_position,
            "had_advantage": flags.get("had_advantage", false),
            "at_disadvantage": _is_at_disadvantage(glyph),
            "is_boss_battle": combat_engine.is_boss_battle,
            "enemy_count": _enemy_squad.size(),
            "finishing_blows": flags.get("finishing_blows", 0),
            "killed_higher_tier": flags.get("killed_higher_tier", false),
            "is_first_actor": glyph.instance_id == _first_actor_id,
        })

# (Additional signal handlers: _on_technique_used, _on_affinity_advantage_hit,
#  _on_interrupt_triggered, _on_finishing_blow, _on_status_applied — see source)

func _evaluate_objectives(glyph, event_type, event_data) -> void:
    for i: int in range(glyph.mastery_objectives.size()):
        var obj: Dictionary = glyph.mastery_objectives[i]
        if obj.get("completed", false):
            continue
        if _check_objective(obj, event_type, event_data, glyph):
            obj["completed"] = true
            objective_completed.emit(glyph, i)
            _check_mastery_complete(glyph)

func _check_objective(objective, event_type, event_data, glyph) -> bool:
    # Supported objective types (18+):
    # Battle-won checks: win_with_advantage, win_battle_no_ko, win_battle_front_row,
    #   win_battle_back_row, win_at_disadvantage, win_vs_3_enemies, win_battle_in_turns,
    #   solo_win, squad_no_ko, finishing_blow_count, finishing_blow_higher_tier,
    #   boss_win, first_turn, win_vs_3_no_ko
    # Immediate checks: use_technique_count, trigger_interrupt, capture_participated,
    #   apply_status, apply_status_count, finishing_blow_with_technique
    # Stubbed (complex): brace_then_survive, tank_most_damage, burn_then_kill,
    #   stun_then_kill, heal_low_hp_ally, weaken_then_null_beam
    match objective["type"]:
        "win_with_advantage":
            return event_type == "battle_won" and event_data.get("had_advantage", false)
        "win_battle_no_ko":
            return event_type == "battle_won" and event_data.get("no_ko", false)
        "win_at_disadvantage":
            return event_type == "battle_won" and event_data.get("at_disadvantage", false)
        # ... (see full source for all 18+ types)
    return false

func _check_mastery_complete(glyph: GlyphInstance) -> void:
    for obj: Dictionary in glyph.mastery_objectives:
        if not obj.get("completed", false):
            return
    glyph.is_mastered = true
    glyph.mastery_bonus_applied = true
    glyph.calculate_stats()
    glyph_mastered.emit(glyph)
```

**Implementation notes:**
- `connect_to_combat(engine)` takes the combat engine as a parameter for testability (autoloads unavailable in `--script` mode).
- `build_mastery_track()` is a public `static` method so FusionEngine can call it without instantiating a tracker.
- Per-battle tracking uses `_battle_flags` dictionary (keyed by `instance_id`) to accumulate advantage hits, finishing blows, etc., then checks them all at `battle_won` time.
- `squad_no_ko` correctly filters `ko_list` to only player-side KOs (the ko_list from CombatEngine includes both sides).
- `win_with_advantage` requires both using an advantage hit AND winning (tracked via `_battle_flags["had_advantage"]`).
- `win_at_disadvantage` checks if any enemy species had affinity advantage over the glyph's species.
- Complex species-specific objectives (`brace_then_survive`, `burn_then_kill`, etc.) are stubbed and return `false` — to be implemented in a later session if needed.

### 6.9a — CodexState

```gdscript
# core/progression/codex_state.gd
class_name CodexState
extends Node

signal species_discovered(species_id: String)
signal fusion_logged(parent_a_id: String, parent_b_id: String, result_id: String)

var discovered_species: Dictionary = {}     # species_id → true
var fusion_log: Array[Dictionary] = []      # [{parent_a, parent_b, result}]
var rifts_cleared: Dictionary = {}          # rift_id → true

func discover_species(species_id: String) -> bool:
    # Returns true if this was a NEW discovery, false if already known
    if discovered_species.has(species_id):
        return false
    discovered_species[species_id] = true
    species_discovered.emit(species_id)
    return true

func is_species_discovered(species_id: String) -> bool:
    return discovered_species.has(species_id)

func log_fusion(parent_a_id: String, parent_b_id: String, result_id: String) -> void:
    fusion_log.append({"parent_a": parent_a_id, "parent_b": parent_b_id, "result": result_id})
    fusion_logged.emit(parent_a_id, parent_b_id, result_id)

func mark_rift_cleared(rift_id: String) -> void:
    rifts_cleared[rift_id] = true

func is_rift_cleared(rift_id: String) -> bool:
    return rifts_cleared.has(rift_id)

func get_discovery_count() -> int:
    return discovered_species.size()

func get_fusion_count() -> int:
    return fusion_log.size()

func reset() -> void:
    discovered_species.clear()
    fusion_log.clear()
    rifts_cleared.clear()
```

### 6.9b — RosterState

```gdscript
# core/progression/roster_state.gd
class_name RosterState
extends Node

signal glyph_added(glyph: GlyphInstance)
signal glyph_removed(glyph: GlyphInstance)
signal squad_changed(squad: Array[GlyphInstance])

var all_glyphs: Array[GlyphInstance] = []
var active_squad: Array[GlyphInstance] = []
var max_squad_size: int = 3

func add_glyph(glyph: GlyphInstance) -> void:
    all_glyphs.append(glyph)
    glyph_added.emit(glyph)

func remove_glyph(glyph: GlyphInstance) -> void:
    all_glyphs.erase(glyph)
    active_squad.erase(glyph)
    glyph_removed.emit(glyph)

func set_active_squad(squad: Array[GlyphInstance]) -> void:
    active_squad = squad
    squad_changed.emit(squad)

func get_mastered_glyphs() -> Array[GlyphInstance]:
    var result: Array[GlyphInstance] = []
    for g: GlyphInstance in all_glyphs:
        if g.is_mastered:
            result.append(g)
    return result

func get_glyph_count() -> int:
    return all_glyphs.size()

func has_glyph(glyph: GlyphInstance) -> bool:
    return all_glyphs.has(glyph)

func reset() -> void:
    all_glyphs.clear()
    active_squad.clear()
```

### 6.10 — DungeonState

```gdscript
# core/dungeon/dungeon_state.gd
class_name DungeonState
extends RefCounted

signal room_entered(room: Dictionary)
signal room_revealed(room_id: String, room_type: String)
signal floor_changed(floor_number: int)
signal crawler_damaged(amount: int, remaining_hp: int)
signal crawler_energy_spent(amount: int, remaining: int)
signal forced_extraction()

var rift_template: RiftTemplate
var current_floor: int = 0
var current_room_id: String = ""
var floors: Array[Dictionary] = []          # Runtime floor data with revealed state
var crawler: CrawlerState                   # Reference to the global CrawlerState

func initialize(template: RiftTemplate) -> void:
    rift_template = template
    current_floor = 0
    floors = RiftGenerator.generate(template)
    crawler = CrawlerState  # Autoload reference
    crawler.begin_run(template.hazard_damage)
    _enter_floor(0)

func move_to_room(room_id: String) -> void:
    var room: Dictionary = _get_room(current_floor, room_id)
    if room.is_empty():
        return
    if not _is_connected(current_room_id, room_id):
        return

    current_room_id = room_id
    room["visited"] = true
    room["revealed"] = true
    room_entered.emit(room)

    # Handle room type effects
    match room["type"]:
        "hazard":
            if not crawler.is_reinforced:
                var dmg: int = rift_template.hazard_damage
                crawler.take_hull_damage(dmg)
                crawler_damaged.emit(dmg, crawler.hull_hp)
                if crawler.hull_hp <= 0:
                    forced_extraction.emit()
            else:
                crawler.is_reinforced = false
        "exit":
            _enter_floor(current_floor + 1)

func use_crawler_ability(ability: String) -> bool:
    var cost: int = crawler.get_ability_cost(ability)
    if crawler.energy < cost:
        return false

    crawler.spend_energy(cost)
    crawler_energy_spent.emit(cost, crawler.energy)

    match ability:
        "scan":
            _reveal_adjacent_rooms()
        "reinforce":
            crawler.is_reinforced = true
        "field_repair":
            pass  # UI handles target selection, then calls heal on the Glyph
        "purge":
            _clear_hazard_room()
        "emergency_warp":
            forced_extraction.emit()
    return true

func _enter_floor(floor_index: int) -> void:
    if floor_index >= floors.size():
        return
    current_floor = floor_index
    # Find START room
    for room: Dictionary in floors[floor_index]["rooms"]:
        if room["type"] == "start":
            current_room_id = room["id"]
            room["visited"] = true
            room["revealed"] = true
            break
    # Reveal EXIT and BOSS rooms
    for room: Dictionary in floors[floor_index]["rooms"]:
        if room["type"] in ["exit", "boss"]:
            room["revealed"] = true
    floor_changed.emit(floor_index)

func _reveal_adjacent_rooms() -> void:
    var connections: Array = floors[current_floor]["connections"]
    for conn: Array in connections:
        if current_room_id in conn:
            var other_id: String = conn[0] if conn[1] == current_room_id else conn[1]
            var room: Dictionary = _get_room(current_floor, other_id)
            if not room.is_empty() and not room["revealed"]:
                room["revealed"] = true
                room_revealed.emit(room["id"], room["type"])

func _clear_hazard_room() -> void:
    # Clear the nearest unrevealed or unvisited hazard adjacent to current room
    pass  # Implementation: find adjacent hazard rooms, change type to "empty"

func _is_connected(from_id: String, to_id: String) -> bool:
    for conn: Array in floors[current_floor]["connections"]:
        if from_id in conn and to_id in conn:
            return true
    return false

func _get_room(floor_idx: int, room_id: String) -> Dictionary:
    for room: Dictionary in floors[floor_idx]["rooms"]:
        if room["id"] == room_id:
            return room
    return {}

func get_adjacent_rooms() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for conn: Array in floors[current_floor]["connections"]:
        if current_room_id in conn:
            var other_id: String = conn[0] if conn[1] == current_room_id else conn[1]
            result.append(_get_room(current_floor, other_id))
    return result
```

### 6.11 — CrawlerState

```gdscript
# core/dungeon/crawler_state.gd
extends Node

signal hull_changed(current: int, max_hp: int)
signal energy_changed(current: int, max_energy: int)
signal item_added(item: ItemDef)
signal item_used(item: ItemDef)

# Persistent (survives between runs)
var max_hull_hp: int = 100
var max_energy: int = 50
var capacity: int = 12
var slots: int = 3
var cargo_slots: int = 2
var active_chassis: String = "standard"
var unlocked_chassis: Array[String] = ["standard"]

# Per-run (reset on each rift entry)
var hull_hp: int = 100
var energy: int = 50
var items: Array[ItemDef] = []
var is_reinforced: bool = false

const ABILITY_COSTS: Dictionary = {
    "scan": 5, "reinforce": 8, "field_repair": 10,
    "purge": 15, "emergency_warp": 25
}
const MAX_ITEMS: int = 5

func begin_run(_hazard_damage: int) -> void:
    hull_hp = max_hull_hp
    energy = max_energy
    items.clear()
    is_reinforced = false
    # Apply chassis bonuses
    match active_chassis:
        "ironclad":
            hull_hp += 25
            energy -= 5
        "scout":
            pass  # Scan cost handled in get_ability_cost()
        "hauler":
            hull_hp -= 10

func get_ability_cost(ability: String) -> int:
    var base: int = ABILITY_COSTS.get(ability, 0)
    if ability == "scan" and active_chassis == "scout":
        return 3
    # Codex 25% bonus
    if ability == "scan" and CodexState.get_discovery_percentage() >= 0.25:
        return maxi(1, base - 2)
    return base

func take_hull_damage(amount: int) -> void:
    hull_hp = maxi(0, hull_hp - amount)
    hull_changed.emit(hull_hp, max_hull_hp)

func spend_energy(amount: int) -> void:
    energy = maxi(0, energy - amount)
    energy_changed.emit(energy, max_energy)

func add_item(item: ItemDef) -> bool:
    if items.size() >= MAX_ITEMS:
        return false
    items.append(item)
    item_added.emit(item)
    return true

func use_item(item: ItemDef) -> void:
    items.erase(item)
    item_used.emit(item)

func apply_upgrade(upgrade: Dictionary) -> void:
    match upgrade["type"]:
        "hull_hp":
            max_hull_hp += upgrade["value"]
        "energy":
            max_energy += upgrade["value"]
        "capacity":
            capacity += upgrade["value"]
        "cargo":
            cargo_slots += upgrade["value"]
        "chassis":
            if upgrade["chassis_id"] not in unlocked_chassis:
                unlocked_chassis.append(upgrade["chassis_id"])
```

### 6.12 — GameState (Top-Level State Machine)

```gdscript
# core/game_state.gd
extends Node

enum State { TITLE, BASTION, RIFT, COMBAT, PUZZLE }

var current_state: State = State.TITLE
var current_dungeon: DungeonState = null
var mastery_tracker: MasteryTracker = MasteryTracker.new()
var game_phase: int = 1  # 1-5, drives NPC dialogue and rift availability

func _ready() -> void:
    mastery_tracker.connect_to_combat(CombatEngine)

func transition_to(new_state: State, params: Dictionary = {}) -> void:
    current_state = new_state
    match new_state:
        State.TITLE:
            get_tree().change_scene_to_file("res://ui/screens/title_screen.tscn")
        State.BASTION:
            get_tree().change_scene_to_file("res://ui/bastion/bastion_scene.tscn")
        State.RIFT:
            var template: RiftTemplate = params.get("template", null)
            if template:
                current_dungeon = DungeonState.new()
                current_dungeon.initialize(template)
            get_tree().change_scene_to_file("res://ui/dungeon/dungeon_scene.tscn")
        State.COMBAT:
            get_tree().change_scene_to_file("res://ui/battle/battle_scene.tscn")
        State.PUZZLE:
            var puzzle_scene: String = params.get("puzzle_scene", "")
            if puzzle_scene != "":
                get_tree().change_scene_to_file(puzzle_scene)

func start_new_game() -> void:
    game_phase = 1
    RosterState.initialize_starting_glyphs()
    CrawlerState.max_hull_hp = 100
    CrawlerState.max_energy = 50
    CrawlerState.capacity = 12
    CodexState.reset()
    transition_to(State.BASTION)

func complete_rift(rift_id: String) -> void:
    CodexState.mark_rift_cleared(rift_id)
    _check_phase_advancement()
    transition_to(State.BASTION)

func _check_phase_advancement() -> void:
    # Advance game_phase based on number of rifts cleared
    var cleared: int = CodexState.cleared_rift_count()
    if cleared >= 1 and game_phase < 2:
        game_phase = 2
    elif cleared >= 3 and game_phase < 3:
        game_phase = 3
    elif cleared >= 5 and game_phase < 4:
        game_phase = 4
    elif cleared >= 6 and game_phase < 5:
        game_phase = 5
```

---

## 7. Presentation Layer — Key Scene Structures

### 7.1 — Battle Scene Tree

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
│   │   │   ├── EnemyPanel1 (GlyphPanel)
│   │   │   └── EnemyPanel2 (GlyphPanel)
│   │   └── EnemyBackRow (HBoxContainer)
│   │       └── EnemyPanel3 (GlyphPanel)
│   └── PlayerSide (HBoxContainer)
│       ├── PlayerFrontRow (HBoxContainer)
│       │   ├── PlayerPanel1 (GlyphPanel)
│       │   └── PlayerPanel2 (GlyphPanel)
│       └── PlayerBackRow (HBoxContainer)
│           └── PlayerPanel3 (GlyphPanel)
├── TurnOrderBar (HBoxContainer)             # Top of screen
│   ├── Portrait1..6 (GlyphPortrait)
├── ActionMenu (VBoxContainer)               # Bottom of screen
│   ├── AttackButton (Button)
│   ├── GuardButton (Button)
│   └── SwapButton (Button)
├── TechniqueList (VBoxContainer)            # Slides in when Attack is pressed
│   └── TechniqueButton (template)
├── TargetHighlights (Control)               # Overlay for target selection
├── CombatLog (ScrollContainer)
│   └── LogText (RichTextLabel)
└── PhaseTransitionOverlay (ColorRect)       # Flash + text for boss phase 2
```

**Signal flow:**
1. `CombatEngine.turn_started` → `BattleScene` shows ActionMenu if player turn, or waits for AI.
2. Player clicks Attack → TechniqueList shows available techniques.
3. Player selects technique → TargetHighlights shows valid targets.
4. Player clicks target → `CombatEngine.submit_action()` called.
5. `CombatEngine.technique_used` → `BattleField` plays damage animation, updates HP bars.
6. `CombatEngine.turn_queue_updated` → `TurnOrderBar` refreshes portraits.

### 7.2 — Dungeon Scene Tree

```
DungeonScene (Control)
├── FloorMap (Control)                       # Node graph rendering
│   └── RoomNodes (Node2D)                   # Dynamically spawned RoomNode instances
│       ├── RoomNode1..N (RoomNode.tscn)
│       └── ConnectionLines (Line2D pool)
├── CrawlerHUD (CanvasLayer)
│   ├── HullBar (HpBar)
│   ├── EnergyBar (HpBar)
│   ├── ItemBar (HBoxContainer)
│   │   └── ItemSlot1..5 (TextureRect)
│   └── AbilityButtons (HBoxContainer)
│       ├── ScanButton (Button)
│       ├── ReinforceButton (Button)
│       ├── FieldRepairButton (Button)
│       ├── PurgeButton (Button)
│       └── WarpButton (Button)
└── RoomPopup (PanelContainer)               # Shows room details on entry
    ├── RoomTitle (Label)
    ├── RoomDescription (Label)
    └── ActionButton (Button)                # "Fight", "Open Cache", "Attempt Puzzle", etc.
```

**Room rendering:** Each `RoomNode` is a `Control` or `TextureRect` positioned at the grid coordinates from the template data × a cell size constant (e.g., 80px). Connections are drawn as `Line2D` between room centers. Fog of war is implemented by setting unrevealed rooms to a dim "?" texture and revealed-but-unvisited rooms to their type icon at reduced opacity.

### 7.3 — Fusion Chamber Scene Tree

```
FusionChamber (Control)
├── ParentSlots (HBoxContainer)
│   ├── ParentSlotA (GlyphPortrait)           # Drag target or click-to-select
│   └── ParentSlotB (GlyphPortrait)
├── RosterPicker (ScrollContainer)            # Scrollable grid of owned Glyphs
│   └── GlyphGrid (GridContainer)
│       └── GlyphCard (template, instanced per Glyph)
├── PreviewPanel (VBoxContainer)
│   ├── ResultTier (Label)
│   ├── ResultAffinity (TextureRect + Label)
│   ├── ResultSpecies (Label)                 # "???" or name
│   ├── InheritedStats (StatDisplay)
│   ├── TechniqueInheritance (VBoxContainer)  # Technique selection toggles
│   │   └── TechniqueOption (template)
│   └── GPWarning (Label)                     # Yellow text if GP > capacity
├── ConfirmButton (Button)
└── DiscoveryOverlay (ColorRect + AnimationPlayer)  # "NEW DISCOVERY" animation
```

---

## 8. JSON Data File Schemas

### 8.1 — glyphs.json

```json
[
  {
    "id": "zapplet",
    "name": "Zapplet",
    "tier": 1,
    "affinity": "electric",
    "gp_cost": 2,
    "base_hp": 12,
    "base_atk": 10,
    "base_def": 8,
    "base_spd": 14,
    "base_res": 9,
    "technique_ids": ["static_snap", "jolt_rush"],
    "fixed_mastery_objectives": [
      {
        "type": "use_technique_count",
        "params": {"technique_id": "jolt_rush", "target": 3, "current": 0},
        "description": "Use Jolt Rush 3 times."
      },
      {
        "type": "win_battle_no_ko",
        "params": {},
        "description": "Win a battle without Zapplet being knocked out."
      }
    ]
  }
]
```

### 8.2 — techniques.json

```json
[
  {
    "id": "static_snap",
    "name": "Static Snap",
    "category": "offensive",
    "affinity": "electric",
    "range_type": "ranged",
    "power": 8,
    "cooldown": 0,
    "status_effect": "",
    "status_accuracy": 0,
    "interrupt_trigger": "",
    "support_effect": "",
    "support_value": 0.0,
    "description": "A quick jolt of electric energy."
  },
  {
    "id": "static_guard",
    "name": "Static Guard",
    "category": "interrupt",
    "affinity": "electric",
    "range_type": "melee",
    "power": 10,
    "cooldown": 3,
    "status_effect": "",
    "status_accuracy": 0,
    "interrupt_trigger": "ON_MELEE",
    "support_effect": "reduce_incoming_50",
    "support_value": 0.5,
    "description": "When guarding, counters melee attacks with electric damage and halves incoming damage."
  }
]
```

### 8.3 — fusion_table.json

```json
[
  {"parent_a": "zapplet", "parent_b": "sparkfin", "result": "thunderclaw"},
  {"parent_a": "zapplet", "parent_b": "stonepaw", "result": "vortail"},
  {"parent_a": "zapplet", "parent_b": "mossling", "result": "ironbark"}
]
```

DataLoader normalizes both orderings on load. The full table from GDD 7.5 must be entered here (all 30+ entries including same-species fusions).

### 8.4 — rift_templates.json

```json
[
  {
    "rift_id": "minor_01",
    "name": "The Frayed Edge",
    "tier": "minor",
    "hazard_damage": 10,
    "enemy_tier_pool": [1],
    "wild_glyph_pool": ["zapplet", "sparkfin", "stonepaw", "mossling", "driftwisp", "glitchkit"],
    "floors": [
      {
        "floor_number": 0,
        "rooms": [
          {"id": "f0_r0", "x": 0, "y": 0, "type": "start"},
          {"id": "f0_r1", "x": 1, "y": 0, "pool": "pool_a"},
          {"id": "f0_r2", "x": 2, "y": 0, "pool": "pool_b"},
          {"id": "f0_r3", "x": 1, "y": 1, "pool": "pool_a"},
          {"id": "f0_r4", "x": 2, "y": 1, "pool": "pool_c"},
          {"id": "f0_r5", "x": 1, "y": 2, "type": "exit"}
        ],
        "connections": [
          ["f0_r0", "f0_r1"], ["f0_r1", "f0_r2"],
          ["f0_r1", "f0_r3"], ["f0_r3", "f0_r4"],
          ["f0_r3", "f0_r5"]
        ]
      }
    ],
    "content_pools": {
      "pool_a": {"enemy": 0.60, "empty": 0.25, "hazard": 0.15},
      "pool_b": {"cache": 0.50, "puzzle": 0.30, "enemy": 0.20},
      "pool_c": {"hazard": 0.40, "enemy": 0.35, "hidden_eligible": 0.25}
    },
    "boss": {
      "species_id": "ironbark",
      "stat_modifier": 1.2,
      "phase1_technique_ids": ["iron_ram", "fortress"],
      "phase2_technique_ids": ["quake_stomp"],
      "phase2_stat_bonus": {"atk": 0.1, "spd": 0.1}
    }
  }
]
```

---

## 9. Build Plan — Claude Code Sessions

Each session has a **goal**, **inputs** (what to feed Claude Code), **deliverables**, and **validation criteria**.

### Session 1 — Data Layer Foundation

**Goal:** Load all JSON data and instantiate Resource objects. Prove every species, technique, and template parses correctly.

**Inputs:**
- This TDD: Sections 3, 4, 5, 8
- GDD: Appendix A (all 15 Glyph definitions), Section 8.9 (all techniques)
- Instruction: "Create the Godot 4.6 project structure, all Resource classes, the DataLoader autoload, and all JSON data files. Write a test scene that loads everything and prints validation to the console."

**Deliverables:**
- `project.godot` with DataLoader autoload registered
- All 6 Resource class scripts
- All 10 JSON data files fully populated
- `tests/test_data_loader.gd` — prints species count, technique count, fusion table size, template count

**Validation:**
- Run the project. Console output shows: "15 species loaded, 39 techniques loaded, 33 fusion pairs loaded, 7 rift templates loaded" (numbers may vary — the point is all data is present and no parse errors).
- No GDScript errors or warnings.

### Session 2 — Combat Engine (Headless)

**Goal:** Turn-based combat fully functional. Can simulate battles in code without any UI.

**Inputs:**
- This TDD: Sections 6.2–6.7
- GDD: Section 8 (complete)
- The DataLoader and data files from Session 1
- Instruction: "Implement GlyphInstance, CombatEngine, DamageCalculator, TurnQueue, StatusManager, and AIController. Write a test script that creates two squads of 3 T1 Glyphs, starts a battle, and runs it to completion via AI on both sides, printing every event to the console."

**Deliverables:**
- All combat scripts in `core/combat/`
- `core/glyph/glyph_instance.gd`
- `tests/test_combat.gd`

**Validation:**
- Run test. Output shows: turn order, each action taken, damage dealt, status effects applied/expired, KOs, and a final WIN/LOSS result.
- Run 10 times — no crashes, results are deterministic (SPD tiebreaks are deterministic; only damage variance differs).
- Manually verify one battle: check damage formula against GDD 8.8 by hand.

### Session 3 — Mastery + Fusion (Headless)

**Goal:** Mastery objectives track and complete. Fusion produces correct results with proper stat inheritance.

**Inputs:**
- This TDD: Sections 6.8–6.9
- GDD: Sections 6 and 7 (complete)
- Sessions 1–2 output
- Instruction: "Implement MasteryTracker and FusionEngine. Write a test that: (1) creates 2 Zapplets, (2) runs battles until both are mastered, (3) fuses them, (4) validates the result is Thunderclaw with correct inherited stats and techniques."

**Deliverables:**
- `core/glyph/mastery_tracker.gd`
- `core/glyph/fusion_engine.gd` (Autoload)
- `core/progression/codex_state.gd`
- `core/progression/roster_state.gd`
- `tests/test_mastery_fusion.gd`

**Validation:**
- Mastery objectives complete based on battle events (verify at least 3 different objective types trigger).
- Fusion output matches GDD 7.5 table.
- Stat inheritance matches GDD 7.2 formula (calculate by hand for one case).
- Technique inheritance respects 4-technique cap.

### Session 4 — Dungeon + Crawler (Headless)

**Goal:** Can generate a rift, navigate room-by-room, trigger encounters, manage Crawler resources.

**Inputs:**
- This TDD: Sections 6.10–6.11
- GDD: Section 9 (complete)
- Sessions 1–3 output
- Instruction: "Implement DungeonState, CrawlerState, RiftGenerator, and CaptureCalculator. Write a test that generates The Frayed Edge rift, moves the Crawler room by room through all floors, prints room types, handles hazards and energy usage, and triggers a boss encounter at the end."

**Deliverables:**
- All scripts in `core/dungeon/`
- `tests/test_dungeon.gd`

**Validation:**
- Rift generates with correct number of floors and rooms per template.
- Room content pools resolve to valid types.
- Connections are bidirectional and consistent.
- Hazards deal correct hull damage per rift tier.
- Energy spending matches ability costs including chassis bonuses.
- Fog of war reveals correctly on move and scan.

### Session 5 — Game State + Text-Based Playthrough

**Goal:** Wire all systems into a single playable loop. A complete run (start → rift → combat → fusion → next rift) is playable via console output and keyboard input.

**Inputs:**
- This TDD: Section 6.12
- GDD: Section 12 (progression arc)
- Sessions 1–4 output
- Instruction: "Implement GameState. Create a test scene that runs the full game loop in text mode: start with 3 T1 Glyphs, enter Minor Rift 1, navigate rooms, fight battles, capture Glyphs, return to base, fuse, enter Minor Rift 2. Use keyboard input for player decisions (numbered menus in the console). The game should be fun to play in a terminal."

**Deliverables:**
- `core/game_state.gd` (Autoload)
- `tests/test_full_loop.gd` — a playable text adventure version of the game

**Validation:**
- Can complete two rift runs and perform at least one fusion.
- Mastery tracks correctly across rift runs.
- Crawler state resets per run, upgrades persist.
- No crashes over a 30-minute play session.
- The game feels like it works — decisions matter, combat resolves correctly, fusion produces expected results.

**This is the critical milestone.** If Session 5 produces a playable text game, the core is solid and everything from here is UI.

### Session 6 — Battle UI

**Inputs:** This TDD Section 7.1, GDD Section 8, all core systems

**Goal:** Render the combat system visually. Formation setup, turn order bar, action selection, technique targeting, damage display, status icons, KO animations, boss phase transition.

**Approach:** Start with placeholder colored rectangles for Glyph sprites. Focus on: (1) formation drag-and-drop, (2) turn order bar updates, (3) action menu flow (Attack → technique list → target select → resolve), (4) HP bar animations, (5) interrupt visual flash.

### Session 7 — Dungeon UI

**Inputs:** This TDD Section 7.2, GDD Section 9

**Goal:** Render the dungeon floor as a node graph. Clickable rooms, fog of war, Crawler HUD with energy/hull bars and ability buttons. Room entry triggers (combat, cache popup, hazard damage).

### Session 8 — Bastion UI (Hub + Fusion + Barracks)

**Inputs:** This TDD Section 7.3, GDD Sections 7.7 and 11

**Goal:** Bastion hub menu. Fusion Chamber with full preview and discovery animation. Barracks with squad management and formation presets. Rift Gate with rift selection.

### Session 9 — Codex + NPCs + Puzzles

**Inputs:** GDD Sections 9.4, 10, 11.2

**Goal:** Codex browser with silhouettes/reveals. NPC dialogue system. Three puzzle room implementations.

### Session 10 — Polish + Tutorial + Full Playthrough

**Goal:** Tutorial rift scripting. Scene transitions. End-to-end playthrough from title screen through Apex Rift. Bug fixing, balance pass, UI polish.

---

## 10. Testing Strategy

### 10.1 — Test Runner

```gdscript
# tests/test_runner.gd
extends SceneTree

func _init() -> void:
    # Run all test files
    var tests: Array[String] = [
        "res://tests/test_data_loader.gd",
        "res://tests/test_damage_calc.gd",
        "res://tests/test_combat_engine.gd",
        "res://tests/test_fusion.gd",
        "res://tests/test_mastery.gd",
        "res://tests/test_rift_generation.gd",
    ]
    for test_path: String in tests:
        var test_script: GDScript = load(test_path) as GDScript
        var test_instance: Node = test_script.new()
        root.add_child(test_instance)
        # Each test script calls its own test functions in _ready()
        # and prints PASS/FAIL per test case
    # Exit after tests complete
    await get_tree().create_timer(2.0).timeout
    quit()
```

Run via: `godot --headless --script res://tests/test_runner.gd`

### 10.2 — What to Test Per System

| System | Key Test Cases |
|---|---|
| DamageCalculator | Affinity multipliers (all 9 combinations), row modifiers, guard modifier, status modifiers, minimum damage 1, variance range |
| TurnQueue | SPD ordering, deterministic tiebreak cascade (tier > affinity > HP% > side > name), boss-last-on-turn-1 |
| StatusManager | Apply, tick, expire, immunity window, no stacking, Burn damage calc |
| CombatEngine | Full battle resolution, interrupt triggering, KO handling, battle end conditions |
| FusionEngine | All table lookups, stat inheritance math, technique cap, tier validation |
| MasteryTracker | Each objective type triggers correctly, multi-complete in one battle, persistence |
| RiftGenerator | Template loading, pool resolution, connection integrity |
| CrawlerState | Energy costs, chassis bonuses, hull damage, item limit |
| CaptureCalculator | Probability formula, par turns, no-KO bonus, cap at 80% |

---

## 11. Performance Considerations

This is a turn-based 2D game. Performance is not a concern for the prototype. However:

- **Avoid allocating new objects per frame.** Combat state should be modified in place, not recreated per turn.
- **Signal connections:** Disconnect mastery tracker from combat signals when not in combat. Reconnect on battle start. This prevents phantom signal calls.
- **JSON loading:** Load all data once in `DataLoader._ready()`. Never re-parse JSON during gameplay.
- **Scene transitions:** Use `change_scene_to_file()` for major transitions. The current scene is freed automatically. Autoloads persist.

---

## 12. Godot 4.6 Specific Notes

- **Typed arrays** (`Array[GlyphInstance]`) are used throughout. These are fully supported in 4.6 and provide runtime type safety.
- **Static typing** should be used on all variables, parameters, and return types. Godot 4.6 GDScript benefits from typed code for both editor autocompletion and runtime performance.
- **`class_name`** is used on all Resource subclasses and data classes for global type registration.
- **`RefCounted`** is used for data classes that don't need to be in the scene tree (`GlyphInstance`, `DungeonState`, `TurnQueue`). This avoids Node overhead and allows garbage collection.
- **Autoloads** extend `Node` (required by Godot).
- **`@export`** is used on Resource properties but is not strictly necessary since we populate them from JSON. It's included for editor visibility if designers want to inspect or override values in the Inspector.
- **Signals with typed parameters** are fully supported in 4.6: `signal battle_won(squad: Array[GlyphInstance], turns: int, ko_list: Array[GlyphInstance])`.

---

*End of Technical Design Document. This spec, combined with the GDD v0.3, provides everything needed to implement the Glyphrift prototype in Godot 4.6 via phased Claude Code sessions.*
