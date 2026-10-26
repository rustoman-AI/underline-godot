extends SceneTree

const Catalog = preload("res://sim/catalog.gd")
const Game = preload("res://sim/game.gd")
const Copy = preload("res://sim/copy.gd")

## P44 Party Away. Sticky yard read only — never a soft dawn chip, never a balance edit.
##   godot --headless --path . -s res://sim/check_party_away.gd

const STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]
const EN := {
	"away.out": "Party out · {station}",
	"away.out_unknown": "Party out · on the line",
	"away.first": "The platform feels thin.",
	"away.tip": "Your party is still on the line.",
	"away.badge_label": "Away",
	"away.reduce": "Party out.",
}
const RU := {
	"away.out": "Отряд вне · {station}",
	"away.out_unknown": "Отряд вне · на линии",
	"away.first": "На платформе пустовато.",
	"away.tip": "Ваш отряд всё ещё на линии.",
	"away.badge_label": "Вне",
	"away.reduce": "Отряд вне.",
}


func _init() -> void:
	var failed := false
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if not _check_strings():
		failed = true
	if not _check_home(catalog):
		failed = true
	if not _check_leave_and_return(catalog):
		failed = true
	if not _check_unknown_and_last(catalog):
		failed = true
	if not _check_wipe(catalog):
		failed = true
	if not _check_float_and_save(catalog):
		failed = true
	if not _check_no_dawn(catalog):
		failed = true
	if not _check_arrival(catalog):
		failed = true
	if not _check_art():
		failed = true
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("Balance: FAIL balance.json changed")
		failed = true
	else:
		print("Balance: ok")
	if failed:
		print("PARTY AWAY FAIL")
		quit(1)
		return
	print("PARTY AWAY OK")
	quit(0)


func _check_strings() -> bool:
	Copy.set_lang("en")
	for key in EN:
		if Copy.t(str(key)) != str(EN[key]):
			print("Strings: FAIL en ", key, " ", Copy.t(str(key)))
			return false
	var filled := Copy.fill("away.out", {"station": "Jay St"})
	if filled != "Party out · Jay St":
		print("Strings: FAIL fill ", filled)
		return false
	Copy.set_lang("ru")
	for key in RU:
		if Copy.t(str(key)) != str(RU[key]):
			print("Strings: FAIL ru ", key, " ", Copy.t(str(key)))
			return false
	var ru_fill := Copy.fill("away.out", {"station": "Джей"})
	if ru_fill != "Отряд вне · Джей":
		print("Strings: FAIL ru fill ", ru_fill)
		return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _boot(catalog: Catalog) -> Game:
	Copy.set_lang("en")
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _stop(game: Game) -> String:
	var home := str(game.capital_id)
	for n in game._neighbors(home):
		var sid := str(n)
		if game.stations.has(sid) and not bool(game.stations[sid].get("hidden", false)):
			return sid
	return ""


func _other(game: Game, skip: String) -> String:
	var home := str(game.capital_id)
	for sid in game.stations:
		var id := str(sid)
		if id == home or id == skip:
			continue
		if bool(game.stations[id].get("hidden", false)):
			continue
		return id
	return ""


func _check_home(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var view: Dictionary = game.party_away_view()
	if bool(view.show) or not bool(view.never_left) or bool(view.wiped):
		print("Home: FAIL ", view)
		return false
	if game.party_away_line(false) != "" or bool(game.flags.get("party_left_home", false)):
		print("Home: FAIL line or flag")
		return false
	if bool(view.dawn) or game.party_away_dawn_chip():
		print("Home: FAIL dawn")
		return false
	if game.dawn_soft_stack() != STACK:
		print("Home: FAIL stack ", game.dawn_soft_stack())
		return false
	for slot in game.dawn_soft_stack():
		if str(slot).contains("away"):
			print("Home: FAIL stack slot ", slot)
			return false
	print("Home: ok")
	return true


func _check_leave_and_return(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _stop(game)
	if sid == "":
		print("Leave: FAIL no neighbor")
		return false
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var stock0: Dictionary = game.stock.duplicate()
	var sick0 := _sick_count(game)
	var staff0 := _staff_count(game)
	var sq: Dictionary = game.squads[game.player]
	sq.station = sid
	sq.away = false
	var view: Dictionary = game.party_away_view()
	var place := game.station_text(sid, "community")
	if not bool(view.show) or str(view.line_key) != "away.out" or str(view.station) != place:
		print("Leave: FAIL view ", view, " place ", place)
		return false
	if game.party_away_line(false) != "Party out · %s" % place:
		print("Leave: FAIL line ", game.party_away_line(false))
		return false
	if game.party_away_line(true) != "Party out.":
		print("Leave: FAIL reduce ", game.party_away_line(true))
		return false
	if not bool(view.first) or bool(view.heard):
		print("Leave: FAIL first ", view)
		return false
	sq.station = str(game.capital_id)
	sq.away = false
	sq.returning = false
	var back: Dictionary = game.party_away_view()
	if bool(back.show) or game.party_away_line(false) != "":
		print("Return: FAIL still showing ", back)
		return false
	if not bool(game.flags.get("party_left_home", false)):
		print("Return: FAIL left flag cleared")
		return false
	if int(game.hope) != hope0 or int(game.discontent) != dis0 or game.stock != stock0:
		print("Leave: FAIL meters drifted")
		return false
	if _sick_count(game) != sick0 or _staff_count(game) != staff0:
		print("Leave: FAIL heal or assign")
		return false
	print("Leave: ok ", place)
	return true


func _check_unknown_and_last(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _stop(game)
	var other := _other(game, sid)
	if sid == "" or other == "":
		print("Unknown: FAIL stops")
		return false
	var sq: Dictionary = game.squads[game.player]
	sq.station = sid
	game.party_away_view()
	var known_name := game.station_text(sid, "community")
	sq.station = str(game.capital_id)
	sq.away = true
	var transit: Dictionary = game.party_away_view()
	if not bool(transit.show) or not bool(transit.known) or str(transit.station) != known_name:
		print("Unknown: FAIL last known ", transit, " ", known_name)
		return false
	if game.party_away_line(false) != "Party out · %s" % known_name:
		print("Unknown: FAIL last line ", game.party_away_line(false))
		return false
	sq.away = false
	sq.station = other
	game.stations[other].known = false
	game.stations[other].erase("intel")
	var blind: Dictionary = game.party_away_view()
	if not bool(blind.show) or bool(blind.known) or str(blind.line_key) != "away.out_unknown":
		print("Unknown: FAIL current blind ", blind)
		return false
	if game.party_away_line(false) != "Party out · on the line":
		print("Unknown: FAIL blind line ", game.party_away_line(false))
		return false
	game.stations[other].intel = 0
	var low: Dictionary = game.party_away_view()
	if bool(low.known):
		print("Unknown: FAIL intel 0 still known")
		return false
	game.stations[other].intel = 1
	var named: Dictionary = game.party_away_view()
	if not bool(named.known) or str(named.station) == "":
		print("Unknown: FAIL intel 1 ", named)
		return false
	sq.away = true
	sq.station = str(game.capital_id)
	game.flags.erase("away_last_station")
	var bare: Dictionary = game.party_away_view()
	if not bool(bare.show) or bool(bare.known) or str(bare.line_key) != "away.out_unknown":
		print("Unknown: FAIL expedition ", bare)
		return false
	print("Unknown: ok")
	return true


func _check_wipe(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _stop(game)
	var sq: Dictionary = game.squads[game.player]
	var roster: Array = sq.roster.duplicate()
	sq.station = sid
	sq.roster = []
	var wiped: Dictionary = game.party_away_view()
	if bool(wiped.show) or not bool(wiped.wiped):
		print("Wipe: FAIL showing ", wiped)
		return false
	if bool(game.flags.get("party_left_home", false)):
		print("Wipe: FAIL never-left marked")
		return false
	sq.roster = roster
	game.party_away_view()
	sq.roster = []
	var after: Dictionary = game.party_away_view()
	if bool(after.show):
		print("Wipe: FAIL orphan after loss ", after)
		return false
	print("Wipe: ok")
	return true


func _check_float_and_save(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _stop(game)
	var sq: Dictionary = game.squads[game.player]
	sq.station = sid
	var first: Dictionary = game.party_away_view()
	if not bool(first.first):
		print("Float: FAIL missing first")
		return false
	game.party_mark_heard_away()
	var again: Dictionary = game.party_away_view()
	if bool(again.first) or not bool(again.heard) or not bool(again.show):
		print("Float: FAIL second ", again)
		return false
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var loaded := _boot(catalog)
	if not loaded.import_state(data):
		print("Float: FAIL load ", loaded.load_error)
		return false
	var kept: Dictionary = loaded.party_away_view()
	if not bool(kept.show) or bool(kept.first) or not bool(loaded.flags.get("heard_away", false)):
		print("Float: FAIL loaded away ", kept)
		return false
	loaded.squads[loaded.player].station = str(loaded.capital_id)
	loaded.squads[loaded.player].away = false
	loaded.squads[loaded.player].returning = false
	var home := loaded.export_state()
	home["schema"] = Game.SAVE_SCHEMA
	var returned := _boot(catalog)
	if not returned.import_state(home):
		print("Float: FAIL return load ", returned.load_error)
		return false
	var quiet: Dictionary = returned.party_away_view()
	if bool(quiet.show) or not bool(returned.flags.get("heard_away", false)):
		print("Float: FAIL orphan after load ", quiet)
		return false
	returned.squads[returned.player].station = sid
	var second: Dictionary = returned.party_away_view()
	if not bool(second.show) or bool(second.first):
		print("Float: FAIL second departure ", second)
		return false
	print("Float: ok")
	return true


func _check_no_dawn(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _stop(game)
	var rumor0: Dictionary = game.rumor.duplicate(true)
	var pending0 := game.pending.size()
	var notices0 := game.notices.size()
	var white0 := game.white_pending.size()
	var story0 := game.story_queue.size()
	game.squads[game.player].station = sid
	game.party_away_view()
	game.party_mark_heard_away()
	game.party_away_line(false)
	game.squads[game.player].station = str(game.capital_id)
	game.party_away_view()
	if game.rumor != rumor0 or game.pending.size() != pending0 or game.notices.size() != notices0:
		print("Dawn: FAIL queues changed")
		return false
	if game.white_pending.size() != white0 or game.story_queue.size() != story0:
		print("Dawn: FAIL white or story")
		return false
	if game.party_away_dawn_chip():
		print("Dawn: FAIL chip")
		return false
	print("Dawn: ok")
	return true


## Same tick the party steps home, the badge is gone and P43 may still offer its chip.
func _check_arrival(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	if not game.has_method("_note_party_home") or not game.has_method("_offer_home_chip") or not game.has_method("home_chip_line"):
		print("Arrival: FAIL homecoming api missing")
		return false
	var sid := _stop(game)
	if sid == "":
		print("Arrival: FAIL no neighbor")
		return false
	var sq: Dictionary = game.squads[game.player]
	sq.station = str(game.capital_id)
	sq.away = false
	sq.returning = false
	game._note_party_home()
	sq.station = sid
	game._note_party_home()
	var away: Dictionary = game.party_away_view()
	if not bool(away.show):
		print("Arrival: FAIL badge while out ", away)
		return false
	if bool(game.flags.get("home_pending", false)):
		print("Arrival: FAIL chip while still out")
		return false
	sq.station = str(game.capital_id)
	sq.away = false
	sq.returning = false
	game._note_party_home()
	var back: Dictionary = game.party_away_view()
	if bool(back.show) or game.party_away_line(false) != "":
		print("Arrival: FAIL badge still up ", back)
		return false
	if not bool(game.flags.get("home_pending", false)):
		print("Arrival: FAIL homecoming cleared with the badge")
		return false
	if game.party_away_dawn_chip():
		print("Arrival: FAIL away dawn chip")
		return false
	game._offer_home_chip()
	if game.home_chip_line(false) == "":
		print("Arrival: FAIL home chip silent")
		return false
	var still: Dictionary = game.party_away_view()
	if bool(still.show):
		print("Arrival: FAIL badge after chip ", still)
		return false
	if int(game.flags.get("home_shown", -1)) != int(game.week):
		print("Arrival: FAIL home shown lost")
		return false
	if bool(game.flags.get("home_pending", false)):
		print("Arrival: FAIL pending stuck")
		return false
	print("Arrival: ok")
	return true


func _check_art() -> bool:
	for path in [
		"res://assets/icons/status/away_boots.png",
		"res://assets/icons/status/away_boots_24.png",
		"res://assets/icons/map/away_boots.png",
		"res://assets/icons/map/away_boots_24.png",
	]:
		if not FileAccess.file_exists(path):
			print("Art: FAIL missing ", path)
			return false
	print("Art: ok")
	return true


func _sick_count(game: Game) -> int:
	var n := 0
	for person in game.residents:
		if int(person.get("sick", 0)) > 0:
			n += 1
	return n


func _staff_count(game: Game) -> int:
	var n := 0
	for room in game.rooms:
		n += room.staff.size()
	return n
