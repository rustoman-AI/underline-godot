extends SceneTree

## Headless checks for the guard: soldiers are residents, marches need them and cost food, a faction you march
## on strikes back, and saves keep the guard.
##   godot --headless --path . -s res://sim/check_guard.gd

var catalog: Catalog
var failed := false


func _init() -> void:
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	_start()
	_recruit()
	_march()
	_strike_back()
	_saves()
	if failed:
		print("GUARD CHECK FAILED")
		quit(1)
	else:
		print("GUARD CHECK OK")
		quit(0)


func _expect(ok: bool, good: String, bad: String) -> void:
	if ok:
		print(good + ": ok")
	else:
		failed = true
		print("FAIL " + bad)


func _game() -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _staffed(game: Game, id: String) -> bool:
	for room in game.rooms:
		for sid in room.staff:
			if str(sid) == id:
				return true
	return false


func _start() -> void:
	var game := _game()
	var ids := game.soldier_ids()
	var idle := true
	for id in ids:
		if _staffed(game, id) or game._is_council(id):
			idle = false
	_expect(ids.size() == int(game.bal.guard.start) and int(game.squads[game.player].size) == ids.size() and idle
		and game.residents.size() == int(game.bal.start_pop),
		"A run starts with %d soldiers out of %d people, none on a room or the council" % [ids.size(), game.residents.size()],
		"start guard %s, squad %d, pop %d" % [ids, int(game.squads[game.player].size), game.residents.size()])


func _recruit() -> void:
	var game := _game()
	var before := game.soldier_count()
	var pick := game._recruit_pick()
	var ok := game.apply({"kind": "recruit"})
	_expect(ok and game.soldier_count() == before + 1 and not _staffed(game, pick) and game.residents.size() == int(game.bal.start_pop),
		"Recruiting takes a resident off work into the guard",
		"recruit ok=%s guard %d -> %d" % [ok, before, game.soldier_count()])
	ok = game.apply({"kind": "dismiss"})
	_expect(ok and game.soldier_count() == before, "Releasing sends a soldier back to work", "dismiss ok=%s guard %d" % [ok, game.soldier_count()])


## The capital's first neighbour, handed to the Directorate so the squad has someone to fight.
func _enemy_next_door(game: Game) -> String:
	for sid in game._neighbors(game.capital_id):
		var st: Dictionary = game.stations[sid]
		if str(st.get("bunker", "")) != "" or bool(st.get("hidden", false)):
			continue
		st.owner = "directorate"
		st.garrison = 2
		st.fort = 1.0
		st.known = true
		return str(sid)
	return ""


func _march() -> void:
	var game := _game()
	game.week = 8
	var target := _enemy_next_door(game)
	while game.soldier_count() > 2:
		game.apply({"kind": "dismiss"})
	var why := game.order_block("move", target)
	_expect(why.begins_with("Needs"), "Two soldiers cannot march on a rival (%s)" % why, "move with 2 soldiers: '%s'" % why)
	while game.soldier_count() < 6:
		game.apply({"kind": "recruit"})
	var food := int(game.stock.food)
	var cost := game.order_cost("move", target)
	var opinion := int(game.opinions.directorate)
	var ok := game.queue_order({"kind": "order", "order": "move", "dest": target})
	_expect(ok and int(cost.get("food", 0)) == 3 and int(game.stock.food) == food - 3,
		"A march of 6 soldiers costs 3 food", "queued %s cost %s food %d -> %d" % [ok, cost, food, int(game.stock.food)])
	var pop := game.residents.size()
	game._resolve_queued()
	_expect(game.soldier_count() < 6 and game.residents.size() < pop,
		"A battle kills soldiers, and they leave the station (%d left)" % game.soldier_count(),
		"after battle guard %d pop %d -> %d" % [game.soldier_count(), pop, game.residents.size()])
	_expect(game.provoked("directorate") and game._hostile_to_player("directorate") and int(game.opinions.directorate) <= opinion - 20,
		"The Directorate is provoked for %d weeks" % game.provoked_weeks("directorate"),
		"provoked %s opinion %d -> %d" % [game.provoked("directorate"), opinion, int(game.opinions.directorate)])
	var risk := game.order_risk("move", target)
	_expect(risk == "" or risk.find("soldier") >= 0, "The march risk names the soldiers", "risk '%s'" % risk)


func _strike_back() -> void:
	var game := _game()
	game.week = 8
	var outpost := ""
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if sid != game.capital_id and str(st.owner) == "neutral" and game._hops(str(game.squads.directorate.station), sid) < 999:
			st.owner = game.player
			outpost = str(sid)
			break
	_expect(game._campaign_target("directorate") != outpost or outpost == "", "A calm Directorate leaves your outpost alone", "calm target %s" % game._campaign_target("directorate"))
	game._provoke("directorate")
	_expect(outpost != "" and game._campaign_target("directorate") == outpost, "A provoked Directorate marches on your outpost", "provoked target '%s' outpost '%s'" % [game._campaign_target("directorate"), outpost])
	var raided := _game()
	raided.week = 8
	var enemy := _enemy_next_door(raided)
	raided.squads[raided.player].station = raided.capital_id
	raided.bal.guard.sortie_chance = 1.0
	raided._provoke("directorate")
	var before := raided.soldier_count()
	raided._sorties()
	_expect(enemy != "" and raided.soldier_count() < before, "Its garrison next door raids your squad (%d -> %d)" % [before, raided.soldier_count()],
		"sortie guard %d -> %d next to %s" % [before, raided.soldier_count(), enemy])
	raided.week = 8 + int(raided.bal.guard.provoke_weeks) + 1
	_expect(not raided.provoked("directorate"), "The grudge runs out", "still provoked at week %d" % raided.week)
	raided.bal.guard.sortie_chance = 0.5


func _saves() -> void:
	var game := _game()
	game.apply({"kind": "recruit"})
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var back := Game.new()
	back.catalog = catalog
	var ok := back.import_state(data)
	_expect(ok and back.soldier_ids() == game.soldier_ids() and int(back.squads[back.player].size) == game.soldier_count(),
		"A save keeps the guard", "import %s guard %s vs %s" % [ok, back.soldier_ids(), game.soldier_ids()])
	var old := _game().export_state()
	old["schema"] = Game.SAVE_SCHEMA
	old.squads[str(old.player)].erase("guard")
	for id in old.people:
		old.people[id].erase("soldier")
	var legacy := Game.new()
	legacy.catalog = catalog
	ok = legacy.import_state(old)
	_expect(ok and legacy.soldier_count() == int(catalog.balance.guard.start),
		"A save from before the guard musters the start guard", "legacy import %s guard %d" % [ok, legacy.soldier_count()])
