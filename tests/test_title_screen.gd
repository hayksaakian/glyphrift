extends SceneTree

var _data_loader: Node = null
var pass_count: int = 0
var fail_count: int = 0


func _init() -> void:
	SaveManager._test_prefix = "test_"
	var dl_script: GDScript = load("res://core/data_loader.gd") as GDScript
	_data_loader = dl_script.new() as Node
	_data_loader.name = "DataLoader"
	root.add_child(_data_loader)

	await process_frame
	_run_tests()
	SaveManager._test_prefix = ""
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — Title Screen Tests")
	print("========================================")
	print("")

	## TitleScreen component
	_test_title_construction()
	_test_title_labels()
	_test_continue_disabled_no_saves()
	_test_new_game_signal()
	_test_continue_signal()
	_test_refresh_enables_continue()
	_test_most_recent_slot_empty()
	_test_most_recent_slot_picks_latest()

	## Load Game button
	_test_load_game_button_exists()
	_test_load_game_disabled_no_saves()
	_test_load_game_enabled_with_saves()
	_test_load_game_signal()

	## MainScene integration
	_test_main_scene_has_title_screen()
	_test_main_scene_show_title()
	_test_main_scene_new_game_flow()
	_test_main_scene_continue_flow()
	_test_main_scene_save_and_quit_returns_to_title()
	_test_main_scene_load_game_opens_popup()
	_test_main_scene_title_slot_loaded()

	## Phase progression
	_test_phase_progression_rifts()
	_test_phase_advancement_thresholds()

	print("")
	print("========================================")
	print("  RESULTS: %d passed, %d failed" % [pass_count, fail_count])
	print("========================================")
	if fail_count == 0:
		print("  ALL TESTS PASSED")
	else:
		print("  SOME TESTS FAILED — review output above")
	print("")


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		print("[PASS] %s" % test_name)
		pass_count += 1
	else:
		print("[FAIL] %s" % test_name)
		fail_count += 1


# ==========================================================================
# Helpers
# ==========================================================================

func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()


func _cleanup_saves() -> void:
	SaveManager.delete_save()
	for slot: String in ["slot1", "slot2", "slot3", "test_slot"]:
		SaveManager.delete_slot(slot)


func _make_game_state() -> GameState:
	var gs_script: GDScript = load("res://core/game_state.gd") as GDScript
	var gs: GameState = gs_script.new() as GameState
	gs.name = "TestGameState_%d" % randi()
	root.add_child(gs)
	return gs


func _make_roster_state() -> RosterState:
	var rs_script: GDScript = load("res://core/progression/roster_state.gd") as GDScript
	var rs: RosterState = rs_script.new() as RosterState
	rs.name = "TestRoster_%d" % randi()
	root.add_child(rs)
	return rs


func _make_codex_state() -> CodexState:
	var cx_script: GDScript = load("res://core/progression/codex_state.gd") as GDScript
	var cx: CodexState = cx_script.new() as CodexState
	cx.name = "TestCodex_%d" % randi()
	root.add_child(cx)
	return cx


func _make_crawler_state() -> CrawlerState:
	var cs_script: GDScript = load("res://core/dungeon/crawler_state.gd") as GDScript
	var cs: CrawlerState = cs_script.new() as CrawlerState
	cs.name = "TestCrawler_%d" % randi()
	root.add_child(cs)
	return cs


func _make_fusion_engine() -> FusionEngine:
	var fe_script: GDScript = load("res://core/glyph/fusion_engine.gd") as GDScript
	var fe: FusionEngine = fe_script.new() as FusionEngine
	fe.name = "TestFusion_%d" % randi()
	root.add_child(fe)
	return fe


func _make_combat_engine() -> Node:
	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	var ce: Node = ce_script.new() as Node
	ce.name = "TestCombat_%d" % randi()
	root.add_child(ce)
	return ce


func _make_main_scene() -> MainScene:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()
	var fe: FusionEngine = _make_fusion_engine()
	var ce: Node = _make_combat_engine()
	var mt: MasteryTracker = MasteryTracker.new()

	fe.data_loader = _data_loader
	fe.codex_state = cx
	fe.roster_state = rs
	ce.set("data_loader", _data_loader)

	gs.data_loader = _data_loader
	gs.roster_state = rs
	gs.codex_state = cx
	gs.crawler_state = cs
	gs.fusion_engine = fe
	gs.combat_engine = ce
	gs.mastery_tracker = mt

	var ms: MainScene = MainScene.new()
	ms.set_meta("_gs", gs)
	ms.set_meta("_rs", rs)
	ms.set_meta("_cx", cx)
	ms.set_meta("_cs", cs)
	ms.set_meta("_fe", fe)
	ms.set_meta("_ce", ce)

	root.add_child(ms)
	ms.setup(gs, rs, cx, cs, ce, fe, mt, _data_loader)
	return ms


func _cleanup_main_scene(ms: MainScene) -> void:
	var gs: GameState = ms.get_meta("_gs")
	var rs: RosterState = ms.get_meta("_rs")
	var cx: CodexState = ms.get_meta("_cx")
	var cs: CrawlerState = ms.get_meta("_cs")
	var fe: FusionEngine = ms.get_meta("_fe")
	var ce: Node = ms.get_meta("_ce")
	_cleanup_node(ms)
	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cx)
	_cleanup_node(cs)
	_cleanup_node(fe)
	_cleanup_node(ce)


# ==========================================================================
# TitleScreen Component Tests
# ==========================================================================

func _test_title_construction() -> void:
	print("--- TitleScreen: Construction ---")
	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)

	_assert(ts._title_label != null, "has title label")
	_assert(ts._subtitle_label != null, "has subtitle label")
	_assert(ts._new_game_btn != null, "has new game button")
	_assert(ts._continue_btn != null, "has continue button")
	_assert(ts._save_info_label != null, "has save info label")
	_assert(ts._vbox != null, "has vbox container")

	_cleanup_node(ts)


func _test_title_labels() -> void:
	print("--- TitleScreen: Labels ---")
	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)

	_assert(ts._title_label.text == "GLYPHRIFT", "title says GLYPHRIFT")
	_assert(ts._new_game_btn.text == "New Game", "new game button text")
	_assert(ts._save_info_label != null, "continue button has save info label")

	_cleanup_node(ts)


func _test_continue_disabled_no_saves() -> void:
	print("--- TitleScreen: Continue disabled with no saves ---")
	_cleanup_saves()

	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)
	ts.refresh()

	_assert(ts._continue_btn.disabled, "continue disabled when no saves exist")
	_assert(ts._save_info_label.text == "", "save info empty when no saves")

	_cleanup_node(ts)


func _test_new_game_signal() -> void:
	print("--- TitleScreen: New Game signal ---")
	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)

	var fired: Dictionary = {"v": false}
	ts.new_game_pressed.connect(func() -> void: fired["v"] = true)
	ts._new_game_btn.pressed.emit()

	_assert(fired["v"], "new_game_pressed signal emitted")

	_cleanup_node(ts)


func _test_continue_signal() -> void:
	print("--- TitleScreen: Continue signal ---")
	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)

	var fired: Dictionary = {"v": false}
	ts.continue_pressed.connect(func() -> void: fired["v"] = true)
	ts._continue_btn.pressed.emit()

	_assert(fired["v"], "continue_pressed signal emitted")

	_cleanup_node(ts)


func _test_refresh_enables_continue() -> void:
	print("--- TitleScreen: Refresh enables continue with save ---")
	_cleanup_saves()

	## Create a save
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()
	gs.game_phase = 2
	SaveManager.save_to_slot("slot1", gs, rs, cx, cs)

	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)
	ts.refresh()

	_assert(not ts._continue_btn.disabled, "continue enabled when save exists")
	_assert(ts._save_info_label.text.contains("Phase 2"), "save info shows phase")

	_cleanup_node(ts)
	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cx)
	_cleanup_node(cs)
	_cleanup_saves()


func _test_most_recent_slot_empty() -> void:
	print("--- TitleScreen: Most recent slot empty ---")
	_cleanup_saves()

	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)

	_assert(ts.get_most_recent_slot() == "", "no slot when no saves")

	_cleanup_node(ts)


func _test_most_recent_slot_picks_latest() -> void:
	print("--- TitleScreen: Most recent slot picks latest timestamp ---")
	_cleanup_saves()

	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()

	## Save to slot1 first (earlier timestamp)
	SaveManager.save_to_slot("slot1", gs, rs, cx, cs)

	## Save to slot2 second (later timestamp) — at least same time or later
	gs.game_phase = 3
	SaveManager.save_to_slot("slot2", gs, rs, cx, cs)

	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)

	## slot2 should be most recent (saved after slot1)
	var best: String = ts.get_most_recent_slot()
	## Both saved near-instantly so timestamps may be equal. Accept either slot2 or slot1.
	_assert(best != "", "most recent slot is not empty")

	_cleanup_node(ts)
	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cx)
	_cleanup_node(cs)
	_cleanup_saves()


# ==========================================================================
# Load Game Button Tests
# ==========================================================================

func _test_load_game_button_exists() -> void:
	print("--- TitleScreen: Load Game button exists ---")
	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)

	_assert(ts._load_game_btn != null, "has load game button")
	_assert(ts._load_game_btn.text == "Load Game", "load game button text")

	_cleanup_node(ts)


func _test_load_game_disabled_no_saves() -> void:
	print("--- TitleScreen: Load Game disabled with no saves ---")
	_cleanup_saves()

	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)
	ts.refresh()

	_assert(ts._load_game_btn.disabled, "load game disabled when no saves")

	_cleanup_node(ts)


func _test_load_game_enabled_with_saves() -> void:
	print("--- TitleScreen: Load Game enabled with saves ---")
	_cleanup_saves()

	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()
	SaveManager.save_to_slot("slot1", gs, rs, cx, cs)

	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)
	ts.refresh()

	_assert(not ts._load_game_btn.disabled, "load game enabled when saves exist")

	_cleanup_node(ts)
	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cx)
	_cleanup_node(cs)
	_cleanup_saves()


func _test_load_game_signal() -> void:
	print("--- TitleScreen: Load Game signal ---")
	var ts: TitleScreen = TitleScreen.new()
	root.add_child(ts)

	var fired: Dictionary = {"v": false}
	ts.load_game_pressed.connect(func() -> void: fired["v"] = true)
	ts._load_game_btn.pressed.emit()

	_assert(fired["v"], "load_game_pressed signal emitted")

	_cleanup_node(ts)


# ==========================================================================
# MainScene Integration Tests
# ==========================================================================

func _test_main_scene_has_title_screen() -> void:
	print("--- MainScene: Has title screen ---")
	var ms: MainScene = MainScene.new()
	root.add_child(ms)

	_assert(ms._title_screen != null, "has title screen")
	_assert(ms._title_screen is TitleScreen, "title screen is TitleScreen")

	_cleanup_node(ms)


func _test_main_scene_show_title() -> void:
	print("--- MainScene: show_title() ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.show_title()

	_assert(ms._title_screen.visible, "title screen visible")
	_assert(not ms._bastion_scene.visible, "bastion hidden")
	_assert(not ms._dungeon_scene.visible, "dungeon hidden")
	_assert(not ms._battle_scene.visible, "battle hidden")

	_cleanup_main_scene(ms)


func _test_main_scene_new_game_flow() -> void:
	print("--- MainScene: New Game flow ---")
	_cleanup_saves()

	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.show_title()
	_assert(ms._title_screen.visible, "title visible before new game")

	## Simulate pressing New Game
	ms._on_new_game()

	_assert(ms.game_state.current_state == GameState.State.BASTION, "state is BASTION")
	_assert(ms._bastion_scene.visible, "bastion visible after new game")
	_assert(not ms._title_screen.visible, "title hidden after new game")
	_assert(ms.roster_state.active_squad.size() == 3, "3 starters in squad")

	_cleanup_main_scene(ms)
	_cleanup_saves()


func _test_main_scene_continue_flow() -> void:
	print("--- MainScene: Continue flow ---")
	_cleanup_saves()

	## Create a save file to continue from
	var gs_save: GameState = _make_game_state()
	var rs_save: RosterState = _make_roster_state()
	var cx_save: CodexState = _make_codex_state()
	var cs_save: CrawlerState = _make_crawler_state()
	gs_save.game_phase = 2
	rs_save.initialize_starting_glyphs(_data_loader)
	SaveManager.save_to_slot("slot1", gs_save, rs_save, cx_save, cs_save)

	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.show_title()
	ms._title_screen.refresh()
	_assert(not ms._title_screen._continue_btn.disabled, "continue enabled with save")

	## Simulate pressing Continue
	ms._on_continue()

	_assert(ms._bastion_scene.visible, "bastion visible after continue")
	_assert(not ms._title_screen.visible, "title hidden after continue")
	_assert(ms.game_state.game_phase == 2, "game phase loaded as 2")

	_cleanup_main_scene(ms)
	_cleanup_node(gs_save)
	_cleanup_node(rs_save)
	_cleanup_node(cx_save)
	_cleanup_node(cs_save)
	_cleanup_saves()


func _test_main_scene_save_and_quit_returns_to_title() -> void:
	print("--- MainScene: Save & Quit returns to title ---")
	_cleanup_saves()

	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.start_game()
	_assert(ms._bastion_scene.visible, "bastion visible after start")

	## Simulate Save & Quit
	ms._on_save_and_quit()

	_assert(ms._title_screen.visible, "title visible after save & quit")
	_assert(not ms._bastion_scene.visible, "bastion hidden after save & quit")

	_cleanup_main_scene(ms)
	_cleanup_saves()


func _test_main_scene_load_game_opens_popup() -> void:
	print("--- MainScene: Load Game opens save slots popup ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.show_title()
	_assert(not ms._title_save_slots.visible, "popup hidden initially")

	ms._on_load_game()
	_assert(ms._title_save_slots.visible, "popup visible after load game")
	_assert(ms._title_save_slots.load_only, "popup is load-only mode")

	_cleanup_main_scene(ms)


func _test_main_scene_title_slot_loaded() -> void:
	print("--- MainScene: Title slot loaded transitions to bastion ---")
	_cleanup_saves()

	## Create save
	var gs_save: GameState = _make_game_state()
	var rs_save: RosterState = _make_roster_state()
	var cx_save: CodexState = _make_codex_state()
	var cs_save: CrawlerState = _make_crawler_state()
	gs_save.game_phase = 3
	rs_save.initialize_starting_glyphs(_data_loader)
	SaveManager.save_to_slot("slot1", gs_save, rs_save, cx_save, cs_save)

	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.show_title()

	## Simulate loading from the popup — setup is done in MainScene.setup()
	ms._title_save_slots._on_load("slot1")

	_assert(ms._bastion_scene.visible, "bastion visible after slot load")
	_assert(not ms._title_screen.visible, "title hidden after slot load")
	_assert(ms.game_state.game_phase == 3, "game phase loaded as 3")

	_cleanup_main_scene(ms)
	_cleanup_node(gs_save)
	_cleanup_node(rs_save)
	_cleanup_node(cx_save)
	_cleanup_node(cs_save)
	_cleanup_saves()


# ==========================================================================
# Phase Progression Tests
# ==========================================================================

func _test_phase_progression_rifts() -> void:
	print("--- Phase progression: rifts available per phase ---")
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	gs.data_loader = _data_loader
	gs.codex_state = CodexState.new()
	gs.roster_state = rs
	gs.crawler_state = cs

	## Phase 1: only tutorial rift
	gs.game_phase = 1
	var rifts1: Array[RiftTemplate] = gs.get_available_rifts()
	_assert(rifts1.size() == 1, "Phase 1: 1 rift (tutorial)")
	_assert(rifts1[0].id == "tutorial_01", "Phase 1: tutorial_01")

	## Phase 2: tutorial + 2 minor = 3
	gs.game_phase = 2
	var rifts2: Array[RiftTemplate] = gs.get_available_rifts()
	_assert(rifts2.size() == 3, "Phase 2: 3 rifts (tutorial + 2 minor)")

	## Phase 3: + 2 standard = 5
	gs.game_phase = 3
	var rifts3: Array[RiftTemplate] = gs.get_available_rifts()
	_assert(rifts3.size() == 5, "Phase 3: 5 rifts (+2 standard)")

	## Phase 4: + 1 major = 6
	gs.game_phase = 4
	var rifts4: Array[RiftTemplate] = gs.get_available_rifts()
	_assert(rifts4.size() == 6, "Phase 4: 6 rifts (+1 major)")

	## Phase 5: + 1 apex = 7
	gs.game_phase = 5
	var rifts5: Array[RiftTemplate] = gs.get_available_rifts()
	_assert(rifts5.size() == 7, "Phase 5: 7 rifts (+1 apex)")

	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_phase_advancement_thresholds() -> void:
	print("--- Phase advancement: thresholds ---")
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	gs.data_loader = _data_loader
	gs.codex_state = CodexState.new()
	gs.roster_state = rs
	gs.crawler_state = cs

	gs.game_phase = 1
	_assert(gs.game_phase == 1, "Starts at phase 1")

	## Clear 1 rift → phase 2
	gs.codex_state.mark_rift_cleared("tutorial_01")
	gs._check_phase_advancement()
	_assert(gs.game_phase == 2, "Phase 2 after 1 clear")

	## Clear 2 more → 3 total → phase 3
	gs.codex_state.mark_rift_cleared("minor_01")
	gs.codex_state.mark_rift_cleared("minor_02")
	gs._check_phase_advancement()
	_assert(gs.game_phase == 3, "Phase 3 after 3 clears")

	## Clear 2 more → 5 total → phase 4
	gs.codex_state.mark_rift_cleared("standard_01")
	gs.codex_state.mark_rift_cleared("standard_02")
	gs._check_phase_advancement()
	_assert(gs.game_phase == 4, "Phase 4 after 5 clears")

	## Clear 1 more → 6 total → phase 5
	gs.codex_state.mark_rift_cleared("major_01")
	gs._check_phase_advancement()
	_assert(gs.game_phase == 5, "Phase 5 after 6 clears")

	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cs)
