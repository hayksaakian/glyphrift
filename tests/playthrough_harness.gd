extends Control

## End-to-end playthrough harness.
## Drives the real GUI: clicks buttons, navigates rooms, fights battles,
## handles captures, and completes a full rift run.

var _data_loader: Node = null
var _main_scene: MainScene = null
var _game_state: GameState = null
var _roster_state: RosterState = null
var _codex_state: CodexState = null
var _crawler_state: CrawlerState = null
var _combat_engine: Node = null
var _fusion_engine: FusionEngine = null
var _mastery_tracker: MasteryTracker = null

var _screenshot_dir: String = "res://screenshots/playthrough/"
var _screenshot_idx: int = 0


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")
	_setup_deps()
	_setup_main_scene()
	_main_scene.start_game()

	DirAccess.make_dir_recursive_absolute("res://screenshots/playthrough")

	await _wait_ms(500)
	_screenshot("bastion_start")
	await _run_playthrough()


func _setup_deps() -> void:
	_roster_state = RosterState.new()
	_roster_state.name = "RosterState"
	add_child(_roster_state)
	_codex_state = CodexState.new()
	_codex_state.name = "CodexState"
	add_child(_codex_state)
	_crawler_state = CrawlerState.new()
	_crawler_state.name = "CrawlerState"
	add_child(_crawler_state)
	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	_combat_engine = ce_script.new() as Node
	_combat_engine.name = "CombatEngine"
	_combat_engine.data_loader = _data_loader
	add_child(_combat_engine)
	_fusion_engine = FusionEngine.new()
	_fusion_engine.name = "FusionEngine"
	_fusion_engine.data_loader = _data_loader
	_fusion_engine.codex_state = _codex_state
	_fusion_engine.roster_state = _roster_state
	add_child(_fusion_engine)
	_mastery_tracker = MasteryTracker.new()
	_mastery_tracker.connect_to_combat(_combat_engine)
	_game_state = GameState.new()
	_game_state.name = "GameState"
	_game_state.data_loader = _data_loader
	_game_state.roster_state = _roster_state
	_game_state.codex_state = _codex_state
	_game_state.crawler_state = _crawler_state
	_game_state.combat_engine = _combat_engine
	_game_state.fusion_engine = _fusion_engine
	_game_state.mastery_tracker = _mastery_tracker
	add_child(_game_state)


func _setup_main_scene() -> void:
	_main_scene = MainScene.new()
	_main_scene.name = "MainScene"
	add_child(_main_scene)
	_main_scene.setup(
		_game_state, _roster_state, _codex_state, _crawler_state,
		_combat_engine, _fusion_engine, _mastery_tracker, _data_loader,
	)


func _run_playthrough() -> void:
	print("")
	print("=== FULL PLAYTHROUGH ===")
	print("")

	## --- BASTION: Open Rift Gate ---
	print("[BASTION] Clicking Rift Gate...")
	_main_scene._bastion_scene._rift_gate_btn.pressed.emit()
	await _wait_ms(300)
	_screenshot("rift_gate")

	## --- RIFT GATE: Click Enter on first rift ---
	print("[RIFT GATE] Clicking Enter...")
	var enter_btn: Button = _find_button_in(_main_scene._bastion_scene._rift_gate, "Enter")
	if enter_btn == null:
		print("  ERROR: No Enter button found!")
		_quit()
		return
	enter_btn.pressed.emit()
	## Wait for fade transition (0.15s out + 0.15s in = ~400ms to be safe)
	await _wait_ms(600)
	_screenshot("dungeon_floor1")

	## --- DUNGEON EXPLORATION LOOP ---
	var ds: DungeonScene = _main_scene._dungeon_scene
	var dungeon: DungeonState = _game_state.current_dungeon
	print("[DUNGEON] Floor 1, room: %s, total floors: %d" % [dungeon.current_room_id, dungeon.floors.size()])

	var max_steps: int = 80
	var step: int = 0
	while step < max_steps:
		step += 1
		var ui: int = ds.get_ui_state()

		if ui == DungeonScene.UIState.RESULT:
			print("[RESULT] Rift ended!")
			_screenshot("rift_result")
			await _wait_ms(500)
			## Click Continue on result overlay to trigger rift_completed
			ds._result_continue.pressed.emit()
			await _wait_ms(800)
			break

		elif ui == DungeonScene.UIState.FLOOR_TRANSITION:
			print("[TRANSITION] Waiting for floor transition...")
			await _wait_until(func() -> bool: return ds.get_ui_state() != DungeonScene.UIState.FLOOR_TRANSITION, 3.0)
			_screenshot("new_floor")
			continue

		elif ui == DungeonScene.UIState.POPUP:
			var popup: RoomPopup = ds._room_popup
			if popup.visible:
				var rtype: String = popup.room_data.get("type", "?")
				print("[POPUP] %s — %s" % [rtype, popup.get_action_text()])
				_screenshot("popup_%s" % rtype)
				popup._action_button.pressed.emit()
				await _wait_ms(200)

				## Check what happened after action
				if ds.get_ui_state() == DungeonScene.UIState.COMBAT:
					await _handle_combat()
				elif ds.get_ui_state() == DungeonScene.UIState.CAPTURE:
					await _handle_capture()
				continue
			else:
				## Popup state but popup not visible — wait a frame
				await _wait_ms(100)
				continue

		elif ui == DungeonScene.UIState.COMBAT:
			## Got into combat without popup (shouldn't happen, but handle it)
			await _handle_combat()
			continue

		elif ui == DungeonScene.UIState.CAPTURE:
			await _handle_capture()
			continue

		elif ui == DungeonScene.UIState.EXPLORING:
			## Move to next room
			var moved: bool = _move_to_best_room(dungeon)
			if not moved:
				print("[STUCK] No reachable rooms!")
				_screenshot("stuck")
				break
			await _wait_ms(200)
			continue

		else:
			await _wait_ms(200)

	## --- FINAL STATE ---
	await _wait_ms(800)
	_screenshot("final")

	print("")
	print("=== PLAYTHROUGH COMPLETE (%d steps) ===" % step)
	print("  Roster: %d glyphs" % _roster_state.all_glyphs.size())
	print("  Cleared: %d rifts" % _codex_state.cleared_rift_count())
	print("  Phase: %d" % _game_state.game_phase)
	for g: GlyphInstance in _roster_state.all_glyphs:
		var squad_tag: String = "(squad)" if _roster_state.active_squad.has(g) else "(reserve)"
		print("  - %s HP:%d/%d %s %s" % [g.species.name, g.current_hp, g.max_hp,
			"KO" if g.is_knocked_out else "OK", squad_tag])
	print("")

	await _wait_ms(500)
	_quit()


func _handle_combat() -> void:
	print("[COMBAT] Battle starting...")
	var bs: BattleScene = _main_scene._battle_scene

	## MUST set auto_battle BEFORE formation confirm so the engine
	## auto-plays player turns from the very first turn
	_combat_engine.auto_battle = true
	bs._animation_queue.instant_mode = true

	## Wait for formation screen
	await _wait_ms(400)
	_screenshot("combat_formation")

	## Confirm formation — this triggers set_formation → _advance_turn
	## With auto_battle=true, the engine will process all turns automatically
	print("[COMBAT] Confirming formation...")
	bs._formation_setup._on_confirm()
	await _wait_ms(100)

	## Drain animation queue until combat ends
	var ticks: int = 0
	while ticks < 300:
		ticks += 1
		bs._animation_queue.drain()
		await get_tree().process_frame

		var phase: int = _combat_engine.phase
		if phase == _combat_engine.BattlePhase.VICTORY:
			print("[COMBAT] VICTORY! (%d ticks)" % ticks)
			break
		elif phase == _combat_engine.BattlePhase.DEFEAT:
			print("[COMBAT] DEFEAT! (%d ticks)" % ticks)
			break

	_screenshot("combat_end")

	## Wait for result screen to actually show
	await _wait_ms(200)
	bs._animation_queue.drain()
	await _wait_ms(200)

	## Verify result screen is showing before clicking Continue
	print("[COMBAT] Clicking Continue (result visible: %s)..." % str(bs._result_screen.visible))
	bs._result_screen._continue_button.pressed.emit()

	## Reset for next battle
	_combat_engine.auto_battle = false
	bs._animation_queue.instant_mode = false

	## Wait for fade transition back to dungeon
	await _wait_ms(700)
	_screenshot("post_combat")

	## Check for capture
	var ds: DungeonScene = _main_scene._dungeon_scene
	if ds.get_ui_state() == DungeonScene.UIState.CAPTURE:
		await _handle_capture()


func _handle_capture() -> void:
	var ds: DungeonScene = _main_scene._dungeon_scene
	var popup: CapturePopup = ds._capture_popup
	print("[CAPTURE] Chance: %s" % popup.get_chance_text())
	_screenshot("capture_offer")
	await _wait_ms(200)

	## Attempt capture
	popup._capture_button.pressed.emit()
	await _wait_ms(300)

	print("[CAPTURE] %s" % popup.get_result_text())
	_screenshot("capture_result")

	## Dismiss
	popup.dismissed.emit()
	await _wait_ms(300)


func _move_to_best_room(dungeon: DungeonState) -> bool:
	var adjacent: Array[Dictionary] = dungeon.get_adjacent_rooms()

	## Priority 1: unvisited rooms (prefer boss > enemy > cache > exit > other)
	var priority_types: Array[String] = ["boss", "enemy", "cache", "hidden", "puzzle", "hazard", "exit"]
	for ptype: String in priority_types:
		for room: Dictionary in adjacent:
			if not room.get("visited", false) and room.get("type", "") == ptype:
				_do_move(dungeon, room)
				return true

	## Priority 2: any unvisited
	for room: Dictionary in adjacent:
		if not room.get("visited", false):
			_do_move(dungeon, room)
			return true

	## Priority 3: exit room (even if visited — to advance floors)
	for room: Dictionary in adjacent:
		if room.get("type", "") == "exit":
			_do_move(dungeon, room)
			return true

	## Priority 4: any adjacent
	if adjacent.size() > 0:
		_do_move(dungeon, adjacent[0])
		return true

	return false


func _do_move(dungeon: DungeonState, room: Dictionary) -> void:
	var rid: String = room.get("id", "")
	var rtype: String = room.get("type", "?")
	if room.get("cleared", false):
		rtype = "cleared"
	print("[MOVE] → %s (%s)" % [rid, rtype])
	dungeon.move_to_room(rid)
	## Exit rooms now emit exit_reached instead of auto-advancing — call descend()
	if rtype == "exit":
		dungeon.descend()


## --- Utilities ---

func _wait_ms(ms: int) -> void:
	## Wait for approximately `ms` milliseconds worth of frames
	var frames: int = maxi(1, int(ms / 16.0))  ## ~60fps
	for i: int in range(frames):
		await get_tree().process_frame


func _wait_until(condition: Callable, timeout_sec: float) -> void:
	var elapsed: float = 0.0
	while elapsed < timeout_sec:
		if condition.call():
			return
		await get_tree().process_frame
		elapsed += 0.016


func _screenshot(label: String) -> void:
	_screenshot_idx += 1
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s%02d_%s.png" % [_screenshot_dir, _screenshot_idx, label]
	image.save_png(path)
	print("  [SS] %s" % path)


func _find_button_in(parent: Node, text: String) -> Button:
	if parent is Button:
		var btn: Button = parent as Button
		if btn.text == text:
			return btn
	for child: Node in parent.get_children():
		var found: Button = _find_button_in(child, text)
		if found != null:
			return found
	return null


func _quit() -> void:
	await get_tree().process_frame
	get_tree().quit()
