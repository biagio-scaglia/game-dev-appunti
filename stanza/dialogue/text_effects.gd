extends RefCounted
## Gli effetti sul testo dei dialoghi, per le righe "che non vanno". Si scrivono in
## stanza.dialogue come BBCode:
## - [glitch]...[/glitch]   le lettere si guastano: per un attimo diventano i segni del menu
##                          guasto (glitch.gd), in rosa, spostate di un pixel. Ogni tanto a raffica.
## - [shiver]...[/shiver]   tremano a scatti: qualche lettera salta di un pixel, a 12 fps.
## - [flicker]...[/flicker] si spengono e si riaccendono, come una lampada che sta morendo.
## Qui ci sono i RichTextEffect; i conti stanno in text_fx.gd.

const Fx := preload("text_fx.gd")


## Mette gli effetti su un RichTextLabel.
static func install(label: RichTextLabel) -> void:
	label.install_effect(Glitch.new())
	label.install_effect(Shiver.new())
	label.install_effect(Flicker.new())


class Glitch extends RichTextEffect:
	var bbcode := "glitch"

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		var i := fx.relative_index
		if not Fx.broken(i, fx.elapsed_time):
			return true
		var ts := TextServerManager.get_primary_interface()
		var code: int = Fx.glyph_for(i, fx.elapsed_time).unicode_at(0)
		var index := ts.font_get_glyph_index(fx.font, Fx.FONT_SIZE, code, 0)
		if index != 0:
			fx.glyph_index = index
		fx.color = Fx.GLITCH_COLOR
		fx.offset += Vector2(Fx.noise(i, int(fx.elapsed_time * Fx.GLITCH_FPS), 5) % 3 - 1, 0)
		return true


class Shiver extends RichTextEffect:
	var bbcode := "shiver"

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		fx.offset += Fx.shiver_offset(fx.relative_index, fx.elapsed_time)
		return true


class Flicker extends RichTextEffect:
	var bbcode := "flicker"

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		fx.color.a *= Fx.flicker_alpha(fx.relative_index, fx.elapsed_time)
		return true
