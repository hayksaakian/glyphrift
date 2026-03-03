class_name CodexState
extends Node

## Tracks discovered species, fusion log, and rift completions.
## Per TDD Section 4 Autoload Registry.

signal species_discovered(species_id: String)
signal fusion_logged(parent_a_id: String, parent_b_id: String, result_id: String)

var discovered_species: Dictionary = {}     ## species_id → true
var fusion_log: Array[Dictionary] = []      ## [{parent_a, parent_b, result}]
var rifts_cleared: Dictionary = {}          ## rift_id → true


func discover_species(species_id: String) -> bool:
	## Returns true if this was a NEW discovery, false if already known
	if discovered_species.has(species_id):
		return false
	discovered_species[species_id] = true
	species_discovered.emit(species_id)
	return true


func is_species_discovered(species_id: String) -> bool:
	return discovered_species.has(species_id)


func log_fusion(parent_a_id: String, parent_b_id: String, result_id: String) -> void:
	fusion_log.append({
		"parent_a": parent_a_id,
		"parent_b": parent_b_id,
		"result": result_id,
	})
	fusion_logged.emit(parent_a_id, parent_b_id, result_id)


func mark_rift_cleared(rift_id: String) -> void:
	rifts_cleared[rift_id] = true


func is_rift_cleared(rift_id: String) -> bool:
	return rifts_cleared.has(rift_id)


func get_discovery_count() -> int:
	return discovered_species.size()


func get_fusion_count() -> int:
	return fusion_log.size()


func cleared_rift_count() -> int:
	return rifts_cleared.size()


func get_discovery_percentage() -> float:
	return discovered_species.size() / 15.0


func reset() -> void:
	discovered_species.clear()
	fusion_log.clear()
	rifts_cleared.clear()
