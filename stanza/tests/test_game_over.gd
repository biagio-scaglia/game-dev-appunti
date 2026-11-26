extends "res://tests/base_test.gd"
## La schermata del cuore spezzato (ui/game_over.gd): il fermo immagine, gli occhi e le bugie,
## il cuore stretto che si spacca, DEATH IS A LIE., e alla fine qualcuno che bussa (sempre).
## E la morte nella zona che la usa, poi il risveglio.

const GameOver := preload("res://ui/game_over.gd")
const ZONE := "res://forest/zone_roots.tscn"
const Main := preload("res://main.gd")
const InputSetup := preload("res://core/input_setup.gd")


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _screen(eyes := 9) -> CanvasLayer:
	var screen: CanvasLayer = GameOver.new()
	screen.sound = false
	screen.pace = 0.05
	screen.eye_count = eyes
	tree.root.add_child(screen)
	_owned.append(screen)
	return screen


func test_la_sequenza_intera() -> void:
	var screen := _screen(9)
	var image := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.5, 0.8))
	screen.play(image)
	assert_true(await wait_signal(screen.finished, 15.0), "arriva in fondo")
	assert_eq(screen.eyes.size(), 9, "gli occhi che hanno visto")
	assert_true(screen.eyes.all(func(e): return e.target == 0.0), "alla fine si chiudono tutti")
	assert_true(screen.heart.broken, "il cuore si è spaccato")
	assert_eq(screen.knock_label.text, "Someone is knocking.", "e qualcuno bussa: sempre")


func test_le_bugie_e_la_piu_grande() -> void:
	var screen := _screen(10)
	screen.play(null)                                 # senza immagine (headless): si parte dal nero
	await wait_signal(screen.finished, 15.0)
	var texts: Array = []
	for child in screen.root_node.get_children():
		if child is Label:
			texts.append(child.text)
	assert_true(GameOver.BIGGEST in texts, "la bugia più grande del gioco: nessuno se ne accorgerebbe")
	assert_true(texts.filter(func(t): return t in GameOver.LIES).size() >= 3, "e le sue bugie")
	for t in texts:
		assert_false("sip" in t.to_lower(), "niente righe del Lete tra i sussurri (temi delicati)")


func test_un_tasto_la_fa_andare_piu_in_fretta() -> void:
	InputSetup.ensure_actions()                      # le azioni dei tasti (le crea Lethe, qui non c'è)
	var screen := _screen()
	screen.pace = 0.2
	screen.play(null)
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	screen._input(press)
	assert_true(screen._hurry < 1.0, "più in fretta")
	assert_true(await wait_signal(screen.finished, 10.0), "ma arriva lo stesso in fondo")
	assert_true(screen.knock_label != null, "col bussare")


func test_nella_zona_la_morte_la_mostra_e_poi_il_risveglio() -> void:
	Main.pending_save = {"zone": "roots", "entry": "top", "flags": {"forest_arrived": true,
		"talk_learned": true, "selene_met": true, "roots_arrived": true, "first_enemy_seen": true},
		"lies": 3}
	var zone: Node2D = add_scene(ZONE, func(n): n.sound = false)
	await tree.process_frame
	zone.state.heart = 0
	zone.combat.die(0.05)
	await tree.process_frame
	var screens := zone.get_children().filter(func(c): return c is GameOver)
	assert_eq(screens.size(), 1, "la schermata c'è")
	assert_eq(screens[0].eye_count, 10, "più bugie, più occhi")
	assert_true(await wait_signal(zone.combat.respawned, 20.0), "poi si risveglia")
	assert_eq(zone.state.heart, zone.state.heart_max, "col cuore intero")
