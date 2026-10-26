class_name PinWarmth
extends RefCounted

## P46 lasting Network ring tint. Reads sympathy (and a join/capture flag). Never queues a dawn chip.

const COLD := Color("6f8494")
const WARY := Color("8c8170")
const WARM := Color("c4a574")
const READY := Color("e2a63a")
const JOIN_FALLBACK := Color("ff7a2f")
const RING_OUT := 2.5
const RING_WIDTH := 2.0
const RING_ALPHA := 0.92
const RING_SEGS := 28


static func secret(st: Dictionary) -> bool:
	return bool(st.get("hidden", false)) and not bool(st.get("known", false))


## Same known bar as station names, plus intel or a visited flag. Fogged stations stay out.
static func revealed(st: Dictionary) -> bool:
	if secret(st):
		return false
	if bool(st.get("known", false)):
		return true
	if bool(st.get("visited", false)):
		return true
	return int(st.get("intel", 0)) >= 1


static func joined_flag(st: Dictionary) -> bool:
	return bool(st.get("joined", false)) or bool(st.get("captured", false))


## cold / wary / warm / ready / join. Join wins on 100 or a joined/captured flag.
static func band_of(st: Dictionary) -> String:
	if joined_flag(st) or int(st.get("sympathy", 0)) >= 100:
		return "join"
	var sympathy := int(st.get("sympathy", 0))
	if sympathy >= 70:
		return "ready"
	if sympathy >= 50:
		return "warm"
	if sympathy >= 20:
		return "wary"
	return "cold"


static func band_key(band: String) -> String:
	return "warm." + band


## Depot / player join accent when the catalog has a colour. Otherwise the P22 join fallback.
static func join_color(game) -> Color:
	if game == null:
		return JOIN_FALLBACK
	var fid := str(game.player)
	var catalog = game.get("catalog")
	if catalog != null and catalog.factions.has(fid):
		var row: Dictionary = catalog.factions[fid]
		if row.has("color"):
			return Color(str(row.color))
	return JOIN_FALLBACK


static func color_of(game, st: Dictionary) -> Color:
	match band_of(st):
		"wary":
			return WARY
		"warm":
			return WARM
		"ready":
			return READY
		"join":
			return join_color(game)
		_:
			return COLD


static func ink(game, st: Dictionary) -> Color:
	var col := color_of(game, st)
	col.a = RING_ALPHA
	return col


## Known non-player stations only. Home and owned pins are left alone. Unknown stays untinted.
static func shows(game, sid: String) -> bool:
	if game == null or not game.stations.has(sid):
		return false
	if str(sid) == str(game.capital_id):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) == str(game.player):
		return false
	if not revealed(st):
		return false
	if not st.has("sympathy") and not joined_flag(st):
		return false
	return true


## Hover: band word, then the ring note. No numeric delta.
static func lines(game, sid: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not shows(game, sid):
		return out
	var st: Dictionary = game.stations[sid]
	var name := Copy.t(band_key(band_of(st)))
	out.append(Copy.fill("warm.band", {"band": name}))
	out.append(Copy.t("warm.tip"))
	return out


## First time this run a warmth tint would draw. Sets flags.seen_pin_warmth.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get("seen_pin_warmth", false)):
		return ""
	var any := false
	for sid in game.stations:
		if shows(game, str(sid)):
			any = true
			break
	if not any:
		return ""
	game.flags["seen_pin_warmth"] = true
	return Copy.t("warm.first")
