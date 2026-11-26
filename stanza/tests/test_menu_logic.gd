extends "res://tests/base_test.gd"
## Le parti del menu senza nodi: tempo di gioco, salvataggi su file, testo guasto, dati.

const GameState := preload("res://menu/game_state.gd")
const SaveStore := preload("res://menu/save_store.gd")
const Glitch := preload("res://menu/glitch.gd")
const Data := preload("res://menu/menu_data.gd")
const Equipment := preload("res://menu/equipment.gd")

var _real_dir := ""


func before() -> void:
	_real_dir = SaveStore.dir
	SaveStore.dir = "user://test_saves"
	for slot in range(1, SaveStore.SLOTS + 1):
		SaveStore.erase(slot)


func after() -> void:
	for slot in range(1, SaveStore.SLOTS + 1):
		SaveStore.erase(slot)
	SaveStore.dir = _real_dir
	await super()


func test_il_tempo_si_legge_in_ore_minuti_secondi() -> void:
	assert_eq(GameState.format_time(0.0), "00:00:00", "zero")
	assert_eq(GameState.format_time(3725.9), "01:02:05", "un'ora e qualcosa")


func test_salvare_e_rileggere_uno_slot() -> void:
	var state := GameState.new()
	state.play_time = 90.0
	state.lies = 2
	assert_false(SaveStore.exists(1), "slot vuoto all'inizio")
	assert_eq(SaveStore.read(1), {}, "slot vuoto: nessun dato")
	assert_true(SaveStore.write(1, state.to_save(Vector2(40, 72), 1)), "scritto")
	var data := SaveStore.read(1)
	var loaded := GameState.new()
	loaded.load_save(data)
	assert_near(loaded.play_time, 90.0, 0.001, "tempo di gioco")
	assert_eq(loaded.lies, 2, "bugie")
	assert_eq(GameState.saved_position(data), Vector2(40, 72), "posizione")
	assert_eq(int(data["sword_stage"]), 1, "stadio della spada")


func test_un_file_rotto_vale_come_vuoto() -> void:
	DirAccess.make_dir_recursive_absolute(SaveStore.dir)
	var f := FileAccess.open(SaveStore.path(2), FileAccess.WRITE)
	f.store_string("non è json")
	f.close()
	assert_eq(SaveStore.read(2), {}, "file rotto")


func test_riscrivere_uno_slot_non_lascia_file_a_meta() -> void:
	assert_true(SaveStore.write(1, {"lies": 1}), "il primo")
	assert_true(SaveStore.write(1, {"lies": 2}), "sopra il vecchio")
	assert_eq(int(SaveStore.read(1)["lies"]), 2, "c'è il nuovo")
	assert_false(FileAccess.file_exists(SaveStore.path(1) + ".tmp"), "e niente file temporaneo in giro")


func test_un_salvataggio_ritoccato_a_mano_non_rompe_niente() -> void:
	# JSON valido, ma coi campi del tipo sbagliato: si scartano, non si va in crash.
	var data := {"learned": "truth_spark", "owned": 3, "equipped": [], "flags": "x",
		"heart_max": 99, "heart": 99, "position": [12]}
	var state := GameState.new()
	state.load_save(data)
	assert_eq(state.learned.size(), 0, "incantesimi: non una lista, niente")
	assert_eq(state.owned, ["black_dress"] as Array[String], "oggetti: solo il vestito")
	assert_eq(state.equipped["body"], "black_dress", "addosso: quello di partenza")
	assert_eq(state.flags, {}, "segni: vuoti")
	assert_eq(state.heart_max, GameState.HEART_CAP, "il cuore non va oltre il massimo")
	assert_eq(state.heart, GameState.HEART_CAP, "e nemmeno quello che resta")
	assert_eq(GameState.saved_position(data), Vector2.ZERO, "posizione monca: zero")
	assert_eq(GameState.saved_position({"position": "qui"}), Vector2.ZERO, "posizione non lista: zero")



func test_il_testo_guasto_tiene_spazi_e_lunghezza() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var text := "Save to which file?"
	assert_eq(Glitch.corrupt(text, 0.0, rng), text, "niente guasto")
	var all := Glitch.corrupt(text, 1.0, rng)
	assert_eq(all.length(), text.length(), "stessa lunghezza")
	for i in text.length():
		if text[i] == " ":
			assert_eq(all[i], " ", "gli spazi restano")
		else:
			assert_true(all[i] in Glitch.GLYPHS, "ogni lettera diventa un segno")


func test_le_schegge_contano_lo_stadio_della_spada() -> void:
	var shard: Dictionary = Data.ITEMS.filter(func(i): return i["id"] == &"shard")[0]
	assert_eq(Data.item_count(shard, 0), 1, "una scheggia")
	assert_eq(Data.item_count(shard, 2), 3, "tre con la lama")
	assert_eq(Data.item_count(Data.ITEMS[0], 2), Data.ITEMS[0]["count"], "gli altri non cambiano")


func test_i_parametri_sommano_l_equipaggiamento() -> void:
	var p := Equipment.params(Data.START_EQUIPMENT, 0)
	assert_eq(p["ATK"], 2, "all'inizio niente spada: solo la base")
	assert_eq(p["DEF"], 3, "base 1 + vestito 2")
	var armed := {"weapon": "glass_sword", "body": "black_dress", "accessory": ""}
	assert_eq(Equipment.params(armed, 0)["ATK"], 4, "base 2 + spada 2")
	assert_eq(Equipment.params(armed, 2)["ATK"], 8, "la lama: +4 in più")
	assert_eq(Equipment.params({"weapon": "", "body": "", "accessory": ""}, 0), Data.BASE_PARAMS, "senza niente")


func test_la_spada_cambia_nome_con_lo_stadio() -> void:
	assert_eq(Equipment.item_name("glass_sword", 0), "Mirror Shard", "scheggia")
	assert_eq(Equipment.item_name("glass_sword", 2), "Glass Blade", "lama")
	assert_eq(Equipment.item_name("", 0), "(none)", "niente")
	assert_eq(Equipment.items_for("body"), ["black_dress", "hoodie"], "cosa va sul corpo")


func test_equipaggiamento_e_incantesimo_si_salvano() -> void:
	var state := GameState.new()
	state.give("glass_sword")
	state.give("bracelet")
	state.learn("truth_spark")
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save(Vector2.ZERO, 0)))
	var loaded := GameState.new()
	loaded.load_save(data)
	assert_eq(loaded.equipped["accessory"], "bracelet", "accessorio")
	assert_eq(loaded.equipped["weapon"], "glass_sword", "arma")
	assert_eq(loaded.spell, "truth_spark", "incantesimo")
	assert_true(loaded.knows("truth_spark") and loaded.owns("glass_sword"), "cosa sa e cosa ha")
	data["spell"] = "moonlight"           # non imparato: niente su Spazio / J
	data["equipped"]["body"] = "hoodie"   # mai trovata: torna il vestito
	data["learned"].append("fireball")    # non esiste
	loaded.load_save(data)
	assert_eq(loaded.spell, "", "un incantesimo non imparato non si carica")
	assert_eq(loaded.equipped["body"], "black_dress", "un oggetto mai trovato non si mette")
	assert_eq(loaded.learned, ["truth_spark"] as Array[String], "quelli che non esistono si scartano")


func test_all_inizio_lethe_non_ha_niente() -> void:
	var state := GameState.new()
	assert_eq(state.learned.size(), 0, "nessun incantesimo")
	assert_eq(state.spell, "", "niente su Spazio / J")
	assert_false(state.can_cast(), "niente magia")
	assert_false(state.can_slash(), "niente spada")
	assert_eq(state.owned, ["black_dress"] as Array[String], "solo il vestito")
	assert_eq(state.equipped, {"weapon": "", "body": "black_dress", "accessory": ""}, "addosso")
	var old := GameState.new()
	old.load_save({"version": 1, "spell": "truth_spark", "equipped": {"weapon": "glass_sword"}})
	assert_false(old.can_cast() or old.can_slash(), "un salvataggio vecchio non regala niente")


func test_imparare_e_trovare() -> void:
	var state := GameState.new()
	state.learn("truth_spark")
	assert_eq(state.spell, "truth_spark", "il primo incantesimo va su Spazio / J")
	assert_true(state.can_cast(), "ora la magia c'è")
	state.learn("mend")
	assert_eq(state.spell, "truth_spark", "il secondo non lo sostituisce")
	state.learn("mend")
	state.learn("nope")
	assert_eq(state.learned.size(), 2, "niente doppioni, niente inventati")
	state.give("glass_sword")
	assert_true(state.can_slash(), "la spada va subito in mano")
	state.give("toy_wand")
	assert_eq(state.equipped["weapon"], "glass_sword", "con le mani piene, la bacchetta resta da parte")
	assert_true(state.owns("toy_wand"), "ma ce l'ha")
