extends SceneTree

## Save fuzz: mutates mid-run saves kept by the soak (build/soak/saves/) and loads each one.
## Every case must either load and then play three weeks without script errors or invariant errors,
## or be refused with a load_error while the live game and the player's slot stay exactly as they were.
##   godot --headless --path . -s res://.tools/save_fuzz.gd -- --saves=50
## Writes build/soak/fuzz.json; works only under user://fuzz_<pid>/.

const SAVES := "res://build/soak/saves"
const PLAY := 3

var catalog: Catalog
var caught: Array = []
var rng := RandomNumberGenerator.new()


class Catch extends Logger:
	var sink: Callable

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		sink.call("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _init() -> void:
	Copy.set_lang("en")
	var limit := 50
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--saves="):
			limit = int(str(arg).get_slice("=", 1))
	catalog = Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	var logger := Catch.new()
	logger.sink = func(text: String) -> void: caught.append(text)
	OS.add_logger(logger)
	var files: Array = []
	for file in DirAccess.get_files_at(SAVES):
		if file.ends_with(".sav"):
			files.append(file)
	files.sort()
	files = files.slice(0, limit)
	SaveGame.root = "user://fuzz_%d" % OS.get_process_id()
	var rows: Array = []
	var tally := {}
	for file in files:
		var raw := FileAccess.get_file_as_bytes(SAVES.path_join(file))
		var data = bytes_to_var(raw.slice(4))
		if not data is Dictionary:
			print("SKIP %s not a save" % file)
			continue
		rng.seed = hash(file)
		for c in _cases(data, raw):
			var row := _try(file, c)
			rows.append(row)
			tally[row.result] = int(tally.get(row.result, 0)) + 1
	_wipe(SaveGame.root)
	SaveGame.root = "user://"
	var out := FileAccess.open("res://build/soak/fuzz.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"saves": files.size(), "cases": rows.size(), "tally": tally, "rows": rows}, "\t"))
	out.close()
	var bad := 0
	for row in rows:
		if not ["loaded", "refused", "refused_noisy"].has(row.result):
			bad += 1
			if bad <= 40:
				print("BAD %s %s %s: %s" % [row.save, row.case, row.result, row.detail])
	print("FUZZ saves %d cases %d %s bad %d" % [files.size(), rows.size(), str(tally), bad])
	quit(1 if bad > 0 else 0)


## Each case is {"name", "bytes"}: the file as it would sit on disk.
func _cases(data: Dictionary, raw: PackedByteArray) -> Array:
	var out: Array = []
	var keys: Array = data.keys()
	for i in 3:
		var key = keys[rng.randi_range(0, keys.size() - 1)]
		out.append(_mut("drop %s" % key, data, func(d): d.erase(key)))
	for i in 4:
		var spot := _spot(data)
		if not spot.is_empty():
			out.append(_mut("drop %s" % spot.path, data, func(d): _at(d, spot.trail).erase(spot.key)))
	var odd := ["text", 7, 2.5, [], {}, null, true]
	for i in 3:
		var key = keys[rng.randi_range(0, keys.size() - 1)]
		var value = odd[rng.randi_range(0, odd.size() - 1)]
		if typeof(value) != typeof(data[key]):
			out.append(_mut("type %s = %s" % [key, type_string(typeof(value))], data, func(d): d[key] = value))
	for i in 5:
		var spot := _spot(data)
		var value = odd[rng.randi_range(0, odd.size() - 1)]
		if not spot.is_empty():
			out.append(_mut("type %s = %s" % [spot.path, type_string(typeof(value))], data, func(d): _at(d, spot.trail)[spot.key] = value))
	for week in [0, -3, int(data.max_weeks) + 1, 2147483647]:
		out.append(_mut("week %d" % week, data, func(d): d.week = week))
	out.append(_mut("max_weeks 0", data, func(d): d.max_weeks = 0))
	out.append(_mut("unknown player", data, func(d): d.player = "nobody"))
	out.append(_mut("unknown capital", data, func(d): d.capital_id = "st_nowhere"))
	out.append(_mut("unknown room type", data, func(d): d.rooms[0].type = "ballroom"))
	out.append(_mut("unknown staff", data, func(d): d.rooms[0].staff.append("p_nobody")))
	out.append(_mut("unknown council seat", data, func(d): d.council.append({"id": "p_nobody", "role": "nobody"})))
	out.append(_mut("unknown audience leader", data, func(d): d.audience = {"faction": "nobody", "week": int(d.week), "target": ""}))
	out.append(_mut("unknown standing leader", data, func(d): d.standing["nobody"] = 10))
	out.append(_mut("unknown law", data, func(d): d.laws_on["no_such_law"] = true))
	out.append(_mut("unknown pending event", data, func(d): d.pending.append({"id": "no_such_event", "title": "x", "text": "x", "choices": []})))
	out.append(_mut("unknown check event", data, func(d): d.check_schedule.append({"id": "no_such_check", "week": int(d.week), "done": false})))
	out.append(_mut("unknown station", data, func(d): d.stations["st_nowhere"] = d.stations[d.stations.keys()[0]].duplicate(true)))
	out.append(_mut("person key differs from id", data, func(d): _rekey_person(d)))
	out.append(_mut("duplicated resident", data, func(d): d.residents.append(d.residents[0].duplicate(true))))
	out.append(_mut("resident twice in people", data, func(d): _twin_person(d)))
	out.append(_mut("same resident in two rooms", data, func(d): _two_rooms(d)))
	out.append(_mut("negative stock", data, func(d): d.stock[d.stock.keys()[0]] = -50))
	out.append(_mut("huge name", data, func(d): d.people[d.people.keys()[0]].name = "N".repeat(1 << 20)))
	out.append(_mut("huge log", data, func(d): d.log.append({"week": int(d.week), "text": "L".repeat(1 << 20), "important": true})))
	out.append(_mut("huge key", data, func(d): d["K".repeat(1 << 16)] = 1))
	out.append(_mut("extra key", data, func(d): d["from_the_future"] = {"a": 1}))
	out.append(_mut("schema 99", data, func(d): d.schema = 99))
	for cut in [0.25, 0.5, 0.97]:
		out.append({"name": "truncated %d%%" % int(cut * 100), "bytes": raw.slice(0, int(raw.size() * cut))})
	out.append({"name": "truncated by one", "bytes": raw.slice(0, raw.size() - 1)})
	out.append({"name": "empty file", "bytes": PackedByteArray()})
	for i in 3:
		var flipped := raw.duplicate()
		var at := rng.randi_range(8, flipped.size() - 1)
		flipped[at] = flipped[at] ^ 0xFF
		out.append({"name": "byte %d flipped" % at, "bytes": flipped})
	return out


func _mut(name: String, data: Dictionary, change: Callable) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	change.call(d)
	var bytes := var_to_bytes(d)
	var head := PackedByteArray()
	head.resize(4)
	head.encode_u32(0, bytes.size())
	return {"name": name, "bytes": head + bytes}


## A random key inside the state below the top level, as a path from the top.
func _spot(data: Dictionary) -> Dictionary:
	var pool: Array = []
	for key in ["people", "rooms", "stock", "dig", "build", "council", "audience", "stations", "check_schedule", "pending", "artifacts", "leader_answers", "fragments"]:
		if data.has(key):
			_collect(data[key], [key], pool, 0)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]


func _collect(value, trail: Array, pool: Array, depth: int) -> void:
	if depth > 3:
		return
	if value is Dictionary:
		for k in value:
			pool.append({"trail": trail.duplicate(), "key": k, "path": ".".join(PackedStringArray(trail.map(func(x): return str(x)))) + "." + str(k)})
			_collect(value[k], trail + [k], pool, depth + 1)
	elif value is Array:
		for i in mini(value.size(), 3):
			_collect(value[i], trail + [i], pool, depth + 1)


func _at(d, trail: Array):
	var node = d
	for step in trail:
		node = node[step]
	return node


func _rekey_person(d: Dictionary) -> void:
	var id = d.people.keys()[0]
	d.people["p_elsewhere"] = d.people[id]
	d.people.erase(id)


func _twin_person(d: Dictionary) -> void:
	var person: Dictionary = d.residents[0].duplicate(true)
	person.id = "p_twin"
	d.people["p_twin"] = person
	d.residents.append(person)
	d.residents.append(person.duplicate(true))


func _two_rooms(d: Dictionary) -> void:
	var id := str(d.residents[0].id)
	var n := 0
	for room in d.rooms:
		if int(catalog.rooms.get(str(room.type), {}).get("staff_max", 0)) > 0 and n < 2:
			room.staff.append(id)
			n += 1


func _try(save: String, c: Dictionary) -> Dictionary:
	_wipe(SaveGame.root)
	DirAccess.make_dir_recursive_absolute(SaveGame.root)
	var slot := Game.new()
	slot.setup(catalog, 7, 40)
	slot.end_week()
	SaveGame.write_auto(slot)
	var slot_md5 := FileAccess.get_md5(SaveGame.auto_path())
	var f := FileAccess.open(SaveGame.manual_path(), FileAccess.WRITE)
	f.store_buffer(c.bytes)
	f.close()
	var game := Game.new()
	game.setup(catalog, 11, 40)
	var before := var_to_bytes(game.export_state())
	caught.clear()
	var why := SaveGame._read(SaveGame.manual_path(), game)
	var row := {"save": save, "case": c.name, "result": "", "detail": why}
	if FileAccess.get_md5(SaveGame.auto_path()) != slot_md5:
		row.result = "slot_changed"
		return row
	var engine_only := not caught.is_empty() and caught.all(func(text): return not str(text).contains(".gd:"))
	if not caught.is_empty() and not (engine_only and why != ""):
		row.result = "error_on_load"
		row.detail = "%s [read: %s, %d errors]" % [str(caught[0]), why, caught.size()]
		return row
	if engine_only and why != "" and var_to_bytes(game.export_state()) == before:
		row.result = "refused_noisy"
		row.detail = "%s; engine logged: %s" % [why, str(caught[0])]
		return row
	if why != "":
		if var_to_bytes(game.export_state()) != before:
			row.result = "refused_but_changed"
		else:
			row.result = "refused"
		return row
	var bot := Bot.new()
	for i in PLAY:
		if game.over != "":
			break
		bot._act(game)
		game.end_week()
		if not caught.is_empty():
			row.result = "error_in_play"
			row.detail = "%s (week %d)" % [str(caught[0]), game.week]
			return row
	if not game.errors.is_empty():
		row.result = "invariant_in_play"
		row.detail = str(game.errors[0])
		return row
	if game.over == "" and not SaveGame.write_auto(game):
		row.result = "resave_failed"
		row.detail = SaveGame.last_error
		return row
	if not caught.is_empty():
		row.result = "error_in_play"
		row.detail = str(caught[0])
		return row
	row.result = "loaded"
	return row


func _wipe(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(dir_path)
