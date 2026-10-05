class_name Game
extends RefCounted

## One week is dawn, station and council actions, the rival phase, then night.
## No nodes. Content comes from the JSON catalog.

var seed := 1
var week := 1
var max_weeks := 40
var over := ""
var player := "depot"
var player_lean := "craft"
var capital_id := "coney"

var stock := {}
var hope := 60
var discontent := 15
var residents: Array = []
var people := {}
var cells := {}
var rooms: Array = []
var laws_on := {}
var law_lock := 0
var council: Array = []
var stations := {}
var tunnels: Array = []
var squads := {}
var opinions := {}
var ambition := {}
var at_war := {}
var trade_on := false
var telegraphed: Array = []
var demands: Array = []
var pending: Array = []
var dig := {}
var build := {}
var expedition := {}
var active_season := {}
var artifacts := {"papers": 0, "iron": 0, "words": 0}
var pumped := false
var quarantine := false
var synod := 0
var floor_met := false
var orders_left := 0
var decisions := 0
var hope_zero := 0
var next_person := 0
var demand_seq := 1
var log: Array = []
var errors: Array = []
var stats := {"shortages": 0, "ultimatums": 0, "min_decisions": 99}
var food_buffers: Array = []
var growth_bank := 0.0
var hope_week := {}
var hope_history: Array = []
var hope_totals := {}
var dis_totals := {}
var hope_samples: Array = []
var last_net := {}
var last_hope_delta := 0
var last_dis_delta := 0
var dis_week := {}
var audit := false
var rot_week := 0
var crunch_week := 0
var crunch_kind := 0
var crunch_rng := RandomNumberGenerator.new()
var crunch_power := false
var belt_down := false
var workshop_down := false
var gen_down := false
var event_last := {}
var week_event_ids := {}

var catalog: Catalog
var rng := RandomNumberGenerator.new()
var bal := {}


func setup(cat: Catalog, run_seed: int, weeks: int) -> void:
	catalog = cat
	bal = cat.balance
	seed = run_seed
	max_weeks = weeks
	rng.seed = run_seed
	week = 1
	over = ""
	player_lean = str(cat.factions[player].lean)
	capital_id = str(cat.factions[player].capital)
	var start: Dictionary = bal.start
	stock = {
		"air": int(start.air),
		"food": int(start.food),
		"power": int(start.power),
		"materials": int(start.materials),
		"tokens": int(start.tokens),
		"influence": int(start.influence),
	}
	hope = int(start.hope)
	discontent = int(start.discontent)
	stats = {
		"shortages": 0,
		"ultimatums": 0,
		"min_decisions": 99,
		"shortage_weeks": 0,
		"first_shortage": 0,
		"hope_min": hope,
		"hope_max": hope,
		"dis_min": discontent,
		"dis_max": discontent,
		"unrest_weeks": 0,
		"pop10": -1,
		"pop20": -1,
		"pop40": -1,
	}
	food_buffers = []
	growth_bank = 0.0
	hope_week = {}
	hope_history = []
	hope_totals = {}
	dis_totals = {}
	dis_week = {}
	hope_samples = []
	last_net = {}
	last_hope_delta = 0
	last_dis_delta = 0
	_init_people()
	_init_grid()
	_init_map()
	_init_squads()
	laws_on[str(cat.factions[player].law)] = true
	_auto_staff()
	if residents.size() != int(bal.start_pop):
		errors.append("start pop %d" % residents.size())
	if stations.size() != 15:
		errors.append("stations %d" % stations.size())
	if council.size() != 3:
		errors.append("council %d" % council.size())
	if errors.is_empty():
		_check_opening_stores()
		rot_week = rng.randi_range(int(bal.rot_min_week), int(bal.rot_max_week))
		crunch_rng.seed = seed * 1000 + 13
		crunch_week = crunch_rng.randi_range(int(bal.crunch_min_week), int(bal.crunch_max_week))
		crunch_kind = crunch_rng.randi_range(0, 2)
		crunch_power = false
		belt_down = false
		workshop_down = false
		gen_down = false
	if errors.is_empty():
		telegraphed = _plan_intents()
		_dawn()
	else:
		over = "error"


func end_week() -> void:
	if over != "":
		return
	_resolve_pending()
	_rival_phase()
	_night()
	_finish_checks()
	stats.min_decisions = mini(int(stats.min_decisions), decisions)
	if audit and decisions < 2 and over == "":
		errors.append("W%d decisions %d" % [week, decisions])
	_invariants()
	if over != "":
		return
	if week >= max_weeks:
		over = "time"
		return
	week += 1
	decisions = 0
	_dawn()


func apply(action: Dictionary) -> bool:
	if over != "":
		return false
	var kind := str(action.get("kind", ""))
	var ok := false
	match kind:
		"event":
			ok = _apply_event(action)
		"build":
			ok = _apply_build(str(action.get("type", "")), int(action.get("level", -1)), int(action.get("cell", -1)))
		"dig":
			ok = _apply_dig_action(action)
		"upgrade":
			ok = _apply_upgrade(str(action.get("room", "")))
		"demolish":
			ok = _apply_demolish(str(action.get("room", "")))
		"assign":
			ok = _apply_assign(str(action.get("person", "")), str(action.get("room", "")))
		"unassign":
			ok = _apply_unassign(str(action.get("person", "")))
		"staff":
			_auto_staff()
			decisions += 1
			_log("STAFF " + _staff_line())
			ok = true
		"law":
			ok = _apply_law(str(action.get("law", "")))
		"pump":
			ok = _apply_pump()
		"quarantine":
			ok = _apply_quarantine()
		"order":
			ok = _apply_order(action)
		_:
			ok = false
	return ok


func report() -> Dictionary:
	var lines: PackedStringArray = []
	lines.append("Seed %d: %s (week %d)" % [seed, over, week])
	lines.append("Final food %d air %d power %d materials %d tokens %d influence %d" % [
		int(stock.food), int(stock.air), int(stock.power), int(stock.materials), int(stock.tokens), int(stock.influence)])
	lines.append("Hope %d discontent %d pop %d stations %d papers %d synod %d" % [
		hope, discontent, residents.size(), owned_count(), int(artifacts.papers), synod])
	var food_line := _food_buffer_line()
	lines.append("Shortages %d first %s ultimatums %d min decisions %d trade %s" % [
		int(stats.shortage_weeks), _week_label(int(stats.first_shortage)), int(stats.ultimatums), int(stats.min_decisions), str(trade_on)])
	lines.append("Food buffer weeks %s  Hope %d/%d  Discontent %d/%d" % [
		food_line, int(stats.hope_min), int(stats.hope_max), int(stats.dis_min), int(stats.dis_max)])
	lines.append("Pop w10/w20/w40 %s/%s/%s  unrest station-weeks %d" % [
		_pop_label(int(stats.pop10)), _pop_label(int(stats.pop20)), _pop_label(int(stats.pop40)), int(stats.unrest_weeks)])
	if errors.is_empty():
		lines.append("Errors: none")
	else:
		lines.append("Errors: " + ", ".join(errors))
	for entry in log:
		if entry.important:
			lines.append("W%02d %s" % [int(entry.week), str(entry.text)])
	if over != "time":
		lines.append("-- recent --")
		var start := maxi(0, log.size() - 18)
		for i in range(start, log.size()):
			lines.append("W%02d %s" % [int(log[i].week), str(log[i].text)])
	var ok: bool = errors.is_empty() and over == "time"
	var buffers := _buffer_span()
	return {
		"ok": ok,
		"summary": "\n".join(lines),
		"seed": seed,
		"over": over,
		"errors": errors,
		"week": week,
		"shortage_weeks": int(stats.shortage_weeks),
		"first_shortage": int(stats.first_shortage),
		"food_min": float(buffers.min),
		"food_med": float(buffers.median),
		"food_max": float(buffers.max),
		"hope_min": int(stats.hope_min),
		"hope_max": int(stats.hope_max),
		"dis_min": int(stats.dis_min),
		"dis_max": int(stats.dis_max),
		"pop10": int(stats.pop10),
		"pop20": int(stats.pop20),
		"pop40": int(stats.pop40),
		"unrest_weeks": int(stats.unrest_weeks),
		"stations": owned_count(),
		"hope_end": hope,
		"hope_avg": _hope_avg(),
		"hope_sources": hope_totals.duplicate(),
		"dis_sources": dis_totals.duplicate(),
		"hope_history": hope_history.duplicate(),
		"crunch_drops": stats.get("crunch_drops", []),
		"crunch_week": crunch_week,
		"crunch_kind": crunch_kind,
	}


func owned_count() -> int:
	return _owned_by(player).size()


func food_buffer_weeks() -> float:
	return float(stock.food) / float(maxi(1, food_need()))


func food_need() -> int:
	var n := Formulas.people_for(residents.size(), int(bal.food_per))
	if _law_on("rationing"):
		n = int(round(float(n) * 0.75))
	return n


func air_need() -> int:
	return Formulas.people_for(residents.size(), int(bal.air_per))


func power_need() -> int:
	return _power_need()


func housing() -> int:
	var n := 0
	for room in rooms:
		if room.offline:
			continue
		n += int(catalog.rooms[room.type].get("housing", 0))
	return n


func room_count(type: String) -> int:
	var n := 0
	for room in rooms:
		if room.type == type:
			n += 1
	if not build.is_empty() and str(build.type) == type:
		n += 1
	return n


func build_slots() -> int:
	var n := 0
	for key in cells:
		if _cell_buildable(cells[key]):
			n += 1
	return n


func output_of(key: String) -> int:
	return int(_tally().get(key, 0))


func borders_player(sid: String) -> bool:
	for n in _neighbors(sid):
		if str(stations[n].owner) == player:
			return true
	return false


func sympathy_preview(sid: String) -> int:
	if not stations.has(sid):
		return 0
	return Formulas.sympathy_gain(float(bal.sympathy_base), player_lean, str(stations[sid].lean), _avg_fill(stations[sid]))


func afford_choice(choice: Dictionary) -> bool:
	return _afford(choice.get("cost", {}))


func can_enact(law_id: String) -> bool:
	return enact_reason(law_id) == ""


func can_pump() -> bool:
	return pump_reason() == ""


func pump_reason() -> String:
	if not _needs_pump():
		return "There is no flood to pump."
	return shortage_text({"materials": int(bal.pump_materials), "power": int(bal.pump_power)})


func enact_reason(law_id: String) -> String:
	if _law_on(law_id):
		return "Already in force."
	if not catalog.laws.has(law_id):
		return "No such law."
	if not _room_ready("meeting_hall"):
		return "Needs a staffed meeting hall. The hall has no one in it."
	if law_lock > 0:
		return "The hall is waiting. Next law in %d weeks." % law_lock
	return ""


func shortage_text(need: Dictionary) -> String:
	var order := ["power", "air", "food", "materials", "tokens", "influence"]
	var needs: PackedStringArray = []
	var short: PackedStringArray = []
	for key in order:
		if not need.has(key):
			continue
		var want := int(need[key])
		if want <= 0:
			continue
		var have := int(stock.get(key, 0))
		if have >= want:
			continue
		needs.append("%d %s" % [want, key])
		short.append("%d %s" % [have, key])
	if needs.is_empty():
		return ""
	return "Needs %s. You have %s." % [", ".join(needs), ", ".join(short)]


func resource_outlook(key: String) -> Dictionary:
	var have := int(stock.get(key, 0))
	var made := output_of(key)
	if key == "power" and _law_on("engineers_charter"):
		made += int(catalog.laws.engineers_charter.get("power", 0))
	var use := _weekly_draw(key)
	var nxt := have + made - use
	var hit: bool = have <= 0 or nxt <= 0
	var dawn := maxi(0, nxt)
	var text := "%s %d on hand. The yard makes %d and uses %d. By dawn: %d." % [key.capitalize(), have, made, use, dawn]
	if nxt < 0:
		text += " Short %d." % -nxt
	var who := _consumer_line(key)
	if who != "":
		text += " " + who
	if key == "power" and nxt < 0:
		var names := _uncovered_power_names()
		if not names.is_empty():
			text += " These rooms will not be covered: %s." % ", ".join(names)
	return {"text": text, "hit": hit, "next": nxt}


func rooms_losing_power() -> Array:
	if int(resource_outlook("power").next) >= 0:
		return []
	return _uncovered_power_ids()


func can_quarantine() -> bool:
	return not quarantine and not active_season.is_empty() and str(active_season.id) == "cough"


func can_expedition() -> bool:
	if not expedition.is_empty():
		return false
	var sq: Dictionary = squads[player]
	if sq.away or str(sq.station) != capital_id:
		return false
	var tunnel := _tunnel_by_id("to_ferry")
	return not tunnel.is_empty() and not tunnel.dug


func can_approach() -> bool:
	if floor_met or int(artifacts.papers) < 1:
		return false
	var tunnel := _tunnel_by_id("to_floor")
	return not tunnel.is_empty() and bool(tunnel.dug)


func can_trade() -> bool:
	return not trade_on and int(opinions.get("exchange", -100)) >= 0 and int(stock.influence) >= 4 and orders_left > 0


func build_possible(type: String) -> bool:
	var defin: Dictionary = catalog.rooms.get(type, {})
	if defin.is_empty() or not bool(defin.get("buildable", false)):
		return false
	if not build.is_empty():
		return false
	if int(stock.materials) < int(defin.materials):
		return false
	if _free_count() < int(bal.build_workers):
		return false
	return build_slots() > 0


func dig_possible(for_space: bool) -> bool:
	if not dig.is_empty():
		return false
	if int(stock.materials) < int(bal.dig_materials):
		return false
	var target := _pick_dig_cell(for_space)
	if target.is_empty():
		return false
	return _free_count() >= int(_dig_cost(int(target.level)).workers)


# --- week phases ---

func _dawn() -> void:
	orders_left = council.size()
	pumped = false
	quarantine = false
	week_event_ids = {}
	_season_clock()
	_queue_crunch()
	_roll_events()
	_log("DAWN food %d air %d power %d mat %d tok %d inf %d hope %d dis %d pop %d" % [
		int(stock.food), int(stock.air), int(stock.power), int(stock.materials), int(stock.tokens), int(stock.influence), hope, discontent, residents.size()])
	for intent in telegraphed:
		if bool(intent.get("hidden", false)):
			continue
		if str(intent.kind) == "demand_posted":
			continue
		_log("INTENT " + _intent_text(intent))
	for d in demands:
		if bool(d.paid):
			continue
		_log("ULTIMATUM %s wants %d tokens, %d turns left" % [_fname(str(d.faction)), int(d.amount), int(d.deadline)], true)


func _rival_phase() -> void:
	var keep: Array = []
	for d in demands:
		if bool(d.paid):
			continue
		d.deadline = int(d.deadline) - 1
		if int(d.deadline) <= 0:
			_add_opinion(str(d.faction), -15)
			stock.food = maxi(0, int(stock.food) - 10)
			_log("ULTIMATUM %s takes its price. Food -10." % _fname(str(d.faction)), true)
		else:
			keep.append(d)
	demands = keep
	var batch := telegraphed
	telegraphed = []
	for intent in batch:
		_resolve_intent(intent)


func _night() -> void:
	if _season_is("cough"):
		_spread_cough()
		_cough_pull_workers()
		_pull_sick_from_rooms()
	var produced := _tally(belt_down, workshop_down, gen_down)
	var swing := int(bal.get("harvest_swing", 0))
	var bias := int(bal.get("harvest_bias", 0))
	if swing > 0 or bias != 0:
		produced.food = maxi(0, int(produced.food) + bias + (rng.randi_range(-swing, swing) if swing > 0 else 0))
	var before := {}
	for key in ["food", "air", "power", "materials", "tokens", "influence"]:
		before[key] = int(stock.get(key, 0))
	for key in produced:
		stock[key] = int(stock.get(key, 0)) + int(produced[key])
	if _law_on("engineers_charter"):
		stock.power = int(stock.power) + int(catalog.laws.engineers_charter.get("power", 0))
	_apply_weekly_laws()
	if trade_on:
		stock.tokens = int(stock.tokens) + int(bal.trade_tokens_week)
	_deliver_outposts()
	_spoil_flood_stores()
	_clamp_storage()
	_spoil_food()
	_rot_stores()
	var need_power := _power_need()
	if _season_is("cold") or crunch_power:
		need_power *= 2
	if quarantine:
		_add_hope(-1, "quarantine")
	var week_short := false
	var food_short := maxi(0, food_need() - int(stock.food))
	var air_short := maxi(0, air_need() - int(stock.air))
	stock.food = maxi(0, int(stock.food) - food_need())
	stock.air = maxi(0, int(stock.air) - air_need())
	if food_short > 0 or air_short > 0:
		_add_hope(int(bal.shortage_hope), "shortage")
		var people_short := food_short * int(bal.food_per) + air_short * int(bal.air_per)
		var deaths := int(people_short / 10)
		week_short = true
		_log("SHORT food %d air %d" % [food_short, air_short], true)
		if deaths > 0:
			_kill(deaths, "Supplies ran out")
	var power_short := maxi(0, need_power - int(stock.power))
	stock.power = maxi(0, int(stock.power) - need_power)
	if power_short > 0:
		_add_hope(int(bal.power_shortage_hope), "power")
		_add_discontent(int(bal.power_shortage_discontent), "power")
		week_short = true
		_log("SHORT power %d" % power_short, true)
	if week_short:
		stats.shortage_weeks = int(stats.shortage_weeks) + 1
		stats.shortages = int(stats.shortage_weeks)
		if int(stats.first_shortage) == 0:
			stats.first_shortage = week
	var eaten := maxi(1, food_need())
	food_buffers.append(float(stock.food) / float(eaten))
	_decay_filters()
	_heal()
	_tick_sickness()
	if _law_on("double_shifts"):
		_double_shift_sickness()
	_apply_flood_if_needed()
	_season_mood()
	_rival_agents()
	if residents.size() > housing():
		_add_discontent(int(bal.overcrowd_discontent), "overcrowd")
	_add_hope(int(bal.hope_drift), "drift")
	for key in before:
		last_net[key] = int(stock.get(key, 0)) - int(before[key])
	_tick_holdings()
	_drift_opinion()
	for fid in ambition:
		ambition[fid] = int(ambition[fid]) + int(bal.ambition_week)
	_grow()
	_advance_jobs()
	_tick_expedition()
	_heal_squads()
	crunch_power = false
	belt_down = false
	workshop_down = false
	gen_down = false
	if over == "":
		telegraphed = _plan_intents()


func _finish_checks() -> void:
	_sample_meters()
	if week == 10:
		stats.pop10 = residents.size()
	elif week == 20:
		stats.pop20 = residents.size()
	elif week == 40 or (over != "" and week >= 40):
		stats.pop40 = residents.size()
	if over == "time" or week >= max_weeks:
		stats.pop40 = residents.size()
	if residents.size() < 8 and over == "":
		over = "collapse"
		_log("COLLAPSE the yard is empty", true)
	if hope <= 0:
		hope_zero += 1
		_shed(2)
		if hope_zero >= 3 and over == "":
			over = "hope"
			_log("HOPE the station stops working", true)
	else:
		hope_zero = 0
	if discontent >= 100 and over == "":
		over = "revolt"
		_log("REVOLT the platform turns on you", true)
	_sample_meters()
	_flush_hope_week()


# --- production ---

func _tally(drop_hydro_food := false, drop_shop := false, drop_gen := false) -> Dictionary:
	var out := {"food": 0, "air": 0, "power": 0, "materials": 0, "tokens": 0, "influence": 0}
	var mult := 1.0
	if _law_on("double_shifts"):
		mult = float(catalog.laws.double_shifts.prod_mult)
	for room in rooms:
		if room.offline or _flood_silences(room):
			continue
		var defin: Dictionary = catalog.rooms[room.type]
		var skill := str(defin.get("skill", ""))
		var skills: Array = []
		for id in room.staff:
			var person: Dictionary = people[id]
			if int(person.sick) > 0 or int(person.absent) > 0 or skill == "":
				skills.append(0)
			else:
				skills.append(int(person.skills.get(skill, 1)))
		var factor := _output_factor(room, defin)
		var base: Dictionary = defin.base
		for key in base:
			if not out.has(key):
				continue
			var amount := float(base[key]) * (1.0 + 0.25 * float(room.upgrade))
			var n := 0
			if factor > 0.0:
				n = Formulas.room_output(amount, skills, float(bal.skill_coef), float(bal.output_cap))
				n = int(round(float(n) * factor))
			if bool(defin.get("decays", false)):
				n = int(round(float(n) * float(room.efficiency)))
			n = int(round(float(n) * mult))
			if drop_hydro_food and str(room.type) == "hydroponics" and str(key) == "food":
				n = int(n / 2.0)
			if drop_shop and str(room.type) == "workshop" and str(key) == "materials":
				n = 0
			if drop_gen and str(room.type) == "generator" and str(key) == "power":
				n = int(n / 2.0)
			out[key] = int(out[key]) + n
	if quarantine:
		for key in ["food", "air", "power", "materials", "influence"]:
			out[key] = int(round(float(out[key]) * 0.75))
	if _law_on("curfew"):
		out.influence = int(round(float(out.influence) * float(catalog.laws.curfew.influence_mult)))
	return out


func _output_factor(room: Dictionary, defin: Dictionary) -> float:
	var have := int(room.staff.size())
	var need := int(defin.get("staff_min", 0))
	if str(room.type) == "generator":
		if have <= 0:
			return 0.0
		if have < need:
			return 0.5
		return 1.0
	if need > 0 and have < need:
		return 0.5
	return 1.0


func _power_need() -> int:
	var n := 0
	for room in rooms:
		if room.offline:
			continue
		n += int(catalog.rooms[room.type].get("power", 0))
	return n


func _weekly_draw(key: String) -> int:
	if key == "food":
		return food_need()
	if key == "air":
		return air_need()
	if key == "power":
		var need := _power_need()
		if _season_is("cold") or crunch_power:
			need *= 2
		return need
	return 0


func _consumer_line(key: String) -> String:
	if key == "food":
		return "Meals for %d people take %d food." % [residents.size(), food_need()]
	if key == "air":
		return "Breathing takes %d air." % air_need()
	if key == "power":
		var draws: Array = []
		for room in rooms:
			if room.offline:
				continue
			var draw := int(catalog.rooms[room.type].get("power", 0))
			if draw <= 0:
				continue
			draws.append({"name": str(catalog.rooms[room.type].name), "draw": draw})
		draws.sort_custom(func(a, b): return int(a.draw) > int(b.draw))
		var bits: PackedStringArray = []
		for i in mini(3, draws.size()):
			bits.append("%s %d" % [str(draws[i].name), int(draws[i].draw)])
		if bits.is_empty():
			return ""
		return "Biggest draws: %s." % ", ".join(bits)
	return ""


func _power_budget() -> int:
	var made := output_of("power")
	if _law_on("engineers_charter"):
		made += int(catalog.laws.engineers_charter.get("power", 0))
	return maxi(0, int(stock.power) + made)


func _uncovered_power_ids() -> Array:
	var rows: Array = []
	for room in rooms:
		if room.offline:
			continue
		var draw := int(catalog.rooms[room.type].get("power", 0))
		if draw <= 0:
			continue
		rows.append(room)
	rows.sort_custom(func(a, b):
		var da := int(catalog.rooms[a.type].get("power", 0))
		var db := int(catalog.rooms[b.type].get("power", 0))
		if da == db:
			return str(a.uid) < str(b.uid)
		return da < db
	)
	var left := _power_budget()
	if _season_is("cold") or crunch_power:
		left = int(left / 2.0)
	var lost: Array = []
	for room in rows:
		var draw := int(catalog.rooms[room.type].get("power", 0))
		if left >= draw:
			left -= draw
		else:
			lost.append(str(room.uid))
	return lost


func _uncovered_power_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for uid in _uncovered_power_ids():
		var room = _room(str(uid))
		if room == null:
			continue
		names.append(str(catalog.rooms[room.type].name))
	return names


func _stock_thin(key: String) -> bool:
	var have := int(stock.get(key, 0))
	if have <= 0:
		return true
	var need := _weekly_draw(key)
	return need > 0 and have <= need


func _demolish_loss(defin: Dictionary) -> String:
	var base: Dictionary = defin.get("base", {})
	var bits: PackedStringArray = []
	for key in base:
		if not _stock_thin(str(key)):
			continue
		bits.append("%s is at %d, and this room is part of what makes it." % [str(key).capitalize(), int(stock.get(key, 0))])
	return " ".join(bits)


func _room_store(room: Dictionary, key: String) -> int:
	var store = catalog.rooms[room.type].get("store", {})
	if store is Dictionary:
		return int(store.get(key, 0))
	return 0


func storage_cap(key: String) -> int:
	var n := 0
	for room in rooms:
		if room.offline or _flood_silences(room):
			continue
		n += _room_store(room, key)
	return n


func _clamp_storage() -> void:
	for key in ["food", "air", "materials"]:
		var cap := storage_cap(key)
		if int(stock.get(key, 0)) > cap:
			stock[key] = cap


func _spoil_food() -> void:
	var cap := storage_cap("food")
	if cap <= 0:
		return
	var line := int(float(cap) * float(bal.spoil_line))
	var excess := int(stock.food) - line
	if excess <= 0:
		return
	var loss := int(round(float(excess) * float(bal.spoil_rate)))
	if loss > 0:
		stock.food = maxi(0, int(stock.food) - loss)


func _spoil_flood_stores() -> void:
	if not _season_is("flood"):
		return
	var lvl := _lowest_open_level()
	var stored := 0
	for room in rooms:
		if int(room.level) != lvl:
			continue
		stored += _room_store(room, "food")
	var loss := mini(int(stock.food), stored)
	if loss <= 0:
		return
	stock.food = int(stock.food) - loss
	_log("FLOOD spoils %d food on the lowest level" % loss, true)


func _season_is(id: String) -> bool:
	return not active_season.is_empty() and str(active_season.id) == id


func _lowest_open_level() -> int:
	var lowest := -1
	for key in cells:
		if cells[key].dug:
			lowest = maxi(lowest, int(cells[key].level))
	return lowest


func _flood_silences(room: Dictionary) -> bool:
	if not _season_is("flood"):
		return false
	return int(room.level) == _lowest_open_level()


func _sample_meters() -> void:
	stats.hope_min = mini(int(stats.hope_min), hope)
	stats.hope_max = maxi(int(stats.hope_max), hope)
	stats.dis_min = mini(int(stats.dis_min), discontent)
	stats.dis_max = maxi(int(stats.dis_max), discontent)
	hope_samples.append(hope)


func _add_hope(delta: int, source: String) -> void:
	if delta == 0:
		return
	var before := hope
	hope = clampi(hope + delta, 0, 100)
	var applied := hope - before
	if applied == 0:
		return
	hope_totals[source] = int(hope_totals.get(source, 0)) + applied
	hope_week[source] = int(hope_week.get(source, 0)) + applied


func _add_discontent(delta: int, source: String) -> void:
	if delta == 0:
		return
	var before := discontent
	discontent = clampi(discontent + delta, 0, 100)
	var applied := discontent - before
	if applied == 0:
		return
	dis_totals[source] = int(dis_totals.get(source, 0)) + applied
	dis_week[source] = int(dis_week.get(source, 0)) + applied


func _flush_hope_week() -> void:
	var hope_sum := 0
	for key in hope_week:
		hope_sum += int(hope_week[key])
	var dis_sum := 0
	for key in dis_week:
		dis_sum += int(dis_week[key])
	last_hope_delta = hope_sum
	last_dis_delta = dis_sum
	var row := {"week": week, "hope": hope, "deltas": hope_week.duplicate()}
	hope_history.append(row)
	hope_week = {}
	dis_week = {}


func _hope_avg() -> float:
	if hope_samples.is_empty():
		return float(hope)
	var sum := 0
	for value in hope_samples:
		sum += int(value)
	return float(sum) / float(hope_samples.size())


func _check_opening_stores() -> void:
	for key in ["food", "air", "materials"]:
		var cap := storage_cap(key)
		var have := int(stock.get(key, 0))
		if have > cap:
			errors.append("start %s %d over cap %d" % [key, have, cap])
			continue
		if cap <= 0:
			errors.append("no %s cap" % key)
			continue
		var share := float(have) / float(cap)
		if share < 0.55 or share > 0.75:
			errors.append("start %s is %d%% of cap %d" % [key, int(round(share * 100.0)), cap])


func _season_mood() -> void:
	if active_season.is_empty():
		return
	var id := str(active_season.id)
	var dis_table = bal.get("season_discontent", {})
	if dis_table is Dictionary and dis_table.has(id):
		_add_discontent(int(dis_table[id]), "season")
	var hope_table = bal.get("season_hope", {})
	if hope_table is Dictionary and hope_table.has(id):
		_add_hope(int(hope_table[id]), "season")


func _rot_stores() -> void:
	if week != rot_week:
		return
	var target := maxi(0, food_need() - int(bal.rot_gap))
	if int(stock.food) <= target:
		return
	var loss := int(stock.food) - target
	stock.food = target
	_log("ROT %d food turns in the stores" % loss, true)


func _rival_agents() -> void:
	var every := int(bal.get("agent_every", 0))
	if every <= 0 or week % every != 0:
		return
	var hostile := false
	for fid in opinions.keys():
		if int(opinions[fid]) < 0:
			hostile = true
	if not hostile:
		return
	_add_discontent(int(bal.agent_discontent), "agent")
	_log("AGENT a rival rumor moves through the yard", true)


func _buffer_span() -> Dictionary:
	if food_buffers.is_empty():
		return {"min": 0.0, "median": 0.0, "max": 0.0}
	var lo := float(food_buffers[0])
	var hi := lo
	for value in food_buffers:
		lo = minf(lo, float(value))
		hi = maxf(hi, float(value))
	return {"min": lo, "median": _median(food_buffers), "max": hi}


func _median(values: Array) -> float:
	var ordered: Array = values.duplicate()
	ordered.sort()
	var n := ordered.size()
	if n % 2 == 1:
		return float(ordered[n / 2])
	return (float(ordered[n / 2 - 1]) + float(ordered[n / 2])) / 2.0


func _food_buffer_line() -> String:
	var span := _buffer_span()
	return "%.1f / %.1f / %.1f" % [float(span.min), float(span.median), float(span.max)]


func _week_label(n: int) -> String:
	if n <= 0:
		return "none"
	return str(n)


func _pop_label(n: int) -> String:
	if n < 0:
		return "-"
	return str(n)


func _apply_weekly_laws() -> void:
	for law_id in laws_on:
		var defin: Dictionary = catalog.laws[law_id]
		if defin.has("hope_week"):
			_add_hope(int(defin.hope_week), "law")
		if defin.has("discontent_week"):
			_add_discontent(int(defin.discontent_week), "law")
		if defin.has("tokens_week"):
			stock.tokens = int(stock.tokens) + int(defin.tokens_week)
		if law_id == "sermons" and _any_trait("Devout"):
			_add_hope(int(defin.get("devout_hope", 0)), "law")
			synod += int(defin.get("synod", 0))
	if law_lock > 0:
		law_lock -= 1


func _decay_filters() -> void:
	var upkeep := int(bal.filter_upkeep)
	for room in rooms:
		if room.type != "air_filter":
			continue
		if int(stock.materials) >= upkeep:
			stock.materials = int(stock.materials) - upkeep
			room.efficiency = clampf(float(room.efficiency) - float(bal.filter_decay) + float(bal.filter_restore), 0.25, 1.0)
		else:
			room.efficiency = clampf(float(room.efficiency) - float(bal.filter_neglect), 0.25, 1.0)


func _room_ready(type: String) -> bool:
	for room in rooms:
		if room.type == type and not room.offline and room.staff.size() >= int(catalog.rooms[type].staff_min):
			return true
	return false


# --- station actions ---

func _apply_build(type: String, level: int = -1, cell: int = -1) -> bool:
	if not build_possible(type):
		return false
	var defin: Dictionary = catalog.rooms[type]
	var spot: Dictionary = {}
	if level >= 0:
		var key := _ck(level, cell)
		if not cells.has(key) or not _cell_buildable(cells[key]):
			return false
		spot = cells[key]
	else:
		spot = _first_build_cell()
	if spot.is_empty():
		return false
	var workers := _pull_workers(int(bal.build_workers), "labor")
	if workers.size() < int(bal.build_workers):
		return false
	stock.materials = int(stock.materials) - int(defin.materials)
	build = {"type": type, "level": int(spot.level), "cell": int(spot.cell), "left": int(defin.build_turns), "workers": workers}
	decisions += 1
	_log("BUILD %s" % defin.name)
	return true


func _apply_dig_action(action: Dictionary) -> bool:
	if action.has("level"):
		return _dig_at(int(action.level), int(action.cell))
	return _apply_dig(bool(action.get("space", false)))


func _dig_at(level: int, cell: int) -> bool:
	var info := dig_preview(level, cell)
	if not bool(info.ok):
		return false
	var key := _ck(level, cell)
	var spot: Dictionary = cells[key]
	var cost: Dictionary = _dig_cost(int(spot.level))
	var workers := _pull_workers(int(cost.workers), "labor")
	if workers.size() < int(cost.workers):
		return false
	stock.materials = int(stock.materials) - int(bal.dig_materials)
	dig = {"level": level, "cell": cell, "left": int(cost.turns), "workers": workers}
	decisions += 1
	_log("DIG L%d C%d (%d turns)" % [level, cell, int(cost.turns)])
	return true


func dig_preview(level: int, cell: int) -> Dictionary:
	var key := _ck(level, cell)
	if not cells.has(key):
		return {"ok": false, "reason": "No such cell.", "turns": 0, "workers": 0, "materials": int(bal.dig_materials)}
	var spot: Dictionary = cells[key]
	var cost := _dig_cost(level)
	var info := {
		"ok": false,
		"reason": "",
		"turns": int(cost.turns),
		"workers": int(cost.workers),
		"materials": int(bal.dig_materials),
	}
	if bool(spot.dug):
		info.reason = "Already open."
		return info
	if not _beside_dug(spot):
		info.reason = "Solid rock. Dig from a cell that touches an open one."
		return info
	if not dig.is_empty():
		info.reason = "A crew is already digging."
		return info
	var reasons: PackedStringArray = []
	if int(stock.materials) < int(bal.dig_materials):
		reasons.append("Needs %d materials, the yard has %d." % [int(bal.dig_materials), int(stock.materials)])
	if _free_count() < int(cost.workers):
		reasons.append("Needs %d free people, %d are free." % [int(cost.workers), _free_count()])
	info.reason = " ".join(reasons)
	info.ok = reasons.is_empty()
	return info


func build_preview(type: String, level: int, cell: int) -> Dictionary:
	var defin: Dictionary = catalog.rooms.get(type, {})
	var info := {"ok": false, "reason": "", "materials": 0, "turns": 0, "workers": int(bal.build_workers), "power": 0, "name": type}
	if defin.is_empty() or not bool(defin.get("buildable", false)):
		info.reason = "That cannot be built."
		return info
	info.materials = int(defin.materials)
	info.turns = int(defin.build_turns)
	info.power = int(defin.get("power", 0))
	info.name = str(defin.name)
	var key := _ck(level, cell)
	if not cells.has(key) or not _cell_buildable(cells[key]):
		info.reason = "That cell is not an open, empty floor."
		return info
	var reasons: PackedStringArray = []
	if not build.is_empty():
		reasons.append("A room is already going up.")
	if int(stock.materials) < int(defin.materials):
		reasons.append("Needs %d materials, the yard has %d." % [int(defin.materials), int(stock.materials)])
	if _free_count() < int(bal.build_workers):
		reasons.append("Needs %d free people, %d are free." % [int(bal.build_workers), _free_count()])
	info.reason = " ".join(reasons)
	info.ok = reasons.is_empty()
	return info


func upgrade_preview(uid: String) -> Dictionary:
	var room = _room(uid)
	var info := {"ok": false, "reason": "", "materials": 0, "name": ""}
	if room == null:
		info.reason = "No such room."
		return info
	var defin: Dictionary = catalog.rooms[room.type]
	var steps: Array = defin.get("upgrades", [])
	info.materials = int(defin.get("upgrade_materials", 0))
	if int(room.upgrade) >= steps.size():
		info.reason = "Nothing left to upgrade."
		return info
	info.name = str(steps[int(room.upgrade)])
	if bool(room.offline):
		info.reason = "The room is offline."
		return info
	if int(stock.materials) < info.materials:
		info.reason = "Needs %d materials, the yard has %d." % [info.materials, int(stock.materials)]
		return info
	info.ok = true
	return info


func demolish_preview(uid: String) -> Dictionary:
	var room = _room(uid)
	var info := {"ok": false, "reason": "", "refund": 0, "name": ""}
	if room == null:
		info.reason = "No such room."
		return info
	var defin: Dictionary = catalog.rooms[room.type]
	info.name = str(defin.name)
	if not bool(defin.get("buildable", false)):
		info.reason = "The platform stays."
		return info
	if not build.is_empty() and int(build.level) == int(room.level) and int(build.cell) == int(room.cell):
		info.reason = "A crew is still on this cell."
		return info
	info.refund = int(defin.materials) / 2
	info.ok = true
	var loss := _demolish_loss(defin)
	if loss != "":
		info.loss = loss
		info.reason = loss
	return info


func _apply_upgrade(uid: String) -> bool:
	var info := upgrade_preview(uid)
	if not bool(info.ok):
		return false
	var room = _room(uid)
	stock.materials = int(stock.materials) - int(info.materials)
	room.upgrade = int(room.upgrade) + 1
	decisions += 1
	_log("UPGRADE %s to %s" % [catalog.rooms[room.type].name, str(info.name)])
	return true


func _apply_demolish(uid: String) -> bool:
	var info := demolish_preview(uid)
	if not bool(info.ok):
		return false
	var room = _room(uid)
	for id in room.staff.duplicate():
		_unassign(str(id))
	stock.materials = int(stock.materials) + int(info.refund)
	cells[_ck(int(room.level), int(room.cell))].room = ""
	var keep: Array = []
	for other in rooms:
		if str(other.uid) != uid:
			keep.append(other)
	rooms = keep
	decisions += 1
	_log("DEMOLISH %s, %d materials back" % [str(info.name), int(info.refund)])
	return true


func _apply_assign(person_id: String, uid: String) -> bool:
	var info := assign_preview(person_id, uid)
	if not bool(info.ok):
		return false
	_unassign(person_id)
	var room = _room(uid)
	room.staff.append(person_id)
	decisions += 1
	_log("ASSIGN %s to %s" % [people[person_id].name, catalog.rooms[room.type].name])
	return true


func _apply_unassign(person_id: String) -> bool:
	if not people.has(person_id):
		return false
	_unassign(person_id)
	decisions += 1
	_log("UNASSIGN %s" % people[person_id].name)
	return true


func assign_preview(person_id: String, uid: String) -> Dictionary:
	var info := {"ok": false, "reason": ""}
	if not people.has(person_id):
		info.reason = "No such resident."
		return info
	var room = _room(uid)
	if room == null:
		info.reason = "No such room."
		return info
	var person: Dictionary = people[person_id]
	var defin: Dictionary = catalog.rooms[room.type]
	if int(defin.staff_max) <= 0:
		info.reason = "No one works this room."
		return info
	if bool(room.offline):
		info.reason = "The room is offline."
		return info
	if int(person.sick) > 0 or int(person.absent) > 0:
		info.reason = "%s cannot work right now." % person.name
		return info
	if _locked_ids().has(person_id):
		info.reason = "%s is on a crew." % person.name
		return info
	var already := false
	for id in room.staff:
		if str(id) == person_id:
			already = true
	if not already and room.staff.size() >= int(defin.staff_max):
		info.reason = "The room is fully staffed."
		return info
	info.ok = true
	return info


func room_detail(uid: String) -> Dictionary:
	var room = _room(uid)
	if room == null:
		return {}
	var defin: Dictionary = catalog.rooms[room.type]
	var skill := str(defin.get("skill", ""))
	var skills: Array = []
	var staff: Array = []
	for id in room.staff:
		var person: Dictionary = people[str(id)]
		var value := 0 if skill == "" else int(person.skills.get(skill, 1))
		if int(person.sick) > 0 or int(person.absent) > 0:
			value = 0
		skills.append(value)
		staff.append({
			"id": str(id),
			"name": str(person.name),
			"skill": value,
			"traits": ", ".join(person.traits),
		})
	var outputs: Array = []
	var base: Dictionary = defin.base
	for key in base:
		var amount := float(base[key]) * (1.0 + 0.25 * float(room.upgrade))
		var factor := _output_factor(room, defin)
		var n := 0
		if factor > 0.0:
			n = Formulas.room_output(amount, skills, float(bal.skill_coef), float(bal.output_cap))
			n = int(round(float(n) * factor))
		if bool(defin.get("decays", false)):
			n = int(round(float(n) * float(room.efficiency)))
		if belt_down and str(room.type) == "hydroponics" and str(key) == "food":
			n = int(n / 2.0)
		if workshop_down and str(room.type) == "workshop" and str(key) == "materials":
			n = 0
		if gen_down and str(room.type) == "generator" and str(key) == "power":
			n = int(n / 2.0)
		outputs.append({"key": str(key), "amount": n, "base": amount})
	var extra := 0.0
	for value in skills:
		if float(value) > 1.0:
			extra += float(value) - 1.0
	return {
		"uid": uid,
		"type": str(room.type),
		"name": str(defin.name),
		"level": int(room.level),
		"cell": int(room.cell),
		"skill": skill,
		"staff": staff,
		"staff_max": int(defin.staff_max),
		"power": int(defin.get("power", 0)),
		"outputs": outputs,
		"upgrade": int(room.upgrade),
		"offline": bool(room.offline),
		"skill_extra": extra,
		"multiplier": minf(float(bal.output_cap), 1.0 + float(bal.skill_coef) * extra),
	}


func candidates_for(uid: String) -> Array:
	var room = _room(uid)
	if room == null:
		return []
	var skill := str(catalog.rooms[room.type].get("skill", ""))
	var rows: Array = []
	for person in residents:
		var id := str(person.id)
		if _locked_ids().has(id) or int(person.sick) > 0 or int(person.absent) > 0:
			continue
		var value := 0 if skill == "" else int(person.skills.get(skill, 0))
		var here := false
		for sid in room.staff:
			if str(sid) == id:
				here = true
		rows.append({"id": id, "name": str(person.name), "skill": value, "here": here, "traits": ", ".join(person.traits)})
	rows.sort_custom(func(a, b): return int(a.skill) > int(b.skill))
	return rows


func buildable_types() -> Array:
	var rows: Array = []
	for type in catalog.rooms.keys():
		var defin: Dictionary = catalog.rooms[type]
		if bool(defin.get("buildable", false)):
			rows.append(type)
	return rows


func week_notes() -> PackedStringArray:
	var lines: PackedStringArray = []
	for entry in log:
		if int(entry.week) != week:
			continue
		var text := str(entry.text)
		if text.begins_with("DAWN") or text.begins_with("INTENT") or text.begins_with("ULTIMATUM") or text.begins_with("SEASON") or text.begins_with("AGENT") or text.begins_with("SHORT") or text.begins_with("ROT") or text.begins_with("No warning"):
			lines.append(text)
	return lines


func _apply_dig(for_space: bool) -> bool:
	if not dig_possible(for_space):
		return false
	var cell := _pick_dig_cell(for_space)
	var cost: Dictionary = _dig_cost(int(cell.level))
	var workers := _pull_workers(int(cost.workers), "labor")
	if workers.size() < int(cost.workers):
		return false
	stock.materials = int(stock.materials) - int(bal.dig_materials)
	dig = {"level": int(cell.level), "cell": int(cell.cell), "left": int(cost.turns), "workers": workers}
	decisions += 1
	_log("DIG L%d C%d (%d turns)" % [int(cell.level), int(cell.cell), int(cost.turns)])
	return true


func _apply_pump() -> bool:
	if not can_pump():
		return false
	stock.materials = int(stock.materials) - int(bal.pump_materials)
	stock.power = int(stock.power) - int(bal.pump_power)
	pumped = true
	for key in cells:
		if cells[key].flooded:
			cells[key].flooded = false
			var uid := str(cells[key].room)
			var flooded_room = _room(uid)
			if uid != "" and flooded_room != null:
				flooded_room.offline = false
	decisions += 1
	_log("PUMP the lower level", true)
	return true


func _apply_quarantine() -> bool:
	if not can_quarantine():
		return false
	quarantine = true
	decisions += 1
	_log("QUARANTINE the sick rooms")
	return true


func _apply_law(law_id: String) -> bool:
	if not can_enact(law_id):
		return false
	var defin: Dictionary = catalog.laws[law_id]
	laws_on[law_id] = true
	law_lock = int(bal.law_cooldown)
	if defin.has("hope_on_enact"):
		_add_hope(int(defin.hope_on_enact), "law")
	if defin.has("discontent_on_enact"):
		_add_discontent(int(defin.discontent_on_enact), "law")
	if defin.has("materials_on_enact"):
		stock.materials = int(stock.materials) + int(defin.materials_on_enact)
	if defin.has("opinion_on_enact"):
		for fid in opinions:
			_add_opinion(fid, int(defin.opinion_on_enact))
	if law_id == "conscription":
		var sq: Dictionary = squads[player]
		sq.size = int(sq.size) + int(defin.squad_bonus)
		sq.max_size = int(sq.max_size) + int(defin.squad_bonus)
	decisions += 1
	_log("LAW %s" % defin.name, true)
	return true


func _advance_jobs() -> void:
	if not build.is_empty():
		build.left = int(build.left) - 1
		if int(build.left) <= 0:
			_place_room(str(build.type), int(build.level), int(build.cell))
			_log("%s is finished" % catalog.rooms[str(build.type)].name)
			build = {}
	if not dig.is_empty():
		dig.left = int(dig.left) - 1
		if int(dig.left) <= 0:
			_finish_dig()


func _finish_dig() -> void:
	var key := _ck(int(dig.level), int(dig.cell))
	var cell: Dictionary = cells[key]
	cell.dug = true
	var find := str(cell.find)
	if find == "flooded":
		cell.flooded = true
		_log("FIND flooded pocket on the lower level", true)
	elif find == "maintenance":
		stock.materials = int(stock.materials) + 15
		_log("FIND old maintenance room, +15 materials", true)
	elif find == "sealed_door":
		artifacts.papers = int(artifacts.papers) + 1
		var tunnel := _tunnel_by_id("to_floor")
		if not tunnel.is_empty():
			tunnel.dug = true
		_log("FIND a sealed door. The stencil says FLOOR.", true)
	if rng.randf() < 0.12 and dig.workers.size() > 0:
		var hit := str(dig.workers[0])
		if people.has(hit):
			people[hit].sick = maxi(int(people[hit].sick), 2)
			_log("A dig accident. %s is hurt." % people[hit].name)
			if _has_trait(people[hit], "Claustrophobic"):
				people[hit].absent = 2
				_add_hope(-3, "trait")
	dig = {}


func _dig_cost(level: int) -> Dictionary:
	var turns := 1 + level
	if _law_on("engineers_charter"):
		turns = maxi(1, turns - int(catalog.laws.engineers_charter.dig_faster))
	return {"turns": turns, "workers": mini(4, 2 + level)}


func _pick_dig_cell(for_space: bool) -> Dictionary:
	if for_space:
		var best := {}
		var best_level := 99
		for key in cells:
			var cell: Dictionary = cells[key]
			if cell.dug or not _beside_dug(cell):
				continue
			if str(cell.find) == "flooded":
				continue
			if int(cell.level) < best_level:
				best_level = int(cell.level)
				best = cell
		if not best.is_empty():
			return best
	var toward := _step_toward_find()
	if not toward.is_empty():
		return toward
	for key in cells:
		var cell: Dictionary = cells[key]
		if not cell.dug and _beside_dug(cell):
			return cell
	return {}


func _step_toward_find() -> Dictionary:
	var queue: Array = []
	var parent := {}
	for key in cells:
		if cells[key].dug:
			queue.append(key)
			parent[key] = ""
	var qi := 0
	while qi < queue.size():
		var key: String = queue[qi]
		qi += 1
		var cell: Dictionary = cells[key]
		for nb in _cell_neighbors(int(cell.level), int(cell.cell)):
			var nk := _ck(nb[0], nb[1])
			if parent.has(nk) or not cells.has(nk):
				continue
			parent[nk] = key
			var nxt: Dictionary = cells[nk]
			if str(nxt.find) != "":
				var cur := nk
				while parent[cur] != "" and not cells[parent[cur]].dug:
					cur = str(parent[cur])
				return cells[cur]
			if not nxt.dug:
				queue.append(nk)
	return {}


func _apply_flood_if_needed() -> void:
	if active_season.is_empty() or str(active_season.id) != "flood":
		return
	if week != int(active_season.start) or pumped:
		if pumped and week == int(active_season.get("start", -1)):
			_log("The Flood hits the pumps and holds.")
		return
	var lowest := -1
	for key in cells:
		if cells[key].dug:
			lowest = maxi(lowest, int(cells[key].level))
	if lowest < 0:
		return
	var names: PackedStringArray = []
	for key in cells:
		var cell: Dictionary = cells[key]
		if int(cell.level) != lowest or not cell.dug or cell.walled:
			continue
		cell.flooded = true
		if str(cell.room) != "":
			var room = _room(str(cell.room))
			if room != null:
				room.offline = true
				names.append(str(catalog.rooms[room.type].name))
	if _any_trait("Claustrophobic"):
		_add_hope(-2, "trait")
	_log("SEASON flood on level %d (%s)" % [lowest, ", ".join(names)], true)


func _needs_pump() -> bool:
	for key in cells:
		if cells[key].flooded:
			return true
	if active_season.is_empty() or str(active_season.id) != "flood" or pumped:
		return false
	return week == int(active_season.start)


# --- council orders ---

func _apply_order(action: Dictionary) -> bool:
	if orders_left <= 0:
		return false
	var order := str(action.get("order", ""))
	var ok := false
	match order:
		"propaganda":
			ok = _order_propaganda(str(action.get("station", "")))
		"aid":
			ok = _order_aid(str(action.get("station", "")))
		"pay":
			ok = _order_pay(str(action.get("demand", "")))
		"gift":
			ok = _order_gift(str(action.get("faction", "")))
		"trade":
			ok = _order_trade()
		"move":
			ok = _order_move(str(action.get("dest", "")))
		"focus":
			ok = _order_focus(str(action.get("station", "")), str(action.get("focus", "")))
		"expedition":
			ok = _order_expedition()
		"approach":
			ok = _order_approach()
		"address":
			ok = _order_address()
	if ok:
		orders_left -= 1
		decisions += 1
	return ok


func _order_propaganda(sid: String) -> bool:
	if not stations.has(sid) or not borders_player(sid):
		return false
	var st: Dictionary = stations[sid]
	var owner := str(st.owner)
	if owner == player or owner == "bunker" or owner == "ruin" or str(st.get("bunker", "")) != "":
		return false
	if int(stock.influence) < int(bal.propaganda_influence):
		return false
	stock.influence = int(stock.influence) - int(bal.propaganda_influence)
	var gain := sympathy_preview(sid)
	st.sympathy = int(st.sympathy) + gain
	_log("ORDER propaganda %s +%d (%d)" % [st.name, gain, int(st.sympathy)])
	if int(st.sympathy) >= 100:
		_capture(sid, player, false)
	return true


func _order_aid(sid: String) -> bool:
	if not stations.has(sid) or not borders_player(sid):
		return false
	var st: Dictionary = stations[sid]
	if str(st.owner) == "bunker" or str(st.owner) == "ruin":
		return false
	var need := _lowest_need(st)
	if need == "":
		return false
	if need == "air":
		if int(stock.air) < 6:
			return false
		stock.air = int(stock.air) - 6
	elif need == "food" or need == "work":
		if int(stock.food) < int(bal.aid_food):
			return false
		stock.food = int(stock.food) - int(bal.aid_food)
	else:
		if int(stock.materials) < 4:
			return false
		stock.materials = int(stock.materials) - 4
	_bump_need(st, need, 0.25)
	_log("ORDER aid %s (%s)" % [st.name, need])
	return true


func _order_pay(did: String) -> bool:
	for d in demands:
		if str(d.id) != did or bool(d.paid):
			continue
		if int(stock.tokens) < int(d.amount):
			return false
		stock.tokens = int(stock.tokens) - int(d.amount)
		d.paid = true
		_add_opinion(str(d.faction), 5)
		_log("ORDER paid %s %d tokens" % [_fname(str(d.faction)), int(d.amount)])
		return true
	return false


func _order_gift(fid: String) -> bool:
	if not opinions.has(fid) or bool(at_war.get(fid, false)):
		return false
	if int(stock.tokens) < int(bal.gift_tokens):
		return false
	stock.tokens = int(stock.tokens) - int(bal.gift_tokens)
	_add_opinion(fid, int(bal.gift_opinion))
	_log("ORDER gift to %s (now %d)" % [_fname(fid), int(opinions[fid])])
	return true


func _order_trade() -> bool:
	if not can_trade():
		return false
	stock.influence = int(stock.influence) - 4
	trade_on = true
	_add_opinion("exchange", 6)
	_log("ORDER trade with the Exchange", true)
	return true


func _order_move(dest: String) -> bool:
	var sq: Dictionary = squads[player]
	if sq.away or not stations.has(dest):
		return false
	var path := _path(str(sq.station), dest)
	if path.size() < 2:
		return false
	return _step_squad(sq, str(path[1]), true)


func _order_focus(sid: String, focus: String) -> bool:
	if focus not in ["food", "air", "defense", "influence"]:
		return false
	if not stations.has(sid) or str(stations[sid].owner) != player or sid == capital_id:
		return false
	stations[sid].focus = focus
	_log("ORDER %s focuses on %s" % [stations[sid].name, focus])
	return true


func _order_expedition() -> bool:
	if not can_expedition():
		return false
	squads[player].away = true
	expedition = {"left": 3, "tunnel": "to_ferry"}
	_log("ORDER expedition to South Ferry", true)
	return true


func _order_approach() -> bool:
	if not can_approach():
		return false
	floor_met = true
	_add_hope(2, "victory")
	_log("The Floor is still holding a meeting. They ask who speaks for Coney Island.", true)
	return true


func _order_address() -> bool:
	_add_hope(1, "address")
	_log("ORDER address the platform")
	return true


func _tick_expedition() -> void:
	if expedition.is_empty():
		return
	expedition.left = int(expedition.left) - 1
	if int(expedition.left) > 0:
		return
	var tunnel := _tunnel_by_id(str(expedition.tunnel))
	if not tunnel.is_empty():
		tunnel.dug = true
	var st: Dictionary = stations.southferry
	st.owner = "neutral"
	st.ruin = false
	st.pop = 18
	st.garrison = 6
	var sq: Dictionary = squads[player]
	sq.away = false
	sq.size = maxi(3, int(round(float(sq.size) * 0.85)))
	stock.materials = int(stock.materials) + 10
	_hire(2)
	expedition = {}
	_log("South Ferry is open. Two people walk back with the squad.", true)


# --- rivals ---

func _plan_intents() -> Array:
	var out: Array = []
	for fid in ["exchange", "directorate"]:
		if _faction_dead(fid):
			continue
		var intent := _plan_one(fid)
		var hide: bool = str(intent.kind) != "demand_posted" and not _has_radio() and rng.randf() < 0.25
		intent.hidden = hide
		out.append(intent)
	return out


func _plan_one(fid: String) -> Dictionary:
	if fid == "exchange" and week > 0 and week % int(bal.demand_every) == 0 and not _demand_open(fid):
		demands.append({
			"id": "d%d" % demand_seq,
			"faction": fid,
			"amount": int(bal.demand_tokens),
			"deadline": 2,
			"paid": false,
		})
		demand_seq += 1
		stats.ultimatums = int(stats.ultimatums) + 1
		return {"faction": fid, "kind": "demand_posted"}
	var sq: Dictionary = squads[fid]
	if int(sq.secure) > 0:
		return {"faction": fid, "kind": "secure", "station": str(sq.station)}
	var target := _campaign_target(fid)
	sq.dest = target
	if target == "":
		return {"faction": fid, "kind": "hold"}
	if fid == "exchange" and not bool(at_war.get(fid, false)):
		return {"faction": fid, "kind": "buy", "station": target}
	return {"faction": fid, "kind": "squad", "station": target}


func _resolve_intent(intent: Dictionary) -> void:
	var fid := str(intent.get("faction", ""))
	var kind := str(intent.get("kind", ""))
	var hidden := bool(intent.get("hidden", false))
	if _faction_dead(fid) or not squads.has(fid):
		return
	match kind:
		"buy":
			_resolve_buy(fid, str(intent.get("station", "")))
		"squad":
			_resolve_squad(fid, str(intent.get("station", "")))
		"secure":
			squads[fid].secure = maxi(0, int(squads[fid].secure) - 1)
			if not hidden:
				_log("%s is securing %s" % [squads[fid].name, stations[str(squads[fid].station)].name])
		"demand_posted", "hold":
			pass
	if hidden and kind in ["buy", "squad"]:
		_log("No warning from %s." % _fname(fid), true)


func _resolve_buy(fid: String, sid: String) -> void:
	if not stations.has(sid):
		return
	var st: Dictionary = stations[sid]
	if str(st.owner) != "neutral":
		return
	st.rival_symp[fid] = int(st.rival_symp.get(fid, 0)) + 18
	_log("%s is buying %s (%d)" % [_fname(fid), st.name, int(st.rival_symp[fid])])
	if int(st.rival_symp[fid]) >= 100:
		_capture(sid, fid, false)


func _resolve_squad(fid: String, target: String) -> void:
	var sq: Dictionary = squads[fid]
	if float(sq.size) < float(sq.max_size) * 0.7:
		sq.size = mini(int(sq.max_size), int(sq.size) + 2)
		_log("%s is refitting at %s" % [sq.name, stations[str(sq.station)].name])
		return
	if target == "" or target == str(sq.station):
		return
	var path := _path(str(sq.station), target)
	if path.size() < 2:
		return
	var nxt := str(path[1])
	var owner := str(stations[nxt].owner)
	if owner == player and not bool(at_war.get(fid, false)):
		_log("%s holds short of %s" % [sq.name, stations[nxt].name])
		return
	_step_squad(sq, nxt, false)


func _step_squad(sq: Dictionary, nxt: String, player_move: bool) -> bool:
	var edge := _edge(str(sq.station), nxt)
	if edge.is_empty():
		return false
	if bool(edge.get("flooded", false)) and not bool(sq.fording):
		sq.fording = true
		_log("%s is held up by flood water toward %s" % [sq.name, stations[nxt].name])
		return true
	sq.fording = false
	var owner := str(stations[nxt].owner)
	if owner == str(sq.faction) or (player_move and (owner == "neutral" or owner == "ruin")):
		sq.station = nxt
		if player_move:
			_log("ORDER move to %s" % stations[nxt].name)
		return true
	if owner == "bunker":
		return false
	if player_move and owner != player and not bool(at_war.get(owner, false)):
		_add_opinion(owner, -20)
	if not player_move and owner == player and not bool(at_war.get(sq.faction, false)):
		return false
	var win := _battle(sq, nxt)
	if win:
		_capture(nxt, str(sq.faction), true)
		sq.station = nxt
		if not player_move:
			sq.secure = int(bal.secure_turns)
	else:
		sq.secure = 1
	return true


func _battle(sq: Dictionary, sid: String) -> bool:
	var st: Dictionary = stations[sid]
	var roll := rng.randf_range(0.8, 1.2)
	var attack := float(sq.size) * float(sq.gear) * (1.0 + float(sq.fight) / 10.0) * roll
	var garrison := float(st.garrison)
	var defender: Dictionary = {}
	if str(st.owner) == player:
		var psq: Dictionary = squads[player]
		if str(psq.station) == sid and not bool(psq.away):
			garrison = float(psq.size)
			defender = psq
	var defense := garrison * float(st.fort) * 1.3
	var win := attack > defense
	var loss := rng.randf_range(0.3, 0.6)
	if win:
		st.garrison = maxi(2, int(round(float(st.garrison) * (1.0 - loss))))
		_log("BATTLE %s takes %s" % [sq.name, st.name], true)
	else:
		sq.size = maxi(2, int(round(float(sq.size) * (1.0 - loss))))
		if not defender.is_empty():
			defender.size = maxi(2, int(round(float(defender.size) * (1.0 - loss * 0.5))))
		_log("BATTLE %s is thrown back from %s" % [sq.name, st.name], true)
	return win


func _capture(sid: String, fid: String, force: bool) -> void:
	var st: Dictionary = stations[sid]
	if str(st.get("bunker", "")) != "" or str(st.owner) == "bunker":
		return
	var prev := str(st.owner)
	if prev == fid:
		return
	st.owner = fid
	st.sympathy = 0
	st.loyalty = 20 if force else 72
	st.unrest = 5 if fid == player else 0
	if str(st.focus) == "":
		st.focus = "food"
	for key in st.rival_symp:
		st.rival_symp[key] = 0
	if opinions.has(prev):
		_add_opinion(prev, -20)
		ambition[prev] = int(ambition.get(prev, 0)) + int(bal.ambition_taken)
		_log("%s will remember %s." % [_fname(prev), st.name])
	if fid == player:
		_add_hope(int(bal.join_hope), "victory")
		_log("JOIN %s (%s)" % [st.name, "force" if force else "peace"], true)
	else:
		_log("%s takes %s" % [_fname(fid), st.name], true)
	if sid == capital_id and fid != player and over == "":
		over = "capital"
		_log("The yard has fallen.", true)


func _campaign_target(fid: String) -> String:
	var best := ""
	var best_hops := 999
	for sid in _owned_by(fid):
		for n in _neighbors(sid):
			var st: Dictionary = stations[n]
			var owner := str(st.owner)
			if owner == fid or owner == "bunker" or owner == "ruin":
				continue
			if owner == player and not bool(at_war.get(fid, false)):
				continue
			if owner != "neutral" and owner != player:
				continue
			var hops := _hops(n, capital_id)
			if hops < best_hops:
				best_hops = hops
				best = n
	return best


func _deliver_outposts() -> void:
	for sid in stations.keys():
		var st: Dictionary = stations[sid]
		if str(st.owner) != player or sid == capital_id:
			continue
		if _connected(sid):
			_outpost_yield(st)


func _tick_holdings() -> void:
	for sid in stations.keys():
		var st: Dictionary = stations[sid]
		if str(st.owner) != player or sid == capital_id:
			continue
		if int(st.unrest) > 0:
			stats.unrest_weeks = int(stats.unrest_weeks) + 1
			st.unrest = int(st.unrest) - 1
			st.loyalty = int(st.loyalty) - 2
		if _avg_fill(st) < 0.45:
			st.loyalty = int(st.loyalty) - 4
			st.rival_symp.exchange = int(st.rival_symp.exchange) + 8
		if not _connected(sid):
			st.loyalty = int(st.loyalty) - 5
		st.loyalty = clampi(int(st.loyalty), 0, 100)
		if int(st.loyalty) < 30 and int(st.rival_symp.exchange) > int(st.loyalty):
			_log("%s slips toward the Exchange" % st.name, true)
			_capture(sid, "exchange", false)


func _outpost_yield(st: Dictionary) -> void:
	var n := int(bal.outpost_yield_unrest) if int(st.unrest) > 0 else int(bal.outpost_yield)
	match str(st.focus):
		"air":
			stock.air = int(stock.air) + n
		"defense":
			st.garrison = int(st.garrison) + 1
		"influence":
			stock.influence = int(stock.influence) + int(bal.outpost_influence)
		_:
			stock.food = int(stock.food) + n


func _drift_opinion() -> void:
	for fid in opinions.keys():
		if fid == "directorate":
			opinions[fid] = int(opinions[fid]) + int(catalog.factions.directorate.get("opinion_drift", -1))
		elif int(opinions[fid]) > 0:
			opinions[fid] = int(opinions[fid]) - 1
		elif int(opinions[fid]) < 0:
			opinions[fid] = int(opinions[fid]) + 1
		opinions[fid] = clampi(int(opinions[fid]), -100, 100)
		if int(opinions[fid]) <= int(bal.opinion_war) and not bool(at_war.get(fid, false)):
			at_war[fid] = true
			_log("WAR %s" % _fname(fid), true)


# --- people ---

func _auto_staff() -> void:
	var used := {}
	for id in _locked_ids():
		used[id] = true
	for person in residents:
		if int(person.sick) > 0 or int(person.absent) > 0:
			used[str(person.id)] = true
	for room in rooms:
		room.staff = []
	for type in _priority_types():
		for room in rooms:
			if room.type != type or room.offline:
				continue
			var defin: Dictionary = catalog.rooms[type]
			var skill := str(defin.get("skill", ""))
			while room.staff.size() < int(defin.staff_min):
				var pick := _best_free(skill, used)
				if pick == "":
					break
				used[pick] = true
				room.staff.append(pick)
	for type in _priority_types():
		for room in rooms:
			if room.type != type or room.offline:
				continue
			var defin: Dictionary = catalog.rooms[type]
			var skill := str(defin.get("skill", ""))
			while room.staff.size() < int(defin.staff_max):
				var pick := _best_free(skill, used)
				if pick == "":
					break
				used[pick] = true
				room.staff.append(pick)


func _priority_types() -> Array:
	var list: Array = []
	if room_count("generator") > 0 and int(stock.power) < 28:
		list.append("generator")
	if int(stock.food) < food_need() * 4:
		list.append("hydroponics")
	if int(stock.air) < air_need() * 4:
		list.append("air_filter")
	list.append_array(["hydroponics", "air_filter", "generator", "workshop", "meeting_hall", "infirmary", "radio"])
	var seen := {}
	var out: Array = []
	for type in list:
		if seen.has(type):
			continue
		seen[type] = true
		out.append(type)
	return out


func _best_free(skill: String, used: Dictionary) -> String:
	var best := ""
	var best_v := -1
	for person in residents:
		var id := str(person.id)
		if used.has(id):
			continue
		var v := 0 if skill == "" else int(person.skills.get(skill, 0))
		if v > best_v:
			best_v = v
			best = id
	return best


func _pull_workers(n: int, skill: String) -> Array:
	var pool: Array = []
	var locked := _locked_ids()
	for person in residents:
		var id := str(person.id)
		if locked.has(id) or int(person.absent) > 0 or int(person.sick) > 0:
			continue
		pool.append(person)
	if pool.size() < n:
		return []
	pool.sort_custom(func(a, b): return int(a.skills.get(skill, 0)) > int(b.skills.get(skill, 0)))
	var chosen: Array = []
	for i in n:
		var id := str(pool[i].id)
		_unassign(id)
		chosen.append(id)
	return chosen


func _locked_ids() -> Array:
	var ids: Array = []
	if not dig.is_empty():
		ids.append_array(dig.workers)
	if not build.is_empty():
		ids.append_array(build.workers)
	return ids


func _free_count() -> int:
	var locked := {}
	for id in _locked_ids():
		locked[id] = true
	var n := 0
	for person in residents:
		if locked.has(str(person.id)) or int(person.sick) > 0 or int(person.absent) > 0:
			continue
		n += 1
	return n


func _unassign(id: String) -> void:
	for room in rooms:
		var keep: Array = []
		for sid in room.staff:
			if str(sid) != id:
				keep.append(sid)
		room.staff = keep


func _hire(n: int) -> void:
	var firsts: Array = catalog.names.first
	var lasts: Array = catalog.names.last
	var traits: Array = catalog.names.traits
	for _i in n:
		next_person += 1
		var id := "n%d" % next_person
		var trait_list: Array = []
		if rng.randf() < 0.65:
			trait_list.append(str(traits[rng.randi() % traits.size()]))
		var person := {
			"id": id,
			"name": "%s %s" % [str(firsts[rng.randi() % firsts.size()]), str(lasts[rng.randi() % lasts.size()])],
			"skills": {
				"labor": rng.randi_range(1, 4),
				"tech": rng.randi_range(1, 4),
				"care": rng.randi_range(1, 3),
				"talk": rng.randi_range(1, 3),
				"fight": rng.randi_range(1, 3),
			},
			"traits": trait_list,
			"sick": 0,
			"absent": 0,
		}
		residents.append(person)
		people[id] = person


func _kill(n: int, why: String) -> void:
	_shed(n)
	if n > 0:
		_log("%s. %d dead." % [why, n], true)


func _shed(n: int) -> void:
	var pool: Array = []
	for person in residents:
		if not _is_council(str(person.id)):
			pool.append(person)
	pool.sort_custom(func(a, b): return _skill_total(a) < _skill_total(b))
	var lost := 0
	while lost < n and not pool.is_empty():
		var person: Dictionary = pool.pop_front()
		_remove_resident(str(person.id))
		lost += 1


func _remove_resident(id: String) -> void:
	_unassign(id)
	people.erase(id)
	var keep: Array = []
	for person in residents:
		if str(person.id) != id:
			keep.append(person)
	residents = keep
	if not dig.is_empty():
		dig.workers = _without(dig.workers, id)
	if not build.is_empty():
		build.workers = _without(build.workers, id)


func _infect(n: int) -> void:
	var pool: Array = []
	for person in residents:
		if int(person.sick) <= 0:
			pool.append(person)
	for _i in n:
		if pool.is_empty():
			return
		var person: Dictionary = pool.pop_at(rng.randi() % pool.size())
		person.sick = 3


func _heal() -> void:
	var cures := 0
	for room in rooms:
		if room.type != "infirmary" or room.offline:
			continue
		for id in room.staff:
			var person: Dictionary = people[id]
			if int(person.sick) <= 0 and int(person.absent) <= 0:
				cures += 1
	if cures <= 0:
		return
	for person in residents:
		if cures <= 0:
			break
		if int(person.sick) > 0:
			person.sick = 0
			cures -= 1


func _tick_sickness() -> void:
	for person in residents:
		if int(person.absent) > 0:
			person.absent = int(person.absent) - 1
		if int(person.sick) > 0:
			person.sick = int(person.sick) - 1


func _double_shift_sickness() -> void:
	var chance := float(catalog.laws.double_shifts.sick_chance)
	for room in rooms:
		if room.type in ["quarters", "platform", "meeting_hall", "infirmary"]:
			continue
		for id in room.staff:
			if rng.randf() < chance:
				people[id].sick = maxi(int(people[id].sick), 2)


func _cough_pull_workers() -> void:
	if quarantine:
		return
	var pull := int(bal.cough_pull)
	if pull <= 0:
		return
	for room in rooms:
		var removed := 0
		var keep: Array = []
		for id in room.staff:
			if removed < pull and people.has(str(id)):
				people[str(id)].sick = maxi(int(people[str(id)].sick), 2)
				removed += 1
				continue
			keep.append(id)
		room.staff = keep


func _pull_sick_from_rooms() -> void:
	for room in rooms:
		var keep: Array = []
		for id in room.staff:
			if people.has(str(id)) and int(people[str(id)].sick) > 0:
				continue
			keep.append(id)
		room.staff = keep


func _spread_cough() -> void:
	if quarantine:
		return
	var chance := float(bal.cough_spread)
	var sick_cells := {}
	for room in rooms:
		for id in room.staff:
			if int(people[id].sick) > 0:
				sick_cells[_ck(int(room.level), int(room.cell))] = true
	if sick_cells.is_empty():
		return
	for room in rooms:
		var key := _ck(int(room.level), int(room.cell))
		var near := sick_cells.has(key)
		if not near:
			for nb in _cell_neighbors(int(room.level), int(room.cell)):
				if sick_cells.has(_ck(nb[0], nb[1])):
					near = true
		if not near:
			continue
		for id in room.staff:
			if int(people[id].sick) <= 0 and rng.randf() < chance:
				people[id].sick = 2


func _growth_scale() -> float:
	if hope < int(bal.growth_hope_low):
		return float(bal.growth_scale_low)
	if hope <= int(bal.growth_hope_high):
		return float(bal.growth_scale_mid)
	return float(bal.growth_scale_high)


func _grow() -> void:
	if residents.size() >= housing():
		return
	if food_buffer_weeks() <= float(bal.growth_buffer):
		return
	growth_bank += float(residents.size()) * float(bal.growth_rate) * _growth_scale()
	var born := 0
	var guard := 0
	while growth_bank >= 1.0 and residents.size() < housing() and food_buffer_weeks() > float(bal.growth_buffer) and guard < 6:
		guard += 1
		growth_bank -= 1.0
		_hire(1)
		born += 1
	if born > 0:
		_log("BORN %d" % born, true)


func _is_council(id: String) -> bool:
	for seat in council:
		if str(seat.id) == id:
			return true
	return false


func _has_trait(person: Dictionary, trait_name: String) -> bool:
	return person.traits.has(trait_name)


func _any_trait(trait_name: String) -> bool:
	for person in residents:
		if _has_trait(person, trait_name):
			return true
	return false


func _skill_total(person: Dictionary) -> int:
	var n := 0
	for key in person.skills:
		n += int(person.skills[key])
	return n


# --- events ---

func _queue_crunch() -> void:
	if crunch_week <= 0 or week != crunch_week:
		return
	var legs := _crunch_legs()
	var costs := _bill_three(int(stock.materials))
	for i in legs.size():
		legs[i]["cost"] = int(costs[i])
	legs.sort_custom(func(a, b): return int(a.pain) > int(b.pain))
	var names: PackedStringArray = []
	for leg in legs:
		names.append(str(leg.short))
	_log("PRESSURE %s" % ", ".join(names), true)
	for leg in legs:
		_present_event(_crunch_event(leg))


func _crunch_legs() -> Array:
	var food_gap := _cover_gap("food")
	var air_gap := _cover_gap("air")
	var power_pain := 14 if int(stock.power) < _power_need() * 2 else 5
	var belt_pain := food_need() if food_buffer_weeks() < 3.0 else 3
	var shop_pain := 8 if int(stock.materials) < 12 else 3
	var gen_pain := 12 if int(stock.power) < _power_need() else 4
	var pantry := {
		"id": "pantry", "short": "the pantry", "title": "The pantry comes up short",
		"text": "This week's meals outrun the stores. Materials can close it. Leaving it spends what you saved.",
		"pay": "Spend %d materials to close the gap", "suffer": "Let the stores run down",
		"pain": food_gap, "hit": {"food": -food_gap},
	}
	var ducts := {
		"id": "ducts", "short": "the ducts", "title": "Ice in the ducts",
		"text": "Meltwater has frozen in the vent runs. Clear it, or the yard draws twice the power tonight.",
		"pay": "Spend %d materials to clear the ducts", "suffer": "Leave the ice",
		"pain": power_pain, "hit": {"discontent": 4, "power_double": true},
	}
	var belt := {
		"id": "lamps", "short": "the belt", "title": "The grow lamps snap",
		"text": "A belt on the hydroponic lamps snaps. Replace it, or the beds give half a crop this week.",
		"pay": "Spend %d materials on a new belt", "suffer": "Let the beds run at half",
		"pain": belt_pain, "hit": {"hope": -2, "discontent": 2, "hydro_down": true},
	}
	var stacks := {
		"id": "stacks", "short": "the stacks", "title": "The charcoal beds pack solid",
		"text": "The air filters are caked. Materials can clear them. Leaving them spends the air you saved.",
		"pay": "Spend %d materials to clear the stacks", "suffer": "Let the air run down",
		"pain": air_gap, "hit": {"air": -air_gap},
	}
	var shop := {
		"id": "shopbelt", "short": "the workshop", "title": "A belt in the workshop slips",
		"text": "The workshop belt is off its wheel. Fix it, or the shop makes nothing this week.",
		"pay": "Spend %d materials to seat the belt", "suffer": "Let the shop sit idle",
		"pain": shop_pain, "hit": {"shop_down": true, "discontent": 2},
	}
	var dynamo := {
		"id": "dynamo", "short": "the dynamo", "title": "The dynamo runs hot",
		"text": "The generator bearing is dry. Grease it, or the dynamo makes half power tonight.",
		"pay": "Spend %d materials to grease the bearing", "suffer": "Let the dynamo limp",
		"pain": gen_pain, "hit": {"gen_down": true, "hope": -1},
	}
	if crunch_kind == 1:
		return [stacks, ducts, shop]
	if crunch_kind == 2:
		return [pantry, dynamo, belt]
	return [pantry, ducts, belt]


func _crunch_event(leg: Dictionary) -> Dictionary:
	var cost := int(leg.cost)
	var suffer: Dictionary = {"id": "leave", "label": str(leg.suffer), "crunch_suffer": true}
	var hit: Dictionary = leg.hit
	for key in hit:
		suffer[key] = hit[key]
	return {
		"id": str(leg.id),
		"title": str(leg.title),
		"major": true,
		"crunch": true,
		"text": str(leg.text),
		"choices": [
			{"id": "pay", "label": str(leg.pay) % cost, "cost": {"materials": cost}},
			suffer,
		],
	}


func _bill_three(pool: int) -> Array:
	if pool < 2:
		return [1, 1, 1]
	var a := maxi(1, int(pool / 3) + crunch_rng.randi_range(-1, 1))
	var b := maxi(1, int(pool / 3) + crunch_rng.randi_range(-1, 1))
	while a + b > pool and (a > 1 or b > 1):
		if a >= b and a > 1:
			a -= 1
		elif b > 1:
			b -= 1
		else:
			break
	var c := pool + 1 - a - b
	var costs := [a, b, maxi(1, c)]
	for i in range(costs.size() - 1, 0, -1):
		var j := crunch_rng.randi_range(0, i)
		var swap = costs[i]
		costs[i] = costs[j]
		costs[j] = swap
	return costs


func _cover_gap(key: String) -> int:
	var have := int(stock.get(key, 0))
	var need := food_need() if key == "food" else air_need()
	var net := output_of(key) - need
	return maxi(need, have - maxi(0, net))


func _roll_events() -> void:
	var pool := _event_pool(rng.randf() < 0.4)
	if pool.is_empty():
		pool = _event_pool(false)
	if pool.is_empty():
		return
	_present_event(_weighted(pool))


func front_event() -> Dictionary:
	if pending.is_empty():
		return {}
	return pending[0]


func modal_ids() -> Array:
	var ids: Array = []
	var seen := {}
	for ev in pending:
		var id := str(ev.id)
		if seen.has(id):
			continue
		seen[id] = true
		ids.append(id)
	return ids


func dismiss_front() -> bool:
	if pending.is_empty():
		return false
	var ev: Dictionary = pending[0]
	var choice := _free_choice(ev)
	if choice.is_empty():
		pending.pop_front()
		return true
	if not _apply_event({"event_id": str(ev.id), "choice_id": str(choice.id)}):
		pending.pop_front()
	return pending.is_empty() or str(pending[0].get("id", "")) != str(ev.id)


func _free_choice(ev: Dictionary) -> Dictionary:
	for choice in ev.choices:
		if _cost_empty(choice.get("cost", {})):
			return choice
	return {}


func _cost_empty(cost) -> bool:
	if typeof(cost) != TYPE_DICTIONARY:
		return true
	for key in cost:
		if int(cost[key]) > 0:
			return false
	return true


func _present_event(ev: Dictionary) -> void:
	var id := str(ev.id)
	if _has_event(pending, id) or week_event_ids.has(id):
		return
	var copy: Dictionary = _copy(ev)
	if id == "refugees":
		var n := rng.randi_range(int(bal.refugee_min), int(bal.refugee_max))
		copy.text = "%d people are at the yard gate with a story about a collapse north of Atlantic Av." % n
		for choice in copy.choices:
			if str(choice.id) == "take":
				choice.people = n
				choice.label = "Take in %d" % n
	week_event_ids[id] = true
	pending.append(copy)
	event_last[id] = week


func _event_pool(major_only: bool) -> Array:
	var pool: Array = []
	for ev in catalog.events:
		if major_only and not bool(ev.get("major", false)):
			continue
		if not major_only and bool(ev.get("major", false)) and rng.randf() < 0.5:
			continue
		if _event_ok(ev):
			pool.append(ev)
	if pool.is_empty() and not major_only:
		for ev in catalog.events:
			if not _event_ok(ev):
				continue
			pool.append(ev)
	return pool


func _event_ok(ev: Dictionary) -> bool:
	var id := str(ev.id)
	if id == "lamps" and week == crunch_week:
		return false
	var cool := int(ev.get("cooldown", 6))
	if event_last.has(id) and week - int(event_last[id]) < cool:
		return false
	if week < int(ev.get("min_week", 1)):
		return false
	if week > int(ev.get("max_week", 99)):
		return false
	if discontent < int(ev.get("min_discontent", 0)):
		return false
	if str(ev.get("requires", "")) == "digging" and dig.is_empty():
		return false
	return true


func _resolve_pending() -> void:
	var guard := 0
	while not pending.is_empty() and guard < 6:
		guard += 1
		var ev: Dictionary = pending[0]
		var choice: Dictionary = ev.choices[0]
		for c in ev.choices:
			if _afford(c.get("cost", {})):
				choice = c
				break
		if not _apply_event({"event_id": ev.id, "choice_id": choice.id}):
			pending.pop_front()


func _apply_event(action: Dictionary) -> bool:
	if pending.is_empty():
		return false
	var ev: Dictionary = pending[0]
	if str(ev.id) != str(action.get("event_id", "")):
		return false
	var choice := {}
	for c in ev.choices:
		if str(c.id) == str(action.get("choice_id", "")):
			choice = c
	if choice.is_empty() or not _afford(choice.get("cost", {})):
		return false
	_pay(choice.get("cost", {}))
	_apply_deltas(choice)
	if bool(choice.get("crunch_suffer", false)):
		var drops: Array = stats.get("crunch_drops", [])
		drops.append(str(ev.title))
		stats["crunch_drops"] = drops
	pending.pop_front()
	decisions += 1
	_log("EVENT %s: %s" % [ev.title, choice.label], bool(ev.get("major", false)))
	return true


func _apply_deltas(choice: Dictionary) -> void:
	for key in ["food", "air", "power", "materials", "tokens", "influence"]:
		if choice.has(key):
			stock[key] = maxi(0, int(stock[key]) + int(choice[key]))
	if choice.has("hope"):
		_add_hope(int(choice.hope), "event")
	if choice.has("discontent"):
		_add_discontent(int(choice.discontent), "event")
	if choice.has("people"):
		var n := int(choice.people)
		if n > 0:
			_hire(n)
		elif n < 0:
			_shed(-n)
	if choice.has("sick"):
		_infect(int(choice.sick))
	if choice.has("efficiency"):
		for room in rooms:
			if room.type == "air_filter":
				room.efficiency = clampf(float(room.efficiency) + float(choice.efficiency), 0.25, 1.0)
	if choice.has("papers"):
		artifacts.papers = int(artifacts.papers) + int(choice.papers)
		if int(choice.papers) > 0:
			_log("A page mentions the Floor.", true)
	if choice.has("synod"):
		synod += int(choice.synod)
	if choice.has("opinion_exchange"):
		_add_opinion("exchange", int(choice.opinion_exchange))
	if choice.has("opinion_directorate"):
		_add_opinion("directorate", int(choice.opinion_directorate))
	if choice.has("trait_hope"):
		for trait_name in choice.trait_hope:
			if _any_trait(str(trait_name)):
				_add_hope(int(choice.trait_hope[trait_name]), "trait")
	if choice.has("trait_absent"):
		for trait_name in choice.trait_absent:
			for person in residents:
				if _has_trait(person, str(trait_name)):
					person.absent = maxi(int(person.absent), int(choice.trait_absent[trait_name]))
					_add_hope(-2, "trait")
	if bool(choice.get("power_double", false)):
		crunch_power = true
	if bool(choice.get("hydro_down", false)):
		belt_down = true
	if bool(choice.get("shop_down", false)):
		workshop_down = true
	if bool(choice.get("gen_down", false)):
		gen_down = true


# --- map ---

func _neighbors(sid: String) -> Array:
	var out: Array = []
	for tunnel in tunnels:
		if not _edge_open(tunnel):
			continue
		if str(tunnel.a) == sid:
			out.append(str(tunnel.b))
		elif str(tunnel.b) == sid:
			out.append(str(tunnel.a))
	return out


func _edge_open(tunnel: Dictionary) -> bool:
	if bool(tunnel.sealed) and not bool(tunnel.dug):
		return false
	if int(tunnel.closed_until) > week:
		return false
	return true


func _edge(a: String, b: String) -> Dictionary:
	for tunnel in tunnels:
		var ta := str(tunnel.a)
		var tb := str(tunnel.b)
		if (ta == a and tb == b) or (ta == b and tb == a):
			return tunnel
	return {}


func _path(src: String, dst: String) -> Array:
	if src == dst:
		return [src]
	var queue: Array = [src]
	var prev := {src: ""}
	var qi := 0
	while qi < queue.size():
		var cur: String = queue[qi]
		qi += 1
		for n in _neighbors(cur):
			var nb := str(n)
			if prev.has(nb):
				continue
			prev[nb] = cur
			if nb == dst:
				var chain: Array = []
				var p := nb
				while p != "":
					chain.push_front(p)
					p = str(prev[p])
				return chain
			queue.append(nb)
	return []


func _hops(a: String, b: String) -> int:
	var path := _path(a, b)
	if path.is_empty():
		return 999
	return path.size() - 1


func _connected(sid: String) -> bool:
	if sid == capital_id:
		return true
	var queue: Array = [capital_id]
	var seen := {capital_id: true}
	var qi := 0
	while qi < queue.size():
		var cur: String = queue[qi]
		qi += 1
		if cur == sid:
			return true
		for n in _neighbors(cur):
			if seen.has(n):
				continue
			if str(stations[n].owner) != player:
				continue
			seen[n] = true
			queue.append(n)
	return false


func _owned_by(fid: String) -> Array:
	var out: Array = []
	for sid in stations:
		if str(stations[sid].owner) == fid:
			out.append(str(sid))
	return out


func _faction_dead(fid: String) -> bool:
	var cap := str(catalog.factions[fid].capital)
	return str(stations[cap].owner) != fid


func _season_clock() -> void:
	var warning := int(bal.season_warning)
	for season in bal.seasons:
		var at := int(season.week)
		if week == at - warning:
			_log("SEASON warning %s" % str(season.id), true)
		if week == at:
			active_season = {"id": str(season.id), "start": at, "until": at + int(season.weeks) - 1}
			_log("SEASON %s" % str(season.id), true)
			if str(season.id) == "cough":
				_infect(int(bal.cough_infect))
	if not active_season.is_empty() and week > int(active_season.until):
		active_season = {}


func _avg_fill(st: Dictionary) -> float:
	var needs: Array = st.needs
	if needs.is_empty():
		return 0.5
	var sum := 0.0
	for need in needs:
		sum += float(need.fill)
	return sum / float(needs.size())


func _lowest_need(st: Dictionary) -> String:
	var best := ""
	var best_v := 2.0
	for need in st.needs:
		if float(need.fill) < best_v:
			best_v = float(need.fill)
			best = str(need.id)
	return best


func _bump_need(st: Dictionary, need_id: String, amount: float) -> void:
	for need in st.needs:
		if str(need.id) == need_id:
			need.fill = clampf(float(need.fill) + amount, 0.0, 1.0)


func _demand_open(fid: String) -> bool:
	for d in demands:
		if str(d.faction) == fid and not bool(d.paid):
			return true
	return false


func _has_radio() -> bool:
	for room in rooms:
		if room.type == "radio" and not room.offline and room.staff.size() >= 1:
			return true
	return false


func _heal_squads() -> void:
	for fid in squads:
		var sq: Dictionary = squads[fid]
		if not bool(sq.away) and int(sq.size) < int(sq.max_size):
			sq.size = mini(int(sq.max_size), int(sq.size) + int(bal.squad_heal))


# --- setup and small helpers ---

func _init_people() -> void:
	for raw in catalog.residents:
		var person: Dictionary = _copy(raw)
		person.sick = 0
		person.absent = 0
		residents.append(person)
		people[str(person.id)] = person
		if str(person.get("council", "")) != "":
			council.append({"role": str(person.council), "id": str(person.id), "loyalty": 80})


func _init_grid() -> void:
	var levels := int(catalog.grid.levels)
	var width := int(catalog.grid.cells)
	for level in levels:
		for cell in width:
			cells[_ck(level, cell)] = {
				"level": level, "cell": cell, "dug": false, "room": "",
				"find": "", "flooded": false, "walled": false,
			}
	for find in catalog.grid.finds:
		var key := _ck(int(find.level), int(find.cell))
		if cells.has(key):
			cells[key].find = str(find.find)
	for open in catalog.grid.open:
		var key := _ck(int(open.level), int(open.cell))
		cells[key].dug = true
		var room_type := str(open.room)
		if room_type != "":
			_place_room(room_type, int(open.level), int(open.cell))


func _init_map() -> void:
	for raw in catalog.stations:
		var st: Dictionary = _copy(raw)
		st.sympathy = 0
		st.loyalty = 40 if str(st.owner) == "neutral" else 75
		st.unrest = 0
		st.focus = ""
		st.rival_symp = {"exchange": 0, "directorate": 0}
		var needs: Array = []
		for need in st.needs:
			needs.append({"id": str(need), "fill": 0.4})
		st.needs = needs
		stations[str(st.id)] = st
	for raw in catalog.tunnels:
		var tunnel: Dictionary = _copy(raw)
		tunnel.sealed = bool(tunnel.get("sealed", false))
		tunnel.dug = not tunnel.sealed
		tunnel.flooded = bool(tunnel.get("flooded", false))
		tunnel.closed_until = 0
		if not tunnel.has("id"):
			tunnel.id = "%s_%s" % [str(tunnel.a), str(tunnel.b)]
		tunnels.append(tunnel)
	for fid in ["exchange", "directorate"]:
		var fac: Dictionary = catalog.factions[fid]
		opinions[fid] = int(fac.opinion)
		ambition[fid] = int(fac.ambition)
		at_war[fid] = false


func _init_squads() -> void:
	var pb: Dictionary = bal.player_squad
	squads[player] = {
		"faction": player, "station": capital_id, "size": int(pb.size), "max_size": int(pb.size),
		"gear": float(pb.gear), "fight": int(people.jonah.skills.fight), "name": "Jonah Peck",
		"dest": "", "secure": 0, "away": false, "fording": false,
	}
	for fid in ["exchange", "directorate"]:
		var fac: Dictionary = catalog.factions[fid]
		var sq: Dictionary = fac.squad
		squads[fid] = {
			"faction": fid, "station": str(fac.capital), "size": int(sq.size), "max_size": int(sq.size),
			"gear": float(sq.gear), "fight": int(sq.fight), "name": str(sq.name),
			"dest": "", "secure": 0, "away": false, "fording": false,
		}


func _place_room(type: String, level: int, cell: int) -> void:
	var uid := "room_%d_%d_%s" % [level, cell, type]
	var room := {
		"uid": uid, "type": type, "level": level, "cell": cell,
		"upgrade": 0, "efficiency": 1.0, "staff": [], "offline": false,
	}
	rooms.append(room)
	cells[_ck(level, cell)].room = uid


func _room(uid: String):
	for room in rooms:
		if str(room.uid) == uid:
			return room
	return null


func _cell_buildable(cell: Dictionary) -> bool:
	if not cell.dug or str(cell.room) != "" or cell.flooded or cell.walled:
		return false
	if not build.is_empty() and int(build.level) == int(cell.level) and int(build.cell) == int(cell.cell):
		return false
	return true


func _first_build_cell() -> Dictionary:
	var best := {}
	var best_level := 99
	for key in cells:
		var cell: Dictionary = cells[key]
		if not _cell_buildable(cell):
			continue
		if int(cell.level) < best_level:
			best_level = int(cell.level)
			best = cell
	return best


func _beside_dug(cell: Dictionary) -> bool:
	for nb in _cell_neighbors(int(cell.level), int(cell.cell)):
		var key := _ck(nb[0], nb[1])
		if cells.has(key) and cells[key].dug:
			return true
	return false


func _cell_neighbors(level: int, cell: int) -> Array:
	var out: Array = []
	var width := int(catalog.grid.cells)
	var levels := int(catalog.grid.levels)
	if cell > 0:
		out.append([level, cell - 1])
	if cell + 1 < width:
		out.append([level, cell + 1])
	if level > 0:
		out.append([level - 1, cell])
	if level + 1 < levels:
		out.append([level + 1, cell])
	return out


func _ck(level: int, cell: int) -> String:
	return "%d:%d" % [level, cell]


func _law_on(law_id: String) -> bool:
	return laws_on.has(law_id)


func _afford(cost) -> bool:
	if not (cost is Dictionary):
		return true
	for key in cost:
		if int(stock.get(key, 0)) < int(cost[key]):
			return false
	return true


func _pay(cost) -> void:
	if not (cost is Dictionary):
		return
	for key in cost:
		stock[key] = int(stock.get(key, 0)) - int(cost[key])


func _add_opinion(fid: String, amount: int) -> void:
	if not opinions.has(fid):
		return
	opinions[fid] = clampi(int(opinions[fid]) + amount, -100, 100)


func _staff_line() -> String:
	var bits: PackedStringArray = []
	for room in rooms:
		if room.staff.size() == 0:
			continue
		bits.append("%s %d" % [str(room.type), room.staff.size()])
	return ", ".join(bits)


func _intent_text(intent: Dictionary) -> String:
	var fid := _fname(str(intent.get("faction", "")))
	var kind := str(intent.get("kind", ""))
	var sid := str(intent.get("station", ""))
	var station_name := sid
	if stations.has(sid):
		station_name = str(stations[sid].name)
	match kind:
		"squad":
			return "%s squad moving to %s" % [fid, station_name]
		"buy":
			return "%s will buy sympathy at %s" % [fid, station_name]
		"secure":
			return "%s is securing %s" % [fid, station_name]
		"demand_posted":
			return "%s will demand tokens" % fid
		_:
			return "%s holds" % fid


func _fname(fid: String) -> String:
	if catalog.factions.has(fid):
		return str(catalog.factions[fid].short)
	return fid


func _tunnel_by_id(id: String) -> Dictionary:
	for tunnel in tunnels:
		if str(tunnel.id) == id:
			return tunnel
	return {}


func _has_event(rows: Array, id: String) -> bool:
	for ev in rows:
		if str(ev.id) == id:
			return true
	return false


func _drop_id(rows: Array, id: String) -> Array:
	var keep: Array = []
	for ev in rows:
		if str(ev.id) != id:
			keep.append(ev)
	return keep


func _weighted(pool: Array) -> Dictionary:
	var total := 0
	for ev in pool:
		total += int(ev.get("weight", 1))
	if total <= 0:
		return pool[0]
	var roll := rng.randi_range(1, total)
	var acc := 0
	for ev in pool:
		acc += int(ev.get("weight", 1))
		if roll <= acc:
			return ev
	return pool[0]


func _without(rows: Array, id: String) -> Array:
	var keep: Array = []
	for row in rows:
		if str(row) != id:
			keep.append(row)
	return keep


func _copy(value):
	return JSON.parse_string(JSON.stringify(value))


func _invariants() -> void:
	for key in stock:
		if int(stock[key]) < 0:
			errors.append("W%d negative %s" % [week, key])
			stock[key] = 0
	if hope < 0 or hope > 100 or discontent < 0 or discontent > 100:
		errors.append("W%d meters" % week)
	var seen := {}
	for person in residents:
		var id := str(person.id)
		if seen.has(id) or not people.has(id):
			errors.append("resident index %s" % id)
		seen[id] = true
	for room in rooms:
		var defin: Dictionary = catalog.rooms[room.type]
		if int(defin.staff_max) > 0 and room.staff.size() > int(defin.staff_max):
			errors.append("overstaff %s" % room.type)
		if int(defin.staff_max) == 0 and room.staff.size() > 0:
			errors.append("staffed %s" % room.type)
		for id in room.staff:
			if not people.has(str(id)):
				errors.append("ghost staff")
	if not errors.is_empty() and over == "":
		over = "error"


func _log(text: String, important := false) -> void:
	log.append({"week": week, "text": text, "important": important})
