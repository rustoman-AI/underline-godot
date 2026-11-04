class_name PassageDuty
extends RefCounted

## P81 Passage Duty. One seat on an owned station whose deal passage is open.
## The seat is the station↔capital pair. Foreign passages stay display-only.
## No map mark, no dawn chip, no goods, no raid change.

const CHIP := "people.chip_duty"


static func dawn_chip() -> bool:
	return false


static func holds(person: Dictionary) -> bool:
	return str(person.get("duty_edge_id", "")) != ""


## Sick and Away outrank Duty. Crew, room, and Free chips are not invented here.
static func chip_key(person: Dictionary) -> String:
	if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
		return ""
	if holds(person):
		return CHIP
	return ""


static func clip_name(name: String) -> String:
	if name.length() <= 12:
		return name
	return name.substr(0, 12) + "…"


static func edge_id(capital: String, sid: String) -> String:
	if capital < sid:
		return capital + "|" + sid
	return sid + "|" + capital


static func far_of(game, edge: String) -> String:
	var bits := edge.split("|")
	if bits.size() != 2:
		return ""
	var cap := str(game.capital_id)
	if bits[0] == cap:
		return str(bits[1])
	if bits[1] == cap:
		return str(bits[0])
	return ""


## Player-owned outpost with the deal passage still open. Capital and foreign pins are not seats.
static func open_owned(game, sid: String) -> bool:
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


static func edge_for(game, sid: String) -> String:
	if not open_owned(game, sid):
		return ""
	return edge_id(str(game.capital_id), sid)


static func watcher(game, edge: String) -> Dictionary:
	if edge == "":
		return {}
	for person in game.residents:
		if str(person.get("duty_edge_id", "")) == edge:
			return person
	return {}


static func seats(game, sid: String) -> Array:
	var edge := edge_for(game, sid)
	if edge == "":
		return []
	var who := watcher(game, edge)
	var pid := ""
	var name := ""
	if not who.is_empty():
		pid = str(who.get("id", ""))
		name = Copy.person(str(who.get("name", "")))
	return [{"id": edge, "station": sid, "person_id": pid, "person_name": name}]


static func tip_line(game, sid: String) -> String:
	if edge_for(game, sid) == "":
		return ""
	return Copy.t("duty.tip")


static func free_people(game) -> Array:
	var rows: Array = []
	for person in game.residents:
		if _free_hand(game, person):
			rows.append(person)
	rows.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return rows


static func preview(game, person_id: String, edge: String) -> Dictionary:
	var info := {"ok": false, "reason": "", "first": false}
	if not game.people.has(person_id):
		info.reason = Copy.t("No such resident.")
		return info
	var sid := far_of(game, edge)
	if sid == "" or edge_for(game, sid) != edge:
		info.reason = Copy.t("duty.lost")
		return info
	var sitting := watcher(game, edge)
	if not sitting.is_empty() and str(sitting.get("id", "")) != person_id:
		info.reason = Copy.t("duty.tip")
		return info
	var person: Dictionary = game.people[person_id]
	if not _free_hand(game, person):
		if game._is_child(person) or int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			info.reason = Copy.t("%s cannot work right now.") % Copy.person(str(person.name))
		elif game._locked_ids().has(person_id) or bool(person.get("soldier", false)):
			info.reason = Copy.t("%s is on a crew.") % Copy.person(str(person.name))
		else:
			info.reason = Copy.t("duty.tip")
		return info
	info.ok = true
	return info


static func _free_hand(game, person: Dictionary) -> bool:
	var id := str(person.get("id", ""))
	if id == "" or game._is_child(person):
		return false
	if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
		return false
	if game._locked_ids().has(id) or bool(person.get("soldier", false)):
		return false
	if holds(person):
		return false
	if game._staff_room_of(id) != "":
		return false
	return true


## Drops watches the station no longer owns, and anyone sick, away, dead, or on a crew.
## Returns the lost line once, or nothing. Does not touch stock, hope, or the dawn stack.
static func sweep(game) -> PackedStringArray:
	var watching := false
	for person in game.residents:
		if holds(person):
			watching = true
			break
	if not watching:
		return PackedStringArray()
	var lost := false
	var seen := {}
	for person in game.residents:
		if not holds(person):
			continue
		var id := str(person.get("id", ""))
		var edge := str(person.get("duty_edge_id", ""))
		var sid := far_of(game, edge)
		var valid: bool = sid != "" and edge_for(game, sid) == edge
		if valid and int(game._supply_hops(sid)) >= 900:
			valid = false
		var blocked: bool = game._is_child(person) or int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0
		blocked = blocked or game._locked_ids().has(id) or bool(person.get("soldier", false))
		if not valid or blocked or seen.has(edge):
			person.erase("duty_edge_id")
			lost = true
			continue
		seen[edge] = true
		if game._staff_room_of(id) != "":
			game._unassign(id)
			if person.has("post"):
				person.erase("post")
	if not lost:
		return PackedStringArray()
	var line := PackedStringArray()
	line.append(Copy.t("duty.lost"))
	return line
