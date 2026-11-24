extends RefCounted
## Costruisce il TileSet della stanza da room_tiles.png e room_tiles.json (scritti
## dal generatore dei tile). Ogni mobile occupa più celle: ogni cella è un tile 1x1,
## e le celle dei tile "solid" hanno un poligono di collisione grande quanto la cella.
## Se il tile ha "solid_cells" (es. un albero: blocca solo al tronco), solo quelle celle.
## Se ha "shapes" (i bordi a incastro: [x, y, w, h] in pixel dall'angolo della cella), la
## collisione è fatta di quei rettangoli invece che della cella intera.
## build() serve anche ad altri atlanti con lo stesso formato (la foresta).

const ATLAS := preload("room_tiles.png")
const DATA_PATH := "res://world/room_tiles.json"
const SOURCE_ID := 0
const WORLD_LAYER := 1            # livello fisico "mondo"


static func load_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


static func build(data: Dictionary, atlas: Texture2D = ATLAS) -> TileSet:
	var size := int(data["tile"])
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(size, size)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, WORLD_LAYER)
	var source := TileSetAtlasSource.new()
	source.texture = atlas
	source.texture_region_size = tile_set.tile_size
	tile_set.add_source(source, SOURCE_ID)
	var half := size / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(-half, half)])
	for tile: Dictionary in data["tiles"].values():
		var origin := Vector2i(int(tile["atlas"][0]), int(tile["atlas"][1]))
		for cell in cells_of(tile):
			source.create_tile(cell)
			if not is_solid_cell(tile, cell - origin):
				continue
			var tile_data := source.get_tile_data(cell, 0)
			var polygons: Array[PackedVector2Array] = [square]
			if tile.has("shapes"):
				polygons.clear()
				for r in tile["shapes"]:
					var rect := Rect2(float(r[0]) - half, float(r[1]) - half, float(r[2]), float(r[3]))
					polygons.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
						rect.end, Vector2(rect.position.x, rect.end.y)]))
			for i in polygons.size():
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, i, polygons[i])
	return tile_set


## Se la cella `local` (rispetto all'angolo del tile) blocca il passaggio.
static func is_solid_cell(tile: Dictionary, local: Vector2i) -> bool:
	if not tile["solid"]:
		return false
	if not tile.has("solid_cells"):
		return true
	for c in tile["solid_cells"]:
		if Vector2i(int(c[0]), int(c[1])) == local:
			return true
	return false


## Le celle dell'atlante occupate da un tile (in ordine di righe).
static func cells_of(tile: Dictionary) -> Array[Vector2i]:
	var origin := Vector2i(int(tile["atlas"][0]), int(tile["atlas"][1]))
	var out: Array[Vector2i] = []
	for y in int(tile["size"][1]):
		for x in int(tile["size"][0]):
			out.append(origin + Vector2i(x, y))
	return out
