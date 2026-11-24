extends Control
## La schermata del titolo, dopo l'intro dello studio. È la scena del finale: Lethe di
## spalle davanti alla porta chiusa, la luna da una parte (il raggio dalla finestra) e la
## luce calda sotto la porta dall'altra, il vassoio intatto. Ogni tanto bussano.
##
## La prima volta che si gioca, prima di tutto, l'avviso sui contenuti (care_note.gd). Poi
## dal nero compaiono la scena, il titolo e il sottotitolo, poi il menu:
## Continue (solo se c'è un salvataggio) / New Game / Talk to Someone / Quit.
## Un tasto durante l'apparizione la salta. New Game: dissolvenza al nero, la cutscene
## (opening/), poi la stanza. Continue: dissolvenza al nero, poi la stanza. Talk to Someone: la pagina coi numeri d'aiuto. Quit: lo schermo si rompe
## come in un incubo (fx/screen_shatter.gd), poi si chiude.
## Musica: il lamento del giullare (carillon stonato, valzer lento).
##
## Pezzi: title_backdrop.gd (raggio e pulviscolo), title_figure.gd (Lethe), title_door.gd
## (la porta che bussa), title_name.gd (il titolo col nome nascosto), heart_menu.gd (il menu
## col cuore che batte), care_note.gd (avviso e aiuto). I disegni stanno in art/.

## Emesso quando si sceglie New Game o Continue, a schermo già nero (prima di cambiare scena).
signal start_requested
## Emesso a schermo rotto, prima di chiudere il gioco.
signal quit_requested

## Il titolo del gioco. Non è ancora deciso: si cambia qui.
@export var game_title := "ALETHEIA"
## Il nome nascosto nel titolo, che ogni tanto resta solo.
@export var hidden_name := "LETHE"
@export var tagline := "Death is a Lie"
## La scena del gioco. Vuota = resta qui ed emette solo start_requested (per i test).
@export_file("*.tscn") var next_scene := "res://main.tscn"
## La cutscene di New Game, prima della stanza (Continue la salta). Vuota = niente cutscene.
@export_file("*.tscn") var opening_scene := "res://opening/opening.tscn"
## Falso nei test: Quit rompe lo schermo ed emette quit_requested, ma non chiude.
@export var really_quit := true
## L'avviso sui contenuti la prima volta (falso nei test che non lo provano).
@export var show_warning := true

const Music := preload("res://core/music.gd")
const ScreenShatter := preload("res://fx/screen_shatter.gd")
const SaveStore := preload("res://menu/save_store.gd")
const SaveView := preload("res://menu/save_view.gd")
const Settings := preload("res://core/settings_store.gd")
const Main := preload("res://main.gd")
const CareNote := preload("care_note.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const MENU := [[&"continue", "Continue"], [&"start", "New Game"], [&"help", "Talk to Someone"],
	[&"quit", "Quit"]]
## Il flag delle impostazioni: l'avviso è già stato letto.
const WARNING_FLAG := "content_warning_seen"
## Di quanti pixel sale il titolo mentre compare.
const RISE := 6.0
const MUSIC_DB := -8.0
const FOOTER_ALPHA := 0.35

@onready var title_name: HBoxContainer = %TitleName
@onready var tagline_label: Label = %TaglineLabel
@onready var menu: VBoxContainer = %Menu
@onready var menu_panel: PanelContainer = %MenuPanel
@onready var footer: Label = %Footer
@onready var glow: TextureRect = %Glow
@onready var figure: Node2D = %Figure
@onready var door: Node2D = %Door
@onready var black: ColorRect = %Black
@onready var music: AudioStreamPlayer = %Music
@onready var sfx_move: AudioStreamPlayer = %SfxMove
@onready var sfx_confirm: AudioStreamPlayer = %SfxConfirm
@onready var _title_rest: Vector2 = title_name.position

var _revealed := false
var _leaving := false
var _reveal: Tween
var note: Control


func _ready() -> void:
	title_name.setup(game_title, hidden_name)
	tagline_label.text = tagline
	menu.setup(menu_entries(), FONT, 16)
	_center_menu.call_deferred()
	menu.chosen.connect(_on_chosen)
	menu.moved.connect(sfx_move.play)
	note = CareNote.new()
	add_child(note)
	note.closed.connect(_on_note_closed)
	_hide_all()
	_breathe(glow)
	if show_warning and not Settings.has_flag(WARNING_FLAG):
		note.open(&"warning")
		return
	_begin()


## Le voci del menu: Continue solo se c'è un salvataggio da riprendere.
static func menu_entries() -> Array:
	var has_save := not latest_save().is_empty()
	return MENU.filter(func(e: Array) -> bool: return e[0] != &"continue" or has_save)


## Il salvataggio più recente (il File 3 non è di Lethe: non conta). {} se non ce n'è.
static func latest_save() -> Dictionary:
	var best: Dictionary = {}
	for slot in range(1, SaveStore.SLOTS + 1):
		if slot == SaveView.CURSED_SLOT:
			continue
		var data := SaveStore.read(slot)
		if not data.is_empty() and int(data.get("saved_at", 0)) >= int(best.get("saved_at", -1)):
			best = data
	return best


## Il pannello cresce con le voci: lo si rimette al centro dello schermo.
func _center_menu() -> void:
	menu_panel.reset_size()
	menu_panel.position.x = roundf((size.x - menu_panel.size.x) / 2.0)


func _begin() -> void:
	Music.play_loop(music)
	_play_reveal()


func _on_note_closed(kind: StringName) -> void:
	match kind:
		&"warning":
			Settings.set_flag(WARNING_FLAG)
			_begin()
		&"help":
			menu.set_active(true)
			menu.focus_id(&"help")


func is_revealed() -> bool:
	return _revealed


func _hide_all() -> void:
	black.color.a = 1.0
	title_name.modulate.a = 0.0
	title_name.position = _title_rest + Vector2(0, RISE)
	tagline_label.modulate.a = 0.0
	figure.modulate.a = 0.0
	door.modulate.a = 0.0
	footer.modulate.a = 0.0
	menu_panel.modulate.a = 0.0
	menu_panel.visible = false
	music.volume_db = -40.0


## L'alone dietro il titolo respira piano, all'infinito.
func _breathe(node: CanvasItem) -> void:
	var t := create_tween().set_loops()
	t.tween_property(node, "modulate:a", 0.6, 3.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "modulate:a", 1.0, 3.2).set_trans(Tween.TRANS_SINE)


func _play_reveal() -> void:
	# La musica sale per conto suo: non deve allungare la sequenza.
	create_tween().tween_property(music, "volume_db", MUSIC_DB, 2.5)
	_reveal = create_tween()
	_reveal.tween_property(black, "color:a", 0.0, 1.2)
	_reveal.parallel().tween_property(figure, "modulate:a", 1.0, 1.0).set_delay(0.2)
	_reveal.parallel().tween_property(door, "modulate:a", 1.0, 1.4).set_delay(0.4)
	_reveal.tween_property(title_name, "modulate:a", 1.0, 1.0)
	_reveal.parallel().tween_property(title_name, "position", _title_rest, 1.0) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reveal.tween_property(tagline_label, "modulate:a", 0.8, 0.6)
	_reveal.tween_callback(_show_menu)


## Salta l'apparizione: tutto subito al suo posto.
func skip_reveal() -> void:
	if _revealed:
		return
	if _reveal:
		_reveal.kill()
	black.color.a = 0.0
	music.volume_db = MUSIC_DB
	figure.modulate.a = 1.0
	door.modulate.a = 1.0
	title_name.modulate.a = 1.0
	title_name.position = _title_rest
	tagline_label.modulate.a = 0.8
	_show_menu()


func _show_menu() -> void:
	_revealed = true
	menu_panel.visible = true
	var t := create_tween().set_parallel()
	t.tween_property(menu_panel, "modulate:a", 1.0, 0.5)
	t.tween_property(footer, "modulate:a", FOOTER_ALPHA, 1.0)
	menu.focus_first()
	door.knocking_enabled = true


func _unhandled_input(event: InputEvent) -> void:
	if _revealed or _leaving or note.is_open():
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton \
		or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		skip_reveal()


func _on_chosen(id: StringName) -> void:
	sfx_confirm.play()
	match id:
		&"continue":
			continue_game()
		&"start":
			Main.pending_save = {}
			start_game()
		&"help":
			open_help()
		&"quit":
			quit_game()


## Talk to Someone: la pagina coi numeri; il menu aspetta sotto.
func open_help() -> void:
	if _leaving or note.is_open():
		return
	menu.set_active(false)
	note.open(&"help")


## Continue: come New Game, ma la stanza riparte dal salvataggio più recente.
func continue_game() -> void:
	var data := latest_save()
	if data.is_empty():
		return
	Main.pending_save = data
	start_game()


## New Game: dissolvenza al nero (anche la musica), poi la stanza.
func start_game() -> void:
	if _leaving:
		return
	_leaving = true
	door.knocking_enabled = false
	var t := create_tween().set_parallel()
	t.tween_property(black, "color:a", 1.0, 1.2)
	t.tween_property(music, "volume_db", -40.0, 1.2)
	await t.finished
	start_requested.emit()
	var target := scene_after_start()
	if target != "":
		get_tree().change_scene_to_file(target)


## Dove si va dopo: New Game passa dalla cutscene, Continue va dritto nella stanza.
func scene_after_start() -> String:
	if next_scene == "":
		return ""
	return opening_scene if Main.pending_save.is_empty() and opening_scene != "" else next_scene


## Quit: lo schermo si rompe partendo dalla voce, i pezzi cadono nel buio, poi si chiude.
func quit_game() -> void:
	if _leaving:
		return
	_leaving = true
	var shatter := ScreenShatter.new()
	add_child(shatter)
	shatter.play(menu.entry_point(&"quit"), music)
	await shatter.finished
	quit_requested.emit()
	if really_quit:
		get_tree().quit()
