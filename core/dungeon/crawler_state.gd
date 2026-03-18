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

## Equipment
var equipped_computer: String = ""   ## EquipmentDef ID or ""
var equipped_accessory: String = ""  ## EquipmentDef ID or ""
var owned_equipment: Array[String] = []  ## All equipment IDs the player owns
var data_loader: Node = null  ## Injectable for equipment lookups

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
	hazard_shield_active = false
	took_hull_damage_this_run = false
	## Chassis bonuses
	match active_chassis:
		"ironclad":
			hull_hp += 25
		"hauler":
			pass  ## Hauler bonus (bench slot) is passive, no per-run stat change
	## Equipment bonuses
	var hull_bonus: int = _get_equipment_value("hull_bonus")
	var energy_bonus: int = _get_equipment_value("energy_bonus")
	hull_hp += hull_bonus
	energy += energy_bonus


func get_effective_hull_hp() -> int:
	## Base + chassis bonus + equipment bonus (for display in Crawler Bay)
	var total: int = max_hull_hp
	if active_chassis == "ironclad":
		total += 25
	total += _get_equipment_value("hull_bonus")
	return total


func get_effective_energy() -> int:
	return max_energy + _get_equipment_value("energy_bonus")


func get_effective_capacity() -> int:
	return capacity + _get_equipment_value("capacity_bonus")


func get_effective_bench_slots() -> int:
	var total: int = bench_slots
	if active_chassis == "hauler":
		total += 1
	total += _get_equipment_value("bench_bonus")
	return total


func get_ability_cost(ability: String) -> int:
	if not ABILITY_COSTS.has(ability):
		return -1
	var cost: int = ABILITY_COSTS[ability]
	## Scout chassis reduces Scan cost from 5 to 3
	if ability == "scan" and active_chassis == "scout":
		cost = 3
	return cost


func get_capture_equipment_bonus() -> float:
	## Sum capture_bonus from all equipped items (as percentage, e.g. 15 → 0.15)
	return float(_get_equipment_value("capture_bonus")) / 100.0


func has_equipment_effect(effect_type: String) -> bool:
	return _get_equipment_value(effect_type) > 0 or _has_equipment_effect_type(effect_type)


func get_floor_transition_hull_regen() -> int:
	return _get_equipment_value("hull_regen_floor")


func get_floor_transition_energy_regen() -> int:
	## Returns percentage of max energy to regen
	return _get_equipment_value("energy_regen_floor")


## Equipment management

func equip(slot: String, equipment_id: String) -> void:
	if equipment_id != "" and not owned_equipment.has(equipment_id):
		return
	match slot:
		"computer":
			equipped_computer = equipment_id
		"accessory":
			equipped_accessory = equipment_id


func unequip(slot: String) -> void:
	match slot:
		"computer":
			equipped_computer = ""
		"accessory":
			equipped_accessory = ""


func add_equipment(equipment_id: String) -> void:
	if not owned_equipment.has(equipment_id):
		owned_equipment.append(equipment_id)


func _get_equipment_value(effect_type: String) -> int:
	## Sum effect_value from all equipped items matching effect_type
	if data_loader == null:
		return 0
	var total: int = 0
	for eq_id: String in [equipped_computer, equipped_accessory]:
		if eq_id == "":
			continue
		var eq: EquipmentDef = data_loader.get_equipment(eq_id)
		if eq != null and eq.effect_type == effect_type:
			total += eq.effect_value
	return total


func _has_equipment_effect_type(effect_type: String) -> bool:
	if data_loader == null:
		return false
	for eq_id: String in [equipped_computer, equipped_accessory]:
		if eq_id == "":
			continue
		var eq: EquipmentDef = data_loader.get_equipment(eq_id)
		if eq != null and eq.effect_type == effect_type:
			return true
	return false


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
