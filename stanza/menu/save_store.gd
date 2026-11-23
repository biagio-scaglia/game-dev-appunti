extends RefCounted
## I file di salvataggio: uno per slot, in JSON, in user://saves/. Solo file, niente nodi.

const SLOTS := 3

## Cartella dei salvataggi (i test ne usano un'altra).
static var dir := "user://saves"


static func path(slot: int) -> String:
	return dir.path_join("slot_%d.json" % slot)


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


static func write(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Salvataggio non riuscito: %s" % path(slot))
		return false
	file.store_string(JSON.stringify(data, "\t"))
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
