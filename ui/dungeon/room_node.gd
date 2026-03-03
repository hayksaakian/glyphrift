class_name RoomNode
extends Control

## Clickable room tile on the floor map (64x80: icon box + type label).
## States: unrevealed, revealed, visited, current.

signal room_clicked(room_id: String)

enum RoomState { UNREVEALED, REVEALED, VISITED, CURRENT }

const ROOM_SIZE: Vector2 = Vector2(64, 80)

const TYPE_ICONS: Dictionary = {
	"start": "S",
	"exit": "\u25bc",
	"enemy": "!",
	"hazard": "\u26a0",
	"puzzle": "?",
	"cache": "\u25c6",
	"hidden": "H",
	"boss": "\u2605",
	"empty": "\u25cb",
}

const TYPE_COLORS: Dictionary = {
	"start": Color("#44AA44"),
	"exit": Color("#4488FF"),
	"enemy": Color("#FF4444"),
	"hazard": Color("#FF8800"),
	"puzzle": Color("#AA44FF"),
	"cache": Color("#FFD700"),
	"hidden": Color("#00DDDD"),
	"boss": Color("#FF2222"),
	"empty": Color("#666666"),
}

const TYPE_NAMES: Dictionary = {
	"start": "Start",
	"exit": "Stairs",
	"enemy": "Enemy",
	"hazard": "Hazard",
	"puzzle": "Puzzle",
	"cache": "Cache",
	"hidden": "Hidden",
	"boss": "Boss",
	"empty": "Empty",
}

const UNREVEALED_ICON: String = "?"
const UNREVEALED_COLOR: Color = Color("#444444")
const CURRENT_BORDER_COLOR: Color = Color("#FFFFFF")
const CURRENT_BORDER_WIDTH: int = 3
const REVEALED_OPACITY: float = 0.5

var room_data: Dictionary = {}
var state: RoomState = RoomState.UNREVEALED
var is_adjacent: bool = false
var label_override: String = ""  ## If set, replaces TYPE_NAMES text

var _icon_label: Label = null
var _type_label: Label = null
var _background: ColorRect = null
var _border_panel: Panel = null


func _ready() -> void:
	custom_minimum_size = ROOM_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	refresh()


func setup(p_room_data: Dictionary) -> void:
	room_data = p_room_data
	_update_state_from_data()
	if is_inside_tree():
		refresh()


func set_state(p_state: RoomState) -> void:
	state = p_state
	if is_inside_tree():
		refresh()


func set_adjacent(p_adjacent: bool) -> void:
	is_adjacent = p_adjacent
	if is_inside_tree():
		refresh()


func get_room_id() -> String:
	return room_data.get("id", "")


func refresh() -> void:
	if _icon_label == null:
		return

	var is_cleared: bool = room_data.get("cleared", false)
	var room_type: String = room_data.get("type", "empty")
	if is_cleared:
		room_type = room_data.get("original_type", room_type)
	var display_name: String = label_override if label_override != "" else TYPE_NAMES.get(room_type, "")

	match state:
		RoomState.UNREVEALED:
			_icon_label.text = UNREVEALED_ICON
			_icon_label.add_theme_color_override("font_color", UNREVEALED_COLOR)
			_type_label.text = "???"
			_type_label.add_theme_color_override("font_color", UNREVEALED_COLOR)
			_background.color = Color("#1A1A1A")
			_icon_label.modulate.a = 1.0
			_border_panel.visible = false
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		RoomState.REVEALED:
			_icon_label.text = TYPE_ICONS.get(room_type, "?")
			_icon_label.add_theme_color_override("font_color", TYPE_COLORS.get(room_type, UNREVEALED_COLOR))
			var scan_info: String = room_data.get("scan_info", "")
			if scan_info != "":
				_type_label.text = scan_info
			else:
				_type_label.text = display_name
			_type_label.add_theme_color_override("font_color", TYPE_COLORS.get(room_type, UNREVEALED_COLOR))
			_background.color = Color("#222222")
			_icon_label.modulate.a = REVEALED_OPACITY
			_type_label.modulate.a = REVEALED_OPACITY
			_border_panel.visible = false
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_adjacent else Control.CURSOR_ARROW
		RoomState.VISITED:
			if is_cleared:
				_icon_label.text = "\u2713"
				_icon_label.add_theme_color_override("font_color", Color("#4CAF50"))
				_type_label.text = "Cleared"
				_type_label.add_theme_color_override("font_color", Color("#4CAF50"))
			else:
				_icon_label.text = TYPE_ICONS.get(room_type, "?")
				_icon_label.add_theme_color_override("font_color", TYPE_COLORS.get(room_type, UNREVEALED_COLOR))
				_type_label.text = display_name
				_type_label.add_theme_color_override("font_color", TYPE_COLORS.get(room_type, UNREVEALED_COLOR))
			_background.color = Color("#2A2A2A")
			_icon_label.modulate.a = 1.0
			_type_label.modulate.a = 1.0
			_border_panel.visible = false
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		RoomState.CURRENT:
			if is_cleared:
				_icon_label.text = "\u2713"
				_icon_label.add_theme_color_override("font_color", Color("#4CAF50"))
				_type_label.text = "Cleared"
				_type_label.add_theme_color_override("font_color", Color("#4CAF50"))
			else:
				_icon_label.text = TYPE_ICONS.get(room_type, "?")
				_icon_label.add_theme_color_override("font_color", TYPE_COLORS.get(room_type, UNREVEALED_COLOR))
				_type_label.text = display_name
				_type_label.add_theme_color_override("font_color", TYPE_COLORS.get(room_type, UNREVEALED_COLOR))
			_background.color = Color("#333333")
			_icon_label.modulate.a = 1.0
			_type_label.modulate.a = 1.0
			_border_panel.visible = true
			mouse_default_cursor_shape = Control.CURSOR_ARROW


func _build_ui() -> void:
	## Background color rect — only covers the icon area (top 56px)
	_background = ColorRect.new()
	_background.position = Vector2(0, 0)
	_background.size = Vector2(64, 56)
	_background.color = Color("#1A1A1A")
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	## Icon label (centered in the background box)
	_icon_label = Label.new()
	_icon_label.position = Vector2(0, 0)
	_icon_label.size = Vector2(64, 56)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 24)
	_icon_label.text = UNREVEALED_ICON
	_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_label)

	## Type name label (below the box, no background)
	_type_label = Label.new()
	_type_label.position = Vector2(0, 58)
	_type_label.size = Vector2(64, 20)
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_type_label.add_theme_font_size_override("font_size", 11)
	_type_label.text = "???"
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_type_label)

	## Current-room highlight border (covers icon box only)
	_border_panel = Panel.new()
	_border_panel.position = Vector2(0, 0)
	_border_panel.size = Vector2(64, 56)
	_border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style: StyleBoxFlat = StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = CURRENT_BORDER_COLOR
	border_style.set_border_width_all(CURRENT_BORDER_WIDTH)
	_border_panel.add_theme_stylebox_override("panel", border_style)
	_border_panel.visible = false
	add_child(_border_panel)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			room_clicked.emit(get_room_id())


func contains_point(global_point: Vector2) -> bool:
	return Rect2(global_position, size).has_point(global_point)


func _update_state_from_data() -> void:
	if room_data.is_empty():
		state = RoomState.UNREVEALED
		return

	var visited: bool = room_data.get("visited", false)
	var revealed: bool = room_data.get("revealed", false)

	if visited:
		state = RoomState.VISITED
	elif revealed:
		state = RoomState.REVEALED
	else:
		state = RoomState.UNREVEALED
