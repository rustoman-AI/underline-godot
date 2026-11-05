class_name TransferHubs
extends RefCounted

## P84 Transfer Hubs. A player-owned station is a Hub when three or more
## tunnels are open passages. Capital may qualify. Foreign, hidden, bunker,
## and ruin stations never do. The nightly cache is only the last derived set,
## so a loss can toast once. Soft dawn does not read this. No goods, hope, or mats.

const DEGREE_MIN := 3
const MARK_PX := 13.0
## Lower-outer L. Locked. Never shrunk, never shifted.
const MARK_SLOT := Vector2(-0.32, 0.22)
## Cited slots this pack does not draw. The mark is omitted when its rect meets any of them.
## P78 Relay letter R, lower-inner.
const RELAY_SLOT := Vector2(0.18, 0.16)
## P82 Signal crescent, upper-inner R.
const CRESCENT_SLOT := Vector2(0.30, -0.26)
## P57 focus letter, upper-inner L.
const FOCUS_SLOT := Vector2(-0.28, -0.30)
## Capital pin at schematic depth. Matches NetworkView PIN_CAPITAL, the 0.4 schematic lift, 0.42 radius, ZOOM_SPAN.
const PIN_CAPITAL := 52.0
const PIN_SCHEMATIC := 1.4
const PIN_RADIUS_OF_PX := 0.42
const ZOOM_SPAN := 3.5
const MARK_PATH := "res://assets/icons/map/transfer_mark_24.png"


static func joins_soft_dawn() -> bool:
	return false


static func open_degree(game, sid: String) -> int:
	if game == null or sid == "":
		return 0
	var n := 0
	for tunnel in game.tunnels:
		if not (tunnel is Dictionary):
			continue
		var a := str(tunnel.get("a", ""))
		var b := str(tunnel.get("b", ""))
		if a == b or (a != sid and b != sid):
			continue
		if not game._edge_open(tunnel):
			continue
		n += 1
	return n


static func _blocked(st: Dictionary) -> bool:
	if bool(st.get("hidden", false)):
		return true
	if str(st.get("bunker", "")) != "" or str(st.get("owner", "")) == "bunker":
		return true
	if bool(st.get("ruin", false)) or str(st.get("owner", "")) == "ruin":
		return true
	return false


static func owned(game, sid: String) -> bool:
	if game == null or not game.stations.has(sid):
		return false
	return str(game.stations[sid].get("owner", "")) == str(game.player)


## Player-owned, not foreign / hidden / bunker / ruin, open-passage degree at least 3.
static func is_hub(game, sid: String) -> bool:
	if not owned(game, sid):
		return false
	var st: Dictionary = game.stations[sid]
	if _blocked(st):
		return false
	return open_degree(game, sid) >= DEGREE_MIN


static func current_ids(game) -> Array:
	var out: Array = []
	if game == null:
		return out
	for sid in game.stations:
		var id := str(sid)
		if is_hub(game, id):
			out.append(id)
	out.sort()
	return out


## Rebuild the nightly cache. One lost toast when any cached Hub is no longer a Hub.
static func sync(game) -> void:
	if game == null:
		return
	var now := current_ids(game)
	var lost := false
	for sid in game.transfer_hub_sids:
		if not now.has(str(sid)):
			lost = true
			break
	game.transfer_hub_sids = now
	if lost:
		game.notices.append(Copy.t("transfer.lost"))


## Visit row. Empty when the station is not ours. status_none is muted.
static func visit_row(game, sid: String) -> Dictionary:
	if not owned(game, sid):
		return {"status": "", "tip": "", "muted": false}
	if is_hub(game, sid):
		return {"status": "transfer.status", "tip": "transfer.tip", "muted": false}
	return {"status": "transfer.status_none", "tip": "transfer.quiet", "muted": true}


## Hover is the tip only, and only while the Hub is live.
static func hover_lines(game, sid: String) -> PackedStringArray:
	var out := PackedStringArray()
	if is_hub(game, sid):
		out.append(Copy.t("transfer.tip"))
	return out


## First Hub of the run. Sets flags.seen_transfer_hub. Not a dawn chip.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get("seen_transfer_hub", false)):
		return ""
	var any := false
	for sid in game.stations:
		if is_hub(game, str(sid)):
			any = true
			break
	if not any:
		return ""
	game.flags["seen_transfer_hub"] = true
	return Copy.t("transfer.first")


static func max_pin_radius() -> float:
	return PIN_CAPITAL * PIN_SCHEMATIC * sqrt(ZOOM_SPAN) * PIN_RADIUS_OF_PX


static func mark_center(at: Vector2, pin_r: float) -> Vector2:
	return at + Vector2(MARK_SLOT.x * pin_r, MARK_SLOT.y * pin_r)


static func _center(at: Vector2, pin_r: float, slot: Vector2) -> Vector2:
	return at + Vector2(slot.x * pin_r, slot.y * pin_r)


static func _rect(center: Vector2, px: float) -> Rect2:
	return Rect2(center - Vector2(px, px) * 0.5, Vector2(px, px))


static func _overlap(a: Rect2, b: Rect2) -> bool:
	if not a.intersects(b, true):
		return false
	var hit := a.intersection(b)
	return hit.size.x > 0.5 and hit.size.y > 0.5


## True when a mark of MARK_PX at `slot` meets P78 R, P82 crescent, or P57 focus.
static func overlaps_slot(slot: Vector2, pin_r: float) -> bool:
	var at := Vector2.ZERO
	var mine := _rect(_center(at, pin_r, slot), MARK_PX)
	for other in [RELAY_SLOT, CRESCENT_SLOT, FOCUS_SLOT]:
		if _overlap(mine, _rect(_center(at, pin_r, other), MARK_PX)):
			return true
	return false


## Locked slot against the three cited rects at max pin radius. False means omit.
static func slot_clean() -> bool:
	return not overlaps_slot(MARK_SLOT, max_pin_radius())


static func texture_ready() -> bool:
	if not FileAccess.file_exists(MARK_PATH):
		return false
	var f := FileAccess.open(MARK_PATH, FileAccess.READ)
	if f == null:
		return false
	var head := f.get_buffer(24)
	f.close()
	if head.size() < 8:
		return false
	if head.get_string_from_ascii().find("git-lfs") >= 0:
		return false
	return head[0] == 0x89 and head[1] == 0x50 and head[2] == 0x4e and head[3] == 0x47


## Map mark only when the Hub is live, the locked slot is clean, and the plate exists.
static func shows_mark(game, sid: String) -> bool:
	return is_hub(game, sid) and slot_clean() and texture_ready()
