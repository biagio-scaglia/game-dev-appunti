extends "res://tests/base_test.gd"
## Il dungeon delle radici, passo 3: la piastra con l'impronta che apre il cancello di
## radici, la chiave della camera di Lethe, la porta della sua camera, la scatola da scarpe
## col filo rosso. Si ricordano dopo un salvataggio, e si risolvono anche con sole bugie.

const ZONE := "res://forest/zone_roots.tscn"
const Main := preload("res://main.gd")
const TILE := 32


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _zone(flags := {}, extra := {}) -> Node2D:
	var all := {"forest_arrived": true, "talk_learned": true, "selene_met": true, "roots_arrived": true,
		"first_enemy_seen": true, "slash_learned": true, "room_entrance": true}
	all.merge(flags, true)
	var data := {"zone": "roots", "entry": "top", "flags": all}
	data.merge(extra, true)
	Main.pending_save = data
	var zone := add_scene(ZONE, func(n): n.sound = false)
	await tree.process_frame
	for enemy in zone.enemies():                 # niente nemici tra i piedi
		enemy.queue_free()
	await tree.process_frame
	return zone


func _blocked(zone: Node2D, from: Vector2, motion: Vector2) -> bool:
	var hero: CharacterBody2D = zone.hero
	hero.global_position = from
	return hero.test_move(hero.global_transform, motion)


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


func test_la_piastra_apre_il_cancello() -> void:
	var zone := await _zone()
	var down := Vector2(9.5 * TILE, 21.6 * TILE)
	assert_true(_blocked(zone, down, Vector2(0, 3 * TILE)), "il cancello di radici chiude le spine")
	var plate: Area2D = zone.puzzles.plates["handprint"]
	zone.hero.global_position = plate.global_position
	for i in 6:
		await tree.physics_frame
	assert_true(zone.puzzles.is_pressed("handprint"), "salendoci sopra, la pietra affonda")
	assert_true(zone.state.flag("gate_thorns"), "e il cancello si ritira")
	assert_true(zone.talk.is_talking(), "la prima volta il racconto")
	await _drive(zone.talk)
	assert_false(_blocked(zone, down, Vector2(0, 3 * TILE)), "ora si passa")


func test_la_chiave() -> void:
	var zone := await _zone({"gate_thorns": true, "plate_handprint": true})
	var key: Area2D = zone.world.get_node("key_old_key")
	assert_true(key != null, "la chiave è per terra")
	assert_true(key.light != null and key.light.energy > 0.0, "e fa un po' di luce: si vede al buio")
	zone.hero.global_position = key.global_position
	for i in 4:
		await tree.physics_frame
	assert_false(zone.puzzles.has_key("old_key"), "passandoci sopra non si prende")
	var ids: Array = zone.talk.things.map(func(t): return t["id"])
	assert_true("old_key" in ids, "ci si parla")
	zone.talk.talk("old_key")
	await _drive(zone.talk)
	assert_true(zone.puzzles.has_key("old_key"), "parlandoci si raccoglie")
	assert_false(is_instance_valid(key), "e sparisce da terra")
	ids = zone.talk.things.map(func(t): return t["id"])
	assert_false("old_key" in ids, "e non ci si parla più")


func test_la_porta_della_camera() -> void:
	var zone := await _zone()
	var below := Vector2(49.5 * TILE, 21.5 * TILE)
	assert_true(_blocked(zone, below, Vector2(0, 4 * TILE)), "la porta chiude le cose sepolte")
	zone.puzzles.open_door("bedroom")
	assert_false(zone.puzzles.door_open("bedroom"), "senza la chiave non si apre")
	zone.state.set_flag("key_old_key")
	zone.talk.talk("bedroom_door")
	await _drive(zone.talk, 0)                   # "Use the key."
	assert_true(zone.puzzles.door_open("bedroom"), "con la chiave sì")
	await tree.physics_frame
	assert_false(_blocked(zone, below, Vector2(0, 4 * TILE)), "e si passa")
	var door: Sprite2D = zone.puzzles.doors["bedroom"]
	assert_eq(door.get_meta(&"tile"), "bedroom_door_open", "la porta aperta")


func test_la_scatola_e_il_filo_rosso() -> void:
	var zone := await _zone({"door_bedroom": true, "key_old_key": true})
	var before: int = zone.state.heart_max
	zone.state.heart = 1
	zone.talk.talk("shoebox")
	await _drive(zone.talk, 0)                   # "Open it."
	assert_true(zone.puzzles.box_open("shoebox"), "aperta")
	assert_eq(zone.state.heart_max, before + 1, "il cuore regge una stretta in più")
	assert_eq(zone.state.heart, zone.state.heart_max, "e torna intero")


func test_si_ricordano_dopo_un_salvataggio() -> void:
	var zone := await _zone({"plate_handprint": true, "gate_thorns": true, "key_old_key": true,
		"door_bedroom": true, "box_shoebox": true})
	assert_true(zone.puzzles.gates.is_empty(), "il cancello non c'è più")
	assert_eq(zone.puzzles.doors["bedroom"].get_meta(&"tile"), "bedroom_door_open", "la porta resta aperta")
	assert_eq(zone.puzzles.boxes["shoebox"].get_meta(&"tile"), "shoebox_open", "la scatola resta aperta")
	assert_false(zone.world.has_node("key_old_key"), "la chiave non torna per terra")
	assert_false(_blocked(zone, Vector2(49.5 * TILE, 21.5 * TILE), Vector2(0, 4 * TILE)), "si passa")


func test_si_parla_con_porta_scatola_e_cancello() -> void:
	var zone := await _zone()
	var ids: Array = zone.talk.things.map(func(t): return t["id"])
	for id in ["bedroom_door", "shoebox", "thorns_gate"]:
		assert_true(id in ids, "si parla con %s" % id)
	zone.puzzles.open_gate("thorns")
	ids = zone.talk.things.map(func(t): return t["id"])
	assert_false("thorns_gate" in ids, "aperto il cancello, non c'è più")


func test_anche_con_sole_bugie() -> void:
	# Una partita in cui Lethe ha mentito sempre: niente magia, mondo grigio, spada grande.
	var zone := await _zone({}, {"truth": 0, "lies": 6})
	assert_false(zone.state.can_cast(), "niente magia")
	zone.puzzles.press("handprint", "thorns")
	await _drive(zone.talk)
	zone.puzzles.take_key("old_key")
	await _drive(zone.talk)
	zone.talk.talk("bedroom_door")
	await _drive(zone.talk, 0)
	zone.talk.talk("shoebox")
	await _drive(zone.talk, 0)
	for flag in ["gate_thorns", "key_old_key", "door_bedroom", "box_shoebox"]:
		assert_true(zone.state.flag(flag), "anche mentendo: %s" % flag)
