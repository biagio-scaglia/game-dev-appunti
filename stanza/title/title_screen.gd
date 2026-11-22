extends Control
## La schermata del titolo, dopo l'intro dello studio. Dal nero compaiono il titolo e
## il sottotitolo, poi il menu (Start / Quit). Un tasto durante l'apparizione la salta.
## Start: dissolvenza al nero e si entra nella stanza.
##
## Pezzi: title_backdrop.gd (raggio di luna e pulviscolo), title_menu.gd (il menu).

## Emesso quando si sceglie Start, a schermo già nero (prima di cambiare scena).
signal start_requested

## Il titolo del gioco. Non è ancora deciso: si cambia qui.
@export var game_title := "ALETHEIA"
@export var tagline := "Death is a Lie"
## La scena del gioco. Vuota = resta qui ed emette solo start_requested (per i test).
@export_file("*.tscn") var next_scene := "res://main.tscn"

const Music := preload("res://core/music.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const MENU := [[&"start", "Start"], [&"quit", "Quit"]]
## Di quanti pixel sale il titolo mentre compare.
const RISE := 6.0

@onready var title_label: Label = %TitleLabel
@onready var tagline_label: Label = %TaglineLabel
@onready var menu: VBoxContainer = %Menu
@onready var black: ColorRect = %Black
@onready var music: AudioStreamPlayer = %Music
@onready var _title_rest: Vector2 = title_label.position

var _revealed := false
var _leaving := false
var _reveal: Tween


func _ready() -> void:
	title_label.text = game_title
	tagline_label.text = tagline
	menu.setup(MENU, FONT, 16)
	menu.chosen.connect(_on_chosen)
	_hide_all()
	Music.play_loop(music)
	_play_reveal()


func is_revealed() -> bool:
	return _revealed


func _hide_all() -> void:
	black.color.a = 1.0
	title_label.modulate.a = 0.0
	title_label.position = _title_rest + Vector2(0, RISE)
	tagline_label.modulate.a = 0.0
	menu.modulate.a = 0.0
	menu.visible = false
	music.volume_db = -40.0


func _play_reveal() -> void:
	_reveal = create_tween()
	_reveal.tween_property(black, "color:a", 0.0, 1.0)
	_reveal.parallel().tween_property(music, "volume_db", -10.0, 2.0)
	_reveal.tween_property(title_label, "modulate:a", 1.0, 1.2)
	_reveal.parallel().tween_property(title_label, "position", _title_rest, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reveal.tween_property(tagline_label, "modulate:a", 0.8, 0.8)
	_reveal.tween_callback(_show_menu)


## Salta l'apparizione: tutto subito al suo posto.
func skip_reveal() -> void:
	if _revealed:
		return
	if _reveal:
		_reveal.kill()
	black.color.a = 0.0
	music.volume_db = -10.0
	title_label.modulate.a = 1.0
	title_label.position = _title_rest
	tagline_label.modulate.a = 0.8
	_show_menu()


func _show_menu() -> void:
	_revealed = true
	menu.visible = true
	create_tween().tween_property(menu, "modulate:a", 1.0, 0.5)
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
	match id:
		&"start":
			start_game()
		&"quit":
			get_tree().quit()


## Start: dissolvenza al nero (anche la musica), poi la stanza.
func start_game() -> void:
	if _leaving:
		return
	_leaving = true
	var t := create_tween().set_parallel()
	t.tween_property(black, "color:a", 1.0, 0.8)
	t.tween_property(music, "volume_db", -40.0, 0.8)
	await t.finished
	start_requested.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
