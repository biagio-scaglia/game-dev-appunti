extends Node2D
## Il riflesso della luna sul lago: una colonna di trattini di luce che tremolano,
## stretta all'orizzonte e larga verso chi guarda. L'origine del nodo è l'orizzonte,
## sotto la luna. `brightness` (0-1) dice quanto è accesa.

const GLADE_COLOR := Color(0.96, 0.9, 0.77)

@export var rows := 22
@export var row_gap := 3
## Mezza larghezza della colonna all'orizzonte e in fondo.
@export var near_half_width := 6.0
@export var far_half_width := 34.0

var brightness := 0.0
var _time := 0.0


## Porta la luminosità a `value` in `time` secondi.
func fade_to(value: float, time: float) -> Tween:
	var t := create_tween()
	t.tween_property(self, "brightness", value, time)
	return t


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for s in streaks(_time, brightness, rows, row_gap, near_half_width, far_half_width):
		draw_rect(s["rect"], Color(GLADE_COLOR, s["alpha"]))


## I trattini da disegnare in questo istante: [{rect, alpha}], a pixel interi.
## Due per riga; la loro larghezza e posizione ondeggiano col tempo.
static func streaks(time: float, bright: float, row_count: int, gap: int,
		half_near: float, half_far: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if bright <= 0.01:
		return out
	for r in row_count:
		var depth := float(r) / maxi(row_count - 1, 1)     # 0 = orizzonte, 1 = in fondo
		var half := lerpf(half_near, half_far, depth)
		var alpha := bright * lerpf(0.9, 0.3, depth)
		for k in 2:
			var w := maxf(2.0, roundf(half * (0.55 + 0.45 * sin(time * 2.3 + r * 1.7 + k * 2.1))))
			var x := roundf(sin(time * 1.3 + r * 0.9 + k * 3.0) * half * 0.5 - w / 2.0)
			out.append({"rect": Rect2(x, 2 + r * gap, w, 1), "alpha": alpha})
	return out
