class_name LineEcho
extends RefCounted

## P91 Line Echo. A neighbor remembers a resolved order. Balance ZERO.
## No resource, standing, sympathy, or check changes. No random draws.
## Nothing in the sim reads `echoes` for an outcome. Bots never open Visit.
## Soft dawn: none. Map mark: none. `echo.first` is a P61 first-float, not a dawn chip.
## The dict stays after the line expires. The Visit and the pin hide it.

const SEEN := "seen_line_echo"
const KINDS := ["envoy", "deal", "aid", "propaganda", "probe", "patrol", "raid"]
## Gate flips this off to prove the hooks do not move a careful run. The game leaves it on.
static var enabled := true
## A first-float the map could not show. The yard plate speaks it once. Not saved.
static var held_float := ""


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func map_mark() -> bool:
	return false


## Order verb to the noun the line speaks. Raid and assault share raid. Empty when the order is not heard.
static func kind_of(order: String) -> String:
	match order:
		"trade":
			return "deal"
		"assault":
			return "raid"
		"envoy", "aid", "propaganda", "probe", "patrol", "raid":
			return order
		_:
			return ""


## After a resolved player order. One echo on each known open 1-hop neighbor. The target stays silent.
static func note_order(game, action: Dictionary) -> void:
	if not enabled or game == null or not (action is Dictionary):
		return
	var kind := kind_of(str(action.get("order", "")))
	if kind == "":
		return
	var sid := PlatformFaces.order_sid(action)
	if sid == "" or not game.stations.has(sid):
		return
	var bag := _ensure(game)
	var seen := {}
	for n in game._neighbors(sid):
		var nid := str(n)
		if seen.has(nid) or nid == "" or nid == sid:
			continue
		seen[nid] = true
		if not _hears(game, nid):
			continue
		if int(game._hops(sid, nid)) != 1:
			continue
		bag[nid] = {"from": sid, "kind": kind, "week": int(game.week)}
	game.echoes = bag


## The echo Visit and the pin may show, or empty when it has expired, is a bunker, or was never heard.
static func line_text(game, nid: String) -> String:
	var heard := _row(game, nid)
	if heard.is_empty():
		return ""
	var kind := Copy.t("echo.kind." + str(heard.kind))
	var station := _place(game, str(heard.from))
	if _face_met(game, nid):
		return Copy.fill("echo.said", {
			"name": Copy.t("regular.%s.name" % nid),
			"kind": kind,
			"station": station,
		})
	return Copy.fill("echo.heard", {"kind": kind, "station": station})


## First echo shown this run. Sets `flags.seen_line_echo`. Not a dawn chip.
static func claim_first(game) -> String:
	if not _live(game):
		return ""
	if bool(game.flags.get(SEEN, false)):
		return ""
	if not _any_line(game):
		return ""
	game.flags[SEEN] = true
	return Copy.t("echo.first")


static func _row(game, nid: String) -> Dictionary:
	if not _live(game) or str(nid) == "" or not _hears(game, nid):
		return {}
	var raw = game.echoes.get(str(nid), null)
	if not (raw is Dictionary):
		return {}
	var week := int(raw.get("week", 0))
	if week <= 0 or week < int(game.week) - 1:
		return {}
	var kind := str(raw.get("kind", ""))
	if not KINDS.has(kind):
		return {}
	var origin := str(raw.get("from", ""))
	if origin == "" or origin == str(nid):
		return {}
	return {"from": origin, "kind": kind, "week": week}


static func _any_line(game) -> bool:
	for sid in game.stations:
		if line_text(game, str(sid)) != "":
			return true
	return false


static func _face_met(game, sid: String) -> bool:
	if not PlatformFaces.has_face(game, sid):
		return false
	return int(PlatformFaces.memory(game, sid).get("met", 0)) > 0


static func _place(game, sid: String) -> String:
	if game.has_method("station_text"):
		var community := str(game.station_text(sid, "community"))
		if community != "":
			return community
	var st = game.stations.get(sid, {})
	if st is Dictionary:
		var name := str(st.get("name", ""))
		if name != "":
			return name
	return str(sid)


static func _hears(game, nid: String) -> bool:
	if game == null or not game.stations.has(nid):
		return false
	var st: Dictionary = game.stations[nid]
	if not bool(st.get("known", false)):
		return false
	if bool(st.get("hidden", false)):
		return false
	if str(st.get("bunker", "")) != "":
		return false
	if str(st.get("owner", "")) == "bunker":
		return false
	if str(st.get("lean", "")) == "bunker":
		return false
	return true


static func _live(game) -> bool:
	return enabled and game != null and game.get("echoes") is Dictionary


static func _ensure(game) -> Dictionary:
	if not (game.echoes is Dictionary):
		game.echoes = {}
	return game.echoes
