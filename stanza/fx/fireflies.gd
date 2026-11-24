extends CPUParticles2D
## Le lucciole: puntini caldi che vagano piano e si accendono e spengono. Blend additivo,
## a blocchi di 2 pixel. Si mettono a gruppi nel bosco (una nuvola per nodo).


func _init() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	amount = 7
	lifetime = 5.0
	preprocess = 5.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 60.0
	direction = Vector2.UP
	spread = 180.0
	gravity = Vector2.ZERO
	initial_velocity_min = 3.0
	initial_velocity_max = 9.0
	orbit_velocity_min = -0.04
	orbit_velocity_max = 0.04
	scale_amount_min = 2.0
	scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6, 0.0))
	ramp.set_color(1, Color(0.8, 1.0, 0.5, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.95, 0.55, 0.9))
	ramp.add_point(0.5, Color(0.9, 1.0, 0.5, 0.2))
	ramp.add_point(0.75, Color(0.9, 1.0, 0.5, 0.85))
	color_ramp = ramp
