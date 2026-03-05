class_name PauseMenu
extends ColorRect

## Reusable pause/menu overlay. Toggled by Escape key or external call.
## Shows Resume, Save & Quit, and optionally Save Slots.

signal save_and_quit_pressed
signal save_slot_loaded

var _resume_btn: Button = null
var _save_quit_btn: Button = null
var _save_slots_btn: Button = null
var _save_slots_popup: SaveSlotsPopup = null

## When true, _unhandled_input is ignored (for headless tests)
var instant_mode: bool = false

## Set to false to hide Save Slots button (e.g. during dungeon)
var show_save_slots: bool = true:
	set(v):
		show_save_slots = v
		if _save_slots_btn != null:
			_save_slots_btn.visible = v


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.7)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func toggle() -> void:
	visible = not visible


func setup_save_slots(
	game_state: GameState,
	roster_state: RosterState,
	codex_state: CodexState,
	crawler_state: CrawlerState,
	data_loader: Node,
) -> void:
	if _save_slots_popup != null:
		_save_slots_popup.setup(game_state, roster_state, codex_state, crawler_state, data_loader)


func _unhandled_input(event: InputEvent) -> void:
	if instant_mode:
		return
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 180)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#1A1A2E")
	style.set_corner_radius_all(8)
	style.border_color = Color("#FFD700")
	style.set_border_width_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_resume_btn = Button.new()
	_resume_btn.text = "Resume"
	_resume_btn.custom_minimum_size = Vector2(200, 36)
	_resume_btn.pressed.connect(func() -> void: visible = false)
	vbox.add_child(_resume_btn)

	_save_slots_btn = Button.new()
	_save_slots_btn.text = "Save Slots"
	_save_slots_btn.custom_minimum_size = Vector2(200, 36)
	_save_slots_btn.pressed.connect(_on_save_slots)
	_save_slots_btn.visible = show_save_slots
	vbox.add_child(_save_slots_btn)

	_save_quit_btn = Button.new()
	_save_quit_btn.text = "Save & Quit"
	_save_quit_btn.custom_minimum_size = Vector2(200, 36)
	_save_quit_btn.pressed.connect(_on_save_quit)
	vbox.add_child(_save_quit_btn)

	## Save slots popup (embedded, hidden)
	_save_slots_popup = SaveSlotsPopup.new()
	_save_slots_popup.name = "SaveSlotsPopup"
	_save_slots_popup.slot_loaded.connect(func() -> void:
		visible = false
		save_slot_loaded.emit()
	)
	add_child(_save_slots_popup)


func _on_save_quit() -> void:
	visible = false
	save_and_quit_pressed.emit()


func _on_save_slots() -> void:
	_save_slots_popup.show_popup()
