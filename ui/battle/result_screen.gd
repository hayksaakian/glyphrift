class_name ResultScreen
extends ColorRect

## Win/loss overlay with Continue button.
## Victory: gold "VICTORY!" + stats. Defeat: red "DEFEAT!".

signal continue_pressed

var _vbox: VBoxContainer = null
var _title_label: Label = null
var _stats_label: Label = null
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
	_continue_button.visible = true

	## Animate in
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func show_defeat() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.text = "DEFEAT"
	_title_label.add_theme_color_override("font_color", Color("#FF4444"))
	_stats_label.visible = false
	_continue_button.visible = true

	## Animate in
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func hide_result() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_ui() -> void:
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_CENTER)
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 20)
	add_child(_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_vbox.add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_vbox.add_child(_stats_label)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(200, 40)
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	_vbox.add_child(_continue_button)
