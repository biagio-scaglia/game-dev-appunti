extends Node
## Il boss di una zona (forest_zone.gd lo monta come "Boss"), dai dati: BOSS [scena, cella],
## BOSS_ROOM (la stanza dello scontro), BOSS_GATE (dove le radici richiudono l'entrata). Il
## passo 6 del dungeon: il Cervo Secco (enemies/dry_deer.gd).
## - Entrando nella stanza la prima volta: la scena. Lethe fa due passi, le radici ricrescono
##   dietro di lei e chiudono, la camera va sul cervo che dorme; apre l'occhio, dice la sua
##   bugia. Poi la barra della vita (ui/boss_bar.gd), la musica dello scontro, e si comincia.
## - I rami: il cervo dice dove cadono, qui si creano (fx/falling_branch.gd), dentro la stanza.
## - Lethe cade: si ricomincia (il cervo torna a dormire, le radici si riaprono, la musica di
##   prima). Si rientra e la scena è più corta.
## - La fine, dall'ultimo colpo: la magia lo libera (si inchina e si scioglie in luce:
##   "deer_freed"), la spada lo rompe (si spacca in corteccia e foglie morte: "deer_broken").
##   Tutte e due: le radici si riaprono, l'esperienza, e dove stava una foglia verde (la Green
##   Leaf, da portare all'albero secco). Si ricorda: "deer_defeated", "deer_freed".

signal fight_started
signal defeated(freed: bool)

const DryDeer := preload("res://enemies/dry_deer.gd")
const FallingBranch := preload("res://fx/falling_branch.gd")
const BossBar := preload("res://ui/boss_bar.gd")
const ZoneDressing := preload("zone_dressing.gd")
const ScreenShake := preload("res://fx/screen_shake.gd")
const Music := preload("res://core/music.gd")
const Sfx := preload("res://core/sfx.gd")
const DIALOGUE := preload("res://dialogue/forest.dialogue")
const THEME := preload("res://audio/deer_theme.wav")
const RETRACT := preload("res://audio/roots_retract.wav")
const FREE := preload("res://audio/deer_free.wav")
const BREAK := preload("res://audio/deer_break.wav")
const TILE := 32
const NAME := "The Dry Deer"

var zone: Node2D
var deer: CharacterBody2D
var bar: CanvasLayer
var fighting := false
## Le radici che chiudono l'entrata durante lo scontro.
var gates: Array[Sprite2D] = []
var _room := Rect2()
var _old_music: AudioStream


func state() -> RefCounted:
	return zone.state


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	var boss: Array = zone.layout_value("BOSS")
	if boss.is_empty():
		return
	for r in zone.layout_value("ROOMS"):
		if r[0] == zone.layout_value("BOSS_ROOM", ""):
			_room = Rect2(Vector2(r[2].position) * TILE, Vector2(r[2].size) * TILE)
	bar = BossBar.new()
	bar.name = "BossBar"
	zone.add_child(bar)
	if state().flag("deer_defeated"):
		_leave_leaf((Vector2(boss[1]) + Vector2(0.5, 0.5)) * TILE)
		return
	deer = DryDeer.new()
	deer.name = "DryDeer"
	deer.target = zone.hero
	deer.sound = zone.sound
	deer.position = (Vector2(boss[1]) + Vector2(0.5, 1.0)) * TILE
	zone.world.add_child(deer)
	deer.home = deer.position
	deer.died.connect(func(_e: Node2D) -> void: _on_defeated())
	deer.branches.connect(drop_branches)
	deer.crashed.connect(_on_crash)
	deer.phase_changed.connect(_on_phase2)
	if zone.rooms:
		zone.rooms.room_changed.connect(func(id: String, _name: String) -> void:
			if id == zone.layout_value("BOSS_ROOM", "") and not fighting and is_instance_valid(deer) and not deer.dead:
				start_fight())
	zone.combat.respawned.connect(_on_respawned)
	zone.combat.died.connect(func() -> void:
		if is_instance_valid(deer):
			deer.set_physics_process(false))      # Lethe è caduta: tutto si ferma
	zone.talk.talk_started.connect(func(_id: String) -> void:
		if fighting:
			bar.root_node.modulate.a = 0.0)
	zone.talk.talk_finished.connect(func(_id: String) -> void:
		if fighting:
			bar.root_node.modulate.a = 1.0)


# --- Lo scontro -----------------------------------------------------------------------------

## La scena dell'entrata, poi lo scontro.
func start_fight() -> void:
	fighting = true
	var cut: Node = zone.story.cut
	var hero: CharacterBody2D = zone.hero
	var first: bool = not state().flag("deer_met")
	state().set_flag("deer_met")
	await cut.begin()
	var inside := Vector2(hero.global_position.x, _room.end.y - 3.2 * TILE)
	await cut.walk(hero, inside, 70.0)
	_close_gates()
	await cut.wait(0.5)
	await cut.pan_to(deer.global_position + Vector2(0, -40), 1.2 if first else 0.6)
	if first:
		await cut.wait(0.6)
		cut.emote(hero, "!")
		await cut.say(DIALOGUE, "deer_wake")
	else:
		await cut.say(DIALOGUE, "deer_again")
	await cut.pan_back(0.8)
	await cut.end()
	bar.appear(NAME)
	bar.set_life(deer.hp, deer.max_hp)
	_swap_music(THEME)
	deer.wake()
	fight_started.emit()


func _process(_delta: float) -> void:
	if fighting and is_instance_valid(deer) and not deer.dead:
		if absf(bar.ratio - float(deer.hp) / deer.max_hp) > 0.001:
			bar.set_life(deer.hp, deer.max_hp)


## I rami cadono nei punti dati (dentro la stanza, non sopra le pareti).
func drop_branches(points: Array) -> Array:
	var out: Array = []
	var inner := _room.grow_individual(-2.5 * TILE, -3.5 * TILE, -2.5 * TILE, -1.5 * TILE)
	for i in points.size():
		var at: Vector2 = points[i]
		at = Vector2(clampf(at.x, inner.position.x, inner.end.x), clampf(at.y, inner.position.y, inner.end.y))
		var branch := FallingBranch.new()
		branch.target = zone.hero
		branch.sound = zone.sound
		branch.position = at
		zone.world.add_child(branch)
		out.append(branch)
	return out


func _on_crash(at: Vector2) -> void:
	var shake := ScreenShake.new()
	shake.strength = 4.0
	shake.duration = 0.45
	get_tree().root.add_child(shake)
	_burst(at, Color(0.5, 0.42, 0.44), 18)


func _on_phase2() -> void:
	bar.set_phase2()
	var shake := ScreenShake.new()
	shake.strength = 3.0
	shake.duration = 1.0
	get_tree().root.add_child(shake)
	_burst(deer.global_position + Vector2(0, -60), Color(0.62, 0.42, 0.34), 24)   # foglie morte dalle corna
	deer.sprite.modulate = Color(1.0, 0.92, 1.12)                                  # le crepe si accendono
	drop_branches(deer._branch_points(5))


## Lethe è caduta: si ricomincia da capo.
func _on_respawned() -> void:
	if is_instance_valid(deer):
		deer.set_physics_process(true)
	if not fighting or not is_instance_valid(deer) or deer.dead:
		return
	fighting = false
	deer.reset()
	_open_gates()
	bar.disappear()
	_swap_music(_old_music)


# --- La fine --------------------------------------------------------------------------------

func _on_defeated() -> void:
	fighting = false
	var freed: bool = deer.last_kind == &"magic"
	state().set_flag("deer_defeated")
	state().set_flag("deer_freed", freed)
	bar.disappear()
	_swap_music(_old_music)
	var cut: Node = zone.story.cut
	await cut.begin()
	await cut.pan_to(deer.global_position + Vector2(0, -40), 0.8)
	if freed:
		_freed_fx()
	else:
		_broken_fx()
	await cut.wait(1.0)
	await cut.say(DIALOGUE, "deer_freed" if freed else "deer_broken")
	var at := deer.global_position
	var reward: int = deer.exp_reward
	deer.queue_free()
	_open_gates()
	_leave_leaf(at + Vector2(0, -6))
	await cut.pan_back(0.8)
	await cut.end()
	zone.gain_exp(reward)
	zone.story._update_roots_goal()
	defeated.emit(freed)


## La verità: si inchina, la luce del petto cresce, si scioglie in luce che sale.
func _freed_fx() -> void:
	if zone.sound:
		Sfx.play(zone, FREE, 1.0, -2.0)
	var s: Sprite2D = deer.sprite
	var t := s.create_tween()
	t.tween_property(s, "modulate", Color(2.2, 2.0, 2.6, 1.0), 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(s, "modulate:a", 0.0, 1.0)
	var motes := CPUParticles2D.new()
	motes.amount = 40
	motes.lifetime = 2.2
	motes.one_shot = true
	motes.explosiveness = 0.3
	motes.local_coords = false
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(40, 30)
	motes.direction = Vector2.UP
	motes.spread = 25.0
	motes.gravity = Vector2(0, -30)
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 35.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.9, 1.0))
	ramp.set_color(1, Color(0.7, 0.5, 1.0, 0.0))
	motes.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	motes.material = mat
	motes.position = deer.global_position + Vector2(0, -50)
	motes.z_index = 6
	zone.add_child(motes)
	motes.emitting = true
	get_tree().create_timer(3.0).timeout.connect(motes.queue_free)


## La spada: un lampo bianco, si spacca, corteccia e foglie morte dappertutto.
func _broken_fx() -> void:
	if zone.sound:
		Sfx.play(zone, BREAK, 1.0, -1.0)
	var shake := ScreenShake.new()
	shake.strength = 5.0
	shake.duration = 0.5
	get_tree().root.add_child(shake)
	var s: Sprite2D = deer.sprite
	s.modulate = Color(3, 3, 3)
	var t := s.create_tween()
	t.tween_property(s, "modulate", Color.WHITE, 0.15)
	t.tween_property(s, "scale", Vector2(1.15, 0.1), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.35)
	_burst(deer.global_position + Vector2(0, -50), Color(0.72, 0.66, 0.64), 30)
	_burst(deer.global_position + Vector2(0, -70), Color(0.62, 0.42, 0.34), 20)


## Dove stava il cervo resta una foglia verde (si raccoglie parlandoci: "leaf").
func _leave_leaf(at: Vector2) -> void:
	if state().flag("item_leaf"):
		return
	zone.puzzles.add_treasure("leaf", at)


# --- Le radici dell'entrata, la musica -----------------------------------------------------

func _close_gates() -> void:
	for cell in zone.layout_value("BOSS_GATE"):
		var sprite := ZoneDressing.thing_sprite(zone.data, "root_gate", cell)
		sprite.set_meta(&"puzzle", true)
		zone.world.add_child(sprite)
		ZoneDressing.build_thing(zone, sprite, zone.data)
		sprite.scale = Vector2(1.0, 0.1)
		sprite.create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		gates.append(sprite)
	if zone.sound:
		Sfx.play(zone, RETRACT, 0.7, -2.0)


func _open_gates() -> void:
	for sprite in gates:
		if is_instance_valid(sprite):
			var t := sprite.create_tween()
			t.tween_property(sprite, "scale", Vector2(1.0, 0.1), 0.5)
			t.tween_callback(sprite.queue_free)
			for child in sprite.get_children():
				if child is StaticBody2D:
					child.queue_free()
	gates.clear()
	if zone.sound:
		Sfx.play(zone, RETRACT, 0.9, -4.0)


func _swap_music(stream: AudioStream) -> void:
	if stream == null or zone.music == null:
		return
	if stream == THEME:
		_old_music = zone.music.stream
	zone.music.stream = stream
	if zone.sound:
		Music.play_loop(zone.music)


func _burst(at: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 16.0
	p.direction = Vector2.UP
	p.spread = 90.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.position = at
	p.z_index = 5
	zone.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
