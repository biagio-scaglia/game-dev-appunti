extends CanvasLayer
## La vita di Lethe, in alto a sinistra (dove l'occhio va per primo; l'obiettivo sta accanto): un cuore solo, non una barra (vault: "Nemici e boss",
## "La mano che stringe il cuore"). A ogni colpo la mano lo stringe di più (heart_hud.png:
## 0 intero, 1-3 la mano che si chiude, 4 stretto del tutto). Sotto, puntini piccoli: quanto
## regge ancora. Il cuore batte, più in fretta quando resta poco; a ogni colpo sobbalza e i
## bordi dello schermo si fanno rossi un attimo. Con l'ultimo pezzo di cuore i bordi restano
## scuri e pulsano, e si sente il battito.

const SHEET := preload("res://ui/heart_hud.png")
const HEARTBEAT := preload("res://audio/heartbeat.wav")
const Sfx := preload("res://core/sfx.gd")

const FRAME := 48
const AT := Vector2(4, 2)
const PIP := Color(0.92, 0.42, 0.55)
const PIP_EMPTY := Color(0.3, 0.2, 0.32, 0.8)

## Falso nei test: niente battito.
var sound := true
var heart := 4
var heart_max := 4
var icon: Sprite2D
var pips: Node2D
var vignette: TextureRect
var _time := 0.0
var _beat_wait := 0.0
var _bump: Tween


func _init() -> void:
	layer = 41


func _ready() -> void:
	vignette = TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.2, 0, 0.04, 0.15), Color(0.35, 0, 0.08, 0.85)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 0.5)
	texture.width = 160
	texture.height = 90
	vignette.texture = texture
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	add_child(vignette)
	icon = Sprite2D.new()
	icon.texture = SHEET
	icon.hframes = 5
	icon.position = AT + Vector2(FRAME, FRAME) / 2.0
	add_child(icon)
	pips = Node2D.new()
	pips.draw.connect(_draw_pips)
	add_child(pips)


## Il fotogramma del cuore: quanto stringe la mano (0-3), 4 se è finito.
static func stage_for(heart_now: int, heart_total: int) -> int:
	if heart_now <= 0:
		return 4
	var squeeze := heart_total - heart_now
	if heart_total <= 1 or squeeze <= 0:
		return 0
	return clampi(ceili(squeeze * 3.0 / (heart_total - 1)), 1, 3)


## Quanto batte in fretta (battiti al secondo), più quando resta poco.
static func beats_per_second(heart_now: int, heart_total: int) -> float:
	return 0.9 + 1.6 * (1.0 - float(heart_now) / maxf(1.0, heart_total))


func show_heart(heart_now: int, heart_total: int) -> void:
	heart = heart_now
	heart_max = heart_total
	icon.frame = stage_for(heart, heart_max)
	pips.queue_redraw()


## Un colpo: il cuore sobbalza, i bordi diventano rossi un attimo.
func hit() -> void:
	if _bump:
		_bump.kill()
	_bump = create_tween()
	icon.scale = Vector2(1.35, 0.8)
	_bump.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	vignette.modulate.a = 1.0
	_bump.parallel().tween_property(vignette, "modulate:a", low_alpha(), 0.5)


## Quanto restano scuri i bordi: solo con l'ultimo pezzo di cuore.
func low_alpha() -> float:
	return 0.55 if heart == 1 else 0.0


func is_low() -> bool:
	return heart == 1


func _process(delta: float) -> void:
	_time += delta
	var bps := beats_per_second(heart, heart_max)
	# Il battito: un piccolo gonfiarsi due volte (tum-tum), poi pausa.
	var phase := fmod(_time * bps, 1.0)
	var pulse := 0.0
	if phase < 0.12:
		pulse = sin(phase / 0.12 * PI)
	elif phase > 0.2 and phase < 0.3:
		pulse = 0.6 * sin((phase - 0.2) / 0.1 * PI)
	if not (_bump and _bump.is_running()) and heart > 0:
		icon.scale = Vector2.ONE * (1.0 + 0.08 * pulse)
	if is_low() and not (_bump and _bump.is_running()):
		vignette.modulate.a = low_alpha() * (0.75 + 0.25 * pulse)
		_beat_wait -= delta
		if _beat_wait <= 0.0:
			_beat_wait = 1.0 / bps
			if sound:
				Sfx.play(self, HEARTBEAT, 1.0, -6.0)


func _draw_pips() -> void:
	var y := AT.y + FRAME + 2
	var total_w := heart_max * 6 - 2
	var x0 := AT.x + (FRAME - total_w) / 2.0
	for i in heart_max:
		var c := PIP if i < heart else PIP_EMPTY
		pips.draw_rect(Rect2(x0 + i * 6, y, 4, 4), c)
