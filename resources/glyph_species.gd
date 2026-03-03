class_name GlyphSpecies
extends Resource

@export var id: String
@export var name: String
@export var tier: int                        ## 1–4
@export var affinity: String                 ## "electric", "ground", "water"
@export var gp_cost: int                     ## 2, 4, 6, or 8
@export var base_hp: int
@export var base_atk: int
@export var base_def: int
@export var base_spd: int
@export var base_res: int
@export var technique_ids: Array[String]     ## IDs into techniques.json
@export var fixed_mastery_objectives: Array[Dictionary]  ## [{type, params, description}]
