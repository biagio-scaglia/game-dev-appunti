extends "menu_page.gd"
## Gli oggetti: la lista, e nella barra d'aiuto la descrizione di quello scelto.
## Riguardando un oggetto la descrizione cambia (vedi menu_data.gd). Usarli non si può.

const Data := preload("menu_data.gd")

## Quante volte si è guardato ogni oggetto (per la seconda descrizione).
var seen := {}


func _init() -> void:
	super()
	header.text = "Items"


func refresh(sword_stage: int) -> void:
	var entries := []
	for item in Data.ITEMS:
		entries.append([item["id"], "%s   x%d" % [item["name"], Data.item_count(item, sword_stage)]])
	fill(entries, _describe)


## La descrizione dell'oggetto: la prima volta quella vera, poi l'altra.
func description(id: StringName) -> String:
	for item in Data.ITEMS:
		if item["id"] == id:
			return item["again"] if seen.get(id, 0) > 1 else item["desc"]
	return ""


func _describe(id: StringName) -> void:
	seen[id] = seen.get(id, 0) + 1
	described.emit(description(id))


func _on_chosen(_id: StringName) -> void:
	denied.emit("You can't use that now.")
