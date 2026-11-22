extends Node2D
## Lethe nel raggio di luna, di spalle, che guarda la finestra. Usa gli sprite della
## protagonista; se non ci sono (sono solo in locale) resta nascosta, senza errori.
## L'origine del nodo è ai piedi.

const Frames := preload("res://characters/protagonista/protagonista_frames.gd")
const DropShadow := preload("res://fx/drop_shadow.gd")

## L'animazione: ferma, di spalle.
@export var animation := &"idle_up"

var sprite: AnimatedSprite2D


func _ready() -> void:
	visible = Frames.sprites_available()
	if not visible:
		return
	var shadow := DropShadow.new()
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Frames.build()
	sprite.offset = Frames.feet_offset()
	add_child(sprite)
	sprite.play(animation)
