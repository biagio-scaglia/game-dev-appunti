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
	[49, 22, 50, 25],      # porta: masso <-> cose sepolte (stretta: c'è la porta della camera)
]
## La parete in cima alle stanze (root_wall, alta 2 celle): [riga, prima colonna, ultima colonna].
## Si salta dove c'è una porta in alto.
const WALL_FACES := [
	[1, 22, 37],
	[13, 2, 17], [13, 22, 27], [13, 31, 37], [13, 42, 57],
	[25, 2, 7], [25, 12, 17], [25, 22, 27], [25, 31, 37], [25, 42, 48], [25, 50, 57],
]

## I meccanismi (forest/zone_puzzles.gd, li crea quando la zona parte e ricorda cosa è aperto):
## - la piastra con l'impronta di una mano piccola, nelle lanterne: apre il cancello di radici
##   verso il passaggio delle spine;
## - la chiave della camera di Lethe, nel passaggio delle spine;
## - la porta della sua camera, tra la stanza del masso e le cose sepolte (si apre con la chiave);
## - la scatola da scarpe di sotto il letto, nelle cose sepolte: dentro il filo rosso.
## Piastre: [id, cella, cancello che apre]. Cancelli: [id, celle in alto (il cancello è alto due)]. Chiavi: [id, cella].
## Porte: [id, chiave, cella in alto a sinistra]. Scatole: [id, cella, oggetto dentro].
const PLATES := [["handprint", Vector2i(14, 20), "thorns"]]
const GATES := [
	["thorns", [Vector2i(8, 22), Vector2i(9, 22), Vector2i(10, 22)]],
	# Il cancello dell'arena (alto due celle, come la parete) sta nel varco della parete del
	# cuore: si vede arrivando. Lo aprono le lanterne (LANTERNS_OPEN).
	["arena", [Vector2i(28, 13), Vector2i(29, 13), Vector2i(30, 13)]],
]
const KEYS := [["old_key", Vector2i(4, 30)]]
const LOCKS := [["bedroom", "old_key", Vector2i(49, 22)]]
const CHESTS := [["shoebox", Vector2i(50, 30), "heart_thread"]]

## Il passo 4 (forest/zone_lanterns.gd): le lanterne di radice lungo la parete delle lanterne,
## la terza dietro una tenda di radici (si apre col gesto Aprire, la luna la accende). Tutte
## accese aprono il cancello dell'arena. Lanterne: [id, cella]. Tende: [id, cella, lanterna].
const LANTERNS := [["west", Vector2i(4, 14)], ["middle", Vector2i(10, 14)], ["east", Vector2i(15, 14)]]
const CURTAINS := [["east", Vector2i(15, 14), "east"]]
const LANTERNS_OPEN := "arena"
## Gli occhi nelle radici (forest/root_eye.gd): sulle pareti delle stanze buie.
const EYES := [
	Vector2i(7, 13), Vector2i(13, 14), Vector2i(5, 25), Vector2i(15, 26), Vector2i(1, 30),
	Vector2i(44, 25), Vector2i(56, 26), Vector2i(23, 14),
]

## Le cose con cui si parla (i cue di forest.dialogue che sono tile).
const TALKS := ["silver_frame", "root_heart", "watering_can", "old_stone"]
const THINGS := [
	# Sotto l'albero: il riposo (la cornice d'argento), le radici da cui si è scesi.
	["silver_frame", Vector2i(35, 27)],
	# Il cuore delle radici (il cancello verso l'arena è in GATES).
	["root_heart", Vector2i(28, 15)],
	# Le lanterne: l'annaffiatoio mai usato.
	["watering_can", Vector2i(5, 19)],
	# La stanza del masso: la pietra antica col segno (il gesto Aprire).
	["old_stone", Vector2i(54, 15)],
	["boulder", Vector2i(51, 17)], ["rock", Vector2i(45, 20)], ["rock_b", Vector2i(10, 31)], ["stump", Vector2i(45, 32)],
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
	# Il passaggio delle spine: la siepe di rovi al piede della parete, ai lati della porta.
	["thorns", Vector2i(2, 27)], ["thorns", Vector2i(3, 27)], ["thorns", Vector2i(4, 27)],
	["thorns", Vector2i(6, 27)], ["thorns", Vector2i(7, 27)], ["thorns", Vector2i(11, 27)],
	["thorns", Vector2i(12, 27)], ["thorns", Vector2i(14, 27)], ["thorns", Vector2i(15, 27)],
	["thorns", Vector2i(16, 27)], ["thorns", Vector2i(17, 27)],
	# La stanza del masso: i solchi di chi ha provato a spostarlo, le schegge.
	["drag_marks", Vector2i(48, 18)], ["drag_marks", Vector2i(49, 18)], ["drag_marks", Vector2i(50, 18)],
	["rubble", Vector2i(54, 19)], ["rubble", Vector2i(47, 15)],
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
