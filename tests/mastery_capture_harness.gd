extends Control

## Visual test harness for capture_participated mastery objective.
## Forces a squad glyph to have capture_participated, runs a battle,
## triggers a successful capture, then shows the glyph detail popup
## to visually verify the objective checkmark turned green.

var _data_loader: Node = null
var _main_scene: MainScene = null
var _game_state: GameState = null
var _roster_state: RosterState = null
var _codex_state: CodexState = null
var _crawler_state: CrawlerState = null
var _combat_engine: Node = null
var _fusion_engine: FusionEngine = null
var _mastery_tracker: MasteryTracker = null

var _step: int = 0
var _screenshot_dir: String = "res://screenshots/"
var _test_glyph: GlyphInstance = null  ## The glyph we're tracking mastery on


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")
	_setup_deps()
	_setup_main_scene()

	_main_scene.start_game()

	await get_tree().process_frame
	await get_tree().process_frame

	## Force capture_participated onto our first squad glyph
	_force_capture_objective()

	_run_step()


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
	_main_scene.instant_mode = true
	add_child(_main_scene)

	_main_scene.setup(
		_game_state,
		_roster_state,
		_codex_state,
		_crawler_state,
		_combat_engine,
		_fusion_engine,
		_mastery_tracker,
		_data_loader,
	)


func _force_capture_objective() -> void:
	## Replace the 3rd (random) mastery objective on our first squad glyph
	## with capture_participated, so we can verify it fires after capture.
	if _roster_state.active_squad.is_empty():
		print("ERROR: No squad glyphs found!")
		return

	_test_glyph = _roster_state.active_squad[0]
	print("Test glyph: %s (id=%s)" % [_test_glyph.species.name, _test_glyph.species.id])
	print("Original mastery objectives:")
	for i: int in range(_test_glyph.mastery_objectives.size()):
		var obj: Dictionary = _test_glyph.mastery_objectives[i]
		print("  [%d] %s — completed=%s" % [i, obj.get("type", "?"), str(obj.get("completed", false))])

	## Force the last objective to capture_participated
	if _test_glyph.mastery_objectives.size() >= 3:
		_test_glyph.mastery_objectives[2] = {
			"type": "capture_participated",
			"params": {},
			"completed": false,
			"description": "Capture a Glyph after a battle this Glyph participated in.",
		}
	else:
		_test_glyph.mastery_objectives.append({
			"type": "capture_participated",
			"params": {},
			"completed": false,
			"description": "Capture a Glyph after a battle this Glyph participated in.",
		})

	print("After forcing capture_participated:")
	for i: int in range(_test_glyph.mastery_objectives.size()):
		var obj: Dictionary = _test_glyph.mastery_objectives[i]
		print("  [%d] %s — completed=%s" % [i, obj.get("type", "?"), str(obj.get("completed", false))])


func _run_step() -> void:
	match _step:
		0:
			print("")
			print("=== Step 1: Show glyph detail BEFORE (capture_participated unchecked) ===")
			_main_scene._detail_popup.show_glyph(_test_glyph)
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("mastery_01_before_detail")
			print("  capture_participated completed: %s" % str(_test_glyph.mastery_objectives[2].get("completed", false)))

		1:
			print("")
			print("=== Step 2: Close detail, enter rift ===")
			_main_scene._detail_popup.hide_popup()
			var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
			_main_scene._on_rift_selected(template)
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("mastery_02_dungeon_start")

		2:
			print("")
			print("=== Step 3: Trigger combat with weak enemy ===")
			var sp: GlyphSpecies = _data_loader.get_species("stonepaw")
			var enemy: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
			enemy.side = "enemy"
			## Give enemy enough HP so multiple squad members take turns
			## (ensures our test glyph participates), but 0 ATK to avoid KOs
			enemy.current_hp = 50
			enemy.max_hp = 50
			enemy.atk = 0
			var enemies: Array[GlyphInstance] = [enemy]
			set_meta("wild_enemy", enemy)
			set_meta("enemies", enemies)

			_main_scene._on_combat_requested(enemies, null)
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("mastery_03_battle_start")

		3:
			print("")
			print("=== Step 4: Auto-battle to win ===")
			_combat_engine.auto_battle = true
			_combat_engine.set_formation()
			var bs: BattleScene = _main_scene._battle_scene
			bs._animation_queue.instant_mode = true

			for i: int in range(50):
				await get_tree().process_frame
				bs._animation_queue.drain()
				if _combat_engine.phase == _combat_engine.BattlePhase.VICTORY or _combat_engine.phase == _combat_engine.BattlePhase.DEFEAT:
					break

			print("  Combat phase: %d" % _combat_engine.phase)
			print("  Test glyph took_turn: %s" % str(_test_glyph.took_turn_this_battle))
			print("  capture_participated BEFORE capture: %s" % str(_test_glyph.mastery_objectives[2].get("completed", false)))
			_take_screenshot("mastery_04_battle_end")

		4:
			print("")
			print("=== Step 5: Return to dungeon, trigger capture popup ===")
			_main_scene._on_battle_finished(true)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame

			var ds: DungeonScene = _main_scene._dungeon_scene
			print("  Capture popup visible: %s" % str(ds._capture_popup.visible))
			print("  UI state: %d (CAPTURE=%d)" % [ds.get_ui_state(), DungeonScene.UIState.CAPTURE])
			_take_screenshot("mastery_05_capture_popup")

		5:
			print("")
			print("=== Step 6: Force successful capture (roll=0.0) ===")
			var ds: DungeonScene = _main_scene._dungeon_scene
			var popup: CapturePopup = ds._capture_popup
			var roster_before: int = _roster_state.all_glyphs.size()
			print("  Roster before: %d" % roster_before)

			popup.attempt_capture_with_roll(0.0)
			await get_tree().process_frame
			await get_tree().process_frame

			var roster_after: int = _roster_state.all_glyphs.size()
			print("  Roster after: %d" % roster_after)
			print("  capture_participated AFTER capture: %s" % str(_test_glyph.mastery_objectives[2].get("completed", false)))
			_take_screenshot("mastery_06_captured")

		6:
			print("")
			print("=== Step 7: Dismiss capture popup ===")
			var ds: DungeonScene = _main_scene._dungeon_scene
			ds._capture_popup.dismissed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("mastery_07_dismissed")

		7:
			print("")
			print("=== Step 8: Show glyph detail AFTER (capture_participated should be checked) ===")
			_main_scene._detail_popup.show_glyph(_test_glyph)
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("mastery_08_after_detail")

			## Final verification
			var obj: Dictionary = _test_glyph.mastery_objectives[2]
			print("")
			print("========================================")
			if obj.get("completed", false):
				print("  PASS: capture_participated is COMPLETED")
			else:
				print("  FAIL: capture_participated is NOT completed")
			print("========================================")

		_:
			print("")
			print("Mastery capture harness complete!")
			await get_tree().process_frame
			get_tree().quit()
			return

	_step += 1
	await get_tree().process_frame
	_run_step()


func _take_screenshot(step_name: String) -> void:
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		print("  -> Screenshot skipped (headless mode): %s" % step_name)
		return
	var image: Image = tex.get_image()
	if image == null:
		print("  -> Screenshot skipped (no image): %s" % step_name)
		return
	var path: String = _screenshot_dir + step_name + ".png"
	var err: Error = image.save_png(path)
	if err == OK:
		print("  -> Saved: %s" % path)
	else:
		print("  -> ERROR saving: %s (code %d)" % [path, err])
