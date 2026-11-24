extends Node
## Mentre il menu è aperto, ogni tanto qualcosa non va: una scritta visibile sotto `root`
## si guasta per un attimo, oppure succede uno degli `events` (lo stato che legge "Dead",
## la finestra che sobbalza). Le scritte con il meta "no_glitch" non si toccano mai
## (il tempo che cambia ogni frame, la barra d'aiuto).

const Glitch := preload("glitch.gd")

const MIN_WAIT := 1.4
const MAX_WAIT := 3.8
const GLITCH_TIME := 0.12
const GLITCH_AMOUNT := 0.45
## Su quanti guasti uno è invece un evento.
const EVENT_CHANCE := 0.25

var rng := RandomNumberGenerator.new()
var root: Control
var events: Array[Callable] = []
var running := false
var _wait := 0.0


func start() -> void:
	running = true
	_wait = rng.randf_range(MIN_WAIT, MAX_WAIT)


func stop() -> void:
	running = false
	for node in targets():
		restore(node)


func _process(delta: float) -> void:
	if not running:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = rng.randf_range(MIN_WAIT, MAX_WAIT)
	trigger()


func trigger() -> void:
	if not events.is_empty() and rng.randf() < EVENT_CHANCE:
		events[rng.randi() % events.size()].call()
		return
	var nodes := targets()
	if not nodes.is_empty():
		glitch(nodes[rng.randi() % nodes.size()])


## Le scritte che si possono guastare: Label e Button visibili, senza "no_glitch".
func targets() -> Array[Control]:
	var out: Array[Control] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if (node is Label or node is Button) and node.is_visible_in_tree() \
				and not node.has_meta(&"no_glitch"):
			out.append(node)
	return out


## Guasta la scritta di `node` per `duration` secondi, poi la rimette a posto.
func glitch(node: Control, duration := GLITCH_TIME, amount := GLITCH_AMOUNT) -> void:
	if node.has_meta(&"clean_text") or String(node.get("text")).strip_edges() == "":
		return
	node.set_meta(&"clean_text", node.get("text"))
	node.set("text", Glitch.corrupt(node.get("text"), amount, rng))
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(node):       # nel frattempo la pagina può averla rifatta (es. salvando)
		restore(node)


## Tutte le scritte guaste insieme, un po' più a lungo.
func burst(duration := 0.3) -> void:
	for node in targets():
		glitch(node, duration)


## Rimette a posto la scritta. Non tipizzato: può arrivare un nodo già liberato (la lista
## degli slot si ricostruisce quando si salva), e allora non fa niente.
func restore(node) -> void:
	if is_instance_valid(node) and node.has_meta(&"clean_text"):
		node.set("text", node.get_meta(&"clean_text"))
		node.remove_meta(&"clean_text")
