extends Label
## Il numero del danno che salta fuori da un nemico colpito: sale un po' di lato, si
## ferma, svanisce. Rosa quando l'arma è quella giusta (debolezza), grigio quando gli fa
## poco, bianco altrimenti. Il font pixel del gioco, col bordo scuro.
##
## Uso: DamageNumber.spawn(parent, posizione, danno, quanto è efficace: 1.5, 1, 0.5)

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const STRONG := Color(1.0, 0.55, 0.72)
const NORMAL := Color(0.96, 0.94, 1.0)
const WEAK := Color(0.62, 0.6, 0.7)
const RISE := 18.0
const TIME := 0.7


static func color_for(multiplier: float) -> Color:
	if multiplier > 1.0:
		return STRONG
	if multiplier < 1.0:
		return WEAK
	return NORMAL


static func spawn(parent: Node, at: Vector2, amount: int, multiplier := 1.0) -> Label:
	var label: Label = load("res://fx/damage_number.gd").new()
	label.text = str(amount)
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", 16 if multiplier <= 1.0 else 32)
	label.add_theme_color_override(&"font_color", color_for(multiplier))
	label.add_theme_color_override(&"font_outline_color", Color(0.06, 0.03, 0.1))
	label.add_theme_constant_override(&"outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 34)
	label.z_index = 20
	parent.add_child(label)
	label.global_position = at - Vector2(20, 30)
	var drift := randf_range(-8.0, 8.0)
	var t := label.create_tween().set_parallel()
	t.tween_property(label, "position", label.position + Vector2(drift, -RISE), TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, TIME * 0.4).set_delay(TIME * 0.6)
	t.chain().tween_callback(label.queue_free)
	return label
