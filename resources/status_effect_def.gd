class_name StatusEffectDef
extends Resource

@export var id: String                ## "burn", "stun", "slow", "weaken", "corrode", "shield"
@export var display_name: String
@export var duration: int             ## turns
@export var is_buff: bool             ## true for shield, false for debuffs
@export var description: String
