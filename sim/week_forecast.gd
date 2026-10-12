extends RefCounted
class_name WeekForecast

## Display only: what tonight will add and take for power, food, air and materials, read the way Game._night does
## it (brownout, event flags, quarantine, the harvest, outposts, the storage cap, spoilage, the rot week, meals,
## breathing, room draw, filter upkeep). Never changes the game. sim/check_clarity.gd holds it to the night.
## Not covered, because the day screen cannot know them: the cough pulling workers at night and day events
## resolved after End turn.

const KEYS := ["power", "food", "air", "materials"]
## Game._tally's quarantine cut on the yard's total output.
const QUARANTINE_CUT := 0.75


## One room's output of `key` tonight. "zero" names why it makes nothing; "steps" are the multipliers in order.
static func room_yield(game, room: Dictionary, key: String, dark: Dictionary = {}) -> Dictionary:
	var defin: Dictionary = game.catalog.rooms[room.type]
	var base_table: Dictionary = defin.get("base", {})
	var out := {"amount": 0, "base": 0.0, "steps": [], "zero": ""}
	if not base_table.has(key):
		return out
	var base := float(base_table[key]) * (1.0 + 0.25 * float(room.upgrade))
	out.base = base
	if bool(room.get("switched_off", false)):
		out.zero = "off"
		return out
	if bool(room.offline) or game._flood_silences(room):
		out.zero = "flooded"
		return out
	if int(room.get("disabled", 0)) > 0:
		out.zero = "broken"
		return out
	if dark.has(str(room.uid)) and str(room.type) != "generator":
		out.zero = "dark"
		return out
	var skill := str(defin.get("skill", ""))
	var skills: Array = []
	for id in room.staff:
		var person: Dictionary = game.people[id]
		if int(person.sick) > 0 or int(person.absent) > 0 or skill == "":
			skills.append(0)
		else:
			skills.append(int(person.skills.get(skill, 1)))
	var factor: float = game._output_factor(room, defin)
	if factor <= 0.0:
		out.zero = "unstaffed"
		return out
	var n := Formulas.room_output(base, skills, float(game.bal.skill_coef), float(game.bal.output_cap))
	var extra := 0.0
	for s in skills:
		if float(s) > 1.0:
			extra += float(s) - 1.0
	var crew := minf(float(game.bal.output_cap), 1.0 + float(game.bal.skill_coef) * extra)
	if absf(crew - 1.0) > 0.001:
		out.steps.append(["skill", crew])
	n = int(round(float(n) * factor))
	if factor < 1.0:
		out.steps.append(["half_crew", factor])
	if bool(defin.get("decays", false)):
		n = int(round(float(n) * float(room.efficiency)))
		if float(room.efficiency) < 0.999:
			out.steps.append(["wear", float(room.efficiency)])
	if game._law_on("double_shifts"):
		var mult := float(game.catalog.laws.double_shifts.prod_mult)
		n = int(round(float(n) * mult))
		out.steps.append(["double_shifts", mult])
	if game.belt_down and str(room.type) == "hydroponics" and key == "food":
		n = int(n / 2.0)
		out.steps.append(["event", 0.5])
	if game.workshop_down and str(room.type) == "workshop" and key == "materials":
		out.zero = "event"
		return out
	if game.gen_down and str(room.type) == "generator" and key == "power":
		n = int(n / 2.0)
		out.steps.append(["event", 0.5])
	if int(room.get("mold", 0)) > 0 and key == "food":
		out.zero = "mold"
		return out
	out.amount = n
	return out


## Rooms that go dark tonight because the power will not cover them.
static func dark_rooms(game) -> Dictionary:
	var dark := {}
	for uid in game._brownout_ids():
		dark[str(uid)] = true
	return dark


## Every key's week: stock now, sources and sinks as lines ({"what", "amount", "room"}), made, used, net, after.
## Food carries "low" and "high" for the random harvest; "expected" uses the harvest bias.
static func week(game) -> Dictionary:
	var dark := dark_rooms(game)
	var made := {}
	var lines := {}
	for key in KEYS:
		made[key] = 0
		lines[key] = []
	for room in game.rooms:
		for key in KEYS:
			var info := room_yield(game, room, key, dark)
			if not game.catalog.rooms[room.type].get("base", {}).has(key):
				continue
			made[key] += int(info.amount)
			if int(info.amount) != 0:
				lines[key].append({"what": str(game.catalog.rooms[room.type].name), "room": str(room.uid), "amount": int(info.amount)})
	if game.quarantine:
		for key in KEYS:
			var cut := int(made[key]) - int(round(float(made[key]) * QUARANTINE_CUT))
			if cut != 0:
				made[key] -= cut
				lines[key].append({"what": "quarantine", "amount": -cut})
	var out := {}
	var swing := int(game.bal.get("harvest_swing", 0))
	var bias := int(game.bal.get("harvest_bias", 0))
	var spread := [0]
	if swing > 0:
		spread = [-swing, 0, swing]
	var runs := []
	for roll in spread:
		runs.append(_night(game, made, lines, dark, bias + int(roll) if (swing > 0 or bias != 0) else 0, swing > 0 or bias != 0))
	var mid: Dictionary = runs[runs.size() / 2]
	for key in KEYS:
		var row: Dictionary = mid[key]
		row["random"] = key == "food" and swing > 0
		if key == "food":
			row["low"] = int(runs[0].food.net)
			row["high"] = int(runs[runs.size() - 1].food.net)
			row["swing"] = swing
		out[key] = row
	return out


static func _night(game, made: Dictionary, room_lines: Dictionary, dark: Dictionary, harvest: int, harvested: bool) -> Dictionary:
	var stock := {}
	var rows := {}
	for key in KEYS:
		stock[key] = int(game.stock.get(key, 0))
		rows[key] = room_lines[key].duplicate(true)
	var produced := made.duplicate()
	if harvested:
		var food := maxi(0, int(produced.food) + harvest)
		if food - int(produced.food) != 0:
			rows.food.append({"what": "harvest", "amount": food - int(produced.food)})
		produced.food = food
	var start := stock.duplicate()
	for key in KEYS:
		stock[key] += int(produced[key])
	if game.vent_cut > 0:
		var air := maxi(0, int(stock.air) - 2)
		_take(rows.air, "vent", int(stock.air) - air)
		stock.air = air
	if game._law_on("engineers_charter"):
		var plus := int(game.catalog.laws.engineers_charter.get("power", 0))
		stock.power += plus
		rows.power.append({"what": "Engineers' Charter", "amount": plus})
	for sid in game.stations.keys():
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != game.player or sid == game.capital_id:
			continue
		var hops: int = game._supply_hops(str(sid))
		if hops >= 900:
			continue
		var flow: Dictionary = Formulas.outpost_flow(int(st.get("held_weeks", 0)) + 1, hops, str(st.focus))
		var upkeep := int(flow.upkeep_materials)
		if upkeep > 0:
			var left := maxi(0, int(stock.materials) - upkeep)
			_take(rows.materials, "outpost_upkeep", int(stock.materials) - left)
			stock.materials = left
		for key in ["food", "materials", "air"]:
			var gain := int(flow.get(key, 0))
			if gain > 0:
				stock[key] += gain
				_give(rows[key], "outposts", gain)
	if game._season_is("flood") and not game.pumped and not game.flood_guard:
		var lvl: int = game._lowest_open_level()
		var stored := 0
		for room in game.rooms:
			if int(room.level) == lvl:
				stored += game._room_store(room, "food")
		var loss := mini(int(stock.food), stored)
		if loss > 0:
			_take(rows.food, "flood", loss)
			stock.food -= loss
	for key in ["food", "air", "materials"]:
		var cap: int = game.storage_cap(key)
		if int(stock[key]) > cap:
			_take(rows[key], "full", int(stock[key]) - cap)
			stock[key] = cap
	var cap_food: int = game.storage_cap("food")
	if cap_food > 0:
		var line := int(float(cap_food) * float(game.bal.spoil_line))
		var excess := int(stock.food) - line
		if excess > 0:
			var spoil := int(round(float(excess) * float(game.bal.spoil_rate)))
			if spoil > 0:
				var left := maxi(0, int(stock.food) - spoil)
				_take(rows.food, "spoil", int(stock.food) - left)
				stock.food = left
	if game.week == game.rot_week:
		var surplus: int = int(stock.food) - int(game.food_need())
		if surplus > 0:
			var rot := mini(surplus, maxi(1, int(round(float(surplus) * 0.5))))
			_take(rows.food, "rot", rot)
			stock.food -= rot
	var short := {}
	for pair in [["food", game.food_need(), "meals"], ["air", game.air_need(), "breathing"]]:
		var key: String = pair[0]
		var need := int(pair[1])
		short[key] = maxi(0, need - int(stock[key]))
		var left := maxi(0, int(stock[key]) - need)
		_take(rows[key], str(pair[2]), int(stock[key]) - left)
		stock[key] = left
	var double: bool = game._season_is("cold") or game.crunch_power
	var power_need := 0
	for room in game.rooms:
		if bool(room.offline) or dark.has(str(room.uid)):
			continue
		var draw := int(game.catalog.rooms[room.type].get("power", 0)) * (2 if double else 1)
		if draw > 0:
			power_need += draw
	short["power"] = maxi(0, power_need - int(stock.power))
	var power_left := maxi(0, int(stock.power) - power_need)
	_draws(game, rows.power, dark, double, int(stock.power) - power_left)
	stock.power = power_left
	short["materials"] = 0
	var upkeep := int(game.bal.filter_upkeep)
	var paid := 0
	for room in game.rooms:
		if str(room.type) != "air_filter":
			continue
		if int(stock.materials) >= upkeep:
			stock.materials -= upkeep
			paid += upkeep
	_take(rows.materials, "filter_upkeep", paid)
	var out := {}
	for key in KEYS:
		var gained := 0
		var spent := 0
		for row in rows[key]:
			if int(row.amount) > 0:
				gained += int(row.amount)
			else:
				spent -= int(row.amount)
		out[key] = {
			"key": key,
			"stock": int(start[key]),
			"made": gained,
			"used": spent,
			"net": int(stock[key]) - int(start[key]),
			"after": int(stock[key]),
			"short": int(short[key]),
			"lines": rows[key],
			"cold": key == "power" and double,
		}
	return out


static func _take(rows: Array, what: String, amount: int) -> void:
	if amount > 0:
		rows.append({"what": what, "amount": -amount})


static func _give(rows: Array, what: String, amount: int) -> void:
	for row in rows:
		if str(row.what) == what:
			row.amount = int(row.amount) + amount
			return
	rows.append({"what": what, "amount": amount})


## Power drawn per room, biggest first; the total is what the night really takes (less when the stock runs out).
static func _draws(game, rows: Array, dark: Dictionary, double: bool, taken: int) -> void:
	var draws := {}
	for room in game.rooms:
		if bool(room.offline) or dark.has(str(room.uid)):
			continue
		var draw := int(game.catalog.rooms[room.type].get("power", 0)) * (2 if double else 1)
		if draw <= 0:
			continue
		var name := str(game.catalog.rooms[room.type].name)
		draws[name] = int(draws.get(name, 0)) + draw
	var names := draws.keys()
	names.sort_custom(func(a, b): return int(draws[a]) > int(draws[b]))
	var left := taken
	for name in names:
		var amount := mini(int(draws[name]), left)
		left -= amount
		if amount > 0:
			rows.append({"what": str(name), "amount": -amount, "draw": true})
