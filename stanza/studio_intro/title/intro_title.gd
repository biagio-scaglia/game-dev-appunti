extends Control
## Il nome dello studio, scritto una lettera alla volta, e sotto il sottotitolo
## ("presenta") che compare salendo piano.

## Secondi per lettera.
const TYPE_SPEED := 0.055
## Il sottotitolo resta un po' trasparente: è una voce più bassa del nome.
const SUBTITLE_ALPHA := 0.7
## Di quanti pixel sale mentre compare.
const SUBTITLE_RISE := 4.0

@onready var name_label: Label = $NameLabel
@onready var subtitle_label: Label = $SubtitleLabel
@onready var sfx_blip: AudioStreamPlayer = $SfxBlip
@onready var _subtitle_rest: Vector2 = subtitle_label.position

var _typed := 0


## Mette i testi, ancora nascosti. Sottotitolo vuoto = niente sottotitolo.
func setup(studio_name: String, subtitle := "") -> void:
	name_label.text = studio_name
	name_label.visible_characters = 0
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""
	subtitle_label.modulate.a = 0.0


func is_fully_typed() -> bool:
	return name_label.visible_characters >= name_label.text.length()


func is_subtitle_shown() -> bool:
	return subtitle_label.visible and subtitle_label.modulate.a >= SUBTITLE_ALPHA - 0.01


## Scrive il nome una lettera alla volta, con un "tic" per lettera (non per gli spazi).
func type_name(speed := TYPE_SPEED) -> void:
	_typed = 0
	var letters := name_label.text.length()
	var t := create_tween()
	t.tween_method(_type_to, 0.0, float(letters), maxf(letters * speed, 0.01))
	await t.finished


## Il sottotitolo sale di qualche pixel comparendo.
func show_subtitle(time := 0.6) -> void:
	if not subtitle_label.visible:
		return
	subtitle_label.position = _subtitle_rest + Vector2(0, SUBTITLE_RISE)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(subtitle_label, "modulate:a", SUBTITLE_ALPHA, time)
	t.tween_property(subtitle_label, "position", _subtitle_rest, time)
	await t.finished


func _type_to(v: float) -> void:
	var n := int(v)
	if n == _typed:
		return
	_typed = n
	name_label.visible_characters = n
	if n > 0 and name_label.text[n - 1] != " ":
		sfx_blip.pitch_scale = randf_range(0.94, 1.08)
		sfx_blip.play()
