extends Control

## Screenshot harness — walks through all UI states, captures a screenshot at each.
## Run: ~/bin/godot --path . res://tests/screenshot_harness.tscn
##
## Produces PNGs in res://screenshots/ for visual review.

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
var _screenshot_dir: String = "res://screenshots/"


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")
	_setup_deps()
	_setup_main_scene()

	## Define the walkthrough steps
	_steps = [
		"01_bastion_hub",
		"02_bastion_barracks",
		"03_bastion_barracks_row_toggle",
		"04_bastion_fusion_chamber",
		"05_bastion_fusion_parents_selected",
		"06_bastion_rift_gate",
		"07_dungeon_exploring",
		"08_dungeon_squad_overlay",
		"09_bastion_after_rift",
	]

	## Start the game
	_main_scene.start_game()

	## Give 2 frames for layout to settle, then start stepping
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
		print("Screenshot harness complete — %d screenshots captured" % _steps.size())
		## Let the final frame render then quit
		await get_tree().process_frame
		get_tree().quit()
		return

	var step_name: String = _steps[_step]
	print("Step %d: %s" % [_step + 1, step_name])

	match step_name:
		"01_bastion_hub":
			## Already showing bastion hub from start_game()
			pass

		"02_bastion_barracks":
			_main_scene._bastion_scene._barracks_btn.pressed.emit()

		"03_bastion_barracks_row_toggle":
			## Toggle first glyph's row to "back" via card click
			var barracks: Barracks = _main_scene._bastion_scene._barracks
			if barracks._squad_cards.size() > 0:
				var g: GlyphInstance = barracks._squad_cards[0].glyph
				barracks._on_squad_card_clicked(g)

		"04_bastion_fusion_chamber":
			## Go back to hub first, then fusion
			_main_scene._bastion_scene.show_hub()
			await get_tree().process_frame
			_main_scene._bastion_scene._fusion_btn.pressed.emit()

		"05_bastion_fusion_parents_selected":
			## Master first 2 glyphs, leave rest unmastered for split picker demo
			var fc: FusionChamber = _main_scene._bastion_scene._fusion_chamber
			var idx: int = 0
			for g: GlyphInstance in _roster_state.all_glyphs:
				if idx < 2:
					g.is_mastered = true
					for i: int in range(g.mastery_objectives.size()):
						g.mastery_objectives[i]["completed"] = true
				idx += 1
			fc.refresh()
			await get_tree().process_frame
			## Pick first two mastered glyphs as parents
			if fc._picker_cards.size() >= 2:
				fc._on_picker_clicked(fc._picker_cards[0].glyph)
				fc._on_picker_clicked(fc._picker_cards[1].glyph)

		"06_bastion_rift_gate":
			## Un-master glyphs (reset to original state)
			for g: GlyphInstance in _roster_state.all_glyphs:
				if g.is_mastered:
					g.is_mastered = false
					for i: int in range(g.mastery_objectives.size()):
						g.mastery_objectives[i]["completed"] = false
			_main_scene._bastion_scene.show_hub()
			await get_tree().process_frame
			_main_scene._bastion_scene._rift_gate_btn.pressed.emit()

		"07_dungeon_exploring":
			## Enter a rift
			var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
			_main_scene._on_rift_selected(template)

		"08_dungeon_squad_overlay":
			## Damage a glyph to show yellow/red HP in overlay
			if _roster_state.active_squad.size() > 0:
				var g: GlyphInstance = _roster_state.active_squad[0]
				g.current_hp = int(g.max_hp * 0.3)
			if _roster_state.active_squad.size() > 1:
				var g2: GlyphInstance = _roster_state.active_squad[1]
				g2.current_hp = int(g2.max_hp * 0.1)
			_main_scene._squad_overlay.refresh()

		"09_bastion_after_rift":
			## Complete the rift and return to bastion
			_main_scene._on_rift_completed(true)

	## Wait 2 frames for rendering, then capture
	await get_tree().process_frame
	await get_tree().process_frame
	_take_screenshot(step_name)

	_step += 1
	## Small delay between steps to let layout settle
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
