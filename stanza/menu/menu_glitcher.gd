extends Node
## Mentre il menu è aperto, ogni tanto qualcosa non va: una scritta si guasta per un
## attimo, oppure succede uno degli `events` (lo stato che legge "Dead", la finestra che
## trema, la sagoma che lampeggia). Le scritte le dà `targets`: chi la chiama decide
## quali sono visibili.

const Glitch := preload("glitch.gd")

const MIN_WAIT := 1.4
const MAX_WAIT := 3.8
const GLITCH_TIME := 0.12
const GLITCH_AMOUNT := 0.45
## Su quanti guasti uno è invece un evento.
const EVENT_CHANCE := 0.25

var rng := RandomNumberGenerator.new()
## Callable che rende un Array di Control con `text` (Label, Button).
var targets: Callable
var events: Array[Callable] = []
var running := false
var _wait := 0.0


func start() -> void:
	running = true
	_wait = rng.randf_range(MIN_WAIT, MAX_WAIT)


func stop() -> void:
	running = false
	if targets.is_valid():
		for node: Control in targets.call():
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
	var nodes: Array = targets.call() if targets.is_valid() else []
	if not nodes.is_empty():
		glitch(nodes[rng.randi() % nodes.size()])


## Guasta la scritta di `node` per `duration` secondi, poi la rimette a posto.
func glitch(node: Control, duration := GLITCH_TIME, amount := GLITCH_AMOUNT) -> void:
	if node.has_meta(&"clean_text") or String(node.get("text")).strip_edges() == "":
		return
	node.set_meta(&"clean_text", node.get("text"))
	node.set("text", Glitch.corrupt(node.get("text"), amount, rng))
	await get_tree().create_timer(duration).timeout
	restore(node)


## Tutte le scritte guaste insieme, un po' più a lungo.
func burst(duration := 0.3) -> void:
	if targets.is_valid():
		for node: Control in targets.call():
			glitch(node, duration)


func restore(node: Control) -> void:
	if is_instance_valid(node) and node.has_meta(&"clean_text"):
		node.set("text", node.get_meta(&"clean_text"))
		node.remove_meta(&"clean_text")
