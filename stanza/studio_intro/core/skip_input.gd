extends RefCounted
## Decide quali input contano come "salta" (o, sul web, come "inizia").

## Tasti che non saltano: volume e multimedia (li premi per sentire meglio),
## modificatori e simili.
const IGNORED_KEYS := [
	KEY_VOLUMEUP, KEY_VOLUMEDOWN, KEY_VOLUMEMUTE,
	KEY_MEDIAPLAY, KEY_MEDIASTOP, KEY_MEDIAPREVIOUS, KEY_MEDIANEXT, KEY_MEDIARECORD,
	KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK,
	KEY_PRINT, KEY_UNKNOWN,
]


## True per un tasto premuto (non ripetuto e non in IGNORED_KEYS), un clic
## (non la rotella) o un pulsante del joypad.
static func is_skip(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode not in IGNORED_KEYS
	if event is InputEventMouseButton:
		return event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	if event is InputEventJoypadButton:
		return event.pressed
	return false
