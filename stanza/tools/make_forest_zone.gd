extends SceneTree
## Scrive res://forest/zone_<nome>.tscn dai dati di forest/zone_<nome>_layout.gd: il terreno
## (TileMapLayer "Ground", coi pezzi dell'autotile scelti dai vertici), le piante basse
## ("Decor"), le cose (Sprite2D sotto "World", y-sort: alberi, rocce, specchio, rovi...),
## dove arriva Lethe ("Spawn") e le uscite verso le altre zone ("Exit_0"...). Poi la scena si ritocca nell'editor
## (col pennello del terreno e spostando le cose): luci e collisioni delle cose le mette
## forest_zone.gd quando parte, dal tile scritto nei metadati.
##   godot --headless --path . -s res://tools/make_forest_zone.gd -- <nome>   (wake, tree; senza: wake)

const ZoneLayout := preload("res://forest/zone_layout.gd")
const Zones := preload("res://forest/zones.gd")
const ForestTileset := preload("res://world/forest/forest_tileset.gd")
const RoomTileset := preload("res://world/room_tileset.gd")
const ZONE_SCRIPT := preload("res://forest/forest_zone.gd")
const TILE := 32

var data: Dictionary
var zone_id := "wake"
var Layout: GDScript
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 11
	var args := OS.get_cmdline_user_args()
	zone_id = args[0] if args.size() > 0 else Zones.FIRST
	Layout = Zones.layout(zone_id)
	data = ForestTileset.load_data()
	var tile_set: TileSet = load("res://world/forest/forest_tileset.tres")
	var root := Node2D.new()
	root.name = "Zone" + zone_id.capitalize()
	root.set_script(ZONE_SCRIPT)
	root.set("zone_id", zone_id)
	var ground := _layer("Ground", tile_set, root)
	var decor := _layer("Decor", tile_set, root)
	_paint_ground(ground)
	for entry in ZoneLayout.value(Layout, "DECOR"):
		decor.set_cell(entry[1], RoomTileset.SOURCE_ID, _atlas(entry[0]))
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	_own(root, world)
	var counts := {}
	for entry in ZoneLayout.value(Layout, "THINGS"):
		var tile_name: String = entry[0]
		counts[tile_name] = counts.get(tile_name, 0) + 1
		var sprite := thing_sprite(data, tile_name, entry[1])
		sprite.name = "%s_%d" % [tile_name, counts[tile_name]]
		_own(root, sprite, world)
	var spawn := Marker2D.new()
	spawn.name = "Spawn"
	spawn.position = ZoneLayout.cell_center(ZoneLayout.value(Layout, "SPAWN"), TILE)
	_own(root, spawn)
	var exits: Array = ZoneLayout.value(Layout, "EXITS")
	for i in exits.size():
		var exit := Area2D.new()
		exit.name = "Exit_%d" % i
		exit.collision_layer = 0
		exit.collision_mask = 2                  # la protagonista
		var cells: Rect2i = exits[i][0]
		var rect := Rect2(Vector2(cells.position) * TILE, Vector2(cells.size) * TILE)
		exit.position = rect.get_center()
		exit.set_meta(&"to_zone", exits[i][1])
		exit.set_meta(&"entry", exits[i][2])
		_own(root, exit)
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		_own(root, shape, exit)
	var out := Zones.scene(zone_id)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, out)
	print(out.get_file(), ": ", "ok" if err == OK else "errore %d" % err)
	root.free()
	quit(0 if err == OK else 1)


## Una cosa della zona: lo Sprite2D del tile, con l'origine in basso al centro (i piedi,
## per l'y-sort) e il nome del tile nei metadati.
static func thing_sprite(tiles: Dictionary, tile_name: String, cell: Vector2i) -> Sprite2D:
	return preload("res://forest/zone_dressing.gd").thing_sprite(tiles, tile_name, cell)


func _paint_ground(ground: TileMapLayer) -> void:
	var v := ZoneLayout.vertices(Layout)
	var size: Vector2i = ZoneLayout.value(Layout, "SIZE")
	for y in size.y:
		for x in size.x:
			var terrain := ZoneLayout.cell_terrain(v, Vector2i(x, y))
			var tile_name := _pick(terrain[0], terrain[1])
			ground.set_cell(Vector2i(x, y), RoomTileset.SOURCE_ID, _atlas(tile_name))
	for face in ZoneLayout.value(Layout, "WALL_FACES"):       # la parete in cima alle stanze
		var origin := _atlas("root_wall")
		for x in range(face[1], face[2] + 1):
			ground.set_cell(Vector2i(x, face[0]), RoomTileset.SOURCE_ID, origin)
			ground.set_cell(Vector2i(x, face[0] + 1), RoomTileset.SOURCE_ID, origin + Vector2i(0, 1))
	var b: Array = ZoneLayout.value(Layout, "BRIDGE")
	if b.is_empty():
		return
	for x in range(b[1], b[2] + 1):
		var tile_name := "bridge_h_w" if x == b[1] else ("bridge_h_e" if x == b[2] else "bridge_h")
		ground.set_cell(Vector2i(x, b[0]), RoomTileset.SOURCE_ID, _atlas(tile_name))


## Il pezzo per un materiale e i suoi angoli; l'erba e il bosco fitto pieno a caso tra le
## varianti.
func _pick(material: String, corners: Array) -> String:
	if material == "":
		var roll := rng.randf()
		if String(ZoneLayout.value(Layout, "BASE", "")) == "roots":
			return "root_floor_b" if roll < 0.3 else "root_floor"
		return "grass_c" if roll < 0.08 else ("grass_d" if roll < 0.2 else ("grass_b" if roll < 0.45 else "grass"))
	if material == "canopy" and corners == [1, 1, 1, 1]:
		return ["canopy_c", "thicket_b", "thicket_c"][rng.randi() % 3]
	return ForestTileset.tile_for(data, material, corners)


func _atlas(tile_name: String) -> Vector2i:
	var tile: Dictionary = data["tiles"][tile_name]
	return Vector2i(int(tile["atlas"][0]), int(tile["atlas"][1]))


func _layer(layer_name: String, tile_set: TileSet, root: Node) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	_own(root, layer)
	return layer


func _own(root: Node, node: Node, parent: Node = null) -> void:
	(parent if parent else root).add_child(node)
	node.owner = root
