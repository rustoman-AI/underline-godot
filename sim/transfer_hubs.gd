class_name TransferHubs
extends RefCounted

## P84 Transfer Hubs. Derived identity for a player-owned junction.
## A hub is an owned station with at least three open passage edges.
## An open passage edge is an open tunnel (Game._neighbors / _edge_open) whose
## far station has passage=true and is not hidden, a bunker, or a ruin.
## Capital uses the same rule. Nothing here spends, grants, or joins soft dawn.

const NEED := 3


static func dawn_chip() -> bool:
	return false


static func barred(st: Dictionary) -> bool:
	if bool(st.get("hidden", false)):
		return true
	if str(st.get("bunker", "")) != "":
		return true
	if bool(st.get("ruin", false)):
		return true
	var owner := str(st.get("owner", ""))
	return owner == "bunker" or owner == "ruin"


## Far end of an open passage edge. The passage flag is the deal flag; owning
## the far station does not invent a passage. Hidden, bunker, and ruin ends never count.
static func passage_end(game, sid: String) -> bool:
	if game == null or sid == "" or not game.stations.has(sid):
		return false
	var st: Dictionary = game.stations[sid]
	if barred(st):
		return false
	return bool(st.get("passage", false))


static func degree(game, sid: String) -> int:
	if game == null or sid == "" or not game.stations.has(sid):
		return 0
	var n := 0
	for other in game._neighbors(sid):
		if passage_end(game, str(other)):
			n += 1
	return n


static func is_hub(game, sid: String) -> bool:
	if game == null or sid == "" or not game.stations.has(sid):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) != str(game.player):
		return false
	if barred(st):
		return false
	return degree(game, sid) >= NEED


static func hub_ids(game) -> Array:
	var ids: Array = []
	if game == null:
		return ids
	for sid in game.stations:
		var id := str(sid)
		if is_hub(game, id):
			ids.append(id)
	ids.sort()
	return ids


## Visit line. Owned stations that may be hubs, including the capital.
## Foreign, hidden, bunker, and ruin stations get nothing.
static func status_key(game, sid: String) -> String:
	if game == null or sid == "" or not game.stations.has(sid):
		return ""
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) != str(game.player) or barred(st):
		return ""
	if is_hub(game, sid):
		return "transfer.status"
	return "transfer.status_none"


static func tip_key(game, sid: String) -> String:
	var key := status_key(game, sid)
	if key == "transfer.status":
		return "transfer.tip"
	if key == "transfer.status_none":
		return "transfer.quiet"
	return ""


static func _stored(game) -> Array:
	var raw = game.flags.get("transfer_hub_sids", [])
	if raw is Array:
		return raw.duplicate()
	if raw is PackedStringArray:
		var copy: Array = []
		for sid in raw:
			copy.append(str(sid))
		return copy
	return []


static func _lost_any(prev: Array, now: Array) -> bool:
	for sid in prev:
		if not now.has(str(sid)):
			return true
	return false


## Nightly cache. The first call only remembers. A later shrink toasts once that week.
static func sync(game, announce := true) -> void:
	if game == null:
		return
	var now := hub_ids(game)
	var known: bool = bool(game.flags.has("transfer_hub_sids"))
	var prev := _stored(game)
	if announce and known and _lost_any(prev, now) and int(game.flags.get("transfer_lost_week", -999)) != int(game.week):
		game.flags["transfer_lost_week"] = int(game.week)
		game.notices.append(Copy.t("transfer.lost"))
	game.flags["transfer_hub_sids"] = now


## First hub of the run. The map float calls this. A quiet network does not set the flag.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get("seen_transfer_hub", false)):
		return ""
	if hub_ids(game).is_empty():
		return ""
	game.flags["seen_transfer_hub"] = true
	return Copy.t("transfer.first")
