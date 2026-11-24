extends "res://tests/base_test.gd"
## Le icone degli oggetti: ogni oggetto ha la sua icona nell'atlante, con nome e
## descrizione, e ci sono tutti i tipi che servono al gioco.

const ItemIcons := preload("res://ui/item_icons.gd")


func test_ogni_oggetto_ha_la_sua_icona() -> void:
	var items: Dictionary = ItemIcons.data()["items"]
	assert_true(items.size() >= 20, "abbastanza oggetti: %d" % items.size())
	var seen := {}
	for id in items:
		var texture := ItemIcons.icon(id)
		assert_true(texture != null, "%s ha l'icona" % id)
		assert_true(Rect2(Vector2.ZERO, ItemIcons.ATLAS.get_size()).encloses(texture.region), "%s nell'atlante" % id)
		assert_false(seen.has(texture.region), "%s non è sopra un'altra icona" % id)
		seen[texture.region] = id
		var image := ItemIcons.ATLAS.get_image().get_region(Rect2i(texture.region))
		assert_false(image.is_invisible(), "%s è disegnata" % id)
		assert_true(String(items[id]["name"]) != "" and String(items[id]["desc"]) != "", "%s ha nome e descrizione" % id)


func test_ci_sono_i_tipi_del_gioco() -> void:
	for kind in ["food", "light", "lethe", "upgrade", "collectible", "key", "accessory"]:
		assert_true(ItemIcons.of_kind(kind).size() > 0, "c'è almeno un %s" % kind)
	assert_eq(int(ItemIcons.info("lethe_water")["effect"]["forget"]), 1, "l'acqua del Lete fa dimenticare")
	assert_eq(ItemIcons.icon("nope"), null, "un oggetto che non c'è: niente icona")
