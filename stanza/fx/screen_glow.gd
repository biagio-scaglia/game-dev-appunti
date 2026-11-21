extends Node2D
## Lo schermo del PC acceso: un velo azzurro in blend additivo sopra lo schermo
## disegnato nel tile, che tremola, più una riga di scansione che scende in loop.

@export var rect := Rect2(0, 0, 36, 20)
@export var color := Color(0.55, 0.9, 1.0)
@export var base_alpha := 0.16
@export var scan_speed := 14.0        # pixel al secondo della riga di scansione

var _time := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 2


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(rect, Color(color, alpha_at(_time)))
	var y := rect.position.y + fmod(_time * scan_speed, rect.size.y)
	draw_rect(Rect2(rect.position.x, floorf(y), rect.size.x, 1), Color(color, base_alpha * 1.8))


## Trasparenza del velo al tempo t: tremolio veloce, sempre tra 0 e 2*base_alpha.
func alpha_at(t: float) -> float:
	var flicker := 0.6 * sin(t * 31.0) + 0.4 * sin(t * 47.0 + 1.1)
	return clampf(base_alpha * (1.0 + 0.5 * flicker), 0.0, base_alpha * 2.0)
