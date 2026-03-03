extends Control

## Automated screenshot harness. Launches battle with T2 squad,
## drives turns to capture all 5 UX polish fixes:
##   1. Turn order highlight (current actor 80x80 + white border)
##   2. FRONT/BACK row labels + separator
##   3. Affinity advantage >>SE hints on technique buttons
##   4. Status icons (22x22 rounded + letter) + flash
##   5. Guard button [Static Guard], 5px border + GUARD label, log message

var _engine: Node = null
var _scene: BattleScene = null
var _data_loader: Node = null
var _shot_index: int = 0


func _ready() -> void:
	_data_loader = get_node("/root/DataLoader")

	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	_engine = ce_script.new() as Node
	_engine.name = "CombatEngine"
	_engine.data_loader = _data_loader
	get_tree().root.call_deferred("add_child", _engine)

	_scene = BattleScene.new()
	_scene.combat_engine = _engine
	add_child(_scene)

	## T2 squad: Thunderclaw (interrupt: static_guard), Vortail (status: destabilize→burn),
	## Ironbark (support: fortress→shield, interrupt: stone_wall)
	## Enemies: T1 glyphs — easy to survive, includes ground targets for electric >>SE
	var p_squad: Array[GlyphInstance] = _make_squad(["thunderclaw", "vortail", "ironbark"])
	var e_squad: Array[GlyphInstance] = _make_squad(["mossling", "sparkfin", "glitchkit"])

	_scene.start_battle(p_squad, e_squad)
	_capture_sequence()


func _make_squad(species_ids: Array) -> Array[GlyphInstance]:
	var squad: Array[GlyphInstance] = []
	for sid: String in species_ids:
		var sp: GlyphSpecies = _data_loader.get_species(sid)
		squad.append(GlyphInstance.create_from_species(sp, _data_loader))
	return squad


func _capture_sequence() -> void:
	## --- Shot 0: Formation screen ---
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	_capture("formation")

	## Confirm formation — engine starts round 1
	_scene._on_formation_confirmed(_scene._formation_setup.get_positions())
	_scene._animation_queue.drain()
	await _render_frames(2)

	## --- Shot 1: Battlefield (Fix 1: turn highlight, Fix 2: row labels) ---
	_log_state("After formation confirm")
	_capture("battlefield_turn_highlight")

	## --- Shot 2: Action menu for actor with interrupts (Fix 5: Guard [Static Guard]) ---
	## Find Thunderclaw (has static_guard interrupt) and show its action menu
	var thunderclaw: GlyphInstance = _find_player("Thunderclaw")
	if thunderclaw != null:
		_scene._show_action_menu(thunderclaw)
		await _render_frames(2)
		_capture("action_menu_interrupt_guard")

		## --- Shot 3: Technique list with >>SE hints (Fix 3) ---
		## Thunderclaw is electric — >>SE against ground enemies (Mossling)
		_scene._on_attack_pressed()
		await _render_frames(2)
		_capture("technique_list_affinity_hints")

		## --- Shot 3b: Target selection with SE highlights ---
		## Pick Chain Bolt (electric piercing — can hit back row Glitchkit who is water)
		var chain_bolt: TechniqueDef = _find_technique(thunderclaw, "chain_bolt")
		if chain_bolt != null:
			_scene._on_technique_chosen(chain_bolt)
			await _render_frames(2)
			_capture("target_select_se_highlights")
			## Cancel to go back
			_scene._target_selector.hide_targets()

		## --- Drive turn: Use destabilize with Vortail to apply burn ---
		## Go back to waiting state
		_scene._technique_list.visible = false
		_scene._action_menu.visible = false
		_scene._state = BattleScene.UIState.ANIMATING

	## Submit Thunderclaw attack to advance past its turn
	if _engine.current_actor != null and _engine.current_actor.side == "player":
		var first_enemy: GlyphInstance = _first_alive_enemy()
		if first_enemy != null:
			var tech: TechniqueDef = _engine.current_actor.techniques[0]
			_engine.submit_action({"action": "attack", "technique": tech, "target": first_enemy})
	_scene._animation_queue.drain()
	await _render_frames(2)

	## Keep submitting player actions until Vortail gets a turn (or enemy turns pass)
	for _i: int in range(10):
		if _engine.current_actor == null:
			break
		if _engine.phase != _engine.BattlePhase.TURN_ACTIVE:
			break
		if _engine.current_actor.species.name == "Vortail":
			break
		if _engine.current_actor.side == "player":
			## Auto-attack with first technique
			var fe: GlyphInstance = _first_alive_enemy()
			if fe != null:
				_engine.submit_action({"action": "attack", "technique": _engine.current_actor.techniques[0], "target": fe})
		_scene._animation_queue.drain()
		await _render_frames(1)

	## Now use Vortail's destabilize (applies burn) on an enemy
	var vortail: GlyphInstance = _find_player("Vortail")
	if _engine.current_actor == vortail and vortail != null:
		var destabilize: TechniqueDef = _find_technique(vortail, "destabilize")
		var target: GlyphInstance = _first_alive_enemy()
		if destabilize != null and target != null:
			print("Vortail uses Destabilize on %s (applies burn)" % target.species.name)
			_engine.submit_action({"action": "attack", "technique": destabilize, "target": target})
			_scene._animation_queue.drain()
			await _render_frames(2)

	## --- Shot 4: Status icons visible on enemy (Fix 4: burn icon with "B") ---
	_capture("status_icons_burn")

	## Continue advancing until a player actor gets a turn again
	for _i: int in range(10):
		if _engine.current_actor == null:
			break
		if _engine.phase != _engine.BattlePhase.TURN_ACTIVE:
			break
		if _engine.current_actor.side == "player":
			break
		_scene._animation_queue.drain()
		await _render_frames(1)

	## --- Shot 5: Guard with interrupt actor → guard border + GUARD label (Fix 5) ---
	## Find Thunderclaw or Ironbark (both have interrupts) and guard
	var guard_actor: GlyphInstance = _engine.current_actor
	if guard_actor != null and guard_actor.side == "player":
		print("Guarding with %s" % guard_actor.species.name)
		_engine.submit_action({"action": "guard"})
		_scene._animation_queue.drain()
		await _render_frames(2)
		_capture("guard_active_with_label")
	else:
		print("No player actor available for guard screenshot")

	## --- Summary ---
	print("")
	print("=== Screenshot Harness Complete ===")
	print("Screenshots saved to /tmp/glyphrift_*.png")
	print("Fix 1: Turn highlight → battlefield_turn_highlight")
	print("Fix 2: Row labels    → battlefield_turn_highlight")
	print("Fix 3: >>SE hints    → technique_list_affinity_hints")
	print("Fix 4: Status icons  → status_icons_burn")
	print("Fix 5: Guard text    → action_menu_interrupt_guard, guard_active_with_label")
	get_tree().quit()


# ==========================================================================
# Helpers
# ==========================================================================

func _capture(label: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "/tmp/glyphrift_%02d_%s.png" % [_shot_index, label]
	image.save_png(path)
	print("Captured: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	_shot_index += 1


func _render_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _log_state(context: String) -> void:
	print("[%s] phase=%d, actor=%s, side=%s, log=%d" % [
		context,
		_engine.phase,
		_engine.current_actor.species.name if _engine.current_actor else "null",
		_engine.current_actor.side if _engine.current_actor else "n/a",
		_scene._combat_log.get_entry_count(),
	])


func _find_player(species_name: String) -> GlyphInstance:
	for g: GlyphInstance in _scene._player_squad:
		if g.species != null and g.species.name == species_name:
			return g
	return null


func _find_technique(glyph: GlyphInstance, tech_id: String) -> TechniqueDef:
	for tech: TechniqueDef in glyph.techniques:
		if tech.id == tech_id:
			return tech
	return null


func _first_alive_enemy() -> GlyphInstance:
	for g: GlyphInstance in _scene._enemy_squad:
		if not g.is_knocked_out:
			return g
	return null
