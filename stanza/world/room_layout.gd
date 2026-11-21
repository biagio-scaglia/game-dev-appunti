extends RefCounted
## Com'è arredata la stanza: solo dati. 20 x 11 celle da 32 px (640 x 352).
## Muro in alto alto 2 celle (righe 0-1), muri laterali e in basso di una cella,
## pavimento nel mezzo. Ogni voce è [nome del tile, cella in alto a sinistra].

const SIZE := Vector2i(20, 11)
const FLOOR := Rect2i(1, 2, 18, 8)
const PLAYER_START := Vector2i(9, 6)

const WALL_FEATURES := [
	["wall_poster", Vector2i(4, 0)],
	["window", Vector2i(8, 0)],
	["wall_poster", Vector2i(14, 0)],
	["door", Vector2i(17, 0)],
]

const DECOR := [
	["rug", Vector2i(7, 5)],
	["console", Vector2i(9, 6)],
	["clothes", Vector2i(4, 4)],
	["clothes", Vector2i(5, 8)],
	["noodle_cups", Vector2i(10, 4)],
	["noodle_cups", Vector2i(3, 9)],
	["cans", Vector2i(14, 4)],
	["cans", Vector2i(12, 8)],
	["pizza_box", Vector2i(6, 9)],
	["books", Vector2i(16, 5)],
]

const OBJECTS := [
	["shelf", Vector2i(1, 2)],
	["bed", Vector2i(1, 6)],
	["desk_pc", Vector2i(11, 2)],
	["chair", Vector2i(12, 4)],
	["lamp", Vector2i(15, 2)],
	["trash_bag", Vector2i(18, 8)],
	["trash_bag", Vector2i(17, 9)],
	["trash_bag", Vector2i(18, 9)],
]
