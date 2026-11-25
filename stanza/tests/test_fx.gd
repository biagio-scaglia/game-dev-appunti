extends "res://tests/base_test.gd"
## Effetti d'atmosfera: sfarfallio, schermo acceso, raggio di luna, musica in loop.

const Flicker := preload("res://fx/flicker.gd")
const ScreenGlow := preload("res://fx/screen_glow.gd")
const Main := preload("res://main.gd")
const MoonBeam := preload("res://fx/moon_beam.gd")
const Music := preload("res://core/music.gd")
const ROOM := preload("res://world/room.gd")


func test_lo_sfarfallio_resta_nei_limiti() -> void:
	for i in 200:
		var e := Flicker.energy_at(1.0, 0.12, 9.0, i * 0.037)
		assert_true(e >= 0.88 - 0.0001 and e <= 1.12 + 0.0001, "energia fuori range: %s" % e)


func test_lo_sfarfallio_muove_la_luce() -> void:
	var light := PointLight2D.new()
	light.energy = 1.0
	var f := Flicker.new()
	f.amount = 0.3
	f.speed = 12.0
	light.add_child(f)
	tree.root.add_child(light)
	_owned.append(light)
	var seen := {}
	for i in 10:
		await tree.process_frame
		seen[snappedf(light.energy, 0.001)] = true
	assert_true(seen.size() > 3, "l'energia cambia nel tempo")


func test_lo_schermo_tremola_senza_sparire() -> void:
	var glow := ScreenGlow.new()
	for i in 100:
		var a := glow.alpha_at(i * 0.013)
		assert_true(a > 0.0 and a <= glow.base_alpha * 2.0, "alpha: %s" % a)
	glow.free()


func test_il_raggio_di_luna_scende_e_ha_il_pulviscolo() -> void:
	var beam := MoonBeam.new()
	tree.root.add_child(beam)
	_owned.append(beam)
	var poly := beam.polygon()
	assert_eq(poly.size(), 4, "trapezio")
	assert_true(poly[2].y > poly[0].y, "scende verso il pavimento")
	assert_true(beam.dust.emitting and beam.dust.amount > 0, "pulviscolo")


func test_la_stanza_attacca_gli_effetti_ai_mobili() -> void:
	var room := Node2D.new()
	room.set_script(ROOM)
	tree.root.add_child(room)
	_owned.append(room)
	var flickers := 0
	for l in room.lights:
		flickers += l.get_children().filter(func(n): return n is Flicker).size()
	assert_eq(flickers, 4, "schermo, telefono, lampada e luna sfarfallano")
	assert_eq(room.get_children().filter(func(n): return n is ScreenGlow).size(), 1, "uno schermo acceso")
	assert_eq(room.get_children().filter(func(n): return n is MoonBeam).size(), 1, "un raggio di luna")


func test_la_musica_va_in_loop() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://audio/stanza_theme.wav")
	tree.root.add_child(player)
	_owned.append(player)
	Music.play_loop(player)
	var stream: AudioStreamWAV = player.stream
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "loop attivo")
	assert_true(stream.loop_end > stream.mix_rate * 20, "loop di tutto il brano (oltre 20 s)")
	assert_true(player.playing, "suona")


func test_nel_bosco_il_raggio_fa_una_pozza_di_luce() -> void:
	var beam := MoonBeam.new()
	beam.pool = true
	tree.root.add_child(beam)
	_owned.append(beam)
	assert_true(beam.light != null, "una luce vera dove tocca terra")
	assert_true(beam.light.position.distance_to(beam.foot()) < 0.5, "proprio lì")
	var plain := MoonBeam.new()
	tree.root.add_child(plain)
	_owned.append(plain)
	assert_true(plain.light == null, "nella stanza no")


func test_nel_bosco_i_raggi_partono_da_sopra_la_mappa() -> void:
	Main.pending_save = {"flags": {"forest_arrived": true, "talk_learned": true, "selene_met": true}}
	var zone := add_scene("res://forest/zone_wake.tscn", func(n): n.sound = false)
	await tree.process_frame
	var beams := zone.get_children().filter(func(n): return n is MoonBeam)
	assert_eq(beams.size(), 3, "tre raggi")
	for beam in beams:
		var full_from: float = beam.position.y + beam.length * beam.fade_until
		assert_true(full_from <= 0.0, "il pezzo che sfuma sta fuori dalla mappa: salendo non sparisce")
	Main.pending_save = {}
