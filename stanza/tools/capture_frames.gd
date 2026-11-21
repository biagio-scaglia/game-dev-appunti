extends SceneTree
## Avvia main.tscn, fa camminare la protagonista e lanciare due magie, e salva uno
## screenshot ogni tanto. Non headless (serve il renderer per luci e blend additivo).
## Uso: Godot.exe --path . -s res://tools/capture_frames.gd -- <cartella_output> [fitto]
## Con "fitto" scatta ogni 0,08 s (per montare una GIF).

## (secondo, azioni premute)
const SCRIPT := [
	[0.0, []],
	[0.3, [&"move_right"]],
	[1.0, [&"move_down", &"move_right", &"run"]],
	[1.5, []],
	[1.6, [&"cast"]],
	[1.7, []],
	[3.0, [&"move_left"]],
	[3.4, []],
	[3.5, [&"cast"]],
	[3.6, []],
]
const SHOTS := [0.2, 0.9, 1.4, 1.95, 2.2, 2.45, 3.8, 4.05]
const DENSE_STEP := 0.08
const DENSE_END := 4.6

var _shots: Array = SHOTS
var _time := 0.0
var _shot := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	if args.size() > 1 and args[1] == "fitto":
		_shots = []
		var t := 0.2
		while t < DENSE_END:
			_shots.append(t)
			t += DENSE_STEP
	root.add_child(load("res://main.tscn").instantiate())


func _process(delta: float) -> bool:
	_time += delta
	_apply_input()
	if _shot < _shots.size() and _time >= _shots[_shot]:
		root.get_texture().get_image().save_png("%s/shot_%03d.png" % [_out, _shot])
		_shot += 1
	return _shot >= _shots.size()


func _apply_input() -> void:
	var pressed: Array = []
	for step in SCRIPT:
		if _time >= step[0]:
			pressed = step[1]
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"run", &"cast"]:
		if not InputMap.has_action(action):
			continue
		if action in pressed:
			Input.action_press(action)
		else:
			Input.action_release(action)
