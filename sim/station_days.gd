class_name StationDays
extends RefCounted

## P89 Station Days. A fixed 8-week wheel plus a memory dict. Balance ZERO.
## No sympathy, opinion, need, stock, hope, cost, or odds change. No RNG.
## Bots never read days. Nothing else in sim/ reads `sdays`.
## Soft dawn: none. Map mark: none. `sday.first` is a P61 first-float, not a dawn chip.
## The parked sympathy bump stays unwired. No reward text and no reward control.

const PACK := "res://data/station_days.json"
const SEEN := "seen_station_days"
const SOON_WEEKS := 3
## Face slot #5 speaks on the day week and the week after (two weeks), then falls through.
const FACE_SPAN := 1

const SOFT := ["envoy", "trade", "aid", "propaganda", "focus"]
const HARD := ["probe", "patrol", "raid", "assault"]

## Gate flips this off to prove the hooks do not move a careful run. The game leaves it on.
static var enabled := true
## A first-float the map could not show. The yard plate speaks it once. Not saved.
static var held_float := ""

static var _loaded := false
static var _offset := {}


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func map_mark() -> bool:
	return false


static func ids() -> PackedStringArray:
	_load()
	var keys: Array = _offset.keys()
	keys.sort()
	var out := PackedStringArray()
	for sid in keys:
		out.append(str(sid))
	return out


static func offset_of(sid: String) -> int:
	_load()
	return int(_offset.get(str(sid), 0))


static func has_day(game, sid: String) -> bool:
	var offset := offset_of(sid)
	if offset < 1 or offset > 8:
		return false
	if game == null:
		return true
	if str(sid) == str(game.capital_id):
		return false
	if not game.stations.has(sid):
		return true
	var st: Dictionary = game.stations[sid]
	if bool(st.get("hidden", false)):
		return false
	if str(st.get("bunker", "")) != "" or str(st.get("owner", "")) == "bunker":
		return false
	if str(st.get("lean", "")) == "bunker":
		return false
	return true


static func day_week(game, sid: String) -> bool:
	if game == null:
		return false
	return _on_week(int(game.week), sid, int(game.max_weeks)) and has_day(game, sid)


## 0 on the day week. 99 when the next day is past the run, or the station has no day.
static func weeks_to(game, sid: String) -> int:
	if game == null or not has_day(game, sid):
		return 99
	var week := int(game.week)
	var max_w := int(game.max_weeks)
	var delta := _mod8(week - offset_of(sid))
	if delta == 0:
		return 0 if max_w <= 0 or week <= max_w else 99
	var ahead := 8 - delta
	if max_w > 0 and week + ahead > max_w:
		return 99
	return ahead


static func sid_of(action: Dictionary) -> String:
	var kind := str(action.get("order", ""))
	if kind == "focus":
		return str(action.get("station", ""))
	return PlatformFaces.order_sid(action)


## First qualifying order on a day week. `at_week` is the week the order was given.
## Queued orders resolve after the week counter has already moved, so the caller passes that earlier week.
## Returns the report sentence, or "" when the order does not decide the day.
static func on_order(game, kind: String, sid: String, at_week: int = -1) -> String:
	if not enabled or game == null or sid == "":
		return ""
	if not has_day(game, sid) or not _known(game, sid):
		return ""
	var w := int(game.week) if at_week < 0 else at_week
	if not _on_week(w, sid, int(game.max_weeks)):
		return ""
	if _has_week(game, sid, w):
		return ""
	var quiet_at := _quiet_week(game, sid)
	if quiet_at > 0 and quiet_at < w:
		return ""
	if quiet_at == w and not HARD.has(kind):
		return ""
	var mode := ""
	if SOFT.has(kind):
		if kind == "focus" and str(game.stations[sid].get("owner", "")) != str(game.player):
			return ""
		if quiet_at == w:
			return ""
		mode = "kept"
	elif HARD.has(kind):
		mode = "intruded"
	else:
		return ""
	var row := _boot(game)
	var bucket: Dictionary = row[mode]
	var weeks: Array = _weeks(game, mode, sid).duplicate()
	weeks.append(w)
	bucket[sid] = weeks
	row[mode] = bucket
	game.sdays = row
	return _report(game, sid, mode)


## Player force capture. The day stays quiet for the rest of the run.
## The capture order itself may still be the intrusion; later orders are not.
static func note_capture(game, sid: String, fid: String, force: bool) -> void:
	if not enabled or game == null or not force:
		return
	if str(fid) != str(game.player) or not has_day(game, sid):
		return
	var row := _boot(game)
	var quiet: Dictionary = row.quiet
	if int(quiet.get(sid, 0)) > 0:
		return
	quiet[sid] = int(game.week)
	row.quiet = quiet
	game.sdays = row


static func is_quiet(game, sid: String) -> bool:
	return _quiet_week(game, sid) > 0


static func row_text(game, sid: String) -> String:
	if not enabled or not _showable(game, sid):
		return ""
	var day := _day_name(sid)
	if is_quiet(game, sid):
		return Copy.fill("sday.quiet", {"day": day})
	return _when_text(game, sid, day)


## Pin hover. Today and soon only. A quiet day adds nothing.
static func tip_line(game, sid: String) -> String:
	if not enabled or not _showable(game, sid) or is_quiet(game, sid):
		return ""
	return _when_text(game, sid, _day_name(sid))


## Tooltip under the status row: the day's description, then the shared tip. Two lines.
static func detail_tip(game, sid: String) -> String:
	if not has_day(game, sid):
		return ""
	return "%s\n%s" % [Copy.t("sday.%s.desc" % sid), Copy.t("sday.tip")]


## P88 Face slot #5. Empty when the window has passed, so the Face falls through.
static func face_line(game, sid: String) -> Dictionary:
	if not enabled or game == null or not has_day(game, sid):
		return {}
	if not _known(game, sid):
		return {}
	var kept := _recent(game, sid, "kept")
	var intruded := _recent(game, sid, "intruded")
	if kept < 0 and intruded < 0:
		return {}
	var day := _day_name(sid)
	if intruded > kept:
		return {"key": "sday.intruded", "fields": {"day": day}}
	if _wearing_gift(game, sid):
		return {"key": "sday.kept_kit", "fields": {"day": day}}
	return {"key": "sday.%s.kept" % sid, "fields": {}}


static func count(game) -> int:
	var n := 0
	var kept = _view(game).get("kept", {})
	if not (kept is Dictionary):
		return 0
	for sid in kept:
		var weeks = kept[sid]
		if weeks is Array:
			n += weeks.size()
	return n


## "station · day · week" from names that already exist. Oldest first.
static func tally_lines(game) -> PackedStringArray:
	var items: Array = []
	var kept = _view(game).get("kept", {})
	if kept is Dictionary:
		for sid in kept:
			var weeks = kept[sid]
			if not (weeks is Array):
				continue
			for w in weeks:
				items.append({"sid": str(sid), "week": int(w)})
	items.sort_custom(func(a, b):
		if int(a.week) == int(b.week):
			return str(a.sid) < str(b.sid)
		return int(a.week) < int(b.week))
	var out := PackedStringArray()
	for item in items:
		var sid := str(item.sid)
		var station := sid
		if game != null and game.has_method("station_text"):
			var place := str(game.station_text(sid, "community"))
			if place != "":
				station = place
		out.append("%s · %s · %s" % [station, _day_name(sid), str(int(item.week))])
	return out


static func attach(report: Dictionary, line: String) -> Dictionary:
	if line == "" or report.is_empty():
		return report
	var text := str(report.get("text", ""))
	report["text"] = line if text == "" else text + "\n" + line
	return report


## First time a day row is shown. Sets `flags.seen_station_days`. Not a dawn chip.
static func claim_first(game) -> String:
	if not enabled or game == null:
		return ""
	if bool(game.flags.get(SEEN, false)):
		return ""
	if not _any_row(game):
		return ""
	game.flags[SEEN] = true
	return Copy.t("sday.first")


static func _when_text(game, sid: String, day: String) -> String:
	var n := weeks_to(game, sid)
	if n == 0:
		return Copy.fill("sday.today", {"day": day})
	if n == 1:
		return Copy.fill("sday.soon_one", {"day": day})
	if n <= SOON_WEEKS:
		return Copy.fill("sday.soon", {"day": day, "n": n})
	return ""


static func _report(game, sid: String, mode: String) -> String:
	var key := "sday.kept_report" if mode == "kept" else "sday.intruded_report"
	var station := sid
	if game.has_method("station_text"):
		var place := str(game.station_text(sid, "community"))
		if place != "":
			station = place
	return Copy.fill(key, {"day": _day_name(sid), "station": station})


static func _day_name(sid: String) -> String:
	return Copy.t("sday.%s.name" % sid)


static func _showable(game, sid: String) -> bool:
	return has_day(game, sid) and _known(game, sid)


static func _known(game, sid: String) -> bool:
	return game != null and game.stations.has(sid) and bool(game.stations[sid].get("known", false))


static func _any_row(game) -> bool:
	for sid in ids():
		if row_text(game, str(sid)) != "":
			return true
	return false


static func _on_week(week: int, sid: String, max_w: int) -> bool:
	var offset := offset_of(sid)
	if offset < 1 or week < 1:
		return false
	if max_w > 0 and week > max_w:
		return false
	return _mod8(week - offset) == 0


static func _mod8(n: int) -> int:
	var m := n % 8
	if m < 0:
		m += 8
	return m


static func _quiet_week(game, sid: String) -> int:
	var quiet = _view(game).get("quiet", {})
	if not (quiet is Dictionary):
		return 0
	return int(quiet.get(str(sid), 0))


static func _recent(game, sid: String, bucket: String) -> int:
	var best := -1
	var week := int(game.week)
	for w in _weeks(game, bucket, sid):
		var n := int(w)
		if n > week or week - n > FACE_SPAN:
			continue
		if n > best:
			best = n
	return best


static func _has_week(game, sid: String, week: int) -> bool:
	for bucket in ["kept", "intruded"]:
		for w in _weeks(game, bucket, sid):
			if int(w) == week:
				return true
	return false


static func _weeks(game, bucket: String, sid: String) -> Array:
	var raw = _view(game).get(bucket, {})
	if not (raw is Dictionary):
		return []
	var weeks = raw.get(sid, [])
	return weeks if weeks is Array else []


static func _wearing_gift(game, sid: String) -> bool:
	var kit: Dictionary = MarksKit.catalog().get("kit", {})
	for id in kit:
		var row = kit[id]
		if not (row is Dictionary):
			continue
		if str(row.get("source", "")) != "station" or str(row.get("station", "")) != str(sid):
			continue
		if MarksKit.wearing(game, str(id)):
			return true
	return false


static func _view(game) -> Dictionary:
	if game == null or not (game.get("sdays") is Dictionary):
		return {"kept": {}, "intruded": {}, "quiet": {}}
	return game.sdays


static func _boot(game) -> Dictionary:
	var row := _view(game)
	if game == null:
		return {"kept": {}, "intruded": {}, "quiet": {}}
	for key in ["kept", "intruded", "quiet"]:
		if not (row.get(key) is Dictionary):
			row[key] = {}
	game.sdays = row
	return row


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_offset = {}
	if not FileAccess.file_exists(PACK):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	if not (data is Dictionary):
		return
	var days = data.get("_days", {})
	if not (days is Dictionary):
		return
	for sid in days:
		var row = days[sid]
		if row is Dictionary:
			_offset[str(sid)] = int(row.get("offset", 0))
