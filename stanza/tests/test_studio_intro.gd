extends "res://tests/base_test.gd"
## L'intro intera, dall'inizio alla fine, e il salto.

const INTRO := "res://studio_intro/studio_intro.tscn"


func _intro(name := "") -> Control:
	return add_scene(INTRO, func(n):
		n.next_scene = ""   # resta qui: il test controlla lo stato finale
		if name != "":
			n.studio_name = name)


func test_arriva_alla_fine_con_tutto_al_suo_posto() -> void:
	Engine.time_scale = 8.0
	var intro := _intro("STUDIO DI PROVA")
	var arrived: bool = await wait_signal(intro.finished, 5.0)
	assert_true(arrived, "finished emesso")
	assert_true(intro.is_done(), "is_done")
	assert_near(intro.get_node("%Black").color.a, 1.0, 0.001, "schermo nero a fine intro")
	assert_near(intro.get_node("%Moon").phase(), 1.0, 0.001, "luna piena")
	var title: Control = intro.get_node("%Title")
	assert_eq(title.name_label.text, "STUDIO DI PROVA", "nome dello studio")
	assert_true(title.is_fully_typed(), "nome scritto tutto")
	assert_true(title.is_subtitle_shown(), "sottotitolo visibile")
	assert_false(intro.get_node("%Moon").eye.visible, "l'occhio si è richiuso")
	assert_near(intro.get_node("%Glade").brightness, 1.0, 0.001, "riflesso acceso")


func test_senza_occhio_finisce_lo_stesso() -> void:
	Engine.time_scale = 8.0
	var watched := {"open": false}
	var intro := add_scene(INTRO, func(n):
		n.next_scene = ""
		n.moon_watches = false)
	var eye: AnimatedSprite2D = intro.get_node("%Moon").eye
	eye.visibility_changed.connect(func(): watched["open"] = watched["open"] or eye.visible)
	assert_true(await wait_signal(intro.finished, 5.0), "finished emesso")
	assert_false(watched["open"], "l'occhio non si è mai aperto")


func test_salto_finisce_subito() -> void:
	var intro := _intro()
	await wait_seconds(0.3)
	var start := Time.get_ticks_msec()
	intro.skip()
	var arrived: bool = await wait_signal(intro.finished, 2.0)
	assert_true(arrived, "finished dopo il salto")
	assert_true(Time.get_ticks_msec() - start < 1000, "il salto dura meno di un secondo")
	assert_false(intro.get_node("%Music").playing, "la musica si ferma col salto")
	assert_false(intro.get_node("%Title").is_fully_typed(), "il nome non ha fatto in tempo")
	# Lascia scadere i timer del regista prima di liberare la scena.
	Engine.time_scale = 8.0
	await wait_seconds(1.0)


func test_non_saltabile_ignora_il_salto() -> void:
	var intro := add_scene(INTRO, func(n):
		n.next_scene = ""
		n.skippable = false)
	await wait_seconds(0.2)
	intro.skip()
	await wait_seconds(0.3)
	assert_false(intro.is_done(), "con skippable = false non salta")
	Engine.time_scale = 8.0
	await wait_signal(intro.finished, 5.0)
