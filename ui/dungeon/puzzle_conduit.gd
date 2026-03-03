class_name PuzzleConduit
extends Control

## Puzzle: connect three affinity nodes in the correct cycle.
## Correct cycle: Electric → Water → Ground → Electric.
## Hint: "Each element flows into what it's strong against."
## 3 attempts max. Give Up option.

signal puzzle_completed(success: bool, reward_type: String, reward_data: Variant)

var instant_mode: bool = false
var _connections: Array[Array] = []
var _selected_node: int = -1
var _started: bool = false
var _completed: bool = false
var _attempts_left: int = 3

const MAX_ATTEMPTS: int = 3

## Node buttons
var _node_buttons: Array[Button] = []

## Internal nodes
var _bg: ColorRect = null
var _title_label: Label = null
var _instruction_label: Label = null
var _hint_label: Label = null
var _node_container: Control = null
var _connections_label: Label = null
var _status_label: Label = null
var _attempts_label: Label = null
var _button_row: HBoxContainer = null
var _give_up_btn: Button = null
var _reset_btn: Button = null

## The three affinities in cycle order
const AFFINITIES: Array[String] = ["electric", "water", "ground"]
## Correct connections: E→W, W→G, G→E (indices: 0→1, 1→2, 2→0)
const CORRECT_CYCLE: Array[Array] = [[0, 1], [1, 2], [2, 0]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func start(p_instant_mode: bool = false) -> void:
	instant_mode = p_instant_mode
	visible = true
	_started = true
	_completed = false
	_connections.clear()
	_selected_node = -1
	_attempts_left = MAX_ATTEMPTS
	_instruction_label.text = "Connect the conduits to form a cycle."
	_status_label.text = "Select a node to begin."
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_connections_label.text = ""
	_update_attempts_label()
	_give_up_btn.visible = true
	_reset_btn.visible = false
	_reset_node_highlights()


func attempt_connections(connections: Array[Array]) -> bool:
	## Direct test method — returns true if connections form the correct cycle
	if connections.size() != 3:
		return false
	for required: Array in CORRECT_CYCLE:
		var found: bool = false
		for conn: Array in connections:
			if (conn[0] == required[0] and conn[1] == required[1]) or \
				(conn[0] == required[1] and conn[1] == required[0]):
				found = true
				break
		if not found:
			return false
	return true


func get_connections() -> Array[Array]:
	return _connections


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
	_title_label.text = "Conduit Puzzle"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_instruction_label = Label.new()
	_instruction_label.add_theme_font_size_override("font_size", 14)
	_instruction_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_instruction_label)

	_hint_label = Label.new()
	_hint_label.text = "Hint: Each element flows into what it's strong against."
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color("#666688"))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hint_label)

	## Node container
	_node_container = HBoxContainer.new()
	(_node_container as HBoxContainer).add_theme_constant_override("separation", 40)
	(_node_container as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_node_container)

	for i: int in range(3):
		var aff: String = AFFINITIES[i]
		var aff_color: Color = Affinity.COLORS.get(aff, Color("#888888"))
		var emoji: String = Affinity.EMOJI.get(aff, "")

		var btn: Button = Button.new()
		btn.text = "%s %s" % [emoji, aff.capitalize()]
		btn.custom_minimum_size = Vector2(100, 60)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = aff_color.darkened(0.3)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.border_color = aff_color
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_node_pressed(idx))
		_node_container.add_child(btn)
		_node_buttons.append(btn)

	## Connection display
	_connections_label = Label.new()
	_connections_label.add_theme_font_size_override("font_size", 14)
	_connections_label.add_theme_color_override("font_color", Color("#88AACC"))
	_connections_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_connections_label)

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

	_reset_btn = Button.new()
	_reset_btn.text = "Reset Connections"
	_reset_btn.custom_minimum_size = Vector2(140, 36)
	_reset_btn.visible = false
	_reset_btn.pressed.connect(_on_reset)
	_button_row.add_child(_reset_btn)

	_give_up_btn = Button.new()
	_give_up_btn.text = "Give Up"
	_give_up_btn.custom_minimum_size = Vector2(120, 36)
	_give_up_btn.pressed.connect(_on_give_up)
	_button_row.add_child(_give_up_btn)


func _on_node_pressed(idx: int) -> void:
	if _completed or not _started:
		return

	if _selected_node == -1:
		## Select first node
		_selected_node = idx
		_status_label.text = "%s selected — click another to connect." % AFFINITIES[idx].capitalize()
		_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		_highlight_node(idx, true)
	elif _selected_node == idx:
		## Deselect
		_selected_node = -1
		_status_label.text = "Select a node to begin."
		_reset_node_highlights()
	else:
		## Connect selected to this node
		var conn: Array = [_selected_node, idx]
		_connections.append(conn)
		_selected_node = -1
		_reset_node_highlights()
		_update_connections_display()
		_reset_btn.visible = true

		_status_label.text = "%d/3 connections made." % _connections.size()
		_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))

		if _connections.size() == 3:
			## Check if correct
			if attempt_connections(_connections):
				_completed = true
				_status_label.text = "Conduit activated!"
				_status_label.add_theme_color_override("font_color", Color("#44FF44"))
				_connections_label.add_theme_color_override("font_color", Color("#44FF44"))
				_give_up_btn.visible = false
				_reset_btn.visible = false
				puzzle_completed.emit(true, "codex_reveal", null)
			else:
				## Wrong — lose an attempt
				_attempts_left -= 1
				_update_attempts_label()

				if _attempts_left <= 0:
					## Failed
					_completed = true
					_status_label.text = "Failed!"
					_status_label.add_theme_color_override("font_color", Color("#FF4444"))
					_connections_label.text = ""
					_give_up_btn.visible = false
					_reset_btn.visible = false
					if not instant_mode:
						var tween: Tween = create_tween()
						tween.tween_interval(1.5)
						tween.tween_callback(func() -> void: puzzle_completed.emit(false, "none", null))
					else:
						puzzle_completed.emit(false, "none", null)
				else:
					_connections.clear()
					_status_label.text = "Wrong cycle! %d attempt%s left." % [
						_attempts_left, "s" if _attempts_left != 1 else ""
					]
					_status_label.add_theme_color_override("font_color", Color("#FF4444"))
					_connections_label.text = ""
					_reset_btn.visible = false


func _update_connections_display() -> void:
	var parts: Array[String] = []
	for conn: Array in _connections:
		parts.append("%s → %s" % [AFFINITIES[conn[0]].capitalize(), AFFINITIES[conn[1]].capitalize()])
	_connections_label.text = " | ".join(parts)
	_connections_label.add_theme_color_override("font_color", Color("#88AACC"))


func _highlight_node(idx: int, highlighted: bool) -> void:
	if idx < 0 or idx >= _node_buttons.size():
		return
	var btn: Button = _node_buttons[idx]
	var aff: String = AFFINITIES[idx]
	var aff_color: Color = Affinity.COLORS.get(aff, Color("#888888"))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if highlighted:
		style.bg_color = aff_color
	else:
		style.bg_color = aff_color.darkened(0.3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_color = Color.WHITE if highlighted else aff_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _reset_node_highlights() -> void:
	for i: int in range(_node_buttons.size()):
		_highlight_node(i, false)


func _on_reset() -> void:
	if _completed:
		return
	_connections.clear()
	_selected_node = -1
	_connections_label.text = ""
	_status_label.text = "Select a node to begin."
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_reset_btn.visible = false
	_reset_node_highlights()


func _on_give_up() -> void:
	_started = false
	_completed = true
	visible = false
	puzzle_completed.emit(false, "none", null)


func _update_attempts_label() -> void:
	_attempts_label.text = "Attempts: %d/%d" % [_attempts_left, MAX_ATTEMPTS]
	if _attempts_left <= 1:
		_attempts_label.add_theme_color_override("font_color", Color("#FF6666"))
	else:
		_attempts_label.add_theme_color_override("font_color", Color("#888888"))
