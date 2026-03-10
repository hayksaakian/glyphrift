class_name CrawlerBay
extends Control

## Crawler Bay — view stats, swap chassis, view milestone progress.

signal back_pressed

var crawler_state: CrawlerState = null
var milestone_tracker: MilestoneTracker = null

var _stats_vbox: VBoxContainer = null
var _chassis_vbox: VBoxContainer = null
var _milestone_vbox: VBoxContainer = null
var _chassis_buttons: Dictionary = {}  ## chassis_id → Button

## Milestone text that unlocks each chassis (for locked display)
const _CHASSIS_UNLOCK: Dictionary = {
	"ironclad": "Discover 1 hidden cache in a rift",
	"scout": "Discover 3 hidden caches total",
	"hauler": "Discover 5 hidden caches total",
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func setup(p_crawler: CrawlerState, p_milestones: MilestoneTracker) -> void:
	crawler_state = p_crawler
	milestone_tracker = p_milestones


func refresh() -> void:
	_refresh_stats()
	_refresh_chassis()
	_refresh_milestones()


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
	main_vbox.add_theme_constant_override("separation", 24)
	scroll.add_child(main_vbox)

	## --- Top row: Stats (left) + Chassis (right) side by side ---
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 40)
	main_vbox.add_child(top_row)

	## Left column: Chassis
	var chassis_col: VBoxContainer = VBoxContainer.new()
	chassis_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chassis_col.custom_minimum_size.x = 340
	chassis_col.add_theme_constant_override("separation", 6)
	top_row.add_child(chassis_col)

	var chassis_header: Label = Label.new()
	chassis_header.text = "CHASSIS"
	chassis_header.add_theme_font_size_override("font_size", 18)
	chassis_header.add_theme_color_override("font_color", Color("#FFD700"))
	chassis_col.add_child(chassis_header)

	_chassis_vbox = VBoxContainer.new()
	_chassis_vbox.add_theme_constant_override("separation", 6)
	chassis_col.add_child(_chassis_vbox)

	## Right column: Stats
	var stats_col: VBoxContainer = VBoxContainer.new()
	stats_col.custom_minimum_size.x = 200
	stats_col.add_theme_constant_override("separation", 6)
	top_row.add_child(stats_col)

	var stats_header: Label = Label.new()
	stats_header.text = "CRAWLER STATS"
	stats_header.add_theme_font_size_override("font_size", 18)
	stats_header.add_theme_color_override("font_color", Color("#FFD700"))
	stats_col.add_child(stats_header)

	_stats_vbox = VBoxContainer.new()
	_stats_vbox.add_theme_constant_override("separation", 4)
	stats_col.add_child(_stats_vbox)

	## --- Bottom: Milestones ---
	var ms_header: Label = Label.new()
	ms_header.text = "UPGRADE MILESTONES"
	ms_header.add_theme_font_size_override("font_size", 18)
	ms_header.add_theme_color_override("font_color", Color("#FFD700"))
	main_vbox.add_child(ms_header)

	_milestone_vbox = VBoxContainer.new()
	_milestone_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_milestone_vbox)


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

		## Card-style panel — entire card is clickable for unlocked chassis
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 56)
		var card_style: StyleBoxFlat = StyleBoxFlat.new()
		card_style.content_margin_left = 10
		card_style.content_margin_right = 10
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		card_style.corner_radius_top_left = 4
		card_style.corner_radius_top_right = 4
		card_style.corner_radius_bottom_left = 4
		card_style.corner_radius_bottom_right = 4

		if is_active:
			card_style.bg_color = Color("#1A3A1A")
			card_style.border_color = Color("#44FF44")
			card_style.border_width_left = 3
			card_style.border_width_right = 3
			card_style.border_width_top = 3
			card_style.border_width_bottom = 3
		elif unlocked:
			card_style.bg_color = Color("#1A1A2A")
			card_style.border_color = Color("#444466")
			card_style.border_width_left = 1
			card_style.border_width_right = 1
			card_style.border_width_top = 1
			card_style.border_width_bottom = 1
		else:
			card_style.bg_color = Color("#111111")
			card_style.border_color = Color("#333333")
			card_style.border_width_left = 1
			card_style.border_width_right = 1
			card_style.border_width_top = 1
			card_style.border_width_bottom = 1

		card.add_theme_stylebox_override("panel", card_style)

		## Make entire card clickable for unlocked, non-active chassis
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
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)

		## Art placeholder — colored square with chassis initial
		var art_frame: PanelContainer = PanelContainer.new()
		art_frame.custom_minimum_size = Vector2(40, 40)
		art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art_style: StyleBoxFlat = StyleBoxFlat.new()
		art_style.corner_radius_top_left = 4
		art_style.corner_radius_top_right = 4
		art_style.corner_radius_bottom_left = 4
		art_style.corner_radius_bottom_right = 4
		if is_active:
			art_style.bg_color = Color("#2A5A2A")
		elif unlocked:
			art_style.bg_color = Color("#2A2A3A")
		else:
			art_style.bg_color = Color("#1A1A1A")
		art_frame.add_theme_stylebox_override("panel", art_style)
		row.add_child(art_frame)

		var art_label: Label = Label.new()
		art_label.text = info["icon"]
		art_label.add_theme_font_size_override("font_size", 16)
		art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		art_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			art_label.add_theme_color_override("font_color", Color("#444444"))
		else:
			art_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		art_frame.add_child(art_label)

		## Text column
		var text_col: VBoxContainer = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.add_theme_constant_override("separation", 2)
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text_col)

		var name_row: HBoxContainer = HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(name_row)

		var name_label: Label = Label.new()
		name_label.text = chassis_id.capitalize()
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			name_label.add_theme_color_override("font_color", Color("#555555"))
		elif is_active:
			name_label.add_theme_color_override("font_color", Color("#FFFFFF"))
		else:
			name_label.add_theme_color_override("font_color", Color("#CCCCCC"))
		name_row.add_child(name_label)

		if is_active:
			var active_badge: Label = Label.new()
			active_badge.text = "ACTIVE"
			active_badge.add_theme_font_size_override("font_size", 10)
			active_badge.add_theme_color_override("font_color", Color("#44FF44"))
			active_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			active_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_row.add_child(active_badge)

		var desc: Label = Label.new()
		desc.add_theme_font_size_override("font_size", 12)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			## Show unlock requirement instead of bonus description
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

		## Hidden button for test compatibility (not visible, used by _chassis_buttons dict)
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


func _refresh_milestones() -> void:
	_clear_children(_milestone_vbox)
	if milestone_tracker == null:
		return

	var progress: Array[Dictionary] = milestone_tracker.get_milestone_progress()
	for entry: Dictionary in progress:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_milestone_vbox.add_child(row)

		var check: Label = Label.new()
		check.custom_minimum_size = Vector2(20, 0)
		check.add_theme_font_size_override("font_size", 14)
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
		desc.text = "%s  \u2192  %s" % [milestone_text, reward_text]
		desc.add_theme_font_size_override("font_size", 13)
		if entry.get("completed", false):
			desc.add_theme_color_override("font_color", Color("#AAAAAA"))
		else:
			desc.add_theme_color_override("font_color", Color("#CCCCCC"))
		row.add_child(desc)


func _select_chassis(chassis_id: String) -> void:
	if crawler_state == null:
		return
	if not crawler_state.unlocked_chassis.has(chassis_id):
		return
	crawler_state.active_chassis = chassis_id
	refresh()


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
