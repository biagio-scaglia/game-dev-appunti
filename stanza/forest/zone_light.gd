extends Node
## La luce di Lethe (gli MP) in una zona (forest_zone.gd lo monta come figlio "Light").
## La magia la spende (il costo è in menu_data.gd, SPELLS), la spada no: la verità costa, la
## bugia no. La luce torna:
## - piano, da sola (una luna ogni PASSIVE_EVERY secondi);
## - in fretta vicino a una luce (gruppo "light_sources": le lanterne accese, le pozze dei
##   raggi di luna): una luna ogni NEAR_EVERY secondi, e si vede il pulviscolo che vola dalla
##   luce a lei;
## - tutta, riposando (allo specchio, alla cornice d'argento: zone_combat.gd chiama restore());
## - un po' (TRUTH_GIFT) ogni volta che in un dialogo dice la verità.
## Piena, un suono di vetro piano. Senza luce la magia sfuma tra le mani e Selene lo dice
## (una volta). Le lune stanno sopra i cuori (ui/light_row.gd, nel HUD della zona).

const GameState := preload("res://menu/game_state.gd")
const Sparks := preload("res://fx/sparks.gd")
const Sfx := preload("res://core/sfx.gd")
const REFILL := preload("res://audio/light_refill.wav")

const PASSIVE_EVERY := 3.0
const NEAR_EVERY := 0.5
## Quanto vicino a una luce per prenderne (dai piedi di Lethe).
const NEAR_RANGE := 76.0
const TRUTH_GIFT := 2
const GROUP := &"light_sources"

var zone: Node2D
var _passive := 0.0
var _near := 0.0
var _truth_before := 0


func state() -> RefCounted:
	return zone.state


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	zone.hero.pay = pay
	zone.hero.fizzled.connect(func() -> void:
		if zone.story:
			zone.story.bark("no_light"))
	zone.talk.talk_started.connect(func(_id: String) -> void: _truth_before = state().truth)
	zone.talk.talk_finished.connect(func(_id: String) -> void:
		if state().truth > _truth_before:
			gain(TRUTH_GIFT))
	refresh()


## Lethe lancia l'incantesimo `spell_id`: paga la luce, o la fila delle lune trema.
func pay(spell_id: String) -> bool:
	var ok: bool = state().spend_mp(spell_id)
	if not ok:
		zone.hud.light_row.deny()
	refresh()
	return ok


## Le lune si vedono solo quando Lethe sa un incantesimo che costa luce.
func shown() -> bool:
	return state().learned.any(func(id: String) -> bool: return GameState.spell_cost(id) > 0)


func refresh() -> void:
	zone.hud.show_light(state().mp, state().MP_MAX, shown())


## La luce torna di `amount`. Piena: il suono di vetro.
func gain(amount: int) -> void:
	var got: int = state().gain_mp(amount)
	if got <= 0:
		return
	refresh()
	if state().mp >= state().MP_MAX and zone.sound:
		Sfx.play(zone, REFILL, 1.0, -8.0)


## Riposando: tutta.
func restore() -> void:
	gain(state().MP_MAX)


func _process(delta: float) -> void:
	if state().mp >= state().MP_MAX or zone.talk.is_talking() or not shown():
		_passive = 0.0
		_near = 0.0
		return
	var source := nearest_source()
	if source != Vector2.INF:
		_near += delta
		if _near >= NEAR_EVERY:
			_near = 0.0
			_mote(source)
			gain(1)
		return
	_passive += delta
	if _passive >= PASSIVE_EVERY:
		_passive = 0.0
		gain(1)


## Il punto della luce più vicina entro NEAR_RANGE (INF se nessuna).
func nearest_source() -> Vector2:
	var hero_at: Vector2 = zone.hero.global_position
	var best := Vector2.INF
	var best_d := NEAR_RANGE
	for node in get_tree().get_nodes_in_group(GROUP):
		var at: Vector2 = node.pool_point() if node.has_method(&"pool_point") else (node as Node2D).global_position
		var d := at.distance_to(hero_at)
		if d <= best_d:
			best_d = d
			best = at
	return best


## Il pulviscolo che vola dalla luce al petto di Lethe.
func _mote(from: Vector2) -> void:
	var mote := Node2D.new()
	zone.add_child(mote)
	mote.global_position = from + Vector2(randf_range(-6, 6), -8)
	var trail := Sparks.trail()
	trail.amount = 6
	mote.add_child(trail)
	trail.emitting = true
	var to: Vector2 = zone.hero.global_position + Vector2(0, -18)
	var t := mote.create_tween()
	t.tween_property(mote, "global_position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: trail.emitting = false)
	t.tween_interval(trail.lifetime)
	t.tween_callback(mote.queue_free)
