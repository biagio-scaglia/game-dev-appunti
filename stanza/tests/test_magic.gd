extends "res://tests/base_test.gd"
## Effetti magici: animazioni, proiettile con la scia, impatto con scintille e tremolio.

const MagicFrames := preload("res://magic/magic_frames.gd")
const PROJECTILE := preload("res://magic/projectile.tscn")
const CHARGE := preload("res://magic/charge.tscn")
const IMPACT := preload("res://magic/impact.tscn")
const ScreenShake := preload("res://fx/screen_shake.gd")


func test_le_tre_animazioni_e_i_loro_tempi() -> void:
	var frames := MagicFrames.build()
	var counts := {&"charge": 8, &"projectile": 4, &"impact": 9}
	for anim: StringName in counts:
		assert_eq(frames.get_frame_count(anim), counts[anim], "fotogrammi di %s" % anim)
	assert_true(MagicFrames.duration(&"charge") < 0.35, "la carica è rapida: finisce col lancio")
	assert_true(MagicFrames.duration(&"impact") > MagicFrames.duration(&"charge"), "l'impatto dura di più")
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


func test_il_proiettile_lascia_una_scia_che_resta_dopo_l_esplosione() -> void:
	Engine.time_scale = 4.0
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_owned.append(holder)
	var shot := PROJECTILE.instantiate()
	shot.max_distance = 30.0
	holder.add_child(shot)
	assert_true(shot.trail.emitting, "la scia è accesa in volo")
	assert_true(await wait_signal(shot.exploded, 3.0), "esplode")
	var trails := holder.get_children().filter(func(n): return n is CPUParticles2D)
	assert_eq(trails.size(), 1, "la scia resta nel mondo")
	assert_false(trails[0].emitting, "ma non emette più")


func test_l_impatto_scoppia_in_scintille_e_fa_tremare_lo_schermo() -> void:
	await _no_shake()
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_owned.append(holder)
	var before := tree.root.get_viewport().canvas_transform
	var fx := IMPACT.instantiate()
	holder.add_child(fx)
	var bursts := fx.get_children().filter(func(n): return n is CPUParticles2D)
	assert_eq(bursts.size(), 1, "uno scoppio di scintille")
	assert_true(bursts[0].one_shot and bursts[0].emitting, "tutte insieme, una volta")
	assert_eq(tree.get_nodes_in_group(&"screen_shake").size(), 1, "trema")
	await wait_seconds(0.4)
	assert_eq(tree.root.get_viewport().canvas_transform, before, "la vista torna dov'era")


func test_due_tremolii_insieme_rimettono_la_vista_a_posto() -> void:
	await _no_shake()
	var before := tree.root.get_viewport().canvas_transform
	for i in 2:
		var s := ScreenShake.new()
		s.strength = 3.0
		tree.root.add_child(s)
		await tree.process_frame
	await wait_seconds(0.4)
	assert_eq(tree.root.get_viewport().canvas_transform, before, "nessuno spostamento rimasto")


func test_la_luce_della_carica_sale() -> void:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_owned.append(holder)
	var fx := CHARGE.instantiate()
	holder.add_child(fx)
	var start: float = fx.light.energy
	await wait_seconds(0.15)
	assert_true(fx.light.energy > start, "si sta raccogliendo: %s -> %s" % [start, fx.light.energy])


## Aspetta che non tremi più niente (un test precedente può averlo lasciato a metà).
func _no_shake() -> void:
	while not tree.get_nodes_in_group(&"screen_shake").is_empty():
		await tree.process_frame
