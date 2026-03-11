class_name GameSettings
extends RefCounted

## Global game settings stored in user://settings.json.
## Battle speed multiplier: 1.0 = normal, 0.5 = fast (2x), 0.0 = instant.

const SAVE_PATH: String = "user://settings.json"

## Battle animation speed: "normal", "fast", "instant"
static var battle_speed: String = "normal"

## Font size: "small", "normal", "large"
static var font_size: String = "normal"

## Maps speed name → delay multiplier
const SPEED_MULTIPLIERS: Dictionary = {
	"normal": 1.0,
	"fast": 0.4,
	"instant": 0.0,
}

## Maps font size name → scale factor
const FONT_SCALES: Dictionary = {
	"small": 0.85,
	"normal": 1.0,
	"large": 1.2,
}


static func get_delay_multiplier() -> float:
	return SPEED_MULTIPLIERS.get(battle_speed, 1.0)


static func get_font_scale() -> float:
	return FONT_SCALES.get(font_size, 1.0)


## Apply font scale to a root Control node by setting default_font_size on its theme.
## Call after changing font_size setting and on startup.
static func apply_font_scale(root: Control) -> void:
	var scale: float = get_font_scale()
	var base_size: int = 16
	var scaled_size: int = int(base_size * scale)
	if root.theme == null:
		root.theme = Theme.new()
	root.theme.default_font_size = scaled_size


static func save_settings() -> void:
	var data: Dictionary = {
		"battle_speed": battle_speed,
		"font_size": font_size,
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
		font_size = data.get("font_size", "normal")
