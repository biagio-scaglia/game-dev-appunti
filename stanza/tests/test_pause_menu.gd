extends "res://tests/base_test.gd"
## Il menu di pausa: apre e ferma il gioco, le pagine, la barra d'aiuto, equipaggiare,
## scegliere l'incantesimo, salvare e caricare, il File 3, le scritte che si guastano, il
## "no" sulle cose che non si possono, gli eventi dopo un salvataggio, i suoni, Game End.

const MENU := "res://menu/pause_menu.tscn"
const SaveStore := preload("res://menu/save_store.gd")
const ScreenShatter := preload("res://fx/screen_shatter.gd")

var _real_dir := ""


func before() -> void:
	_real_dir = SaveStore.dir
	SaveStore.dir = "user://test_saves"
	for slot in range(1, SaveStore.SLOTS + 1):
		SaveStore.erase(slot)


func after() -> void:
	tree.paused = false
	for slot in range(1, SaveStore.SLOTS + 1):
		SaveStore.erase(slot)
	SaveStore.dir = _real_dir
	await super()


## Una protagonista finta: basta un Node2D con lo stadio della spada.
func _hero() -> Node2D:
	var script := GDScript.new()
	script.source_code = "extends Node2D\nvar sword_stage := 0\n"
	script.reload()
	var hero := Node2D.new()
	hero.set_script(script)
	tree.root.add_child(hero)
	_owned.append(hero)
	return hero


func _menu(hero: Node2D = null) -> CanvasLayer:
	var menu := add_scene(MENU, func(n): n.title_scene = "")
	menu.setup(menu.state, hero, null)
	# Niente a caso durante i test: guasti, suoni e reazioni si chiamano a mano.
	menu.glitcher.set_process(false)
	menu.ambience.set_process(false)
	menu.reactions.stop_chance = 0.0
	menu.reactions.save_event_chance = 0.0
	return menu


func test_apre_ferma_il_gioco_e_chiude() -> void:
	var menu := _menu()
	assert_false(menu.visible, "nascosto all'inizio")
	menu.open()
	await tree.process_frame
	assert_true(menu.visible and menu.is_open(), "aperto")
	assert_true(tree.paused, "gioco in pausa")
	assert_eq(menu.commands.focused_id(), &"items", "il cuore sulla prima voce")
	menu.back()
	assert_false(menu.is_open() or menu.visible, "chiuso")
	assert_false(tree.paused, "il gioco riparte")


func test_ogni_voce_apre_la_sua_pagina_e_indietro_torna_alle_voci() -> void:
	var menu := _menu()
	menu.open()
	for id in [&"items", &"spells", &"equip", &"status", &"save", &"load", &"end"]:
		menu.choose(id)
		await tree.process_frame
		assert_eq(menu.view, id, "pagina " + id)
		assert_false(menu.party.visible, "il gruppo è nascosto in " + id)
		menu.back()
		await tree.process_frame
		assert_eq(menu.view, &"", "di nuovo alle voci")
		assert_eq(menu.commands.focused_id(), id, "il cuore torna su " + id)
	assert_true(menu.is_open(), "indietro da una pagina non chiude")


func test_un_oggetto_riguardato_cambia_descrizione() -> void:
	var menu := _menu()
	menu.open()
	menu.choose(&"items")
	await tree.process_frame
	var list: VBoxContainer = menu.items_view.list
	assert_true(menu.help_text().begins_with("Rice gone cold"), "la prima descrizione, nella barra d'aiuto")
	list.get_child(1).grab_focus()
	list.get_child(0).grab_focus()
	assert_true(menu.help_text().begins_with("Someone still knocks"), "la seconda volta è un'altra")


func test_la_barra_d_aiuto_spiega_voce_e_tasti() -> void:
	var menu := _menu()
	menu.open()
	assert_eq(menu.help_text(), "Things you found in the room.", "aiuto della prima voce")
	assert_eq(menu.keys_label.text, "Space: choose    Esc: close", "tasti sulle voci")
	menu.commands.get_node("equip").grab_focus()
	assert_eq(menu.help_text(), "Change what Lethe holds and wears.", "l'aiuto segue il cuore")
	menu.choose(&"equip")
	assert_eq(menu.keys_label.text, "Space: choose    Esc: back", "tasti in una pagina")


func test_equipaggiare_un_arma_cambia_i_parametri() -> void:
	var menu := _menu(_hero())
	menu.state.give("glass_sword")
	menu.state.give("toy_wand")
	menu.open()
	menu.choose(&"equip")
	var equip: HBoxContainer = menu.equip_view
	assert_true(equip.slots.get_node("weapon").text.contains("Mirror Shard"), "lo slot mostra l'arma")
	equip.open_slot("weapon")
	assert_eq(equip.mode, &"items", "si sceglie l'oggetto")
	assert_eq(equip.items.focused_id(), &"glass_sword", "il cuore su quella che ha")
	equip.items.get_node("toy_wand").grab_focus()
	assert_eq(equip.preview_text("M.ATK"), "> 14", "anteprima: M.ATK sale")
	assert_eq(equip.preview_text("ATK"), "> 2", "anteprima: ATK scende")
	equip.items.chosen.emit(&"toy_wand")
	assert_eq(menu.state.equipped["weapon"], "toy_wand", "equipaggiata")
	assert_eq(equip.mode, &"slots", "di nuovo agli slot")
	assert_eq(menu.help_text(), "Equipped: Toy Wand.", "conferma nella barra d'aiuto")
	menu.back()
	menu.choose(&"status")
	assert_eq(menu.status_view.slot_text("weapon"), "Toy Wand", "lo stato la mostra")
	assert_eq(menu.status_view.param_text("M.ATK"), "14", "e i parametri cambiano")


func test_indietro_dagli_oggetti_torna_agli_slot() -> void:
	var menu := _menu()
	menu.open()
	menu.choose(&"equip")
	menu.equip_view.open_slot("body")
	menu.back()
	assert_eq(menu.view, &"equip", "ancora nella pagina")
	assert_eq(menu.equip_view.mode, &"slots", "agli slot")
	assert_eq(menu.equip_view.slots.focused_id(), &"body", "sullo slot di prima")
	menu.back()
	assert_eq(menu.view, &"", "poi alle voci")


func test_all_inizio_tutto_e_punto_interrogativo() -> void:
	var menu := _menu(_hero())
	menu.open()
	menu.choose(&"spells")
	var spells: VBoxContainer = menu.spells_view
	assert_true(spells.header.text.ends_with("(none)"), "niente su Spazio / J")
	for button: Button in spells.list.get_children():
		assert_true(button.text.begins_with("???"), "%s: ???" % button.name)
	menu.back()
	menu.choose(&"items")
	assert_false(menu.items_view.list.has_node("shard"), "senza spada niente schegge")
	menu.back()
	menu.choose(&"equip")
	var equip: HBoxContainer = menu.equip_view
	assert_true(equip.slots.get_node("weapon").text.contains("(none)"), "a mani vuote")
	equip.open_slot("weapon")
	assert_eq(equip.items.focused_id(), &"none", "il cuore su (none)")
	assert_eq(equip.items.get_node("glass_sword").text, "???", "la spada non si sa ancora")
	equip.items.get_node("glass_sword").grab_focus()
	assert_eq(equip.preview_text("ATK"), "", "nessuna anteprima")
	equip.items.chosen.emit(&"glass_sword")
	assert_eq(menu.state.equipped["weapon"], "", "non si mette")
	assert_eq(menu.help_text(), "You don't have this yet.", "e lo dice")
	menu.back()
	menu.back()
	menu.choose(&"status")
	assert_eq(menu.status_view.spell_label.text, "(none)", "lo stato: nessun incantesimo")


func test_scegliere_l_incantesimo_su_spazio() -> void:
	var menu := _menu()
	menu.state.learn("truth_spark")
	menu.open()
	menu.choose(&"spells")
	var spells: VBoxContainer = menu.spells_view
	assert_true(spells.header.text.contains("Truth Spark"), "quello pronto")
	assert_true(spells.list.get_node("truth_spark").text.contains("(ready)"), "segnato nella lista")
	assert_true(spells.list.get_node("moonlight").text.begins_with("???"), "quelli non imparati")
	var denied := {"n": 0}
	menu.reactions.happened.connect(func(e): if e == &"deny": denied["n"] += 1)
	spells.list.chosen.emit(&"moonlight")
	assert_eq(menu.state.spell, "truth_spark", "uno non imparato non si sceglie")
	assert_eq(denied["n"], 1, "e si sente il no")
	assert_eq(menu.help_text(), "You haven't learned this yet.", "e lo dice")


func test_salva_e_carica_posizione_e_spada() -> void:
	var hero := _hero()
	hero.global_position = Vector2(120, 80)
	hero.sword_stage = 2
	var menu := _menu(hero)
	menu.open()
	menu.choose(&"save")
	menu.save_view.slot_chosen.emit(1)
	assert_true(SaveStore.exists(1), "file scritto")
	assert_true(menu.message_text().begins_with("Saved"), "messaggio di salvataggio")
	assert_true(menu.save_view.list.get_node("slot1").text.contains("Lethe"), "lo slot mostra il salvataggio")
	menu.back()
	menu.back()

	hero.global_position = Vector2.ZERO
	hero.sword_stage = 0
	menu.open()
	menu.choose(&"load")
	menu.save_view.slot_chosen.emit(1)
	assert_eq(hero.global_position, Vector2(120, 80), "posizione ripresa")
	assert_eq(hero.sword_stage, 2, "spada ripresa")
	assert_false(menu.is_open(), "caricare chiude il menu")


func test_caricare_chiede_di_ricaricare_la_scena_del_posto() -> void:
	var menu := _menu(_hero())
	menu.state.place = "The Forest"
	menu.open()
	menu.choose(&"save")
	menu.save_view.slot_chosen.emit(1)
	menu.back()
	menu.back()
	var got: Array = []
	menu.loaded.connect(got.append)
	menu.open()
	menu.choose(&"load")
	menu.save_view.slot_chosen.emit(1)
	assert_eq(got.size(), 1, "chi ospita il menu lo sa (e ricarica la scena)")
	assert_eq(String(got[0].get("place")), "The Forest", "col salvataggio giusto")
	assert_eq(preload("res://main.gd").scene_for_save(got[0]), "res://forest/zone_wake.tscn",
		"si torna nella foresta")
	assert_eq(preload("res://main.gd").scene_for_save({"place": "Her Room"}), "res://main.tscn",
		"o nella stanza")


func test_nella_foresta_il_menu_non_ha_i_suoni_della_stanza() -> void:
	var menu := _menu()
	menu.state.place = "The Forest"
	menu.open()
	for i in 6:
		assert_eq(menu.ambience.play_random(), &"glass", "nella foresta c'è solo lo specchio")
	menu.reactions.save_event_chance = 1.0
	for i in 12:
		var event: StringName = menu.reactions.after_save(1, null)
		assert_false(event in [&"knock", &"watched"], "niente porta né telefono dopo un salvataggio")
	menu.back()
	menu.state.place = "Her Room"
	menu.open()
	var heard := {}
	for i in 20:
		heard[menu.ambience.play_random()] = true
	assert_true(heard.has(&"knock") or heard.has(&"phone"), "nella stanza sì")


func test_caricare_uno_slot_vuoto_non_fa_niente() -> void:
	var hero := _hero()
	hero.global_position = Vector2(5, 5)
	var menu := _menu(hero)
	menu.open()
	menu.choose(&"load")
	menu.save_view.slot_chosen.emit(2)
	assert_eq(menu.message_text(), "There is nothing there.", "messaggio")
	assert_eq(hero.global_position, Vector2(5, 5), "posizione intatta")
	assert_true(menu.is_open(), "il menu resta aperto")


func test_il_file_3_non_e_suo() -> void:
	var menu := _menu(_hero())
	menu.open()
	menu.choose(&"save")
	assert_eq(menu.save_view.list.get_node("slot3").text, menu.save_view.CURSED_TEXT, "già occupato")
	menu.save_view.slot_chosen.emit(3)
	assert_false(SaveStore.exists(3), "non si salva")
	assert_eq(menu.message_text(), "This file is already in use.", "messaggio")
	menu.back()
	menu.choose(&"load")
	menu.save_view.slot_chosen.emit(3)
	assert_eq(menu.message_text(), "...not yet.", "e non si carica")
	assert_true(menu.is_open(), "il menu resta aperto")


func test_una_scritta_guasta_torna_com_era() -> void:
	var menu := _menu()
	menu.open()
	await tree.process_frame
	var label: Label = menu.day_label
	var clean := label.text
	menu.glitcher.glitch(label, 0.05, 1.0)
	assert_true(label.text != clean and label.text.length() == clean.length(), "guasta")
	await wait_seconds(0.15)
	assert_eq(label.text, clean, "rimessa a posto")
	assert_false(menu.time_label in menu.glitcher.targets(), "il tempo non si guasta")


func test_lo_stato_legge_dead_per_un_attimo() -> void:
	var menu := _menu()
	menu.open()
	var card: HBoxContainer = menu.party.hero
	card.blink_dead(0.05)
	assert_eq(card.state_label.text, "Dead", "morta")
	assert_eq(card.hp.value, 0, "HP a zero")
	await wait_seconds(0.15)
	assert_eq(card.state_label.text, "Normal", "di nuovo normale")
	assert_eq(card.hp.value, card.hp.max_value, "HP pieni")


func test_game_end_rompe_lo_schermo_e_porta_al_titolo() -> void:
	Engine.time_scale = 4.0
	var menu := _menu()
	menu.open()
	menu.choose(&"end")
	menu.end_view.chosen.emit(&"title")
	await tree.process_frame
	assert_eq(menu.get_children().filter(func(n): return n is ScreenShatter).size(), 1, "lo schermo si rompe")
	menu.back()
	assert_true(menu.is_open(), "mentre si rompe, indietro non fa niente")
	assert_true(await wait_signal(menu.title_requested, 6.0), "title_requested emesso")


func test_usare_un_oggetto_non_si_puo() -> void:
	var menu := _menu()
	menu.open()
	menu.choose(&"items")
	var events := []
	menu.reactions.happened.connect(events.append)
	menu.items_view.list.chosen.emit(&"tray")
	assert_eq(events, [&"deny"], "il no")
	assert_eq(menu.help_text(), "You can't use that now.", "e il perché")
	menu.reactions.stop_chance = 1.0
	menu.reactions.deny()
	assert_true(menu.reactions.stop_label.visible, "a volte STOP. sopra tutto")
	await wait_seconds(0.4)
	assert_false(menu.reactions.stop_label.visible, "solo per un attimo")


func test_dopo_un_salvataggio_a_volte_succede_qualcosa() -> void:
	Engine.time_scale = 4.0
	var menu := _menu(_hero())
	menu.open()
	menu.choose(&"save")
	menu.save_view.slot_chosen.emit(1)
	var button: Button = menu.save_view.slot_button(1)
	var real := button.text
	assert_eq(menu.reactions.after_save(1, button), &"", "di solito niente")
	menu.reactions.after_save(1, button, &"stolen_file")
	await wait_seconds(0.8)   # tempo di gioco: lo scambio va da 0,5 a 1,2 s
	assert_eq(button.text, menu.reactions.STOLEN_TEXT % 1, "il file per un attimo è un altro")
	assert_true(await wait_signal(menu.reactions.happened, 2.0), "poi finisce")
	assert_eq(button.text, real, "e torna il suo")
	menu.reactions.after_save(1, button, &"watched")
	assert_true(await wait_signal(menu.reactions.happened, 2.0), "qualcuno ha visto")
	assert_eq(menu.message_text(), "She saw you save.", "e lo dice")


func test_i_suoni_di_sottofondo_non_si_ripetono_di_fila() -> void:
	var menu := _menu()
	var last := &""
	for i in 12:
		var kind: StringName = menu.ambience.play_random()
		assert_true(kind != last, "mai due uguali di fila")
		assert_true(kind in menu.ambience.SOUNDS, "un suono vero")
		last = kind


func test_salvare_mentre_una_voce_e_guasta_non_rompe_niente() -> void:
	# Il bug: una voce degli slot guasta per un attimo, si salva (la lista si rifà e la voce
	# vecchia viene liberata), poi il guasto prova a rimetterla a posto.
	var menu := _menu(_hero())
	menu.open()
	menu.choose(&"save")
	var slot: Button = menu.save_view.slot_button(1)
	menu.glitcher.glitch(slot, 0.05, 1.0)
	menu.save_view.slot_chosen.emit(1)
	await tree.process_frame
	await wait_seconds(0.1)
	assert_true(SaveStore.exists(1), "il salvataggio c'è")
	assert_true(menu.is_open(), "e il menu è ancora lì")
	menu.glitcher.restore(slot)          # anche chiamata a mano su un nodo liberato: niente


func test_le_bugie_sono_occhi() -> void:
	var menu := _menu(_hero())
	menu.state.lies = 3
	menu.open()
	menu.choose(&"status")
	var eyes: Control = menu.status_view.lie_eyes
	assert_true(eyes.is_visible_in_tree(), "nel menu Stato c'è il filo con gli occhi")
	assert_eq(eyes.open_eyes(), 3, "un occhio aperto per ogni bugia")
	assert_eq(eyes.slots(), eyes.MIN_SLOTS, "gli altri chiusi, che aspettano")
	assert_false(menu.status_view.lies_label.visible, "il numero non si vede")
	menu.state.lies = 40
	menu.back()
	menu.choose(&"status")
	assert_eq(eyes.open_eyes(), eyes.MAX_SLOTS, "con tante bugie il filo è tutto occhi aperti")


func test_durante_una_scena_il_menu_non_si_apre() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node2D\nvar sword_stage := 0\nvar frozen := false\nvar scripted := false\n"
	script.reload()
	var hero := Node2D.new()
	hero.set_script(script)
	tree.root.add_child(hero)
	_owned.append(hero)
	var menu := _menu(hero)
	hero.frozen = true                        # la caduta nello specchio, una cutscene...
	var esc := InputEventAction.new()
	esc.action = &"menu"
	esc.pressed = true
	menu._unhandled_input(esc)
	assert_false(menu.is_open(), "Esc durante una scena non apre il menu")
	assert_false(tree.paused, "e il gioco non si ferma sotto la scena")
	hero.frozen = false
	hero.scripted = true
	assert_false(menu.can_open(), "nemmeno quando la guida una cutscene")
	hero.scripted = false
	menu._unhandled_input(esc)
	assert_true(menu.is_open(), "finita la scena, sì")
