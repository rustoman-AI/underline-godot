extends SceneTree

## P42 rail noise. Border party queues one dawn chip; none when the border is empty;
## a mid-assault party is skipped; the first chip of a run floats once; rumor and
## border.dawn_new outrank it. Meters and the careful loss band stay put.
##   godot --headless --path . -s res://sim/check_rail_noise.gd


func _init() -> void:
	var failed := false
	if not _check_strings():
		failed = true
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_noise(catalog):
		failed = true
	if not _check_icon():
		failed = true
	if not _check_props():
		failed = true
	if failed:
		print("RAIL NOISE FAIL")
		quit(1)
		return
	print("RAIL NOISE OK")
	quit(0)


func _check_strings() -> bool:
	Copy.set_lang("en")
	var en := {
		"noise.rail": "Rail noise · {station}",
		"noise.rail_unknown": "Rail noise · Unknown",
		"noise.first": "Something heavy on the next rail.",
		"noise.tip": "A rival party on your border",
		"noise.chip_label": "Noise",
		"noise.gone": "The next rail went quiet.",
	}
	for key in en:
		if Copy.t(key) != str(en[key]):
			print("Strings: FAIL en ", key, " ", Copy.t(key))
			return false
	var filled := Copy.fill("noise.rail", {"station": "Sisters of the Garden"})
	if filled != "Rail noise · Sisters of the Garden":
		print("Strings: FAIL fill ", filled)
		return false
	Copy.set_lang("ru")
	var ru := {
		"noise.rail": "Шум рельсов · {station}",
		"noise.rail_unknown": "Шум рельсов · Неизвестно",
		"noise.first": "На соседних рельсах что-то тяжёлое.",
		"noise.tip": "Чужой отряд на вашей границе",
		"noise.chip_label": "Шум",
		"noise.gone": "Соседние рельсы затихли.",
	}
	for key in ru:
		if Copy.t(key) != str(ru[key]):
			print("Strings: FAIL ru ", key, " ", Copy.t(key))
			return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_noise(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	if game.over == "error":
		print("Noise: FAIL setup")
		return false
	var meters := _meters(game)
	var band := _band(game)
	var borders: Array = game.border_stations()
	if not borders.has("riverside") or borders.has(game.capital_id) or borders.has("brickworks"):
		print("Noise: FAIL borders ", borders)
		return false
	for sid in borders:
		if str(game.stations[sid].owner) == game.player or not game.borders_player(str(sid)):
			print("Noise: FAIL border station ", sid)
			return false
	if not game.rail_noise_candidate().is_empty():
		print("Noise: FAIL chip with nobody on the border ", game.rail_noise_candidate())
		return false
	var home := str(game.squads["exchange"].station)
	game.squads["exchange"].station = "brickworks"
	game.squads["exchange"].size = 8
	if not game.rail_noise_candidate().is_empty():
		print("Noise: FAIL two-hop station queued a chip")
		return false
	game.squads["exchange"].station = "riverside"
	var chip: Dictionary = game.rail_noise_candidate()
	var place := game.station_text("riverside", "community")
	if str(chip.get("station", "")) != "riverside" or str(chip.get("key", "")) != "noise.rail":
		print("Noise: FAIL known chip ", chip)
		return false
	if game.dawn_soft_line(chip) != "Rail noise · %s" % place:
		print("Noise: FAIL line ", game.dawn_soft_line(chip))
		return false
	game.stations["riverside"].known = false
	game.stations["riverside"].intel = 0
	chip = game.rail_noise_candidate()
	if str(chip.get("key", "")) != "noise.rail_unknown" or game.dawn_soft_line(chip) != Copy.t("noise.rail_unknown"):
		print("Noise: FAIL unknown ", chip, " ", game.dawn_soft_line(chip))
		return false
	game.stations["riverside"].intel = 1
	chip = game.rail_noise_candidate()
	if str(chip.get("key", "")) != "noise.rail" or int(game.station_intel("riverside")) < 1:
		print("Noise: FAIL intel ", chip)
		return false
	game.stations["riverside"].known = true
	game.squads["exchange"].away = true
	if not game.rail_noise_candidate().is_empty():
		print("Noise: FAIL away party")
		return false
	game.squads["exchange"].away = false
	game.squads["exchange"].size = 0
	if not game.rail_noise_candidate().is_empty():
		print("Noise: FAIL empty party")
		return false
	game.squads["exchange"].size = 6
	game.squads["exchange"].mid_assault = true
	if not game.rail_noise_candidate().is_empty() or not game.party_mid_assault("exchange"):
		print("Noise: FAIL mid-assault still queued")
		return false
	game.squads["exchange"].mid_assault = false
	game.squads["exchange"].assault_player_week = game.week
	if not game.rail_noise_candidate().is_empty():
		print("Noise: FAIL assault week")
		return false
	game.squads["exchange"].assault_player_week = game.week - 1
	if not game.rail_noise_candidate().is_empty():
		print("Noise: FAIL dawn after assault")
		return false
	game.squads["exchange"].assault_player_week = game.week - 2
	chip = game.rail_noise_candidate()
	if str(chip.get("station", "")) != "riverside":
		print("Noise: FAIL noise did not return after the assault week ", chip)
		return false
	game.squads["exchange"].station = home
	game.squads[game.player].station = "riverside"
	if not game.rail_noise_candidate().is_empty():
		print("Noise: FAIL player party counted ", game.rail_noise_candidate())
		return false
	game.squads[game.player].station = game.capital_id
	game.squads["exchange"].station = "riverside"
	if not _check_pick(game):
		return false
	if not _check_priority(game):
		return false
	if not _check_float(game, catalog):
		return false
	if _meters(game) != meters or _band(game) != band:
		print("Noise: FAIL meters or careful band moved")
		return false
	var losses := FileAccess.get_file_as_string("res://sim/check_balance.gd")
	if not losses.contains('const LOSSES := {"careful": [3, 11], "expander": [0, 17], "follower": [0, 16]}'):
		print("Noise: FAIL careful loss band")
		return false
	game.squads["exchange"].station = home
	print("Noise: ok")
	return true


## Largest party, then the station closest to Coney. Garden held so northgate and mill join the border.
func _check_pick(game: Game) -> bool:
	game.stations["garden"].owner = game.player
	var near := game._hops("riverside", game.capital_id)
	var far := game._hops("northgate", game.capital_id)
	if near >= far or not game.border_stations().has("northgate") or not game.border_stations().has("riverside"):
		print("Noise: FAIL hop geometry ", near, " ", far, " ", game.border_stations())
		return false
	game.squads["exchange"].station = "riverside"
	game.squads["exchange"].size = 6
	game.squads["directorate"].station = "northgate"
	game.squads["directorate"].size = 6
	var chip: Dictionary = game.rail_noise_candidate()
	if str(chip.get("station", "")) != "riverside" or int(chip.get("hops", 99)) != near:
		print("Noise: FAIL tie went far ", chip)
		return false
	game.squads["directorate"].size = 11
	chip = game.rail_noise_candidate()
	if str(chip.get("station", "")) != "northgate" or int(chip.get("size", 0)) != 11:
		print("Noise: FAIL largest party ", chip)
		return false
	game.squads["directorate"].size = 4
	chip = game.rail_noise_candidate()
	if str(chip.get("faction", "")) != "exchange":
		print("Noise: FAIL smaller far party won ", chip)
		return false
	print("Noise: pick ok")
	return true


func _check_priority(game: Game) -> bool:
	game.squads["exchange"].station = "riverside"
	game.squads["exchange"].size = 8
	game.squads["directorate"].station = "northgate"
	game.squads["directorate"].mid_assault = true
	game.flags["rumor_dawn"] = true
	game.flags["border_dawn_new"] = true
	if str(game.dawn_soft_chip().get("kind", "")) != "rumor":
		print("Noise: FAIL rumor did not outrank rail")
		return false
	game.flags.erase("rumor_dawn")
	if str(game.dawn_soft_chip().get("kind", "")) != "border_new":
		print("Noise: FAIL border_new did not outrank rail")
		return false
	game.flags.erase("border_dawn_new")
	if str(game.dawn_soft_chip().get("kind", "")) != "rail":
		print("Noise: FAIL rail missing after higher chips ", game.dawn_soft_chip())
		return false
	game.flags["rumor_dawn"] = true
	var shown: Dictionary = game.present_dawn_soft_chip()
	if str(shown.get("kind", "")) != "rumor" or not bool(shown.get("fresh", false)) or bool(shown.get("first", false)):
		print("Noise: FAIL rumor present ", shown)
		return false
	if game.flags.has("rumor_dawn") or bool(game.flags.get("heard_rail", false)):
		print("Noise: FAIL rumor consumed the rail flag")
		return false
	if str(game.dawn_soft_chip().get("kind", "")) != "rumor":
		print("Noise: FAIL rail stacked on the rumor dawn")
		return false
	game.week += 1
	if str(game.dawn_soft_chip().get("kind", "")) != "rail":
		print("Noise: FAIL rail did not wait a dawn")
		return false
	print("Noise: priority ok")
	return true


func _check_float(game: Game, catalog: Catalog) -> bool:
	var first: Dictionary = game.present_dawn_soft_chip()
	if str(first.get("kind", "")) != "rail" or not bool(first.get("fresh", false)) or not bool(first.get("first", false)):
		print("Noise: FAIL first float ", first)
		return false
	if not bool(game.flags.get("heard_rail", false)):
		print("Noise: FAIL heard_rail unset")
		return false
	var again: Dictionary = game.present_dawn_soft_chip()
	if bool(again.get("fresh", false)) or bool(again.get("first", false)):
		print("Noise: FAIL second present the same dawn ", again)
		return false
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var copy := Game.new()
	copy.catalog = catalog
	if not copy.import_state(data):
		print("Noise: FAIL load ", copy.load_error)
		return false
	if not bool(copy.flags.get("heard_rail", false)):
		print("Noise: FAIL heard_rail did not load")
		return false
	var loaded: Dictionary = copy.present_dawn_soft_chip()
	if bool(loaded.get("first", false)):
		print("Noise: FAIL float replayed from the save ", loaded)
		return false
	copy.week += 1
	var later: Dictionary = copy.present_dawn_soft_chip()
	if str(later.get("kind", "")) != "rail" or not bool(later.get("fresh", false)) or bool(later.get("first", false)):
		print("Noise: FAIL later dawn ", later)
		return false
	print("Noise: float ok")
	return true


func _check_icon() -> bool:
	var paths := [
		"res://assets/icons/status/noise_rail.png",
		"res://assets/icons/status/noise_rail_24.png",
		"res://assets/icons/map/noise_rail.png",
		"res://assets/icons/map/noise_rail_24.png",
	]
	var present := false
	for path in paths:
		if ResourceLoader.exists(path):
			present = true
	var registered := FileAccess.get_file_as_string("res://ui/art_pack.gd")
	if not registered.contains('"noise_rail"'):
		print("Icon: FAIL noise_rail is not registered")
		return false
	if present:
		print("Icon: noise_rail file present")
	else:
		print("Icon: absent, text chip")
	return true


## Tray and listening cans are wired only when the files are already in the prop set.
## PROPS stays empty while the painted rooms carry their own props. No new prop system.
func _check_props() -> bool:
	var tray := "res://assets/props/prop_infirmary_tray.webp"
	var cans := "res://assets/props/prop_listening_cans.webp"
	if ResourceLoader.exists(tray) or ResourceLoader.exists(cans):
		print("Props: FAIL files exist and are not wired")
		return false
	print("Props: absent, not wired")
	return true


func _meters(game: Game) -> Array:
	var stock: Array = []
	for key in ["air", "food", "power", "materials", "tokens", "influence"]:
		stock.append(int(game.stock.get(key, 0)))
	return [game.hope, game.discontent, stock]


func _band(game: Game) -> Array:
	return [
		int(game.bal.hope_drift),
		int(game.bal.shortage_hope),
		int(game.bal.power_shortage_hope),
		int(game.bal.power_shortage_discontent),
		int(game.bal.harvest_swing),
		int(game.bal.start.hope),
		int(game.bal.start.discontent),
		int(game.bal.get("overcrowd_discontent", 0)),
		int(game.bal.get("assault_hope", 0)),
		int(game.bal.get("assault_discontent", 0)),
	]
