extends Node
## Il regista delle cutscene: piccoli passi da mettere in fila con `await`, così una scena si
## scrive come un copione.
##
##   var cut := Cutscene.new()
##   add_child(cut)
##   cut.setup(hero, camera, talk, [hud, objective])
##   await cut.begin()                       # bande nere, Lethe ferma, l'interfaccia via
##   await cut.pan_to(punto, 1.2)            # la camera guarda là
##   cut.emote(hero, "!")
##   await cut.walk(hero, punto2)
##   await cut.say(DIALOGO, "cue")
##   await cut.pan_back(0.8)
##   await cut.end()                         # tutto come prima, si gioca
##
## `pace` accorcia tutte le attese (i test lo mettono basso).

const Emote := preload("res://fx/emote.gd")

## Quanto sono alte le bande nere (pixel dello schermo, 640 x 360).
const BAR_HEIGHT := 30.0
const BAR_TIME := 0.45

var hero: CharacterBody2D
var camera: Camera2D
var talk: Node
## Le cose dell'interfaccia da nascondere durante la scena (con set_shown o visible).
var ui: Array = []
var pace := 1.0
var running := false

var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _camera_base := Vector2.ZERO


func setup(hero_node: CharacterBody2D, camera_node: Camera2D, talk_node: Node, ui_nodes: Array = []) -> void:
	hero = hero_node
	camera = camera_node
	talk = talk_node
	ui = ui_nodes


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)
	_top = _bar()
	_bottom = _bar()
	_bottom.position.y = 360.0


func _bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.size = Vector2(640, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bar)
	return bar


## Comincia: le bande nere entrano, Lethe si ferma (guidata dalla scena), l'interfaccia sparisce.
func begin() -> void:
	running = true
	if hero:
		hero.set(&"scripted", true)
		hero.set(&"frozen", true)
		hero.call(&"update_animation", Vector2.ZERO, false)
	if camera:
		_camera_base = camera.offset
	_show_ui(false)
	await _bars(BAR_HEIGHT)


## Finisce: le bande escono, la camera torna su Lethe, si gioca.
func end() -> void:
	if camera and camera.offset != _camera_base:
		await pan_back(0.5)
	await _bars(0.0)
	_show_ui(true)
	if hero:
		hero.set(&"scripted", false)
		hero.set(&"frozen", false)
	running = false


func _bars(height: float) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_top, "size:y", height, BAR_TIME * pace)
	t.tween_property(_bottom, "size:y", height, BAR_TIME * pace)
	t.tween_property(_bottom, "position:y", 360.0 - height, BAR_TIME * pace)
	await t.finished


func _show_ui(shown: bool) -> void:
	for node in ui:
		if not is_instance_valid(node):
			continue
		if node.has_method(&"set_shown"):
			node.set_shown(shown)
		else:
			node.visible = shown


## La camera guarda `world_point` (resta dentro i bordi della zona da sola).
func pan_to(world_point: Vector2, time := 1.0) -> void:
	if camera == null:
		return
	var holder: Node2D = camera.get_parent()
	var goal: Vector2 = world_point - holder.global_position - camera.position
	var t := create_tween()
	t.tween_property(camera, "offset", goal, time * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## La camera torna su Lethe.
func pan_back(time := 0.8) -> void:
	if camera == null:
		return
	var t := create_tween()
	t.tween_property(camera, "offset", _camera_base, time * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## Lethe (o un altro attore con update_animation) cammina fino a `to`, poi si ferma.
func walk(actor: Node2D, to: Vector2, speed := 60.0) -> void:
	var dir := (to - actor.global_position)
	if dir.length() < 1.0:
		return
	if actor.has_method(&"update_animation"):
		actor.update_animation(dir.normalized(), false)
	var t := create_tween()
	t.tween_property(actor, "global_position", to, dir.length() / speed * pace)
	await t.finished
	if actor.has_method(&"update_animation"):
		actor.update_animation(Vector2.ZERO, false)


## Si gira verso `dir` (resta ferma).
func face(actor: Node2D, dir: Vector2) -> void:
	if actor.has_method(&"update_animation"):
		actor.update_animation(dir.normalized(), false)
		actor.update_animation(Vector2.ZERO, false)


## Una nuvoletta sopra la testa: "!", "?", "...". Non aspetta.
func emote(actor: Node2D, kind: String, height := 62.0) -> Node2D:
	return Emote.pop(actor, kind, height)


## Un dialogo, fino alla fine. Lethe resta guidata dalla scena anche dopo.
func say(resource: Resource, cue: String) -> void:
	if talk == null:
		return
	talk.say(resource, cue)
	await talk.talk_finished
	if hero and running:
		hero.set(&"scripted", true)
		hero.set(&"frozen", true)


func wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds * pace).timeout
