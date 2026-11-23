extends RefCounted
## L'equipaggiamento di Lethe: nomi, bonus, parametri totali e cosa va in ogni slot.
## La spada di vetro cambia nome e forza con lo stadio. Solo logica.

const Data := preload("menu_data.gd")


static func item_name(id: String, sword_stage: int) -> String:
	if id == "":
		return "(none)"
	if id == "glass_sword":
		return Data.WEAPONS[clampi(sword_stage, 0, Data.WEAPONS.size() - 1)]
	return Data.EQUIPMENT.get(id, {}).get("name", "?")


static func description(id: String) -> String:
	return "Nothing." if id == "" else Data.EQUIPMENT.get(id, {}).get("desc", "")


static func bonus(id: String, sword_stage: int) -> Dictionary:
	var b: Dictionary = Data.EQUIPMENT.get(id, {}).get("bonus", {}).duplicate()
	if id == "glass_sword":
		b["ATK"] = b.get("ATK", 0) + Data.SWORD_ATK_PER_STAGE * sword_stage
	return b


## I parametri con addosso `equipped` ({slot: id}).
static func params(equipped: Dictionary, sword_stage: int) -> Dictionary:
	var out: Dictionary = Data.BASE_PARAMS.duplicate()
	for slot in equipped:
		var b := bonus(String(equipped[slot]), sword_stage)
		for key in b:
			out[key] += b[key]
	return out


## Gli oggetti che vanno in uno slot.
static func items_for(slot: String) -> Array:
	return Data.EQUIPMENT.keys().filter(func(id): return Data.EQUIPMENT[id]["slot"] == slot)


## Il nome dello slot ("Weapon").
static func slot_name(slot: String) -> String:
	for s in Data.EQUIP_SLOTS:
		if s[0] == slot:
			return s[1]
	return slot
