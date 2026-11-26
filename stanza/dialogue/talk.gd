extends Node
## Parlare con le cose della stanza. Ogni frame guarda cosa c'è davanti a Lethe (solo le
## cose che hanno un cue in stanza.dialogue); se c'è qualcosa, sopra la sua testa compare
## un'iconcina: un fumetto col cuore che batte come quello del menu (tum-tum, pausa).
## Compare con un piccolo salto e sparisce rimpicciolendo. Con interact (E, Z, Invio) apre
## il riquadro dei dialoghi e ferma Lethe finché non finisce.
##
## Nei dialoghi si vedono: le variabili di GameState (truth, lies...) e seen("id"), quante
## volte ha già parlato con quella cosa.
##
## La prima volta (`key_hint`) accanto al fumetto c'è anche il tasto: "E". Dopo il primo
## dialogo non compare più (i tasti si spiegano una volta, quando servono).
## say() apre un dialogo che non è di una cosa (es. il narratore del prologo).

signal talk_started(id: String)
signal talk_finished(id: String)

const DIALOGUE := preload("res://dialogue/stanza.dialogue")
## Due fotogrammi in fila: cuore pieno, cuore stretto (come il cuore del menu).
const ICON := preload("res://dialogue/talk_icon.png")
const HeartMenu := preload("res://ui/heart_menu.gd")
const DialogueBox := preload("dialogue_box.gd")
const RoomThings := preload("res://world/room_things.gd")
const InputSetup := preload("res://core/input_setup.gd")

## La punta dell'icona rispetto ai piedi: la testa di Lethe arriva a 52 px, più un blocco
## di aria.
const HEAD_HEIGHT := 54.0
const POP_SECONDS := 0.18
const HIDE_SECONDS := 0.1

var room: Node2D
var hero: Node2D
var state: RefCounted
## Le cose con cui si può parlare (rettangoli relativi alla stanza).
var things: Array[Dictionary] = []
## La cosa davanti a Lethe ora ("" = niente).
var target := ""
## {id: quante volte ci ha parlato}
var visits := {}
## Altri oggetti dove i dialoghi cercano variabili e funzioni (es. la porta che bussa).
var extra_states: Array = []
var box: CanvasLayer
## L'icona sopra la testa di Lethe. Sta in un CanvasLayer che segue il mondo: il buio
## della stanza (CanvasModulate) non la scurisce.
var icon: Sprite2D
var _beat_step := 0
var _beat_left := 0.0
var _pop: Tween
## Mostra il tasto accanto al fumetto, finché non si parla la prima volta.
var key_hint := false
## Il dialogo delle cose (stanza.dialogue nella stanza; un altro nelle zone, con setup_with).
var dialogue: Resource = DIALOGUE
var hint_label: Label


func _ready() -> void:
	InputSetup.ensure_actions()
	var layer := CanvasLayer.new()
	layer.name = "IconLayer"
	layer.layer = 2                         # sopra il filtro grigio del mondo (livello 1)
	layer.follow_viewport_enabled = true
	add_child(layer)
	icon = Sprite2D.new()
	icon.texture = ICON
	icon.hframes = 2
	icon.offset = Vector2(0, -ICON.get_height() / 2.0)    # l'origine è in basso, sulla punta
	icon.hide()
	layer.add_child(icon)
	hint_label = Label.new()
	hint_label.text = InputSetup.LABELS[&"action"]
	hint_label.add_theme_font_override(&"font", preload("res://ui/fonts/kenpixel_high_square.ttf"))
	hint_label.add_theme_font_size_override(&"font_size", 16)
	hint_label.add_theme_color_override(&"font_color", Color(0.95, 0.9, 1.0))
	hint_label.add_theme_color_override(&"font_outline_color", Color(0.12, 0.08, 0.18))
	hint_label.add_theme_constant_override(&"outline_size", 4)
	hint_label.position = Vector2(ICON.get_width() / 4.0 + 2, -ICON.get_height() - 4)
	icon.add_child(hint_label)
	hint_label.hide()


func setup(room_node: Node2D, hero_node: Node2D, game_state: RefCounted) -> void:
	room = room_node
	hero = hero_node
	state = game_state
	things = RoomThings.build(room.data, DIALOGUE.get_cues())


## Come setup(), ma fuori dalla stanza: `origin` è il nodo a cui sono relativi i
## rettangoli di `thing_list` ({id, rect}), e `resource` il dialogo con un cue per id.
func setup_with(origin: Node2D, hero_node: Node2D, game_state: RefCounted, thing_list: Array[Dictionary],
		resource: Resource) -> void:
	room = origin
	hero = hero_node
	state = game_state
	things = thing_list
	dialogue = resource


func is_talking() -> bool:
	return is_instance_valid(box)


## Quante volte ha già parlato con `id` (la usano i dialoghi).
func seen(id: String) -> int:
	return int(visits.get(id, 0))


## Apre il dialogo della cosa `id` (anche senza averla davanti: lo usano i test).
func talk(id: String) -> void:
	say(dialogue, id)


## Apre il cue `cue` di un dialogo qualsiasi, fermando Lethe finché non finisce.
func say(resource: Resource, cue: String) -> void:
	if is_talking():
		return
	if resource == dialogue:
		key_hint = false        # ha parlato con una cosa: il tasto l'ha capito
	hint_label.hide()
	_set_target("", true)
	hero.set(&"frozen", true)
	box = DialogueBox.new()
	box.finished.connect(_on_finished.bind(cue))
	add_child(box)
	talk_started.emit(cue)
	box.start(resource, cue, [self, state] + extra_states)


## Dove sta la punta dell'icona: sopra la testa di Lethe. In cima alla stanza l'icona
## non esce dallo schermo.
func icon_anchor() -> Vector2:
	var tip := hero.global_position - Vector2(0, HEAD_HEIGHT)
	tip.y = maxf(tip.y, ICON.get_height() + 2.0)
	return tip.round()


func _process(delta: float) -> void:
	var now := ""
	if hero and not is_talking() and not get_tree().paused and not hero.call(&"is_attacking") \
			and not hero.get(&"frozen"):

		var feet := hero.global_position - room.global_position
		now = RoomThings.in_front(things, feet, hero.get(&"facing"))
	_set_target(now)
	if icon.visible and hero:
		icon.position = icon_anchor()
		_beat(delta)


func _unhandled_input(event: InputEvent) -> void:
	if target != "" and event.is_action_pressed(&"interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		talk(target)


## Il cuore nel fumetto batte col ritmo del cuore del menu.
func _beat(delta: float) -> void:
	_beat_left -= delta
	if _beat_left > 0.0:
		return
	_beat_step = (_beat_step + 1) % HeartMenu.BEAT.size()
	icon.frame = HeartMenu.BEAT[_beat_step][0]
	_beat_left = HeartMenu.BEAT[_beat_step][1]


## Cambia la cosa davanti. L'icona compare con un salto; sparisce rimpicciolendo (o subito,
## con `at_once`: quando si apre il dialogo).
func _set_target(id: String, at_once := false) -> void:
	if id == target:
		return
	var was_shown := target != ""
	target = id
	if id != "" and was_shown and icon.visible:
		return            # da una cosa all'altra: l'icona resta dov'è, sopra la testa
	if _pop:
		_pop.kill()
	if id == "":
		if at_once or not icon.visible:
			icon.hide()
			return
		_pop = create_tween()
		_pop.tween_property(icon, "scale", Vector2(0.3, 0.3), HIDE_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_pop.tween_callback(icon.hide)
		return
	icon.position = icon_anchor()
	hint_label.visible = key_hint
	icon.show()
	icon.frame = 0
	_beat_step = 0
	_beat_left = HeartMenu.BEAT[0][1]
	icon.scale = Vector2(0.3, 0.3)
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
