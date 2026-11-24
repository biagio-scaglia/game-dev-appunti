extends RefCounted
## Le icone degli oggetti (ui/items/item_icons.png, 32x32, dal generatore in locale) e i
## loro dati (item_icons.json): nome, tipo, descrizione, effetto.
##
## Tipi: "food" (cura: il cibo, qualcuno ti pensa), "light" (ricarica la luce della magia),
## "lethe" (l'acqua del Lete: cura tutto, ma si dimentica qualcosa), "upgrade" (più cuore,
## più luce, la spada che cresce), "collectible" (pagine della lettera, foglie, figure),
## "key", "accessory". Gli effetti sono dati per quando ci sarà la vita (vault: "Nemici e
## boss", "Cose da fare"); per ora nessuno li applica.

const ATLAS := preload("res://ui/items/item_icons.png")
const DATA_PATH := "res://ui/items/item_icons.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


static func has(id: String) -> bool:
	return data()["items"].has(id)


## I dati di un oggetto ({} se non c'è).
static func info(id: String) -> Dictionary:
	return data()["items"].get(id, {})


## L'icona di un oggetto (null se non c'è).
static func icon(id: String) -> AtlasTexture:
	var item := info(id)
	if item.is_empty():
		return null
	var cell := float(data()["cell"])
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = Rect2(Vector2(item["atlas"][0], item["atlas"][1]) * cell, Vector2(cell, cell))
	return texture


## Gli id di un tipo ("food", "upgrade"...).
static func of_kind(kind: String) -> Array:
	return data()["items"].keys().filter(func(id): return data()["items"][id]["kind"] == kind)
