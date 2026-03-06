class_name GlyphDetailPopup
extends ColorRect

## Modal popup showing full glyph info + mastery checklist.
## Two modes: show_glyph() for instance view, show_species_info() for codex species view.

signal closed

var glyph: GlyphInstance = null
var species: GlyphSpecies = null  ## Set in both modes for external inspection

## Internal nodes
var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _header_label: Label = null
var _art_rect: ColorRect = null
var _initial_label: Label = null
var _stats_label: Label = null
var _gp_label: Label = null
var _techniques_header: Label = null
var _techniques_vbox: VBoxContainer = null
var _mastery_header: Label = null
var _mastery_vbox: VBoxContainer = null
var _mastery_bonus_label: Label = null
var _mastered_banner: Label = null
var _location_label: Label = null
var _close_button: Button = null
var _art_panel: PanelContainer = null

const _RANGE_TAGS: Dictionary = {
	"melee": "\ud83d\udc4a",
	"ranged": "\ud83c\udff9",
	"aoe": "\ud83d\udca5",
	"piercing": "\ud83c\udfaf",
}



func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.7)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func show_glyph(p_glyph: GlyphInstance) -> void:
	glyph = p_glyph
	species = p_glyph.species if p_glyph != null else null
	visible = true
	_animate_show()
	_location_label.visible = false
	_refresh()


func show_species_info(sp: GlyphSpecies, data_loader: Node, is_captured: bool) -> void:
	## Codex species-level view: base stats, all techniques, possible masteries, rift locations
	glyph = null
	species = sp
	visible = true
	_animate_show()
	_refresh_species(sp, data_loader, is_captured)


func hide_popup() -> void:
	visible = false
	glyph = null
	species = null


func _animate_show() -> void:
	if _panel == null:
		return
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.8, 0.8)
	_panel.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate", Color.WHITE, 0.15)


func _refresh() -> void:
	if glyph == null or glyph.species == null:
		return

	var sp: GlyphSpecies = glyph.species
	var aff: String = sp.affinity
	var aff_color: Color = Affinity.COLORS.get(aff, Affinity.COLORS["neutral"])

	## Header: "Zapplet · Electric T1"
	_header_label.text = "%s \u00b7 %s %s T%d" % [sp.name, Affinity.EMOJI.get(aff, ""), aff.capitalize(), sp.tier]
	_header_label.add_theme_color_override("font_color", aff_color)

	## Art placeholder
	_art_rect.color = aff_color
	_initial_label.text = sp.name[0].to_upper()
	GlyphArt.apply_texture(_art_panel, _art_rect, _initial_label, sp.id, 64)

	## Stats
	_stats_label.text = "HP: %d  ATK: %d  DEF: %d  SPD: %d  RES: %d" % [
		glyph.max_hp, glyph.atk, glyph.def_stat, glyph.spd, glyph.res
	]
	_gp_label.text = "GP: %d" % sp.gp_cost

	## Techniques
	_refresh_techniques(glyph.techniques)

	## Mastery section
	_refresh_mastery()


func _refresh_species(sp: GlyphSpecies, data_loader: Node, is_captured: bool) -> void:
	var aff: String = sp.affinity
	var aff_color: Color = Affinity.COLORS.get(aff, Affinity.COLORS["neutral"])

	## Header
	_header_label.text = "%s \u00b7 %s %s T%d" % [sp.name, Affinity.EMOJI.get(aff, ""), aff.capitalize(), sp.tier]
	_header_label.add_theme_color_override("font_color", aff_color)

	## Art placeholder
	_art_rect.color = aff_color
	_initial_label.text = sp.name[0].to_upper()
	GlyphArt.apply_texture(_art_panel, _art_rect, _initial_label, sp.id, 64)

	## Base stats (species-level, not instance)
	_stats_label.text = "HP: %d  ATK: %d  DEF: %d  SPD: %d  RES: %d" % [
		sp.base_hp, sp.base_atk, sp.base_def, sp.base_spd, sp.base_res
	]
	_gp_label.text = "GP: %d" % sp.gp_cost

	## All native techniques
	var techs: Array[TechniqueDef] = []
	for tid: String in sp.technique_ids:
		var tech: TechniqueDef = data_loader.get_technique(tid)
		if tech != null:
			techs.append(tech)
	_refresh_techniques(techs)

	## Mastery: show possible objectives for this tier
	_refresh_species_mastery(sp, data_loader)

	## Location: which rifts contain this species
	_refresh_location(sp, data_loader, is_captured)


func _refresh_species_mastery(sp: GlyphSpecies, data_loader: Node) -> void:
	for child: Node in _mastery_vbox.get_children():
		_mastery_vbox.remove_child(child)
		child.queue_free()

	_mastered_banner.visible = false
	_mastery_bonus_label.visible = false

	if sp.tier == 4:
		_mastery_header.text = "-- Mastery (apex — no mastery) --"
		return

	_mastery_header.text = "-- Mastery Objectives --"

	## Fixed objectives from species
	for obj: Dictionary in sp.fixed_mastery_objectives:
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", 13)
		label.text = "\u2022 %s" % obj.get("description", "Unknown")
		label.add_theme_color_override("font_color", Color("#CCCCCC"))
		_mastery_vbox.add_child(label)

	## Random pool objectives for this tier
	var pool: Array = data_loader.mastery_pools.get(sp.tier, [])
	if pool.size() > 0:
		var header: Label = Label.new()
		header.add_theme_font_size_override("font_size", 12)
		header.text = "+ 1 random from:"
		header.add_theme_color_override("font_color", Color("#888888"))
		_mastery_vbox.add_child(header)
		for obj: Dictionary in pool:
			var label: Label = Label.new()
			label.add_theme_font_size_override("font_size", 12)
			label.text = "  \u2022 %s" % obj.get("description", "Unknown")
			label.add_theme_color_override("font_color", Color("#999999"))
			_mastery_vbox.add_child(label)


func _refresh_location(sp: GlyphSpecies, data_loader: Node, is_captured: bool) -> void:
	if not is_captured:
		_location_label.text = "Capture to reveal locations"
		_location_label.add_theme_color_override("font_color", Color("#666666"))
		_location_label.visible = true
		return

	## Find rifts containing this species
	var rift_names: Array[String] = []
	for rt: RiftTemplate in data_loader.rift_templates:
		if sp.id in rt.wild_glyph_pool:
			rift_names.append(rt.name)
	if rift_names.is_empty():
		_location_label.text = "Found in: Unknown"
	else:
		_location_label.text = "Found in: %s" % ", ".join(rift_names)
	_location_label.add_theme_color_override("font_color", Color("#88AACC"))
	_location_label.visible = true


func _refresh_mastery() -> void:
	## Instance-level mastery display (used by show_glyph)
	_location_label.visible = false

	## Clear old objective labels
	for child: Node in _mastery_vbox.get_children():
		_mastery_vbox.remove_child(child)
		child.queue_free()

	var objectives: Array[Dictionary] = glyph.mastery_objectives
	var total: int = objectives.size()
	var completed: int = 0
	for obj: Dictionary in objectives:
		if obj.get("completed", false):
			completed += 1

	## No objectives: T4 species
	if total == 0:
		if glyph.species != null and glyph.species.tier == 4:
			_mastery_header.text = "-- Mastery (apex — no mastery) --"
		else:
			_mastery_header.text = "-- Mastery --"
		_mastered_banner.visible = false
		_mastery_bonus_label.visible = false
		return

	_mastery_header.text = "-- Mastery (%d/%d) --" % [completed, total]

	## Mastered banner
	if glyph.is_mastered:
		_mastered_banner.text = "MASTERED"
		_mastered_banner.add_theme_color_override("font_color", Color("#FFD700"))
		_mastered_banner.visible = true
		_mastery_bonus_label.text = "+2 all stats applied"
		_mastery_bonus_label.add_theme_color_override("font_color", Color("#FFD700"))
		_mastery_bonus_label.visible = true
	else:
		_mastered_banner.visible = false
		_mastery_bonus_label.text = "+2 all stats on mastery completion"
		_mastery_bonus_label.add_theme_color_override("font_color", Color("#888888"))
		_mastery_bonus_label.visible = true

	## Objective list
	for i: int in range(total):
		var obj: Dictionary = objectives[i]
		var is_complete: bool = obj.get("completed", false)
		var desc: String = obj.get("description", "Unknown objective")
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", 13)

		if is_complete:
			label.text = "\u2713 %s" % desc
			label.add_theme_color_override("font_color", Color("#4CAF50"))
		else:
			## Check for progressive counter
			var params: Dictionary = obj.get("params", {})
			var progress_text: String = ""
			if params.has("current") and params.has("target"):
				progress_text = " [%d/%d]" % [params.get("current", 0), params.get("target", 1)]
			label.text = "\u25cb %s%s" % [desc, progress_text]
			label.add_theme_color_override("font_color", Color("#AAAAAA"))

		_mastery_vbox.add_child(label)


func _build_ui() -> void:
	## Centered panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(420, 340)
	_panel.offset_left = -210.0
	_panel.offset_right = 210.0
	_panel.offset_top = -170.0
	_panel.offset_bottom = 170.0
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1A2E")
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.border_color = Color("#FFD700")
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(_vbox)

	## Header: "Zapplet · Electric T1"
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_header_label)

	## Art + stats row
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	_vbox.add_child(top_row)

	## Art placeholder (64x64)
	_art_panel = PanelContainer.new()
	var art_panel: PanelContainer = _art_panel
	art_panel.custom_minimum_size = Vector2(64, 64)
	top_row.add_child(art_panel)

	_art_rect = ColorRect.new()
	_art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_rect.color = Affinity.COLORS["neutral"]
	art_panel.add_child(_art_rect)

	_initial_label = Label.new()
	_initial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initial_label.add_theme_font_size_override("font_size", 28)
	_initial_label.add_theme_color_override("font_color", Color.WHITE)
	_initial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_initial_label.add_theme_constant_override("outline_size", 4)
	art_panel.add_child(_initial_label)

	## Stats column
	var stats_vbox: VBoxContainer = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	top_row.add_child(stats_vbox)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	stats_vbox.add_child(_stats_label)

	_gp_label = Label.new()
	_gp_label.add_theme_font_size_override("font_size", 13)
	_gp_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	stats_vbox.add_child(_gp_label)

	## Techniques
	_techniques_header = Label.new()
	_techniques_header.text = "-- Techniques --"
	_techniques_header.add_theme_font_size_override("font_size", 13)
	_techniques_header.add_theme_color_override("font_color", Color("#AAAAAA"))
	_techniques_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_techniques_header)

	_techniques_vbox = VBoxContainer.new()
	_techniques_vbox.add_theme_constant_override("separation", 2)
	_vbox.add_child(_techniques_vbox)

	## Mastery header
	_mastery_header = Label.new()
	_mastery_header.add_theme_font_size_override("font_size", 14)
	_mastery_header.add_theme_color_override("font_color", Color("#AAAAAA"))
	_mastery_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_mastery_header)

	## Mastered banner (hidden by default)
	_mastered_banner = Label.new()
	_mastered_banner.add_theme_font_size_override("font_size", 18)
	_mastered_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mastered_banner.visible = false
	_vbox.add_child(_mastered_banner)

	## Mastery objectives VBox
	_mastery_vbox = VBoxContainer.new()
	_mastery_vbox.add_theme_constant_override("separation", 4)
	_vbox.add_child(_mastery_vbox)

	## Mastery bonus label
	_mastery_bonus_label = Label.new()
	_mastery_bonus_label.add_theme_font_size_override("font_size", 11)
	_mastery_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mastery_bonus_label.visible = false
	_vbox.add_child(_mastery_bonus_label)

	## Location label (codex species view only)
	_location_label = Label.new()
	_location_label.add_theme_font_size_override("font_size", 13)
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_location_label.visible = false
	_vbox.add_child(_location_label)

	## Close button
	_close_button = Button.new()
	_close_button.name = "DetailCloseButton"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(120, 32)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(func() -> void:
		hide_popup()
		closed.emit()
	)
	_vbox.add_child(_close_button)


func _refresh_techniques(techs: Array[TechniqueDef]) -> void:
	for child: Node in _techniques_vbox.get_children():
		_techniques_vbox.remove_child(child)
		child.queue_free()

	for tech: TechniqueDef in techs:
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", 13)
		label.text = _format_technique(tech)
		var tech_color: Color = Affinity.COLORS.get(tech.affinity, Color.WHITE)
		label.add_theme_color_override("font_color", tech_color)
		_techniques_vbox.add_child(label)


func _format_technique(tech: TechniqueDef) -> String:
	var aff_tag: String = Affinity.EMOJI.get(tech.affinity, "?")
	var range_tag: String = _RANGE_TAGS.get(tech.range_type, "?")
	var text: String = ""
	if tech.power > 0:
		text = "%s %s  %s %d" % [aff_tag, tech.name, range_tag, tech.power]
	elif tech.category == "support":
		text = "%s %s  %s" % [aff_tag, tech.name, tech.support_effect.capitalize()]
	else:
		text = "%s %s  %s" % [aff_tag, tech.name, range_tag]
	if tech.cooldown > 0:
		text += "  \u231b%d" % tech.cooldown
	if tech.status_effect != "":
		text += "  [%s %d%%]" % [tech.status_effect.capitalize(), tech.status_accuracy]
	return text


func _gui_input(event: InputEvent) -> void:
	## Click outside panel to close
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			## Check if click is outside the panel
			var panel_rect: Rect2 = Rect2(_panel.global_position, _panel.size)
			if not panel_rect.has_point(mb.global_position):
				hide_popup()
				closed.emit()
