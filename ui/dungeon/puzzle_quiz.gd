class_name PuzzleQuiz
extends Control

## Puzzle: "Who's That Glyph?" — identify a species from a silhouette.
## Shows a darkened glyph art (affinity color dimmed, no letter), 4 name choices.
## One shot: correct = item reward, wrong = no penalty, puzzle completes either way.

signal puzzle_completed(success: bool, reward_type: String, reward_data: Variant)

var instant_mode: bool = false
var _correct_species: GlyphSpecies = null
var _choices: Array[GlyphSpecies] = []
var _answered: bool = false

## Internal nodes
var _bg: ColorRect = null
var _title_label: Label = null
var _instruction_label: Label = null
var _silhouette_container: PanelContainer = null
var _silhouette_rect: ColorRect = null
var _choice_vbox: VBoxContainer = null
var _choice_buttons: Array[Button] = []
var _result_label: Label = null
var _continue_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func start(data_loader: Node, codex_state: CodexState, p_instant_mode: bool = false) -> void:
	instant_mode = p_instant_mode
	_answered = false
	visible = true

	## Pick a correct species
	var all_species: Array[GlyphSpecies] = []
	if data_loader != null:
		for sp: GlyphSpecies in data_loader.species.values():
			all_species.append(sp)

	if all_species.size() < 4:
		puzzle_completed.emit(false, "none", null)
		return

	## Prefer species the player has seen (discovered in codex) for easier quiz
	var discovered: Array[GlyphSpecies] = []
	var undiscovered: Array[GlyphSpecies] = []
	for sp: GlyphSpecies in all_species:
		if codex_state != null and codex_state.is_species_discovered(sp.id):
			discovered.append(sp)
		else:
			undiscovered.append(sp)

	## Pick correct answer — prefer discovered species
	var pool: Array[GlyphSpecies] = discovered if discovered.size() >= 4 else all_species
	pool.shuffle()
	_correct_species = pool[0]

	## Build 4 choices: 1 correct + 3 wrong
	_choices.clear()
	_choices.append(_correct_species)
	var wrong_pool: Array[GlyphSpecies] = []
	for sp: GlyphSpecies in all_species:
		if sp.id != _correct_species.id:
			wrong_pool.append(sp)
	wrong_pool.shuffle()
	for i: int in range(mini(3, wrong_pool.size())):
		_choices.append(wrong_pool[i])
	_choices.shuffle()

	_update_display()


func start_with_species(correct: GlyphSpecies, choices: Array[GlyphSpecies], p_instant_mode: bool = true) -> void:
	## Deterministic start for testing
	instant_mode = p_instant_mode
	_answered = false
	_correct_species = correct
	_choices = choices.duplicate()
	visible = true
	_update_display()


func attempt_answer(species_id: String) -> bool:
	## Direct test method — returns true if correct
	return _correct_species != null and _correct_species.id == species_id


func get_correct_species() -> GlyphSpecies:
	return _correct_species


func _update_display() -> void:
	## Set silhouette — dimmed affinity color, no letter visible
	if _correct_species != null:
		var aff_color: Color = Affinity.COLORS.get(_correct_species.affinity, Color.GRAY)
		_silhouette_rect.color = aff_color.darkened(0.7)

	## Update choice buttons
	for btn: Button in _choice_buttons:
		btn.visible = false
	for i: int in range(_choices.size()):
		if i < _choice_buttons.size():
			_choice_buttons[i].text = _choices[i].name
			_choice_buttons[i].visible = true
			_choice_buttons[i].disabled = false

	_result_label.visible = false
	_continue_btn.visible = false
	_title_label.text = "Who's That Glyph?"
	_instruction_label.text = "Identify the species from its silhouette."


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Who's That Glyph?"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color("#FFD700"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_instruction_label = Label.new()
	_instruction_label.add_theme_font_size_override("font_size", 14)
	_instruction_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_instruction_label)

	## Silhouette display — centered dark box
	var silhouette_center: HBoxContainer = HBoxContainer.new()
	silhouette_center.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(silhouette_center)

	_silhouette_container = PanelContainer.new()
	_silhouette_container.custom_minimum_size = Vector2(96, 96)
	var sil_style: StyleBoxFlat = StyleBoxFlat.new()
	sil_style.bg_color = Color(0.1, 0.1, 0.15)
	sil_style.set_corner_radius_all(8)
	sil_style.border_color = Color(0.3, 0.3, 0.4)
	sil_style.set_border_width_all(2)
	_silhouette_container.add_theme_stylebox_override("panel", sil_style)
	silhouette_center.add_child(_silhouette_container)

	_silhouette_rect = ColorRect.new()
	_silhouette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_silhouette_rect.color = Color(0.2, 0.2, 0.2)
	_silhouette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_silhouette_container.add_child(_silhouette_rect)

	## Question mark on silhouette
	var question_label: Label = Label.new()
	question_label.text = "?"
	question_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_label.add_theme_font_size_override("font_size", 48)
	question_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	question_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_silhouette_container.add_child(question_label)

	## Choice buttons
	_choice_vbox = VBoxContainer.new()
	_choice_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_choice_vbox)

	for i: int in range(4):
		var btn: Button = Button.new()
		btn.name = "QuizChoice_%d" % i
		btn.custom_minimum_size = Vector2(200, 36)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_choice_pressed(idx))
		_choice_vbox.add_child(btn)
		_choice_buttons.append(btn)

	## Result label
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 16)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.visible = false
	vbox.add_child(_result_label)

	## Continue button
	_continue_btn = Button.new()
	_continue_btn.name = "QuizContinueButton"
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(140, 40)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue)
	vbox.add_child(_continue_btn)


func _on_choice_pressed(idx: int) -> void:
	if _answered or idx >= _choices.size():
		return
	_answered = true

	var chosen: GlyphSpecies = _choices[idx]
	var correct: bool = chosen.id == _correct_species.id

	## Disable all buttons
	for btn: Button in _choice_buttons:
		btn.disabled = true

	## Reveal the silhouette
	if _correct_species != null:
		var aff_color: Color = Affinity.COLORS.get(_correct_species.affinity, Color.GRAY)
		_silhouette_rect.color = aff_color

	if correct:
		_result_label.text = "Correct! It's %s!" % _correct_species.name
		_result_label.add_theme_color_override("font_color", Color("#44FF44"))
	else:
		_result_label.text = "Wrong! It was %s." % _correct_species.name
		_result_label.add_theme_color_override("font_color", Color("#FF6644"))

	_result_label.visible = true
	_continue_btn.visible = true

	if instant_mode:
		if correct:
			puzzle_completed.emit(true, "item", null)
		else:
			puzzle_completed.emit(false, "none", null)


func _on_continue() -> void:
	var correct: bool = false
	if _correct_species != null and _answered:
		for i: int in range(_choices.size()):
			if _choice_buttons[i].text == _correct_species.name:
				correct = not _choice_buttons[i].disabled or true
				break
	## Re-check: was answer correct?
	if _result_label.text.begins_with("Correct"):
		puzzle_completed.emit(true, "item", null)
	else:
		puzzle_completed.emit(false, "none", null)
