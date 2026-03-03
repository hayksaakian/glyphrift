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

var _bastion_scene: BastionScene = null
var _dungeon_scene: DungeonScene = null
var _battle_scene: BattleScene = null
var _transition_overlay: ColorRect = null
var _squad_overlay: SquadOverlay = null
var _detail_popup: GlyphDetailPopup = null

## For testing — skip transition tweens
var instant_mode: bool = false

## Track current rift template for completion
var _current_rift_template: RiftTemplate = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene_tree()
	_connect_signals()


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
	_bastion_scene.setup(game_state, roster_state, codex_state, crawler_state, fusion_engine, data_loader)
	_dungeon_scene.data_loader = data_loader
	_dungeon_scene.roster_state = roster_state
	_dungeon_scene.codex_state = codex_state
	_battle_scene.combat_engine = combat_engine
	_battle_scene.mastery_tracker = mastery_tracker


func start_game() -> void:
	if game_state == null:
		return
	game_state.start_new_game()
	_show_bastion()


func _build_scene_tree() -> void:
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

	## Transition overlay (full screen black for fades)
	_transition_overlay = ColorRect.new()
	_transition_overlay.name = "TransitionOverlay"
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.color = Color(0, 0, 0, 0)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.visible = false
	add_child(_transition_overlay)


func _connect_signals() -> void:
	_bastion_scene.rift_selected.connect(_on_rift_selected)
	_dungeon_scene.combat_requested.connect(_on_combat_requested)
	_dungeon_scene.capture_requested.connect(_on_capture_requested)
	_dungeon_scene.rift_completed.connect(_on_rift_completed)
	_dungeon_scene.squad_changed.connect(_on_squad_changed)
	_battle_scene.battle_finished.connect(_on_battle_finished)
	_squad_overlay.glyph_clicked.connect(_on_squad_overlay_glyph_clicked)


## --- State transitions ---

func _show_bastion() -> void:
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
	_squad_overlay.setup(roster_state.active_squad, roster_state)
	_squad_overlay.refresh()


func _show_battle() -> void:
	_bastion_scene.visible = false
	_dungeon_scene.visible = false
	_battle_scene.visible = true
	_squad_overlay.visible = false


## --- Signal handlers ---

func _on_rift_selected(template: RiftTemplate) -> void:
	_current_rift_template = template
	crawler_state.begin_run()
	game_state.start_rift(template)
	_dungeon_scene.instant_mode = instant_mode

	_fade_to(func() -> void:
		_show_dungeon()
		_dungeon_scene.start_rift(game_state.current_dungeon)
	)


func _on_combat_requested(enemies: Array[GlyphInstance], boss_def: BossDef) -> void:
	_fade_to(func() -> void:
		_show_battle()
		_battle_scene.start_battle(roster_state.active_squad, enemies, boss_def)
	)


func _on_battle_finished(won: bool) -> void:
	## Get enemies from combat engine for capture flow
	var enemies: Array[GlyphInstance] = []
	if combat_engine != null:
		enemies = combat_engine.enemy_squad

	_fade_to(func() -> void:
		_show_dungeon()
		_squad_overlay.refresh()
		_dungeon_scene.on_combat_finished(won, enemies)
	)


func _on_capture_requested(wild_glyph: GlyphInstance) -> void:
	## Add captured glyph to roster — do NOT dismiss the popup here.
	## The popup stays visible so the player sees "CAPTURED!".
	## DungeonScene's _on_capture_dismissed (Continue button) handles cleanup.
	if wild_glyph == null:
		return

	## Check barracks capacity — reserves = all_glyphs minus active_squad
	var reserve_count: int = roster_state.all_glyphs.size() - roster_state.active_squad.size()
	if reserve_count >= roster_state.max_reserves:
		## Cargo full — update popup to tell the player
		_dungeon_scene._capture_popup._result_label.text = "CAPTURED!\nBut cargo is full — released."
		_dungeon_scene._capture_popup._result_label.add_theme_color_override(
			"font_color", Color("#FFC107")
		)
		return

	wild_glyph.side = "player"
	wild_glyph.reset_combat_state()
	wild_glyph.current_hp = wild_glyph.max_hp
	wild_glyph.mastery_objectives = MasteryTracker.build_mastery_track(
		wild_glyph.species, data_loader.mastery_pools
	)
	roster_state.add_glyph(wild_glyph)
	codex_state.discover_species(wild_glyph.species.id)

	## Update popup to confirm where the glyph went
	_dungeon_scene._capture_popup._result_label.text = "CAPTURED!\nAdded to reserves."

	## Append capture info to room history
	_append_room_history("Captured %s." % wild_glyph.species.name)

	## Refresh squad overlay to show new reserve
	_squad_overlay.refresh()


func _on_rift_completed(won: bool) -> void:
	if won and _current_rift_template != null:
		game_state.complete_rift(_current_rift_template.rift_id)

	## Heal all glyphs when returning to bastion
	_heal_all_glyphs()

	var msg: String = ""
	if won:
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
