extends CharacterBody2D
## La base dei nemici (vault: "Nemici e boss"): vita, debolezze, il lampo bianco e la
## spinta quando vengono colpiti, la morte che si scioglie in ombra, e il danno a Lethe
## quando la toccano (solo quando `hurtful`). Ogni nemico fa il suo in behave().
##
## Stanno nel livello fisico "nemici" (la spada e la magia li cercano lì) e nel gruppo
## "enemies". La spada li colpisce con hurt(danno, &"sword", da dove), la magia con &"magic".

signal died(enemy: Node2D)

const Sfx := preload("res://core/sfx.gd")
const Sparks := preload("res://fx/sparks.gd")
const DropShadow := preload("res://fx/drop_shadow.gd")
const HIT := preload("res://audio/enemy_hit.wav")
const DIE := preload("res://audio/enemy_die.wav")
const DamageNumber := preload("res://fx/damage_number.gd")
## La barretta della vita sopra il nemico: quanto resta visibile dopo un colpo.
const BAR_SHOW := 2.5
const BAR_WIDTH := 20.0
## Dopo un colpo il nemico è scomposto: per un attimo non attacca (si può incalzare).
const STAGGER := 0.35

const ENEMY_LAYER := 4
const HERO_LAYER := 2
const FLASH_TIME := 0.12
const KNOCK_DRAG := 900.0

var max_hp := 3
var hp := 3
## Quanto fa male ogni arma: {&"sword": 0.5, &"magic": 1.5}. Manca = 1.
var weakness := {}
var contact_damage := 1
## Quanta esperienza lascia, e la probabilità di lasciare qualcosa da mangiare.
var exp_reward := 2
## Il livello del nemico (quello della zona): l'esperienza cala se Lethe è molto più in alto.
var level := 1
var drop_chance := 0.3
## Quanto lo spinge via un colpo (pixel al secondo). 0 = ha le radici (il rovo).
var knockback := 230.0
## Se toccarlo adesso fa male a Lethe.
var hurtful := false
## Chi inseguire (Lethe). Lo mette la zona.
var target: Node2D
## Falso nei test: niente suoni.
var sound := true
var dead := false
## Da dove è partito (ci torna).
var home := Vector2.ZERO

var sprite: Sprite2D
var hurtbox: Area2D
var hurt_shape: CircleShape2D
var _flash := 0.0
var _knock := Vector2.ZERO
var _anim_time := 0.0
var _bar_time := 0.0
var _stagger := 0.0
var bar: Node2D
## Quanto in alto sta la barretta (sopra lo sprite).
var bar_height := 40.0


func _init() -> void:
	collision_layer = ENEMY_LAYER
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(&"enemies")


func _ready() -> void:
	home = global_position
	hp = max_hp
	bar = Node2D.new()
	bar.z_index = 15
	bar.draw.connect(_draw_bar)
	add_child(bar)


## Il corpo (dove lo colpiscono) e la zona che fa male a Lethe, cerchi intorno all'origine.
func make_body(radius: float, at := Vector2.ZERO) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = at
	add_child(shape)
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = HERO_LAYER
	hurtbox.monitorable = false
	var hshape := CollisionShape2D.new()
	hurt_shape = CircleShape2D.new()
	hurt_shape.radius = radius + 2.0
	hshape.shape = hurt_shape
	hshape.position = at
	hurtbox.add_child(hshape)
	add_child(hurtbox)


## Lo sprite: un foglio di `frames` fotogrammi in fila, con l'origine ai piedi (`lift` lo
## alza da terra, per chi vola) e l'ombra sotto.
func make_sprite(texture: Texture2D, frames: int, lift := 0.0, shadow := true) -> void:
	if shadow:
		var s := DropShadow.new()
		add_child(s)
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.hframes = frames
	sprite.offset = Vector2(0, -texture.get_height() / 2.0 - lift)
	add_child(sprite)


## Il danno di un colpo con un'arma, dopo le debolezze (almeno 1).
func damage_from(amount: int, kind: StringName) -> int:
	return maxi(1, roundi(amount * float(weakness.get(kind, 1.0))))


## Colpito: toglie vita, lampeggia, viene spinto via. Ritorna il danno fatto.
func hurt(amount: int, kind: StringName, from: Vector2) -> int:
	if dead:
		return 0
	var dmg := damage_from(amount, kind)
	hp -= dmg
	_flash = FLASH_TIME
	_bar_time = BAR_SHOW
	_stagger = STAGGER
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -bar_height), dmg,
		float(weakness.get(kind, 1.0)))
	var away := global_position - from
	_knock = (away.normalized() if away.length() > 0.1 else Vector2.UP) * knockback
	if sound:
		Sfx.play(get_parent(), HIT, randf_range(0.9, 1.1), -4.0)
	var sparks := Sparks.burst(8 if kind == &"magic" else 5)
	sparks.position = global_position + Vector2(0, -10)
	get_parent().add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	on_hurt(kind)
	if hp <= 0:
		die()
	return dmg


## Per i nemici: cosa fanno quando vengono colpiti (es. la falena scappa).
func on_hurt(_kind: StringName) -> void:
	pass


## Si scioglie in ombra: puntini scuri che salgono, lo sprite che si schiaccia e sparisce.
func die() -> void:
	if dead:
		return
	dead = true
	hurtful = false
	collision_layer = 0
	if sound:
		Sfx.play(get_parent(), DIE, randf_range(0.9, 1.1), -6.0)
	var smoke := CPUParticles2D.new()
	smoke.amount = 16
	smoke.lifetime = 0.9
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 8.0
	smoke.direction = Vector2.UP
	smoke.spread = 60.0
	smoke.gravity = Vector2(0, -30)
	smoke.initial_velocity_min = 10.0
	smoke.initial_velocity_max = 40.0
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.16, 0.1, 0.24, 0.95))
	ramp.set_color(1, Color(0.3, 0.2, 0.45, 0.0))
	smoke.color_ramp = ramp
	smoke.position = global_position + Vector2(0, -10)
	get_parent().add_child(smoke)
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)
	died.emit(self)
	var t := create_tween().set_parallel()
	t.tween_property(sprite, "scale", Vector2(1.4, 0.2), 0.25)
	t.tween_property(sprite, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_anim_time += delta
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	if _bar_time > 0.0:
		_bar_time -= delta
		bar.queue_redraw()
	if _knock != Vector2.ZERO:
		global_position += _knock * delta
		_knock = _knock.move_toward(Vector2.ZERO, KNOCK_DRAG * delta)
		return
	if _stagger > 0.0:
		_stagger -= delta
		return
	behave(delta)
	if hurtful and target and hurtbox:
		for body in hurtbox.get_overlapping_bodies():
			if body == target and target.has_method(&"hurt"):
				if target.hurt(contact_damage, global_position):
					on_hit_target()


## Il comportamento del nemico, ogni frame di fisica.
func behave(_delta: float) -> void:
	pass


## Ha fatto male a Lethe (es. la falena si allontana).
func on_hit_target() -> void:
	pass


func is_staggered() -> bool:
	return _stagger > 0.0


## La barretta: vuota scura, piena rosa, a blocchi di 2 pixel; si spegne piano.
func _draw_bar() -> void:
	if _bar_time <= 0.0 or dead:
		return
	var a := clampf(_bar_time / 0.5, 0.0, 1.0)
	var left := Vector2(-BAR_WIDTH / 2.0, -bar_height - 6.0)
	bar.draw_rect(Rect2(left - Vector2(2, 2), Vector2(BAR_WIDTH + 4, 6)), Color(0.05, 0.03, 0.08, 0.85 * a))
	var fill := floorf(BAR_WIDTH * clampf(float(hp) / max_hp, 0.0, 1.0) / 2.0) * 2.0
	bar.draw_rect(Rect2(left, Vector2(fill, 2)), Color(0.92, 0.42, 0.55, a))


## Lethe è a meno di `radius`?
func sees_target(radius: float) -> bool:
	return target != null and is_instance_valid(target) and global_position.distance_to(target.global_position) < radius
