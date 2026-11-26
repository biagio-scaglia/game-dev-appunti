extends Area2D
## Una fiammella della veglia (magic/vigil.gd): una fiamma piccola di verità, viola e bianca,
## disegnata qui a blocchi (niente immagini) e mossa da chi la tiene. Finché `flying` è falso
## la sposta la veglia (gira attorno a Lethe); lanciata, vola con `velocity` e piega un po'
## verso `target` se c'è. Tocca i nemici (fa male, `damage`) e si spegne; si spegne anche
## contro un muro o dopo `max_distance`. Come il proiettile, attira le falene (gruppo "lure")
## e accende le lanterne (light_catch.gd).

signal gone

const Glow := preload("res://core/glow.gd")
const Sparks := preload("res://fx/sparks.gd")
const LightCatch := preload("light_catch.gd")

## La fiamma, 5 x 7: o bordo viola, v viola, w bianco (due fotogrammi: la punta si piega).
const SHAPES := [
	["..o..", ".ovo.", ".ovo.", "ovwvo", "ovwvo", "ovwvo", ".ooo."],
	[".o...", ".oo..", ".ovo.", "ovwvo", "ovwvo", "ovwvo", ".ooo."],
]
const COLORS := {"o": Color(0.5, 0.3, 0.9), "v": Color(0.8, 0.62, 1.0), "w": Color(1.0, 0.96, 1.0)}
const PX := 2
## Quanto piega verso il bersaglio (radianti al secondo).
const TURN := 7.0

var damage := 2
var flying := false
var velocity := Vector2.ZERO
var target: Node2D
var max_distance := 300.0
var travelled := 0.0
var _time := 0.0
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 5                           # il mondo e i nemici, come il proiettile
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	add_child(Glow.light(Color(0.72, 0.5, 1.0), 0.32, 34.0))   # piccola: sono quattro, sommate
	add_to_group(&"lure")
	body_entered.connect(_on_body)
	var mat := CanvasItemMaterial.new()            # è luce: il buio della zona non la spegne
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat



## Parte verso `direction` (normalizzata) a `speed` pixel al secondo.
func launch(direction: Vector2, speed: float) -> void:
	flying = true
	z_index = 5                                  # in volo sta sopra le cose: è luce
	velocity = direction * speed


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not flying or _done:
		return
	if is_instance_valid(target) and not target.get(&"dead"):
		var to := target.global_position + Vector2(0, -12) - global_position
		var turn := clampf(velocity.angle_to(to), -TURN * delta, TURN * delta)
		velocity = velocity.rotated(turn)
	var step := velocity * delta
	position += step
	travelled += step.length()
	LightCatch.touch(get_tree(), global_position)
	if travelled >= max_distance:
		burn_out()


func _on_body(body: Node2D) -> void:
	if _done:
		return
	if body.is_in_group(&"enemies"):
		body.hurt(damage, &"magic", global_position)
		burn_out()
	elif flying:
		burn_out()                               # contro un muro: mentre gira, i muri non contano


## Si spegne in un piccolo sbuffo di scintille (che resta nel mondo e finisce da solo).
func burn_out() -> void:
	if _done:
		return
	_done = true
	LightCatch.touch(get_tree(), global_position)
	var parent := get_parent()
	if parent and is_inside_tree():
		var puff := Sparks.burst(8)
		parent.add_child(puff)
		puff.global_position = global_position
		puff.emitting = true
		get_tree().create_timer(puff.lifetime + 0.1).timeout.connect(puff.queue_free)
	gone.emit()
	queue_free()


func _draw() -> void:
	var shape: Array = SHAPES[int(_time * 10.0) % 2]
	var origin := Vector2(-2.5, -5.0) * PX
	# In volo la punta resta indietro, come una cometa (la forma punta in su).
	draw_set_transform(Vector2.ZERO, velocity.angle() - PI / 2.0 if flying else 0.0)
	for y in shape.size():
		var row: String = shape[y]
		for x in row.length():
			if row[x] != ".":
				draw_rect(Rect2(origin + Vector2(x, y) * PX, Vector2(PX, PX)), COLORS[row[x]])
