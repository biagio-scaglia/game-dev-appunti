extends Node2D
## Il calendario della cutscene iniziale, da vicino: un foglio di un mese appeso al muro, al
## buio, nella luce fredda della luna. I giorni si barrano uno alla volta fino a quello
## cerchiato, poi niente. Disegnato in codice a blocchi di 2 pixel, come gli sprite.
##
## L'origine del nodo è l'angolo in alto a sinistra del foglio.

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")

## Il mese: 30 giorni, il primo cade di giovedì (colonna 3).
const DAYS := 30
const FIRST_COLUMN := 3
## Il giorno cerchiato: l'ultimo in cui Lethe è uscita (vault: "Trama - bozza").
const CIRCLED_DAY := 12

const CELL := Vector2(32, 26)
const COLUMNS := 7
const MARGIN := Vector2(8, 26)
const ROWS := 5
const PAPER_SIZE := Vector2(COLUMNS * 32 + 16, 26 + ROWS * 26 + 8)

const PAPER := Color(0.45, 0.46, 0.6)
const PAPER_EDGE := Color(0.3, 0.3, 0.42)
const RING := Color(0.2, 0.18, 0.26)
const GRID := Color(0.36, 0.36, 0.5)
const NUMBER := Color(0.22, 0.2, 0.3)
const INK := Color(0.5, 0.14, 0.2)
const CIRCLE := Color(0.72, 0.2, 0.28)
const WEEKDAYS := ["M", "T", "W", "T", "F", "S", "S"]

## Quanti giorni sono barrati (dall'1).
var crossed := 0:
	set(value):
		crossed = clampi(value, 0, DAYS)
		queue_redraw()
## Quanto del cerchio è disegnato, da 0 a 1.
var circle := 0.0:
	set(value):
		circle = clampf(value, 0.0, 1.0)
		queue_redraw()


## Il riquadro del giorno `day` (1-30), rispetto al foglio.
static func cell_rect(day: int) -> Rect2:
	var index := day - 1 + FIRST_COLUMN
	var pos := MARGIN + Vector2(index % COLUMNS, index / COLUMNS) * CELL
	return Rect2(pos, CELL)


## I blocchi di una X dentro `rect` (due diagonali a gradini da 2 pixel).
static func cross_blocks(rect: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var inner := rect.grow(-5)
	var steps := int(inner.size.x / 2.0)
	for i in steps:
		var y := floorf(i * (inner.size.y - 2) / (steps - 1) / 2.0) * 2.0
		out.append(inner.position + Vector2(i * 2, y))
		out.append(inner.position + Vector2(inner.size.x - 2 - i * 2, y))
	return out


## I blocchi di un cerchio (un'ellisse un po' storta, fatta a mano) intorno a `rect`, fino a
## `amount` (0-1) del giro.
static func circle_blocks(rect: Rect2, amount: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var center := rect.get_center()
	var radius := rect.size / 2.0 + Vector2(2, 1)
	var count := int(48 * amount)
	for i in count:
		var a := -PI * 0.6 + TAU * 1.08 * i / 48.0        # chi cerchia a mano va un po' oltre
		var r := radius * (1.0 + 0.06 * sin(a * 3.0))
		var p := center + Vector2(cos(a) * r.x, sin(a) * r.y)
		var snapped := (p / 2.0).floor() * 2.0
		if out.is_empty() or out[-1] != snapped:
			out.append(snapped)
	return out


func _draw() -> void:
	# Il foglio, con l'orlo più scuro e gli anelli della spirale in cima.
	draw_rect(Rect2(Vector2(2, 2), PAPER_SIZE), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(Vector2.ZERO, PAPER_SIZE), PAPER_EDGE)
	draw_rect(Rect2(Vector2(2, 2), PAPER_SIZE - Vector2(4, 4)), PAPER)
	for i in 8:
		draw_rect(Rect2(Vector2(16 + i * 28, -4), Vector2(4, 8)), RING)
	for c in COLUMNS:
		draw_string(FONT, MARGIN + Vector2(c * CELL.x + 12, -6), WEEKDAYS[c],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NUMBER)
	for day in range(1, DAYS + 1):
		var rect := cell_rect(day)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), GRID)
		draw_string(FONT, rect.position + Vector2(4, 14), str(day),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NUMBER)
	for day in range(1, crossed + 1):
		for b in cross_blocks(cell_rect(day)):
			draw_rect(Rect2(b, Vector2(2, 2)), INK)
	for b in circle_blocks(cell_rect(CIRCLED_DAY), circle):
		draw_rect(Rect2(b, Vector2(2, 2)), CIRCLE)
