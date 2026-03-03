extends Control

## Quick launcher to explore a dungeon rift in the GUI.
## Run: ~/bin/godot res://ui/dungeon/dungeon_demo.tscn
## Or set as main scene in project.godot and press F5.
##
## Click adjacent rooms to navigate. Popups appear for each room type.
## Enemy/boss rooms trigger auto-resolved combat (no actual BattleScene).
## Capture popup appears after defeating wild glyphs.

var _data_loader: Node = null
var _dungeon_state: DungeonState = null
var _dungeon_scene: DungeonScene = null
var _crawler: CrawlerState = null
var _status_label: Label = null


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")

	## Create CrawlerState (deferred — root is busy during _ready)
	_crawler = CrawlerState.new()
	_crawler.name = "Crawler"
	get_tree().root.call_deferred("add_child", _crawler)

	## Status label (bottom right)
	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_status_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status_label.offset_right = -12.0
	_status_label.offset_bottom = -8.0
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_status_label.text = "Click adjacent rooms to explore. ESC to quit."
	add_child(_status_label)

	## Wait a frame for deferred add_child to complete, then initialize
	await get_tree().process_frame
	_start_rift()


func _start_rift() -> void:
	## Create DungeonState + initialize with tutorial rift
	_dungeon_state = DungeonState.new()
	_dungeon_state.crawler = _crawler
	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	_dungeon_state.initialize(template)

	## Create DungeonScene
	_dungeon_scene = DungeonScene.new()
	_dungeon_scene.data_loader = _data_loader
	add_child(_dungeon_scene)

	## Wire signals
	_dungeon_scene.combat_requested.connect(_on_combat_requested)
	_dungeon_scene.capture_requested.connect(_on_capture_requested)
	_dungeon_scene.rift_completed.connect(_on_rift_completed)
	_dungeon_scene.floor_changed.connect(_on_floor_changed)

	## Start
	_dungeon_scene.start_rift(_dungeon_state)
	_update_status()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			get_tree().quit()
		## R to restart
		if key.pressed and key.keycode == KEY_R:
			_restart_rift()


func _on_combat_requested(enemies: Array[GlyphInstance], boss_def: BossDef) -> void:
	## Auto-resolve combat: player always wins (demo mode)
	var is_boss: bool = boss_def != null
	print("[Demo] Combat! %d enemies%s — auto-resolving..." % [enemies.size(), " (BOSS)" if is_boss else ""])
	_status_label.text = "Combat resolved! (auto-win in demo mode)"
	## Small delay then return to exploration
	await get_tree().create_timer(0.3).timeout
	_dungeon_scene.on_combat_finished(true, enemies)
	_update_status()


func _on_capture_requested(glyph: GlyphInstance) -> void:
	print("[Demo] Captured: %s" % glyph.species.name)
	_status_label.text = "Captured %s!" % glyph.species.name
	await get_tree().create_timer(0.5).timeout
	_dungeon_scene.on_capture_done()
	_update_status()


func _on_rift_completed(won: bool) -> void:
	if won:
		print("[Demo] RIFT COMPLETE — Victory!")
		_status_label.text = "RIFT COMPLETE! Press R to restart."
	else:
		print("[Demo] RIFT FAILED — Forced extraction!")
		_status_label.text = "RIFT FAILED! Press R to restart."


func _on_floor_changed(floor_number: int) -> void:
	print("[Demo] Floor changed to %d" % floor_number)
	_update_status()


func _restart_rift() -> void:
	print("[Demo] Restarting rift...")
	_dungeon_scene.queue_free()

	_dungeon_state = DungeonState.new()
	_dungeon_state.crawler = _crawler
	var template: RiftTemplate = _data_loader.get_rift_template("tutorial_01")
	_dungeon_state.initialize(template)

	_dungeon_scene = DungeonScene.new()
	_dungeon_scene.data_loader = _data_loader
	add_child(_dungeon_scene)
	_dungeon_scene.combat_requested.connect(_on_combat_requested)
	_dungeon_scene.capture_requested.connect(_on_capture_requested)
	_dungeon_scene.rift_completed.connect(_on_rift_completed)
	_dungeon_scene.floor_changed.connect(_on_floor_changed)
	_dungeon_scene.start_rift(_dungeon_state)
	_update_status()


func _update_status() -> void:
	if _dungeon_state == null:
		return
	var floor_num: int = _dungeon_state.current_floor + 1
	var total_floors: int = _dungeon_state.floors.size()
	var room: Dictionary = _dungeon_state.get_current_room()
	var room_type: String = room.get("type", "?")
	_status_label.text = "Floor %d/%d | Room: %s (%s) | Click adjacent rooms | R=restart | ESC=quit" % [
		floor_num, total_floors, _dungeon_state.current_room_id, room_type
	]
