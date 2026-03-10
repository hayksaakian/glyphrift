class_name SettingsPopup
extends ColorRect

## Settings overlay. Shows battle speed toggle and other options.

signal closed

var _panel: PanelContainer = null
var _speed_btn: Button = null
var _close_btn: Button = null

const SPEED_OPTIONS: Array[String] = ["normal", "fast", "instant"]
const SPEED_LABELS: Dictionary = {
	"normal": "Normal",
	"fast": "Fast (2x)",
	"instant": "Instant",
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.7)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_update_speed_label()


func show_popup() -> void:
	_update_speed_label()
	visible = true


func hide_popup() -> void:
	visible = false


func _build_ui() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 220)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#1A1A2E")
	style.set_corner_radius_all(8)
	style.border_color = Color("#FFD700")
	style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	## Title
	var title: Label = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	## Battle Speed row
	var speed_row: HBoxContainer = HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 10)
	vbox.add_child(speed_row)

	var speed_label: Label = Label.new()
	speed_label.text = "Battle Speed:"
	speed_label.add_theme_font_size_override("font_size", 14)
	speed_label.add_theme_color_override("font_color", Color("#DDDDDD"))
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(speed_label)

	_speed_btn = Button.new()
	_speed_btn.name = "SpeedButton"
	_speed_btn.custom_minimum_size = Vector2(120, 32)
	_speed_btn.pressed.connect(_cycle_speed)
	speed_row.add_child(_speed_btn)

	## Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	## Close button
	_close_btn = Button.new()
	_close_btn.name = "SettingsCloseButton"
	_close_btn.text = "Done"
	_close_btn.custom_minimum_size = Vector2(120, 36)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(func() -> void:
		hide_popup()
		closed.emit()
	)
	vbox.add_child(_close_btn)


func _cycle_speed() -> void:
	var current_idx: int = SPEED_OPTIONS.find(GameSettings.battle_speed)
	var next_idx: int = (current_idx + 1) % SPEED_OPTIONS.size()
	GameSettings.battle_speed = SPEED_OPTIONS[next_idx]
	GameSettings.save_settings()
	_update_speed_label()


func _update_speed_label() -> void:
	if _speed_btn != null:
		_speed_btn.text = SPEED_LABELS.get(GameSettings.battle_speed, "Normal")


func _gui_input(event: InputEvent) -> void:
	## Click outside panel to close
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var panel_rect: Rect2 = Rect2(_panel.global_position, _panel.size)
			if not panel_rect.has_point(mb.global_position):
				hide_popup()
				closed.emit()
