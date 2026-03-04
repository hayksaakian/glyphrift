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
var _picker_container: VBoxContainer = null
var _mastered_grid: HFlowContainer = null
var _unmastered_grid: HFlowContainer = null
var _divider_label: Label = null
var _picker_label: Label = null
var _preview_panel: VBoxContainer = null
var _preview_art_container: CenterContainer = null
var _preview_art_rect: ColorRect = null
var _preview_art_label: Label = null
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

## Technique button formatting (same as TechniqueButton)
const _RANGE_TAGS: Dictionary = {
	"melee": "M",
	"ranged": "R",
	"aoe": "AoE",
	"piercing": "P",
}


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

	## Sort glyphs into mastered and unmastered groups
	var mastered_glyphs: Array[GlyphInstance] = []
	var unmastered_glyphs: Array[GlyphInstance] = []
	for g: GlyphInstance in roster_state.all_glyphs:
		if g.is_mastered:
			mastered_glyphs.append(g)
		else:
			unmastered_glyphs.append(g)

	## Populate mastered grid
	for g: GlyphInstance in mastered_glyphs:
		var card: GlyphCard = GlyphCard.new()
		card.setup(g)
		card.card_clicked.connect(_on_picker_clicked)
		_mastered_grid.add_child(card)
		_picker_cards.append(card)

	## Show/hide divider and unmastered section
	_divider_label.visible = not unmastered_glyphs.is_empty()
	_unmastered_grid.visible = not unmastered_glyphs.is_empty()

	## Populate unmastered grid
	for g: GlyphInstance in unmastered_glyphs:
		var card: GlyphCard = GlyphCard.new()
		card.setup(g)
		card.disabled_state = true
		card.card_clicked.connect(_on_picker_clicked)
		_unmastered_grid.add_child(card)
		_picker_cards.append(card)


func _build_ui() -> void:
	## Background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	## Outer margin container
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	## Two-column layout: parents+preview (left) | picker grid (right)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	main_vbox.add_child(columns)

	## Left column: styled panel with parents + preview + buttons (shrink to content)
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_style: StyleBoxFlat = StyleBoxFlat.new()
	left_style.bg_color = Color(0.10, 0.10, 0.14)
	left_style.border_color = Color(0.3, 0.3, 0.4)
	left_style.set_border_width_all(1)
	left_style.set_corner_radius_all(6)
	left_style.set_content_margin_all(12)
	left_panel.add_theme_stylebox_override("panel", left_style)
	columns.add_child(left_panel)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(left_scroll)

	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 10)
	left_scroll.add_child(left_col)

	## Parent slots row
	var parent_row: HBoxContainer = HBoxContainer.new()
	parent_row.add_theme_constant_override("separation", 20)
	parent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_child(parent_row)

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
	left_col.add_child(_error_label)

	## Preview panel
	_preview_panel = VBoxContainer.new()
	_preview_panel.add_theme_constant_override("separation", 4)
	_preview_panel.visible = false
	left_col.add_child(_preview_panel)

	var preview_header: Label = Label.new()
	preview_header.text = "-- Preview --"
	preview_header.add_theme_font_size_override("font_size", 14)
	preview_header.add_theme_color_override("font_color", Color("#AAAAAA"))
	preview_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_panel.add_child(preview_header)

	## Preview art (64x64) — silhouette if undiscovered
	_preview_art_container = CenterContainer.new()
	_preview_art_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_panel.add_child(_preview_art_container)

	_preview_art_rect = ColorRect.new()
	_preview_art_rect.custom_minimum_size = Vector2(64, 64)
	_preview_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_art_rect.color = Color("#333333")
	_preview_art_container.add_child(_preview_art_rect)

	_preview_art_label = Label.new()
	_preview_art_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_art_label.add_theme_font_size_override("font_size", 28)
	_preview_art_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_preview_art_label.add_theme_constant_override("outline_size", 3)
	_preview_art_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_art_rect.add_child(_preview_art_label)

	_preview_name = Label.new()
	_preview_name.add_theme_font_size_override("font_size", 16)
	_preview_panel.add_child(_preview_name)

	_preview_stats = Label.new()
	_preview_stats.add_theme_font_size_override("font_size", 12)
	_preview_panel.add_child(_preview_stats)

	_preview_gp = Label.new()
	_preview_gp.add_theme_font_size_override("font_size", 12)
	_preview_panel.add_child(_preview_gp)

	_gp_warning = Label.new()
	_gp_warning.text = "\u26a0 Over capacity!"
	_gp_warning.add_theme_font_size_override("font_size", 12)
	_gp_warning.add_theme_color_override("font_color", Color("#FFC107"))
	_gp_warning.visible = false
	_preview_panel.add_child(_gp_warning)

	var tech_header: Label = Label.new()
	tech_header.text = "Inherit techniques:"
	tech_header.add_theme_font_size_override("font_size", 12)
	tech_header.add_theme_color_override("font_color", Color("#AAAAAA"))
	_preview_panel.add_child(tech_header)

	_technique_container = VBoxContainer.new()
	_technique_container.add_theme_constant_override("separation", 2)
	_preview_panel.add_child(_technique_container)

	## Fuse button
	_fuse_button = Button.new()
	_fuse_button.text = "Fuse!"
	_fuse_button.custom_minimum_size = Vector2(200, 36)
	_fuse_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fuse_button.visible = false
	_fuse_button.pressed.connect(_on_fuse_pressed)
	left_col.add_child(_fuse_button)

	## Right column: styled panel with picker grid
	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	var right_style: StyleBoxFlat = StyleBoxFlat.new()
	right_style.bg_color = Color(0.10, 0.10, 0.14)
	right_style.border_color = Color(0.3, 0.3, 0.4)
	right_style.set_border_width_all(1)
	right_style.set_corner_radius_all(6)
	right_style.set_content_margin_all(6)
	right_panel.add_theme_stylebox_override("panel", right_style)
	columns.add_child(right_panel)

	var right_col: VBoxContainer = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_col)

	_picker_label = Label.new()
	_picker_label.text = "Available Glyphs (mastered)"
	_picker_label.add_theme_font_size_override("font_size", 14)
	_picker_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_picker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(_picker_label)

	var picker_scroll: ScrollContainer = ScrollContainer.new()
	picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(picker_scroll)

	_picker_container = VBoxContainer.new()
	_picker_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_container.add_theme_constant_override("separation", 8)
	picker_scroll.add_child(_picker_container)

	_mastered_grid = HFlowContainer.new()
	_mastered_grid.add_theme_constant_override("h_separation", 8)
	_mastered_grid.add_theme_constant_override("v_separation", 8)
	_mastered_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_container.add_child(_mastered_grid)

	_divider_label = Label.new()
	_divider_label.text = "Not Ready — Needs Mastery"
	_divider_label.add_theme_font_size_override("font_size", 11)
	_divider_label.add_theme_color_override("font_color", Color("#666677"))
	_divider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_divider_label.visible = false
	_picker_container.add_child(_divider_label)

	_unmastered_grid = HFlowContainer.new()
	_unmastered_grid.add_theme_constant_override("h_separation", 8)
	_unmastered_grid.add_theme_constant_override("v_separation", 8)
	_unmastered_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unmastered_grid.visible = false
	_picker_container.add_child(_unmastered_grid)

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

	## Update preview art
	var species_id: String = preview["result_species_id"]
	var is_discovered: bool = preview["is_discovered"]
	var aff_color: Color = Affinity.COLORS.get(aff, Affinity.COLORS["neutral"])
	if is_discovered:
		_preview_art_rect.color = aff_color
		_preview_art_label.text = name_text[0].to_upper()
		_preview_art_label.add_theme_color_override("font_color", Color.WHITE)
		GlyphArt.apply_texture(_preview_art_rect, _preview_art_rect, _preview_art_label, species_id, 64)
	else:
		_preview_art_rect.color = Color("#333333")
		_preview_art_label.text = "?"
		_preview_art_label.add_theme_color_override("font_color", Color("#666666"))
		GlyphArt.apply_texture(_preview_art_rect, _preview_art_rect, _preview_art_label, species_id, 64, true)

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
		btn.text = _format_technique_text(tech)
		btn.custom_minimum_size = Vector2(200, 28)
		btn.toggle_mode = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tech_color: Color = Affinity.COLORS.get(tech.affinity, Color.WHITE)
		btn.add_theme_color_override("font_color", tech_color)
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
	for child: Node in _mastered_grid.get_children():
		_mastered_grid.remove_child(child)
		child.queue_free()
	for child: Node in _unmastered_grid.get_children():
		_unmastered_grid.remove_child(child)
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


func _format_technique_text(tech: TechniqueDef) -> String:
	var aff_tag: String = Affinity.EMOJI.get(tech.affinity, "?")
	var range_tag: String = _RANGE_TAGS.get(tech.range_type, "?")
	if tech.power > 0:
		return "%s %s  %s  Pw:%d" % [aff_tag, tech.name, range_tag, tech.power]
	elif tech.category == "support":
		return "%s %s  %s" % [aff_tag, tech.name, tech.support_effect.capitalize()]
	else:
		return "%s %s  %s" % [aff_tag, tech.name, range_tag]
