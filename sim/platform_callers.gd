class_name PlatformCallers
extends RefCounted

## P93 Platform Callers. Text plus a saved occupancy dict. Balance ZERO.
## No food, mats, hope, air, tokens, opinion, sympathy, or loyalty deltas.
## No rng / net_rng / story_rng / check_rng / crunch_rng draws.
## Nothing in the sim reads `callers` for an outcome. Bots never read it.
## Soft dawn: none. Map mark: none. `caller.first` is a P61 first-float, not a dawn chip.
##
## Schema 24 adds `callers` after the line-echo and rival-desk saves.
## Schema <= 23 fills an empty callers dict and keeps keys already in the file.
## Do not renumber.
##
## Synod "deal" is the first P80 favor spend. P80 is not on this branch, so
## `favor_on()` stays false and that trigger never fires. When P80 lands, call
## `note_favor_spend(game)` from the successful spend and expose `enabled` on
## `res://sim/synod_favor.gd`.

const SEEN := "seen_callers"
const FACTIONS: Array = ["exchange", "directorate", "synod"]
const QUEUE_CAP := 3
const COOLDOWN := 4
const STAY := 1
## Gate flips this off to prove the hooks do not move a careful run. The game leaves it on.
static var enabled := true
## null asks P80. true/false forces the Synod favor trigger for the gate only.
static var favor_override = null


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func map_mark() -> bool:
	return false


static func blank() -> Dictionary:
	return {"here": "", "until": 0, "why": "", "seen": {}, "cool_until": {}, "queue": []}


## Same cuts as NetworkView._band_key. Warm or better is opinion >= 50.
static func band_name(opinion: int) -> String:
	if opinion >= 100:
		return "join"
	if opinion >= 70:
		return "ready"
	if opinion >= 50:
		return "warm"
	if opinion >= 20:
		return "wary"
	return "cold"


static func warm_or_better(opinion: int) -> bool:
	return opinion >= 50


static func favor_on() -> bool:
	if favor_override != null:
		return bool(favor_override)
	if not ResourceLoader.exists("res://sim/synod_favor.gd"):
		return false
	var script = load("res://sim/synod_favor.gd")
	if script == null:
		return false
	return bool(script.get("enabled"))


## First time a rival faction's opinion is warm or better. Does not write the opinion.
static func note_opinions(game) -> void:
	if not enabled or game == null:
		return
	var opinions = game.get("opinions")
	if not (opinions is Dictionary):
		return
	for fid in FACTIONS:
		if warm_or_better(int(opinions.get(fid, 0))):
			_fire(game, str(fid), "warm")


## Exchange / Directorate station deal only. Synod deals are favor spends.
static func note_deal(game, fid: String) -> void:
	if fid != "exchange" and fid != "directorate":
		return
	_fire(game, fid, "deal")


## Player-started raid or assault, win or loss, against a station this faction owns.
static func note_hit(game, fid: String) -> void:
	_fire(game, fid, "hit")


## P80 Synod favor spend. No-op while that pack is off.
static func note_favor_spend(game) -> void:
	if not favor_on():
		return
	_fire(game, "synod", "deal")


## Dawn, after the week counter has moved and before this dawn's orders resolve.
## Last week's caller leaves. The head of the queue sits if their offer week has
## come, the seat is empty, and their cooldown has expired. FIFO: a head who is
## early or still cooling holds everyone behind them.
static func tick(game) -> void:
	if not enabled or game == null:
		return
	var book := _ensure(game)
	var here := str(book.get("here", ""))
	if here != "" and int(game.week) >= int(book.get("until", 0)):
		var cool: Dictionary = book.cool_until
		cool[here] = int(game.week) + COOLDOWN
		book.cool_until = cool
		book.here = ""
		book.until = 0
		book.why = ""
		game.caller_left_toast = true
		here = ""
	if here != "":
		return
	var queue: Array = book.queue
	if queue.is_empty():
		return
	var head = queue[0]
	if not (head is Dictionary):
		queue.pop_front()
		book.queue = queue
		return
	if int(head.get("offer", 0)) > int(game.week):
		return
	var fid := str(head.get("fid", ""))
	if not _cooled(book, fid, int(game.week)):
		return
	queue.pop_front()
	book.queue = queue
	book.here = fid
	book.why = str(head.get("why", ""))
	book.until = int(game.week) + STAY


## The seated courier, or {} when the row should hide.
static func card(game) -> Dictionary:
	if not enabled or game == null:
		return {}
	var book := _ensure(game)
	var fid := str(book.get("here", ""))
	var why := str(book.get("why", ""))
	if fid == "" or not FACTIONS.has(fid):
		return {}
	if int(game.week) >= int(book.get("until", 0)):
		return {}
	if why != "warm" and why != "deal" and why != "hit":
		return {}
	return {
		"fid": fid,
		"why": why,
		"name_key": "caller.%s.name" % fid,
		"role_key": "caller.%s.role" % fid,
		"line_key": "caller.%s.%s" % [fid, why],
		"title_key": "caller.title",
		"tip_key": "caller.tip",
		"portrait": "caller_%s" % fid,
	}


## First caller this run. Sets flags.seen_callers. Not a dawn chip.
static func claim_first(game) -> String:
	if not enabled or game == null:
		return ""
	if bool(game.flags.get(SEEN, false)):
		return ""
	if card(game).is_empty():
		return ""
	game.flags[SEEN] = true
	return Copy.t("caller.first")


static func _fire(game, fid: String, why: String) -> void:
	if not enabled or game == null:
		return
	if not FACTIONS.has(fid):
		return
	if why != "warm" and why != "deal" and why != "hit":
		return
	var book := _ensure(game)
	var seen: Dictionary = book.seen
	var have: Array = seen.get(fid, [])
	if typeof(have) != TYPE_ARRAY:
		have = []
	if have.has(why):
		return
	have = have.duplicate()
	have.append(why)
	seen[fid] = have
	book.seen = seen
	var queue: Array = book.queue
	if queue.size() >= QUEUE_CAP:
		return
	queue.append({"fid": fid, "why": why, "offer": int(game.week) + 1})
	book.queue = queue


static func _cooled(book: Dictionary, fid: String, week: int) -> bool:
	var cool: Dictionary = book.get("cool_until", {})
	if not (cool is Dictionary):
		return true
	return week >= int(cool.get(fid, 0))


static func _ensure(game) -> Dictionary:
	var raw = game.get("callers")
	if not (raw is Dictionary):
		game.callers = blank()
		return game.callers
	var fresh := blank()
	for key in fresh:
		if not raw.has(key):
			raw[key] = fresh[key]
	if not (raw.seen is Dictionary):
		raw.seen = {}
	if not (raw.cool_until is Dictionary):
		raw.cool_until = {}
	if not (raw.queue is Array):
		raw.queue = []
	return raw
