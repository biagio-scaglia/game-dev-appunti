extends SceneTree
## Scrive res://world/forest/forest_tileset.tres dal JSON dei tile (con l'autotile), per
## dipingere le mappe della foresta nell'editor. Da rilanciare quando cambia l'atlante:
##   godot --headless --path . -s res://tools/make_forest_tileset.gd

const ForestTileset := preload("res://world/forest/forest_tileset.gd")
const OUT := "res://world/forest/forest_tileset.tres"


func _initialize() -> void:
	var tile_set := ForestTileset.build(ForestTileset.load_data())
	var err := ResourceSaver.save(tile_set, OUT)
	print("forest_tileset.tres: ", "ok" if err == OK else "errore %d" % err)
	quit(0 if err == OK else 1)
