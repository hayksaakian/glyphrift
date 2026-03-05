class_name CapturePopup
extends PanelContainer

## Post-combat popup for capturing a defeated wild glyph.
## Shows capture probability and result.

signal capture_attempted(glyph: GlyphInstance, success: bool)
signal capture_released(glyph: GlyphInstance)
signal cargo_swap_chosen(keep_glyph: GlyphInstance, release_glyph: GlyphInstance)
signal dismissed()

const POPUP_SIZE: Vector2 = Vector2(340, 280)


var wild_glyph: GlyphInstance = null
var capture_chance: float = 0.0

var _title_label: Label = null
var _art_placeholder: ColorRect = null
var _art_initial: Label = null
var _art_container: Control = null
var _name_label: Label = null
var _info_label: Label = null
var _chance_label: Label = null
var _breakdown_label: Label = null
var _capture_button: Button = null
var _release_button: Button = null
var _result_label: Label = null
var _button_container: HBoxContainer = null
var _continue_button: Button = null
var _swap_container: VBoxContainer = null
var _abandon_btn: Button = null
var _swap_new_glyph: GlyphInstance = null


func _ready() -> void:
	custom_minimum_size = POPUP_SIZE
	visible = false
	_build_ui()


func show_capture(glyph: GlyphInstance, chance: float, breakdown: Dictionary = {}) -> void:
	wild_glyph = glyph
	capture_chance = chance

	_title_label.text = "WILD GLYPH DEFEATED!"

	var aff_color: Color = Affinity.COLORS.get(glyph.species.affinity, Color.WHITE)
	_art_placeholder.color = aff_color
	_art_initial.text = glyph.species.name[0].to_upper()
	GlyphArt.apply_texture(_art_container, _art_placeholder, _art_initial, glyph.species.id, 48)
	_name_label.text = glyph.species.name
	var emoji: String = Affinity.EMOJI.get(glyph.species.affinity, "")
	_info_label.text = "%s %s T%d" % [emoji, glyph.species.affinity.capitalize(), glyph.species.tier]
	_chance_label.text = "Capture Chance: %d%%" % int(chance * 100.0)
	_capture_button.text = "Capture" if chance >= 1.0 else "Attempt Capture"

	## Show modifier breakdown
	if not breakdown.is_empty():
		_breakdown_label.text = _format_breakdown(breakdown)
		_breakdown_label.visible = true
	else:
		_breakdown_label.visible = false

	_capture_button.visible = true
	_capture_button.disabled = false
	_release_button.visible = true
	_button_container.visible = true
	_result_label.text = ""
	_result_label.visible = false
	_continue_button.visible = false
	_swap_container.visible = false
	_abandon_btn.visible = false
	visible = true
	_animate_show()


func _format_breakdown(bd: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("Base %d%%" % int(bd.get("base", 0.0) * 100.0))
	var turn_bonus: float = bd.get("turn_bonus", 0.0)
	if turn_bonus > 0:
		parts.append("Speed +%d%%" % int(turn_bonus * 100.0))
	elif turn_bonus == 0.0:
		pass  ## At par — no bonus or penalty to show
	var item_bonus: float = bd.get("item_bonus", 0.0)
	if item_bonus > 0:
		parts.append("Lure +%d%%" % int(item_bonus * 100.0))
	if bd.get("capped", false):
		parts.append("(max 80%)")
	return " | ".join(parts)


func hide_popup() -> void:
	visible = false


func show_cargo_swap(new_glyph: GlyphInstance, cargo: Array[GlyphInstance]) -> void:
	_swap_new_glyph = new_glyph

	_title_label.text = "Cargo Full!"
	_title_label.add_theme_color_override("font_color", Color("#FFC107"))

	var aff_color: Color = Affinity.COLORS.get(new_glyph.species.affinity, Color.WHITE)
	_art_placeholder.color = aff_color
	_art_initial.text = new_glyph.species.name[0].to_upper()
	GlyphArt.apply_texture(_art_container, _art_placeholder, _art_initial, new_glyph.species.id, 48)
	_name_label.text = new_glyph.species.name
	var emoji: String = Affinity.EMOJI.get(new_glyph.species.affinity, "")
	_info_label.text = "%s %s T%d" % [emoji, new_glyph.species.affinity.capitalize(), new_glyph.species.tier]

	_chance_label.text = "Release a cargo glyph to make room:"
	_capture_button.visible = false
	_release_button.visible = false
	_result_label.visible = false
	_continue_button.visible = false
	_button_container.visible = false

	## Clear previous swap buttons
	for child: Node in _swap_container.get_children():
		_swap_container.remove_child(child)
		child.queue_free()

	## Add a release button for each cargo glyph
	for cargo_glyph: GlyphInstance in cargo:
		var btn: Button = Button.new()
		btn.text = "Release %s" % cargo_glyph.species.name
		btn.custom_minimum_size = Vector2(200, 32)
		btn.pressed.connect(_on_swap_release.bind(cargo_glyph))
		_swap_container.add_child(btn)

	## Abandon button
	_abandon_btn.visible = true
	_swap_container.visible = true
	visible = true


func _on_swap_release(released: GlyphInstance) -> void:
	cargo_swap_chosen.emit(_swap_new_glyph, released)
	## Show result confirmation (like normal capture) instead of instant dismiss
	_swap_container.visible = false
	_abandon_btn.visible = false
	_chance_label.visible = false
	_breakdown_label.visible = false
	_result_label.text = "CAPTURED!\nSwapped with %s." % released.species.name
	_result_label.add_theme_color_override("font_color", Color("#44FF44"))
	_result_label.visible = true
	_continue_button.visible = true


func _on_abandon_pressed() -> void:
	_swap_new_glyph = null
	dismissed.emit()


func get_chance_text() -> String:
	if _chance_label != null:
		return _chance_label.text
	return ""


func get_result_text() -> String:
	if _result_label != null:
		return _result_label.text
	return ""


func _build_ui() -> void:
	## Panel styling
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", panel_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	## Title
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	## Glyph info row
	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 12)
	info_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(info_row)

	## Art placeholder (affinity colored square with initial)
	_art_container = Control.new()
	var art_container: Control = _art_container
	art_container.custom_minimum_size = Vector2(48, 48)
	info_row.add_child(art_container)

	_art_placeholder = ColorRect.new()
	_art_placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_placeholder.color = Color.GRAY
	art_container.add_child(_art_placeholder)

	_art_initial = Label.new()
	_art_initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_initial.add_theme_font_size_override("font_size", 20)
	_art_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_art_initial.add_theme_color_override("font_color", Color.WHITE)
	_art_initial.add_theme_color_override("font_outline_color", Color.BLACK)
	_art_initial.add_theme_constant_override("outline_size", 3)
	art_container.add_child(_art_initial)

	## Name + info column
	var name_col: VBoxContainer = VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 2)
	info_row.add_child(name_col)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	name_col.add_child(_name_label)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	name_col.add_child(_info_label)

	## Capture chance
	_chance_label = Label.new()
	_chance_label.add_theme_font_size_override("font_size", 14)
	_chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_chance_label)

	## Modifier breakdown
	_breakdown_label = Label.new()
	_breakdown_label.add_theme_font_size_override("font_size", 10)
	_breakdown_label.add_theme_color_override("font_color", Color("#999999"))
	_breakdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_breakdown_label.visible = false
	vbox.add_child(_breakdown_label)

	## Buttons
	_button_container = HBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 16)
	_button_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_button_container)

	_capture_button = Button.new()
	_capture_button.text = "Attempt Capture"
	_capture_button.custom_minimum_size = Vector2(130, 36)
	_capture_button.pressed.connect(_on_capture_pressed)
	_button_container.add_child(_capture_button)

	_release_button = Button.new()
	_release_button.text = "Release"
	_release_button.custom_minimum_size = Vector2(90, 36)
	_release_button.pressed.connect(_on_release_pressed)
	_button_container.add_child(_release_button)

	## Result text
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.visible = false
	vbox.add_child(_result_label)

	## Continue button (shown after capture result)
	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(100, 36)
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_button.visible = false
	_continue_button.pressed.connect(func() -> void: dismissed.emit())
	vbox.add_child(_continue_button)

	## Cargo swap container (hidden by default)
	_swap_container = VBoxContainer.new()
	_swap_container.add_theme_constant_override("separation", 6)
	_swap_container.visible = false
	vbox.add_child(_swap_container)

	## Abandon button (hidden by default)
	_abandon_btn = Button.new()
	_abandon_btn.text = "Abandon new capture"
	_abandon_btn.custom_minimum_size = Vector2(200, 32)
	_abandon_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_abandon_btn.visible = false
	_abandon_btn.pressed.connect(_on_abandon_pressed)
	vbox.add_child(_abandon_btn)


func _on_capture_pressed() -> void:
	if wild_glyph == null:
		return
	## 100% chance — skip the roll confirmation, just capture and dismiss
	if capture_chance >= 1.0:
		capture_attempted.emit(wild_glyph, true)
		dismissed.emit()
		return
	var roll: float = randf()
	var success: bool = roll <= capture_chance
	_capture_button.disabled = true
	_release_button.visible = false

	## Play attempt shake animation, then show result
	_play_attempt_shake(success)


func _play_attempt_shake(success: bool) -> void:
	## Shake the art container to build tension
	if _art_container == null:
		_show_capture_result(success)
		return
	var orig: Vector2 = _art_container.position
	var tween: Tween = create_tween()
	for i: int in range(4):
		var offset: float = 6.0 - float(i)
		tween.tween_property(_art_container, "position", orig + Vector2(offset, 0), 0.06)
		tween.tween_property(_art_container, "position", orig + Vector2(-offset, 0), 0.06)
	tween.tween_property(_art_container, "position", orig, 0.04)
	tween.tween_callback(_show_capture_result.bind(success))


func _show_capture_result(success: bool) -> void:
	_result_label.visible = true
	_continue_button.visible = true

	if success:
		_result_label.text = "CAPTURED!"
		_result_label.add_theme_color_override("font_color", Color("#44FF44"))
		_play_capture_success()
	else:
		_result_label.text = "ESCAPED!"
		_result_label.add_theme_color_override("font_color", Color("#FF4444"))
		_play_capture_failure()

	capture_attempted.emit(wild_glyph, success)


func _play_capture_success() -> void:
	## Bright flash + scale pop on the art container
	if _art_container == null:
		return
	_art_container.modulate = Color(2.0, 2.0, 2.0)
	_art_container.pivot_offset = _art_container.size / 2.0
	_art_container.scale = Vector2(1.3, 1.3)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_art_container, "modulate", Color.WHITE, 0.3)
	tween.tween_property(_art_container, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)


func _play_capture_failure() -> void:
	## Quick dash to the right and fade
	if _art_container == null:
		return
	var orig_pos: Vector2 = _art_container.position
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_art_container, "position", orig_pos + Vector2(80, 0), 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(_art_container, "modulate", Color(1, 1, 1, 0.3), 0.2)
	tween.chain().tween_callback(func() -> void:
		## Reset for next use
		_art_container.position = orig_pos
		_art_container.modulate = Color.WHITE
	)


## Deterministic capture for testing (no animation)
func attempt_capture_with_roll(roll: float) -> bool:
	if wild_glyph == null:
		return false
	var success: bool = roll <= capture_chance
	_capture_button.disabled = true
	_release_button.visible = false
	_show_capture_result(success)
	return success


func _animate_show() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(0.85, 0.85)
	modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func _on_release_pressed() -> void:
	if wild_glyph == null:
		return
	capture_released.emit(wild_glyph)
