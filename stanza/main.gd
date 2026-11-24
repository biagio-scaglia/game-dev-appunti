extends Node2D
## La scena principale: la stanza al buio (CanvasModulate), la protagonista al centro,
## l'OST lo-fi in loop, il menu di pausa (Esc o X) e i dialoghi con le cose (Talk, sta
## in fondo alla scena: il suo riquadro si prende l'input prima del menu), e dopo un po'
## qualcuno che bussa alla porta (DoorKnock). Qui si conta il tempo di gioco.

const Music := preload("core/music.gd")
const GameState := preload("menu/game_state.gd")

@onready var room: Node2D = %Room
@onready var hero: CharacterBody2D = %Protagonista
@onready var music: AudioStreamPlayer = %Music
@onready var pause_menu: CanvasLayer = %PauseMenu
@onready var talk: Node = %Talk
@onready var knock: Node2D = %DoorKnock

var state := GameState.new()


func _ready() -> void:
	hero.position = room.player_start()
	pause_menu.setup(state, hero, music)
	talk.setup(room, hero, state)
	# Bussano alla porta: i dialoghi sanno se c'è qualcuno (knocking) e possono rispondere.
	knock.setup(room)
	knock.is_busy = talk.is_talking
	talk.extra_states.append(knock)
	# La riga dei tasti sparisce sotto il riquadro dei dialoghi.
	var hint: Label = $HUD/Hint
	talk.talk_started.connect(func(_id: String) -> void: hint.hide())
	talk.talk_finished.connect(func(_id: String) -> void: hint.show())
	Music.play_loop(music)


func _process(delta: float) -> void:
	state.play_time += delta   # in pausa conta il menu
