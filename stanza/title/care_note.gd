extends Control
## Le due pagine calme del titolo (vault: "Temi delicati - linee guida"):
## - &"warning": l'avviso sui contenuti, prima del titolo, la prima volta che si gioca;
## - &"help": "Talk to Someone", dal menu del titolo, sempre: i numeri d'aiuto.
## Testo fermo e chiaro, niente effetti, niente glitch. Un tasto chiude (non subito, così un
## tasto tenuto premuto non la salta). Si costruisce da sola, in codice.

signal closed(kind: StringName)

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")

const PAGES := {
	&"warning": {
		"title": "Before you start",
		"lines": [
			"This game is about isolation, despair and thoughts of suicide.",
			"It never shows them, but it talks about them.",
			"There is also some mild horror.",
			"",
			"If you are going through something like Lethe,",
			"you don't have to go through it alone.",
			"\"Talk to Someone\" in the title menu is always there.",
		],
	},
	&"help": {
		"title": "Talk to Someone",
		"lines": [
			"If you recognized yourself in Lethe,",
			"talk to someone you trust. Or call:",
			"",
			"Italy - Telefono Amico: 02 2327 2327",
			"Emergency: 112",
			"Other countries: findahelpline.com",
			"",
			"Someone will answer the door.",
		],
		"accent": [3, 4, 5],
	},
}
const HINT := "Press any key"
## Prima di così il tasto non chiude.
const MIN_SECONDS := 1.0
const FADE := 0.4

const BG := Color(0.03, 0.02, 0.05, 0.97)
const TITLE_COLOR := Color(0.93, 0.9, 1.0)
const TEXT_COLOR := Color(0.78, 0.74, 0.88)
const ACCENT := Color(1.0, 0.8, 0.52)      # la luce sotto la porta
const HINT_COLOR := Color(0.62, 0.58, 0.74, 0.7)

var kind: StringName = &""
var title_label: Label
var body: VBoxContainer
var hint_label: Label
var _shown_for := 0.0
var _closing := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	center.add_child(column)
	title_label = _label(TITLE_COLOR)
	column.add_child(title_label)
	body = VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 0)
	column.add_child(body)
	hint_label = _label(HINT_COLOR)
	hint_label.text = HINT
	column.add_child(hint_label)


static func _label(color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", color)
	return label


func is_open() -> bool:
	return visible and not _closing


## Il testo della pagina aperta, tutto di fila (per i test).
func text() -> String:
	var lines: PackedStringArray = [title_label.text]
	for child: Label in body.get_children():
		lines.append(child.text)
	return "\n".join(lines)


func open(page: StringName) -> void:
	kind = page
	var data: Dictionary = PAGES[page]
	title_label.text = data["title"]
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var lines: Array = data["lines"]
	var accent: Array = data.get("accent", [])
	for i in lines.size():
		var line: String = lines[i]
		# Le righe coi numeri hanno il colore della luce sotto la porta.
		var label := _label(ACCENT if i in accent else TEXT_COLOR)
		label.text = line if line != "" else " "
		body.add_child(label)
	_shown_for = 0.0
	_closing = false
	hint_label.modulate.a = 0.0
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)


func can_close() -> bool:
	return is_open() and _shown_for >= MIN_SECONDS


func _process(delta: float) -> void:
	if not is_open():
		return
	_shown_for += delta
	if _shown_for >= MIN_SECONDS and hint_label.modulate.a == 0.0:
		create_tween().tween_property(hint_label, "modulate:a", 1.0, FADE)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	get_viewport().set_input_as_handled()    # aperta, si prende tutto
	var pressed := (event is InputEventKey or event is InputEventJoypadButton \
		or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo()
	if pressed and can_close():
		close()


func close() -> void:
	if not is_open():
		return
	_closing = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	await t.finished
	visible = false
	_closing = false
	closed.emit(kind)
