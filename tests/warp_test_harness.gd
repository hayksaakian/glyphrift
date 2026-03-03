extends Control

## Visual test for emergency warp flow:
## Enter rift → take damage → warp out → verify heal + notification at bastion.

var _data_loader: Node = null
var _main_scene: MainScene = null
var _game_state: GameState = null
var _roster_state: RosterState = null
var _codex_state: CodexState = null
var _crawler_state: CrawlerState = null
var _combat_engine: Node = null
var _fusion_engine: FusionEngine = null
var _mastery_tracker: MasteryTracker = null

var _screenshot_dir: String = "res://screenshots/warp/"
var _screenshot_idx: int = 0


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")
	_setup_deps()
	_setup_main_scene()
	_main_scene.start_game()
	DirAccess.make_dir_recursive_absolute("res://screenshots/warp")

	await _wait_ms(500)
	_screenshot("01_bastion_start")
	await _run_test()


func _setup_deps() -> void:
	_roster_state = RosterState.new()
	_roster_state.name = "RosterState"
	add_child(_roster_state)
	_codex_state = CodexState.new()
	_codex_state.name = "CodexState"
	add_child(_codex_state)
	_crawler_state = CrawlerState.new()
	_crawler_state.name = "CrawlerState"
	add_child(_crawler_state)
	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	_combat_engine = ce_script.new() as Node
	_combat_engine.name = "CombatEngine"
	_combat_engine.data_loader = _data_loader
	add_child(_combat_engine)
	_fusion_engine = FusionEngine.new()
	_fusion_engine.name = "FusionEngine"
	_fusion_engine.data_loader = _data_loader
	_fusion_engine.codex_state = _codex_state
	_fusion_engine.roster_state = _roster_state
	add_child(_fusion_engine)
	_mastery_tracker = MasteryTracker.new()
	_mastery_tracker.connect_to_combat(_combat_engine)
	_game_state = GameState.new()
	_game_state.name = "GameState"
	_game_state.data_loader = _data_loader
	_game_state.roster_state = _roster_state
	_game_state.codex_state = _codex_state
	_game_state.crawler_state = _crawler_state
	_game_state.combat_engine = _combat_engine
	_game_state.fusion_engine = _fusion_engine
	_game_state.mastery_tracker = _mastery_tracker
	add_child(_game_state)


func _setup_main_scene() -> void:
	_main_scene = MainScene.new()
	_main_scene.name = "MainScene"
	add_child(_main_scene)
	_main_scene.setup(
		_game_state, _roster_state, _codex_state, _crawler_state,
		_combat_engine, _fusion_engine, _mastery_tracker, _data_loader,
	)


func _run_test() -> void:
	print("")
	print("=== WARP TEST ===")
	print("")

	## Enter rift
	print("[1] Entering rift...")
	_main_scene._bastion_scene._rift_gate_btn.pressed.emit()
	await _wait_ms(300)
	var enter_btn: Button = _find_button_in(_main_scene._bastion_scene._rift_gate, "Enter")
	enter_btn.pressed.emit()
	await _wait_ms(700)
	_screenshot("02_dungeon_start")

	## Damage glyphs to simulate a rough run
	print("[2] Damaging glyphs...")
	var squad: Array[GlyphInstance] = _roster_state.active_squad
	squad[0].current_hp = 0
	squad[0].is_knocked_out = true
	squad[1].current_hp = 3
	squad[2].current_hp = 4
	_main_scene._squad_overlay.refresh()
	await _wait_ms(300)
	_screenshot("03_damaged_squad")

	## Print state before warp
	print("  Before warp:")
	for g: GlyphInstance in squad:
		print("    %s: HP %d/%d %s" % [g.species.name, g.current_hp, g.max_hp,
			"(KO)" if g.is_knocked_out else ""])

	## Click Warp ability button
	print("[3] Clicking Emergency Warp...")
	var ds: DungeonScene = _main_scene._dungeon_scene
	var warp_btn: Button = ds._crawler_hud.get_ability_button("emergency_warp")
	print("  Warp button found: %s, disabled: %s" % [str(warp_btn != null), str(warp_btn.disabled) if warp_btn else "n/a"])
	warp_btn.pressed.emit()
	await _wait_ms(500)
	_screenshot("04_rift_failed_overlay")

	## Check dungeon state — should show RIFT FAILED result
	print("  DungeonScene UI state: %d (RESULT=%d)" % [ds.get_ui_state(), DungeonScene.UIState.RESULT])

	## Click Continue on result overlay to trigger rift_completed
	print("[3b] Clicking Continue on result overlay...")
	ds._result_continue.pressed.emit()
	## Wait for fade transition to bastion
	await _wait_ms(1000)
	_screenshot("05_bastion_after_warp")

	## Check healing happened
	print("[4] After warp — checking heal:")
	for g: GlyphInstance in _roster_state.all_glyphs:
		var status: String = "OK" if not g.is_knocked_out else "KO"
		print("    %s: HP %d/%d %s" % [g.species.name, g.current_hp, g.max_hp, status])

	var all_healed: bool = true
	for g: GlyphInstance in _roster_state.all_glyphs:
		if g.current_hp != g.max_hp or g.is_knocked_out:
			all_healed = false
	print("  All healed: %s" % str(all_healed))

	## Check notification is visible
	var notif: Label = _main_scene._bastion_scene._notification_label
	print("  Notification visible: %s" % str(notif.visible))
	print("  Notification text: '%s'" % notif.text)

	## Check bastion is showing
	print("  Bastion visible: %s" % str(_main_scene._bastion_scene.visible))
	print("  Dungeon visible: %s" % str(_main_scene._dungeon_scene.visible))

	## Wait a moment and take final screenshot
	await _wait_ms(500)
	_screenshot("06_bastion_notification")

	print("")
	print("=== WARP TEST COMPLETE ===")
	var passed: bool = all_healed and notif.visible and _main_scene._bastion_scene.visible
	print("  Result: %s" % ("PASS" if passed else "FAIL"))
	print("")

	await _wait_ms(500)
	get_tree().quit()


func _wait_ms(ms: int) -> void:
	var frames: int = maxi(1, int(ms / 16.0))
	for i: int in range(frames):
		await get_tree().process_frame


func _screenshot(label: String) -> void:
	_screenshot_idx += 1
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s%02d_%s.png" % [_screenshot_dir, _screenshot_idx, label]
	image.save_png(path)
	print("  [SS] %s" % path)


func _find_button_in(parent: Node, text: String) -> Button:
	if parent is Button and (parent as Button).text == text:
		return parent as Button
	for child: Node in parent.get_children():
		var found: Button = _find_button_in(child, text)
		if found != null:
			return found
	return null
