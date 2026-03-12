class_name MainScene
extends Control

## Top-level orchestrator that manages the full game loop.
## State machine follows GameState.State: BASTION ↔ RIFT ↔ COMBAT.

var game_state: GameState = null
var roster_state: RosterState = null
var codex_state: CodexState = null
var crawler_state: CrawlerState = null
var combat_engine: Node = null
var fusion_engine: FusionEngine = null
var mastery_tracker: MasteryTracker = null
var data_loader: Node = null

var _title_screen: TitleScreen = null
var _title_save_slots: SaveSlotsPopup = null
var _bastion_scene: BastionScene = null
var _dungeon_scene: DungeonScene = null
var _battle_scene: BattleScene = null
var _transition_overlay: ColorRect = null
var _squad_overlay: SquadOverlay = null
var _detail_popup: GlyphDetailPopup = null
var _milestone_toast: PanelContainer = null
var _milestone_toast_label: Label = null

## For testing — skip transition tweens
var instant_mode: bool = false

## Track current rift template for completion
var _current_rift_template: RiftTemplate = null



func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameSettings.load_settings()
	GameSettings.apply_font_scale(self)
	_build_scene_tree()
	_connect_signals()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GlyphArt.clear_cache()
		GameArt.clear_cache()


func setup(
	p_game_state: GameState,
	p_roster_state: RosterState,
	p_codex_state: CodexState,
	p_crawler_state: CrawlerState,
	p_combat_engine: Node,
	p_fusion_engine: FusionEngine,
	p_mastery_tracker: MasteryTracker,
	p_data_loader: Node,
) -> void:
	game_state = p_game_state
	roster_state = p_roster_state
	codex_state = p_codex_state
	crawler_state = p_crawler_state
	combat_engine = p_combat_engine
	fusion_engine = p_fusion_engine
	mastery_tracker = p_mastery_tracker
	data_loader = p_data_loader

	## Setup sub-scenes
	_title_save_slots.setup(game_state, roster_state, codex_state, crawler_state, data_loader)
	_bastion_scene.setup(game_state, roster_state, codex_state, crawler_state, fusion_engine, data_loader)
	_dungeon_scene.data_loader = data_loader
	_dungeon_scene.roster_state = roster_state
	_dungeon_scene.codex_state = codex_state
	_dungeon_scene._squad_overlay = _squad_overlay
	_dungeon_scene._pause_menu.setup_save_slots(game_state, roster_state, codex_state, crawler_state, data_loader)
	## Wire save_fn so manual saves go through the same path as auto-saves
	_dungeon_scene._pause_menu._save_slots_popup.save_fn = _save_to_slot
	_bastion_scene._pause_menu._save_slots_popup.save_fn = _save_to_slot
	_battle_scene.combat_engine = combat_engine
	_battle_scene.mastery_tracker = mastery_tracker

	## Wire milestone signals
	if codex_state != null:
		codex_state.fusion_logged.connect(_on_fusion_logged)
	if game_state != null and game_state.milestone_tracker != null:
		game_state.milestone_tracker.milestone_completed.connect(_on_milestone_completed)


func show_title() -> void:
	if game_state == null:
		return
	_show_title()


func start_game() -> void:
	if game_state == null:
		return
	## Try loading existing save; fall back to new game
	if SaveManager.has_save():
		var loaded: bool = SaveManager.load_game(
			game_state, roster_state, codex_state, crawler_state, data_loader
		)
		if loaded:
			if _try_resume_rift():
				return
			_show_bastion()
			return
	game_state.start_new_game()
	_show_bastion()


func _build_scene_tree() -> void:
	## TitleScreen
	_title_screen = TitleScreen.new()
	_title_screen.name = "TitleScreen"
	_title_screen.visible = false
	add_child(_title_screen)

	## Save slots popup for title screen (load-only mode)
	_title_save_slots = SaveSlotsPopup.new()
	_title_save_slots.name = "TitleSaveSlots"
	_title_save_slots.load_only = true
	add_child(_title_save_slots)

	## BastionScene
	_bastion_scene = BastionScene.new()
	_bastion_scene.name = "BastionScene"
	add_child(_bastion_scene)

	## DungeonScene
	_dungeon_scene = DungeonScene.new()
	_dungeon_scene.name = "DungeonScene"
	_dungeon_scene.visible = false
	add_child(_dungeon_scene)

	## BattleScene
	_battle_scene = BattleScene.new()
	_battle_scene.name = "BattleScene"
	_battle_scene.visible = false
	add_child(_battle_scene)

	## SquadOverlay (shown during dungeon, right side)
	_squad_overlay = SquadOverlay.new()
	_squad_overlay.name = "SquadOverlay"
	_squad_overlay.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_squad_overlay.offset_left = -160.0
	_squad_overlay.offset_right = -10.0
	_squad_overlay.offset_top = -100.0
	_squad_overlay.offset_bottom = 100.0
	_squad_overlay.visible = false
	add_child(_squad_overlay)

	## Detail popup (above everything except transition)
	_detail_popup = GlyphDetailPopup.new()
	_detail_popup.name = "DetailPopup"
	add_child(_detail_popup)

	## Milestone toast (top-center, above scenes)
	_milestone_toast = PanelContainer.new()
	_milestone_toast.name = "MilestoneToast"
	_milestone_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_milestone_toast.offset_left = -200.0
	_milestone_toast.offset_right = 200.0
	_milestone_toast.offset_top = 20.0
	_milestone_toast.offset_bottom = 70.0
	_milestone_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milestone_toast.visible = false
	var toast_style: StyleBoxFlat = StyleBoxFlat.new()
	toast_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	toast_style.border_color = Color("#FFD700")
	toast_style.set_border_width_all(2)
	toast_style.set_corner_radius_all(6)
	toast_style.set_content_margin_all(8)
	_milestone_toast.add_theme_stylebox_override("panel", toast_style)
	_milestone_toast_label = Label.new()
	_milestone_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_milestone_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_milestone_toast_label.add_theme_font_size_override("font_size", 14)
	_milestone_toast_label.add_theme_color_override("font_color", Color("#FFD700"))
	_milestone_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_milestone_toast.add_child(_milestone_toast_label)
	add_child(_milestone_toast)

	## Transition overlay (full screen black for fades)
	_transition_overlay = ColorRect.new()
	_transition_overlay.name = "TransitionOverlay"
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.color = Color(0, 0, 0, 0)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.visible = false
	add_child(_transition_overlay)


func _connect_signals() -> void:
	_title_screen.new_game_pressed.connect(_on_new_game)
	_title_screen.continue_pressed.connect(_on_continue)
	_title_screen.load_game_pressed.connect(_on_load_game)
	_title_save_slots.slot_loaded.connect(_on_title_slot_loaded)
	_bastion_scene.rift_selected.connect(_on_rift_selected)
	_bastion_scene.hub_entered.connect(_auto_save)
	_bastion_scene.save_and_quit_pressed.connect(_on_save_and_quit)
	_bastion_scene.save_slot_loaded.connect(_on_save_slot_loaded)
	_dungeon_scene.combat_requested.connect(_on_combat_requested)
	_dungeon_scene.capture_requested.connect(_on_capture_requested)
	_dungeon_scene.rift_completed.connect(_on_rift_completed)
	_dungeon_scene.squad_changed.connect(_on_squad_changed)
	_dungeon_scene.hidden_room_entered.connect(_on_hidden_room_entered)
	_dungeon_scene.floor_changed.connect(_on_floor_changed)
	_dungeon_scene.save_and_quit_pressed.connect(_on_save_and_quit)
	_dungeon_scene.save_slot_loaded.connect(_on_save_slot_loaded)
	_battle_scene.battle_finished.connect(_on_battle_finished)
	_squad_overlay.glyph_clicked.connect(_on_squad_overlay_glyph_clicked)
	_squad_overlay.swap_pressed.connect(func() -> void: _dungeon_scene._on_swap_pressed())


## --- State transitions ---

func _show_title() -> void:
	_title_screen.visible = true
	_title_screen.refresh()
	_bastion_scene.visible = false
	_dungeon_scene.visible = false
	_battle_scene.visible = false
	_squad_overlay.visible = false


func _show_bastion() -> void:
	_title_screen.visible = false
	_bastion_scene.visible = true
	_bastion_scene.show_hub()
	_dungeon_scene.visible = false
	_battle_scene.visible = false
	_squad_overlay.visible = false


func _show_dungeon() -> void:
	_bastion_scene.visible = false
	_dungeon_scene.visible = true
	_battle_scene.visible = false
	_squad_overlay.visible = true
	_squad_overlay.setup(roster_state.active_squad, null, _dungeon_scene.rift_pool, crawler_state)
	_squad_overlay.refresh()


func _show_battle() -> void:
	_bastion_scene.visible = false
	_dungeon_scene.visible = false
	_battle_scene.visible = true
	_squad_overlay.visible = false


## --- Title screen handlers ---

func _on_new_game() -> void:
	game_state.start_new_game()
	_fade_to(func() -> void:
		_show_bastion()
	)


func _on_continue() -> void:
	var slot: String = _title_screen.get_most_recent_slot()
	if slot == "":
		return
	var loaded: bool = SaveManager.load_from_slot(
		slot, game_state, roster_state, codex_state, crawler_state, data_loader
	)
	if not loaded:
		return
	_fade_to(func() -> void:
		_bastion_scene.setup(game_state, roster_state, codex_state, crawler_state, fusion_engine, data_loader)
		if _try_resume_rift():
			return
		_show_bastion()
	)


func _on_load_game() -> void:
	_title_save_slots.show_popup()


func _on_title_slot_loaded() -> void:
	_fade_to(func() -> void:
		_bastion_scene.setup(game_state, roster_state, codex_state, crawler_state, fusion_engine, data_loader)
		if _try_resume_rift():
			return
		_show_bastion()
	)


## --- GRB helpers (for MCP automation) ---

func grb_enter_first_rift() -> void:
	var rifts: Array[RiftTemplate] = game_state.get_available_rifts()
	if rifts.size() > 0:
		_on_rift_selected(rifts[0])


## --- Signal handlers ---

func _on_rift_selected(template: RiftTemplate) -> void:
	_auto_save()
	_current_rift_template = template
	crawler_state.begin_run()
	game_state.start_rift(template)
	_dungeon_scene.instant_mode = instant_mode

	_fade_to(func() -> void:
		_dungeon_scene.start_rift(game_state.current_dungeon)
		_show_dungeon()
	)


func _on_combat_requested(enemies: Array[GlyphInstance], boss_def: BossDef) -> void:
	_fade_to(func() -> void:
		_show_battle()
		_battle_scene.skip_formation = true
		_battle_scene.start_battle(roster_state.active_squad, enemies, boss_def)
	)


func _on_battle_finished(won: bool, was_forfeit: bool = false) -> void:
	## Get combat stats for capture calculation
	var enemies: Array[GlyphInstance] = []
	var turns: int = 3
	var recruit_counts: Dictionary = {}
	var ko_list: Array[GlyphInstance] = []
	if combat_engine != null:
		enemies = combat_engine.enemy_squad
		turns = combat_engine.turn_count
		recruit_counts = combat_engine.recruit_counts.duplicate()
		ko_list = combat_engine.ko_list.duplicate()

	_fade_to(func() -> void:
		_show_dungeon()
		_squad_overlay.refresh()
		_dungeon_scene.on_combat_finished(won, enemies, turns, recruit_counts, was_forfeit, ko_list)
	)


func _on_capture_requested(wild_glyph: GlyphInstance) -> void:
	## Add captured glyph to roster — do NOT dismiss the popup here.
	## The popup stays visible so the player sees "CAPTURED!".
	## DungeonScene's _on_capture_dismissed (Continue button) handles cleanup.
	if wild_glyph == null:
		return

	## Prepare the glyph for the player roster
	wild_glyph.side = "player"
	wild_glyph.reset_combat_state()
	wild_glyph.current_hp = wild_glyph.max_hp
	wild_glyph.mastery_objectives = MasteryTracker.build_mastery_track(
		wild_glyph.species, data_loader.mastery_pools
	)

	## If active squad has room and GP capacity, add directly to squad
	var added_to_squad: bool = false
	var squad_has_slot: bool = roster_state.active_squad.size() < crawler_state.slots
	var squad_gp: int = _get_squad_gp()
	var would_exceed_gp: bool = squad_gp + wild_glyph.get_gp_cost() > crawler_state.capacity
	if squad_has_slot and not would_exceed_gp:
		roster_state.add_glyph(wild_glyph)
		roster_state.active_squad.append(wild_glyph)
		if not _dungeon_scene.rift_pool.has(wild_glyph):
			_dungeon_scene.rift_pool.append(wild_glyph)
		added_to_squad = true
	else:
		## Check bench capacity (non-squad glyphs in rift pool)
		var bench_count: int = _dungeon_scene.rift_pool.size() - roster_state.active_squad.size()
		if bench_count >= crawler_state.get_effective_bench_slots():
			## Bench full — show swap UI (release a bench glyph to make room)
			var bench_glyphs: Array[GlyphInstance] = _get_bench_glyphs()
			var popup: CapturePopup = _dungeon_scene._capture_popup
			var has_transmitter: bool = crawler_state.has_rift_transmitter if crawler_state != null else false
			popup.show_bench_swap(wild_glyph, bench_glyphs, has_transmitter)
			if not popup.bench_swap_chosen.is_connected(_on_bench_swap):
				popup.bench_swap_chosen.connect(_on_bench_swap)
			if has_transmitter and not popup.transmitter_send.is_connected(_on_transmitter_send):
				popup.transmitter_send.connect(_on_transmitter_send)
			return

		roster_state.add_glyph(wild_glyph)
		if not _dungeon_scene.rift_pool.has(wild_glyph):
			_dungeon_scene.rift_pool.append(wild_glyph)

	codex_state.discover_species(wild_glyph.species.id)

	## Notify mastery tracker about the capture
	if mastery_tracker != null:
		mastery_tracker.notify_capture(roster_state.active_squad)

	## Notify milestone tracker about the capture
	if game_state != null:
		game_state.notify_capture(wild_glyph)

	## Update popup to confirm where the glyph went
	if added_to_squad:
		_dungeon_scene._capture_popup._result_label.text = "CAPTURED!\nAdded to squad."
		_dungeon_scene.emit_signal("squad_changed")
	else:
		_dungeon_scene._capture_popup._result_label.text = "CAPTURED!\nAdded to bench."

	## Append capture info to room history
	_append_room_history("Captured %s." % wild_glyph.species.name)

	## Refresh squad overlay to show new reserve
	_squad_overlay.refresh()


func _get_squad_gp() -> int:
	var total: int = 0
	for g: GlyphInstance in roster_state.active_squad:
		total += g.get_gp_cost()
	return total


func _get_bench_glyphs() -> Array[GlyphInstance]:
	var result: Array[GlyphInstance] = []
	for g: GlyphInstance in _dungeon_scene.rift_pool:
		if not roster_state.active_squad.has(g):
			result.append(g)
	return result


func _on_bench_swap(keep_glyph: GlyphInstance, release_glyph: GlyphInstance) -> void:
	## Remove released glyph from rift pool and roster
	roster_state.remove_glyph(release_glyph)
	_dungeon_scene.rift_pool.erase(release_glyph)

	## Add new glyph
	roster_state.add_glyph(keep_glyph)
	if not _dungeon_scene.rift_pool.has(keep_glyph):
		_dungeon_scene.rift_pool.append(keep_glyph)
	codex_state.discover_species(keep_glyph.species.id)

	## Notify mastery tracker about the capture
	if mastery_tracker != null:
		mastery_tracker.notify_capture(roster_state.active_squad)

	## Notify milestone tracker about the capture
	if game_state != null:
		game_state.notify_capture(keep_glyph)

	_append_room_history("Captured %s (released %s)." % [keep_glyph.species.name, release_glyph.species.name])
	_squad_overlay.refresh()


func _on_transmitter_send(glyph: GlyphInstance) -> void:
	## Send captured glyph directly to bastion reserves (not rift pool)
	glyph.side = "player"
	glyph.reset_combat_state()
	glyph.current_hp = glyph.max_hp
	glyph.mastery_objectives = MasteryTracker.build_mastery_track(
		glyph.species, data_loader.mastery_pools
	)
	roster_state.add_glyph(glyph)
	codex_state.discover_species(glyph.species.id)

	if mastery_tracker != null:
		mastery_tracker.notify_capture(roster_state.active_squad)
	if game_state != null:
		game_state.notify_capture(glyph)

	_append_room_history("Transmitted %s to reserves." % glyph.species.name)
	_squad_overlay.refresh()


func _on_rift_completed(won: bool) -> void:
	if won and _current_rift_template != null:
		game_state.complete_rift(_current_rift_template.rift_id)
	else:
		## Loss/extraction: complete_rift already clears current_dungeon on win,
		## but on loss we must clear it so the save doesn't contain mid-rift state.
		game_state.current_dungeon = null

	## Heal all glyphs when returning to bastion
	_heal_all_glyphs()

	_auto_save()

	var msg: String = ""
	if won:
		## Check if all rifts are now cleared (endgame)
		var total_rifts: int = data_loader.rift_templates.size() if data_loader != null else 8
		if codex_state != null and codex_state.cleared_rift_count() >= total_rifts:
			var discovery_pct: int = int(codex_state.get_discovery_percentage() * 100)
			msg = "ALL RIFTS CONQUERED! Codex: %d%% discovered. The rifts are sealed... for now." % discovery_pct
		else:
			msg = "Rift conquered! All glyphs healed."
	else:
		msg = "Extracted from rift. All glyphs healed."

	_fade_to(func() -> void:
		_show_bastion()
		_bastion_scene.show_notification(msg)
	)
	_current_rift_template = null


func _heal_all_glyphs() -> void:
	for g: GlyphInstance in roster_state.all_glyphs:
		g.current_hp = g.max_hp
		g.is_knocked_out = false


func _on_squad_changed() -> void:
	_squad_overlay.setup(roster_state.active_squad, null, _dungeon_scene.rift_pool, crawler_state)
	_squad_overlay.refresh()


func _on_squad_overlay_glyph_clicked(g: GlyphInstance) -> void:
	if g != null and _detail_popup != null:
		_detail_popup.show_glyph(g)


func _append_room_history(text: String) -> void:
	## Append extra info to the current room's history string
	if game_state == null or game_state.current_dungeon == null:
		return
	var ds: DungeonState = game_state.current_dungeon
	var floor_idx: int = ds.current_floor
	if floor_idx >= ds.floors.size():
		return
	var floor_data: Dictionary = ds.floors[floor_idx]
	for room: Dictionary in floor_data.get("rooms", []):
		if room.get("id", "") == ds.current_room_id:
			var existing: String = room.get("history", "")
			if existing != "":
				room["history"] = existing + " " + text
			else:
				room["history"] = text
			break


func _on_hidden_room_entered() -> void:
	if game_state != null:
		game_state.notify_hidden_room()


func _on_floor_changed(_floor_number: int) -> void:
	## Auto-save on each floor transition during a rift
	_auto_save()


func _on_fusion_logged(_parent_a: String, _parent_b: String, _result: String) -> void:
	if game_state != null:
		game_state.notify_fusion()


func _on_milestone_completed(_upgrade_id: String, description: String) -> void:
	show_milestone_toast(description)


func show_milestone_toast(text: String) -> void:
	if _milestone_toast == null or _milestone_toast_label == null:
		return
	_milestone_toast_label.text = "UPGRADE UNLOCKED!\n%s" % text
	_milestone_toast.visible = true
	_milestone_toast.modulate = Color.WHITE
	if instant_mode:
		return
	## Slide in from top
	var target_top: float = 20.0
	_milestone_toast.offset_top = -60.0
	_milestone_toast.offset_bottom = -10.0
	_milestone_toast.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_milestone_toast, "offset_top", target_top, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(_milestone_toast, "offset_bottom", target_top + 50.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(_milestone_toast, "modulate", Color.WHITE, 0.2)
	tween.set_parallel(false)
	## Hold then fade out
	tween.tween_interval(3.0)
	tween.tween_property(_milestone_toast, "modulate", Color(1, 1, 1, 0), 1.0)
	tween.tween_callback(func() -> void: _milestone_toast.visible = false)


## --- Save slot loaded ---

func _on_save_slot_loaded() -> void:
	## State objects already updated by load — re-show bastion with fresh data
	_bastion_scene.setup(game_state, roster_state, codex_state, crawler_state, fusion_engine, data_loader)
	if _try_resume_rift():
		return
	_show_bastion()


## --- Auto-save ---

func _on_save_and_quit() -> void:
	_auto_save()
	_fade_to(func() -> void:
		_show_title()
	)


func _save_to_slot(slot: String) -> void:
	if game_state == null:
		return
	var bench: Array[GlyphInstance] = []
	if game_state.current_dungeon != null and _dungeon_scene != null:
		bench = _get_bench_glyphs()
	SaveManager.save_to_slot(slot, game_state, roster_state, codex_state, crawler_state, "", bench)


func _auto_save() -> void:
	_save_to_slot(SaveManager.AUTOSAVE_SLOT)


## --- Mid-rift resume ---

func _try_resume_rift() -> bool:
	## Check if the last load had mid-rift data. If so, resume the dungeon.
	var rift_data: Dictionary = SaveManager.last_load_rift_data
	if not rift_data.get("in_rift", false):
		return false
	var ds: DungeonState = rift_data.get("dungeon_state") as DungeonState
	if ds == null:
		return false

	_current_rift_template = ds.rift_template

	_dungeon_scene.instant_mode = instant_mode
	_show_dungeon()
	_dungeon_scene.start_rift(ds)
	## Add bench glyphs to rift pool (start_rift only adds squad)
	var bench: Array = rift_data.get("rift_bench", rift_data.get("rift_cargo", []))
	for g: Variant in bench:
		if g is GlyphInstance:
			if not _dungeon_scene.rift_pool.has(g as GlyphInstance):
				_dungeon_scene.rift_pool.append(g as GlyphInstance)

	## Re-setup overlay now that rift_pool is fully populated
	_squad_overlay.setup(roster_state.active_squad, null, _dungeon_scene.rift_pool, crawler_state)
	_squad_overlay.refresh()

	## Clear so subsequent loads don't re-trigger
	SaveManager.last_load_rift_data = {}
	return true


## --- Fade transition ---

func _fade_to(callback: Callable) -> void:
	if instant_mode:
		callback.call()
		return

	_transition_overlay.visible = true
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition_overlay.color = Color(0, 0, 0, 0)

	var tween: Tween = create_tween()
	## Fade out (to black)
	tween.tween_property(_transition_overlay, "color", Color(0, 0, 0, 1), 0.15)
	## Execute callback at peak
	tween.tween_callback(callback)
	## Fade in (from black)
	tween.tween_property(_transition_overlay, "color", Color(0, 0, 0, 0), 0.15)
	## Cleanup
	tween.tween_callback(func() -> void:
		_transition_overlay.visible = false
		_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
