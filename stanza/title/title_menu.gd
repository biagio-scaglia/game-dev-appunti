extends VBoxContainer
## Il menu del titolo: una voce per riga, la voce scelta ha davanti "> " e si
## illumina. Tastiera, gamepad (ui_up / ui_down / ui_accept) e mouse: sono Button
## veri, il focus lo gestisce Godot.

signal chosen(id: StringName)
## Il focus è passato a un'altra voce (per il suono del carillon). Non al primo focus.
signal moved

const MARK := "> "

var _sound_ready := false


## Crea le voci: [[id, testo], ...]. La prima prende il focus.
func setup(entries: Array, font: Font, font_size: int) -> void:
	for child in get_children():
		child.queue_free()
	for entry in entries:
		var button := Button.new()
		button.name = String(entry[0])
		button.set_meta(&"label", entry[1])
		button.text = entry[1]
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_override(&"font", font)
		button.add_theme_font_size_override(&"font_size", font_size)
		button.add_theme_color_override(&"font_color", Color(0.62, 0.58, 0.74))
		button.add_theme_color_override(&"font_hover_color", Color(0.95, 0.9, 1.0))
		button.add_theme_color_override(&"font_focus_color", Color(0.95, 0.9, 1.0))
		button.add_theme_color_override(&"font_pressed_color", Color(0.8, 0.6, 1.0))
		button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		button.focus_entered.connect(_mark.bind(button))
		button.focus_exited.connect(_unmark.bind(button))
		button.mouse_entered.connect(button.grab_focus)
		button.pressed.connect(func(): chosen.emit(entry[0]))
		add_child(button)


func focus_first() -> void:
	if get_child_count() > 0:
		(get_child(0) as Button).grab_focus()
	_sound_ready = true


## La voce che ha il focus ora (vuoto se nessuna).
func focused_id() -> StringName:
	var owner_focus := get_viewport().gui_get_focus_owner()
	return StringName(owner_focus.name) if owner_focus and owner_focus.get_parent() == self else &""


func _mark(button: Button) -> void:
	button.text = MARK + String(button.get_meta(&"label"))
	if _sound_ready:
		moved.emit()


func _unmark(button: Button) -> void:
	button.text = String(button.get_meta(&"label"))
