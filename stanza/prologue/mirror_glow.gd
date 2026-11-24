extends Node2D
## Lo specchio che chiama: l'angolo scoperto del vetro (in basso a destra, sotto il
## lenzuolo) brilla di una luce fredda che non viene dalla stanza. Con `intensity` (0-1)
## crescono insieme: il vetro acceso, la luce sulla stanza, le scintille che salgono piano
## dall'angolo, il ronzio di vetro (più forte da vicino). Con `crack` (0-1) le crepe corrono
## dall'angolo su tutto lo specchio: è la caduta.
##
## L'origine del nodo è al centro dell'angolo scoperto. Tutto a blocchi di 2 pixel.

const Glow := preload("res://core/glow.gd")
const HUM := preload("res://audio/mirror_hum.wav")

## Il vetro scoperto, rispetto all'origine (6 x 8 pixel nel disegno dello specchio).
const GLASS := Rect2(-3, -4, 6, 8)
## Lo specchio intero sotto il lenzuolo, rispetto all'origine (per le crepe).
const MIRROR := Rect2(-19, -46, 22, 50)
const COLD := Color(0.62, 0.82, 1.0)
const WHITE := Color(0.92, 0.97, 1.0)
const LIGHT_RADIUS := Vector2(20.0, 90.0)       # da spento a pieno
const LIGHT_ENERGY := Vector2(0.2, 0.9)
const HUM_DB := Vector2(-34.0, -8.0)
## Le crepe: [angolo in gradi, lunghezza in pixel] dall'angolo verso il resto del vetro.
const CRACKS := [[-100.0, 44.0], [-125.0, 38.0], [-150.0, 22.0], [-80.0, 30.0], [-170.0, 16.0],
	[-60.0, 12.0], [160.0, 10.0]]

var intensity := 0.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		_apply()
var crack := 0.0:
	set(value):
		crack = clampf(value, 0.0, 1.0)
		queue_redraw()
## Falso nei test: niente ronzio.
var sound := true

var light: PointLight2D
var motes: CPUParticles2D
var hum: AudioStreamPlayer2D
var _time := 0.0


func _ready() -> void:
	light = Glow.light(COLD, 0.0, LIGHT_RADIUS.x)
	add_child(light)
	motes = _motes()
	add_child(motes)
	hum = AudioStreamPlayer2D.new()
	hum.stream = HUM
	hum.max_distance = 700.0
	hum.attenuation = 1.6
	add_child(hum)
	var stream := HUM as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_apply()


## Il vetro pulsa piano (più veloce quando chiama forte), da 0.7 a 1.
static func pulse(time: float, amount: float) -> float:
	return 0.85 + 0.15 * sin(time * (1.4 + amount * 2.2))


## I blocchi di una crepa: dall'origine verso `angle` (gradi), lunga `length`, a zig-zag.
static func crack_blocks(angle: float, length: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var side := dir.orthogonal()
	var steps := int(length / 2.0)
	for i in steps:
		var wobble := side * (2.0 if (i / 3) % 2 == 0 else -2.0) * minf(1.0, i / 4.0)
		var p := (dir * i * 2.0 + wobble) / 2.0
		out.append(p.floor() * 2.0)
	return out


func _process(delta: float) -> void:
	_time += delta
	if intensity > 0.0 or crack > 0.0:
		light.energy = lerpf(LIGHT_ENERGY.x, LIGHT_ENERGY.y, intensity) * pulse(_time, intensity)
		queue_redraw()


func _apply() -> void:
	if not is_node_ready():
		return
	visible = intensity > 0.0 or crack > 0.0
	light.texture_scale = lerpf(LIGHT_RADIUS.x, LIGHT_RADIUS.y, intensity) / (Glow.TEXTURE_SIZE / 2.0)
	light.energy = lerpf(LIGHT_ENERGY.x, LIGHT_ENERGY.y, intensity)
	motes.emitting = intensity > 0.0
	motes.amount = 6 + int(intensity * 18)
	hum.volume_db = lerpf(HUM_DB.x, HUM_DB.y, intensity)
	if sound and intensity > 0.0 and not hum.playing:
		hum.play()
	elif intensity <= 0.0:
		hum.stop()


func _draw() -> void:
	if intensity <= 0.0 and crack <= 0.0:
		return
	var p := pulse(_time, intensity)
	# Il vetro scoperto, acceso; un alone di un blocco intorno, più debole.
	draw_rect(GLASS.grow(2), Color(COLD, 0.25 * intensity * p))
	draw_rect(GLASS, Color(COLD.lerp(WHITE, intensity * 0.6), (0.5 + 0.5 * intensity) * p))
	draw_rect(Rect2(GLASS.position + Vector2(2, 2), Vector2(2, 2)), Color(WHITE, p))
	# Le crepe, che si allungano con `crack`.
	if crack <= 0.0:
		return
	for c in CRACKS:
		var blocks := crack_blocks(c[0], c[1])
		var shown := int(blocks.size() * crack)
		for i in shown:
			if MIRROR.has_point(blocks[i]):
				draw_rect(Rect2(blocks[i], Vector2(2, 2)), Color(WHITE, 0.9))


func _motes() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.amount = 6
	p.lifetime = 2.4
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(3, 4)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(WHITE, 0.0))
	ramp.set_color(1, Color(COLD, 0.0))
	ramp.add_point(0.2, Color(COLD, 0.9))
	p.color_ramp = ramp
	return p
