extends Node
## I massi di una zona (forest_zone.gd lo monta come "Boulders"), dai dati: BOULDERS. Il
## passo 5 del dungeon: "Some things are too heavy to move alone."
## - Un masso (2x2) si spinge camminandoci contro: tenendo la direzione per PUSH_TIME si
##   sposta di due celle (la sua larghezza), se dall'altra parte c'è posto. Pietra che
##   stride, polvere, la terra che trema.
## - La prima volta Lethe da sola non lo smuove (il dialogo "boulder_alone"): Selene le dice
##   di farlo insieme. Da lì Selene aiuta (la sua luce va al masso a ogni spinta). Il flag
##   "boulder_together".
## - Spinto tutto sopra la terra che crolla (zone_traps.gd), ci sprofonda: ne resta la cima a
##   filo del pavimento, e il buco diventa un ponte.
## Si ricorda dove sta ("boulder_<id>": [x, y]) e se è sprofondato ("boulder_<id>_sunk").

signal pushed(id: String)
signal sunk(id: String)

const ZoneDressing := preload("zone_dressing.gd")
const RoomTileset := preload("res://world/room_tileset.gd")
const ScreenShake := preload("res://fx/screen_shake.gd")
const Sparks := preload("res://fx/sparks.gd")
const Sfx := preload("res://core/sfx.gd")
const PUSH := preload("res://audio/boulder_push.wav")
const STRAIN := preload("res://audio/boulder_strain.wav")
const DIALOGUE := preload("res://dialogue/forest.dialogue")
const TILE := 32
const SIZE := Vector2i(2, 2)
## Quanto tenere la direzione contro il masso prima che si muova, e quanto ci mette.
const PUSH_TIME := 0.3
const SLIDE_TIME := 0.45

var zone: Node2D
## id -> Sprite2D
var boulders := {}
var _pressing := 0.0
var _sliding := false


func state() -> RefCounted:
	return zone.state


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	for entry in zone.layout_value("BOULDERS"):
		_add(entry[0], entry[1])


func _add(id: String, start: Vector2i) -> void:
	var cell := start
	var kept = state().flags.get("boulder_" + id)
	if kept is Array and kept.size() == 2:
		cell = Vector2i(int(kept[0]), int(kept[1]))
	if state().flag("boulder_%s_sunk" % id):
		_show_sunk(cell)
		for c in cells_of(cell):
			zone.traps.fill(c)
		return
	var sprite := ZoneDressing.thing_sprite(zone.data, "boulder", cell)
	sprite.name = "boulder_" + id
	sprite.set_meta(&"puzzle", true)
	sprite.set_meta(&"cell", cell)
	zone.world.add_child(sprite)
	ZoneDressing.build_thing(zone, sprite, zone.data)
	boulders[id] = sprite


func cell_of(id: String) -> Vector2i:
	return boulders[id].get_meta(&"cell")


static func cells_of(top_left: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			out.append(top_left + Vector2i(x, y))
	return out


func together() -> bool:
	return state().flag("boulder_together")


## Dal dialogo: d'ora in poi Selene aiuta.
func push_together() -> void:
	state().set_flag("boulder_together")


## Spinge il masso `id` verso `dir` (una direzione cardinale). Falso se non si è mosso.
func push(id: String, dir: Vector2i) -> bool:
	if _sliding or not boulders.has(id):
		return false
	var sprite: Sprite2D = boulders[id]
	if not together():
		_sfx_at(STRAIN, sprite.global_position, 1.0, -6.0)
		_shake(sprite)
		if not zone.talk.is_talking():
			zone.talk.say(DIALOGUE, "boulder_alone")
		return false
	var to: Vector2i = cell_of(id) + dir * SIZE.x
	if not has_room(id, to):
		_sfx_at(STRAIN, sprite.global_position, 1.2, -10.0)
		_shake(sprite)
		return false
	_slide(id, to)
	return true


## C'è posto per il masso con l'angolo in alto a sinistra in `to`? Tutto quello che blocca
## (terra, pareti, cose) no; un buco della terra crollata sì (ci sprofonda).
func has_room(id: String, to: Vector2i) -> bool:
	var space := zone.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(SIZE) * TILE - Vector2(6, 6)
	query.shape = box
	query.transform = Transform2D(0.0, (Vector2(to) + Vector2(SIZE) / 2.0) * TILE)
	query.collision_mask = RoomTileset.WORLD_LAYER | 2         # il mondo, e Lethe
	var own: StaticBody2D = _body(boulders[id])
	if own:
		query.exclude = [own.get_rid()]
	for hit in space.intersect_shape(query, 16):
		var other: Object = hit["collider"]
		if other is Node and (other as Node).is_in_group(&"pits"):
			continue
		return false
	return true


func _slide(id: String, to: Vector2i) -> void:
	_sliding = true
	var sprite: Sprite2D = boulders[id]
	var from: Vector2i = cell_of(id)
	sprite.set_meta(&"cell", to)
	state().flags["boulder_" + id] = [to.x, to.y]
	_sfx_at(PUSH, sprite.global_position, randf_range(0.92, 1.05), -2.0)
	_selene_helps(sprite)
	var target := sprite.position + Vector2(to - from) * TILE
	var t := sprite.create_tween()
	t.tween_property(sprite, "position", target, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dust(sprite.global_position, Vector2(from - to))
	await t.finished
	var shake := ScreenShake.new()
	shake.strength = 1.2
	shake.duration = 0.2
	get_tree().root.add_child(shake)
	_sliding = false
	pushed.emit(id)
	if cells_of(to).all(func(c: Vector2i) -> bool: return zone.traps.is_crumble(c)):
		_sink(id)


## Sopra la terra che crolla: la terra cede, il masso va giù e resta la cima.
func _sink(id: String) -> void:
	var sprite: Sprite2D = boulders[id]
	var cell: Vector2i = cell_of(id)
	for c in cells_of(cell):
		zone.traps.collapse(c)
	var t := sprite.create_tween().set_parallel()
	t.tween_property(sprite, "position:y", sprite.position.y + 18, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "modulate", Color(0.4, 0.4, 0.5, 0.0), 0.4)
	await t.finished
	for c in cells_of(cell):
		zone.traps.fill(c)
	sprite.queue_free()
	boulders.erase(id)
	state().set_flag("boulder_%s_sunk" % id)
	_show_sunk(cell)
	sunk.emit(id)


func _show_sunk(cell: Vector2i) -> void:
	var top := ZoneDressing.thing_sprite(zone.data, "boulder_sunk", cell)
	top.name = "boulder_sunk_%d_%d" % [cell.x, cell.y]
	zone.decor.add_child(top)                    # per terra: ci si cammina sopra


# --- Spingere camminando -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var hero: CharacterBody2D = zone.hero
	if _sliding or hero.frozen or hero.scripted or zone.talk.is_talking():
		_pressing = 0.0
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var id := _against(input)
	if id == "":
		_pressing = 0.0
		return
	_pressing += delta
	if _pressing >= PUSH_TIME:
		_pressing = 0.0
		push(id, _cardinal(input))


## Il masso contro cui Lethe sta spingendo con `input`, o "".
func _against(input: Vector2) -> String:
	if input.length() < 0.5:
		return ""
	var dir := _cardinal(input)
	var feet: Vector2 = zone.hero.global_position + Vector2(dir) * 10.0
	for id in boulders:
		var rect := Rect2(Vector2(cell_of(id)) * TILE, Vector2(SIZE) * TILE)
		if rect.has_point(feet):
			return id
	return ""


static func _cardinal(v: Vector2) -> Vector2i:
	if absf(v.x) >= absf(v.y):
		return Vector2i(int(signf(v.x)), 0)
	return Vector2i(0, int(signf(v.y)))


func _body(sprite: Sprite2D) -> StaticBody2D:
	for child in sprite.get_children():
		if child is StaticBody2D:
			return child
	return null


## Selene aiuta: la sua luce corre al masso.
func _selene_helps(sprite: Sprite2D) -> void:
	var selene: Node2D = zone.selene
	if selene == null:
		return
	selene.glow_up()
	var mote := Node2D.new()
	zone.add_child(mote)
	mote.global_position = selene.global_position
	var trail := Sparks.trail()
	mote.add_child(trail)
	trail.emitting = true
	var t := mote.create_tween()
	t.tween_property(mote, "global_position", sprite.global_position + Vector2(0, -30), 0.25)
	t.tween_callback(func() -> void: trail.emitting = false)
	t.tween_interval(trail.lifetime)
	t.tween_callback(mote.queue_free)


func _shake(sprite: Sprite2D) -> void:
	var t := sprite.create_tween()
	for dx in [2.0, -2.0, 1.0, 0.0]:
		t.tween_property(sprite, "offset:x", sprite.offset.x + dx, 0.05)


## La polvere che si alza dietro il masso, dal lato da cui viene.
func _dust(at: Vector2, back: Vector2) -> void:
	var dust := CPUParticles2D.new()
	dust.amount = 16
	dust.lifetime = 0.8
	dust.one_shot = true
	dust.explosiveness = 0.5
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(24, 4)
	dust.direction = back.normalized() if back != Vector2.ZERO else Vector2.UP
	dust.spread = 45.0
	dust.gravity = Vector2(0, -10)
	dust.initial_velocity_min = 15.0
	dust.initial_velocity_max = 40.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.48, 0.5, 0.6))
	ramp.set_color(1, Color(0.4, 0.34, 0.38, 0.0))
	dust.color_ramp = ramp
	dust.position = at + Vector2(0, -4)
	dust.z_index = 2
	zone.add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


func _sfx_at(stream: AudioStream, at: Vector2, pitch: float, db: float) -> void:
	if not zone.sound:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = db
	player.max_distance = 600.0
	player.position = at
	zone.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
