extends "res://tests/base_test.gd"
## La stanza: muri, mobili, pavimento libero, luci.

const Layout := preload("res://world/room_layout.gd")
const ROOM := preload("res://world/room.gd")


func _room() -> Node2D:
	var room := Node2D.new()
	room.set_script(ROOM)
	tree.root.add_child(room)
	_owned.append(room)
	return room


func test_muri_tutto_intorno() -> void:
	var room := _room()
	assert_true(room.is_solid(Vector2i(5, 0)), "muro in alto")
	assert_true(room.is_solid(Vector2i(5, 1)), "muro in alto, seconda riga")
	assert_true(room.is_solid(Vector2i(0, 5)), "muro a sinistra")
	assert_true(room.is_solid(Vector2i(Layout.SIZE.x - 1, 5)), "muro a destra")
	assert_true(room.is_solid(Vector2i(5, Layout.SIZE.y - 1)), "muro in basso")


func test_mobili_solidi_e_oggetti_per_terra_no() -> void:
	var room := _room()
	assert_true(room.is_solid(Vector2i(2, 7)), "il letto blocca")
	assert_true(room.is_solid(Vector2i(12, 3)), "la scrivania blocca")
	assert_false(room.is_solid(Vector2i(8, 5)), "sul tappeto si cammina")
	assert_false(room.is_solid(Vector2i(4, 8)), "sui vestiti per terra si cammina")
	assert_true(room.is_solid(Vector2i(5, 3)), "lo specchio coperto blocca")
	assert_false(room.is_solid(Vector2i(17, 2)), "sul vassoio davanti alla porta si passa")


func test_la_protagonista_parte_in_un_punto_libero() -> void:
	var room := _room()
	assert_true(Layout.FLOOR.has_point(Layout.PLAYER_START), "dentro il pavimento")
	assert_false(room.is_solid(Layout.PLAYER_START), "cella libera")
	assert_eq(room.player_start(), Vector2(Layout.PLAYER_START) * 32 + Vector2(16, 16), "centro della cella")


func test_si_accendono_le_luci_dei_mobili() -> void:
	var room := _room()
	assert_eq(room.lights.size(), 4, "schermo, telefono sul letto, lampada, luna")
	for l in room.lights:
		assert_true(l.energy > 0.0, "luce accesa")


func test_i_mobili_si_ordinano_per_y() -> void:
	var room := _room()
	assert_true(room.object_layer.y_sort_enabled, "livello dei mobili ordinato per Y")
