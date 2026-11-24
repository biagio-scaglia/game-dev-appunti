extends RefCounted
## Le cose della stanza con cui si può parlare: dove stanno e quale c'è davanti a Lethe.
## Solo logica (niente nodi): una "cosa" è {"id": nome del tile, "rect": Rect2 nel mondo}.

const Layout := preload("room_layout.gd")

## Quanto avanti guarda Lethe dai piedi, e quanto si allarga ogni cosa per "prenderla".
const REACH := 18.0
const MARGIN := 6.0


## Le cose della stanza (muri, tappeti, mobili) con il loro rettangolo nel mondo.
## `ids`: solo queste (vuoto = tutte). I rettangoli sono relativi alla stanza.
static func build(data: Dictionary, ids: PackedStringArray = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var size := float(data["tile"])
	for entry in Layout.WALL_FEATURES + Layout.DECOR + Layout.OBJECTS:
		var id: String = entry[0]
		if not ids.is_empty() and id not in ids:
			continue
		var tile: Dictionary = data["tiles"][id]
		var cell: Vector2i = entry[1]
		var cells := Vector2(float(tile["size"][0]), float(tile["size"][1]))
		out.append({"id": id, "rect": Rect2(Vector2(cell) * size, cells * size)})
	return out


## La cosa davanti a Lethe (piedi in `feet`, sguardo `facing`), o "" se non c'è niente.
## Prima conta quello che ha davanti, poi quello su cui sta; a pari merito vince la più
## piccola (il cuscino sopra il tappeto).
static func in_front(things: Array[Dictionary], feet: Vector2, facing: Vector2) -> String:
	var probes := [feet + facing.normalized() * REACH, feet]
	for probe: Vector2 in probes:
		var best := ""
		var best_area := INF
		for thing in things:
			var rect: Rect2 = thing["rect"]
			if rect.grow(MARGIN).has_point(probe) and rect.get_area() < best_area:
				best = thing["id"]
				best_area = rect.get_area()
		if best != "":
			return best
	return ""


## Il rettangolo della cosa `id` (vuoto se non c'è).
static func rect_of(things: Array[Dictionary], id: String) -> Rect2:
	for thing in things:
		if thing["id"] == id:
			return thing["rect"]
	return Rect2()
