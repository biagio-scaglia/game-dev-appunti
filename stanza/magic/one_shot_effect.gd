extends Node2D
## Effetto magico che si suona una volta e sparisce (carica, impatto). Ha una luce
## viola che si spegne mentre l'animazione finisce.

const MagicFrames := preload("magic_frames.gd")
const Glow := preload("../core/glow.gd")

@export var animation := &"impact"
@export var light_energy := 1.2
@export var light_radius := 90.0

@onready var sprite: AnimatedSprite2D = $Sprite

var light: PointLight2D


func _ready() -> void:
	sprite.sprite_frames = MagicFrames.build()
	sprite.animation_finished.connect(queue_free)
	sprite.play(animation)
	light = Glow.light(Color(0.75, 0.5, 1.0), light_energy, light_radius)
	add_child(light)
	var frames := sprite.sprite_frames.get_frame_count(animation)
	var duration := frames / sprite.sprite_frames.get_animation_speed(animation)
	create_tween().tween_property(light, "energy", 0.0, duration)
