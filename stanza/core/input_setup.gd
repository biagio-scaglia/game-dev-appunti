extends RefCounted
## Crea le azioni di input se mancano: move_* (WASD e frecce), run (Shift),
## cast (Spazio o J). Così il progetto funziona senza toccare la Input Map a mano.

const ACTIONS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"run": [KEY_SHIFT],
	&"cast": [KEY_SPACE, KEY_J],
}


static func ensure_actions() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
