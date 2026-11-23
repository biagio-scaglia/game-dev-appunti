extends Control
## Una barra come in RPG Maker: la sigla a sinistra, i numeri a destra, sotto la barra.
## A blocchi di 2 pixel come gli sprite. `unknown`: numeri "??" e barra vuota.

const Style := preload("menu_style.gd")
const BAR_Y := 14.0
const BAR_H := 4.0

var caption := "HP":
	set(v): caption = v; queue_redraw()
var value := 0:
	set(v): value = v; queue_redraw()
var max_value := 1:
	set(v): max_value = v; queue_redraw()
var color := Style.HP_COLOR:
	set(v): color = v; queue_redraw()
var unknown := false:
	set(v): unknown = v; queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(120, 20)


## Il testo dei numeri, come si vede (pubblico per i test).
func numbers() -> String:
	return "??/??" if unknown else "%d/%d" % [value, max_value]


func fill() -> float:
	return 0.0 if unknown or max_value <= 0 else clampf(float(value) / max_value, 0.0, 1.0)


func _draw() -> void:
	var font := Style.FONT
	var size_px := Style.FONT_SIZE
	draw_string(font, Vector2(0, 11), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Style.ACCENT)
	draw_string(font, Vector2(0, 11), numbers(), HORIZONTAL_ALIGNMENT_RIGHT, size.x, size_px, Style.TEXT)
	draw_rect(Rect2(0, BAR_Y, size.x, BAR_H), Color(0.05, 0.03, 0.09))
	var width := floorf(size.x * fill() / 2.0) * 2.0
	if width > 0.0:
		draw_rect(Rect2(0, BAR_Y, width, BAR_H), color)
		draw_rect(Rect2(0, BAR_Y, width, 2), color.lightened(0.3))
