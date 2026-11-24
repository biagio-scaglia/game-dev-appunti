extends Node
## Parlare con le cose della stanza. Ogni frame guarda cosa c'è davanti a Lethe (solo le
## cose che hanno un cue in stanza.dialogue) e ci mette sopra un'iconcina: un fumetto col
## cuore, che compare con un piccolo salto e ondeggia di un blocco. Con interact (E, Z,
## Invio) apre il riquadro dei dialoghi e ferma Lethe finché non finisce.
##
## Nei dialoghi si vedono: le variabili di GameState (truth, lies...) e seen("id"), quante
## volte ha già parlato con quella cosa.

signal talk_started(id: String)
signal talk_finished(id: String)

const DIALOGUE := preload("res://dialogue/stanza.dialogue")
const ICON := preload("res://dialogue/talk_icon.png")
const DialogueBox := preload("dialogue_box.gd")
const RoomThings := preload("res://world/room_things.gd")
const InputSetup := preload("res://core/input_setup.gd")

## L'icona: quanto sta sopra la cosa, di quanto ondeggia (un blocco da 2 px) e ogni quanto.
const ICON_LIFT := 4.0
const BOB := 2.0
const BOB_SECONDS := 0.45
const POP_SECONDS := 0.18

var room: Node2D
var hero: Node2D
var state: RefCounted
## Le cose con cui si può parlare (rettangoli relativi alla stanza).
var things: Array[Dictionary] = []
## La cosa davanti a Lethe ora ("" = niente).
var target := ""
## {id: quante volte ci ha parlato}
var visits := {}
var box: CanvasLayer
## L'icona sopra la cosa. Sta in un CanvasLayer che segue il mondo: il buio della stanza
## (CanvasModulate) non la scurisce.
var icon: Sprite2D
var _time := 0.0
var _pop: Tween


func _ready() -> void:
	InputSetup.ensure_actions()
	var layer := CanvasLayer.new()
	layer.name = "IconLayer"
	layer.follow_viewport_enabled = true
	add_child(layer)
	icon = Sprite2D.new()
	icon.texture = ICON
	icon.offset = Vector2(0, -ICON.get_height() / 2.0)    # l'origine è in basso, sulla punta
	icon.hide()
	layer.add_child(icon)


func setup(room_node: Node2D, hero_node: Node2D, game_state: RefCounted) -> void:
	room = room_node
	hero = hero_node
	state = game_state
	things = RoomThings.build(room.data, DIALOGUE.get_cues())


func is_talking() -> bool:
	return is_instance_valid(box)


## Quante volte ha già parlato con `id` (la usano i dialoghi).
func seen(id: String) -> int:
	return int(visits.get(id, 0))


## Apre il dialogo della cosa `id` (anche senza averla davanti: lo usano i test).
func talk(id: String) -> void:
	if is_talking():
		return
	_set_target("")
	hero.set(&"frozen", true)
	box = DialogueBox.new()
	box.finished.connect(_on_finished.bind(id))
	add_child(box)
	talk_started.emit(id)
	box.start(DIALOGUE, id, [self, state])


func _process(delta: float) -> void:
	_time += delta
	var now := ""
	if hero and not is_talking() and not get_tree().paused and not hero.call(&"is_attacking"):
		var feet := hero.global_position - room.global_position
		now = RoomThings.in_front(things, feet, hero.get(&"facing"))
	_set_target(now)
	if target != "":
		var bob := BOB if fmod(_time, BOB_SECONDS * 2.0) < BOB_SECONDS else 0.0
		icon.position = (_icon_anchor(target) - Vector2(0, bob)).round()


func _unhandled_input(event: InputEvent) -> void:
	if target != "" and event.is_action_pressed(&"interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		talk(target)


## Dove sta la punta dell'icona: a metà della cosa, appena sopra. Le cose sul muro
## arrivano al bordo dello schermo: lì l'icona scende sulla cosa.
func _icon_anchor(id: String) -> Vector2:
	var rect := RoomThings.rect_of(things, id)
	var tip := room.global_position + Vector2(rect.get_center().x, rect.position.y - ICON_LIFT)
	tip.y = maxf(tip.y, ICON.get_height() + 2.0)
	return tip


func _set_target(id: String) -> void:
	if id == target:
		return
	target = id
	icon.visible = id != ""
	if id == "":
		return
	_time = 0.0
	icon.position = _icon_anchor(id).round()
	if _pop:
		_pop.kill()
	icon.scale = Vector2(0.4, 0.4)
	_pop = create_tween()
	_pop.tween_property(icon, "scale", Vector2.ONE, POP_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_finished(id: String) -> void:
	visits[id] = seen(id) + 1
	box = null
	# Un paio di frame di fisica: il tasto che chiude il dialogo non fa partire la magia.
	await get_tree().physics_frame
	await get_tree().physics_frame
	hero.set(&"frozen", false)
	talk_finished.emit(id)
