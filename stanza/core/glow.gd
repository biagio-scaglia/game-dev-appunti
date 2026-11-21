extends RefCounted
## Luci morbide: una PointLight2D con una texture a gradiente radiale. La usano la
## magia (luce viola che illumina la stanza) e i mobili accesi (schermo, lampada).

const TEXTURE_SIZE := 128

static var _texture: GradientTexture2D


static func light(color: Color, energy: float, radius: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _soft_texture()
	l.texture_scale = radius / (TEXTURE_SIZE / 2.0)
	l.color = color
	l.energy = energy
	return l


static func _soft_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
	return _texture
