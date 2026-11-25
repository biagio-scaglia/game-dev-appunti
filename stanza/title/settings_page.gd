extends Control
## Le impostazioni, dal menu del titolo: una pagina sopra il titolo, con la stessa lista col
## cuore che batte (ui/heart_menu.gd). Sinistra e destra cambiano il valore della voce,
## Spazio la cambia o la apre, Esc torna indietro.
##
## - Volume, Music: da 0 a 10 (a tacche);
## - Fullscreen, Screen shake: sì / no;
## - Text speed: lento, normale, veloce;
## - Erase files: la lista dei file da cancellare (file_eraser.gd: lì le cose non vanno
##   come dovrebbero).
## Ogni cambio si salva subito (core/settings_store.gd). Si costruisce da sola, in codice.

signal closed
## Un file è stato cancellato (il titolo ricontrolla "Continue").
signal file_erased(slot: int)

const HeartMenu := preload("res://ui/heart_menu.gd")
const Settings := preload("res://core/settings_store.gd")
const FileEraser := preload("file_eraser.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const MOVE := preload("res://audio/ui_move.wav")
const CONFIRM := preload("res://audio/ui_confirm.wav")
const Sfx := preload("res://core/sfx.gd")

const ROWS := [&"volume", &"music", &"fullscreen", &"shake", &"text_speed", &"erase", &"back"]
const NAMES := {&"volume": "Volume", &"music": "Music", &"fullscreen": "Fullscreen",
	&"shake": "Screen shake", &"text_speed": "Text speed", &"erase": "Erase files...", &"back": "Back"}
const HELP := {
	&"volume": "Everything you hear.",
	&"music": "Only the music.",
	&"fullscreen": "The whole screen, or a window.",
	&"shake": "The screen trembles when something hits.",
	&"text_speed": "How fast the words come.",
	&"erase": "Forget a file.",
	&"back": "",
}
const BG := Color(0.03, 0.02, 0.05, 0.94)
const TITLE_COLOR := Color(0.93, 0.9, 1.0)
const HELP_COLOR := Color(0.62, 0.58, 0.74)
const FADE := 0.25
## Dove comincia la colonna dei valori, dentro la riga.
const VALUE_X := 170.0
const PIP := Color(0.92, 0.42, 0.55)
const PIP_EMPTY := Color(0.28, 0.2, 0.32)
const VALUE_COLOR := Color(0.95, 0.9, 1.0)

## &"settings" o &"erase" (la lista dei file).
var mode := &"settings"
var sound := true
var title_label: Label
var list: VBoxContainer
var help_label: Label
var eraser: Node


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
	column.add_theme_constant_override(&"separation", 12)
	column.custom_minimum_size = Vector2(300, 0)
	center.add_child(column)
	title_label = _label(TITLE_COLOR)
	column.add_child(title_label)
	list = HeartMenu.new()
	column.add_child(list)
	help_label = _label(HELP_COLOR)
	help_label.set_meta(&"no_glitch", true)
	column.add_child(help_label)
	list.chosen.connect(_on_chosen)
	list.moved.connect(func() -> void: _sfx(MOVE, 1.0, -10.0); _update_help())
	eraser = FileEraser.new()
	eraser.name = "Eraser"
	add_child(eraser)
	eraser.setup(self)


static func _label(color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", color)
	return label


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)
	show_settings()


func close() -> void:
	if eraser.busy:
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	await t.finished
	visible = false
	closed.emit()


# --- Le impostazioni ---------------------------------------------------------------------

func show_settings(focus := &"volume") -> void:
	mode = &"settings"
	title_label.text = "Settings"
	list.setup(ROWS.map(func(id: StringName) -> Array: return [id, NAMES[id]]), FONT, 16)
	for id in ROWS:
		_add_value(id)
	list.focus_id(focus)
	_update_help()


## Il valore della riga, in colonna a destra: le tacche per i volumi, una parola per il resto.
func _add_value(id: StringName) -> void:
	var button := list.get_node(NodePath(String(id))) as Button
	if id in [&"volume", &"music"]:
		var pips := Control.new()
		pips.name = "Value"
		pips.position = Vector2(VALUE_X, 8)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.draw.connect(func() -> void:
			var v := int(Settings.value(String(id)))
			for i in Settings.VOLUME_STEPS:
				pips.draw_rect(Rect2(i * 8, 0, 6, 10), PIP if i < v else PIP_EMPTY))
		button.add_child(pips)
	elif id in [&"fullscreen", &"shake", &"text_speed"]:
		var label := _label(VALUE_COLOR)
		label.name = "Value"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.position = Vector2(VALUE_X, 5)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = value_text(id)
		button.add_child(label)


## Il valore scritto (per le righe che non sono volumi).
static func value_text(id: StringName) -> String:
	match id:
		&"fullscreen", &"shake":
			return "On" if bool(Settings.value(String(id))) else "Off"
		&"text_speed":
			return Settings.TEXT_SPEED_NAMES[int(Settings.value("text_speed"))]
	return ""


## Cambia il valore di una riga di `step` (-1 a sinistra, +1 a destra o Spazio).
func change(id: StringName, step: int) -> void:
	match id:
		&"volume", &"music":
			var v := clampi(int(Settings.value(String(id))) + step, 0, Settings.VOLUME_STEPS)
			Settings.set_value(String(id), v)
		&"fullscreen", &"shake":
			Settings.set_value(String(id), not bool(Settings.value(String(id))))
		&"text_speed":
			var n := Settings.TEXT_SPEEDS.size()
			Settings.set_value("text_speed", (int(Settings.value("text_speed")) + step + n) % n)
		_:
			return
	var value := list.get_node(NodePath(String(id) + "/Value"))
	if value is Label:
		value.text = value_text(id)
	else:
		value.queue_redraw()
	_sfx(MOVE, 1.3 if step > 0 else 0.9, -8.0)


func _on_chosen(id: StringName) -> void:
	if mode == &"erase":
		eraser.choose(id)
		return
	match id:
		&"back":
			_sfx(CONFIRM, 1.0, -8.0)
			close()
		&"erase":
			_sfx(CONFIRM, 1.0, -8.0)
			eraser.open_list()
		_:
			change(id, 1)


func _update_help() -> void:
	if mode == &"settings":
		help_label.text = HELP.get(list.focused_id(), "")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if eraser.busy:
		get_viewport().set_input_as_handled()     # mentre si cancella, non si tocca niente
		return
	if mode == &"settings" and (event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")):
		get_viewport().set_input_as_handled()
		change(list.focused_id(), -1 if event.is_action_pressed(&"ui_left") else 1)
		return
	var right_click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_RIGHT
	if event.is_action_pressed(&"ui_cancel") or right_click:
		get_viewport().set_input_as_handled()
		if mode == &"erase":
			eraser.back()
		else:
			close()


func _sfx(stream: AudioStream, pitch: float, db: float) -> void:
	if sound:
		Sfx.play(self, stream, pitch, db)
