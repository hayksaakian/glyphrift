extends SceneTree

var _data_loader: Node = null
var _engine: Node = null
var _scene: BattleScene = null
var pass_count: int = 0
var fail_count: int = 0


func _init() -> void:
	## Manually instantiate DataLoader
	var dl_script: GDScript = load("res://core/data_loader.gd") as GDScript
	_data_loader = dl_script.new() as Node
	_data_loader.name = "DataLoader"
	root.add_child(_data_loader)

	## Manually instantiate CombatEngine
	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	_engine = ce_script.new() as Node
	_engine.name = "CombatEngine"
	_engine.data_loader = _data_loader
	root.add_child(_engine)

	await process_frame
	_run_tests()
	quit()


func _run_tests() -> void:
	print("")
	print("========================================")
	print("  GLYPHRIFT — Battle UI Tests")
	print("========================================")
	print("")

	_test_component_construction()
	_test_animation_queue()
	_test_glyph_panel()
	_test_glyph_portrait()
	_test_portrait_highlight()
	_test_technique_button()
	_test_technique_button_hint()
	_test_status_icons_letters()
	_test_battle_log()
	_test_formation_setup()
	_test_target_selector()
	_test_result_screen()
	_test_phase_overlay()
	_test_damage_number()
	_test_battle_scene_construction()
	_test_battle_scene_formation_flow()
	_test_auto_battle_smoke()
	_test_multi_battle()
	_test_boss_battle()
	_test_flee_button_exists()
	_test_forfeit_triggers_defeat()
	_test_flee_hidden_for_boss()

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
# Helper: create a fresh BattleScene wired to the engine
# ==========================================================================

func _create_battle_scene() -> BattleScene:
	## Clean up old scene if any
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
		_scene = null

	_scene = BattleScene.new()
	_scene.combat_engine = _engine
	root.add_child(_scene)
	## Use instant mode for headless testing — skip timer delays
	_scene._animation_queue.instant_mode = true
	return _scene


func _make_squad(species_ids: Array[String]) -> Array[GlyphInstance]:
	var squad: Array[GlyphInstance] = []
	for sid: String in species_ids:
		var sp: GlyphSpecies = _data_loader.get_species(sid)
		squad.append(GlyphInstance.create_from_species(sp, _data_loader))
	return squad


# ==========================================================================
# Component Construction Tests
# ==========================================================================

func _test_component_construction() -> void:
	print("--- Component Construction ---")

	## AnimationQueue
	var aq: AnimationQueue = AnimationQueue.new()
	root.add_child(aq)
	_assert(aq != null, "AnimationQueue instantiates")
	_assert(not aq.is_playing(), "AnimationQueue starts not playing")
	_assert(aq.get_queue_size() == 0, "AnimationQueue starts empty")
	aq.queue_free()

	## GlyphPanel
	var panel: GlyphPanel = GlyphPanel.new()
	root.add_child(panel)
	_assert(panel != null, "GlyphPanel instantiates")
	_assert(panel.custom_minimum_size == Vector2(180, 80), "GlyphPanel has correct min size")
	panel.queue_free()

	## GlyphPortrait
	var portrait: GlyphPortrait = GlyphPortrait.new()
	root.add_child(portrait)
	_assert(portrait != null, "GlyphPortrait instantiates")
	_assert(portrait._square.custom_minimum_size == Vector2(64, 64), "GlyphPortrait square has correct min size")
	portrait.queue_free()

	## TechniqueButton
	var btn: TechniqueButton = TechniqueButton.new()
	root.add_child(btn)
	_assert(btn != null, "TechniqueButton instantiates")
	btn.queue_free()

	## BattleLog
	var log: BattleLog = BattleLog.new()
	root.add_child(log)
	_assert(log != null, "BattleLog instantiates")
	log.queue_free()

	## FormationSetup
	var formation: FormationSetup = FormationSetup.new()
	root.add_child(formation)
	_assert(formation != null, "FormationSetup instantiates")
	formation.queue_free()

	## TargetSelector
	var ts: TargetSelector = TargetSelector.new()
	root.add_child(ts)
	_assert(ts != null, "TargetSelector instantiates")
	ts.queue_free()

	## DamageNumber
	var dn: DamageNumber = DamageNumber.new()
	root.add_child(dn)
	_assert(dn != null, "DamageNumber instantiates")
	dn.queue_free()

	## PhaseOverlay
	var po: PhaseOverlay = PhaseOverlay.new()
	root.add_child(po)
	_assert(po != null, "PhaseOverlay instantiates")
	po.queue_free()

	## ResultScreen
	var rs: ResultScreen = ResultScreen.new()
	root.add_child(rs)
	_assert(rs != null, "ResultScreen instantiates")
	rs.queue_free()

	## BattleScene
	var bs: BattleScene = BattleScene.new()
	root.add_child(bs)
	_assert(bs != null, "BattleScene instantiates")
	bs.queue_free()

	print("")


# ==========================================================================
# AnimationQueue Tests
# ==========================================================================

func _test_animation_queue() -> void:
	print("--- AnimationQueue ---")

	var aq: AnimationQueue = AnimationQueue.new()
	root.add_child(aq)

	## Test enqueue with long delay — should still be playing
	aq.enqueue("test_event", {"value": 42}, 999.0)
	_assert(aq.is_playing(), "AnimationQueue plays after enqueue")

	## Test clear
	aq.enqueue("another", {}, 999.0)
	aq.clear()
	_assert(not aq.is_playing(), "AnimationQueue stops after clear")
	_assert(aq.get_queue_size() == 0, "AnimationQueue empty after clear")

	## Test callback enqueue
	var callback_ran: Dictionary = {"ran": false}
	aq.enqueue_callback(func() -> void: callback_ran["ran"] = true, 0.0)
	## Callback should fire immediately (0 delay)
	_assert(callback_ran["ran"], "AnimationQueue callback fires with 0 delay")

	aq.queue_free()
	print("")


# ==========================================================================
# GlyphPanel Tests
# ==========================================================================

func _test_glyph_panel() -> void:
	print("--- GlyphPanel ---")

	var sp: GlyphSpecies = _data_loader.get_species("zapplet")
	var g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)

	var panel: GlyphPanel = GlyphPanel.new()
	panel.glyph = g
	root.add_child(panel)

	## Panel should have built its UI in _ready
	_assert(panel._name_label != null, "GlyphPanel builds name label")
	_assert(panel._hp_bar != null, "GlyphPanel builds HP bar")
	_assert(panel._status_row != null, "GlyphPanel builds status row")

	## Refresh should populate
	panel.refresh()
	_assert(panel._name_label.text == "Zapplet", "GlyphPanel shows correct name")
	_assert(panel._hp_bar.max_value == g.max_hp, "GlyphPanel HP bar max matches glyph")
	_assert(int(panel._hp_bar.value) == g.current_hp, "GlyphPanel HP bar value matches glyph")

	## Affinity color
	_assert(panel._affinity_rect.color == Affinity.COLORS["electric"],
		"GlyphPanel shows electric affinity color for Zapplet")

	## Test KO modulate
	g.is_knocked_out = true
	panel.refresh()
	_assert(panel.modulate.a < 1.0, "GlyphPanel dims when KO'd")

	## Test guard border
	g.is_knocked_out = false
	g.is_guarding = true
	panel.refresh()
	_assert(panel._guard_border.visible, "GlyphPanel shows guard border when guarding")

	## Test status display
	g.is_guarding = false
	g.active_statuses["burn"] = 3
	g.active_statuses["slow"] = 2
	panel.refresh()
	_assert(panel._status_row.get_child_count() == 2,
		"GlyphPanel shows 2 status icons (got %d)" % panel._status_row.get_child_count())

	panel.queue_free()
	print("")


# ==========================================================================
# GlyphPortrait Tests
# ==========================================================================

func _test_glyph_portrait() -> void:
	print("--- GlyphPortrait ---")

	var sp: GlyphSpecies = _data_loader.get_species("stonepaw")
	var g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
	g.side = "player"

	var portrait: GlyphPortrait = GlyphPortrait.new()
	portrait.glyph = g
	root.add_child(portrait)

	portrait.refresh()
	_assert(portrait._initial_label.text == "S", "GlyphPortrait shows species initial 'S' for Stonepaw")
	_assert(portrait._color_rect.color == Affinity.COLORS["ground"],
		"GlyphPortrait shows ground color for Stonepaw")

	## Test side border color
	var border_style: StyleBoxFlat = portrait._border.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(border_style.border_color == Color("#4488FF"), "GlyphPortrait border is blue for player side")

	## Test enemy side
	g.side = "enemy"
	portrait.refresh()
	border_style = portrait._border.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(border_style.border_color == Color("#FF4444"), "GlyphPortrait border is red for enemy side")

	portrait.queue_free()
	print("")


# ==========================================================================
# GlyphPortrait Highlight Tests
# ==========================================================================

func _test_portrait_highlight() -> void:
	print("--- GlyphPortrait Highlight ---")

	var sp: GlyphSpecies = _data_loader.get_species("zapplet")
	var g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)
	g.side = "player"

	var portrait: GlyphPortrait = GlyphPortrait.new()
	portrait.glyph = g
	root.add_child(portrait)

	## Default: not highlighted, 64x64
	_assert(portrait._square.custom_minimum_size == Vector2(64, 64),
		"GlyphPortrait default square is 64x64")
	_assert(not portrait._highlight_border.visible,
		"GlyphPortrait highlight border hidden by default")

	## Highlight on
	portrait.set_highlighted(true)
	_assert(portrait._square.custom_minimum_size == Vector2(80, 80),
		"GlyphPortrait highlighted square is 80x80")
	_assert(portrait._highlight_border.visible,
		"GlyphPortrait highlight border visible when highlighted")

	## Highlight off
	portrait.set_highlighted(false)
	_assert(portrait._square.custom_minimum_size == Vector2(64, 64),
		"GlyphPortrait square returns to 64x64 when unhighlighted")
	_assert(not portrait._highlight_border.visible,
		"GlyphPortrait highlight border hidden when unhighlighted")

	portrait.queue_free()
	print("")


# ==========================================================================
# TechniqueButton Tests
# ==========================================================================

func _test_technique_button() -> void:
	print("--- TechniqueButton ---")

	var tech: TechniqueDef = _data_loader.get_technique("arc_fang")
	var btn: TechniqueButton = TechniqueButton.new()
	root.add_child(btn)
	btn.setup(tech, true)

	_assert(btn.technique == tech, "TechniqueButton stores technique reference")
	_assert(btn.is_usable, "TechniqueButton is usable when set")
	_assert("Arc Fang" in btn.text, "TechniqueButton shows technique name")
	_assert("18" in btn.text, "TechniqueButton shows power value")
	_assert(not btn.disabled, "TechniqueButton not disabled when usable")

	## Test cooldown display
	btn.setup(tech, false)
	_assert(btn.disabled, "TechniqueButton disabled when not usable")

	## Test signal emission
	var signal_data: Dictionary = {"received": false}
	btn.technique_selected.connect(func(t: TechniqueDef) -> void: signal_data["received"] = true)
	btn.setup(tech, true)
	btn._on_pressed()
	_assert(signal_data["received"], "TechniqueButton emits technique_selected on press")

	btn.queue_free()
	print("")


# ==========================================================================
# TechniqueButton Hint Tests
# ==========================================================================

func _test_technique_button_hint() -> void:
	print("--- TechniqueButton Hint ---")

	var tech: TechniqueDef = _data_loader.get_technique("arc_fang")
	var btn: TechniqueButton = TechniqueButton.new()
	root.add_child(btn)

	## With advantage
	btn.setup_with_hint(tech, true, true)
	_assert(btn._se_badge.visible, "TechniqueButton shows S.EFF badge when has_advantage")
	_assert("Arc Fang" in btn.text, "TechniqueButton still shows technique name with hint")

	## Without advantage
	btn.setup_with_hint(tech, true, false)
	_assert(not btn._se_badge.visible, "TechniqueButton hides badge when no advantage")

	## setup() resets advantage
	btn.setup_with_hint(tech, true, true)
	btn.setup(tech, true)
	_assert(not btn._se_badge.visible, "TechniqueButton setup() clears advantage badge")

	btn.queue_free()
	print("")


# ==========================================================================
# Status Icon Letter Tests
# ==========================================================================

func _test_status_icons_letters() -> void:
	print("--- Status Icons with Letters ---")

	var sp: GlyphSpecies = _data_loader.get_species("zapplet")
	var g: GlyphInstance = GlyphInstance.create_from_species(sp, _data_loader)

	var panel: GlyphPanel = GlyphPanel.new()
	panel.glyph = g
	root.add_child(panel)

	## Add statuses and refresh
	g.active_statuses["burn"] = 3
	g.active_statuses["stun"] = 1
	panel.refresh()

	_assert(panel._status_row.get_child_count() == 2,
		"Status row has 2 icons (got %d)" % panel._status_row.get_child_count())

	## Check that icons are PanelContainers with letter labels
	var found_burn: bool = false
	var found_stun: bool = false
	for child: Node in panel._status_row.get_children():
		var icon: PanelContainer = child as PanelContainer
		_assert(icon != null, "Status icon is PanelContainer")
		_assert(icon.custom_minimum_size == Vector2(22, 22), "Status icon is 22x22")
		if icon.has_meta("status_id"):
			var sid: String = icon.get_meta("status_id")
			if sid == "burn":
				found_burn = true
				var lbl: Label = icon.get_child(0) as Label
				_assert(lbl != null and lbl.text == "B", "Burn icon has letter B")
			elif sid == "stun":
				found_stun = true
				var lbl: Label = icon.get_child(0) as Label
				_assert(lbl != null and lbl.text == "S", "Stun icon has letter S")

	_assert(found_burn, "Found burn status icon")
	_assert(found_stun, "Found stun status icon")

	## flash_status should not crash
	panel.flash_status("burn")
	_assert(true, "flash_status(burn) runs without crash")

	panel.queue_free()
	print("")


# ==========================================================================
# BattleLog Tests
# ==========================================================================

func _test_battle_log() -> void:
	print("--- BattleLog ---")

	var log: BattleLog = BattleLog.new()
	root.add_child(log)

	_assert(log.get_entry_count() == 0, "BattleLog starts empty")
	log.add_entry("Test message", Color.WHITE)
	_assert(log.get_entry_count() == 1, "BattleLog has 1 entry after add")
	log.add_entry("Second message", Color.RED)
	_assert(log.get_entry_count() == 2, "BattleLog has 2 entries after second add")

	log.clear_log()
	_assert(log.get_entry_count() == 0, "BattleLog cleared")

	log.queue_free()
	print("")


# ==========================================================================
# FormationSetup Tests
# ==========================================================================

func _test_formation_setup() -> void:
	print("--- FormationSetup ---")

	var formation: FormationSetup = FormationSetup.new()
	root.add_child(formation)

	var squad: Array[GlyphInstance] = _make_squad(["zapplet", "stonepaw", "driftwisp"] as Array[String])
	## Set up formation: first two front, third back (simulates Barracks assignment)
	squad[0].row_position = "front"
	squad[1].row_position = "front"
	squad[2].row_position = "back"

	_assert(not formation.visible, "FormationSetup starts hidden")

	formation.show_formation(squad)
	_assert(formation.visible, "FormationSetup visible after show")

	## Preserves existing row_position from GlyphInstance
	var positions: Dictionary = formation.get_positions()
	_assert(positions[squad[0].instance_id] == "front", "First glyph preserves front row")
	_assert(positions[squad[1].instance_id] == "front", "Second glyph preserves front row")
	_assert(positions[squad[2].instance_id] == "back", "Third glyph preserves back row")

	## Test signal emission
	var confirmed_data: Dictionary = {"positions": {}}
	formation.formation_confirmed.connect(func(pos: Dictionary) -> void:
		confirmed_data["positions"] = pos
	)
	formation._on_confirm()
	_assert(confirmed_data["positions"].size() == 3,
		"FormationSetup emits positions for all 3 glyphs (got %d)" % confirmed_data["positions"].size())

	formation.hide_formation()
	_assert(not formation.visible, "FormationSetup hidden after hide")

	formation.queue_free()
	print("")


# ==========================================================================
# TargetSelector Tests
# ==========================================================================

func _test_target_selector() -> void:
	print("--- TargetSelector ---")

	var ts: TargetSelector = TargetSelector.new()
	root.add_child(ts)

	_assert(not ts.visible, "TargetSelector starts hidden")

	## Create dummy panels
	var g1: GlyphInstance = GlyphInstance.create_from_species(_data_loader.get_species("zapplet"), _data_loader)
	var panel1: GlyphPanel = GlyphPanel.new()
	panel1.glyph = g1
	root.add_child(panel1)

	var panels: Dictionary = {g1.instance_id: panel1}
	var targets: Array[GlyphInstance] = [g1]

	ts.show_targets(targets, panels)
	_assert(ts.visible, "TargetSelector visible after show_targets")

	## Test signal on click
	var selected_data: Dictionary = {"glyph": null}
	ts.target_selected.connect(func(g: GlyphInstance) -> void: selected_data["glyph"] = g)
	ts._on_target_clicked(g1)
	_assert(selected_data["glyph"] == g1, "TargetSelector emits target_selected on click")
	_assert(not ts.visible, "TargetSelector hides after selection")

	## Test cancel
	ts.show_targets(targets, panels)
	var cancelled: Dictionary = {"fired": false}
	ts.selection_cancelled.connect(func() -> void: cancelled["fired"] = true)
	ts._on_cancel()
	_assert(cancelled["fired"], "TargetSelector emits selection_cancelled on cancel")

	ts.queue_free()
	panel1.queue_free()
	print("")


# ==========================================================================
# ResultScreen Tests
# ==========================================================================

func _test_result_screen() -> void:
	print("--- ResultScreen ---")

	var rs: ResultScreen = ResultScreen.new()
	root.add_child(rs)

	_assert(not rs.visible, "ResultScreen starts hidden")

	rs.show_victory(15, 1)
	_assert(rs.visible, "ResultScreen visible after show_victory")
	_assert(rs._title_label.text == "VICTORY!", "ResultScreen shows VICTORY title")

	rs.hide_result()
	_assert(not rs.visible, "ResultScreen hidden after hide_result")

	rs.show_defeat()
	_assert(rs.visible, "ResultScreen visible after show_defeat")
	_assert(rs._title_label.text == "DEFEAT", "ResultScreen shows DEFEAT title")

	## Test continue signal
	var continued: Dictionary = {"fired": false}
	rs.continue_pressed.connect(func() -> void: continued["fired"] = true)
	rs._continue_button.pressed.emit()
	_assert(continued["fired"], "ResultScreen emits continue_pressed")

	rs.queue_free()
	print("")


# ==========================================================================
# PhaseOverlay Tests
# ==========================================================================

func _test_phase_overlay() -> void:
	print("--- PhaseOverlay ---")

	var po: PhaseOverlay = PhaseOverlay.new()
	root.add_child(po)

	_assert(not po.visible, "PhaseOverlay starts hidden")
	_assert(po._label != null, "PhaseOverlay has label")
	_assert(po._label.text == "PHASE 2", "PhaseOverlay label says PHASE 2")

	po.queue_free()
	print("")


# ==========================================================================
# DamageNumber Tests
# ==========================================================================

func _test_damage_number() -> void:
	print("--- DamageNumber ---")

	var dn: DamageNumber = DamageNumber.new()
	root.add_child(dn)

	dn.show_damage(42, "damage")
	_assert(dn.text == "42", "DamageNumber shows damage value")

	var dn2: DamageNumber = DamageNumber.new()
	root.add_child(dn2)
	dn2.show_damage(15, "heal")
	_assert(dn2.text == "+15", "DamageNumber shows heal with + prefix")

	var dn3: DamageNumber = DamageNumber.new()
	root.add_child(dn3)
	dn3.show_damage(0, "shield")
	_assert(dn3.text == "Shield!", "DamageNumber shows Shield! text")

	dn.queue_free()
	dn2.queue_free()
	dn3.queue_free()
	print("")


# ==========================================================================
# BattleScene Construction Tests
# ==========================================================================

func _test_battle_scene_construction() -> void:
	print("--- BattleScene Construction ---")

	var scene: BattleScene = _create_battle_scene()

	_assert(scene._background != null, "BattleScene has background")
	_assert(scene._formation_setup != null, "BattleScene has formation setup")
	_assert(scene._battlefield != null, "BattleScene has battlefield")
	_assert(scene._enemy_front_row != null, "BattleScene has enemy front row")
	_assert(scene._enemy_back_row != null, "BattleScene has enemy back row")
	_assert(scene._player_front_row != null, "BattleScene has player front row")
	_assert(scene._player_back_row != null, "BattleScene has player back row")
	_assert(scene._turn_order_bar != null, "BattleScene has turn order bar")
	_assert(scene._action_menu != null, "BattleScene has action menu")
	_assert(scene._technique_list != null, "BattleScene has technique list")
	_assert(scene._target_selector != null, "BattleScene has target selector")
	_assert(scene._combat_log != null, "BattleScene has combat log")
	_assert(scene._phase_overlay != null, "BattleScene has phase overlay")
	_assert(scene._result_screen != null, "BattleScene has result screen")
	_assert(scene._animation_queue != null, "BattleScene has animation queue")
	_assert(scene._interrupt_label != null, "BattleScene has interrupt label")

	## Verify initial visibility states
	_assert(not scene._action_menu.visible, "Action menu starts hidden")
	_assert(not scene._technique_list.visible, "Technique list starts hidden")
	_assert(not scene._result_screen.visible, "Result screen starts hidden")
	_assert(not scene._phase_overlay.visible, "Phase overlay starts hidden")

	_assert(scene.combat_engine == _engine, "BattleScene has engine injected")

	scene.queue_free()
	_scene = null
	print("")


# ==========================================================================
# Formation Flow Tests
# ==========================================================================

func _test_battle_scene_formation_flow() -> void:
	print("--- BattleScene Formation Flow ---")

	var scene: BattleScene = _create_battle_scene()
	var p_squad: Array[GlyphInstance] = _make_squad(["zapplet", "stonepaw", "driftwisp"] as Array[String])
	var e_squad: Array[GlyphInstance] = _make_squad(["sparkfin", "mossling", "glitchkit"] as Array[String])

	## Before battle, no panels
	_assert(scene._panels.size() == 0, "No panels before battle starts")

	## Start battle — engine emits battle_started → formation shown
	_engine.auto_battle = true
	scene.start_battle(p_squad, e_squad)

	_assert(scene._state == BattleScene.UIState.FORMATION, "State is FORMATION after start_battle")
	_assert(scene._formation_setup.visible, "Formation setup visible")

	## Confirm formation — populates panels, engine runs auto-battle
	scene._on_formation_confirmed(scene._formation_setup.get_positions())

	## Engine should have completed (auto_battle is synchronous)
	var ended: bool = _engine.phase == _engine.BattlePhase.VICTORY or _engine.phase == _engine.BattlePhase.DEFEAT
	_assert(ended, "Engine battle completed after formation confirm")

	## Drain animation queue to process all queued events instantly
	scene._animation_queue.drain()

	## Panels should be created for all 6 glyphs
	_assert(scene._panels.size() == 6,
		"6 panels created (got %d)" % scene._panels.size())

	## Combat log should have entries (from direct + drained queue callbacks)
	_assert(scene._combat_log.get_entry_count() > 0,
		"Combat log has entries (got %d)" % scene._combat_log.get_entry_count())

	scene.queue_free()
	_scene = null
	_engine.auto_battle = false
	print("")


# ==========================================================================
# Auto-Battle Smoke Tests
# ==========================================================================

func _test_auto_battle_smoke() -> void:
	print("--- Auto-Battle Smoke Test ---")

	var scene: BattleScene = _create_battle_scene()
	_engine.auto_battle = true

	var p_squad: Array[GlyphInstance] = _make_squad(["zapplet", "stonepaw", "driftwisp"] as Array[String])
	var e_squad: Array[GlyphInstance] = _make_squad(["sparkfin", "mossling", "glitchkit"] as Array[String])

	scene.start_battle(p_squad, e_squad)
	scene._on_formation_confirmed(scene._formation_setup.get_positions())

	var ended: bool = _engine.phase == _engine.BattlePhase.VICTORY or _engine.phase == _engine.BattlePhase.DEFEAT
	_assert(ended, "Auto-battle completed without crash")

	## Drain all queued animation events
	scene._animation_queue.drain()

	var is_victory: bool = _engine.phase == _engine.BattlePhase.VICTORY
	print("       Result: %s in %d turns" % ["VICTORY" if is_victory else "DEFEAT", _engine.turn_count])

	_assert(_engine.turn_count > 0, "Turns occurred (got %d)" % _engine.turn_count)
	_assert(scene._combat_log.get_entry_count() > 5,
		"Multiple log entries (got %d)" % scene._combat_log.get_entry_count())

	## Queue should be empty after drain
	_assert(scene._animation_queue.get_queue_size() == 0,
		"Animation queue empty after drain")

	scene.queue_free()
	_scene = null
	_engine.auto_battle = false
	print("")


# ==========================================================================
# Multi-Battle Tests
# ==========================================================================

func _test_multi_battle() -> void:
	print("--- Multi-Battle ---")

	var scene: BattleScene = _create_battle_scene()
	_engine.auto_battle = true

	for i: int in range(3):
		var p_squad: Array[GlyphInstance] = _make_squad(["zapplet", "stonepaw", "driftwisp"] as Array[String])
		var e_squad: Array[GlyphInstance] = _make_squad(["sparkfin", "mossling", "glitchkit"] as Array[String])

		scene.start_battle(p_squad, e_squad)
		scene._on_formation_confirmed(scene._formation_setup.get_positions())
		scene._animation_queue.drain()

		var ended: bool = _engine.phase == _engine.BattlePhase.VICTORY or _engine.phase == _engine.BattlePhase.DEFEAT
		_assert(ended, "Battle %d completed" % (i + 1))

		var result: String = "VICTORY" if _engine.phase == _engine.BattlePhase.VICTORY else "DEFEAT"
		print("       Battle %d: %s in %d turns" % [i + 1, result, _engine.turn_count])

	## Verify BattleScene reset works — panels should be from last battle only
	_assert(scene._panels.size() == 6,
		"Panels are 6 after 3 battles (reset works), got %d" % scene._panels.size())

	scene.queue_free()
	_scene = null
	_engine.auto_battle = false
	print("")


# ==========================================================================
# Boss Battle Tests
# ==========================================================================

func _test_boss_battle() -> void:
	print("--- Boss Battle ---")

	var scene: BattleScene = _create_battle_scene()
	_engine.auto_battle = true

	var p_squad: Array[GlyphInstance] = _make_squad(["thunderclaw", "ironbark", "vortail"] as Array[String])

	## Create boss manually (like test_full_loop does)
	var boss_def: BossDef = _data_loader.get_boss("standard_01")
	var boss_species: GlyphSpecies = _data_loader.get_species(boss_def.species_id)
	var boss: GlyphInstance = GlyphInstance.new()
	boss.species = boss_species
	for tid: String in boss_def.phase1_technique_ids:
		var tech: TechniqueDef = _data_loader.get_technique(tid)
		if tech != null:
			boss.techniques.append(tech)
	## Apply boss stat modifier
	boss.bonus_hp = int(float(boss_species.base_hp) * boss_def.stat_modifier) - boss_species.base_hp
	boss.bonus_atk = int(float(boss_species.base_atk) * boss_def.stat_modifier) - boss_species.base_atk
	boss.bonus_def = int(float(boss_species.base_def) * boss_def.stat_modifier) - boss_species.base_def
	boss.bonus_spd = int(float(boss_species.base_spd) * boss_def.stat_modifier) - boss_species.base_spd
	boss.bonus_res = int(float(boss_species.base_res) * boss_def.stat_modifier) - boss_species.base_res
	boss.calculate_stats()
	var e_squad: Array[GlyphInstance] = [boss]

	## Track if phase transition signal fires
	var phase_data: Dictionary = {"fired": false}
	_engine.phase_transition.connect(func(b: GlyphInstance) -> void: phase_data["fired"] = true)

	scene.start_battle(p_squad, e_squad, boss_def)
	scene._on_formation_confirmed(scene._formation_setup.get_positions())
	scene._animation_queue.drain()

	var ended: bool = _engine.phase == _engine.BattlePhase.VICTORY or _engine.phase == _engine.BattlePhase.DEFEAT
	_assert(ended, "Boss battle completed without crash")

	var result: String = "VICTORY" if _engine.phase == _engine.BattlePhase.VICTORY else "DEFEAT"
	print("       Boss battle: %s in %d turns" % [result, _engine.turn_count])

	_assert(_engine.is_boss_battle, "Engine recognized boss battle")
	_assert(scene._panels.size() > 0, "Panels created for boss battle")
	_assert(scene._combat_log.get_entry_count() > 0, "Log entries for boss battle")

	## Phase transition may or may not fire depending on battle flow
	if phase_data["fired"]:
		print("       Phase transition DID occur")
	else:
		print("       Phase transition did NOT occur (boss died/won before 50%)")
	_assert(true, "Boss battle phase transition handling didn't crash")

	## Disconnect
	if _engine.phase_transition.get_connections().size() > 0:
		for conn: Dictionary in _engine.phase_transition.get_connections():
			_engine.phase_transition.disconnect(conn["callable"])

	scene.queue_free()
	_scene = null
	_engine.auto_battle = false
	print("")


# ==========================================================================
# Flee / Forfeit Tests
# ==========================================================================

func _test_flee_button_exists() -> void:
	print("--- Flee Button: Exists in action menu ---")
	var scene: BattleScene = _create_battle_scene()
	_assert(scene._flee_button != null, "Flee button exists")
	_assert(scene._flee_button.text == "Flee", "Flee button text is 'Flee'")

	## Start non-boss battle
	var p_squad: Array[GlyphInstance] = _make_squad(["sparkfin"] as Array[String])
	var e_squad: Array[GlyphInstance] = _make_squad(["zapplet"] as Array[String])
	scene.start_battle(p_squad, e_squad)
	scene._on_formation_confirmed(scene._formation_setup.get_positions())

	## Manually trigger action menu rebuild (battle may end before player turn)
	scene._show_action_menu(p_squad[0])

	## Flee button should be in the action menu for non-boss battles
	var flee_in_menu: bool = scene._flee_button.get_parent() == scene._action_menu
	_assert(flee_in_menu, "Flee button is in action menu")

	scene.queue_free()
	_scene = null
	print("")


func _test_forfeit_triggers_defeat() -> void:
	print("--- Forfeit: Triggers DEFEAT ---")
	var scene: BattleScene = _create_battle_scene()
	var p_squad: Array[GlyphInstance] = _make_squad(["sparkfin"] as Array[String])
	var e_squad: Array[GlyphInstance] = _make_squad(["zapplet"] as Array[String])

	var lost_signal: Dictionary = {"fired": false}
	_engine.battle_lost.connect(func(_s: Array[GlyphInstance]) -> void: lost_signal["fired"] = true)

	scene.start_battle(p_squad, e_squad)
	scene._on_formation_confirmed(scene._formation_setup.get_positions())
	scene._animation_queue.drain()

	## Call forfeit
	_engine.forfeit()

	_assert(_engine.phase == _engine.BattlePhase.DEFEAT, "Phase is DEFEAT after forfeit")
	_assert(lost_signal["fired"], "battle_lost emitted after forfeit")

	## Drain battle_lost animation
	scene._animation_queue.drain()
	_assert(scene._state == BattleScene.UIState.RESULT, "BattleScene enters RESULT state")

	## Clean up signal
	for conn: Dictionary in _engine.battle_lost.get_connections():
		_engine.battle_lost.disconnect(conn["callable"])

	scene.queue_free()
	_scene = null
	print("")


func _test_flee_hidden_for_boss() -> void:
	print("--- Flee Button: Hidden for boss ---")
	var scene: BattleScene = _create_battle_scene()
	_engine.auto_battle = false

	var p_squad: Array[GlyphInstance] = _make_squad(["thunderclaw", "ironbark"] as Array[String])

	## Create boss
	var boss_def: BossDef = _data_loader.get_boss("standard_01")
	var boss_species: GlyphSpecies = _data_loader.get_species(boss_def.species_id)
	var boss: GlyphInstance = GlyphInstance.new()
	boss.species = boss_species
	for tid: String in boss_def.phase1_technique_ids:
		var tech: TechniqueDef = _data_loader.get_technique(tid)
		if tech != null:
			boss.techniques.append(tech)
	boss.calculate_stats()
	var e_squad: Array[GlyphInstance] = [boss]

	scene.start_battle(p_squad, e_squad, boss_def)
	scene._on_formation_confirmed(scene._formation_setup.get_positions())
	scene._animation_queue.drain()

	## Flee button should NOT be in the action menu for boss battles
	var flee_in_menu: bool = scene._flee_button.get_parent() == scene._action_menu
	_assert(not flee_in_menu, "Flee button not in action menu for boss battle")

	scene.queue_free()
	_scene = null
	_engine.auto_battle = false
	print("")
