extends CanvasLayer
## Il menu di pausa, come in RPG Maker. Esc o X lo apre e ferma il gioco; Esc, X o il
## tasto destro del mouse tornano indietro. A sinistra le voci (Items, Spells, Equip,
## Status, Save, Load, Game End) col cuore che batte, sotto tempo di gioco, giorno e
## luogo; a destra la finestra grande, che cambia con la voce. In fondo la barra d'aiuto:
## cosa fa quello che si sta guardando, e quali tasti usare.
##
## Cose che non vanno: il gioco dietro si fa grigio e trema (menu_backdrop.gdshader), la
## musica rallenta e stona, le scritte si guastano per un attimo (menu_glitcher.gd; mai
## la barra d'aiuto), lo stato legge "Dead", a volte Lethe è di spalle, in fondo al gruppo
## c'è un sussurro, e il File 3 non è suo (save_view.gd).

signal opened
signal closed
## Game End -> To Title, a schermo già nero (prima di cambiare scena).
signal title_requested

const Data := preload("menu_data.gd")
const Style := preload("menu_style.gd")
const GameState := preload("game_state.gd")
const SaveStore := preload("save_store.gd")
const InputSetup := preload("res://core/input_setup.gd")

## Una volta su tante, aprendo il menu, il ritratto di Lethe è di spalle.
const AWAY_CHANCE := 0.125
const MUSIC_PITCH := 0.8
const MUSIC_DROP_DB := 6.0
const MESSAGE_TIME := 1.4

## La scena del titolo per Game End. Vuota = emette solo title_requested (per i test).
@export_file("*.tscn") var title_scene := "res://title/title_screen.tscn"

@onready var root: Control = %Root
@onready var backdrop: ColorRect = %Backdrop
@onready var fade: ColorRect = %Fade
@onready var commands: VBoxContainer = %Commands
@onready var time_label: Label = %TimeLabel
@onready var day_label: Label = %DayLabel
@onready var place_label: Label = %PlaceLabel
@onready var help_label: Label = %HelpLabel
@onready var keys_label: Label = %KeysLabel
@onready var party: VBoxContainer = %PartyView
@onready var status_view: VBoxContainer = %StatusView
@onready var items_view: VBoxContainer = %ItemsView
@onready var spells_view: VBoxContainer = %SpellsView
@onready var equip_view: HBoxContainer = %EquipView
@onready var save_view: VBoxContainer = %SaveView
@onready var end_view: VBoxContainer = %EndView
@onready var message: PanelContainer = %Message
@onready var message_label: Label = %MessageLabel
@onready var glitcher: Node = %Glitcher
@onready var sfx_move: AudioStreamPlayer = %SfxMove
@onready var sfx_confirm: AudioStreamPlayer = %SfxConfirm
@onready var sfx_wrong: AudioStreamPlayer = %SfxWrong

var state := GameState.new()
## La protagonista (un Node2D con `sword_stage`). Può mancare (test).
var hero: Node2D
var music: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
## La pagina aperta: &"" (le voci), &"items", &"spells", &"equip", &"status", &"save",
## &"load", &"end".
var view := &""
var _open := false
var _last_command := &"items"
var _music_pitch := 1.0
var _music_db := 0.0
var _message_tween: Tween


func _ready() -> void:
	InputSetup.ensure_actions()
	visible = false
	root.theme = Style.theme()
	message.hide()
	fade.color.a = 0.0
	for label in [time_label, help_label, keys_label]:
		label.set_meta(&"no_glitch", true)   # il tempo cambia ogni frame; l'aiuto deve leggersi
	commands.setup(Data.COMMANDS.map(func(c): return [c[0], c[1]]), Style.FONT, Style.FONT_SIZE)
	for c in Data.COMMANDS:
		commands.get_node(String(c[0])).focus_entered.connect(_help.bind(c[2], Data.KEYS_MAIN))
	commands.chosen.connect(_on_command)
	for list in [commands, items_view.list, spells_view.list, equip_view.slots, equip_view.items,
			save_view.list, end_view.list]:
		list.moved.connect(sfx_move.play)
	for v in [items_view, spells_view, equip_view]:
		v.described.connect(func(text): help_label.text = text)
	equip_view.equipped.connect(sfx_confirm.play)
	save_view.slot_chosen.connect(_on_slot)
	end_view.chosen.connect(_on_end)
	glitcher.rng = rng
	glitcher.targets = _glitch_targets
	glitcher.events.assign([_blink_dead, _shake])


func setup(game_state: GameState, hero_node: Node2D, music_player: AudioStreamPlayer) -> void:
	state = game_state
	hero = hero_node
	music = music_player


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	get_tree().paused = true
	visible = true
	party.hero.show_face(rng.randf() < AWAY_CHANCE)
	party.whisper.text = Data.WHISPERS[rng.randi() % Data.WHISPERS.size()]
	_refresh()
	_show(&"")
	commands.set_active(true)
	commands.focus_first()
	_last_command = &"items"
	sfx_confirm.play()
	root.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(root, "modulate:a", 1.0, 0.18)
	t.tween_method(_set_strength, 0.0, 1.0, 0.35)
	if music:
		_music_pitch = music.pitch_scale
		_music_db = music.volume_db
		t.tween_property(music, "pitch_scale", MUSIC_PITCH, 0.6)
		t.tween_property(music, "volume_db", _music_db - MUSIC_DROP_DB, 0.6)
	glitcher.start()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	glitcher.stop()
	visible = false
	message.hide()
	get_tree().paused = false
	if music:
		var t := create_tween().set_parallel()
		t.tween_property(music, "pitch_scale", _music_pitch, 0.4)
		t.tween_property(music, "volume_db", _music_db, 0.4)
	closed.emit()


## Indietro: dentro una pagina un passo alla volta, da una pagina alle voci, dalle voci
## si chiude.
func back() -> void:
	if view == &"":
		close()
		return
	sfx_move.play()
	if view == &"equip" and equip_view.back():
		return
	for v in [items_view, spells_view, equip_view, save_view, end_view]:
		v.leave()
	_show(&"")
	commands.set_active(true)
	commands.focus_id(_last_command)


## Sceglie una voce come se la si premesse (pubblico per i test).
func choose(id: StringName) -> void:
	_on_command(id)


func _process(delta: float) -> void:
	if not _open:
		return
	state.play_time += delta
	time_label.text = "Time  " + GameState.format_time(state.play_time)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed(&"menu") and not get_tree().paused:
			get_viewport().set_input_as_handled()
			open()
		return
	var right_click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_RIGHT
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"menu") or right_click:
		get_viewport().set_input_as_handled()
		back()


func _on_command(id: StringName) -> void:
	sfx_confirm.play()
	_last_command = id
	commands.set_active(false)
	match id:
		&"items":
			_show(id)
			items_view.enter()
		&"spells":
			_show(id)
			spells_view.enter()
		&"equip":
			_show(id)
			equip_view.enter()
		&"status":
			_show(id)
			_help("Everything about Lethe, at a glance.", Data.KEYS_VIEW)
		&"save", &"load":
			save_view.refresh(id)
			_show(id)
			save_view.enter()
			_help("Choose a file." if id == &"save" else "Choose a file to continue from.")
		&"end":
			_show(id)
			end_view.enter()
			_help("Unsaved progress will be lost.")
	if id != &"status":
		keys_label.text = Data.KEYS_PAGE


func _on_slot(slot: int) -> void:
	if slot == save_view.CURSED_SLOT:
		sfx_wrong.play()
		glitcher.burst()
		_say("This file is already in use." if view == &"save" else "...not yet.", true)
		return
	if view == &"save":
		SaveStore.write(slot, state.to_save(_hero_position(), _sword_stage()))
		sfx_confirm.play()
		save_view.refresh(&"save")
		save_view.enter()
		save_view.list.focus_id(StringName("slot%d" % slot))
		_say("Saved to File %d." % slot)
		return
	var data := SaveStore.read(slot)
	if data.is_empty():
		sfx_wrong.play()
		_say("There is nothing there.")
		return
	state.load_save(data)
	if hero:
		hero.global_position = GameState.saved_position(data)
		hero.set("sword_stage", int(data.get("sword_stage", 0)))
	sfx_confirm.play()
	close()


func _on_end(id: StringName) -> void:
	if id != &"title":
		back()
		return
	glitcher.stop()
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.8)
	if music:
		t.parallel().tween_property(music, "volume_db", -40.0, 0.8)
	await t.finished
	title_requested.emit()
	if title_scene != "":
		get_tree().paused = false
		get_tree().change_scene_to_file(title_scene)


func _show(new_view: StringName) -> void:
	view = new_view
	if view == &"":
		_refresh()   # quello che si è cambiato in una pagina si vede subito
	party.visible = view == &""
	status_view.visible = view == &"status"
	items_view.visible = view == &"items"
	spells_view.visible = view == &"spells"
	equip_view.visible = view == &"equip"
	save_view.visible = view in [&"save", &"load"]
	end_view.visible = view == &"end"


func _refresh() -> void:
	time_label.text = "Time  " + GameState.format_time(state.play_time)
	day_label.text = "Day  %d" % state.day
	place_label.text = state.place
	status_view.refresh(state, _sword_stage())
	status_view.hero.show_face(party.hero.is_away())
	items_view.refresh(_sword_stage())
	spells_view.refresh(state)
	equip_view.refresh(state, _sword_stage())


## La barra d'aiuto: cosa fa quello che si guarda, e i tasti.
func _help(text: String, keys := Data.KEYS_PAGE) -> void:
	help_label.text = text
	keys_label.text = keys


func help_text() -> String:
	return help_label.text


## Un messaggio a centro schermo, che sparisce da solo. `wrong`: in rosso.
func _say(text: String, wrong := false) -> void:
	message_label.text = text
	message_label.add_theme_color_override(&"font_color", Style.HP_COLOR if wrong else Style.TEXT)
	message.show()
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_TIME)
	_message_tween.tween_callback(message.hide)


func message_text() -> String:
	return message_label.text if message.visible else ""


func _glitch_targets() -> Array:
	var out := []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if (node is Label or node is Button) and node.is_visible_in_tree() \
				and not node.has_meta(&"no_glitch"):
			out.append(node)
	return out


func _blink_dead() -> void:
	(status_view if view == &"status" else party).hero.blink_dead()


func _shake() -> void:
	var t := create_tween()
	for x in [3.0, -2.0, 1.0, 0.0]:
		t.tween_property(root, "position:x", x, 0.03)


func _set_strength(v: float) -> void:
	(backdrop.material as ShaderMaterial).set_shader_parameter(&"strength", v)


func _hero_position() -> Vector2:
	return hero.global_position if hero else Vector2.ZERO


func _sword_stage() -> int:
	return int(hero.get("sword_stage")) if hero and hero.get("sword_stage") != null else 0
