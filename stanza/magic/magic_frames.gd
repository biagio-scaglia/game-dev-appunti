extends RefCounted
## Animazioni degli effetti magici dai loro sheet (6 fotogrammi in fila ciascuno).

const SHEETS := {
	&"charge": [preload("sprites/magia_carica.png"), Vector2(32, 32), false],
	&"projectile": [preload("sprites/magia_proiettile.png"), Vector2(32, 32), true],
	&"impact": [preload("sprites/magia_impatto.png"), Vector2(48, 48), false],
}
const FPS := 14.0


static func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in SHEETS:
		var sheet: Texture2D = SHEETS[anim][0]
		var cell: Vector2 = SHEETS[anim][1]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS)
		frames.set_animation_loop(anim, SHEETS[anim][2])
		for i in int(sheet.get_width() / cell.x):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(i * cell.x, 0), cell)
			frames.add_frame(anim, atlas)
	return frames
