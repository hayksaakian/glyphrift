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

	await process_frame
	_run_tests()
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — Dungeon UI Tests")
	print("========================================")
	print("")

	_test_room_node_construction()
	_test_room_node_states()
	_test_room_node_icons()
	_test_room_node_click()
	_test_room_node_setup_from_data()
	_test_room_node_adjacent()

	_test_floor_map_construction()
	_test_floor_map_room_positions()
	_test_floor_map_connections()
	_test_floor_map_current_room()
	_test_floor_map_signal_updates()
	_test_floor_map_adjacency()

	_test_crawler_hud_construction()
	_test_crawler_hud_bars()
	_test_crawler_hud_abilities()
	_test_crawler_hud_signal_updates()
	_test_crawler_hud_items()

	_test_room_popup_construction()
	_test_room_popup_types()
	_test_room_popup_boss_name()
	_test_room_popup_hazard_damage()
	_test_room_popup_action_signal()

	_test_capture_popup_construction()
	_test_capture_popup_display()
	_test_capture_popup_success()
	_test_capture_popup_failure()
	_test_capture_popup_release()

	_test_dungeon_scene_construction()
	_test_dungeon_scene_start_rift()
	_test_dungeon_scene_room_navigation()
	_test_dungeon_scene_popup_flow()
	_test_dungeon_scene_ability_usage()
	_test_dungeon_scene_floor_transition()
	_test_dungeon_scene_forced_extraction()
	_test_dungeon_scene_combat_signal()
	_test_dungeon_scene_capture_flow()

	_test_capture_popup_bench_swap_display()
	_test_capture_popup_bench_swap_release()
	_test_capture_popup_bench_swap_abandon()

	_test_fog_of_war()
	_test_scan_reveals_adjacent()
	_test_click_to_navigate()
	_test_click_to_navigate_stops_at_combat()

	_test_crawler_token_position()
	_test_path_preview()
	_test_preview_highlight()
	_test_moving_state_blocks_clicks()

	_test_boss_capture_on_rerun()
	_test_boss_no_capture_on_first_clear()

	_test_battle_loss_pushback()
	_test_battle_loss_hull_zero_extracts()

	_test_pause_menu_exists()
	_test_pause_save_and_quit_signal()

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

func _make_crawler() -> CrawlerState:
	var cs_script: GDScript = load("res://core/dungeon/crawler_state.gd") as GDScript
	var cs: CrawlerState = cs_script.new() as CrawlerState
	cs.name = "TestCrawler"
	root.add_child(cs)
	return cs


func _make_dungeon_state(template_id: String = "tutorial_01") -> DungeonState:
	var ds: DungeonState = DungeonState.new()
	var crawler: CrawlerState = _make_crawler()
	ds.crawler = crawler
	var template: RiftTemplate = _data_loader.get_rift_template(template_id)
	ds.initialize(template)
	return ds


func _make_dungeon_state_with_floors(floors: Array[Dictionary], template_id: String = "tutorial_01") -> DungeonState:
	var ds: DungeonState = DungeonState.new()
	var crawler: CrawlerState = _make_crawler()
	ds.crawler = crawler
	var template: RiftTemplate = _data_loader.get_rift_template(template_id)
	ds.initialize_with_floors(template, floors)
	return ds


func _make_simple_floor() -> Dictionary:
	## A simple 3-room floor for testing: start → enemy → exit
	return {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": false},
			{"id": "r2", "x": 2, "y": 0, "type": "exit", "visited": false, "revealed": false},
		],
		"connections": [["r0", "r1"], ["r1", "r2"]],
	}


func _make_multi_floor() -> Array[Dictionary]:
	## Two floors for testing floor transitions
	var floor0: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "f0_r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "f0_r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": false},
			{"id": "f0_r2", "x": 2, "y": 0, "type": "exit", "visited": false, "revealed": false},
		],
		"connections": [["f0_r0", "f0_r1"], ["f0_r1", "f0_r2"]],
	}
	var floor1: Dictionary = {
		"floor_number": 1,
		"rooms": [
			{"id": "f1_r0", "x": 0, "y": 0, "type": "start", "visited": false, "revealed": false},
			{"id": "f1_r1", "x": 1, "y": 0, "type": "boss", "visited": false, "revealed": false},
		],
		"connections": [["f1_r0", "f1_r1"]],
	}
	var result: Array[Dictionary] = []
	result.append(floor0)
	result.append(floor1)
	return result


func _make_variety_floor() -> Dictionary:
	## Floor with one of each room type for popup testing
	return {
		"floor_number": 0,
		"rooms": [
			{"id": "r_start", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r_enemy", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true},
			{"id": "r_cache", "x": 2, "y": 0, "type": "cache", "visited": false, "revealed": true},
			{"id": "r_hazard", "x": 0, "y": 1, "type": "hazard", "visited": false, "revealed": true},
			{"id": "r_puzzle", "x": 1, "y": 1, "type": "puzzle", "visited": false, "revealed": true},
			{"id": "r_boss", "x": 2, "y": 1, "type": "boss", "visited": false, "revealed": true},
			{"id": "r_empty", "x": 0, "y": 2, "type": "empty", "visited": false, "revealed": true},
			{"id": "r_hidden", "x": 1, "y": 2, "type": "hidden", "visited": false, "revealed": true},
			{"id": "r_exit", "x": 2, "y": 2, "type": "exit", "visited": false, "revealed": true},
		],
		"connections": [
			["r_start", "r_enemy"], ["r_start", "r_cache"], ["r_start", "r_hazard"],
			["r_enemy", "r_puzzle"], ["r_cache", "r_boss"],
			["r_hazard", "r_empty"], ["r_puzzle", "r_hidden"], ["r_boss", "r_exit"],
		],
	}


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()


func _make_glyph(species_id: String = "zapplet") -> GlyphInstance:
	var species: GlyphSpecies = _data_loader.get_species(species_id)
	var glyph: GlyphInstance = GlyphInstance.create_from_species(species, _data_loader)
	glyph.calculate_stats()
	return glyph


# ==========================================================================
# RoomNode Tests
# ==========================================================================

func _test_room_node_construction() -> void:
	print("--- RoomNode: Construction ---")
	var node: RoomNode = RoomNode.new()
	root.add_child(node)
	_assert(node != null, "RoomNode instantiates")
	_assert(node.custom_minimum_size == Vector2(64, 80), "RoomNode has 64x80 min size")
	_assert(node.state == RoomNode.RoomState.UNREVEALED, "Default state is UNREVEALED")
	_assert(node._icon_label != null, "Has icon label")
	_assert(node._background != null, "Has background rect")
	_assert(node._border_panel != null, "Has border panel")
	_assert(not node._border_panel.visible, "Border hidden by default")
	_cleanup_node(node)


func _test_room_node_states() -> void:
	print("--- RoomNode: State Transitions ---")
	var node: RoomNode = RoomNode.new()
	root.add_child(node)
	node.setup({"id": "r1", "x": 0, "y": 0, "type": "enemy", "visited": false, "revealed": false})

	## Unrevealed
	_assert(node.state == RoomNode.RoomState.UNREVEALED, "Unrevealed from data")
	_assert(node._icon_label.text == "?", "Unrevealed shows ?")

	## Revealed
	node.set_state(RoomNode.RoomState.REVEALED)
	_assert(node.state == RoomNode.RoomState.REVEALED, "State set to REVEALED")
	_assert(node._icon_label.text == "!", "Revealed enemy shows !")
	_assert(node._icon_label.modulate.a < 1.0, "Revealed has reduced opacity")
	_assert(not node._border_panel.visible, "Revealed has no border")

	## Visited
	node.set_state(RoomNode.RoomState.VISITED)
	_assert(node.state == RoomNode.RoomState.VISITED, "State set to VISITED")
	_assert(node._icon_label.text == "!", "Visited enemy shows !")
	_assert(is_equal_approx(node._icon_label.modulate.a, 1.0), "Visited has full opacity")
	_assert(not node._border_panel.visible, "Visited has no border")

	## Current (border now hidden — crawler token shows position)
	node.set_state(RoomNode.RoomState.CURRENT)
	_assert(node.state == RoomNode.RoomState.CURRENT, "State set to CURRENT")
	_assert(not node._border_panel.visible, "Current no longer shows border (token replaces it)")
	_assert(is_equal_approx(node._icon_label.modulate.a, 1.0), "Current has full opacity")

	_cleanup_node(node)


func _test_room_node_icons() -> void:
	print("--- RoomNode: Icons Per Type ---")
	var types_and_icons: Dictionary = {
		"start": "S",
		"exit": "\u25bc",
		"enemy": "!",
		"cache": "\u25c6",
		"boss": "\u2605",
		"empty": "\u25cb",
		"hidden": "H",
	}
	for room_type: String in types_and_icons:
		var node: RoomNode = RoomNode.new()
		root.add_child(node)
		node.setup({"id": "test", "x": 0, "y": 0, "type": room_type, "visited": true, "revealed": true})
		_assert(node._icon_label.text == types_and_icons[room_type], "Type '%s' shows correct icon '%s'" % [room_type, types_and_icons[room_type]])
		_cleanup_node(node)


func _test_room_node_click() -> void:
	print("--- RoomNode: Click Signal ---")
	var node: RoomNode = RoomNode.new()
	root.add_child(node)
	node.setup({"id": "test_click", "x": 0, "y": 0, "type": "enemy", "visited": false, "revealed": true})

	var signal_data: Dictionary = {"received": false, "room_id": ""}
	node.room_clicked.connect(func(rid: String) -> void:
		signal_data["received"] = true
		signal_data["room_id"] = rid
	)

	## Simulate click
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	node._gui_input(event)

	_assert(signal_data["received"], "room_clicked signal emitted on click")
	_assert(signal_data["room_id"] == "test_click", "room_clicked passes correct room_id")
	_cleanup_node(node)


func _test_room_node_setup_from_data() -> void:
	print("--- RoomNode: Setup From Room Data ---")
	var node: RoomNode = RoomNode.new()
	root.add_child(node)

	## Visited room data
	node.setup({"id": "r5", "x": 3, "y": 2, "type": "cache", "visited": true, "revealed": true})
	_assert(node.state == RoomNode.RoomState.VISITED, "Visited data → VISITED state")
	_assert(node.get_room_id() == "r5", "get_room_id returns correct id")

	## Revealed but not visited
	node.setup({"id": "r6", "x": 1, "y": 1, "type": "hazard", "visited": false, "revealed": true})
	_assert(node.state == RoomNode.RoomState.REVEALED, "Revealed data → REVEALED state")

	## Unrevealed
	node.setup({"id": "r7", "x": 0, "y": 0, "type": "enemy", "visited": false, "revealed": false})
	_assert(node.state == RoomNode.RoomState.UNREVEALED, "Unrevealed data → UNREVEALED state")
	_assert(node._icon_label.text == "?", "Unrevealed shows ? regardless of type")

	_cleanup_node(node)


func _test_room_node_adjacent() -> void:
	print("--- RoomNode: Adjacent Flag ---")
	var node: RoomNode = RoomNode.new()
	root.add_child(node)
	node.setup({"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true})
	node.set_state(RoomNode.RoomState.REVEALED)

	_assert(not node.is_adjacent, "Not adjacent by default")
	node.set_adjacent(true)
	_assert(node.is_adjacent, "Adjacent after set_adjacent(true)")

	_cleanup_node(node)


# ==========================================================================
# FloorMap Tests
# ==========================================================================

func _test_floor_map_construction() -> void:
	print("--- FloorMap: Construction ---")
	var fm: FloorMap = FloorMap.new()
	fm.size = Vector2(800, 500)
	root.add_child(fm)
	_assert(fm != null, "FloorMap instantiates")
	_assert(fm.get_room_count() == 0, "No rooms before build")
	_assert(fm.get_line_count() == 0, "No lines before build")
	_cleanup_node(fm)


func _test_floor_map_room_positions() -> void:
	print("--- FloorMap: Room Positions ---")
	var ds: DungeonState = _make_dungeon_state_with_floors([_make_simple_floor()])
	var fm: FloorMap = FloorMap.new()
	fm.size = Vector2(800, 500)
	root.add_child(fm)
	fm.build_floor(ds.floors[0], ds)

	_assert(fm.get_room_count() == 3, "3 rooms spawned from simple floor")

	## Rooms should be spaced at CELL_SIZE (100px) intervals on X
	var r0: RoomNode = fm.get_room_node("r0")
	var r1: RoomNode = fm.get_room_node("r1")
	var r2: RoomNode = fm.get_room_node("r2")
	_assert(r0 != null, "Room r0 exists")
	_assert(r1 != null, "Room r1 exists")
	_assert(r2 != null, "Room r2 exists")

	## X spacing should be CELL_SIZE apart
	var dx_01: float = r1.position.x - r0.position.x
	var dx_12: float = r2.position.x - r1.position.x
	_assert(is_equal_approx(dx_01, float(FloorMap.CELL_SIZE)), "r0→r1 X spacing is CELL_SIZE")
	_assert(is_equal_approx(dx_12, float(FloorMap.CELL_SIZE)), "r1→r2 X spacing is CELL_SIZE")

	## All on same Y (y=0 for all rooms)
	_assert(is_equal_approx(r0.position.y, r1.position.y), "r0 and r1 same Y")
	_assert(is_equal_approx(r1.position.y, r2.position.y), "r1 and r2 same Y")

	_cleanup_node(fm)
	_cleanup_node(ds.crawler)


func _test_floor_map_connections() -> void:
	print("--- FloorMap: Connection Lines ---")
	var ds: DungeonState = _make_dungeon_state_with_floors([_make_simple_floor()])
	var fm: FloorMap = FloorMap.new()
	fm.size = Vector2(800, 500)
	root.add_child(fm)
	fm.build_floor(ds.floors[0], ds)

	_assert(fm.get_line_count() == 2, "2 connection lines from simple floor")
	_cleanup_node(fm)
	_cleanup_node(ds.crawler)


func _test_floor_map_current_room() -> void:
	print("--- FloorMap: Current Room Highlight ---")
	var ds: DungeonState = _make_dungeon_state_with_floors([_make_simple_floor()])
	var fm: FloorMap = FloorMap.new()
	fm.size = Vector2(800, 500)
	root.add_child(fm)
	fm.build_floor(ds.floors[0], ds)

	## Start room should be current
	fm.set_current_room("r0")
	var r0: RoomNode = fm.get_room_node("r0")
	_assert(r0.state == RoomNode.RoomState.CURRENT, "r0 is CURRENT after set_current_room")

	## Move current to r1
	fm.set_current_room("r1")
	_assert(r0.state == RoomNode.RoomState.VISITED, "r0 reverts to VISITED")
	var r1: RoomNode = fm.get_room_node("r1")
	_assert(r1.state == RoomNode.RoomState.CURRENT, "r1 is now CURRENT")

	_cleanup_node(fm)
	_cleanup_node(ds.crawler)


func _test_floor_map_signal_updates() -> void:
	print("--- FloorMap: Signal-Driven Updates ---")
	## Use simple floor — r1 is foggy (adjacent to start), r2 is unrevealed
	var ds: DungeonState = _make_dungeon_state_with_floors([_make_simple_floor()])
	var fm: FloorMap = FloorMap.new()
	fm.size = Vector2(800, 500)
	root.add_child(fm)
	fm.build_floor(ds.floors[0], ds)
	fm.set_current_room("r0")
	fm.refresh_all()

	## r1 starts FOGGY (visible but type unknown)
	var r1: RoomNode = fm.get_room_node("r1")
	_assert(r1.state == RoomNode.RoomState.FOGGY, "r1 starts FOGGY")

	## Simulate full reveal (as if scanned)
	ds.floors[0]["rooms"][1]["revealed"] = true
	fm.update_room("r1")
	_assert(r1.state == RoomNode.RoomState.REVEALED, "r1 becomes REVEALED after scan")

	_cleanup_node(fm)
	_cleanup_node(ds.crawler)


func _test_floor_map_adjacency() -> void:
	print("--- FloorMap: Adjacency Tracking ---")
	var ds: DungeonState = _make_dungeon_state_with_floors([_make_simple_floor()])
	var fm: FloorMap = FloorMap.new()
	fm.size = Vector2(800, 500)
	root.add_child(fm)
	fm.build_floor(ds.floors[0], ds)
	fm.set_current_room("r0")
	fm.refresh_all()

	## r1 is adjacent to r0 (connected)
	var r1: RoomNode = fm.get_room_node("r1")
	_assert(r1.is_adjacent, "r1 is adjacent to r0")

	## r2 is NOT adjacent to r0 (not connected directly)
	var r2: RoomNode = fm.get_room_node("r2")
	_assert(not r2.is_adjacent, "r2 is NOT adjacent to r0")

	_cleanup_node(fm)
	_cleanup_node(ds.crawler)


# ==========================================================================
# CrawlerHUD Tests
# ==========================================================================

func _test_crawler_hud_construction() -> void:
	print("--- CrawlerHUD: Construction ---")
	var hud: CrawlerHUD = CrawlerHUD.new()
	root.add_child(hud)
	_assert(hud != null, "CrawlerHUD instantiates")
	_assert(hud._hull_bar != null, "Has hull bar")
	_assert(hud._energy_bar != null, "Has energy bar")
	_assert(hud._items_button != null, "Has items button")
	_assert(hud._ability_buttons.size() == 5, "Has 5 ability buttons")
	_cleanup_node(hud)


func _test_crawler_hud_bars() -> void:
	print("--- CrawlerHUD: Bar Values ---")
	var crawler: CrawlerState = _make_crawler()
	crawler.begin_run()
	var hud: CrawlerHUD = CrawlerHUD.new()
	root.add_child(hud)
	hud.setup(crawler)
	hud.refresh()

	_assert(hud._hull_bar.value == float(crawler.hull_hp), "Hull bar matches crawler hull_hp")
	_assert(hud._hull_bar.max_value == float(crawler.max_hull_hp), "Hull bar max matches max_hull_hp")
	_assert(hud._energy_bar.value == float(crawler.energy), "Energy bar matches crawler energy")
	_assert(hud._energy_bar.max_value == float(crawler.max_energy), "Energy bar max matches max_energy")
	_assert(hud._hull_label.text == "%d/%d" % [crawler.hull_hp, crawler.max_hull_hp], "Hull label shows correct text")
	_assert(hud._energy_label.text == "%d/%d" % [crawler.energy, crawler.max_energy], "Energy label shows correct text")

	## Hull color should be green at full HP
	_assert(hud._hull_fill_style.bg_color == CrawlerHUD.HULL_COLOR_HIGH, "Full hull is green")

	## Take damage to go below 25%
	crawler.take_hull_damage(80)
	hud.refresh()
	_assert(hud._hull_fill_style.bg_color == CrawlerHUD.HULL_COLOR_MED, "Low hull is yellow")

	## Take more damage to go below 10%
	crawler.take_hull_damage(12)
	hud.refresh()
	_assert(hud._hull_fill_style.bg_color == CrawlerHUD.HULL_COLOR_LOW, "Critical hull is red")

	_cleanup_node(hud)
	_cleanup_node(crawler)


func _test_crawler_hud_abilities() -> void:
	print("--- CrawlerHUD: Ability Buttons ---")
	var crawler: CrawlerState = _make_crawler()
	crawler.begin_run()
	var hud: CrawlerHUD = CrawlerHUD.new()
	root.add_child(hud)
	hud.setup(crawler)
	hud.refresh()

	## All abilities should show cost
	var scan_btn: Button = hud.get_ability_button("scan")
	_assert(scan_btn != null, "Scan button exists")
	_assert("5" in scan_btn.text, "Scan button shows cost 5")
	_assert(not scan_btn.disabled, "Scan enabled at full energy")

	var warp_btn: Button = hud.get_ability_button("emergency_warp")
	_assert(warp_btn != null, "Warp button exists")
	_assert("25" in warp_btn.text, "Warp button shows cost 25")
	_assert(not warp_btn.disabled, "Warp enabled at full energy (50)")

	## Drain energy to make warp unaffordable
	crawler.spend_energy(30)
	hud.refresh()
	_assert(warp_btn.disabled, "Warp disabled with only 20 energy")
	_assert(not scan_btn.disabled, "Scan still enabled with 20 energy")

	## Drain more
	crawler.spend_energy(16)
	hud.refresh()
	_assert(scan_btn.disabled, "Scan disabled with only 4 energy")

	_cleanup_node(hud)
	_cleanup_node(crawler)


func _test_crawler_hud_signal_updates() -> void:
	print("--- CrawlerHUD: Signal-Driven Updates ---")
	var crawler: CrawlerState = _make_crawler()
	crawler.begin_run()
	var hud: CrawlerHUD = CrawlerHUD.new()
	root.add_child(hud)
	hud.setup(crawler)
	hud.refresh()

	## Take damage via signal
	crawler.take_hull_damage(30)
	## hull_changed signal should auto-update
	_assert(hud._hull_bar.value == float(crawler.hull_hp), "Hull bar updates on hull_changed signal")
	_assert(hud._hull_label.text == "%d/%d" % [crawler.hull_hp, crawler.max_hull_hp], "Hull label updates on signal")

	## Spend energy via signal
	crawler.spend_energy(15)
	_assert(hud._energy_bar.value == float(crawler.energy), "Energy bar updates on energy_changed signal")

	_cleanup_node(hud)
	_cleanup_node(crawler)


func _test_crawler_hud_items() -> void:
	print("--- CrawlerHUD: Items Display ---")
	var crawler: CrawlerState = _make_crawler()
	crawler.begin_run()
	var hud: CrawlerHUD = CrawlerHUD.new()
	root.add_child(hud)
	hud.setup(crawler)
	hud.refresh()

	_assert("0/5" in hud._items_button.text, "Items shows 0/5 initially")

	## Add an item
	var item: ItemDef = _data_loader.get_item("repair_patch")
	crawler.add_item(item)
	## item_added signal should auto-update
	_assert("1/5" in hud._items_button.text, "Items shows 1/5 after adding item")

	_cleanup_node(hud)
	_cleanup_node(crawler)


# ==========================================================================
# RoomPopup Tests
# ==========================================================================

func _test_room_popup_construction() -> void:
	print("--- RoomPopup: Construction ---")
	var popup: RoomPopup = RoomPopup.new()
	root.add_child(popup)
	_assert(popup != null, "RoomPopup instantiates")
	_assert(not popup.visible, "Hidden by default")
	_assert(popup._title_label != null, "Has title label")
	_assert(popup._description_label != null, "Has description label")
	_assert(popup._action_button != null, "Has action button")
	_cleanup_node(popup)


func _test_room_popup_types() -> void:
	print("--- RoomPopup: Content Per Type ---")
	var popup: RoomPopup = RoomPopup.new()
	root.add_child(popup)

	var type_checks: Dictionary = {
		"enemy": {"title": "Wild Glyphs Ahead!", "action": "Fight"},
		"cache": {"title": "Supply Cache Found!", "action": "Open"},
		"hazard": {"title": "Hazard Zone!", "action": "Continue"},
		"puzzle": {"title": "Puzzle Room", "action": "Attempt"},
		"boss": {"title": "RIFT GUARDIAN", "action": "Challenge Boss"},
		"empty": {"title": "Nothing here.", "action": "Continue"},
		"exit": {"title": "Stairs Down", "action": "Descend"},
		"hidden": {"title": "Hidden Cache Found!", "action": "Open"},
	}

	for room_type: String in type_checks:
		popup.show_room({"type": room_type, "id": "test"})
		var expected: Dictionary = type_checks[room_type]
		_assert(popup.get_title_text().begins_with(expected["title"]), "Type '%s' has correct title" % room_type)
		_assert(popup.get_action_text() == expected["action"], "Type '%s' has action '%s'" % [room_type, expected["action"]])
		_assert(popup.visible, "Popup visible after show_room '%s'" % room_type)

	_cleanup_node(popup)


func _test_room_popup_boss_name() -> void:
	print("--- RoomPopup: Boss Name ---")
	var popup: RoomPopup = RoomPopup.new()
	popup.data_loader = _data_loader as DataLoader
	root.add_child(popup)

	popup.show_room({"type": "boss", "id": "boss_room"}, "thunderclaw")
	_assert("Thunderclaw" in popup.get_title_text(), "Boss popup includes species name")
	_assert("RIFT GUARDIAN" in popup.get_title_text(), "Boss popup includes RIFT GUARDIAN")

	_cleanup_node(popup)


func _test_room_popup_hazard_damage() -> void:
	print("--- RoomPopup: Hazard Damage ---")
	var popup: RoomPopup = RoomPopup.new()
	root.add_child(popup)

	popup.show_room({"type": "hazard", "id": "h1"}, "15")
	_assert("15" in popup.get_description_text(), "Hazard popup shows damage value")

	_cleanup_node(popup)


func _test_room_popup_action_signal() -> void:
	print("--- RoomPopup: Action Signal ---")
	var popup: RoomPopup = RoomPopup.new()
	root.add_child(popup)

	var signal_data: Dictionary = {"received": false, "type": "", "data": {}}
	popup.action_pressed.connect(func(rt: String, rd: Dictionary) -> void:
		signal_data["received"] = true
		signal_data["type"] = rt
		signal_data["data"] = rd
	)

	popup.show_room({"type": "enemy", "id": "e1"})
	popup._action_button.pressed.emit()

	_assert(signal_data["received"], "action_pressed emitted on button press")
	_assert(signal_data["type"] == "enemy", "action_pressed passes correct room type")

	_cleanup_node(popup)


# ==========================================================================
# CapturePopup Tests
# ==========================================================================

func _test_capture_popup_construction() -> void:
	print("--- CapturePopup: Construction ---")
	var popup: CapturePopup = CapturePopup.new()
	root.add_child(popup)
	_assert(popup != null, "CapturePopup instantiates")
	_assert(not popup.visible, "Hidden by default")
	_assert(popup._capture_button != null, "Has capture button")
	_assert(popup._release_button != null, "Has release button")
	_assert(popup._result_label != null, "Has result label")
	_cleanup_node(popup)


func _test_capture_popup_display() -> void:
	print("--- CapturePopup: Display ---")
	var popup: CapturePopup = CapturePopup.new()
	root.add_child(popup)
	var glyph: GlyphInstance = _make_glyph("zapplet")

	popup.show_capture(glyph, 0.65)
	_assert(popup.visible, "Visible after show_capture")
	_assert("65%" in popup.get_chance_text(), "Shows 65% capture chance")
	_assert(popup._name_label.text == "Zapplet", "Shows glyph name")
	_assert(popup._capture_button.visible, "Capture button visible")
	_assert(popup._release_button.visible, "Release button visible")
	_assert(not popup._result_label.visible, "Result label hidden initially")

	_cleanup_node(popup)


func _test_capture_popup_success() -> void:
	print("--- CapturePopup: Capture Success ---")
	var popup: CapturePopup = CapturePopup.new()
	root.add_child(popup)
	var glyph: GlyphInstance = _make_glyph("stonepaw")

	var signal_data: Dictionary = {"received": false, "success": false}
	popup.capture_attempted.connect(func(g: GlyphInstance, s: bool) -> void:
		signal_data["received"] = true
		signal_data["success"] = s
	)

	popup.show_capture(glyph, 0.80)
	## Use deterministic roll (0.5 <= 0.80 = success)
	var result: bool = popup.attempt_capture_with_roll(0.5)

	_assert(result, "Capture succeeds with roll 0.5 and chance 0.80")
	_assert(signal_data["received"], "capture_attempted signal emitted")
	_assert(signal_data["success"], "Signal reports success")
	_assert(popup.get_result_text() == "CAPTURED!", "Shows CAPTURED! text")
	_assert(popup._capture_button.disabled, "Capture button disabled after attempt")
	_assert(not popup._release_button.visible, "Release button hidden after attempt")

	_cleanup_node(popup)


func _test_capture_popup_failure() -> void:
	print("--- CapturePopup: Capture Failure ---")
	var popup: CapturePopup = CapturePopup.new()
	root.add_child(popup)
	var glyph: GlyphInstance = _make_glyph("mossling")

	popup.show_capture(glyph, 0.40)
	## Roll 0.9 > 0.40 = failure
	var result: bool = popup.attempt_capture_with_roll(0.9)

	_assert(not result, "Capture fails with roll 0.9 and chance 0.40")
	_assert(popup.get_result_text() == "ESCAPED!", "Shows ESCAPED! text")

	_cleanup_node(popup)


func _test_capture_popup_release() -> void:
	print("--- CapturePopup: Release ---")
	var popup: CapturePopup = CapturePopup.new()
	root.add_child(popup)
	var glyph: GlyphInstance = _make_glyph("driftwisp")

	var signal_data: Dictionary = {"released": false}
	popup.capture_released.connect(func(_g: GlyphInstance) -> void:
		signal_data["released"] = true
	)

	popup.show_capture(glyph, 0.50)
	popup._release_button.pressed.emit()

	_assert(signal_data["released"], "capture_released signal emitted on release")

	_cleanup_node(popup)


# ==========================================================================
# CapturePopup Bench Swap Tests
# ==========================================================================

func _test_capture_popup_bench_swap_display() -> void:
	print("--- CapturePopup: Bench Swap Display ---")
	var popup: CapturePopup = CapturePopup.new()
	root.add_child(popup)

	var new_glyph: GlyphInstance = _make_glyph("zapplet")
	var bench_a: GlyphInstance = _make_glyph("stonepaw")
	var bench_b: GlyphInstance = _make_glyph("sparkfin")
	var bench: Array[GlyphInstance] = [bench_a, bench_b]

	popup.show_bench_swap(new_glyph, bench)

	_assert(popup.visible, "Popup visible after show_bench_swap")
	_assert(popup._title_label.text == "Bench Full!", "Title shows Bench Full!")
	_assert(popup._name_label.text == "Zapplet", "Shows new glyph name")
	_assert(not popup._capture_button.visible, "Capture button hidden in swap mode")
	_assert(not popup._release_button.visible, "Release button hidden in swap mode")
	_assert(popup._swap_container.visible, "Swap container visible")
	_assert(popup._swap_container.get_child_count() == 2, "Two swap buttons for two bench glyphs")
	_assert(popup._abandon_btn.visible, "Abandon button visible")

	var btn0: Button = popup._swap_container.get_child(0) as Button
	_assert("Stonepaw" in btn0.text, "First swap button shows Stonepaw")
	var btn1: Button = popup._swap_container.get_child(1) as Button
	_assert("Sparkfin" in btn1.text, "Second swap button shows Sparkfin")

	_cleanup_node(popup)


func _test_capture_popup_bench_swap_release() -> void:
	print("--- CapturePopup: Bench Swap Release ---")
	var popup: CapturePopup = CapturePopup.new()
	root.add_child(popup)

	var new_glyph: GlyphInstance = _make_glyph("zapplet")
	var bench_a: GlyphInstance = _make_glyph("stonepaw")
	var bench_b: GlyphInstance = _make_glyph("sparkfin")
	var bench: Array[GlyphInstance] = [bench_a, bench_b]

	var signal_data: Dictionary = {"received": false, "keep": null, "release": null}
	popup.bench_swap_chosen.connect(func(k: GlyphInstance, r: GlyphInstance) -> void:
		signal_data["received"] = true
		signal_data["keep"] = k
		signal_data["release"] = r
	)

	var dismissed_data: Dictionary = {"received": false}
	popup.dismissed.connect(func() -> void:
		dismissed_data["received"] = true
	)

	popup.show_bench_swap(new_glyph, bench)

	## Click to release first bench glyph
	var btn0: Button = popup._swap_container.get_child(0) as Button
	btn0.pressed.emit()

	_assert(signal_data["received"], "bench_swap_chosen emitted on release click")
	_assert(signal_data["keep"] == new_glyph, "Keep glyph is the new capture")
	_assert(signal_data["release"] == bench_a, "Released glyph is the clicked bench glyph")
	_assert(popup._result_label.visible, "result label visible after swap")
	_assert("CAPTURED" in popup._result_label.text, "result shows CAPTURED after swap")
	_assert(popup._continue_button.visible, "continue button visible after swap")
	## Click Continue to dismiss
	popup._continue_button.pressed.emit()
	_assert(dismissed_data["received"], "dismissed emitted after continue")

	_cleanup_node(popup)


func _test_capture_popup_bench_swap_abandon() -> void:
	print("--- CapturePopup: Bench Swap Abandon ---")
	var popup: CapturePopup = CapturePopup.new()
	root.add_child(popup)

	var new_glyph: GlyphInstance = _make_glyph("zapplet")
	var bench_a: GlyphInstance = _make_glyph("stonepaw")
	var bench: Array[GlyphInstance] = [bench_a]

	var swap_data: Dictionary = {"received": false}
	popup.bench_swap_chosen.connect(func(_k: GlyphInstance, _r: GlyphInstance) -> void:
		swap_data["received"] = true
	)

	var dismissed_data: Dictionary = {"received": false}
	popup.dismissed.connect(func() -> void:
		dismissed_data["received"] = true
	)

	popup.show_bench_swap(new_glyph, bench)
	popup._abandon_btn.pressed.emit()

	_assert(not swap_data["received"], "bench_swap_chosen NOT emitted on abandon")
	_assert(dismissed_data["received"], "dismissed emitted on abandon")

	_cleanup_node(popup)


# ==========================================================================
# DungeonScene Tests
# ==========================================================================

func _test_dungeon_scene_construction() -> void:
	print("--- DungeonScene: Construction ---")
	var scene: DungeonScene = DungeonScene.new()
	root.add_child(scene)
	_assert(scene != null, "DungeonScene instantiates")
	_assert(scene._floor_map != null, "Has FloorMap")
	_assert(scene._crawler_hud != null, "Has CrawlerHUD")
	_assert(scene._room_popup != null, "Has RoomPopup")
	_assert(scene._capture_popup != null, "Has CapturePopup")
	_assert(scene._background != null, "Has background")
	_assert(scene._floor_label != null, "Has floor label")
	_cleanup_node(scene)


func _test_dungeon_scene_start_rift() -> void:
	print("--- DungeonScene: Start Rift ---")
	var ds: DungeonState = _make_dungeon_state_with_floors([_make_simple_floor()])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)

	scene.instant_mode = true
	scene.start_rift(ds)

	_assert(scene.dungeon_state == ds, "Dungeon state is set")
	_assert(scene.get_ui_state() == DungeonScene.UIState.EXPLORING, "UI state is EXPLORING")
	_assert(scene._floor_map.get_room_count() == 3, "FloorMap has 3 rooms")
	_assert("Floor 1" in scene._floor_label.text, "Floor label shows Floor 1")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_dungeon_scene_room_navigation() -> void:
	print("--- DungeonScene: Room Navigation ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "empty", "visited": false, "revealed": true},
			{"id": "r2", "x": 2, "y": 0, "type": "exit", "visited": false, "revealed": false},
		],
		"connections": [["r0", "r1"], ["r1", "r2"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	## Click on adjacent room r1 (empty room)
	scene._on_room_clicked("r1")
	_assert(ds.current_room_id == "r1", "Moved to r1 after click")

	## r2 is now auto-revealed (adjacent to r1 after moving there)
	## Click on r2 (exit) — shows exit popup, stays on floor 0
	scene._room_popup.hide_popup()
	scene._state = DungeonScene.UIState.EXPLORING
	scene._on_room_clicked("r2")
	_assert(ds.current_room_id == "r2", "Moved to r2 (exit)")
	## Exit overlay shown, click Stay to dismiss
	scene._exit_stay_btn.pressed.emit()
	_assert(scene.get_ui_state() == DungeonScene.UIState.EXPLORING, "Back to EXPLORING after Stay")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_dungeon_scene_popup_flow() -> void:
	print("--- DungeonScene: Popup Flow ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	## Click enemy room
	scene._on_room_clicked("r1")
	_assert(scene.get_ui_state() == DungeonScene.UIState.POPUP, "State is POPUP after entering enemy room")
	_assert(scene._room_popup.visible, "Room popup is visible")
	_assert(scene._room_popup.get_title_text() == "Wild Glyphs Ahead!", "Popup shows enemy title")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_dungeon_scene_ability_usage() -> void:
	print("--- DungeonScene: Ability Usage ---")
	var ds: DungeonState = _make_dungeon_state_with_floors([_make_simple_floor()])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	var initial_energy: int = ds.crawler.energy

	## Use scan ability
	scene._on_ability_pressed("scan")
	var cost: int = ds.crawler.get_ability_cost("scan")
	_assert(ds.crawler.energy == initial_energy - cost, "Energy reduced by scan cost")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_dungeon_scene_floor_transition() -> void:
	print("--- DungeonScene: Floor Transition ---")
	var floors: Array[Dictionary] = _make_multi_floor()
	var ds: DungeonState = _make_dungeon_state_with_floors(floors)
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	var floor_signal: Dictionary = {"changed": false, "floor": -1}
	scene.floor_changed.connect(func(f: int) -> void:
		floor_signal["changed"] = true
		floor_signal["floor"] = f
	)

	_assert(ds.current_floor == 0, "Starts on floor 0")
	_assert("Floor 1" in scene._floor_label.text, "Label shows Floor 1")

	## Navigate: r0 → r1 (enemy) — r1 is auto-revealed (adjacent to start)
	scene._on_room_clicked("f0_r1")
	scene._room_popup.hide_popup()
	scene._state = DungeonScene.UIState.EXPLORING

	## Move to exit — shows exit overlay instead of auto-advancing
	scene._on_room_clicked("f0_r2")

	_assert(ds.current_floor == 0, "Still on floor 0 (exit popup shown)")
	_assert(scene._exit_overlay.visible, "Exit overlay is visible")
	_assert(scene.get_ui_state() == DungeonScene.UIState.POPUP, "UI state is POPUP")

	## Click Descend to advance
	scene._exit_descend_btn.pressed.emit()

	_assert(ds.current_floor == 1, "Advanced to floor 1 after Descend")
	_assert(floor_signal["changed"], "floor_changed signal emitted")
	_assert(floor_signal["floor"] == 1, "floor_changed reports floor 1")
	_assert("Floor 2" in scene._floor_label.text, "Label shows Floor 2")
	_assert(not scene._exit_overlay.visible, "Exit overlay hidden after descend")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_dungeon_scene_forced_extraction() -> void:
	print("--- DungeonScene: Forced Extraction ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "hazard", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	var rift_signal: Dictionary = {"completed": false, "won": true}
	scene.rift_completed.connect(func(w: bool) -> void:
		rift_signal["completed"] = true
		rift_signal["won"] = w
	)

	## Set hull to very low so hazard kills it
	ds.crawler.hull_hp = 5

	## Move to hazard room — triggers damage (10 default) → hull ≤ 0 → forced_extraction
	scene._on_room_clicked("r1")

	_assert(scene.get_ui_state() == DungeonScene.UIState.RESULT, "UI state is RESULT")
	## Click Continue on result overlay to emit rift_completed
	scene._result_continue.pressed.emit()
	_assert(rift_signal["completed"], "rift_completed emitted after forced extraction")
	_assert(not rift_signal["won"], "rift_completed reports loss (won=false)")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_dungeon_scene_combat_signal() -> void:
	print("--- DungeonScene: Combat Signal ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	var combat_signal: Dictionary = {"requested": false, "enemies": [], "boss": null}
	scene.combat_requested.connect(func(e: Array[GlyphInstance], b: BossDef) -> void:
		combat_signal["requested"] = true
		combat_signal["enemies"] = e
		combat_signal["boss"] = b
	)

	## Click enemy room then press Fight
	scene._on_room_clicked("r1")
	scene._on_popup_action("enemy", {"type": "enemy", "id": "r1"})

	_assert(combat_signal["requested"], "combat_requested emitted after Fight action")
	_assert(combat_signal["enemies"].size() > 0, "Enemies array is non-empty")
	_assert(combat_signal["boss"] == null, "Boss def is null for wild encounter")
	_assert(scene.get_ui_state() == DungeonScene.UIState.COMBAT, "UI state is COMBAT")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_dungeon_scene_capture_flow() -> void:
	print("--- DungeonScene: Capture Flow ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	## Simulate combat finished with a capturable glyph
	var wild: GlyphInstance = _make_glyph("sparkfin")
	wild.side = "enemy"
	var enemies: Array[GlyphInstance] = [wild]
	scene.on_combat_finished(true, enemies)

	_assert(scene.get_ui_state() == DungeonScene.UIState.CAPTURE, "UI state is CAPTURE after winning")
	_assert(scene._capture_popup.visible, "Capture popup is visible")

	## Test capture signal
	var capture_signal: Dictionary = {"requested": false}
	scene.capture_requested.connect(func(_g: GlyphInstance) -> void:
		capture_signal["requested"] = true
	)
	scene._capture_popup.attempt_capture_with_roll(0.0)  ## Guaranteed success (0.0 <= any chance)
	_assert(capture_signal["requested"], "capture_requested emitted on successful capture")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


# ==========================================================================
# Fog of War Tests
# ==========================================================================

func _test_fog_of_war() -> void:
	print("--- Fog of War ---")
	var ds: DungeonState = _make_dungeon_state_with_floors([_make_simple_floor()])
	var fm: FloorMap = FloorMap.new()
	fm.size = Vector2(800, 500)
	root.add_child(fm)
	fm.build_floor(ds.floors[0], ds)
	fm.set_current_room("r0")
	fm.refresh_all()

	## r0 (start) is visited+revealed
	var r0: RoomNode = fm.get_room_node("r0")
	_assert(r0.state == RoomNode.RoomState.CURRENT, "Start room is CURRENT")

	## r1 (enemy) is FOGGY (visible but type unknown, adjacent to start)
	var r1: RoomNode = fm.get_room_node("r1")
	_assert(r1.state == RoomNode.RoomState.FOGGY, "Enemy room is FOGGY (adjacent to start)")
	_assert(r1._icon_label.text == "?", "Foggy room shows ?")
	_assert(r1.visible, "Foggy room is visible on screen")

	## r2 (exit) is unrevealed (not adjacent to start)
	var r2: RoomNode = fm.get_room_node("r2")
	_assert(r2.state == RoomNode.RoomState.UNREVEALED, "Exit room is unrevealed")
	_assert(not r2.visible, "Unrevealed room is invisible on screen")

	_cleanup_node(fm)
	_cleanup_node(ds.crawler)


func _test_scan_reveals_adjacent() -> void:
	print("--- Scan Reveals Adjacent ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": false},
			{"id": "r2", "x": 2, "y": 0, "type": "cache", "visited": false, "revealed": false},
			{"id": "r3", "x": 3, "y": 0, "type": "exit", "visited": false, "revealed": false},
		],
		"connections": [["r0", "r1"], ["r1", "r2"], ["r2", "r3"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])

	## After floor entry, r1 is visible but foggy (adjacent to start)
	_assert(ds.floors[0]["rooms"][1].get("visible", false), "r1 visible (adjacent to start)")
	_assert(not ds.floors[0]["rooms"][1]["revealed"], "r1 NOT revealed (foggy)")
	_assert(not ds.floors[0]["rooms"][2]["revealed"], "r2 starts unrevealed")

	## Connect signal to track reveals
	var revealed_ids: Array = []
	ds.room_revealed.connect(func(rid: String, _rt: String) -> void:
		revealed_ids.append(rid)
	)

	## Scan from r0 — fully reveals r1 (adjacent, was foggy)
	ds.use_crawler_ability("scan")
	_assert(ds.floors[0]["rooms"][1]["revealed"], "r1 fully revealed after scan")
	_assert(revealed_ids.has("r1"), "room_revealed signal for r1")
	_assert(not revealed_ids.has("r2"), "r2 not adjacent to r0, not revealed")
	_assert(ds.crawler.energy < ds.crawler.max_energy, "Scan consumed energy")

	_cleanup_node(ds.crawler)


func _test_click_to_navigate() -> void:
	print("--- Click-to-Navigate: multi-hop walk ---")
	## Floor: start → empty → empty → exit (all visible)
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true, "visible": true},
			{"id": "r1", "x": 1, "y": 0, "type": "empty", "visited": true, "revealed": true, "visible": true},
			{"id": "r2", "x": 2, "y": 0, "type": "empty", "visited": true, "revealed": true, "visible": true},
			{"id": "r3", "x": 3, "y": 0, "type": "exit", "visited": false, "revealed": true, "visible": true},
		],
		"connections": [["r0", "r1"], ["r1", "r2"], ["r2", "r3"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	## Click r3 (3 rooms away) — should pathfind and walk through empty rooms
	## Stops at exit (exit_reached signal triggers popup)
	scene._on_room_clicked("r3")

	## Should have walked to r3 (exit popup shown)
	_assert(ds.current_room_id == "r3", "Walked to r3 via pathfinding (got %s)" % ds.current_room_id)
	## r1 and r2 should be visited
	_assert(ds.floors[0]["rooms"][1]["visited"], "r1 visited along path")
	_assert(ds.floors[0]["rooms"][2]["visited"], "r2 visited along path")
	## Exit popup should be shown
	_assert(scene.get_ui_state() == DungeonScene.UIState.POPUP, "Exit popup shown")

	## Dismiss exit popup
	scene._exit_stay_btn.pressed.emit()
	_assert(scene.get_ui_state() == DungeonScene.UIState.EXPLORING, "Back to exploring after stay")

	## Click r0 (backtrack 3 rooms) — should walk back through cleared rooms
	scene._on_room_clicked("r0")
	_assert(ds.current_room_id == "r0", "Walked back to r0 via pathfinding")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_click_to_navigate_stops_at_combat() -> void:
	print("--- Click-to-Navigate: stops at combat room ---")
	## Floor: start → enemy → empty (all visible)
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true, "visible": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true, "visible": true},
			{"id": "r2", "x": 2, "y": 0, "type": "empty", "visited": false, "revealed": true, "visible": true},
		],
		"connections": [["r0", "r1"], ["r1", "r2"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	## Click r2 (2 rooms away) — should stop at r1 (enemy popup)
	scene._on_room_clicked("r2")

	_assert(ds.current_room_id == "r1", "Stopped at enemy room r1 (got %s)" % ds.current_room_id)
	_assert(scene.get_ui_state() == DungeonScene.UIState.POPUP, "Enemy popup shown")
	_assert(ds.floors[0]["rooms"][2]["visited"] == false, "r2 NOT visited (path interrupted)")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


# ==========================================================================
# Crawler Token & Path Preview Tests
# ==========================================================================

func _test_crawler_token_position() -> void:
	print("--- CrawlerToken: Position after start_rift ---")
	var floor_data: Dictionary = _make_simple_floor()
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	## Token should exist
	var token: CrawlerToken = scene._floor_map._crawler_token
	_assert(token != null, "CrawlerToken exists on FloorMap")
	_assert(token.instant_mode, "Token has instant_mode from FloorMap")

	## Token should be at start room center
	var start_center: Vector2 = scene._floor_map.get_room_center("r0")
	var expected_pos: Vector2 = start_center - CrawlerToken.TOKEN_SIZE / 2.0
	_assert(token.position.distance_to(expected_pos) < 1.0, "Token at start room center (got %s, expected %s)" % [token.position, expected_pos])

	## Move to r1 — token should update
	ds.move_to_room("r1")
	var r1_center: Vector2 = scene._floor_map.get_room_center("r1")
	var expected_r1: Vector2 = r1_center - CrawlerToken.TOKEN_SIZE / 2.0
	_assert(token.position.distance_to(expected_r1) < 1.0, "Token moved to r1 center after navigation")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_path_preview() -> void:
	print("--- PathPreview: Show and clear ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true, "visible": true},
			{"id": "r1", "x": 1, "y": 0, "type": "empty", "visited": true, "revealed": true, "visible": true},
			{"id": "r2", "x": 2, "y": 0, "type": "empty", "visited": true, "revealed": true, "visible": true},
		],
		"connections": [["r0", "r1"], ["r1", "r2"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	## Show preview for path [r1, r2]
	var path: Array[String] = ["r1", "r2"]
	scene._floor_map.show_path_preview(path)

	## Preview line should be visible with 3 points (current + 2 path rooms)
	_assert(scene._floor_map._preview_line.visible, "Preview line visible after show_path_preview")
	_assert(scene._floor_map._preview_line.get_point_count() == 3, "Preview line has 3 points (got %d)" % scene._floor_map._preview_line.get_point_count())

	## Room r1 and r2 should have preview highlight
	var r1_node: RoomNode = scene._floor_map.get_room_node("r1")
	var r2_node: RoomNode = scene._floor_map.get_room_node("r2")
	_assert(r1_node._preview_highlight.visible, "r1 preview highlight visible")
	_assert(r2_node._preview_highlight.visible, "r2 preview highlight visible")

	## r0 (current) should NOT have preview highlight
	var r0_node: RoomNode = scene._floor_map.get_room_node("r0")
	_assert(not r0_node._preview_highlight.visible, "r0 (current) no preview highlight")

	## Clear preview
	scene._floor_map.clear_path_preview()
	_assert(not scene._floor_map._preview_line.visible, "Preview line hidden after clear")
	_assert(not r1_node._preview_highlight.visible, "r1 preview cleared")
	_assert(not r2_node._preview_highlight.visible, "r2 preview cleared")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_preview_highlight() -> void:
	print("--- RoomNode: Preview Highlight ---")
	var node: RoomNode = RoomNode.new()
	root.add_child(node)
	node.setup({"id": "r1", "x": 0, "y": 0, "type": "enemy", "visited": true, "revealed": true})

	_assert(node._preview_highlight != null, "Has preview highlight panel")
	_assert(not node._preview_highlight.visible, "Preview highlight hidden by default")

	node.set_preview_highlight(true)
	_assert(node._preview_highlight.visible, "Preview highlight shown when set")

	node.set_preview_highlight(false)
	_assert(not node._preview_highlight.visible, "Preview highlight hidden when cleared")

	_cleanup_node(node)


func _test_moving_state_blocks_clicks() -> void:
	print("--- DungeonScene: MOVING state blocks clicks ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true, "visible": true},
			{"id": "r1", "x": 1, "y": 0, "type": "empty", "visited": true, "revealed": true, "visible": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	scene.start_rift(ds)

	## Manually set MOVING state
	scene._state = DungeonScene.UIState.MOVING
	scene._on_room_clicked("r1")

	## Should NOT have moved (still at r0)
	_assert(ds.current_room_id == "r0", "MOVING state blocks room click (still at r0, got %s)" % ds.current_room_id)

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_boss_capture_on_rerun() -> void:
	print("--- BossCapture: Offered on re-run ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "boss", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true

	## Mark this rift as previously cleared
	var codex: CodexState = CodexState.new()
	var rift_id: String = ds.rift_template.rift_id
	codex.mark_rift_cleared(rift_id)
	scene.codex_state = codex

	scene.start_rift(ds)

	## Create a boss glyph
	var boss: GlyphInstance = _make_glyph("zapplet")
	boss.is_boss = true
	boss.side = "enemy"
	var enemies: Array[GlyphInstance] = [boss]

	## Simulate winning the boss fight on a re-run
	scene.on_combat_finished(true, enemies, 3)

	## Should show capture popup (not result screen)
	_assert(scene.get_ui_state() == DungeonScene.UIState.CAPTURE, "Boss capture offered on re-run (got state %d)" % scene.get_ui_state())
	_assert(scene._boss_capture_pending, "Boss capture pending flag set")

	## Dismiss capture → should show rift result
	scene._on_capture_dismissed()
	_assert(scene.get_ui_state() == DungeonScene.UIState.RESULT, "Rift result shown after boss capture dismiss")
	_assert(not scene._boss_capture_pending, "Boss capture pending cleared")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_boss_no_capture_on_first_clear() -> void:
	print("--- BossCapture: Not offered on first clear ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "boss", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true

	## Codex with NO prior clear
	var codex: CodexState = CodexState.new()
	scene.codex_state = codex

	scene.start_rift(ds)

	## Create a boss glyph
	var boss: GlyphInstance = _make_glyph("zapplet")
	boss.is_boss = true
	boss.side = "enemy"
	var enemies: Array[GlyphInstance] = [boss]

	## Simulate winning the boss fight on first clear
	scene.on_combat_finished(true, enemies, 3)

	## Should go straight to result (no capture)
	_assert(scene.get_ui_state() == DungeonScene.UIState.RESULT, "First clear skips boss capture (got state %d)" % scene.get_ui_state())
	_assert(not scene._boss_capture_pending, "No boss capture pending on first clear")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


# ==========================================================================
# Battle Loss Penalty Tests (GDD 8.13)
# ==========================================================================

func _test_battle_loss_pushback() -> void:
	print("--- BattleLoss: Pushback + revive + hull damage ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true

	## Set up roster with a squad
	var roster: RosterState = RosterState.new()
	var g1: GlyphInstance = _make_glyph("sparkfin")
	var g2: GlyphInstance = _make_glyph("zapplet")
	roster.active_squad.append(g1)
	roster.active_squad.append(g2)
	scene.roster_state = roster

	scene.start_rift(ds)

	## Navigate to enemy room
	scene._on_room_clicked("r1")
	_assert(ds.current_room_id == "r1", "Moved to r1")

	## Enter combat
	scene._on_popup_action("enemy", {"type": "enemy", "id": "r1"})
	_assert(scene._pre_combat_room_id == "r0", "Pre-combat room saved as r0 (got %s)" % scene._pre_combat_room_id)

	## KO one glyph
	g1.current_hp = 0
	g1.is_knocked_out = true

	var initial_hull: int = ds.crawler.hull_hp

	## Simulate losing the battle
	var enemies: Array[GlyphInstance] = [_make_glyph("zapplet")]
	scene.on_combat_finished(false, enemies, 3)

	## Assertions
	_assert(ds.current_room_id == "r0", "Pushed back to previous room r0 (got %s)" % ds.current_room_id)
	_assert(not g1.is_knocked_out, "KO'd glyph revived")
	_assert(g1.current_hp == maxi(1, int(float(g1.max_hp) * 0.3)), "Revived at 30%% HP (got %d, expected %d)" % [g1.current_hp, maxi(1, int(float(g1.max_hp) * 0.3))])
	_assert(ds.crawler.hull_hp == initial_hull - 15, "Hull took 15 damage (got %d, expected %d)" % [ds.crawler.hull_hp, initial_hull - 15])
	_assert(scene.get_ui_state() == DungeonScene.UIState.EXPLORING, "Back to EXPLORING state")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_battle_loss_hull_zero_extracts() -> void:
	print("--- BattleLoss: Hull zero → forced extraction ---")
	var floor_data: Dictionary = {
		"floor_number": 0,
		"rooms": [
			{"id": "r0", "x": 0, "y": 0, "type": "start", "visited": true, "revealed": true},
			{"id": "r1", "x": 1, "y": 0, "type": "enemy", "visited": false, "revealed": true},
		],
		"connections": [["r0", "r1"]],
	}
	var ds: DungeonState = _make_dungeon_state_with_floors([floor_data])
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true

	## Set up roster with a squad
	var roster: RosterState = RosterState.new()
	var g1: GlyphInstance = _make_glyph("sparkfin")
	roster.active_squad.append(g1)
	scene.roster_state = roster

	scene.start_rift(ds)

	## Navigate to enemy room and enter combat
	scene._on_room_clicked("r1")
	scene._on_popup_action("enemy", {"type": "enemy", "id": "r1"})

	## Set hull very low (< 15 so loss penalty destroys it)
	ds.crawler.hull_hp = 10

	## Simulate losing the battle
	var enemies: Array[GlyphInstance] = [_make_glyph("zapplet")]
	scene.on_combat_finished(false, enemies, 3)

	## Hull should be 0 and result overlay shown (forced extraction)
	_assert(ds.crawler.hull_hp == 0, "Hull reduced to 0")
	_assert(scene.get_ui_state() == DungeonScene.UIState.RESULT, "Forced extraction → RESULT state")

	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_pause_menu_exists() -> void:
	print("--- Pause menu exists ---")
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	var ds: DungeonState = _make_dungeon_state()
	scene.start_rift(ds)

	_assert(scene._pause_menu != null, "Pause menu exists")
	_assert(not scene._pause_menu.is_open, "Pause menu closed by default")
	_assert(scene._pause_menu._resume_btn != null, "Resume button exists")
	_assert(scene._pause_menu._save_quit_btn != null, "Save & Quit button exists")
	_assert(scene._pause_menu._save_slots_btn != null, "Save Slots button exists")
	_cleanup_node(scene)
	_cleanup_node(ds.crawler)


func _test_pause_save_and_quit_signal() -> void:
	print("--- Pause save & quit emits signal ---")
	var scene: DungeonScene = DungeonScene.new()
	scene.data_loader = _data_loader
	root.add_child(scene)
	scene.instant_mode = true
	var ds: DungeonState = _make_dungeon_state()
	scene.start_rift(ds)

	var sig: Dictionary = {"fired": false}
	scene.save_and_quit_pressed.connect(func() -> void: sig["fired"] = true)

	## Toggle on
	scene._pause_menu.toggle()
	_assert(scene._pause_menu.is_open, "Pause menu open after toggle")

	## Resume closes it
	scene._pause_menu._resume_btn.pressed.emit()
	_assert(not scene._pause_menu.is_open, "Pause menu closed after resume")

	## Save & quit emits signal
	scene._pause_menu.toggle()
	scene._pause_menu._save_quit_btn.pressed.emit()
	_assert(not scene._pause_menu.is_open, "Pause menu closed after save & quit")
	_assert(sig["fired"], "save_and_quit_pressed signal fired")
	_cleanup_node(scene)
	_cleanup_node(ds.crawler)
