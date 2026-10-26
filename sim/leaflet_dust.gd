class_name LeafletDust
extends RefCounted

## P47 lasting leaflet scrap. Spawned only when propaganda resolves at sympathy >= 70.
## Two-week TTL. Never queues a dawn chip and never reads envoy, deal, or drift.

const PAPER := Color("efe4c8")
const INK := Color("2b2118")
const READY := 70
const COOL := 50
const TTL_WEEKS := 2
## Pin radius is 0.42 of the pin sprite. The scrap is a quarter of that sprite.
const PIN_RADIUS_OF_PX := 0.42
const CHIP_OF_PIN := 0.25
## Beside the under-pin pip row. Crowded pins move the scrap above that row.
const NEAR := Vector2(0.95, 0.72)
const OPPOSITE := Vector2(-0.55, -1.08)


static func until_of(st: Dictionary) -> int:
	if st.has("leaflet_until_week"):
		return int(st.get("leaflet_until_week", 0))
	return int(st.get("leaflet_until", 0))


static func clear_station(st: Dictionary) -> void:
	st.erase("leaflet_until_week")
	st.erase("leaflet_until")


## Propaganda resolve only. Caller has already checked after-sympathy >= 70 and that the station did not join.
static func arm(game, sid: String) -> void:
	if game == null or not game.stations.has(sid):
		return
	if str(sid) == str(game.capital_id):
		return
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) == str(game.player):
		return
	if bool(st.get("joined", false)) or bool(st.get("captured", false)):
		return
	if int(st.get("sympathy", 0)) < READY:
		return
	var until := int(game.week) + TTL_WEEKS
	st["leaflet_until_week"] = until
	st["leaflet_until"] = until


static func _should_clear(game, sid: String, st: Dictionary, until: int) -> bool:
	if until <= int(game.week):
		return true
	if int(st.get("sympathy", 0)) < COOL:
		return true
	if str(sid) == str(game.capital_id):
		return true
	if str(st.get("owner", "")) == str(game.player):
		return true
	if bool(st.get("joined", false)) or bool(st.get("captured", false)):
		return true
	return false


## Drops a TTL that has expired, cooled below 50, or lost the pin to a join/capture.
## Unknown stations keep the TTL and simply do not draw.
static func settle(game, sid: String) -> void:
	if game == null or not game.stations.has(sid):
		return
	var st: Dictionary = game.stations[sid]
	var until := until_of(st)
	if until <= 0:
		if st.has("leaflet_until_week") or st.has("leaflet_until"):
			clear_station(st)
		return
	if _should_clear(game, sid, st, until):
		clear_station(st)
		return
	st["leaflet_until_week"] = until
	st["leaflet_until"] = until


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
	if str(sid) == str(game.capital_id):
		return false
	if str(st.get("owner", "")) == str(game.player):
		return false
	if bool(st.get("joined", false)) or bool(st.get("captured", false)):
		return false
	if int(st.get("sympathy", 0)) < COOL:
		return false
	if not bool(st.get("known", false)):
		return false
	if bool(st.get("hidden", false)) and not bool(st.get("known", false)):
		return false
	return true


## Quarter of the pin sprite, in pixels.
static func chip_px(pin_r: float) -> float:
	if pin_r <= 0.0:
		return 8.0
	return maxf(6.0, (pin_r / PIN_RADIUS_OF_PX) * CHIP_OF_PIN)


## Near the pip row, or above it when brass pips already occupy that side.
static func slot(at: Vector2, pin_r: float, crowded: bool) -> Vector2:
	var rel := OPPOSITE if crowded else NEAR
	return at + Vector2(rel.x * pin_r, rel.y * pin_r)


## Hover. Compact is the reduce-motion readout. No numeric delta.
static func lines(game, sid: String, compact: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if not shows(game, sid):
		return out
	if compact:
		out.append(Copy.t("leaf.reduce"))
		return out
	out.append(Copy.t("leaf.label"))
	out.append(Copy.t("leaf.tip"))
	return out


## The scrap never flutters, in full motion or reduce-motion.
static func flutters() -> bool:
	return false


## First time this run a leaflet chip would draw. Sets flags.seen_leaflet_dust.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get("seen_leaflet_dust", false)):
		return ""
	var any := false
	for sid in game.stations:
		if shows(game, str(sid)):
			any = true
			break
	if not any:
		return ""
	game.flags["seen_leaflet_dust"] = true
	return Copy.t("leaf.first")
