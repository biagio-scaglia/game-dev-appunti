extends "res://tests/base_test.gd"
## Il dungeon delle radici, passo 4: le lanterne di radice (la luce di Lethe, o Selene che si
## stanca), la tenda di radici e il gesto Aprire dalla pietra antica, i rovi della radura,
## gli occhi nelle radici, e la veglia (le quattro fiammelle) che si impara accendendo le
## lanterne con la propria luce. Tutto si risolve anche con sole bugie.

const ROOTS := "res://forest/zone_roots.tscn"
const WAKE := "res://forest/zone_wake.tscn"
const Main := preload("res://main.gd")
const LightCatch := preload("res://magic/light_catch.gd")
const Vigil := preload("res://magic/vigil.gd")
const RootEye := preload("res://forest/root_eye.gd")
const TILE := 32

## Con la magia (la prima verità detta) o senza (sempre bugie).
const WITH_LIGHT := {"truth": 3, "lies": 0, "learned": ["truth_spark"], "spell": "truth_spark"}
const NO_LIGHT := {"truth": 0, "lies": 6}


## Un nemico finto: sta nel gruppo, sul livello dei nemici, e conta i colpi.
class Dummy extends StaticBody2D:
	var dead := false
	var hits := 0

	func _ready() -> void:
		collision_layer = 4
		add_to_group(&"enemies")
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(20, 20)
		shape.shape = box
		shape.position = Vector2(0, -10)
		add_child(shape)

	func hurt(amount: int, _kind: StringName, _from: Vector2) -> int:
		hits += 1
		return amount


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _zone(flags := {}, extra := WITH_LIGHT, path := ROOTS) -> Node2D:
	var all := {"forest_arrived": true, "talk_learned": true, "selene_met": true, "roots_arrived": true,
		"first_enemy_seen": true, "slash_learned": true, "room_entrance": true, "room_lanterns": true,
		"room_boulder": true, "room_heart": true, "room_thorns": true}
	all.merge(flags, true)
	var data := {"zone": "roots" if path == ROOTS else "wake", "entry": "top" if path == ROOTS else "",
		"flags": all}
	data.merge(extra, true)
	Main.pending_save = data
	var zone := add_scene(path, func(n): n.sound = false)
	await tree.process_frame
	for enemy in zone.enemies():
		enemy.queue_free()
	await tree.process_frame
	return zone


func _drive(talk: Node, pick := 0) -> void:
	for i in 400:
		await tree.process_frame
		var box = talk.box
		if not is_instance_valid(box):
			break
		box.sound = false
		if box.choices_panel.visible:
			box.choose(pick)
		elif box.waiting or box.text_label.is_typing:
			box.advance()
	await tree.physics_frame
	await tree.physics_frame


## Lethe davanti (sotto) a una lanterna o a una tenda.
func _stand_below(zone: Node2D, sprite: Sprite2D) -> void:
	zone.hero.global_position = sprite.global_position + Vector2(0, 20)
	zone.hero.facing = Vector2.UP


func _catch_point(zone: Node2D, id: String) -> Vector2:
	var sprite: Sprite2D = zone.lanterns.lanterns[id]
	return (sprite.get_meta(&"catcher") as Node2D).global_position


# --- Le lanterne ------------------------------------------------------------------------------

func test_la_luce_accende_la_lanterna() -> void:
	var zone := await _zone()
	var lit := [false]
	zone.lanterns.lantern_lit.connect(func(id: String, by: String) -> void: lit[0] = id == "west" and by == "lethe")
	LightCatch.touch(tree, _catch_point(zone, "west") + Vector2(0, 50))
	assert_false(zone.lanterns.is_lit("west"), "troppo lontano: niente")
	LightCatch.touch(tree, _catch_point(zone, "west") + Vector2(12, 8))
	assert_true(zone.lanterns.is_lit("west"), "la luce la tocca: si accende")
	assert_true(lit[0], "e lo dice, con chi l'ha accesa")
	var sprite: Sprite2D = zone.lanterns.lanterns["west"]
	assert_eq(sprite.get_meta(&"tile"), "root_lantern_lit", "si vede accesa")
	assert_true(sprite.is_in_group(&"lure"), "attira le falene")


func test_il_proiettile_accende_la_lanterna() -> void:
	var zone := await _zone()
	var shot: Area2D = preload("res://magic/projectile.tscn").instantiate()
	shot.direction = Vector2.UP
	zone.world.add_child(shot)
	shot.global_position = _catch_point(zone, "middle") + Vector2(0, 70)
	for i in 30:
		await tree.physics_frame
		if zone.lanterns.is_lit("middle"):
			break
	assert_true(zone.lanterns.is_lit("middle"), "la magia di Lethe la accende")


func test_dietro_la_tenda_la_luce_non_arriva() -> void:
	var zone := await _zone()
	assert_true(zone.lanterns.hidden("east"), "la terza è dietro la tenda")
	assert_true(zone.lanterns.curtains["east"].position.y > zone.lanterns.lanterns["east"].position.y,
		"chiusa, la tenda le sta davanti")
	LightCatch.touch(tree, _catch_point(zone, "east"))
	assert_false(zone.lanterns.is_lit("east"), "la luce non la raggiunge")
	var ids: Array = zone.talk.things.map(func(t): return t["id"])
	assert_true("root_curtain" in ids, "si parla con la tenda")


func test_selene_accende_e_si_stanca() -> void:
	var zone := await _zone({}, NO_LIGHT)
	assert_false(zone.state.can_cast(), "niente magia")
	_stand_below(zone, zone.lanterns.lanterns["west"])
	zone.talk.talk("root_lantern")
	await _drive(zone.talk)
	assert_true(zone.lanterns.is_lit("west"), "la accende Selene")
	assert_eq(int(zone.state.flags.get("selene_tired", 0)), 1, "e si stanca: si ricorda")
	assert_eq(zone.selene.tired, 1, "si vede")
	assert_true(zone.selene.base_energy() < 0.55, "ha meno luce")


func test_la_stanchezza_di_selene_resta() -> void:
	var zone := await _zone({"selene_tired": 2}, NO_LIGHT)
	assert_eq(zone.selene.tired, 2, "dopo un salvataggio è ancora stanca")


func test_con_la_luce_selene_lascia_fare_a_lethe() -> void:
	var zone := await _zone()
	_stand_below(zone, zone.lanterns.lanterns["west"])
	zone.talk.talk("root_lantern")
	await _drive(zone.talk)
	assert_false(zone.lanterns.is_lit("west"), "con la magia la accende Lethe, non Selene")
	assert_eq(int(zone.state.flags.get("selene_tired", 0)), 0, "Selene non si stanca")


# --- Il gesto Aprire e la tenda ---------------------------------------------------------------

func test_la_pietra_insegna_il_gesto() -> void:
	var zone := await _zone()
	assert_false(zone.story.knows_open(), "all'inizio no")
	zone.talk.talk("old_stone")
	await _drive(zone.talk)
	assert_true(zone.story.knows_open(), "la pietra antica insegna Aprire")
	assert_false(zone.story.stone_teaches(), "una volta sola")


func test_senza_il_gesto_la_tenda_resta_chiusa() -> void:
	var zone := await _zone()
	_stand_below(zone, zone.lanterns.curtains["east"])
	zone.talk.talk("root_curtain")
	await _drive(zone.talk)
	assert_false(zone.lanterns.curtain_open("east"), "non si apre")


func test_il_gesto_apre_la_tenda_e_la_luna_accende() -> void:
	var zone := await _zone({"gesture_open": true})
	var curtain: Sprite2D = zone.lanterns.curtains["east"]
	_stand_below(zone, curtain)
	zone.talk.talk("root_curtain")
	await _drive(zone.talk)
	assert_true(zone.lanterns.curtain_open("east"), "la tenda si apre")
	assert_eq(curtain.get_meta(&"tile"), "root_curtain_open", "si vede aperta")
	if not zone.lanterns.is_lit("east"):
		assert_true(await wait_signal(zone.lanterns.lantern_lit, 3.0), "poi la luna arriva")
	assert_true(zone.lanterns.is_lit("east"), "e accende la lanterna")
	var lantern: Sprite2D = zone.lanterns.lanterns["east"]
	assert_true(curtain.position.y < lantern.position.y, "aperta, la tenda passa dietro: la lanterna si vede")


# --- Tutte accese: l'arena, e la veglia ----------------------------------------------------------

func _light_all(zone: Node2D, by_selene := false) -> void:
	for id in ["west", "middle"]:
		if by_selene:
			_stand_below(zone, zone.lanterns.lanterns[id])
			zone.talk.talk("root_lantern")
			await _drive(zone.talk)
		else:
			LightCatch.touch(tree, _catch_point(zone, id))
	_stand_below(zone, zone.lanterns.curtains["east"])
	zone.talk.talk("root_curtain")
	await _drive(zone.talk)
	await wait_signal(zone.lanterns.all_lit, 3.0)
	await _drive(zone.talk)                       # il racconto delle lanterne


func test_tutte_accese_aprono_l_arena_e_danno_la_veglia() -> void:
	var zone := await _zone({"gesture_open": true, "heart_seen": true, "gate_thorns": true,
		"key_old_key": true, "door_bedroom": true})
	var hero: CharacterBody2D = zone.hero
	hero.global_position = Vector2(29.5 * TILE, 15.5 * TILE)
	assert_true(hero.test_move(hero.global_transform, Vector2(0, -3 * TILE)), "prima: l'arena è chiusa")
	await _light_all(zone)
	assert_true(zone.state.flag("lanterns_lit"), "tutte accese")
	assert_true(zone.state.flag("gate_arena"), "il cancello dell'arena si apre")
	assert_true(zone.state.knows("vigil"), "la luce di Lethe: le fiammelle vengono da lei")
	assert_eq(zone.state.spell, "vigil", "e vanno subito su Q")
	assert_eq(zone.hero.spell, "vigil", "Lethe la lancia")
	assert_eq(zone.objective.text, zone.story.GOAL_DEER, "l'obiettivo: verso il cervo")
	for i in 40:
		await tree.physics_frame
	hero.global_position = Vector2(29.5 * TILE, 15.5 * TILE)
	assert_false(hero.test_move(hero.global_transform, Vector2(0, -3 * TILE)), "dopo: si passa")


func test_anche_con_sole_bugie() -> void:
	var zone := await _zone({}, NO_LIGHT)
	zone.talk.talk("old_stone")
	await _drive(zone.talk)
	await _light_all(zone, true)
	assert_true(zone.state.flag("gate_arena"), "anche mentendo l'arena si apre")
	assert_false(zone.state.knows("vigil"), "ma la veglia no: le ha accese Selene")
	assert_eq(zone.selene.tired, 2, "e Selene ha pagato due volte")


func test_si_ricordano_dopo_un_salvataggio() -> void:
	var zone := await _zone({"lantern_west": true, "curtain_east": true, "lantern_east": true})
	assert_true(zone.lanterns.is_lit("west"), "la lanterna resta accesa")
	assert_eq(zone.lanterns.lanterns["west"].get_meta(&"tile"), "root_lantern_lit", "e si vede")
	assert_eq(zone.lanterns.curtains["east"].get_meta(&"tile"), "root_curtain_open", "la tenda resta aperta")
	assert_false(zone.lanterns.is_lit("middle"), "quella mai accesa no")


# --- I rovi della radura --------------------------------------------------------------------------

func _brambles(zone: Node2D) -> Sprite2D:
	for sprite in zone.thing_nodes():
		if String(sprite.get_meta(&"tile")).begins_with("brambles"):
			return sprite
	return null


func test_il_gesto_apre_i_rovi_della_radura() -> void:
	var zone := await _zone({"gesture_open": true}, {}, WAKE)
	var brambles := _brambles(zone)
	_stand_below(zone, brambles)
	var hero: CharacterBody2D = zone.hero
	assert_true(hero.test_move(hero.global_transform, Vector2(0, -2 * TILE)), "prima i rovi chiudono")
	zone.talk.talk("brambles")
	await _drive(zone.talk)
	assert_eq(brambles.get_meta(&"tile"), "brambles_open", "si scostano")
	_stand_below(zone, brambles)
	assert_false(hero.test_move(hero.global_transform, Vector2(0, -1 * TILE)), "e si passa")
	var ids: Array = zone.talk.things.map(func(t): return t["id"])
	assert_false("brambles" in ids, "aperti non dicono più che sono chiusi")


func test_i_rovi_restano_aperti() -> void:
	var zone := await _zone({"gesture_open": true}, {}, WAKE)
	var brambles := _brambles(zone)
	var key: String = zone.puzzles._brambles_key(brambles)
	zone.queue_free()
	await tree.process_frame
	var again := await _zone({"gesture_open": true, key: true}, {}, WAKE)
	assert_eq(_brambles(again).get_meta(&"tile"), "brambles_open", "dopo un salvataggio restano aperti")


func test_senza_il_gesto_i_rovi_restano() -> void:
	var zone := await _zone({}, {}, WAKE)
	_stand_below(zone, _brambles(zone))
	zone.talk.talk("brambles")
	await _drive(zone.talk)
	assert_eq(_brambles(zone).get_meta(&"tile"), "brambles", "chiusi")


# --- Gli occhi nelle radici ---------------------------------------------------------------------

func test_gli_occhi_si_aprono_al_buio_e_la_luce_li_chiude() -> void:
	var zone := await _zone()
	var eyes: Array = tree.get_nodes_in_group(&"root_eyes").filter(func(e): return zone.is_ancestor_of(e))
	assert_true(eyes.size() >= 6, "ci sono gli occhi")
	var eye: Node2D = eyes[0]
	zone.hero.global_position = eye.global_position + Vector2(40, 60)
	await tree.create_timer(1.0).timeout          # tempo vero: in headless i frame volano
	assert_true(eye.is_open(), "Lethe vicina, al buio: si apre")
	var light := Node2D.new()
	light.add_to_group(&"lure")
	zone.add_child(light)
	light.global_position = eye.global_position + Vector2(30, 0)
	await tree.create_timer(0.6).timeout
	assert_true(eye.openness < 0.05, "una luce vicina: si chiude")
	light.queue_free()
	zone.hero.global_position = eye.global_position + Vector2(0, 400)
	await tree.create_timer(1.0).timeout
	assert_true(eye.openness < 0.05, "Lethe lontana: resta chiuso")


# --- La veglia -------------------------------------------------------------------------------------

func test_le_fiammelle_girano_poi_partono() -> void:
	var zone := await _zone()
	var vigil: Node2D = Vigil.new()
	vigil.caster = zone.hero
	vigil.facing = Vector2.RIGHT
	zone.world.add_child(vigil)
	await tree.physics_frame
	assert_eq(vigil.flames.size(), 4, "quattro fiammelle")
	for i in 12:
		await tree.physics_frame
	assert_eq(vigil.circling(), 4, "prima le girano attorno")
	var d: float = (vigil.flames[0] as Node2D).global_position.distance_to(vigil.global_position)
	assert_near(d, Vigil.RADIUS, 8.0, "a distanza")
	zone.hero.global_position += Vector2(40, 0)
	await tree.physics_frame
	await tree.physics_frame
	d = (vigil.flames[1] as Node2D).global_position.distance_to(vigil.global_position)
	assert_near(d, Vigil.RADIUS, 8.0, "e la seguono se si muove")
	var launched := false
	for i in 120:
		await tree.physics_frame
		if vigil.circling() == 0:
			launched = true
			break
	assert_true(launched, "poi partono tutte")


func test_le_fiammelle_cercano_i_nemici() -> void:
	var zone := await _zone()
	var hero: CharacterBody2D = zone.hero
	var dummy := Dummy.new()
	zone.world.add_child(dummy)
	dummy.global_position = hero.global_position + Vector2(-90, 10)     # dietro di lei
	var vigil: Node2D = Vigil.new()
	vigil.caster = hero
	vigil.facing = Vector2.RIGHT
	zone.world.add_child(vigil)
	for i in 150:
		await tree.physics_frame
		if dummy.hits >= 4:
			break
	assert_eq(dummy.hits, 4, "tutte e quattro lo trovano, anche se Lethe guarda dall'altra parte")


func test_lethe_lancia_la_veglia_una_alla_volta() -> void:
	var zone := await _zone({}, {"truth": 3, "lies": 0, "learned": ["truth_spark", "vigil"], "spell": "vigil"})
	var hero: CharacterBody2D = zone.hero
	assert_eq(hero.spell, "vigil", "su Q c'è la veglia")
	hero.cast()
	for i in 60:
		await tree.physics_frame
		if is_instance_valid(hero.vigil):
			break
	assert_true(is_instance_valid(hero.vigil), "partono le fiammelle")
	var first: Node2D = hero.vigil
	await wait_signal(hero.attack_finished, 2.0)
	hero.cast()
	await tree.physics_frame
	assert_false(hero.is_attacking(), "finché girano non se ne lancia un'altra")
	assert_eq(hero.vigil, first, "è sempre la stessa veglia")
