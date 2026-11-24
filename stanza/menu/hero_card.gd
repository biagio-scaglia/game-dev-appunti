extends HBoxContainer
## La riga di Lethe: ritratto, nome, classe, livello, barre del cuore, MP ed esperienza, e
## stato. refresh() la legge dallo stato della partita (senza: i valori di partenza).
## La usano la vista del gruppo e quella dello stato. Ogni tanto lo stato legge "Dead".

const Style := preload("menu_style.gd")
const Data := preload("menu_data.gd")
const Gauge := preload("gauge.gd")

var portrait: TextureRect
var name_label: Label
var state_label: Label
var hp: Gauge
var mp: Gauge
var xp: Gauge
var level_label: Label
var _dead := false


func _init() -> void:
	add_theme_constant_override(&"separation", 14)
	portrait = Style.picture(Style.face(), Vector2(64, 64))
	add_child(portrait)

	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 110
	info.add_theme_constant_override(&"separation", 0)
	name_label = Style.label(Data.NAME)
	info.add_child(name_label)
	info.add_child(Style.label(Data.CLASS, Style.DIM))
	level_label = Style.label("Lv %d" % Data.LEVEL)
	info.add_child(level_label)
	add_child(info)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override(&"separation", 2)
	hp = _gauge("HEART", 4, Style.HP_COLOR)
	mp = _gauge("MP", Data.MP, Style.MP_COLOR)
	xp = _gauge("EXP", 8, Style.ACCENT)
	bars.add_child(hp)
	bars.add_child(mp)
	bars.add_child(xp)
	state_label = Style.label("Normal", Style.DIM)
	bars.add_child(state_label)
	add_child(bars)


func refresh(state: RefCounted) -> void:
	level_label.text = "Lv %d" % int(state.level)
	hp.max_value = int(state.heart_max)
	hp.value = int(state.heart)
	xp.max_value = state.exp_to_next(int(state.level))
	xp.value = int(state.xp)


func show_face(away: bool) -> void:
	portrait.texture = Style.face(away)


func is_away() -> bool:
	return portrait.texture != null and portrait.texture.region.position.y > 64


## Per un attimo: stato "Dead" e HP a zero. Poi tutto torna com'era.
func blink_dead(duration := 0.15) -> void:
	if _dead:
		return
	_dead = true
	state_label.text = "Dead"
	state_label.add_theme_color_override(&"font_color", Style.HP_COLOR)
	var before := hp.value
	hp.value = 0
	await get_tree().create_timer(duration).timeout
	state_label.text = "Normal"
	state_label.add_theme_color_override(&"font_color", Style.DIM)
	hp.value = before
	_dead = false


func shows_dead() -> bool:
	return _dead


func _gauge(caption: String, amount: int, color: Color) -> Gauge:
	var g := Gauge.new()
	g.caption = caption
	g.max_value = amount
	g.value = amount
	g.color = color
	g.custom_minimum_size = Vector2(150, 20)
	return g
