extends CanvasLayer
## La fine del prologo: Lethe toglie il lenzuolo e cade nello specchio.
## 1. il lenzuolo scivola (fruscio), l'angolo si accende al massimo;
## 2. lo specchio cede: le crepe corrono sul vetro, schegge, lo schermo trema, la musica
##    si ferma; Lethe viene tirata verso il vetro e sparisce in una scia di luce fredda;
## 3. un lampo freddo, e lo schermo diventa vetro: le schegge si girano e volano su mentre
##    Lethe cade (fx/mirror_shatter.gd), col vento della caduta: "Cold glass." /
##    "Then nothing under her feet.";
## 4. nel nero, una scheggia di specchio che luccica: "Something sharp in her hand." /
##    "A piece of the mirror." È la spada di vetro, allo stadio di scheggia;
## 5. il cartello: CHAPTER 1 / THE FOREST. Poi `finished`.
##
## Uso: var fall := MirrorFall.new(); add_child(fall); await fall.play(glow, hero, music)

signal finished

const MirrorShatter := preload("res://fx/mirror_shatter.gd")
const ScreenShake := preload("res://fx/screen_shake.gd")
const Sparks := preload("res://fx/sparks.gd")
const Sfx := preload("res://core/sfx.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const RUSTLE := preload("res://audio/sheet_rustle.wav")
const BREAK := preload("res://audio/mirror_break.wav")
const WHOOSH := preload("res://audio/fall_whoosh.wav")
const GLINT := preload("res://audio/shard_glint.wav")

const COLD := Color(0.62, 0.82, 1.0)
const PALE := Color(0.78, 0.76, 0.88)
const NIGHT_LINES := [["Cold glass.", Color(0.7, 0.8, 0.95), 16],
	["Then nothing under her feet.", Color(0.7, 0.66, 0.85), 16]]
const SHARD_LINES := ["Something sharp in her hand.", "A piece of the mirror."]
const CHAPTER := "CHAPTER 1"
const CHAPTER_NAME := "THE FOREST"

## La scheggia, un carattere per blocco: W bianco, L vetro chiaro, D vetro scuro, V il
## riflesso viola del vestito.
const SHARD := [
	"....W..",
	"...WL..",
	"..WLL..",
	"..LLV..",
	".WLLL..",
	".LLLLD.",
	".LLLD..",
	"LLLLD..",
	".LLDD..",
	"..LD...",
	"..D....",
]
const SHARD_COLORS := {"W": Color(0.95, 0.98, 1.0), "L": Color(0.62, 0.78, 0.95),
	"D": Color(0.34, 0.45, 0.68), "V": Color(0.66, 0.42, 0.92)}
const SHARD_BLOCK := 6

## Falso nei test: niente suoni.
var sound := true
## Più veloce nei test (moltiplica tutte le attese).
var pace := 1.0

var flash: ColorRect
var shard: Node2D
var texts: VBoxContainer
var _glint := 0.0


func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	flash = ColorRect.new()
	flash.color = Color(COLD, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)


func _sfx(stream: AudioStream, db := 0.0, pitch := 1.0) -> void:
	if sound:
		Sfx.play(self, stream, pitch, db)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * pace).timeout


func play(glow: Node2D, hero: Node2D, music: AudioStreamPlayer) -> void:
	# 1. Il lenzuolo scivola, l'angolo si accende.
	_sfx(RUSTLE, -2.0)
	var t := create_tween()
	t.tween_property(glow, "intensity", 1.0, 0.8 * pace)
	await _wait(1.0)
	# 2. Lo specchio cede.
	_sfx(BREAK, 0.0)
	if music:
		var tape := create_tween().set_parallel()
		tape.tween_property(music, "pitch_scale", 0.3, 1.2 * pace)
		tape.tween_property(music, "volume_db", -40.0, 1.4 * pace)
	create_tween().tween_property(glow, "crack", 1.0, 0.7 * pace).set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)
	var shake := ScreenShake.new()
	shake.strength = 3.0
	shake.duration = 0.7
	get_tree().root.add_child(shake)
	var glass := Sparks.shards(22)
	glass.position = glow.global_position
	glow.get_parent().add_child(glass)
	glass.emitting = true
	glass.finished.connect(glass.queue_free)
	await _wait(0.9)
	# Lethe viene tirata verso il vetro e sparisce nella luce.
	if hero:
		var trail := Sparks.trail()
		trail.modulate = COLD
		hero.add_child(trail)
		var pull := create_tween().set_parallel()
		pull.tween_property(hero, "global_position", glow.global_position + Vector2(-6, 20), 0.9 * pace) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pull.tween_property(hero, "modulate", Color(COLD, 0.0), 0.9 * pace)
	await _wait(0.7)
	# 3. Il lampo, poi lo schermo si rompe e cade nel buio.
	var light := create_tween()
	light.tween_property(flash, "color:a", 0.85, 0.2 * pace)
	light.tween_property(flash, "color:a", 0.0, 0.3 * pace)
	await light.finished
	await get_tree().process_frame       # la foto del vetro è la stanza, non il lampo
	if music:
		music.stop()
	_sfx(WHOOSH, -2.0)
	var shatter := MirrorShatter.new()
	shatter.night_lines = NIGHT_LINES
	add_child(shatter)
	shatter.layer = layer + 1
	shatter.play(glow.get_global_transform_with_canvas().origin)
	await shatter.finished
	# 4. Nel nero, la scheggia.
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(640, 360)
	var over := CanvasLayer.new()
	over.layer = layer + 2
	add_child(over)
	over.add_child(black)
	shatter.queue_free()
	await _wait(0.8)
	shard = Node2D.new()
	shard.position = Vector2(320, 150) - Vector2(SHARD[0].length(), SHARD.size()) * SHARD_BLOCK / 2.0
	shard.draw.connect(_draw_shard)
	shard.modulate.a = 0.0
	over.add_child(shard)
	create_tween().tween_property(shard, "modulate:a", 1.0, 1.2 * pace)
	await _wait(0.9)
	_sfx(GLINT, -4.0)
	create_tween().tween_property(self, "_glint", 1.0, 0.5 * pace)
	texts = VBoxContainer.new()
	texts.position = Vector2(0, 220)
	texts.size = Vector2(640, 60)
	over.add_child(texts)
	for line in SHARD_LINES:
		var label := _label(line, PALE, 16)
		label.modulate.a = 0.0
		texts.add_child(label)
		var fade := create_tween()
		fade.tween_property(label, "modulate:a", 1.0, 0.8 * pace)
		await _wait(2.0)
	await _wait(1.0)
	var out := create_tween().set_parallel()
	out.tween_property(shard, "modulate:a", 0.0, 1.0 * pace)
	out.tween_property(texts, "modulate:a", 0.0, 1.0 * pace)
	await out.finished
	# 5. Il cartello del capitolo.
	var card := VBoxContainer.new()
	card.position = Vector2(0, 140)
	card.size = Vector2(640, 80)
	card.add_theme_constant_override(&"separation", 6)
	card.modulate.a = 0.0
	over.add_child(card)
	card.add_child(_label(CHAPTER, Color(0.93, 0.9, 1.0), 32))
	card.add_child(_label(CHAPTER_NAME, COLD, 16))
	var show_card := create_tween()
	show_card.tween_property(card, "modulate:a", 1.0, 1.4 * pace)
	show_card.tween_interval(2.6 * pace)
	show_card.tween_property(card, "modulate:a", 0.0, 1.2 * pace)
	await show_card.finished
	finished.emit()


func _process(_delta: float) -> void:
	if shard:
		shard.queue_redraw()


func _draw_shard() -> void:
	for y in SHARD.size():
		var row: String = SHARD[y]
		for x in row.length():
			var c := row[x]
			if c in SHARD_COLORS:
				shard.draw_rect(Rect2(Vector2(x, y) * SHARD_BLOCK, Vector2.ONE * SHARD_BLOCK), SHARD_COLORS[c])
	# Il luccichio: una croce di luce sul bordo in alto che si apre e si richiude.
	if _glint > 0.0 and _glint < 1.0:
		var at := Vector2(4, 0) * SHARD_BLOCK + Vector2(2, 2)
		var arm := sin(_glint * PI) * 14.0
		var c := Color(1, 1, 1, sin(_glint * PI))
		shard.draw_rect(Rect2(at - Vector2(arm, 1), Vector2(arm * 2, 2)), c)
		shard.draw_rect(Rect2(at - Vector2(1, arm), Vector2(2, arm * 2)), c)


static func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
