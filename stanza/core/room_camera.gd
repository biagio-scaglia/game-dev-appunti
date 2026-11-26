extends Node
## La camera per stanze (i dungeon): la camera di Lethe resta la stessa (così il regista
## delle cutscene la muove come sempre), ma i suoi limiti sono quelli della stanza in cui
## si trova. Passando una porta, i limiti scivolano verso la stanza nuova (come in Zelda):
## per un attimo Lethe si ferma e viene spinta dentro di un passo, poi si gioca.
##
## Una stanza è [id, nome, Rect2i in celle]. `room_changed` dice dove si è arrivati (la zona
## ci mostra il nome, la prima volta).

signal room_changed(id: String, room_name: String)

const SLIDE := 0.45
## Quanto deve entrare Lethe in una stanza perché sia "dentro" (pixel): niente rimbalzi
## sulla soglia.
const MARGIN := 10.0
## Di quanto viene spinta dentro la stanza nuova durante lo scivolamento.
const STEP_IN := 20.0

var camera: Camera2D
var hero: CharacterBody2D
var rooms: Array = []
var tile := 32
var current := ""
var sliding := false


func setup(camera_node: Camera2D, hero_node: CharacterBody2D, room_list: Array, tile_size := 32) -> void:
	camera = camera_node
	hero = hero_node
	rooms = room_list
	tile = tile_size
	var room := room_at(hero.global_position, 0.0)
	if not room.is_empty():
		current = room[0]
		_set_limits(rect_of(room))
		camera.reset_smoothing()


## La stanza in pixel.
func rect_of(room: Array) -> Rect2:
	var cells: Rect2i = room[2]
	return Rect2(Vector2(cells.position) * tile, Vector2(cells.size) * tile)


## La stanza che contiene `point` (entrata almeno di `margin`), o [] se non c'è.
func room_at(point: Vector2, margin := MARGIN) -> Array:
	for room in rooms:
		if rect_of(room).grow(-margin).has_point(point):
			return room
	return []


func room_named(id: String) -> Array:
	for room in rooms:
		if room[0] == id:
			return room
	return []


func _process(_delta: float) -> void:
	if sliding or hero == null or not is_instance_valid(hero):
		return
	var room := room_at(hero.global_position)
	if room.is_empty() or room[0] == current:
		return
	slide_to(room)


## Scivola verso `room`: i limiti si spostano dalla stanza vecchia alla nuova.
func slide_to(room: Array) -> void:
	var from_room := room_named(current)
	current = room[0]
	room_changed.emit(room[0], room[1])
	if from_room.is_empty():
		_set_limits(rect_of(room))
		return
	sliding = true
	var a := rect_of(from_room)
	var b := rect_of(room)
	var smoothing := camera.position_smoothing_enabled
	camera.position_smoothing_enabled = false
	var was_frozen: bool = hero.get(&"frozen")
	hero.set(&"frozen", true)
	var push := (b.get_center() - a.get_center()).normalized() * STEP_IN
	var t := create_tween().set_parallel()
	t.tween_method(func(k: float) -> void: _set_limits(Rect2(a.position.lerp(b.position, k), b.size)),
		0.0, 1.0, SLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(hero, "global_position", hero.global_position + push, SLIDE)
	await t.finished
	camera.position_smoothing_enabled = smoothing
	hero.set(&"frozen", was_frozen)
	sliding = false


func _set_limits(r: Rect2) -> void:
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)
