extends "res://tests/base_test.gd"
## La cutscene di New Game: il calendario si barra fino al giorno cerchiato, la frase e le
## sue eco sempre più sbiadite, il nero alla fine; per saltarla servono due tasti. Il titolo
## ci passa solo con New Game.

const OPENING := "res://opening/opening.tscn"
const CalendarPage := preload("res://opening/calendar_page.gd")
const Opening := preload("res://opening/opening.gd")
const Main := preload("res://main.gd")


func after() -> void:
	Main.pending_save = {}
	Main.from_opening = false
	await super()


func _opening() -> Control:
	return add_scene(OPENING, func(n):
		n.next_scene = ""
		n.sound = false)


func _key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_A
	e.pressed = true
	return e


func test_arriva_fino_in_fondo() -> void:
	Engine.time_scale = 8.0
	var o := _opening()
	await tree.process_frame
	assert_near(o.black.color.a, 1.0, 0.001, "parte dal nero")
	assert_true(await wait_signal(o.finished, 6.0), "finisce")
	assert_eq(o.calendar.crossed, CalendarPage.CIRCLED_DAY - 1, "barrati fino al giorno prima")
	assert_near(o.calendar.circle, 1.0, 0.001, "e quello cerchiato")
	assert_eq(o.lines.get_child_count(), Opening.ECHOES, "la frase e le sue eco")
	assert_eq(o.lines.get_child(0).text, Opening.LINE, "domani esco")
	assert_near(o.black.color.a, 1.0, 0.001, "finisce nel nero")


func test_per_saltare_servono_due_tasti() -> void:
	var o := _opening()
	await tree.process_frame
	o._unhandled_input(_key())
	assert_true(o.hint.visible, "il primo tasto chiede conferma")
	assert_false(o.is_done(), "non salta")
	o._unhandled_input(_key())
	assert_true(o.is_done(), "il secondo salta")
	assert_true(await wait_signal(o.finished, 2.0), "e finisce")


func test_le_eco_sbiadiscono() -> void:
	for i in Opening.ECHOES - 1:
		assert_true(Opening.echo_alpha(i + 1) < Opening.echo_alpha(i), "la %d è più chiara della %d" % [i, i + 1])
	assert_true(Opening.echo_alpha(Opening.ECHOES - 1) > 0.05, "anche l'ultima si legge appena")


func test_il_calendario() -> void:
	assert_eq(CalendarPage.cell_rect(1).position, CalendarPage.MARGIN + Vector2(CalendarPage.FIRST_COLUMN * 32, 0),
		"il primo cade di giovedì")
	var last := CalendarPage.cell_rect(CalendarPage.DAYS)
	assert_true(last.end.y <= CalendarPage.PAPER_SIZE.y, "l'ultimo giorno sta sul foglio")
	for day in [1, 11]:
		var rect := CalendarPage.cell_rect(day)
		for b in CalendarPage.cross_blocks(rect):
			assert_true(rect.encloses(Rect2(b, Vector2(2, 2))), "la X del %d sta nella casella" % day)
	assert_eq(CalendarPage.circle_blocks(CalendarPage.cell_rect(12), 0.0).size(), 0, "cerchio non iniziato")
	assert_true(CalendarPage.circle_blocks(CalendarPage.cell_rect(12), 1.0).size() > 20, "cerchio intero")


func test_solo_new_game_passa_dalla_cutscene() -> void:
	var title: Control = load("res://title/title_screen.tscn").instantiate()
	Main.pending_save = {}
	assert_eq(title.scene_after_start(), OPENING, "New Game: la cutscene")
	Main.pending_save = {"truth": 1}
	assert_eq(title.scene_after_start(), "res://main.tscn", "Continue: dritto nella stanza")
	title.next_scene = ""
	assert_eq(title.scene_after_start(), "", "nei test resta lì")
	title.free()
	var o: Control = load(OPENING).instantiate()
	assert_eq(o.next_scene, "res://main.tscn", "dopo la cutscene, la stanza")
	o.free()
