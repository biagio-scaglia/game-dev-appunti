extends SceneTree
## Fa partire l'intro e salva uno screenshot a ogni istante di SHOTS.
## Uso (non headless, serve il renderer):
##   Godot.exe --path . -s res://tools/capture_frames.gd -- <cartella_output>

const SHOTS := [0.5, 1.3, 2.0, 2.75, 3.45, 3.9, 4.8, 5.9, 7.0]

var _time := 0.0
var _next := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var intro: Node = load("res://studio_intro/studio_intro.tscn").instantiate()
	intro.next_scene = ""   # resta sull'intro, così si vede anche il finale
	root.add_child(intro)


func _process(delta: float) -> bool:
	_time += delta
	if _next < SHOTS.size() and _time >= SHOTS[_next]:
		var img := root.get_texture().get_image()
		img.save_png("%s/frame_%02d_%.2fs.png" % [_out, _next, SHOTS[_next]])
		_next += 1
	return _next >= SHOTS.size()
