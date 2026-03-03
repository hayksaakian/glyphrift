extends Control

## Quick visual test for the item popup.

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
		_game_state, _roster_state, _codex_state, _crawler_state,
		_combat_engine, _fusion_engine, _mastery_tracker, _data_loader,
	)


func _run_step() -> void:
	match _step:
		0:
			print("Step 1: Enter rift")
			var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
			_main_scene._on_rift_selected(template)
			await get_tree().process_frame

			## Add some items to the crawler manually
			var repair: ItemDef = _data_loader.get_item("repair_patch")
			var shard: ItemDef = _data_loader.get_item("vital_shard")
			var surge: ItemDef = _data_loader.get_item("surge_cell")
			_crawler_state.add_item(repair)
			_crawler_state.add_item(shard)
			_crawler_state.add_item(surge)

			## Damage a glyph so heal is meaningful
			_roster_state.active_squad[0].current_hp = 3
			_main_scene._squad_overlay.refresh()
			_main_scene._dungeon_scene._crawler_hud.refresh()

			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("items_01_dungeon_with_items")

		1:
			print("Step 2: Open item popup")
			_main_scene._dungeon_scene._on_items_pressed()
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("items_02_popup_open")

		2:
			print("Step 3: Use Vital Shard to heal glyph")
			var popup: ItemPopup = _main_scene._dungeon_scene._item_popup
			## Find and press the Use button for vital_shard
			for row: HBoxContainer in popup._item_rows:
				for child: Node in row.get_children():
					if child is Button and child.text == "Use":
						## Check if this row is the Vital Shard
						var info: VBoxContainer = row.get_child(0) as VBoxContainer
						var name_label: Label = info.get_child(0) as Label
						if name_label.text == "Vital Shard":
							child.pressed.emit()
							break
			await get_tree().process_frame
			await get_tree().process_frame
			print("  Squad[0] HP after heal: %d/%d" % [_roster_state.active_squad[0].current_hp, _roster_state.active_squad[0].max_hp])
			_main_scene._squad_overlay.refresh()
			_take_screenshot("items_03_after_heal")

		3:
			print("Step 4: Close popup")
			_main_scene._dungeon_scene._item_popup.closed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_take_screenshot("items_04_closed")

		_:
			print("Item test harness complete!")
			await get_tree().process_frame
			get_tree().quit()
			return

	_step += 1
	await get_tree().process_frame
	_run_step()


func _take_screenshot(name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir + name + ".png"
	image.save_png(path)
	print("  -> Saved: %s" % path)
