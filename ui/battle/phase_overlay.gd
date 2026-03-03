class_name PhaseOverlay
extends ColorRect

## Full-screen flash white -> hold "PHASE 2" 1s -> fade.
## Emits transition_complete when done.

signal transition_complete

var _label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(1, 1, 1, 0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_label = Label.new()
	_label.text = "PHASE 2"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.add_theme_font_size_override("font_size", 48)
	_label.add_theme_color_override("font_color", Color("#FF4444"))
	_label.modulate.a = 0.0
	add_child(_label)


func play_transition() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var tween: Tween = create_tween()
	## Flash white
	tween.tween_property(self, "color", Color(1, 1, 1, 0.8), 0.15)
	## Show text
	tween.tween_callback(func() -> void: _label.modulate.a = 1.0)
	## Hold
	tween.tween_interval(1.0)
	## Fade out
	tween.tween_property(self, "color", Color(1, 1, 1, 0), 0.4)
	tween.parallel().tween_property(_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_complete.emit()
	)
