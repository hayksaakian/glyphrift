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

enum UIState {
	EXPLORING,
	POPUP,
	COMBAT,
	CAPTURE,
	FLOOR_TRANSITION,
	RESULT,
	PUZZLE,
}

var dungeon_state: DungeonState = null
var data_loader: Node = null  ## Injectable DataLoader
var _state: UIState = UIState.EXPLORING

var roster_state: RosterState = null  ## Injectable — for item use
var codex_state: CodexState = null  ## Injectable — for conduit reveal reward

## Puzzle overlays
var _puzzle_sequence: PuzzleSequence = null
var _puzzle_conduit: PuzzleConduit = null
var _puzzle_echo: PuzzleEcho = null
var _echo_battle_active: bool = false
var _echo_glyph: GlyphInstance = null

## Repair picker
var _repair_overlay: ColorRect = null
var _repair_vbox: VBoxContainer = null

var _background: ColorRect = null
var _floor_map: FloorMap = null
var _crawler_hud: CrawlerHUD = null
var _room_popup: RoomPopup = null
var _capture_popup: CapturePopup = null
var _item_popup: ItemPopup = null
var _floor_label: Label = null
var _floor_overlay: ColorRect = null
var _floor_overlay_label: Label = null
var _result_overlay: ColorRect = null
var _result_title: Label = null
var _result_subtitle: Label = null
var _result_continue: Button = null
var _result_won: bool = false
var _warped_out: bool = false

var _dungeon_connections: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene_tree()
	_connect_internal_signals()


func start_rift(p_dungeon_state: DungeonState) -> void:
	dungeon_state = p_dungeon_state
	_connect_dungeon_signals()

	## Setup CrawlerHUD
	_crawler_hud.setup(dungeon_state.crawler)
	_crawler_hud.refresh()

	## Build initial floor
	_rebuild_floor()
	_state = UIState.EXPLORING


func get_ui_state() -> UIState:
	return _state


func on_combat_finished(won: bool, enemies: Array[GlyphInstance]) -> void:
	## Called by parent after combat ends

	## Handle echo battle flow
	if _echo_battle_active:
		_echo_battle_active = false
		if won and _echo_glyph != null:
			## Free capture (100% chance) on echo win
			_clear_current_room("Defeated echo glyph.")
			_show_capture_with_chance(_echo_glyph, 1.0)
		else:
			## Loss or no echo glyph — just clear and return
			_clear_current_room("Echo faded away.")
			if _is_squad_wiped():
				_warped_out = false
				_show_result(false)
			else:
				_state = UIState.EXPLORING
		_echo_glyph = null
		return

	if not won:
		_room_popup.hide_popup()
		## Check if entire squad is wiped — force extraction
		if _is_squad_wiped():
			_warped_out = false
			_show_result(false)
		else:
			_state = UIState.EXPLORING
		return

	## Mark current room as cleared so it doesn't retrigger
	_clear_current_room("Defeated wild glyphs.")

	## Check if this was a boss fight — winning means rift complete
	var was_boss: bool = false
	for enemy: GlyphInstance in enemies:
		if enemy.is_boss:
			was_boss = true
			break

	if was_boss:
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

	## Room popup (centered, hidden)
	_room_popup = RoomPopup.new()
	_room_popup.name = "RoomPopup"
	_room_popup.set_anchors_preset(Control.PRESET_CENTER)
	_room_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_room_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
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

	## Floor transition overlay (full screen, hidden)
	_floor_overlay = ColorRect.new()
	_floor_overlay.name = "FloorOverlay"
	_floor_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_overlay.color = Color(0, 0, 0, 0)
	_floor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_overlay.visible = false
	add_child(_floor_overlay)

	_floor_overlay_label = Label.new()
	_floor_overlay_label.set_anchors_preset(Control.PRESET_CENTER)
	_floor_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_overlay_label.add_theme_font_size_override("font_size", 28)
	_floor_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	_floor_overlay.add_child(_floor_overlay_label)

	## Result overlay (rift complete / failed)
	_result_overlay = ColorRect.new()
	_result_overlay.name = "ResultOverlay"
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.color = Color(0, 0, 0, 0.85)
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
	_result_continue.text = "Continue"
	_result_continue.custom_minimum_size = Vector2(140, 40)
	_result_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result_continue.pressed.connect(_on_result_continue)
	result_vbox.add_child(_result_continue)


func _connect_internal_signals() -> void:
	_floor_map.room_clicked.connect(_on_room_clicked)
	_room_popup.action_pressed.connect(_on_popup_action)
	_crawler_hud.ability_pressed.connect(_on_ability_pressed)
	_crawler_hud.items_pressed.connect(_on_items_pressed)
	_capture_popup.capture_attempted.connect(_on_capture_attempted)
	_capture_popup.capture_released.connect(_on_capture_released)
	_capture_popup.dismissed.connect(_on_capture_dismissed)
	_item_popup.closed.connect(_on_item_popup_closed)
	_item_popup.item_used.connect(_on_item_used)

	## Puzzle signals
	_puzzle_sequence.puzzle_completed.connect(_on_puzzle_completed)
	_puzzle_conduit.puzzle_completed.connect(_on_puzzle_completed)
	_puzzle_echo.puzzle_completed.connect(_on_puzzle_completed)
	_puzzle_echo.echo_combat_requested.connect(_on_echo_combat_requested)


func _connect_dungeon_signals() -> void:
	_disconnect_dungeon_signals()
	var connections: Array[Array] = [
		["room_entered", _on_room_entered],
		["room_revealed", _on_room_revealed],
		["floor_changed", _on_floor_changed],
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
	## Only allow moving to adjacent rooms
	var adjacent_ids: Dictionary = {}
	for room: Dictionary in dungeon_state.get_adjacent_rooms():
		adjacent_ids[room["id"]] = true
	if not adjacent_ids.has(room_id):
		return
	dungeon_state.move_to_room(room_id)


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
		## Exit room triggers floor transition via DungeonState.move_to_room
		## which calls _enter_floor internally — floor_changed signal handles it
		pass


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
	if remaining_hp <= 0:
		pass  ## forced_extraction signal handles this


func _on_forced_extraction() -> void:
	## Distinguish voluntary warp (hull > 0) from actual destruction (hull <= 0)
	if dungeon_state != null and dungeon_state.crawler != null:
		_warped_out = dungeon_state.crawler.hull_hp > 0
	else:
		_warped_out = false
	_show_result(false)


func _on_popup_action(room_type: String, room_data_local: Dictionary) -> void:
	_room_popup.hide_popup()

	match room_type:
		"enemy":
			_state = UIState.COMBAT
			var enemies: Array[GlyphInstance] = _generate_wild_enemies()
			combat_requested.emit(enemies, null)
		"boss":
			_state = UIState.COMBAT
			var boss_data: BossDef = null
			if data_loader != null:
				boss_data = data_loader.get_boss(dungeon_state.rift_template.rift_id)
			var boss_squad: Array[GlyphInstance] = _generate_boss(boss_data)
			combat_requested.emit(boss_squad, boss_data)
		"cache", "hidden":
			_pick_item()
			_clear_current_room("Looted supplies.")
			_state = UIState.EXPLORING
		"puzzle":
			_launch_puzzle(room_data_local)
		"hazard":
			_clear_current_room("Hazard cleared. Safe to pass.")
			_state = UIState.EXPLORING
		"empty", "start":
			_state = UIState.EXPLORING
		"exit":
			## Should not get here — exit handled by DungeonState
			_state = UIState.EXPLORING


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


func _on_capture_attempted(glyph: GlyphInstance, success: bool) -> void:
	if success:
		capture_requested.emit(glyph)


func _on_capture_released(_glyph: GlyphInstance) -> void:
	_capture_popup.hide_popup()
	_state = UIState.EXPLORING


func _on_capture_dismissed() -> void:
	_capture_popup.hide_popup()
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


func _on_item_used(_item: ItemDef) -> void:
	_crawler_hud.refresh()
	squad_changed.emit()


## --- Helpers ---

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

	## Fade to black
	var tween: Tween = create_tween()
	tween.tween_property(_floor_overlay, "color", Color(0, 0, 0, 1), 0.15)

	## Hold on title
	tween.tween_callback(func() -> void:
		_rebuild_floor()
	)
	tween.tween_interval(0.25)

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
	## Calculate capture chance (stub values for enemy_count=1, turns=3, no_ko=true)
	var chance: float = CaptureCalculator.calculate_chance(1, 3, false)
	_capture_popup.show_capture(glyph, chance)


func _is_squad_wiped() -> bool:
	if roster_state == null:
		return false
	for g: GlyphInstance in roster_state.active_squad:
		if not g.is_knocked_out:
			return false
	return true


func _generate_scan_info(room_id: String) -> void:
	## Pre-generate species names for a scanned enemy room
	if data_loader == null or dungeon_state == null:
		return
	var template: RiftTemplate = dungeon_state.rift_template
	if template.wild_glyph_pool.is_empty():
		return

	var count: int = randi_range(1, 3)
	var names: Array[String] = []
	for i: int in range(count):
		var species_id: String = template.wild_glyph_pool[randi() % template.wild_glyph_pool.size()]
		var species: GlyphSpecies = data_loader.get_species(species_id)
		if species != null:
			names.append(species.name)

	if not names.is_empty():
		var room: Dictionary = dungeon_state._get_room(dungeon_state.current_floor, room_id)
		if not room.is_empty():
			room["scan_info"] = ", ".join(names)


func _generate_boss_scan_info(room_id: String) -> void:
	## Add boss name to scanned boss room
	if data_loader == null or dungeon_state == null:
		return
	var template: RiftTemplate = dungeon_state.rift_template
	var boss_def: BossDef = data_loader.get_boss(template.boss_id)
	if boss_def != null:
		var room: Dictionary = dungeon_state._get_room(dungeon_state.current_floor, room_id)
		if not room.is_empty():
			room["scan_info"] = boss_def.name


func _generate_wild_enemies() -> Array[GlyphInstance]:
	var enemies: Array[GlyphInstance] = []
	if data_loader == null or dungeon_state == null:
		return enemies

	var template: RiftTemplate = dungeon_state.rift_template
	if template.wild_glyph_pool.is_empty():
		return enemies

	var count: int = randi_range(1, 3)
	for i: int in range(count):
		var species_id: String = template.wild_glyph_pool[randi() % template.wild_glyph_pool.size()]
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

	boss.max_hp = int(boss_species.base_hp * boss_def.stat_modifier)
	boss.atk = int(boss_species.base_atk * boss_def.stat_modifier)
	boss.def_stat = int(boss_species.base_def * boss_def.stat_modifier)
	boss.spd = int(boss_species.base_spd * boss_def.stat_modifier)
	boss.res = int(boss_species.base_res * boss_def.stat_modifier)
	boss.current_hp = boss.max_hp
	squad.append(boss)

	return squad


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


func _pick_item() -> void:
	if data_loader == null or dungeon_state == null:
		return
	var all_items: Dictionary = data_loader.items
	if all_items.is_empty():
		return
	var keys: Array = all_items.keys()
	var item_id: String = keys[randi() % keys.size()]
	var item: ItemDef = data_loader.get_item(item_id)
	if item != null:
		dungeon_state.crawler.add_item(item)


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
		if g.current_hp >= g.max_hp and not g.is_knocked_out:
			continue  ## Already full HP, skip
		has_targets = true
		var btn: Button = Button.new()
		var hp_pct: int = int(float(g.current_hp) / maxf(float(g.max_hp), 1.0) * 100)
		var heal_amount: int = maxi(1, int(float(g.max_hp) * 0.5))
		var status: String = "KO" if g.is_knocked_out else "%d/%d HP" % [g.current_hp, g.max_hp]
		btn.text = "%s  %s  (+%d HP)" % [g.species.name, status, heal_amount]
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
	if target.is_knocked_out:
		target.is_knocked_out = false

	_hide_repair_picker()
	_crawler_hud.refresh()
	squad_changed.emit()


func _hide_repair_picker() -> void:
	_repair_overlay.visible = false
	_state = UIState.EXPLORING


## --- Puzzle helpers ---

const PUZZLE_TYPES: Array[String] = ["sequence", "conduit", "echo"]

func _launch_puzzle(room_data: Dictionary) -> void:
	## Assign a random puzzle type to this room if not already set
	if not room_data.has("puzzle_type"):
		room_data["puzzle_type"] = PUZZLE_TYPES[randi() % PUZZLE_TYPES.size()]

	_state = UIState.PUZZLE
	var puzzle_type: String = room_data["puzzle_type"]

	match puzzle_type:
		"sequence":
			_puzzle_sequence.start(instant_mode)
		"conduit":
			_puzzle_conduit.start(instant_mode)
		"echo":
			if dungeon_state != null and dungeon_state.rift_template != null:
				_puzzle_echo.start(dungeon_state.rift_template, data_loader, roster_state)
			else:
				## Fallback to sequence if no rift data
				_puzzle_sequence.start(instant_mode)


func _on_puzzle_completed(success: bool, reward_type: String, _reward_data: Variant) -> void:
	## Hide all puzzle overlays
	_puzzle_sequence.visible = false
	_puzzle_conduit.visible = false
	_puzzle_echo.visible = false

	if success:
		match reward_type:
			"item":
				_pick_item()
				_clear_current_room("Puzzle solved — found supplies!")
			"codex_reveal":
				_reveal_random_species()
				_clear_current_room("Puzzle solved — codex updated!")
			_:
				_clear_current_room("Puzzle solved.")
	else:
		_clear_current_room("Passed by the puzzle.")

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


func _reveal_random_species() -> void:
	## Discover a random undiscovered species
	if codex_state == null or data_loader == null:
		return
	var undiscovered: Array[String] = []
	for species_id: String in data_loader.species.keys():
		if not codex_state.is_species_discovered(species_id):
			undiscovered.append(species_id)
	if not undiscovered.is_empty():
		var pick: String = undiscovered[randi() % undiscovered.size()]
		codex_state.discover_species(pick)
