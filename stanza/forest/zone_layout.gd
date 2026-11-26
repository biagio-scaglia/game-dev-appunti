extends RefCounted
## Le funzioni comuni ai dati delle zone (zone_wake_layout.gd, zone_tree_layout.gd...): ogni
## zona è un file di sole costanti, qui si leggono. Il terreno si descrive per vertici
## (come l'autotile "a angoli"): ogni vertice della griglia (W+1 x H+1) è erba, sentiero,
## Lete o bosco fitto; dai 4 vertici di una cella si sceglie il pezzo.
##
## Le costanti di una zona: SIZE, SPAWN, CANOPY_BLOCKS, PATHS, LETHE, BRIDGE ([] = niente
## ponte), THINGS, DECOR, ENEMIES, BEAMS, FIREFLIES, TALKS, ENTRIES {nome: cella},
## EXITS [[Rect2i, zona, entrata]]. Quelle che mancano valgono vuote.
## Per i posti sottoterra (il dungeon delle radici): BASE ("roots": il pavimento è di radici,
## non d'erba), EARTH_BLOCKS (la terra, che blocca), CARVE (dove si scava: stanze e porte,
## tornano pavimento), WALL_FACES (la parete in cima alle stanze), ROOMS (la camera per
## stanze), DARKNESS e THEME (il buio e la musica).
## I meccanismi: PLATES, GATES, KEYS, LOCKS, CHESTS (zone_puzzles.gd); LANTERNS, CURTAINS,
## LANTERNS_OPEN (zone_lanterns.gd); EYES, gli occhi nelle radici (zone_dressing.gd);
## SPIKES, CRUMBLE (zone_traps.gd); BOULDERS (zone_boulders.gd); TREASURES (zone_puzzles.gd).

const GRASS := ""
## Se due materiali si toccano nella stessa cella, vince il primo (il bosco copre tutto,
## l'acqua copre il sentiero).
const PRECEDENCE := ["earth", "canopy", "lethe", "path"]
## Il materiale e la costante della zona che lo descrive.
const MATERIALS := {"canopy": "CANOPY_BLOCKS", "path": "PATHS", "lethe": "LETHE", "earth": "EARTH_BLOCKS"}


## Una costante della zona (o `default` se non c'è).
static func value(layout: GDScript, key: String, default: Variant = []) -> Variant:
	return layout.get_script_constant_map().get(key, default)


## I vertici: vertices[y][x] = "" (erba) o il materiale.
static func vertices(layout: GDScript) -> Array:
	var size: Vector2i = value(layout, "SIZE")
	var v := []
	for y in size.y + 1:
		var row := []
		row.resize(size.x + 1)
		row.fill(GRASS)
		v.append(row)
	for material in ["path", "lethe", "canopy", "earth"]:   # dal più debole al più forte
		for r in value(layout, MATERIALS[material]):
			for y in range(r[1], r[3] + 1):
				for x in range(r[0], r[2] + 1):
					v[y][x] = material
	for r in value(layout, "CARVE"):                         # lo scavo: torna pavimento
		for y in range(r[1], r[3] + 1):
			for x in range(r[0], r[2] + 1):
				v[y][x] = GRASS
	return v


## Il terreno di una cella: [materiale, angoli (alto-sx, alto-dx, basso-sx, basso-dx)].
## Materiale "" = erba piena.
static func cell_terrain(v: Array, cell: Vector2i) -> Array:
	var corners := [v[cell.y][cell.x], v[cell.y][cell.x + 1], v[cell.y + 1][cell.x], v[cell.y + 1][cell.x + 1]]
	for material in PRECEDENCE:
		if material in corners:
			return [material, corners.map(func(c): return 1 if c == material else 0)]
	return [GRASS, [0, 0, 0, 0]]


## Il centro di una cella, in pixel.
static func cell_center(cell: Vector2i, tile := 32) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * tile
