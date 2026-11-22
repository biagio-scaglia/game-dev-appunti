extends Node2D
## Effetto magico che si suona una volta e sparisce (carica, impatto), con la sua luce
## viola, il suo suono (nodo Sfx, se c'è) e, a scelta, uno scoppio di scintille e un
## tremolio dello schermo. Sparisce quando animazione e suono sono finiti: il tempo si
## calcola dalla durata del suono, non dal segnale finished (che senza audio non arriva).
##
## La luce della carica sale (si sta raccogliendo); quella dell'impatto si spegne.

const MagicFrames := preload("magic_frames.gd")
const Glow := preload("../core/glow.gd")
const Sparks := preload("../fx/sparks.gd")
const ScreenShake := preload("../fx/screen_shake.gd")

@export var animation := &"impact"
@export var light_energy := 1.2
@export var light_radius := 90.0
## True: la luce parte spenta e sale fino a light_energy (la carica).
@export var light_rises := false
## Scintille dello scoppio (0 = niente).
@export var burst_sparks := 0
## Pixel di tremolio dello schermo (0 = niente).
@export var shake := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sfx: AudioStreamPlayer = get_node_or_null(^"Sfx")

var light: PointLight2D


func _ready() -> void:
	sprite.sprite_frames = MagicFrames.build()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(animation)
	var duration := MagicFrames.duration(animation)
	light = Glow.light(Color(0.75, 0.5, 1.0), 0.0 if light_rises else light_energy, light_radius)
	add_child(light)
	create_tween().tween_property(light, "energy", light_energy if light_rises else 0.0, duration)
	if burst_sparks > 0:
		var burst := Sparks.burst(burst_sparks)
		add_child(burst)
		burst.emitting = true
	if shake > 0.0:
		var shaker := ScreenShake.new()
		shaker.strength = shake
		get_tree().root.add_child(shaker)
	if sfx:
		sfx.play()
	get_tree().create_timer(lifetime()).timeout.connect(queue_free)


## Quanto resta in scena: la più lunga tra l'animazione e il suono.
func lifetime() -> float:
	var anim := MagicFrames.duration(animation)
	return maxf(anim, sfx.stream.get_length()) if sfx and sfx.stream else anim


func _on_animation_finished() -> void:
	sprite.visible = false                # il suono può finire da solo
	light.energy = 0.0
