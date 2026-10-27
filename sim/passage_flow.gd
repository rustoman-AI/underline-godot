class_name PassageFlow
extends RefCounted

## P58 goods tick on the P45 passage thread.
## Reads passage (DealMarks.shows_thread) and the live P55 good_flowing flag.
## Held sources keep the pin goods pip. Never queues a dawn chip. No delivery math.

const DealMarks = preload("res://sim/deal_marks.gd")

const BRASS := Color("e2a63a")
const CARD_INK := Color("2b2118")
## Outer size of the disc on screen. The 1 px ink ring sits outside this fill.
const TICK_PX := 11.0
## P55 CP2 goods tint. air_coupons is the air good's name; the id on the station is "air".
const TINT := {
	"seeds": Color("7dba6a"),
	"pork": Color("7dba6a"),
	"salt": Color("7dba6a"),
	"copper": Color("c4a574"),
	"junk": Color("c4a574"),
	"water": Color("6f8494"),
	"air": Color("6f8494"),
	"air_coupons": Color("6f8494"),
	"heat": Color("e2a63a"),
}


static func secret(st: Dictionary) -> bool:
	return bool(st.get("hidden", false)) and not bool(st.get("known", false))


## Passage thread, foreign source, and a good actually flowing this week.
## good_flowing is the P55 path: held, or passage plus at least one deal. Held is refused here.
static func shows(game, sid: String) -> bool:
	if game == null or not game.stations.has(sid):
		return false
	if str(sid) == str(game.capital_id):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) == str(game.player):
		return false
	if secret(st) or not bool(st.get("known", false)):
		return false
	if not DealMarks.shows_thread(game, sid):
		return false
	if not game.has_method("good_flowing") or not game.good_flowing(sid):
		return false
	return true


static func good_id(game, sid: String) -> String:
	if game == null or not game.has_method("station_good"):
		return ""
	var good: Dictionary = game.station_good(sid)
	return str(good.get("id", ""))


## CP2 tint when the good id is known. Otherwise brass at 0.9.
static func tint_of(good_id: String) -> Color:
	if TINT.has(good_id):
		return TINT[good_id]
	var brass := BRASS
	brass.a = 0.9
	return brass


static func tint_for(game, sid: String) -> Color:
	return tint_of(good_id(game, sid))


## Midpoint of the passage segment. The view omits the tick when that thread was not drawn.
static func midpoint(a: Vector2, yard: Vector2) -> Vector2:
	return a.lerp(yard, 0.5)


## The tick never slides or pulses. Reduce-motion and full motion both stay still.
static func ticks_slide() -> bool:
	return false


static func good_name(game, sid: String) -> String:
	if game == null or not game.has_method("station_good"):
		return ""
	var good: Dictionary = game.station_good(sid)
	if good.is_empty():
		return ""
	var key := str(good.get("name_key", ""))
	if key == "":
		key = "good." + str(good.get("id", "")) + ".name"
	var name := Copy.t(key)
	if name == "" or name == key:
		return ""
	return name


## Tip only while the tick would paint. A quiet-passage line is not part of this pack.
static func tip_lines(game, sid: String) -> PackedStringArray:
	if not shows(game, sid):
		return PackedStringArray()
	var lines := PackedStringArray()
	lines.append(Copy.t("flow.tip"))
	var name := good_name(game, sid)
	if name != "":
		lines.append(Copy.fill("flow.good", {"good": name}))
	return lines


## First tick of a run. Sets flags.seen_passage_flow. Does not touch the dawn chip.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get("seen_passage_flow", false)):
		return ""
	var any := false
	for sid in game.stations:
		if shows(game, str(sid)):
			any = true
			break
	if not any:
		return ""
	game.flags["seen_passage_flow"] = true
	return Copy.t("flow.first")
