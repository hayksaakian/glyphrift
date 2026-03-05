class_name BattleLog
extends Control

## Collapsible combat log. Default compact (75px, 2-3 lines).
## Expand button toggles to full-height scrollable history.

var _rich_text: RichTextLabel = null
var _scroll: ScrollContainer = null
var _toggle_button: Button = null
var _bg: ColorRect = null
var _entry_count: int = 0
var _expanded: bool = false

const COMPACT_HEIGHT: float = 75.0
const EXPANDED_HEIGHT: float = 220.0


func _ready() -> void:
	custom_minimum_size = Vector2(300, COMPACT_HEIGHT)
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


func set_expanded(value: bool) -> void:
	_expanded = value
	if _toggle_button != null:
		_toggle_button.text = "LOG \u25b2" if _expanded else "LOG \u25bc"
	var target_h: float = EXPANDED_HEIGHT if _expanded else COMPACT_HEIGHT
	custom_minimum_size.y = target_h
	## Adjust parent offset if anchored to bottom
	var parent_offset: float = -(target_h + 10.0)
	if get_parent() != null:
		offset_top = parent_offset


func _on_toggle_pressed() -> void:
	set_expanded(not _expanded)


func _build_ui() -> void:
	## Dark background
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.05, 0.05, 0.1, 0.85)
	add_child(_bg)

	## Toggle button (top-right corner)
	_toggle_button = Button.new()
	_toggle_button.name = "ToggleLogButton"
	_toggle_button.text = "LOG \u25bc"
	_toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle_button.offset_left = -52.0
	_toggle_button.offset_top = 2.0
	_toggle_button.offset_right = -2.0
	_toggle_button.offset_bottom = 20.0
	_toggle_button.add_theme_font_size_override("font_size", 9)
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)

	## Scroll container for rich text
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 0.0
	add_child(_scroll)

	_rich_text = RichTextLabel.new()
	_rich_text.bbcode_enabled = true
	_rich_text.scroll_following = true
	_rich_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rich_text.add_theme_font_size_override("normal_font_size", 12)
	_rich_text.add_theme_color_override("default_color", Color("#CCCCCC"))
	_scroll.add_child(_rich_text)
