class_name ItemPopup
extends PanelContainer

## Shows crawler inventory with item names, descriptions, and Use buttons.
## Items like repair_hull and restore_energy apply immediately.
## heal_glyph is used between battles to restore a glyph.

signal item_used(item: ItemDef)
signal closed()


## DEBUG: Track what hides the popup (investigating BUG-015)
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		print("[ItemPopup] hidden — stack trace:")
		print_stack()

const ITEM_COLORS: Dictionary = {
	"repair_hull": Color("#4CAF50"),
	"restore_energy": Color("#2196F3"),
	"heal_glyph": Color("#E91E63"),
	"status_immunity": Color("#9C27B0"),
	"capture_bonus": Color("#FF9800"),
	"reveal_floor": Color("#FFEB3B"),
	"revive_glyph": Color("#FF5722"),
	"damage_boost": Color("#F44336"),
	"hazard_immunity": Color("#607D8B"),
}
const ITEM_ICON_SIZE: int = 40

var crawler: CrawlerState = null
var roster_state: RosterState = null

var _title_label: Label = null
var _item_list: VBoxContainer = null
var _empty_label: Label = null
var _close_button: Button = null
var _item_rows: Array[HBoxContainer] = []


func _ready() -> void:
	custom_minimum_size = Vector2(360, 0)
	clip_contents = true
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
	scroll.custom_minimum_size = Vector2(0, 60)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_close_button.name = "ItemCloseButton"
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
		row.custom_minimum_size = Vector2(0, 56)
		_item_list.add_child(row)
		_item_rows.append(row)

		row.add_child(ItemPopup.create_item_icon(item))

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
		desc_label.max_lines_visible = 2
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	var applied: bool = ItemPopup.apply_item(item, crawler, roster_state)
	if applied:
		crawler.use_item(item)
		item_used.emit(item)
		_rebuild_list()


static func create_item_icon(item: ItemDef, icon_size: int = ITEM_ICON_SIZE) -> Control:
	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(icon_size, icon_size)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg: ColorRect = ColorRect.new()
	bg.custom_minimum_size = Vector2(icon_size, icon_size)
	bg.size = Vector2(icon_size, icon_size)
	bg.color = ITEM_COLORS.get(item.effect_type, Color("#666666"))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	var border: ReferenceRect = ReferenceRect.new()
	border.custom_minimum_size = Vector2(icon_size, icon_size)
	border.size = Vector2(icon_size, icon_size)
	border.border_color = ITEM_COLORS.get(item.effect_type, Color("#666666")).lightened(0.3)
	border.border_width = 2.0
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border)

	var letter: Label = Label.new()
	letter.text = item.name.substr(0, 1)
	letter.add_theme_font_size_override("font_size", int(icon_size * 0.5))
	letter.add_theme_color_override("font_color", Color.WHITE)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.size = Vector2(icon_size, icon_size)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(letter)

	## Outline effect via shadow
	letter.add_theme_color_override("font_shadow_color", Color.BLACK)
	letter.add_theme_constant_override("shadow_offset_x", 1)
	letter.add_theme_constant_override("shadow_offset_y", 1)

	return container


static func apply_item(item: ItemDef, p_crawler: CrawlerState, p_roster: RosterState) -> bool:
	match item.effect_type:
		"repair_hull":
			p_crawler.hull_hp = mini(p_crawler.hull_hp + int(item.effect_value), p_crawler.max_hull_hp)
			p_crawler.hull_changed.emit(p_crawler.hull_hp, p_crawler.max_hull_hp)
			return true
		"restore_energy":
			p_crawler.energy = mini(p_crawler.energy + int(item.effect_value), p_crawler.max_energy)
			p_crawler.energy_changed.emit(p_crawler.energy, p_crawler.max_energy)
			return true
		"heal_glyph":
			## Heal the most damaged glyph
			if p_roster == null:
				return false
			var most_damaged: GlyphInstance = null
			var most_missing: int = 0
			for g: GlyphInstance in p_roster.active_squad:
				var missing: int = g.max_hp - g.current_hp
				if missing > most_missing:
					most_missing = missing
					most_damaged = g
			if most_damaged == null:
				return false
			most_damaged.current_hp = most_damaged.max_hp
			most_damaged.is_knocked_out = false
			return true
		"revive_glyph":
			## Revive a KO'd glyph with effect_value% HP
			if p_roster == null:
				return false
			for g: GlyphInstance in p_roster.active_squad:
				if g.is_knocked_out:
					g.current_hp = maxi(1, int(float(g.max_hp) * item.effect_value / 100.0))
					g.is_knocked_out = false
					return true
			return false  ## No KO'd glyphs
		"status_immunity", "capture_bonus", "reveal_floor", "damage_boost", "hazard_immunity":
			## These are passive effects — just consume for now
			return true
		_:
			return false
