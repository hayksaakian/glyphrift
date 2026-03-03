class_name DamageNumber
extends Label

## Floating damage label — tweens up + fades over 0.8s, then queue_free().
## Red = damage, Green = heal, Cyan = shield.

const COLOR_DAMAGE: Color = Color("#FF4444")
const COLOR_HEAL: Color = Color("#44FF44")
const COLOR_SHIELD: Color = Color("#00DDDD")
const COLOR_BURN: Color = Color("#FF8800")


func show_damage(value: int, type: String = "damage") -> void:
	text = str(value)
	match type:
		"heal":
			text = "+" + str(value)
			add_theme_color_override("font_color", COLOR_HEAL)
		"shield":
			text = "Shield!"
			add_theme_color_override("font_color", COLOR_SHIELD)
		"burn":
			text = str(value)
			add_theme_color_override("font_color", COLOR_BURN)
		_:
			text = str(value)
			add_theme_color_override("font_color", COLOR_DAMAGE)

	add_theme_font_size_override("font_size", 18)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 40.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
