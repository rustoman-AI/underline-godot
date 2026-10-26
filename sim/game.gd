class_name Game
extends RefCounted
const Brief = preload("res://sim/brief.gd")
const JOURNAL_MAX := 200
## Each week at hope 0 this many residents leave; this many weeks in a row at 0 end the run.
const HOPE_ZERO_LEAVE := 2
const HOPE_ZERO_WEEKS := 3
const PUSH_BLOCKED := ["infirmary", "radio", "quarters"]
const PUSH_WINDOW := 4
## Salvage Board (DEC-S2). Tier is the blueprint gate. Step is the room upgrade level this node fits.
## Materials stay on the room's existing upgrade cost. No new balance.json numbers.
const SALVAGE_NODES := [
	{"id": "grow_lamps", "room": "hydroponics", "tier": 0, "step": 1},
	{"id": "charcoal", "room": "air_filter", "tier": 0, "step": 1},
	{"id": "dynamo", "room": "generator", "tier": 0, "step": 1},
	{"id": "drill_heads", "room": "workshop", "tier": 0, "step": 1},
	{"id": "bunks", "room": "quarters", "tier": 0, "step": 1},
	{"id": "mushroom_beds", "room": "hydroponics", "tier": 1, "step": 2},
	{"id": "pressure_seals", "room": "air_filter", "tier": 1, "step": 2},
	{"id": "substation", "room": "generator", "tier": 1, "step": 2},
	{"id": "armor", "room": "workshop", "tier": 1, "step": 2},
	{"id": "quarantine_ward", "room": "infirmary", "tier": 1, "step": 1},
	{"id": "antenna", "room": "radio", "tier": 1, "step": 1},
	{"id": "pipe_taps", "room": "listening_post", "tier": 2, "step": 1},
]
const STRIP_MATERIALS := 4
const STRIP_EVERY := 3
const JUNK_EVERY := 6

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
## Strip cooldown, first-fit float, and the one-time raid blueprint. Blueprints themselves live on stock.
var salvage := {"strip_week": 0, "floated": false, "raid_bp": false, "float_id": "", "float_uid": "", "junk_week": 0}
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
## Yard pile clear, same brigade as dig. Empty when nobody is clearing.
var clear := {}
## Last finished clear, for the one-shot dust overlay. Not saved.
var clear_burst := {}
var clear_burst_seq := 0
var build := {}
var expedition := {}
var active_season := {}
var seasons: Array = []
var artifacts := {"papers": 0, "iron": 0, "words": 0, "breach": 0}
var combat_lock := {}
var battle_dis_week := 0
var injury_bias := -1.0
var last_combat_report := {}
var pumped := false
var flood_guard := false
var quarantine := false
var synod := 0
var floor_met := false
var orders_left := 0
var seat_used := {}
var queued_orders: Array = []
var order_reports: Array = []
var last_order_note := {}
var choice_results: Array = []
## One map rumor: {station, text_key, week_until, true}. `blind` is extra: the pin was unknown when it was rolled.
## Empty when the map has none. Kept for 3 weeks, or until the station is scouted or owned.
var rumor := {}
## Rival-intent hops waiting for the map to draw. The view drains this; it is not saved.
var map_playback: Array = []
## Gift / pay floats and aid stamps waiting for the next map draw. Not saved.
var map_marks: Array = []
## Aid need-bar ticks the visit sheet plays once: {station, need, old, new, week}. Not saved.
var need_ticks: Array = []
const RUMOR_LINES := ["rumor.line_01", "rumor.line_02", "rumor.line_03", "rumor.line_04", "rumor.line_05", "rumor.line_06"]
const RUMOR_WEEKS := 3
## What _order_pay already adds. Named so the toast and the dawn line use the same figure.
const PAY_OPINION := 5
## What _order_aid already adds to a need fill. Named so the report can read the same step.
const AID_BUMP := 0.25
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
## Told about every applied action ("action", {...}) and journal row ("journal", row). Set by the UI for the
## playtest log; never saved.
var watcher: Callable
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
## The week the platform was last addressed (queued or given); once a week (address_cooldown).
var address_week := -99
## This week's hardship ids, the chronicle of heavy moments, people who have left, and burials still waiting.
var hardship_now: Array = []
var chronicle: Array = []
var departed: Array = []
var burials: Array = []
## Creed stays empty until a line law sets it. No line law is in the book yet.
var creed := ""
var notices: Array = []
## Meter changes to float once, the first week a held perk applies. The yard clears this.
var perk_float_due := {}
## Dawn-card line for a Listening Post order. Not saved.
var listening_line := ""

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
	_jitter_seasons()
	week = 1
	hardship_now = []
	chronicle = []
	departed = []
	burials = []
	creed = ""
	notices = []
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
		"blueprints": 0,
	}
	salvage = {"strip_week": 0, "floated": false, "raid_bp": false, "float_id": "", "float_uid": "", "junk_week": 0}
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
	_muster_start_guard()
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
	_tick_claims()
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
		_seal_score()
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
	var scene: bool = kind == "event" and not pending.is_empty() and pending[0].has("trigger")
	var ok := false
	match kind:
		"event":
			ok = _apply_event(action)
		"build":
			ok = _apply_build(str(action.get("type", "")), int(action.get("level", -1)), int(action.get("cell", -1)))
		"dig":
			ok = _apply_dig_action(action)
		"clear":
			ok = _apply_clear(int(action.get("level", -1)), int(action.get("cell", -1)))
		"upgrade":
			ok = _apply_upgrade(str(action.get("room", "")))
		"strip":
			ok = _apply_strip()
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
		"push":
			ok = _apply_push(str(action.get("room", "")))
		"repeal":
			ok = _apply_repeal(str(action.get("law", "")))
		"power":
			ok = _move_power(str(action.get("room", "")), bool(action.get("up", false)))
		"order":
			ok = _apply_order(action)
		"recruit":
			ok = _apply_recruit()
		"dismiss":
			ok = _apply_dismiss()
		"appoint":
			ok = appoint_governor(str(action.get("station", "")), str(action.get("person", "")))
		"recall":
			ok = recall_governor(str(action.get("station", "")))
		"audience":
			ok = _apply_help() if bool(action.get("help", false)) else _apply_audience(bool(action.get("accept", false)))
		_:
			ok = false
	if ok and not entry.is_empty():
		_journal(kind, entry)
	if ok and watcher.is_valid():
		watcher.call("action", {"kind": kind, "action": action, "entry": entry, "scene": scene})
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
		"clear":
			return {"level": int(action.get("level", -1)), "cell": int(action.get("cell", -1))}
		"upgrade", "demolish":
			var room = _room(str(action.get("room", "")))
			if room == null:
				return {}
			if kind == "upgrade":
				return {"type": str(room.type), "name": str(upgrade_preview(str(room.uid)).name), "tier": int(room.upgrade) + 1}
			return {"type": str(room.type)}
		"law", "repeal":
			return {"law": str(action.get("law", ""))}
		"order":
			return {"order": str(action.get("order", "")), "station": str(action.get("station", action.get("dest", "")))}
		"pump", "quarantine", "burn", "rally", "strip":
			return {"done": true}
		"push":
			var pushed = _room(str(action.get("room", "")))
			if pushed == null:
				return {}
			return {"type": str(pushed.type)}
	return {}


## Rows hold ids only; the UI words them. Oldest rows drop off past JOURNAL_MAX so saves stay small.
func _journal(kind: String, data: Dictionary) -> void:
	var row := data.duplicate(true)
	row["kind"] = kind
	row["week"] = week
	journal.append(row)
	if watcher.is_valid():
		watcher.call("journal", row)
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


func air_buffer_weeks() -> float:
	return float(stock.air) / float(maxi(1, air_need()))


func food_need() -> int:
	var shares := 0.0
	for person in residents:
		shares += (2.0 / 3.0) if _is_child(person) else 1.0
	var n := 0
	if shares > 0.0:
		n = ceili(shares / float(maxi(1, int(bal.food_per))))
	if _law_on("rationing"):
		n = int(round(float(n) * 0.75))
	return n


func air_need() -> int:
	var adults := 0
	for person in residents:
		if not _is_child(person):
			adults += 1
	return Formulas.people_for(adults, int(bal.air_per))


func power_need() -> int:
	return _power_need()


func housing() -> int:
	var n := 0
	for room in rooms:
		if room.offline:
			continue
		n += room_housing(room)
	for b in _merge_groups():
		if str(b[0].type) != "quarters":
			continue
		var live := true
		for r in b:
			if bool(r.offline):
				live = false
		if live:
			n += int(bal.get("merge_housing", 2)) * (b.size() - 1)
	return n


## Base output multiplier for a room at this upgrade tier. One tier is upgrade_output (0.75 = +75%).
func output_scale(tier: int) -> float:
	return 1.0 + float(bal.get("upgrade_output", 0.75)) * float(tier)


## What a room's bought upgrades do beyond that output step (balance.json upgrade_fx), summed over
## every tier bought. cough_spread multiplies, shrug_down is true if any tier has it, the rest add up.
func upgrade_fx(room) -> Dictionary:
	var out := {}
	var steps: Array = catalog.rooms[room.type].get("upgrades", [])
	var table: Dictionary = bal.get("upgrade_fx", {})
	for i in mini(int(room.upgrade), steps.size()):
		var fx: Dictionary = table.get(str(steps[i]), {})
		for key in fx:
			if key == "cough_spread":
				out[key] = float(out.get(key, 1.0)) * float(fx[key])
			elif key == "shrug_down":
				out[key] = bool(out.get(key, false)) or bool(fx[key])
			else:
				out[key] = int(out.get(key, 0)) + int(fx[key])
	return out


func room_housing(room) -> int:
	return maxi(0, int(catalog.rooms[room.type].get("housing", 0)) + int(upgrade_fx(room).get("housing", 0)))


func room_power(room) -> int:
	return maxi(0, int(catalog.rooms[room.type].get("power", 0)) + int(upgrade_fx(room).get("power", 0)))


func filter_upkeep(room) -> int:
	return maxi(0, int(bal.filter_upkeep) + int(upgrade_fx(room).get("upkeep", 0)))


## Armour plates: events that shut the workshop down (shop_down, disabled weeks) pass it by.
func shrugs_down(room) -> bool:
	return bool(upgrade_fx(room).get("shrug_down", false))


## The best value of a station-wide upgrade effect among rooms that are switched on: the smallest for
## dig_turns and cough_spread, the largest for warning_weeks. Rooms of one type do not stack.
func station_fx(key: String) -> float:
	var best := 1.0 if key == "cough_spread" else 0.0
	for room in rooms:
		if bool(room.offline):
			continue
		var fx := upgrade_fx(room)
		if not fx.has(key):
			continue
		if key == "warning_weeks":
			best = maxf(best, float(fx[key]))
		else:
			best = minf(best, float(fx[key]))
	return best


## Weekly hope or discontent from upgrades (family corners, loudspeakers) in rooms that are switched on.
func upgrade_mood(key: String) -> int:
	var n := 0
	for room in rooms:
		if not bool(room.offline):
			n += int(upgrade_fx(room).get(key, 0))
	return n


func flood_warning() -> int:
	return int(bal.get("season_warning", 2)) + int(station_fx("warning_weeks")) + _perk_int("flood_warn_weeks")


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


## 1 while the yard is not sharing short rations. share_output (balance dilemmas) while it is.
func output_cut() -> float:
	var until := int(stats.get("share_until", 0))
	if until <= 0 or week > until:
		return 1.0
	return float(_dilemma().get("share_output", 1.0))


## Room output after the equal-share cut. Radio tokens are added later and are not cut.
func share_cut(n: int) -> int:
	var cut := output_cut()
	if cut >= 0.999:
		return n
	return int(round(float(n) * cut))


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


## P37 Border Whisper is not on this branch. Stub of its 1-hop rule: every station that
## touches the player's line through an open tunnel and is not already player-owned.
## P37 can replace this body. Rail noise only reads the list. No rings, no orient card.
func border_stations() -> Array:
	var out: Array = []
	for sid in stations:
		var id := str(sid)
		if str(stations[id].get("owner", "")) == player:
			continue
		if borders_player(id):
			out.append(id)
	out.sort()
	return out


## 0 unknown, 1+ known. `known` counts as intel 1. A numeric `intel` field counts as itself.
func station_intel(sid: String) -> int:
	if not stations.has(sid):
		return 0
	var st: Dictionary = stations[sid]
	var rank := int(st.get("intel", 0))
	if bool(st.get("known", false)):
		rank = maxi(rank, 1)
	return rank


## True while this rival party is already mid-assault on the player, so P20/P25 owns the scream.
## Set squad.mid_assault for the week their chrome is up, and clear it when that week ends.
## A fight onto player ground stamps assault_player_week; the dawn of that fight and the next skip noise.
## A provoked squad merely standing on the border is not an assault. The capital hold-short is not one either.
func party_mid_assault(fid: String) -> bool:
	if fid == "" or fid == player or not squads.has(fid):
		return false
	var sq: Dictionary = squads[fid]
	if bool(sq.get("mid_assault", false)):
		return true
	var fought := int(sq.get("assault_player_week", -99))
	return fought == week or fought == week - 1


## The rival party the yard would hear, before dawn-chip priority. Empty when nobody qualifies.
## Largest party, then fewest hops to Coney (the player's capital). Same hop count breaks on station id.
func rail_noise_candidate() -> Dictionary:
	var borders := {}
	for sid in border_stations():
		borders[str(sid)] = true
	var best := {}
	var best_size := -1
	var best_hops := 9999
	for fid in squads:
		var id := str(fid)
		if id == player or party_mid_assault(id):
			continue
		var sq: Dictionary = squads[fid]
		if bool(sq.get("away", false)):
			continue
		var sid := str(sq.get("station", ""))
		if not borders.has(sid):
			continue
		var size := int(sq.get("size", 0))
		if size <= 0:
			continue
		var hops := _hops(sid, capital_id)
		var station_id := str(best.get("station", ""))
		var prefer := best.is_empty() or size > best_size or (size == best_size and hops < best_hops) or (size == best_size and hops == best_hops and sid < station_id)
		if not prefer:
			continue
		best_size = size
		best_hops = hops
		var known := station_intel(sid) >= 1
		var place := ""
		if known:
			place = station_text(sid, "community")
			if place == "":
				place = str(stations[sid].get("name", sid))
		best = {
			"kind": "rail",
			"faction": id,
			"station": sid,
			"size": size,
			"hops": hops,
			"known": known,
			"place": place,
			"key": "noise.rail" if known else "noise.rail_unknown",
		}
	return best


## P28 sets flags.rumor_dawn on the dawn a rumor chip should win.
## P37 sets flags.border_dawn_new on the dawn border.dawn_new should win.
## Both stay unset on this branch. First match wins; the others wait for a later dawn.
func _rumor_dawn_due() -> bool:
	return bool(flags.get("rumor_dawn", false))


func _border_dawn_new_due() -> bool:
	return bool(flags.get("border_dawn_new", false))


func _pick_dawn_soft_chip() -> Dictionary:
	if _rumor_dawn_due():
		return {"kind": "rumor", "key": "rumor.dawn"}
	if _border_dawn_new_due():
		return {"kind": "border_new", "key": "border.dawn_new"}
	return rail_noise_candidate()


## This dawn's one soft chip. After present_dawn_soft_chip(), the same week returns that latch.
func dawn_soft_chip() -> Dictionary:
	if int(flags.get("dawn_soft_week", -1)) == week:
		return _latched_dawn_soft()
	return _pick_dawn_soft_chip()


func _latched_dawn_soft() -> Dictionary:
	var kind := str(flags.get("dawn_soft_kind", ""))
	if kind == "":
		return {}
	return {
		"kind": kind,
		"key": str(flags.get("dawn_soft_key", "")),
		"station": str(flags.get("dawn_soft_station", "")),
		"place": str(flags.get("dawn_soft_place", "")),
		"faction": str(flags.get("dawn_soft_faction", "")),
		"known": bool(flags.get("dawn_soft_known", false)),
		"fresh": false,
		"first": false,
	}


## Takes this dawn's one soft chip and latches it. The first rail chip of a run sets flags.heard_rail.
func present_dawn_soft_chip() -> Dictionary:
	if int(flags.get("dawn_soft_week", -1)) == week:
		var again := _latched_dawn_soft()
		again["fresh"] = false
		again["first"] = false
		return again
	var chip := _pick_dawn_soft_chip()
	flags["dawn_soft_week"] = week
	flags["dawn_soft_kind"] = str(chip.get("kind", ""))
	flags["dawn_soft_key"] = str(chip.get("key", ""))
	flags["dawn_soft_station"] = str(chip.get("station", ""))
	flags["dawn_soft_place"] = str(chip.get("place", ""))
	flags["dawn_soft_faction"] = str(chip.get("faction", ""))
	flags["dawn_soft_known"] = bool(chip.get("known", false))
	if str(chip.get("kind", "")) == "rumor":
		flags.erase("rumor_dawn")
	elif str(chip.get("kind", "")) == "border_new":
		flags.erase("border_dawn_new")
	chip = chip.duplicate(true)
	chip["fresh"] = true
	chip["first"] = false
	if str(chip.get("kind", "")) == "rail" and not bool(flags.get("heard_rail", false)):
		flags["heard_rail"] = true
		chip["first"] = true
	return chip


## Player-facing line for a soft chip. Rail uses the community name when the station is known.
func dawn_soft_line(chip: Dictionary) -> String:
	var key := str(chip.get("key", ""))
	if key == "noise.rail":
		var place := str(chip.get("place", ""))
		var sid := str(chip.get("station", ""))
		if sid != "" and stations.has(sid) and station_intel(sid) >= 1:
			var live := station_text(sid, "community")
			if live == "":
				live = str(stations[sid].get("name", sid))
			place = live
		return Copy.fill("noise.rail", {"station": place})
	if key == "":
		return ""
	return Copy.t(key)


func sympathy_preview(sid: String) -> int:
	if not stations.has(sid):
		return 0
	return Formulas.sympathy_gain(float(bal.sympathy_base), player_lean, str(stations[sid].lean), _avg_fill(stations[sid]))


## Toast-time envoy numbers. Same gain as `_order_envoy` before the dawn need bump.
func envoy_preview(sid: String) -> Dictionary:
	if not stations.has(sid):
		return {"gain": 0, "need_id": ""}
	var st: Dictionary = stations[sid]
	var gain := maxi(2, int(round(float(sympathy_preview(sid)) * 0.35)))
	return {"gain": gain, "need_id": _lowest_need(st)}


## The deal about to land at dawn, clamped to the 1–3 ladder.
func deal_preview(sid: String) -> int:
	if not stations.has(sid):
		return 1
	return clampi(int(stations[sid].get("deals", 0)) + 1, 1, 3)


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
	var strain := tension_push(hardships(), hope)
	hope_d += int(strain.hope)
	dis_d += int(strain.dis) + int(strain.despair)
	hope_d += upgrade_mood("hope_week")
	dis_d += upgrade_mood("discontent_week")
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
			dis_d += agent_push()
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
	if sq.away or str(sq.station) != capital_id or soldier_count() < int(bal.guard.move_min):
		return false
	var tunnel := _tunnel_by_id("to_ferry")
	return not tunnel.is_empty() and not tunnel.dug


func can_approach() -> bool:
	if floor_met or int(artifacts.papers) < 1:
		return false
	var tunnel := _tunnel_by_id("to_floor")
	return not tunnel.is_empty() and bool(tunnel.dug)


func can_trade() -> bool:
	if int(combat_lock.get("exchange", 0)) > week:
		return false
	return not trade_on and int(opinions.get("exchange", -100)) >= 0 and int(stock.influence) >= 4 and orders_left > 0


func build_possible(type: String) -> bool:
	var defin: Dictionary = catalog.rooms.get(type, {})
	if defin.is_empty() or not bool(defin.get("buildable", false)):
		return false
	if not build.is_empty():
		return false
	var cap := int(defin.get("max", 0))
	if cap > 0 and room_count(type) >= cap:
		return false
	if type == "listening_post" and listening_build_block() != "":
		return false
	if int(stock.materials) < int(defin.materials):
		return false
	if _free_count() < int(bal.build_workers):
		return false
	return build_slots() > 0


func dig_possible(for_space: bool) -> bool:
	if not dig.is_empty() or not clear.is_empty():
		return false
	if int(stock.materials) < dig_material_cost():
		return false
	var target := _pick_dig_cell(for_space)
	if target.is_empty():
		return false
	return _free_count() >= int(_dig_cost(int(target.level)).workers)


# --- week phases ---

func _dawn() -> void:
	_expire_need_ticks()
	battle_dis_week = 0
	_resolve_queued()
	_sync_perk_notices()
	orders_left = council.size()
	for seat in council:
		if governor_of(str(seat.id)) != "":
			orders_left -= 1
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
	_offer_burial()
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
	_roll_rumor()
	_audience_dawn()
	_drip_piles()
	_offer_home_chip()


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
	_sorties()


func _night() -> void:
	_grant_junk_blueprints()
	var sick_now := sick_count()
	if _season_is("cough"):
		_spread_cough()
		_cough_pull_workers()
	_mark_brownout()
	var produced := _tally(belt_down, workshop_down, gen_down, true)
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
	_tick_seats()
	for room in rooms:
		if int(room.get("mold", 0)) > 0:
			room.mold = int(room.mold) - 1
		if int(room.get("disabled", 0)) > 0:
			room.disabled = int(room.disabled) - 1
	_resolve_pushes()
	if _law_on("engineers_charter"):
		stock.power = int(stock.power) + int(catalog.laws.engineers_charter.get("power", 0))
	_apply_weekly_laws()
	if trade_on:
		stock.tokens = int(stock.tokens) + int(bal.trade_tokens_week)
	_deliver_outposts()
	_apply_held_perks()
	_deliver_goods()
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
		_note("SHORT Food ran short by %d, air by %d." % [food_short, air_short], "SHORT еды не хватило на %d, воздуха на %d." % [food_short, air_short])
		if deaths > 0:
			var cause := "food_shortage" if food_short > 0 else "air_shortage"
			_kill(deaths, "Supplies ran out", cause)
	var power_short := maxi(0, need_power - int(stock.power))
	stock.power = maxi(0, int(stock.power) - need_power)
	if power_short > 0:
		_add_hope(int(bal.power_shortage_hope), "power")
		_add_discontent(int(bal.power_shortage_discontent), "power")
		week_short = true
		_note("SHORT Power ran short by %d." % power_short, "SHORT энергии не хватило на %d." % power_short)
	var dark_now := power_short > 0
	for room in rooms:
		if bool(room.get("browned", false)):
			dark_now = true
		room.browned = false
	if int(stock.power) <= 0:
		power_zero_streak += 1
	else:
		power_zero_streak = 0
	stats["power_zero_max"] = maxi(int(stats.get("power_zero_max", 0)), power_zero_streak)
	if week_short:
		_life_journal_shortage()
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
	_note_new_sickness()
	_apply_flood_if_needed()
	_season_mood()
	_tension(_hardship_ids(food_short > 0 or air_short > 0, food_short > 0, dark_now, sick_now))
	_rival_agents()
	if residents.size() > housing():
		_add_discontent(int(bal.overcrowd_discontent), "overcrowd")
	if upgrade_mood("hope_week") != 0:
		_add_hope(upgrade_mood("hope_week"), "upgrades")
	if upgrade_mood("discontent_week") != 0:
		_add_discontent(upgrade_mood("discontent_week"), "upgrades")
	_add_hope(int(bal.hope_drift), "drift")
	for key in before:
		last_net[key] = int(stock.get(key, 0)) - int(before[key])
	_synod_preach()
	_claim_swayed()
	_tick_holdings()
	_drift_opinion()
	_tick_children()
	for fid in ambition:
		if str(fid) == "synod":
			continue
		ambition[fid] = int(ambition[fid]) + int(bal.ambition_week)
	_grow()
	_advance_jobs()
	_tick_expedition()
	_tick_player_party()
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
		_shed(HOPE_ZERO_LEAVE, "died", "hope")
		if hope_zero >= HOPE_ZERO_WEEKS and over == "":
			over = "hope"
			_log("HOPE the station stops working", true)
	else:
		hope_zero = 0
	if discontent >= 100 and over == "":
		over = "revolt"
		_log("REVOLT the platform turns on you", true)
	_sample_meters()
	_flush_hope_week()
	_seal_score()


# --- production ---

func _tally(drop_hydro_food := false, drop_shop := false, drop_gen := false, commit := false, perk_boost := true) -> Dictionary:
	var out := {"food": 0, "air": 0, "power": 0, "materials": 0, "tokens": 0, "influence": 0}
	var mult := 1.0
	if _law_on("double_shifts"):
		mult = float(catalog.laws.double_shifts.prod_mult)
	var made := {}
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
			if _is_child(person):
				skills.append(0)
				continue
			if commit and int(person.sick) <= 0 and int(person.absent) <= 0:
				_mark_served(person, room)
			if int(person.sick) > 0 or int(person.absent) > 0 or skill == "":
				skills.append(0)
			else:
				skills.append(int(person.skills.get(skill, 1)))
		var factor := _output_factor(room, defin)
		var base: Dictionary = defin.base
		for key in base:
			if not out.has(key):
				continue
			var amount := float(base[key]) * output_scale(int(room.upgrade))
			var n := 0
			if factor > 0.0:
				n = Formulas.room_output(amount, skills, float(bal.skill_coef), float(bal.output_cap))
				n = int(round(float(n) * factor))
			if bool(defin.get("decays", false)):
				n = int(round(float(n) * float(room.efficiency)))
			n = int(round(float(n) * mult))
			if drop_hydro_food and str(room.type) == "hydroponics" and str(key) == "food":
				n = int(n / 2.0)
			if drop_shop and str(room.type) == "workshop" and str(key) == "materials" and not shrugs_down(room):
				n = 0
			if drop_gen and str(room.type) == "generator" and str(key) == "power":
				n = int(n / 2.0)
			if int(room.get("mold", 0)) > 0 and str(key) == "food":
				n = 0
			elif not (drop_shop and str(room.type) == "workshop" and str(key) == "materials" and not shrugs_down(room)):
				n += crew_extra(skills, room, n)
			if perk_boost and str(room.type) == "hydroponics" and str(key) == "food":
				n += _effect_int("food_room_bonus")
			if perk_boost and str(room.type) == "generator" and str(key) == "power":
				n = int(round(float(n) * _generator_mult()))
			if str(key) == "food" and factor > 0.0 and int(room.get("mold", 0)) <= 0:
				n += mushroom_food(room)
			n = share_cut(scale_push(n, room))
			out[key] = int(out[key]) + n
			made[str(room.uid) + "|" + str(key)] = n
	var mb := float(bal.get("merge_bonus", 0.0))
	if mb > 0.0:
		for b in _merge_groups():
			if b.size() < 2:
				continue
			for key in catalog.rooms[str(b[0].type)].base:
				if not out.has(key):
					continue
				var sum := 0
				for r in b:
					sum += int(made.get(str(r.uid) + "|" + str(key), 0))
				out[key] = int(out[key]) + int(round(float(sum) * mb * float(b.size() - 1)))
	if quarantine:
		for key in ["food", "air", "power", "materials", "influence"]:
			out[key] = int(round(float(out[key]) * 0.75))
	if _law_on("curfew"):
		out.influence = int(round(float(out.influence) * float(catalog.laws.curfew.influence_mult)))
	out.tokens = int(out.tokens) + radio_grant()
	return out


## A staffed radio that is actually running brings tokens. Flat, so an upgrade does not multiply it.
func radio_grant() -> int:
	var n := 0
	for room in rooms:
		if str(room.type) != "radio":
			continue
		if bool(room.get("offline", false)) or _flood_silences(room) or int(room.get("disabled", 0)) > 0:
			continue
		if bool(room.get("browned", false)):
			continue
		if _able_count(room) < 1:
			continue
		n += 2
	return n


## --- push a room (one night, one room) ---

## A room with its own output. Infirmary, radio and quarters never push.
func room_pushable(room) -> bool:
	if not (room is Dictionary):
		return false
	var type := str(room.get("type", ""))
	if type in PUSH_BLOCKED or not catalog.rooms.has(type):
		return false
	var base: Dictionary = catalog.rooms[type].get("base", {})
	for key in base:
		if float(base[key]) > 0.0:
			return true
	return false


func room_pushed(room) -> bool:
	if not (room is Dictionary):
		return false
	for at in room.get("push_weeks", []):
		if int(at) == week:
			return true
	return false


## Pushes of this room in the previous 4 weeks. The push being rolled is not one of them.
func _push_priors(room) -> int:
	var seen := {}
	var n := 0
	for at in room.get("push_weeks", []):
		var w := int(at)
		if w < week - PUSH_WINDOW or w >= week or seen.has(w):
			continue
		seen[w] = true
		n += 1
	return n


## A staffer still in the room with care or fight at 4 or more halves the incident chance.
func _push_covered(room) -> bool:
	for id in room.get("staff", []):
		if not people.has(str(id)):
			continue
		var person: Dictionary = people[str(id)]
		if int(person.get("absent", 0)) > 0:
			continue
		var skills: Dictionary = person.get("skills", {})
		if int(skills.get("care", 0)) >= 4 or int(skills.get("fight", 0)) >= 4:
			return true
	return false


func _push_chance(room) -> float:
	var p := float(bal.get("push_risk", 0.15)) + float(bal.get("push_stack", 0.10)) * float(_push_priors(room))
	p = minf(p, float(bal.get("push_cap", 0.55)))
	if _push_covered(room):
		p *= 0.5
	return p


## The percent the preview shows and the percent _push_hits rolls against.
func _push_pct(room) -> int:
	return int(round(_push_chance(room) * 100.0))


func push_preview(uid: String) -> Dictionary:
	var room = _room(uid)
	var out := {
		"ok": false,
		"pct": 0,
		"chance": 0.0,
		"reason": Copy.t("push.disabled_room"),
		"uid": uid,
	}
	if not room_pushable(room):
		return out
	var chance := _push_chance(room)
	out.chance = chance
	out.pct = _push_pct(room)
	if room_pushed(room):
		out.reason = Copy.t("push.disabled_used")
		return out
	out.ok = true
	out.reason = ""
	return out


func _apply_push(uid: String) -> bool:
	if not bool(push_preview(uid).get("ok", false)):
		return false
	var room = _room(uid)
	var weeks: Array = []
	var raw = room.get("push_weeks", [])
	if raw is Array:
		weeks = raw.duplicate()
	weeks.append(week)
	room["push_weeks"] = weeks
	decisions += 1
	_log("ORDER push %s" % str(room.type))
	return true


## Double a pushed room's finished output. 1 when it was not pushed this week.
func scale_push(n: int, room) -> int:
	if not room_pushed(room):
		return n
	return int(round(float(n) * float(bal.get("push_mult", 2.0))))


## The staffed room that makes `key`, or "" when none can be pushed tonight.
func push_target(key: String) -> String:
	var best := ""
	var best_n := 0
	for room in rooms:
		if not room_pushable(room) or not bool(push_preview(str(room.uid)).get("ok", false)):
			continue
		if bool(room.get("offline", false)) or int(room.get("disabled", 0)) > 0:
			continue
		var defin: Dictionary = catalog.rooms[room.type]
		if int(defin.get("base", {}).get(key, 0)) <= 0:
			continue
		if int(defin.get("staff_min", 0)) > 0 and _able_count(room) <= 0:
			continue
		var n := int(defin.base[key]) * maxi(1, _able_count(room))
		if n <= best_n:
			continue
		best_n = n
		best = str(room.uid)
	return best


func _push_hits(room) -> bool:
	return rng.randi_range(0, 99) < _push_pct(room)


func _resolve_pushes() -> void:
	for room in rooms:
		if not room_pushed(room) or int(room.get("push_rolled", 0)) == week:
			continue
		room["push_rolled"] = week
		if not _push_hits(room):
			continue
		_push_incident(room)


func _push_incident(room) -> void:
	var type := str(room.type)
	match type:
		"hydroponics":
			stock.food = maxi(0, int(stock.food) - 4)
		"air_filter":
			room.disabled = maxi(int(room.get("disabled", 0)), 1)
			_push_injure(room)
		"generator":
			stock.power = maxi(0, int(stock.power) - 8)
			_push_injure(room)
		"workshop":
			_push_injure(room)
		"meeting_hall":
			_add_discontent(4, "push")
		_:
			pass
	room["push_tint_until"] = week + 1
	_push_note(_push_incident_key(type))


func _push_incident_key(type: String) -> String:
	Copy.boot()
	var key := "push.incident." + type
	if Copy.keys.has(key):
		return key
	return "push.incident.generic"


func _push_pack(key: String) -> Dictionary:
	Copy.boot()
	var row: Dictionary = Copy.keys.get(key, {})
	var en: String = str(row.get("en", ""))
	var ru: String = str(row.get("ru", en))
	return {"en": en, "ru": ru}


func _push_note(key: String) -> void:
	var pack := _push_pack(key)
	_note("PUSH " + pack.en, "PUSH " + pack.ru)


func _push_injure(room) -> void:
	var id := _push_victim(room)
	if id == "" or not people.has(id):
		return
	var person: Dictionary = people[id]
	person.absent = maxi(int(person.get("absent", 0)), 2)
	_life_note(person, "injured", {})
	_log("INJURED 1", true)
	var pack := _push_pack("push.incident_known")
	var name_en := str(person.get("name", ""))
	var name_ru := str(person.get("name_ru", ""))
	if name_ru == "":
		name_ru = name_en
	var suffix := "а" if str(person.get("sex", "m")) == "f" else ""
	var en := str(pack.en).replace("{name}", name_en).replace("{a}", "")
	var ru := str(pack.ru).replace("{name}", name_ru).replace("{a}", suffix)
	_note("PUSH " + en, "PUSH " + ru)


func _push_victim(room) -> String:
	var ids: Array = []
	for id in room.get("staff", []):
		ids.append(str(id))
	for person in residents:
		var id := str(person.id)
		if not ids.has(id):
			ids.append(id)
	for id in ids:
		if not people.has(str(id)):
			continue
		var person: Dictionary = people[str(id)]
		if _is_child(person) or int(person.get("absent", 0)) > 0:
			continue
		return str(id)
	return ""


## People on the roster who can actually work. Sick and absent stay listed, but they do not count.
## What to add to a room's output (made) so each able worker is worth at least 1 of it, plus 1 for each
## veteran (four weeks on the same seat), up to two.
func crew_extra(skills: Array, room, made: int = 0) -> int:
	var hands := 0
	for s in skills:
		if float(s) >= 1.0:
			hands += 1
	var vets := 0
	if room is Dictionary:
		for id in room.get("staff", []):
			if not people.has(str(id)):
				continue
			var person: Dictionary = people[str(id)]
			if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
				continue
			if int(person.get("seat_weeks", 0)) >= 4:
				vets += 1
	return maxi(0, hands - made) + mini(vets, 2)


func _tick_seats() -> void:
	var seated := {}
	for room in rooms:
		for id in room.staff:
			var key := str(id)
			seated[key] = true
			if people.has(key):
				people[key]["seat_weeks"] = int(people[key].get("seat_weeks", 0)) + 1
	for person in residents:
		var key := str(person.id)
		if seated.has(key):
			continue
		if str(person.get("post", "")) == "":
			person["seat_weeks"] = 0


func _able_count(room: Dictionary) -> int:
	var n := 0
	for id in room.get("staff", []):
		if not people.has(str(id)):
			continue
		var person: Dictionary = people[str(id)]
		if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		n += 1
	return n


func _output_factor(room: Dictionary, defin: Dictionary) -> float:
	var listed := int(room.get("staff", []).size())
	var have := _able_count(room)
	var need := int(defin.get("staff_min", 0))
	var grp := _merge_group_of(room)
	if grp.size() > 1:
		listed = 0
		have = 0
		for r in grp:
			listed += int(r.get("staff", []).size())
			have += _able_count(r)
		need = need * grp.size() - int(bal.get("merge_crew_saving", 1)) * (grp.size() - 1)
		need = maxi(0, need)
	if str(room.type) == "generator":
		if have <= 0:
			return 0.0
		if have < need:
			return 0.5
		return 1.0
	if need > 0 and have <= 0:
		return 0.0 if listed > 0 else 0.5
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
		pool -= room_power(room) * mult
	if pool < 0:
		pool = 0
	var spare := brownout_spare()
	var decided := {}
	for uid in power_order:
		var room = _room(str(uid))
		if room == null:
			continue
		if decided.has(str(uid)):
			continue
		if str(room.type) == "generator" or bool(room.offline) or _flood_silences(room):
			continue
		var grp := _merge_group_of(room)
		var draw := 0
		for r in grp:
			decided[str(r.uid)] = true
			if bool(r.offline) or _flood_silences(r) or str(r.type) == "generator":
				continue
			draw += room_power(r) * mult
		if draw <= 0:
			continue
		if pool >= draw:
			pool -= draw
		elif spare > 0:
			spare -= 1
		else:
			for r in grp:
				dark.append(str(r.uid))
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
		# The meals count measures stores against the whole week's eating, the HUD shows the net after the harvest.
		# While the harvest keeps the net slow, say the meals count is what is left if it fails.
		var harvest := output_of("food") > 0
		if thin and harvest and left <= horizon:
			thin = false
		if thin:
			var meals := maxi(0, int(floor(food_buffer_weeks())))
			when = "is down to %s of meals" % Words.count(meals, "week")
			if harvest:
				when = "stores hold %s of meals if the harvest fails" % Words.count(meals, "week")
				if meals == 0:
					when = "stores are empty, only the harvest feeds the station"
			if left > horizon:
				shown = horizon
		if (key == "food" or key == "air") and _weeks_until_empty("power") <= horizon:
			hint = _supply_hint("generator")
		var stock_text := "%s %s. %s" % [name, when, str(hint.text)]
		if Copy.ru():
			stock_text = "%s %s" % [_ru_stock_when(key, left, thin, maxi(0, int(floor(food_buffer_weeks()))) if thin else left, harvest), str(hint.text)]
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


func crowd_tip() -> String:
	var people := residents.size()
	var beds := housing()
	var n := int(bal.get("overcrowd_discontent", 2))
	var line := ""
	if Copy.ru():
		line = "Людей: %d. Коек: %d." % [people, beds]
		if people > beds:
			line += " Из-за нехватки коек недовольство растёт на %d в неделю." % n
		return line
	line = "People: %d. Beds: %d." % [people, beds]
	if people > beds:
		line += " Not enough beds raises discontent by %d a week." % n
	return line


func flood_line() -> String:
	if flood_guard:
		return ""
	var eta := _flood_eta()
	if eta > flood_warning():
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
	for season in seasons:
		if str(season.id) != "flood":
			continue
		var left := int(season.week) - week
		if left > 0:
			return left
	return 99


func _ru_stock_when(key: String, left: int, thin: bool, meals: int, harvest := false) -> String:
	if key == "food" and thin:
		if harvest and meals == 0:
			return "Запасов еды нет, станцию кормит только урожай."
		if harvest:
			return "Если урожай подведёт, запасов еды хватит на %s." % Words.count(meals, "week")
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
	var push := hardship_push()
	if push != "":
		bits.append(push)
	for fix in fixes:
		bits.append(str(fix.text))
	var first: Dictionary = fixes[0] if not fixes.is_empty() else {}
	return {
		"text": " ".join(bits),
		"weeks": left,
		"hardships": hardships(),
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
		var ids := hardships()
		var hope_hit := -int(tension_push(ids, hope).hope)
		if hope_hit > 0:
			rows.append({"name": hardship_name(str(ids[0])), "amount": hope_hit})
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
		var ids := hardships()
		var strain := tension_push(ids, hope)
		if int(strain.dis) > 0:
			rows.append({"name": hardship_name(str(ids[0])), "amount": int(strain.dis)})
		if int(strain.despair) > 0:
			rows.append({"name": "despair", "amount": int(strain.despair)})
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
		if order_block("address") == "":
			out.append({"hint": "address", "text": Copy.t("Address the platform: hope +1."), "level": -1, "cell": -1})
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
		n += room_power(room)
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
		n += room_power(room)
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
			var draw := room_power(room)
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
		var draw := room_power(room)
		if draw <= 0:
			continue
		rows.append(room)
	rows.sort_custom(func(a, b):
		var da := room_power(a)
		var db := room_power(b)
		if da == db:
			return str(a.uid) < str(b.uid)
		return da < db
	)
	var left := _power_budget()
	if _season_is("cold") or crunch_power:
		left = int(left / 2.0)
	var lost: Array = []
	for room in rows:
		var draw := room_power(room)
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
	var loss := int(round(float(excess) * float(bal.spoil_rate) * _spoil_mult()))
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


## Moves each season's start by up to season_jitter weeks either way, from the seed alone, so a loaded run gets the
## same calendar back. Uses its own stream; the run's RNG is untouched.
func _jitter_seasons() -> void:
	var spread := int(bal.get("season_jitter", 0))
	var roll := RandomNumberGenerator.new()
	roll.seed = seed * 53 + 7
	seasons = []
	for row in bal.get("seasons", []):
		var moved: Dictionary = row.duplicate()
		if spread > 0:
			moved.week = int(row.week) + roll.randi_range(-spread, spread)
		seasons.append(moved)


## This week's hardships as the dawn sees them: "shortage" (food will run short) or "air", else "thin food" (under
## hard_food_weeks of food), "dark rooms" (power short or rooms browning out), "sickness" (hard_sick_share of the
## people sick), "season" (one is on), and "crowd" only when hard_crowd is on.
func hardships() -> Array:
	var food_short := int(resource_outlook("food").next) < 0
	var air_short := int(resource_outlook("air").next) < 0
	var dark := int(resource_outlook("power").next) < 0 or not _brownout_ids().is_empty()
	return _hardship_ids(food_short or air_short, food_short, dark, sick_count())


func _hardship_ids(short_now: bool, food_short: bool, dark: bool, sick: int) -> Array:
	var ids: Array = []
	if short_now:
		ids.append("shortage" if food_short else "air")
	elif food_buffer_weeks() < float(bal.get("hard_food_weeks", 0)):
		ids.append("thin food")
	if dark:
		ids.append("dark rooms")
	if not residents.is_empty() and float(sick) / float(residents.size()) >= float(bal.get("hard_sick_share", 1.0)):
		ids.append("sickness")
	if not active_season.is_empty():
		ids.append("season")
	if bool(bal.get("hard_crowd", false)) and residents.size() > housing():
		ids.append("crowd")
	return ids


## What a week with these hardships does: hope hardship_hope each, up to hardship_cap of them; discontent
## hardship_discontent once (hardship_discontent_early before hardship_ramp_week), or settled_discontent with none;
## despair_discontent more while hope is under despair_hope.
## TODO(Code): comfort_hope and comfort_food_weeks are in the validated set, but the spec does not say how they
## apply, so they do nothing yet.
func tension_push(ids: Array, hope_now: int) -> Dictionary:
	var out := {"hope": 0, "dis": 0, "despair": 0}
	out.hope = mini(ids.size(), int(bal.get("hardship_cap", 0))) * int(bal.get("hardship_hope", 0))
	if not ids.is_empty():
		var each := int(bal.get("hardship_discontent", 0))
		if week < int(bal.get("hardship_ramp_week", 0)):
			each = int(bal.get("hardship_discontent_early", 0))
		out.dis = each * mini(ids.size(), int(bal.get("hardship_dis_cap", 1)))
	elif not bool(bal.get("settled_needs_beds", false)) or residents.size() <= housing():
		out.dis = int(bal.get("settled_discontent", 0))
	if hope_now < int(bal.get("despair_hope", 0)):
		out.despair = int(bal.get("despair_discontent", 0))
	return out


func _tension(ids: Array) -> void:
	hardship_now = []
	for id in ids:
		hardship_now.append(str(id))
	var push := tension_push(ids, hope)
	_add_hope(int(push.hope), "hardship")
	_add_discontent(int(push.dis), "hardship" if not ids.is_empty() else "settled")
	_add_discontent(int(push.despair), "despair")


## Rival agents stir the yard; from agent_late_week they push harder.
func agent_push() -> int:
	var n := int(bal.get("agent_discontent", 0))
	if week >= int(bal.get("agent_late_week", 999)):
		n += int(bal.get("agent_late_bonus", 0))
	return n


func sick_count() -> int:
	var n := 0
	for person in residents:
		if int(person.get("sick", 0)) > 0:
			n += 1
	return n


## A hardship as a short phrase for lists and the revolt warning (Copy keys hardship.*).
func hardship_name(id: String) -> String:
	match id:
		"shortage", "thin food":
			return "low food stores"
		"air":
			return "not enough air"
		"dark rooms":
			return "dark rooms"
		"sickness":
			return "the sick"
		"season":
			return "the %s" % str(active_season.get("id", "season"))
		"crowd":
			return "the crowd"
	return id


## The revolt warning's push sentence from the first one or two hardships; "" when there are none.
func hardship_push() -> String:
	var ids := hardships()
	if ids.is_empty():
		return ""
	var first := Copy.t(hardship_name(str(ids[0])))
	if ids.size() == 1:
		return Copy.t("Pushing toward revolt: %s.") % first
	return Copy.t("Pushing toward revolt: %s and %s.") % [first, Copy.t(hardship_name(str(ids[1])))]


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
	_add_discontent(agent_push(), "agent")
	_note("AGENT a rival rumor moves through the yard", "AGENT По станции ползёт слух, пущенный соперником.")


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
	var skip := int(flags.get("filter_skip", 0)) > 0
	if skip:
		flags.erase("filter_skip")
	for room in rooms:
		if room.type != "air_filter":
			continue
		var upkeep := filter_upkeep(room)
		if skip or int(stock.materials) >= upkeep:
			if not skip:
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
		spot = _merge_build_cell(type)
		if spot.is_empty():
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
	stock.materials = int(stock.materials) - dig_material_cost()
	dig = {"level": level, "cell": cell, "left": int(cost.turns), "workers": workers}
	decisions += 1
	_log("DIG L%d C%d (%d turns)" % [level, cell, int(cost.turns)])
	return true


func dig_preview(level: int, cell: int) -> Dictionary:
	var key := _ck(level, cell)
	if not cells.has(key):
		return {"ok": false, "reason": Copy.t("No such cell."), "turns": 0, "workers": 0, "materials": dig_material_cost()}
	var spot: Dictionary = cells[key]
	var cost := _dig_cost(level)
	var info := {
		"ok": false,
		"reason": "",
		"turns": int(cost.turns),
		"workers": int(cost.workers),
		"materials": dig_material_cost(),
	}
	if bool(spot.dug):
		info.reason = Copy.t("Already open.")
		return info
	if not _beside_dug(spot):
		info.reason = Copy.t("Solid rock. Dig from a cell that touches an open one.")
		return info
	if not clear.is_empty():
		info.reason = Copy.t("clear.busy")
		return info
	if not dig.is_empty():
		info.reason = Copy.t("A crew is already digging.")
		return info
	var reasons: PackedStringArray = []
	if int(stock.materials) < dig_material_cost():
		reasons.append(Copy.t("Needs %s, the yard has %s.") % [Words.count(dig_material_cost(), "material"), Words.count(int(stock.materials), "material")])
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
	if cells.has(key) and str(cells[key].get("pile", "")) != "":
		info.reason = Copy.t("clear.blocked_build")
		return info
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
	if type == "listening_post":
		var radio := listening_build_block()
		if radio != "":
			reasons.append(radio)
	var cap := int(defin.get("max", 0))
	if cap > 0 and room_count(type) >= cap:
		info.reason = " ".join(reasons)
		info.ok = false
		return info
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
	info.materials = upgrade_cost(str(room.type), int(room.upgrade) + 1)
	if steps.is_empty():
		return info
	if int(room.upgrade) >= steps.size():
		info.reason = Copy.t("Nothing left to upgrade.")
		return info
	info.name = str(steps[int(room.upgrade)])
	if bool(room.offline):
		info.reason = Copy.t("The room is offline.")
		return info
	var node := salvage_for_step(str(room.type), int(room.upgrade) + 1)
	if not node.is_empty():
		info.tier = int(node.tier)
		info.node = str(node.id)
		info.blueprints = 1 if int(node.tier) >= 1 else 0
		var gate := salvage_gate(node)
		if gate != "":
			info.reason = gate
			return info
	if int(stock.materials) < info.materials:
		info.reason = Copy.t("Needs %s, the yard has %s.") % [Words.count(info.materials, "material"), Words.count(int(stock.materials), "material")]
		return info
	info.ok = true
	return info


## Materials for upgrading a room of this type to the given tier: upgrade_materials times the tier's
## multiplier from balance.json upgrade_step_cost (tiers past the list use its last value), rounded up.
func upgrade_cost(type: String, tier: int) -> int:
	var base := int(catalog.rooms[type].get("upgrade_materials", 0))
	var step: Array = bal.get("upgrade_step_cost", [1.0])
	if step.is_empty() or tier < 1:
		return base
	return ceili(base * float(step[mini(tier, step.size()) - 1]) - 0.0001)


func salvage_def(id: String) -> Dictionary:
	for row in SALVAGE_NODES:
		if str(row.id) == id:
			return row
	return {}


func salvage_for_step(type: String, step: int) -> Dictionary:
	for row in SALVAGE_NODES:
		if str(row.room) == type and int(row.step) == step:
			return row
	return {}


## "" when the node can be fitted. Tier 1+ needs a blueprint. Pipe taps wait until a Listening Post exists.
func salvage_gate(node: Dictionary) -> String:
	if str(node.get("id", "")) == "pipe_taps" and not _listening_post_built():
		return Copy.t("salvage.need_listening")
	if int(node.get("tier", 0)) >= 1 and int(stock.get("blueprints", 0)) < 1:
		return Copy.t("salvage.need_blueprint")
	return ""


func _listening_post_built() -> bool:
	if catalog == null or not catalog.rooms.has("listening_post"):
		return false
	for room in rooms:
		if str(room.type) == "listening_post":
			return true
	return false


func salvage_fit_uid(id: String) -> String:
	var node := salvage_def(id)
	if node.is_empty() or not catalog.rooms.has(str(node.room)):
		return ""
	if salvage_gate(node) != "":
		return ""
	var step := int(node.step)
	for room in rooms:
		if str(room.type) != str(node.room) or bool(room.offline):
			continue
		if int(room.upgrade) == step - 1:
			return str(room.uid)
	return ""


## Desk rows: fitted, the room that can take the fit, and why a locked node is locked.
func salvage_board() -> Array:
	var rows: Array = []
	for node in SALVAGE_NODES:
		var copy: Dictionary = node.duplicate()
		var type := str(node.room)
		var step := int(node.step)
		var fitted := false
		var uid := ""
		for room in rooms:
			if str(room.type) != type:
				continue
			if int(room.upgrade) >= step:
				fitted = true
			elif uid == "" and int(room.upgrade) == step - 1 and not bool(room.offline):
				uid = str(room.uid)
		copy.fitted = fitted
		copy.uid = uid
		copy.blueprints = 1 if int(node.tier) >= 1 else 0
		copy.materials = upgrade_cost(type, step) if catalog.rooms.has(type) else 0
		copy.name_key = "salvage.node." + str(node.id)
		copy.gate = ""
		copy.reason = ""
		if not fitted:
			if str(node.id) == "pipe_taps" and not _listening_post_built():
				copy.gate = "listening"
				copy.reason = Copy.t("salvage.need_listening")
			elif uid == "":
				copy.gate = "room"
			elif int(node.tier) >= 1 and int(stock.get("blueprints", 0)) < 1:
				copy.gate = "blueprint"
				copy.reason = Copy.t("salvage.locked")
			else:
				var info := upgrade_preview(uid)
				if not bool(info.ok):
					copy.gate = "wait"
					copy.reason = str(info.reason)
		rows.append(copy)
	return rows


## Which clipboard the desk shows. Nothing fitted yet is the empty board. Once a fit is on the board and a
## later node is waiting on a blueprint, the locked clipboard replaces it. Otherwise the working board.
func salvage_face_of(rows: Array) -> String:
	var fitted := false
	var need_blueprint := false
	for row in rows:
		if bool(row.get("fitted", false)):
			fitted = true
		if str(row.get("gate", "")) == "blueprint":
			need_blueprint = true
	if not fitted:
		return "empty"
	if need_blueprint:
		return "no_blueprint"
	return "board"


func salvage_face() -> String:
	return salvage_face_of(salvage_board())


func strip_preview() -> Dictionary:
	var info := {"ok": false, "reason": "", "materials": STRIP_MATERIALS}
	var reasons: PackedStringArray = []
	if not _room_ready("workshop"):
		reasons.append(Copy.t("salvage.strip_tip"))
	var last := int(salvage.get("strip_week", 0))
	if last > 0 and week < last + STRIP_EVERY:
		reasons.append(Copy.t("salvage.strip_tip"))
	if int(stock.get("materials", 0)) < STRIP_MATERIALS:
		reasons.append(Copy.t("Needs %s, the yard has %s.") % [Words.count(STRIP_MATERIALS, "material"), Words.count(int(stock.materials), "material")])
	info.reason = " ".join(reasons)
	info.ok = reasons.is_empty()
	return info


func _apply_strip() -> bool:
	var info := strip_preview()
	if not bool(info.ok):
		return false
	stock.materials = int(stock.materials) - STRIP_MATERIALS
	salvage.strip_week = week
	_gain_blueprint("strip")
	decisions += 1
	_log("STRIP scrap, blueprint")
	return true


func _gain_blueprint(source: String) -> void:
	stock.blueprints = int(stock.get("blueprints", 0)) + 1
	var line := Copy.t("salvage.gained_%s" % source)
	notices.append(line)
	_log(line, true)


func _grant_first_raid_blueprint() -> void:
	if bool(salvage.get("raid_bp", false)):
		return
	salvage.raid_bp = true
	_gain_blueprint("raid")


## P2 Junk good is not on this master: station goods have no "junk", and nothing sets flags.junk_flow.
## When that flow exists, a held junk source grants +1 blueprint every 6 weeks.
func junk_flowing() -> bool:
	if bool(flags.get("junk_flow", false)):
		return true
	if catalog == null or not stations.has("clocktower"):
		return false
	if str(stations.clocktower.get("owner", "")) != player:
		return false
	return int(catalog.station_goods("clocktower").get("junk", 0)) > 0


func _grant_junk_blueprints() -> void:
	if not junk_flowing() or week % JUNK_EVERY != 0:
		return
	if int(salvage.get("junk_week", 0)) == week:
		return
	salvage.junk_week = week
	_gain_blueprint("junk")


func take_salvage_float() -> Dictionary:
	var id := str(salvage.get("float_id", ""))
	var uid := str(salvage.get("float_uid", ""))
	salvage.float_id = ""
	salvage.float_uid = ""
	if id == "":
		return {}
	return {"id": id, "uid": uid}


func _ready_salvage() -> void:
	if typeof(salvage) != TYPE_DICTIONARY:
		salvage = {}
	salvage.strip_week = int(salvage.get("strip_week", 0))
	salvage.floated = bool(salvage.get("floated", false))
	salvage.raid_bp = bool(salvage.get("raid_bp", false))
	salvage.float_id = str(salvage.get("float_id", ""))
	salvage.float_uid = str(salvage.get("float_uid", ""))
	salvage.junk_week = int(salvage.get("junk_week", 0))
	if typeof(stock) != TYPE_DICTIONARY:
		return
	stock.blueprints = maxi(0, int(stock.get("blueprints", 0)))


## Flat +1 food on a hydroponics room once mushroom beds are fitted. Hope does not move on the fit.
func mushroom_food(room, tier: int = -1) -> int:
	var at := int(room.upgrade) if tier < 0 else tier
	if str(room.get("type", "")) != "hydroponics" or at < 2:
		return 0
	if bool(room.get("offline", false)):
		return 0
	return 1


func _pressure_seals_online() -> bool:
	for room in rooms:
		if str(room.type) == "air_filter" and int(room.upgrade) >= 2 and not bool(room.offline):
			return true
	return false


func cough_spread_chance() -> float:
	var chance := float(bal.cough_spread) * station_fx("cough_spread")
	if _pressure_seals_online():
		chance *= 0.8
	return chance


func _substation_online() -> bool:
	for room in rooms:
		if str(room.type) == "generator" and int(room.upgrade) >= 2 and not bool(room.offline):
			return true
	return false


## One extra room stays lit when a substation is online.
func brownout_spare() -> int:
	return 1 if _substation_online() else 0


func _antenna_online() -> bool:
	for room in rooms:
		if str(room.type) == "radio" and int(room.upgrade) >= 1 and not bool(room.offline):
			return true
	return false


func _listening_post_online() -> bool:
	if not _listening_post_built():
		return false
	for room in rooms:
		if str(room.type) == "listening_post" and not bool(room.offline):
			return true
	return false


## Listening Post, when that room exists, hides nothing. Otherwise a staffed radio already hides nothing,
## and an antenna cuts whatever hide chance remains in half.
func intent_hide_chance() -> float:
	if _listening_post_online():
		return 0.0
	var chance := 0.0 if _has_radio() else 0.25
	if chance > 0.0 and _antenna_online():
		chance *= 0.5
	return chance


## P29 owns the blown roll. Pipe taps cut that chance by 5% once the Listening Post upgrade is fitted.
func blown_scale() -> float:
	for room in rooms:
		if str(room.type) == "listening_post" and int(room.get("upgrade", 0)) >= 1 and not bool(room.get("offline", false)):
			return 0.95
	return 1.0


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
	var node := salvage_for_step(str(room.type), int(room.upgrade) + 1)
	stock.materials = int(stock.materials) - int(info.materials)
	if not node.is_empty() and int(node.tier) >= 1:
		stock.blueprints = int(stock.get("blueprints", 0)) - 1
	for r in _merge_group_of(room):
		r.upgrade = int(r.upgrade) + 1
	if not node.is_empty() and not bool(salvage.get("floated", false)):
		salvage.floated = true
		salvage.float_id = str(node.id)
		salvage.float_uid = uid
	if str(info.name) == "armor" and squads.has(player) and not bool(squads[player].get("armor_fit", false)):
		squads[player].gear = float(squads[player].gear) + float(bal.get("armor_gear", 0.15))
		squads[player].armor_fit = true
		var plate := Copy.t("combat.toast.armor")
		notices.append(plate)
		_log(plate, true)
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
	people[person_id]["post"] = uid
	people[person_id]["seat_weeks"] = 0
	decisions += 1
	_log("ASSIGN %s to %s" % [people[person_id].name, catalog.rooms[room.type].name])
	if str(room.type) == "listening_post":
		notices.append(listening_assign_line(person_id))
	return true


func _apply_unassign(person_id: String) -> bool:
	if not people.has(person_id):
		return false
	people[person_id].erase("post")
	people[person_id]["seat_weeks"] = 0
	_unassign(person_id)
	decisions += 1
	_log("UNASSIGN %s" % people[person_id].name)
	return true


func switch_preview(uid: String) -> Dictionary:
	var info := {"can": false, "on": true, "saves": 0, "reason": ""}
	var room = _room(uid)
	if room == null:
		return info
	var draw := room_power(room)
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
	if _is_child(person) or int(person.sick) > 0 or int(person.absent) > 0:
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
	var outputs := _room_output_rows(room)
	var extra := 0.0
	for value in skills:
		if float(value) > 1.0:
			extra += float(value) - 1.0
	var group: Array = _merge_group_of(room)
	var width := group.size()
	var cell_list: Array = []
	var block_staff := 0
	var block_power := 0
	var block_staff_max := 0
	for r in group:
		cell_list.append(int(r.cell))
		block_staff += int(r.staff.size())
		block_staff_max += int(catalog.rooms[str(r.type)].get("staff_max", 0))
		if not bool(r.get("switched_off", false)):
			block_power += room_power(r)
	var crew_need := int(defin.get("staff_min", 0))
	if width > 1:
		crew_need = crew_need * width - int(bal.get("merge_crew_saving", 1)) * (width - 1)
		crew_need = maxi(0, crew_need)
	var block_outputs: Array = []
	var bonus_n := 0
	if width > 1 and str(room.type) == "quarters":
		bonus_n = int(bal.get("merge_housing", 2)) * (width - 1)
	elif width > 1:
		var seen := {}
		for r in group:
			for row in _room_output_rows(r):
				var key := str(row.key)
				if not seen.has(key):
					seen[key] = 0
				seen[key] = int(seen[key]) + int(row.amount)
		for key in seen:
			var base_sum := int(seen[key])
			var bonus := _merge_key_bonus(base_sum, width)
			if bonus_n == 0:
				bonus_n = bonus
			block_outputs.append({"key": key, "base": base_sum, "bonus": bonus, "total": base_sum + bonus})
	var note := ""
	if width >= 2:
		note = Copy.t("merge.disaster") % width
	return {
		"uid": uid,
		"type": str(room.type),
		"name": str(defin.name),
		"level": int(room.level),
		"cell": int(room.cell),
		"skill": skill,
		"staff": staff,
		"staff_max": int(defin.staff_max),
		"power": room_power(room),
		"outputs": outputs,
		"upgrade": int(room.upgrade),
		"offline": bool(room.offline),
		"skill_extra": extra,
		"multiplier": minf(float(bal.output_cap), 1.0 + float(bal.skill_coef) * extra),
		"block_width": width,
		"merge_bonus": bonus_n,
		"crew_need": crew_need,
		"cells": cell_list,
		"disaster_note": note,
		"block_power": block_power,
		"block_outputs": block_outputs,
		"block_staff": block_staff,
		"block_staff_max": block_staff_max,
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
			var cap := int(defin.get("max", 0))
			if cap > 0 and room_count(str(type)) >= cap:
				continue
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
	stock.materials = int(stock.materials) - dig_material_cost()
	dig = {"level": int(cell.level), "cell": int(cell.cell), "left": int(cost.turns), "workers": workers}
	decisions += 1
	_log("DIG L%d C%d (%d turns)" % [int(cell.level), int(cell.cell), int(cost.turns)])
	return true


## Seasonal water leaves when the flood weeks end. A pump can clear it sooner. Rooms the player switched
## off stay off.
func _recede_flood() -> void:
	var names: PackedStringArray = []
	var any := false
	for key in cells:
		if not bool(cells[key].get("flooded", false)):
			continue
		any = true
		cells[key].flooded = false
		var uid := str(cells[key].room)
		var flooded_room = _room(uid)
		if uid != "" and flooded_room != null:
			flooded_room.offline = bool(flooded_room.get("switched_off", false))
			names.append(Copy.t(str(catalog.rooms[flooded_room.type].name)))
	if not any:
		return
	if names.is_empty():
		_note("SEASON The water is down.", "SEASON Вода сошла.")
	else:
		_note("SEASON The water is down. %s are working again." % ", ".join(names), "SEASON Вода сошла. Снова работают: %s." % ", ".join(names))


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
	if law_id == "sermons":
		_perk_sermons_hope()
	if defin.has("discontent_on_enact"):
		_add_discontent(int(defin.discontent_on_enact), "law")
	if defin.has("materials_on_enact"):
		stock.materials = int(stock.materials) + int(defin.materials_on_enact)
	if defin.has("opinion_on_enact"):
		for fid in opinions:
			_add_opinion(fid, int(defin.opinion_on_enact))
	if bool(defin.get("line", false)):
		_note_moment("creed_line", {"law": str(defin.name)}, 5)
		if str(defin.get("creed", "")) != "":
			creed = str(defin.creed)
	if law_id == "conscription":
		for _i in int(defin.squad_bonus):
			var pick := _recruit_pick()
			if pick == "":
				break
			_enlist(pick)
		var sq: Dictionary = squads[player]
		sq.max_size = int(sq.get("max_size", sq.size)) + int(defin.squad_bonus)
		if sq.has("roster"):
			_fill_roster(sq, int(sq.max_size))
	decisions += 1
	_log("LAW %s" % defin.name, true)
	return true


func _advance_jobs() -> void:
	if not build.is_empty():
		build.left = int(build.left) - 1
		if int(build.left) <= 0:
			var crew: Array = build.get("workers", []).duplicate()
			_place_room(str(build.type), int(build.level), int(build.cell))
			_log("%s is finished" % catalog.rooms[str(build.type)].name)
			_journal("built", {"type": str(build.type)})
			build = {}
			_restore_posts(crew)
	if not dig.is_empty():
		dig.left = int(dig.left) - 1
		if int(dig.left) <= 0:
			var crew: Array = dig.get("workers", []).duplicate()
			_finish_dig()
			_restore_posts(crew)
	if not clear.is_empty():
		clear.left = int(clear.left) - 1
		if int(clear.left) <= 0:
			var crew: Array = clear.get("workers", []).duplicate()
			_finish_clear()
			_restore_posts(crew)


## "requires": "digging" holds while a crew is digging and the week after it breaks through, when the new
## room is still open and nobody has cleared it.
func _digging_now() -> bool:
	return not dig.is_empty() or week - int(flags.get("dig_done_week", -99)) <= 1


func _finish_dig() -> void:
	flags["dig_done_week"] = week
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
	_offer_rubble(cell)
	dig = {}


## DEC-C1. Weeks, crew, tool mats, yield band, and sick chance. Charter trims weeks; drill heads do not.
const PILE_CAP := 3
const PILE := {
	"rubble": {"weeks": 1, "crew": 2, "materials": 0, "lo": 4, "hi": 6, "risk": 8},
	"scrap": {"weeks": 1, "crew": 2, "materials": 1, "lo": 7, "hi": 9, "risk": 8},
	"coal": {"weeks": 2, "crew": 2, "materials": 0, "lo": 5, "hi": 7, "risk": 12},
}


func pile_count() -> int:
	var n := 0
	for key in cells:
		if str(cells[key].get("pile", "")) != "":
			n += 1
	return n


## First cell carrying this pile kind, or any pile when kind is empty.
func pile_spot(kind: String = "") -> Dictionary:
	for key in cells:
		var cell: Dictionary = cells[key]
		var pile := str(cell.get("pile", ""))
		if pile == "" or (kind != "" and pile != kind):
			continue
		return cell
	return {}


func clear_weeks(kind: String) -> int:
	var row: Dictionary = PILE.get(kind, {})
	var turns := int(row.get("weeks", 1))
	if _law_on("engineers_charter"):
		turns = maxi(1, turns - int(catalog.laws.engineers_charter.get("dig_faster", 1)))
	return maxi(1, turns)


func clear_preview(level: int, cell: int) -> Dictionary:
	var info := {
		"ok": false,
		"reason": "",
		"weeks": 0,
		"turns": 0,
		"workers": 2,
		"materials": 0,
		"kind": "",
		"risk_pct": 0,
		"risk_hope": false,
	}
	var key := _ck(level, cell)
	if not cells.has(key):
		info.reason = Copy.t("No such cell.")
		return info
	var spot: Dictionary = cells[key]
	var kind := str(spot.get("pile", ""))
	if kind == "" or not PILE.has(kind):
		info.reason = Copy.t("Already open.")
		return info
	var row: Dictionary = PILE[kind]
	info.kind = kind
	info.weeks = clear_weeks(kind)
	info.turns = int(info.weeks)
	info.workers = int(row.crew)
	info.materials = int(row.materials)
	info.risk_pct = int(row.risk)
	info.risk_hope = kind == "coal"
	if not dig.is_empty():
		info.reason = Copy.t("clear.dig_busy")
		return info
	if not clear.is_empty():
		info.reason = Copy.t("clear.busy")
		return info
	var reasons: PackedStringArray = []
	if int(info.materials) > 0 and int(stock.materials) < int(info.materials):
		reasons.append(Copy.t("Needs %s, the yard has %s.") % [Words.count(int(info.materials), "material"), Words.count(int(stock.materials), "material")])
	if _free_count() < int(info.workers):
		reasons.append(Copy.t("Needs %s free. %s are free.") % [Words.count(int(info.workers), "person", "people"), Words.count(_free_count(), "person", "people")])
	info.reason = " ".join(reasons)
	info.ok = reasons.is_empty()
	return info


func _apply_clear(level: int, cell: int) -> bool:
	var info := clear_preview(level, cell)
	if not bool(info.ok):
		return false
	var workers := _pull_workers(int(info.workers), "labor")
	if workers.size() < int(info.workers):
		return false
	if int(info.materials) > 0:
		stock.materials = int(stock.materials) - int(info.materials)
	clear = {
		"level": level,
		"cell": cell,
		"left": int(info.weeks),
		"workers": workers,
		"kind": str(info.kind),
	}
	decisions += 1
	_log("CLEAR %s L%d C%d (%d turns)" % [str(info.kind), level, cell, int(info.weeks)])
	return true


func _finish_clear() -> void:
	var kind := str(clear.get("kind", ""))
	var level := int(clear.get("level", 0))
	var cell_i := int(clear.get("cell", 0))
	var workers: Array = clear.get("workers", []).duplicate()
	var key := _ck(level, cell_i)
	if cells.has(key):
		cells[key].erase("pile")
	var row: Dictionary = PILE.get(kind, {})
	var gained := _pile_yield(kind, level, cell_i)
	stock.materials = int(stock.materials) + gained
	var rest := kind == "coal" and _has_air_filter()
	if rest:
		flags["filter_skip"] = 1
	var toast_key := "clear.toast_coal" if rest else "clear.toast_mats"
	notices.append(Copy.clip(Copy.fill(toast_key, {"n": str(gained)}), 72))
	if not bool(flags.get("cleared_once", false)):
		flags["cleared_once"] = true
		_note_moment("clear", {}, 1)
	_pile_risk(kind, workers, level, cell_i, int(row.get("risk", 0)))
	clear = {}
	clear_burst_seq += 1
	clear_burst = {"level": level, "cell": cell_i, "seq": clear_burst_seq}
	_log("CLEAR done %s +%d" % [kind, gained])


func _pile_risk(kind: String, workers: Array, level: int, cell_i: int, risk: int) -> void:
	var claustro := false
	for id in workers:
		if people.has(str(id)) and _has_trait(people[str(id)], "Claustrophobic"):
			claustro = true
	if kind == "coal" and claustro:
		_add_hope(-1, "trait")
	if workers.is_empty() or _clear_roll(level * 100 + cell_i + 1) >= risk:
		return
	var hit := str(workers[posmod(_clear_roll(level * 100 + cell_i + 3), workers.size())])
	if not people.has(hit):
		return
	people[hit].sick = maxi(int(people[hit].sick), 1)
	var bark := Copy.t("clear.hurt")
	notices.append(Copy.clip(bark, 72))
	_log(bark, true)


func _pile_yield(kind: String, level: int, cell_i: int) -> int:
	var row: Dictionary = PILE.get(kind, {})
	var lo := int(row.get("lo", 0))
	var hi := int(row.get("hi", lo))
	var span := maxi(1, hi - lo + 1)
	return lo + posmod(_clear_roll(level * 100 + cell_i + 2), span)


## Stable 0–99. Does not draw from the week rng, so dig accidents stay on their old stream.
func _clear_roll(salt: int) -> int:
	return posmod(int(seed) * 31 + int(week) * 17 + salt * 13, 100)


func _has_air_filter() -> bool:
	for room in rooms:
		if str(room.type) == "air_filter":
			return true
	return false


func _offer_rubble(cell: Dictionary) -> void:
	if not bool(cell.get("dug", false)) or str(cell.get("room", "")) != "":
		return
	if str(cell.get("pile", "")) != "" or bool(cell.get("flooded", false)):
		return
	if str(cell.get("find", "")) != "":
		return
	if pile_count() >= PILE_CAP:
		return
	var salt := int(cell.level) * 100 + int(cell.cell)
	if _clear_roll(salt) >= 20:
		return
	var spot := _spawn_spot(cell)
	if spot.is_empty():
		return
	spot["pile"] = "rubble"


## Week 1 starts one room: the bot's single project, and the floor a player taps.
const WEEK1_FLOOR_TAKES := 1


## A later pile's floor. The new dig floor is kept when it is allowed. Preferred week-1 floors are used only when no other empty floor exists.
func _spawn_spot(prefer: Dictionary = {}) -> Dictionary:
	var open := _empty_dug_spots()
	if open.is_empty():
		return {}
	var held := {}
	for cell in _preferred_early_floors():
		held[_ck(int(cell.level), int(cell.cell))] = true
	var others: Array = []
	for cell in open:
		if not held.has(_ck(int(cell.level), int(cell.cell))):
			others.append(cell)
	var pool: Array = others if not others.is_empty() else open
	if not prefer.is_empty():
		var want := _ck(int(prefer.level), int(prefer.cell))
		for cell in pool:
			if _ck(int(cell.level), int(cell.cell)) == want:
				return cell
	return pool[0]


## Empty floors in the order `_first_build_cell()` would hand them out: lowest level, first in grid order.
func _build_floor_order() -> Array:
	var pool := _open_floors(true)
	var order: Array = []
	while not pool.is_empty():
		var best_i := 0
		var best_level := 99
		for i in pool.size():
			var level := int(pool[i].level)
			if level < best_level:
				best_level = level
				best_i = i
		order.append(pool[best_i])
		pool.remove_at(best_i)
	return order


## Floors week 1 would build on: every empty floor at the lowest level, then the next
## floors in that same order if week 1 would take more than that tier.
func _preferred_early_floors() -> Array:
	var order := _build_floor_order()
	if order.is_empty():
		return []
	var lowest := int(order[0].level)
	var preferred: Array = []
	for cell in order:
		if int(cell.level) != lowest:
			break
		preferred.append(cell)
	var i := preferred.size()
	while preferred.size() < WEEK1_FLOOR_TAKES and i < order.size():
		preferred.append(order[i])
		i += 1
	return preferred


func _open_floors(ignore_piles: bool) -> Array:
	var rows: Array = []
	for key in cells:
		var cell: Dictionary = cells[key]
		if not bool(cell.dug) or str(cell.room) != "" or bool(cell.get("flooded", false)) or bool(cell.get("walled", false)):
			continue
		if not ignore_piles and str(cell.get("pile", "")) != "":
			continue
		rows.append(cell)
	return rows


## Empty dug floor with no room and no pile. Level 2 first, then the rest in grid order.
func _empty_dug_spots() -> Array:
	var rows: Array = []
	for key in cells:
		var cell: Dictionary = cells[key]
		if not bool(cell.dug) or str(cell.room) != "" or str(cell.get("pile", "")) != "":
			continue
		if bool(cell.get("flooded", false)):
			continue
		rows.append(cell)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := 0 if int(a.level) == 2 else 1
		var pb := 0 if int(b.level) == 2 else 1
		if pa != pb:
			return pa < pb
		if int(a.level) != int(b.level):
			return int(a.level) < int(b.level)
		return int(a.cell) < int(b.cell)
	)
	return rows


## Weeks 4, 10 and 16: one coal or scrap if the yard has fewer than two piles and food is not in crisis.
func _drip_piles() -> void:
	if week < 4 or week > 20 or posmod(week - 4, 6) != 0:
		return
	if pile_count() >= 2 or food_buffer_weeks() < 1.0:
		return
	var spot := _spawn_spot()
	if spot.is_empty():
		return
	spot["pile"] = "coal" if _clear_roll(week * 9 + 4) < 50 else "scrap"


func _dig_cost(level: int) -> Dictionary:
	var turns := 1 + level
	if _law_on("engineers_charter"):
		turns = maxi(1, turns - int(catalog.laws.engineers_charter.dig_faster))
	turns = maxi(1, turns + int(station_fx("dig_turns")))
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
	if week != int(active_season.start):
		return
	if flags.has("leak_patched"):
		flood_guard = true
		_note("SEASON The patched pipes hold. The flood does not reach the rooms.", "SEASON Заплатка держит. Паводок не доходит до комнат.")
		return
	if pumped or flood_guard:
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
	for extra in _flood_merge_blocks():
		names.append(str(extra))
	if _any_trait("Claustrophobic"):
		_add_hope(-2, "trait")
	if names.is_empty():
		_note("SEASON Flood on level %d." % lowest, "SEASON Паводок на уровне %d." % lowest)
	else:
		_note("SEASON Flood on level %d (%s)." % [lowest, ", ".join(names)], "SEASON Паводок на уровне %d (%s)." % [lowest, ", ".join(names)])
	_journal("flood", {"level": lowest})


func _needs_pump() -> bool:
	for key in cells:
		if cells[key].flooded:
			return true
	if flood_guard:
		return false
	return _flood_eta() <= flood_warning()


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
		"patrol":
			ok = _order_patrol(str(action.get("dest", "")))
		"raid":
			ok = _order_raid(str(action.get("dest", action.get("station", ""))), true)
		"assault":
			ok = _order_assault(str(action.get("dest", action.get("station", ""))), true)
		"breach":
			ok = _order_breach()
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
		"probe":
			ok = _order_probe(str(action.get("station", action.get("dest", ""))))
		"tap":
			ok = _order_tap(str(action.get("faction", "")))
	if ok:
		if order == "probe" or order == "tap":
			flags["listening_order_week"] = week
		orders_left -= 1
		decisions += 1
		_take_seat(order)
		if order == "trade":
			_vo_cue("caravan_arrived")
			flags["first_caravan"] = flags.get("first_caravan", week)
	return ok


## What propaganda adds at a station: the full swing, or only what is left to 100, so the last push does not
## waste sympathy.
func propaganda_gain(sid: String) -> int:
	if not stations.has(sid):
		return 0
	var gap := maxi(0, 100 - int(stations[sid].get("sympathy", 0)))
	return mini(sympathy_preview(sid), gap)


## Propaganda's price: the full price for a full swing, or that share of it when the station needs less (rounded
## up, at least 1), so five pushes of 22 toward 100 cost 6 + 6 + 6 + 6 + 4.
func propaganda_cost(sid: String) -> int:
	var full := int(bal.propaganda_influence)
	var swing := sympathy_preview(sid)
	var gain := propaganda_gain(sid)
	if swing <= 0 or gain >= swing:
		return full
	return maxi(1, int(ceil(float(full) * float(gain) / float(swing))))


func _order_propaganda(sid: String) -> bool:
	if _propaganda_block(sid) != "":
		return false
	var st: Dictionary = stations[sid]
	var before_sym := int(st.sympathy)
	var gain := propaganda_gain(sid)
	stock.influence = int(stock.influence) - propaganda_cost(sid)
	st.sympathy = before_sym + gain
	var after_sym := int(st.sympathy)
	_log("ORDER propaganda %s +%d (%d)" % [st.name, gain, after_sym])
	var joined := false
	if after_sym >= 100:
		joined = _capture(sid, player, false)
	if after_sym >= 70:
		st.leaflet_until = int(week) + 2
	if joined:
		st.join_pulse = true
	_stamp_soft_note(st, sid, "propaganda", before_sym, after_sym, gain, "", 0.0, 0.0, int(st.get("deals", 0)), joined)
	return true


func _order_envoy(sid: String) -> bool:
	if _envoy_block(sid) != "":
		return false
	var st: Dictionary = stations[sid]
	var before_sym := int(st.sympathy)
	var need_id := _lowest_need(st)
	var need_before := _need_fill(st, need_id)
	stock.influence = int(stock.influence) - 3
	_bump_need(st, need_id, 0.2)
	var need_after := _need_fill(st, need_id)
	var gain := maxi(2, int(round(float(sympathy_preview(sid)) * 0.35)))
	st.sympathy = before_sym + gain
	var after_sym := int(st.sympathy)
	_log("ORDER envoy %s +%d (%d)" % [st.name, gain, after_sym])
	var joined := false
	if after_sym >= 100:
		joined = _capture(sid, player, false)
	if joined:
		st.join_pulse = true
	_stamp_soft_note(st, sid, "envoy", before_sym, after_sym, gain, need_id, need_before, need_after, int(st.get("deals", 0)), joined)
	return true


func _order_deal(sid: String) -> bool:
	if _deal_block(sid) != "":
		return false
	var st: Dictionary = stations[sid]
	var before_sym := int(st.sympathy)
	var need_id := _lowest_need(st)
	var need_before := _need_fill(st, need_id)
	stock.influence = int(stock.influence) - 4
	st.deals = int(st.get("deals", 0)) + 1
	st.passage = true
	_bump_need(st, need_id, 0.25)
	var need_after := _need_fill(st, need_id)
	stock.food = int(stock.food) + 4
	stock.materials = int(stock.materials) + 2
	_log("DEAL %s (%d)" % [st.name, int(st.deals)], true)
	var joined := false
	if int(st.deals) >= 3 and str(st.owner) == "neutral":
		_log("DEAL %s asks to join" % st.name, true)
		joined = _capture(sid, player, false)
	if joined:
		st.join_pulse = true
	_stamp_soft_note(st, sid, "deal", before_sym, before_sym, 0, need_id, need_before, need_after, int(st.deals), joined)
	return true


## Why an order is short of influence; names the meeting hall while the station has none, since it makes nearly
## all of it.
func influence_short() -> String:
	var why := Copy.t("Not enough influence.")
	if room_count("meeting_hall") == 0:
		why += " " + Copy.t("A meeting hall makes it.")
	return why


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
		if str(seat_used.get(role, "")) != "" or busy.has(pid) or governor_of(pid) != "":
			continue
		var person: Dictionary = people.get(pid, {})
		return {"role": role, "id": pid, "name": str(person.get("name", role))}
	return {}


func order_cost(kind: String, _sid: String = "") -> Dictionary:
	match kind:
		"propaganda":
			return {"influence": propaganda_cost(_sid)}
		"envoy":
			return {"influence": 3}
		"trade":
			return {"influence": 4}
		"address":
			return {"influence": int(bal.get("address_influence", 3))}
		"move":
			var food := move_food(_sid)
			return {"food": food} if food > 0 else {}
		"gift":
			return {"tokens": int(bal.get("gift_tokens", 0))}
		"aid":
			if not stations.has(_sid):
				return {}
			return _aid_price(_lowest_need(stations[_sid]))
		"pay":
			var due: Dictionary = open_demand_for(_sid)
			if due.is_empty():
				return {}
			return {"tokens": int(due.get("amount", 0))}
		"raid":
			return {"food": int(bal.get("raid_pack_food", 2))}
		"breach":
			return {"materials": int(bal.get("breach_materials", 6))}
		"probe":
			return {"tokens": int(bal.get("probe_tokens", 3))}
		"tap":
			return {"food": 2}
		_:
			return {}
	return {}


## Rations for a march off your own ground: food per two soldiers, rounded up. Walking home or between your
## own stations is free.
func move_food(dest: String) -> int:
	var sq: Dictionary = squads.get(player, {})
	if sq.is_empty() or not stations.has(dest):
		return 0
	var path := _path(str(sq.station), dest)
	if path.size() < 2 or str(stations[str(path[1])].owner) == player:
		return 0
	return int(ceil(float(soldier_count()) / 2.0)) * int(bal.guard.food_per_two)


func queue_order(action: Dictionary) -> bool:
	var kind := str(action.get("order", ""))
	var sid := str(action.get("station", action.get("dest", "")))
	if kind == "tap":
		sid = str(action.get("faction", sid))
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
	var prev_address := address_week
	if kind == "address":
		address_week = week
	if kind == "probe" or kind == "tap":
		flags["listening_order_week"] = week
		if kind == "probe":
			flags["listening_probe_sid"] = str(action.get("station", action.get("dest", "")))
			var place := station_text(str(flags["listening_probe_sid"]), "community")
			notices.append(Copy.fill("listening.toast_probe_queued", {"station": place}))
		else:
			notices.append(Copy.fill("listening.toast_tap_queued", {"faction": Copy.t(_fname(str(action.get("faction", ""))))}))
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
		"prev_address": prev_address,
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
		if str(row.get("kind", "")) == "address":
			address_week = int(row.get("prev_address", -99))
		if str(row.get("kind", "")) == "probe" or str(row.get("kind", "")) == "tap":
			if int(flags.get("listening_order_week", -1)) == week:
				flags.erase("listening_order_week")
			flags.erase("listening_probe_sid")
		queued_orders.remove_at(i)
		_journal("cancel", {"order": str(row.get("kind", "")), "station": str(row.get("target", ""))})
		return true
	return false


func _resolve_queued() -> void:
	var rows: Array = queued_orders.duplicate(true)
	queued_orders.clear()
	for row in rows:
		last_combat_report = {}
		var action: Dictionary = row.get("action", {})
		var cost: Dictionary = row.get("cost", {})
		for key in cost:
			stock[key] = int(stock.get(key, 0)) + int(cost[key])
		var kind := str(action.get("order", ""))
		var sid := str(action.get("station", ""))
		last_order_note = {}
		var host := _order_host(kind, action)
		var before := _order_before(kind, action)
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
				ok = _order_move(str(action.get("dest", action.get("station", ""))))
			"patrol":
				ok = _order_patrol(str(action.get("dest", action.get("station", ""))))
			"raid":
				ok = _order_raid(str(action.get("dest", action.get("station", ""))), false)
			"assault":
				ok = _order_assault(str(action.get("dest", action.get("station", ""))), false)
			"breach":
				ok = _order_breach()
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
				ok = _order_address(true)
			"probe":
				ok = _order_probe(str(action.get("station", action.get("dest", ""))))
			"tap":
				ok = _order_tap(str(action.get("faction", "")))
		var place := sid
		if kind == "tap":
			place = Copy.t(_fname(str(action.get("faction", ""))))
		var dest_id := str(action.get("dest", ""))
		if dest_id == "":
			dest_id = sid
		if kind in ["move", "patrol", "raid", "assault"] and stations.has(dest_id):
			place = station_text(dest_id, "community")
			if place == "":
				place = str(stations[dest_id].get("community", dest_id))
		elif stations.has(sid):
			place = station_text(sid, "community")
		seat_used.erase(str(row.get("role", "")))
		var note := _take_soft_note(kind, sid, row, ok)
		if not note.is_empty():
			order_reports.append(note)
			continue
		if ok and not last_combat_report.is_empty() and kind in ["raid", "assault"]:
			order_reports.append(last_combat_report.duplicate(true))
			last_combat_report = {}
			continue
		last_combat_report = {}
		var title := Copy.t("Dawn report")
		var who := Copy.person(str(row.get("name", "")))
		var text := _order_result_text(kind, action, who, place, before, ok)
		var extra := {}
		if ok:
			title = Copy.t(_order_title(kind))
		if ok and kind in ["gift", "aid", "pay"]:
			extra = _soft_order_report(kind, action, who, place, before)
			title = str(extra.get("title", title))
			text = str(extra.get("text", text))
		var report := {"title": title, "text": text, "ok": ok, "kind": kind, "person": str(row.get("person", "")),
			"station": str(action.get("dest", "")) if kind == "move" else sid}
		for key in ["before", "after", "faction", "need"]:
			if extra.has(key):
				report[key] = extra[key]
		if ok and host != "":
			report.merge(_leader_flavour("trade" if kind == "trade" else "territory", host))
		if ok and kind in ["gift", "aid", "pay"]:
			_note_soft_mark(kind, report)
		order_reports.append(report)
		if ok and kind == "trade":
			_vo_cue("caravan_arrived")
			flags["first_caravan"] = flags.get("first_caravan", week)
		_journal("order_done", {"order": kind, "station": str(action.get("dest", sid)) if kind == "move" else sid, "name": str(row.get("name", "")), "ok": ok})


## Stock, sympathy and the squad, read after the order's cost is refunded and before it resolves.
func _order_before(kind: String, action: Dictionary) -> Dictionary:
	var sid := str(action.get("station", action.get("dest", "")))
	var snap := {"stock": {}}
	for key in ["food", "air", "power", "materials", "tokens", "influence"]:
		snap.stock[key] = int(stock.get(key, 0))
	if stations.has(sid):
		var st: Dictionary = stations[sid]
		snap.sympathy = int(st.get("sympathy", 0))
		snap.owner = str(st.owner)
	var sq: Dictionary = squads.get(player, {})
	snap.squad = str(sq.get("station", ""))
	if kind == "move":
		var path := _path(str(snap.squad), str(action.get("dest", "")))
		var nxt := str(path[1]) if path.size() >= 2 else ""
		snap.step = nxt
		snap.step_owner = str(stations[nxt].owner) if stations.has(nxt) else ""
	if kind == "gift":
		var fid := str(action.get("faction", ""))
		if fid == "" :
			fid = _gift_faction(sid)
		snap.faction = fid
		snap.opinion = int(opinions.get(fid, 0))
	elif kind == "pay":
		var fid := str(action.get("faction", ""))
		if fid == "":
			fid = str(open_demand_for(sid).get("faction", ""))
		snap.faction = fid
		snap.opinion = int(opinions.get(fid, 0))
	elif kind == "aid" and stations.has(sid):
		var need := _lowest_need(stations[sid])
		snap.need = need
		snap.need_fill = _need_fill(stations[sid], need)
	return snap


## What the dawn card says the order did: a line from the councillor, then the change.
func _order_result_text(kind: String, action: Dictionary, who: String, place: String, before: Dictionary, ok: bool) -> String:
	if not ok:
		return "%s %s · %s" % [Copy.t("The order failed."), who, place]
	var bits: PackedStringArray = ["%s · %s" % [who, place]]
	var sid := str(action.get("station", ""))
	match kind:
		"propaganda", "envoy":
			if stations.has(sid):
				var now := int(stations[sid].get("sympathy", 0))
				var gain := now - int(before.get("sympathy", now))
				if str(stations[sid].owner) == player and str(before.get("owner", "")) != player:
					bits.append(Copy.t("%s stands with you.") % place)
				elif gain != 0:
					bits.append(Copy.t("Sympathy is now %d (+%d).") % [now, gain])
			if kind == "envoy":
				bits.append(Copy.t("Their weakest need eases."))
		"trade":
			if sid == "":
				bits.append(Copy.t("The Exchange opinion is now %d. Tokens come every week.") % int(opinions.get("exchange", 0)))
			elif stations.has(sid):
				bits.append(Copy.t("Passage is open. Deals with them: %d.") % int(stations[sid].get("deals", 0)))
				if str(stations[sid].owner) == player and str(before.get("owner", "")) != player:
					bits.append(Copy.t("%s stands with you.") % place)
		"move":
			var here := str(squads.get(player, {}).get("station", ""))
			var step := str(before.get("step", ""))
			if step != "" and here == step and str(stations[step].owner) == player and str(before.get("step_owner", "")) != player:
				bits.append(Copy.t("The squad takes %s.") % (station_text(step, "community") if station_text(step, "community") != "" else place))
			elif here != str(before.get("squad", "")):
				var arrived := station_text(here, "community")
				bits.append(Copy.t("The squad reaches %s.") % (arrived if arrived != "" else place))
			else:
				bits.append(Copy.t("The squad is held up on the way."))
		"expedition":
			bits.append(Copy.t("The squad is away for %s.") % Words.count(3, "week"))
		"probe", "tap":
			if listening_line != "":
				bits.append(listening_line)
	var gained := _gained_since(before)
	if gained != "":
		bits.append(gained)
	if bits.size() == 1:
		bits.append(Copy.t("It is done."))
	return " ".join(bits)


func _gained_since(before: Dictionary) -> String:
	var was: Dictionary = before.get("stock", {})
	var bits: PackedStringArray = []
	for key in ["food", "air", "power", "materials", "tokens", "influence"]:
		var d := int(stock.get(key, 0)) - int(was.get(key, 0))
		if d > 0:
			bits.append(Copy.stock(d, key))
	if bits.is_empty():
		return ""
	return Copy.t("They send %s.") % ", ".join(bits)


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
		"move", "patrol":
			return "The squad arrives"
		"raid":
			return "combat.after_raid"
		"assault":
			return "combat.after_assault"
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
		"probe":
			return "listening.probe"
		"tap":
			return "listening.tap"
		_:
			return "Dawn report"


func _stamp_soft_note(st: Dictionary, sid: String, kind: String, before_sym: int, after_sym: int, gain: int, need_id: String, need_before: float, need_after: float, deals: int, joined: bool) -> void:
	var plate := ""
	match kind:
		"propaganda":
			plate = "propaganda"
		"envoy":
			plate = "letter"
		"deal":
			plate = "toll"
	last_order_note = {
		"kind": kind,
		"station": sid,
		"community": str(st.get("community", "")),
		"before_sympathy": before_sym,
		"after_sympathy": after_sym,
		"gain": gain,
		"need_id": need_id,
		"need_before": need_before,
		"need_after": need_after,
		"deals": deals,
		"joined": joined,
		"plate": plate,
	}


func _take_soft_note(kind: String, sid: String, row: Dictionary, ok: bool) -> Dictionary:
	var expect := kind
	if kind == "trade" and sid != "":
		expect = "deal"
	if not ok or str(last_order_note.get("kind", "")) != expect:
		last_order_note = {}
		return {}
	var note: Dictionary = last_order_note.duplicate(true)
	last_order_note = {}
	var person_id := str(row.get("person", ""))
	var name := str(row.get("name", ""))
	note["name"] = name
	note["councillor"] = name
	note["person"] = person_id
	note["fem"] = _feminine(person_id, name)
	note["ok"] = true
	note["title"] = order_report_title(note)
	note["text"] = "\n".join(order_report_lines(note))
	return note


func order_report_title(row: Dictionary) -> String:
	var community := str(row.get("community", ""))
	match str(row.get("kind", "")):
		"propaganda":
			return Copy.fill("order.report_propaganda_title", {"community": community})
		"envoy":
			return Copy.fill("order.report_envoy_title")
		"deal":
			return Copy.fill("order.report_deal_title")
	return str(row.get("title", Copy.t("Dawn report")))


func order_report_lines(row: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for block in order_report_blocks(row):
		lines.append(str(block.get("text", "")))
	return lines


func order_report_blocks(row: Dictionary) -> Array:
	var kind := str(row.get("kind", ""))
	if kind != "propaganda" and kind != "envoy" and kind != "deal":
		return []
	if not row.has("before_sympathy") or not row.has("after_sympathy") or not row.has("gain"):
		return []
	var blocks: Array = []
	var name := Copy.person(str(row.get("name", "")))
	var community := str(row.get("community", ""))
	var fem := bool(row.get("fem", false))
	match kind:
		"propaganda":
			blocks.append({"role": "body", "text": Copy.fill("order.report_propaganda_body", {"name": name, "fem": fem})})
		"envoy":
			blocks.append({"role": "body", "text": Copy.fill("order.report_envoy_body", {"name": name, "community": community, "fem": fem})})
		"deal":
			blocks.append({"role": "body", "text": Copy.fill("order.report_deal_body", {"name": name, "n": int(row.get("deals", 0)), "fem": fem})})
	var gain := int(row.get("gain", 0))
	if kind == "propaganda" or kind == "envoy" or gain != 0:
		blocks.append({
			"role": "delta",
			"text": Copy.fill("order.report_sympathy", {
				"before": int(row.get("before_sympathy", 0)),
				"after": int(row.get("after_sympathy", 0)),
				"gain": gain,
			}),
		})
	if kind == "envoy" and str(row.get("need_id", "")) != "":
		blocks.append({
			"role": "need",
			"text": Copy.fill("order.report_need", {
				"need": Copy.t(str(row.get("need_id", ""))),
				"old": int(round(float(row.get("need_before", 0.0)) * 100.0)),
				"new": int(round(float(row.get("need_after", 0.0)) * 100.0)),
			}),
		})
	if kind == "deal" and int(row.get("deals", 0)) >= 1:
		blocks.append({"role": "passage", "text": Copy.fill("order.report_passage")})
	if bool(row.get("joined", false)):
		var join_key := "order.report_join" if kind == "deal" else "order.report_capture"
		blocks.append({"role": "join", "text": Copy.fill(join_key)})
	return blocks


func _feminine(person_id: String, full_name: String) -> bool:
	var ids := {
		"inez": true, "mara": true, "ruth": true, "samira": true, "lila": true,
		"june": true, "nora": true, "ada": true, "mina": true, "tess": true,
		"kim": true, "ann": true, "fran": true,
	}
	if ids.has(person_id):
		return true
	var first := full_name.get_slice(" ", 0)
	var names := {
		"Ida": true, "May": true, "Eva": true, "Lois": true, "Cora": true,
		"Nina": true, "Bea": true, "Rosa": true, "Thea": true, "Pam": true,
		"Inez": true, "Mara": true, "Ruth": true, "Samira": true, "Lila": true,
		"June": true, "Nora": true, "Ada": true, "Mina": true, "Tess": true,
		"Kim": true, "Ann": true, "Fran": true,
	}
	return names.has(first)


func order_block(kind: String, sid: String = "") -> String:
	if kind.begins_with("focus:"):
		return focus_block(sid, kind.trim_prefix("focus:"))
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
		"patrol":
			return _patrol_block(sid)
		"raid":
			return _raid_block(sid)
		"assault":
			return _assault_block(sid)
		"breach":
			return _breach_block()
		"trade":
			if sid != "":
				return _deal_block(sid)
			if trade_on:
				return Copy.t("Trade with the Exchange is already open.")
			if int(opinions.get("exchange", -100)) < 0:
				return Copy.t("The Exchange will not deal with you.")
			if int(stock.influence) < 4:
				return influence_short()
			return ""
		"expedition":
			return _expedition_block()
		"approach":
			return approach_block()
		"approach_observatory":
			return observatory_block()
		"approach_quarantine":
			return quarantine_block()
		"address":
			return address_reason()
		"aid":
			return _aid_block(sid)
		"gift":
			return _gift_block(sid)
		"pay":
			return _pay_block(sid)
		"probe":
			return _probe_block(sid)
		"tap":
			return _tap_block(sid)
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
	if kind.begins_with("focus:"):
		return Copy.t("No risk. Once the station can ship, this is what it sends home.")
	match kind:
		"envoy":
			if not stations.has(sid):
				return ""
			var gain := maxi(2, int(round(float(sympathy_preview(sid)) * 0.35)))
			return Copy.t("No risk. Sympathy +%d, and their weakest need improves.") % gain
		"propaganda":
			return Copy.t("No risk. Sympathy +%d.") % propaganda_gain(sid)
		"trade":
			if sid != "":
				return Copy.t("No risk. A deal opens passage; three deals and a neutral station joins you.")
			return Copy.t("No risk. Exchange opinion +6, and tokens every week.")
		"patrol":
			return Copy.t("combat.order.patrol_tip")
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
				return Copy.t("No fight on the next step. Marching: %s.") % Words.count(soldier_count(), "soldier")
			var st: Dictionary = stations[nxt]
			var attack := float(sq.size) * float(sq.gear) * (1.0 + float(sq.fight) / 10.0)
			var defense := float(st.garrison) * float(st.fort) * 1.3
			var odds := 100
			if attack > 0.0:
				odds = int(round(clampf((1.2 - defense / attack) / 0.4, 0.0, 1.0) * 100.0))
			var line := Copy.t("Battle at %s: about %d%% to win with %s. A loss kills a third to half of them; even a win costs some.") % [station_text(nxt, "community") if station_text(nxt, "community") != "" else Copy.t(str(st.name)), odds, Words.count(soldier_count(), "soldier")]
			if not bool(at_war.get(owner, false)):
				line += " " + Copy.t("Their opinion of you drops by 20.")
			if opinions.has(owner):
				line += " " + Copy.t("They strike back for %s.") % Words.count(int(bal.guard.provoke_weeks), "week")
			return line
		"raid", "assault":
			var preview := battle_preview(kind, sid)
			if not bool(preview.get("ok", false)):
				return ""
			return Copy.t("combat.odds.header") % [str(preview.get("place", "")), int(preview.get("win_pct", 0))]
		"expedition":
			return Copy.t("The squad is away 3 weeks and comes back about 15% smaller.")
		"approach", "approach_observatory", "approach_quarantine":
			return Copy.t("No risk. The meeting comes at the next dawn.")
		"gift", "aid", "pay":
			return order_toast(kind, _soft_action(kind, sid))
		"probe":
			return Copy.t("listening.probe_tip")
		"tap":
			return Copy.t("listening.tap_tip")
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
	if int(stock.influence) < propaganda_cost(sid):
		return influence_short()
	return ""


func _envoy_block(sid: String) -> String:
	var why := _court_block(sid)
	if why != "":
		return why
	if int(stock.influence) < 3:
		return influence_short()
	return ""


func _deal_block(sid: String) -> String:
	var why := _court_block(sid)
	if why != "":
		return why
	if stations.has(sid) and int(combat_lock.get(str(stations[sid].owner), 0)) > week:
		return Copy.t("order.truce")
	if int(stations[sid].get("deals", 0)) >= 3:
		return Copy.t("Three deals are already in force.")
	if int(stock.influence) < 4:
		return influence_short()
	return ""


func _move_block(dest: String) -> String:
	var sq: Dictionary = squads[player]
	if bool(sq.away):
		return Copy.t("The squad is away.")
	if not stations.has(dest):
		return Copy.t("No open tunnel that way.")
	var path := _path(str(sq.station), dest)
	if path.size() < 2:
		return Copy.t("No open tunnel that way.")
	if str(stations[str(path[1])].owner) != player and soldier_count() < int(bal.guard.move_min):
		return Copy.t("Needs %d soldiers. Recruit them at your station.") % int(bal.guard.move_min)
	if int(stock.food) < move_food(dest):
		return Copy.t("Not enough food for the march.")
	return ""


func _expedition_block() -> String:
	if not expedition.is_empty():
		return Copy.t("The expedition is already out.")
	var sq: Dictionary = squads.get(player, {})
	if bool(sq.get("away", false)) or str(sq.get("station", "")) != capital_id:
		return Copy.t("The squad must be home first.")
	if soldier_count() < int(bal.guard.move_min):
		return Copy.t("Needs %d soldiers. Recruit them at your station.") % int(bal.guard.move_min)
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
	var cost := _aid_price(need)
	for key in cost:
		if int(stock.get(key, 0)) < int(cost[key]):
			return false
	for key in cost:
		stock[key] = int(stock.get(key, 0)) - int(cost[key])
	_bump_need(st, need, AID_BUMP)
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
		_add_opinion(str(d.faction), PAY_OPINION)
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


## Gift lands on the faction that owns the station (_order_gift), so the toast names that faction, not the station.
func _gift_faction(sid: String) -> String:
	if not stations.has(sid):
		return ""
	var fid := str(stations[sid].owner)
	if fid == "" or fid == player or fid == "synod" or not opinions.has(fid):
		return ""
	return fid


func _gift_delta(sid: String) -> int:
	var fid := _gift_faction(sid)
	if fid == "" or bool(at_war.get(fid, false)):
		return 0
	return int(bal.get("gift_opinion", 0))


## Aid's step is AID_BUMP. No step is left when the worst need is already full, so the button stays hidden.
func _aid_delta(sid: String) -> bool:
	if not stations.has(sid) or not borders_player(sid):
		return false
	var st: Dictionary = stations[sid]
	if str(st.owner) in ["bunker", "ruin"] or str(st.get("bunker", "")) != "":
		return false
	var need := _lowest_need(st)
	if need == "":
		return false
	return _need_fill(st, need) < 1.0


func _pay_delta(sid: String) -> int:
	var due := open_demand_for(sid)
	if due.is_empty():
		return 0
	var fid := str(due.get("faction", ""))
	if fid == "" or fid == "synod" or not opinions.has(fid):
		return 0
	return PAY_OPINION


## False when that verb changes nothing today, so the card does not invent a button.
func verb_shown(kind: String, sid: String) -> bool:
	match kind:
		"gift":
			return _gift_delta(sid) != 0
		"aid":
			return _aid_delta(sid)
		"pay":
			return _pay_delta(sid) != 0
	return false


func open_demand_for(sid: String) -> Dictionary:
	if not stations.has(sid):
		return {}
	var fid := str(stations[sid].owner)
	for d in demands:
		if str(d.get("faction", "")) == fid and not bool(d.get("paid", false)):
			return d
	return {}


func _demand_queued(did: String) -> bool:
	for row in queued_orders:
		if str(row.get("kind", "")) == "pay" and str(row.get("action", {}).get("demand", "")) == did:
			return true
	return false


func _aid_price(need: String) -> Dictionary:
	if need == "air":
		return {"air": 6}
	if need == "food" or need == "work":
		return {"food": int(bal.get("aid_food", 0))}
	if need == "":
		return {}
	return {"materials": 4}


func _need_fill(st: Dictionary, need_id: String) -> float:
	for need in st.get("needs", []):
		if str(need.get("id", "")) == need_id:
			return float(need.get("fill", 0.0))
	return 0.0


func _soft_action(kind: String, sid: String) -> Dictionary:
	var action := {"order": kind, "station": sid}
	if kind == "gift":
		action["faction"] = _gift_faction(sid)
	elif kind == "pay":
		var due := open_demand_for(sid)
		action["demand"] = str(due.get("id", ""))
		action["faction"] = str(due.get("faction", ""))
	return action


## The line the map toasts when the order is queued. Empty for every other order.
func order_toast(kind: String, action: Dictionary) -> String:
	match kind:
		"gift":
			var fid := str(action.get("faction", ""))
			if fid == "":
				fid = _gift_faction(str(action.get("station", "")))
			var n := int(bal.get("gift_opinion", 0))
			if fid == "" or n == 0:
				return ""
			return Copy.fill("order.toast_gift", {"faction": Copy.t(_fname(fid)), "n": str(n)})
		"aid":
			var sid := str(action.get("station", ""))
			if not stations.has(sid):
				return ""
			var need := _lowest_need(stations[sid])
			if need == "":
				return ""
			var place := station_text(sid, "community")
			if place == "":
				place = Copy.t(str(stations[sid].get("name", sid)))
			return Copy.fill("order.toast_aid", {"station": place, "need": Copy.t(need)})
		"pay":
			var fid := str(action.get("faction", ""))
			if fid == "":
				fid = str(open_demand_for(str(action.get("station", ""))).get("faction", ""))
			if fid == "" or PAY_OPINION == 0:
				return ""
			return Copy.fill("order.toast_pay", {"faction": Copy.t(_fname(fid)), "n": str(PAY_OPINION)})
	return ""


func _aid_block(sid: String) -> String:
	if not _aid_delta(sid):
		return Copy.t("No such order.")
	var cost := _aid_price(_lowest_need(stations[sid]))
	for key in cost:
		if int(stock.get(key, 0)) < int(cost[key]):
			return Copy.t("Not enough %s.") % Copy.res(key)
	return ""


func _gift_block(sid: String) -> String:
	if _gift_delta(sid) == 0:
		return Copy.t("No such order.")
	if int(stock.get("tokens", 0)) < int(bal.get("gift_tokens", 0)):
		return Copy.t("Not enough tokens.")
	return ""


func _pay_block(sid: String) -> String:
	var due := open_demand_for(sid)
	if due.is_empty() or _pay_delta(sid) == 0:
		return Copy.t("No such order.")
	if _demand_queued(str(due.get("id", ""))):
		return Copy.t("That demand is already being paid.")
	if int(stock.get("tokens", 0)) < int(due.get("amount", 0)):
		return Copy.t("Not enough tokens.")
	return ""


## Dawn card for Gift, Aid and Pay: the same before → after the toast promised. Numbers are what the order just did.
func _soft_order_report(kind: String, action: Dictionary, who: String, place: String, before: Dictionary) -> Dictionary:
	var out := {"title": Copy.t("Dawn report"), "text": ""}
	if kind == "aid":
		var sid := str(action.get("station", ""))
		var need := str(before.get("need", ""))
		var old_pct := int(round(float(before.get("need_fill", 0.0)) * 100.0))
		var new_pct := old_pct
		if stations.has(sid) and need != "":
			new_pct = int(round(_need_fill(stations[sid], need) * 100.0))
		var need_name := Copy.t(need) if need != "" else ""
		out.title = Copy.fill("order.report_aid_title", {"station": place})
		out.text = "%s · %s %s %s %s" % [
			who, place,
			Copy.fill("order.report_aid_body", {"station": place}),
			Copy.fill("order.report_aid_need", {"need": need_name, "old": str(old_pct), "new": str(new_pct)}),
			Copy.t("order.report_aid_outcome"),
		]
		out.before = old_pct
		out.after = new_pct
		out.need = need
		return out
	var fid := str(before.get("faction", action.get("faction", "")))
	var was := int(before.get("opinion", 0))
	var now := int(opinions.get(fid, was))
	var faction_name := Copy.t(_fname(fid))
	var opinion := Copy.fill("order.report_opinion", {"before": str(was), "after": str(now), "n": str(now - was)})
	if kind == "pay":
		out.title = Copy.t("order.report_pay_title")
		out.text = "%s · %s %s %s %s" % [
			who, place,
			Copy.fill("order.report_pay_body", {"faction": faction_name}),
			opinion,
			Copy.t("order.report_pay_outcome"),
		]
	else:
		out.title = Copy.fill("order.report_gift_title", {"faction": faction_name})
		out.text = "%s · %s %s %s %s" % [
			who, place,
			Copy.fill("order.report_gift_body", {"faction": faction_name}),
			opinion,
			Copy.t("order.report_gift_outcome"),
		]
	out.before = was
	out.after = now
	out.faction = fid
	return out


## Lasting mark after a soft order lands. Gift and Pay float the real opinion step; Aid ticks the need bar.
## No float when the step clamped to nothing.
func _note_soft_mark(kind: String, report: Dictionary) -> void:
	if kind == "aid":
		need_ticks.append({
			"station": str(report.get("station", "")),
			"need": str(report.get("need", "")),
			"old": int(report.get("before", 0)),
			"new": int(report.get("after", 0)),
			"week": week,
		})
		map_marks.append({"kind": "aid", "station": str(report.get("station", "")), "text": ""})
		return
	var step := int(report.get("after", 0)) - int(report.get("before", 0))
	if step == 0:
		return
	map_marks.append({
		"kind": kind,
		"faction": str(report.get("faction", "")),
		"station": str(report.get("station", "")),
		"text": "+%d" % step,
	})


func _expire_need_ticks() -> void:
	var keep: Array = []
	for row in need_ticks:
		if int(row.get("week", 0)) == week:
			keep.append(row)
	need_ticks = keep


## 0..1 from the run seed and week, so a rumor does not consume the balance streams.
func _rumor_unit(salt: int) -> float:
	var n := int(seed) * 100003 + week * 10007 + salt * 9176 + 13
	n = (n * 1103515245 + 12345) & 0x7fffffff
	n = (n ^ (n >> 16)) & 0x7fffffff
	return float(n % 10000) / 10000.0


func rumor_truth_chance() -> float:
	return 0.9 if _has_radio() else 0.6


func rumor_count() -> int:
	return 1 if _rumor_live() else 0


func _rumor_live() -> bool:
	if rumor.is_empty():
		return false
	if week >= int(rumor.get("week_until", 0)):
		return false
	var sid := str(rumor.get("station", ""))
	if not stations.has(sid):
		return false
	var st: Dictionary = stations[sid]
	if str(st.owner) == player:
		return false
	if bool(rumor.get("blind", false)) and bool(st.get("known", false)):
		return false
	if int(st.get("sympathy", 0)) > 0 or int(st.get("deals", 0)) > 0:
		return false
	return true


func _rumor_candidate(sid: String) -> bool:
	if not stations.has(sid) or sid == capital_id:
		return false
	var st: Dictionary = stations[sid]
	var owner := str(st.owner)
	if owner == player or owner == "bunker" or owner == "ruin":
		return false
	if bool(st.get("hidden", false)) and not bool(st.get("known", false)):
		return false
	if not bool(st.get("known", false)):
		return true
	return int(st.get("sympathy", 0)) <= 0 and int(st.get("deals", 0)) <= 0


func _rumor_pool() -> Array:
	var seen := {}
	for owned in _owned_by(player):
		for n in _neighbors(str(owned)):
			var sid := str(n)
			if _rumor_candidate(sid):
				seen[sid] = true
	for intent in telegraphed:
		var sid := str(intent.get("station", ""))
		if _rumor_candidate(sid):
			seen[sid] = true
	var pool: Array = seen.keys()
	pool.sort()
	return pool


## Exactly one rumor, or none when every neighbour is already known and courted.
func _roll_rumor() -> void:
	if _rumor_live():
		return
	rumor = {}
	var pool := _rumor_pool()
	if pool.is_empty():
		return
	var pick := int(_rumor_unit(1) * pool.size())
	if pick >= pool.size():
		pick = pool.size() - 1
	var sid := str(pool[pick])
	var line_i := int(_rumor_unit(3) * RUMOR_LINES.size())
	if line_i >= RUMOR_LINES.size():
		line_i = RUMOR_LINES.size() - 1
	var st: Dictionary = stations[sid]
	rumor = {
		"station": sid,
		"text_key": str(RUMOR_LINES[line_i]),
		"week_until": week + RUMOR_WEEKS,
		"true": _rumor_unit(2) < rumor_truth_chance(),
		"blind": not bool(st.get("known", false)),
	}


func rumor_label() -> String:
	if not _rumor_live():
		return ""
	var sid := str(rumor.get("station", ""))
	var community := station_text(sid, "community")
	if community == "":
		return Copy.t("rumor.chip_fallback")
	return Copy.fill("rumor.chip_label", {"community": community})


func rumor_toast() -> String:
	if not _rumor_live():
		return ""
	var sid := str(rumor.get("station", ""))
	var community := station_text(sid, "community")
	if community == "":
		community = Copy.t("rumor.chip_fallback")
	var line := Copy.fill(str(rumor.get("text_key", "")), {"community": community})
	if line == "" or line == str(rumor.get("text_key", "")):
		line = community
	var prefix := Copy.t("rumor.toast_prefix")
	if prefix != "" and not line.begins_with(prefix):
		return "%s %s" % [prefix, line]
	return line


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
	if _move_block(dest) != "":
		return false
	var path := _path(str(sq.station), dest)
	stock.food = int(stock.food) - move_food(dest)
	var stepped := _step_squad(sq, str(path[1]), true)
	_note_party_home()
	return stepped


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
	# P7 night runs should call _note_night_run. The expedition is the outing that exists today.
	for pid in _squad_names(2):
		_note_night_run(str(pid))
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


## Why the platform cannot be addressed now; "" when it can (the council order itself aside).
func address_reason() -> String:
	var cost := int(bal.get("address_influence", 0))
	if week - address_week < int(bal.get("address_cooldown", 1)):
		return Copy.t("Already addressed this week.")
	for row in queued_orders:
		if str(row.get("kind", "")) == "address":
			return Copy.t("Already addressed this week.")
	if int(stock.influence) < cost:
		return Copy.t("Need %d influence.") % cost
	return ""


## Speaking to the platform: influence for hope, once a week. A queued address booked its week when the council
## took it, so at dawn it only pays.
func _order_address(queued := false) -> bool:
	var cost := int(bal.get("address_influence", 0))
	if not queued and address_reason() != "":
		return false
	if int(stock.influence) < cost:
		return false
	stock.influence = int(stock.influence) - cost
	if not queued:
		address_week = week
	_add_hope(int(bal.get("address_hope", 1)), "address")
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
	_lose_soldiers(int(round(float(sq.size) * 0.15)), "The road to South Ferry")
	stock.materials = int(stock.materials) + 10
	_hire(2)
	expedition = {}
	flags[EXPEDITION_FLAG] = true
	_note("BACK South Ferry is open. Two people walk back with the squad, and materials come with them.", "BACK Саут-Ферри открыт. Двое возвращаются с отрядом, и с ними материалы.")


# --- rivals ---

func _plan_intents() -> Array:
	var out: Array = []
	for fid in ["exchange", "directorate"]:
		if _faction_dead(fid):
			continue
		var intent := _plan_one(fid)
		var hide_p := intent_hide_chance()
		var hide: bool = str(intent.kind) != "demand_posted" and hide_p > 0.0 and net_rng.randf() < hide_p
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
	for season in seasons:
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
	if fid == "exchange" and not _hostile_to_player(fid):
		return {"faction": fid, "kind": "buy", "station": target}
	return {"faction": fid, "kind": "squad", "station": target}


func _resolve_intent(intent: Dictionary) -> void:
	var fid := str(intent.get("faction", ""))
	var kind := str(intent.get("kind", ""))
	var hidden := bool(intent.get("hidden", false))
	if _faction_dead(fid) or not squads.has(fid):
		return
	var sid := str(intent.get("station", ""))
	var from_station := str(squads[fid].get("station", ""))
	var owner_before := str(stations[sid].owner) if stations.has(sid) else ""
	var sym_before := int(stations[sid].rival_symp.get(fid, 0)) if stations.has(sid) else 0
	var size_before := int(squads[fid].get("size", 0))
	match kind:
		"buy":
			_resolve_buy(fid, sid)
		"squad":
			_resolve_squad(fid, sid)
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
	if not hidden:
		_queue_intent_playback(intent, from_station, owner_before, sym_before, size_before)


## One result chip for a visible intent. Kinds that exist today: buy, squad, hold, secure, demand_posted.
## Preached is art only; this does not invent a preach verb.
func _queue_intent_playback(intent: Dictionary, from_station: String, owner_before: String, sym_before: int, size_before: int) -> void:
	var fid := str(intent.get("faction", ""))
	var kind := str(intent.get("kind", ""))
	var sid := str(intent.get("station", ""))
	var chip := ""
	var at := sid
	match kind:
		"buy":
			if not stations.has(sid) or owner_before != "neutral":
				chip = "map.chip.bought_fail"
			elif str(stations[sid].owner) == fid:
				chip = "map.chip.bought_faction"
			elif int(stations[sid].rival_symp.get(fid, 0)) > sym_before and sym_before > 0:
				chip = "map.chip.bought_soft"
			elif int(stations[sid].rival_symp.get(fid, 0)) > sym_before:
				chip = "map.chip.bought"
			else:
				chip = "map.chip.bought_fail"
		"squad":
			var here := str(squads[fid].get("station", ""))
			if here != from_station and stations.has(here):
				var owner := str(stations[here].owner)
				chip = "map.chip.marched_faction" if owner != "" and owner != "neutral" and owner != fid and owner != player else "map.chip.marched"
				if owner == player:
					chip = "map.chip.marched"
				at = here
			elif int(squads[fid].get("size", 0)) > size_before:
				chip = "map.chip.held"
				at = from_station
			else:
				chip = "map.chip.marched_back"
				at = from_station
		"secure":
			chip = "map.chip.secured"
			at = str(squads[fid].get("station", sid))
		"hold":
			chip = "map.chip.held"
			at = from_station
		"demand_posted":
			chip = "map.chip.demanded"
			at = from_station
		_:
			return
	var dest := at if at != "" else sid
	var path: Array = []
	if from_station != "" and dest != "" and from_station != dest and stations.has(from_station) and stations.has(dest):
		path = _path(from_station, dest)
	elif dest != "" and stations.has(dest):
		path = [dest]
	elif from_station != "" and stations.has(from_station):
		path = [from_station]
	map_playback.append({
		"faction": fid,
		"kind": kind,
		"chip": chip,
		"station": dest,
		"path": path.duplicate(),
	})


func _resolve_buy(fid: String, sid: String) -> void:
	if not stations.has(sid):
		return
	var st: Dictionary = stations[sid]
	if str(st.owner) != "neutral":
		return
	st.rival_symp[fid] = int(st.rival_symp.get(fid, 0)) + 8 + net_rng.randi_range(0, 10)
	_press_loyalty(st, fid)
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
	if owner == player and not _hostile_to_player(fid):
		_log("%s holds short of %s" % [sq.name, stations[nxt].name])
		return
	if fid == "directorate" and bool(bal.get("slow_directorate_home", false)):
		var home: Dictionary = squads.get(player, {})
		if str(home.get("station", "")) == capital_id and not bool(home.get("away", false)):
			_log("%s holds short of %s" % [sq.name, stations[nxt].name])
			return
	_step_squad(sq, nxt, false)


# --- retaliation: a faction you march on strikes back ---

## Marching your squad into a faction's station provokes it for a few weeks: its squad comes for your stations
## and its garrisons raid your squad when it stands next to them.
func _provoke(fid: String) -> void:
	var was := provoked(fid)
	flags["provoked_" + fid] = week + int(bal.guard.provoke_weeks)
	if not was:
		var line := "%s will strike back." % _fname(fid)
		if Copy.ru():
			line = "%s ответит ударом." % Copy.t(_fname(fid))
		_log(line, true)


func provoked(fid: String) -> bool:
	return int(flags.get("provoked_" + fid, 0)) >= week


func provoked_weeks(fid: String) -> int:
	return maxi(0, int(flags.get("provoked_" + fid, 0)) - week)


func _hostile_to_player(fid: String) -> bool:
	return bool(at_war.get(fid, false)) or provoked(fid)


## The nearest station you hold to a provoked faction's squad, your capital aside; "" when none is in reach.
func _strike_target(fid: String) -> String:
	if not squads.has(fid):
		return ""
	var from := str(squads[fid].station)
	var best := ""
	var best_hops := 999
	for sid in _owned_by(player):
		if sid == capital_id:
			continue
		var hops := _hops(from, sid)
		if hops >= 0 and hops < best_hops:
			best_hops = hops
			best = sid
	return best


## Garrisons of a provoked faction raid your squad when it stands on or next to their ground.
func _sorties() -> void:
	var sq: Dictionary = squads.get(player, {})
	if sq.is_empty() or bool(sq.away) or soldier_count() == 0:
		return
	var here := str(sq.station)
	for fid in opinions.keys():
		if not provoked(fid):
			continue
		var raider := ""
		for n in _neighbors(here):
			if str(stations[n].owner) == fid and int(stations[n].garrison) > 0:
				raider = n
				break
		if raider == "":
			continue
		if net_rng.randf() >= float(bal.guard.sortie_chance):
			continue
		var hit := net_rng.randi_range(1, 2)
		var place := station_text(raider, "community")
		if place == "":
			place = Copy.t(str(stations[raider].name))
		_lose_soldiers(hit, Copy.t("A raid from %s") % place)


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
			_clear_wired(nxt)
			_log("ORDER move to %s" % stations[nxt].name)
		return true
	if owner == "bunker":
		return false
	if player_move and owner != player and not bool(at_war.get(owner, false)):
		_add_opinion(owner, -20)
	if player_move and owner != player and opinions.has(owner):
		_provoke(owner)
	if not player_move and owner == player and not _hostile_to_player(str(sq.faction)):
		return false
	if not player_move and nxt == capital_id and (week <= max_weeks or int(ambition.get(str(sq.faction), 0)) < 100):
		_log("%s holds short of %s" % [sq.name, stations[nxt].name])
		return false
	if not player_move and owner == player:
		sq["assault_player_week"] = week
	var win := _battle(sq, nxt)
	if win:
		_press_loyalty(stations[nxt], str(sq.faction))
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
	var ours := str(sq.faction) == player
	if win:
		st.garrison = clampi(int(round(float(st.garrison) * (1.0 - loss))), 2, 22)
		_log("BATTLE %s takes %s" % [sq.name, st.name], true)
		if ours:
			_lose_soldiers(maxi(1, int(round(float(sq.size) * loss * 0.35))), "The garrison fought back")
	else:
		_log("BATTLE %s is thrown back from %s" % [sq.name, st.name], true)
		if ours:
			_lose_soldiers(maxi(1, int(round(float(sq.size) * loss))), "Thrown back")
		else:
			sq.size = clampi(int(round(float(sq.size) * (1.0 - loss))), 5, 20)
		if not defender.is_empty():
			_lose_soldiers(int(round(float(defender.size) * loss * 0.5)), "The guard held the station")
	if ours:
		_note_moment("battle", {"place": str(st.name), "result": "the squad came back smaller" if not win else "the squad took the station"}, 3)
	return win


## How long a faction that lost a station keeps a claim on it. Display only, plus the ring; Assault numbers stay put.
const CLAIM_WEEKS := 12


func low_weeks_of(sid: String) -> int:
	if not stations.has(sid):
		return 0
	return int(stations[sid].get("low_weeks", 0))


## The faction whose colour the pressure ring uses. Empty when the station is not under pressure.
func pressure_faction(sid: String) -> String:
	if not stations.has(sid):
		return ""
	var st: Dictionary = stations[sid]
	if int(st.get("low_weeks", 0)) <= 0:
		return ""
	var by := str(st.get("pressure_by", ""))
	if by != "":
		return by
	var suitor := _suitor(st)
	if suitor != "":
		return suitor
	if str(st.get("owner", "")) == player:
		return _courting_rival()
	return ""


## Live claim, or {} when none. A faction that currently holds the station does not claim it.
func station_claim(sid: String) -> Dictionary:
	if not stations.has(sid):
		return {}
	return _active_claim(stations[sid])


func faction_title(fid: String) -> String:
	if catalog != null and catalog.factions.has(fid):
		return str(catalog.factions[fid].get("name", fid))
	return _fname(fid)


func _active_claim(st: Dictionary) -> Dictionary:
	var raw = st.get("claim", null)
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var faction := str(raw.get("faction", ""))
	var left := int(raw.get("weeks_left", 0))
	if faction == "" or left <= 0:
		return {}
	if str(st.get("owner", "")) == faction:
		return {}
	return {"faction": faction, "weeks_left": left}


func _claimable_faction(fid: String) -> bool:
	if fid == "" or fid in ["neutral", "ruin", "bunker", "enemy"]:
		return false
	return fid == player or (catalog != null and catalog.factions.has(fid))


## Previous owner gets a 12-week claim when the station had none. Does not replace a claim already on it.
func _grant_claim(st: Dictionary, prev: String) -> void:
	if not _active_claim(st).is_empty():
		return
	st.erase("claim")
	if not _claimable_faction(prev):
		return
	st["claim"] = {"faction": prev, "weeks_left": CLAIM_WEEKS}


func _tick_claims() -> void:
	for sid in stations.keys():
		var st: Dictionary = stations[sid]
		var claim := _active_claim(st)
		if claim.is_empty():
			if st.has("claim"):
				st.erase("claim")
			continue
		var left := int(claim.weeks_left) - 1
		if left <= 0:
			st.erase("claim")
			if bool(st.get("known", false)):
				notices.append(Copy.fill("pressure.claim_cleared", {"station": _station_place(str(sid))}))
		else:
			st["claim"] = {"faction": str(claim.faction), "weeks_left": left}


func _capture(sid: String, fid: String, force: bool) -> bool:
	var pushed := false
	if stations.has(sid):
		pushed = bool(stations[sid].get("_breach", false))
		stations[sid].erase("_breach")
	if week < 4:
		return false
	var st: Dictionary = stations[sid]
	var hostile := force or fid != player
	if hostile and int(st.get("low_weeks", 0)) < 2 and not pushed:
		return false
	if str(st.get("bunker", "")) != "" or str(st.owner) == "bunker":
		return false
	var prev := str(st.owner)
	if prev == fid:
		return false
	## Holding a station spends your own claim. A different faction's claim stays until it lapses or they retake.
	var held = st.get("claim", {})
	if typeof(held) == TYPE_DICTIONARY and str(held.get("faction", "")) == prev:
		st.erase("claim")
	var reclaim := str(_active_claim(st).get("faction", "")) == fid
	st.owner = fid
	st.sympathy = 0
	st.loyalty = 20 if force else 72
	st.unrest = net_rng.randi_range(4, 6)
	st.known = true
	if fid == player:
		_clear_wired(sid)
	st.held_weeks = 0
	st.low_weeks = 0
	st.erase("pressure_by")
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
	if reclaim:
		st.erase("claim")
		notices.append(Copy.fill("pressure.claim_cleared", {"station": _station_place(sid)}))
	_grant_claim(st, prev)
	if fid == player:
		var shipment := ""
		if force and bool(bal.get("force_no_join_hope", true)):
			_add_hope(int(bal.get("assault_hope", -3)), "force")
			_add_discontent(int(bal.get("assault_discontent", 8)), "force")
			_note_moment("station_taken_force", {"place": _station_place(sid), "week": week}, 5)
			notices.append(Copy.fill("combat.toast.force_capture", {"place": _station_place(sid)}))
			notices.append(Copy.t("combat.toast.force_hope"))
			notices.append(Copy.t("combat.toast.force_discontent"))
		else:
			_add_hope(int(bal.join_hope), "victory")
			_add_discontent(int(bal.get("join_discontent", 0)), "victory")
			_note_moment("station_taken", {"place": str(st.name)}, 3)
			shipment = _capture_shipment(st)
		var how := "force" if force else "peace"
		var joined := str(st.name)
		if Copy.ru():
			how = "силой" if force else "мирно"
			joined = Copy.t(joined)
		var line := "JOIN %s (%s)" % [joined, how]
		if shipment != "":
			line += ". " + shipment
		_log(line, true)
	else:
		if prev == player:
			_note_moment("station_lost", {"place": str(st.name)}, 3)
		_log("%s takes %s" % [_fname(fid), st.name], true)
	_settle_governors()
	if sid == capital_id and fid != player and over == "":
		over = "capital"
		_log("The yard has fallen.", true)
		_seal_score()
	_sync_perk_notices()
	return true


## A station that comes over sends one load home the week it joins, so the capture is not only a new pin.
func _capture_shipment(st: Dictionary) -> String:
	var goods: Dictionary = catalog.station_goods(str(st.get("id", "")))
	var key := "food"
	for good in goods:
		if int(goods[good]) > int(goods.get(key, 0)):
			key = str(good)
	var n := int(CAPTURE_LOAD.get(key, 4))
	stock[key] = int(stock.get(key, 0)) + n
	return Copy.t("They send %s.") % Copy.stock(n, key)


## The one load a station sends home the week it joins, by its biggest good.
const CAPTURE_LOAD := {"food": 6, "materials": 4, "tokens": 4, "air": 4, "influence": 3}


func focus_block(sid: String, focus: String) -> String:
	if focus not in ["food", "air", "defense", "influence"]:
		return Copy.t("No such order.")
	if not stations.has(sid) or str(stations[sid].owner) != player or sid == capital_id:
		return Copy.t("That station is out of reach.")
	if str(stations[sid].get("focus", "")) == focus:
		return Copy.t("They already send this home.")
	return ""


func set_outpost_focus(sid: String, focus: String) -> bool:
	if focus_block(sid, focus) != "":
		return false
	stations[sid].focus = focus
	_log("ORDER %s focuses on %s" % [stations[sid].name, focus])
	return true


## What a held station ships home at next dawn: the same flow _deliver_outposts pays, one week older.
## Empty for the capital and for stations that are not the player's. A focus previews that focus instead of the
## current one; settled previews what it ships once it is past settling in.
func outpost_yield(sid: String, focus: String = "", settled: bool = false) -> Dictionary:
	if not stations.has(sid) or str(stations[sid].owner) != player or sid == capital_id:
		return {}
	var st: Dictionary = stations[sid]
	var age := int(st.get("held_weeks", 0)) + 1
	if settled:
		age = maxi(age, 5)
	var use := focus if focus != "" else str(st.get("focus", ""))
	var gov := str(st.get("governor", ""))
	var flow := Formulas.outpost_flow(age, _supply_hops(sid), use, governor_bonus(gov, use), governor_settle(gov), catalog.station_goods(sid))
	return _with_food_focus_bonus(flow, use)


# --- community perks and goods (DEC-G1, DEC-G2) ---

## Perks on stations the player owns right now. Home has none. Each row is {id, station, effects}.
func held_perks() -> Array:
	var rows: Array = []
	for sid in stations:
		if str(stations[sid].owner) != player:
			continue
		var perk := station_perk(str(sid))
		if perk.is_empty():
			continue
		rows.append(perk)
	return rows


func station_perk(sid: String) -> Dictionary:
	var row = catalog.communities.get("stations", {}).get(sid, {}).get("perk", {})
	if not (row is Dictionary) or str(row.get("id", "")) == "":
		return {}
	var effects: Dictionary = row.get("effects", {})
	return {"id": str(row.id), "station": sid, "effects": effects if effects is Dictionary else {}}


func station_good(sid: String) -> Dictionary:
	var row = catalog.communities.get("stations", {}).get(sid, {}).get("good", {})
	if not (row is Dictionary) or str(row.get("id", "")) == "":
		return {}
	var effects: Dictionary = row.get("effects", {})
	return {
		"id": str(row.id),
		"station": sid,
		"name_key": str(row.get("name_key", "")),
		"effects": effects if effects is Dictionary else {},
	}


## Held source, or passage plus at least one Deal. Full toll routes stay out of this pass.
func good_flowing(sid: String) -> bool:
	if station_good(sid).is_empty() or not stations.has(sid):
		return false
	if str(stations[sid].owner) == player:
		return true
	return bool(stations[sid].get("passage", false)) and deal_count() >= 1


func flowing_goods() -> Array:
	var rows: Array = []
	for sid in stations:
		if good_flowing(str(sid)):
			rows.append(station_good(str(sid)))
	return rows


func perk_sheet_line(sid: String) -> String:
	var perk := station_perk(sid)
	if perk.is_empty():
		return ""
	return Copy.t("perk." + str(perk.id))


func good_sheet_line(sid: String) -> String:
	var good := station_good(sid)
	if good.is_empty():
		return ""
	var name := Copy.t(str(good.name_key)) if str(good.name_key) != "" else Copy.t("good." + str(good.id) + ".name")
	var sheet := Copy.t("good." + str(good.id) + ".sheet")
	var line := "%s: %s. %s" % [Copy.t("good.label"), name, sheet]
	if good_flowing(sid):
		line += " " + Copy.fill("good.flowing", {"good": name})
	return line


func _effect_sources() -> Array:
	var rows: Array = []
	for perk in held_perks():
		rows.append(perk.effects)
	for good in flowing_goods():
		rows.append(good.effects)
	return rows


func _perk_int(key: String) -> int:
	var n := 0
	for perk in held_perks():
		n += int(perk.effects.get(key, 0))
	return n


func _effect_int(key: String) -> int:
	var n := 0
	for fx in _effect_sources():
		n += int(fx.get(key, 0))
	return n


## Water and the Spring perk both halve cough. Together they stay at half, not a quarter.
func _cough_mult() -> float:
	var mult := 1.0
	var any := false
	for fx in _effect_sources():
		if fx.has("cough_mult"):
			any = true
			mult *= float(fx.cough_mult)
	if not any:
		return 1.0
	return maxf(0.5, mult)


func _generator_mult() -> float:
	var mult := 1.0
	for perk in held_perks():
		if perk.effects.has("generator_mult"):
			mult *= float(perk.effects.generator_mult)
	return mult


## Heat carries the same sabotage roll as the Atlantic perk. Holding both is one roll, not two.
func _sabotage_chance() -> float:
	var chance := 0.0
	for fx in _effect_sources():
		chance = maxf(chance, float(fx.get("sabotage_chance", 0.0)))
	return chance


func _spoil_mult() -> float:
	var mult := 1.0
	for fx in _effect_sources():
		if fx.has("spoil_mult"):
			mult *= float(fx.spoil_mult)
	return mult


func _static_weight_mult() -> int:
	var mult := 1
	for perk in held_perks():
		var w := int(perk.effects.get("static_event_weight", 0))
		if w > 1:
			mult *= w
	return mult


func dig_material_cost() -> int:
	return maxi(1, int(bal.dig_materials) + _perk_int("dig_mat_delta"))


func _with_food_focus_bonus(flow: Dictionary, focus: String) -> Dictionary:
	if flow.is_empty() or focus != "food" or int(flow.get("upkeep_materials", 0)) > 0:
		return flow
	var extra := _perk_int("food_focus_bonus")
	if extra != 0:
		flow.food = int(flow.get("food", 0)) + extra
	return flow


func _apply_held_perks() -> void:
	_add_stock("power", _effect_int("power_week"))
	_add_stock("tokens", _effect_int("token_week"))
	_add_stock("influence", _effect_int("influence_week"))
	var dis := _perk_int("discontent_week")
	if dis != 0:
		_add_discontent(dis, "perk")
	var opinion := _perk_int("exchange_opinion_week")
	if opinion != 0:
		_add_opinion("exchange", opinion, "perk")
	_roll_sabotage()


## Weekly goods from a held source, or from a station with passage once a Deal exists.
## Fork sides that are not in the build yet stay a no-op; the weekly number still lands.
func _deliver_goods() -> void:
	for good in flowing_goods():
		var fx: Dictionary = good.effects
		_add_stock("food", int(fx.get("food_week", 0)))
		_add_stock("materials", int(fx.get("materials_week", 0)))
		_add_stock("air", int(fx.get("air_week", 0)))
		var every := int(fx.get("blueprint_weeks", 0))
		if every > 0:
			var key := "good_week:" + str(good.id)
			flags[key] = int(flags.get(key, 0)) + 1
			if int(flags[key]) >= every:
				flags[key] = 0
				_grant_fork(str(fx.get("fork_unlock", "any_locked")))
		else:
			_open_forks(fx)


func _add_stock(key: String, n: int) -> void:
	if n == 0 or not stock.has(key):
		return
	stock[key] = int(stock.get(key, 0)) + n


func _roll_sabotage() -> void:
	var chance := _sabotage_chance()
	if chance <= 0.0 or rng.randf() >= chance:
		return
	var open: Array = []
	for room in rooms:
		if bool(room.get("offline", false)) or str(room.type) == "platform":
			continue
		open.append(room)
	if open.is_empty():
		return
	var room: Dictionary = open[rng.randi_range(0, open.size() - 1)]
	room.disabled = maxi(int(room.get("disabled", 0)), 1)
	_log("SABOTAGE %s" % str(catalog.rooms[room.type].name), true)
	_journal("sabotage", {"type": str(room.type)})


func _perk_sermons_hope() -> void:
	var cost := _perk_int("sermons_hope_once")
	if cost == 0 or flags.has("perk_sermons_paid"):
		return
	flags["perk_sermons_paid"] = week
	_add_hope(cost, "perk")


func _open_forks(fx: Dictionary) -> void:
	var raw = fx.get("fork_unlock", null)
	var ids: Array = []
	if raw is Array:
		ids = raw
	elif str(raw) != "":
		ids = [str(raw)]
	for id in ids:
		var key := "fork_open:" + str(id)
		if flags.has(key):
			continue
		flags[key] = week
		_grant_fork(str(id))


## No fork table ships in this pass. A later fork list in the catalog can turn the flag into a side.
func _grant_fork(id: String) -> void:
	if id == "" or id == "any_locked":
		return
	var forks = catalog.communities.get("forks", null)
	if not (forks is Dictionary) or not (forks as Dictionary).has(id):
		return
	flags["fork:" + id] = true


func _perk_station_name(sid: String) -> String:
	var key := "station." + sid
	var named := Copy.t(key)
	if named != key:
		return named
	if stations.has(sid):
		return Copy.t(str(stations[sid].name))
	return sid


func _perk_station_of(perk_id: String) -> String:
	var rows: Dictionary = catalog.communities.get("stations", {})
	for sid in rows:
		var perk = rows[sid].get("perk", {})
		if perk is Dictionary and str(perk.get("id", "")) == perk_id:
			return str(sid)
	return perk_id


## Dawn lines for a perk that just started or just stopped. Losing it drops the effect the same night.
func _sync_perk_notices() -> void:
	var now := {}
	for perk in held_perks():
		now[str(perk.id)] = perk
	for id in now:
		var flag := "perk_on:" + str(id)
		if flags.has(flag):
			continue
		flags[flag] = week
		var perk: Dictionary = now[id]
		notices.append(Copy.fill("perk.toast_held", {
			"name": _perk_station_name(str(perk.station)),
			"perk": Copy.t("perk.short." + str(id)),
		}))
		_queue_perk_float(perk)
	var gone: Array = []
	for key in flags.keys():
		var name := str(key)
		if not name.begins_with("perk_on:"):
			continue
		var id := name.trim_prefix("perk_on:")
		if not now.has(id):
			gone.append(id)
	for id in gone:
		flags.erase("perk_on:" + str(id))
		var sid := _perk_station_of(str(id))
		notices.append(Copy.fill("perk.toast_lost", {
			"name": _perk_station_name(sid),
			"perk": Copy.t("perk.short." + str(id)),
		}))


func _queue_perk_float(perk: Dictionary) -> void:
	var id := str(perk.id)
	if flags.has("perk_floated:" + id):
		return
	flags["perk_floated:" + id] = week
	var fx: Dictionary = perk.effects
	var due: Dictionary = perk_float_due
	var food := int(fx.get("food_room_bonus", 0)) * _live_hydro_rooms()
	food += int(fx.get("food_focus_bonus", 0))
	if food != 0:
		due["food"] = int(due.get("food", 0)) + food
	if fx.has("power_week"):
		due["power"] = int(due.get("power", 0)) + int(fx.power_week)
	if fx.has("token_week"):
		due["tokens"] = int(due.get("tokens", 0)) + int(fx.token_week)
	if fx.has("influence_week"):
		due["influence"] = int(due.get("influence", 0)) + int(fx.influence_week)
	if fx.has("discontent_week"):
		due["discontent"] = int(due.get("discontent", 0)) + int(fx.discontent_week)
	if fx.has("generator_mult"):
		var plain := int(_tally(false, false, false, false, false).get("power", 0))
		var boosted := int(_tally(false, false, false, false, true).get("power", 0))
		var extra := boosted - plain
		if extra != 0:
			due["power"] = int(due.get("power", 0)) + extra
	perk_float_due = due


func _live_hydro_rooms() -> int:
	var n := 0
	for room in rooms:
		if str(room.type) != "hydroponics":
			continue
		if bool(room.get("offline", false)) or int(room.get("disabled", 0)) > 0:
			continue
		n += 1
	return n


# --- governors ---
## A resident who holds a station for the player (docs/GOVERNORS_PLAN.md). The station carries the person's id in
## "governor"; while they govern they are away from home (absent, held there each week) and their room post is kept
## for their return. A councillor may govern, but their seat gives no order while they are away.
const GOVERNOR_SKILL := {"food": "labor", "air": "tech", "defense": "fight", "influence": "talk"}


## The extra focus goods a person adds as governor: +1 at the first skill line, +2 at the second.
func governor_bonus(pid: String, focus: String) -> int:
	if not people.has(pid):
		return 0
	var g: Dictionary = bal.governor
	var skill := int(people[pid].skills.get(str(GOVERNOR_SKILL.get(focus if focus != "" else "food", "labor")), 0))
	if skill >= int(g.skill_plus_two):
		return 2
	if skill >= int(g.skill_plus_one):
		return 1
	return 0


## Weeks a station takes to settle in under this governor (shorter with a strong worker in charge).
func governor_settle(pid: String) -> int:
	var g: Dictionary = bal.governor
	if people.has(pid) and int(people[pid].skills.get("labor", 0)) >= int(g.labor_min):
		return int(g.settle_weeks_labor)
	return int(g.settle_weeks)


## The station a person governs, or "".
func governor_of(pid: String) -> String:
	for sid in stations:
		if str(stations[sid].get("governor", "")) == pid and pid != "":
			return str(sid)
	return ""


func governor_block(sid: String, pid: String) -> String:
	if not stations.has(sid) or str(stations[sid].owner) != player or sid == capital_id:
		return Copy.t("That station is out of reach.")
	if str(stations[sid].get("governor", "")) != "":
		return Copy.t("The station already has a governor.")
	if not people.has(pid):
		return Copy.t("No such person.")
	var person: Dictionary = people[pid]
	if governor_of(pid) != "":
		return Copy.t("They already govern a station.")
	if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
		return Copy.t("They are not at the station now.")
	if _locked_ids().has(pid) or bool(person.get("soldier", false)):
		return Copy.t("They are on a crew or in the guard.")
	if (bal.governor.get("too_young", []) as Array).has(pid):
		return Copy.t("Too young to hold a station.")
	if int(stock.influence) < int(bal.governor.appoint_influence):
		return influence_short()
	return ""


## Who could govern a station, best first by what they would add to its focus: [{id, name, skill, bonus, council}].
func governor_candidates(sid: String) -> Array:
	var out: Array = []
	if not stations.has(sid):
		return out
	var focus := str(stations[sid].get("focus", "food"))
	var key := str(GOVERNOR_SKILL.get(focus if focus != "" else "food", "labor"))
	for person in residents:
		var pid := str(person.id)
		var why := governor_block(sid, pid)
		if why != "" and why != influence_short():
			continue
		out.append({"id": pid, "name": str(person.name), "skill": int(person.skills.get(key, 0)), "skill_key": key,
			"bonus": governor_bonus(pid, focus), "council": _is_council(pid), "talk": int(person.skills.get("talk", 0))})
	out.sort_custom(func(a, b): return [int(a.bonus), not bool(a.council), int(a.skill)] > [int(b.bonus), not bool(b.council), int(b.skill)])
	return out


func appoint_governor(sid: String, pid: String) -> bool:
	if governor_block(sid, pid) != "":
		return false
	var g: Dictionary = bal.governor
	stock.influence = int(stock.influence) - int(g.appoint_influence)
	_mark_post(pid)
	_unassign(pid)
	people[pid].absent = maxi(int(people[pid].get("absent", 0)), 2)
	stations[sid].governor = pid
	if _has_trait(people[pid], "Veteran"):
		stations[sid].garrison = int(stations[sid].garrison) + int(g.veteran_garrison)
	if _is_council(pid):
		for seat in council:
			if str(seat.id) == pid and str(seat_used.get(str(seat.role), "")) == "":
				orders_left = maxi(0, orders_left - 1)
	decisions += 1
	_note("%s now holds %s for us." % [people[pid].name, stations[sid].name], "%s теперь держит для нас станцию «%s»." % [Copy.person(str(people[pid].name)), Copy.t(str(stations[sid].name))])
	_journal("governor", {"station": sid, "person": pid})
	return true


## Brings the governor home now; sick_weeks > 0 when they walk home from a lost station.
func recall_governor(sid: String, sick_weeks: int = 0) -> bool:
	if not stations.has(sid):
		return false
	var pid := str(stations[sid].get("governor", ""))
	if pid == "":
		return false
	stations[sid].governor = ""
	if not people.has(pid):
		return true
	if _has_trait(people[pid], "Veteran"):
		stations[sid].garrison = maxi(0, int(stations[sid].garrison) - int(bal.governor.veteran_garrison))
	people[pid].absent = 0
	if sick_weeks > 0:
		people[pid].sick = maxi(int(people[pid].get("sick", 0)), sick_weeks)
		_note("%s walks home from %s, hurt." % [people[pid].name, stations[sid].name], "%s возвращается из «%s» с ранением." % [Copy.person(str(people[pid].name)), Copy.t(str(stations[sid].name))])
	else:
		_log("RECALL %s from %s" % [people[pid].name, stations[sid].name])
		_restore_post(pid)
	return true


## Releases governors of stations that are no longer the player's (they walk home hurt) and of people who are gone.
func _settle_governors() -> void:
	for sid in stations:
		var st: Dictionary = stations[sid]
		var pid := str(st.get("governor", ""))
		if pid == "":
			continue
		if not people.has(pid):
			st.governor = ""
		elif str(st.owner) != player:
			recall_governor(str(sid), int(bal.governor.lost_sick_weeks))


## Keeps every governor away from home through the weekly absence tick.
func _hold_governors() -> void:
	for sid in stations:
		var pid := str(stations[sid].get("governor", ""))
		if pid != "" and people.has(pid):
			people[pid].absent = maxi(int(people[pid].get("absent", 0)), 2)


## The governor's weekly price and the station-side effects of who they are. Called with the outpost deliveries.
func _pay_governors() -> void:
	var g: Dictionary = bal.governor
	for sid in stations:
		var st: Dictionary = stations[sid]
		var pid := str(st.get("governor", ""))
		if pid == "" or not people.has(pid):
			continue
		if int(stock.influence) < int(g.weekly_influence):
			_note("No influence left to keep a governor. %s comes home." % people[pid].name, "Влияния на наместника не осталось. %s возвращается домой." % Copy.person(str(people[pid].name)))
			recall_governor(str(sid))
			continue
		stock.influence = int(stock.influence) - int(g.weekly_influence)
		var person: Dictionary = people[pid]
		if int(person.skills.get("talk", 0)) >= int(g.talk_min):
			st.loyalty = mini(100, int(st.loyalty) + int(g.talk_loyalty))
		if _has_trait(person, "Devout") and int(st.unrest) > 0:
			st.unrest = int(st.unrest) - 1
		if _has_trait(person, "Black marketeer") and _supply_hops(str(sid)) < 900:
			stock.tokens = int(stock.tokens) + int(g.marketeer_tokens)


## What a station the player does not hold would ship home once taken and settled in, at its current focus (food
## when it has none): the supply line would run through the best neighbour that already supplies. Empty for the
## player's own stations; all zero when no neighbour supplies (it would be cut off).
func yield_if_taken(sid: String) -> Dictionary:
	if not stations.has(sid) or str(stations[sid].owner) == player or sid == capital_id:
		return {}
	var hops := 999
	for n in _neighbors(sid):
		if _supplies(str(n)):
			hops = mini(hops, _supply_hops(str(n)) + 1)
	var focus := str(stations[sid].get("focus", ""))
	return Formulas.outpost_flow(5, hops, focus if focus != "" else "food", 0, 4, catalog.station_goods(sid))


## The chain of stations an outpost's loads walk home along, outpost first and capital last, through stations
## that supply (the same rule as _supply_hops). Empty when the line is cut.
func supply_route(sid: String) -> Array:
	if not stations.has(sid) or sid == capital_id:
		return []
	var prev := {capital_id: ""}
	var queue: Array = [capital_id]
	var qi := 0
	while qi < queue.size():
		var cur: String = queue[qi]
		qi += 1
		for n in _neighbors(cur):
			var nb := str(n)
			if prev.has(nb) or not _supplies(nb):
				continue
			prev[nb] = cur
			if nb == sid:
				var chain: Array = []
				var p := nb
				while p != "":
					chain.append(p)
					p = str(prev[p])
				return chain
			queue.append(nb)
	return []


## The open tunnel chain from the capital to a station, capital first, for caravans that walk to a trade partner.
func trade_route(sid: String) -> Array:
	if not stations.has(sid) or sid == capital_id:
		return []
	return _path(capital_id, sid)


## The tunnel chain a squad walked from one station to another, for the map to animate; a straight hop when the
## tunnels between them are closed now.
func walk_route(from: String, to: String) -> Array:
	var chain := _path(from, to)
	return chain if not chain.is_empty() else [from, to]


## The open tunnel chain from a rival station to its faction's seat, for the rival carts the map draws.
func rival_route(sid: String, seat: String) -> Array:
	if not stations.has(sid) or not stations.has(seat) or sid == seat:
		return []
	return _path(sid, seat)


func _campaign_target(fid: String) -> String:
	if provoked(fid):
		var strike := _strike_target(fid)
		if strike != "":
			return strike
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
			if owner == player and not _hostile_to_player(fid):
				continue
			if owner != "neutral" and owner != player:
				continue
			var hops := _hops(n, capital_id)
			if hops < best_hops:
				best_hops = hops
				best = n
	return best


func _deliver_outposts() -> void:
	_settle_governors()
	_pay_governors()
	for sid in stations.keys():
		var st: Dictionary = stations[sid]
		if str(st.owner) != player or sid == capital_id:
			continue
		st.held_weeks = int(st.get("held_weeks", 0)) + 1
		var hops := _supply_hops(str(sid))
		if hops >= 900:
			continue
		var gov := str(st.get("governor", ""))
		var flow := Formulas.outpost_flow(int(st.held_weeks), hops, str(st.focus), governor_bonus(gov, str(st.focus)), governor_settle(gov), catalog.station_goods(str(sid)))
		flow = _with_food_focus_bonus(flow, str(st.focus))
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
		var pressing := _suitor(st)
		if pressing == "":
			pressing = _courting_rival()
		if pressing != "":
			st["pressure_by"] = pressing
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
					st.erase("pressure_by")
					_note_flip(sid, player, "neutral")
					_grant_claim(st, player)
					_settle_governors()
					_sync_perk_notices()


func _press_loyalty(st: Dictionary, by: String = "") -> void:
	if by != "":
		st["pressure_by"] = by
	st.loyalty = maxi(0, int(st.loyalty) - (4 + net_rng.randi_range(0, 7)))
	_mark_low(st)


func _mark_low(st: Dictionary) -> void:
	if int(st.loyalty) >= 42:
		st.low_weeks = 0
		st.erase("pressure_by")
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
		if _is_child(person) or int(person.sick) > 0 or int(person.absent) > 0:
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
	list.append_array(["hydroponics", "air_filter", "generator", "workshop", "meeting_hall", "infirmary", "radio", "listening_post"])
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
		if used.has(id) or _is_child(person):
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
		if locked.has(id) or _is_child(person) or int(person.absent) > 0 or int(person.sick) > 0:
			continue
		pool.append(person)
	if pool.size() < n:
		return []
	pool.sort_custom(func(a, b): return int(a.skills.get(skill, 0)) > int(b.skills.get(skill, 0)))
	var chosen: Array = []
	for i in n:
		var id := str(pool[i].id)
		_mark_post(id)
		_unassign(id)
		chosen.append(id)
	return chosen


func _locked_ids() -> Array:
	var ids: Array = []
	if not dig.is_empty():
		ids.append_array(dig.workers)
	if not clear.is_empty():
		ids.append_array(clear.workers)
	if not build.is_empty():
		ids.append_array(build.workers)
	ids.append_array(soldier_ids())
	return ids


func _free_count() -> int:
	var locked := {}
	for id in _locked_ids():
		locked[id] = true
	var n := 0
	for person in residents:
		if locked.has(str(person.id)) or _is_child(person) or int(person.sick) > 0 or int(person.absent) > 0:
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
		_fill_identity(person)
		residents.append(person)
		people[id] = person
		_dress([person])


func _kill(n: int, why: String, cause := "accident", place := "") -> void:
	var names := _shed(n, "died", cause, place)
	if names.size() > 0:
		_log("%s. %s." % [why, ", ".join(names)], true)
		_journal("deaths", {"n": names.size()})
		_vo_cue("resident_lost")


func _shed(n: int, how := "died", cause := "accident", place := "") -> PackedStringArray:
	var names: PackedStringArray = []
	var lost := 0
	while lost < n:
		var id := _pick_victim(cause)
		if id == "":
			break
		names.append(str(people[id].get("name", id)))
		_remove_resident(id, how == "died", cause, how, place)
		lost += 1
	return names


func _remove_resident(id: String, notice := false, cause := "", how := "died", place := "") -> void:
	if people.has(id) and (notice or cause != ""):
		var who: Dictionary = people[id]
		var memory := int(who.get("memory", 0))
		var known := memory >= 40
		var line_id := _death_line_id(cause if cause != "" else "accident", who)
		if how == "died":
			_remember_departure(who, "died", line_id, place)
			stats.named_dead = int(stats.get("named_dead", 0)) + 1
			_note_moment("named_death", {"name": str(who.get("name", id)), "cause": _death_cause_label(line_id), "who": id}, 5)
			if known:
				_note_moment("known_lost", {"name": str(who.get("name", id))}, 5)
				_add_hope(-2, "known")
			if memory >= 30:
				burials.append({
					"id": id,
					"name": str(who.get("name", id)),
					"name_ru": str(who.get("name_ru", "")),
					"cause": line_id,
					"memory": memory,
				})
		elif how == "left":
			_remember_departure(who, "left", line_id, place)
			if known:
				_add_hope(-1, "known")
				_note_moment("known_lost", {"name": str(who.get("name", id))}, 4)
	var gone := str(people[id].get("name", "")) if people.has(id) else ""
	var seat := ""
	if people.has(id):
		var uid := _staff_room_of(id)
		if uid == "":
			uid = str(people[id].get("post", ""))
		var room = _room(uid)
		if room != null:
			seat = Copy.t(str(catalog.rooms[room.type].name))
	_drop_roster(id)
	_unassign(id)
	if notice and gone != "":
		var name := Copy.person(gone)
		var died := "умерла" if people.has(id) and sex_of(people[id]) == "f" else "умер"
		if seat != "":
			_note("LOST %s died. Their place in %s is empty." % [name, seat], "LOST %s %s. Место в «%s» пусто." % [name, died, seat])
		else:
			_note("LOST %s died." % name, "LOST %s %s." % [name, died])
	people.erase(id)
	var keep: Array = []
	for person in residents:
		if str(person.id) != id:
			keep.append(person)
	residents = keep
	if not dig.is_empty():
		dig.workers = _without(dig.workers, id)
	if not clear.is_empty():
		clear.workers = _without(clear.workers, id)
	if not build.is_empty():
		build.workers = _without(build.workers, id)
	_sync_guard()


# --- the guard: the player's squad is made of residents ---

## Residents standing in the platform guard. They eat and take beds like everyone else but work no room.
func soldier_ids() -> Array:
	var ids: Array = []
	for person in residents:
		if bool(person.get("soldier", false)):
			ids.append(str(person.id))
	return ids


func soldier_count() -> int:
	return soldier_ids().size()


## The player's squad is as big as the guard; nothing refills it but recruiting.
func _sync_guard() -> void:
	if not squads.has(player):
		return
	var sq: Dictionary = squads[player]
	var n := soldier_count()
	var before := str(sq.get("station", ""))
	sq.size = n
	if not sq.has("roster"):
		sq.max_size = n
	if n == 0 and not bool(sq.get("away", false)):
		sq.station = capital_id
	if str(sq.get("station", "")) != before:
		_note_party_home()


## Who joins the guard next: the best fighter outside the council, crews and sickbeds; idle people first on a tie.
func _recruit_pick() -> String:
	var locked := _locked_ids()
	var best := ""
	var best_v := -1
	for person in residents:
		var id := str(person.id)
		if locked.has(id) or _is_council(id) or _is_child(person) or int(person.sick) > 0 or int(person.absent) > 0:
			continue
		var v := int(person.skills.get("fight", 0)) * 2
		if _staff_room_of(id) == "":
			v += 1
		if v > best_v:
			best_v = v
			best = id
	return best


func _staff_room_of(id: String) -> String:
	for room in rooms:
		for sid in room.staff:
			if str(sid) == id:
				return str(room.uid)
	return ""


## The room a person was taken from, so a dig crew or the guard can put them back.
func _mark_post(id: String) -> void:
	if not people.has(id):
		return
	var uid := _staff_room_of(id)
	if uid != "":
		people[id]["post"] = uid


func _restore_post(id: String) -> void:
	if not people.has(id):
		return
	if _staff_room_of(id) != "" or bool(people[id].get("soldier", false)):
		return
	if int(people[id].get("sick", 0)) > 0 or int(people[id].get("absent", 0)) > 0:
		return
	var uid := str(people[id].get("post", ""))
	if uid == "" or not bool(assign_preview(id, uid).ok):
		return
	var room = _room(uid)
	room.staff.append(id)


func _restore_posts(ids: Array) -> void:
	for id in ids:
		_restore_post(str(id))


func recruit_block() -> String:
	var sq: Dictionary = squads.get(player, {})
	if bool(sq.get("away", false)) or str(sq.get("station", "")) != capital_id:
		return Copy.t("The squad must be home first.")
	if soldier_count() >= int(bal.guard.max):
		return Copy.t("The guard is full.")
	if _recruit_pick() == "":
		return Copy.t("Nobody is free to join the guard.")
	if int(stock.materials) < int(bal.guard.recruit_materials):
		return Copy.t("Not enough materials.")
	return ""


func dismiss_block() -> String:
	var sq: Dictionary = squads.get(player, {})
	if bool(sq.get("away", false)) or str(sq.get("station", "")) != capital_id:
		return Copy.t("The squad must be home first.")
	if soldier_count() == 0:
		return Copy.t("The guard is empty.")
	return ""


## Who the next recruit would be, by name; "" when nobody can join.
func recruit_preview() -> String:
	var pick := _recruit_pick()
	return Copy.person(str(people[pick].name)) if pick != "" else ""


func _enlist(id: String) -> void:
	_mark_post(id)
	_unassign(id)
	people[id].soldier = true
	_sync_guard()


func _apply_recruit() -> bool:
	if recruit_block() != "":
		return false
	var id := _recruit_pick()
	stock.materials = int(stock.materials) - int(bal.guard.recruit_materials)
	_enlist(id)
	decisions += 1
	_log("RECRUIT %s joins the guard (%d)" % [people[id].name, soldier_count()])
	return true


func _apply_dismiss() -> bool:
	if dismiss_block() != "":
		return false
	var pick := ""
	var low := 99
	for id in soldier_ids():
		var v := int(people[id].skills.get("fight", 0))
		if v < low:
			low = v
			pick = id
	people[pick].soldier = false
	_sync_guard()
	_restore_post(pick)
	decisions += 1
	_log("DISMISS %s goes back to work (%d)" % [people[pick].name, soldier_count()])
	return true


## Soldiers killed in a fight or lost on the road leave the station for good; the weakest fall first.
func _lose_soldiers(n: int, why: String) -> int:
	var ids := soldier_ids()
	ids.sort_custom(func(a, b): return int(people[a].skills.get("fight", 0)) < int(people[b].skills.get("fight", 0)))
	var lost := 0
	while lost < n and not ids.is_empty():
		_remove_resident(str(ids.pop_front()), true, "battle", "died", why)
		lost += 1
	if lost > 0:
		_log(Copy.t("%s. Killed: %s.") % [Copy.t(why), Words.count(lost, "soldier")], true)
		_journal("deaths", {"n": lost})
		_vo_cue("resident_lost")
	return lost


## The first guard of a new run, and of a save from before the guard was made of people.
func _muster_start_guard() -> void:
	squads[player].guard = true
	for _i in int(bal.guard.start):
		var pick := _recruit_pick()
		if pick == "":
			break
		_enlist(pick)


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
	_hold_governors()
	var flushing_due: Array = []
	var lent_due: Array = []
	for person in residents:
		var away := int(person.get("flushing_back", 0)) > 0
		var lent := bool(person.get("lent", false))
		var was_out := int(person.absent) > 0 or int(person.sick) > 0
		if int(person.absent) > 0:
			person.absent = int(person.absent) - 1
		if int(person.sick) > 0 and not away:
			person.sick = int(person.sick) - 1
		if away and int(person.absent) <= 0:
			flushing_due.append(str(person.id))
		elif lent and int(person.absent) <= 0:
			lent_due.append(str(person.id))
		elif was_out and int(person.absent) <= 0 and int(person.sick) <= 0:
			_restore_post(str(person.id))
	if not flushing_due.is_empty():
		_resolve_flushing(flushing_due)
	for id in lent_due:
		_resolve_lent(str(id))


func _double_shift_sickness() -> void:
	var chance := float(catalog.laws.double_shifts.sick_chance)
	for room in rooms:
		if room.type in ["quarters", "platform", "meeting_hall", "infirmary"]:
			continue
		for id in room.staff:
			if rng.randf() < chance:
				people[id].sick = maxi(int(people[id].sick), 2)


## A few workers fall ill during the Cough. They stay on the roster; output drops while they cannot work.
func _cough_pull_workers() -> void:
	if quarantine:
		return
	var cap := int(bal.cough_pull)
	if cap <= 0:
		return
	var pool: Array = []
	for person in residents:
		if int(person.get("sick", 0)) > 0:
			continue
		if _staff_room_of(str(person.id)) == "":
			continue
		pool.append(person)
	var hit := 0
	while hit < cap and not pool.is_empty():
		var person: Dictionary = pool.pop_at(rng.randi() % pool.size())
		person.sick = maxi(int(person.sick), 2)
		hit += 1
	if hit > 0:
		_note("SICK %s fall ill and stay at their posts." % Words.count(hit, "worker"), "SICK Заболели и остались на местах: %s." % Words.count(hit, "worker"))


## Sick people used to be stripped off the roster here, which emptied rooms with no word why.
## They stay listed. _output_factor ignores them until they are well.
func _pull_sick_from_rooms() -> void:
	pass


func _spread_cough() -> void:
	if quarantine or bool(flags.get("list_sealed", false)):
		return
	var chance := cough_spread_chance() * _cough_mult()
	var sick_cells := {}
	for room in rooms:
		for id in room.staff:
			if int(people[id].sick) > 0:
				sick_cells[_ck(int(room.level), int(room.cell))] = true
	if sick_cells.is_empty():
		return
	for b in _merge_groups():
		var hit := false
		for r in b:
			if sick_cells.has(_ck(int(r.level), int(r.cell))):
				hit = true
		if hit:
			for r in b:
				sick_cells[_ck(int(r.level), int(r.cell))] = true
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
		var child_name := _birth()
		if child_name == "":
			continue
		born += 1
		if born <= 2:
			_add_hope(1, "birth")
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
	_note_moment("crunch", {}, 2)
	for leg in legs:
		_present_event(_crunch_event(leg))


func _crunch_legs() -> Array:
	var legs := _crunch_table()
	if crunch_kind == 1:
		return [legs.stacks, legs.ducts, legs.shopbelt]
	if crunch_kind == 2:
		return [legs.pantry, legs.dynamo, legs.belt]
	return [legs.pantry, legs.ducts, legs.belt]


func crunch_leg(id: String) -> Dictionary:
	return _crunch_table().get(id, {})


func _crunch_table() -> Dictionary:
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
	return {"pantry": pantry, "ducts": ducts, "belt": belt, "stacks": stacks, "shopbelt": shop, "dynamo": dynamo}


func _crunch_event(leg: Dictionary) -> Dictionary:
	var cost := int(leg.cost)
	var suffer: Dictionary = {"id": "leave", "label": str(leg.suffer), "crunch_suffer": true}
	var hit: Dictionary = leg.hit
	for key in hit:
		suffer[key] = hit[key]
	var ev := {
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
	var art := _crunch_banner(str(leg.id))
	if str(art.get("banner", "")) != "":
		ev["banner"] = str(art.get("banner", ""))
		ev["tag"] = str(art.get("tag", ""))
	return ev


## Same banners as ArtPack.crunch_event_art. Kept on the sim so a missing texture import
## does not drop the crunch card.
func _crunch_banner(id: String) -> Dictionary:
	match id:
		"pantry":
			return {"banner": "hunger", "tag": "hunger"}
		"ducts", "belt":
			return {"banner": "dark", "tag": "dark"}
		"stacks":
			return {"banner": "rat", "tag": "scrap"}
		"shopbelt":
			return {"banner": "tools", "tag": "tools"}
		"dynamo":
			return {"banner": "brownout", "tag": "dark"}
		_:
			return {}


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


func _dilemma() -> Dictionary:
	var row = bal.get("dilemmas", {})
	if row is Dictionary:
		return row
	return {}


## A state dilemma: weight 0, fired from the dawn trigger, never from the weighted pool.
## Bunker scenes also carry "trigger", but theirs is an order, not a stock or season test.
func _state_dilemma(ev: Dictionary) -> bool:
	var trigger = ev.get("trigger", null)
	if not (trigger is Dictionary):
		return false
	if trigger.has("order"):
		return false
	return trigger.has("food_weeks_lt") or trigger.has("air_weeks_lt") or trigger.has("sick_gte")


## Once a run, and not within dilemma_cooldown weeks of a dilemma already shown. The trigger must hold now.
func _dilemma_ready(ev: Dictionary) -> bool:
	var id := str(ev.id)
	if events_seen.has(id) or _has_event(pending, id) or week_event_ids.has(id):
		return false
	if bool(ev.get("chain_only", false)) or bool(ev.get("check_only", false)):
		return false
	var last := int(stats.get("dilemma_week", -99))
	if last > 0 and week < last + int(bal.get("dilemma_cooldown", 2)):
		return false
	var trigger = ev.get("trigger", {})
	return trigger is Dictionary and _trigger_holds(trigger)


func _trigger_holds(trigger: Dictionary) -> bool:
	if trigger.has("food_weeks_lt") and food_buffer_weeks() >= float(trigger.food_weeks_lt):
		return false
	if trigger.has("air_weeks_lt") and air_buffer_weeks() >= float(trigger.air_weeks_lt):
		return false
	if trigger.has("sick_gte") and sick_count() < int(trigger.sick_gte):
		return false
	if trigger.has("season") and not _season_is(str(trigger.season)):
		return false
	if trigger.has("station_known"):
		var sid := _resolve_station(str(trigger.station_known))
		if sid == "" or not bool(stations[sid].get("known", false)):
			return false
	return true


## At most one dilemma a dawn, and none while a major card is already waiting. Dawn is the only caller.
func _offer_dilemmas() -> void:
	for ev in pending:
		if event_is_big(ev):
			return
	for ev in catalog.events:
		if not _state_dilemma(ev) or not _event_ok(ev):
			continue
		if _present_event(ev):
			stats["dilemma_week"] = week
		return


## Numbers live in balance.json dilemmas. The catalog row stays free of them.
func _stamp_dilemma(ev: Dictionary) -> void:
	var d := _dilemma()
	var id := str(ev.id)
	for choice in ev.choices:
		var cid := str(choice.id)
		if id == "two_portions" and cid == "workers":
			choice.hope = int(d.get("workers_hope", 0))
			choice.discontent = int(d.get("workers_discontent", 0))
		elif id == "two_portions" and cid == "pier":
			choice.check = {"skill": "grit", "color": "white"}
			choice.success = {"food": int(d.get("pier_food", 0))}
			choice.failure = {"injured": int(d.get("pier_injured", 1))}
		elif id == "breathers_price" and cid == "lend":
			choice.air = int(d.get("air_gain", 0))
		elif id == "breathers_price" and cid == "pay":
			choice.cost = {"tokens": int(d.get("pay_tokens", 0))}
			choice.air = int(d.get("air_gain", 0))
		elif id == "breathers_price" and cid == "night":
			choice.check = {"skill": "senses", "color": "red"}
			choice.success = {"air": int(d.get("air_gain", 0))}
			choice.failure = {"opinion_exchange": int(d.get("steal_opinion", 0))}
		elif id == "the_list" and cid == "seal":
			choice.hope = int(d.get("seal_hope", 0))
		elif id == "the_list" and cid == "open":
			choice.sick = int(d.get("open_sick", 0))
			choice.synod = int(d.get("open_synod", 0))
		elif id == "the_list" and cid == "flushing":
			var sid := _flushing_id()
			if not _has_passage(sid):
				choice.locked = true
				choice.lock_reason = {"en": "Needs passage to Flushing.", "ru": "Нужен проход до Флашинга."}


func _apply_dilemma_choice(ev: Dictionary, choice: Dictionary) -> void:
	var d := _dilemma()
	var id := str(ev.id)
	var cid := str(choice.id)
	if id == "two_portions" and cid == "share":
		var weeks := int(d.get("share_weeks", 2))
		stats["share_until"] = week + weeks - 1
		_note("The yard shares what is left. Every room gives less for %d weeks." % weeks, "Двор делит остаток. Каждая комната даёт меньше ещё %d нед." % weeks)
	elif id == "two_portions" and cid == "workers":
		_note("The workers eat first. The rest of the yard notices.", "Сначала едят рабочие. Остальной двор это видит.")
	elif id == "breathers_price" and cid == "lend":
		var n := int(d.get("lend_people", 2))
		var weeks := int(d.get("lend_weeks", 4))
		var sent := 0
		for pid in _pick_away(n):
			people[pid].absent = maxi(int(people[pid].get("absent", 0)), weeks)
			people[pid].lent = true
			sent += 1
		_note("%s go to Bowling Green for %d weeks." % [Words.count(sent, "resident"), weeks], "В Боулинг-Грин на %d нед. уходят %s." % [weeks, Words.count(sent, "resident")])
	elif id == "the_list" and cid == "seal":
		flags["list_sealed"] = true
		var names := _shed(int(d.get("seal_deaths", 1)), "died", "sealed")
		if names.is_empty():
			_note("The lower level is sealed. The cough stops at the door.", "Нижний ярус запечатан. Кашель останавливается у двери.")
		else:
			_note("The lower level is sealed. %s does not come back up. The cough stops at the door." % ", ".join(names), "Нижний ярус запечатан. %s не поднимается. Кашель останавливается у двери." % ", ".join(names))
	elif id == "the_list" and cid == "flushing":
		var weeks := int(d.get("flushing_weeks", 3))
		var sent := 0
		for pid in _pick_sick(int(d.get("flushing_count", 3))):
			var person: Dictionary = people[pid]
			person.flushing_sick = maxi(1, int(person.get("sick", 0)))
			person.flushing_back = week + weeks
			person.absent = maxi(int(person.get("absent", 0)), weeks)
			sent += 1
		_note("%s leave for Flushing." % Words.count(sent, "sick resident"), "Во Флашинг уходят %s." % Words.count(sent, "sick resident"))


func _resolve_flushing(ids: Array) -> void:
	var need := int(_dilemma().get("flushing_synod", 10))
	var healed := synod >= need
	var names: PackedStringArray = []
	for raw in ids:
		var id := str(raw)
		if not people.has(id):
			continue
		var person: Dictionary = people[id]
		var saved := maxi(1, int(person.get("flushing_sick", 1)))
		person.erase("flushing_back")
		person.erase("flushing_sick")
		names.append(Copy.person(str(person.get("name", id))))
		if healed:
			person.sick = 0
		else:
			person.sick = maxi(int(person.sick), saved)
		if int(person.absent) <= 0 and int(person.sick) <= 0:
			_restore_post(id)
	if names.is_empty():
		return
	var who := ", ".join(names)
	if healed:
		_note("%s return from Flushing. The cough is gone." % who, "%s возвращаются из Флашинга. Кашля нет." % who)
	else:
		_note("Flushing sends them back no better. The Synod did not answer.", "Флашинг возвращает их без перемен. Синод не ответил.")


func _resolve_lent(id: String) -> void:
	if not people.has(id):
		return
	var person: Dictionary = people[id]
	person.erase("lent")
	var name := Copy.person(str(person.get("name", id)))
	var stay := float(_dilemma().get("lend_stay", 0.0))
	var line := int(_dilemma().get("lend_opinion", 0))
	if int(opinions.get("exchange", 0)) < line and rng.randf() < stay:
		_remove_resident(id, false, "left", "left")
		_note("%s stays with the Exchange." % name, "%s остаётся у Биржи." % name)
		return
	if int(person.get("absent", 0)) <= 0 and int(person.get("sick", 0)) <= 0:
		_restore_post(id)
	_note("%s comes back from Bowling Green." % name, "%s возвращается из Боулинг-Грина." % name)


## Live station id for a trigger token. "bowling" is the old stations.json id; the map calls it Bowling Green.
func _resolve_station(token: String) -> String:
	if token == "flushing":
		return _flushing_id()
	if stations.has(token):
		return token
	var wanted := token
	for raw in catalog.stations:
		if str(raw.get("id", "")) == token:
			wanted = str(raw.get("name", token))
			break
	for sid in stations:
		var name := str(stations[sid].get("name", ""))
		if name == wanted or name == token:
			return str(sid)
	return ""


func _flushing_id() -> String:
	if stations.has("garden"):
		return "garden"
	for sid in stations:
		if str(stations[sid].get("name", "")) == "Flushing":
			return str(sid)
	return ""


func _has_passage(sid: String) -> bool:
	if sid == "" or not stations.has(sid):
		return false
	var st: Dictionary = stations[sid]
	return str(st.get("owner", "")) == player or bool(st.get("passage", false))


func _resident_by_cast(cast: String) -> String:
	for person in residents:
		if cast_id_of(person) == cast:
			return str(person.id)
	return ""


## Lowest-labor adults who are not on the council, not governing, and not already away.
func _pick_away(n: int) -> Array:
	var pool: Array = []
	for person in residents:
		if _is_child(person) or _is_council(str(person.id)) or governor_of(str(person.id)) != "":
			continue
		if int(person.get("absent", 0)) > 0:
			continue
		pool.append(person)
	pool.sort_custom(func(a, b): return int(a.skills.get("labor", 0)) < int(b.skills.get("labor", 0)))
	var ids: Array = []
	for person in pool:
		if ids.size() >= n:
			break
		ids.append(str(person.id))
	return ids


func _pick_sick(n: int) -> Array:
	var pool: Array = []
	for person in residents:
		if int(person.get("sick", 0)) <= 0 or int(person.get("absent", 0)) > 0:
			continue
		pool.append(person)
	pool.sort_custom(func(a, b):
		var a_free := not _is_council(str(a.id)) and governor_of(str(a.id)) == ""
		var b_free := not _is_council(str(b.id)) and governor_of(str(b.id)) == ""
		if a_free != b_free:
			return a_free
		return int(a.skills.get("labor", 0)) < int(b.skills.get("labor", 0))
	)
	var ids: Array = []
	for person in pool:
		if ids.size() >= n:
			break
		ids.append(str(person.id))
	return ids


func _roll_events() -> void:
	if week == crunch_week:
		for item in follows:
			if int(item.due) <= week:
				item.due = week + 1
		_offer_dilemmas()
		return
	_present_due_follows()
	var pool := _event_pool(rng.randf() < 0.4)
	if pool.is_empty():
		pool = _event_pool(false)
	if not pool.is_empty():
		_present_event(_weighted(pool))
	_offer_dilemmas()


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
	if str(ev.get("requires", "")) == "digging" and not _digging_now():
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
			copy.follow_memory = memory
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


## Big decisions are the ones the dawn card opens with: major events, story beats (st1_, st2_, st3_), forced
## scenes, crisis legs and leader consequences (lc_, lc2_). The rest are small: the player meets them during the
## week (ui/station.gd), one at a time as they work, and all that are left when they end the week.
func event_is_big(ev: Dictionary) -> bool:
	var id := str(ev.get("id", ""))
	if bool(ev.get("major", false)) or ev.has("trigger") or not crunch_leg(id).is_empty():
		return true
	return id.begins_with("st1_") or id.begins_with("st2_") or id.begins_with("st3_") or id.begins_with("lc_") or id.begins_with("lc2_")


## Moves the big decisions to the front of the queue, keeping each group's order, so dawn shows those first and
## the small ones wait. Only the player's screen calls this; bots answer the queue as it was drawn.
func big_first() -> void:
	var big: Array = []
	var small: Array = []
	for ev in pending:
		(big if event_is_big(ev) else small).append(ev)
	pending = big + small


func small_pending() -> int:
	var n := 0
	for ev in pending:
		if not event_is_big(ev):
			n += 1
	return n


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
	if _state_dilemma(copy):
		_stamp_dilemma(copy)
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
			if ev.has("needs") or ev.has("trigger"):
				continue
			if not _event_ok(ev):
				continue
			pool.append(ev)
	return pool


func _event_ok(ev: Dictionary) -> bool:
	var id := str(ev.id)
	if _state_dilemma(ev):
		return _dilemma_ready(ev)
	if bool(ev.get("chain_only", false)) or bool(ev.get("check_only", false)):
		return false
	if ev.has("needs") or ev.has("trigger"):
		return false
	if id == "lamps" and week == crunch_week:
		return false
	var cool := maxi(int(bal.get("event_cooldown", 8)), int(ev.get("cooldown", 8)))
	if event_last.has(id) and week - int(event_last[id]) < cool:
		return false
	if not bool(ev.get("major", false)) and int(event_times.get(id, 0)) >= int(bal.get("event_minor_cap", 1)):
		return false
	if week < int(ev.get("min_week", 1)):
		return false
	if week > int(ev.get("max_week", 99)):
		return false
	if discontent < int(ev.get("min_discontent", 0)):
		return false
	if str(ev.get("requires", "")) == "digging" and not _digging_now():
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
		var reason = choice.get("lock_reason", "")
		if reason is Dictionary:
			return line_of({"lock_reason": reason}, "lock_reason")
		return str(reason)
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
			return "Нужно %d %s, у тебя %d" % [int(req.proofs_min), Copy.plural(int(req.proofs_min), ["доказательство", "доказательства", "доказательств"]), proofs()]
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
		if _is_child(person) or int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
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
	if skill == "wits" and _perk_int("check_wits") != 0:
		rows.append({"text": "perk.short.library", "amount": _perk_int("check_wits")})
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
			var live: Dictionary = pending[pending.size() - 1]
			if not bool(live.get("opened", false)):
				_apply_effect_block(live.get("effects_on_open", {}), "", false, live)
				live.opened = true
		else:
			item.week = week + 3


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
			return "Повтор, когда %s дойдёт до ступени %d" % [Copy.t(named), int(retry.level)]
		return "Retry after: %s level %d" % [named, int(retry.level)]
	if retry.has("room"):
		var name := str(catalog.rooms[str(retry.room)].name)
		if Copy.ru():
			return "Повтор, когда построишь: %s" % Copy.t(name)
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
	if str(ev.get("id", "")) == "two_portions" and str(choice.get("id", "")) == "pier":
		var bait := _resident_by_cast("bait")
		if bait != "":
			person_id = bait
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
	if people.has(person_id):
		_life_note(people[person_id], "check_rolled", {})
		if success:
			people[person_id].checks_passed = int(people[person_id].get("checks_passed", 0)) + 1
	if success:
		_apply_effect_block(choice.get("success", {}), person_id, false, ev)
		if str(ev.id) == "vents":
			vent_cut = 0
		return true
	if color == "red" or _state_dilemma(ev):
		_apply_effect_block(choice.get("failure", {}), person_id, color == "red", ev)
		return true
	_apply_effect_block(choice.get("failure", {}), person_id, false, ev)
	if retried:
		choice.locked = true
		choice.spent = true
		choice.lock_reason = "The roll stands." if not Copy.ru() else "Перебросить нельзя."
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
				for r in _merge_group_of(room):
					r.mold = mold
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
	if _state_dilemma(ev):
		_apply_dilemma_choice(ev, choice)
	var mark := str(choice.get("flag", ""))
	if mark != "":
		flags[mark] = true
	if bool(choice.get("crunch_suffer", false)):
		var drops: Array = stats.get("crunch_drops", [])
		drops.append(str(ev.title))
		stats["crunch_drops"] = drops
	pending.pop_front()
	_schedule_follow(ev, choice)
	_log("EVENT %s: %s" % [line_of(ev, "title"), line_of(choice, "label")], bool(ev.get("major", false)))
	if str(ev.get("burial_id", "")) != "":
		_resolve_burial(str(ev.burial_id), str(choice.get("id", "")))
	else:
		_note_moment("dilemma", {"title": line_of(ev, "title"), "choice": line_of(choice, "label")}, 3)
		var named := str(action.get("person", ""))
		if named != "" and people.has(named):
			_life_note(people[named], "named_dilemma", {})
	return true


## What picking this event choice changes right now, already clamped the way _apply_event applies it, so the
## button can say it in words: {stock: {key: delta}, hope, discontent, people, sick, papers, standing: {fid: delta},
## check, bet}. A check or a bet only pays its cost up front; the rest is decided by the roll.
func choice_effects(choice: Dictionary) -> Dictionary:
	var fx := {"stock": {}, "hope": 0, "discontent": 0, "people": 0, "sick": 0, "papers": 0, "standing": {},
		"check": choice.has("check"), "bet": choice.has("bet")}
	var after: Dictionary = stock.duplicate()
	var cost = choice.get("cost", {})
	if cost is Dictionary:
		for key in cost:
			if ARTIFACTS.has(str(key)):
				if str(key) == "papers":
					fx.papers = -int(cost[key])
			else:
				after[key] = int(after.get(key, 0)) - int(cost[key])
	if not fx.check and not fx.bet:
		for key in ["food", "air", "power", "materials", "tokens", "influence"]:
			if choice.has(key):
				after[key] = maxi(0, int(after[key]) + int(choice[key]))
		var h := clampi(hope + int(choice.get("hope", 0)), 0, 100)
		var lifts = choice.get("trait_hope", {})
		if lifts is Dictionary:
			for trait_name in lifts:
				if _any_trait(str(trait_name)):
					h = clampi(h + int(lifts[trait_name]), 0, 100)
		var away = choice.get("trait_absent", {})
		if away is Dictionary:
			for trait_name in away:
				for person in residents:
					if _has_trait(person, str(trait_name)):
						h = clampi(h - 2, 0, 100)
		fx.hope = h - hope
		fx.discontent = clampi(discontent + int(choice.get("discontent", 0)), 0, 100) - discontent
		fx.people = int(choice.get("people", 0))
		fx.sick = maxi(0, int(choice.get("sick", 0)))
		fx.papers = int(fx.papers) + int(choice.get("papers", 0))
		var shifts = choice.get("standing", {})
		if shifts is Dictionary:
			for fid in shifts:
				var now := 0
				if standing.has(str(fid)):
					now = int(standing[str(fid)])
				elif not leader(str(fid)).is_empty():
					now = clampi(int(leader(str(fid)).get("start_opinion", 0)), -100, 100)
				else:
					continue
				var moved := clampi(now + int(shifts[fid]), -100, 100) - now
				if moved != 0:
					fx.standing[str(fid)] = moved
	for key in after:
		var delta := int(after[key]) - int(stock.get(key, 0))
		if delta != 0:
			fx.stock[key] = delta
	return fx


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
		var names := _shed(lost, "died", "dilemma")
		if names.is_empty():
			_log("LOST %d" % lost, true)
		else:
			_log("LOST %s" % ", ".join(names), true)
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
		_life_note(people[id], "injured", {})
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
		if int(person.get("absent", 0)) > 0 and governor_of(str(person.id)) == "":
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
		if (int(person.get("absent", 0)) > 0 and governor_of(str(person.id)) == "") or int(person.get("sick", 0)) > 0:
			n += 1
	return n


func _disable_room(type: String, weeks: int) -> void:
	if type == "" or weeks <= 0:
		return
	weeks = mini(2, weeks)
	for room in rooms:
		if str(room.type) != type:
			continue
		if shrugs_down(room):
			_log("ARMOURED %s keeps working" % type, true)
			return
		for r in _merge_group_of(room):
			r.disabled = maxi(int(r.get("disabled", 0)), weeks)
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
			_shed(-n, "left", "left")
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
	for season in seasons:
		var at := int(season.week)
		var warning := flood_warning() if str(season.id) == "flood" else int(bal.season_warning)
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
		_note_moment("season", {"season": str(active_season.id)}, 2)
		if str(active_season.id) == "flood":
			_recede_flood()
		active_season = {}
	if flood_guard and _flood_eta() > flood_warning():
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


func _radio_ready() -> bool:
	for room in rooms:
		if str(room.type) != "radio":
			continue
		if bool(room.offline) or int(room.get("disabled", 0)) > 0 or bool(room.get("switched_off", false)):
			continue
		if room.staff.size() >= 1:
			return true
	return false


func listening_build_block() -> String:
	if not _radio_ready():
		return Copy.t("listening.need_radio")
	return ""


func _listening_room():
	for room in rooms:
		if str(room.type) == "listening_post":
			return room
	return null


func listening_active() -> bool:
	var room = _listening_room()
	if room == null:
		return false
	if bool(room.offline) or int(room.get("disabled", 0)) > 0 or bool(room.get("browned", false)) or bool(room.get("switched_off", false)):
		return false
	return room.staff.size() >= int(catalog.rooms["listening_post"].get("staff_min", 1))


func listening_probe_live() -> bool:
	return str(flags.get("listening_probe_sid", "")) != ""


func listening_card_key() -> String:
	var room = _listening_room()
	if room == null:
		return "listening.offline"
	if bool(room.offline) or int(room.get("disabled", 0)) > 0 or bool(room.get("switched_off", false)) or bool(room.get("browned", false)):
		return "listening.offline"
	if room.staff.size() < int(catalog.rooms["listening_post"].get("staff_min", 1)):
		return "listening.unstaffed"
	return "listening.listen_status"


func room_can_push(type: String) -> bool:
	var defin: Dictionary = catalog.rooms.get(type, {})
	return bool(defin.get("push", true))


func rumor_truth() -> float:
	if listening_active():
		return 0.95
	if _has_radio():
		return 0.90
	return 0.0


func listening_blown_cut() -> float:
	var room = _listening_room()
	if room == null:
		return 0.0
	var tier := int(room.get("upgrade", 0))
	if tier >= 2:
		return 0.10
	if tier >= 1:
		return 0.05
	return 0.0


func listening_blown_chance(kind: String) -> float:
	var key := "probe_blown" if kind == "probe" else "tap_blown"
	var base := 0.15 if kind == "probe" else 0.25
	return maxf(0.0, float(bal.get(key, base)) - listening_blown_cut())


func listening_blown_pct(kind: String) -> int:
	return int(round(listening_blown_chance(kind) * 100.0))


func _intent_hidden(kind: String) -> bool:
	if kind == "demand_posted":
		return false
	if listening_active() or _has_radio():
		return false
	return net_rng.randf() < 0.25


func listening_probe_targets() -> Array:
	var out: Array = []
	for sid in stations:
		var st: Dictionary = stations[sid]
		if not bool(st.get("known", false)):
			continue
		if str(st.owner) == player or str(st.owner) == "bunker" or str(st.get("bunker", "")) != "":
			continue
		out.append(str(sid))
	return out


func listening_tap_targets() -> Array:
	var out: Array = []
	for fid in opinions:
		if bool(at_war.get(str(fid), false)):
			continue
		out.append(str(fid))
	return out


func listening_idle_line() -> String:
	if not listening_active():
		return ""
	if int(flags.get("listening_order_week", -1)) == week:
		return ""
	var room = _listening_room()
	if room != null:
		for pid in room.staff:
			var who := _listening_who_line(str(pid))
			if who != "":
				return who
	return Copy.t("staff.listening.idle_%d" % (1 + (week % 2)))


func listening_assign_line(person_id: String) -> String:
	var who := _listening_who_line(person_id)
	if who != "":
		return who
	var n := 1 + absi(person_id.hash()) % 6
	return Copy.t("staff.listening.assign_%d" % n)


func _listening_who_line(person_id: String) -> String:
	var first := str(people.get(person_id, {}).get("name", "")).get_slice(" ", 0)
	if first == "":
		return ""
	var key := "staff.listening.who.%s" % first
	var line := Copy.t(key)
	return "" if line == key else line


func _listening_room_block() -> String:
	return "" if listening_card_key() == "listening.listen_status" else Copy.t(listening_card_key())


func _listening_busy() -> String:
	if int(flags.get("listening_order_week", -1)) == week:
		return Copy.t("One order a week.")
	return ""


func _probe_block(sid: String) -> String:
	var room := _listening_room_block()
	if room != "":
		return room
	var busy := _listening_busy()
	if busy != "":
		return busy
	if not stations.has(sid):
		return Copy.t("That station is out of reach.")
	var st: Dictionary = stations[sid]
	if not bool(st.get("known", false)) or str(st.owner) == player or str(st.owner) == "bunker" or str(st.get("bunker", "")) != "":
		return Copy.t("That station is out of reach.")
	var need := int(bal.get("probe_tokens", 3))
	if int(stock.tokens) < need:
		return Copy.t("Needs %s, the yard has %s.") % [Words.count(need, "token"), Words.count(int(stock.tokens), "token")]
	return ""


func _tap_block(fid: String) -> String:
	var room := _listening_room_block()
	if room != "":
		return room
	var busy := _listening_busy()
	if busy != "":
		return busy
	if not opinions.has(fid) or bool(at_war.get(fid, false)):
		return Copy.t("That station is out of reach.")
	if int(stock.food) < 2:
		return Copy.t("Needs %s, the yard has %s.") % [Words.count(2, "food"), Words.count(int(stock.food), "food")]
	return ""


func _order_probe(sid: String) -> bool:
	listening_line = ""
	flags.erase("listening_probe_sid")
	if not listening_active() or not stations.has(sid):
		return false
	var st: Dictionary = stations[sid]
	if not bool(st.get("known", false)) or str(st.owner) == player or str(st.owner) == "bunker" or str(st.get("bunker", "")) != "":
		return false
	var cost := int(bal.get("probe_tokens", 3))
	if int(stock.tokens) < cost:
		return false
	stock.tokens = int(stock.tokens) - cost
	var place := station_text(sid, "community")
	if place == "":
		place = str(st.get("name", sid))
	if net_rng.randf() < listening_blown_chance("probe"):
		_listening_blown(str(st.owner), place)
		return true
	st.intel = clampi(maxi(int(st.get("intel", 0)), 2), 0, 3)
	st.wired_until = int(week) + 2
	var faction := Copy.t(_fname(str(st.owner))) if catalog.factions.has(str(st.owner)) else Copy.t("Neutral")
	var line := Copy.fill("listening.probe_reveal", {
		"faction": faction,
		"station": place,
		"opinion": _signed_int(int(opinions.get(str(st.owner), 0))),
	})
	listening_line = line
	notices.append(line)
	_log("ORDER probe %s intel %d" % [str(st.name), int(st.intel)])
	return true


func _order_tap(fid: String) -> bool:
	listening_line = ""
	if not listening_active() or not opinions.has(fid) or bool(at_war.get(fid, false)):
		return false
	if int(stock.food) < 2:
		return false
	stock.food = int(stock.food) - 2
	var place := _listening_place(fid)
	if net_rng.randf() < listening_blown_chance("tap"):
		_listening_blown(fid, place)
		return true
	_add_opinion(fid, -4, "listening")
	var good := listening_flow_good(fid)
	var line := ""
	if good != "":
		stock[good] = int(stock.get(good, 0)) + 1
		line = Copy.fill("listening.tap_skim", {"good": Copy.res(good)})
	else:
		line = Copy.fill("listening.tap_plan", {"plan": listening_plan_phrase(fid)})
	listening_line = line
	notices.append(line)
	_log("ORDER tap %s" % fid)
	return true


func _listening_blown(fid: String, place: String) -> void:
	_add_hope(-1, "listening")
	if opinions.has(fid):
		_add_opinion(fid, int(bal.get("blown_opinion", -12)), "listening")
	_add_discontent(2, "listening")
	_note_moment("listening_blown", {"station": place}, 2)
	_disable_room("listening_post", 1)
	var blown := Copy.fill("listening.blown", {"station": place})
	var dawn := Copy.t("listening.blown_dawn")
	listening_line = "%s %s" % [blown, dawn]
	notices.append(blown)
	notices.append(dawn)
	_log(blown, true)


func _listening_place(fid: String) -> String:
	var cap := str(catalog.factions.get(fid, {}).get("capital", ""))
	if stations.has(cap):
		var place := station_text(cap, "community")
		if place != "":
			return place
	return Copy.t(_fname(fid))


func listening_flow_good(fid: String) -> String:
	var cap := str(catalog.factions.get(fid, {}).get("capital", ""))
	for sid in stations:
		if str(sid) == cap:
			continue
		var st: Dictionary = stations[sid]
		if str(st.owner) != fid:
			continue
		var goods: Dictionary = catalog.station_goods(str(sid))
		for key in ["food", "materials", "tokens", "influence", "air"]:
			if int(goods.get(key, 0)) > 0:
				return str(key)
	return ""


func listening_plan_phrase(fid: String) -> String:
	var ru := Copy.ru()
	if _demand_open(fid):
		return "оплата жетонами" if ru else "pay tokens"
	for intent in telegraphed:
		if str(intent.get("faction", "")) != fid or bool(intent.get("hidden", false)):
			continue
		if str(intent.get("kind", "")) != "buy":
			continue
		var place := ""
		var sid := str(intent.get("station", ""))
		if stations.has(sid):
			place = station_text(sid, "community")
		if place != "":
			return ("подарок жетонами на %s" % place) if ru else ("gift tokens to %s" % place)
		return "подарок жетонами" if ru else "gift tokens"
	var need := "food"
	var cap := str(catalog.factions.get(fid, {}).get("capital", ""))
	if stations.has(cap):
		var lowest := _lowest_need(stations[cap])
		if lowest in ["food", "materials", "air", "medicine"]:
			need = lowest
	if ru:
		var ru_need := {"food": "едой", "materials": "материалами", "air": "воздухом", "medicine": "лекарствами"}
		return "помощь %s" % str(ru_need.get(need, "едой"))
	return "aid %s" % need


func _signed_int(n: int) -> String:
	if n > 0:
		return "+%d" % n
	return str(n)


func _clear_wired(sid: String) -> void:
	if stations.has(sid):
		stations[sid].erase("wired_until")


func _heal_squads() -> void:
	for fid in squads:
		var sq: Dictionary = squads[fid]
		if str(fid) == player:
			if sq.has("roster"):
				if int(sq.get("attrition", 0)) > 0:
					sq.attrition = maxi(0, int(sq.attrition) - int(bal.squad_heal))
				_sync_party(sq)
			continue
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
	_dress(residents)


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


## Cast id of a resident for the portrait, "" for residents outside the cast and for ids that are not residents.
func cast_of(id: String) -> String:
	if not people.has(id):
		return ""
	var person: Dictionary = people[id]
	var cast := cast_id_of(person)
	return "" if cast == str(person.get("id", "")) else cast


func has_coney_cast() -> bool:
	return capital_id == "southdepot" or capital_id == "coney"


## The portrait a resident wears, out of `names` (portrait_01, portrait_02...): the face chosen when they
## arrived (see _dress), kept for the whole game and across load. Ids that are not residents, or whose face is
## not among `names`, get an unpinned face by hash.
func portrait_name(id: String, names: Array) -> String:
	if names.is_empty():
		return ""
	if people.has(id) and names.has(str(people[id].get("face", ""))):
		return str(people[id].face)
	var pinned := pinned_faces() if catalog != null else {}
	var rest: Array = names.filter(func(name): return not pinned.has(name))
	if rest.is_empty():
		rest = names
	return str(rest[_stable_hash(id) % rest.size()])


## Faces pinned to somebody: the profile pins of the core residents and, in a Coney game, the cast pins.
func pinned_faces() -> Dictionary:
	var out := {}
	var rows: Dictionary = catalog.profiles.get("residents", {})
	for id in rows:
		if rows[id].has("portrait"):
			out[str(rows[id].portrait)] = true
	if has_coney_cast():
		for cast in catalog.cast_portraits:
			out[str(catalog.cast_portraits[cast])] = true
	return out


## The pinned face of a person: the cast pin for a Coney cast member, the profile pin for a core resident who
## keeps their own name, "" for everyone else.
func portrait_pin(person: Dictionary) -> String:
	var id := str(person.get("id", ""))
	var cast := cast_id_of(person)
	if cast != id:
		return str(catalog.cast_portraits.get(cast, ""))
	return str(catalog.profiles.get("residents", {}).get(id, {}).get("portrait", ""))


## "m" or "f": a Coney cast member's from the cast, a core resident's from the profile, anyone else's from the
## first name (data/resident_profiles.json generated_names), or by a stable hash of the id for an unknown name.
func sex_of(person: Dictionary) -> String:
	var id := str(person.get("id", ""))
	var cast := cast_id_of(person)
	var prof: Dictionary = catalog.profiles
	if cast != id and prof.get("cast", {}).has(cast):
		return str(prof.cast[cast].get("sex", "m"))
	var row: Dictionary = prof.get("residents", {}).get(id, {})
	if row.has("sex"):
		return str(row.sex)
	var first := str(person.get("name", "")).get_slice(" ", 0)
	var names: Dictionary = prof.get("generated_names", {})
	if names.has(first):
		return str(names[first])
	return "f" if _stable_hash(id) % 2 == 1 else "m"


## Gives `rows` (already among the residents) their sex and face. Pinned people take their pin; the others a
## face of their own sex, by id: first one pinned to nobody and worn by no living resident, then any of their
## sex nobody living wears, then any of their sex.
func _dress(rows: Array) -> void:
	var worn := {}
	for person in residents:
		if str(person.get("face", "")) != "":
			worn[str(person.face)] = true
	var later: Array = []
	for person in rows:
		if not person.has("sex"):
			person["sex"] = sex_of(person)
		if str(person.get("face", "")) != "":
			continue
		var pin := portrait_pin(person)
		if pin != "":
			person["face"] = pin
			worn[pin] = true
		else:
			later.append(person)
	var faces: Dictionary = catalog.profiles.get("portrait_sex", {})
	var pinned := pinned_faces()
	for person in later:
		var own: Array = faces.keys().filter(func(face): return str(faces[face]) == str(person.sex))
		own.sort()
		var pick := ""
		for pool in [own.filter(func(face): return not pinned.has(face) and not worn.has(face)), own.filter(func(face): return not worn.has(face)), own]:
			if not pool.is_empty():
				pick = str(pool[_stable_hash(str(person.id)) % pool.size()])
				break
		person["face"] = pick
		worn[pick] = true


static func _stable_hash(text: String) -> int:
	var n := 0
	for i in text.length():
		n = (n * 33 + text.unicode_at(i)) % 1000003
	return n


## Profession, before-the-Silence line or keepsake from a resident's profile in the game language; "" for the
## Coney cast (their dossier has its own) and for people without a profile.
func profile_line(person: Dictionary, key: String) -> String:
	var id := str(person.get("id", ""))
	if cast_id_of(person) != id:
		return ""
	return line_of(catalog.profiles.get("residents", {}).get(id, {}), key)


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
	_press_loyalty(st, "synod")
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
			"governor": "",
			"deals": 0,
			"passage": false,
			"known": false,
			"intel": 0,
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
		"gear": float(pb.gear), "fight": 1, "name": str(pb.get("name", "Platform guard")),
		"dest": "", "secure": 0, "away": false, "fording": false,
		"roster": [], "returning": false, "return_to": capital_id, "return_week": 0, "attrition": 0, "armor_fit": false,
	}
	_fill_roster(squads[player], int(pb.size))
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
		"switched_off": false, "push_weeks": [], "push_tint_until": 0,
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
	if str(cell.get("pile", "")) != "":
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


func _event_draw_weight(ev: Dictionary) -> int:
	var w := int(ev.get("weight", 1))
	if str(ev.get("id", "")) == "static":
		w *= maxi(1, _static_weight_mult())
	return maxi(0, w)


func _weighted(pool: Array, stream: RandomNumberGenerator = null) -> Dictionary:
	var total := 0
	for ev in pool:
		total += _event_draw_weight(ev)
	if total <= 0:
		return pool[0]
	var roll := (stream if stream != null else rng).randi_range(1, total)
	var acc := 0
	for ev in pool:
		acc += _event_draw_weight(ev)
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
	"stock", "salvage", "hope", "discontent", "residents", "people", "cells", "rooms",
	"laws_on", "law_lock", "council", "stations", "tunnels", "squads",
	"opinions", "ambition", "at_war", "trade_on", "telegraphed", "demands",
	"pending", "dig", "clear", "build", "expedition", "active_season", "artifacts",
	"pumped", "flood_guard", "quarantine", "synod", "floor_met", "orders_left", "decisions",
	"hope_zero", "next_person", "demand_seq", "log", "errors", "stats",
	"food_buffers", "growth_bank", "hope_week", "hope_history", "hope_totals",
	"dis_totals", "hope_samples", "last_net", "last_hope_delta", "last_dis_delta",
	"dis_week", "audit", "rot_week", "crunch_week", "crunch_kind",
	"crunch_power", "belt_down", "workshop_down", "gen_down", "event_last",
	"week_event_ids", "power_order", "event_times", "events_seen", "event_history",
	"follows", "pressure", "warning_weeks", "crisis_faults", "demand_log",
	"power_zero_streak", "rally_lock", "address_week", "hardship_now", "chronicle", "departed", "burials", "creed", "notices", "combat_lock", "seat_used", "opinion_memory", "queued_orders", "order_reports", "choice_results", "rumor",
	"check_schedule", "white_pending", "vent_cut", "relations", "flags", "journal",
	"vo_heard", "radio_week", "standing", "standing_memory", "audience", "audience_last",
	"audience_due", "audience_deals", "vo_cues", "leader_answers", "fragments", "story_words", "help_last",
	"story_queue", "proof_extra",
]


## SaveGame stamps files with "schema": SAVE_SCHEMA; such saves must carry every PERSIST key plus all
## RNG_KEYS or they are rejected. Data without "schema" is version 1, the format from before.
## Adding a PERSIST key needs a new schema number and its own migration list. Version 7 added sex and face to
## every person; older saves get them from the profiles and names on load (_dress_legacy). Version 8 added
## "governor" to every station; older saves start with no governors. Version 9 added "address_week"; older saves
## start with the platform not yet addressed. Version 10 added the chronicle, departures, and burials.
## Version 11 added the truce lock from tunnel combat; older saves start with none.
## Version 12 added the map rumor; older saves start with none.
## Version 13 added the salvage board; older saves start with none.
## Version 14 added the yard clear job. Older saves start with nobody clearing.
const SAVE_SCHEMA := 14
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
## Fields a version 1 to 8 save may lack: the platform not addressed yet.
const V8_ADDED := ["address_week"]
## Fields a version 1 to 9 save may lack: no chronicle, no named departures, no burial waiting.
const V9_ADDED := ["hardship_now", "chronicle", "departed", "burials", "creed", "notices"]
## Fields a version 1 to 10 save may lack: no truce lock from tunnel combat yet.
const V10_ADDED := ["combat_lock"]
## Fields a version 1 to 11 save may lack: no map rumor yet.
const V11_ADDED := ["rumor"]
## Fields a version 1 to 12 save may lack: no salvage board yet.
const V12_ADDED := ["salvage"]
## Fields a version 1 to 13 save may lack: no pile crew out yet.
const V13_ADDED := ["clear"]

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
	if bal.is_empty():
		bal = catalog.balance
	_jitter_seasons()
	if squads.has(player) and not bool(squads[player].get("guard", false)):
		_muster_start_guard()
	_sync_guard()
	_ready_salvage()
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
		elif (int(schema) == 1 and V1_ADDED.has(key)) or (int(schema) <= 2 and V2_ADDED.has(key)) or (int(schema) <= 3 and V3_ADDED.has(key)) or (int(schema) <= 4 and V4_ADDED.has(key)) or (int(schema) <= 5 and V5_ADDED.has(key)) or (int(schema) <= 8 and V8_ADDED.has(key)) or (int(schema) <= 9 and V9_ADDED.has(key)) or (int(schema) <= 10 and V10_ADDED.has(key)) or (int(schema) <= 11 and V11_ADDED.has(key)) or (int(schema) <= 12 and V12_ADDED.has(key)) or (int(schema) <= 13 and V13_ADDED.has(key)):
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
	if int(schema) <= 6:
		_dress_legacy(state, cat)
	if int(schema) <= 7 and state.stations is Dictionary:
		for sid in state.stations:
			if state.stations[sid] is Dictionary and not state.stations[sid].has("governor"):
				state.stations[sid]["governor"] = ""
	## Blueprints live on stock. Saves from before the salvage board have none; they start at zero.
	if int(schema) <= 11 and state.stock is Dictionary and not state.stock.has("blueprints"):
		state.stock["blueprints"] = 0
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


## A version 1 to 6 save has people without sex and face: dress them in resident order as a new run would.
## Malformed records are left for _state_problem to refuse.
static func _dress_legacy(state: Dictionary, cat: Catalog) -> void:
	if not (state.people is Dictionary) or not (state.residents is Array):
		return
	var game := Game.new()
	game.catalog = cat
	game.capital_id = str(state.capital_id)
	var rows: Array = []
	for row in state.residents:
		if row is Dictionary and state.people.get(str(row.get("id", ""))) is Dictionary:
			rows.append(state.people[str(row.id)])
	game.people = state.people
	game.residents = rows
	game._dress(rows)


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
		var faces: Dictionary = cat.profiles.get("portrait_sex", {})
		if not ["m", "f"].has(person.get("sex")):
			return "person %s sex %s" % [str(id), str(person.get("sex"))]
		if str(faces.get(person.get("face", ""), "")) != str(person.sex):
			return "person %s (%s) wears %s" % [str(id), str(person.sex), str(person.get("face"))]
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
		if not (room is Dictionary) or not cat.rooms.has(str(room.get("type", ""))) or not (room.get("staff") is Array) or not (room.get("uid") is String):
			return "room malformed"
		if uids.has(str(room.get("uid", ""))):
			return "room %s twice" % str(room.get("uid", ""))
		uids[str(room.uid)] = true
		for id in room.staff:
			if not state.people.has(str(id)):
				return "room %s staffed by unknown %s" % [room.uid, id]
	for job in [state.dig, state.clear, state.build]:
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
	for law in state.laws_on:
		if not cat.laws.has(str(law)):
			return "law %s unknown" % str(law)
	for tunnel in state.tunnels:
		if not (tunnel is Dictionary) or not state.stations.has(str(tunnel.get("a", ""))) or not state.stations.has(str(tunnel.get("b", ""))):
			return "tunnel to an unknown station"
	var why_shape := _shape_problem(state, cat)
	if why_shape != "":
		return why_shape
	for sid in state.stations:
		var gov := str(state.stations[sid].get("governor", ""))
		if gov != "" and not state.people.has(gov):
			return "station %s governed by unknown %s" % [str(sid), gov]
	return ""


## Shapes of a fresh run on this catalog: the keys every person, station, room and council seat carries there,
## with their types. A saved record must carry them too, or the week code reads a hole.
static var _models := {}


static func _model(cat: Catalog) -> Dictionary:
	var id := cat.get_instance_id()
	if not _models.has(id):
		var fresh := Game.new()
		fresh.setup(cat, 1, 40)
		_models.clear()
		_models[id] = {
			"stock": _common([fresh.stock]), "person": _common(fresh.people.values()),
			"station": _common(fresh.stations.values()), "room": _common(fresh.rooms), "seat": _common(fresh.council),
			"tunnel": _common(fresh.tunnels),
		}
	return _models[id]


## What every row shares: a Dictionary of the keys all rows have (each with what their values share),
## a sample value when all rows are of one kind, or null when they differ.
static func _common(rows: Array):
	if rows.is_empty():
		return null
	var first = rows[0]
	for row in rows:
		if not _same_kind(row, first):
			return null
	if not first is Dictionary:
		return [] if first is Array else first
	var out := {}
	for key in first:
		var values: Array = []
		for row in rows:
			if not row.has(key):
				values = []
				break
			values.append(row[key])
		if not values.is_empty():
			out[key] = _common(values)
	return out


static func _same_kind(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return true
	return typeof(a) == typeof(b)


static func _shape(value, model, path: String) -> String:
	if model == null:
		return ""
	if not _same_kind(value, model):
		return "%s is %s" % [path, type_string(typeof(value))]
	if model is Dictionary:
		for key in model:
			if not value.has(key):
				return "%s.%s missing" % [path, str(key)]
			var why := _shape(value[key], model[key], "%s.%s" % [path, str(key)])
			if why != "":
				return why
	return ""


static func _shape_problem(state: Dictionary, cat: Catalog) -> String:
	var model := _model(cat)
	var why := _shape(state.stock, model.stock, "stock")
	for id in state.people:
		if why == "":
			why = _shape(state.people[id], model.person, "person %s" % str(id))
	for id in state.stations:
		if why == "":
			why = _shape(state.stations[id], model.station, "station %s" % str(id))
	for room in state.rooms:
		if why == "":
			why = _shape(room, model.room, "room %s" % str(room.uid))
	for seat in state.council:
		if why == "":
			why = _shape(seat, model.seat, "council seat")
	for tunnel in state.tunnels:
		if why == "":
			why = _shape(tunnel, model.tunnel, "tunnel")
	if why != "":
		return why
	for item in state.check_schedule:
		if not (item is Dictionary) or not (item.get("id") is String) or not _same_kind(item.get("week"), 0) or not (item.get("done") is bool):
			return "check schedule malformed"
	for ev in state.pending + state.white_pending:
		why = _event_problem(ev, cat)
		if why != "":
			return why
	return ""


## A waiting event needs its id and choices, each choice its id, and every number the catalog's choice
## carries must still be a number.
static func _event_problem(ev, cat: Catalog) -> String:
	if not (ev is Dictionary) or not (ev.get("id") is String) or not (ev.get("choices") is Array):
		return "waiting event malformed"
	var source := {}
	for row in cat.events:
		if str(row.get("id", "")) == ev.id:
			source = row
	for choice in ev.choices:
		if not (choice is Dictionary) or not (choice.get("id") is String):
			return "event %s choice malformed" % ev.id
		for row in source.get("choices", []):
			if str(row.get("id", "")) != choice.id:
				continue
			for key in row:
				if (row[key] is int or row[key] is float) and choice.has(key) and not _same_kind(choice[key], 0):
					return "event %s choice %s %s is %s" % [ev.id, choice.id, str(key), type_string(typeof(choice[key]))]
	return ""


func _line_name(room_name: String, lower: bool) -> String:
	if Copy.ru():
		return Copy.t(room_name)
	return room_name.to_lower() if lower else room_name


func _note(en: String, ru_line: String) -> void:
	_log(ru_line if Copy.ru() else en, true)


func _log(text: String, important := false) -> void:
	log.append({"week": week, "text": text, "important": important})


func text_pack(pack) -> String:
	if typeof(pack) != TYPE_DICTIONARY:
		return str(pack)
	return line_of({"v": pack}, "v")


func fill_text(pack, vars: Dictionary) -> String:
	var text := text_pack(pack)
	for key in vars:
		text = text.replace("{%s}" % str(key), str(vars[key]))
	return text.replace("{a}", "").replace("{ee}", "")


func _note_moment(kind: String, fields: Dictionary, weight: int) -> void:
	chronicle.append({"week": week, "kind": kind, "weight": weight, "fields": fields.duplicate(true)})


func chronicle_top(limit := 6) -> Array:
	var rows: Array = chronicle.duplicate(true)
	rows.sort_custom(func(a, b):
		if int(a.weight) == int(b.weight):
			return int(a.week) > int(b.week)
		return int(a.weight) > int(b.weight)
	)
	if rows.size() > limit:
		rows.resize(limit)
	for row in rows:
		row["text"] = chronicle_line(row)
	return rows


func chronicle_line(moment: Dictionary) -> String:
	var kind := str(moment.get("kind", ""))
	var fields: Dictionary = moment.get("fields", {})
	fields["week"] = int(moment.get("week", week))
	var combat_key := ""
	match kind:
		"listening_blown":
			return Copy.fill("listening.blown", {"station": str(fields.get("station", ""))})
		"station_taken_force":
			combat_key = "combat.chronicle.station_taken_force"
		"unbidden":
			combat_key = "combat.chronicle.unbidden"
		"raid_win":
			combat_key = "combat.chronicle.raid_win"
		"raid_loss":
			combat_key = "combat.chronicle.raid_loss"
	if combat_key != "":
		var vars := {}
		for key in fields:
			vars[str(key)] = str(fields[key])
		vars["week"] = str(int(moment.get("week", week)))
		return Copy.fill(combat_key, vars)
	if kind == "clear":
		return Copy.t("clear.chronicle")
	for row in catalog.epilogues.get("chronicle", []):
		if str(row.get("kind", "")) != kind:
			continue
		var vars := {}
		for key in fields:
			vars[str(key)] = str(fields[key])
		if kind == "season":
			vars["season"] = Copy.season(str(fields.get("season", "")))
		return fill_text(row, vars)
	return "Week %d: %s" % [int(moment.get("week", 0)), kind]


func _creed_id() -> String:
	if creed in ["watch", "chapel", "market"]:
		return creed
	return "none"


func epilogue_payload() -> Dictionary:
	var ending := str(over)
	if ending not in ["time", "revolt", "hope", "collapse", "capital"]:
		ending = "time"
	var fates: Array = []
	for line in fate_lines():
		fates.append({"name": "", "line": str(line)})
	return {
		"ending": ending,
		"creed": _creed_id(),
		"creed_label": _creed_label(),
		"verdict": verdict_line(),
		"judgment": judgment_line(),
		"fates": fates,
		"score": score_now(),
		"score_parts": Copy.t("epilogue.score_parts"),
		"week": week,
	}


func _creed_label() -> String:
	match _creed_id():
		"watch":
			return Copy.t("Watch")
		"chapel":
			return Copy.t("Chapel")
		"market":
			return Copy.t("Market")
		_:
			return Copy.t("epilogue.no_creed")


func verdict_line() -> String:
	var ending := str(over)
	if ending not in ["time", "revolt", "hope", "collapse", "capital"]:
		ending = "time"
	var table: Dictionary = catalog.epilogues.get("verdicts", {})
	var by_end: Dictionary = table.get(ending, {})
	var pack = by_end.get(_creed_id(), {})
	if pack is Dictionary and not pack.is_empty():
		return text_pack(pack)
	return ""


func judgment_line() -> String:
	var picked := _judgment_id()
	if picked == "force_moment":
		return "%s %s" % [Copy.t("combat.epilogue.force_moment"), Copy.t("combat.epilogue.force_judgment")]
	for row in catalog.epilogues.get("judgments", []):
		if str(row.get("id", "")) == picked:
			return text_pack(row)
	return ""


func _judgment_id() -> String:
	var top := chronicle_top(1)
	if top.is_empty():
		return "quiet_survive" if _creed_id() == "none" else "sent_down"
	var moment: Dictionary = top[0]
	var kind := str(moment.get("kind", ""))
	var fields: Dictionary = moment.get("fields", {})
	var cause := str(fields.get("cause", ""))
	match kind:
		"named_death", "known_lost":
			if _burial_of(str(fields.get("who", ""))) == "ledger" or cause == "ledger":
				return "ledger_dead"
			if cause in ["cough", "the cough"]:
				return "cough_list"
			if cause in ["sickness", "sealed", "Sickness"]:
				return "sealed_sick"
			if "fight" in cause.to_lower() or "battle" in cause.to_lower() or "пал" in cause.to_lower():
				return "held_stations"
			return "sent_down"
		"creed_line", "creed_chosen":
			match _creed_id():
				"watch":
					return "timetable"
				"chapel":
					return "covenant"
				"market":
					return "price"
				_:
					return "quiet_survive"
		"station_taken_force":
			return "force_moment"
		"station_taken", "station_lost", "battle":
			return "held_stations"
		"dilemma":
			return "turned_away"
		"season":
			if str(fields.get("season", "")) == "cough":
				return "cough_list"
			return "sealed_sick"
		"floor":
			return "floor_papers"
		_:
			if over == "time" and _creed_id() == "none":
				return "quiet_survive"
			return "sent_down"


func fate_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var seen := {}
	for seat in council:
		var id := str(seat.id)
		seen[id] = true
		lines.append(_fate_line(id, str(seat.role), true))
	var pool: Array = []
	for person in residents:
		if seen.has(str(person.id)):
			continue
		pool.append({"id": str(person.id), "memory": int(person.get("memory", 0)), "live": true})
	for row in departed:
		if seen.has(str(row.get("id", ""))):
			continue
		pool.append({"id": str(row.get("id", "")), "memory": int(row.get("memory", 0)), "live": false})
	pool.sort_custom(func(a, b): return int(a.memory) > int(b.memory))
	var n := 0
	for row in pool:
		if n >= 5:
			break
		lines.append(_fate_line(str(row.id), "", false))
		n += 1
	return lines


func _fate_line(id: String, seat: String, on_council: bool) -> String:
	var info := _person_record(id)
	var template := _fate_template(info, seat, on_council)
	var room := str(info.get("room", ""))
	var vars := {
		"name": str(info.get("name", id)),
		"week": str(int(info.get("week", week))),
		"room": Copy.t(room) if room != "" else Copy.t("the yard"),
		"place": str(info.get("place", _home_name())),
		"seat": Copy.t(seat.capitalize()) if seat != "" else "",
		"cause": str(info.get("cause", "")),
	}
	if Copy.ru() and str(info.get("name_ru", "")) != "":
		vars["name"] = str(info.name_ru)
	return fill_text(template, vars)


func _fate_template(info: Dictionary, seat: String, on_council: bool) -> Dictionary:
	var how := str(info.get("how", "alive"))
	var fid := "quiet_end"
	if how == "died":
		var burial := str(info.get("burial", ""))
		if burial == "ledger":
			fid = "ledger"
		elif burial == "bury":
			fid = "buried"
		else:
			fid = _fate_death_id(str(info.get("cause_id", "")))
	elif how == "left":
		fid = "kept_room_left" if str(info.get("room", "")) != "" else "walked_place"
	elif on_council:
		fid = "council_held"
	elif int(info.get("grew_week", 0)) > 0:
		fid = "child_grew"
	elif bool(info.get("seasoned", false)):
		fid = "seasoned"
	elif int(info.get("night_runs", 0)) > 0:
		fid = "night_runner"
	elif int(info.get("checks_passed", 0)) >= 2:
		fid = "check_hero"
	elif str(info.get("room", "")) != "":
		fid = "kept_room"
	elif over == "time" or week >= max_weeks:
		fid = "survived_40"
	return _fate_pack(fid)


func _fate_death_id(cause_id: String) -> String:
	match cause_id:
		"sickness":
			return "died_sick"
		"cough":
			return "died_cough"
		"food_shortage":
			return "died_food"
		"air_shortage":
			return "died_air"
		"battle":
			return "died_battle"
		"sealed":
			return "died_sealed"
		"accident":
			return "died_accident"
		"cold", "flood":
			return "died_sick"
		_:
			return "died_sick"


func _fate_pack(id: String) -> Dictionary:
	for row in catalog.epilogues.get("fates", []):
		if str(row.get("id", "")) == id:
			return row
	return {"en": "{name} was still in the yard.", "ru": "{name} всё ещё во дворе."}


func score_now() -> int:
	var named := int(stats.get("named_dead", 0))
	var total := week * 10 + residents.size() * 2 + owned_count() * 15 + hope - named * 5
	if _mandate_fulfilled():
		total += 100
	return total


func _mandate_fulfilled() -> bool:
	return stats.has("mandate_fulfilled") and bool(stats.get("mandate_fulfilled", false))


func best_score() -> int:
	return int(stats.get("best_score", 0))


func _seal_score() -> void:
	if over == "" or bool(stats.get("scored", false)):
		return
	stats.scored = true
	stats.score = score_now()
	stats.best_score = _write_best(int(stats.score))


func _write_best(score: int) -> int:
	var cfg := ConfigFile.new()
	cfg.load("user://records.cfg")
	var best := int(cfg.get_value("scores", "best", 0))
	if score > best:
		best = score
		cfg.set_value("scores", "best", best)
		cfg.save("user://records.cfg")
	return best


func _is_child(person: Dictionary) -> bool:
	return bool(person.get("child", false)) and int(person.get("child_left", 0)) > 0


func can_work(person: Dictionary) -> bool:
	return not _is_child(person) and int(person.get("sick", 0)) <= 0 and int(person.get("absent", 0)) <= 0


func _tick_children() -> void:
	for person in residents:
		if not bool(person.get("child", false)):
			continue
		if int(person.get("born_week", -1)) == week:
			continue
		person.child_left = int(person.get("child_left", 0)) - 1
		if int(person.child_left) <= 0:
			_grow_up(person)


func _birth() -> String:
	var firsts: Array = catalog.names.first
	var lasts: Array = catalog.names.last
	if firsts.is_empty() or lasts.is_empty():
		return ""
	next_person += 1
	var id := "n%d" % next_person
	var person := {
		"id": id,
		"name": "%s %s" % [str(firsts[rng.randi() % firsts.size()]), str(lasts[rng.randi() % lasts.size()])],
		"skills": {"labor": 0, "tech": 0, "care": 0, "talk": 0, "fight": 0},
		"traits": [],
		"sick": 0,
		"absent": 0,
		"child": true,
		"child_left": 8,
		"born_week": week,
		"parent_skill": _parent_skill(),
		"memory": 0,
		"story_events": [],
	}
	_fill_identity(person)
	_stamp_checks(person)
	residents.append(person)
	people[id] = person
	_dress([person])
	_note_moment("birth", {"name": str(person.name)}, 2)
	return str(person.name)


func _grow_up(person: Dictionary) -> void:
	person.child = false
	person.child_left = 0
	person.grew_week = week
	var skills: Dictionary = person.get("skills", {})
	for key in ["labor", "tech", "care", "talk", "fight"]:
		skills[key] = rng.randi_range(1, 3)
	var bonus := str(person.get("parent_skill", ""))
	if bonus != "":
		skills[bonus] = mini(6, int(skills.get(bonus, 1)) + 1)
	person.skills = skills
	person.checks = {}
	_stamp_checks(person)


func _parent_skill() -> String:
	var options: Array = []
	for room in rooms:
		var skill := str(catalog.rooms[room.type].get("skill", ""))
		if skill == "":
			continue
		for id in room.staff:
			if people.has(str(id)) and not _is_child(people[str(id)]):
				options.append(skill)
	if options.is_empty():
		return ""
	return str(options[rng.randi() % options.size()])


func _mark_served(person: Dictionary, room: Dictionary) -> void:
	if _is_child(person):
		return
	person.served = int(person.get("served", 0)) + 1
	var uid := str(room.uid)
	if str(person.get("staff_room", "")) != uid:
		person.staff_room = uid
		person.staff_weeks = 0
	person.staff_weeks = int(person.get("staff_weeks", 0)) + 1
	var defin: Dictionary = catalog.rooms[room.type]
	person.last_room = str(defin.get("name", room.type))
	if int(person.staff_weeks) < 6:
		return
	person.staff_weeks = 0
	var skill := str(defin.get("skill", ""))
	if skill == "":
		return
	var cur := int(person.get("skills", {}).get(skill, 0))
	if cur >= 6:
		return
	person.skills[skill] = cur + 1
	person.seasoned = true
	person.checks = {}
	_stamp_checks(person)
	var toast := fill_text(_fate_pack("seasoned"), {"name": str(person.name), "room": Copy.t(str(defin.get("name", "")))})
	notices.append(toast)
	_log(toast, true)


func _life_note(person: Dictionary, pool: String, extra: Dictionary) -> void:
	var rows: Array = catalog.names.get("journals", {}).get(pool, [])
	if rows.is_empty():
		return
	var pick: Dictionary = rows[rng.randi() % rows.size()]
	if not person.has("story_events") or typeof(person.story_events) != TYPE_ARRAY:
		person.story_events = []
	var room := str(extra.get("room", person.get("last_room", "")))
	person.story_events.append({
		"pool": pool,
		"id": str(pick.get("id", "")),
		"week": week,
		"name": str(person.get("name", "")),
		"room": room,
	})
	person.memory = mini(100, int(person.get("memory", 0)) + 5)


func journal_line(ev: Dictionary) -> String:
	if str(ev.get("pool", "")) == "fought":
		var place := str(ev.get("room", ""))
		return Copy.fill("combat.journal.fought", {"name": str(ev.get("name", "")), "place": place, "room": place})
	var rows: Array = catalog.names.get("journals", {}).get(str(ev.get("pool", "")), [])
	var pick := {}
	for row in rows:
		if str(row.get("id", "")) == str(ev.get("id", "")):
			pick = row
			break
	if pick.is_empty() and not rows.is_empty():
		pick = rows[0]
	return fill_text(pick, {"name": str(ev.get("name", "")), "room": Copy.t(str(ev.get("room", "")))})


func _life_journal_shortage() -> void:
	for room in rooms:
		var defin: Dictionary = catalog.rooms[str(room.type)]
		for id in room.staff:
			if not people.has(str(id)):
				continue
			var person: Dictionary = people[str(id)]
			if not can_work(person):
				continue
			_life_note(person, "staffed_shortage", {"room": str(defin.get("name", ""))})


func _note_night_run(person_id: String) -> void:
	if not people.has(person_id):
		return
	var person: Dictionary = people[person_id]
	person.night_runs = int(person.get("night_runs", 0)) + 1
	_life_note(person, "night_run", {})


func _note_new_sickness() -> void:
	for person in residents:
		if int(person.get("sick", 0)) > 0 and not bool(person.get("sick_noted", false)):
			person.sick_noted = true
			var room := str(person.get("last_room", ""))
			_life_note(person, "sick", {"room": room})
		elif int(person.get("sick", 0)) <= 0:
			person.sick_noted = false


func _fill_identity(person: Dictionary) -> void:
	if str(person.get("before_silence", "")) == "" or (person.get("before_silence") is Dictionary and str(person.before_silence.get("en", "")) == ""):
		person.before_silence = _identity_pack(person, "pasts")
	if str(person.get("keepsake", "")) == "" or (person.get("keepsake") is Dictionary and str(person.keepsake.get("en", "")) == ""):
		person.keepsake = _identity_pack(person, "keepsakes")
	if not person.has("memory"):
		person.memory = 0
	if not person.has("story_events"):
		person.story_events = []


func _identity_pack(person: Dictionary, kind: String) -> Dictionary:
	var block: Dictionary = catalog.names.get(kind, {})
	var authored: Dictionary = block.get("authored", {})
	var id := str(person.get("id", ""))
	if authored.has(id):
		return authored[id]
	var pool: Array = block.get("pool", [])
	if pool.is_empty():
		return {}
	var index := absi(("%s:%s" % [id, kind]).hash()) % pool.size()
	return pool[index]


func _pick_victim(cause: String) -> String:
	var non: Array = []
	var last: Array = []
	for person in residents:
		if _is_council(str(person.id)):
			last.append(person)
		else:
			non.append(person)
	var pool: Array = non if not non.is_empty() else last
	if cause == "battle":
		var adults: Array = []
		for person in pool:
			if _is_child(person) or int(person.get("absent", 0)) > 0:
				continue
			adults.append(person)
		if adults.is_empty():
			return ""
		adults.sort_custom(func(a, b): return int(a.get("skills", {}).get("fight", 0)) < int(b.get("skills", {}).get("fight", 0)))
		return str(adults[0].id)
	elif cause in ["sickness", "sick", "hope", "cough"]:
		pool.sort_custom(func(a, b):
			if int(a.get("sick", 0)) == int(b.get("sick", 0)):
				return int(a.get("skills", {}).get("care", 0)) < int(b.get("skills", {}).get("care", 0))
			return int(a.get("sick", 0)) > int(b.get("sick", 0))
		)
	elif cause in ["food_shortage", "air_shortage", "shortage", "cold", "flood"]:
		pool.sort_custom(func(a, b): return int(a.get("skills", {}).get("care", 0)) < int(b.get("skills", {}).get("care", 0)))
	else:
		pool.sort_custom(func(a, b): return _skill_total(a) < _skill_total(b))
	if pool.is_empty():
		return ""
	return str(pool[0].id)


func _death_line_id(cause: String, person: Dictionary) -> String:
	match cause:
		"battle":
			return "battle"
		"food_shortage":
			return "food_shortage"
		"air_shortage":
			return "air_shortage"
		"hope":
			if int(person.get("sick", 0)) > 0:
				return "cough" if _season_is("cough") else "sickness"
			if _season_is("cold"):
				return "cold"
			if _season_is("flood"):
				return "flood"
			return "dilemma"
		"dilemma":
			return "dilemma"
		"sickness", "sick":
			return "cough" if _season_is("cough") else "sickness"
		"left":
			return "left"
		_:
			return cause if cause != "" else "accident"


func _death_cause_label(line_id: String) -> String:
	match line_id:
		"sickness":
			return Copy.t("hardship.sick")
		"food_shortage":
			return Copy.t("hardship.food_short")
		"air_shortage":
			return Copy.t("hardship.air_short")
		"cough":
			return Copy.t("hardship.season_cough")
		"cold":
			return Copy.t("hardship.season_cold")
		"flood":
			return Copy.t("hardship.season_flood")
		"battle":
			return Copy.t("the line")
		"dilemma":
			return Copy.t("a choice")
		"accident":
			return Copy.t("the tools")
		"sealed":
			return Copy.t("the seal")
		_:
			return line_id.replace("_", " ")


func _death_text(line_id: String, person_name: String, name_ru: String) -> Dictionary:
	var pack := {"en": person_name, "ru": person_name}
	for row in catalog.names.get("deaths", []):
		if str(row.get("id", "")) == line_id:
			pack = row
			break
	var en := fill_text({"en": str(pack.get("en", "")), "ru": str(pack.get("en", ""))}, {"name": person_name})
	var ru_name := name_ru if name_ru != "" else person_name
	var ru := fill_text({"en": str(pack.get("ru", "")), "ru": str(pack.get("ru", ""))}, {"name": ru_name})
	return {"en": en, "ru": ru}


func _offer_burial() -> void:
	if burials.is_empty():
		return
	for ev in pending:
		if str(ev.get("burial_id", "")) != "":
			return
	var row: Dictionary = burials[0]
	var body := _death_text(str(row.get("cause", "sickness")), str(row.get("name", "")), str(row.get("name_ru", "")))
	if str(row.get("cause", "")) == "battle":
		body = _battle_death_text(str(row.get("name", "")), str(row.get("name_ru", "")), str(row.get("place", "")))
	var choices: Array = [
		{"id": "bury", "label": {"en": "Bury them", "ru": "Похоронить"}, "cost": {"materials": 1}, "hope": 1},
		{"id": "tunnel", "label": {"en": "Leave them in the tunnel", "ru": "Оставить в тоннеле"}},
	]
	if _law_on("ledger"):
		choices.insert(1, {"id": "ledger", "label": {"en": "Give them to the Ledger", "ru": "Отдать Гроссбуху"}, "materials": 2})
	pending.push_front({
		"id": "burial_%s" % str(row.get("id", "")),
		"burial_id": str(row.get("id", "")),
		"title": {"en": str(row.get("name", "")), "ru": str(row.get("name_ru", row.get("name", "")))},
		"text": body,
		"choices": choices,
	})


func _resolve_burial(person_id: String, choice_id: String) -> void:
	var keep: Array = []
	for row in burials:
		if str(row.get("id", "")) == person_id:
			continue
		keep.append(row)
	burials = keep
	for row in departed:
		if str(row.get("id", "")) != person_id:
			continue
		if choice_id == "bury":
			row.burial = "bury"
		elif choice_id == "ledger":
			row.burial = "ledger"
			# TODO(P6): Devout mood −2 when mood exists. Ledger has no mood to write yet.
			_log("LEDGER %s" % str(row.get("name", person_id)), true)


func _remember_departure(person: Dictionary, how: String, cause_id: String, place: String) -> void:
	departed.append({
		"id": str(person.get("id", "")),
		"name": str(person.get("name", "")),
		"name_ru": str(person.get("name_ru", "")),
		"memory": int(person.get("memory", 0)),
		"week": week,
		"how": how,
		"cause_id": cause_id,
		"cause": _death_cause_label(cause_id) if how == "died" else "",
		"room": str(person.get("last_room", "")),
		"place": place if place != "" else _home_name(),
		"burial": "",
		"seasoned": bool(person.get("seasoned", false)),
		"grew_week": int(person.get("grew_week", 0)),
		"night_runs": int(person.get("night_runs", 0)),
		"checks_passed": int(person.get("checks_passed", 0)),
		"role": str(person.get("council", "")),
	})


func _person_record(id: String) -> Dictionary:
	if people.has(id):
		var person: Dictionary = people[id]
		return {
			"id": id,
			"name": str(person.get("name", id)),
			"name_ru": str(person.get("name_ru", "")),
			"memory": int(person.get("memory", 0)),
			"week": int(person.get("grew_week", week)),
			"how": "alive",
			"cause_id": "",
			"cause": "",
			"room": str(person.get("last_room", "")),
			"place": _home_name(),
			"burial": "",
			"seasoned": bool(person.get("seasoned", false)),
			"grew_week": int(person.get("grew_week", 0)),
			"night_runs": int(person.get("night_runs", 0)),
			"checks_passed": int(person.get("checks_passed", 0)),
		}
	for row in departed:
		if str(row.get("id", "")) == id:
			return row
	return {"id": id, "name": id, "how": "alive", "week": week}


func _burial_of(id: String) -> String:
	for row in departed:
		if str(row.get("id", "")) == id:
			return str(row.get("burial", ""))
	return ""


func _home_name() -> String:
	if stations.has(capital_id):
		return str(stations[capital_id].get("community", stations[capital_id].get("name", "the yard")))
	return "the yard"


func _squad_names(limit: int) -> Array:
	var pool: Array = []
	for person in residents:
		if not can_work(person):
			continue
		pool.append(person)
	pool.sort_custom(func(a, b): return int(a.get("skills", {}).get("fight", 0)) > int(b.get("skills", {}).get("fight", 0)))
	var out: Array = []
	for person in pool:
		out.append(str(person.id))
		if out.size() >= limit:
			break
	return out


# --- tunnel combat (P20) ---

func breach_stock() -> int:
	return int(artifacts.get("breach", 0))


func breach_craft_reason() -> String:
	var gate := _breach_gate()
	if gate != "":
		return gate
	return order_block("breach")


## Locked soft-dawn order. Party Away is sticky yard chrome and has no slot here.
## P43 homecoming queues the arrival chip; this badge does not.
const DAWN_SOFT_STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]


func dawn_soft_stack() -> Array:
	return DAWN_SOFT_STACK.duplicate()


## Always false. P44 must not become a fifth soft dawn chip. P43 owns the arrival chip.
func party_away_dawn_chip() -> bool:
	return false


func _party_position_away(sq: Dictionary) -> bool:
	if bool(sq.get("away", false)):
		return true
	return str(sq.get("station", "")) != str(capital_id)


func _away_station_name(sid: String) -> String:
	if not stations.has(sid):
		return ""
	var community := station_text(sid, "community")
	if community != "":
		return community
	return str(stations[sid].get("name", ""))


func _remember_away_station(sq: Dictionary) -> void:
	var sid := str(sq.get("station", ""))
	if sid == "" or sid == str(capital_id) or not stations.has(sid):
		return
	if not _home_station_known(sid) or _away_station_name(sid) == "":
		return
	flags["away_last_station"] = sid


## Current non-home station when intel allows; otherwise the last known non-home
## (expedition / in transit, station field still home). An unknown current stop stays unnamed.
func _party_away_place(sq: Dictionary) -> Dictionary:
	var sid := str(sq.get("station", ""))
	if sid != "" and sid != str(capital_id) and stations.has(sid):
		var name := _away_station_name(sid)
		if _home_station_known(sid) and name != "":
			return {"id": sid, "name": name, "known": true}
		return {"id": sid, "name": "", "known": false}
	var last := str(flags.get("away_last_station", ""))
	if last != "" and last != str(capital_id) and stations.has(last):
		var last_name := _away_station_name(last)
		if _home_station_known(last) and last_name != "":
			return {"id": last, "name": last_name, "known": true}
	return {"id": "", "name": "", "known": false}


## Sticky yard read. Sets `flags.party_left_home` the first time a living party is out,
## so a later save remembers they have left. Hides the same tick the party is home.
## Does not touch dawn queues, homecoming flags, stock, or health.
func party_away_view() -> Dictionary:
	var heard := bool(flags.get("heard_away", false))
	var view := {
		"show": false,
		"away": false,
		"wiped": true,
		"never_left": not bool(flags.get("party_left_home", false)),
		"living": 0,
		"known": false,
		"station_id": "",
		"station": "",
		"line_key": "",
		"first": false,
		"heard": heard,
		"dawn": false,
	}
	if not squads.has(player):
		return view
	var sq: Dictionary = squads[player]
	var living := _party_living_count(sq)
	var away := _party_position_away(sq)
	view.living = living
	view.away = away
	view.wiped = living <= 0
	if away and living > 0:
		flags["party_left_home"] = true
		_remember_away_station(sq)
	view.never_left = not bool(flags.get("party_left_home", false))
	var place := _party_away_place(sq)
	view.station_id = str(place.id)
	view.station = str(place.name)
	view.known = bool(place.known)
	var show: bool = away and living > 0 and not bool(view.never_left)
	view.show = show
	if show:
		view.line_key = "away.out" if bool(place.known) else "away.out_unknown"
	view.heard = bool(flags.get("heard_away", false))
	view.first = show and not bool(view.heard)
	view.dawn = false
	return view


func party_away_line(reduce_motion := false) -> String:
	var view := party_away_view()
	if not bool(view.show):
		return ""
	if reduce_motion:
		return Copy.t("away.reduce")
	if str(view.line_key) == "away.out":
		return Copy.fill("away.out", {"station": str(view.station)})
	return Copy.t("away.out_unknown")


## First platform float has been seen this run. Save/load keeps `flags.heard_away`.
func party_mark_heard_away() -> void:
	flags["heard_away"] = true


func party_roster() -> Dictionary:
	var sq: Dictionary = squads.get(player, {})
	var members: Array = []
	for id in sq.get("roster", []):
		if not people.has(str(id)):
			continue
		var person: Dictionary = people[str(id)]
		members.append({
			"id": str(id),
			"name": str(person.get("name", id)),
			"fight": int(person.get("skills", {}).get("fight", 0)),
			"known": int(person.get("memory", 0)) >= 40,
			"away": int(person.get("absent", 0)) > 0 or int(person.get("sick", 0)) > 0,
		})
	var max_size := int(sq.get("max_size", members.size()))
	return {
		"max_size": max_size,
		"members": members,
		"empty_slots": maxi(0, max_size - members.size()),
		"effective_size": _effective_size(sq) if squads.has(player) else 0.0,
	}


func party_toggle(person_id: String) -> String:
	if not squads.has(player) or not people.has(person_id):
		return Copy.t("order.party_empty")
	if _party_locked():
		return Copy.t("party.away_block")
	var sq: Dictionary = squads[player]
	if not sq.has("roster") or typeof(sq.roster) != TYPE_ARRAY:
		sq.roster = []
	var roster: Array = sq.roster
	if roster.has(person_id):
		roster.erase(person_id)
		_sync_party(sq)
		return ""
	var person: Dictionary = people[person_id]
	if _is_child(person):
		return Copy.t("order.party_empty")
	if _is_council(person_id):
		return Copy.t("party.marshal_note")
	if roster.size() >= int(sq.max_size):
		return Copy.t("party.count") % [roster.size(), int(sq.max_size)]
	roster.append(person_id)
	_unassign(person_id)
	_sync_party(sq)
	return ""


func party_add_best() -> String:
	if not squads.has(player):
		return Copy.t("order.party_empty")
	var sq: Dictionary = squads[player]
	var roster: Array = sq.get("roster", [])
	var best := ""
	var best_f := -1
	for person in residents:
		var id := str(person.id)
		if roster.has(id) or id == "jonah" or _is_council(id) or _is_child(person):
			continue
		if int(person.get("absent", 0)) > 0:
			continue
		var fight := int(person.get("skills", {}).get("fight", 0))
		if fight > best_f:
			best_f = fight
			best = id
	if best == "":
		return Copy.t("order.party_empty")
	return party_toggle(best)


func battle_preview(kind: String, sid: String) -> Dictionary:
	var info := {
		"ok": false,
		"win_pct": 0,
		"mods": [],
		"named_at_risk": 0,
		"known_at_risk": 0,
		"moral": {},
		"why": "",
		"place": "",
	}
	if not stations.has(sid) or not squads.has(player):
		info.why = Copy.t("order.no_tunnel")
		return info
	info.place = _station_place(sid)
	var why := ""
	if kind == "raid":
		why = _raid_gate(sid)
	elif kind == "assault":
		why = _assault_gate(sid)
	else:
		why = _patrol_gate(sid)
	info.why = why
	if why != "" and kind != "patrol":
		return info
	if kind == "patrol":
		info.ok = why == ""
		return info
	var spend := kind == "assault" and _breach_will_spend(sid)
	var factors := _battle_factors(squads[player], sid, spend)
	var pct := _win_pct(float(factors.attack), float(factors.defense))
	var risk := _named_risk(pct)
	var owner := str(stations[sid].owner)
	info.ok = true
	info.win_pct = pct
	info.mods = factors.mods
	info.named_at_risk = int(risk.named)
	info.known_at_risk = int(risk.known)
	info.moral = {
		"hope": absi(int(bal.get("assault_hope", -3))),
		"discontent": int(bal.get("assault_discontent", 8)),
		"unbidden_hope": 0 if bool(at_war.get(owner, false)) else absi(int(bal.get("unbidden_hope", -2))),
		"known_extra_hope": 2,
		"raid_discontent": int(bal.get("raid_discontent", 2)),
		"raid_opinion": absi(int(bal.get("raid_opinion", -15))),
	}
	return info


func _breach_will_spend(sid: String) -> bool:
	if int(artifacts.get("breach", 0)) < 1 or not stations.has(sid):
		return false
	return int(stations[sid].get("low_weeks", 0)) < 2


func _station_place(sid: String) -> String:
	if not stations.has(sid):
		return sid
	var st: Dictionary = stations[sid]
	return Copy.t(str(st.get("community", st.get("name", sid))))


func _roster_ids() -> Array:
	if not squads.has(player):
		return []
	var sq: Dictionary = squads[player]
	if not sq.has("roster") or typeof(sq.roster) != TYPE_ARRAY:
		return []
	return sq.roster


func _drop_roster(id: String) -> void:
	if not squads.has(player):
		return
	var sq: Dictionary = squads[player]
	if not sq.has("roster") or typeof(sq.roster) != TYPE_ARRAY:
		return
	var roster: Array = sq.roster
	if roster.has(id):
		roster.erase(id)


func _fill_roster(sq: Dictionary, want: int) -> void:
	if not sq.has("roster") or typeof(sq.roster) != TYPE_ARRAY:
		sq.roster = []
	var roster: Array = sq.roster
	var have := {}
	for id in roster:
		have[str(id)] = true
	var pool: Array = []
	for person in residents:
		var id := str(person.id)
		if have.has(id) or id == "jonah" or _is_council(id) or _is_child(person):
			continue
		if int(person.get("absent", 0)) > 0:
			continue
		pool.append(person)
	pool.sort_custom(func(a, b): return int(a.get("skills", {}).get("fight", 0)) > int(b.get("skills", {}).get("fight", 0)))
	for person in pool:
		if roster.size() >= want:
			break
		var id := str(person.id)
		roster.append(id)
		_unassign(id)
	_sync_party(sq)


func _sync_party(sq: Dictionary) -> void:
	if not sq.has("roster") or typeof(sq.roster) != TYPE_ARRAY:
		return
	var keep: Array = []
	for id in sq.roster:
		if people.has(str(id)):
			keep.append(str(id))
	sq.roster = keep
	_refresh_fight(sq)


func _refresh_fight(sq: Dictionary) -> void:
	var sum := 0
	var n := 0
	for id in sq.get("roster", []):
		if not people.has(str(id)):
			continue
		sum += int(people[str(id)].get("skills", {}).get("fight", 0))
		n += 1
	if n <= 0:
		sq.fight = 1
	else:
		sq.fight = maxi(1, int(ceil(float(sum) / float(n))))


func _effective_size(sq: Dictionary) -> float:
	if str(sq.get("faction", "")) != player or not sq.has("roster"):
		return float(sq.get("size", 0))
	var present := 0
	var listed := 0
	for id in sq.roster:
		if not people.has(str(id)):
			continue
		listed += 1
		var person: Dictionary = people[str(id)]
		if _is_child(person) or int(person.get("absent", 0)) > 0 or int(person.get("sick", 0)) > 0:
			continue
		present += 1
	var empty := maxi(0, int(sq.get("max_size", listed)) - listed)
	var weight := float(bal.get("party_empty_weight", 0.5))
	var eff := float(present) + weight * float(empty) - float(sq.get("attrition", 0))
	return clampf(eff, 0.0, float(maxi(1, int(sq.get("max_size", present)))))


func _party_locked() -> bool:
	if not squads.has(player):
		return true
	var sq: Dictionary = squads[player]
	return bool(sq.get("away", false)) or bool(sq.get("returning", false)) or int(sq.get("secure", 0)) > 0


func _marshal_alive() -> bool:
	for seat in council:
		if str(seat.role) == "marshal" and people.has(str(seat.id)):
			return true
	return false


func _party_send_block() -> String:
	if bool(flags.get("truce", false)):
		return Copy.t("order.truce")
	if not _marshal_alive():
		return Copy.t("order.no_marshal")
	if _party_locked():
		return Copy.t("order.party_away")
	if not squads.has(player) or _effective_size(squads[player]) < 1.0:
		return Copy.t("order.party_empty")
	return ""


func _patrol_block(dest: String) -> String:
	return _patrol_gate(dest)


func _raid_block(dest: String) -> String:
	return _raid_gate(dest)


func _assault_block(dest: String) -> String:
	return _assault_gate(dest)


func _breach_block() -> String:
	return _breach_gate()


func _patrol_gate(dest: String) -> String:
	var common := _party_send_block()
	if common != "":
		return common
	if not stations.has(dest):
		return Copy.t("order.no_tunnel")
	var sq: Dictionary = squads[player]
	var path := _path(str(sq.station), dest)
	if path.size() < 2:
		return Copy.t("order.no_tunnel")
	var nxt := str(path[1])
	var owner := str(stations[nxt].owner)
	if owner != player and owner != "neutral" and owner != "ruin":
		return Copy.t("combat.order.patrol_tip")
	return ""


func _raid_gate(dest: String) -> String:
	var common := _party_send_block()
	if common != "":
		return common
	if not stations.has(dest):
		return Copy.t("order.no_tunnel")
	var st: Dictionary = stations[dest]
	var owner := str(st.owner)
	if owner == "bunker" or str(st.get("bunker", "")) != "":
		return Copy.t("That station will not hear an envoy.")
	if owner == player or owner == "neutral" or owner == "ruin":
		return Copy.t("order.not_hostile")
	var sq: Dictionary = squads[player]
	if _path(str(sq.station), dest).size() != 2:
		return Copy.t("order.no_tunnel")
	if not bool(st.get("known", false)):
		return Copy.t("order.raid_intel")
	if int(st.get("intel", 0)) < 2:
		return Copy.t("listening.need_intel")
	if _effective_size(sq) < 4.0:
		return Copy.t("order.raid_size")
	if int(stock.food) < int(bal.get("raid_pack_food", 2)):
		return Copy.t("Needs %s, the yard has %s.") % [Words.count(int(bal.get("raid_pack_food", 2)), "food"), Words.count(int(stock.food), "food")]
	return ""


func _assault_gate(dest: String) -> String:
	var common := _party_send_block()
	if common != "":
		return common
	if not stations.has(dest):
		return Copy.t("order.no_tunnel")
	var st: Dictionary = stations[dest]
	var owner := str(st.owner)
	if owner == "bunker" or str(st.get("bunker", "")) != "":
		return Copy.t("That station will not hear an envoy.")
	if owner == player or owner == "ruin":
		return Copy.t("order.not_hostile")
	var sq: Dictionary = squads[player]
	if _path(str(sq.station), dest).size() != 2:
		return Copy.t("order.no_tunnel")
	if int(st.get("low_weeks", 0)) < 2 and int(artifacts.get("breach", 0)) < 1:
		return Copy.t("order.assault_gate")
	return ""


func _breach_gate() -> String:
	if int(artifacts.get("breach", 0)) >= 1:
		return Copy.t("breach.disabled_held")
	if not _room_ready("workshop"):
		return Copy.t("breach.disabled_shop")
	if int(stock.materials) < int(bal.get("breach_materials", 6)):
		return Copy.t("breach.disabled_mats")
	return ""


func _order_patrol(dest: String) -> bool:
	if _patrol_gate(dest) != "":
		return false
	var sq: Dictionary = squads[player]
	var path := _path(str(sq.station), dest)
	var stepped := _step_squad(sq, str(path[1]), true)
	_note_party_home()
	return stepped


func _order_raid(dest: String, immediate: bool) -> bool:
	last_combat_report = {}
	if _raid_gate(dest) != "":
		return false
	var hope0 := hope
	var dis0 := discontent
	stock.food = int(stock.food) - int(bal.get("raid_pack_food", 2))
	var sq: Dictionary = squads[player]
	var fought := _resolve_battle(sq, dest, false)
	var win := bool(fought.get("win", false))
	var st: Dictionary = stations[dest]
	var place := _station_place(dest)
	if win:
		stock.food = int(stock.food) + int(bal.get("raid_loot_food", 8))
		stock.materials = int(stock.materials) + int(bal.get("raid_loot_materials", 6))
		_add_opinion(str(st.owner), int(bal.get("raid_opinion", -15)))
		for n in _neighbors(dest):
			var nid := str(n)
			if stations.has(nid) and str(stations[nid].owner) != player:
				stations[nid].loyalty = maxi(0, int(stations[nid].loyalty) - 5)
		_add_discontent(int(bal.get("raid_discontent", 2)), "raid")
		_note_moment("raid_win", {"place": place, "week": week}, 4)
		notices.append(Copy.t("combat.toast.raid_win"))
		_grant_first_raid_blueprint()
		_log(Copy.fill("combat.log.raid_win", {"week": str(week), "place": place}), true)
		sq.station = dest
		sq.returning = true
		sq.return_to = capital_id
		sq.return_week = week - 1 if immediate else week
		sq.secure = 1
		var owner := str(st.owner)
		if owner != "" and owner != player and owner != "neutral" and owner != "ruin":
			combat_lock[owner] = week + 4
	else:
		_add_hope(-1, "raid")
		_add_discontent(4, "raid")
		sq.secure = 1
		sq.returning = false
		_note_moment("raid_loss", {"place": place, "week": week}, 4)
		notices.append(Copy.t("combat.toast.raid_loss"))
		_log(Copy.fill("combat.log.raid_loss", {"week": str(week), "place": place}), true)
	var opinion := ""
	if win:
		opinion = Copy.t("combat.raid_cost") % [int(bal.get("raid_discontent", 2)), absi(int(bal.get("raid_opinion", -15)))]
	_stamp_combat("raid", dest, win, false, fought.get("player", {}), hope0, dis0, opinion)
	_note_party_home()
	return true


func _order_assault(dest: String, _immediate: bool) -> bool:
	last_combat_report = {}
	if _assault_gate(dest) != "":
		return false
	var hope0 := hope
	var dis0 := discontent
	var st: Dictionary = stations[dest]
	var owner := str(st.owner)
	var place := _station_place(dest)
	var spend := _breach_will_spend(dest)
	if spend:
		artifacts.breach = 0
		st["_breach"] = true
	var unbidden := not bool(at_war.get(owner, false))
	if unbidden:
		_add_hope(int(bal.get("unbidden_hope", -2)), "unbidden")
		_add_opinion(owner, -20)
		_note_moment("unbidden", {"place": place, "week": week}, 5)
		notices.append(Copy.fill("combat.toast.unbidden", {"place": place}))
		_log(Copy.fill("combat.log.unbidden", {"week": str(week), "place": place}), true)
	var fought := _resolve_battle(squads[player], dest, spend)
	var win := bool(fought.get("win", false))
	var captured := false
	var sq: Dictionary = squads[player]
	if win:
		captured = _capture(dest, player, true)
		if captured:
			sq.station = dest
			stations[dest].known = true
			_log(Copy.fill("combat.log.assault_win", {"week": str(week), "place": place}), true)
			_log(Copy.fill("combat.log.force_capture", {"week": str(week), "place": place}), true)
		sq.secure = 1
	else:
		_add_hope(-1, "assault")
		_add_discontent(4, "assault")
		sq.secure = 1
		notices.append(Copy.t("combat.toast.assault_loss"))
		_log(Copy.fill("combat.log.assault_loss", {"week": str(week), "place": place}), true)
	var opinion := ""
	if unbidden:
		opinion = Copy.t("combat.unbidden") % absi(int(bal.get("unbidden_hope", -2)))
	_stamp_combat("assault", dest, win, captured, fought.get("player", {}), hope0, dis0, opinion)
	_note_party_home()
	return true


func _order_breach() -> bool:
	if _breach_gate() != "":
		return false
	stock.materials = int(stock.materials) - int(bal.get("breach_materials", 6))
	artifacts.breach = 1
	var ready := Copy.t("breach.toast")
	notices.append(ready)
	_log(ready, true)
	return true


func _stamp_combat(kind: String, sid: String, win: bool, force: bool, hurt: Dictionary, hope0: int, dis0: int, opinion: String) -> void:
	var place := _station_place(sid)
	var title_key := "combat.after_loss"
	var outcome := "combat.lost"
	if win and kind == "raid":
		title_key = "combat.after_raid"
		outcome = "combat.raid_win"
	elif win and kind == "assault":
		title_key = "combat.after_assault"
		outcome = "combat.took_force" if force else "combat.lost"
	last_combat_report = {
		"title": Copy.t(title_key) % place,
		"text": Copy.t(outcome),
		"ok": true,
		"battle": true,
		"kind": kind,
		"win": win and (kind != "assault" or force),
		"force": force,
		"place": place,
		"dead": hurt.get("dead", []),
		"injured": hurt.get("injured", []),
		"deltas": {"hope": hope - hope0, "discontent": discontent - dis0},
		"loyalty": int(stations[sid].get("loyalty", 0)) if stations.has(sid) else 0,
		"opinion_line": opinion,
	}


func _battle_factors(sq: Dictionary, sid: String, breach: bool) -> Dictionary:
	var st: Dictionary = stations[sid]
	var atk_mod := 1.0
	var def_mod := 1.0
	var mods: Array = []
	if _edge_flooded(str(sq.get("station", "")), sid):
		atk_mod *= float(bal.get("tunnel_flood_atk", 0.85))
		mods.append({"id": "flood", "label": Copy.t("combat.mod_flood")})
	if int(st.get("unrest", 0)) >= 4:
		atk_mod *= float(bal.get("tunnel_dark_atk", 1.10))
		def_mod *= float(bal.get("tunnel_dark_def", 0.90))
		mods.append({"id": "dark", "label": Copy.t("combat.mod_dark")})
	var fort := float(st.get("fort", 1.0))
	if _home_guard(sq, sid):
		fort += float(bal.get("home_guard_fort", 0.10))
		mods.append({"id": "home_guard", "label": Copy.t("combat.mod_home")})
	if breach:
		atk_mod *= 1.15
		mods.append({"id": "breach", "label": Copy.t("combat.mod_breach")})
	var attack := _effective_size(sq) * float(sq.get("gear", 1.0)) * (1.0 + float(sq.get("fight", 1)) / 10.0) * atk_mod
	var garrison := float(st.get("garrison", 1))
	var defender := {}
	if str(st.get("owner", "")) == player and squads.has(player):
		var psq: Dictionary = squads[player]
		if str(psq.get("station", "")) == sid and not bool(psq.get("away", false)) and not bool(psq.get("returning", false)):
			garrison = _effective_size(psq)
			defender = psq
	var defense := garrison * fort * 1.3 * def_mod
	return {"attack": attack, "defense": defense, "mods": mods, "defender": defender}


func _home_guard(attacker: Dictionary, sid: String) -> bool:
	if str(attacker.get("faction", "")) == player:
		return false
	if not _room_ready("platform"):
		return false
	if not squads.has(player):
		return false
	var psq: Dictionary = squads[player]
	var left := bool(psq.get("away", false)) or str(psq.get("station", "")) != capital_id
	if not left:
		return false
	if str(psq.get("station", "")) == sid:
		return false
	return _neighbors(capital_id).has(sid)


func _edge_flooded(a: String, b: String) -> bool:
	var edge := _edge(a, b)
	if edge.is_empty():
		return false
	return str(edge.get("state", "")) == "flooded" or bool(edge.get("flooded", false))


func _win_pct(attack: float, defense: float) -> int:
	if attack <= 0.0:
		return 0
	return int(round(clampf((1.2 - defense / attack) / 0.4, 0.0, 1.0) * 100.0))


func _named_risk(pct: int) -> Dictionary:
	var win_mid := (float(bal.get("battle_loss_win_min", 0.10)) + float(bal.get("battle_loss_win_max", 0.25))) * 0.5
	var lose_mid := (float(bal.get("battle_loss_lose_min", 0.35)) + float(bal.get("battle_loss_lose_max", 0.55))) * 0.5
	var p := float(pct) / 100.0
	var frac := p * win_mid + (1.0 - p) * lose_mid
	var sq: Dictionary = squads[player]
	var pool := _named_pool(sq)
	var hits := int(round(minf(frac * _effective_size(sq), float(pool.size()))))
	var known := 0
	var n := mini(hits, pool.size())
	for i in n:
		var person: Dictionary = pool[i]
		if int(person.get("memory", 0)) >= 40:
			known += 1
	return {"named": hits, "known": known}


func _named_pool(sq: Dictionary) -> Array:
	var rows: Array = []
	var roster: Array = sq.get("roster", [])
	if not roster.is_empty():
		for id in roster:
			if not people.has(str(id)):
				continue
			var person: Dictionary = people[str(id)]
			if _is_child(person) or int(person.get("absent", 0)) > 0 or int(person.get("sick", 0)) > 0:
				continue
			rows.append(person)
	else:
		for person in residents:
			if _is_council(str(person.get("id", ""))) or _is_child(person) or int(person.get("absent", 0)) > 0:
				continue
			rows.append(person)
	rows.sort_custom(func(a, b): return int(a.get("skills", {}).get("fight", 0)) < int(b.get("skills", {}).get("fight", 0)))
	return rows


func _loss_frac(won: bool) -> float:
	if won:
		return net_rng.randf_range(float(bal.get("battle_loss_win_min", 0.10)), float(bal.get("battle_loss_win_max", 0.25)))
	return net_rng.randf_range(float(bal.get("battle_loss_lose_min", 0.35)), float(bal.get("battle_loss_lose_max", 0.55)))


func _roll_injury() -> bool:
	if injury_bias >= 0.0:
		return injury_bias >= 0.5
	var chance := float(bal.get("battle_injury_chance", 0.30))
	if _room_ready("infirmary"):
		chance = float(bal.get("battle_injury_chance_infirmary", 0.50))
	return net_rng.randf() < chance


func _add_battle_discontent(amount: int) -> void:
	var room := mini(amount, 9 - battle_dis_week)
	if room <= 0:
		return
	_add_discontent(room, "battle")
	battle_dis_week += room


func _resolve_battle(atk: Dictionary, sid: String, breach: bool) -> Dictionary:
	var factors := _battle_factors(atk, sid, breach)
	var roll := net_rng.randf_range(0.8, 1.2)
	var win := float(factors.attack) * roll > float(factors.defense)
	var def_frac := _loss_frac(not win)
	var atk_hurt := _hurt_side(atk, sid, _loss_frac(win))
	var def_hurt := {"dead": [], "injured": []}
	var defender: Dictionary = factors.get("defender", {})
	if not defender.is_empty() and str(defender.get("faction", "")) != str(atk.get("faction", "")):
		def_hurt = _hurt_side(defender, sid, def_frac)
	if stations.has(sid):
		var st: Dictionary = stations[sid]
		st.garrison = maxi(2, int(round(float(st.get("garrison", 2)) * (1.0 - def_frac))))
	var player_hurt := atk_hurt if str(atk.get("faction", "")) == player else def_hurt
	return {"win": win, "player": player_hurt, "attack": factors.attack, "defense": factors.defense, "mods": factors.mods}


func _hurt_side(sq: Dictionary, sid: String, frac: float) -> Dictionary:
	var dead: Array = []
	var injured: Array = []
	var place := _station_place(sid)
	if str(sq.get("faction", "")) != player or not sq.has("roster"):
		var nxt := int(round(float(sq.get("size", 1)) * (1.0 - frac)))
		sq.size = clampi(nxt, 1, int(sq.get("max_size", maxi(1, nxt))))
		return {"dead": dead, "injured": injured}
	var loss_n := maxi(0, int(round(_effective_size(sq) * frac)))
	var pool := _named_pool(sq)
	var hits := mini(loss_n, pool.size())
	for i in hits:
		var person: Dictionary = pool[i]
		var id := str(person.get("id", ""))
		var pname := str(person.get("name", id))
		var known := int(person.get("memory", 0)) >= 40
		if _roll_injury():
			person.absent = 2
			_unassign(id)
			_note_fought(person, place)
			_life_note(person, "injured", {"room": place})
			injured.append({"name": pname, "known": known, "weeks": 2})
			_log(Copy.fill("combat.log.named_injury", {"name": pname, "place": place}), true)
		else:
			_remove_resident(id, true, "battle", "died", place)
			dead.append({"name": pname, "known": known})
			_add_battle_discontent(3)
			_log(Copy.fill("combat.log.named_death", {"name": pname, "place": place}), true)
	var abstract := loss_n - hits
	if abstract > 0:
		sq.attrition = int(sq.get("attrition", 0)) + abstract
	_sync_party(sq)
	return {"dead": dead, "injured": injured}


func _tick_player_party() -> void:
	if not squads.has(player):
		return
	var sq: Dictionary = squads[player]
	if bool(sq.get("returning", false)):
		if week > int(sq.get("return_week", week)):
			_step_party_home(sq)
		return
	if int(sq.get("secure", 0)) > 0:
		sq.secure = int(sq.secure) - 1


func _step_party_home(sq: Dictionary) -> void:
	var before := str(sq.get("station", ""))
	var home := str(sq.get("return_to", capital_id))
	if home == "":
		home = capital_id
	if str(sq.get("station", "")) == home:
		sq.returning = false
		sq.secure = 0
		_sync_party(sq)
		return
	var path := _path(str(sq.station), home)
	if path.size() < 2:
		sq.station = home
		sq.returning = false
		sq.secure = 0
		_sync_party(sq)
		if str(sq.get("station", "")) != before:
			_note_party_home()
		return
	var nxt := str(path[1])
	if _edge_flooded(str(sq.station), nxt) and int(sq.get("ford", 0)) < 1:
		sq.ford = 1
		return
	sq.ford = 0
	sq.station = nxt
	if str(sq.station) == home:
		sq.returning = false
		sq.secure = 0
	_sync_party(sq)
	if str(sq.get("station", "")) != before:
		_note_party_home()


## P43 homecoming. One soft dawn chip when the player party steps back onto the capital
## after having left (patrol, raid, assault, or a return walk). P28, P37 and P42 are not
## on this branch. They outrank this chip by claiming the dawn: set flags.rumor_dawn,
## flags.border_dawn_new or flags.rail_dawn to this week (a bool true claims until cleared).
## Homecoming only reads those flags. flags.heard_home is the once-per-run platform float.
func _note_party_home() -> void:
	if not squads.has(player):
		return
	var sq: Dictionary = squads[player]
	var here := str(sq.get("station", ""))
	if here == "":
		return
	var prev := str(flags.get("home_pos", ""))
	var seen := bool(flags.get("home_seen", false))
	if here != capital_id:
		flags["home_left"] = true
		if not bool(flags.get("home_pending", false)):
			flags["home_from"] = here
	var arrived := seen and prev != "" and prev != capital_id and here == capital_id
	flags["home_pos"] = here
	flags["home_seen"] = true
	if not arrived or not bool(flags.get("home_left", false)):
		return
	if _party_living_count(sq) <= 0:
		return
	if bool(flags.get("home_pending", false)):
		return
	flags["home_pending"] = true


func _party_living_count(sq: Dictionary) -> int:
	var roster = sq.get("roster", [])
	if typeof(roster) != TYPE_ARRAY:
		return 0
	var n := 0
	for id in roster:
		if people.has(str(id)):
			n += 1
	return n


## Known community, or an intel of at least 1. Otherwise the chip says "the line".
func _home_station_known(sid: String) -> bool:
	if sid == "" or not stations.has(sid):
		return false
	var st: Dictionary = stations[sid]
	if bool(st.get("known", false)):
		return true
	return int(st.get("intel", 0)) >= 1


func home_back_line() -> String:
	var sid := str(flags.get("home_shown_from", ""))
	if sid == "":
		sid = str(flags.get("home_from", ""))
	if not _home_station_known(sid):
		return Copy.t("home.back_unknown")
	var name := station_text(sid, "community")
	if name == "":
		return Copy.t("home.back_unknown")
	return Copy.fill("home.back", {"station": name})


## The dawn line for this week, or "" when homecoming is not the chip showing.
## short is the reduce-motion line.
func home_chip_line(short: bool = false) -> String:
	if int(flags.get("home_shown", -1)) != week:
		return ""
	if short:
		return Copy.t("home.reduce")
	return home_back_line()


## Week number claims this dawn only. Bool true claims until the owner clears it.
func _dawn_flag_claims(key: String) -> bool:
	if not flags.has(key):
		return false
	var v = flags[key]
	match typeof(v):
		TYPE_BOOL:
			return bool(v)
		TYPE_INT, TYPE_FLOAT:
			return int(v) == week
		_:
			var text := str(v)
			return text == str(week) or text == "true"
	return false


## Empty when homecoming may show. Otherwise the higher chip that owns this dawn.
func _soft_dawn_blocker() -> String:
	if _dawn_flag_claims("rumor_dawn"):
		return "rumor"
	if _dawn_flag_claims("border_dawn_new"):
		return "border"
	if _dawn_flag_claims("rail_dawn"):
		return "rail"
	return ""


func _offer_home_chip() -> void:
	_note_party_home()
	if not bool(flags.get("home_pending", false)):
		return
	if int(flags.get("home_shown", -1)) == week:
		return
	if _soft_dawn_blocker() != "":
		return
	flags["home_pending"] = false
	flags["home_shown"] = week
	flags["home_dawn"] = week
	flags["home_shown_from"] = str(flags.get("home_from", ""))
	if not bool(flags.get("heard_home", false)):
		flags["home_float"] = true
		flags["heard_home"] = true
	else:
		flags["home_float"] = false


func _note_fought(person: Dictionary, place: String) -> void:
	if not person.has("story_events") or typeof(person.story_events) != TYPE_ARRAY:
		person.story_events = []
	person.story_events.append({
		"pool": "fought",
		"id": "fought",
		"week": week,
		"name": str(person.get("name", "")),
		"room": place,
	})
	person.memory = mini(100, int(person.get("memory", 0)) + 5)


func _battle_death_text(person_name: String, name_ru: String, place: String) -> Dictionary:
	var key := "combat.death.battle" if place == "" else "combat.death.battle_at"
	var packed := Copy.pack(key)
	var ru_name := name_ru if name_ru != "" else person_name
	var en := fill_text({"en": str(packed.get("en", "")), "ru": str(packed.get("en", ""))}, {"name": person_name, "place": place})
	var ru := fill_text({"en": str(packed.get("ru", "")), "ru": str(packed.get("ru", ""))}, {"name": ru_name, "place": place})
	return {"en": en, "ru": ru}

# --- room merging (same type, same upgrade, 2–3 wide) ---
const MERGE_TYPES := ["hydroponics", "air_filter", "generator", "workshop", "quarters"]


func _merge_enabled() -> bool:
	return float(bal.get("merge_bonus", 0.0)) > 0.0 or int(bal.get("merge_on", 0)) != 0


func _merge_short(type: String) -> String:
	if type == "hydroponics":
		return "hydro"
	if type == "air_filter":
		return "filter"
	return type


func _merge_runs(level: int, ghost) -> Array:
	var out: Array = []
	var cap := int(bal.get("merge_max", 3))
	var span := int(catalog.grid.get("cells", 6))
	var run: Array = []
	for cell in span + 1:
		var room = null
		if ghost != null and int(ghost.level) == level and int(ghost.cell) == cell:
			room = ghost
		else:
			var key := _ck(level, cell)
			if cells.has(key) and str(cells[key].get("room", "")) != "":
				room = _room(str(cells[key].room))
		var same := room != null and MERGE_TYPES.has(str(room.type)) and not run.is_empty() and str(run[0].type) == str(room.type) and int(run[0].upgrade) == int(room.upgrade) and run.size() < cap
		if same:
			run.append(room)
			continue
		if run.size() > 1:
			out.append(run)
		run = []
		if room != null and MERGE_TYPES.has(str(room.type)):
			run = [room]
	if run.size() > 1:
		out.append(run)
	return out


func _merge_groups() -> Array:
	var out: Array = []
	if not _merge_enabled():
		return out
	for level in int(catalog.grid.get("levels", 3)):
		for run in _merge_runs(level, null):
			out.append(run)
	return out


func _merge_group_of(room: Dictionary) -> Array:
	if room.is_empty():
		return []
	for b in _merge_groups():
		for r in b:
			if str(r.uid) == str(room.uid):
				return b
	return [room]


func merge_group_of(uid: String) -> Array:
	var room = _room(uid)
	if room == null:
		return []
	var grp := _merge_group_of(room)
	if grp.size() < 2:
		return [uid]
	var out: Array = []
	for r in grp:
		out.append(str(r.uid))
	return out


func _merge_tag_line(type: String, width: int) -> String:
	var key := "merge.tag_%s_%d" % [_merge_short(type), width]
	var line := Copy.t(key)
	if line != key:
		return line
	var bonus_key := "merge.bonus_food"
	if type == "air_filter":
		bonus_key = "merge.bonus_air"
	elif type == "generator":
		bonus_key = "merge.bonus_power"
	elif type == "workshop":
		bonus_key = "merge.bonus_materials"
	elif type == "quarters":
		bonus_key = "merge.bonus_housing"
	var name := Copy.t(str(catalog.rooms[type].name))
	return "%s. %s" % [Copy.t("merge.joins") % [name, Copy.t(bonus_key)], Copy.t("merge.shares")]


func merge_preview(type: String, level: int, cell: int) -> Dictionary:
	var info := {
		"joins": false,
		"partner_uid": "",
		"partner_name": "",
		"width": 1,
		"bonus_line": "",
		"share_line": "",
		"cells": [cell],
	}
	if not MERGE_TYPES.has(type) or not _merge_enabled():
		return info
	var key := _ck(level, cell)
	if not cells.has(key) or not _cell_buildable(cells[key]):
		return info
	var ghost := {
		"uid": "__ghost__",
		"type": type,
		"upgrade": 0,
		"level": level,
		"cell": cell,
		"staff": [],
	}
	var found: Array = []
	for run in _merge_runs(level, ghost):
		for r in run:
			if str(r.uid) == "__ghost__":
				found = run
	if found.size() < 2:
		return info
	info.joins = true
	info.width = found.size()
	var cells_out: Array = []
	var partner = null
	for r in found:
		cells_out.append(int(r.cell))
		if str(r.uid) == "__ghost__":
			continue
		if partner == null or absi(int(r.cell) - cell) < absi(int(partner.cell) - cell):
			partner = r
	info.cells = cells_out
	if partner != null:
		info.partner_uid = str(partner.uid)
		info.partner_name = str(catalog.rooms[str(partner.type)].name)
	info.bonus_line = _merge_tag_line(type, found.size())
	info.share_line = Copy.t("merge.shares")
	return info


func _merge_build_cell(type: String) -> Dictionary:
	if int(bal.get("bot_merge", 0)) == 0 or not MERGE_TYPES.has(type):
		return {}
	var best := {}
	for key in cells:
		var cell: Dictionary = cells[key]
		if not _cell_buildable(cell):
			continue
		for d in [-1, 1]:
			var nk := _ck(int(cell.level), int(cell.cell) + d)
			if not cells.has(nk) or str(cells[nk].room) == "":
				continue
			var other = _room(str(cells[nk].room))
			if other != null and str(other.type) == type and int(other.upgrade) == 0 and _merge_group_of(other).size() < int(bal.get("merge_max", 3)):
				if best.is_empty() or int(cell.level) < int(best.level):
					best = cell
	return best


func _merge_key_bonus(sum: int, width: int) -> int:
	var mb := float(bal.get("merge_bonus", 0.0))
	if mb <= 0.0 or width < 2:
		return 0
	return int(round(float(sum) * mb * float(width - 1)))


func _room_output_rows(room: Dictionary) -> Array:
	var defin: Dictionary = catalog.rooms[room.type]
	var skill := str(defin.get("skill", ""))
	var skills: Array = []
	for id in room.staff:
		var person: Dictionary = people[str(id)]
		var value := 0 if skill == "" else int(person.skills.get(skill, 1))
		if int(person.sick) > 0 or int(person.absent) > 0:
			value = 0
		skills.append(value)
	var outputs: Array = []
	var base: Dictionary = defin.base
	for key in base:
		var amount := float(base[key]) * output_scale(int(room.upgrade))
		var factor := _output_factor(room, defin)
		var n := 0
		if factor > 0.0:
			n = Formulas.room_output(amount, skills, float(bal.skill_coef), float(bal.output_cap))
			n = int(round(float(n) * factor))
		if bool(defin.get("decays", false)):
			n = int(round(float(n) * float(room.efficiency)))
		if belt_down and str(room.type) == "hydroponics" and str(key) == "food":
			n = int(n / 2.0)
		if workshop_down and str(room.type) == "workshop" and str(key) == "materials" and not shrugs_down(room):
			n = 0
		elif gen_down and str(room.type) == "generator" and str(key) == "power":
			n = int(n / 2.0)
			n += crew_extra(skills, room, n)
		elif not (workshop_down and str(room.type) == "workshop" and str(key) == "materials" and not shrugs_down(room)):
			n += crew_extra(skills, room, n)
		if str(key) == "food" and factor > 0.0 and int(room.get("mold", 0)) <= 0:
			n += mushroom_food(room)
		n = share_cut(scale_push(n, room))
		outputs.append({"key": str(key), "amount": n, "base": amount})
	return outputs


func _flood_merge_blocks() -> PackedStringArray:
	var names := PackedStringArray()
	for b in _merge_groups():
		var hit := false
		for r in b:
			var key := _ck(int(r.level), int(r.cell))
			if cells.has(key) and bool(cells[key].get("flooded", false)):
				hit = true
		if not hit:
			continue
		for r in b:
			var key := _ck(int(r.level), int(r.cell))
			if not cells.has(key):
				continue
			var cell: Dictionary = cells[key]
			var was: bool = bool(cell.flooded)
			cell.flooded = true
			r.offline = true
			if not was:
				names.append(Copy.t(str(catalog.rooms[str(r.type)].name)))
	return names
