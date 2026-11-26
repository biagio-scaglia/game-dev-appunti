extends Area2D
## Un oggetto per terra da raccogliere (es. la mela che lascia un nemico): l'icona di
## ui/item_icons.gd che galleggia piano, un luccichio a intermittenza (così si distingue
## dal fondo: i fiorellini dell'erba non brillano), un'ombra. Lethe ci passa sopra e lo
## prende (`picked`). Dopo un po' lampeggia e sparisce, se nessuno lo prende.
## Fa un po' di luce (`glow`), così si vede anche al buio del dungeon. Con `auto_pick` falso
## non si prende passandoci sopra: si raccoglie parlandoci (la chiave: ha il suo dialogo).
## `wanted` dice se adesso serve (la mela a cuore pieno no): se non serve resta a terra, e
## si prende appena serve, anche se Lethe ci sta già sopra.

signal picked(id: String)

const ItemIcons := preload("res://ui/item_icons.gd")
const DropShadow := preload("res://fx/drop_shadow.gd")
const Glow := preload("res://core/glow.gd")

const LIFETIME := 25.0
const BLINK_FROM := 4.0
const GLINT_EVERY := 1.3

var id := "apple"
## La lucina dell'oggetto (Color(0, 0, 0, 0) = niente).
var glow := Color(1.0, 0.86, 0.55)
## Si prende passandoci sopra (falso: solo parlandoci).
var auto_pick := true
var light: PointLight2D
## Serve adesso? (chi lo lascia per terra lo decide: la zona guarda il cuore)
var wanted := func() -> bool: return true
var sprite: Sprite2D
var _time := 0.0
var _glint: Node2D
var _taken := false


func _init() -> void:
	collision_layer = 0
	collision_mask = 2                          # la protagonista
	monitorable = false


func _ready() -> void:
	var shadow := DropShadow.new()
	shadow.radius = Vector2(6, 2)
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = ItemIcons.icon(id)
	sprite.offset = Vector2(0, -16)
	add_child(sprite)
	if glow.a > 0.0:
		light = Glow.light(glow, 0.7, 34.0)
		light.position = Vector2(0, -16)
		add_child(light)
	_glint = Node2D.new()
	_glint.draw.connect(_draw_glint)
	_glint.position = Vector2(6, -24)
	add_child(_glint)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	shape.position = Vector2(0, -6)
	add_child(shape)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_time += delta
	sprite.position.y = -2.0 + sin(_time * 3.0) * 2.0
	_glint.position.y = -24.0 + sprite.position.y
	_glint.queue_redraw()
	var left := LIFETIME - _time
	if left < BLINK_FROM:
		visible = int(left * 8.0) % 2 == 0
	if left <= 0.0:
		queue_free()
		return
	if monitoring:
		for body in get_overlapping_bodies():   # ci stava sopra quando non serviva
			_on_body(body)


## Il luccichio: una crocetta di luce che si apre e si chiude, ogni GLINT_EVERY secondi.
func glint_amount() -> float:
	var phase := fmod(_time, GLINT_EVERY) / 0.35
	return sin(phase * PI) if phase < 1.0 else 0.0


func _draw_glint() -> void:
	var a := glint_amount()
	if a <= 0.0:
		return
	var arm := roundf(a * 4.0) * 2.0
	var c := Color(1, 1, 1, a)
	_glint.draw_rect(Rect2(-arm, -1, arm * 2.0, 2), c)
	_glint.draw_rect(Rect2(-1, -arm, 2, arm * 2.0), c)


func _on_body(body: Node2D) -> void:
	if _taken or not auto_pick or not body.has_method(&"hurt") or not wanted.call():
		return
	_taken = true
	picked.emit(id)
	queue_free()
