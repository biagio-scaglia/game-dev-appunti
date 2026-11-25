extends RefCounted
## Le cose da ricordare tra una partita e l'altra che non sono un salvataggio: i flag (se
## l'avviso sui contenuti è già stato letto) e le impostazioni del menu del titolo (volume,
## musica, schermo intero, scuotimento dello schermo, velocità del testo). Un ConfigFile in
## user://. apply() le mette in pratica (audio, finestra); il resto le legge quando serve.

## Dove sta il file (i test ne usano un altro).
static var path := "user://settings.cfg"

const SECTION := "flags"
const VALUES := "settings"
## Il canale della musica (core/music.gd ci manda i brani): così la si regola da sola.
const MUSIC_BUS := &"Music"
## Le impostazioni e il loro valore di partenza. I volumi vanno da 0 a VOLUME_STEPS.
const DEFAULTS := {
	"volume": 8,
	"music": 8,
	"fullscreen": false,
	"shake": true,
	"text_speed": 1,
}
const VOLUME_STEPS := 10
## Velocità del testo: lento, normale, veloce (quanto si moltiplica il tempo per lettera).
const TEXT_SPEEDS := [1.8, 1.0, 0.45]
const TEXT_SPEED_NAMES := ["Slow", "Normal", "Fast"]

static var _cache: Dictionary = {}
## Il file da cui viene la cache (se `path` cambia, si rilegge).
static var _cache_path := ""


static func has_flag(key: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	return bool(config.get_value(SECTION, key, false))


static func set_flag(key: String, value := true) -> void:
	_write(SECTION, key, value)


static func erase() -> void:
	_cache.clear()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Il valore di un'impostazione (quello di partenza se non è mai stata cambiata).
static func value(key: String) -> Variant:
	if _cache.is_empty() or _cache_path != path:
		_cache.clear()
		_cache_path = path
		var config := ConfigFile.new()
		config.load(path)
		for k in DEFAULTS:
			_cache[k] = config.get_value(VALUES, k, DEFAULTS[k])
	return _cache.get(key, DEFAULTS.get(key))


## Cambia un'impostazione, la salva e la mette subito in pratica.
static func set_value(key: String, v: Variant) -> void:
	value(key)                     # riempie la cache
	_cache[key] = v
	_write(VALUES, key, v)
	apply()


static func _write(section: String, key: String, v: Variant) -> void:
	var config := ConfigFile.new()
	config.load(path)      # se non c'è, si parte da vuoto
	config.set_value(section, key, v)
	if config.save(path) != OK:
		push_error("Impostazioni non salvate: %s" % path)


## Da 0..VOLUME_STEPS a decibel (0 = muto).
static func volume_db(steps: int) -> float:
	if steps <= 0:
		return -80.0
	return linear_to_db(float(steps) / VOLUME_STEPS)


## Il canale della musica, se manca lo crea (manda al Master).
static func ensure_buses() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, MUSIC_BUS)
	AudioServer.set_bus_send(index, &"Master")


## Mette in pratica le impostazioni: volumi e schermo intero.
static func apply() -> void:
	ensure_buses()
	AudioServer.set_bus_volume_db(0, volume_db(int(value("volume"))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), volume_db(int(value("music"))))
	if DisplayServer.get_name() == "headless":
		return
	var full := bool(value("fullscreen"))
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)


## Quanto dura una lettera nei dialoghi rispetto al normale.
static func text_speed_scale() -> float:
	return TEXT_SPEEDS[clampi(int(value("text_speed")), 0, TEXT_SPEEDS.size() - 1)]
