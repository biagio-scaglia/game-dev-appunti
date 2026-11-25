extends RefCounted
## Crea le azioni di input se mancano, così il progetto funziona senza toccare la Input Map.
##
## Lo schema (pensato per una mano sola sulle lettere, e per chi gioca con le frecce):
## - move_*: WASD o frecce. Tenendo una direzione Lethe si mette a correre da sola
##   (protagonista.gd, auto_run_after); run (Shift) la fa correre subito.
## - action: Spazio (o Z, J, E, Invio, clic sinistro). Il tasto unico: davanti a una cosa ci
##   parla (talk.gd, "interact"), altrimenti la spada di vetro ("slash"). Va avanti nei
##   dialoghi. interact e slash sono la stessa cosa sotto: parlare ferma Lethe prima
##   che la spada parta.
## - cast: Q (o X, K, clic destro), la magia.
## - menu: Esc o C, il menu di pausa.
## - sword_stage: F2, solo per provare gli stadi della spada nelle build di debug.

## Spazio, Z, J, E, Invio e il clic sinistro fanno la stessa cosa (vedi sopra).
const ACTION_KEYS := [KEY_SPACE, KEY_Z, KEY_J, KEY_E, KEY_ENTER]

const ACTIONS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"run": [KEY_SHIFT],
	&"cast": [KEY_Q, KEY_X, KEY_K],
	&"slash": ACTION_KEYS,
	&"interact": ACTION_KEYS,
	&"sword_stage": [KEY_F2],
	&"menu": [KEY_ESCAPE, KEY_C],
}
const MOUSE := {
	&"slash": MOUSE_BUTTON_LEFT,
	&"interact": MOUSE_BUTTON_LEFT,
	&"cast": MOUSE_BUTTON_RIGHT,
}
## Come si scrivono i tasti principali nei suggerimenti a schermo.
const LABELS := {&"action": "Space", &"cast": "Q", &"menu": "Esc"}


static func ensure_actions() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		if MOUSE.has(action):
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE[action]
			InputMap.action_add_event(action, click)
