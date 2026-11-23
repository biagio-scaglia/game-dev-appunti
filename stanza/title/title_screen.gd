extends Control
## La schermata del titolo, dopo l'intro dello studio. Dal nero compaiono il raggio di
## luna con Lethe di spalle, il titolo e il sottotitolo, poi il menu (Start / Quit).
## Un tasto durante l'apparizione la salta. Start: dissolvenza al nero, poi la stanza.
## Quit: lo schermo si rompe come in un incubo (fx/screen_shatter.gd), poi si chiude.
## Musica: il lamento del giullare (carillon stonato, valzer lento).
##
## Pezzi: title_backdrop.gd (raggio e pulviscolo), title_figure.gd (Lethe),
## title_name.gd (il titolo col nome nascosto), heart_menu.gd (il menu col cuore che batte).
## I disegni (finestra, pavimento, pannello, cuore, ornamento) stanno in art/.

## Emesso quando si sceglie Start, a schermo già nero (prima di cambiare scena).
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
## Falso nei test: Quit rompe lo schermo ed emette quit_requested, ma non chiude.
@export var really_quit := true

const Music := preload("res://core/music.gd")
const ScreenShatter := preload("res://fx/screen_shatter.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const MENU := [[&"start", "Start"], [&"quit", "Quit"]]
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
@onready var black: ColorRect = %Black
@onready var music: AudioStreamPlayer = %Music
@onready var sfx_move: AudioStreamPlayer = %SfxMove
@onready var sfx_confirm: AudioStreamPlayer = %SfxConfirm
@onready var _title_rest: Vector2 = title_name.position

var _revealed := false
var _leaving := false
var _reveal: Tween


func _ready() -> void:
	title_name.setup(game_title, hidden_name)
	tagline_label.text = tagline
	menu.setup(MENU, FONT, 16)
	menu.chosen.connect(_on_chosen)
	menu.moved.connect(sfx_move.play)
	_hide_all()
	Music.play_loop(music)
	_breathe(glow)
	_play_reveal()


func is_revealed() -> bool:
	return _revealed


func _hide_all() -> void:
	black.color.a = 1.0
	title_name.modulate.a = 0.0
	title_name.position = _title_rest + Vector2(0, RISE)
	tagline_label.modulate.a = 0.0
	figure.modulate.a = 0.0
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


func _unhandled_input(event: InputEvent) -> void:
	if _revealed or _leaving:
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton \
		or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		skip_reveal()


func _on_chosen(id: StringName) -> void:
	sfx_confirm.play()
	match id:
		&"start":
			start_game()
		&"quit":
			quit_game()


## Start: dissolvenza al nero (anche la musica), poi la stanza.
func start_game() -> void:
	if _leaving:
		return
	_leaving = true
	var t := create_tween().set_parallel()
	t.tween_property(black, "color:a", 1.0, 1.2)
	t.tween_property(music, "volume_db", -40.0, 1.2)
	await t.finished
	start_requested.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)


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
