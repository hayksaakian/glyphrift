class_name PuzzleSequence
extends Control

## Puzzle: memorize a sequence of colored pillars, then repeat it.
## Animated playback highlights each pillar in order.
## Player gets 3 attempts. Wrong → lose an attempt. 0 attempts → fail.

signal puzzle_completed(success: bool, reward_type: String, reward_data: Variant)

var instant_mode: bool = false
var _correct_order: Array[int] = []
var _player_input: Array[int] = []
var _pillar_buttons: Array[Button] = []
var _started: bool = false
var _input_phase: bool = false
var _animating: bool = false
var _attempts_left: int = 3

const MAX_ATTEMPTS: int = 3

## Internal nodes
var _bg: ColorRect = null
var _title_label: Label = null
var _instruction_label: Label = null
var _sequence_display: Label = null
var _pillar_row: HBoxContainer = null
var _status_label: Label = null
var _attempts_label: Label = null
var _button_row: HBoxContainer = null
var _give_up_btn: Button = null
var _show_again_btn: Button = null

## Pillar colors
const PILLAR_COLORS: Array[Color] = [
	Color("#FF4444"),  ## Red
	Color("#44FF44"),  ## Green
	Color("#4488FF"),  ## Blue
	Color("#FFAA00"),  ## Orange
]

const PILLAR_DIM_COLORS: Array[Color] = [
	Color("#661111"),
	Color("#116611"),
	Color("#112266"),
	Color("#664400"),
]

const PILLAR_NAMES: Array[String] = ["Red", "Green", "Blue", "Orange"]


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
	_animating = false
	_player_input.clear()
	_attempts_left = MAX_ATTEMPTS

	## Generate random order (3-4 pillars)
	var count: int = 3 + (randi() % 2)
	_correct_order.clear()
	for i: int in range(count):
		_correct_order.append(randi() % _pillar_buttons.size())

	_update_attempts_label()
	_show_again_btn.visible = false
	_give_up_btn.visible = true
	_sequence_display.text = ""

	## Animate the sequence
	_play_sequence()


func start_with_order(order: Array[int], p_instant_mode: bool = true) -> void:
	## Deterministic start for testing
	instant_mode = p_instant_mode
	visible = true
	_started = true
	_correct_order = order.duplicate()
	_player_input.clear()
	_attempts_left = MAX_ATTEMPTS
	_animating = false
	_update_attempts_label()
	_show_again_btn.visible = false
	_give_up_btn.visible = true
	_sequence_display.text = ""
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
	vbox.add_theme_constant_override("separation", 12)
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

	## Sequence display: shows "Red → Blue → Orange" during memorize
	_sequence_display = Label.new()
	_sequence_display.add_theme_font_size_override("font_size", 16)
	_sequence_display.add_theme_color_override("font_color", Color("#FFFFFF"))
	_sequence_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_sequence_display)

	_pillar_row = HBoxContainer.new()
	_pillar_row.add_theme_constant_override("separation", 16)
	_pillar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_pillar_row)

	## Create 4 pillar buttons (start dimmed)
	for i: int in range(4):
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = PILLAR_DIM_COLORS[i]
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.border_color = PILLAR_COLORS[i].darkened(0.3)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.text = PILLAR_NAMES[i]
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_pillar_pressed(idx))
		_pillar_row.add_child(btn)
		_pillar_buttons.append(btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	_attempts_label = Label.new()
	_attempts_label.add_theme_font_size_override("font_size", 12)
	_attempts_label.add_theme_color_override("font_color", Color("#888888"))
	_attempts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_attempts_label)

	## Buttons row
	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 16)
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_button_row)

	_show_again_btn = Button.new()
	_show_again_btn.text = "Show Again"
	_show_again_btn.custom_minimum_size = Vector2(120, 36)
	_show_again_btn.visible = false
	_show_again_btn.pressed.connect(_on_show_again)
	_button_row.add_child(_show_again_btn)

	_give_up_btn = Button.new()
	_give_up_btn.text = "Give Up"
	_give_up_btn.custom_minimum_size = Vector2(120, 36)
	_give_up_btn.pressed.connect(_on_give_up)
	_button_row.add_child(_give_up_btn)


func _play_sequence() -> void:
	_animating = true
	_input_phase = false
	_instruction_label.text = "Watch the sequence..."
	_status_label.text = ""
	_show_again_btn.visible = false

	## Dim all pillars
	for i: int in range(_pillar_buttons.size()):
		_set_pillar_state(i, false)

	if instant_mode:
		## Show full sequence text immediately
		_show_sequence_text()
		_begin_input_phase()
		return

	## Animate: highlight each pillar in order
	_sequence_display.text = ""
	var tween: Tween = create_tween()
	for step: int in range(_correct_order.size()):
		var pillar_idx: int = _correct_order[step]
		## Light up
		tween.tween_callback(func() -> void:
			_set_pillar_state(pillar_idx, true)
			_update_sequence_text_up_to(step + 1)
		)
		tween.tween_interval(0.8)
		## Dim
		tween.tween_callback(func() -> void:
			_set_pillar_state(pillar_idx, false)
		)
		tween.tween_interval(0.3)

	## After animation, start input phase
	tween.tween_interval(0.5)
	tween.tween_callback(_begin_input_phase)


func _show_sequence_text() -> void:
	_update_sequence_text_up_to(_correct_order.size())


func _update_sequence_text_up_to(count: int) -> void:
	var parts: Array[String] = []
	for i: int in range(mini(count, _correct_order.size())):
		parts.append(PILLAR_NAMES[_correct_order[i]])
	_sequence_display.text = " → ".join(parts)


func _set_pillar_state(idx: int, lit: bool) -> void:
	if idx < 0 or idx >= _pillar_buttons.size():
		return
	var btn: Button = _pillar_buttons[idx]
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if lit:
		style.bg_color = PILLAR_COLORS[idx]
		style.border_color = Color.WHITE
	else:
		style.bg_color = PILLAR_DIM_COLORS[idx]
		style.border_color = PILLAR_COLORS[idx].darkened(0.3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _begin_input_phase() -> void:
	_animating = false
	_input_phase = true
	_player_input.clear()
	_instruction_label.text = "Now repeat the sequence!"
	_status_label.text = "0/%d" % _correct_order.size()
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_show_again_btn.visible = true

	## Dim all pillars for input
	for i: int in range(_pillar_buttons.size()):
		_set_pillar_state(i, false)


func _on_pillar_pressed(idx: int) -> void:
	if not _input_phase or _animating:
		return

	_player_input.append(idx)
	var pos: int = _player_input.size() - 1

	## Flash the pressed pillar
	_set_pillar_state(idx, true)
	if not instant_mode:
		var tween: Tween = create_tween()
		var captured_idx: int = idx
		tween.tween_interval(0.2)
		tween.tween_callback(func() -> void: _set_pillar_state(captured_idx, false))

	if _correct_order[pos] != idx:
		## Wrong — lose an attempt
		_attempts_left -= 1
		_player_input.clear()
		_update_attempts_label()

		if _attempts_left <= 0:
			## Failed!
			_input_phase = false
			_status_label.text = "Failed!"
			_status_label.add_theme_color_override("font_color", Color("#FF4444"))
			_instruction_label.text = "The pillars go dark..."
			_show_again_btn.visible = false
			_give_up_btn.visible = false
			_sequence_display.text = ""
			if not instant_mode:
				var tween2: Tween = create_tween()
				tween2.tween_interval(1.5)
				tween2.tween_callback(func() -> void: puzzle_completed.emit(false, "none", null))
			else:
				puzzle_completed.emit(false, "none", null)
		else:
			_status_label.text = "Wrong! %d attempt%s left. 0/%d" % [
				_attempts_left, "s" if _attempts_left != 1 else "", _correct_order.size()
			]
			_status_label.add_theme_color_override("font_color", Color("#FF4444"))
		return

	_status_label.text = "%d/%d" % [_player_input.size(), _correct_order.size()]
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))

	if _player_input.size() == _correct_order.size():
		## Correct!
		_input_phase = false
		_status_label.text = "Correct!"
		_status_label.add_theme_color_override("font_color", Color("#44FF44"))
		_instruction_label.text = "The pillars glow with energy!"
		_show_again_btn.visible = false
		_give_up_btn.visible = false
		_sequence_display.text = ""
		puzzle_completed.emit(true, "item", null)


func _on_show_again() -> void:
	if _animating or not _started:
		return
	_play_sequence()


func _on_give_up() -> void:
	_input_phase = false
	_started = false
	visible = false
	puzzle_completed.emit(false, "none", null)


func _update_attempts_label() -> void:
	_attempts_label.text = "Attempts: %d/%d" % [_attempts_left, MAX_ATTEMPTS]
	if _attempts_left <= 1:
		_attempts_label.add_theme_color_override("font_color", Color("#FF6666"))
	else:
		_attempts_label.add_theme_color_override("font_color", Color("#888888"))
