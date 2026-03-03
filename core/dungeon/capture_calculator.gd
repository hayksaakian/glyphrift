class_name CaptureCalculator
extends RefCounted

## GDD 8.11 — Capture probability formula
## chance = min(0.80, 0.40 + max(0, par_turns - actual_turns) * 0.10 + (0.15 if no_player_ko))
##
## Par turns by enemy squad size:
##   1 enemy → 3 turns
##   2 enemies → 5 turns
##   3 enemies → 6 turns

const BASE_CHANCE: float = 0.40
const TURN_BONUS_PER: float = 0.10
const NO_KO_BONUS: float = 0.15
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


static func calculate_chance(enemy_count: int, actual_turns: int, player_had_ko: bool) -> float:
	var par: int = get_par_turns(enemy_count)
	var turn_bonus: float = maxf(0.0, float(par - actual_turns) * TURN_BONUS_PER)
	var ko_bonus: float = 0.0 if player_had_ko else NO_KO_BONUS
	return minf(MAX_CHANCE, BASE_CHANCE + turn_bonus + ko_bonus)
