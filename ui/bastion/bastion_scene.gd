class_name BastionScene
extends Control

## Hub screen with navigation to facilities.

signal rift_selected(template: RiftTemplate)

enum SubScreen { HUB, BARRACKS, FUSION, RIFT_GATE, CODEX }

var game_state: GameState = null
var roster_state: RosterState = null
var codex_state: CodexState = null
var crawler_state: CrawlerState = null
var fusion_engine: FusionEngine = null
var data_loader: Node = null

var _current_screen: int = SubScreen.HUB
var _hub: Control = null
var _barracks: Barracks = null
var _fusion_chamber: FusionChamber = null
var _rift_gate: RiftGate = null
var _codex_browser: CodexBrowser = null

## Hub elements
var _title_label: Label = null
var _status_label: Label = null
var _rift_gate_btn: Button = null
var _barracks_btn: Button = null
var _fusion_btn: Button = null
var _codex_btn: Button = null
var _squad_preview: HBoxContainer = null
var _squad_cards: Array[GlyphCard] = []
var _notification_label: Label = null
var _detail_popup: GlyphDetailPopup = null
var _npc_panel: NpcPanel = null
var _mastery_hint_shown: bool = false

## NPC buttons
var _npc_kael_btn: Button = null
var _npc_lira_btn: Button = null
var _npc_maro_btn: Button = null

## Tracks the last game_phase each NPC's dialogue was read at (0 = never read)
var _npc_read_phase: Dictionary = {"kael": 0, "lira": 0, "maro": 0}
## Indicator labels on NPC portrait art (keyed by npc_id)
var _npc_indicators: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_signals()


func setup(
	p_game_state: GameState,
	p_roster_state: RosterState,
	p_codex_state: CodexState,
	p_crawler_state: CrawlerState,
	p_fusion_engine: FusionEngine,
	p_data_loader: Node,
) -> void:
	game_state = p_game_state
	roster_state = p_roster_state
	codex_state = p_codex_state
	crawler_state = p_crawler_state
	fusion_engine = p_fusion_engine
	data_loader = p_data_loader

	## Setup sub-screens
	_barracks.setup(roster_state, crawler_state)
	_fusion_chamber.setup(fusion_engine, roster_state, crawler_state, data_loader)
	_rift_gate.setup(game_state, codex_state, data_loader)
	_codex_browser.setup(data_loader, codex_state, game_state, roster_state)
	_npc_panel.setup(data_loader, game_state)


func refresh() -> void:
	_update_status()
	_update_squad_preview()


func show_hub() -> void:
	_current_screen = SubScreen.HUB
	_hub.visible = true
	_barracks.visible = false
	_fusion_chamber.visible = false
	_rift_gate.visible = false
	_codex_browser.visible = false
	refresh()
	_update_npc_indicators()

	if not _mastery_hint_shown:
		_mastery_hint_shown = true
		show_notification(
			"Each glyph has 3 mastery objectives. Complete them in battle to unlock fusion!",
			Color("#88CCFF")
		)


func show_notification(text: String, color: Color = Color("#44FF44")) -> void:
	if _notification_label == null:
		return
	_notification_label.text = text
	_notification_label.add_theme_color_override("font_color", color)
	_notification_label.visible = true
	_notification_label.modulate = Color.WHITE
	## Fade out after 3 seconds
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_notification_label, "modulate", Color(1, 1, 1, 0), 1.0)
	tween.tween_callback(func() -> void: _notification_label.visible = false)


func get_sub_screen() -> int:
	return _current_screen


func _build_ui() -> void:
	## Background
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.10)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	## Hub panel
	_hub = Control.new()
	_hub.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hub)

	var hub_vbox: VBoxContainer = VBoxContainer.new()
	hub_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hub_vbox.offset_left = 20.0
	hub_vbox.offset_top = 20.0
	hub_vbox.offset_right = -20.0
	hub_vbox.offset_bottom = -20.0
	hub_vbox.add_theme_constant_override("separation", 16)
	_hub.add_child(hub_vbox)

	## Title
	_title_label = Label.new()
	_title_label.text = "BASTION"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_vbox.add_child(_title_label)

	## Navigation buttons
	var nav_row: HBoxContainer = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 20)
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hub_vbox.add_child(nav_row)

	_rift_gate_btn = Button.new()
	_rift_gate_btn.text = "Rift Gate"
	_rift_gate_btn.custom_minimum_size = Vector2(140, 44)
	nav_row.add_child(_rift_gate_btn)

	_barracks_btn = Button.new()
	_barracks_btn.text = "Barracks"
	_barracks_btn.custom_minimum_size = Vector2(140, 44)
	nav_row.add_child(_barracks_btn)

	_fusion_btn = Button.new()
	_fusion_btn.text = "Fusion Chamber"
	_fusion_btn.custom_minimum_size = Vector2(140, 44)
	nav_row.add_child(_fusion_btn)

	_codex_btn = Button.new()
	_codex_btn.text = "Codex"
	_codex_btn.custom_minimum_size = Vector2(140, 44)
	nav_row.add_child(_codex_btn)

	## Status bar
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_vbox.add_child(_status_label)

	## Squad preview header
	var squad_header: Label = Label.new()
	squad_header.text = "-- Active Squad --"
	squad_header.add_theme_font_size_override("font_size", 14)
	squad_header.add_theme_color_override("font_color", Color("#888888"))
	squad_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_vbox.add_child(squad_header)

	## Squad preview row
	_squad_preview = HBoxContainer.new()
	_squad_preview.add_theme_constant_override("separation", 12)
	_squad_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	hub_vbox.add_child(_squad_preview)

	## NPC row
	var npc_header: Label = Label.new()
	npc_header.text = "-- NPCs --"
	npc_header.add_theme_font_size_override("font_size", 14)
	npc_header.add_theme_color_override("font_color", Color("#888888"))
	npc_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_vbox.add_child(npc_header)

	var npc_row: HBoxContainer = HBoxContainer.new()
	npc_row.add_theme_constant_override("separation", 24)
	npc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hub_vbox.add_child(npc_row)

	_npc_kael_btn = _build_npc_card(npc_row, "Kael", "Veteran Warden", NpcPanel.NPC_COLORS["kael"])
	_npc_lira_btn = _build_npc_card(npc_row, "Lira", "Rift Researcher", NpcPanel.NPC_COLORS["lira"])
	_npc_maro_btn = _build_npc_card(npc_row, "Maro", "Crawler Mechanic", NpcPanel.NPC_COLORS["maro"])

	## Notification label (fades out after showing)
	_notification_label = Label.new()
	_notification_label.add_theme_font_size_override("font_size", 14)
	_notification_label.add_theme_color_override("font_color", Color("#44FF44"))
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.visible = false
	hub_vbox.add_child(_notification_label)

	## Sub-screens (hidden by default)
	_barracks = Barracks.new()
	_barracks.name = "Barracks"
	_barracks.visible = false
	add_child(_barracks)

	_fusion_chamber = FusionChamber.new()
	_fusion_chamber.name = "FusionChamber"
	_fusion_chamber.visible = false
	add_child(_fusion_chamber)

	_rift_gate = RiftGate.new()
	_rift_gate.name = "RiftGate"
	_rift_gate.visible = false
	add_child(_rift_gate)

	_codex_browser = CodexBrowser.new()
	_codex_browser.name = "CodexBrowser"
	_codex_browser.visible = false
	add_child(_codex_browser)

	## NPC panel (modal, above sub-screens)
	_npc_panel = NpcPanel.new()
	_npc_panel.name = "NpcPanel"
	add_child(_npc_panel)

	## Detail popup (above everything)
	_detail_popup = GlyphDetailPopup.new()
	_detail_popup.name = "DetailPopup"
	add_child(_detail_popup)


func _connect_signals() -> void:
	_rift_gate_btn.pressed.connect(_show_rift_gate)
	_barracks_btn.pressed.connect(_show_barracks)
	_fusion_btn.pressed.connect(_show_fusion)
	_codex_btn.pressed.connect(_show_codex)

	_barracks.done_pressed.connect(show_hub)
	_fusion_chamber.back_pressed.connect(show_hub)
	_rift_gate.back_pressed.connect(show_hub)
	_codex_browser.back_pressed.connect(show_hub)
	_rift_gate.rift_selected.connect(func(t: RiftTemplate) -> void: rift_selected.emit(t))

	## NPC buttons
	_npc_kael_btn.pressed.connect(func() -> void: _open_npc("kael"))
	_npc_lira_btn.pressed.connect(func() -> void: _open_npc("lira"))
	_npc_maro_btn.pressed.connect(func() -> void: _open_npc("maro"))


func _show_rift_gate() -> void:
	_current_screen = SubScreen.RIFT_GATE
	_hub.visible = false
	_barracks.visible = false
	_fusion_chamber.visible = false
	_codex_browser.visible = false
	_rift_gate.visible = true
	_rift_gate.refresh()


func _show_barracks() -> void:
	_current_screen = SubScreen.BARRACKS
	_hub.visible = false
	_rift_gate.visible = false
	_fusion_chamber.visible = false
	_codex_browser.visible = false
	_barracks.visible = true
	_barracks.refresh()


func _show_fusion() -> void:
	_current_screen = SubScreen.FUSION
	_hub.visible = false
	_rift_gate.visible = false
	_barracks.visible = false
	_codex_browser.visible = false
	_fusion_chamber.visible = true
	_fusion_chamber.refresh()


func _show_codex() -> void:
	_current_screen = SubScreen.CODEX
	_hub.visible = false
	_rift_gate.visible = false
	_barracks.visible = false
	_fusion_chamber.visible = false
	_codex_browser.visible = true
	_codex_browser.refresh()


func _update_status() -> void:
	if game_state == null or codex_state == null or roster_state == null:
		return
	var phase: int = game_state.game_phase
	var cleared: int = codex_state.cleared_rift_count()
	var glyph_count: int = roster_state.get_glyph_count()
	var codex_pct: int = int(codex_state.get_discovery_percentage() * 100)
	_status_label.text = "Phase %d \u00b7 %d Rifts Cleared \u00b7 %d Glyphs \u00b7 %d%% Codex" % [
		phase, cleared, glyph_count, codex_pct
	]


func _update_squad_preview() -> void:
	## Clear old cards
	_squad_cards.clear()
	for child: Node in _squad_preview.get_children():
		_squad_preview.remove_child(child)
		child.queue_free()

	if roster_state == null:
		return

	for g: GlyphInstance in roster_state.active_squad:
		var card: GlyphCard = GlyphCard.new()
		card.setup(g)
		card.card_clicked.connect(_on_squad_card_clicked)
		_squad_preview.add_child(card)
		_squad_cards.append(card)


func _on_squad_card_clicked(g: GlyphInstance) -> void:
	if g != null and _detail_popup != null:
		_detail_popup.show_glyph(g)


func _open_npc(npc_id: String) -> void:
	if game_state != null:
		_npc_read_phase[npc_id] = mini(game_state.game_phase, 3)
	_npc_panel.show_npc(npc_id)
	_update_npc_indicators()


func _update_npc_indicators() -> void:
	if game_state == null:
		return
	var phase: int = mini(game_state.game_phase, 3)
	for npc_id: String in _npc_indicators:
		var indicator: Label = _npc_indicators[npc_id] as Label
		if indicator == null:
			continue
		var read_phase: int = _npc_read_phase.get(npc_id, 0)
		indicator.visible = phase > read_phase


func _build_npc_card(parent: Control, npc_name: String, npc_title: String, npc_color: Color) -> Button:
	## Build a portrait card: art square + name + title, all inside a clickable Button
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(100, 110)
	## Transparent flat style so the card contents show through
	var flat_style: StyleBoxFlat = StyleBoxFlat.new()
	flat_style.bg_color = Color(0, 0, 0, 0)
	card.add_theme_stylebox_override("normal", flat_style)
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = Color(1, 1, 1, 0.05)
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)
	parent.add_child(card)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	## Portrait (48x48, centered)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(center)

	var art: ColorRect = ColorRect.new()
	art.custom_minimum_size = Vector2(48, 48)
	art.color = npc_color
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(art)

	var initial: Label = Label.new()
	initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.add_theme_font_size_override("font_size", 22)
	initial.add_theme_color_override("font_color", Color.WHITE)
	initial.add_theme_color_override("font_outline_color", Color.BLACK)
	initial.add_theme_constant_override("outline_size", 3)
	initial.text = npc_name[0].to_upper()
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(initial)

	## Unread indicator (top-right of portrait)
	var indicator: Label = Label.new()
	indicator.text = "\ud83d\udcac"
	indicator.add_theme_font_size_override("font_size", 14)
	indicator.add_theme_color_override("font_color", Color("#FFFF00"))
	indicator.add_theme_color_override("font_outline_color", Color.BLACK)
	indicator.add_theme_constant_override("outline_size", 3)
	indicator.position = Vector2(30, -2)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.visible = false
	art.add_child(indicator)
	_npc_indicators[npc_name.to_lower()] = indicator

	## Name
	var name_label: Label = Label.new()
	name_label.text = npc_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", npc_color.lightened(0.3))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	## Title
	var title_label: Label = Label.new()
	title_label.text = npc_title
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.add_theme_color_override("font_color", Color("#888888"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	return card
