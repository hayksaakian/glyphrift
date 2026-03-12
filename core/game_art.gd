class_name GameArt
extends RefCounted

## Centralized art loading for NPC portraits, status icons, and room icons.
## Same caching + fallback pattern as GlyphArt.

const NPC_PATH: String = "res://assets/sprites/npcs/%s.png"
const STATUS_ICON_PATH: String = "res://assets/sprites/icons/status/%s.png"
const ROOM_ICON_PATH: String = "res://assets/sprites/icons/rooms/%s.png"

## Cache: id -> Texture2D or &"_miss" sentinel
static var _npc_cache: Dictionary = {}
static var _status_cache: Dictionary = {}
static var _room_cache: Dictionary = {}
static var _MISS: StringName = &"_miss"


static func get_npc_portrait(npc_id: String) -> Texture2D:
	if _npc_cache.has(npc_id):
		var cached: Variant = _npc_cache[npc_id]
		if cached is Texture2D:
			return cached as Texture2D
		return null
	var path: String = NPC_PATH % npc_id
	var tex: Texture2D = _try_load(path)
	_npc_cache[npc_id] = tex if tex != null else _MISS
	return tex


static func get_status_icon(status_id: String) -> Texture2D:
	if _status_cache.has(status_id):
		var cached: Variant = _status_cache[status_id]
		if cached is Texture2D:
			return cached as Texture2D
		return null
	var path: String = STATUS_ICON_PATH % status_id
	var tex: Texture2D = _try_load(path)
	_status_cache[status_id] = tex if tex != null else _MISS
	return tex


static func get_room_icon(room_type: String) -> Texture2D:
	if _room_cache.has(room_type):
		var cached: Variant = _room_cache[room_type]
		if cached is Texture2D:
			return cached as Texture2D
		return null
	var path: String = ROOM_ICON_PATH % room_type
	var tex: Texture2D = _try_load(path)
	_room_cache[room_type] = tex if tex != null else _MISS
	return tex


static func _try_load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func clear_cache() -> void:
	_npc_cache.clear()
	_status_cache.clear()
	_room_cache.clear()
