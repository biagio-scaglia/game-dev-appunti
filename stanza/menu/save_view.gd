extends VBoxContainer
## Gli slot di salvataggio, per salvare o caricare. Ogni slot mostra nome, giorno e tempo
## di gioco. Il terzo non è suo: c'è già dentro qualcosa, e non si tocca.

signal slot_chosen(slot: int)

const Style := preload("menu_style.gd")
const Data := preload("menu_data.gd")
const SaveStore := preload("save_store.gd")
const GameState := preload("game_state.gd")
const HeartMenu := preload("res://title/title_menu.gd")

## Lo slot che non è di Lethe.
const CURSED_SLOT := 3
const CURSED_TEXT := "File 3   Lethe   Day 0   ??:??:??"

var header: Label
var list: HeartMenu
var mode := &"save"


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	header = Style.label("", Style.ACCENT)
	add_child(header)
	add_child(HSeparator.new())
	list = HeartMenu.new()
	list.add_theme_constant_override(&"separation", -4)
	list.chosen.connect(func(id: StringName): slot_chosen.emit(int(String(id).trim_prefix("slot"))))
	add_child(list)


## mode: &"save" o &"load".
func refresh(new_mode: StringName) -> void:
	mode = new_mode
	header.text = "Save to which file?" if mode == &"save" else "Load which file?"
	var entries := []
	for slot in range(1, SaveStore.SLOTS + 1):
		entries.append([StringName("slot%d" % slot), slot_text(slot)])
	list.setup(entries, Style.FONT, Style.FONT_SIZE)
	list.set_active(false)


static func slot_text(slot: int) -> String:
	if slot == CURSED_SLOT:
		return CURSED_TEXT
	var data := SaveStore.read(slot)
	if data.is_empty():
		return "File %d   - empty -" % slot
	return "File %d   %s   Day %d   %s" % [slot, Data.NAME, int(data.get("day", 1)),
		GameState.format_time(float(data.get("play_time", 0.0)))]


func enter() -> void:
	list.set_active(true)
	list.focus_first()


func leave() -> void:
	list.set_active(false)
