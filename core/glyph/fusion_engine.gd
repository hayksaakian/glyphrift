class_name FusionEngine
extends Node

## Performs fusion lookup, stat/technique inheritance per TDD 6.8.

signal fusion_completed(result: GlyphInstance)
signal new_species_discovered(species: GlyphSpecies)

## Injectable dependencies (autoloads unavailable in --script tests)
var data_loader: Node = null
var codex_state: Node = null
var roster_state: Node = null


func _ready() -> void:
	if has_node("/root/DataLoader"):
		data_loader = get_node("/root/DataLoader")
	if has_node("/root/CodexState"):
		codex_state = get_node("/root/CodexState")
	if has_node("/root/RosterState"):
		roster_state = get_node("/root/RosterState")


func can_fuse(a: GlyphInstance, b: GlyphInstance) -> Dictionary:
	## Returns {valid: bool, reason: String}
	if not a.is_mastered:
		return {"valid": false, "reason": a.species.name + " is not mastered."}
	if not b.is_mastered:
		return {"valid": false, "reason": b.species.name + " is not mastered."}
	if not _tiers_compatible(a.species.tier, b.species.tier):
		return {"valid": false, "reason": "These tiers cannot fuse together."}
	return {"valid": true, "reason": ""}


func preview_fusion(a: GlyphInstance, b: GlyphInstance) -> Dictionary:
	## Returns preview info for the UI (GDD 7.7 step 4)
	var result_species_id: String = data_loader.lookup_fusion(a.species.id, b.species.id)
	var result_species: GlyphSpecies = data_loader.get_species(result_species_id)
	var is_discovered: bool = false
	if codex_state != null:
		is_discovered = codex_state.is_species_discovered(result_species_id)
	var bonuses: Dictionary = _calculate_inheritance(a, b)

	return {
		"result_tier": result_species.tier,
		"result_affinity": result_species.affinity,
		"result_species_name": result_species.name if is_discovered else "???",
		"result_species_id": result_species_id if is_discovered else "",
		"result_gp": result_species.gp_cost,
		"inheritance_bonuses": bonuses,
		"inheritable_techniques_a": _get_inheritable_techniques(a, result_species),
		"inheritable_techniques_b": _get_inheritable_techniques(b, result_species),
		"num_technique_slots": _get_inheritance_slots(result_species),
	}


func execute_fusion(
	a: GlyphInstance,
	b: GlyphInstance,
	inherited_technique_ids: Array[String]
) -> GlyphInstance:
	var result_species_id: String = data_loader.lookup_fusion(a.species.id, b.species.id)
	var result_species: GlyphSpecies = data_loader.get_species(result_species_id)
	var bonuses: Dictionary = _calculate_inheritance(a, b)

	var result: GlyphInstance = GlyphInstance.new()
	result.species = result_species

	## Apply inheritance bonuses
	result.bonus_hp = bonuses["hp"]
	result.bonus_atk = bonuses["atk"]
	result.bonus_def = bonuses["def"]
	result.bonus_spd = bonuses["spd"]
	result.bonus_res = bonuses["res"]

	## Build technique list: native first, then inherited (4-technique cap)
	for tech_id: String in result_species.technique_ids:
		var tech: TechniqueDef = data_loader.get_technique(tech_id)
		if tech != null:
			result.techniques.append(tech)
	for tech_id: String in inherited_technique_ids:
		if result.techniques.size() < 4:
			var tech: TechniqueDef = data_loader.get_technique(tech_id)
			if tech != null:
				result.techniques.append(tech)

	## Build mastery track (T4 gets none)
	result.mastery_objectives = MasteryTracker.build_mastery_track(
		result_species, data_loader.mastery_pools
	)

	result.calculate_stats()

	## Update game state if state managers are available
	if roster_state != null:
		roster_state.remove_glyph(a)
		roster_state.remove_glyph(b)
		roster_state.add_glyph(result)

	if codex_state != null:
		codex_state.log_fusion(a.species.id, b.species.id, result_species_id)
		var was_new: bool = codex_state.discover_species(result_species_id)
		if was_new:
			new_species_discovered.emit(result_species)

	fusion_completed.emit(result)
	return result


# --- Private ---


func _tiers_compatible(tier_a: int, tier_b: int) -> bool:
	## GDD 7.1: only adjacent tiers or same tier. T4 can't fuse.
	if tier_a == 4 or tier_b == 4:
		return false
	return absi(tier_a - tier_b) <= 1


func _calculate_inheritance(a: GlyphInstance, b: GlyphInstance) -> Dictionary:
	## GDD 7.2: floor((ParentA_Stat + ParentB_Stat) * 0.15) per stat
	return {
		"hp": int((a.max_hp + b.max_hp) * 0.15),
		"atk": int((a.atk + b.atk) * 0.15),
		"def": int((a.def_stat + b.def_stat) * 0.15),
		"spd": int((a.spd + b.spd) * 0.15),
		"res": int((a.res + b.res) * 0.15),
	}


func _get_inheritance_slots(sp: GlyphSpecies) -> int:
	## GDD 7.3: 4-technique cap
	var native_count: int = sp.technique_ids.size()
	match native_count:
		2: return 2  ## 1 from each parent
		3: return 1  ## 1 from either parent
		_: return 0  ## 4 native = no inheritance


func _get_inheritable_techniques(
	parent: GlyphInstance,
	result_species: GlyphSpecies
) -> Array[TechniqueDef]:
	## Return parent's techniques that aren't native to the result species
	var result: Array[TechniqueDef] = []
	for tech: TechniqueDef in parent.techniques:
		if tech.id not in result_species.technique_ids:
			result.append(tech)
	return result
