class_name DungeonState
extends RefCounted

var rift_template: RiftTemplate
var floors: Array[Dictionary] = []
var current_floor: int = 0
var current_room_id: String = ""

## Injectable dependency (not autoload — tests instantiate manually)
var crawler: CrawlerState

signal room_entered(room: Dictionary)
signal room_shown(room_id: String)
signal room_revealed(room_id: String, room_type: String)
signal floor_changed(floor_number: int)
signal exit_reached(floor_number: int)
signal crawler_damaged(amount: int, remaining_hp: int)
signal crawler_energy_spent(amount: int, remaining: int)
signal forced_extraction()


func initialize(template: RiftTemplate) -> void:
	rift_template = template
	floors = RiftGenerator.generate(template)
	crawler.begin_run(template.hazard_damage)
	_enter_floor(0)


func initialize_with_floors(template: RiftTemplate, prebuilt_floors: Array[Dictionary]) -> void:
	## For testing: inject pre-built floors instead of generating randomly
	rift_template = template
	floors = prebuilt_floors
	crawler.begin_run(template.hazard_damage)
	_enter_floor(0)


func restore_from_save(template: RiftTemplate, saved_floors: Array[Dictionary], floor_idx: int, room_id: String) -> void:
	## Restore dungeon state from save — does NOT reset crawler (caller must restore crawler run state).
	rift_template = template
	floors = saved_floors
	current_floor = floor_idx
	current_room_id = room_id
	## Don't call _enter_floor (would reset room states and emit signals).
	## Just emit floor_changed so the UI picks up the current floor.
	floor_changed.emit(current_floor)


func move_to_room(room_id: String) -> bool:
	var room: Dictionary = _get_room(current_floor, room_id)
	if room.is_empty():
		return false
	if not _is_connected(current_room_id, room_id):
		return false

	current_room_id = room_id
	room["visited"] = true
	room["revealed"] = true
	room["visible"] = true
	room_entered.emit(room)

	## Show adjacent rooms as foggy (visible but type unknown)
	_show_adjacent_rooms()

	## Handle room type effects
	match room["type"]:
		"hazard":
			_handle_hazard()
		"exit":
			exit_reached.emit(current_floor + 1)

	return true


func use_crawler_ability(ability: String) -> bool:
	var cost: int = crawler.get_ability_cost(ability)
	if cost < 0:
		return false
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
			pass  ## UI handles target selection, then calls heal on Glyph
		"purge":
			_clear_hazard_room()
		"emergency_warp":
			forced_extraction.emit()

	return true


func descend() -> void:
	_enter_floor(current_floor + 1)


func find_path(target_id: String) -> Array[String]:
	## BFS shortest path from current_room_id to target_id.
	## Only traverses visible rooms. Returns room IDs (start excluded, target included).
	if current_room_id == target_id or current_floor >= floors.size():
		return []
	var floor_data: Dictionary = floors[current_floor]

	## Build adjacency map for visible rooms
	var adj: Dictionary = {}
	for room: Dictionary in floor_data["rooms"]:
		if room.get("visible", false):
			adj[room["id"]] = []
	## Include current room even if not marked visible
	if not adj.has(current_room_id):
		adj[current_room_id] = []

	for conn: Array in floor_data["connections"]:
		var a: String = conn[0]
		var b: String = conn[1]
		if adj.has(a) and adj.has(b):
			adj[a].append(b)
			adj[b].append(a)

	## BFS
	var queue: Array = [current_room_id]
	var came_from: Dictionary = {current_room_id: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == target_id:
			var path: Array[String] = []
			var step: String = target_id
			while step != current_room_id:
				path.push_front(step)
				step = came_from[step]
			return path
		for neighbor: Variant in adj.get(current, []):
			if not came_from.has(neighbor):
				came_from[neighbor] = current
				queue.append(neighbor)
	return []


func get_current_room() -> Dictionary:
	return _get_room(current_floor, current_room_id)


func get_adjacent_rooms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if current_floor >= floors.size():
		return result
	var floor_data: Dictionary = floors[current_floor]
	for conn: Array in floor_data["connections"]:
		var other_id: String = ""
		if conn[0] == current_room_id:
			other_id = conn[1]
		elif conn[1] == current_room_id:
			other_id = conn[0]
		if other_id != "":
			var room: Dictionary = _get_room(current_floor, other_id)
			if not room.is_empty():
				result.append(room)
	return result


# --- Private ---


func _enter_floor(floor_index: int) -> void:
	if floor_index >= floors.size():
		return  ## Rift complete — current_floor stays at last valid floor
	current_floor = floor_index
	var floor_data: Dictionary = floors[floor_index]

	## Find START room and set as current
	for room: Dictionary in floor_data["rooms"]:
		if room["type"] == "start":
			current_room_id = room["id"]
			room["visited"] = true
			room["revealed"] = true
			room["visible"] = true
			break

	## On final floor only, reveal boss rooms (they're the rift objective)
	var is_final_floor: bool = floor_index == floors.size() - 1
	if is_final_floor:
		for room: Dictionary in floor_data["rooms"]:
			if room["type"] == "boss":
				room["revealed"] = true
				room["visible"] = true

	## Show adjacent rooms as foggy (visible but type unknown)
	_show_adjacent_rooms()

	floor_changed.emit(floor_index)


func _handle_hazard() -> void:
	if crawler.hazard_shield_active:
		crawler.hazard_shield_active = false
		return
	if crawler.is_reinforced:
		crawler.is_reinforced = false
		return
	var dmg: int = rift_template.hazard_damage
	crawler.take_hull_damage(dmg)
	crawler_damaged.emit(dmg, crawler.hull_hp)
	if crawler.hull_hp <= 0:
		forced_extraction.emit()


func _clear_hazard_room() -> void:
	## Find adjacent hazard rooms and change type to "empty"
	var adjacent: Array[Dictionary] = get_adjacent_rooms()
	for room: Dictionary in adjacent:
		if room["type"] == "hazard" and not room["visited"]:
			room["type"] = "empty"
			return


func _show_adjacent_rooms() -> void:
	## Make adjacent rooms visible (foggy) without revealing their type
	var adjacent: Array[Dictionary] = get_adjacent_rooms()
	for room: Dictionary in adjacent:
		if not room.get("visible", false):
			room["visible"] = true
			room_shown.emit(room["id"])


func _reveal_adjacent_rooms() -> void:
	## Fully reveal adjacent rooms (scan ability) — shows type
	var adjacent: Array[Dictionary] = get_adjacent_rooms()
	for room: Dictionary in adjacent:
		room["visible"] = true
		if not room["revealed"]:
			room["revealed"] = true
			room_revealed.emit(room["id"], room["type"])


func _is_connected(from_id: String, to_id: String) -> bool:
	if current_floor >= floors.size():
		return false
	var floor_data: Dictionary = floors[current_floor]
	for conn: Array in floor_data["connections"]:
		if (conn[0] == from_id and conn[1] == to_id) or (conn[1] == from_id and conn[0] == to_id):
			return true
	return false


func _get_room(floor_idx: int, room_id: String) -> Dictionary:
	if floor_idx >= floors.size():
		return {}
	for room: Dictionary in floors[floor_idx]["rooms"]:
		if room["id"] == room_id:
			return room
	return {}
