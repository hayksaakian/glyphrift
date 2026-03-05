class_name TitleScreen
extends Control

## Title screen with New Game / Continue options.

signal new_game_pressed
signal continue_pressed
signal load_game_pressed

var _title_label: Label = null
var _subtitle_label: Label = null
var _new_game_btn: Button = null
var _continue_btn: Button = null
var _load_game_btn: Button = null
var _save_info_label: Label = null
var _vbox: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	## Dark background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.10)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	## Centered VBox
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_CENTER)
	_vbox.offset_left = -150.0
	_vbox.offset_right = 150.0
	_vbox.offset_top = -180.0
	_vbox.offset_bottom = 180.0
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_vbox)

	## Title
	_title_label = Label.new()
	_title_label.text = "GLYPHRIFT"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 64)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_vbox.add_child(_title_label)

	## Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "Dungeon-Crawling Monster-Fusion RPG"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_vbox.add_child(_subtitle_label)

	## Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	_vbox.add_child(spacer)

	## Continue button with save info subtitle
	_continue_btn = Button.new()
	_continue_btn.name = "ContinueButton"
	_continue_btn.custom_minimum_size = Vector2(200, 50)
	_continue_btn.disabled = true
	_continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	_vbox.add_child(_continue_btn)

	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_continue_btn.add_child(btn_vbox)

	var btn_label: Label = Label.new()
	btn_label.text = "Continue"
	btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_vbox.add_child(btn_label)

	_save_info_label = Label.new()
	_save_info_label.text = ""
	_save_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_info_label.add_theme_font_size_override("font_size", 11)
	_save_info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_save_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_vbox.add_child(_save_info_label)

	## New Game button
	_new_game_btn = Button.new()
	_new_game_btn.name = "NewGameButton"
	_new_game_btn.text = "New Game"
	_new_game_btn.custom_minimum_size = Vector2(200, 40)
	_new_game_btn.pressed.connect(func() -> void: new_game_pressed.emit())
	_vbox.add_child(_new_game_btn)

	## Load Game button
	_load_game_btn = Button.new()
	_load_game_btn.name = "LoadGameButton"
	_load_game_btn.text = "Load Game"
	_load_game_btn.custom_minimum_size = Vector2(200, 40)
	_load_game_btn.disabled = true
	_load_game_btn.pressed.connect(func() -> void: load_game_pressed.emit())
	_vbox.add_child(_load_game_btn)

	## Spacer before quit
	var quit_spacer: Control = Control.new()
	quit_spacer.custom_minimum_size = Vector2(0, 12)
	_vbox.add_child(quit_spacer)

	## Quit button
	var quit_btn: Button = Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(200, 34)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_vbox.add_child(quit_btn)


func refresh() -> void:
	var slot: String = get_most_recent_slot()
	var has_saves: bool = slot != ""
	_continue_btn.disabled = not has_saves
	_load_game_btn.disabled = not has_saves

	if not has_saves:
		_save_info_label.text = ""
		_new_game_btn.grab_focus()
		return

	var info: Dictionary = SaveManager.get_slot_info(slot)
	if info.is_empty():
		_save_info_label.text = ""
		_continue_btn.grab_focus()
		return

	var phase: int = info.get("phase", 1)
	var glyph_count: int = info.get("glyph_count", 0)
	var slot_label: String = "Auto Save" if slot == SaveManager.AUTOSAVE_SLOT else slot.capitalize()
	_save_info_label.text = "%s — Phase %d, %d glyphs" % [slot_label, phase, glyph_count]
	_continue_btn.grab_focus()


func get_most_recent_slot() -> String:
	var slots: Array[String] = SaveManager.list_slots()
	if slots.is_empty():
		return ""

	var best_slot: String = ""
	var best_timestamp: String = ""

	for slot: String in slots:
		var info: Dictionary = SaveManager.get_slot_info(slot)
		if info.is_empty():
			continue
		var ts: String = info.get("timestamp", "")
		if ts > best_timestamp:
			best_timestamp = ts
			best_slot = slot
	return best_slot
