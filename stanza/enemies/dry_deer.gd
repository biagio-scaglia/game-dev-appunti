extends "res://enemies/enemy.gd"
## Il Cervo Secco (vault: "Nemici e boss"): il boss del capitolo 1, lo spirito dell'albero secco.
## La bugia "It hasn't been that long" con un corpo. Carica in linea retta; dove si ferma
## cadono i rami. Si batte con la magia o con la spada: la zona (forest/zone_boss.gd) guarda
## l'ultimo colpo (`last_kind`) e cambia la fine (la verità lo libera, la spada lo rompe).
##
## Gli stati:
## - SLEEP: dorme tra le radici, finché la zona non lo sveglia (wake());
## - STALK: si avvicina camminando, girato verso Lethe;
## - WINDUP: abbassa le corna, raspa, il cuore e l'occhio si accendono, e per terra la scia
##   viola di dove andrà (la direzione si blocca a metà): si vede arrivare;
## - CHARGE: in linea retta, fortissimo; fa male a chi tocca. Contro la parete: CRASH, la terra
##   trema, cadono i rami, e resta STUNNED con le corna piantate (lì prende il doppio). Se la
##   carica finisce senza sbattere, cadono meno rami e si riprende subito;
## - a metà vita (phase 2) bramisce, le crepe si accendono di viola: preavviso più corto e due
##   cariche di fila.
## La corteccia: fuori dallo stordimento la spada fa metà; la magia passa (è luce).

signal phase_changed
signal crashed(at: Vector2)
## Per la zona: dove cadono i rami (lei li crea, così fanno male solo a Lethe).
signal branches(points: Array)

const SHEET := preload("res://enemies/sprites/dry_deer.png")
const SNORT := preload("res://audio/deer_snort.wav")
const GALLOP := preload("res://audio/deer_gallop.wav")
const CRASH := preload("res://audio/deer_crash.wav")
const BELLOW := preload("res://audio/deer_bellow.wav")
const Glow := preload("res://core/glow.gd")
const RoomTileset := preload("res://world/room_tileset.gd")

enum State { SLEEP, STALK, WINDUP, CHARGE, STUNNED, RECOVER, ROAR }

## Il foglio (enemies/sprites/dry_deer.png): di fronte quasi sempre (guarda chi gioca); di
## profilo solo la mira e la carica verso destra o sinistra (il disegno guarda a destra).
const FRAMES := 24
const IDLE := [0, 1, 2, 3]
const WALK := [4, 5, 6, 7]
const WINDUP_FRAMES := [8, 9, 10, 9]
const CHARGE_FRAMES := [11, 12, 13, 14]
const STUN_FRAMES := [15, 16]
const SIDE_WINDUP := [17, 18, 19, 18]
const SIDE_CHARGE := [20, 21, 22, 23]

const MAX_HP := 40
const WALK_SPEED := 42.0
const CHARGE_SPEED := 340.0
const STALK_TIME := Vector2(0.9, 1.5)
const WINDUP_TIME := 0.85
const WINDUP_TIME_2 := 0.55
## Fino a quando, nella mira, segue ancora Lethe (poi la direzione resta).
const AIM_UNTIL := 0.55
const CHARGE_MAX := 1.4
const STUN_TIME := 1.9
const STUN_TIME_2 := 1.4
const RECOVER_TIME := 0.5
const ROAR_TIME := 1.3
## Quanto prende fuori e dentro lo stordimento.
const ARMOR := {&"sword": 0.5, &"magic": 1.0}
const OPEN := {&"sword": 2.0, &"magic": 2.0}
## Il corpo, rispetto ai piedi.
const BODY_AT := Vector2(0, -24)

var state := State.SLEEP
var phase := 1
## L'ultimo colpo (spada o magia): decide la fine.
var last_kind := &""
var charge_dir := Vector2.RIGHT
var _timer := 0.0
var _charges_left := 0
var _aim_line: Line2D
var _heart_light: PointLight2D
var _gallop: AudioStreamPlayer2D


func _init() -> void:
	super()
	add_to_group(&"bosses")                  # la zona non lo tratta come gli altri nemici


func _ready() -> void:
	super()
	max_hp = MAX_HP
	hp = max_hp
	knockback = 0.0
	exp_reward = 30
	drop_chance = 0.0
	contact_damage = 1
	collision_mask = RoomTileset.WORLD_LAYER         # sbatte contro le pareti
	make_sprite(SHEET, FRAMES)
	make_body(22.0, BODY_AT)
	bar_height = 110.0
	_heart_light = Glow.light(Color(0.66, 0.5, 1.0), 0.6, 120.0)   # il cuore illumina il corpo, nel buio
	_heart_light.position = Vector2(0, -38)
	add_child(_heart_light)
	_aim_line = Line2D.new()
	_aim_line.width = 6.0
	_aim_line.default_color = Color(0.7, 0.5, 1.0, 0.0)
	_aim_line.z_index = -1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_aim_line.material = mat
	add_child(_aim_line)
	_show(IDLE[0])


## La zona lo sveglia (dopo la scena): comincia.
func wake() -> void:
	if state == State.SLEEP:
		_enter(State.STALK, 0.6)


## Torna a dormire com'era (Lethe è caduta: si ricomincia).
func reset() -> void:
	hp = max_hp
	phase = 1
	last_kind = &""
	state = State.SLEEP
	hurtful = false
	_aim_line.default_color.a = 0.0
	global_position = home
	sprite.modulate = Color.WHITE
	_stop_gallop()
	_show(IDLE[0])


func is_stunned() -> bool:
	return state == State.STUNNED


func damage_from(amount: int, kind: StringName) -> int:
	var k: float = (OPEN if is_stunned() else ARMOR).get(kind, 1.0)
	return maxi(1, roundi(amount * k))


func hurt(amount: int, kind: StringName, from: Vector2) -> int:
	if state == State.SLEEP:
		return 0
	last_kind = kind
	var dmg := super(amount, kind, from)
	_stagger = 0.0                                    # un boss non si scompone: la carica continua
	if not dead and phase == 1 and hp <= max_hp / 2:
		phase = 2
		_enter(State.ROAR, ROAR_TIME)
		phase_changed.emit()
		_play(BELLOW, 0.95, -2.0)
	return dmg


## Non si scioglie in ombra come gli altri: la fine la fa la zona (libero o rotto).
func die() -> void:
	if dead:
		return
	dead = true
	hurtful = false
	collision_layer = 0
	_aim_line.default_color.a = 0.0
	_stop_gallop()
	_show(STUN_FRAMES[0])
	died.emit(self)


func behave(delta: float) -> void:
	_timer -= delta
	match state:
		State.SLEEP:
			_animate(IDLE, 1.5)
		State.STALK:
			sprite.flip_h = false
			var to := (target.global_position - global_position) if target else Vector2.ZERO
			if to.length() > 90.0:
				move_and_collide(to.normalized() * WALK_SPEED * delta)
				_animate(WALK, 6.0)
			else:
				_animate(IDLE, 3.0)
			if _timer <= 0.0:
				_charges_left = 2 if phase == 2 else 1
				_start_windup()
		State.WINDUP:
			var total := WINDUP_TIME_2 if phase == 2 else WINDUP_TIME
			var done := 1.0 - _timer / total
			if done < AIM_UNTIL and target:
				charge_dir = (target.global_position - global_position).normalized()
				_face(charge_dir)
			_animate(SIDE_WINDUP if sideways() else WINDUP_FRAMES, 7.0)
			_draw_aim(done)
			if _timer <= 0.0:
				_aim_line.default_color.a = 0.0
				hurtful = true
				_enter(State.CHARGE, CHARGE_MAX)
				_start_gallop()
		State.CHARGE:
			_animate(SIDE_CHARGE if sideways() else CHARGE_FRAMES, 14.0)
			var hit := move_and_collide(charge_dir * CHARGE_SPEED * delta)
			if hit:
				_crash()
			elif _timer <= 0.0:
				_end_charge()
		State.STUNNED:
			sprite.flip_h = false
			_animate(STUN_FRAMES, 3.0)
			if _timer <= 0.0:
				_enter(State.RECOVER, RECOVER_TIME)
		State.RECOVER:
			_animate(IDLE, 3.0)
			if _timer <= 0.0:
				_enter(State.STALK, randf_range(STALK_TIME.x, STALK_TIME.y))
		State.ROAR:
			_show(IDLE[2])
			sprite.position = Vector2(randf_range(-1, 1), 0)
			if _timer <= 0.0:
				sprite.position = Vector2.ZERO
				_enter(State.STALK, 0.4)
	_heart_light.energy = 0.5 + (0.9 if state in [State.WINDUP, State.CHARGE] else 0.0) + (0.3 if phase == 2 else 0.0)


func _start_windup() -> void:
	_enter(State.WINDUP, WINDUP_TIME_2 if phase == 2 else WINDUP_TIME)
	_play(SNORT, randf_range(0.9, 1.05), -3.0)


## Contro la parete: la terra trema, il cervo resta stordito, cadono i rami.
func _crash() -> void:
	hurtful = false
	_stop_gallop()
	_play(CRASH, randf_range(0.9, 1.05), 0.0)
	crashed.emit(global_position + charge_dir * 30.0)
	branches.emit(_branch_points(6 if phase == 2 else 4))
	_charges_left = 0
	_enter(State.STUNNED, STUN_TIME_2 if phase == 2 else STUN_TIME)


## La carica finisce senza sbattere: pochi rami, e (nella seconda fase) un'altra carica.
func _end_charge() -> void:
	hurtful = false
	_stop_gallop()
	branches.emit(_branch_points(2))
	_charges_left -= 1
	if _charges_left > 0:
		_start_windup()
	else:
		_enter(State.RECOVER, RECOVER_TIME)


## Dove cadono i rami: uno dove sta Lethe, gli altri a caso nella stanza intorno al cervo.
func _branch_points(count: int) -> Array:
	var out: Array = []
	if target:
		out.append(target.global_position)
	for i in count - 1:
		out.append(global_position + Vector2(randf_range(-220, 220), randf_range(-120, 90)))
	return out


func _enter(next: State, time: float) -> void:
	state = next
	_timer = time


## La carica va più di lato che in su o in giù: si disegna di profilo.
func sideways() -> bool:
	return absf(charge_dir.x) > absf(charge_dir.y) * 1.2


## Di profilo il disegno guarda a destra: verso sinistra si specchia. Di fronte no.
func _face(dir: Vector2) -> void:
	sprite.flip_h = sideways() and dir.x < 0.0


func _animate(frames: Array, fps: float) -> void:
	_show(frames[int(_anim_time * fps) % frames.size()])


func _show(frame: int) -> void:
	if sprite:
		sprite.frame = frame


## La scia viola per terra, verso dove caricherà: cresce mentre prende la mira.
func _draw_aim(done: float) -> void:
	_aim_line.clear_points()
	_aim_line.add_point(Vector2(0, -6))
	_aim_line.add_point(Vector2(0, -6) + charge_dir * 260.0 * minf(1.0, done * 1.6))
	_aim_line.default_color.a = 0.16 + 0.12 * sin(_anim_time * 24.0)


func _start_gallop() -> void:
	if not sound:
		return
	_gallop = AudioStreamPlayer2D.new()
	_gallop.stream = GALLOP
	_gallop.volume_db = -2.0
	add_child(_gallop)
	_gallop.play()


func _stop_gallop() -> void:
	if is_instance_valid(_gallop):
		_gallop.queue_free()
	_gallop = null


func _play(stream: AudioStream, pitch: float, db: float) -> void:
	if sound:
		Sfx.play(get_parent(), stream, pitch, db)
