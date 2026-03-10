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
	main_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(main_vbox)

	## --- Stats Section ---
	var stats_header: Label = Label.new()
	stats_header.text = "CRAWLER STATS"
	stats_header.add_theme_font_size_override("font_size", 18)
	stats_header.add_theme_color_override("font_color", Color("#FFD700"))
	main_vbox.add_child(stats_header)

	_stats_vbox = VBoxContainer.new()
	_stats_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_stats_vbox)

	## --- Chassis Section ---
	var chassis_header: Label = Label.new()
	chassis_header.text = "CHASSIS"
	chassis_header.add_theme_font_size_override("font_size", 18)
	chassis_header.add_theme_color_override("font_color", Color("#FFD700"))
	main_vbox.add_child(chassis_header)

	_chassis_vbox = VBoxContainer.new()
	_chassis_vbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_chassis_vbox)

	## --- Milestones Section ---
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

	var stats: Array[String] = [
		"Hull HP: %d" % crawler_state.max_hull_hp,
		"Energy: %d" % crawler_state.max_energy,
		"Capacity (CP): %d" % crawler_state.capacity,
		"Squad Slots: %d" % crawler_state.slots,
		"Bench Slots: %d" % crawler_state.bench_slots,
		"Active Chassis: %s" % crawler_state.active_chassis.capitalize(),
	]
	for s: String in stats:
		var label: Label = Label.new()
		label.text = s
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#CCCCCC"))
		_stats_vbox.add_child(label)


func _refresh_chassis() -> void:
	_clear_children(_chassis_vbox)
	_chassis_buttons.clear()
	if crawler_state == null:
		return

	var chassis_info: Dictionary = {
		"standard": "No bonus (default)",
		"ironclad": "+25 Hull HP, -5 Energy",
		"scout": "Scan costs 3 Energy (instead of 5)",
		"hauler": "+1 Bench slot, -10 Hull HP",
	}

	for chassis_id: String in ["standard", "ironclad", "scout", "hauler"]:
		var unlocked: bool = crawler_state.unlocked_chassis.has(chassis_id)
		var is_active: bool = crawler_state.active_chassis == chassis_id

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_chassis_vbox.add_child(row)

		var btn: Button = Button.new()
		btn.name = "ChassisButton_%s" % chassis_id.capitalize()
		btn.custom_minimum_size = Vector2(160, 32)
		if is_active:
			btn.text = "%s (Active)" % chassis_id.capitalize()
			btn.disabled = true
		elif unlocked:
			btn.text = chassis_id.capitalize()
			var cid: String = chassis_id
			btn.pressed.connect(func() -> void: _select_chassis(cid))
		else:
			btn.text = "%s (Locked)" % chassis_id.capitalize()
			btn.disabled = true
		row.add_child(btn)
		_chassis_buttons[chassis_id] = btn

		var desc: Label = Label.new()
		desc.text = chassis_info.get(chassis_id, "")
		desc.add_theme_font_size_override("font_size", 12)
		if not unlocked:
			desc.add_theme_color_override("font_color", Color("#666666"))
		elif is_active:
			desc.add_theme_color_override("font_color", Color("#44FF44"))
		else:
			desc.add_theme_color_override("font_color", Color("#AAAAAA"))
		desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(desc)


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
