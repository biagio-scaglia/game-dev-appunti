extends Node
## Cancellare i file, dalle impostazioni del titolo. Non va come dovrebbe (vault: "Il gioco
## mente"):
## - il File 3 non si cancella: le scritte si guastano, "IT'S NOT YOURS." (non è di Lethe,
##   come nel menu di pausa);
## - un file vuoto: "There is nothing there to forget.";
## - un file vero: prima si chiede (il cuore parte su "Keep"), poi la riga si guasta sempre di
##   più, con un ronzio, la finestra trema e tra le lettere passano frammenti ("don't",
##   "I'm still here"); il vetro, un lampo rosso, e il file non c'è più. Per un attimo
##   ricompare ("...where did I go?"), poi resta vuoto. Il titolo, dopo, sente bussare.
##
## Lavora sulla pagina delle impostazioni (settings_page.gd): la sua lista, il titolo, l'aiuto.
## `pace` accorcia le attese (test).

const SaveStore := preload("res://menu/save_store.gd")
const SaveView := preload("res://menu/save_view.gd")
const Glitch := preload("res://menu/glitch.gd")
const Sfx := preload("res://core/sfx.gd")
const FONT := preload("res://ui/fonts/kenpixel_high_square.ttf")
const DENY := preload("res://audio/menu_deny.wav")
const GLASS := preload("res://audio/menu_glass.wav")
const HUM := preload("res://audio/mirror_hum.wav")
const WHISPER := preload("res://audio/bramble_whisper.wav")

const RED := Color(0.85, 0.22, 0.32)
const TITLE_COLOR := Color(0.93, 0.9, 1.0)
## Quanto dura la riga che si guasta prima di sparire.
const CORRUPT_TIME := 1.8
const STEP := 0.06
## Quello che passa tra le lettere mentre il file si cancella.
const FRAGMENTS := ["don't", "please", "I'm still here", "LETHE", "wait"]
const LAST_WORDS := "...where did I go?"

var page: Control
var busy := false
var pace := 1.0
## Il file che si sta per cancellare (0 = nessuno: si sta guardando la lista).
var pending := 0
var rng := RandomNumberGenerator.new()


func setup(settings_page: Control) -> void:
	page = settings_page


## La lista dei file (e Back).
func open_list(focus := &"slot1") -> void:
	page.mode = &"erase"
	pending = 0
	_title("Erase which file?")
	var entries := []
	for slot in range(1, SaveStore.SLOTS + 1):
		entries.append([SaveView.slot_id(slot), SaveView.slot_text(slot)])
	entries.append([&"back", "Back"])
	page.list.setup(entries, FONT, 16)
	page.list.focus_id(focus)
	page.help_label.text = ""


func back() -> void:
	if busy:
		return
	if pending != 0:
		open_list(SaveView.slot_id(pending))
	else:
		page.show_settings(&"erase")


func choose(id: StringName) -> void:
	if busy:
		return
	match id:
		&"back":
			back()
		&"keep":
			open_list(SaveView.slot_id(pending))
		&"forget":
			erase(pending)
		_:
			var slot := int(String(id).trim_prefix("slot"))
			if slot == SaveView.CURSED_SLOT:
				refuse()
			elif SaveStore.read(slot).is_empty():
				_sfx(DENY, 1.1, -8.0)
				page.help_label.text = "There is nothing there to forget."
			else:
				confirm(slot)


## Il File 3 non si cancella.
func refuse() -> void:
	busy = true
	_sfx(DENY, 0.6, -2.0)
	var buttons: Array = page.list.get_children()
	var originals: Array = buttons.map(func(b: Button) -> String: return b.text)
	var t := 0.0
	while t < 0.6:
		for b: Button in buttons:
			b.text = Glitch.corrupt(originals[buttons.find(b)], 0.5, rng)
		_jolt(3.0)
		await _wait(STEP)
		t += STEP
	for i in buttons.size():
		buttons[i].text = originals[i]
	page.list.position.x = 0.0
	_title("IT'S NOT YOURS.", RED)
	page.help_label.text = "That file was never yours to erase."
	await _wait(1.2)
	_title("Erase which file?")
	busy = false


func confirm(slot: int) -> void:
	pending = slot
	_title("Erase File %d?" % slot, RED)
	page.list.setup([[&"forget", "Erase"], [&"keep", "Keep"]], FONT, 16)
	page.list.focus_id(&"keep")                # il cuore parte dalla scelta che non fa danni
	page.help_label.text = "She won't remember any of it."


## Il file se ne va, ma non in silenzio.
func erase(slot: int) -> void:
	busy = true
	pending = 0
	_title("File %d" % slot)
	var text := SaveView.slot_text(slot)
	page.list.setup([[SaveView.slot_id(slot), text]], FONT, 16)
	var row: Button = page.list.get_child(0)
	page.list.set_active(false)
	page.help_label.text = ""
	_sfx(HUM, 0.6, -6.0)
	var t := 0.0
	var whispered := false
	while t < CORRUPT_TIME:
		var k := t / CORRUPT_TIME
		if rng.randf() < 0.18 + 0.2 * k:
			row.text = "File %d   %s" % [slot, FRAGMENTS[rng.randi() % FRAGMENTS.size()]]
			if not whispered and k > 0.4:
				whispered = true
				_sfx(WHISPER, 0.8, -6.0)
		else:
			row.text = Glitch.corrupt(text, 0.15 + 0.85 * k, rng)
		row.add_theme_color_override(&"font_disabled_color", Color.WHITE.lerp(RED, k))
		row.modulate = Color.WHITE.lerp(RED, k)
		_jolt(1.0 + 4.0 * k)
		await _wait(STEP)
		t += STEP
	page.list.position.x = 0.0
	_sfx(GLASS, 0.7, -2.0)
	_flash()
	SaveStore.erase(slot)
	row.modulate = Color.WHITE
	row.text = SaveView.slot_text(slot)
	await _wait(0.7)
	row.text = "File %d   Lethe   %s" % [slot, LAST_WORDS]   # un attimo: è ancora lì?
	await _wait(0.14)
	row.text = SaveView.slot_text(slot)
	_title("File %d is gone." % slot)
	page.file_erased.emit(slot)
	await _wait(1.2)
	busy = false
	page.list.set_active(true)
	open_list(SaveView.slot_id(slot))


func _title(text: String, color := TITLE_COLOR) -> void:
	page.title_label.text = text
	page.title_label.add_theme_color_override(&"font_color", color)


func _jolt(power: float) -> void:
	page.list.position.x = roundf(rng.randf_range(-power, power))


## Un lampo rosso su tutta la pagina.
func _flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(RED, 0.45)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(flash)
	var t := flash.create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.5 * pace)
	t.tween_callback(flash.queue_free)


func _sfx(stream: AudioStream, pitch: float, db: float) -> void:
	if page.sound:
		Sfx.play(page, stream, pitch, db)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * pace).timeout
