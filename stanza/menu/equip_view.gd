extends HBoxContainer
## Equipaggiamento, come in RPG Maker. A sinistra gli slot (arma, corpo, accessorio) con
## quello che Lethe ha addosso; scelto uno slot, sotto compaiono gli oggetti che ci vanno.
## A destra i parametri: mentre si guarda un oggetto, accanto ai valori che cambierebbero
## c'è quello nuovo (più alto in viola, più basso in rosso).

## Il testo per la barra d'aiuto in fondo al menu.
signal described(text: String)
signal equipped

const Style := preload("menu_style.gd")
const Data := preload("menu_data.gd")
const Equipment := preload("equipment.gd")
const HeartMenu := preload("res://title/title_menu.gd")
const NONE := "none"

var state: RefCounted
var sword_stage := 0
var slots: HeartMenu
var items: HeartMenu
var items_header: Label
## &"slots" (si sceglie lo slot) o &"items" (si sceglie l'oggetto).
var mode := &"slots"
var slot := "weapon"
var _now := {}
var _next := {}


func _init() -> void:
	add_theme_constant_override(&"separation", 36)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 250
	left.add_theme_constant_override(&"separation", 4)
	left.add_child(Style.label("Equipment", Style.ACCENT))
	slots = HeartMenu.new()
	slots.add_theme_constant_override(&"separation", -4)
	slots.chosen.connect(func(id): open_slot(String(id)))
	left.add_child(slots)
	left.add_child(HSeparator.new())
	items_header = Style.label("", Style.ACCENT)
	left.add_child(items_header)
	items = HeartMenu.new()
	items.add_theme_constant_override(&"separation", -4)
	items.chosen.connect(func(id): equip(String(id)))
	left.add_child(items)
	add_child(left)

	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 4)
	right.add_child(Style.label("Stats", Style.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 0)
	for p in Data.PARAM_ORDER:
		grid.add_child(Style.label(p, Style.ACCENT))
		_now[p] = Style.label("")
		_next[p] = Style.label("")
		grid.add_child(_now[p])
		grid.add_child(_next[p])
	right.add_child(grid)
	add_child(right)


func refresh(game_state: RefCounted, stage: int) -> void:
	state = game_state
	sword_stage = stage
	var entries := []
	for s in Data.EQUIP_SLOTS:
		entries.append([StringName(s[0]), "%s   %s" % [s[1], Equipment.item_name(state.equipped[s[0]], stage)]])
	slots.setup(entries, Style.FONT, Style.FONT_SIZE)
	for button: Button in slots.get_children():
		button.focus_entered.connect(_on_slot_focus.bind(String(button.name)))
	slots.set_active(false)
	_close_items()


func enter() -> void:
	mode = &"slots"
	slots.set_active(true)
	slots.focus_id(StringName(slot))


## Indietro: dagli oggetti agli slot (true: gestito qui), dagli slot si esce (false).
func back() -> bool:
	if mode == &"items":
		_close_items()
		slots.set_active(true)
		slots.focus_id(StringName(slot))
		return true
	slots.set_active(false)
	return false


func leave() -> void:
	_close_items()
	slots.set_active(false)


func open_slot(id: String) -> void:
	slot = id
	mode = &"items"
	var entries := []
	for item_id in Equipment.items_for(slot):
		entries.append([StringName(item_id), Equipment.item_name(item_id, sword_stage)])
	if slot == "accessory":
		entries.append([StringName(NONE), "(none)"])
	items.setup(entries, Style.FONT, Style.FONT_SIZE)
	for button: Button in items.get_children():
		button.focus_entered.connect(_preview.bind(String(button.name)))
	items_header.text = "Choose a %s" % Equipment.slot_name(slot).to_lower()
	slots.set_active(false)
	items.set_active(true)
	var current := String(state.equipped[slot])
	items.focus_id(StringName(current if current != "" else NONE))


func equip(id: String) -> void:
	state.equipped[slot] = "" if id == NONE else id
	equipped.emit()
	refresh(state, sword_stage)
	enter()
	described.emit("Equipped: %s." % Equipment.item_name(state.equipped[slot], sword_stage))


## Il valore nuovo di un parametro, come si vede ("> 7"; vuoto se non si sta scegliendo).
func preview_text(param: String) -> String:
	return _next[param].text


func _close_items() -> void:
	mode = &"slots"
	items.setup([], Style.FONT, Style.FONT_SIZE)
	items_header.text = ""
	_show_params({})


func _on_slot_focus(id: String) -> void:
	slot = id
	var current := String(state.equipped[id])
	described.emit("%s: %s. %s" % [Equipment.slot_name(id), Equipment.item_name(current, sword_stage),
		Equipment.description(current)])


func _preview(id: String) -> void:
	var trial: Dictionary = state.equipped.duplicate()
	trial[slot] = "" if id == NONE else id
	_show_params(Equipment.params(trial, sword_stage))
	described.emit(Equipment.description(trial[slot]))


func _show_params(preview: Dictionary) -> void:
	var now := Equipment.params(state.equipped, sword_stage) if state else Data.BASE_PARAMS
	for p in Data.PARAM_ORDER:
		_now[p].text = str(now[p])
		var label: Label = _next[p]
		if preview.is_empty() or preview[p] == now[p]:
			label.text = ""   # solo i valori che cambiano
			continue
		label.text = "> %d" % preview[p]
		var color := Style.TEXT
		if preview[p] > now[p]:
			color = Style.ACCENT
		elif preview[p] < now[p]:
			color = Style.HP_COLOR
		label.add_theme_color_override(&"font_color", color)
