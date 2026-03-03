extends Control

## Targeted capture flow test harness.
## Boots the game, enters a rift, triggers combat, wins it via auto_battle,
## then captures the post-combat screenshot to verify the capture popup appears.

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


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")
	_setup_deps()
	_setup_main_scene()

	_main_scene.start_game()

	await get_tree().process_frame
	await get_tree().process_frame
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


func _run_step() -> void:
	match _step:
		0:
			print("Step 1: Enter rift")
			var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
			_main_scene._on_rift_selected(template)
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("capture_01_dungeon_start")

		1:
			print("Step 2: Trigger combat with a single wild enemy")
			## Create a single weak enemy so auto_battle wins quickly
			var sp: GlyphSpecies = _data_loader.get_species("zapplet")
			var enemy: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
			enemy.side = "enemy"
			enemy.current_hp = 1  ## 1 HP so combat ends immediately
			var enemies: Array[GlyphInstance] = [enemy]

			## Store the enemy for capture later
			set_meta("wild_enemy", enemy)
			set_meta("enemies", enemies)

			_main_scene._on_combat_requested(enemies, null)
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("capture_02_battle_start")

		2:
			print("Step 3: Auto-battle to win quickly")
			## Set auto_battle and run formation to skip player input
			_combat_engine.auto_battle = true
			## Submit empty formation to start combat
			_combat_engine.set_formation()
			## Drain the animation queue
			var bs: BattleScene = _main_scene._battle_scene
			bs._animation_queue.instant_mode = true

			## Process several frames to let auto_battle complete
			for i: int in range(50):
				await get_tree().process_frame
				bs._animation_queue.drain()
				if _combat_engine.phase == _combat_engine.BattlePhase.VICTORY or _combat_engine.phase == _combat_engine.BattlePhase.DEFEAT:
					break

			print("  Combat phase: %d" % _combat_engine.phase)
			_take_screenshot("capture_03_battle_end")

		3:
			print("Step 4: Simulate battle_finished → return to dungeon with capture popup")
			## Instead of waiting for result screen click, directly simulate
			var enemies: Array[GlyphInstance] = get_meta("enemies")
			_main_scene._on_battle_finished(true)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame

			## Check if capture popup is visible
			var ds: DungeonScene = _main_scene._dungeon_scene
			var popup_visible: bool = ds._capture_popup.visible
			var ui_state: int = ds.get_ui_state()
			print("  Capture popup visible: %s" % str(popup_visible))
			print("  DungeonScene UI state: %d (CAPTURE=%d)" % [ui_state, DungeonScene.UIState.CAPTURE])
			print("  Capture chance text: %s" % ds._capture_popup.get_chance_text())
			_take_screenshot("capture_04_capture_popup")

		4:
			print("Step 5: Force a successful capture via deterministic roll")
			var ds: DungeonScene = _main_scene._dungeon_scene
			var popup: CapturePopup = ds._capture_popup
			var roster_before: int = _roster_state.all_glyphs.size()
			print("  Roster size before capture: %d" % roster_before)

			## Use deterministic roll of 0.0 (always succeeds since chance > 0)
			popup.attempt_capture_with_roll(0.0)
			await get_tree().process_frame
			await get_tree().process_frame

			var roster_after: int = _roster_state.all_glyphs.size()
			print("  Roster size after capture: %d" % roster_after)
			print("  Result text: %s" % popup.get_result_text())
			print("  Popup still visible: %s" % str(popup.visible))
			_take_screenshot("capture_05_captured_result")

		5:
			print("Step 6: Dismiss popup via Continue")
			var ds: DungeonScene = _main_scene._dungeon_scene
			var popup: CapturePopup = ds._capture_popup
			## Press Continue (dismissed signal)
			popup.dismissed.emit()
			await get_tree().process_frame
			await get_tree().process_frame

			print("  Popup visible after dismiss: %s" % str(popup.visible))
			print("  UI state after dismiss: %d (EXPLORING=%d)" % [ds.get_ui_state(), DungeonScene.UIState.EXPLORING])
			_take_screenshot("capture_06_back_to_exploring")

		_:
			print("")
			print("Capture test harness complete!")
			await get_tree().process_frame
			get_tree().quit()
			return

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
