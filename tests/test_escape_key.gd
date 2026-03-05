extends Control

## Tests Escape key toggling PauseMenu, including the dual-menu scenario.
## Run: ~/bin/godot --path . res://tests/test_escape_key.tscn

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	await get_tree().process_frame
	await get_tree().process_frame

	## --- Basic toggle ---
	print("--- Basic toggle ---")
	var pm: PauseMenu = PauseMenu.new()
	pm.instant_mode = true
	add_child(pm)

	_assert(not pm.is_open, "Starts closed")
	pm.toggle()
	_assert(pm.is_open, "Open after toggle")
	pm.toggle()
	_assert(not pm.is_open, "Closed after second toggle")
	pm.open()
	_assert(pm.is_open, "Open after open()")
	pm.close()
	_assert(not pm.is_open, "Closed after close()")

	remove_child(pm)
	pm.queue_free()

	## --- Simulated Escape key ---
	print("--- Simulated Escape key ---")
	var pm2: PauseMenu = PauseMenu.new()
	add_child(pm2)

	_simulate_escape()
	await get_tree().process_frame
	_assert(pm2.is_open, "Open after Escape")

	_simulate_escape()
	await get_tree().process_frame
	_assert(not pm2.is_open, "Closed after second Escape")

	remove_child(pm2)
	pm2.queue_free()

	## --- Dual menus: hidden parent doesn't steal input ---
	print("--- Dual menus: hidden parent doesn't steal input ---")

	var bastion: Control = Control.new()
	bastion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bastion)

	var dungeon: Control = Control.new()
	dungeon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dungeon.visible = false
	add_child(dungeon)

	var bastion_pm: PauseMenu = PauseMenu.new()
	bastion.add_child(bastion_pm)

	var dungeon_pm: PauseMenu = PauseMenu.new()
	dungeon.add_child(dungeon_pm)

	_simulate_escape()
	await get_tree().process_frame
	_assert(bastion_pm.is_open, "Bastion menu opens")
	_assert(not dungeon_pm.is_open, "Dungeon menu stays closed (parent hidden)")

	_simulate_escape()
	await get_tree().process_frame
	_assert(not bastion_pm.is_open, "Bastion menu closes")

	## Flip: dungeon visible, bastion hidden
	bastion.visible = false
	dungeon.visible = true

	_simulate_escape()
	await get_tree().process_frame
	_assert(dungeon_pm.is_open, "Dungeon menu opens when visible")
	_assert(not bastion_pm.is_open, "Bastion menu stays closed (parent hidden)")

	_simulate_escape()
	await get_tree().process_frame
	_assert(not dungeon_pm.is_open, "Dungeon menu closes")

	remove_child(bastion)
	remove_child(dungeon)
	bastion.queue_free()
	dungeon.queue_free()

	## Done
	print("")
	print("========================================")
	print("  Escape Key Tests: %d passed, %d failed" % [_pass_count, _fail_count])
	print("========================================")
	get_tree().quit()


func _simulate_escape() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		print("[PASS] %s" % msg)
		_pass_count += 1
	else:
		print("[FAIL] %s" % msg)
		_fail_count += 1
