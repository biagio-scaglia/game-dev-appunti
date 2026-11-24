extends Node2D
## Lo sfondo del titolo: il buio della stanza, un raggio di luna in diagonale (lo
## stesso spiraglio tra le tende che c'è nel gioco) e il pulviscolo che ci sale piano.
## Tutto a blocchi di `pixel`, come gli sprite.

@export var size := Vector2(640, 360)
@export var pixel := 2
@export var beam_color := Color(0.62, 0.7, 1.0, 0.06)
@export var mote_color := Color(0.8, 0.82, 1.0)
@export var mote_count := 40
## Seme fisso: il pulviscolo parte sempre uguale (utile per screenshot e test).
@export var mote_seed := 7

var motes: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mote_seed
	for i in mote_count:
		motes.append({
			"pos": Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y)),
			"speed": rng.randf_range(3.0, 9.0),
			"phase": rng.randf_range(0, TAU),
		})


func _process(delta: float) -> void:
	_time += delta
	for m in motes:
		m["pos"] = step_mote(m["pos"], m["speed"], m["phase"], _time, delta, size)
	queue_redraw()


## Un passo di un granello: sale piano, ondeggia di lato, rientra dal basso.
static func step_mote(pos: Vector2, speed: float, phase: float, time: float, delta: float, area: Vector2) -> Vector2:
	pos.y -= speed * delta
	pos.x += sin(time * 0.7 + phase) * 4.0 * delta
	if pos.y < -4.0:
		pos.y = area.y + 4.0
	return pos


## Il raggio: un trapezio dallo spiraglio in alto fino a terra, in diagonale, dove sta Lethe
## davanti alla porta.
## `spread` lo allarga (l'alone intorno al nucleo).
func beam_polygon(spread := 0.0) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(size.x * (0.30 - spread * 0.3), 0), Vector2(size.x * (0.34 + spread * 0.3), 0),
		Vector2(size.x * (0.88 + spread), size.y), Vector2(size.x * (0.72 - spread), size.y),
	])


## Le nuvole che passano davanti alla luna: il raggio cala e risale piano (0.55 - 1).
static func cloud_light(time: float) -> float:
	var v := 0.5 + 0.25 * sin(time * 0.31) + 0.25 * sin(time * 0.53 + 1.7)
	return 0.55 + 0.45 * v


## Quanto brilla un granello ora (tremola), da 0 a 1.
static func twinkle(phase: float, time: float) -> float:
	return 0.35 + 0.35 * (0.5 + 0.5 * sin(time * 1.8 + phase * 3.0))


func _draw() -> void:
	var light := cloud_light(_time)
	var halo := beam_color
	halo.a *= 0.45 * light
	draw_colored_polygon(beam_polygon(0.05), halo)
	var core := beam_color
	core.a *= light
	draw_colored_polygon(beam_polygon(), core)
	for m in motes:
		var p: Vector2 = (m["pos"] / pixel).floor() * pixel
		var c := mote_color
		c.a = twinkle(m["phase"], _time)
		draw_rect(Rect2(p, Vector2(pixel, pixel)), c)
