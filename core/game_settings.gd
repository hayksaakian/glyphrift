class_name GameSettings
extends RefCounted

## Global game settings stored in user://settings.json.
## Battle speed multiplier: 1.0 = normal, 0.5 = fast (2x), 0.0 = instant.

const SAVE_PATH: String = "user://settings.json"

## Battle animation speed: "normal", "fast", "instant"
static var battle_speed: String = "normal"

## Maps speed name → delay multiplier
const SPEED_MULTIPLIERS: Dictionary = {
	"normal": 1.0,
	"fast": 0.4,
	"instant": 0.0,
}


static func get_delay_multiplier() -> float:
	return SPEED_MULTIPLIERS.get(battle_speed, 1.0)


static func save_settings() -> void:
	var data: Dictionary = {
		"battle_speed": battle_speed,
	}
	var json_str: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(json_str)
		file.close()


static func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(json_str) != OK:
		return
	var data: Variant = json.data
	if data is Dictionary:
		battle_speed = data.get("battle_speed", "normal")
