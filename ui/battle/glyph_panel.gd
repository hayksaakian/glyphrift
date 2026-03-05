class_name GlyphPanel
extends PanelContainer

## Individual glyph display — colored rect, HP bar, status icons,
## guard border, KO grey modulate.

signal panel_clicked(glyph: GlyphInstance)


const STATUS_COLORS: Dictionary = {
	"burn": Color("#FF4444"),
	"stun": Color("#FFDD44"),
	"slow": Color("#4488FF"),
	"weaken": Color("#FF8800"),
	"corrode": Color("#8B6914"),
	"shield": Color("#00DDDD"),
}

const STATUS_LETTERS: Dictionary = {
	"burn": "B",
	"stun": "S",
	"weaken": "W",
	"slow": "L",
	"corrode": "C",
	"shield": "H",
}


var glyph: GlyphInstance = null

var _hbox: HBoxContainer = null
var _vbox: VBoxContainer = null
var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _status_row: HBoxContainer = null
var _guard_border: Panel = null
var _guard_label: Label = null
var _affinity_rect: ColorRect = null
var _affinity_label: Label = null
var _art_initial_label: Label = null
var _art_container: PanelContainer = null
var _active_border: Panel = null
var _row_badge: PanelContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(180, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()

	if glyph != null:
		refresh()


func setup(p_glyph: GlyphInstance) -> void:
	glyph = p_glyph
	if is_inside_tree():
		refresh()


func refresh() -> void:
	if glyph == null:
		return

	## Name
	_name_label.text = glyph.species.name if glyph.species else "???"

	## Affinity color + label + art placeholder
	var aff: String = glyph.species.affinity if glyph.species else "neutral"
	var aff_color: Color = Affinity.COLORS.get(aff, Affinity.COLORS["neutral"])
	_affinity_rect.color = aff_color
	_affinity_label.text = "%s %s" % [Affinity.EMOJI.get(aff, ""), aff.to_upper()]
	_art_initial_label.text = glyph.species.name[0].to_upper() if glyph.species else "?"
	GlyphArt.apply_texture(_art_container, _affinity_rect, _art_initial_label, glyph.species.id if glyph.species else "", 60)

	## HP bar
	_hp_bar.max_value = glyph.max_hp
	_hp_bar.value = glyph.current_hp
	_hp_label.text = "%d/%d" % [glyph.current_hp, glyph.max_hp]

	## HP bar color
	var hp_pct: float = float(glyph.current_hp) / maxf(float(glyph.max_hp), 1.0)
	var bar_style: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style:
		if hp_pct > 0.5:
			bar_style.bg_color = Color("#4CAF50")
		elif hp_pct > 0.25:
			bar_style.bg_color = Color("#FFC107")
		else:
			bar_style.bg_color = Color("#F44336")

	## Guard visual
	_guard_border.visible = glyph.is_guarding

	## KO modulate
	if glyph.is_knocked_out:
		modulate = Color(0.4, 0.4, 0.4, 0.7)
	else:
		modulate = Color.WHITE

	## Back-row reduction badge
	if _row_badge != null:
		_row_badge.visible = glyph.row_position == "back"

	## Status icons
	_refresh_statuses()


func set_active_turn(active: bool) -> void:
	if _active_border != null:
		_active_border.visible = active


func animate_hp(target_hp: int, duration: float = 0.4) -> void:
	if glyph == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_hp_bar, "value", float(target_hp), duration)
	tween.tween_callback(func() -> void:
		_hp_label.text = "%d/%d" % [glyph.current_hp, glyph.max_hp]
		_update_hp_bar_color()
	)


func flash_damage() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func flash_heal() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.3, 1.0, 0.3), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func play_ko() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.4, 0.4, 0.4, 0.7), 0.5)


func _build_ui() -> void:
	## Horizontal layout: art placeholder (left) + stats (right)
	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 6)
	_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_hbox)

	## --- Left: Art placeholder (60x60 colored square with initial letter) ---
	_art_container = PanelContainer.new()
	var art_container: PanelContainer = _art_container
	art_container.custom_minimum_size = Vector2(60, 60)
	art_container.mouse_filter = Control.MOUSE_FILTER_PASS
	var art_style: StyleBoxFlat = StyleBoxFlat.new()
	art_style.bg_color = Color(0, 0, 0, 0)
	art_container.add_theme_stylebox_override("panel", art_style)
	_hbox.add_child(art_container)

	_affinity_rect = ColorRect.new()
	_affinity_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_affinity_rect.color = Affinity.COLORS["neutral"]
	_affinity_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	art_container.add_child(_affinity_rect)

	_art_initial_label = Label.new()
	_art_initial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art_initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_art_initial_label.add_theme_font_size_override("font_size", 22)
	_art_initial_label.add_theme_color_override("font_color", Color.WHITE)
	_art_initial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_art_initial_label.add_theme_constant_override("outline_size", 3)
	_art_initial_label.mouse_filter = Control.MOUSE_FILTER_PASS
	art_container.add_child(_art_initial_label)

	## (Back-row badge added in stats column below, not overlaid on art)

	## --- Right: Stats column ---
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 1)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_hbox.add_child(_vbox)

	## Affinity label (small, e.g. "ELECTRIC")
	_affinity_label = Label.new()
	_affinity_label.add_theme_font_size_override("font_size", 9)
	_affinity_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_affinity_label.text = ""
	_affinity_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_affinity_label)

	## Name + back-row badge on same line
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(name_row)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_row.add_child(_name_label)

	## Back-row reduction badge (inline, small)
	_row_badge = PanelContainer.new()
	_row_badge.visible = false
	_row_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	_row_badge.tooltip_text = "Back row: melee & ranged damage reduced by 30%"
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.15, 0.25, 0.45, 0.8)
	badge_style.set_corner_radius_all(3)
	badge_style.content_margin_left = 3.0
	badge_style.content_margin_right = 3.0
	badge_style.content_margin_top = 0.0
	badge_style.content_margin_bottom = 0.0
	_row_badge.add_theme_stylebox_override("panel", badge_style)
	var badge_label: Label = Label.new()
	badge_label.text = "\u221230%"
	badge_label.add_theme_font_size_override("font_size", 9)
	badge_label.add_theme_color_override("font_color", Color("#88AAFF"))
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_badge.add_child(badge_label)
	name_row.add_child(_row_badge)

	## HP bar + label on same line
	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	hp_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(hp_row)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 16)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color("#4CAF50")
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color("#333333")
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("background", bg_style)
	hp_row.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 11)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_PASS
	hp_row.add_child(_hp_label)

	## Status row
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 2)
	_status_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_status_row)

	## Guard border overlay (5px width + GUARD label)
	_guard_border = Panel.new()
	_guard_border.visible = false
	var guard_style: StyleBoxFlat = StyleBoxFlat.new()
	guard_style.bg_color = Color(0, 0, 0, 0)
	guard_style.border_color = Color("#00BFFF")
	guard_style.border_width_left = 5
	guard_style.border_width_right = 5
	guard_style.border_width_top = 5
	guard_style.border_width_bottom = 5
	_guard_border.add_theme_stylebox_override("panel", guard_style)
	_guard_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guard_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_guard_border)

	_guard_label = Label.new()
	_guard_label.text = "GUARD"
	_guard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guard_label.add_theme_font_size_override("font_size", 10)
	_guard_label.add_theme_color_override("font_color", Color("#00BFFF"))
	_guard_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_guard_label.offset_top = -20.0
	_guard_border.add_child(_guard_label)

	## Active turn border overlay (gold, hidden by default)
	_active_border = Panel.new()
	_active_border.visible = false
	var active_style: StyleBoxFlat = StyleBoxFlat.new()
	active_style.bg_color = Color(0, 0, 0, 0)
	active_style.border_color = Color("#FFD700")
	active_style.border_width_left = 3
	active_style.border_width_right = 3
	active_style.border_width_top = 3
	active_style.border_width_bottom = 3
	_active_border.add_theme_stylebox_override("panel", active_style)
	_active_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_active_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_active_border)

	## Panel background
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1A2E")
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", panel_style)


func flash_status(status_id: String) -> void:
	## Brief color flash on the status icon when it lands
	for child: Node in _status_row.get_children():
		if child.has_meta("status_id") and child.get_meta("status_id") == status_id:
			var tween: Tween = create_tween()
			tween.tween_property(child, "modulate", Color(2.0, 2.0, 2.0), 0.1)
			tween.tween_property(child, "modulate", Color.WHITE, 0.2)
			return


func _refresh_statuses() -> void:
	## Clear existing icons
	for child: Node in _status_row.get_children():
		child.queue_free()

	if glyph == null:
		return

	for status_id: String in glyph.active_statuses:
		var icon: PanelContainer = PanelContainer.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.set_meta("status_id", status_id)
		icon.tooltip_text = status_id.capitalize()
		var icon_style: StyleBoxFlat = StyleBoxFlat.new()
		icon_style.bg_color = STATUS_COLORS.get(status_id, Color.WHITE)
		icon_style.corner_radius_top_left = 3
		icon_style.corner_radius_top_right = 3
		icon_style.corner_radius_bottom_left = 3
		icon_style.corner_radius_bottom_right = 3
		icon.add_theme_stylebox_override("panel", icon_style)

		var letter: Label = Label.new()
		letter.text = STATUS_LETTERS.get(status_id, "?")
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 12)
		letter.add_theme_color_override("font_color", Color.WHITE)
		icon.add_child(letter)

		_status_row.add_child(icon)


func _update_hp_bar_color() -> void:
	if glyph == null:
		return
	var hp_pct: float = float(glyph.current_hp) / maxf(float(glyph.max_hp), 1.0)
	var bar_style: StyleBoxFlat = _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if bar_style:
		if hp_pct > 0.5:
			bar_style.bg_color = Color("#4CAF50")
		elif hp_pct > 0.25:
			bar_style.bg_color = Color("#FFC107")
		else:
			bar_style.bg_color = Color("#F44336")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			panel_clicked.emit(glyph)
