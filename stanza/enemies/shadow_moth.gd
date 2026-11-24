extends "res://enemies/enemy.gd"
## La falena d'ombra (capitolo 1): vola in cerchio, e quando vede Lethe le gira intorno,
## si ferma un attimo sbattendo le ali più forte (si sente) e si butta su di lei. Le falene
## vanno alla luce: se c'è una luce che attira (gruppo "lure", la magia di Lethe) vanno lì
## e si dimenticano di lei. Debole alla magia, la spada le fa poco (le attraversa).
## Vola: passa sopra tutto.

const SHEET := preload("res://enemies/sprites/moth.png")
const FLUTTER := preload("res://audio/moth_flutter.wav")
const DIVE := preload("res://audio/moth_dive.wav")
const Glow := preload("res://core/glow.gd")

enum State { WANDER, HUNT, WINDUP, DIVE, RECOVER, LURED }

const SEE := 150.0
const LOSE := 240.0
const ORBIT := 60.0
const LURE_RANGE := 200.0
const SPEED := 70.0
const DIVE_SPEED := 260.0
const WINDUP_TIME := 0.5
const DIVE_TIME := 0.38
const RECOVER_TIME := 0.7
const HUNT_TIME := Vector2(1.4, 2.4)
const LIFT := 14.0

var state := State.WANDER
var _timer := 0.0
var _angle := 0.0
var _dive_dir := Vector2.ZERO
var lure: Node2D


func _ready() -> void:
	super()
	max_hp = 3
	hp = max_hp
	weakness = {&"magic": 1.5, &"sword": 0.5}
	exp_reward = 3
	make_sprite(SHEET, 3, LIFT)
	make_body(11.0, Vector2(0, -LIFT - 10))
	bar_height = LIFT + 26.0
	# Un filo di luce viola dagli occhi delle ali: al buio si vedono arrivare.
	var eyes := Glow.light(Color(0.62, 0.5, 1.0), 0.45, 26.0)
	eyes.position = Vector2(0, -LIFT - 10)
	add_child(eyes)
	_angle = randf() * TAU


func behave(delta: float) -> void:
	_timer -= delta
	var near_lure := _find_lure()
	if near_lure and state in [State.WANDER, State.HUNT, State.RECOVER]:
		lure = near_lure
		state = State.LURED
	match state:
		State.WANDER:
			_circle(home, 30.0, 1.1, delta)
			if sees_target(SEE):
				_enter(State.HUNT, randf_range(HUNT_TIME.x, HUNT_TIME.y))
		State.HUNT:
			_circle(target.global_position, ORBIT, 2.2, delta)
			if not sees_target(LOSE):
				_enter(State.WANDER, 0.0)
			elif _timer <= 0.0:
				_enter(State.WINDUP, WINDUP_TIME)
				if sound:
					Sfx.play(get_parent(), FLUTTER, 1.3, -8.0)
		State.WINDUP:
			# Ferma, le ali più veloci: si capisce che sta per buttarsi.
			if _timer <= 0.0:
				_dive_dir = (target.global_position - global_position).normalized()
				_enter(State.DIVE, DIVE_TIME)
				hurtful = true
				if sound:
					Sfx.play(get_parent(), DIVE, 1.0, -6.0)
		State.DIVE:
			global_position += _dive_dir * DIVE_SPEED * delta
			if _timer <= 0.0:
				_back_off()
		State.RECOVER:
			global_position -= _dive_dir * SPEED * 0.8 * delta
			if _timer <= 0.0:
				_enter(State.HUNT if sees_target(LOSE) else State.WANDER, randf_range(HUNT_TIME.x, HUNT_TIME.y))
		State.LURED:
			if not is_instance_valid(lure) or lure.global_position.distance_to(global_position) > LURE_RANGE * 1.5:
				lure = null
				_enter(State.WANDER, 0.0)
			else:
				_circle(lure.global_position, 18.0, 4.0, delta)
	_animate()


func _enter(next: State, time: float) -> void:
	state = next
	_timer = time
	if next != State.DIVE:
		hurtful = false


func _back_off() -> void:
	_enter(State.RECOVER, RECOVER_TIME)


func on_hit_target() -> void:
	_back_off()


func on_hurt(_kind: StringName) -> void:
	_back_off()                      # colpita: smette quello che faceva e si allontana


## Gira intorno a `center` a distanza `radius`, avvicinandosi piano.
func _circle(center: Vector2, radius: float, turn: float, delta: float) -> void:
	_angle += turn * delta
	var goal := center + Vector2.from_angle(_angle) * radius
	global_position = global_position.move_toward(goal, SPEED * delta * 1.6)


func _find_lure() -> Node2D:
	var best: Node2D = null
	var best_d := LURE_RANGE
	for node in get_tree().get_nodes_in_group(&"lure"):
		var d: float = (node as Node2D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _animate() -> void:
	if state == State.DIVE:
		sprite.frame = 2
		sprite.rotation = _dive_dir.angle() + PI / 2.0
		return
	sprite.rotation = 0.0
	var fps := 16.0 if state == State.WINDUP else 8.0
	sprite.frame = int(_anim_time * fps) % 2
	# L'avviso: prima di buttarsi si illumina a scatti (si vede arrivare).
	if state == State.WINDUP and _flash <= 0.0:
		sprite.modulate = Color(1.8, 1.5, 2.2) if int(_anim_time * 12.0) % 2 == 0 else Color.WHITE
	elif _flash <= 0.0:
		sprite.modulate = Color.WHITE
	sprite.position.y = sin(_anim_time * 3.0) * 2.0           # galleggia
