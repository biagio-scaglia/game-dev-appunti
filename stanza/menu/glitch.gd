extends RefCounted
## Testo che si guasta per un attimo: alcune lettere diventano segni. Gli spazi restano,
## così la riga non cambia forma. Solo logica.

const GLYPHS := "#%&?/<>_=*!"


## `amount` è la parte di lettere da guastare (0 niente, 1 tutte).
static func corrupt(text: String, amount: float, rng: RandomNumberGenerator) -> String:
	var out := ""
	for ch in text:
		if ch != " " and rng.randf() < amount:
			out += GLYPHS[rng.randi() % GLYPHS.length()]
		else:
			out += ch
	return out
