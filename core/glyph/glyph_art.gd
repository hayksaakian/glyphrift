class_name GlyphArt
extends RefCounted

## Centralized glyph art loading with placeholder fallback.
## Static utility — same pattern as Affinity.

const PORTRAIT_PATH: String = "res://assets/sprites/glyphs/portraits/%s.png"
const SILHOUETTE_PATH: String = "res://assets/sprites/glyphs/silhouettes/%s_silhouette.png"
const MIN_TEXTURE_SIZE: int = 8  ## Below this, always use placeholder

## Cache: species_id -> Texture2D or &"_miss" sentinel
static var _portrait_cache: Dictionary = {}
static var _silhouette_cache: Dictionary = {}
static var _MISS: StringName = &"_miss"


static func get_portrait(species_id: String) -> Texture2D:
	if _portrait_cache.has(species_id):
		var cached: Variant = _portrait_cache[species_id]
		if cached is Texture2D:
			return cached as Texture2D
		return null  ## Sentinel (_MISS) or unexpected type
	var path: String = PORTRAIT_PATH % species_id
	var tex: Texture2D = _try_load(path)
	_portrait_cache[species_id] = tex if tex != null else _MISS
	return tex


static func get_silhouette(species_id: String) -> Texture2D:
	if _silhouette_cache.has(species_id):
		var cached: Variant = _silhouette_cache[species_id]
		if cached is Texture2D:
			return cached as Texture2D
		return null  ## Sentinel (_MISS) or unexpected type
	var path: String = SILHOUETTE_PATH % species_id
	var tex: Texture2D = _try_load(path)
	_silhouette_cache[species_id] = tex if tex != null else _MISS
	return tex


static func _try_load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Apply a glyph texture to an art container, falling back to placeholder.
##
## art_container: parent Control holding affinity_rect and initial_label
## affinity_rect: the ColorRect placeholder (stays visible as background)
## initial_label: the Label placeholder (hidden when texture is shown)
## species_id: species ID for texture lookup
## art_size: pixel size of the art area (skips texture below MIN_TEXTURE_SIZE)
## silhouette: if true, use silhouette texture (for undiscovered codex entries)
static func apply_texture(
	art_container: Control,
	affinity_rect: ColorRect,
	initial_label: Label,
	species_id: String,
	art_size: int = 60,
	silhouette: bool = false,
) -> void:
	var existing: TextureRect = art_container.get_node_or_null("GlyphTexture") as TextureRect

	## Below minimum size: always use placeholder
	if art_size < MIN_TEXTURE_SIZE:
		if existing != null:
			existing.visible = false
		affinity_rect.visible = true
		initial_label.visible = true
		return

	var tex: Texture2D = get_silhouette(species_id) if silhouette else get_portrait(species_id)

	if tex == null:
		## No texture: show placeholder
		if existing != null:
			existing.visible = false
		affinity_rect.visible = true
		initial_label.visible = true
		return

	## Texture found: create TextureRect if needed
	if existing == null:
		existing = TextureRect.new()
		existing.name = "GlyphTexture"
		existing.set_anchors_preset(Control.PRESET_FULL_RECT)
		existing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		existing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_container.add_child(existing)
		## Insert after affinity_rect so it's above background but below overlays
		art_container.move_child(existing, affinity_rect.get_index() + 1)

	existing.texture = tex
	existing.visible = true
	affinity_rect.visible = true  ## Keep as background for transparent areas
	initial_label.visible = false


static func clear_cache() -> void:
	_portrait_cache.clear()
	_silhouette_cache.clear()
