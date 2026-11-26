extends RefCounted
## La seconda zona della foresta: la radura dell'albero secco. Solo dati (li usa
## tools/make_forest_zone.gd per scrivere zone_tree.tscn; funzioni comuni in zone_layout.gd).
##
## 30 x 20 celle. Si arriva da ovest, dal sentiero della prima zona. In mezzo l'albero secco,
## bianco come un osso, con la luna che ci cade sopra: è la pianta del davanzale di Lethe,
## enorme. Sotto le radici, un buco che scende al buio (il dungeon delle radici). Intorno
## foglie morte, radici che affiorano, una pozza del Lete a nord-est.

const SIZE := Vector2i(30, 20)
const SPAWN := Vector2i(2, 10)
## Da ovest si torna alla prima zona.
const EXITS := [[Rect2i(0, 9, 1, 3), "wake", "east"]]
## "hole": risalendo dalle radici, accanto al buco.
const ENTRIES := {"west": Vector2i(2, 10), "hole": Vector2i(17, 10)}
## Le cose con cui si parla (i cue di forest.dialogue che sono tile).
const TALKS := ["dead_tree", "root_hole"]
## L'albero e il buco tra le radici (le scene della regia li guardano).
const TREE := Vector2i(14, 4)
const ROOT_HOLE := Vector2i(15, 8)

## Vertici [x0, y0, x1, y1] inclusi. Chiuso tutto intorno, aperto solo a ovest.
const CANOPY_BLOCKS := [
	[0, 0, 30, 1], [0, 19, 30, 20], [29, 0, 30, 20], [0, 0, 1, 8], [0, 13, 1, 20],
	[3, 2, 6, 5], [24, 13, 28, 17], [3, 15, 7, 18], [26, 1, 29, 2],
]
## Il sentiero da ovest, e lo spiazzo di terra davanti all'albero.
const PATHS := [[1, 10, 13, 11], [13, 9, 19, 12]]
## La pozza del Lete, che esce dal bosco a nord.
const LETHE := [[20, 1, 22, 6]]
const BRIDGE := []

const THINGS := [
	["dead_tree", TREE],
	["root_hole", ROOT_HOLE],
	["pine", Vector2i(7, 2)], ["pine", Vector2i(26, 10)], ["tree", Vector2i(25, 3)],
	["tree", Vector2i(13, 15)], ["birch", Vector2i(10, 5)], ["birch", Vector2i(19, 14)],
	["hollow_log", Vector2i(8, 13)], ["big_rock", Vector2i(24, 8)], ["rock_b", Vector2i(12, 13)],
	["stump", Vector2i(18, 6)], ["bush", Vector2i(4, 6)], ["bush", Vector2i(22, 15)],
]
const DECOR := [
	# Le foglie morte e le radici intorno all'albero.
	["leaf_litter", Vector2i(13, 7)], ["leaf_litter", Vector2i(17, 8)], ["leaf_litter", Vector2i(14, 10)],
	["leaf_litter", Vector2i(16, 11)], ["leaf_litter", Vector2i(12, 9)], ["leaf_litter", Vector2i(19, 10)],
	["roots", Vector2i(13, 8)], ["roots", Vector2i(17, 7)], ["roots", Vector2i(16, 9)],
	# La pozza: canne e ninfee.
	["reeds", Vector2i(19, 5)], ["reeds", Vector2i(22, 4)], ["lily", Vector2i(20, 3)], ["lily", Vector2i(21, 4)],
	# Luce nel buio.
	["glow_moss", Vector2i(4, 12)], ["glow_moss", Vector2i(22, 17)], ["mushrooms", Vector2i(9, 8)],
	["mushrooms", Vector2i(23, 12)], ["moonflower", Vector2i(18, 9)], ["flowers", Vector2i(6, 8)],
	# Il resto.
	["fern", Vector2i(11, 12)], ["tall_grass", Vector2i(5, 13)], ["tall_grass", Vector2i(26, 15)],
	["sapling", Vector2i(22, 9)], ["sapling", Vector2i(9, 9)], ["pebbles", Vector2i(6, 10)],
]
## Pochi nemici: la radura è triste, non pericolosa.
const ENEMIES := [
	["moth", Vector2i(11, 7)], ["moth", Vector2i(22, 11)], ["bramble", Vector2i(17, 14)],
	["firefly", Vector2i(26, 7)],
]
## La luna cade sull'albero (pixel, dove tocca terra).
const BEAMS := [Vector2(496, 250)]
const FIREFLIES := [Vector2(300, 200), Vector2(750, 450)]
