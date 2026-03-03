class_name DungeonScene
extends Control

## Main dungeon exploration orchestrator.
## Receives a DungeonState via start_rift(), builds UI, handles navigation.
## Does NOT own DungeonState — receives it like BattleScene receives CombatEngine.

signal combat_requested(enemies: Array[GlyphInstance], boss_def: BossDef)
signal capture_requested(wild_glyph: GlyphInstance)
signal rift_completed(won: bool)
signal floor_changed(floor_number: int)

enum UIState {
	EXPLORING,
	POPUP,
	COMBAT,
	CAPTURE,
	FLOOR_TRANSITION,
	RESULT,
}

var dungeon_state: DungeonState = null
var data_loader: Node = null  ## Injectable DataLoader
var _state: UIState = UIState.EXPLORING

var _background: ColorRect = null
var _floor_map: FloorMap = null
var _crawler_hud: CrawlerHUD = null
var _room_popup: RoomPopup = null
var _capture_popup: CapturePopup = null
var _floor_label: Label = null
var _floor_overlay: ColorRect = null
var _floor_overlay_label: Label = null
var _result_overlay: ColorRect = null
var _result_title: Label = null
var _result_subtitle: Label = null

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
	if not won:
		_state = UIState.EXPLORING
		_room_popup.hide_popup()
		return

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


func _connect_internal_signals() -> void:
	_floor_map.room_clicked.connect(_on_room_clicked)
	_room_popup.action_pressed.connect(_on_popup_action)
	_crawler_hud.ability_pressed.connect(_on_ability_pressed)
	_capture_popup.capture_attempted.connect(_on_capture_attempted)
	_capture_popup.capture_released.connect(_on_capture_released)
	_capture_popup.dismissed.connect(_on_capture_dismissed)


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

	var room_type: String = room.get("type", "empty")

	## Show popup for actionable rooms
	if room_type in ["enemy", "cache", "hazard", "puzzle", "boss", "empty", "hidden"]:
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


func _on_room_revealed(room_id: String, _room_type: String) -> void:
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
			_state = UIState.EXPLORING
		"puzzle":
			## Stub: auto-complete with a reward
			_pick_item()
			_state = UIState.EXPLORING
		"hazard", "empty", "start":
			_state = UIState.EXPLORING
		"exit":
			## Should not get here — exit handled by DungeonState
			_state = UIState.EXPLORING


func _on_ability_pressed(ability_name: String) -> void:
	if _state != UIState.EXPLORING:
		return
	if dungeon_state == null:
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
	_room_popup.hide_popup()

	if won:
		_result_title.text = "RIFT COMPLETE"
		_result_title.add_theme_color_override("font_color", Color("#FFD700"))
		var rift_name: String = dungeon_state.rift_template.name if dungeon_state.rift_template != null else "Rift"
		_result_subtitle.text = "%s conquered!" % rift_name
	else:
		_result_title.text = "RIFT FAILED"
		_result_title.add_theme_color_override("font_color", Color("#FF4444"))
		_result_subtitle.text = "Crawler destroyed — forced extraction."

	_result_overlay.visible = true
	rift_completed.emit(won)


func _show_capture(glyph: GlyphInstance) -> void:
	_state = UIState.CAPTURE
	## Calculate capture chance (stub values for enemy_count=1, turns=3, no_ko=true)
	var chance: float = CaptureCalculator.calculate_chance(1, 3, false)
	_capture_popup.show_capture(glyph, chance)


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
