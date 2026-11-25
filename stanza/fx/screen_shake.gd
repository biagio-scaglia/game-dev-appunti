extends Node
## Un piccolo tremolio dello schermo (l'impatto si sente). Sposta la vista del mondo
## (canvas_transform del viewport) di pochi pixel interi a caso, sempre meno, poi la
## rimette a posto e sparisce. L'interfaccia nei CanvasLayer non trema.
##
## Uso: var s := ScreenShake.new(); s.strength = 2.0; get_tree().root.add_child(s)
## Se ne parte un altro mentre questo trema, il nuovo prende il suo posto (e la sua
## posizione di riposo), così la vista torna sempre dov'era.

const Settings := preload("res://core/settings_store.gd")

var strength := 2.0
var duration := 0.18
var _time := 0.0
var _base: Transform2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if not bool(Settings.value("shake")):      # tolto nelle impostazioni
		queue_free()
		return
	_base = get_viewport().canvas_transform
	for other in get_tree().get_nodes_in_group(&"screen_shake"):
		_base = other._base                # la vera posizione di riposo
		other.queue_free()
		other.set_process(false)
	add_to_group(&"screen_shake")


## Lo spostamento al tempo t: pixel interi, sempre più piccolo fino a zero.
static func offset_at(t: float, total: float, power: float, rng: RandomNumberGenerator) -> Vector2:
	var left := clampf(1.0 - t / total, 0.0, 1.0)
	var amount := power * left * left
	return Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)).round()


func _process(delta: float) -> void:
	_time += delta
	var viewport := get_viewport()
	if _time >= duration:
		viewport.canvas_transform = _base
		queue_free()
		return
	var t := _base
	t.origin += offset_at(_time, duration, strength, _rng)
	viewport.canvas_transform = t
