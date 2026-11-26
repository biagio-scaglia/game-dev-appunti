extends Node
## Le lanterne di radice e le tende di radici di una zona (forest_zone.gd lo monta come figlio
## "Lanterns"), dai dati: LANTERNS, CURTAINS, LANTERNS_OPEN. Il passo 4 del dungeon.
## - Una lanterna si accende con la luce della magia (il proiettile o le fiammelle la toccano:
##   magic/light_catch.gd). Senza magia la accende Selene, dal dialogo, e si stanca un po'.
##   Accesa fa luce calda e attira le falene (gruppo "lure"). Si ricorda: "lantern_<id>".
## - Una tenda di radici chiude una nicchia (e la lanterna dentro, che finché è chiusa la
##   luce non raggiunge). Si apre col gesto Aprire, dal dialogo: le radici si scostano, scende
##   la luna, e la luna accende la lanterna. Si ricorda: "curtain_<id>".
## - Tutte accese: "lanterns_lit", e il cancello LANTERNS_OPEN si apre (zone_puzzles.gd).
## Si risolve anche con sole bugie: Selene e il gesto bastano.

signal lantern_lit(id: String, by: String)
signal curtain_opened(id: String)
signal all_lit

const ZoneDressing := preload("zone_dressing.gd")
const RoomFx := preload("res://world/room_fx.gd")
const MoonBeam := preload("res://fx/moon_beam.gd")
const LightCatch := preload("res://magic/light_catch.gd")
const Fire := preload("res://fx/fire.gd")
const Sfx := preload("res://core/sfx.gd")
const GLINT := preload("res://audio/shard_glint.wav")
const RETRACT := preload("res://audio/roots_retract.wav")
const TILE := 32
## Dove la luce prende la lanterna (il mezzo, sopra i piedi) e da quanto lontano: tutta la
## lanterna, anche il piede (un colpo dal basso lo prende lì).
const CATCH_AT := Vector2(0, -32)
const CATCH_RADIUS := 42.0
## Quanto aspetta la luna, dopo che la tenda si apre, ad accendere la lanterna.
const MOON_DELAY := 0.7
## Dove sta la fiamma (la base), rispetto ai piedi della lanterna.
const FLAME_AT := Vector2(0, -29)


## Il punto della lanterna che prende luce: lo cercano le luci della magia.
class Catcher extends Node2D:
	var catch_radius := 42.0
	var on_catch: Callable

	func catch_point() -> Vector2:
		return global_position

	func catch_light() -> void:
		on_catch.call()


var zone: Node2D
## id -> Sprite2D: le lanterne e le tende.
var lanterns := {}
var curtains := {}


func state() -> RefCounted:
	return zone.state


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	for entry in zone.layout_value("LANTERNS"):
		_add_lantern(entry[0], entry[1])
	for entry in zone.layout_value("CURTAINS"):
		_add_curtain(entry[0], entry[1], entry[2])


# --- Le lanterne ----------------------------------------------------------------------------

func _add_lantern(id: String, cell: Vector2i) -> void:
	var sprite := _thing("root_lantern", cell)
	lanterns[id] = sprite
	var catcher := Catcher.new()
	catcher.name = "Catcher"
	catcher.position = CATCH_AT
	catcher.on_catch = func() -> void: light(id, "lethe")
	sprite.add_child(catcher)
	sprite.set_meta(&"catcher", catcher)
	if is_lit(id):
		_show_lit(id)
	else:
		catcher.add_to_group(LightCatch.GROUP)


func is_lit(id: String) -> bool:
	return state().flag("lantern_" + id)


func lit_count() -> int:
	return lanterns.keys().filter(is_lit).size()


func all_lanterns_lit() -> bool:
	return not lanterns.is_empty() and lit_count() == lanterns.size()


## Si accende (`by`: "lethe" con la sua luce, "selene", "moon" dalla tenda). Ignorato se è
## già accesa o se è ancora dietro una tenda chiusa (la luce non ci arriva).
func light(id: String, by: String) -> void:
	if not lanterns.has(id) or is_lit(id) or (by != "moon" and hidden(id)):
		return
	state().set_flag("lantern_" + id)
	_show_lit(id, true)
	_sfx(GLINT, 1.3, -6.0)
	_refresh_talk()
	lantern_lit.emit(id, by)
	if all_lanterns_lit() and not state().flag("lanterns_lit"):
		state().set_flag("lanterns_lit")
		var gate := String(zone.layout_value("LANTERNS_OPEN", ""))
		if gate != "":
			zone.puzzles.open_gate(gate)
		all_lit.emit()


## La lanterna è dietro una tenda ancora chiusa?
func hidden(id: String) -> bool:
	for curtain_id in curtains:
		var curtain: Sprite2D = curtains[curtain_id]
		if String(curtain.get_meta(&"lantern")) == id and not curtain_open(curtain_id):
			return true
	return false


## Accesa: il disegno, il fuoco animato, la luce. `now`: si è accesa adesso (la vampata).
func _show_lit(id: String, now := false) -> void:
	var sprite: Sprite2D = lanterns[id]
	ZoneDressing.set_tile(sprite, zone.data, "root_lantern_lit")
	var catcher: Node2D = sprite.get_meta(&"catcher")
	catcher.remove_from_group(LightCatch.GROUP)
	sprite.add_to_group(&"lure")                 # le falene vanno alla luce, gli occhi si chiudono
	sprite.add_to_group(&"light_sources")        # vicino, la luce (gli MP) torna in fretta
	var fire := Fire.new()
	fire.name = "Fire"
	fire.sound = zone.sound
	fire.position = FLAME_AT
	sprite.add_child(fire)
	var light := RoomFx.attach(zone, zone.data["tiles"]["root_lantern_lit"], ZoneDressing.thing_rect(sprite).position)
	if now:
		fire.ignite()
		if light:                                # la vampata: la luce si gonfia e torna
			var energy := light.energy
			light.energy = energy * 3.0
			light.create_tween().tween_property(light, "energy", energy, 0.9).set_trans(Tween.TRANS_SINE)


## Dai dialoghi, quando Lethe non ha più la magia: Selene accende la lanterna spenta più
## vicina a Lethe, e si stanca un po' (per sempre: "selene_tired").
func selene_light_lantern() -> void:
	var id := nearest_unlit()
	if id == "":
		return
	light(id, "selene")
	state().set_flag("selene_tired", int(state().flags.get("selene_tired", 0)) + 1)
	if zone.selene:
		zone.selene.tire()
		_give_light(zone.selene, lanterns[id])


## La luce che passa da Selene alla lanterna: una scia di pulviscolo che vola dall'una all'altra.
func _give_light(from: Node2D, to: Sprite2D) -> void:
	var mote := Node2D.new()
	zone.add_child(mote)
	mote.global_position = from.global_position
	var trail := preload("res://fx/sparks.gd").trail()
	mote.add_child(trail)
	trail.emitting = true
	var t := mote.create_tween()
	t.tween_property(mote, "global_position", to.global_position + FLAME_AT, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: trail.emitting = false)
	t.tween_interval(trail.lifetime)
	t.tween_callback(mote.queue_free)


## La lanterna spenta (e raggiungibile) più vicina a Lethe, o "".
func nearest_unlit() -> String:
	var best := ""
	var best_d := INF
	for id in lanterns:
		if is_lit(id) or hidden(id):
			continue
		var d: float = (lanterns[id] as Sprite2D).global_position.distance_to(zone.hero.global_position)
		if d < best_d:
			best_d = d
			best = id
	return best


# --- Le tende di radici ---------------------------------------------------------------------

func _add_curtain(id: String, cell: Vector2i, lantern: String) -> void:
	var opened := curtain_open(id)
	var sprite := _thing("root_curtain_open" if opened else "root_curtain", cell)
	sprite.set_meta(&"lantern", lantern)
	sprite.set_meta(&"base_y", sprite.position.y)
	curtains[id] = sprite
	_layer_curtain(sprite, opened)
	if opened:
		_add_moon(sprite)


## La tenda e la lanterna stanno nella stessa cella: chiusa, la tenda sta davanti (la copre);
## aperta, passa dietro (la nicchia buia è lo sfondo della lanterna). Nell'ordine dall'alto
## del mondo conta la y: la si sposta di un pixel, e il disegno resta dov'è.
func _layer_curtain(sprite: Sprite2D, opened: bool) -> void:
	var nudge := -1.0 if opened else 1.0
	sprite.position.y = float(sprite.get_meta(&"base_y")) + nudge
	sprite.offset.y = -sprite.texture.get_size().y - nudge


func curtain_open(id: String) -> bool:
	return state().flag("curtain_" + id)


## Dai dialoghi, col gesto Aprire: la tenda più vicina a Lethe si scosta, scende la luna e
## accende la lanterna che c'era dietro.
func open_curtain() -> void:
	var id := _nearest_closed_curtain()
	if id == "":
		return
	state().set_flag("curtain_" + id)
	var sprite: Sprite2D = curtains[id]
	for child in sprite.get_children():
		if child is StaticBody2D:
			child.queue_free()
	ZoneDressing.set_tile(sprite, zone.data, "root_curtain_open")
	_layer_curtain(sprite, true)
	_sfx(RETRACT, 1.2, -4.0)
	_add_moon(sprite)
	_refresh_talk()
	curtain_opened.emit(id)
	# La luna arriva poco dopo. Un timer e non un await: chi chiama (il dialogo) non aspetta.
	var lantern := String(sprite.get_meta(&"lantern"))
	if is_inside_tree():
		get_tree().create_timer(MOON_DELAY).timeout.connect(light.bind(lantern, "moon"))
	else:
		light(lantern, "moon")


func _nearest_closed_curtain() -> String:
	var best := ""
	var best_d := INF
	for id in curtains:
		if curtain_open(id):
			continue
		var d: float = (curtains[id] as Sprite2D).global_position.distance_to(zone.hero.global_position)
		if d < best_d:
			best_d = d
			best = id
	return best


## Il raggio di luna che scende nella nicchia aperta.
func _add_moon(sprite: Sprite2D) -> void:
	var beam := MoonBeam.new()
	beam.length = 60.0
	beam.slant = 6.0
	beam.top_width = 8.0
	beam.bottom_width = 30.0
	beam.fade_until = 0.2
	beam.unshaded = true
	beam.pool = true
	beam.color = Color(0.55, 0.67, 1.0, 0.09)
	beam.dust_amount = 12
	beam.z_index = 1
	beam.position = sprite.position + Vector2(-beam.slant, -beam.length)
	zone.add_child(beam)


# --- Con chi si parla -------------------------------------------------------------------------

## Le lanterne spente (raggiungibili) e le tende chiuse.
func talk_things() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in lanterns:
		if not is_lit(id) and not hidden(id):
			out.append({"id": "root_lantern", "rect": ZoneDressing.thing_rect(lanterns[id])})
	for id in curtains:
		if not curtain_open(id):
			out.append({"id": "root_curtain", "rect": ZoneDressing.thing_rect(curtains[id])})
	return out


func _thing(tile_name: String, cell: Vector2i) -> Sprite2D:
	var sprite := ZoneDressing.thing_sprite(zone.data, tile_name, cell)
	sprite.name = "%s_%d_%d" % [tile_name, cell.x, cell.y]
	sprite.set_meta(&"puzzle", true)
	zone.world.add_child(sprite)
	ZoneDressing.build_thing(zone, sprite, zone.data)
	return sprite


func _refresh_talk() -> void:
	if zone.talk:
		zone.talk.things = zone.talk_things()


func _sfx(stream: AudioStream, pitch: float, db: float) -> void:
	if zone.sound:
		Sfx.play(zone, stream, pitch, db)
