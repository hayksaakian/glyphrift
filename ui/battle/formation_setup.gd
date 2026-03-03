class_name FormationSetup
extends Control

## Row assignment UI — front/back slots, click to reassign, confirm button.
## Default: first 2 glyphs front, rest back.

signal formation_confirmed(positions: Dictionary)

var _squad: Array[GlyphInstance] = []
var _positions: Dictionary = {}  ## instance_id → "front" or "back"

var _front_row: HBoxContainer = null
var _back_row: HBoxContainer = null
var _confirm_button: Button = null
var _title_label: Label = null
var _bg: ColorRect = null
var _portraits: Dictionary = {}  ## instance_id → GlyphPortrait


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func show_formation(squad: Array[GlyphInstance]) -> void:
	_squad = squad
	_positions.clear()
	_portraits.clear()
	visible = true

	## Default positions: first 2 front, rest back
	var front_count: int = 0
	for g: GlyphInstance in _squad:
		if front_count < 2:
			_positions[g.instance_id] = "front"
			front_count += 1
		else:
			_positions[g.instance_id] = "back"

	_rebuild_slots()


func hide_formation() -> void:
	visible = false


func get_positions() -> Dictionary:
	return _positions.duplicate()


func _build_ui() -> void:
	## Opaque background to cover battlefield
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color("#0D1117")
	add_child(_bg)

	## CenterContainer fills parent, centers VBox inside
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Assign Formation"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	vbox.add_child(_title_label)

	## Hint
	var hint: Label = Label.new()
	hint.text = "Click a glyph to move between rows"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("#888888"))
	vbox.add_child(hint)

	## Front row label + slots
	var front_label: Label = Label.new()
	front_label.text = "Front Row"
	front_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	front_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(front_label)

	_front_row = HBoxContainer.new()
	_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_front_row.add_theme_constant_override("separation", 16)
	vbox.add_child(_front_row)

	## Back row label + slots
	var back_label: Label = Label.new()
	back_label.text = "Back Row"
	back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(back_label)

	_back_row = HBoxContainer.new()
	_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_back_row.add_theme_constant_override("separation", 16)
	vbox.add_child(_back_row)

	## Confirm button
	_confirm_button = Button.new()
	_confirm_button.text = "Confirm Formation"
	_confirm_button.custom_minimum_size = Vector2(240, 48)
	_confirm_button.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_button)


func _rebuild_slots() -> void:
	## Clear existing portraits — remove_child before queue_free for immediate removal
	for child: Node in _front_row.get_children():
		_front_row.remove_child(child)
		child.queue_free()
	for child: Node in _back_row.get_children():
		_back_row.remove_child(child)
		child.queue_free()
	_portraits.clear()

	for g: GlyphInstance in _squad:
		var portrait: GlyphPortrait = GlyphPortrait.new()
		portrait.glyph = g
		portrait.clicked.connect(_on_portrait_clicked)
		_portraits[g.instance_id] = portrait

		if _positions.get(g.instance_id, "front") == "front":
			_front_row.add_child(portrait)
		else:
			_back_row.add_child(portrait)


func _on_portrait_clicked(glyph: GlyphInstance) -> void:
	## Toggle between front and back
	var current: String = _positions.get(glyph.instance_id, "front")
	_positions[glyph.instance_id] = "back" if current == "front" else "front"
	_rebuild_slots()


func _on_confirm() -> void:
	formation_confirmed.emit(_positions.duplicate())
