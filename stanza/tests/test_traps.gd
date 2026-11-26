extends "res://tests/base_test.gd"
## Il dungeon delle radici, passo 5: le spine di radice a tempo, la terra che crolla, il masso
## da spingere (la prima volta da sola non si muove: insieme a Selene sì), il masso che
## sprofonda e fa da ponte, la Moon Pearl dall'altra parte. Si ricordano, e si risolvono anche
## con sole bugie.

const ROOTS := "res://forest/zone_roots.tscn"
const Main := preload("res://main.gd")
const Traps := preload("res://forest/zone_traps.gd")
const TILE := 32
const NO_LIGHT := {"truth": 0, "lies": 6}


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _zone(flags := {}, extra := {}) -> Node2D:
	var all := {"forest_arrived": true, "talk_learned": true, "selene_met": true, "roots_arrived": true,
		"first_enemy_seen": true, "slash_learned": true, "room_entrance": true, "room_boulder": true,
		"room_thorns": true, "room_heart": true}
	all.merge(flags, true)
	var data := {"zone": "roots", "entry": "top", "flags": all}
	data.merge(extra, true)
	Main.pending_save = data
	var zone := add_scene(ROOTS, func(n): n.sound = false)
	await tree.process_frame
	for enemy in zone.enemies():
		enemy.queue_free()
	await tree.process_frame
	return zone


func _drive(talk: Node, pick := 0) -> void:
	for i in 400:
		await tree.process_frame
		var box = talk.box
		if not is_instance_valid(box):
			break
		box.sound = false
		if box.choices_panel.visible:
			box.choose(pick)
		elif box.waiting or box.text_label.is_typing:
			box.advance()
	await tree.physics_frame
	await tree.physics_frame


func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


# --- Le spine ---------------------------------------------------------------------------------

## Porta il giro delle spine dove la spina in `cell` è nello stadio `stage`.
func _set_stage(zone: Node2D, cell: Vector2i, stage: String) -> void:
	var phase: float = zone.traps.spikes[cell]["phase"]
	var at: float = {"down": 0.2, "warn": Traps.WARN_AT + 0.1, "up": Traps.UP_AT + 0.1}[stage]
	zone.traps._time = fposmod(at - phase, Traps.PERIOD)


func test_le_spine_fanno_il_giro() -> void:
	var zone := await _zone()
	var cell := Vector2i(6, 30)
	assert_true(zone.traps.spikes.has(cell), "ci sono le spine")
	for stage in ["down", "warn", "up"]:
		_set_stage(zone, cell, stage)
		assert_eq(zone.traps.spike_stage(cell), stage, "lo stadio %s" % stage)
	var phases: Array = zone.traps.spikes.values().map(func(s): return s["phase"])
	assert_true(phases[0] != phases[-1], "ognuna col suo ritardo: un'onda")


func test_fuori_fanno_male_dentro_no() -> void:
	var zone := await _zone()
	var cell := Vector2i(6, 30)
	var heart: int = zone.state.heart
	zone.hero.global_position = _center(cell)
	_set_stage(zone, cell, "down")
	zone.traps._physics_process(0.0)
	assert_eq(zone.state.heart, heart, "giù: si passa")
	_set_stage(zone, cell, "warn")
	zone.traps._physics_process(0.0)
	assert_eq(zone.state.heart, heart, "tremano: ancora si passa (si vedono arrivare)")
	_set_stage(zone, cell, "up")
	zone.traps._physics_process(0.0)
	assert_eq(zone.state.heart, heart - 1, "fuori: fanno male")
	assert_eq(zone.traps.spikes[cell]["sprite"].get_meta(&"tile"), "root_spikes_up", "e si vedono")


# --- La terra che crolla ------------------------------------------------------------------------

func test_la_terra_crolla_e_si_cade() -> void:
	var zone := await _zone()
	var cell := Vector2i(55, 20)
	var heart: int = zone.state.heart
	var safe := _center(Vector2i(53, 20))
	zone.hero.global_position = safe
	await tree.create_timer(1.5).timeout          # si entra nella stanza: la camera scivola, il passo dentro
	zone.hero.global_position = safe
	for i in 3:
		await tree.physics_frame
	zone.hero.global_position = _center(cell)
	await wait_signal(zone.traps.fell, 3.0)
	assert_true(zone.traps.is_pit(cell), "è crollata")
	assert_eq(zone.state.heart, heart - 1, "la caduta fa male")
	assert_true(zone.hero.global_position.distance_to(safe) < 8.0, "e si torna dov'era prima")
	var hero: CharacterBody2D = zone.hero
	assert_true(hero.test_move(hero.global_transform, Vector2(2 * TILE, 0)), "il buco non si attraversa")


func test_correndo_non_si_attraversa() -> void:
	var zone := await _zone()
	var hero: CharacterBody2D = zone.hero
	var start := Vector2(52.5 * TILE, 20.5 * TILE)   # lontano: il passo d'entrata non la tocca
	hero.global_position = start
	await tree.create_timer(1.5).timeout          # la camera finisce di scivolare
	hero.global_position = start
	await tree.physics_frame
	var heart: int = zone.state.heart
	Input.action_press(&"move_right")
	Input.action_press(&"run")
	var fell := await wait_signal(zone.traps.fell, 3.0)
	Input.action_release(&"move_right")
	Input.action_release(&"run")
	assert_true(fell, "correndo sulla striscia si cade lo stesso")
	assert_eq(zone.state.heart, heart - 1, "un pezzo di cuore")
	assert_true(hero.global_position.x < 55 * TILE, "e si resta di qua")
	for c in [Vector2i(55, 15), Vector2i(56, 22)]:
		assert_true(zone.traps.is_pit(c), "è crollata tutta la striscia (%s)" % c)


func test_il_buco_resta() -> void:
	var zone := await _zone({"crumble_55_20": "pit"})
	assert_true(zone.traps.is_pit(Vector2i(55, 20)), "dopo un salvataggio il buco c'è ancora")
	assert_eq(zone.traps.crumbles[Vector2i(55, 20)].get_meta(&"tile"), "pit", "e si vede")


# --- Il masso -----------------------------------------------------------------------------------

func test_da_sola_non_si_muove() -> void:
	var zone := await _zone()
	assert_false(zone.boulders.push("stone", Vector2i.RIGHT), "da sola no")
	assert_eq(zone.boulders.cell_of("stone"), Vector2i(51, 17), "è ancora lì")
	await _drive(zone.talk)
	assert_true(zone.boulders.together(), "Selene: insieme")


func test_insieme_si_spinge_e_sprofonda() -> void:
	var zone := await _zone({"boulder_together": true})
	assert_true(zone.boulders.push("stone", Vector2i.RIGHT), "si muove")
	await wait_signal(zone.boulders.pushed, 2.0)
	assert_eq(zone.boulders.cell_of("stone"), Vector2i(53, 17), "di due celle")
	assert_true(zone.boulders.push("stone", Vector2i.RIGHT), "ancora")
	assert_true(await wait_signal(zone.boulders.sunk, 3.0), "sulla terra che crolla sprofonda")
	assert_true(zone.state.flag("boulder_stone_sunk"), "si ricorda")
	for c in [Vector2i(55, 17), Vector2i(56, 17), Vector2i(55, 18), Vector2i(56, 18)]:
		assert_eq(String(zone.state.flags.get("crumble_%d_%d" % [c.x, c.y], "")), "filled", "ponte: %s" % c)
	await tree.physics_frame
	var hero: CharacterBody2D = zone.hero
	hero.global_position = _center(Vector2i(54, 17))
	assert_false(hero.test_move(hero.global_transform, Vector2(3 * TILE, 0)), "si passa sopra")


func test_contro_il_muro_non_va() -> void:
	var zone := await _zone({"boulder_together": true})
	assert_true(zone.boulders.push("stone", Vector2i.UP), "su, una volta")
	await wait_signal(zone.boulders.pushed, 2.0)
	assert_false(zone.boulders.push("stone", Vector2i.UP), "ancora su: c'è la parete")
	assert_eq(zone.boulders.cell_of("stone"), Vector2i(51, 15), "fermo")


func test_si_spinge_camminandoci_contro() -> void:
	var zone := await _zone({"boulder_together": true})
	var hero: CharacterBody2D = zone.hero
	hero.global_position = Vector2(50.4 * TILE, 18.5 * TILE)
	Input.action_press(&"move_right")
	var moved := await wait_signal(zone.boulders.pushed, 3.0)
	Input.action_release(&"move_right")
	assert_true(moved, "tenendo la direzione contro il masso")
	assert_eq(zone.boulders.cell_of("stone"), Vector2i(53, 17), "a destra")


func test_il_masso_si_ricorda() -> void:
	var zone := await _zone({"boulder_together": true, "boulder_stone": [53, 17]})
	assert_eq(zone.boulders.cell_of("stone"), Vector2i(53, 17), "dove l'aveva lasciato")
	var sunk := await _zone({"boulder_stone": [55, 17], "boulder_stone_sunk": true})
	assert_false(sunk.boulders.boulders.has("stone"), "sprofondato: non c'è più")
	assert_false(sunk.traps.is_crumble(Vector2i(55, 17)), "e il ponte resta")


# --- La perla -------------------------------------------------------------------------------------

func test_la_perla_allunga_la_luce() -> void:
	var zone := await _zone({}, {"learned": ["truth_spark"], "spell": "truth_spark", "truth": 2})
	var before: int = zone.state.mp_max
	var ids: Array = zone.talk.things.map(func(t): return t["id"])
	assert_true("moon_pearl" in ids, "luccica, ci si parla")
	zone.talk.talk("moon_pearl")
	await _drive(zone.talk)
	assert_eq(zone.state.mp_max, before + 1, "una luna in più")
	assert_eq(zone.state.mp, zone.state.mp_max, "e tutte piene")
	assert_eq(zone.hud.light_row.moons.size(), before + 1, "si vede")
	assert_true(zone.state.flag("item_moon_pearl"), "si ricorda")


func test_anche_con_sole_bugie() -> void:
	var zone := await _zone({}, NO_LIGHT)
	zone.boulders.push("stone", Vector2i.RIGHT)
	await _drive(zone.talk)
	assert_true(zone.boulders.push("stone", Vector2i.RIGHT), "il masso si spinge anche mentendo")
	await wait_signal(zone.boulders.pushed, 2.0)
	zone.boulders.push("stone", Vector2i.RIGHT)
	assert_true(await wait_signal(zone.boulders.sunk, 3.0), "e fa da ponte")
