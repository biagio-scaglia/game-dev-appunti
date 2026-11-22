extends RefCounted
## Effetti piccoli e senza stato: le scintille.

const SheetFrames := preload("../core/sheet_frames.gd")
const SPARKLE_SHEET := preload("../assets/sparkle.png")
const SPARKLE_CELL := Vector2(7, 7)
const SPARKLE_FRAMES := 4

static var _sparkle_frames: SpriteFrames


## Una scintilla in `at` (coordinate di `parent`): nasce, brilla, sparisce da sola.
static func sparkle(parent: Node, at: Vector2) -> AnimatedSprite2D:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _get_sparkle_frames()
	s.position = at
	s.scale = Vector2(2, 2)
	parent.add_child(s)
	s.animation_finished.connect(s.queue_free)
	s.play()
	return s


## Una scintilla per ogni punto di `points`, una ogni `gap` secondi.
static func sparkle_burst(parent: Node, points: Array, gap: float) -> void:
	for i in points.size():
		parent.get_tree().create_timer(i * gap).timeout.connect(sparkle.bind(parent, points[i]))


static func _get_sparkle_frames() -> SpriteFrames:
	if _sparkle_frames == null:
		_sparkle_frames = SpriteFrames.new()
		SheetFrames.add_strip(_sparkle_frames, &"default", SPARKLE_SHEET, SPARKLE_CELL, SPARKLE_FRAMES, 12.0)
	return _sparkle_frames
