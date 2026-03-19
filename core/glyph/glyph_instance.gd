class_name GlyphInstance
extends RefCounted

## Unique runtime identifier
var instance_id: int = 0

## Species reference (immutable template data)
var species: GlyphSpecies = null

## Learned techniques (TechniqueDef references)
var techniques: Array[TechniqueDef] = []

## Computed stats (base + inheritance bonuses)
var max_hp: int = 0
var atk: int = 0
var def_stat: int = 0
var spd: int = 0
var res: int = 0

## Inheritance bonuses from fusion (GDD 7.3: 15% of donor stats)
var bonus_hp: int = 0
var bonus_atk: int = 0
var bonus_def: int = 0
var bonus_spd: int = 0
var bonus_res: int = 0

## Current HP (mutable during combat and between encounters)
var current_hp: int = 0

## Combat transient state — reset between battles
var cooldowns: Dictionary = {}           ## technique_id → turns remaining
var active_statuses: Dictionary = {}     ## status_id → turns remaining
var status_immunities: Dictionary = {}   ## status_id → turns remaining (1-turn immunity)
var is_guarding: bool = false
var guard_technique_name: String = ""    ## Name of interrupt technique used while guarding
var is_knocked_out: bool = false
var took_turn_this_round: bool = false
var row_position: String = "front"       ## "front" or "back"

## Mastery state
var is_mastered: bool = false
var mastery_objectives: Array[Dictionary] = []
var mastery_bonus_applied: bool = false
var took_turn_this_battle: bool = false

## Side tag for combat — "player" or "enemy"
var side: String = ""

## Boss tracking
var is_boss: bool = false
var boss_phase: int = 1

## Counter for unique instance IDs
static var _next_id: int = 1


func _init() -> void:
	instance_id = _next_id
	_next_id += 1


func calculate_stats() -> void:
	if species == null:
		return
	max_hp = species.base_hp + bonus_hp
	atk = species.base_atk + bonus_atk
	def_stat = species.base_def + bonus_def
	spd = species.base_spd + bonus_spd
	res = species.base_res + bonus_res
	## GDD 6.4: Mastered Glyphs gain permanent +2 to all stats
	if mastery_bonus_applied:
		max_hp += 2
		atk += 2
		def_stat += 2
		spd += 2
		res += 2
	current_hp = max_hp


func get_completed_objective_count() -> int:
	var count: int = 0
	for obj: Dictionary in mastery_objectives:
		if obj.get("completed", false):
			count += 1
	return count


func get_mastery_stars_text() -> String:
	## Returns star string: gold stars for completed objectives, dim for remaining.
	## T4 glyphs have no mastery, returns empty.
	var total: int = mastery_objectives.size()
	if total == 0:
		return ""
	var completed: int = get_completed_objective_count()
	if completed == 0:
		return ""
	var stars: String = ""
	for i: int in range(completed):
		stars += "\u2605"  ## Filled star
	return stars


func get_effective_spd() -> float:
	var base: float = float(spd)
	if active_statuses.has("slow"):
		base *= 0.7
	return base


func get_effective_atk() -> float:
	var base: float = float(atk)
	if active_statuses.has("weaken"):
		base *= 0.75
	return base


func get_effective_def() -> float:
	var base: float = float(def_stat)
	if active_statuses.has("corrode"):
		base *= 0.75
	return base


func get_gp_cost() -> int:
	if species == null:
		return 0
	return species.gp_cost


func reset_combat_state() -> void:
	cooldowns.clear()
	active_statuses.clear()
	status_immunities.clear()
	is_guarding = false
	guard_technique_name = ""
	took_turn_this_round = false
	took_turn_this_battle = false
	boss_phase = 1
	## Re-derive KO from HP — a glyph at 0 HP stays knocked out between battles
	is_knocked_out = current_hp <= 0


func tick_cooldowns() -> void:
	var to_remove: Array[String] = []
	for tech_id: String in cooldowns:
		cooldowns[tech_id] -= 1
		if cooldowns[tech_id] <= 0:
			to_remove.append(tech_id)
	for tech_id: String in to_remove:
		cooldowns.erase(tech_id)


func is_technique_ready(tech: TechniqueDef) -> bool:
	return not cooldowns.has(tech.id)


func put_on_cooldown(tech: TechniqueDef) -> void:
	if tech.cooldown > 0:
		cooldowns[tech.id] = tech.cooldown


static func create_from_species(sp: GlyphSpecies, dl: Node) -> GlyphInstance:
	var g: GlyphInstance = GlyphInstance.new()
	g.species = sp
	## Resolve techniques from species technique_ids
	for tid: String in sp.technique_ids:
		var tech: TechniqueDef = dl.get_technique(tid)
		if tech != null:
			g.techniques.append(tech)
	g.calculate_stats()
	return g
