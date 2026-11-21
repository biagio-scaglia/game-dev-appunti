extends Node2D
## La stanza: crea i livelli di tile (pavimento, muri, oggetti per terra, mobili),
## li dipinge secondo room_layout.gd e accende le luci dei mobili (schermo, lampada,
## luna tra le tende). Il livello dei mobili ha l'ordinamento per Y: la protagonista
## passa davanti o dietro a seconda di dove sta.

const Tiles := preload("room_tileset.gd")
const Layout := preload("room_layout.gd")
const Glow := preload("../core/glow.gd")

var data: Dictionary
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var decor_layer: TileMapLayer
var object_layer: TileMapLayer
var lights: Array[PointLight2D] = []


func _ready() -> void:
	y_sort_enabled = true
	data = Tiles.load_data()
	var tile_set := Tiles.build(data)
	floor_layer = _layer("Floor", tile_set, -3)
	wall_layer = _layer("Walls", tile_set, -2)
	decor_layer = _layer("Decor", tile_set, -1)
	object_layer = _layer("Objects", tile_set, 0)
	object_layer.y_sort_enabled = true
	_paint_structure()
	for entry in Layout.WALL_FEATURES:
		place(wall_layer, entry[0], entry[1])
	for entry in Layout.DECOR:
		place(decor_layer, entry[0], entry[1])
	for entry in Layout.OBJECTS:
		place(object_layer, entry[0], entry[1])


## Mette il tile `tile_name` con l'angolo in alto a sinistra in `cell`.
func place(layer: TileMapLayer, tile_name: String, cell: Vector2i) -> void:
	var tile: Dictionary = data["tiles"][tile_name]
	var origin := Vector2i(int(tile["atlas"][0]), int(tile["atlas"][1]))
	for atlas_cell in Tiles.cells_of(tile):
		layer.set_cell(cell + atlas_cell - origin, Tiles.SOURCE_ID, atlas_cell)
	if tile.has("light"):
		_add_light(tile["light"], cell)


## True se la cella blocca il passaggio (muro o mobile).
func is_solid(cell: Vector2i) -> bool:
	for layer: TileMapLayer in [wall_layer, object_layer]:
		var tile_data: TileData = layer.get_cell_tile_data(cell)
		if tile_data and tile_data.get_collision_polygons_count(0) > 0:
			return true
	return false


func player_start() -> Vector2:
	return floor_layer.map_to_local(Layout.PLAYER_START)


func _layer(layer_name: String, tile_set: TileSet, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = z
	add_child(layer)
	return layer


func _paint_structure() -> void:
	var r := Layout.FLOOR
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			place(floor_layer, "floor_b" if (x * 7 + y * 3) % 5 == 0 else "floor", Vector2i(x, y))
	for x in range(r.position.x, r.end.x):
		place(wall_layer, "wall", Vector2i(x, 0))
	for y in Layout.SIZE.y:
		place(wall_layer, "wall_top", Vector2i(0, y))
		place(wall_layer, "wall_top", Vector2i(Layout.SIZE.x - 1, y))
	for x in Layout.SIZE.x:
		place(wall_layer, "wall_top", Vector2i(x, Layout.SIZE.y - 1))


func _add_light(info: Dictionary, cell: Vector2i) -> void:
	var c: Array = info["color"]
	var l := Glow.light(Color(c[0], c[1], c[2]), float(info["energy"]), float(info["radius"]))
	var top_left := floor_layer.map_to_local(cell) - Vector2(data["tile"], data["tile"]) / 2.0
	l.position = top_left + Vector2(info["offset"][0], info["offset"][1])
	add_child(l)
	lights.append(l)
