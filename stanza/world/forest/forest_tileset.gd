extends RefCounted
## Il TileSet della foresta (capitolo 1): forest_tiles.png e forest_tiles.json, dal
## generatore in locale (stesso formato della stanza, costruito da room_tileset.gd), più
## l'autotile.
##
## Autotile "a angoli" (terrain set 0, MATCH_CORNERS): erba, sentiero, Lete, bosco fitto.
## Ogni tile di bordo dice nel JSON quali dei suoi 4 angoli sono materiale ("corners");
## nell'editor si dipinge col terreno e Godot sceglie il pezzo giusto, angoli interni e
## diagonali compresi. L'erba e il bosco fitto hanno più varianti (con "probability").
##
## Il resto: alberi e abeti (2x3, bloccano solo al tronco), l'albero secco (3x4), ponti sul
## Lete (con i pezzi sulle rive), rovi che chiudono i passaggi (si aprono col gesto Aprire),
## cespugli, rocce, ceppi, tronchi, felci, erba alta, fiori e funghi che fanno luce, lo
## specchio dove si salva, e il dungeon tra le radici (pavimento, muro, buco, radici che
## fanno luce, pietre antiche).
##
## Per dipingere le mappe nell'editor c'è forest_tileset.tres, scritto da
## tools/make_forest_tileset.gd (rilanciarlo quando cambia l'atlante).

const RoomTileset := preload("res://world/room_tileset.gd")
const ATLAS := preload("forest_tiles.png")
const DATA_PATH := "res://world/forest/forest_tiles.json"
const TERRAIN_SET := 0
## I terreni, nell'ordine del terrain set.
## "earth" e "roots" sono del sottosuolo: la terra sta sul pavimento di radici ("base").
const TERRAINS := ["grass", "path", "lethe", "canopy", "earth", "roots"]
const TERRAIN_COLORS := [Color(0.3, 0.55, 0.4), Color(0.6, 0.45, 0.35), Color(0.3, 0.45, 0.85),
	Color(0.1, 0.3, 0.25),
	Color(0.25, 0.18, 0.22), Color(0.4, 0.3, 0.32)]
## I 4 angoli, nell'ordine di "corners": alto-sx, alto-dx, basso-sx, basso-dx.
const CORNER_BITS := [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]


static func load_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


static func build(data: Dictionary) -> TileSet:
	var tile_set := RoomTileset.build(data, ATLAS)
	tile_set.add_terrain_set(TERRAIN_SET)
	tile_set.set_terrain_set_mode(TERRAIN_SET, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for i in TERRAINS.size():
		tile_set.add_terrain(TERRAIN_SET, i)
		tile_set.set_terrain_name(TERRAIN_SET, i, TERRAINS[i])
		tile_set.set_terrain_color(TERRAIN_SET, i, TERRAIN_COLORS[i])
	var source := tile_set.get_source(RoomTileset.SOURCE_ID) as TileSetAtlasSource
	for tile: Dictionary in data["tiles"].values():
		if not tile.has("terrain"):
			continue
		var cell := Vector2i(int(tile["atlas"][0]), int(tile["atlas"][1]))
		var tile_data := source.get_tile_data(cell, 0)
		var material: int = TERRAINS.find(tile["terrain"])
		tile_data.terrain_set = TERRAIN_SET
		tile_data.terrain = material
		for i in 4:
			var base: int = TERRAINS.find(tile.get("base", "grass"))
			tile_data.set_terrain_peering_bit(CORNER_BITS[i], material if int(tile["corners"][i]) else base)
		tile_data.probability = float(tile.get("probability", 1.0))
	return tile_set


## Il nome del tile dai 4 angoli (per i test e per costruire mappe da codice).
static func tile_for(data: Dictionary, terrain: String, corners: Array) -> String:
	for tile_name in data["tiles"]:
		var tile: Dictionary = data["tiles"][tile_name]
		var tile_corners: Array = tile.get("corners", []).map(func(v): return int(v))
		if tile.get("terrain", "") == terrain and tile_corners == corners.map(func(v): return int(v)) \
				and tile.get("probability", 1.0) == 1.0:
			return tile_name
	return ""
