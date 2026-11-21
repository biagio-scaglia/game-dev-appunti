extends "res://tests/base_test.gd"
## Dalla direzione del movimento a riga dello sheet, specchio e nome dell'animazione.

const Facing := preload("res://characters/protagonista/facing.gd")


func test_otto_direzioni() -> void:
	assert_eq(Facing.dir8(Vector2(1, 0.1), Vector2.DOWN), Vector2.RIGHT, "quasi destra")
	assert_eq(Facing.dir8(Vector2(0.7, 0.7), Vector2.DOWN), Vector2(1, 1), "diagonale giù-destra")
	assert_eq(Facing.dir8(Vector2(-0.1, -1), Vector2.DOWN), Vector2.UP, "quasi su")
	assert_eq(Facing.dir8(Vector2(-1, -1), Vector2.DOWN), Vector2(-1, -1), "diagonale su-sinistra")


func test_da_ferma_tiene_la_direzione() -> void:
	assert_eq(Facing.dir8(Vector2.ZERO, Vector2.LEFT), Vector2.LEFT, "ferma")


func test_righe_dello_sheet() -> void:
	assert_eq(Facing.row_of(Vector2.DOWN), 0, "giù")
	assert_eq(Facing.row_of(Vector2(1, 1)), 1, "giù-lato")
	assert_eq(Facing.row_of(Vector2(-1, 0)), 2, "lato")
	assert_eq(Facing.row_of(Vector2(1, -1)), 3, "su-lato")
	assert_eq(Facing.row_of(Vector2.UP), 4, "su")


func test_a_sinistra_si_specchia() -> void:
	assert_true(Facing.flipped(Vector2(-1, 1)), "giù-sinistra")
	assert_false(Facing.flipped(Vector2(1, 0)), "destra")
	assert_false(Facing.flipped(Vector2.UP), "su")


func test_nomi_delle_animazioni() -> void:
	assert_eq(Facing.animation("walk", Vector2.LEFT), &"walk_side", "cammina di lato")
	assert_eq(Facing.animation("attack", Vector2(-1, -1)), &"attack_up_side", "attacca su-lato")
