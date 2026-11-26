extends Control
## La luce di Lethe (gli MP), sopra i cuori: una fila di piccole lune. La magia la spende, e
## la luce torna (forest/zone_light.gd): piano da sola, in fretta vicino a una luce, tutta
## riposando, un po' a ogni verità. Disegnata a blocchi come i cuori: niente immagini.
## - Una luna che torna piena si accende con un lampo e un salto.
## - Una luna spesa si svuota con un piccolo soffio di pulviscolo.
## - Senza luce abbastanza per l'incantesimo, la fila trema (deny()).
## Finché Lethe non ha un incantesimo che costa luce la fila non c'è.

## Uno spicchio, 7 x 7: O contorno, h luna.
const SHAPE := [
	"..OOO..",
	".OhhO..",
	"OhhO...",
	"OhO....",
	"OhhO...",
	".OhhO..",
	"..OOO..",
]
const PX := 2
const GAP := 2
const FULL := {"O": Color(0.42, 0.48, 0.9), "h": Color(0.9, 0.92, 1.0)}
const EMPTY := {"O": Color(0.32, 0.29, 0.46), "h": Color(0.09, 0.07, 0.13)}
const SHADOW := Color(0, 0, 0, 0.45)


class Moon extends Node2D:
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
					var color: Color = (FULL if full else EMPTY)[c]
					if flash > 0.0:
						color = color.lerp(Color.WHITE, flash)
					draw_rect(Rect2(at, Vector2(PX, PX)), color)


var moons: Array[Moon] = []
var light := 0
var light_max := 0
var _shown_once := false


static func moon_size() -> Vector2:
	return Vector2(SHAPE[0].length(), SHAPE.size()) * PX


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_light(now: int, total: int) -> void:
	var animate := _shown_once
	_shown_once = true
	light = now
	if total != light_max or moons.size() != total:
		light_max = total
		_rebuild()
	for i in moons.size():
		var moon := moons[i]
		var full := i < light
		if moon.full == full:
			continue
		moon.full = full
		moon.queue_redraw()
		if animate:
			if full:
				_pop(moon)
			else:
				_puff(moon)


## Non basta: la fila trema un attimo.
func deny() -> void:
	var t := create_tween()
	var x := position.x
	for dx in [-3.0, 3.0, -2.0, 0.0]:
		t.tween_property(self, "position:x", x + dx, 0.04)


func _rebuild() -> void:
	for moon in moons:
		moon.queue_free()
	moons.clear()
	var cell := moon_size()
	for i in light_max:
		var moon := Moon.new()
		moon.full = i < light
		moon.position = Vector2(i * (cell.x + GAP), 0) + cell / 2.0
		add_child(moon)
		moons.append(moon)
	size = Vector2(light_max * (cell.x + GAP) - GAP, cell.y)


func _pop(moon: Moon) -> void:
	moon.scale = Vector2(1.5, 1.5)
	moon.flash = 1.0
	var t := moon.create_tween().set_parallel()
	t.tween_property(moon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(moon, "flash", 0.0, 0.35)


func _puff(moon: Moon) -> void:
	moon.flash = 0.6
	moon.create_tween().tween_property(moon, "flash", 0.0, 0.2)
	var dust := CPUParticles2D.new()
	dust.amount = 5
	dust.lifetime = 0.5
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.direction = Vector2.UP
	dust.spread = 60.0
	dust.gravity = Vector2(0, -20)
	dust.initial_velocity_min = 15.0
	dust.initial_velocity_max = 35.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, FULL["h"])
	ramp.set_color(1, Color(FULL["O"], 0.0))
	dust.color_ramp = ramp
	dust.position = moon.position
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)
