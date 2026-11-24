extends RefCounted
## I conti degli effetti sul testo dei dialoghi (vedi text_effects.gd): quali lettere si
## guastano e con che segno, di quanto saltano, quanto si vedono. Funzioni statiche e
## deterministiche (la stessa lettera nello stesso scatto fa sempre la stessa cosa), così
## si provano nei test. Tutto a pixel interi e a scatti: è pixel art.

const GlitchText := preload("res://menu/glitch.gd")

## Glitch: una lettera ogni tanto, e ogni PERIOD secondi una raffica di BURST secondi.
const GLITCH_FPS := 15.0
const GLITCH_CHANCE := 0.06
const BURST_CHANCE := 0.5
const BURST_PERIOD := 1.6
const BURST := 0.14
const GLITCH_COLOR := Color(0.95, 0.42, 0.62)
## Shiver: quante lettere su tante saltano a ogni scatto.
const SHIVER_FPS := 12.0
const SHIVER_EVERY := 4
## Flicker: a ogni scatto una lettera su tante si spegne quasi del tutto.
const FLICKER_FPS := 9.0
const FLICKER_CHANCE := 0.18
const FLICKER_ALPHA := 0.25
## La grandezza del font del riquadro: serve per cercare il glifo che sostituisce la lettera.
const FONT_SIZE := 16


## Un numero a caso ma sempre uguale per la stessa lettera nello stesso scatto.
static func noise(index: int, step: int, salt := 0) -> int:
	return absi(hash(Vector3i(index, step, salt)))


## La lettera `index` è guasta al tempo `time`?
static func broken(index: int, time: float) -> bool:
	var step := int(time * GLITCH_FPS)
	var period := int(time / BURST_PERIOD)
	# La raffica parte in un punto diverso di ogni periodo.
	var burst_at := (noise(period, 0, 7) % 100) / 100.0 * (BURST_PERIOD - BURST)
	var in_period := time - period * BURST_PERIOD
	var chance := BURST_CHANCE if in_period >= burst_at and in_period < burst_at + BURST \
			else GLITCH_CHANCE
	return (noise(index, step, 1) % 1000) < chance * 1000.0


## Il segno che prende il posto della lettera guasta.
static func glyph_for(index: int, time: float) -> String:
	var glyphs: String = GlitchText.GLYPHS
	return glyphs[noise(index, int(time * GLITCH_FPS), 2) % glyphs.length()]


## Di quanto salta la lettera `index` (pixel interi: -1, 0 o 1 per lato).
static func shiver_offset(index: int, time: float) -> Vector2:
	var n := noise(index, int(time * SHIVER_FPS), 3)
	if n % SHIVER_EVERY != 0:
		return Vector2.ZERO
	return Vector2((n / 4) % 3 - 1, (n / 12) % 3 - 1)


## Quanto si vede la lettera `index` (1 accesa, FLICKER_ALPHA quasi spenta).
static func flicker_alpha(index: int, time: float) -> float:
	var n := noise(index, int(time * FLICKER_FPS), 4)
	return FLICKER_ALPHA if (n % 1000) < FLICKER_CHANCE * 1000.0 else 1.0
