class_name PuzzleConduit
extends Control

## Puzzle: connect three affinity nodes in the correct cycle.
## Correct cycle: Electric → Water → Ground → Electric.
## Click to select a node, click another to connect them.

signal puzzle_completed(success: bool, reward_type: String, reward_data: Variant)

var instant_mode: bool = false
var _connections: Array[Array] = []
var _selected_node: int = -1
var _started: bool = false
var _completed: bool = false

## Node buttons
var _node_buttons: Array[Button] = []
var _node_labels: Array[Label] = []

## Internal nodes
var _bg: ColorRect = null
var _title_label: Label = null
var _instruction_label: Label = null
var _node_container: Control = null
var _status_label: Label = null

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
	_instruction_label.text = "Connect the conduits in the correct cycle."
	_status_label.text = "Select a node to begin."
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_reset_node_highlights()


func attempt_connections(connections: Array[Array]) -> bool:
	## Direct test method — returns true if connections form the correct cycle
	if connections.size() != 3:
		return false
	## Check each required connection exists (order-independent within pairs)
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
	vbox.add_theme_constant_override("separation", 16)
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

	## Node container (triangle layout via HBoxContainer with spacing)
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

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)


func _on_node_pressed(idx: int) -> void:
	if _completed:
		return
	if not _started:
		return

	if _selected_node == -1:
		## Select first node
		_selected_node = idx
		_status_label.text = "%s selected. Click another to connect." % AFFINITIES[idx].capitalize()
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

		_status_label.text = "%d/3 connections made." % _connections.size()

		if _connections.size() == 3:
			## Check if correct
			if attempt_connections(_connections):
				_completed = true
				_status_label.text = "Conduit activated!"
				_status_label.add_theme_color_override("font_color", Color("#44FF44"))
				puzzle_completed.emit(true, "codex_reveal", null)
			else:
				## Wrong — reset
				_connections.clear()
				_status_label.text = "Wrong connections! Try again."
				_status_label.add_theme_color_override("font_color", Color("#FF4444"))


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
	style.border_color = aff_color if not highlighted else Color.WHITE
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
