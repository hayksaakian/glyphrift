class_name MilestoneTracker
extends RefCounted

## Tracks crawler upgrade milestones per GDD 4.5.
## Checks conditions after key events and awards upgrades via CrawlerState.

signal milestone_completed(upgrade_id: String, description: String)

## Persistent progress
var completed_milestones: Dictionary = {}  ## upgrade_id → true
var hidden_rooms_found: int = 0

## Per-run tracking
var _run_capture_affinities: Dictionary = {}  ## affinity → true

## Injectable dependencies
var crawler_state: CrawlerState = null
var codex_state: CodexState = null
var data_loader: Node = null

## Upgrade definitions loaded from data
var _upgrades: Array[Dictionary] = []


func initialize(p_data_loader: Node) -> void:
	data_loader = p_data_loader
	if data_loader != null and data_loader.has_method("get_crawler_upgrades"):
		_upgrades = data_loader.get_crawler_upgrades()


func begin_run() -> void:
	_run_capture_affinities.clear()


func on_capture(glyph: GlyphInstance) -> void:
	## Track affinity of captured glyph for all-affinities milestone
	if glyph != null and glyph.species != null:
		_run_capture_affinities[glyph.species.affinity] = true
	_check_all_affinities()


func on_hidden_room_discovered() -> void:
	hidden_rooms_found += 1
	_check_hidden_room_milestones()


func on_rift_completed(rift_template: RiftTemplate, is_first_clear: bool) -> void:
	## Re-entered rifts don't grant milestone progress (GDD 9.8)
	if not is_first_clear:
		return

	## Check no-damage milestone
	if crawler_state != null and not crawler_state.took_hull_damage_this_run:
		_award_milestone("hull_no_damage")

	## Check major rift milestone
	if rift_template != null and rift_template.tier == "major":
		_award_milestone("seal_major_rift")

	## Check all-affinities (end of run is also a valid check point)
	_check_all_affinities()


func on_fusion_performed() -> void:
	_check_fusion_milestone()


func _check_hidden_room_milestones() -> void:
	if hidden_rooms_found >= 1:
		_award_milestone("hidden_room_1")
	if hidden_rooms_found >= 3:
		_award_milestone("hidden_room_3")
	if hidden_rooms_found >= 5:
		_award_milestone("hidden_room_5")


func _check_all_affinities() -> void:
	if _run_capture_affinities.has("electric") and \
	   _run_capture_affinities.has("ground") and \
	   _run_capture_affinities.has("water"):
		_award_milestone("all_affinities")


func _check_fusion_milestone() -> void:
	if codex_state == null:
		return
	## Count unique result species in fusion log
	var unique_results: Dictionary = {}
	for entry: Dictionary in codex_state.fusion_log:
		unique_results[entry.get("result", "")] = true
	if unique_results.size() >= 10:
		_award_milestone("fuse_10_unique")


func _award_milestone(upgrade_id: String) -> void:
	if completed_milestones.has(upgrade_id):
		return

	var upgrade: Dictionary = _find_upgrade(upgrade_id)
	if upgrade.is_empty():
		return

	completed_milestones[upgrade_id] = true

	if crawler_state != null:
		crawler_state.apply_upgrade(upgrade)

	var desc: String = upgrade.get("description", "")
	milestone_completed.emit(upgrade_id, desc)


func _find_upgrade(upgrade_id: String) -> Dictionary:
	for u: Dictionary in _upgrades:
		if u.get("id", "") == upgrade_id:
			return u
	return {}


func get_milestone_progress() -> Array[Dictionary]:
	## Returns all milestones with completion status for UI display
	var result: Array[Dictionary] = []
	for u: Dictionary in _upgrades:
		var entry: Dictionary = u.duplicate()
		entry["completed"] = completed_milestones.has(u.get("id", ""))
		result.append(entry)
	return result


func is_completed(upgrade_id: String) -> bool:
	return completed_milestones.has(upgrade_id)
