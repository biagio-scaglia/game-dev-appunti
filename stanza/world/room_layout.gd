extends RefCounted
## Com'è arredata la stanza: solo dati. 20 x 11 celle da 32 px (640 x 352).
## Muro in alto alto 2 celle (righe 0-1), muri laterali e in basso di una cella,
## pavimento nel mezzo. Ogni voce è [nome del tile, cella in alto a sinistra].

const SIZE := Vector2i(20, 11)
const FLOOR := Rect2i(1, 2, 18, 8)
const PLAYER_START := Vector2i(8, 7)   # davanti al tappeto, non sopra la console

## Ogni cosa racconta (vedi il vault, "La stanza di Lethe"): il resto è stato tolto.
const WALL_FEATURES := [
	["wall_poster", Vector2i(4, 0)],      # la vita di prima: la sua maghetta preferita
	["window", Vector2i(8, 0)],           # la luna: fuori c'è ancora un mondo
	["wall_calendar", Vector2i(14, 0)],   # giorni barrati fino a uno cerchiato, poi niente
	["door", Vector2i(17, 0)],            # chiusa
]

const DECOR := [
	["rug", Vector2i(7, 5)],
	["console", Vector2i(9, 5)],          # dove scappa
	["cushion", Vector2i(8, 6)],          # dove si siede, schiacciato
	["clothes", Vector2i(4, 8)],          # buttata accanto al letto
	["paper_balls", Vector2i(14, 3)],     # accanto alla scrivania: una lettera che non riesce a scrivere
	["food_tray", Vector2i(17, 2)],       # davanti alla porta, intatto, con un biglietto
]

const OBJECTS := [
	["shelf", Vector2i(1, 2)],
	["covered_mirror", Vector2i(5, 2)],   # non riesce a guardarsi
	["dead_plant", Vector2i(7, 2)],       # sotto la finestra: nessuno la annaffia da mesi
	["bed", Vector2i(1, 6)],
	["nightstand", Vector2i(3, 6)],       # una foto a faccia in giù
	["desk_pc", Vector2i(11, 2)],
	["chair", Vector2i(12, 4)],
	["lamp", Vector2i(15, 2)],
	["trash_bag", Vector2i(18, 8)],
]
