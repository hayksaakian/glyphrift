class_name CrawlerBay
extends Control

## Crawler Bay — 3-column, 2-row dashboard.
## Row 1 (top): Milestones | Equipment Hints | Crawler Stats
## Row 2 (bottom): Chassis Selector | Computer Selector | Accessory Selector

signal back_pressed

var crawler_state: CrawlerState = null
var milestone_tracker: MilestoneTracker = null
var data_loader: Node = null

## Row 1 containers
var _milestone_vbox: VBoxContainer = null
var _hints_vbox: VBoxContainer = null
var _stats_vbox: VBoxContainer = null

## Row 2 containers
var _chassis_vbox: VBoxContainer = null
var _computer_vbox: VBoxContainer = null
var _accessory_vbox: VBoxContainer = null

## Test compatibility
var _chassis_buttons: Dictionary = {}  ## chassis_id → Button
var _equipment_buttons: Dictionary = {}  ## slot → Button (hidden, for test access)

## Milestone text that unlocks each chassis (for locked display)
const _CHASSIS_UNLOCK: Dictionary = {
	"ironclad": "Discover 1 hidden cache in a rift",
	"scout": "Discover 3 hidden caches total",
	"hauler": "Discover 5 hidden caches total",
}

const _EQUIPMENT_HINTS: Array = [
	{"text": "Equipment drops from cache and hidden rooms (~15% chance).", "color": "#999999"},
	{"text": "Rarer items are more likely from hidden rooms.", "color": "#888888"},
	{"text": "Each piece is unique — once found, it's yours to keep.", "color": "#888888"},
	{"text": "Equip before entering a rift. Bonuses apply for the run.", "color": "#888888"},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func setup(p_crawler: CrawlerState, p_milestones: MilestoneTracker, p_data_loader: Node = null) -> void:
	crawler_state = p_crawler
	milestone_tracker = p_milestones
	data_loader = p_data_loader


func refresh() -> void:
	_refresh_stats()
	_refresh_milestones()
	_refresh_hints()
	_refresh_chassis()
	_refresh_equipment_column(_computer_vbox, "computer")
	_refresh_equipment_column(_accessory_vbox, "accessory")


func _build_ui() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 44.0
	scroll.offset_left = 20.0
	scroll.offset_right = -20.0
	scroll.offset_bottom = -20.0
	add_child(scroll)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(main_vbox)

	## ====== ROW 1 (top): Milestones | Hints | Stats ======
	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 20)
	main_vbox.add_child(row1)

	## -- Milestones column --
	var ms_col: VBoxContainer = VBoxContainer.new()
	ms_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ms_col.size_flags_stretch_ratio = 1.2
	ms_col.add_theme_constant_override("separation", 6)
	row1.add_child(ms_col)

	_add_section_header(ms_col, "MILESTONES")

	_milestone_vbox = VBoxContainer.new()
	_milestone_vbox.add_theme_constant_override("separation", 4)
	ms_col.add_child(_milestone_vbox)

	## -- Hints column --
	var hints_col: VBoxContainer = VBoxContainer.new()
	hints_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints_col.size_flags_stretch_ratio = 1.0
	hints_col.add_theme_constant_override("separation", 6)
	row1.add_child(hints_col)

	_add_section_header(hints_col, "EQUIPMENT SOURCES")

	_hints_vbox = VBoxContainer.new()
	_hints_vbox.add_theme_constant_override("separation", 6)
	hints_col.add_child(_hints_vbox)

	## -- Stats column --
	var stats_col: VBoxContainer = VBoxContainer.new()
	stats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_col.size_flags_stretch_ratio = 0.8
	stats_col.add_theme_constant_override("separation", 6)
	row1.add_child(stats_col)

	_add_section_header(stats_col, "CRAWLER STATS")

	_stats_vbox = VBoxContainer.new()
	_stats_vbox.add_theme_constant_override("separation", 4)
	stats_col.add_child(_stats_vbox)

	## ====== ROW 2 (bottom): Chassis | Computer | Accessory ======
	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 20)
	main_vbox.add_child(row2)

	## -- Chassis column --
	var chassis_col: VBoxContainer = VBoxContainer.new()
	chassis_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chassis_col.add_theme_constant_override("separation", 6)
	row2.add_child(chassis_col)

	_add_section_header(chassis_col, "CHASSIS")

	_chassis_vbox = VBoxContainer.new()
	_chassis_vbox.add_theme_constant_override("separation", 6)
	chassis_col.add_child(_chassis_vbox)

	## -- Computer column --
	var computer_col: VBoxContainer = VBoxContainer.new()
	computer_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	computer_col.add_theme_constant_override("separation", 6)
	row2.add_child(computer_col)

	_add_section_header(computer_col, "COMPUTER")

	_computer_vbox = VBoxContainer.new()
	_computer_vbox.add_theme_constant_override("separation", 6)
	computer_col.add_child(_computer_vbox)

	## -- Accessory column --
	var accessory_col: VBoxContainer = VBoxContainer.new()
	accessory_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accessory_col.add_theme_constant_override("separation", 6)
	row2.add_child(accessory_col)

	_add_section_header(accessory_col, "ACCESSORY")

	_accessory_vbox = VBoxContainer.new()
	_accessory_vbox.add_theme_constant_override("separation", 6)
	accessory_col.add_child(_accessory_vbox)


## ============================================================
## Refresh helpers
## ============================================================


func _refresh_stats() -> void:
	_clear_children(_stats_vbox)
	if crawler_state == null:
		return

	var eff_hull: int = crawler_state.get_effective_hull_hp()
	var eff_energy: int = crawler_state.get_effective_energy()
	var eff_bench: int = crawler_state.get_effective_bench_slots()

	var stats: Array[Dictionary] = [
		{"label": "Hull HP", "value": str(eff_hull), "bonus": eff_hull != crawler_state.max_hull_hp},
		{"label": "Energy", "value": str(eff_energy), "bonus": eff_energy != crawler_state.max_energy},
		{"label": "Capacity (CP)", "value": str(crawler_state.capacity), "bonus": false},
		{"label": "Squad Slots", "value": str(crawler_state.slots), "bonus": false},
		{"label": "Bench Slots", "value": str(eff_bench), "bonus": eff_bench != crawler_state.bench_slots},
	]

	for s: Dictionary in stats:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_stats_vbox.add_child(row)

		var lbl: Label = Label.new()
		lbl.text = "%s:" % s["label"]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color("#999999"))
		lbl.custom_minimum_size.x = 110
		row.add_child(lbl)

		var val_label: Label = Label.new()
		val_label.text = s["value"]
		val_label.add_theme_font_size_override("font_size", 14)
		if s["bonus"]:
			val_label.add_theme_color_override("font_color", Color("#44FF44"))
		else:
			val_label.add_theme_color_override("font_color", Color("#FFFFFF"))
		row.add_child(val_label)


func _refresh_milestones() -> void:
	_clear_children(_milestone_vbox)
	if milestone_tracker == null:
		return

	var progress: Array[Dictionary] = milestone_tracker.get_milestone_progress()
	for entry: Dictionary in progress:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_milestone_vbox.add_child(row)

		var check: Label = Label.new()
		check.custom_minimum_size = Vector2(16, 0)
		check.add_theme_font_size_override("font_size", 13)
		if entry.get("completed", false):
			check.text = "\u2713"
			check.add_theme_color_override("font_color", Color("#44FF44"))
		else:
			check.text = "\u25cb"
			check.add_theme_color_override("font_color", Color("#666666"))
		row.add_child(check)

		var desc: Label = Label.new()
		var milestone_text: String = str(entry.get("milestone", ""))
		var reward_text: String = str(entry.get("description", ""))
		desc.text = "%s \u2192 %s" % [milestone_text, reward_text]
		desc.add_theme_font_size_override("font_size", 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry.get("completed", false):
			desc.add_theme_color_override("font_color", Color("#AAAAAA"))
		else:
			desc.add_theme_color_override("font_color", Color("#CCCCCC"))
		row.add_child(desc)


func _refresh_hints() -> void:
	_clear_children(_hints_vbox)

	## Show how many pieces the player owns
	if crawler_state != null:
		var owned: int = crawler_state.owned_equipment.size()
		var total: int = 8
		var count_label: Label = Label.new()
		count_label.text = "Collected: %d / %d" % [owned, total]
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.add_theme_color_override("font_color", Color("#FFD700") if owned > 0 else Color("#666666"))
		_hints_vbox.add_child(count_label)

		var spacer: Control = Control.new()
		spacer.custom_minimum_size.y = 4
		_hints_vbox.add_child(spacer)

	for hint: Dictionary in _EQUIPMENT_HINTS:
		var lbl: Label = Label.new()
		lbl.text = hint["text"]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(hint["color"]))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hints_vbox.add_child(lbl)


func _refresh_chassis() -> void:
	_clear_children(_chassis_vbox)
	_chassis_buttons.clear()
	if crawler_state == null:
		return

	var chassis_info: Dictionary = {
		"standard": {"desc": "No bonus (default)", "icon": "S"},
		"ironclad": {"desc": "+25 Hull HP", "icon": "I"},
		"scout": {"desc": "Scan costs 3 Energy (instead of 5)", "icon": "Sc"},
		"hauler": {"desc": "+1 Bench slot", "icon": "H"},
	}

	for chassis_id: String in ["standard", "ironclad", "scout", "hauler"]:
		var unlocked: bool = crawler_state.unlocked_chassis.has(chassis_id)
		var is_active: bool = crawler_state.active_chassis == chassis_id
		var info: Dictionary = chassis_info.get(chassis_id, {"desc": "", "icon": "?"})

		var card: PanelContainer = _make_selectable_card(is_active, unlocked)

		if unlocked and not is_active:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var cid: String = chassis_id
			card.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton:
					var mb: InputEventMouseButton = event as InputEventMouseButton
					if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
						_select_chassis(cid)
			)

		_chassis_vbox.add_child(card)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)

		## Icon square
		var chassis_tex: Texture2D = GameArt.get_chassis_icon(chassis_id)
		var art_frame: PanelContainer = _make_icon_square(info["icon"], is_active, unlocked, chassis_tex)
		row.add_child(art_frame)

		## Text
		var text_col: VBoxContainer = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.add_theme_constant_override("separation", 1)
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text_col)

		var name_row: HBoxContainer = HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(name_row)

		var name_label: Label = Label.new()
		name_label.text = chassis_id.capitalize()
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			name_label.add_theme_color_override("font_color", Color("#555555"))
		elif is_active:
			name_label.add_theme_color_override("font_color", Color("#FFFFFF"))
		else:
			name_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		name_row.add_child(name_label)

		if is_active:
			var badge: Label = Label.new()
			badge.text = "ACTIVE"
			badge.add_theme_font_size_override("font_size", 9)
			badge.add_theme_color_override("font_color", Color("#44FF44"))
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_row.add_child(badge)

		var desc: Label = Label.new()
		desc.add_theme_font_size_override("font_size", 11)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			var unlock_text: String = _CHASSIS_UNLOCK.get(chassis_id, "")
			desc.text = "\ud83d\udd12 %s" % unlock_text if unlock_text != "" else info["desc"]
			desc.add_theme_color_override("font_color", Color("#555555"))
		elif is_active:
			desc.text = info["desc"]
			desc.add_theme_color_override("font_color", Color("#88CC88"))
		else:
			desc.text = info["desc"]
			desc.add_theme_color_override("font_color", Color("#888888"))
		text_col.add_child(desc)

		## Hidden test button
		var btn: Button = Button.new()
		btn.name = "ChassisButton_%s" % chassis_id.capitalize()
		btn.visible = false
		if is_active:
			btn.disabled = true
		elif unlocked:
			var cid2: String = chassis_id
			btn.pressed.connect(func() -> void: _select_chassis(cid2))
		else:
			btn.disabled = true
		card.add_child(btn)
		_chassis_buttons[chassis_id] = btn


func _refresh_equipment_column(vbox: VBoxContainer, slot: String) -> void:
	_clear_children(vbox)
	if crawler_state == null:
		return

	var equipped_id: String = crawler_state.equipped_computer if slot == "computer" else crawler_state.equipped_accessory

	## Gather owned items for this slot
	var slot_items: Array[Dictionary] = []
	if data_loader != null:
		for eid: String in crawler_state.owned_equipment:
			var eq: EquipmentDef = data_loader.get_equipment(eid)
			if eq != null and eq.slot == slot:
				slot_items.append({"id": eid, "def": eq, "equipped": eid == equipped_id})

	if slot_items.is_empty():
		## Empty state
		var empty_card: PanelContainer = _make_selectable_card(false, false)
		vbox.add_child(empty_card)
		var empty_label: Label = Label.new()
		empty_label.text = "None found yet"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color("#555555"))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_card.add_child(empty_label)

		## Hidden test button (disabled)
		var test_btn: Button = Button.new()
		test_btn.name = "EquipButton_%s" % slot.capitalize()
		test_btn.visible = false
		test_btn.disabled = true
		empty_card.add_child(test_btn)
		_equipment_buttons[slot] = test_btn
		return

	## "None" option to unequip
	if equipped_id != "":
		var none_card: PanelContainer = _make_selectable_card(false, true)
		none_card.mouse_filter = Control.MOUSE_FILTER_STOP
		none_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var s: String = slot
		none_card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					_unequip_slot(s)
		)
		vbox.add_child(none_card)
		var none_label: Label = Label.new()
		none_label.text = "Remove equipment"
		none_label.add_theme_font_size_override("font_size", 12)
		none_label.add_theme_color_override("font_color", Color("#888888"))
		none_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		none_card.add_child(none_label)

	## One card per owned item
	var first_btn: Button = null
	for item: Dictionary in slot_items:
		var eq: EquipmentDef = item["def"]
		var eid: String = item["id"]
		var is_equipped: bool = item["equipped"]

		var card: PanelContainer = _make_selectable_card(is_equipped, true)

		if not is_equipped:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var eq_id: String = eid
			var s2: String = slot
			card.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton:
					var mb: InputEventMouseButton = event as InputEventMouseButton
					if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
						_select_equipment_direct(s2, eq_id)
			)

		vbox.add_child(card)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)

		## Equipment icon square
		var equip_tex: Texture2D = GameArt.get_equipment_icon(eid)
		var equip_frame: PanelContainer = _make_icon_square("", is_equipped, true, equip_tex)
		row.add_child(equip_frame)

		## Text
		var text_col: VBoxContainer = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.add_theme_constant_override("separation", 1)
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text_col)

		var name_row: HBoxContainer = HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(name_row)

		var name_lbl: Label = Label.new()
		name_lbl.text = eq.name
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_equipped:
			name_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
		else:
			name_lbl.add_theme_color_override("font_color", Color("#CCCCCC"))
		name_row.add_child(name_lbl)

		if is_equipped:
			var badge: Label = Label.new()
			badge.text = "EQUIPPED"
			badge.add_theme_font_size_override("font_size", 9)
			badge.add_theme_color_override("font_color", Color("#44FF44"))
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_row.add_child(badge)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = eq.description
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_equipped:
			desc_lbl.add_theme_color_override("font_color", Color("#88CC88"))
		else:
			desc_lbl.add_theme_color_override("font_color", Color("#888888"))
		text_col.add_child(desc_lbl)

		## Rarity tag
		var rarity_lbl: Label = Label.new()
		rarity_lbl.text = eq.rarity.capitalize()
		rarity_lbl.add_theme_font_size_override("font_size", 10)
		rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match eq.rarity:
			"common":
				rarity_lbl.add_theme_color_override("font_color", Color("#666666"))
			"uncommon":
				rarity_lbl.add_theme_color_override("font_color", Color("#4488CC"))
			"rare":
				rarity_lbl.add_theme_color_override("font_color", Color("#CC88FF"))
		text_col.add_child(rarity_lbl)

		## Hidden test button
		var test_btn: Button = Button.new()
		test_btn.name = "EquipButton_%s_%s" % [slot.capitalize(), eid]
		test_btn.visible = false
		test_btn.disabled = is_equipped
		if not is_equipped:
			var eq_id2: String = eid
			var s3: String = slot
			test_btn.pressed.connect(func() -> void: _select_equipment_direct(s3, eq_id2))
		card.add_child(test_btn)
		if first_btn == null:
			first_btn = test_btn

	## Store first button for test access
	if first_btn != null:
		_equipment_buttons[slot] = first_btn
	else:
		## Fallback: empty hidden button
		var fb: Button = Button.new()
		fb.name = "EquipButton_%s" % slot.capitalize()
		fb.visible = false
		fb.disabled = true
		vbox.add_child(fb)
		_equipment_buttons[slot] = fb


## ============================================================
## Actions
## ============================================================


func _select_chassis(chassis_id: String) -> void:
	if crawler_state == null:
		return
	if not crawler_state.unlocked_chassis.has(chassis_id):
		return
	crawler_state.active_chassis = chassis_id
	refresh()


func _select_equipment_direct(slot: String, equipment_id: String) -> void:
	if crawler_state == null:
		return
	crawler_state.equip(slot, equipment_id)
	refresh()


func _unequip_slot(slot: String) -> void:
	if crawler_state == null:
		return
	crawler_state.unequip(slot)
	refresh()


## ============================================================
## Shared card builders
## ============================================================


func _make_selectable_card(is_active: bool, is_available: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 48)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	if is_active:
		style.bg_color = Color("#1A3A1A")
		style.border_color = Color("#44FF44")
		_set_border_width(style, 2)
	elif is_available:
		style.bg_color = Color("#1A1A2A")
		style.border_color = Color("#444466")
		_set_border_width(style, 1)
	else:
		style.bg_color = Color("#111111")
		style.border_color = Color("#333333")
		_set_border_width(style, 1)

	card.add_theme_stylebox_override("panel", style)
	return card


func _make_icon_square(icon_text: String, is_active: bool, is_available: bool, tex: Texture2D = null) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = Vector2(36, 36)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	if is_active:
		style.bg_color = Color("#2A5A2A")
	elif is_available:
		style.bg_color = Color("#2A2A3A")
	else:
		style.bg_color = Color("#1A1A1A")
	frame.add_theme_stylebox_override("panel", style)

	if tex != null:
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.texture = tex
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not is_available:
			tex_rect.modulate = Color(0.3, 0.3, 0.3, 1.0)
		frame.add_child(tex_rect)
	else:
		var lbl: Label = Label.new()
		lbl.text = icon_text
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not is_available:
			lbl.add_theme_color_override("font_color", Color("#444444"))
		else:
			lbl.add_theme_color_override("font_color", Color("#CCCCCC"))
		frame.add_child(lbl)

	return frame


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var header: Label = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color("#FFD700"))
	parent.add_child(header)


func _set_border_width(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_right = width
	style.border_width_top = width
	style.border_width_bottom = width


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
