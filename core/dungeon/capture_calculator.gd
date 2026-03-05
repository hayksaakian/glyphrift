class_name CaptureCalculator
extends RefCounted

## GDD 8.11 — Capture probability formula
## chance = min(0.80, 0.40 + max(0, par_turns - actual_turns) * 0.10)
##
## Par turns by enemy squad size:
##   1 enemy → 3 turns
##   2 enemies → 5 turns
##   3 enemies → 6 turns

const BASE_CHANCE: float = 0.40
const TURN_BONUS_PER: float = 0.10
const MAX_CHANCE: float = 0.80

const PAR_TURNS: Dictionary = {
	1: 3,
	2: 5,
	3: 6,
}


static func get_par_turns(enemy_count: int) -> int:
	if PAR_TURNS.has(enemy_count):
		return PAR_TURNS[enemy_count]
	## Default: scale linearly for 4+ enemies (unlikely but safe)
	return enemy_count * 2


static func calculate_chance(enemy_count: int, actual_turns: int, item_bonus: float = 0.0) -> float:
	var bd: Dictionary = get_breakdown(enemy_count, actual_turns, item_bonus)
	return bd["total"]


## Returns a breakdown of all capture chance modifiers.
static func get_breakdown(enemy_count: int, actual_turns: int, item_bonus: float = 0.0) -> Dictionary:
	var par: int = get_par_turns(enemy_count)
	var turn_bonus: float = maxf(0.0, float(par - actual_turns) * TURN_BONUS_PER)
	var total: float = minf(MAX_CHANCE, BASE_CHANCE + turn_bonus + item_bonus)
	return {
		"base": BASE_CHANCE,
		"turn_bonus": turn_bonus,
		"item_bonus": item_bonus,
		"total": total,
		"capped": (BASE_CHANCE + turn_bonus + item_bonus) > MAX_CHANCE,
	}
