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

	## Mid-rift save/load tests
	_test_mid_rift_save_round_trip()
	_test_mid_rift_crawler_run_state()
	_test_mid_rift_rift_bench()
	_test_mid_rift_room_state_preserved()
	_test_no_dungeon_means_bastion()

	## BUG-013: Bench glyph edge cases
	_test_bench_full_two_glyphs()
	_test_bench_after_capture_mid_rift()
	_test_bench_after_squad_swap()
	_test_bench_glyph_with_damage()
	_test_bench_identity_preserved()
	_test_bench_empty_when_no_bench_glyphs()
	_test_bench_indices_stable_after_roster_growth()

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
	crs1.bench_slots = 3

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
	_assert(crs2.bench_slots == 3, "crawler: bench_slots == 3")

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
	var file: FileAccess = FileAccess.open("user://test_save_slot1.json", FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	json.parse(text)
	var data: Dictionary = json.data
	_assert(data.has("timestamp"), "slot timestamp: field exists in JSON")
	_assert(str(data["timestamp"]).length() > 0, "slot timestamp: not empty")

	_cleanup([gs, rs, cs, crs])


# --- Mid-rift save/load tests ---


func _make_dungeon_state(crs: CrawlerState) -> DungeonState:
	var ds: DungeonState = DungeonState.new()
	ds.crawler = crs
	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	## Build minimal floors for testing
	var floor1: Dictionary = {
		"rooms": [
			{"id": "r1", "type": "start", "x": 0, "y": 0, "visited": true, "revealed": true, "visible": true},
			{"id": "r2", "type": "enemy", "x": 1, "y": 0, "visited": true, "revealed": true, "visible": true},
			{"id": "r3", "type": "exit", "x": 2, "y": 0, "visited": false, "revealed": false, "visible": true},
		],
		"connections": [["r1", "r2"], ["r2", "r3"]],
	}
	var floor2: Dictionary = {
		"rooms": [
			{"id": "r4", "type": "start", "x": 0, "y": 0, "visited": false, "revealed": false, "visible": false},
			{"id": "r5", "type": "boss", "x": 1, "y": 0, "visited": false, "revealed": false, "visible": false},
		],
		"connections": [["r4", "r5"]],
	}
	ds.initialize_with_floors(template, [floor1, floor2])
	## Move to r2 so we're mid-rift
	ds.move_to_room("r2")
	return ds


func _test_mid_rift_save_round_trip() -> void:
	print("")
	print("--- Mid-rift: Save round-trip ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1
	gs1.current_state = GameState.State.RIFT

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	var ok: bool = SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(ok, "mid-rift: load succeeds")
	_assert(gs2.current_state == GameState.State.RIFT, "mid-rift: state is RIFT")
	_assert(gs2.current_dungeon != null, "mid-rift: current_dungeon not null")
	_assert(gs2.current_dungeon.current_room_id == "r2", "mid-rift: current room is r2")
	_assert(gs2.current_dungeon.current_floor == 0, "mid-rift: current floor is 0")
	_assert(gs2.current_dungeon.rift_template.rift_id == "tutorial_01", "mid-rift: template is tutorial_01")
	_assert(SaveManager.last_load_rift_data.get("in_rift", false), "mid-rift: last_load_rift_data has in_rift")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_mid_rift_crawler_run_state() -> void:
	print("")
	print("--- Mid-rift: Crawler run state ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1
	## Simulate mid-rift damage
	crs1.take_hull_damage(30)
	crs1.spend_energy(15)

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(crs2.hull_hp == 70, "mid-rift crawler: hull_hp == 70")
	_assert(crs2.energy == 35, "mid-rift crawler: energy == 35")
	_assert(crs2.took_hull_damage_this_run == true, "mid-rift crawler: took_hull_damage_this_run")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_mid_rift_rift_bench() -> void:
	print("")
	print("--- Mid-rift: Rift bench ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	var bench_glyph: GlyphInstance = _make_glyph("sparkfin")
	rs1.add_glyph(bench_glyph)  ## Bench glyphs must be in roster
	var bench: Array[GlyphInstance] = [bench_glyph]

	SaveManager.save_game(gs1, rs1, cs1, crs1, bench)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	var loaded_bench: Array = SaveManager.last_load_rift_data.get("rift_bench", [])
	_assert(loaded_bench.size() == 1, "mid-rift bench: 1 item")
	_assert((loaded_bench[0] as GlyphInstance).species.id == "sparkfin", "mid-rift bench: sparkfin")
	## Verify bench glyph is the SAME object as roster glyph (not a duplicate)
	_assert(loaded_bench[0] == rs2.all_glyphs[rs2.all_glyphs.size() - 1], "mid-rift bench: same instance as roster")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_mid_rift_room_state_preserved() -> void:
	print("")
	print("--- Mid-rift: Room states preserved ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	var ds2: DungeonState = gs2.current_dungeon
	## Floor 0, room r1 was visited
	var floor0: Dictionary = ds2.floors[0]
	var r1_visited: bool = false
	var r2_visited: bool = false
	var r3_revealed: bool = false
	for room: Dictionary in floor0["rooms"]:
		if room["id"] == "r1":
			r1_visited = room.get("visited", false)
		elif room["id"] == "r2":
			r2_visited = room.get("visited", false)
		elif room["id"] == "r3":
			r3_revealed = room.get("revealed", false)
	_assert(r1_visited, "mid-rift rooms: r1 was visited")
	_assert(r2_visited, "mid-rift rooms: r2 was visited")
	## r3 was visible but not revealed (fog state)
	_assert(not r3_revealed, "mid-rift rooms: r3 not revealed (foggy)")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_no_dungeon_means_bastion() -> void:
	print("")
	print("--- Mid-rift: No dungeon means bastion ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.current_state = GameState.State.RIFT
	gs1.current_dungeon = null  ## No dungeon

	SaveManager.save_game(gs1, rs1, cs1, crs1)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()

	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)
	_assert(gs2.current_state == GameState.State.BASTION, "no dungeon: state is BASTION")
	_assert(not SaveManager.last_load_rift_data.get("in_rift", false), "no dungeon: no rift data")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


## --- BUG-013: Bench glyph edge case tests ---


func _test_bench_full_two_glyphs() -> void:
	print("")
	print("--- Bench: full bench (2/2) round-trip ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	## Build squad of 3 + bench of 2
	var squad1: GlyphInstance = _make_glyph("zapplet")
	var squad2: GlyphInstance = _make_glyph("sparkfin")
	var squad3: GlyphInstance = _make_glyph("stonepaw")
	var bench1: GlyphInstance = _make_glyph("mossling")
	var bench2: GlyphInstance = _make_glyph("driftwisp")

	for g: GlyphInstance in [squad1, squad2, squad3, bench1, bench2]:
		rs1.add_glyph(g)
	rs1.active_squad = [squad1, squad2, squad3]

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	var bench: Array[GlyphInstance] = [bench1, bench2]
	SaveManager.save_game(gs1, rs1, cs1, crs1, bench)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()
	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)

	var loaded_bench: Array = SaveManager.last_load_rift_data.get("rift_bench", [])
	_assert(loaded_bench.size() == 2, "full bench: 2 glyphs loaded")
	_assert((loaded_bench[0] as GlyphInstance).species.id == "mossling", "full bench: first is mossling")
	_assert((loaded_bench[1] as GlyphInstance).species.id == "driftwisp", "full bench: second is driftwisp")
	_assert(rs2.active_squad.size() == 3, "full bench: squad still 3")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_bench_after_capture_mid_rift() -> void:
	print("")
	print("--- Bench: capture adds to bench mid-rift ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	## Full squad, empty bench
	var squad1: GlyphInstance = _make_glyph("zapplet")
	var squad2: GlyphInstance = _make_glyph("sparkfin")
	var squad3: GlyphInstance = _make_glyph("stonepaw")
	for g: GlyphInstance in [squad1, squad2, squad3]:
		rs1.add_glyph(g)
	rs1.active_squad = [squad1, squad2, squad3]

	## Simulate capture: add new glyph to roster (bench candidate)
	var captured: GlyphInstance = _make_glyph("glitchkit")
	rs1.add_glyph(captured)

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	## Save with captured glyph on bench
	var bench: Array[GlyphInstance] = [captured]
	SaveManager.save_game(gs1, rs1, cs1, crs1, bench)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()
	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)

	var loaded_bench: Array = SaveManager.last_load_rift_data.get("rift_bench", [])
	_assert(loaded_bench.size() == 1, "capture bench: 1 glyph")
	_assert((loaded_bench[0] as GlyphInstance).species.id == "glitchkit", "capture bench: glitchkit")
	## Verify bench glyph is same object as in roster
	_assert(loaded_bench[0] == rs2.all_glyphs[3], "capture bench: same object as roster[3]")
	_assert(rs2.all_glyphs.size() == 4, "capture bench: roster has 4 total")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_bench_after_squad_swap() -> void:
	print("")
	print("--- Bench: swap squad<->bench then save ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	## Squad of 3, bench of 1
	var squad1: GlyphInstance = _make_glyph("zapplet")
	var squad2: GlyphInstance = _make_glyph("sparkfin")
	var squad3: GlyphInstance = _make_glyph("stonepaw")
	var bench1: GlyphInstance = _make_glyph("mossling")
	for g: GlyphInstance in [squad1, squad2, squad3, bench1]:
		rs1.add_glyph(g)
	rs1.active_squad = [squad1, squad2, squad3]

	## Simulate swap: squad3 goes to bench, bench1 goes to squad
	rs1.active_squad = [squad1, squad2, bench1]

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	## After swap: stonepaw is now on bench
	var bench: Array[GlyphInstance] = [squad3]
	SaveManager.save_game(gs1, rs1, cs1, crs1, bench)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()
	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)

	var loaded_bench: Array = SaveManager.last_load_rift_data.get("rift_bench", [])
	_assert(loaded_bench.size() == 1, "swap bench: 1 glyph")
	_assert((loaded_bench[0] as GlyphInstance).species.id == "stonepaw", "swap bench: stonepaw on bench")
	_assert(rs2.active_squad.size() == 3, "swap bench: squad still 3")
	_assert(rs2.active_squad[2].species.id == "mossling", "swap bench: mossling now in squad")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_bench_glyph_with_damage() -> void:
	print("")
	print("--- Bench: damaged bench glyph HP preserved ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	var squad1: GlyphInstance = _make_glyph("zapplet")
	var bench1: GlyphInstance = _make_glyph("sparkfin")
	bench1.current_hp = 5  ## Badly damaged
	for g: GlyphInstance in [squad1, bench1]:
		rs1.add_glyph(g)
	rs1.active_squad = [squad1]

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	var bench: Array[GlyphInstance] = [bench1]
	SaveManager.save_game(gs1, rs1, cs1, crs1, bench)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()
	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)

	var loaded_bench: Array = SaveManager.last_load_rift_data.get("rift_bench", [])
	_assert(loaded_bench.size() == 1, "damaged bench: 1 glyph")
	_assert((loaded_bench[0] as GlyphInstance).current_hp == 5, "damaged bench: HP=5 preserved")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_bench_identity_preserved() -> void:
	print("")
	print("--- Bench: species, mastery, techniques preserved ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	var squad1: GlyphInstance = _make_glyph("zapplet")
	var bench1: GlyphInstance = _make_glyph("ironbark")
	bench1.is_mastered = true
	bench1.mastery_bonus_applied = true
	bench1.current_hp = bench1.max_hp
	for g: GlyphInstance in [squad1, bench1]:
		rs1.add_glyph(g)
	rs1.active_squad = [squad1]

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	var bench: Array[GlyphInstance] = [bench1]
	SaveManager.save_game(gs1, rs1, cs1, crs1, bench)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()
	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)

	var loaded_bench: Array = SaveManager.last_load_rift_data.get("rift_bench", [])
	_assert(loaded_bench.size() == 1, "identity bench: 1 glyph")
	var bg: GlyphInstance = loaded_bench[0] as GlyphInstance
	_assert(bg.species.id == "ironbark", "identity bench: species=ironbark")
	_assert(bg.is_mastered == true, "identity bench: mastered")
	_assert(bg.mastery_bonus_applied == true, "identity bench: mastery bonus applied")
	_assert(bg.techniques.size() > 0, "identity bench: has techniques")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_bench_empty_when_no_bench_glyphs() -> void:
	print("")
	print("--- Bench: empty bench saves correctly ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	var squad1: GlyphInstance = _make_glyph("zapplet")
	rs1.add_glyph(squad1)
	rs1.active_squad = [squad1]

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	var bench: Array[GlyphInstance] = []
	SaveManager.save_game(gs1, rs1, cs1, crs1, bench)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()
	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)

	var loaded_bench: Array = SaveManager.last_load_rift_data.get("rift_bench", [])
	_assert(loaded_bench.size() == 0, "empty bench: 0 glyphs")
	_assert(rs2.active_squad.size() == 1, "empty bench: squad=1")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])


func _test_bench_indices_stable_after_roster_growth() -> void:
	print("")
	print("--- Bench: indices stable when roster grows before save ---")
	var gs1: GameState = _make_game_state()
	var rs1: RosterState = _make_roster_state()
	var cs1: CodexState = _make_codex_state()
	var crs1: CrawlerState = _make_crawler_state()
	gs1.data_loader = _data_loader
	gs1.crawler_state = crs1

	## Start with squad of 2 + bench of 1
	var squad1: GlyphInstance = _make_glyph("zapplet")
	var squad2: GlyphInstance = _make_glyph("sparkfin")
	var bench1: GlyphInstance = _make_glyph("stonepaw")
	for g: GlyphInstance in [squad1, squad2, bench1]:
		rs1.add_glyph(g)
	rs1.active_squad = [squad1, squad2]

	## Simulate: player captures another glyph (added to roster via transmitter)
	var transmitted: GlyphInstance = _make_glyph("mossling")
	rs1.add_glyph(transmitted)

	var ds1: DungeonState = _make_dungeon_state(crs1)
	gs1.current_dungeon = ds1

	## Bench still just stonepaw (transmitted went to reserves, not rift pool)
	var bench: Array[GlyphInstance] = [bench1]
	SaveManager.save_game(gs1, rs1, cs1, crs1, bench)

	var gs2: GameState = _make_game_state()
	var rs2: RosterState = _make_roster_state()
	var cs2: CodexState = _make_codex_state()
	var crs2: CrawlerState = _make_crawler_state()
	SaveManager.load_game(gs2, rs2, cs2, crs2, _data_loader)

	var loaded_bench: Array = SaveManager.last_load_rift_data.get("rift_bench", [])
	_assert(loaded_bench.size() == 1, "roster growth bench: 1 glyph")
	_assert((loaded_bench[0] as GlyphInstance).species.id == "stonepaw", "roster growth bench: stonepaw")
	_assert(rs2.all_glyphs.size() == 4, "roster growth bench: 4 total glyphs")
	_assert(loaded_bench[0] == rs2.all_glyphs[2], "roster growth bench: correct roster index")

	_cleanup([gs1, rs1, cs1, crs1, gs2, rs2, cs2, crs2])
