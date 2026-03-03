class_name PuzzleSequence
extends Control

## Puzzle: memorize a sequence of colored pillars, then repeat it.
## Shows inscription for 5s (0s in instant_mode), then hides.
## Player clicks pillars in order. Wrong → reset. Correct → reward.

signal puzzle_completed(success: bool, reward_type: String, reward_data: Variant)

var instant_mode: bool = false
var _correct_order: Array[int] = []
var _player_input: Array[int] = []
var _pillar_buttons: Array[Button] = []
var _started: bool = false
var _input_phase: bool = false

## Internal nodes
var _bg: ColorRect = null
var _title_label: Label = null
var _instruction_label: Label = null
var _pillar_row: HBoxContainer = null
var _status_label: Label = null

## Pillar colors
const PILLAR_COLORS: Array[Color] = [
	Color("#FF4444"),  ## Red
	Color("#44FF44"),  ## Green
	Color("#4488FF"),  ## Blue
	Color("#FFAA00"),  ## Orange
]

const PILLAR_SYMBOLS: Array[String] = ["I", "II", "III", "IV"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func start(p_instant_mode: bool = false) -> void:
	instant_mode = p_instant_mode
	visible = true
	_started = true
	_input_phase = false
	_player_input.clear()

	## Generate random order (3-4 pillars)
	var count: int = 3 + (randi() % 2)
	_correct_order.clear()
	for i: int in range(count):
		_correct_order.append(randi() % _pillar_buttons.size())

	## Show the inscription (correct order)
	_instruction_label.text = "Memorize the sequence..."
	_instruction_label.visible = true
	_highlight_sequence()

	if instant_mode:
		_begin_input_phase()
	else:
		## Show for 5 seconds, then hide
		var tween: Tween = create_tween()
		tween.tween_interval(5.0)
		tween.tween_callback(_begin_input_phase)


func start_with_order(order: Array[int], p_instant_mode: bool = true) -> void:
	## Deterministic start for testing
	instant_mode = p_instant_mode
	visible = true
	_started = true
	_correct_order = order.duplicate()
	_player_input.clear()
	_begin_input_phase()


func attempt_sequence(order: Array[int]) -> bool:
	## Direct test method — returns true if sequence matches
	_player_input.clear()
	for idx: int in order:
		_player_input.append(idx)
		if _player_input.size() <= _correct_order.size():
			if _correct_order[_player_input.size() - 1] != idx:
				_player_input.clear()
				return false
	return _player_input.size() == _correct_order.size()


func get_correct_order() -> Array[int]:
	return _correct_order


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0.85)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Glyph Sequence Puzzle"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_instruction_label = Label.new()
	_instruction_label.add_theme_font_size_override("font_size", 14)
	_instruction_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_instruction_label)

	_pillar_row = HBoxContainer.new()
	_pillar_row.add_theme_constant_override("separation", 16)
	_pillar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_pillar_row)

	## Create 4 pillar buttons
	for i: int in range(4):
		var btn: Button = Button.new()
		btn.text = PILLAR_SYMBOLS[i]
		btn.custom_minimum_size = Vector2(64, 64)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = PILLAR_COLORS[i]
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_pillar_pressed(idx))
		_pillar_row.add_child(btn)
		_pillar_buttons.append(btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)


func _highlight_sequence() -> void:
	## Visual: show order numbers on pillars
	for i: int in range(_correct_order.size()):
		var idx: int = _correct_order[i]
		if idx < _pillar_buttons.size():
			_pillar_buttons[idx].text = "%s [%d]" % [PILLAR_SYMBOLS[idx], i + 1]


func _begin_input_phase() -> void:
	_input_phase = true
	_player_input.clear()
	_instruction_label.text = "Repeat the sequence!"
	_status_label.text = "0/%d" % _correct_order.size()

	## Reset pillar labels
	for i: int in range(_pillar_buttons.size()):
		_pillar_buttons[i].text = PILLAR_SYMBOLS[i]


func _on_pillar_pressed(idx: int) -> void:
	if not _input_phase:
		return

	_player_input.append(idx)
	var pos: int = _player_input.size() - 1

	if _correct_order[pos] != idx:
		## Wrong — reset
		_player_input.clear()
		_status_label.text = "Wrong! Try again. 0/%d" % _correct_order.size()
		_status_label.add_theme_color_override("font_color", Color("#FF4444"))
		return

	_status_label.text = "%d/%d" % [_player_input.size(), _correct_order.size()]
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))

	if _player_input.size() == _correct_order.size():
		## Correct!
		_input_phase = false
		_status_label.text = "Correct!"
		_status_label.add_theme_color_override("font_color", Color("#44FF44"))
		puzzle_completed.emit(true, "item", null)
