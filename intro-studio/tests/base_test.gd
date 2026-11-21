extends RefCounted
## Base di ogni test: gli assert e qualche aiuto per i test asincroni.
## Un file di test estende questo script e ha metodi che iniziano con "test_".

## Il SceneTree del runner, per aggiungere scene e aspettare frame.
var tree: SceneTree
var failures: PackedStringArray = []
## Nodi aggiunti con add_scene(): after() li libera.
var _owned: Array[Node] = []


func before() -> void:
	pass


func after() -> void:
	for n in _owned:
		if is_instance_valid(n):
			n.queue_free()
	Engine.time_scale = 1.0
	await tree.process_frame


func assert_true(cond: bool, msg := "atteso vero") -> void:
	if not cond:
		failures.append(msg)


func assert_false(cond: bool, msg := "atteso falso") -> void:
	assert_true(not cond, msg)


func assert_eq(got: Variant, want: Variant, msg := "") -> void:
	if got != want:
		failures.append("%s: atteso %s, ottenuto %s" % [msg, str(want), str(got)])


func assert_near(got: float, want: float, eps := 0.001, msg := "") -> void:
	if absf(got - want) > eps:
		failures.append("%s: atteso %s ± %s, ottenuto %s" % [msg, want, eps, got])


## Istanzia una scena, la aggiunge all'albero e la libera a fine test.
func add_scene(path: String, setup := Callable()) -> Node:
	var node: Node = load(path).instantiate()
	if setup.is_valid():
		setup.call(node)
	tree.root.add_child(node)
	_owned.append(node)
	return node


## Aspetta `sig` al massimo `timeout` secondi reali. True se è arrivato.
func wait_signal(sig: Signal, timeout: float) -> bool:
	var state := {"done": false}
	sig.connect(func(): state["done"] = true, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while not state["done"] and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return state["done"]


func wait_seconds(t: float) -> void:
	await tree.create_timer(t).timeout
