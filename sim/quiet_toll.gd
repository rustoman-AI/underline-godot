class_name QuietToll
extends RefCounted

## P86 Quiet Toll. Read-only.
## An owned passage seat (P81: player outpost, passage still open) with foreign goods
## on an open tunnel (P58 display: foreign passage thread and a good actually flowing).
## tip_only: no skim, no mats, no map tick, no soft-dawn chip. The skim line stays in the text pack and is never called.

const FLAG := "seen_quiet_toll"
const DealMarks = preload("res://sim/deal_marks.gd")


static func joins_soft_dawn() -> bool:
	return false


static func draws_map_tick() -> bool:
	return false


static func skim_wired() -> bool:
	return false


## Same pair key P81 stores on a resident as duty_edge_id.
static func edge_id(a: String, b: String) -> String:
	if a < b:
		return a + "|" + b
	return b + "|" + a


## Player-owned outpost whose deal passage is still open. Capital and foreign pins are not seats.
static func owned_seat(game, sid: String) -> bool:
	if game == null or sid == "" or str(sid) == str(game.capital_id):
		return false
	if not game.stations.has(sid):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) != str(game.player):
		return false
	if not bool(st.get("passage", false)):
		return false
	if bool(st.get("hidden", false)) and not bool(st.get("known", false)):
		return false
	return true


static func duty_edge(game, sid: String) -> String:
	if not owned_seat(game, sid):
		return ""
	var duty = _duty_script()
	if duty != null and duty.has_method("edge_for"):
		return str(duty.edge_for(game, sid))
	return edge_id(str(game.capital_id), sid)


static func duty_posted(game, sid: String) -> bool:
	var edge := duty_edge(game, sid)
	if edge == "":
		return false
	var duty = _duty_script()
	if duty != null and duty.has_method("watcher"):
		return not (duty.watcher(game, edge) as Dictionary).is_empty()
	for person in game.residents:
		if str(person.get("duty_edge_id", "")) == edge:
			return true
	return false


## P58 foreign-flow display. Prefer that pack when it is on the branch. Never draws the tick.
static func foreign_display(game, sid: String) -> bool:
	if game == null or sid == "" or not game.stations.has(sid):
		return false
	var flow = _flow_script()
	if flow != null and flow.has_method("shows"):
		return bool(flow.shows(game, sid))
	if str(sid) == str(game.capital_id):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) == str(game.player):
		return false
	if bool(st.get("hidden", false)) and not bool(st.get("known", false)):
		return false
	if not bool(st.get("known", false)):
		return false
	if not DealMarks.shows_thread(game, sid):
		return false
	if not game.has_method("good_flowing") or not bool(game.good_flowing(sid)):
		return false
	return true


## qualifies / need_duty / quiet / "" (nothing).
## Flow is a foreign passage neighbor. Duty is the P81 seat on this station.
static func station_state(game, sid: String) -> String:
	if not owned_seat(game, sid):
		return ""
	var flow := false
	if game.has_method("_neighbors"):
		for other in game._neighbors(sid):
			if foreign_display(game, str(other)):
				flow = true
				break
	var duty := duty_posted(game, sid)
	if flow and duty:
		return "qualifies"
	if flow:
		return "need_duty"
	if duty:
		return "quiet"
	return ""


static func tip_line(game, sid: String) -> String:
	match station_state(game, sid):
		"qualifies":
			return Copy.t("toll.tip")
		"need_duty":
			return Copy.t("toll.need_duty")
		"quiet":
			return Copy.t("toll.quiet")
		_:
			return ""


## "status", "none", or "" when the Visit row is omitted.
static func visit_kind(game, sid: String) -> String:
	match station_state(game, sid):
		"qualifies":
			return "status"
		"quiet":
			return "none"
		_:
			return ""


static func visit_line(kind: String) -> String:
	if kind == "status":
		return Copy.t("toll.status")
	if kind == "none":
		return Copy.t("toll.status_none")
	return ""


## First qualifying tip this run. Sets flags.seen_quiet_toll. Not a dawn chip.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get(FLAG, false)):
		return ""
	var any := false
	for sid in game.stations:
		if station_state(game, str(sid)) == "qualifies":
			any = true
			break
	if not any:
		return ""
	game.flags[FLAG] = true
	return Copy.t("toll.first")


static func _duty_script():
	if ResourceLoader.exists("res://sim/passage_duty.gd"):
		return load("res://sim/passage_duty.gd")
	return null


static func _flow_script():
	if ResourceLoader.exists("res://sim/passage_flow.gd"):
		return load("res://sim/passage_flow.gd")
	return null
