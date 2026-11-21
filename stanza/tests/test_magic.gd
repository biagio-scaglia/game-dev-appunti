extends "res://tests/base_test.gd"
## Effetti magici: animazioni, proiettile, impatto.

const MagicFrames := preload("res://magic/magic_frames.gd")
const PROJECTILE := preload("res://magic/projectile.tscn")


func test_tre_animazioni_da_sei_fotogrammi() -> void:
	var frames := MagicFrames.build()
	for anim in [&"charge", &"projectile", &"impact"]:
		assert_eq(frames.get_frame_count(anim), 6, "fotogrammi di %s" % anim)
	assert_true(frames.get_animation_loop(&"projectile"), "il proiettile gira in loop")
	assert_false(frames.get_animation_loop(&"impact"), "l'impatto no")


func test_il_proiettile_vola_dritto_ed_esplode_a_fine_corsa() -> void:
	Engine.time_scale = 4.0
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_owned.append(holder)
	var shot := PROJECTILE.instantiate()
	shot.direction = Vector2.LEFT
	shot.max_distance = 60.0
	holder.add_child(shot)
	shot.global_position = Vector2(500, 200)
	var hit := {"at": Vector2.INF}
	shot.exploded.connect(func(at): hit["at"] = at)
	assert_true(await wait_signal(shot.exploded, 3.0), "esplode")
	assert_true(hit["at"].x < 445.0 and is_equal_approx(hit["at"].y, 200.0), "è andato a sinistra: %s" % hit["at"])
	var impacts := holder.get_children().filter(func(n): return n.name.begins_with("Impact"))
	assert_eq(impacts.size(), 1, "lascia un impatto")
	await wait_seconds(1.0)
	assert_eq(holder.get_child_count(), 0, "l'impatto sparisce da solo")


func test_il_proiettile_ha_la_sua_luce() -> void:
	var shot := PROJECTILE.instantiate()
	tree.root.add_child(shot)
	_owned.append(shot)
	var lights := shot.get_children().filter(func(n): return n is PointLight2D)
	assert_eq(lights.size(), 1, "una luce viola")
	assert_eq(shot.sprite.material.blend_mode, CanvasItemMaterial.BLEND_MODE_ADD, "blend additivo")
