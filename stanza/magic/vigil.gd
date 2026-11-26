extends Node2D
## La veglia (Vigil), il secondo incantesimo: quattro fiammelle di verità escono dalle mani
## di Lethe, le girano attorno (fanno male a chi tocca), poi partono una dopo l'altra: verso
## i nemici vicini se ci sono (piegano un po' per seguirli), altrimenti a ventaglio verso
## dove guarda. Si impara accendendo con la propria luce le lanterne di radice del dungeon.
##
## Il nodo segue `caster` (sta all'altezza delle mani) e si libera da solo quando l'ultima
## fiammella si è spenta. Lethe può muoversi mentre girano: la seguono.

signal finished

const Flame := preload("vigil_flame.gd")
const Sfx := preload("res://core/sfx.gd")
const CAST := preload("res://audio/magic_cast.wav")

const COUNT := 4
## Il raggio del giro, quanto in fretta gira (radianti al secondo), quanto ci mettono ad
## allargarsi dalle mani, quanto girano prima di partire, e ogni quanto ne parte una.
const RADIUS := 24.0
const SPIN := 9.0
const GATHER := 0.2
const ORBIT := 0.55
const GAP := 0.09
const SPEED := 280.0
## Fin dove cercano un nemico da inseguire.
const SEEK_RANGE := 170.0
## Senza nemici: il ventaglio attorno a dove guarda (radianti).
const SPREAD := [-0.24, -0.08, 0.08, 0.24]
const HAND_HEIGHT := 18.0

var caster: Node2D
var facing := Vector2.DOWN
var damage := 2
var flames: Array = []
var _time := 0.0
var _launched := 0
var _alive := COUNT


func _ready() -> void:
	for i in COUNT:
		var flame: Area2D = Flame.new()
		flame.damage = damage
		flame.gone.connect(_on_gone)
		add_child(flame)
		flames.append(flame)
	_follow()
	_place(0.0)


func _physics_process(delta: float) -> void:
	_time += delta
	_follow()
	_place(delta)
	var due := int(floor((_time - GATHER - ORBIT) / GAP)) + 1
	while _launched < mini(due, COUNT):
		_launch(_launched)
		_launched += 1


## Quante sono ancora attorno a Lethe (non partite e non spente).
func circling() -> int:
	var n := 0
	for flame in flames:
		if is_instance_valid(flame) and not flame.flying:
			n += 1
	return n


func _follow() -> void:
	if is_instance_valid(caster):
		global_position = caster.global_position + Vector2(0, -HAND_HEIGHT)


func _place(_delta: float) -> void:
	var grow := clampf(_time / GATHER, 0.0, 1.0)
	for i in flames.size():
		if not is_instance_valid(flames[i]) or flames[i].flying:
			continue                                 # già partita, o spenta su un nemico
		var flame: Area2D = flames[i]
		var angle := _time * SPIN + TAU * i / COUNT
		flame.position = Vector2(cos(angle), sin(angle) * 0.7) * RADIUS * grow   # un po' schiacciato: la vista è dall'alto
		# Il nodo sta all'altezza delle mani, quindi nell'ordine dall'alto è dietro Lethe: la
		# metà del giro più vicina a chi guarda passa davanti a lei.
		flame.z_index = 1 if sin(angle) > 0.0 else 0


## Una fiammella parte: resta dove è nel mondo (non segue più Lethe) e vola.
func _launch(i: int) -> void:
	if not is_instance_valid(flames[i]):
		return
	var flame: Area2D = flames[i]
	var at := flame.global_position
	remove_child(flame)
	get_parent().add_child(flame)
	flame.global_position = at
	var targets := _targets()
	var direction := facing.normalized().rotated(SPREAD[i])
	if not targets.is_empty():
		flame.target = targets[i % targets.size()]
		direction = (flame.target.global_position + Vector2(0, -12) - at).normalized()
	flame.launch(direction, SPEED)
	Sfx.play(get_parent(), CAST, 1.35 + 0.12 * i, -9.0)


## I nemici vivi entro SEEK_RANGE, dal più vicino.
func _targets() -> Array:
	var out: Array = []
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.get(&"dead") or (enemy as Node2D).global_position.distance_to(global_position) > SEEK_RANGE:
			continue
		out.append(enemy)
	out.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	return out


func _on_gone() -> void:
	_alive -= 1
	if _alive <= 0:
		finished.emit()
		queue_free()
