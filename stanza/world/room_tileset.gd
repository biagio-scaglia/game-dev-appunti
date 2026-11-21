extends RefCounted
## Costruisce il TileSet della stanza da room_tiles.png e room_tiles.json (scritti
## dal generatore dei tile). Ogni mobile occupa più celle: ogni cella è un tile 1x1,
## e le celle dei tile "solid" hanno un poligono di collisione grande quanto la cella.

const ATLAS := preload("room_tiles.png")
const DATA_PATH := "res://world/room_tiles.json"
const SOURCE_ID := 0
const WORLD_LAYER := 1            # livello fisico "mondo"


static func load_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


static func build(data: Dictionary) -> TileSet:
	var size := int(data["tile"])
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(size, size)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, WORLD_LAYER)
	var source := TileSetAtlasSource.new()
	source.texture = ATLAS
	source.texture_region_size = tile_set.tile_size
	tile_set.add_source(source, SOURCE_ID)
	var half := size / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(-half, half)])
	for tile: Dictionary in data["tiles"].values():
		for cell in cells_of(tile):
			source.create_tile(cell)
			if tile["solid"]:
				var tile_data := source.get_tile_data(cell, 0)
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, square)
	return tile_set


## Le celle dell'atlante occupate da un tile (in ordine di righe).
static func cells_of(tile: Dictionary) -> Array[Vector2i]:
	var origin := Vector2i(int(tile["atlas"][0]), int(tile["atlas"][1]))
	var out: Array[Vector2i] = []
	for y in int(tile["size"][1]):
		for x in int(tile["size"][0]):
			out.append(origin + Vector2i(x, y))
	return out
