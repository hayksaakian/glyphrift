class_name ItemPopup
extends PanelContainer

## Shows crawler inventory with item names, descriptions, and Use buttons.
## Items like repair_hull and restore_energy apply immediately.
## heal_glyph is used between battles to restore a glyph.

signal item_used(item: ItemDef)
signal closed()

var crawler: CrawlerState = null
var roster_state: RosterState = null

var _title_label: Label = null
var _item_list: VBoxContainer = null
var _empty_label: Label = null
var _close_button: Button = null
var _item_rows: Array[HBoxContainer] = []


func _ready() -> void:
	custom_minimum_size = Vector2(360, 300)
	visible = false
	_build_ui()


func show_items(p_crawler: CrawlerState, p_roster: RosterState = null) -> void:
	crawler = p_crawler
	roster_state = p_roster
	_rebuild_list()
	visible = true


func hide_popup() -> void:
	visible = false


func _build_ui() -> void:
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

	_title_label = Label.new()
	_title_label.text = "INVENTORY"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## Cap height so popup doesn't overflow screen
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.add_theme_constant_override("separation", 6)
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_list)

	_empty_label = Label.new()
	_empty_label.text = "No items."
	_empty_label.add_theme_font_size_override("font_size", 13)
	_empty_label.add_theme_color_override("font_color", Color("#888888"))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_empty_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(100, 32)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(func() -> void: closed.emit())
	vbox.add_child(_close_button)


func _rebuild_list() -> void:
	_item_rows.clear()
	for child: Node in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()

	if crawler == null or crawler.items.is_empty():
		_empty_label.visible = true
		return
	_empty_label.visible = false

	for item: ItemDef in crawler.items:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_item_list.add_child(row)
		_item_rows.append(row)

		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 1)
		row.add_child(info_col)

		var name_label: Label = Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 13)
		info_col.add_child(name_label)

		var desc_label: Label = Label.new()
		desc_label.text = item.description
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(desc_label)

		var use_btn: Button = Button.new()
		use_btn.name = "UseButton_%s" % item.name.replace(" ", "")
		use_btn.text = "Use"
		use_btn.custom_minimum_size = Vector2(60, 28)
		use_btn.pressed.connect(_on_use_pressed.bind(item))
		row.add_child(use_btn)


func _on_use_pressed(item: ItemDef) -> void:
	if crawler == null:
		return
	var applied: bool = _apply_item(item)
	if applied:
		crawler.use_item(item)
		item_used.emit(item)
		_rebuild_list()


func _apply_item(item: ItemDef) -> bool:
	match item.effect_type:
		"repair_hull":
			crawler.hull_hp = mini(crawler.hull_hp + int(item.effect_value), crawler.max_hull_hp)
			crawler.hull_changed.emit(crawler.hull_hp, crawler.max_hull_hp)
			return true
		"restore_energy":
			crawler.energy = mini(crawler.energy + int(item.effect_value), crawler.max_energy)
			crawler.energy_changed.emit(crawler.energy, crawler.max_energy)
			return true
		"heal_glyph":
			## Heal the most damaged glyph
			if roster_state == null:
				return false
			var most_damaged: GlyphInstance = null
			var most_missing: int = 0
			for g: GlyphInstance in roster_state.active_squad:
				var missing: int = g.max_hp - g.current_hp
				if missing > most_missing:
					most_missing = missing
					most_damaged = g
			if most_damaged == null:
				return false
			most_damaged.current_hp = most_damaged.max_hp
			most_damaged.is_knocked_out = false
			return true
		"status_immunity", "capture_bonus":
			## These are passive effects — just consume for now
			return true
		_:
			return false
