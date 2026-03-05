class_name SquadOverlay
extends PanelContainer

## Small panel showing squad status during dungeon exploration.
## Displays active squad (name + HP bar) and reserves (name only).
## Click any glyph name to open the detail popup.

signal glyph_clicked(glyph: GlyphInstance)

var _vbox: VBoxContainer = null
var _entries: Array[Dictionary] = []  ## [{glyph, name_label, hp_bar, hp_label, effect_badge}]
var _reserve_header: Label = null
var _reserve_rows: Array[HBoxContainer] = []
var _roster_state: RosterState = null
var _cargo: Array[GlyphInstance] = []
var _cargo_capacity: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(140, 0)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)


func setup(squad: Array[GlyphInstance], p_roster_state: RosterState = null, p_cargo: Array[GlyphInstance] = [], p_cargo_capacity: int = 0) -> void:
	_roster_state = p_roster_state
	_cargo = p_cargo
	_cargo_capacity = p_cargo_capacity
	_clear_entries()

	for g: GlyphInstance in squad:
		var entry: Dictionary = _make_entry(g)
		_entries.append(entry)

	## Reserve header (hidden until reserves exist)
	_reserve_header = Label.new()
	_reserve_header.text = "Reserves"
	_reserve_header.add_theme_font_size_override("font_size", 9)
	_reserve_header.add_theme_color_override("font_color", Color("#888888"))
	_reserve_header.visible = false
	_vbox.add_child(_reserve_header)

	refresh()


func refresh() -> void:
	## Update squad HP bars
	for entry: Dictionary in _entries:
		var g: GlyphInstance = entry["glyph"]
		var hp_bar: ProgressBar = entry["hp_bar"]
		var hp_label: Label = entry["hp_label"]

		hp_bar.max_value = g.max_hp
		hp_bar.value = g.current_hp
		hp_label.text = str(g.current_hp)

		## Color thresholds (same as CrawlerHUD)
		var pct: float = float(g.current_hp) / maxf(float(g.max_hp), 1.0)
		var fill: StyleBoxFlat = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null:
			if pct > 0.5:
				fill.bg_color = Color("#4CAF50")
			elif pct > 0.25:
				fill.bg_color = Color("#FFC107")
			else:
				fill.bg_color = Color("#F44336")

	## Update reserves list
	_refresh_reserves()


func _refresh_reserves() -> void:
	## Clear old reserve rows
	for row: HBoxContainer in _reserve_rows:
		_vbox.remove_child(row)
		row.queue_free()
	_reserve_rows.clear()

	## Use cargo (glyphs captured this rift) instead of full roster reserves
	var reserves: Array[GlyphInstance] = _cargo

	if _reserve_header != null:
		if _cargo_capacity > 0:
			_reserve_header.text = "Cargo %d/%d" % [reserves.size(), _cargo_capacity]
			_reserve_header.visible = true
		else:
			_reserve_header.visible = not reserves.is_empty()
			_reserve_header.text = "Reserves"

	for g: GlyphInstance in reserves:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					glyph_clicked.emit(g)
		)
		_vbox.add_child(row)
		_reserve_rows.append(row)

		var art: Control = _make_art_icon(g, 16, false)
		row.add_child(art)

		var label: Label = Label.new()
		var sp_name: String = g.species.name if g.species else "???"
		label.text = sp_name
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("#AAAAAA"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)


func _make_entry(g: GlyphInstance) -> Dictionary:
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.mouse_filter = Control.MOUSE_FILTER_STOP
	name_row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name_row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				glyph_clicked.emit(g)
	)
	_vbox.add_child(name_row)

	var art: Control = _make_art_icon(g, 20, false)
	name_row.add_child(art)

	var name_label: Label = Label.new()
	var sp_name_overlay: String = g.species.name if g.species else "???"
	var stars_overlay: String = g.get_mastery_stars_text()
	if stars_overlay != "":
		name_label.text = "%s %s" % [sp_name_overlay, stars_overlay]
	else:
		name_label.text = sp_name_overlay
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)

	## Effect badge (hidden by default, shown when glyph has an active effect)
	var effect_badge: Label = Label.new()
	effect_badge.add_theme_font_size_override("font_size", 10)
	effect_badge.add_theme_color_override("font_color", Color("#66DD88"))
	effect_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	effect_badge.visible = false
	name_row.add_child(effect_badge)

	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	_vbox.add_child(hp_row)

	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 10)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.show_percentage = false
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color("#4CAF50")
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color("#333333")
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	hp_row.add_child(hp_bar)

	var hp_label: Label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.custom_minimum_size = Vector2(24, 0)
	hp_row.add_child(hp_label)

	return {"glyph": g, "name_label": name_label, "hp_bar": hp_bar, "hp_label": hp_label, "effect_badge": effect_badge}


func _clear_entries() -> void:
	_entries.clear()
	_reserve_rows.clear()
	_reserve_header = null
	for child: Node in _vbox.get_children():
		_vbox.remove_child(child)
		child.queue_free()


func set_glyph_effect(glyph: GlyphInstance, text: String, tooltip: String = "") -> void:
	for entry: Dictionary in _entries:
		if entry["glyph"] == glyph:
			var badge: Label = entry["effect_badge"]
			badge.text = text
			badge.tooltip_text = tooltip
			badge.visible = true
			return


func clear_glyph_effect(glyph: GlyphInstance) -> void:
	for entry: Dictionary in _entries:
		if entry["glyph"] == glyph:
			var badge: Label = entry["effect_badge"]
			badge.visible = false
			return


func clear_all_effects() -> void:
	for entry: Dictionary in _entries:
		var badge: Label = entry["effect_badge"]
		badge.visible = false


func _make_art_icon(g: GlyphInstance, icon_size: int, clickable: bool = true) -> Control:
	## Small affinity-colored square with initial letter — same visual as GlyphPanel/GlyphCard
	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(icon_size, icon_size)

	if clickable:
		container.mouse_filter = Control.MOUSE_FILTER_STOP
		container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		container.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					glyph_clicked.emit(g)
		)
	else:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var aff: String = g.species.affinity if g.species else "neutral"
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Affinity.COLORS.get(aff, Affinity.COLORS["neutral"])
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(rect)

	var letter: Label = Label.new()
	letter.text = g.species.name[0].to_upper() if g.species else "?"
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", int(icon_size * 0.6))
	letter.add_theme_color_override("font_color", Color.WHITE)
	letter.add_theme_color_override("font_outline_color", Color.BLACK)
	letter.add_theme_constant_override("outline_size", 2)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(letter)
	GlyphArt.apply_texture(container, rect, letter, g.species.id if g.species else "", icon_size)

	return container
