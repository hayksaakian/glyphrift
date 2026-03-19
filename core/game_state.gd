class_name GameState
extends Node

## Top-level state machine per TDD 6.12.
## Orchestrates transitions between game phases and tracks progression.

enum State { TITLE, BASTION, RIFT, COMBAT, EVENT }

signal state_changed(new_state: int)
signal phase_advanced(new_phase: int)
signal rift_completed(rift_id: String)
signal milestone_awarded(upgrade_id: String, description: String)

var current_state: int = State.TITLE
var current_dungeon: DungeonState = null
var mastery_tracker: MasteryTracker = null
var game_phase: int = 1
var npc_read_phase: Dictionary = {"kael": 0, "lira": 0, "maro": 0}
var npc_read_quest: Dictionary = {"kael": "", "lira": "", "maro": ""}  ## quest state last seen
var completed_quests: Dictionary = {}  ## quest_id → true

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
	2: ["minor_01", "minor_02", "minor_03", "minor_04"],
	3: ["standard_01", "standard_02"],
	4: ["major_01", "major_02"],
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
	crawler_state.bench_slots = 2
	crawler_state.active_chassis = "standard"
	crawler_state.unlocked_chassis = ["standard"]
	npc_read_phase = {"kael": 0, "lira": 0, "maro": 0}
	npc_read_quest = {"kael": "", "lira": "", "maro": ""}
	completed_quests.clear()
	crawler_state.has_rift_transmitter = false
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


func check_quest_status(npc_id: String) -> Dictionary:
	## Returns quest status for an NPC: {available, active, complete, quest_data, progress, total}
	if data_loader == null or not data_loader.npc_quests.has(npc_id):
		return {}
	var quest: Dictionary = data_loader.npc_quests[npc_id]
	var quest_id: String = quest.get("id", "")
	if completed_quests.has(quest_id):
		return {"state": "done", "quest": quest}
	if game_phase < int(quest.get("min_phase", 1)):
		return {"state": "locked", "quest": quest}

	var condition: String = quest.get("condition", "")
	var progress: int = _get_quest_progress(condition)
	var total: int = _get_quest_total(condition)
	var is_complete: bool = progress >= total
	return {
		"state": "complete" if is_complete else "active",
		"quest": quest,
		"progress": progress,
		"total": total,
	}


func complete_quest(npc_id: String) -> String:
	## Complete the NPC's quest and apply reward. Returns reward text.
	var status: Dictionary = check_quest_status(npc_id)
	if status.get("state", "") != "complete":
		return ""
	var quest: Dictionary = status["quest"]
	var quest_id: String = quest.get("id", "")
	completed_quests[quest_id] = true

	var reward_type: String = quest.get("reward_type", "")
	var reward_value: int = int(quest.get("reward_value", 0))
	match reward_type:
		"codex_reveal":
			if codex_state != null:
				for _i: int in range(reward_value):
					_reveal_random_species()
		"capacity":
			if crawler_state != null:
				crawler_state.capacity += reward_value
		"hull_hp":
			if crawler_state != null:
				crawler_state.max_hull_hp += reward_value
		"energy":
			if crawler_state != null:
				crawler_state.max_energy += reward_value

	return quest.get("reward_text", "Quest complete!")


func _get_quest_progress(condition: String) -> int:
	match condition:
		"codex_discoveries_8":
			if codex_state != null:
				return codex_state.discovered_species.size()
			return 0
		"rifts_cleared_3":
			if codex_state != null:
				return codex_state.cleared_rift_count()
			return 0
		"hidden_rooms_3":
			if milestone_tracker != null:
				return milestone_tracker.hidden_rooms_found
			return 0
	return 0


func _get_quest_total(condition: String) -> int:
	match condition:
		"codex_discoveries_8":
			return 8
		"rifts_cleared_3":
			return 3
		"hidden_rooms_3":
			return 3
	return 1


func _reveal_random_species() -> void:
	if codex_state == null or data_loader == null:
		return
	for species_id: String in data_loader.species:
		if not codex_state.discovered_species.has(species_id):
			codex_state.discover_species(species_id)
			return


func _check_phase_advancement() -> void:
	var cleared: int = codex_state.cleared_rift_count()
	for target_phase: int in [5, 4, 3, 2]:
		if game_phase < target_phase and cleared >= PHASE_THRESHOLDS[target_phase]:
			game_phase = target_phase
			phase_advanced.emit(game_phase)
			return
