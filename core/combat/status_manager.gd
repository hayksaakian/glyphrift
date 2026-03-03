class_name StatusManager

const DURATIONS: Dictionary = {
	"burn": 3,
	"stun": 1,
	"slow": 3,
	"weaken": 3,
	"corrode": 3,
	"shield": 2,
}


static func apply(glyph: GlyphInstance, status_id: String) -> bool:
	## Check immunity
	if glyph.status_immunities.has(status_id):
		return false
	## Apply or refresh duration (non-stacking)
	glyph.active_statuses[status_id] = DURATIONS.get(status_id, 1)
	return true


static func try_apply(glyph: GlyphInstance, status_id: String, accuracy: int) -> String:
	## Roll status application: chance = clamp(accuracy - RES/2, 10, 90)
	if glyph.status_immunities.has(status_id):
		return "immune"
	var chance: float = clampf(float(accuracy) - float(glyph.res) / 2.0, 10.0, 90.0)
	var roll: float = randf() * 100.0
	if roll < chance:
		glyph.active_statuses[status_id] = DURATIONS.get(status_id, 1)
		return "applied"
	return "resisted"


static func tick(glyph: GlyphInstance) -> Dictionary:
	## Returns: {"burn_damage": int, "expired": Array[String]}
	var result: Dictionary = {"burn_damage": 0, "expired": []}

	## Process burn damage
	if glyph.active_statuses.has("burn"):
		var burn_dmg: int = maxi(1, int(float(glyph.max_hp) * 0.08))
		glyph.current_hp -= burn_dmg
		if glyph.current_hp < 0:
			glyph.current_hp = 0
		result["burn_damage"] = burn_dmg

	## Decrement all durations and collect expired
	var to_remove: Array[String] = []
	for status_id: String in glyph.active_statuses:
		glyph.active_statuses[status_id] -= 1
		if glyph.active_statuses[status_id] <= 0:
			to_remove.append(status_id)

	## Remove expired and grant 1-turn immunity
	for status_id: String in to_remove:
		glyph.active_statuses.erase(status_id)
		glyph.status_immunities[status_id] = 1
		result["expired"].append(status_id)

	return result


static func clear_immunities_tick(glyph: GlyphInstance) -> void:
	## Called at start of each glyph's turn — decrement immunity timers
	var to_remove: Array[String] = []
	for status_id: String in glyph.status_immunities:
		glyph.status_immunities[status_id] -= 1
		if glyph.status_immunities[status_id] <= 0:
			to_remove.append(status_id)
	for status_id: String in to_remove:
		glyph.status_immunities.erase(status_id)


static func is_stunned(glyph: GlyphInstance) -> bool:
	return glyph.active_statuses.has("stun")


static func has_status(glyph: GlyphInstance, status_id: String) -> bool:
	return glyph.active_statuses.has(status_id)


static func clear_all(glyph: GlyphInstance) -> void:
	glyph.active_statuses.clear()
