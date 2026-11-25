extends CanvasLayer
## Il mondo che si svuota (vault: "Sistema Karma", "Riferimenti e ispirazioni"): quando le
## bugie superano le verità, i colori del mondo si spengono verso un grigio freddo; restano
## solo i rossi (gli occhi, le bacche, le luci che mentono). Con la verità il colore torna.
##
## Un filtro su tutto lo schermo sopra il mondo (livello LAYER) e sotto l'interfaccia (HUD,
## dialoghi, menu stanno più in alto): legge lo schermo già disegnato e lo desatura.
## Quanto, lo dice lo stato (GameState.grey_amount); quando cambia ci va piano, e quando
## cresce si vede un battito: il colore che se ne va.
##
## Uso: var grey := WorldGrey.new(); add_child(grey); grey.setup(state)

## Sopra il mondo (0), sotto tutto il resto.
const LAYER := 1
## In quanti secondi raggiunge il grigio nuovo.
const EASE := 1.6

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(screen, SCREEN_UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// quanto è rosso: il rosso non si spegne mai
	float red = clamp((c.r - max(c.g, c.b)) * 3.0 - 0.15, 0.0, 1.0);
	vec3 grey = vec3(lum) * vec3(0.94, 0.93, 1.0);   // un grigio freddo, appena viola
	COLOR = vec4(mix(c.rgb, grey, amount * (1.0 - red)), 1.0);
}
"""

var state: RefCounted
var rect: ColorRect
var material: ShaderMaterial
## Il grigio di adesso (va verso quello dello stato).
var amount := 0.0


func _init() -> void:
	layer = LAYER
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	add_child(rect)


## Lo stato da guardare; il grigio parte subito giusto (niente dissolvenza all'avvio).
func setup(game_state: RefCounted) -> void:
	state = game_state
	amount = target()
	_apply()


func target() -> float:
	return float(state.grey_amount()) if state and state.has_method(&"grey_amount") else 0.0


func _process(delta: float) -> void:
	var goal := target()
	if is_equal_approx(goal, amount):
		return
	amount = move_toward(amount, goal, delta / EASE)
	_apply()


func _apply() -> void:
	material.set_shader_parameter(&"amount", amount)
	rect.visible = amount > 0.001          # a colori pieni non costa niente
