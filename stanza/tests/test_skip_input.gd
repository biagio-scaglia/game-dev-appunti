extends "res://tests/base_test.gd"
## Quali input saltano l'intro.

const SkipInput := preload("res://studio_intro/core/skip_input.gd")


func _key(keycode: Key, pressed := true, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.pressed = pressed
	e.echo = echo
	return e


func _click(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	return e


func test_un_tasto_normale_salta() -> void:
	assert_true(SkipInput.is_skip(_key(KEY_A)), "A premuto")
	assert_true(SkipInput.is_skip(_key(KEY_ENTER)), "Invio premuto")


func test_tasto_rilasciato_o_ripetuto_non_salta() -> void:
	assert_false(SkipInput.is_skip(_key(KEY_A, false)), "A rilasciato")
	assert_false(SkipInput.is_skip(_key(KEY_A, true, true)), "A ripetuto (echo)")


func test_volume_e_modificatori_non_saltano() -> void:
	for k: Key in [KEY_VOLUMEUP, KEY_VOLUMEMUTE, KEY_SHIFT, KEY_ALT]:
		assert_false(SkipInput.is_skip(_key(k)), "tasto %s" % OS.get_keycode_string(k))


func test_clic_salta_ma_rotella_no() -> void:
	assert_true(SkipInput.is_skip(_click(MOUSE_BUTTON_LEFT)), "clic sinistro")
	assert_false(SkipInput.is_skip(_click(MOUSE_BUTTON_WHEEL_UP)), "rotella")


func test_pulsante_joypad_salta() -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	assert_true(SkipInput.is_skip(e), "pulsante A")


func test_movimento_del_mouse_non_salta() -> void:
	assert_false(SkipInput.is_skip(InputEventMouseMotion.new()), "mouse che si muove")
