extends SceneTree

## P43 homecoming gate. Leave and return queues one dawn chip; a wipe or a party that
## never left does not. Rumor, border and rail flags outrank it. No balance drift.
##   godot --headless --path . -s res://sim/check_homecoming.gd

var failed := false


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_strings():
		failed = true
	if not _check_never_left(catalog):
		failed = true
	if not _check_return(catalog):
		failed = true
	if not _check_walk_back(catalog):
		failed = true
	if not _check_queued(catalog):
		failed = true
	if not _check_wipe(catalog):
		failed = true
	if not _check_unknown(catalog):
		failed = true
	if not _check_priority(catalog):
		failed = true
	if not _check_save(catalog):
		failed = true
	if not _check_drift(catalog):
		failed = true
	_check_icon()
	if failed:
		print("HOMECOMING FAIL")
		quit(1)
		return
	print("HOMECOMING OK")
	quit(0)


func _expect(ok: bool, good: String, bad: String) -> bool:
	if ok:
		print(good + ": ok")
		return true
	failed = true
	print("FAIL " + bad)
	return false


func _game(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _neighbor(game: Game) -> String:
	for sid in game._neighbors(game.capital_id):
		var st: Dictionary = game.stations[sid]
		if str(st.owner) == "neutral":
			return str(sid)
	return ""


func _meters(game: Game) -> Dictionary:
	return {
		"hope": game.hope,
		"dis": game.discontent,
		"food": int(game.stock.food),
		"mat": int(game.stock.materials),
		"inf": int(game.stock.influence),
		"pop": game.residents.size(),
		"rng": game.rng.state,
		"net": game.net_rng.state,
	}


func _check_strings() -> bool:
	var want := {
		"home.back": ["Party home · from {station}", "Отряд дома · с {station}"],
		"home.back_unknown": ["Party home · from the line", "Отряд дома · с линии"],
		"home.first": ["Boots on the home platform.", "Ботинки на домашней платформе."],
		"home.tip": ["Your party is back at Coney.", "Ваш отряд снова на Кони."],
		"home.chip_label": ["Homecoming", "Возвращение"],
		"home.reduce": ["Party home.", "Отряд дома."],
	}
	Copy.set_lang("en")
	for key in want:
		if Copy.t(key) != str(want[key][0]):
			print("Strings: FAIL en %s -> %s" % [key, Copy.t(key)])
			return false
	var filled := Copy.fill("home.back", {"station": "Sisters of the Garden"})
	if filled != "Party home · from Sisters of the Garden":
		print("Strings: FAIL fill ", filled)
		return false
	Copy.set_lang("ru")
	for key in want:
		if Copy.t(key) != str(want[key][1]):
			print("Strings: FAIL ru %s -> %s" % [key, Copy.t(key)])
			return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_never_left(catalog: Catalog) -> bool:
	var game := _game(catalog)
	if game.over == "error":
		print("Never-left: FAIL setup")
		return false
	var quiet := game.home_chip_line(false) == "" and not bool(game.flags.get("heard_home", false))
	game.end_week()
	quiet = quiet and game.home_chip_line(false) == "" and not bool(game.flags.get("home_left", false))
	quiet = quiet and not bool(game.flags.get("heard_home", false))
	return _expect(quiet, "Never left home", "chip or heard_home on a party that stayed")


func _check_return(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Return: FAIL no neighbour")
		return false
	var place := game.station_text(sid, "community")
	var before := _meters(game)
	if not game._order_patrol(sid):
		print("Return: FAIL patrol out ", game._patrol_gate(sid))
		return false
	if str(game.squads[game.player].station) == game.capital_id:
		print("Return: FAIL still home")
		return false
	if game.home_chip_line(false) != "":
		print("Return: FAIL chip while away")
		return false
	if not game._order_patrol(game.capital_id):
		print("Return: FAIL patrol home ", game._patrol_gate(game.capital_id))
		return false
	if str(game.squads[game.player].station) != game.capital_id:
		print("Return: FAIL did not step home")
		return false
	game._offer_home_chip()
	var line := game.home_chip_line(false)
	var want := "Party home · from %s" % place
	if line != want:
		print("Return: FAIL line ", line, " want ", want)
		return false
	if game.home_chip_line(true) != "Party home.":
		print("Return: FAIL reduce ", game.home_chip_line(true))
		return false
	if not bool(game.flags.get("heard_home", false)) or not bool(game.flags.get("home_float", false)):
		print("Return: FAIL first float flag")
		return false
	## A second offer the same dawn does not stack another chip.
	game._offer_home_chip()
	if game.home_chip_line(false) != want or bool(game.flags.get("home_pending", false)):
		print("Return: FAIL stacked")
		return false
	## Second homecoming: chip only.
	game.flags["home_float"] = false
	if not game._order_patrol(sid) or not game._order_patrol(game.capital_id):
		print("Return: FAIL second trip")
		return false
	game.week += 1
	game._offer_home_chip()
	if game.home_chip_line(false) != want or bool(game.flags.get("home_float", false)) or not bool(game.flags.get("heard_home", false)):
		print("Return: FAIL second float ", game.home_chip_line(false), " ", game.flags.get("home_float", false))
		return false
	var after := _meters(game)
	if after != before:
		print("Return: FAIL meters moved ", before, " -> ", after)
		return false
	print("Return: ok %s" % place)
	return true


## The auto return walk (raid / cancelled trip stepping back along return_to).
func _check_walk_back(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if not game._order_patrol(sid):
		print("Walk: FAIL out")
		return false
	var sq: Dictionary = game.squads[game.player]
	sq.returning = true
	sq.return_to = game.capital_id
	sq.return_week = game.week - 1
	game._step_party_home(sq)
	if str(sq.station) != game.capital_id:
		print("Walk: FAIL station ", sq.station)
		return false
	game._offer_home_chip()
	var line := game.home_chip_line(false)
	var want := "Party home · from %s" % game.station_text(sid, "community")
	return _expect(line == want and not bool(game.flags.get("home_pending", false)), "Return walk", "line %s" % line)


## Queued patrol resolves at dawn, the same path the yard uses.
func _check_queued(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if not game.queue_order({"kind": "order", "order": "patrol", "dest": sid}):
		print("Queued: FAIL out ", game.order_block("patrol", sid))
		return false
	game.end_week()
	if str(game.squads[game.player].get("station", "")) == game.capital_id:
		print("Queued: FAIL did not leave")
		return false
	if game.home_chip_line(false) != "":
		print("Queued: FAIL chip on the way out")
		return false
	if not game.queue_order({"kind": "order", "order": "patrol", "dest": game.capital_id}):
		print("Queued: FAIL home ", game.order_block("patrol", game.capital_id))
		return false
	game.end_week()
	var want := "Party home · from %s" % game.station_text(sid, "community")
	var line := game.home_chip_line(false)
	return _expect(line == want, "Queued dawn", "line '%s' week %d station %s" % [line, game.week, game.squads[game.player].get("station", "")])


func _check_wipe(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	game.squads[game.player].station = sid
	game._note_party_home()
	game.squads[game.player].roster = []
	game.squads[game.player].station = game.capital_id
	game._note_party_home()
	game._offer_home_chip()
	var quiet := game.home_chip_line(false) == "" and not bool(game.flags.get("home_pending", false))
	quiet = quiet and not bool(game.flags.get("heard_home", false))
	return _expect(quiet, "Wipe skips", "wiped party still chipped")


func _check_unknown(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	game.stations[sid].known = false
	game.stations[sid].erase("intel")
	game.squads[game.player].station = sid
	game._note_party_home()
	game.squads[game.player].station = game.capital_id
	game._note_party_home()
	game._offer_home_chip()
	var line := game.home_chip_line(false)
	return _expect(line == "Party home · from the line", "Unknown line", "line %s" % line)


func _check_priority(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if not game._order_patrol(sid) or not game._order_patrol(game.capital_id):
		print("Priority: FAIL trip")
		return false
	if not bool(game.flags.get("home_pending", false)):
		print("Priority: FAIL not pending")
		return false
	game.flags["rumor_dawn"] = game.week
	game._offer_home_chip()
	if not bool(game.flags.get("home_pending", false)) or game.home_chip_line(false) != "":
		print("Priority: FAIL rumor did not defer")
		return false
	game.flags["rumor_dawn"] = game.week - 1
	game.flags["border_dawn_new"] = game.week
	game._offer_home_chip()
	if not bool(game.flags.get("home_pending", false)):
		print("Priority: FAIL border did not defer")
		return false
	game.flags["border_dawn_new"] = false
	game.flags["rail_dawn"] = true
	game._offer_home_chip()
	if not bool(game.flags.get("home_pending", false)) or game._soft_dawn_blocker() != "rail":
		print("Priority: FAIL rail did not defer")
		return false
	game.flags["rail_dawn"] = false
	game._offer_home_chip()
	var line := game.home_chip_line(false)
	if line == "" or bool(game.flags.get("home_pending", false)):
		print("Priority: FAIL did not show after ", line)
		return false
	print("Priority: ok rumor > border > rail > home")
	return true


func _check_save(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if not game._order_patrol(sid) or not game._order_patrol(game.capital_id):
		print("Save: FAIL trip")
		return false
	game._offer_home_chip()
	var data := game.export_state()
	var loaded := Game.new()
	loaded.setup(catalog, 2, 40)
	if not loaded.import_state(data):
		print("Save: FAIL import ", loaded.load_error)
		return false
	if not bool(loaded.flags.get("heard_home", false)) or not bool(loaded.flags.get("home_float", false)):
		print("Save: FAIL flags ", loaded.flags.get("heard_home", false), " ", loaded.flags.get("home_float", false))
		return false
	loaded.flags["home_float"] = false
	var again := loaded.export_state()
	var second := Game.new()
	second.setup(catalog, 3, 40)
	if not second.import_state(again):
		print("Save: FAIL second import")
		return false
	if not bool(second.flags.get("heard_home", false)) or bool(second.flags.get("home_float", false)):
		print("Save: FAIL heard stuck")
		return false
	if not second._order_patrol(sid) or not second._order_patrol(second.capital_id):
		print("Save: FAIL return after load")
		return false
	second.week += 1
	second._offer_home_chip()
	var quiet := second.home_chip_line(false) != "" and not bool(second.flags.get("home_float", false))
	return _expect(quiet, "Save keeps heard_home", "float after load")


func _check_drift(catalog: Catalog) -> bool:
	var text := FileAccess.get_file_as_string("res://data/balance.json")
	if text.contains("heard_home") or text.contains("homecoming") or text.contains("home_boots"):
		print("Drift: FAIL balance.json mentions homecoming")
		return false
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("hope_drift", 0)) != -1:
		print("Drift: FAIL hope_drift")
		return false
	var game := _game(catalog)
	if int(game.bal.hope_drift) != -1:
		print("Drift: FAIL live hope_drift")
		return false
	var sid := _neighbor(game)
	var before := _meters(game)
	game._order_patrol(sid)
	game._order_patrol(game.capital_id)
	game._offer_home_chip()
	if _meters(game) != before:
		print("Drift: FAIL chip moved meters")
		return false
	print("Careful band: untouched")
	return true


func _check_icon() -> void:
	var status := FileAccess.file_exists("res://assets/icons/status/home_boots.png")
	var status_24 := FileAccess.file_exists("res://assets/icons/status/home_boots_24.png")
	var map_icon := FileAccess.file_exists("res://assets/icons/map/home_boots.png")
	var map_24 := FileAccess.file_exists("res://assets/icons/map/home_boots_24.png")
	if not status or not status_24 or not map_icon or not map_24:
		print("Icon: omitted (home_boots file missing)")
		return
	## ArtPack preloads the whole pack; this gate only needs the boot files themselves.
	var big := Image.new()
	var small := Image.new()
	if big.load("res://assets/icons/status/home_boots.png") != OK or small.load("res://assets/icons/status/home_boots_24.png") != OK:
		print("Icon: home_boots present but did not load; chip omits it")
		return
	if big.get_width() != 256 or small.get_width() != 24:
		print("Icon: FAIL size %d / %d" % [big.get_width(), small.get_width()])
		failed = true
		return
	print("Icon: home_boots 256+24")
