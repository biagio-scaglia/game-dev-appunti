extends "menu_page.gd"
## Gli incantesimi: in alto quello che parte con Q, sotto la lista. Scegliere un
## incantesimo imparato lo mette su Q; quelli non ancora imparati sono "???" e
## sceglierli non si può. All'inizio sono tutti "???".

const Data := preload("menu_data.gd")

var state: RefCounted


func refresh(game_state: RefCounted) -> void:
	state = game_state
	header.text = "On Q:   %s" % Data.spell(state.spell).get("name", Data.NOTHING)
	var entries := []
	for s in Data.SPELLS:
		var text := "%s   - not learned -" % Data.UNKNOWN
		if state.knows(s["id"]):
			text = "%s   %d MP%s" % [s["name"], s["mp"], "   (ready)" if s["id"] == state.spell else ""]
		entries.append([StringName(s["id"]), text])
	fill(entries, _describe)


func enter(focus := &"") -> void:
	if focus == &"" and state.spell != "":
		focus = StringName(state.spell)
	super(focus)


func choose(id: String) -> void:
	var s := Data.spell(id)
	if not state.knows(id):
		denied.emit("You haven't learned this yet.")
		return
	state.spell = id
	refresh(state)
	enter(StringName(id))
	described.emit("%s is now on Q." % s["name"])


func _describe(id: StringName) -> void:
	var s := Data.spell(String(id))
	described.emit(s["desc"] if state.knows(String(id)) else "You haven't learned this yet.")


func _on_chosen(id: StringName) -> void:
	choose(String(id))
