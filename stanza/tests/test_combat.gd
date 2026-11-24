extends "res://tests/base_test.gd"
## Il combattimento: il cuore (stato e disegno), Lethe che prende i colpi, le debolezze dei
## nemici, come si comportano la falena, il rovo e la lucciola falsa, la spada e la magia
## che li colpiscono davvero, e nella foresta la morte e il risveglio allo specchio.

const GameState := preload("res://menu/game_state.gd")
const HeartHud := preload("res://ui/heart_hud.gd")
const Moth := preload("res://enemies/shadow_moth.gd")
const Bramble := preload("res://enemies/whispering_bramble.gd")
const Firefly := preload("res://enemies/false_firefly.gd")
const HERO := preload("res://characters/protagonista/protagonista.tscn")
const PROJECTILE := preload("res://magic/projectile.tscn")
const Main := preload("res://main.gd")


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _holder() -> Node2D:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	_owned.append(holder)
	return holder


func _hero(holder: Node2D, at: Vector2) -> CharacterBody2D:
	var hero: CharacterBody2D = HERO.instantiate()
	holder.add_child(hero)
	hero.global_position = at
	return hero


func _enemy(holder: Node2D, script: GDScript, at: Vector2, target: Node2D = null) -> CharacterBody2D:
	var enemy: CharacterBody2D = script.new()
	enemy.sound = false
	enemy.target = target
	enemy.position = at
	holder.add_child(enemy)
	return enemy


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


# --- Il cuore -------------------------------------------------------------------------------

func test_il_cuore_nello_stato() -> void:
	var state := GameState.new()
	assert_eq(state.heart, state.heart_max, "si parte col cuore intero")
	assert_eq(state.hurt(1), 3, "un colpo")
	assert_eq(state.squeeze(), 1, "la mano stringe un po'")
	state.hurt(10)
	assert_true(state.is_dead(), "stretto del tutto")
	assert_eq(state.heart, 0, "mai sotto zero")
	state.heal(2)
	assert_eq(state.heart, 2, "si cura")
	state.heal(99)
	assert_eq(state.heart, state.heart_max, "mai sopra il massimo")
	state.hurt(1)
	var loaded := GameState.new()
	loaded.load_save(state.to_save(Vector2.ZERO, 0))
	assert_eq(loaded.heart, 3, "si salva")


func test_il_disegno_del_cuore() -> void:
	assert_eq(HeartHud.stage_for(4, 4), 0, "intero")
	assert_eq(HeartHud.stage_for(3, 4), 1, "la mano lo tocca")
	assert_eq(HeartHud.stage_for(1, 4), 3, "la mano lo stringe")
	assert_eq(HeartHud.stage_for(0, 4), 4, "stretto del tutto")
	assert_eq(HeartHud.stage_for(5, 6), 1, "con un cuore più grande, piano piano")
	assert_true(HeartHud.beats_per_second(1, 4) > HeartHud.beats_per_second(4, 4), "con poco cuore batte in fretta")


func test_lethe_prende_un_colpo() -> void:
	var holder := _holder()
	var hero := _hero(holder, Vector2(200, 200))
	var got := {"n": 0}
	hero.damaged.connect(func(_a, _f): got["n"] += 1)
	assert_true(hero.hurt(1, Vector2(180, 200)), "il primo colpo arriva")
	assert_true(hero.knock.x > 0.0, "spinta via dal colpo")
	assert_false(hero.hurt(1, Vector2(180, 200)), "subito dopo no: è invulnerabile")
	assert_eq(got["n"], 1, "un colpo solo")
	await _frames(4)
	assert_true(hero.global_position.x > 200.0, "la spinta la sposta")
	hero.invulnerable = 0.0
	hero.frozen = true
	assert_false(hero.hurt(1, Vector2.ZERO), "mentre parla non la colpiscono")


# --- I nemici --------------------------------------------------------------------------------

func test_le_debolezze() -> void:
	var holder := _holder()
	var moth := _enemy(holder, Moth, Vector2(100, 100))
	var bramble := _enemy(holder, Bramble, Vector2(200, 100))
	var fly := _enemy(holder, Firefly, Vector2(300, 100))
	await tree.process_frame
	assert_eq(moth.damage_from(2, &"sword"), 1, "la spada attraversa la falena")
	assert_true(moth.damage_from(3, &"magic") >= moth.max_hp, "la magia la scioglie in un colpo")
	assert_eq(bramble.damage_from(2, &"sword"), 3, "la spada taglia il rovo")
	assert_eq(bramble.damage_from(3, &"magic"), 2, "la magia gli fa poco")
	assert_eq(fly.damage_from(2, &"sword"), 2, "la lucciola: niente debolezze")


func test_un_nemico_muore() -> void:
	var holder := _holder()
	var fly := _enemy(holder, Firefly, Vector2(100, 100))
	await tree.process_frame
	var got := {"died": false}
	fly.died.connect(func(_e): got["died"] = true)
	fly.hurt(1, &"sword", Vector2(90, 100))
	assert_eq(fly.hp, 1, "un colpo")
	assert_false(fly.state == Firefly.State.HIDDEN, "colpita, si scopre")
	fly.hurt(1, &"sword", Vector2(90, 100))
	assert_true(got["died"], "il secondo la scioglie")
	assert_eq(fly.collision_layer, 0, "da morta non si colpisce più")
	await wait_seconds(0.4)
	assert_false(is_instance_valid(fly), "e sparisce")


func test_la_falena_gira_e_si_butta() -> void:
	Engine.time_scale = 3.0
	var holder := _holder()
	var hero := _hero(holder, Vector2(300, 300))
	hero.set_physics_process(false)
	var moth := _enemy(holder, Moth, Vector2(380, 300), hero)
	await tree.process_frame
	await _frames(3)
	assert_eq(moth.state, Moth.State.HUNT, "vede Lethe: le gira intorno")
	var seen := {"windup": false, "dive": false, "hurtful": false}
	for i in 240:
		await tree.physics_frame
		seen["windup"] = seen["windup"] or moth.state == Moth.State.WINDUP
		if moth.state == Moth.State.DIVE:
			seen["dive"] = true
			seen["hurtful"] = seen["hurtful"] or moth.hurtful
		if seen["dive"]:
			break
	assert_true(seen["windup"], "prima si ferma (si vede arrivare)")
	assert_true(seen["dive"], "poi si butta")
	assert_true(seen["hurtful"], "e lì fa male")


func test_la_falena_va_alla_luce() -> void:
	var holder := _holder()
	var moth := _enemy(holder, Moth, Vector2(100, 100))
	var light := Node2D.new()
	light.add_to_group(&"lure")
	light.position = Vector2(200, 120)
	holder.add_child(light)
	await tree.process_frame
	await _frames(3)
	assert_eq(moth.state, Moth.State.LURED, "va verso la luce")
	var before := moth.global_position.distance_to(light.global_position)
	await _frames(20)
	assert_true(moth.global_position.distance_to(light.global_position) < before, "si avvicina")
	assert_false(moth.hurtful, "distratta, non fa male")


func test_il_rovo_sussurra_e_frusta() -> void:
	var holder := _holder()
	var hero := _hero(holder, Vector2(300, 300))
	hero.set_physics_process(false)
	var bramble := _enemy(holder, Bramble, Vector2(340, 300), hero)
	await tree.process_frame
	await _frames(2)
	assert_eq(bramble.state, Bramble.State.SHIVER, "Lethe vicina: trema")
	assert_true(bramble.last_lie() in Bramble.LIES, "e sussurra una sua bugia")
	assert_true(bramble.get_children().any(func(n): return n is Label), "che si legge sopra")
	assert_false(bramble.hurtful, "mentre trema non fa ancora male: si può scappare")
	var got := {"hit": false}
	hero.damaged.connect(func(_a, _f): got["hit"] = true)
	for i in 90:
		await tree.physics_frame
		if got["hit"]:
			break
	assert_true(got["hit"], "poi frusta, e arriva fino a lei")
	assert_true(bramble.collision_layer & 1, "e blocca il passaggio")


func test_la_lucciola_falsa() -> void:
	Engine.time_scale = 2.0
	var holder := _holder()
	var hero := _hero(holder, Vector2(100, 300))
	hero.set_physics_process(false)
	var fly := _enemy(holder, Firefly, Vector2(300, 300), hero)
	await tree.process_frame
	await _frames(3)
	assert_true(fly.is_hidden(), "da lontano è una lucciola come le altre")
	assert_false(fly.hurtful, "e non fa male")
	hero.global_position = Vector2(260, 300)
	await _frames(3)
	assert_false(fly.is_hidden(), "da vicino si apre")
	await wait_seconds(0.3)
	assert_eq(fly.state, Firefly.State.CHASE, "e la insegue")
	hero.global_position = Vector2(900, 300)
	await _frames(4)
	assert_true(fly.state in [Firefly.State.RETURN, Firefly.State.HIDDEN], "se Lethe scappa lontano, torna indietro")
	assert_false(fly.hurtful, "e smette di mordere")
	for i in 120:
		await tree.physics_frame
		if fly.is_hidden():
			break
	assert_true(fly.is_hidden(), "e torna a fare la lucciola")
	assert_true(fly.global_position.distance_to(fly.home) < 3.0, "al suo posto")


func test_la_spada_e_la_magia_colpiscono() -> void:
	var holder := _holder()
	var hero := _hero(holder, Vector2(200, 200))
	hero.facing = Vector2.RIGHT
	var bramble := _enemy(holder, Bramble, Vector2(240, 205))
	bramble.set_physics_process(false)
	await tree.process_frame
	hero.slash()
	for i in 60:
		await tree.physics_frame
		if bramble.hp < bramble.max_hp:
			break
	assert_eq(bramble.hp, bramble.max_hp - 3, "la spada lo taglia")
	var moth := _enemy(holder, Moth, Vector2(500, 200))
	moth.set_physics_process(false)
	await tree.process_frame
	var shot: Area2D = PROJECTILE.instantiate()
	shot.direction = Vector2.RIGHT
	holder.add_child(shot)
	shot.global_position = Vector2(440, 200 - Moth.LIFT - 10)
	var got := {"died": false}
	moth.died.connect(func(_e): got["died"] = true)
	for i in 60:
		await tree.physics_frame
		if got["died"]:
			break
	assert_true(got["died"], "la magia scioglie la falena")


# --- Nella foresta -----------------------------------------------------------------------------

func _zone() -> Node2D:
	Main.pending_save = {"flags": {"forest_arrived": true, "talk_learned": true}}
	var zone := add_scene("res://forest/zone_wake.tscn", func(n): n.sound = false)
	await tree.process_frame
	return zone


func test_nella_foresta_ci_sono_i_nemici() -> void:
	var zone := await _zone()
	var Layout := preload("res://forest/zone_wake_layout.gd")
	assert_eq(zone.enemies().size(), Layout.ENEMIES.size(), "tutti al loro posto")
	for enemy in zone.enemies():
		assert_eq(enemy.target, zone.hero, "cercano Lethe")
		assert_true(enemy.global_position.distance_to(zone.spawn.global_position) > 150.0,
			"%s non è addosso a dove arriva Lethe" % enemy.name)
	assert_eq(zone.hud.heart, zone.state.heart, "il cuore in alto")


func test_un_colpo_stringe_il_cuore() -> void:
	var zone := await _zone()
	zone.hero.hurt(1, zone.hero.global_position + Vector2(10, 0))
	assert_eq(zone.state.heart, zone.state.heart_max - 1, "un pezzo di cuore in meno")
	assert_eq(zone.hud.icon.frame, 1, "la mano lo tocca")


func test_morire_e_risvegliarsi_allo_specchio() -> void:
	Engine.time_scale = 6.0
	var zone := await _zone()
	zone.talk.talk("mirror")
	for i in 200:
		await tree.process_frame
		var box = zone.talk.box
		if not is_instance_valid(box):
			break
		if box.waiting or box.text_label.is_typing:
			box.advance()
	assert_true(zone.state.flag("rested"), "allo specchio ci si riposa")
	var mirror_point: Vector2 = zone.respawn_point
	assert_true(mirror_point.distance_to(zone.spawn.global_position) > 10.0, "e da lì si ripartirà")
	await tree.physics_frame
	await tree.physics_frame
	zone.hero.global_position = Vector2(900, 380)
	zone.state.heart = 1
	zone.hero.hurt(1, Vector2(890, 380))
	assert_true(zone.state.is_dead(), "stretto del tutto")
	assert_true(zone.hero.frozen, "tutto si ferma")
	assert_true(await wait_signal(zone.respawned, 4.0), "Death is a lie: si riparte")
	assert_eq(zone.state.heart, zone.state.heart_max, "col cuore intero")
	assert_true(zone.hero.global_position.distance_to(mirror_point) < 1.0, "davanti allo specchio")
	await tree.process_frame
	assert_eq(zone.enemies().size(), preload("res://forest/zone_wake_layout.gd").ENEMIES.size(),
		"i nemici tornano al loro posto")


func test_la_mira_assistita_della_spada() -> void:
	var holder := _holder()
	var hero := _hero(holder, Vector2(200, 200))
	hero.facing = Vector2.RIGHT
	var fly := _enemy(holder, Firefly, Vector2(240, 230))      # davanti, un po' in basso
	fly.set_physics_process(false)
	var behind := _enemy(holder, Firefly, Vector2(150, 200))   # dietro: non conta
	behind.set_physics_process(false)
	await tree.process_frame
	var aim: Vector2 = hero.aim_at_enemy()
	assert_true(aim.x > 0.0 and aim.y > 0.0, "punta il nemico davanti, non quello dietro")
	hero.slash()
	assert_eq(hero.facing, Vector2(1, 1), "si gira verso di lui")
	for i in 40:
		await tree.physics_frame
		if fly.hp < fly.max_hp:
			break
	assert_true(fly.hp < fly.max_hp, "e lo prende anche se non lo guardava dritto")
	assert_eq(behind.hp, behind.max_hp, "quello dietro no")
	await wait_seconds(0.2)
	assert_near(Engine.time_scale, 1.0, 0.001, "dopo il fermo del colpo il tempo torna normale")


func test_la_spada_parte_subito() -> void:
	var holder := _holder()
	var hero := _hero(holder, Vector2(200, 200))
	hero.facing = Vector2.RIGHT
	var start := Time.get_ticks_msec()
	hero.slash()
	var is_sword := func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("glass_sword.gd")
	while holder.get_children().filter(is_sword).is_empty() and Time.get_ticks_msec() - start < 1000:
		await tree.process_frame
	var ms := Time.get_ticks_msec() - start
	assert_true(ms < 150, "la lama arriva subito (%d ms; prima erano più di 200)" % ms)


func test_il_riquadro_del_cuore() -> void:
	var zone := await _zone()
	var box: PanelContainer = zone.hud.box
	assert_true(box.position.y + box.size.y <= 360.0 and box.position.y > 240.0, "in basso")
	assert_true(box.position.x < 40.0, "a sinistra")
	assert_false(zone.objective.heart.visible, "di cuore ce n'è uno solo")
	zone.talk.talk("mirror")
	await wait_seconds(0.3)
	assert_true(box.modulate.a < 0.1, "durante un dialogo si nasconde (il testo sta in basso)")


# --- Esperienza, livelli, segreti ------------------------------------------------------------

func test_la_curva_dei_livelli() -> void:
	var costs := []
	for lv in range(1, 6):
		costs.append(GameState.exp_to_next(lv))
	assert_eq(costs, [10, 28, 52, 80, 112], "ogni livello costa più del precedente")
	var state := GameState.new()
	assert_eq(state.gain_exp(9), 0, "non ancora")
	assert_eq(state.gain_exp(1), 1, "livello 2")
	assert_eq(state.heart_max, 5, "ai pari: il cuore regge di più")
	assert_eq(state.attack_bonus(), 0, "la spada ancora no")
	state.gain_exp(28)
	assert_eq(state.level, 3, "livello 3")
	assert_eq(state.heart_max, 5, "ai dispari il cuore no...")
	assert_eq(state.attack_bonus(), 1, "...ma la spada taglia di più")
	state.heart = 1
	state.gain_exp(52)
	assert_eq(state.heart, state.heart_max, "a ogni livello il cuore torna intero")
	for i in 20:
		state.gain_exp(500)
	assert_eq(state.heart_max, GameState.HEART_CAP, "mai oltre il massimo")


func test_niente_esperienza_facile() -> void:
	var state := GameState.new()
	assert_eq(state.exp_from(4, 1), 4, "alla pari: tutta")
	state.level = 3
	assert_eq(state.exp_from(4, 1), 2, "due livelli sopra: la metà")
	state.level = 6
	assert_eq(state.exp_from(4, 1), 1, "molto sopra: quasi niente (morire e rifarli non conviene)")


func test_un_nemico_sciolto_lascia_luce() -> void:
	var zone := await _zone()
	var fly: CharacterBody2D = zone.enemies().filter(func(e): return e is Firefly)[0]
	fly.drop_chance = 1.0
	var before: int = zone.state.xp
	var reward: int = fly.exp_reward
	fly.hurt(99, &"sword", fly.global_position + Vector2(-5, 0))
	await wait_seconds(1.2)
	assert_eq(zone.state.xp, before + reward, "la luce arriva a Lethe: esperienza")
	var apples: Array = zone.world.get_children().filter(func(n): return n is Area2D and n.get(&"id") == "apple")
	assert_eq(apples.size(), 1, "e una mela per terra")
	zone.state.heart = 2
	apples[0].picked.emit("apple")
	assert_eq(zone.state.heart, 3, "la mela cura")


func test_il_tasto_della_spada() -> void:
	var zone := await _zone()
	zone.state.give("glass_sword")
	zone.sync_abilities()
	assert_eq(zone.slash_hint, null, "lontano dai nemici: niente")
	var moth: Node2D = zone.enemies()[0]
	zone.hero.global_position = moth.global_position + Vector2(60, 0)
	await tree.process_frame
	await tree.process_frame
	assert_true(zone.slash_hint != null, "un nemico vicino: compare K")
	var label: Label = zone.slash_hint.get_child(0).get_child(0)
	assert_true(label.text.begins_with("K"), "dice il tasto")
	zone._on_hero_attack(&"slash")
	assert_eq(zone.slash_hint, null, "al primo fendente sparisce")
	assert_true(zone.state.flag("slash_learned"), "e non torna")


func test_il_segreto_della_decima_morte() -> void:
	var zone := await _zone()
	zone.state.flags["deaths"] = 9
	var max_before: int = zone.state.heart_max
	var got := {"secret": false}
	zone.secret_shown.connect(func(): got["secret"] = true)
	zone.die(0.05)
	assert_true(await wait_signal(zone.respawned, 6.0), "si riparte")
	assert_true(got["secret"], "la decima volta: il finto reset")
	assert_eq(zone.state.deaths(), 10, "dieci")
	assert_eq(zone.state.heart_max, max_before + 1, "e la mano molla un po'")
	assert_true(zone.state.flag("secret_ten"), "segnato")


func test_il_menu_mostra_cuore_e_livello() -> void:
	var HeroCard := preload("res://menu/hero_card.gd")
	var card := HeroCard.new()
	tree.root.add_child(card)
	_owned.append(card)
	var state := GameState.new()
	state.gain_exp(15)
	state.heart = 3
	card.refresh(state)
	assert_eq(card.level_label.text, "Lv 2", "il livello")
	assert_eq(card.hp.numbers(), "3/5", "il cuore")
	assert_eq(card.xp.numbers(), "5/28", "l'esperienza verso il prossimo")


# --- Come si sente il combattimento ---------------------------------------------------------------

func test_i_numeri_del_danno() -> void:
	var DamageNumber := preload("res://fx/damage_number.gd")
	assert_eq(DamageNumber.color_for(1.5), DamageNumber.STRONG, "punto debole: rosa")
	assert_eq(DamageNumber.color_for(0.5), DamageNumber.WEAK, "l'arma fa poco: grigio")
	var holder := _holder()
	var bramble := _enemy(holder, Bramble, Vector2(200, 200))
	bramble.set_physics_process(false)
	await tree.process_frame
	bramble.hurt(2, &"sword", Vector2(180, 200))
	var numbers := holder.get_children().filter(func(n): return n is Label and n.text == "3")
	assert_eq(numbers.size(), 1, "il numero salta fuori (2 di spada x1.5 = 3)")
	assert_eq(numbers[0].get_theme_color(&"font_color"), DamageNumber.STRONG, "rosa: la spada è giusta per il rovo")
	await wait_seconds(0.9)
	assert_false(is_instance_valid(numbers[0]), "e poi svanisce")


func test_la_barretta_e_il_colpo_che_scompone() -> void:
	var holder := _holder()
	var hero := _hero(holder, Vector2(100, 200))
	hero.set_physics_process(false)
	var fly := _enemy(holder, Firefly, Vector2(300, 200), hero)
	await tree.process_frame
	fly.max_hp = 5
	fly.hp = 5
	assert_true(fly._bar_time <= 0.0, "intero: niente barretta")
	fly.hurt(1, &"sword", Vector2(290, 200))
	assert_true(fly._bar_time > 0.0, "colpito: la barretta sopra")
	assert_true(fly.is_staggered(), "e scomposto per un attimo")
	var at: Vector2 = fly.global_position
	hero.global_position = fly.global_position + Vector2(20, 0)
	await _frames(3)
	assert_true(fly.state == Firefly.State.REVEAL or fly.global_position.distance_to(at) < 30.0,
		"scomposto non insegue subito")


func test_il_colpo_dopo_non_si_perde() -> void:
	var holder := _holder()
	var hero := _hero(holder, Vector2(200, 200))
	hero.facing = Vector2.RIGHT
	hero.slash()
	# Verso la fine del fendente (gli ultimi due fotogrammi), come chi gioca.
	var sprite: AnimatedSprite2D = hero.sprite
	var last := sprite.sprite_frames.get_frame_count(sprite.animation) - 1
	for i in 120:
		if sprite.frame >= last - 1:
			break
		await tree.process_frame
	assert_true(hero.is_attacking(), "il primo fendente è ancora in corso")
	var ev := InputEventAction.new()
	ev.action = &"slash"
	ev.pressed = true
	Input.parse_input_event(ev)
	await tree.physics_frame
	await tree.physics_frame
	var up := InputEventAction.new()
	up.action = &"slash"
	Input.parse_input_event(up)
	assert_true(hero._buffered > 0.0, "premuto durante il fendente: se lo ricorda")
	var got := {"n": 0}
	hero.attack_finished.connect(func(k): if k == &"slash": got["n"] += 1)
	for i in 120:
		await tree.physics_frame
		if got["n"] >= 2:
			break
	assert_eq(got["n"], 2, "e il secondo fendente parte appena finisce il primo")


func test_l_esperienza_si_vede_quando_arriva() -> void:
	var zone := await _zone()
	zone.gain_exp(5)
	var popups := zone.get_children().filter(func(n): return n is Label and n.text == "+5 EXP")
	assert_eq(popups.size(), 1, "sopra Lethe sale +5 EXP")
	assert_eq(zone.state.xp, 5, "e l'esperienza c'è")
	zone.gain_exp(9)
	assert_eq(zone.state.level, 2, "livello 2")
	assert_eq(zone.hud.heart_max, 5, "col cuore più grande")
	assert_false(zone.hud.box.get_children().any(func(n): return n is ProgressBar), "nel riquadro del cuore solo il cuore")


func test_sotto_il_menu_di_pausa() -> void:
	var zone := await _zone()
	var menu_layer: int = zone.pause_menu.layer
	assert_true(zone.hud.layer < menu_layer, "il cuore sta sotto il menu")
	assert_true(zone.objective.layer < menu_layer, "anche l'obiettivo")
