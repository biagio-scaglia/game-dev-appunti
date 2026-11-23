extends CanvasLayer
## Lo schermo che si rompe, come in un incubo. Si fotografa lo schermo e lo si ferma; la
## musica rallenta fino a spegnersi, come un nastro; dal punto d'impatto partono le crepe
## (raggi e anelli, a ragnatela) e lo schermo trema; poi i frammenti cadono nel buio,
## prima i più vicini. Nel nero due righe: "Wake up, Lethe." e "You can't.". Poi `finished`.
## Un tasto, dopo le prime crepe, salta tutto e chiude subito.
##
## Uso: var s := ScreenShatter.new(); add_child(s); s.play(punto, musica); await s.finished

signal finished

const Glitch := preload("res://menu/glitch.gd")
const Sfx := preload("res://core/sfx.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const CRACK_SOUND := preload("res://audio/sword_slash.wav")
const BREAK_SOUND := preload("res://audio/magic_impact.wav")

const RAYS := 11
const RINGS := 4
const CRACK_TIME := 0.45
const HOLD_TIME := 0.5
const FALL_TIME := 1.3
const GRAVITY := 900.0
## [testo, colore, misura del font]
const LINES := [["Wake up, Lethe.", Color(0.7, 0.66, 0.85), 16], ["You can't.", Color(0.78, 0.2, 0.3), 32]]
const LINE_TIME := 1.0

var rng := RandomNumberGenerator.new()
var shards: Array[Polygon2D] = []
var _cracks: Node2D
var _crack_progress := 0.0
var _rays: Array = []
var _center := Vector2.ZERO
var _done := false
var _skippable := false


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


## La ragnatela di frammenti attorno a `center` che copre `size`: raggi storti, anelli a
## distanze irregolari; l'ultimo anello sta fuori dallo schermo. Solo geometria.
static func web(center: Vector2, size: Vector2, rays: int, rings: int,
		rand: RandomNumberGenerator) -> Array[PackedVector2Array]:
	var reach := 0.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		reach = maxf(reach, center.distance_to(corner))
	reach += 40.0
	var angles: Array[float] = []
	for i in rays:
		angles.append((i + rand.randf_range(-0.3, 0.3)) * TAU / rays)
	var radii: Array[float] = []
	for k in rings:
		var t := float(k + 1) / rings
		radii.append(reach if k == rings - 1 else reach * t * t * rand.randf_range(0.8, 1.15))
	# points[i][k]: dove il raggio i incontra l'anello k (con un po' di storto).
	var points := []
	for i in rays:
		var row := []
		for k in rings:
			var a := angles[i] + (rand.randf_range(-0.08, 0.08) if k < rings - 1 else 0.0)
			row.append(center + Vector2.from_angle(a) * radii[k])
		points.append(row)
	var out: Array[PackedVector2Array] = []
	for i in rays:
		var j := (i + 1) % rays
		out.append(PackedVector2Array([center, points[i][0], points[j][0]]))
		for k in rings - 1:
			out.append(PackedVector2Array([points[i][k], points[i][k + 1], points[j][k + 1], points[j][k]]))
	return out


func play(at: Vector2, music: AudioStreamPlayer = null) -> void:
	rng.randomize()
	_center = at
	var size := get_viewport().get_visible_rect().size
	var shot := _screenshot(size)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = size
	add_child(black)
	var holder := Node2D.new()
	add_child(holder)
	var scale_uv := Vector2(shot.get_width(), shot.get_height()) / size
	for poly in web(at, size, RAYS, RINGS, rng):
		var shard := Polygon2D.new()
		shard.texture = shot
		shard.polygon = poly
		var uv := PackedVector2Array()
		for p in poly:
			uv.append(p * scale_uv)
		shard.uv = uv
		holder.add_child(shard)
		shards.append(shard)
	_cracks = Node2D.new()
	_cracks.draw.connect(_draw_cracks)
	holder.add_child(_cracks)
	_rays = _crack_lines(size)

	if music:
		var tape := create_tween().set_parallel()
		tape.tween_property(music, "pitch_scale", 0.15, CRACK_TIME + HOLD_TIME).set_trans(Tween.TRANS_QUAD)
		tape.tween_property(music, "volume_db", -40.0, CRACK_TIME + HOLD_TIME + 0.3)
	Sfx.play(self, CRACK_SOUND, 0.55, -4.0)

	# Le crepe corrono fuori dall'impatto, lo schermo trema.
	var crack := create_tween()
	crack.tween_method(_set_crack, 0.0, 1.0, CRACK_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	for x in [6.0, -5.0, 4.0, -3.0, 2.0, -1.0, 0.0]:
		crack.parallel().tween_property(holder, "position", Vector2(x, -x * 0.5), 0.05)
	await crack.finished
	_skippable = true
	for shard in shards:   # i pezzi si staccano appena: lo schermo è rotto
		shard.position = (_mid(shard.polygon) - at).normalized() * rng.randf_range(0.5, 2.0)
	await get_tree().create_timer(HOLD_TIME).timeout
	if _done:
		return

	Sfx.play(self, BREAK_SOUND, 0.5, -2.0)
	if music:
		music.stop()
	_cracks.hide()
	for shard in shards:
		_fall(shard, size)
	await get_tree().create_timer(FALL_TIME).timeout
	if _done:
		return
	holder.hide()
	await _nightmare_lines(size)
	_finish()


## Quanti frammenti ci sono ancora sullo schermo (pubblico per i test).
func shard_count() -> int:
	return shards.size()


func _input(event: InputEvent) -> void:
	if _skippable and not _done and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _screenshot(size: Vector2) -> Texture2D:
	var headless := DisplayServer.get_name() == "headless"
	var image: Image = null if headless else get_viewport().get_texture().get_image()
	if image == null or image.is_empty():   # headless: niente da fotografare
		image = Image.create_empty(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
		image.fill(Color(0.07, 0.06, 0.1))
	return ImageTexture.create_from_image(image)


func _fall(shard: Polygon2D, size: Vector2) -> void:
	var mid := _mid(shard.polygon)
	var away := (mid - _center).normalized()
	var delay := mid.distance_to(_center) / size.length() * 0.5   # prima i pezzi vicini all'impatto
	var push := away * rng.randf_range(30.0, 120.0) + Vector2(0, rng.randf_range(-80.0, 0.0))
	shard.offset = -mid   # così ruota attorno al suo centro
	var base := shard.position + mid
	shard.position = base
	var t := create_tween().set_parallel()
	t.tween_method(func(time: float):
		shard.position = base + push * time + Vector2(0, 0.5 * GRAVITY * time * time),
		0.0, FALL_TIME, FALL_TIME).set_delay(delay)
	t.tween_property(shard, "rotation", rng.randf_range(-2.5, 2.5), FALL_TIME).set_delay(delay)
	t.tween_property(shard, "modulate", Color(0.4, 0.35, 0.5, 0.0), FALL_TIME).set_delay(delay + 0.3)


func _nightmare_lines(size: Vector2) -> void:
	for line in LINES:
		var label := Label.new()
		label.add_theme_font_override(&"font", FONT)
		label.add_theme_font_size_override(&"font_size", line[2])
		label.add_theme_color_override(&"font_color", line[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(size.x, line[2] + 4)
		label.position = Vector2(0, (size.y - label.size.y) / 2.0)
		add_child(label)
		var steps := 6
		for s in steps:   # compare guasta, poi si legge
			if _done:
				return
			label.text = Glitch.corrupt(line[0], 1.0 - float(s) / (steps - 1), rng)
			await get_tree().create_timer(LINE_TIME * 0.06).timeout
		await get_tree().create_timer(LINE_TIME * 0.64).timeout
		label.queue_free()
		if _done:
			return


func _crack_lines(size: Vector2) -> Array:
	var lines := []
	var reach := size.length()
	for i in RAYS:
		var a := (i + rng.randf_range(-0.3, 0.3)) * TAU / RAYS
		var pts := PackedVector2Array([_center])
		var p := _center
		while p.distance_to(_center) < reach:
			p += Vector2.from_angle(a + rng.randf_range(-0.35, 0.35)) * rng.randf_range(12.0, 30.0)
			pts.append(p)
		lines.append(pts)
	return lines


func _set_crack(v: float) -> void:
	_crack_progress = v
	_cracks.queue_redraw()


func _draw_cracks() -> void:
	var reach := _crack_progress * get_viewport().get_visible_rect().size.length()
	for pts: PackedVector2Array in _rays:
		var shown := PackedVector2Array()
		for p in pts:
			if p.distance_to(_center) > reach:
				break
			shown.append(p.round())
		if shown.size() > 1:
			_cracks.draw_polyline(shown, Color(0, 0, 0, 0.8), 3.0)
			_cracks.draw_polyline(shown, Color(0.95, 0.92, 1.0, 0.9), 1.0)
	_cracks.draw_circle(_center, 3.0 + 4.0 * _crack_progress, Color(1, 1, 1, 0.8))


static func _mid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / poly.size()
