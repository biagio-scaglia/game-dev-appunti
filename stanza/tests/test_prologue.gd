extends "res://tests/base_test.gd"
## Il prologo nella stanza: il risveglio dopo la cutscene, il tasto accanto al fumetto la
## prima volta, lo specchio che chiama (solo dopo chi bussa e cinque cose guardate), "Not
## yet." che lo fa brillare di più, la caduta che dà la scheggia, e i salvataggi.

const MAIN := "res://main.tscn"
const Main := preload("res://main.gd")
const MirrorGlow := preload("res://prologue/mirror_glow.gd")
const Prologue := preload("res://prologue/prologue.gd")


func after() -> void:
	tree.paused = false
	Main.from_opening = false
	Main.pending_save = {}
	await super()


func _main(from_opening := false) -> Node:
	Main.from_opening = from_opening
	var main := add_scene(MAIN, func(n): n.get_node("%DoorKnock").sound = false)
	main.prologue.sound = false
	main.prologue.glow.sound = false
	main.prologue.objective.sound = false
	await tree.process_frame
	main.music.stop()
	main.knock.set_process(false)
	return main


## Va avanti nel dialogo aperto scegliendo `pick`, fino alla fine.
func _drive(talk: Node, pick := 0) -> void:
	var box: CanvasLayer = talk.box
	if not is_instance_valid(box):
		return
	box.sound = false
	for i in 400:
		await tree.process_frame
		if not is_instance_valid(box):
			break
		if box.choices_panel.visible:
			box.choose(pick)
		elif box.waiting or box.text_label.is_typing:
			box.advance()
	await tree.physics_frame
	await tree.physics_frame
	await tree.process_frame


func _wait_talking(talk: Node, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not talk.is_talking() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return talk.is_talking()


## Fa andare via chi bussa (senza risposta) e guarda cinque cose.
func _ready_to_call(main: Node) -> void:
	var knock: Node2D = main.knock
	knock.tick(knock.first_delay)
	for i in knock.max_series:
		knock.tick(knock.series_gap)
	for id in ["bed", "shelf", "window", "dead_plant", "console"]:
		main.talk.talk(id)
		await _drive(main.talk)


func test_il_risveglio_dopo_la_cutscene() -> void:
	Engine.time_scale = 6.0
	var main := await _main(true)
	var hero: CharacterBody2D = main.hero
	assert_eq(hero.global_position, main.prologue.wake_position(), "accanto al letto")
	assert_false(main.room.is_solid(Prologue.WAKE_CELL), "su una cella libera")
	assert_true(hero.frozen, "ferma mentre apre gli occhi")
	assert_false(Main.from_opening, "il risveglio una volta sola")
	assert_true(await _wait_talking(main.talk, 4.0), "poi il narratore")
	var box: CanvasLayer = main.talk.box
	for i in 30:
		if is_instance_valid(box.line):
			break
		await tree.process_frame
	assert_eq(box.line.text, "Night.", "la prima riga")
	await _drive(main.talk)
	assert_false(hero.frozen, "e si gioca")
	assert_true(main.state.flag("woke_up"), "segnato")
	assert_true(main.talk.key_hint, "il tasto accanto al fumetto, la prima volta")


func test_il_tasto_solo_la_prima_volta() -> void:
	var main := await _main()
	var talk: Node = main.talk
	assert_true(talk.key_hint, "una partita nuova: il tasto c'è")
	var things: Array[Dictionary] = talk.things
	var rect: Rect2 = things.filter(func(t): return t["id"] == "food_tray")[0]["rect"]
	main.hero.global_position = main.room.global_position + Vector2(rect.get_center().x, rect.end.y + 10)
	main.hero.facing = Vector2.UP
	await tree.process_frame
	await tree.process_frame
	assert_true(talk.icon.visible and talk.hint_label.visible, "accanto al fumetto: E")
	talk.talk("food_tray")
	await _drive(talk)
	assert_false(talk.key_hint, "dopo il primo dialogo, mai più")
	assert_true(main.state.flag("talk_learned"), "e si salva")


func test_lo_specchio_chiama_solo_quando_e_ora() -> void:
	var main := await _main()
	var prologue: Node = main.prologue
	for id in ["bed", "shelf", "window", "dead_plant", "console"]:
		main.talk.talk(id)
		await _drive(main.talk)
	assert_eq(main.state.looked_count(), 5, "cinque cose guardate")
	assert_false(prologue.mirror_calling, "ma bussano ancora: lo specchio aspetta")
	var knock: Node2D = main.knock
	knock.tick(knock.first_delay)
	for i in knock.max_series:
		knock.tick(knock.series_gap)
	assert_true(prologue.mirror_calling, "chi bussava se n'è andato: lo specchio chiama")
	assert_true(main.state.flag("mirror_calling"), "segnato")
	assert_true(await _wait_talking(main.talk, 3.0), "il narratore lo dice")
	await _drive(main.talk)
	await wait_seconds(0.5)
	assert_true(prologue.glow.intensity > 0.0, "l'angolo si accende")
	assert_true(prologue.glow.light.energy > 0.0, "e fa luce")


func test_non_ancora_lo_fa_brillare_di_piu() -> void:
	Engine.time_scale = 4.0
	var main := await _main()
	await _ready_to_call(main)
	var prologue: Node = main.prologue
	assert_true(await _wait_talking(main.talk, 3.0), "il narratore")
	await _drive(main.talk)
	await wait_seconds(0.8)
	var before: float = prologue.glow.intensity
	main.talk.talk("covered_mirror")
	await _drive(main.talk, 1)          # "Not yet."
	await wait_seconds(0.5)
	assert_eq(prologue.call_visits, 1, "una volta")
	assert_true(prologue.glow.intensity > before, "brilla di più")
	assert_false(prologue._falling, "non cade")


func test_togliere_il_lenzuolo_e_cadere() -> void:
	Engine.time_scale = 8.0
	var main := await _main()
	await _ready_to_call(main)
	var prologue: Node = main.prologue
	await _wait_talking(main.talk, 3.0)
	await _drive(main.talk)
	assert_false(main.state.can_slash(), "prima: niente spada")
	main.talk.talk("covered_mirror")
	await _drive(main.talk, 0)          # "Pull the sheet off."
	assert_true(prologue._falling, "cade")
	assert_true(main.hero.frozen, "ferma")
	assert_true(await wait_signal(prologue.finished, 12.0), "fino al cartello")
	assert_true(main.state.owns("glass_sword"), "la scheggia in mano")
	assert_true(main.state.can_slash(), "la spada c'è")
	assert_true(main.hero.can_slash, "e K funziona")
	assert_true(main.state.flag("prologue_done"), "prologo finito")


func test_da_un_salvataggio_lo_specchio_chiama_ancora() -> void:
	Main.pending_save = {"flags": {"knock_over": true, "mirror_calling": true, "call_visits": 2,
		"looked": ["bed", "shelf", "window", "dead_plant", "console"]}}
	var main := await _main()
	assert_true(main.knock.knock_over, "non bussano più")
	assert_true(main.prologue.mirror_calling, "lo specchio chiama già")
	assert_eq(main.prologue.call_visits, 2, "con le volte di prima")
	assert_false(main.talk.is_talking(), "senza ripeterlo")


func test_il_vetro() -> void:
	for i in 40:
		var p := MirrorGlow.pulse(i * 0.3, 0.5)
		assert_true(p >= 0.7 - 0.0001 and p <= 1.0 + 0.0001, "pulsa nei limiti: %s" % p)
	var blocks := MirrorGlow.crack_blocks(-100.0, 40.0)
	assert_eq(blocks.size(), 20, "un blocco ogni 2 pixel")
	for b in blocks:
		assert_eq(b, (b / 2.0).floor() * 2.0, "sulla griglia da 2")
	assert_true(blocks[-1].y < -30.0, "la crepa sale sul vetro")


func test_lo_specchio_si_rompe_a_schegge_lunghe() -> void:
	var MirrorShatter := preload("res://fx/mirror_shatter.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var size := Vector2(640, 360)
	var pieces := MirrorShatter.slivers(size, MirrorShatter.SLIVER_WIDTH, MirrorShatter.ROWS, rng)
	assert_true(pieces.size() >= 12 * MirrorShatter.ROWS, "tante schegge: %d" % pieces.size())
	for x in range(0, 641, 20):
		for y in range(0, 361, 30):
			var p := Vector2(x, y) + Vector2(0.37, 0.53)
			assert_true(pieces.any(func(poly): return Geometry2D.is_point_in_polygon(p, poly)),
				"nessun buco in %s" % p)
	var poly: PackedVector2Array = pieces[0]
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	assert_true(box.size.y > box.size.x, "più alte che larghe, come schegge di specchio")


func test_l_obiettivo_dice_cosa_fare() -> void:
	assert_eq(Prologue.objective_for(false, 0, false, false, false), "", "mentre si sveglia: niente")
	assert_eq(Prologue.objective_for(true, 2, false, false, false), "Look around the room (2/5)", "guardare")
	assert_eq(Prologue.objective_for(true, 9, false, false, false), "Look around the room (5/5)", "al massimo 5")
	assert_eq(Prologue.objective_for(true, 2, true, false, false), Prologue.GOAL_DOOR, "bussano: la porta")
	assert_eq(Prologue.objective_for(true, 5, false, true, false), Prologue.GOAL_MIRROR, "lo specchio")
	assert_eq(Prologue.objective_for(true, 5, false, true, true), "", "mentre cade: niente")
	var Banner := preload("res://ui/objective_banner.gd")
	assert_true(Banner.same_goal("Look around the room (2/5)", "Look around the room (3/5)"), "stesso obiettivo")
	assert_false(Banner.same_goal("Look around the room (5/5)", Prologue.GOAL_DOOR), "un altro")


func test_l_obiettivo_in_alto_nella_stanza() -> void:
	var main := await _main()
	await tree.process_frame
	var banner: CanvasLayer = main.prologue.objective
	assert_eq(banner.text, "Look around the room (0/5)", "si parte guardando")
	main.talk.talk("bed")
	await _drive(main.talk)
	await tree.process_frame
	assert_eq(banner.text, "Look around the room (1/5)", "conta")
	main.talk.talk("bed")
	await _drive(main.talk)
	await tree.process_frame
	assert_eq(banner.text, "Look around the room (1/5)", "la stessa cosa non conta due volte")


func test_guardato_tutto_bussano_subito() -> void:
	var main := await _main()
	var knock: Node2D = main.knock
	for id in ["bed", "shelf", "window", "dead_plant", "console"]:
		main.talk.talk(id)
		await _drive(main.talk)
	knock.tick(3.1)
	assert_true(knock.knocking, "non serve aspettare i 35 secondi")
	await tree.process_frame
	assert_eq(main.prologue.objective.text, Prologue.GOAL_DOOR, "l'obiettivo: la porta")
