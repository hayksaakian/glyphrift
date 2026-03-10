class_name AnimationQueue
extends Node

## Serializes visual events for sequential playback.
## CombatEngine fires multiple signals in one frame — this queues them
## and plays one at a time with configurable delays.

signal queue_empty
signal event_started(event: Dictionary)

var _queue: Array[Dictionary] = []
var _playing: bool = false
var _default_delay: float = 0.3

## When true, events are queued but not auto-played.
## Call drain() to process all events instantly (for testing).
var instant_mode: bool = false


func enqueue(type: String, data: Dictionary = {}, delay: float = -1.0) -> void:
	var event: Dictionary = {
		"type": type,
		"data": data,
		"delay": delay if delay >= 0.0 else _default_delay,
	}
	_queue.append(event)
	if not _playing and not instant_mode:
		_play_next()


func enqueue_callback(callback: Callable, delay: float = 0.0) -> void:
	var event: Dictionary = {
		"type": "_callback",
		"data": {"callback": callback},
		"delay": delay,
	}
	_queue.append(event)
	if not _playing and not instant_mode:
		_play_next()


func clear() -> void:
	_queue.clear()
	_playing = false


func is_playing() -> bool:
	return _playing


func get_queue_size() -> int:
	return _queue.size()


func drain() -> void:
	## Process all queued events instantly (no delays). For testing.
	while not _queue.is_empty():
		var event: Dictionary = _queue.pop_front()
		event_started.emit(event)
		if event["type"] == "_callback":
			var cb: Callable = event["data"]["callback"]
			cb.call()
	_playing = false
	queue_empty.emit()


func _play_next() -> void:
	if _queue.is_empty():
		_playing = false
		queue_empty.emit()
		return

	_playing = true
	var event: Dictionary = _queue.pop_front()
	event_started.emit(event)

	if event["type"] == "_callback":
		var cb: Callable = event["data"]["callback"]
		cb.call()

	var delay: float = event["delay"] * GameSettings.get_delay_multiplier()
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	_play_next()
