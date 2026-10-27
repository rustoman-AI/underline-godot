extends RefCounted

## P73 Charges · Promises · Mandate · Week ticker.
## Cards are the event/dawn family. They do not join the soft-dawn stack
## (rumor → border.dawn_new → rail → homecoming).
## Charge fail changes nothing. Mandate +100 is only stats.mandate_fulfilled,
## which score_now() already reads. This file never adds 100 itself.
##
## Penn has no faction. foundry loyalty 78 is opinion −10 (loyalty − 88).
## "Dig to level 3" is a newly opened bottom cell (2:2–2:5). The grid only has
## levels 0–2, and 2:0 / 2:1 start open.
## Unite Brooklyn is owned stations ≥ 5 (there is no vassal field).
## Line capital is a late secure capital: week ≥ 33, still ours, pop ≥ 40.
## medkits_3 stays in the text pack and is never drawn (no medkit count).

const IDS_MANDATE := ["hold_coney", "unite_brooklyn", "reach_floor", "faith_dead", "line_capital"]
const DEFAULT_MANDATE := ["hold_coney", "unite_brooklyn", "reach_floor"]
const PRESSURE := ["hope_40", "discontent_under_50", "squad_home_3", "no_named_death_4", "power_steady", "air_ok", "no_food_short_3", "hydro_staffed"]
const RANK := {
	"ultimatum": 0,
	"season": 1,
	"charge": 2,
	"promise": 3,
	"runners": 4,
	"build": 5,
	"law_cooldown": 6,
}


static func on_dawn(g) -> void:
	_norm(g)
	if int(g.promise.get("prev_dis", -1)) < 0:
		g.promise.prev_dis = int(g.discontent)
	_tick_rows(g)
	_refill(g)
	_tick_promise(g)
	_maybe_offer_promise(g)
	_maybe_offer_mandate(g)
	_eval_mandate(g, false)
	g.promise.prev_dis = int(g.discontent)


static func before_score(g) -> void:
	_norm(g)
	_eval_mandate(g, true)


static func seed_night(g) -> void:
	_norm(g)
	var left := int(g.charges.get("seed_weeks", 0))
	if left <= 0:
		return
	var bonus := 0
	var need := 1
	if g.catalog != null and g.catalog.rooms.has("hydroponics"):
		need = maxi(1, int(g.catalog.rooms.hydroponics.get("staff_min", 1)))
	for room in g.rooms:
		if str(room.get("type", "")) != "hydroponics":
			continue
		if bool(room.get("offline", false)):
			continue
		if room.get("staff", []).size() >= need:
			bonus += 1
	g.stock.food = int(g.stock.get("food", 0)) + maxi(1, bonus)
	g.charges.seed_weeks = left - 1


static func apply_choice(g, ev: Dictionary, choice: Dictionary) -> void:
	_norm(g)
	var cm := str(ev.get("cm", ""))
	var cid := str(choice.get("id", ""))
	if cm == "promise":
		if cid == "accept":
			_accept(g, str(ev.get("promise_id", "")))
		else:
			_decline(g)
	elif cm == "mandate" and cid == "confirm":
		if g.mandate.get("picked", []).is_empty():
			commit(g, DEFAULT_MANDATE.duplicate(), false, false)


static func commit(g, ids: Array, count_decision := true, drop_pending := true) -> bool:
	_norm(g)
	if ids.size() != 3:
		return false
	var seen := {}
	var clean: Array = []
	for raw in ids:
		var id := str(raw)
		if not IDS_MANDATE.has(id) or seen.has(id):
			return false
		seen[id] = true
		clean.append(id)
	g.mandate.picked = clean
	g.mandate.offered = true
	g.mandate.show_progress = true
	g.mandate.missed = false
	if drop_pending:
		var keep: Array = []
		for ev in g.pending:
			if str(ev.get("cm", "")) == "mandate" or str(ev.get("id", "")) == "mandate_pick":
				continue
			keep.append(ev)
		g.pending = keep
	if count_decision:
		g.decisions += 1
	return true


static func progress_line(g) -> String:
	_norm(g)
	if not bool(g.mandate.get("show_progress", false)) or bool(g.mandate.get("missed", false)):
		return ""
	var ids = g.mandate.get("picked", [])
	if not (ids is Array) or ids.is_empty():
		return ""
	var titles: PackedStringArray = []
	for id in ids:
		titles.append(Copy.t("mandate.title." + str(id)))
	return Copy.fill("mandate.progress", {"title": " · ".join(titles)})


static func panel_rows(g) -> Array:
	_norm(g)
	var out: Array = []
	for row in g.charges.get("active", []):
		var id := str(row.get("id", ""))
		var n := maxi(0, int(row.get("due", 0)) - int(g.week))
		out.append({
			"id": id,
			"text": Copy.t("charge.text." + id),
			"due": Copy.fill("charge.due", {"n": str(n)}),
			"reward": reward_label(str(row.get("reward", ""))),
		})
	return out


static func promise_line(g) -> String:
	_norm(g)
	if str(g.promise.get("status", "")) != "active":
		return ""
	var id := str(g.promise.get("id", ""))
	if id == "":
		return ""
	return Copy.fill("promise.active", {"text": Copy.t("promise.text." + id)})


static func cooldown_line(g) -> String:
	_norm(g)
	if not bool(g.promise.get("refused_recent", false)):
		return ""
	if int(g.week) >= int(g.promise.get("cooldown_until", 0)):
		return ""
	return Copy.t("promise.cooldown")


static func reward_label(kind: String) -> String:
	if kind == "seeds_x2":
		return Copy.t("good.seeds.name") + " ×2"
	var key := "charge.done"
	if kind == "goods":
		key = "charge.done_goods"
	elif kind == "intel":
		key = "charge.done_intel"
	elif kind == "influence_4" or kind == "influence_6":
		key = "charge.done_influence"
	var line := Copy.t(key)
	var parts := line.split("—")
	if parts.size() < 2:
		parts = line.split(" - ")
	if parts.size() >= 2:
		var word := str(parts[parts.size() - 1]).strip_edges()
		if word.ends_with("."):
			word = word.substr(0, word.length() - 1)
		return word
	return line


static func ticker_items(g) -> Array:
	_norm(g)
	var rows: Array = []
	var runners := _runners_weeks(g)
	if runners >= 1:
		rows.append(_tick_row("runners", runners, Copy.fill("ticker.runners", {"n": str(runners)})))
	var build_n := int(g.build.get("left", 0)) if not g.build.is_empty() else 0
	if build_n >= 1:
		rows.append(_tick_row("build", build_n, Copy.fill("ticker.build", {"n": str(build_n)})))
	var charge_n := _soonest_charge(g)
	if charge_n >= 1:
		rows.append(_tick_row("charge", charge_n, Copy.fill("ticker.charge", {"n": str(charge_n)})))
	if str(g.promise.get("status", "")) == "active":
		var pn := int(g.promise.get("due", 0)) - int(g.week)
		if pn >= 1:
			rows.append(_tick_row("promise", pn, Copy.fill("ticker.promise", {"n": str(pn)})))
	var ult := _soonest_ultimatum(g)
	if ult >= 1:
		rows.append(_tick_row("ultimatum", ult, Copy.fill("ticker.ultimatum", {"n": str(ult)})))
	var season_n := 0
	var season_name := ""
	for season in g.seasons:
		var n := int(season.get("week", 0)) - int(g.week)
		if n < 1:
			continue
		if season_n == 0 or n < season_n:
			season_n = n
			season_name = Copy.season(str(season.get("id", "")))
	if season_n >= 1:
		rows.append(_tick_row("season", season_n, Copy.fill("ticker.season", {"n": str(season_n), "season": season_name})))
	if int(g.law_lock) >= 1:
		rows.append(_tick_row("law_cooldown", int(g.law_lock), Copy.fill("ticker.law_cooldown", {"n": str(int(g.law_lock))})))
	rows.sort_custom(func(a, b):
		if int(a.n) != int(b.n):
			return int(a.n) < int(b.n)
		return int(a.rank) < int(b.rank)
	)
	if rows.size() > 4:
		rows = rows.slice(0, 4)
	return rows


static func ticker_texts(g) -> Array:
	var out: Array = []
	for row in ticker_items(g):
		out.append(str(row.get("text", "")))
	return out


static func promise_event(id: String) -> Dictionary:
	return {
		"id": "promise_offer",
		"major": true,
		"cm": "promise",
		"promise_id": id,
		"title": Copy.pack("promise.offer_title"),
		"text": Copy.pack("promise.offer"),
		"choices": [
			{"id": "decline", "label": Copy.pack("promise.decline")},
			{"id": "accept", "label": Copy.pack("promise.accept")},
		],
	}


static func mandate_event() -> Dictionary:
	return {
		"id": "mandate_pick",
		"major": true,
		"cm": "mandate",
		"title": Copy.pack("mandate.pick"),
		"text": Copy.pack("mandate.pick_body"),
		"choices": [
			{"id": "confirm", "label": Copy.pack("mandate.confirm")},
		],
	}


static func _tick_row(kind: String, n: int, text: String) -> Dictionary:
	return {"kind": kind, "n": n, "rank": int(RANK.get(kind, 9)), "text": text}


static func _norm(g) -> void:
	if not (g.charges is Dictionary) or g.charges.is_empty():
		g.charges = {"active": [], "closed": [], "seed_weeks": 0}
	if not g.charges.has("active") or not (g.charges.active is Array):
		g.charges.active = []
	if not g.charges.has("closed") or not (g.charges.closed is Array):
		g.charges.closed = []
	if not g.charges.has("seed_weeks"):
		g.charges.seed_weeks = 0
	if not (g.promise is Dictionary) or not g.promise.has("status"):
		g.promise = _blank_promise(int(g.discontent))
	if not (g.mandate is Dictionary) or not g.mandate.has("picked"):
		g.mandate = _blank_mandate()
	if not (g.mandate.picked is Array):
		g.mandate.picked = []


static func _blank_promise(dis: int) -> Dictionary:
	return {
		"status": "", "id": "", "due": 0, "born": 0, "streak": 0, "base": 0,
		"clean": 0, "home": 0, "cooldown_until": 0, "refused_recent": false,
		"cooldown_tipped": false, "prev_dis": dis,
	}


static func _blank_mandate() -> Dictionary:
	return {
		"offered": false, "picked": [], "show_progress": false,
		"fulfilled": false, "missed": false, "late_short": false,
	}


static func _rng(g) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g.seed) * 10007 + int(g.week) * 131 + 17
	return rng


static func _shuffle(rng: RandomNumberGenerator, rows: Array) -> void:
	for i in range(rows.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = rows[i]
		rows[i] = rows[j]
		rows[j] = tmp


static func _tick_rows(g) -> void:
	var active: Array = g.charges.active
	var i := active.size() - 1
	while i >= 0:
		var row: Dictionary = active[i]
		if int(row.get("born", 0)) == int(g.week):
			i -= 1
			continue
		var verdict := _judge_charge(g, row)
		if verdict == "done":
			_grant(g, row)
			_close_charge(g, i)
		elif verdict == "fail":
			g.notices.append(Copy.t("charge.failed"))
			_close_charge(g, i)
		i -= 1


static func _close_charge(g, index: int) -> void:
	var row: Dictionary = g.charges.active[index]
	var id := str(row.get("id", ""))
	g.charges.active.remove_at(index)
	if id != "" and not g.charges.closed.has(id):
		g.charges.closed.append(id)


static func _refill(g) -> void:
	var rng := _rng(g)
	var pressure: Array = []
	for id in PRESSURE:
		if _eligible(g, id):
			pressure.append(id)
	_shuffle(rng, pressure)
	var easy: Array = []
	var pack = g.catalog.charges_pack if g.catalog != null else {}
	var rows = pack.get("charges", []) if pack is Dictionary else []
	for row in rows:
		var id := str(row.get("id", ""))
		if PRESSURE.has(id) or id == "medkits_3":
			continue
		if _eligible(g, id):
			easy.append(id)
	_shuffle(rng, easy)
	while g.charges.active.size() < 3:
		var id := ""
		if not pressure.is_empty():
			id = str(pressure.pop_front())
		elif not easy.is_empty():
			id = str(easy.pop_front())
		else:
			break
		if not _eligible(g, id):
			continue
		var need := _need_weeks(id)
		var span := rng.randi_range(maxi(3, need), 6)
		var due := mini(int(g.week) + span, _gate(id) + 1)
		if due <= int(g.week):
			if not g.charges.closed.has(id):
				g.charges.closed.append(id)
			continue
		g.charges.active.append({
			"id": id,
			"due": due,
			"reward": _reward_kind(g, id),
			"streak": 0,
			"base": _charge_base(g, id),
			"born": int(g.week),
		})


static func _reward_kind(g, id: String) -> String:
	var pack = g.catalog.charges_pack if g.catalog != null else {}
	for row in pack.get("charges", []):
		if str(row.get("id", "")) == id:
			return str(row.get("reward_kind", "intel"))
	return "intel"


static func _eligible(g, id: String) -> bool:
	if id == "" or id == "medkits_3":
		return false
	if g.charges.closed.has(id) or _active_has(g, id):
		return false
	if int(g.week) + _need_weeks(id) > _gate(id):
		return false
	if _already(g, id):
		return false
	if PRESSURE.has(id):
		return _under_pressure(g, id)
	return true


static func _active_has(g, id: String) -> bool:
	for row in g.charges.active:
		if str(row.get("id", "")) == id:
			return true
	return false


static func _need_weeks(id: String) -> int:
	match id:
		"hydro_staffed", "discontent_under_50", "no_named_death_4", "air_ok":
			return 4
		"no_food_short_3", "penn_cool", "meeting_hall", "squad_home_3", "power_steady":
			return 3
		"hope_40", "synod_15", "push_twice":
			return 2
		_:
			return 1


static func _gate(id: String) -> int:
	match id:
		"food_store_wk9":
			return 9
		"mats_store":
			return 10
		"scout_ferry":
			return 11
		"dig_level_3":
			return 12
		"scout_botanic":
			return 14
		_:
			return 99


static func _under_pressure(g, id: String) -> bool:
	match id:
		"hope_40":
			return int(g.hope) < 48
		"discontent_under_50":
			return int(g.discontent) >= 35
		"squad_home_3":
			return not _squad_home(g)
		"no_named_death_4":
			return int(g.stats.get("named_dead", 0)) > 0
		"power_steady":
			return int(g.flags.get("cm_power_short", -99)) >= int(g.week) - 4
		"air_ok":
			return int(g.flags.get("cm_air_short", -99)) >= int(g.week) - 4
		"no_food_short_3":
			return g.food_buffer_weeks() < 1.6 or int(g.flags.get("cm_food_short", -99)) >= int(g.week) - 4
		"hydro_staffed":
			return int(g.week) >= 8 and g._room_ready("hydroponics")
		_:
			return false


static func _already(g, id: String) -> bool:
	match id:
		"food_store_wk9":
			return g.food_buffer_weeks() >= 2.0
		"scout_botanic":
			return _known(g, "botanic")
		"scout_ferry":
			return _ferry_open(g)
		"scout_neighbor":
			return _known_others(g) >= 3
		"exchange_20":
			return int(g.opinions.get("exchange", 0)) >= 20
		"synod_15":
			return int(g.opinions.get("synod", 0)) >= 15
		"directorate_deal":
			return g.audience_deals.has("directorate")
		"dig_level_3":
			return _dug_level3(g)
		"pop_30":
			return g.residents.size() >= 30
		"mats_store":
			return int(g.stock.get("materials", 0)) >= 20
		"hold_station":
			return g.owned_count() > 1
		"papers_1":
			return int(g.artifacts.get("papers", 0)) >= 1
		"approach_mark":
			return _approach_marked(g)
		"night_run_2":
			return _night_runs(g) >= 2
		"build_infirmary":
			return g._room_ready("infirmary") and bool(g.flags.get("medkits", false))
		"win_patrol":
			return int(g.flags.get("cm_patrol_win", 0)) > 0
		_:
			return false


static func _charge_base(g, id: String) -> int:
	match id:
		"build_quarters":
			return _room_count(g, "quarters")
		"night_run_2":
			return _night_runs(g)
		"law_adapt_2":
			return _adapt_laws(g)
		"no_named_death_4":
			return int(g.stats.get("named_dead", 0))
		"push_twice":
			return _push_weeks_since(g, 0)
		_:
			return 0


static func _judge_charge(g, row: Dictionary) -> String:
	var id := str(row.get("id", ""))
	var born := int(row.get("born", 0))
	if id == "push_twice" and int(g.flags.get("cm_named_injury", -1)) >= born:
		return "fail"
	if id == "no_named_death_4" and int(g.stats.get("named_dead", 0)) > int(row.get("base", 0)):
		return "fail"
	if _charge_met(g, row):
		return "done"
	if int(g.week) >= int(row.get("due", 0)):
		return "fail"
	return "open"


static func _charge_met(g, row: Dictionary) -> bool:
	var id := str(row.get("id", ""))
	var born := int(row.get("born", 0))
	match id:
		"food_store_wk9":
			return g.food_buffer_weeks() >= 2.0 and int(g.week) <= _gate(id)
		"no_food_short_3":
			return _clean_streak(g, row, "cm_food_short") >= 3
		"hydro_staffed":
			return _staff_streak(g, row, "hydroponics") >= 4
		"scout_botanic":
			return _known(g, "botanic")
		"scout_ferry":
			return _ferry_open(g)
		"scout_neighbor":
			return _known_others(g) >= 3
		"exchange_20":
			return int(g.opinions.get("exchange", 0)) >= 20
		"synod_15":
			return _opinion_streak(g, row, "synod", 15) >= 2
		"directorate_deal":
			return g.audience_deals.has("directorate")
		"penn_cool":
			return _penn_streak(g, row) >= 3
		"dig_level_3":
			return _dug_level3(g)
		"build_quarters":
			return _room_count(g, "quarters") > int(row.get("base", 0))
		"build_infirmary":
			return g._room_ready("infirmary") and bool(g.flags.get("medkits", false))
		"meeting_hall":
			return _staff_streak(g, row, "meeting_hall") >= 3
		"hope_40":
			return _hope_streak(g, row) >= 2
		"discontent_under_50":
			return _dis_streak(g, row) >= 4
		"pop_30":
			return g.residents.size() >= 30
		"no_named_death_4":
			return _named_quiet_streak(g, row) >= 4
		"squad_home_3":
			return _home_streak(g, row) >= 3
		"win_patrol":
			return int(g.flags.get("cm_patrol_win", -1)) >= born
		"push_twice":
			return _push_weeks_since(g, born) >= int(row.get("base", 0)) + 2
		"mats_store":
			return int(g.stock.get("materials", 0)) >= 20 and int(g.week) <= _gate(id)
		"power_steady":
			return _clean_streak(g, row, "cm_power_short") >= 3
		"air_ok":
			return _clean_streak(g, row, "cm_air_short") >= 4
		"hold_station":
			return g.owned_count() > 1
		"papers_1":
			return int(g.artifacts.get("papers", 0)) >= 1
		"approach_mark":
			return _approach_marked(g)
		"night_run_2":
			return _night_runs(g) >= int(row.get("base", 0)) + 2
		"law_adapt_2":
			return _adapt_laws(g) >= int(row.get("base", 0)) + 2
		_:
			return false


static func _bump(row: Dictionary, ok: bool) -> int:
	if ok:
		row.streak = int(row.get("streak", 0)) + 1
	else:
		row.streak = 0
	return int(row.streak)


static func _clean_streak(g, row: Dictionary, flag: String) -> int:
	var dirty := int(g.flags.get(flag, -99)) == int(g.week) - 1
	return _bump(row, not dirty)


static func _staff_streak(g, row: Dictionary, type: String) -> int:
	return _bump(row, g._room_ready(type))


static func _opinion_streak(g, row: Dictionary, fid: String, floor: int) -> int:
	return _bump(row, int(g.opinions.get(fid, -999)) >= floor)


static func _penn_streak(g, row: Dictionary) -> int:
	return _bump(row, _penn_opinion(g) >= -10)


static func _hope_streak(g, row: Dictionary) -> int:
	return _bump(row, int(g.hope) >= 40)


static func _dis_streak(g, row: Dictionary) -> int:
	return _bump(row, int(g.discontent) < 50)


static func _named_quiet_streak(g, row: Dictionary) -> int:
	return _bump(row, int(g.stats.get("named_dead", 0)) <= int(row.get("base", 0)))


static func _home_streak(g, row: Dictionary) -> int:
	return _bump(row, _squad_home(g))


static func _grant(g, row: Dictionary) -> void:
	var kind := str(row.get("reward", ""))
	match kind:
		"blueprint":
			g.stock.blueprints = int(g.stock.get("blueprints", 0)) + 1
			g.notices.append(Copy.t("charge.done"))
		"goods":
			g.stock.materials = int(g.stock.get("materials", 0)) + 2
			g.notices.append(Copy.t("charge.done_goods"))
		"seeds_x2":
			g.charges.seed_weeks = int(g.charges.get("seed_weeks", 0)) + 2
			g.notices.append(Copy.t("charge.done_goods"))
		"influence_4":
			g.stock.influence = int(g.stock.get("influence", 0)) + 4
			g.notices.append(Copy.t("charge.done_influence"))
		"influence_6":
			g.stock.influence = int(g.stock.get("influence", 0)) + 6
			g.notices.append(Copy.t("charge.done_influence"))
		"intel":
			g.notices.append(Copy.t("charge.done_intel"))
		_:
			g.notices.append(Copy.t("charge.failed"))


static func _tick_promise(g) -> void:
	if str(g.promise.get("status", "")) != "active":
		return
	if int(g.promise.get("born", 0)) == int(g.week):
		return
	var id := str(g.promise.get("id", ""))
	var verdict := _judge_promise(g, id)
	if verdict == "kept":
		g._add_hope(3, "promise")
		g.notices.append(Copy.t("promise.kept"))
		_clear_promise(g, false)
	elif verdict == "broke":
		g._add_discontent(15, "promise")
		g._add_hope(-3, "promise")
		g.notices.append(Copy.t("promise.broke"))
		_clear_promise(g, false)


static func _judge_promise(g, id: String) -> String:
	var due := int(g.promise.get("due", 0))
	match id:
		"no_shortage_3":
			if _short_last_night(g, true):
				return "broke"
			g.promise.clean = int(g.promise.get("clean", 0)) + 1
			if int(g.promise.clean) >= 3:
				return "kept"
		"feed_full":
			if int(g.flags.get("cm_food_short", -99)) == int(g.week) - 1:
				return "broke"
			g.promise.clean = int(g.promise.get("clean", 0)) + 1
			if int(g.promise.clean) >= 4:
				return "kept"
		"hall_open":
			if g._room_ready("meeting_hall"):
				g.promise.streak = int(g.promise.get("streak", 0)) + 1
			else:
				g.promise.streak = 0
			if int(g.promise.streak) >= 4:
				return "kept"
		"squad_rest":
			if not _squad_home(g):
				return "broke"
			g.promise.home = int(g.promise.get("home", 0)) + 1
			if int(g.promise.home) >= 2:
				return "kept"
		"build_quarters":
			if _room_count(g, "quarters") > int(g.promise.get("base", 0)):
				return "kept"
		"repeal_double":
			if not g._law_on("double_shifts"):
				return "kept"
		"bury_next":
			return _judge_bury(g)
		"no_push_week":
			if _push_weeks_since(g, int(g.promise.get("born", 0))) > 0:
				return "broke"
			g.promise.streak = int(g.promise.get("streak", 0)) + 1
			if int(g.promise.streak) >= 3:
				return "kept"
		_:
			pass
	if int(g.week) >= due:
		return "broke"
	return "open"


static func _judge_bury(g) -> String:
	var born := int(g.promise.get("born", 0))
	var waiting := false
	for row in g.departed:
		if str(row.get("how", "")) != "died":
			continue
		if int(row.get("week", 0)) < born:
			continue
		var burial := str(row.get("burial", ""))
		if burial == "bury":
			return "kept"
		if burial == "ledger" or burial == "tunnel":
			return "broke"
		waiting = true
	if int(g.week) >= int(g.promise.get("due", 0)):
		return "broke"
	if waiting:
		return "open"
	return "open"


static func _short_last_night(g, any_kind: bool) -> bool:
	var night := int(g.week) - 1
	if int(g.flags.get("cm_food_short", -99)) == night:
		return true
	if not any_kind:
		return false
	return int(g.flags.get("cm_air_short", -99)) == night or int(g.flags.get("cm_power_short", -99)) == night


static func _maybe_offer_promise(g) -> void:
	if str(g.promise.get("status", "")) != "":
		return
	if _pending_cm(g, "promise"):
		return
	var prev := int(g.promise.get("prev_dis", 0))
	var now := int(g.discontent)
	var rising := prev < 60 and now >= 60
	var until := int(g.promise.get("cooldown_until", 0))
	var cooling := int(g.week) < until
	var refused := bool(g.promise.get("refused_recent", false))
	if rising and cooling and refused and not bool(g.promise.get("cooldown_tipped", false)):
		g.notices.append(Copy.t("promise.cooldown"))
		g.promise.cooldown_tipped = true
		return
	if now < 60 or cooling:
		return
	if not rising and not refused:
		return
	var id := _pick_promise(g)
	if id == "":
		return
	g.promise.status = "offer"
	g.promise.id = id
	g.promise.refused_recent = false
	g.pending.append(promise_event(id))


static func _pick_promise(g) -> String:
	var ids: Array = []
	var pack = g.catalog.charges_pack if g.catalog != null else {}
	for row in pack.get("promises", []):
		var id := str(row.get("id", ""))
		if id == "repeal_double" and not g._law_on("double_shifts"):
			continue
		if id != "":
			ids.append(id)
	if ids.is_empty():
		return ""
	var rng := _rng(g)
	return str(ids[rng.randi_range(0, ids.size() - 1)])


static func _accept(g, id: String) -> void:
	if id == "":
		id = str(g.promise.get("id", ""))
	g._add_discontent(-8, "promise")
	g.promise.status = "active"
	g.promise.id = id
	g.promise.born = int(g.week)
	g.promise.due = int(g.week) + 4
	g.promise.streak = 0
	g.promise.clean = 0
	g.promise.home = 0
	g.promise.base = _room_count(g, "quarters")
	g.promise.refused_recent = false
	g.promise.cooldown_tipped = false


static func _decline(g) -> void:
	g.promise.status = ""
	g.promise.id = ""
	g.promise.refused_recent = true
	g.promise.cooldown_until = int(g.week) + 4
	g.promise.cooldown_tipped = false
	g.notices.append(Copy.t("promise.refused"))


static func _clear_promise(g, refused: bool) -> void:
	g.promise.status = ""
	g.promise.id = ""
	g.promise.streak = 0
	g.promise.clean = 0
	g.promise.home = 0
	if refused:
		g.promise.refused_recent = true


static func _maybe_offer_mandate(g) -> void:
	if int(g.week) != 8 or bool(g.mandate.get("offered", false)):
		return
	if not g.mandate.get("picked", []).is_empty():
		g.mandate.offered = true
		return
	if not _pending_cm(g, "mandate"):
		g.pending.append(mandate_event())
	g.mandate.offered = true


static func _eval_mandate(g, sealing: bool) -> void:
	var ids = g.mandate.get("picked", [])
	if not (ids is Array) or ids.is_empty():
		return
	if bool(g.mandate.get("fulfilled", false)) or bool(g.mandate.get("missed", false)):
		return
	if _mandate_all(g, ids, sealing):
		g.mandate.fulfilled = true
		g.mandate.show_progress = true
		g.stats["mandate_fulfilled"] = true
		g.notices.append(Copy.t("mandate.fulfilled"))
		return
	if sealing or _mandate_impossible(g, ids):
		g.mandate.missed = true
		g.mandate.show_progress = false


static func _mandate_all(g, ids: Array, sealing: bool) -> bool:
	for id in ids:
		if not _mandate_met(g, str(id), sealing):
			return false
	return true


static func _mandate_met(g, id: String, sealing: bool) -> bool:
	match id:
		"hold_coney":
			return sealing and g.residents.size() >= 50 and not bool(g.mandate.get("late_short", false))
		"unite_brooklyn":
			return g.owned_count() >= 5
		"reach_floor":
			return int(g.artifacts.get("papers", 0)) >= 3 and bool(g.floor_met)
		"faith_dead":
			return _faith_kept(g)
		"line_capital":
			return int(g.week) >= 33 and _owns_capital(g) and g.residents.size() >= 40 and str(g.over) != "capital"
		_:
			return false


static func _mandate_impossible(g, ids: Array) -> bool:
	if ids.has("hold_coney") and bool(g.mandate.get("late_short", false)):
		return true
	if ids.has("faith_dead") and int(g.stats.get("named_dead", 0)) > 5:
		return true
	return false


static func _faith_kept(g) -> bool:
	if int(g.stats.get("named_dead", 0)) > 5:
		return false
	for row in g.departed:
		if str(row.get("how", "")) != "died":
			continue
		if str(row.get("burial", "")) != "bury":
			return false
	return true


static func _pending_cm(g, cm: String) -> bool:
	for ev in g.pending:
		if str(ev.get("cm", "")) == cm:
			return true
	return false


static func _runners_weeks(g) -> int:
	if not g.expedition.is_empty() and int(g.expedition.get("left", 0)) >= 1:
		return int(g.expedition.get("left", 0))
	if not g.squads.has(g.player):
		return 0
	var sq: Dictionary = g.squads[g.player]
	if bool(sq.get("returning", false)):
		var n := int(sq.get("return_week", 0)) - int(g.week)
		if n >= 1:
			return n
	return 0


static func _soonest_charge(g) -> int:
	var best := 0
	for row in g.charges.get("active", []):
		var n := int(row.get("due", 0)) - int(g.week)
		if n < 1:
			continue
		if best == 0 or n < best:
			best = n
	return best


static func _soonest_ultimatum(g) -> int:
	var best := 0
	for d in g.demands:
		if bool(d.get("paid", false)):
			continue
		var n := int(d.get("deadline", 0))
		if n < 1:
			continue
		if best == 0 or n < best:
			best = n
	return best


static func _squad_home(g) -> bool:
	if not g.squads.has(g.player):
		return false
	var sq: Dictionary = g.squads[g.player]
	if bool(sq.get("away", false)) or bool(sq.get("returning", false)):
		return false
	if not g.expedition.is_empty():
		return false
	return str(sq.get("station", "")) == str(g.capital_id)


static func _known(g, sid: String) -> bool:
	return g.stations.has(sid) and bool(g.stations[sid].get("known", false))


static func _known_others(g) -> int:
	var n := 0
	for sid in g.stations:
		if str(sid) == str(g.capital_id):
			continue
		if bool(g.stations[sid].get("known", false)):
			n += 1
	return n


static func _ferry_open(g) -> bool:
	if _known(g, "vault"):
		return true
	var tunnel = g._tunnel_by_id("to_ferry")
	return tunnel is Dictionary and bool(tunnel.get("dug", false))


static func _approach_marked(g) -> bool:
	if bool(g.floor_met):
		return true
	var tunnel = g._tunnel_by_id("to_floor")
	return tunnel is Dictionary and bool(tunnel.get("dug", false))


static func _dug_level3(g) -> bool:
	for key in ["2:2", "2:3", "2:4", "2:5"]:
		if g.cells.has(key) and bool(g.cells[key].get("dug", false)):
			return true
	return false


static func _penn_opinion(g) -> int:
	var loy := 78
	if g.stations.has("foundry"):
		loy = int(g.stations.foundry.get("loyalty", 78))
	return loy - 88


static func _room_count(g, type: String) -> int:
	var n := 0
	for room in g.rooms:
		if str(room.get("type", "")) == type and not bool(room.get("offline", false)):
			n += 1
	return n


static func _night_runs(g) -> int:
	var n := 0
	for person in g.residents:
		n += int(person.get("night_runs", 0))
	return n


static func _adapt_laws(g) -> int:
	var n := 0
	for id in g.laws_on:
		if not bool(g.laws_on[id]):
			continue
		var defin: Dictionary = g.catalog.laws.get(str(id), {})
		if bool(defin.get("repealable", false)):
			n += 1
	return n


static func _push_weeks_since(g, born: int) -> int:
	var seen := {}
	for room in g.rooms:
		for at in room.get("push_weeks", []):
			var w := int(at)
			if w < born or seen.has(w):
				continue
			seen[w] = true
	return seen.size()


static func _owns_capital(g) -> bool:
	if not g.stations.has(g.capital_id):
		return false
	return str(g.stations[g.capital_id].get("owner", "")) == str(g.player)
