extends "res://tests/base_test.gd"
## Il menu di pausa: apre e ferma il gioco, le pagine, la barra d'aiuto, equipaggiare,
## scegliere l'incantesimo, salvare e caricare, il File 3, le scritte che si guastano.

const MENU := "res://menu/pause_menu.tscn"
const SaveStore := preload("res://menu/save_store.gd")

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
	menu.glitcher.set_process(false)   # niente guasti a caso durante i test
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
	assert_eq(menu.keys_label.text, "Enter: choose    Esc: close", "tasti sulle voci")
	menu.commands.get_node("equip").grab_focus()
	assert_eq(menu.help_text(), "Change what Lethe holds and wears.", "l'aiuto segue il cuore")
	menu.choose(&"equip")
	assert_eq(menu.keys_label.text, "Enter: choose    Esc: back", "tasti in una pagina")


func test_equipaggiare_un_arma_cambia_i_parametri() -> void:
	var menu := _menu(_hero())
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


func test_scegliere_l_incantesimo_su_spazio() -> void:
	var menu := _menu()
	menu.open()
	menu.choose(&"spells")
	var spells: VBoxContainer = menu.spells_view
	assert_true(spells.ready_label.text.contains("Truth Spark"), "quello pronto")
	assert_true(spells.list.get_node("truth_spark").text.contains("(ready)"), "segnato nella lista")
	assert_true(spells.list.get_node("moonlight").text.begins_with("???"), "quelli non imparati")
	spells.list.chosen.emit(&"moonlight")
	assert_eq(menu.state.spell, "truth_spark", "uno non imparato non si sceglie")
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
	assert_false(menu.time_label in menu._glitch_targets(), "il tempo non si guasta")


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


func test_game_end_porta_al_titolo() -> void:
	var menu := _menu()
	menu.open()
	menu.choose(&"end")
	menu.end_view.chosen.emit(&"title")
	assert_true(await wait_signal(menu.title_requested, 3.0), "title_requested emesso")
	assert_near(menu.fade.color.a, 1.0, 0.001, "schermo nero")
