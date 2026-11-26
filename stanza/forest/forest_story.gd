extends Node
## La regia del capitolo 1 nella foresta (vault: "Trama - bozza"), come prologue.gd per la
## stanza. La zona (forest_zone.gd) fa il mondo; qui le scene e Selene:
## - l'arrivo: dal nero la camera scende dalle chiome a Lethe per terra, le schegge che
##   brillano, lei si guarda intorno ("?"), il racconto; poi Selene scende dalla luna, Lethe
##   la vede ("!"), e la prima scelta del capitolo (la verità accende la magia);
## - il primo nemico: la prima volta che una falena (o un rovo, una lucciola) è vicino, tutto
##   si ferma, la camera lo guarda, e Selene avvisa;
## - le battute di Selene durante il gioco (bark): il primo colpo preso, il cuore quasi
##   finito, il primo nemico sciolto, il livello, la mela, il silenzio dopo una bugia.
##   Ognuna una volta sola (flag "bark_<chiave>", si salva);
## - l'uscita della prima zona: la camera guarda avanti, verso l'albero bianco;
## - la radura dell'albero secco (zona "tree"): la prima volta la camera va sull'albero, la
##   luna che ci cade sopra; Lethe lo riconosce. Il buco tra le radici porta giù;
## - il dungeon delle radici (zona "roots"): la prima volta la discesa raccontata, Selene che
##   fa un po' di luce; entrando in una stanza nuova il suo nome e una riga sola (il dungeon
##   racconta la pianta che nessuno annaffia più: l'annaffiatoio mai usato, il cuore che
##   batte ancora); il cuore delle radici cambia l'obiettivo.
##
## Sta tra gli extra_states dei dialoghi: forest.dialogue chiama selene_met() e learn_truth().
## `pace` accorcia le attese (test).

const Cutscene := preload("res://core/cutscene.gd")
const Selene := preload("res://characters/selene/selene.gd")
const Sparks := preload("res://fx/sparks.gd")
const Sfx := preload("res://core/sfx.gd")
const MenuData := preload("res://menu/menu_data.gd")
const InputSetup := preload("res://core/input_setup.gd")
const DIALOGUE := preload("res://dialogue/forest.dialogue")
const GLINT := preload("res://audio/shard_glint.wav")

## L'incantesimo della prima verità.
const FIRST_SPELL := "truth_spark"
## Gli obiettivi della radura dell'albero.
const GOAL_TREE := "Reach the dead tree"
const GOAL_ROOTS := "Go down between the roots"
## Gli obiettivi del dungeon delle radici.
const GOAL_HEART := "Find the heart of the roots"
const GOAL_DEER := "Find a way past the roots"
## Dopo il cuore, i meccanismi uno alla volta (zone_puzzles.gd): così si sa sempre cosa fare.
const GOAL_THORNS := "Open the thorn passage"
const GOAL_KEY := "Look behind the thorns"
const GOAL_DOOR := "Find the door the key opens"
## Le stanze del dungeon: la riga che compare sotto il nome, la prima volta.
const ROOM_LINES := {
	"entrance": "The roots she never watered.",
	"heart": "Everything dry is still holding on.",
	"lanterns": "Light, if someone brings it.",
	"boulder": "Some things are too heavy to move alone.",
	"thorns": "It hurts to go forward. It hurts to stay.",
	"buried": "What you hide, stays.",
	"arena": "Something sleeps where the light can't reach.",
}
const FALL := preload("res://audio/fall_whoosh.wav")
## Quanto vicino deve arrivare un nemico perché parta la scena del primo nemico.
const FIRST_ENEMY_RANGE := 150.0
## Le battute di Selene: chiave -> riga.
const BARKS := {
	"first_hit": "Lethe! Your heart-",
	"low_heart": "Please. Rest at the mirror.",
	"first_kill": "...One less shadow.",
	"level": "You feel lighter. I can see it.",
	"apple": "When did you last eat?",
	"lie": "...",
	"full_apple": "Keep it for later.",
}

signal arrived

var zone: Node2D
var pace := 1.0
var cut: Cutscene


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	cut = Cutscene.new()
	cut.name = "Cutscene"
	add_child(cut)
	cut.setup(zone.hero, zone.camera, zone.talk, [zone.hud, zone.objective])
	zone.hero.damaged.connect(_on_hero_damaged)
	zone.leveled_up.connect(func(_lv: int) -> void: bark("level"))
	zone.enemy_defeated.connect(func(_e: Node2D) -> void: bark("first_kill"))
	zone.item_picked.connect(func(_id: String) -> void: bark("apple"))
	# I meccanismi del dungeon fanno andare avanti l'obiettivo.
	for done in [zone.puzzles.gate_opened, zone.puzzles.key_taken, zone.puzzles.door_opened]:
		done.connect(func(_id: String) -> void: _update_roots_goal())


func state() -> RefCounted:
	return zone.state


# --- Selene ------------------------------------------------------------------------------

func spawn_selene() -> Node2D:
	if zone.selene == null:
		var s := Selene.new()
		s.name = "Selene"
		s.target = zone.hero
		zone.add_child(s)
		zone.selene = s
	return zone.selene


## Per i dialoghi: Selene c'è già?
func selene_met() -> bool:
	return state().flag("selene_met")


## La prima verità: nel palmo si accende la luce (la magia). Dai dialoghi.
func learn_truth() -> void:
	if state().knows(FIRST_SPELL):
		return
	state().learn(FIRST_SPELL)
	zone.sync_abilities()
	if zone.selene:
		zone.selene.glow_up()
	_sfx(GLINT, 1.6, -4.0)
	zone.toast(String(MenuData.spell(FIRST_SPELL).get("name", "Light")),
		"%s  Throw the light" % InputSetup.LABELS[&"cast"])


## Una battuta di Selene, una volta sola per partita (si salva nei flag).
func bark(key: String) -> void:
	if zone.selene == null or cut.running or zone.talk.is_talking():
		return
	if state().flag("bark_" + key):
		return
	state().set_flag("bark_" + key)
	zone.selene.bark(BARKS[key])


func _on_hero_damaged(_amount: int, _from: Vector2) -> void:
	# Il cuore si aggiorna dopo questo segnale: si guarda al frame dopo.
	await get_tree().process_frame
	if state().heart == 1:
		bark("low_heart")
	else:
		bark("first_hit")


## Dopo un dialogo: se Lethe ha appena mentito, Selene non dice niente (ma si vede).
func after_talk(lies_before: int) -> void:
	if state().lies > lies_before:
		bark("lie")


# --- Le scene ----------------------------------------------------------------------------

## La prima volta: dal nero, la camera scende dalle chiome fino a Lethe per terra; lei si
## guarda intorno; poi Selene. Alla fine si gioca e c'è l'obiettivo.
func arrive() -> void:
	var black := _black_layer()
	await cut.begin()
	cut.face(zone.hero, Vector2.DOWN)
	zone.camera.offset = Vector2(0, -170)                # si parte guardando le chiome
	zone.camera.reset_smoothing()
	await cut.wait(0.6)
	var open := create_tween()
	open.tween_property(black, "color:a", 0.0, 2.0 * pace).set_trans(Tween.TRANS_SINE)
	await cut.pan_back(3.0)
	black.get_parent().queue_free()
	var glass := Sparks.shards(18)
	glass.global_position = zone.hero.global_position + Vector2(0, -10)
	zone.world.add_child(glass)
	glass.emitting = true
	glass.finished.connect(glass.queue_free)
	_sfx(GLINT, 0.8, -6.0)
	await cut.wait(0.9)
	state().set_flag("forest_arrived")
	await cut.say(DIALOGUE, "arrive")
	cut.face(zone.hero, Vector2.LEFT)
	await cut.wait(0.5)
	cut.face(zone.hero, Vector2.RIGHT)
	await cut.wait(0.5)
	cut.emote(zone.hero, "?")
	await cut.wait(0.9)
	await _selene_scene()
	await cut.end()
	_after_selene()


## Selene scende dalla luna (anche da sola: un salvataggio di prima che ci fosse).
func meet_selene() -> void:
	await cut.begin()
	await _selene_scene()
	await cut.end()
	_after_selene()


func _selene_scene() -> void:
	cut.face(zone.hero, Vector2.DOWN)
	spawn_selene().wait_hidden()             # compare solo quando scende
	_sfx(GLINT, 1.3, -6.0)
	await cut.pan_to(zone.hero.global_position + Vector2(-20, -90), 1.0)
	zone.selene.descend(pace)
	await cut.wait(1.0)
	await cut.pan_back(1.2)
	cut.emote(zone.hero, "!")
	cut.face(zone.hero, Vector2(1, -1))
	await cut.wait(0.8)
	await cut.say(DIALOGUE, "selene_meet")
	state().set_flag("selene_met")           # subito: i dialoghi dopo lo sanno già


func _after_selene() -> void:
	state().set_flag("selene_met")
	zone.objective.show_text(zone.GOAL_PATH)
	arrived.emit()


## La zona è pronta: la scena giusta per dove si è (la prima volta), o solo l'obiettivo.
func zone_ready(_from_travel: bool) -> void:
	match zone.zone_id:
		"tree":
			if not state().flag("tree_arrived"):
				enter_tree.call_deferred()
			else:
				zone.objective.show_text(tree_goal())
		"roots":
			if not state().flag("roots_arrived"):
				enter_roots.call_deferred()
			else:
				zone.objective.show_text(roots_goal())
		_:
			if not state().flag("forest_arrived"):
				arrive()
			elif not selene_met():
				meet_selene.call_deferred()      # un salvataggio di prima che arrivasse Selene
			else:
				zone.objective.show_text(zone.GOAL_PATH)


func tree_goal() -> String:
	return GOAL_ROOTS if state().flag("tree_seen") else GOAL_TREE


## Prima di passare in un'altra zona: la prima volta verso l'albero, la camera guarda avanti.
func before_travel(to_zone: String) -> void:
	if zone.zone_id == "wake" and to_zone == "tree" and not state().flag("tree_glimpse"):
		state().set_flag("tree_glimpse")
		await leave_scene()


## La prima volta nella radura dell'albero: la camera va sull'albero secco, la luna sopra;
## Lethe lo riconosce.
func enter_tree() -> void:
	await cut.begin()
	cut.face(zone.hero, Vector2.RIGHT)
	await cut.wait(0.6)
	var tree_cell: Vector2i = zone.layout_value("TREE", Vector2i.ZERO)
	await cut.pan_to(Vector2(tree_cell) * zone.TILE + Vector2(48, 64), 2.2)
	await cut.wait(0.8)
	cut.emote(zone.hero, "...")
	await cut.say(DIALOGUE, "tree_arrive")
	await cut.pan_back(1.4)
	await cut.end()
	state().set_flag("tree_arrived")
	zone.objective.show_text(GOAL_TREE)
	arrived.emit()


## Dopo un dialogo con una cosa: l'albero visto cambia l'obiettivo.
func on_talk(id: String) -> void:
	if id == "dead_tree" and not state().flag("tree_seen"):
		state().set_flag("tree_seen")
		zone.objective.show_text(GOAL_ROOTS)


## Dai dialoghi (il buco tra le radici): si scende nel dungeon.
func go_down() -> void:
	state().set_flag("roots_entered")
	_sfx(FALL, 0.8, -6.0)
	zone.call_deferred(&"travel", "roots", "top")


## L'obiettivo nel dungeon: il cuore, poi la piastra che apre le spine, la chiave dietro le
## spine, la porta della camera; aperta quella, un modo per passare le radici dell'arena.
func roots_goal() -> String:
	var s := state()
	if not s.flag("heart_seen"):
		return GOAL_HEART
	if not s.flag("gate_thorns"):
		return GOAL_THORNS
	if not s.flag("key_old_key"):
		return GOAL_KEY
	if not s.flag("door_bedroom"):
		return GOAL_DOOR
	return GOAL_DEER


func _update_roots_goal() -> void:
	if zone.zone_id == "roots" and state().flag("roots_arrived"):
		zone.objective.show_text(roots_goal())


## La prima volta sottoterra: il nero, il tonfo, la luce che scende dal buco; Lethe si
## guarda intorno, e il racconto. Poi il nome della prima stanza.
func enter_roots() -> void:
	var black := _black_layer()
	await cut.begin()
	cut.face(zone.hero, Vector2.DOWN)
	await cut.wait(0.9)
	var shake := preload("res://fx/screen_shake.gd").new()
	shake.strength = 2.0
	get_tree().root.add_child(shake)
	var open := create_tween()
	open.tween_property(black, "color:a", 0.0, 2.2 * pace).set_trans(Tween.TRANS_SINE)
	await open.finished
	black.get_parent().queue_free()
	cut.emote(zone.hero, "?")
	await cut.wait(0.6)
	cut.face(zone.hero, Vector2.UP)
	await cut.pan_to(zone.hero.global_position + Vector2(0, -90), 1.4)
	await cut.wait(0.5)
	await cut.say(DIALOGUE, "roots_arrive")
	await cut.pan_back(1.0)
	await cut.end()
	state().set_flag("roots_arrived")
	zone.objective.show_text(GOAL_HEART)
	arrived.emit()


## Si entra in una stanza del dungeon: la prima volta il suo nome e la sua riga.
func on_room(id: String, room_name: String) -> void:
	var key := "room_" + id
	if state().flag(key):
		return
	state().set_flag(key)
	zone.toast(room_name, ROOM_LINES.get(id, ""))


## Dai dialoghi: il cuore delle radici visto.
func saw_heart() -> void:
	state().set_flag("heart_seen")
	zone.objective.show_text(roots_goal())


## Il primo nemico: si ferma tutto, la camera lo guarda, Selene avvisa. Una volta sola.
func check_first_enemy() -> void:
	if state().flag("first_enemy_seen") or cut.running or zone.talk.is_talking() \
			or not selene_met() or zone.hero.get(&"frozen"):
		return
	for enemy in zone.enemies():
		if enemy.global_position.distance_to(zone.hero.global_position) < FIRST_ENEMY_RANGE:
			first_enemy(enemy)
			return


func first_enemy(enemy: Node2D) -> void:
	state().set_flag("first_enemy_seen")
	for e in zone.enemies():
		e.set_physics_process(false)
	await cut.begin()
	cut.emote(zone.hero, "!")
	cut.face(zone.hero, enemy.global_position - zone.hero.global_position)
	await cut.pan_to(enemy.global_position + Vector2(0, -16), 0.9)
	await cut.wait(0.5)
	await cut.say(DIALOGUE, "first_enemy")
	await cut.end()
	for e in zone.enemies():
		e.set_physics_process(true)


## L'uscita: la camera guarda avanti, verso l'albero bianco; Selene e Lethe; poi la zona
## chiude il capitolo per ora.
func leave_scene() -> void:
	await cut.begin()
	cut.face(zone.hero, Vector2.RIGHT)
	await cut.pan_to(zone.hero.global_position + Vector2(240, -20), 1.6)
	await cut.wait(0.6)
	await cut.say(DIALOGUE, "exit")
	await cut.pan_back(1.0)
	cut.running = false                       # la zona fa il nero e il resto


# --- Pezzi -------------------------------------------------------------------------------

func _black_layer() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 60
	zone.add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(640, 360)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	return black


func _sfx(stream: AudioStream, pitch: float, db: float) -> void:
	if zone.sound:
		Sfx.play(zone, stream, pitch, db)
