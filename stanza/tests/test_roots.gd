extends "res://tests/base_test.gd"
## Il dungeon delle radici (passo 2): le stanze scavate nella terra e collegate dalle porte,
## la camera che resta sulla stanza e scivola, il nome della stanza la prima volta, la
## cornice d'argento dove ci si riposa, la discesa dal buco e la risalita.

const ZONE := "res://forest/zone_roots.tscn"
const Main := preload("res://main.gd")
const Layout := preload("res://forest/zone_roots_layout.gd")
const ZoneLayout := preload("res://forest/zone_layout.gd")
const ForestTileset := preload("res://world/forest/forest_tileset.gd")
const TILE := 32


func after() -> void:
	tree.paused = false
	Main.pending_save = {}
	await super()


func _zone(flags := {}) -> Node2D:
	var all := {"forest_arrived": true, "talk_learned": true, "selene_met": true, "roots_arrived": true,
		"first_enemy_seen": true, "slash_learned": true}
	all.merge(flags, true)
	Main.pending_save = {"zone": "roots", "entry": "top", "flags": all}
	var zone := add_scene(ZONE, func(n): n.sound = false)
	await tree.process_frame
	return zone


func _room_center(id: String) -> Vector2:
	for room in Layout.ROOMS:
		if room[0] == id:
			var r: Rect2i = room[2]
			return (Vector2(r.position) + Vector2(r.size) / 2.0) * TILE
	return Vector2.ZERO


func test_le_stanze_sono_collegate() -> void:
	# Dal punto d'arrivo si arriva a piedi (sul terreno) al centro di tutte le stanze.
	var v := ZoneLayout.vertices(Layout)
	var seen := {Layout.SPAWN: true}
	var queue: Array[Vector2i] = [Layout.SPAWN]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= Layout.SIZE.x or n.y >= Layout.SIZE.y:
				continue
			if ZoneLayout.cell_terrain(v, n)[0] == "":
				seen[n] = true
				queue.append(n)
	for room in Layout.ROOMS:
		var r: Rect2i = room[2]
		var center := Vector2i(r.position.x + r.size.x / 2, r.position.y + 6)
		assert_true(seen.has(center), "si arriva a %s" % room[0])
	assert_false(seen.has(Vector2i(5, 5)), "fuori dalle stanze è tutta terra")


func test_la_terra_e_il_pavimento() -> void:
	var data := ForestTileset.load_data()
	assert_eq(ForestTileset.tile_for(data, "earth", [0, 0, 1, 1]), "earth_n", "la terra ha i suoi bordi")
	assert_eq(String(data["tiles"]["earth_n"]["base"]), "roots", "sopra il pavimento di radici")
	assert_true(data["tiles"]["earth_c"]["solid"], "la terra blocca")
	var tile_set: TileSet = load("res://world/forest/forest_tileset.tres")
	assert_eq(tile_set.get_terrains_count(ForestTileset.TERRAIN_SET), ForestTileset.TERRAINS.size(),
		"terra e radici nell'autotile dell'editor")


func test_la_camera_resta_sulla_stanza() -> void:
	var zone := await _zone()
	var rooms: Node = zone.rooms
	assert_true(rooms != null, "il dungeon ha la camera per stanze")
	assert_eq(rooms.current, "entrance", "si parte sotto l'albero")
	var r: Rect2 = rooms.rect_of(rooms.room_named("entrance"))
	assert_eq(zone.camera.limit_left, int(r.position.x), "i limiti sono quelli della stanza")
	assert_eq(zone.camera.limit_top, int(r.position.y), "anche in alto")


func test_passando_una_porta_la_camera_scivola() -> void:
	var zone := await _zone()
	var rooms: Node = zone.rooms
	var got := {"id": ""}
	rooms.room_changed.connect(func(id, _n): got["id"] = id)
	zone.hero.global_position = _room_center("heart") + Vector2(0, 40)
	await tree.process_frame
	await tree.process_frame
	assert_eq(got["id"], "heart", "nel cuore delle radici")
	assert_true(rooms.sliding, "la camera scivola")
	assert_true(zone.hero.frozen, "Lethe ferma un attimo")
	await wait_seconds(0.7)
	assert_false(rooms.sliding, "poi finisce")
	assert_false(zone.hero.frozen, "e si gioca")
	var r: Rect2 = rooms.rect_of(rooms.room_named("heart"))
	assert_eq(zone.camera.limit_top, int(r.position.y), "la camera è sulla stanza nuova")
	assert_true(zone.state.flag("room_heart"), "la prima volta il nome della stanza")


func test_la_cornice_d_argento() -> void:
	var zone := await _zone()
	zone.state.heart = 1
	zone.rest()
	assert_eq(zone.state.heart, zone.state.heart_max, "ci si riposa")
	var frames: Array = zone.thing_nodes().filter(func(s): return s.get_meta(&"tile") == "silver_frame")
	var frame: Sprite2D = frames[0]
	assert_true(zone.respawn_point.distance_to(frame.global_position + Vector2(0, 20)) < 1.0,
		"e ci si risveglia davanti alla cornice")


func test_il_cancello_e_il_cuore() -> void:
	var zone := await _zone()
	var ids: Array = zone.talk.things.map(func(t): return t["id"])
	for id in ["silver_frame", "root_heart", "root_gate", "watering_can", "old_stone"]:
		assert_true(id in ids, "si parla con %s" % id)
	var hero: CharacterBody2D = zone.hero
	hero.global_position = Vector2(29.5 * TILE, 13.6 * TILE)
	assert_true(hero.test_move(hero.global_transform, Vector2(0, -3 * TILE)), "il cancello di radici chiude l'arena")
	assert_eq(zone.story.roots_goal(), zone.story.GOAL_HEART, "prima: trova il cuore")
	zone.story.saw_heart()
	assert_eq(zone.objective.text, zone.story.GOAL_THORNS, "visto il cuore: apri il passaggio delle spine")


func test_la_prima_volta_sottoterra() -> void:
	Engine.time_scale = 6.0
	var zone := await _zone({"roots_arrived": false})
	assert_true(zone.state.flag("roots_arrived") == false, "non ancora arrivata")
	for i in 600:
		await tree.process_frame
		var box = zone.talk.box
		if is_instance_valid(box):
			box.sound = false
			if box.waiting or box.text_label.is_typing:
				box.advance()
		elif zone.state.flag("roots_arrived"):
			break
	assert_true(zone.state.flag("roots_arrived"), "arrivata, dopo il racconto")
	assert_eq(zone.objective.text, zone.story.GOAL_HEART, "l'obiettivo")


func test_si_scende_e_si_risale() -> void:
	var data_tree := preload("res://forest/zone_tree_layout.gd")
	assert_true(data_tree.ENTRIES.has("hole"), "risalendo si arriva accanto al buco")
	var exits: Array = Layout.EXITS
	assert_eq(exits[0][1], "tree", "dalle radici si risale alla radura")
	var zone := await _zone()
	assert_eq(zone.state.zone, "roots", "il salvataggio ricorda il dungeon")
	assert_eq(preload("res://forest/zones.gd").scene("roots"), ZONE, "la zona ha la sua scena")
