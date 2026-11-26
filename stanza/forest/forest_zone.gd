extends Node2D
## Una zona della foresta (zone_wake.tscn, zone_tree.tscn, zone_roots.tscn..., scritte da
## tools/make_forest_zone.gd dai dati in zone_<nome>_layout.gd e poi ritoccabili nell'editor).
## Quale zona è lo dice `zone_id`; si passa da una all'altra dalle uscite (Exit_0...), e si
## arriva all'entrata giusta (ENTRIES nei dati). La scena ha il terreno ("Ground", con le
## collisioni del TileSet), le piante basse ("Decor"), le cose ("World": Sprite2D col nome del
## tile nei metadati), "Spawn" e le uscite.
##
## Questo script monta i pezzi e tiene la zona insieme:
## - zone_dressing.gd: luci e collisioni delle cose, raggi di luna, lucciole, cose con cui si parla;
## - zone_combat.gd ("Combat"): nemici, cuore, esperienza, oggetti, morte, riposo, il segreto;
## - zone_puzzles.gd ("Puzzles"): piastre, cancelli di radici, chiavi, porte, scatole;
## - forest_story.gd ("Story"): la regia del capitolo (scene, Selene, obiettivi);
## - qui: il buio, Lethe e la camera (per stanze nei dungeon: core/room_camera.gd), la musica,
##   il menu di pausa, i dialoghi, l'interfaccia, i passaggi tra le zone.
## Le funzioni pubbliche del combattimento (die, rest, drop, gain_exp...) passano da qui, così
## dialoghi e regia parlano solo con la zona.
##
## Lo stato arriva da Main.pending_save (il prologo che finisce, un'altra zona, o Continue).

signal exited
signal died
signal respawned
signal leveled_up(level: int)
signal secret_shown
## Per la regia (forest_story.gd): un nemico sciolto, un oggetto raccolto.
signal enemy_defeated(enemy: Node2D)
## Si va in un'altra zona (prima di cambiare scena).
signal traveled(to_zone: String)
signal item_picked(id: String)

const Main := preload("res://main.gd")
const GameState := preload("res://menu/game_state.gd")
const ForestTileset := preload("res://world/forest/forest_tileset.gd")
const RoomCamera := preload("res://core/room_camera.gd")
const Music := preload("res://core/music.gd")
const Sfx := preload("res://core/sfx.gd")
const ObjectiveBanner := preload("res://ui/objective_banner.gd")
const HeartHud := preload("res://ui/heart_hud.gd")
const ScreenText := preload("res://ui/screen_text.gd")
const WorldGrey := preload("res://fx/world_grey.gd")
const Talk := preload("res://dialogue/talk.gd")
const ZoneLayout := preload("zone_layout.gd")
const ZoneDressing := preload("zone_dressing.gd")
const ZoneCombat := preload("zone_combat.gd")
const ZonePuzzles := preload("zone_puzzles.gd")
const Zones := preload("zones.gd")
const ForestStory := preload("forest_story.gd")
const HERO := preload("res://characters/protagonista/protagonista.tscn")
const PAUSE_MENU := preload("res://menu/pause_menu.tscn")
const DIALOGUE := preload("res://dialogue/forest.dialogue")
const THEME := preload("res://audio/forest_theme.wav")
const GLINT := preload("res://audio/shard_glint.wav")
const TITLE := "res://title/title_screen.tscn"
## L'incantesimo della prima verità (lo insegna la regia).
const FIRST_SPELL := ForestStory.FIRST_SPELL

const PLACE := "The Forest"
const NIGHT := Color(0.4, 0.45, 0.62)
const TILE := 32
const GOAL_PATH := "Follow the path"
## Quanto ci mette lo schermo a farsi nero passando da una zona all'altra.
const TRAVEL_FADE := 0.5

## Quale zona è (forest/zones.gd): la scrive il generatore nella scena.
@export var zone_id := "wake"

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var world: Node2D = $World
@onready var spawn: Marker2D = $Spawn

var state: RefCounted = GameState.new()
## I dati della zona (forest/zone_<nome>_layout.gd).
var Layout: GDScript
var data: Dictionary
var hero: CharacterBody2D
var camera: Camera2D
var music: AudioStreamPlayer
var pause_menu: CanvasLayer
var talk: Node
var objective: CanvasLayer
var hud: CanvasLayer
## La camera per stanze (solo nei dungeon: ROOMS nei dati).
var rooms: Node
## Nemici, cuore, esperienza, morte, riposo.
var combat: Node
## Piastre, cancelli, chiavi, porte, scatole.
var puzzles: Node
## La regia del capitolo: le scene, Selene e le sue battute.
var story: Node
## Selene, la compagna (dopo che è scesa dalla luna: la crea la regia).
var selene: Node2D
## Falso nei test: niente suoni.
var sound := true

## Dove si riparte quando il cuore è stretto del tutto (lo tiene il combattimento).
var respawn_point: Vector2:
	get: return combat.respawn_point
	set(value): combat.respawn_point = value
## L'indicazione del tasto della spada (la tiene il combattimento).
var slash_hint: CanvasLayer:
	get: return combat.slash_hint

var _leaving := false
var _lies_before := 0


func _ready() -> void:
	get_tree().paused = false                   # una scena nuova parte sempre in movimento
	Layout = Zones.layout(zone_id)
	data = ForestTileset.load_data()
	var night := CanvasModulate.new()
	night.color = layout_value("DARKNESS", NIGHT)       # sottoterra è più buio
	add_child(night)
	if not Main.pending_save.is_empty():
		state.load_save(Main.pending_save)
	var entry := String(Main.pending_save.get("entry", ""))
	var same_zone := String(Main.pending_save.get("zone", Zones.FIRST)) == zone_id
	state.place = PLACE
	state.zone = zone_id
	_dress()
	hero = HERO.instantiate()
	world.add_child(hero)
	hero.global_position = start_position(entry, same_zone)
	Main.pending_save = {}
	_add_camera()
	_add_combat()
	puzzles = ZonePuzzles.new()
	puzzles.name = "Puzzles"
	add_child(puzzles)
	puzzles.setup(self)
	_add_music()
	_add_menu()
	_add_talk()
	_add_ui()
	for exit in exits():
		exit.body_entered.connect(_on_exit.bind(exit))
	_add_story()
	if sound:
		Music.play_loop(music)
	if state.flag("selene_met"):
		story.spawn_selene().snap()
	if rooms:
		rooms.room_changed.connect(story.on_room)
	story.zone_ready(entry != "")


# --- Il montaggio ---------------------------------------------------------------------------

func _dress() -> void:
	ZoneDressing.build_things(self, world, data)
	ZoneDressing.light_decor(self, decor, data)
	ZoneDressing.add_beams(self, layout_value("BEAMS"), is_underground())
	ZoneDressing.add_fireflies(self, layout_value("FIREFLIES"))


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
	if is_underground():                             # il dungeon: la camera per stanze
		rooms = RoomCamera.new()
		rooms.name = "Rooms"
		add_child(rooms)
		rooms.setup(camera, hero, layout_value("ROOMS"), TILE)


func _add_combat() -> void:
	combat = ZoneCombat.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(self)
	# I segnali del combattimento sono anche della zona (la regia e i test ascoltano la zona).
	combat.died.connect(died.emit)
	combat.respawned.connect(respawned.emit)
	combat.leveled_up.connect(leveled_up.emit)
	combat.secret_shown.connect(secret_shown.emit)
	combat.enemy_defeated.connect(enemy_defeated.emit)
	combat.item_picked.connect(item_picked.emit)


func _add_music() -> void:
	music = AudioStreamPlayer.new()
	var theme_path := String(layout_value("THEME", ""))
	music.stream = load(theme_path) if theme_path != "" else THEME
	music.volume_db = -6.0
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)


func _add_menu() -> void:
	pause_menu = PAUSE_MENU.instantiate()
	add_child(pause_menu)
	pause_menu.setup(state, hero, music)
	pause_menu.closed.connect(sync_abilities)
	pause_menu.loaded.connect(Main.resume_save)
	sync_abilities()


func _add_talk() -> void:
	talk = Talk.new()
	talk.name = "Talk"
	add_child(talk)                     # dopo il menu: il riquadro si prende l'input prima
	talk.setup_with(self, hero, state, talk_things(), DIALOGUE)
	talk.extra_states.append(self)
	talk.extra_states.append(puzzles)    # i dialoghi aprono porte e scatole
	talk.key_hint = not state.flag("talk_learned")
	talk.talk_finished.connect(_on_talk_finished)
	talk.talk_started.connect(func(_id: String) -> void: hud.set_shown(false))
	talk.talk_finished.connect(func(_id: String) -> void: hud.set_shown(true))


func _add_ui() -> void:
	objective = ObjectiveBanner.new()
	objective.show_heart = false       # di cuore ce n'è uno solo: quello della vita, in basso
	add_child(objective)
	hud = HeartHud.new()
	hud.sound = sound
	add_child(hud)
	hud.show_heart(state.heart, state.heart_max)
	var grey := WorldGrey.new()                 # le bugie spengono i colori del bosco
	grey.name = "WorldGrey"
	add_child(grey)
	grey.setup(state)


func _add_story() -> void:
	story = ForestStory.new()
	story.name = "Story"
	add_child(story)
	story.setup(self)
	talk.extra_states.append(story)       # i dialoghi chiamano selene_met() e learn_truth()
	talk.talk_started.connect(func(_id: String) -> void: _lies_before = state.lies)
	talk.talk_finished.connect(func(_id: String) -> void: story.after_talk(_lies_before))


func _process(_delta: float) -> void:
	if hero and talk:
		story.check_first_enemy()
		combat.check_slash_hint()


# --- Dati e luoghi ----------------------------------------------------------------------------

## Una costante dei dati della zona (vuota se non c'è).
func layout_value(key: String, default: Variant = []) -> Variant:
	return ZoneLayout.value(Layout, key, default)


## Sottoterra (un dungeon a stanze)?
func is_underground() -> bool:
	return not layout_value("ROOMS").is_empty()


## Il rettangolo della zona, in pixel.
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(layout_value("SIZE")) * TILE)


## Dove parte Lethe: all'entrata da cui arriva (da un'altra zona), dove aveva salvato (in
## questa zona), o allo Spawn.
func start_position(entry: String, same_zone: bool) -> Vector2:
	var entries: Dictionary = layout_value("ENTRIES", {})
	if entry != "" and entries.has(entry):
		return ZoneLayout.cell_center(entries[entry], TILE)
	var saved := GameState.saved_position(Main.pending_save)
	if same_zone and saved != Vector2.ZERO and (zone_id != Zones.FIRST or state.flag("forest_arrived")):
		return saved
	return spawn.global_position


func thing_nodes() -> Array[Sprite2D]:
	return ZoneDressing.thing_nodes(world)


## Le cose con cui si parla: i tile in TALKS, il ruscello del Lete, e porte, scatole e
## cancelli dei meccanismi.
func talk_things() -> Array[Dictionary]:
	var out := ZoneDressing.talk_things(world, layout_value("TALKS"), layout_value("LETHE"), layout_value("BRIDGE"))
	if puzzles:
		out.append_array(puzzles.talk_things())
	return out


func sync_abilities() -> void:
	hero.can_cast = state.can_cast()
	hero.can_slash = state.can_slash()
	hero.attack_bonus = state.attack_bonus()
	var stage: int = state.sword_stage()        # la spada cresce con le bugie
	var grew: bool = stage > int(hero.sword_stage) and state.can_slash() and is_node_ready()
	hero.sword_stage = stage
	if grew:
		toast(["", "The shard grows.", "The glass is a blade now."][stage],
			"Another lie. Another piece of the mirror.")
		if sound:
			Sfx.play(self, GLINT, 0.7, -4.0)


## Nome e riga in alto al centro (il livello, la stanza nuova, la spada che cresce).
func toast(title: String, line: String) -> void:
	ScreenText.toast(self, title, line)


# --- Il combattimento (passa da qui: dialoghi e regia parlano con la zona) ---------------------

func enemies() -> Array:
	return combat.enemies()


func spawn_enemies() -> void:
	combat.spawn_enemies()


func enemy_key(index: int) -> String:
	return combat.enemy_key(index)


func drop(id: String, at: Vector2) -> Node2D:
	return combat.drop(id, at)


func gain_exp(amount: int) -> void:
	combat.gain_exp(amount)


func die(pace := 1.0) -> void:
	await combat.die(pace)


func respawn() -> void:
	combat.respawn()


## Dai dialoghi (lo specchio, la cornice d'argento): ci si riposa.
func rest() -> void:
	combat.rest()


func mirror_point() -> Vector2:
	return combat.mirror_point()


# --- Le uscite ----------------------------------------------------------------------------------

func _on_talk_finished(id: String) -> void:
	if id in layout_value("TALKS") or id == "lethe":
		state.set_flag("talk_learned")
	story.on_talk(id)


## Le uscite verso le altre zone (Area2D col meta "to_zone").
func exits() -> Array[Area2D]:
	var out: Array[Area2D] = []
	for child in get_children():
		if child is Area2D and child.has_meta(&"to_zone"):
			out.append(child)
	return out


## Un'uscita: verso la zona dei suoi meta. La prima volta, se la regia ha una scena per
## quel passaggio (la camera che guarda l'albero bianco), prima la scena.
func _on_exit(body: Node, exit: Area2D = null) -> void:
	if body != hero or _leaving:
		return
	if exit == null:
		exit = exits()[0]
	_leaving = true
	objective.show_text("")
	var to_zone := String(exit.get_meta(&"to_zone"))
	await story.before_travel(to_zone)
	travel(to_zone, String(exit.get_meta(&"entry")))


## Si va in un'altra zona: lo schermo si fa nero, lo stato passa (Main.pending_save, con
## l'entrata da cui si arriva), e la scena cambia.
func travel(to_zone: String, entry: String) -> void:
	hero.set(&"frozen", true)
	var black := ScreenText.black_layer(self, 90)
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, TRAVEL_FADE)
	t.parallel().tween_property(music, "volume_db", -30.0, TRAVEL_FADE)
	await t.finished
	var data_out: Dictionary = state.to_save(Vector2.ZERO, int(hero.get("sword_stage")))
	data_out["zone"] = to_zone
	data_out["entry"] = entry
	Main.pending_save = data_out
	traveled.emit(to_zone)
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file(Zones.scene(to_zone))


## Dove il capitolo per ora finisce: "To be continued", poi il titolo.
func _leave() -> void:
	hero.set(&"frozen", true)
	var black := ScreenText.black_layer(self, 90)
	var label := ScreenText.centered_line(black.get_parent(), "TO BE CONTINUED", Color(0.78, 0.76, 0.88))
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
