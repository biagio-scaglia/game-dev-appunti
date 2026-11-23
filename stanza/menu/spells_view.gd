extends VBoxContainer
## Gli incantesimi: in alto quello che parte con Spazio / J, sotto la lista. Scegliere un
## incantesimo imparato lo mette su Spazio / J; quelli non ancora imparati sono "???".

signal described(text: String)

const Style := preload("menu_style.gd")
const Data := preload("menu_data.gd")
const HeartMenu := preload("res://title/title_menu.gd")

var state: RefCounted
var ready_label: Label
var list: HeartMenu


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	ready_label = Style.label("", Style.ACCENT)
	add_child(ready_label)
	add_child(HSeparator.new())
	list = HeartMenu.new()
	list.add_theme_constant_override(&"separation", -4)
	list.chosen.connect(func(id): choose(String(id)))
	add_child(list)


func refresh(game_state: RefCounted) -> void:
	state = game_state
	ready_label.text = "On Space / J:   %s" % Data.spell(state.spell)["name"]
	var entries := []
	for s in Data.SPELLS:
		var text := "???   - not learned -"
		if s["learned"]:
			text = "%s   %d MP%s" % [s["name"], s["mp"], "   (ready)" if s["id"] == state.spell else ""]
		entries.append([StringName(s["id"]), text])
	list.setup(entries, Style.FONT, Style.FONT_SIZE)
	for button: Button in list.get_children():
		button.focus_entered.connect(_describe.bind(String(button.name)))
	list.set_active(false)


func enter(focus := "") -> void:
	list.set_active(true)
	list.focus_id(StringName(focus if focus != "" else state.spell))


func leave() -> void:
	list.set_active(false)


func choose(id: String) -> void:
	var s := Data.spell(id)
	if not s.get("learned", false):
		described.emit("You haven't learned this yet.")
		return
	state.spell = id
	refresh(state)
	enter(id)
	described.emit("%s is now on Space / J." % s["name"])


func _describe(id: String) -> void:
	var s := Data.spell(id)
	described.emit(s["desc"] if s.get("learned", false) else "You haven't learned this yet.")
