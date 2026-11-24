extends "res://enemies/enemy.gd"
## Il rovo che sussurra (capitolo 1): fermo, un groviglio di rami con una bocca. Quando Lethe
## passa vicino sussurra (e sopra compare una cosa che lei si è detta: le sue bugie), poi
## trema e frusta: per un attimo le spine arrivano lontano. Si vede arrivare: si schiva.
## Debole alla spada (le bugie si tagliano), la magia gli fa poco. Blocca il passaggio.

const SHEET := preload("res://enemies/sprites/bramble.png")
const WHISPER := preload("res://audio/bramble_whisper.wav")
const LASH := preload("res://audio/bramble_lash.wav")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")

## Le cose che Lethe si è detta (e che il rovo le ripete).
const LIES := ["You're fine.", "Nobody noticed.", "Just one more day.", "It doesn't hurt.",
	"Go back to sleep.", "Tomorrow."]

enum State { IDLE, SHIVER, LASH, COOLDOWN }

const NOTICE := 78.0
const SHIVER_TIME := 0.55
const LASH_TIME := 0.35
const COOLDOWN_TIME := 1.4
const REST_RADIUS := 12.0
const LASH_RADIUS := 46.0
const WHISPER_EVERY := 5.0

var state := State.IDLE
var _timer := 0.0
var _whisper_wait := 0.0
var _lie := 0


func _init() -> void:
	super()
	collision_layer = ENEMY_LAYER | 1          # blocca anche il passaggio (livello "mondo")


func _ready() -> void:
	super()
	max_hp = 4
	hp = max_hp
	weakness = {&"sword": 1.5, &"magic": 0.5}
	exp_reward = 4
	drop_chance = 0.4
	make_sprite(SHEET, 3, -10.0, false)
	make_body(16.0, Vector2(0, -10))
	hurt_shape.radius = REST_RADIUS
	bar_height = 44.0
	_lie = randi() % LIES.size()


func behave(delta: float) -> void:
	_timer -= delta
	_whisper_wait -= delta
	match state:
		State.IDLE:
			sprite.frame = 0
			if sees_target(NOTICE):
				_whisper()
				_go(State.SHIVER, SHIVER_TIME)
		State.SHIVER:
			sprite.frame = 1
			sprite.position.x = (1.0 if int(_anim_time * 30.0) % 2 == 0 else -1.0)
			if _timer <= 0.0:
				sprite.position.x = 0.0
				_go(State.LASH, LASH_TIME)
				hurtful = true
				hurt_shape.radius = LASH_RADIUS
				if sound:
					Sfx.play(get_parent(), LASH, randf_range(0.95, 1.05), -2.0)
		State.LASH:
			sprite.frame = 2
			if _timer <= 0.0:
				hurtful = false
				hurt_shape.radius = REST_RADIUS
				_go(State.COOLDOWN, COOLDOWN_TIME)
		State.COOLDOWN:
			sprite.frame = 0
			if _timer <= 0.0:
				_go(State.IDLE, 0.0)


func _go(next: State, time: float) -> void:
	state = next
	_timer = time


## Sussurra: il suono, e sopra il rovo una bugia di Lethe che sale e si spegne.
func _whisper() -> void:
	if _whisper_wait > 0.0:
		return
	_whisper_wait = WHISPER_EVERY
	if sound:
		Sfx.play(get_parent(), WHISPER, randf_range(0.9, 1.05), -8.0)
	var label := Label.new()
	label.text = LIES[_lie]
	_lie = (_lie + 1) % LIES.size()
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", Color(0.78, 0.66, 0.9, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 20)
	label.position = Vector2(-80, -100)       # sopra la barretta e i numeri del danno
	label.z_index = 5
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", -120.0, 1.8)
	t.parallel().tween_property(label, "modulate:a", 0.0, 1.8).set_delay(0.6)
	t.tween_callback(label.queue_free)


## Colpito mentre frusta o trema: si ritira (la frusta si ferma, ricomincia da capo).
func on_hurt(_kind: StringName) -> void:
	if state in [State.SHIVER, State.LASH]:
		hurtful = false
		hurt_shape.radius = REST_RADIUS
		sprite.position.x = 0.0
		_go(State.COOLDOWN, COOLDOWN_TIME)


func last_lie() -> String:
	return LIES[(_lie - 1 + LIES.size()) % LIES.size()]
