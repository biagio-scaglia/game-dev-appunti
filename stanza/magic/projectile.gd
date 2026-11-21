extends Area2D
## Il proiettile magico: vola dritto, illumina la stanza di viola, esplode quando
## tocca un muro o un mobile (livello "mondo") o dopo max_distance pixel.

signal exploded(at: Vector2)

const MagicFrames := preload("magic_frames.gd")
const Glow := preload("../core/glow.gd")
const IMPACT := preload("impact.tscn")

@export var speed := 190.0
@export var max_distance := 420.0

@onready var sprite: AnimatedSprite2D = $Sprite

var direction := Vector2.RIGHT
var travelled := 0.0
var _done := false


func _ready() -> void:
	sprite.sprite_frames = MagicFrames.build()
	sprite.play(&"projectile")
	sprite.rotation = direction.angle()          # lo sheet vola verso destra
	add_child(Glow.light(Color(0.72, 0.48, 1.0), 1.3, 80.0))
	body_entered.connect(func(_body): explode())


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	position += step
	travelled += step.length()
	if travelled >= max_distance:
		explode()


func explode() -> void:
	if _done:
		return
	_done = true
	var fx := IMPACT.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
	exploded.emit(global_position)
	queue_free()
