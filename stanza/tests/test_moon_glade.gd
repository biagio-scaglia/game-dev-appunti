extends "res://tests/base_test.gd"
## Il riflesso della luna sul lago.

const MoonGlade := preload("res://studio_intro/fx/moon_glade.gd")


func _streaks(time: float, bright: float) -> Array[Dictionary]:
	return MoonGlade.streaks(time, bright, 22, 3, 6.0, 34.0)


func test_spento_non_disegna_niente() -> void:
	assert_eq(_streaks(1.0, 0.0).size(), 0, "brightness 0")


func test_due_trattini_per_riga_a_pixel_interi() -> void:
	var s := _streaks(2.5, 1.0)
	assert_eq(s.size(), 44, "22 righe x 2")
	for item in s:
		var r: Rect2 = item["rect"]
		assert_eq(r.position, r.position.round(), "posizione intera")
		assert_true(r.size.x >= 2.0, "larghezza minima")


func test_piu_largo_e_tenue_verso_chi_guarda() -> void:
	var s := _streaks(0.0, 1.0)
	var first: Dictionary = s[0]
	var last: Dictionary = s[s.size() - 1]
	assert_true(first["alpha"] > last["alpha"], "all'orizzonte più luminoso")
	assert_true(last["rect"].position.y > first["rect"].position.y, "le righe scendono")
	for item in s:
		assert_true(absf(item["rect"].get_center().x) <= 34.0 + 1.0, "dentro la colonna")


func test_la_luminosita_scala_l_alpha() -> void:
	var full := _streaks(1.0, 1.0)
	var half := _streaks(1.0, 0.5)
	assert_near(half[0]["alpha"], full[0]["alpha"] * 0.5, 0.0001, "metà luce")
