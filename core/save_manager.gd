class_name SaveManager
extends RefCounted

## Static utility for saving/loading game state to slot-based JSON files.
## Autosave uses the "autosave" slot; manual slots use "slot1", "slot2", "slot3".
## Only saves at bastion boundaries (no mid-rift saves).

const AUTOSAVE_SLOT: String = "autosave"
const SAVE_VERSION: int = 1
const _LEGACY_PATH: String = "user://save.json"

## Test isolation: set non-empty so tests use separate files (e.g. "test_save_*.json").
static var _test_prefix: String = ""


static func _slot_path(slot: String) -> String:
	return "user://%ssave_%s.json" % [_test_prefix, slot]


# --- Slot-based API ---


static func save_to_slot(
	slot: String,
	game_state: GameState,
	roster_state: RosterState,
	codex_state: CodexState,
	crawler_state: CrawlerState,
	label: String = "",
) -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true),
		"label": label,
		"game_state": _serialize_game_state(game_state),
		"roster_state": _serialize_roster_state(roster_state),
		"codex_state": _serialize_codex_state(codex_state),
		"crawler_state": _serialize_crawler_state(crawler_state),
	}

	var path: String = _slot_path(slot)
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open save file for writing: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(json_string)
	file.close()
	return true


static func load_from_slot(
	slot: String,
	game_state: GameState,
	roster_state: RosterState,
	codex_state: CodexState,
	crawler_state: CrawlerState,
	data_loader: Node,
) -> bool:
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file for reading: " + str(FileAccess.get_open_error()))
		return false
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		push_error("SaveManager: JSON parse error: " + json.get_error_message())
		return false

	var data: Dictionary = json.data
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_error("SaveManager: Version mismatch — expected %d, got %s" % [SAVE_VERSION, str(data.get("version", "?"))])
		return false

	_deserialize_game_state(data.get("game_state", {}), game_state)
	_deserialize_roster_state(data.get("roster_state", {}), roster_state, data_loader)
	_deserialize_codex_state(data.get("codex_state", {}), codex_state)
	_deserialize_crawler_state(data.get("crawler_state", {}), crawler_state, data_loader)
	return true


static func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


static func delete_slot(slot: String) -> void:
	var path: String = _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func get_slot_info(slot: String) -> Dictionary:
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}

	var data: Dictionary = json.data
	var gs_data: Dictionary = data.get("game_state", {})
	var rs_data: Dictionary = data.get("roster_state", {})
	return {
		"slot": slot,
		"phase": int(gs_data.get("game_phase", 1)),
		"glyph_count": (rs_data.get("glyphs", []) as Array).size(),
		"timestamp": str(data.get("timestamp", "")),
		"label": str(data.get("label", "")),
	}


static func list_slots() -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return result
	var prefix: String = _test_prefix + "save_"
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with(prefix) and file_name.ends_with(".json"):
			var slot_name: String = file_name.trim_prefix(prefix).trim_suffix(".json")
			result.append(slot_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


# --- Legacy migration + autosave convenience API ---


static func _migrate_legacy_save() -> void:
	## One-time migration: rename user://save.json → user://save_autosave.json
	## Skip migration in test mode (don't touch real saves).
	if _test_prefix != "":
		return
	if FileAccess.file_exists(_LEGACY_PATH) and not FileAccess.file_exists(_slot_path(AUTOSAVE_SLOT)):
		var dir: DirAccess = DirAccess.open("user://")
		if dir != null:
			dir.rename(_LEGACY_PATH, _slot_path(AUTOSAVE_SLOT))


static func has_save() -> bool:
	_migrate_legacy_save()
	return has_slot(AUTOSAVE_SLOT)


static func delete_save() -> void:
	delete_slot(AUTOSAVE_SLOT)


static func save_game(
	game_state: GameState,
	roster_state: RosterState,
	codex_state: CodexState,
	crawler_state: CrawlerState,
) -> bool:
	return save_to_slot(AUTOSAVE_SLOT, game_state, roster_state, codex_state, crawler_state)


static func load_game(
	game_state: GameState,
	roster_state: RosterState,
	codex_state: CodexState,
	crawler_state: CrawlerState,
	data_loader: Node,
) -> bool:
	return load_from_slot(AUTOSAVE_SLOT, game_state, roster_state, codex_state, crawler_state, data_loader)


# --- GameState ---


static func _serialize_game_state(gs: GameState) -> Dictionary:
	return {
		"game_phase": gs.game_phase,
		"npc_read_phase": gs.npc_read_phase.duplicate(),
	}


static func _deserialize_game_state(data: Dictionary, gs: GameState) -> void:
	gs.game_phase = int(data.get("game_phase", 1))
	gs.current_state = GameState.State.BASTION
	var npc_data: Dictionary = data.get("npc_read_phase", {})
	for npc_id: String in gs.npc_read_phase:
		gs.npc_read_phase[npc_id] = int(npc_data.get(npc_id, 0))


# --- RosterState ---


static func _serialize_roster_state(rs: RosterState) -> Dictionary:
	var glyphs: Array[Dictionary] = []
	for g: GlyphInstance in rs.all_glyphs:
		glyphs.append(_serialize_glyph(g))

	## Store active squad as indices into all_glyphs
	var squad_indices: Array[int] = []
	for g: GlyphInstance in rs.active_squad:
		var idx: int = rs.all_glyphs.find(g)
		if idx >= 0:
			squad_indices.append(idx)

	return {
		"glyphs": glyphs,
		"squad_indices": squad_indices,
	}


static func _deserialize_roster_state(
	data: Dictionary,
	rs: RosterState,
	data_loader: Node,
) -> void:
	rs.all_glyphs.clear()
	rs.active_squad.clear()

	var glyph_dicts: Array = data.get("glyphs", [])
	for gd: Dictionary in glyph_dicts:
		var g: GlyphInstance = _deserialize_glyph(gd, data_loader)
		if g != null:
			rs.all_glyphs.append(g)

	## Restore active squad from indices
	var squad_indices: Array = data.get("squad_indices", [])
	for idx_val: Variant in squad_indices:
		var idx: int = int(idx_val)
		if idx >= 0 and idx < rs.all_glyphs.size():
			rs.active_squad.append(rs.all_glyphs[idx])


# --- Glyph ---


static func _serialize_glyph(g: GlyphInstance) -> Dictionary:
	## Only save inherited (non-native) technique IDs
	var inherited_tech_ids: Array[String] = []
	if g.species != null:
		for tech: TechniqueDef in g.techniques:
			if not g.species.technique_ids.has(tech.id):
				inherited_tech_ids.append(tech.id)

	## Deep-copy mastery objectives (mutable current counters)
	var mastery_data: Array[Dictionary] = []
	for obj: Dictionary in g.mastery_objectives:
		mastery_data.append(obj.duplicate(true))

	return {
		"species_id": g.species.id if g.species else "",
		"bonus_hp": g.bonus_hp,
		"bonus_atk": g.bonus_atk,
		"bonus_def": g.bonus_def,
		"bonus_spd": g.bonus_spd,
		"bonus_res": g.bonus_res,
		"current_hp": g.current_hp,
		"is_mastered": g.is_mastered,
		"mastery_bonus_applied": g.mastery_bonus_applied,
		"mastery_objectives": mastery_data,
		"inherited_technique_ids": inherited_tech_ids,
	}


static func _deserialize_glyph(data: Dictionary, data_loader: Node) -> GlyphInstance:
	var species_id: String = data.get("species_id", "")
	if species_id == "":
		return null

	var sp: GlyphSpecies = data_loader.get_species(species_id)
	if sp == null:
		push_error("SaveManager: Unknown species '%s'" % species_id)
		return null

	var g: GlyphInstance = GlyphInstance.new()
	g.species = sp

	## Restore native techniques from species
	for tid: String in sp.technique_ids:
		var tech: TechniqueDef = data_loader.get_technique(tid)
		if tech != null:
			g.techniques.append(tech)

	## Restore inherited techniques
	var inherited_ids: Array = data.get("inherited_technique_ids", [])
	for tid: Variant in inherited_ids:
		var tech: TechniqueDef = data_loader.get_technique(str(tid))
		if tech != null and not g.techniques.has(tech):
			g.techniques.append(tech)

	## Restore bonuses
	g.bonus_hp = int(data.get("bonus_hp", 0))
	g.bonus_atk = int(data.get("bonus_atk", 0))
	g.bonus_def = int(data.get("bonus_def", 0))
	g.bonus_spd = int(data.get("bonus_spd", 0))
	g.bonus_res = int(data.get("bonus_res", 0))

	## Restore mastery state
	g.is_mastered = data.get("is_mastered", false)
	g.mastery_bonus_applied = data.get("mastery_bonus_applied", false)

	## Restore mastery objectives (deep copy)
	var obj_array: Array = data.get("mastery_objectives", [])
	var objectives: Array[Dictionary] = []
	for obj: Variant in obj_array:
		if obj is Dictionary:
			objectives.append((obj as Dictionary).duplicate(true))
	g.mastery_objectives = objectives

	## Recalculate stats (sets current_hp = max_hp)
	g.calculate_stats()

	## Override current_hp with saved value
	var saved_hp: int = int(data.get("current_hp", g.max_hp))
	g.current_hp = mini(saved_hp, g.max_hp)

	return g


# --- CodexState ---


static func _serialize_codex_state(cs: CodexState) -> Dictionary:
	## Convert dict keys to arrays for clean JSON
	var discovered: Array[String] = []
	for key: String in cs.discovered_species:
		discovered.append(key)

	var rifts: Array[String] = []
	for key: String in cs.rifts_cleared:
		rifts.append(key)

	## Fusion log is already an Array[Dictionary]
	var fusions: Array[Dictionary] = []
	for entry: Dictionary in cs.fusion_log:
		fusions.append(entry.duplicate())

	return {
		"discovered_species": discovered,
		"fusion_log": fusions,
		"rifts_cleared": rifts,
	}


static func _deserialize_codex_state(data: Dictionary, cs: CodexState) -> void:
	## Write directly to dicts (skip signals during load)
	cs.discovered_species.clear()
	for sid: Variant in data.get("discovered_species", []):
		cs.discovered_species[str(sid)] = true

	cs.fusion_log.clear()
	for entry: Variant in data.get("fusion_log", []):
		if entry is Dictionary:
			cs.fusion_log.append(entry as Dictionary)

	cs.rifts_cleared.clear()
	for rid: Variant in data.get("rifts_cleared", []):
		cs.rifts_cleared[str(rid)] = true


# --- CrawlerState ---


static func _serialize_crawler_state(crs: CrawlerState) -> Dictionary:
	var chassis_list: Array[String] = []
	for c: String in crs.unlocked_chassis:
		chassis_list.append(c)
	var item_ids: Array[String] = []
	for item: ItemDef in crs.items:
		item_ids.append(item.id)
	return {
		"max_hull_hp": crs.max_hull_hp,
		"max_energy": crs.max_energy,
		"capacity": crs.capacity,
		"slots": crs.slots,
		"cargo_slots": crs.cargo_slots,
		"active_chassis": crs.active_chassis,
		"unlocked_chassis": chassis_list,
		"items": item_ids,
	}


static func _deserialize_crawler_state(data: Dictionary, crs: CrawlerState, data_loader: Node) -> void:
	crs.max_hull_hp = int(data.get("max_hull_hp", 100))
	crs.max_energy = int(data.get("max_energy", 50))
	crs.capacity = int(data.get("capacity", 12))
	crs.slots = int(data.get("slots", 3))
	crs.cargo_slots = int(data.get("cargo_slots", 2))
	crs.active_chassis = str(data.get("active_chassis", "standard"))

	var chassis_arr: Array = data.get("unlocked_chassis", ["standard"])
	var chassis_list: Array[String] = []
	for c: Variant in chassis_arr:
		chassis_list.append(str(c))
	crs.unlocked_chassis = chassis_list

	crs.items.clear()
	for item_id: Variant in data.get("items", []):
		var item: ItemDef = data_loader.get_item(str(item_id))
		if item != null:
			crs.items.append(item)
