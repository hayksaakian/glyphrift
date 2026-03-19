extends SceneTree

var _data_loader: Node = null
var pass_count: int = 0
var fail_count: int = 0


func _init() -> void:
	var dl_script: GDScript = load("res://core/data_loader.gd") as GDScript
	_data_loader = dl_script.new() as Node
	_data_loader.name = "DataLoader"
	root.add_child(_data_loader)

	await process_frame
	_run_tests()
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — Session 9 Tests")
	print("  Codex UI + NPC Dialogue + Event Rooms")
	print("========================================")
	print("")

	## CodexBrowser
	_test_codex_construction()
	_test_codex_tabs_switch()
	_test_codex_glyph_registry_all_undiscovered()
	_test_codex_glyph_registry_discovered()
	_test_codex_discovery_counter()
	_test_codex_detail_popup_on_click()
	_test_codex_undiscovered_no_popup()
	_test_codex_fusion_log_empty()
	_test_codex_fusion_log_entries()
	_test_codex_rift_atlas()
	_test_codex_rift_atlas_cleared()
	_test_codex_back_signal()
	_test_codex_species_sorted_by_tier()
	_test_codex_hint_text()
	_test_codex_panel_art_colors()

	## NpcPanel
	_test_npc_construction()
	_test_npc_show_kael()
	_test_npc_show_lira()
	_test_npc_show_maro()
	_test_npc_phase_dialogue()
	_test_npc_phase_5_dialogue()
	_test_npc_close_signal()
	_test_npc_portrait_colors()

	## BastionScene integration
	_test_bastion_codex_button()
	_test_bastion_codex_navigation()
	_test_bastion_codex_back_to_hub()
	_test_bastion_npc_buttons_exist()
	_test_bastion_npc_panel_show()
	_test_bastion_npc_unread_indicator()
	_test_bastion_all_screens_hide_codex()

	## NPC Quests
	_test_quest_data_loaded()
	_test_quest_active_from_phase_1()
	_test_quest_active_state()
	_test_quest_complete_and_reward()
	_test_quest_panel_display()

	## PuzzleSequence
	_test_puzzle_sequence_construction()
	_test_puzzle_sequence_correct_order()
	_test_puzzle_sequence_wrong_order()
	_test_puzzle_sequence_start_with_order()
	_test_puzzle_sequence_attempt_method()
	_test_puzzle_sequence_signal()

	## PuzzleConduit
	_test_puzzle_conduit_construction()
	_test_puzzle_conduit_correct_cycle()
	_test_puzzle_conduit_wrong_cycle()
	_test_puzzle_conduit_attempt_method()
	_test_puzzle_conduit_reward_type()

	## PuzzleEcho
	_test_puzzle_echo_construction()
	_test_puzzle_echo_start_with_glyph()
	_test_puzzle_echo_challenge_signal()
	_test_puzzle_echo_walk_past_signal()
	_test_puzzle_echo_glyph_display()

	## DungeonScene event integration
	_test_dungeon_puzzle_state_exists()
	_test_dungeon_puzzle_type_assignment()
	_test_dungeon_puzzle_sequence_reward()
	_test_dungeon_puzzle_conduit_reward()
	_test_dungeon_echo_combat_flow()
	_test_dungeon_echo_capture_on_win()
	_test_dungeon_puzzle_room_cleared()
	_test_dungeon_reveal_random_species()

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

func _make_glyph(species_id: String = "zapplet") -> GlyphInstance:
	var sp: GlyphSpecies = _data_loader.get_species(species_id)
	var g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
	g.mastery_objectives = MasteryTracker.build_mastery_track(sp, _data_loader.mastery_pools)
	return g


func _make_mastered_glyph(species_id: String = "zapplet") -> GlyphInstance:
	var g: GlyphInstance = _make_glyph(species_id)
	g.is_mastered = true
	for i: int in range(g.mastery_objectives.size()):
		g.mastery_objectives[i]["completed"] = true
	return g


func _make_codex_state() -> CodexState:
	var cx_script: GDScript = load("res://core/progression/codex_state.gd") as GDScript
	var cx: CodexState = cx_script.new() as CodexState
	cx.name = "TestCodex_%d" % randi()
	root.add_child(cx)
	return cx


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


func _make_dungeon_state_with_floors(floors: Array[Dictionary], template_id: String = "tutorial_01") -> DungeonState:
	var ds: DungeonState = DungeonState.new()
	var crawler: CrawlerState = _make_crawler_state()
	ds.crawler = crawler
	var template: RiftTemplate = _data_loader.get_rift_template(template_id)
	ds.initialize_with_floors(template, floors)
	return ds


func _make_puzzle_floor() -> Dictionary:
	return {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "event", "visited": false, "revealed": true},
			{"id": "r2", "x": 2, "y": 0, "type": "exit", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"], ["r1", "r2"]],
	}


func _make_bastion_scene() -> BastionScene:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()
	var fe: FusionEngine = _make_fusion_engine()

	fe.data_loader = _data_loader
	fe.codex_state = cx
	fe.roster_state = rs

	gs.data_loader = _data_loader
	gs.roster_state = rs
	gs.codex_state = cx
	gs.crawler_state = cs
	gs.fusion_engine = fe

	var bs: BastionScene = BastionScene.new()
	bs.set_meta("_gs", gs)
	bs.set_meta("_rs", rs)
	bs.set_meta("_cx", cx)
	bs.set_meta("_cs", cs)
	bs.set_meta("_fe", fe)
	root.add_child(bs)
	bs.setup(gs, rs, cx, cs, fe, _data_loader)
	return bs


func _cleanup_bastion(bs: BastionScene) -> void:
	var gs: GameState = bs.get_meta("_gs")
	var rs: RosterState = bs.get_meta("_rs")
	var cx: CodexState = bs.get_meta("_cx")
	var cs: CrawlerState = bs.get_meta("_cs")
	var fe: FusionEngine = bs.get_meta("_fe")
	_cleanup_node(bs)
	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cx)
	_cleanup_node(cs)
	_cleanup_node(fe)


func _collect_label_text(node: Node) -> String:
	var text: String = ""
	if node is Label:
		text += (node as Label).text + " "
	for child: Node in node.get_children():
		text += _collect_label_text(child)
	return text


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()


# ==========================================================================
# CodexBrowser Tests
# ==========================================================================

func _test_codex_construction() -> void:
	print("--- CodexBrowser: Construction ---")
	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	_assert(cb._glyph_grid != null, "glyph grid exists")
	_assert(cb._fusion_vbox != null, "fusion vbox exists")
	_assert(cb._rift_vbox != null, "rift vbox exists")
	_assert(cb._detail_popup != null, "detail popup exists")
	_cleanup_node(cb)


func _test_codex_tabs_switch() -> void:
	print("--- CodexBrowser: Tab Switching ---")
	var cx: CodexState = _make_codex_state()
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)

	## Default tab is GLYPH_REGISTRY
	_assert(cb.get_current_tab() == CodexBrowser.Tab.GLYPH_REGISTRY, "default tab is glyph registry")

	## Switch to Fusion Log
	cb._fusion_tab_btn.pressed.emit()
	_assert(cb.get_current_tab() == CodexBrowser.Tab.FUSION_LOG, "switched to fusion log")
	_assert(cb._fusion_panel.visible, "fusion panel visible")
	_assert(not cb._glyph_panel.visible, "glyph panel hidden")

	## Switch to Rift Atlas
	cb._rift_tab_btn.pressed.emit()
	_assert(cb.get_current_tab() == CodexBrowser.Tab.RIFT_ATLAS, "switched to rift atlas")
	_assert(cb._rift_panel.visible, "rift panel visible")

	## Switch back to Glyph Registry
	cb._glyph_tab_btn.pressed.emit()
	_assert(cb.get_current_tab() == CodexBrowser.Tab.GLYPH_REGISTRY, "back to glyph registry")
	_assert(cb._glyph_panel.visible, "glyph panel visible again")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_glyph_registry_all_undiscovered() -> void:
	print("--- CodexBrowser: All Undiscovered ---")
	var cx: CodexState = _make_codex_state()
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb.refresh()

	_assert(cb._glyph_grid.get_child_count() == 18, "18 species panels")
	## All should show "???" name
	var first_panel: Control = cb._glyph_grid.get_child(0)
	_assert(first_panel.get_meta("is_discovered") == false, "first panel undiscovered")
	_assert(cb._glyph_counter.text == "0/18 Discovered", "counter shows 0")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_glyph_registry_discovered() -> void:
	print("--- CodexBrowser: Discovered Species ---")
	var cx: CodexState = _make_codex_state()
	cx.discover_species("zapplet")
	cx.discover_species("stonepaw")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb.refresh()

	## Find the zapplet panel
	var found_discovered: bool = false
	for i: int in range(cb._glyph_grid.get_child_count()):
		var panel: Control = cb._glyph_grid.get_child(i)
		if panel.get_meta("species_id") == "zapplet":
			_assert(panel.get_meta("is_discovered") == true, "zapplet discovered")
			found_discovered = true
			break
	_assert(found_discovered, "found zapplet panel")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_discovery_counter() -> void:
	print("--- CodexBrowser: Discovery Counter ---")
	var cx: CodexState = _make_codex_state()
	cx.discover_species("zapplet")
	cx.discover_species("stonepaw")
	cx.discover_species("driftwisp")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb.refresh()

	_assert(cb._glyph_counter.text == "3/18 Discovered", "counter shows 3/18")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_detail_popup_on_click() -> void:
	print("--- CodexBrowser: Detail Popup on Click ---")
	var cx: CodexState = _make_codex_state()
	cx.discover_species("zapplet")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb.refresh()

	## Simulate click on discovered species
	cb._on_species_panel_clicked("zapplet")
	_assert(cb._detail_popup.visible, "detail popup visible after click")
	_assert(cb._detail_popup.species != null, "popup has species")
	_assert(cb._detail_popup.species.id == "zapplet", "popup shows zapplet")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_undiscovered_no_popup() -> void:
	print("--- CodexBrowser: Undiscovered No Popup ---")
	var cx: CodexState = _make_codex_state()
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb.refresh()

	## Click undiscovered — no popup
	cb._on_species_panel_clicked("zapplet")
	_assert(not cb._detail_popup.visible, "no popup for undiscovered")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_fusion_log_empty() -> void:
	print("--- CodexBrowser: Fusion Log Empty ---")
	var cx: CodexState = _make_codex_state()
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb._fusion_tab_btn.pressed.emit()

	_assert(cb._fusion_vbox.get_child_count() == 1, "one child (empty label)")
	var child: Label = cb._fusion_vbox.get_child(0) as Label
	_assert(child != null and child.text == "No fusions recorded.", "empty state text")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_fusion_log_entries() -> void:
	print("--- CodexBrowser: Fusion Log Entries ---")
	var cx: CodexState = _make_codex_state()
	cx.log_fusion("zapplet", "stonepaw", "thunderclaw")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb._fusion_tab_btn.pressed.emit()

	_assert(cb._fusion_vbox.get_child_count() == 1, "one fusion entry")
	var entry: PanelContainer = cb._fusion_vbox.get_child(0) as PanelContainer
	_assert(entry != null, "entry is a PanelContainer")
	var entry_text: String = _collect_label_text(entry)
	_assert(entry_text.contains("Zapplet"), "entry contains Zapplet name")
	_assert(entry_text.contains("Stonepaw"), "entry contains Stonepaw name")
	_assert(entry_text.contains("Thunderclaw"), "entry contains Thunderclaw name")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_rift_atlas() -> void:
	print("--- CodexBrowser: Rift Atlas ---")
	var cx: CodexState = _make_codex_state()
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx
	gs.roster_state = _make_roster_state()
	gs.crawler_state = _make_crawler_state()
	gs.game_phase = 1

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb._rift_tab_btn.pressed.emit()

	## Phase 1 has tutorial_01
	_assert(cb._rift_vbox.get_child_count() >= 1, "at least one rift shown")

	_cleanup_node(cb)
	_cleanup_node(gs.roster_state)
	_cleanup_node(gs.crawler_state)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_rift_atlas_cleared() -> void:
	print("--- CodexBrowser: Rift Atlas Cleared ---")
	var cx: CodexState = _make_codex_state()
	cx.mark_rift_cleared("tutorial_01")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx
	gs.roster_state = _make_roster_state()
	gs.crawler_state = _make_crawler_state()
	gs.game_phase = 1

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb._rift_tab_btn.pressed.emit()

	## Find a row with "CLEARED"
	var found_cleared: bool = false
	for i: int in range(cb._rift_vbox.get_child_count()):
		var row: Node = cb._rift_vbox.get_child(i)
		if row is HBoxContainer:
			for j: int in range(row.get_child_count()):
				var child: Node = row.get_child(j)
				if child is Label and (child as Label).text == "CLEARED":
					found_cleared = true
					break
	_assert(found_cleared, "cleared marker visible")

	_cleanup_node(cb)
	_cleanup_node(gs.roster_state)
	_cleanup_node(gs.crawler_state)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_back_signal() -> void:
	print("--- CodexBrowser: Back Signal ---")
	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)

	var signal_data: Dictionary = {"emitted": false}
	cb.back_pressed.connect(func() -> void: signal_data["emitted"] = true)
	cb._back_btn.pressed.emit()
	_assert(signal_data["emitted"], "back_pressed signal emitted")

	_cleanup_node(cb)


func _test_codex_species_sorted_by_tier() -> void:
	print("--- CodexBrowser: Species Sorted by Tier ---")
	var cx: CodexState = _make_codex_state()
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb.refresh()

	## First 6 panels should be T1 (6 T1 species)
	var first_species_id: String = (cb._glyph_grid.get_child(0) as Control).get_meta("species_id")
	var first_sp: GlyphSpecies = _data_loader.get_species(first_species_id)
	_assert(first_sp.tier == 1, "first panel is T1 species")

	## Last panels should be T4
	var last_idx: int = cb._glyph_grid.get_child_count() - 1
	var last_species_id: String = (cb._glyph_grid.get_child(last_idx) as Control).get_meta("species_id")
	var last_sp: GlyphSpecies = _data_loader.get_species(last_species_id)
	_assert(last_sp.tier == 4, "last panel is T4 species")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_hint_text() -> void:
	print("--- CodexBrowser: Hint Text ---")
	var cx: CodexState = _make_codex_state()
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb.refresh()

	## Codex entries have hints
	_assert(_data_loader.codex_entries.has("zapplet"), "codex entry exists for zapplet")
	_assert(_data_loader.codex_entries["zapplet"].has("hint"), "hint field exists")

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_codex_panel_art_colors() -> void:
	print("--- CodexBrowser: Panel Art Colors ---")
	var cx: CodexState = _make_codex_state()
	cx.discover_species("zapplet")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx

	var cb: CodexBrowser = CodexBrowser.new()
	root.add_child(cb)
	cb.setup(_data_loader, cx, gs)
	cb.refresh()

	## Find zapplet panel — its art should be electric color
	for i: int in range(cb._glyph_grid.get_child_count()):
		var panel: Control = cb._glyph_grid.get_child(i)
		if panel.get_meta("species_id") == "zapplet":
			## Discovered — art should have affinity color (not grey)
			_assert(panel.get_meta("is_discovered") == true, "zapplet is discovered with art color")
			break

	_cleanup_node(cb)
	_cleanup_node(gs)
	_cleanup_node(cx)


# ==========================================================================
# NpcPanel Tests
# ==========================================================================

func _test_npc_construction() -> void:
	print("--- NpcPanel: Construction ---")
	var np: NpcPanel = NpcPanel.new()
	root.add_child(np)
	_assert(np._panel != null, "panel exists")
	_assert(np._name_label != null, "name label exists")
	_assert(np._title_label != null, "title label exists")
	_assert(np._dialogue_label != null, "dialogue label exists")
	_assert(not np.visible, "hidden by default")
	_cleanup_node(np)


func _test_npc_show_kael() -> void:
	print("--- NpcPanel: Show Kael ---")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.game_phase = 1

	var np: NpcPanel = NpcPanel.new()
	root.add_child(np)
	np.setup(_data_loader, gs)
	np.show_npc("kael")

	_assert(np.visible, "visible after show_npc")
	_assert(np._name_label.text == "Kael", "name is Kael")
	_assert(np._title_label.text == "Veteran Warden", "title is correct")
	_assert(np._dialogue_label.text.length() > 0, "dialogue has text")

	_cleanup_node(np)
	_cleanup_node(gs)


func _test_npc_show_lira() -> void:
	print("--- NpcPanel: Show Lira ---")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.game_phase = 1

	var np: NpcPanel = NpcPanel.new()
	root.add_child(np)
	np.setup(_data_loader, gs)
	np.show_npc("lira")

	_assert(np._name_label.text == "Lira", "name is Lira")
	_assert(np._title_label.text == "Rift Researcher", "title is correct")

	_cleanup_node(np)
	_cleanup_node(gs)


func _test_npc_show_maro() -> void:
	print("--- NpcPanel: Show Maro ---")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.game_phase = 1

	var np: NpcPanel = NpcPanel.new()
	root.add_child(np)
	np.setup(_data_loader, gs)
	np.show_npc("maro")

	_assert(np._name_label.text == "Maro", "name is Maro")
	_assert(np._title_label.text == "Crawler Mechanic", "title is correct")

	_cleanup_node(np)
	_cleanup_node(gs)


func _test_npc_phase_dialogue() -> void:
	print("--- NpcPanel: Phase Dialogue ---")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.game_phase = 2

	var np: NpcPanel = NpcPanel.new()
	root.add_child(np)
	np.setup(_data_loader, gs)
	np.show_npc("kael")

	## Phase 2 dialogue should be non-empty (randomly picks from phase 2 lines)
	_assert(np._dialogue_label.text.length() > 0, "phase 2 Kael has dialogue")

	_cleanup_node(np)
	_cleanup_node(gs)


func _test_npc_phase_5_dialogue() -> void:
	print("--- NpcPanel: Phase 5 Dialogue ---")
	var gs: GameState = _make_game_state()
	gs.data_loader = _data_loader
	gs.game_phase = 5

	var np: NpcPanel = NpcPanel.new()
	root.add_child(np)
	np.setup(_data_loader, gs)
	np.show_npc("kael")

	## Phase 5 dialogue exists and loads
	_assert(np._dialogue_label.text.length() > 0, "phase 5 Kael has dialogue")
	## Phase 5 should NOT use phase 3 content (which mentions Major Rift)
	_assert(not np._dialogue_label.text.contains("Major Rift"), "uses phase 5 dialogue, not phase 3")

	_cleanup_node(np)
	_cleanup_node(gs)


func _test_npc_close_signal() -> void:
	print("--- NpcPanel: Close Signal ---")
	var np: NpcPanel = NpcPanel.new()
	root.add_child(np)

	var signal_data: Dictionary = {"emitted": false}
	np.closed.connect(func() -> void: signal_data["emitted"] = true)

	np.visible = true
	np._close_btn.pressed.emit()

	_assert(signal_data["emitted"], "closed signal emitted")
	_assert(not np.visible, "hidden after close")

	_cleanup_node(np)


func _test_npc_portrait_colors() -> void:
	print("--- NpcPanel: Portrait Colors ---")
	_assert(NpcPanel.NPC_COLORS.has("kael"), "kael color defined")
	_assert(NpcPanel.NPC_COLORS.has("lira"), "lira color defined")
	_assert(NpcPanel.NPC_COLORS.has("maro"), "maro color defined")

	## Check approximate colors
	var kael_color: Color = NpcPanel.NPC_COLORS["kael"]
	_assert(kael_color.r > 0.7, "kael is reddish")
	var lira_color: Color = NpcPanel.NPC_COLORS["lira"]
	_assert(lira_color.b > 0.7, "lira is bluish/teal")
	var maro_color: Color = NpcPanel.NPC_COLORS["maro"]
	_assert(maro_color.r > 0.7, "maro is orangish")


# ==========================================================================
# BastionScene Integration Tests
# ==========================================================================

func _test_bastion_codex_button() -> void:
	print("--- BastionScene: Codex Button ---")
	var bs: BastionScene = _make_bastion_scene()
	_assert(bs._codex_btn != null, "codex button exists")
	_assert(bs._codex_btn.text == "Codex", "codex button text")
	_cleanup_bastion(bs)


func _test_bastion_codex_navigation() -> void:
	print("--- BastionScene: Codex Navigation ---")
	var bs: BastionScene = _make_bastion_scene()
	bs.show_hub()

	bs._codex_btn.pressed.emit()
	_assert(bs.get_sub_screen() == BastionScene.SubScreen.CODEX, "codex screen active")
	_assert(bs._codex_browser.visible, "codex browser visible")
	_assert(not bs._hub.visible, "hub hidden")

	_cleanup_bastion(bs)


func _test_bastion_codex_back_to_hub() -> void:
	print("--- BastionScene: Codex Back to Hub ---")
	var bs: BastionScene = _make_bastion_scene()
	bs.show_hub()

	bs._codex_btn.pressed.emit()
	_assert(bs.get_sub_screen() == BastionScene.SubScreen.CODEX, "in codex")

	bs._codex_browser.back_pressed.emit()
	_assert(bs.get_sub_screen() == BastionScene.SubScreen.HUB, "back to hub")
	_assert(bs._hub.visible, "hub visible again")
	_assert(not bs._codex_browser.visible, "codex hidden")

	_cleanup_bastion(bs)


func _test_bastion_npc_buttons_exist() -> void:
	print("--- BastionScene: NPC Buttons ---")
	var bs: BastionScene = _make_bastion_scene()
	_assert(bs._npc_kael_btn != null, "kael button exists")
	_assert(bs._npc_lira_btn != null, "lira button exists")
	_assert(bs._npc_maro_btn != null, "maro button exists")
	## NPC buttons are portrait cards — check they contain the name in a child label
	_assert(bs._npc_kael_btn.custom_minimum_size.y > 60, "kael card has portrait height")
	_assert(bs._npc_lira_btn.custom_minimum_size.y > 60, "lira card has portrait height")
	_assert(bs._npc_maro_btn.custom_minimum_size.y > 60, "maro card has portrait height")
	_cleanup_bastion(bs)


func _test_bastion_npc_panel_show() -> void:
	print("--- BastionScene: NPC Panel Show ---")
	var bs: BastionScene = _make_bastion_scene()
	bs.game_state.game_phase = 1

	bs._npc_kael_btn.pressed.emit()
	_assert(bs._npc_panel.visible, "NPC panel visible after kael button")
	_assert(bs._npc_panel._name_label.text == "Kael", "shows Kael")

	_cleanup_bastion(bs)


func _test_bastion_npc_unread_indicator() -> void:
	print("--- BastionScene: NPC Unread Indicator ---")
	var bs: BastionScene = _make_bastion_scene()
	bs.game_state.game_phase = 1

	## On first show_hub, all NPCs should have unread indicator (phase 1 > read 0)
	bs.show_hub()
	var kael_ind: Label = bs._npc_indicators.get("kael") as Label
	var lira_ind: Label = bs._npc_indicators.get("lira") as Label
	_assert(kael_ind != null, "Kael has indicator label")
	_assert(kael_ind.visible, "Kael indicator visible when unread")

	## Click Kael to read — indicator should clear
	bs._npc_kael_btn.pressed.emit()
	bs._npc_panel.hide_popup()
	_assert(not kael_ind.visible, "Kael indicator hidden after reading")

	## Lira should still have indicator (not yet read)
	_assert(lira_ind.visible, "Lira indicator still visible (unread)")

	## Advance phase — Kael should get indicator again
	bs.game_state.game_phase = 2
	bs.show_hub()
	_assert(kael_ind.visible, "Kael indicator visible again at new phase")

	_cleanup_bastion(bs)


func _test_bastion_all_screens_hide_codex() -> void:
	print("--- BastionScene: All Screens Hide Codex ---")
	var bs: BastionScene = _make_bastion_scene()
	bs.show_hub()

	## Go to codex
	bs._codex_btn.pressed.emit()
	_assert(bs._codex_browser.visible, "codex visible")

	## Switch to barracks — codex should hide
	bs._barracks_btn.pressed.emit()
	_assert(not bs._codex_browser.visible, "codex hidden when in barracks")

	## Switch to fusion
	bs._codex_btn.pressed.emit()
	bs._fusion_btn.pressed.emit()
	_assert(not bs._codex_browser.visible, "codex hidden when in fusion")

	## Switch to rift gate
	bs._codex_btn.pressed.emit()
	bs._rift_gate_btn.pressed.emit()
	_assert(not bs._codex_browser.visible, "codex hidden when in rift gate")

	_cleanup_bastion(bs)


# ==========================================================================
# PuzzleSequence Tests
# ==========================================================================

func _test_puzzle_sequence_construction() -> void:
	print("--- PuzzleSequence: Construction ---")
	var ps: PuzzleSequence = PuzzleSequence.new()
	root.add_child(ps)
	_assert(ps._pillar_buttons.size() == 4, "4 pillar buttons")
	_assert(not ps.visible, "hidden by default")
	_cleanup_node(ps)


func _test_puzzle_sequence_correct_order() -> void:
	print("--- PuzzleSequence: Correct Order ---")
	var ps: PuzzleSequence = PuzzleSequence.new()
	root.add_child(ps)

	var order: Array[int] = [0, 1, 2]
	ps.start_with_order(order, true)

	_assert(ps.visible, "visible after start")
	_assert(ps.get_correct_order() == order, "correct order set")
	_assert(ps.attempt_sequence(order), "correct sequence accepted")

	_cleanup_node(ps)


func _test_puzzle_sequence_wrong_order() -> void:
	print("--- PuzzleSequence: Wrong Order ---")
	var ps: PuzzleSequence = PuzzleSequence.new()
	root.add_child(ps)

	var order: Array[int] = [0, 1, 2]
	ps.start_with_order(order, true)

	var wrong: Array[int] = [2, 1, 0]
	_assert(not ps.attempt_sequence(wrong), "wrong sequence rejected")

	_cleanup_node(ps)


func _test_puzzle_sequence_start_with_order() -> void:
	print("--- PuzzleSequence: Start With Order ---")
	var ps: PuzzleSequence = PuzzleSequence.new()
	root.add_child(ps)

	var order: Array[int] = [3, 1, 0, 2]
	ps.start_with_order(order, true)

	_assert(ps._correct_order.size() == 4, "4-element order")
	_assert(ps._input_phase, "in input phase")

	_cleanup_node(ps)


func _test_puzzle_sequence_attempt_method() -> void:
	print("--- PuzzleSequence: Attempt Method ---")
	var ps: PuzzleSequence = PuzzleSequence.new()
	root.add_child(ps)

	ps.start_with_order([1, 2, 3], true)
	_assert(ps.attempt_sequence([1, 2, 3]), "correct via attempt method")
	_assert(not ps.attempt_sequence([1, 2, 0]), "wrong via attempt method")
	_assert(not ps.attempt_sequence([1, 2]), "too short rejected")

	_cleanup_node(ps)


func _test_puzzle_sequence_signal() -> void:
	print("--- PuzzleSequence: Complete Signal ---")
	var ps: PuzzleSequence = PuzzleSequence.new()
	root.add_child(ps)

	var signal_data: Dictionary = {"success": false, "reward": ""}
	ps.puzzle_completed.connect(func(s: bool, r: String, _d: Variant) -> void:
		signal_data["success"] = s
		signal_data["reward"] = r
	)

	ps.start_with_order([0, 1], true)
	## Simulate clicking correct pillars
	ps._on_pillar_pressed(0)
	ps._on_pillar_pressed(1)

	_assert(signal_data["success"] == true, "success signal emitted")
	_assert(signal_data["reward"] == "item", "reward type is item")

	_cleanup_node(ps)


# ==========================================================================
# PuzzleConduit Tests
# ==========================================================================

func _test_puzzle_conduit_construction() -> void:
	print("--- PuzzleConduit: Construction ---")
	var pc: PuzzleConduit = PuzzleConduit.new()
	root.add_child(pc)
	_assert(pc._node_buttons.size() == 4, "4 node buttons (3 cycle + 1 red herring)")
	_assert(not pc.visible, "hidden by default")
	_cleanup_node(pc)


func _test_puzzle_conduit_correct_cycle() -> void:
	print("--- PuzzleConduit: Correct Cycle ---")
	var pc: PuzzleConduit = PuzzleConduit.new()
	root.add_child(pc)

	## Correct: E(0)→W(1), W(1)→G(2), G(2)→E(0)
	var correct: Array[Array] = [[0, 1], [1, 2], [2, 0]]
	_assert(pc.attempt_connections(correct), "correct cycle accepted")

	_cleanup_node(pc)


func _test_puzzle_conduit_wrong_cycle() -> void:
	print("--- PuzzleConduit: Wrong Cycle ---")
	var pc: PuzzleConduit = PuzzleConduit.new()
	root.add_child(pc)

	## Missing the 2→0 connection, has 0→0 instead (invalid)
	var wrong: Array[Array] = [[0, 1], [1, 2], [1, 0]]
	## This has [0,1] twice and is missing [2,0]
	_assert(not pc.attempt_connections(wrong), "wrong cycle rejected")

	_cleanup_node(pc)


func _test_puzzle_conduit_attempt_method() -> void:
	print("--- PuzzleConduit: Attempt Method ---")
	var pc: PuzzleConduit = PuzzleConduit.new()
	root.add_child(pc)

	## Reversed order should still work (order-independent within pairs)
	var reversed: Array[Array] = [[1, 0], [2, 1], [0, 2]]
	_assert(pc.attempt_connections(reversed), "reversed pairs accepted")

	## Too few
	var partial: Array[Array] = [[0, 1], [1, 2]]
	_assert(not pc.attempt_connections(partial), "partial rejected")

	_cleanup_node(pc)


func _test_puzzle_conduit_reward_type() -> void:
	print("--- PuzzleConduit: Reward Type ---")
	var pc: PuzzleConduit = PuzzleConduit.new()
	root.add_child(pc)

	var signal_data: Dictionary = {"reward": ""}
	pc.puzzle_completed.connect(func(_s: bool, r: String, _d: Variant) -> void:
		signal_data["reward"] = r
	)

	pc.start(true)
	## Simulate correct connections via node presses
	pc._on_node_pressed(0)
	pc._on_node_pressed(1)
	pc._on_node_pressed(1)
	pc._on_node_pressed(2)
	pc._on_node_pressed(2)
	pc._on_node_pressed(0)

	_assert(signal_data["reward"] == "codex_reveal", "reward type is codex_reveal")

	_cleanup_node(pc)


# ==========================================================================
# PuzzleEcho Tests
# ==========================================================================

func _test_puzzle_echo_construction() -> void:
	print("--- PuzzleEcho: Construction ---")
	var pe: PuzzleEcho = PuzzleEcho.new()
	root.add_child(pe)
	_assert(pe._challenge_btn != null, "challenge button exists")
	_assert(pe._walk_past_btn != null, "walk past button exists")
	_assert(not pe.visible, "hidden by default")
	_cleanup_node(pe)


func _test_puzzle_echo_start_with_glyph() -> void:
	print("--- PuzzleEcho: Start With Glyph ---")
	var pe: PuzzleEcho = PuzzleEcho.new()
	root.add_child(pe)

	var g: GlyphInstance = _make_glyph("zapplet")
	g.side = "enemy"
	pe.start_with_glyph(g)

	_assert(pe.visible, "visible after start")
	_assert(pe.get_echo_glyph() == g, "echo glyph set")
	_assert(pe._description_label.text.contains("Zapplet"), "description mentions species")

	_cleanup_node(pe)


func _test_puzzle_echo_challenge_signal() -> void:
	print("--- PuzzleEcho: Challenge Signal ---")
	var pe: PuzzleEcho = PuzzleEcho.new()
	root.add_child(pe)

	var signal_data: Dictionary = {"glyph": null}
	pe.echo_combat_requested.connect(func(g: GlyphInstance) -> void:
		signal_data["glyph"] = g
	)

	var g: GlyphInstance = _make_glyph("stonepaw")
	g.side = "enemy"
	pe.start_with_glyph(g)
	pe._on_challenge()

	_assert(signal_data["glyph"] == g, "echo_combat_requested emitted with glyph")
	_assert(not pe.visible, "hidden after challenge")

	_cleanup_node(pe)


func _test_puzzle_echo_walk_past_signal() -> void:
	print("--- PuzzleEcho: Walk Past Signal ---")
	var pe: PuzzleEcho = PuzzleEcho.new()
	root.add_child(pe)

	var signal_data: Dictionary = {"emitted": false, "success": true}
	pe.puzzle_completed.connect(func(s: bool, _r: String, _d: Variant) -> void:
		signal_data["emitted"] = true
		signal_data["success"] = s
	)

	var g: GlyphInstance = _make_glyph("zapplet")
	pe.start_with_glyph(g)
	pe._on_walk_past()

	_assert(signal_data["emitted"], "puzzle_completed emitted on walk past")
	_assert(signal_data["success"] == false, "success is false for walk past")

	_cleanup_node(pe)


func _test_puzzle_echo_glyph_display() -> void:
	print("--- PuzzleEcho: Glyph Display ---")
	var pe: PuzzleEcho = PuzzleEcho.new()
	root.add_child(pe)

	var g: GlyphInstance = _make_glyph("driftwisp")
	g.side = "enemy"
	pe.start_with_glyph(g)

	_assert(pe._glyph_card != null, "glyph card exists")
	_assert(pe._glyph_card.glyph == g, "glyph card displays echo glyph")

	_cleanup_node(pe)


# ==========================================================================
# DungeonScene Event Integration Tests
# ==========================================================================

func _test_dungeon_puzzle_state_exists() -> void:
	print("--- DungeonScene: Event UIState ---")
	var ds_scene: DungeonScene = DungeonScene.new()
	root.add_child(ds_scene)
	## EVENT should be a valid UIState
	_assert(DungeonScene.UIState.EVENT == 7, "EVENT UIState exists")
	_cleanup_node(ds_scene)


func _test_dungeon_puzzle_type_assignment() -> void:
	print("--- DungeonScene: Event Type Assignment ---")
	var floor_data: Dictionary = _make_puzzle_floor()
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])

	var ds_scene: DungeonScene = DungeonScene.new()
	ds_scene.instant_mode = true
	ds_scene.data_loader = _data_loader
	ds_scene.roster_state = _make_roster_state()
	root.add_child(ds_scene)
	ds_scene.start_rift(ds)

	## Navigate to event room
	ds.move_to_room("r1")

	## Event rooms launch directly (no popup)
	_assert(ds_scene.get_ui_state() == DungeonScene.UIState.EVENT, "event launched directly")

	_cleanup_node(ds_scene)
	_cleanup_node(ds_scene.roster_state)
	_cleanup_node(ds.crawler)


func _test_dungeon_puzzle_sequence_reward() -> void:
	print("--- DungeonScene: Sequence Reward ---")
	var ds_scene: DungeonScene = DungeonScene.new()
	ds_scene.instant_mode = true
	ds_scene.data_loader = _data_loader
	ds_scene.roster_state = _make_roster_state()
	var floor_data: Dictionary = _make_puzzle_floor()
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	root.add_child(ds_scene)
	ds_scene.start_rift(ds)

	## Simulate event completion with item reward
	ds_scene._on_event_completed(true, "item", null)
	_assert(ds_scene.get_ui_state() == DungeonScene.UIState.EXPLORING, "back to exploring after event")

	_cleanup_node(ds_scene)
	_cleanup_node(ds_scene.roster_state)
	_cleanup_node(ds.crawler)


func _test_dungeon_puzzle_conduit_reward() -> void:
	print("--- DungeonScene: Conduit Reward ---")
	var cx: CodexState = _make_codex_state()
	var ds_scene: DungeonScene = DungeonScene.new()
	ds_scene.instant_mode = true
	ds_scene.data_loader = _data_loader
	ds_scene.codex_state = cx
	ds_scene.roster_state = _make_roster_state()
	var floor_data: Dictionary = _make_puzzle_floor()
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	root.add_child(ds_scene)
	ds_scene.start_rift(ds)

	var before_count: int = cx.get_discovery_count()

	## Simulate conduit success → reveal species, then event completed
	ds_scene._on_conduit_success()
	ds_scene._on_event_completed(true, "codex_reveal", null)

	var after_count: int = cx.get_discovery_count()
	_assert(after_count > before_count, "new species discovered from conduit")

	_cleanup_node(ds_scene)
	_cleanup_node(ds_scene.roster_state)
	_cleanup_node(cx)
	_cleanup_node(ds.crawler)


func _test_dungeon_echo_combat_flow() -> void:
	print("--- DungeonScene: Echo Combat Flow ---")
	var ds_scene: DungeonScene = DungeonScene.new()
	ds_scene.instant_mode = true
	ds_scene.data_loader = _data_loader
	ds_scene.roster_state = _make_roster_state()
	var floor_data: Dictionary = _make_puzzle_floor()
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	root.add_child(ds_scene)
	ds_scene.start_rift(ds)

	## Track combat_requested
	var signal_data: Dictionary = {"emitted": false}
	ds_scene.combat_requested.connect(func(_enemies: Array[GlyphInstance], _boss: BossDef) -> void:
		signal_data["emitted"] = true
	)

	var echo_g: GlyphInstance = _make_glyph("zapplet")
	echo_g.side = "enemy"
	ds_scene._on_echo_combat_requested(echo_g)

	_assert(ds_scene._echo_battle_active, "echo battle flag set")
	_assert(signal_data["emitted"], "combat_requested emitted")
	_assert(ds_scene.get_ui_state() == DungeonScene.UIState.COMBAT, "in combat state")

	_cleanup_node(ds_scene)
	_cleanup_node(ds_scene.roster_state)
	_cleanup_node(ds.crawler)


func _test_dungeon_echo_capture_on_win() -> void:
	print("--- DungeonScene: Echo Capture on Win ---")
	var ds_scene: DungeonScene = DungeonScene.new()
	ds_scene.instant_mode = true
	ds_scene.data_loader = _data_loader
	var rs: RosterState = _make_roster_state()
	ds_scene.roster_state = rs
	var floor_data: Dictionary = _make_puzzle_floor()
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	root.add_child(ds_scene)
	ds_scene.start_rift(ds)

	## Move to event room first so we have a current room to clear
	ds.move_to_room("r1")

	## Simulate echo combat request then win
	var echo_g: GlyphInstance = _make_glyph("zapplet")
	echo_g.side = "enemy"
	ds_scene._echo_battle_active = true
	ds_scene._echo_glyph = echo_g

	var enemies: Array[GlyphInstance] = [echo_g]
	ds_scene.on_combat_finished(true, enemies)

	## Should be in capture state with 100% chance
	_assert(ds_scene.get_ui_state() == DungeonScene.UIState.CAPTURE, "capture state after echo win")

	_cleanup_node(ds_scene)
	_cleanup_node(rs)
	_cleanup_node(ds.crawler)


func _test_dungeon_puzzle_room_cleared() -> void:
	print("--- DungeonScene: Event Room Cleared ---")
	var ds_scene: DungeonScene = DungeonScene.new()
	ds_scene.instant_mode = true
	ds_scene.data_loader = _data_loader
	ds_scene.roster_state = _make_roster_state()
	var floor_data: Dictionary = _make_puzzle_floor()
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	root.add_child(ds_scene)
	ds_scene.start_rift(ds)

	## Move to event room
	ds.move_to_room("r1")

	## Simulate event completion
	ds_scene._on_event_completed(true, "item", null)

	## Room should be cleared
	var room: Dictionary = ds._get_room(0, "r1")
	_assert(room.get("cleared", false), "event room marked cleared")

	_cleanup_node(ds_scene)
	_cleanup_node(ds_scene.roster_state)
	_cleanup_node(ds.crawler)


func _test_dungeon_reveal_random_species() -> void:
	print("--- DungeonScene: Reveal Random Species ---")
	var cx: CodexState = _make_codex_state()
	var ds_scene: DungeonScene = DungeonScene.new()
	ds_scene.data_loader = _data_loader
	ds_scene.codex_state = cx

	root.add_child(ds_scene)

	_assert(cx.get_discovery_count() == 0, "no discoveries initially")

	ds_scene._reveal_random_species()

	_assert(cx.get_discovery_count() == 1, "one species discovered")

	_cleanup_node(ds_scene)
	_cleanup_node(cx)


# ==========================================================================
# NPC Quest Tests
# ==========================================================================


func _test_quest_data_loaded() -> void:
	print("--- Quests: Data loaded ---")
	_assert(_data_loader.npc_quests.has("lira"), "Lira quest loaded")
	_assert(_data_loader.npc_quests.has("kael"), "Kael quest loaded")
	_assert(_data_loader.npc_quests.has("maro"), "Maro quest loaded")
	var lira_q: Dictionary = _data_loader.npc_quests["lira"]
	_assert(lira_q.get("id", "") == "lira_codex_quest", "Lira quest ID correct")
	_assert(lira_q.get("condition", "") == "codex_discoveries_8", "Lira quest condition correct")


func _test_quest_active_from_phase_1() -> void:
	print("--- Quests: Active from phase 1 ---")
	var gs: GameState = _make_game_state()
	var cx: CodexState = _make_codex_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx
	gs.game_phase = 1  ## Quests available from phase 1

	var status: Dictionary = gs.check_quest_status("lira")
	_assert(status.get("state", "") == "active", "Lira quest active at phase 1")

	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_quest_active_state() -> void:
	print("--- Quests: Active with progress ---")
	var gs: GameState = _make_game_state()
	var cx: CodexState = _make_codex_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx
	gs.game_phase = 2

	## Discover 3 species (need 8 for Lira's quest)
	cx.discover_species("zapplet")
	cx.discover_species("sparkfin")
	cx.discover_species("stonepaw")

	var status: Dictionary = gs.check_quest_status("lira")
	_assert(status.get("state", "") == "active", "Lira quest active")
	_assert(status.get("progress", 0) == 3, "progress is 3")
	_assert(status.get("total", 0) == 8, "total is 8")

	_cleanup_node(gs)
	_cleanup_node(cx)


func _test_quest_complete_and_reward() -> void:
	print("--- Quests: Complete and claim reward ---")
	var gs: GameState = _make_game_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx
	gs.crawler_state = cs
	gs.game_phase = 2

	## Discover 8 species for Lira's quest
	for sp_id: String in ["zapplet", "sparkfin", "stonepaw", "mossling", "driftwisp", "glitchkit", "thunderclaw", "ironbark"]:
		cx.discover_species(sp_id)

	var status: Dictionary = gs.check_quest_status("lira")
	_assert(status.get("state", "") == "complete", "Lira quest completable")

	## Claim reward (codex reveal)
	var initial_count: int = cx.discovered_species.size()
	var reward_text: String = gs.complete_quest("lira")
	_assert(reward_text != "", "reward text returned")
	_assert(cx.discovered_species.size() > initial_count, "new species revealed")
	_assert(gs.completed_quests.has("lira_codex_quest"), "quest marked completed")

	## Can't complete again
	var status2: Dictionary = gs.check_quest_status("lira")
	_assert(status2.get("state", "") == "done", "quest shows done after completion")

	_cleanup_node(gs)
	_cleanup_node(cx)
	_cleanup_node(cs)


func _test_quest_panel_display() -> void:
	print("--- Quests: NPC panel shows quest ---")
	var gs: GameState = _make_game_state()
	var cx: CodexState = _make_codex_state()
	gs.data_loader = _data_loader
	gs.codex_state = cx
	gs.game_phase = 2

	cx.discover_species("zapplet")
	cx.discover_species("sparkfin")

	var panel: NpcPanel = NpcPanel.new()
	root.add_child(panel)
	panel.setup(_data_loader, gs)
	panel.show_npc("lira")

	_assert(panel._quest_label.visible, "quest label visible")
	_assert(panel._quest_label.text.contains("Field Research"), "quest name shown")
	_assert(panel._quest_label.text.contains("2/8"), "progress shown")
	_assert(not panel._quest_btn.visible, "claim button hidden (not complete)")

	_cleanup_node(panel)
	_cleanup_node(gs)
	_cleanup_node(cx)
