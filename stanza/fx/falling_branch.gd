extends Node2D
## Un ramo secco che cade dal buio (il Cervo Secco si ferma e la terra trema): prima l'ombra
## per terra che si allarga e un filo di polvere che scende (si vede dove), poi il ramo che
## precipita, si spezza a terra con le schegge e fa male a chi c'è sotto (`target`). Resta un
## po' per terra spezzato, poi sparisce. L'origine è il punto dove cade.

signal landed(hit: bool)

const SHEET := preload("res://enemies/sprites/falling_branch.png")
const Sfx := preload("res://core/sfx.gd")
const SNAP := preload("res://audio/branch_snap.wav")
const LAND := preload("res://audio/branch_land.wav")

## Quanto si vede l'ombra prima che arrivi, quanto ci mette a cadere, quanto resta a terra.
const WARN := 0.75
const FALL := 0.18
const LIE := 1.6
const HEIGHT := 190.0
## Fin dove fa male, dal punto dove cade.
const RADIUS := 20.0

var target: Node2D
var sound := true
var _t := 0.0
var _landed := false
var _sprite: Sprite2D


func _ready() -> void:
	z_index = 0
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = 2
	_sprite.offset = Vector2(0, -SHEET.get_height() / 2.0 + 4)
	_sprite.visible = false
	add_child(_sprite)
	var dust := CPUParticles2D.new()
	dust.amount = 8
	dust.lifetime = WARN
	dust.one_shot = true
	dust.explosiveness = 0.2
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(5, 1)
	dust.direction = Vector2.DOWN
	dust.spread = 5.0
	dust.gravity = Vector2(0, 380)
	dust.color = Color(0.45, 0.38, 0.4)
	dust.position = Vector2(0, -HEIGHT)
	add_child(dust)
	dust.emitting = true
	if sound:
		Sfx.play(get_parent(), SNAP, randf_range(0.9, 1.15), -10.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= WARN and not _landed:
		_sprite.visible = true
		var k := clampf((_t - WARN) / FALL, 0.0, 1.0)
		_sprite.position.y = -HEIGHT * (1.0 - k * k)
		if k >= 1.0:
			_land()
	if _landed and _t > WARN + FALL + LIE:
		modulate.a = move_toward(modulate.a, 0.0, delta * 3.0)
		if modulate.a <= 0.0:
			queue_free()


func _land() -> void:
	_landed = true
	_sprite.frame = 1
	_sprite.position.y = 0
	var hit := false
	if is_instance_valid(target) and target.global_position.distance_to(global_position) <= RADIUS:
		hit = target.hurt(1, global_position + Vector2(0, -4))
	if sound:
		Sfx.play(get_parent(), LAND, randf_range(0.9, 1.1), -5.0)
	var splinters := CPUParticles2D.new()
	splinters.amount = 10
	splinters.lifetime = 0.6
	splinters.one_shot = true
	splinters.explosiveness = 1.0
	splinters.direction = Vector2.UP
	splinters.spread = 75.0
	splinters.gravity = Vector2(0, 360)
	splinters.initial_velocity_min = 40.0
	splinters.initial_velocity_max = 90.0
	splinters.scale_amount_min = 1.0
	splinters.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.72, 0.66, 0.64))
	ramp.set_color(1, Color(0.45, 0.36, 0.38, 0.0))
	splinters.color_ramp = ramp
	add_child(splinters)
	splinters.emitting = true
	landed.emit(hit)


## L'ombra per terra: cresce e si scurisce finché il ramo arriva.
func _draw() -> void:
	if _landed:
		return
	var k := clampf(_t / WARN, 0.0, 1.0)
	var w := 6.0 + 14.0 * k
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, w, Color(0.03, 0.02, 0.05, 0.25 + 0.4 * k))
	draw_circle(Vector2.ZERO, w * 0.55, Color(0.03, 0.02, 0.05, 0.2 + 0.35 * k))


func is_landed() -> bool:
	return _landed
