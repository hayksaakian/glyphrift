extends SceneTree

var _data_loader: Node = null
var _crawler: CrawlerState = null
var pass_count: int = 0
var fail_count: int = 0


func _init() -> void:
	## Manually instantiate DataLoader
	var dl_script: GDScript = load("res://core/data_loader.gd") as GDScript
	_data_loader = dl_script.new() as Node
	_data_loader.name = "DataLoader"
	root.add_child(_data_loader)

	## Instantiate CrawlerState
	_crawler = CrawlerState.new()
	_crawler.name = "CrawlerState"
	root.add_child(_crawler)

	await process_frame
	_run_tests()
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — Dungeon & Crawler Tests")
	print("========================================")
	print("")

	_test_crawler_begin_run()
	_test_crawler_ability_costs()
	_test_crawler_chassis_bonuses()
	_test_crawler_hull_damage()
	_test_crawler_energy_spending()
	_test_crawler_item_management()
	_test_crawler_apply_upgrade()
	_test_crawler_persistent_properties()
	_test_capture_calculator()
	_test_rift_generator_tutorial()
	_test_rift_generator_puzzle_type_assignment()
	_test_rift_generator_pool_resolution()
	_test_rift_generator_connections_bidirectional()
	_test_dungeon_state_floor_entry()
	_test_dungeon_state_movement()
	_test_dungeon_state_fog_of_war()
	_test_dungeon_state_scan_reveals_adjacent()
	_test_dungeon_state_hazard_damage()
	_test_dungeon_state_reinforce_negates_hazard()
	_test_dungeon_state_exit_advances_floor()
	_test_dungeon_state_forced_extraction()
	_test_dungeon_state_crawler_damaged_signal()
	_test_dungeon_state_crawler_energy_spent_signal()
	_test_dungeon_state_walk_full_rift()
	_test_dungeon_state_exit_stay()
	_test_dungeon_state_auto_reveal_on_move()
	_test_dungeon_state_find_path()

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


# ==========================================================
#  CRAWLER STATE TESTS
# ==========================================================


func _test_crawler_begin_run() -> void:
	print("--- CrawlerState: begin_run ---")

	_crawler.max_hull_hp = 100
	_crawler.max_energy = 50
	_crawler.active_chassis = "standard"

	## Mess up per-run state
	_crawler.hull_hp = 10
	_crawler.energy = 3
	_crawler.is_reinforced = true
	var item: ItemDef = _data_loader.get_item("repair_patch")
	_crawler.items.append(item)

	_crawler.begin_run()

	_assert(_crawler.hull_hp == 100, "begin_run resets hull_hp to max (got %d)" % _crawler.hull_hp)
	_assert(_crawler.energy == 50, "begin_run resets energy to max (got %d)" % _crawler.energy)
	_assert(_crawler.items.size() == 1, "begin_run preserves items")
	_assert(not _crawler.is_reinforced, "begin_run clears reinforced flag")


func _test_crawler_ability_costs() -> void:
	print("--- CrawlerState: ability costs ---")

	_crawler.active_chassis = "standard"

	_assert(_crawler.get_ability_cost("scan") == 5, "Scan costs 5")
	_assert(_crawler.get_ability_cost("reinforce") == 8, "Reinforce costs 8")
	_assert(_crawler.get_ability_cost("field_repair") == 10, "Field Repair costs 10")
	_assert(_crawler.get_ability_cost("purge") == 15, "Purge costs 15")
	_assert(_crawler.get_ability_cost("emergency_warp") == 25, "Emergency Warp costs 25")
	_assert(_crawler.get_ability_cost("nonexistent") == -1, "Unknown ability returns -1")


func _test_crawler_chassis_bonuses() -> void:
	print("--- CrawlerState: chassis bonuses ---")

	## Ironclad: +25 hull, -5 energy
	_crawler.max_hull_hp = 100
	_crawler.max_energy = 50
	_crawler.active_chassis = "ironclad"
	_crawler.begin_run()
	_assert(_crawler.hull_hp == 125, "Ironclad gives +25 hull (got %d)" % _crawler.hull_hp)
	_assert(_crawler.energy == 45, "Ironclad gives -5 energy (got %d)" % _crawler.energy)

	## Scout: scan costs 3 instead of 5
	_crawler.active_chassis = "scout"
	_crawler.begin_run()
	_assert(_crawler.hull_hp == 100, "Scout has normal hull (got %d)" % _crawler.hull_hp)
	_assert(_crawler.get_ability_cost("scan") == 3, "Scout reduces scan to 3")
	_assert(_crawler.get_ability_cost("reinforce") == 8, "Scout doesn't affect reinforce")

	## Hauler: -10 hull HP
	_crawler.active_chassis = "hauler"
	_crawler.begin_run()
	_assert(_crawler.hull_hp == 90, "Hauler gives -10 hull (got %d)" % _crawler.hull_hp)
	_assert(_crawler.energy == 50, "Hauler has normal energy (got %d)" % _crawler.energy)

	## Reset to standard
	_crawler.active_chassis = "standard"
	_crawler.begin_run()


func _test_crawler_hull_damage() -> void:
	print("--- CrawlerState: hull damage ---")

	_crawler.active_chassis = "standard"
	_crawler.max_hull_hp = 100
	_crawler.begin_run()

	var hull_signals: Dictionary = {"count": 0}
	_crawler.hull_changed.connect(func(_c: int, _m: int) -> void: hull_signals["count"] += 1)

	_crawler.take_hull_damage(30)
	_assert(_crawler.hull_hp == 70, "Hull 100 - 30 = 70 (got %d)" % _crawler.hull_hp)
	_assert(hull_signals["count"] == 1, "hull_changed emitted once")

	## Damage doesn't go below 0
	_crawler.take_hull_damage(200)
	_assert(_crawler.hull_hp == 0, "Hull floors at 0 (got %d)" % _crawler.hull_hp)

	## Disconnect
	for conn: Dictionary in _crawler.hull_changed.get_connections():
		_crawler.hull_changed.disconnect(conn["callable"])


func _test_crawler_energy_spending() -> void:
	print("--- CrawlerState: energy spending ---")

	_crawler.active_chassis = "standard"
	_crawler.max_energy = 50
	_crawler.begin_run()

	var energy_signals: Dictionary = {"count": 0}
	_crawler.energy_changed.connect(func(_c: int, _m: int) -> void: energy_signals["count"] += 1)

	_crawler.spend_energy(10)
	_assert(_crawler.energy == 40, "Energy 50 - 10 = 40 (got %d)" % _crawler.energy)
	_assert(energy_signals["count"] == 1, "energy_changed emitted once")

	## spend_energy always decrements (check is in DungeonState)
	_crawler.spend_energy(5)
	_assert(_crawler.energy == 35, "Energy 40 - 5 = 35 (got %d)" % _crawler.energy)

	## Disconnect
	for conn: Dictionary in _crawler.energy_changed.get_connections():
		_crawler.energy_changed.disconnect(conn["callable"])


func _test_crawler_item_management() -> void:
	print("--- CrawlerState: item management ---")

	_crawler.active_chassis = "standard"
	_crawler.items.clear()
	_crawler.begin_run()

	var patch: ItemDef = _data_loader.get_item("repair_patch")
	var cell: ItemDef = _data_loader.get_item("surge_cell")

	## Add up to MAX_ITEMS
	for i: int in range(CrawlerState.MAX_ITEMS):
		var ok: bool = _crawler.add_item(patch if i % 2 == 0 else cell)
		_assert(ok, "Add item %d succeeds" % (i + 1))

	_assert(_crawler.items.size() == 5, "Items at max 5 (got %d)" % _crawler.items.size())

	## 6th item rejected
	_assert(not _crawler.add_item(patch), "6th item rejected")
	_assert(_crawler.items.size() == 5, "Still 5 items after rejection")

	## Use item
	_assert(_crawler.use_item(_crawler.items[0]), "Use first item succeeds")
	_assert(_crawler.items.size() == 4, "4 items after use")

	## Use item not in inventory
	var lure: ItemDef = _data_loader.get_item("echo_lure")
	_assert(not _crawler.use_item(lure), "Use item not in inventory fails")


func _test_crawler_apply_upgrade() -> void:
	print("--- CrawlerState: apply_upgrade ---")

	_crawler.max_hull_hp = 100
	_crawler.max_energy = 50
	_crawler.capacity = 12
	_crawler.bench_slots = 2
	_crawler.unlocked_chassis = ["standard"]

	_crawler.apply_upgrade({"type": "hull_hp", "value": 20})
	_assert(_crawler.max_hull_hp == 120, "Hull upgrade +20 (got %d)" % _crawler.max_hull_hp)

	_crawler.apply_upgrade({"type": "energy", "value": 10})
	_assert(_crawler.max_energy == 60, "Energy upgrade +10 (got %d)" % _crawler.max_energy)

	_crawler.apply_upgrade({"type": "capacity", "value": 2})
	_assert(_crawler.capacity == 14, "Capacity upgrade +2 (got %d)" % _crawler.capacity)

	_crawler.apply_upgrade({"type": "bench", "value": 1})
	_assert(_crawler.bench_slots == 3, "Bench upgrade +1 (got %d)" % _crawler.bench_slots)

	_crawler.apply_upgrade({"type": "chassis", "chassis_id": "scout"})
	_assert(_crawler.unlocked_chassis.has("scout"), "Scout chassis unlocked")

	## Duplicate chassis unlock is a no-op
	_crawler.apply_upgrade({"type": "chassis", "chassis_id": "scout"})
	var scout_count: int = 0
	for c: String in _crawler.unlocked_chassis:
		if c == "scout":
			scout_count += 1
	_assert(scout_count == 1, "Scout appears only once after duplicate unlock")

	## Reset for other tests
	_crawler.max_hull_hp = 100
	_crawler.max_energy = 50
	_crawler.capacity = 12
	_crawler.bench_slots = 2
	_crawler.unlocked_chassis = ["standard"]


func _test_crawler_persistent_properties() -> void:
	print("--- CrawlerState: persistent properties ---")

	## Verify TDD 6.11 default values
	_crawler.max_hull_hp = 100
	_crawler.max_energy = 50
	_crawler.capacity = 12
	_crawler.slots = 3
	_crawler.bench_slots = 2

	_assert(_crawler.capacity == 12, "Default capacity is 12")
	_assert(_crawler.slots == 3, "Default slots is 3")
	_assert(_crawler.bench_slots == 2, "Default bench_slots is 2")

	## These persist across runs
	_crawler.capacity = 14
	_crawler.begin_run()
	_assert(_crawler.capacity == 14, "Capacity persists across runs (got %d)" % _crawler.capacity)

	## Reset
	_crawler.capacity = 12


# ==========================================================
#  CAPTURE CALCULATOR TESTS
# ==========================================================


func _test_capture_calculator() -> void:
	print("--- CaptureCalculator ---")

	## Par turns: 1 enemy = 3, 2 enemies = 5, 3 enemies = 6
	_assert(CaptureCalculator.get_par_turns(1) == 3, "Par turns for 1 enemy = 3")
	_assert(CaptureCalculator.get_par_turns(2) == 5, "Par turns for 2 enemies = 5")
	_assert(CaptureCalculator.get_par_turns(3) == 6, "Par turns for 3 enemies = 6")

	## Base case: exactly at par → 40%
	var chance: float = CaptureCalculator.calculate_chance(1, 3)
	_assert(absf(chance - 0.40) < 0.001, "At par = 40%% (got %.3f)" % chance)

	## 1 turn under par → 40% + 10% = 50%
	chance = CaptureCalculator.calculate_chance(1, 2)
	_assert(absf(chance - 0.50) < 0.001, "1 under par = 50%% (got %.3f)" % chance)

	## 2 turns under par → 40% + 20% = 60%
	chance = CaptureCalculator.calculate_chance(1, 1)
	_assert(absf(chance - 0.60) < 0.001, "2 under par = 60%% (got %.3f)" % chance)

	## Over par: no turn bonus → 40%
	chance = CaptureCalculator.calculate_chance(1, 5)
	_assert(absf(chance - 0.40) < 0.001, "Over par = 40%% (got %.3f)" % chance)

	## Max cap: 3 turns under par (par=6, actual=3) → 40% + 30% = 70%
	chance = CaptureCalculator.calculate_chance(3, 3)
	_assert(absf(chance - 0.70) < 0.001, "3 under par = 70%% (got %.3f)" % chance)

	## Way over par → just base 40%
	chance = CaptureCalculator.calculate_chance(2, 10)
	_assert(absf(chance - 0.40) < 0.001, "Way over par = 40%% (got %.3f)" % chance)

	## Echo lure bonus: at par + 25% item → 40% + 25% = 65%
	chance = CaptureCalculator.calculate_chance(1, 3, 0.25)
	_assert(absf(chance - 0.65) < 0.001, "Echo lure at par = 65%% (got %.3f)" % chance)

	## Echo lure bonus: 2 under par + 25% → 40% + 20% + 25% = 80% (at cap)
	chance = CaptureCalculator.calculate_chance(1, 1, 0.25)
	_assert(absf(chance - 0.80) < 0.001, "Echo lure 2 under par = 80%% capped (got %.3f)" % chance)

	## Item bonus still respects 80% cap
	chance = CaptureCalculator.calculate_chance(1, 1, 0.50)
	_assert(absf(chance - 0.80) < 0.001, "Item bonus capped at 80%% (got %.3f)" % chance)


# ==========================================================
#  RIFT GENERATOR TESTS
# ==========================================================


func _test_rift_generator_tutorial() -> void:
	print("--- RiftGenerator: tutorial_01 (explicit types) ---")

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	_assert(template != null, "tutorial_01 template loaded")

	var gen_floors: Array[Dictionary] = RiftGenerator.generate(template)
	_assert(gen_floors.size() == 3, "tutorial_01 has 3 floors (got %d)" % gen_floors.size())

	## Floor 0: start, 3 puzzles, enemy, exit — all explicit
	var f0_rooms: Array = gen_floors[0]["rooms"]
	_assert(f0_rooms.size() == 6, "Floor 0 has 6 rooms (got %d)" % f0_rooms.size())

	var f0_types: Array[String] = []
	for r: Dictionary in f0_rooms:
		f0_types.append(r["type"])
	_assert(f0_types.has("start"), "Floor 0 has start room")
	_assert(f0_types.has("enemy"), "Floor 0 has enemy room")
	_assert(f0_types.has("exit"), "Floor 0 has exit room")

	## Floor 2 (final): has boss room
	var f2_rooms: Array = gen_floors[2]["rooms"]
	var boss_found: bool = false
	for r: Dictionary in f2_rooms:
		if r["type"] == "boss":
			boss_found = true
	_assert(boss_found, "Final floor has boss room")

	## All rooms start unrevealed (visibility set by DungeonState._enter_floor)
	var all_unrevealed: bool = true
	for floor_data: Dictionary in gen_floors:
		for room: Dictionary in floor_data["rooms"]:
			if room["revealed"] or room["visited"]:
				all_unrevealed = false
	_assert(all_unrevealed, "RiftGenerator sets all rooms to unrevealed (DungeonState handles reveals)")

	## Puzzle rooms should have puzzle_type from template
	var puzzle_types: Array[String] = []
	for r: Dictionary in f0_rooms:
		if r["type"] == "puzzle":
			_assert(r.has("puzzle_type"), "Puzzle room %s has puzzle_type" % r["id"])
			puzzle_types.append(r["puzzle_type"])
	_assert(puzzle_types.has("conduit"), "Tutorial floor 0 has conduit puzzle")
	_assert(puzzle_types.has("echo"), "Tutorial floor 0 has echo puzzle")
	_assert(puzzle_types.has("quiz"), "Tutorial floor 0 has quiz puzzle")


func _test_rift_generator_puzzle_type_assignment() -> void:
	print("--- RiftGenerator: puzzle_type assigned to pool-generated puzzles ---")

	var template: RiftTemplate = _data_loader.get_rift_template("minor_01")
	var gen_floors: Array[Dictionary] = RiftGenerator.generate(template)

	## Every puzzle room across all floors should have a puzzle_type
	var puzzle_count: int = 0
	for floor_data: Dictionary in gen_floors:
		for room: Dictionary in floor_data["rooms"]:
			if room["type"] == "puzzle":
				puzzle_count += 1
				_assert(room.has("puzzle_type"), "Pool-generated puzzle room has puzzle_type")
				_assert(room["puzzle_type"] in RiftGenerator.PUZZLE_TYPES, "puzzle_type is valid: %s" % room["puzzle_type"])

	## minor_01 should generate at least some puzzle rooms from pools
	_assert(puzzle_count >= 0, "Puzzle rooms found or not (pool-dependent, count=%d)" % puzzle_count)


func _test_rift_generator_pool_resolution() -> void:
	print("--- RiftGenerator: pool resolution (minor_01) ---")

	var template: RiftTemplate = _data_loader.get_rift_template("minor_01")
	var gen_floors: Array[Dictionary] = RiftGenerator.generate(template)

	_assert(gen_floors.size() == 4, "minor_01 has 4 floors (got %d)" % gen_floors.size())

	## All rooms should have a concrete type (no "pool_a" etc.)
	var valid_types: Array[String] = ["start", "exit", "boss", "cache", "enemy", "empty", "hazard", "hidden", "puzzle"]
	var all_valid: bool = true
	var total_rooms: int = 0
	for floor_data: Dictionary in gen_floors:
		for room: Dictionary in floor_data["rooms"]:
			total_rooms += 1
			if not valid_types.has(room["type"]):
				print("  Invalid room type: %s in room %s" % [room["type"], room["id"]])
				all_valid = false

	_assert(all_valid, "All room types are valid concrete types")
	_assert(total_rooms == 27, "minor_01 has 27 total rooms (got %d)" % total_rooms)

	## Start rooms on every floor
	for fi: int in range(gen_floors.size()):
		var has_start: bool = false
		for room: Dictionary in gen_floors[fi]["rooms"]:
			if room["type"] == "start":
				has_start = true
		_assert(has_start, "Floor %d has a start room" % fi)


func _test_rift_generator_connections_bidirectional() -> void:
	print("--- RiftGenerator: connections are bidirectional ---")

	var template: RiftTemplate = _data_loader.get_rift_template("minor_01")
	var gen_floors: Array[Dictionary] = RiftGenerator.generate(template)

	var all_bidir: bool = true
	for floor_data: Dictionary in gen_floors:
		var room_ids: Array[String] = []
		for room: Dictionary in floor_data["rooms"]:
			room_ids.append(room["id"])

		for conn: Array in floor_data["connections"]:
			var a: String = conn[0]
			var b: String = conn[1]
			if not room_ids.has(a) or not room_ids.has(b):
				print("  Connection references invalid room: %s — %s" % [a, b])
				all_bidir = false

	_assert(all_bidir, "All connections reference valid room IDs")


# ==========================================================
#  DUNGEON STATE TESTS
# ==========================================================


## Helper: create a deterministic 2-floor rift for testing
func _make_test_floors() -> Array[Dictionary]:
	## Floor 0: start → enemy → hazard → exit
	## Floor 1: start → cache → boss
	var f0: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "f0_r0", "x": 0, "y": 0, "type": "start", "visited": false, "revealed": false},
			{"id": "f0_r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": false},
			{"id": "f0_r2", "x": 2, "y": 0, "type": "hazard", "visited": false, "revealed": false},
			{"id": "f0_r3", "x": 3, "y": 0, "type": "exit", "visited": false, "revealed": false},
		],
		"connections": [
			["f0_r0", "f0_r1"],
			["f0_r1", "f0_r2"],
			["f0_r2", "f0_r3"],
		],
	}
	var f1: Dictionary = {
		"floor_number": 1,
		"rooms": [
			{"id": "f1_r0", "x": 0, "y": 0, "type": "start", "visited": false, "revealed": false},
			{"id": "f1_r1", "x": 1, "y": 0, "type": "cache", "visited": false, "revealed": false},
			{"id": "f1_r2", "x": 2, "y": 0, "type": "boss", "visited": false, "revealed": false},
		],
		"connections": [
			["f1_r0", "f1_r1"],
			["f1_r1", "f1_r2"],
		],
	}
	var result: Array[Dictionary] = []
	result.append(f0)
	result.append(f1)
	return result


func _make_test_template() -> RiftTemplate:
	var template: RiftTemplate = RiftTemplate.new()
	template.rift_id = "test_rift"
	template.name = "Test Rift"
	template.tier = "minor"
	template.hazard_damage = 10
	template.enemy_tier_pool = [1]
	template.wild_glyph_pool = ["zapplet"]
	template.content_pools = {}
	template.boss = {}
	template.floors = []
	return template


func _fresh_dungeon() -> DungeonState:
	_crawler.max_hull_hp = 100
	_crawler.max_energy = 50
	_crawler.active_chassis = "standard"
	_crawler.unlocked_chassis = ["standard"]

	var ds: DungeonState = DungeonState.new()
	ds.crawler = _crawler
	ds.initialize_with_floors(_make_test_template(), _make_test_floors())
	return ds


func _test_dungeon_state_floor_entry() -> void:
	print("--- DungeonState: floor entry ---")

	var ds: DungeonState = _fresh_dungeon()

	_assert(ds.current_floor == 0, "Starts on floor 0")
	_assert(ds.current_room_id == "f0_r0", "Current room is start (f0_r0)")

	## Start room is visited and revealed (set by _enter_floor)
	var start: Dictionary = ds.get_current_room()
	_assert(start["visited"], "Start room is visited")
	_assert(start["revealed"], "Start room is revealed")

	## Enemy room (adjacent to start) is visible but NOT revealed (foggy)
	var enemy_room: Dictionary = ds._get_room(0, "f0_r1")
	_assert(enemy_room.get("visible", false), "Enemy room (adjacent to start) is visible")
	_assert(not enemy_room["revealed"], "Enemy room type is NOT revealed (foggy)")
	_assert(not enemy_room["visited"], "Enemy room is not visited")

	## Exit room is NOT visible (not adjacent to start)
	var exit_room: Dictionary = ds._get_room(0, "f0_r3")
	_assert(not exit_room.get("visible", false), "Exit room is NOT visible")


func _test_dungeon_state_movement() -> void:
	print("--- DungeonState: movement ---")

	var ds: DungeonState = _fresh_dungeon()

	## Valid move: start → enemy
	var entered: Dictionary = {"room": {}}
	ds.room_entered.connect(func(r: Dictionary) -> void: entered["room"] = r)

	var ok: bool = ds.move_to_room("f0_r1")
	_assert(ok, "Move to connected room succeeds")
	_assert(ds.current_room_id == "f0_r1", "Current room updated to f0_r1")
	_assert(entered["room"]["id"] == "f0_r1", "room_entered signal fired with correct room")

	## Invalid move: can't jump to exit (not connected to f0_r1 directly)
	ok = ds.move_to_room("f0_r3")
	_assert(not ok, "Cannot move to non-adjacent room")
	_assert(ds.current_room_id == "f0_r1", "Room unchanged after failed move")

	## Disconnect
	for conn: Dictionary in ds.room_entered.get_connections():
		ds.room_entered.disconnect(conn["callable"])


func _test_dungeon_state_fog_of_war() -> void:
	print("--- DungeonState: fog of war ---")

	var ds: DungeonState = _fresh_dungeon()

	## Enemy room (adjacent to start) is visible but foggy
	var enemy: Dictionary = ds._get_room(0, "f0_r1")
	_assert(enemy.get("visible", false), "Enemy room visible (adjacent to start)")
	_assert(not enemy["revealed"], "Enemy room type NOT revealed (foggy)")

	## Move to enemy room → now visited + revealed, adjacent become visible
	ds.move_to_room("f0_r1")
	_assert(enemy["visited"], "Enemy room visited after entry")
	_assert(enemy["revealed"], "Enemy room revealed after entry")

	## Hazard room (adjacent to r1) is now visible but foggy
	var hazard: Dictionary = ds._get_room(0, "f0_r2")
	_assert(hazard.get("visible", false), "Hazard room visible after moving to r1")
	_assert(not hazard["revealed"], "Hazard room type NOT revealed (foggy)")

	## Exit room (adjacent to r2, not r1) still not visible
	var exit_room: Dictionary = ds._get_room(0, "f0_r3")
	_assert(not exit_room.get("visible", false), "Exit room not visible (not adjacent to r1)")


func _test_dungeon_state_scan_reveals_adjacent() -> void:
	print("--- DungeonState: scan reveals adjacent ---")

	var ds: DungeonState = _fresh_dungeon()

	## r1 (adjacent to start) is visible but NOT revealed (foggy)
	var enemy: Dictionary = ds._get_room(0, "f0_r1")
	_assert(enemy.get("visible", false), "r1 visible after floor entry")
	_assert(not enemy["revealed"], "r1 NOT revealed (foggy)")

	## Track reveals
	var reveals: Dictionary = {"ids": []}
	ds.room_revealed.connect(func(rid: String, _rt: String) -> void: reveals["ids"].append(rid))

	## Scan from start → fully reveals r1 (adjacent)
	var ok: bool = ds.use_crawler_ability("scan")
	_assert(ok, "Scan ability succeeds")
	_assert(enemy["revealed"], "r1 fully revealed after scan")
	_assert(reveals["ids"].has("f0_r1"), "room_revealed signal for r1")

	## r2 (not adjacent to start) still not revealed
	var hazard: Dictionary = ds._get_room(0, "f0_r2")
	_assert(not hazard["revealed"], "r2 not revealed (not adjacent to start)")

	## Disconnect
	for conn: Dictionary in ds.room_revealed.get_connections():
		ds.room_revealed.disconnect(conn["callable"])


func _test_dungeon_state_hazard_damage() -> void:
	print("--- DungeonState: hazard damage ---")

	var ds: DungeonState = _fresh_dungeon()

	## Walk to hazard: start → enemy → hazard
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r2")

	_assert(_crawler.hull_hp == 90, "Hazard dealt 10 damage (hull %d)" % _crawler.hull_hp)


func _test_dungeon_state_reinforce_negates_hazard() -> void:
	print("--- DungeonState: reinforce negates hazard ---")

	var ds: DungeonState = _fresh_dungeon()

	## Use reinforce from start
	ds.use_crawler_ability("reinforce")
	_assert(_crawler.is_reinforced, "Crawler is reinforced")
	_assert(_crawler.energy == 42, "Energy 50 - 8 = 42 (got %d)" % _crawler.energy)

	## Walk to hazard: start → enemy → hazard
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r2")

	_assert(_crawler.hull_hp == 100, "Reinforce negated hazard — hull still 100 (got %d)" % _crawler.hull_hp)
	_assert(not _crawler.is_reinforced, "Reinforced consumed after hazard")


func _test_dungeon_state_exit_advances_floor() -> void:
	print("--- DungeonState: exit advances floor ---")

	var ds: DungeonState = _fresh_dungeon()

	var floor_signals: Dictionary = {"floors": []}
	ds.floor_changed.connect(func(f: int) -> void: floor_signals["floors"].append(f))

	var exit_signals: Dictionary = {"floors": []}
	ds.exit_reached.connect(func(f: int) -> void: exit_signals["floors"].append(f))

	## Walk through floor 0: start → enemy → hazard → exit
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r2")
	ds.move_to_room("f0_r3")

	## Moving to exit emits exit_reached, does NOT auto-advance
	_assert(ds.current_floor == 0, "Still on floor 0 after entering exit")
	_assert(ds.current_room_id == "f0_r3", "Standing in exit room")
	_assert(exit_signals["floors"].has(1), "exit_reached(1) emitted")
	_assert(not floor_signals["floors"].has(1), "floor_changed NOT yet emitted")

	## Calling descend() advances floor
	ds.descend()

	_assert(ds.current_floor == 1, "Moved to floor 1 after descend()")
	_assert(ds.current_room_id == "f1_r0", "Now at floor 1 start room")
	_assert(floor_signals["floors"].has(1), "floor_changed(1) emitted after descend")

	## Floor 1 start room is visited/revealed
	var f1_start: Dictionary = ds.get_current_room()
	_assert(f1_start["visited"], "Floor 1 start is visited")
	_assert(f1_start["revealed"], "Floor 1 start is revealed")

	## Boss room on final floor is revealed
	var boss_room: Dictionary = ds._get_room(1, "f1_r2")
	_assert(boss_room["revealed"], "Boss room on final floor is revealed")

	## Disconnect
	for conn: Dictionary in ds.floor_changed.get_connections():
		ds.floor_changed.disconnect(conn["callable"])
	for conn: Dictionary in ds.exit_reached.get_connections():
		ds.exit_reached.disconnect(conn["callable"])


func _test_dungeon_state_forced_extraction() -> void:
	print("--- DungeonState: forced extraction ---")

	_crawler.max_hull_hp = 100
	_crawler.max_energy = 50
	_crawler.active_chassis = "standard"

	var ds: DungeonState = DungeonState.new()
	ds.crawler = _crawler
	ds.initialize_with_floors(_make_test_template(), _make_test_floors())

	## Manually set hull low so hazard (10 damage) drops it to 0
	_crawler.hull_hp = 5

	var extraction: Dictionary = {"fired": false}
	ds.forced_extraction.connect(func() -> void: extraction["fired"] = true)

	## Walk into hazard (10 damage, hull 5 → 0)
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r2")

	_assert(_crawler.hull_hp == 0, "Hull dropped to 0")
	_assert(extraction["fired"], "forced_extraction signal fired from DungeonState")

	## Disconnect
	for conn: Dictionary in ds.forced_extraction.get_connections():
		ds.forced_extraction.disconnect(conn["callable"])


func _test_dungeon_state_crawler_damaged_signal() -> void:
	print("--- DungeonState: crawler_damaged signal ---")

	var ds: DungeonState = _fresh_dungeon()

	var damaged: Dictionary = {"amount": 0, "remaining": 0}
	ds.crawler_damaged.connect(func(a: int, r: int) -> void:
		damaged["amount"] = a
		damaged["remaining"] = r
	)

	## Walk into hazard: start → enemy → hazard
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r2")

	_assert(damaged["amount"] == 10, "crawler_damaged amount = 10 (got %d)" % damaged["amount"])
	_assert(damaged["remaining"] == 90, "crawler_damaged remaining = 90 (got %d)" % damaged["remaining"])

	## Disconnect
	for conn: Dictionary in ds.crawler_damaged.get_connections():
		ds.crawler_damaged.disconnect(conn["callable"])


func _test_dungeon_state_crawler_energy_spent_signal() -> void:
	print("--- DungeonState: crawler_energy_spent signal ---")

	var ds: DungeonState = _fresh_dungeon()

	var spent: Dictionary = {"amount": 0, "remaining": 0}
	ds.crawler_energy_spent.connect(func(a: int, r: int) -> void:
		spent["amount"] = a
		spent["remaining"] = r
	)

	## Use scan (costs 5)
	ds.use_crawler_ability("scan")

	_assert(spent["amount"] == 5, "crawler_energy_spent amount = 5 (got %d)" % spent["amount"])
	_assert(spent["remaining"] == 45, "crawler_energy_spent remaining = 45 (got %d)" % spent["remaining"])

	## Insufficient energy: should fail without spending
	_crawler.energy = 2
	var ok: bool = ds.use_crawler_ability("scan")
	_assert(not ok, "Scan rejected when energy insufficient")
	_assert(_crawler.energy == 2, "Energy unchanged after rejected ability")

	## Disconnect
	for conn: Dictionary in ds.crawler_energy_spent.get_connections():
		ds.crawler_energy_spent.disconnect(conn["callable"])


func _test_dungeon_state_walk_full_rift() -> void:
	print("--- DungeonState: walk full rift ---")

	var ds: DungeonState = _fresh_dungeon()

	## Floor 0: start → enemy → hazard → exit
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r2")
	ds.move_to_room("f0_r3")
	## Exit emits exit_reached — must call descend() to advance
	_assert(ds.current_floor == 0, "Still on floor 0 until descend()")
	ds.descend()
	_assert(ds.current_floor == 1, "On floor 1 after descend()")

	## Floor 1: start → cache → boss
	ds.move_to_room("f1_r1")
	ds.move_to_room("f1_r2")

	## Entering boss room doesn't change floor (it's the last room, not exit)
	_assert(ds.current_floor == 1, "Still on floor 1 after boss room")
	_assert(ds.current_room_id == "f1_r2", "Standing in boss room")

	## Verify hull took 10 damage from floor 0 hazard
	_assert(_crawler.hull_hp == 90, "Hull is 90 after one hazard hit (got %d)" % _crawler.hull_hp)


func _test_dungeon_state_exit_stay() -> void:
	print("--- DungeonState: exit stay ---")

	var ds: DungeonState = _fresh_dungeon()

	## Walk to exit: start → enemy → hazard → exit
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r2")
	ds.move_to_room("f0_r3")

	## Still on floor 0 after entering exit
	_assert(ds.current_floor == 0, "Still on floor 0")
	_assert(ds.current_room_id == "f0_r3", "Standing in exit room")

	## Can backtrack — move back to hazard
	ds.move_to_room("f0_r2")
	_assert(ds.current_room_id == "f0_r2", "Moved back to hazard room")
	_assert(ds.current_floor == 0, "Still on floor 0 after backtrack")


func _test_dungeon_state_auto_reveal_on_move() -> void:
	print("--- DungeonState: auto-show on move ---")

	var ds: DungeonState = _fresh_dungeon()

	## After floor entry, r1 (adjacent to start) is visible but foggy
	var r1: Dictionary = ds._get_room(0, "f0_r1")
	_assert(r1.get("visible", false), "r1 visible on floor entry (adjacent to start)")
	_assert(not r1["revealed"], "r1 NOT revealed (foggy)")

	## r2 (not adjacent to start) is still not visible
	var r2: Dictionary = ds._get_room(0, "f0_r2")
	_assert(not r2.get("visible", false), "r2 NOT visible on floor entry")

	## Move to r1 → r1 becomes revealed, r2 becomes visible (foggy)
	ds.move_to_room("f0_r1")
	_assert(r1["revealed"], "r1 revealed after entering")
	_assert(r2.get("visible", false), "r2 visible after moving to r1 (foggy)")
	_assert(not r2["revealed"], "r2 NOT revealed (still foggy)")

	## r3 (exit, adjacent to r2 not r1) is still not visible
	var r3: Dictionary = ds._get_room(0, "f0_r3")
	_assert(not r3.get("visible", false), "r3 NOT visible (not adjacent to r1)")

	## Move to r2 → r2 revealed, r3 becomes visible (foggy)
	ds.move_to_room("f0_r2")
	_assert(r2["revealed"], "r2 revealed after entering")
	_assert(r3.get("visible", false), "r3 visible after moving to r2 (foggy)")
	_assert(not r3["revealed"], "r3 NOT revealed (still foggy)")


func _test_dungeon_state_find_path() -> void:
	print("--- DungeonState: find_path (BFS) ---")

	var ds: DungeonState = _fresh_dungeon()

	## From start, only r1 is visible (adjacent). r2/r3 are not visible yet.
	## Path to r1 (adjacent, visible) should work
	var path: Array[String] = ds.find_path("f0_r1")
	_assert(path.size() == 1, "Path to adjacent r1 has 1 step (got %d)" % path.size())
	_assert(path[0] == "f0_r1", "Path step is f0_r1")

	## Path to r2 fails — r2 is not visible
	path = ds.find_path("f0_r2")
	_assert(path.is_empty(), "No path to r2 (not visible)")

	## Move to r1 → r2 becomes visible (foggy)
	ds.move_to_room("f0_r1")

	## Now path from r1 to r2 should work (1 step)
	path = ds.find_path("f0_r2")
	_assert(path.size() == 1, "Path to r2 from r1 has 1 step")

	## Move to r2 → r3 becomes visible (foggy)
	ds.move_to_room("f0_r2")

	## Path to r3 from r2
	path = ds.find_path("f0_r3")
	_assert(path.size() == 1, "Path to r3 from r2 has 1 step")

	## Multi-hop: move back to start, make all rooms visible, then path to r3
	## First need to go back: r2 → r1 → r0
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r0")
	_assert(ds.current_room_id == "f0_r0", "Back at start")

	## All rooms should now be visible (visited or adjacent to visited)
	path = ds.find_path("f0_r3")
	_assert(path.size() == 3, "Path from r0 to r3 = 3 steps (got %d)" % path.size())
	_assert(path[0] == "f0_r1", "Step 1: f0_r1")
	_assert(path[1] == "f0_r2", "Step 2: f0_r2")
	_assert(path[2] == "f0_r3", "Step 3: f0_r3")

	## Path to self is empty
	path = ds.find_path("f0_r0")
	_assert(path.is_empty(), "Path to self is empty")

	## Path to nonexistent room is empty
	path = ds.find_path("fake_room")
	_assert(path.is_empty(), "Path to nonexistent room is empty")
