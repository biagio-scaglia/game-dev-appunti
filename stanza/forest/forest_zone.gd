extends Node2D
## Una zona della foresta (la prima: zone_wake.tscn, scritta da tools/make_forest_zone.gd e
## poi ritoccabile nell'editor). La scena ha il terreno ("Ground", con le collisioni del
## TileSet: bosco fitto e Lete), le piante basse ("Decor"), le cose ("World": Sprite2D col
## nome del tile nei metadati), "Spawn" ed "Exit". Qui, quando parte:
## - il buio della notte (CanvasModulate), raggi di luna tra le chiome, lucciole;
## - luci e collisioni delle cose, dal JSON dei tile (gli alberi bloccano solo al tronco);
## - Lethe, con la camera che la segue e si ferma ai bordi della zona;
## - l'OST della foresta, il menu di pausa, i dialoghi con le cose (forest.dialogue),
##   l'obiettivo in alto;
## - la prima volta (dalla caduta del prologo) l'arrivo: il nero che si apre, le schegge
##   che brillano intorno a lei, "Grass. Cold, wet grass.";
## - l'uscita: per ora il capitolo finisce qui e si torna al titolo;
## - i nemici (enemies/: falene d'ombra, rovi che sussurrano, lucciole false) e la vita a
##   cuore (ui/heart_hud.gd): ogni colpo la mano stringe di più; stretto del tutto, "Death is
##   a lie.", e Lethe si risveglia davanti allo specchio (dove si riposa: il cuore torna intero).
##
## Lo stato arriva da Main.pending_save (il prologo che finisce, o Continue dal titolo).

signal exited
signal died
signal respawned

const Main := preload("res://main.gd")
const GameState := preload("res://menu/game_state.gd")
const ForestTileset := preload("res://world/forest/forest_tileset.gd")
const RoomTileset := preload("res://world/room_tileset.gd")
const RoomFx := preload("res://world/room_fx.gd")
const RoomThings := preload("res://world/room_things.gd")
const MoonBeam := preload("res://fx/moon_beam.gd")
const Fireflies := preload("res://fx/fireflies.gd")
const Sparks := preload("res://fx/sparks.gd")
const Music := preload("res://core/music.gd")
const Sfx := preload("res://core/sfx.gd")
const ObjectiveBanner := preload("res://ui/objective_banner.gd")
const Talk := preload("res://dialogue/talk.gd")
const Layout := preload("zone_wake_layout.gd")
const HERO := preload("res://characters/protagonista/protagonista.tscn")
const PAUSE_MENU := preload("res://menu/pause_menu.tscn")
const DIALOGUE := preload("res://dialogue/forest.dialogue")
const THEME := preload("res://audio/forest_theme.wav")
const GLINT := preload("res://audio/shard_glint.wav")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const TITLE := "res://title/title_screen.tscn"
const HeartHud := preload("res://ui/heart_hud.gd")
const ScreenShake := preload("res://fx/screen_shake.gd")
const HURT := preload("res://audio/heart_hurt.wav")
const BREAK := preload("res://audio/heart_break.wav")
const ENEMY_SCRIPTS := {
	"moth": preload("res://enemies/shadow_moth.gd"),
	"bramble": preload("res://enemies/whispering_bramble.gd"),
	"firefly": preload("res://enemies/false_firefly.gd"),
}

const PLACE := "The Forest"
const NIGHT := Color(0.4, 0.45, 0.62)
const TILE := 32
const GOAL_PATH := "Follow the path"
## Le cose con cui si parla (i cue di forest.dialogue che sono tile).
const TALKS := ["mirror", "brambles", "old_stone"]

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var world: Node2D = $World
@onready var spawn: Marker2D = $Spawn
@onready var exit_area: Area2D = $Exit

var state: RefCounted = GameState.new()
var hero: CharacterBody2D
var camera: Camera2D
var music: AudioStreamPlayer
var pause_menu: CanvasLayer
var talk: Node
var objective: CanvasLayer
var hud: CanvasLayer
## Dove si riparte quando il cuore è stretto del tutto (lo Spawn, poi lo specchio).
var respawn_point := Vector2.ZERO
var _dying := false
var data: Dictionary
## Falso nei test: niente suoni.
var sound := true
var _leaving := false


func _ready() -> void:
	data = ForestTileset.load_data()
	var night := CanvasModulate.new()
	night.color = NIGHT
	add_child(night)
	if not Main.pending_save.is_empty():
		state.load_save(Main.pending_save)
	state.place = PLACE
	_build_things()
	_light_decor()
	for at in Layout.BEAMS:
		var beam := MoonBeam.new()
		beam.position = at - Vector2(50, 200)
		beam.z_index = 1
		add_child(beam)
	for at in Layout.FIREFLIES:
		var flies := Fireflies.new()
		flies.position = at
		flies.z_index = 2
		add_child(flies)
	hero = HERO.instantiate()
	world.add_child(hero)
	var saved := GameState.saved_position(Main.pending_save)
	hero.global_position = saved if state.flag("forest_arrived") and saved != Vector2.ZERO \
		else spawn.global_position
	hero.set("sword_stage", int(Main.pending_save.get("sword_stage", 0)))
	Main.pending_save = {}
	_add_camera()
	respawn_point = spawn.global_position
	hero.damaged.connect(_on_hero_damaged)
	spawn_enemies()
	music = AudioStreamPlayer.new()
	music.stream = THEME
	music.volume_db = -6.0
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	pause_menu = PAUSE_MENU.instantiate()
	add_child(pause_menu)
	pause_menu.setup(state, hero, music)
	pause_menu.closed.connect(sync_abilities)
	sync_abilities()
	talk = Talk.new()
	talk.name = "Talk"
	add_child(talk)                     # dopo il menu: il riquadro si prende l'input prima
	talk.setup_with(self, hero, state, talk_things(), DIALOGUE)
	talk.extra_states.append(self)
	talk.key_hint = not state.flag("talk_learned")
	talk.talk_finished.connect(_on_talk_finished)
	objective = ObjectiveBanner.new()
	objective.show_heart = false                     # il cuore c'è già: quello della vita
	objective.at = Vector2(HeartHud.AT.x + HeartHud.FRAME + 6, 18)
	add_child(objective)
	hud = HeartHud.new()
	hud.sound = sound
	add_child(hud)
	hud.show_heart(state.heart, state.heart_max)
	exit_area.body_entered.connect(_on_exit)
	if sound:
		Music.play_loop(music)
	if not state.flag("forest_arrived"):
		arrive()
	else:
		objective.show_text(GOAL_PATH)


func sync_abilities() -> void:
	hero.can_cast = state.can_cast()
	hero.can_slash = state.can_slash()


## Il rettangolo della zona, in pixel.
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(Layout.SIZE) * TILE)


func _add_camera() -> void:
	camera = Camera2D.new()
	var b := bounds()
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.end.x)
	camera.limit_bottom = int(b.end.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.position = Vector2(0, -20)                # un po' sopra i piedi: si guarda il viso
	hero.add_child(camera)
	camera.make_current()


# --- Le cose -------------------------------------------------------------------------------

## Le cose della zona (gli Sprite2D sotto World col tile nei metadati).
func thing_nodes() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child in world.get_children():
		if child is Sprite2D and child.has_meta(&"tile"):
			out.append(child)
	return out


## Il rettangolo di una cosa (il suo disegno intero, in pixel della zona).
static func thing_rect(sprite: Sprite2D) -> Rect2:
	return Rect2(sprite.position + sprite.offset, sprite.texture.get_size())


## Luci e collisioni: dal JSON del tile, come nella stanza. Le collisioni stanno nelle celle
## "solid" (solo il tronco, per gli alberi).
func _build_things() -> void:
	for sprite in thing_nodes():
		var tile: Dictionary = data["tiles"][sprite.get_meta(&"tile")]
		var rect := thing_rect(sprite)
		RoomFx.attach(self, tile, rect.position)
		if not tile["solid"]:
			continue
		var body := StaticBody2D.new()
		body.collision_layer = RoomTileset.WORLD_LAYER
		sprite.add_child(body)
		var cells := Vector2i(int(tile["size"][0]), int(tile["size"][1]))
		for y in cells.y:
			for x in cells.x:
				if not RoomTileset.is_solid_cell(tile, Vector2i(x, y)):
					continue
				var shape := CollisionShape2D.new()
				var box := RectangleShape2D.new()
				box.size = Vector2(TILE, TILE)
				shape.shape = box
				shape.position = sprite.offset + (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE
				body.add_child(shape)


## Le luci delle piante basse (funghi e fiori fanno luce).
func _light_decor() -> void:
	var by_atlas := {}
	for tile_name in data["tiles"]:
		var t: Dictionary = data["tiles"][tile_name]
		by_atlas[Vector2i(int(t["atlas"][0]), int(t["atlas"][1]))] = t
	for cell in decor.get_used_cells():
		var tile: Dictionary = by_atlas.get(decor.get_cell_atlas_coords(cell), {})
		if tile.has("light"):
			RoomFx.attach(self, tile, Vector2(cell) * TILE)


## Le cose con cui si parla: i tile in TALKS e il ruscello del Lete.
func talk_things() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sprite in thing_nodes():
		var tile_name: String = sprite.get_meta(&"tile")
		if tile_name in TALKS:
			out.append({"id": tile_name, "rect": thing_rect(sprite)})
	# Il ruscello, sopra e sotto il ponte (sul ponte non si guarda l'acqua a ogni passo).
	var bridge_row: int = Layout.BRIDGE[0]
	for r in Layout.LETHE:
		for span in [[r[1], bridge_row], [bridge_row + 1, r[3]]]:
			var top_left := Vector2(r[0], span[0]) * TILE
			out.append({"id": "lethe", "rect": Rect2(top_left, Vector2(r[2] - r[0], span[1] - span[0]) * TILE)})
	return out


# --- I nemici e il cuore ------------------------------------------------------------------

func enemies() -> Array:
	return get_tree().get_nodes_in_group(&"enemies").filter(func(e): return is_ancestor_of(e))


func spawn_enemies() -> void:
	for entry in Layout.ENEMIES:
		var enemy: CharacterBody2D = ENEMY_SCRIPTS[entry[0]].new()
		enemy.name = "%s_%d" % [entry[0], world.get_child_count()]
		enemy.sound = sound
		enemy.target = hero
		enemy.position = (Vector2(entry[1]) + Vector2(0.5, 0.8)) * TILE
		world.add_child(enemy)


func _on_hero_damaged(amount: int, _from: Vector2) -> void:
	if _dying:
		return
	state.hurt(amount)
	hud.show_heart(state.heart, state.heart_max)
	hud.hit()
	if sound:
		Sfx.play(self, HURT, randf_range(0.95, 1.05), -2.0)
	var shake := ScreenShake.new()
	shake.strength = 3.0
	shake.duration = 0.2
	get_tree().root.add_child(shake)
	if state.is_dead():
		die()


## Il cuore stretto del tutto: tutto si ferma, il nero, "Death is a lie.", e Lethe si
## risveglia davanti allo specchio col cuore intero (i nemici tornano al loro posto).
func die(pace := 1.0) -> void:
	if _dying:
		return
	_dying = true
	hero.set(&"frozen", true)
	for enemy in enemies():
		enemy.set_physics_process(false)
	if sound:
		Sfx.play(self, BREAK, 1.0, -2.0)
	died.emit()
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.size = Vector2(640, 360)
	layer.add_child(black)
	var label := Label.new()
	label.text = "Death is a lie."
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", Color(0.78, 0.2, 0.3))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(640, 20)
	label.position = Vector2(0, 170)
	label.modulate.a = 0.0
	layer.add_child(label)
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, 1.2 * pace)
	t.tween_property(label, "modulate:a", 1.0, 0.8 * pace)
	t.tween_interval(1.6 * pace)
	t.tween_property(label, "modulate:a", 0.0, 0.6 * pace)
	await t.finished
	respawn()
	var back := create_tween()
	back.tween_property(black, "color:a", 0.0, 1.2 * pace)
	await back.finished
	layer.queue_free()
	_dying = false
	respawned.emit()
	talk.say(DIALOGUE, "wake_again")


## Di nuovo in piedi: davanti allo specchio (o allo Spawn), cuore intero, nemici al posto.
func respawn() -> void:
	for enemy in enemies():
		enemy.queue_free()
	spawn_enemies.call_deferred()
	state.heal(state.heart_max)
	hud.show_heart(state.heart, state.heart_max)
	hero.global_position = respawn_point
	hero.set(&"knock", Vector2.ZERO)
	hero.set(&"invulnerable", 0.0)
	hero.set(&"frozen", false)
	camera.reset_smoothing()


## Lo specchio: ci si riposa (il cuore torna intero) e da qui si riparte.
func rest() -> void:
	state.heal(state.heart_max)
	hud.show_heart(state.heart, state.heart_max)
	for sprite in thing_nodes():
		if sprite.get_meta(&"tile") == "mirror":
			respawn_point = sprite.global_position + Vector2(0, 20)
	state.set_flag("rested")
	if sound:
		Sfx.play(self, GLINT, 1.0, -8.0)


# --- L'arrivo e l'uscita -------------------------------------------------------------------

## La prima volta: il nero che si apre piano, le schegge che brillano intorno a Lethe,
## l'arrivo raccontato. `pace` accorcia le attese (test).
func arrive(pace := 1.0) -> void:
	hero.set(&"frozen", true)
	hero.set(&"facing", Vector2.DOWN)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(640, 360)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	await get_tree().create_timer(0.8 * pace).timeout
	var glass := Sparks.shards(18)
	glass.global_position = hero.global_position + Vector2(0, -10)
	world.add_child(glass)
	glass.emitting = true
	glass.finished.connect(glass.queue_free)
	if sound:
		Sfx.play(self, GLINT, 0.8, -6.0)
	var open := create_tween()
	open.tween_property(black, "color:a", 0.0, 2.4 * pace).set_trans(Tween.TRANS_SINE)
	await open.finished
	layer.queue_free()
	state.set_flag("forest_arrived")
	talk.say(DIALOGUE, "arrive")


func _on_talk_finished(id: String) -> void:
	if id in TALKS or id == "lethe":
		state.set_flag("talk_learned")
	if id == "arrive":
		objective.show_text(GOAL_PATH)
	if id == "exit":
		_leave()


func _on_exit(body: Node) -> void:
	if body != hero or _leaving:
		return
	_leaving = true
	objective.show_text("")
	talk.say(DIALOGUE, "exit")


## Per ora la foresta finisce qui: "To be continued", poi il titolo.
func _leave() -> void:
	hero.set(&"frozen", true)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.size = Vector2(640, 360)
	layer.add_child(black)
	var label := Label.new()
	label.text = "TO BE CONTINUED"
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", Color(0.78, 0.76, 0.88))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(640, 20)
	label.position = Vector2(0, 170)
	label.modulate.a = 0.0
	layer.add_child(label)
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, 1.4)
	t.parallel().tween_property(music, "volume_db", -40.0, 1.8)
	t.tween_property(label, "modulate:a", 1.0, 1.0)
	t.tween_interval(2.4)
	t.tween_property(label, "modulate:a", 0.0, 1.0)
	await t.finished
	exited.emit()
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file(TITLE)
