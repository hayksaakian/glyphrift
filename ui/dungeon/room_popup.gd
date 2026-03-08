class_name RoomPopup
extends Control

## Modal popup shown when entering a room.
## Content varies by room type; action button triggers interaction.

signal action_pressed(room_type: String, room_data: Dictionary)
signal formation_requested(room_type: String, room_data: Dictionary)
signal back_out_pressed()

const POPUP_SIZE: Vector2 = Vector2(320, 280)

const ROOM_TITLES: Dictionary = {
	"enemy": "Wild Glyphs Ahead!",
	"cache": "Supply Cache Found!",
	"hazard": "Hazard Zone!",
	"puzzle": "Puzzle Room",
	"boss": "RIFT GUARDIAN",
	"empty": "Nothing here.",
	"exit": "Stairs Down",
	"hidden": "Hidden Cache Found!",
	"start": "Starting Point",
}

const ACTION_LABELS: Dictionary = {
	"enemy": "Fight",
	"cache": "Open",
	"hazard": "Continue",
	"puzzle": "Attempt",
	"boss": "Challenge Boss",
	"empty": "Continue",
	"exit": "Descend",
	"hidden": "Open",
	"start": "Continue",
}

var room_data: Dictionary = {}
var data_loader: DataLoader = null
var roster_state: RosterState = null  ## Injectable — for formation preview

var _title_label: Label = null
var _description_label: Label = null
var _action_button: Button = null
var _formation_button: Button = null
var _formation_preview: HBoxContainer = null
var _button_row: HBoxContainer = null
var _back_out_button: Button = null
var _vbox: VBoxContainer = null
var _enemy_preview: HBoxContainer = null


func _ready() -> void:
	custom_minimum_size = POPUP_SIZE
	visible = false
	_build_ui()


func show_room(p_room_data: Dictionary, extra_info: String = "") -> void:
	room_data = p_room_data
	var room_type: String = room_data.get("type", "empty")

	var title: String = ROOM_TITLES.get(room_type, "Unknown Room")
	if room_type == "boss" and extra_info != "":
		title = "RIFT GUARDIAN: %s" % extra_info

	_title_label.text = title

	## Show enemy preview if scan data has species IDs
	var scan_species_ids: Array = room_data.get("scan_species_ids", [])
	_clear_enemy_preview()
	if not scan_species_ids.is_empty() and (room_type == "enemy" or room_type == "boss"):
		_show_enemy_preview(scan_species_ids, room_type == "boss")
		_description_label.text = ""
		_description_label.visible = false
	else:
		_description_label.visible = true
		_description_label.text = _get_description(room_type, extra_info)

	_action_button.text = ACTION_LABELS.get(room_type, "Continue")

	## Show formation preview + adjust button for combat rooms
	var is_combat: bool = room_type in ["enemy", "boss"]
	_formation_button.visible = is_combat
	_back_out_button.visible = room_type == "boss"
	_refresh_formation_preview(is_combat)

	visible = true
	_animate_show()


func show_result(title: String, description: String) -> void:
	_title_label.text = title
	_description_label.text = description
	_description_label.visible = true
	_clear_enemy_preview()
	_action_button.text = "Continue"
	_formation_button.visible = false
	_back_out_button.visible = false
	_formation_preview.visible = false
	visible = true
	_animate_show()


func hide_popup() -> void:
	visible = false


func _animate_show() -> void:
	pivot_offset = size / 2.0
	scale = Vector2(0.85, 0.85)
	modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func get_title_text() -> String:
	if _title_label != null:
		return _title_label.text
	return ""


func get_description_text() -> String:
	if _description_label != null:
		return _description_label.text
	return ""


func get_action_text() -> String:
	if _action_button != null:
		return _action_button.text
	return ""


func _build_ui() -> void:
	clip_contents = true

	## Background panel (fills this Control)
	var bg: PanelContainer = PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", panel_style)
	add_child(bg)

	## ScrollContainer to prevent overflow
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16.0
	scroll.offset_right = -16.0
	scroll.offset_top = 12.0
	scroll.offset_bottom = -12.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vbox)

	## Title
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)

	## Description (hidden when enemy preview is shown)
	_description_label = Label.new()
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_description_label)

	## Enemy preview row (populated dynamically)
	_enemy_preview = HBoxContainer.new()
	_enemy_preview.add_theme_constant_override("separation", 12)
	_enemy_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_preview.visible = false
	_vbox.add_child(_enemy_preview)

	## Formation preview (small icons showing front/back row, hidden by default)
	_formation_preview = HBoxContainer.new()
	_formation_preview.add_theme_constant_override("separation", 4)
	_formation_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	_formation_preview.visible = false
	_vbox.add_child(_formation_preview)

	## Button row (Fight + Adjust Formation side by side for combat rooms)
	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 12)
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(_button_row)

	## Action button
	_action_button = Button.new()
	_action_button.name = "ActionButton"
	_action_button.custom_minimum_size = Vector2(120, 36)
	_action_button.pressed.connect(_on_action_pressed)
	_button_row.add_child(_action_button)

	## Adjust Formation button (hidden for non-combat rooms)
	_formation_button = Button.new()
	_formation_button.name = "FormationButton"
	_formation_button.text = "Formation"
	_formation_button.custom_minimum_size = Vector2(100, 36)
	_formation_button.pressed.connect(_on_formation_pressed)
	_formation_button.visible = false
	_button_row.add_child(_formation_button)

	## Back Out button (boss rooms only)
	_back_out_button = Button.new()
	_back_out_button.name = "BackOutButton"
	_back_out_button.text = "Back Out"
	_back_out_button.custom_minimum_size = Vector2(100, 36)
	_back_out_button.pressed.connect(_on_back_out_pressed)
	_back_out_button.visible = false
	_button_row.add_child(_back_out_button)


func _show_enemy_preview(species_ids: Array, is_boss: bool) -> void:
	for sid: Variant in species_ids:
		var species_id: String = str(sid)
		var species: GlyphSpecies = data_loader.get_species(species_id) if data_loader != null else null
		if species == null:
			continue

		var card: VBoxContainer = VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		_enemy_preview.add_child(card)

		## Art container (48x48)
		var art_size: int = 64 if is_boss else 48
		var art_container: PanelContainer = PanelContainer.new()
		art_container.custom_minimum_size = Vector2(art_size, art_size)
		art_container.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(art_container)

		var aff: String = species.affinity
		var aff_color: Color = Affinity.COLORS.get(aff, Affinity.COLORS["neutral"])

		var rect: ColorRect = ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.color = aff_color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_container.add_child(rect)

		var letter: Label = Label.new()
		letter.text = species.name[0].to_upper()
		letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", int(art_size * 0.5))
		letter.add_theme_color_override("font_color", Color.WHITE)
		letter.add_theme_color_override("font_outline_color", Color.BLACK)
		letter.add_theme_constant_override("outline_size", 2)
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_container.add_child(letter)

		GlyphArt.apply_texture(art_container, rect, letter, species_id, art_size)

		## Name
		var name_label: Label = Label.new()
		name_label.text = species.name
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_label)

		## Affinity + Tier
		var info_label: Label = Label.new()
		info_label.text = "%s %s T%d" % [Affinity.EMOJI.get(aff, ""), aff.capitalize(), species.tier]
		info_label.add_theme_font_size_override("font_size", 9)
		info_label.add_theme_color_override("font_color", aff_color)
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(info_label)

		## HP + ATK
		var stats_label: Label = Label.new()
		stats_label.text = "HP:%d ATK:%d" % [species.base_hp, species.base_atk]
		stats_label.add_theme_font_size_override("font_size", 9)
		stats_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(stats_label)

	_enemy_preview.visible = _enemy_preview.get_child_count() > 0


func _clear_enemy_preview() -> void:
	if _enemy_preview == null:
		return
	for child: Node in _enemy_preview.get_children():
		_enemy_preview.remove_child(child)
		child.queue_free()
	_enemy_preview.visible = false


func _get_description(room_type: String, extra_info: String) -> String:
	var scan_info: String = room_data.get("scan_info", "")
	match room_type:
		"enemy":
			if scan_info != "":
				return "Scouted: %s" % scan_info
			return "Wild glyphs block your path!"
		"cache":
			return "A supply cache sits before you."
		"hazard":
			if extra_info != "":
				return "Crawler takes %s damage." % extra_info
			return "The crawler takes damage from environmental hazards."
		"puzzle":
			return "A mysterious mechanism awaits."
		"boss":
			var warning: String = "\n[Defeat means emergency extraction!]"
			if scan_info != "":
				return "Scouted: %s guards this floor.%s" % [scan_info, warning]
			return "A powerful guardian defends this floor.%s" % warning
		"empty":
			return "An empty chamber. Nothing of interest."
		"exit":
			return "Descend to the next floor?"
		"hidden":
			return "A hidden cache with rare supplies!"
		"start":
			return "Your starting position on this floor."
		_:
			return ""


func _on_action_pressed() -> void:
	var room_type: String = room_data.get("type", "empty")
	action_pressed.emit(room_type, room_data)


func _on_formation_pressed() -> void:
	var room_type: String = room_data.get("type", "empty")
	formation_requested.emit(room_type, room_data)


func _on_back_out_pressed() -> void:
	back_out_pressed.emit()


func _refresh_formation_preview(show: bool) -> void:
	## Clear old preview
	for child: Node in _formation_preview.get_children():
		_formation_preview.remove_child(child)
		child.queue_free()

	if not show or roster_state == null:
		_formation_preview.visible = false
		return

	var front: Array[GlyphInstance] = []
	var back: Array[GlyphInstance] = []
	for g: GlyphInstance in roster_state.active_squad:
		if g.row_position == "back":
			back.append(g)
		else:
			front.append(g)

	## Build compact preview: "F: [icons]  B: [icons]"
	if not front.is_empty():
		var f_label: Label = Label.new()
		f_label.text = "Front:"
		f_label.add_theme_font_size_override("font_size", 11)
		f_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		f_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_formation_preview.add_child(f_label)
		for g: GlyphInstance in front:
			_formation_preview.add_child(_make_mini_icon(g))

	if not back.is_empty():
		var b_label: Label = Label.new()
		b_label.text = "  Back:"
		b_label.add_theme_font_size_override("font_size", 11)
		b_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		b_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_formation_preview.add_child(b_label)
		for g: GlyphInstance in back:
			_formation_preview.add_child(_make_mini_icon(g))

	_formation_preview.visible = true


func _make_mini_icon(g: GlyphInstance) -> Control:
	const ICON_SIZE: int = 28
	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
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
	letter.add_theme_font_size_override("font_size", 14)
	letter.add_theme_color_override("font_color", Color.WHITE)
	letter.add_theme_color_override("font_outline_color", Color.BLACK)
	letter.add_theme_constant_override("outline_size", 1)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(letter)

	GlyphArt.apply_texture(container, rect, letter, g.species.id if g.species else "", ICON_SIZE)
	return container
