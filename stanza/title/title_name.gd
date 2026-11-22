extends HBoxContainer
## Il titolo, con un nome nascosto dentro: A-LETHE-IA. Ogni tanto le lettere intorno
## al nome tremolano e si spengono per un attimo, e resta solo LETHE: il nome della
## protagonista è dentro la parola "verità". Chi lo nota, scava.
##
## Tre Label figlie: Before, Word, After. Se il nome non c'è nel titolo, tutto va in Word
## e non tremola niente.

## Secondi tra un tremolio e l'altro (a caso in questo intervallo).
@export var flicker_every := Vector2(7.0, 13.0)
@export var flicker_seed := 3
## Quanto restano accese le lettere intorno mentre il nome resta solo.
const DIM := 0.08
## La tinta del nome mentre resta solo.
const WORD_TINT := Color(1.0, 0.82, 1.0)

@onready var before: Label = $Before
@onready var word: Label = $Word
@onready var after: Label = $After

var _rng := RandomNumberGenerator.new()
var _wait := 0.0
var _flicker: Tween


func _ready() -> void:
	_rng.seed = flicker_seed
	_wait = _rng.randf_range(flicker_every.x, flicker_every.y)


## Divide `title` intorno a `hidden` (es. "ALETHEIA", "LETHE" -> "A", "LETHE", "IA").
func setup(title: String, hidden: String) -> void:
	var parts := split(title, hidden)
	before.text = parts[0]
	word.text = parts[1]
	after.text = parts[2]


## [prima, nome, dopo]. Se il nome non c'è: ["", titolo, ""].
static func split(title: String, hidden: String) -> PackedStringArray:
	var at := title.find(hidden) if hidden != "" else -1
	if at < 0:
		return PackedStringArray(["", title, ""])
	return PackedStringArray([title.left(at), hidden, title.substr(at + hidden.length())])


func full_text() -> String:
	return before.text + word.text + after.text


func can_flicker() -> bool:
	return before.text != "" or after.text != ""


func is_flickering() -> bool:
	return _flicker != null and _flicker.is_running()


func _process(delta: float) -> void:
	if not can_flicker() or is_flickering():
		return
	_wait -= delta
	if _wait <= 0.0:
		flicker()
		_wait = _rng.randf_range(flicker_every.x, flicker_every.y)


## Il tremolio: due battiti veloci, il nome resta solo per un momento, poi tutto torna.
func flicker() -> void:
	if not can_flicker():
		return
	if _flicker:
		_flicker.kill()
	_flicker = create_tween()
	for a in [DIM, 0.7, DIM]:
		_flicker.tween_callback(_set_outer.bind(a))
		_flicker.tween_interval(0.06)
	_flicker.tween_property(word, "modulate", WORD_TINT, 0.08)
	_flicker.tween_interval(0.7)
	_flicker.tween_method(_set_outer, DIM, 1.0, 0.5)
	_flicker.parallel().tween_property(word, "modulate", Color.WHITE, 0.5)


func _set_outer(alpha: float) -> void:
	before.modulate.a = alpha
	after.modulate.a = alpha
