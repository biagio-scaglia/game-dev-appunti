extends Node2D
## La scena principale: la stanza al buio (CanvasModulate), la protagonista al centro,
## l'OST lo-fi in loop, il menu di pausa (Esc o X) e i dialoghi con le cose (Talk, sta
## in fondo alla scena: il suo riquadro si prende l'input prima del menu), e dopo un po'
## qualcuno che bussa alla porta (DoorKnock). Il prologo (prologue/prologue.gd) fa il
## risveglio dopo la cutscene, lo specchio che chiama e la caduta; finito, si torna al
## titolo (il capitolo 1 non c'è ancora). Qui si conta il tempo di gioco.

const Music := preload("core/music.gd")
const GameState := preload("menu/game_state.gd")
const Prologue := preload("prologue/prologue.gd")
const TITLE := "res://title/title_screen.tscn"

@onready var room: Node2D = %Room
@onready var hero: CharacterBody2D = %Protagonista
@onready var music: AudioStreamPlayer = %Music
@onready var pause_menu: CanvasLayer = %PauseMenu
@onready var talk: Node = %Talk
@onready var knock: Node2D = %DoorKnock

var state := GameState.new()

## Il salvataggio da riprendere all'avvio ("Continue" del titolo). Si usa una volta e si svuota.
static var pending_save: Dictionary = {}
## Vero quando si arriva dalla cutscene di New Game: si parte col risveglio.
static var from_opening := false

var prologue: Node


func _ready() -> void:
	hero.position = room.player_start()
	if not pending_save.is_empty():
		state.load_save(pending_save)
		hero.global_position = GameState.saved_position(pending_save)
		hero.set("sword_stage", int(pending_save.get("sword_stage", 0)))
		pending_save = {}
	# Magia e spada solo se Lethe le ha (all'inizio no). Si riguarda quando si chiude il menu:
	# lì si può cambiare l'arma.
	sync_abilities()
	pause_menu.closed.connect(sync_abilities)
	pause_menu.setup(state, hero, music)
	talk.setup(room, hero, state)
	# Bussano alla porta: i dialoghi sanno se c'è qualcuno (knocking) e possono rispondere.
	knock.setup(room)
	knock.is_busy = talk.is_talking
	talk.extra_states.append(knock)
	prologue = Prologue.new()
	prologue.name = "Prologue"
	add_child(prologue)
	prologue.setup(room, hero, talk, knock, state, music)
	prologue.finished.connect(_on_prologue_finished)
	Music.play_loop(music)
	if from_opening:
		from_opening = false
		prologue.wake_up()


## Il prologo è finito: per ora si torna al titolo.
func _on_prologue_finished() -> void:
	sync_abilities()
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file(TITLE)


func sync_abilities() -> void:
	hero.can_cast = state.can_cast()
	hero.can_slash = state.can_slash()


func _process(delta: float) -> void:
	state.play_time += delta   # in pausa conta il menu
