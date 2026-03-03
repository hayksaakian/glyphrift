class_name RosterState
extends Node

## Owns the player's Glyph collection, active squad, and formation presets.
## Per TDD Section 4 Autoload Registry.

signal glyph_added(glyph: GlyphInstance)
signal glyph_removed(glyph: GlyphInstance)
signal squad_changed(squad: Array[GlyphInstance])

var all_glyphs: Array[GlyphInstance] = []
var active_squad: Array[GlyphInstance] = []
var max_squad_size: int = 3
var max_reserves: int = 20                  ## Barracks storage capacity (separate from crawler cargo)


func add_glyph(glyph: GlyphInstance) -> void:
	all_glyphs.append(glyph)
	glyph_added.emit(glyph)


func remove_glyph(glyph: GlyphInstance) -> void:
	all_glyphs.erase(glyph)
	active_squad.erase(glyph)
	glyph_removed.emit(glyph)


func set_active_squad(squad: Array[GlyphInstance]) -> void:
	active_squad = squad
	squad_changed.emit(squad)


func get_mastered_glyphs() -> Array[GlyphInstance]:
	var result: Array[GlyphInstance] = []
	for g: GlyphInstance in all_glyphs:
		if g.is_mastered:
			result.append(g)
	return result


func get_glyph_count() -> int:
	return all_glyphs.size()


func has_glyph(glyph: GlyphInstance) -> bool:
	return all_glyphs.has(glyph)


func initialize_starting_glyphs(data_loader: Node) -> void:
	reset()
	var starter_ids: Array[String] = ["zapplet", "stonepaw", "driftwisp"]
	var squad: Array[GlyphInstance] = []
	for sid: String in starter_ids:
		var sp: GlyphSpecies = data_loader.get_species(sid)
		var g: GlyphInstance = GlyphInstance.create_from_species(sp, data_loader)
		g.mastery_objectives = MasteryTracker.build_mastery_track(sp, data_loader.mastery_pools)
		add_glyph(g)
		squad.append(g)
	set_active_squad(squad)

	## Debug: extra mastered glyphs in reserves for fusion testing
	if _seed_debug_glyphs:
		_add_debug_glyphs(data_loader)


## Set to true before calling initialize_starting_glyphs to seed fusion-ready reserves.
var _seed_debug_glyphs: bool = false


func _add_debug_glyphs(data_loader: Node) -> void:
	var debug_ids: Array[String] = ["zapplet", "sparkfin", "stonepaw", "mossling", "driftwisp"]
	for sid: String in debug_ids:
		var sp: GlyphSpecies = data_loader.get_species(sid)
		var g: GlyphInstance = GlyphInstance.create_from_species(sp, data_loader)
		g.mastery_objectives = MasteryTracker.build_mastery_track(sp, data_loader.mastery_pools)
		## Mark mastered
		for obj: Dictionary in g.mastery_objectives:
			obj["completed"] = true
		g.is_mastered = true
		g.mastery_bonus_applied = true
		g.calculate_stats()
		add_glyph(g)


func reset() -> void:
	all_glyphs.clear()
	active_squad.clear()
