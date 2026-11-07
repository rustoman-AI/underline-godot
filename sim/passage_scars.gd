class_name PassageScars
extends RefCounted

## P94 Passage Scars. Memory only.
## An owned passage (player holds at least one end of an existing tunnel) remembers the
## last raid/assault or P74 night-run death that resolved on either endpoint.
## Edge key is the sorted pair P58 / P81 / Quiet Toll already use. No second graph.
## Endpoint match only: no path search. Count increments; kind and week stay latest.
## Tip and one Visit line. First float once per run. Not a dawn chip. No map mark.
## Balance ZERO. No rng. Soft dawn NONE.
##
## Schema chain: 20 station days, 21 carried word, 22 line echo, 23 rival desk,
## 24 platform callers, 25 passage scars. A key already stored is kept.
## Schema <= 24 may omit scars.

const FLAG := "seen_passage_scars"
const TIP_W := 360.0
## Gate and careful runs flip this off. The game leaves it on. Off writes nothing.
static var enabled := true


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func map_mark() -> bool:
	return false


## P74 is on this master. If that script is absent the night trigger stays dormant.
static func night_armed() -> bool:
	return ResourceLoader.exists("res://sim/night_runs.gd")


## Same pair key as QuietToll.edge_id and NetworkView._edge_key.
static func edge_id(a: String, b: String) -> String:
	if a < b:
		return a + "|" + b
	return b + "|" + a


static func holds(game, sid: String) -> bool:
	if game == null or sid == "" or not game.stations.has(sid):
		return false
	return str(game.stations[sid].get("owner", "")) == str(game.player)


## Tunnel exists and the player holds at least one end. Foreign-only edges are not owned.
static func owned_edge(game, a: String, b: String) -> bool:
	if game == null or a == "" or b == "" or a == b:
		return false
	if not game.has_method("_edge") or game._edge(a, b).is_empty():
		return false
	return holds(game, a) or holds(game, b)


## Player or rival raid / assault resolved at sid. Both outcomes. No path walk.
static func note_raid(game, sid: String) -> void:
	_note(game, sid, "raid")


## P74 night-run death whose site station is sid. Dormant when Night Runs is absent.
static func note_night(game, sid: String) -> void:
	if not night_armed():
		return
	_note(game, sid, "night")


static func _note(game, sid: String, kind: String) -> void:
	if not enabled or game == null or sid == "":
		return
	if not (game.get("stations") is Dictionary) or not game.stations.has(sid):
		return
	if not (game.get("tunnels") is Array):
		return
	if not (game.get("scars") is Dictionary):
		game.scars = {}
	var week := maxi(1, int(game.week))
	for tunnel in game.tunnels:
		if not (tunnel is Dictionary):
			continue
		var a := str(tunnel.get("a", ""))
		var b := str(tunnel.get("b", ""))
		if a != sid and b != sid:
			continue
		if not holds(game, a) and not holds(game, b):
			continue
		var key := edge_id(a, b)
		var prev: Dictionary = game.scars.get(key, {}) if game.scars.get(key, {}) is Dictionary else {}
		var count := int(prev.get("count", 0)) + 1
		if game.scars.has(key):
			game.scars.erase(key)
		game.scars[key] = {"kind": kind, "week": week, "count": count}


static func line_of(row: Dictionary) -> String:
	var kind := str(row.get("kind", "raid"))
	var n := int(row.get("week", 0))
	var count := int(row.get("count", 0))
	if kind == "night":
		if count > 1:
			return Copy.fill("scar.night_n", {"count": str(count), "n": str(n)})
		return Copy.fill("scar.night", {"n": str(n)})
	if count > 1:
		return Copy.fill("scar.raid_n", {"count": str(count), "n": str(n)})
	return Copy.fill("scar.raid", {"n": str(n)})


## Ordered rows for the owned-edge tip. Flow, then Duty, then Toll, then Scar.
## Empty when the edge is foreign-only or has no scar. Does not rewrite those packs.
static func edge_rows(game, a: String, b: String) -> Array:
	if not enabled or not owned_edge(game, a, b):
		return []
	var scar := _scar_line(game, edge_id(a, b))
	if scar == "":
		return []
	var rows: Array = []
	rows.append_array(_pack_rows("res://sim/passage_flow.gd", "flow", game, a, b))
	rows.append_array(_pack_rows("res://sim/passage_duty.gd", "duty", game, a, b))
	rows.append_array(_toll_rows(game, a, b))
	rows.append({"role": "scar", "text": scar})
	return rows


static func edge_tip(game, a: String, b: String) -> String:
	var parts := PackedStringArray()
	for row in edge_rows(game, a, b):
		parts.append(str(row.get("text", "")))
	return "\n".join(parts)


## One Visit line: the most recent scar among owned edges that touch this station.
## {} when the station has none. Both endpoints of an owned edge may show it.
static func visit_row(game, sid: String) -> Dictionary:
	if not enabled or game == null or sid == "" or not (game.get("scars") is Dictionary):
		return {}
	var best: Dictionary = {}
	var best_edge := ""
	for key in game.scars:
		var edge := str(key)
		if not _touches(edge, sid) or not _owned_key(game, edge):
			continue
		var row = game.scars[key]
		if not (row is Dictionary):
			continue
		if best.is_empty() or _prefer(row, edge, best, best_edge):
			best = row
			best_edge = edge
	if best.is_empty():
		return {}
	return {"edge": best_edge, "text": line_of(best), "kind": str(best.get("kind", "")), "week": int(best.get("week", 0)), "count": int(best.get("count", 0))}


static func visit_line(game, sid: String) -> String:
	return str(visit_row(game, sid).get("text", ""))


## First scar of the run, when the player can see it. Sets seen_passage_scars. Not a dawn chip.
static func claim_first(game) -> String:
	if not enabled or game == null or not (game.get("flags") is Dictionary):
		return ""
	if bool(game.flags.get(FLAG, false)):
		return ""
	if not (game.get("scars") is Dictionary) or game.scars.is_empty():
		return ""
	game.flags[FLAG] = true
	return Copy.t("scar.first")


static func tip() -> String:
	return Copy.t("scar.tip")


## "" when a schema-25 scars dict can be played. Extra keys inside a row are ignored.
static func problem(scars, week: int) -> String:
	if not (scars is Dictionary):
		return "scars"
	for key in scars:
		var edge := str(key)
		var bits := edge.split("|")
		if bits.size() != 2 or str(bits[0]) == "" or str(bits[1]) == "" or str(bits[0]) >= str(bits[1]):
			return "scar edge %s" % edge
		var row = scars[key]
		if not (row is Dictionary):
			return "scar %s" % edge
		var kind := str(row.get("kind", ""))
		if kind != "raid" and kind != "night":
			return "scar %s kind" % edge
		if typeof(row.get("week")) != TYPE_INT or int(row.week) < 1 or int(row.week) > maxi(1, week):
			return "scar %s week" % edge
		if typeof(row.get("count")) != TYPE_INT or int(row.count) < 1:
			return "scar %s count" % edge
	return ""


static func _scar_line(game, edge: String) -> String:
	if game == null or not (game.get("scars") is Dictionary):
		return ""
	var row = game.scars.get(edge, {})
	if not (row is Dictionary) or row.is_empty():
		return ""
	return line_of(row)


static func _prefer(row: Dictionary, edge: String, other: Dictionary, other_edge: String) -> bool:
	var week := int(row.get("week", 0))
	var oweek := int(other.get("week", 0))
	if week != oweek:
		return week > oweek
	# Same week: the later write wins. note_* reinserts the key at the end.
	return edge != other_edge


static func _touches(edge: String, sid: String) -> bool:
	var bits := edge.split("|")
	return bits.size() == 2 and (str(bits[0]) == sid or str(bits[1]) == sid)


static func _owned_key(game, edge: String) -> bool:
	var bits := edge.split("|")
	if bits.size() != 2:
		return false
	return owned_edge(game, str(bits[0]), str(bits[1]))


static func _toll_rows(game, a: String, b: String) -> Array:
	var rows: Array = []
	var seen := {}
	for pair in [[a, b], [b, a]]:
		var state := str(QuietToll.edge_state(game, str(pair[0]), str(pair[1])))
		var key := ""
		match state:
			"qualifies":
				key = "toll.tip"
			"need_duty":
				key = "toll.need_duty"
			"quiet":
				key = "toll.quiet"
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		rows.append({"role": "toll", "text": Copy.t(key)})
	return rows


static func _pack_rows(path: String, role: String, game, a: String, b: String) -> Array:
	if not ResourceLoader.exists(path):
		return []
	var script = load(path)
	if script == null:
		return []
	var lines: Array = []
	if script.has_method("edge_tip_lines"):
		lines = script.edge_tip_lines(game, a, b)
	elif script.has_method("edge_lines"):
		lines = script.edge_lines(game, a, b)
	var rows: Array = []
	for line in lines:
		var text := str(line)
		if text == "":
			continue
		rows.append({"role": role, "text": text})
	return rows
