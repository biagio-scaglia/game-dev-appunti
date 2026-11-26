extends CharacterBody2D
## La protagonista: cammina in 8 direzioni, corre da sola se si tiene una direzione (o
## subito con Shift), e attacca in due modi (tasti: core/input_setup.gd).
## - Magia (Q): la verità. Prima la carica sulle mani, poi a metà attacco parte
##   l'incantesimo su Q (`spell`): il proiettile verso dove guarda (truth_spark) o le quattro
##   fiammelle della veglia (vigil, magic/vigil.gd).
## - Spada di vetro dello specchio (Spazio, il tasto unico): la bugia. La lama compare dalla mano e fende verso
##   dove guarda; sword_stage (0 scheggia, 1 pugnale, 2 lama) cresce con le bugie.
## Mentre attacca o parla (`frozen`) sta ferma. L'origine del nodo è ai piedi.
## `can_cast` e `can_slash` dicono se la magia e la spada ci sono già: nel gioco le decide lo
## stato della partita (all'inizio niente), da sola (test, reel) può tutto.

signal attack_finished(kind: StringName)
## Ha preso un colpo (da `from`, nel mondo): chi la ascolta toglie il cuore.
signal damaged(amount: int, from: Vector2)

const Frames := preload("protagonista_frames.gd")
const Facing := preload("facing.gd")
const InputSetup := preload("../../core/input_setup.gd")
const PROJECTILE := preload("res://magic/projectile.tscn")
const CHARGE := preload("res://magic/charge.tscn")
const Vigil := preload("res://magic/vigil.gd")
const SWORD := preload("res://weapon/glass_sword.tscn")

@export var walk_speed := 70.0
@export var run_speed := 130.0
## Dopo quanti secondi con una direzione tenuta si mette a correre da sola (0 = mai).
@export var auto_run_after := 0.4
## Fotogramma dell'attacco in cui parte il colpo (il proiettile o il fendente).
@export var launch_frame := 3
## Lo stadio della spada di vetro: cresce con le bugie (sistema del karma, da fare).
@export_range(0, 2) var sword_stage := 0
## Quanto fanno male la spada (più lo stadio) e la magia, prima delle debolezze dei nemici.
const SWORD_DAMAGE := 2
const MAGIC_DAMAGE := 3
## Ogni fiammella della veglia (sono quattro).
const VIGIL_DAMAGE := 2
## Dopo un colpo: per quanto non ne prende altri (e lampeggia), la spinta all'indietro.
const INVULNERABLE_TIME := 1.1
const KNOCKBACK := 230.0
const KNOCK_DRAG := 1300.0
## La spada parte quasi subito (la magia ha bisogno di caricarsi: launch_frame).
const SLASH_FRAME := 1
## La mira assistita della spada: un nemico entro questa distanza, e non più di
## AIM_ANGLE gradi da dove guarda, attira il fendente verso di sé.
const AIM_RANGE := 72.0
const AIM_ANGLE := 80.0
## Il fermo quando la lama prende qualcosa: quanto dura e quanto rallenta tutto.
const HITSTOP := 0.06
const HITSTOP_SCALE := 0.08
## Dove sono le mani rispetto ai piedi: in alto e un po' avanti.
const HAND_HEIGHT := 24.0
const HAND_REACH := 14.0

@onready var sprite: AnimatedSprite2D = $Sprite

var facing := Vector2.DOWN
## L'attacco in corso: &"cast", &"slash" o vuoto.
var attacking := &""
var _launched := false
## Ferma (sta parlando con qualcosa): niente movimento né attacchi.
var frozen := false
## Guidata da una cutscene (core/cutscene.gd): niente input, niente animazioni automatiche;
## la muove e la gira chi la guida (update_animation e la posizione).
var scripted := false
## Sa un incantesimo (Spazio / J) e ha la spada in mano (K).
var can_cast := true
var can_slash := true
## L'incantesimo su Q (lo mette chi conosce lo stato; da sola, il primo).
var spell := "truth_spark"
## La veglia in corso: finché le fiammelle girano non se ne lancia un'altra.
var vigil: Node2D
## Secondi di invulnerabilità che restano; la spinta di un colpo (si spegne da sola).
var invulnerable := 0.0
var knock := Vector2.ZERO
## Dove va il fendente (verso il nemico della mira assistita, o dove guarda).
var aim := Vector2.ZERO
var _hitstop := false
## Quanto taglia in più la spada (dal livello: lo mette chi conosce lo stato).
var attack_bonus := 0
## Un fendente premuto mentre ne finisce un altro: parte appena può (per BUFFER secondi).
const BUFFER := 0.25
var _buffered := 0.0
## Da quanto tiene una direzione (per la corsa da sola).
var _held := 0.0


func _ready() -> void:
	InputSetup.ensure_actions()
	sprite.sprite_frames = Frames.build()
	sprite.offset = Frames.feet_offset()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	_play("idle")


func _physics_process(delta: float) -> void:
	_tick_hurt(delta)
	if scripted:
		velocity = Vector2.ZERO
		return
	if knock != Vector2.ZERO:
		velocity = knock
		move_and_slide()
		knock = knock.move_toward(Vector2.ZERO, KNOCK_DRAG * delta)
		return
	if frozen:
		velocity = Vector2.ZERO
		if not is_attacking():
			_play("idle")
		return
	if can_cast and Input.is_action_just_pressed(&"cast"):
		cast()
	elif can_slash and Input.is_action_just_pressed(&"slash"):
		if is_attacking():
			_buffered = BUFFER          # lo ricorda: parte alla fine di questo
		else:
			slash()
	_buffered = maxf(0.0, _buffered - delta)
	if can_slash and OS.is_debug_build() and Input.is_action_just_pressed(&"sword_stage"):
		sword_stage = (sword_stage + 1) % 3       # solo per provare gli stadi
	if is_attacking():
		velocity = Vector2.ZERO
		_held = 0.0
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_held = _held + delta if direction != Vector2.ZERO else 0.0
	var running := Input.is_action_pressed(&"run") or is_auto_running()
	velocity = direction * (run_speed if running else walk_speed)
	move_and_slide()
	update_animation(direction, running)


## Tiene una direzione da abbastanza: corre senza Shift.
func is_auto_running() -> bool:
	return auto_run_after > 0.0 and _held >= auto_run_after


## Un colpo da `from`: ritorna falso se non l'ha preso (invulnerabile, o ferma a parlare).
func hurt(amount: int, from: Vector2) -> bool:
	if invulnerable > 0.0 or frozen:
		return false
	invulnerable = INVULNERABLE_TIME
	var away := global_position - from
	knock = (away.normalized() if away.length() > 0.1 else -facing) * KNOCKBACK
	damaged.emit(amount, from)
	return true


func _tick_hurt(delta: float) -> void:
	if invulnerable <= 0.0:
		return
	invulnerable = maxf(0.0, invulnerable - delta)
	# Lampeggia a scatti (blocchi di 0.08 s), come i vecchi giochi.
	sprite.visible = invulnerable <= 0.0 or int(invulnerable / 0.08) % 2 == 0


func is_attacking() -> bool:
	return attacking != &""


## Sceglie l'animazione di movimento. Pubblica: la usano i test.
func update_animation(direction: Vector2, running: bool) -> void:
	facing = Facing.dir8(direction, facing)
	if direction == Vector2.ZERO:
		_play("idle")
	else:
		_play("run" if running else "walk")


## Lancia la magia verso dove guarda. Ignorato se sta già attaccando.
func cast() -> void:
	if spell == "vigil" and is_instance_valid(vigil):
		return
	if _start_attack(&"cast"):
		_spawn(CHARGE.instantiate(), hand_position())


## Fende con la spada di vetro verso dove guarda. Ignorato se sta già attaccando.
func slash() -> void:
	if _start_attack(&"slash"):
		aim = aim_at_enemy()
		if aim != Vector2.ZERO:
			facing = Facing.dir8(aim, facing)       # si gira verso il nemico (8 direzioni)
			_play("slash")


## La mira assistita: la direzione verso il nemico più vicino davanti a lei (entro
## AIM_RANGE e AIM_ANGLE), o zero se non c'è.
func aim_at_enemy() -> Vector2:
	var best := Vector2.ZERO
	var best_d := AIM_RANGE
	var hand := hand_position()
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.get(&"dead"):
			continue
		var to: Vector2 = (enemy as Node2D).global_position + Vector2(0, -14) - hand
		var d := to.length()
		if d < best_d and absf(rad_to_deg(facing.angle_to(to))) <= AIM_ANGLE:
			best_d = d
			best = to.normalized()
	return best


## Il fermo del colpo: tutto quasi immobile per un attimo (si sente che ha preso).
func hit_stop() -> void:
	if _hitstop or not is_inside_tree():
		return
	_hitstop = true
	var before := Engine.time_scale
	Engine.time_scale = before * HITSTOP_SCALE
	await get_tree().create_timer(HITSTOP, true, false, true).timeout
	Engine.time_scale = before
	_hitstop = false


func hand_position() -> Vector2:
	return global_position + facing.normalized() * HAND_REACH + Vector2(0, -HAND_HEIGHT)


func _start_attack(kind: StringName) -> bool:
	if is_attacking():
		return false
	attacking = kind
	_launched = false
	_play("attack" if kind == &"cast" else "slash")   # slash: la stessa posa, con la scia di vetro
	return true


func _on_frame_changed() -> void:
	var frame := launch_frame if attacking == &"cast" else SLASH_FRAME
	if not is_attacking() or _launched or sprite.frame < frame:
		return
	_launched = true
	match attacking:
		&"cast":
			if spell == "vigil":
				vigil = Vigil.new()
				vigil.caster = self
				vigil.facing = facing
				vigil.damage = VIGIL_DAMAGE
				_spawn(vigil, global_position)
			else:
				var shot := PROJECTILE.instantiate()
				shot.direction = facing.normalized()
				shot.damage = MAGIC_DAMAGE
				_spawn(shot, hand_position())
		&"slash":
			var sword := SWORD.instantiate()
			sword.direction = aim if aim != Vector2.ZERO else facing.normalized()
			sword.stage = sword_stage
			sword.hit.connect(func(body: Node2D) -> void:
				if body.has_method(&"hurt"):
					body.hurt(SWORD_DAMAGE + sword_stage + attack_bonus, &"sword", global_position)
					hit_stop())
			_spawn(sword, hand_position())


func _on_animation_finished() -> void:
	if not is_attacking():
		return
	var kind := attacking
	attacking = &""
	_play("idle")
	attack_finished.emit(kind)
	if _buffered > 0.0 and can_slash:
		_buffered = 0.0
		slash()


func _spawn(node: Node2D, at: Vector2) -> void:
	get_parent().add_child(node)
	node.global_position = at


func _play(kind: String) -> void:
	sprite.flip_h = Facing.flipped(facing)
	var anim := Facing.animation(kind, facing)
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
