extends CanvasLayer
## Il cuore spezzato (la morte di Lethe): una schermata che deve mettere a disagio, dentro le
## regole del vault ("Temi delicati": l'horror è per l'inquietudine, mai per far vedere dolore;
## la morte non è pace; qualcuno bussa sempre). Nessuna immagine di ferite o di metodi: occhi,
## una mano, le sue bugie.
## 1. Il fermo immagine: il gioco si congela nell'istante, i colori se ne vanno (restano i rossi,
##    come quando le bugie spengono il mondo), l'immagine si sdoppia e trema. La musica si
##    taglia; il battito rallenta e si ferma.
## 2. Il nero. Un fischio sottile. Si aprono, uno alla volta, occhi rossi che guardano il centro
##    e sbattono fuori tempo (più bugie ha detto, più occhi: "qualcuno ha visto").
## 3. Accanto agli occhi le sue bugie, sussurrate; e la più grande del gioco: "Nobody would notice."
## 4. In mezzo il suo cuore, stretto da una mano che non si vede (si vedono solo le impronte
##    delle dita e il cuore che si schiaccia) finché il vetro si spacca.
## 5. DEATH IS A LIE., grande, rosso, le lettere che ogni tanto sono altre.
## 6. Qualcuno bussa. Gli occhi si chiudono tutti insieme. "Someone is knocking." (la smentita
##    a "Nobody would notice"). Poi chi la usa la fa svanire (fade_out) e Lethe si risveglia.
## Un tasto la fa andare più in fretta (non la salta del tutto: il bussare c'è sempre).

signal finished

const HeartHud := preload("heart_hud.gd")
const Sfx := preload("res://core/sfx.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const HEARTBEAT := preload("res://audio/heartbeat.wav")
const BREAK := preload("res://audio/heart_break.wav")
const WHISPER := preload("res://audio/bramble_whisper.wav")
const KNOCK := preload("res://audio/menu_knock.wav")
const FREEZE := preload("res://audio/gameover_freeze.wav")
const DARK := preload("res://audio/gameover_dark.wav")

## Le bugie che sussurrano (le righe che mentono del capitolo 1), e la più grande del gioco.
const LIES := ["I'm fine.", "I'm okay.", "I just forgot.", "It was already dead when I got it.",
	"It hasn't been that long.", "Nobody would notice."]
const BIGGEST := "Nobody would notice."
const TITLE := "DEATH IS A LIE."
const GLITCH_CHARS := "#%&?!/\\|*"
const SIZE := Vector2(640, 360)
const HEART_AT := Vector2(320, 150)

const FREEZE_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
uniform float split = 0.0;
uniform float scan = 0.0;
void fragment() {
	vec2 uv = UV;
	float off = split * 0.008;
	vec3 c = vec3(texture(TEXTURE, uv + vec2(off, 0.0)).r, texture(TEXTURE, uv).g,
		texture(TEXTURE, uv - vec2(off, 0.0)).b);
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	float red = clamp((c.r - max(c.g, c.b)) * 2.5, 0.0, 1.0);
	vec3 drained = mix(vec3(grey * 0.85), c * vec3(1.2, 0.6, 0.6), red);
	c = mix(c, drained, amount);
	c *= 1.0 - 0.18 * amount * step(0.5, fract(uv.y * 120.0 + scan));
	c *= 1.0 - amount * 0.9 * smoothstep(0.25, 0.75, distance(uv, vec2(0.5)));
	COLOR = vec4(c, 1.0);
}
"""


## Un occhio nel buio (a blocchi di 5 pixel): un alone rosso, il bianco giallastro malato,
## l'iride rossa. Si apre piano, guarda il centro, sbatte fuori tempo.
class Eye extends Node2D:
	const ROWS := [
		[".........", ".........", "ooooooooo", ".........", "........."],
		[".........", "...ooo...", ".owwiwwo.", "...ooo...", "........."],
		["..ooooo..", ".owwwwwo.", "owwwiiwwo", ".owwiiwo.", "..ooooo.."],
	]
	const COLORS := {"o": Color(0.22, 0.03, 0.07), "w": Color(0.78, 0.72, 0.56), "i": Color(0.86, 0.06, 0.12)}
	const HALO := Color(0.55, 0.0, 0.06, 0.18)
	const PX := 5
	const LOOK_AT := Vector2(320, 150)
	var openness := 0.0
	var target := 0.0
	var _blink := 0.0
	var _wait := 2.0

	func _ready() -> void:
		_wait = randf_range(1.0, 3.5)

	func _process(delta: float) -> void:
		openness = move_toward(openness, target, delta * (1.4 if target > openness else 4.0))
		_wait -= delta
		if _wait <= 0.0 and openness > 0.9:
			_blink = 0.12
			_wait = randf_range(1.5, 4.0)
		_blink = maxf(0.0, _blink - delta)
		queue_redraw()

	func _draw() -> void:
		var f := 1 if _blink > 0.0 and openness > 0.5 else int(round(openness * 2.0))
		if openness > 0.05:                             # l'alone: rosso, a blocchi
			for r in [4, 3]:
				draw_rect(Rect2(Vector2(-r - 2, -r * 0.5 - 1) * PX, Vector2(r * 2 + 4, r + 2) * PX),
					Color(HALO, HALO.a * openness))
		var rows: Array = ROWS[f]
		var look := (LOOK_AT - position).normalized()
		var shift := Vector2(roundf(look.x), roundf(look.y) if f == 2 else 0.0)
		var origin := Vector2(-4.5, -2.5) * PX
		for pass_iris in [false, true]:
			for y in rows.size():
				var row: String = rows[y]
				for x in row.length():
					var c := row[x]
					if c == ".":
						continue
					if not pass_iris:
						draw_rect(Rect2(origin + Vector2(x, y) * PX, Vector2(PX, PX)), COLORS["w" if c == "i" else c])
					elif c == "i":
						var at := Vector2(x, y) + shift
						if rows[clampi(int(at.y), 0, 4)][clampi(int(at.x), 0, 8)] != ".":
							draw_rect(Rect2(origin + at * PX, Vector2(PX, PX)), COLORS["i"])


## Il cuore (lo stesso dei cuori in basso, grande), stretto da una mano che non si vede: si
## schiaccia a scatti, sopra restano le impronte scure di quattro dita, la crepa si allarga.
class HeartHand extends Node2D:
	const HH := preload("heart_hud.gd")
	const PX := 8
	## Le impronte delle dita: [x, inclinazione], sul cuore (in blocchi della sua forma).
	const MARKS := [[1.6, 0.35], [3.4, 0.15], [5.4, -0.15], [7.2, -0.35]]
	const BRUISE := Color(0.18, 0.02, 0.07)
	var squeeze := 0.0
	var crack := 0.0
	var broken := false
	var flash := 0.0
	var _cracks: Array[Vector2i] = []

	func _ready() -> void:
		# la crepa che si allarga: parte da quella dei cuori in basso e si ramifica
		var shape: Array = HH.SHAPE
		var r := RandomNumberGenerator.new()
		r.seed = 9
		_cracks.assign(HH.CRACK)
		for k in 14:
			var from: Vector2i = _cracks[r.randi() % _cracks.size()]
			var next := from + Vector2i(r.randi_range(-1, 1), r.randi_range(0, 1))
			if next.y < shape.size() and next.x >= 0 and next.x < shape[0].length() 					and shape[next.y][next.x] != "." and shape[next.y][next.x] != "O":
				_cracks.append(next)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if broken:
			return
		var shape: Array = HH.SHAPE
		# la presa: stretto di lato, a scatti (come un battito al contrario)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		var sx := 1.0 - squeeze * (0.28 + 0.06 * pulse)
		var sy := 1.0 + squeeze * 0.12
		var px := Vector2(PX * sx, PX * sy)
		var size := Vector2(shape[0].length(), shape.size()) * px
		var origin := -size / 2.0 + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * squeeze * 2.5
		var shown := int(ceil(crack * _cracks.size()))
		for y in shape.size():
			var row: String = shape[y]
			for x in row.length():
				var c := row[x]
				if c == ".":
					continue
				var col: Color = HH.FULL[c]
				if _cracks.find(Vector2i(x, y)) in range(shown):
					col = Color(0.95, 0.9, 0.92)
				col = col.lerp(Color.WHITE, flash)
				draw_rect(Rect2(origin + Vector2(x, y) * px, px + Vector2(0.5, 0.5)), col)
		if squeeze > 0.15:                               # le impronte delle dita, scure
			var a := clampf((squeeze - 0.15) * 1.6, 0.0, 0.85)
			for m in MARKS:
				for k in 5:
					var y := 1.5 + k
					var x: float = m[0] + m[1] * k
					draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px.x * 0.9, px.y)), Color(BRUISE, a))


var sound := true
## Il tempo di ogni passo (meno di 1: più in fretta; le morti dopo la prima).
var pace := 1.0
## Quanti occhi (dalle bugie).
var eye_count := 8
var root_node: Control
var freeze_rect: TextureRect
var black: ColorRect
var eyes: Array[Eye] = []
var heart: HeartHand
var title: Label
var knock_label: Label
var _hurry := 1.0
var _glitch := 0.0
var _drone: AudioStreamPlayer
var _started := false


func _init() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	root_node = Control.new()
	root_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_node)


## La sequenza intera. `frozen`: l'immagine dell'istante (null se non c'è: headless).
func play(frozen: Image) -> void:
	_started = true
	await _freeze(frozen)
	await _dark()
	await _eyes()
	await _hand()
	await _title()
	await _knock()
	finished.emit()


## Chi la usa la fa svanire quando Lethe è di nuovo in piedi.
func fade_out(time := 1.2) -> void:
	var t := create_tween()
	t.tween_property(root_node, "modulate:a", 0.0, time)
	if is_instance_valid(_drone):
		t.parallel().tween_property(_drone, "volume_db", -60.0, time)
	await t.finished
	queue_free()


func _input(event: InputEvent) -> void:
	if not _started:
		return
	for action in [&"interact", &"cast", &"slash", &"menu"]:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			_hurry = 0.3                          # più in fretta, ma tutto (il bussare c'è sempre)


func _wait(seconds: float) -> void:
	if seconds > 0.0 and is_inside_tree():
		await get_tree().create_timer(seconds * pace * _hurry, true).timeout


# --- 1. Il fermo immagine ---------------------------------------------------------------------

func _freeze(frozen: Image) -> void:
	_play(FREEZE, 1.0, -4.0)
	if frozen != null and not frozen.is_empty():
		freeze_rect = TextureRect.new()
		freeze_rect.texture = ImageTexture.create_from_image(frozen)
		freeze_rect.size = SIZE
		freeze_rect.stretch_mode = TextureRect.STRETCH_SCALE
		freeze_rect.pivot_offset = SIZE / 2.0
		var mat := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = FREEZE_SHADER
		mat.shader = shader
		freeze_rect.material = mat
		root_node.add_child(freeze_rect)
		var t := create_tween().set_parallel()
		t.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"amount", v), 0.0, 1.0, 0.9 * pace)
		t.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"split", v), 0.0, 1.0, 1.4 * pace)
		t.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"scan", v), 0.0, 6.0, 1.6 * pace)
		t.tween_property(freeze_rect, "scale", Vector2(1.08, 1.08), 1.6 * pace)
	for k in 3:                                       # il battito che rallenta e si ferma
		_play(HEARTBEAT, 1.0 - k * 0.12, -4.0 - k * 4.0)
		await _wait(0.45 + k * 0.3)
	await _wait(0.3)


# --- 2. Il nero ---------------------------------------------------------------------------------

func _dark() -> void:
	black = ColorRect.new()
	black.color = Color.BLACK
	black.size = SIZE
	root_node.add_child(black)
	if is_instance_valid(freeze_rect):
		freeze_rect.queue_free()
	if sound:
		_drone = AudioStreamPlayer.new()
		_drone.stream = DARK
		_drone.volume_db = -6.0
		_drone.bus = &"Master"
		add_child(_drone)
		_drone.play()
	await _wait(0.7)


# --- 3. Gli occhi e le bugie -----------------------------------------------------------------------

func _eyes() -> void:
	var spots := _eye_spots(eye_count)
	var lies := LIES.duplicate()
	lies.erase(BIGGEST)
	lies.shuffle()
	var said := 0
	for i in spots.size():
		var eye := Eye.new()
		eye.position = spots[i]
		root_node.add_child(eye)
		eye.target = 1.0
		eyes.append(eye)
		if i == spots.size() - 1:
			_whisper(BIGGEST, spots[i])               # la più grande, per ultima
		elif i % 2 == 0 and said < lies.size():
			_whisper(lies[said], spots[i])
			said += 1
		await _wait(0.16)
	await _wait(0.5)


## Dove si aprono gli occhi: sparsi, non sopra il cuore e la scritta in mezzo.
func _eye_spots(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var middle := Rect2(170, 60, 300, 230)
	var tries := 0
	while out.size() < count and tries < 500:
		tries += 1
		var p := Vector2(randf_range(30, 610), randf_range(25, 335))
		if middle.has_point(p):
			continue
		if out.any(func(q: Vector2) -> bool: return q.distance_to(p) < 46.0):
			continue
		out.append(p)
	return out


func _whisper(text: String, near: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", 24 if text == BIGGEST else 16)
	l.add_theme_color_override(&"font_color", Color(0.58, 0.46, 0.5) if text != BIGGEST else Color(0.86, 0.22, 0.3))
	l.position = near + Vector2(-40, 12)
	l.position.x = clampf(l.position.x, 6, SIZE.x - 170)
	l.modulate.a = 0.0
	root_node.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "modulate:a", 0.9, 0.4 * pace)
	t.tween_interval(1.4 * pace)
	t.tween_property(l, "modulate:a", 0.0 if text != BIGGEST else 0.55, 0.8 * pace)
	_play(WHISPER, randf_range(0.7, 1.0), -14.0)


# --- 4. La mano --------------------------------------------------------------------------------------

func _hand() -> void:
	heart = HeartHand.new()
	heart.position = HEART_AT
	root_node.add_child(heart)
	var t := create_tween()
	t.tween_property(heart, "squeeze", 1.0, 2.2 * pace * _hurry).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(heart, "crack", 1.0, 2.0 * pace * _hurry).set_delay(0.8 * pace * _hurry)
	await t.finished
	heart.flash = 1.0
	_play(BREAK, 0.8, 0.0)
	await _wait(0.08)
	heart.broken = true
	_shards(HEART_AT)
	await _wait(0.6)


func _shards(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 26
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 80.0
	p.gravity = Vector2(0, 380)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.set_color(0, HeartHud.FULL["r"])
	ramp.set_color(1, Color(HeartHud.FULL["d"], 0.0))
	p.color_ramp = ramp
	p.position = at
	root_node.add_child(p)
	p.emitting = true


# --- 5. La scritta -----------------------------------------------------------------------------------

func _title() -> void:
	title = Label.new()
	title.add_theme_font_override(&"font", FONT)
	title.add_theme_font_size_override(&"font_size", 32)
	title.add_theme_color_override(&"font_color", Color(0.8, 0.12, 0.2))
	title.add_theme_color_override(&"font_shadow_color", Color(0.25, 0.0, 0.05))
	title.add_theme_constant_override(&"shadow_offset_x", 2)
	title.add_theme_constant_override(&"shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(SIZE.x, 40)
	title.position = Vector2(0, 230)
	title.text = TITLE
	title.modulate.a = 0.0
	root_node.add_child(title)
	create_tween().tween_property(title, "modulate:a", 1.0, 0.25 * pace)
	_glitch = 1.0
	await _wait(2.0)


func _process(delta: float) -> void:
	if title == null or _glitch <= 0.0:
		return
	title.position = Vector2(randf_range(-1, 1), 230 + randf_range(-1, 1)) * Vector2(_glitch, 1)
	if randf() < 0.12 * _glitch:                     # una lettera che per un attimo è un'altra
		var chars := TITLE.split("")
		var i := randi() % chars.size()
		if chars[i] != " ":
			chars[i] = GLITCH_CHARS[randi() % GLITCH_CHARS.length()]
		title.text = "".join(chars)
	elif randf() < 0.3:
		title.text = TITLE
	_glitch = move_toward(_glitch, 0.35, delta * 0.2)


# --- 6. Qualcuno bussa ----------------------------------------------------------------------------

func _knock() -> void:
	_play(KNOCK, 1.0, -2.0)
	await _wait(0.25)
	for eye in eyes:                                   # tutti insieme: qualcuno è arrivato
		eye.target = 0.0
	_glitch = 0.0
	if title:
		title.text = TITLE
		create_tween().tween_property(title, "modulate:a", 0.0, 0.8 * pace)
	if is_instance_valid(_drone):
		create_tween().tween_property(_drone, "volume_db", -24.0, 1.2 * pace)
	await _wait(0.9)
	knock_label = Label.new()
	knock_label.text = "Someone is knocking."
	knock_label.add_theme_font_override(&"font", FONT)
	knock_label.add_theme_font_size_override(&"font_size", 16)
	knock_label.add_theme_color_override(&"font_color", Color(0.86, 0.84, 0.94))
	knock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	knock_label.size = Vector2(SIZE.x, 24)
	knock_label.position = Vector2(0, 168)
	knock_label.modulate.a = 0.0
	root_node.add_child(knock_label)
	var t := create_tween()
	t.tween_property(knock_label, "modulate:a", 1.0, 1.0 * pace)
	await t.finished
	await _wait(1.2)


func _play(stream: AudioStream, pitch: float, db: float) -> void:
	if sound and is_inside_tree():
		Sfx.play(self, stream, pitch, db)
