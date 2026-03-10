class_name BastionScene
extends Control

## Hub screen with navigation to facilities.

signal rift_selected(template: RiftTemplate)
signal hub_entered
signal save_and_quit_pressed
signal save_slot_loaded

enum SubScreen { HUB, BARRACKS, FUSION, RIFT_GATE, CODEX, CRAWLER_BAY }

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
var _crawler_bay: CrawlerBay = null

## Hub elements
var _title_label: Label = null
var _status_label: Label = null
var _rift_gate_btn: Button = null
var _barracks_btn: Button = null
var _fusion_btn: Button = null
var _codex_btn: Button = null
var _crawler_bay_btn: Button = null
var _menu_btn: Button = null
var _pause_menu: PauseMenu = null
var _squad_preview: HBoxContainer = null
var _squad_cards: Array[GlyphCard] = []
var _notification_label: Label = null
var _detail_popup: GlyphDetailPopup = null
var _npc_panel: NpcPanel = null
var _back_bar: PanelContainer = null
var _back_bar_title: Label = null
var _mastery_hint_shown: bool = false
var _hints_shown: Dictionary = {}  ## screen_name → true

## NPC buttons
var _npc_kael_btn: Button = null
var _npc_lira_btn: Button = null
var _npc_maro_btn: Button = null

## Indicator labels on NPC portrait art (keyed by npc_id)
## _npc_indicators: chat bubble for unread dialogue
## _npc_quest_indicators: exclamation for claimable quest reward
var _npc_indicators: Dictionary = {}
var _npc_quest_indicators: Dictionary = {}


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
	_crawler_bay.setup(crawler_state, game_state.milestone_tracker if game_state else null)
	_npc_panel.setup(data_loader, game_state)
	_pause_menu.setup_save_slots(game_state, roster_state, codex_state, crawler_state, data_loader)


func refresh() -> void:
	_update_status()
	_update_squad_preview()


func show_hub() -> void:
	var was_in_sub: bool = _current_screen != SubScreen.HUB
	_current_screen = SubScreen.HUB
	_hide_all_screens()
	_hub.visible = true
	_back_bar.visible = false
	refresh()
	_update_npc_indicators()
	if was_in_sub:
		_slide_in(_hub)
		hub_entered.emit()

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

	_rift_gate_btn = _make_nav_button("Rift Gate")
	nav_row.add_child(_rift_gate_btn)

	_barracks_btn = _make_nav_button("Barracks")
	nav_row.add_child(_barracks_btn)

	_fusion_btn = _make_nav_button("Fusion Chamber")
	nav_row.add_child(_fusion_btn)

	_codex_btn = _make_nav_button("Codex")
	nav_row.add_child(_codex_btn)

	_crawler_bay_btn = _make_nav_button("Crawler Bay")
	nav_row.add_child(_crawler_bay_btn)

	_menu_btn = _make_nav_button("Menu")
	nav_row.add_child(_menu_btn)

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

	_crawler_bay = CrawlerBay.new()
	_crawler_bay.name = "CrawlerBay"
	_crawler_bay.visible = false
	add_child(_crawler_bay)

	## Persistent back bar (visible when in a sub-screen)
	_back_bar = PanelContainer.new()
	_back_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_back_bar.offset_bottom = 36.0
	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.08, 0.08, 0.12)
	bar_style.border_color = Color(0.2, 0.2, 0.3)
	bar_style.border_width_bottom = 1
	bar_style.content_margin_left = 16
	bar_style.content_margin_right = 16
	bar_style.content_margin_top = 4
	bar_style.content_margin_bottom = 4
	_back_bar.add_theme_stylebox_override("panel", bar_style)
	_back_bar.visible = false
	add_child(_back_bar)

	var bar_content: HBoxContainer = HBoxContainer.new()
	bar_content.add_theme_constant_override("separation", 12)
	bar_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_bar.add_child(bar_content)

	var back_btn: Button = Button.new()
	back_btn.name = "BackToBastionButton"
	back_btn.text = "\u2190 Bastion"
	back_btn.custom_minimum_size = Vector2(100, 24)
	back_btn.pressed.connect(show_hub)
	bar_content.add_child(back_btn)

	_back_bar_title = Label.new()
	_back_bar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_bar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_bar_title.add_theme_font_size_override("font_size", 20)
	_back_bar_title.add_theme_color_override("font_color", Color("#FFD700"))
	bar_content.add_child(_back_bar_title)

	## Spacer to keep title centered
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(100, 0)
	bar_content.add_child(spacer)

	## NPC panel (modal, above sub-screens)
	_npc_panel = NpcPanel.new()
	_npc_panel.name = "NpcPanel"
	add_child(_npc_panel)

	## Pause menu (reusable, above sub-screens)
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.save_and_quit_pressed.connect(func() -> void: save_and_quit_pressed.emit())
	_pause_menu.save_slot_loaded.connect(func() -> void: save_slot_loaded.emit())
	add_child(_pause_menu)

	## Detail popup (above everything)
	_detail_popup = GlyphDetailPopup.new()
	_detail_popup.name = "DetailPopup"
	add_child(_detail_popup)


func _connect_signals() -> void:
	_rift_gate_btn.pressed.connect(_show_rift_gate)
	_barracks_btn.pressed.connect(_show_barracks)
	_fusion_btn.pressed.connect(_show_fusion)
	_codex_btn.pressed.connect(_show_codex)
	_menu_btn.pressed.connect(func() -> void: _pause_menu.toggle())

	_crawler_bay_btn.pressed.connect(_show_crawler_bay)
	_barracks.done_pressed.connect(show_hub)
	_fusion_chamber.back_pressed.connect(show_hub)
	_rift_gate.back_pressed.connect(show_hub)
	_codex_browser.back_pressed.connect(show_hub)
	_rift_gate.rift_selected.connect(func(t: RiftTemplate) -> void: rift_selected.emit(t))

	## NPC buttons
	_npc_kael_btn.pressed.connect(func() -> void: _open_npc("kael"))
	_npc_lira_btn.pressed.connect(func() -> void: _open_npc("lira"))
	_npc_maro_btn.pressed.connect(func() -> void: _open_npc("maro"))


func _hide_all_screens() -> void:
	_hub.visible = false
	_rift_gate.visible = false
	_barracks.visible = false
	_fusion_chamber.visible = false
	_codex_browser.visible = false
	_crawler_bay.visible = false


func _show_rift_gate() -> void:
	_current_screen = SubScreen.RIFT_GATE
	_hide_all_screens()
	_rift_gate.visible = true
	_back_bar.visible = true
	_back_bar_title.text = "RIFT GATE"
	_rift_gate.refresh()
	_slide_in(_rift_gate)
	_show_hint_once("rift_gate")


func _show_barracks() -> void:
	_current_screen = SubScreen.BARRACKS
	_hide_all_screens()
	_barracks.visible = true
	_back_bar.visible = true
	_back_bar_title.text = "BARRACKS"
	_barracks.refresh()
	_slide_in(_barracks)
	_show_hint_once("barracks")


func _show_fusion() -> void:
	_current_screen = SubScreen.FUSION
	_hide_all_screens()
	_fusion_chamber.visible = true
	_back_bar.visible = true
	_back_bar_title.text = "FUSION CHAMBER"
	_fusion_chamber.refresh()
	_slide_in(_fusion_chamber)
	_show_hint_once("fusion")


func _show_codex() -> void:
	_current_screen = SubScreen.CODEX
	_hide_all_screens()
	_codex_browser.visible = true
	_back_bar.visible = true
	_back_bar_title.text = "CODEX"
	_codex_browser.refresh()
	_slide_in(_codex_browser)
	_show_hint_once("codex")


func _show_crawler_bay() -> void:
	_current_screen = SubScreen.CRAWLER_BAY
	_hide_all_screens()
	_crawler_bay.visible = true
	_back_bar.visible = true
	_back_bar_title.text = "CRAWLER BAY"
	_crawler_bay.refresh()
	_slide_in(_crawler_bay)
	_show_hint_once("crawler_bay")


func _slide_in(screen: Control) -> void:
	screen.position.x = 40.0
	screen.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(screen, "position:x", 0.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(screen, "modulate", Color.WHITE, 0.15)




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
		game_state.npc_read_phase[npc_id] = mini(game_state.game_phase, 3)
	_npc_panel.show_npc(npc_id)
	_update_npc_indicators()


func _update_npc_indicators() -> void:
	if game_state == null:
		return
	var phase: int = mini(game_state.game_phase, 3)
	for npc_id: String in _npc_indicators:
		## Chat bubble for unread dialogue
		var indicator: Label = _npc_indicators[npc_id] as Label
		if indicator != null:
			var read_phase: int = game_state.npc_read_phase.get(npc_id, 0)
			var should_show: bool = phase > read_phase
			indicator.visible = should_show
			if should_show and indicator.is_inside_tree():
				_start_bob_tween(indicator)

		## Quest reward exclamation
		var quest_ind: Label = _npc_quest_indicators.get(npc_id) as Label
		if quest_ind != null:
			var quest_status: Dictionary = game_state.check_quest_status(npc_id)
			var quest_ready: bool = quest_status.get("state", "") == "complete"
			quest_ind.visible = quest_ready
			if quest_ready and quest_ind.is_inside_tree():
				_start_bob_tween(quest_ind)


const SCREEN_HINTS: Dictionary = {
	"barracks": "Manage your active squad and reserves. Drag glyphs between squad and reserve slots.",
	"fusion": "Fuse two mastered glyphs to create a stronger species. Both parents are consumed.",
	"codex": "Track discovered species, fusion history, and rift completions.",
	"rift_gate": "Select a rift to explore. Clearing rifts advances the phase and unlocks new rifts.",
	"crawler_bay": "View crawler upgrades, switch chassis, and check milestone progress.",
}


func _show_hint_once(screen_name: String) -> void:
	if _hints_shown.get(screen_name, false):
		return
	_hints_shown[screen_name] = true
	var hint: String = SCREEN_HINTS.get(screen_name, "")
	if hint != "":
		show_notification(hint, Color("#88CCFF"))


func _make_nav_button(label_text: String) -> Button:
	var btn: Button = Button.new()
	btn.name = "%sButton" % label_text.replace(" ", "")
	btn.text = label_text
	btn.custom_minimum_size = Vector2(140, 44)
	BattleScene._apply_button_fx(btn)
	return btn


func _start_bob_tween(indicator: Label) -> void:
	## Gentle up/down bob loop on the chat bubble indicator
	var base_y: float = indicator.position.y
	var tween: Tween = indicator.create_tween()
	tween.set_loops()
	tween.tween_property(indicator, "position:y", base_y - 4.0, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(indicator, "position:y", base_y, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _build_npc_card(parent: Control, npc_name: String, npc_title: String, npc_color: Color) -> Button:
	## Build a portrait card: art square + name + title, all inside a clickable Button
	var card: Button = Button.new()
	card.name = "NpcCard_%s" % npc_name.replace(" ", "")
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

	## Quest reward indicator (top-left of portrait, gold exclamation)
	var quest_indicator: Label = Label.new()
	quest_indicator.text = "!"
	quest_indicator.add_theme_font_size_override("font_size", 18)
	quest_indicator.add_theme_color_override("font_color", Color("#FFD700"))
	quest_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
	quest_indicator.add_theme_constant_override("outline_size", 4)
	quest_indicator.position = Vector2(-4, -6)
	quest_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_indicator.visible = false
	art.add_child(quest_indicator)
	_npc_quest_indicators[npc_name.to_lower()] = quest_indicator

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
