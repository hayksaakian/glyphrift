class_name Barracks
extends Control

## View and manage glyph roster + active squad.
## Click glyphs to move between squad ↔ reserves.

signal done_pressed()

var roster_state: RosterState = null
var crawler_state: CrawlerState = null

var _title_label: Label = null
var _gp_label: Label = null
var _squad_counter: Label = null
var _squad_container: HBoxContainer = null
var _reserve_container: HBoxContainer = null
var _done_button: Button = null
var _info_label: Label = null

## Track GlyphCard instances for cleanup
var _squad_cards: Array[GlyphCard] = []
var _reserve_cards: Array[GlyphCard] = []
var _row_buttons: Array[Button] = []
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

	## Squad cards with row toggles
	for g: GlyphInstance in squad:
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS

		var card: GlyphCard = GlyphCard.new()
		card.setup(g)
		card.show_info_button = true
		card.card_clicked.connect(_on_squad_card_clicked)
		card.info_pressed.connect(_on_info_pressed)
		vbox.add_child(card)
		_squad_cards.append(card)

		var row_btn: Button = Button.new()
		row_btn.text = "[%s]" % g.row_position.capitalize()
		row_btn.custom_minimum_size = Vector2(80, 28)
		row_btn.pressed.connect(_make_row_toggle(g, row_btn))
		vbox.add_child(row_btn)
		_row_buttons.append(row_btn)

		_squad_container.add_child(vbox)

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

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 20.0
	main_vbox.offset_top = 20.0
	main_vbox.offset_right = -20.0
	main_vbox.offset_bottom = -20.0
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	## Title
	_title_label = Label.new()
	_title_label.text = "BARRACKS"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	main_vbox.add_child(_title_label)

	## Squad section
	var squad_header: Label = Label.new()
	squad_header.text = "Active Squad"
	squad_header.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(squad_header)

	_squad_container = HBoxContainer.new()
	_squad_container.add_theme_constant_override("separation", 12)
	main_vbox.add_child(_squad_container)

	## Reserve section
	var reserve_header: Label = Label.new()
	reserve_header.text = "Reserves"
	reserve_header.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(reserve_header)

	_reserve_container = HBoxContainer.new()
	_reserve_container.add_theme_constant_override("separation", 12)
	main_vbox.add_child(_reserve_container)

	## Info / counters
	_gp_label = Label.new()
	_gp_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(_gp_label)

	_squad_counter = Label.new()
	_squad_counter.add_theme_font_size_override("font_size", 12)
	_squad_counter.add_theme_color_override("font_color", Color("#AAAAAA"))
	main_vbox.add_child(_squad_counter)

	## Help text
	_info_label = Label.new()
	_info_label.text = "Click a glyph to move between squad and reserves"
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", Color("#888888"))
	main_vbox.add_child(_info_label)

	## Done button
	_done_button = Button.new()
	_done_button.text = "Done"
	_done_button.custom_minimum_size = Vector2(120, 36)
	_done_button.pressed.connect(func() -> void: done_pressed.emit())
	main_vbox.add_child(_done_button)

	## Detail popup (above everything)
	_detail_popup = GlyphDetailPopup.new()
	_detail_popup.name = "BarracksDetailPopup"
	add_child(_detail_popup)


func _on_squad_card_clicked(g: GlyphInstance) -> void:
	if g == null or roster_state == null or crawler_state == null:
		return
	## Move from squad to reserves (always allowed — total roster size unchanged)
	var new_squad: Array[GlyphInstance] = []
	for s: GlyphInstance in roster_state.active_squad:
		if s != g:
			new_squad.append(s)
	roster_state.set_active_squad(new_squad)
	refresh()


func _on_reserve_card_clicked(g: GlyphInstance) -> void:
	if g == null or roster_state == null or crawler_state == null:
		return
	## Move from reserves to squad if squad not full and GP fits
	if roster_state.active_squad.size() >= crawler_state.slots:
		return  ## Squad full
	var current_gp: int = _get_squad_gp()
	if current_gp + g.get_gp_cost() > crawler_state.capacity:
		return  ## Over GP capacity
	var new_squad: Array[GlyphInstance] = roster_state.active_squad.duplicate()
	new_squad.append(g)
	roster_state.set_active_squad(new_squad)
	refresh()


func _on_info_pressed(g: GlyphInstance) -> void:
	if g != null and _detail_popup != null:
		_detail_popup.show_glyph(g)


func _make_row_toggle(g: GlyphInstance, btn: Button) -> Callable:
	return func() -> void:
		if g.row_position == "front":
			g.row_position = "back"
		else:
			g.row_position = "front"
		btn.text = "[%s]" % g.row_position.capitalize()


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
	_row_buttons.clear()
	for child: Node in _squad_container.get_children():
		_squad_container.remove_child(child)
		child.queue_free()
	for child: Node in _reserve_container.get_children():
		_reserve_container.remove_child(child)
		child.queue_free()
