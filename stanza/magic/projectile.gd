extends Area2D
## Il proiettile magico: vola dritto lasciando una scia di scintille, illumina la stanza
## di viola, esplode quando tocca un muro o un mobile (livello "mondo") o dopo
## max_distance pixel. Al lancio suona il soffio (nodo Sfx). Tocca anche i nemici (livello
## "nemici"): fa male (`damage`), e la sua luce attira le falene (gruppo "lure") e accende
## le cose che prendono luce, le lanterne di radice (light_catch.gd).

signal exploded(at: Vector2)

const MagicFrames := preload("magic_frames.gd")
const Glow := preload("../core/glow.gd")
const Sparks := preload("../fx/sparks.gd")
const IMPACT := preload("impact.tscn")
const LightCatch := preload("light_catch.gd")

@export var speed := 190.0
@export var max_distance := 420.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sfx: AudioStreamPlayer = $Sfx

var direction := Vector2.RIGHT
var damage := 3
var travelled := 0.0
var _done := false
var trail: CPUParticles2D


func _ready() -> void:
	sprite.sprite_frames = MagicFrames.build()
	sprite.play(&"projectile")
	sprite.rotation = direction.angle()          # lo sheet vola verso destra
	add_child(Glow.light(Color(0.72, 0.48, 1.0), 1.3, 80.0))
	body_entered.connect(_on_body)
	add_to_group(&"lure")
	trail = Sparks.trail()
	add_child(trail)
	trail.emitting = true
	sfx.play()


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	position += step
	travelled += step.length()
	LightCatch.touch(get_tree(), global_position)
	if travelled >= max_distance:
		explode()


func _on_body(body: Node2D) -> void:
	if body.is_in_group(&"enemies"):
		body.hurt(damage, &"magic", global_position)
	explode()


func explode() -> void:
	if _done:
		return
	_done = true
	LightCatch.touch(get_tree(), global_position)
	var fx := IMPACT.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
	exploded.emit(global_position)
	_leave_trail()
	queue_free()


## La scia resta nel mondo e si spegne da sola (le scintille già nate finiscono la vita).
func _leave_trail() -> void:
	var at := trail.global_position
	trail.emitting = false
	remove_child(trail)
	get_parent().add_child(trail)
	trail.global_position = at
	get_tree().create_timer(trail.lifetime + 0.05).timeout.connect(trail.queue_free)
