class_name RoomTrace
extends RefCounted

## P95 Room Trace. One muted glance on a built home room, plus the yard piles.
## Reads fields that already exist. Writes only flags.seen_room_trace when a line
## is shown. No dice rolls. No new sim field. Not a dawn chip. No map mark.
## A source pack that is not in this build leaves its line hidden. Do not stub it.
## Schema stays 21: the flag lives in the existing flags dict.

const FLAG := "seen_room_trace"
const ROOMS := ["infirmary", "quarters", "radio", "workshop"]
## FLAG-later, plus the Listening Post room itself (the radio line is the glance).
const SKIP := ["hydroponics", "air_filter", "generator", "meeting_hall", "platform", "listening_post"]
const PILES := ["rubble", "scrap", "coal"]

static var enabled := true


static func map_mark() -> bool:
	return false


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


## Existing state the lines are derived from. Printed by the gate.
static func fields_read() -> PackedStringArray:
	return PackedStringArray([
		"residents[].sick",
		"residents[].absent",
		"residents[].lent",
		"residents[].flushing_back",
		"residents[].on_run",
		"residents[].story_events[].pool",
		"Game.governor_of",
		"Game.listening_active",
		"rooms[listening_post].disabled",
		"chronicle[].kind",
		"Game.salvage_board",
		"cells[].pile",
	])


static func _built(game, room_type: String) -> bool:
	if game == null:
		return false
	for room in game.rooms:
		if typeof(room) == TYPE_DICTIONARY and str(room.get("type", "")) == room_type:
			return true
	return false


## Sick residents, plus people hurt at home (absent, injury note, not away on a posting).
static func cot_count(game) -> int:
	if game == null:
		return 0
	var n := 0
	for person in game.residents:
		if typeof(person) != TYPE_DICTIONARY:
			continue
		if int(person.get("sick", 0)) > 0:
			n += 1
			continue
		if _hurt_at_home(game, person):
			n += 1
	return n


static func _hurt_at_home(game, person: Dictionary) -> bool:
	if int(person.get("absent", 0)) <= 0 or not _marked_injured(person):
		return false
	var id := str(person.get("id", ""))
	if id != "" and str(game.governor_of(id)) != "":
		return false
	if bool(person.get("lent", false)):
		return false
	if int(person.get("flushing_back", 0)) > 0:
		return false
	if bool(person.get("on_run", false)):
		return false
	return true


static func _marked_injured(person: Dictionary) -> bool:
	var rows = person.get("story_events", [])
	if typeof(rows) != TYPE_ARRAY:
		return false
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("pool", "")) == "injured":
			return true
	return false


## P83 Guest Beds is not in this build. Zero hides the quarters line. No invented seats.
static func guest_occupied(game) -> int:
	if game == null or not game.has_method("guest_seats_occupied"):
		return 0
	return maxi(0, int(game.call("guest_seats_occupied")))


static func _listening_post(game) -> Dictionary:
	if game == null:
		return {}
	for room in game.rooms:
		if typeof(room) == TYPE_DICTIONARY and str(room.get("type", "")) == "listening_post":
			return room
	return {}


## Blown is the Listening Post disable that follows a listening_blown moment.
## Down, unstaffed, and switched off are not blown, and they do not get a line.
static func _post_blown(game, post: Dictionary) -> bool:
	if int(post.get("disabled", 0)) <= 0:
		return false
	var week := int(game.week)
	for row in game.chronicle:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("kind", "")) != "listening_blown":
			continue
		if int(row.get("week", -99)) >= week - 1:
			return true
	return false


static func radio_key(game) -> String:
	if game == null or not game.has_method("listening_active"):
		return ""
	var post := _listening_post(game)
	if post.is_empty():
		return ""
	if _post_blown(game, post):
		return "trace.radio.blown"
	if game.listening_active():
		return "trace.radio.up"
	return ""


## A salvage row is listed when a standing room can take the fit, or the fit is
## waiting on a blueprint. An empty board (no room, nothing fitted) stays quiet.
static func salvage_listed(game) -> bool:
	if game == null or not game.has_method("salvage_board"):
		return false
	for row in game.salvage_board():
		if typeof(row) != TYPE_DICTIONARY or bool(row.get("fitted", false)):
			continue
		if str(row.get("uid", "")) != "":
			return true
		var gate := str(row.get("gate", ""))
		if gate == "blueprint" or gate == "wait":
			return true
	return false


static func yard_count(game) -> int:
	if game == null:
		return 0
	var n := 0
	for key in game.cells:
		var cell = game.cells[key]
		if typeof(cell) != TYPE_DICTIONARY:
			continue
		if PILES.has(str(cell.get("pile", ""))):
			n += 1
	return n


## First uncleared pile, top level then left cell. The yard strip anchors here.
static func yard_spot(game) -> Dictionary:
	if game == null:
		return {}
	var best := {}
	var best_rank := 9999
	for key in game.cells:
		var cell = game.cells[key]
		if typeof(cell) != TYPE_DICTIONARY:
			continue
		if not PILES.has(str(cell.get("pile", ""))):
			continue
		var rank := int(cell.get("level", 0)) * 10 + int(cell.get("cell", 0))
		if rank < best_rank:
			best_rank = rank
			best = {"level": int(cell.get("level", 0)), "cell": int(cell.get("cell", 0))}
	return best


static func key_for(game, room_type: String) -> String:
	if not enabled or game == null or SKIP.has(room_type) or not _built(game, room_type):
		return ""
	match room_type:
		"infirmary":
			return "trace.infirmary" if cot_count(game) > 0 else ""
		"quarters":
			return "trace.quarters" if guest_occupied(game) > 0 else ""
		"radio":
			return radio_key(game)
		"workshop":
			return "trace.workshop" if salvage_listed(game) else ""
		_:
			return ""


static func line_for(game, room_type: String) -> String:
	var key := key_for(game, room_type)
	if key == "":
		return ""
	if key == "trace.infirmary":
		return Copy.fill(key, {"n": cot_count(game)})
	if key == "trace.quarters":
		return Copy.fill(key, {"n": guest_occupied(game)})
	return Copy.t(key)


static func yard_line(game) -> String:
	if not enabled:
		return ""
	var n := yard_count(game)
	if n <= 0:
		return ""
	return Copy.fill("trace.yard", {"n": n})


static func shows_any(game) -> bool:
	if yard_line(game) != "":
		return true
	for room_type in ROOMS:
		if line_for(game, room_type) != "":
			return true
	return false


static func tip() -> String:
	return Copy.t("trace.tip")


## First time any trace line is shown this run. Not a dawn chip.
static func claim_first(game) -> String:
	if not enabled or game == null:
		return ""
	if bool(game.flags.get(FLAG, false)):
		return ""
	if not shows_any(game):
		return ""
	game.flags[FLAG] = true
	return Copy.t("trace.first")
