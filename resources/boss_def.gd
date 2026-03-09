class_name BossDef
extends Resource

@export var species_id: String
@export var stat_modifier: float = 1.0             ## Legacy, ignored — use mastery_stars
@export var mastery_stars: int = 0                  ## 0-3, each star = +2 all stats
@export var phase1_technique_ids: Array[String]
@export var phase2_technique_ids: Array[String]
@export var phase2_stat_bonus: Dictionary           ## {"atk": 0.1, "spd": 0.1}
@export var squad: Array[Dictionary] = []           ## Multi-glyph boss: [{species_id, mastered, technique_ids}]
