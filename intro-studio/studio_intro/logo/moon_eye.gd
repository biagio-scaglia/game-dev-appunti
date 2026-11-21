extends AnimatedSprite2D
## L'occhio che si apre sulla luna piena. Grande come la luna (stesso foglio a
## celle 48x48), quindi va messo come figlio della luna alla stessa scala.
## watch() lo apre, lo tiene aperto un momento e lo richiude.

const SheetFrames := preload("../core/sheet_frames.gd")
const EYE_SHEET := preload("../assets/moon_eye.png")
const CELL := Vector2(48, 48)
const FRAMES := 4

@onready var sfx_thrum: AudioStreamPlayer = $SfxThrum


func _ready() -> void:
	sprite_frames = build_frames()
	animation = &"open"
	frame = 0
	visible = false


## Un'animazione "open": cella 0 = chiuso, l'ultima = spalancato.
static func build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	SheetFrames.add_strip(frames, &"open", EYE_SHEET, CELL, FRAMES)
	frames.remove_animation(&"default")
	return frames


func is_open() -> bool:
	return visible and frame == FRAMES - 1


func open(time := 0.3) -> void:
	visible = true
	var t := create_tween()
	t.tween_method(_set_openness, 0.0, 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


func close(time := 0.18) -> void:
	var t := create_tween()
	t.tween_method(_set_openness, 1.0, 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	visible = false


## Si apre col battito, guarda per `hold` secondi, si chiude.
func watch(hold := 0.65) -> void:
	sfx_thrum.play()
	await open()
	await get_tree().create_timer(hold).timeout
	await close()


## 0 = chiuso, 1 = aperto: sceglie la cella.
func _set_openness(v: float) -> void:
	frame = roundi(clampf(v, 0.0, 1.0) * (FRAMES - 1))
