class_name NpcPanel
extends ColorRect

## Modal NPC dialogue overlay.
## Same pattern as GlyphDetailPopup: full-rect semi-transparent bg, centered panel.

signal closed

var data_loader: Node = null
var game_state: GameState = null

## Portrait colors per NPC
const NPC_COLORS: Dictionary = {
	"kael": Color("#CC4444"),
	"lira": Color("#44AACC"),
	"maro": Color("#CC8844"),
}

## Internal nodes
var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _portrait_panel: PanelContainer = null
var _portrait_rect: ColorRect = null
var _portrait_label: Label = null
var _name_label: Label = null
var _title_label: Label = null
var _dialogue_label: Label = null
var _quest_label: Label = null
var _quest_btn: Button = null
var _current_npc_id: String = ""
var _close_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.7)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func setup(p_data_loader: Node, p_game_state: GameState) -> void:
	data_loader = p_data_loader
	game_state = p_game_state


func show_npc(npc_id: String) -> void:
	if data_loader == null or game_state == null:
		return
	if not data_loader.npc_dialogue.has(npc_id):
		return

	var npc_data: Dictionary = data_loader.npc_dialogue[npc_id]
	var npc_name: String = npc_data.get("name", npc_id.capitalize())
	var npc_title: String = npc_data.get("title", "")
	var phases: Dictionary = npc_data.get("phases", {})

	## Check if all rifts are cleared for the "all_cleared" dialogue
	var all_cleared: bool = false
	if game_state.codex_state != null and game_state.data_loader != null:
		var total_rifts: int = game_state.data_loader.rift_templates.size()
		all_cleared = game_state.codex_state.cleared_rift_count() >= total_rifts

	## Use all_cleared key if available, otherwise fall back to phase
	var phase_key: String = "all_cleared" if all_cleared else str(game_state.game_phase)
	var lines: Array = phases.get(phase_key, [])
	if lines.is_empty():
		## Fall back to highest numbered phase
		for p: int in range(game_state.game_phase, 0, -1):
			lines = phases.get(str(p), [])
			if not lines.is_empty():
				break
	var dialogue_text: String = ""
	if not lines.is_empty():
		dialogue_text = lines[randi() % lines.size()]

	## Portrait color
	var portrait_color: Color = NPC_COLORS.get(npc_id, Color("#888888"))

	## Update UI
	_portrait_rect.color = portrait_color
	_portrait_label.text = npc_name[0].to_upper()
	_name_label.text = npc_name
	_name_label.add_theme_color_override("font_color", portrait_color.lightened(0.3))
	_title_label.text = npc_title
	_current_npc_id = npc_id

	## Quest handling — may override dialogue text
	var quest_status: Dictionary = game_state.check_quest_status(npc_id)
	var quest_state: String = quest_status.get("state", "")
	_quest_label.visible = false
	_quest_btn.visible = false

	if quest_state == "active":
		var quest: Dictionary = quest_status["quest"]
		var progress: int = quest_status.get("progress", 0)
		var total: int = quest_status.get("total", 1)
		var seen_quest: String = game_state.npc_read_quest.get(npc_id, "")
		var first_visit: bool = seen_quest == "" or seen_quest == "locked"
		dialogue_text = quest.get("accept_dialogue", dialogue_text) if first_visit else quest.get("progress_dialogue", dialogue_text) % progress
		_quest_label.text = "Quest: %s (%d/%d)" % [quest.get("name", ""), progress, total]
		_quest_label.add_theme_color_override("font_color", Color("#FFCC00"))
		_quest_label.visible = true
	elif quest_state == "complete":
		var quest: Dictionary = quest_status["quest"]
		dialogue_text = quest.get("complete_dialogue", dialogue_text)
		_quest_label.text = "Quest: %s — COMPLETE!" % quest.get("name", "")
		_quest_label.add_theme_color_override("font_color", Color("#44FF44"))
		_quest_label.visible = true
		_quest_btn.text = "Claim Reward"
		_quest_btn.visible = true
	elif quest_state == "done":
		var quest: Dictionary = quest_status["quest"]
		_quest_label.text = "Quest: %s — Done" % quest.get("name", "")
		_quest_label.add_theme_color_override("font_color", Color("#888888"))
		_quest_label.visible = true

	_dialogue_label.text = dialogue_text

	## Update portrait border color to match NPC
	var style: StyleBoxFlat = _portrait_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		var new_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
		new_style.bg_color = portrait_color.darkened(0.4)
		new_style.border_color = portrait_color.lightened(0.2)
		_portrait_panel.add_theme_stylebox_override("panel", new_style)

	visible = true


func hide_popup() -> void:
	visible = false


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
	panel_style.border_color = Color("#888888")
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
	_vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(_vbox)

	## Portrait (80x80, centered)
	var portrait_center: CenterContainer = CenterContainer.new()
	_vbox.add_child(portrait_center)

	_portrait_panel = PanelContainer.new()
	var portrait_panel: PanelContainer = _portrait_panel
	portrait_panel.custom_minimum_size = Vector2(80, 80)
	var portrait_style: StyleBoxFlat = StyleBoxFlat.new()
	portrait_style.bg_color = Color("#888888")
	portrait_style.corner_radius_top_left = 8
	portrait_style.corner_radius_top_right = 8
	portrait_style.corner_radius_bottom_left = 8
	portrait_style.corner_radius_bottom_right = 8
	portrait_style.border_color = Color("#FFFFFF44")
	portrait_style.border_width_left = 2
	portrait_style.border_width_right = 2
	portrait_style.border_width_top = 2
	portrait_style.border_width_bottom = 2
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	portrait_center.add_child(portrait_panel)

	_portrait_rect = ColorRect.new()
	_portrait_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_rect.color = Color("#888888")
	portrait_panel.add_child(_portrait_rect)

	_portrait_label = Label.new()
	_portrait_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_label.add_theme_font_size_override("font_size", 32)
	_portrait_label.add_theme_color_override("font_color", Color.WHITE)
	_portrait_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_portrait_label.add_theme_constant_override("outline_size", 4)
	portrait_panel.add_child(_portrait_label)

	## Name (centered)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_name_label)

	## Title (centered, smaller)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)

	## Dialogue text
	_dialogue_label = Label.new()
	_dialogue_label.add_theme_font_size_override("font_size", 14)
	_dialogue_label.add_theme_color_override("font_color", Color("#DDDDDD"))
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_dialogue_label)

	## Quest status label
	_quest_label = Label.new()
	_quest_label.add_theme_font_size_override("font_size", 12)
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_label.visible = false
	_vbox.add_child(_quest_label)

	## Quest complete button
	_quest_btn = Button.new()
	_quest_btn.name = "QuestCompleteButton"
	_quest_btn.text = "Claim Reward"
	_quest_btn.custom_minimum_size = Vector2(140, 32)
	_quest_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quest_btn.visible = false
	_quest_btn.pressed.connect(_on_quest_complete)
	_vbox.add_child(_quest_btn)

	## Close button
	_close_btn = Button.new()
	_close_btn.name = "NpcCloseButton"
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(100, 32)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(func() -> void:
		hide_popup()
		closed.emit()
	)
	_vbox.add_child(_close_btn)


func _on_quest_complete() -> void:
	if game_state == null or _current_npc_id == "":
		return
	var reward_text: String = game_state.complete_quest(_current_npc_id)
	if reward_text != "":
		_quest_btn.visible = false
		_quest_label.text = reward_text
		_quest_label.add_theme_color_override("font_color", Color("#44FF44"))


func _gui_input(event: InputEvent) -> void:
	## Click outside panel to close
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var panel_rect: Rect2 = Rect2(_panel.global_position, _panel.size)
			if not panel_rect.has_point(mb.global_position):
				hide_popup()
				closed.emit()
