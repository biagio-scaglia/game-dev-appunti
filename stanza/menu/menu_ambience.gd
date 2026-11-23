extends Node
## Mentre il menu è aperto, ogni tanto un oggetto della stanza fa rumore da solo: bussano
## alla porta, il telefono vibra, lo specchio si incrina, il carillon suona tre note,
## l'orologio si ferma. Piano, e mai lo stesso due volte di fila.
## I suoni li fa tools/audio/make_menu_sfx.py (in locale).

signal played(kind: StringName)

const Sfx := preload("res://core/sfx.gd")
const SOUNDS := {
	&"knock": preload("res://audio/menu_knock.wav"),
	&"phone": preload("res://audio/menu_phone.wav"),
	&"glass": preload("res://audio/menu_glass.wav"),
	&"music_box": preload("res://audio/menu_music_box.wav"),
	&"clock": preload("res://audio/menu_clock.wav"),
}
const MIN_WAIT := 8.0
const MAX_WAIT := 20.0
const VOLUME_DB := -12.0

var rng := RandomNumberGenerator.new()
var running := false
var _wait := 0.0
var _last := &""


func start() -> void:
	running = true
	_wait = rng.randf_range(MIN_WAIT * 0.5, MAX_WAIT * 0.6)   # il primo arriva prima


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	if not running:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = rng.randf_range(MIN_WAIT, MAX_WAIT)
	play_random()


func play_random() -> StringName:
	var kinds := SOUNDS.keys().filter(func(k): return k != _last)
	var kind: StringName = kinds[rng.randi() % kinds.size()]
	play(kind)
	return kind


func play(kind: StringName, db := VOLUME_DB) -> void:
	_last = kind
	Sfx.play(self, SOUNDS[kind], rng.randf_range(0.9, 1.05), db)
	played.emit(kind)
