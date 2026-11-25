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
	var counts := {"idle": 4, "walk": 4, "run": 6, "attack": 7, "slash": 7}
	for kind: String in counts:
		for row in ["down", "down_side", "side", "up_side", "up"]:
			assert_eq(frames.get_frame_count(StringName("%s_%s" % [kind, row])), counts[kind], "%s_%s" % [kind, row])


func test_ha_l_ombra_sotto_lo_sprite() -> void:
	var hero := _hero()
	var shadow: Node2D = hero.get_node("Shadow")
	assert_true(shadow.get_index() < hero.sprite.get_index(), "l'ombra si disegna prima dello sprite")
	assert_true(shadow.color.a > 0.0 and shadow.color.a < 1.0, "semitrasparente")


func test_l_ombra_e_un_ellisse_a_blocchi() -> void:
	var DropShadow := preload("res://fx/drop_shadow.gd")
	var rows := DropShadow.rows(Vector2(10, 4), 2)
	var box := rows[0]
	for row in rows:
		box = box.merge(row)
		for v in [row.position.x, row.position.y, row.size.x, row.size.y]:
			assert_true(is_equal_approx(fmod(absf(v), 2.0), 0.0), "sulla griglia da 2: %s" % row)
	assert_eq(box.size, Vector2(20, 8), "larga 20, alta 8")
	assert_true(rows[0].size.x < rows[1].size.x, "più stretta in alto che al centro")


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
	assert_true(await wait_signal(hero.attack_finished, 3.0), "l'attacco finisce")
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


func test_la_spada_fende_verso_dove_guarda() -> void:
	Engine.time_scale = 4.0
	var hero := _hero()
	hero.update_animation(Vector2.LEFT, false)
	hero.update_animation(Vector2.ZERO, false)
	hero.sword_stage = 2
	hero.slash()
	var holder := hero.get_parent()
	assert_eq(hero.sprite.animation, &"slash_side", "la posa con la scia di vetro")
	assert_true(hero.sprite.flip_h, "verso sinistra, specchiata")
	assert_false(holder.get_children().any(func(n): return n.name.begins_with("Charge")), "niente carica di magia")
	var kind := {"k": &""}
	hero.attack_finished.connect(func(k): kind["k"] = k)
	assert_true(await wait_signal(hero.attack_finished, 3.0), "il fendente finisce")
	assert_eq(kind["k"], &"slash", "era la spada")
	var swords := holder.get_children().filter(func(n): return n.name.begins_with("GlassSword"))
	assert_eq(swords.size(), 1, "una lama")
	if swords.size() == 1:
		assert_eq(swords[0].direction, Vector2.LEFT, "verso dove guardava")
		assert_eq(swords[0].stage, 2, "lo stadio della spada")


func test_non_si_attacca_due_volte_insieme() -> void:
	var hero := _hero()
	hero.cast()
	hero.slash()
	assert_eq(hero.attacking, &"cast", "la spada aspetta che finisca la magia")


func test_tenendo_una_direzione_corre_da_sola() -> void:
	var hero := _hero()
	Input.action_press(&"move_right")
	for i in 4:
		await tree.physics_frame
	assert_near(hero.velocity.x, hero.walk_speed, 0.5, "all'inizio cammina")
	await wait_seconds(hero.auto_run_after + 0.1)
	assert_true(hero.is_auto_running(), "poi si mette a correre")
	assert_near(hero.velocity.x, hero.run_speed, 0.5, "senza Shift")
	Input.action_release(&"move_right")
	await tree.physics_frame
	await tree.physics_frame
	assert_false(hero.is_auto_running(), "lasciata la direzione si riparte camminando")


func test_lo_schema_dei_tasti() -> void:
	var InputSetup := preload("res://core/input_setup.gd")
	InputSetup.ensure_actions()
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	assert_true(InputMap.action_has_event(&"slash", space) and InputMap.action_has_event(&"interact", space),
		"Spazio è il tasto unico: parla o colpisce")
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	assert_true(InputMap.action_has_event(&"cast", q), "Q è la magia")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	assert_true(InputMap.action_has_event(&"menu", esc), "Esc il menu")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	assert_true(InputMap.action_has_event(&"slash", left), "anche col mouse")
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_") or action in [&"slash", &"interact"]:
			continue
		for other in [&"slash", &"cast", &"menu"]:
			if other == action or not InputMap.has_action(action):
				continue
			for event in InputMap.action_get_events(action):
				assert_false(InputMap.action_has_event(other, event) and action in InputSetup.ACTIONS,
					"%s e %s non si pestano i piedi (%s)" % [action, other, event.as_text()])
