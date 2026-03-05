class_name ResultScreen
extends ColorRect

## Win/loss overlay with Continue button.
## Victory: gold "VICTORY!" + stats. Defeat: red "DEFEAT!".

signal continue_pressed

var _vbox: VBoxContainer = null
var _title_label: Label = null
var _stats_label: Label = null
var _mastery_section: VBoxContainer = null
var _continue_button: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.7)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_ui()


func show_victory(turns_taken: int, ko_count: int) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.text = "VICTORY!"
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_stats_label.text = "Turns: %d  |  KOs taken: %d" % [turns_taken, ko_count]
	_stats_label.visible = true
	_mastery_section.visible = false
	_continue_button.visible = true

	## Animate in
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func show_mastery_progress(events: Array[Dictionary]) -> void:
	## Show mastery progress/completion on victory screen.
	## events: [{type, glyph, objective_index}] where type is "objective_completed" or "glyph_mastered"
	if events.is_empty():
		return

	_clear_mastery_content()
	var has_content: bool = false

	for event: Dictionary in events:
		var g: GlyphInstance = event.get("glyph") as GlyphInstance
		if g == null or g.species == null:
			continue

		var type: String = event.get("type", "")
		if type == "glyph_mastered":
			var label: Label = Label.new()
			label.text = "\u2605 %s MASTERED!" % g.species.name
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color("#FFD700"))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_mastery_section.add_child(label)
			has_content = true

		elif type == "objective_completed":
			var obj_idx: int = event.get("objective_index", -1)
			if obj_idx >= 0 and obj_idx < g.mastery_objectives.size():
				var obj: Dictionary = g.mastery_objectives[obj_idx]
				var desc: String = obj.get("description", "")
				var label: Label = Label.new()
				label.text = "%s: %s \u2713 COMPLETE!" % [g.species.name, desc]
				label.add_theme_font_size_override("font_size", 12)
				label.add_theme_color_override("font_color", Color("#4CAF50"))
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_mastery_section.add_child(label)
				has_content = true

	_mastery_section.visible = has_content


func show_squad_mastery(squad: Array[GlyphInstance]) -> void:
	## Show per-glyph mastery stars and next objective progress for all squad members.
	## Called after show_victory + show_mastery_progress.
	if squad.is_empty():
		return

	_clear_mastery_content()
	var has_content: bool = false

	for g: GlyphInstance in squad:
		if g.species == null or g.species.tier == 4:
			continue
		var total: int = g.mastery_objectives.size()
		if total == 0:
			continue

		var completed: int = g.get_completed_objective_count()

		## Stars line
		var star_text: String = ""
		for i: int in range(total):
			if i < completed:
				star_text += "\u2605"
			else:
				star_text += "\u2606"

		var star_color: Color = Color("#FFD700") if g.is_mastered else Color("#CCCCCC")
		var mastered_tag: String = " MASTERED" if g.is_mastered else ""

		var star_label: Label = Label.new()
		star_label.text = "%s  %s%s" % [g.species.name, star_text, mastered_tag]
		star_label.add_theme_font_size_override("font_size", 13)
		star_label.add_theme_color_override("font_color", star_color)
		star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mastery_section.add_child(star_label)
		has_content = true

		## Show next incomplete objective progress
		if not g.is_mastered:
			for obj: Dictionary in g.mastery_objectives:
				if obj.get("completed", false):
					continue
				var desc: String = obj.get("description", "")
				var params: Dictionary = obj.get("params", {})
				var progress_text: String = ""
				if params.has("current") and params.has("target"):
					progress_text = " [%d/%d]" % [int(params["current"]), int(params["target"])]
				var obj_label: Label = Label.new()
				obj_label.text = "  Next: %s%s" % [desc, progress_text]
				obj_label.add_theme_font_size_override("font_size", 11)
				obj_label.add_theme_color_override("font_color", Color("#888888"))
				obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_mastery_section.add_child(obj_label)
				break  ## Only show first incomplete objective

	if has_content:
		_mastery_section.visible = true


func show_defeat() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.text = "DEFEAT"
	_title_label.add_theme_color_override("font_color", Color("#FF4444"))
	_stats_label.visible = false
	_mastery_section.visible = false
	_continue_button.visible = true

	## Animate in
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func hide_result() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _clear_mastery_content() -> void:
	for child: Node in _mastery_section.get_children():
		if child != _mastery_section.get_child(0):  ## Keep header
			_mastery_section.remove_child(child)
			child.queue_free()


func _build_ui() -> void:
	## CenterContainer fills full rect, VBox stays compact inside it
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 16)
	_vbox.custom_minimum_size.x = 400.0
	center.add_child(_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_vbox.add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_vbox.add_child(_stats_label)

	## Mastery progress section (scroll-wrapped to cap height)
	var mastery_scroll: ScrollContainer = ScrollContainer.new()
	mastery_scroll.custom_minimum_size.y = 0.0
	mastery_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mastery_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mastery_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(mastery_scroll)

	_mastery_section = VBoxContainer.new()
	_mastery_section.add_theme_constant_override("separation", 4)
	_mastery_section.visible = false
	_mastery_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mastery_scroll.add_child(_mastery_section)

	var mastery_header: Label = Label.new()
	mastery_header.text = "-- Mastery Progress --"
	mastery_header.add_theme_font_size_override("font_size", 14)
	mastery_header.add_theme_color_override("font_color", Color("#AAAAAA"))
	mastery_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mastery_section.add_child(mastery_header)

	## Continue button — part of the group, not pinned separately
	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(200, 40)
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	_vbox.add_child(_continue_button)
