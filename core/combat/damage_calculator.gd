class_name DamageCalculator


## Affinity matchup matrix: AFFINITY_MATRIX[attack][defend] = multiplier
## Only non-1.0 entries need to be listed. Missing pairs default to 1.0.
const AFFINITY_MATRIX: Dictionary = {
	"electric": {"water": 1.5, "ground": 0.65},
	"water": {"ground": 1.5, "electric": 0.65},
	"ground": {"electric": 1.5, "water": 0.65},
}

const DEFAULT_MULT: float = 1.0

const BACK_ROW_REDUCTION: float = 0.7
const SHIELD_REDUCTION: float = 0.75
const GUARD_REDUCTION: float = 0.5


static func calculate(attacker: GlyphInstance, defender: GlyphInstance, technique: TechniqueDef) -> int:
	## Support techniques deal no damage
	if technique.category == "support":
		return 0

	var effective_atk: float = attacker.get_effective_atk()
	var effective_def: float = defender.get_effective_def()

	var raw: float = float(technique.power) * (effective_atk / maxf(effective_def, 1.0))

	## Affinity multiplier (technique affinity vs defender species affinity)
	raw *= get_affinity_multiplier(technique.affinity, defender.species.affinity)

	## Row modifier
	raw *= get_row_modifier(technique.range_type, defender.row_position)

	## Shield modifier
	raw *= get_shield_modifier(defender)

	## Guard modifier
	raw *= get_guard_modifier(defender)

	## Variance ±10%
	var variance: float = randf_range(0.9, 1.1)
	raw *= variance

	return maxi(1, int(raw))


static func calculate_fixed(attacker: GlyphInstance, defender: GlyphInstance, technique: TechniqueDef, variance: float) -> int:
	## Deterministic version for testing — caller provides variance
	if technique.category == "support":
		return 0

	var effective_atk: float = attacker.get_effective_atk()
	var effective_def: float = defender.get_effective_def()

	var raw: float = float(technique.power) * (effective_atk / maxf(effective_def, 1.0))
	raw *= get_affinity_multiplier(technique.affinity, defender.species.affinity)
	raw *= get_row_modifier(technique.range_type, defender.row_position)
	raw *= get_shield_modifier(defender)
	raw *= get_guard_modifier(defender)
	raw *= variance

	return maxi(1, int(raw))


static func get_affinity_multiplier(tech_affinity: String, defender_affinity: String) -> float:
	if not AFFINITY_MATRIX.has(tech_affinity):
		return DEFAULT_MULT
	return AFFINITY_MATRIX[tech_affinity].get(defender_affinity, DEFAULT_MULT)


static func has_affinity_advantage(tech_affinity: String, defender_affinity: String) -> bool:
	if not AFFINITY_MATRIX.has(tech_affinity):
		return false
	return AFFINITY_MATRIX[tech_affinity].get(defender_affinity, DEFAULT_MULT) > DEFAULT_MULT


static func get_row_modifier(range_type: String, defender_row: String) -> float:
	if defender_row != "back":
		return 1.0
	## Back row takes reduced damage from melee and ranged, full from aoe/piercing
	if range_type == "melee" or range_type == "ranged":
		return BACK_ROW_REDUCTION
	return 1.0


static func get_shield_modifier(defender: GlyphInstance) -> float:
	if defender.active_statuses.has("shield"):
		return SHIELD_REDUCTION
	return 1.0


static func get_guard_modifier(defender: GlyphInstance) -> float:
	if defender.is_guarding:
		return GUARD_REDUCTION
	return 1.0
