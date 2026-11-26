extends RefCounted
## Le scritte e i neri dello schermo, in un posto solo (prima erano ricopiati in ogni scena):
## - label(): una scritta col font del gioco, centrata, con l'ombra;
## - black_layer(): un nero a tutto schermo su un CanvasLayer (per sfumare dentro e fuori);
## - centered_line(): una riga in mezzo allo schermo, su un layer ("Death is a lie.");
## - toast(): nome e riga in alto al centro, che compaiono e se ne vanno (il livello, la
##   stanza nuova del dungeon);
## - float_text(): una scritta piccola che sale da un punto del mondo e svanisce ("+3 EXP").
## Solo funzioni statiche: chi chiama le mette nel suo albero.

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const SCREEN := Vector2(640, 360)
const TOAST_TITLE := Color(1.0, 0.8, 0.9)
const TOAST_LINE := Color(0.8, 0.76, 0.92)


static func label(text: String, color: Color, font_size := 16) -> Label:
	var l := Label.new()
	l.text = text if text != "" else " "
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override(&"shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Un nero a tutto schermo su un layer nuovo dentro `parent` (alfa di partenza `alpha`).
static func black_layer(parent: Node, layer := 70, alpha := 0.0) -> ColorRect:
	var canvas := CanvasLayer.new()
	canvas.layer = layer
	parent.add_child(canvas)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, alpha)
	black.size = SCREEN
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(black)
	return black


## Una riga in mezzo allo schermo, trasparente (si fa comparire con un tween), sul layer di
## `black` (o su `canvas`).
static func centered_line(canvas: Node, text: String, color: Color) -> Label:
	var l := label(text, color)
	l.remove_theme_color_override(&"font_shadow_color")
	l.size = Vector2(SCREEN.x, 20)
	l.position = Vector2(0, 170)
	l.modulate.a = 0.0
	canvas.add_child(l)
	return l


## Nome e riga in alto al centro, che compaiono e se ne vanno.
static func toast(parent: Node, title: String, line: String) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 8                      # sotto il menu di pausa (10)
	parent.add_child(canvas)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 52)
	box.size = Vector2(SCREEN.x, 40)
	box.modulate.a = 0.0
	canvas.add_child(box)
	box.add_child(label(title, TOAST_TITLE))
	box.add_child(label(line, TOAST_LINE))
	var t := canvas.create_tween()
	t.tween_property(box, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(box, "position:y", 44.0, 0.3)
	t.tween_interval(1.8)
	t.tween_property(box, "modulate:a", 0.0, 0.6)
	t.tween_callback(canvas.queue_free)


## Una scritta piccola che sale da `at` (nel mondo) e svanisce.
static func float_text(parent: Node, at: Vector2, text: String, color: Color) -> Label:
	var l := label(text, color)
	l.add_theme_color_override(&"font_outline_color", Color(0.06, 0.03, 0.1))
	l.add_theme_constant_override(&"outline_size", 4)
	l.size = Vector2(80, 20)
	l.z_index = 20
	parent.add_child(l)
	l.global_position = at - Vector2(40, 10)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 16.0, 0.8).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)
	return l
