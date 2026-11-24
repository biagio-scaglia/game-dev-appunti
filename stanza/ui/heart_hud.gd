extends CanvasLayer
## La vita di Lethe, in basso a sinistra, in un riquadro come quelli dei menu: un cuore
## solo, non una barra (vault: "Nemici e boss", "La mano che stringe il cuore"). A ogni colpo
## la mano lo stringe di più (heart_hud.png: 0 intero, 1-3 la mano che si chiude, 4 stretto
## del tutto). Accanto, cuoricini piccoli: quante strette regge ancora. Durante i dialoghi
## (il riquadro del testo sta in basso) si nasconde. Il cuore batte, più in fretta quando resta poco; a ogni colpo sobbalza e i
## bordi dello schermo si fanno rossi un attimo. Con l'ultimo pezzo di cuore i bordi restano
## scuri e pulsano, e si sente il battito.

const SHEET := preload("res://ui/heart_hud.png")
const HEARTBEAT := preload("res://audio/heartbeat.wav")
const Sfx := preload("res://core/sfx.gd")
const Style := preload("res://menu/menu_style.gd")

const FRAME := 32
## L'angolo in basso a sinistra del riquadro.
const MARGIN := Vector2(8, 8)
const PIP := Color(0.92, 0.42, 0.55)
const PIP_LIGHT := Color(1.0, 0.72, 0.8)
const PIP_EMPTY := Color(0.28, 0.2, 0.32)
## Un cuoricino, a blocchi di 2 pixel (7 x 6).
const PIP_SHAPE := [".xx.xx.", "xxxxxxx", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]
const PIP_BLOCK := 2
const PIP_GAP := 4

## Falso nei test: niente battito.
var sound := true
var heart := 4
var heart_max := 4
var icon: Sprite2D
var pips: Control
var box: PanelContainer
## Il livello e la barra dell'esperienza (sotto i cuoricini).
var level_label: Label
var xp_bar: Control
var level := 1
var xp := 0
var xp_next := 10
## Quanto è piena la barra adesso (si muove verso xp / xp_next).
var xp_fill := 0.0
var _xp_flash := 0.0
const XP_COLOR := Color(0.72, 0.55, 1.0)
const XP_LIGHT := Color(0.9, 0.82, 1.0)
var vignette: TextureRect
var _time := 0.0
var _beat_wait := 0.0
var _bump: Tween


func _init() -> void:
	layer = 41


func _ready() -> void:
	vignette = TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.2, 0, 0.04, 0.15), Color(0.35, 0, 0.08, 0.85)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 0.5)
	texture.width = 160
	texture.height = 90
	vignette.texture = texture
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	add_child(vignette)
	box = PanelContainer.new()
	box.add_theme_stylebox_override(&"panel", _box_style())
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var holder := Control.new()                    # il cuore pulsa senza spostare il resto
	holder.custom_minimum_size = Vector2(FRAME, FRAME)
	row.add_child(holder)
	icon = Sprite2D.new()
	icon.texture = SHEET
	icon.hframes = 5
	icon.position = Vector2(FRAME, FRAME) / 2.0
	holder.add_child(icon)
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	pips = Control.new()
	pips.draw.connect(_draw_pips)
	right.add_child(pips)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 4)
	right.add_child(line)
	level_label = Label.new()
	level_label.add_theme_font_override(&"font", Style.FONT)
	level_label.add_theme_font_size_override(&"font_size", 16)
	level_label.add_theme_color_override(&"font_color", Style.ACCENT)
	level_label.text = "LV 1"
	line.add_child(level_label)
	xp_bar = Control.new()
	xp_bar.custom_minimum_size = Vector2(44, 16)
	xp_bar.draw.connect(_draw_xp)
	line.add_child(xp_bar)
	_place()


func _box_style() -> StyleBox:
	var style := Style.window_style()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 4)
	style.set_content_margin(SIDE_RIGHT, 10)
	return style


## Il riquadro si allarga coi cuoricini: lo si rimette nell'angolo in basso a sinistra.
func _place() -> void:
	var pip_w := PIP_SHAPE[0].length() * PIP_BLOCK
	pips.custom_minimum_size = Vector2(heart_max * (pip_w + PIP_GAP) - PIP_GAP, PIP_SHAPE.size() * PIP_BLOCK + 2)
	box.reset_size()
	box.position = Vector2(MARGIN.x, 360 - MARGIN.y - box.size.y)


## Il livello e l'esperienza. `animate`: la barra si riempie piano (e se è salito di
## livello, prima si riempie tutta e lampeggia).
func show_xp(new_level: int, new_xp: int, next: int, animate := true) -> void:
	var leveled := new_level > level
	level = new_level
	xp = new_xp
	xp_next = maxi(1, next)
	level_label.text = "LV %d" % level
	var goal := clampf(float(xp) / xp_next, 0.0, 1.0)
	if not animate or not is_node_ready():
		xp_fill = goal
		xp_bar.queue_redraw()
		return
	var t := create_tween()
	if leveled:
		t.tween_method(_set_fill, xp_fill, 1.0, 0.25)
		t.tween_callback(func() -> void: _xp_flash = 0.6)
		t.tween_method(_set_fill, 0.0, goal, 0.35)
	else:
		t.tween_method(_set_fill, xp_fill, goal, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_fill(v: float) -> void:
	xp_fill = v
	xp_bar.queue_redraw()


func _draw_xp() -> void:
	var w := xp_bar.size.x
	var y := 7.0
	xp_bar.draw_rect(Rect2(0, y, w, 4), Color(0.05, 0.03, 0.09))
	var fill := floorf(w * xp_fill / 2.0) * 2.0
	if fill > 0.0:
		var c := XP_LIGHT if _xp_flash > 0.0 and int(_xp_flash * 10.0) % 2 == 0 else XP_COLOR
		xp_bar.draw_rect(Rect2(0, y, fill, 4), c)
		xp_bar.draw_rect(Rect2(0, y, fill, 2), c.lightened(0.3))


## Nasconde il riquadro (piano) mentre c'è un dialogo, e lo rimette dopo.
func set_shown(shown: bool) -> void:
	create_tween().tween_property(box, "modulate:a", 1.0 if shown else 0.0, 0.2)


## Il fotogramma del cuore: quanto stringe la mano (0-3), 4 se è finito.
static func stage_for(heart_now: int, heart_total: int) -> int:
	if heart_now <= 0:
		return 4
	var squeeze := heart_total - heart_now
	if heart_total <= 1 or squeeze <= 0:
		return 0
	return clampi(ceili(squeeze * 3.0 / (heart_total - 1)), 1, 3)


## Quanto batte in fretta (battiti al secondo), più quando resta poco.
static func beats_per_second(heart_now: int, heart_total: int) -> float:
	return 0.9 + 1.6 * (1.0 - float(heart_now) / maxf(1.0, heart_total))


func show_heart(heart_now: int, heart_total: int) -> void:
	heart = heart_now
	heart_max = heart_total
	icon.frame = stage_for(heart, heart_max)
	if is_node_ready():
		_place()
	pips.queue_redraw()


## Un colpo: il cuore sobbalza, i bordi diventano rossi un attimo.
func hit() -> void:
	if _bump:
		_bump.kill()
	_bump = create_tween()
	icon.scale = Vector2(1.35, 0.8)
	_bump.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	vignette.modulate.a = 1.0
	_bump.parallel().tween_property(vignette, "modulate:a", low_alpha(), 0.5)


## Quanto restano scuri i bordi: solo con l'ultimo pezzo di cuore.
func low_alpha() -> float:
	return 0.55 if heart == 1 else 0.0


func is_low() -> bool:
	return heart == 1


func _process(delta: float) -> void:
	_time += delta
	if _xp_flash > 0.0:
		_xp_flash -= delta
		xp_bar.queue_redraw()
	var bps := beats_per_second(heart, heart_max)
	# Il battito: un piccolo gonfiarsi due volte (tum-tum), poi pausa.
	var phase := fmod(_time * bps, 1.0)
	var pulse := 0.0
	if phase < 0.12:
		pulse = sin(phase / 0.12 * PI)
	elif phase > 0.2 and phase < 0.3:
		pulse = 0.6 * sin((phase - 0.2) / 0.1 * PI)
	if not (_bump and _bump.is_running()) and heart > 0:
		icon.scale = Vector2.ONE * (1.0 + 0.08 * pulse)
	if is_low() and not (_bump and _bump.is_running()):
		vignette.modulate.a = low_alpha() * (0.75 + 0.25 * pulse)
		_beat_wait -= delta
		if _beat_wait <= 0.0:
			_beat_wait = 1.0 / bps
			if sound:
				Sfx.play(self, HEARTBEAT, 1.0, -6.0)


func _draw_pips() -> void:
	var pip_w := PIP_SHAPE[0].length() * PIP_BLOCK
	var y := (FRAME - PIP_SHAPE.size() * PIP_BLOCK) / 2.0
	for i in heart_max:
		var x := i * (pip_w + PIP_GAP)
		var full := i < heart
		for row in PIP_SHAPE.size():
			var line: String = PIP_SHAPE[row]
			for col in line.length():
				if line[col] != "x":
					continue
				var c := (PIP_LIGHT if row == 1 and col in [1, 2] else PIP) if full else PIP_EMPTY
				pips.draw_rect(Rect2(x + col * PIP_BLOCK, y + row * PIP_BLOCK, PIP_BLOCK, PIP_BLOCK), c)
