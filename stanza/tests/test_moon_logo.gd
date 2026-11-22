extends "res://tests/base_test.gd"
## La luna: fasi e animazioni.

const MoonLogo := preload("res://studio_intro/logo/moon_logo.gd")
const INTRO := "res://studio_intro/studio_intro.tscn"


## L'intro intera ferma (non parte da sola) per provare la luna da vicino.
func _moon() -> Node2D:
	var intro := add_scene(INTRO, func(n): n.set_script(null))
	return intro.get_node("%Moon")


func test_un_animazione_con_tutte_le_fasi() -> void:
	var frames := MoonLogo.build_frames()
	assert_eq(frames.get_animation_names(), PackedStringArray(["phases"]), "animazioni")
	assert_eq(frames.get_frame_count(&"phases"), MoonLogo.PHASES, "celle")


func test_set_phase_sceglie_la_cella_giusta() -> void:
	var moon := _moon()
	moon.set_phase(0.0)
	assert_eq(moon.sprite.frame, 0, "luna nuova")
	moon.set_phase(1.0)
	assert_eq(moon.sprite.frame, MoonLogo.PHASES - 1, "luna piena")
	moon.set_phase(7.0)
	assert_eq(moon.sprite.frame, MoonLogo.PHASES - 1, "oltre 1 resta piena")


func test_parte_nascosta_e_nuova() -> void:
	var moon := _moon()
	assert_false(moon.visible, "nascosta all'inizio")
	assert_near(moon.phase(), 0.0, 0.001, "fase iniziale")


func test_rise_e_wax_arrivano_a_luna_piena_al_suo_posto() -> void:
	Engine.time_scale = 8.0
	var moon := _moon()
	await moon.rise()
	assert_true(moon.visible, "visibile dopo rise")
	assert_eq(moon.position, moon.rest_position, "ferma al suo posto")
	assert_near(moon.modulate.a, 1.0, 0.01, "del tutto opaca")
	await moon.wax()
	assert_near(moon.phase(), 1.0, 0.001, "piena dopo wax")


func test_l_occhio_parte_chiuso_e_nascosto() -> void:
	var moon := _moon()
	assert_false(moon.eye.visible, "occhio nascosto")
	assert_false(moon.eye.is_open(), "occhio chiuso")


func test_watch_apre_e_richiude_l_occhio() -> void:
	Engine.time_scale = 8.0
	var moon := _moon()
	await moon.eye.open()
	assert_true(moon.eye.is_open(), "aperto dopo open")
	await moon.eye.close()
	assert_false(moon.eye.visible, "nascosto dopo close")
	await moon.watch(0.1)
	assert_false(moon.eye.is_open(), "chiuso dopo watch")


func test_rim_point_sta_sul_bordo() -> void:
	var moon := _moon()
	var p: Vector2 = moon.rim_point(0.0, 0.0)
	assert_near(p.distance_to(moon.rest_position), MoonLogo.RADIUS, 0.01, "distanza dal centro")
