extends Control

## Puzzle test harness — walks through all 3 puzzle types in various states.
## Run: ~/bin/godot --path . res://tests/puzzle_test_harness.tscn

var _data_loader: Node = null
var _step: int = 0
var _steps: Array[String] = []
var _screenshot_dir: String = "res://screenshots/puzzles/"

var _seq: PuzzleSequence = null
var _conduit: PuzzleConduit = null
var _echo: PuzzleEcho = null


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")
	DirAccess.make_dir_recursive_absolute("res://screenshots/puzzles")

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#0A0A14")
	add_child(bg)

	_seq = PuzzleSequence.new()
	_seq.name = "PuzzleSequence"
	add_child(_seq)

	_conduit = PuzzleConduit.new()
	_conduit.name = "PuzzleConduit"
	add_child(_conduit)

	_echo = PuzzleEcho.new()
	_echo.name = "PuzzleEcho"
	add_child(_echo)

	_steps = [
		"01_seq_input_phase",
		"02_seq_wrong_1attempt",
		"03_seq_partial_correct",
		"04_seq_complete",
		"05_seq_failed",
		"06_conduit_initial",
		"07_conduit_node_selected",
		"08_conduit_1_connection",
		"09_conduit_wrong",
		"10_conduit_correct",
		"11_echo_initial",
	]

	await get_tree().process_frame
	await get_tree().process_frame
	_run_step()


func _run_step() -> void:
	if _step >= _steps.size():
		print("Puzzle harness complete — %d screenshots captured" % _steps.size())
		await get_tree().process_frame
		get_tree().quit()
		return

	var step_name: String = _steps[_step]
	print("Step %d: %s" % [_step + 1, step_name])

	_seq.visible = false
	_conduit.visible = false
	_echo.visible = false

	match step_name:
		"01_seq_input_phase":
			## Show input phase with sequence text visible
			_seq.start_with_order([2, 0, 3, 1] as Array[int], true)
			## Manually show the sequence text so it's visible in screenshot
			_seq._sequence_display.text = "Blue → Red → Orange → Green"

		"02_seq_wrong_1attempt":
			## After 2 wrong attempts (1 left)
			_seq.start_with_order([2, 0, 3, 1] as Array[int], true)
			_seq._attempts_left = 1
			_seq._update_attempts_label()
			_seq._status_label.text = "Wrong! 1 attempt left. 0/4"
			_seq._status_label.add_theme_color_override("font_color", Color("#FF4444"))

		"03_seq_partial_correct":
			## 2/4 correct inputs
			_seq.start_with_order([2, 0, 3, 1] as Array[int], true)
			_seq._player_input = [2, 0] as Array[int]
			_seq._status_label.text = "2/4"
			_seq._status_label.add_theme_color_override("font_color", Color("#AAAAAA"))

		"04_seq_complete":
			## Success
			_seq.start_with_order([2, 0, 3, 1] as Array[int], true)
			_seq._player_input = [2, 0, 3, 1] as Array[int]
			_seq._input_phase = false
			_seq._status_label.text = "Correct!"
			_seq._status_label.add_theme_color_override("font_color", Color("#44FF44"))
			_seq._instruction_label.text = "The pillars glow with energy!"
			_seq._show_again_btn.visible = false
			_seq._give_up_btn.visible = false

		"05_seq_failed":
			## All attempts used
			_seq.start_with_order([2, 0, 3, 1] as Array[int], true)
			_seq._input_phase = false
			_seq._attempts_left = 0
			_seq._update_attempts_label()
			_seq._status_label.text = "Failed!"
			_seq._status_label.add_theme_color_override("font_color", Color("#FF4444"))
			_seq._instruction_label.text = "The pillars go dark..."
			_seq._show_again_btn.visible = false
			_seq._give_up_btn.visible = false
			_seq._sequence_display.text = ""

		"06_conduit_initial":
			_conduit.start(true)

		"07_conduit_node_selected":
			_conduit.start(true)
			_conduit._on_node_pressed(0)

		"08_conduit_1_connection":
			_conduit.start(true)
			_conduit._on_node_pressed(0)
			_conduit._on_node_pressed(1)  ## E→W

		"09_conduit_wrong":
			_conduit.start(true)
			_conduit._on_node_pressed(0)
			_conduit._on_node_pressed(1)  ## E→W
			_conduit._on_node_pressed(1)
			_conduit._on_node_pressed(0)  ## W→E (duplicate direction)
			_conduit._on_node_pressed(2)
			_conduit._on_node_pressed(0)  ## G→E — 3 connections, wrong cycle

		"10_conduit_correct":
			_conduit.start(true)
			_conduit._on_node_pressed(0)
			_conduit._on_node_pressed(1)  ## E→W
			_conduit._on_node_pressed(1)
			_conduit._on_node_pressed(2)  ## W→G
			_conduit._on_node_pressed(2)
			_conduit._on_node_pressed(0)  ## G→E

		"11_echo_initial":
			var sp: GlyphSpecies = _data_loader.get_species("thunderclaw")
			var echo_g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
			echo_g.side = "enemy"
			_echo.start_with_glyph(echo_g)

	await get_tree().process_frame
	await get_tree().process_frame
	_take_screenshot(step_name)

	_step += 1
	await get_tree().process_frame
	_run_step()


func _take_screenshot(step_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir + step_name + ".png"
	var err: Error = image.save_png(path)
	if err == OK:
		print("  -> Saved: %s" % path)
	else:
		print("  -> ERROR saving: %s (code %d)" % [path, err])
