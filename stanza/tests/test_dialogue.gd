extends "res://tests/base_test.gd"
## I dialoghi con le cose: cosa c'è davanti a Lethe, i cue di stanza.dialogue, il riquadro
## (scrive, va avanti, le scelte, chiude) e Talk nella stanza vera (ferma Lethe, conta le
## visite, il karma delle scelte, il menu di pausa non si apre sotto).

const DIALOGUE := preload("res://dialogue/stanza.dialogue")
const DialogueBox := preload("res://dialogue/dialogue_box.gd")
const RoomThings := preload("res://world/room_things.gd")
const Tiles := preload("res://world/room_tileset.gd")
const Layout := preload("res://world/room_layout.gd")
const MAIN := "res://main.tscn"


func after() -> void:
	tree.paused = false
	await super()


func _things() -> Array[Dictionary]:
	return RoomThings.build(Tiles.load_data())


## Un punto per terra appena sotto la cosa `id`.
func _below(things: Array[Dictionary], id: String) -> Vector2:
	var rect := RoomThings.rect_of(things, id)
	return Vector2(rect.get_center().x, rect.end.y + 10)


func _box() -> CanvasLayer:
	var box := DialogueBox.new()
	box.sound = false
	tree.root.add_child(box)
	_owned.append(box)
	return box


## Aspetta che la riga sia arrivata (get_next_dialogue_line è asincrona).
func _wait_line(box: CanvasLayer) -> void:
	for i in 30:
		await tree.process_frame
		if not is_instance_valid(box) or is_instance_valid(box.line):
			return


## Va avanti fino in fondo scegliendo sempre la voce `pick`. Quante righe ha visto.
func _drive(box: CanvasLayer, pick := 0) -> int:
	var lines := 0
	for i in 200:
		if not is_instance_valid(box):
			break
		await tree.process_frame
		if not is_instance_valid(box):
			break
		if box.choices_panel.visible:
			box.choose(pick)
		elif box.waiting:
			lines += 1
			box.advance()
		elif is_instance_valid(box.line) and box.text_label.is_typing:
			box.advance()     # finisce di scrivere
	return lines


func test_davanti_a_lethe() -> void:
	var things := _things()
	var below := _below(things, "covered_mirror")
	assert_eq(RoomThings.in_front(things, below, Vector2.UP), "covered_mirror", "guarda lo specchio")
	assert_eq(RoomThings.in_front(things, below + Vector2(0, 40), Vector2.UP), "",
		"troppo lontana: niente")
	var start := Vector2(Layout.PLAYER_START) * 32 + Vector2(16, 16)
	assert_eq(RoomThings.in_front(things, start + Vector2(0, 60), Vector2.DOWN), "",
		"in mezzo al pavimento: niente")


func test_sul_tappeto_vince_la_cosa_piu_piccola() -> void:
	var things := _things()
	var cushion := RoomThings.rect_of(things, "cushion")
	assert_eq(RoomThings.in_front(things, cushion.get_center(), Vector2.ZERO), "cushion",
		"il cuscino, non il tappeto sotto")


func test_ogni_cue_e_una_cosa_della_stanza() -> void:
	var ids: PackedStringArray = []
	for entry in Layout.WALL_FEATURES + Layout.DECOR + Layout.OBJECTS:
		ids.append(entry[0])
	var cues := DIALOGUE.get_cues()
	assert_true(cues.size() >= 10, "ci sono i dialoghi")
	for cue in cues:
		assert_true(cue in ids, "il cue %s è un oggetto della stanza" % cue)
	# Le cose che raccontano (il vault) devono avere qualcosa da dire.
	for id in ["covered_mirror", "wall_calendar", "food_tray", "nightstand", "paper_balls",
			"dead_plant", "window", "wall_poster", "console", "door"]:
		assert_true(id in cues, "%s ha un dialogo" % id)
	assert_eq(_things().size(), ids.size(), "senza filtro ci sono tutte le cose")
	assert_eq(RoomThings.build(Tiles.load_data(), cues).size(), cues.size(), "filtrate per cue")


func test_il_riquadro_scrive_va_avanti_e_chiude() -> void:
	var box := _box()
	var done := {"ok": false}
	box.finished.connect(func(): done["ok"] = true)
	box.start(DIALOGUE, "door", [])
	await _wait_line(box)
	assert_true(box.box.visible, "il riquadro si vede")
	assert_eq(box.line.character, "", "la prima riga è del narratore")
	assert_false(box.face.visible, "niente ritratto per il narratore")
	assert_true(box.text_label.is_typing, "scrive una lettera alla volta")
	box.advance()
	assert_false(box.text_label.is_typing, "il tasto finisce la riga")
	assert_true(box.waiting, "e poi aspetta")
	box.advance()
	await _wait_line(box)
	assert_eq(box.line.character, "Lethe", "la seconda la pensa Lethe")
	assert_eq(box.name_label.text, "Lethe", "col suo nome")
	assert_eq(box.face.visible, box.face.texture != null, "il ritratto se ci sono gli sprite")
	await _drive(box)
	assert_true(done["ok"], "finito")
	assert_false(is_instance_valid(box), "e si chiude da solo")


func test_le_scelte() -> void:
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nvar truth := 0\nvar lies := 0\nfunc seen(_id: String) -> int:\n\treturn 0\n"
	script.reload()
	var box := _box()
	box.start(DIALOGUE, "covered_mirror", [script.new()])
	for i in 30:
		await tree.process_frame
		if box.choices_panel.visible:
			break
		if box.text_label.is_typing:
			box.advance()
	assert_true(box.choices_panel.visible, "compaiono le scelte")
	assert_eq(box.choice_texts().size(), 2, "due scelte")
	assert_true(box.choices.has_heart(&"0"), "il cuore sulla prima")


func test_talk_nella_stanza() -> void:
	var main := add_scene(MAIN)
	await tree.process_frame
	var talk: Node = main.talk
	var hero: CharacterBody2D = main.hero
	main.music.stop()
	# Davanti al vassoio: compare l'iconcina.
	var things: Array[Dictionary] = talk.things
	hero.global_position = main.room.global_position + _below(things, "food_tray")
	hero.facing = Vector2.UP
	await tree.process_frame
	assert_eq(talk.target, "food_tray", "il vassoio davanti")
	assert_true(talk.icon.visible, "compare l'iconcina")
	assert_near(talk.icon.position.x, roundf(hero.global_position.x), 0.5, "sulla verticale di Lethe")
	assert_true(talk.icon.position.y <= hero.global_position.y - 52.0, "sopra la sua testa")
	# Si allontana: l'icona sparisce rimpicciolendo.
	hero.global_position += Vector2(0, 120)
	await wait_seconds(0.3)
	assert_eq(talk.target, "", "niente davanti")
	assert_false(talk.icon.visible, "l'icona sparisce")
	hero.global_position -= Vector2(0, 120)
	await tree.process_frame
	await tree.process_frame     # process_frame arriva prima dei _process dei nodi
	assert_true(talk.icon.visible, "torna davanti: ricompare")

	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await tree.process_frame
	await tree.process_frame
	assert_true(talk.is_talking(), "interact apre il dialogo")
	assert_true(hero.frozen, "Lethe è ferma")
	assert_eq(talk.target, "", "niente icona mentre parla")
	assert_false(talk.icon.visible, "l'icona sparisce")
	talk.box.sound = false

	# Il menu di pausa non si apre sotto il dialogo.
	var esc := InputEventAction.new()
	esc.action = &"menu"
	esc.pressed = true
	Input.parse_input_event(esc)
	await tree.process_frame
	await tree.process_frame
	assert_false(main.pause_menu.is_open(), "niente menu di pausa")

	var box: CanvasLayer = talk.box
	var lines := await _drive(box)
	await wait_signal(talk.talk_finished, 1.0)
	assert_false(hero.frozen, "Lethe torna libera")
	assert_eq(talk.seen("food_tray"), 1, "una visita")
	assert_true(lines >= 3, "la prima volta racconta di più")

	talk.talk("food_tray")
	var again := await _drive(talk.box)
	assert_eq(again, 1, "la seconda volta una riga sola")
	assert_eq(talk.seen("food_tray"), 2, "due visite")


func test_lo_specchio_conta_la_verita_o_la_bugia() -> void:
	var main := add_scene(MAIN)
	await tree.process_frame
	main.music.stop()
	var talk: Node = main.talk
	talk.talk("covered_mirror")
	talk.box.sound = false
	await _drive(talk.box, 0)
	assert_eq(main.state.truth, 1, "guardare nell'angolo è la verità")
	assert_eq(main.state.lies, 0, "nessuna bugia")
	await tree.physics_frame
	await tree.physics_frame
	talk.talk("covered_mirror")
	talk.box.sound = false
	await _drive(talk.box, 1)
	assert_eq(main.state.truth, 1, "la seconda volta non si sceglie più")
	assert_eq(main.state.lies, 0, "...e il karma non cambia")
