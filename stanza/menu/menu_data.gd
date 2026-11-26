extends RefCounted
## I testi del menu di pausa: voci, oggetti, equipaggiamento, incantesimi e statistiche.
## Solo dati. Gli oggetti sono quelli della stanza (vedi il vault, "La stanza di Lethe"):
## ognuno ha una descrizione, e una seconda che compare quando lo si guarda di nuovo.

## [id, testo, aiuto in fondo al menu]
const COMMANDS := [
	[&"items", "Items", "Things you found in the room."],
	[&"spells", "Spells", "Your spells. Choose the one you cast with Q."],
	[&"equip", "Equip", "Change what Lethe holds and wears."],
	[&"status", "Status", "Lethe's stats, equipment and spell."],
	[&"save", "Save", "Save your progress to a file."],
	[&"load", "Load", "Continue from a saved file."],
	[&"end", "Game End", "Return to the title screen."],
]

const END_CHOICES := [[&"title", "To Title"], [&"cancel", "Cancel"]]

## I tasti, in fondo al menu: sulle voci e dentro una pagina.
const KEYS_MAIN := "Space: choose    Esc: close"
const KEYS_PAGE := "Space: choose    Esc: back"
const KEYS_VIEW := "Esc: back"

## count -1: tante quante le schegge della spada (lo stadio + 1).
const ITEMS := [
	{"id": &"tray", "name": "Untouched Tray", "count": 1,
		"desc": "Rice gone cold. A note with a small heart: \"I'll leave it here.\"",
		"again": "Someone still knocks. You still don't answer."},
	{"id": &"photo", "name": "Face-down Photo", "count": 1,
		"desc": "You know who is in it. You don't turn it over.",
		"again": "It was face up a moment ago."},
	{"id": &"letter", "name": "Crumpled Letter", "count": 7,
		"desc": "Seven tries. Every one of them starts with \"I'm sorry\".",
		"again": "Eight now. You don't remember writing the last one."},
	{"id": &"shard", "name": "Mirror Shard", "count": -1,
		"desc": "Glass from the covered mirror. Every lie cuts a new piece.",
		"again": "In the glass, someone is standing behind you."},
	{"id": &"phone", "name": "Phone", "count": 1,
		"desc": "37 unread messages.",
		"again": "38."},
	{"id": &"calendar", "name": "Calendar Page", "count": 1,
		"desc": "Days crossed out, up to the circled one. Then nothing.",
		"again": "Today is circled too."},
]

const NAME := "Lethe"
const CLASS := "Hikikomori"
const LEVEL := 1
const HP := 34
const MP := 12

const PARAM_ORDER := ["ATK", "DEF", "M.ATK", "M.DEF", "AGI", "LUK"]
## I parametri senza equipaggiamento.
const BASE_PARAMS := {"ATK": 2, "DEF": 1, "M.ATK": 11, "M.DEF": 7, "AGI": 6, "LUK": 0}

## [id, nome dello slot]
const EQUIP_SLOTS := [["weapon", "Weapon"], ["body", "Body"], ["accessory", "Accessory"]]
## La spada di vetro cambia nome con lo stadio (scheggia, pugnale, lama) e ogni stadio
## dà +2 ATK in più.
const WEAPONS := ["Mirror Shard", "Glass Dagger", "Glass Blade"]
const SWORD_ATK_PER_STAGE := 2
## Quello che Lethe ha con sé. Gli id sono String: tornano così dai salvataggi in JSON.
const EQUIPMENT := {
	"glass_sword": {"slot": "weapon", "bonus": {"ATK": 2},
		"desc": "Made from the covered mirror. It grows with every lie."},
	"toy_wand": {"slot": "weapon", "name": "Toy Wand", "bonus": {"M.ATK": 3},
		"desc": "From the magical girl on the poster. It still lights up."},
	"black_dress": {"slot": "body", "name": "Black Dress", "bonus": {"DEF": 2, "M.DEF": 2},
		"desc": "Black and violet. You chose it for a day that never came."},
	"hoodie": {"slot": "body", "name": "Oversized Hoodie", "bonus": {"DEF": 1, "AGI": 2},
		"desc": "Not yours. It still smells like someone."},
	"bracelet": {"slot": "accessory", "name": "Hospital Bracelet", "bonus": {"M.DEF": 2, "LUK": 1},
		"desc": "Your name is printed on it. Spelled wrong."},
}
## All'inizio Lethe ha solo il vestito: niente spada (arriva con la scheggia dello specchio),
## niente accessori. Il resto si trova nel gioco (vault: "Trama - bozza").
const START_EQUIPMENT := {"weapon": "", "body": "black_dress", "accessory": ""}
## Quello che ha sempre, anche in un salvataggio vecchio o rotto.
const BASE_OWNED := ["black_dress"]

## Gli incantesimi. All'inizio non ne sa nessuno: si vedono tutti come "???". Il primo,
## Truth Spark, arriva con la prima verità detta nella foresta; Vigil (le quattro fiammelle)
## accendendo con la propria luce le lanterne di radice del dungeon.
const SPELLS := [
	{"id": "truth_spark", "name": "Truth Spark", "mp": 0,
		"desc": "Gather light in your hands and throw it. It lights up the dark."},
	{"id": "vigil", "name": "Vigil", "mp": 2,
		"desc": "Four small flames keep watch around you. Then they go where the dark is."},
	{"id": "moonlight", "name": "Moonlight", "mp": 4,
		"desc": "Open your hands to the moon. Everything nearby remembers the light."},
	{"id": "mend", "name": "Mend", "mp": 3,
		"desc": "Hold your own heart a little less tight."},
]
## Nessun incantesimo su Q all'inizio.
const START_SPELL := ""
## Come si vede quello che Lethe non ha ancora.
const UNKNOWN := "???"
const NOTHING := "(none)"

## In fondo alla pagina del gruppo, appena leggibile: una a caso ogni volta (anche nessuna).
const WHISPERS := [
	"You were here before.",
	"Day 1. Again.",
	"Someone is still waiting outside the door.",
	"Don't turn around.",
	"The mirror is not covered anymore.",
	"",
]


static func item_count(item: Dictionary, sword_stage: int) -> int:
	return sword_stage + 1 if item["count"] < 0 else item["count"]


static func spell(id: String) -> Dictionary:
	for s in SPELLS:
		if s["id"] == id:
			return s
	return {}
