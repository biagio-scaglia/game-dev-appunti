extends Control
## Le bugie, nel menu Stato: non un numero, un filo spinato con gli occhi infilati (vault:
## "Riferimenti e ispirazioni"). Ogni bugia apre un occhio rosso; gli altri sono chiusi, e
## aspettano. Ogni tanto uno sbatte, e gli occhi aperti guardano tutti dalla stessa parte:
## qualcuno ha visto.
##
## Disegnato qui, a blocchi di PX pixel.

const PX := 3
## Un occhio aperto, 9 x 7: O contorno, w bianco, r iride rossa, k pupilla, l ciglia.
const OPEN := [
	".l.l.l.l.",
	"..OOOOO..",
	".OwwrwwO.",
	"OwwrkrwwO",
	".OwwrwwO.",
	"..OOOOO..",
	".........",
]
## Chiuso: la palpebra curva in giù, con le ciglia (si vede che è un occhio che aspetta).
const CLOSED := [
	".........",
	".........",
	"O.......O",
	".OOOOOOO.",
	"..l.l.l..",
	".........",
	".........",
]
const COLORS := {"O": Color(0.1, 0.05, 0.1), "w": Color(0.9, 0.86, 0.86), "r": Color(0.8, 0.12, 0.2),
	"k": Color(0.05, 0.02, 0.04), "l": Color(0.1, 0.05, 0.1)}
const CLOSED_TINT := Color(0.7, 0.64, 0.78)
const WIRE := Color(0.45, 0.4, 0.5)
const BARB := Color(0.62, 0.56, 0.68)
## Il fondo della finestra del menu (dietro l'occhio chiuso il filo non si vede).
const GAP := Color(0.08, 0.06, 0.11)
## Quanti posti ci sono almeno sul filo (gli occhi chiusi aspettano), e al massimo.
const MIN_SLOTS := 6
const MAX_SLOTS := 12
const EYE_W := 9 * PX
const WIDTH := 300.0

## Quante bugie (occhi aperti).
var count := 0
var _time := 0.0
var _blinking := -1
var _blink_left := 0.0
var _next_blink := 2.0
var _look := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 7 * PX + 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(lies: int) -> void:
	count = maxi(0, lies)
	queue_redraw()


func slots() -> int:
	return clampi(count, MIN_SLOTS, MAX_SLOTS)


## Quanti occhi aperti si vedono (con più di MAX_SLOTS bugie, sono tutti aperti).
func open_eyes() -> int:
	return mini(count, slots())


func _process(delta: float) -> void:
	_time += delta
	_next_blink -= delta
	if _blinking >= 0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_blinking = -1
			queue_redraw()
	elif _next_blink <= 0.0 and open_eyes() > 0:
		_blinking = rng.randi() % open_eyes()
		_blink_left = 0.14
		_next_blink = rng.randf_range(1.2, 3.5)
		if rng.randf() < 0.4:
			_look = rng.randi_range(-1, 1)         # tutti insieme guardano altrove
		queue_redraw()


func _draw() -> void:
	var n := slots()
	var y := 3 * PX + 2
	draw_rect(Rect2(0, y, WIDTH, PX / 2.0 + 1), WIRE)          # il filo
	var step := (WIDTH - EYE_W) / maxf(1.0, n - 1)
	for i in range(0, int(WIDTH), 12):                         # le spine
		draw_rect(Rect2(i + 5, y - PX, PX / 2.0 + 1, PX), BARB)
		draw_rect(Rect2(i + 4, y + PX, PX / 2.0 + 1, PX), BARB)
	for i in n:
		var x := roundf(i * step)
		var open := i < open_eyes() and i != _blinking
		_draw_eye(Vector2(x, 2), open)


func _draw_eye(at: Vector2, open: bool) -> void:
	var rows: Array = OPEN if open else CLOSED
	if not open:                                     # il filo si interrompe: lì c'è un occhio
		draw_rect(Rect2(at + Vector2(0, 2 * PX), Vector2(9, 3) * PX), GAP)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			if c == ".":
				continue
			var col: Color = COLORS[c]
			var px := x
			if open and c in ["r", "k"]:
				px += _look                                   # guardano tutti dalla stessa parte
			if not open:
				col = CLOSED_TINT
			draw_rect(Rect2(at + Vector2(px, y) * PX, Vector2(PX, PX)), col)
