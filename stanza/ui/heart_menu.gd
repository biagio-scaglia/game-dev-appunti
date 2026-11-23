extends VBoxContainer
## Il menu del titolo: una voce per riga; davanti alla voce scelta batte un piccolo
## cuore (le altre hanno un'icona vuota della stessa misura: il testo non si sposta).
## Tastiera, gamepad (ui_up / ui_down / ui_accept) e mouse: sono Button veri, il focus
## lo gestisce Godot. Lo usa anche il menu di pausa, per ogni sua lista.

signal chosen(id: StringName)
## Il focus è passato a un'altra voce (per il suono del carillon). Non al primo focus.
signal moved

## Il cuore: due fotogrammi in fila (pieno, battito).
const HEART := preload("res://title/art/heart.png")
## Il battito come un cuore vero: tum-tum, pausa. [fotogramma, secondi] (0 pieno, 1 stretto).
const BEAT := [[1, 0.12], [0, 0.12], [1, 0.12], [0, 0.7]]

## Quanto corre il cuore (2 = il doppio veloce: il menu di pausa lo fa agitare).
var beat_speed := 1.0
var heart_frames: Array[AtlasTexture] = []
var _blank: ImageTexture
var _sound_ready := false
var _beat_step := 0
var _beat_left := 0.0


func _init() -> void:
	var size := Vector2(HEART.get_width() / 2.0, HEART.get_height())
	for i in 2:
		var frame := AtlasTexture.new()
		frame.atlas = HEART
		frame.region = Rect2(Vector2(size.x * i, 0), size)
		heart_frames.append(frame)
	var empty := Image.create_empty(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	_blank = ImageTexture.create_from_image(empty)


## Crea le voci: [[id, testo], ...]. La prima prende il focus.
func setup(entries: Array, font: Font, font_size: int) -> void:
	for child in get_children():
		remove_child(child)      # subito: le voci nuove possono riusare gli stessi nomi
		child.queue_free()
	for entry in entries:
		var button := Button.new()
		button.name = String(entry[0])
		button.text = entry[1]
		button.flat = true
		button.icon = _blank
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override(&"h_separation", 6)
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
		# Il focus resta nella lista: niente salti di lato verso altre liste.
		button.focus_neighbor_left = NodePath(".")
		button.focus_neighbor_right = NodePath(".")
	var buttons := get_children()
	if buttons.size() > 1:   # dalla prima si sale all'ultima e viceversa
		buttons[0].focus_neighbor_top = buttons[0].get_path_to(buttons[-1])
		buttons[-1].focus_neighbor_bottom = buttons[-1].get_path_to(buttons[0])


func focus_first() -> void:
	focus_id(StringName(get_child(0).name) if get_child_count() > 0 else &"")


func focus_id(id: StringName) -> void:
	var button := get_node_or_null(NodePath(String(id))) as Button if id != &"" else null
	if button:
		button.grab_focus()
	_sound_ready = true


## Una lista non attiva non prende il focus (né da tastiera né col mouse).
func set_active(active: bool) -> void:
	for button: Button in get_children():
		button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


## La voce che ha il focus ora (vuoto se nessuna).
func focused_id() -> StringName:
	var owner_focus := get_viewport().gui_get_focus_owner()
	return StringName(owner_focus.name) if owner_focus and owner_focus.get_parent() == self else &""


## True se davanti a questa voce c'è il cuore.
func has_heart(id: StringName) -> bool:
	var button := get_node_or_null(NodePath(String(id))) as Button if id != &"" else null
	return button != null and button.icon is AtlasTexture and button.icon in heart_frames


func _process(delta: float) -> void:
	_beat_left -= delta
	if _beat_left > 0.0:
		return
	_beat_step = (_beat_step + 1) % BEAT.size()
	_beat_left = BEAT[_beat_step][1] / beat_speed
	var id := focused_id()
	if id != &"":
		(get_node(NodePath(String(id))) as Button).icon = heart_frames[BEAT[_beat_step][0]]


func _mark(button: Button) -> void:
	button.icon = heart_frames[0]
	if _sound_ready:
		moved.emit()


func _unmark(button: Button) -> void:
	button.icon = _blank
