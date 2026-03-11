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

## Lore objects found in empty rooms (GDD 7.8)
const RIFT_LORE: Dictionary = {
	"tutorial_01": [
		"A cracked data terminal flickers weakly. The last entry reads: \"Rift stabilizers failing. Evacuate sector 7.\"",
		"Scratches on the wall form crude tally marks — someone was counting days.",
		"A shattered containment pod lies on its side. Whatever was inside is long gone.",
	],
	"minor_01": [
		"A faded mural depicts glyphs and humans working side by side. The paint is centuries old.",
		"A broken calibration device hums faintly. Its display reads \"IRONBARK — CONTAINMENT FAILED.\"",
		"Stone fragments arranged in a circle. Some kind of ritual site, or maybe just rubble.",
		"A data fragment crackles to life: \"...ground-type signatures increasing. The rift is resonating with the bedrock itself...\"",
	],
	"minor_02": [
		"Condensation drips from the ceiling in rhythmic patterns, like a heartbeat.",
		"A waterlogged journal entry: \"The Vortail was here before the rift opened. It didn't come through — it was waiting.\"",
		"Crystal formations along the walls pulse with a faint blue light. They feel warm to the touch.",
		"A corroded monitoring station. The last reading shows water pressure readings off the scale.",
	],
	"minor_03": [
		"Scorch marks radiate outward from a central point. Something discharged here — violently.",
		"A severed power cable sparks intermittently. The air smells of ozone.",
		"A researcher's note: \"The electric signatures aren't random. They pulse in patterns. Almost like... communication.\"",
		"Melted metal pooled and solidified into strange shapes. The heat must have been extraordinary.",
	],
	"standard_01": [
		"A massive claw mark gouges the reinforced wall. Whatever made this was enormous.",
		"Fragments of a containment field generator. The shielding was rated for T2 glyphs — clearly insufficient.",
		"An audio log crackles: \"Stormfang isn't just powerful. It's intelligent. It's learning our patrol patterns.\"",
		"The air crackles with residual static. Your crawler's instruments spike briefly.",
	],
	"standard_02": [
		"The floor has been reshaped — pushed upward into ridges by some tremendous force from below.",
		"Fossilized root structures thread through the walls. They predate the rift by millennia.",
		"A geological survey marker, bent at an impossible angle: \"TERRADON NESTING ZONE — DO NOT DISTURB.\"",
		"The stone here is warm. Not from heat — from something living deep within it.",
	],
	"major_01": [
		"Reality itself seems thin here. The walls shimmer, and sometimes you can see... somewhere else.",
		"A warning beacon, still active: \"RIFTMAW DETECTED. DIMENSIONAL INSTABILITY CRITICAL. ALL PERSONNEL EVACUATE.\"",
		"Floating debris hangs motionless in mid-air. Gravity has forgotten this room.",
		"A researcher's final log: \"The void isn't empty. It's full. Full of things that want to come through.\"",
		"Cracks in space itself — tiny fractures through which darkness seeps like liquid.",
	],
	"apex_01": [
		"The walls are made of something that isn't quite matter. Your instruments can't classify it.",
		"A recording, barely audible: \"The Nullweaver doesn't destroy. It unmakes. There's a difference.\"",
		"Echoes of sounds that haven't happened yet reverberate through the chamber.",
		"The null energy here is so dense it's visible — a shimmering absence of light.",
		"A final message, carved into unreality itself: \"They were here before the rifts. The rifts are doors, not wounds.\"",
	],
}
## Generic fallback lore for rifts not in the dictionary
const GENERIC_LORE: Array[String] = [
	"Dust motes drift in still air. This room has been undisturbed for a long time.",
	"Faint scratches on the floor suggest something was dragged through here.",
	"The walls are scorched in places. Evidence of an old battle, perhaps.",
]

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
var _damage_boost_active: bool = false
var _damage_boost_amounts: Dictionary = {}  ## GlyphInstance → int (ATK added)

## Last combat stats (for capture calculation)
var _last_enemy_count: int = 1
var _last_turns: int = 3
var _last_recruit_counts: Dictionary = {}  ## species_id → recruit uses
var _last_ko_list: Array[GlyphInstance] = []  ## KO order (first KO'd → last KO'd)
var _boss_capture_pending: bool = false  ## Show rift result after boss capture dismissal

var _background: ColorRect = null
var _floor_map: FloorMap = null
var _crawler_hud: CrawlerHUD = null
var _room_popup: RoomPopup = null
var _capture_popup: CapturePopup = null
var _item_popup: ItemPopup = null
var _rift_name_label: Label = null
var _rift_info_btn: Button = null
var _rift_info_popup: PanelContainer = null
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

var _forced_repair: bool = false  ## When true, repair picker requires at least 1 heal before closing
var _forced_repair_healed: bool = false  ## Tracks whether player healed at least once in forced mode

var _walk_queue: Array[String] = []
var _walking_path: bool = false  ## True during multi-room pathfinding walk
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


func on_combat_finished(won: bool, enemies: Array[GlyphInstance], turns: int = 3, recruit_counts: Dictionary = {}, was_forfeit: bool = false, ko_list: Array[GlyphInstance] = []) -> void:
	## Called by parent after combat ends
	_clear_damage_boost()
	_last_enemy_count = maxi(1, enemies.size())
	_last_turns = turns
	_last_recruit_counts = recruit_counts
	_last_ko_list = ko_list

	## Consume ward charm (single-use per battle)
	if _ward_charm_active:
		_ward_charm_active = false
		_crawler_hud.remove_active_effect("status_immunity")
		if _squad_overlay != null and roster_state != null and not roster_state.active_squad.is_empty():
			_squad_overlay.clear_glyph_effect(roster_state.active_squad[0])

	## Handle echo battle flow
	if _echo_battle_active:
		_echo_battle_active = false
		if won and _echo_glyph != null:
			## Free capture (100% chance) on echo win
			_clear_current_room("Defeated echo glyph.")
			## Set memory fragment for lore display on capture
			_capture_popup.memory_fragment = _puzzle_echo.get_memory_fragment()
			_show_capture_with_chance(_echo_glyph, 1.0)
		elif was_forfeit:
			## Fled echo — room stays, no penalty
			_room_popup.hide_popup()
			_state = UIState.EXPLORING
		else:
			## Echo loss — apply loss penalty (forced heal or extraction)
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
		if was_forfeit:
			## Fled — room stays uncleared, no penalty, return to map
			_state = UIState.EXPLORING
		elif was_boss:
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

	## Wild encounter — offer capture for best candidate (BUG-030)
	## Priority: highest recruit count, then last KO'd
	if enemies.size() > 0:
		var candidates: Array[GlyphInstance] = []
		for enemy: GlyphInstance in enemies:
			if not enemy.is_boss:
				candidates.append(enemy)
		if not candidates.is_empty():
			var best: GlyphInstance = _pick_capture_target(candidates)
			_show_capture(best)
			return

	## No capture — back to exploring
	_state = UIState.EXPLORING
	_room_popup.hide_popup()


func _pick_capture_target(candidates: Array[GlyphInstance]) -> GlyphInstance:
	## Sort by: recruit count desc, then KO order desc (last KO'd first)
	var best: GlyphInstance = candidates[0]
	var best_recruit: int = _last_recruit_counts.get(best.species.id, 0) if best.species != null else 0
	var best_ko_idx: int = _last_ko_list.find(best)

	for i: int in range(1, candidates.size()):
		var c: GlyphInstance = candidates[i]
		var c_recruit: int = _last_recruit_counts.get(c.species.id, 0) if c.species != null else 0
		var c_ko_idx: int = _last_ko_list.find(c)

		if c_recruit > best_recruit:
			best = c
			best_recruit = c_recruit
			best_ko_idx = c_ko_idx
		elif c_recruit == best_recruit and c_ko_idx > best_ko_idx:
			best = c
			best_recruit = c_recruit
			best_ko_idx = c_ko_idx
	return best


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

	## Rift name + info button (top center, below HUD)
	var rift_header: HBoxContainer = HBoxContainer.new()
	rift_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rift_header.offset_top = 48.0
	rift_header.offset_bottom = 70.0
	rift_header.alignment = BoxContainer.ALIGNMENT_CENTER
	rift_header.add_theme_constant_override("separation", 6)
	rift_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rift_header)

	_rift_name_label = Label.new()
	_rift_name_label.name = "RiftNameLabel"
	_rift_name_label.add_theme_font_size_override("font_size", 16)
	_rift_name_label.add_theme_color_override("font_color", Color("#FFD700"))
	_rift_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rift_header.add_child(_rift_name_label)

	_rift_info_btn = Button.new()
	_rift_info_btn.name = "RiftInfoButton"
	_rift_info_btn.text = "(i)"
	_rift_info_btn.custom_minimum_size = Vector2(28, 22)
	_rift_info_btn.add_theme_font_size_override("font_size", 12)
	_rift_info_btn.pressed.connect(_toggle_rift_info)
	rift_header.add_child(_rift_info_btn)

	_rift_info_popup = _build_rift_info_popup()
	add_child(_rift_info_popup)

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
	swap_panel.custom_minimum_size = Vector2(340, 240)
	swap_panel.offset_left = -170.0
	swap_panel.offset_right = 170.0
	swap_panel.offset_top = -200.0
	swap_panel.offset_bottom = 200.0
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


func _build_rift_info_popup() -> PanelContainer:
	var popup: PanelContainer = PanelContainer.new()
	popup.name = "RiftInfoPopup"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.offset_left = -160.0
	popup.offset_right = 160.0
	popup.offset_top = -100.0
	popup.offset_bottom = 100.0
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_STOP

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.border_color = Color(0.5, 0.5, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	popup.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	popup.add_child(vbox)

	var title: Label = Label.new()
	title.name = "InfoTitle"
	title.text = "Rift Info"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var details: Label = Label.new()
	details.name = "InfoDetails"
	details.add_theme_font_size_override("font_size", 12)
	details.add_theme_color_override("font_color", Color("#CCCCCC"))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(details)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 28)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func() -> void: popup.visible = false)
	vbox.add_child(close_btn)

	return popup


func _toggle_rift_info() -> void:
	if _rift_info_popup == null or dungeon_state == null:
		return
	if _rift_info_popup.visible:
		_rift_info_popup.visible = false
		return

	var template: RiftTemplate = dungeon_state.rift_template
	if template == null:
		return

	## Build info text
	var lines: PackedStringArray = PackedStringArray()
	lines.append(template.name)
	lines.append("Tier: %s" % template.tier.capitalize())
	lines.append("Floors: %d" % template.floors.size())
	lines.append("Hazard Damage: %d" % template.hazard_damage)

	## Boss info
	if data_loader != null:
		var boss_def: BossDef = data_loader.get_boss(template.rift_id)
		if boss_def != null:
			var boss_species: GlyphSpecies = data_loader.get_species(boss_def.species_id)
			if boss_species != null:
				var emoji: String = Affinity.EMOJI.get(boss_species.affinity, "")
				lines.append("Boss: %s %s" % [boss_species.name, emoji])

	## Wild pool summary
	if not template.wild_glyph_pool.is_empty():
		lines.append("Wild Species: %d types" % template.wild_glyph_pool.size())

	var title_label: Label = _rift_info_popup.get_child(0).get_child(0) as Label
	title_label.text = template.name

	var details_label: Label = _rift_info_popup.get_child(0).get_child(1) as Label
	details_label.text = "\n".join(lines).substr(lines[0].length() + 1)

	_rift_info_popup.visible = true


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

	## Re-engage current room if not cleared and interactable
	if room_id == dungeon_state.current_room_id:
		_re_engage_current_room()
		return

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


func _re_engage_current_room() -> void:
	var room: Dictionary = dungeon_state.get_current_room()
	if room.is_empty():
		return
	if room.get("cleared", false):
		return
	var room_type: String = room.get("type", "empty")
	if room_type not in ["boss", "puzzle", "enemy"]:
		return
	## Re-show the popup with same logic as _on_room_entered
	_state = UIState.POPUP
	var extra: String = ""
	if room_type == "boss" and data_loader != null:
		var boss_def: BossDef = data_loader.get_boss(dungeon_state.rift_template.rift_id)
		if boss_def != null:
			extra = boss_def.species_id
	_room_popup.show_room(room, extra)


func _walk_path(path: Array[String]) -> void:
	## Walk along a BFS path, stopping early if a room triggers a blocking event.
	if instant_mode:
		## Synchronous walk — preserves existing test behavior
		_walking_path = path.size() > 1
		for room_id: String in path:
			if _state != UIState.EXPLORING:
				break
			_pre_combat_room_id = dungeon_state.current_room_id
			if not dungeon_state.move_to_room(room_id):
				break
		_walking_path = false
		return

	## Animated walk
	_walk_queue = []
	for rid: String in path:
		_walk_queue.append(rid)
	_walking_path = path.size() > 1
	_state = UIState.MOVING
	_walk_next_step()


func _walk_next_step() -> void:
	if _walk_queue.is_empty():
		_walking_path = false
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

	## Skip popups for non-actionable rooms (start)
	if room_type == "start":
		return

	## Empty rooms: show lore object on first visit (50% chance)
	## Only trigger on direct moves (not during multi-room pathfinding walk)
	if room_type == "empty":
		if not _walking_path and not room.get("lore_shown", false) and randi() % 2 == 0:
			room["lore_shown"] = true
			var lore_text: String = _get_lore_text()
			if lore_text != "":
				_state = UIState.POPUP
				_room_popup.show_result("Lore Fragment", lore_text)
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
				extra = boss_def.species_id
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
			## Store enemy species on room so it shows names after battle loss (BUG-028)
			if scan_ids.is_empty() and not enemies.is_empty():
				var species_ids: Array[String] = []
				for e: GlyphInstance in enemies:
					if e.species != null:
						species_ids.append(e.species.id)
				if not species_ids.is_empty():
					room_data_local["scan_species_ids"] = species_ids
					var names: PackedStringArray = PackedStringArray()
					for sid: String in species_ids:
						var sp: GlyphSpecies = data_loader.get_species(sid) if data_loader != null else null
						names.append(sp.name if sp != null else sid)
					room_data_local["scan_info"] = ", ".join(names)
			_apply_damage_boost()
			combat_requested.emit(enemies, null)
		"boss":
			_state = UIState.COMBAT
			var boss_data: BossDef = null
			if data_loader != null:
				boss_data = data_loader.get_boss(dungeon_state.rift_template.rift_id)
			var boss_squad: Array[GlyphInstance] = _generate_boss(boss_data)
			_apply_damage_boost()
			combat_requested.emit(boss_squad, boss_data)
		"cache":
			if room_data_local.get("cleared", false):
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
		"hidden":
			if room_data_local.get("cleared", false):
				_state = UIState.EXPLORING
			else:
				var result: Dictionary = _pick_item()
				_clear_current_room("Found hidden cache!")
				## Hidden rooms also restore 15 hull HP as bonus
				var hull_bonus: int = 15
				if dungeon_state != null and dungeon_state.crawler != null:
					var c: CrawlerState = dungeon_state.crawler
					var healed: int = mini(hull_bonus, c.max_hull_hp - c.hull_hp)
					c.hull_hp = mini(c.hull_hp + hull_bonus, c.max_hull_hp)
					if healed > 0:
						c.hull_changed.emit(c.hull_hp, c.max_hull_hp)
				if result.get("full", false):
					_show_swap_picker(result["item"], "cache")
					return
				elif result.get("item") != null:
					var found_item: ItemDef = result["item"]
					_room_popup.show_result("Hidden Cache: %s" % found_item.name, "%s\n+%d Hull HP restored!" % [found_item.description, hull_bonus])
				else:
					_room_popup.show_result("Hidden Cache", "+%d Hull HP restored!" % hull_bonus)
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

	if ability_name == "scan":
		## Generate scan info for adjacent rooms that were already revealed
		## (room_revealed only fires for newly revealed rooms)
		_scan_already_revealed_rooms()
		if not instant_mode:
			_play_scan_ripple()

	_floor_map.refresh_all()


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
			if _squad_overlay != null:
				_squad_overlay.set_glyph_effect(target, "\U0001f6e1", "Ward: blocks next status effect")
		_crawler_hud.add_active_effect("status_immunity",
			"Ward Charm",
			"Next status effect on %s will be blocked." % (
				roster_state.active_squad[0].species.name if roster_state != null and not roster_state.active_squad.is_empty() else "first glyph"
			))
	elif item.effect_type == "reveal_floor":
		## Reveal all rooms on current floor
		if dungeon_state != null:
			var floor_data: Dictionary = dungeon_state.floors[dungeon_state.current_floor]
			for room: Dictionary in floor_data.get("rooms", []):
				room["revealed"] = true
				room["visible"] = true
			_floor_map.refresh_all()
		_crawler_hud.add_active_effect("reveal_floor",
			"Rift Beacon", "All rooms on this floor revealed.")
	elif item.effect_type == "damage_boost":
		_damage_boost_active = true
		_crawler_hud.add_active_effect("damage_boost",
			"Affinity Prism +50%", "Next battle: all attacks deal +50% damage.")
	elif item.effect_type == "hazard_immunity":
		if dungeon_state != null and dungeon_state.crawler != null:
			dungeon_state.crawler.hazard_shield_active = true
		_crawler_hud.add_active_effect("hazard_immunity",
			"Hull Shield", "Next hazard room damage blocked.")
	_crawler_hud.refresh()
	squad_changed.emit()


## --- Helpers ---


func _apply_damage_boost() -> void:
	if not _damage_boost_active or roster_state == null:
		return
	_damage_boost_amounts.clear()
	for g: GlyphInstance in roster_state.active_squad:
		var boost: int = int(float(g.atk) * 0.5)
		g.atk += boost
		_damage_boost_amounts[g] = boost
	_damage_boost_active = false
	_crawler_hud.remove_active_effect("damage_boost")


func _clear_damage_boost() -> void:
	for g: Variant in _damage_boost_amounts:
		var glyph: GlyphInstance = g as GlyphInstance
		if glyph != null:
			glyph.atk -= _damage_boost_amounts[g]
	_damage_boost_amounts.clear()


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
	_capture_popup.memory_fragment = ""
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
	## Battle loss: no free revives. Player must spend energy to heal via forced repair picker.
	## If not enough energy for even one repair → emergency warp out.

	## Push back to pre-combat room (enemy resets by staying uncleared)
	if _pre_combat_room_id != "" and dungeon_state != null and _pre_combat_room_id != dungeon_state.current_room_id:
		dungeon_state.current_room_id = _pre_combat_room_id
		_floor_map.set_current_room(_pre_combat_room_id)

	## Check if player has energy to heal at least one glyph
	var repair_cost: int = 10
	if dungeon_state != null and dungeon_state.crawler != null:
		repair_cost = dungeon_state.crawler.get_ability_cost("field_repair")

	var has_damaged: bool = _has_damaged_glyphs()
	if not has_damaged:
		## Everyone is at full HP somehow — just return to exploring
		_state = UIState.EXPLORING
		return

	if dungeon_state != null and dungeon_state.crawler != null and dungeon_state.crawler.energy < repair_cost:
		## Not enough energy for repair → emergency warp
		_warped_out = true
		_show_result(false)
		return

	## Force open repair picker — player must heal at least one glyph
	_show_repair_picker(true)


func _has_damaged_glyphs() -> bool:
	## Check if any squad or bench glyphs need healing
	if roster_state == null:
		return false
	for g: GlyphInstance in roster_state.active_squad:
		if g.current_hp < g.max_hp:
			return true
	for g: GlyphInstance in rift_pool:
		if g not in roster_state.active_squad and g.current_hp < g.max_hp:
			return true
	return false


func _get_lore_text() -> String:
	## Pick a random lore fragment for the current rift
	if dungeon_state == null or dungeon_state.rift_template == null:
		return ""
	var rift_id: String = dungeon_state.rift_template.rift_id
	var lore_pool: Array = RIFT_LORE.get(rift_id, GENERIC_LORE)
	if lore_pool.is_empty():
		lore_pool = GENERIC_LORE
	return lore_pool[randi() % lore_pool.size()]


func _get_boss_affinity() -> String:
	## Look up the boss's affinity from template → boss_def → species
	if data_loader == null or dungeon_state == null:
		return ""
	var template: RiftTemplate = dungeon_state.rift_template
	var boss_def: BossDef = data_loader.get_boss(template.rift_id)
	if boss_def == null:
		return ""
	var boss_species: GlyphSpecies = data_loader.get_species(boss_def.species_id)
	if boss_species == null:
		return ""
	return boss_species.affinity


func _get_filtered_pool() -> Array[String]:
	## Filter wild_glyph_pool by enemy_tier_pool, then weight boss-affinity species 2x
	if data_loader == null or dungeon_state == null:
		return [] as Array[String]
	var template: RiftTemplate = dungeon_state.rift_template
	if template.wild_glyph_pool.is_empty():
		return [] as Array[String]

	## Filter by tier
	var filtered: Array[String] = []
	for sid: String in template.wild_glyph_pool:
		var species: GlyphSpecies = data_loader.get_species(sid)
		if species != null and species.tier in template.enemy_tier_pool:
			filtered.append(sid)
	if filtered.is_empty():
		return [] as Array[String]

	## Weight boss-affinity species 2x
	var boss_aff: String = _get_boss_affinity()
	var weighted: Array[String] = []
	for sid: String in filtered:
		weighted.append(sid)
		var species: GlyphSpecies = data_loader.get_species(sid)
		if species != null and species.affinity == boss_aff:
			weighted.append(sid)  ## 2x weight
	return weighted


func _get_enemy_count() -> int:
	## Floor-scaled enemy count: early floors 1-2, late floors 2-3
	if dungeon_state == null:
		return randi_range(1, 3)
	var total_floors: int = dungeon_state.rift_template.floors.size()
	var progress: float = float(dungeon_state.current_floor) / float(maxi(total_floors - 1, 1))
	if progress < 0.5:
		return randi_range(1, 2)
	else:
		return randi_range(2, 3)


func _pick_enemy_species(count: int) -> Array[String]:
	## Pick species with uniqueness bias from filtered+weighted pool
	var pool: Array[String] = _get_filtered_pool()
	if pool.is_empty():
		return [] as Array[String]

	var picked: Array[String] = []
	for i: int in range(count):
		var choice: String = pool[randi() % pool.size()]
		## Retry up to 3 times to avoid duplicates
		for _retry: int in range(3):
			if choice in picked:
				choice = pool[randi() % pool.size()]
			else:
				break
		picked.append(choice)
	return picked


func _scan_already_revealed_rooms() -> void:
	## For rooms adjacent to the player that were already revealed before scan,
	## generate scan info if they don't have it yet.
	if dungeon_state == null:
		return
	for room: Dictionary in dungeon_state.get_adjacent_rooms():
		var room_id: String = room.get("id", "")
		var room_type: String = room.get("type", "")
		if room.get("scan_species_ids", []).is_empty():
			if room_type == "enemy":
				_generate_scan_info(room_id)
			elif room_type == "boss":
				_generate_boss_scan_info(room_id)


func _generate_scan_info(room_id: String) -> void:
	## Pre-generate species names and IDs for a scanned enemy room
	if data_loader == null or dungeon_state == null:
		return
	var template: RiftTemplate = dungeon_state.rift_template
	if template.wild_glyph_pool.is_empty():
		return

	var count: int = _get_enemy_count()
	var species_ids: Array[String] = _pick_enemy_species(count)
	var names: Array[String] = []
	for species_id: String in species_ids:
		var species: GlyphSpecies = data_loader.get_species(species_id)
		if species != null:
			names.append(species.name)

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
		var count: int = _get_enemy_count()
		ids = _pick_enemy_species(count)
		if ids.is_empty():
			return enemies

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

func _show_repair_picker(forced: bool = false) -> void:
	if roster_state == null or dungeon_state == null:
		return

	## Track forced mode state
	if forced and not _forced_repair:
		_forced_repair = true
		_forced_repair_healed = false

	## Check energy first (voluntary repair only)
	var cost: int = dungeon_state.crawler.get_ability_cost("field_repair")
	if not _forced_repair and dungeon_state.crawler.energy < cost:
		return

	## Build list of damaged squad members
	for child: Node in _repair_vbox.get_children():
		_repair_vbox.remove_child(child)
		child.queue_free()

	var header: Label = Label.new()
	if _forced_repair:
		header.text = "Battle Lost — Heal a Glyph to Continue"
		header.add_theme_color_override("font_color", Color("#FF6B6B"))
	else:
		header.text = "Field Repair — Pick a Glyph"
		header.add_theme_color_override("font_color", Color("#4CAF50"))
	header.add_theme_font_size_override("font_size", 15)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_vbox.add_child(header)

	## Show energy cost info
	if _forced_repair:
		var info: Label = Label.new()
		info.text = "Each heal costs %d energy (you have %d)" % [cost, dungeon_state.crawler.energy]
		info.add_theme_font_size_override("font_size", 12)
		info.add_theme_color_override("font_color", Color("#AAAAAA"))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_repair_vbox.add_child(info)

	var has_targets: bool = false
	for g: GlyphInstance in roster_state.active_squad:
		if g.current_hp >= g.max_hp:
			continue
		has_targets = true
		_repair_vbox.add_child(_make_repair_button(g))

	## Bench glyphs (in rift_pool but not active_squad)
	var bench_damaged: Array[GlyphInstance] = []
	for g: GlyphInstance in rift_pool:
		if g not in roster_state.active_squad and g.current_hp < g.max_hp:
			bench_damaged.append(g)
	if not bench_damaged.is_empty():
		var sep: Label = Label.new()
		sep.text = "— Bench —"
		sep.add_theme_font_size_override("font_size", 12)
		sep.add_theme_color_override("font_color", Color("#888888"))
		sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_repair_vbox.add_child(sep)
		for g: GlyphInstance in bench_damaged:
			has_targets = true
			_repair_vbox.add_child(_make_repair_button(g))

	if not has_targets:
		var no_targets: Label = Label.new()
		no_targets.text = "All glyphs are at full HP."
		no_targets.add_theme_font_size_override("font_size", 13)
		no_targets.add_theme_color_override("font_color", Color("#888888"))
		no_targets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_repair_vbox.add_child(no_targets)

	## In forced mode: show Done button only after at least 1 heal; no Cancel
	## In voluntary mode: show Cancel button
	if _forced_repair:
		if _forced_repair_healed:
			var done_btn: Button = Button.new()
			done_btn.name = "DoneRepairButton"
			done_btn.text = "Done"
			done_btn.custom_minimum_size = Vector2(80, 28)
			done_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			done_btn.pressed.connect(_hide_repair_picker)
			_repair_vbox.add_child(done_btn)
	else:
		var cancel_btn: Button = Button.new()
		cancel_btn.name = "CancelRepairButton"
		cancel_btn.text = "Cancel"
		cancel_btn.custom_minimum_size = Vector2(80, 28)
		cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cancel_btn.pressed.connect(_hide_repair_picker)
		_repair_vbox.add_child(cancel_btn)

	_state = UIState.POPUP
	_repair_overlay.visible = true


func _make_repair_button(g: GlyphInstance) -> Button:
	var btn: Button = Button.new()
	btn.name = "RepairButton_%s" % g.species.name.replace(" ", "")
	var heal_amount: int = maxi(1, int(float(g.max_hp) * 0.5))
	var status: String = "KO" if g.current_hp <= 0 else "%d/%d HP" % [g.current_hp, g.max_hp]
	btn.text = "%s  %s  (+%d HP, 50%%)" % [g.species.name, status, heal_amount]
	btn.custom_minimum_size = Vector2(0, 32)
	var glyph_ref: GlyphInstance = g
	btn.pressed.connect(func() -> void: _on_repair_target_selected(glyph_ref))
	return btn


func _on_repair_target_selected(target: GlyphInstance) -> void:
	## Spend energy
	dungeon_state.use_crawler_ability("field_repair")

	## Heal 50% max HP
	var heal: int = maxi(1, int(float(target.max_hp) * 0.5))
	target.current_hp = mini(target.current_hp + heal, target.max_hp)
	## Always sync KO flag with HP
	target.is_knocked_out = target.current_hp <= 0

	## Track forced repair progress
	if _forced_repair:
		_forced_repair_healed = true

	_crawler_hud.refresh()
	squad_changed.emit()

	## Stay open if there are more damaged glyphs (squad + bench) and enough energy
	var cost: int = dungeon_state.crawler.get_ability_cost("field_repair")
	var has_damaged: bool = false
	for g: GlyphInstance in rift_pool:
		if g.current_hp < g.max_hp:
			has_damaged = true
			break
	if has_damaged and dungeon_state.crawler.energy >= cost:
		_show_repair_picker()  ## Rebuild with updated HP values
	elif _forced_repair:
		## No more energy or targets — close forced picker
		_hide_repair_picker()
	else:
		_hide_repair_picker()


func _hide_repair_picker() -> void:
	_forced_repair = false
	_forced_repair_healed = false
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

	var swap_scroll: ScrollContainer = ScrollContainer.new()
	swap_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	swap_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_swap_vbox.add_child(swap_scroll)

	var item_list: VBoxContainer = VBoxContainer.new()
	item_list.add_theme_constant_override("separation", 6)
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_scroll.add_child(item_list)

	for item: ItemDef in dungeon_state.crawler.items:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		item_list.add_child(row)

		row.add_child(ItemPopup.create_item_icon(item))

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
		item_desc.max_lines_visible = 2
		item_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	## Apply passive effects (same as _on_item_used)
	_on_item_used(use_item)
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
	_apply_damage_boost()
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
		## All species discovered — give an item instead of nothing
		var result: Dictionary = _pick_item()
		if not result.is_empty():
			var item: ItemDef = result["item"]
			if result["full"]:
				_puzzle_conduit.set_reward_text("Conduit resonance: %s (inventory full!)" % item.name)
			else:
				_puzzle_conduit.set_reward_text("Conduit resonance: found %s!" % item.name)
		else:
			_puzzle_conduit.set_reward_text("The conduit hums quietly...")


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


