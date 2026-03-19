extends Control

## Session 9 visual harness — walks through Codex, NPC dialogue, and Event rooms.
## Run: ~/bin/godot --path . res://tests/session9_harness.tscn
##
## Produces PNGs in res://screenshots/session9/ for visual review.

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
var _steps: Array[String] = []
var _screenshot_dir: String = "res://screenshots/session9/"


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")
	DirAccess.make_dir_recursive_absolute("res://screenshots/session9")
	_setup_deps()
	_setup_main_scene()

	_steps = [
		"01_bastion_hub_with_npcs",
		"02_codex_glyph_registry_empty",
		"03_codex_glyph_registry_discovered",
		"04_codex_fusion_log",
		"05_codex_rift_atlas",
		"06_codex_detail_popup",
		"07_npc_kael_phase1",
		"08_npc_lira_phase1",
		"09_npc_maro_phase1",
		"10_npc_kael_phase2",
		"11_dungeon_puzzle_room",
		"12_puzzle_sequence",
		"13_puzzle_conduit",
		"14_puzzle_echo",
	]

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
	if _step >= _steps.size():
		print("Session 9 harness complete — %d screenshots captured" % _steps.size())
		await get_tree().process_frame
		get_tree().quit()
		return

	var step_name: String = _steps[_step]
	print("Step %d: %s" % [_step + 1, step_name])

	match step_name:
		"01_bastion_hub_with_npcs":
			## Hub is already showing from start_game() — now shows NPC buttons + Codex
			pass

		"02_codex_glyph_registry_empty":
			## Open codex — all species undiscovered (only 3 starters known)
			_main_scene._bastion_scene._codex_btn.pressed.emit()

		"03_codex_glyph_registry_discovered":
			## Discover more species for a richer display
			_codex_state.discover_species("sparkfin")
			_codex_state.discover_species("mossling")
			_codex_state.discover_species("glitchkit")
			_codex_state.discover_species("thunderclaw")
			_codex_state.discover_species("ironbark")
			_main_scene._bastion_scene._codex_browser.refresh()

		"04_codex_fusion_log":
			## Add some fusion log entries
			_codex_state.log_fusion("zapplet", "sparkfin", "thunderclaw")
			_codex_state.log_fusion("stonepaw", "mossling", "ironbark")
			_main_scene._bastion_scene._codex_browser._fusion_tab_btn.pressed.emit()

		"05_codex_rift_atlas":
			## Switch to rift atlas
			_main_scene._bastion_scene._codex_browser._rift_tab_btn.pressed.emit()

		"06_codex_detail_popup":
			## Click a discovered species to show detail popup
			_main_scene._bastion_scene._codex_browser._glyph_tab_btn.pressed.emit()
			await get_tree().process_frame
			_main_scene._bastion_scene._codex_browser._on_species_panel_clicked("thunderclaw")

		"07_npc_kael_phase1":
			## Close codex, show Kael NPC
			_main_scene._bastion_scene._codex_browser._detail_popup.hide_popup()
			_main_scene._bastion_scene.show_hub()
			await get_tree().process_frame
			_main_scene._bastion_scene._npc_kael_btn.pressed.emit()

		"08_npc_lira_phase1":
			## Close Kael, show Lira
			_main_scene._bastion_scene._npc_panel.hide_popup()
			await get_tree().process_frame
			_main_scene._bastion_scene._npc_lira_btn.pressed.emit()

		"09_npc_maro_phase1":
			## Close Lira, show Maro
			_main_scene._bastion_scene._npc_panel.hide_popup()
			await get_tree().process_frame
			_main_scene._bastion_scene._npc_maro_btn.pressed.emit()

		"10_npc_kael_phase2":
			## Advance phase, show Kael with new dialogue
			_main_scene._bastion_scene._npc_panel.hide_popup()
			_game_state.game_phase = 2
			await get_tree().process_frame
			_main_scene._bastion_scene._npc_kael_btn.pressed.emit()

		"11_dungeon_puzzle_room":
			## Close NPC, enter a rift, navigate to event room
			_main_scene._bastion_scene._npc_panel.hide_popup()
			_game_state.game_phase = 1
			await get_tree().process_frame
			## Enter rift
			var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
			_main_scene._on_rift_selected(template)
			await get_tree().process_frame
			## Inject a custom floor with event rooms for screenshot
			var ds: DungeonState = _game_state.current_dungeon
			if ds != null:
				var floor_data: Dictionary = ds.floors[0]
				## Find first non-start room and make it a puzzle
				for room: Dictionary in floor_data.get("rooms", []):
					if room.get("type", "") == "enemy":
						room["type"] = "event"
						room["revealed"] = true
						break
				_main_scene._dungeon_scene._rebuild_floor()

		"12_puzzle_sequence":
			## Launch sequence puzzle directly
			var ps: PuzzleSequence = _main_scene._dungeon_scene._puzzle_sequence
			ps.start_with_order([0, 2, 1, 3], true)

		"13_puzzle_conduit":
			## Hide sequence, launch conduit
			_main_scene._dungeon_scene._puzzle_sequence.visible = false
			_main_scene._dungeon_scene._puzzle_conduit.start(true)

		"14_puzzle_echo":
			## Hide conduit, launch echo
			_main_scene._dungeon_scene._puzzle_conduit.visible = false
			var sp: GlyphSpecies = _data_loader.get_species("thunderclaw")
			var echo_g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
			echo_g.side = "enemy"
			_main_scene._dungeon_scene._puzzle_echo.start_with_glyph(echo_g)

	## Wait for rendering
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
