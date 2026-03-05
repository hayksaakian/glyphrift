class_name BattleLog
extends ScrollContainer

## Scrollable combat log using RichTextLabel. Auto-scrolls to bottom.

var _rich_text: RichTextLabel = null
var _entry_count: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 60)
	_build_ui()


func add_entry(text: String, color: Color = Color.WHITE) -> void:
	if _rich_text == null:
		return
	var hex: String = color.to_html(false)
	_rich_text.append_text("[color=#%s]%s[/color]\n" % [hex, text])
	_entry_count += 1


func clear_log() -> void:
	if _rich_text:
		_rich_text.clear()
	_entry_count = 0


func get_entry_count() -> int:
	return _entry_count


func _build_ui() -> void:
	## Dark background panel
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.1, 0.85)
	add_child(bg)

	_rich_text = RichTextLabel.new()
	_rich_text.bbcode_enabled = true
	_rich_text.scroll_following = true
	_rich_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich_text.add_theme_font_size_override("normal_font_size", 12)
	_rich_text.add_theme_color_override("default_color", Color("#CCCCCC"))
	add_child(_rich_text)
