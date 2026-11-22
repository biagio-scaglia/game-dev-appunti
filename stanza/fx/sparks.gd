extends RefCounted
## Scintille di magia e schegge di vetro: quadratini da 2 pixel (la griglia degli sprite).
## Le scintille (blend additivo, dal viola chiaro al viola scuro trasparente) fanno la scia
## del proiettile e lo scoppio all'impatto; le schegge (vetro azzurro, blend normale:
## il vetro non è luce) cadono dalla spada.

const LIGHT := Color(0.84, 0.67, 1.0)
const DEEP := Color(0.46, 0.25, 0.81, 0.0)
const GLASS_LIGHT := Color(0.92, 0.97, 1.0)
const GLASS_DARK := Color(0.5, 0.63, 0.86, 0.0)


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


## Le schegge della spada: saltano via, cadono a terra e si spengono.
static func shards(count := 8) -> CPUParticles2D:
	var p := _base()
	p.material = null                      # vetro, non luce: blend normale
	p.amount = count
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, 320)
	var ramp := Gradient.new()
	ramp.set_color(0, GLASS_LIGHT)
	ramp.set_color(1, GLASS_DARK)
	p.color_ramp = ramp
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
