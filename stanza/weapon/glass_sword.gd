extends Node2D
## Un fendente della spada di vetro dello specchio. Ogni bugia ne stacca una scheggia:
## lo stadio (0 scheggia, 1 pugnale, 2 lama) dice quanto è lunga e incrinata, e quanto
## lontano colpisce. La lama compare dalla mano, luccica di luna, fende verso
## `direction` e si sbriciola in schegge che cadono. L'origine del nodo è la mano.
##
## Colpisce i corpi del livello "nemici" mentre la lama passa (fotogrammi 1-3): quelli già
## nella zona quando arriva e quelli che entrano mentre passa, ognuno una volta (segnale hit).

signal hit(body: Node2D)

const SwordFrames := preload("sword_frames.gd")
const Glow := preload("../core/glow.gd")
const Sparks := preload("../fx/sparks.gd")
const ScreenShake := preload("../fx/screen_shake.gd")

## Fotogrammi in cui la lama taglia.
const STRIKE_FRAMES := Vector2i(1, 3)
## Raggio della zona colpita, per stadio (cresce con la lama). Generoso: si deve sentire che
## la lama prende quello che si vede toccare.
const REACH := [24.0, 28.0, 32.0]
## Luce fredda: la lama riflette la luna.
const LIGHT_COLOR := Color(0.72, 0.84, 1.0)

@export_range(0, 2) var stage := 0
var direction := Vector2.RIGHT

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var shape: CollisionShape2D = $Hitbox/Shape
@onready var sfx: AudioStreamPlayer = $Sfx

var light: PointLight2D
var _striking := false
var _already_hit := {}


func _ready() -> void:
	var dir := direction.normalized()
	sprite.sprite_frames = SwordFrames.build()
	sprite.offset = SwordFrames.PIVOT_OFFSET
	sprite.rotation = dir.angle()
	sprite.flip_v = dir.x < 0                   # verso sinistra il fendente scende lo stesso dall'alto
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(func(): sprite.visible = false)
	sprite.play(SwordFrames.animation(stage))
	(shape.shape as CircleShape2D).radius = REACH[stage]   # la forma è locale: ogni spada ha la sua
	shape.position = dir * REACH[stage] * 0.7
	hitbox.body_entered.connect(func(body): if _striking: _hit(body))
	light = Glow.light(LIGHT_COLOR, 0.5 + 0.2 * stage, 40.0 + 10.0 * stage)
	add_child(light)
	create_tween().tween_property(light, "energy", 0.0, SwordFrames.duration())
	sfx.play()
	get_tree().create_timer(maxf(SwordFrames.duration(), sfx.stream.get_length())).timeout.connect(queue_free)


func is_striking() -> bool:
	return _striking


func _hit(body: Node2D) -> void:
	if not _already_hit.has(body):
		_already_hit[body] = true
		hit.emit(body)


func _on_frame_changed() -> void:
	var striking := sprite.frame >= STRIKE_FRAMES.x and sprite.frame <= STRIKE_FRAMES.y
	if striking and not _striking:              # la lama arriva: chi è già nella zona
		for body in hitbox.get_overlapping_bodies():
			_hit(body)
	_striking = striking
	if sprite.frame == STRIKE_FRAMES.y:          # il colpo arriva in fondo: schegge e un tremolio
		var shards := Sparks.shards(6 + 4 * stage)
		shards.position = direction.normalized() * REACH[stage] * 0.7
		add_child(shards)
		shards.emitting = true
		var shaker := ScreenShake.new()
		shaker.strength = 1.0 + stage * 0.5
		get_tree().root.add_child(shaker)
