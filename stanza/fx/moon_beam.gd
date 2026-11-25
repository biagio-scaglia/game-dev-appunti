extends Node2D
## Il raggio di luna: da uno spiraglio (le tende della stanza, le chiome nel bosco) scende
## in diagonale fino a terra, in blend additivo. Non è una lastra piatta:
## - sfuma: quasi niente in cima, pieno a metà, un po' meno a terra;
## - ha un nucleo più chiaro nel mezzo e i bordi più tenui (tre fasce);
## - respira piano (la luce che passa tra le foglie cambia);
## - il pulviscolo ci fluttua dentro, qualche granello luccica;
## - con `pool` dove arriva c'è una pozza di luce: ellissi a gradini sul prato e una luce
##   vera (PointLight2D) che schiarisce erba e cose sotto il buio della notte.
## L'origine del nodo è lo spiraglio.

const Glow := preload("res://core/glow.gd")

@export var length := 200.0
@export var top_width := 6.0
@export var bottom_width := 70.0
@export var slant := 50.0            # di quanto il fondo del raggio va a destra
@export var color := Color(0.65, 0.75, 1.0, 0.07)
@export var dust_amount := 26
## La pozza di luce a terra (nel bosco sì; nella stanza il raggio cade sul pavimento e basta).
@export var pool := false
@export var pool_energy := 0.55
## Quanto respira (0 = fermo) e in quanti secondi.
@export var breath := 0.18
@export var breath_period := 5.0
## Dove il raggio è già pieno (frazione della lunghezza): sopra sfuma verso lo spiraglio.
## Nel bosco il raggio parte da sopra la mappa: sfuma solo nel pezzo che non si vede.
@export var fade_until := 0.45
## Vero: il buio della notte (CanvasModulate) non lo spegne. È luce, deve vedersi anche
## sopra le chiome scure.
@export var unshaded := false

var dust: CPUParticles2D
var light: PointLight2D
var _time := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if unshaded:
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	z_index = 1
	_time = fmod(position.x * 0.37, breath_period)   # i raggi vicini non respirano insieme
	dust = _make_dust()
	add_child(dust)
	if pool:
		light = Glow.light(Color(color.r, color.g, color.b), pool_energy, bottom_width * 0.9)
		light.position = foot()
		light.scale = Vector2(1.0, 0.55)               # schiacciata: è per terra
		add_child(light)


## Il trapezio intero (dallo spiraglio a terra).
func polygon() -> PackedVector2Array:
	return _band(1.0)


## Dove il raggio tocca terra.
func foot() -> Vector2:
	return Vector2(slant, length)


func _process(delta: float) -> void:
	if breath <= 0.0:
		return
	_time += delta
	var k := 1.0 + breath * sin(_time / breath_period * TAU)
	modulate.a = k
	if light:
		light.energy = pool_energy * k


## Il trapezio stretto a `k` della larghezza (1 = tutto il raggio).
func _band(k: float) -> PackedVector2Array:
	var top := top_width * k / 2.0
	var bottom := bottom_width * k / 2.0
	return PackedVector2Array([
		Vector2(-top, 0), Vector2(top, 0),
		Vector2(slant + bottom, length), Vector2(slant - bottom, length),
	])


func _draw() -> void:
	# Tre fasce una dentro l'altra: i bordi tenui, il nucleo più chiaro.
	for band in [[1.0, 0.7], [0.62, 0.55], [0.28, 0.6]]:
		_draw_faded(_band(band[0]), color.a * band[1])
	if pool:
		# La pozza: ellissi a gradini (pixel), più chiare al centro.
		var f := foot()
		for step in [[1.0, 0.5], [0.7, 0.6], [0.4, 0.7]]:
			_ellipse(f, Vector2(bottom_width * 0.65, bottom_width * 0.2) * step[0], color.a * step[1])


## Un trapezio che sfuma dall'alto: niente allo spiraglio, pieno a `fade_until`, 70% a terra.
func _draw_faded(quad: PackedVector2Array, alpha: float) -> void:
	var mid_l := quad[0].lerp(quad[3], fade_until)
	var mid_r := quad[1].lerp(quad[2], fade_until)
	var c := Color(color.r, color.g, color.b)
	var top := Color(c, 0.0)
	var full := Color(c, alpha)
	var low := Color(c, alpha * 0.7)
	draw_polygon(PackedVector2Array([quad[0], quad[1], mid_r, mid_l]),
		PackedColorArray([top, top, full, full]))
	draw_polygon(PackedVector2Array([mid_l, mid_r, quad[2], quad[3]]),
		PackedColorArray([full, full, low, low]))


func _ellipse(center: Vector2, radius: Vector2, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append((center + Vector2(cos(a) * radius.x, sin(a) * radius.y)).round())
	draw_colored_polygon(points, Color(color.r, color.g, color.b, alpha))


func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = dust_amount
	p.lifetime = 6.0
	p.preprocess = 6.0                         # già pieno di pulviscolo all'avvio
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = Vector2(slant * 0.55, length * 0.55)
	p.emission_rect_extents = Vector2(bottom_width / 3.0, length / 2.5)
	p.direction = Vector2(0.3, 1)
	p.spread = 60.0
	p.gravity = Vector2(0, 2)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	# Ogni granello si accende e si spegne due volte: luccica, non è un puntino fisso.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.9, 1.0, 0.0))
	ramp.add_point(0.25, Color(0.9, 0.95, 1.0, 0.75))
	ramp.add_point(0.4, Color(0.85, 0.9, 1.0, 0.3))
	ramp.add_point(0.6, Color(0.95, 0.97, 1.0, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.9, 1.0, 0.0))
	p.color_ramp = ramp
	p.material = material
	return p
