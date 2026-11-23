extends RefCounted
## L'aspetto del menu di pausa: il tema (font, colori, il pannello del titolo come
## finestra) e i ritratti di Lethe ritagliati dai suoi sheet. Solo helper statici.

const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const PANEL := preload("res://title/art/panel.png")
const IDLE_SHEET := "res://characters/protagonista/sprites/protagonista_idle.png"

const TEXT := Color(0.86, 0.82, 0.96)
const DIM := Color(0.55, 0.5, 0.68)
const ACCENT := Color(0.72, 0.55, 1.0)
const HP_COLOR := Color(0.78, 0.36, 0.5)
const MP_COLOR := Color(0.5, 0.44, 0.92)
const FONT_SIZE := 16

## Il viso nella cella 64x64 dello sheet (riga 0 giù, riga 4 su: di spalle).
const FACE := Rect2(16, 10, 32, 32)
const ROW_DOWN := 0
const ROW_UP := 4


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = FONT_SIZE
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_stylebox(&"panel", &"PanelContainer", window_style())
	return t


static func window_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PANEL
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 8)
		style.set_content_margin(side, 10)
	return style


static func label(text: String, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", color)
	return l


static func has_sprites() -> bool:
	return ResourceLoader.exists(IDLE_SHEET)


## Il viso di Lethe (di spalle se `away`). Null se gli sprite non ci sono.
static func face(away := false) -> AtlasTexture:
	return _cut(Rect2(FACE.position + Vector2(0, 64 * (ROW_UP if away else ROW_DOWN)), FACE.size))


## Lethe intera, ferma, di fronte (per la sagoma nel secondo posto).
static func body() -> AtlasTexture:
	return _cut(Rect2(0, 0, 64, 64))


static func _cut(region: Rect2) -> AtlasTexture:
	if not has_sprites():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(IDLE_SHEET)
	atlas.region = region
	return atlas


## Un riquadro per un'immagine pixel art ingrandita a blocchi interi.
static func picture(texture: Texture2D, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect
