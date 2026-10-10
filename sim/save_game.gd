class_name SaveGame
extends RefCounted

## Autosave once a week, plus one manual slot. Both live under user://.

const AUTO := "user://autosave.sav"
const MANUAL := "user://manual.sav"


static func write_auto(game: Game) -> bool:
	return _write(AUTO, game)


static func write_manual(game: Game) -> bool:
	return _write(MANUAL, game)


static func has_any() -> bool:
	return FileAccess.file_exists(AUTO) or FileAccess.file_exists(MANUAL)


static func has_manual() -> bool:
	return FileAccess.file_exists(MANUAL)


static func load_latest(game: Game) -> bool:
	return _read(_newest(), game)


static func load_manual(game: Game) -> bool:
	return _read(MANUAL, game)


static func _write(path: String, game: Game) -> bool:
	if game == null:
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(game.export_state(), true)
	f.close()
	return true


static func _newest() -> String:
	var best := ""
	var best_time := -1
	for path in [AUTO, MANUAL]:
		if not FileAccess.file_exists(path):
			continue
		var modified := int(FileAccess.get_modified_time(path))
		if modified >= best_time:
			best = path
			best_time = modified
	return best


static func _read(path: String, game: Game) -> bool:
	if path == "" or game == null or not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var data = f.get_var(true)
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return game.import_state(data)
