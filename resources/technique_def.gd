class_name TechniqueDef
extends Resource

@export var id: String
@export var name: String
@export var category: String          ## "offensive", "status", "support", "interrupt"
@export var affinity: String          ## "electric", "ground", "water", "neutral"
@export var range_type: String        ## "melee", "ranged", "aoe", "piercing"
@export var power: int
@export var cooldown: int
@export var status_effect: String     ## "" if none, otherwise status ID
@export var status_accuracy: int      ## 0–100
@export var interrupt_trigger: String ## "" if not interrupt, otherwise "ON_MELEE", etc.
@export var support_effect: String    ## "" if not support, otherwise effect description key
@export var support_value: float      ## heal %, buff %, etc.
@export var description: String       ## Player-facing tooltip text
