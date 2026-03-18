class_name SquadSwapPopup
extends ColorRect

## Mid-rift squad swap modal.
## Shows active squad (click to bench) and bench (click to deploy).
## Enforces slot limit, GP capacity, and bench capacity.
## When both sides are full, enters direct swap mode (click one from each side).

signal swap_completed()
signal swap_cancelled()

var roster_state: RosterState = null
var crawler_state: CrawlerState = null
var rift_pool: Array[GlyphInstance] = []  ## Set by DungeonScene — all glyphs available in this rift

var _panel: PanelContainer = null
var _squad_vbox: VBoxContainer = null
var _bench_vbox: VBoxContainer = null
var _status_label: Label = null
var _feedback_label: Label = null
var _done_button: Button = null

## Direct swap state — for when both squad and bench are at capacity
var _swap_source: GlyphInstance = null  ## First glyph selected for direct swap
var _swap_source_is_squad: bool = false  ## True if source came from squad side


func _ready() -> void:
	_build_ui()


func show_popup() -> void:
	_swap_source = null
	visible = true
	_refresh()


func hide_popup() -> void:
	visible = false


func _build_ui() -> void:
	## Full-screen dark overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.7)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	## Center panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(400, 440)
	_panel.offset_left = -200.0
	_panel.offset_right = 200.0
	_panel.offset_top = -220.0
	_panel.offset_bottom = 220.0
	add_child(_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", panel_style)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	## Title
	var title: Label = Label.new()
	title.text = "Squad Swap"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	## Status (GP / slots)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_status_label)

	## Two-column layout
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(columns)

	## Left column — Active Squad
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)

	var squad_header: Label = Label.new()
	squad_header.text = "Active Squad"
	squad_header.add_theme_font_size_override("font_size", 13)
	squad_header.add_theme_color_override("font_color", Color("#88DD88"))
	squad_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(squad_header)

	var squad_hint: Label = Label.new()
	squad_hint.text = "(click to bench)"
	squad_hint.add_theme_font_size_override("font_size", 10)
	squad_hint.add_theme_color_override("font_color", Color("#666666"))
	squad_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(squad_hint)

	_squad_vbox = VBoxContainer.new()
	_squad_vbox.add_theme_constant_override("separation", 4)
	left.add_child(_squad_vbox)

	## Right column — Bench
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	columns.add_child(right)

	var bench_header: Label = Label.new()
	bench_header.text = "Bench"
	bench_header.add_theme_font_size_override("font_size", 13)
	bench_header.add_theme_color_override("font_color", Color("#88AADD"))
	bench_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(bench_header)

	var bench_hint: Label = Label.new()
	bench_hint.text = "(click to deploy)"
	bench_hint.add_theme_font_size_override("font_size", 10)
	bench_hint.add_theme_color_override("font_color", Color("#666666"))
	bench_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(bench_hint)

	_bench_vbox = VBoxContainer.new()
	_bench_vbox.add_theme_constant_override("separation", 4)
	right.add_child(_bench_vbox)

	## Feedback label
	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", 11)
	_feedback_label.add_theme_color_override("font_color", Color("#FF6666"))
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.text = ""
	main_vbox.add_child(_feedback_label)

	## Done button
	_done_button = Button.new()
	_done_button.text = "Done"
	_done_button.custom_minimum_size = Vector2(120, 36)
	_done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_done_button.pressed.connect(_on_done_pressed)
	main_vbox.add_child(_done_button)


func _refresh() -> void:
	_feedback_label.text = ""

	## Update status
	var squad_gp: int = _get_squad_gp()
	var max_gp: int = crawler_state.get_effective_capacity() if crawler_state else 12
	var squad_size: int = roster_state.active_squad.size() if roster_state else 0
	var max_slots: int = crawler_state.slots if crawler_state else 3
	var bench_size: int = _get_bench_glyphs().size()
	var max_bench: int = crawler_state.get_effective_bench_slots() if crawler_state else 2
	_status_label.text = "Slots: %d/%d  |  GP: %d/%d  |  Bench: %d/%d" % [squad_size, max_slots, squad_gp, max_gp, bench_size, max_bench]

	## Show direct swap hint when both sides are at capacity
	if squad_size >= max_slots and bench_size >= max_bench:
		_show_feedback("Both full — click one from each side to swap.")
		_feedback_label.add_theme_color_override("font_color", Color("#AAAAAA"))

	## Rebuild squad rows
	_clear_children(_squad_vbox)
	if roster_state != null:
		for g: GlyphInstance in roster_state.active_squad:
			var row: HBoxContainer = _make_glyph_row(g, true)
			_squad_vbox.add_child(row)
		if roster_state.active_squad.is_empty():
			var empty_label: Label = Label.new()
			empty_label.text = "(empty)"
			empty_label.add_theme_font_size_override("font_size", 11)
			empty_label.add_theme_color_override("font_color", Color("#666666"))
			_squad_vbox.add_child(empty_label)

	## Rebuild bench rows
	_clear_children(_bench_vbox)
	var bench_glyphs: Array[GlyphInstance] = _get_bench_glyphs()
	for g: GlyphInstance in bench_glyphs:
		var row: HBoxContainer = _make_glyph_row(g, false)
		_bench_vbox.add_child(row)
	if bench_glyphs.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "(none)"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color("#666666"))
		_bench_vbox.add_child(empty_label)


func _get_bench_glyphs() -> Array[GlyphInstance]:
	## Rift pool glyphs not currently in the active squad
	if roster_state == null:
		return []
	var result: Array[GlyphInstance] = []
	for g: GlyphInstance in rift_pool:
		if not roster_state.active_squad.has(g):
			result.append(g)
	return result


func _make_glyph_row(g: GlyphInstance, is_squad: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	## Art icon
	var art: Control = _make_art_icon(g, 24)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)

	## Name + HP
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_label: Label = Label.new()
	var sp_name: String = g.species.name if g.species else "???"
	var stars: String = g.get_mastery_stars_text()
	name_label.text = "%s %s" % [sp_name, stars] if stars != "" else sp_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	var hp_label: Label = Label.new()
	hp_label.text = "HP %d/%d  GP %d  %s" % [g.current_hp, g.max_hp, g.get_gp_cost(), g.row_position]
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color("#999999"))
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hp_label)

	## KO indicator
	if g.current_hp <= 0:
		name_label.add_theme_color_override("font_color", Color("#666666"))
		hp_label.text = "KO'd"
		hp_label.add_theme_color_override("font_color", Color("#FF4444"))

	## Highlight if this is the selected swap source
	if _swap_source == g:
		row.add_theme_constant_override("separation", 4)
		name_label.add_theme_color_override("font_color", Color("#FFD700"))

	## Click handler
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_on_glyph_clicked(g, is_squad)
	)
	return row


func _on_glyph_clicked(g: GlyphInstance, is_squad: bool) -> void:
	## If we have a pending swap source from the opposite side, execute the swap
	if _swap_source != null:
		if is_squad and not _swap_source_is_squad:
			## Clicked squad glyph, source is bench → swap them
			_execute_direct_swap(_swap_source, g)
			return
		elif not is_squad and _swap_source_is_squad:
			## Clicked bench glyph, source is squad → swap them
			_execute_direct_swap(g, _swap_source)
			return
		else:
			## Same side — cancel selection and re-select
			_swap_source = null

	## Normal click behavior
	if is_squad:
		_bench_glyph(g)
	else:
		_deploy_glyph(g)


func _bench_glyph(g: GlyphInstance) -> void:
	## Remove from active squad → goes to bench
	if roster_state == null:
		return
	if roster_state.active_squad.size() <= 1:
		_show_feedback("Squad must have at least 1 glyph!")
		return

	## Check bench capacity
	var bench_size: int = _get_bench_glyphs().size()
	var max_bench: int = crawler_state.get_effective_bench_slots() if crawler_state else 2
	if bench_size >= max_bench:
		## Bench full — enter direct swap mode (select this squad glyph, then click a bench glyph)
		_swap_source = g
		_swap_source_is_squad = true
		_show_feedback("Bench full — now click a bench glyph to swap with.")
		_feedback_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		_refresh()
		return

	var new_squad: Array[GlyphInstance] = []
	for s: GlyphInstance in roster_state.active_squad:
		if s != g:
			new_squad.append(s)
	roster_state.set_active_squad(new_squad)
	_swap_source = null
	_refresh()


func _deploy_glyph(g: GlyphInstance) -> void:
	## Add bench glyph to active squad
	if roster_state == null or crawler_state == null:
		return
	if g.current_hp <= 0:
		_show_feedback("Can't deploy a KO'd glyph!")
		return
	if roster_state.active_squad.size() >= crawler_state.slots:
		## Squad full — enter direct swap mode (select this bench glyph, then click a squad glyph)
		_swap_source = g
		_swap_source_is_squad = false
		_show_feedback("Squad full — now click a squad glyph to swap with.")
		_feedback_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		_refresh()
		return
	var current_gp: int = _get_squad_gp()
	if current_gp + g.get_gp_cost() > crawler_state.get_effective_capacity():
		_show_feedback("Not enough GP! (%d + %d > %d)" % [current_gp, g.get_gp_cost(), crawler_state.get_effective_capacity()])
		return
	var new_squad: Array[GlyphInstance] = roster_state.active_squad.duplicate()
	new_squad.append(g)
	roster_state.set_active_squad(new_squad)
	_swap_source = null
	_refresh()


func _execute_direct_swap(bench_glyph: GlyphInstance, squad_glyph: GlyphInstance) -> void:
	## Atomically swap a bench glyph and a squad glyph
	if roster_state == null or crawler_state == null:
		return
	if bench_glyph.current_hp <= 0:
		_show_feedback("Can't deploy a KO'd glyph!")
		_swap_source = null
		_refresh()
		return

	## Check GP: remove squad glyph's GP, add bench glyph's GP
	var current_gp: int = _get_squad_gp()
	var new_gp: int = current_gp - squad_glyph.get_gp_cost() + bench_glyph.get_gp_cost()
	if new_gp > crawler_state.get_effective_capacity():
		_show_feedback("Not enough GP! (%d > %d)" % [new_gp, crawler_state.get_effective_capacity()])
		_swap_source = null
		_refresh()
		return

	## Build new squad: replace squad_glyph with bench_glyph
	var new_squad: Array[GlyphInstance] = []
	for s: GlyphInstance in roster_state.active_squad:
		if s == squad_glyph:
			new_squad.append(bench_glyph)
		else:
			new_squad.append(s)
	roster_state.set_active_squad(new_squad)
	_swap_source = null
	_refresh()


func _get_squad_gp() -> int:
	if roster_state == null:
		return 0
	var total: int = 0
	for g: GlyphInstance in roster_state.active_squad:
		total += g.get_gp_cost()
	return total


func _show_feedback(msg: String) -> void:
	_feedback_label.text = msg
	_feedback_label.add_theme_color_override("font_color", Color("#FF6666"))


func _on_done_pressed() -> void:
	if roster_state != null and roster_state.active_squad.is_empty():
		_show_feedback("Squad can't be empty!")
		return
	_swap_source = null
	hide_popup()
	swap_completed.emit()


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _make_art_icon(g: GlyphInstance, icon_size: int) -> Control:
	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(icon_size, icon_size)
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
