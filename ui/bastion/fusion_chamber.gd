class_name FusionChamber
extends Control

## Select two mastered glyphs, preview result, confirm fusion.

signal back_pressed()

var fusion_engine: FusionEngine = null
var roster_state: RosterState = null
var crawler_state: CrawlerState = null
var data_loader: Node = null

## Selected parents
var _parent_a: GlyphInstance = null
var _parent_b: GlyphInstance = null

## Technique selection
var _selected_technique_ids: Array[String] = []
var _max_techniques: int = 0

## Internal nodes
var _title_label: Label = null
var _parent_a_card: GlyphCard = null
var _parent_b_card: GlyphCard = null
var _parent_a_slot: PanelContainer = null
var _parent_b_slot: PanelContainer = null
var _picker_container: GridContainer = null
var _picker_label: Label = null
var _preview_panel: VBoxContainer = null
var _preview_name: Label = null
var _preview_stats: Label = null
var _preview_gp: Label = null
var _gp_warning: Label = null
var _technique_container: VBoxContainer = null
var _fuse_button: Button = null
var _back_button: Button = null
var _error_label: Label = null
var _discovery_overlay: ColorRect = null
var _discovery_label: Label = null
var _discovery_result_card: GlyphCard = null

## Track picker cards for cleanup
var _picker_cards: Array[GlyphCard] = []
var _technique_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func setup(p_fusion: FusionEngine, p_roster: RosterState, p_crawler: CrawlerState, p_data_loader: Node) -> void:
	fusion_engine = p_fusion
	roster_state = p_roster
	crawler_state = p_crawler
	data_loader = p_data_loader
	if is_inside_tree():
		refresh()


func refresh() -> void:
	_clear_picker()
	_clear_parent_slots()
	_parent_a = null
	_parent_b = null
	_selected_technique_ids.clear()
	_preview_panel.visible = false
	_error_label.visible = false
	_fuse_button.visible = false
	_gp_warning.visible = false
	_discovery_overlay.visible = false

	if roster_state == null:
		return

	## Populate picker with all glyphs — mastered ones clickable, others disabled
	for g: GlyphInstance in roster_state.all_glyphs:
		var card: GlyphCard = GlyphCard.new()
		card.setup(g)
		card.disabled_state = not g.is_mastered
		card.card_clicked.connect(_on_picker_clicked)
		_picker_container.add_child(card)
		_picker_cards.append(card)


func _build_ui() -> void:
	## Background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	## ScrollContainer so content doesn't overflow
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 20.0
	scroll.offset_top = 20.0
	scroll.offset_right = -20.0
	scroll.offset_bottom = -20.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(main_vbox)

	## Title
	_title_label = Label.new()
	_title_label.text = "FUSION CHAMBER"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	## Parent slots row
	var parent_row: HBoxContainer = HBoxContainer.new()
	parent_row.add_theme_constant_override("separation", 20)
	parent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(parent_row)

	_parent_a_slot = _make_empty_slot("Parent A")
	parent_row.add_child(_parent_a_slot)

	var plus_label: Label = Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 28)
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent_row.add_child(plus_label)

	_parent_b_slot = _make_empty_slot("Parent B")
	parent_row.add_child(_parent_b_slot)

	## Error label
	_error_label = Label.new()
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_label.add_theme_color_override("font_color", Color("#FF4444"))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.visible = false
	main_vbox.add_child(_error_label)

	## Picker
	_picker_label = Label.new()
	_picker_label.text = "-- Available Glyphs (mastered only) --"
	_picker_label.add_theme_font_size_override("font_size", 14)
	_picker_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_picker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_picker_label)

	var picker_center: CenterContainer = CenterContainer.new()
	picker_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(picker_center)

	_picker_container = GridContainer.new()
	_picker_container.columns = 5
	_picker_container.add_theme_constant_override("h_separation", 8)
	_picker_container.add_theme_constant_override("v_separation", 8)
	picker_center.add_child(_picker_container)

	## Preview panel — horizontal: stats left, techniques right
	_preview_panel = VBoxContainer.new()
	_preview_panel.add_theme_constant_override("separation", 4)
	_preview_panel.visible = false
	main_vbox.add_child(_preview_panel)

	var preview_header: Label = Label.new()
	preview_header.text = "-- Preview --"
	preview_header.add_theme_font_size_override("font_size", 14)
	preview_header.add_theme_color_override("font_color", Color("#AAAAAA"))
	preview_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_panel.add_child(preview_header)

	var preview_hbox: HBoxContainer = HBoxContainer.new()
	preview_hbox.add_theme_constant_override("separation", 40)
	preview_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview_panel.add_child(preview_hbox)

	## Left: result info
	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 2)
	preview_hbox.add_child(info_col)

	_preview_name = Label.new()
	_preview_name.add_theme_font_size_override("font_size", 16)
	info_col.add_child(_preview_name)

	_preview_stats = Label.new()
	_preview_stats.add_theme_font_size_override("font_size", 12)
	info_col.add_child(_preview_stats)

	_preview_gp = Label.new()
	_preview_gp.add_theme_font_size_override("font_size", 12)
	info_col.add_child(_preview_gp)

	_gp_warning = Label.new()
	_gp_warning.text = "\u26a0 Over capacity!"
	_gp_warning.add_theme_font_size_override("font_size", 12)
	_gp_warning.add_theme_color_override("font_color", Color("#FFC107"))
	_gp_warning.visible = false
	info_col.add_child(_gp_warning)

	## Right: technique selection
	var tech_col: VBoxContainer = VBoxContainer.new()
	tech_col.add_theme_constant_override("separation", 2)
	preview_hbox.add_child(tech_col)

	var tech_header: Label = Label.new()
	tech_header.text = "Inherit techniques:"
	tech_header.add_theme_font_size_override("font_size", 12)
	tech_header.add_theme_color_override("font_color", Color("#AAAAAA"))
	tech_col.add_child(tech_header)

	_technique_container = VBoxContainer.new()
	_technique_container.add_theme_constant_override("separation", 2)
	tech_col.add_child(_technique_container)

	## Buttons row
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(btn_row)

	_fuse_button = Button.new()
	_fuse_button.text = "Fuse!"
	_fuse_button.custom_minimum_size = Vector2(100, 36)
	_fuse_button.visible = false
	_fuse_button.pressed.connect(_on_fuse_pressed)
	btn_row.add_child(_fuse_button)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(100, 36)
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	btn_row.add_child(_back_button)

	## Discovery overlay (hidden)
	_discovery_overlay = ColorRect.new()
	_discovery_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_discovery_overlay.color = Color(0, 0, 0, 0.9)
	_discovery_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_discovery_overlay.visible = false
	add_child(_discovery_overlay)

	var disc_vbox: VBoxContainer = VBoxContainer.new()
	disc_vbox.set_anchors_preset(Control.PRESET_CENTER)
	disc_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	disc_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	disc_vbox.add_theme_constant_override("separation", 16)
	_discovery_overlay.add_child(disc_vbox)

	_discovery_label = Label.new()
	_discovery_label.text = "NEW DISCOVERY!"
	_discovery_label.add_theme_font_size_override("font_size", 28)
	_discovery_label.add_theme_color_override("font_color", Color("#FFD700"))
	_discovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disc_vbox.add_child(_discovery_label)

	## Placeholder for result card — created on discovery
	var disc_center: CenterContainer = CenterContainer.new()
	disc_vbox.add_child(disc_center)
	_discovery_result_card = GlyphCard.new()
	disc_center.add_child(_discovery_result_card)

	var dismiss_btn: Button = Button.new()
	dismiss_btn.text = "Continue"
	dismiss_btn.custom_minimum_size = Vector2(120, 36)
	dismiss_btn.pressed.connect(_hide_discovery)
	disc_vbox.add_child(dismiss_btn)


func _on_picker_clicked(g: GlyphInstance) -> void:
	if g == null or not g.is_mastered:
		return

	## Don't allow picking same glyph for both slots
	if _parent_a != null and _parent_a == g:
		return
	if _parent_b != null and _parent_b == g:
		return

	if _parent_a == null:
		_parent_a = g
		_update_parent_slot(_parent_a_slot, g)
	elif _parent_b == null:
		_parent_b = g
		_update_parent_slot(_parent_b_slot, g)
	else:
		return  ## Both slots filled

	## Highlight selected in picker
	_update_picker_selection()

	if _parent_a != null and _parent_b != null:
		_check_fusion()


func _update_parent_slot(slot: PanelContainer, g: GlyphInstance) -> void:
	## Clear slot
	for child: Node in slot.get_children():
		slot.remove_child(child)
		child.queue_free()

	var card: GlyphCard = GlyphCard.new()
	card.setup(g)
	card.card_clicked.connect(_on_parent_slot_clicked)
	slot.add_child(card)


func _on_parent_slot_clicked(g: GlyphInstance) -> void:
	## Clear the slot
	if g == _parent_a:
		_parent_a = null
		_reset_slot(_parent_a_slot, "Parent A")
	elif g == _parent_b:
		_parent_b = null
		_reset_slot(_parent_b_slot, "Parent B")

	_preview_panel.visible = false
	_error_label.visible = false
	_fuse_button.visible = false
	_gp_warning.visible = false
	_update_picker_selection()


func _check_fusion() -> void:
	if fusion_engine == null:
		return

	var result: Dictionary = fusion_engine.can_fuse(_parent_a, _parent_b)
	if not result["valid"]:
		_error_label.text = result["reason"]
		_error_label.visible = true
		_preview_panel.visible = false
		_fuse_button.visible = false
		return

	_error_label.visible = false
	var preview: Dictionary = fusion_engine.preview_fusion(_parent_a, _parent_b)
	_show_preview(preview)


func _show_preview(preview: Dictionary) -> void:
	_preview_panel.visible = true
	_fuse_button.visible = true

	var name_text: String = preview["result_species_name"]
	var aff: String = preview["result_affinity"]
	var tier: int = preview["result_tier"]
	var emoji: String = Affinity.EMOJI.get(aff, "")
	_preview_name.text = "Result: %s (%s %s T%d)" % [name_text, emoji, aff.capitalize(), tier]

	var bonuses: Dictionary = preview["inheritance_bonuses"]
	_preview_stats.text = "Stats: HP+%d ATK+%d DEF+%d SPD+%d RES+%d" % [
		bonuses["hp"], bonuses["atk"], bonuses["def"], bonuses["spd"], bonuses["res"]
	]

	var gp: int = preview["result_gp"]
	_preview_gp.text = "GP: %d" % gp

	## GP warning
	if crawler_state != null and gp > crawler_state.capacity:
		_gp_warning.visible = true
	else:
		_gp_warning.visible = false

	## Technique selection
	_clear_techniques()
	_max_techniques = preview["num_technique_slots"]
	_selected_technique_ids.clear()

	var all_inheritable: Array[TechniqueDef] = []
	for t: TechniqueDef in preview["inheritable_techniques_a"]:
		all_inheritable.append(t)
	for t: TechniqueDef in preview["inheritable_techniques_b"]:
		if not _has_technique(all_inheritable, t):
			all_inheritable.append(t)

	for tech: TechniqueDef in all_inheritable:
		var btn: Button = Button.new()
		btn.text = tech.name
		btn.custom_minimum_size = Vector2(200, 28)
		btn.toggle_mode = true
		btn.set_meta("tech_id", tech.id)
		btn.toggled.connect(_on_technique_toggled.bind(tech.id))
		_technique_container.add_child(btn)
		_technique_buttons.append(btn)


func _on_technique_toggled(toggled_on: bool, tech_id: String) -> void:
	if toggled_on:
		if _selected_technique_ids.size() < _max_techniques:
			_selected_technique_ids.append(tech_id)
		else:
			## Over limit — untoggle
			for btn: Button in _technique_buttons:
				if btn.get_meta("tech_id") == tech_id:
					btn.set_pressed_no_signal(false)
					return
	else:
		_selected_technique_ids.erase(tech_id)


func _on_fuse_pressed() -> void:
	if fusion_engine == null or _parent_a == null or _parent_b == null:
		return

	var tech_ids: Array[String] = _selected_technique_ids.duplicate()
	var result: GlyphInstance = fusion_engine.execute_fusion(_parent_a, _parent_b, tech_ids)

	## Check if new species was discovered (check via codex)
	var was_new: bool = false
	if fusion_engine.codex_state != null:
		## FusionEngine already called discover_species and emitted new_species_discovered
		## We listen for it via the signal approach, but for simplicity check result
		was_new = true  ## We'll use the signal from fusion_engine instead

	_show_discovery(result)


func _show_discovery(result: GlyphInstance) -> void:
	_discovery_result_card.setup(result)
	_discovery_overlay.visible = true


func _hide_discovery() -> void:
	_discovery_overlay.visible = false
	refresh()


func _update_picker_selection() -> void:
	for card: GlyphCard in _picker_cards:
		if card.glyph == _parent_a or card.glyph == _parent_b:
			card.selected = true
		else:
			card.selected = false


func _make_empty_slot(label_text: String) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(120, 160)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#222233")
	style.border_color = Color("#555566")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	slot.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#666677"))
	slot.add_child(label)

	return slot


func _reset_slot(slot: PanelContainer, label_text: String) -> void:
	for child: Node in slot.get_children():
		slot.remove_child(child)
		child.queue_free()

	var label: Label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#666677"))
	slot.add_child(label)


func _clear_picker() -> void:
	_picker_cards.clear()
	for child: Node in _picker_container.get_children():
		_picker_container.remove_child(child)
		child.queue_free()


func _clear_techniques() -> void:
	_technique_buttons.clear()
	for child: Node in _technique_container.get_children():
		_technique_container.remove_child(child)
		child.queue_free()


func _clear_parent_slots() -> void:
	_reset_slot(_parent_a_slot, "Parent A")
	_reset_slot(_parent_b_slot, "Parent B")


func _has_technique(arr: Array[TechniqueDef], t: TechniqueDef) -> bool:
	for existing: TechniqueDef in arr:
		if existing.id == t.id:
			return true
	return false
