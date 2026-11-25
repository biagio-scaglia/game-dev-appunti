extends CanvasLayer
## Il riquadro dei dialoghi (il "balloon" di Dialogue Manager), con l'aspetto del menu di
## pausa: la finestra del titolo, il font pixel, il cuore che batte. In basso il testo che
## si scrive una lettera alla volta; a sinistra il viso di Lethe quando pensa lei (le righe
## del narratore non hanno ritratto); le scelte in una finestrella sopra, a destra.
##
## Tasti: interact (E, Z, Invio), ui_accept o clic: prima finisce di scrivere la riga, poi
## va avanti. Finché è aperto si prende tutto l'input (niente menu di pausa sotto).
##
## Le righe "che non vanno": dentro il testo [glitch], [shiver] e [flicker] (vedi
## text_effects.gd); una riga intera col tag [#wrong] si guasta e trema tutta, il riquadro
## sobbalza e le lamelle del carillon suonano scordate.
## Si crea con DialogueBox.new(), si aggiunge all'albero e si chiama start().

signal finished

const Style := preload("res://menu/menu_style.gd")
const HeartMenu := preload("res://ui/heart_menu.gd")
const Sfx := preload("res://core/sfx.gd")
const LABEL_SCENE := preload("res://addons/dialogue_manager/nodes/dialogue_label/dialogue_label.tscn")
const BLIP := preload("res://audio/ui_move.wav")
const TextEffects := preload("text_effects.gd")

## Il nome che ha il ritratto.
const HERO_NAME := "Lethe"
const LAYER := 50
const BOX_HEIGHT := 86
const MARGIN := 10
const FACE_SIZE := Vector2(64, 64)
const Settings := preload("res://core/settings_store.gd")
const TEXT_SECONDS_PER_STEP := 0.025
## Una lamella di carillon ogni tante lettere, piano e acuta.
const BLIP_EVERY := 3
const BLIP_DB := -22.0
## Il tag delle righe che non vanno, e come suonano: più basse e stonate.
const WRONG_TAG := "wrong"
const WRONG_PITCH := Vector2(0.55, 0.8)
## Il sobbalzo del riquadro: scatti di pixel interi.
const JOLT := [Vector2(3, 0), Vector2(-2, 1), Vector2(2, -1), Vector2(-1, 0), Vector2.ZERO]
const JOLT_STEP := 0.04

var resource: DialogueResource
var game_states: Array = []
var line: DialogueLine
## La riga è scritta tutta e aspetta un tasto (non vale mentre ci sono le scelte).
var waiting := false
## Muto per i test.
var sound := true

var root: Control
var box: PanelContainer
var face: TextureRect
var name_label: Label
var text_label: DialogueLabel
var next_heart: TextureRect
var choices_panel: PanelContainer
var choices: VBoxContainer
var _responses: Array = []
var _blink := 0.0
## La riga che si vede ora non va (tag [#wrong]).
var wrong := false
var _jolt: Tween


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## Comincia dal cue `cue` di `dialogue`. `states`: dove cercare variabili e funzioni.
func start(dialogue: DialogueResource, cue: String, states: Array = []) -> void:
	resource = dialogue
	game_states = states
	_show_line(await resource.get_next_dialogue_line(cue, game_states))


## Va alla riga dopo (o chiude, se era l'ultima).
func advance() -> void:
	if not is_instance_valid(line):
		return
	if text_label.is_typing:
		text_label.skip_typing()
	elif waiting:
		waiting = false
		_go(line.next_id)


## Sceglie la risposta numero `index` tra quelle visibili.
func choose(index: int) -> void:
	if index < 0 or index >= _responses.size():
		return
	choices_panel.hide()
	_go((_responses[index] as DialogueResponse).next_id)


## Le scritte delle risposte che si vedono ora (per i test).
func choice_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for r: DialogueResponse in _responses:
		out.append(r.text)
	return out


func _go(next_id: String) -> void:
	_show_line(await resource.get_next_dialogue_line(next_id, game_states))


func _show_line(next_line: DialogueLine) -> void:
	line = next_line
	if not is_instance_valid(line):
		finished.emit()
		queue_free()
		return
	waiting = false
	next_heart.hide()
	choices_panel.hide()
	var is_hero := line.character == HERO_NAME
	face.texture = Style.face() if is_hero else null
	face.visible = face.texture != null
	name_label.text = line.character
	name_label.visible = not line.character.is_empty()
	wrong = line.has_tag(WRONG_TAG)
	if wrong:
		line.text = "[shiver][glitch]%s[/glitch][/shiver]" % line.text
		jolt()
	text_label.dialogue_line = line
	box.show()
	if not line.text.is_empty():
		text_label.type_out()
		await text_label.finished_typing
	if line.responses.size() > 0:
		_show_choices()
	else:
		waiting = true


## Il riquadro sobbalza (a scatti di pixel interi) e torna al suo posto.
func jolt() -> void:
	if _jolt:
		_jolt.kill()
	_jolt = create_tween()
	for step: Vector2 in JOLT:
		_jolt.tween_callback(func() -> void: root.position = step)
		_jolt.tween_interval(JOLT_STEP)


func _show_choices() -> void:
	_responses = line.responses.filter(func(r: DialogueResponse) -> bool: return r.is_allowed)
	var entries: Array = []
	for i in _responses.size():
		entries.append([StringName(str(i)), (_responses[i] as DialogueResponse).text])
	choices.setup(entries, Style.FONT, Style.FONT_SIZE)
	choices_panel.show()
	choices.focus_first()


func _process(delta: float) -> void:
	_blink += delta
	next_heart.visible = waiting and fmod(_blink, 0.8) < 0.55


func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()        # sotto il dialogo non passa niente
	if event.is_echo():
		return
	var mouse := event as InputEventMouseButton
	var click := mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	var press := event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")
	if choices_panel.visible:
		# ui_accept e il clic li gestiscono i pulsanti; E / Z sceglie la voce col cuore.
		if event.is_action_pressed(&"interact") and choices.focused_id() != &"":
			choose(int(String(choices.focused_id())))
	elif press or click:
		advance()


func _on_spoke(letter: String, index: int, _speed: float) -> void:
	if sound and index % BLIP_EVERY == 0 and letter.strip_edges() != "":
		var pitch := randf_range(WRONG_PITCH.x, WRONG_PITCH.y) if wrong else randf_range(1.8, 2.1)
		Sfx.play(self, BLIP, pitch, BLIP_DB)


func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Style.theme()
	add_child(root)

	box = PanelContainer.new()
	box.name = "Box"
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = MARGIN
	box.offset_right = -MARGIN
	box.offset_top = -BOX_HEIGHT - MARGIN
	box.offset_bottom = -MARGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.hide()
	root.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	face = Style.picture(null, FACE_SIZE)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 0)
	row.add_child(column)
	name_label = Style.label("", Style.ACCENT)
	column.add_child(name_label)

	text_label = LABEL_SCENE.instantiate()
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.seconds_per_step = TEXT_SECONDS_PER_STEP * Settings.text_speed_scale()
	text_label.skip_action = &""
	text_label.add_theme_color_override(&"default_color", Style.TEXT)
	text_label.add_theme_font_override(&"normal_font", Style.FONT)
	text_label.add_theme_font_size_override(&"normal_font_size", Style.FONT_SIZE)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.spoke.connect(_on_spoke)
	TextEffects.install(text_label)
	column.add_child(text_label)

	# Il cuore in basso a destra: la riga è finita, si può andare avanti.
	var heart := HeartMenu.new()
	next_heart = TextureRect.new()
	next_heart.texture = heart.heart_frames[0]
	heart.free()
	next_heart.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	next_heart.offset_left = -MARGIN * 3 - 12
	next_heart.offset_top = -MARGIN * 3 - 10
	next_heart.offset_right = -MARGIN * 3
	next_heart.offset_bottom = -MARGIN * 3
	next_heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	next_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_heart.hide()
	root.add_child(next_heart)

	choices_panel = PanelContainer.new()
	choices_panel.name = "Choices"
	choices_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	choices_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	choices_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	choices_panel.offset_right = -MARGIN
	choices_panel.offset_bottom = -BOX_HEIGHT - MARGIN - 4
	choices_panel.hide()
	root.add_child(choices_panel)
	choices = HeartMenu.new()
	choices.chosen.connect(func(id: StringName) -> void: choose(int(String(id))))
	choices_panel.add_child(choices)
