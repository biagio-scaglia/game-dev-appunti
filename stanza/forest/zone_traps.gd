extends Node
## Le trappole di una zona (forest_zone.gd lo monta come "Traps"), dai dati: SPIKES e
## CRUMBLE. Il passo 5 del dungeon. Si vedono arrivare tutte.
## - Le spine di radice a tempo: per terra tre buchi; ogni PERIOD secondi la terra trema e
##   spuntano le punte (WARN), poi escono radici appuntite (UP) e fanno male a chi c'è sopra,
##   poi si ritirano. Ogni punto ha il suo ritardo (i dati): in fila fanno un'onda, e si passa
##   aspettando il varco.
## - La terra che crolla: terreno crepato. Ci si mette piede e cede tutto il pezzo crepato
##   insieme (le crepe che si toccano): trema, si sbriciola e dopo CRUMBLE_DELAY crolla. Resta
##   un buco che blocca. Non si attraversa correndo: la striscia larga due celle chiede più
##   tempo di quanto regge. Chi c'era sopra cade (un pezzo di cuore)
##   e si ritrova dove era prima di metterci piede. Un masso spinto sopra ci sprofonda e il
##   buco diventa un ponte (fill(), dal masso: zone_boulders.gd). Si ricorda: "crumble_x_y"
##   ("pit" o "filled").

signal collapsed(cell: Vector2i)
signal fell
## Le spine l'hanno presa.
signal spiked

const ZoneDressing := preload("zone_dressing.gd")
const RoomTileset := preload("res://world/room_tileset.gd")
const ScreenShake := preload("res://fx/screen_shake.gd")
const Sfx := preload("res://core/sfx.gd")
const SPIKE_UP := preload("res://audio/spike_up.wav")
const SPIKE_WARN := preload("res://audio/spike_warn.wav")
const CRUMBLE := preload("res://audio/ground_crumble.wav")
const COLLAPSE := preload("res://audio/ground_collapse.wav")
const TILE := 32

## Le spine: un giro intero, quando cominciano a tremare, quando escono.
const PERIOD := 2.0
const WARN_AT := 0.9
const UP_AT := 1.35
## Le spine si sentono solo se Lethe è abbastanza vicina.
const HEAR_RANGE := 260.0
## Quanto regge la terra crepata dopo che ci si mette piede.
const CRUMBLE_DELAY := 0.3

var zone: Node2D
## cella -> {"sprite", "phase", "stage"}
var spikes := {}
## cella -> Sprite2D (crepa o buco); i buchi hanno il loro StaticBody2D.
var crumbles := {}
var _time := 0.0
var _cracking := {}
var _safe := Vector2.ZERO
var _falling := false


func state() -> RefCounted:
	return zone.state


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	for entry in zone.layout_value("SPIKES"):
		_add_spikes(entry[0], float(entry[1]))
	for cell in zone.layout_value("CRUMBLE"):
		_add_crumble(cell)
	_safe = zone.hero.global_position


# --- Le spine ---------------------------------------------------------------------------------

func _add_spikes(cell: Vector2i, phase: float) -> void:
	var sprite := ZoneDressing.thing_sprite(zone.data, "root_spikes_down", cell + Vector2i(0, -1))
	sprite.name = "spikes_%d_%d" % [cell.x, cell.y]
	sprite.set_meta(&"puzzle", true)
	zone.world.add_child(sprite)                # nel mondo: fuori sono alte, si ordinano con Lethe
	spikes[cell] = {"sprite": sprite, "phase": phase, "stage": "down"}


## A che punto è una spina adesso: "down", "warn" o "up".
func spike_stage(cell: Vector2i) -> String:
	var t := fmod(_time + float(spikes[cell]["phase"]), PERIOD)
	if t >= UP_AT:
		return "up"
	if t >= WARN_AT:
		return "warn"
	return "down"


func _update_spikes() -> void:
	var feet: Vector2 = zone.hero.global_position
	for cell in spikes:
		var spike: Dictionary = spikes[cell]
		var stage := spike_stage(cell)
		var sprite: Sprite2D = spike["sprite"]
		if stage != spike["stage"]:
			spike["stage"] = stage
			ZoneDressing.set_tile(sprite, zone.data, "root_spikes_" + stage)
			var near := sprite.global_position.distance_to(feet) < HEAR_RANGE
			if stage == "warn":
				_shiver(sprite)
				if near:
					_sfx_at(SPIKE_WARN, sprite.global_position, randf_range(0.9, 1.1), -16.0)
			elif stage == "up":
				sprite.scale = Vector2(1.0, 0.6)       # escono di scatto
				sprite.create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.08)
				if near:
					_sfx_at(SPIKE_UP, sprite.global_position, randf_range(0.9, 1.15), -9.0)
		if stage == "up" and _cell_rect(cell).grow(-4).has_point(feet):
			if zone.hero.hurt(1, _cell_rect(cell).get_center() + Vector2(0, 8)):
				spiked.emit()


## La terra trema: lo sprite vibra di un pixel.
func _shiver(sprite: Sprite2D) -> void:
	var t := sprite.create_tween()
	for dx in [1.0, -1.0, 1.0, -1.0, 0.0]:
		t.tween_property(sprite, "offset:x", sprite.offset.x + dx, 0.05)


# --- La terra che crolla -------------------------------------------------------------------------

func _add_crumble(cell: Vector2i) -> void:
	var kept := String(state().flags.get(_crumble_key(cell), ""))
	if kept == "filled":
		return
	var sprite := ZoneDressing.thing_sprite(zone.data, "cracked_floor", cell)
	sprite.name = "crumble_%d_%d" % [cell.x, cell.y]
	zone.decor.add_child(sprite)               # per terra: sotto Lethe
	crumbles[cell] = sprite
	if kept == "pit":
		_show_pit(cell)
		return
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2                    # la protagonista
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(TILE, TILE)             # appena ci mette piede
	shape.shape = box
	area.add_child(shape)
	area.position = _cell_rect(cell).get_center()
	area.name = "Step"
	zone.add_child(area)
	sprite.set_meta(&"area", area)
	area.body_entered.connect(func(body: Node) -> void:
		if body == zone.hero:
			crack(cell))


func _crumble_key(cell: Vector2i) -> String:
	return "crumble_%d_%d" % [cell.x, cell.y]


func is_crumble(cell: Vector2i) -> bool:
	return crumbles.has(cell)


func is_pit(cell: Vector2i) -> bool:
	return String(state().flags.get(_crumble_key(cell), "")) == "pit"


## Qualcuno ci ha messo piede: tutto il pezzo crepato (le crepe che si toccano) trema, si
## sbriciola, e dopo CRUMBLE_DELAY crolla insieme.
func crack(cell: Vector2i) -> void:
	if not crumbles.has(cell) or is_pit(cell) or _cracking.has(cell):
		return
	var group := connected(cell)
	for c in group:
		_cracking[c] = true
		_shiver(crumbles[c])
		_dirt(_cell_rect(c).get_center(), 3)
	_sfx_at(CRUMBLE, _cell_rect(cell).get_center(), randf_range(0.9, 1.1), -6.0)
	await get_tree().create_timer(CRUMBLE_DELAY).timeout
	var under := _on_crumble_cells(group, zone.hero.global_position)
	for c in group:
		collapse(c, false)
	if under:
		fall()


## Le crepe (non ancora crollate) che si toccano con `cell`, lei compresa.
func connected(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var todo: Array[Vector2i] = [cell]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if c in out or not crumbles.has(c) or is_pit(c):
			continue
		out.append(c)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			todo.append(c + d)
	return out


func _on_crumble_cells(cells: Array[Vector2i], at: Vector2) -> bool:
	for c in cells:
		if _cell_rect(c).grow(2).has_point(at):
			return true
	return false


## La terra crolla: resta un buco. Se Lethe è ancora lì sopra, cade (`check_fall`).
func collapse(cell: Vector2i, check_fall := true) -> void:
	_cracking.erase(cell)
	if not crumbles.has(cell) or is_pit(cell):
		return
	state().flags[_crumble_key(cell)] = "pit"
	_show_pit(cell)
	_sfx_at(COLLAPSE, _cell_rect(cell).get_center(), randf_range(0.9, 1.1), -4.0)
	_dirt(_cell_rect(cell).get_center(), 14)
	var shake := ScreenShake.new()
	shake.strength = 1.5
	shake.duration = 0.3
	get_tree().root.add_child(shake)
	collapsed.emit(cell)
	if check_fall and _cell_rect(cell).grow(2).has_point(zone.hero.global_position):
		fall()


func _show_pit(cell: Vector2i) -> void:
	var sprite: Sprite2D = crumbles[cell]
	ZoneDressing.set_tile(sprite, zone.data, "pit")
	if sprite.has_meta(&"area"):
		(sprite.get_meta(&"area") as Node).queue_free()
		sprite.remove_meta(&"area")
	var body := StaticBody2D.new()
	body.name = "Pit"
	body.collision_layer = RoomTileset.WORLD_LAYER
	body.add_to_group(&"pits")
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(TILE, TILE)
	shape.shape = box
	body.add_child(shape)
	body.position = _cell_rect(cell).get_center()
	zone.add_child(body)
	sprite.set_meta(&"body", body)


## Il masso è sprofondato qui: non c'è più né crepa né buco, si cammina (sopra c'è lui).
func fill(cell: Vector2i) -> void:
	if not crumbles.has(cell):
		return
	state().flags[_crumble_key(cell)] = "filled"
	var sprite: Sprite2D = crumbles[cell]
	if sprite.has_meta(&"body"):
		(sprite.get_meta(&"body") as Node).queue_free()
	if sprite.has_meta(&"area"):
		(sprite.get_meta(&"area") as Node).queue_free()
	sprite.queue_free()
	crumbles.erase(cell)


## Lethe cade nel buco: giù nel buio, un pezzo di cuore, e si ritrova dov'era prima.
func fall() -> void:
	if _falling:
		return
	_falling = true
	var hero: CharacterBody2D = zone.hero
	hero.frozen = true
	var sprite: Node2D = hero.sprite
	var t := sprite.create_tween().set_parallel()
	t.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "modulate", Color(0.2, 0.15, 0.25, 0.0), 0.35)
	await t.finished
	hero.global_position = _safe
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	hero.frozen = false
	hero.hurt(1, _safe + Vector2(0, -1))
	hero.set(&"knock", Vector2.ZERO)
	_falling = false
	fell.emit()


# --- Il giro ------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	if not spikes.is_empty():
		_update_spikes()
	if not _falling and not zone.hero.frozen and not _on_crumble(zone.hero.global_position):
		_safe = zone.hero.global_position


func _on_crumble(at: Vector2) -> bool:
	for cell in crumbles:
		if _cell_rect(cell).grow(6).has_point(at):
			return true
	return false


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))


func _dirt(at: Vector2, amount: int) -> void:
	var dirt := CPUParticles2D.new()
	dirt.amount = amount
	dirt.lifetime = 0.6
	dirt.one_shot = true
	dirt.explosiveness = 0.8
	dirt.local_coords = false
	dirt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dirt.emission_rect_extents = Vector2(12, 8)
	dirt.direction = Vector2.UP
	dirt.spread = 60.0
	dirt.gravity = Vector2(0, 200)
	dirt.initial_velocity_min = 20.0
	dirt.initial_velocity_max = 50.0
	dirt.color = Color(0.42, 0.34, 0.36)
	dirt.position = at
	dirt.z_index = 2
	zone.add_child(dirt)
	dirt.emitting = true
	dirt.finished.connect(dirt.queue_free)


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
