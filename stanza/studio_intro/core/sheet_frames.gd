extends RefCounted
## Costruisce animazioni (SpriteFrames) da un foglio di sprite a celle in fila.
## Lo usano il logo e le scintille: un solo posto dove si "taglia" un foglio.


## Aggiunge ad `frames` l'animazione `anim`, con `count` celle grandi `cell`
## prese da sinistra a destra nel foglio `sheet`.
static func add_strip(frames: SpriteFrames, anim: StringName, sheet: Texture2D,
		cell: Vector2, count: int, fps := 5.0, loop := false) -> void:
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(Vector2(i * cell.x, 0), cell)
		frames.add_frame(anim, atlas)
