extends Node
## I meccanismi di una zona (forest_zone.gd lo monta come figlio "Puzzles"), dai dati della
## zona: piastre (PLATES), cancelli di radici (GATES), chiavi (KEYS), porte chiuse (LOCKS) e
## scatole (CHESTS). Li crea quando la zona parte e si ricorda nei flag della partita cosa è
## già aperto (così dopo un salvataggio la porta resta aperta):
## - la piastra: Lethe ci sale sopra, la pietra affonda, il suo cancello si ritira (le
##   radici scivolano via); la prima volta il racconto ("plate_<id>", "gate_<id>");
## - la chiave: per terra, luccica e fa un po' di luce; ci si parla (il fumetto sopra la
##   testa) e si raccoglie col suo racconto ("key_<id>");
## - la porta: si parla, e con la chiave si apre ("door_<id>");
## - la scatola: si parla, si apre, dentro un oggetto ("box_<id>"). Il filo rosso
##   (heart_thread) fa reggere al cuore una stretta in più;
## - i tesori (TREASURES): un oggetto per terra che luccica, si raccoglie parlandoci
##   ("item_<id>"); la Moon Pearl dietro la terra che crolla fa durare di più la luce;
## - i rovi (il tile "brambles", messi nella scena): col gesto Aprire si scostano e lasciano
##   passare ("brambles_<zona>_<x>_<y>"). Nella prima radura chiudono la nicchia della pietra.
## Niente qui ha bisogno della magia: si risolve anche dicendo solo bugie.
##
## I dialoghi (forest.dialogue) lo usano: has_key(), door_open(), open_door(), box_open(),
## open_box(), open_brambles() (sta tra gli extra_states dei dialoghi).

signal gate_opened(id: String)
signal key_taken(id: String)
signal door_opened(id: String)
signal box_opened(id: String)
signal brambles_opened

const ZoneDressing := preload("zone_dressing.gd")
const ScreenText := preload("res://ui/screen_text.gd")
const ScreenShake := preload("res://fx/screen_shake.gd")
const Pickup := preload("res://items/pickup.gd")
const ItemIcons := preload("res://ui/item_icons.gd")
const Sfx := preload("res://core/sfx.gd")
const DIALOGUE := preload("res://dialogue/forest.dialogue")
const CREAK := preload("res://audio/door_creak.wav")
const RETRACT := preload("res://audio/roots_retract.wav")
const CLICK := preload("res://audio/stone_click.wav")
const GLINT := preload("res://audio/shard_glint.wav")
const TILE := 32

var zone: Node2D
## id -> nodi: le piastre (Area2D), i cancelli (Sprite2D), le porte, le scatole.
var plates := {}
var gates := {}
var doors := {}
var boxes := {}
## Le chiavi ancora per terra (id -> Area2D).
var keys := {}
## I tesori ancora per terra (id -> Area2D).
var treasures := {}


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	for entry in zone.layout_value("GATES"):
		if not state().flag("gate_" + entry[0]):
			gates[entry[0]] = entry[1].map(func(cell: Vector2i) -> Sprite2D: return _thing("root_gate", cell))
	for entry in zone.layout_value("PLATES"):
		_add_plate(entry[0], entry[1], entry[2])
	for entry in zone.layout_value("KEYS"):
		if not has_key(entry[0]):
			_add_key(entry[0], entry[1])
	for entry in zone.layout_value("TREASURES"):
		if not state().flag("item_" + entry[0]):
			_add_treasure(entry[0], entry[1])
	for entry in zone.layout_value("LOCKS"):
		doors[entry[0]] = _thing("bedroom_door_open" if door_open(entry[0]) else "bedroom_door", entry[2])
		doors[entry[0]].set_meta(&"key", entry[1])
	for sprite in zone.thing_nodes():
		if sprite.get_meta(&"tile") == "brambles" and state().flag(_brambles_key(sprite)):
			_show_brambles_open(sprite)
	for entry in zone.layout_value("CHESTS"):
		boxes[entry[0]] = _thing("shoebox_open" if box_open(entry[0]) else "shoebox", entry[1])
		boxes[entry[0]].set_meta(&"item", entry[2])


func state() -> RefCounted:
	return zone.state


func _sfx(stream: AudioStream, pitch := 1.0, db := 0.0) -> void:
	if zone.sound:
		Sfx.play(zone, stream, pitch, db)


## Una cosa nel mondo (col suo corpo, se blocca).
func _thing(tile_name: String, cell: Vector2i) -> Sprite2D:
	var sprite := ZoneDressing.thing_sprite(zone.data, tile_name, cell)
	sprite.name = "%s_%d_%d" % [tile_name, cell.x, cell.y]
	sprite.set_meta(&"puzzle", true)            # ci si parla da qui (talk_things), non dal tile
	zone.world.add_child(sprite)
	ZoneDressing.build_thing(zone, sprite, zone.data)
	return sprite


## Le cose con cui si parla: le porte, le scatole e i cancelli ancora chiusi.
func talk_things() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in doors:
		out.append({"id": "bedroom_door", "rect": ZoneDressing.thing_rect(doors[id])})
	for id in boxes:
		out.append({"id": "shoebox", "rect": ZoneDressing.thing_rect(boxes[id])})
	for id in keys:
		var item: Node2D = keys[id]
		out.append({"id": id, "rect": Rect2(item.position - Vector2(16, 28), Vector2(32, 32))})
	for id in treasures:
		var item: Node2D = treasures[id]
		out.append({"id": id, "rect": Rect2(item.position - Vector2(16, 28), Vector2(32, 32))})
	for id in gates:
		for sprite in gates[id]:
			out.append({"id": "%s_gate" % id, "rect": ZoneDressing.thing_rect(sprite)})
	return out


# --- La piastra e il cancello -----------------------------------------------------------------

func _add_plate(id: String, cell: Vector2i, gate: String) -> void:
	var pressed: bool = state().flag("plate_" + id)
	var sprite := ZoneDressing.thing_sprite(zone.data, "pressure_plate_down" if pressed else "pressure_plate", cell)
	sprite.name = "plate_" + id
	# Per terra: figlia delle piante basse, quindi sopra il pavimento e sotto Lethe. (Con
	# z_index -1 dentro World finiva sotto il pavimento, e non si vedeva.)
	zone.decor.add_child(sprite)
	if not pressed:
		ZoneDressing.build_thing(zone, sprite, zone.data)   # l'impronta brilla appena: si trova
		var pulse := sprite.create_tween().set_loops()      # e respira piano: chiede di salirci
		pulse.tween_property(sprite, "modulate", Color(1.7, 1.55, 1.9), 1.1).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(sprite, "modulate", Color.WHITE, 1.1).set_trans(Tween.TRANS_SINE)
		sprite.set_meta(&"pulse", pulse)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2                     # la protagonista
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(20, 16)
	shape.shape = box
	area.add_child(shape)
	area.position = ZoneDressing.thing_rect(sprite).get_center()
	zone.add_child(area)
	plates[id] = area
	area.set_meta(&"sprite", sprite)
	if not pressed:
		area.body_entered.connect(func(body: Node) -> void:
			if body == zone.hero:
				press(id, gate))


func is_pressed(id: String) -> bool:
	return state().flag("plate_" + id)


## Lethe sale sulla piastra: la pietra affonda (scatta), il cancello si ritira; la prima
## volta il racconto.
func press(id: String, gate: String) -> void:
	if is_pressed(id):
		return
	state().set_flag("plate_" + id)
	var sprite: Sprite2D = plates[id].get_meta(&"sprite")
	if sprite.has_meta(&"pulse"):
		(sprite.get_meta(&"pulse") as Tween).kill()
		sprite.modulate = Color.WHITE
	ZoneDressing.set_tile(sprite, zone.data, "pressure_plate_down")
	_sfx(CLICK, 1.0, -2.0)
	open_gate(gate)
	if not zone.talk.is_talking():
		zone.talk.say(DIALOGUE, "plate_" + id)


## Le radici del cancello scivolano via (si schiacciano e svaniscono), il passaggio è libero.
func open_gate(id: String) -> void:
	if state().flag("gate_" + id):
		return
	state().set_flag("gate_" + id)
	_sfx(RETRACT, 0.9, -2.0)
	var shake := ScreenShake.new()
	shake.strength = 1.5
	shake.duration = 0.5
	get_tree().root.add_child(shake)
	for sprite in gates.get(id, []):
		for child in sprite.get_children():
			if child is StaticBody2D:
				child.queue_free()               # il passaggio si libera subito
		var t: Tween = sprite.create_tween().set_parallel()
		t.tween_property(sprite, "scale", Vector2(1.0, 0.1), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(sprite, "modulate:a", 0.0, 0.6)
		t.chain().tween_callback(sprite.queue_free)
	gates.erase(id)
	_refresh_talk()
	gate_opened.emit(id)


# --- La chiave e la porta --------------------------------------------------------------------

func _add_key(id: String, cell: Vector2i) -> void:
	var item: Area2D = Pickup.new()
	item.id = id
	item.name = "key_" + id
	item.position = (Vector2(cell) + Vector2(0.5, 0.8)) * TILE
	item.auto_pick = false                      # si raccoglie parlandoci
	item.expires = false                        # e aspetta: non sparisce come una mela
	item.glow = Color(1.0, 0.82, 0.45)
	zone.world.add_child(item)
	keys[id] = item


func has_key(id: String) -> bool:
	return state().flag("key_" + id)


## Dai dialoghi (o direttamente): la chiave è presa, sparisce da terra.
func take_key(id: String) -> void:
	if has_key(id):
		return
	state().set_flag("key_" + id)
	if keys.has(id):
		keys[id].queue_free()
		keys.erase(id)
		_refresh_talk()
	_sfx(GLINT, 0.8, -4.0)
	ScreenText.toast(zone, ItemIcons.info(id).get("name", id), "Heavy and cold. And familiar.")
	key_taken.emit(id)
	if not zone.talk.is_talking():
		zone.talk.say(DIALOGUE, "%s_found" % id)


func door_open(id: String) -> bool:
	return state().flag("door_" + id)


## Dai dialoghi: la porta si apre con la sua chiave (se Lethe ce l'ha).
func open_door(id: String) -> void:
	var door: Sprite2D = doors.get(id)
	if door == null or door_open(id) or not has_key(String(door.get_meta(&"key"))):
		return
	state().set_flag("door_" + id)
	_sfx(CREAK, 1.0, -2.0)
	for child in door.get_children():
		if child is StaticBody2D:
			child.queue_free()
	ZoneDressing.set_tile(door, zone.data, "bedroom_door_open")
	door_opened.emit(id)


# --- La scatola ----------------------------------------------------------------------------------

func box_open(id: String) -> bool:
	return state().flag("box_" + id)


## Dai dialoghi: la scatola si apre, e quello che c'è dentro è di Lethe.
func open_box(id: String) -> void:
	var box: Sprite2D = boxes.get(id)
	if box == null or box_open(id):
		return
	state().set_flag("box_" + id)
	ZoneDressing.set_tile(box, zone.data, "shoebox_open")
	give(String(box.get_meta(&"item")))
	box_opened.emit(id)


## Un oggetto trovato: il filo rosso (il cuore regge una stretta in più), la Moon Pearl (la
## luce dura di più: una luna in più, e tutte piene).
func give(item: String) -> void:
	var info: Dictionary = ItemIcons.info(item)
	var effect: Dictionary = info.get("effect", {})
	var s: RefCounted = state()
	var line := "Something of hers, found again."
	if effect.has("max_heart"):
		s.heart_max = mini(s.HEART_CAP, s.heart_max + int(effect["max_heart"]))
		s.heal(s.heart_max)
		zone.hud.show_heart(s.heart, s.heart_max)
		line = "Her heart holds one more."
	if effect.has("max_light"):
		s.mp_max = mini(s.MP_CAP, s.mp_max + int(effect["max_light"]))
		s.mp = s.mp_max
		if zone.light:
			zone.light.refresh()
		line = "Her light lasts a little longer."
	_sfx(GLINT, 0.9, -4.0)
	ScreenText.toast(zone, info.get("name", item), line)


# --- I tesori ----------------------------------------------------------------------------------

func _add_treasure(id: String, cell: Vector2i) -> void:
	var item: Area2D = Pickup.new()
	item.id = id
	item.name = "treasure_" + id
	item.position = (Vector2(cell) + Vector2(0.5, 0.8)) * TILE
	item.auto_pick = false
	item.expires = false
	item.glow = Color(0.75, 0.82, 1.0)
	zone.world.add_child(item)
	treasures[id] = item


## Dai dialoghi: il tesoro si raccoglie, sparisce da terra e fa il suo effetto.
func take_treasure(id: String) -> void:
	if state().flag("item_" + id):
		return
	state().set_flag("item_" + id)
	if treasures.has(id):
		treasures[id].queue_free()
		treasures.erase(id)
		_refresh_talk()
	give(id)


func _refresh_talk() -> void:
	if zone.talk:
		zone.talk.things = zone.talk_things()


# --- I rovi -----------------------------------------------------------------------------------

## Fin dove Lethe arriva ad aprire i rovi (pixel, dai piedi).
const BRAMBLES_REACH := 72.0


func _brambles_key(sprite: Sprite2D) -> String:
	var cell := Vector2i((sprite.position / TILE).floor())
	return "brambles_%s_%d_%d" % [zone.zone_id, cell.x, cell.y]


## Dai dialoghi, col gesto Aprire: i rovi chiusi più vicini a Lethe si scostano.
func open_brambles() -> void:
	var best: Sprite2D = null
	var best_d := BRAMBLES_REACH
	for sprite in zone.thing_nodes():
		if sprite.get_meta(&"tile") != "brambles":
			continue
		var d: float = sprite.global_position.distance_to(zone.hero.global_position)
		if d < best_d:
			best_d = d
			best = sprite
	if best == null:
		return
	state().set_flag(_brambles_key(best))
	_show_brambles_open(best)
	_sfx(RETRACT, 1.3, -4.0)
	_refresh_talk()
	brambles_opened.emit()


func _show_brambles_open(sprite: Sprite2D) -> void:
	for child in sprite.get_children():
		if child is StaticBody2D:
			child.queue_free()
	ZoneDressing.set_tile(sprite, zone.data, "brambles_open")
