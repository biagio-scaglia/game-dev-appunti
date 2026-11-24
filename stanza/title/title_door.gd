extends Node2D
## La porta del titolo: la porta della stanza di Lethe, sola nel buio, con la luce calda che
## passa sotto e si allarga sul pavimento, e il vassoio intatto davanti. Ogni tanto qualcuno
## bussa: tre colpi piano, la porta trema di un pixel, sotto compare l'ombra di due piedi
## che poi se ne va. È la scena del finale (Trama - bozza, nel vault): la luna da una parte,
## la porta dall'altra.
##
## L'origine del nodo è al centro della soglia (dove la porta tocca terra). I disegni sono
## quelli della stanza (room_tiles.png), a grandezza vera.

signal knocked

const Tiles := preload("res://world/room_tileset.gd")
const KNOCK := preload("res://audio/menu_knock.wav")
const Glow := preload("res://core/glow.gd")

## Dopo quanto bussa la prima volta e ogni quanto ribussa (a caso nell'intervallo).
@export var first_knock := 6.0
@export var knock_every := Vector2(14.0, 22.0)
@export var knock_db := -12.0
@export var knock_seed := 5
## Spento finché il titolo non è comparso (e nei test).
@export var knocking_enabled := false
## Falso nei test: niente suono.
@export var sound := true

const LIGHT := Color(1.0, 0.8, 0.52)
const SHADOW := Color(0.06, 0.04, 0.08)
## La striscia sotto la porta e i due piedi (pixel, rispetto alla soglia).
const STRIP := Rect2(-12, -2, 24, 2)
const FEET := [Rect2(-7, -2, 4, 2), Rect2(3, -2, 4, 2)]
## La luce sul pavimento: righe di blocchi da 2, sempre più larghe e più deboli, sommate
## (blend additivo) a quello che c'è sotto, più un alone morbido intorno alla soglia.
const SPILL_ROWS := 10
const SPILL_ALPHA := 0.22
const HALO := Rect2(-44, -14, 88, 36)
const HALO_ALPHA := 0.35
## Il vassoio: davanti alla porta, un po' a sinistra (centro del disegno).
const TRAY_AT := Vector2(24, 10)
## Della casella della porta si prende solo la porta (senza il muro intorno).
const DOOR_CROP := Rect2(4, 8, 24, 56)
## Quanto restano i piedi dopo l'ultimo colpo.
const FEET_STAY := 2.5

var feet := false:
	set(value):
		feet = value
		queue_redraw()

var _door: AtlasTexture
var _tray: AtlasTexture
var _rng := RandomNumberGenerator.new()
var _wait := 0.0
var _shake := 0.0
var _time := 0.0
var _player: AudioStreamPlayer
var _spill: Node2D
var _halo: GradientTexture2D


func _ready() -> void:
	var data := Tiles.load_data()
	_door = _tile(data, "door")
	_door.region = Rect2(_door.region.position + DOOR_CROP.position, DOOR_CROP.size)
	_tray = _tile(data, "food_tray")
	_rng.seed = knock_seed
	_wait = first_knock
	_player = AudioStreamPlayer.new()
	_player.stream = KNOCK
	_player.volume_db = knock_db
	add_child(_player)
	# La luce si somma al buio: un figlio col blend additivo, disegnato sopra porta e vassoio.
	_spill = Node2D.new()
	_spill.material = CanvasItemMaterial.new()
	_spill.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spill.draw.connect(_draw_spill)
	add_child(_spill)
	_halo = Glow._soft_texture()


static func _tile(data: Dictionary, id: String) -> AtlasTexture:
	var tile: Dictionary = data["tiles"][id]
	var size := int(data["tile"])
	var texture := AtlasTexture.new()
	texture.atlas = Tiles.ATLAS
	texture.region = Rect2(Vector2(tile["atlas"][0], tile["atlas"][1]) * size,
		Vector2(tile["size"][0], tile["size"][1]) * size)
	return texture


## Il prossimo intervallo tra due colpi, nei limiti di `every`.
static func next_gap(rng: RandomNumberGenerator, every: Vector2) -> float:
	return rng.randf_range(every.x, every.y)


## Quanto brilla la luce sotto la porta (respira appena: qualcuno si muove di là), 0.8 - 1.
static func light_level(time: float) -> float:
	return 0.9 + 0.1 * sin(time * 1.3) * sin(time * 0.47 + 1.1)


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(_shake - delta, 0.0)
	if knocking_enabled:
		_wait -= delta
		if _wait <= 0.0:
			knock()
	queue_redraw()
	_spill.queue_redraw()


## Tre colpi piano: il suono, la porta che trema, i piedi sotto la porta che poi se ne vanno.
func knock() -> void:
	_wait = next_gap(_rng, knock_every)
	feet = true
	if sound and is_inside_tree():
		_player.play()
	var t := create_tween()
	for i in 3:
		t.tween_callback(func() -> void: _shake = 0.08)
		t.tween_interval(0.28)
	t.tween_interval(FEET_STAY)
	t.tween_callback(func() -> void: feet = false)
	knocked.emit()


func _draw_spill() -> void:
	var light := light_level(_time)
	_spill.draw_texture_rect(_halo, HALO, false, Color(LIGHT, HALO_ALPHA * light))
	# La luce sul pavimento, a blocchi: si allarga verso chi guarda e si spegne.
	for row in SPILL_ROWS:
		var half := 12 + row * 3
		var a := SPILL_ALPHA * light * (1.0 - float(row) / SPILL_ROWS)
		_spill.draw_rect(Rect2(-half, row * 2, half * 2, 2), Color(LIGHT, a))


func _draw() -> void:
	var light := light_level(_time)
	var jolt := Vector2(1, 0) if _shake > 0.0 else Vector2.ZERO
	if _door:
		draw_texture(_door, Vector2(-_door.get_width() / 2.0, -_door.get_height()) + jolt)
	draw_rect(STRIP, Color(LIGHT, light))
	if feet:
		for f: Rect2 in FEET:
			draw_rect(f, SHADOW)
	if _tray:
		draw_texture(_tray, TRAY_AT - _tray.get_size() / 2.0)
