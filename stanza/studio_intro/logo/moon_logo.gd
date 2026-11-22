extends Node2D
## La luna dello studio. Quattro azioni, ognuna si può aspettare con await:
## rise() sale dal basso ancora nuova, wax() cresce fino a piena, shine() brilla,
## watch() apre l'occhio e ti guarda (vedi moon_eye.gd).

const SheetFrames := preload("../core/sheet_frames.gd")
const MOON_SHEET := preload("../assets/moon_phases.png")
const CELL := Vector2(48, 48)
const PHASES := 12
## Raggio della luna a schermo (20 pixel dello sprite, a scala 2).
const RADIUS := 40.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var glow: Sprite2D = $Glow
@onready var eye: AnimatedSprite2D = $Eye
@onready var sfx_rise: AudioStreamPlayer = $SfxRise
@onready var sfx_chime: AudioStreamPlayer = $SfxChime

## Dove si ferma dopo essere salita: la posizione che ha nella scena.
var rest_position := Vector2.ZERO


func _ready() -> void:
	rest_position = position
	sprite.sprite_frames = build_frames()
	sprite.animation = &"phases"
	set_phase(0.0)
	glow.modulate.a = 0.0
	visible = false


## Un'animazione "phases": cella 0 = luna nuova, l'ultima = luna piena.
static func build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	SheetFrames.add_strip(frames, &"phases", MOON_SHEET, CELL, PHASES)
	frames.remove_animation(&"default")
	return frames


## 0 = nuova, 1 = piena. Sceglie la cella più vicina.
func set_phase(p: float) -> void:
	sprite.frame = roundi(clampf(p, 0.0, 1.0) * (PHASES - 1))


func phase() -> float:
	return float(sprite.frame) / (PHASES - 1)


## Un punto sul bordo della luna (angolo in radianti), nelle coordinate del genitore.
func rim_point(angle: float, margin := 6.0) -> Vector2:
	return rest_position + Vector2.from_angle(angle) * (RADIUS + margin)


## Sale di `distance` pixel comparendo dal buio.
func rise(distance := 36.0, time := 1.1) -> void:
	visible = true
	position = rest_position + Vector2(0, distance)
	modulate.a = 0.0
	sfx_rise.play()
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", rest_position, time)
	t.tween_property(self, "modulate:a", 1.0, time * 0.7)
	await t.finished


## Da nuova a piena, piano all'inizio e alla fine.
func wax(time := 1.4) -> void:
	var t := create_tween()
	t.tween_method(set_phase, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## Luna piena: un battito di luce e l'alone che resta acceso.
func shine() -> void:
	sfx_chime.play()
	var t := create_tween()
	t.tween_property(glow, "modulate:a", 1.0, 0.18)
	t.tween_property(glow, "modulate:a", 0.6, 0.8)
	await t.finished


## La luna apre l'occhio, ti guarda per `hold` secondi, lo richiude.
func watch(hold := 0.65) -> void:
	await eye.watch(hold)
