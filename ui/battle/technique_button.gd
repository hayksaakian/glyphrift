class_name TechniqueButton
extends Button

## Technique list button — shows [V] Name  R  Pw:8, greyed if on cooldown.
## When super-effective, shows a green SE! badge on the right edge.

signal technique_selected(technique: TechniqueDef)

const RANGE_TAGS: Dictionary = {
	"melee": "\ud83d\udc4a",
	"ranged": "\ud83c\udff9",
	"aoe": "\ud83d\udca5",
	"piercing": "\ud83c\udfaf",
}

const INTERRUPT_TRIGGERS: Dictionary = {
	"ON_MELEE": "vs Melee",
	"ON_RANGED": "vs Ranged",
	"ON_AOE": "vs AoE",
	"ON_SUPPORT": "vs Support",
}

var technique: TechniqueDef = null
var is_usable: bool = true
var _has_advantage: bool = false
var _se_badge: PanelContainer = null


func setup(p_technique: TechniqueDef, p_usable: bool = true) -> void:
	technique = p_technique
	is_usable = p_usable
	_has_advantage = false
	_update_display()


func setup_with_hint(p_technique: TechniqueDef, p_usable: bool, p_has_advantage: bool) -> void:
	technique = p_technique
	is_usable = p_usable
	_has_advantage = p_has_advantage
	_update_display()


func _ready() -> void:
	pressed.connect(_on_pressed)
	clip_text = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	_build_se_badge()
	if technique != null:
		_update_display()


func _update_display() -> void:
	if technique == null:
		text = "???"
		if _se_badge != null:
			_se_badge.visible = false
		return

	var aff_tag: String = Affinity.EMOJI.get(technique.affinity, "?")
	var range_tag: String = RANGE_TAGS.get(technique.range_type, "?")

	if technique.category == "interrupt":
		var trigger_label: String = INTERRUPT_TRIGGERS.get(technique.interrupt_trigger, "Guard")
		text = "%s %s  \U0001f6e1\ufe0f %s" % [aff_tag, technique.name, trigger_label]
		if technique.power > 0:
			text += "  Pw:%d" % technique.power
	elif technique.power > 0:
		text = "%s %s  %s %d" % [aff_tag, technique.name, range_tag, technique.power]
	elif technique.category == "support":
		text = "%s %s  %s" % [aff_tag, technique.name, technique.support_effect.capitalize()]
	else:
		text = "%s %s  %s" % [aff_tag, technique.name, range_tag]

	if technique.cooldown > 0:
		text += "  \u231b%d" % technique.cooldown

	## Show/hide badge
	if _se_badge != null:
		_se_badge.visible = _has_advantage

	## Tooltip with description and effect details
	tooltip_text = _build_tooltip()

	disabled = not is_usable
	if not is_usable:
		modulate = Color(0.5, 0.5, 0.5, 0.8)
	else:
		modulate = Color.WHITE
		var aff_color: Color = Affinity.COLORS.get(technique.affinity, Color.WHITE)
		add_theme_color_override("font_color", aff_color)


func _build_tooltip() -> String:
	if technique == null:
		return ""
	var lines: Array[String] = []
	if technique.description != "":
		lines.append(technique.description)
	if technique.status_effect != "":
		lines.append("Status: %s (%d%%)" % [technique.status_effect.capitalize(), technique.status_accuracy])
	if technique.support_effect != "":
		var pct: int = int(technique.support_value * 100)
		lines.append("Effect: %s %d%%" % [technique.support_effect.capitalize(), pct])
	if technique.interrupt_trigger != "":
		lines.append("Interrupt: %s" % technique.interrupt_trigger.capitalize())
	return "\n".join(lines)


func _build_se_badge() -> void:
	_se_badge = PanelContainer.new()
	_se_badge.visible = false
	_se_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_se_badge.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_se_badge.offset_left = -46.0
	_se_badge.offset_right = 0.0
	_se_badge.offset_top = 0.0
	_se_badge.offset_bottom = 0.0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#1a4010")
	style.border_color = Color("#44AA22")
	style.border_width_left = 1
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	_se_badge.add_theme_stylebox_override("panel", style)
	add_child(_se_badge)

	var label: Label = Label.new()
	label.text = "S.EFF"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#66FF66"))
	_se_badge.add_child(label)


func _on_pressed() -> void:
	if technique != null and is_usable:
		technique_selected.emit(technique)
