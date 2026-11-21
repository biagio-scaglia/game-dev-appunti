extends Control
## L'intro dello studio, da mettere all'inizio di ogni gioco. Circa 7 secondi.
##
## Questo script è solo il regista: decide chi fa cosa e quando. I pezzi:
##   logo/moon_logo.gd      la luna (sale, cresce, brilla, guarda)
##   logo/moon_eye.gd       l'occhio che si apre sulla luna piena
##   fx/starfield.gd        le stelle e la stella cadente
##   fx/moon_glade.gd       il riflesso della luna sul lago
##   fx/intro_fx.gd         le scintille
##   title/intro_title.gd   il nome scritto lettera per lettera e il sottotitolo
##   core/                  input da saltare, fogli di sprite, avviso per il web
##
## Per riusarla: copia la cartella studio_intro/ nel gioco e imposta next_scene,
## oppure istanzia la scena e ascolta finished. Vedi README.md qui accanto.

## Emesso a intro finita (o saltata), con lo schermo già nero.
signal finished

## Il nome dello studio. Quando avrai un nome vero, cambialo qui.
@export var studio_name := "BIAGIO SCAGLIA"
## La riga sotto il nome. Vuota = niente sottotitolo.
@export var subtitle := "presenta"
## Se true, la luna piena apre l'occhio e ti guarda. È la firma dello studio.
@export var moon_watches := true
## Se false, niente musica (restano gli effetti sonori).
@export var play_music := true
## La scena da caricare a fine intro. Vuota = resta qui ed emette solo finished.
@export_file("*.tscn") var next_scene := ""
## Se false, i tasti non saltano l'intro (utile per registrare un video).
@export var skippable := true

const SkipInput := preload("core/skip_input.gd")
const StartPrompt := preload("core/start_prompt.gd")
const IntroFx := preload("fx/intro_fx.gd")

## Angoli (in gradi) dei punti sul bordo della luna dove spuntano le scintille.
const SPARKLE_ANGLES := [-40.0, 200.0, 20.0, 150.0]

@onready var moon: Node2D = %Moon
@onready var stars: Node2D = %Stars
@onready var glade: Node2D = %Glade
@onready var title: Control = %Title
@onready var center: Control = %Center
@onready var black: ColorRect = %Black
@onready var music: AudioStreamPlayer = %Music

var _done := false
var _waiting_start := false
var _start_label: Label

## Sul web basta chiedere il clic una volta: poi l'audio resta sbloccato.
static var _audio_unlocked := false


func _ready() -> void:
	title.setup(studio_name, subtitle)
	black.color.a = 1.0
	if OS.has_feature("web") and not _audio_unlocked:
		_waiting_start = true
		_start_label = StartPrompt.show_on(self, title.name_label.get_theme_font(&"font"))
		return
	_play()


func is_done() -> bool:
	return _done


func _unhandled_input(event: InputEvent) -> void:
	if _done or not SkipInput.is_skip(event):
		return
	get_viewport().set_input_as_handled()
	if _waiting_start:
		_waiting_start = false
		_audio_unlocked = true
		_start_label.queue_free()
		_play()
	else:
		skip()


## Salta l'intro (se permesso): dissolvenza veloce e fine.
func skip() -> void:
	if skippable:
		finish(0.25)


## Aspetta t secondi. False se nel frattempo l'intro è finita o saltata.
func _wait(t: float) -> bool:
	await get_tree().create_timer(t).timeout
	return not _done


func _play() -> void:
	# 1. Dal nero alla notte; le stelle si accendono. La musica è scritta su questi tempi.
	if play_music:
		music.play()
	create_tween().tween_property(black, "color:a", 0.0, 0.6)
	stars.light_up(1.6)
	if not await _wait(0.4): return

	# 2. La luna sale, ancora nuova, e il lago comincia a rifletterla. Poi cresce.
	glade.fade_to(0.35, 0.9)
	await moon.rise(36.0, 0.9)
	if _done: return
	await moon.wax(1.2)
	if _done: return

	# 3. Luna piena: brilla, scintille sul bordo, passa una stella cadente.
	moon.shine()
	glade.fade_to(1.0, 0.4)
	IntroFx.sparkle_burst(center, _sparkle_points(), 0.14)
	stars.shoot()
	if not await _wait(0.55): return

	# 4. La luna apre l'occhio e ti guarda; il riflesso si stringe finché guarda.
	if moon_watches:
		glade.fade_to(0.45, 0.3)
		await moon.watch(0.65)
		if _done: return
		glade.fade_to(1.0, 0.4)
		if not await _wait(0.15): return

	# 5. Il nome, poi il sottotitolo.
	await title.type_name()
	if _done: return
	await title.show_subtitle()
	if not await _wait(1.4): return
	finish(0.6)


func _sparkle_points() -> Array:
	var points := []
	for deg: float in SPARKLE_ANGLES:
		points.append(moon.rim_point(deg_to_rad(deg)))
	return points


## Fine: dissolvenza al nero, segnale, e la scena successiva se c'è.
func finish(fade: float) -> void:
	if _done:
		return
	_done = true
	var t := create_tween().set_parallel()
	t.tween_property(black, "color:a", 1.0, fade)
	t.tween_property(music, "volume_db", -40.0, fade)   # la musica sfuma col nero
	await t.finished
	music.stop()
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
