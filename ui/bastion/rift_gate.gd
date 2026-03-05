class_name RiftGate
extends Control

## Select and enter available rifts.

signal rift_selected(template: RiftTemplate)
signal back_pressed()

var game_state: GameState = null
var codex_state: CodexState = null
var data_loader: Node = null

var _title_label: Label = null
var _rift_container: VBoxContainer = null  ## Outer container (holds both sections)
var _available_header: Label = null
var _available_row: HBoxContainer = null
var _cleared_header: Label = null
var _cleared_row: HBoxContainer = null
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
	var available: Array[RiftTemplate] = []
	var cleared: Array[RiftTemplate] = []
	for template: RiftTemplate in rifts:
		var is_cleared: bool = codex_state != null and codex_state.is_rift_cleared(template.rift_id)
		if is_cleared:
			cleared.append(template)
		else:
			available.append(template)

	for template: RiftTemplate in available:
		var panel: PanelContainer = _make_rift_panel(template)
		_available_row.add_child(panel)
		_rift_panels.append(panel)

	for template: RiftTemplate in cleared:
		var panel: PanelContainer = _make_rift_panel(template)
		_cleared_row.add_child(panel)
		_rift_panels.append(panel)

	_available_header.visible = available.size() > 0
	_cleared_header.visible = cleared.size() > 0


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
	main_vbox.offset_top = 48.0
	main_vbox.offset_right = -20.0
	main_vbox.offset_bottom = -20.0
	main_vbox.add_theme_constant_override("separation", 16)
	add_child(main_vbox)

	## Outer scroll for both sections
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll)

	_rift_container = VBoxContainer.new()
	_rift_container.add_theme_constant_override("separation", 20)
	_rift_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rift_container)

	## Available rifts section
	_available_header = _make_section_header("Available Rifts")
	_rift_container.add_child(_available_header)

	var avail_scroll: ScrollContainer = ScrollContainer.new()
	avail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	avail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rift_container.add_child(avail_scroll)

	_available_row = HBoxContainer.new()
	_available_row.add_theme_constant_override("separation", 16)
	avail_scroll.add_child(_available_row)

	## Cleared rifts section
	_cleared_header = _make_section_header("Cleared Rifts")
	_rift_container.add_child(_cleared_header)

	var cleared_scroll: ScrollContainer = ScrollContainer.new()
	cleared_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cleared_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cleared_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rift_container.add_child(cleared_scroll)

	_cleared_row = HBoxContainer.new()
	_cleared_row.add_theme_constant_override("separation", 16)
	cleared_scroll.add_child(_cleared_row)



func _make_rift_panel(template: RiftTemplate) -> PanelContainer:
	var is_cleared: bool = codex_state != null and codex_state.is_rift_cleared(template.rift_id)

	## Whole panel is clickable
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				rift_selected.emit(template)
	)

	var normal_color: Color = Color("#1A1A2E")
	var hover_color: Color = Color("#2A2A42")
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = normal_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	panel.mouse_entered.connect(func() -> void: style.bg_color = hover_color)
	panel.mouse_exited.connect(func() -> void: style.bg_color = normal_color)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	## Rift name
	var name_label: Label = Label.new()
	name_label.text = template.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	## Tier + floor count + cleared (all inline)
	var info_parts: String = "%s \u00b7 %d Floors" % [template.tier.capitalize(), template.floors.size()]
	if is_cleared:
		info_parts += " \u00b7 \u2713 Cleared"
	var info_label: Label = Label.new()
	info_label.text = info_parts
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info_label)

	## Boss portrait + name
	var boss_species_id: String = ""
	var boss_species_name: String = ""
	var boss_affinity: String = "neutral"
	if data_loader != null:
		var boss_def: BossDef = data_loader.get_boss(template.rift_id)
		if boss_def != null:
			boss_species_id = boss_def.species_id
			var species: GlyphSpecies = data_loader.get_species(boss_species_id)
			if species != null:
				boss_species_name = species.name
				boss_affinity = species.affinity

	if boss_species_id != "":
		var tex: Texture2D = GlyphArt.get_portrait(boss_species_id)
		if tex != null:
			## Portrait container — affinity-colored backdrop (matches glyph_card pattern)
			var portrait_bg: ColorRect = ColorRect.new()
			portrait_bg.custom_minimum_size = Vector2(0, 120)
			portrait_bg.color = Affinity.COLORS.get(boss_affinity, Affinity.COLORS["neutral"]).darkened(0.6)
			portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(portrait_bg)

			var portrait: TextureRect = TextureRect.new()
			portrait.texture = tex
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait_bg.add_child(portrait)

	## Boss name label
	if boss_species_name != "":
		var boss_label: Label = Label.new()
		boss_label.text = "Boss: %s" % boss_species_name
		boss_label.add_theme_font_size_override("font_size", 12)
		boss_label.add_theme_color_override("font_color", Color("#FF8800"))
		boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(boss_label)

	## Action label (not a button — the whole panel is clickable)
	var action_label: Label = Label.new()
	action_label.text = "Re-enter" if is_cleared else "Enter"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 14)
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(action_label)

	return panel


func _make_section_header(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#AAAAAA"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _clear_rifts() -> void:
	_rift_panels.clear()
	for row: HBoxContainer in [_available_row, _cleared_row]:
		for child: Node in row.get_children():
			row.remove_child(child)
			child.queue_free()
