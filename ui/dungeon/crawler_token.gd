class_name CrawlerToken
extends Control

## Diamond-shaped crawler token shown on the dungeon floor map.
## Animates between rooms with a tween. Pulses subtly when idle.

const TOKEN_SIZE: Vector2 = Vector2(28, 28)
const FILL_COLOR: Color = Color("#00DDDD")
const OUTLINE_COLOR: Color = Color("#004444")

var instant_mode: bool = false

var _fill_polygon: Polygon2D = null
var _outline_polygon: Polygon2D = null
var _pulse_tween: Tween = null
var _move_tween: Tween = null


func _ready() -> void:
	custom_minimum_size = TOKEN_SIZE
	size = TOKEN_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Outline (slightly larger diamond behind)
	_outline_polygon = Polygon2D.new()
	_outline_polygon.polygon = PackedVector2Array([
		Vector2(14, 0), Vector2(28, 14), Vector2(14, 28), Vector2(0, 14)
	])
	_outline_polygon.color = OUTLINE_COLOR
	add_child(_outline_polygon)

	## Fill diamond
	_fill_polygon = Polygon2D.new()
	_fill_polygon.polygon = PackedVector2Array([
		Vector2(14, 2), Vector2(26, 14), Vector2(14, 26), Vector2(2, 14)
	])
	_fill_polygon.color = FILL_COLOR
	add_child(_fill_polygon)

	_start_pulse()


func teleport_to(pos: Vector2) -> void:
	position = pos - TOKEN_SIZE / 2.0


func move_to(pos: Vector2, on_complete: Callable = Callable()) -> void:
	var target: Vector2 = pos - TOKEN_SIZE / 2.0

	if instant_mode:
		position = target
		if on_complete.is_valid():
			on_complete.call()
		return

	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if on_complete.is_valid():
		_move_tween.tween_callback(on_complete)


func _start_pulse() -> void:
	if instant_mode:
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "modulate:a", 0.8, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "modulate:a", 1.0, 0.75) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
