class_name CarriedWord
extends RefCounted

## P90 Carried Word. A folded note between two Faces. Balance ZERO.
## No resource, standing, sympathy, or check changes.
## No random draws. Nothing in the sim reads `carry` for an outcome. Bots never take a note.
## Soft dawn: none. Map mark: none. `carry.first` is a P61 first-float, not a dawn chip.
## The parked delivery reward stays an unused 0 in data. This script never reads it.

const SEEN := "seen_carried_word"
const DELIVER_KINDS := ["envoy", "trade", "aid", "propaganda", "focus", "move"]
## Gate flips this off to prove the hooks do not move a careful run. The game leaves it on.
static var enabled := true

static var _loaded := false
static var _order: Array = []
static var _by_id := {}
static var _places := {}
## Undo window for Open it. Not saved: a reload keeps the note sealed.
static var _pending := {}


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func map_mark() -> bool:
	return false


static func threads() -> Array:
	_load()
	return _order.duplicate(true)


## Slot #1 on the Face row. Empty when this Face has nothing to say for the pack.
static func face_line(game, sid: String) -> Dictionary:
	if not _live(game) or str(sid) == "":
		return {}
	if int(PlatformFaces.memory(game, sid).get("met", 0)) <= 0:
		return {}
	var reply := _reply_row(game, sid)
	if not reply.is_empty():
		return reply
	var linger := _linger_row(game, sid)
	if not linger.is_empty():
		return linger
	return _offer_row(game, sid)


## The actionable offer only. End lines stay on `face_line`.
static func offer(game, sid: String) -> Dictionary:
	if not _live(game):
		return {}
	var reply := _reply_row(game, sid)
	if not reply.is_empty():
		return reply
	return _offer_row(game, sid)


static func take(game, sid: String) -> bool:
	if not _live(game) or not _pocket(game).is_empty():
		return false
	var row := offer(game, sid)
	var button := str(row.get("button", ""))
	if button != "carry.take" and button != "carry.take_reply":
		return false
	var id := str(row.get("thread", ""))
	var spec := _spec(id)
	if spec.is_empty():
		return false
	var leg := 2 if button == "carry.take_reply" else 1
	var bag := _ensure(game)
	bag["pocket"] = {"thread": id, "leg": leg, "opened": false, "week": int(game.week)}
	_pending.erase(game.get_instance_id())
	return true


## Pocket empties. The thread is not started again, so it can be offered later.
static func give_back(game) -> String:
	if not _live(game):
		return ""
	var pocket := _pocket(game)
	if pocket.is_empty():
		return ""
	var from_name := _person(str(_ends(pocket).get("writer", "")), Copy.ru())
	var id := str(pocket.get("thread", ""))
	var bag := _ensure(game)
	var threads: Dictionary = bag.get("threads", {})
	threads.erase(id)
	bag["threads"] = threads
	bag["pocket"] = {}
	_pending.erase(game.get_instance_id())
	return from_name


## Starts the undo window. The text stays hidden until `commit_open`.
static func open(game) -> bool:
	if not _live(game):
		return false
	var pocket := _pocket(game)
	if pocket.is_empty() or bool(pocket.get("opened", false)):
		return false
	_pending[game.get_instance_id()] = true
	return true


static func cancel_open(game) -> void:
	if game == null:
		return
	_pending.erase(game.get_instance_id())


## Toast lapsed. The leg is open and the text may show.
static func commit_open(game) -> bool:
	if game == null:
		return false
	var armed := pending_open(game)
	_pending.erase(game.get_instance_id())
	if not armed or not _live(game):
		return false
	var pocket := _pocket(game)
	if pocket.is_empty():
		return false
	pocket["opened"] = true
	return true


static func pending_open(game) -> bool:
	if game == null:
		return false
	return bool(_pending.get(game.get_instance_id(), false))


## Report line for a resolved order, or "" when the note stays in the pocket.
static func on_order(game, kind: String, sid: String, who: String = "", fem: bool = false) -> String:
	var named := Copy.person(who) if who != "" else ""
	var both := _deliver(game, kind, sid, named, fem, false)
	if both.is_empty():
		return ""
	return str(both.ru) if Copy.ru() else str(both.en)


## A Night Run whose site station is the note's destination. Caller promises a runner came home.
static func on_night_run(game, site) -> Dictionary:
	var sid := ""
	if site is Dictionary:
		sid = str(site.get("station", ""))
	else:
		sid = str(site)
	return _deliver(game, "run", sid, "", false, true)


static func tip_line(game, sid: String) -> String:
	if not _live(game) or str(sid) == "":
		return ""
	var pocket := _pocket(game)
	if pocket.is_empty():
		return ""
	var dest := str(_ends(pocket).get("dest", ""))
	if dest != str(sid) or _force_taken(game, dest):
		return ""
	var reader := str(_ends(pocket).get("reader", ""))
	return Copy.fill("carry.tip_dest", {"to": _person(reader, Copy.ru())})


static func target_sid(kind: String, action: Dictionary) -> String:
	match kind:
		"move", "patrol", "raid", "assault":
			var dest := str(action.get("dest", ""))
			if dest == "":
				dest = str(action.get("station", ""))
			return dest
		"probe":
			var probe := str(action.get("station", ""))
			if probe == "":
				probe = str(action.get("dest", ""))
			return probe
		"tap":
			return ""
		_:
			return str(action.get("station", action.get("dest", "")))


## First note taken this run. Sets `flags.seen_carried_word`. Not a dawn chip.
static func claim_first(game) -> String:
	if not _live(game):
		return ""
	if bool(game.flags.get(SEEN, false)):
		return ""
	if _pocket(game).is_empty():
		return ""
	game.flags[SEEN] = true
	return Copy.t("carry.first")


static func pocket_view(game) -> Dictionary:
	var view := {
		"empty": true,
		"line": "",
		"text": "",
		"no_one": false,
		"opened": false,
		"pending": false,
		"can_open": false,
		"from": "",
	}
	if not _live(game):
		return view
	var pocket := _pocket(game)
	if pocket.is_empty():
		return view
	var ends := _ends(pocket)
	var writer := str(ends.get("writer", ""))
	var reader := str(ends.get("reader", ""))
	var dest := str(ends.get("dest", ""))
	var opened := bool(pocket.get("opened", false))
	var pending := pending_open(game)
	view.empty = false
	view.opened = opened
	view.pending = pending
	view.can_open = not opened and not pending
	view.no_one = _force_taken(game, dest)
	view.from = _person(writer, Copy.ru())
	view.line = Copy.fill("carry.pocket", {
		"from": view.from,
		"to": _person(reader, Copy.ru()),
		"station": _place(dest, "ru" if Copy.ru() else "en"),
	})
	if opened and not pending:
		var part := "reply_read" if int(pocket.get("leg", 1)) == 2 else "read"
		view.text = Copy.t("carry.%s.%s" % [str(pocket.get("thread", "")), part])
	return view


static func tally(game) -> Dictionary:
	var closed: Array = []
	var opened: Array = []
	var n := 0
	if _live(game):
		n = int(game.carry.get("delivered", 0))
		var threads: Dictionary = game.carry.get("threads", {})
		if threads is Dictionary:
			for spec in threads():
				var id := str(spec.get("id", ""))
				var state := str(threads.get(id, ""))
				if state == "closed":
					closed.append(id)
				elif state == "opened":
					opened.append(id)
	return {"n": n, "closed": closed, "opened": opened}


static func _deliver(game, kind: String, sid: String, who: String, fem: bool, run: bool) -> Dictionary:
	if not _live(game):
		return {}
	var pocket := _pocket(game)
	if pocket.is_empty():
		return {}
	if not run and not DELIVER_KINDS.has(kind):
		return {}
	if kind == "trade" and str(sid) == "":
		return {}
	var ends := _ends(pocket)
	var dest := str(ends.get("dest", ""))
	if str(sid) == "" or str(sid) != dest:
		return {}
	if _force_taken(game, dest):
		return {}
	if (kind == "focus" or kind == "move") and not _owned(game, dest):
		return {}
	var id := str(pocket.get("thread", ""))
	var leg := int(pocket.get("leg", 1))
	var was_open := bool(pocket.get("opened", false))
	var spec := _spec(id)
	var origin := str(spec.get("from", ""))
	var far := str(spec.get("to", ""))
	var bag := _ensure(game)
	bag["delivered"] = int(bag.get("delivered", 0)) + 1
	bag["pocket"] = {}
	_pending.erase(game.get_instance_id())
	var threads: Dictionary = bag.get("threads", {})
	if leg == 1 and not was_open:
		threads[id] = "leg1_done"
	elif leg == 1 and was_open:
		threads[id] = "opened"
		_remember(game, far, "carry.%s.opened" % id, id)
		_remember(game, origin, "carry.origin_opened", id)
	elif leg == 2 and not was_open:
		threads[id] = "closed"
		_remember(game, origin, "carry.%s.closed" % id, id)
	else:
		threads[id] = "opened"
		_remember(game, origin, "carry.%s.opened" % id, id)
	bag["threads"] = threads
	var reader := str(ends.get("reader", ""))
	var vars_en := {
		"who": who,
		"to": _person(reader, false),
		"station": _place(dest, "en"),
		"fem": fem,
	}
	var vars_ru := {
		"who": who,
		"to": _person(reader, true),
		"station": _place(dest, "ru"),
		"fem": fem,
	}
	var key := "carry.delivered_run" if run else "carry.delivered_report"
	return _both(key, vars_en, vars_ru, fem)


static func _offer_row(game, sid: String) -> Dictionary:
	for spec in threads():
		if str(spec.get("from", "")) != str(sid):
			continue
		var id := str(spec.get("id", ""))
		if _started(game, id):
			continue
		if not _origin_ready(game, sid):
			continue
		if not _dest_ready(game, str(spec.get("to", ""))):
			continue
		return _button_row(game, "carry.%s.offer" % id, "carry.take", id)
	return {}


static func _reply_row(game, sid: String) -> Dictionary:
	var threads: Dictionary = game.carry.get("threads", {})
	if not (threads is Dictionary):
		return {}
	for spec in threads():
		if str(spec.get("to", "")) != str(sid):
			continue
		var id := str(spec.get("id", ""))
		if str(threads.get(id, "")) != "leg1_done":
			continue
		if _in_pocket(game, id):
			continue
		if _force_taken(game, sid):
			continue
		return _button_row(game, "carry.%s.delivered" % id, "carry.take_reply", id)
	return {}


static func _linger_row(game, sid: String) -> Dictionary:
	var lines = game.carry.get("lines", [])
	if not (lines is Array):
		return {}
	var found := {}
	for row in lines:
		if not (row is Dictionary):
			continue
		if str(row.get("sid", "")) != str(sid):
			continue
		if int(row.get("until", 0)) < int(game.week):
			continue
		found = {"key": str(row.get("key", "")), "fields": {}, "thread": str(row.get("thread", ""))}
	return found


static func _button_row(game, key: String, button: String, id: String) -> Dictionary:
	var row := {"key": key, "fields": {}, "thread": id}
	if _pocket(game).is_empty():
		row["button"] = button
	else:
		row["muted"] = true
		row["reason"] = "carry.one_only"
	return row


static func _remember(game, sid: String, key: String, id: String) -> void:
	if str(sid) == "" or str(key) == "":
		return
	var bag := _ensure(game)
	var lines: Array = []
	for row in bag.get("lines", []):
		if row is Dictionary and str(row.get("sid", "")) == str(sid) and str(row.get("thread", "")) == str(id):
			continue
		lines.append(row)
	lines.append({"sid": str(sid), "key": key, "until": int(game.week) + 1, "thread": str(id)})
	bag["lines"] = lines


static func _started(game, id: String) -> bool:
	if _in_pocket(game, id):
		return true
	var threads: Dictionary = game.carry.get("threads", {})
	if not (threads is Dictionary):
		return false
	return str(threads.get(id, "")) != ""


static func _in_pocket(game, id: String) -> bool:
	var pocket := _pocket(game)
	return not pocket.is_empty() and str(pocket.get("thread", "")) == str(id)


static func _origin_ready(game, sid: String) -> bool:
	if not game.stations.has(sid):
		return false
	var st: Dictionary = game.stations[sid]
	if int(st.get("sympathy", 0)) >= 50:
		return true
	return _owned(game, sid) and not _force_taken(game, sid)


static func _dest_ready(game, sid: String) -> bool:
	if str(sid) == "" or not game.stations.has(sid):
		return false
	var st: Dictionary = game.stations[sid]
	if not bool(st.get("known", false)) or bool(st.get("hidden", false)):
		return false
	if _force_taken(game, sid):
		return false
	return true


static func _owned(game, sid: String) -> bool:
	if not game.stations.has(sid):
		return false
	return str(game.stations[sid].get("owner", "")) == str(game.player)


static func _force_taken(game, sid: String) -> bool:
	return bool(PlatformFaces.memory(game, sid).get("taken", false))


static func _ends(pocket: Dictionary) -> Dictionary:
	var spec := _spec(str(pocket.get("thread", "")))
	var origin := str(spec.get("from", ""))
	var far := str(spec.get("to", ""))
	if int(pocket.get("leg", 1)) == 2:
		return {"writer": far, "reader": origin, "dest": origin}
	return {"writer": origin, "reader": far, "dest": far}


static func _spec(id: String) -> Dictionary:
	_load()
	var row = _by_id.get(str(id), {})
	return row if row is Dictionary else {}


static func _person(sid: String, ru: bool) -> String:
	var pack := Copy.pack("regular.%s.name" % str(sid))
	if ru and str(pack.get("ru", "")) != "":
		return str(pack.ru)
	var en := str(pack.get("en", ""))
	return en if en != "" else str(sid)


static func _place(sid: String, lang: String) -> String:
	_load()
	var row = _places.get(str(sid), {})
	if not (row is Dictionary):
		return str(sid)
	if lang == "ru" and str(row.get("ru", "")) != "":
		return str(row.ru)
	var en := str(row.get("en", ""))
	return en if en != "" else str(sid)


static func _both(key: String, vars_en: Dictionary, vars_ru: Dictionary, fem: bool) -> Dictionary:
	var pack := Copy.pack(key)
	return {
		"en": _apply(str(pack.get("en", "")), vars_en, fem),
		"ru": _apply(str(pack.get("ru", "")), vars_ru, fem),
	}


static func _apply(template: String, vars: Dictionary, fem: bool) -> String:
	var line := template
	for token in vars:
		if str(token) == "fem":
			continue
		line = line.replace("{%s}" % str(token), str(vars[token]))
	return line.replace("{a}", "а" if fem else "").replace("{ee}", "")


static func _pocket(game) -> Dictionary:
	if game == null or not (game.get("carry") is Dictionary):
		return {}
	var pocket = game.carry.get("pocket", {})
	if not (pocket is Dictionary) or str(pocket.get("thread", "")) == "":
		return {}
	return pocket


static func _live(game) -> bool:
	return enabled and game != null and game.get("carry") is Dictionary


static func _ensure(game) -> Dictionary:
	if not (game.carry is Dictionary):
		game.carry = {"pocket": {}, "threads": {}, "delivered": 0, "lines": []}
	var bag: Dictionary = game.carry
	if not (bag.get("pocket") is Dictionary):
		bag["pocket"] = {}
	if not (bag.get("threads") is Dictionary):
		bag["threads"] = {}
	if not (bag.get("lines") is Array):
		bag["lines"] = []
	return bag


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_order = []
	_by_id = {}
	_places = {}
	if FileAccess.file_exists("res://data/carried_word.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/carried_word.json"))
		if data is Dictionary:
			var rows = data.get("_threads", [])
			if rows is Array:
				for row in rows:
					if not (row is Dictionary):
						continue
					var id := str(row.get("id", ""))
					if id == "":
						continue
					var spec := {"id": id, "from": str(row.get("from", "")), "to": str(row.get("to", ""))}
					_order.append(spec)
					_by_id[id] = spec
	if FileAccess.file_exists("res://data/platform_faces.json"):
		var faces_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/platform_faces.json"))
		if faces_data is Dictionary:
			var faces = faces_data.get("_faces", {})
			if faces is Dictionary:
				for sid in faces:
					var face = faces[sid]
					if face is Dictionary:
						_places[str(sid)] = {"en": str(face.get("station", "")), "ru": str(face.get("station_ru", ""))}
