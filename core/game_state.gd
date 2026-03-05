class_name GameState
extends Node

## Top-level state machine per TDD 6.12.
## Orchestrates transitions between game phases and tracks progression.

enum State { TITLE, BASTION, RIFT, COMBAT, PUZZLE }

signal state_changed(new_state: int)
signal phase_advanced(new_phase: int)
signal rift_completed(rift_id: String)
signal milestone_awarded(upgrade_id: String, description: String)

var current_state: int = State.TITLE
var current_dungeon: DungeonState = null
var mastery_tracker: MasteryTracker = null
var game_phase: int = 1
var npc_read_phase: Dictionary = {"kael": 0, "lira": 0, "maro": 0}

## Injectable dependencies
var data_loader: Node = null
var roster_state: RosterState = null
var codex_state: CodexState = null
var crawler_state: CrawlerState = null
var combat_engine: Node = null
var fusion_engine: FusionEngine = null
var milestone_tracker: MilestoneTracker = null

## Rift availability by phase
const PHASE_RIFTS: Dictionary = {
	1: ["tutorial_01"],
	2: ["minor_01", "minor_02"],
	3: ["standard_01", "standard_02"],
	4: ["major_01"],
	5: ["apex_01"],
}

## Phase advancement thresholds: phase N+1 requires N cleared rifts
const PHASE_THRESHOLDS: Dictionary = {
	2: 1,
	3: 3,
	4: 5,
	5: 6,
}


func transition_to(new_state: int) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func start_new_game() -> void:
	game_phase = 1
	codex_state.reset()
	roster_state.initialize_starting_glyphs(data_loader)
	## Discover the 3 starter species
	codex_state.discover_species("zapplet")
	codex_state.discover_species("stonepaw")
	codex_state.discover_species("driftwisp")
	## Reset crawler to defaults
	crawler_state.max_hull_hp = 100
	crawler_state.max_energy = 50
	crawler_state.capacity = 12
	crawler_state.slots = 3
	crawler_state.cargo_slots = 2
	crawler_state.active_chassis = "standard"
	crawler_state.unlocked_chassis = ["standard"]
	npc_read_phase = {"kael": 0, "lira": 0, "maro": 0}
	## Reset milestones
	if milestone_tracker != null:
		milestone_tracker.completed_milestones.clear()
		milestone_tracker.hidden_rooms_found = 0
	transition_to(State.BASTION)


func get_available_rifts() -> Array[RiftTemplate]:
	var result: Array[RiftTemplate] = []
	for phase: int in range(1, game_phase + 1):
		if PHASE_RIFTS.has(phase):
			for rift_id: String in PHASE_RIFTS[phase]:
				var template: RiftTemplate = data_loader.get_rift_template(rift_id)
				if template != null:
					result.append(template)
	return result


func start_rift(template: RiftTemplate) -> void:
	current_dungeon = DungeonState.new()
	current_dungeon.crawler = crawler_state
	current_dungeon.initialize(template)
	if milestone_tracker != null:
		milestone_tracker.begin_run()
	transition_to(State.RIFT)


func complete_rift(rift_id: String) -> void:
	var is_first_clear: bool = not codex_state.is_rift_cleared(rift_id)
	codex_state.mark_rift_cleared(rift_id)

	## Check milestones before clearing dungeon reference
	if milestone_tracker != null and current_dungeon != null:
		milestone_tracker.on_rift_completed(current_dungeon.rift_template, is_first_clear)

	rift_completed.emit(rift_id)
	_check_phase_advancement()
	current_dungeon = null
	transition_to(State.BASTION)


func notify_capture(glyph: GlyphInstance) -> void:
	if milestone_tracker != null:
		milestone_tracker.on_capture(glyph)


func notify_hidden_room() -> void:
	if milestone_tracker != null:
		milestone_tracker.on_hidden_room_discovered()


func notify_fusion() -> void:
	if milestone_tracker != null:
		milestone_tracker.on_fusion_performed()


func _check_phase_advancement() -> void:
	var cleared: int = codex_state.cleared_rift_count()
	for target_phase: int in [5, 4, 3, 2]:
		if game_phase < target_phase and cleared >= PHASE_THRESHOLDS[target_phase]:
			game_phase = target_phase
			phase_advanced.emit(game_phase)
			return
