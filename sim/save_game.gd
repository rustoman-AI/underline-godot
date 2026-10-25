class_name SaveGame
extends RefCounted

## Autosave once a week, plus one manual slot. Both live under `root`.
## A save is written to a .tmp file, read back and validated, then swapped in; the slot it replaces
## stays beside it as .bak. Loading tries the newest slot first and falls back to the others.

## Tests point this at their own folder so the player's slots are never touched.
static var root := "user://"
## The file the last successful load came from, and why the last write or load failed.
static var last_path := ""
static var last_error := ""


static func auto_path() -> String:
	return root.path_join("autosave.sav")


static func manual_path() -> String:
	return root.path_join("manual.sav")


static func write_auto(game: Game) -> bool:
	return _write(auto_path(), game)


static func write_manual(game: Game) -> bool:
	return _write(manual_path(), game)


static func has_any() -> bool:
	for path in [auto_path(), manual_path()]:
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			return true
	return false


static func has_manual() -> bool:
	return FileAccess.file_exists(manual_path()) or FileAccess.file_exists(manual_path() + ".bak")


## Newest readable save of any slot, then the backups.
static func load_latest(game: Game) -> bool:
	var slots := _by_age([auto_path(), manual_path()])
	var backups := _by_age([auto_path() + ".bak", manual_path() + ".bak"])
	return _load_first(slots + backups, game)


static func load_manual(game: Game) -> bool:
	return _load_first([manual_path(), manual_path() + ".bak"], game)


static func _load_first(paths: Array, game: Game) -> bool:
	last_path = ""
	var errors: PackedStringArray = []
	for path in paths:
		var why := _read(str(path), game)
		if why == "":
			last_path = str(path)
			last_error = "; ".join(errors)
			return true
		errors.append("%s: %s" % [str(path).get_file(), why])
	last_error = "; ".join(errors) if not errors.is_empty() else "no save"
	return false


static func _write(path: String, game: Game) -> bool:
	last_error = ""
	if game == null:
		last_error = "no game"
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "open %s: %s" % [tmp.get_file(), error_string(FileAccess.get_open_error())]
		return false
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var stored := f.store_var(data, false)
	f.flush()
	var err := f.get_error()
	f.close()
	if not stored or err != OK:
		last_error = "write %s: %s" % [tmp.get_file(), error_string(err)]
		DirAccess.remove_absolute(tmp)
		return false
	var check := _decode(tmp)
	if check.error == "":
		check.error = Game.stage_state(check.data, game.catalog).error
	if check.error != "":
		last_error = "verify %s: %s" % [tmp.get_file(), check.error]
		DirAccess.remove_absolute(tmp)
		return false
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		var old := _decode(path)
		if old.error == "" and Game.stage_state(old.data, game.catalog).error == "":
			if FileAccess.file_exists(bak):
				DirAccess.remove_absolute(bak)
			err = DirAccess.rename_absolute(path, bak)
		else:
			err = DirAccess.remove_absolute(path)
		if err != OK:
			last_error = "keep %s: %s" % [bak.get_file(), error_string(err)]
			DirAccess.remove_absolute(tmp)
			return false
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		last_error = "swap %s: %s" % [path.get_file(), error_string(err)]
		if FileAccess.file_exists(bak) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(bak, path)
		return false
	return true


static func _by_age(paths: Array) -> Array:
	var found: Array = []
	for path in paths:
		if FileAccess.file_exists(path):
			found.append(path)
	found.sort_custom(func(a, b): return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b))
	return found


## "" when the file became the game's state; otherwise why it did not, with the game left as it was.
static func _read(path: String, game: Game) -> String:
	if game == null:
		return "no game"
	var got := _decode(path)
	if got.error != "":
		return got.error
	if not game.import_state(got.data):
		return game.load_error
	return ""


static func _decode(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "missing", "data": {}}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"error": "open: " + error_string(FileAccess.get_open_error()), "data": {}}
	if f.get_length() < 8 or int(f.get_32()) + 4 != f.get_length():
		f.close()
		return {"error": "truncated", "data": {}}
	f.seek(0)
	var data = f.get_var(false)
	var err := f.get_error()
	f.close()
	if err != OK and err != ERR_FILE_EOF:
		return {"error": "read: " + error_string(err), "data": {}}
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "not a save", "data": {}}
	return {"error": "", "data": data}
