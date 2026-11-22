extends Node2D
## Ombra sotto i piedi: un'ellisse scura e semitrasparente, disegnata in codice.
## Va messa come primo figlio del personaggio (così sta sotto lo sprite), con
## l'origine sui piedi. Non dipende dagli sprite: vale per ogni animazione.
## È fatta a blocchi di `pixel` come gli sprite (ingranditi 2x), non a bordi lisci.

@export var radius := Vector2(10, 4):
	set(value):
		radius = value
		queue_redraw()
@export var color := Color(0.04, 0.02, 0.07, 0.5):
	set(value):
		color = value
		queue_redraw()
## Lato di un "pixel" dello sprite, in pixel dello schermo di gioco.
@export var pixel := 2:
	set(value):
		pixel = value
		queue_redraw()


func _draw() -> void:
	for row in rows(radius, pixel):
		draw_rect(row, color)


## Le righe dell'ellisse attorno all'origine, allineate alla griglia `px`:
## una striscia alta `px` per riga, larga quanto l'ellisse a quell'altezza.
static func rows(r: Vector2, px: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var y := -r.y
	while y < r.y:
		var mid := (y + px / 2.0) / r.y                   # centro della striscia, da -1 a 1
		var half := r.x * sqrt(maxf(0.0, 1.0 - mid * mid))
		half = maxf(px, snappedf(half, px))
		out.append(Rect2(-half, y, half * 2.0, px))
		y += px
	return out
