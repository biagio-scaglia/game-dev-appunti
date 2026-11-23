extends VBoxContainer
## La base delle pagine del menu fatte di una lista: un titolo, una riga, la lista col
## cuore. Una pagina dice cosa scrivere nella barra d'aiuto (`described`) e quando si è
## scelto qualcosa che non si può (`denied`: la reazione la decide menu_reactions.gd).

signal described(text: String)
signal denied(text: String)

const Style := preload("menu_style.gd")
const HeartMenu := preload("res://ui/heart_menu.gd")

var header: Label
var list: HeartMenu


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	header = Style.label("", Style.ACCENT)
	add_child(header)
	add_child(HSeparator.new())
	list = HeartMenu.new()
	list.add_theme_constant_override(&"separation", -4)
	list.chosen.connect(_on_chosen)
	add_child(list)


## Riempie la lista: [[id, testo], ...]. `on_focus(id)` quando il cuore arriva su una voce.
func fill(entries: Array, on_focus := Callable()) -> void:
	list.setup(entries, Style.FONT, Style.FONT_SIZE)
	if on_focus.is_valid():
		for button: Button in list.get_children():
			button.focus_entered.connect(on_focus.bind(StringName(button.name)))
	list.set_active(false)


func enter(focus := &"") -> void:
	list.set_active(true)
	if focus != &"":
		list.focus_id(focus)
	else:
		list.focus_first()


func leave() -> void:
	list.set_active(false)


## Una voce scelta (Invio o clic). Le pagine lo ridefiniscono.
func _on_chosen(_id: StringName) -> void:
	pass
