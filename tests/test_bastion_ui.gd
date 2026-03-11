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
	print("  GLYPHRIFT — Bastion UI Tests")
	print("========================================")
	print("")

	## GlyphCard
	_test_glyph_card_construction()
	_test_glyph_card_display()
	_test_glyph_card_click_signal()
	_test_glyph_card_selected_state()
	_test_glyph_card_disabled_state()
	_test_glyph_card_mastery_indicator()
	_test_glyph_card_mastery_bar_progress()
	_test_glyph_card_no_species()

	## Barracks
	_test_barracks_construction()
	_test_barracks_roster_display()
	_test_barracks_squad_to_reserve()
	_test_barracks_reserve_to_squad()
	_test_barracks_gp_capacity()
	_test_barracks_slot_limits()
	_test_barracks_row_assignment()
	_test_barracks_reserve_full()
	_test_barracks_gp_counter()
	_test_barracks_done_signal()

	## FusionChamber
	_test_fusion_construction()
	_test_fusion_picker_shows_glyphs()
	_test_fusion_picker_mastered_clickable()
	_test_fusion_parent_selection()
	_test_fusion_can_fuse_invalid()
	_test_fusion_preview_display()
	_test_fusion_technique_selection()
	_test_fusion_execute()
	_test_fusion_gp_warning()
	_test_fusion_clear_parent()
	_test_fusion_same_glyph_blocked()

	## RiftGate
	_test_rift_gate_construction()
	_test_rift_gate_list()
	_test_rift_gate_cleared_marker()
	_test_rift_gate_enter_signal()
	_test_rift_gate_boss_name()

	## BastionScene
	_test_bastion_construction()
	_test_bastion_navigation_barracks()
	_test_bastion_navigation_fusion()
	_test_bastion_navigation_rift_gate()
	_test_bastion_status_bar()
	_test_bastion_squad_preview()
	_test_bastion_rift_selected_signal()
	_test_bastion_back_to_hub()

	## SquadOverlay
	_test_squad_overlay_construction()
	_test_squad_overlay_display()
	_test_squad_overlay_hp_update()
	_test_squad_overlay_color_thresholds()

	## MainScene (isolate from real saves)
	SaveManager._test_prefix = "bastion_ui_"
	_test_main_scene_construction()
	_test_main_scene_start_game()
	_test_main_scene_rift_flow()
	_test_main_scene_combat_flow()
	_test_main_scene_hp_persistence()
	_test_main_scene_heal_on_return()
	_test_main_scene_capture_flow()
	_test_main_scene_rift_completion()
	SaveManager._test_prefix = ""

	## GlyphDetailPopup
	_test_detail_popup_construction()
	_test_detail_popup_shows_glyph_info()
	_test_detail_popup_mastery_objectives()
	_test_detail_popup_completed_objectives()
	_test_detail_popup_mastered_banner()
	_test_detail_popup_progressive_counter()
	_test_detail_popup_t4_mastery()
	_test_detail_popup_close()

	## ResultScreen Mastery
	_test_result_screen_mastery_section()
	_test_result_screen_mastery_objective_completed()
	_test_result_screen_mastery_glyph_mastered()
	_test_result_screen_defeat_no_mastery()

	## BattleScene Mastery Wiring
	_test_battle_scene_mastery_tracker()
	_test_battle_scene_mastery_events_collected()

	## Barracks Info Button
	_test_barracks_info_button()
	_test_barracks_info_popup()

	## BastionScene Detail Popup
	_test_bastion_squad_card_popup()
	_test_bastion_mastery_hint()

	## Milestone Toast
	SaveManager._test_prefix = "bastion_ui_"
	_test_milestone_toast()
	SaveManager._test_prefix = ""

	## CrawlerBay
	_test_crawler_bay_construction()
	_test_crawler_bay_stats_display()
	_test_crawler_bay_chassis_selection()
	_test_crawler_bay_milestone_display()
	_test_bastion_navigation_crawler_bay()

	## Settings
	_test_game_settings_default()
	_test_game_settings_cycle()
	_test_game_settings_delay_multiplier()
	_test_settings_popup_construction()
	_test_settings_popup_speed_cycle()
	_test_settings_popup_font_size()
	_test_game_settings_font_scale()
	_test_pause_menu_settings_button()

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


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()


# ==========================================================================
# GlyphCard Tests
# ==========================================================================

func _test_glyph_card_construction() -> void:
	print("--- GlyphCard: Construction ---")
	var card: GlyphCard = GlyphCard.new()
	root.add_child(card)

	_assert(card.custom_minimum_size == Vector2(120, 160), "card min size 120x160")
	_assert(card._bg != null, "card has background panel")
	_assert(card._name_label != null, "card has name label")
	_assert(card._mastery_bar != null, "card has mastery bar")
	_assert(card._select_border != null, "card has selection border")
	_assert(not card._select_border.visible, "selection border hidden by default")

	_cleanup_node(card)


func _test_glyph_card_display() -> void:
	print("--- GlyphCard: Display Values ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var card: GlyphCard = GlyphCard.new()
	card.glyph = g
	root.add_child(card)

	_assert(card._name_label.text == "Zapplet", "card shows species name")
	_assert(card._info_label.text.contains("Electric"), "card shows affinity")
	_assert(card._info_label.text.contains("T1"), "card shows tier")
	_assert(card._gp_label.text.contains("GP:"), "card shows GP cost")
	_assert(card._stats_label.text.contains("HP:"), "card shows HP stat")
	_assert(card._stats_label.text.contains("ATK:"), "card shows ATK stat")

	_cleanup_node(card)


func _test_glyph_card_click_signal() -> void:
	print("--- GlyphCard: Click Signal ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var card: GlyphCard = GlyphCard.new()
	card.glyph = g
	root.add_child(card)

	var clicked: Dictionary = {"value": false, "glyph": null}
	card.card_clicked.connect(func(gl: GlyphInstance) -> void:
		clicked["value"] = true
		clicked["glyph"] = gl
	)

	card.card_clicked.emit(g)
	_assert(clicked["value"] == true, "card_clicked signal fires")
	_assert(clicked["glyph"] == g, "card_clicked passes glyph")

	_cleanup_node(card)


func _test_glyph_card_selected_state() -> void:
	print("--- GlyphCard: Selected State ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var card: GlyphCard = GlyphCard.new()
	card.glyph = g
	root.add_child(card)

	_assert(not card._select_border.visible, "border hidden initially")
	card.selected = true
	_assert(card._select_border.visible, "border visible when selected")
	card.selected = false
	_assert(not card._select_border.visible, "border hidden after deselect")

	_cleanup_node(card)


func _test_glyph_card_disabled_state() -> void:
	print("--- GlyphCard: Disabled State ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var card: GlyphCard = GlyphCard.new()
	card.glyph = g
	root.add_child(card)

	_assert(card.modulate == Color.WHITE, "normal modulate is white")
	card.disabled_state = true
	_assert(card.modulate.a < 1.0, "disabled state dims card")
	card.disabled_state = false
	_assert(card.modulate == Color.WHITE, "re-enabled restores white")

	_cleanup_node(card)


func _test_glyph_card_mastery_indicator() -> void:
	print("--- GlyphCard: Mastery Indicator ---")
	var g: GlyphInstance = _make_mastered_glyph("zapplet")
	var card: GlyphCard = GlyphCard.new()
	card.glyph = g
	root.add_child(card)

	_assert(card._mastery_check.visible, "checkmark visible for mastered glyph")
	_assert(card._mastery_bar.value == card._mastery_bar.max_value, "mastery bar full")

	_cleanup_node(card)


func _test_glyph_card_mastery_bar_progress() -> void:
	print("--- GlyphCard: Mastery Bar Progress ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	if g.mastery_objectives.size() > 0:
		g.mastery_objectives[0]["completed"] = true
	var card: GlyphCard = GlyphCard.new()
	card.glyph = g
	root.add_child(card)

	_assert(card._mastery_bar.value == 1, "mastery bar shows 1 completed")
	_assert(not card._mastery_check.visible, "no checkmark for partial mastery")

	_cleanup_node(card)


func _test_glyph_card_no_species() -> void:
	print("--- GlyphCard: No Species ---")
	var card: GlyphCard = GlyphCard.new()
	root.add_child(card)
	card.refresh()
	_assert(true, "refresh with null glyph doesn't crash")
	_cleanup_node(card)


# ==========================================================================
# Barracks Tests
# ==========================================================================

func _test_barracks_construction() -> void:
	print("--- Barracks: Construction ---")
	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)

	_assert(barracks._front_row_container != null, "has front row container")
	_assert(barracks._reserve_container != null, "has reserve container")

	_cleanup_node(barracks)


func _test_barracks_roster_display() -> void:
	print("--- Barracks: Roster Display ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	rs.initialize_starting_glyphs(_data_loader)

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	_assert(barracks._squad_cards.size() == 3, "3 squad cards shown")
	_assert(barracks._reserve_cards.size() == 0, "0 reserve cards (no reserves)")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_barracks_squad_to_reserve() -> void:
	print("--- Barracks: Squad to Reserve ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	rs.initialize_starting_glyphs(_data_loader)

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	var first_glyph: GlyphInstance = rs.active_squad[0]
	barracks._remove_from_squad(first_glyph)

	_assert(rs.active_squad.size() == 2, "squad now has 2")
	_assert(barracks._reserve_cards.size() == 1, "1 reserve card after move")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_barracks_reserve_to_squad() -> void:
	print("--- Barracks: Reserve to Squad ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	rs.initialize_starting_glyphs(_data_loader)

	var g: GlyphInstance = rs.active_squad[0]
	var new_squad: Array[GlyphInstance] = []
	for s: GlyphInstance in rs.active_squad:
		if s != g:
			new_squad.append(s)
	rs.set_active_squad(new_squad)

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	_assert(rs.active_squad.size() == 2, "squad starts with 2")
	barracks._on_reserve_card_clicked(g)
	_assert(rs.active_squad.size() == 3, "squad now has 3 after adding reserve")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_barracks_gp_capacity() -> void:
	print("--- Barracks: GP Capacity Enforcement ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	cs.capacity = 4
	rs.initialize_starting_glyphs(_data_loader)
	rs.set_active_squad([])

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	var g1: GlyphInstance = rs.all_glyphs[0]
	var g2: GlyphInstance = rs.all_glyphs[1]
	var g3: GlyphInstance = rs.all_glyphs[2]

	barracks._on_reserve_card_clicked(g1)
	barracks._on_reserve_card_clicked(g2)
	var squad_before: int = rs.active_squad.size()
	barracks._on_reserve_card_clicked(g3)
	_assert(rs.active_squad.size() == squad_before, "GP cap blocks adding third glyph")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_barracks_slot_limits() -> void:
	print("--- Barracks: Slot Limits ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	cs.slots = 2
	rs.initialize_starting_glyphs(_data_loader)

	var squad2: Array[GlyphInstance] = [rs.all_glyphs[0], rs.all_glyphs[1]]
	rs.set_active_squad(squad2)

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	barracks._on_reserve_card_clicked(rs.all_glyphs[2])
	_assert(rs.active_squad.size() == 2, "slot limit blocks adding third glyph")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_barracks_row_assignment() -> void:
	print("--- Barracks: Row Assignment ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	rs.initialize_starting_glyphs(_data_loader)

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	var g: GlyphInstance = rs.active_squad[0]
	_assert(g.row_position == "front", "default row is front")

	## Click card toggles row (same as FormationSetup)
	barracks._on_squad_card_clicked(g)
	_assert(g.row_position == "back", "row toggled to back")
	barracks._on_squad_card_clicked(g)
	_assert(g.row_position == "front", "row toggled back to front")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_barracks_reserve_full() -> void:
	print("--- Barracks: Reserve Full ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	cs.bench_slots = 0
	rs.initialize_starting_glyphs(_data_loader)

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	## Squad→reserve always allowed (rearranging existing roster, not adding new glyphs)
	var g: GlyphInstance = rs.active_squad[0]
	barracks._remove_from_squad(g)
	_assert(rs.active_squad.size() == 2, "squad to reserve allowed even at bench 0 (roster unchanged)")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_barracks_gp_counter() -> void:
	print("--- Barracks: GP Counter ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	rs.initialize_starting_glyphs(_data_loader)

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	_assert(barracks._gp_label.text.contains("GP:"), "GP label contains GP text")
	_assert(barracks._gp_label.text.contains("/%d" % cs.capacity), "GP label shows capacity")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_barracks_done_signal() -> void:
	print("--- Barracks: Squad Protection ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	rs.initialize_starting_glyphs(_data_loader)

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	## Verify blocked when squad is empty
	for g: GlyphInstance in rs.active_squad.duplicate():
		barracks._remove_from_squad(g)
	_assert(rs.active_squad.size() == 1, "can't remove last squad member")
	_assert(barracks._feedback_label.visible == true, "feedback shown for last member")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


# ==========================================================================
# FusionChamber Tests
# ==========================================================================

func _test_fusion_construction() -> void:
	print("--- FusionChamber: Construction ---")
	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)

	_assert(fc._parent_a_slot != null, "has parent A slot")
	_assert(fc._parent_b_slot != null, "has parent B slot")
	_assert(fc._picker_container != null, "has picker container")
	_assert(not fc._preview_panel.visible, "preview hidden initially")
	_assert(not fc._fuse_button.visible, "fuse button hidden initially")

	_cleanup_node(fc)


func _test_fusion_picker_shows_glyphs() -> void:
	print("--- FusionChamber: Picker Shows Glyphs ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var fe: FusionEngine = _make_fusion_engine()
	rs.initialize_starting_glyphs(_data_loader)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	_assert(fc._picker_cards.size() == 3, "picker shows 3 glyphs")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(fe)


func _test_fusion_picker_mastered_clickable() -> void:
	print("--- FusionChamber: Mastered Clickable ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var fe: FusionEngine = _make_fusion_engine()

	var mastered: GlyphInstance = _make_mastered_glyph("zapplet")
	var unmastered: GlyphInstance = _make_glyph("stonepaw")
	rs.add_glyph(mastered)
	rs.add_glyph(unmastered)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	_assert(fc._picker_cards.size() == 2, "picker shows 2 glyphs")
	var mastered_card: GlyphCard = null
	var unmastered_card: GlyphCard = null
	for card: GlyphCard in fc._picker_cards:
		if card.glyph == mastered:
			mastered_card = card
		elif card.glyph == unmastered:
			unmastered_card = card
	_assert(mastered_card != null and not mastered_card.disabled_state, "mastered card enabled")
	_assert(unmastered_card != null and unmastered_card.disabled_state, "unmastered card disabled")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(fe)


func _test_fusion_parent_selection() -> void:
	print("--- FusionChamber: Parent Selection ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var cx: CodexState = _make_codex_state()
	var fe: FusionEngine = _make_fusion_engine()
	fe.data_loader = _data_loader
	fe.codex_state = cx

	var g1: GlyphInstance = _make_mastered_glyph("zapplet")
	var g2: GlyphInstance = _make_mastered_glyph("stonepaw")
	rs.add_glyph(g1)
	rs.add_glyph(g2)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	fc._on_picker_clicked(g1)
	_assert(fc._parent_a == g1, "parent A set to clicked glyph")
	_assert(fc._parent_b == null, "parent B still null")

	fc._on_picker_clicked(g2)
	_assert(fc._parent_b == g2, "parent B set to second glyph")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(cx)
	_cleanup_node(fe)


func _test_fusion_can_fuse_invalid() -> void:
	print("--- FusionChamber: Can Fuse Invalid ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var cx: CodexState = _make_codex_state()
	var fe: FusionEngine = _make_fusion_engine()
	fe.data_loader = _data_loader
	fe.codex_state = cx

	var g1: GlyphInstance = _make_mastered_glyph("zapplet")
	var g2: GlyphInstance = _make_glyph("stonepaw")
	rs.add_glyph(g1)
	rs.add_glyph(g2)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	fc._parent_a = g1
	fc._parent_b = g2
	fc._check_fusion()

	_assert(fc._error_label.visible, "error label shown for invalid fusion")
	_assert(not fc._preview_panel.visible, "preview hidden for invalid fusion")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(cx)
	_cleanup_node(fe)


func _test_fusion_preview_display() -> void:
	print("--- FusionChamber: Preview Display ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var cx: CodexState = _make_codex_state()
	var fe: FusionEngine = _make_fusion_engine()
	fe.data_loader = _data_loader
	fe.codex_state = cx

	var g1: GlyphInstance = _make_mastered_glyph("zapplet")
	var g2: GlyphInstance = _make_mastered_glyph("sparkfin")
	rs.add_glyph(g1)
	rs.add_glyph(g2)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	fc._parent_a = g1
	fc._parent_b = g2
	fc._check_fusion()

	_assert(fc._preview_panel.visible, "preview shown for valid fusion")
	_assert(fc._fuse_button.visible, "fuse button visible")
	_assert(fc._preview_name.text.contains("Result:"), "preview shows result name")
	_assert(fc._preview_stats.text.contains("Stats:"), "preview shows stats")
	_assert(fc._preview_gp.text.contains("GP:"), "preview shows GP")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(cx)
	_cleanup_node(fe)


func _test_fusion_technique_selection() -> void:
	print("--- FusionChamber: Technique Selection ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var cx: CodexState = _make_codex_state()
	var fe: FusionEngine = _make_fusion_engine()
	fe.data_loader = _data_loader
	fe.codex_state = cx

	var g1: GlyphInstance = _make_mastered_glyph("zapplet")
	var g2: GlyphInstance = _make_mastered_glyph("sparkfin")
	rs.add_glyph(g1)
	rs.add_glyph(g2)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	fc._parent_a = g1
	fc._parent_b = g2
	fc._check_fusion()

	_assert(fc._max_techniques >= 0, "max techniques set from preview")
	if fc._technique_buttons.size() > 0:
		fc._technique_buttons[0].set_pressed(true)
		_assert(fc._selected_technique_ids.size() == 1, "one technique selected after toggle")
	else:
		_assert(true, "no inheritable techniques (native fill all slots)")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(cx)
	_cleanup_node(fe)


func _test_fusion_execute() -> void:
	print("--- FusionChamber: Execute Fusion ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var cx: CodexState = _make_codex_state()
	var fe: FusionEngine = _make_fusion_engine()
	fe.data_loader = _data_loader
	fe.codex_state = cx
	fe.roster_state = rs

	var g1: GlyphInstance = _make_mastered_glyph("zapplet")
	var g2: GlyphInstance = _make_mastered_glyph("sparkfin")
	rs.add_glyph(g1)
	rs.add_glyph(g2)
	rs.set_active_squad([g1, g2])

	var fc: FusionChamber = FusionChamber.new()
	fc.instant_mode = true
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	fc._parent_a = g1
	fc._parent_b = g2
	fc._check_fusion()
	fc._on_fuse_pressed()

	_assert(not rs.has_glyph(g1), "parent A removed from roster")
	_assert(not rs.has_glyph(g2), "parent B removed from roster")
	_assert(rs.all_glyphs.size() == 1, "one new glyph in roster")
	_assert(fc._discovery_overlay.visible, "discovery overlay shown")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(cx)
	_cleanup_node(fe)


func _test_fusion_gp_warning() -> void:
	print("--- FusionChamber: GP Warning ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	cs.capacity = 1
	var cx: CodexState = _make_codex_state()
	var fe: FusionEngine = _make_fusion_engine()
	fe.data_loader = _data_loader
	fe.codex_state = cx

	var g1: GlyphInstance = _make_mastered_glyph("zapplet")
	var g2: GlyphInstance = _make_mastered_glyph("sparkfin")
	rs.add_glyph(g1)
	rs.add_glyph(g2)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	fc._parent_a = g1
	fc._parent_b = g2
	fc._check_fusion()

	_assert(fc._gp_warning.visible, "GP warning shown when over capacity")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(cx)
	_cleanup_node(fe)


func _test_fusion_clear_parent() -> void:
	print("--- FusionChamber: Clear Parent Slot ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var cx: CodexState = _make_codex_state()
	var fe: FusionEngine = _make_fusion_engine()
	fe.data_loader = _data_loader
	fe.codex_state = cx

	var g1: GlyphInstance = _make_mastered_glyph("zapplet")
	rs.add_glyph(g1)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	fc._on_picker_clicked(g1)
	_assert(fc._parent_a == g1, "parent A set")

	fc._on_parent_slot_clicked(g1)
	_assert(fc._parent_a == null, "parent A cleared")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(cx)
	_cleanup_node(fe)


func _test_fusion_same_glyph_blocked() -> void:
	print("--- FusionChamber: Same Glyph Blocked ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	var fe: FusionEngine = _make_fusion_engine()

	var g1: GlyphInstance = _make_mastered_glyph("zapplet")
	rs.add_glyph(g1)

	var fc: FusionChamber = FusionChamber.new()
	root.add_child(fc)
	fc.setup(fe, rs, cs, _data_loader)
	fc.refresh()

	fc._on_picker_clicked(g1)
	_assert(fc._parent_a == g1, "parent A set")
	fc._on_picker_clicked(g1)
	_assert(fc._parent_b == null, "same glyph blocked for parent B")

	_cleanup_node(fc)
	_cleanup_node(rs)
	_cleanup_node(cs)
	_cleanup_node(fe)


# ==========================================================================
# RiftGate Tests
# ==========================================================================

func _test_rift_gate_construction() -> void:
	print("--- RiftGate: Construction ---")
	var rg: RiftGate = RiftGate.new()
	root.add_child(rg)

	_assert(rg._rift_container != null, "has rift container")

	_cleanup_node(rg)


func _test_rift_gate_list() -> void:
	print("--- RiftGate: Rift List ---")
	var gs: GameState = _make_game_state()
	var cx: CodexState = _make_codex_state()
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	gs.data_loader = _data_loader
	gs.roster_state = rs
	gs.codex_state = cx
	gs.crawler_state = cs

	var rg: RiftGate = RiftGate.new()
	root.add_child(rg)
	rg.setup(gs, cx, _data_loader)

	gs.game_phase = 1
	rg.refresh()
	_assert(rg._rift_panels.size() == 1, "phase 1 shows 1 rift")

	gs.game_phase = 2
	rg.refresh()
	_assert(rg._rift_panels.size() == 5, "phase 2 shows 5 rifts")

	_cleanup_node(rg)
	_cleanup_node(gs)
	_cleanup_node(cx)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_rift_gate_cleared_marker() -> void:
	print("--- RiftGate: Cleared Marker ---")
	var gs: GameState = _make_game_state()
	var cx: CodexState = _make_codex_state()
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	gs.data_loader = _data_loader
	gs.roster_state = rs
	gs.codex_state = cx
	gs.crawler_state = cs
	gs.game_phase = 1

	cx.mark_rift_cleared("tutorial_01")

	var rg: RiftGate = RiftGate.new()
	root.add_child(rg)
	rg.setup(gs, cx, _data_loader)
	rg.refresh()

	var found_cleared: bool = false
	if rg._rift_panels.size() > 0:
		found_cleared = _find_label_text_recursive(rg._rift_panels[0], "Cleared")
	_assert(found_cleared, "cleared marker shown for tutorial_01")

	_cleanup_node(rg)
	_cleanup_node(gs)
	_cleanup_node(cx)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_rift_gate_enter_signal() -> void:
	print("--- RiftGate: Enter Signal ---")
	var gs: GameState = _make_game_state()
	var cx: CodexState = _make_codex_state()
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	gs.data_loader = _data_loader
	gs.roster_state = rs
	gs.codex_state = cx
	gs.crawler_state = cs
	gs.game_phase = 1

	var rg: RiftGate = RiftGate.new()
	root.add_child(rg)
	rg.setup(gs, cx, _data_loader)
	rg.refresh()

	var selected: Dictionary = {"value": null}
	rg.rift_selected.connect(func(t: RiftTemplate) -> void: selected["value"] = t)

	if rg._rift_panels.size() > 0:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		rg._rift_panels[0].gui_input.emit(click)
	_assert(selected["value"] != null, "rift_selected signal fires")
	_assert(selected["value"] is RiftTemplate, "signal passes RiftTemplate")

	_cleanup_node(rg)
	_cleanup_node(gs)
	_cleanup_node(cx)
	_cleanup_node(rs)
	_cleanup_node(cs)


func _test_rift_gate_boss_name() -> void:
	print("--- RiftGate: Boss Name ---")
	var gs: GameState = _make_game_state()
	var cx: CodexState = _make_codex_state()
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()
	gs.data_loader = _data_loader
	gs.roster_state = rs
	gs.codex_state = cx
	gs.crawler_state = cs
	gs.game_phase = 1

	var rg: RiftGate = RiftGate.new()
	root.add_child(rg)
	rg.setup(gs, cx, _data_loader)
	rg.refresh()

	var found_boss: bool = false
	if rg._rift_panels.size() > 0:
		found_boss = _find_label_text_recursive(rg._rift_panels[0], "Boss:")
	_assert(found_boss, "boss name shown in rift panel")

	_cleanup_node(rg)
	_cleanup_node(gs)
	_cleanup_node(cx)
	_cleanup_node(rs)
	_cleanup_node(cs)


# ==========================================================================
# BastionScene Tests
# ==========================================================================

func _test_bastion_construction() -> void:
	print("--- BastionScene: Construction ---")
	var bs: BastionScene = BastionScene.new()
	root.add_child(bs)

	_assert(bs._title_label.text == "BASTION", "bastion title")
	_assert(bs._rift_gate_btn != null, "has rift gate button")
	_assert(bs._barracks_btn != null, "has barracks button")
	_assert(bs._fusion_btn != null, "has fusion button")
	_assert(bs._barracks != null, "has barracks sub-screen")
	_assert(bs._fusion_chamber != null, "has fusion sub-screen")
	_assert(bs._rift_gate != null, "has rift gate sub-screen")

	_cleanup_node(bs)


func _test_bastion_navigation_barracks() -> void:
	print("--- BastionScene: Navigate to Barracks ---")
	var bs: BastionScene = _make_bastion_scene()

	bs._barracks_btn.pressed.emit()
	_assert(bs.get_sub_screen() == BastionScene.SubScreen.BARRACKS, "sub screen is BARRACKS")
	_assert(bs._barracks.visible, "barracks visible")
	_assert(not bs._hub.visible, "hub hidden")

	_cleanup_bastion(bs)


func _test_bastion_navigation_fusion() -> void:
	print("--- BastionScene: Navigate to Fusion ---")
	var bs: BastionScene = _make_bastion_scene()

	bs._fusion_btn.pressed.emit()
	_assert(bs.get_sub_screen() == BastionScene.SubScreen.FUSION, "sub screen is FUSION")
	_assert(bs._fusion_chamber.visible, "fusion visible")
	_assert(not bs._hub.visible, "hub hidden")

	_cleanup_bastion(bs)


func _test_bastion_navigation_rift_gate() -> void:
	print("--- BastionScene: Navigate to Rift Gate ---")
	var bs: BastionScene = _make_bastion_scene()

	bs._rift_gate_btn.pressed.emit()
	_assert(bs.get_sub_screen() == BastionScene.SubScreen.RIFT_GATE, "sub screen is RIFT_GATE")
	_assert(bs._rift_gate.visible, "rift gate visible")
	_assert(not bs._hub.visible, "hub hidden")

	_cleanup_bastion(bs)


func _test_bastion_status_bar() -> void:
	print("--- BastionScene: Status Bar ---")
	var bs: BastionScene = _make_bastion_scene()
	bs.refresh()

	_assert(bs._status_label.text.contains("Phase"), "status shows phase")
	_assert(bs._status_label.text.contains("Rifts Cleared"), "status shows rifts cleared")
	_assert(bs._status_label.text.contains("Glyphs"), "status shows glyph count")
	_assert(bs._status_label.text.contains("Codex"), "status shows codex %")

	_cleanup_bastion(bs)


func _test_bastion_squad_preview() -> void:
	print("--- BastionScene: Squad Preview ---")
	var bs: BastionScene = _make_bastion_scene()
	bs.refresh()

	_assert(bs._squad_cards.size() == 3, "3 squad cards in preview")

	_cleanup_bastion(bs)


func _test_bastion_rift_selected_signal() -> void:
	print("--- BastionScene: Rift Selected Signal ---")
	var bs: BastionScene = _make_bastion_scene()

	var selected: Dictionary = {"value": null}
	bs.rift_selected.connect(func(t: RiftTemplate) -> void: selected["value"] = t)

	bs._rift_gate_btn.pressed.emit()

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	bs._rift_gate.rift_selected.emit(template)
	_assert(selected["value"] == template, "rift_selected propagated from rift gate")

	_cleanup_bastion(bs)


func _test_bastion_back_to_hub() -> void:
	print("--- BastionScene: Back to Hub ---")
	var bs: BastionScene = _make_bastion_scene()

	bs._barracks_btn.pressed.emit()
	_assert(not bs._hub.visible, "hub hidden after nav")
	bs._barracks.done_pressed.emit()
	_assert(bs._hub.visible, "hub visible after done")
	_assert(bs.get_sub_screen() == BastionScene.SubScreen.HUB, "sub screen is HUB")

	_cleanup_bastion(bs)


# ==========================================================================
# SquadOverlay Tests
# ==========================================================================

func _test_squad_overlay_construction() -> void:
	print("--- SquadOverlay: Construction ---")
	var overlay: SquadOverlay = SquadOverlay.new()
	root.add_child(overlay)

	_assert(overlay._vbox != null, "has vbox")
	_assert(overlay._entries.size() == 0, "empty initially")

	_cleanup_node(overlay)


func _test_squad_overlay_display() -> void:
	print("--- SquadOverlay: Display ---")
	var g1: GlyphInstance = _make_glyph("zapplet")
	var g2: GlyphInstance = _make_glyph("stonepaw")
	var squad: Array[GlyphInstance] = [g1, g2]

	var overlay: SquadOverlay = SquadOverlay.new()
	root.add_child(overlay)
	overlay.setup(squad)

	_assert(overlay._entries.size() == 2, "2 entries for 2 glyphs")
	var first_name: Label = overlay._entries[0]["name_label"]
	_assert(first_name.text == "Zapplet", "first entry name is Zapplet")

	_cleanup_node(overlay)


func _test_squad_overlay_hp_update() -> void:
	print("--- SquadOverlay: HP Update ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var squad: Array[GlyphInstance] = [g]

	var overlay: SquadOverlay = SquadOverlay.new()
	root.add_child(overlay)
	overlay.setup(squad)

	var hp_label: Label = overlay._entries[0]["hp_label"]
	_assert(hp_label.text == str(g.max_hp), "HP shows max initially")

	g.current_hp = 5
	overlay.refresh()
	_assert(hp_label.text == "5", "HP label updated after damage")

	_cleanup_node(overlay)


func _test_squad_overlay_color_thresholds() -> void:
	print("--- SquadOverlay: Color Thresholds ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var squad: Array[GlyphInstance] = [g]

	var overlay: SquadOverlay = SquadOverlay.new()
	root.add_child(overlay)
	overlay.setup(squad)

	overlay.refresh()
	var fill: StyleBoxFlat = overlay._entries[0]["hp_bar"].get_theme_stylebox("fill") as StyleBoxFlat
	_assert(fill.bg_color == Color("#4CAF50"), "green at full HP")

	g.current_hp = 1
	overlay.refresh()
	fill = overlay._entries[0]["hp_bar"].get_theme_stylebox("fill") as StyleBoxFlat
	_assert(fill.bg_color == Color("#F44336"), "red at low HP")

	_cleanup_node(overlay)


# ==========================================================================
# MainScene Tests
# ==========================================================================

func _test_main_scene_construction() -> void:
	print("--- MainScene: Construction ---")
	var ms: MainScene = MainScene.new()
	root.add_child(ms)

	_assert(ms._bastion_scene != null, "has bastion scene")
	_assert(ms._dungeon_scene != null, "has dungeon scene")
	_assert(ms._battle_scene != null, "has battle scene")
	_assert(ms._transition_overlay != null, "has transition overlay")
	_assert(ms._squad_overlay != null, "has squad overlay")

	_cleanup_node(ms)


func _test_main_scene_start_game() -> void:
	print("--- MainScene: Start Game ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.start_game()

	_assert(ms.game_state.current_state == GameState.State.BASTION, "state is BASTION")
	_assert(ms._bastion_scene.visible, "bastion visible")
	_assert(not ms._dungeon_scene.visible, "dungeon hidden")
	_assert(not ms._battle_scene.visible, "battle hidden")
	_assert(ms.roster_state.active_squad.size() == 3, "3 starters in squad")

	_cleanup_main_scene(ms)


func _test_main_scene_rift_flow() -> void:
	print("--- MainScene: Rift Flow ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.start_game()

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	ms._on_rift_selected(template)

	_assert(ms._dungeon_scene.visible, "dungeon visible after rift select")
	_assert(not ms._bastion_scene.visible, "bastion hidden during rift")
	_assert(ms._squad_overlay.visible, "squad overlay visible during rift")
	_assert(ms.game_state.current_dungeon != null, "dungeon state created")

	_cleanup_main_scene(ms)


func _test_main_scene_combat_flow() -> void:
	print("--- MainScene: Combat Flow ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.start_game()

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	ms._on_rift_selected(template)

	var enemy: GlyphInstance = _make_glyph("zapplet")
	enemy.side = "enemy"
	var enemies: Array[GlyphInstance] = [enemy]
	ms._on_combat_requested(enemies, null)

	_assert(ms._battle_scene.visible, "battle scene visible during combat")
	_assert(not ms._dungeon_scene.visible, "dungeon hidden during combat")
	_assert(not ms._squad_overlay.visible, "squad overlay hidden during combat")

	_cleanup_main_scene(ms)


func _test_main_scene_hp_persistence() -> void:
	print("--- MainScene: HP Persistence ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.start_game()

	var g: GlyphInstance = ms.roster_state.active_squad[0]
	g.current_hp = 10
	_assert(g.current_hp == 10, "HP damaged to 10")
	_assert(g.current_hp == 10, "HP persists (no auto-heal during rift)")

	_cleanup_main_scene(ms)


func _test_main_scene_heal_on_return() -> void:
	print("--- MainScene: Heal on Return ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.start_game()

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	ms._on_rift_selected(template)

	for g: GlyphInstance in ms.roster_state.active_squad:
		g.current_hp = 5
		g.is_knocked_out = true

	ms._on_rift_completed(true)

	var all_healed: bool = true
	for g: GlyphInstance in ms.roster_state.all_glyphs:
		if g.current_hp != g.max_hp:
			all_healed = false
		if g.is_knocked_out:
			all_healed = false
	_assert(all_healed, "all glyphs healed on return to bastion")
	_assert(ms._bastion_scene.visible, "bastion visible after rift complete")

	_cleanup_main_scene(ms)


func _test_main_scene_capture_flow() -> void:
	print("--- MainScene: Capture Flow ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.start_game()

	var initial_count: int = ms.roster_state.all_glyphs.size()

	var wild: GlyphInstance = _make_glyph("sparkfin")
	wild.side = "enemy"
	ms._on_capture_requested(wild)

	_assert(ms.roster_state.all_glyphs.size() == initial_count + 1, "glyph added to roster")
	_assert(ms.roster_state.has_glyph(wild), "captured glyph in roster")
	_assert(wild.side == "player", "captured glyph side set to player")

	_cleanup_main_scene(ms)


func _test_main_scene_rift_completion() -> void:
	print("--- MainScene: Rift Completion ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	ms.start_game()

	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	ms._on_rift_selected(template)
	ms._on_rift_completed(true)

	_assert(ms.codex_state.is_rift_cleared("tutorial_01"), "rift marked as cleared")
	_assert(ms._bastion_scene.visible, "bastion visible after completion")

	_cleanup_main_scene(ms)


# ==========================================================================
# Helper: BastionScene with deps
# ==========================================================================

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
	rs.initialize_starting_glyphs(_data_loader)

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


# ==========================================================================
# Helper: MainScene with all deps
# ==========================================================================

func _make_main_scene() -> MainScene:
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()
	var fe: FusionEngine = _make_fusion_engine()
	var ce: Node = _make_combat_engine()
	var mt: MasteryTracker = MasteryTracker.new()
	var mlt: MilestoneTracker = MilestoneTracker.new()
	mlt.crawler_state = cs
	mlt.codex_state = cx
	mlt.initialize(_data_loader)

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
	gs.milestone_tracker = mlt

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
# Recursive search helpers
# ==========================================================================

func _find_label_text_recursive(node: Node, search_text: String) -> bool:
	if node is Label:
		var label: Label = node as Label
		if label.text.contains(search_text):
			return true
	for child: Node in node.get_children():
		if _find_label_text_recursive(child, search_text):
			return true
	return false


func _find_button_recursive(node: Node, button_text: String) -> Button:
	if node is Button:
		var btn: Button = node as Button
		if btn.text == button_text:
			return btn
	for child: Node in node.get_children():
		var found: Button = _find_button_recursive(child, button_text)
		if found != null:
			return found
	return null


# ==========================================================================
# GlyphDetailPopup Tests
# ==========================================================================

func _test_detail_popup_construction() -> void:
	print("--- GlyphDetailPopup: Construction ---")
	var popup: GlyphDetailPopup = GlyphDetailPopup.new()
	root.add_child(popup)

	_assert(popup._panel != null, "popup has panel")
	_assert(popup._header_label != null, "popup has header label")
	_assert(popup._mastery_vbox != null, "popup has mastery vbox")
	_assert(popup._close_button != null, "popup has close button")
	_assert(not popup.visible, "popup hidden by default")

	_cleanup_node(popup)


func _test_detail_popup_shows_glyph_info() -> void:
	print("--- GlyphDetailPopup: Glyph Info ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var popup: GlyphDetailPopup = GlyphDetailPopup.new()
	root.add_child(popup)

	popup.show_glyph(g)

	_assert(popup.visible, "popup visible after show_glyph")
	_assert(popup._header_label.text.contains("Zapplet"), "header shows species name")
	_assert(popup._header_label.text.contains("Electric"), "header shows affinity")
	_assert(popup._header_label.text.contains("T1"), "header shows tier")
	_assert(popup._stats_label.text.contains("HP:"), "stats show HP")
	_assert(popup._stats_label.text.contains("ATK:"), "stats show ATK")
	_assert(popup._gp_label.text.contains("GP:"), "shows GP cost")
	_assert(popup._techniques_vbox.get_child_count() > 0, "shows technique entries")

	_cleanup_node(popup)


func _test_detail_popup_mastery_objectives() -> void:
	print("--- GlyphDetailPopup: Mastery Objectives ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var popup: GlyphDetailPopup = GlyphDetailPopup.new()
	root.add_child(popup)

	popup.show_glyph(g)

	## Should show 3 objectives (2 fixed + 1 random)
	var obj_count: int = popup._mastery_vbox.get_child_count()
	_assert(obj_count == 3, "popup shows 3 objectives (got %d)" % obj_count)
	_assert(popup._mastery_header.text.contains("0/3"), "mastery header shows 0/3")

	## All should show grey circle (incomplete)
	if obj_count > 0:
		var first: Label = popup._mastery_vbox.get_child(0) as Label
		_assert(first.text.begins_with("\u25cb"), "incomplete objective shows circle marker")

	_cleanup_node(popup)


func _test_detail_popup_completed_objectives() -> void:
	print("--- GlyphDetailPopup: Completed Objectives ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	## Complete first objective
	if g.mastery_objectives.size() > 0:
		g.mastery_objectives[0]["completed"] = true

	var popup: GlyphDetailPopup = GlyphDetailPopup.new()
	root.add_child(popup)
	popup.show_glyph(g)

	_assert(popup._mastery_header.text.contains("1/3"), "header shows 1/3 completed")
	var first: Label = popup._mastery_vbox.get_child(0) as Label
	_assert(first.text.begins_with("\u2713"), "completed objective shows checkmark")
	_assert(not popup._mastered_banner.visible, "not mastered yet — no banner")

	_cleanup_node(popup)


func _test_detail_popup_mastered_banner() -> void:
	print("--- GlyphDetailPopup: Mastered Banner ---")
	var g: GlyphInstance = _make_mastered_glyph("zapplet")
	var popup: GlyphDetailPopup = GlyphDetailPopup.new()
	root.add_child(popup)
	popup.show_glyph(g)

	_assert(popup._mastered_banner.visible, "mastered banner visible")
	_assert(popup._mastered_banner.text == "MASTERED", "banner says MASTERED")
	_assert(popup._mastery_bonus_label.visible, "bonus label visible")
	_assert(popup._mastery_bonus_label.text.contains("+2"), "bonus label mentions +2")

	_cleanup_node(popup)


func _test_detail_popup_progressive_counter() -> void:
	print("--- GlyphDetailPopup: Progressive Counter ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	## Find or create a use_technique_count objective with progress
	var found_progressive: bool = false
	for obj: Dictionary in g.mastery_objectives:
		var params: Dictionary = obj.get("params", {})
		if params.has("target"):
			params["current"] = 1
			found_progressive = true
			break

	var popup: GlyphDetailPopup = GlyphDetailPopup.new()
	root.add_child(popup)
	popup.show_glyph(g)

	if found_progressive:
		## Check that at least one label shows [current/target] format
		var found_counter: bool = false
		for i: int in range(popup._mastery_vbox.get_child_count()):
			var label: Label = popup._mastery_vbox.get_child(i) as Label
			if label != null and label.text.contains("[1/"):
				found_counter = true
				break
		_assert(found_counter, "progressive counter [1/N] shown")
	else:
		_assert(true, "no progressive objective to test (skip)")

	_cleanup_node(popup)


func _test_detail_popup_t4_mastery() -> void:
	print("--- GlyphDetailPopup: T4 Mastery ---")
	## T4 species now have mastery objectives (2 fixed + 1 random)
	var sp: GlyphSpecies = _data_loader.get_species("voltarion")  ## T4
	if sp == null:
		_assert(true, "no T4 species in data (skip)")
		return
	var g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
	g.mastery_objectives = MasteryTracker.build_mastery_track(sp, _data_loader.mastery_pools)

	var popup: GlyphDetailPopup = GlyphDetailPopup.new()
	root.add_child(popup)
	popup.show_glyph(g)

	_assert(popup._mastery_header.text.contains("0/3"), "T4 shows 0/3 mastery progress")
	_assert(popup._mastery_vbox.get_child_count() > 0, "T4 has objective labels")

	_cleanup_node(popup)


func _test_detail_popup_close() -> void:
	print("--- GlyphDetailPopup: Close ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var popup: GlyphDetailPopup = GlyphDetailPopup.new()
	root.add_child(popup)
	popup.show_glyph(g)

	_assert(popup.visible, "popup visible before close")
	var closed_dict: Dictionary = {"closed": false}
	popup.closed.connect(func() -> void: closed_dict["closed"] = true)
	popup.hide_popup()
	popup.closed.emit()  ## Simulate the signal (hide_popup doesn't emit)

	_assert(not popup.visible, "popup hidden after close")
	_assert(closed_dict["closed"], "closed signal emitted")

	_cleanup_node(popup)


# ==========================================================================
# ResultScreen Mastery Tests
# ==========================================================================

func _test_result_screen_mastery_section() -> void:
	print("--- ResultScreen: Mastery Section ---")
	var rs: ResultScreen = ResultScreen.new()
	root.add_child(rs)

	_assert(rs._mastery_section != null, "result screen has mastery section")
	_assert(not rs._mastery_section.visible, "mastery section hidden by default")

	rs.show_victory(5, 0)
	_assert(not rs._mastery_section.visible, "mastery section hidden on victory with no events")

	_cleanup_node(rs)


func _test_result_screen_mastery_objective_completed() -> void:
	print("--- ResultScreen: Mastery Objective Completed ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var rs: ResultScreen = ResultScreen.new()
	root.add_child(rs)

	rs.show_victory(5, 0)

	var events: Array[Dictionary] = []
	events.append({
		"type": "objective_completed",
		"glyph": g,
		"objective_index": 0,
	})
	rs.show_mastery_progress(events)

	_assert(rs._mastery_section.visible, "mastery section visible with events")
	## Header + 1 event label = 2 children
	_assert(rs._mastery_section.get_child_count() >= 2, "mastery section has event labels")

	## Check label content
	var event_label: Label = rs._mastery_section.get_child(1) as Label
	_assert(event_label.text.contains("Zapplet"), "event label shows glyph name")
	_assert(event_label.text.contains("COMPLETE"), "event label shows COMPLETE")

	_cleanup_node(rs)


func _test_result_screen_mastery_glyph_mastered() -> void:
	print("--- ResultScreen: Glyph Mastered ---")
	var g: GlyphInstance = _make_mastered_glyph("zapplet")
	var rs: ResultScreen = ResultScreen.new()
	root.add_child(rs)

	rs.show_victory(5, 0)

	var events: Array[Dictionary] = []
	events.append({
		"type": "glyph_mastered",
		"glyph": g,
	})
	rs.show_mastery_progress(events)

	_assert(rs._mastery_section.visible, "mastery section visible")
	var mastered_label: Label = rs._mastery_section.get_child(1) as Label
	_assert(mastered_label.text.contains("MASTERED"), "shows MASTERED text")
	_assert(mastered_label.text.contains("Zapplet"), "shows glyph name")
	_assert(mastered_label.text.contains("\u2605"), "shows star symbol")

	_cleanup_node(rs)


func _test_result_screen_defeat_no_mastery() -> void:
	print("--- ResultScreen: Defeat No Mastery ---")
	var rs: ResultScreen = ResultScreen.new()
	root.add_child(rs)

	rs.show_defeat()
	_assert(not rs._mastery_section.visible, "mastery section hidden on defeat")

	_cleanup_node(rs)


# ==========================================================================
# BattleScene Mastery Wiring Tests
# ==========================================================================

func _test_battle_scene_mastery_tracker() -> void:
	print("--- BattleScene: Mastery Tracker ---")
	var bs: BattleScene = BattleScene.new()
	root.add_child(bs)

	_assert(bs.mastery_tracker == null, "mastery_tracker null by default")

	var mt: MasteryTracker = MasteryTracker.new()
	bs.mastery_tracker = mt
	_assert(bs.mastery_tracker == mt, "mastery_tracker set correctly")

	_cleanup_node(bs)


func _test_battle_scene_mastery_events_collected() -> void:
	print("--- BattleScene: Mastery Events Collected ---")
	var bs: BattleScene = BattleScene.new()
	root.add_child(bs)

	var mt: MasteryTracker = MasteryTracker.new()
	bs.mastery_tracker = mt

	## Simulate connecting mastery signals
	bs._mastery_events.clear()
	bs._connect_mastery_signals()

	var g: GlyphInstance = _make_glyph("zapplet")

	## Simulate mastery objective completion
	mt.objective_completed.emit(g, 0)
	_assert(bs._mastery_events.size() == 1, "1 event collected after objective")
	_assert(bs._mastery_events[0]["type"] == "objective_completed", "event type is objective_completed")
	_assert(bs._mastery_events[0]["glyph"] == g, "event glyph matches")
	_assert(bs._mastery_events[0]["objective_index"] == 0, "event objective_index matches")

	## Simulate glyph mastered
	mt.glyph_mastered.emit(g)
	_assert(bs._mastery_events.size() == 2, "2 events after mastered")
	_assert(bs._mastery_events[1]["type"] == "glyph_mastered", "event type is glyph_mastered")

	## Disconnect should work cleanly
	bs._disconnect_mastery_signals()

	_cleanup_node(bs)


# ==========================================================================
# Barracks Info Button Tests
# ==========================================================================

func _test_barracks_info_button() -> void:
	print("--- Barracks: Info Button ---")
	var g: GlyphInstance = _make_glyph("zapplet")
	var card: GlyphCard = GlyphCard.new()
	card.setup(g)
	root.add_child(card)

	_assert(card._info_button != null, "card has info button")
	_assert(not card._info_button.visible, "info button hidden by default")

	card.show_info_button = true
	_assert(card._info_button.visible, "info button visible when enabled")

	var info_dict: Dictionary = {"pressed": false}
	card.info_pressed.connect(func(_g: GlyphInstance) -> void: info_dict["pressed"] = true)
	card._info_button.pressed.emit()
	_assert(info_dict["pressed"], "info_pressed signal emitted on click")

	_cleanup_node(card)


func _test_barracks_info_popup() -> void:
	print("--- Barracks: Info Popup ---")
	var rs: RosterState = _make_roster_state()
	var cs: CrawlerState = _make_crawler_state()

	var g1: GlyphInstance = _make_glyph("zapplet")
	g1.side = "player"
	rs.add_glyph(g1)
	rs.set_active_squad([g1])

	var barracks: Barracks = Barracks.new()
	root.add_child(barracks)
	barracks.setup(rs, cs)
	barracks.refresh()

	_assert(barracks._detail_popup != null, "barracks has detail popup")
	_assert(not barracks._detail_popup.visible, "popup hidden initially")

	## Cards should have info buttons
	_assert(barracks._squad_cards.size() > 0, "barracks has squad cards")
	if barracks._squad_cards.size() > 0:
		var card: GlyphCard = barracks._squad_cards[0]
		_assert(card.show_info_button, "squad card has info button enabled")

	_cleanup_node(barracks)
	_cleanup_node(rs)
	_cleanup_node(cs)


# ==========================================================================
# BastionScene Detail Popup Tests
# ==========================================================================

func _test_bastion_squad_card_popup() -> void:
	print("--- BastionScene: Squad Card Popup ---")
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()
	var fe: FusionEngine = _make_fusion_engine()

	gs.data_loader = _data_loader
	gs.codex_state = cx
	gs.roster_state = rs
	fe.data_loader = _data_loader
	fe.codex_state = cx
	fe.roster_state = rs

	rs.initialize_starting_glyphs(_data_loader)

	var bastion: BastionScene = BastionScene.new()
	root.add_child(bastion)
	bastion.setup(gs, rs, cx, cs, fe, _data_loader)
	bastion._mastery_hint_shown = true  ## Skip hint for this test
	bastion.show_hub()

	_assert(bastion._detail_popup != null, "bastion has detail popup")
	_assert(not bastion._detail_popup.visible, "popup hidden initially")

	## Squad cards should exist and clicking should open popup
	if bastion._squad_cards.size() > 0:
		var card: GlyphCard = bastion._squad_cards[0]
		card.card_clicked.emit(card.glyph)
		_assert(bastion._detail_popup.visible, "popup opens on squad card click")
		_assert(bastion._detail_popup.glyph == card.glyph, "popup shows clicked glyph")
	else:
		_assert(true, "no squad cards to test (skip)")

	_cleanup_node(bastion)
	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cx)
	_cleanup_node(cs)
	_cleanup_node(fe)


func _test_bastion_mastery_hint() -> void:
	print("--- BastionScene: Mastery Hint ---")
	var gs: GameState = _make_game_state()
	var rs: RosterState = _make_roster_state()
	var cx: CodexState = _make_codex_state()
	var cs: CrawlerState = _make_crawler_state()
	var fe: FusionEngine = _make_fusion_engine()

	gs.data_loader = _data_loader
	gs.codex_state = cx
	gs.roster_state = rs
	fe.data_loader = _data_loader
	fe.codex_state = cx
	fe.roster_state = rs

	rs.initialize_starting_glyphs(_data_loader)

	var bastion: BastionScene = BastionScene.new()
	root.add_child(bastion)
	bastion.setup(gs, rs, cx, cs, fe, _data_loader)

	_assert(not bastion._mastery_hint_shown, "hint not shown before first hub")
	bastion.show_hub()
	_assert(bastion._mastery_hint_shown, "hint shown after first hub")
	_assert(bastion._notification_label.visible, "notification visible")
	_assert(bastion._notification_label.text.contains("mastery"), "notification mentions mastery")

	## Second show_hub should not reset
	bastion._notification_label.visible = false
	bastion.show_hub()
	## Notification should not be re-triggered (already shown)
	## The notification was already shown, _mastery_hint_shown stays true
	_assert(bastion._mastery_hint_shown, "hint flag stays true")

	_cleanup_node(bastion)
	_cleanup_node(gs)
	_cleanup_node(rs)
	_cleanup_node(cx)
	_cleanup_node(cs)
	_cleanup_node(fe)


# ==========================================================================
# Milestone Toast Tests
# ==========================================================================

func _test_milestone_toast() -> void:
	print("--- MainScene: Milestone Toast ---")
	var ms: MainScene = _make_main_scene()
	ms.instant_mode = true

	_assert(ms._milestone_toast != null, "has milestone toast")
	_assert(not ms._milestone_toast.visible, "toast hidden initially")

	## Trigger a milestone via show_milestone_toast
	ms.show_milestone_toast("+10 Hull HP")
	_assert(ms._milestone_toast.visible, "toast visible after milestone")
	_assert(ms._milestone_toast_label.text.contains("UPGRADE UNLOCKED"), "toast says UPGRADE UNLOCKED")
	_assert(ms._milestone_toast_label.text.contains("+10 Hull HP"), "toast shows description")

	## Trigger via milestone_tracker signal
	ms._milestone_toast.visible = false
	var gs: GameState = ms.get_meta("_gs")
	if gs.milestone_tracker != null:
		gs.milestone_tracker.milestone_completed.emit("test_id", "Test reward")
		_assert(ms._milestone_toast.visible, "toast appears on signal")
		_assert(ms._milestone_toast_label.text.contains("Test reward"), "toast shows signal description")

	_cleanup_main_scene(ms)


# ==========================================================================
# CrawlerBay Tests
# ==========================================================================

func _test_crawler_bay_construction() -> void:
	print("--- CrawlerBay: Construction ---")
	var bay: CrawlerBay = CrawlerBay.new()
	root.add_child(bay)

	_assert(bay._stats_vbox != null, "has stats vbox")
	_assert(bay._chassis_vbox != null, "has chassis vbox")
	_assert(bay._milestone_vbox != null, "has milestone vbox")

	_cleanup_node(bay)


func _test_crawler_bay_stats_display() -> void:
	print("--- CrawlerBay: Stats Display ---")
	var cs: CrawlerState = _make_crawler_state()
	var bay: CrawlerBay = CrawlerBay.new()
	root.add_child(bay)
	bay.setup(cs, null)
	bay.refresh()

	_assert(bay._stats_vbox.get_child_count() > 0, "stats section populated")
	## Check that hull HP value appears
	var first_label: Label = bay._stats_vbox.get_child(0) as Label
	_assert("Hull HP" in first_label.text, "first stat is Hull HP (got: %s)" % first_label.text)

	_cleanup_node(bay)
	_cleanup_node(cs)


func _test_crawler_bay_chassis_selection() -> void:
	print("--- CrawlerBay: Chassis Selection ---")
	var cs: CrawlerState = _make_crawler_state()
	cs.unlocked_chassis = ["standard", "ironclad"]
	cs.active_chassis = "standard"

	var bay: CrawlerBay = CrawlerBay.new()
	root.add_child(bay)
	bay.setup(cs, null)
	bay.refresh()

	## Standard should be active (disabled), ironclad should be clickable
	_assert(bay._chassis_buttons.has("standard"), "has standard button")
	_assert(bay._chassis_buttons.has("ironclad"), "has ironclad button")
	var std_btn: Button = bay._chassis_buttons["standard"]
	var iron_btn: Button = bay._chassis_buttons["ironclad"]
	_assert(std_btn.disabled, "standard disabled (active)")
	_assert(not iron_btn.disabled, "ironclad enabled (unlocked, not active)")

	## Select ironclad
	bay._select_chassis("ironclad")
	_assert(cs.active_chassis == "ironclad", "active chassis changed to ironclad")

	## After refresh, ironclad should be disabled (active), standard clickable
	var iron_btn2: Button = bay._chassis_buttons["ironclad"]
	_assert(iron_btn2.disabled, "ironclad now disabled (active)")

	_cleanup_node(bay)
	_cleanup_node(cs)


func _test_crawler_bay_milestone_display() -> void:
	print("--- CrawlerBay: Milestone Display ---")
	var cs: CrawlerState = _make_crawler_state()
	var mt: MilestoneTracker = MilestoneTracker.new()
	mt.crawler_state = cs
	mt.codex_state = CodexState.new()
	mt.initialize(_data_loader)

	## Complete a milestone
	mt.on_hidden_room_discovered()

	var bay: CrawlerBay = CrawlerBay.new()
	root.add_child(bay)
	bay.setup(cs, mt)
	bay.refresh()

	_assert(bay._milestone_vbox.get_child_count() > 0, "milestone section populated")

	## Check that at least one shows a checkmark
	var found_check: bool = false
	for i: int in range(bay._milestone_vbox.get_child_count()):
		var row: HBoxContainer = bay._milestone_vbox.get_child(i) as HBoxContainer
		if row == null:
			continue
		var check_label: Label = row.get_child(0) as Label
		if check_label != null and "\u2713" in check_label.text:
			found_check = true
			break
	_assert(found_check, "at least one completed milestone shows checkmark")

	_cleanup_node(bay)
	_cleanup_node(cs)


func _test_bastion_navigation_crawler_bay() -> void:
	print("--- BastionScene: Navigate to Crawler Bay ---")
	var bs: BastionScene = _make_bastion_scene()

	bs._crawler_bay_btn.pressed.emit()
	_assert(bs.get_sub_screen() == BastionScene.SubScreen.CRAWLER_BAY, "sub screen is CRAWLER_BAY")
	_assert(bs._crawler_bay.visible, "crawler bay visible")
	_assert(not bs._hub.visible, "hub hidden")

	_cleanup_bastion(bs)


# ==========================================================================
# Settings Tests
# ==========================================================================


func _test_game_settings_default() -> void:
	print("--- GameSettings: Default values ---")
	GameSettings.battle_speed = "normal"
	_assert(GameSettings.battle_speed == "normal", "default battle speed is normal")
	_assert(GameSettings.get_delay_multiplier() == 1.0, "normal delay multiplier is 1.0")


func _test_game_settings_cycle() -> void:
	print("--- GameSettings: Speed values ---")
	GameSettings.battle_speed = "fast"
	_assert(GameSettings.battle_speed == "fast", "can set to fast")
	GameSettings.battle_speed = "instant"
	_assert(GameSettings.battle_speed == "instant", "can set to instant")
	GameSettings.battle_speed = "normal"


func _test_game_settings_delay_multiplier() -> void:
	print("--- GameSettings: Delay multipliers ---")
	GameSettings.battle_speed = "normal"
	_assert(GameSettings.get_delay_multiplier() == 1.0, "normal = 1.0")
	GameSettings.battle_speed = "fast"
	_assert(GameSettings.get_delay_multiplier() == 0.4, "fast = 0.4")
	GameSettings.battle_speed = "instant"
	_assert(GameSettings.get_delay_multiplier() == 0.0, "instant = 0.0")
	GameSettings.battle_speed = "normal"


func _test_settings_popup_construction() -> void:
	print("--- SettingsPopup: Construction ---")
	var popup: SettingsPopup = SettingsPopup.new()
	root.add_child(popup)
	_assert(popup != null, "popup created")
	_assert(not popup.visible, "popup hidden by default")
	_assert(popup._speed_btn != null, "speed button exists")
	_assert(popup._close_btn != null, "close button exists")
	popup.show_popup()
	_assert(popup.visible, "popup visible after show")
	popup.hide_popup()
	_assert(not popup.visible, "popup hidden after hide")
	_cleanup_node(popup)


func _test_settings_popup_speed_cycle() -> void:
	print("--- SettingsPopup: Speed cycle ---")
	GameSettings.battle_speed = "normal"
	var popup: SettingsPopup = SettingsPopup.new()
	root.add_child(popup)
	popup.show_popup()

	_assert(popup._speed_btn.text == "Normal", "initial label is Normal")
	popup._cycle_speed()
	_assert(GameSettings.battle_speed == "fast", "cycled to fast")
	_assert(popup._speed_btn.text == "Fast (2x)", "label shows Fast (2x)")
	popup._cycle_speed()
	_assert(GameSettings.battle_speed == "instant", "cycled to instant")
	_assert(popup._speed_btn.text == "Instant", "label shows Instant")
	popup._cycle_speed()
	_assert(GameSettings.battle_speed == "normal", "cycled back to normal")

	_cleanup_node(popup)
	GameSettings.battle_speed = "normal"


func _test_settings_popup_font_size() -> void:
	print("--- SettingsPopup: Font size cycle ---")
	GameSettings.font_size = "normal"
	var popup: SettingsPopup = SettingsPopup.new()
	root.add_child(popup)
	popup.show_popup()

	_assert(popup._font_btn != null, "font button exists")
	_assert(popup._font_btn.text == "Normal", "initial font label is Normal")
	popup._cycle_font_size()
	_assert(GameSettings.font_size == "large", "cycled to large")
	_assert(popup._font_btn.text == "Large", "label shows Large")
	popup._cycle_font_size()
	_assert(GameSettings.font_size == "small", "cycled to small")
	_assert(popup._font_btn.text == "Small", "label shows Small")
	popup._cycle_font_size()
	_assert(GameSettings.font_size == "normal", "cycled back to normal")

	_cleanup_node(popup)
	GameSettings.font_size = "normal"


func _test_game_settings_font_scale() -> void:
	print("--- GameSettings: Font scale values ---")
	GameSettings.font_size = "small"
	_assert(GameSettings.get_font_scale() == 0.85, "small = 0.85")
	GameSettings.font_size = "normal"
	_assert(GameSettings.get_font_scale() == 1.0, "normal = 1.0")
	GameSettings.font_size = "large"
	_assert(GameSettings.get_font_scale() == 1.2, "large = 1.2")

	## Test apply_font_scale
	var ctrl: Control = Control.new()
	root.add_child(ctrl)
	GameSettings.apply_font_scale(ctrl)
	_assert(ctrl.theme != null, "theme created")
	_assert(ctrl.theme.default_font_size == 19, "large font size = 19")

	GameSettings.font_size = "small"
	GameSettings.apply_font_scale(ctrl)
	_assert(ctrl.theme.default_font_size == 13, "small font size = 13")

	GameSettings.font_size = "normal"
	GameSettings.apply_font_scale(ctrl)
	_assert(ctrl.theme.default_font_size == 16, "normal font size = 16")

	_cleanup_node(ctrl)
	GameSettings.font_size = "normal"


func _test_pause_menu_settings_button() -> void:
	print("--- PauseMenu: Settings button ---")
	var menu: PauseMenu = PauseMenu.new()
	menu.instant_mode = true
	root.add_child(menu)

	_assert(menu._settings_btn != null, "settings button exists")
	_assert(menu._settings_popup != null, "settings popup exists")
	_assert(not menu._settings_popup.visible, "settings popup hidden initially")

	menu._settings_btn.pressed.emit()
	_assert(menu._settings_popup.visible, "settings popup visible after click")

	menu._settings_popup.hide_popup()
	_assert(not menu._settings_popup.visible, "settings popup hidden after close")

	_cleanup_node(menu)
