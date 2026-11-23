extends Node2D
## La scena principale: la stanza al buio (CanvasModulate), la protagonista al centro,
## l'OST lo-fi in loop e il menu di pausa (Esc o X). Qui si conta il tempo di gioco.

const Music := preload("core/music.gd")
const GameState := preload("menu/game_state.gd")

@onready var room: Node2D = %Room
@onready var hero: CharacterBody2D = %Protagonista
@onready var music: AudioStreamPlayer = %Music
@onready var pause_menu: CanvasLayer = %PauseMenu

var state := GameState.new()


func _ready() -> void:
	hero.position = room.player_start()
	pause_menu.setup(state, hero, music)
	Music.play_loop(music)


func _process(delta: float) -> void:
	state.play_time += delta   # in pausa conta il menu
