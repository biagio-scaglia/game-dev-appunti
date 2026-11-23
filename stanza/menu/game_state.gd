extends RefCounted
## Lo stato della partita che si salva: tempo di gioco, giorno, verità e bugie (il karma,
## per ora sempre a zero), equipaggiamento, l'incantesimo su Spazio / J, dove sta Lethe e
## lo stadio della spada. Solo dati.

const Data := preload("menu_data.gd")
const SAVE_VERSION := 1

var play_time := 0.0
## Il calendario è fermo al giorno cerchiato: è sempre il giorno 1.
var day := 1
var place := "Her Room"
var truth := 0
var lies := 0
## {slot: id dell'oggetto, "" = niente}
var equipped: Dictionary = Data.START_EQUIPMENT.duplicate()
var spell: String = Data.START_SPELL


## "01:02:05" da 3725 secondi.
static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d:%02d" % [s / 3600, s / 60 % 60, s % 60]


func to_save(position: Vector2, sword_stage: int) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"play_time": play_time,
		"day": day,
		"place": place,
		"truth": truth,
		"lies": lies,
		"equipped": equipped.duplicate(),
		"spell": spell,
		"position": [position.x, position.y],
		"sword_stage": sword_stage,
		"saved_at": int(Time.get_unix_time_from_system()),
	}


## Riprende i campi dello stato da un salvataggio (posizione e spada le applica chi chiama).
func load_save(data: Dictionary) -> void:
	play_time = float(data.get("play_time", 0.0))
	day = int(data.get("day", 1))
	place = String(data.get("place", place))
	truth = int(data.get("truth", 0))
	lies = int(data.get("lies", 0))
	equipped = Data.START_EQUIPMENT.duplicate()
	var saved: Dictionary = data.get("equipped", {})
	for slot in equipped:
		var id := String(saved.get(slot, equipped[slot]))
		if id == "" or Data.EQUIPMENT.has(id):
			equipped[slot] = id
	var saved_spell := String(data.get("spell", Data.START_SPELL))
	spell = saved_spell if Data.spell(saved_spell).get("learned", false) else Data.START_SPELL


static func saved_position(data: Dictionary) -> Vector2:
	var p: Array = data.get("position", [0, 0])
	return Vector2(float(p[0]), float(p[1]))
