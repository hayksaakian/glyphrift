class_name FloorMap
extends Control

## Renders the current floor as a node graph of RoomNode tiles connected by lines.
## Spawns RoomNode instances at (room.x * cell_size, room.y * cell_size).
## Listens to DungeonState signals to update room visuals.

signal room_clicked(room_id: String)
signal room_hovered(room_id: String)
signal room_hover_exited()

const CELL_SIZE: int = 100
const LINE_COLOR_REVEALED: Color = Color("#888888")
const LINE_COLOR_UNREVEALED: Color = Color("#333333")
const LINE_WIDTH: float = 2.0
const PREVIEW_LINE_COLOR: Color = Color(0, 0.87, 0.87, 0.5)
const PREVIEW_LINE_WIDTH: float = 3.0

var dungeon_state: DungeonState = null
var instant_mode: bool = false

var _room_nodes: Dictionary = {}  ## room_id → RoomNode
var _connection_lines: Array[Line2D] = []
var _map_container: Control = null
var _lines_container: Control = null
var _token_container: Control = null
var _crawler_token: CrawlerToken = null
var _preview_line: Line2D = null
var _preview_room_ids: Array[String] = []
var _offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	_lines_container = Control.new()
	_lines_container.name = "Lines"
	_lines_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_lines_container)

	_map_container = Control.new()
	_map_container.name = "Rooms"
	_map_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_map_container)

	_token_container = Control.new()
	_token_container.name = "Token"
	_token_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_token_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_token_container)

	_crawler_token = CrawlerToken.new()
	_crawler_token.instant_mode = instant_mode
	_token_container.add_child(_crawler_token)

	_preview_line = Line2D.new()
	_preview_line.name = "PreviewLine"
	_preview_line.default_color = PREVIEW_LINE_COLOR
	_preview_line.width = PREVIEW_LINE_WIDTH
	_preview_line.visible = false
	_lines_container.add_child(_preview_line)


func build_floor(floor_data: Dictionary, p_dungeon_state: DungeonState) -> void:
	dungeon_state = p_dungeon_state
	_clear()
	_calculate_offset(floor_data)
	_spawn_rooms(floor_data)
	_draw_connections(floor_data)
	_update_adjacency()

	## Update token instant_mode and place on start room
	if _crawler_token != null:
		_crawler_token.instant_mode = instant_mode
		var start_id: String = dungeon_state.current_room_id if dungeon_state != null else ""
		if start_id != "" and _room_nodes.has(start_id):
			_crawler_token.teleport_to(get_room_center(start_id))


func update_room(room_id: String) -> void:
	if not _room_nodes.has(room_id):
		return
	var node: RoomNode = _room_nodes[room_id]
	var old_state: RoomNode.RoomState = node.state
	## Re-read room data from dungeon state
	var floor_data: Dictionary = dungeon_state.floors[dungeon_state.current_floor]
	for room: Dictionary in floor_data["rooms"]:
		if room["id"] == room_id:
			node.setup(room)
			break
	_update_adjacency()
	## Animate reveal if newly visible
	if not instant_mode and old_state == RoomNode.RoomState.UNREVEALED and node.state != RoomNode.RoomState.UNREVEALED:
		node.reveal_animate()


func set_current_room(room_id: String) -> void:
	for id: String in _room_nodes:
		var node: RoomNode = _room_nodes[id]
		if id == room_id:
			node.set_state(RoomNode.RoomState.CURRENT)
		elif node.state == RoomNode.RoomState.CURRENT:
			## Revert previous current room to visited
			node.set_state(RoomNode.RoomState.VISITED)
	_update_adjacency()

	## Move token to current room
	if _crawler_token != null and _room_nodes.has(room_id):
		_crawler_token.teleport_to(get_room_center(room_id))


func refresh_all() -> void:
	if dungeon_state == null:
		return
	var floor_data: Dictionary = dungeon_state.floors[dungeon_state.current_floor]
	for room: Dictionary in floor_data["rooms"]:
		var rid: String = room["id"]
		if _room_nodes.has(rid):
			var node: RoomNode = _room_nodes[rid]
			var old_state: RoomNode.RoomState = node.state
			node.setup(room)
			if not instant_mode and old_state == RoomNode.RoomState.UNREVEALED and node.state != RoomNode.RoomState.UNREVEALED:
				node.reveal_animate()
	## Mark current room
	if dungeon_state.current_room_id != "" and _room_nodes.has(dungeon_state.current_room_id):
		_room_nodes[dungeon_state.current_room_id].set_state(RoomNode.RoomState.CURRENT)
	_update_adjacency()
	_update_line_colors()


func get_room_node(room_id: String) -> RoomNode:
	return _room_nodes.get(room_id, null)


func get_room_count() -> int:
	return _room_nodes.size()


func get_line_count() -> int:
	return _connection_lines.size()


func _clear() -> void:
	for id: String in _room_nodes:
		var node: RoomNode = _room_nodes[id]
		_map_container.remove_child(node)
		node.queue_free()
	_room_nodes.clear()

	for line: Line2D in _connection_lines:
		_lines_container.remove_child(line)
		line.queue_free()
	_connection_lines.clear()


func _calculate_offset(floor_data: Dictionary) -> void:
	## Center map in the available viewport area.
	## For tall maps (STS-style trees), expand minimum size so ScrollContainer can scroll.
	var min_x: int = 999
	var max_x: int = -999
	var min_y: int = 999
	var max_y: int = -999
	for room: Dictionary in floor_data["rooms"]:
		var rx: int = int(room["x"])
		var ry: int = int(room["y"])
		min_x = mini(min_x, rx)
		max_x = maxi(max_x, rx)
		min_y = mini(min_y, ry)
		max_y = maxi(max_y, ry)

	var map_width: float = float((max_x - min_x) * CELL_SIZE + RoomNode.ROOM_SIZE.x)
	var map_height: float = float((max_y - min_y) * CELL_SIZE + RoomNode.ROOM_SIZE.y)

	## Get viewport area — use ScrollContainer parent size if present
	var available: Vector2 = Vector2.ZERO
	var p: Control = get_parent() as Control
	if p != null and p is ScrollContainer and p.size.x > 0.0:
		available = p.size
	elif size.x > 0.0:
		available = size
	if available.x <= 0.0:
		available = Vector2(800, 500)

	## Horizontal: always center
	var offset_x: float = (available.x - map_width) / 2.0 - float(min_x * CELL_SIZE)

	## Vertical: center if fits, otherwise top-align with padding for scrolling
	var top_pad: float = 30.0
	var bottom_pad: float = 40.0
	var content_height: float = map_height + top_pad + bottom_pad
	var offset_y: float
	if content_height <= available.y:
		## Map fits in viewport — center vertically, no scrolling needed
		offset_y = (available.y - map_height) / 2.0 - float(min_y * CELL_SIZE)
		custom_minimum_size.y = 0.0
	else:
		## Map taller than viewport — expand for scroll and top-align
		offset_y = top_pad - float(min_y * CELL_SIZE)
		custom_minimum_size.y = content_height

	_offset = Vector2(offset_x, offset_y)


func _spawn_rooms(floor_data: Dictionary) -> void:
	var floor_num: int = int(floor_data.get("floor_number", 0)) + 1
	var total_floors: int = dungeon_state.floors.size() if dungeon_state != null else 1

	for room: Dictionary in floor_data["rooms"]:
		var node: RoomNode = RoomNode.new()
		_map_container.add_child(node)

		## Set contextual labels for start/exit rooms
		var room_type: String = room.get("type", "")
		if room_type == "start":
			node.label_override = "Floor %d" % floor_num
		elif room_type == "exit":
			if floor_num < total_floors:
				node.label_override = "To Floor %d" % (floor_num + 1)
			else:
				node.label_override = "Stairs"

		node.setup(room)
		node.position = Vector2(
			float(int(room["x"]) * CELL_SIZE) + _offset.x,
			float(int(room["y"]) * CELL_SIZE) + _offset.y,
		)
		node.room_clicked.connect(_on_room_clicked)
		var rid: String = room["id"]
		node.mouse_entered.connect(_on_room_mouse_entered.bind(rid))
		node.mouse_exited.connect(_on_room_mouse_exited)
		_room_nodes[rid] = node


func _draw_connections(floor_data: Dictionary) -> void:
	for conn: Array in floor_data["connections"]:
		var from_id: String = conn[0]
		var to_id: String = conn[1]
		if not _room_nodes.has(from_id) or not _room_nodes.has(to_id):
			continue
		var from_node: RoomNode = _room_nodes[from_id]
		var to_node: RoomNode = _room_nodes[to_id]

		var line: Line2D = Line2D.new()
		line.set_meta("from_id", from_id)
		line.set_meta("to_id", to_id)
		var half: Vector2 = Vector2(RoomNode.ROOM_SIZE.x / 2.0, 28.0)  ## Center of icon box
		line.add_point(from_node.position + half)
		line.add_point(to_node.position + half)
		line.width = LINE_WIDTH
		line.default_color = LINE_COLOR_UNREVEALED
		_lines_container.add_child(line)
		_connection_lines.append(line)

	_update_line_colors()


func _update_line_colors() -> void:
	for line: Line2D in _connection_lines:
		var from_id: String = line.get_meta("from_id")
		var to_id: String = line.get_meta("to_id")
		var from_visible: bool = _room_nodes.has(from_id) and _room_nodes[from_id].state != RoomNode.RoomState.UNREVEALED
		var to_visible: bool = _room_nodes.has(to_id) and _room_nodes[to_id].state != RoomNode.RoomState.UNREVEALED
		if from_visible and to_visible:
			line.visible = true
			var from_revealed: bool = _room_nodes[from_id].state in [RoomNode.RoomState.REVEALED, RoomNode.RoomState.VISITED, RoomNode.RoomState.CURRENT]
			var to_revealed: bool = _room_nodes[to_id].state in [RoomNode.RoomState.REVEALED, RoomNode.RoomState.VISITED, RoomNode.RoomState.CURRENT]
			line.default_color = LINE_COLOR_REVEALED if (from_revealed and to_revealed) else LINE_COLOR_UNREVEALED
		else:
			line.visible = false


func _update_adjacency() -> void:
	if dungeon_state == null:
		return
	var adjacent_ids: Dictionary = {}
	for room: Dictionary in dungeon_state.get_adjacent_rooms():
		adjacent_ids[room["id"]] = true

	for id: String in _room_nodes:
		_room_nodes[id].set_adjacent(adjacent_ids.has(id))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var click_pos: Vector2 = mb.position
			for id: String in _room_nodes:
				var rn: RoomNode = _room_nodes[id]
				if rn.contains_point(click_pos):
					room_clicked.emit(id)
					get_viewport().set_input_as_handled()
					return


func _on_room_clicked(room_id: String) -> void:
	room_clicked.emit(room_id)


func _on_room_mouse_entered(room_id: String) -> void:
	room_hovered.emit(room_id)


func _on_room_mouse_exited() -> void:
	room_hover_exited.emit()


func get_room_center(room_id: String) -> Vector2:
	if not _room_nodes.has(room_id):
		return Vector2.ZERO
	var node: RoomNode = _room_nodes[room_id]
	return node.position + Vector2(32, 28)


func show_path_preview(path: Array[String]) -> void:
	clear_path_preview()
	if path.is_empty():
		return

	_preview_room_ids = path.duplicate()

	## Highlight rooms along the path
	for rid: String in path:
		if _room_nodes.has(rid):
			_room_nodes[rid].set_preview_highlight(true)

	## Draw preview line from current room through path
	_preview_line.clear_points()
	var current_id: String = dungeon_state.current_room_id if dungeon_state != null else ""
	if current_id != "" and _room_nodes.has(current_id):
		_preview_line.add_point(get_room_center(current_id))
	for rid: String in path:
		if _room_nodes.has(rid):
			_preview_line.add_point(get_room_center(rid))
	_preview_line.visible = _preview_line.get_point_count() >= 2


func clear_path_preview() -> void:
	for rid: String in _preview_room_ids:
		if _room_nodes.has(rid):
			_room_nodes[rid].set_preview_highlight(false)
	_preview_room_ids.clear()
	if _preview_line != null:
		_preview_line.clear_points()
		_preview_line.visible = false


func animate_token_to(room_id: String, on_complete: Callable = Callable()) -> void:
	if _crawler_token == null or not _room_nodes.has(room_id):
		if on_complete.is_valid():
			on_complete.call()
		return
	_crawler_token.move_to(get_room_center(room_id), on_complete)
