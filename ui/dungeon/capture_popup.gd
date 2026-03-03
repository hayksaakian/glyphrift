class_name CapturePopup
extends PanelContainer

## Post-combat popup for capturing a defeated wild glyph.
## Shows capture probability and result.

signal capture_attempted(glyph: GlyphInstance, success: bool)
signal capture_released(glyph: GlyphInstance)
signal dismissed()

const POPUP_SIZE: Vector2 = Vector2(340, 280)

const AFFINITY_COLORS: Dictionary = {
	"electric": Color("#FFD700"),
	"ground": Color("#4CAF50"),
	"water": Color("#00ACC1"),
}

var wild_glyph: GlyphInstance = null
var capture_chance: float = 0.0

var _title_label: Label = null
var _art_placeholder: ColorRect = null
var _art_initial: Label = null
var _name_label: Label = null
var _info_label: Label = null
var _chance_label: Label = null
var _capture_button: Button = null
var _release_button: Button = null
var _result_label: Label = null
var _button_container: HBoxContainer = null
var _continue_button: Button = null


func _ready() -> void:
	custom_minimum_size = POPUP_SIZE
	visible = false
	_build_ui()


func show_capture(glyph: GlyphInstance, chance: float) -> void:
	wild_glyph = glyph
	capture_chance = chance

	_title_label.text = "WILD GLYPH DEFEATED!"

	var aff_color: Color = AFFINITY_COLORS.get(glyph.species.affinity, Color.WHITE)
	_art_placeholder.color = aff_color
	_art_initial.text = glyph.species.name[0].to_upper()
	_name_label.text = glyph.species.name
	_info_label.text = "%s T%d" % [glyph.species.affinity.capitalize(), glyph.species.tier]
	_chance_label.text = "Capture Chance: %d%%" % int(chance * 100.0)

	_capture_button.visible = true
	_capture_button.disabled = false
	_release_button.visible = true
	_result_label.text = ""
	_result_label.visible = false
	_continue_button.visible = false
	visible = true


func hide_popup() -> void:
	visible = false


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
	var art_container: Control = Control.new()
	art_container.custom_minimum_size = Vector2(48, 48)
	info_row.add_child(art_container)

	_art_placeholder = ColorRect.new()
	_art_placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_placeholder.color = Color.GRAY
	art_container.add_child(_art_placeholder)

	_art_initial = Label.new()
	_art_initial.set_anchors_preset(Control.PRESET_CENTER)
	_art_initial.add_theme_font_size_override("font_size", 20)
	_art_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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


func _on_capture_pressed() -> void:
	if wild_glyph == null:
		return
	var roll: float = randf()
	var success: bool = roll <= capture_chance
	_capture_button.disabled = true
	_release_button.visible = false
	_result_label.visible = true
	_continue_button.visible = true

	if success:
		_result_label.text = "CAPTURED!"
		_result_label.add_theme_color_override("font_color", Color("#44FF44"))
	else:
		_result_label.text = "ESCAPED!"
		_result_label.add_theme_color_override("font_color", Color("#FF4444"))

	capture_attempted.emit(wild_glyph, success)


## Deterministic capture for testing
func attempt_capture_with_roll(roll: float) -> bool:
	if wild_glyph == null:
		return false
	var success: bool = roll <= capture_chance
	_capture_button.disabled = true
	_release_button.visible = false
	_result_label.visible = true
	_continue_button.visible = true

	if success:
		_result_label.text = "CAPTURED!"
		_result_label.add_theme_color_override("font_color", Color("#44FF44"))
	else:
		_result_label.text = "ESCAPED!"
		_result_label.add_theme_color_override("font_color", Color("#FF4444"))

	capture_attempted.emit(wild_glyph, success)
	return success


func _on_release_pressed() -> void:
	if wild_glyph == null:
		return
	capture_released.emit(wild_glyph)
