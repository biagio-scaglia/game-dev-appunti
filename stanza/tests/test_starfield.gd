extends "res://tests/base_test.gd"
## Il cielo stellato: generazione e luminosità.

const Starfield := preload("res://studio_intro/fx/starfield.gd")
const AREA := Rect2(-340, -200, 680, 400)
const CLEAR := Rect2(-190, 0, 380, 70)


func test_stesso_seme_stesso_cielo() -> void:
	var a := Starfield.generate_stars(42, 30, AREA, CLEAR)
	var b := Starfield.generate_stars(42, 30, AREA, CLEAR)
	assert_eq(a, b, "due cieli con lo stesso seme")
	var c := Starfield.generate_stars(43, 30, AREA, CLEAR)
	assert_true(a != c, "seme diverso = cielo diverso")


func test_numero_e_zone_delle_stelle() -> void:
	var stars := Starfield.generate_stars(1987, 46, AREA, CLEAR)
	assert_eq(stars.size(), 46, "numero di stelle")
	for s in stars:
		var p: Vector2 = s["pos"]
		assert_false(CLEAR.has_point(p), "stella nella zona del nome: %s" % p)
		assert_true(AREA.grow(1).has_point(p), "stella fuori dall'area: %s" % p)
		assert_eq(p, p.round(), "posizione non intera")


func test_stella_spenta_prima_della_sua_accensione() -> void:
	var s := {"alpha": 1.0, "speed": 1.0, "phase": 0.0, "delay": 1.0}
	assert_near(Starfield.star_alpha(s, 0.0, 0.0), 0.0, 0.001, "reveal 0")
	assert_true(Starfield.star_alpha(s, 1.0, 0.0) > 0.5, "reveal 1: accesa")


func test_tremolio_resta_nei_limiti() -> void:
	var s := {"alpha": 0.8, "speed": 2.0, "phase": 1.0, "delay": 0.0}
	for i in 50:
		var a := Starfield.star_alpha(s, 1.0, i * 0.1)
		assert_true(a >= 0.8 * 0.3 - 0.001 and a <= 0.8 + 0.001, "alpha fuori range: %s" % a)
