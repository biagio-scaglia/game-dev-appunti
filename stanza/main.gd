extends Node2D
## La scena principale: la stanza al buio (CanvasModulate), la protagonista al centro.

@onready var room: Node2D = %Room
@onready var hero: CharacterBody2D = %Protagonista


func _ready() -> void:
	hero.position = room.player_start()
