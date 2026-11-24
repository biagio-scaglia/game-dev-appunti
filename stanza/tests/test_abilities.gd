extends "res://tests/base_test.gd"
## All'inizio Lethe non ha magia né spada: nella stanza Spazio / J e K non fanno niente.
## Quando le trova (learn, give) e si chiude il menu, tornano.

const MAIN := "res://main.tscn"


func after() -> void:
	tree.paused = false
	await super()


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await tree.physics_frame
	await tree.physics_frame
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)
	await tree.physics_frame


func test_nella_stanza_niente_magia_ne_spada() -> void:
	var main := add_scene(MAIN)
	await tree.process_frame
	main.music.stop()
	var hero: CharacterBody2D = main.hero
	assert_false(hero.can_cast, "niente magia")
	assert_false(hero.can_slash, "niente spada")
	await _press(&"cast")
	assert_false(hero.is_attacking(), "Spazio / J non fa niente")
	await _press(&"slash")
	assert_false(hero.is_attacking(), "K non fa niente")


func test_quando_le_trova_tornano() -> void:
	var main := add_scene(MAIN)
	await tree.process_frame
	main.music.stop()
	main.state.learn("truth_spark")
	main.state.give("glass_sword")
	main.pause_menu.open()
	main.pause_menu.close()
	assert_true(main.hero.can_cast, "la magia c'è")
	assert_true(main.hero.can_slash, "la spada pure")
	await _press(&"slash")
	assert_eq(main.hero.attacking, &"slash", "K fende")
