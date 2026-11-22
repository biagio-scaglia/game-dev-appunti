extends "res://tests/base_test.gd"
## La schermata del titolo: apparizione, salto, menu, Start.

const TITLE := "res://title/title_screen.tscn"
const Backdrop := preload("res://title/title_backdrop.gd")


func _title() -> Control:
	return add_scene(TITLE, func(n): n.next_scene = "")   # resta qui: niente cambio scena


func test_parte_dal_nero_col_titolo_nascosto() -> void:
	var title := _title()
	assert_near(title.get_node("%Black").color.a, 1.0, 0.001, "parte nero")
	assert_near(title.get_node("%TitleLabel").modulate.a, 0.0, 0.001, "titolo nascosto")
	assert_false(title.get_node("%Menu").visible, "menu nascosto")
	assert_eq(title.get_node("%TitleLabel").text, "ALETHEIA", "titolo")
	assert_eq(title.get_node("%TaglineLabel").text, "Death is a Lie", "sottotitolo")


func test_l_apparizione_arriva_al_menu() -> void:
	Engine.time_scale = 8.0
	var title := _title()
	var deadline := Time.get_ticks_msec() + 3000
	while not title.is_revealed() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_true(title.is_revealed(), "apparizione finita")
	assert_near(title.get_node("%Black").color.a, 0.0, 0.001, "niente più nero")
	assert_true(title.get_node("%Menu").visible, "menu visibile")


func test_un_tasto_salta_l_apparizione_e_start_ha_il_focus() -> void:
	var title := _title()
	await tree.process_frame
	title.skip_reveal()
	await tree.process_frame
	assert_true(title.is_revealed(), "saltata")
	assert_near(title.get_node("%TitleLabel").modulate.a, 1.0, 0.001, "titolo visibile")
	var menu: VBoxContainer = title.get_node("%Menu")
	assert_eq(menu.focused_id(), &"start", "Start ha il focus")
	assert_eq(menu.get_node("start").text, "> Start", "segno davanti alla voce scelta")
	assert_eq(menu.get_node("quit").text, "Quit", "le altre senza segno")


func test_start_dissolve_al_nero_e_chiede_il_gioco() -> void:
	Engine.time_scale = 4.0
	var title := _title()
	await tree.process_frame
	title.skip_reveal()
	title.get_node("%Menu").get_node("start").pressed.emit()
	assert_true(await wait_signal(title.start_requested, 3.0), "start_requested emesso")
	assert_near(title.get_node("%Black").color.a, 1.0, 0.001, "schermo nero")


func test_il_pulviscolo_sale_e_rientra_dal_basso() -> void:
	var area := Vector2(640, 360)
	var p := Backdrop.step_mote(Vector2(100, 200), 10.0, 0.0, 0.0, 1.0, area)
	assert_true(p.y < 200.0, "sale")
	p = Backdrop.step_mote(Vector2(100, -3.9), 10.0, 0.0, 0.0, 1.0, area)
	assert_true(p.y > area.y, "rientra dal basso")
	for i in 50:
		var a := Backdrop.twinkle(i * 0.3, i * 0.17)
		assert_true(a >= 0.35 - 0.0001 and a <= 0.7 + 0.0001, "luminosità nei limiti: %s" % a)


func test_l_intro_porta_al_titolo_in_inglese() -> void:
	var intro: Control = load("res://studio_intro/studio_intro.tscn").instantiate()
	assert_eq(intro.next_scene, TITLE, "dopo l'intro c'è il titolo")
	assert_eq(intro.subtitle, "presents", "sottotitolo in inglese")
	intro.free()
