extends CanvasLayer
## La caduta nello specchio (diversa dallo schermo che si rompe del Quit, screen_shatter.gd):
## 1. lo schermo diventa vetro: crepe bianche corrono dal punto d'impatto lungo tagli
##    quasi verticali, come le schegge lunghe di uno specchio;
## 2. le schegge si girano una alla volta, a onda dal punto d'impatto: per un attimo si
##    vede il loro retro, freddo e chiaro (il dietro dello specchio);
## 3. tutte le schegge volano verso l'alto, si allungano e si spengono: è Lethe che cade.
##    Nel buio salgono strisce di luce fredda, il vento della caduta;
## 4. le righe (`night_lines`), che compaiono piano. Poi `finished`.
## Un tasto, dopo le crepe, salta tutto.

signal finished

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")

const COLD := Color(0.62, 0.82, 1.0)
const BACK := Color(0.78, 0.88, 1.0)
const CRACK_TIME := 0.6
const FLIP_TIME := 0.9
const RUSH_TIME := 1.5
const STREAK_TIME := 1.6
const LINE_TIME := 2.2
## Larghezza delle schegge (a caso in questo intervallo) e quante righe per colonna.
const SLIVER_WIDTH := Vector2(26.0, 52.0)
const ROWS := 3

var night_lines: Array = []
var rng := RandomNumberGenerator.new()
var pieces: Array[Polygon2D] = []
var _holder: Node2D
var _cracks: Node2D
var _crack := 0.0
var _edges: Array = []          # [punto a, punto b, distanza dall'impatto]
var _reach := 1.0
var _center := Vector2.ZERO
var _done := false
var _skippable := false


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


## Le schegge che coprono `size`: colonne strette e storte (tagli quasi verticali), ognuna
## tagliata in `rows` pezzi da tagli obliqui. Solo geometria.
static func slivers(size: Vector2, width: Vector2, rows: int,
		rand: RandomNumberGenerator) -> Array[PackedVector2Array]:
	# I tagli verticali: x in alto e x in basso (storti), da 0 a oltre il bordo.
	var cuts: Array[Vector2] = [Vector2(-2, -2)]
	var x := 0.0
	while x < size.x:
		x += rand.randf_range(width.x, width.y)
		var top := minf(x, size.x + 2) if x < size.x else size.x + 2
		var lean := rand.randf_range(-10.0, 10.0) if x < size.x else 0.0
		cuts.append(Vector2(top, top + lean))
	# Le quote dei tagli orizzontali (uguali per tutte le colonne, poi storte per colonna).
	var out: Array[PackedVector2Array] = []
	for c in cuts.size() - 1:
		var l := cuts[c]
		var r := cuts[c + 1]
		var ys: Array[Vector2] = [Vector2(-2, -2)]   # [y a sinistra, y a destra]
		for k in range(1, rows):
			var y := size.y * k / rows + rand.randf_range(-30.0, 30.0)
			ys.append(Vector2(y, y + rand.randf_range(-14.0, 14.0)))
		ys.append(Vector2(size.y + 2, size.y + 2))
		for k in rows:
			var y0 := ys[k]
			var y1 := ys[k + 1]
			out.append(PackedVector2Array([
				Vector2(lerpf(l.x, l.y, y0.x / size.y), y0.x), Vector2(lerpf(r.x, r.y, y0.y / size.y), y0.y),
				Vector2(lerpf(r.x, r.y, y1.y / size.y), y1.y), Vector2(lerpf(l.x, l.y, y1.x / size.y), y1.x),
			]))
	return out


static func _mid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / poly.size()


func shard_count() -> int:
	return pieces.size()


func play(at: Vector2) -> void:
	rng.randomize()
	_center = at
	var size := get_viewport().get_visible_rect().size
	var shot := _screenshot(size)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = size
	add_child(black)
	_holder = Node2D.new()
	add_child(_holder)
	var scale_uv := Vector2(shot.get_width(), shot.get_height()) / size
	for poly in slivers(size, SLIVER_WIDTH, ROWS, rng):
		var mid := _mid(poly)
		var piece := Polygon2D.new()
		piece.texture = shot
		var local := PackedVector2Array()
		var uv := PackedVector2Array()
		for p in poly:
			local.append(p - mid)
			uv.append(p * scale_uv)
		piece.polygon = local
		piece.uv = uv
		piece.position = mid
		_holder.add_child(piece)
		pieces.append(piece)
		_reach = maxf(_reach, mid.distance_to(at))
		for i in poly.size():
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % poly.size()]
			_edges.append([a, b, ((a + b) / 2.0).distance_to(at)])
	_cracks = Node2D.new()
	_cracks.draw.connect(_draw_cracks)
	_holder.add_child(_cracks)

	# 1. Le crepe corrono dal punto d'impatto.
	var crack := create_tween()
	crack.tween_method(_set_crack, 0.0, 1.0, CRACK_TIME).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await crack.finished
	_skippable = true
	if _done:
		return
	# 2. Le schegge si girano, a onda: si vede il retro freddo, poi di nuovo l'immagine,
	#    più chiara e più fredda (è già vetro, non più stanza).
	for piece in pieces:
		var delay := piece.position.distance_to(at) / _reach * FLIP_TIME * 0.6
		var flip := create_tween()
		flip.tween_interval(delay)
		flip.tween_property(piece, "scale:x", 0.0, FLIP_TIME * 0.2).set_trans(Tween.TRANS_SINE)
		flip.tween_callback(func() -> void: piece.color = BACK)
		flip.tween_property(piece, "scale:x", -1.0, FLIP_TIME * 0.2).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(FLIP_TIME).timeout
	if _done:
		return
	_cracks.hide()
	# 3. Volano su: la stanza se ne va in alto, Lethe cade.
	var streaks := _streaks(size)
	add_child(streaks)
	for piece in pieces:
		_rush(piece, size)
	await get_tree().create_timer(RUSH_TIME).timeout
	if _done:
		return
	_holder.hide()
	await get_tree().create_timer(STREAK_TIME * 0.5).timeout
	streaks.emitting = false
	# 4. Le righe nel buio.
	for line in night_lines:
		if _done:
			return
		await _show_line(line, size)
	_finish()


func _rush(piece: Polygon2D, size: Vector2) -> void:
	# Prima i pezzi in basso (vicini ai piedi), poi su su fino in cima.
	var delay := (1.0 - piece.position.y / size.y) * 0.35 + rng.randf_range(0.0, 0.15)
	var drift := rng.randf_range(-30.0, 30.0)
	var start := piece.position
	var t := create_tween().set_parallel()
	t.tween_method(func(time: float) -> void:
		piece.position = start + Vector2(drift * time, -size.y * 1.6 * time * time),
		0.0, 1.0, RUSH_TIME - 0.4).set_delay(delay)
	t.tween_property(piece, "scale:y", 1.7, RUSH_TIME - 0.4).set_delay(delay)
	t.tween_property(piece, "rotation", rng.randf_range(-0.4, 0.4), RUSH_TIME - 0.4).set_delay(delay)
	t.tween_property(piece, "modulate", Color(COLD, 0.0), RUSH_TIME - 0.5).set_delay(delay + 0.2)


## Il vento della caduta: strisce sottili di luce fredda che salgono veloci.
func _streaks(size: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.amount = 40
	p.lifetime = 0.7
	p.position = Vector2(size.x / 2.0, size.y + 10)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x / 2.0, 4)
	p.direction = Vector2.UP
	p.spread = 2.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 520.0
	p.initial_velocity_max = 760.0
	# Un rettangolo 2 x 14: la striscia.
	var image := Image.create_empty(2, 14, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(image)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(COLD, 0.0))
	ramp.set_color(1, Color(COLD, 0.0))
	ramp.add_point(0.3, Color(COLD, 0.55))
	p.color_ramp = ramp
	return p


func _show_line(line: Array, size: Vector2) -> void:
	var label := Label.new()
	label.text = line[0]
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", line[2])
	label.add_theme_color_override(&"font_color", line[1])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(size.x, line[2] + 4)
	label.position = Vector2(0, (size.y - label.size.y) / 2.0)
	label.modulate.a = 0.0
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, LINE_TIME * 0.3)
	t.tween_interval(LINE_TIME * 0.4)
	t.tween_property(label, "modulate:a", 0.0, LINE_TIME * 0.3)
	await t.finished
	label.queue_free()


func _input(event: InputEvent) -> void:
	if _skippable and not _done and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _set_crack(v: float) -> void:
	_crack = v
	_cracks.queue_redraw()


## Le crepe: ogni bordo di scheggia si accende quando l'onda dall'impatto lo raggiunge.
func _draw_cracks() -> void:
	for e in _edges:
		var reached: float = _crack * _reach * 1.1 - float(e[2])
		if reached <= 0.0:
			continue
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var amount := clampf(reached / 60.0, 0.0, 1.0)
		var mid := (a + b) / 2.0
		_cracks.draw_line(mid - (mid - a) * amount, mid + (b - mid) * amount, Color(BACK, 0.9), 2.0)


func _screenshot(size: Vector2) -> Texture2D:
	var headless := DisplayServer.get_name() == "headless"
	var image: Image = null if headless else get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		image = Image.create_empty(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
		image.fill(Color(0.07, 0.06, 0.1))
	return ImageTexture.create_from_image(image)
