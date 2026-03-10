class_name PuzzleEcho
extends Control

## Puzzle: encounter a ghostly echo glyph.
## Player can challenge it (fight) or walk past (skip).
## Challenge triggers a combat; winning allows free capture.

signal puzzle_completed(success: bool, reward_type: String, reward_data: Variant)
signal echo_combat_requested(echo_glyph: GlyphInstance)

## Per-species echo flavor text and memory fragments
const ECHO_LORE: Dictionary = {
	"zapplet": {
		"encounter": "Static crackles in the air. A ghostly Zapplet flickers into view, trailing arcs of errant voltage — a memory of the first charge.",
		"fragment": "Memory Fragment: \"Before the rifts opened, Zapplets gathered in swarms above copper spires, drawn to the resonance of the old conductors.\"",
	},
	"sparkfin": {
		"encounter": "A faint glow pulses in the dark. The ghostly outline of a Sparkfin circles you, its fins leaving trails of dying light.",
		"fragment": "Memory Fragment: \"Sparkfins were the first species to adapt to rift energy. Their fins evolved to channel it, not just conduct it.\"",
	},
	"stonepaw": {
		"encounter": "The ground trembles. A spectral Stonepaw rises from the floor tiles, its crystalline claws scraping against reality itself.",
		"fragment": "Memory Fragment: \"Stonepaws once burrowed through solid bedrock to build their dens. The rifts turned their tunnels into something... else.\"",
	},
	"mossling": {
		"encounter": "Wisps of green light drift past. A translucent Mossling materializes among them, its mossy tendrils reaching toward you as if remembering sunlight.",
		"fragment": "Memory Fragment: \"Mosslings were caretakers of the deep forests. When the trees died, they retreated into the rifts and never came back.\"",
	},
	"driftwisp": {
		"encounter": "Reality bends. A Driftwisp phases in and out of existence at the edge of your vision, its form shifting between here and somewhere else entirely.",
		"fragment": "Memory Fragment: \"Driftwisps exist in two places at once. Some researchers believe they're not echoes at all — just the other half, briefly visible.\"",
	},
	"glitchkit": {
		"encounter": "Your crawler's instruments spike with noise. A Glitchkit materializes from the interference, its form stuttering like corrupted data.",
		"fragment": "Memory Fragment: \"Glitchkits feed on unstable energy signatures. They're drawn to damaged rift walls — where reality is thinnest.\"",
	},
	"thunderclaw": {
		"encounter": "Lightning arcs between the walls. A massive Thunderclaw drops from above, its claws crackling with contained fury, eyes locked on you.",
		"fragment": "Memory Fragment: \"Thunderclaws were apex predators before the rifts. They adapted fastest — the storms in here are nothing compared to what they survived outside.\"",
	},
	"ironbark": {
		"encounter": "The walls groan. An Ironbark materializes from the stone itself, ancient and immovable, its bark-like hide scarred from a hundred forgotten battles.",
		"fragment": "Memory Fragment: \"The oldest Ironbarks remember the world before the rifts. They don't fight to survive — they fight because they remember what was lost.\"",
	},
	"vortail": {
		"encounter": "Space warps around a central point, and a Vortail unfolds from the distortion. Its tail traces impossible geometries in the air behind it.",
		"fragment": "Memory Fragment: \"Vortails navigate by sensing tears in space-time. Follow one long enough and you'll find every hidden room in the rift.\"",
	},
	"stormfang": {
		"encounter": "The air pressure drops. A Stormfang's silhouette forms in a swirl of charged particles, its fangs generating their own lightning field.",
		"fragment": "Memory Fragment: \"A single Stormfang can generate enough voltage to power a city. The old world tried to harness them. That didn't end well.\"",
	},
	"terradon": {
		"encounter": "The floor cracks in concentric rings. A Terradon heaves itself upward through the fractures, each step sending tremors through the entire floor.",
		"fragment": "Memory Fragment: \"Terradons are living geology. Their bones are crystallized minerals, and their heartbeat registers on seismic instruments.\"",
	},
	"riftmaw": {
		"encounter": "A void opens in the air ahead. Two pale eyes peer out from absolute darkness, and a Riftmaw slides into existence like a predator emerging from deep water.",
		"fragment": "Memory Fragment: \"Riftmaws don't enter rifts — they ARE rifts. Each one carries a pocket dimension in its throat. No one knows what's inside.\"",
	},
	"voltarion": {
		"encounter": "Every light source in the corridor dims, then blazes white. A Voltarion materializes in the center of the surge, radiating power that makes your skin tingle.",
		"fragment": "Memory Fragment: \"Voltarions were once worshipped as storm gods. The truth is stranger — they're living capacitors, evolved to store and release rift energy.\"",
	},
	"lithosurge": {
		"encounter": "The walls reshape themselves into an archway, and a Lithosurge steps through as if the rift itself built a door for it. The stone heals behind it.",
		"fragment": "Memory Fragment: \"Lithosurges don't just move through stone — they negotiate with it. The rifts bend to their will because they understand the underlying architecture.\"",
	},
	"nullweaver": {
		"encounter": "Everything goes silent. Not quiet — silent. A Nullweaver drifts through the void where sound used to be, rewriting the rules of the space around it.",
		"fragment": "Memory Fragment: \"The Nullweaver was the last species discovered. Or perhaps the first — records from before the rifts mention something eerily similar.\"",
	},
}

var instant_mode: bool = false
var _echo_glyph: GlyphInstance = null
var _started: bool = false

## Internal nodes
var _bg: ColorRect = null
var _title_label: Label = null
var _description_label: Label = null
var _lore_label: Label = null
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
	_apply_lore(species.id, species.name)


func start_with_glyph(glyph: GlyphInstance) -> void:
	## Deterministic start for testing
	_started = true
	visible = true
	_echo_glyph = glyph
	_glyph_card.setup(_echo_glyph)
	var sid: String = glyph.species.id if glyph.species else ""
	var sname: String = glyph.species.name if glyph.species else "???"
	_apply_lore(sid, sname)


func _apply_lore(species_id: String, species_name: String) -> void:
	var lore: Dictionary = ECHO_LORE.get(species_id, {})
	var encounter_text: String = lore.get("encounter", "")
	if encounter_text.is_empty():
		_description_label.text = "A ghostly echo of %s shimmers before you..." % species_name
	else:
		_description_label.text = encounter_text
	_lore_label.visible = false


func get_memory_fragment() -> String:
	## Returns the memory fragment text for the current echo (shown after victory)
	if _echo_glyph == null or _echo_glyph.species == null:
		return ""
	var lore: Dictionary = ECHO_LORE.get(_echo_glyph.species.id, {})
	return lore.get("fragment", "")


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
	_description_label.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(_description_label)

	_lore_label = Label.new()
	_lore_label.add_theme_font_size_override("font_size", 12)
	_lore_label.add_theme_color_override("font_color", Color("#AACCFF"))
	_lore_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_lore_label.add_theme_constant_override("outline_size", 2)
	_lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_label.custom_minimum_size = Vector2(400, 0)
	_lore_label.visible = false
	vbox.add_child(_lore_label)

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
	_challenge_btn.name = "ChallengeButton"
	_challenge_btn.text = "Challenge"
	_challenge_btn.custom_minimum_size = Vector2(120, 40)
	_challenge_btn.pressed.connect(_on_challenge)
	_button_row.add_child(_challenge_btn)

	_walk_past_btn = Button.new()
	_walk_past_btn.name = "WalkPastButton"
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
