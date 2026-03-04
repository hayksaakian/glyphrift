class_name CrawlerHUD
extends PanelContainer

## Top-of-screen HUD showing Crawler resources and ability buttons.
## Listens to CrawlerState.hull_changed and energy_changed signals.

signal ability_pressed(ability_name: String)
signal items_pressed()

const HULL_COLOR_HIGH: Color = Color("#4CAF50")
const HULL_COLOR_MED: Color = Color("#FFC107")
const HULL_COLOR_LOW: Color = Color("#F44336")
const ENERGY_COLOR: Color = Color("#2196F3")
const ENERGY_COLOR_LOW: Color = Color("#1565C0")

const ABILITIES: Array[String] = ["scan", "reinforce", "field_repair", "purge", "emergency_warp"]
const ABILITY_LABELS: Dictionary = {
	"scan": "Scan",
	"reinforce": "Reinforce",
	"field_repair": "Heal Glyph",
	"purge": "Purge",
	"emergency_warp": "Warp",
}

const ABILITY_TOOLTIPS: Dictionary = {
	"scan": "Reveal all rooms adjacent to your position",
	"reinforce": "Shield the crawler from hazard damage for the next room (one use, cheap)",
	"field_repair": "Restore HP to one of your Glyphs",
	"purge": "Permanently destroy an adjacent hazard room, turning it safe (costly but clears the path)",
	"emergency_warp": "Emergency retreat — abandon the rift but keep your Glyphs and items intact. Use when hull is critical to avoid total loss.",
}

var crawler: CrawlerState = null

var _hull_bar: ProgressBar = null
var _hull_label: Label = null
var _energy_bar: ProgressBar = null
var _energy_label: Label = null
var _items_button: Button = null
var _ability_buttons: Dictionary = {}  ## ability_name → Button
var _hull_fill_style: StyleBoxFlat = null
var _energy_fill_style: StyleBoxFlat = null


func _ready() -> void:
	_build_ui()


func setup(p_crawler: CrawlerState) -> void:
	## Disconnect old signals if re-setup with same or different crawler
	if crawler != null:
		if crawler.hull_changed.is_connected(_on_hull_changed):
			crawler.hull_changed.disconnect(_on_hull_changed)
		if crawler.energy_changed.is_connected(_on_energy_changed):
			crawler.energy_changed.disconnect(_on_energy_changed)
		if crawler.item_added.is_connected(_on_item_changed):
			crawler.item_added.disconnect(_on_item_changed)
		if crawler.item_used.is_connected(_on_item_changed):
			crawler.item_used.disconnect(_on_item_changed)
	crawler = p_crawler
	if crawler != null:
		crawler.hull_changed.connect(_on_hull_changed)
		crawler.energy_changed.connect(_on_energy_changed)
		crawler.item_added.connect(_on_item_changed)
		crawler.item_used.connect(_on_item_changed)
	if is_inside_tree():
		refresh()


func refresh() -> void:
	if crawler == null:
		return
	_update_hull(crawler.hull_hp, crawler.max_hull_hp)
	_update_energy(crawler.energy, crawler.max_energy)
	_update_items()
	_update_abilities()


func get_ability_button(ability_name: String) -> Button:
	return _ability_buttons.get(ability_name, null)


func _build_ui() -> void:
	## Dark semi-transparent background
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bg_style.content_margin_left = 8.0
	bg_style.content_margin_right = 8.0
	bg_style.content_margin_top = 4.0
	bg_style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", bg_style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)

	## Hull section
	var hull_section: HBoxContainer = _make_bar_section("Hull:", HULL_COLOR_HIGH)
	_hull_bar = hull_section.get_meta("bar")
	_hull_label = hull_section.get_meta("label")
	_hull_fill_style = hull_section.get_meta("fill_style")
	hbox.add_child(hull_section)

	## Energy section
	var energy_section: HBoxContainer = _make_bar_section("Energy:", ENERGY_COLOR)
	_energy_bar = energy_section.get_meta("bar")
	_energy_label = energy_section.get_meta("label")
	_energy_fill_style = energy_section.get_meta("fill_style")
	hbox.add_child(energy_section)

	## Items button
	_items_button = Button.new()
	_items_button.text = "Items: 0/5"
	_items_button.custom_minimum_size.x = 80.0
	_items_button.pressed.connect(func() -> void: items_pressed.emit())
	hbox.add_child(_items_button)

	## Separator
	var sep: VSeparator = VSeparator.new()
	hbox.add_child(sep)

	## Ability buttons
	for ability_name: String in ABILITIES:
		var btn: Button = Button.new()
		btn.name = ability_name
		btn.custom_minimum_size.x = 70.0
		btn.tooltip_text = ABILITY_TOOLTIPS.get(ability_name, "")
		btn.pressed.connect(_on_ability_pressed.bind(ability_name))
		_ability_buttons[ability_name] = btn
		hbox.add_child(btn)


func _make_bar_section(title: String, bar_color: Color) -> HBoxContainer:
	var section: HBoxContainer = HBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	section.add_child(title_label)

	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 14)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_bar_style.bg_color = Color(0.15, 0.15, 0.15)
	bar.add_theme_stylebox_override("background", bg_bar_style)

	section.add_child(bar)

	var value_label: Label = Label.new()
	value_label.text = "100/100"
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.custom_minimum_size.x = 60.0
	section.add_child(value_label)

	section.set_meta("bar", bar)
	section.set_meta("label", value_label)
	section.set_meta("fill_style", fill_style)
	return section


func _update_hull(current: int, max_hp: int) -> void:
	if _hull_bar == null:
		return
	_hull_bar.max_value = float(max_hp)
	_hull_bar.value = float(current)
	_hull_label.text = "%d/%d" % [current, max_hp]

	## Color based on percentage
	var pct: float = float(current) / float(max_hp) if max_hp > 0 else 0.0
	if pct > 0.25:
		_hull_fill_style.bg_color = HULL_COLOR_HIGH
	elif pct > 0.10:
		_hull_fill_style.bg_color = HULL_COLOR_MED
	else:
		_hull_fill_style.bg_color = HULL_COLOR_LOW


func _update_energy(current: int, max_e: int) -> void:
	if _energy_bar == null:
		return
	_energy_bar.max_value = float(max_e)
	_energy_bar.value = float(current)
	_energy_label.text = "%d/%d" % [current, max_e]

	var pct: float = float(current) / float(max_e) if max_e > 0 else 0.0
	if pct > 0.2:
		_energy_fill_style.bg_color = ENERGY_COLOR
	else:
		_energy_fill_style.bg_color = ENERGY_COLOR_LOW


func _update_items() -> void:
	if _items_button == null or crawler == null:
		return
	_items_button.text = "Items: %d/%d" % [crawler.items.size(), CrawlerState.MAX_ITEMS]


func _update_abilities() -> void:
	if crawler == null:
		return
	for ability_name: String in ABILITIES:
		if not _ability_buttons.has(ability_name):
			continue
		var btn: Button = _ability_buttons[ability_name]
		var cost: int = crawler.get_ability_cost(ability_name)
		var label: String = ABILITY_LABELS.get(ability_name, ability_name)
		btn.text = "%s (%d)" % [label, cost]
		var can_afford: bool = crawler.energy >= cost
		btn.disabled = not can_afford
		if can_afford:
			btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(0.5, 0.5, 0.5, 0.8)


func _on_hull_changed(current: int, max_hp: int) -> void:
	_update_hull(current, max_hp)


func _on_energy_changed(current: int, max_e: int) -> void:
	_update_energy(current, max_e)
	_update_abilities()


func _on_item_changed(_item: ItemDef) -> void:
	_update_items()


func _on_ability_pressed(ability_name: String) -> void:
	ability_pressed.emit(ability_name)
