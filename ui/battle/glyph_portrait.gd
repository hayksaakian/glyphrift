class_name GlyphPortrait
extends VBoxContainer

## Portrait for turn bar + formation slots.
## Colored square with species initial, name label below, side-colored border.

signal clicked(glyph: GlyphInstance)

const AFFINITY_COLORS: Dictionary = {
	"electric": Color("#FFD700"),
	"ground": Color("#4CAF50"),
	"water": Color("#00ACC1"),
	"neutral": Color("#888888"),
}

var glyph: GlyphInstance = null
var _highlighted: bool = false

var _color_rect: ColorRect = null
var _initial_label: Label = null
var _name_label: Label = null
var _border: Panel = null
var _square: PanelContainer = null
var _highlight_border: Panel = null


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
	_color_rect.color = AFFINITY_COLORS.get(aff, AFFINITY_COLORS["neutral"])
	_initial_label.text = glyph.species.name[0].to_upper() if glyph.species else "?"
	_name_label.text = glyph.species.name if glyph.species else "?"

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


func set_highlighted(active: bool) -> void:
	_highlighted = active
	if not is_inside_tree():
		return
	if active:
		_square.custom_minimum_size = Vector2(80, 80)
		_highlight_border.visible = true
	else:
		_square.custom_minimum_size = Vector2(64, 64)
		_highlight_border.visible = false


func _build_ui() -> void:
	## Colored square container
	_square = PanelContainer.new()
	_square.custom_minimum_size = Vector2(64, 64)
	_square.mouse_filter = Control.MOUSE_FILTER_PASS
	var square_style: StyleBoxFlat = StyleBoxFlat.new()
	square_style.bg_color = Color(0, 0, 0, 0)
	_square.add_theme_stylebox_override("panel", square_style)
	add_child(_square)

	## Background color fill
	_color_rect = ColorRect.new()
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_color_rect.color = AFFINITY_COLORS["neutral"]
	_square.add_child(_color_rect)

	## Initial letter centered in square
	_initial_label = Label.new()
	_initial_label.set_anchors_preset(Control.PRESET_CENTER)
	_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initial_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_initial_label.add_theme_font_size_override("font_size", 26)
	_initial_label.add_theme_color_override("font_color", Color.WHITE)
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

	## Name label below the square
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	add_child(_name_label)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(glyph)
