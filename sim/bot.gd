class_name Bot
extends RefCounted

## Two stewards. Careful keeps a reserve. Expander takes every station and spends the reserve.

var profile := "careful"
var _did_aid := false
var _did_talk := false
var _did_ration := false


func play(weeks: int, run_seed: int, profile_name: String = "careful") -> Dictionary:
	profile = profile_name
	var catalog := Catalog.new()
	if not catalog.load_all():
		return {"ok": false, "summary": catalog.error, "over": "error", "errors": [catalog.error], "week": 0}
	var game := Game.new()
	game.setup(catalog, run_seed, weeks)
	game.audit = profile_name != "follower"
	var guard := 0
	while game.over == "" and guard < weeks + 2:
		guard += 1
		_act(game)
		game.end_week()
	var report := game.report()
	report["profile"] = profile
	return report


func _act(game: Game) -> void:
	if game.use_medkits():
		pass
	if profile == "follower":
		_follow(game)
		return
	_did_aid = false
	_did_talk = false
	var guard := 0
	while not game.pending.is_empty() and guard < 6:
		guard += 1
		var ev: Dictionary = game.pending[0]
		var best: Dictionary = {}
		var best_score := -99999
		if profile == "expander" and _all_checks(ev):
			best = _expander_check_choice(game, ev)
		else:
			for choice in ev.choices:
				if game.choice_locked(choice) or not game.choice_offered(choice) or not game.afford_choice(choice):
					continue
				var score := _score_choice(game, choice)
				if score > best_score:
					best_score = score
					best = choice
		if best.is_empty():
			break
		if not game.apply(_event_action(game, ev, best)):
			break
	var project := _project(game)
	if not project.is_empty():
		game.apply(project)
	game.apply({"kind": "staff"})
	var spent := 0
	while spent < game.council.size():
		var order := _order(game)
		if order.is_empty():
			break
		if not game.apply(order):
			break
		spent += 1
	if profile != "follower" and game.decisions < 2:
		game.apply({"kind": "staff"})


func _follow(game: Game) -> void:
	for demand in game.demands:
		if bool(demand.paid):
			continue
		if int(game.stock.tokens) >= int(demand.amount):
			game.apply({"kind": "order", "order": "pay", "demand": str(demand.id)})
			break
	var forecasts: Array = game.forecasts()
	if not game.revolt_warning().is_empty():
		forecasts.append({"key": "discontent"})
	var guard := 0
	while not game.pending.is_empty() and guard < 6:
		guard += 1
		var ev: Dictionary = game.pending[0]
		var choice := _visible_choice(game, ev, forecasts)
		if choice.is_empty():
			break
		if not game.apply(_event_action(game, ev, choice)):
			break
		forecasts = game.forecasts()
		if not game.revolt_warning().is_empty():
			forecasts.append({"key": "discontent"})
	_do_soft(game)
	var retry := _retry_build(game)
	if not retry.is_empty():
		game.apply(retry)
	elif game.output_of("air") < game.air_need() and game.room_count("air_filter") < 2 and game.build_possible("air_filter"):
		game.apply({"kind": "build", "type": "air_filter"})
	elif not _build_power(game) and not _build_crowd(game) and not _ease_mood(game):
		var build := _urgent_build(game)
		if not build.is_empty():
			_do_row(game, build)
	_top_up_air(game)
	_follow_network(game)


func _top_up_air(game: Game) -> void:
	_fill_free(game, "generator", int(game.stock.power) < 30)
	_fill_free(game, "air_filter", game.output_of("air") < game.air_need())


func _fill_free(game: Game, type: String, needed: bool) -> void:
	if not needed:
		return
	var used := {}
	for room in game.rooms:
		for id in room.staff:
			used[str(id)] = true
	for room in game.rooms:
		if str(room.type) != type or bool(room.get("offline", false)) or int(room.get("disabled", 0)) > 0:
			continue
		var defin: Dictionary = game.catalog.rooms[type]
		var skill := str(defin.get("skill", ""))
		while room.staff.size() < int(defin.staff_max):
			if type == "air_filter" and game.output_of("air") >= game.air_need():
				return
			var pick := ""
			var best := -1
			for person in game.residents:
				var id := str(person.id)
				if used.has(id) or int(person.sick) > 0 or int(person.absent) > 0:
					continue
				var v := int(person.skills.get(skill, 0))
				if v > best:
					best = v
					pick = id
			if pick == "":
				return
			if not game.apply({"kind": "assign", "person": pick, "room": str(room.uid)}):
				return
			used[pick] = true


func _follow_network(game: Game) -> void:
	if game.week < 3:
		return
	if game.owned_count() >= 2 and game.deal_count() >= 1:
		return
	var sid := game.nearest_neutral()
	if sid == "":
		return
	if game.order_block("trade", sid) != "":
		return
	game.apply({"kind": "order", "order": "trade", "station": sid})


func _do_soft(game: Game) -> void:
	var warning: Dictionary = game.revolt_warning()
	if not warning.is_empty():
		for fix in warning.fixes:
			if _is_soft(fix):
				_do_row(game, fix)
	for row in game.forecasts():
		if _is_soft(row):
			_do_row(game, row)


func _urgent_build(game: Game) -> Dictionary:
	var best := {}
	var best_weeks := 99
	var warning: Dictionary = game.revolt_warning()
	if not warning.is_empty():
		for fix in warning.fixes:
			if _is_buildish(fix) and int(warning.weeks) < best_weeks:
				best = fix
				best_weeks = int(warning.weeks)
	for row in game.forecasts():
		if _is_buildish(row) and int(row.weeks) < best_weeks:
			best = row
			best_weeks = int(row.weeks)
	return best


func _build_power(game: Game) -> bool:
	if game.room_count("generator") >= 2:
		return false
	if game._weeks_until_empty("power") > 8 and not _cold_soon(game):
		return false
	_free_crew(game, int(game.bal.build_workers))
	if game.build_possible("generator"):
		return game.apply({"kind": "build", "type": "generator"})
	if game.dig_possible(true):
		return game.apply({"kind": "dig", "space": true})
	if game.dig_possible(false):
		return game.apply({"kind": "dig", "space": false})
	return false


func _free_crew(game: Game, need: int) -> void:
	var short := need - game._free_count()
	if short <= 0:
		return
	for room in game.rooms:
		if str(room.type) in ["quarters", "platform", "generator"]:
			continue
		for id in room.staff.duplicate():
			if short <= 0:
				return
			if game.apply({"kind": "unassign", "person": str(id)}):
				short -= 1


func _cold_soon(game: Game) -> bool:
	if game._season_is("cold"):
		return true
	for season in game.bal.seasons:
		if str(season.id) != "cold":
			continue
		var left := int(season.week) - game.week
		return left > 0 and left <= int(game.bal.get("season_warning", 2))
	return false


func _build_crowd(game: Game) -> bool:
	if game.housing() >= game.residents.size():
		return false
	for row in game.forecasts():
		if str(row.get("key", "")) != "overcrowd":
			continue
		return _do_row(game, row)
	return false


func _ease_mood(game: Game) -> bool:
	if game.discontent < 52 or game._weeks_until_empty("air") <= 1:
		return false
	if game.rally_reason() == "":
		return game.apply({"kind": "rally"})
	if game.room_count("meeting_hall") == 0 and game.build_possible("meeting_hall"):
		return game.apply({"kind": "build", "type": "meeting_hall"})
	if game.room_count("meeting_hall") > 0:
		game.apply({"kind": "staff"})
		if game.rally_reason() == "":
			return game.apply({"kind": "rally"})
	return false


func _is_soft(row: Dictionary) -> bool:
	var hint := str(row.get("hint", ""))
	return hint != "" and hint != "dig" and hint != "burn" and not hint.begins_with("build:")


func _is_buildish(row: Dictionary) -> bool:
	var hint := str(row.get("hint", ""))
	return hint == "dig" or hint == "burn" or hint.begins_with("build:")


func _do_row(game: Game, row: Dictionary) -> bool:
	var hint := str(row.get("hint", ""))
	if hint.begins_with("build:"):
		var type := hint.trim_prefix("build:")
		var info: Dictionary = game.build_preview(type, int(row.level), int(row.cell))
		if bool(info.ok):
			return game.apply({"kind": "build", "type": type, "level": int(row.level), "cell": int(row.cell)})
	elif hint == "dig":
		var dig: Dictionary = game.dig_preview(int(row.level), int(row.cell))
		if bool(dig.ok):
			return game.apply({"kind": "dig", "level": int(row.level), "cell": int(row.cell)})
	elif hint.begins_with("staff:"):
		return game.apply({"kind": "staff"})
	elif hint == "burn":
		if bool(game.burn_preview().ok):
			return game.apply({"kind": "burn"})
	elif hint == "rally":
		return game.apply({"kind": "rally"})
	elif hint == "quarantine":
		return game.apply({"kind": "quarantine"})
	elif hint == "pump":
		return game.apply({"kind": "pump"})
	elif hint.begins_with("law:"):
		return game.apply({"kind": "law", "law": hint.trim_prefix("law:")})
	elif hint.begins_with("repeal:"):
		return game.apply({"kind": "repeal", "law": hint.trim_prefix("repeal:")})
	return false


func _all_checks(ev: Dictionary) -> bool:
	var choices: Array = ev.get("choices", [])
	if choices.is_empty():
		return false
	for choice in choices:
		if not choice.has("check"):
			return false
	return true


func _best_check_choice(game: Game, ev: Dictionary) -> Dictionary:
	var best := {}
	var best_p := -1
	for choice in ev.choices:
		if game.choice_locked(choice) or not game.choice_offered(choice) or not game.afford_choice(choice):
			continue
		var skill := str(choice.check.get("skill", "wits"))
		var who := game.best_check_resident(skill)
		var chance := game.check_chance(skill, int(choice.check.get("difficulty", 10)), who, str(choice.check.get("color", "")))
		if chance > best_p:
			best_p = chance
			best = choice
	return best


func _visible_choice(game: Game, ev: Dictionary, forecasts: Array) -> Dictionary:
	if _all_checks(ev):
		for choice in ev.choices:
			if game.choice_locked(choice) or not game.choice_offered(choice) or not game.afford_choice(choice):
				continue
			return choice
		return {}
	var fallback := {}
	for choice in ev.choices:
		if game.choice_locked(choice) or choice.has("bet") or not game.afford_choice(choice):
			continue
		if fallback.is_empty():
			fallback = choice
		if _spends_forecast(choice, forecasts) or _hurts_meter(choice, forecasts) or _adds_mouths(choice, forecasts):
			continue
		return choice
	return fallback


func _adds_mouths(choice: Dictionary, forecasts: Array) -> bool:
	if int(choice.get("people", 0)) <= 0:
		return false
	for row in forecasts:
		if str(row.get("key", "")) == "food":
			return true
	return false


func _hurts_meter(choice: Dictionary, forecasts: Array) -> bool:
	for row in forecasts:
		var key := str(row.get("key", ""))
		if key == "discontent" and int(choice.get("discontent", 0)) > 0:
			return true
		if key == "hope" and int(choice.get("hope", 0)) < 0:
			return true
	return false


func _spends_forecast(choice: Dictionary, forecasts: Array) -> bool:
	var cost = choice.get("cost", {})
	if typeof(cost) != TYPE_DICTIONARY:
		return false
	for key in cost:
		if int(cost[key]) <= 0:
			continue
		for row in forecasts:
			if str(row.key) == str(key):
				return true
	return false


func _project(game: Game) -> Dictionary:
	if game.can_pump():
		return {"kind": "pump"}
	if profile == "expander":
		return _project_expander(game)
	var retry := _retry_build(game)
	if not retry.is_empty():
		return retry
	if game.can_quarantine() and _sick(game) >= 2:
		return {"kind": "quarantine"}
	if game.room_count("hydroponics") < 1 and game.build_possible("hydroponics"):
		return {"kind": "build", "type": "hydroponics"}
	if game.week == 2 and game.room_count("hydroponics") < 2 and game.food_buffer_weeks() < 2.4 and game.build_possible("hydroponics"):
		return {"kind": "build", "type": "hydroponics"}
	if game.week >= 3 and not _did_ration and game.can_enact("rationing") and game.food_buffer_weeks() < 2.2:
		_did_ration = true
		return {"kind": "law", "law": "rationing"}
	if game.room_count("generator") == 0 and game.build_possible("generator"):
		return {"kind": "build", "type": "generator"}
	if game.housing() < game.residents.size() and game.residents.size() < 66 and game.build_possible("quarters"):
		return {"kind": "build", "type": "quarters"}
	if game.room_count("meeting_hall") == 0 and game.build_possible("meeting_hall"):
		return {"kind": "build", "type": "meeting_hall"}
	if game.output_of("food") < game.food_need() and game.food_buffer_weeks() < 1.3 and game.room_count("hydroponics") < 2 and game.build_possible("hydroponics"):
		return {"kind": "build", "type": "hydroponics"}
	if game.output_of("air") < game.air_need() and game.build_possible("air_filter"):
		return {"kind": "build", "type": "air_filter"}
	var spare := game.housing() - game.residents.size()
	if game.residents.size() < 62 and game.build_possible("quarters") and (spare < 0 or (spare < 4 and game.food_buffer_weeks() > float(game.bal.growth_buffer))):
		return {"kind": "build", "type": "quarters"}
	if _sick(game) >= 1 and game.room_count("infirmary") == 0 and game.build_possible("infirmary"):
		return {"kind": "build", "type": "infirmary"}
	if game.week >= 16 and game.room_count("radio") == 0 and game.build_possible("radio"):
		return {"kind": "build", "type": "radio"}
	if game.build_slots() == 0 and game.dig_possible(true):
		return {"kind": "dig", "space": true}
	if game.week >= 4 and int(game.stock.materials) >= 16 and game.build_slots() > 0 and game.dig_possible(false):
		return {"kind": "dig", "space": false}
	if game.can_enact("sermons") and game.hope < 42:
		return {"kind": "law", "law": "sermons"}
	if game.can_enact("open_market") and int(game.stock.tokens) < 24 and game.discontent < 55:
		return {"kind": "law", "law": "open_market"}
	return {}


func _project_expander(game: Game) -> Dictionary:
	if game.can_quarantine():
		return {"kind": "quarantine"}
	var retry := _retry_build(game)
	if not retry.is_empty():
		return retry
	if game.room_count("generator") == 0 and game.week >= 2 and game.build_possible("generator"):
		return {"kind": "build", "type": "generator"}
	if game.output_of("air") < game.air_need() and game.build_possible("air_filter"):
		return {"kind": "build", "type": "air_filter"}
	if game.housing() < game.residents.size() and game.build_possible("quarters"):
		return {"kind": "build", "type": "quarters"}
	if game.food_buffer_weeks() < 1.4 and game.room_count("hydroponics") < 3 and game.build_possible("hydroponics"):
		return {"kind": "build", "type": "hydroponics"}
	if game.room_count("meeting_hall") == 0 and game.build_possible("meeting_hall"):
		return {"kind": "build", "type": "meeting_hall"}
	if game.output_of("food") < game.food_need() and game.build_possible("hydroponics"):
		return {"kind": "build", "type": "hydroponics"}
	if game.dig_possible(false):
		return {"kind": "dig", "space": false}
	if game.dig_possible(true):
		return {"kind": "dig", "space": true}
	return {}


func _order(game: Game) -> Dictionary:
	if profile == "expander":
		return _order_expander(game)
	for demand in game.demands:
		if bool(demand.paid):
			continue
		if int(game.stock.tokens) >= int(demand.amount) + 8:
			return {"kind": "order", "order": "pay", "demand": str(demand.id)}
	if int(game.opinions.get("directorate", 0)) <= -30 and int(game.stock.tokens) >= 36 and not bool(game.at_war.get("directorate", false)):
		return {"kind": "order", "order": "gift", "faction": "directorate"}
	if game.can_trade():
		return {"kind": "order", "order": "trade"}
	if game.owned_count() >= 2:
		if game.hope < 40:
			return {"kind": "order", "order": "address"}
		return {}
	var border := _best_border(game)
	if border != "" and int(game.stock.influence) >= int(game.bal.propaganda_influence):
		var st: Dictionary = game.stations[border]
		if not _did_aid and int(st.sympathy) >= 20 and int(st.sympathy) < 70 and _avg_need(st) < 0.55 and game.food_buffer_weeks() > 3.0:
			_did_aid = true
			return {"kind": "order", "order": "aid", "station": border}
		return {"kind": "order", "order": "propaganda", "station": border}
	var shaky := _shaky_outpost(game)
	if shaky != "" and not _did_aid and int(game.stock.food) > game.food_need() * 2:
		_did_aid = true
		return {"kind": "order", "order": "aid", "station": shaky}
	if game.week >= 18 and game.can_expedition() and int(game.stock.food) > 24 and not bool(game.at_war.get("directorate", false)):
		return {"kind": "order", "order": "expedition"}
	if game.can_approach():
		return {"kind": "order", "order": "approach"}
	for sid in game.stations:
		var held: Dictionary = game.stations[sid]
		if str(held.owner) == game.player and str(sid) != game.capital_id and str(held.focus) == "":
			return {"kind": "order", "order": "focus", "station": str(sid), "focus": _focus_for(game)}
	if game.hope < 40:
		return {"kind": "order", "order": "address"}
	return {}


func _order_expander(game: Game) -> Dictionary:
	for demand in game.demands:
		if bool(demand.paid):
			continue
		if int(game.stock.tokens) >= int(demand.amount) + 20:
			return {"kind": "order", "order": "pay", "demand": str(demand.id)}
	if game.can_trade():
		return {"kind": "order", "order": "trade"}
	if game.hope < 40 and not _did_talk:
		_did_talk = true
		return {"kind": "order", "order": "address"}
	if game.owned_count() >= 5:
		return {}
	var border := _best_border(game)
	if border != "" and int(game.stock.influence) >= int(game.bal.propaganda_influence):
		var st: Dictionary = game.stations[border]
		if not _did_aid and int(st.sympathy) >= 15 and int(st.sympathy) < 85 and _avg_need(st) < 0.75 and int(game.stock.food) >= int(game.bal.aid_food) + game.food_need():
			_did_aid = true
			return {"kind": "order", "order": "aid", "station": border}
		return {"kind": "order", "order": "propaganda", "station": border}
	for sid in game.stations:
		var held: Dictionary = game.stations[sid]
		if str(held.owner) == game.player and str(sid) != game.capital_id and str(held.focus) != "influence":
			return {"kind": "order", "order": "focus", "station": str(sid), "focus": "influence"}
	if game.can_expedition():
		return {"kind": "order", "order": "expedition"}
	if game.can_approach():
		return {"kind": "order", "order": "approach"}
	return {}


func _best_border(game: Game) -> String:
	var best := ""
	var best_score := -1
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		var owner := str(st.owner)
		if owner == game.player or owner == "bunker" or owner == "ruin" or str(st.get("bunker", "")) != "":
			continue
		if not game.borders_player(str(sid)):
			continue
		var score := game.sympathy_preview(str(sid)) + int(st.sympathy)
		if owner == "neutral":
			score += 40
		if score > best_score:
			best_score = score
			best = str(sid)
	return best


func _shaky_outpost(game: Game) -> String:
	var best := ""
	var worst := 101
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != game.player or str(sid) == game.capital_id:
			continue
		if int(st.loyalty) < worst and (int(st.loyalty) < 55 or _avg_need(st) < 0.5):
			worst = int(st.loyalty)
			best = str(sid)
	return best


func _avg_need(st: Dictionary) -> float:
	var needs: Array = st.needs
	if needs.is_empty():
		return 1.0
	var sum := 0.0
	for need in needs:
		sum += float(need.fill)
	return sum / float(needs.size())


func _focus_for(game: Game) -> String:
	if game.food_buffer_weeks() < 1.5:
		return "food"
	if int(game.stock.air) < game.air_need() * 2:
		return "air"
	return "defense"


func _event_action(game: Game, ev: Dictionary, choice: Dictionary) -> Dictionary:
	var action := {"kind": "event", "event_id": str(ev.id), "choice_id": str(choice.id)}
	if choice.has("check"):
		action.person = game.best_check_resident(str(choice.check.get("skill", "")))
	return action


func _check_ev(game: Game, choice: Dictionary) -> int:
	var skill := str(choice.check.get("skill", "wits"))
	var who := game.best_check_resident(skill)
	var chance := game.check_chance(skill, int(choice.check.get("difficulty", 10)), who, str(choice.check.get("color", "")))
	var p := float(chance) / 100.0
	var win := _effect_value(game, choice.get("success", {}))
	var lose := _effect_value(game, choice.get("failure", {}))
	var ev := int(round(p * float(win) + (1.0 - p) * float(lose)))
	var cost = choice.get("cost", {})
	if cost is Dictionary:
		ev -= int(cost.get("tokens", 0)) / 2
		ev -= int(cost.get("materials", 0))
	return ev


func _effect_value(game: Game, fx: Dictionary) -> int:
	var value := int(fx.get("hope", 0)) * 4
	value -= int(fx.get("discontent", 0)) * 3
	value += int(fx.get("air", 0))
	value += int(fx.get("materials", 0))
	value += int(fx.get("food", 0))
	value += int(fx.get("tokens", 0)) / 2
	value += int(fx.get("influence", 0))
	if fx.has("food_pct"):
		value += int(round(float(game.stock.food) * float(int(fx.food_pct)) / 100.0))
	value -= int(fx.get("injured", 0)) * 8
	value -= int(fx.get("sick", 0)) * 6
	value -= int(fx.get("residents_lost", 0)) * 30
	var shut = fx.get("room_disabled", {})
	if shut is Dictionary:
		value -= int(shut.get("weeks", 0)) * 5
	var rel = fx.get("relation", {})
	if rel is Dictionary:
		for fid in rel:
			value += int(rel[fid]) / 5
	if str(fx.get("flag", "")) != "":
		value += 6
	if fx.has("brownout"):
		value += 4 if not bool(fx.brownout) else -6
	return value


func _expander_check_choice(game: Game, ev: Dictionary) -> Dictionary:
	var cynical := {}
	var best_cyn := 0
	var risk := {}
	var best_risk := -99999
	for choice in ev.choices:
		if game.choice_locked(choice) or not game.choice_offered(choice) or not game.afford_choice(choice):
			continue
		var cyn := _cynicism(choice)
		if cyn > best_cyn:
			best_cyn = cyn
			cynical = choice
		var skill := str(choice.check.get("skill", "wits"))
		var who := game.best_check_resident(skill)
		var chance := game.check_chance(skill, int(choice.check.get("difficulty", 10)), who, str(choice.check.get("color", "")))
		var risk_score := 100 - chance
		if str(choice.check.get("color", "")) == "red":
			risk_score += 40
		if risk_score > best_risk:
			best_risk = risk_score
			risk = choice
	if best_cyn > 0:
		return cynical
	return risk


func _cynicism(choice: Dictionary) -> int:
	var fx: Dictionary = choice.get("success", {})
	var score := 0
	if int(fx.get("hope", 0)) < 0:
		score += -int(fx.hope)
	if int(fx.get("discontent", 0)) > 0:
		score += int(fx.discontent)
	if int(fx.get("sick", 0)) > 0:
		score += int(fx.sick)
	var rel = fx.get("relation", {})
	if rel is Dictionary:
		for fid in rel:
			if int(rel[fid]) < 0:
				score += -int(rel[fid]) / 5
	return score


func _retry_build(game: Game) -> Dictionary:
	for ev in game.white_pending:
		for choice in ev.choices:
			if not bool(choice.get("locked", false)) or bool(choice.get("spent", false)):
				continue
			var retry: Dictionary = choice.get("check", {}).get("retry", {})
			if retry.is_empty():
				continue
			if retry.has("level"):
				var kind := str(retry.get("room", ""))
				if game._room_built_level(kind) >= int(retry.level) or int(game.stock.materials) < 10:
					continue
				for room in game.rooms:
					if str(room.type) != kind:
						continue
					var info: Dictionary = game.upgrade_preview(str(room.uid))
					if bool(info.get("ok", false)):
						return {"kind": "upgrade", "room": str(room.uid)}
			elif retry.has("room"):
				var kind := str(retry.room)
				if game.room_count(kind) > 0 or game.food_buffer_weeks() < 1.3:
					continue
				if game.build_possible(kind):
					return {"kind": "build", "type": kind}
	return {}


func _score_choice(game: Game, choice: Dictionary) -> int:
	if choice.has("check"):
		return _check_ev(game, choice)
	if choice.has("bet"):
		return -40
	var score := int(choice.get("hope", 0)) * 3
	score -= int(choice.get("discontent", 0)) * 2
	score += int(choice.get("food", 0))
	score += int(choice.get("air", 0))
	score += int(choice.get("materials", 0))
	score += int(choice.get("power", 0)) / 2
	score += int(choice.get("tokens", 0)) / 2
	score += int(choice.get("influence", 0))
	score += int(choice.get("papers", 0)) * 4
	var people := int(choice.get("people", 0))
	if people > 0:
		if profile == "expander":
			score += 8
		else:
			var spare := game.housing() - game.residents.size()
			var new_need := Formulas.people_for(game.residents.size() + people, int(game.bal.food_per))
			var weeks := float(game.stock.food) / float(maxi(1, new_need))
			if spare >= people and weeks > float(game.bal.growth_buffer):
				score += 6
			else:
				score -= 16
	if people < 0:
		score -= 8
	score -= int(choice.get("sick", 0)) * 4
	if int(choice.get("food", 0)) > 0 and int(game.stock.food) > 36:
		score -= int(choice.food)
	var cost = choice.get("cost", {})
	if cost is Dictionary and cost.has("tokens") and int(game.stock.tokens) < 42:
		score -= 20
	if cost is Dictionary and cost.has("materials") and int(game.stock.materials) < 18:
		score -= 6
	return score


func _sick(game: Game) -> int:
	var n := 0
	for person in game.residents:
		if int(person.sick) > 0:
			n += 1
	return n
