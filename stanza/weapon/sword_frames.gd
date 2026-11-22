extends RefCounted
## Il fendente della spada di vetro dal suo sheet: 3 righe (stadi: scheggia, pugnale,
## lama) x 6 fotogrammi, celle 48x48. Animazioni "slash_0", "slash_1", "slash_2".

const SHEET := preload("sprites/spada_vetro.png")
const CELL := Vector2(48, 48)
const STAGES := 3
const FPS := 18.0
## Il perno (la mano) nel disegno è a sinistra del centro: con questo offset un
## AnimatedSprite2D centrato ruota intorno alla mano.
const PIVOT_OFFSET := Vector2(14, 0)


static func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var columns := int(SHEET.get_width() / CELL.x)
	for stage in STAGES:
		var anim := animation(stage)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS)
		frames.set_animation_loop(anim, false)
		for column in columns:
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = Rect2(Vector2(column, stage) * CELL, CELL)
			frames.add_frame(anim, atlas)
	return frames


static func animation(stage: int) -> StringName:
	return StringName("slash_%d" % clampi(stage, 0, STAGES - 1))


## Secondi di un fendente.
static func duration() -> float:
	return int(SHEET.get_width() / CELL.x) / FPS
