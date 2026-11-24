extends CanvasLayer
## L'obiettivo in alto a sinistra: cosa fare adesso, in una riga. Davanti il cuore del menu
## che batte piano; dietro una striscia scura che sfuma verso destra, così si legge sopra
## la stanza senza coprirla.
##
## show_text() cambia l'obiettivo: il vecchio scivola via a sinistra, il nuovo entra con un
## piccolo suono. Se cambia solo il numero (es. 2/5 -> 3/5) la riga non si muove: il testo
## si accende un attimo. Testo vuoto = niente obiettivo (la riga sparisce).

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const HEART := preload("res://title/art/heart.png")
const HeartMenu := preload("res://ui/heart_menu.gd")
const Sfx := preload("res://core/sfx.gd")
const PING := preload("res://audio/ui_move.wav")

const AT := Vector2(8, 6)
const TEXT := Color(0.9, 0.86, 0.98)
const LIT := Color(1.0, 0.82, 0.92)
const STRIP := Color(0.03, 0.02, 0.06, 0.6)
const SLIDE := 12.0

## Falso nei test: niente suono.
var sound := true
var text := ""
var row: HBoxContainer
var label: Label
var heart: TextureRect
var strip: TextureRect
var _frames: Array[AtlasTexture] = []
var _beat_step := 0
var _beat_left := 0.0
var _move: Tween


func _init() -> void:
	layer = 40


func _ready() -> void:
	for i in 2:
		var frame := AtlasTexture.new()
		frame.atlas = HEART
		frame.region = Rect2(Vector2(HEART.get_width() / 2.0 * i, 0),
			Vector2(HEART.get_width() / 2.0, HEART.get_height()))
		_frames.append(frame)
	# La striscia: un gradiente da scuro a trasparente.
	var gradient := Gradient.new()
	gradient.set_color(0, STRIP)
	gradient.set_color(1, Color(STRIP, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	strip = TextureRect.new()
	strip.texture = texture
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.position = Vector2(0, 0)
	strip.size = Vector2(300, 30)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	row = HBoxContainer.new()
	row.position = AT
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	heart = TextureRect.new()
	heart.texture = _frames[0]
	heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(heart)
	label = Label.new()
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", TEXT)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	row.add_child(label)
	row.modulate.a = 0.0
	strip.modulate.a = 0.0


## Le due righe sono lo stesso obiettivo (cambia solo il numero tra parentesi)?
static func same_goal(a: String, b: String) -> bool:
	return a.get_slice("(", 0) == b.get_slice("(", 0)


func show_text(new_text: String) -> void:
	if new_text == text:
		return
	var old := text
	text = new_text
	if _move:
		_move.kill()
	_move = create_tween()
	if new_text == "":
		_move.set_parallel()
		_move.tween_property(row, "modulate:a", 0.0, 0.3)
		_move.tween_property(strip, "modulate:a", 0.0, 0.3)
		return
	if old != "" and same_goal(old, new_text):
		label.text = new_text
		label.modulate = LIT
		_move.tween_property(label, "modulate", Color.WHITE, 0.6)
		return
	if old != "":
		_move.tween_property(row, "modulate:a", 0.0, 0.2)
		_move.parallel().tween_property(row, "position:x", AT.x - SLIDE, 0.2)
	_move.tween_callback(func() -> void:
		label.text = new_text
		label.modulate = Color.WHITE
		row.position.x = AT.x + SLIDE
		if sound:
			Sfx.play(self, PING, 0.7, -10.0))
	_move.tween_property(row, "modulate:a", 1.0, 0.35)
	_move.parallel().tween_property(row, "position:x", AT.x, 0.35).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	_move.parallel().tween_property(strip, "modulate:a", 1.0, 0.35)


func _process(delta: float) -> void:
	if text == "":
		return
	# Il cuore batte come quello del menu, ma più piano.
	_beat_left -= delta * 0.7
	if _beat_left > 0.0:
		return
	_beat_step = (_beat_step + 1) % HeartMenu.BEAT.size()
	heart.texture = _frames[HeartMenu.BEAT[_beat_step][0]]
	_beat_left = HeartMenu.BEAT[_beat_step][1]
