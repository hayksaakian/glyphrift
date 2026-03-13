class_name GlyphAnimator
extends Control

## Animated glyph display using sprite sheets. Falls back to static portrait
## when no sprite sheet exists.
##
## Usage:
##   var animator: GlyphAnimator = GlyphAnimator.new()
##   add_child(animator)
##   animator.setup("zapplet")
##   animator.play("attack")  # Plays attack, emits animation_finished when done
##
## Sprite sheet format: 512x512 PNG, 4 rows × 4 cols of 128x128 frames.
## Row 0: idle (4 frames, 4 FPS, loops)
## Row 1: attack (4 frames, 8 FPS, no loop)
## Row 2: hurt (2 frames, 6 FPS, no loop)
## Row 3: ko (3 frames, 4 FPS, no loop, hold last)

signal animation_finished


const SHEET_PATH: String = "res://assets/sprites/glyphs/sheets/%s_sheet.png"
const FRAME_SIZE: int = 128
const COLS: int = 4

const ANIMS: Dictionary = {
	"idle": {"row": 0, "frames": 4, "fps": 4.0, "loop": true},
	"attack": {"row": 1, "frames": 4, "fps": 8.0, "loop": false},
	"hurt": {"row": 2, "frames": 2, "fps": 6.0, "loop": false},
	"ko": {"row": 3, "frames": 3, "fps": 4.0, "loop": false},
}

## If true, animations skip to final frame immediately (for headless testing).
var instant_mode: bool = false

## True if a sprite sheet was loaded; false if using static fallback.
var has_animations: bool = false

var _species_id: String = ""
var _sprite: AnimatedSprite2D = null
var _sprite_frames: SpriteFrames = null
var _fallback_texture: TextureRect = null
var _affinity_rect: ColorRect = null
var _current_anim: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(species_id: String) -> void:
	_species_id = species_id
	_clear_children()

	var sheet_tex: Texture2D = _load_sheet(species_id)
	if sheet_tex != null:
		_setup_animated(sheet_tex)
		has_animations = true
		play("idle")
	else:
		_setup_fallback(species_id)
		has_animations = false


func set_species(species_id: String) -> void:
	setup(species_id)


func play(anim_name: String) -> void:
	if not has_animations:
		animation_finished.emit()
		return

	if not ANIMS.has(anim_name):
		animation_finished.emit()
		return

	_current_anim = anim_name
	var anim_data: Dictionary = ANIMS[anim_name]

	if instant_mode:
		## Skip to final frame — stop first, then set animation, then set frame
		## (setting animation resets frame to 0, so frame must come after)
		_sprite.stop()
		_sprite.animation = anim_name
		_sprite.set_frame_and_progress(anim_data["frames"] - 1, 0.0)
		animation_finished.emit()
		return

	_sprite.play(anim_name)

	if anim_data["loop"]:
		## Looping animations don't emit finished — emit immediately
		animation_finished.emit()


func get_current_animation() -> String:
	return _current_anim


func _setup_animated(sheet_tex: Texture2D) -> void:
	_sprite_frames = SpriteFrames.new()

	## Remove default animation if present
	if _sprite_frames.has_animation("default"):
		_sprite_frames.remove_animation("default")

	for anim_name: String in ANIMS:
		var anim_data: Dictionary = ANIMS[anim_name]
		_sprite_frames.add_animation(anim_name)
		_sprite_frames.set_animation_speed(anim_name, anim_data["fps"])
		_sprite_frames.set_animation_loop(anim_name, anim_data["loop"])

		var row: int = anim_data["row"]
		var frame_count: int = anim_data["frames"]

		for i: int in range(frame_count):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(i * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
			_sprite_frames.add_frame(anim_name, atlas)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _sprite_frames
	_sprite.centered = false
	## Scale to fill this Control's size
	_sprite.scale = Vector2(size.x / FRAME_SIZE, size.y / FRAME_SIZE) if size.x > 0 else Vector2.ONE
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	add_child(_sprite)


func _setup_fallback(species_id: String) -> void:
	## Show the static portrait via the same pattern as GlyphArt
	var tex: Texture2D = GlyphArt.get_portrait(species_id)

	## Add affinity background
	_affinity_rect = ColorRect.new()
	_affinity_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_affinity_rect.color = Color("#333333")
	_affinity_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_affinity_rect)

	if tex != null:
		_fallback_texture = TextureRect.new()
		_fallback_texture.texture = tex
		_fallback_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fallback_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fallback_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_fallback_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fallback_texture)


func _on_sprite_animation_finished() -> void:
	if _current_anim == "ko":
		## Hold last frame — don't restart
		_sprite.stop()
	animation_finished.emit()


func _load_sheet(species_id: String) -> Texture2D:
	var path: String = SHEET_PATH % species_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _clear_children() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_sprite = null
	_sprite_frames = null
	_fallback_texture = null
	_affinity_rect = null
	has_animations = false
	_current_anim = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _sprite != null:
		## Keep sprite scaled to fill control size
		if size.x > 0 and size.y > 0:
			_sprite.scale = Vector2(size.x / FRAME_SIZE, size.y / FRAME_SIZE)
