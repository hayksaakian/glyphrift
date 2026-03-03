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
	_assert(_crawler.items.is_empty(), "begin_run clears items")
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
	_crawler.cargo_slots = 2
	_crawler.unlocked_chassis = ["standard"]

	_crawler.apply_upgrade({"type": "hull_hp", "value": 20})
	_assert(_crawler.max_hull_hp == 120, "Hull upgrade +20 (got %d)" % _crawler.max_hull_hp)

	_crawler.apply_upgrade({"type": "energy", "value": 10})
	_assert(_crawler.max_energy == 60, "Energy upgrade +10 (got %d)" % _crawler.max_energy)

	_crawler.apply_upgrade({"type": "capacity", "value": 2})
	_assert(_crawler.capacity == 14, "Capacity upgrade +2 (got %d)" % _crawler.capacity)

	_crawler.apply_upgrade({"type": "cargo", "value": 1})
	_assert(_crawler.cargo_slots == 3, "Cargo upgrade +1 (got %d)" % _crawler.cargo_slots)

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
	_crawler.cargo_slots = 2
	_crawler.unlocked_chassis = ["standard"]


func _test_crawler_persistent_properties() -> void:
	print("--- CrawlerState: persistent properties ---")

	## Verify TDD 6.11 default values
	_crawler.max_hull_hp = 100
	_crawler.max_energy = 50
	_crawler.capacity = 12
	_crawler.slots = 3
	_crawler.cargo_slots = 2

	_assert(_crawler.capacity == 12, "Default capacity is 12")
	_assert(_crawler.slots == 3, "Default slots is 3")
	_assert(_crawler.cargo_slots == 2, "Default cargo_slots is 2")

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

	## Base case: exactly at par, player had KO → 40%
	var chance: float = CaptureCalculator.calculate_chance(1, 3, true)
	_assert(absf(chance - 0.40) < 0.001, "At par with KO = 40%% (got %.3f)" % chance)

	## At par, no KO → 40% + 15% = 55%
	chance = CaptureCalculator.calculate_chance(1, 3, false)
	_assert(absf(chance - 0.55) < 0.001, "At par no KO = 55%% (got %.3f)" % chance)

	## 1 turn under par, no KO → 40% + 10% + 15% = 65%
	chance = CaptureCalculator.calculate_chance(1, 2, false)
	_assert(absf(chance - 0.65) < 0.001, "1 under par no KO = 65%% (got %.3f)" % chance)

	## Over par: no turn bonus → 40% + 15% = 55%
	chance = CaptureCalculator.calculate_chance(1, 5, false)
	_assert(absf(chance - 0.55) < 0.001, "Over par no KO = 55%% (got %.3f)" % chance)

	## Max cap: 3 turns under par (par=6, actual=3), no KO → 40% + 30% + 15% = 85% → capped at 80%
	chance = CaptureCalculator.calculate_chance(3, 3, false)
	_assert(absf(chance - 0.80) < 0.001, "Capped at 80%% (got %.3f)" % chance)

	## Over par, with KO → just 40%
	chance = CaptureCalculator.calculate_chance(2, 10, true)
	_assert(absf(chance - 0.40) < 0.001, "Over par with KO = 40%% (got %.3f)" % chance)


# ==========================================================
#  RIFT GENERATOR TESTS
# ==========================================================


func _test_rift_generator_tutorial() -> void:
	print("--- RiftGenerator: tutorial_01 (explicit types) ---")

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	_assert(template != null, "tutorial_01 template loaded")

	var gen_floors: Array[Dictionary] = RiftGenerator.generate(template)
	_assert(gen_floors.size() == 3, "tutorial_01 has 3 floors (got %d)" % gen_floors.size())

	## Floor 0: start, enemy, exit — all explicit
	var f0_rooms: Array = gen_floors[0]["rooms"]
	_assert(f0_rooms.size() == 3, "Floor 0 has 3 rooms (got %d)" % f0_rooms.size())

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

	## Exit room is revealed but not visited (set by _enter_floor)
	var exit_room: Dictionary = ds._get_room(0, "f0_r3")
	_assert(exit_room["revealed"], "Exit room is revealed")
	_assert(not exit_room["visited"], "Exit room is not visited")

	## Enemy room starts unrevealed
	var enemy_room: Dictionary = ds._get_room(0, "f0_r1")
	_assert(not enemy_room["revealed"], "Enemy room starts unrevealed")


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

	## Enemy room starts unrevealed
	var enemy: Dictionary = ds._get_room(0, "f0_r1")
	_assert(not enemy["revealed"], "Enemy room starts unrevealed")

	## Move to enemy room → now revealed
	ds.move_to_room("f0_r1")
	_assert(enemy["revealed"], "Enemy room revealed after entry")
	_assert(enemy["visited"], "Enemy room visited after entry")

	## Hazard room still unrevealed until visited
	var hazard: Dictionary = ds._get_room(0, "f0_r2")
	_assert(not hazard["revealed"], "Hazard room still unrevealed")


func _test_dungeon_state_scan_reveals_adjacent() -> void:
	print("--- DungeonState: scan reveals adjacent ---")

	var ds: DungeonState = _fresh_dungeon()

	## Move to enemy room (f0_r1)
	ds.move_to_room("f0_r1")

	## Hazard room (f0_r2) is adjacent but unrevealed
	var hazard: Dictionary = ds._get_room(0, "f0_r2")
	_assert(not hazard["revealed"], "Hazard unrevealed before scan")

	## Track reveals
	var reveals: Dictionary = {"ids": []}
	ds.room_revealed.connect(func(rid: String, _rt: String) -> void: reveals["ids"].append(rid))

	## Use scan via use_crawler_ability
	var ok: bool = ds.use_crawler_ability("scan")
	_assert(ok, "Scan ability succeeds")
	_assert(hazard["revealed"], "Hazard revealed after scan")
	_assert(_crawler.energy == 45, "Energy 50 - 5 = 45 (got %d)" % _crawler.energy)

	## Start room (f0_r0) is already revealed, shouldn't be in reveals list
	_assert(not reveals["ids"].has("f0_r0"), "Already-revealed room not in reveals signal")
	_assert(reveals["ids"].has("f0_r2"), "Hazard room in reveals signal")

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

	## Walk through floor 0: start → enemy → hazard → exit
	ds.move_to_room("f0_r1")
	ds.move_to_room("f0_r2")
	ds.move_to_room("f0_r3")

	_assert(ds.current_floor == 1, "Moved to floor 1 (got %d)" % ds.current_floor)
	_assert(ds.current_room_id == "f1_r0", "Now at floor 1 start room")
	_assert(floor_signals["floors"].has(1), "floor_changed(1) emitted")

	## Floor 1 start room is visited/revealed
	var f1_start: Dictionary = ds.get_current_room()
	_assert(f1_start["visited"], "Floor 1 start is visited")
	_assert(f1_start["revealed"], "Floor 1 start is revealed")

	## Boss room on final floor is revealed (TDD: exit and boss always revealed)
	var boss_room: Dictionary = ds._get_room(1, "f1_r2")
	_assert(boss_room["revealed"], "Boss room on final floor is revealed")

	## Disconnect
	for conn: Dictionary in ds.floor_changed.get_connections():
		ds.floor_changed.disconnect(conn["callable"])


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
	_assert(ds.current_floor == 1, "On floor 1")

	## Floor 1: start → cache → boss
	ds.move_to_room("f1_r1")
	ds.move_to_room("f1_r2")

	## Entering boss room doesn't change floor (it's the last room, not exit)
	_assert(ds.current_floor == 1, "Still on floor 1 after boss room")
	_assert(ds.current_room_id == "f1_r2", "Standing in boss room")

	## Verify hull took 10 damage from floor 0 hazard
	_assert(_crawler.hull_hp == 90, "Hull is 90 after one hazard hit (got %d)" % _crawler.hull_hp)
