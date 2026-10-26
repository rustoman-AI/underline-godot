class_name NeedTick
extends RefCounted

## P49 lasting need tick. Spawned only when an envoy resolve improves a station need.
## Two-week TTL. Never queues a dawn chip and never reads propaganda, deal, aid, or drift.

const CHALK := Color("d7e0d2")
const INK := Color("3e5244")
const TTL_WEEKS := 2
## Upper-left when the pip row is empty (leaflet, if any, sits lower-right).
const OPEN := Vector2(-0.98, -1.14)
## Lower-left once brass pips are out, so the tick stays off that row and off the leaflet scrap.
const CROWDED := Vector2(-1.42, 0.22)


static func until_of(st: Dictionary) -> int:
	return int(st.get("need_tick_until_week", 0))


static func id_of(st: Dictionary) -> String:
	return str(st.get("need_tick_id", ""))


static func clear_station(st: Dictionary) -> void:
	st.erase("need_tick_id")
	st.erase("need_tick_until_week")


## Envoy resolve only. Caller passes the need fill from before and after the existing bump.
static func arm(game, sid: String, need_id: String, before: float, after: float) -> void:
	if game == null or not game.stations.has(sid):
		return
	if after <= before + 0.0001:
		return
	if str(need_id) == "":
		return
	if str(sid) == str(game.capital_id):
		return
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) == str(game.player):
		return
	if bool(st.get("joined", false)) or bool(st.get("captured", false)):
		return
	st["need_tick_id"] = str(need_id)
	st["need_tick_until_week"] = int(game.week) + TTL_WEEKS


static func _should_clear(game, sid: String, st: Dictionary, until: int) -> bool:
	if until <= int(game.week):
		return true
	if id_of(st) == "":
		return true
	if str(sid) == str(game.capital_id):
		return true
	if str(st.get("owner", "")) == str(game.player):
		return true
	if bool(st.get("joined", false)) or bool(st.get("captured", false)):
		return true
	return false


## Drops a TTL that has expired or a station that joined or was captured.
## Unknown stations keep the TTL and simply do not draw.
static func settle(game, sid: String) -> void:
	if game == null or not game.stations.has(sid):
		return
	var st: Dictionary = game.stations[sid]
	var until := until_of(st)
	if until <= 0 and id_of(st) == "":
		return
	if until <= 0 or _should_clear(game, sid, st, until):
		clear_station(st)
		return
	st["need_tick_id"] = id_of(st)
	st["need_tick_until_week"] = until


static func settle_all(game) -> void:
	if game == null:
		return
	for sid in game.stations:
		settle(game, str(sid))


## Known non-player stations only, and only while the TTL is still ahead.
static func shows(game, sid: String) -> bool:
	if game == null or not game.stations.has(sid):
		return false
	settle(game, sid)
	var st: Dictionary = game.stations[sid]
	if until_of(st) <= int(game.week):
		return false
	if id_of(st) == "":
		return false
	if str(sid) == str(game.capital_id):
		return false
	if str(st.get("owner", "")) == str(game.player):
		return false
	if bool(st.get("joined", false)) or bool(st.get("captured", false)):
		return false
	if not bool(st.get("known", false)):
		return false
	if bool(st.get("hidden", false)) and not bool(st.get("known", false)):
		return false
	return true


## Visit need row for the improved need only. Other needs on the same station stay plain.
static func shows_need(game, sid: String, need_id: String) -> bool:
	if str(need_id) == "" or not shows(game, sid):
		return false
	return id_of(game.stations[sid]) == str(need_id)


## Above the pip row, or lower-left once that row is occupied. Frameless; no pulse.
static func slot(at: Vector2, pin_r: float, crowded: bool) -> Vector2:
	var rel := CROWDED if crowded else OPEN
	return at + Vector2(rel.x * pin_r, rel.y * pin_r)


static func mark_px(pin_r: float) -> float:
	return clampf(pin_r * 0.5, 6.0, 8.0)


## Two segments of a check. Same points every call — the tick never bounces.
static func tick_points(origin: Vector2, size: float) -> PackedVector2Array:
	var s := maxf(size, 1.0)
	return PackedVector2Array([
		origin + Vector2(s * 0.18, s * 0.52),
		origin + Vector2(s * 0.40, s * 0.78),
		origin + Vector2(s * 0.84, s * 0.22),
	])


static func bounces() -> bool:
	return false


## Hover. Compact is the reduce-motion readout. No numeric delta.
static func lines(game, sid: String, compact: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if not shows(game, sid):
		return out
	if compact:
		out.append(Copy.t("need.reduce"))
		return out
	out.append(Copy.t("need.label"))
	out.append(Copy.t("need.tick"))
	return out


static func tip(compact: bool) -> String:
	if compact:
		return Copy.t("need.reduce")
	return Copy.t("need.tick")


static func caption(compact: bool) -> String:
	if compact:
		return Copy.t("need.reduce")
	return Copy.t("need.label")


## First time this run a need tick would draw. Sets flags.seen_need_tick.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get("seen_need_tick", false)):
		return ""
	var any := false
	for sid in game.stations:
		if shows(game, str(sid)):
			any = true
			break
	if not any:
		return ""
	game.flags["seen_need_tick"] = true
	return Copy.t("need.first")
