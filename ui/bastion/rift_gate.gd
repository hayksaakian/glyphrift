class_name RiftGate
extends Control

## Select and enter available rifts.

signal rift_selected(template: RiftTemplate)
signal back_pressed()

var game_state: GameState = null
var codex_state: CodexState = null
var data_loader: Node = null

var _title_label: Label = null
var _rift_container: HBoxContainer = null
var _back_button: Button = null
var _rift_panels: Array[PanelContainer] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func setup(p_game_state: GameState, p_codex_state: CodexState, p_data_loader: Node) -> void:
	game_state = p_game_state
	codex_state = p_codex_state
	data_loader = p_data_loader
	if is_inside_tree():
		refresh()


func refresh() -> void:
	_clear_rifts()

	if game_state == null:
		return

	var rifts: Array[RiftTemplate] = game_state.get_available_rifts()
	for template: RiftTemplate in rifts:
		var panel: PanelContainer = _make_rift_panel(template)
		_rift_container.add_child(panel)
		_rift_panels.append(panel)


func _build_ui() -> void:
	## Background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 20.0
	main_vbox.offset_top = 20.0
	main_vbox.offset_right = -20.0
	main_vbox.offset_bottom = -20.0
	main_vbox.add_theme_constant_override("separation", 16)
	add_child(main_vbox)

	## Title
	_title_label = Label.new()
	_title_label.text = "RIFT GATE"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	## Rift list
	_rift_container = HBoxContainer.new()
	_rift_container.add_theme_constant_override("separation", 16)
	_rift_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(_rift_container)

	## Spacer to push back button to bottom
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)

	## Back button
	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(100, 36)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	main_vbox.add_child(_back_button)


func _make_rift_panel(template: RiftTemplate) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 160)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#1A1A2E")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	## Rift name
	var name_label: Label = Label.new()
	name_label.text = template.name
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	## Tier + floor count
	var info_label: Label = Label.new()
	info_label.text = "%s \u00b7 %d Floors" % [template.tier.capitalize(), template.floors.size()]
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	vbox.add_child(info_label)

	## Boss species name
	if data_loader != null:
		var boss_def: BossDef = data_loader.get_boss(template.rift_id)
		if boss_def != null:
			var species: GlyphSpecies = data_loader.get_species(boss_def.species_id)
			if species != null:
				var boss_label: Label = Label.new()
				boss_label.text = "Boss: %s" % species.name
				boss_label.add_theme_font_size_override("font_size", 12)
				boss_label.add_theme_color_override("font_color", Color("#FF8800"))
				vbox.add_child(boss_label)

	## Cleared marker
	if codex_state != null and codex_state.is_rift_cleared(template.rift_id):
		var cleared_label: Label = Label.new()
		cleared_label.text = "\u2713 CLEARED"
		cleared_label.add_theme_font_size_override("font_size", 14)
		cleared_label.add_theme_color_override("font_color", Color("#4CAF50"))
		vbox.add_child(cleared_label)

	## Enter button
	var enter_btn: Button = Button.new()
	enter_btn.text = "Enter"
	enter_btn.custom_minimum_size = Vector2(80, 30)
	enter_btn.pressed.connect(func() -> void: rift_selected.emit(template))
	vbox.add_child(enter_btn)

	return panel


func _clear_rifts() -> void:
	_rift_panels.clear()
	for child: Node in _rift_container.get_children():
		_rift_container.remove_child(child)
		child.queue_free()
