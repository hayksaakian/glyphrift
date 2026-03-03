class_name MasteryTracker
extends RefCounted

## Connects to CombatEngine signals and evaluates mastery objectives
## for all player Glyphs. Per TDD 6.9.

signal objective_completed(glyph: GlyphInstance, objective_index: int)
signal glyph_mastered(glyph: GlyphInstance)

## Injectable combat engine reference (autoloads unavailable in --script tests)
var combat_engine: Node = null

## Per-battle tracking
var _battle_flags: Dictionary = {}          ## instance_id → Dictionary of flags
var _enemy_squad: Array[GlyphInstance] = []
var _first_actor_id: int = -1
var _last_technique_by_glyph: Dictionary = {} ## instance_id → TechniqueDef


func connect_to_combat(engine: Node) -> void:
	combat_engine = engine
	engine.battle_started.connect(_on_battle_started)
	engine.battle_won.connect(_on_battle_won)
	engine.technique_used.connect(_on_technique_used)
	engine.affinity_advantage_hit.connect(_on_affinity_advantage_hit)
	engine.interrupt_triggered.connect(_on_interrupt_triggered)
	engine.glyph_dealt_finishing_blow.connect(_on_finishing_blow)
	engine.status_applied.connect(_on_status_applied)
	engine.turn_started.connect(_on_turn_started)


func disconnect_from_combat() -> void:
	if combat_engine == null:
		return
	combat_engine.battle_started.disconnect(_on_battle_started)
	combat_engine.battle_won.disconnect(_on_battle_won)
	combat_engine.technique_used.disconnect(_on_technique_used)
	combat_engine.affinity_advantage_hit.disconnect(_on_affinity_advantage_hit)
	combat_engine.interrupt_triggered.disconnect(_on_interrupt_triggered)
	combat_engine.glyph_dealt_finishing_blow.disconnect(_on_finishing_blow)
	combat_engine.status_applied.disconnect(_on_status_applied)
	combat_engine.turn_started.disconnect(_on_turn_started)
	combat_engine = null


## Build mastery track for a glyph: 2 fixed + 1 random (T4 gets none)
static func build_mastery_track(sp: GlyphSpecies, mastery_pools: Dictionary) -> Array[Dictionary]:
	if sp.tier == 4:
		return []

	var objectives: Array[Dictionary] = []
	## 2 fixed objectives from species
	for obj: Dictionary in sp.fixed_mastery_objectives:
		var copy: Dictionary = obj.duplicate(true)
		copy["completed"] = false
		objectives.append(copy)

	## 1 random from tier pool
	var pool: Array = mastery_pools.get(sp.tier, [])
	if pool.size() > 0:
		var random_obj: Dictionary = pool[randi() % pool.size()].duplicate(true)
		random_obj["completed"] = false
		objectives.append(random_obj)

	return objectives


# --- Signal Handlers ---


func _on_battle_started(
	_p_squad: Array[GlyphInstance],
	e_squad: Array[GlyphInstance]
) -> void:
	_battle_flags.clear()
	_last_technique_by_glyph.clear()
	_first_actor_id = -1
	_enemy_squad = e_squad


func _on_turn_started(glyph: GlyphInstance, _turn_idx: int) -> void:
	## Track the very first actor in the battle
	if _first_actor_id == -1:
		_first_actor_id = glyph.instance_id


func _on_battle_won(
	squad: Array[GlyphInstance],
	turns_taken: int,
	ko_list: Array[GlyphInstance]
) -> void:
	for glyph: GlyphInstance in squad:
		if not glyph.took_turn_this_battle or glyph.is_mastered:
			continue
		if glyph.species.tier == 4:
			continue

		var flags: Dictionary = _get_flags(glyph.instance_id)
		var player_kos: Array[GlyphInstance] = []
		for ko: GlyphInstance in ko_list:
			if ko.side == "player":
				player_kos.append(ko)

		var participants: Array[GlyphInstance] = squad.filter(
			func(g: GlyphInstance) -> bool: return g.took_turn_this_battle
		)

		_evaluate_objectives(glyph, "battle_won", {
			"turns": turns_taken,
			"no_ko": not ko_list.has(glyph),
			"squad_no_ko": player_kos.is_empty(),
			"solo": participants.size() == 1 and participants[0] == glyph,
			"row": glyph.row_position,
			"had_advantage": flags.get("had_advantage", false),
			"at_disadvantage": _is_at_disadvantage(glyph),
			"is_boss_battle": combat_engine.is_boss_battle if combat_engine else false,
			"enemy_count": _enemy_squad.size(),
			"finishing_blows": flags.get("finishing_blows", 0),
			"killed_higher_tier": flags.get("killed_higher_tier", false),
			"is_first_actor": glyph.instance_id == _first_actor_id,
		})


func _on_technique_used(
	user: GlyphInstance,
	technique: TechniqueDef,
	_target: GlyphInstance,
	_damage: int
) -> void:
	_last_technique_by_glyph[user.instance_id] = technique

	if user.is_mastered or user.species.tier == 4:
		return
	_evaluate_objectives(user, "technique_used", {
		"technique_id": technique.id,
	})


func _on_affinity_advantage_hit(
	attacker: GlyphInstance,
	_target: GlyphInstance
) -> void:
	var flags: Dictionary = _get_flags(attacker.instance_id)
	flags["had_advantage"] = true


func _on_interrupt_triggered(
	defender: GlyphInstance,
	_technique: TechniqueDef,
	_attacker: GlyphInstance
) -> void:
	if defender.is_mastered or defender.species.tier == 4:
		return
	_evaluate_objectives(defender, "interrupt_triggered", {})


func _on_finishing_blow(
	attacker: GlyphInstance,
	target: GlyphInstance
) -> void:
	var flags: Dictionary = _get_flags(attacker.instance_id)
	flags["finishing_blows"] = flags.get("finishing_blows", 0) + 1
	if target.species.tier > attacker.species.tier:
		flags["killed_higher_tier"] = true

	if attacker.is_mastered or attacker.species.tier == 4:
		return

	## Immediate objectives (don't require battle win)
	var tech: TechniqueDef = _last_technique_by_glyph.get(attacker.instance_id)
	_evaluate_objectives(attacker, "finishing_blow", {
		"target_tier": target.species.tier,
		"technique_id": tech.id if tech else "",
	})


func _on_status_applied(
	target: GlyphInstance,
	status_id: String
) -> void:
	## Find who applied the status (last technique user targeting this glyph)
	## technique_used fires before status_applied in CombatEngine
	for glyph_id: int in _last_technique_by_glyph:
		var tech: TechniqueDef = _last_technique_by_glyph[glyph_id]
		if tech.status_effect == status_id:
			## This glyph likely applied the status
			var applicant_id: int = glyph_id
			## Find the actual glyph instance
			var applicant: GlyphInstance = _find_glyph_by_id(applicant_id)
			if applicant != null and not applicant.is_mastered and applicant.species.tier != 4:
				_evaluate_objectives(applicant, "status_applied", {
					"status_id": status_id,
					"technique_id": tech.id,
					"target_instance_id": target.instance_id,
				})
			break


# --- Objective Evaluation ---


func _evaluate_objectives(
	glyph: GlyphInstance,
	event_type: String,
	event_data: Dictionary
) -> void:
	for i: int in range(glyph.mastery_objectives.size()):
		var obj: Dictionary = glyph.mastery_objectives[i]
		if obj.get("completed", false):
			continue
		if _check_objective(obj, event_type, event_data, glyph):
			obj["completed"] = true
			objective_completed.emit(glyph, i)
			_check_mastery_complete(glyph)


func _check_objective(
	objective: Dictionary,
	event_type: String,
	event_data: Dictionary,
	glyph: GlyphInstance
) -> bool:
	var obj_type: String = objective.get("type", "")
	var params: Dictionary = objective.get("params", {})

	match obj_type:
		"win_with_advantage":
			return event_type == "battle_won" and event_data.get("had_advantage", false)

		"win_battle_no_ko":
			return event_type == "battle_won" and event_data.get("no_ko", false)

		"win_battle_front_row":
			return event_type == "battle_won" and event_data.get("row", "") == "front"

		"win_battle_back_row":
			return event_type == "battle_won" and event_data.get("row", "") == "back"

		"use_technique_count":
			if event_type == "technique_used" and event_data.get("technique_id", "") == params.get("technique_id", ""):
				params["current"] = params.get("current", 0) + 1
				return params["current"] >= params.get("target", 1)
			return false

		"capture_participated":
			return event_type == "capture_occurred"

		"win_at_disadvantage":
			return event_type == "battle_won" and event_data.get("at_disadvantage", false)

		"win_vs_3_enemies":
			return event_type == "battle_won" and event_data.get("enemy_count", 0) >= params.get("enemy_count", 3)

		"trigger_interrupt":
			return event_type == "interrupt_triggered"

		"win_battle_in_turns":
			return event_type == "battle_won" and event_data.get("turns", 99) <= params.get("max_turns", 99)

		"finishing_blow_count":
			return event_type == "battle_won" and event_data.get("finishing_blows", 0) >= params.get("target", 1)

		"solo_win":
			return event_type == "battle_won" and event_data.get("solo", false)

		"squad_no_ko":
			return event_type == "battle_won" and event_data.get("squad_no_ko", false)

		"finishing_blow_higher_tier":
			return event_type == "battle_won" and event_data.get("killed_higher_tier", false)

		"boss_win":
			return event_type == "battle_won" and event_data.get("is_boss_battle", false)

		"first_turn":
			return event_type == "battle_won" and event_data.get("is_first_actor", false)

		"apply_status":
			return (event_type == "status_applied"
				and event_data.get("status_id", "") == params.get("status_id", "")
				and event_data.get("technique_id", "") == params.get("technique_id", ""))

		"apply_status_count":
			if event_type == "status_applied" and event_data.get("status_id", "") == params.get("status_id", ""):
				params["current"] = params.get("current", 0) + 1
				return params["current"] >= params.get("target", 1)
			return false

		"finishing_blow_with_technique":
			return (event_type == "finishing_blow"
				and event_data.get("technique_id", "") == params.get("technique_id", ""))

		"win_vs_3_no_ko":
			return (event_type == "battle_won"
				and event_data.get("enemy_count", 0) >= 3
				and event_data.get("squad_no_ko", false))

		## Complex species-specific objectives — stubs for prototype
		"brace_then_survive", "tank_most_damage", "burn_then_kill", \
		"stun_then_kill", "heal_low_hp_ally", "weaken_then_null_beam":
			return false

	return false


func _check_mastery_complete(glyph: GlyphInstance) -> void:
	for obj: Dictionary in glyph.mastery_objectives:
		if not obj.get("completed", false):
			return
	## All objectives complete — GDD 6.4
	glyph.is_mastered = true
	glyph.mastery_bonus_applied = true
	glyph.calculate_stats()
	glyph_mastered.emit(glyph)


# --- Helpers ---


func _get_flags(instance_id: int) -> Dictionary:
	if not _battle_flags.has(instance_id):
		_battle_flags[instance_id] = {
			"had_advantage": false,
			"finishing_blows": 0,
			"killed_higher_tier": false,
		}
	return _battle_flags[instance_id]


func _is_at_disadvantage(glyph: GlyphInstance) -> bool:
	## Check if any enemy in this battle has affinity advantage over this glyph
	var g_aff: String = glyph.species.affinity
	for enemy: GlyphInstance in _enemy_squad:
		if DamageCalculator.has_affinity_advantage(enemy.species.affinity, g_aff):
			return true
	return false


func _find_glyph_by_id(instance_id: int) -> GlyphInstance:
	if combat_engine == null:
		return null
	for g: GlyphInstance in combat_engine.player_squad:
		if g.instance_id == instance_id:
			return g
	for g: GlyphInstance in combat_engine.enemy_squad:
		if g.instance_id == instance_id:
			return g
	return null
