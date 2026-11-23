extends HBoxContainer
## La riga di Lethe: ritratto, nome, classe, livello, barre HP/MP e stato.
## La usano la vista del gruppo e quella dello stato. Ogni tanto lo stato legge "Dead".

const Style := preload("menu_style.gd")
const Data := preload("menu_data.gd")
const Gauge := preload("gauge.gd")

var portrait: TextureRect
var name_label: Label
var state_label: Label
var hp: Gauge
var mp: Gauge
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
	info.add_child(Style.label("Lv %d" % Data.LEVEL))
	add_child(info)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override(&"separation", 2)
	hp = _gauge("HP", Data.HP, Style.HP_COLOR)
	mp = _gauge("MP", Data.MP, Style.MP_COLOR)
	bars.add_child(hp)
	bars.add_child(mp)
	state_label = Style.label("Normal", Style.DIM)
	bars.add_child(state_label)
	add_child(bars)


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
	hp.value = 0
	await get_tree().create_timer(duration).timeout
	state_label.text = "Normal"
	state_label.add_theme_color_override(&"font_color", Style.DIM)
	hp.value = Data.HP
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
