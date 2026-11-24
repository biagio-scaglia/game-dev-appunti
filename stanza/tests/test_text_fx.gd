extends "res://tests/base_test.gd"
## Gli effetti sul testo per le righe che non vanno: i conti (glitch, tremolio, lettere che si
## spengono) e il riquadro con una riga [#wrong] (si guasta tutta, il riquadro sobbalza).

const Fx := preload("res://dialogue/text_fx.gd")
const GlitchText := preload("res://menu/glitch.gd")
const DialogueBox := preload("res://dialogue/dialogue_box.gd")
const DIALOGUE := preload("res://dialogue/stanza.dialogue")


func test_i_conti_sono_sempre_uguali() -> void:
	for i in 50:
		assert_eq(Fx.broken(i, 1.234), Fx.broken(i, 1.234), "glitch deterministico")
		assert_eq(Fx.shiver_offset(i, 0.7), Fx.shiver_offset(i, 0.7), "tremolio deterministico")
		assert_eq(Fx.flicker_alpha(i, 2.1), Fx.flicker_alpha(i, 2.1), "flicker deterministico")


func test_il_glitch_e_raro_ma_arriva_a_raffiche() -> void:
	var broken := 0
	var total := 0
	var worst := 0.0
	for s in 200:                       # 200 scatti, ~13 secondi
		var t := s / Fx.GLITCH_FPS
		var now := 0
		for i in 200:
			if Fx.broken(i, t):
				now += 1
				assert_true(Fx.glyph_for(i, t) in GlitchText.GLYPHS, "i segni del menu guasto")
		broken += now
		total += 200
		worst = maxf(worst, now / 200.0)
	var ratio := float(broken) / total
	assert_true(ratio > 0.02 and ratio < 0.2, "di solito poche lettere guaste (%.3f)" % ratio)
	assert_true(worst > 0.3, "ma ogni tanto una raffica (%.2f)" % worst)


func test_il_tremolio_salta_di_un_pixel() -> void:
	var still := 0
	for s in 40:
		for i in 50:
			var o := Fx.shiver_offset(i, s / Fx.SHIVER_FPS)
			assert_true(absf(o.x) <= 1.0 and absf(o.y) <= 1.0, "al massimo un pixel")
			assert_eq(o, o.round(), "pixel interi")
			if o == Vector2.ZERO:
				still += 1
	assert_true(still > 1000 and still < 2000, "molte lettere ferme, qualcuna salta (%d)" % still)


func test_le_lettere_si_spengono_ogni_tanto() -> void:
	var dark := 0
	for s in 40:
		for i in 50:
			var a := Fx.flicker_alpha(i, s / Fx.FLICKER_FPS)
			assert_true(a == 1.0 or a == Fx.FLICKER_ALPHA, "accesa o quasi spenta")
			if a < 1.0:
				dark += 1
	assert_true(dark > 100 and dark < 800, "qualcuna si spegne (%d)" % dark)


func test_la_riga_che_non_va() -> void:
	var box := DialogueBox.new()
	box.sound = false
	tree.root.add_child(box)
	_owned.append(box)
	assert_eq(box.text_label.custom_effects.size(), 3, "glitch, shiver, flicker installati")
	box.start(DIALOGUE, "bed", [])
	for i in 30:
		await tree.process_frame
		if is_instance_valid(box.line):
			break
	assert_false(box.wrong, "la prima riga va bene")
	box.advance()
	box.advance()
	for i in 30:
		await tree.process_frame
		if box.wrong:
			break
	assert_true(box.wrong, "\"I'm not tired.\" non va")
	assert_true("[glitch]" in box.text_label.text and "[shiver]" in box.text_label.text,
		"la riga intera si guasta e trema")
	assert_eq(box.text_label.get_parsed_text(), "I'm not tired.", "ma il testo è quello")
	assert_true(box.root.position != Vector2.ZERO, "il riquadro sobbalza")
	await wait_seconds(0.4)
	assert_eq(box.root.position, Vector2.ZERO, "e torna al suo posto")


func test_le_bugie_si_guastano() -> void:
	# Le righe [#wrong] nel file: le bugie di Lethe.
	var wrong: PackedStringArray = []
	for data: Dictionary in DIALOGUE.lines.values():
		if "wrong" in data.get("tags", []):
			wrong.append(String(data.get("text", "")))
	assert_true("Just old furniture. Nothing to see here." in wrong, "la bugia dello specchio")
	assert_true("One more game. Then I'll sleep." in wrong, "la bugia della console")
