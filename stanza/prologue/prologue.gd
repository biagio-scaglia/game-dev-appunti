extends Node
## Il regista del prologo, nella stanza (vault: "Trama - bozza"):
## - il risveglio: dopo la cutscene del calendario Lethe è accanto al letto, al buio; gli
##   occhi si aprono due volte (il nero si apre e si richiude), un respiro, si alza, e il
##   narratore: "Night. The same night." La prima volta, accanto al fumetto c'è il tasto;
## - lo specchio che chiama: quando chi bussava se n'è andato e Lethe ha guardato
##   abbastanza cose (LOOKS_NEEDED), l'angolo scoperto dello specchio si accende, la musica
##   della stanza si spegne e parte quella dello specchio, e il narratore lo dice. Ogni
##   "Not yet." lo fa brillare di più;
## - la caduta: "Pull the sheet off." -> mirror_fall.gd. Alla fine Lethe ha la scheggia
##   (la spada di vetro) e il prologo è finito: `finished`.
##
## In alto a sinistra, l'obiettivo di adesso (ui/objective_banner.gd): guardare la stanza
## (n/5), andare alla porta quando bussano, andare allo specchio quando chiama. Se Lethe ha
## già guardato tutto e non hanno ancora bussato, bussano subito (niente attese a vuoto).
##
## I dialoghi leggono qui `mirror_calling` e `call_visits` e chiamano pull_sheet() e
## not_yet() (è tra gli extra_states di Talk). Lo stato del prologo sta nei flag della
## partita, così si salva.

signal call_started
signal finished

const DIALOGUE := preload("res://dialogue/prologue.dialogue")
const MirrorGlow := preload("mirror_glow.gd")
const MirrorFall := preload("mirror_fall.gd")
const ObjectiveBanner := preload("res://ui/objective_banner.gd")
const Music := preload("res://core/music.gd")
const Sfx := preload("res://core/sfx.gd")
const RoomThings := preload("res://world/room_things.gd")
const MIRROR_THEME := preload("res://audio/mirror_theme.wav")
const WAKE := preload("res://audio/wake_up.wav")
const RUSTLE := preload("res://audio/sheet_rustle.wav")
const GLINT := preload("res://audio/shard_glint.wav")

## Quante cose diverse deve guardare Lethe prima che lo specchio chiami.
const LOOKS_NEEDED := 5
## Dove si sveglia: la cella del pavimento accanto al letto.
const WAKE_CELL := Vector2i(3, 8)
## L'angolo scoperto dello specchio, rispetto all'angolo in alto a sinistra del suo tile.
const MIRROR_CORNER := Vector2(23, 50)
const MIRROR_DB := -10.0
## Quanto si accende lo specchio la prima volta, e quanto in più a ogni "Not yet."
const CALL_START := 0.4
const CALL_STEP := 0.2

var room: Node2D
var hero: Node2D
var talk: Node
var knock: Node2D
var state: RefCounted
var room_music: AudioStreamPlayer
var glow: Node2D
var mirror_music: AudioStreamPlayer
## Falso nei test: niente suoni.
var sound := true

## Letti dai dialoghi.
var mirror_calling := false
var call_visits := 0
var _pulled := false
var _falling := false
var _black: ColorRect
## L'obiettivo in alto.
var objective: CanvasLayer
## Falso mentre si sveglia (niente obiettivo finché non ha aperto gli occhi).
var _awake := true

const GOAL_LOOK := "Look around the room (%d/%d)"
const GOAL_DOOR := "Someone is knocking. Go to the door"
const GOAL_MIRROR := "Go to the mirror"


func setup(room_node: Node2D, hero_node: Node2D, talk_node: Node, knock_node: Node2D,
		game_state: RefCounted, music: AudioStreamPlayer) -> void:
	room = room_node
	hero = hero_node
	talk = talk_node
	knock = knock_node
	state = game_state
	room_music = music
	glow = MirrorGlow.new()
	glow.position = mirror_corner()
	glow.z_index = 1
	room.get_parent().add_child(glow)
	mirror_music = AudioStreamPlayer.new()
	mirror_music.stream = MIRROR_THEME
	mirror_music.volume_db = -40.0
	add_child(mirror_music)
	objective = ObjectiveBanner.new()
	add_child(objective)
	talk.extra_states.append(self)
	talk.key_hint = not state.flag("talk_learned")
	talk.talk_finished.connect(_on_talk_finished)
	knock.ended.connect(_on_knock_ended)
	# Da un salvataggio: quello che è già successo resta successo.
	if state.flag("knock_over"):
		knock.knock_over = true
	call_visits = int(state.flags.get("call_visits", 0))
	if state.flag("mirror_calling"):
		_call(false)


## Dove sta l'angolo scoperto dello specchio, nel mondo.
func mirror_corner() -> Vector2:
	var things := RoomThings.build(room.data, PackedStringArray(["covered_mirror"]))
	var rect := RoomThings.rect_of(things, "covered_mirror")
	return room.position + rect.position + MIRROR_CORNER


func wake_position() -> Vector2:
	return room.position + room.floor_layer.map_to_local(WAKE_CELL)


func _sfx(stream: AudioStream, db := 0.0) -> void:
	if sound:
		Sfx.play(self, stream, 1.0, db)


# --- Il risveglio -----------------------------------------------------------------------

## Il risveglio dopo la cutscene. `pace` accorcia le attese (test).
func wake_up(pace := 1.0) -> void:
	_awake = false
	hero.global_position = wake_position()
	hero.set(&"facing", Vector2.DOWN)
	hero.set(&"frozen", true)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = Vector2(640, 360)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	if room_music:
		room_music.volume_db = -40.0
		create_tween().tween_property(room_music, "volume_db", 0.0, 6.0 * pace)
	await get_tree().create_timer(0.8 * pace).timeout
	_sfx(WAKE, -4.0)
	# Gli occhi che si aprono: due volte quasi, la terza davvero.
	var eyes := create_tween()
	eyes.tween_property(_black, "color:a", 0.55, 0.9 * pace).set_trans(Tween.TRANS_SINE)
	eyes.tween_property(_black, "color:a", 0.95, 0.5 * pace)
	eyes.tween_interval(0.4 * pace)
	eyes.tween_property(_black, "color:a", 0.35, 0.8 * pace).set_trans(Tween.TRANS_SINE)
	eyes.tween_property(_black, "color:a", 0.8, 0.35 * pace)
	eyes.tween_interval(0.3 * pace)
	eyes.tween_property(_black, "color:a", 0.0, 1.6 * pace).set_trans(Tween.TRANS_SINE)
	await eyes.finished
	layer.queue_free()
	# Si alza: un piccolo salto, il lenzuolo.
	_sfx(RUSTLE, -8.0)
	var sprite: Node2D = hero.get_node_or_null(^"Sprite")
	if sprite:
		var rise := create_tween()
		rise.tween_property(sprite, "scale", Vector2(1.08, 0.9), 0.12 * pace)
		rise.tween_property(sprite, "scale", Vector2(0.95, 1.06), 0.12 * pace)
		rise.parallel().tween_property(sprite, "position:y", -3.0, 0.12 * pace)
		rise.tween_property(sprite, "scale", Vector2.ONE, 0.15 * pace)
		rise.parallel().tween_property(sprite, "position:y", 0.0, 0.15 * pace)
		await rise.finished
	await get_tree().create_timer(0.5 * pace).timeout
	state.set_flag("woke_up")
	talk.say(DIALOGUE, "wake_up")


# --- L'obiettivo ------------------------------------------------------------------------

## Cosa fare adesso, in una riga ("" = niente).
static func objective_for(awake: bool, looked: int, knocking: bool, calling: bool,
		falling: bool) -> String:
	if not awake or falling:
		return ""
	if calling:
		return GOAL_MIRROR
	if knocking:
		return GOAL_DOOR
	return GOAL_LOOK % [mini(looked, LOOKS_NEEDED), LOOKS_NEEDED]


func current_objective() -> String:
	return objective_for(_awake, state.looked_count(), knock.knocking, mirror_calling, _falling)


func _process(_delta: float) -> void:
	if objective and state:
		objective.show_text(current_objective())


# --- Lo specchio che chiama --------------------------------------------------------------

func is_ready_to_call() -> bool:
	return not mirror_calling and state.flag("knock_over") and state.looked_count() >= LOOKS_NEEDED


func _on_knock_ended(_answered: bool) -> void:
	state.set_flag("knock_over")
	_check_call()


func _on_talk_finished(id: String) -> void:
	if id == "wake_up":
		_awake = true
	if talk.things.any(func(t: Dictionary) -> bool: return t["id"] == id):
		state.look(id)
		state.set_flag("talk_learned")
		if state.looked_count() >= LOOKS_NEEDED:
			knock.hurry()
	if id == "covered_mirror" and _pulled:
		fall()
		return
	_check_call()


func _check_call() -> void:
	if is_ready_to_call() and not talk.is_talking():
		_call(true)


## Lo specchio comincia a chiamare. `announce`: con il suono e il narratore (non quando si
## riprende da un salvataggio).
func _call(announce: bool) -> void:
	mirror_calling = true
	state.set_flag("mirror_calling")
	var target := minf(1.0, CALL_START + CALL_STEP * call_visits)
	var light := create_tween()
	light.tween_property(glow, "intensity", target, 2.5 if announce else 0.01)
	# La musica della stanza si spegne, quella dello specchio sale piano.
	if room_music:
		var fade := create_tween()
		fade.tween_property(room_music, "volume_db", -40.0, 3.0)
		fade.tween_callback(room_music.stop)
	if sound:
		Music.play_loop(mirror_music)
	create_tween().tween_property(mirror_music, "volume_db", MIRROR_DB, 4.0)
	call_started.emit()
	if announce:
		_sfx(GLINT, -10.0)
		await get_tree().create_timer(1.2).timeout
		talk.say(DIALOGUE, "mirror_calls")


func not_yet() -> void:
	call_visits += 1
	state.flags["call_visits"] = call_visits
	create_tween().tween_property(glow, "intensity", minf(1.0, CALL_START + CALL_STEP * call_visits), 1.2)


func pull_sheet() -> void:
	_pulled = true


# --- La caduta --------------------------------------------------------------------------

func fall(pace := 1.0) -> void:
	if _falling:
		return
	_falling = true
	hero.set(&"frozen", true)
	var mirror_fall := MirrorFall.new()
	mirror_fall.sound = sound
	mirror_fall.pace = pace
	add_child(mirror_fall)
	await mirror_fall.play(glow, hero, mirror_music)
	state.give("glass_sword")
	state.set_flag("prologue_done")
	finished.emit()
