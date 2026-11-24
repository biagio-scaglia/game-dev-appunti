extends Control
## La cutscene di New Game, prima della stanza. Breve (circa 25 secondi), senza dialoghi:
## 1. nero, e qualcuno bussa tre volte;
## 2. il calendario al buio: i giorni si barrano uno alla volta, uno viene cerchiato, poi
##    niente;
## 3. sotto, a matita: "tomorrow I'll go out." E sotto ancora la stessa frase, una per ogni
##    giorno dopo, sempre più sbiadita;
## 4. di nuovo nero, di nuovo bussano. Poi la stanza.
## Annuncia la domanda del gioco ("aprirai la porta?") senza spiegarla (vault: "Trama - bozza").
##
## Un tasto mostra "Press again to skip"; il secondo salta (così non si salta per sbaglio).
## Continue non passa di qui: solo New Game.

## Emesso a cutscene finita (o saltata), con lo schermo già nero.
signal finished

const CalendarPage := preload("calendar_page.gd")
const Main := preload("res://main.gd")
const SkipInput := preload("res://studio_intro/core/skip_input.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const KNOCK := preload("res://audio/menu_knock.wav")
const SCRATCH := preload("res://audio/ui_move.wav")

## La scena dopo. Vuota = resta qui ed emette solo finished (test).
@export_file("*.tscn") var next_scene := "res://main.tscn"
## Falso nei test: niente suoni.
@export var sound := true

const LINE := "tomorrow I'll go out."
## Quante volte la frase si ripete sotto (i giorni dopo quello cerchiato).
const ECHOES := 6
const BG := Color(0.03, 0.025, 0.045)
const PENCIL := Color(0.78, 0.76, 0.88)
const SKIP_HINT := "Press again to skip"

var calendar: Node2D
var lines: VBoxContainer
var black: ColorRect
var hint: Label
var _knock: AudioStreamPlayer
var _scratch: AudioStreamPlayer
var _done := false
var _skip_armed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	calendar = CalendarPage.new()
	calendar.position = ((Vector2(640, 0) - Vector2(CalendarPage.PAPER_SIZE.x, 0)) / 2.0).floor() \
		+ Vector2(0, 24)
	calendar.modulate.a = 0.0
	add_child(calendar)
	lines = VBoxContainer.new()
	lines.position = Vector2(0, 212)
	lines.size = Vector2(640, 120)
	lines.add_theme_constant_override(&"separation", -2)
	add_child(lines)
	hint = _label(SKIP_HINT, Color(0.62, 0.58, 0.74, 0.7))
	hint.position = Vector2(440, 336)
	hint.size = Vector2(192, 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.visible = false
	add_child(hint)
	black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_knock = _player(KNOCK, -6.0)
	_scratch = _player(SCRATCH, -14.0)
	_play()


func _player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p


static func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", color)
	return label


## Quanto è sbiadita la frase numero `i` (0 la prima, la più chiara).
static func echo_alpha(i: int) -> float:
	return 0.9 * pow(0.62, i)


func is_done() -> bool:
	return _done


## Aspetta `seconds`, ma smette subito se la cutscene è finita (saltata). Vero se va avanti.
func _wait(seconds: float) -> bool:
	if _done:
		return false
	await get_tree().create_timer(seconds, false).timeout
	return not _done


func _fade(node: CanvasItem, to: float, seconds: float) -> bool:
	if _done:
		return false
	var t := create_tween()
	t.tween_property(node, "modulate:a" if node != black else "color:a", to, seconds)
	await t.finished
	return not _done


func _knock_three() -> bool:
	if sound and not _done:
		_knock.play()
	return await _wait(2.2)


func _play() -> void:
	# 1. Nero, bussano.
	if not await _wait(0.8): return
	if not await _knock_three(): return
	# 2. Il calendario.
	black.color.a = 0.0
	if not await _fade(calendar, 1.0, 1.2): return
	if not await _wait(0.6): return
	for day in range(1, CalendarPage.CIRCLED_DAY):
		calendar.crossed = day
		if sound:
			_scratch.pitch_scale = randf_range(0.5, 0.7)
			_scratch.play()
		if not await _wait(0.16): return
	if not await _wait(0.5): return
	var t := create_tween()
	t.tween_property(calendar, "circle", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	await t.finished
	if not await _wait(1.4): return
	# 3. La frase, poi le altre, sempre più sbiadite.
	for i in ECHOES:
		var label := _label(LINE, PENCIL)
		label.modulate.a = 0.0
		lines.add_child(label)
		if not await _fade(label, echo_alpha(i), 0.9 if i == 0 else 0.5): return
		if not await _wait(1.4 if i == 0 else 0.35): return
	if not await _wait(2.0): return
	# 4. Di nuovo nero, di nuovo bussano. Poi la stanza.
	if not await _fade(black, 1.0, 1.4): return
	if not await _knock_three(): return
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done or not SkipInput.is_skip(event):
		return
	get_viewport().set_input_as_handled()
	if _skip_armed:
		skip()
	else:
		_skip_armed = true
		hint.visible = true


## Salta: al nero (in fretta) e via.
func skip() -> void:
	if _done:
		return
	_done = true
	hint.visible = false
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, 0.4)
	await t.finished
	_leave()


func _finish() -> void:
	if _done:
		return
	_done = true
	black.color.a = 1.0
	_leave()


func _leave() -> void:
	Main.from_opening = true       # la stanza parte col risveglio
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
