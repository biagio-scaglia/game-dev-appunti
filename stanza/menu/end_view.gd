extends VBoxContainer
## Game End: tornare al titolo o no.

signal chosen(id: StringName)

const Style := preload("menu_style.gd")
const Data := preload("menu_data.gd")
const HeartMenu := preload("res://title/title_menu.gd")

var list: HeartMenu


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	add_child(Style.label("Return to the title?", Style.ACCENT))
	add_child(HSeparator.new())
	list = HeartMenu.new()
	list.chosen.connect(chosen.emit)
	add_child(list)


func _ready() -> void:
	list.setup(Data.END_CHOICES, Style.FONT, Style.FONT_SIZE)
	list.set_active(false)


func enter() -> void:
	list.set_active(true)
	list.focus_first()


func leave() -> void:
	list.set_active(false)
