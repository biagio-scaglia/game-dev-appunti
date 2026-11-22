extends RefCounted
## La scritta "Clicca o premi un tasto" che pulsa. Serve solo sul web: il browser
## non fa partire l'audio finché la pagina non riceve un clic o un tasto.

const TEXT := "Clicca o premi un tasto"


## Crea la scritta, la aggiunge a `parent` a tutto schermo e la fa pulsare.
static func show_on(parent: Control, font: Font, font_size := 16) -> Label:
	var label := Label.new()
	label.text = TEXT
	label.uppercase = true
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(label)
	var t := label.create_tween().set_loops()
	t.tween_property(label, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	return label
