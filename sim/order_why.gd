class_name OrderWhy
extends RefCounted

## P65 Order Why. Report-only: one short tip for a disabled covered order.
## First true blocker wins. Does not change gate formulas, costs, or balance.
## No tween — the tip is static text, including when reduce-motion is on.
## Never a soft dawn chip. approach.need is cited from P63 and is not invented here.
## why.influence is not a locked key: an influence shortfall keeps today's live tip.

const COVERED := {
	"dig": true,
	"build": true,
	"clear": true,
	"rally": true,
	"trade": true,
	"move": true,
	"expedition": true,
	"approach": true,
}

## Pri 1 → 6. Order-specific names share pri 5 in this order. Approach is last.
const ORDER := [
	"workers",
	"materials",
	"orders",
	"blocked",
	"trade_opinion",
	"trade_on",
	"power",
	"food",
	"party_away",
	"already",
	"approach",
]


static func covers(kind: String) -> bool:
	return bool(COVERED.get(kind, false))


## "" when no locked key applies (enabled, uncovered, influence gap, or approach.need not shipped).
static func first_key(flags: Dictionary) -> String:
	for name in ORDER:
		if not bool(flags.get(name, false)):
			continue
		if str(name) == "approach":
			return "approach.need"
		return "why.%s" % str(name)
	return ""


## Translated short reason, or "" when the caller should keep the live tip.
static func tip(game, kind: String, ctx: Dictionary = {}) -> String:
	if game == null or not covers(kind):
		return ""
	var key := first_key(_flags(game, kind, ctx))
	if key == "":
		return ""
	if key == "approach.need" and not Copy.keys.has("approach.need"):
		return ""
	return Copy.t(key)


## Short reason when one is locked; otherwise the live line the gate already produced.
static func show(game, kind: String, live: String, ctx: Dictionary = {}) -> String:
	var short := tip(game, kind, ctx)
	return short if short != "" else live


static func _flags(game, kind: String, ctx: Dictionary) -> Dictionary:
	match kind:
		"dig":
			return _dig_flags(game, ctx)
		"build":
			return _build_flags(game, ctx)
		"clear":
			return _clear_flags(game, ctx)
		"rally":
			return _rally_flags(game)
		"trade":
			return _trade_flags(game, str(ctx.get("sid", "")))
		"move":
			return _move_flags(game, str(ctx.get("sid", "")))
		"expedition":
			return _expedition_flags(game)
		"approach":
			return _approach_flags(game)
	return {}


static func _council(game, flags: Dictionary) -> void:
	if game.order_councillor().is_empty():
		flags["workers"] = true
	if int(game.orders_left) <= 0:
		flags["orders"] = true


static func _dig_flags(game, ctx: Dictionary) -> Dictionary:
	var flags := {}
	var level := int(ctx.get("level", -1))
	var cell := int(ctx.get("cell", -1))
	var key := str(game._ck(level, cell))
	if not game.cells.has(key):
		flags["blocked"] = true
		return flags
	var spot: Dictionary = game.cells[key]
	if bool(spot.get("dug", false)):
		flags["already"] = true
		return flags
	if not game._beside_dug(spot):
		flags["blocked"] = true
		return flags
	if not game.clear.is_empty() or not game.dig.is_empty():
		flags["workers"] = true
	var cost: Dictionary = game._dig_cost(level)
	if int(game._free_count()) < int(cost.get("workers", 0)):
		flags["workers"] = true
	if int(game.stock.get("materials", 0)) < int(game.dig_material_cost()):
		flags["materials"] = true
	return flags


static func _build_flags(game, ctx: Dictionary) -> Dictionary:
	var flags := {}
	var type := str(ctx.get("type", ""))
	var level := int(ctx.get("level", -1))
	var cell := int(ctx.get("cell", -1))
	var defin: Dictionary = game.catalog.rooms.get(type, {})
	if defin.is_empty() or not bool(defin.get("buildable", false)):
		flags["blocked"] = true
		return flags
	var key := str(game._ck(level, cell))
	var spot: Dictionary = game.cells.get(key, {})
	var structural: bool = spot.is_empty() or not bool(game._cell_buildable(spot))
	if structural:
		flags["blocked"] = true
	if not game.build.is_empty():
		flags["workers"] = true
	if structural:
		return flags
	if int(game.stock.get("materials", 0)) < int(defin.get("materials", 0)):
		flags["materials"] = true
	if int(game._free_count()) < int(game.bal.build_workers):
		flags["workers"] = true
	if type == "listening_post" and str(game.listening_build_block()) != "":
		flags["blocked"] = true
	var cap := int(defin.get("max", 0))
	if cap > 0 and int(game.room_count(type)) >= cap:
		flags["already"] = true
	return flags


static func _clear_flags(game, ctx: Dictionary) -> Dictionary:
	var flags := {}
	var level := int(ctx.get("level", -1))
	var cell := int(ctx.get("cell", -1))
	var key := str(game._ck(level, cell))
	if not game.cells.has(key):
		flags["blocked"] = true
		return flags
	var spot: Dictionary = game.cells[key]
	var pile := str(spot.get("pile", ""))
	if pile == "" or not game.PILE.has(pile):
		flags["already"] = true
		return flags
	if not game.dig.is_empty() or not game.clear.is_empty():
		flags["workers"] = true
	var row: Dictionary = game.PILE[pile]
	var mats := int(row.get("materials", 0))
	if mats > 0 and int(game.stock.get("materials", 0)) < mats:
		flags["materials"] = true
	if int(game._free_count()) < int(row.get("crew", 2)):
		flags["workers"] = true
	return flags


static func _hall_has_crew(game) -> bool:
	var need := int(game.catalog.rooms["meeting_hall"].get("staff_min", 1))
	for room in game.rooms:
		if str(room.get("type", "")) != "meeting_hall":
			continue
		var staff: Array = room.get("staff", [])
		if staff.size() >= need:
			return true
	return false


static func _rally_flags(game) -> Dictionary:
	var flags := {}
	if int(game.room_count("meeting_hall")) <= 0:
		flags["blocked"] = true
	elif not game._room_ready("meeting_hall"):
		if _hall_has_crew(game):
			flags["blocked"] = true
		else:
			flags["workers"] = true
	if int(game.rally_lock) > 0:
		flags["already"] = true
	return flags


static func _trade_flags(game, sid: String) -> Dictionary:
	var flags := {}
	_council(game, flags)
	if sid == "":
		if bool(game.trade_on):
			flags["trade_on"] = true
		if int(game.opinions.get("exchange", -100)) < 0:
			flags["trade_opinion"] = true
		return flags
	if not game.stations.has(sid) or not game.borders_player(sid):
		flags["blocked"] = true
		return flags
	var st: Dictionary = game.stations[sid]
	var owner := str(st.get("owner", ""))
	if owner == str(game.player):
		flags["already"] = true
		return flags
	if owner == "bunker" or owner == "ruin" or owner == "enemy" or bool(st.get("hidden", false)) or str(st.get("bunker", "")) != "":
		flags["blocked"] = true
		return flags
	if int(game.combat_lock.get(owner, 0)) > int(game.week):
		flags["blocked"] = true
		return flags
	if int(st.get("deals", 0)) >= 3:
		flags["already"] = true
	return flags


static func _move_flags(game, dest: String) -> Dictionary:
	var flags := {}
	_council(game, flags)
	var sq: Dictionary = game.squads.get(game.player, {})
	var away := bool(sq.get("away", false))
	if away:
		flags["party_away"] = true
	if not game.stations.has(dest):
		flags["blocked"] = true
		return flags
	var path: Array = game._path(str(sq.get("station", "")), dest)
	if path.size() < 2:
		flags["blocked"] = true
		return flags
	if away:
		return flags
	var nxt := str(path[1])
	if str(game.stations[nxt].get("owner", "")) != str(game.player) and int(game.soldier_count()) < int(game.bal.guard.move_min):
		flags["workers"] = true
	if int(game.stock.get("food", 0)) < int(game.move_food(dest)):
		flags["food"] = true
	return flags


static func _expedition_flags(game) -> Dictionary:
	var flags := {}
	_council(game, flags)
	var sq: Dictionary = game.squads.get(game.player, {})
	var away := bool(sq.get("away", false)) or str(sq.get("station", "")) != str(game.capital_id)
	if not game.expedition.is_empty():
		flags["already"] = true
	if away:
		flags["party_away"] = true
	if game.expedition.is_empty() and not away and int(game.soldier_count()) < int(game.bal.guard.move_min):
		flags["workers"] = true
	var tunnel: Dictionary = game._tunnel_by_id("to_ferry")
	if tunnel.is_empty() or bool(tunnel.get("dug", false)):
		flags["already"] = true
	return flags


static func _approach_flags(game) -> Dictionary:
	var flags := {}
	_council(game, flags)
	if bool(game.floor_met) or int(game.artifacts.get("papers", 0)) < 1:
		flags["approach"] = true
		return flags
	var tunnel: Dictionary = game._tunnel_by_id("to_floor")
	if tunnel.is_empty() or not bool(tunnel.get("dug", false)):
		flags["approach"] = true
	return flags
