extends Node
## Mentre il menu è aperto, ogni tanto un oggetto della stanza fa rumore da solo: bussano
## alla porta, il telefono vibra, lo specchio si incrina, il carillon suona tre note,
## l'orologio si ferma. Piano, e mai lo stesso due volte di fila.
## Solo le cose che ci sono dove sta Lethe (use_place): nella foresta la porta, il telefono,
## il carillon e l'orologio non ci sono, resta lo specchio.
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
## Quali suoni ci sono in ogni posto (state.place). Un posto che manca: tutti.
const PLACE_SOUNDS := {
	"The Forest": [&"glass"],
}
const MIN_WAIT := 8.0
const MAX_WAIT := 20.0
const VOLUME_DB := -12.0

var rng := RandomNumberGenerator.new()
var running := false
var _wait := 0.0
var _last := &""
## I suoni del posto dove sta Lethe.
var kinds: Array = SOUNDS.keys()


func use_place(place: String) -> void:
	kinds = PLACE_SOUNDS.get(place, SOUNDS.keys())


## C'è questo suono, qui? (le reazioni del menu lo chiedono prima di usarlo)
func has_sound(kind: StringName) -> bool:
	return kind in kinds


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
	var choices := kinds.filter(func(k): return k != _last)
	if choices.is_empty():
		choices = kinds                 # un solo suono: si ripete, pazienza
	var kind: StringName = choices[rng.randi() % choices.size()]
	play(kind)
	return kind


func play(kind: StringName, db := VOLUME_DB) -> void:
	_last = kind
	Sfx.play(self, SOUNDS[kind], rng.randf_range(0.9, 1.05), db)
	played.emit(kind)
