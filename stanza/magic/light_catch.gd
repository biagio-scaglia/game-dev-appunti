extends RefCounted
## Le cose che prendono luce (gruppo "light_catchers": le lanterne di radice del dungeon).
## Le luci della magia (il proiettile, le fiammelle della veglia) chiamano touch() mentre
## volano e quando si spengono: chi è abbastanza vicino si accende (catch_light()).
## Ogni cosa dice da sola quanto lontano la luce la raggiunge (catch_radius) e da dove
## (catch_point()).

const GROUP := &"light_catchers"


static func touch(tree: SceneTree, at: Vector2) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group(GROUP):
		if node.catch_point().distance_to(at) <= float(node.catch_radius):
			node.catch_light()


## C'è una luce che attira (gruppo "lure": la magia, le lanterne accese) entro `radius`
## da `at`? Gli occhi nelle radici si chiudono.
static func lit_near(tree: SceneTree, at: Vector2, radius: float) -> bool:
	if tree == null:
		return false
	for node in tree.get_nodes_in_group(&"lure"):
		if node is Node2D and (node as Node2D).global_position.distance_to(at) <= radius:
			return true
	return false
