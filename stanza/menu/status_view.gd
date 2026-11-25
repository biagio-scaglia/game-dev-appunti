extends VBoxContainer
## Lo stato di Lethe: la sua riga, poi parametri (con l'equipaggiamento), equipaggiamento,
## incantesimo su Q e karma: le verità sono un numero, le bugie no (lie_eyes.gd: un filo
## spinato con un occhio rosso aperto per ogni bugia).

const Style := preload("menu_style.gd")
const Data := preload("menu_data.gd")
const Equipment := preload("equipment.gd")
const HeroCard := preload("hero_card.gd")
const LieEyes := preload("lie_eyes.gd")

var hero: HeroCard
var _params := {}
var _slots := {}
var spell_label: Label
var truth_label: Label
var lies_label: Label
var lie_eyes: Control


func _init() -> void:
	add_theme_constant_override(&"separation", 14)
	hero = HeroCard.new()
	add_child(hero)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 40)
	var params := GridContainer.new()
	params.columns = 2
	params.add_theme_constant_override(&"h_separation", 24)
	params.add_theme_constant_override(&"v_separation", 0)
	for p in Data.PARAM_ORDER:
		params.add_child(Style.label(p, Style.ACCENT))
		_params[p] = Style.label("")
		params.add_child(_params[p])
	columns.add_child(params)

	var gear := GridContainer.new()
	gear.columns = 2
	gear.add_theme_constant_override(&"h_separation", 16)
	gear.add_theme_constant_override(&"v_separation", 0)
	for s in Data.EQUIP_SLOTS:
		gear.add_child(Style.label(s[1], Style.ACCENT))
		_slots[s[0]] = Style.label("")
		gear.add_child(_slots[s[0]])
	gear.add_child(Style.label("Spell", Style.ACCENT))
	spell_label = Style.label("")
	gear.add_child(spell_label)
	gear.add_child(Style.label("Truth", Style.ACCENT))
	truth_label = Style.label("")
	gear.add_child(truth_label)
	columns.add_child(gear)
	add_child(columns)
	# Le bugie: sotto tutto, su una riga loro. Il numero c'è ma non si vede.
	var lies_row := HBoxContainer.new()
	lies_row.add_theme_constant_override(&"separation", 16)
	lies_row.add_child(Style.label("Lies", Style.ACCENT))
	lie_eyes = LieEyes.new()
	lie_eyes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lies_row.add_child(lie_eyes)
	lies_label = Style.label("")
	lies_label.visible = false
	lies_row.add_child(lies_label)
	add_child(lies_row)


func refresh(state: RefCounted, sword_stage: int) -> void:
	var values := Equipment.params(state.equipped, sword_stage)
	for p in Data.PARAM_ORDER:
		_params[p].text = str(values[p])
	for s in _slots:
		_slots[s].text = Equipment.item_name(state.equipped[s], sword_stage)
	spell_label.text = Data.spell(state.spell).get("name", Data.NOTHING)
	truth_label.text = str(state.truth)
	lies_label.text = str(state.lies)
	lie_eyes.set_count(state.lies)


func param_text(param: String) -> String:
	return _params[param].text


func slot_text(slot: String) -> String:
	return _slots[slot].text
