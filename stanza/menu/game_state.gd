extends RefCounted
## Lo stato della partita che si salva: tempo di gioco, giorno, verità e bugie (il karma),
## cosa sa e cosa ha Lethe (incantesimi imparati, equipaggiamento trovato), cosa ha addosso,
## l'incantesimo su Q, dove sta e lo stadio della spada. Solo dati.
##
## All'inizio Lethe non sa nessun incantesimo e ha solo il vestito: niente magia, niente
## spada (vault: "Trama - bozza", il prologo). Le cose arrivano con learn() e give().

const Data := preload("menu_data.gd")
const SAVE_VERSION := 2

var play_time := 0.0
## Il calendario è fermo al giorno cerchiato: è sempre il giorno 1.
var day := 1
var place := "Her Room"
var truth := 0
var lies := 0
## Gli incantesimi imparati (id).
var learned: Array[String] = []
## L'equipaggiamento trovato (id).
var owned: Array[String] = []
## {slot: id dell'oggetto, "" = niente}
var equipped: Dictionary = Data.START_EQUIPMENT.duplicate()
## L'incantesimo su Q ("" = nessuno).
var spell: String = Data.START_SPELL
## I segni di quello che è già successo nella storia (es. "knock_over", "mirror_calling"),
## e le cose guardate nella stanza ("looked": lista di id). Solo valori da JSON.
var flags: Dictionary = {}
## La vita è un cuore (vault: "Nemici e boss"): quante strette regge, e quante ne mancano.
## Ogni colpo la mano stringe un po' di più; a zero il cuore è stretto del tutto.
var heart_max := 4
var heart := 4
## L'esperienza: i nemici sciolti lasciano luce che Lethe raccoglie. Ogni livello costa più
## del precedente (exp_to_next) e i premi si alternano: ai livelli pari il cuore regge una
## stretta in più (fino a HEART_CAP), ai dispari la spada taglia di più (attack_bonus). A ogni
## livello il cuore torna intero.
var level := 1
var xp := 0
const HEART_CAP := 8


func _init() -> void:
	owned.assign(Data.BASE_OWNED)


## "01:02:05" da 3725 secondi.
static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d:%02d" % [s / 3600, s / 60 % 60, s % 60]


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func set_flag(key: String, value := true) -> void:
	flags[key] = value


## Segna una cosa della stanza come guardata. Quante cose diverse ha guardato.
func look(thing_id: String) -> int:
	var looked: Array = flags.get("looked", [])
	if not thing_id in looked:
		looked.append(thing_id)
	flags["looked"] = looked
	return looked.size()


func looked_count() -> int:
	return (flags.get("looked", []) as Array).size()


## Un colpo: il cuore perde `amount`. Ritorna quanto ne resta.
func hurt(amount: int) -> int:
	heart = maxi(0, heart - amount)
	return heart


func heal(amount: int) -> void:
	heart = mini(heart_max, heart + amount)


## Quanta esperienza serve per passare dal livello `lv` al successivo: cresce più che
## lineare (10, 28, 52, 80, 112...).
static func exp_to_next(lv: int) -> int:
	return roundi(10.0 * pow(lv, 1.5))


## Lo stadio della spada di vetro (0 scheggia, 1 pugnale, 2 lama): ogni bugia stacca una
## scheggia dallo specchio (vault: "La spada di vetro"). Da SWORD_LIES[0] bugie è un pugnale,
## da SWORD_LIES[1] una lama.
const SWORD_LIES := [2, 5]


static func sword_stage_for(lie_count: int) -> int:
	var stage := 0
	for need in SWORD_LIES:
		if lie_count >= need:
			stage += 1
	return stage


func sword_stage() -> int:
	return sword_stage_for(lies)


## Quanto taglia in più la spada per il livello (uno ogni due livelli, dal 3).
func attack_bonus() -> int:
	return (level - 1) / 2


## L'esperienza davvero presa da un nemico di livello `enemy_level`: piena se è alla pari o
## più forte, sempre meno se Lethe è molto più in alto (non conviene morire e rifarli).
func exp_from(amount: int, enemy_level: int) -> int:
	var gap := level - enemy_level
	if gap <= 1:
		return amount
	return maxi(1, roundi(amount * pow(0.5, gap - 1)))


## Prende esperienza; ritorna quanti livelli ha guadagnato.
func gain_exp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= exp_to_next(level):
		xp -= exp_to_next(level)
		level += 1
		gained += 1
		if level % 2 == 0:
			heart_max = mini(HEART_CAP, heart_max + 1)
		heart = heart_max
	return gained


## Quante volte il cuore si è spezzato (per un segreto).
func deaths() -> int:
	return int(flags.get("deaths", 0))


func add_death() -> int:
	flags["deaths"] = deaths() + 1
	return deaths()


func is_dead() -> bool:
	return heart <= 0


## Quanto stringe la mano (0 = niente, heart_max = del tutto).
func squeeze() -> int:
	return heart_max - heart


func knows(spell_id: String) -> bool:
	return spell_id in learned


func owns(item_id: String) -> bool:
	return item_id in owned


## Può usare la magia: ha un incantesimo su Q.
func can_cast() -> bool:
	return spell != "" and knows(spell)


## Può usare la spada: ha la spada di vetro in mano.
func can_slash() -> bool:
	return equipped.get("weapon", "") == "glass_sword"


## Impara un incantesimo. Se non ne aveva nessuno pronto, va su Q.
func learn(spell_id: String) -> void:
	if Data.spell(spell_id).is_empty() or knows(spell_id):
		return
	learned.append(spell_id)
	if spell == "":
		spell = spell_id


## Trova un oggetto da equipaggiare. Se il suo slot è vuoto, lo mette subito addosso.
func give(item_id: String) -> void:
	if not Data.EQUIPMENT.has(item_id) or owns(item_id):
		return
	owned.append(item_id)
	var slot: String = Data.EQUIPMENT[item_id]["slot"]
	if equipped.get(slot, "") == "":
		equipped[slot] = item_id


func to_save(position: Vector2, sword_stage: int) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"play_time": play_time,
		"day": day,
		"place": place,
		"truth": truth,
		"lies": lies,
		"learned": learned.duplicate(),
		"owned": owned.duplicate(),
		"equipped": equipped.duplicate(),
		"spell": spell,
		"flags": flags.duplicate(true),
		"heart": heart,
		"heart_max": heart_max,
		"level": level,
		"xp": xp,
		"position": [position.x, position.y],
		"sword_stage": sword_stage,
		"saved_at": int(Time.get_unix_time_from_system()),
	}


## Riprende i campi dello stato da un salvataggio (posizione e spada le applica chi chiama).
## Quello che non torna (un incantesimo che non esiste, un oggetto mai trovato) si scarta.
func load_save(data: Dictionary) -> void:
	play_time = float(data.get("play_time", 0.0))
	day = int(data.get("day", 1))
	place = String(data.get("place", place))
	truth = int(data.get("truth", 0))
	lies = int(data.get("lies", 0))
	learned.clear()
	for id in data.get("learned", []):
		if not Data.spell(String(id)).is_empty() and not knows(String(id)):
			learned.append(String(id))
	owned.assign(Data.BASE_OWNED)
	for id in data.get("owned", []):
		if Data.EQUIPMENT.has(String(id)) and not owns(String(id)):
			owned.append(String(id))
	equipped = Data.START_EQUIPMENT.duplicate()
	var saved: Dictionary = data.get("equipped", {})
	for slot in equipped:
		var id := String(saved.get(slot, equipped[slot]))
		if id == "" or (owns(id) and Data.EQUIPMENT[id]["slot"] == slot):
			equipped[slot] = id
	level = maxi(1, int(data.get("level", 1)))
	xp = maxi(0, int(data.get("xp", 0)))
	heart_max = maxi(1, int(data.get("heart_max", 4)))
	heart = clampi(int(data.get("heart", heart_max)), 1, heart_max)
	var saved_flags = data.get("flags", {})
	flags = saved_flags.duplicate(true) if saved_flags is Dictionary else {}
	var saved_spell := String(data.get("spell", Data.START_SPELL))
	spell = saved_spell if knows(saved_spell) else Data.START_SPELL


static func saved_position(data: Dictionary) -> Vector2:
	var p: Array = data.get("position", [0, 0])
	return Vector2(float(p[0]), float(p[1]))
