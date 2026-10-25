extends SceneTree

## Headless gate for Push a Room (DEC-P1…P3).
##   godot --headless --path . -s res://sim/check_push.gd
##   godot --headless --path . -s res://sim/check_push.gd -- --losses


func _init() -> void:
	Copy.set_lang("en")
	var losses := false
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--losses":
			losses = true
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("PUSH FAIL catalog ", catalog.error)
		quit(1)
		return
	var failed := false
	if not _check_keys(catalog):
		failed = true
	if not _check_strings():
		failed = true
	if not _check_double(catalog):
		failed = true
	if not _check_preview(catalog):
		failed = true
	if not _check_incidents(catalog):
		failed = true
	if not _check_bot(catalog):
		failed = true
	if losses and not _check_losses(catalog):
		failed = true
	if failed:
		print("PUSH FAIL")
		quit(1)
		return
	print("PUSH OK")
	quit(0)


func _check_keys(catalog: Catalog) -> bool:
	var found: Array = []
	for key in catalog.balance.keys():
		if str(key).begins_with("push_"):
			found.append(str(key))
	found.sort()
	var want: Array = ["push_cap", "push_mult", "push_risk", "push_stack"]
	if found != want:
		print("Keys: FAIL push_* ", found)
		return false
	var bal: Dictionary = catalog.balance
	if not is_equal_approx(float(bal.push_mult), 2.0) or not is_equal_approx(float(bal.push_risk), 0.15):
		print("Keys: FAIL mult/risk")
		return false
	if not is_equal_approx(float(bal.push_stack), 0.10) or not is_equal_approx(float(bal.push_cap), 0.55):
		print("Keys: FAIL stack/cap")
		return false
	print("Keys: ok")
	return true


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("push.button") != "Push" or Copy.t("Push") != "Push":
		print("Strings: FAIL en button ", Copy.t("push.button"), " / ", Copy.t("Push"))
		return false
	if Copy.t("push.tip_ok") != "Double tonight's output. Incident risk ~%d%%.":
		print("Strings: FAIL en tip")
		return false
	Copy.set_lang("ru")
	if Copy.t("push.button") != "Нажать" or Copy.t("Push") != "Нажать":
		print("Strings: FAIL ru button ", Copy.t("push.button"), " / ", Copy.t("Push"))
		return false
	var pairs := {
		"push.disabled_room": "Эту комнату нажимать нельзя.",
		"push.disabled_used": "На этой неделе уже нажимали.",
		"push.confirm_title": "Нажать эту комнату?",
		"push.incident.hydroponics": "Гидропоника: гниль. −4 еды.",
		"push.incident.air_filter": "Воздушный фильтр: пожар у створки. Комната выключена на неделю, 1 ранен.",
		"push.incident.generator": "Генератор: выброс. −8 энергии, 1 ранен.",
		"push.incident.workshop": "Мастерская: авария. 1 ранен.",
		"push.incident.meeting_hall": "Зал собраний: крик. Недовольство +4.",
		"push.incident.generic": "Нажим сорвался. Что-то сломалось.",
		"push.incident_known": "{name} пострадал{a}.",
		"push.toast_ok": "{room}: нажали. Ночной выход удвоится.",
	}
	for key in pairs:
		if Copy.t(str(key)) != str(pairs[key]):
			print("Strings: FAIL %s -> %s" % [key, Copy.t(str(key))])
			Copy.set_lang("en")
			return false
		var en: String = str(Copy.keys[key].en)
		if Copy.t(en) != str(pairs[key]):
			print("Strings: FAIL ru.json %s" % en)
			Copy.set_lang("en")
			return false
	Copy.set_lang("en")
	var dawn := FileAccess.get_file_as_string("res://ui/station.gd")
	if not dawn.contains("\"PUSH\""):
		print("Strings: FAIL dawn does not read PUSH")
		return false
	print("Strings: ok")
	return true


func _room_of(game: Game, type: String):
	for room in game.rooms:
		if str(room.type) == type:
			return room
	return null


func _check_double(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 3, 40)
	if game.over == "error":
		print("Double: FAIL setup ", game.errors)
		return false
	var hydro = _room_of(game, "hydroponics")
	var uid := str(hydro.uid)
	var before: Dictionary = game._tally()
	if int(before.food) <= 0:
		print("Double: FAIL hydro makes no food")
		return false
	var shown: Dictionary = game.push_preview(uid)
	if not bool(shown.ok) or int(shown.pct) != game._push_pct(hydro):
		print("Double: FAIL preview ", shown)
		return false
	if not game.apply({"kind": "push", "room": uid}):
		print("Double: FAIL push refused")
		return false
	if game._push_pct(hydro) != int(shown.pct):
		print("Double: FAIL night percent %d != preview %d" % [game._push_pct(hydro), int(shown.pct)])
		return false
	var after: Dictionary = game._tally()
	if int(after.food) != int(before.food) * 2:
		print("Double: FAIL food %d -> %d" % [int(before.food), int(after.food)])
		return false
	if int(after.air) != int(before.air) or int(after.power) != int(before.power) or int(after.materials) != int(before.materials):
		print("Double: FAIL other goods moved")
		return false
	if game.apply({"kind": "push", "room": uid}):
		print("Double: FAIL second push accepted")
		return false
	var again: Dictionary = game.push_preview(uid)
	if bool(again.ok) or str(again.reason) != Copy.t("push.disabled_used"):
		print("Double: FAIL used reason ", again)
		return false
	if int(game._tally().food) != int(after.food):
		print("Double: FAIL second tally changed food")
		return false
	for type in ["quarters", "infirmary", "radio"]:
		var blocked := _spare(game, type)
		var info: Dictionary = game.push_preview(str(blocked.uid))
		if bool(info.ok) or str(info.reason) != Copy.t("push.disabled_room"):
			print("Double: FAIL %s pushable " % type, info)
			return false
	game.week += 1
	var next: Dictionary = game.push_preview(uid)
	if not bool(next.ok) or int(next.pct) != 25:
		print("Double: FAIL next week %s" % str(next))
		return false
	print("Double: ok")
	return true


func _spare(game: Game, type: String) -> Dictionary:
	var found = _room_of(game, type)
	if found != null:
		return found
	var room := {
		"uid": "push_test_%s" % type, "type": type, "level": 2, "cell": 5,
		"upgrade": 0, "efficiency": 1.0, "staff": [], "offline": false, "browned": false,
		"disabled": 0, "switched_off": false, "push_weeks": [], "push_tint_until": 0,
	}
	game.rooms.append(room)
	return room


func _expect_pct(priors: int, covered: bool) -> int:
	var p := 0.15 + 0.10 * float(priors)
	p = minf(p, 0.55)
	if covered:
		p *= 0.5
	return int(round(p * 100.0))


func _check_preview(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	var hydro = _room_of(game, "hydroponics")
	var uid := str(hydro.uid)
	game.week = 10
	if int(game.push_preview(uid).pct) != _expect_pct(0, false):
		print("Preview: FAIL base ", game.push_preview(uid))
		return false
	hydro.push_weeks = [6, 7, 8, 9]
	if int(game.push_preview(uid).pct) != _expect_pct(4, false):
		print("Preview: FAIL cap ", game.push_preview(uid).pct)
		return false
	hydro.push_weeks = [5, 7, 8, 9]
	if int(game.push_preview(uid).pct) != _expect_pct(3, false):
		print("Preview: FAIL window ", game.push_preview(uid).pct, " want ", _expect_pct(3, false))
		return false
	hydro.push_weeks = [9, 9, 8]
	if int(game.push_preview(uid).pct) != _expect_pct(2, false):
		print("Preview: FAIL duplicates ", game.push_preview(uid).pct)
		return false
	hydro.push_weeks = []
	var staff_id := str(hydro.staff[0])
	game.people[staff_id].skills.care = 4
	if int(game.push_preview(uid).pct) != _expect_pct(0, true):
		print("Preview: FAIL half ", game.push_preview(uid).pct, " want ", _expect_pct(0, true))
		return false
	game.people[staff_id].skills.care = 1
	game.people[staff_id].skills.fight = 4
	if int(game.push_preview(uid).pct) != _expect_pct(0, true):
		print("Preview: FAIL fight half")
		return false
	game.people[staff_id].absent = 2
	if int(game.push_preview(uid).pct) != _expect_pct(0, false):
		print("Preview: FAIL absent still halves")
		return false
	game.people[staff_id].absent = 0
	game.people[staff_id].skills.fight = 1
	game.bal = game.bal.duplicate(true)
	game.bal.push_risk = 0.0
	game.bal.push_stack = 0.0
	var misses := 0
	for _i in 30:
		if game._push_hits(hydro):
			misses += 1
	if misses != 0:
		print("Preview: FAIL zero chance hit")
		return false
	game.bal.push_risk = 1.0
	game.bal.push_cap = 1.0
	var hits := 0
	for _j in 30:
		if game._push_hits(hydro):
			hits += 1
	if hits != 30:
		print("Preview: FAIL certain chance missed")
		return false
	print("Preview: ok")
	return true


func _own_bal(game: Game) -> void:
	game.bal = game.bal.duplicate(true)
	## Covered staff halve the chance. 2.0 stays a certain hit after that halving.
	game.bal.push_risk = 2.0
	game.bal.push_cap = 2.0
	game.bal.push_stack = 0.0


func _pushed_line(game: Game, bit: String) -> bool:
	for entry in game.log:
		if bool(entry.important) and str(entry.text).begins_with("PUSH ") and str(entry.text).findn(bit) >= 0:
			return true
	return false


func _absent(game: Game) -> int:
	var n := 0
	for person in game.residents:
		if int(person.get("absent", 0)) > 0:
			n += 1
	return n


func _check_incidents(catalog: Catalog) -> bool:
	if not _incident_food(catalog):
		return false
	if not _incident_air(catalog):
		return false
	if not _incident_power(catalog):
		return false
	if not _incident_shop(catalog):
		return false
	if not _incident_hall(catalog):
		return false
	if not _incident_generic(catalog):
		return false
	print("Incidents: ok")
	return true


func _incident_food(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var hydro = _room_of(game, "hydroponics")
	game.stock.food = 20
	if not game.apply({"kind": "push", "room": str(hydro.uid)}):
		print("Incidents: FAIL push hydro")
		return false
	game._resolve_pushes()
	if int(game.stock.food) != 16 or not _pushed_line(game, "rot"):
		print("Incidents: FAIL rot food %d" % int(game.stock.food))
		return false
	if int(hydro.push_tint_until) != game.week + 1:
		print("Incidents: FAIL tint")
		return false
	game._resolve_pushes()
	if int(game.stock.food) != 16:
		print("Incidents: FAIL rot rolled twice")
		return false
	return true


func _incident_air(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var room = _room_of(game, "air_filter")
	var open_air := int(game._tally().air)
	var absent_before := _absent(game)
	if not game.apply({"kind": "push", "room": str(room.uid)}):
		print("Incidents: FAIL push air")
		return false
	game._resolve_pushes()
	if int(room.disabled) != 1 or _absent(game) != absent_before + 1 or not _pushed_line(game, "gate fire"):
		print("Incidents: FAIL air disabled %s absent %d" % [str(room.disabled), _absent(game)])
		return false
	if int(game._tally().air) >= open_air:
		print("Incidents: FAIL air still running")
		return false
	return true


func _incident_power(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var room = _room_of(game, "generator")
	game.stock.power = 30
	var absent_before := _absent(game)
	if not game.apply({"kind": "push", "room": str(room.uid)}):
		print("Incidents: FAIL push generator")
		return false
	game._resolve_pushes()
	if int(game.stock.power) != 22 or _absent(game) != absent_before + 1 or not _pushed_line(game, "blowout"):
		print("Incidents: FAIL power %d" % int(game.stock.power))
		return false
	return true


func _incident_shop(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var room = _room_of(game, "workshop")
	var food := int(game.stock.food)
	var power := int(game.stock.power)
	var absent_before := _absent(game)
	if not game.apply({"kind": "push", "room": str(room.uid)}):
		print("Incidents: FAIL push workshop")
		return false
	game._resolve_pushes()
	if _absent(game) != absent_before + 1 or int(game.stock.food) != food or int(game.stock.power) != power:
		print("Incidents: FAIL workshop side effects absent %d->%d food %d->%d power %d->%d staff %s" % [absent_before, _absent(game), food, int(game.stock.food), power, int(game.stock.power), str(room.staff)])
		return false
	if not _pushed_line(game, "accident"):
		print("Incidents: FAIL workshop line")
		return false
	return true


func _incident_hall(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var hall := _spare(game, "meeting_hall")
	var before := game.discontent
	if not game.apply({"kind": "push", "room": str(hall.uid)}):
		print("Incidents: FAIL push hall")
		return false
	game._resolve_pushes()
	if game.discontent != before + 4 or not _pushed_line(game, "shouting"):
		print("Incidents: FAIL discontent %d -> %d" % [before, game.discontent])
		return false
	return true


func _incident_generic(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var room = _room_of(game, "platform")
	var food := int(game.stock.food)
	var power := int(game.stock.power)
	var dis := game.discontent
	if not game.apply({"kind": "push", "room": str(room.uid)}):
		print("Incidents: FAIL push platform")
		return false
	game._resolve_pushes()
	if int(game.stock.food) != food or int(game.stock.power) != power or game.discontent != dis:
		print("Incidents: FAIL generic changed stocks")
		return false
	if not _pushed_line(game, "went wrong"):
		print("Incidents: FAIL generic line")
		return false
	return true


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 8, 40)
	_own_bal(game)
	return game


func _check_bot(catalog: Catalog) -> bool:
	var follower_game := Game.new()
	follower_game.setup(catalog, 2, 40)
	follower_game.stock.food = 0
	var follower := Bot.new()
	follower.profile = "follower"
	follower._maybe_push(follower_game)
	var did := false
	for room in follower_game.rooms:
		if str(room.type) == "hydroponics" and follower_game.room_pushed(room):
			did = true
	if not did:
		print("Bot: FAIL follower did not push hydroponics")
		return false
	var careful_game := Game.new()
	careful_game.setup(catalog, 2, 40)
	careful_game.stock.food = 0
	var careful := Bot.new()
	careful.profile = "careful"
	careful._act(careful_game)
	for room in careful_game.rooms:
		if careful_game.room_pushed(room):
			print("Bot: FAIL careful pushed %s" % str(room.type))
			return false
	print("Bot: ok")
	return true


func _check_losses(catalog: Catalog) -> bool:
	var lost := 0
	var first := 99
	var pushes := 0
	for run_seed in range(1, 61):
		var bot := Bot.new()
		bot.profile = "careful"
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = true
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		for room in game.rooms:
			pushes += int(room.get("push_weeks", []).size())
		if game.over != "time":
			lost += 1
			first = mini(first, game.week)
		if run_seed % 15 == 0:
			print("  careful seed %d, lost %d" % [run_seed, lost])
	var share := 100.0 * float(lost) / 60.0
	print("Careful lost %d of 60 (%.1f%%), first loss %s, pushes %d" % [lost, share, str(first) if lost > 0 else "none", pushes])
	if pushes != 0:
		print("Losses: FAIL careful pushed")
		return false
	if share > 35.0:
		print("Losses: FAIL careful above 35%% — lower push_stack to 0.08 and re-sim")
		return false
	if share < 15.0:
		print("Losses: careful under 15%% with zero pushes, same corridor as a run that never pushes. Stack stays %.2f" % float(catalog.balance.push_stack))
	print("Losses: ok")
	return true
