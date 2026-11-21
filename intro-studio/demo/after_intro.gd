extends Control
## Scena segnaposto: è dove partirebbe il gioco vero. Invio rilancia l'intro.


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		get_tree().change_scene_to_file("res://studio_intro/studio_intro.tscn")
