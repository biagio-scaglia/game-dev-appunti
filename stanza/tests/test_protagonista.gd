extends "res://tests/base_test.gd"
## La protagonista in scena: animazioni, movimento, magia.
## Servono gli sprite in characters/protagonista/sprites/ (solo in locale).

const Frames := preload("res://characters/protagonista/protagonista_frames.gd")
const HERO := preload("res://characters/protagonista/protagonista.tscn")


func _hero() -> CharacterBody2D:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_owned.append(holder)
	var hero := HERO.instantiate()
	holder.add_child(hero)
	hero.position = Vector2(300, 200)
	return hero


func test_gli_sprite_ci_sono() -> void:
	assert_true(Frames.sprites_available(), "sprite in characters/protagonista/sprites/")


func test_tutte_le_animazioni_in_5_direzioni() -> void:
	var frames := Frames.build()
	var counts := {"idle": 4, "walk": 4, "run": 6, "attack": 7}
	for kind: String in counts:
		for row in ["down", "down_side", "side", "up_side", "up"]:
			assert_eq(frames.get_frame_count(StringName("%s_%s" % [kind, row])), counts[kind], "%s_%s" % [kind, row])


func test_parte_ferma_verso_il_basso() -> void:
	var hero := _hero()
	assert_eq(hero.sprite.animation, &"idle_down", "ferma, verso il basso")


func test_cammina_a_sinistra_specchiata_e_corre() -> void:
	var hero := _hero()
	hero.update_animation(Vector2.LEFT, false)
	assert_eq(hero.sprite.animation, &"walk_side", "cammina di lato")
	assert_true(hero.sprite.flip_h, "specchiata verso sinistra")
	hero.update_animation(Vector2(1, -1).normalized(), true)
	assert_eq(hero.sprite.animation, &"run_up_side", "corre su-destra")
	assert_false(hero.sprite.flip_h, "non specchiata verso destra")


func test_la_magia_carica_poi_lancia_il_proiettile() -> void:
	Engine.time_scale = 4.0
	var hero := _hero()
	hero.update_animation(Vector2.RIGHT, false)
	hero.update_animation(Vector2.ZERO, false)
	hero.cast()
	var holder := hero.get_parent()
	assert_eq(hero.sprite.animation, &"attack_side", "attacco di lato")
	assert_true(holder.get_children().any(func(n): return n.name.begins_with("Charge")), "parte la carica")
	assert_true(await wait_signal(hero.cast_finished, 3.0), "l'attacco finisce")
	var shots := holder.get_children().filter(func(n): return n.name.begins_with("Projectile"))
	assert_eq(shots.size(), 1, "è partito un proiettile")
	if shots.size() == 1:
		assert_eq(shots[0].direction, Vector2.RIGHT, "verso dove guardava")
	assert_eq(hero.sprite.animation, &"idle_side", "torna ferma")


func test_mentre_lancia_non_si_muove() -> void:
	var hero := _hero()
	var start := hero.position
	hero.cast()
	Input.action_press(&"move_left")
	await wait_seconds(0.2)
	Input.action_release(&"move_left")
	assert_eq(hero.position, start, "ferma durante la magia")
