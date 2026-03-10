class_name GlyphPortrait
extends VBoxContainer

## Portrait for turn bar + formation slots.
## Colored square with species initial, name label below, side-colored border.

signal clicked(glyph: GlyphInstance)


var glyph: GlyphInstance = null
var _highlighted: bool = false
var portrait_size: int = 32  ## Set before adding to tree for custom size

## Turn queue clarity: SPD + stun skip + arrow
var show_stun_skip: bool = false:
	set(value):
		show_stun_skip = value
		if _skip_label:
			_skip_label.visible = value
var spd_value: int = 0  ## Effective SPD for tooltip
var spd_modified: bool = false  ## True when slow status active
var show_spd_tooltip: bool = false:
	set(value):
		show_spd_tooltip = value
		if _spd_tooltip:
			_spd_tooltip.visible = value

var _color_rect: ColorRect = null
var _initial_label: Label = null
var _name_label: Label = null
var _border: Panel = null
var _square: PanelContainer = null
var _highlight_border: Panel = null
var _spd_badge: Label = null
var _spd_tooltip: Label = null
var _skip_label: Label = null
var _arrow_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 2)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_build_ui()
	if glyph != null:
		refresh()


func setup(p_glyph: GlyphInstance) -> void:
	glyph = p_glyph
	if is_inside_tree():
		refresh()


func refresh() -> void:
	if glyph == null:
		return

	var aff: String = glyph.species.affinity if glyph.species else "neutral"
	_color_rect.color = Affinity.COLORS.get(aff, Affinity.COLORS["neutral"])
	_initial_label.text = glyph.species.name[0].to_upper() if glyph.species else "?"
	_name_label.text = glyph.species.name if glyph.species else "?"
	GlyphArt.apply_texture(_square, _color_rect, _initial_label, glyph.species.id if glyph.species else "", portrait_size)

	## Side border color
	var border_style: StyleBoxFlat = _border.get_theme_stylebox("panel") as StyleBoxFlat
	if border_style:
		if glyph.side == "player":
			border_style.border_color = Color("#4488FF")
		else:
			border_style.border_color = Color("#FF4444")

	## KO modulate
	if glyph.is_knocked_out:
		modulate = Color(0.4, 0.4, 0.4, 0.7)
	else:
		modulate = Color.WHITE

	## SPD badge: show only when speed is modified (slow status)
	if _spd_badge:
		_spd_badge.visible = spd_modified
	if _spd_tooltip:
		_spd_tooltip.text = "SPD %d" % spd_value
		_spd_tooltip.visible = show_spd_tooltip


func set_highlighted(active: bool) -> void:
	_highlighted = active
	if not is_inside_tree():
		return
	if active:
		var hl_size: int = portrait_size + 8
		_square.custom_minimum_size = Vector2(hl_size, hl_size)
		_highlight_border.visible = true
	else:
		_square.custom_minimum_size = Vector2(portrait_size, portrait_size)
		_highlight_border.visible = false
	if _arrow_label:
		_arrow_label.visible = active


func _build_ui() -> void:
	## Arrow marker: "▶" above portrait for active turn (in VBoxContainer, before square)
	_arrow_label = Label.new()
	_arrow_label.text = "\u25b6"
	_arrow_label.add_theme_font_size_override("font_size", maxi(8, int(portrait_size * 0.35)))
	_arrow_label.add_theme_color_override("font_color", Color("#FFDD44"))
	_arrow_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_arrow_label.add_theme_constant_override("outline_size", 2)
	_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_label.visible = false
	_arrow_label.custom_minimum_size = Vector2(0, maxi(10, int(portrait_size * 0.4)))
	add_child(_arrow_label)

	## Colored square container
	_square = PanelContainer.new()
	_square.custom_minimum_size = Vector2(portrait_size, portrait_size)
	_square.mouse_filter = Control.MOUSE_FILTER_PASS
	var square_style: StyleBoxFlat = StyleBoxFlat.new()
	square_style.bg_color = Color(0, 0, 0, 0)
	_square.add_theme_stylebox_override("panel", square_style)
	add_child(_square)

	## Background color fill
	_color_rect = ColorRect.new()
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_color_rect.color = Affinity.COLORS["neutral"]
	_square.add_child(_color_rect)

	## Initial letter centered in square
	_initial_label = Label.new()
	_initial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initial_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_initial_label.add_theme_font_size_override("font_size", maxi(10, int(portrait_size * 0.5)))
	_initial_label.add_theme_color_override("font_color", Color.WHITE)
	_initial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_initial_label.add_theme_constant_override("outline_size", 3)
	_square.add_child(_initial_label)

	## Side border overlay on square
	_border = Panel.new()
	_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style: StyleBoxFlat = StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = Color("#4488FF")
	border_style.border_width_left = 2
	border_style.border_width_right = 2
	border_style.border_width_top = 2
	border_style.border_width_bottom = 2
	_border.add_theme_stylebox_override("panel", border_style)
	_square.add_child(_border)

	## Active-turn highlight border (white, 4px, hidden by default)
	_highlight_border = Panel.new()
	_highlight_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_highlight_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_border.visible = false
	var hl_style: StyleBoxFlat = StyleBoxFlat.new()
	hl_style.bg_color = Color(0, 0, 0, 0)
	hl_style.border_color = Color.WHITE
	hl_style.border_width_left = 4
	hl_style.border_width_right = 4
	hl_style.border_width_top = 4
	hl_style.border_width_bottom = 4
	_highlight_border.add_theme_stylebox_override("panel", hl_style)
	_square.add_child(_highlight_border)

	## SPD badge: small "▼" shown when slow status active
	_spd_badge = Label.new()
	_spd_badge.text = "\u25bc"
	_spd_badge.add_theme_font_size_override("font_size", maxi(8, int(portrait_size * 0.3)))
	_spd_badge.add_theme_color_override("font_color", Color("#FF4444"))
	_spd_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_spd_badge.add_theme_constant_override("outline_size", 2)
	_spd_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_spd_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_spd_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_spd_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spd_badge.visible = false
	_square.add_child(_spd_badge)

	## Stun skip overlay: "SKIP" centered in red
	_skip_label = Label.new()
	_skip_label.text = "SKIP"
	_skip_label.add_theme_font_size_override("font_size", maxi(8, int(portrait_size * 0.35)))
	_skip_label.add_theme_color_override("font_color", Color("#FF4444"))
	_skip_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_skip_label.add_theme_constant_override("outline_size", 3)
	_skip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_label.visible = false
	_square.add_child(_skip_label)

	## Name label below the square
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	var label_width: int = maxi(portrait_size, int(portrait_size * 1.6))
	_name_label.custom_minimum_size = Vector2(label_width, 0)
	_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_name_label.add_theme_font_size_override("font_size", maxi(9, int(portrait_size * 0.3)))
	_name_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	add_child(_name_label)

	## SPD tooltip: "SPD 12" shown below name on highlight
	_spd_tooltip = Label.new()
	_spd_tooltip.text = "SPD 0"
	_spd_tooltip.add_theme_font_size_override("font_size", maxi(8, int(portrait_size * 0.28)))
	_spd_tooltip.add_theme_color_override("font_color", Color("#AACCFF"))
	_spd_tooltip.add_theme_color_override("font_outline_color", Color.BLACK)
	_spd_tooltip.add_theme_constant_override("outline_size", 2)
	_spd_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spd_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spd_tooltip.visible = false
	add_child(_spd_tooltip)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(glyph)
