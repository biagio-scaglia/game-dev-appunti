extends Node
## Fa sfarfallare la luce del nodo padre (PointLight2D): un tremolio continuo (somma
## di onde a frequenze diverse, così non sembra regolare) più, ogni tanto, un calo
## improvviso e breve, come un monitor vecchio o una lampadina stanca.

@export var amount := 0.1        # quanto oscilla l'energia (0.1 = ±10%)
@export var speed := 4.0         # quanto è veloce il tremolio
@export var dip_chance := 0.0    # probabilità al secondo di un calo improvviso
const DIP_FACTOR := 0.35
const DIP_TIME := Vector2(0.05, 0.14)

var base_energy := 1.0
var _time := 0.0
var _dip_left := 0.0
var _rng := RandomNumberGenerator.new()
var _light: Light2D


func _ready() -> void:
	_light = get_parent() as Light2D
	base_energy = _light.energy
	_rng.seed = hash(get_path())
	_time = _rng.randf() * 10.0          # ogni luce parte da un punto diverso


func _process(delta: float) -> void:
	_time += delta
	if _dip_left > 0.0:
		_dip_left -= delta
	elif _rng.randf() < dip_chance * delta:
		_dip_left = _rng.randf_range(DIP_TIME.x, DIP_TIME.y)
	var energy := energy_at(base_energy, amount, speed, _time)
	_light.energy = energy * (DIP_FACTOR if _dip_left > 0.0 else 1.0)


## Energia al tempo t, senza cali: tre onde sommate, risultato tra base*(1-amount)
## e base*(1+amount). Statica: la usano i test.
static func energy_at(base: float, amp: float, spd: float, t: float) -> float:
	var wave := 0.5 * sin(t * spd) + 0.3 * sin(t * spd * 2.37 + 1.3) + 0.2 * sin(t * spd * 5.11 + 0.7)
	return base * (1.0 + amp * wave)
