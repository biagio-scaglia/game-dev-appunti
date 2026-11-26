extends Node2D
## Un fuoco piccolo e vivo (le lanterne di radice del dungeon): la fiamma disegnata qui a
## blocchi, quattro fotogrammi che si alternano non sempre nello stesso ordine (un fuoco non
## ripete), le braci che salgono e si spengono, e il crepitio vicino (AudioStreamPlayer2D,
## si sente solo avvicinandosi). Il buio della zona non la spegne (unshaded): è luce.
## L'origine è la base della fiamma.
## ignite(): il fuoco che prende, una vampata (la fiamma cresce di colpo e torna) con un
## soffio e uno scoppio di braci.

const Sfx := preload("res://core/sfx.gd")
const CRACKLE := preload("res://audio/fire_crackle.wav")
const IGNITE := preload("res://audio/lantern_ignite.wav")

## r punta rossa, o arancio, y giallo, w cuore bianco. 7 x 9.
const FRAMES := [
	["...r...", "..oo...", "..ooo..", ".ooyo..", ".oyyoo.", ".oyyyo.", "ooywyoo", ".oywyo.", "..ooo.."],
	["....r..", "...oo..", "..ooo..", "..oyoo.", ".ooyyo.", ".oyyyo.", "ooywyoo", ".oywyo.", "..ooo.."],
	["...r...", "...o...", "..ooo..", "..oyo..", ".ooyoo.", ".oyyyo.", ".oywyo.", "ooywyoo", "..ooo.."],
	[".......", "..r....", "..oo...", ".ooyo..", ".oyyoo.", ".oyyyo.", "ooywyoo", ".oywyo.", "..ooo.."],
]
const COLORS := {"r": Color(0.72, 0.24, 0.16), "o": Color(0.95, 0.5, 0.2), "y": Color(1.0, 0.8, 0.4),
	"w": Color(1.0, 0.97, 0.86)}
const PX := 2
## Fotogrammi al secondo (un po' a caso intorno).
const FPS := 9.0

## Falso nei test: niente crepitio.
var sound := true
var _frame := 0
var _next := 0.0
var _flare := 0.0
var _embers: CPUParticles2D
var _crackle: AudioStreamPlayer2D


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_embers = _make_embers()
	add_child(_embers)
	if sound:
		_crackle = AudioStreamPlayer2D.new()
		var stream: AudioStreamWAV = CRACKLE.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_crackle.stream = stream
		_crackle.volume_db = -13.0
		_crackle.max_distance = 260.0
		_crackle.attenuation = 1.6
		add_child(_crackle)
		_crackle.play(randf() * stream.get_length())      # due lanterne non crepitano insieme


## La fiamma prende: vampata, soffio, braci.
func ignite() -> void:
	_flare = 1.0
	if sound:
		Sfx.play(self, IGNITE, randf_range(0.95, 1.08), -4.0)
	var burst := _make_embers()
	burst.amount = 14
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 70.0
	burst.spread = 70.0
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(burst.lifetime + 0.2).timeout.connect(burst.queue_free)


func frame() -> int:
	return _frame


func _process(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		var choices := range(FRAMES.size())
		choices.erase(_frame)
		_frame = choices[randi() % choices.size()]
		_next = randf_range(0.7, 1.3) / FPS
		queue_redraw()
	if _flare > 0.0:
		_flare = move_toward(_flare, 0.0, delta * 2.2)
		queue_redraw()


func _draw() -> void:
	var rows: Array = FRAMES[_frame]
	var scale_y := 1.0 + _flare * 0.8                     # la vampata: più alta
	var px := Vector2(PX, PX * scale_y)
	var origin := Vector2(-3.5 * PX, -rows.size() * px.y)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != ".":
				var col: Color = COLORS[row[x]]
				if _flare > 0.0:
					col = col.lerp(Color.WHITE, _flare * 0.4)
				draw_rect(Rect2(origin + Vector2(x * px.x, y * px.y), px), col)


func _make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 4
	p.lifetime = 1.4
	p.local_coords = false
	p.position = Vector2(0, -10)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(3, 2)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(0, -18)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.5))
	ramp.set_color(1, Color(0.8, 0.25, 0.1, 0.0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	return p
