extends SceneTree

## Save/Load round-trip tests for SaveManager.

var _data_loader: Node = null
var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	SaveManager._test_prefix = "test_"
	var script: GDScript = load("res://core/data_loader.gd") as GDScript
	_data_loader = script.new() as Node
	_data_loader.name = "DataLoader"
	root.add_child(_data_loader)
	await process_frame
	_run_tests()
	SaveManager._test_prefix = ""
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — Save/Load Tests")
	print("========================================")
	print("")

	_test_has_save_no_file()
	_test_save_creates_file()
	_test_delete_save()
	_test_game_phase_round_trip()
	_test_empty_roster_round_trip()
	_test_single_glyph_round_trip()
	_test_glyph_bonuses_round_trip()
	_test_mastered_glyph_round_trip()
	_test_mastery_objective_progress()
	_test_inherited_techniques()
	_test_active_squad_indices()
	_test_current_hp_preservation()
	_test_codex_discovered_species()
	_test_codex_fusion_log()
	_test_codex_rifts_cleared()
	_test_crawler_upgrades()
	_test_crawler_chassis()
	_test_version_mismatch()
	_test_multiple_glyphs_with_squad()
	_test_restores_to_bastion_state()
	_test_mastery_objective_deep_copy()
	_test_items_persist_between_rifts()
	_test_items_saved_and_loaded()
	_test_npc_read_phase_round_trip()

	## Slot tests
	_test_slot_save_load_round_trip()
	_test_list_slots()
	_test_get_slot_info()
	_test_delete_slot()
	_test_slot_timestamp_saved()

	print("")
	print("========================================")
	var total: int = _pass_count + _fail_count
	print("  Results: %d/%d passed" % [_pass_count, total])
	if _fail_count > 0:
		print("  FAILURES: %d" % _fail_count)
	else:
		print("  ALL TESTS PASSED")
	print("========================================")
	print("")


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		print("[PASS] %s" % test_name)
		_pass_count += 1
	else:
		print("[FAIL] %s" % test_name)
		_fail_count += 1


# --- Helpers ---


func _make_game_state() -> GameState:
	var gs: GameState = GameState.new()
	gs.name = "GameState"
	root.add_child(gs)
	return gs


func _make_roster_state() -> RosterState:
	var rs: RosterState = RosterState.new()
	rs.name = "RosterState"
	root.add_child(rs)
	return rs


func _make_codex_state() -> CodexState:
	var cs: CodexState = CodexState.new()
	cs.name = "CodexState"
	root.add_child(cs)
	return cs


func _make_crawler_state() -> CrawlerState:
	var crs: CrawlerState = CrawlerState.new()
	crs.name = "CrawlerState"
	root.add_child(crs)
	return crs


func _cleanup(nodes: Array) -> void:
	for n: Node in nodes:
		n.queue_free()
	## Ensure save files are cleaned up
	SaveManager.delete_save()
	for slot: String in ["slot1", "slot2", "slot3", "test_slot"]:
		SaveManager.delete_slot(slot)


func _make_glyph(species_id: String) -> GlyphInstance:
	return GlyphInstance.create_from_species(_data_loader.get_species(species_id), _data_loader)


# --- Tests ---


func _test_has_save_no_file() -> void:
	SaveManager.delete_save()
	_assert(not SaveManager.has_save(), "has_save returns false when no file")


func _test_save_creates_file() -> void:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cs: CodexState = _make_codex_state()
	var crs: CrawlerState = _make_crawler_state()

	var ok: bool = SaveManager.save_game(gs, rs, cs, crs)
	_assert(ok, "save_game returns true")
	_assert(SaveManager.has_save(), "has_save returns true after save")

	_cleanup([gs, rs, cs, crs])


func _test_delete_save() -> void:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cs: CodexState = _make_codex_state()
	var crs: CrawlerState = _make_crawler_state()

	SaveManager.save_game(gs, rs, cs, crs)
	SaveManager.delete_save()
	_assert(not SaveManager.has_save(), "delete_save removes file")

	_cleanup([gs, rs, cs, crs])


func _test_game_phase_round_trip() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.game_phase = 3

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	var ok: bool = SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(ok, "game_phase: load succeeds")
	_assert(gs2.game_phase == 3, "game_phase: restored to 3")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_empty_roster_round_trip() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(rs2.all_glyphs.size() == 0, "empty roster: no glyphs")
	_assert(rs2.active_squad.size() == 0, "empty roster: no squad")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_single_glyph_round_trip() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g: GlyphInstance = _make_glyph("zapplet")
	rs1.add_glyph(g)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(rs2.all_glyphs.size() == 1, "single glyph: count == 1")
	_assert(rs2.all_glyphs[0].species.id == "zapplet", "single glyph: species is zapplet")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_glyph_bonuses_round_trip() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g: GlyphInstance = _make_glyph("stonepaw")
	g.bonus_hp = 5
	g.bonus_atk = 3
	g.bonus_def = 2
	g.bonus_spd = 1
	g.bonus_res = 4
	g.calculate_stats()
	rs1.add_glyph(g)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	var loaded: GlyphInstance = rs2.all_glyphs[0]
	_assert(loaded.bonus_hp == 5, "bonuses: hp=5")
	_assert(loaded.bonus_atk == 3, "bonuses: atk=3")
	_assert(loaded.bonus_def == 2, "bonuses: def=2")
	_assert(loaded.bonus_spd == 1, "bonuses: spd=1")
	_assert(loaded.bonus_res == 4, "bonuses: res=4")
	## Stats should include bonuses
	var sp: GlyphSpecies = _data_loader.get_species("stonepaw")
	_assert(loaded.max_hp == sp.base_hp + 5, "bonuses: max_hp includes bonus")
	_assert(loaded.atk == sp.base_atk + 3, "bonuses: atk includes bonus")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_mastered_glyph_round_trip() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g: GlyphInstance = _make_glyph("zapplet")
	g.is_mastered = true
	g.mastery_bonus_applied = true
	g.calculate_stats()
	rs1.add_glyph(g)
	var expected_hp: int = g.max_hp

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	var loaded: GlyphInstance = rs2.all_glyphs[0]
	_assert(loaded.is_mastered, "mastered: is_mastered true")
	_assert(loaded.mastery_bonus_applied, "mastered: bonus_applied true")
	_assert(loaded.max_hp == expected_hp, "mastered: max_hp includes +2 bonus (got %d, expected %d)" % [loaded.max_hp, expected_hp])

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_mastery_objective_progress() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g: GlyphInstance = _make_glyph("zapplet")
	g.mastery_objectives = [
		{"type": "win_with_advantage", "params": {}, "completed": true, "description": "Win with advantage"},
		{"type": "use_technique_count", "params": {"technique_id": "spark", "target": 5, "current": 3}, "completed": false, "description": "Use spark 5 times"},
		{"type": "win_battle_no_ko", "params": {}, "completed": false, "description": "Win without KO"},
	]
	rs1.add_glyph(g)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	var loaded: GlyphInstance = rs2.all_glyphs[0]
	_assert(loaded.mastery_objectives.size() == 3, "mastery objectives: count == 3")
	_assert(loaded.mastery_objectives[0]["completed"] == true, "mastery objectives: first completed")
	_assert(loaded.mastery_objectives[1]["completed"] == false, "mastery objectives: second not completed")
	_assert(int(loaded.mastery_objectives[1]["params"]["current"]) == 3, "mastery objectives: current counter preserved (3)")
	_assert(int(loaded.mastery_objectives[1]["params"]["target"]) == 5, "mastery objectives: target preserved (5)")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_inherited_techniques() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g: GlyphInstance = _make_glyph("zapplet")
	## Add an inherited technique (not native to zapplet)
	var inherited_tech: TechniqueDef = _data_loader.get_technique("rock_toss")
	g.techniques.append(inherited_tech)
	var total_techs: int = g.techniques.size()
	rs1.add_glyph(g)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	var loaded: GlyphInstance = rs2.all_glyphs[0]
	_assert(loaded.techniques.size() == total_techs, "inherited techniques: total count preserved (%d)" % total_techs)
	## Check that stone_throw is present
	var has_inherited: bool = false
	for t: TechniqueDef in loaded.techniques:
		if t.id == "rock_toss":
			has_inherited = true
	_assert(has_inherited, "inherited techniques: rock_toss present")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_active_squad_indices() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g1: GlyphInstance = _make_glyph("zapplet")
	var g2: GlyphInstance = _make_glyph("stonepaw")
	var g3: GlyphInstance = _make_glyph("driftwisp")
	rs1.add_glyph(g1)
	rs1.add_glyph(g2)
	rs1.add_glyph(g3)
	## Squad is g1 and g3 (indices 0 and 2)
	var squad: Array[GlyphInstance] = [g1, g3]
	rs1.set_active_squad(squad)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(rs2.active_squad.size() == 2, "squad indices: squad size == 2")
	_assert(rs2.active_squad[0].species.id == "zapplet", "squad indices: first is zapplet")
	_assert(rs2.active_squad[1].species.id == "driftwisp", "squad indices: second is driftwisp")
	## Squad members should be the same objects as in all_glyphs
	_assert(rs2.active_squad[0] == rs2.all_glyphs[0], "squad indices: same object as all_glyphs[0]")
	_assert(rs2.active_squad[1] == rs2.all_glyphs[2], "squad indices: same object as all_glyphs[2]")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_current_hp_preservation() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g: GlyphInstance = _make_glyph("zapplet")
	g.current_hp = 5  ## Damaged
	rs1.add_glyph(g)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	var loaded: GlyphInstance = rs2.all_glyphs[0]
	_assert(loaded.current_hp == 5, "current_hp: preserved at 5 (got %d)" % loaded.current_hp)
	_assert(loaded.max_hp == g.max_hp, "current_hp: max_hp correct")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_codex_discovered_species() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	cs1.discover_species("zapplet")
	cs1.discover_species("stonepaw")
	cs1.discover_species("sparkfin")

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(cs2.discovered_species.size() == 3, "codex discovered: count == 3")
	_assert(cs2.is_species_discovered("zapplet"), "codex discovered: zapplet")
	_assert(cs2.is_species_discovered("stonepaw"), "codex discovered: stonepaw")
	_assert(cs2.is_species_discovered("sparkfin"), "codex discovered: sparkfin")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_codex_fusion_log() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	cs1.log_fusion("zapplet", "stonepaw", "voltarion")
	cs1.log_fusion("sparkfin", "driftwisp", "lithosurge")

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(cs2.fusion_log.size() == 2, "codex fusion_log: count == 2")
	_assert(cs2.fusion_log[0]["parent_a"] == "zapplet", "codex fusion_log: first parent_a")
	_assert(cs2.fusion_log[0]["result"] == "voltarion", "codex fusion_log: first result")
	_assert(cs2.fusion_log[1]["parent_a"] == "sparkfin", "codex fusion_log: second parent_a")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_codex_rifts_cleared() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	cs1.mark_rift_cleared("tutorial_01")
	cs1.mark_rift_cleared("minor_01")

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(cs2.rifts_cleared.size() == 2, "codex rifts_cleared: count == 2")
	_assert(cs2.is_rift_cleared("tutorial_01"), "codex rifts_cleared: tutorial_01")
	_assert(cs2.is_rift_cleared("minor_01"), "codex rifts_cleared: minor_01")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_crawler_upgrades() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	crs1.max_hull_hp = 125
	crs1.max_energy = 60
	crs1.capacity = 16
	crs1.slots = 4
	crs1.cargo_slots = 3

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(crs2.max_hull_hp == 125, "crawler: max_hull_hp == 125")
	_assert(crs2.max_energy == 60, "crawler: max_energy == 60")
	_assert(crs2.capacity == 16, "crawler: capacity == 16")
	_assert(crs2.slots == 4, "crawler: slots == 4")
	_assert(crs2.cargo_slots == 3, "crawler: cargo_slots == 3")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_crawler_chassis() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	crs1.active_chassis = "ironclad"
	crs1.unlocked_chassis = ["standard", "ironclad", "scout"]

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(crs2.active_chassis == "ironclad", "crawler chassis: active == ironclad")
	_assert(crs2.unlocked_chassis.size() == 3, "crawler chassis: 3 unlocked")
	_assert(crs2.unlocked_chassis.has("scout"), "crawler chassis: has scout")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_version_mismatch() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	## Manually write a save with wrong version
	var data: Dictionary = {"version": 999, "game_state": {}, "roster_state": {}, "codex_state": {}, "crawler_state": {}}
	var file: FileAccess = FileAccess.open("user://save_autosave.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	var ok: bool = SaveManager.load_game(gs1, rs1, cs1, crs1, _data_loader)
	_assert(not ok, "version mismatch: load returns false")

	_cleanup([gs1, rs1, cs1, crs1])


func _test_multiple_glyphs_with_squad() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g1: GlyphInstance = _make_glyph("zapplet")
	var g2: GlyphInstance = _make_glyph("stonepaw")
	var g3: GlyphInstance = _make_glyph("driftwisp")
	var g4: GlyphInstance = _make_glyph("sparkfin")
	rs1.add_glyph(g1)
	rs1.add_glyph(g2)
	rs1.add_glyph(g3)
	rs1.add_glyph(g4)
	rs1.set_active_squad([g1, g2, g3])

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(rs2.all_glyphs.size() == 4, "multi glyph: 4 total")
	_assert(rs2.active_squad.size() == 3, "multi glyph: squad of 3")
	_assert(rs2.all_glyphs[3].species.id == "sparkfin", "multi glyph: reserve sparkfin at index 3")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_restores_to_bastion_state() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.current_state = GameState.State.RIFT  ## Simulate mid-rift (shouldn't happen but test safety)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(gs2.current_state == GameState.State.BASTION, "restore state: always BASTION")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_mastery_objective_deep_copy() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var g: GlyphInstance = _make_glyph("zapplet")
	g.mastery_objectives = [
		{"type": "use_technique_count", "params": {"technique_id": "spark", "target": 5, "current": 2}, "completed": false, "description": "test"},
	]
	rs1.add_glyph(g)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	## Mutate the original after saving
	g.mastery_objectives[0]["params"]["current"] = 99

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	var loaded: GlyphInstance = rs2.all_glyphs[0]
	## Should still be 2, not 99
	_assert(int(loaded.mastery_objectives[0]["params"]["current"]) == 2, "deep copy: mutation after save doesn't affect loaded data")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_items_persist_between_rifts() -> void:
	var crs: CrawlerState = _make_crawler_state()
	var item: ItemDef = _data_loader.get_item("repair_patch")
	crs.add_item(item)
	_assert(crs.items.size() == 1, "items persist: has 1 item before run")
	crs.begin_run()
	_assert(crs.items.size() == 1, "items persist: still has 1 item after begin_run")
	_cleanup([crs])


func _test_items_saved_and_loaded() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	var item1: ItemDef = _data_loader.get_item("repair_patch")
	var item2: ItemDef = _data_loader.get_item("surge_cell")
	crs1.add_item(item1)
	crs1.add_item(item2)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(crs2.items.size() == 2, "items saved: count == 2")
	_assert(crs2.items[0].id == "repair_patch", "items saved: first is repair_patch")
	_assert(crs2.items[1].id == "surge_cell", "items saved: second is surge_cell")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_npc_read_phase_round_trip() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()

	gs1.npc_read_phase = {"kael": 2, "lira": 1, "maro": 0}

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(int(gs2.npc_read_phase["kael"]) == 2, "npc_read_phase: kael == 2")
	_assert(int(gs2.npc_read_phase["lira"]) == 1, "npc_read_phase: lira == 1")
	_assert(int(gs2.npc_read_phase["maro"]) == 0, "npc_read_phase: maro == 0")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


# --- Slot tests ---


func _test_slot_save_load_round_trip() -> void:
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.game_phase = 4
	var g: GlyphInstance = _make_glyph("zapplet")
	rs1.add_glyph(g)

	var ok: bool = SaveManager.save_to_slot("slot1", gs1, rs1, cs1, crs1)
	_assert(ok, "slot round-trip: save_to_slot returns true")

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	var loaded: bool = SaveManager.load_from_slot("slot1", gs2, rs2, cs2, crs2, _data_loader)
	_assert(loaded, "slot round-trip: load_from_slot returns true")
	_assert(gs2.game_phase == 4, "slot round-trip: game_phase == 4")
	_assert(rs2.all_glyphs.size() == 1, "slot round-trip: 1 glyph")
	_assert(rs2.all_glyphs[0].species.id == "zapplet", "slot round-trip: species is zapplet")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_list_slots() -> void:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cs: CodexState = _make_codex_state()
	var crs: CrawlerState = _make_crawler_state()

	SaveManager.save_to_slot("slot1", gs, rs, cs, crs)
	SaveManager.save_to_slot("slot3", gs, rs, cs, crs)

	var slots: Array[String] = SaveManager.list_slots()
	_assert(slots.has("slot1"), "list_slots: has slot1")
	_assert(slots.has("slot3"), "list_slots: has slot3")
	_assert(not slots.has("slot2"), "list_slots: no slot2")

	_cleanup([gs, rs, cs, crs])


func _test_get_slot_info() -> void:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cs: CodexState = _make_codex_state()
	var crs: CrawlerState = _make_crawler_state()
	gs.game_phase = 3
	rs.add_glyph(_make_glyph("zapplet"))
	rs.add_glyph(_make_glyph("stonepaw"))

	SaveManager.save_to_slot("slot2", gs, rs, cs, crs)

	var info: Dictionary = SaveManager.get_slot_info("slot2")
	_assert(not info.is_empty(), "get_slot_info: not empty")
	_assert(info.get("phase", 0) == 3, "get_slot_info: phase == 3")
	_assert(info.get("glyph_count", 0) == 2, "get_slot_info: glyph_count == 2")
	_assert(info.get("timestamp", "") != "", "get_slot_info: has timestamp")

	## Empty slot returns empty dict
	var empty_info: Dictionary = SaveManager.get_slot_info("slot1")
	_assert(empty_info.is_empty(), "get_slot_info: empty for unused slot")

	_cleanup([gs, rs, cs, crs])


func _test_delete_slot() -> void:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cs: CodexState = _make_codex_state()
	var crs: CrawlerState = _make_crawler_state()

	SaveManager.save_to_slot("slot1", gs, rs, cs, crs)
	_assert(SaveManager.has_slot("slot1"), "delete_slot: slot exists before delete")
	SaveManager.delete_slot("slot1")
	_assert(not SaveManager.has_slot("slot1"), "delete_slot: slot gone after delete")

	_cleanup([gs, rs, cs, crs])


func _test_slot_timestamp_saved() -> void:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cs: CodexState = _make_codex_state()
	var crs: CrawlerState = _make_crawler_state()

	SaveManager.save_to_slot("slot1", gs, rs, cs, crs)

	## Read raw JSON to verify timestamp field exists
	var file: FileAccess = FileAccess.open("user://save_slot1.json", FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	json.parse(text)
	var data: Dictionary = json.data
	_assert(data.has("timestamp"), "slot timestamp: field exists in JSON")
	_assert(str(data["timestamp"]).length() > 0, "slot timestamp: not empty")

	_cleanup([gs, rs, cs, crs])
