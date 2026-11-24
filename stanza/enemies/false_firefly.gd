extends "res://enemies/enemy.gd"
## La lucciola falsa (capitolo 1): una luce che mente. Da lontano è una lucciola come le
## altre, calda, che galleggia. Quando Lethe si avvicina si apre (un corpo nero, occhi rossi,
## denti), la luce diventa rossa e la insegue. Dopo un po', o se Lethe scappa lontano, torna
## al suo posto e fa di nuovo la lucciola. Vola. Due colpi qualsiasi.

const SHEET := preload("res://enemies/sprites/firefly.png")
const BITE := preload("res://audio/firefly_bite.wav")
const Glow := preload("res://core/glow.gd")

enum State { HIDDEN, REVEAL, CHASE, BACK_OFF, RETURN }

const NOTICE := 64.0
const GIVE_UP := 220.0
const REVEAL_TIME := 0.35
const CHASE_TIME := 3.2
const BACK_OFF_TIME := 0.6
const SPEED := 92.0
const LIFT := 12.0
const WARM := Color(1.0, 0.88, 0.5)
const RED := Color(1.0, 0.3, 0.3)

var state := State.HIDDEN
var _timer := 0.0
var light: PointLight2D


func _ready() -> void:
	super()
	max_hp = 2
	hp = max_hp
	exp_reward = 2
	make_sprite(SHEET, 3, LIFT, false)
	make_body(10.0, Vector2(0, -LIFT - 8))
	light = Glow.light(WARM, 0.6, 34.0)
	light.position = Vector2(0, -LIFT - 8)
	add_child(light)
	bar_height = LIFT + 22.0


func is_hidden() -> bool:
	return state == State.HIDDEN


func behave(delta: float) -> void:
	_timer -= delta
	match state:
		State.HIDDEN:
			sprite.frame = 0
			sprite.position.y = sin(_anim_time * 2.0) * 3.0
			light.energy = 0.5 + 0.15 * sin(_anim_time * 3.0)
			if sees_target(NOTICE):
				_go(State.REVEAL, REVEAL_TIME)
				light.color = RED
				if sound:
					Sfx.play(get_parent(), BITE, 1.2, -6.0)
		State.REVEAL:
			sprite.frame = 1
			if _timer <= 0.0:
				_go(State.CHASE, CHASE_TIME)
				hurtful = true
		State.CHASE:
			sprite.frame = 1 + int(_anim_time * 8.0) % 2
			global_position = global_position.move_toward(target.global_position, SPEED * delta)
			if _timer <= 0.0 or not sees_target(GIVE_UP):
				_go(State.RETURN, 0.0)
				hurtful = false
		State.BACK_OFF:
			sprite.frame = 1
			global_position += (global_position - target.global_position).normalized() * SPEED * delta
			if _timer <= 0.0:
				_go(State.CHASE, CHASE_TIME * 0.5)
				hurtful = true
		State.RETURN:
			sprite.frame = 1
			global_position = global_position.move_toward(home, SPEED * 0.8 * delta)
			if global_position.distance_to(home) < 2.0:
				_go(State.HIDDEN, 0.0)
				light.color = WARM


func _go(next: State, time: float) -> void:
	state = next
	_timer = time


func on_hit_target() -> void:
	if sound:
		Sfx.play(get_parent(), BITE, 0.9, -4.0)
	_go(State.BACK_OFF, BACK_OFF_TIME)
	hurtful = false


func on_hurt(_kind: StringName) -> void:
	if state == State.HIDDEN:
		_go(State.REVEAL, REVEAL_TIME)
		light.color = RED
