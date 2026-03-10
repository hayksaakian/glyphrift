extends Control

## Squad swap visual test harness.
## Exercises the swap flow: sets up squad + captures, opens swap popup,
## performs swaps, and screenshots both popup and sidebar at each step.

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
			print("Step 1: Enter minor_01 rift")
			var template: RiftTemplate = _data_loader.get_rift_template("minor_01")
			_main_scene._on_rift_selected(template)
			await get_tree().process_frame
			await get_tree().process_frame

			_print_state("After entering rift")
			_take_screenshot("swap_01_rift_start")

		1:
			print("Step 2: Simulate capturing a wild glyph (Zapplet)")
			var sp: GlyphSpecies = _data_loader.get_species("zapplet")
			var wild: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
			wild.side = "player"
			wild.row_position = "back"

			## Add to roster and rift pool (simulating capture flow)
			_roster_state.add_glyph(wild)
			if not _main_scene._dungeon_scene.rift_pool.has(wild):
				_main_scene._dungeon_scene.rift_pool.append(wild)
			_codex_state.discover_species(sp.id)

			## Refresh sidebar
			_main_scene._on_squad_changed()
			await get_tree().process_frame

			_print_state("After capturing Zapplet")
			_take_screenshot("swap_02_after_capture")

		2:
			print("Step 3: Open squad swap popup")
			var ds: DungeonScene = _main_scene._dungeon_scene
			ds._on_swap_pressed()
			await get_tree().process_frame
			await get_tree().process_frame

			_print_state("Swap popup open (before any swaps)")
			_take_screenshot("swap_03_popup_open")

		3:
			print("Step 4: Bench an original squad member (first glyph)")
			var ds: DungeonScene = _main_scene._dungeon_scene
			var popup: SquadSwapPopup = ds._squad_swap_popup
			var first_glyph: GlyphInstance = _roster_state.active_squad[0]
			print("  Benching: %s" % first_glyph.species.name)
			popup._bench_glyph(first_glyph)
			await get_tree().process_frame

			_print_state("After benching original squad member")
			_take_screenshot("swap_04_after_bench")

		4:
			print("Step 5: Close swap popup (Done)")
			var ds: DungeonScene = _main_scene._dungeon_scene
			var popup: SquadSwapPopup = ds._squad_swap_popup
			popup._on_done_pressed()
			await get_tree().process_frame
			await get_tree().process_frame

			_print_state("After closing swap (sidebar should show benched glyph)")
			_take_screenshot("swap_05_after_close")

		5:
			print("Step 6: Reopen swap popup (benched glyph should still be in bench)")
			var ds: DungeonScene = _main_scene._dungeon_scene
			ds._on_swap_pressed()
			await get_tree().process_frame
			await get_tree().process_frame

			_print_state("Swap popup reopened (benched glyph should persist)")
			_take_screenshot("swap_06_reopen")

		6:
			print("Step 7: Re-deploy the benched glyph")
			var ds: DungeonScene = _main_scene._dungeon_scene
			var popup: SquadSwapPopup = ds._squad_swap_popup
			## Find benched glyphs
			var bench: Array[GlyphInstance] = popup._get_bench_glyphs()
			if bench.size() > 0:
				var deploy_glyph: GlyphInstance = bench[0]
				print("  Re-deploying: %s" % deploy_glyph.species.name)
				popup._deploy_glyph(deploy_glyph)
			else:
				print("  ERROR: No bench glyphs found!")
			await get_tree().process_frame

			_print_state("After re-deploying benched glyph")
			_take_screenshot("swap_07_redeploy")

		7:
			print("Step 8: Close and check final state")
			var ds: DungeonScene = _main_scene._dungeon_scene
			var popup: SquadSwapPopup = ds._squad_swap_popup
			popup._on_done_pressed()
			await get_tree().process_frame
			await get_tree().process_frame

			_print_state("Final state after all swaps")
			_take_screenshot("swap_08_final")

		_:
			print("")
			print("Squad swap test harness complete!")
			print("Check screenshots in res://screenshots/swap_*.png")
			await get_tree().process_frame
			get_tree().quit()
			return

	_step += 1
	await get_tree().process_frame
	_run_step()


func _print_state(label: String) -> void:
	print("  --- %s ---" % label)

	## Active squad
	var squad_names: Array[String] = []
	for g: GlyphInstance in _roster_state.active_squad:
		squad_names.append(g.species.name)
	print("  Active squad: %s" % str(squad_names))

	## Rift pool
	var pool_names: Array[String] = []
	for g: GlyphInstance in _main_scene._dungeon_scene.rift_pool:
		pool_names.append(g.species.name)
	print("  Rift pool: %s" % str(pool_names))

	## Sidebar overlay state
	var overlay: SquadOverlay = _main_scene._squad_overlay
	if overlay != null:
		var entry_names: Array[String] = []
		for entry: Dictionary in overlay._entries:
			entry_names.append(entry["glyph"].species.name)
		print("  Sidebar squad entries: %s" % str(entry_names))
		print("  Sidebar reserve header visible: %s, text: '%s'" % [
			str(overlay._reserve_header.visible) if overlay._reserve_header else "null",
			overlay._reserve_header.text if overlay._reserve_header else "null"
		])
		print("  Sidebar reserve rows: %d" % overlay._reserve_rows.size())

	## Swap popup state (if visible)
	var popup: SquadSwapPopup = _main_scene._dungeon_scene._squad_swap_popup
	if popup.visible:
		var bench: Array[GlyphInstance] = popup._get_bench_glyphs()
		var bench_names: Array[String] = []
		for g: GlyphInstance in bench:
			bench_names.append(g.species.name)
		print("  Swap popup bench: %s" % str(bench_names))


func _take_screenshot(step_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir + step_name + ".png"
	var err: Error = image.save_png(path)
	if err == OK:
		print("  -> Saved: %s" % path)
	else:
		print("  -> ERROR saving: %s (code %d)" % [path, err])
