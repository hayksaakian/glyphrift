class_name DamageCalculator


## Affinity advantage triangle: Electric > Water > Ground > Electric
const ADVANTAGE_MAP: Dictionary = {
	"electric": "water",
	"water": "ground",
	"ground": "electric",
}

const ADVANTAGE_MULT: float = 1.5
const DISADVANTAGE_MULT: float = 0.65
const NEUTRAL_MULT: float = 1.0

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
	if tech_affinity == "neutral":
		return NEUTRAL_MULT
	if not ADVANTAGE_MAP.has(tech_affinity):
		return NEUTRAL_MULT
	if ADVANTAGE_MAP[tech_affinity] == defender_affinity:
		return ADVANTAGE_MULT
	if ADVANTAGE_MAP[defender_affinity] == tech_affinity:
		return DISADVANTAGE_MULT
	return NEUTRAL_MULT


static func has_affinity_advantage(tech_affinity: String, defender_affinity: String) -> bool:
	if tech_affinity == "neutral":
		return false
	return ADVANTAGE_MAP.get(tech_affinity, "") == defender_affinity


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
