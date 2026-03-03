class_name BattleScene
extends Control

## Main battle UI orchestrator. Builds full scene tree programmatically,
## wires CombatEngine signals, manages UI state machine.
## Pure presentation layer — all logic lives in CombatEngine.

signal battle_finished(won: bool)

enum UIState {
	WAITING,
	FORMATION,
	ACTION_MENU,
	TECHNIQUE_LIST,
	TARGET_SELECT,
	ANIMATING,
	RESULT,
}

const AFFINITY_COLORS: Dictionary = {
	"electric": Color("#FFD700"),
	"ground": Color("#4CAF50"),
	"water": Color("#00ACC1"),
	"neutral": Color("#888888"),
}

## Injectable dependency
var combat_engine: Node = null

## UI state
var _state: int = UIState.WAITING
var _selected_technique: TechniqueDef = null
var _current_actor: GlyphInstance = null

## Scene tree nodes
var _background: ColorRect = null
var _formation_setup: FormationSetup = null
var _battlefield: Control = null
var _enemy_front_row: HBoxContainer = null
var _enemy_back_row: HBoxContainer = null
var _player_front_row: HBoxContainer = null
var _player_back_row: HBoxContainer = null
var _turn_order_bar: HBoxContainer = null
var _action_menu: VBoxContainer = null
var _technique_list: VBoxContainer = null
var _target_selector: TargetSelector = null
var _combat_log: BattleLog = null
var _phase_overlay: PhaseOverlay = null
var _result_screen: ResultScreen = null
var _animation_queue: AnimationQueue = null
var _interrupt_label: Label = null

## Glyph panel tracking
var _panels: Dictionary = {}  ## instance_id → GlyphPanel
var _turn_portraits: Array[GlyphPortrait] = []

## Action menu buttons
var _attack_button: Button = null
var _guard_button: Button = null
var _swap_button: Button = null

## Track squads
var _player_squad: Array[GlyphInstance] = []
var _enemy_squad: Array[GlyphInstance] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene_tree()
	_connect_internal_signals()


func start_battle(p_squad: Array[GlyphInstance], e_squad: Array[GlyphInstance], boss_def: BossDef = null) -> void:
	_player_squad = p_squad
	_enemy_squad = e_squad
	reset()

	if combat_engine == null:
		push_error("BattleScene: combat_engine not set")
		return

	_connect_engine_signals()
	combat_engine.start_battle(p_squad, e_squad, boss_def)


func reset() -> void:
	_state = UIState.WAITING
	_selected_technique = null
	_current_actor = null
	_panels.clear()
	_turn_portraits.clear()

	## Clear battlefield panels
	_remove_all_children(_enemy_front_row)
	_remove_all_children(_enemy_back_row)
	_remove_all_children(_player_front_row)
	_remove_all_children(_player_back_row)

	## Clear turn order bar (skip label at index 0)
	while _turn_order_bar.get_child_count() > 1:
		var child: Node = _turn_order_bar.get_child(_turn_order_bar.get_child_count() - 1)
		_turn_order_bar.remove_child(child)
		child.queue_free()

	## Clear technique list
	_clear_technique_list()

	## Hide overlays
	_action_menu.visible = false
	_technique_list.visible = false
	_formation_setup.hide_formation()
	_target_selector.hide_targets()
	_phase_overlay.visible = false
	_result_screen.hide_result()
	_combat_log.clear_log()
	_animation_queue.clear()
	_interrupt_label.visible = false

	## Disconnect old engine signals
	_disconnect_engine_signals()


# ==========================================================================
# Scene Tree Construction
# ==========================================================================

func _build_scene_tree() -> void:
	## Background
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.color = Color("#0D1117")
	add_child(_background)

	## Battlefield container
	_battlefield = Control.new()
	_battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_battlefield)

	_build_battlefield()

	## Turn order bar at top
	_turn_order_bar = HBoxContainer.new()
	_turn_order_bar.position = Vector2(20, 12)
	_turn_order_bar.add_theme_constant_override("separation", 6)
	add_child(_turn_order_bar)

	## Turn order label
	var turn_label: Label = Label.new()
	turn_label.text = "TURN: "
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_turn_order_bar.add_child(turn_label)

	## Action menu (right side, anchored)
	_action_menu = VBoxContainer.new()
	_action_menu.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_action_menu.offset_left = -180.0
	_action_menu.offset_top = -80.0
	_action_menu.offset_right = -20.0
	_action_menu.offset_bottom = 80.0
	_action_menu.add_theme_constant_override("separation", 10)
	_action_menu.visible = false
	add_child(_action_menu)

	_build_action_menu()

	## Technique list (right side, same area as action menu)
	_technique_list = VBoxContainer.new()
	_technique_list.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_technique_list.offset_left = -340.0
	_technique_list.offset_top = -120.0
	_technique_list.offset_right = -20.0
	_technique_list.offset_bottom = 120.0
	_technique_list.add_theme_constant_override("separation", 6)
	_technique_list.visible = false
	add_child(_technique_list)

	## Target selector overlay
	_target_selector = TargetSelector.new()
	add_child(_target_selector)

	## Combat log (bottom, full width minus right panel)
	_combat_log = BattleLog.new()
	_combat_log.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_combat_log.offset_left = 20.0
	_combat_log.offset_top = -150.0
	_combat_log.offset_right = -200.0
	_combat_log.offset_bottom = -10.0
	add_child(_combat_log)

	## Interrupt flash label (centered, hidden by default)
	_interrupt_label = Label.new()
	_interrupt_label.set_anchors_preset(Control.PRESET_CENTER)
	_interrupt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interrupt_label.add_theme_font_size_override("font_size", 36)
	_interrupt_label.add_theme_color_override("font_color", Color("#00DDDD"))
	_interrupt_label.visible = false
	add_child(_interrupt_label)

	## Formation setup (full-screen overlay, above everything except phase/result)
	_formation_setup = FormationSetup.new()
	add_child(_formation_setup)

	## Phase overlay
	_phase_overlay = PhaseOverlay.new()
	add_child(_phase_overlay)

	## Result screen
	_result_screen = ResultScreen.new()
	add_child(_result_screen)

	## Animation queue (non-visual Node)
	_animation_queue = AnimationQueue.new()
	add_child(_animation_queue)


func _build_battlefield() -> void:
	## Battlefield layout: front rows face each other at the center line.
	## Top to bottom: Enemy BACK → Enemy FRONT → center → Player FRONT → Player BACK
	## Each row sits in a tinted lane (PanelContainer) with min height so empty rows are visible.
	var field: VBoxContainer = VBoxContainer.new()
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.offset_left = 40.0
	field.offset_top = 100.0
	field.offset_right = -200.0
	field.offset_bottom = -160.0
	field.add_theme_constant_override("separation", 4)
	_battlefield.add_child(field)

	## Enemy label
	var enemy_label: Label = Label.new()
	enemy_label.text = "Enemy"
	enemy_label.add_theme_font_size_override("font_size", 14)
	enemy_label.add_theme_color_override("font_color", Color("#FF6666"))
	field.add_child(enemy_label)

	## Enemy BACK lane (top — furthest from center, dimmer)
	var enemy_back_lane: PanelContainer = _make_row_lane(Color("#13151d"))
	field.add_child(enemy_back_lane)
	var enemy_back_inner: HBoxContainer = HBoxContainer.new()
	enemy_back_inner.add_theme_constant_override("separation", 8)
	enemy_back_lane.add_child(enemy_back_inner)
	enemy_back_inner.add_child(_make_row_label("BACK", Color("#666666")))
	_enemy_back_row = HBoxContainer.new()
	_enemy_back_row.add_theme_constant_override("separation", 8)
	enemy_back_inner.add_child(_enemy_back_row)

	## Spacer between enemy back and front
	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 2)
	field.add_child(spacer1)

	## Enemy FRONT lane (closer to center, brighter)
	var enemy_front_lane: PanelContainer = _make_row_lane(Color("#1e2235"))
	field.add_child(enemy_front_lane)
	var enemy_front_inner: HBoxContainer = HBoxContainer.new()
	enemy_front_inner.add_theme_constant_override("separation", 8)
	enemy_front_lane.add_child(enemy_front_inner)
	enemy_front_inner.add_child(_make_row_label("FRONT", Color("#AAAAAA")))
	_enemy_front_row = HBoxContainer.new()
	_enemy_front_row.add_theme_constant_override("separation", 8)
	enemy_front_inner.add_child(_enemy_front_row)

	## Center divider
	var center_sep: HSeparator = HSeparator.new()
	center_sep.custom_minimum_size = Vector2(0, 10)
	field.add_child(center_sep)

	## Player label
	var player_label: Label = Label.new()
	player_label.text = "Player"
	player_label.add_theme_font_size_override("font_size", 14)
	player_label.add_theme_color_override("font_color", Color("#6688FF"))
	field.add_child(player_label)

	## Player FRONT lane (closer to center, brighter)
	var player_front_lane: PanelContainer = _make_row_lane(Color("#1e2235"))
	field.add_child(player_front_lane)
	var player_front_inner: HBoxContainer = HBoxContainer.new()
	player_front_inner.add_theme_constant_override("separation", 8)
	player_front_lane.add_child(player_front_inner)
	player_front_inner.add_child(_make_row_label("FRONT", Color("#AAAAAA")))
	_player_front_row = HBoxContainer.new()
	_player_front_row.add_theme_constant_override("separation", 8)
	player_front_inner.add_child(_player_front_row)

	## Spacer between player front and back
	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 2)
	field.add_child(spacer2)

	## Player BACK lane (bottom — furthest from center, dimmer)
	var player_back_lane: PanelContainer = _make_row_lane(Color("#13151d"))
	field.add_child(player_back_lane)
	var player_back_inner: HBoxContainer = HBoxContainer.new()
	player_back_inner.add_theme_constant_override("separation", 8)
	player_back_lane.add_child(player_back_inner)
	player_back_inner.add_child(_make_row_label("BACK", Color("#666666")))
	_player_back_row = HBoxContainer.new()
	_player_back_row.add_theme_constant_override("separation", 8)
	player_back_inner.add_child(_player_back_row)


func _build_action_menu() -> void:
	var menu_label: Label = Label.new()
	menu_label.text = "Actions"
	menu_label.add_theme_font_size_override("font_size", 20)
	menu_label.add_theme_color_override("font_color", Color("#FFD700"))
	_action_menu.add_child(menu_label)

	_attack_button = Button.new()
	_attack_button.text = "Attack"
	_attack_button.custom_minimum_size = Vector2(160, 40)
	_attack_button.pressed.connect(_on_attack_pressed)
	_action_menu.add_child(_attack_button)

	_guard_button = Button.new()
	_guard_button.text = "Guard"
	_guard_button.custom_minimum_size = Vector2(160, 40)
	_guard_button.pressed.connect(_on_guard_pressed)
	_action_menu.add_child(_guard_button)

	_swap_button = Button.new()
	_swap_button.text = "Swap"
	_swap_button.custom_minimum_size = Vector2(160, 40)
	_swap_button.pressed.connect(_on_swap_pressed)
	_action_menu.add_child(_swap_button)


func _make_row_lane(bg_color: Color) -> PanelContainer:
	var lane: PanelContainer = PanelContainer.new()
	lane.custom_minimum_size = Vector2(0, 32)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	lane.add_theme_stylebox_override("panel", style)
	return lane


func _make_row_label(p_text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = p_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.custom_minimum_size = Vector2(44, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


# ==========================================================================
# Signal Wiring
# ==========================================================================

var _engine_connections: Array[Dictionary] = []

func _connect_engine_signals() -> void:
	if combat_engine == null:
		return
	_disconnect_engine_signals()

	var connections: Array[Array] = [
		["battle_started", _on_battle_started],
		["turn_started", _on_turn_started],
		["technique_used", _on_technique_used],
		["glyph_ko", _on_glyph_ko],
		["glyph_dealt_finishing_blow", _on_finishing_blow],
		["interrupt_triggered", _on_interrupt_triggered],
		["status_applied", _on_status_applied],
		["status_expired", _on_status_expired],
		["status_resisted", _on_status_resisted],
		["status_immune", _on_status_immune],
		["affinity_advantage_hit", _on_affinity_advantage],
		["guard_activated", _on_guard_activated],
		["swap_performed", _on_swap_performed],
		["battle_won", _on_battle_won],
		["battle_lost", _on_battle_lost],
		["turn_queue_updated", _on_turn_queue_updated],
		["phase_transition", _on_phase_transition],
		["burn_damage", _on_burn_damage],
		["round_started", _on_round_started],
	]

	for conn: Array in connections:
		var sig_name: String = conn[0]
		var handler: Callable = conn[1]
		combat_engine.connect(sig_name, handler)
		_engine_connections.append({"signal": sig_name, "handler": handler})


func _disconnect_engine_signals() -> void:
	if combat_engine == null:
		return
	for conn: Dictionary in _engine_connections:
		if combat_engine.is_connected(conn["signal"], conn["handler"]):
			combat_engine.disconnect(conn["signal"], conn["handler"])
	_engine_connections.clear()


func _connect_internal_signals() -> void:
	_formation_setup.formation_confirmed.connect(_on_formation_confirmed)
	_target_selector.target_selected.connect(_on_target_selected)
	_target_selector.selection_cancelled.connect(_on_target_cancelled)
	_result_screen.continue_pressed.connect(_on_continue_pressed)
	_animation_queue.queue_empty.connect(_on_animation_queue_empty)
	_animation_queue.event_started.connect(_process_queued_event)


# ==========================================================================
# CombatEngine Signal Handlers → enqueue to AnimationQueue
# ==========================================================================

func _on_battle_started(p_squad: Array[GlyphInstance], e_squad: Array[GlyphInstance]) -> void:
	_player_squad = p_squad
	_enemy_squad = e_squad
	_state = UIState.FORMATION
	_battlefield.visible = false
	_formation_setup.show_formation(p_squad)
	_combat_log.add_entry("Battle begins!", Color("#FFD700"))


func _on_turn_started(glyph: GlyphInstance, turn_index: int) -> void:
	_animation_queue.enqueue("turn_started", {"glyph": glyph, "turn_index": turn_index}, 0.2)


func _on_technique_used(user: GlyphInstance, technique: TechniqueDef, target: GlyphInstance, damage: int) -> void:
	_animation_queue.enqueue("technique_used", {
		"user": user, "technique": technique, "target": target, "damage": damage
	}, 0.5)


func _on_glyph_ko(glyph: GlyphInstance, attacker: GlyphInstance) -> void:
	_animation_queue.enqueue("glyph_ko", {"glyph": glyph, "attacker": attacker}, 0.4)


func _on_finishing_blow(attacker: GlyphInstance, target: GlyphInstance) -> void:
	## Logged but no separate animation
	_animation_queue.enqueue_callback(func() -> void:
		_combat_log.add_entry("%s dealt the finishing blow to %s!" % [
			attacker.species.name, target.species.name
		], Color("#FF8800"))
	)


func _on_interrupt_triggered(defender: GlyphInstance, technique: TechniqueDef, attacker: GlyphInstance) -> void:
	_animation_queue.enqueue("interrupt", {
		"defender": defender, "technique": technique, "attacker": attacker
	}, 0.8)


func _on_status_applied(target: GlyphInstance, status_id: String) -> void:
	_animation_queue.enqueue_callback(func() -> void:
		_combat_log.add_entry("%s is now %s!" % [target.species.name, status_id.to_upper()], Color("#FFAA00"))
		_refresh_panel(target)
		if _panels.has(target.instance_id):
			(_panels[target.instance_id] as GlyphPanel).flash_status(status_id)
	, 0.15)


func _on_status_expired(target: GlyphInstance, status_id: String) -> void:
	_animation_queue.enqueue_callback(func() -> void:
		_combat_log.add_entry("%s's %s wore off." % [target.species.name, status_id], Color("#888888"))
		_refresh_panel(target)
	, 0.1)


func _on_status_resisted(target: GlyphInstance, status_id: String) -> void:
	_animation_queue.enqueue_callback(func() -> void:
		_combat_log.add_entry("%s resisted %s!" % [target.species.name, status_id], Color("#AAAAAA"))
	)


func _on_status_immune(target: GlyphInstance, status_id: String) -> void:
	_animation_queue.enqueue_callback(func() -> void:
		_combat_log.add_entry("%s is immune to %s!" % [target.species.name, status_id], Color("#AAAAAA"))
	)


func _on_affinity_advantage(attacker: GlyphInstance, target: GlyphInstance) -> void:
	_animation_queue.enqueue_callback(func() -> void:
		_combat_log.add_entry("Affinity advantage! %s vs %s" % [
			attacker.species.affinity.to_upper(), target.species.affinity.to_upper()
		], Color("#FFD700"))
	)


func _on_guard_activated(glyph: GlyphInstance) -> void:
	_animation_queue.enqueue_callback(func() -> void:
		var has_interrupt: bool = false
		for tech: TechniqueDef in glyph.techniques:
			if tech.category == "interrupt":
				has_interrupt = true
				break
		if has_interrupt:
			_combat_log.add_entry("%s is guarding. Interrupts ready!" % glyph.species.name, Color("#00BFFF"))
		else:
			_combat_log.add_entry("%s is guarding." % glyph.species.name, Color("#00BFFF"))
		_refresh_panel(glyph)
	, 0.2)


func _on_swap_performed(glyph_a: GlyphInstance, glyph_b: GlyphInstance) -> void:
	_animation_queue.enqueue("swap", {"glyph_a": glyph_a, "glyph_b": glyph_b}, 0.3)


func _on_battle_won(p_squad: Array[GlyphInstance], turns_taken: int, ko_list: Array[GlyphInstance]) -> void:
	_animation_queue.enqueue("battle_won", {
		"squad": p_squad, "turns": turns_taken, "kos": ko_list
	}, 0.3)


func _on_battle_lost(p_squad: Array[GlyphInstance]) -> void:
	_animation_queue.enqueue("battle_lost", {"squad": p_squad}, 0.3)


func _on_turn_queue_updated(queue: Array[GlyphInstance]) -> void:
	## Update immediately (no queue delay)
	_refresh_turn_order(queue)


func _on_phase_transition(boss: GlyphInstance) -> void:
	_animation_queue.enqueue("phase_transition", {"boss": boss}, 0.1)


func _on_burn_damage(glyph: GlyphInstance, damage: int) -> void:
	_animation_queue.enqueue_callback(func() -> void:
		_combat_log.add_entry("%s takes %d burn damage!" % [glyph.species.name, damage], Color("#FF8800"))
		_refresh_panel(glyph)
		_spawn_damage_number(glyph, damage, "burn")
	, 0.3)


func _on_round_started(round_number: int) -> void:
	_animation_queue.enqueue_callback(func() -> void:
		_combat_log.add_entry("--- Round %d ---" % round_number, Color("#FFDD44"))
	, 0.1)


# ==========================================================================
# Animation Queue Event Processing
# ==========================================================================

func _on_animation_queue_empty() -> void:
	## Check if it's time for player input
	if combat_engine == null:
		return
	if combat_engine.phase == combat_engine.BattlePhase.TURN_ACTIVE:
		if combat_engine.current_actor != null and combat_engine.current_actor.side == "player":
			_show_action_menu(combat_engine.current_actor)
			return
	## Otherwise we're waiting for engine to advance


func _process_queued_event(event: Dictionary) -> void:
	## Called by animation_queue event_started signal
	var type: String = event["type"]
	var data: Dictionary = event["data"]

	match type:
		"turn_started":
			_handle_turn_started_visual(data["glyph"], data["turn_index"])
		"technique_used":
			_handle_technique_used_visual(data["user"], data["technique"], data["target"], data["damage"])
		"glyph_ko":
			_handle_ko_visual(data["glyph"])
		"interrupt":
			_handle_interrupt_visual(data["defender"], data["technique"])
		"swap":
			_handle_swap_visual(data["glyph_a"], data["glyph_b"])
		"phase_transition":
			_handle_phase_transition_visual(data["boss"])
		"battle_won":
			_handle_battle_won_visual(data["turns"], data["kos"])
		"battle_lost":
			_handle_battle_lost_visual()


func _handle_turn_started_visual(glyph: GlyphInstance, turn_index: int) -> void:
	_current_actor = glyph
	var name: String = glyph.species.name if glyph.species else "???"

	if StatusManager.is_stunned(glyph):
		_combat_log.add_entry("%s is stunned and can't act!" % name, Color("#FFDD44"))
	else:
		var side_color: Color = Color("#6688FF") if glyph.side == "player" else Color("#FF6666")
		_combat_log.add_entry("%s's turn (#%d)" % [name, turn_index], side_color)

	## Highlight current actor panel
	_highlight_current_actor(glyph)

	## Refresh turn order bar to show remaining queue with current actor highlighted
	if combat_engine != null:
		var remaining: Array[GlyphInstance] = combat_engine.turn_queue.get_preview(6)
		_refresh_turn_order(remaining)


func _handle_technique_used_visual(user: GlyphInstance, technique: TechniqueDef, target: GlyphInstance, damage: int) -> void:
	var user_name: String = user.species.name if user.species else "???"
	var target_name: String = target.species.name if target.species else "???"

	if technique.category == "support":
		if technique.support_effect == "heal_percent" or technique.support_effect == "heal_percent_all":
			var healed: int = target.current_hp  ## Already applied by engine
			_combat_log.add_entry("%s heals %s!" % [user_name, target_name], Color("#44FF44"))
			_refresh_panel(target)
			_spawn_damage_number(target, 0, "heal")
		elif technique.support_effect == "shield":
			_combat_log.add_entry("%s shields %s!" % [user_name, target_name], Color("#00DDDD"))
			_refresh_panel(target)
			_spawn_damage_number(target, 0, "shield")
		else:
			_combat_log.add_entry("%s uses %s on %s!" % [user_name, technique.name, target_name], Color("#44AAFF"))
			_refresh_panel(target)
	else:
		_combat_log.add_entry("%s uses %s on %s for %d damage!" % [
			user_name, technique.name, target_name, damage
		], Color.WHITE)
		_refresh_panel(target)
		if damage > 0:
			_spawn_damage_number(target, damage, "damage")
			if _panels.has(target.instance_id):
				(_panels[target.instance_id] as GlyphPanel).flash_damage()

	_refresh_panel(user)


func _handle_ko_visual(glyph: GlyphInstance) -> void:
	var name: String = glyph.species.name if glyph.species else "???"
	_combat_log.add_entry("%s is knocked out!" % name, Color("#FF4444"))
	if _panels.has(glyph.instance_id):
		(_panels[glyph.instance_id] as GlyphPanel).play_ko()


func _handle_interrupt_visual(defender: GlyphInstance, technique: TechniqueDef) -> void:
	var name: String = defender.species.name if defender.species else "???"
	_combat_log.add_entry("%s triggers %s!" % [name, technique.name], Color("#00DDDD"))

	## Flash interrupt name on screen
	_interrupt_label.text = technique.name.to_upper()
	_interrupt_label.visible = true
	var tween: Tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func() -> void: _interrupt_label.visible = false)


func _handle_swap_visual(glyph_a: GlyphInstance, glyph_b: GlyphInstance) -> void:
	var a_name: String = glyph_a.species.name if glyph_a.species else "???"
	var b_name: String = glyph_b.species.name if glyph_b.species else "???"
	_combat_log.add_entry("%s swaps with %s." % [a_name, b_name], Color("#AAAAFF"))
	## Rebuild row assignments
	_rebuild_row_panels()


func _handle_phase_transition_visual(boss: GlyphInstance) -> void:
	var name: String = boss.species.name if boss.species else "???"
	_combat_log.add_entry("%s enters PHASE 2!" % name, Color("#FF4444"))
	_phase_overlay.play_transition()
	_refresh_panel(boss)


func _handle_battle_won_visual(turns: int, kos: Array) -> void:
	_state = UIState.RESULT
	_action_menu.visible = false
	_technique_list.visible = false
	_combat_log.add_entry("VICTORY!", Color("#FFD700"))
	var player_kos: int = 0
	for g: GlyphInstance in _player_squad:
		if g.is_knocked_out:
			player_kos += 1
	_result_screen.show_victory(turns, player_kos)


func _handle_battle_lost_visual() -> void:
	_state = UIState.RESULT
	_action_menu.visible = false
	_technique_list.visible = false
	_combat_log.add_entry("DEFEAT...", Color("#FF4444"))
	_result_screen.show_defeat()


# ==========================================================================
# Formation Flow
# ==========================================================================

func _on_formation_confirmed(positions: Dictionary) -> void:
	_formation_setup.hide_formation()
	_battlefield.visible = true
	_state = UIState.ANIMATING

	## Apply positions first so row_position is set before panels read it
	combat_engine.set_formation(positions)

	## Now populate battlefield panels using the assigned row_position values
	_populate_battlefield()


func _populate_battlefield() -> void:
	for g: GlyphInstance in _player_squad:
		var panel: GlyphPanel = GlyphPanel.new()
		panel.glyph = g
		_panels[g.instance_id] = panel
		if g.row_position == "front":
			_player_front_row.add_child(panel)
		else:
			_player_back_row.add_child(panel)

	for g: GlyphInstance in _enemy_squad:
		var panel: GlyphPanel = GlyphPanel.new()
		panel.glyph = g
		_panels[g.instance_id] = panel
		if g.row_position == "front":
			_enemy_front_row.add_child(panel)
		else:
			_enemy_back_row.add_child(panel)


# ==========================================================================
# Action Menu + Technique + Targeting
# ==========================================================================

func _show_action_menu(actor: GlyphInstance) -> void:
	_state = UIState.ACTION_MENU
	_current_actor = actor
	_action_menu.visible = true
	_technique_list.visible = false

	## Dynamic guard button text — mention interrupts if actor has any
	var has_interrupt: bool = false
	for tech: TechniqueDef in actor.techniques:
		if tech.category == "interrupt":
			has_interrupt = true
			break
	if has_interrupt:
		_guard_button.text = "Guard [Static Guard]"
	else:
		_guard_button.text = "Guard"

	## Enable/disable swap based on squad size
	var alive_allies: Array[GlyphInstance] = []
	for g: GlyphInstance in _player_squad:
		if not g.is_knocked_out and g != actor:
			alive_allies.append(g)
	_swap_button.disabled = alive_allies.is_empty()


func _on_attack_pressed() -> void:
	if _state != UIState.ACTION_MENU:
		return
	_state = UIState.TECHNIQUE_LIST
	_action_menu.visible = false
	_show_technique_list()


func _on_guard_pressed() -> void:
	if _state != UIState.ACTION_MENU:
		return
	_action_menu.visible = false
	_state = UIState.ANIMATING
	combat_engine.submit_action({"action": "guard"})


func _on_swap_pressed() -> void:
	if _state != UIState.ACTION_MENU:
		return
	_state = UIState.TARGET_SELECT
	_selected_technique = null
	_action_menu.visible = false

	## Show alive allies as swap targets
	var targets: Array[GlyphInstance] = []
	for g: GlyphInstance in _player_squad:
		if not g.is_knocked_out and g != _current_actor:
			targets.append(g)
	_target_selector.show_targets(targets, _panels)


func _show_technique_list() -> void:
	_clear_technique_list()
	_technique_list.visible = true

	if _current_actor == null:
		return

	for tech: TechniqueDef in _current_actor.techniques:
		## Skip interrupts (passive only)
		if tech.category == "interrupt":
			continue

		## Determine usability
		var usable: bool = true
		if not _current_actor.is_technique_ready(tech):
			usable = false
		if tech.range_type == "melee" and _current_actor.row_position == "back":
			usable = false

		## Check affinity advantage against reachable targets only
		var reachable: Array[GlyphInstance] = _get_valid_targets(tech)
		var has_advantage: bool = false
		for e: GlyphInstance in reachable:
			if e.species != null and DamageCalculator.has_affinity_advantage(tech.affinity, e.species.affinity):
				has_advantage = true
				break

		var btn: TechniqueButton = TechniqueButton.new()
		btn.setup_with_hint(tech, usable, has_advantage)
		btn.technique_selected.connect(_on_technique_chosen)
		_technique_list.add_child(btn)

	## Back button
	var back_btn: Button = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(200, 30)
	back_btn.pressed.connect(func() -> void:
		_technique_list.visible = false
		_action_menu.visible = true
		_state = UIState.ACTION_MENU
	)
	_technique_list.add_child(back_btn)


func _on_technique_chosen(technique: TechniqueDef) -> void:
	_selected_technique = technique
	_technique_list.visible = false

	## AoE: auto-submit (engine handles all-target logic)
	if technique.range_type == "aoe":
		_action_menu.visible = false
		_state = UIState.ANIMATING
		var first_enemy: GlyphInstance = _get_first_alive_enemy()
		combat_engine.submit_action({
			"action": "attack",
			"technique": technique,
			"target": first_enemy,
		})
		return

	## Support: target allies
	if technique.category == "support":
		_state = UIState.TARGET_SELECT
		_action_menu.visible = false
		var allies: Array[GlyphInstance] = []
		for g: GlyphInstance in _player_squad:
			if not g.is_knocked_out:
				allies.append(g)
		_target_selector.show_targets(allies, _panels)
		return

	## Offensive: show valid enemy targets with affinity hints
	_state = UIState.TARGET_SELECT
	_action_menu.visible = false
	var targets: Array[GlyphInstance] = _get_valid_targets(technique)
	_target_selector.show_targets(targets, _panels, technique.affinity)


func _on_target_selected(target: GlyphInstance) -> void:
	_state = UIState.ANIMATING

	if _selected_technique == null:
		## Swap action
		combat_engine.submit_action({"action": "swap", "target": target})
	else:
		combat_engine.submit_action({
			"action": "attack",
			"technique": _selected_technique,
			"target": target,
		})

	_selected_technique = null


func _on_target_cancelled() -> void:
	## Return to action menu
	_state = UIState.ACTION_MENU
	_action_menu.visible = true
	_technique_list.visible = false


# ==========================================================================
# Target Validation (mirrors AIController logic)
# ==========================================================================

func _get_valid_targets(technique: TechniqueDef) -> Array[GlyphInstance]:
	var alive: Array[GlyphInstance] = []
	for e: GlyphInstance in _enemy_squad:
		if not e.is_knocked_out:
			alive.append(e)

	if alive.is_empty():
		return alive

	## AoE, Piercing, Ranged can hit anyone
	if technique.range_type in ["aoe", "piercing", "ranged"]:
		return alive

	## Melee: front row only if front row has living members
	var front_alive: Array[GlyphInstance] = []
	for e: GlyphInstance in alive:
		if e.row_position == "front":
			front_alive.append(e)

	if front_alive.is_empty():
		return alive
	return front_alive


func _get_first_alive_enemy() -> GlyphInstance:
	for e: GlyphInstance in _enemy_squad:
		if not e.is_knocked_out:
			return e
	return null


# ==========================================================================
# Visual Helpers
# ==========================================================================

func _refresh_panel(glyph: GlyphInstance) -> void:
	if _panels.has(glyph.instance_id):
		(_panels[glyph.instance_id] as GlyphPanel).refresh()


func _refresh_all_panels() -> void:
	for id: int in _panels:
		(_panels[id] as GlyphPanel).refresh()


func _highlight_current_actor(glyph: GlyphInstance) -> void:
	## Show gold active-turn border on current actor, clear others
	for id: int in _panels:
		var panel: GlyphPanel = _panels[id] as GlyphPanel
		panel.set_active_turn(panel.glyph == glyph)


func _refresh_turn_order(queue: Array[GlyphInstance]) -> void:
	## Clear old portraits (skip the "TURN:" label at index 0)
	while _turn_order_bar.get_child_count() > 1:
		var child: Node = _turn_order_bar.get_child(_turn_order_bar.get_child_count() - 1)
		_turn_order_bar.remove_child(child)
		child.queue_free()

	_turn_portraits.clear()

	## Current round: remaining actors
	var count: int = mini(queue.size(), 6)
	for i: int in range(count):
		var portrait: GlyphPortrait = GlyphPortrait.new()
		portrait.glyph = queue[i]
		_turn_order_bar.add_child(portrait)
		_turn_portraits.append(portrait)
		portrait.set_highlighted(i == 0)

	## Next round preview: separator + SPD-sorted alive glyphs (dimmed)
	var next_round: Array[GlyphInstance] = _compute_next_round_preview()
	if next_round.is_empty():
		return

	## Round separator
	var sep_label: Label = Label.new()
	sep_label.text = "|"
	sep_label.add_theme_font_size_override("font_size", 28)
	sep_label.add_theme_color_override("font_color", Color("#555555"))
	sep_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_order_bar.add_child(sep_label)

	## Show up to 6 total slots worth of next-round portraits (dimmed)
	var next_slots: int = mini(next_round.size(), maxi(6 - count, 2))
	for i: int in range(next_slots):
		var portrait: GlyphPortrait = GlyphPortrait.new()
		portrait.glyph = next_round[i]
		portrait.modulate = Color(0.5, 0.5, 0.5, 0.7)
		_turn_order_bar.add_child(portrait)


func _compute_next_round_preview() -> Array[GlyphInstance]:
	## Predict next round order using same deterministic sort as TurnQueue
	var alive: Array[GlyphInstance] = []
	for g: GlyphInstance in _player_squad:
		if not g.is_knocked_out:
			alive.append(g)
	for g: GlyphInstance in _enemy_squad:
		if not g.is_knocked_out:
			alive.append(g)
	alive.sort_custom(TurnQueue.compare_spd)
	return alive


func _rebuild_row_panels() -> void:
	## Move panels to correct rows after a swap
	for g: GlyphInstance in _player_squad:
		if _panels.has(g.instance_id):
			var panel: GlyphPanel = _panels[g.instance_id] as GlyphPanel
			panel.get_parent().remove_child(panel)
			if g.row_position == "front":
				_player_front_row.add_child(panel)
			else:
				_player_back_row.add_child(panel)

	for g: GlyphInstance in _enemy_squad:
		if _panels.has(g.instance_id):
			var panel: GlyphPanel = _panels[g.instance_id] as GlyphPanel
			panel.get_parent().remove_child(panel)
			if g.row_position == "front":
				_enemy_front_row.add_child(panel)
			else:
				_enemy_back_row.add_child(panel)


func _spawn_damage_number(glyph: GlyphInstance, value: int, type: String) -> void:
	if not _panels.has(glyph.instance_id):
		return
	var panel: GlyphPanel = _panels[glyph.instance_id] as GlyphPanel
	var dmg_num: DamageNumber = DamageNumber.new()
	dmg_num.position = Vector2(panel.size.x / 2.0 - 20.0, -10.0)
	panel.add_child(dmg_num)
	dmg_num.show_damage(value, type)


func _clear_technique_list() -> void:
	_remove_all_children(_technique_list)


func _remove_all_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _on_continue_pressed() -> void:
	var won: bool = combat_engine.phase == combat_engine.BattlePhase.VICTORY
	_result_screen.hide_result()
	battle_finished.emit(won)
