extends Node
## Il combattimento e la vita in una zona (forest_zone.gd lo monta come figlio "Combat"):
## - i nemici della zona (dai dati: ENEMIES), tranne quelli già sconfitti (flag "defeated":
##   restano sconfitti anche dopo un salvataggio; tornano tutti solo quando il cuore si spezza);
## - un nemico sciolto: la sua luce vola a Lethe (esperienza, "+3 EXP", magari un livello) e
##   a volte lascia una mela per terra;
## - Lethe colpita: il cuore si stringe, lo schermo trema; stretto del tutto, "Death is a lie."
##   e ci si risveglia davanti allo specchio (o alla cornice d'argento, sottoterra);
## - alla decima morte il segreto: un finto reset, e la mano molla un po';
## - il riposo allo specchio, e il tasto della spada la prima volta che un nemico si avvicina.
##
## Legge e usa la zona (stato, Lethe, cuore, dialoghi, musica): `zone`.

signal died
signal respawned
signal leveled_up(level: int)
signal secret_shown
signal enemy_defeated(enemy: Node2D)
signal item_picked(id: String)

const Sfx := preload("res://core/sfx.gd")
const Music := preload("res://core/music.gd")
const ScreenShake := preload("res://fx/screen_shake.gd")
const ScreenText := preload("res://ui/screen_text.gd")
const Pickup := preload("res://items/pickup.gd")
const ItemIcons := preload("res://ui/item_icons.gd")
const InputSetup := preload("res://core/input_setup.gd")
const ZoneDressing := preload("zone_dressing.gd")
const Zones := preload("zones.gd")
const DIALOGUE := preload("res://dialogue/forest.dialogue")
const GLINT := preload("res://audio/shard_glint.wav")
const HURT := preload("res://audio/heart_hurt.wav")
const BREAK := preload("res://audio/heart_break.wav")
const CHIME := preload("res://audio/ui_move.wav")
const KNOCK := preload("res://audio/menu_knock.wav")
const GameOver := preload("res://ui/game_over.gd")

const ENEMY_SCRIPTS := {
	"moth": preload("res://enemies/shadow_moth.gd"),
	"bramble": preload("res://enemies/whispering_bramble.gd"),
	"firefly": preload("res://enemies/false_firefly.gd"),
}
## Alla decima volta che il cuore si spezza: il segreto (un finto reset).
const SECRET_DEATHS := 10
## Il livello dei nemici della zona.
const ZONE_LEVEL := 1
## Quanto vicino deve arrivare un nemico perché compaia il tasto della spada.
const SLASH_HINT_RANGE := 170.0
## Dove ci si riposa (e ci si risveglia): lo specchio nel bosco, la cornice sottoterra.
const REST_TILES := ["mirror", "silver_frame"]
const TILE := 32

var zone: Node2D
## Dove si riparte quando il cuore è stretto del tutto (lo Spawn, poi lo specchio).
var respawn_point := Vector2.ZERO
## L'indicazione del tasto della spada (la prima volta che un nemico si avvicina).
var slash_hint: CanvasLayer
var _dying := false


func setup(zone_node: Node2D) -> void:
	zone = zone_node
	respawn_point = mirror_point() if zone.state.flag("rested") else zone.spawn.global_position
	zone.hero.damaged.connect(_on_hero_damaged)
	zone.hero.attack_finished.connect(on_hero_attack)
	spawn_enemies()


func _sfx(stream: AudioStream, pitch := 1.0, db := 0.0) -> void:
	if zone.sound:
		Sfx.play(zone, stream, pitch, db)


# --- I nemici -------------------------------------------------------------------------------

## I nemici della zona (non i boss: quelli li tiene zone_boss.gd, non si rimettono al risveglio).
func enemies() -> Array:
	return get_tree().get_nodes_in_group(&"enemies").filter(_is_ours)


func _is_ours(e: Node) -> bool:
	return zone.is_ancestor_of(e) and not e.is_in_group(&"bosses")


func spawn_enemies() -> void:
	var defeated: Array = zone.state.flags.get("defeated", [])
	var list: Array = zone.layout_value("ENEMIES")
	for i in list.size():
		var entry: Array = list[i]
		var key := enemy_key(i)
		if key in defeated:
			continue
		var enemy: CharacterBody2D = ENEMY_SCRIPTS[entry[0]].new()
		enemy.set_meta(&"key", key)
		enemy.name = "%s_%d" % [entry[0], zone.world.get_child_count()]
		enemy.sound = zone.sound
		enemy.target = zone.hero
		enemy.position = (Vector2(entry[1]) + Vector2(0.5, 0.8)) * TILE
		enemy.level = ZONE_LEVEL
		enemy.died.connect(_on_enemy_died)
		zone.world.add_child(enemy)


## Il nome fisso di un nemico della zona (per ricordarsi chi è stato sconfitto). Nella prima
## zona senza prefisso (i salvataggi di prima), nelle altre col nome della zona.
func enemy_key(index: int) -> String:
	var key := "%s_%d" % [zone.layout_value("ENEMIES")[index][0], index]
	return key if zone.zone_id == Zones.FIRST else "%s:%s" % [zone.zone_id, key]


func _on_enemy_died(enemy: Node2D) -> void:
	var defeated: Array = zone.state.flags.get("defeated", [])
	if enemy.has_meta(&"key") and not enemy.get_meta(&"key") in defeated:
		defeated.append(enemy.get_meta(&"key"))
	zone.state.flags["defeated"] = defeated
	enemy_defeated.emit(enemy)
	var at: Vector2 = enemy.global_position
	var amount: int = zone.state.exp_from(int(enemy.get(&"exp_reward")), int(enemy.get(&"level")))
	_fly_motes(at + Vector2(0, -12), amount)
	if randf() < float(enemy.get(&"drop_chance")):
		drop("apple", at)


# --- Oggetti ed esperienza --------------------------------------------------------------------

## Lascia un oggetto per terra in `at`.
func drop(id: String, at: Vector2) -> Node2D:
	var item: Area2D = Pickup.new()
	item.id = id
	item.position = at
	item.picked.connect(_on_picked)
	if ItemIcons.info(id).get("effect", {}).has("heal"):
		item.wanted = func() -> bool: return zone.state.heart < zone.state.heart_max   # a cuore pieno resta lì
	zone.world.add_child.call_deferred(item)
	return item


func _on_picked(id: String) -> void:
	item_picked.emit(id)
	var effect: Dictionary = ItemIcons.info(id).get("effect", {})
	zone.state.heal(int(effect.get("heal", 0)))
	zone.hud.show_heart(zone.state.heart, zone.state.heart_max)
	_sfx(GLINT, 1.4, -6.0)


## La luce del nemico: puntini viola che volano a Lethe uno dopo l'altro; quando arriva
## l'ultimo, l'esperienza.
func _fly_motes(from: Vector2, amount: int) -> void:
	var count := clampi(amount, 1, 6)
	for i in count:
		var mote := Node2D.new()
		mote.draw.connect(func() -> void:
			mote.draw_rect(Rect2(-2, -2, 4, 4), Color(0.78, 0.62, 1.0))
			mote.draw_rect(Rect2(-1, -1, 2, 2), Color(1, 1, 1)))
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mote.material = mat
		mote.z_index = 6
		zone.add_child(mote)
		mote.global_position = from
		var side := Vector2(randf_range(-30, 30), randf_range(-36, -14))
		var t := create_tween()
		t.tween_interval(0.08 * i)
		t.tween_method(func(k: float) -> void:
			if not is_instance_valid(zone.hero) or not is_instance_valid(mote):
				return
			var goal: Vector2 = zone.hero.global_position + Vector2(0, -24)
			var mid := from + side
			mote.global_position = from.lerp(mid, k).lerp(mid.lerp(goal, k), k), 0.0, 1.0, 0.55)
		t.tween_callback(mote.queue_free)
		if i == count - 1:
			t.tween_callback(gain_exp.bind(amount))


func gain_exp(amount: int) -> void:
	var state: RefCounted = zone.state
	var levels: int = state.gain_exp(amount)
	ScreenText.float_text(zone, zone.hero.global_position + Vector2(0, -58), "+%d EXP" % amount,
		Color(0.8, 0.66, 1.0))
	_sfx(CHIME, 1.8, -10.0)
	if levels > 0:
		zone.hud.show_heart(state.heart, state.heart_max)
		zone.sync_abilities()
		var line := "Her heart holds a little more." if state.level % 2 == 0 else "The shard cuts a little deeper."
		ScreenText.toast(zone, "LV %d" % state.level, line)
		_sfx(GLINT, 0.9, -4.0)
		leveled_up.emit(state.level)


# --- Il tasto della spada -----------------------------------------------------------------------

## La prima volta che un nemico si avvicina (dopo la scena del primo nemico, e con la
## spada): accanto al cuore, il tasto. Sparisce al primo fendente (flag "slash_learned").
func check_slash_hint() -> void:
	var state: RefCounted = zone.state
	if slash_hint or not state.flag("first_enemy_seen") or state.flag("slash_learned") \
			or not state.can_slash() or zone.talk.is_talking():
		return
	for enemy in enemies():
		if enemy.global_position.distance_to(zone.hero.global_position) < SLASH_HINT_RANGE:
			show_slash_hint()
			return


func show_slash_hint() -> void:
	slash_hint = CanvasLayer.new()
	slash_hint.layer = 7
	zone.add_child(slash_hint)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", preload("res://menu/menu_style.gd").window_style())
	var box: Control = zone.hud.box
	panel.position = Vector2(box.position.x + box.size.x + 8, box.position.y)
	panel.add_child(ScreenText.label("%s  Swing the shard" % InputSetup.LABELS[&"action"], Color(0.95, 0.9, 1.0)))
	slash_hint.add_child(panel)
	panel.modulate.a = 0.0
	var t := create_tween().set_loops(4)
	t.tween_property(panel, "modulate:a", 1.0, 0.4)
	t.tween_interval(0.8)
	t.tween_property(panel, "modulate:a", 0.75, 0.4)


func on_hero_attack(kind: StringName) -> void:
	if kind != &"slash":
		return
	zone.state.set_flag("slash_learned")
	if slash_hint:
		var hint := slash_hint
		slash_hint = null
		var t := create_tween()
		t.tween_property(hint.get_child(0), "modulate:a", 0.0, 0.3)
		t.tween_callback(hint.queue_free)


# --- Il cuore, la morte, il riposo ----------------------------------------------------------------

func _on_hero_damaged(amount: int, _from: Vector2) -> void:
	if _dying:
		return
	var state: RefCounted = zone.state
	state.hurt(amount)
	zone.hud.show_heart(state.heart, state.heart_max)
	zone.hud.hit()
	_sfx(HURT, randf_range(0.95, 1.05), -2.0)
	var shake := ScreenShake.new()
	shake.strength = 3.0
	shake.duration = 0.2
	get_tree().root.add_child(shake)
	if state.is_dead():
		die()


## Il cuore stretto del tutto: la schermata del cuore spezzato (ui/game_over.gd: il fermo
## immagine, gli occhi, la mano, "Death is a lie.", qualcuno bussa), e Lethe si risveglia
## davanti allo specchio col cuore intero (i nemici tornano al loro posto). La prima volta
## per intero, poi un po' più in fretta.
func die(pace := 1.0) -> void:
	if _dying:
		return
	_dying = true
	zone.hero.set(&"frozen", true)
	for enemy in enemies():
		enemy.set_physics_process(false)
	_sfx(BREAK, 1.0, -2.0)
	died.emit()
	if zone.state.add_death() == SECRET_DEATHS:
		await _secret(pace)
		return
	var frozen: Image = null
	if DisplayServer.get_name() != "headless":        # l'istante, per il fermo immagine
		frozen = get_viewport().get_texture().get_image()
	if zone.music:
		zone.music.stop()                              # la musica si taglia di colpo
	var screen := GameOver.new()
	screen.sound = zone.sound
	screen.pace = pace * (1.0 if zone.state.deaths() <= 1 else 0.7)
	screen.eye_count = 7 + mini(int(zone.state.lies), 9)     # qualcuno ha visto
	zone.add_child(screen)
	await screen.play(frozen)
	respawn()
	if zone.music and zone.sound:
		Music.play_loop(zone.music)
	await screen.fade_out(1.2 * pace)
	_dying = false
	respawned.emit()
	zone.talk.say(DIALOGUE, "wake_again")


## Il segreto della decima morte: un finto reset. Il gioco si spegne di colpo (niente
## musica), dal nero torna il titolo... ma di ALETHEIA cadono le lettere intorno e resta
## LETHE. "Ten times. She keeps waking up." Qualcuno bussa: "Lethe? ...Are you awake?".
## E la mano, per una volta, molla un po': il cuore regge una stretta in più.
func _secret(pace := 1.0) -> void:
	zone.music.stop()
	var black := ScreenText.black_layer(zone, 80, 1.0)
	var canvas := black.get_parent()
	await get_tree().create_timer(1.2 * pace).timeout
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, 110)
	row.size = Vector2(640, 52)
	row.add_theme_constant_override(&"separation", 0)
	canvas.add_child(row)
	var letters: Array[Label] = []
	for ch in "ALETHEIA":
		var l := ScreenText.label(ch, Color(0.93, 0.9, 1.0), 48)
		l.add_theme_color_override(&"font_shadow_color", Color(0.28, 0.14, 0.46))
		l.add_theme_constant_override(&"shadow_offset_y", 3)
		row.add_child(l)
		letters.append(l)
	row.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(row, "modulate:a", 1.0, 1.0 * pace)
	t.tween_interval(1.0 * pace)
	await t.finished
	for i in [0, 6, 7]:                     # le lettere intorno al nome cadono: resta LETHE
		var fall := create_tween().set_parallel()
		fall.tween_property(letters[i], "modulate:a", 0.0, 0.7 * pace)
		fall.tween_property(letters[i], "position:y", 60.0, 0.7 * pace).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
	for i in range(1, 6):
		letters[i].add_theme_color_override(&"font_color", Color(1.0, 0.82, 1.0))
	await get_tree().create_timer(1.4 * pace).timeout
	var lines := VBoxContainer.new()
	lines.position = Vector2(0, 190)
	lines.size = Vector2(640, 90)
	canvas.add_child(lines)
	var pale := Color(0.78, 0.76, 0.88)
	for pair in [["Ten times.", pale], ["She keeps waking up.", pale], ["", pale],
			["Lethe? ...Are you awake?", Color(1.0, 0.8, 0.52)]]:
		var label := ScreenText.label(pair[0], pair[1])
		label.modulate.a = 0.0
		lines.add_child(label)
		if String(pair[0]).begins_with("Lethe?"):
			_sfx(KNOCK, 1.0, -4.0)
		create_tween().tween_property(label, "modulate:a", 1.0, 0.8 * pace)
		await get_tree().create_timer(1.4 * pace).timeout
	var state: RefCounted = zone.state
	state.heart_max = mini(state.HEART_CAP, state.heart_max + 1)       # la mano molla un po'
	state.set_flag("secret_ten")
	secret_shown.emit()
	await get_tree().create_timer(1.6 * pace).timeout
	respawn()
	if zone.sound:
		Music.play_loop(zone.music)
	var back := create_tween()
	back.tween_property(black, "color:a", 0.0, 1.2 * pace)
	back.parallel().tween_property(row, "modulate:a", 0.0, 0.8 * pace)
	back.parallel().tween_property(lines, "modulate:a", 0.0, 0.8 * pace)
	await back.finished
	canvas.queue_free()
	_dying = false
	respawned.emit()
	ScreenText.toast(zone, "The hand loosens, a little.", "Her heart holds one more.")


## Di nuovo in piedi: davanti allo specchio (o allo Spawn), cuore intero, nemici al posto.
func respawn() -> void:
	var state: RefCounted = zone.state
	state.flags.erase("defeated")
	for enemy in enemies():
		enemy.queue_free()
	spawn_enemies.call_deferred()
	state.heal(state.heart_max)
	zone.hud.show_heart(state.heart, state.heart_max)
	if zone.light:
		zone.light.restore()
	var hero: CharacterBody2D = zone.hero
	hero.global_position = respawn_point
	hero.set(&"knock", Vector2.ZERO)
	hero.set(&"invulnerable", 0.0)
	hero.set(&"frozen", false)
	zone.camera.reset_smoothing()


## Lo specchio (o la cornice): ci si riposa (il cuore torna intero) e da qui si riparte.
func rest() -> void:
	var state: RefCounted = zone.state
	state.heal(state.heart_max)
	zone.hud.show_heart(state.heart, state.heart_max)
	if zone.light:
		zone.light.restore()                    # e anche la luce
	respawn_point = mirror_point()
	state.set_flag("rested")
	_sfx(GLINT, 1.0, -8.0)


## Dove ci si risveglia davanti allo specchio (o alla cornice d'argento, sottoterra; lo
## Spawn, se non c'è nessuno dei due).
func mirror_point() -> Vector2:
	for sprite in ZoneDressing.thing_nodes(zone.world):
		if sprite.get_meta(&"tile") in REST_TILES:
			return sprite.global_position + Vector2(0, 20)
	return zone.spawn.global_position
