extends RefCounted

## State dilemmas (two_portions, breathers_price, the_list) and the three Coney recast cards.
## Each dilemma fires once, from its trigger, with a free choice and a map option. Numbers come from balance.json.
## Run alone with sim/check_dilemmas.gd; sim/audience_checks.gd runs them too, so bot_run covers them.

const IDS := ["two_portions", "breathers_price", "the_list"]
const MAP_CHOICE := {"two_portions": "pier", "breathers_price": "night", "the_list": "flushing"}

var catalog: Catalog
var lines: PackedStringArray = []
var failed := false


static func run(cat: Catalog) -> Dictionary:
	var checks = load("res://sim/dilemma_checks.gd").new()
	checks.catalog = cat
	checks._catalog()
	checks._triggers()
	checks._effects()
	checks._coney()
	return {"ok": not checks.failed, "lines": checks.lines}


func _expect(ok: bool, good: String, bad: String) -> void:
	if ok:
		lines.append(good + ": ok")
	else:
		failed = true
		lines.append("FAIL " + bad)


func _game(run_seed := 1) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	return game


func _row(id: String) -> Dictionary:
	for ev in catalog.events:
		if str(ev.get("id", "")) == id:
			return ev
	return {}


func _choice(ev: Dictionary, id: String) -> Dictionary:
	for choice in ev.get("choices", []):
		if str(choice.get("id", "")) == id:
			return choice
	return {}


func _shown(game: Game, id: String) -> bool:
	return game.pending.any(func(ev): return str(ev.get("id", "")) == id)


func _arm(game: Game) -> void:
	game.pending.clear()
	game.week_event_ids = {}


func _front(game: Game) -> Dictionary:
	if game.pending.is_empty():
		return {}
	return game.pending[0]


func _dilemma() -> Dictionary:
	var row = catalog.balance.get("dilemmas", {})
	if row is Dictionary:
		return row
	return {}


func _text(ev: Dictionary) -> String:
	var pack = ev.get("text", "")
	if pack is Dictionary:
		return str(pack.get("en", ""))
	return str(pack)


func _catalog() -> void:
	var d := _dilemma()
	var bad: PackedStringArray = []
	if int(catalog.balance.get("dilemma_cooldown", 0)) != 2:
		bad.append("cooldown")
	for key in ["workers_hope", "workers_discontent", "share_output", "share_weeks", "pier_food", "air_gain", "pay_tokens", "lend_people", "lend_weeks", "seal_deaths", "seal_hope", "open_sick", "open_synod", "flushing_count", "flushing_weeks", "flushing_synod"]:
		if not d.has(key):
			bad.append("balance " + key)
	for id in IDS:
		var ev := _row(id)
		if ev.is_empty():
			bad.append(id + " missing")
			continue
		if int(ev.get("weight", 1)) != 0:
			bad.append(id + " weight")
		if not ev.has("trigger"):
			bad.append(id + " trigger")
		var trigger: Dictionary = ev.get("trigger", {})
		if trigger.has("order"):
			bad.append(id + " order")
		var free := false
		for choice in ev.get("choices", []):
			var cost = choice.get("cost", {})
			var empty := true
			if cost is Dictionary:
				for key in cost:
					if int(cost[key]) > 0:
						empty = false
			if empty:
				free = true
		if not free:
			bad.append(id + " free choice")
		var map_id := str(MAP_CHOICE[id])
		if not bool(_choice(ev, map_id).get("map", false)):
			bad.append(id + " map option")
		if str(ev.get("banner", "")) != id or str(ev.get("tag", "")) == "":
			bad.append(id + " banner")
		if ArtPack.resolve_event_banner(ev) != id or ArtPack.resolve_event_banner(ev) == "cough":
			bad.append(id + " plate")
	var portions := _row("two_portions")
	var breathers := _row("breathers_price")
	var listing := _row("the_list")
	if int(portions.get("trigger", {}).get("food_weeks_lt", 0)) != 1:
		bad.append("food trigger")
	if int(breathers.get("trigger", {}).get("air_weeks_lt", 0)) != 1 or str(breathers.get("trigger", {}).get("station_known", "")) != "bowling":
		bad.append("air trigger")
	if str(listing.get("trigger", {}).get("season", "")) != "cough" or int(listing.get("trigger", {}).get("sick_gte", 0)) != 3:
		bad.append("cough trigger")
	if not _text(portions).contains("Dead Pier") or not _text(breathers).contains("Bowling Green") or not _text(listing).contains("Flushing"):
		bad.append("copy")
	var frame := ArtPack.dilemma_frame()
	if frame == null or frame.get_width() <= 0:
		bad.append("frame")
	_expect(bad.is_empty(), "Three dilemmas, weight 0, trigger, free choice, map option", ", ".join(bad))


func _triggers() -> void:
	var game := _game()
	game.week = 100
	game.stock.food = 0
	game.stock.air = 400
	_arm(game)
	game._roll_events()
	var once := _shown(game, "two_portions") and int(game.stats.get("dilemma_week", 0)) == 100
	var pool: Array = game._event_pool(false) + game._event_pool(true)
	var leaked := pool.any(func(ev): return ev.has("trigger") or IDS.has(str(ev.get("id", ""))))
	_arm(game)
	game.stats["dilemma_week"] = -99
	game._offer_dilemmas()
	var again := _shown(game, "two_portions")
	_expect(once and not leaked and not again, "Food crash shows Two portions once, never from the pool", "once=%s leaked=%s again=%s" % [once, leaked, again])

	game = _game()
	game.week = 100
	game.stock.food = 400
	game.stock.air = 400
	game.active_season = {"id": "cough", "start": 100, "until": 102}
	_sicken(game, 3)
	_arm(game)
	game._roll_events()
	var listed := _shown(game, "the_list")
	game.events_seen.erase("the_list")
	game.stats["dilemma_week"] = -99
	_arm(game)
	game.active_season = {}
	game._offer_dilemmas()
	var out_of_season := _shown(game, "the_list")
	_expect(listed and not out_of_season, "Cough and 3 sick show The list once", "listed=%s out=%s" % [listed, out_of_season])

	game = _game()
	game.week = 20
	game.stock.food = 400
	game.stock.air = 0
	var bowling := game._resolve_station("bowling")
	var hidden := bowling != "" and not game._event_ok(game._event_by_id("breathers_price"))
	if bowling != "":
		game.stations[bowling].known = true
	var open := bowling != "" and game._event_ok(game._event_by_id("breathers_price"))
	_expect(hidden and open, "Breathers wait until Bowling Green is known", "hidden=%s open=%s station=%s" % [hidden, open, bowling])

	game = _game()
	game.week = 100
	game.stock.food = 0
	game.stock.air = 400
	_arm(game)
	game._offer_dilemmas()
	var took := game.apply({"kind": "event", "event_id": "two_portions", "choice_id": "workers"})
	if bowling != "":
		game.stations[bowling].known = true
	game.stock.air = 0
	game.week = 101
	_arm(game)
	game._offer_dilemmas()
	var early := _shown(game, "breathers_price")
	game.week = 102
	_arm(game)
	game._offer_dilemmas()
	var later := _shown(game, "breathers_price")
	_expect(took and not early and later, "Two weeks between dilemmas", "took=%s week101=%s week102=%s" % [took, early, later])

	game = _game()
	game.week = 12
	game.stock.food = 0
	game.stock.air = 400
	game.pending = [{"id": "blocker", "major": true, "title": "Already waiting", "text": "A major card is open.", "choices": [{"id": "wait", "label": "Wait"}]}]
	game._offer_dilemmas()
	var blocked := not _shown(game, "two_portions") and game.pending.size() == 1
	_arm(game)
	game._offer_dilemmas()
	_expect(blocked and _shown(game, "two_portions"), "No dilemma while a major card is waiting", "blocked=%s then=%s" % [blocked, _shown(game, "two_portions")])

	var scene_in_pool := false
	game = _game()
	for ev in game._event_pool(false) + game._event_pool(true):
		if ev.has("trigger"):
			scene_in_pool = true
	var scene_ok := false
	for ev in catalog.events:
		var trigger = ev.get("trigger", null)
		if trigger is Dictionary and trigger.has("order") and game._event_ok(ev):
			scene_ok = true
	_expect(not scene_in_pool and not scene_ok, "Bunker scenes stay out of the pool and the dilemma gate", "pool=%s ok=%s" % [scene_in_pool, scene_ok])


func _effects() -> void:
	var d := _dilemma()
	var game := _offer_food()
	var card := _front(game)
	var workers := _choice(card, "workers")
	var before_hope := game.hope
	var before_dis := game.discontent
	var took := game.apply({"kind": "event", "event_id": "two_portions", "choice_id": "workers"})
	var chronicled := false
	for row in game.chronicle:
		if str(row.get("kind", "")) == "dilemma" and int(row.get("weight", 0)) == 3 and str(row.get("fields", {}).get("choice", "")).contains("Feed the workers"):
			chronicled = true
	_expect(took and game.hope - before_hope == int(d.workers_hope) and game.discontent - before_dis == int(d.workers_discontent) and chronicled,
		"Workers: hope and discontent from balance, chronicle weight 3",
		"hope %d dis %d chronicle %s" % [game.hope - before_hope, game.discontent - before_dis, chronicled])

	game = _offer_food()
	var before_out := game.output_of("food")
	took = game.apply({"kind": "event", "event_id": "two_portions", "choice_id": "share"})
	var cut := game.output_cut()
	var until := int(game.stats.get("share_until", 0))
	var during := game.output_of("food")
	var sample := game.share_cut(20)
	game.week = until + 1
	var after := game.output_cut()
	_expect(took and until == 8 + int(d.share_weeks) - 1 and is_equal_approx(cut, float(d.share_output)) and during < before_out and is_equal_approx(after, 1.0) and sample == int(round(20.0 * float(d.share_output))),
		"Share cuts room output for two weeks",
		"until=%d cut=%.2f food %d -> %d then %.2f" % [until, cut, before_out, during, after])

	var pier := _pier_outcome(true)
	var hurt := _pier_outcome(false)
	_expect(pier and hurt, "Pier: Grit success brings the food, failure injures Bait and closes", "success=%s failure=%s" % [pier, hurt])

	game = _offer_list()
	var pop := game.residents.size()
	before_hope = game.hope
	took = game.apply({"kind": "event", "event_id": "the_list", "choice_id": "seal"})
	var sealed := bool(game.flags.get("list_sealed", false)) and game.residents.size() == pop - int(d.seal_deaths) and game.hope - before_hope == int(d.seal_hope)
	var spread := _spread_stopped(game)
	_expect(took and sealed and spread, "Seal: one named death, hope from balance, cough does not spread", "took=%s sealed=%s spread=%s pop %d hope %d" % [took, sealed, spread, game.residents.size() - pop, game.hope - before_hope])

	game = _offer_list()
	var sick := game.sick_count()
	var synod := game.synod
	took = game.apply({"kind": "event", "event_id": "the_list", "choice_id": "open"})
	_expect(took and game.sick_count() - sick == int(d.open_sick) and game.synod - synod == int(d.open_synod),
		"Open infirmary: sick and Synod from balance", "sick %+d synod %+d" % [game.sick_count() - sick, game.synod - synod])

	_flushing()
	_lend()


func _pier_outcome(want_food: bool) -> bool:
	var food_gain := int(_dilemma().get("pier_food", 0))
	for run_seed in range(1, 41):
		var game := _offer_food(run_seed)
		if game.pending.is_empty():
			continue
		var pier := _choice(_front(game), "pier")
		if not pier.has("check"):
			return false
		if str(pier.check.get("skill", "")) != "grit" or str(pier.check.get("color", "")) != "white":
			return false
		if int(pier.get("success", {}).get("food", 0)) != food_gain or int(pier.get("failure", {}).get("injured", 0)) != int(_dilemma().get("pier_injured", 1)):
			return false
		pier.check.difficulty = 0 if want_food else 99
		var bait := game._resident_by_cast("bait")
		var before := int(game.stock.food)
		if not game.apply({"kind": "event", "event_id": "two_portions", "choice_id": "pier", "person": bait}):
			continue
		var gained := int(game.stock.food) - before
		var injured := false
		if bait != "" and game.people.has(bait):
			injured = int(game.people[bait].get("absent", 0)) >= 2
		if want_food and gained == food_gain and game.pending.is_empty():
			return true
		if not want_food and gained == 0 and injured and game.pending.is_empty() and game.white_pending.is_empty():
			return true
	return false


func _spread_stopped(game: Game) -> bool:
	var pair := _sick_pair(game)
	if pair.is_empty():
		return false
	var was := float(game.bal.cough_spread)
	game.bal.cough_spread = 1.0
	game.people[pair[0]].sick = 2
	game.people[pair[1]].sick = 0
	game.flags["list_sealed"] = true
	game._spread_cough()
	var held := int(game.people[pair[1]].sick) == 0
	game.flags.erase("list_sealed")
	game._spread_cough()
	var moved := int(game.people[pair[1]].sick) > 0
	game.bal.cough_spread = was
	return held and moved


func _sick_pair(game: Game) -> Array:
	for room in game.rooms:
		if room.staff.size() >= 2:
			return [str(room.staff[0]), str(room.staff[1])]
	var ids: Array = []
	for room in game.rooms:
		for id in room.staff:
			ids.append(str(id))
			if ids.size() >= 2:
				return ids
	return []


func _flushing() -> void:
	var d := _dilemma()
	var game := _offer_list()
	var locked := _choice(_front(game), "flushing")
	var closed := bool(locked.get("locked", false)) and str(game.lock_reason(locked)).contains("Flushing")
	var sid := game._flushing_id()
	if sid != "":
		game.stations[sid].passage = true
	game.events_seen.erase("the_list")
	game.stats["dilemma_week"] = -99
	_arm(game)
	game._offer_dilemmas()
	var opened := not bool(_choice(_front(game), "flushing").get("locked", false))
	_sicken(game, int(d.flushing_count))
	var sent: Array = []
	for person in game.residents:
		if int(person.sick) > 0:
			sent.append(str(person.id))
	var took := game.apply({"kind": "event", "event_id": "the_list", "choice_id": "flushing"})
	var away := 0
	for id in sent:
		if game.people.has(str(id)) and int(game.people[str(id)].get("flushing_back", 0)) > 0:
			away += 1
	game.synod = int(d.flushing_synod)
	for _i in int(d.flushing_weeks):
		game._tick_sickness()
	var healed := true
	for id in sent:
		if game.people.has(str(id)) and int(game.people[str(id)].sick) > 0:
			healed = false
	_expect(closed and opened and took and away == int(d.flushing_count) and healed,
		"Flushing needs passage, then sends the sick home healed when the Synod answers",
		"closed=%s opened=%s took=%s away=%d healed=%s" % [closed, opened, took, away, healed])

	game = _offer_list()
	if sid != "":
		game.stations[sid].passage = true
	game.events_seen.erase("the_list")
	game.stats["dilemma_week"] = -99
	_arm(game)
	game._offer_dilemmas()
	_sicken(game, int(d.flushing_count))
	took = game.apply({"kind": "event", "event_id": "the_list", "choice_id": "flushing"})
	game.synod = 0
	for _i in int(d.flushing_weeks):
		game._tick_sickness()
	var line := false
	for entry in game.log:
		if str(entry.get("text", "")).contains("Synod did not answer"):
			line = true
	var still := 0
	for person in game.residents:
		if int(person.sick) > 0:
			still += 1
	_expect(took and line and still >= 1, "Flushing sends them back no better when the Synod is silent", "took=%s line=%s still=%d" % [took, line, still])


func _lend() -> void:
	var d := _dilemma()
	var game := _game()
	game.week = 20
	game.stock.food = 400
	game.stock.air = 0
	var bowling := game._resolve_station("bowling")
	if bowling != "":
		game.stations[bowling].known = true
	_arm(game)
	game._offer_dilemmas()
	var before := int(game.stock.air)
	var took := game.apply({"kind": "event", "event_id": "breathers_price", "choice_id": "lend"})
	var away := 0
	for person in game.residents:
		if bool(person.get("lent", false)) and int(person.absent) >= int(d.lend_weeks):
			away += 1
	var night := _choice(_row("breathers_price"), "night")
	_expect(took and int(game.stock.air) - before == int(d.air_gain) and away == int(d.lend_people) and bool(night.get("map", false)),
		"Lend: air from balance and two residents away for four weeks",
		"took=%s air %+d away=%d" % [took, int(game.stock.air) - before, away])

	game = _game()
	game.week = 8
	game.stock.food = 400
	game.stock.air = 0
	if bowling != "":
		game.stations[bowling].known = true
	_arm(game)
	game._offer_dilemmas()
	var card := _front(game)
	var pay := _choice(card, "pay")
	var steal := _choice(card, "night")
	var priced := int(pay.get("cost", {}).get("tokens", 0)) == int(d.pay_tokens) and int(pay.get("air", 0)) == int(d.air_gain)
	var red := str(steal.get("check", {}).get("skill", "")) == "senses" and str(steal.get("check", {}).get("color", "")) == "red"
	var drop := int(steal.get("failure", {}).get("opinion_exchange", 0)) == int(d.get("steal_opinion", 0))
	_expect(priced and red and drop and int(steal.get("success", {}).get("air", 0)) == int(d.air_gain),
		"Pay and the night steal read their numbers from balance", "pay=%s red=%s drop=%s" % [priced, red, drop])


func _offer_food(run_seed := 1) -> Game:
	var game := _game(run_seed)
	game.week = 8
	game.stock.food = 0
	game.stock.air = 400
	_arm(game)
	game._offer_dilemmas()
	return game


func _offer_list() -> Game:
	var game := _game()
	game.week = 30
	game.stock.food = 400
	game.stock.air = 400
	game.active_season = {"id": "cough", "start": 30, "until": 32}
	_sicken(game, 3)
	_arm(game)
	game._offer_dilemmas()
	return game


func _sicken(game: Game, n: int) -> void:
	var left := n
	for person in game.residents:
		person.sick = 0
	for person in game.residents:
		if left <= 0:
			break
		if game._is_child(person):
			continue
		person.sick = 3
		left -= 1


func _coney() -> void:
	var want := {
		"stores_turn": ["hunger", "Bait opens the food store"],
		"diesel": ["dark", "Salty Maggie knocks"],
		"ration_coat": ["cough", "Old Man Coney caught Barnum"],
	}
	var bad: PackedStringArray = []
	var game := _game()
	game.week = 10
	for id in want:
		var ev := _row(id)
		if ev.is_empty():
			bad.append(id + " missing")
			continue
		if str(ev.get("banner", "")) != str(want[id][0]) or str(ev.get("tag", "")) != str(want[id][0]):
			bad.append(id + " banner")
		if ev.has("trigger") or int(ev.get("weight", 0)) <= 0 or not bool(ev.get("sasha", false)):
			bad.append(id + " pool row")
		if not _text(ev).contains(str(want[id][1])):
			bad.append(id + " copy")
		var pack = ev.get("text", {})
		if not (pack is Dictionary) or str(pack.get("ru", "")) == "":
			bad.append(id + " ru")
		if not game._event_ok(ev):
			bad.append(id + " not drawable")
	_expect(bad.is_empty(), "Coney recast: stores, diesel, ration coat, with banners", ", ".join(bad))
