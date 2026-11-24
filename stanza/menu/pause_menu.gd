extends CanvasLayer
## Il menu di pausa, come in RPG Maker. Esc o X lo apre e ferma il gioco; Esc, X o il
## tasto destro del mouse tornano indietro. A sinistra le voci col cuore che batte e sotto
## tempo di gioco, giorno e luogo; a destra la pagina della voce scelta; in fondo la barra
## d'aiuto (cosa fa quello che si guarda, e quali tasti usare).
##
## Questo script tiene insieme i pezzi e decide quale pagina si vede. Il resto sta altrove:
## - le pagine: party_view, items_view, spells_view, equip_view, status_view, save_view,
##   end_view (le liste estendono menu_page.gd);
## - cosa non va: menu_glitcher.gd (scritte guaste), menu_ambience.gd (bussano, sussurri,
##   respiri), menu_reactions.gd (il "no" e gli eventi dopo un salvataggio),
##   menu_backdrop.gdshader (il gioco grigio dietro), fx/screen_shatter.gd (Game End).

signal opened
signal closed
## Game End -> To Title, a schermo già rotto (prima di cambiare scena).
signal title_requested

const Data := preload("menu_data.gd")
const Style := preload("menu_style.gd")
const GameState := preload("game_state.gd")
const SaveStore := preload("save_store.gd")
const InputSetup := preload("res://core/input_setup.gd")
const ScreenShatter := preload("res://fx/screen_shatter.gd")

## Una volta su tante, aprendo il menu, il ritratto di Lethe è di spalle.
const AWAY_CHANCE := 0.125
const MUSIC_PITCH := 0.8
const MUSIC_DROP_DB := 6.0
const MESSAGE_TIME := 1.6

## La scena del titolo per Game End. Vuota = emette solo title_requested (per i test).
@export_file("*.tscn") var title_scene := "res://title/title_screen.tscn"

@onready var root: Control = %Root
@onready var backdrop: ColorRect = %Backdrop
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
@onready var ambience: Node = %Ambience
@onready var reactions: Node = %Reactions
@onready var sfx_move: AudioStreamPlayer = %SfxMove
@onready var sfx_confirm: AudioStreamPlayer = %SfxConfirm

var state := GameState.new()
## La protagonista (un Node2D con `sword_stage`). Può mancare (test).
var hero: Node2D
var music: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
## La pagina aperta: &"" (le voci), &"items", &"spells", &"equip", &"status", &"save",
## &"load", &"end".
var view := &""
var _open := false
var _leaving := false
var _last_command := &"items"
var _music_pitch := 1.0
var _music_db := 0.0
var _message_tween: Tween


func _ready() -> void:
	InputSetup.ensure_actions()
	visible = false
	root.theme = Style.theme()
	message.hide()
	for label in [time_label, help_label, keys_label]:
		label.set_meta(&"no_glitch", true)   # il tempo cambia ogni frame; l'aiuto deve leggersi
	_build_commands()
	for list in [commands, items_view.list, spells_view.list, equip_view.slots, equip_view.items,
			save_view.list, end_view.list]:
		list.moved.connect(sfx_move.play)
	for page in [items_view, spells_view, equip_view]:
		page.described.connect(func(text): help_label.text = text)
	for page in [items_view, spells_view, equip_view]:
		page.denied.connect(_deny)
	equip_view.equipped.connect(sfx_confirm.play)
	save_view.slot_chosen.connect(_on_slot)
	end_view.chosen.connect(_on_end)
	for node in [glitcher, ambience, reactions]:
		node.rng = rng
	glitcher.root = root
	glitcher.events.assign([_blink_dead, reactions.jolt])
	reactions.setup(root, ambience, _say)


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
	ambience.start()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	glitcher.stop()
	ambience.stop()
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
	if _leaving:
		return
	if view == &"":
		close()
		return
	sfx_move.play()
	if view == &"equip" and equip_view.back():
		return
	for page in [items_view, spells_view, equip_view, save_view, end_view]:
		page.leave()
	_show(&"")
	commands.set_active(true)
	commands.focus_id(_last_command)


## Sceglie una voce come se la si premesse (pubblico per i test).
func choose(id: StringName) -> void:
	_on_command(id)


func help_text() -> String:
	return help_label.text


func message_text() -> String:
	return message_label.text if message.visible else ""


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


# --- Voci e pagine ---

func _build_commands() -> void:
	commands.setup(Data.COMMANDS.map(func(c): return [c[0], c[1]]), Style.FONT, Style.FONT_SIZE)
	for c in Data.COMMANDS:
		commands.get_node(String(c[0])).focus_entered.connect(_help.bind(c[2], Data.KEYS_MAIN))
	commands.chosen.connect(_on_command)


func _on_command(id: StringName) -> void:
	sfx_confirm.play()
	_last_command = id
	commands.set_active(false)
	_show(id)
	match id:
		&"items":
			items_view.enter()
		&"spells":
			spells_view.enter()
		&"equip":
			equip_view.enter()
		&"status":
			_help("Everything about Lethe, at a glance.", Data.KEYS_VIEW)
		&"save", &"load":
			save_view.refresh(id)
			save_view.enter()
			_help("Choose a file." if id == &"save" else "Choose a file to continue from.")
		&"end":
			end_view.enter()
			_help("Unsaved progress will be lost.")
	if id != &"status":
		keys_label.text = Data.KEYS_PAGE


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
	items_view.refresh(_sword_stage(), state.owns("glass_sword"))
	spells_view.refresh(state)
	equip_view.refresh(state, _sword_stage())


# --- Salvare, caricare, uscire ---

func _on_slot(slot: int) -> void:
	var button: Button = save_view.slot_button(slot)
	if slot == save_view.CURSED_SLOT:
		reactions.deny(button)
		glitcher.burst()
		_say("This file is already in use." if view == &"save" else "...not yet.", true)
		return
	if view == &"save":
		SaveStore.write(slot, state.to_save(_hero_position(), _sword_stage()))
		sfx_confirm.play()
		save_view.refresh(&"save")
		save_view.enter(save_view.slot_id(slot))
		_say("Saved to File %d." % slot)
		reactions.after_save(slot, save_view.slot_button(slot))
		return
	var data := SaveStore.read(slot)
	if data.is_empty():
		reactions.deny(button)
		_say("There is nothing there.", true)
		return
	state.load_save(data)
	if hero:
		hero.global_position = GameState.saved_position(data)
		hero.set("sword_stage", int(data.get("sword_stage", 0)))
	sfx_confirm.play()
	close()


## Game End -> To Title: lo schermo si rompe come al Quit del titolo, poi il titolo.
func _on_end(id: StringName) -> void:
	if id != &"title":
		back()
		return
	_leaving = true
	glitcher.stop()
	ambience.stop()
	var shatter := ScreenShatter.new()
	add_child(shatter)
	shatter.play(end_view.list.entry_point(&"title"), music)
	await shatter.finished
	title_requested.emit()
	if title_scene != "":
		get_tree().paused = false
		get_tree().change_scene_to_file(title_scene)


# --- Aiuto, messaggi, effetti ---

## La barra d'aiuto: cosa fa quello che si guarda, e i tasti.
func _help(text: String, keys := Data.KEYS_PAGE) -> void:
	help_label.text = text
	keys_label.text = keys


## Si è scelta una cosa che non si può: la reazione, e il perché nella barra d'aiuto.
func _deny(reason: String) -> void:
	reactions.deny(get_viewport().gui_get_focus_owner())
	help_label.text = reason


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


func _blink_dead() -> void:
	(status_view if view == &"status" else party).hero.blink_dead()


func _set_strength(v: float) -> void:
	(backdrop.material as ShaderMaterial).set_shader_parameter(&"strength", v)


func _hero_position() -> Vector2:
	return hero.global_position if hero else Vector2.ZERO


func _sword_stage() -> int:
	return int(hero.get("sword_stage")) if hero and hero.get("sword_stage") != null else 0
