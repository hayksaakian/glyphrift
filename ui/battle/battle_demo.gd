extends Control

## Quick launcher to play a battle in the GUI.
## Run: ~/bin/godot --path . -s res://ui/battle/battle_demo.gd
## Or set as main scene in project.godot and press F5 in the editor.

var _engine: Node = null
var _scene: BattleScene = null
var _data_loader: Node = null


func _ready() -> void:
	## Grab DataLoader autoload
	_data_loader = get_node("/root/DataLoader")

	## Create CombatEngine
	var ce_script: GDScript = load("res://core/combat/combat_engine.gd") as GDScript
	_engine = ce_script.new() as Node
	_engine.name = "CombatEngine"
	_engine.data_loader = _data_loader
	get_tree().root.call_deferred("add_child", _engine)

	## Create BattleScene
	_scene = BattleScene.new()
	_scene.combat_engine = _engine
	_scene.battle_finished.connect(_on_battle_finished)
	add_child(_scene)

	## Build squads
	var p_squad: Array[GlyphInstance] = _make_squad(["zapplet", "stonepaw", "driftwisp"])
	var e_squad: Array[GlyphInstance] = _make_squad(["sparkfin", "mossling", "glitchkit"])

	## Start battle
	_scene.start_battle(p_squad, e_squad)


func _make_squad(species_ids: Array) -> Array[GlyphInstance]:
	var squad: Array[GlyphInstance] = []
	for sid: String in species_ids:
		var sp: GlyphSpecies = _data_loader.get_species(sid)
		squad.append(GlyphInstance.create_from_species(sp, _data_loader))
	return squad


func _on_battle_finished(won: bool) -> void:
	print("Battle finished — %s" % ("VICTORY" if won else "DEFEAT"))
	## Start another battle after a short delay
	await get_tree().create_timer(0.5).timeout
	var p_squad: Array[GlyphInstance] = _make_squad(["thunderclaw", "ironbark", "vortail"])
	var e_squad: Array[GlyphInstance] = _make_squad(["sparkfin", "mossling", "glitchkit"])
	_scene.start_battle(p_squad, e_squad)
