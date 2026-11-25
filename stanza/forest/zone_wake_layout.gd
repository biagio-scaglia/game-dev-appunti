extends RefCounted
## La prima zona della foresta: la radura dove Lethe cade dallo specchio. Solo dati (li usa
## tools/make_forest_zone.gd per scrivere zone_wake.tscn, che poi si ritocca nell'editor).
##
## 40 x 24 celle da 32 px (2 schermi per 2). Il bosco fitto tutto intorno, con l'uscita a
## est; il sentiero parte dalla radura dell'atterraggio e va verso l'uscita; a metà il primo
## ruscello del Lete, con un ponte; un ramo del sentiero sale a nord e finisce contro i
## rovi (dietro, una nicchia con una pietra antica: si aprirà col gesto Aprire).
##
## Il terreno si descrive per vertici (come l'autotile "a angoli"): ogni vertice della
## griglia (W+1 x H+1) è erba, sentiero, Lete o bosco fitto; dai 4 vertici di una cella si
## sceglie il pezzo.

const SIZE := Vector2i(40, 24)
const SPAWN := Vector2i(6, 12)
## Dove si esce (celle): verso il cuore della foresta.
const EXIT := Rect2i(38, 9, 2, 5)

## Vertici [x0, y0, x1, y1] inclusi.
const CANOPY_BLOCKS := [
	[0, 0, 40, 1], [0, 23, 40, 24], [0, 0, 1, 24], [39, 0, 40, 8], [39, 15, 40, 24],
	[2, 2, 4, 6], [2, 18, 6, 22], [30, 2, 33, 5], [34, 18, 38, 22], [11, 2, 14, 7], [18, 2, 22, 7],
	[9, 19, 12, 22], [36, 2, 38, 4],
]
const PATHS := [[8, 11, 22, 12], [28, 11, 40, 12], [15, 5, 16, 11]]
const LETHE := [[24, 4, 26, 20]]
## Il ponte sul Lete, sulla riga del sentiero: [riga, prima colonna, ultima colonna].
const BRIDGE := [11, 23, 26]

## Le cose (Sprite2D nella scena): [tile, cella in alto a sinistra].
const THINGS := [
	["mirror", Vector2i(4, 9)],
	["brambles", Vector2i(15, 6)],
	["old_stone", Vector2i(15, 2)],
	["tree", Vector2i(6, 3)], ["tree", Vector2i(26, 1)], ["tree", Vector2i(33, 6)],
	["tree", Vector2i(12, 14)], ["tree", Vector2i(29, 14)], ["tree", Vector2i(2, 13)],
	["pine", Vector2i(8, 1)], ["pine", Vector2i(22, 13)], ["pine", Vector2i(35, 13)],
	["pine", Vector2i(17, 17)], ["pine", Vector2i(28, 5)],
	["big_rock", Vector2i(19, 9)], ["rock", Vector2i(31, 10)], ["rock", Vector2i(7, 16)],
	["log", Vector2i(14, 19)], ["stump", Vector2i(10, 8)], ["bush", Vector2i(21, 16)],
	["bush", Vector2i(36, 9)], ["bush", Vector2i(3, 7)],
	["birch", Vector2i(9, 15)], ["birch", Vector2i(19, 18)], ["hollow_log", Vector2i(27, 16)],
	["rock_b", Vector2i(22, 9)], ["rock_b", Vector2i(34, 16)],
]
## Le piante basse (TileMapLayer "Decor"): [tile, cella].
const DECOR := [
	["mushrooms", Vector2i(5, 14)], ["mushrooms", Vector2i(17, 3)], ["mushrooms", Vector2i(27, 18)],
	["flowers", Vector2i(8, 13)], ["flowers", Vector2i(21, 4)], ["flowers", Vector2i(32, 16)],
	["fern", Vector2i(11, 10)], ["fern", Vector2i(18, 14)], ["fern", Vector2i(33, 9)],
	["fern", Vector2i(23, 7)], ["tall_grass", Vector2i(9, 6)], ["tall_grass", Vector2i(27, 9)],
	["tall_grass", Vector2i(14, 16)], ["tall_grass", Vector2i(36, 16)], ["roots", Vector2i(13, 9)],
	["roots", Vector2i(30, 12)],
]
## I nemici: [tipo, cella]. Falene vicino al sentiero e al Lete, rovi ai lati del sentiero
## (mai sopra: non chiudono la strada), lucciole false tra le lucciole vere.
const ENEMIES := [
	["moth", Vector2i(18, 8)], ["moth", Vector2i(31, 15)], ["moth", Vector2i(10, 17)],
	["bramble", Vector2i(12, 9)], ["bramble", Vector2i(33, 13)], ["bramble", Vector2i(21, 14)],
	["firefly", Vector2i(8, 18)], ["firefly", Vector2i(35, 7)],
]
## Raggi di luna tra le chiome (pixel, dove cadono).
const BEAMS := [Vector2(300, 150), Vector2(620, 330), Vector2(1000, 260)]
## Lucciole (pixel, centro di ogni nuvola).
const FIREFLIES := [Vector2(250, 420), Vector2(700, 200), Vector2(1100, 500), Vector2(500, 600)]

const GRASS := ""
const MATERIALS := {"canopy": CANOPY_BLOCKS, "path": PATHS, "lethe": LETHE}
## Se due materiali si toccano nella stessa cella, vince il primo (il bosco copre tutto,
## l'acqua copre il sentiero).
const PRECEDENCE := ["canopy", "lethe", "path"]


## I vertici: vertices[y][x] = "" (erba) o il materiale.
static func vertices() -> Array:
	var v := []
	for y in SIZE.y + 1:
		var row := []
		row.resize(SIZE.x + 1)
		row.fill(GRASS)
		v.append(row)
	for material in ["path", "lethe", "canopy"]:            # dal più debole al più forte
		for r in MATERIALS[material]:
			for y in range(r[1], r[3] + 1):
				for x in range(r[0], r[2] + 1):
					v[y][x] = material
	return v


## Il terreno di una cella: [materiale, angoli (alto-sx, alto-dx, basso-sx, basso-dx)].
## Materiale "" = erba piena.
static func cell_terrain(v: Array, cell: Vector2i) -> Array:
	var corners := [v[cell.y][cell.x], v[cell.y][cell.x + 1], v[cell.y + 1][cell.x], v[cell.y + 1][cell.x + 1]]
	for material in PRECEDENCE:
		if material in corners:
			return [material, corners.map(func(c): return 1 if c == material else 0)]
	return [GRASS, [0, 0, 0, 0]]
