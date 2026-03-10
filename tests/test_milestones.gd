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
	print("  GLYPHRIFT — Milestone Tracker Tests")
	print("========================================")
	print("")

	_test_initialization()
	_test_hull_no_damage()
	_test_hull_no_damage_only_first_clear()
	_test_hidden_room_chassis_unlocks()
	_test_all_affinities()
	_test_fuse_10_unique()
	_test_seal_major_rift()
	_test_milestone_only_awards_once()
	_test_took_hull_damage_flag()
	_test_save_load_round_trip()

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

func _make_tracker() -> MilestoneTracker:
	var mt: MilestoneTracker = MilestoneTracker.new()
	var cs_script: GDScript = load("res://core/dungeon/crawler_state.gd") as GDScript
	var crawler: CrawlerState = cs_script.new() as CrawlerState
	crawler.name = "TestCrawler_%d" % randi()
	root.add_child(crawler)
	mt.crawler_state = crawler
	mt.codex_state = CodexState.new()
	mt.initialize(_data_loader)
	return mt


func _make_glyph(species_id: String) -> GlyphInstance:
	var species: GlyphSpecies = _data_loader.get_species(species_id)
	return GlyphInstance.create_from_species(species, _data_loader)


func _cleanup_crawler(mt: MilestoneTracker) -> void:
	if mt.crawler_state != null and mt.crawler_state.get_parent() != null:
		mt.crawler_state.get_parent().remove_child(mt.crawler_state)
		mt.crawler_state.queue_free()


# ==========================================================================
# Tests
# ==========================================================================

func _test_initialization() -> void:
	print("--- Initialization ---")
	var mt: MilestoneTracker = _make_tracker()
	_assert(mt._upgrades.size() == 8, "Loaded 8 upgrade definitions (got %d)" % mt._upgrades.size())
	_assert(mt.completed_milestones.is_empty(), "No milestones completed initially")
	_assert(mt.hidden_rooms_found == 0, "Hidden rooms starts at 0")
	_cleanup_crawler(mt)


func _test_hull_no_damage() -> void:
	print("--- Hull No Damage Milestone ---")
	var mt: MilestoneTracker = _make_tracker()
	var initial_hull: int = mt.crawler_state.max_hull_hp

	## Start a run with no hull damage
	mt.crawler_state.begin_run()
	mt.begin_run()

	## Complete a rift (first clear)
	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	mt.on_rift_completed(template, true)

	_assert(mt.is_completed("hull_no_damage"), "Hull no-damage milestone completed")
	_assert(mt.crawler_state.max_hull_hp == initial_hull + 10, "Max hull increased by 10 (got %d)" % mt.crawler_state.max_hull_hp)
	_cleanup_crawler(mt)


func _test_hull_no_damage_only_first_clear() -> void:
	print("--- Hull No Damage: Only first clear ---")
	var mt: MilestoneTracker = _make_tracker()

	mt.crawler_state.begin_run()
	mt.begin_run()

	## Complete rift as re-run (not first clear)
	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	mt.on_rift_completed(template, false)

	_assert(not mt.is_completed("hull_no_damage"), "Not awarded on re-run")
	_cleanup_crawler(mt)


func _test_hidden_room_chassis_unlocks() -> void:
	print("--- Hidden Room Chassis Unlocks ---")
	var mt: MilestoneTracker = _make_tracker()

	## 1st hidden room → Ironclad
	mt.on_hidden_room_discovered()
	_assert(mt.is_completed("hidden_room_1"), "1st hidden room milestone")
	_assert(mt.crawler_state.unlocked_chassis.has("ironclad"), "Ironclad unlocked")
	_assert(not mt.crawler_state.unlocked_chassis.has("scout"), "Scout not yet unlocked")

	## 2nd hidden room → nothing new
	mt.on_hidden_room_discovered()
	_assert(not mt.is_completed("hidden_room_3"), "3rd milestone not yet (only 2 found)")

	## 3rd hidden room → Scout
	mt.on_hidden_room_discovered()
	_assert(mt.is_completed("hidden_room_3"), "3rd hidden room milestone")
	_assert(mt.crawler_state.unlocked_chassis.has("scout"), "Scout unlocked")

	## 4th → nothing
	mt.on_hidden_room_discovered()

	## 5th → Hauler
	mt.on_hidden_room_discovered()
	_assert(mt.is_completed("hidden_room_5"), "5th hidden room milestone")
	_assert(mt.crawler_state.unlocked_chassis.has("hauler"), "Hauler unlocked")
	_assert(mt.hidden_rooms_found == 5, "Hidden rooms count is 5")

	_cleanup_crawler(mt)


func _test_all_affinities() -> void:
	print("--- All Affinities Capture ---")
	var mt: MilestoneTracker = _make_tracker()
	var initial_energy: int = mt.crawler_state.max_energy

	mt.begin_run()

	## Capture electric
	var g1: GlyphInstance = _make_glyph("zapplet")  ## Electric
	mt.on_capture(g1)
	_assert(not mt.is_completed("all_affinities"), "Not complete with one affinity")

	## Capture ground
	var g2: GlyphInstance = _make_glyph("stonepaw")  ## Ground
	mt.on_capture(g2)
	_assert(not mt.is_completed("all_affinities"), "Not complete with two affinities")

	## Capture water
	var g3: GlyphInstance = _make_glyph("driftwisp")  ## Water
	mt.on_capture(g3)
	_assert(mt.is_completed("all_affinities"), "All affinities milestone completed")
	_assert(mt.crawler_state.max_energy == initial_energy + 5, "Max energy increased by 5 (got %d)" % mt.crawler_state.max_energy)

	_cleanup_crawler(mt)


func _test_fuse_10_unique() -> void:
	print("--- Fuse 10 Unique Species ---")
	var mt: MilestoneTracker = _make_tracker()
	var initial_bench: int = mt.crawler_state.bench_slots

	## Log 9 unique fusions
	for i: int in range(9):
		mt.codex_state.log_fusion("a%d" % i, "b%d" % i, "result_%d" % i)
		mt.on_fusion_performed()
	_assert(not mt.is_completed("fuse_10_unique"), "Not complete at 9 fusions")

	## 10th fusion
	mt.codex_state.log_fusion("a9", "b9", "result_9")
	mt.on_fusion_performed()
	_assert(mt.is_completed("fuse_10_unique"), "Fuse 10 unique milestone completed")
	_assert(mt.crawler_state.bench_slots == initial_bench + 1, "Bench slots increased by 1 (got %d)" % mt.crawler_state.bench_slots)

	_cleanup_crawler(mt)


func _test_seal_major_rift() -> void:
	print("--- Seal Major Rift ---")
	var mt: MilestoneTracker = _make_tracker()
	var initial_capacity: int = mt.crawler_state.capacity

	## Complete a non-major rift
	var tutorial: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	mt.on_rift_completed(tutorial, true)
	_assert(not mt.is_completed("seal_major_rift"), "Not completed for tutorial rift")

	## Complete the major rift
	var major: RiftTemplate = _data_loader.get_rift_template("major_01")
	mt.on_rift_completed(major, true)
	_assert(mt.is_completed("seal_major_rift"), "Seal major rift milestone completed")
	_assert(mt.crawler_state.capacity == initial_capacity + 2, "Capacity increased by 2 (got %d)" % mt.crawler_state.capacity)

	_cleanup_crawler(mt)


func _test_milestone_only_awards_once() -> void:
	print("--- Milestone Awards Only Once ---")
	var mt: MilestoneTracker = _make_tracker()

	## Award no-damage twice
	mt.crawler_state.begin_run()
	mt.begin_run()
	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	mt.on_rift_completed(template, true)
	var hull_after_first: int = mt.crawler_state.max_hull_hp

	## Second time (different rift, first clear, no damage)
	mt.crawler_state.begin_run()
	mt.begin_run()
	var minor: RiftTemplate = _data_loader.get_rift_template("minor_01")
	mt.on_rift_completed(minor, true)

	_assert(mt.crawler_state.max_hull_hp == hull_after_first, "Hull not increased again (got %d, expected %d)" % [mt.crawler_state.max_hull_hp, hull_after_first])

	_cleanup_crawler(mt)


func _test_took_hull_damage_flag() -> void:
	print("--- CrawlerState: took_hull_damage_this_run ---")
	var cs_script: GDScript = load("res://core/dungeon/crawler_state.gd") as GDScript
	var crawler: CrawlerState = cs_script.new() as CrawlerState
	crawler.name = "TestCrawler_damage"
	root.add_child(crawler)

	crawler.begin_run()
	_assert(not crawler.took_hull_damage_this_run, "Starts false after begin_run")

	crawler.take_hull_damage(10)
	_assert(crawler.took_hull_damage_this_run, "Set to true after take_hull_damage")

	crawler.begin_run()
	_assert(not crawler.took_hull_damage_this_run, "Reset after next begin_run")

	crawler.get_parent().remove_child(crawler)
	crawler.queue_free()


func _test_save_load_round_trip() -> void:
	print("--- Milestone Save/Load Round Trip ---")
	var mt: MilestoneTracker = _make_tracker()

	## Complete some milestones
	mt.on_hidden_room_discovered()
	mt.on_hidden_room_discovered()
	mt.on_hidden_room_discovered()  ## 3 hidden rooms → ironclad + scout

	_assert(mt.hidden_rooms_found == 3, "3 hidden rooms before save")
	_assert(mt.is_completed("hidden_room_1"), "hidden_room_1 before save")
	_assert(mt.is_completed("hidden_room_3"), "hidden_room_3 before save")

	## Serialize
	var data: Dictionary = {
		"completed_milestones": [],
		"hidden_rooms_found": 0,
	}
	var milestones: Array[String] = []
	for key: String in mt.completed_milestones:
		milestones.append(key)
	data["completed_milestones"] = milestones
	data["hidden_rooms_found"] = mt.hidden_rooms_found

	## Create fresh tracker and deserialize
	var mt2: MilestoneTracker = MilestoneTracker.new()
	mt2.completed_milestones.clear()
	for mid: Variant in data.get("completed_milestones", []):
		mt2.completed_milestones[str(mid)] = true
	mt2.hidden_rooms_found = int(data.get("hidden_rooms_found", 0))

	_assert(mt2.hidden_rooms_found == 3, "Hidden rooms restored (got %d)" % mt2.hidden_rooms_found)
	_assert(mt2.is_completed("hidden_room_1"), "hidden_room_1 restored")
	_assert(mt2.is_completed("hidden_room_3"), "hidden_room_3 restored")
	_assert(not mt2.is_completed("hidden_room_5"), "hidden_room_5 not completed (correct)")

	_cleanup_crawler(mt)
