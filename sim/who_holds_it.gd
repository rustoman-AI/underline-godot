class_name WhoHoldsIt
extends RefCounted

## P101 Who Holds It. A pure preview of the existing governor tradeoff.
## Reads the live game. Writes nothing. Does not stamp, journal, or call apply.
## The shipment is Formulas.outpost_flow plus the existing food-focus perk, with the
## candidate substituted for the station's governor. st.governor is never written.
##
## _supply_hops is a read-only BFS. _supplies, which it calls, only reads owner,
## passage, and trade_on. Neither function writes.

const VISIBLE_ROWS := 6
const MAX_TAGS := 4
const FLOW_KEYS := ["food", "materials", "air", "influence", "tokens"]
const KNOWN_GOODS := ["food", "materials", "tokens", "influence", "air"]
const FOCUS_GOOD := {"food": "food", "air": "air", "defense": "materials", "influence": "influence"}
const KEYS := [
	"govpick.next_dawn",
	"govpick.settled",
	"govpick.settling",
	"govpick.settle_in",
	"govpick.for_focus",
	"govpick.leaves",
	"govpick.no_room",
	"govpick.order_now",
	"govpick.garrison",
	"govpick.devout",
	"govpick.marketeer",
	"govpick.more",
	"govpick.send",
	"govpick.pick_first",
	"govpick.changed",
	"govpick.runs_out",
]
const EN := {
	"govpick.next_dawn": "Next dawn: {flow}",
	"govpick.settled": "Once settled: {flow}",
	"govpick.settling": "Still settling: costs {n} material",
	"govpick.settle_in": "Settles in {n} weeks",
	"govpick.for_focus": "Shown for {focus} focus",
	"govpick.leaves": "Leaves {room}. Post kept for their return.",
	"govpick.no_room": "No room assignment",
	"govpick.order_now": "One order fewer this week",
	"govpick.garrison": "Garrison +{n}",
	"govpick.devout": "Eases unrest by 1 a week",
	"govpick.marketeer": "Tokens +{n} a week while supplied",
	"govpick.more": "+{n} more",
	"govpick.send": "Send {name}",
	"govpick.pick_first": "Pick who goes.",
	"govpick.changed": "Things changed. Compare again.",
	"govpick.runs_out": "If influence runs out, they come home.",
}


static func locale_ready() -> bool:
	Copy.boot()
	for key in KEYS:
		if text(str(key)) == "":
			return false
	return true


## The active locale's string, or "" when that locale has none. Never the raw key.
static func text(key: String) -> String:
	Copy.boot()
	if not Copy.keys.has(key):
		return ""
	var row: Dictionary = Copy.keys[key]
	var value := ""
	if Copy.ru():
		value = str(row.get("ru", ""))
	else:
		value = str(row.get("en", ""))
	if value == "" or value == key or value.begins_with("govpick."):
		return ""
	return value


static func fill(key: String, vars: Dictionary) -> String:
	var line := text(key)
	if line == "":
		return ""
	for token in vars:
		line = line.replace("{%s}" % str(token), str(vars[token]))
	if line.find("govpick.") >= 0:
		return ""
	return line


static func goods_readable(game, sid: String) -> bool:
	if Game.SAVE_SCHEMA != 27:
		return false
	if game == null or game.catalog == null or not game.stations.has(sid):
		return false
	var goods: Dictionary = game.catalog.station_goods(str(sid))
	if goods.is_empty():
		return false
	for key in goods:
		if not KNOWN_GOODS.has(str(key)):
			return false
		var value = goods[key]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
	return true


## Next-dawn and settled flows for this candidate. Does not write the governor.
static func project(game, sid: String, pid: String) -> Dictionary:
	var blank := {
		"ok": false,
		"next": {},
		"settled": {},
		"settle_weeks": 0,
		"differs": false,
		"age": 0,
		"hops": 0,
		"bonus": 0,
		"focus": "",
	}
	if game == null or not game.stations.has(sid) or not game.people.has(pid):
		return blank
	var st: Dictionary = game.stations[sid]
	var focus := str(st.get("focus", "food"))
	var age := int(st.get("held_weeks", 0)) + 1
	var hops := int(game._supply_hops(str(sid)))
	var bonus := int(game.governor_bonus(pid, focus))
	var settle := int(game.governor_settle(pid))
	blank.age = age
	blank.hops = hops
	blank.bonus = bonus
	blank.focus = focus
	blank.settle_weeks = settle
	if not goods_readable(game, sid):
		return blank
	var goods: Dictionary = game.catalog.station_goods(str(sid))
	var next: Dictionary = Formulas.outpost_flow(age, hops, focus, bonus, settle, goods)
	next = game._with_food_focus_bonus(next, focus)
	var later := maxi(age, 5)
	var settled: Dictionary = Formulas.outpost_flow(later, hops, focus, bonus, settle, goods)
	settled = game._with_food_focus_bonus(settled, focus)
	blank.ok = true
	blank.next = next
	blank.settled = settled
	blank.differs = not same_flow(next, settled)
	return blank


static func same_flow(a: Dictionary, b: Dictionary) -> bool:
	for key in ["food", "materials", "tokens", "influence", "air", "upkeep_materials"]:
		if int(a.get(key, 0)) != int(b.get(key, 0)):
			return false
	return true


static func flow_phrase(flow: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key in FLOW_KEYS:
		var n := int(flow.get(key, 0))
		if n > 0:
			bits.append("+%d %s" % [n, Copy.res(key)])
	if bits.is_empty():
		return "0"
	return ", ".join(bits)


static func next_line(flow: Dictionary) -> String:
	if int(flow.get("upkeep_materials", 0)) > 0:
		return fill("govpick.settling", {"n": int(flow.upkeep_materials)})
	return fill("govpick.next_dawn", {"flow": flow_phrase(flow)})


static func settled_line(flow: Dictionary) -> String:
	if int(flow.get("upkeep_materials", 0)) > 0:
		return fill("govpick.settling", {"n": int(flow.upkeep_materials)})
	return fill("govpick.settled", {"flow": flow_phrase(flow)})


static func settle_line(weeks: int) -> String:
	return fill("govpick.settle_in", {"n": weeks})


## Tag order matches the sheet: this week's order, the seat, loyalty, garrison, Devout, marketeer.
## Devout only while unrest is above zero. Marketeer only while the station is supplied.
## The council order tag only when that seat is still unused this week.
static func tags(game, sid: String, pid: String) -> Array:
	var out: Array = []
	if game == null or not game.people.has(pid) or not game.stations.has(sid):
		return out
	var person: Dictionary = game.people[pid]
	var st: Dictionary = game.stations[sid]
	var g: Dictionary = game.bal.governor
	if game._is_council(pid):
		var unused := false
		for seat in game.council:
			if str(seat.get("id", "")) == pid and str(game.seat_used.get(str(seat.get("role", "")), "")) == "":
				unused = true
		if unused:
			var order_line := text("govpick.order_now")
			if order_line != "":
				out.append({"id": "order_now", "text": order_line})
		var seat_line := Copy.t("councillor: no order while away")
		out.append({"id": "seat", "text": seat_line})
	if int(person.skills.get("talk", 0)) >= int(g.talk_min):
		out.append({"id": "loyalty", "text": Copy.t("loyalty +%d a week") % int(g.talk_loyalty)})
	if game._has_trait(person, "Veteran"):
		var garrison := fill("govpick.garrison", {"n": int(g.veteran_garrison)})
		if garrison != "":
			out.append({"id": "garrison", "text": garrison})
	if game._has_trait(person, "Devout") and int(st.get("unrest", 0)) > 0:
		var devout := text("govpick.devout")
		if devout != "":
			out.append({"id": "devout", "text": devout})
	if game._has_trait(person, "Black marketeer") and int(game._supply_hops(str(sid))) < 900:
		var market := fill("govpick.marketeer", {"n": int(g.marketeer_tokens)})
		if market != "":
			out.append({"id": "marketeer", "text": market})
	return out


static func home_line(title: String) -> String:
	if title == "":
		return text("govpick.no_room")
	return fill("govpick.leaves", {"room": title})


## The comma line the old popup shows. Used when the shipment cannot be projected.
static func comma_line(game, sid: String, row: Dictionary) -> String:
	if game == null or not game.stations.has(sid):
		return ""
	var g: Dictionary = game.bal.governor
	var focus := str(game.stations[sid].get("focus", "food"))
	var good := Copy.res(str(FOCUS_GOOD.get(focus, "food")))
	var bits: PackedStringArray = ["%s %d" % [Copy.skill(str(row.get("skill_key", ""))), int(row.get("skill", 0))]]
	if int(row.get("bonus", 0)) > 0:
		bits.append("+%d %s" % [int(row.bonus), good])
	if int(row.get("talk", 0)) >= int(g.talk_min):
		bits.append(Copy.t("loyalty +%d a week") % int(g.talk_loyalty))
	if bool(row.get("council", false)):
		bits.append(Copy.t("councillor: no order while away"))
	return "%s   %s" % [Copy.person(str(row.get("name", ""))), ", ".join(bits)]


## A fingerprint of everything the sheet displays or the appoint command checks.
## Read-only. A change here means Send must not apply.
static func revision(game, sid: String) -> String:
	if game == null or not game.stations.has(sid):
		return "missing"
	var bits: PackedStringArray = []
	bits.append("schema:%d" % Game.SAVE_SCHEMA)
	bits.append("week:%d" % int(game.week))
	bits.append("over:%s" % str(game.over))
	bits.append("influence:%d" % int(game.stock.get("influence", 0)))
	bits.append("orders:%d" % int(game.orders_left))
	bits.append("perk:%d" % int(game._perk_int("food_focus_bonus")))
	bits.append("hops:%d" % int(game._supply_hops(str(sid))))
	var st: Dictionary = game.stations[sid]
	bits.append("owner:%s" % str(st.get("owner", "")))
	bits.append("governor:%s" % str(st.get("governor", "")))
	bits.append("focus:%s" % str(st.get("focus", "")))
	bits.append("held:%d" % int(st.get("held_weeks", 0)))
	bits.append("unrest:%d" % int(st.get("unrest", 0)))
	bits.append("loyalty:%d" % int(st.get("loyalty", 0)))
	bits.append("garrison:%d" % int(st.get("garrison", 0)))
	var goods: Dictionary = game.catalog.station_goods(str(sid))
	var gkeys: Array = goods.keys()
	gkeys.sort()
	for key in gkeys:
		bits.append("good:%s=%s" % [str(key), str(goods[key])])
	var seats: PackedStringArray = []
	for seat in game.council:
		seats.append("%s:%s:%s" % [str(seat.get("id", "")), str(seat.get("role", "")), str(game.seat_used.get(str(seat.get("role", "")), ""))])
	seats.sort()
	bits.append("seats:%s" % "|".join(seats))
	for row in game.governor_candidates(str(sid)):
		var pid := str(row.get("id", ""))
		var person: Dictionary = game.people.get(pid, {})
		var skills: PackedStringArray = []
		for sk in person.get("skills", {}):
			skills.append("%s%d" % [str(sk), int(person.skills[sk])])
		skills.sort()
		var traits: PackedStringArray = []
		for trait_name in person.get("traits", []):
			traits.append(str(trait_name))
		traits.sort()
		bits.append("who:%s:%s:%s:%s:%s:%d:%d:%d" % [
			pid,
			",".join(skills),
			",".join(traits),
			"1" if bool(row.get("council", false)) else "0",
			game._staff_room_of(pid),
			int(person.get("absent", 0)),
			int(person.get("sick", 0)),
			1 if bool(person.get("soldier", false)) else 0,
		])
	return "\n".join(bits)
