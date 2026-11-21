extends RefCounted
## Gli effetti dei mobili, letti dal JSON dei tile: la luce (con lo sfarfallio, se
## c'è), il velo dello schermo acceso, il raggio di luna dalla finestra.

const Glow := preload("../core/glow.gd")
const Flicker := preload("../fx/flicker.gd")
const ScreenGlow := preload("../fx/screen_glow.gd")
const MoonBeam := preload("../fx/moon_beam.gd")


## Aggiunge a `parent` gli effetti del tile, con l'angolo in alto a sinistra in
## `top_left` (pixel). Ritorna la luce creata (o null).
static func attach(parent: Node2D, tile: Dictionary, top_left: Vector2) -> PointLight2D:
	var light: PointLight2D = null
	if tile.has("light"):
		var info: Dictionary = tile["light"]
		var c: Array = info["color"]
		light = Glow.light(Color(c[0], c[1], c[2]), float(info["energy"]), float(info["radius"]))
		light.position = top_left + _vec(info["offset"])
		parent.add_child(light)
		if tile.has("flicker"):
			var f := Flicker.new()
			f.amount = float(tile["flicker"][0])
			f.speed = float(tile["flicker"][1])
			f.dip_chance = float(tile["flicker"][2])
			light.add_child(f)
	if tile.has("screen"):
		var s: Array = tile["screen"]
		var glow := ScreenGlow.new()
		glow.rect = Rect2(top_left + Vector2(s[0], s[1]), Vector2(s[2], s[3]))
		parent.add_child(glow)
	if tile.has("beam"):
		var beam := MoonBeam.new()
		beam.position = top_left + _vec(tile["beam"])
		parent.add_child(beam)
	return light


static func _vec(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
