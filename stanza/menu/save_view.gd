extends "menu_page.gd"
## Gli slot di salvataggio, per salvare o caricare. Ogni slot mostra nome, giorno e tempo
## di gioco. Il terzo non è suo: c'è già dentro qualcosa, e non si tocca.

signal slot_chosen(slot: int)

const Data := preload("menu_data.gd")
const SaveStore := preload("save_store.gd")
const GameState := preload("game_state.gd")

## Lo slot che non è di Lethe.
const CURSED_SLOT := 3
const CURSED_TEXT := "File 3   Lethe   Day 0   ??:??:??"

var mode := &"save"


## mode: &"save" o &"load".
func refresh(new_mode: StringName) -> void:
	mode = new_mode
	header.text = "Save to which file?" if mode == &"save" else "Load which file?"
	var entries := []
	for slot in range(1, SaveStore.SLOTS + 1):
		entries.append([slot_id(slot), slot_text(slot)])
	fill(entries)


static func slot_id(slot: int) -> StringName:
	return StringName("slot%d" % slot)


static func slot_text(slot: int) -> String:
	if slot == CURSED_SLOT:
		return CURSED_TEXT
	var data := SaveStore.read(slot)
	if data.is_empty():
		return "File %d   - empty -" % slot
	return "File %d   %s   Day %d   %s" % [slot, Data.NAME, int(data.get("day", 1)),
		GameState.format_time(float(data.get("play_time", 0.0)))]


## Il pulsante di uno slot (per gli effetti che lo toccano).
func slot_button(slot: int) -> Button:
	return list.get_node_or_null(NodePath(String(slot_id(slot)))) as Button


func _on_chosen(id: StringName) -> void:
	slot_chosen.emit(int(String(id).trim_prefix("slot")))
