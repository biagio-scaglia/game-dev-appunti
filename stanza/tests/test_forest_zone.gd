extends "res://tests/base_test.gd"
## La prima zona della foresta: si carica con lo stato giusto, la camera si ferma ai bordi,
## gli alberi bloccano solo al tronco, il Lete blocca ma il ponte no, i rovi chiudono il
## ramo a nord, l'arrivo dalla caduta, l'uscita, e come ci si arriva (prologo, Continue).

const ZONE := "res://forest/zone_wake.tscn"
const Main := preload("res://main.gd")
const Layout := preload("res://forest/zone_wake_layout.gd")
const ZoneLayout := preload("res://forest/zone_layout.gd")
const Zones := preload("res://forest/zones.gd")
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
	assert_true(await wait_signal(zone.traveled, 3.0), "poi si va nella radura dell'albero")
	assert_eq(String(Main.pending_save.get("zone")), "tree", "verso la zona dell'albero")
	assert_eq(String(Main.pending_save.get("entry")), "west", "entrando da ovest")


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


func test_le_mappe() -> void:
	var data := preload("res://world/forest/forest_tileset.gd").load_data()
	for zone_id in Zones.SCENES:
		var layout: GDScript = Zones.layout(zone_id)
		var v := ZoneLayout.vertices(layout)
		var size: Vector2i = ZoneLayout.value(layout, "SIZE")
		assert_eq(v.size(), size.y + 1, "%s: una riga di vertici in più delle celle" % zone_id)
		assert_true(ZoneLayout.cell_terrain(v, ZoneLayout.value(layout, "SPAWN"))[0] in ["", "path"],
			"%s: si arriva sull'erba o sul sentiero" % zone_id)
		for exit in ZoneLayout.value(layout, "EXITS"):
			var cells: Rect2i = exit[0]
			var mid := cells.position + cells.size / 2
			assert_true(ZoneLayout.cell_terrain(v, mid)[0] != "canopy", "%s: l'uscita verso %s è aperta" % [zone_id, exit[1]])
			var there: GDScript = Zones.layout(exit[1])
			assert_true(ZoneLayout.value(there, "ENTRIES", {}).has(exit[2]), "%s: dall'altra parte c'è l'entrata %s" % [zone_id, exit[2]])
		for entry in ZoneLayout.value(layout, "ENTRIES", {}).values():
			assert_eq(ZoneLayout.cell_terrain(v, entry)[0] in ["", "path"], true, "%s: l'entrata è libera" % zone_id)
		for entry in ZoneLayout.value(layout, "THINGS") + ZoneLayout.value(layout, "DECOR"):
			assert_true(data["tiles"].has(entry[0]), "%s: %s è un tile" % [zone_id, entry[0]])


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
	await cut.pan_to(zone.hero.global_position + Vector2(400, 0), 0.5)
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


# --- La radura dell'albero secco ---------------------------------------------------------

func _tree_zone(flags := {}) -> Node2D:
	var all_flags := {"forest_arrived": true, "talk_learned": true, "selene_met": true}
	all_flags.merge(flags, true)
	Main.pending_save = {"place": "The Forest", "zone": "tree", "entry": "west", "flags": all_flags}
	var zone := add_scene("res://forest/zone_tree.tscn", func(n): n.sound = false)
	await tree.process_frame
	return zone


func test_la_radura_dell_albero_la_prima_volta() -> void:
	Engine.time_scale = 6.0
	var zone := await _tree_zone()
	assert_eq(zone.zone_id, "tree", "la zona dell'albero")
	var entry: Vector2i = zone.layout_value("ENTRIES")["west"]
	assert_true(zone.hero.global_position.distance_to(ZoneLayout.cell_center(entry)) < 1.0, "si arriva da ovest")
	var deadline := Time.get_ticks_msec() + 4000
	while not zone.talk.is_talking() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_true(zone.talk.is_talking(), "la camera va sull'albero, e Lethe lo riconosce")
	await _drive(zone.talk)
	assert_true(await wait_signal(zone.story.arrived, 4.0), "la scena finisce")
	assert_true(zone.state.flag("tree_arrived"), "una volta sola")
	assert_eq(zone.objective.text, zone.story.GOAL_TREE, "l'obiettivo: l'albero")
	assert_eq(zone.state.zone, "tree", "lo stato sa in che zona è")


func test_l_albero_e_il_buco_tra_le_radici() -> void:
	var zone := await _tree_zone({"tree_arrived": true})
	var ids: Array = zone.talk.things.map(func(t): return t["id"])
	assert_true("dead_tree" in ids and "root_hole" in ids, "si parla con l'albero e col buco")
	zone.talk.talk("dead_tree")
	await _drive(zone.talk, 0)
	assert_eq(zone.state.truth, 1, "\"I don't remember\": una verità")
	assert_eq(zone.objective.text, zone.story.GOAL_ROOTS, "ora: scendere tra le radici")
	zone.talk.talk("root_hole")
	await _drive(zone.talk, 0)
	assert_true(zone.state.flag("roots_entered"), "si scende")


func test_da_una_zona_all_altra_e_ritorno() -> void:
	Engine.time_scale = 4.0
	var zone := await _tree_zone({"tree_arrived": true})
	zone.state.flags["defeated"] = ["moth_0"]          # una falena della prima zona
	zone._on_exit(zone.hero)
	assert_true(await wait_signal(zone.traveled, 3.0), "da ovest si torna indietro")
	assert_eq(String(Main.pending_save.get("zone")), "wake", "nella prima zona")
	assert_eq(String(Main.pending_save.get("entry")), "east", "dall'entrata est")
	assert_eq(Main.scene_for_save(Main.pending_save), "res://forest/zone_wake.tscn", "Continue sa dove andare")
	Main.pending_save["entry"] = "east"
	var wake := add_scene("res://forest/zone_wake.tscn", func(n): n.sound = false)
	await tree.process_frame
	var east: Vector2i = wake.layout_value("ENTRIES")["east"]
	assert_true(wake.hero.global_position.distance_to(ZoneLayout.cell_center(east)) < 1.0, "si arriva da est")
	assert_eq(wake.enemies().size(), Layout.ENEMIES.size() - 1, "la falena sconfitta resta sconfitta")
	assert_eq(zone.enemy_key(0).begins_with("tree:"), true, "i nemici dell'albero hanno il nome della zona")


func test_una_zona_nuova_parte_sempre_in_movimento() -> void:
	tree.paused = true                         # come se il menu fosse rimasto aperto prima
	var zone := await _zone()
	assert_false(tree.paused, "la foresta non parte ferma (lo schermo nero dopo lo specchio)")


func test_la_camera_delle_scene_non_esce_dalla_mappa() -> void:
	var zone := await _zone()
	var cut: Node = zone.story.cut
	var b: Rect2 = zone.bounds()
	var p: Vector2 = cut.clamp_to_limits(b.end + Vector2(500, 500))
	assert_true(p.x <= b.end.x - 320.0 + 0.5 and p.y <= b.end.y - 180.0 + 0.5, "oltre il bordo non si guarda")
	p = cut.clamp_to_limits(Vector2(-500, -500))
	assert_true(p.x >= 320.0 - 0.5 and p.y >= 180.0 - 0.5, "nemmeno dall'altra parte")


func test_vicino_al_bordo_la_camera_guarda_dalla_parte_giusta() -> void:
	Main.pending_save = {"flags": {"forest_arrived": true, "talk_learned": true, "selene_met": true},
		"position": [1150.0, 360.0]}
	var zone := add_scene("res://forest/zone_wake.tscn", func(n): n.sound = false)
	await tree.process_frame
	var cut: Node = zone.story.cut
	cut.pace = 0.05
	await cut.begin()
	await cut.pan_to(zone.hero.global_position + Vector2(240, 0), 1.0)
	assert_true(zone.camera.offset.x >= -0.5, "vicino al bordo destro non torna indietro (offset %s)" % zone.camera.offset)
	await cut.end()
