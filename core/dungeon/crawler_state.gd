class_name CrawlerState
extends Node

## Persistent stats (survive between runs)
var max_hull_hp: int = 100
var max_energy: int = 50
var capacity: int = 12                     ## Maximum combined Glyph Power in active squad
var slots: int = 3                         ## Number of Glyphs in active battle squad
var bench_slots: int = 2                   ## Max non-active glyphs during a rift run
var active_chassis: String = "standard"
var unlocked_chassis: Array[String] = ["standard"]
var has_rift_transmitter: bool = false

## Per-run state (reset each dungeon entry)
var hull_hp: int = 100
var energy: int = 50
var items: Array = []  ## Array of ItemDef
var is_reinforced: bool = false
var hazard_shield_active: bool = false
var took_hull_damage_this_run: bool = false

const MAX_ITEMS: int = 5

const ABILITY_COSTS: Dictionary = {
	"scan": 5,
	"reinforce": 8,
	"field_repair": 10,
	"purge": 15,
	"emergency_warp": 25,
}

signal hull_changed(current: int, max_hp: int)
signal energy_changed(current: int, max_e: int)
signal item_added(item: ItemDef)
signal item_used(item: ItemDef)


func begin_run(_hazard_damage: int = 0) -> void:
	hull_hp = max_hull_hp
	energy = max_energy
	is_reinforced = false
	took_hull_damage_this_run = false
	## Chassis bonuses
	match active_chassis:
		"ironclad":
			hull_hp += 25
		"hauler":
			pass  ## Hauler bonus (bench slot) is passive, no per-run stat change


func get_effective_hull_hp() -> int:
	## Base + chassis bonus (for display in Crawler Bay)
	if active_chassis == "ironclad":
		return max_hull_hp + 25
	return max_hull_hp


func get_effective_energy() -> int:
	return max_energy


func get_effective_bench_slots() -> int:
	if active_chassis == "hauler":
		return bench_slots + 1
	return bench_slots


func get_ability_cost(ability: String) -> int:
	if not ABILITY_COSTS.has(ability):
		return -1
	var cost: int = ABILITY_COSTS[ability]
	## Scout chassis reduces Scan cost from 5 to 3
	if ability == "scan" and active_chassis == "scout":
		cost = 3
	return cost


func take_hull_damage(amount: int) -> void:
	if amount > 0:
		took_hull_damage_this_run = true
	hull_hp = maxi(0, hull_hp - amount)
	hull_changed.emit(hull_hp, max_hull_hp)


func spend_energy(amount: int) -> void:
	energy = maxi(0, energy - amount)
	energy_changed.emit(energy, max_energy)


func add_item(item: ItemDef) -> bool:
	if items.size() >= MAX_ITEMS:
		return false
	items.append(item)
	item_added.emit(item)
	return true


func use_item(item: ItemDef) -> bool:
	var idx: int = items.find(item)
	if idx == -1:
		return false
	items.remove_at(idx)
	item_used.emit(item)
	return true


func apply_upgrade(upgrade: Dictionary) -> void:
	var upgrade_type: String = upgrade.get("type", "")
	var value: int = int(upgrade.get("value", 0))
	match upgrade_type:
		"hull_hp":
			max_hull_hp += value
		"energy":
			max_energy += value
		"capacity":
			capacity += value
		"bench":
			bench_slots += value
		"chassis":
			var chassis_id: String = upgrade.get("chassis_id", "")
			if chassis_id != "" and not unlocked_chassis.has(chassis_id):
				unlocked_chassis.append(chassis_id)
		"rift_transmitter":
			has_rift_transmitter = true
