class_name PauseMenu
extends ColorRect

## Reusable pause/menu overlay. Toggled by Escape key or external call.
## Shows Resume, Save Slots, and Save & Quit.
## Always stays in the tree (never set visible=false) so Escape works.

signal save_and_quit_pressed
signal save_slot_loaded

var _open: bool = false
var _center: CenterContainer = null
var _resume_btn: Button = null
var _save_quit_btn: Button = null
var _save_slots_btn: Button = null
var _save_slots_popup: SaveSlotsPopup = null

## When true, _unhandled_input is ignored (for headless tests)
var instant_mode: bool = false

## Read-only — whether the menu is currently showing
var is_open: bool:
	get:
		return _open


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0, 0, 0, 0)
	_build_ui()


func open() -> void:
	if _open:
		return
	_open = true
	color = Color(0, 0, 0, 0.7)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center.visible = true


func close() -> void:
	if not _open:
		return
	_open = false
	color = Color(0, 0, 0, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.visible = false


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func setup_save_slots(
	game_state: GameState,
	roster_state: RosterState,
	codex_state: CodexState,
	crawler_state: CrawlerState,
	data_loader: Node,
) -> void:
	if _save_slots_popup != null:
		_save_slots_popup.setup(game_state, roster_state, codex_state, crawler_state, data_loader)


func _input(event: InputEvent) -> void:
	if instant_mode:
		return
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.visible = false
	add_child(_center)

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
	_center.add_child(panel)

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
	_resume_btn.pressed.connect(close)
	vbox.add_child(_resume_btn)

	_save_slots_btn = Button.new()
	_save_slots_btn.text = "Save Slots"
	_save_slots_btn.custom_minimum_size = Vector2(200, 36)
	_save_slots_btn.pressed.connect(_on_save_slots)
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
		close()
		save_slot_loaded.emit()
	)
	add_child(_save_slots_popup)


func _on_save_quit() -> void:
	close()
	save_and_quit_pressed.emit()


func _on_save_slots() -> void:
	_save_slots_popup.show_popup()
