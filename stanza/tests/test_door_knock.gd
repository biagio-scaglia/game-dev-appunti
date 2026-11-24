extends "res://tests/base_test.gd"
## Bussano alla porta: quando comincia, quante volte bussa, la luce e i piedi sotto la porta,
## chi se ne va se Lethe non risponde, il dialogo della porta mentre bussano (verità, bugia,
## silenzio) e dopo.

const MAIN := "res://main.tscn"


func after() -> void:
	tree.paused = false
	await super()


func _main() -> Node:
	var main := add_scene(MAIN)
	await tree.process_frame
	main.music.stop()
	main.knock.sound = false
	main.knock.set_process(false)          # il tempo lo fanno passare i test
	return main


## Va avanti nel dialogo aperto scegliendo `pick`, fino alla fine.
func _drive(talk: Node, pick: int) -> void:
	var box: CanvasLayer = talk.box
	box.sound = false
	for i in 300:
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


func test_bussano_dopo_un_po() -> void:
	var main := await _main()
	var knock: Node2D = main.knock
	assert_false(knock.knocking, "all'inizio niente")
	knock.tick(knock.first_delay - 1.0)
	assert_false(knock.knocking, "non ancora")
	knock.tick(1.5)
	assert_true(knock.knocking, "bussano")
	assert_eq(knock.series, 1, "una volta")
	assert_true(knock.feet, "l'ombra dei piedi sotto la porta")
	await wait_seconds(knock.FADE_SECONDS + 0.1)
	assert_near(knock.light_amount, 1.0, 0.01, "la luce sotto la porta")
	knock.tick(knock.series_gap)
	assert_eq(knock.series, 2, "ribussano")


func test_la_luce_e_sotto_la_porta() -> void:
	var main := await _main()
	var knock: Node2D = main.knock
	assert_eq(knock.position, Vector2(17 * 32 + 16, 64), "al centro della soglia")


func test_se_nessuno_risponde_se_ne_vanno() -> void:
	var main := await _main()
	var knock: Node2D = main.knock
	var got := {"answered": null}
	knock.ended.connect(func(answered: bool) -> void: got["answered"] = answered)
	knock.tick(knock.first_delay)
	for i in knock.max_series:
		knock.tick(knock.series_gap)
	assert_eq(knock.series, knock.max_series, "bussano %d volte" % knock.max_series)
	assert_false(knock.knocking, "poi smettono")
	assert_true(knock.knock_over, "ed è finita")
	assert_eq(got["answered"], false, "senza risposta")
	await wait_seconds(knock.FEET_LEAVE_SECONDS + knock.FADE_SECONDS + 0.2)
	assert_false(knock.feet, "i piedi se ne vanno")
	assert_near(knock.light_amount, 0.0, 0.01, "la luce si spegne")
	knock.tick(1000.0)
	assert_eq(knock.series, knock.max_series, "non bussano più")


func test_il_tempo_si_ferma_mentre_parla() -> void:
	var main := await _main()
	var knock: Node2D = main.knock
	knock.set_process(true)
	knock.tick(knock.first_delay - 0.05)
	main.talk.talk("bed")
	await wait_seconds(0.3)
	assert_false(knock.knocking, "durante un dialogo non bussano")


func test_alla_porta_dice_la_verita() -> void:
	var main := await _main()
	var knock: Node2D = main.knock
	knock.tick(knock.first_delay)
	main.talk.talk("door")
	await _drive(main.talk, 0)
	assert_eq(main.state.truth, 1, "\"I'm awake\" è la verità")
	assert_true(knock.knock_over and not knock.knocking, "chi bussava se ne va")


func test_alla_porta_mente() -> void:
	var main := await _main()
	var knock: Node2D = main.knock
	var got := {"answered": null}
	knock.ended.connect(func(answered: bool) -> void: got["answered"] = answered)
	knock.tick(knock.first_delay)
	main.talk.talk("door")
	await _drive(main.talk, 1)
	assert_eq(main.state.lies, 1, "\"I'm asleep\" è una bugia")
	assert_eq(got["answered"], true, "ma ha risposto")


func test_alla_porta_sta_zitta_e_dopo() -> void:
	var main := await _main()
	var knock: Node2D = main.knock
	knock.tick(knock.first_delay)
	main.talk.talk("door")
	await _drive(main.talk, 2)
	assert_eq(main.state.truth + main.state.lies, 0, "il silenzio non conta")
	assert_true(knock.knock_over, "se ne vanno lo stesso")
	# Dopo, la porta dice un'altra cosa (e niente scelte).
	main.talk.talk("door")
	var box: CanvasLayer = main.talk.box
	box.sound = false
	for i in 30:
		await tree.process_frame
		if is_instance_valid(box.line):
			break
	assert_eq(box.line.text, "The light under the door is gone.", "la luce non c'è più")
	await _drive(main.talk, 0)
