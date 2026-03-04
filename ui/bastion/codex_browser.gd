class_name CodexBrowser
extends Control

## Codex browser with three tabs: Glyph Registry, Fusion Log, Rift Atlas.

signal back_pressed

var data_loader: Node = null
var codex_state: CodexState = null
var game_state: GameState = null
var roster_state: RosterState = null

## Tab state
enum Tab { GLYPH_REGISTRY, FUSION_LOG, RIFT_ATLAS }
var _current_tab: int = Tab.GLYPH_REGISTRY

## Internal nodes
var _bg: ColorRect = null
var _title_label: Label = null
var _tab_row: HBoxContainer = null
var _glyph_tab_btn: Button = null
var _fusion_tab_btn: Button = null
var _rift_tab_btn: Button = null
var _back_btn: Button = null

## Tab panels
var _glyph_panel: Control = null
var _fusion_panel: Control = null
var _rift_panel: Control = null

## Glyph Registry internals
var _glyph_grid: GridContainer = null
var _glyph_counter: Label = null
var _species_panels: Array[Control] = []

## Fusion Log internals
var _fusion_vbox: VBoxContainer = null
var _fusion_empty_label: Label = null

## Rift Atlas internals
var _rift_vbox: VBoxContainer = null

## Detail popup
var _detail_popup: GlyphDetailPopup = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_signals()


func setup(p_data_loader: Node, p_codex_state: CodexState, p_game_state: GameState, p_roster_state: RosterState = null) -> void:
	data_loader = p_data_loader
	codex_state = p_codex_state
	game_state = p_game_state
	roster_state = p_roster_state


func refresh() -> void:
	_show_tab(_current_tab)


func get_current_tab() -> int:
	return _current_tab


func _build_ui() -> void:
	## Background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.06, 0.06, 0.10)
	_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bg)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 20.0
	main_vbox.offset_top = 20.0
	main_vbox.offset_right = -20.0
	main_vbox.offset_bottom = -20.0
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	## Title
	_title_label = Label.new()
	_title_label.text = "CODEX"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	## Tab row
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 16)
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(_tab_row)

	_glyph_tab_btn = Button.new()
	_glyph_tab_btn.text = "Glyph Registry"
	_glyph_tab_btn.custom_minimum_size = Vector2(140, 36)
	_tab_row.add_child(_glyph_tab_btn)

	_fusion_tab_btn = Button.new()
	_fusion_tab_btn.text = "Fusion Log"
	_fusion_tab_btn.custom_minimum_size = Vector2(140, 36)
	_tab_row.add_child(_fusion_tab_btn)

	_rift_tab_btn = Button.new()
	_rift_tab_btn.text = "Rift Atlas"
	_rift_tab_btn.custom_minimum_size = Vector2(140, 36)
	_tab_row.add_child(_rift_tab_btn)

	## --- Glyph Registry panel ---
	_glyph_panel = Control.new()
	_glyph_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_glyph_panel)

	var glyph_scroll: ScrollContainer = ScrollContainer.new()
	glyph_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glyph_panel.add_child(glyph_scroll)

	var glyph_inner: VBoxContainer = VBoxContainer.new()
	glyph_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glyph_inner.add_theme_constant_override("separation", 8)
	glyph_scroll.add_child(glyph_inner)

	_glyph_counter = Label.new()
	_glyph_counter.add_theme_font_size_override("font_size", 14)
	_glyph_counter.add_theme_color_override("font_color", Color("#AAAAAA"))
	_glyph_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_inner.add_child(_glyph_counter)

	var grid_center: CenterContainer = CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glyph_inner.add_child(grid_center)

	_glyph_grid = GridContainer.new()
	_glyph_grid.columns = 5
	_glyph_grid.add_theme_constant_override("h_separation", 8)
	_glyph_grid.add_theme_constant_override("v_separation", 8)
	grid_center.add_child(_glyph_grid)

	## --- Fusion Log panel ---
	_fusion_panel = Control.new()
	_fusion_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fusion_panel.visible = false
	main_vbox.add_child(_fusion_panel)

	var fusion_scroll: ScrollContainer = ScrollContainer.new()
	fusion_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fusion_panel.add_child(fusion_scroll)

	_fusion_vbox = VBoxContainer.new()
	_fusion_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fusion_vbox.add_theme_constant_override("separation", 6)
	fusion_scroll.add_child(_fusion_vbox)

	_fusion_empty_label = Label.new()
	_fusion_empty_label.text = "No fusions recorded."
	_fusion_empty_label.add_theme_font_size_override("font_size", 14)
	_fusion_empty_label.add_theme_color_override("font_color", Color("#888888"))
	_fusion_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fusion_vbox.add_child(_fusion_empty_label)

	## --- Rift Atlas panel ---
	_rift_panel = Control.new()
	_rift_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rift_panel.visible = false
	main_vbox.add_child(_rift_panel)

	var rift_scroll: ScrollContainer = ScrollContainer.new()
	rift_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rift_panel.add_child(rift_scroll)

	_rift_vbox = VBoxContainer.new()
	_rift_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rift_vbox.add_theme_constant_override("separation", 6)
	rift_scroll.add_child(_rift_vbox)

	## Back button
	_back_btn = Button.new()
	_back_btn.text = "Back"
	_back_btn.custom_minimum_size = Vector2(100, 36)
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(_back_btn)

	## Detail popup (above everything)
	_detail_popup = GlyphDetailPopup.new()
	_detail_popup.name = "CodexDetailPopup"
	add_child(_detail_popup)


func _connect_signals() -> void:
	_glyph_tab_btn.pressed.connect(func() -> void: _show_tab(Tab.GLYPH_REGISTRY))
	_fusion_tab_btn.pressed.connect(func() -> void: _show_tab(Tab.FUSION_LOG))
	_rift_tab_btn.pressed.connect(func() -> void: _show_tab(Tab.RIFT_ATLAS))
	_back_btn.pressed.connect(func() -> void: back_pressed.emit())


func _show_tab(tab: int) -> void:
	_current_tab = tab
	_glyph_panel.visible = tab == Tab.GLYPH_REGISTRY
	_fusion_panel.visible = tab == Tab.FUSION_LOG
	_rift_panel.visible = tab == Tab.RIFT_ATLAS

	match tab:
		Tab.GLYPH_REGISTRY:
			_refresh_glyph_registry()
		Tab.FUSION_LOG:
			_refresh_fusion_log()
		Tab.RIFT_ATLAS:
			_refresh_rift_atlas()


func _refresh_glyph_registry() -> void:
	## Clear old panels
	_species_panels.clear()
	for child: Node in _glyph_grid.get_children():
		_glyph_grid.remove_child(child)
		child.queue_free()

	if data_loader == null or codex_state == null:
		_glyph_counter.text = "0/15 Discovered"
		return

	## Build sorted species list
	var all_species: Array[GlyphSpecies] = []
	for sp: GlyphSpecies in data_loader.species.values():
		all_species.append(sp)
	all_species.sort_custom(func(a: GlyphSpecies, b: GlyphSpecies) -> bool:
		if a.tier != b.tier:
			return a.tier < b.tier
		return a.name < b.name
	)

	var discovered_count: int = codex_state.get_discovery_count()
	_glyph_counter.text = "%d/15 Discovered" % discovered_count

	for sp: GlyphSpecies in all_species:
		var panel: Control = _build_species_panel(sp)
		_glyph_grid.add_child(panel)
		_species_panels.append(panel)


func _has_species_in_roster(species_id: String) -> bool:
	if roster_state == null:
		return false
	for g: GlyphInstance in roster_state.all_glyphs:
		if g.species != null and g.species.id == species_id:
			return true
	return false


func _build_species_panel(sp: GlyphSpecies) -> Control:
	var is_discovered: bool = codex_state.is_species_discovered(sp.id)
	var is_owned: bool = is_discovered and _has_species_in_roster(sp.id)
	var aff_color: Color = Affinity.COLORS.get(sp.affinity, Affinity.COLORS["neutral"])
	var entry: Dictionary = data_loader.codex_entries.get(sp.id, {})
	var hint: String = entry.get("hint", "")

	var panel: Control = Control.new()
	panel.custom_minimum_size = Vector2(120, 160)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	## Background — border color indicates status
	var bg: Panel = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color("#1A1A2E")
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	if is_owned:
		bg_style.border_color = aff_color.darkened(0.2)
		bg_style.border_width_left = 2
		bg_style.border_width_right = 2
		bg_style.border_width_top = 2
		bg_style.border_width_bottom = 2
	elif is_discovered:
		bg_style.border_color = Color("#555555")
		bg_style.border_width_left = 1
		bg_style.border_width_right = 1
		bg_style.border_width_top = 1
		bg_style.border_width_bottom = 1
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4.0
	vbox.offset_top = 4.0
	vbox.offset_right = -4.0
	vbox.offset_bottom = -4.0
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	## Art placeholder (60x60)
	var art_container: CenterContainer = CenterContainer.new()
	art_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(art_container)

	var art_rect: ColorRect = ColorRect.new()
	art_rect.custom_minimum_size = Vector2(60, 60)
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_container.add_child(art_rect)

	var initial_label: Label = Label.new()
	initial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_label.add_theme_font_size_override("font_size", 24)
	initial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	initial_label.add_theme_constant_override("outline_size", 3)
	initial_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_rect.add_child(initial_label)

	if is_discovered:
		art_rect.color = aff_color
		initial_label.text = sp.name[0].to_upper()
		initial_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		art_rect.color = Color("#333333")
		initial_label.text = "?"
		initial_label.add_theme_color_override("font_color", Color("#666666"))

	## Name
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	if is_discovered:
		name_label.text = sp.name
		name_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color("#555555"))

	## Affinity type (issue #4) — show for discovered, hide for undiscovered
	var type_label: Label = Label.new()
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(type_label)

	if is_discovered:
		var emoji: String = Affinity.EMOJI.get(sp.affinity, "")
		type_label.text = "%s %s T%d" % [emoji, sp.affinity.capitalize(), sp.tier]
		type_label.add_theme_color_override("font_color", aff_color.lightened(0.2))
	else:
		type_label.text = "T%d" % sp.tier
		type_label.add_theme_color_override("font_color", Color("#444444"))

	## Status indicator (issue #3): Owned vs Seen-only vs Unknown
	var status_label: Label = Label.new()
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(status_label)

	if is_owned:
		status_label.text = "In Roster"
		status_label.add_theme_color_override("font_color", Color("#4CAF50"))
	elif is_discovered:
		status_label.text = "Seen"
		status_label.add_theme_color_override("font_color", Color("#888888"))
	else:
		status_label.text = ""

	## Hint (issue #2): only show for discovered species
	if is_discovered:
		var hint_label: Label = Label.new()
		hint_label.add_theme_font_size_override("font_size", 8)
		hint_label.add_theme_color_override("font_color", Color("#777777"))
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint_label.text = hint
		vbox.add_child(hint_label)

	## Store species_id for click handling
	panel.set_meta("species_id", sp.id)
	panel.set_meta("is_discovered", is_discovered)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_on_species_panel_clicked(sp.id)
	)

	return panel


func _on_species_panel_clicked(species_id: String) -> void:
	if codex_state == null or data_loader == null:
		return
	if not codex_state.is_species_discovered(species_id):
		return
	var sp: GlyphSpecies = data_loader.get_species(species_id)
	if sp == null:
		return
	## Check if player has captured this species (in roster)
	var is_captured: bool = false
	if roster_state != null:
		for g: GlyphInstance in roster_state.all_glyphs:
			if g.species != null and g.species.id == species_id:
				is_captured = true
				break
	_detail_popup.show_species_info(sp, data_loader, is_captured)


func _refresh_fusion_log() -> void:
	## Clear old entries
	for child: Node in _fusion_vbox.get_children():
		_fusion_vbox.remove_child(child)
		child.queue_free()

	if codex_state == null or codex_state.fusion_log.is_empty():
		_fusion_empty_label = Label.new()
		_fusion_empty_label.text = "No fusions recorded."
		_fusion_empty_label.add_theme_font_size_override("font_size", 14)
		_fusion_empty_label.add_theme_color_override("font_color", Color("#888888"))
		_fusion_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fusion_vbox.add_child(_fusion_empty_label)
		return

	for entry: Dictionary in codex_state.fusion_log:
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#CCCCCC"))

		var parent_a_name: String = _get_species_display(entry.get("parent_a", ""))
		var parent_b_name: String = _get_species_display(entry.get("parent_b", ""))
		var result_name: String = _get_species_display(entry.get("result", ""))

		var a_emoji: String = _get_species_emoji(entry.get("parent_a", ""))
		var b_emoji: String = _get_species_emoji(entry.get("parent_b", ""))
		var r_emoji: String = _get_species_emoji(entry.get("result", ""))

		label.text = "%s %s + %s %s → %s %s" % [a_emoji, parent_a_name, b_emoji, parent_b_name, r_emoji, result_name]
		_fusion_vbox.add_child(label)


func _get_species_display(species_id: String) -> String:
	if data_loader == null:
		return species_id
	var sp: GlyphSpecies = data_loader.get_species(species_id)
	if sp == null:
		return species_id
	return sp.name


func _get_species_emoji(species_id: String) -> String:
	if data_loader == null:
		return ""
	var sp: GlyphSpecies = data_loader.get_species(species_id)
	if sp == null:
		return ""
	return Affinity.EMOJI.get(sp.affinity, "")


func _refresh_rift_atlas() -> void:
	## Clear old entries
	for child: Node in _rift_vbox.get_children():
		_rift_vbox.remove_child(child)
		child.queue_free()

	if game_state == null or codex_state == null:
		return

	var rifts: Array[RiftTemplate] = game_state.get_available_rifts()
	if rifts.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No rifts available."
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color("#888888"))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rift_vbox.add_child(empty_label)
		return

	for template: RiftTemplate in rifts:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_rift_vbox.add_child(row)

		var name_label: Label = Label.new()
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.text = template.name
		row.add_child(name_label)

		var tier_label: Label = Label.new()
		tier_label.add_theme_font_size_override("font_size", 12)
		tier_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		tier_label.text = "[%s]" % template.tier
		row.add_child(tier_label)

		if codex_state.is_rift_cleared(template.rift_id):
			var cleared_label: Label = Label.new()
			cleared_label.add_theme_font_size_override("font_size", 12)
			cleared_label.add_theme_color_override("font_color", Color("#4CAF50"))
			cleared_label.text = "CLEARED"
			row.add_child(cleared_label)
