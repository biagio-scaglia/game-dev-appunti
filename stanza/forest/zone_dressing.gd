extends RefCounted
## L'allestimento di una zona, quando parte: quello che la scena non salva perché viene dai
## dati dei tile e della zona.
## - le cose (Sprite2D sotto World col tile nei metadati): luce e collisioni dal JSON dei
##   tile (le collisioni solo nelle celle "solid": il tronco, per gli alberi);
## - le luci delle piante basse (funghi, fiori, radici che fanno luce);
## - i raggi di luna (nel bosco scendono dal cielo, sottoterra da un buco nel soffitto) e le
##   lucciole;
## - le cose con cui si parla (i tile in TALKS e il ruscello del Lete).
## Solo funzioni statiche: la zona le chiama in _ready.

const RoomTileset := preload("res://world/room_tileset.gd")
const RoomFx := preload("res://world/room_fx.gd")
const MoonBeam := preload("res://fx/moon_beam.gd")
const Fireflies := preload("res://fx/fireflies.gd")
const ForestTileset := preload("res://world/forest/forest_tileset.gd")

const TILE := 32
## Da quanto sopra il bordo della mappa partono i raggi di luna (nel bosco).
const BEAM_ABOVE := 90.0
## Quanto è lunga la luce che scende da un buco nel soffitto, sottoterra.
const UNDERGROUND_BEAM := 150.0


## Le cose della zona (gli Sprite2D sotto `world` col tile nei metadati).
static func thing_nodes(world: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child in world.get_children():
		if child is Sprite2D and child.has_meta(&"tile"):
			out.append(child)
	return out


## Il rettangolo di una cosa (il suo disegno intero, in pixel della zona).
static func thing_rect(sprite: Sprite2D) -> Rect2:
	return Rect2(sprite.position + sprite.offset, sprite.texture.get_size())


## Una cosa: lo Sprite2D del tile `tile_name` con l'angolo in alto a sinistra in `cell`,
## l'origine in basso al centro (i piedi, per l'y-sort) e il nome del tile nei metadati. La
## usano il generatore delle scene e i meccanismi creati quando la zona parte.
static func thing_sprite(tiles: Dictionary, tile_name: String, cell: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	set_tile(sprite, tiles, tile_name)
	var size := sprite.texture.get_size()
	sprite.position = Vector2(cell) * TILE + Vector2(size.x / 2.0, size.y)
	return sprite


## Cambia il disegno di una cosa (la porta che si apre, la scatola, la piastra), con
## l'origine sempre ai piedi.
static func set_tile(sprite: Sprite2D, tiles: Dictionary, tile_name: String) -> void:
	var tile: Dictionary = tiles["tiles"][tile_name]
	var size := Vector2(float(tile["size"][0]), float(tile["size"][1])) * TILE
	var texture := AtlasTexture.new()
	texture.atlas = ForestTileset.ATLAS
	texture.region = Rect2(Vector2(float(tile["atlas"][0]), float(tile["atlas"][1])) * TILE, size)
	sprite.texture = texture
	sprite.offset = Vector2(-size.x / 2.0, -size.y)
	sprite.set_meta(&"tile", tile_name)


## Luci e collisioni delle cose (le luci vanno in `parent`).
static func build_things(parent: Node2D, world: Node, data: Dictionary) -> void:
	for sprite in thing_nodes(world):
		build_thing(parent, sprite, data)


## Luce e collisioni di una cosa. Ritorna il corpo delle collisioni (o null se non blocca).
static func build_thing(parent: Node2D, sprite: Sprite2D, data: Dictionary) -> StaticBody2D:
	var tile: Dictionary = data["tiles"][sprite.get_meta(&"tile")]
	RoomFx.attach(parent, tile, thing_rect(sprite).position)
	if not tile["solid"]:
		return null
	var body := StaticBody2D.new()
	body.collision_layer = RoomTileset.WORLD_LAYER
	sprite.add_child(body)
	var cells := Vector2i(int(tile["size"][0]), int(tile["size"][1]))
	for y in cells.y:
		for x in cells.x:
			if not RoomTileset.is_solid_cell(tile, Vector2i(x, y)):
				continue
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = Vector2(TILE, TILE)
			shape.shape = box
			shape.position = sprite.offset + (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE
			body.add_child(shape)
	return body


## Le luci delle piante basse del layer `decor`.
static func light_decor(parent: Node2D, decor: TileMapLayer, data: Dictionary) -> void:
	var by_atlas := {}
	for tile_name in data["tiles"]:
		var t: Dictionary = data["tiles"][tile_name]
		by_atlas[Vector2i(int(t["atlas"][0]), int(t["atlas"][1]))] = t
	for cell in decor.get_used_cells():
		var tile: Dictionary = by_atlas.get(decor.get_cell_atlas_coords(cell), {})
		if tile.has("light"):
			RoomFx.attach(parent, tile, Vector2(cell) * TILE)


## I raggi di luna (`points`: dove toccano terra). `underground`: escono da un buco nel
## soffitto della stanza invece che dal cielo.
static func add_beams(parent: Node2D, points: Array, underground: bool) -> void:
	for at in points:
		var beam := MoonBeam.new()
		if underground:
			beam.length = UNDERGROUND_BEAM
			beam.slant = 16.0
			beam.fade_until = 0.25
		else:
			# Il raggio scende da sopra la mappa (lo spiraglio non si vede mai): così salendo
			# non si arriva al pezzo che sfuma e non sparisce.
			beam.length = at.y + BEAM_ABOVE
			beam.slant = beam.length * 0.25
			beam.fade_until = BEAM_ABOVE * 0.9 / beam.length   # pieno già prima del bordo
		beam.top_width = 14.0
		beam.position = at - Vector2(beam.slant, beam.length)
		beam.pool = true                         # la luna fa una pozza per terra
		beam.unshaded = true
		beam.color = Color(0.55, 0.67, 1.0, 0.085)
		beam.dust_amount = 34
		beam.z_index = 1
		parent.add_child(beam)


static func add_fireflies(parent: Node2D, points: Array) -> void:
	for at in points:
		var flies := Fireflies.new()
		flies.position = at
		flies.z_index = 2
		parent.add_child(flies)


## Le cose con cui si parla: i tile in `talks` e il ruscello del Lete (sopra e sotto il
## ponte: sul ponte non si guarda l'acqua a ogni passo). Le cose dei meccanismi (meta
## "puzzle": i cancelli, le porte) le dice zone_puzzles.gd, col loro cue e solo finché sono
## chiuse.
static func talk_things(world: Node, talks: Array, lethe: Array, bridge: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sprite in thing_nodes(world):
		var tile_name: String = sprite.get_meta(&"tile")
		if tile_name in talks and not sprite.has_meta(&"puzzle"):
			out.append({"id": tile_name, "rect": thing_rect(sprite)})
	var bridge_row: int = bridge[0] if not bridge.is_empty() else -1
	for r in lethe:
		var spans := [[r[1], r[3]]]
		if bridge_row > r[1] and bridge_row < r[3]:
			spans = [[r[1], bridge_row], [bridge_row + 1, r[3]]]
		for span in spans:
			var top_left := Vector2(r[0], span[0]) * TILE
			out.append({"id": "lethe", "rect": Rect2(top_left, Vector2(r[2] - r[0], span[1] - span[0]) * TILE)})
	return out
