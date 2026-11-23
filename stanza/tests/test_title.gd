extends "res://tests/base_test.gd"
## La schermata del titolo: apparizione, salto, menu, Start, il nome nascosto nel titolo.

const TITLE := "res://title/title_screen.tscn"
const Backdrop := preload("res://title/title_backdrop.gd")
const TitleName := preload("res://title/title_name.gd")
const ScreenShatter := preload("res://fx/screen_shatter.gd")


func _title() -> Control:
	return add_scene(TITLE, func(n): n.next_scene = "")   # resta qui: niente cambio scena


func test_parte_dal_nero_col_titolo_nascosto() -> void:
	var title := _title()
	assert_near(title.get_node("%Black").color.a, 1.0, 0.001, "parte nero")
	assert_near(title.get_node("%TitleName").modulate.a, 0.0, 0.001, "titolo nascosto")
	assert_false(title.get_node("%MenuPanel").visible, "menu nascosto")
	assert_eq(title.get_node("%TitleName").full_text(), "ALETHEIA", "titolo")
	assert_eq(title.get_node("%TaglineLabel").text, "Death is a Lie", "sottotitolo")


func test_l_apparizione_arriva_al_menu() -> void:
	Engine.time_scale = 8.0
	var title := _title()
	var deadline := Time.get_ticks_msec() + 3000
	while not title.is_revealed() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_true(title.is_revealed(), "apparizione finita")
	assert_near(title.get_node("%Black").color.a, 0.0, 0.001, "niente più nero")
	assert_true(title.get_node("%MenuPanel").visible, "menu visibile")


func test_un_tasto_salta_l_apparizione_e_start_ha_il_focus() -> void:
	var title := _title()
	await tree.process_frame
	title.skip_reveal()
	await tree.process_frame
	assert_true(title.is_revealed(), "saltata")
	assert_near(title.get_node("%TitleName").modulate.a, 1.0, 0.001, "titolo visibile")
	var menu: VBoxContainer = title.get_node("%Menu")
	assert_eq(menu.focused_id(), &"start", "Start ha il focus")
	assert_true(menu.has_heart(&"start"), "il cuore davanti alla voce scelta")
	assert_false(menu.has_heart(&"quit"), "le altre senza cuore")
	assert_eq(menu.get_node("start").text, "Start", "il testo resta quello")
	menu.get_node("quit").grab_focus()
	assert_true(menu.has_heart(&"quit") and not menu.has_heart(&"start"), "il cuore segue il focus")


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


func test_il_nome_e_nascosto_nel_titolo() -> void:
	assert_eq(TitleName.split("ALETHEIA", "LETHE"), PackedStringArray(["A", "LETHE", "IA"]), "A-LETHE-IA")
	assert_eq(TitleName.split("DEATH IS A LIE", "LETHE"), PackedStringArray(["", "DEATH IS A LIE", ""]),
		"senza il nome: tutto insieme")


func test_il_tremolio_lascia_solo_il_nome_e_poi_torna() -> void:
	Engine.time_scale = 4.0
	var title := _title()
	await tree.process_frame
	var name_box: HBoxContainer = title.get_node("%TitleName")
	name_box.flicker()
	await wait_seconds(0.3)
	assert_true(name_box.before.modulate.a < 0.2, "la A si spegne")
	assert_true(name_box.after.modulate.a < 0.2, "IA si spegne")
	assert_near(name_box.word.modulate.a, 1.0, 0.001, "LETHE resta")
	var deadline := Time.get_ticks_msec() + 2000
	while name_box.is_flickering() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	assert_near(name_box.before.modulate.a, 1.0, 0.001, "la A torna")


func test_muoversi_nel_menu_suona_ma_non_al_primo_focus() -> void:
	var title := _title()
	await tree.process_frame
	var moves := {"n": 0}
	var menu: VBoxContainer = title.get_node("%Menu")
	menu.moved.connect(func(): moves["n"] += 1)
	title.skip_reveal()
	await tree.process_frame
	assert_eq(moves["n"], 0, "il primo focus non suona")
	menu.get_node("quit").grab_focus()
	assert_eq(moves["n"], 1, "passare a Quit suona")


func test_lethe_c_e_solo_se_ci_sono_gli_sprite() -> void:
	var title := _title()
	var Frames := preload("res://characters/protagonista/protagonista_frames.gd")
	assert_eq(title.get_node("%Figure").visible, Frames.sprites_available(), "visibile solo con gli sprite")


func test_i_frammenti_coprono_tutto_lo_schermo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var size := Vector2(640, 360)
	var web := ScreenShatter.web(Vector2(90, 300), size, 11, 4, rng)
	assert_eq(web.size(), 11 * 4, "un triangolo e tre anelli per raggio")
	for x in range(0, 641, 40):
		for y in range(0, 361, 40):
			var p := Vector2(x, y) + Vector2(0.37, 0.53)
			assert_true(web.any(func(poly): return Geometry2D.is_point_in_polygon(p, poly)),
				"nessun buco in %s" % p)


func test_quit_rompe_lo_schermo_e_poi_chiede_di_chiudere() -> void:
	Engine.time_scale = 4.0
	var title := add_scene(TITLE, func(n):
		n.next_scene = ""
		n.really_quit = false)
	await tree.process_frame
	title.skip_reveal()
	title.get_node("%Menu").get_node("quit").pressed.emit()
	await tree.process_frame
	var shatter: CanvasLayer = title.get_children().filter(func(n): return n is ScreenShatter)[0]
	assert_true(shatter.shard_count() > 0, "lo schermo è in pezzi")
	assert_true(await wait_signal(title.quit_requested, 6.0), "poi quit_requested")
