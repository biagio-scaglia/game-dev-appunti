extends Node2D
## Il cielo: stelle che si accendono una alla volta e poi tremolano, più una
## stella cadente a comando. Tutto disegnato con _draw(), niente sprite.
##
## Le stelle sono generate da un seme fisso: il cielo è sempre lo stesso,
## in ogni gioco. È parte della firma dello studio.

const STAR_COLOR := Color(0.96, 0.9, 0.77)
const SHOOT_COLOR := Color(1, 0.97, 0.88)
const TRAIL := 9

## Seme del cielo. Cambialo e cambiano le stelle.
@export var star_seed := 1987
@export var star_count := 46
## Area in cui nascono le stelle (centrata sull'origine del nodo).
@export var area := Rect2(-340, -200, 680, 400)
## Zona senza stelle, per non disturbare il nome.
@export var keep_clear := Rect2(-190, 0, 380, 70)

@onready var sfx_whoosh: AudioStreamPlayer = $SfxWhoosh

## Ogni stella: {pos, px (lato in pixel), alpha, speed, phase, delay}
var stars: Array[Dictionary] = []
## Da 0 a 1: quante stelle sono già accese (ognuna ha il suo `delay`).
var reveal := 0.0
var _time := 0.0
var _shoot := -1.0          # avanzamento della stella cadente (-1 = nessuna)
var _shoot_from := Vector2.ZERO
var _shoot_to := Vector2.ZERO


func _ready() -> void:
	stars = generate_stars(star_seed, star_count, area, keep_clear)


## Stelle a posizioni intere, mai dentro `clear`. Stesso seme = stesse stelle.
static func generate_stars(seed_value: int, count: int, rect: Rect2, clear: Rect2) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	while out.size() < count:
		var pos := Vector2(rng.randi_range(int(rect.position.x), int(rect.end.x)),
				rng.randi_range(int(rect.position.y), int(rect.end.y)))
		if clear.has_point(pos):
			continue
		out.append({
			"pos": pos,
			"px": 2.0 if rng.randf() < 0.15 else 1.0,
			"alpha": rng.randf_range(0.35, 1.0),
			"speed": rng.randf_range(1.0, 3.2),
			"phase": rng.randf_range(0.0, TAU),
			"delay": rng.randf(),
		})
	return out


## Accende le stelle nell'arco di `time` secondi.
func light_up(time := 1.4) -> Tween:
	var t := create_tween()
	t.tween_property(self, "reveal", 1.0, time)
	return t


## Una stella cadente da `from` a `to` in `time` secondi.
func shoot(from := Vector2(300, -170), to := Vector2(130, -105), time := 0.55) -> void:
	_shoot_from = from
	_shoot_to = to
	sfx_whoosh.play()
	var t := create_tween()
	t.tween_property(self, "_shoot", 1.0, time).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	_shoot = -1.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for s in stars:
		var a := star_alpha(s, reveal, _time)
		if a > 0.01:
			draw_rect(Rect2(s["pos"], Vector2(s["px"], s["px"])), Color(STAR_COLOR, a))
	if _shoot >= 0.0:
		_draw_shooting_star()


## Luminosità di una stella: accensione (secondo il suo delay) per tremolio.
static func star_alpha(s: Dictionary, reveal_value: float, time: float) -> float:
	var on := clampf((reveal_value - s["delay"] * 0.8) * 5.0, 0.0, 1.0)
	var twinkle := 0.65 + 0.35 * sin(time * s["speed"] + s["phase"])
	return s["alpha"] * on * twinkle


func _draw_shooting_star() -> void:
	var head := _shoot_from.lerp(_shoot_to, _shoot)
	var back := (_shoot_from - _shoot_to).normalized()
	var fade := 1.0 - maxf(0.0, (_shoot - 0.8) / 0.2)   # sparisce alla fine
	for i in TRAIL:
		var p := (head + back * i * 2.0).round()
		var a := (1.0 - float(i) / TRAIL) * fade
		draw_rect(Rect2(p, Vector2(2 if i == 0 else 1, 2 if i == 0 else 1)), Color(SHOOT_COLOR, a))
