extends "res://tests/base_test.gd"
## I tile della foresta: il JSON torna con l'atlante, i pezzi per fare una mappa ci sono,
## e gli alberi bloccano solo al tronco.

const ForestTileset := preload("res://world/forest/forest_tileset.gd")
const RoomTileset := preload("res://world/room_tileset.gd")


func test_ogni_tile_sta_nell_atlante() -> void:
	var data := ForestTileset.load_data()
	var cols := ForestTileset.ATLAS.get_width() / int(data["tile"])
	var rows := ForestTileset.ATLAS.get_height() / int(data["tile"])
	var used := {}
	for tile_name in data["tiles"]:
		for cell in RoomTileset.cells_of(data["tiles"][tile_name]):
			assert_true(cell.x < cols and cell.y < rows, "%s dentro l'atlante" % tile_name)
			assert_false(used.has(cell), "%s non si sovrappone a %s" % [tile_name, used.get(cell, "")])
			used[cell] = tile_name


func test_ci_sono_i_pezzi_per_una_mappa() -> void:
	var tiles: Dictionary = ForestTileset.load_data()["tiles"]
	for t in ["grass", "grass_b", "grass_c", "grass_d", "thicket_b", "thicket_c", "thicket_edge",
			"tree", "pine", "dead_tree", "mirror", "mushrooms", "bridge_h", "bridge_v", "bridge_h_w",
			"bridge_h_e", "bridge_v_n", "bridge_v_s", "brambles", "brambles_open", "root_floor",
			"root_wall", "root_hole", "glow_root", "old_stone"]:
		assert_true(tiles.has(t), "c'è %s" % t)
	for kind in ["path", "lethe", "canopy"]:
		for part in ["nw", "n", "ne", "w", "c", "e", "sw", "s", "se", "inw", "ine", "isw", "ise", "d1", "d2"]:
			assert_true(tiles.has("%s_%s" % [kind, part]), "c'è %s_%s" % [kind, part])
	assert_true(tiles["lethe_c"]["solid"], "nel Lete non si cammina")
	assert_false(tiles["path_c"]["solid"], "sul sentiero sì")
	assert_true(tiles["canopy_c"]["solid"], "il bosco fitto è un muro")
	assert_false(tiles["bridge_h"]["solid"], "sul ponte si passa")
	assert_true(tiles["brambles"]["solid"] and tiles["brambles"]["gesture"] == "open", "i rovi si aprono")
	assert_true(tiles["mushrooms"].has("light"), "i funghi fanno luce")


func test_gli_alberi_bloccano_solo_al_tronco() -> void:
	var data := ForestTileset.load_data()
	var tree: Dictionary = data["tiles"]["tree"]
	assert_false(RoomTileset.is_solid_cell(tree, Vector2i(0, 0)), "sotto la chioma si passa")
	assert_true(RoomTileset.is_solid_cell(tree, Vector2i(1, 2)), "il tronco blocca")
	assert_true(RoomTileset.is_solid_cell(data["tiles"]["rock"], Vector2i.ZERO), "senza solid_cells: tutto")
	var tile_set := ForestTileset.build(data)
	var source := tile_set.get_source(RoomTileset.SOURCE_ID) as TileSetAtlasSource
	var origin := Vector2i(int(tree["atlas"][0]), int(tree["atlas"][1]))
	assert_eq(source.get_tile_data(origin, 0).get_collision_polygons_count(0), 0, "chioma senza collisione")
	assert_eq(source.get_tile_data(origin + Vector2i(0, 2), 0).get_collision_polygons_count(0), 1,
		"tronco con collisione")


func test_i_bordi_bloccano_solo_dove_c_e_acqua() -> void:
	var data := ForestTileset.load_data()
	var tile_set := ForestTileset.build(data)
	var source := tile_set.get_source(RoomTileset.SOURCE_ID) as TileSetAtlasSource
	var edge: Dictionary = data["tiles"]["lethe_n"]          # acqua solo in basso
	var cell := Vector2i(int(edge["atlas"][0]), int(edge["atlas"][1]))
	var tile_data := source.get_tile_data(cell, 0)
	assert_eq(tile_data.get_collision_polygons_count(0), 2, "due quarti: gli angoli in basso")
	for i in 2:
		for p in tile_data.get_collision_polygon_points(0, i):
			assert_true(p.y >= 0.0, "solo nella metà bassa")


func test_l_autotile_sceglie_il_pezzo_giusto() -> void:
	var data := ForestTileset.load_data()
	var tile_set := ForestTileset.build(data)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	tree.root.add_child(layer)
	_owned.append(layer)
	var grass: Array[Vector2i] = []
	for y in 7:
		for x in 7:
			grass.append(Vector2i(x, y))
	layer.set_cells_terrain_connect(grass, ForestTileset.TERRAIN_SET, 0)
	var path: Array[Vector2i] = []
	for y in range(2, 5):
		for x in range(2, 5):
			path.append(Vector2i(x, y))
	layer.set_cells_terrain_connect(path, ForestTileset.TERRAIN_SET, 1)
	var center: Dictionary = data["tiles"]["path_c"]
	assert_eq(layer.get_cell_atlas_coords(Vector2i(3, 3)), Vector2i(int(center["atlas"][0]), int(center["atlas"][1])),
		"in mezzo: sentiero pieno")
	# Il bordo sta dentro la zona dipinta: l'angolo in alto a sinistra è un angolo esterno.
	var corner := layer.get_cell_tile_data(Vector2i(2, 2))
	assert_eq(corner.terrain, 1, "l'angolo della zona è sentiero")
	assert_eq(corner.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER), 0, "verso fuori: erba")
	assert_eq(corner.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER), 1, "verso dentro: sentiero")
	var side := layer.get_cell_tile_data(Vector2i(3, 2))
	assert_eq(side.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER), 0, "il lato in alto: erba sopra")
	assert_eq(side.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER), 1, "sentiero sotto")


func test_il_tileset_per_l_editor_c_e() -> void:
	var tile_set: TileSet = load("res://world/forest/forest_tileset.tres")
	assert_eq(tile_set.get_terrain_sets_count(), 1, "con l'autotile")
	assert_eq(tile_set.get_terrains_count(ForestTileset.TERRAIN_SET), ForestTileset.TERRAINS.size(), "quattro terreni")
	assert_eq(ForestTileset.tile_for(ForestTileset.load_data(), "lethe", [0, 0, 1, 1]), "lethe_n", "dai vertici al nome")


func test_la_musica_del_bosco() -> void:
	var theme: AudioStreamWAV = load("res://audio/forest_theme.wav")
	assert_true(theme != null, "c'è")
	assert_near(theme.get_length(), 48.0, 0.1, "16 battute a 80 bpm")
