extends "res://tests/base_test.gd"
## La schermata del titolo: apparizione, salto, menu, New Game, Continue, il nome nascosto
## nel titolo, la porta che bussa, l'avviso sui contenuti e la pagina "Talk to Someone".

const TITLE := "res://title/title_screen.tscn"
const Backdrop := preload("res://title/title_backdrop.gd")
const TitleName := preload("res://title/title_name.gd")
const ScreenShatter := preload("res://fx/screen_shatter.gd")
const SaveStore := preload("res://menu/save_store.gd")
const Settings := preload("res://core/settings_store.gd")
const TitleDoor := preload("res://title/title_door.gd")
const TitleScreen := preload("res://title/title_screen.gd")
const Main := preload("res://main.gd")

var _real_saves := ""
var _real_settings := ""


func before() -> void:
	_real_saves = SaveStore.dir
	_real_settings = Settings.path
	SaveStore.dir = "user://test_saves"
	Settings.path = "user://test_settings.cfg"
	_clean()


func after() -> void:
	_clean()
	SaveStore.dir = _real_saves
	Settings.path = _real_settings
	Main.pending_save = {}
	await super()


func _clean() -> void:
	for slot in range(1, SaveStore.SLOTS + 1):
		SaveStore.erase(slot)
	Settings.erase()


func _title(warning := false) -> Control:
	return add_scene(TITLE, func(n):
		n.next_scene = ""          # resta qui: niente cambio scena
		n.show_warning = warning)


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
	assert_eq(menu.focused_id(), &"start", "senza salvataggi New Game ha il focus")
	assert_true(menu.has_heart(&"start"), "il cuore davanti alla voce scelta")
	assert_false(menu.has_heart(&"quit"), "le altre senza cuore")
	assert_eq(menu.get_node("start").text, "New Game", "il testo resta quello")
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


func test_continue_solo_se_c_e_un_salvataggio() -> void:
	var ids := TitleScreen.menu_entries().map(func(e): return e[0])
	assert_eq(ids, [&"start", &"help", &"quit"], "senza salvataggi: niente Continue")
	SaveStore.write(3, {"saved_at": 99})
	assert_false(&"continue" in TitleScreen.menu_entries().map(func(e): return e[0]),
		"il File 3 non è di Lethe: non conta")
	SaveStore.write(1, {"saved_at": 10, "truth": 1})
	SaveStore.write(2, {"saved_at": 20, "truth": 2})
	ids = TitleScreen.menu_entries().map(func(e): return e[0])
	assert_eq(ids[0], &"continue", "Continue in cima")
	assert_eq(int(TitleScreen.latest_save()["truth"]), 2, "riprende il più recente")


func test_continue_porta_il_salvataggio_alla_stanza() -> void:
	Engine.time_scale = 4.0
	SaveStore.write(1, {"saved_at": 10, "truth": 3, "lies": 1, "position": [200, 150]})
	var title := _title()
	await tree.process_frame
	title.skip_reveal()
	await tree.process_frame
	var menu: VBoxContainer = title.get_node("%Menu")
	assert_eq(menu.focused_id(), &"continue", "col salvataggio il focus è su Continue")
	menu.get_node("continue").pressed.emit()
	assert_true(await wait_signal(title.start_requested, 3.0), "parte")
	assert_eq(int(Main.pending_save.get("truth", 0)), 3, "il salvataggio aspetta la stanza")
	var main := add_scene("res://main.tscn")
	await tree.process_frame
	main.music.stop()
	assert_eq(main.state.truth, 3, "la stanza riparte con la verità salvata")
	assert_eq(main.state.lies, 1, "e le bugie")
	assert_eq(main.hero.global_position, Vector2(200, 150), "Lethe dove era")
	assert_true(Main.pending_save.is_empty(), "usato una volta sola")


func test_new_game_dimentica_il_salvataggio() -> void:
	Engine.time_scale = 4.0
	SaveStore.write(1, {"saved_at": 10, "truth": 3})
	Main.pending_save = {"truth": 9}
	var title := _title()
	await tree.process_frame
	title.skip_reveal()
	title.get_node("%Menu").get_node("start").pressed.emit()
	assert_true(await wait_signal(title.start_requested, 3.0), "parte")
	assert_true(Main.pending_save.is_empty(), "si parte da capo")


func test_la_prima_volta_l_avviso_poi_mai_piu() -> void:
	var title := _title(true)
	await tree.process_frame
	assert_true(title.note.is_open(), "l'avviso prima di tutto")
	assert_eq(title.note.kind, &"warning", "è l'avviso")
	assert_true("suicide" in title.note.text(), "dice di cosa parla")
	assert_near(title.get_node("%Black").color.a, 1.0, 0.001, "il titolo aspetta nel nero")
	assert_false(title.note.can_close(), "un tasto subito non lo salta")
	title.skip_reveal()         # nemmeno saltare l'apparizione lo chiude
	assert_true(title.note.is_open(), "resta aperto")
	await wait_seconds(title.note.MIN_SECONDS + 0.1)
	assert_true(title.note.can_close(), "dopo un attimo si chiude")
	title.note.close()
	assert_true(await wait_signal(title.note.closed, 2.0), "chiuso")
	assert_true(Settings.has_flag(title.WARNING_FLAG), "letto")
	await tree.process_frame
	assert_true(title.music.playing, "e parte il titolo")
	var again := _title(true)
	await tree.process_frame
	assert_false(again.note.is_open(), "la seconda volta niente avviso")


func test_talk_to_someone_apre_i_numeri_e_torna_al_menu() -> void:
	var title := _title()
	await tree.process_frame
	title.skip_reveal()
	await tree.process_frame
	var menu: VBoxContainer = title.get_node("%Menu")
	menu.get_node("help").pressed.emit()
	assert_true(title.note.is_open(), "la pagina si apre")
	assert_eq(title.note.kind, &"help", "quella dell'aiuto")
	assert_true("Telefono Amico" in title.note.text(), "c'è il numero")
	assert_true("findahelpline.com" in title.note.text(), "e gli altri paesi")
	assert_eq(menu.get_node("quit").focus_mode, Control.FOCUS_NONE, "il menu sotto non prende il focus")
	await wait_seconds(title.note.MIN_SECONDS + 0.1)
	title.note.close()
	assert_true(await wait_signal(title.note.closed, 2.0), "chiusa")
	assert_eq(menu.focused_id(), &"help", "si torna sulla stessa voce")


func test_la_porta_bussa_e_i_piedi_se_ne_vanno() -> void:
	Engine.time_scale = 4.0
	var title := _title()
	await tree.process_frame
	var door: Node2D = title.get_node("%Door")
	door.sound = false
	assert_false(door.knocking_enabled, "prima del menu non bussa")
	title.skip_reveal()
	assert_true(door.knocking_enabled, "col menu sì")
	door.first_knock = 0.0
	door.knock()
	assert_true(door.feet, "i piedi sotto la porta")
	await wait_seconds(door.FEET_STAY + 1.2)
	assert_false(door.feet, "poi se ne vanno")
	var rng := RandomNumberGenerator.new()
	for i in 30:
		var gap := TitleDoor.next_gap(rng, door.knock_every)
		assert_true(gap >= door.knock_every.x and gap <= door.knock_every.y, "intervallo nei limiti")
	for i in 50:
		var l := TitleDoor.light_level(i * 0.37)
		assert_true(l >= 0.8 - 0.0001 and l <= 1.0 + 0.0001, "la luce respira nei limiti: %s" % l)


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
