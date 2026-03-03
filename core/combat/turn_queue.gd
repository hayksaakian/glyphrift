class_name TurnQueue
extends RefCounted

var _queue: Array[GlyphInstance] = []
var _index: int = 0


func build(glyphs: Array[GlyphInstance], boss_battle_first_round: bool = false) -> void:
	_queue.clear()
	_index = 0

	## Separate boss from non-boss glyphs for first-round handling
	var bosses: Array[GlyphInstance] = []
	var non_bosses: Array[GlyphInstance] = []

	for g: GlyphInstance in glyphs:
		if g.is_knocked_out:
			continue
		if boss_battle_first_round and g.is_boss:
			bosses.append(g)
		else:
			non_bosses.append(g)

	## Sort non-bosses by effective SPD descending, deterministic tiebreak
	non_bosses.sort_custom(compare_spd)

	_queue = non_bosses
	## Boss acts last on turn 1
	_queue.append_array(bosses)

	## Reset turn tracking
	for g: GlyphInstance in _queue:
		g.took_turn_this_round = false


func build_new_round(glyphs: Array[GlyphInstance]) -> void:
	## Subsequent rounds: normal SPD ordering, no boss-last rule
	build(glyphs, false)


func current() -> GlyphInstance:
	if _index >= _queue.size():
		return null
	return _queue[_index]


func advance() -> GlyphInstance:
	if _index < _queue.size():
		_queue[_index].took_turn_this_round = true
	_index += 1
	if _index >= _queue.size():
		return null
	return _queue[_index]


func is_round_complete() -> bool:
	return _index >= _queue.size()


func get_preview(count: int) -> Array[GlyphInstance]:
	var result: Array[GlyphInstance] = []
	var start: int = _index
	for i: int in range(start, mini(start + count, _queue.size())):
		result.append(_queue[i])
	return result


func get_all() -> Array[GlyphInstance]:
	return _queue.duplicate()


## Affinity speed priority: electric (fast) > ground (steady) > water (fluid)
const AFFINITY_PRIORITY: Dictionary = {"electric": 0, "ground": 1, "water": 2}


static func compare_spd(a: GlyphInstance, b: GlyphInstance) -> bool:
	## Primary: higher effective SPD goes first
	var spd_a: float = a.get_effective_spd()
	var spd_b: float = b.get_effective_spd()
	if spd_a != spd_b:
		return spd_a > spd_b

	## Tiebreak 1: higher tier acts first
	var tier_a: int = a.species.tier if a.species else 0
	var tier_b: int = b.species.tier if b.species else 0
	if tier_a != tier_b:
		return tier_a > tier_b

	## Tiebreak 2: affinity cycle — electric > ground > water
	var aff_a: String = a.species.affinity if a.species else "neutral"
	var aff_b: String = b.species.affinity if b.species else "neutral"
	var pri_a: int = AFFINITY_PRIORITY.get(aff_a, 3)
	var pri_b: int = AFFINITY_PRIORITY.get(aff_b, 3)
	if pri_a != pri_b:
		return pri_a < pri_b

	## Tiebreak 3: lower HP% acts first (desperation)
	var hp_pct_a: float = float(a.current_hp) / maxf(float(a.max_hp), 1.0)
	var hp_pct_b: float = float(b.current_hp) / maxf(float(b.max_hp), 1.0)
	if hp_pct_a != hp_pct_b:
		return hp_pct_a < hp_pct_b

	## Tiebreak 4: player side wins over enemy
	if a.side != b.side:
		return a.side == "player"

	## Tiebreak 5: alphabetical species name (final deterministic fallback)
	var name_a: String = a.species.name if a.species else ""
	var name_b: String = b.species.name if b.species else ""
	return name_a < name_b
