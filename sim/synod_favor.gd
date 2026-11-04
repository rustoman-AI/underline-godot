class_name SynodFavor
extends RefCounted

## P80 Synod Favor. A thin spend on Game.synod. State lives in flags so the save schema stays put.
## Soft dawn is not joined. Costs are the SPEC figures. No new combat system and no creed fork.

const LISTEN := 10
const COOLDOWN_WEEKS := 2
const ESCORT_WEEKS := 4
const CHRONICLE_WEIGHT := 1
const IDS := ["blessing", "escort_tip", "quiet_week"]
const COST := {"blessing": 8, "escort_tip": 10, "quiet_week": 12}
## Expander may buy a blessing when the meter is high and hope is low. Careful never spends.
const EXPANDER_SYNOD := 18
const EXPANDER_HOPE := 40


static func cost(id: String) -> int:
	return int(COST.get(id, 0))


static func label_key(id: String) -> String:
	return "favor." + id


static func tip_key(id: String) -> String:
	if id == "escort_tip":
		return "favor.escort_tip_tip"
	return "favor.%s_tip" % id


static func open(game) -> bool:
	return game != null and int(game.synod) >= LISTEN


static func cooldown_n(game) -> int:
	if game == null:
		return 0
	if not game.flags.has("favor_week"):
		return 0
	return maxi(0, int(game.flags.get("favor_week", 0)) + COOLDOWN_WEEKS - int(game.week))


static func block(game, id: String) -> String:
	if not IDS.has(id):
		return "id"
	if not open(game):
		return "closed"
	if cooldown_n(game) > 0:
		return "cooldown"
	if int(game.synod) < cost(id):
		return "cost"
	return ""


## One-click spend. Returns ok, the spent toast, and the first-float line (empty after the first).
static func spend(game, id: String) -> Dictionary:
	var why := block(game, id)
	if why != "":
		return {"ok": false, "why": why, "toast": "", "float": "", "id": id}
	var name := Copy.t(label_key(id))
	game.synod = int(game.synod) - cost(id)
	game.flags["favor_week"] = int(game.week)
	var first := not bool(game.flags.get("seen_synod_favor", false))
	game.flags["seen_synod_favor"] = true
	if id == "blessing":
		game._add_hope(1, "favor")
		game._add_discontent(-1, "favor")
	elif id == "escort_tip":
		game.flags["favor_escort_until"] = int(game.week) + ESCORT_WEEKS
	elif id == "quiet_week":
		game.flags["favor_quiet"] = true
	game._note_moment("favor", {"favor": name, "id": id}, CHRONICLE_WEIGHT)
	return {
		"ok": true,
		"why": "",
		"toast": Copy.fill("favor.spent", {"favor": name}),
		"float": Copy.t("favor.first") if first else "",
		"id": id,
		"favor": name,
	}


## Next dawn only. True when the drawn card is a weighted major faction knock and should not be presented.
## A draw that is not one of those consumes the favor and lets the card through (no extra toast; no refund).
static func skip_pressure(game, ev: Dictionary) -> bool:
	if game == null or not bool(game.flags.get("favor_quiet", false)):
		return false
	game.flags["favor_quiet"] = false
	var skipped := pressure_event(ev)
	game.flags["favor_quiet_result"] = "skip" if skipped else "noop"
	return skipped


static func pressure_event(ev: Dictionary) -> bool:
	if not bool(ev.get("major", false)):
		return false
	if int(ev.get("weight", 0)) <= 0:
		return false
	if ev.has("needs") or ev.has("trigger") or bool(ev.get("chain_only", false)):
		return false
	var id := str(ev.get("id", ""))
	var banner := str(ev.get("banner", ""))
	if id == "toll" or id.begins_with("toll") or id == "knock" or id.begins_with("knock"):
		return true
	return banner == "toll" or banner == "knock"


## Existing fight term, one point, for the next player raid or tunnel fight on a Synod-lean or owned path.
static func escort_applies(game, sq: Dictionary, sid: String) -> bool:
	var until := int(game.flags.get("favor_escort_until", 0))
	if until <= 0 or int(game.week) >= until:
		return false
	if str(sq.get("faction", "")) != str(game.player):
		return false
	return _path_ok(game, sid)


static func consume_escort(game) -> void:
	game.flags.erase("favor_escort_until")


## Dawn after the window, and only if no qualifying fight consumed it. No refund.
static func expire_escort(game) -> void:
	var until := int(game.flags.get("favor_escort_until", 0))
	if until <= 0 or int(game.week) < until:
		return
	game.flags.erase("favor_escort_until")
	game.notices.append(Copy.t("favor.expire"))


static func bot_may_bless(game, profile: String) -> bool:
	if profile != "expander":
		return false
	if int(game.synod) < EXPANDER_SYNOD or int(game.hope) >= EXPANDER_HOPE:
		return false
	return block(game, "blessing") == ""


static func _path_ok(game, sid: String) -> bool:
	if not game.stations.has(sid):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) == "synod" or str(st.get("lean", "")) == "faith":
		return true
	if str(st.get("owner", "")) == str(game.player):
		return true
	if game.squads.has(game.player):
		var origin := str(game.squads[game.player].get("station", ""))
		if origin != "" and game.stations.has(origin) and str(game.stations[origin].get("owner", "")) == str(game.player):
			return true
	return false
