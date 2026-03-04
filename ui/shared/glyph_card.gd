class_name GlyphCard
extends Control

## Compact 120x160 glyph display used across Barracks, Fusion, and squad views.

signal card_clicked(glyph: GlyphInstance)
signal info_pressed(glyph: GlyphInstance)


var glyph: GlyphInstance = null

## Visual states
var selected: bool = false:
	set(value):
		selected = value
		_update_border()
var disabled_state: bool = false:
	set(value):
		disabled_state = value
		_update_modulate()

## Internal nodes
var _bg: PanelContainer = null
var _vbox: VBoxContainer = null
var _affinity_rect: ColorRect = null
var _initial_label: Label = null
var _art_panel: PanelContainer = null
var _name_label: Label = null
var _info_label: Label = null
var _gp_label: Label = null
var _stats_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _hp_row: HBoxContainer = null
var _mastery_bar: ProgressBar = null
var _mastery_check: Label = null
var _mastery_count: Label = null
var _mastery_row: HBoxContainer = null
var _info_button: Button = null
var _select_border: Panel = null

## When true, show a small "i" info button on the card
var show_info_button: bool = false:
	set(value):
		show_info_button = value
		if _info_button != null:
			_info_button.visible = value


func _ready() -> void:
	custom_minimum_size = Vector2(120, 160)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	if glyph != null:
		refresh()


func setup(p_glyph: GlyphInstance) -> void:
	glyph = p_glyph
	if is_inside_tree():
		refresh()


func refresh() -> void:
	if glyph == null or glyph.species == null:
		return

	var sp: GlyphSpecies = glyph.species
	var aff: String = sp.affinity
	var aff_color: Color = Affinity.COLORS.get(aff, Affinity.COLORS["neutral"])

	## Art placeholder
	_affinity_rect.color = aff_color
	_initial_label.text = sp.name[0].to_upper()
	GlyphArt.apply_texture(_art_panel, _affinity_rect, _initial_label, sp.id, 60)

	## Text labels
	_name_label.text = sp.name
	_info_label.text = "%s %s T%d" % [Affinity.EMOJI.get(aff, ""), aff.capitalize(), sp.tier]
	_gp_label.text = "GP: %d" % sp.gp_cost
	_stats_label.text = "HP:%d ATK:%d" % [glyph.max_hp, glyph.atk]

	## HP bar
	_hp_bar.max_value = glyph.max_hp
	_hp_bar.value = glyph.current_hp
	_hp_label.text = "%d/%d" % [glyph.current_hp, glyph.max_hp]
	var hp_pct: float = float(glyph.current_hp) / maxf(float(glyph.max_hp), 1.0)
	var hp_fill: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if hp_fill != null:
		if hp_pct > 0.5:
			hp_fill.bg_color = Color("#4CAF50")
		elif hp_pct > 0.25:
			hp_fill.bg_color = Color("#FFC107")
		else:
			hp_fill.bg_color = Color("#F44336")

	## Mastery bar
	var total: int = glyph.mastery_objectives.size()
	var completed: int = 0
	for obj: Dictionary in glyph.mastery_objectives:
		if obj.get("completed", false):
			completed += 1

	if total == 0:
		_mastery_row.visible = false
	else:
		_mastery_row.visible = true
		_mastery_bar.max_value = total
		_mastery_bar.value = completed
		_mastery_count.text = "%d/%d" % [completed, total]
		if glyph.is_mastered:
			_mastery_check.visible = true
			_mastery_check.text = " \u2713"
			_mastery_count.add_theme_color_override("font_color", Color("#4CAF50"))
		else:
			_mastery_check.visible = false
			_mastery_count.add_theme_color_override("font_color", Color("#888888"))

	_update_modulate()
	_update_border()


func _build_ui() -> void:
	## Background panel
	_bg = PanelContainer.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color("#1A1A2E")
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_bg)

	## Main VBox
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 2)
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_bg.add_child(_vbox)

	## Affinity colored art placeholder (60x60 centered)
	var art_container: CenterContainer = CenterContainer.new()
	art_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(art_container)

	_art_panel = PanelContainer.new()
	var art_panel: PanelContainer = _art_panel
	art_panel.custom_minimum_size = Vector2(60, 60)
	art_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	art_container.add_child(art_panel)

	_affinity_rect = ColorRect.new()
	_affinity_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_affinity_rect.color = Affinity.COLORS["neutral"]
	_affinity_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	art_panel.add_child(_affinity_rect)

	_initial_label = Label.new()
	_initial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initial_label.add_theme_font_size_override("font_size", 24)
	_initial_label.add_theme_color_override("font_color", Color.WHITE)
	_initial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_initial_label.add_theme_constant_override("outline_size", 3)
	_initial_label.mouse_filter = Control.MOUSE_FILTER_PASS
	art_panel.add_child(_initial_label)

	## Species name
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_name_label)

	## Affinity + tier
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 10)
	_info_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_info_label)

	## GP cost
	_gp_label = Label.new()
	_gp_label.add_theme_font_size_override("font_size", 10)
	_gp_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_gp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gp_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_gp_label)

	## Stats (HP, ATK)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 10)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_stats_label)

	## HP bar row
	_hp_row = HBoxContainer.new()
	_hp_row.add_theme_constant_override("separation", 3)
	_hp_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_hp_row)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 10)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.show_percentage = false
	var hp_fill_style: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill_style.bg_color = Color("#4CAF50")
	hp_fill_style.corner_radius_top_left = 2
	hp_fill_style.corner_radius_top_right = 2
	hp_fill_style.corner_radius_bottom_left = 2
	hp_fill_style.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", hp_fill_style)
	var hp_bg_style: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg_style.bg_color = Color("#333333")
	hp_bg_style.corner_radius_top_left = 2
	hp_bg_style.corner_radius_top_right = 2
	hp_bg_style.corner_radius_bottom_left = 2
	hp_bg_style.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("background", hp_bg_style)
	_hp_row.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 8)
	_hp_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_hp_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_hp_row.add_child(_hp_label)

	## Mastery row (label + bar + checkmark)
	_mastery_row = HBoxContainer.new()
	_mastery_row.add_theme_constant_override("separation", 2)
	_mastery_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_mastery_row)

	var mastery_label: Label = Label.new()
	mastery_label.text = "M:"
	mastery_label.add_theme_font_size_override("font_size", 8)
	mastery_label.add_theme_color_override("font_color", Color("#666666"))
	mastery_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_mastery_row.add_child(mastery_label)

	_mastery_bar = ProgressBar.new()
	_mastery_bar.custom_minimum_size = Vector2(0, 10)
	_mastery_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mastery_bar.show_percentage = false
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color("#4CAF50")
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	_mastery_bar.add_theme_stylebox_override("fill", fill_style)
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color("#333333")
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	_mastery_bar.add_theme_stylebox_override("background", bar_bg)
	_mastery_row.add_child(_mastery_bar)

	_mastery_count = Label.new()
	_mastery_count.add_theme_font_size_override("font_size", 8)
	_mastery_count.add_theme_color_override("font_color", Color("#888888"))
	_mastery_count.mouse_filter = Control.MOUSE_FILTER_PASS
	_mastery_row.add_child(_mastery_count)

	_mastery_check = Label.new()
	_mastery_check.add_theme_font_size_override("font_size", 12)
	_mastery_check.add_theme_color_override("font_color", Color("#4CAF50"))
	_mastery_check.visible = false
	_mastery_check.mouse_filter = Control.MOUSE_FILTER_PASS
	_mastery_row.add_child(_mastery_check)

	## Info button (hidden by default, used in Barracks)
	_info_button = Button.new()
	_info_button.text = "i"
	_info_button.custom_minimum_size = Vector2(22, 22)
	_info_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_button.offset_left = -26.0
	_info_button.offset_top = 4.0
	_info_button.offset_right = -4.0
	_info_button.offset_bottom = 26.0
	_info_button.visible = show_info_button
	_info_button.pressed.connect(func() -> void:
		if glyph != null:
			info_pressed.emit(glyph)
	)
	add_child(_info_button)

	## Selection border overlay
	_select_border = Panel.new()
	_select_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_select_border.visible = false
	_select_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sel_style: StyleBoxFlat = StyleBoxFlat.new()
	sel_style.bg_color = Color(0, 0, 0, 0)
	sel_style.border_color = Color("#FFD700")
	sel_style.border_width_left = 3
	sel_style.border_width_right = 3
	sel_style.border_width_top = 3
	sel_style.border_width_bottom = 3
	sel_style.corner_radius_top_left = 6
	sel_style.corner_radius_top_right = 6
	sel_style.corner_radius_bottom_left = 6
	sel_style.corner_radius_bottom_right = 6
	_select_border.add_theme_stylebox_override("panel", sel_style)
	add_child(_select_border)


func _update_border() -> void:
	if _select_border != null:
		_select_border.visible = selected


func _update_modulate() -> void:
	if disabled_state:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(glyph)
