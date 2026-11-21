extends RefCounted
## Da dove va la protagonista a cosa mostrare. Gli sheet hanno 5 righe (giù,
## giù-lato, lato, su-lato, su) con il lato che guarda a destra: le direzioni verso
## sinistra sono le stesse righe specchiate. Solo logica, niente nodi.

const ROWS := ["down", "down_side", "side", "up_side", "up"]


## Una delle 8 direzioni (componenti -1, 0 o 1). Da ferma tiene `current`.
static func dir8(v: Vector2, current: Vector2) -> Vector2:
	if v.length_squared() < 0.0001:
		return current
	var a := snappedf(v.angle(), PI / 4.0)
	return Vector2(roundf(cos(a)), roundf(sin(a)))


static func row_of(dir: Vector2) -> int:
	if dir.y > 0:
		return 0 if dir.x == 0 else 1
	if dir.y == 0:
		return 2
	return 4 if dir.x == 0 else 3


## Verso sinistra si specchia (le righe di lato guardano a destra).
static func flipped(dir: Vector2) -> bool:
	return dir.x < 0


## "walk_side", "idle_down", "attack_up_side", ...
static func animation(kind: String, dir: Vector2) -> StringName:
	return StringName("%s_%s" % [kind, ROWS[row_of(dir)]])
