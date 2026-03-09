extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0
var _data_loader: Node = null


func _init() -> void:
	_data_loader = load("res://core/data_loader.gd").new()
	root.add_child(_data_loader)
	await process_frame

	_test_capture_recruit_bonus()
	_test_combat_engine_recruit()
	_test_dungeon_scene_recruit_to_capture()
	_test_puzzle_quiz()
	_test_tutorial_boss_floor_cache()
	_test_tutorial_puzzle_types()
	_test_field_repair_display()
	_test_minor_03_loads()
	_test_boss_mastery_stats()
	_test_boss_mastery_display()

	print("\n========================================")
	print("  RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	print("========================================")
	if _fail_count == 0:
		print("  ALL TESTS PASSED")
	else:
		print("  SOME TESTS FAILED — review output above")
	print("")

	_data_loader.queue_free()
	quit(1 if _fail_count > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("[PASS] %s" % msg)
	else:
		_fail_count += 1
		print("[FAIL] %s" % msg)


# ==========================================================
#  CAPTURE CALCULATOR — Recruit Bonus
# ==========================================================

func _test_capture_recruit_bonus() -> void:
	print("--- CaptureCalculator: Recruit Bonus ---")

	## No recruit: at par → 40%
	var chance: float = CaptureCalculator.calculate_chance(1, 3, 0.0, 0)
	_assert(absf(chance - 0.40) < 0.001, "No recruit at par = 40%% (got %.3f)" % chance)

	## 1 recruit: at par → 40% + 15% = 55%
	chance = CaptureCalculator.calculate_chance(1, 3, 0.0, 1)
	_assert(absf(chance - 0.55) < 0.001, "1 recruit at par = 55%% (got %.3f)" % chance)

	## 2 recruits: at par → 40% + 30% = 70%
	chance = CaptureCalculator.calculate_chance(1, 3, 0.0, 2)
	_assert(absf(chance - 0.70) < 0.001, "2 recruits at par = 70%% (got %.3f)" % chance)

	## 3 recruits: at par → 40% + 45% = 80% (capped)
	chance = CaptureCalculator.calculate_chance(1, 3, 0.0, 3)
	_assert(absf(chance - 0.80) < 0.001, "3 recruits at par = 80%% capped (got %.3f)" % chance)

	## 4 recruits: clamped to 3 → same as 3
	chance = CaptureCalculator.calculate_chance(1, 3, 0.0, 4)
	_assert(absf(chance - 0.80) < 0.001, "4 recruits clamped to 3 = 80%% (got %.3f)" % chance)

	## Recruit + speed bonus: 1 recruit + 1 under par → 40% + 10% + 15% = 65%
	chance = CaptureCalculator.calculate_chance(1, 2, 0.0, 1)
	_assert(absf(chance - 0.65) < 0.001, "1 recruit + 1 under par = 65%% (got %.3f)" % chance)

	## Recruit + item: 1 recruit + 25% item at par → 40% + 15% + 25% = 80% (capped)
	chance = CaptureCalculator.calculate_chance(1, 3, 0.25, 1)
	_assert(absf(chance - 0.80) < 0.001, "1 recruit + lure at par = 80%% capped (got %.3f)" % chance)

	## Breakdown includes recruit_bonus
	var bd: Dictionary = CaptureCalculator.get_breakdown(1, 3, 0.0, 2)
	_assert(absf(bd["recruit_bonus"] - 0.30) < 0.001, "Breakdown shows 30%% recruit bonus (got %.3f)" % bd["recruit_bonus"])
	_assert(bd.has("recruit_bonus"), "Breakdown has recruit_bonus key")


# ==========================================================
#  COMBAT ENGINE — Recruit Action
# ==========================================================

func _test_combat_engine_recruit() -> void:
	print("--- CombatEngine: Recruit Action ---")

	var engine: Node = load("res://core/combat/combat_engine.gd").new()
	engine.data_loader = _data_loader
	engine.auto_battle = false
	root.add_child(engine)

	## Build squads
	var player: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	player.calculate_stats()
	var enemy: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("mossling"), _data_loader)
	enemy.calculate_stats()

	var p_squad: Array[GlyphInstance] = [player]
	var e_squad: Array[GlyphInstance] = [enemy]

	engine.start_battle(p_squad, e_squad)
	engine.set_formation()

	## Recruit counts start at 0
	_assert(engine.recruit_counts.is_empty(), "Recruit counts empty at battle start")
	_assert(engine.get_recruit_count("mossling") == 0, "No recruits for mossling initially")

	## Submit recruit action
	engine.submit_action({"action": "recruit", "target": enemy})

	## Check recruit count incremented
	_assert(engine.get_recruit_count("mossling") == 1, "1 recruit for mossling after recruit action")

	## Total recruit uses
	_assert(engine.get_total_recruit_uses() == 1, "Total recruit uses = 1")

	engine.queue_free()


# ==========================================================
#  DUNGEON SCENE — Recruit counts flow to capture popup
# ==========================================================

func _test_dungeon_scene_recruit_to_capture() -> void:
	print("--- DungeonScene: Recruit → Capture Breakdown ---")

	## Build a dungeon with an enemy room
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = DungeonState.new()
	var crawler: CrawlerState = load("res://core/dungeon/crawler_state.gd").new() as CrawlerState
	crawler.name = "TestCrawler_recruit"
	root.add_child(crawler)
	ds.crawler = crawler
	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	ds.initialize_with_floors(template, [floor_data])

	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	scene.instant_mode = true
	root.add_child(scene)
	scene.start_rift(ds)

	## Create a wild enemy glyph
	var wild: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("sparkfin"), _data_loader)
	wild.calculate_stats()
	wild.side = "enemy"
	var enemies: Array[GlyphInstance] = [wild]

	## Simulate combat finished WITH recruit counts for sparkfin
	var recruit_counts: Dictionary = {"sparkfin": 2}
	scene.on_combat_finished(true, enemies, 3, recruit_counts)

	## Should be in CAPTURE state
	_assert(scene.get_ui_state() == DungeonScene.UIState.CAPTURE, "UI state is CAPTURE after winning with capturable enemy")
	_assert(scene._capture_popup.visible, "Capture popup is visible")

	## Verify the breakdown label includes recruit bonus
	var breakdown_text: String = scene._capture_popup._breakdown_label.text
	_assert("Recruit" in breakdown_text, "Capture breakdown includes 'Recruit' (got: '%s')" % breakdown_text)

	## Verify the actual chance includes recruit bonus: 40% base + 30% recruit = 70%
	_assert("70%" in scene._capture_popup._chance_label.text, "Capture chance is 70%% with 2 recruits (got: '%s')" % scene._capture_popup._chance_label.text)

	## Now test WITHOUT recruit counts — should be 40% base only
	scene.on_combat_finished(true, enemies, 3, {})
	var breakdown_no_recruit: String = scene._capture_popup._breakdown_label.text
	_assert("Recruit" not in breakdown_no_recruit, "No recruit text without recruit counts (got: '%s')" % breakdown_no_recruit)

	crawler.queue_free()
	scene.queue_free()


# ==========================================================
#  PUZZLE QUIZ
# ==========================================================

func _test_puzzle_quiz() -> void:
	print("--- PuzzleQuiz ---")

	var quiz: PuzzleQuiz = PuzzleQuiz.new()
	root.add_child(quiz)

	## Build test species
	var sp_a: GlyphSpecies = _data_loader.get_species("zapplet")
	var sp_b: GlyphSpecies = _data_loader.get_species("mossling")
	var sp_c: GlyphSpecies = _data_loader.get_species("stonepaw")
	var sp_d: GlyphSpecies = _data_loader.get_species("sparkfin")

	var choices: Array[GlyphSpecies] = [sp_a, sp_b, sp_c, sp_d]
	quiz.start_with_species(sp_a, choices)

	_assert(quiz.visible, "Quiz is visible after start")
	_assert(quiz.get_correct_species() == sp_a, "Correct species is zapplet")
	_assert(quiz.attempt_answer("zapplet"), "Correct answer returns true")
	_assert(not quiz.attempt_answer("mossling"), "Wrong answer returns false")

	## Test with data_loader (random mode)
	var completed: Dictionary = {"called": false, "success": false}
	quiz.puzzle_completed.connect(func(s: bool, _rt: String, _rd: Variant) -> void:
		completed["called"] = true
		completed["success"] = s
	)

	quiz.start(_data_loader, null, true)
	_assert(quiz.get_correct_species() != null, "Random quiz picks a correct species")
	_assert(quiz.visible, "Random quiz is visible")

	quiz.queue_free()


# ==========================================================
#  TUTORIAL BOSS FLOOR — Pre-boss cache room
# ==========================================================

func _test_tutorial_boss_floor_cache() -> void:
	print("--- Tutorial Boss Floor: Cache Room ---")

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	_assert(template != null, "tutorial_01 template loaded")

	## Boss floor is floor 2
	var boss_floor: Dictionary = template.floors[2]
	var rooms: Array = boss_floor["rooms"]

	## Check that a cache room exists
	var has_cache: bool = false
	var has_boss: bool = false
	for r: Dictionary in rooms:
		if r.get("type", "") == "cache":
			has_cache = true
		if r.get("type", "") == "boss":
			has_boss = true

	_assert(has_cache, "Boss floor has a cache room")
	_assert(has_boss, "Boss floor has a boss room")
	_assert(rooms.size() == 5, "Boss floor has 5 rooms (start+hazard+enemy+cache+boss, got %d)" % rooms.size())


# ==========================================================
#  TUTORIAL PUZZLE TYPES — Map-driven
# ==========================================================

func _test_tutorial_puzzle_types() -> void:
	print("--- Tutorial Puzzle Types: Map-Driven ---")

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	var f0: Dictionary = template.floors[0]
	var rooms: Array = f0["rooms"]

	var puzzle_types: Array[String] = []
	for r: Dictionary in rooms:
		if r.get("type", "") == "puzzle" and r.has("puzzle_type"):
			puzzle_types.append(r["puzzle_type"])

	_assert(puzzle_types.size() == 3, "Floor 0 has 3 puzzle rooms with puzzle_type (got %d)" % puzzle_types.size())
	_assert(puzzle_types.has("conduit"), "Has conduit puzzle")
	_assert(puzzle_types.has("echo"), "Has echo puzzle")
	_assert(puzzle_types.has("quiz"), "Has quiz puzzle")

	## No duplicates
	var unique: Dictionary = {}
	for pt: String in puzzle_types:
		unique[pt] = true
	_assert(unique.size() == puzzle_types.size(), "No duplicate puzzle types")


# ==========================================================
#  FIELD REPAIR — Shows percentage
# ==========================================================

func _test_field_repair_display() -> void:
	print("--- Field Repair: Percentage Display ---")

	## Build a DungeonScene and verify repair button text includes "50%"
	var scene: DungeonScene = DungeonScene.new()
	scene.instant_mode = true
	root.add_child(scene)

	## Create roster with a damaged glyph
	var roster: RosterState = RosterState.new()
	var glyph: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	glyph.calculate_stats()
	glyph.current_hp = 5  ## Damage it
	roster.add_glyph(glyph)
	roster.active_squad.append(glyph)
	scene.roster_state = roster

	## Build dungeon state with crawler
	var crawler: CrawlerState = CrawlerState.new()
	root.add_child(crawler)
	crawler.energy = 100

	var dungeon: DungeonState = DungeonState.new()
	dungeon.crawler = crawler

	scene.dungeon_state = dungeon
	scene.data_loader = _data_loader

	## Call _show_repair_picker to populate the repair vbox
	scene._show_repair_picker()

	## Find the repair button
	var repair_vbox: VBoxContainer = scene._repair_vbox
	var found_pct: bool = false
	if repair_vbox != null:
		for child: Node in repair_vbox.get_children():
			if child is Button:
				if "50%" in child.text:
					found_pct = true

	_assert(found_pct, "Repair button text includes '50%%'")

	crawler.queue_free()
	scene.queue_free()


# ==========================================================
#  MINOR_03 RIFT — Loads correctly
# ==========================================================

func _test_minor_03_loads() -> void:
	print("--- Minor 03: Voltaic Fissure ---")

	var template: RiftTemplate = _data_loader.get_rift_template("minor_03")
	_assert(template != null, "minor_03 template loaded")
	_assert(template.name == "Voltaic Fissure", "minor_03 name is 'Voltaic Fissure'")
	_assert(template.tier == "minor", "minor_03 tier is minor")
	_assert(template.floors.size() == 4, "minor_03 has 4 floors (got %d)" % template.floors.size())

	## Boss floor has boss room
	var boss_floor: Dictionary = template.floors[3]
	var has_boss: bool = false
	var has_cache: bool = false
	for r: Dictionary in boss_floor["rooms"]:
		if r.get("type", "") == "boss":
			has_boss = true
		if r.get("type", "") == "cache":
			has_cache = true
	_assert(has_boss, "minor_03 boss floor has boss room")
	_assert(has_cache, "minor_03 boss floor has cache room")

	## Boss def exists
	var boss_def: BossDef = _data_loader.get_boss("minor_03")
	_assert(boss_def != null, "minor_03 boss def loaded")
	_assert(boss_def.species_id == "thunderclaw", "minor_03 boss is thunderclaw")
	_assert(boss_def.mastery_stars == 2, "minor_03 boss has 2 mastery stars")

	## Phase 2 includes minor_03
	var gs: GameState = GameState.new()
	gs.game_phase = 2
	gs.data_loader = _data_loader
	gs.codex_state = CodexState.new()
	var rifts: Array[RiftTemplate] = gs.get_available_rifts()
	var has_minor_03: bool = false
	for t: RiftTemplate in rifts:
		if t.rift_id == "minor_03":
			has_minor_03 = true
	_assert(has_minor_03, "Phase 2 includes minor_03 rift")

	## Total rift count: 8 templates, 8 bosses
	_assert(_data_loader.rift_templates.size() == 8, "8 rift templates loaded (got %d)" % _data_loader.rift_templates.size())
	_assert(_data_loader.bosses.size() == 8, "8 boss defs loaded (got %d)" % _data_loader.bosses.size())


# ==========================================================
#  BOSS MASTERY STATS — calculate_stats with bonus_*
# ==========================================================

func _test_boss_mastery_stats() -> void:
	print("--- Boss Mastery Stats ---")

	var sp: GlyphSpecies = _data_loader.get_species("thunderclaw")
	_assert(sp != null, "thunderclaw species loaded")

	## Create boss with 2 mastery stars → +4 all stats
	var boss: GlyphInstance = GlyphInstance.new()
	boss.species = sp
	boss.is_boss = true
	boss.bonus_hp = 2 * 2
	boss.bonus_atk = 2 * 2
	boss.bonus_def = 2 * 2
	boss.bonus_spd = 2 * 2
	boss.bonus_res = 2 * 2
	boss.calculate_stats()

	_assert(boss.max_hp == sp.base_hp + 4, "Boss HP = base + 4 (got %d, expected %d)" % [boss.max_hp, sp.base_hp + 4])
	_assert(boss.atk == sp.base_atk + 4, "Boss ATK = base + 4 (got %d, expected %d)" % [boss.atk, sp.base_atk + 4])
	_assert(boss.def_stat == sp.base_def + 4, "Boss DEF = base + 4 (got %d, expected %d)" % [boss.def_stat, sp.base_def + 4])
	_assert(boss.spd == sp.base_spd + 4, "Boss SPD = base + 4 (got %d, expected %d)" % [boss.spd, sp.base_spd + 4])
	_assert(boss.res == sp.base_res + 4, "Boss RES = base + 4 (got %d, expected %d)" % [boss.res, sp.base_res + 4])
	_assert(boss.current_hp == boss.max_hp, "Boss current_hp = max_hp")

	## Zero stars → base stats only
	var boss0: GlyphInstance = GlyphInstance.new()
	boss0.species = sp
	boss0.is_boss = true
	boss0.calculate_stats()
	_assert(boss0.max_hp == sp.base_hp, "0-star boss HP = base (got %d)" % boss0.max_hp)
	_assert(boss0.atk == sp.base_atk, "0-star boss ATK = base (got %d)" % boss0.atk)


# ==========================================================
#  BOSS MASTERY DISPLAY — Stars text
# ==========================================================

func _test_boss_mastery_display() -> void:
	print("--- Boss Mastery Display ---")

	var sp: GlyphSpecies = _data_loader.get_species("ironbark")
	var boss: GlyphInstance = GlyphInstance.new()
	boss.species = sp
	boss.is_boss = true

	## Build mastery objectives: 2 of 3 completed
	var objectives: Array[Dictionary] = []
	objectives.append({"type": "boss_mastery", "completed": true})
	objectives.append({"type": "boss_mastery", "completed": true})
	objectives.append({"type": "boss_mastery", "completed": false})
	boss.mastery_objectives = objectives

	_assert(boss.get_completed_objective_count() == 2, "2 completed objectives")
	var stars_text: String = boss.get_mastery_stars_text()
	_assert(stars_text.length() == 2, "Stars text has 2 chars (got %d: '%s')" % [stars_text.length(), stars_text])
	_assert("\u2605" in stars_text, "Stars text contains filled star")
