extends RefCounted
## I file di salvataggio: uno per slot, in JSON, in user://saves/. Solo file, niente nodi.
## Si scrive prima in un file accanto (.tmp) e poi lo si mette al posto del vecchio: se il
## gioco si chiude a metà scrittura, il salvataggio di prima resta intero.

const SLOTS := 3

## Cartella dei salvataggi (i test ne usano un'altra).
static var dir := "user://saves"


static func path(slot: int) -> String:
	return dir.path_join("slot_%d.json" % slot)


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


static func write(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path(slot) + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Salvataggio non riuscito: %s" % tmp)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var ok := file.get_error() == OK
	file.close()
	if not ok or DirAccess.rename_absolute(tmp, path(slot)) != OK:
		push_error("Salvataggio non riuscito: %s" % path(slot))
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Il salvataggio dello slot, o {} se non c'è (o è rotto).
static func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path(slot))) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


static func erase(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))
