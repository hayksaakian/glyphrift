extends Control

## Full game launcher — boots MainScene with all dependencies wired up.
## Set as main scene or run: ~/bin/godot --path . res://ui/game_demo.tscn

var _main_scene: MainScene = null
var _data_loader: Node = null


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")

	## Create all dependencies
	var roster_state: RosterState = RosterState.new()
	roster_state.name = "RosterState"
	add_child(roster_state)

	var codex_state: CodexState = CodexState.new()
	codex_state.name = "CodexState"
	add_child(codex_state)

	var crawler_state: CrawlerState = CrawlerState.new()
	crawler_state.name = "CrawlerState"
	add_child(crawler_state)

	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	var combat_engine: Node = ce_script.new() as Node
	combat_engine.name = "CombatEngine"
	combat_engine.data_loader = _data_loader
	add_child(combat_engine)

	var fusion_engine: FusionEngine = FusionEngine.new()
	fusion_engine.name = "FusionEngine"
	fusion_engine.data_loader = _data_loader
	fusion_engine.codex_state = codex_state
	fusion_engine.roster_state = roster_state
	add_child(fusion_engine)

	var mastery_tracker: MasteryTracker = MasteryTracker.new()
	mastery_tracker.connect_to_combat(combat_engine)

	var game_state: GameState = GameState.new()
	game_state.name = "GameState"
	game_state.data_loader = _data_loader
	game_state.roster_state = roster_state
	game_state.codex_state = codex_state
	game_state.crawler_state = crawler_state
	game_state.combat_engine = combat_engine
	game_state.fusion_engine = fusion_engine
	game_state.mastery_tracker = mastery_tracker
	add_child(game_state)

	## Create and wire MainScene
	_main_scene = MainScene.new()
	_main_scene.name = "MainScene"
	add_child(_main_scene)

	_main_scene.setup(
		game_state,
		roster_state,
		codex_state,
		crawler_state,
		combat_engine,
		fusion_engine,
		mastery_tracker,
		_data_loader,
	)

	roster_state._seed_debug_glyphs = true
	_main_scene.start_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		GlyphArt.clear_cache()
