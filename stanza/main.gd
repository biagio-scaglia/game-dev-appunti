extends Node2D
## La scena principale: la stanza al buio (CanvasModulate), la protagonista al centro,
## l'OST lo-fi in loop.

const Music := preload("core/music.gd")

@onready var room: Node2D = %Room
@onready var hero: CharacterBody2D = %Protagonista
@onready var music: AudioStreamPlayer = %Music


func _ready() -> void:
	hero.position = room.player_start()
	Music.play_loop(music)
