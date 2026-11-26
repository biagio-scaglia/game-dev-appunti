extends Node2D
## Un occhio nelle radici (passo 4 del dungeon; vault: "Riferimenti e ispirazioni"). Sta
## chiuso nella parete. Quando Lethe è vicina e intorno è buio si apre piano e la segue con la
## pupilla; una luce vicina (gruppo "lure": la magia, una lanterna accesa) lo fa chiudere di
## colpo. Non fa male: guarda e basta. Non lo spegne il buio della zona (materiale
## unshaded): al buio si vede proprio lui. Sta nella parete, sotto Lethe (è figlio delle piante
## basse, non del mondo): lei non ci passa mai sopra né davanti. Aprendosi fa un suono umido e
## basso (si sente solo vicino); aperto, ogni tanto sbatte la palpebra.
##
## Disegnato qui, a blocchi di PX pixel, come Selene.

const LightCatch := preload("res://magic/light_catch.gd")
const OPEN_SOUND := preload("res://audio/eye_open.wav")

## Tre fotogrammi, 7 x 5: chiuso, socchiuso, aperto. o palpebra, w bianco, i iride.
const FRAMES := [
	[".......", ".......", "ooooooo", ".......", "......."],
	[".......", "..ooo..", ".owiwo.", "..ooo..", "......."],
	["..ooo..", ".owwwo.", "owwiwwo", ".owwwo.", "..ooo.."],
]
const COLORS := {"o": Color(0.36, 0.25, 0.27), "w": Color(0.86, 0.82, 0.74), "i": Color(0.62, 0.1, 0.18)}
const PX := 2
## Da quanto vicino si accorge di Lethe, e quanta luce intorno lo fa chiudere.
const SEE_RANGE := 200.0
const LIGHT_RANGE := 110.0
## Quanto in fretta si apre (si chiude il doppio più in fretta: la luce fa male).
const OPEN_SPEED := 1.6

## Chi guarda.
var target: Node2D
## Falso nei test: niente suono.
var sound := true
var _was_open := false
var _blink := 0.0
var _blink_wait := 3.0
## 0 = chiuso, 1 = aperto.
var openness := 0.0
var _look := 0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_blink_wait = randf_range(2.0, 6.0)


## Vuole aprirsi? Lethe è vicina e non c'è luce intorno.
func wants_open() -> bool:
	if not is_instance_valid(target):
		return false
	if target.global_position.distance_to(global_position) > SEE_RANGE:
		return false
	return not LightCatch.lit_near(get_tree(), global_position, LIGHT_RANGE)


func is_open() -> bool:
	return openness >= 0.99


func _process(delta: float) -> void:
	var want := wants_open()
	openness = move_toward(openness, 1.0 if want else 0.0, delta * (OPEN_SPEED if want else OPEN_SPEED * 2.0))
	if is_open() and not _was_open and sound:
		var player := AudioStreamPlayer2D.new()
		player.stream = OPEN_SOUND
		player.volume_db = -10.0
		player.pitch_scale = randf_range(0.85, 1.1)
		player.max_distance = 320.0
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	_was_open = is_open()
	_blink = maxf(0.0, _blink - delta)
	if is_open():
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink = 0.14
			_blink_wait = randf_range(2.5, 6.0)
	_look = 0
	if is_instance_valid(target):
		var dx := target.global_position.x - global_position.x
		_look = 0 if absf(dx) < 24.0 else int(signf(dx))
	queue_redraw()


func _draw() -> void:
	var shown := 1 if _blink > 0.0 and openness > 0.5 else int(round(openness * 2.0))
	var frame: Array = FRAMES[shown]
	var origin := Vector2(-3.5, -2.5) * PX
	var iris := Vector2(-1, -1)
	for y in frame.size():
		var row: String = frame[y]
		for x in row.length():
			var c := row[x]
			if c == ".":
				continue
			if c == "i":
				iris = Vector2(x, y)
				c = "w"
			draw_rect(Rect2(origin + Vector2(x, y) * PX, Vector2(PX, PX)), COLORS[c])
	if iris.x >= 0:                              # la pupilla la segue (sul bianco)
		var row: String = frame[int(iris.y)]
		var x := int(iris.x) + _look
		if x >= 0 and x < row.length() and row[x] == "w":
			iris.x = x
		draw_rect(Rect2(origin + iris * PX, Vector2(PX, PX)), COLORS["i"])
