extends "res://tests/base_test.gd"
## La luce di Lethe (gli MP): la magia la spende, torna da sola, in fretta vicino alle luci,
## tutta riposando, un po' a ogni verità; senza, la magia sfuma. E l'atmosfera sottoterra:
## il fuoco animato delle lanterne, gli occhi che restano nella parete, la siepe di rovi che
## blocca, la polvere e le gocce.

const ROOTS := "res://forest/zone_roots.tscn"
const Main := preload("res://main.gd")
const GameState := preload("res://menu/game_state.gd")
const LightCatch := preload("res://magic/light_catch.gd")
const Fire := preload("res://fx/fire.gd")
const TILE := 32
const WITH_LIGHT := {"truth": 3, "lies": 0, "learned": ["truth_spark"], "spell": "truth_spark"}


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _zone(flags := {}, extra := WITH_LIGHT) -> Node2D:
	var all := {"forest_arrived": true, "talk_learned": true, "selene_met": true, "roots_arrived": true,
		"first_enemy_seen": true, "slash_learned": true, "room_entrance": true, "room_lanterns": true,
		"room_heart": true, "room_thorns": true}
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


# --- Lo stato -----------------------------------------------------------------------------------

func test_la_luce_si_spende_e_torna() -> void:
	var s := GameState.new()
	assert_eq(s.mp, s.mp_max, "all'inizio piena")
	assert_eq(GameState.spell_cost("truth_spark"), 1, "la scintilla costa una luna")
	assert_eq(GameState.spell_cost("vigil"), 3, "la veglia tre")
	assert_true(s.spend_mp("vigil"), "si spende")
	assert_eq(s.mp, s.mp_max - 3, "tolta")
	s.mp = 2
	assert_false(s.spend_mp("vigil"), "non basta")
	assert_eq(s.mp, 2, "e non si tocca")
	assert_eq(s.gain_mp(10), s.mp_max - 2, "torna fino al massimo, non oltre")


func test_la_luce_si_salva() -> void:
	var s := GameState.new()
	s.mp = 2
	var again := GameState.new()
	again.load_save(s.to_save(Vector2.ZERO, 0))
	assert_eq(again.mp, 2, "si ricorda")
	again.load_save({"mp": 99})
	assert_eq(again.mp, again.mp_max, "un valore storto si aggiusta")


# --- In gioco ---------------------------------------------------------------------------------------

func test_le_lune_si_vedono_solo_con_la_magia() -> void:
	var zone := await _zone()
	assert_true(zone.hud.light_row.visible, "con la scintilla: le lune sopra i cuori")
	assert_eq(zone.hud.light_row.moons.size(), zone.state.mp_max, "una per luna")
	var dark := await _zone({}, {"truth": 0, "lies": 6})
	assert_false(dark.hud.light_row.visible, "senza magia niente lune")


func test_la_magia_spende_e_senza_luce_sfuma() -> void:
	var zone := await _zone()
	var hero: CharacterBody2D = zone.hero
	hero.cast()
	assert_eq(zone.state.mp, zone.state.mp_max - 1, "la scintilla spende una luna")
	assert_eq(zone.hud.light_row.light, zone.state.mp, "e le lune lo mostrano")
	await wait_signal(hero.attack_finished, 2.0)
	zone.state.mp = 0
	var fizzled := [false]
	hero.fizzled.connect(func() -> void: fizzled[0] = true)
	hero.cast()
	assert_true(fizzled[0], "senza luce sfuma")
	assert_false(hero.is_attacking(), "e niente parte")


func test_vicino_a_una_luce_torna_in_fretta() -> void:
	var zone := await _zone({"lantern_west": true})
	var lantern: Sprite2D = zone.lanterns.lanterns["west"]
	assert_true(lantern.is_in_group(&"light_sources"), "la lanterna accesa è una luce")
	zone.state.mp = 0
	zone.hero.global_position = lantern.global_position + Vector2(0, 30)
	await tree.create_timer(1.3).timeout
	assert_true(zone.state.mp >= 2, "vicino alla lanterna: più lune in poco tempo")


func test_da_sola_torna_piano() -> void:
	var zone := await _zone()
	zone.state.mp = 0
	zone.hero.global_position = Vector2(50.5 * TILE, 31.5 * TILE)   # le cose sepolte: nessuna luce vicina
	assert_eq(zone.light.nearest_source(), Vector2.INF, "lontano dalle luci")
	await tree.create_timer(1.3).timeout
	assert_eq(zone.state.mp, 0, "in poco tempo, niente")
	zone.light._passive = zone.light.PASSIVE_EVERY - 0.01
	await tree.create_timer(0.1).timeout
	assert_eq(zone.state.mp, 1, "col tempo, una luna")


func test_riposando_torna_tutta() -> void:
	var zone := await _zone()
	zone.state.mp = 1
	zone.rest()
	assert_eq(zone.state.mp, zone.state.mp_max, "allo specchio, tutta")


func test_una_verita_ridà_luce() -> void:
	var zone := await _zone()
	zone.state.mp = 0
	zone.talk.talk_started.emit("prova")
	zone.state.truth += 1
	zone.talk.talk_finished.emit("prova")
	assert_eq(zone.state.mp, zone.light.TRUTH_GIFT, "detta la verità, la luce torna")
	zone.talk.talk_started.emit("prova")
	zone.state.lies += 1
	zone.talk.talk_finished.emit("prova")
	assert_eq(zone.state.mp, zone.light.TRUTH_GIFT, "una bugia no")


# --- L'atmosfera ---------------------------------------------------------------------------------------

func test_il_fuoco_della_lanterna_e_vivo() -> void:
	var zone := await _zone()
	LightCatch.touch(tree, (zone.lanterns.lanterns["west"].get_meta(&"catcher") as Node2D).global_position)
	var fire: Node2D = zone.lanterns.lanterns["west"].get_node("Fire")
	assert_true(fire != null, "accesa: c'è il fuoco")
	var seen := {}
	for i in 40:
		await tree.create_timer(0.05).timeout
		seen[fire.frame()] = true
	assert_true(seen.size() >= 3, "e si muove: più fotogrammi")


func test_gli_occhi_restano_nella_parete() -> void:
	var zone := await _zone()
	for eye in tree.get_nodes_in_group(&"root_eyes"):
		if not zone.is_ancestor_of(eye):
			continue
		assert_eq(eye.get_parent(), zone.decor, "sotto Lethe, con le piante basse")
		assert_eq(eye.z_index, 0, "niente z_index che lo porti sopra di lei")
		var cell := Vector2i((eye.position / TILE).floor())
		assert_true(zone.ground.get_cell_tile_data(cell) != null, "sta su una cella")
		var hero: CharacterBody2D = zone.hero
		hero.global_position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
		assert_true(hero.test_move(hero.global_transform, Vector2.ZERO) or _solid(zone, cell),
			"dove c'è un occhio non si cammina (%s)" % cell)


func _solid(zone: Node2D, cell: Vector2i) -> bool:
	var data: TileData = zone.ground.get_cell_tile_data(cell)
	return data != null and data.get_collision_polygons_count(0) > 0


func test_la_siepe_di_rovi_blocca() -> void:
	var zone := await _zone()
	var data: TileData = zone.decor.get_cell_tile_data(Vector2i(3, 27))
	assert_true(data != null and data.get_collision_polygons_count(0) > 0, "i rovi hanno un corpo")
	var hero: CharacterBody2D = zone.hero
	hero.global_position = Vector2(3.5 * TILE, 29.5 * TILE)
	assert_true(hero.test_move(hero.global_transform, Vector2(0, -2 * TILE)), "non ci si passa sopra")


func test_sottoterra_c_e_l_aria() -> void:
	var zone := await _zone()
	var ambience: Node = zone.get_node("Ambience")
	assert_true(ambience.dust.emitting, "la polvere nell'aria")
	var drop: Node2D = ambience.drip(zone.hero.global_position + Vector2(40, 0))
	assert_true(is_instance_valid(drop), "una goccia")
	await tree.create_timer(1.2).timeout
	assert_false(is_instance_valid(drop), "cade, fa l'anello e sparisce")
