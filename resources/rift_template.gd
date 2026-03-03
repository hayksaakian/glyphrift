class_name RiftTemplate
extends Resource

@export var rift_id: String
@export var name: String
@export var tier: String                           ## "minor", "standard", "major", "apex"
@export var floors: Array[Dictionary]              ## [{floor_number, rooms, connections, content_pools}]
@export var boss: Dictionary                       ## {species_id, stat_modifier, phase2_techniques}
@export var hazard_damage: int
@export var enemy_tier_pool: Array[int]            ## [1], [1,2], [2,3], etc.
@export var wild_glyph_pool: Array[String]         ## species IDs capturable here
@export var content_pools: Dictionary              ## pool_name → {room_type: weight}
