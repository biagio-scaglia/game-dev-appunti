extends "res://tests/base_test.gd"
## Il taglio dei fogli di sprite.

const SheetFrames := preload("res://studio_intro/core/sheet_frames.gd")
const SHEET := preload("res://studio_intro/assets/sparkle.png")


func test_taglia_celle_in_fila() -> void:
	var frames := SpriteFrames.new()
	SheetFrames.add_strip(frames, &"anim", SHEET, Vector2(7, 7), 4, 12.0)
	assert_eq(frames.get_frame_count(&"anim"), 4, "numero di celle")
	var third: AtlasTexture = frames.get_frame_texture(&"anim", 2)
	assert_eq(third.region, Rect2(14, 0, 7, 7), "regione della terza cella")
	assert_eq(frames.get_animation_speed(&"anim"), 12.0, "velocità")
	assert_false(frames.get_animation_loop(&"anim"), "non in loop di default")


func test_riusa_un_animazione_esistente() -> void:
	var frames := SpriteFrames.new()
	SheetFrames.add_strip(frames, &"default", SHEET, Vector2(7, 7), 2)
	assert_eq(frames.get_frame_count(&"default"), 2, "celle aggiunte a 'default'")
