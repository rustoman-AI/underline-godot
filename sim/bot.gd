class_name Bot
extends RefCounted

## Two stewards. Careful keeps a reserve. Expander takes every station and spends the reserve.

var profile := "careful"
var _did_aid := false


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
	if profile == "follower":
		_follow(game)
		return
	_did_aid = false
	var guard := 0
	while not game.pending.is_empty() and guard < 6:
		guard += 1
		var ev: Dictionary = game.pending[0]
		var best: Dictionary = {}
		var best_score := -99999
		for choice in ev.choices:
			if not game.afford_choice(choice):
				continue
			var score := _score_choice(game, choice)
			if score > best_score:
				best_score = score
				best = choice
		if best.is_empty():
			break
		if not game.apply({"kind": "event", "event_id": ev.id, "choice_id": best.id}):
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


func _follow(game: Game) -> void:
	var forecasts: Array = game.forecasts()
	var guard := 0
	while not game.pending.is_empty() and guard < 6:
		guard += 1
		var ev: Dictionary = game.pending[0]
		var choice := _visible_choice(game, ev, forecasts)
		if choice.is_empty():
			break
		if not game.apply({"kind": "event", "event_id": ev.id, "choice_id": choice.id}):
			break
		forecasts = game.forecasts()
	if forecasts.is_empty():
		return
	var row: Dictionary = forecasts[0]
	var hint := str(row.hint)
	if hint.begins_with("build:"):
		var type := hint.trim_prefix("build:")
		var info: Dictionary = game.build_preview(type, int(row.level), int(row.cell))
		if bool(info.ok):
			game.apply({"kind": "build", "type": type, "level": int(row.level), "cell": int(row.cell)})
	elif hint == "dig":
		var dig: Dictionary = game.dig_preview(int(row.level), int(row.cell))
		if bool(dig.ok):
			game.apply({"kind": "dig", "level": int(row.level), "cell": int(row.cell)})
	elif hint.begins_with("staff:"):
		game.apply({"kind": "staff"})
	elif hint == "burn":
		if bool(game.burn_preview().ok):
			game.apply({"kind": "burn"})


func _visible_choice(game: Game, ev: Dictionary, forecasts: Array) -> Dictionary:
	var fallback := {}
	for choice in ev.choices:
		if not game.afford_choice(choice):
			continue
		if fallback.is_empty():
			fallback = choice
		if _spends_forecast(choice, forecasts):
			continue
		return choice
	return fallback


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
	if game.can_quarantine() and _sick(game) >= 2:
		return {"kind": "quarantine"}
	if game.room_count("generator") == 0 and game.build_possible("generator"):
		return {"kind": "build", "type": "generator"}
	if game.housing() < game.residents.size() and game.build_possible("quarters"):
		return {"kind": "build", "type": "quarters"}
	if game.room_count("hydroponics") < 2 and game.food_buffer_weeks() < 2.0 and game.build_possible("hydroponics"):
		return {"kind": "build", "type": "hydroponics"}
	if game.room_count("meeting_hall") == 0 and game.build_possible("meeting_hall"):
		return {"kind": "build", "type": "meeting_hall"}
	if game.output_of("food") < game.food_need() and game.build_possible("hydroponics"):
		return {"kind": "build", "type": "hydroponics"}
	if game.output_of("air") < game.air_need() and game.build_possible("air_filter"):
		return {"kind": "build", "type": "air_filter"}
	var spare := game.housing() - game.residents.size()
	if game.build_possible("quarters") and (spare < 0 or (spare < 8 and game.food_buffer_weeks() > float(game.bal.growth_buffer))):
		return {"kind": "build", "type": "quarters"}
	if _sick(game) >= 1 and game.room_count("infirmary") == 0 and game.build_possible("infirmary"):
		return {"kind": "build", "type": "infirmary"}
	if game.week >= 16 and game.room_count("radio") == 0 and game.build_possible("radio"):
		return {"kind": "build", "type": "radio"}
	if game.build_slots() == 0 and game.dig_possible(true):
		return {"kind": "dig", "space": true}
	if game.week >= 4 and int(game.stock.materials) >= 16 and game.build_slots() > 0 and game.dig_possible(false):
		return {"kind": "dig", "space": false}
	if game.can_enact("rationing") and int(game.stock.food) < game.food_need() * 3:
		return {"kind": "law", "law": "rationing"}
	if game.can_enact("sermons") and game.hope < 42:
		return {"kind": "law", "law": "sermons"}
	if game.can_enact("open_market") and int(game.stock.tokens) < 24 and game.discontent < 55:
		return {"kind": "law", "law": "open_market"}
	return {}


func _project_expander(game: Game) -> Dictionary:
	if game.room_count("generator") == 0 and game.week >= 2 and game.build_possible("generator"):
		return {"kind": "build", "type": "generator"}
	if game.room_count("meeting_hall") == 0 and game.build_possible("meeting_hall"):
		return {"kind": "build", "type": "meeting_hall"}
	if game.discontent >= 55 and game.housing() < game.residents.size() and game.build_possible("quarters"):
		return {"kind": "build", "type": "quarters"}
	if game.output_of("food") < game.food_need() and game.build_possible("hydroponics"):
		return {"kind": "build", "type": "hydroponics"}
	if game.output_of("air") < game.air_need() and game.build_possible("air_filter"):
		return {"kind": "build", "type": "air_filter"}
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
	var border := _best_border(game)
	if border != "" and int(game.stock.influence) >= int(game.bal.propaganda_influence):
		var st: Dictionary = game.stations[border]
		if not _did_aid and int(st.sympathy) >= 20 and int(st.sympathy) < 70 and _avg_need(st) < 0.55 and int(game.stock.food) > game.food_need() * 2:
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
		if int(game.stock.tokens) >= int(demand.amount) + 40:
			return {"kind": "order", "order": "pay", "demand": str(demand.id)}
	if game.can_trade():
		return {"kind": "order", "order": "trade"}
	var border := _best_border(game)
	if border != "" and int(game.stock.influence) >= int(game.bal.propaganda_influence):
		var st: Dictionary = game.stations[border]
		if not _did_aid and int(st.sympathy) >= 15 and int(st.sympathy) < 85 and _avg_need(st) < 0.75 and int(game.stock.food) >= int(game.bal.aid_food):
			_did_aid = true
			return {"kind": "order", "order": "aid", "station": border}
		return {"kind": "order", "order": "propaganda", "station": border}
	for sid in game.stations:
		var held: Dictionary = game.stations[sid]
		if str(held.owner) == game.player and str(sid) != game.capital_id and str(held.focus) == "":
			return {"kind": "order", "order": "focus", "station": str(sid), "focus": "food"}
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
	if int(game.stock.food) < game.food_need() * 3:
		return "food"
	if int(game.stock.air) < game.air_need() * 3:
		return "air"
	if int(game.stock.influence) < 8:
		return "influence"
	return "food"


func _score_choice(game: Game, choice: Dictionary) -> int:
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
