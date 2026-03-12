class_name EquipmentDef
extends Resource

@export var id: String
@export var name: String
@export var slot: String            ## "computer" or "accessory"
@export var description: String
@export var effect_type: String     ## "scan_reveal_all", "energy_regen_floor", "capture_bonus",
                                    ## "energy_bonus", "hull_bonus", "bench_bonus",
                                    ## "hull_regen_floor"
@export var effect_value: int
@export var rarity: String          ## "common", "uncommon", "rare"
