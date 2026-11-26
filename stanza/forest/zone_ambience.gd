extends Node
## L'aria sottoterra (forest_zone.gd lo monta come "Ambience" nei posti a stanze): non fa
## niente al gioco, fa sentire dove si è.
## - La polvere: granelli che galleggiano piano nell'aria davanti alla camera (prendono quella
##   poca luce che c'è).
## - Le gocce: ogni tanto, da qualche parte nello schermo, una goccia cade dal buio, fa un
##   anello per terra e il suo plip con l'eco della grotta.
## - Le radici: più di rado, lontano, una radice si assesta (scricchiola) e dall'alto cade un
##   filo di terra.
## I suoni sono posizionali (si sentono da dove vengono) e piano.

const DRIP := preload("res://audio/water_drip.wav")
const CREAK := preload("res://audio/root_creak.wav")

## Ogni quanto (secondi, a caso tra i due) una goccia, e una radice.
const DRIP_EVERY := Vector2(1.8, 4.5)
const CREAK_EVERY := Vector2(9.0, 18.0)
## Mezzo schermo (pixel del mondo): dove possono succedere le cose.
const VIEW := Vector2(300, 160)


## Una goccia: cade da `fall` pixel sopra, poi l'anello per terra che si allarga e sparisce.
class Drip extends Node2D:
	var fall := 60.0
	var _t := 0.0
	const FALL_TIME := 0.45
	const RING_TIME := 0.5

	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t > FALL_TIME + RING_TIME:
			queue_free()

	func _draw() -> void:
		var col := Color(0.62, 0.7, 0.9, 0.55)
		if _t < FALL_TIME:
			var k := _t / FALL_TIME
			var y := -fall * (1.0 - k * k)
			draw_rect(Rect2(Vector2(-1, y - 3), Vector2(2, 3)), col)
			return
		var r := (_t - FALL_TIME) / RING_TIME
		col.a *= 1.0 - r
		var w := 3.0 + 9.0 * r
		var h := 1.0 + 3.0 * r
		for a in range(0, 360, 30):                     # l'anello schiacciato, a pixel
			var p := Vector2(cos(deg_to_rad(a)) * w, sin(deg_to_rad(a)) * h).round()
			draw_rect(Rect2(p, Vector2(2, 1)), col)


var zone: Node2D
var dust: CPUParticles2D
var _drip_wait := 1.0
var _creak_wait := 6.0


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	dust = _make_dust()
	zone.camera.add_child(dust)                         # segue la camera; i granelli restano nel mondo
	_drip_wait = randf_range(DRIP_EVERY.x, DRIP_EVERY.y)
	_creak_wait = randf_range(CREAK_EVERY.x, CREAK_EVERY.y)


func _process(delta: float) -> void:
	_drip_wait -= delta
	if _drip_wait <= 0.0:
		_drip_wait = randf_range(DRIP_EVERY.x, DRIP_EVERY.y)
		drip(_random_spot())
	_creak_wait -= delta
	if _creak_wait <= 0.0:
		_creak_wait = randf_range(CREAK_EVERY.x, CREAK_EVERY.y)
		creak(_random_spot())


## Una goccia che cade e tocca terra in `at` (pixel del mondo).
func drip(at: Vector2) -> Node2D:
	var d := Drip.new()
	d.fall = randf_range(40.0, 90.0)
	d.position = at
	d.z_index = 1
	zone.add_child(d)
	if zone.sound:
		var timer := get_tree().create_timer(Drip.FALL_TIME)
		timer.timeout.connect(func() -> void: _play_at(DRIP, at, randf_range(0.8, 1.25), -12.0))
	return d


## Una radice che scricchiola lontano, e la terra che cade dall'alto in `at`.
func creak(at: Vector2) -> void:
	if zone.sound:
		_play_at(CREAK, at, randf_range(0.7, 1.05), -14.0)
	var dirt := CPUParticles2D.new()
	dirt.amount = 10
	dirt.lifetime = 0.9
	dirt.one_shot = true
	dirt.explosiveness = 0.6
	dirt.local_coords = false
	dirt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dirt.emission_rect_extents = Vector2(6, 1)
	dirt.direction = Vector2.DOWN
	dirt.spread = 10.0
	dirt.gravity = Vector2(0, 260)
	dirt.initial_velocity_min = 5.0
	dirt.initial_velocity_max = 20.0
	dirt.color = Color(0.36, 0.28, 0.3)
	dirt.position = at + Vector2(0, -80)
	zone.add_child(dirt)
	dirt.emitting = true
	dirt.finished.connect(dirt.queue_free)


func _random_spot() -> Vector2:
	var center: Vector2 = zone.camera.get_screen_center_position()
	return center + Vector2(randf_range(-VIEW.x, VIEW.x), randf_range(-VIEW.y * 0.4, VIEW.y))


func _play_at(stream: AudioStream, at: Vector2, pitch: float, db: float) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = db
	player.max_distance = 700.0
	player.position = at
	zone.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 36
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(340, 200)
	p.direction = Vector2(1, -0.3)
	p.spread = 180.0
	p.gravity = Vector2(0, 1.5)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 5.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(0.8, 0.76, 0.9, 0.0), Color(0.8, 0.76, 0.9, 0.22),
		Color(0.8, 0.76, 0.9, 0.22), Color(0.8, 0.76, 0.9, 0.0)])
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	p.z_index = 3
	return p
