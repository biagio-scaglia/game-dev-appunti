extends RefCounted
## Le zone della foresta: nome -> scena. Il salvataggio ricorda il nome (GameState.zone),
## le uscite di una zona dicono il nome della prossima.

const SCENES := {
	"wake": "res://forest/zone_wake.tscn",      # la radura della caduta
	"tree": "res://forest/zone_tree.tscn",      # la radura dell'albero secco
}
const FIRST := "wake"


static func scene(zone_id: String) -> String:
	return SCENES.get(zone_id, SCENES[FIRST])


## I dati di una zona (forest/zone_<nome>_layout.gd).
static func layout(zone_id: String) -> GDScript:
	return load("res://forest/zone_%s_layout.gd" % (zone_id if SCENES.has(zone_id) else FIRST))
