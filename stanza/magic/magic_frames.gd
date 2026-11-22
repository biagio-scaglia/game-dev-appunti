extends RefCounted
## Animazioni degli effetti magici dai loro sheet (fotogrammi in fila: carica 8,
## proiettile 4, impatto 9). Ognuna col suo ritmo: la carica è rapida (finisce quando
## parte il colpo), l'impatto lascia il tempo alla dissolvenza.

## [sheet, cella, loop, fotogrammi al secondo]
const SHEETS := {
	&"charge": [preload("sprites/magia_carica.png"), Vector2(32, 32), false, 30.0],
	&"projectile": [preload("sprites/magia_proiettile.png"), Vector2(32, 32), true, 12.0],
	&"impact": [preload("sprites/magia_impatto.png"), Vector2(48, 48), false, 16.0],
}


static func build() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in SHEETS:
		var sheet: Texture2D = SHEETS[anim][0]
		var cell: Vector2 = SHEETS[anim][1]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, SHEETS[anim][3])
		frames.set_animation_loop(anim, SHEETS[anim][2])
		for i in int(sheet.get_width() / cell.x):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(i * cell.x, 0), cell)
			frames.add_frame(anim, atlas)
	return frames


## Secondi di un'animazione (una passata).
static func duration(anim: StringName) -> float:
	var sheet: Texture2D = SHEETS[anim][0]
	return int(sheet.get_width() / SHEETS[anim][1].x) / SHEETS[anim][3]
