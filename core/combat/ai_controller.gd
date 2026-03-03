class_name AIController


static func decide(actor: GlyphInstance, allies: Array[GlyphInstance], enemies: Array[GlyphInstance], data_loader: Node) -> Dictionary:
	## Returns: {"action": "attack"|"guard"|"swap", "technique": TechniqueDef, "target": GlyphInstance}
	var technique: TechniqueDef = _pick_technique(actor, enemies, data_loader)
	var target: GlyphInstance = _pick_target(actor, enemies, technique)

	## If support technique, target self or ally
	if technique.category == "support":
		target = _pick_support_target(actor, allies, technique)

	return {"action": "attack", "technique": technique, "target": target}


static func _pick_technique(actor: GlyphInstance, enemies: Array[GlyphInstance], data_loader: Node) -> TechniqueDef:
	var best: TechniqueDef = null
	var best_power: int = -1

	for tech: TechniqueDef in actor.techniques:
		## Skip interrupts — they trigger passively while guarding
		if tech.category == "interrupt":
			continue
		## Skip if on cooldown
		if not actor.is_technique_ready(tech):
			continue
		## Skip melee if actor is in back row
		if tech.range_type == "melee" and actor.row_position == "back":
			continue
		## Pick highest power technique
		if tech.power > best_power or (tech.power == best_power and tech.category == "offensive"):
			best = tech
			best_power = tech.power

	## If no support technique was picked but it has 0 power, prefer offensive even at 0
	## Fallback to tackle if nothing available
	if best == null:
		best = data_loader.get_technique("tackle")
	return best


static func _pick_target(actor: GlyphInstance, enemies: Array[GlyphInstance], technique: TechniqueDef) -> GlyphInstance:
	var valid_targets: Array[GlyphInstance] = _get_valid_targets(enemies, technique)
	if valid_targets.is_empty():
		## If no valid targets (shouldn't happen), return first alive
		for e: GlyphInstance in enemies:
			if not e.is_knocked_out:
				return e
		return null

	## Priority 1: Can KO this turn
	for target: GlyphInstance in valid_targets:
		var est_damage: int = _estimate_damage(actor, target, technique)
		if est_damage >= target.current_hp:
			return target

	## Priority 2: Affinity advantage
	var advantage_targets: Array[GlyphInstance] = []
	for target: GlyphInstance in valid_targets:
		if DamageCalculator.has_affinity_advantage(technique.affinity, target.species.affinity):
			advantage_targets.append(target)
	if not advantage_targets.is_empty():
		## Among advantage targets, pick lowest HP
		advantage_targets.sort_custom(func(a: GlyphInstance, b: GlyphInstance) -> bool: return a.current_hp < b.current_hp)
		return advantage_targets[0]

	## Priority 3: Lowest current HP
	valid_targets.sort_custom(func(a: GlyphInstance, b: GlyphInstance) -> bool: return a.current_hp < b.current_hp)
	return valid_targets[0]


static func _pick_support_target(actor: GlyphInstance, allies: Array[GlyphInstance], technique: TechniqueDef) -> GlyphInstance:
	## For heals, pick lowest HP% ally. For buffs/shields, pick self or highest ATK ally.
	if technique.support_effect == "heal_percent" or technique.support_effect == "heal_percent_all":
		var best: GlyphInstance = actor
		var lowest_pct: float = float(actor.current_hp) / float(actor.max_hp)
		for ally: GlyphInstance in allies:
			if ally.is_knocked_out:
				continue
			var pct: float = float(ally.current_hp) / float(ally.max_hp)
			if pct < lowest_pct:
				lowest_pct = pct
				best = ally
		return best
	## Default: target self for shield/buff/immunity
	return actor


static func _get_valid_targets(enemies: Array[GlyphInstance], technique: TechniqueDef) -> Array[GlyphInstance]:
	var alive: Array[GlyphInstance] = []
	for e: GlyphInstance in enemies:
		if not e.is_knocked_out:
			alive.append(e)

	if alive.is_empty():
		return alive

	## AoE/Piercing can hit anyone
	if technique.range_type == "aoe" or technique.range_type == "piercing":
		return alive

	## Ranged can hit anyone
	if technique.range_type == "ranged":
		return alive

	## Melee: can only hit front row if front row has living members
	var front_alive: Array[GlyphInstance] = []
	for e: GlyphInstance in alive:
		if e.row_position == "front":
			front_alive.append(e)

	if front_alive.is_empty():
		return alive  ## All front row dead, melee can reach back row
	return front_alive


static func _estimate_damage(attacker: GlyphInstance, defender: GlyphInstance, technique: TechniqueDef) -> int:
	## Quick estimate without variance for AI decision-making
	if technique.category == "support":
		return 0
	var effective_atk: float = attacker.get_effective_atk()
	var effective_def: float = defender.get_effective_def()
	var raw: float = float(technique.power) * (effective_atk / maxf(effective_def, 1.0))
	raw *= DamageCalculator.get_affinity_multiplier(technique.affinity, defender.species.affinity)
	raw *= DamageCalculator.get_row_modifier(technique.range_type, defender.row_position)
	raw *= DamageCalculator.get_shield_modifier(defender)
	raw *= DamageCalculator.get_guard_modifier(defender)
	return maxi(1, int(raw))
