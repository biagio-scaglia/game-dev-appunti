extends VBoxContainer
## Gli oggetti: la lista, e nella barra d'aiuto in fondo la descrizione di quello scelto.
## Riguardando un oggetto la descrizione cambia (vedi menu_data.gd). Usarli: "Not now."

signal described(text: String)

const Style := preload("menu_style.gd")
const Data := preload("menu_data.gd")
const HeartMenu := preload("res://title/title_menu.gd")

var list: HeartMenu
## Quante volte si è guardato ogni oggetto (per la seconda descrizione).
var seen := {}


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	add_child(Style.label("Items", Style.ACCENT))
	add_child(HSeparator.new())
	list = HeartMenu.new()
	list.add_theme_constant_override(&"separation", -4)
	list.chosen.connect(func(_id): described.emit("You can't use that now."))
	add_child(list)


func refresh(sword_stage: int) -> void:
	var entries := []
	for item in Data.ITEMS:
		entries.append([item["id"], "%s   x%d" % [item["name"], Data.item_count(item, sword_stage)]])
	list.setup(entries, Style.FONT, Style.FONT_SIZE)
	for button: Button in list.get_children():
		button.focus_entered.connect(_describe.bind(StringName(button.name)))
	list.set_active(false)


func enter() -> void:
	list.set_active(true)
	list.focus_first()


func leave() -> void:
	list.set_active(false)


## La descrizione dell'oggetto: la prima volta quella vera, poi l'altra.
func description(id: StringName) -> String:
	for item in Data.ITEMS:
		if item["id"] == id:
			return item["again"] if seen.get(id, 0) > 1 else item["desc"]
	return ""


func _describe(id: StringName) -> void:
	seen[id] = seen.get(id, 0) + 1
	described.emit(description(id))
