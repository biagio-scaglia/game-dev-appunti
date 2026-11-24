extends Node2D
## Bussano alla porta. Dopo `first_delay` secondi nella stanza qualcuno bussa: si sente il
## colpo (più forte vicino alla porta), lo schermo trema appena e sotto la porta compare una
## striscia di luce con l'ombra di due piedi. Bussa ancora ogni `series_gap` secondi; dopo
## `max_series` volte se ne va (i piedi spariscono, poi la luce). Se Lethe va alla porta,
## il dialogo della porta è un altro (vedi stanza.dialogue, cue "door"): lì `knocking` è vero
## e answer() chiude l'evento. Succede una volta sola.
##
## Mentre un dialogo è aperto (o il gioco è in pausa) il tempo qui si ferma.

signal started
signal knocked(series: int)
## `answered`: Lethe è andata alla porta (vero) o li ha lasciati andare via (falso).
signal ended(answered: bool)

const KNOCK := preload("res://audio/menu_knock.wav")
const Glow := preload("res://core/glow.gd")
const ScreenShake := preload("res://fx/screen_shake.gd")
const RoomThings := preload("res://world/room_things.gd")

## Dopo quanto bussano la prima volta, ogni quanto ribussano, quante volte prima di andarsene.
@export var first_delay := 35.0
@export var series_gap := 6.0
@export var max_series := 4
@export var knock_db := -4.0

## La striscia di luce sotto la porta e i piedi (pixel, rispetto al centro della soglia).
const STRIP := Rect2(-12, 0, 24, 2)
const FEET := [Rect2(-7, 0, 4, 2), Rect2(3, 0, 4, 2)]
const LIGHT_COLOR := Color(1.0, 0.8, 0.52)
const SHADOW_COLOR := Color(0.06, 0.04, 0.08)
const GLOW_ENERGY := 0.5
const GLOW_RADIUS := 28.0
const FADE_SECONDS := 0.8
const FEET_LEAVE_SECONDS := 0.9

## Qualcuno è alla porta (lo leggono i dialoghi).
var knocking := false
## È già successo (risposto o andati via): non succede più.
var knock_over := false
## Quante volte ha bussato.
var series := 0
## Per non dover sapere chi parla: vero quando il tempo deve stare fermo.
var is_busy := func() -> bool: return false
## Muto per i test.
var sound := true

var light_amount := 0.0:
	set(value):
		light_amount = value
		if _glow:
			_glow.energy = GLOW_ENERGY * value
		queue_redraw()
var feet := false:
	set(value):
		feet = value
		queue_redraw()

var _wait := 0.0
var _glow: PointLight2D
var _player: AudioStreamPlayer2D
var _fade: Tween


func _ready() -> void:
	z_index = -1          # sul pavimento, sotto i mobili e Lethe
	_wait = first_delay
	_glow = Glow.light(LIGHT_COLOR, 0.0, GLOW_RADIUS)
	_glow.position = Vector2(0, 6)
	add_child(_glow)
	_player = AudioStreamPlayer2D.new()
	_player.stream = KNOCK
	_player.volume_db = knock_db
	_player.attenuation = 0.6
	_player.max_distance = 900.0
	add_child(_player)


## Si mette sulla soglia della porta della stanza.
func setup(room: Node2D) -> void:
	var things := RoomThings.build(room.data, PackedStringArray(["door"]))
	var door := RoomThings.rect_of(things, "door")
	position = room.position + Vector2(door.get_center().x, door.end.y)


func _process(delta: float) -> void:
	if not is_busy.call():
		tick(delta)


## Fa passare il tempo dell'evento (pubblica: la usano i test).
func tick(delta: float) -> void:
	if knock_over:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if knocking and series >= max_series:
		_leave(false)
		return
	if not knocking:
		knocking = true
		feet = true
		_fade_light(1.0)
		started.emit()
	knock()


## Fa bussare presto (fra al massimo `seconds`), se non è ancora successo: lo usa il
## prologo quando Lethe ha già guardato tutto, così non resta ad aspettare.
func hurry(seconds := 3.0) -> void:
	if not knocking and not knock_over:
		_wait = minf(_wait, seconds)


## Un colpo alla porta: il suono, un piccolo tremolio, la luce che sobbalza.
func knock() -> void:
	series += 1
	_wait = series_gap
	if sound:
		_player.pitch_scale = randf_range(0.92, 1.0)
		_player.play()
	var shake := ScreenShake.new()
	shake.strength = 1.0
	shake.duration = 0.12
	get_tree().root.add_child(shake)
	knocked.emit(series)


## Lethe ha risposto (o è rimasta zitta davanti alla porta): chi bussava se ne va.
## La chiama il dialogo della porta.
func answer() -> void:
	if knocking:
		_leave(true)


func _leave(answered: bool) -> void:
	if _fade:
		_fade.kill()
	knocking = false
	knock_over = true
	_fade = create_tween()
	_fade.tween_interval(FEET_LEAVE_SECONDS)
	_fade.tween_callback(func() -> void: feet = false)    # i passi che si allontanano
	_fade.tween_property(self, "light_amount", 0.0, FADE_SECONDS)
	ended.emit(answered)


func _fade_light(to: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "light_amount", to, FADE_SECONDS)


func _draw() -> void:
	if light_amount <= 0.0:
		return
	draw_rect(STRIP, Color(LIGHT_COLOR, light_amount))
	if feet:
		for f: Rect2 in FEET:
			draw_rect(f, Color(SHADOW_COLOR, light_amount))
