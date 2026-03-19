class_name RiftGenerator
extends RefCounted

## Static utility: takes a RiftTemplate and produces runtime floor data
## with room types resolved from content pools.
##
## Visibility (visited/revealed) is initialized to false for all rooms.
## DungeonState._enter_floor() handles revealing START, EXIT, and BOSS rooms.


const EVENT_TYPES: Array[String] = ["conduit", "echo", "quiz"]

static func generate(template: RiftTemplate) -> Array[Dictionary]:
	var floors: Array[Dictionary] = []
	var event_index: int = 0  ## Round-robin counter for event type assignment

	for floor_data: Dictionary in template.floors:
		var runtime_rooms: Array[Dictionary] = []

		for room_data: Dictionary in floor_data["rooms"]:
			var room: Dictionary = _build_runtime_room(room_data, template)
			## Assign event_type for event rooms
			if room["type"] == "event":
				if room_data.has("event_type"):
					room["event_type"] = room_data["event_type"]
				else:
					room["event_type"] = EVENT_TYPES[event_index % EVENT_TYPES.size()]
					event_index += 1
			runtime_rooms.append(room)

		## Copy connections as-is (already bidirectional pairs)
		var connections: Array = []
		for conn: Array in floor_data["connections"]:
			connections.append(conn)

		floors.append({
			"floor_number": floor_data["floor_number"],
			"rooms": runtime_rooms,
			"connections": connections,
		})

	return floors


static func _build_runtime_room(room_data: Dictionary, template: RiftTemplate) -> Dictionary:
	var room_type: String = ""

	## Resolve room type: explicit "type" field or "pool" reference
	if room_data.has("type"):
		room_type = room_data["type"]
	elif room_data.has("pool"):
		room_type = _resolve_pool(room_data["pool"], template.content_pools)
	else:
		room_type = "empty"

	var room: Dictionary = {
		"id": room_data["id"],
		"x": int(room_data["x"]),
		"y": int(room_data["y"]),
		"type": room_type,
		"visited": false,
		"revealed": false,
	}
	## Carry over optional room attributes from template
	if room_data.has("fixed_item"):
		room["fixed_item"] = room_data["fixed_item"]
	if room_data.has("enemy_tier"):
		room["enemy_tier"] = int(room_data["enemy_tier"])
	return room


static func _resolve_pool(pool_name: String, content_pools: Dictionary) -> String:
	if not content_pools.has(pool_name):
		return "empty"

	var pool: Dictionary = content_pools[pool_name]
	## Weighted random selection
	var total_weight: float = 0.0
	for w: float in pool.values():
		total_weight += w

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for room_type: String in pool:
		cumulative += pool[room_type]
		if roll <= cumulative:
			## "hidden_eligible" resolves to "hidden"
			if room_type == "hidden_eligible":
				return "hidden"
			return room_type

	## Fallback: return first key
	return pool.keys()[0]
