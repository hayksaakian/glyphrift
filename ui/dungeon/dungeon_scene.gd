class_name DungeonScene
extends Control

## Main dungeon exploration orchestrator.
## Receives a DungeonState via start_rift(), builds UI, handles navigation.
## Does NOT own DungeonState — receives it like BattleScene receives CombatEngine.

signal combat_requested(enemies: Array[GlyphInstance], boss_def: BossDef)
signal capture_requested(wild_glyph: GlyphInstance)
signal rift_completed(won: bool)
signal floor_changed(floor_number: int)
signal squad_changed()
signal hidden_room_entered()
signal save_and_quit_pressed
signal save_slot_loaded

enum UIState {
	EXPLORING,
	MOVING,
	POPUP,
	COMBAT,
	CAPTURE,
	FLOOR_TRANSITION,
	RESULT,
	PUZZLE,
	SQUAD_SWAP,
}

var dungeon_state: DungeonState = null
var data_loader: Node = null  ## Injectable DataLoader
var _state: UIState = UIState.EXPLORING

var roster_state: RosterState = null  ## Injectable — for item use
var codex_state: CodexState = null  ## Injectable — for conduit reveal reward
var rift_pool: Array[GlyphInstance] = []  ## All glyphs available in this rift (squad + bench)
var _squad_overlay: Variant = null  ## Set by MainScene — for ward charm glyph effects

## Puzzle overlays
var _puzzle_sequence: PuzzleSequence = null
var _puzzle_conduit: PuzzleConduit = null
var _puzzle_echo: PuzzleEcho = null
var _puzzle_quiz: PuzzleQuiz = null
var _echo_battle_active: bool = false
var _echo_glyph: GlyphInstance = null

## Repair picker
var _repair_overlay: ColorRect = null
var _repair_vbox: VBoxContainer = null

## Item swap picker (shown when inventory full)
var _swap_overlay: ColorRect = null
var _swap_vbox: VBoxContainer = null
var _swap_pending_item: ItemDef = null
var _swap_source: String = ""  ## "cache" or "puzzle"

## Active item bonuses (consumed after next combat)
var _capture_item_bonus: float = 0.0
var _ward_charm_active: bool = false

## Last combat stats (for capture calculation)
var _last_enemy_count: int = 1
var _last_turns: int = 3
var _last_recruit_counts: Dictionary = {}  ## species_id → recruit uses
var _boss_capture_pending: bool = false  ## Show rift result after boss capture dismissal

var _background: ColorRect = null
var _floor_map: FloorMap = null
var _crawler_hud: CrawlerHUD = null
var _room_popup: RoomPopup = null
var _capture_popup: CapturePopup = null
var _item_popup: ItemPopup = null
var _rift_name_label: Label = null
var _floor_label: Label = null
var _floor_overlay: ColorRect = null
var _floor_overlay_label: Label = null
var _result_overlay: ColorRect = null
var _result_title: Label = null
var _result_subtitle: Label = null
var _result_continue: Button = null
var _result_won: bool = false
var _warped_out: bool = false

## Exit overlay
var _exit_overlay: ColorRect = null
var _exit_title: Label = null
var _exit_description: Label = null
var _exit_descend_btn: Button = null
var _exit_stay_btn: Button = null
var _exit_target_floor: int = -1

var _pre_combat_room_id: String = ""

const BATTLE_LOSS_HULL_DAMAGE: int = 15
const BATTLE_LOSS_REVIVE_PCT: float = 0.3

var _walk_queue: Array[String] = []
var _dungeon_connections: Array[Dictionary] = []

## Formation setup (shown on demand from combat popup)
var _formation_setup: FormationSetup = null
var _pending_formation_room_type: String = ""
var _pending_formation_room_data: Dictionary = {}

## Pause menu
var _pause_menu: PauseMenu = null

## Squad swap popup
var _squad_swap_popup: SquadSwapPopup = null

## Tutorial hint tracking (tutorial_01 only)
var _tutorial_hints_shown: Dictionary = {}
var _tutorial_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene_tree()
	_connect_internal_signals()


func start_rift(p_dungeon_state: DungeonState) -> void:
	dungeon_state = p_dungeon_state
	_connect_dungeon_signals()
	## Build initial rift pool from current squad
	rift_pool.clear()
	if roster_state != null:
		for g: GlyphInstance in roster_state.active_squad:
			rift_pool.append(g)

	## Pass instant_mode to floor map
	_floor_map.instant_mode = instant_mode

	## Show rift name
	if dungeon_state.rift_template != null:
		_rift_name_label.text = dungeon_state.rift_template.name
	else:
		_rift_name_label.text = ""

	## Pass roster_state to popup for formation preview
	_room_popup.roster_state = roster_state

	## Setup CrawlerHUD
	_crawler_hud.setup(dungeon_state.crawler)
	_crawler_hud.refresh()

	## Build initial floor
	_rebuild_floor()
	_state = UIState.EXPLORING

	## Tutorial hint on first rift entry
	if _is_tutorial_rift():
		_show_tutorial_hint("explore", "Click adjacent rooms to move. Use Scan to reveal hidden room types.")


func get_ui_state() -> UIState:
	return _state


func on_combat_finished(won: bool, enemies: Array[GlyphInstance], turns: int = 3, recruit_counts: Dictionary = {}) -> void:
	## Called by parent after combat ends
	_last_enemy_count = maxi(1, enemies.size())
	_last_turns = turns
	_last_recruit_counts = recruit_counts

	## Consume ward charm (single-use per battle)
	if _ward_charm_active:
		_ward_charm_active = false
		_crawler_hud.remove_active_effect("status_immunity")
		if roster_state != null and not roster_state.active_squad.is_empty():
			_squad_overlay.clear_glyph_effect(roster_state.active_squad[0])

	## Handle echo battle flow
	if _echo_battle_active:
		_echo_battle_active = false
		if won and _echo_glyph != null:
			## Free capture (100% chance) on echo win
			_clear_current_room("Defeated echo glyph.")
			_show_capture_with_chance(_echo_glyph, 1.0)
		else:
			## Loss — apply GDD 8.13 penalty
			_clear_current_room("Echo faded away.")
			_room_popup.hide_popup()
			_apply_battle_loss_penalty()
		_echo_glyph = null
		return

	## Check if this was a boss fight
	var was_boss: bool = false
	for enemy: GlyphInstance in enemies:
		if enemy.is_boss:
			was_boss = true
			break

	if not won:
		_room_popup.hide_popup()
		if was_boss:
			## Boss loss → auto Emergency Warp (no retry within a run)
			_clear_current_room("Guardian stands.")
			_warped_out = true
			_show_result(false)
		else:
			_apply_battle_loss_penalty()
		return

	## Mark current room as cleared so it doesn't retrigger
	_clear_current_room("Defeated wild glyphs.")

	if was_boss:
		## On re-runs (rift already cleared), offer boss capture before result
		var rift_id: String = dungeon_state.rift_template.rift_id if dungeon_state.rift_template != null else ""
		if rift_id != "" and codex_state != null and codex_state.is_rift_cleared(rift_id):
			var boss_glyph: GlyphInstance = enemies[0] if not enemies.is_empty() else null
			if boss_glyph != null:
				_boss_capture_pending = true
				_show_capture(boss_glyph)
				return
		_show_result(true)
		return

	## Wild encounter — offer capture for first non-boss enemy
	if enemies.size() > 0:
		var capturable: GlyphInstance = null
		for enemy: GlyphInstance in enemies:
			if not enemy.is_boss:
				capturable = enemy
				break
		if capturable != null:
			_show_capture(capturable)
			return

	## No capture — back to exploring
	_state = UIState.EXPLORING
	_room_popup.hide_popup()


func on_capture_done() -> void:
	_capture_popup.hide_popup()
	_state = UIState.EXPLORING


func _build_scene_tree() -> void:
	## Background
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.08, 0.08, 0.10)
	_background.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_background)

	## Floor map (centered area below HUD)
	_floor_map = FloorMap.new()
	_floor_map.name = "FloorMap"
	_floor_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_map.offset_top = 50.0  ## Below HUD
	add_child(_floor_map)

	## Crawler HUD (top bar)
	_crawler_hud = CrawlerHUD.new()
	_crawler_hud.name = "CrawlerHUD"
	_crawler_hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_crawler_hud.custom_minimum_size.y = 44.0
	add_child(_crawler_hud)

	## Rift name label (top center, below HUD)
	_rift_name_label = Label.new()
	_rift_name_label.name = "RiftNameLabel"
	_rift_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rift_name_label.offset_top = 48.0
	_rift_name_label.offset_bottom = 70.0
	_rift_name_label.add_theme_font_size_override("font_size", 16)
	_rift_name_label.add_theme_color_override("font_color", Color("#FFD700"))
	_rift_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rift_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rift_name_label)

	## Floor label (bottom left)
	_floor_label = Label.new()
	_floor_label.name = "FloorLabel"
	_floor_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_floor_label.offset_left = 12.0
	_floor_label.offset_bottom = -8.0
	_floor_label.add_theme_font_size_override("font_size", 14)
	_floor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_floor_label.text = "Floor 1"
	_floor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floor_label)

	## Pause menu (reusable component, hidden)
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.instant_mode = instant_mode
	_pause_menu.save_and_quit_pressed.connect(func() -> void: save_and_quit_pressed.emit())
	_pause_menu.save_slot_loaded.connect(func() -> void: save_slot_loaded.emit())
	add_child(_pause_menu)

	## Squad swap popup (full-screen overlay, hidden)
	_squad_swap_popup = SquadSwapPopup.new()
	_squad_swap_popup.name = "SquadSwapPopup"
	_squad_swap_popup.swap_completed.connect(_on_swap_completed)
	_squad_swap_popup.swap_cancelled.connect(_on_swap_cancelled)
	add_child(_squad_swap_popup)

	## Room popup (centered, hidden)
	_room_popup = RoomPopup.new()
	_room_popup.name = "RoomPopup"
	_room_popup.data_loader = data_loader
	_room_popup.set_anchors_preset(Control.PRESET_CENTER)
	_room_popup.offset_left = -160.0
	_room_popup.offset_right = 160.0
	_room_popup.offset_top = -150.0
	_room_popup.offset_bottom = 150.0
	add_child(_room_popup)

	## Capture popup (centered, hidden)
	_capture_popup = CapturePopup.new()
	_capture_popup.name = "CapturePopup"
	_capture_popup.set_anchors_preset(Control.PRESET_CENTER)
	_capture_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_capture_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_capture_popup)

	## Item popup (centered, hidden)
	_item_popup = ItemPopup.new()
	_item_popup.name = "ItemPopup"
	_item_popup.set_anchors_preset(Control.PRESET_CENTER)
	_item_popup.offset_left = -190.0
	_item_popup.offset_right = 190.0
	_item_popup.offset_top = -220.0
	_item_popup.offset_bottom = 220.0
	add_child(_item_popup)

	## Repair picker overlay (modal, hidden)
	_repair_overlay = ColorRect.new()
	_repair_overlay.name = "RepairOverlay"
	_repair_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_repair_overlay.color = Color(0, 0, 0, 0.7)
	_repair_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_repair_overlay.visible = false
	add_child(_repair_overlay)

	var repair_panel: PanelContainer = PanelContainer.new()
	repair_panel.set_anchors_preset(Control.PRESET_CENTER)
	repair_panel.custom_minimum_size = Vector2(280, 200)
	repair_panel.offset_left = -140.0
	repair_panel.offset_right = 140.0
	repair_panel.offset_top = -100.0
	repair_panel.offset_bottom = 100.0
	var repair_style: StyleBoxFlat = StyleBoxFlat.new()
	repair_style.bg_color = Color("#1A1A2E")
	repair_style.corner_radius_top_left = 8
	repair_style.corner_radius_top_right = 8
	repair_style.corner_radius_bottom_left = 8
	repair_style.corner_radius_bottom_right = 8
	repair_style.border_color = Color("#4CAF50")
	repair_style.border_width_left = 2
	repair_style.border_width_right = 2
	repair_style.border_width_top = 2
	repair_style.border_width_bottom = 2
	repair_style.content_margin_left = 12
	repair_style.content_margin_right = 12
	repair_style.content_margin_top = 10
	repair_style.content_margin_bottom = 10
	repair_panel.add_theme_stylebox_override("panel", repair_style)
	_repair_overlay.add_child(repair_panel)

	_repair_vbox = VBoxContainer.new()
	_repair_vbox.add_theme_constant_override("separation", 6)
	repair_panel.add_child(_repair_vbox)

	## Item swap picker overlay (modal, hidden)
	_swap_overlay = ColorRect.new()
	_swap_overlay.name = "SwapOverlay"
	_swap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swap_overlay.color = Color(0, 0, 0, 0.7)
	_swap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_swap_overlay.visible = false
	add_child(_swap_overlay)

	var swap_panel: PanelContainer = PanelContainer.new()
	swap_panel.set_anchors_preset(Control.PRESET_CENTER)
	swap_panel.custom_minimum_size = Vector2(320, 240)
	swap_panel.offset_left = -160.0
	swap_panel.offset_right = 160.0
	swap_panel.offset_top = -120.0
	swap_panel.offset_bottom = 120.0
	var swap_style: StyleBoxFlat = StyleBoxFlat.new()
	swap_style.bg_color = Color("#1A1A2E")
	swap_style.set_corner_radius_all(8)
	swap_style.border_color = Color("#FFD700")
	swap_style.set_border_width_all(2)
	swap_style.content_margin_left = 12
	swap_style.content_margin_right = 12
	swap_style.content_margin_top = 10
	swap_style.content_margin_bottom = 10
	swap_panel.add_theme_stylebox_override("panel", swap_style)
	_swap_overlay.add_child(swap_panel)

	_swap_vbox = VBoxContainer.new()
	_swap_vbox.add_theme_constant_override("separation", 6)
	swap_panel.add_child(_swap_vbox)

	## Puzzle overlays (full screen, hidden)
	_puzzle_sequence = PuzzleSequence.new()
	_puzzle_sequence.name = "PuzzleSequence"
	add_child(_puzzle_sequence)

	_puzzle_conduit = PuzzleConduit.new()
	_puzzle_conduit.name = "PuzzleConduit"
	add_child(_puzzle_conduit)

	_puzzle_echo = PuzzleEcho.new()
	_puzzle_echo.name = "PuzzleEcho"
	add_child(_puzzle_echo)

	_puzzle_quiz = PuzzleQuiz.new()
	_puzzle_quiz.name = "PuzzleQuiz"
	add_child(_puzzle_quiz)

	## Exit overlay (stairs choice — Descend / Stay)
	_exit_overlay = ColorRect.new()
	_exit_overlay.name = "ExitOverlay"
	_exit_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_exit_overlay.color = Color(0, 0, 0, 0.7)
	_exit_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_overlay.visible = false
	add_child(_exit_overlay)

	var exit_panel: PanelContainer = PanelContainer.new()
	exit_panel.set_anchors_preset(Control.PRESET_CENTER)
	exit_panel.custom_minimum_size = Vector2(280, 160)
	exit_panel.offset_left = -140.0
	exit_panel.offset_right = 140.0
	exit_panel.offset_top = -80.0
	exit_panel.offset_bottom = 80.0
	var exit_style: StyleBoxFlat = StyleBoxFlat.new()
	exit_style.bg_color = Color("#1A1A2E")
	exit_style.set_corner_radius_all(8)
	exit_style.border_color = Color("#FFD700")
	exit_style.set_border_width_all(2)
	exit_style.content_margin_left = 16
	exit_style.content_margin_right = 16
	exit_style.content_margin_top = 12
	exit_style.content_margin_bottom = 12
	exit_panel.add_theme_stylebox_override("panel", exit_style)
	_exit_overlay.add_child(exit_panel)

	var exit_vbox: VBoxContainer = VBoxContainer.new()
	exit_vbox.add_theme_constant_override("separation", 10)
	exit_panel.add_child(exit_vbox)

	_exit_title = Label.new()
	_exit_title.text = "Stairs Down"
	_exit_title.add_theme_font_size_override("font_size", 18)
	_exit_title.add_theme_color_override("font_color", Color("#FFD700"))
	_exit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_vbox.add_child(_exit_title)

	_exit_description = Label.new()
	_exit_description.text = "Descend to the next floor?"
	_exit_description.add_theme_font_size_override("font_size", 13)
	_exit_description.add_theme_color_override("font_color", Color("#AAAAAA"))
	_exit_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exit_vbox.add_child(_exit_description)

	var exit_btn_row: HBoxContainer = HBoxContainer.new()
	exit_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	exit_btn_row.add_theme_constant_override("separation", 16)
	exit_vbox.add_child(exit_btn_row)

	_exit_descend_btn = Button.new()
	_exit_descend_btn.name = "DescendButton"
	_exit_descend_btn.text = "Descend"
	_exit_descend_btn.custom_minimum_size = Vector2(100, 36)
	exit_btn_row.add_child(_exit_descend_btn)

	_exit_stay_btn = Button.new()
	_exit_stay_btn.name = "StayButton"
	_exit_stay_btn.text = "Stay"
	_exit_stay_btn.custom_minimum_size = Vector2(100, 36)
	exit_btn_row.add_child(_exit_stay_btn)

	## Floor transition overlay (full screen, hidden)
	_floor_overlay = ColorRect.new()
	_floor_overlay.name = "FloorOverlay"
	_floor_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_overlay.color = Color(0, 0, 0, 0)
	_floor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_overlay.visible = false
	add_child(_floor_overlay)

	_floor_overlay_label = Label.new()
	_floor_overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_floor_overlay_label.add_theme_font_size_override("font_size", 28)
	_floor_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_floor_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_overlay.add_child(_floor_overlay_label)

	## Result overlay (rift complete / failed)
	_result_overlay = ColorRect.new()
	_result_overlay.name = "ResultOverlay"
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.color = Color(0, 0, 0, 1.0)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_overlay.visible = false
	add_child(_result_overlay)

	var result_vbox: VBoxContainer = VBoxContainer.new()
	result_vbox.set_anchors_preset(Control.PRESET_CENTER)
	result_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_vbox.add_theme_constant_override("separation", 12)
	_result_overlay.add_child(result_vbox)

	_result_title = Label.new()
	_result_title.add_theme_font_size_override("font_size", 36)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_vbox.add_child(_result_title)

	_result_subtitle = Label.new()
	_result_subtitle.add_theme_font_size_override("font_size", 16)
	_result_subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_vbox.add_child(_result_subtitle)

	_result_continue = Button.new()
	_result_continue.name = "RiftResultContinueButton"
	_result_continue.text = "Continue"
	_result_continue.custom_minimum_size = Vector2(140, 40)
	_result_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result_continue.pressed.connect(_on_result_continue)
	result_vbox.add_child(_result_continue)


	## Formation setup overlay (hidden, shown on demand)
	_formation_setup = FormationSetup.new()
	_formation_setup.name = "FormationSetup"
	add_child(_formation_setup)

	## Tutorial hint label (top center, overlays everything)
	_tutorial_label = Label.new()
	_tutorial_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tutorial_label.offset_left = -300.0
	_tutorial_label.offset_right = 300.0
	_tutorial_label.offset_top = 50.0
	_tutorial_label.offset_bottom = 100.0
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tutorial_label.add_theme_font_size_override("font_size", 13)
	_tutorial_label.add_theme_color_override("font_color", Color("#88CCFF"))
	_tutorial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tutorial_label.add_theme_constant_override("outline_size", 3)
	_tutorial_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_label.visible = false
	add_child(_tutorial_label)


func _connect_internal_signals() -> void:
	_floor_map.room_clicked.connect(_on_room_clicked)
	_floor_map.room_hovered.connect(_on_room_hovered)
	_floor_map.room_hover_exited.connect(_on_room_hover_exited)
	_room_popup.action_pressed.connect(_on_popup_action)
	_room_popup.formation_requested.connect(_on_formation_requested)
	_room_popup.back_out_pressed.connect(_on_boss_back_out)
	_crawler_hud.ability_pressed.connect(_on_ability_pressed)
	_crawler_hud.items_pressed.connect(_on_items_pressed)
	_crawler_hud.menu_pressed.connect(func() -> void: _pause_menu.toggle())
	_capture_popup.capture_attempted.connect(_on_capture_attempted)
	_capture_popup.capture_released.connect(_on_capture_released)
	_capture_popup.dismissed.connect(_on_capture_dismissed)
	_item_popup.closed.connect(_on_item_popup_closed)
	_item_popup.item_used.connect(_on_item_used)

	## Exit overlay signals
	_exit_descend_btn.pressed.connect(_on_exit_descend)
	_exit_stay_btn.pressed.connect(_on_exit_stay)

	## Click-outside-to-close on modal backdrops
	_exit_overlay.gui_input.connect(_on_backdrop_click.bind(_on_exit_stay))
	_repair_overlay.gui_input.connect(_on_backdrop_click.bind(_hide_repair_picker))
	_swap_overlay.gui_input.connect(_on_backdrop_click.bind(_on_swap_leave))

	## Formation setup
	_formation_setup.formation_confirmed.connect(_on_dungeon_formation_confirmed)

	## Puzzle signals
	_puzzle_sequence.puzzle_completed.connect(_on_puzzle_completed)
	_puzzle_conduit.puzzle_completed.connect(_on_puzzle_completed)
	_puzzle_conduit.success_reached.connect(_on_conduit_success)
	_puzzle_echo.puzzle_completed.connect(_on_puzzle_completed)
	_puzzle_echo.echo_combat_requested.connect(_on_echo_combat_requested)
	_puzzle_quiz.puzzle_completed.connect(_on_puzzle_completed)


func _connect_dungeon_signals() -> void:
	_disconnect_dungeon_signals()
	var connections: Array[Array] = [
		["room_entered", _on_room_entered],
		["room_shown", _on_room_shown],
		["room_revealed", _on_room_revealed],
		["floor_changed", _on_floor_changed],
		["exit_reached", _on_exit_reached],
		["crawler_damaged", _on_crawler_damaged],
		["forced_extraction", _on_forced_extraction],
	]
	for conn: Array in connections:
		dungeon_state.connect(conn[0], conn[1])
		_dungeon_connections.append({"signal": conn[0], "handler": conn[1]})


func _disconnect_dungeon_signals() -> void:
	if dungeon_state == null:
		return
	for conn: Dictionary in _dungeon_connections:
		if dungeon_state.is_connected(conn["signal"], conn["handler"]):
			dungeon_state.disconnect(conn["signal"], conn["handler"])
	_dungeon_connections.clear()


func _rebuild_floor() -> void:
	if dungeon_state == null:
		return
	var floor_idx: int = dungeon_state.current_floor
	if floor_idx >= dungeon_state.floors.size():
		return
	var floor_data: Dictionary = dungeon_state.floors[floor_idx]
	_floor_map.build_floor(floor_data, dungeon_state)
	_floor_map.set_current_room(dungeon_state.current_room_id)
	_floor_map.refresh_all()
	var rift_name: String = dungeon_state.rift_template.name if dungeon_state.rift_template != null else "Rift"
	_floor_label.text = "%s — Floor %d/%d" % [rift_name, floor_idx + 1, dungeon_state.floors.size()]


## --- Signal handlers ---

func _on_room_clicked(room_id: String) -> void:
	if _state != UIState.EXPLORING:
		return
	if dungeon_state == null:
		return

	## Clear any path preview
	_floor_map.clear_path_preview()

	## Direct adjacent move (fast path)
	var adjacent_ids: Dictionary = {}
	for room: Dictionary in dungeon_state.get_adjacent_rooms():
		adjacent_ids[room["id"]] = true
	if adjacent_ids.has(room_id):
		_walk_path([room_id] as Array[String])
		return
	## Non-adjacent: pathfind and walk step by step
	var path: Array[String] = dungeon_state.find_path(room_id)
	if path.is_empty():
		return
	_walk_path(path)


func _walk_path(path: Array[String]) -> void:
	## Walk along a BFS path, stopping early if a room triggers a blocking event.
	if instant_mode:
		## Synchronous walk — preserves existing test behavior
		for room_id: String in path:
			if _state != UIState.EXPLORING:
				break
			_pre_combat_room_id = dungeon_state.current_room_id
			if not dungeon_state.move_to_room(room_id):
				break
		return

	## Animated walk
	_walk_queue = []
	for rid: String in path:
		_walk_queue.append(rid)
	_state = UIState.MOVING
	_walk_next_step()


func _walk_next_step() -> void:
	if _walk_queue.is_empty():
		if _state == UIState.MOVING:
			_state = UIState.EXPLORING
		return

	var next_id: String = _walk_queue[0]
	_walk_queue.remove_at(0)

	_floor_map.animate_token_to(next_id, func() -> void:
		## Move in dungeon state (fires room_entered → _on_room_entered)
		_pre_combat_room_id = dungeon_state.current_room_id
		dungeon_state.move_to_room(next_id)

		## If a blocking event occurred (popup, combat, etc.), stop walking
		if _state != UIState.MOVING:
			_walk_queue.clear()
			return

		_walk_next_step()
	)


func _on_room_hovered(room_id: String) -> void:
	if _state != UIState.EXPLORING:
		return
	if dungeon_state == null:
		return
	## Only show preview for visible rooms
	if not _room_nodes_visible(room_id):
		return
	var path: Array[String] = dungeon_state.find_path(room_id)
	if path.is_empty():
		## Adjacent room — show just that room
		var adjacent_ids: Dictionary = {}
		for room: Dictionary in dungeon_state.get_adjacent_rooms():
			adjacent_ids[room["id"]] = true
		if adjacent_ids.has(room_id) and room_id != dungeon_state.current_room_id:
			_floor_map.show_path_preview([room_id] as Array[String])
		return
	_floor_map.show_path_preview(path)


func _on_room_hover_exited() -> void:
	_floor_map.clear_path_preview()


func _room_nodes_visible(room_id: String) -> bool:
	if dungeon_state == null:
		return false
	var floor_data: Dictionary = dungeon_state.floors[dungeon_state.current_floor]
	for room: Dictionary in floor_data["rooms"]:
		if room["id"] == room_id:
			return room.get("visible", false) or room.get("visited", false) or room.get("revealed", false)
	return false


func _on_room_entered(room: Dictionary) -> void:
	_floor_map.set_current_room(room["id"])
	_floor_map.refresh_all()

	## Cleared rooms never retrigger — just pass through silently
	if room.get("cleared", false):
		return

	var room_type: String = room.get("type", "empty")

	## Skip popups for non-actionable rooms (start, empty on revisit)
	if room_type in ["start", "empty"]:
		return

	## Notify hidden room discovery for milestone tracking
	if room_type == "hidden":
		hidden_room_entered.emit()

	## Tutorial hints for room types
	if _is_tutorial_rift():
		match room_type:
			"enemy":
				_show_tutorial_hint("enemy", "Wild glyphs! Defeat them in combat, then try to capture one for your squad.")
			"hazard":
				_show_tutorial_hint("hazard", "Hazards damage your crawler hull. Use Field Repair to heal, or Reinforce to halve damage.")
			"exit":
				_show_tutorial_hint("exit", "Floor exit! Descend to go deeper, or stay to explore more rooms.")
			"cache", "hidden":
				_show_tutorial_hint("cache", "Supply cache! Items give temporary bonuses like capture chance or status immunity.")

	## Hazards: show popup only on first visit, silently damage on revisits
	if room_type == "hazard":
		if room.get("hazard_seen", false):
			## Revisit — damage already applied by DungeonState, just refresh HUD
			_crawler_hud.refresh()
			return
		room["hazard_seen"] = true

	## Show popup for actionable rooms
	if room_type in ["enemy", "cache", "hazard", "puzzle", "boss", "hidden"]:
		_state = UIState.POPUP
		var extra: String = ""
		if room_type == "hazard" and dungeon_state.rift_template != null:
			extra = str(dungeon_state.rift_template.hazard_damage)
		elif room_type == "boss" and data_loader != null:
			var boss_def: BossDef = data_loader.get_boss(dungeon_state.rift_template.rift_id)
			if boss_def != null:
				var species: GlyphSpecies = data_loader.get_species(boss_def.species_id)
				if species != null:
					extra = species.name
		_room_popup.show_room(room, extra)
	elif room_type == "exit":
		## Exit handled via exit_reached signal → shows Descend/Stay popup
		pass


func _on_room_shown(room_id: String) -> void:
	## Room became visible (foggy) — update map display
	_floor_map.update_room(room_id)
	_floor_map.refresh_all()


func _on_room_revealed(room_id: String, room_type: String) -> void:
	## Generate scout info for enemy/boss rooms on scan
	if room_type == "enemy":
		_generate_scan_info(room_id)
	elif room_type == "boss":
		_generate_boss_scan_info(room_id)
	_floor_map.update_room(room_id)
	_floor_map.refresh_all()


func _on_floor_changed(floor_number: int) -> void:
	## Check if we've gone past last floor (rift complete)
	if floor_number >= dungeon_state.floors.size():
		_rebuild_floor()
		floor_changed.emit(floor_number)
		_show_result(true)
		return

	_play_floor_transition(floor_number)


func _on_crawler_damaged(_amount: int, remaining_hp: int) -> void:
	_crawler_hud.refresh()
	## Screen shake + red flash for hazard damage
	if not instant_mode:
		_play_damage_shake()
	if remaining_hp <= 0:
		pass  ## forced_extraction signal handles this


func _play_damage_shake() -> void:
	var original_pos: Vector2 = position
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.5, 0.5), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(8, 0), 0.03)
	tween.tween_property(self, "position", original_pos + Vector2(-8, 0), 0.03)
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.03)
	tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.03)
	tween.tween_property(self, "position", original_pos, 0.03)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)


func _play_scan_ripple() -> void:
	## Expanding cyan ring from crawler position
	var current_node: RoomNode = _floor_map.get_room_node(dungeon_state.current_room_id)
	if current_node == null:
		return
	var center: Vector2 = current_node.position + current_node.size / 2.0

	var ring: Control = Control.new()
	ring.position = center
	ring.z_index = 10
	_floor_map.add_child(ring)

	var circle: ColorRect = ColorRect.new()
	circle.color = Color(0, 0.8, 1.0, 0.4)
	circle.size = Vector2(10, 10)
	circle.position = -circle.size / 2.0
	circle.pivot_offset = circle.size / 2.0
	ring.add_child(circle)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", Vector2(30, 30), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(circle, "modulate", Color(0, 0.8, 1.0, 0), 0.5).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void: ring.queue_free())


func _on_forced_extraction() -> void:
	## Distinguish voluntary warp (hull > 0) from actual destruction (hull <= 0)
	if dungeon_state != null and dungeon_state.crawler != null:
		_warped_out = dungeon_state.crawler.hull_hp > 0
	else:
		_warped_out = false
	_show_result(false)


func _on_exit_reached(next_floor: int) -> void:
	_exit_target_floor = next_floor
	_exit_description.text = "Descend to Floor %d?" % (next_floor + 1)
	_exit_overlay.visible = true
	_state = UIState.POPUP


func _on_exit_descend() -> void:
	_exit_overlay.visible = false
	if dungeon_state != null:
		dungeon_state.descend()


func _on_exit_stay() -> void:
	_exit_overlay.visible = false
	_state = UIState.EXPLORING


func _on_boss_back_out() -> void:
	_room_popup.hide_popup()
	_state = UIState.EXPLORING


func _on_popup_action(room_type: String, room_data_local: Dictionary) -> void:
	_room_popup.hide_popup()

	match room_type:
		"enemy":
			_state = UIState.COMBAT
			var scan_ids: Array = room_data_local.get("scan_species_ids", [])
			var enemies: Array[GlyphInstance] = _generate_wild_enemies(scan_ids)
			combat_requested.emit(enemies, null)
		"boss":
			_state = UIState.COMBAT
			var boss_data: BossDef = null
			if data_loader != null:
				boss_data = data_loader.get_boss(dungeon_state.rift_template.rift_id)
			var boss_squad: Array[GlyphInstance] = _generate_boss(boss_data)
			combat_requested.emit(boss_squad, boss_data)
		"cache", "hidden":
			if room_data_local.get("cleared", false):
				## Second click (Continue on result) — just dismiss
				_state = UIState.EXPLORING
			else:
				var result: Dictionary = _pick_item()
				_clear_current_room("Looted supplies.")
				if result.get("full", false):
					_show_swap_picker(result["item"], "cache")
					return
				elif result.get("item") != null:
					var found_item: ItemDef = result["item"]
					_room_popup.show_result("Found: %s" % found_item.name, found_item.description)
				else:
					_room_popup.show_result("Cache Empty", "Nothing useful remains.")
				## Stay in POPUP — next Continue click will dismiss
		"puzzle":
			_launch_puzzle(room_data_local)
		"hazard":
			## Hazards are persistent — they damage every pass-through.
			## Only Purge ability converts them to empty. Don't mark cleared.
			_state = UIState.EXPLORING
		"empty", "start":
			_state = UIState.EXPLORING
		"exit":
			## Should not get here — exit handled by DungeonState
			_state = UIState.EXPLORING


func _on_formation_requested(room_type: String, room_data_local: Dictionary) -> void:
	## Player wants to adjust formation before fighting
	if roster_state == null:
		return
	_pending_formation_room_type = room_type
	_pending_formation_room_data = room_data_local
	_room_popup.hide_popup()
	_formation_setup.show_formation(roster_state.active_squad)


func _on_dungeon_formation_confirmed(positions: Dictionary) -> void:
	## Apply formation positions to squad
	_formation_setup.hide_formation()
	for g: GlyphInstance in roster_state.active_squad:
		g.row_position = positions.get(g.instance_id, g.row_position)
	## Now proceed to combat with the pending room data
	_on_popup_action(_pending_formation_room_type, _pending_formation_room_data)
	_pending_formation_room_type = ""
	_pending_formation_room_data = {}


func _on_ability_pressed(ability_name: String) -> void:
	if _state != UIState.EXPLORING:
		return
	if dungeon_state == null:
		return

	## Field repair needs a target picker before spending energy
	if ability_name == "field_repair":
		_show_repair_picker()
		return

	dungeon_state.use_crawler_ability(ability_name)
	_crawler_hud.refresh()
	_floor_map.refresh_all()

	if ability_name == "scan" and not instant_mode:
		_play_scan_ripple()


func _on_capture_attempted(glyph: GlyphInstance, success: bool) -> void:
	if success:
		capture_requested.emit(glyph)


func _on_capture_released(_glyph: GlyphInstance) -> void:
	_capture_popup.hide_popup()
	if _boss_capture_pending:
		_boss_capture_pending = false
		_show_result(true)
	else:
		_state = UIState.EXPLORING


func _on_capture_dismissed() -> void:
	_capture_popup.hide_popup()
	if _boss_capture_pending:
		_boss_capture_pending = false
		_show_result(true)
	else:
		_state = UIState.EXPLORING


func _on_swap_pressed() -> void:
	if _state != UIState.EXPLORING:
		return
	## Need at least one benchable glyph
	var bench_count: int = 0
	if roster_state != null:
		for g: GlyphInstance in rift_pool:
			if not roster_state.active_squad.has(g):
				bench_count += 1
	if bench_count == 0:
		return
	_state = UIState.SQUAD_SWAP
	_squad_swap_popup.roster_state = roster_state
	_squad_swap_popup.crawler_state = dungeon_state.crawler if dungeon_state else null
	_squad_swap_popup.rift_pool = rift_pool
	_squad_swap_popup.show_popup()


func _on_swap_completed() -> void:
	_squad_swap_popup.hide_popup()
	_state = UIState.EXPLORING
	squad_changed.emit()


func _on_swap_cancelled() -> void:
	_squad_swap_popup.hide_popup()
	_state = UIState.EXPLORING


func _on_items_pressed() -> void:
	if _state != UIState.EXPLORING:
		return
	if dungeon_state == null:
		return
	_state = UIState.POPUP
	_item_popup.show_items(dungeon_state.crawler, roster_state)


func _on_item_popup_closed() -> void:
	_item_popup.hide_popup()
	_state = UIState.EXPLORING
	_crawler_hud.refresh()


func _on_item_used(item: ItemDef) -> void:
	if item.effect_type == "capture_bonus":
		_capture_item_bonus += item.effect_value / 100.0
		_crawler_hud.add_active_effect("capture_bonus",
			"Echo Lure +%d%%" % int(item.effect_value),
			"Capture chance increased by %d%% for the next battle." % int(item.effect_value))
	elif item.effect_type == "status_immunity":
		_ward_charm_active = true
		## Apply immunity to first squad glyph for next battle
		if roster_state != null and not roster_state.active_squad.is_empty():
			var target: GlyphInstance = roster_state.active_squad[0]
			for status_id: String in ["burn", "stun", "slow", "weaken", "corrode"]:
				target.status_immunities[status_id] = 1
			_squad_overlay.set_glyph_effect(target, "\U0001f6e1", "Ward: blocks next status effect")
		_crawler_hud.add_active_effect("status_immunity",
			"Ward Charm",
			"Next status effect on %s will be blocked." % (
				roster_state.active_squad[0].species.name if roster_state != null and not roster_state.active_squad.is_empty() else "first glyph"
			))
	_crawler_hud.refresh()
	squad_changed.emit()


## --- Helpers ---


func _on_backdrop_click(event: InputEvent, dismiss_fn: Callable) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			dismiss_fn.call()


## Instant mode for headless testing — skips transition animation
var instant_mode: bool = false


func _play_floor_transition(floor_number: int) -> void:
	_state = UIState.FLOOR_TRANSITION

	var rift_name: String = dungeon_state.rift_template.name if dungeon_state.rift_template != null else "Rift"
	_floor_overlay_label.text = "%s\nFloor %d" % [rift_name, floor_number + 1]
	_floor_overlay.visible = true
	_floor_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	if instant_mode:
		_floor_overlay.color = Color(0, 0, 0, 0)
		_floor_overlay.visible = false
		_floor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rebuild_floor()
		floor_changed.emit(floor_number)
		_state = UIState.EXPLORING
		return

	## Fade to black with downward slide on label
	_floor_overlay_label.position.y = -20.0
	_floor_overlay_label.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.tween_property(_floor_overlay, "color", Color(0, 0, 0, 1), 0.15)

	## Slide label down into view
	tween.set_parallel(true)
	tween.tween_property(_floor_overlay_label, "position:y", 0.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(_floor_overlay_label, "modulate", Color.WHITE, 0.2)
	tween.set_parallel(false)

	## Hold on title
	tween.tween_callback(func() -> void:
		_rebuild_floor()
	)
	tween.tween_interval(0.2)

	## Fade back in
	tween.tween_property(_floor_overlay, "color", Color(0, 0, 0, 0), 0.15)
	tween.tween_callback(func() -> void:
		_floor_overlay.visible = false
		_floor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_state = UIState.EXPLORING
		floor_changed.emit(floor_number)
	)


func _show_result(won: bool) -> void:
	_state = UIState.RESULT
	_result_won = won
	_room_popup.hide_popup()

	if won:
		_result_title.text = "RIFT COMPLETE"
		_result_title.add_theme_color_override("font_color", Color("#FFD700"))
		var rift_name: String = dungeon_state.rift_template.name if dungeon_state.rift_template != null else "Rift"
		_result_subtitle.text = "%s conquered!" % rift_name
	elif _warped_out:
		_result_title.text = "EXTRACTED"
		_result_title.add_theme_color_override("font_color", Color("#FFC107"))
		_result_subtitle.text = "Emergency warp — returned to bastion safely."
	else:
		_result_title.text = "RIFT FAILED"
		_result_title.add_theme_color_override("font_color", Color("#FF4444"))
		_result_subtitle.text = "Crawler destroyed — forced extraction."

	_result_overlay.visible = true


func _on_result_continue() -> void:
	_result_overlay.visible = false
	rift_completed.emit(_result_won)


func _show_capture(glyph: GlyphInstance) -> void:
	_state = UIState.CAPTURE
	if _is_tutorial_rift():
		_show_tutorial_hint("capture", "Capture chance depends on battle speed. Finish faster for better odds!")
	## Sum recruit uses for the glyph's species
	var recruit_uses: int = _last_recruit_counts.get(glyph.species.id, 0) if glyph.species != null else 0
	var breakdown: Dictionary = CaptureCalculator.get_breakdown(
		_last_enemy_count, _last_turns, _capture_item_bonus, recruit_uses
	)
	_capture_popup.show_capture(glyph, breakdown["total"], breakdown)
	## Consume capture bonus after use (single-use per item description)
	_capture_item_bonus = 0.0
	_crawler_hud.remove_active_effect("capture_bonus")


func _is_squad_wiped() -> bool:
	if roster_state == null:
		return false
	for g: GlyphInstance in roster_state.active_squad:
		if not g.is_knocked_out:
			return false
	return true


func _apply_battle_loss_penalty() -> void:
	## GDD 8.13: Revive KO'd glyphs at 30%, take 15 hull damage, push back to previous room
	if roster_state != null:
		for g: GlyphInstance in roster_state.active_squad:
			if g.is_knocked_out:
				g.is_knocked_out = false
				g.current_hp = maxi(1, int(float(g.max_hp) * BATTLE_LOSS_REVIVE_PCT))
		squad_changed.emit()

	## Hull damage
	if dungeon_state != null and dungeon_state.crawler != null:
		dungeon_state.crawler.take_hull_damage(BATTLE_LOSS_HULL_DAMAGE)
		_crawler_hud.refresh()

		## If hull destroyed → forced extraction
		if dungeon_state.crawler.hull_hp <= 0:
			_warped_out = false
			_show_result(false)
			return

	## Push back to pre-combat room (enemy resets by staying uncleared)
	if _pre_combat_room_id != "" and dungeon_state != null and _pre_combat_room_id != dungeon_state.current_room_id:
		dungeon_state.current_room_id = _pre_combat_room_id
		_floor_map.set_current_room(_pre_combat_room_id)

	_state = UIState.EXPLORING


func _generate_scan_info(room_id: String) -> void:
	## Pre-generate species names and IDs for a scanned enemy room
	if data_loader == null or dungeon_state == null:
		return
	var template: RiftTemplate = dungeon_state.rift_template
	if template.wild_glyph_pool.is_empty():
		return

	var count: int = randi_range(1, 3)
	var names: Array[String] = []
	var species_ids: Array[String] = []
	for i: int in range(count):
		var species_id: String = template.wild_glyph_pool[randi() % template.wild_glyph_pool.size()]
		var species: GlyphSpecies = data_loader.get_species(species_id)
		if species != null:
			names.append(species.name)
			species_ids.append(species_id)

	if not names.is_empty():
		var room: Dictionary = dungeon_state._get_room(dungeon_state.current_floor, room_id)
		if not room.is_empty():
			room["scan_info"] = ", ".join(names)
			room["scan_species_ids"] = species_ids


func _generate_boss_scan_info(room_id: String) -> void:
	## Add boss name and species ID to scanned boss room
	if data_loader == null or dungeon_state == null:
		return
	var template: RiftTemplate = dungeon_state.rift_template
	var boss_def: BossDef = data_loader.get_boss(template.boss_id)
	if boss_def != null:
		var room: Dictionary = dungeon_state._get_room(dungeon_state.current_floor, room_id)
		if not room.is_empty():
			room["scan_info"] = boss_def.name
			room["scan_species_ids"] = [boss_def.species_id] as Array[String]


func _generate_wild_enemies(scan_species_ids: Array = []) -> Array[GlyphInstance]:
	var enemies: Array[GlyphInstance] = []
	if data_loader == null or dungeon_state == null:
		return enemies

	## Use scanned species if available (so fight matches the preview)
	var ids: Array[String] = []
	if not scan_species_ids.is_empty():
		for sid: Variant in scan_species_ids:
			ids.append(str(sid))
	else:
		var template: RiftTemplate = dungeon_state.rift_template
		if template.wild_glyph_pool.is_empty():
			return enemies
		var count: int = randi_range(1, 3)
		for i: int in range(count):
			ids.append(template.wild_glyph_pool[randi() % template.wild_glyph_pool.size()])

	for species_id: String in ids:
		var species: GlyphSpecies = data_loader.get_species(species_id)
		if species == null:
			continue
		var glyph: GlyphInstance = GlyphInstance.create_from_species(species, data_loader)
		glyph.calculate_stats()
		glyph.side = "enemy"
		enemies.append(glyph)

	return enemies


func _generate_boss(boss_def: BossDef) -> Array[GlyphInstance]:
	var squad: Array[GlyphInstance] = []
	if boss_def == null or data_loader == null:
		return squad

	## Multi-glyph boss squad
	if not boss_def.squad.is_empty():
		for entry: Dictionary in boss_def.squad:
			var sp: GlyphSpecies = data_loader.get_species(entry.get("species_id", ""))
			if sp == null:
				continue
			var g: GlyphInstance = GlyphInstance.new()
			g.species = sp
			g.is_boss = true
			g.side = "enemy"
			g.row_position = entry.get("row_position", "front")
			for tid: String in entry.get("technique_ids", []):
				var tech: TechniqueDef = data_loader.get_technique(tid)
				if tech != null:
					g.techniques.append(tech)
			if entry.get("mastered", false):
				g.mastery_bonus_applied = true
			g.calculate_stats()
			squad.append(g)
		return squad

	## Legacy single-species boss
	var boss_species: GlyphSpecies = data_loader.get_species(boss_def.species_id)
	if boss_species == null:
		return squad

	var boss: GlyphInstance = GlyphInstance.new()
	boss.species = boss_species
	boss.is_boss = true
	boss.side = "enemy"

	for tid: String in boss_def.phase1_technique_ids:
		var tech: TechniqueDef = data_loader.get_technique(tid)
		if tech != null:
			boss.techniques.append(tech)

	## Apply mastery-based stat scaling: each star = +2 all stats via bonus_*
	var stars: int = boss_def.mastery_stars
	if stars > 0:
		boss.bonus_hp = stars * 2
		boss.bonus_atk = stars * 2
		boss.bonus_def = stars * 2
		boss.bonus_spd = stars * 2
		boss.bonus_res = stars * 2
	boss.mastery_objectives = _build_boss_mastery(stars)
	boss.calculate_stats()
	squad.append(boss)

	return squad


func _build_boss_mastery(stars: int) -> Array[Dictionary]:
	## Build 3 dummy mastery objectives with the first N marked completed.
	## Used for boss display (star icons) without affecting real mastery logic.
	var objectives: Array[Dictionary] = []
	for i: int in range(3):
		objectives.append({"type": "boss_mastery", "completed": i < stars})
	return objectives


func _clear_current_room(history: String = "") -> void:
	## Mark the current room as cleared so re-entering doesn't retrigger events.
	## Stores the original type and a history string for display on the map.
	if dungeon_state == null:
		return
	var floor_idx: int = dungeon_state.current_floor
	if floor_idx >= dungeon_state.floors.size():
		return
	var floor_data: Dictionary = dungeon_state.floors[floor_idx]
	for room: Dictionary in floor_data.get("rooms", []):
		if room.get("id", "") == dungeon_state.current_room_id:
			room["cleared"] = true
			if not room.has("original_type"):
				room["original_type"] = room.get("type", "empty")
			if history != "":
				room["history"] = history
			break
	_floor_map.refresh_all()


func _pick_item() -> Dictionary:
	if data_loader == null or dungeon_state == null:
		return {}
	var all_items: Dictionary = data_loader.items
	if all_items.is_empty():
		return {}
	var keys: Array = all_items.keys()
	var item_id: String = keys[randi() % keys.size()]
	var item: ItemDef = data_loader.get_item(item_id)
	if item == null:
		return {}
	var added: bool = dungeon_state.crawler.add_item(item)
	return {"item": item, "full": not added}


## --- Repair picker ---

func _show_repair_picker() -> void:
	if roster_state == null or dungeon_state == null:
		return

	## Check energy first
	var cost: int = dungeon_state.crawler.get_ability_cost("field_repair")
	if dungeon_state.crawler.energy < cost:
		return

	## Build list of damaged squad members
	for child: Node in _repair_vbox.get_children():
		_repair_vbox.remove_child(child)
		child.queue_free()

	var header: Label = Label.new()
	header.text = "Field Repair — Pick a Glyph"
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color("#4CAF50"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_vbox.add_child(header)

	var has_targets: bool = false
	for g: GlyphInstance in roster_state.active_squad:
		if g.current_hp >= g.max_hp:
			continue  ## Already full HP, skip
		has_targets = true
		var btn: Button = Button.new()
		btn.name = "RepairButton_%s" % g.species.name.replace(" ", "")
		var heal_amount: int = maxi(1, int(float(g.max_hp) * 0.5))
		var status: String = "KO" if g.current_hp <= 0 else "%d/%d HP" % [g.current_hp, g.max_hp]
		btn.text = "%s  %s  (+%d HP, 50%%)" % [g.species.name, status, heal_amount]
		btn.custom_minimum_size = Vector2(0, 32)
		var glyph_ref: GlyphInstance = g
		btn.pressed.connect(func() -> void: _on_repair_target_selected(glyph_ref))
		_repair_vbox.add_child(btn)

	if not has_targets:
		var no_targets: Label = Label.new()
		no_targets.text = "All glyphs are at full HP."
		no_targets.add_theme_font_size_override("font_size", 13)
		no_targets.add_theme_color_override("font_color", Color("#888888"))
		no_targets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_repair_vbox.add_child(no_targets)

	var cancel_btn: Button = Button.new()
	cancel_btn.name = "CancelRepairButton"
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(_hide_repair_picker)
	_repair_vbox.add_child(cancel_btn)

	_state = UIState.POPUP
	_repair_overlay.visible = true


func _on_repair_target_selected(target: GlyphInstance) -> void:
	## Spend energy
	dungeon_state.use_crawler_ability("field_repair")

	## Heal 50% max HP
	var heal: int = maxi(1, int(float(target.max_hp) * 0.5))
	target.current_hp = mini(target.current_hp + heal, target.max_hp)
	## Always sync KO flag with HP
	target.is_knocked_out = target.current_hp <= 0

	_hide_repair_picker()
	_crawler_hud.refresh()
	squad_changed.emit()


func _hide_repair_picker() -> void:
	_repair_overlay.visible = false
	_state = UIState.EXPLORING


## --- Item swap picker ---

func _show_swap_picker(new_item: ItemDef, source: String) -> void:
	_swap_pending_item = new_item
	_swap_source = source

	for child: Node in _swap_vbox.get_children():
		_swap_vbox.remove_child(child)
		child.queue_free()

	var header: Label = Label.new()
	header.text = "Inventory Full!"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color("#FFD700"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swap_vbox.add_child(header)

	var found_label: Label = Label.new()
	found_label.text = "Found: %s" % new_item.name
	found_label.add_theme_font_size_override("font_size", 13)
	found_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	found_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	found_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_swap_vbox.add_child(found_label)

	var desc_label: Label = Label.new()
	desc_label.text = new_item.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color("#888888"))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_swap_vbox.add_child(desc_label)

	var sep: HSeparator = HSeparator.new()
	_swap_vbox.add_child(sep)

	var hint_label: Label = Label.new()
	hint_label.text = "Use or drop an item to make room:"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swap_vbox.add_child(hint_label)

	for item: ItemDef in dungeon_state.crawler.items:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_swap_vbox.add_child(row)

		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 1)
		row.add_child(info_col)

		var name_label: Label = Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 13)
		info_col.add_child(name_label)

		var item_desc: Label = Label.new()
		item_desc.text = item.description
		item_desc.add_theme_font_size_override("font_size", 10)
		item_desc.add_theme_color_override("font_color", Color("#AAAAAA"))
		item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(item_desc)

		var use_btn: Button = Button.new()
		use_btn.name = "UseButton_%s" % item.name.replace(" ", "")
		use_btn.text = "Use"
		use_btn.custom_minimum_size = Vector2(50, 28)
		var item_ref: ItemDef = item
		use_btn.pressed.connect(func() -> void: _on_swap_use_selected(item_ref))
		row.add_child(use_btn)

		var drop_btn: Button = Button.new()
		drop_btn.name = "DropButton_%s" % item.name.replace(" ", "")
		drop_btn.text = "Drop"
		drop_btn.custom_minimum_size = Vector2(50, 28)
		drop_btn.pressed.connect(func() -> void: _on_swap_drop_selected(item_ref))
		row.add_child(drop_btn)

	var leave_btn: Button = Button.new()
	leave_btn.name = "LeaveItButton"
	leave_btn.text = "Leave It"
	leave_btn.custom_minimum_size = Vector2(100, 30)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.pressed.connect(_on_swap_leave)
	_swap_vbox.add_child(leave_btn)

	_state = UIState.POPUP
	_swap_overlay.visible = true


func _on_swap_use_selected(use_item: ItemDef) -> void:
	var applied: bool = ItemPopup.apply_item(use_item, dungeon_state.crawler, roster_state)
	if not applied:
		return
	dungeon_state.crawler.use_item(use_item)
	## Now there's room — add the new item
	dungeon_state.crawler.add_item(_swap_pending_item)
	var item_name: String = _swap_pending_item.name
	_swap_pending_item = null
	_swap_overlay.visible = false
	_crawler_hud.refresh()

	if _swap_source == "puzzle":
		_state = UIState.EXPLORING
	else:
		_room_popup.show_result("Found: %s" % item_name, "Used %s to make room." % use_item.name)
		_state = UIState.POPUP


func _on_swap_drop_selected(drop_item: ItemDef) -> void:
	dungeon_state.crawler.use_item(drop_item)
	dungeon_state.crawler.add_item(_swap_pending_item)
	var item_name: String = _swap_pending_item.name
	_swap_pending_item = null
	_swap_overlay.visible = false
	_crawler_hud.refresh()

	if _swap_source == "puzzle":
		_state = UIState.EXPLORING
	else:
		_room_popup.show_result("Found: %s" % item_name, "Swapped items.")
		_state = UIState.POPUP


func _on_swap_leave() -> void:
	_swap_pending_item = null
	_swap_overlay.visible = false

	if _swap_source == "puzzle":
		_state = UIState.EXPLORING
	else:
		_room_popup.show_result("Left Behind", "Inventory full — item left behind.")
		_state = UIState.POPUP


## --- Puzzle helpers ---

func _launch_puzzle(room_data: Dictionary) -> void:
	## puzzle_type is pre-assigned by RiftGenerator; fallback to conduit if missing
	if not room_data.has("puzzle_type"):
		room_data["puzzle_type"] = "conduit"

	_state = UIState.PUZZLE
	var puzzle_type: String = room_data["puzzle_type"]

	match puzzle_type:
		"sequence":
			## Legacy — removed; fall through to conduit
			_puzzle_conduit.start(instant_mode)
		"conduit":
			_puzzle_conduit.start(instant_mode)
		"echo":
			if dungeon_state != null and dungeon_state.rift_template != null:
				## Persist the echo species so revisits show the same glyph
				if room_data.has("echo_species_id") and data_loader != null:
					var sp: GlyphSpecies = data_loader.get_species(room_data["echo_species_id"])
					if sp != null:
						var g: GlyphInstance = GlyphInstance.create_from_species(sp, data_loader)
						g.side = "enemy"
						_puzzle_echo.start_with_glyph(g)
					else:
						_puzzle_echo.start(dungeon_state.rift_template, data_loader, roster_state)
				else:
					_puzzle_echo.start(dungeon_state.rift_template, data_loader, roster_state)
				## Save the chosen species for future revisits
				if _puzzle_echo.get_echo_glyph() != null and _puzzle_echo.get_echo_glyph().species != null:
					room_data["echo_species_id"] = _puzzle_echo.get_echo_glyph().species.id
			else:
				_puzzle_conduit.start(instant_mode)
		"quiz":
			## Persist quiz species so revisits show the same question
			if room_data.has("quiz_correct_id") and room_data.has("quiz_choice_ids") and data_loader != null:
				var correct_sp: GlyphSpecies = data_loader.get_species(room_data["quiz_correct_id"])
				var choices: Array[GlyphSpecies] = []
				for cid: String in room_data["quiz_choice_ids"]:
					var sp: GlyphSpecies = data_loader.get_species(cid)
					if sp != null:
						choices.append(sp)
				if correct_sp != null and choices.size() >= 4:
					_puzzle_quiz.start_with_species(correct_sp, choices, instant_mode)
				else:
					_start_quiz_fresh(room_data)
			else:
				_start_quiz_fresh(room_data)


func _start_quiz_fresh(room_data: Dictionary) -> void:
	var glyph_pool: Array[String] = []
	if dungeon_state != null and dungeon_state.rift_template != null:
		for sid: String in dungeon_state.rift_template.wild_glyph_pool:
			glyph_pool.append(sid)
	_puzzle_quiz.start(data_loader, codex_state, instant_mode, glyph_pool)
	## Save the chosen species/choices for future revisits
	var correct: GlyphSpecies = _puzzle_quiz.get_correct_species()
	if correct != null:
		room_data["quiz_correct_id"] = correct.id
		var choice_ids: Array[String] = []
		for sp: GlyphSpecies in _puzzle_quiz._choices:
			choice_ids.append(sp.id)
		room_data["quiz_choice_ids"] = choice_ids


func _on_puzzle_completed(success: bool, reward_type: String, _reward_data: Variant) -> void:
	## Hide all puzzle overlays
	_puzzle_sequence.visible = false
	_puzzle_conduit.visible = false
	_puzzle_echo.visible = false
	_puzzle_quiz.visible = false

	if success:
		match reward_type:
			"item":
				var result: Dictionary = _pick_item()
				if result.get("full", false):
					_clear_current_room("Puzzle solved — found supplies!")
					_show_swap_picker(result["item"], "puzzle")
					return
				else:
					_clear_current_room("Puzzle solved — found supplies!")
			"codex_reveal":
				## Reveal already done in _on_conduit_success
				_clear_current_room("Puzzle solved — codex updated!")
			_:
				_clear_current_room("Puzzle solved.")
	else:
		## Failed or gave up — room stays as puzzle for retry
		pass

	_state = UIState.EXPLORING


func _on_echo_combat_requested(echo_glyph: GlyphInstance) -> void:
	_echo_battle_active = true
	_echo_glyph = echo_glyph
	_puzzle_echo.visible = false
	_state = UIState.COMBAT
	var enemies: Array[GlyphInstance] = [echo_glyph]
	combat_requested.emit(enemies, null)


func _show_capture_with_chance(glyph: GlyphInstance, chance: float) -> void:
	_state = UIState.CAPTURE
	_capture_popup.show_capture(glyph, chance)


func _on_conduit_success() -> void:
	## Do the reveal immediately so we can show the species name
	var species_name: String = _reveal_random_species()
	if species_name != "":
		_puzzle_conduit.set_reward_text("Discovered: %s" % species_name)
	else:
		_puzzle_conduit.set_reward_text("All species already discovered!")


func _reveal_random_species() -> String:
	## Discover a random undiscovered species, return its name
	if codex_state == null or data_loader == null:
		return ""
	var undiscovered: Array[String] = []
	for species_id: String in data_loader.species.keys():
		if not codex_state.is_species_discovered(species_id):
			undiscovered.append(species_id)
	if not undiscovered.is_empty():
		var pick: String = undiscovered[randi() % undiscovered.size()]
		codex_state.discover_species(pick)
		var species: GlyphSpecies = data_loader.species[pick]
		return species.name
	return ""


## --- Tutorial hint system (tutorial_01 only) ---

func _is_tutorial_rift() -> bool:
	if dungeon_state == null or dungeon_state.rift_template == null:
		return false
	return dungeon_state.rift_template.rift_id == "tutorial_01"


func _show_tutorial_hint(hint_id: String, text: String) -> void:
	if _tutorial_hints_shown.get(hint_id, false):
		return
	_tutorial_hints_shown[hint_id] = true
	if _tutorial_label == null:
		return
	_tutorial_label.text = text
	_tutorial_label.visible = true
	_tutorial_label.modulate = Color.WHITE
	if not instant_mode:
		var tween: Tween = create_tween()
		tween.tween_interval(4.0)
		tween.tween_property(_tutorial_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(_tutorial_label.set.bind("visible", false))


## --- GRB helpers (for MCP automation) ---

var grb_target_room: String = ""

func grb_move_to_target() -> String:
	if dungeon_state == null:
		return "no dungeon"
	if _state != UIState.EXPLORING:
		return "busy: %d" % _state
	var moved: bool = dungeon_state.move_to_room(grb_target_room)
	if not moved:
		return "cannot move to " + grb_target_room
	return "moved to " + grb_target_room


func grb_popup_action() -> String:
	if _state != UIState.POPUP:
		return "not in popup state: %d" % _state
	var rt: String = _room_popup.room_data.get("type", "")
	_on_popup_action(rt, _room_popup.room_data)
	return "action: " + rt


func grb_get_rooms() -> Array:
	if dungeon_state == null:
		return []
	var result: Array = []
	var floor_data: Dictionary = dungeon_state.floors[dungeon_state.current_floor]
	for room: Dictionary in floor_data.get("rooms", []):
		result.append({
			"id": room.get("id", ""),
			"type": room.get("type", "???") if room.get("revealed", false) else "???",
			"revealed": room.get("revealed", false),
			"cleared": room.get("cleared", false),
			"current": room.get("id", "") == dungeon_state.current_room_id,
		})
	return result


