extends CanvasLayer
## La vita di Lethe, in basso a sinistra: una fila di cuori in pixel art, senza riquadro
## (vault: "Nemici e boss"). Ogni cuore è una stretta che il cuore regge ancora.
## - Un colpo: l'ultimo cuore pieno lampeggia bianco e si incrina come vetro, i pezzi
##   cadono; resta il contorno vuoto con la crepa. I bordi dello schermo si fanno rossi.
## - Guarire (la mela, un livello, lo specchio): il cuore torna con un rimbalzo.
## - L'ultimo cuore pieno batte (tum-tum), più in fretta quando ne resta poco; con l'ultimo
##   pezzo i bordi restano rossi e pulsano, e si sente il battito.
## Durante i dialoghi (il riquadro del testo sta in basso) la fila si nasconde.
## I cuori sono disegnati qui (SHAPE), a blocchi di PX pixel: niente immagini.

const HEARTBEAT := preload("res://audio/heartbeat.wav")
const Sfx := preload("res://core/sfx.gd")

## Un cuore, 9 x 8: O contorno, h luce, r pieno, d ombra.
const SHAPE := [
	".OOO.OOO.",
	"OhhrOrrrO",
	"OhrrrrrrO",
	"OrrrrrrdO",
	".OrrrrdO.",
	"..OrrdO..",
	"...OdO...",
	"....O....",
]
## La crepa dei cuori vuoti (celle di SHAPE).
const CRACK := [Vector2i(5, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 5)]
const PX := 2
const GAP := 4
## L'angolo in basso a sinistra della fila.
const MARGIN := Vector2(10, 10)
const FULL := {"O": Color(0.2, 0.05, 0.12), "h": Color(1.0, 0.74, 0.8), "r": Color(0.9, 0.24, 0.38),
	"d": Color(0.6, 0.11, 0.26)}
const EMPTY := {"O": Color(0.42, 0.3, 0.48), "inside": Color(0.1, 0.07, 0.13),
	"crack": Color(0.55, 0.45, 0.62)}
const SHADOW := Color(0, 0, 0, 0.45)
## Quanto si arrossano i bordi al colpo (poi si spengono in mezzo secondo).
const HIT_ALPHA := 0.6


## Un cuore della fila: si disegna da solo, pieno o vuoto, con il lampo bianco sopra.
class Pip extends Node2D:
	var full := true
	var flash := 0.0:
		set(value):
			flash = value
			queue_redraw()

	func _draw() -> void:
		var size := Vector2(SHAPE[0].length(), SHAPE.size()) * PX
		var origin := -size / 2.0
		for pass_shadow in [true, false]:
			for y in SHAPE.size():
				var row: String = SHAPE[y]
				for x in row.length():
					var c := row[x]
					if c == ".":
						continue
					var at := origin + Vector2(x, y) * PX
					if pass_shadow:
						draw_rect(Rect2(at + Vector2(0, PX), Vector2(PX, PX)), SHADOW)
						continue
					var color: Color
					if full:
						color = FULL[c]
					elif c == "O":
						color = EMPTY["O"]
					else:
						color = EMPTY["crack"] if Vector2i(x, y) in CRACK else EMPTY["inside"]
					if flash > 0.0:
						color = color.lerp(Color.WHITE, flash)
					draw_rect(Rect2(at, Vector2(PX, PX)), color)


## Falso nei test: niente battito.
var sound := true
var heart := 4
var heart_max := 4
## La fila dei cuori (la usa anche il suggerimento del tasto della spada, per mettersi accanto).
var box: Control
var pips: Array[Pip] = []

var vignette: TextureRect
var _time := 0.0
var _beat_wait := 0.0
var _bump: Tween
var _shown_once := false


func _init() -> void:
	layer = 6               # sotto il menu di pausa (10): il menu lo copre e lo scurisce


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
	box = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_rebuild()


static func heart_size() -> Vector2:
	return Vector2(SHAPE[0].length(), SHAPE.size()) * PX


## Quanto batte in fretta (battiti al secondo), più quando resta poco.
static func beats_per_second(heart_now: int, heart_total: int) -> float:
	return 0.9 + 1.6 * (1.0 - float(heart_now) / maxf(1.0, heart_total))


## Nasconde la fila (piano) mentre c'è un dialogo, e la rimette dopo.
func set_shown(shown: bool) -> void:
	create_tween().tween_property(box, "modulate:a", 1.0 if shown else 0.0, 0.2)


func show_heart(heart_now: int, heart_total: int) -> void:
	var animate := _shown_once and is_node_ready()
	_shown_once = true
	heart = heart_now
	if heart_total != heart_max or pips.size() != heart_total:
		var grew := heart_total > heart_max
		heart_max = heart_total
		if is_node_ready():
			_rebuild()
			if animate and grew:
				_pop(pips[-1])             # il cuore regge una stretta in più: quello nuovo salta
	for i in pips.size():
		var pip := pips[i]
		var full := i < heart
		if pip.full == full:
			continue
		pip.full = full
		pip.queue_redraw()
		if animate:
			if full:
				_pop(pip)
			else:
				_shatter(pip)


## Un colpo: la fila sobbalza, i bordi diventano rossi un attimo.
func hit() -> void:
	if _bump:
		_bump.kill()
	_bump = create_tween()
	for x in [-3.0, 3.0, -2.0, 0.0]:
		_bump.tween_property(box, "position:x", MARGIN.x + x, 0.04)
	vignette.modulate.a = maxf(HIT_ALPHA, low_alpha())   # un lampo, non tutto lo schermo
	_bump.parallel().tween_property(vignette, "modulate:a", low_alpha(), 0.5)


## Quanto restano scuri i bordi: solo con l'ultimo pezzo di cuore.
func low_alpha() -> float:
	return 0.55 if heart == 1 else 0.0


func is_low() -> bool:
	return heart == 1


func _rebuild() -> void:
	for pip in pips:
		pip.queue_free()
	pips.clear()
	var size := heart_size()
	for i in heart_max:
		var pip := Pip.new()
		pip.full = i < heart
		pip.position = Vector2(i * (size.x + GAP), 0) + size / 2.0
		box.add_child(pip)
		pips.append(pip)
	box.size = Vector2(heart_max * (size.x + GAP) - GAP, size.y)
	box.position = Vector2(MARGIN.x, 360 - MARGIN.y - size.y)


## Torna pieno: un salto e un lampo.
func _pop(pip: Pip) -> void:
	pip.scale = Vector2(1.6, 1.6)
	pip.flash = 1.0
	var t := pip.create_tween().set_parallel()
	t.tween_property(pip, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(pip, "flash", 0.0, 0.3)


## Si rompe: lampo bianco, schiacciato, e i pezzi rossi che cadono.
func _shatter(pip: Pip) -> void:
	pip.flash = 1.0
	pip.scale = Vector2(1.3, 0.8)
	var t := pip.create_tween().set_parallel()
	t.tween_property(pip, "flash", 0.0, 0.25)
	t.tween_property(pip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var shards := CPUParticles2D.new()
	shards.amount = 8
	shards.lifetime = 0.6
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.direction = Vector2.UP
	shards.spread = 70.0
	shards.gravity = Vector2(0, 420)
	shards.initial_velocity_min = 50.0
	shards.initial_velocity_max = 110.0
	shards.scale_amount_min = 2.0
	shards.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, FULL["r"])
	ramp.set_color(1, Color(FULL["d"], 0.0))
	shards.color_ramp = ramp
	shards.position = box.position + pip.position
	add_child(shards)
	shards.emitting = true
	shards.finished.connect(shards.queue_free)


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
	for i in pips.size():
		var pip := pips[i]
		if pip.flash > 0.0:
			continue                             # sta saltando o si sta rompendo
		if i == heart - 1:
			pip.scale = Vector2.ONE * (1.0 + (0.18 if is_low() else 0.1) * pulse)
		else:
			pip.scale = pip.scale.move_toward(Vector2.ONE, delta * 4.0)
	if _bump and _bump.is_running():
		return                              # il sobbalzo del colpo comanda i bordi
	if not is_low():
		# Guarita (mela, livello, specchio): il rosso rimasto dall'ultimo pezzo se ne va.
		vignette.modulate.a = move_toward(vignette.modulate.a, 0.0, delta * 1.5)
		return
	vignette.modulate.a = low_alpha() * (0.75 + 0.25 * pulse)
	_beat_wait -= delta
	if _beat_wait <= 0.0:
		_beat_wait = 1.0 / bps
		if sound:
			Sfx.play(self, HEARTBEAT, 1.0, -6.0)
