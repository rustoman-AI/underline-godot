class_name OutpostLedger
extends RefCounted

## P85 Outpost Ledger. Last week's flow for one owned outpost, recomputed from state
## the delivery already used. Reads only. Writes nothing. No RNG. No new fields.
##
## mats = flow.materials - flow.upkeep_materials
## food = flow.food
## goods = flow.tokens + flow.influence + flow.air
## Age is stations[sid].held_weeks, the age _deliver_outposts already applied.
## A station with no delivery yet, a zero flow, or inputs that moved this week stays hidden.

const FLAG := "seen_outpost_ledger"


static func map_mark() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


## Existing state the flow is derived from. Printed by the gate.
static func fields_read() -> PackedStringArray:
	return PackedStringArray([
		"stations[sid].held_weeks",
		"stations[sid].focus",
		"stations[sid].governor",
		"Game._supply_hops",
		"catalog.station_goods",
		"Formulas.outpost_flow",
		"Game.governor_bonus",
		"Game.governor_settle",
		"Game._with_food_focus_bonus",
		"flow.materials",
		"flow.upkeep_materials",
		"flow.food",
		"flow.tokens",
		"flow.influence",
		"flow.air",
	])


static func _owned_visible(game, sid: String) -> bool:
	if game == null or str(sid) == "" or not game.stations.has(sid):
		return false
	if str(sid) == str(game.capital_id):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) != str(game.player):
		return false
	if bool(st.get("hidden", false)):
		return false
	return true


## Focus or governor changed after last dawn, so the stored inputs are not last week's.
static func _inputs_moved(game, sid: String) -> bool:
	var st: Dictionary = game.stations[sid]
	var name := str(st.get("name", ""))
	var week := int(game.week)
	var focus_prefix := "ORDER %s focuses on " % name
	var recall_tail := " from %s" % name
	for entry in game.log:
		if typeof(entry) != TYPE_DICTIONARY or int(entry.get("week", -1)) != week:
			continue
		var text := str(entry.get("text", ""))
		if name != "" and (text.begins_with(focus_prefix) or (text.begins_with("RECALL ") and text.ends_with(recall_tail))):
			return true
	for row in game.journal:
		if typeof(row) != TYPE_DICTIONARY or int(row.get("week", -1)) != week:
			continue
		if str(row.get("kind", "")) == "governor" and str(row.get("station", "")) == str(sid):
			return true
	return false


## The flow dict _deliver_outposts would have applied at the last dawn, from current inputs.
## Empty when this outpost has not been through a delivery.
static func _flow(game, sid: String) -> Dictionary:
	var st: Dictionary = game.stations[sid]
	var age := int(st.get("held_weeks", 0))
	if age < 1:
		return {}
	var focus := str(st.get("focus", ""))
	var gov := str(st.get("governor", ""))
	var flow := Formulas.outpost_flow(age, int(game._supply_hops(str(sid))), focus, int(game.governor_bonus(gov, focus)), int(game.governor_settle(gov)), game.catalog.station_goods(str(sid)))
	return game._with_food_focus_bonus(flow, focus)


static func amounts(game, sid: String) -> Dictionary:
	var blank := {"mats": 0, "food": 0, "goods": 0, "show": false}
	if not _owned_visible(game, sid) or _inputs_moved(game, sid):
		return blank
	var flow := _flow(game, sid)
	if flow.is_empty():
		return blank
	var mats := int(flow.get("materials", 0)) - int(flow.get("upkeep_materials", 0))
	var food := int(flow.get("food", 0))
	var goods := int(flow.get("tokens", 0)) + int(flow.get("influence", 0)) + int(flow.get("air", 0))
	var show := mats != 0 or food != 0 or goods != 0
	return {"mats": mats, "food": food, "goods": goods, "show": show}


static func shows(game, sid: String) -> bool:
	return bool(amounts(game, sid).get("show", false))


static func status_text(row: Dictionary) -> String:
	return Copy.fill("ledger.status", {
		"mats": int(row.get("mats", 0)),
		"food": int(row.get("food", 0)),
		"goods": int(row.get("goods", 0)),
	})


static func stack_text(row: Dictionary) -> PackedStringArray:
	return PackedStringArray([
		Copy.fill("ledger.mats", {"n": int(row.get("mats", 0))}),
		Copy.fill("ledger.food", {"n": int(row.get("food", 0))}),
		Copy.fill("ledger.goods", {"n": int(row.get("goods", 0))}),
	])


static func tip() -> String:
	return Copy.t("ledger.tip")


## First Visit that actually shows the ledger this run. Sets flags.seen_outpost_ledger.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get(FLAG, false)):
		return ""
	game.flags[FLAG] = true
	return Copy.t("ledger.first")
