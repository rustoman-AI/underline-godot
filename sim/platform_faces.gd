class_name PlatformFaces
extends RefCounted

## P88 Platform Faces. Text plus a saved memory dict. Balance ZERO.
## No food, mats, hope, air, tokens, opinion, sympathy, or loyalty deltas.
## No check changes. No rng / net_rng / story_rng / check_rng / crunch_rng draws.
## Nothing in the sim reads `regulars` for an outcome. Bots never open Visit.
## Soft dawn: none. Map mark: none. `regular.first` is a P61 first-float, not a dawn chip.
## P89 speaks through slot #5 (`sday.*`). P90 (`carry.*`) stays an empty hook. No reward numbers.

const SEEN := "seen_regulars"
## Gate flips this off to prove the hooks do not move a careful run. The game leaves it on.
static var enabled := true

static var _loaded := false
static var _fem := {}
static var _ids: PackedStringArray = PackedStringArray()


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func map_mark() -> bool:
	return false


## Reserved for P90 Carried Word. Slot 1. Empty until that pack lands.
static func carry_hook(_game, _sid: String) -> Dictionary:
	return {}


## P89 Station Days. Slot 5. Empty once the two-week window has passed.
static func station_day_hook(game, sid: String) -> Dictionary:
	return StationDays.face_line(game, sid)


static func face_ids() -> PackedStringArray:
	_load()
	return _ids


static func is_fem(sid: String) -> bool:
	_load()
	return bool(_fem.get(str(sid), false))


static func has_face(game, sid: String) -> bool:
	if game == null or str(sid) == "":
		return false
	if str(sid) == str(game.capital_id):
		return false
	_load()
	if not _ids.has(str(sid)):
		return false
	if game.stations.has(sid):
		var st: Dictionary = game.stations[sid]
		if bool(st.get("hidden", false)):
			return false
		if str(st.get("bunker", "")) != "" or str(st.get("owner", "")) == "bunker":
			return false
		if str(st.get("lean", "")) == "bunker":
			return false
	return true


static func memory(game, sid: String) -> Dictionary:
	var blank := {"met": 0, "last_kind": "", "last_week": 0, "taken": false}
	if game == null or not (game.get("regulars") is Dictionary):
		return blank
	var raw = game.regulars.get(str(sid), null)
	if not (raw is Dictionary):
		return blank
	return {
		"met": int(raw.get("met", 0)),
		"last_kind": str(raw.get("last_kind", "")),
		"last_week": int(raw.get("last_week", 0)),
		"taken": bool(raw.get("taken", false)),
	}


## First Visit of a known station. Returns true the week the Face is met.
static func meet(game, sid: String) -> bool:
	if not enabled or not has_face(game, sid):
		return false
	if not game.stations.has(sid) or not bool(game.stations[sid].get("known", false)):
		return false
	var row := _ensure(game, sid)
	if int(row.get("met", 0)) > 0:
		return false
	row.met = int(game.week)
	return true


## After a resolved order whose target is this station. Writes memory only.
static func note_order(game, action: Dictionary) -> void:
	if not enabled or game == null:
		return
	var sid := order_sid(action)
	if sid == "" or not has_face(game, sid):
		return
	if not game.stations.has(sid) or not bool(game.stations[sid].get("known", false)):
		return
	var row := _ensure(game, sid)
	if int(row.get("met", 0)) <= 0:
		row.met = int(game.week)
	row.last_kind = str(action.get("order", ""))
	row.last_week = int(game.week)


## After `_capture` changes the owner. `taken` is only a player force capture.
static func note_capture(game, sid: String, fid: String, force: bool) -> void:
	if not enabled or game == null or not has_face(game, sid):
		return
	var row := _ensure(game, sid)
	row.taken = force and str(fid) == str(game.player)


static func order_sid(action: Dictionary) -> String:
	var kind := str(action.get("order", ""))
	match kind:
		"envoy", "aid", "propaganda", "trade":
			return str(action.get("station", ""))
		"probe":
			var probe := str(action.get("station", ""))
			if probe == "":
				probe = str(action.get("dest", ""))
			return probe
		"patrol", "raid", "assault":
			var dest := str(action.get("dest", ""))
			if dest == "":
				dest = str(action.get("station", ""))
			return dest
		_:
			return ""


## One line, cap 1. `greet` is the P87 greet cached for this Visit (possibly empty).
static func line(game, sid: String) -> Dictionary:
	if not _showing(game, sid):
		return {}
	return _pick(game, sid, MarksKit.greet(game, sid))


static func line_cached(game, sid: String, greet: Dictionary) -> Dictionary:
	if not _showing(game, sid):
		return {}
	return _pick(game, sid, greet)


static func render(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	var fields = row.get("fields", {})
	if not (fields is Dictionary):
		fields = {}
	return Copy.fill(str(row.get("key", "")), fields)


## Met Faces only. Gone and rival use their band words; everyone else uses `_band_key`.
static func list_rows(game) -> Array:
	var out: Array = []
	if game == null:
		return out
	for sid in face_ids():
		if not has_face(game, sid):
			continue
		if int(memory(game, sid).get("met", 0)) <= 0:
			continue
		if not game.stations.has(sid):
			continue
		var st: Dictionary = game.stations[sid]
		var state := list_state(game, sid)
		var band := "regular.band_gone" if state == "gone" else ("regular.band_rival" if state == "rival" else relation_key(st))
		out.append({
			"sid": sid,
			"name_key": "regular.%s.name" % sid,
			"station": str(st.get("name", sid)),
			"band_key": band,
			"muted": state == "gone" or state == "rival",
		})
	return out


static func met_count(game) -> int:
	return list_rows(game).size()


static func face_total(game) -> int:
	var n := 0
	for sid in face_ids():
		if has_face(game, sid):
			n += 1
	return n


static func list_state(game, sid: String) -> String:
	if _gone(game, sid):
		return "gone"
	if _rival(game, sid):
		return "rival"
	return "band"


static func relation_key(st: Dictionary) -> String:
	var sympathy := int(st.get("sympathy", 0))
	if sympathy >= 100:
		return "map.relation_band_join"
	if sympathy >= 70:
		return "map.relation_band_ready"
	if sympathy >= 50:
		return "map.relation_band_warm"
	if sympathy >= 20:
		return "map.relation_band_wary"
	return "map.relation_band_cold"


## First Face met this run. Sets `flags.seen_regulars`. Not a dawn chip.
static func claim_first(game) -> String:
	if not enabled or game == null:
		return ""
	if bool(game.flags.get(SEEN, false)):
		return ""
	var any := false
	if game.get("regulars") is Dictionary:
		for sid in game.regulars:
			var raw = game.regulars[sid]
			if raw is Dictionary and int(raw.get("met", 0)) > 0:
				any = true
				break
	if not any:
		return ""
	game.flags[SEEN] = true
	return Copy.t("regular.first")


static func _showing(game, sid: String) -> bool:
	return enabled and has_face(game, sid) and int(memory(game, sid).get("met", 0)) > 0


static func _pick(game, sid: String, greet: Dictionary) -> Dictionary:
	var st: Dictionary = game.stations[sid]
	var carry := carry_hook(game, sid)
	if _hook_key(carry, "carry."):
		return _hook_row(carry, 1)
	if _gone(game, sid):
		return _row("regular.gone", {"name": Copy.t("regular.%s.name" % sid), "fem": is_fem(sid)}, 2)
	if _rival(game, sid):
		return _row("regular.rival", {
			"name": Copy.t("regular.%s.name" % sid),
			"faction": faction_label(game, str(st.get("owner", ""))),
		}, 3)
	var mem := memory(game, sid)
	var last_week := int(mem.get("last_week", 0))
	if last_week > 0 and last_week >= int(game.week) - 1:
		var after := _after_key(str(mem.get("last_kind", "")))
		if after != "" and _has_key(after):
			return _row(after, {}, 4)
	var day := station_day_hook(game, sid)
	if _hook_key(day, "sday."):
		return _hook_row(day, 5)
	var greet_key := str(greet.get("key", ""))
	if greet_key.begins_with("obs.greet."):
		var spoken := _row(greet_key, {}, 6)
		spoken["greet_kind"] = str(greet.get("kind", ""))
		spoken["greet_id"] = str(greet.get("id", ""))
		return spoken
	var dead := _dead_name(game, sid)
	if dead != "":
		return _row("regular.your_dead", {"dead": dead}, 7)
	var band := "cold"
	if str(st.get("owner", "")) == str(game.player):
		band = "held"
	elif int(st.get("sympathy", 0)) >= 50:
		band = "warm"
	return _row("regular.%s.%s" % [sid, band], {}, 8)


static func _gone(game, sid: String) -> bool:
	if not bool(memory(game, sid).get("taken", false)):
		return false
	return str(game.stations[sid].get("owner", "")) == str(game.player)


static func _rival(game, sid: String) -> bool:
	var owner := str(game.stations[sid].get("owner", ""))
	if owner == "" or owner == str(game.player) or owner == "neutral" or owner == "bunker" or owner == "ruin":
		return false
	var journal: Array = game.journal if game.get("journal") is Array else []
	for i in range(journal.size() - 1, -1, -1):
		var entry = journal[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("kind", "")) != "station" or str(entry.get("station", "")) != str(sid):
			continue
		return str(entry.get("to", "")) == owner
	return false


static func _dead_name(game, sid: String) -> String:
	var place := str(game.stations[sid].get("name", ""))
	var found := ""
	var rows: Array = game.departed if game.get("departed") is Array else []
	for entry in rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("how", "")) != "died":
			continue
		if str(entry.get("place", "")) != place:
			continue
		found = str(entry.get("name", ""))
		if Copy.ru() and str(entry.get("name_ru", "")) != "":
			found = str(entry.get("name_ru"))
	return found


static func faction_label(game, fid: String) -> String:
	if game != null and game.catalog != null and game.catalog.factions.has(fid):
		return Copy.t(str(game.catalog.factions[fid].get("name", fid)))
	if fid == "enemy":
		return Copy.t("Enemy")
	return Copy.t(fid)


static func _after_key(kind: String) -> String:
	match kind:
		"trade":
			return "regular.after_deal"
		"raid", "assault":
			return "regular.after_raid"
		"envoy", "aid", "propaganda", "probe", "patrol":
			return "regular.after_%s" % kind
		_:
			return ""


static func _hook_key(row: Dictionary, prefix: String) -> bool:
	return not row.is_empty() and str(row.get("key", "")).begins_with(prefix)


static func _hook_row(row: Dictionary, slot: int) -> Dictionary:
	var fields = row.get("fields", {})
	if not (fields is Dictionary):
		fields = {}
	var out := _row(str(row.get("key", "")), fields, slot)
	if row.has("button"):
		out["button"] = str(row.get("button", ""))
	return out


static func _row(key: String, fields: Dictionary, slot: int) -> Dictionary:
	return {"key": key, "fields": fields, "slot": slot}


static func _has_key(key: String) -> bool:
	Copy.boot()
	return Copy.keys.has(key)


static func _ensure(game, sid: String) -> Dictionary:
	if not (game.regulars is Dictionary):
		game.regulars = {}
	var cur = game.regulars.get(sid, null)
	if cur is Dictionary:
		if not cur.has("met"):
			cur.met = 0
		if not cur.has("last_kind"):
			cur.last_kind = ""
		if not cur.has("last_week"):
			cur.last_week = 0
		if not cur.has("taken"):
			cur.taken = false
		return cur
	var row := {"met": 0, "last_kind": "", "last_week": 0, "taken": false}
	game.regulars[sid] = row
	return row


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_fem = {}
	_ids = PackedStringArray()
	if not FileAccess.file_exists("res://data/platform_faces.json"):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/platform_faces.json"))
	if not (data is Dictionary):
		return
	var faces = data.get("_faces", {})
	if not (faces is Dictionary):
		return
	var keys: Array = faces.keys()
	keys.sort()
	for sid in keys:
		_ids.append(str(sid))
		var row = faces[sid]
		_fem[str(sid)] = bool(row.get("fem", false)) if row is Dictionary else false
