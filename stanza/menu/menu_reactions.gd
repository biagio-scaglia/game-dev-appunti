extends Node
## Le reazioni del menu quando qualcosa non va:
## - deny(): si è scelta una cosa che non si può (un incantesimo non imparato, usare un
##   oggetto, uno slot vuoto). Un "no" basso e scordato, la voce si fa rossa, la finestra
##   sobbalza; a volte sopra tutto compare "STOP." con un sussurro.
## - after_save(): dopo un salvataggio, a volte succede qualcosa (SAVE_EVENTS): bussano
##   alla porta, il file per un attimo diventa un altro, qualcuno ti ha vista.

## Per i test: cosa è successo (&"deny" o uno di SAVE_EVENTS).
signal happened(event: StringName)

const Sfx := preload("res://core/sfx.gd")
const Style := preload("menu_style.gd")
const DENY_SOUND := preload("res://audio/menu_deny.wav")
const STOP_WORDS := ["STOP.", "DON'T.", "NO."]
const SAVE_EVENTS := [&"knock", &"stolen_file", &"watched"]
## Il file salvato, per un attimo: non è il suo.
const STOLEN_TEXT := "File %d   ????   Day 0   ??:??:??"

var stop_chance := 0.35
var save_event_chance := 0.35
var rng := RandomNumberGenerator.new()
## La finestra che sobbalza, i suoni di sottofondo, e chi scrive i messaggi:
## say.call(testo, rosso).
var root: Control
var ambience: Node
var say: Callable
var stop_label: Label


func setup(root_control: Control, ambience_node: Node, say_func: Callable) -> void:
	root = root_control
	ambience = ambience_node
	say = say_func
	stop_label = Label.new()
	stop_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stop_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stop_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	stop_label.add_theme_font_size_override(&"font_size", 64)
	stop_label.add_theme_color_override(&"font_color", Style.HP_COLOR)
	stop_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	stop_label.add_theme_constant_override(&"outline_size", 8)
	stop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stop_label.set_meta(&"no_glitch", true)
	stop_label.hide()
	root.add_child(stop_label)


## Non si può. `target`: la voce scelta, che si fa rossa.
func deny(target: Control = null) -> void:
	Sfx.play(self, DENY_SOUND, rng.randf_range(0.9, 1.1), -4.0)
	if target:
		target.modulate = Color(1.7, 0.35, 0.45)
		create_tween().tween_property(target, "modulate", Color.WHITE, 0.4)
	jolt()
	if rng.randf() < stop_chance:
		stop_word()
	happened.emit(&"deny")


## La finestra sobbalza di lato.
func jolt() -> void:
	var t := create_tween()
	for x in [4.0, -4.0, 3.0, -2.0, 0.0]:
		t.tween_property(root, "position:x", x, 0.03)


## Una parola enorme in mezzo allo schermo, per un attimo.
func stop_word() -> void:
	stop_label.text = STOP_WORDS[rng.randi() % STOP_WORDS.size()]
	stop_label.show()
	if ambience:
		ambience.play(&"whisper", -4.0)
	await get_tree().create_timer(0.22).timeout
	stop_label.hide()


## Dopo un salvataggio nello slot `slot` (`button`: la sua voce). `event` vuoto: a caso,
## e il più delle volte niente. Rende l'evento scelto.
func after_save(slot: int, button: Button, event := &"") -> StringName:
	if event == &"":
		if rng.randf() >= save_event_chance:
			return &""
		event = SAVE_EVENTS[rng.randi() % SAVE_EVENTS.size()]
	_run_save_event(event, slot, button)
	return event


func _run_save_event(event: StringName, slot: int, button: Button) -> void:
	match event:
		&"knock":
			if ambience:
				ambience.play(&"knock", -2.0)
			await get_tree().create_timer(1.7).timeout
			say.call("...someone is at the door.", true)
		&"stolen_file":
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(button):
				var real := button.text
				button.text = STOLEN_TEXT % slot
				button.modulate = Color(1.5, 0.4, 0.5)
				await get_tree().create_timer(0.7).timeout
				if is_instance_valid(button):
					button.text = real
					button.modulate = Color.WHITE
		&"watched":
			await get_tree().create_timer(1.0).timeout
			if ambience:
				ambience.play(&"breath", -4.0)
			say.call("She saw you save.", true)
	happened.emit(event)
