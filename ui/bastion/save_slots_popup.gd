class_name SaveSlotsPopup
extends ColorRect

## Modal popup for managing 5 manual save slots + autosave.
## Same pattern as NpcPanel: full-rect semi-transparent bg + centered panel.

signal slot_loaded

const SLOT_KEYS: Array[String] = ["slot1", "slot2", "slot3", "slot4", "slot5"]
const SLOT_LABELS: Array[String] = ["Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5"]

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
var _rename_edit: LineEdit = null
var _rename_slot: String = ""


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
	_hide_rename()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(540, 420)
	_panel.offset_left = -270.0
	_panel.offset_right = 270.0
	_panel.offset_top = -210.0
	_panel.offset_bottom = 210.0
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
	_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(_vbox)

	## Title
	var title: Label = Label.new()
	title.text = "SAVE SLOTS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)

	## Scrollable area for slot rows
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(scroll)

	var slot_list: VBoxContainer = VBoxContainer.new()
	slot_list.add_theme_constant_override("separation", 6)
	slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slot_list)

	## Autosave row
	_autosave_row = _build_slot_row_2line(SaveManager.AUTOSAVE_SLOT, "Autosave", Color("#88CCFF"), false, slot_list)

	## Separator
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	slot_list.add_child(sep)

	## Manual slot rows
	for i: int in range(SLOT_KEYS.size()):
		var row: Dictionary = _build_slot_row_2line(SLOT_KEYS[i], SLOT_LABELS[i], Color("#CCCCCC"), true, slot_list)
		_rows.append(row)

	## Close button
	_close_btn = Button.new()
	_close_btn.name = "SaveSlotsCloseButton"
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(100, 32)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(hide_popup)
	_vbox.add_child(_close_btn)


func _build_slot_row_2line(slot_key: String, slot_label: String, name_color: Color, is_manual: bool, parent: VBoxContainer) -> Dictionary:
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	parent.add_child(outer)

	## Line 1: name + buttons
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	outer.add_child(hbox)

	var name_lbl: Label = Label.new()
	name_lbl.text = slot_label
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", name_color)
	name_lbl.custom_minimum_size = Vector2(120, 0)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.clip_text = true
	hbox.add_child(name_lbl)

	## Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	## Buttons
	var save_btn: Button = null
	if is_manual:
		save_btn = Button.new()
		save_btn.name = "SaveButton_%s" % slot_key
		save_btn.text = "Save"
		save_btn.custom_minimum_size = Vector2(56, 26)
		save_btn.pressed.connect(_on_save.bind(slot_key))
		hbox.add_child(save_btn)

	var load_btn: Button = Button.new()
	load_btn.name = "LoadButton_%s" % slot_key
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(56, 26)
	load_btn.pressed.connect(_on_load.bind(slot_key))
	hbox.add_child(load_btn)

	var rename_btn: Button = null
	if is_manual:
		rename_btn = Button.new()
		rename_btn.name = "RenameButton_%s" % slot_key
		rename_btn.text = "Rename"
		rename_btn.custom_minimum_size = Vector2(64, 26)
		rename_btn.pressed.connect(_on_rename_start.bind(slot_key))
		hbox.add_child(rename_btn)

	var del_btn: Button = Button.new()
	del_btn.name = "DeleteButton_%s" % slot_key
	del_btn.text = "Del"
	del_btn.custom_minimum_size = Vector2(44, 26)
	del_btn.add_theme_color_override("font_color", Color("#FF6666"))
	del_btn.pressed.connect(_on_delete.bind(slot_key))
	hbox.add_child(del_btn)

	## Line 2: location + details (smaller, dimmer)
	var info_lbl: Label = Label.new()
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.add_theme_color_override("font_color", Color("#888888"))
	info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_lbl.clip_text = true
	outer.add_child(info_lbl)

	return {
		"slot_key": slot_key,
		"name_label": name_lbl,
		"info_label": info_lbl,
		"load_btn": load_btn,
		"delete_btn": del_btn,
		"save_btn": save_btn,
		"rename_btn": rename_btn,
	}


func _refresh_all_rows() -> void:
	_refresh_row(_autosave_row)
	for row: Dictionary in _rows:
		_refresh_row(row)


func _refresh_row(row: Dictionary) -> void:
	var slot_key: String = row["slot_key"]
	var name_lbl: Label = row["name_label"] as Label
	var info_lbl: Label = row["info_label"] as Label
	var load_btn: Button = row["load_btn"] as Button
	var del_btn: Button = row["delete_btn"] as Button
	var save_btn: Button = row.get("save_btn") as Button
	var rename_btn: Button = row.get("rename_btn") as Button

	## Hide save/rename buttons in load-only mode
	if save_btn != null:
		save_btn.visible = not load_only
	if rename_btn != null:
		rename_btn.visible = not load_only

	var info: Dictionary = SaveManager.get_slot_info(slot_key)
	if info.is_empty():
		## Show slot label for empty slots
		var default_label: String = "Autosave" if slot_key == SaveManager.AUTOSAVE_SLOT else ""
		for i: int in range(SLOT_KEYS.size()):
			if SLOT_KEYS[i] == slot_key:
				default_label = SLOT_LABELS[i]
				break
		name_lbl.text = default_label
		info_lbl.text = "— Empty —"
		info_lbl.add_theme_color_override("font_color", Color("#555555"))
		load_btn.disabled = true
		del_btn.disabled = true
		if rename_btn != null:
			rename_btn.disabled = true
	else:
		## Line 1: save name (or slot label if none)
		var save_name: String = info.get("save_name", "")
		if save_name == "":
			save_name = "Autosave" if slot_key == SaveManager.AUTOSAVE_SLOT else slot_key
		name_lbl.text = save_name

		## Line 2: location — Phase X — Y Glyphs — date
		var location: String = info.get("location", "")
		var phase: int = info.get("phase", 1)
		var glyphs: int = info.get("glyph_count", 0)
		var ts: String = info.get("timestamp", "")
		if ts.length() > 10:
			ts = ts.substr(0, 10)
		var parts: Array[String] = []
		if location != "":
			parts.append(location)
		parts.append("Phase %d" % phase)
		parts.append("%d Glyphs" % glyphs)
		if ts != "":
			parts.append(ts)
		info_lbl.text = " · ".join(parts)
		info_lbl.add_theme_color_override("font_color", Color("#888888"))
		load_btn.disabled = false
		del_btn.disabled = false
		if rename_btn != null:
			rename_btn.disabled = false


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


func _on_rename_start(slot_key: String) -> void:
	if not SaveManager.has_slot(slot_key):
		return
	_hide_rename()
	_rename_slot = slot_key

	## Find the row's name label and replace with a LineEdit
	var row: Dictionary = {}
	for r: Dictionary in _rows:
		if r["slot_key"] == slot_key:
			row = r
			break
	if row.is_empty():
		return

	var name_lbl: Label = row["name_label"] as Label
	_rename_edit = LineEdit.new()
	_rename_edit.text = name_lbl.text
	_rename_edit.custom_minimum_size = Vector2(120, 24)
	_rename_edit.add_theme_font_size_override("font_size", 13)
	_rename_edit.select_all()
	_rename_edit.text_submitted.connect(_on_rename_confirm)
	## Insert before the name label's parent spacer
	var hbox: HBoxContainer = name_lbl.get_parent() as HBoxContainer
	var idx: int = name_lbl.get_index()
	name_lbl.visible = false
	hbox.add_child(_rename_edit)
	hbox.move_child(_rename_edit, idx)
	_rename_edit.grab_focus()


func _on_rename_confirm(new_name: String) -> void:
	if _rename_slot == "" or new_name.strip_edges() == "":
		_hide_rename()
		return
	## Re-save with new name
	var info: Dictionary = SaveManager.get_slot_info(_rename_slot)
	if info.is_empty():
		_hide_rename()
		return
	## Load the raw save data, update save_name, write back
	var path: String = "user://save_%s.json" % _rename_slot
	if SaveManager._test_prefix != "":
		path = "user://%ssave_%s.json" % [SaveManager._test_prefix, _rename_slot]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_hide_rename()
		return
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		_hide_rename()
		return
	var data: Dictionary = json.data
	data["save_name"] = new_name.strip_edges()
	var json_string: String = JSON.stringify(data, "\t")
	var wfile: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if wfile != null:
		wfile.store_string(json_string)
		wfile.close()
	_hide_rename()
	_refresh_all_rows()


func _hide_rename() -> void:
	if _rename_edit != null and is_instance_valid(_rename_edit):
		## Restore the name label
		for r: Dictionary in _rows:
			if r["slot_key"] == _rename_slot:
				var name_lbl: Label = r["name_label"] as Label
				name_lbl.visible = true
				break
		_rename_edit.get_parent().remove_child(_rename_edit)
		_rename_edit.queue_free()
		_rename_edit = null
	_rename_slot = ""


func _gui_input(event: InputEvent) -> void:
	## Click outside panel to close
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var panel_rect: Rect2 = Rect2(_panel.global_position, _panel.size)
			if not panel_rect.has_point(mb.global_position):
				hide_popup()
