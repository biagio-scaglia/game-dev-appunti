extends CharacterBody2D
## La protagonista: cammina in 8 direzioni, corre con Shift, lancia una magia con
## Spazio (o J). Mentre lancia sta ferma: prima la carica sulle mani, poi a metà
## attacco parte il proiettile verso dove guarda. L'origine del nodo è ai piedi.

signal cast_finished

const Frames := preload("protagonista_frames.gd")
const Facing := preload("facing.gd")
const InputSetup := preload("../../core/input_setup.gd")
const PROJECTILE := preload("res://magic/projectile.tscn")
const CHARGE := preload("res://magic/charge.tscn")

@export var walk_speed := 70.0
@export var run_speed := 130.0
## Fotogramma dell'attacco in cui parte il proiettile.
@export var launch_frame := 3
## Dove sono le mani rispetto ai piedi: in alto e un po' avanti.
const HAND_HEIGHT := 24.0
const HAND_REACH := 14.0

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := Vector2.DOWN
var casting := false
var _launched := false


func _ready() -> void:
	InputSetup.ensure_actions()
	sprite.sprite_frames = Frames.build()
	sprite.offset = Frames.feet_offset()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	_play("idle")


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"cast"):
		cast()
	if casting:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var running := Input.is_action_pressed(&"run")
	velocity = direction * (run_speed if running else walk_speed)
	move_and_slide()
	update_animation(direction, running)


## Sceglie l'animazione di movimento. Pubblica: la usano i test.
func update_animation(direction: Vector2, running: bool) -> void:
	facing = Facing.dir8(direction, facing)
	if direction == Vector2.ZERO:
		_play("idle")
	else:
		_play("run" if running else "walk")


## Lancia la magia verso dove guarda. Ignorato se sta già lanciando.
func cast() -> void:
	if casting:
		return
	casting = true
	_launched = false
	_play("attack")
	_spawn(CHARGE.instantiate(), hand_position())


func hand_position() -> Vector2:
	return global_position + facing.normalized() * HAND_REACH + Vector2(0, -HAND_HEIGHT)


func _on_frame_changed() -> void:
	if casting and not _launched and sprite.frame >= launch_frame:
		_launched = true
		var shot := PROJECTILE.instantiate()
		shot.direction = facing.normalized()
		_spawn(shot, hand_position())


func _on_animation_finished() -> void:
	if not casting:
		return
	casting = false
	_play("idle")
	cast_finished.emit()


func _spawn(node: Node2D, at: Vector2) -> void:
	get_parent().add_child(node)
	node.global_position = at


func _play(kind: String) -> void:
	sprite.flip_h = Facing.flipped(facing)
	var anim := Facing.animation(kind, facing)
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
