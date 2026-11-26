extends SceneTree
## Lancia tutti i test in res://tests/test_*.gd e stampa il risultato.
## Esce con 1 se almeno un test fallisce (così una CI si ferma).
##
## Uso:  Godot.exe --headless --path . -s res://tests/run_tests.gd

const TESTS_DIR := "res://tests"


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var passed := 0
	var failed := 0
	for file in _test_files():
		print("\n%s" % file)
		var script: GDScript = load(TESTS_DIR.path_join(file))
		if script == null or not script.can_instantiate():
			# Non compila: senza questo il file si saltava in silenzio e il totale era "verde".
			failed += 1
			print("  FAIL  il file non compila (vedi SCRIPT ERROR sopra)")
			continue
		for test_name in _test_methods(script):
			var case: RefCounted = script.new()
			case.tree = self
			await case.before()
			await case.call(test_name)
			await case.after()
			if case.failures.is_empty():
				passed += 1
				print("  ok    ", test_name)
			else:
				failed += 1
				print("  FAIL  ", test_name)
				for f in case.failures:
					print("        - ", f)
	print("\n%d passati, %d falliti" % [passed, failed])
	# Lascia al server audio il tempo di chiudere i suoni ancora in coda.
	await create_timer(0.5).timeout
	quit(1 if failed > 0 else 0)


func _test_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(TESTS_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out


func _test_methods(script: GDScript) -> PackedStringArray:
	var out: PackedStringArray = []
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and n not in out:
			out.append(n)
	return out
