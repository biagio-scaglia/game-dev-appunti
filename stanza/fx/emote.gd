extends Node2D
## La nuvoletta sopra la testa (come nei vecchi RPG): "!" sorpresa, "?" dubbio, "..."
## silenzio, "<3" (un cuoricino) affetto. Salta fuori con un rimbalzo, resta un attimo,
## svanisce. Disegnata qui: un riquadro chiaro col bordo scuro e la punta in basso.
##
## Uso: Emote.pop(chi, "!")   (si attacca a chi, sopra la testa)

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const FILL := Color(0.95, 0.93, 1.0)
const EDGE := Color(0.16, 0.1, 0.24)
const INK := {"!": Color(0.85, 0.25, 0.35), "?": Color(0.35, 0.3, 0.7), "...": Color(0.3, 0.26, 0.4),
	"<3": Color(0.9, 0.35, 0.5)}
const STAY := 1.1

var kind := "!"


static func pop(actor: Node2D, what: String, height := 62.0) -> Node2D:
	var bubble: Node2D = load("res://fx/emote.gd").new()
	bubble.kind = what
	bubble.position = Vector2(10, -height)
	bubble.z_index = 20
	actor.add_child(bubble)
	return bubble


func _ready() -> void:
	scale = Vector2(0.2, 0.2)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(STAY)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)


func _draw() -> void:
	var w := 22.0 if kind == "..." else 16.0
	var box := Rect2(-w / 2.0, -18, w, 16)
	draw_rect(box.grow(1), EDGE)
	draw_rect(box, FILL)
	for i in 3:                                         # la punta, a gradini
		draw_rect(Rect2(-3 + i, -2 + i, 6 - i * 2, 1), EDGE if i == 2 else FILL)
	draw_rect(Rect2(-4, -2, 1, 1), EDGE)
	draw_rect(Rect2(3, -2, 1, 1), EDGE)
	var color: Color = INK.get(kind, EDGE)
	if kind == "<3":
		_draw_heart(Vector2(-3, -14), color)
		return
	var size := FONT.get_string_size(kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(FONT, Vector2(-size.x / 2.0, -5), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


## Il cuoricino (il font pixel non ha il carattere del cuore).
func _draw_heart(at: Vector2, color: Color) -> void:
	var rows := [".xx.xx.", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "x":
				draw_rect(Rect2(at + Vector2(x - 0.5, y), Vector2(1, 1)), color)
