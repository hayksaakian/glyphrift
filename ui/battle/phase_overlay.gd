class_name PhaseOverlay
extends ColorRect

## Full-screen flash white -> hold "PHASE 2" 1s -> fade.
## Emits transition_complete when done.

signal transition_complete

var _label: Label = null
var _changes_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(1, 1, 1, 0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_label = Label.new()
	_label.text = "PHASE 2"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 48)
	_label.add_theme_color_override("font_color", Color("#FF4444"))
	_label.modulate.a = 0.0
	vbox.add_child(_label)

	_changes_label = Label.new()
	_changes_label.text = ""
	_changes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_changes_label.add_theme_font_size_override("font_size", 16)
	_changes_label.add_theme_color_override("font_color", Color("#FFAAAA"))
	_changes_label.modulate.a = 0.0
	vbox.add_child(_changes_label)


func play_transition(changes: Dictionary = {}) -> void:
	_changes_label.text = _format_changes(changes)
	_changes_label.visible = not _changes_label.text.is_empty()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var tween: Tween = create_tween()
	## Flash white
	tween.tween_property(self, "color", Color(1, 1, 1, 0.8), 0.15)
	## Show text
	tween.tween_callback(func() -> void:
		_label.modulate.a = 1.0
		_changes_label.modulate.a = 1.0
	)
	## Hold
	tween.tween_interval(1.2)
	## Fade out
	tween.tween_property(self, "color", Color(1, 1, 1, 0), 0.4)
	tween.parallel().tween_property(_label, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(_changes_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_complete.emit()
	)


func _format_changes(changes: Dictionary) -> String:
	var parts: Array[String] = []
	if changes.has("atk"):
		parts.append("ATK %s" % changes["atk"])
	if changes.has("spd"):
		parts.append("SPD %s" % changes["spd"])
	if changes.has("new_techniques"):
		var techs: Array = changes["new_techniques"]
		for t_name: Variant in techs:
			parts.append("+ %s" % str(t_name))
	return " | ".join(parts)
