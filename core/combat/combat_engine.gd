extends Node

## Signals per TDD 6.3
signal battle_started(player_squad: Array[GlyphInstance], enemy_squad: Array[GlyphInstance])
signal turn_started(glyph: GlyphInstance, turn_index: int)
signal technique_used(user: GlyphInstance, technique: TechniqueDef, target: GlyphInstance, damage: int)
signal glyph_ko(glyph: GlyphInstance, attacker: GlyphInstance)
signal glyph_dealt_finishing_blow(attacker: GlyphInstance, target: GlyphInstance)
signal interrupt_triggered(defender: GlyphInstance, technique: TechniqueDef, attacker: GlyphInstance)
signal status_applied(target: GlyphInstance, status_id: String)
signal status_expired(target: GlyphInstance, status_id: String)
signal status_resisted(target: GlyphInstance, status_id: String)
signal status_immune(target: GlyphInstance, status_id: String)
signal affinity_advantage_hit(attacker: GlyphInstance, target: GlyphInstance)
signal guard_activated(glyph: GlyphInstance)
signal swap_performed(glyph: GlyphInstance)
signal battle_won(player_squad: Array[GlyphInstance], turns_taken: int, ko_list: Array[GlyphInstance])
signal battle_lost(player_squad: Array[GlyphInstance])
signal turn_queue_updated(queue: Array[GlyphInstance])
signal phase_transition(boss: GlyphInstance, changes: Dictionary)
signal burn_damage(glyph: GlyphInstance, damage: int)
signal round_started(round_number: int)

enum BattlePhase { INACTIVE, FORMATION, TURN_ACTIVE, ANIMATING, VICTORY, DEFEAT }

var phase: int = BattlePhase.INACTIVE
var data_loader: Node = null

var player_squad: Array[GlyphInstance] = []
var enemy_squad: Array[GlyphInstance] = []
var turn_queue: TurnQueue = TurnQueue.new()
var turn_count: int = 0
var round_number: int = 0
var ko_list: Array[GlyphInstance] = []

## When true, AI controls player side too (for testing)
var auto_battle: bool = false

## Track whose turn it is for external UI queries
var current_actor: GlyphInstance = null

## Boss reference for phase tracking
var _boss: GlyphInstance = null
var _boss_def: BossDef = null
var is_boss_battle: bool = false


func _ready() -> void:
	if has_node("/root/DataLoader"):
		data_loader = get_node("/root/DataLoader")


func start_battle(p_squad: Array[GlyphInstance], e_squad: Array[GlyphInstance], boss_def: BossDef = null) -> void:
	player_squad = p_squad
	enemy_squad = e_squad
	turn_count = 0
	round_number = 0
	ko_list.clear()
	_boss = null
	_boss_def = boss_def
	is_boss_battle = boss_def != null

	## Reset combat state for all glyphs
	for g: GlyphInstance in player_squad:
		g.reset_combat_state()
		g.side = "player"
	for g: GlyphInstance in enemy_squad:
		g.reset_combat_state()
		g.side = "enemy"

	## Tag boss
	if is_boss_battle and not enemy_squad.is_empty():
		_boss = enemy_squad[0]
		_boss.is_boss = true

	phase = BattlePhase.FORMATION
	battle_started.emit(player_squad, enemy_squad)


func set_formation(player_positions: Dictionary = {}, enemy_positions: Dictionary = {}) -> void:
	## player_positions: {glyph_instance_id: "front"/"back"}
	## If empty, use default: first 2 front, rest back
	_assign_default_positions(player_squad, player_positions)
	_assign_default_positions(enemy_squad, enemy_positions)

	phase = BattlePhase.TURN_ACTIVE
	_start_new_round()


func _assign_default_positions(squad: Array[GlyphInstance], overrides: Dictionary) -> void:
	var front_count: int = 0
	for i: int in range(squad.size()):
		var g: GlyphInstance = squad[i]
		if overrides.has(g.instance_id):
			g.row_position = overrides[g.instance_id]
		elif front_count < 2:
			g.row_position = "front"
			front_count += 1
		else:
			g.row_position = "back"


func _start_new_round() -> void:
	round_number += 1
	round_started.emit(round_number)

	var all_glyphs: Array[GlyphInstance] = _get_all_alive()
	var is_first: bool = round_number == 1 and is_boss_battle
	turn_queue.build(all_glyphs, is_first)
	turn_queue_updated.emit(turn_queue.get_all())

	_advance_turn()


func _get_all_alive() -> Array[GlyphInstance]:
	var alive: Array[GlyphInstance] = []
	for g: GlyphInstance in player_squad:
		if not g.is_knocked_out:
			alive.append(g)
	for g: GlyphInstance in enemy_squad:
		if not g.is_knocked_out:
			alive.append(g)
	return alive


func _advance_turn() -> void:
	## Check for battle end
	if _all_knocked_out(player_squad):
		phase = BattlePhase.DEFEAT
		battle_lost.emit(player_squad)
		return
	if _all_knocked_out(enemy_squad):
		phase = BattlePhase.VICTORY
		battle_won.emit(player_squad, turn_count, ko_list)
		return

	## Check if round is complete
	if turn_queue.is_round_complete():
		_start_new_round()
		return

	current_actor = turn_queue.current()
	if current_actor == null:
		_start_new_round()
		return

	## Skip knocked out glyphs
	if current_actor.is_knocked_out:
		turn_queue.advance()
		_advance_turn()
		return

	turn_count += 1
	current_actor.took_turn_this_battle = true

	## Clear guard from previous round
	current_actor.is_guarding = false

	## Clear immunity timers at start of turn
	StatusManager.clear_immunities_tick(current_actor)

	## Tick cooldowns
	current_actor.tick_cooldowns()

	## Check stun — skip turn if stunned
	if StatusManager.is_stunned(current_actor):
		turn_started.emit(current_actor, turn_count)
		## Tick statuses (will process burn and decrement stun)
		var tick_result: Dictionary = StatusManager.tick(current_actor)
		if tick_result["burn_damage"] > 0:
			burn_damage.emit(current_actor, tick_result["burn_damage"])
		for expired_id: String in tick_result["expired"]:
			status_expired.emit(current_actor, expired_id)
		_check_ko(current_actor, null)
		turn_queue.advance()
		_advance_turn()
		return

	turn_started.emit(current_actor, turn_count)

	## Determine action
	if auto_battle or current_actor.side == "enemy":
		var allies: Array[GlyphInstance] = _get_squad_alive(current_actor.side)
		var enemies: Array[GlyphInstance] = _get_enemies_alive(current_actor.side)
		var decision: Dictionary = AIController.decide(current_actor, allies, enemies, data_loader)
		_execute_action(current_actor, decision)
	## else: wait for UI input via submit_action()


func submit_action(action: Dictionary) -> void:
	## Called by UI when player chooses an action
	if phase != BattlePhase.TURN_ACTIVE or current_actor == null:
		return
	_execute_action(current_actor, action)


func _execute_action(actor: GlyphInstance, action: Dictionary) -> void:
	var action_type: String = action.get("action", "attack")

	match action_type:
		"guard":
			_execute_guard(actor)
		"swap":
			_execute_swap(actor)
		_:
			_execute_attack(actor, action["technique"], action["target"])

	## Tick statuses at end of turn (burn, duration countdown)
	var tick_result: Dictionary = StatusManager.tick(actor)
	if tick_result["burn_damage"] > 0:
		burn_damage.emit(actor, tick_result["burn_damage"])
	for expired_id: String in tick_result["expired"]:
		status_expired.emit(actor, expired_id)
	_check_ko(actor, null)

	turn_queue.advance()
	_advance_turn()


func _execute_guard(actor: GlyphInstance) -> void:
	actor.is_guarding = true
	guard_activated.emit(actor)


func _execute_swap(actor: GlyphInstance) -> void:
	actor.row_position = "back" if actor.row_position == "front" else "front"
	swap_performed.emit(actor)


func _execute_attack(actor: GlyphInstance, technique: TechniqueDef, target: GlyphInstance) -> void:
	## Handle support techniques
	if technique.category == "support":
		_execute_support(actor, technique, target)
		actor.put_on_cooldown(technique)
		return

	## Check for interrupts from guarding defenders
	var was_interrupted: bool = _check_interrupts(actor, technique, target)
	if was_interrupted:
		## Some interrupts cancel the attack entirely (e.g., Stone Wall, Disrupt)
		## The interrupt handler already put the interrupt on cooldown
		## Still put attacker's technique on cooldown
		actor.put_on_cooldown(technique)
		return

	## Handle AoE — hits all enemies of actor
	if technique.range_type == "aoe":
		_execute_aoe_attack(actor, technique)
		actor.put_on_cooldown(technique)
		return

	## Single target attack
	var damage: int = DamageCalculator.calculate(actor, target, technique)
	target.current_hp -= damage
	if target.current_hp < 0:
		target.current_hp = 0

	## Check affinity advantage
	if DamageCalculator.has_affinity_advantage(technique.affinity, target.species.affinity):
		affinity_advantage_hit.emit(actor, target)

	technique_used.emit(actor, technique, target, damage)

	## Apply status effect if technique has one
	_try_apply_status(actor, target, technique)

	## Boss phase transition check (before KO so boss can survive at phase 2)
	if target.is_boss:
		_check_boss_phase_transition(target)

	## Check KO
	_check_ko(target, actor)


func _execute_aoe_attack(actor: GlyphInstance, technique: TechniqueDef) -> void:
	var targets: Array[GlyphInstance] = _get_enemies_alive(actor.side)
	for target: GlyphInstance in targets:
		var damage: int = DamageCalculator.calculate(actor, target, technique)
		target.current_hp -= damage
		if target.current_hp < 0:
			target.current_hp = 0

		if DamageCalculator.has_affinity_advantage(technique.affinity, target.species.affinity):
			affinity_advantage_hit.emit(actor, target)

		technique_used.emit(actor, technique, target, damage)
		_try_apply_status(actor, target, technique)
		if target.is_boss:
			_check_boss_phase_transition(target)
		_check_ko(target, actor)


func _execute_support(actor: GlyphInstance, technique: TechniqueDef, target: GlyphInstance) -> void:
	## Check for Disrupt interrupt
	var was_interrupted: bool = _check_interrupts(actor, technique, target)
	if was_interrupted:
		actor.put_on_cooldown(technique)
		return

	match technique.support_effect:
		"shield":
			StatusManager.apply(target, "shield")
			status_applied.emit(target, "shield")
			technique_used.emit(actor, technique, target, 0)
		"heal_percent":
			var heal_amount: int = int(float(target.max_hp) * technique.support_value)
			var actual_heal: int = mini(heal_amount, target.max_hp - target.current_hp)
			target.current_hp = mini(target.current_hp + heal_amount, target.max_hp)
			technique_used.emit(actor, technique, target, actual_heal)
		"heal_percent_all":
			var allies: Array[GlyphInstance] = _get_squad_alive(actor.side)
			for ally: GlyphInstance in allies:
				var heal_amount: int = int(float(ally.max_hp) * technique.support_value)
				var actual_heal: int = mini(heal_amount, ally.max_hp - ally.current_hp)
				ally.current_hp = mini(ally.current_hp + heal_amount, ally.max_hp)
				technique_used.emit(actor, technique, ally, actual_heal)
		"atk_buff":
			## Temporary ATK boost — apply directly (not via calculate_stats which resets HP)
			## Revisit with proper buff system for duration tracking later
			target.atk += int(float(target.atk) * technique.support_value)
			technique_used.emit(actor, technique, target, 0)
		"status_immunity":
			## Grant immunity to all status types
			for status_id: String in StatusManager.DURATIONS:
				if StatusManager.DURATIONS[status_id] > 0:
					target.status_immunities[status_id] = 99
			technique_used.emit(actor, technique, target, 0)


func _try_apply_status(attacker: GlyphInstance, target: GlyphInstance, technique: TechniqueDef) -> void:
	if technique.status_effect == "" or technique.status_accuracy <= 0:
		return
	if target.is_knocked_out:
		return

	var result: String = StatusManager.try_apply(target, technique.status_effect, technique.status_accuracy)
	match result:
		"applied":
			status_applied.emit(target, technique.status_effect)
		"resisted":
			status_resisted.emit(target, technique.status_effect)
		"immune":
			status_immune.emit(target, technique.status_effect)


func _check_interrupts(attacker: GlyphInstance, technique: TechniqueDef, _target: GlyphInstance) -> bool:
	## Find all guarding defenders with matching interrupt triggers
	var defenders: Array[GlyphInstance] = _get_enemies_alive(attacker.side)
	var trigger: String = _get_interrupt_trigger(technique)
	if trigger == "":
		return false

	## Collect candidates: guarding defenders with matching off-cooldown interrupt
	var candidates: Array[Dictionary] = []
	for defender: GlyphInstance in defenders:
		if not defender.is_guarding:
			continue
		for tech: TechniqueDef in defender.techniques:
			if tech.category != "interrupt":
				continue
			if tech.interrupt_trigger != trigger:
				continue
			if not defender.is_technique_ready(tech):
				continue
			candidates.append({"defender": defender, "technique": tech})
			break  ## Only one interrupt per defender

	if candidates.is_empty():
		return false

	## Highest SPD defender fires
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["defender"] as GlyphInstance).get_effective_spd() > (b["defender"] as GlyphInstance).get_effective_spd()
	)

	var chosen: Dictionary = candidates[0]
	var defender: GlyphInstance = chosen["defender"]
	var int_tech: TechniqueDef = chosen["technique"]

	interrupt_triggered.emit(defender, int_tech, attacker)
	defender.put_on_cooldown(int_tech)

	## Resolve interrupt effects based on the specific technique
	return _resolve_interrupt(defender, int_tech, attacker, technique)


func _resolve_interrupt(defender: GlyphInstance, int_tech: TechniqueDef, attacker: GlyphInstance, attack_tech: TechniqueDef) -> bool:
	## Returns true if the attack should be cancelled
	match int_tech.id:
		"static_guard":
			## Deals damage to attacker, reduces incoming hit by 50%
			## We handle reduction by letting the attack proceed but with guard active
			## The damage is: fixed power of interrupt technique
			var int_damage: int = DamageCalculator.calculate(defender, attacker, int_tech)
			attacker.current_hp -= int_damage
			if attacker.current_hp < 0:
				attacker.current_hp = 0
			technique_used.emit(defender, int_tech, attacker, int_damage)
			_check_ko(attacker, defender)
			return false  ## Attack still proceeds (guard provides 50% reduction)
		"stone_wall":
			## Blocks the incoming attack entirely
			technique_used.emit(defender, int_tech, attacker, 0)
			return true
		"phase_shift":
			## Defender takes 0 from AoE (allies still take damage)
			## Don't cancel; handled specially in AoE resolution
			technique_used.emit(defender, int_tech, attacker, 0)
			return false
		"null_counter":
			## Deals damage to attacker, doesn't reduce incoming
			var int_damage: int = DamageCalculator.calculate(defender, attacker, int_tech)
			attacker.current_hp -= int_damage
			if attacker.current_hp < 0:
				attacker.current_hp = 0
			technique_used.emit(defender, int_tech, attacker, int_damage)
			_check_ko(attacker, defender)
			return false
		"tremor_response":
			## Applies Slow to attacker
			var result: String = StatusManager.try_apply(attacker, "slow", 70)
			if result == "applied":
				status_applied.emit(attacker, "slow")
			technique_used.emit(defender, int_tech, attacker, 0)
			return false
		"disrupt":
			## Cancels support technique entirely
			technique_used.emit(defender, int_tech, attacker, 0)
			return true
	return false


func _get_interrupt_trigger(technique: TechniqueDef) -> String:
	if technique.category == "support":
		return "ON_SUPPORT"
	match technique.range_type:
		"melee":
			return "ON_MELEE"
		"ranged":
			return "ON_RANGED"
		"aoe":
			return "ON_AOE"
	return ""


func _check_ko(glyph: GlyphInstance, attacker: GlyphInstance) -> void:
	if glyph.current_hp <= 0 and not glyph.is_knocked_out:
		glyph.is_knocked_out = true
		glyph.current_hp = 0
		glyph_ko.emit(glyph, attacker)
		ko_list.append(glyph)
		if attacker != null:
			glyph_dealt_finishing_blow.emit(attacker, glyph)


func _check_boss_phase_transition(boss: GlyphInstance) -> void:
	if boss != _boss or _boss_def == null:
		return
	if boss.boss_phase >= 2:
		return
	if boss.current_hp > 0 and boss.current_hp <= boss.max_hp / 2:
		boss.boss_phase = 2
		## Clear all status effects
		StatusManager.clear_all(boss)
		## Apply phase 2 stat bonuses
		var atk_bonus: float = _boss_def.phase2_stat_bonus.get("atk", 0.0)
		var spd_bonus: float = _boss_def.phase2_stat_bonus.get("spd", 0.0)
		## Apply stat bonuses directly (not via calculate_stats which resets current_hp)
		boss.atk = int(float(boss.atk) * (1.0 + atk_bonus))
		boss.spd = int(float(boss.spd) * (1.0 + spd_bonus))
		## Build changes dictionary for UI communication
		var changes: Dictionary = {}
		if atk_bonus > 0:
			changes["atk"] = "+%d%%" % int(atk_bonus * 100)
		if spd_bonus > 0:
			changes["spd"] = "+%d%%" % int(spd_bonus * 100)
		## Add phase 2 techniques (respect 4-technique cap per TDD)
		var new_tech_names: Array[String] = []
		for tid: String in _boss_def.phase2_technique_ids:
			if boss.techniques.size() >= 4:
				break
			var tech: TechniqueDef = data_loader.get_technique(tid)
			if tech != null:
				var already_has: bool = false
				for existing: TechniqueDef in boss.techniques:
					if existing.id == tid:
						already_has = true
						break
				if not already_has:
					boss.techniques.append(tech)
					new_tech_names.append(tech.name)
		if not new_tech_names.is_empty():
			changes["new_techniques"] = new_tech_names
		phase_transition.emit(boss, changes)


func _get_squad_alive(side: String) -> Array[GlyphInstance]:
	var squad: Array[GlyphInstance] = player_squad if side == "player" else enemy_squad
	var alive: Array[GlyphInstance] = []
	for g: GlyphInstance in squad:
		if not g.is_knocked_out:
			alive.append(g)
	return alive


func _get_enemies_alive(side: String) -> Array[GlyphInstance]:
	var enemy_side: String = "enemy" if side == "player" else "player"
	return _get_squad_alive(enemy_side)


func forfeit() -> void:
	phase = BattlePhase.DEFEAT
	battle_lost.emit(player_squad)


func _all_knocked_out(squad: Array[GlyphInstance]) -> bool:
	for g: GlyphInstance in squad:
		if not g.is_knocked_out:
			return false
	return true
