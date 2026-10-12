class_name Game
extends RefCounted
const Brief = preload("res://sim/brief.gd")
const JOURNAL_MAX := 200

## One week is dawn, station and council actions, the rival phase, then night.
## No nodes. Content comes from the JSON catalog.

var seed := 1
var week := 1
var max_weeks := 40
var over := ""
var player := "depot"
var player_lean := "craft"
var capital_id := "southdepot"

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
var opinion_memory := {}
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
var flood_guard := false
var quarantine := false
var synod := 0
var floor_met := false
var orders_left := 0
var seat_used := {}
var queued_orders: Array = []
var order_reports: Array = []
var choice_results: Array = []
var decisions := 0
var hope_zero := 0
var next_person := 0
var demand_seq := 1
var log: Array = []
var journal: Array = []
## Voice lines already heard this playthrough, keyed by line id.
var vo_heard := {}
var radio_week := 0
## Conditions waiting to be voiced, matched to "system" lines in data/vo by the UI, which clears them.
## Each name appears once, so the list stays small when nothing drains it.
var vo_cues: Array = []
const VO_COOLDOWN := 6
## Leader opinion of the station, -100..100 per leader faction, apart from the map's `opinions`.
var standing := {}
## The last few deeds each leader remembers, as {"week", "deed", ...}; the UI words them.
var standing_memory := {}
## The leader at the door this week: {"faction", "week", "target"}. Empty when nobody waits.
var audience := {}
var audience_last := {}
var audience_due := {}
var audience_deals := {}
## Each leader's first audience answer this run: {faction: {"answer": "accepted"|"refused"|"silence", "week"}}.
## Set once, never overwritten; leader consequence events read it.
var leader_answers := {}
## Truth fragments learned this run (docs/STORY.md): {id: {"known": true, "how": "honest"|"dirty"|"found", "week"}}.
## Set once by know_fragment(), never overwritten.
var fragments := {}
## Testimonies already granted for resident stories heard, one per STORY_WORDS_EVERY distinct stories.
var story_words := 0
## Week each leader was last helped; help waits audience_cooldown_weeks whatever the regard band.
var help_last := {}
## Bunker scenes (events with "trigger") an order has set off, shown at the next dawn in this order.
var story_queue: Array = []
## Proofs gained from choices ("proof": n) on top of the fragments learned honestly.
var proof_extra := 0
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
var check_rng := RandomNumberGenerator.new()
var check_schedule: Array = []
var white_pending: Array = []
var vent_cut := 0
var relations := {}
var flags := {}
var last_check := {}
var crunch_power := false
var belt_down := false
var workshop_down := false
var gen_down := false
var event_last := {}
var week_event_ids := {}
var power_order: Array = []
var event_times := {}
var events_seen := {}
var event_history: Array = []
var follows: Array = []
var pressure := {}
var warning_weeks := {}
var crisis_faults: Array = []
var demand_log: Array = []
var power_zero_streak := 0
var rally_lock := 0

var catalog: Catalog
var rng := RandomNumberGenerator.new()
var net_rng := RandomNumberGenerator.new()
var story_rng := RandomNumberGenerator.new()
var bal := {}


func setup(cat: Catalog, run_seed: int, weeks: int) -> void:
	catalog = cat
	bal = cat.balance
	seed = run_seed
	max_weeks = weeks
	rng.seed = run_seed
	net_rng.seed = run_seed * 17 + 3
	story_rng.seed = run_seed * 41 + 5
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
		"first_ultimatum": 0,
		"flip_week": 0,
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
	_init_standing()
	laws_on[str(cat.factions[player].law)] = true
	_auto_staff()
	if residents.size() != int(bal.start_pop):
		errors.append("start pop %d" % residents.size())
	if stations.size() != 25:
		errors.append("stations %d" % stations.size())
	if council.size() != 3:
		errors.append("council %d" % council.size())
	if errors.is_empty():
		_check_opening_stores()
		rot_week = rng.randi_range(int(bal.rot_min_week), int(bal.rot_max_week))
		crunch_rng.seed = seed * 1000 + 13
		check_rng.seed = seed * 29 + 11
		_install_check_events()
		_schedule_checks()
		crunch_week = crunch_rng.randi_range(int(bal.crunch_min_week), int(bal.crunch_max_week))
		crunch_kind = crunch_rng.randi_range(0, 2)
		_book_calendar()
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
	_vo_watch()


## Seasons always speak; anything else stays quiet for VO_COOLDOWN weeks after it last spoke.
func _vo_cue(name: String) -> void:
	if vo_cues.has(name):
		return
	var key := "@" + name
	if not name.begins_with("season_") and vo_heard.has(key) and week - int(vo_heard[key]) < VO_COOLDOWN:
		return
	vo_heard[key] = week
	vo_cues.append(name)


## Raises a cue when a watched state turns on. The first look only records where things stand, and each state
## needs to clear by a margin before it can fire again, so a value hovering at the line does not repeat.
func _vo_watch() -> void:
	var sick := 0
	for person in residents:
		if int(person.get("sick", 0)) > 0:
			sick += 1
	var food_low := bool(vo_heard.get("~food_critical", false))
	var cheerful := bool(vo_heard.get("~morale_high", false))
	var now := {
		"food_critical": food_buffer_weeks() < (2.0 if food_low else 1.0),
		"power_restored": power_zero_streak == 0 and not gen_down,
		"disease_contained": sick == 0,
		"morale_high": hope >= (65 if cheerful else 75),
	}
	for name in now:
		var key := "~" + str(name)
		var was = vo_heard.get(key, null)
		vo_heard[key] = now[name]
		if was != null and not bool(was) and bool(now[name]):
			_vo_cue(str(name))
	var pop := residents.size()
	var last := int(vo_heard.get("~pop", pop))
	vo_heard["~pop"] = pop
	if pop > last:
		_vo_cue("resident_joined")


func apply(action: Dictionary) -> bool:
	if over != "":
		return false
	var kind := str(action.get("kind", ""))
	var entry := _journal_context(kind, action)
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
		"switch":
			ok = _apply_switch(str(action.get("room", "")), bool(action.get("on", true)))
		"staff":
			_auto_staff()
			decisions += 1
			_log("STAFF " + _staff_line())
			ok = true
		"medkits":
			ok = use_medkits()
		"law":
			ok = _apply_law(str(action.get("law", "")))
		"pump":
			ok = _apply_pump()
		"quarantine":
			ok = _apply_quarantine()
		"burn":
			ok = _apply_burn()
		"rally":
			ok = _apply_rally()
		"repeal":
			ok = _apply_repeal(str(action.get("law", "")))
		"power":
			ok = _move_power(str(action.get("room", "")), bool(action.get("up", false)))
		"order":
			ok = _apply_order(action)
		"audience":
			ok = _apply_help() if bool(action.get("help", false)) else _apply_audience(bool(action.get("accept", false)))
		_:
			ok = false
	if ok and not entry.is_empty():
		_journal(kind, entry)
	return ok


## What the journal keeps about an action, read before the action changes state. Empty means not journaled.
func _journal_context(kind: String, action: Dictionary) -> Dictionary:
	match kind:
		"event":
			return {"event_id": str(action.get("event_id", "")), "choice_id": str(action.get("choice_id", ""))}
		"build":
			return {"type": str(action.get("type", ""))}
		"dig":
			return {"level": int(action.get("level", -1)), "cell": int(action.get("cell", -1))}
		"upgrade", "demolish":
			var room = _room(str(action.get("room", "")))
			if room != null:
				return {"type": str(room.type)}
			return {}
		"law", "repeal":
			return {"law": str(action.get("law", ""))}
		"order":
			return {"order": str(action.get("order", "")), "station": str(action.get("station", action.get("dest", "")))}
		"pump", "quarantine", "burn", "rally":
			return {"done": true}
	return {}


## Rows hold ids only; the UI words them. Oldest rows drop off past JOURNAL_MAX so saves stay small.
func _journal(kind: String, data: Dictionary) -> void:
	var row := data.duplicate(true)
	row["kind"] = kind
	row["week"] = week
	journal.append(row)
	if journal.size() > JOURNAL_MAX:
		journal = journal.slice(journal.size() - JOURNAL_MAX)


## Notes a player action that happens outside apply(), such as a radio item heard.
func journal_note(kind: String, data: Dictionary) -> void:
	_journal(kind, data)


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
		"deals_w10": int(stats.get("deals_w10", 0)),
		"stations_w25": int(stats.get("stations_w25", owned_count() if week >= 25 else 0)),
		"influence": int(stock.influence),
		"first_ultimatum": int(stats.get("first_ultimatum", 0)),
		"flip_week": int(stats.get("flip_week", 0)),
		"flip_name": str(stats.get("flip_name", "")),
		"flip_from": str(stats.get("flip_from", "")),
		"flip_to": str(stats.get("flip_to", "")),
		"shortage_causes": stats.get("shortage_causes", []),
		"hope_end": hope,
		"hope_avg": _hope_avg(),
		"hope_sources": hope_totals.duplicate(),
		"dis_sources": dis_totals.duplicate(),
		"hope_history": hope_history.duplicate(),
		"crunch_drops": stats.get("crunch_drops", []),
		"crunch_week": crunch_week,
		"crunch_kind": crunch_kind,
		"power_zero_max": int(stats.get("power_zero_max", 0)),
		"unaffordable_dawn": int(stats.get("unaffordable_dawn", 0)),
		"events_by_15": _events_by(15),
		"check_white_rolls": int(stats.get("check_white_rolls", 0)),
		"check_white_success": int(stats.get("check_white_success", 0)),
		"check_red_rolls": int(stats.get("check_red_rolls", 0)),
		"check_red_success": int(stats.get("check_red_success", 0)),
		"check_retried": int(stats.get("check_retried", 0)),
		"check_retry_passed": int(stats.get("check_retry_passed", 0)),
	}


func _events_by(limit: int) -> int:
	var n := 0
	for id in events_seen:
		if int(events_seen[id]) <= limit:
			n += 1
	return n


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


func nearest_neutral() -> String:
	var best := ""
	var best_hops := 999
	for sid in stations:
		var st: Dictionary = stations[sid]
		if str(st.owner) != "neutral" or bool(st.get("hidden", false)):
			continue
		if not borders_player(str(sid)):
			continue
		var hops := _hops(str(sid), capital_id)
		if hops < best_hops:
			best_hops = hops
			best = str(sid)
	return best


func trade_pitch(sid: String) -> String:
	if not stations.has(sid):
		return ""
	var st: Dictionary = stations[sid]
	var need := _lowest_need(st)
	var who := str(st.community) if Copy.ru() else str(st.name)
	var lack := Copy.t(need) if Copy.ru() else need
	if Copy.ru():
		return "%s нуждается: %s. Сделка стоит 4 влияния и открывает тоннель." % [who, lack]
	return "%s is short of %s. A trade deal costs 4 influence and opens the tunnel." % [who, lack]


func deal_count() -> int:
	var total := 0
	for sid in stations:
		total += int(stations[sid].get("deals", 0))
	return total


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
		return Copy.t("There is no flood to pump.")
	return shortage_text({"materials": int(bal.pump_materials), "power": int(bal.pump_power)})


func enact_reason(law_id: String) -> String:
	if _law_on(law_id):
		return Copy.t("Already in force.")
	if not catalog.laws.has(law_id):
		return Copy.t("No such law.")
	if not _room_ready("meeting_hall"):
		return Copy.t("Needs a staffed meeting hall. The hall has no one in it.")
	if law_lock > 0:
		return Copy.t("The hall is waiting. Next law in %s.") % Words.count(law_lock, "week")
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
		needs.append(Copy.stock(want, str(key)))
		short.append(Copy.stock(have, str(key)))
	if needs.is_empty():
		for key in ARTIFACTS:
			var have := int(artifacts.get(key, 0))
			if int(need.get(key, 0)) > have:
				return Copy.t("Needs %s %d, you have %d") % [Copy.t(str(ARTIFACT_TEXT[key])), int(need[key]), have]
		return ""
	var line := Copy.t("Needs %s. You have %s.") % [", ".join(needs), ", ".join(short)]
	var where: PackedStringArray = []
	for key in order:
		if not need.has(key):
			continue
		if int(stock.get(key, 0)) >= int(need[key]):
			continue
		var hint := Brief.where_for(self, str(key))
		if hint != "":
			where.append(hint)
	if not where.is_empty():
		line += " " + " ".join(where)
	return line


func resource_outlook(key: String) -> Dictionary:
	var have := int(stock.get(key, 0))
	var made := output_of(key)
	if key == "power" and _law_on("engineers_charter"):
		made += int(catalog.laws.engineers_charter.get("power", 0))
	var use := _weekly_draw(key)
	var nxt := have + made - use
	var hit: bool = have <= 0 or nxt <= 0
	var dawn := maxi(0, nxt)
	var text := Copy.t("%s %d on hand. The yard makes %d and uses %d. By dawn: %d.") % [Copy.res(key), have, made, use, dawn]
	if nxt < 0:
		text += Copy.t(" Short %d.") % -nxt
	var who := _consumer_line(key)
	if who != "":
		text += " " + who
	if key == "power" and nxt < 0:
		var names := _uncovered_power_names()
		if not names.is_empty():
			text += Copy.t(" These rooms will not be covered: %s.") % ", ".join(names)
	return {"text": text, "hit": hit, "next": nxt}


func dawn_projection() -> Dictionary:
	var out := {}
	for key in ["air", "food", "power", "materials", "tokens", "influence"]:
		var row: Dictionary = resource_outlook(key)
		out[key] = maxi(0, int(row.next))
	var hope_d := int(bal.get("hope_drift", 0))
	var dis_d := 0
	if quarantine:
		hope_d -= 1
	if int(resource_outlook("food").next) < 0 or int(resource_outlook("air").next) < 0:
		hope_d += int(bal.get("shortage_hope", 0))
	if int(resource_outlook("power").next) < 0:
		hope_d += int(bal.get("power_shortage_hope", 0))
		dis_d += int(bal.get("power_shortage_discontent", 0))
	if not active_season.is_empty():
		var season_id := str(active_season.id)
		var dis_table = bal.get("season_discontent", {})
		if dis_table is Dictionary and dis_table.has(season_id):
			dis_d += int(dis_table[season_id])
		var hope_table = bal.get("season_hope", {})
		if hope_table is Dictionary and hope_table.has(season_id):
			hope_d += int(hope_table[season_id])
	if residents.size() > housing():
		dis_d += int(bal.get("overcrowd_discontent", 0))
	for law_id in laws_on:
		var defin: Dictionary = catalog.laws[law_id]
		if defin.has("hope_week"):
			hope_d += int(defin.hope_week)
		if defin.has("discontent_week"):
			dis_d += int(defin.discontent_week)
		if str(law_id) == "sermons" and _any_trait("Devout"):
			hope_d += int(defin.get("devout_hope", 0))
	var every := int(bal.get("agent_every", 0))
	if every > 0 and week % every == 0:
		var hostile := false
		for fid in opinions.keys():
			if int(opinions[fid]) < 0:
				hostile = true
		if hostile:
			dis_d += int(bal.get("agent_discontent", 0))
	out.hope = clampi(hope + hope_d, 0, 100)
	out.discontent = clampi(discontent + dis_d, 0, 100)
	return out


func rooms_losing_power() -> Array:
	return _brownout_ids()


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
	_resolve_queued()
	orders_left = council.size()
	seat_used = {}
	pumped = false
	quarantine = false
	week_event_ids = {}
	_season_clock()
	_queue_crunch()
	_roll_events()
	_offer_forced_event()
	_release_white_checks()
	_offer_checks()
	_offer_story_event()
	_offer_triggered()
	_note_dawn_afford()
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
		var ultimatum := "ULTIMATUM %s wants %d tokens, %d turns left" % [_fname(str(d.faction)), int(d.amount), int(d.deadline)]
		if Copy.ru():
			ultimatum = "ULTIMATUM %s хочет %s, осталось %s." % [Copy.t(_fname(str(d.faction))), Copy.stock(int(d.amount), "tokens"), Words.count(int(d.deadline), "week")]
		_log(ultimatum, true)
	_audience_dawn()


func _rival_phase() -> void:
	var keep: Array = []
	for d in demands:
		if bool(d.paid):
			continue
		d.deadline = int(d.deadline) - 1
		if int(d.deadline) <= 0:
			_add_opinion(str(d.faction), -15)
			stock.food = maxi(0, int(stock.food) - 10)
			var taken := "ULTIMATUM %s takes its price. Food -10." % _fname(str(d.faction))
			if Copy.ru():
				taken = "ULTIMATUM %s забирает цену. Еда −10." % Copy.t(_fname(str(d.faction)))
			_log(taken, true)
			_journal("ultimatum", {"faction": str(d.faction)})
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
	_mark_brownout()
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
	if vent_cut > 0:
		stock.air = maxi(0, int(stock.air) - 2)
		vent_cut = maxi(0, vent_cut - 1)
	for room in rooms:
		if int(room.get("mold", 0)) > 0:
			room.mold = int(room.mold) - 1
		if int(room.get("disabled", 0)) > 0:
			room.disabled = int(room.disabled) - 1
	if _law_on("engineers_charter"):
		stock.power = int(stock.power) + int(catalog.laws.engineers_charter.get("power", 0))
	_apply_weekly_laws()
	if trade_on:
		stock.tokens = int(stock.tokens) + int(bal.trade_tokens_week)
	_deliver_outposts()
	var flood_loss := _spoil_flood_stores()
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
		_note("SHORT food %d air %d" % [food_short, air_short], "SHORT еды не хватило на %d, воздуха на %d." % [food_short, air_short])
		if deaths > 0:
			_kill(deaths, "Supplies ran out")
	var power_short := maxi(0, need_power - int(stock.power))
	stock.power = maxi(0, int(stock.power) - need_power)
	if power_short > 0:
		_add_hope(int(bal.power_shortage_hope), "power")
		_add_discontent(int(bal.power_shortage_discontent), "power")
		week_short = true
		_note("SHORT power %d" % power_short, "SHORT энергии не хватило на %d." % power_short)
	for room in rooms:
		room.browned = false
	if int(stock.power) <= 0:
		power_zero_streak += 1
	else:
		power_zero_streak = 0
	stats["power_zero_max"] = maxi(int(stats.get("power_zero_max", 0)), power_zero_streak)
	if week_short:
		stats.shortage_weeks = int(stats.shortage_weeks) + 1
		stats.shortages = int(stats.shortage_weeks)
		if int(stats.first_shortage) == 0:
			stats.first_shortage = week
		var cause := "growth"
		if food_short > 0 and flood_loss > 0:
			cause = "flood"
		elif food_short <= 0 and air_short > 0:
			cause = "air"
		elif food_short <= 0 and power_short > 0:
			cause = "power"
		var causes: Array = stats.get("shortage_causes", [])
		causes.append({"week": week, "cause": cause})
		stats["shortage_causes"] = causes
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
	_synod_preach()
	_claim_swayed()
	_tick_holdings()
	_drift_opinion()
	for fid in ambition:
		if str(fid) == "synod":
			continue
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
		stats.deals_w10 = deal_count()
	if week == 25:
		stats.stations_w25 = owned_count()
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
		if room.offline or _flood_silences(room) or int(room.get("disabled", 0)) > 0:
			continue
		if bool(room.get("browned", false)) and str(room.type) != "generator":
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
			if int(room.get("mold", 0)) > 0 and str(key) == "food":
				n = 0
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


func _mark_brownout() -> void:
	var dark := _brownout_ids()
	var dark_set := {}
	for uid in dark:
		dark_set[str(uid)] = true
	for room in rooms:
		var uid := str(room.uid)
		var was_dark := bool(room.get("browned", false))
		room.browned = dark_set.has(uid)
		if room.browned:
			_log("BROWN %s is dark" % str(catalog.rooms[room.type].name), true)
			if not was_dark:
				_journal("dark", {"type": str(room.type)})


func _brownout_ids() -> Array:
	var dark: Array = []
	var pool := int(stock.power) + _generator_yield()
	var mult := 2 if (_season_is("cold") or crunch_power) else 1
	for room in rooms:
		if str(room.type) != "generator" or bool(room.offline):
			continue
		pool -= int(catalog.rooms.generator.get("power", 0)) * mult
	if pool < 0:
		pool = 0
	for uid in power_order:
		var room = _room(str(uid))
		if room == null:
			continue
		if str(room.type) == "generator" or bool(room.offline) or _flood_silences(room):
			continue
		var draw := int(catalog.rooms[str(room.type)].get("power", 0)) * mult
		if draw <= 0:
			continue
		if pool >= draw:
			pool -= draw
		else:
			dark.append(str(room.uid))
	return dark


func _generator_yield() -> int:
	var saved: Array = []
	for room in rooms:
		saved.append(bool(room.get("browned", false)))
		if str(room.type) != "generator":
			room.browned = true
	var n := int(_tally(belt_down, workshop_down, gen_down).get("power", 0))
	for i in rooms.size():
		rooms[i].browned = saved[i]
	var extra := 0
	if _law_on("engineers_charter"):
		extra = int(catalog.laws.engineers_charter.get("power", 0))
	return n + extra


func forecasts() -> Array:
	var rows: Array = []
	var horizon := int(bal.get("forecast_weeks", 2))
	for key in ["power", "food", "air", "materials"]:
		var left := _weeks_until_empty(key)
		var thin: bool = key == "food" and _food_thin()
		if left > horizon and not thin:
			continue
		var hint := _supply_hint(_supply_type(key))
		var name := Copy.res(key)
		var when := "is gone" if left <= 0 else "runs out in %s" % _week_span(left)
		var shown := left
		if thin:
			var meals := maxi(0, int(floor(food_buffer_weeks())))
			when = "is down to %s of meals" % Words.count(meals, "week")
			if left > horizon:
				shown = horizon
		if (key == "food" or key == "air") and _weeks_until_empty("power") <= horizon:
			hint = _supply_hint("generator")
		var stock_text := "%s %s. %s" % [name, when, str(hint.text)]
		if Copy.ru():
			stock_text = "%s %s" % [_ru_stock_when(key, left, thin, maxi(0, int(floor(food_buffer_weeks()))) if thin else left), str(hint.text)]
		rows.append({
			"key": key,
			"weeks": shown,
			"text": stock_text,
			"hint": str(hint.hint),
			"level": int(hint.get("level", -1)),
			"cell": int(hint.get("cell", -1)),
		})
	for meter in ["discontent", "hope"]:
		var left := _weeks_until_break(meter)
		if meter == "hope":
			left = _hope_warn_weeks()
		if left > horizon and not (meter == "hope" and hope <= 50):
			continue
		if meter == "hope" and hope <= 50 and left > 4:
			left = 4
		var pushes := _coming_pushes(meter)
		var fixes := _best_fixes(meter, 1)
		var fix: Dictionary = fixes[0] if not fixes.is_empty() else {}
		var name := "Discontent" if meter == "discontent" else "Hope"
		var when := "is down to %d" % hope if meter == "hope" else ("is at the edge" if left <= 0 else "hits 100 in %s" % _week_span(left))
		var meter_text := "%s %s. %s %s" % [name, when, _push_line(pushes), str(fix.get("text", ""))]
		if Copy.ru():
			meter_text = _ru_meter_when(meter, left, _push_line(pushes), str(fix.get("text", "")))
		rows.append({
			"key": meter,
			"weeks": left,
			"text": meter_text,
			"hint": str(fix.get("hint", "")),
			"level": int(fix.get("level", -1)),
			"cell": int(fix.get("cell", -1)),
		})
	if can_quarantine():
		rows.append({
			"key": "power",
			"weeks": 0,
			"text": Copy.t("The cough pulls crews off every room. Quarantine ends the Cough."),
			"hint": "quarantine",
			"level": -1,
			"cell": -1,
		})
	var flood_text := flood_line()
	if flood_text != "":
		var eta := _flood_eta()
		rows.append({
			"key": "flood",
			"weeks": eta,
			"text": flood_text,
			"hint": "pump" if can_pump() else "",
			"level": -1,
			"cell": -1,
		})
	rows.sort_custom(func(a, b): return int(a.weeks) < int(b.weeks))
	if residents.size() > housing():
		var beds := _supply_hint("quarters")
		rows.append({
			"key": "overcrowd",
			"weeks": 0,
			"text": crowd_line(),
			"hint": str(beds.hint),
			"level": int(beds.get("level", -1)),
			"cell": int(beds.get("cell", -1)),
		})
	return rows


func crowd_line() -> String:
	var n := int(bal.get("overcrowd_discontent", 2))
	if Copy.ru():
		return "Теснота +%d/нед" % n
	return "Overcrowding +%d/wk" % n


func flood_line() -> String:
	if flood_guard:
		return ""
	var eta := _flood_eta()
	if eta > int(bal.get("season_warning", 2)):
		return ""
	var spoil := Copy.t("Food on the lower level will spoil.")
	if eta <= 0:
		return spoil
	if Copy.ru():
		return "Паводок через %s. %s" % [_week_span(eta), spoil]
	return "Flood in %s. %s" % [_week_span(eta), spoil]


func _flood_eta() -> int:
	if _season_is("flood"):
		return 0
	for season in bal.seasons:
		if str(season.id) != "flood":
			continue
		var left := int(season.week) - week
		if left > 0:
			return left
	return 99


func _ru_stock_when(key: String, left: int, thin: bool, meals: int) -> String:
	if key == "food" and thin:
		return "Еды осталось на %s." % Words.count(meals, "week")
	if left <= 0:
		match key:
			"food":
				return "Еда кончилась."
			"air":
				return "Воздух кончился."
			"power":
				return "Энергия кончилась."
			_:
				return "Материалы кончились."
	var span := _week_span(left)
	match key:
		"food":
			return "Еда кончится через %s." % span
		"air":
			return "Воздух кончится через %s." % span
		"power":
			return "Энергия кончится через %s." % span
		_:
			return "Материалы кончатся через %s." % span


func _ru_meter_when(meter: String, left: int, push: String, fix: String) -> String:
	var bit := ""
	if meter == "hope":
		bit = "Надежда упала до %d." % hope
	elif left <= 0:
		bit = "Недовольство на пределе."
	else:
		bit = "Недовольство дойдёт до 100 через %s." % _week_span(left)
	return "%s %s %s" % [bit, push, fix]


func revolt_warning() -> Dictionary:
	if discontent < int(bal.get("revolt_warn", 70)):
		return {}
	var gain := _meter_gain("discontent")
	var left := 99
	if discontent >= 100:
		left = 0
	elif gain > 0:
		left = int(ceil(float(100 - discontent) / float(gain)))
	else:
		left = maxi(1, 100 - discontent)
	var fixes := _best_fixes("discontent", 2)
	var bits: PackedStringArray = [Copy.t("Revolt in about %s.") % _week_span(left)]
	for fix in fixes:
		bits.append(str(fix.text))
	var first: Dictionary = fixes[0] if not fixes.is_empty() else {}
	return {
		"text": " ".join(bits),
		"weeks": left,
		"fixes": fixes,
		"hint": str(first.get("hint", "")),
		"level": int(first.get("level", -1)),
		"cell": int(first.get("cell", -1)),
	}


func close_caption() -> String:
	var choice := _free_choice(front_event())
	if choice.is_empty():
		return Copy.t("Close")
	return Copy.t("Close: %s") % Copy.t(line_of(choice, "label"))


func _food_thin() -> bool:
	if food_buffer_weeks() < 2.5:
		return true
	return _weeks_until_empty("food") <= int(bal.get("forecast_weeks", 2))


func _hope_warn_weeks() -> int:
	var mark := 20
	var gain := _meter_gain("hope")
	if hope <= mark:
		return 0
	if gain <= 0:
		return 99
	return int(ceil(float(hope - mark) / float(gain)))


func _weeks_until_break(meter: String) -> int:
	var gain := _meter_gain(meter)
	if gain <= 0:
		return 99
	if meter == "discontent":
		if discontent >= 100:
			return 0
		return int(ceil(float(100 - discontent) / float(gain)))
	if hope <= 0:
		return 0
	return int(ceil(float(hope) / float(gain)))


func _meter_gain(meter: String) -> int:
	var total := 0
	for push in _coming_pushes(meter):
		total += int(push.amount)
	return total


func _coming_pushes(meter: String) -> Array:
	var rows: Array = []
	if meter == "hope":
		var slide := -int(bal.hope_drift)
		if slide > 0:
			rows.append({"name": "the weekly slide", "amount": slide})
		if _food_thin():
			rows.append({"name": "a shortage", "amount": 4})
		for law_id in laws_on:
			var defin: Dictionary = catalog.laws[law_id]
			var hit := -int(defin.get("hope_week", 0))
			if hit > 0:
				rows.append({"name": str(defin.name), "amount": hit})
	else:
		if not active_season.is_empty():
			var season_id := str(active_season.id)
			var amount := int(bal.season_discontent[season_id])
			if amount > 0:
				rows.append({"name": "the %s" % season_id, "amount": amount})
		if residents.size() > housing():
			rows.append({"name": "the crowd", "amount": int(bal.overcrowd_discontent)})
		for law_id in laws_on:
			var defin: Dictionary = catalog.laws[law_id]
			var hit := int(defin.get("discontent_week", 0))
			if hit > 0:
				rows.append({"name": str(defin.name), "amount": hit})
	rows.sort_custom(func(a, b): return int(a.amount) > int(b.amount))
	return rows


func _push_line(pushes: Array) -> String:
	if pushes.is_empty():
		return ""
	var line := ""
	if pushes.size() == 1:
		line = "%s is pushing it." % str(pushes[0].name)
	else:
		line = "%s and %s are pushing it." % [str(pushes[0].name), str(pushes[1].name)]
	line = line.substr(0, 1).to_upper() + line.substr(1)
	if not Copy.ru():
		return line
	var first := Copy.t(str(pushes[0].name))
	if pushes.size() == 1:
		return Copy.t("%s is pushing it.") % first
	return Copy.t("%s and %s are pushing it.") % [first, Copy.t(str(pushes[1].name))]


func _best_fixes(meter: String, limit: int) -> Array:
	var out: Array = []
	if meter == "discontent":
		if _season_is("cough") and can_quarantine():
			out.append({"hint": "quarantine", "text": Copy.t("Quarantine ends the Cough."), "level": -1, "cell": -1})
		_add_repeal(out, "conscription", Copy.t("Repeal Conscription."))
		if residents.size() > housing():
			_add_room_fix(out, "quarters", Copy.t("Build Quarters so the crowd has beds."))
		_add_rally(out)
	else:
		if _food_thin():
			if _weeks_until_empty("power") <= int(bal.get("forecast_weeks", 2)):
				_add_room_fix(out, "generator", Copy.t("Build a generator so the farms have power."))
			else:
				_add_room_fix(out, "hydroponics", Copy.t("Build Hydroponics so the shortage stops."))
		_add_repeal(out, "curfew", Copy.t("Repeal Curfew."))
		_add_repeal(out, "rationing", Copy.t("Repeal Rationing."))
		_add_law(out, "sermons", Copy.t("Pass Sermons in the meeting hall."))
		if out.is_empty():
			_add_hall_step(out)
	if out.size() > limit:
		out.resize(limit)
	return out


func _add_law(out: Array, law_id: String, text: String) -> void:
	if _law_on(law_id) or not can_enact(law_id):
		return
	out.append({"hint": "law:%s" % law_id, "text": text, "level": -1, "cell": -1})


func _add_repeal(out: Array, law_id: String, text: String) -> void:
	if repeal_reason(law_id) != "":
		return
	out.append({"hint": "repeal:%s" % law_id, "text": text, "level": -1, "cell": -1})


func _add_rally(out: Array) -> void:
	if rally_reason() == "":
		out.append({"hint": "rally", "text": Copy.t("Hold a rally in the meeting hall."), "level": -1, "cell": -1})
		return
	_add_hall_step(out)


func _add_hall_step(out: Array) -> void:
	if room_count("meeting_hall") == 0:
		_add_room_fix(out, "meeting_hall", Copy.t("Build a meeting hall on a dug cell."))
		return
	if not _room_ready("meeting_hall"):
		out.append({"hint": "staff:meeting_hall", "text": Copy.t("Staff the meeting hall."), "level": -1, "cell": -1})


func _add_room_fix(out: Array, type: String, fallback: String) -> void:
	var hint := _supply_hint(type)
	var text := str(hint.text)
	if text == "":
		text = fallback
	out.append({
		"hint": str(hint.hint),
		"text": text,
		"level": int(hint.get("level", -1)),
		"cell": int(hint.get("cell", -1)),
	})


func rally_reason() -> String:
	if rally_lock > 0:
		return Copy.t("The hall held a rally recently. Next one in %s.") % Words.count(rally_lock, "week")
	if not _room_ready("meeting_hall"):
		if room_count("meeting_hall") == 0:
			return Copy.t("Needs a meeting hall.")
		return Copy.t("Needs a staffed meeting hall. The hall has no one in it.")
	return ""


func repeal_reason(law_id: String) -> String:
	if not _law_on(law_id):
		return Copy.t("Not in force.")
	if not bool(catalog.laws[law_id].get("repealable", false)):
		return Copy.t("It cannot be repealed.")
	if not _room_ready("meeting_hall"):
		return Copy.t("Needs a staffed meeting hall. The hall has no one in it.")
	if law_lock > 0:
		return Copy.t("The hall is waiting. Next law in %s.") % Words.count(law_lock, "week")
	return ""


func _weeks_until_empty(key: String) -> int:
	var have := int(stock.get(key, 0))
	if have <= 0:
		return 0
	var make := 0
	var use := 0
	if key == "power":
		make = _generator_yield()
		use = _full_power_draw()
	elif key == "food":
		make = output_of("food")
		use = food_need()
	elif key == "air":
		make = output_of("air")
		use = air_need()
	else:
		make = output_of("materials")
		use = 0
	var net := make - use
	if net >= 0:
		return 99
	return int(ceil(float(have) / float(-net)))


func _full_power_draw() -> int:
	var n := 0
	for room in rooms:
		if room.offline:
			continue
		n += int(catalog.rooms[room.type].get("power", 0))
	if _season_is("cold") or crunch_power:
		n *= 2
	return n


func _supply_type(key: String) -> String:
	match key:
		"power":
			return "generator"
		"food":
			return "hydroponics"
		"air":
			return "air_filter"
		_:
			return "workshop"


func _week_span(n: int) -> String:
	return Words.count(n, "week")


func _supply_hint(type: String) -> Dictionary:
	var defin: Dictionary = catalog.rooms[type]
	var cost := int(defin.materials)
	var turns := maxi(1, int(defin.build_turns))
	if _type_understaffed(type):
		return {"hint": "staff:%s" % type, "text": Copy.t("Staff the %s.") % _line_name(str(defin.name), true), "level": -1, "cell": -1}
	var spot := _first_build_cell()
	if spot.is_empty():
		var dig: Dictionary = _pick_dig_cell(true)
		var dig_line := Copy.t("Dig a cell, then build a %s (%s, %s).") % [_line_name(str(defin.name), true), Words.count(cost, "material"), _week_span(turns)]
		if type != "generator":
			dig_line = Copy.t("Dig a cell, then build %s (%s, %s).") % [_line_name(str(defin.name), false), Words.count(cost, "material"), _week_span(turns)]
		return {"hint": "dig", "text": dig_line, "level": int(dig.get("level", -1)), "cell": int(dig.get("cell", -1))}
	var line := Copy.t("Build a %s on a dug cell (%s, %s).") % [_line_name(str(defin.name), true), Words.count(cost, "material"), _week_span(turns)]
	if type != "generator":
		line = Copy.t("Build %s on a dug cell (%s, %s).") % [_line_name(str(defin.name), false), Words.count(cost, "material"), _week_span(turns)]
	return {"hint": "build:%s" % type, "text": line, "level": int(spot.level), "cell": int(spot.cell)}


func _type_understaffed(type: String) -> bool:
	var need := int(catalog.rooms[type].get("staff_min", 0))
	if need <= 0:
		return false
	for room in rooms:
		if str(room.type) != type or bool(room.offline):
			continue
		if int(room.staff.size()) < need:
			return true
	return false


func burn_preview() -> Dictionary:
	var cost := int(bal.burn_materials)
	var info := {
		"ok": int(stock.materials) >= cost,
		"materials": cost,
		"power": int(bal.burn_power),
		"hope": int(bal.burn_hope),
		"reason": "",
	}
	if not bool(info.ok):
		info.reason = shortage_text({"materials": cost})
	return info


func _apply_burn() -> bool:
	var info := burn_preview()
	if not bool(info.ok):
		return false
	stock.materials = int(stock.materials) - int(info.materials)
	stock.power = int(stock.power) + int(info.power)
	_add_hope(int(info.hope), "burn")
	decisions += 1
	_log("BURN %d materials into %d power" % [int(info.materials), int(info.power)])
	return true


func _apply_rally() -> bool:
	if rally_reason() != "":
		return false
	_add_discontent(int(bal.rally_discontent), "rally")
	_add_hope(int(bal.rally_hope), "rally")
	rally_lock = int(bal.rally_cooldown)
	decisions += 1
	_log("RALLY in the meeting hall", true)
	return true


func _apply_repeal(law_id: String) -> bool:
	if repeal_reason(law_id) != "":
		return false
	laws_on.erase(law_id)
	law_lock = int(bal.law_cooldown)
	decisions += 1
	_log("REPEAL %s" % catalog.laws[law_id].name, true)
	return true


func _move_power(uid: String, up: bool) -> bool:
	var i := power_order.find(uid)
	if i < 0:
		return false
	var j := i - 1 if up else i + 1
	if j < 0 or j >= power_order.size():
		return false
	var swap = power_order[i]
	power_order[i] = power_order[j]
	power_order[j] = swap
	decisions += 1
	return true


func _insert_power(uid: String, type: String) -> void:
	var rank := _power_rank(type)
	var at := power_order.size()
	for i in power_order.size():
		var other = _room(str(power_order[i]))
		if other == null:
			continue
		if _power_rank(str(other.type)) > rank:
			at = i
			break
	power_order.insert(at, uid)


func _power_rank(type: String) -> int:
	match type:
		"air_filter":
			return 0
		"hydroponics":
			return 1
		"quarters":
			return 2
		"workshop":
			return 3
		_:
			return 9


func _power_need() -> int:
	var n := 0
	for room in rooms:
		if room.offline or bool(room.get("browned", false)):
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
		return Copy.t("Meals for %s take %d food.") % [Words.count(residents.size(), "person", "people"), food_need()]
	if key == "air":
		return Copy.t("Breathing takes %d air.") % air_need()
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
			bits.append("%s %d" % [Copy.t(str(draws[i].name)), int(draws[i].draw)])
		if bits.is_empty():
			return ""
		return Copy.t("Biggest draws: %s.") % ", ".join(bits)
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
		names.append(Copy.t(str(catalog.rooms[room.type].name)))
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
		bits.append(Copy.t("%s is at %d, and this room is part of what makes it.") % [Copy.res(str(key)), int(stock.get(key, 0))])
	return " ".join(bits)


func _room_store(room: Dictionary, key: String) -> int:
	var store = catalog.rooms[room.type].get("store", {})
	if store is Dictionary:
		return int(store.get(key, 0))
	return 0


func storage_cap(key: String) -> int:
	var n := 0
	for room in rooms:
		if room.offline or _flood_silences(room) or int(room.get("disabled", 0)) > 0:
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


func _spoil_flood_stores() -> int:
	if not _season_is("flood"):
		return 0
	if pumped or flood_guard:
		return 0
	var lvl := _lowest_open_level()
	var stored := 0
	for room in rooms:
		if int(room.level) != lvl:
			continue
		stored += _room_store(room, "food")
	var loss := mini(int(stock.food), stored)
	if loss <= 0:
		return 0
	stock.food = int(stock.food) - loss
	_log("FLOOD spoils %d food on the lowest level" % loss, true)
	return loss


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
	var need := food_need()
	var surplus := int(stock.food) - need
	if surplus <= 0:
		return
	var loss := mini(surplus, maxi(1, int(round(float(surplus) * 0.5))))
	stock.food = int(stock.food) - loss
	_note("ROT %d food turns in the stores" % loss, "ROT В кладовых испортилось %d еды." % loss)


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
	_note("AGENT a rival rumor moves through the yard", "AGENT По двору прошёл слух соперника.")


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
	if rally_lock > 0:
		rally_lock -= 1


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
		return {"ok": false, "reason": Copy.t("No such cell."), "turns": 0, "workers": 0, "materials": int(bal.dig_materials)}
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
		info.reason = Copy.t("Already open.")
		return info
	if not _beside_dug(spot):
		info.reason = Copy.t("Solid rock. Dig from a cell that touches an open one.")
		return info
	if not dig.is_empty():
		info.reason = Copy.t("A crew is already digging.")
		return info
	var reasons: PackedStringArray = []
	if int(stock.materials) < int(bal.dig_materials):
		reasons.append(Copy.t("Needs %s, the yard has %s.") % [Words.count(int(bal.dig_materials), "material"), Words.count(int(stock.materials), "material")])
	if _free_count() < int(cost.workers):
		reasons.append(Copy.t("Needs %s free. %s are free.") % [Words.count(int(cost.workers), "person", "people"), Words.count(_free_count(), "person", "people")])
	info.reason = " ".join(reasons)
	info.ok = reasons.is_empty()
	return info


func build_preview(type: String, level: int, cell: int) -> Dictionary:
	var defin: Dictionary = catalog.rooms.get(type, {})
	var info := {"ok": false, "reason": "", "materials": 0, "turns": 0, "workers": int(bal.build_workers), "power": 0, "name": type}
	if defin.is_empty() or not bool(defin.get("buildable", false)):
		info.reason = Copy.t("That cannot be built.")
		return info
	info.materials = int(defin.materials)
	info.turns = int(defin.build_turns)
	info.power = int(defin.get("power", 0))
	info.name = str(defin.name)
	var key := _ck(level, cell)
	if not cells.has(key) or not _cell_buildable(cells[key]):
		info.reason = Copy.t("That cell is not an open, empty floor.")
		return info
	var reasons: PackedStringArray = []
	if not build.is_empty():
		reasons.append(Copy.t("A room is already going up."))
	if int(stock.materials) < int(defin.materials):
		reasons.append(Copy.t("Needs %s, the yard has %s.") % [Words.count(int(defin.materials), "material"), Words.count(int(stock.materials), "material")])
	if _free_count() < int(bal.build_workers):
		reasons.append(Copy.t("Needs %s free. %s are free.") % [Words.count(int(bal.build_workers), "person", "people"), Words.count(_free_count(), "person", "people")])
	info.reason = " ".join(reasons)
	info.ok = reasons.is_empty()
	return info


func upgrade_preview(uid: String) -> Dictionary:
	var room = _room(uid)
	var info := {"ok": false, "reason": "", "materials": 0, "name": ""}
	if room == null:
		info.reason = Copy.t("No such room.")
		return info
	var defin: Dictionary = catalog.rooms[room.type]
	var steps: Array = defin.get("upgrades", [])
	info.materials = int(defin.get("upgrade_materials", 0))
	if int(room.upgrade) >= steps.size():
		info.reason = Copy.t("Nothing left to upgrade.")
		return info
	info.name = str(steps[int(room.upgrade)])
	if bool(room.offline):
		info.reason = Copy.t("The room is offline.")
		return info
	if int(stock.materials) < info.materials:
		info.reason = Copy.t("Needs %s, the yard has %s.") % [Words.count(info.materials, "material"), Words.count(int(stock.materials), "material")]
		return info
	info.ok = true
	return info


func demolish_preview(uid: String) -> Dictionary:
	var room = _room(uid)
	var info := {"ok": false, "reason": "", "refund": 0, "name": ""}
	if room == null:
		info.reason = Copy.t("No such room.")
		return info
	var defin: Dictionary = catalog.rooms[room.type]
	info.name = str(defin.name)
	if not bool(defin.get("buildable", false)):
		info.reason = Copy.t("The platform stays.")
		return info
	if not build.is_empty() and int(build.level) == int(room.level) and int(build.cell) == int(room.cell):
		info.reason = Copy.t("A crew is still on this cell.")
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
	var order: Array = []
	for id in power_order:
		if str(id) != uid:
			order.append(id)
	power_order = order
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


func switch_preview(uid: String) -> Dictionary:
	var info := {"can": false, "on": true, "saves": 0, "reason": ""}
	var room = _room(uid)
	if room == null:
		return info
	var draw := int(catalog.rooms[room.type].get("power", 0))
	info.saves = draw
	info.on = not bool(room.get("switched_off", false))
	if str(room.type) == "platform" or draw <= 0:
		return info
	if info.on and bool(room.offline):
		info.reason = Copy.t("The room is offline.")
		return info
	info.can = true
	return info


func _apply_switch(uid: String, on: bool) -> bool:
	var info := switch_preview(uid)
	if not bool(info.can) or bool(info.on) == on:
		return false
	var room = _room(uid)
	if on:
		room.switched_off = false
		room.offline = bool(cells[_ck(int(room.level), int(room.cell))].flooded)
	else:
		for id in room.staff.duplicate():
			_unassign(str(id))
		room.switched_off = true
		room.offline = true
	decisions += 1
	_log("SWITCH %s %s" % [catalog.rooms[room.type].name, "on" if on else "off"])
	return true


func assign_preview(person_id: String, uid: String) -> Dictionary:
	var info := {"ok": false, "reason": ""}
	if not people.has(person_id):
		info.reason = Copy.t("No such resident.")
		return info
	var room = _room(uid)
	if room == null:
		info.reason = Copy.t("No such room.")
		return info
	var person: Dictionary = people[person_id]
	var defin: Dictionary = catalog.rooms[room.type]
	if int(defin.staff_max) <= 0:
		info.reason = Copy.t("No one works this room.")
		return info
	if bool(room.offline):
		info.reason = Copy.t("The room is offline.")
		return info
	if int(person.sick) > 0 or int(person.absent) > 0:
		info.reason = Copy.t("%s cannot work right now.") % Copy.person(str(person.name))
		return info
	if _locked_ids().has(person_id):
		info.reason = Copy.t("%s is on a crew.") % Copy.person(str(person.name))
		return info
	var already := false
	for id in room.staff:
		if str(id) == person_id:
			already = true
	if not already and room.staff.size() >= int(defin.staff_max):
		info.reason = Copy.t("The room is fully staffed.")
		info["full"] = true
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
			"name": Copy.person(str(person.name)),
			"skill": value,
			"traits": Copy.trait_list(person.traits),
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
		rows.append({"id": id, "name": Copy.person(str(person.name)), "skill": value, "here": here, "traits": Copy.trait_list(person.traits)})
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
		if text.begins_with("DAWN") or text.begins_with("INTENT") or text.begins_with("ULTIMATUM") or text.begins_with("SEASON") or text.begins_with("AGENT") or text.begins_with("SHORT") or text.begins_with("ROT") or text.begins_with("WARN") or text.begins_with("No warning"):
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
	flood_guard = true
	for key in cells:
		if cells[key].flooded:
			cells[key].flooded = false
			var uid := str(cells[key].room)
			var flooded_room = _room(uid)
			if uid != "" and flooded_room != null:
				flooded_room.offline = bool(flooded_room.get("switched_off", false))
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
			_journal("built", {"type": str(build.type)})
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
		_note("FIND flooded pocket on the lower level", "FIND на нижнем уровне затопленный карман.")
	elif find == "maintenance":
		stock.materials = int(stock.materials) + 15
		_note("FIND old maintenance room, +15 materials", "FIND старая служебная комната, +15 материалов.")
	elif find == "sealed_door":
		artifacts.papers = int(artifacts.papers) + 1
		var tunnel := _tunnel_by_id("to_floor")
		if not tunnel.is_empty():
			tunnel.dug = true
		flags["first_sealed_tunnel"] = flags.get("first_sealed_tunnel", week)
		_note("FIND a sealed door. The stencil says FLOOR.", "FIND запечатанная дверь. На трафарете: ЭТАЖ.")
	elif find == "cable":
		stock.power = int(stock.power) + int(bal.find_cable_power)
		_note("FIND old cable, +%d power" % int(bal.find_cable_power), "FIND старый кабель, +%d энергии." % int(bal.find_cable_power))
	elif find == "salvage":
		stock.materials = int(stock.materials) + int(bal.find_salvage_materials)
		_note("FIND salvage, +%d materials" % int(bal.find_salvage_materials), "FIND лом, +%d материалов." % int(bal.find_salvage_materials))
	if find in ["flooded", "maintenance", "sealed_door", "cable", "salvage"]:
		_journal("find", {"find": find})
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
	if week != int(active_season.start) or pumped or flood_guard:
		if (pumped or flood_guard) and week == int(active_season.get("start", -1)):
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
				names.append(Copy.t(str(catalog.rooms[room.type].name)))
	if _any_trait("Claustrophobic"):
		_add_hope(-2, "trait")
	var flood_note := "SEASON flood on level %d (%s)" % [lowest, ", ".join(names)]
	if Copy.ru():
		flood_note = "SEASON Паводок на уровне %d (%s)." % [lowest, ", ".join(names)]
	_log(flood_note, true)
	_journal("flood", {"level": lowest})


func _needs_pump() -> bool:
	for key in cells:
		if cells[key].flooded:
			return true
	if flood_guard:
		return false
	return _flood_eta() <= int(bal.get("season_warning", 2))


# --- council orders ---

func _apply_order(action: Dictionary) -> bool:
	if orders_left <= 0:
		return false
	var order := str(action.get("order", ""))
	var ok := false
	match order:
		"propaganda":
			ok = _order_propaganda(str(action.get("station", "")))
		"envoy":
			ok = _order_envoy(str(action.get("station", "")))
		"aid":
			ok = _order_aid(str(action.get("station", "")))
		"pay":
			ok = _order_pay(str(action.get("demand", "")))
		"gift":
			ok = _order_gift(str(action.get("faction", "")))
		"trade":
			if str(action.get("station", "")) != "":
				ok = _order_deal(str(action.station))
			else:
				ok = _order_trade()
		"move":
			ok = _order_move(str(action.get("dest", "")))
		"focus":
			ok = _order_focus(str(action.get("station", "")), str(action.get("focus", "")))
		"expedition":
			ok = _order_expedition()
		"approach":
			ok = _order_approach()
		"approach_observatory":
			ok = _order_approach_observatory()
		"approach_quarantine":
			ok = _order_approach_quarantine()
		"address":
			ok = _order_address()
	if ok:
		orders_left -= 1
		decisions += 1
		_take_seat(order)
		if order == "trade":
			_vo_cue("caravan_arrived")
			flags["first_caravan"] = flags.get("first_caravan", week)
	return ok


func _order_propaganda(sid: String) -> bool:
	if _propaganda_block(sid) != "":
		return false
	var st: Dictionary = stations[sid]
	stock.influence = int(stock.influence) - int(bal.propaganda_influence)
	var gain := sympathy_preview(sid)
	st.sympathy = int(st.sympathy) + gain
	_log("ORDER propaganda %s +%d (%d)" % [st.name, gain, int(st.sympathy)])
	if int(st.sympathy) >= 100:
		_capture(sid, player, false)
	return true


func _order_envoy(sid: String) -> bool:
	if _envoy_block(sid) != "":
		return false
	var st: Dictionary = stations[sid]
	stock.influence = int(stock.influence) - 3
	_bump_need(st, _lowest_need(st), 0.2)
	var gain := maxi(2, int(round(float(sympathy_preview(sid)) * 0.35)))
	st.sympathy = int(st.sympathy) + gain
	_log("ORDER envoy %s +%d (%d)" % [st.name, gain, int(st.sympathy)])
	if int(st.sympathy) >= 100:
		_capture(sid, player, false)
	return true


func _order_deal(sid: String) -> bool:
	if _deal_block(sid) != "":
		return false
	var st: Dictionary = stations[sid]
	stock.influence = int(stock.influence) - 4
	st.deals = int(st.get("deals", 0)) + 1
	st.passage = true
	_bump_need(st, _lowest_need(st), 0.25)
	_log("DEAL %s (%d)" % [st.name, int(st.deals)], true)
	if int(st.deals) >= 3 and str(st.owner) == "neutral":
		_log("DEAL %s asks to join" % st.name, true)
		_capture(sid, player, false)
	return true


func _take_seat(order_name: String) -> void:
	for seat in council:
		var role := str(seat.role)
		if str(seat_used.get(role, "")) == "":
			seat_used[role] = order_name
			return


func order_councillor() -> Dictionary:
	var busy := {}
	for row in queued_orders:
		busy[str(row.get("person", ""))] = true
	for seat in council:
		var role := str(seat.role)
		var pid := str(seat.id)
		if str(seat_used.get(role, "")) != "" or busy.has(pid):
			continue
		var person: Dictionary = people.get(pid, {})
		return {"role": role, "id": pid, "name": str(person.get("name", role))}
	return {}


func order_cost(kind: String, _sid: String = "") -> Dictionary:
	match kind:
		"propaganda":
			return {"influence": int(bal.propaganda_influence)}
		"envoy":
			return {"influence": 3}
		"trade":
			return {"influence": 4}
		_:
			return {}
	return {}


func queue_order(action: Dictionary) -> bool:
	var kind := str(action.get("order", ""))
	var sid := str(action.get("station", action.get("dest", "")))
	if order_block(kind, sid) != "":
		return false
	var who := order_councillor()
	if who.is_empty():
		return false
	var cost := order_cost(kind, sid)
	for key in cost:
		if int(stock.get(key, 0)) < int(cost[key]):
			return false
	for key in cost:
		stock[key] = int(stock.get(key, 0)) - int(cost[key])
	orders_left -= 1
	seat_used[str(who.role)] = kind
	var target := sid
	if kind == "expedition" and stations.has("vault"):
		target = "vault"
	elif kind == "approach" and stations.has("archive"):
		target = "archive"
	queued_orders.append({
		"action": action.duplicate(true),
		"role": str(who.role),
		"person": str(who.id),
		"name": str(who.name),
		"cost": cost.duplicate(true),
		"home": capital_id,
		"target": target,
		"kind": kind,
	})
	_journal("order", {"order": kind, "station": target, "name": str(who.name)})
	return true


func cancel_queued(role: String) -> bool:
	for i in queued_orders.size():
		var row: Dictionary = queued_orders[i]
		if str(row.role) != role:
			continue
		var cost: Dictionary = row.get("cost", {})
		for key in cost:
			stock[key] = int(stock.get(key, 0)) + int(cost[key])
		seat_used.erase(role)
		orders_left += 1
		queued_orders.remove_at(i)
		_journal("cancel", {"order": str(row.get("kind", "")), "station": str(row.get("target", ""))})
		return true
	return false


func _resolve_queued() -> void:
	var rows: Array = queued_orders.duplicate(true)
	queued_orders.clear()
	for row in rows:
		var action: Dictionary = row.get("action", {})
		var cost: Dictionary = row.get("cost", {})
		for key in cost:
			stock[key] = int(stock.get(key, 0)) + int(cost[key])
		var kind := str(action.get("order", ""))
		var sid := str(action.get("station", ""))
		var host := _order_host(kind, action)
		var ok := false
		match kind:
			"propaganda":
				ok = _order_propaganda(sid)
			"envoy":
				ok = _order_envoy(sid)
			"aid":
				ok = _order_aid(sid)
			"pay":
				ok = _order_pay(str(action.get("demand", "")))
			"gift":
				ok = _order_gift(str(action.get("faction", "")))
			"trade":
				if sid != "":
					ok = _order_deal(sid)
				else:
					ok = _order_trade()
			"move":
				ok = _order_move(str(action.get("dest", "")))
			"focus":
				ok = _order_focus(sid, str(action.get("focus", "")))
			"expedition":
				ok = _order_expedition()
			"approach":
				ok = _order_approach()
			"approach_observatory":
				ok = _order_approach_observatory()
			"approach_quarantine":
				ok = _order_approach_quarantine()
			"address":
				ok = _order_address()
		var place := sid
		if kind == "move" and stations.has(str(action.get("dest", ""))):
			place = station_text(str(action.dest), "community")
		elif stations.has(sid):
			place = station_text(sid, "community")
		seat_used.erase(str(row.get("role", "")))
		var title := Copy.t("Dawn report")
		var text := "%s · %s" % [str(row.get("name", "")), place]
		if ok:
			title = Copy.t(_order_title(kind))
		else:
			text = "%s %s" % [Copy.t("The order failed."), text]
		var report := {"title": title, "text": text, "ok": ok}
		if ok and host != "":
			report.merge(_leader_flavour("trade" if kind == "trade" else "territory", host))
		order_reports.append(report)
		if ok and kind == "trade":
			_vo_cue("caravan_arrived")
			flags["first_caravan"] = flags.get("first_caravan", week)
		_journal("order_done", {"order": kind, "station": str(action.get("dest", sid)) if kind == "move" else sid, "name": str(row.get("name", "")), "ok": ok})


## The faction whose ground the order enters or whose trade it opens, read before the order resolves
## because a capture changes the owner; "" when no faction is involved.
func _order_host(kind: String, action: Dictionary) -> String:
	var sid := str(action.get("station", ""))
	match kind:
		"envoy", "propaganda":
			pass
		"trade":
			if sid == "":
				return "exchange"
		"move":
			var sq: Dictionary = squads.get(player, {})
			var path: Array = []
			if not sq.is_empty():
				path = _path(str(sq.get("station", "")), str(action.get("dest", "")))
			sid = str(path[1]) if path.size() >= 2 else ""
		_:
			return ""
	return str(stations[sid].owner) if stations.has(sid) else ""


func _order_title(kind: String) -> String:
	match kind:
		"envoy":
			return "Envoy returns"
		"propaganda":
			return "Propaganda returns"
		"move":
			return "The squad arrives"
		"trade":
			return "The deal is struck"
		"expedition":
			return "The expedition sets out"
		"approach":
			return "Approach the Floor"
		"approach_observatory":
			return "Approach the Observatory"
		"approach_quarantine":
			return "Approach the Quarantine"
		_:
			return "Dawn report"


func order_block(kind: String, sid: String = "") -> String:
	if orders_left <= 0:
		return Copy.t("No council order left this week.")
	if order_councillor().is_empty():
		return Copy.t("No councillor is free.")
	match kind:
		"envoy":
			return _envoy_block(sid)
		"propaganda":
			return _propaganda_block(sid)
		"move":
			return _move_block(sid)
		"trade":
			if sid != "":
				return _deal_block(sid)
			if trade_on:
				return Copy.t("Trade with the Exchange is already open.")
			if int(opinions.get("exchange", -100)) < 0:
				return Copy.t("The Exchange will not deal with you.")
			if int(stock.influence) < 4:
				return Copy.t("Not enough influence.")
			return ""
		"expedition":
			return _expedition_block()
		"approach":
			return approach_block()
		"approach_observatory":
			return observatory_block()
		"approach_quarantine":
			return quarantine_block()
		_:
			return Copy.t("No such order.")
	return ""


## Why the Floor cannot be approached now; "" when it can (the order itself aside).
func approach_block() -> String:
	if floor_met:
		return Copy.t("The Floor has already been met.")
	var tunnel := _tunnel_by_id("to_floor")
	if int(artifacts.get("papers", 0)) < 1 or tunnel.is_empty() or not bool(tunnel.get("dug", false)):
		return Copy.t("Needs Papers and the Floor tunnel")
	return ""


## Why the Observatory cannot be approached now; "" when it can (the order itself aside).
func observatory_block() -> String:
	if _scene_used("st3_observatory"):
		return Copy.t("The Observatory has already been met.")
	if int(artifacts.get("words", 0)) < 2 or not fragment_known("synod_recording"):
		return Copy.t("Needs 2 testimonies and the recording")
	return ""


func can_approach_observatory() -> bool:
	return observatory_block() == "" and orders_left > 0


## Why the Quarantine cannot be approached now; "" when it can (the order itself aside).
func quarantine_block() -> String:
	if _scene_used("st3_quarantine"):
		return Copy.t("The Quarantine has already been met.")
	if int(artifacts.get("iron", 0)) < 1 or not fragment_known("quarantine_path"):
		return Copy.t("Needs the Lamplighters' path and iron")
	return ""


func can_approach_quarantine() -> bool:
	return quarantine_block() == "" and orders_left > 0


func order_risk(kind: String, sid: String = "") -> String:
	match kind:
		"envoy":
			if not stations.has(sid):
				return ""
			var gain := maxi(2, int(round(float(sympathy_preview(sid)) * 0.35)))
			return Copy.t("No risk. Sympathy +%d, and their weakest need improves.") % gain
		"propaganda":
			return Copy.t("No risk. Sympathy +%d.") % sympathy_preview(sid)
		"trade":
			if sid != "":
				return Copy.t("No risk. A deal opens passage; three deals and a neutral station joins you.")
			return Copy.t("No risk. Exchange opinion +6, and tokens every week.")
		"move":
			var sq: Dictionary = squads[player]
			if not stations.has(sid):
				return ""
			var path := _path(str(sq.station), sid)
			if path.size() < 2:
				return ""
			var nxt := str(path[1])
			var owner := str(stations[nxt].owner)
			if owner == player or owner == "neutral" or owner == "ruin":
				return Copy.t("No fight on the next step.")
			var st: Dictionary = stations[nxt]
			var attack := float(sq.size) * float(sq.gear) * (1.0 + float(sq.fight) / 10.0)
			var defense := float(st.garrison) * float(st.fort) * 1.3
			var odds := 100
			if attack > 0.0:
				odds = int(round(clampf((1.2 - defense / attack) / 0.4, 0.0, 1.0) * 100.0))
			var line := Copy.t("Battle at %s: about %d%% to win. A loss costs 30-60%% of the squad.") % [station_text(nxt, "community") if station_text(nxt, "community") != "" else str(st.name), odds]
			if not bool(at_war.get(owner, false)):
				line += " " + Copy.t("Their opinion of you drops by 20.")
			return line
		"expedition":
			return Copy.t("The squad is away 3 weeks and comes back about 15% smaller.")
		"approach", "approach_observatory", "approach_quarantine":
			return Copy.t("No risk. The meeting comes at the next dawn.")
	return ""


func _court_block(sid: String) -> String:
	if not stations.has(sid) or not borders_player(sid):
		return Copy.t("That station is out of reach.")
	var st: Dictionary = stations[sid]
	var owner := str(st.owner)
	if owner == player:
		return Copy.t("They already stand with you.")
	if owner == "bunker" or owner == "ruin" or owner == "enemy" or bool(st.get("hidden", false)) or str(st.get("bunker", "")) != "":
		return Copy.t("That station will not hear an envoy.")
	return ""


func _propaganda_block(sid: String) -> String:
	var why := _court_block(sid)
	if why != "":
		return why
	if int(stock.influence) < int(bal.propaganda_influence):
		return Copy.t("Not enough influence.")
	return ""


func _envoy_block(sid: String) -> String:
	var why := _court_block(sid)
	if why != "":
		return why
	if int(stock.influence) < 3:
		return Copy.t("Not enough influence.")
	return ""


func _deal_block(sid: String) -> String:
	var why := _court_block(sid)
	if why != "":
		return why
	if int(stations[sid].get("deals", 0)) >= 3:
		return Copy.t("Three deals are already in force.")
	if int(stock.influence) < 4:
		return Copy.t("Not enough influence.")
	return ""


func _move_block(dest: String) -> String:
	var sq: Dictionary = squads[player]
	if bool(sq.away):
		return Copy.t("The squad is away.")
	if not stations.has(dest):
		return Copy.t("No open tunnel that way.")
	if _path(str(sq.station), dest).size() < 2:
		return Copy.t("No open tunnel that way.")
	return ""


func _expedition_block() -> String:
	if not expedition.is_empty():
		return Copy.t("The expedition is already out.")
	var sq: Dictionary = squads.get(player, {})
	if bool(sq.get("away", false)) or str(sq.get("station", "")) != capital_id:
		return Copy.t("The squad must be home first.")
	var tunnel := _tunnel_by_id("to_ferry")
	if tunnel.is_empty() or bool(tunnel.get("dug", false)):
		return Copy.t("South Ferry is already open.")
	return ""


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


## Set when the South Ferry expedition walks back: the hook for story events ("needs": {"flag": ...}) that grant
## what it found, such as "artifacts": {"iron": 1}.
const EXPEDITION_FLAG := "expedition_ferry_back"


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
	_fire_trigger("approach_floor")
	return true


func _order_approach_observatory() -> bool:
	if observatory_block() != "":
		return false
	if stations.has("oldcommand"):
		stations.oldcommand.hidden = false
		stations.oldcommand.known = true
	_log("Court St answers through the grate. Someone down there has been counting.", true)
	_fire_trigger("approach_observatory")
	return true


func _order_approach_quarantine() -> bool:
	if quarantine_block() != "":
		return false
	_fire_trigger("approach_quarantine")
	return true


## The bunker scenes an order can set off ("trigger": {"order": ...}); each order name is fired from one place.
const TRIGGER_ORDERS := ["approach_floor", "approach_quarantine", "approach_observatory"]


## Queues every bunker scene waiting on `order` whose trigger conditions hold, for the next dawn, once a run.
func _fire_trigger(order: String) -> void:
	for ev in catalog.events:
		var trigger = ev.get("trigger", null)
		if not (trigger is Dictionary) or str(trigger.get("order", "")) != order or _scene_used(str(ev.id)):
			continue
		if needs_hold(trigger.get("needs", {})):
			story_queue.append(str(ev.id))


func _scene_used(id: String) -> bool:
	return events_seen.has(id) or story_queue.has(id) or _has_event(pending, id)


## Bunker scenes queued by an order come at dawn after every other draw, so no pool or slot sees them.
func _offer_triggered() -> void:
	var keep: Array = []
	for id in story_queue:
		var ev := _event_by_id(str(id))
		if ev.is_empty() or events_seen.has(str(id)):
			continue
		if not _present_event(ev):
			keep.append(id)
	story_queue = keep


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
	var st: Dictionary = stations.vault
	st.owner = "neutral"
	st.ruin = false
	st.hidden = false
	st.known = true
	st.pop = 18
	st.garrison = 6
	var sq: Dictionary = squads[player]
	sq.away = false
	sq.size = maxi(3, int(round(float(sq.size) * 0.85)))
	stock.materials = int(stock.materials) + 10
	_hire(2)
	expedition = {}
	flags[EXPEDITION_FLAG] = true
	_log("South Ferry is open. Two people walk back with the squad.", true)


# --- rivals ---

func _plan_intents() -> Array:
	var out: Array = []
	for fid in ["exchange", "directorate"]:
		if _faction_dead(fid):
			continue
		var intent := _plan_one(fid)
		var hide: bool = str(intent.kind) != "demand_posted" and not _has_radio() and net_rng.randf() < 0.25
		intent.hidden = hide
		out.append(intent)
	return out


func token_income() -> int:
	var n := 0
	if trade_on:
		n += int(bal.trade_tokens_week)
	for law_id in laws_on:
		var defin: Dictionary = catalog.laws[law_id]
		if defin.has("tokens_week"):
			n += int(defin.tokens_week)
	return n


func _book_calendar() -> void:
	pressure = {}
	warning_weeks = {}
	crisis_faults = []
	for season in bal.seasons:
		var at := int(season.week)
		var warn := at - int(bal.season_warning)
		if warn > 0:
			warning_weeks[warn] = true
			_book_pressure(warn, "warning")
		for i in int(season.weeks):
			_book_pressure(at + i, "season")
	var start := crunch_week
	var guard := 0
	while _pressure_taken(crunch_week) and guard < 12:
		guard += 1
		crunch_week += 1
		if crunch_week > int(bal.crunch_max_week):
			crunch_week = int(bal.crunch_min_week)
		if crunch_week == start:
			break
	if _pressure_taken(crunch_week):
		crisis_faults.append("crunch had no quiet week")
	else:
		_book_pressure(crunch_week, "crunch")


func _pressure_taken(at: int) -> bool:
	return pressure.has(at)


func _book_pressure(at: int, kind: String) -> bool:
	if at <= 0:
		return false
	if pressure.has(at) and str(pressure[at]) != kind:
		crisis_faults.append("%s overlapped %s on week %d" % [kind, str(pressure[at]), at])
		return false
	pressure[at] = kind
	return true


func _post_ultimatum(fid: String) -> Dictionary:
	var income := token_income()
	var basis := maxi(8, income)
	var span := 2 + int((week / int(bal.demand_every)) % 2)
	var first := 0
	var last := 0
	for shift in 8:
		var open_at := week + 1 + shift
		var close_at := open_at + 1
		if _pressure_taken(open_at) or _pressure_taken(close_at) or warning_weeks.has(close_at):
			continue
		first = open_at
		last = close_at
		break
	if first == 0:
		return {}
	if not _book_pressure(first, "ultimatum") or not _book_pressure(last, "ultimatum"):
		return {}
	var amount := basis * span
	demands.append({
		"id": "d%d" % demand_seq,
		"faction": fid,
		"amount": amount,
		"deadline": 2,
		"paid": false,
		"income": income,
		"span": span,
		"deadline_week": last,
	})
	demand_log.append({
		"week": week,
		"amount": amount,
		"income": income,
		"span": span,
		"deadline_week": last,
	})
	demand_seq += 1
	stats.ultimatums = int(stats.ultimatums) + 1
	if int(stats.get("first_ultimatum", 0)) == 0:
		stats.first_ultimatum = week
	return {"faction": fid, "kind": "demand_posted"}


func _rival_strength(fid: String) -> int:
	var held := _owned_by(fid).size()
	var body := 0
	if squads.has(fid):
		body = int(squads[fid].size)
	var sympathy := 0
	for sid in stations:
		sympathy += int(stations[sid].rival_symp.get(fid, 0))
	var push := 0
	if squads.has(fid):
		push = int(squads[fid].get("momentum", 0))
	return held * 6 + int(ambition.get(fid, 0)) + body + int(sympathy / 10) + push


func _ultimatum_threshold() -> int:
	return 68 + owned_count() * 3 + int(stock.influence) / 6


func _plan_one(fid: String) -> Dictionary:
	var opened: bool = int(stats.get("first_ultimatum", 0)) > 0
	var due: bool = opened and week > 0 and week % int(bal.demand_every) == 0
	if squads.has(fid) and not opened:
		squads[fid].momentum = int(squads[fid].get("momentum", 0)) + net_rng.randi_range(0, 3)
	var pressing: bool = not opened and week >= 6 and _rival_strength(fid) >= _ultimatum_threshold()
	if (due or pressing) and not _demand_open(fid):
		var posted := _post_ultimatum(fid)
		if not posted.is_empty():
			return posted
	var sq: Dictionary = squads[fid]
	if int(sq.secure) > 0:
		return {"faction": fid, "kind": "secure", "station": str(sq.station)}
	var target := _campaign_target(fid)
	sq.dest = target
	if target != "" and stations.has(target):
		stations[target].known = true
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
		var quiet := "No warning from %s." % _fname(fid)
		if Copy.ru():
			quiet = "No warning from %s." % Copy.t(_fname(fid))
		_log(quiet, true)


func _resolve_buy(fid: String, sid: String) -> void:
	if not stations.has(sid):
		return
	var st: Dictionary = stations[sid]
	if str(st.owner) != "neutral":
		return
	st.rival_symp[fid] = int(st.rival_symp.get(fid, 0)) + 8 + net_rng.randi_range(0, 10)
	_press_loyalty(st)
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
	var state := str(edge.get("state", "open"))
	if state == "sealed" and not bool(edge.get("dug", false)):
		return false
	if state == "collapsed" and not bool(edge.get("dug", false)):
		edge.dug = true
		edge.state = "open"
		_log("DIG the tunnel toward %s is clear" % stations[nxt].name, true)
		_journal("tunnel", {"station": nxt})
		return true
	var flooded: bool = state == "flooded" or bool(edge.get("flooded", false))
	if flooded and int(sq.get("ford", 0)) < 1:
		sq.ford = 1
		_log("%s is held up by flood water toward %s" % [sq.name, stations[nxt].name])
		return true
	sq.ford = 0
	sq.left = str(sq.station)
	var owner := str(stations[nxt].owner)
	if owner == str(sq.faction) or (player_move and (owner == "neutral" or owner == "ruin")):
		sq.station = nxt
		stations[nxt].known = true
		if player_move:
			_log("ORDER move to %s" % stations[nxt].name)
		return true
	if owner == "bunker":
		return false
	if player_move and owner != player and not bool(at_war.get(owner, false)):
		_add_opinion(owner, -20)
	if not player_move and owner == player and not bool(at_war.get(sq.faction, false)):
		return false
	if not player_move and nxt == capital_id and (week <= max_weeks or int(ambition.get(str(sq.faction), 0)) < 100):
		_log("%s holds short of %s" % [sq.name, stations[nxt].name])
		return false
	var win := _battle(sq, nxt)
	if win:
		_press_loyalty(stations[nxt])
		if _capture(nxt, str(sq.faction), true):
			sq.station = nxt
			stations[nxt].known = true
			if not player_move:
				sq.secure = int(bal.secure_turns)
		else:
			_log("%s cannot hold %s yet" % [sq.name, stations[nxt].name])
	else:
		sq.secure = 1
	return true


func _battle(sq: Dictionary, sid: String) -> bool:
	var st: Dictionary = stations[sid]
	var roll := net_rng.randf_range(0.8, 1.2)
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
	var loss := net_rng.randf_range(0.3, 0.6)
	if win:
		st.garrison = clampi(int(round(float(st.garrison) * (1.0 - loss))), 2, 22)
		_log("BATTLE %s takes %s" % [sq.name, st.name], true)
	else:
		sq.size = clampi(int(round(float(sq.size) * (1.0 - loss))), 5, 20)
		if not defender.is_empty():
			defender.size = clampi(int(round(float(defender.size) * (1.0 - loss * 0.5))), 5, 20)
		_log("BATTLE %s is thrown back from %s" % [sq.name, st.name], true)
	return win


func _capture(sid: String, fid: String, force: bool) -> bool:
	if week < 4:
		return false
	var st: Dictionary = stations[sid]
	var hostile := force or fid != player
	if hostile and int(st.get("low_weeks", 0)) < 2:
		return false
	if str(st.get("bunker", "")) != "" or str(st.owner) == "bunker":
		return false
	var prev := str(st.owner)
	if prev == fid:
		return false
	st.owner = fid
	st.sympathy = 0
	st.loyalty = 20 if force else 72
	st.unrest = net_rng.randi_range(4, 6)
	st.known = true
	st.held_weeks = 0
	st.low_weeks = 0
	if fid != player or force:
		_note_flip(sid, prev, fid)
	_journal("station", {"station": sid, "to": fid, "from": prev})
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
		var how := "force" if force else "peace"
		var joined := str(st.name)
		if Copy.ru():
			how = "силой" if force else "мирно"
			joined = Copy.t(joined)
		_log("JOIN %s (%s)" % [joined, how], true)
	else:
		_log("%s takes %s" % [_fname(fid), st.name], true)
	if sid == capital_id and fid != player and over == "":
		over = "capital"
		_log("The yard has fallen.", true)
	return true


func _campaign_target(fid: String) -> String:
	if int(stats.get("flip_week", 0)) == 0:
		var locked := str(stats.get("flip_target", ""))
		if locked != "" and stations.has(locked) and str(stations[locked].owner) == "neutral":
			return locked
		var border := _border_neutrals(fid)
		if border.size() >= 2:
			var picked := _weighted_border(border)
			if picked != "":
				stats.flip_target = picked
				return picked
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
		st.held_weeks = int(st.get("held_weeks", 0)) + 1
		var hops := _supply_hops(str(sid))
		if hops >= 900:
			continue
		var flow := Formulas.outpost_flow(int(st.held_weeks), hops, str(st.focus))
		var upkeep := int(flow.upkeep_materials)
		if upkeep > 0:
			stock.materials = maxi(0, int(stock.materials) - upkeep)
		for key in ["food", "materials", "tokens", "influence", "air"]:
			var gain := int(flow.get(key, 0))
			if gain > 0:
				stock[key] = int(stock.get(key, 0)) + gain


func _claim_swayed() -> void:
	if week < 4:
		return
	for sid in stations.keys():
		var st: Dictionary = stations[sid]
		if str(st.owner) != "neutral" and str(st.owner) != "ruin":
			continue
		if int(st.get("deals", 0)) >= 3 or int(st.sympathy) >= 100:
			_capture(str(sid), player, false)
			continue
		for fid in ["exchange", "directorate", "synod"]:
			if int(st.rival_symp.get(fid, 0)) >= 100:
				_capture(str(sid), fid, false)
				break


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
			var courting := _courting_rival()
			if courting != "" and st.rival_symp.has(courting):
				st.rival_symp[courting] = int(st.rival_symp[courting]) + 8
		if not _connected(sid):
			st.loyalty = int(st.loyalty) - 5
		st.loyalty = clampi(int(st.loyalty), 0, 100)
		_mark_low(st)
		if int(st.low_weeks) >= 2 and week >= 4:
				var suitor := _suitor(st)
				if suitor != "":
					_log("DEFECT %s leaves for %s" % [st.name, _fname(suitor)], true)
					_capture(sid, suitor, false)
				else:
					_log("REVOLT %s throws the garrison out" % st.name, true)
					_journal("station", {"station": sid, "to": "neutral", "from": player})
					st.owner = "neutral"
					st.loyalty = 45
					st.sympathy = 0
					st.unrest = 0
					st.low_weeks = 0
					_note_flip(sid, player, "neutral")


func _press_loyalty(st: Dictionary) -> void:
	st.loyalty = maxi(0, int(st.loyalty) - (4 + net_rng.randi_range(0, 7)))
	_mark_low(st)


func _mark_low(st: Dictionary) -> void:
	if int(st.loyalty) >= 42:
		st.low_weeks = 0
		return
	if int(st.get("marked_week", -1)) == week:
		return
	st.marked_week = week
	st.low_weeks = int(st.get("low_weeks", 0)) + 1
	if int(st.low_weeks) == 1:
		var place := str(st.name)
		if Copy.ru():
			place = Copy.t(place)
		_log("WARN %s is losing its loyalty" % place, true)


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
			_journal("war", {"faction": fid})


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
		_stamp_checks(person)
		residents.append(person)
		people[id] = person


func _kill(n: int, why: String) -> void:
	_shed(n)
	if n > 0:
		_log("%s. %d dead." % [why, n], true)
		_journal("deaths", {"n": n})
		_vo_cue("resident_lost")


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
		_journal("born", {"n": born})


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
		names.append(Copy.t(str(leg.short)))
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
		"pay": "Spend %s to close the gap", "suffer": "Let the stores run down",
		"pain": food_gap, "hit": {"food": -food_gap},
	}
	var ducts := {
		"id": "ducts", "short": "the ducts", "title": "Ice in the ducts",
		"text": "Meltwater has frozen in the vent runs. Clear it, or the yard draws twice the power tonight.",
		"pay": "Spend %s to clear the ducts", "suffer": "Leave the ice",
		"pain": power_pain, "hit": {"discontent": 4, "power_double": true},
	}
	var belt := {
		"id": "belt", "short": "the belt", "title": "The grow lamps snap",
		"text": "A belt on the hydroponic lamps snaps. Replace it, or the beds give half a crop this week.",
		"pay": "Spend %s on a new belt", "suffer": "Let the beds run at half",
		"pain": belt_pain, "hit": {"hope": -2, "discontent": 2, "hydro_down": true},
	}
	var stacks := {
		"id": "stacks", "short": "the stacks", "title": "The charcoal beds pack solid",
		"text": "The air filters are caked. Materials can clear them. Leaving them spends the air you saved.",
		"pay": "Spend %s to clear the stacks", "suffer": "Let the air run down",
		"pain": air_gap, "hit": {"air": -air_gap},
	}
	var shop := {
		"id": "shopbelt", "short": "the workshop", "title": "A belt in the workshop slips",
		"text": "The workshop belt is off its wheel. Fix it, or the shop makes nothing this week.",
		"pay": "Spend %s to seat the belt", "suffer": "Let the shop sit idle",
		"pain": shop_pain, "hit": {"shop_down": true, "discontent": 2},
	}
	var dynamo := {
		"id": "dynamo", "short": "the dynamo", "title": "The dynamo runs hot",
		"text": "The generator bearing is dry. Grease it, or the dynamo makes half power tonight.",
		"pay": "Spend %s to grease the bearing", "suffer": "Let the dynamo limp",
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
			{"id": "pay", "label": Copy.t(str(leg.pay)) % Words.count(cost, "material"), "cost": {"materials": cost}},
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
	if week == crunch_week:
		for item in follows:
			if int(item.due) <= week:
				item.due = week + 1
		return
	_present_due_follows()
	var pool := _event_pool(rng.randf() < 0.4)
	if pool.is_empty():
		pool = _event_pool(false)
	if pool.is_empty():
		return
	_present_event(_weighted(pool))


## Events with "needs" show once a run, only while every condition in it holds, and never enter the random
## pool (_event_ok). A forced one (needs_forced) is shown at dawn unless a major event is already waiting, then
## it tries again next dawn until its window closes; one per week at most, the one whose window closes first.
## Draws nothing from the random streams. The others are story beats (_offer_story_event).
func _offer_forced_event() -> void:
	for ev in pending:
		if bool(ev.get("major", false)):
			return
	var pick := {}
	var pick_left := 1 << 30
	for ev in catalog.events:
		if not needs_forced(ev):
			continue
		var left := needs_window(ev)
		if left >= 0 and left < pick_left:
			pick = ev
			pick_left = left
	if not pick.is_empty():
		_present_event(pick)


## The story slot: at most one story beat a week, on top of whatever the random pool brought, weighted among
## the beats whose window is open, drawn only from story_rng so the pool's stream and order stay as they were.
## Outside the pool's cooldown and minor cap. A busy week (story_slot_free) passes; a beat whose window holds no
## free week does not show this run.
func _offer_story_event() -> void:
	if not story_slot_free():
		return
	var open: Array = []
	for ev in catalog.events:
		if story_beat(ev) and not _has_event(pending, str(ev.id)) and needs_window(ev) >= 0:
			open.append(ev)
	if not open.is_empty():
		_present_event(_weighted(open, story_rng))


## No story beat in a week that already brought 3 or more other events, a leader consequence, a season, or a
## food or air crisis (a shortage last night, or stock plus a night's output short of a night's need).
func story_slot_free() -> bool:
	var others := 0
	for id in week_event_ids:
		var ev := _event_by_id(str(id))
		if ev.has("needs"):
			if needs_forced(ev):
				return false
			continue
		others += 1
	if others >= 3 or not active_season.is_empty():
		return false
	var causes: Array = stats.get("shortage_causes", [])
	if not causes.is_empty() and int(causes[-1].week) == week - 1 and str(causes[-1].cause) != "power":
		return false
	return int(stock.food) + output_of("food") >= food_need() and int(stock.air) + output_of("air") >= air_need()


static func story_beat(ev: Dictionary) -> bool:
	return ev.has("needs") and not needs_forced(ev) and not bool(ev.get("chain_only", false)) \
		and not bool(ev.get("check_only", false))


const NEEDS_KEYS := ["leader", "answer", "after_weeks", "standing_min", "standing_max", "band", "fragment",
	"no_fragment", "flag", "no_flag", "artifacts_min", "week", "season", "ending_blocked"]
## Weeks a window stays open when nothing in "needs" closes it.
const OPEN_WINDOW := 1 << 20

## "forced": true, or by default any leader consequence (needs.leader), as data/events_leaders.json has none.
static func needs_forced(ev: Dictionary) -> bool:
	var needs = ev.get("needs", null)
	if not (needs is Dictionary):
		return false
	return bool(ev.get("forced", needs.has("leader")))


## Weeks left in the event's window this dawn (OPEN_WINDOW when nothing closes it), or -1 when it cannot show
## now: it has shown already or a condition in "needs" does not hold. Every key is optional; all must hold.
func needs_window(ev: Dictionary) -> int:
	var needs = ev.get("needs", null)
	if not (needs is Dictionary) or events_seen.has(str(ev.id)):
		return -1
	var left := OPEN_WINDOW
	if needs.has("leader"):
		var row: Dictionary = leader_answers.get(str(needs.leader), {})
		if row.is_empty() or not answer_matches(str(needs.get("answer", "")), str(row.answer)):
			return -1
		if needs.has("after_weeks"):
			var span: Array = needs.after_weeks
			var since := week - int(row.week)
			if since < int(span[0]) or since > int(span[1]):
				return -1
			left = mini(left, int(span[1]) - since)
	if needs.has("week"):
		var weeks: Array = needs.week
		if week < int(weeks[0]) or week > int(weeks[1]):
			return -1
		left = mini(left, int(weeks[1]) - week)
	if offers_ending(ev) and not _ending_open(ev):
		return -1
	return left if needs_hold(needs) else -1


## The conditions in "needs" that do not depend on a window.
func needs_hold(needs: Dictionary) -> bool:
	for fid in needs.get("standing_min", {}):
		if int(standing.get(str(fid), 0)) < int(needs.standing_min[fid]):
			return false
	for fid in needs.get("standing_max", {}):
		if int(standing.get(str(fid), 0)) > int(needs.standing_max[fid]):
			return false
	for fid in needs.get("band", {}):
		if standing_band(str(fid)) != str(needs.band[fid]):
			return false
	if needs.has("fragment") and not fragment_known(str(needs.fragment)):
		return false
	if needs.has("no_fragment") and fragment_known(str(needs.no_fragment)):
		return false
	if needs.has("flag") and not flags.has(str(needs.flag)):
		return false
	if needs.has("no_flag") and flags.has(str(needs.no_flag)):
		return false
	for key in needs.get("artifacts_min", {}):
		if int(artifacts.get(str(key), 0)) < int(needs.artifacts_min[key]):
			return false
	if needs.has("season") and not _season_is(str(needs.season)):
		return false
	if needs.has("ending_blocked") and ending_blocked() != bool(needs.ending_blocked):
		return false
	return true


## Whether every story ending is closed: no choice with an "ending" in any event has its "requires" met.
func ending_blocked() -> bool:
	for ev in catalog.events:
		if _ending_open(ev):
			return false
	return true


static func offers_ending(ev: Dictionary) -> bool:
	return ev.get("choices", []).any(func(c): return c is Dictionary and str(c.get("ending", "")) != "")


## An event offering endings is only worth showing while at least one of those endings can be chosen.
func _ending_open(ev: Dictionary) -> bool:
	for choice in ev.get("choices", []):
		if str(choice.get("ending", "")) != "" and requires_reason(choice.get("requires", {})) == "":
			return true
	return false


static func answer_matches(wanted: String, given: String) -> bool:
	return wanted == given or (wanted == "refused" and given == "silence")


func _present_due_follows() -> void:
	var keep: Array = []
	var presented := 0
	for item in follows:
		if int(item.due) > week:
			keep.append(item)
			continue
		if presented >= 1:
			item.due = week + 1
			keep.append(item)
			continue
		var ev := _event_by_id(str(item.id))
		if ev.is_empty():
			continue
		var copy: Dictionary = _copy(ev)
		var memory := str(item.get("memory", ""))
		var by = ev.get("by", {})
		if by is Dictionary and by.has(memory):
			copy.text = str(by[memory])
		if _present_event(copy):
			presented += 1
	follows = keep


func _event_by_id(id: String) -> Dictionary:
	for ev in catalog.events:
		if str(ev.id) == id:
			return ev
	return {}


func _note_dawn_afford() -> void:
	if pending.is_empty():
		return
	var any := false
	for ev in pending:
		for choice in ev.choices:
			if _afford(choice.get("cost", {})):
				any = true
	if not any:
		stats["unaffordable_dawn"] = int(stats.get("unaffordable_dawn", 0)) + 1


func _schedule_follow(ev: Dictionary, choice: Dictionary) -> void:
	var follow := str(ev.get("follow", ""))
	if follow == "":
		return
	var gap := (story_rng if story_beat(ev) else rng).randi_range(2, 6)
	var due := week + gap
	var earliest := 0
	if event_last.has(follow):
		earliest = int(event_last[follow]) + int(bal.get("event_cooldown", 8))
	for item in follows:
		if str(item.id) == follow:
			earliest = maxi(earliest, int(item.due) + int(bal.get("event_cooldown", 8)))
	if earliest > due:
		return
	follows.append({"id": follow, "due": due, "memory": str(choice.id)})


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
		if _cost_empty(choice.get("cost", {})) and str(choice.get("ending", "")) == "":
			return choice
	return {}


func _cost_empty(cost) -> bool:
	if typeof(cost) != TYPE_DICTIONARY:
		return true
	for key in cost:
		if int(cost[key]) > 0:
			return false
	return true


func _present_event(ev: Dictionary) -> bool:
	var id := str(ev.id)
	if _has_event(pending, id) or week_event_ids.has(id):
		return false
	var copy: Dictionary = _copy(ev)
	if id == "refugees":
		var n := rng.randi_range(int(bal.refugee_min), int(bal.refugee_max))
		copy.text = Copy.t("%s at the yard gate with a story about a collapse north of Atlantic Av.") % Words.count(n, "person", "people")
		for choice in copy.choices:
			if str(choice.id) == "take":
				choice.people = n
				choice.label = Copy.t("Take in %d") % n
	week_event_ids[id] = true
	_calibrate_checks(copy)
	pending.append(copy)
	event_last[id] = week
	event_times[id] = int(event_times.get(id, 0)) + 1
	if not events_seen.has(id):
		events_seen[id] = week
	event_history.append({"id": id, "week": week})
	return true


func _event_pool(major_only: bool) -> Array:
	var pool: Array = []
	for ev in catalog.events:
		if ev.has("needs") or ev.has("trigger"):
			continue
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
	if bool(ev.get("chain_only", false)) or bool(ev.get("check_only", false)):
		return false
	if ev.has("needs") or ev.has("trigger"):
		return false
	if id == "lamps" and week == crunch_week:
		return false
	var cool := maxi(int(bal.get("event_cooldown", 8)), int(ev.get("cooldown", 8)))
	if event_last.has(id) and week - int(event_last[id]) < cool:
		return false
	if not bool(ev.get("major", false)) and int(event_times.get(id, 0)) >= int(bal.get("event_minor_cap", 2)):
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
		var choice := {}
		for c in ev.choices:
			if choice_locked(c) or not choice_offered(c) or not _afford(c.get("cost", {})) or str(c.get("ending", "")) != "":
				continue
			choice = c
			break
		if choice.is_empty():
			pending.pop_front()
			continue
		var person := ""
		if choice.has("check"):
			person = best_check_resident(str(choice.check.get("skill", "")))
		if not _apply_event({"event_id": ev.id, "choice_id": choice.id, "person": person}):
			pending.pop_front()


func choice_locked(choice: Dictionary) -> bool:
	return bool(choice.get("locked", false)) or requires_reason(choice.get("requires", {})) != ""


## Why a locked choice is closed, one line for the card: a check's lock_reason or the first unmet "requires".
func lock_reason(choice: Dictionary) -> String:
	if bool(choice.get("locked", false)):
		return str(choice.get("lock_reason", ""))
	return requires_reason(choice.get("requires", {}))


## Choice-level "requires": the "needs" keys plus these.
const REQUIRES_EXTRA := ["proofs_min", "hope_min", "any_flag", "any_of"]
## What a flag read by "requires" is called on the card; any other flag shows its id with spaces.
const FLAG_TEXT := {
	"floor_published": "the minutes read aloud",
	"floor_deal": "a place on the Floor's list",
	"floor_to_directorate": "the Floor handed over",
	"observatory_trusted": "the Observatory's trust",
	"observatory_sheltered": "the Observatory sheltered",
	"observatory_stripped": "the Observatory stripped",
	"quarantine_open": "the Quarantine door opened",
}
const ARTIFACT_TEXT := {"papers": "Papers", "iron": "Iron", "words": "Words"}


static func flag_text(flag: String) -> String:
	return Copy.t(str(FLAG_TEXT.get(flag, flag.replace("_", " "))))


## The first condition in `req` that does not hold, as one line in the current language; "" when all hold.
## Never empty for an unmet condition, so a closed choice always says why.
func requires_reason(req) -> String:
	if not (req is Dictionary) or req.is_empty():
		return ""
	if req.has("week"):
		var weeks: Array = req.week
		if week < int(weeks[0]) or week > int(weeks[1]):
			return Copy.t("Only in weeks %d to %d") % [int(weeks[0]), int(weeks[1])]
	if req.has("leader"):
		var row: Dictionary = leader_answers.get(str(req.leader), {})
		if row.is_empty() or not answer_matches(str(req.get("answer", "")), str(row.answer)):
			return Copy.t("Needs your answer to %s") % _leader_display(str(req.leader))
		if req.has("after_weeks"):
			var since := week - int(row.week)
			if since < int(req.after_weeks[0]) or since > int(req.after_weeks[1]):
				return Copy.t("Only %d to %d weeks after your answer to %s") % [int(req.after_weeks[0]), int(req.after_weeks[1]), _leader_display(str(req.leader))]
	for fid in req.get("standing_min", {}):
		var now := int(standing.get(str(fid), 0))
		if now < int(req.standing_min[fid]):
			return Copy.t("Needs %s's trust: %d") % [_faction_of(str(fid)), int(req.standing_min[fid])]
	for fid in req.get("standing_max", {}):
		var now := int(standing.get(str(fid), 0))
		if now > int(req.standing_max[fid]):
			return Copy.t("Needs %s's regard at %d or lower, now %d") % [_leader_display(str(fid)), int(req.standing_max[fid]), now]
	for fid in req.get("band", {}):
		if standing_band(str(fid)) != str(req.band[fid]):
			return Copy.t("Needs %s at %s") % [_leader_display(str(fid)), Copy.t(str(req.band[fid]))]
	if req.has("fragment") and not fragment_known(str(req.fragment)):
		return Copy.t("Needs the fragment: %s") % _fragment_name(str(req.fragment))
	if req.has("no_fragment") and fragment_known(str(req.no_fragment)):
		return Copy.t("Closed: you already know %s") % _fragment_name(str(req.no_fragment))
	if req.has("flag") and not flags.has(str(req.flag)):
		return Copy.t("Needs %s") % flag_text(str(req.flag))
	if req.has("no_flag") and flags.has(str(req.no_flag)):
		return Copy.t("Closed: %s") % flag_text(str(req.no_flag))
	for key in req.get("artifacts_min", {}):
		var have := int(artifacts.get(str(key), 0))
		if have < int(req.artifacts_min[key]):
			return Copy.t("Needs %s %d, you have %d") % [Copy.t(str(ARTIFACT_TEXT.get(str(key), key))), int(req.artifacts_min[key]), have]
	if req.has("season") and not _season_is(str(req.season)):
		return Copy.t("Only during the %s") % Copy.season(str(req.season))
	if req.has("ending_blocked") and ending_blocked() != bool(req.ending_blocked):
		return Copy.t("Not while an ending is open") if bool(req.ending_blocked) else Copy.t("Only while an ending is open")
	if req.has("proofs_min") and proofs() < int(req.proofs_min):
		if Copy.ru():
			return "Нужно %d %s, у вас %d" % [int(req.proofs_min), Copy.plural(int(req.proofs_min), ["доказательство", "доказательства", "доказательств"]), proofs()]
		return "Needs %d %s, you have %d" % [int(req.proofs_min), "proof" if int(req.proofs_min) == 1 else "proofs", proofs()]
	if req.has("hope_min") and hope < int(req.hope_min):
		return Copy.t("Needs hope %d, now %d") % [int(req.hope_min), hope]
	if req.has("any_flag"):
		var names: PackedStringArray = []
		var any := false
		for flag in req.any_flag:
			any = any or flags.has(str(flag))
			names.append(flag_text(str(flag)))
		if not any:
			return Copy.t("Needs %s") % Copy.t(" or ").join(names)
	if req.has("any_of"):
		var whys: PackedStringArray = []
		var nouns: PackedStringArray = []
		for sub in req.any_of:
			var why := requires_reason(sub)
			if why == "":
				return ""
			whys.append(why)
			nouns.append(_unmet_noun(sub))
		if not nouns.has(""):
			return Copy.t("Needs %s") % Copy.t(" or ").join(nouns)
		return Copy.t("; or ").join(whys)
	return ""


## The first unmet condition in `req` as a short noun for an "either way" reason; "" when it has none.
func _unmet_noun(req: Dictionary) -> String:
	if req.size() != 1:
		return ""
	if req.has("flag") and not flags.has(str(req.flag)):
		return flag_text(str(req.flag))
	for fid in req.get("standing_min", {}):
		if int(standing.get(str(fid), 0)) < int(req.standing_min[fid]):
			return Copy.t("%s's trust: %d") % [_faction_of(str(fid)), int(req.standing_min[fid])]
	if req.has("hope_min") and hope < int(req.hope_min):
		return Copy.t("hope %d") % int(req.hope_min)
	return ""


func _leader_display(fid: String) -> String:
	var pair = leader_name(fid, "name")
	if pair is Dictionary:
		var out := str(pair.get("ru", "")) if Copy.ru() else ""
		return out if out != "" else str(pair.get("en", fid))
	return str(pair) if str(pair) != "" else fid


## Russian takes the faction in the genitive ("доверие Дирекции"); English uses its short name.
const FACTION_OF_RU := {"depot": "Депо", "directorate": "Дирекции", "synod": "Синода", "exchange": "Биржи", "black_flag": "Фонарщиков"}


## The faction as read in a reason line: "the Directorate" / "Дирекции".
func _faction_of(fid: String) -> String:
	if Copy.ru() and FACTION_OF_RU.has(fid):
		return str(FACTION_OF_RU[fid])
	if catalog.factions.has(fid):
		return "the " + str(catalog.factions[fid].short)
	return "the Lamplighters" if fid == "black_flag" else _leader_display(fid)


func _fragment_name(id: String) -> String:
	var title := fragment_text(id, "title")
	return title if title != "" else id.replace("_", " ")


func choice_offered(choice: Dictionary) -> bool:
	var color := str(choice.get("check", {}).get("color", ""))
	return not (color == "red" and week < 6)


func line_of(node: Dictionary, key: String) -> String:
	if not node.has(key):
		return ""
	if Copy.ru() and node.get("ru_own", null) is Dictionary and node.ru_own.has(key):
		return str(node.ru_own[key])
	var pack = node[key]
	if pack is Dictionary:
		var lang := "ru" if Copy.ru() else "en"
		if str(pack.get(lang, "")) != "":
			return str(pack[lang])
		return str(pack.get("en", ""))
	return str(pack)


func best_check_resident(skill: String) -> String:
	var best := ""
	var best_v := -1
	var best_named := false
	for person in residents:
		if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		var value := check_value(person, skill)
		var named := _named_cast(person)
		if value > best_v or (value == best_v and named and not best_named):
			best_v = value
			best = str(person.id)
			best_named = named
	return best


func _named_cast(person: Dictionary) -> bool:
	return person.has("dossier") or str(person.get("name_ru", "")) != ""


func check_value(person: Dictionary, skill: String) -> int:
	if not person.has("checks"):
		_stamp_checks(person)
	return int(person.get("checks", {}).get(skill, 0))


func check_modifiers(skill: String) -> Array:
	var rows: Array = []
	if skill == "wits" and _room_ready("workshop"):
		rows.append({"text": "Workshop", "amount": 1})
	if skill == "wits" and _law_on("engineers_charter"):
		rows.append({"text": "Engineers' Charter", "amount": 1})
	if skill == "voice" and _room_ready("meeting_hall"):
		rows.append({"text": "Meeting hall", "amount": 1})
	if skill == "voice" and _law_on("sermons"):
		rows.append({"text": "Sermons", "amount": 1})
	if skill == "senses" and _room_ready("air_filter"):
		rows.append({"text": "Air filter", "amount": 1})
	if skill == "grit" and _room_ready("quarters"):
		rows.append({"text": "Quarters", "amount": 1})
	if skill == "grit" and _law_on("rationing"):
		rows.append({"text": "Rationing", "amount": -1})
	var kept: Array = []
	var sum := 0
	for row in rows:
		var amt := int(row.amount)
		if amt > 0 and sum >= 2:
			continue
		if amt > 0 and sum + amt > 2:
			amt = 2 - sum
		var shown: Dictionary = row.duplicate()
		shown.amount = amt
		sum += amt
		kept.append(shown)
	return kept


func _calibrate_checks(ev: Dictionary) -> void:
	for choice in ev.get("choices", []):
		if not choice.has("check"):
			continue
		var check: Dictionary = choice.check
		var skill := str(check.get("skill", "wits"))
		var color := str(check.get("color", "white"))
		var who := best_check_resident(skill)
		var bonus := check_bonus(skill, who)
		check.difficulty = bonus + (6 if color == "white" else 7)


func check_bonus(skill: String, person_id: String) -> int:
	var bonus := 0
	if people.has(person_id):
		bonus += check_value(people[person_id], skill)
	for row in check_modifiers(skill):
		bonus += int(row.amount)
	return bonus


func check_chance(skill: String, difficulty: int, person_id: String, color: String = "") -> int:
	var bonus := check_bonus(skill, person_id)
	var ok := 0
	for a in 6:
		for b in 6:
			if _check_hits(a + 1, b + 1, bonus, difficulty, color):
				ok += 1
	return int(round(float(ok) * 100.0 / 36.0))


func _check_hits(d1: int, d2: int, bonus: int, difficulty: int, color: String) -> bool:
	if d1 == 6 and d2 == 6:
		return true
	if d1 == 1 and d2 == 1:
		return false
	var total := d1 + d2 + bonus
	if total > difficulty:
		return true
	# A red total that only ties the target succeeds when the first die is higher.
	# That puts the best resident at 50%, the only 2d6 step inside 45-65 besides 58%.
	if total == difficulty and (color != "red" or d1 > d2):
		return true
	return false


func check_preview(choice: Dictionary, person_id: String) -> Dictionary:
	var check: Dictionary = choice.get("check", {})
	var skill := str(check.get("skill", ""))
	if person_id == "" or not people.has(person_id):
		person_id = best_check_resident(skill)
	var who := ""
	if people.has(person_id):
		who = str(people[person_id].name)
	return {
		"skill": skill,
		"difficulty": int(check.get("difficulty", 10)),
		"color": str(check.get("color", "white")),
		"person": person_id,
		"name": str(who),
		"value": check_value(people[person_id], skill) if people.has(person_id) else 0,
		"modifiers": check_modifiers(skill),
		"chance": check_chance(skill, int(check.get("difficulty", 10)), person_id, str(check.get("color", ""))),
		"locked": choice_locked(choice),
		"reason": lock_reason(choice),
	}


func _stamp_checks(person: Dictionary) -> void:
	var existing = person.get("checks", {})
	if existing is Dictionary and not (existing as Dictionary).is_empty():
		return
	var skills: Dictionary = person.get("skills", {})
	var traits: Array = person.get("traits", [])
	var role := str(person.get("council", ""))
	var grit := _check_band(maxi(int(skills.get("labor", 0)), int(skills.get("fight", 0))))
	var wits := _check_band(int(skills.get("tech", 0)))
	var voice := _check_band(int(skills.get("talk", 0)))
	var senses := _check_band(maxi(int(skills.get("care", 0)), int(skills.get("fight", 0)) - 1))
	if traits.has("Veteran"):
		grit += 1
	if traits.has("Ex-driver"):
		wits += 1
	if traits.has("Devout"):
		voice += 1
	if traits.has("Black marketeer") or traits.has("Insomniac"):
		senses += 1
	if traits.has("Claustrophobic"):
		grit -= 1
	if role == "marshal":
		grit += 1
	elif role == "steward":
		wits += 1
	elif role == "envoy":
		voice += 1
	person.checks = {
		"grit": clampi(grit, 0, 3),
		"wits": clampi(wits, 0, 3),
		"voice": clampi(voice, 0, 3),
		"senses": clampi(senses, 0, 3),
	}


func _check_band(value: int) -> int:
	if value >= 5:
		return 3
	if value >= 4:
		return 2
	if value >= 2:
		return 1
	return 0


func _install_check_events() -> void:
	var keep: Array = []
	for ev in catalog.events:
		if not bool(ev.get("check_only", false)):
			keep.append(ev)
	for raw in catalog.check_events.get("events", []):
		if raw is Dictionary:
			keep.append(_convert_check_event(raw))
	catalog.events = keep


func _convert_check_event(raw: Dictionary) -> Dictionary:
	var choices: Array = []
	for opt in raw.get("options", []):
		if opt is Dictionary:
			choices.append(_convert_check_option(opt))
	var open_fx = raw.get("effects_on_open", {})
	return {
		"id": str(raw.get("id", "")),
		"check_only": true,
		"weight": 0,
		"min_week": int(raw.get("min_week", 6)),
		"banner": str(raw.get("banner", "")),
		"requires_room": str(raw.get("requires_room", "")),
		"effects_on_open": open_fx if open_fx is Dictionary else {},
		"title": raw.get("title", {}),
		"text": raw.get("intro", {}),
		"choices": choices,
	}


func _convert_check_option(opt: Dictionary) -> Dictionary:
	var check := {
		"skill": str(opt.get("skill", "wits")),
		"difficulty": int(opt.get("target", 10)),
		"color": str(opt.get("color", "white")),
	}
	var fail: Dictionary = opt.get("fail", {})
	if fail.has("retry_after") and fail.retry_after is Dictionary:
		check.retry = _convert_retry(fail.retry_after)
	var choice := {
		"id": str(opt.get("id", "")),
		"label": opt.get("text", {}),
		"check": check,
		"success": _pack_outcome(opt.get("success", {})),
		"failure": _pack_outcome(fail),
	}
	if opt.has("stake") and opt.stake is Dictionary:
		choice.cost = opt.stake
	return choice


func _pack_outcome(block: Dictionary) -> Dictionary:
	var out := {}
	if block.has("text"):
		out.text = block.text
	var effects = block.get("effects", {})
	if effects is Dictionary:
		for key in effects:
			out[key] = effects[key]
	return out


func _convert_retry(raw: Dictionary) -> Dictionary:
	var retry := {}
	if raw.has("label"):
		retry.label = raw.label
	if raw.has("room_level") and raw.room_level is Dictionary:
		for room_id in raw.room_level:
			retry.room = str(room_id)
			retry.level = int(raw.room_level[room_id])
			break
	elif raw.has("room"):
		retry.room = str(raw.room)
	elif raw.has("skill"):
		retry.skill = str(raw.skill)
		retry.at = int(raw.get("min", 2))
	return retry


func _schedule_checks() -> void:
	check_schedule = []
	var taken := {}
	var cursor := 6
	for ev in catalog.events:
		if not bool(ev.get("check_only", false)):
			continue
		var lo := maxi(int(ev.get("min_week", 6)), cursor)
		var at := check_rng.randi_range(lo, lo + 3)
		var guard := 0
		while taken.has(at) and guard < 12:
			at += 1
			guard += 1
		taken[at] = true
		cursor = at + 1
		check_schedule.append({"id": str(ev.id), "week": at, "done": false})


func _offer_checks() -> void:
	for item in check_schedule:
		if bool(item.get("done", false)) or int(item.week) != week:
			continue
		var ev := _event_by_id(str(item.id))
		if ev.is_empty():
			item.done = true
			continue
		var need := str(ev.get("requires_room", ""))
		if need != "" and room_count(need) <= 0:
			item.week = week + 1
			continue
		if _present_event(ev):
			item.done = true
			if not bool(ev.get("opened", false)):
				var live: Dictionary = pending[pending.size() - 1]
				_apply_effect_block(live.get("effects_on_open", {}), "", false, live)
				ev.opened = true
				live.opened = true
		else:
			item.week = week + 1


func _release_white_checks() -> void:
	var keep: Array = []
	for ev in white_pending:
		var ready := false
		for choice in ev.choices:
			if not choice_locked(choice) or bool(choice.get("spent", false)):
				continue
			if _retry_met(choice):
				choice.locked = false
				choice.retry_open = true
				choice.lock_reason = ""
				ready = true
		if ready and not _has_event(pending, str(ev.id)):
			_calibrate_checks(ev)
			if str(ev.id) == "vents":
				vent_cut = 0
			pending.append(ev)
		elif not ready:
			keep.append(ev)
	white_pending = keep


func _retry_met(choice: Dictionary) -> bool:
	var retry: Dictionary = choice.get("check", {}).get("retry", {})
	if retry.has("level"):
		return _room_built_level(str(retry.get("room", ""))) >= int(retry.level)
	if retry.has("room"):
		return room_count(str(retry.room)) > 0
	if retry.has("skill"):
		var need := int(retry.get("at", 2))
		for person in residents:
			if check_value(person, str(retry.skill)) >= need:
				return true
		return false
	return true


func _room_built_level(type: String) -> int:
	var best := 0
	for room in rooms:
		if str(room.type) != type:
			continue
		best = maxi(best, int(room.upgrade) + 1)
	return best


func _retry_line(choice: Dictionary) -> String:
	var retry: Dictionary = choice.get("check", {}).get("retry", {})
	var authored := line_of(retry, "label")
	if authored != "":
		if Copy.ru():
			return "Повтор: %s" % authored
		return "Retry after: %s" % authored
	if retry.has("level"):
		var named := str(catalog.rooms[str(retry.get("room", ""))].name)
		if Copy.ru():
			return "Повтор, когда %s достигнет уровня %d" % [Copy.t(named), int(retry.level)]
		return "Retry after: %s level %d" % [named, int(retry.level)]
	if retry.has("room"):
		var name := str(catalog.rooms[str(retry.room)].name)
		if Copy.ru():
			return "Повтор, когда построите: %s" % Copy.t(name)
		return "Retry after: build %s" % name
	if retry.has("skill"):
		var label := Copy.skill(str(retry.skill))
		var need := int(retry.get("at", 2))
		if Copy.ru():
			return "Повтор, когда кто-то достигнет: %s %d" % [label, need]
		return "Retry after: a resident reaches %s %d" % [label, need]
	if Copy.ru():
		return "Повтор на следующей неделе."
	return "Retry after: next week"


func _resolve_check(ev: Dictionary, choice: Dictionary, person_id: String) -> bool:
	var check: Dictionary = choice.get("check", {})
	var skill := str(check.get("skill", "wits"))
	var color := str(check.get("color", "white"))
	if color == "red" and week < 6:
		return true
	if person_id == "" or not people.has(person_id):
		person_id = best_check_resident(skill)
	var difficulty := int(check.get("difficulty", 10))
	var bonus := check_bonus(skill, person_id)
	var d1 := check_rng.randi_range(1, 6)
	var d2 := check_rng.randi_range(1, 6)
	var box := d1 == 6 and d2 == 6
	var snake := d1 == 1 and d2 == 1
	var success := _check_hits(d1, d2, bonus, difficulty, color)
	var retried := bool(choice.get("retry_open", false))
	var outcome_block: Dictionary = choice.get("success", {}) if success else choice.get("failure", {})
	last_check = {
		"skill": skill, "color": color, "d1": d1, "d2": d2, "bonus": bonus,
		"success": success, "box": box, "snake": snake,
		"name": str(people[person_id].name) if people.has(person_id) else "",
		"outcome": line_of(outcome_block, "text"),
	}
	_note_check(color, success, retried)
	var face := "double 6" if box else ("double 1" if snake else "%d+%d" % [d1, d2])
	var verdict := "Success" if success else "Failure"
	if Copy.ru():
		face = "две шестёрки" if box else ("две единицы" if snake else "%d+%d" % [d1, d2])
		verdict = "Успех" if success else "Провал"
	var signed := "+%d" % bonus if bonus >= 0 else str(bonus)
	var line := "CHECK %s %s %s vs %d. %s." % [Copy.skill(skill), face, signed, difficulty, verdict]
	if Copy.ru():
		line = "ПРОВЕРКА %s %s %s против %d. %s." % [Copy.skill(skill), face, signed, difficulty, verdict]
	_log(line, true)
	if success:
		_apply_effect_block(choice.get("success", {}), person_id, false, ev)
		if str(ev.id) == "vents":
			vent_cut = 0
		return true
	if color == "red":
		_apply_effect_block(choice.get("failure", {}), person_id, true, ev)
		return true
	_apply_effect_block(choice.get("failure", {}), person_id, false, ev)
	if retried:
		choice.locked = true
		choice.spent = true
		choice.lock_reason = "The roll stands." if not Copy.ru() else "Бросок остаётся."
		return false
	choice.locked = true
	choice.retry_open = false
	choice.lock_reason = _retry_line(choice)
	pending.pop_front()
	white_pending.append(ev)
	return false


func _apply_white_fallout(failure: Dictionary) -> void:
	if bool(failure.get("vents", false)):
		vent_cut = 2
	if bool(failure.get("gen_down", false)):
		gen_down = true


func _apply_red_failure(failure: Dictionary) -> void:
	var copy: Dictionary = failure.duplicate()
	if int(copy.get("people", 0)) < 0:
		if int(stats.get("red_kills", 0)) >= 1:
			copy.people = 0
		else:
			copy.people = maxi(int(copy.people), -1)
			stats.red_kills = int(stats.get("red_kills", 0)) + 1
	var mold := int(copy.get("mold", 0))
	copy.erase("mold")
	_apply_deltas(copy)
	if mold > 0:
		for room in rooms:
			if str(room.type) == "hydroponics":
				room.mold = mold
				break


func _resolve_bet(choice: Dictionary) -> void:
	var bet: Dictionary = choice.get("bet", {})
	var d1 := check_rng.randi_range(1, 6)
	var d2 := check_rng.randi_range(1, 6)
	var win := d1 + d2 >= int(bet.get("target", 7))
	last_check = {"bet": true, "d1": d1, "d2": d2, "success": win, "box": d1 == 6 and d2 == 6, "snake": d1 == 1 and d2 == 1}
	if win:
		stock.tokens = int(stock.tokens) + int(bet.get("win", 0))
		if Copy.ru():
			_log("СТАВКА %d+%d. Выигрыш: %d жетонов." % [d1, d2, int(bet.get("win", 0))], true)
		else:
			_log("BET %d+%d wins %d tokens." % [d1, d2, int(bet.get("win", 0))], true)
	elif Copy.ru():
		_log("СТАВКА %d+%d. Ставка сгорела." % [d1, d2], true)
	else:
		_log("BET %d+%d loses the stake." % [d1, d2], true)


func _note_check(color: String, success: bool, retried: bool) -> void:
	var roll_key := "check_red_rolls" if color == "red" else "check_white_rolls"
	var win_key := "check_red_success" if color == "red" else "check_white_success"
	stats[roll_key] = int(stats.get(roll_key, 0)) + 1
	if success:
		stats[win_key] = int(stats.get(win_key, 0)) + 1
	if retried:
		stats.check_retried = int(stats.get("check_retried", 0)) + 1
		if success:
			stats.check_retry_passed = int(stats.get("check_retry_passed", 0)) + 1


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
	if choice.is_empty() or choice_locked(choice) or not choice_offered(choice) or not _afford(choice.get("cost", {})):
		return false
	_pay(choice.get("cost", {}))
	var keep := true
	if choice.has("check"):
		keep = _resolve_check(ev, choice, str(action.get("person", "")))
	elif choice.has("bet"):
		_resolve_bet(choice)
	else:
		_apply_deltas(choice)
		_apply_standing_choice(ev, choice)
	decisions += 1
	if not keep:
		return true
	if bool(choice.get("crunch_suffer", false)):
		var drops: Array = stats.get("crunch_drops", [])
		drops.append(str(ev.title))
		stats["crunch_drops"] = drops
	pending.pop_front()
	_schedule_follow(ev, choice)
	_log("EVENT %s: %s" % [line_of(ev, "title"), line_of(choice, "label")], bool(ev.get("major", false)))
	return true


## Choice effect "standing": {faction: delta} moves that leader's regard (clamped -100..100). The leader
## remembers the event as a deed, and the journal gets a "regard" row with the change that actually happened.
func _apply_standing_choice(ev: Dictionary, choice: Dictionary) -> void:
	var shifts = choice.get("standing", {})
	if not (shifts is Dictionary):
		return
	_init_standing()
	for fid in shifts:
		var key := str(fid)
		if not standing.has(key):
			continue
		var was := int(standing[key])
		_add_standing(key, int(shifts[fid]), {"deed": "event", "event": str(ev.id), "choice": str(choice.id)})
		var moved := int(standing[key]) - was
		if moved == 0:
			continue
		_journal("regard", {"faction": key, "delta": moved, "event_id": str(ev.id)})
		_log("STANDING %s %s" % [key, "+%d" % moved if moved >= 0 else str(moved)], true)


func _apply_effect_block(effects: Dictionary, person_id: String, red: bool, host: Dictionary) -> void:
	if effects.is_empty():
		return
	var copy: Dictionary = effects.duplicate(true)
	if copy.has("food_pct"):
		var pct := int(copy.food_pct)
		var delta := int(round(float(stock.food) * float(pct) / 100.0))
		copy.food = int(copy.get("food", 0)) + delta
		copy.erase("food_pct")
	_cap_vent_air(host, copy)
	var lost := int(copy.get("residents_lost", 0))
	copy.erase("residents_lost")
	if red and lost > 0:
		if int(stats.get("red_kills", 0)) >= 1:
			lost = 0
		else:
			lost = 1
			stats.red_kills = int(stats.get("red_kills", 0)) + 1
	var hurt := int(copy.get("injured", 0))
	copy.erase("injured")
	var shut = copy.get("room_disabled", {})
	copy.erase("room_disabled")
	var browned := copy.has("brownout")
	var brown_on := bool(copy.get("brownout", false))
	copy.erase("brownout")
	var relation = copy.get("relation", {})
	copy.erase("relation")
	var flag := str(copy.get("flag", ""))
	copy.erase("flag")
	copy.erase("text")
	_apply_deltas(copy)
	if lost > 0:
		_shed(lost)
		_log("LOST %d" % lost, true)
	if hurt > 0:
		_injure(hurt, person_id)
	if shut is Dictionary and not shut.is_empty():
		_disable_room(str(shut.get("type", "")), int(shut.get("weeks", 0)))
	if browned:
		gen_down = brown_on
	if relation is Dictionary:
		for fid in relation:
			relations[str(fid)] = int(relations.get(str(fid), 0)) + int(relation[fid])
			var signed := "+%d" % int(relation[fid]) if int(relation[fid]) >= 0 else str(int(relation[fid]))
			_log("RELATION %s %s" % [str(fid), signed], true)
	if flag != "":
		flags[flag] = true
		_log("FLAG %s" % flag, true)


func _injure(n: int, first_id: String) -> void:
	var picked: Array = []
	if people.has(first_id):
		picked.append(first_id)
	for person in residents:
		if picked.size() >= n:
			break
		var id := str(person.id)
		if picked.has(id) or int(person.get("absent", 0)) > 0:
			continue
		picked.append(id)
	for id in picked:
		people[id].absent = maxi(int(people[id].absent), 2)
		_unassign(str(id))
	if not picked.is_empty():
		_log("INJURED %d" % picked.size(), true)


func _cap_vent_air(host: Dictionary, copy: Dictionary) -> void:
	if not copy.has("air") or int(copy.air) >= 0:
		return
	var used := int(host.get("vent_weeks", 0))
	if used >= 2:
		copy.erase("air")
		return
	host.vent_weeks = used + 1
	vent_cut = mini(2, vent_cut)


func use_medkits() -> bool:
	if not bool(flags.get("medkits", false)) or medkit_targets() <= 0:
		return false
	var healed := 0
	for person in residents:
		if healed >= 2:
			break
		if int(person.get("absent", 0)) > 0:
			person.absent = 0
			healed += 1
	for person in residents:
		if healed >= 2:
			break
		if int(person.get("sick", 0)) > 0:
			person.sick = 0
			healed += 1
	flags.erase("medkits")
	decisions += 1
	_note("Medkits. %d back on the job." % healed, "Аптечки. Снова в строю: %d." % healed)
	return true


func medkit_targets() -> int:
	var n := 0
	for person in residents:
		if int(person.get("absent", 0)) > 0 or int(person.get("sick", 0)) > 0:
			n += 1
	return n


func _disable_room(type: String, weeks: int) -> void:
	if type == "" or weeks <= 0:
		return
	weeks = mini(2, weeks)
	for room in rooms:
		if str(room.type) != type:
			continue
		room.disabled = maxi(int(room.get("disabled", 0)), weeks)
		_log("DISABLED %s %d" % [type, int(room.disabled)], true)
		return


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
	_apply_story_effects(choice)


## Story effects (docs/briefs/cursor_story_engine.txt): "artifacts" {papers|iron|words: n}, "fragment" (learned
## the choice's "how" way, "found" by default) and "flag" (set for "needs" to read).
func _apply_story_effects(choice: Dictionary) -> void:
	var found = choice.get("artifacts", {})
	if found is Dictionary:
		for key in found:
			if not ARTIFACTS.has(str(key)) or int(found[key]) == 0:
				continue
			artifacts[str(key)] = maxi(0, int(artifacts.get(str(key), 0)) + int(found[key]))
			_log("ARTIFACT %s %+d" % [str(key), int(found[key])], true)
	if choice.has("fragment"):
		know_fragment(str(choice.fragment), str(choice.get("how", "found")))
	var flag := str(choice.get("flag", ""))
	if flag != "":
		flags[flag] = true
		_log("FLAG %s" % flag, true)
	if int(choice.get("proof", 0)) > 0:
		proof_extra += int(choice.proof)
		_journal("proof", {"amount": int(choice.proof)})
	var ending := str(choice.get("ending", ""))
	if ending != "" and over == "":
		over = ending
		stats.pop40 = residents.size()
		_journal("ending", {"ending": ending})
		_log("ENDING %s" % ending, true)


## The run's ending: the story endings set by a choice keep their id, and the old game over reasons map to
## theirs (time -> winter). "" while the run goes on.
const STORY_ENDINGS := ["open_door", "exodus", "order"]
const OVER_ENDINGS := {"time": "winter", "collapse": "collapse", "hope": "hope", "revolt": "revolt", "capital": "capital"}
const ENDINGS := ["open_door", "exodus", "order", "winter", "collapse", "hope", "revolt", "capital"]


func ending_id() -> String:
	if STORY_ENDINGS.has(over):
		return over
	return str(OVER_ENDINGS.get(over, ""))


## The ending's "title" or "text" from data/endings.json in the current language.
func ending_text(id: String, key: String) -> String:
	return _pair_text(catalog.endings.get("endings", {}).get(id, {}).get(key, {}))


## The epilogue line for a leader by the recorded answer: accepted, refused (or silence), helped, none.
func leader_epilogue_state(fid: String) -> String:
	var answer := str(leader_answers.get(fid, {}).get("answer", ""))
	match answer:
		"accepted":
			return "accepted"
		"refused", "silence":
			return "refused"
		"helped":
			return "helped"
	return "none"


func leader_epilogue(fid: String) -> String:
	return _pair_text(catalog.endings.get("leaders", {}).get(fid, {}).get(leader_epilogue_state(fid), {}))


## proof with 3 or more proofs, some with any fragment known, none otherwise.
func truth_state() -> String:
	if proofs() >= 3:
		return "proof"
	for id in fragments:
		if fragment_known(str(id)):
			return "some"
	return "none"


func truth_epilogue() -> String:
	return _pair_text(catalog.endings.get("truth", {}).get(truth_state(), {}))


func _pair_text(pair) -> String:
	if not (pair is Dictionary):
		return ""
	var out := str(pair.get("ru", "")) if Copy.ru() else ""
	return out if out != "" else str(pair.get("en", ""))


## Leader deals taken and turned away over the run, from the journal (silence counts as turned away).
func deals_tally() -> Dictionary:
	var made := 0
	var refused := 0
	for row in journal:
		if str(row.get("kind", "")) != "audience":
			continue
		match str(row.get("result", "")):
			"deal":
				made += 1
			"refused", "silence":
				refused += 1
	return {"made": made, "refused": refused}


const FRAGMENTS := {
	"depot_order": "depot", "directorate_ledger": "directorate", "synod_recording": "synod",
	"exchange_papers": "exchange", "quarantine_path": "black_flag",
}
const FRAGMENT_HOWS := ["honest", "dirty", "found"]
const ARTIFACTS := ["papers", "iron", "words"]
const STORY_WORDS_EVERY := 3


## Learns a truth fragment once: a "truth" journal row and a line in the next dawn report. Returns false when
## the id is unknown or the fragment is already known; the first way it was learned stays.
func know_fragment(id: String, how: String = "found") -> bool:
	if not FRAGMENTS.has(id) or fragment_known(id):
		return false
	if not FRAGMENT_HOWS.has(how):
		how = "found"
	fragments[id] = {"known": true, "how": how, "week": week}
	_journal("truth", {"id": id, "how": how})
	var title := fragment_text(id, "title")
	_note("TRUTH Learned: %s." % title, "TRUTH Узнано: %s." % title)
	return true


func fragment_known(id: String) -> bool:
	var row = fragments.get(id, null)
	return row is Dictionary and bool(row.get("known", false))


## Proofs the endings weigh: fragments learned the honest way plus proofs gained in bunker scenes.
func proofs() -> int:
	return honest_fragments() + proof_extra


func honest_fragments() -> int:
	var n := 0
	for id in fragments:
		if fragment_known(str(id)) and str(fragments[id].get("how", "")) == "honest":
			n += 1
	return n


## A fragment's "title", "hint" or "text" from data/truth.json in the current language, "" when unwritten.
func fragment_text(id: String, key: String) -> String:
	var pair = catalog.truth.get(id, {}).get(key, {})
	if not (pair is Dictionary):
		return str(pair) if pair != null else ""
	var out := str(pair.get("ru", "")) if Copy.ru() else ""
	return out if out != "" else str(pair.get("en", ""))


## A resident's recorded story played to the end. Every STORY_WORDS_EVERY distinct stories heard (vo_heard
## true, any language) grant one Words artifact, each threshold once. Returns how many were granted now.
func hear_story(id: String) -> int:
	if id == "":
		return 0
	vo_heard[id] = true
	var due := stories_heard() / STORY_WORDS_EVERY
	var granted := 0
	while story_words < due:
		story_words += 1
		granted += 1
		artifacts.words = int(artifacts.get("words", 0)) + 1
		_journal("testimony", {"stories": story_words * STORY_WORDS_EVERY})
		_note("TESTIMONY Gathered from the stories heard: Words +1.", "TESTIMONY Собрано из услышанных историй: «Слова» +1.")
	return granted


## Distinct resident stories heard to the end this run.
func stories_heard() -> int:
	var n := 0
	for row in Voice.of_type("story"):
		var mark = vo_heard.get(str(row.get("id", "")), null)
		if mark is bool and mark:
			n += 1
	return n


## Stories still to hear before the next Words artifact.
func stories_to_testimony() -> int:
	return maxi(1, (story_words + 1) * STORY_WORDS_EVERY - stories_heard())


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
	var state := str(tunnel.get("state", ""))
	if state == "":
		state = "sealed" if bool(tunnel.get("sealed", false)) else "open"
	if state == "sealed" and not bool(tunnel.get("dug", false)):
		return false
	if state == "collapsed" and not bool(tunnel.get("dug", false)):
		return false
	if int(tunnel.get("closed_until", 0)) > week:
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


func _supply_hops(sid: String) -> int:
	if sid == capital_id:
		return 0
	var queue: Array = [capital_id]
	var dist := {capital_id: 0}
	var qi := 0
	while qi < queue.size():
		var cur: String = queue[qi]
		qi += 1
		for n in _neighbors(cur):
			if dist.has(n):
				continue
			if not _supplies(str(n)):
				continue
			dist[n] = int(dist[cur]) + 1
			if str(n) == sid:
				return int(dist[n])
			queue.append(n)
	return 999


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
			if not _supplies(str(n)):
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
			var soon := "SEASON warning %s" % str(season.id)
			if Copy.ru():
				soon = "SEASON Скоро %s." % Copy.season(str(season.id))
			_log(soon, true)
			_journal("season", {"id": str(season.id), "soon": true})
			_vo_cue("season_%s_soon" % str(season.id))
			if str(season.id) == "flood":
				_vo_cue("tunnel_warning")
		if week == at:
			active_season = {"id": str(season.id), "start": at, "until": at + int(season.weeks) - 1}
			var begun := "SEASON %s" % str(season.id)
			if Copy.ru():
				begun = "SEASON Начался %s." % Copy.season(str(season.id))
			_log(begun, true)
			_journal("season", {"id": str(season.id)})
			_vo_cue("season_%s" % str(season.id))
			if str(season.id) == "cough":
				_infect(int(bal.cough_infect))
	if not active_season.is_empty() and week > int(active_season.until):
		active_season = {}
	if flood_guard and _flood_eta() > int(bal.get("season_warning", 2)):
		flood_guard = false


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


func has_radio_room() -> bool:
	for room in rooms:
		if room.type == "radio":
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
		_stamp_checks(person)
		residents.append(person)
		people[str(person.id)] = person
		if str(person.get("council", "")) != "":
			council.append({"role": str(person.council), "id": str(person.id), "loyalty": 80})
	_apply_coney_cast()


const CONEY_SLOTS := ["chris", "mina", "kim", "drew", "ann"]


func _apply_coney_cast() -> void:
	if capital_id != "southdepot" and capital_id != "coney":
		return
	var rows: Array = catalog.coney.get("characters", [])
	var n := mini(rows.size(), CONEY_SLOTS.size())
	for i in n:
		var id := str(CONEY_SLOTS[i])
		if not people.has(id):
			continue
		var person: Dictionary = people[id]
		var row: Dictionary = rows[i]
		var name: Dictionary = row.get("name", {})
		person.name = str(name.get("en", person.name))
		person.name_ru = str(name.get("ru", ""))
		person.cast_id = str(row.get("id", ""))
		person.core = true
		var skills: Dictionary = row.get("skills", {})
		person.checks = {
			"grit": clampi(int(skills.get("grit", 0)), 0, 3),
			"wits": clampi(int(skills.get("wits", 0)), 0, 3),
			"voice": clampi(int(skills.get("voice", 0)), 0, 3),
			"senses": clampi(int(skills.get("senses", 0)), 0, 3),
		}
		person.dossier = {
			"title": row.get("title", {}),
			"look": row.get("look", {}),
			"bio": row.get("bio", {}),
			"hook": row.get("hook", {}),
		}


## Backstory key for a resident. Saves from before cast_id fall back to the Coney slot order.
func cast_id_of(person: Dictionary) -> String:
	if str(person.get("cast_id", "")) != "":
		return str(person.cast_id)
	var slot := CONEY_SLOTS.find(str(person.get("id", "")))
	var rows: Array = catalog.coney.get("characters", [])
	if person.has("dossier") and slot >= 0 and slot < rows.size():
		return str(rows[slot].get("id", ""))
	return str(person.get("id", ""))


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


func _ideology(tag: String) -> String:
	match tag:
		"depot":
			return "craft"
		"exchange":
			return "trade"
		"dir":
			return "order"
		"synod":
			return "faith"
		_:
			return ""


func _lean_for(sid: String, ideo: String, old: Dictionary) -> String:
	if ideo != "":
		return ideo
	if str(old.get("lean", "")) != "":
		return str(old.lean)
	var cycle := ["order", "faith", "trade", "craft"]
	return cycle[absi(sid.hash()) % cycle.size()]


func _default_needs(ideo: String) -> Array:
	match ideo:
		"craft":
			return ["food", "air", "work"]
		"trade":
			return ["trade", "food", "protection"]
		"order":
			return ["protection", "work", "food"]
		"faith":
			return ["faith", "air", "medicine"]
		_:
			return ["food", "air", "protection"]


func _opening_owner(sid: String, row: Dictionary) -> String:
	if sid == "vault":
		return "ruin"
	var tag := str(row.lean)
	if bool(row.get("hidden", false)) or tag == "bunker":
		return "bunker"
	if tag == "enemy":
		return "enemy"
	if bool(row.get("capital", false)):
		match tag:
			"depot":
				return "depot"
			"exchange":
				return "exchange"
			"dir":
				return "directorate"
			"synod":
				return "synod"
	if tag == "synod":
		return "synod"
	if sid == "dockyard":
		return "directorate"
	return "neutral"


func _add_tunnel(a: String, b: String, state: String, line_id: String, seen: Dictionary) -> void:
	if a == "" or b == "" or a == b:
		return
	var key := a + "|" + b if a < b else b + "|" + a
	if seen.has(key):
		return
	seen[key] = true
	var sealed := state == "sealed"
	tunnels.append({
		"id": "%s_%s" % [a, b],
		"a": a,
		"b": b,
		"line": line_id,
		"state": state,
		"sealed": sealed,
		"dug": not sealed and state != "collapsed",
		"flooded": state == "flooded",
		"closed_until": 0,
	})


func _mark_tunnel(a: String, b: String, state: String) -> void:
	var tunnel := _edge(a, b)
	if tunnel.is_empty():
		return
	tunnel.state = state
	tunnel.flooded = state == "flooded"
	tunnel.sealed = state == "sealed"
	tunnel.dug = state != "sealed" and state != "collapsed"


func _supplies(sid: String) -> bool:
	if sid == capital_id:
		return true
	if not stations.has(sid):
		return false
	var st: Dictionary = stations[sid]
	var owner := str(st.owner)
	if owner == player:
		return true
	if bool(st.get("passage", false)):
		return true
	if trade_on and owner == "exchange":
		return true
	return false


func _border_neutrals(fid: String) -> Array:
	var rows: Array = []
	if squads.has(fid):
		rows = _neutral_neighbors(str(squads[fid].station))
	if rows.size() < 2:
		rows = []
		var seen := {}
		for sid in _owned_by(fid):
			for n in _neutral_neighbors(str(sid)):
				if seen.has(n):
					continue
				seen[n] = true
				rows.append(str(n))
	rows.sort_custom(func(a, b):
		var ha := _hops(str(a), capital_id)
		var hb := _hops(str(b), capital_id)
		if ha == hb:
			return str(a) < str(b)
		return ha < hb
	)
	if rows.size() > 3:
		rows.resize(3)
	return rows


func _neutral_neighbors(sid: String) -> Array:
	var rows: Array = []
	for n in _neighbors(sid):
		var st: Dictionary = stations[n]
		if str(st.owner) != "neutral":
			continue
		if str(st.get("bunker", "")) != "":
			continue
		rows.append(str(n))
	return rows


func _weighted_border(rows: Array) -> String:
	if rows.is_empty():
		return ""
	var roll := (seed * 5 + 3) % (rows.size() + 1)
	if roll >= rows.size():
		roll = 0
	return str(rows[roll])


func _note_flip(sid: String, prev: String, nxt: String) -> void:
	if int(stats.get("flip_week", 0)) == 0:
		stats.flip_week = week
		stats.flip_sid = sid
		stats.flip_name = str(stations[sid].name) if stations.has(sid) else sid
		stats.flip_from = prev
		stats.flip_to = nxt


func _courting_rival() -> String:
	var best := ""
	var best_n := -999
	for fid in ["exchange", "directorate"]:
		var n := int(ambition.get(fid, 0))
		if n > best_n:
			best_n = n
			best = fid
	return best


func _suitor(st: Dictionary) -> String:
	var best := ""
	var best_n := 20
	for fid in ["exchange", "directorate", "synod"]:
		var n := int(st.rival_symp.get(fid, 0))
		if n > best_n:
			best_n = n
			best = fid
	return best


func _synod_preach() -> void:
	if not catalog.factions.has("synod"):
		return
	var cap := str(catalog.factions.synod.capital)
	var best := ""
	var best_hops := 99
	for sid in stations:
		var st: Dictionary = stations[sid]
		if str(st.owner) != "neutral" or bool(st.get("hidden", false)):
			continue
		var hops := _hops(str(sid), cap)
		if hops > 2 or hops >= best_hops:
			continue
		best_hops = hops
		best = str(sid)
	if best == "":
		return
	var st: Dictionary = stations[best]
	st.rival_symp.synod = int(st.rival_symp.synod) + 6 + net_rng.randi_range(0, 8)
	_press_loyalty(st)
	st.known = true
	_log("PREACH The Synod speaks at %s" % st.name, true)
	if int(st.rival_symp.synod) >= 100:
		_capture(best, "synod", false)


const STATION_TEXT := ["community", "who", "conflict", "art"]


## Community, who, conflict or art for the current language. Russian comes from data/station_communities.json
## (then the station itself, for saves from before a station was in the file); English from
## station_communities_en.json, falling back to the Russian line when the English one is missing.
func station_text(sid: String, field: String) -> String:
	var ru := str(catalog.communities.get("stations", {}).get(sid, {}).get(field, ""))
	if ru == "":
		ru = str(stations.get(sid, {}).get(field, ""))
	if Copy.ru():
		return ru
	var en := str(catalog.communities_en.get("stations", {}).get(sid, {}).get(field, ""))
	return en if en != "" else ru


func _init_map() -> void:
	var legacy := {}
	for raw in catalog.stations:
		legacy[str(raw.name)] = raw
	var pack: Dictionary = catalog.communities
	var rows: Dictionary = pack.get("stations", {})
	for sid in rows:
		var row: Dictionary = rows[sid]
		var old: Dictionary = legacy.get(str(row.name), {})
		var ideo := _ideology(str(row.lean))
		var owner := _opening_owner(str(sid), row)
		var need_ids: Array = old.get("needs", _default_needs(ideo))
		var needs: Array = []
		for need in need_ids:
			needs.append({"id": str(need), "fill": 0.4})
		var pop := int(old.get("pop", 40 if owner != "ruin" else 0))
		var garrison := int(old.get("garrison", 0 if owner == "ruin" else 10))
		stations[str(sid)] = {
			"id": str(sid),
			"name": str(row.name),
			"full": str(old.get("full", row.name)),
			"desc": str(old.get("desc", row.get("art", ""))),
			"community": str(row.community),
			"who": str(row.who),
			"conflict": str(row.conflict),
			"art": str(row.art),
			"lat": float(row.lat),
			"lon": float(row.lon),
			"owner": owner,
			"lean": _lean_for(str(sid), ideo, old),
			"pop": pop,
			"garrison": garrison,
			"fort": float(old.get("fort", 1.25 if bool(row.get("capital", false)) else 1.0)),
			"needs": needs,
			"capital": bool(row.get("capital", false)),
			"hidden": bool(row.get("hidden", false)),
			"bunker": "floor" if str(sid) == "archive" else "",
			"ruin": str(sid) == "vault",
			"sympathy": 0,
			"loyalty": 78 if owner != "ruin" else 40,
			"unrest": 0,
			"focus": "",
			"deals": 0,
			"passage": false,
			"known": false,
			"held_weeks": 0,
			"low_weeks": 0,
			"rival_symp": {"exchange": 0, "directorate": 0, "synod": 0},
		}
	var seen := {}
	for line_id in pack.get("lines", {}):
		var stops: Array = pack.lines[line_id]
		for i in range(stops.size() - 1):
			_add_tunnel(str(stops[i]), str(stops[i + 1]), "open", str(line_id), seen)
	for pair in pack.get("sealed", []):
		if pair is Array and pair.size() >= 2:
			_add_tunnel(str(pair[0]), str(pair[1]), "sealed", "", seen)
	_mark_tunnel("mill", "harbor", "flooded")
	_mark_tunnel("library", "observatory", "collapsed")
	var ferry := _edge("eastwater", "vault")
	if not ferry.is_empty():
		ferry.id = "to_ferry"
		ferry.state = "sealed"
		ferry.sealed = true
		ferry.dug = false
	var floor_tunnel := _edge("dockyard", "archive")
	if not floor_tunnel.is_empty():
		floor_tunnel.id = "to_floor"
		floor_tunnel.state = "sealed"
		floor_tunnel.sealed = true
		floor_tunnel.dug = false
	for fid in ["exchange", "directorate", "synod"]:
		if not catalog.factions.has(fid):
			continue
		var fac: Dictionary = catalog.factions[fid]
		opinions[fid] = int(fac.opinion)
		ambition[fid] = int(fac.ambition)
		at_war[fid] = false
	if stations.has(capital_id):
		stations[capital_id].known = true
		stations[capital_id].owner = player
		for n in _neighbors(capital_id):
			stations[str(n)].known = true
	for fid in ["exchange", "directorate", "synod"]:
		if not catalog.factions.has(fid):
			continue
		var cap := str(catalog.factions[fid].capital)
		if stations.has(cap):
			stations[cap].known = true


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
		"upgrade": 0, "efficiency": 1.0, "staff": [], "offline": false, "browned": false, "disabled": 0,
		"switched_off": false,
	}
	rooms.append(room)
	cells[_ck(level, cell)].room = uid
	_insert_power(uid, type)


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
		var have := int(artifacts.get(key, 0)) if ARTIFACTS.has(str(key)) else int(stock.get(key, 0))
		if have < int(cost[key]):
			return false
	return true


func _pay(cost) -> void:
	if not (cost is Dictionary):
		return
	for key in cost:
		if ARTIFACTS.has(str(key)):
			artifacts[str(key)] = int(artifacts.get(str(key), 0)) - int(cost[key])
		else:
			stock[key] = int(stock.get(key, 0)) - int(cost[key])


func _add_opinion(fid: String, amount: int, why: String = "") -> void:
	if not opinions.has(fid) or fid == "synod":
		return
	opinions[fid] = clampi(int(opinions[fid]) + amount, -100, 100)
	if not opinion_memory.has(fid):
		opinion_memory[fid] = []
	var note := why if why != "" else "shift"
	opinion_memory[fid].append({"week": week, "delta": amount, "why": note})
	if opinion_memory[fid].size() > 8:
		opinion_memory[fid].pop_front()


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
			return Copy.t("%s squad moving to %s") % [Copy.t(fid), Copy.t(station_name)]
		"buy":
			return Copy.t("%s will buy sympathy at %s") % [Copy.t(fid), Copy.t(station_name)]
		"secure":
			return Copy.t("%s is securing %s") % [Copy.t(fid), Copy.t(station_name)]
		"demand_posted":
			return Copy.t("%s will demand tokens") % Copy.t(fid)
		_:
			return Copy.t("%s holds") % Copy.t(fid)


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


func _weighted(pool: Array, stream: RandomNumberGenerator = null) -> Dictionary:
	var total := 0
	for ev in pool:
		total += int(ev.get("weight", 1))
	if total <= 0:
		return pool[0]
	var roll := (stream if stream != null else rng).randi_range(1, total)
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


## Rooms a deal raises by one tier for free, and laws it puts in force; the deal text in faction_leaders.json names them.
const DEAL_ROOM := {"burn_papers": "workshop", "the_list": "air_filter"}
const DEAL_LAW := {"the_list": "curfew"}


## Mechanics only (data/faction_leaders.json); every word a leader shows comes from data/leader_lines.json.
func leader(fid: String) -> Dictionary:
	for row in catalog.leaders.get("factions", []):
		if str(row.get("id", "")) == fid:
			return row
	return {}


## The faction "name", the "leader" or their "title" as {en, ru}, from data/leader_lines.json.
func leader_name(fid: String, key: String) -> Dictionary:
	return catalog.lines.get("factions", {}).get(fid, {}).get(key, {})


## One {en, ru} line from data/leader_lines.json; "bands" takes the band name. A missing, empty or
## unwritten line falls back to first_contact, and to {} only when that is missing too.
func leader_line(fid: String, key: String, band: String = "") -> Dictionary:
	var row: Dictionary = catalog.lines.get("factions", {}).get(fid, {})
	var pair = row.get("bands", {}).get(band, {}) if key == "bands" else row.get(key, {})
	if not line_written(pair):
		pair = row.get("first_contact", {})
	return pair if line_written(pair) else {}


static func line_written(pair) -> bool:
	if not pair is Dictionary:
		return false
	var en := str(pair.get("en", "")).strip_edges()
	return en != "" and en != "TODO_REWRITE"


## First meeting gets first_contact; after that the line for the leader's current regard band.
func audience_opening(fid: String) -> Dictionary:
	if not audience_last.has(fid):
		return leader_line(fid, "first_contact")
	return leader_line(fid, "bands", standing_band(fid))


## Which line audience_opening shows, as a voice key: "first_contact" or "band_<band>".
func audience_opening_key(fid: String) -> String:
	if audience_last.has(fid):
		var band := standing_band(fid)
		if line_written(catalog.lines.get("factions", {}).get(fid, {}).get("bands", {}).get(band, {})):
			return "band_" + band
	return "first_contact"


## A territory or trade line for the order report, at most once per faction every LEADER_LINE_GAP weeks.
## Flavour only: the week it was last shown sits in flags under "line_<faction>".
const LEADER_LINE_GAP := 4

func _leader_flavour(kind: String, fid: String) -> Dictionary:
	if fid == "" or fid == player or leader(fid).is_empty():
		return {}
	var key := "line_" + fid
	if flags.has(key) and week - int(flags[key]) < LEADER_LINE_GAP:
		return {}
	var pair := leader_line(fid, kind)
	if pair.is_empty():
		return {}
	flags[key] = week
	return {"faction": fid, "line": pair, "line_key": kind}


func _init_standing() -> void:
	for row in catalog.leaders.get("factions", []):
		var fid := str(row.get("id", ""))
		if not standing.has(fid):
			standing[fid] = clampi(int(row.get("start_opinion", 0)), -100, 100)
		if not standing_memory.has(fid):
			standing_memory[fid] = []


func standing_band(fid: String) -> String:
	var value := int(standing.get(fid, 0))
	for band in catalog.leaders.get("opinion_bands", []):
		if value >= int(band.min) and value <= int(band.max):
			return str(band.id)
	return ""


func _add_standing(fid: String, amount: int, deed: Dictionary) -> void:
	if not standing.has(fid) or amount == 0:
		return
	standing[fid] = clampi(int(standing[fid]) + amount, -100, 100)
	_remember(fid, deed)


func _remember(fid: String, deed: Dictionary) -> void:
	var rows: Array = standing_memory.get(fid, [])
	var row := deed.duplicate()
	row["week"] = week
	rows.append(row)
	var slots := int(catalog.leaders.memory_slots)
	if rows.size() > slots:
		rows = rows.slice(rows.size() - slots)
	standing_memory[fid] = rows


## Arrival rules read "<a>_or_<b>"; "week_N" takes N from the data.
func _arrived(rule: String) -> bool:
	for part in rule.split("_or_"):
		var key := str(part)
		if key.begins_with("week_"):
			if week >= key.trim_prefix("week_").to_int():
				return true
			continue
		match key:
			"radio_built":
				if _has_radio():
					return true
			"directorate_intent":
				for intent in telegraphed:
					if str(intent.get("faction", "")) != "directorate" or str(intent.get("kind", "")) != "squad" or bool(intent.get("hidden", false)):
						continue
					var sid := str(intent.get("station", ""))
					if stations.has(sid) and (str(stations[sid].owner) == player or borders_player(sid)):
						return true
			"food_critical":
				if food_buffer_weeks() < 1.0:
					return true
			"first_season":
				if not active_season.is_empty():
					return true
			"first_caravan", "first_sealed_tunnel":
				if flags.has(key):
					return true
	return false


## A leader left waiting a week counts as turned away. Then at most one leader comes per dawn, chosen among
## those who have arrived, have no deal done and are out of cooldown (hostile and pact leaders have none).
## Least recently seen goes first: never seen before anyone seen, then the oldest audience_last; ties go to
## the earlier arrival, then to the order in faction_leaders.json. A refused or silent leader is requeued
## behind everyone waiting, so a repeater cannot keep the door from the others.
func _audience_dawn() -> void:
	if catalog.leaders.is_empty():
		return
	_init_standing()
	if not audience.is_empty():
		_audience_refuse("silence")
	for row in catalog.leaders.get("factions", []):
		var fid := str(row.get("id", ""))
		if not audience_due.has(fid) and _arrived(str(row.get("arrival", ""))):
			audience_due[fid] = week
	var best := ""
	var best_key: Array = []
	for row in catalog.leaders.get("factions", []):
		var fid := str(row.get("id", ""))
		if not audience_eligible(fid):
			continue
		var key := [int(audience_last.get(fid, -1)), int(audience_due[fid])]
		if best == "" or key < best_key:
			best = fid
			best_key = key
	if best == "":
		return
	var target := ""
	if str(leader(best).get("dirty_deal", {}).get("id", "")) == "the_list":
		target = list_target()
	audience = {"faction": best, "week": week, "target": target}


## Arrived, deal not done, and either never seen, out of the cooldown, or hostile or pact.
func audience_eligible(fid: String) -> bool:
	if not audience_due.has(fid) or audience_deals.has(fid):
		return false
	var band := standing_band(fid)
	if band == "hostile" or band == "pact" or not audience_last.has(fid):
		return true
	return week - int(audience_last[fid]) >= int(catalog.leaders.audience_cooldown_weeks)


## Who the Directorate's list would name: the least skilled resident outside the council.
func list_target() -> String:
	var pick := ""
	var low := 1 << 30
	for person in residents:
		var id := str(person.id)
		if _is_council(id):
			continue
		var total := _skill_total(person)
		if total < low:
			low = total
			pick = id
	return pick


func audience_reason() -> String:
	if audience.is_empty():
		return Copy.t("Nobody is waiting.")
	var deal: Dictionary = leader(str(audience.faction)).get("dirty_deal", {})
	if str(deal.get("id", "")) == "the_list" and not people.has(str(audience.get("target", ""))):
		return Copy.t("There is nobody to hand over.")
	var food := int(deal.get("food", 0))
	if food < 0 and int(stock.food) < -food:
		return Copy.t("Needs %s, the stores have %s.") % [Copy.stock(-food, "food"), Copy.stock(int(stock.food), "food")]
	return ""


func _audience_refuse(how: String) -> void:
	var fid := str(audience.get("faction", ""))
	_record_answer(fid, how)
	audience_last[fid] = week
	_remember(fid, {"deed": how})
	_journal("audience", {"faction": fid, "result": how})
	audience = {}


## The week is the audience's own: a leader left waiting is counted at the next dawn but was answered by
## silence the week they came.
## "helped" answers no deal: the first answer to the deal itself, coming later, takes its place.
func _record_answer(fid: String, answer: String) -> void:
	if fid == "":
		return
	if leader_answers.has(fid) and not (str(leader_answers[fid].get("answer", "")) == "helped" and answer != "helped"):
		return
	leader_answers[fid] = {"answer": answer, "week": int(audience.get("week", week))}


## The leader at the door's honest favour from faction_leaders.json: {resource, amount, standing}, or {}.
func help_terms() -> Dictionary:
	if audience.is_empty():
		return {}
	var help = leader(str(audience.faction)).get("help", {})
	if not (help is Dictionary) or not stock.has(str(help.get("resource", ""))):
		return {}
	return help


## What offering help changes this turn: the stock it takes and the regard it gives, already clamped.
func help_effects() -> Dictionary:
	var help := help_terms()
	if help.is_empty():
		return {}
	var fid := str(audience.faction)
	var now := int(standing.get(fid, 0))
	return {"resource": str(help.resource), "amount": int(help.amount),
		"standing": clampi(now + int(help.get("standing", 0)), -100, 100) - now}


## Weeks before this leader can be helped again; 0 when help is open. Counts from the last help, in every band.
func help_wait(fid: String) -> int:
	if not help_last.has(fid):
		return 0
	return maxi(0, int(help_last[fid]) + int(catalog.leaders.audience_cooldown_weeks) - week)


## Why help cannot be offered now; "" when it can.
func help_reason() -> String:
	var help := help_terms()
	if help.is_empty():
		return Copy.t("Nobody is waiting.")
	var wait := help_wait(str(audience.faction))
	if wait == 1:
		return Copy.t("You helped recently, 1 week left")
	if wait > 1:
		return Copy.t("You helped recently, %d weeks left") % wait
	var key := str(help.resource)
	if int(stock.get(key, 0)) < int(help.amount):
		return Copy.t("Needs %s, the stores have %s.") % [Copy.stock(int(help.amount), key), Copy.stock(int(stock.get(key, 0)), key)]
	return ""


## The favour line on the card ("offer") or the leader's thanks ("reply") from leader_lines.json.
func help_line(fid: String, part: String) -> Dictionary:
	var pair = catalog.lines.get("factions", {}).get(fid, {}).get("help", {}).get(part, {})
	return pair if line_written(pair) else {}


## Offer help: pay the stock, earn the regard, close the audience with "helped". No deal, no deal flag, no
## consequence events; the leader comes back after the usual cooldown with the deal still on the table.
func _apply_help() -> bool:
	if help_reason() != "":
		return false
	var fid := str(audience.faction)
	var fx := help_effects()
	var key := str(fx.resource)
	stock[key] = int(stock[key]) - int(fx.amount)
	_add_standing(fid, int(help_terms().get("standing", 0)), {"deed": "helped"})
	var spent: Dictionary = stats.get("help_spent", {})
	spent[key] = int(spent.get(key, 0)) + int(fx.amount)
	stats["help_spent"] = spent
	_record_answer(fid, "helped")
	audience_last[fid] = week
	help_last[fid] = week
	_journal("audience", {"faction": fid, "result": "helped", "resource": key, "amount": int(fx.amount), "standing": int(fx.standing)})
	_log("STANDING %s %s" % [fid, "+%d" % int(fx.standing) if int(fx.standing) >= 0 else str(fx.standing)], true)
	audience = {}
	decisions += 1
	return true


func _apply_audience(accept: bool) -> bool:
	if audience.is_empty():
		return false
	if not accept:
		_audience_refuse("refused")
		decisions += 1
		return true
	if audience_reason() != "":
		return false
	var fid := str(audience.faction)
	var deal: Dictionary = leader(fid).get("dirty_deal", {})
	var deal_id := str(deal.get("id", ""))
	var fx := audience_effects()
	var deed := {"deed": deal_id}
	if str(fx.hand_over) != "":
		var person: Dictionary = people[str(fx.hand_over)]
		deed["name"] = str(person.get("name", ""))
		deed["name_ru"] = str(person.get("name_ru", ""))
		_remove_resident(str(fx.hand_over))
		_journal("handed_over", {"faction": fid, "name": deed.name, "name_ru": deed.name_ru})
	if deal_id == "burn_papers":
		if bool(fx.papers):
			artifacts.papers = int(artifacts.papers) - 1
		_journal("papers_burned", {"faction": fid, "destroyed": bool(fx.papers)})
	if bool(fx.toll_lost):
		_journal("false_way", {"faction": fid})
	_add_hope(int(fx.hope), "audience")
	_add_discontent(int(fx.discontent), "audience")
	stock.food = int(stock.food) + int(fx.food)
	for other in fx.standing:
		_add_standing(str(other), int(fx.standing[other]), deed)
	if not fx.tier.is_empty():
		var room = _room(str(fx.tier.uid))
		room.upgrade = int(room.upgrade) + 1
		_log("UPGRADE %s to %s" % [catalog.rooms[room.type].name, str(fx.tier.name)])
	if str(fx.law) != "":
		laws_on[str(fx.law)] = true
	flags[str(fx.flag)] = week
	_journal("audience", {"faction": fid, "result": "deal", "deal": deal_id})
	_record_answer(fid, "accepted")
	audience_deals[fid] = week
	audience_last[fid] = week
	audience = {}
	decisions += 1
	return true


## Everything taking the deal at the door changes this turn, already clamped to the meters, so the card can show
## exactly what will move. Promises in the deal text with no mechanic behind them are not here.
func audience_effects() -> Dictionary:
	var fx := {
		"hope": 0, "discontent": 0, "food": 0, "standing": {}, "hand_over": "", "law": "",
		"tier": {}, "papers": false, "toll_lost": false, "flag": "",
	}
	if audience.is_empty():
		return fx
	var fid := str(audience.faction)
	var deal: Dictionary = leader(fid).get("dirty_deal", {})
	var deal_id := str(deal.get("id", ""))
	fx.flag = str(deal.get("flag", deal_id))
	fx.hope = clampi(hope + int(deal.get("hope", 0)), 0, 100) - hope
	fx.discontent = clampi(discontent + int(deal.get("discontent", 0)), 0, 100) - discontent
	fx.food = maxi(0, int(stock.food) + int(deal.get("food", 0))) - int(stock.food)
	var shifts: Dictionary = deal.get("opinion", {})
	for other in shifts:
		if not standing.has(str(other)):
			continue
		var now := int(standing[other])
		var moved := clampi(now + int(shifts[other]), -100, 100) - now
		if moved != 0:
			fx.standing[str(other)] = moved
	if deal_id == "the_list" and people.has(str(audience.get("target", ""))):
		fx.hand_over = str(audience.target)
	if DEAL_LAW.has(deal_id) and not _law_on(str(DEAL_LAW[deal_id])):
		fx.law = str(DEAL_LAW[deal_id])
	if DEAL_ROOM.has(deal_id):
		var type := str(DEAL_ROOM[deal_id])
		var steps: Array = catalog.rooms[type].get("upgrades", [])
		for room in rooms:
			if str(room.type) == type and int(room.upgrade) < steps.size():
				fx.tier = {"uid": str(room.uid), "type": type, "name": str(steps[int(room.upgrade)])}
				break
	fx.papers = deal_id == "burn_papers" and int(artifacts.papers) > 0
	fx.toll_lost = deal_id == "lantern_toll" and int(standing.get(fid, 0)) < 0
	return fx


const PERSIST := [
	"seed", "week", "max_weeks", "over", "player", "player_lean", "capital_id",
	"stock", "hope", "discontent", "residents", "people", "cells", "rooms",
	"laws_on", "law_lock", "council", "stations", "tunnels", "squads",
	"opinions", "ambition", "at_war", "trade_on", "telegraphed", "demands",
	"pending", "dig", "build", "expedition", "active_season", "artifacts",
	"pumped", "flood_guard", "quarantine", "synod", "floor_met", "orders_left", "decisions",
	"hope_zero", "next_person", "demand_seq", "log", "errors", "stats",
	"food_buffers", "growth_bank", "hope_week", "hope_history", "hope_totals",
	"dis_totals", "hope_samples", "last_net", "last_hope_delta", "last_dis_delta",
	"dis_week", "audit", "rot_week", "crunch_week", "crunch_kind",
	"crunch_power", "belt_down", "workshop_down", "gen_down", "event_last",
	"week_event_ids", "power_order", "event_times", "events_seen", "event_history",
	"follows", "pressure", "warning_weeks", "crisis_faults", "demand_log",
	"power_zero_streak", "rally_lock", "seat_used", "opinion_memory", "queued_orders", "order_reports", "choice_results",
	"check_schedule", "white_pending", "vent_cut", "relations", "flags", "journal",
	"vo_heard", "radio_week", "standing", "standing_memory", "audience", "audience_last",
	"audience_due", "audience_deals", "vo_cues", "leader_answers", "fragments", "story_words", "help_last",
	"story_queue", "proof_extra",
]


## SaveGame stamps files with "schema": SAVE_SCHEMA; such saves must carry every PERSIST key plus all
## RNG_KEYS or they are rejected. Data without "schema" is version 1, the format from before.
## Adding a PERSIST key needs a new schema number and its own migration list.
const SAVE_SCHEMA := 6
const RNG_KEYS := ["rng_state", "crunch_state", "net_state", "check_state", "story_state"]
## Fields a version 1 save may lack. They get the class defaults of a fresh Game, standing gets each
## leader's start_opinion, never anything from the run being replaced.
const V1_ADDED := [
	"flood_guard", "seat_used", "opinion_memory", "queued_orders", "order_reports", "choice_results",
	"check_schedule", "white_pending", "vent_cut", "relations", "flags", "journal", "vo_heard", "radio_week",
	"standing", "standing_memory", "audience", "audience_last", "audience_due", "audience_deals", "vo_cues",
]
## Version 1 saves predate these streams; they restart from the seed the same way setup() seeds them.
const V1_RNG_ADDED := ["net_state", "check_state"]
## Fields a version 1 or 2 save may lack; they start empty like a fresh Game (no answers recorded yet).
const V2_ADDED := ["leader_answers"]
const ANSWERS := ["accepted", "refused", "silence"]
## What leader_answers may hold: the deal answers, or "helped" until the deal itself is answered. Consequence
## events key on ANSWERS only, so "helped" opens none of them.
const SAVED_ANSWERS := ["accepted", "refused", "silence", "helped"]
## Fields a version 1 to 3 save may lack: no fragment known, no testimony granted yet (stories already heard
## count toward the next one when a story ends).
const V3_ADDED := ["fragments", "story_words"]
## Version 1 to 3 saves predate the story slot; its stream restarts from the seed the way setup() seeds it.
const V3_RNG_ADDED := ["story_state"]
## Fields a version 1 to 4 save may lack: no leader helped yet, so help is open to everyone.
const V4_ADDED := ["help_last"]
## Fields a version 1 to 5 save may lack: no bunker scene waiting, no proof beyond the fragments.
const V5_ADDED := ["story_queue", "proof_extra"]

## Why the last import_state() refused its data; "" after a successful import.
var load_error := ""


func export_state() -> Dictionary:
	var data := {
		"rng_state": rng.state, "crunch_state": crunch_rng.state,
		"net_state": net_rng.state, "check_state": check_rng.state, "story_state": story_rng.state,
	}
	for key in PERSIST:
		var value = get(key)
		data[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return data


## Replaces the whole run with the saved one, or leaves the game untouched and returns false.
func import_state(data: Dictionary) -> bool:
	var staged := stage_state(data, catalog)
	load_error = str(staged.error)
	if load_error != "":
		return false
	var state: Dictionary = staged.state
	for key in PERSIST:
		set(key, state[key])
	rng.state = int(state.rng_state)
	crunch_rng.state = int(state.crunch_state)
	net_rng.state = int(state.net_state)
	check_rng.state = int(state.check_state)
	story_rng.state = int(state.story_state)
	last_check = {}
	_init_standing()
	return true


## Migrates and validates save data into a complete, detached state without touching any live game.
## Returns {"error": String, "state": Dictionary}; state is only filled when error is "".
static func stage_state(data: Dictionary, cat: Catalog) -> Dictionary:
	if cat == null:
		return {"error": "no catalog", "state": {}}
	var schema = data.get("schema", 1)
	if typeof(schema) != TYPE_INT or int(schema) < 1 or int(schema) > SAVE_SCHEMA:
		return {"error": "unsupported schema %s" % str(schema), "state": {}}
	var base := Game.new()
	base.catalog = cat
	base._init_standing()
	var state := {}
	for key in PERSIST:
		if data.has(key):
			state[key] = data[key]
		elif (int(schema) == 1 and V1_ADDED.has(key)) or (int(schema) <= 2 and V2_ADDED.has(key)) or (int(schema) <= 3 and V3_ADDED.has(key)) or (int(schema) <= 4 and V4_ADDED.has(key)) or (int(schema) <= 5 and V5_ADDED.has(key)):
			state[key] = base.get(key)
		else:
			return {"error": "missing %s" % key, "state": {}}
		var want := typeof(base.get(key))
		var got := typeof(state[key])
		if got != want and not (want == TYPE_FLOAT and got == TYPE_INT):
			return {"error": "%s has type %s" % [key, type_string(got)], "state": {}}
	for key in RNG_KEYS:
		if data.has(key):
			if typeof(data[key]) != TYPE_INT:
				return {"error": "%s is not an int" % key, "state": {}}
			state[key] = data[key]
		elif (int(schema) == 1 and V1_RNG_ADDED.has(key)) or (int(schema) <= 3 and V3_RNG_ADDED.has(key)):
			state[key] = _v1_stream(key, int(state.seed))
		else:
			return {"error": "missing %s" % key, "state": {}}
	if int(schema) == 1 and not data.has("check_schedule"):
		var rebuilt := _v1_checks(cat, int(state.seed))
		state.check_schedule = rebuilt.schedule
		if not data.has("check_state"):
			state.check_state = rebuilt.state
	state = state.duplicate(true)
	var why := _state_problem(state, cat)
	if why != "":
		return {"error": why, "state": {}}
	var linked: Array = []
	for person in state.residents:
		linked.append(state.people[str(person.id)])
	state.residents = linked
	return {"error": "", "state": state}


## setup() draws the check weeks first from the freshly seeded check stream, so a version 1 save gets
## the schedule and stream state a new run of the same seed starts with.
static func _v1_checks(cat: Catalog, run_seed: int) -> Dictionary:
	var game := Game.new()
	game.catalog = cat
	game._install_check_events()
	game.check_rng.seed = run_seed * 29 + 11
	game._schedule_checks()
	return {"schedule": game.check_schedule, "state": game.check_rng.state}


static func _v1_stream(key: String, run_seed: int) -> int:
	var stream := RandomNumberGenerator.new()
	match key:
		"net_state":
			stream.seed = run_seed * 17 + 3
		"story_state":
			stream.seed = run_seed * 41 + 5
		_:
			stream.seed = run_seed * 29 + 11
	return stream.state


## Structure and identity checks on a staged state; "" when it can be played.
static func _state_problem(state: Dictionary, cat: Catalog) -> String:
	if int(state.max_weeks) < 1 or int(state.week) < 1 or int(state.week) > int(state.max_weeks):
		return "week %d of %d" % [int(state.week), int(state.max_weeks)]
	if not cat.factions.has(str(state.player)):
		return "unknown player %s" % state.player
	if not state.stations.has(str(state.capital_id)):
		return "unknown capital %s" % state.capital_id
	for id in state.people:
		var person = state.people[id]
		if not (person is Dictionary) or str(person.get("id", "")) != str(id):
			return "person %s malformed" % str(id)
	var seen := {}
	for person in state.residents:
		if not (person is Dictionary) or not state.people.has(str(person.get("id", ""))):
			return "resident outside people"
		if seen.has(str(person.id)):
			return "resident %s twice" % person.id
		seen[str(person.id)] = true
	if seen.size() != state.people.size():
		return "people %d, residents %d" % [state.people.size(), seen.size()]
	for seat in state.council:
		if not (seat is Dictionary) or not seat.has("id") or not seat.has("role"):
			return "council seat malformed"
	var uids := {}
	for room in state.rooms:
		if not (room is Dictionary) or not cat.rooms.has(str(room.get("type", ""))) or not (room.get("staff") is Array):
			return "room malformed"
		if uids.has(str(room.get("uid", ""))):
			return "room %s twice" % str(room.get("uid", ""))
		uids[str(room.uid)] = true
		for id in room.staff:
			if not state.people.has(str(id)):
				return "room %s staffed by unknown %s" % [room.uid, id]
	for job in [state.dig, state.build]:
		for id in job.get("workers", []):
			if not state.people.has(str(id)):
				return "worker %s unknown" % id
	var leaders := {}
	for row in cat.leaders.get("factions", []):
		leaders[str(row.get("id", ""))] = true
	for fid in state.standing:
		if not leaders.has(str(fid)) or typeof(state.standing[fid]) != TYPE_INT:
			return "standing %s malformed" % str(fid)
	if not state.audience.is_empty():
		if not leaders.has(str(state.audience.get("faction", ""))):
			return "audience faction %s unknown" % str(state.audience.get("faction", ""))
		var target := str(state.audience.get("target", ""))
		if target != "" and not state.people.has(target):
			return "audience target %s unknown" % target
	for fid in state.leader_answers:
		var row = state.leader_answers[fid]
		if not leaders.has(str(fid)) or not (row is Dictionary):
			return "leader answer %s malformed" % str(fid)
		if not SAVED_ANSWERS.has(str(row.get("answer", ""))):
			return "leader answer %s is %s" % [str(fid), str(row.get("answer", ""))]
		if typeof(row.get("week")) != TYPE_INT or int(row.week) < 1 or int(row.week) > int(state.week):
			return "leader answer %s week %s" % [str(fid), str(row.get("week"))]
	for fid in state.help_last:
		var at = state.help_last[fid]
		if not leaders.has(str(fid)) or typeof(at) != TYPE_INT or int(at) < 1 or int(at) > int(state.week):
			return "help %s week %s" % [str(fid), str(at)]
	for id in state.story_queue:
		var queued := false
		for ev in cat.events:
			if str(ev.get("id", "")) == str(id) and ev.has("trigger"):
				queued = true
		if not queued:
			return "story queue %s is not a bunker scene" % str(id)
	if typeof(state.proof_extra) != TYPE_INT or int(state.proof_extra) < 0:
		return "proof_extra %s" % str(state.proof_extra)
	for key in ARTIFACTS:
		if typeof(state.artifacts.get(key)) != TYPE_INT or int(state.artifacts[key]) < 0:
			return "artifact %s is %s" % [key, str(state.artifacts.get(key))]
	for id in state.fragments:
		var row = state.fragments[id]
		if not FRAGMENTS.has(str(id)) or not (row is Dictionary) or typeof(row.get("known")) != TYPE_BOOL:
			return "fragment %s malformed" % str(id)
		if not FRAGMENT_HOWS.has(str(row.get("how", ""))):
			return "fragment %s learned %s" % [str(id), str(row.get("how", ""))]
		if typeof(row.get("week")) != TYPE_INT or int(row.week) < 1 or int(row.week) > int(state.week):
			return "fragment %s week %s" % [str(id), str(row.get("week"))]
	if int(state.story_words) < 0:
		return "story_words %d" % int(state.story_words)
	return ""


func _line_name(room_name: String, lower: bool) -> String:
	if Copy.ru():
		return Copy.t(room_name)
	return room_name.to_lower() if lower else room_name


func _note(en: String, ru_line: String) -> void:
	_log(ru_line if Copy.ru() else en, true)


func _log(text: String, important := false) -> void:
	log.append({"week": week, "text": text, "important": important})
