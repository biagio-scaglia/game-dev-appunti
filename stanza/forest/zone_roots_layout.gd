extends RefCounted
## Il dungeon delle radici (vault: "Il dungeon delle radici"): sotto l'albero secco, le radici
## della pianta del davanzale di Lethe, quella che nessuno annaffia più. Solo dati (li usa
## tools/make_forest_zone.gd per scrivere zone_roots.tscn; funzioni comuni in zone_layout.gd).
##
## Una griglia di 3 x 3 stanze da 20 x 12 celle (una schermata); ne servono 7 più l'arena. La
## camera resta sulla stanza in cui si è (ROOMS) e scivola passando una porta.
##
##                 [ arena: il Cervo Secco ]
##                            |  (cancello di radici)
##  [ le lanterne ] --- [ il cuore delle radici ] --- [ la stanza del masso ]
##         |                  |                              |
##  [ le spine    ]     [ sotto l'albero ]           [ le cose sepolte ]
##                      (si arriva qui, il riposo)
##
## Il terreno: tutto terra (EARTH_BLOCKS), poi si scavano le stanze e le porte (CARVE). Il
## pavimento è di radici (BASE). In cima a ogni stanza la parete di terra con le radici che
## pendono (WALL_FACES).

const SIZE := Vector2i(60, 36)
const BASE := "roots"
## Il buio sottoterra (più del bosco di notte) e la musica.
const DARKNESS := Color(0.3, 0.27, 0.4)
const THEME := "res://audio/roots_theme.wav"
const SPAWN := Vector2i(25, 30)
## Da dove si arriva: dal buco tra le radici della radura dell'albero.
const ENTRIES := {"top": Vector2i(25, 30)}
## Le radici da cui si è scesi (in alto a sinistra della prima stanza): si risale.
const EXITS := [[Rect2i(22, 27, 2, 2), "tree", "hole"]]

## Le stanze: [id, nome che compare entrando, rettangolo in celle].
const ROOMS := [
	["arena", "Where the Deer Sleeps", Rect2i(20, 0, 20, 12)],
	["lanterns", "The Lantern Roots", Rect2i(0, 12, 20, 12)],
	["heart", "The Heart of the Roots", Rect2i(20, 12, 20, 12)],
	["boulder", "The Stone Room", Rect2i(40, 12, 20, 12)],
	["thorns", "The Thorn Passage", Rect2i(0, 24, 20, 12)],
	["entrance", "Under the Tree", Rect2i(20, 24, 20, 12)],
	["buried", "The Buried Things", Rect2i(40, 24, 20, 12)],
]

## Vertici [x0, y0, x1, y1] inclusi.
const EARTH_BLOCKS := [[0, 0, 60, 36]]
## Le stanze (l'interno di ognuna: [ox + 2, oy + 1, ox + 18, oy + 10]) e le porte tra loro.
const CARVE := [
	[22, 1, 38, 10],       # arena
	[2, 13, 18, 22],       # le lanterne
	[22, 13, 38, 22],      # il cuore delle radici
	[42, 13, 58, 22],      # il masso
	[2, 25, 18, 34],       # le spine
	[22, 25, 38, 34],      # sotto l'albero
	[42, 25, 58, 34],      # le cose sepolte
	[28, 10, 31, 13],      # porta: cuore -> arena (chiusa dal cancello di radici)
	[18, 16, 22, 19],      # porta: lanterne <-> cuore
	[38, 16, 42, 19],      # porta: cuore <-> masso
	[28, 22, 31, 25],      # porta: cuore <-> sotto l'albero
	[8, 22, 11, 25],       # porta: lanterne <-> spine
	[48, 22, 51, 25],      # porta: masso <-> cose sepolte
]
## La parete in cima alle stanze (root_wall, alta 2 celle): [riga, prima colonna, ultima colonna].
## Si salta dove c'è una porta in alto.
const WALL_FACES := [
	[1, 22, 37],
	[13, 2, 17], [13, 22, 27], [13, 31, 37], [13, 42, 57],
	[25, 2, 7], [25, 12, 17], [25, 22, 27], [25, 31, 37], [25, 42, 47], [25, 52, 57],
]

## Le cose con cui si parla (i cue di forest.dialogue che sono tile).
const TALKS := ["silver_frame", "root_heart", "root_gate", "watering_can", "old_stone"]
const THINGS := [
	# Sotto l'albero: il riposo (la cornice d'argento), le radici da cui si è scesi.
	["silver_frame", Vector2i(35, 27)],
	# Il cuore delle radici, e il cancello verso l'arena.
	["root_heart", Vector2i(28, 15)],
	["root_gate", Vector2i(28, 11)], ["root_gate", Vector2i(29, 11)], ["root_gate", Vector2i(30, 11)],
	# Le lanterne: l'annaffiatoio mai usato.
	["watering_can", Vector2i(5, 19)],
	# La stanza del masso: la pietra antica col segno (il gesto Aprire).
	["old_stone", Vector2i(54, 15)],
	["rock", Vector2i(45, 20)], ["rock_b", Vector2i(10, 31)], ["stump", Vector2i(45, 32)],
]
const DECOR := [
	["glow_root", Vector2i(24, 31)], ["glow_root", Vector2i(36, 32)], ["glow_root", Vector2i(23, 20)],
	["glow_root", Vector2i(36, 15)], ["glow_root", Vector2i(4, 16)], ["glow_root", Vector2i(16, 29)],
	["glow_root", Vector2i(56, 20)], ["glow_root", Vector2i(44, 29)],
	["roots", Vector2i(22, 28)], ["roots", Vector2i(26, 33)], ["roots", Vector2i(33, 20)],
	["roots", Vector2i(12, 17)], ["roots", Vector2i(52, 31)], ["roots", Vector2i(7, 32)],
	["mushrooms", Vector2i(37, 29)], ["mushrooms", Vector2i(3, 20)], ["mushrooms", Vector2i(57, 33)],
	["pebbles", Vector2i(31, 33)], ["pebbles", Vector2i(14, 21)], ["pebbles", Vector2i(50, 17)],
	["leaf_litter", Vector2i(29, 29)], ["leaf_litter", Vector2i(31, 31)],
]
## Pochi nemici per ora (il dungeon vero arriva coi passi dopo): falene nel buio, lucciole
## false tra le radici che fanno luce.
const ENEMIES := [
	["moth", Vector2i(33, 18)], ["moth", Vector2i(8, 16)], ["firefly", Vector2i(13, 30)],
	["firefly", Vector2i(52, 28)], ["moth", Vector2i(50, 17)],
]
## La luce che scende dal buco tra le radici, dove Lethe arriva (pixel, dove tocca terra).
const BEAMS := [Vector2(800, 960)]
const FIREFLIES := []
