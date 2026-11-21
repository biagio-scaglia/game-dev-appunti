extends Node2D
## Il raggio di luna: dallo spiraglio tra le tende scende in diagonale fino al
## pavimento, appena visibile (blend additivo), con il pulviscolo che ci fluttua dentro.
## L'origine del nodo è lo spiraglio.

@export var length := 200.0
@export var top_width := 6.0
@export var bottom_width := 70.0
@export var slant := 50.0            # di quanto il fondo del raggio va a destra
@export var color := Color(0.65, 0.75, 1.0, 0.07)
@export var dust_amount := 26

var dust: CPUParticles2D


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 1
	dust = _make_dust()
	add_child(dust)


func polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-top_width / 2.0, 0), Vector2(top_width / 2.0, 0),
		Vector2(slant + bottom_width / 2.0, length), Vector2(slant - bottom_width / 2.0, length),
	])


func _draw() -> void:
	draw_colored_polygon(polygon(), color)


func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = dust_amount
	p.lifetime = 6.0
	p.preprocess = 6.0                         # già pieno di pulviscolo all'avvio
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = Vector2(slant / 2.0, length / 2.0)
	p.emission_rect_extents = Vector2(bottom_width / 3.0, length / 2.5)
	p.direction = Vector2(0.3, 1)
	p.spread = 60.0
	p.gravity = Vector2(0, 2)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.9, 1.0, 0.0))
	ramp.add_point(0.3, Color(0.85, 0.9, 1.0, 0.55))
	ramp.add_point(0.7, Color(0.85, 0.9, 1.0, 0.45))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.9, 1.0, 0.0))
	p.color_ramp = ramp
	p.material = material
	return p
