class_name SaveSlotsPopup
extends ColorRect

## Modal popup for managing 3 manual save slots.
## Same pattern as NpcPanel: full-rect semi-transparent bg + centered panel.

signal slot_loaded

const SLOT_KEYS: Array[String] = ["slot1", "slot2", "slot3"]
const SLOT_LABELS: Array[String] = ["Slot 1", "Slot 2", "Slot 3"]

var game_state: GameState = null
var roster_state: RosterState = null
var codex_state: CodexState = null
var crawler_state: CrawlerState = null
var data_loader: Node = null

var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _close_btn: Button = null
var _rows: Array[Dictionary] = []
var _autosave_row: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.7)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func setup(
	p_game_state: GameState,
	p_roster_state: RosterState,
	p_codex_state: CodexState,
	p_crawler_state: CrawlerState,
	p_data_loader: Node,
) -> void:
	game_state = p_game_state
	roster_state = p_roster_state
	codex_state = p_codex_state
	crawler_state = p_crawler_state
	data_loader = p_data_loader


var load_only: bool = false


func show_popup() -> void:
	_refresh_all_rows()
	visible = true


func hide_popup() -> void:
	visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 320)
	_panel.offset_left = -260.0
	_panel.offset_right = 260.0
	_panel.offset_top = -160.0
	_panel.offset_bottom = 160.0
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1A2E")
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.border_color = Color("#888888")
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(_vbox)

	## Title
	var title: Label = Label.new()
	title.text = "SAVE SLOTS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)

	## Autosave row
	_autosave_row = _build_autosave_row()

	## Separator
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_vbox.add_child(sep)

	## Manual slot rows
	for i: int in range(SLOT_KEYS.size()):
		var row: Dictionary = _build_slot_row(SLOT_KEYS[i], SLOT_LABELS[i])
		_rows.append(row)

	## Close button
	_close_btn = Button.new()
	_close_btn.name = "SaveSlotsCloseButton"
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(100, 32)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(hide_popup)
	_vbox.add_child(_close_btn)


func _build_autosave_row() -> Dictionary:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(hbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = "Autosave"
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color("#88CCFF"))
	name_lbl.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(name_lbl)

	var info_lbl: Label = Label.new()
	info_lbl.add_theme_font_size_override("font_size", 13)
	info_lbl.add_theme_color_override("font_color", Color("#AAAAAA"))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(info_lbl)

	var load_btn: Button = Button.new()
	load_btn.name = "LoadAutosaveButton"
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(64, 30)
	load_btn.pressed.connect(_on_load.bind(SaveManager.AUTOSAVE_SLOT))
	hbox.add_child(load_btn)

	var del_btn: Button = Button.new()
	del_btn.name = "DeleteAutosaveButton"
	del_btn.text = "Delete"
	del_btn.custom_minimum_size = Vector2(64, 30)
	del_btn.add_theme_color_override("font_color", Color("#FF6666"))
	del_btn.pressed.connect(_on_delete.bind(SaveManager.AUTOSAVE_SLOT))
	hbox.add_child(del_btn)

	return {
		"slot_key": SaveManager.AUTOSAVE_SLOT,
		"info_label": info_lbl,
		"load_btn": load_btn,
		"delete_btn": del_btn,
	}


func _build_slot_row(slot_key: String, slot_label: String) -> Dictionary:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(hbox)

	## Slot name
	var name_lbl: Label = Label.new()
	name_lbl.text = slot_label
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color("#CCCCCC"))
	name_lbl.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(name_lbl)

	## Info label (phase, glyphs, timestamp)
	var info_lbl: Label = Label.new()
	info_lbl.add_theme_font_size_override("font_size", 13)
	info_lbl.add_theme_color_override("font_color", Color("#AAAAAA"))
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(info_lbl)

	## Save button
	var save_btn: Button = Button.new()
	save_btn.name = "SaveButton_%s" % slot_key
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(64, 30)
	save_btn.pressed.connect(_on_save.bind(slot_key))
	hbox.add_child(save_btn)

	## Load button
	var load_btn: Button = Button.new()
	load_btn.name = "LoadButton_%s" % slot_key
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(64, 30)
	load_btn.pressed.connect(_on_load.bind(slot_key))
	hbox.add_child(load_btn)

	## Delete button
	var del_btn: Button = Button.new()
	del_btn.name = "DeleteButton_%s" % slot_key
	del_btn.text = "Delete"
	del_btn.custom_minimum_size = Vector2(64, 30)
	del_btn.add_theme_color_override("font_color", Color("#FF6666"))
	del_btn.pressed.connect(_on_delete.bind(slot_key))
	hbox.add_child(del_btn)

	return {
		"slot_key": slot_key,
		"info_label": info_lbl,
		"load_btn": load_btn,
		"delete_btn": del_btn,
		"save_btn": save_btn,
	}


func _refresh_all_rows() -> void:
	_refresh_row(_autosave_row)
	for row: Dictionary in _rows:
		_refresh_row(row)


func _refresh_row(row: Dictionary) -> void:
	var slot_key: String = row["slot_key"]
	var info_lbl: Label = row["info_label"] as Label
	var load_btn: Button = row["load_btn"] as Button
	var del_btn: Button = row["delete_btn"] as Button
	var save_btn: Button = row.get("save_btn") as Button

	## Hide save buttons in load-only mode
	if save_btn != null:
		save_btn.visible = not load_only

	var info: Dictionary = SaveManager.get_slot_info(slot_key)
	if info.is_empty():
		info_lbl.text = "— Empty —"
		info_lbl.add_theme_color_override("font_color", Color("#666666"))
		load_btn.disabled = true
		del_btn.disabled = true
	else:
		var phase: int = info.get("phase", 1)
		var glyphs: int = info.get("glyph_count", 0)
		var ts: String = info.get("timestamp", "")
		## Show just date portion if available
		if ts.length() > 10:
			ts = ts.substr(0, 10)
		info_lbl.text = "Phase %d — %d Glyphs — %s" % [phase, glyphs, ts]
		info_lbl.add_theme_color_override("font_color", Color("#AAAAAA"))
		load_btn.disabled = false
		del_btn.disabled = false


func _on_save(slot_key: String) -> void:
	if game_state == null:
		return
	SaveManager.save_to_slot(slot_key, game_state, roster_state, codex_state, crawler_state)
	_refresh_all_rows()


func _on_load(slot_key: String) -> void:
	if game_state == null or data_loader == null:
		return
	var ok: bool = SaveManager.load_from_slot(
		slot_key, game_state, roster_state, codex_state, crawler_state, data_loader
	)
	if ok:
		hide_popup()
		slot_loaded.emit()


func _on_delete(slot_key: String) -> void:
	SaveManager.delete_slot(slot_key)
	_refresh_all_rows()


func _gui_input(event: InputEvent) -> void:
	## Click outside panel to close
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var panel_rect: Rect2 = Rect2(_panel.global_position, _panel.size)
			if not panel_rect.has_point(mb.global_position):
				hide_popup()
