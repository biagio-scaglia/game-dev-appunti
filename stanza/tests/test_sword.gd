extends "res://tests/base_test.gd"
## La spada di vetro dello specchio: stadi, fendente, zona che colpisce, schegge.

const SwordFrames := preload("res://weapon/sword_frames.gd")
const SWORD := preload("res://weapon/glass_sword.tscn")


func _sword(stage := 0, direction := Vector2.RIGHT) -> Node2D:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_owned.append(holder)
	var sword := SWORD.instantiate()
	sword.stage = stage
	sword.direction = direction
	holder.add_child(sword)
	sword.global_position = Vector2(300, 200)
	return sword


func test_tre_stadi_da_sei_fotogrammi() -> void:
	var frames := SwordFrames.build()
	for stage in 3:
		assert_eq(frames.get_frame_count(SwordFrames.animation(stage)), 6, "stadio %d" % stage)
	assert_eq(SwordFrames.animation(7), &"slash_2", "oltre la lama resta la lama")


func test_la_lama_cresce_con_gli_stadi() -> void:
	var small := _sword(0)
	var big := _sword(2)
	var r0: float = (small.shape.shape as CircleShape2D).radius
	var r2: float = (big.shape.shape as CircleShape2D).radius
	assert_true(r2 > r0, "la lama arriva più lontano della scheggia: %s > %s" % [r2, r0])


func test_verso_sinistra_fende_lo_stesso_dall_alto() -> void:
	var sword := _sword(1, Vector2.LEFT)
	assert_near(absf(sword.sprite.rotation), PI, 0.001, "girata verso sinistra")
	assert_true(sword.sprite.flip_v, "e capovolta: il colpo scende dall'alto")
	assert_true(sword.shape.position.x < 0, "colpisce a sinistra")


func test_colpisce_solo_mentre_la_lama_passa_e_lascia_le_schegge() -> void:
	Engine.time_scale = 2.0
	var sword := _sword(1)
	assert_false(sword.is_striking(), "all'inizio la lama compare soltanto")
	var seen := {"striking": false, "shards": false}
	var deadline := Time.get_ticks_msec() + 2000
	while is_instance_valid(sword) and Time.get_ticks_msec() < deadline:
		seen["striking"] = seen["striking"] or sword.is_striking()
		seen["shards"] = seen["shards"] or sword.get_children().any(func(n): return n is CPUParticles2D)
		await tree.process_frame
	assert_true(seen["striking"], "a metà fendente colpisce")
	assert_true(seen["shards"], "il vetro si sbriciola in schegge")
	assert_false(is_instance_valid(sword), "poi sparisce da sola")


func test_un_nemico_nella_zona_viene_colpito() -> void:
	# Il nemico c'è già quando parte il fendente, come in gioco. (La zona deve restare
	# monitorable: con monitorable = false e livello 0 Godot 4.7 non rileva più niente.)
	Engine.time_scale = 2.0
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_owned.append(holder)
	var enemy := StaticBody2D.new()
	enemy.collision_layer = 4                     # livello "nemici"
	var body_shape := CollisionShape2D.new()
	body_shape.shape = CircleShape2D.new()
	(body_shape.shape as CircleShape2D).radius = 6.0
	enemy.add_child(body_shape)
	enemy.position = Vector2(318, 200)
	holder.add_child(enemy)
	await tree.physics_frame
	var sword := SWORD.instantiate()
	sword.stage = 2
	sword.position = Vector2(300, 200)
	holder.add_child(sword)
	var hits := {"n": 0}
	sword.hit.connect(func(_b): hits["n"] += 1)
	await wait_seconds(0.5)
	assert_eq(hits["n"], 1, "colpito una volta")
