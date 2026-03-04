class_name PuzzleEcho
extends Control

## Puzzle: encounter a ghostly echo glyph.
## Player can challenge it (fight) or walk past (skip).
## Challenge triggers a combat; winning allows free capture.

signal puzzle_completed(success: bool, reward_type: String, reward_data: Variant)
signal echo_combat_requested(echo_glyph: GlyphInstance)

var instant_mode: bool = false
var _echo_glyph: GlyphInstance = null
var _started: bool = false

## Internal nodes
var _bg: ColorRect = null
var _title_label: Label = null
var _description_label: Label = null
var _glyph_card: GlyphCard = null
var _button_row: HBoxContainer = null
var _challenge_btn: Button = null
var _walk_past_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func start(rift_template: RiftTemplate, data_loader: Node, roster_state: RosterState) -> void:
	if data_loader == null or rift_template == null:
		return

	_started = true
	visible = true

	## Pick a random species from the rift's wild_glyph_pool
	var pool: Array = rift_template.wild_glyph_pool
	if pool.is_empty():
		return

	var species_id: String = pool[randi() % pool.size()]
	var species: GlyphSpecies = data_loader.get_species(species_id)
	if species == null:
		return

	_echo_glyph = GlyphInstance.create_from_species(species, data_loader)
	_echo_glyph.side = "enemy"

	## Display the echo glyph
	_glyph_card.setup(_echo_glyph)

	_description_label.text = "A ghostly echo of %s shimmers before you..." % species.name


func start_with_glyph(glyph: GlyphInstance) -> void:
	## Deterministic start for testing
	_started = true
	visible = true
	_echo_glyph = glyph
	_glyph_card.setup(_echo_glyph)
	_description_label.text = "A ghostly echo of %s shimmers before you..." % glyph.species.name


func get_echo_glyph() -> GlyphInstance:
	return _echo_glyph


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
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Echo Encounter"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color("#8888FF"))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_description_label = Label.new()
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_description_label)

	## Glyph card display (centered)
	var card_container: CenterContainer = CenterContainer.new()
	vbox.add_child(card_container)

	_glyph_card = GlyphCard.new()
	_glyph_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.add_child(_glyph_card)

	## Action buttons
	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 20)
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_button_row)

	_challenge_btn = Button.new()
	_challenge_btn.text = "Challenge"
	_challenge_btn.custom_minimum_size = Vector2(120, 40)
	_challenge_btn.pressed.connect(_on_challenge)
	_button_row.add_child(_challenge_btn)

	_walk_past_btn = Button.new()
	_walk_past_btn.text = "Walk Past"
	_walk_past_btn.custom_minimum_size = Vector2(120, 40)
	_walk_past_btn.pressed.connect(_on_walk_past)
	_button_row.add_child(_walk_past_btn)

	## Capture hint
	var hint: Label = Label.new()
	hint.text = "Guaranteed capture on victory!"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#44CC44"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


func _on_challenge() -> void:
	if not _started or _echo_glyph == null:
		return
	visible = false
	echo_combat_requested.emit(_echo_glyph)


func _on_walk_past() -> void:
	if not _started:
		return
	visible = false
	puzzle_completed.emit(false, "none", null)
