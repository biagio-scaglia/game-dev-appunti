extends "res://tests/base_test.gd"
## Il dungeon delle radici, passo 6: il Cervo Secco. La scena d'entrata (le radici richiudono
## dietro), la carica contro la parete e lo stordimento (lì prende il doppio, altrimenti la
## corteccia ferma metà della spada), la seconda fase, i rami che cadono, le due fini (la
## magia lo libera, la spada lo rompe), Lethe che cade e si ricomincia, il salvataggio, la
## foglia.

const ROOTS := "res://forest/zone_roots.tscn"
const Main := preload("res://main.gd")
const DryDeer := preload("res://enemies/dry_deer.gd")
const FallingBranch := preload("res://fx/falling_branch.gd")
const TILE := 32


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _zone(flags := {}) -> Node2D:
	var all := {"forest_arrived": true, "talk_learned": true, "selene_met": true, "roots_arrived": true,
		"first_enemy_seen": true, "slash_learned": true, "heart_seen": true, "room_heart": true,
		"room_arena": true, "lanterns_lit": true, "gate_arena": true, "gate_thorns": true,
		"key_old_key": true, "door_bedroom": true}
	all.merge(flags, true)
	Main.pending_save = {"zone": "roots", "entry": "top", "flags": all, "truth": 3,
		"learned": ["truth_spark"], "spell": "truth_spark"}
	var zone := add_scene(ROOTS, func(n): n.sound = false)
	await tree.process_frame
	for enemy in zone.enemies():
		enemy.queue_free()
	await tree.process_frame
	return zone


## Guida il prossimo dialogo: aspetta che compaia (le scene hanno panoramiche prima), poi va
## avanti fino alla fine.
func _drive(talk: Node) -> void:
	var seen := false
	for i in 1200:
		await tree.process_frame
		var box = talk.box
		if not is_instance_valid(box):
			if seen:
				break
			continue
		seen = true
		box.sound = false
		if box.waiting or box.text_label.is_typing:
			box.advance()
	await tree.physics_frame


## Lethe nell'arena e lo scontro cominciato (la scena guidata fino in fondo).
func _fight(zone: Node2D) -> DryDeer:
	zone.story.cut.pace = 0.05
	zone.hero.global_position = Vector2(29.5 * TILE, 9.5 * TILE)
	var started: Signal = zone.boss.fight_started
	zone.boss.start_fight()
	_drive(zone.talk)
	await wait_signal(started, 8.0)
	return zone.boss.deer


func test_il_cervo_dorme_nell_arena() -> void:
	var zone := await _zone()
	var deer: DryDeer = zone.boss.deer
	assert_true(deer != null, "c'è")
	assert_eq(deer.state, DryDeer.State.SLEEP, "dorme")
	assert_false(deer in zone.enemies(), "non è un nemico qualunque")
	assert_eq(deer.hurt(5, &"magic", Vector2.ZERO), 0, "dormendo non si tocca")


func test_entrando_si_chiudono_le_radici() -> void:
	var zone := await _zone()
	var deer := await _fight(zone)
	assert_true(zone.boss.fighting, "lo scontro è cominciato")
	assert_eq(zone.boss.gates.size(), 3, "le radici richiudono l'entrata")
	assert_true(zone.boss.bar.is_shown(), "la barra della vita")
	assert_true(deer.state != DryDeer.State.SLEEP, "il cervo è sveglio")
	assert_true(zone.state.flag("deer_met"), "si ricorda d'averlo visto")
	var hero: CharacterBody2D = zone.hero
	hero.global_position = Vector2(29.5 * TILE, 9.5 * TILE)
	assert_true(hero.test_move(hero.global_transform, Vector2(0, 3 * TILE)), "non si esce")


func test_la_carica_finisce_contro_la_parete() -> void:
	var zone := await _zone()
	var deer := await _fight(zone)
	var crashed := [false]
	deer.crashed.connect(func(_at: Vector2) -> void: crashed[0] = true)
	deer.charge_dir = Vector2.LEFT
	deer.hurtful = true
	deer._enter(DryDeer.State.CHARGE, DryDeer.CHARGE_MAX)
	for i in 120:
		await tree.physics_frame
		if crashed[0]:
			break
	assert_true(crashed[0], "sbatte")
	assert_true(deer.is_stunned(), "resta stordito, le corna piantate")
	assert_false(deer.hurtful, "stordito non fa male")


func test_la_corteccia_e_lo_stordimento() -> void:
	var zone := await _zone()
	var deer := await _fight(zone)
	deer._enter(DryDeer.State.STALK, 5.0)
	assert_eq(deer.damage_from(4, &"sword"), 2, "fuori: la corteccia ferma metà della spada")
	assert_eq(deer.damage_from(4, &"magic"), 4, "la magia passa")
	deer._enter(DryDeer.State.STUNNED, 5.0)
	assert_eq(deer.damage_from(4, &"sword"), 8, "stordito: il doppio")
	var hp: int = deer.hp
	deer.hurt(4, &"sword", deer.global_position + Vector2(0, 20))
	assert_eq(deer.hp, hp - 8, "e si vede")
	assert_eq(deer.state, DryDeer.State.STUNNED, "un colpo non lo scompone")


func test_a_meta_vita_la_seconda_fase() -> void:
	var zone := await _zone()
	var deer := await _fight(zone)
	deer._enter(DryDeer.State.STUNNED, 5.0)
	deer.hurt(deer.max_hp / 4, &"magic", deer.global_position)     # stordito vale doppio: metà vita
	assert_eq(deer.phase, 2, "la seconda fase")
	assert_eq(deer.state, DryDeer.State.ROAR, "bramisce")
	assert_true(zone.boss.bar.phase2, "la barra si accende")
	await tree.process_frame
	assert_true(zone.boss.bar.ratio <= 0.5, "e scende")


func test_i_rami_fanno_male_dove_cadono() -> void:
	var zone := await _zone()
	var deer := await _fight(zone)
	deer._enter(DryDeer.State.STUNNED, 10.0)           # fermo: i rami e basta
	var hero: CharacterBody2D = zone.hero
	hero.invulnerable = 0.0
	assert_false(hero.frozen, "finita la scena Lethe è libera (anche se la camera scivolava)")
	var heart: int = zone.state.heart
	var branches: Array = zone.boss.drop_branches([hero.global_position, hero.global_position + Vector2(150, 0)])
	assert_eq(branches.size(), 2, "due rami")
	var hits := [0]
	for b in branches:
		b.landed.connect(func(hit: bool) -> void:
			if hit:
				hits[0] += 1)
	await tree.create_timer(FallingBranch.WARN + FallingBranch.FALL + 0.3).timeout
	assert_eq(hits[0], 1, "fa male solo quello che le cade addosso")
	assert_eq(zone.state.heart, heart - 1, "un pezzo di cuore")


func test_la_verita_lo_libera() -> void:
	var zone := await _zone()
	var deer := await _fight(zone)
	var freed := [false, false]
	zone.boss.defeated.connect(func(f: bool) -> void:
		freed[0] = true
		freed[1] = f)
	deer._enter(DryDeer.State.STUNNED, 5.0)
	deer.hurt(999, &"magic", deer.global_position)
	_drive(zone.talk)
	assert_true(await wait_signal(zone.boss.defeated, 10.0) or freed[0], "finisce")
	assert_true(freed[1], "l'ultimo colpo era luce: libero")
	assert_true(zone.state.flag("deer_defeated"), "si ricorda")
	assert_true(zone.state.flag("deer_freed"), "e come")
	assert_true(zone.boss.gates.is_empty(), "le radici si riaprono")
	assert_true(zone.puzzles.treasures.has("leaf"), "dove stava, una foglia")
	assert_eq(zone.objective.text, zone.story.GOAL_LEAF, "l'obiettivo: la foglia all'albero")


func test_la_spada_lo_rompe() -> void:
	var zone := await _zone()
	var deer := await _fight(zone)
	deer._enter(DryDeer.State.STUNNED, 5.0)
	deer.hurt(999, &"sword", deer.global_position)
	_drive(zone.talk)
	await wait_signal(zone.boss.defeated, 10.0)
	assert_true(zone.state.flag("deer_defeated"), "battuto")
	assert_false(zone.state.flag("deer_freed"), "ma rotto, non libero")
	assert_true(zone.puzzles.treasures.has("leaf"), "la foglia c'è lo stesso")


func test_se_lethe_cade_si_ricomincia() -> void:
	var zone := await _zone()
	var deer := await _fight(zone)
	deer._enter(DryDeer.State.STUNNED, 5.0)
	deer.hurt(6, &"magic", deer.global_position)
	zone.combat.died.emit()
	zone.combat.respawned.emit()
	assert_false(zone.boss.fighting, "lo scontro si chiude")
	assert_eq(deer.state, DryDeer.State.SLEEP, "il cervo torna a dormire")
	assert_eq(deer.hp, deer.max_hp, "intero")
	assert_eq(deer.global_position, deer.home, "dove stava")
	assert_true(deer.is_physics_processing(), "e si muove di nuovo")
	await tree.create_timer(0.7).timeout
	assert_true(zone.boss.gates.is_empty(), "le radici si riaprono")


func test_battuto_resta_battuto() -> void:
	var zone := await _zone({"deer_defeated": true, "deer_freed": true})
	assert_true(zone.boss.deer == null, "il cervo non c'è più")
	assert_true(zone.puzzles.treasures.has("leaf"), "la foglia aspetta")
	assert_eq(zone.story.roots_goal(), zone.story.GOAL_LEAF, "l'obiettivo è la foglia")
	zone.talk.talk("leaf")
	await _drive(zone.talk)
	assert_true(zone.state.flag("item_leaf"), "presa")
	var again := await _zone({"deer_defeated": true, "item_leaf": true})
	assert_false(again.puzzles.treasures.has("leaf"), "presa resta presa")
