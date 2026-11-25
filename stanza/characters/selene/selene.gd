extends Node2D
## Selene, la compagna (vault: "Entità compagna"): uno spicchio di luna, sceso dalla luna
## della finestra della stanza. Galleggia accanto a Lethe, un po' dietro e sopra la testa,
## e la segue con calma; fa un po' di luce intorno (al buio del bosco è una lampada) e
## lascia una scia di pulviscolo. Ha un occhio solo, come la luna del titolo, che sbatte.
## Mente anche lei, a volte (per proteggere Lethe): lo fa il dialogo, non questo nodo.
## Durante il gioco dice battute brevi sopra la testa (bark), senza fermare niente: il primo
## nemico sciolto, il cuore che stringe, la mela... Ognuna con una chiave si dice una volta.
##
## Disegnata qui (SHAPE), a blocchi di PX pixel: niente immagini.

const Glow := preload("res://core/glow.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
## Il colore delle sue battute: pallido come lei.
const VOICE := Color(0.82, 0.86, 1.0)
const BARK_TIME := 2.8

## La falce, 9 x 9: O contorno, h luna, s ombra della luna, e l'occhio.
const SHAPE := [
	"...OOO...",
	".OOhhO...",
	"OhhhO....",
	"OheO.....",
	"OhhO.....",
	"OshO.....",
	"OshhO....",
	".OOshO...",
	"...OOO...",
]
const PX := 2
const COLORS := {"O": Color(0.6, 0.68, 0.95), "h": Color(0.95, 0.92, 0.82), "s": Color(0.8, 0.8, 0.86),
	"e": Color(0.22, 0.16, 0.34)}
const LIGHT_COLOR := Color(0.74, 0.8, 1.0)
## Dove sta rispetto ai piedi di Lethe (x verso le sue spalle), e quanto in fretta la segue.
const OFFSET := Vector2(20, -52)
const FOLLOW := 3.5
const BOB := 3.0

## Chi segue (Lethe). Senza, sta ferma dov'è.
var target: Node2D
var light: PointLight2D
var trail: CPUParticles2D
## Da che parte sta (1 = a destra di Lethe, -1 = a sinistra): la falce si gira.
var side := 1.0
## Mentre scende dal cielo (descend) non segue.
var following := true
var _time := 0.0
var _blink := 0.0
var _eye_open := true
var _glow_boost := 0.0
var _bark: Label
## Le battute già dette (chiave -> vero).
var said := {}


func _ready() -> void:
	z_index = 6                          # sopra le chiome: vola
	light = Glow.light(LIGHT_COLOR, 0.55, 60.0)
	add_child(light)
	trail = _make_trail()
	add_child(trail)
	_blink = randf_range(2.0, 4.0)


## Dove vuole stare adesso (dietro le spalle di Lethe, sopra la testa).
func goal() -> Vector2:
	if not is_instance_valid(target):
		return global_position
	var facing: Vector2 = target.get(&"facing") if target.get(&"facing") != null else Vector2.DOWN
	if absf(facing.x) > 0.1:
		side = -signf(facing.x)            # resta alle sue spalle
	return target.global_position + Vector2(OFFSET.x * side, OFFSET.y)


## Mettila subito al suo posto (all'avvio della zona, dopo un salvataggio).
func snap() -> void:
	global_position = goal()


## Nascosta e ferma finché non scende (appena creata sarebbe nell'angolo della mappa, e
## volerebbe verso Lethe: sembrerebbe scendere due volte).
func wait_hidden() -> void:
	following = false
	visible = false


## Scende dal cielo fino al suo posto accanto a Lethe (la prima volta). `pace` per i test.
func descend(pace := 1.0) -> void:
	following = false
	var to := goal()
	global_position = to + Vector2(-30, -240)
	visible = true
	var t := create_tween()
	t.tween_property(self, "global_position", to, 2.2 * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	following = true
	glow_up()


## Una battuta breve sopra di lei. Con `key` la dice una volta sola (ritorna falso se l'ha
## già detta). Una nuova copre quella di prima.
func bark(text: String, key := "", time := BARK_TIME) -> bool:
	if key != "":
		if said.has(key):
			return false
		said[key] = true
	if is_instance_valid(_bark):
		_bark.queue_free()
	_bark = Label.new()
	_bark.text = text
	_bark.add_theme_font_override(&"font", FONT)
	_bark.add_theme_font_size_override(&"font_size", 16)
	_bark.add_theme_color_override(&"font_color", VOICE)
	_bark.add_theme_color_override(&"font_outline_color", Color(0.06, 0.04, 0.12))
	_bark.add_theme_constant_override(&"outline_size", 4)
	_bark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark.size = Vector2(220, 20)
	_bark.position = Vector2(-110, -34)
	_bark.z_index = 30
	_bark.modulate.a = 0.0
	add_child(_bark)
	glow_up()
	var t := _bark.create_tween()
	t.tween_property(_bark, "modulate:a", 1.0, 0.2)
	t.tween_interval(time)
	t.tween_property(_bark, "modulate:a", 0.0, 0.4)
	t.tween_callback(_bark.queue_free)
	return true


func bark_text() -> String:
	return _bark.text if is_instance_valid(_bark) else ""


## Un attimo di luce in più (quando arriva, quando Lethe dice la verità).
func glow_up() -> void:
	_glow_boost = 1.0


func _process(delta: float) -> void:
	_time += delta
	if following and is_instance_valid(target):
		global_position = global_position.lerp(goal(), 1.0 - exp(-FOLLOW * delta))
	_blink -= delta
	if _blink <= 0.0:
		_eye_open = not _eye_open
		_blink = 0.12 if not _eye_open else randf_range(2.5, 5.0)
		queue_redraw()
	_glow_boost = move_toward(_glow_boost, 0.0, delta)
	light.energy = 0.55 + 0.08 * sin(_time * 2.0) + 0.6 * _glow_boost
	queue_redraw()


func _draw() -> void:
	var bob := roundf(sin(_time * 2.4) * BOB)
	var size := Vector2(SHAPE[0].length(), SHAPE.size()) * PX
	var origin := Vector2(-size.x / 2.0, -size.y / 2.0 + bob)
	for y in SHAPE.size():
		var row: String = SHAPE[y]
		for x in row.length():
			var c := row[x]
			if c == ".":
				continue
			if c == "e" and not _eye_open:
				c = "h"
			var col: Color = COLORS[c]
			if _glow_boost > 0.0:
				col = col.lerp(Color.WHITE, _glow_boost * 0.6)
			# La falce guarda Lethe: specchiata quando sta alla sua sinistra.
			var px := x if side < 0.0 else row.length() - 1 - x
			draw_rect(Rect2(origin + Vector2(px, y) * PX, Vector2(PX, PX)), col)


func _make_trail() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 0.9
	p.local_coords = false                  # la scia resta dove è passata
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 5.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, -12)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.95, 1.0, 0.9))
	ramp.set_color(1, Color(0.7, 0.78, 1.0, 0.0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	return p
