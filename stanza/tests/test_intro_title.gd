extends "res://tests/base_test.gd"
## Il nome scritto lettera per lettera.

const INTRO := "res://studio_intro/studio_intro.tscn"


func _title() -> Control:
	var intro := add_scene(INTRO, func(n): n.set_script(null))
	return intro.get_node("%Title")


func test_setup_nasconde_il_nome() -> void:
	var title := _title()
	title.setup("LUNA STUDIO")
	assert_eq(title.name_label.text, "LUNA STUDIO", "testo")
	assert_eq(title.name_label.visible_characters, 0, "nessuna lettera visibile")
	assert_false(title.is_fully_typed(), "non ancora scritto")


func test_sottotitolo_vuoto_resta_nascosto() -> void:
	var title := _title()
	title.setup("X", "")
	assert_false(title.subtitle_label.visible, "nessun sottotitolo")
	await title.show_subtitle()
	assert_false(title.is_subtitle_shown(), "show_subtitle non fa niente")


func test_show_subtitle_lo_porta_al_suo_posto() -> void:
	Engine.time_scale = 8.0
	var title := _title()
	var rest: Vector2 = title.subtitle_label.position
	title.setup("X", "presenta")
	assert_false(title.is_subtitle_shown(), "nascosto dopo setup")
	await title.show_subtitle()
	assert_true(title.is_subtitle_shown(), "visibile")
	assert_eq(title.subtitle_label.position, rest, "tornato alla sua posizione")


func test_type_name_scrive_tutto() -> void:
	Engine.time_scale = 8.0
	var title := _title()
	title.setup("AB CD")
	await title.type_name()
	assert_true(title.is_fully_typed(), "tutte le lettere visibili")
