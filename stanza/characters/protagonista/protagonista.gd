extends CharacterBody2D
## La protagonista: cammina in 8 direzioni, corre con Shift, e attacca in due modi.
## - Magia (Spazio o J): la verità. Prima la carica sulle mani, poi a metà attacco parte
##   il proiettile verso dove guarda.
## - Spada di vetro dello specchio (K): la bugia. La lama compare dalla mano e fende verso
##   dove guarda; sword_stage (0 scheggia, 1 pugnale, 2 lama) cresce con le bugie.
## Mentre attacca o parla (`frozen`) sta ferma. L'origine del nodo è ai piedi.

signal attack_finished(kind: StringName)

const Frames := preload("protagonista_frames.gd")
const Facing := preload("facing.gd")
const InputSetup := preload("../../core/input_setup.gd")
const PROJECTILE := preload("res://magic/projectile.tscn")
const CHARGE := preload("res://magic/charge.tscn")
const SWORD := preload("res://weapon/glass_sword.tscn")

@export var walk_speed := 70.0
@export var run_speed := 130.0
## Fotogramma dell'attacco in cui parte il colpo (il proiettile o il fendente).
@export var launch_frame := 3
## Lo stadio della spada di vetro: cresce con le bugie (sistema del karma, da fare).
@export_range(0, 2) var sword_stage := 0
## Dove sono le mani rispetto ai piedi: in alto e un po' avanti.
const HAND_HEIGHT := 24.0
const HAND_REACH := 14.0

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := Vector2.DOWN
## L'attacco in corso: &"cast", &"slash" o vuoto.
var attacking := &""
var _launched := false
## Ferma (sta parlando con qualcosa): niente movimento né attacchi.
var frozen := false


func _ready() -> void:
	InputSetup.ensure_actions()
	sprite.sprite_frames = Frames.build()
	sprite.offset = Frames.feet_offset()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	_play("idle")


func _physics_process(_delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		if not is_attacking():
			_play("idle")
		return
	if Input.is_action_just_pressed(&"cast"):
		cast()
	elif Input.is_action_just_pressed(&"slash"):
		slash()
	if OS.is_debug_build() and Input.is_action_just_pressed(&"sword_stage"):
		sword_stage = (sword_stage + 1) % 3       # solo per provare gli stadi
	if is_attacking():
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var running := Input.is_action_pressed(&"run")
	velocity = direction * (run_speed if running else walk_speed)
	move_and_slide()
	update_animation(direction, running)


func is_attacking() -> bool:
	return attacking != &""


## Sceglie l'animazione di movimento. Pubblica: la usano i test.
func update_animation(direction: Vector2, running: bool) -> void:
	facing = Facing.dir8(direction, facing)
	if direction == Vector2.ZERO:
		_play("idle")
	else:
		_play("run" if running else "walk")


## Lancia la magia verso dove guarda. Ignorato se sta già attaccando.
func cast() -> void:
	if _start_attack(&"cast"):
		_spawn(CHARGE.instantiate(), hand_position())


## Fende con la spada di vetro verso dove guarda. Ignorato se sta già attaccando.
func slash() -> void:
	_start_attack(&"slash")


func hand_position() -> Vector2:
	return global_position + facing.normalized() * HAND_REACH + Vector2(0, -HAND_HEIGHT)


func _start_attack(kind: StringName) -> bool:
	if is_attacking():
		return false
	attacking = kind
	_launched = false
	_play("attack" if kind == &"cast" else "slash")   # slash: la stessa posa, con la scia di vetro
	return true


func _on_frame_changed() -> void:
	if not is_attacking() or _launched or sprite.frame < launch_frame:
		return
	_launched = true
	match attacking:
		&"cast":
			var shot := PROJECTILE.instantiate()
			shot.direction = facing.normalized()
			_spawn(shot, hand_position())
		&"slash":
			var sword := SWORD.instantiate()
			sword.direction = facing.normalized()
			sword.stage = sword_stage
			_spawn(sword, hand_position())


func _on_animation_finished() -> void:
	if not is_attacking():
		return
	var kind := attacking
	attacking = &""
	_play("idle")
	attack_finished.emit(kind)


func _spawn(node: Node2D, at: Vector2) -> void:
	get_parent().add_child(node)
	node.global_position = at


func _play(kind: String) -> void:
	sprite.flip_h = Facing.flipped(facing)
	var anim := Facing.animation(kind, facing)
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
