extends RefCounted
## Scintille di magia: quadratini da 2 pixel (la griglia degli sprite), blend additivo,
## dal viola chiaro al viola scuro trasparente. Due usi: la scia del proiettile e lo
## scoppio all'impatto.

const LIGHT := Color(0.84, 0.67, 1.0)
const DEEP := Color(0.46, 0.25, 0.81, 0.0)


## La scia: scintille lasciate nel mondo dietro il proiettile, che si spengono piano.
static func trail() -> CPUParticles2D:
	var p := _base()
	p.amount = 28
	p.lifetime = 0.4
	p.local_coords = false             # restano dove sono nate: disegnano la scia
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	return p


## Lo scoppio: tutte insieme, veloci, frenano e cadono un poco, poi si spengono.
static func burst(count := 16) -> CPUParticles2D:
	var p := _base()
	p.amount = count
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 110.0
	p.damping_min = 140.0
	p.damping_max = 180.0
	p.gravity = Vector2(0, 40)
	return p


static func _base() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.scale_amount_min = 2.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, LIGHT)
	ramp.set_color(1, DEEP)
	p.color_ramp = ramp
	return p
