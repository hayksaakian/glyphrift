class_name Barracks
extends Control

## View and manage glyph roster + active squad.
## Squad: front/back row layout (click card to toggle row, × to remove).
## Reserves: click card to add to squad.

signal done_pressed()

var roster_state: RosterState = null
var crawler_state: CrawlerState = null

var _title_label: Label = null
var _gp_label: Label = null
var _squad_counter: Label = null
var _front_row_container: HBoxContainer = null
var _back_row_container: HBoxContainer = null
var _reserve_container: HBoxContainer = null
var _done_button: Button = null
var _info_label: Label = null
var _feedback_label: Label = null
var _scroll: ScrollContainer = null

## Track GlyphCard instances for cleanup
var _squad_cards: Array[GlyphCard] = []
var _reserve_cards: Array[GlyphCard] = []
var _detail_popup: GlyphDetailPopup = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func setup(p_roster: RosterState, p_crawler: CrawlerState) -> void:
	roster_state = p_roster
	crawler_state = p_crawler
	if is_inside_tree():
		refresh()


func refresh() -> void:
	if roster_state == null or crawler_state == null:
		return

	_clear_cards()

	var squad: Array[GlyphInstance] = roster_state.active_squad
	var reserves: Array[GlyphInstance] = _get_reserves()

	## Squad cards — split into front/back rows
	for g: GlyphInstance in squad:
		var wrapper: VBoxContainer = VBoxContainer.new()
		wrapper.add_theme_constant_override("separation", 4)
		wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

		var card: GlyphCard = GlyphCard.new()
		card.setup(g)
		card.show_info_button = true
		card.card_clicked.connect(_on_squad_card_clicked)
		card.info_pressed.connect(_on_info_pressed)
		wrapper.add_child(card)
		_squad_cards.append(card)

		## Small remove button
		var remove_btn: Button = Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(80, 24)
		remove_btn.add_theme_font_size_override("font_size", 11)
		remove_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var captured_g: GlyphInstance = g
		remove_btn.pressed.connect(func() -> void: _remove_from_squad(captured_g))
		wrapper.add_child(remove_btn)

		if g.row_position == "front":
			_front_row_container.add_child(wrapper)
		else:
			_back_row_container.add_child(wrapper)

	## Reserve cards
	for g: GlyphInstance in reserves:
		var card: GlyphCard = GlyphCard.new()
		card.setup(g)
		card.show_info_button = true
		card.card_clicked.connect(_on_reserve_card_clicked)
		card.info_pressed.connect(_on_info_pressed)
		_reserve_container.add_child(card)
		_reserve_cards.append(card)

	_update_counters()


func _build_ui() -> void:
	## Background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 20.0
	_scroll.offset_top = 20.0
	_scroll.offset_right = -20.0
	_scroll.offset_bottom = -20.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 10)
	_scroll.add_child(main_vbox)

	## Title
	_title_label = Label.new()
	_title_label.text = "BARRACKS"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	## Front row section
	var front_header: Label = Label.new()
	front_header.text = "Front Row"
	front_header.add_theme_font_size_override("font_size", 16)
	front_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(front_header)

	_front_row_container = HBoxContainer.new()
	_front_row_container.add_theme_constant_override("separation", 12)
	_front_row_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_front_row_container.custom_minimum_size.y = 200
	main_vbox.add_child(_front_row_container)

	## Back row section
	var back_header: Label = Label.new()
	back_header.text = "Back Row"
	back_header.add_theme_font_size_override("font_size", 16)
	back_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(back_header)

	_back_row_container = HBoxContainer.new()
	_back_row_container.add_theme_constant_override("separation", 12)
	_back_row_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_back_row_container.custom_minimum_size.y = 200
	main_vbox.add_child(_back_row_container)

	## Hint for squad
	var squad_hint: Label = Label.new()
	squad_hint.text = "Click card to swap row  |  Remove to send to reserves"
	squad_hint.add_theme_font_size_override("font_size", 11)
	squad_hint.add_theme_color_override("font_color", Color("#888888"))
	squad_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(squad_hint)

	## Reserve section
	var reserve_header: Label = Label.new()
	reserve_header.text = "Reserves"
	reserve_header.add_theme_font_size_override("font_size", 16)
	reserve_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(reserve_header)

	_reserve_container = HBoxContainer.new()
	_reserve_container.add_theme_constant_override("separation", 12)
	_reserve_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(_reserve_container)

	## Info / counters
	_gp_label = Label.new()
	_gp_label.add_theme_font_size_override("font_size", 14)
	_gp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_gp_label)

	_squad_counter = Label.new()
	_squad_counter.add_theme_font_size_override("font_size", 12)
	_squad_counter.add_theme_color_override("font_color", Color("#AAAAAA"))
	_squad_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_squad_counter)

	## Help text
	_info_label = Label.new()
	_info_label.text = "Click a reserve glyph to add to squad"
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", Color("#888888"))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_info_label)

	## Done button (inside scroll)
	_done_button = Button.new()
	_done_button.text = "Done"
	_done_button.custom_minimum_size = Vector2(120, 36)
	_done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_done_button.pressed.connect(_on_done_pressed)
	main_vbox.add_child(_done_button)

	## Feedback label — fixed at bottom, outside scroll so always visible
	_feedback_label = Label.new()
	_feedback_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_feedback_label.offset_top = -40.0
	_feedback_label.offset_bottom = -8.0
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color("#FF4444"))
	_feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_feedback_label.add_theme_constant_override("outline_size", 3)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.visible = false
	add_child(_feedback_label)

	## Detail popup (above everything)
	_detail_popup = GlyphDetailPopup.new()
	_detail_popup.name = "BarracksDetailPopup"
	add_child(_detail_popup)


func _on_squad_card_clicked(g: GlyphInstance) -> void:
	if g == null or roster_state == null:
		return
	## Toggle row position (like FormationSetup)
	if g.row_position == "front":
		g.row_position = "back"
	else:
		g.row_position = "front"
	refresh()


func _remove_from_squad(g: GlyphInstance) -> void:
	if g == null or roster_state == null:
		return
	if roster_state.active_squad.size() <= 1:
		_show_feedback("Squad must have at least 1 glyph!")
		return
	var new_squad: Array[GlyphInstance] = []
	for s: GlyphInstance in roster_state.active_squad:
		if s != g:
			new_squad.append(s)
	roster_state.set_active_squad(new_squad)
	_clear_feedback()
	refresh()


func _on_reserve_card_clicked(g: GlyphInstance) -> void:
	if g == null or roster_state == null or crawler_state == null:
		return
	## Move from reserves to squad if squad not full and GP fits
	if roster_state.active_squad.size() >= crawler_state.slots:
		_show_feedback("Squad is full! (%d/%d slots)" % [roster_state.active_squad.size(), crawler_state.slots])
		return
	var current_gp: int = _get_squad_gp()
	if current_gp + g.get_gp_cost() > crawler_state.capacity:
		_show_feedback("Not enough GP! Need %d, only %d/%d available." % [
			g.get_gp_cost(), crawler_state.capacity - current_gp, crawler_state.capacity
		])
		return
	var new_squad: Array[GlyphInstance] = roster_state.active_squad.duplicate()
	new_squad.append(g)
	roster_state.set_active_squad(new_squad)
	_clear_feedback()
	refresh()


func _on_done_pressed() -> void:
	if roster_state == null or roster_state.active_squad.is_empty():
		_show_feedback("Squad must have at least 1 glyph!")
		return
	_clear_feedback()
	done_pressed.emit()


func _show_feedback(text: String) -> void:
	_feedback_label.text = text
	_feedback_label.visible = true
	_scroll.offset_bottom = -48.0


func _clear_feedback() -> void:
	_feedback_label.visible = false
	_feedback_label.text = ""
	_scroll.offset_bottom = -20.0


func _on_info_pressed(g: GlyphInstance) -> void:
	if g != null and _detail_popup != null:
		_detail_popup.show_glyph(g)


func _get_reserves() -> Array[GlyphInstance]:
	var reserves: Array[GlyphInstance] = []
	for g: GlyphInstance in roster_state.all_glyphs:
		if not roster_state.active_squad.has(g):
			reserves.append(g)
	return reserves


func _get_squad_gp() -> int:
	var total: int = 0
	for g: GlyphInstance in roster_state.active_squad:
		total += g.get_gp_cost()
	return total


func _update_counters() -> void:
	var gp: int = _get_squad_gp()
	_gp_label.text = "GP: %d/%d" % [gp, crawler_state.capacity]

	var reserves: Array[GlyphInstance] = _get_reserves()
	_squad_counter.text = "Squad: %d/%d  |  Reserves: %d/%d" % [
		roster_state.active_squad.size(), crawler_state.slots,
		reserves.size(), roster_state.max_reserves,
	]


func _clear_cards() -> void:
	_squad_cards.clear()
	_reserve_cards.clear()
	for child: Node in _front_row_container.get_children():
		_front_row_container.remove_child(child)
		child.queue_free()
	for child: Node in _back_row_container.get_children():
		_back_row_container.remove_child(child)
		child.queue_free()
	for child: Node in _reserve_container.get_children():
		_reserve_container.remove_child(child)
		child.queue_free()
