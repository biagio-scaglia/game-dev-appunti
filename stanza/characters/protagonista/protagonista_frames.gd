extends RefCounted
## Animazioni della protagonista dai suoi 5 sheet (celle 64x64, 5 righe = 5 direzioni).
## Gli sheet stanno in sprites/ e si caricano a runtime, così
## il progetto si apre anche senza (con un errore chiaro invece di uno di parsing).

const Facing := preload("facing.gd")
const SPRITES := "res://characters/protagonista/sprites/protagonista_%s.png"
const CELL := Vector2(64, 64)
## Bordo inferiore dei piedi nella cella.
const FEET_Y := 64.0
const KINDS := ["idle", "walk", "run", "attack", "slash"]   # slash: la spada (scia di vetro)
const FPS := {"idle": 6.0, "walk": 8.0, "run": 12.0, "attack": 14.0, "slash": 14.0}


static func sprites_available() -> bool:
	return KINDS.all(func(k): return ResourceLoader.exists(SPRITES % k))


static func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	if not sprites_available():
		push_error("Sprite della protagonista mancanti in characters/protagonista/sprites/ .")
		return frames
	for kind: String in KINDS:
		var sheet: Texture2D = load(SPRITES % kind)
		var columns := int(sheet.get_width() / CELL.x)
		for row in Facing.ROWS.size():
			var anim := StringName("%s_%s" % [kind, Facing.ROWS[row]])
			frames.add_animation(anim)
			frames.set_animation_speed(anim, FPS[kind])
			frames.set_animation_loop(anim, kind not in ["attack", "slash"])
			for column in columns:
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(Vector2(column, row) * CELL, CELL)
				frames.add_frame(anim, atlas)
	return frames


## Offset di un AnimatedSprite2D centrato perché l'origine del nodo cada sui piedi.
static func feet_offset() -> Vector2:
	return Vector2(0, CELL.y / 2.0 - FEET_Y)
