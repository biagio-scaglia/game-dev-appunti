extends CanvasLayer
## La vita di un boss, in basso al centro (sopra il riquadro dei dialoghi non serve: durante
## i dialoghi si nasconde). Il nome in alto, la barra a blocchi di 2 pixel come i cuori:
## - un colpo: la barra sobbalza, il pezzo perso resta bianco un attimo e poi scende piano
##   (si vede quanto ha fatto male);
## - la seconda fase: il bordo si accende di viola e resta.
## Entra e esce sfumando (appear / disappear).

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const WIDTH := 200.0
const HEIGHT := 6.0
const MARGIN_BOTTOM := 30.0
const FILL := Color(0.92, 0.42, 0.55)
const TRAIL := Color(1.0, 0.95, 0.96)
const BACK := Color(0.07, 0.04, 0.1, 0.9)
const EDGE := Color(0.32, 0.24, 0.38)
const EDGE_HOT := Color(0.7, 0.5, 1.0)


class Bar extends Node2D:
	const WIDTH := 200.0
	const HEIGHT := 6.0
	const FILL := Color(0.92, 0.42, 0.55)
	const TRAIL := Color(1.0, 0.95, 0.96)
	const BACK := Color(0.07, 0.04, 0.1, 0.9)
	const EDGE := Color(0.32, 0.24, 0.38)
	const EDGE_HOT := Color(0.7, 0.5, 1.0)
	var owner_bar: CanvasLayer

	func _draw() -> void:
		var b := owner_bar
		var left := Vector2(-WIDTH / 2.0, 0)
		var edge: Color = EDGE_HOT if b.phase2 else EDGE
		draw_rect(Rect2(left - Vector2(4, 4), Vector2(WIDTH + 8, HEIGHT + 8)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(left - Vector2(2, 2), Vector2(WIDTH + 4, HEIGHT + 4)), edge)
		draw_rect(Rect2(left, Vector2(WIDTH, HEIGHT)), BACK)
		var trail := floorf(WIDTH * b.trail / 2.0) * 2.0
		var fill := floorf(WIDTH * b.ratio / 2.0) * 2.0
		draw_rect(Rect2(left, Vector2(trail, HEIGHT)), TRAIL)
		draw_rect(Rect2(left, Vector2(fill, HEIGHT)), FILL)
		draw_rect(Rect2(left, Vector2(fill, 2)), FILL.lightened(0.35))     # la luce sopra


var ratio := 1.0
var trail := 1.0
var phase2 := false
var root_node: Control
var bar: Bar
var title: Label
var _trail_wait := 0.0


func _init() -> void:
	layer = 6


func _ready() -> void:
	root_node = Control.new()
	root_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_node.modulate.a = 0.0
	add_child(root_node)
	title = Label.new()
	title.add_theme_font_override(&"font", FONT)
	title.add_theme_font_size_override(&"font_size", 16)
	title.add_theme_color_override(&"font_color", Color(0.93, 0.9, 0.96))
	title.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override(&"shadow_offset_y", 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(640, 20)
	title.position = Vector2(0, 360 - MARGIN_BOTTOM - 22)
	root_node.add_child(title)
	bar = Bar.new()
	bar.owner_bar = self
	bar.position = Vector2(320, 360 - MARGIN_BOTTOM)
	root_node.add_child(bar)


func appear(boss_name: String) -> void:
	title.text = boss_name
	ratio = 1.0
	trail = 1.0
	phase2 = false
	bar.queue_redraw()
	create_tween().tween_property(root_node, "modulate:a", 1.0, 0.6)


func disappear() -> void:
	create_tween().tween_property(root_node, "modulate:a", 0.0, 0.8)


func is_shown() -> bool:
	return root_node.modulate.a > 0.0


## La vita cambia (`now` su `total`): la barra scende subito, la scia bianca dopo.
func set_life(now: int, total: int) -> void:
	var next := clampf(float(now) / maxf(1.0, total), 0.0, 1.0)
	if next < ratio:
		_trail_wait = 0.35
		var t := create_tween()
		for dx in [-3.0, 3.0, -1.0, 0.0]:
			t.tween_property(bar, "position:x", 320.0 + dx, 0.04)
	ratio = next
	bar.queue_redraw()


func set_phase2() -> void:
	phase2 = true
	bar.queue_redraw()


func _process(delta: float) -> void:
	if trail > ratio:
		_trail_wait -= delta
		if _trail_wait <= 0.0:
			trail = move_toward(trail, ratio, delta * 0.6)
			bar.queue_redraw()
	elif trail < ratio:
		trail = ratio
