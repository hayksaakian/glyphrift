extends Node

var species: Dictionary = {}          ## id → GlyphSpecies
var techniques: Dictionary = {}       ## id → TechniqueDef
var fusion_table: Dictionary = {}     ## "speciesA_id|speciesB_id" → result_species_id
var mastery_pools: Dictionary = {}    ## tier (int) → Array[Dictionary]
var items: Dictionary = {}            ## id → ItemDef
var rift_templates: Array[RiftTemplate] = []
var bosses: Dictionary = {}           ## rift_id → BossDef
var codex_entries: Dictionary = {}    ## species_id → {hint, lore}
var npc_dialogue: Dictionary = {}     ## npc_id → {name, title, phases}
var crawler_upgrades: Array[Dictionary] = []


func _ready() -> void:
	_load_techniques()
	_load_species()
	_load_fusion_table()
	_load_mastery_pools()
	_load_items()
	_load_rift_templates()
	_load_bosses()
	_load_codex()
	_load_npc_dialogue()
	_load_crawler_upgrades()


func get_species(id: String) -> GlyphSpecies:
	return species[id]


func get_technique(id: String) -> TechniqueDef:
	return techniques[id]


func get_item(id: String) -> ItemDef:
	return items[id]


func get_boss(rift_id: String) -> BossDef:
	return bosses[rift_id]


func get_crawler_upgrades() -> Array[Dictionary]:
	return crawler_upgrades


func get_rift_template(rift_id: String) -> RiftTemplate:
	for template: RiftTemplate in rift_templates:
		if template.rift_id == rift_id:
			return template
	return null


func lookup_fusion(species_a_id: String, species_b_id: String) -> String:
	## Fusion is order-independent: check both orderings
	var key_1: String = species_a_id + "|" + species_b_id
	var key_2: String = species_b_id + "|" + species_a_id
	if fusion_table.has(key_1):
		return fusion_table[key_1]
	if fusion_table.has(key_2):
		return fusion_table[key_2]
	return _default_fusion(species_a_id, species_b_id)


func _default_fusion(a_id: String, b_id: String) -> String:
	## GDD 7.6 fallback: result matches affinity of parent with higher total base stats
	var a: GlyphSpecies = species[a_id]
	var b: GlyphSpecies = species[b_id]
	var a_total: int = a.base_hp + a.base_atk + a.base_def + a.base_spd + a.base_res
	var b_total: int = b.base_hp + b.base_atk + b.base_def + b.base_spd + b.base_res
	var target_affinity: String = a.affinity if a_total >= b_total else b.affinity
	var target_tier: int = _fusion_result_tier(a.tier, b.tier)
	for sp: GlyphSpecies in species.values():
		if sp.affinity == target_affinity and sp.tier == target_tier:
			return sp.id
	return a_id


func _fusion_result_tier(tier_a: int, tier_b: int) -> int:
	## GDD 7.1: same tier → tier+1, adjacent tiers → max tier
	if tier_a == tier_b:
		return mini(tier_a + 1, 4)
	return maxi(tier_a, tier_b)


# --- Private loader functions ---


func _load_json(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: Failed to open " + path + " — error: " + str(FileAccess.get_open_error()))
		return null
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		push_error("DataLoader: JSON parse error in " + path + " at line " + str(json.get_error_line()) + ": " + json.get_error_message())
		return null
	return json.data


func _load_techniques() -> void:
	var data: Variant = _load_json("res://data/techniques.json")
	if data == null:
		return
	for entry: Dictionary in data:
		var tech: TechniqueDef = TechniqueDef.new()
		tech.id = entry["id"]
		tech.name = entry["name"]
		tech.category = entry["category"]
		tech.affinity = entry["affinity"]
		tech.range_type = entry["range_type"]
		tech.power = int(entry["power"])
		tech.cooldown = int(entry["cooldown"])
		tech.status_effect = entry.get("status_effect", "")
		tech.status_accuracy = int(entry.get("status_accuracy", 0))
		tech.interrupt_trigger = entry.get("interrupt_trigger", "")
		tech.support_effect = entry.get("support_effect", "")
		tech.support_value = float(entry.get("support_value", 0.0))
		tech.description = entry.get("description", "")
		techniques[tech.id] = tech


func _load_species() -> void:
	var data: Variant = _load_json("res://data/glyphs.json")
	if data == null:
		return
	for entry: Dictionary in data:
		var sp: GlyphSpecies = GlyphSpecies.new()
		sp.id = entry["id"]
		sp.name = entry["name"]
		sp.tier = int(entry["tier"])
		sp.affinity = entry["affinity"]
		sp.gp_cost = int(entry["gp_cost"])
		sp.base_hp = int(entry["base_hp"])
		sp.base_atk = int(entry["base_atk"])
		sp.base_def = int(entry["base_def"])
		sp.base_spd = int(entry["base_spd"])
		sp.base_res = int(entry["base_res"])
		var tech_ids: Array[String] = []
		for tid: String in entry["technique_ids"]:
			tech_ids.append(tid)
		sp.technique_ids = tech_ids
		var mastery_objs: Array[Dictionary] = []
		for obj: Dictionary in entry.get("fixed_mastery_objectives", []):
			mastery_objs.append(obj)
		sp.fixed_mastery_objectives = mastery_objs
		species[sp.id] = sp


func _load_fusion_table() -> void:
	var data: Variant = _load_json("res://data/fusion_table.json")
	if data == null:
		return
	for entry: Dictionary in data:
		var a: String = entry["parent_a"]
		var b: String = entry["parent_b"]
		var result: String = entry["result"]
		## Store both orderings for quick lookup
		fusion_table[a + "|" + b] = result
		if a != b:
			fusion_table[b + "|" + a] = result


func _load_mastery_pools() -> void:
	var data: Variant = _load_json("res://data/mastery_pools.json")
	if data == null:
		return
	## JSON keys are strings ("1", "2", "3"), convert to int keys
	for key: String in data:
		var tier: int = int(key)
		var pool_array: Array[Dictionary] = []
		for obj: Dictionary in data[key]:
			pool_array.append(obj)
		mastery_pools[tier] = pool_array


func _load_items() -> void:
	var data: Variant = _load_json("res://data/items.json")
	if data == null:
		return
	for entry: Dictionary in data:
		var item: ItemDef = ItemDef.new()
		item.id = entry["id"]
		item.name = entry["name"]
		item.effect_type = entry["effect_type"]
		item.effect_value = float(entry["effect_value"])
		item.description = entry.get("description", "")
		item.usable_in_combat = entry.get("usable_in_combat", false)
		items[item.id] = item


func _load_rift_templates() -> void:
	var data: Variant = _load_json("res://data/rift_templates.json")
	if data == null:
		return
	for entry: Dictionary in data:
		var template: RiftTemplate = RiftTemplate.new()
		template.rift_id = entry["rift_id"]
		template.name = entry["name"]
		template.tier = entry["tier"]
		template.hazard_damage = int(entry["hazard_damage"])

		var tier_pool: Array[int] = []
		for t: float in entry["enemy_tier_pool"]:
			tier_pool.append(int(t))
		template.enemy_tier_pool = tier_pool

		var glyph_pool: Array[String] = []
		for gid: String in entry["wild_glyph_pool"]:
			glyph_pool.append(gid)
		template.wild_glyph_pool = glyph_pool

		var floors_array: Array[Dictionary] = []
		for floor_data: Dictionary in entry["floors"]:
			floors_array.append(floor_data)
		template.floors = floors_array

		template.boss = entry.get("boss", {})
		template.content_pools = entry.get("content_pools", {})
		rift_templates.append(template)


func _load_bosses() -> void:
	var data: Variant = _load_json("res://data/bosses.json")
	if data == null:
		return
	for entry: Dictionary in data:
		var boss: BossDef = BossDef.new()
		boss.species_id = entry["species_id"]
		boss.stat_modifier = float(entry["stat_modifier"])

		var p1_ids: Array[String] = []
		for tid: String in entry["phase1_technique_ids"]:
			p1_ids.append(tid)
		boss.phase1_technique_ids = p1_ids

		var p2_ids: Array[String] = []
		for tid: String in entry["phase2_technique_ids"]:
			p2_ids.append(tid)
		boss.phase2_technique_ids = p2_ids

		boss.phase2_stat_bonus = entry.get("phase2_stat_bonus", {})
		bosses[entry["rift_id"]] = boss


func _load_codex() -> void:
	var data: Variant = _load_json("res://data/codex_entries.json")
	if data == null:
		return
	codex_entries = data


func _load_npc_dialogue() -> void:
	var data: Variant = _load_json("res://data/npc_dialogue.json")
	if data == null:
		return
	npc_dialogue = data


func _load_crawler_upgrades() -> void:
	var data: Variant = _load_json("res://data/crawler_upgrades.json")
	if data == null:
		return
	for entry: Dictionary in data:
		crawler_upgrades.append(entry)
