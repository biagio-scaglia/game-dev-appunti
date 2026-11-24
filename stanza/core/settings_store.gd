extends RefCounted
## Le cose da ricordare tra una partita e l'altra che non sono un salvataggio (per ora:
## se l'avviso sui contenuti è già stato letto). Un ConfigFile in user://. Solo file.

## Dove sta il file (i test ne usano un altro).
static var path := "user://settings.cfg"

const SECTION := "flags"


static func has_flag(key: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	return bool(config.get_value(SECTION, key, false))


static func set_flag(key: String, value := true) -> void:
	var config := ConfigFile.new()
	config.load(path)      # se non c'è, si parte da vuoto
	config.set_value(SECTION, key, value)
	if config.save(path) != OK:
		push_error("Impostazioni non salvate: %s" % path)


static func erase() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
