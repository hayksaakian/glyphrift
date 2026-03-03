class_name TargetSelector
extends Control

## Target highlight overlay. Shows colored borders on valid targets.
## Click target → target_selected. Back/cancel → selection_cancelled.
## When tech_affinity is provided, super-effective targets get a green border + SE label.

signal target_selected(glyph: GlyphInstance)
signal selection_cancelled

var _valid_targets: Array[GlyphInstance] = []
var _panels: Dictionary = {}  ## instance_id → GlyphPanel
var _highlight_rects: Array[Panel] = []
var _se_labels: Array[Label] = []
var _cancel_button: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(100, 30)
	_cancel_button.position = Vector2(10, 10)
	_cancel_button.pressed.connect(_on_cancel)
	_cancel_button.visible = false
	add_child(_cancel_button)


func show_targets(targets: Array[GlyphInstance], panels: Dictionary, tech_affinity: String = "") -> void:
	_valid_targets = targets
	_panels = panels
	visible = true
	_cancel_button.visible = true

	## Add highlight borders to valid target panels
	_clear_highlights()
	for g: GlyphInstance in _valid_targets:
		if _panels.has(g.instance_id):
			var panel: GlyphPanel = _panels[g.instance_id] as GlyphPanel
			var is_se: bool = false
			if tech_affinity != "" and g.species != null:
				is_se = DamageCalculator.has_affinity_advantage(tech_affinity, g.species.affinity)
			var highlight: Panel = _create_highlight(panel, is_se)
			_highlight_rects.append(highlight)
			if is_se:
				var se_label: Label = _create_se_label(panel)
				_se_labels.append(se_label)
			## Connect click on the panel
			if not panel.panel_clicked.is_connected(_on_target_clicked):
				panel.panel_clicked.connect(_on_target_clicked)


func hide_targets() -> void:
	_clear_highlights()
	_cancel_button.visible = false
	visible = false
	## Disconnect click signals
	for g: GlyphInstance in _valid_targets:
		if _panels.has(g.instance_id):
			var panel: GlyphPanel = _panels[g.instance_id] as GlyphPanel
			if panel.panel_clicked.is_connected(_on_target_clicked):
				panel.panel_clicked.disconnect(_on_target_clicked)
	_valid_targets.clear()


func _create_highlight(panel: GlyphPanel, is_se: bool) -> Panel:
	var highlight: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	if is_se:
		style.border_color = Color("#66FF66")
	else:
		style.border_color = Color("#FFDD44")
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	highlight.add_theme_stylebox_override("panel", style)
	highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(highlight)
	return highlight


func _create_se_label(panel: GlyphPanel) -> Label:
	var label: Label = Label.new()
	label.text = "S.EFF"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#66FF66"))
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = -14.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label


func _clear_highlights() -> void:
	for h: Panel in _highlight_rects:
		if is_instance_valid(h) and h.get_parent() != null:
			h.get_parent().remove_child(h)
			h.queue_free()
	_highlight_rects.clear()
	for l: Label in _se_labels:
		if is_instance_valid(l) and l.get_parent() != null:
			l.get_parent().remove_child(l)
			l.queue_free()
	_se_labels.clear()


func _on_target_clicked(glyph: GlyphInstance) -> void:
	if glyph in _valid_targets:
		hide_targets()
		target_selected.emit(glyph)


func _on_cancel() -> void:
	hide_targets()
	selection_cancelled.emit()
