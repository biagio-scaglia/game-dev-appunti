extends VBoxContainer
## La prima pagina del menu: il gruppo, cioè Lethe. In fondo, appena leggibile, un
## sussurro diverso ogni volta che si apre il menu.

const Style := preload("menu_style.gd")
const HeroCard := preload("hero_card.gd")

const WHISPER_ALPHA := 0.3

var hero: HeroCard
var whisper: Label


func _init() -> void:
	hero = HeroCard.new()
	add_child(hero)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	whisper = Style.label("", Style.DIM)
	whisper.modulate.a = WHISPER_ALPHA
	add_child(whisper)
