extends Control

## Focused screenshot harness for sizing fixes:
## 1. Formation screen — verify name labels aren't clipped
## 2. Room popup — verify formation preview icons are readable
##
## Run: ~/bin/godot --path . res://tests/screenshot_sizing.tscn

var _data_loader: Node = null
var _roster_state: RosterState = null
var _codex_state: CodexState = null
var _step: int = 0
var _steps: Array[String] = []
var _screenshot_dir: String = "res://screenshots/"


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")
	_setup_deps()

	_steps = [
		"sizing_01_formation_screen",
		"sizing_02_room_popup_enemy",
		"sizing_03_room_popup_boss",
		"sizing_04_glyph_portrait_standalone",
		"sizing_05_dungeon_hud_menu",
	]

	await get_tree().process_frame
	await get_tree().process_frame
	_run_step()


func _setup_deps() -> void:
	_roster_state = RosterState.new()
	_roster_state.name = "RosterState"
	add_child(_roster_state)
	_roster_state.initialize_starting_glyphs(_data_loader)

	_codex_state = CodexState.new()
	_codex_state.name = "CodexState"
	add_child(_codex_state)

	## Give some glyphs mastery stars for visual variety
	var idx: int = 0
	for g: GlyphInstance in _roster_state.active_squad:
		if idx == 0 and g.mastery_objectives.size() >= 3:
			## Fully mastered
			for i: int in range(g.mastery_objectives.size()):
				g.mastery_objectives[i]["completed"] = true
			g.is_mastered = true
		elif idx == 1 and g.mastery_objectives.size() >= 2:
			## 2 stars
			g.mastery_objectives[0]["completed"] = true
			g.mastery_objectives[1]["completed"] = true
		elif idx == 2 and g.mastery_objectives.size() >= 1:
			## 1 star
			g.mastery_objectives[0]["completed"] = true
		idx += 1


func _run_step() -> void:
	if _step >= _steps.size():
		print("Sizing screenshot harness complete — %d screenshots captured" % _steps.size())
		await get_tree().process_frame
		get_tree().quit()
		return

	## Clear previous step's children (except deps)
	for child: Node in get_children():
		if child is RosterState or child is CodexState:
			continue
		if child.name.begins_with("step_"):
			remove_child(child)
			child.queue_free()

	await get_tree().process_frame

	var step_name: String = _steps[_step]
	print("Step %d: %s" % [_step + 1, step_name])

	match step_name:
		"sizing_01_formation_screen":
			_show_formation_screen()

		"sizing_02_room_popup_enemy":
			_show_room_popup("enemy")

		"sizing_03_room_popup_boss":
			_show_room_popup("boss")

		"sizing_04_glyph_portrait_standalone":
			_show_portrait_gallery()

		"sizing_05_dungeon_hud_menu":
			_show_dungeon_with_hud()

	## Wait for layout
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_take_screenshot(step_name)

	_step += 1
	await get_tree().process_frame
	_run_step()


func _show_formation_screen() -> void:
	var formation: FormationSetup = FormationSetup.new()
	formation.name = "step_formation"
	add_child(formation)
	formation.show_formation(_roster_state.active_squad)


func _show_room_popup(room_type: String) -> void:
	## Background
	var bg: ColorRect = ColorRect.new()
	bg.name = "step_bg"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1)
	add_child(bg)

	## Center the popup
	var center: CenterContainer = CenterContainer.new()
	center.name = "step_center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var popup: RoomPopup = RoomPopup.new()
	popup.name = "step_popup"
	popup.data_loader = _data_loader
	popup.roster_state = _roster_state
	center.add_child(popup)

	## Build scan species from data for a realistic preview
	var scan_ids: Array = []
	if room_type == "boss":
		## Use a real species id (not boss id)
		var all_ids: Array = _data_loader.species.keys()
		if all_ids.size() > 0:
			scan_ids = [all_ids[0]]
	else:
		## Pick 2-3 wild species for enemy preview
		var all_ids: Array = _data_loader.species.keys()
		for i: int in range(mini(3, all_ids.size())):
			scan_ids.append(all_ids[i])

	var room_data: Dictionary = {
		"type": room_type,
		"scan_species_ids": scan_ids,
	}

	popup.show_room(room_data)


func _show_portrait_gallery() -> void:
	## Show portraits at different sizes to verify scaling
	var bg: ColorRect = ColorRect.new()
	bg.name = "step_bg"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1)
	add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "step_gallery"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 24)
	add_child(vbox)

	## Row labels + portraits at 32, 48, 64 sizes
	var sizes: Array[int] = [32, 48, 64]
	for sz: int in sizes:
		var row_label: Label = Label.new()
		row_label.text = "portrait_size = %d" % sz
		row_label.add_theme_font_size_override("font_size", 14)
		row_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		vbox.add_child(row_label)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		vbox.add_child(hbox)

		for g: GlyphInstance in _roster_state.active_squad:
			var portrait: GlyphPortrait = GlyphPortrait.new()
			portrait.portrait_size = sz
			portrait.glyph = g
			hbox.add_child(portrait)


func _show_dungeon_with_hud() -> void:
	## Show just the CrawlerHUD to verify Menu button is integrated
	var bg: ColorRect = ColorRect.new()
	bg.name = "step_bg"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1)
	add_child(bg)

	var crawler: CrawlerState = CrawlerState.new()
	crawler.name = "step_crawler"
	add_child(crawler)

	var hud: CrawlerHUD = CrawlerHUD.new()
	hud.name = "step_hud"
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.custom_minimum_size.y = 44.0
	add_child(hud)
	hud.setup(crawler)


func _take_screenshot(step_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir + step_name + ".png"
	var err: Error = image.save_png(path)
	if err == OK:
		print("  -> Saved: %s" % path)
	else:
		print("  -> ERROR saving: %s (code %d)" % [path, err])
