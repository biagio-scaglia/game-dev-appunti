extends "res://tests/base_test.gd"
## La prima zona della foresta: si carica con lo stato giusto, la camera si ferma ai bordi,
## gli alberi bloccano solo al tronco, il Lete blocca ma il ponte no, i rovi chiudono il
## ramo a nord, l'arrivo dalla caduta, l'uscita, e come ci si arriva (prologo, Continue).

const ZONE := "res://forest/zone_wake.tscn"
const Main := preload("res://main.gd")
const Layout := preload("res://forest/zone_wake_layout.gd")
const TILE := 32


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _zone(arrived := true) -> Node2D:
	Main.pending_save = {"flags": {"forest_arrived": arrived, "talk_learned": true, "selene_met": arrived}}
	var zone := add_scene(ZONE, func(n): n.sound = false)
	await tree.process_frame
	await tree.physics_frame
	return zone


## Se Lethe, messa in `from`, sbatte contro qualcosa muovendosi di `motion`.
func _blocked(zone: Node2D, from: Vector2, motion: Vector2) -> bool:
	var hero: CharacterBody2D = zone.hero
	hero.global_position = from
	return hero.test_move(hero.global_transform, motion)


## Fa andare avanti un dialogo fino alla fine, scegliendo sempre la risposta `choice`.
func _drive(talk: Node, choice := 0) -> void:
	var box: CanvasLayer = talk.box
	if not is_instance_valid(box):
		return
	box.sound = false
	for i in 300:
		await tree.process_frame
		if not is_instance_valid(box):
			break
		if box.choices_panel.visible:
			box.choose(mini(choice, box.choice_texts().size() - 1))
		elif box.waiting or box.text_label.is_typing:
			box.advance()
	await tree.physics_frame
	await tree.physics_frame


func test_la_zona_si_carica() -> void:
	var zone := await _zone()
	assert_eq(zone.state.place, "The Forest", "il posto")
	assert_eq(zone.hero.global_position, zone.spawn.global_position, "Lethe allo Spawn")
	assert_eq(zone.camera.limit_right, Layout.SIZE.x * TILE, "la camera si ferma a destra")
	assert_eq(zone.camera.limit_bottom, Layout.SIZE.y * TILE, "e in basso")
	assert_true(zone.camera.is_current(), "è la camera attiva")
	assert_true(zone.thing_nodes().size() == Layout.THINGS.size(), "tutte le cose")
	assert_true(zone.ground.get_used_cells().size() == Layout.SIZE.x * Layout.SIZE.y, "il terreno è pieno")
	assert_eq(zone.objective.text, zone.GOAL_PATH, "l'obiettivo")
	assert_true(Main.pending_save.is_empty(), "lo stato usato una volta")


func test_gli_alberi_bloccano_solo_al_tronco() -> void:
	var zone := await _zone()
	# L'albero in (6, 3): 2x3 celle, il tronco nella riga in basso (pixel y 160-192).
	var trunk_x := 7 * TILE
	assert_true(_blocked(zone, Vector2(trunk_x, 230), Vector2(0, -50)), "contro il tronco si sbatte")
	# L'albero in (12, 14): la chioma nelle righe 14-15, il tronco nella 16.
	assert_false(_blocked(zone, Vector2(10.5 * TILE, 15.5 * TILE), Vector2(4 * TILE, 0)),
		"sotto la chioma si passa")
	assert_true(_blocked(zone, Vector2(10.5 * TILE, 16.6 * TILE), Vector2(4 * TILE, 0)),
		"ma non attraverso il tronco")


func test_il_lete_blocca_ma_il_ponte_no() -> void:
	var zone := await _zone()
	var row_y := (Layout.BRIDGE[0] + 0.5) * TILE
	assert_false(_blocked(zone, Vector2(21.5 * TILE, row_y + 6), Vector2(6 * TILE, 0)), "sul ponte si passa")
	assert_true(_blocked(zone, Vector2(22 * TILE, 8.5 * TILE), Vector2(3 * TILE, 0)), "nell'acqua no")


func test_i_rovi_chiudono_il_ramo_a_nord() -> void:
	var zone := await _zone()
	assert_true(_blocked(zone, Vector2(15.5 * TILE, 9 * TILE), Vector2(0, -4 * TILE)), "i rovi bloccano")
	assert_true(_blocked(zone, Vector2(1.0 * TILE, 12 * TILE), Vector2(-2 * TILE, 0)), "il bosco fitto è un muro")


func test_l_arrivo_dalla_caduta() -> void:
	Engine.time_scale = 6.0
	var zone := await _zone(false)
	assert_true(zone.hero.frozen, "ferma mentre apre gli occhi")
	var deadline := Time.get_ticks_msec() + 4000
	while not zone.talk.is_talking() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_true(zone.talk.is_talking(), "poi racconta l'arrivo")
	await _drive(zone.talk)
	assert_true(zone.state.flag("forest_arrived"), "arrivata")
	deadline = Time.get_ticks_msec() + 4000
	while not zone.talk.is_talking() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_true(zone.selene != null, "poi scende Selene")
	assert_true(zone.talk.is_talking(), "e parla con Lethe")
	await _drive(zone.talk)
	assert_true(zone.state.flag("selene_met"), "incontrata")
	assert_true(await wait_signal(zone.story.arrived, 4.0), "la scena finisce")
	assert_false(zone.hero.frozen, "e si gioca")
	assert_eq(zone.objective.text, zone.GOAL_PATH, "segui il sentiero")


func test_si_parla_con_le_cose() -> void:
	var zone := await _zone()
	var ids: Array = zone.talk.things.map(func(t): return t["id"])
	for id in ["mirror", "brambles", "old_stone", "lethe"]:
		assert_true(id in ids, "si parla con %s" % id)
	zone.talk.talk("lethe")
	assert_true(zone.talk.is_talking(), "il Lete")
	await _drive(zone.talk)
	assert_false(zone.talk.is_talking(), "e finisce")


func test_l_uscita() -> void:
	Engine.time_scale = 8.0
	var zone := await _zone()
	zone._on_exit(zone.hero)
	var deadline := Time.get_ticks_msec() + 4000
	while not zone.talk.is_talking() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_true(zone.talk.is_talking(), "la camera guarda avanti, e racconta la strada che continua")
	await _drive(zone.talk)
	assert_true(await wait_signal(zone.exited, 3.0), "poi la zona finisce")


func test_dal_prologo_e_da_continue() -> void:
	var main := add_scene("res://main.tscn")
	await tree.process_frame
	main.music.stop()
	main.state.give("glass_sword")
	main._on_prologue_finished()
	assert_eq(String(Main.pending_save["place"]), "The Forest", "il prologo porta nella foresta")
	assert_true("glass_sword" in Main.pending_save["owned"], "con la scheggia")
	var title: Control = load("res://title/title_screen.tscn").instantiate()
	assert_eq(title.scene_after_start(), ZONE, "Continue da un salvataggio nella foresta: la foresta")
	Main.pending_save = {"place": "Her Room"}
	assert_eq(title.scene_after_start(), "res://main.tscn", "dalla stanza: la stanza")
	title.free()
	Main.pending_save = {"flags": {"forest_arrived": true, "selene_met": true}, "owned": ["black_dress", "glass_sword"],
		"equipped": {"weapon": "glass_sword", "body": "black_dress", "accessory": ""}}
	var armed := add_scene(ZONE, func(n): n.sound = false)
	await tree.process_frame
	assert_true(armed.hero.can_slash, "nella foresta la spada funziona")


func test_la_mappa() -> void:
	var v := Layout.vertices()
	assert_eq(v.size(), Layout.SIZE.y + 1, "una riga di vertici in più delle celle")
	assert_eq(Layout.cell_terrain(v, Layout.SPAWN)[0], "", "Lethe arriva sull'erba")
	for x in range(Layout.EXIT.position.x, Layout.EXIT.end.x):
		assert_true(Layout.cell_terrain(v, Vector2i(x, 11))[0] != "canopy", "l'uscita è aperta")
	var data := preload("res://world/forest/forest_tileset.gd").load_data()
	for entry in Layout.THINGS + Layout.DECOR:
		assert_true(data["tiles"].has(entry[0]), "%s è un tile" % entry[0])


# --- Selene ------------------------------------------------------------------------------

func _zone_before_selene() -> Node2D:
	Engine.time_scale = 6.0
	Main.pending_save = {"flags": {"forest_arrived": true, "talk_learned": true}}
	var zone := add_scene("res://forest/zone_wake.tscn", func(n): n.sound = false)
	var deadline := Time.get_ticks_msec() + 4000
	while not zone.talk.is_talking() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return zone


func test_dire_la_verita_a_selene_accende_la_magia() -> void:
	var zone := await _zone_before_selene()
	assert_true(zone.talk.is_talking(), "Selene scende e parla")
	assert_false(zone.state.knows(zone.FIRST_SPELL), "prima niente magia")
	await _drive(zone.talk, 1)
	assert_true(zone.state.knows(zone.FIRST_SPELL), "la verità: la luce nel palmo")
	assert_true(zone.hero.can_cast, "e la si può lanciare")
	assert_eq(zone.state.truth, 1, "una verità")


func test_mentire_a_selene_e_la_seconda_occasione_al_lete() -> void:
	var zone := await _zone_before_selene()
	await _drive(zone.talk, 0)
	await wait_signal(zone.story.arrived, 4.0)
	assert_false(zone.state.knows(zone.FIRST_SPELL), "la bugia: niente magia")
	assert_eq(zone.state.lies, 1, "una bugia")
	zone.talk.talk("lethe")
	await _drive(zone.talk, 1)
	assert_true(zone.state.knows(zone.FIRST_SPELL), "al Lete dire che fa paura è la prima verità")


func test_selene_segue_lethe() -> void:
	var zone := await _zone()
	assert_true(zone.selene != null, "dopo l'incontro c'è sempre")
	var start: Vector2 = zone.selene.global_position
	zone.hero.global_position += Vector2(200, 0)
	await wait_seconds(1.5)
	assert_true(zone.selene.global_position.distance_to(zone.selene.goal()) < 10.0, "la raggiunge")
	assert_true(zone.selene.global_position.x > start.x + 150.0, "si è spostata con lei")
	assert_true(zone.selene.global_position.y < zone.hero.global_position.y - 30.0, "sopra la testa")


func test_il_primo_nemico_ferma_tutto_e_selene_avvisa() -> void:
	Engine.time_scale = 6.0
	var zone := await _zone()
	var enemy: Node2D = zone.enemies()[0]
	zone.hero.global_position = enemy.global_position + Vector2(-100, 0)
	var deadline := Time.get_ticks_msec() + 3000
	while not zone.talk.is_talking() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_true(zone.state.flag("first_enemy_seen"), "la scena del primo nemico")
	assert_false(enemy.is_physics_processing(), "i nemici si fermano")
	assert_true(zone.hero.scripted, "Lethe la guida la scena")
	await _drive(zone.talk)
	deadline = Time.get_ticks_msec() + 3000
	while zone.story.cut.running and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_false(zone.hero.scripted or zone.hero.frozen, "poi si gioca")
	assert_true(enemy.is_physics_processing(), "e i nemici ripartono")


func test_le_battute_di_selene_una_volta_sola() -> void:
	var zone := await _zone()
	zone.story.bark("first_kill")
	assert_eq(zone.selene.bark_text(), zone.story.BARKS["first_kill"], "Selene lo dice")
	assert_true(zone.state.flag("bark_first_kill"), "e si ricorda di averlo detto (si salva)")
	zone.selene.bark("altro")
	zone.story.bark("first_kill")
	assert_eq(zone.selene.bark_text(), "altro", "non lo ridice")


func test_la_cutscene_ridà_i_comandi() -> void:
	var zone := await _zone()
	var cut: Node = zone.story.cut
	cut.pace = 0.1
	await cut.begin()
	assert_true(zone.hero.scripted, "durante la scena Lethe non si comanda")
	assert_true(cut._top.size.y > 0.0, "le bande nere")
	await cut.pan_to(zone.hero.global_position + Vector2(100, 0), 0.5)
	assert_true(zone.camera.offset.x > 50.0, "la camera guarda altrove")
	cut.emote(zone.hero, "!")
	await cut.walk(zone.hero, zone.hero.global_position + Vector2(20, 0))
	await cut.end()
	assert_false(zone.hero.scripted or zone.hero.frozen, "alla fine si gioca")
	assert_eq(zone.camera.offset, Vector2.ZERO, "la camera torna su Lethe")
	assert_eq(cut._top.size.y, 0.0, "le bande escono")


func test_selene_scende_una_volta_sola_dall_alto() -> void:
	Engine.time_scale = 4.0
	Main.pending_save = {"flags": {"forest_arrived": true, "talk_learned": true}}
	var zone := add_scene("res://forest/zone_wake.tscn", func(n): n.sound = false)
	var first_seen := Vector2.INF
	var appearances := 0
	var was_visible := false
	var deadline := Time.get_ticks_msec() + 5000
	while not zone.talk.is_talking() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		var s: Node2D = zone.selene
		var shown: bool = s != null and s.visible
		if shown and not was_visible:
			appearances += 1
			if first_seen == Vector2.INF:
				first_seen = s.global_position
		was_visible = shown
	assert_eq(appearances, 1, "compare una volta")
	assert_true(first_seen.y < zone.hero.global_position.y - 150.0, "e compare in alto, sopra Lethe (scende dal cielo)")
	assert_true(absf(first_seen.x - zone.hero.global_position.x) < 80.0, "non in un angolo della mappa")
