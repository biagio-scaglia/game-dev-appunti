extends "res://tests/base_test.gd"
## Il TileSet costruito dal JSON del generatore.

const Tiles := preload("res://world/room_tileset.gd")


func test_il_json_ha_tutti_i_tile_della_stanza() -> void:
	var data := Tiles.load_data()
	assert_eq(int(data["tile"]), 32, "celle da 32")
	for tile_name in ["floor", "wall", "window", "door", "bed", "desk_pc", "chair", "shelf", "rug"]:
		assert_true(data["tiles"].has(tile_name), "manca %s" % tile_name)


func test_ogni_cella_sta_dentro_l_atlante() -> void:
	var data := Tiles.load_data()
	var cells: Vector2i = Vector2i(Tiles.ATLAS.get_size()) / int(data["tile"])
	for tile: Dictionary in data["tiles"].values():
		for cell in Tiles.cells_of(tile):
			assert_true(cell.x < cells.x and cell.y < cells.y, "cella fuori dall'atlante: %s" % cell)


func test_collisioni_solo_sui_tile_solidi() -> void:
	var data := Tiles.load_data()
	var source: TileSetAtlasSource = Tiles.build(data).get_source(Tiles.SOURCE_ID)
	for tile_name: String in data["tiles"]:
		var tile: Dictionary = data["tiles"][tile_name]
		for cell in Tiles.cells_of(tile):
			var polygons := source.get_tile_data(cell, 0).get_collision_polygons_count(0)
			assert_eq(polygons > 0, bool(tile["solid"]), "%s, cella %s" % [tile_name, cell])


func test_i_mobili_occupano_piu_celle() -> void:
	var data := Tiles.load_data()
	assert_eq(Tiles.cells_of(data["tiles"]["bed"]).size(), 6, "letto 2x3")
	assert_eq(Tiles.cells_of(data["tiles"]["desk_pc"]).size(), 6, "scrivania 3x2")
