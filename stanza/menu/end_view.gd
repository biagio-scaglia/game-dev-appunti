extends "menu_page.gd"
## Game End: tornare al titolo o no.

signal chosen(id: StringName)

const Data := preload("menu_data.gd")


func _ready() -> void:
	header.text = "Return to the title?"
	fill(Data.END_CHOICES)


func _on_chosen(id: StringName) -> void:
	chosen.emit(id)
