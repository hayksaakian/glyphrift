class_name ItemDef
extends Resource

@export var id: String
@export var name: String
@export var effect_type: String       ## "repair_hull", "restore_energy", "heal_glyph",
                                      ## "status_immunity", "capture_bonus"
@export var effect_value: float       ## Amount (25 hull, 10 energy, 100% heal, 25% capture, etc.)
@export var description: String
@export var usable_in_combat: bool    ## false for all prototype items
