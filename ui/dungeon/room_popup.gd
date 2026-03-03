class_name RoomPopup
extends PanelContainer

## Modal popup shown when entering a room.
## Content varies by room type; action button triggers interaction.

signal action_pressed(room_type: String, room_data: Dictionary)

const POPUP_SIZE: Vector2 = Vector2(320, 200)

const ROOM_TITLES: Dictionary = {
	"enemy": "Wild Glyphs Ahead!",
	"cache": "Supply Cache Found!",
	"hazard": "Hazard Zone!",
	"puzzle": "Puzzle Room",
	"boss": "RIFT GUARDIAN",
	"empty": "Nothing here.",
	"exit": "Stairs Down",
	"hidden": "Hidden Cache Found!",
	"start": "Starting Point",
}

const ACTION_LABELS: Dictionary = {
	"enemy": "Fight",
	"cache": "Open",
	"hazard": "Continue",
	"puzzle": "Attempt",
	"boss": "Challenge",
	"empty": "Continue",
	"exit": "Descend",
	"hidden": "Open",
	"start": "Continue",
}

var room_data: Dictionary = {}

var _title_label: Label = null
var _description_label: Label = null
var _action_button: Button = null
var _vbox: VBoxContainer = null


func _ready() -> void:
	custom_minimum_size = POPUP_SIZE
	visible = false
	_build_ui()


func show_room(p_room_data: Dictionary, extra_info: String = "") -> void:
	room_data = p_room_data
	var room_type: String = room_data.get("type", "empty")

	var title: String = ROOM_TITLES.get(room_type, "Unknown Room")
	if room_type == "boss" and extra_info != "":
		title = "RIFT GUARDIAN: %s" % extra_info

	_title_label.text = title

	var desc: String = _get_description(room_type, extra_info)
	_description_label.text = desc

	_action_button.text = ACTION_LABELS.get(room_type, "Continue")
	visible = true


func hide_popup() -> void:
	visible = false


func get_title_text() -> String:
	if _title_label != null:
		return _title_label.text
	return ""


func get_description_text() -> String:
	if _description_label != null:
		return _description_label.text
	return ""


func get_action_text() -> String:
	if _action_button != null:
		return _action_button.text
	return ""


func _build_ui() -> void:
	## Popup styling
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", panel_style)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	add_child(_vbox)

	## Title
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)

	## Description
	_description_label = Label.new()
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_description_label)

	## Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(spacer)

	## Action button
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(120, 36)
	_action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action_button.pressed.connect(_on_action_pressed)
	_vbox.add_child(_action_button)


func _get_description(room_type: String, extra_info: String) -> String:
	match room_type:
		"enemy":
			return "Wild glyphs block your path!"
		"cache":
			return "A supply cache sits before you."
		"hazard":
			if extra_info != "":
				return "Crawler takes %s damage." % extra_info
			return "The crawler takes damage from environmental hazards."
		"puzzle":
			return "A mysterious mechanism awaits."
		"boss":
			return "A powerful guardian defends this floor."
		"empty":
			return "An empty chamber. Nothing of interest."
		"exit":
			return "Descend to the next floor?"
		"hidden":
			return "A hidden cache with rare supplies!"
		"start":
			return "Your starting position on this floor."
		_:
			return ""


func _on_action_pressed() -> void:
	var room_type: String = room_data.get("type", "empty")
	action_pressed.emit(room_type, room_data)
