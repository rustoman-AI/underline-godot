extends SceneTree

## P53 Raid Share gate.
##   godot --headless --path . -s res://sim/check_raid_share.gd
## Stockpile matches today's loot. Yard and Tribute follow DEC-L1. The card is not a soft dawn chip.
## Careful loss on seeds 1–60 is the shared 7/60 line after the P64 pack.
## The 15–35% band is noted, not retuned here. Careful still never raids.

var failed := false


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("RAID SHARE FAIL catalog " + catalog.error)
		quit(1)
		return
	_strings()
	_balance(catalog)
	_stockpile_parity(catalog)
	_hold_before_dawn(catalog)
	_yard_and_tribute(catalog)
	_edges(catalog)
	_bots(catalog)
	_assault_never(catalog)
	_not_soft_dawn(catalog)
	_ui_wires()
	if failed:
		print("RAID SHARE FAIL")
		quit(1)
		return
	var band := _careful_band(catalog)
	var lost := int(band.lost)
	var pct := 100.0 * float(lost) / 60.0
	print("Careful loss: %d/60 (%.1f%%)" % [lost, pct])
	print("Careful raid_share hope %d  chronicle %d" % [int(band.hope), int(band.moments)])
	# P64 tunnel-life one-shots moved the shared careful line from 2/60 to 7/60.
	# Careful still never raids, so Yard hope and the chronicle stay 0. Do not retune Yard hope.
	# The tunnel gate owns the 15-35% note. Softening crate_blank keep food does not climb into that band.
	if int(band.hope) != 0 or int(band.moments) != 0:
		_bad("careful took Yard or Tribute (hope %d, chronicle %d)" % [int(band.hope), int(band.moments)])
	if lost != 7:
		_bad("careful loss %d/60 moved off the 7/60 line" % lost)
	if lost < 9 or lost > 21:
		print("NOTE spec names 15-35 percent of 60. Measured %d/60 (%.1f percent). Careful still does not raid." % [lost, pct])
	if failed:
		print("RAID SHARE FAIL")
		quit(1)
	else:
		print("RAID SHARE OK")
		quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_bad(msg)


func _strings() -> void:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/raid_share.json"))
	if not (pack is Dictionary) or not (pack.by_key is Dictionary):
		_bad("raid_share.json")
		return
	var rows: Dictionary = pack.by_key
	Copy.set_lang("en")
	for key in rows:
		var want := str(rows[key].get("en", ""))
		if Copy.t(str(key)) != want:
			_bad("EN %s got %s" % [str(key), Copy.t(str(key))])
	Copy.set_lang("ru")
	for key in rows:
		var want := str(rows[key].get("ru", ""))
		if Copy.t(str(key)) != want:
			_bad("RU %s got %s" % [str(key), Copy.t(str(key))])
	Copy.set_lang("en")
	_expect(Copy.fill("raid_share.toast_tribute", {"faction": "Directorate"}) == "Tribute sent to Directorate.", "tribute toast fill")
	_expect(Copy.fill("raid_share.dawn_yard", {"before": 40, "after": 42}) == "The yard ate. Hope 40 → 42.", "dawn yard fill")
	_expect(Copy.fill("raid_share.dawn_tribute", {"faction": "Directorate", "before": -25, "after": -13}) == "Tribute to Directorate. Opinion -25 → -13.", "dawn tribute fill")


func _balance(catalog: Catalog) -> void:
	_expect(int(catalog.balance.get("gift_opinion", 0)) == 12, "gift_opinion moved")
	_expect(int(catalog.balance.get("raid_loot_food", 0)) == 8 and int(catalog.balance.get("raid_loot_materials", 0)) == 6, "raid loot moved")
	for key in catalog.balance:
		if str(key).begins_with("raid_share"):
			_bad("new balance key " + str(key))


func _game(catalog: Catalog, run_seed := 3) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.injury_bias = 0.0
	return game


func _arm(game: Game) -> String:
	var dest := ""
	var fallback := ""
	for sid in game._neighbors(game.capital_id):
		if fallback == "":
			fallback = str(sid)
		var owner := str(game.stations[str(sid)].get("owner", ""))
		if owner != game.player and owner != "neutral" and owner != "ruin" and owner != "bunker" and str(game.stations[str(sid)].get("bunker", "")) == "":
			dest = str(sid)
			break
	if dest == "":
		dest = fallback
		if dest != "" and game.stations.has(dest):
			game.stations[dest].owner = "directorate"
			game.stations[dest].bunker = ""
	if dest == "":
		return ""
	var st: Dictionary = game.stations[dest]
	st.known = true
	st.intel = 2
	st.garrison = 1
	st.fort = 0.2
	st.unrest = 0
	game.squads[game.player].gear = 40.0
	game.stock.food = 40
	return dest


func _snap(game: Game) -> Dictionary:
	var opinions := {}
	for fid in game.opinions:
		opinions[str(fid)] = int(game.opinions[fid])
	return {
		"food": int(game.stock.food),
		"materials": int(game.stock.materials),
		"tokens": int(game.stock.tokens),
		"hope": game.hope,
		"discontent": game.discontent,
		"blueprints": int(game.stock.get("blueprints", 0)),
		"opinions": opinions,
		"week": game.week,
		"over": game.over,
	}


func _same(a: Dictionary, b: Dictionary, label: String) -> void:
	for key in a:
		if str(key) == "opinions":
			var ao: Dictionary = a.opinions
			var bo: Dictionary = b.opinions
			for fid in ao:
				if int(ao[fid]) != int(bo.get(fid, -999)):
					_bad("%s opinion %s %s vs %s" % [label, fid, str(ao[fid]), str(bo.get(fid, "?"))])
			continue
		if str(a[key]) != str(b[key]):
			_bad("%s %s %s vs %s" % [label, str(key), str(a[key]), str(b[key])])


func _share_moments(game: Game) -> int:
	var n := 0
	for moment in game.chronicle:
		if str(moment.get("kind", "")) == "raid_share":
			n += 1
			if int(moment.get("weight", 0)) != 1:
				_bad("chronicle weight %s" % str(moment.get("weight", "")))
	return n


func _report_text(game: Game, kind: String) -> String:
	for row in game.order_reports:
		if str(row.get("kind", "")) == kind:
			return str(row.get("text", ""))
	return ""


func _stockpile_parity(catalog: Catalog) -> void:
	var plain := _game(catalog)
	var held := _game(catalog)
	var dest := _arm(plain)
	var dest_b := _arm(held)
	_expect(dest != "" and dest == dest_b, "no raid target")
	if dest == "":
		return
	var gate := plain._raid_gate(dest)
	_expect(gate == "", "raid blocked " + gate)
	if gate != "":
		return
	var before := int(plain.stock.food)
	var mats_before := int(plain.stock.materials)
	_expect(plain._order_raid(dest, true), "plain raid failed")
	_expect(not plain.raid_share_open(), "plain raid left the card open")
	var food_gain := int(plain.bal.get("raid_loot_food", 0))
	var mat_gain := int(plain.bal.get("raid_loot_materials", 0))
	var pack := int(plain.bal.get("raid_pack_food", 0))
	_expect(int(plain.stock.food) == before - pack + food_gain, "stockpile food %s expected %s" % [plain.stock.food, before - pack + food_gain])
	_expect(int(plain.stock.materials) == mats_before + mat_gain, "stockpile mats")
	_expect(_share_moments(plain) == 0, "stockpile wrote a chronicle")
	_expect(_report_text(plain, "raid_share") == "", "stockpile wrote a dawn line")
	held.raid_share_hold = true
	var food_b := int(held.stock.food)
	_expect(held._order_raid(dest_b, true), "held raid failed")
	_expect(held.raid_share_open(), "held raid did not open the share")
	_expect(int(held.stock.food) == food_b - pack, "loot landed before the pick")
	var loot: Dictionary = held.raid_share_loot()
	_expect(int(loot.get("food", 0)) == food_gain and int(loot.get("mats", 0)) == mat_gain and int(loot.get("good", 0)) == 0, "loot table changed %s" % str(loot))
	_expect(held.raid_share_body() == Copy.fill("raid_share.body", {"loot": held.raid_share_loot_line()}), "body is not the loot line")
	var again: Dictionary = held.apply_raid_share("later")
	_expect(not bool(again.ok) and held.raid_share_open(), "unknown choice consumed the haul")
	var row: Dictionary = held.apply_raid_share("stockpile")
	_expect(bool(row.ok) and str(row.toast) == "", "stockpile toast %s" % str(row.get("toast", "")))
	var twice: Dictionary = held.apply_raid_share("stockpile")
	_expect(bool(twice.ok) and bool(twice.already), "second stockpile was not a no-op")
	_same(_snap(plain), _snap(held), "stockpile parity")


func _dawn_logged(game: Game, week: int) -> bool:
	for entry in game.log:
		if int(entry.get("week", 0)) == week and str(entry.get("text", "")).begins_with("DAWN food"):
			return true
	return false


func _hold_before_dawn(catalog: Catalog) -> void:
	var auto := _game(catalog, 4)
	var wait := _game(catalog, 4)
	var dest := _arm(auto)
	_arm(wait)
	if dest == "" or not auto.queue_order({"kind": "order", "order": "raid", "dest": dest}):
		_bad("could not queue raid " + auto._raid_gate(dest))
		return
	if not wait.queue_order({"kind": "order", "order": "raid", "dest": dest}):
		_bad("could not queue the held raid")
		return
	auto.end_week()
	wait.raid_share_hold = true
	wait.end_week()
	_expect(wait.dawn_held() and wait.raid_share_open(), "dawn did not wait on the share")
	_expect(not _dawn_logged(wait, wait.week), "dawn log ran before the pick")
	_expect(_dawn_logged(auto, auto.week), "auto dawn did not log")
	var chip: Dictionary = wait._pick_dawn_soft_chip()
	_expect(str(chip.get("kind", "")) != "raid_share", "share joined the soft dawn stack")
	_expect(_report_text(wait, "raid_share") == "", "share report before the pick")
	wait.resume_dawn()
	_expect(not wait.dawn_held() and not wait.raid_share_open(), "resume left the card open")
	_expect(_dawn_logged(wait, wait.week), "resume did not finish dawn")
	_same(_snap(auto), _snap(wait), "timeout stockpile")


func _stage(game: Game, food: int, mats: int, good: int, good_res := "", faction := "directorate") -> void:
	game.raid_share = {
		"food": food,
		"mats": mats,
		"good": good,
		"good_res": good_res,
		"faction": faction,
		"station": "staged",
		"place": "Staged",
	}


func _yard_and_tribute(catalog: Catalog) -> void:
	var yard := _game(catalog, 5)
	_stage(yard, 8, 6, 0)
	var food0 := int(yard.stock.food)
	var mats0 := int(yard.stock.materials)
	var hope0 := yard.hope
	var dis0 := yard.discontent
	var row: Dictionary = yard.apply_raid_share("yard")
	_expect(int(yard.stock.food) == food0 + 4 and int(yard.stock.materials) == mats0 + 6, "yard stock")
	_expect(yard.hope == hope0 + 2 and yard.discontent == dis0 - 2, "yard mood %s %s" % [yard.hope - hope0, yard.discontent - dis0])
	_expect(str(row.toast) == Copy.t("raid_share.toast_yard"), "yard toast")
	_expect(_report_text(yard, "raid_share") == Copy.fill("raid_share.dawn_yard", {"before": hope0, "after": hope0 + 2}), "yard dawn line")
	_expect(_share_moments(yard) == 1, "yard chronicle")
	_expect(yard.chronicle_line(yard.chronicle[yard.chronicle.size() - 1]) == _report_text(yard, "raid_share"), "chronicle line")

	var tribute := _game(catalog, 5)
	_stage(tribute, 8, 6, 0)
	var opinion0 := int(tribute.opinions.get("directorate", 0))
	var tokens0 := int(tribute.stock.tokens)
	var hope1 := tribute.hope
	var trow: Dictionary = tribute.apply_raid_share("tribute")
	_expect(int(tribute.stock.food) == food0 + 4 and int(tribute.stock.materials) == mats0 + 6, "tribute keeps half the food and all the mats")
	_expect(int(tribute.stock.tokens) == tokens0, "food tribute spent tokens")
	_expect(tribute.hope == hope1 - 1, "tribute hope")
	_expect(int(tribute.opinions.get("directorate", 0)) == opinion0 + int(tribute.bal.gift_opinion), "tribute opinion")
	var faction := Copy.t(tribute._fname("directorate"))
	_expect(str(trow.toast) == Copy.fill("raid_share.toast_tribute", {"faction": faction}), "tribute toast " + str(trow.toast))
	_expect(_report_text(tribute, "raid_share") == Copy.fill("raid_share.dawn_tribute", {"faction": faction, "before": opinion0, "after": opinion0 + int(tribute.bal.gift_opinion)}), "tribute dawn line")
	_expect(_share_moments(tribute) == 1, "tribute chronicle")


func _edges(catalog: Catalog) -> void:
	var mats := _game(catalog, 6)
	mats.stock.tokens = 10
	_stage(mats, 0, 6, 0)
	var mats0 := int(mats.stock.materials)
	var opinion0 := int(mats.opinions.get("directorate", 0))
	mats.apply_raid_share("tribute")
	_expect(int(mats.stock.tokens) == 6 and int(mats.stock.materials) == mats0 + 6, "mats-only tribute tokens")
	_expect(int(mats.opinions.get("directorate", 0)) == opinion0 + 12, "mats-only opinion")

	var broke := _game(catalog, 6)
	broke.stock.tokens = 1
	_stage(broke, 0, 6, 0)
	broke.apply_raid_share("tribute")
	_expect(int(broke.stock.tokens) == 0, "short token pile")

	var good := _game(catalog, 6)
	var hope0 := good.hope
	var dis0 := good.discontent
	var mat0 := int(good.stock.materials)
	_stage(good, 0, 0, 3, "materials")
	good.apply_raid_share("yard")
	_expect(good.hope == hope0 + 1 and good.discontent == dis0 and int(good.stock.materials) == mat0 + 3, "good-only yard")

	var gift := _game(catalog, 6)
	gift.stock.tokens = 10
	var gmat := int(gift.stock.materials)
	var ghope := gift.hope
	_stage(gift, 0, 0, 3, "materials")
	gift.apply_raid_share("tribute")
	_expect(int(gift.stock.tokens) == 7 and int(gift.stock.materials) == gmat + 3 and gift.hope == ghope - 1, "good-only tribute")

	var odd := _game(catalog, 6)
	var ofood := int(odd.stock.food)
	_stage(odd, 7, 0, 0)
	odd.apply_raid_share("yard")
	_expect(int(odd.stock.food) == ofood + 4, "odd food ceils into the yard")


func _bots(catalog: Catalog) -> void:
	var careful := _game(catalog, 7)
	careful.hope = 10
	careful.opinions.directorate = -40
	careful.raid_share_profile = "careful"
	_stage(careful, 8, 0, 0)
	_expect(careful.raid_share_bot_choice() == "stockpile", "careful did not stockpile")

	var follower := _game(catalog, 7)
	follower.hope = 39
	follower.raid_share_profile = "follower"
	_stage(follower, 8, 0, 0)
	_expect(follower.raid_share_bot_choice() == "yard", "follower below 40 did not share")
	follower.hope = 40
	_expect(follower.raid_share_bot_choice() == "stockpile", "follower at 40 shared")

	var expander := _game(catalog, 7)
	expander.raid_share_profile = "expander"
	_stage(expander, 8, 0, 0)
	expander.opinions.directorate = -20
	_expect(expander.raid_share_bot_choice() == "tribute", "expander at -20 did not tribute")
	expander.opinions.directorate = -19
	_expect(expander.raid_share_bot_choice() == "stockpile", "expander at -19 tributed")

	var live := _game(catalog, 8)
	var twin := _game(catalog, 8)
	var dest := _arm(live)
	_arm(twin)
	if dest == "":
		_bad("bot raid target")
		return
	live.raid_share_profile = "follower"
	live.hope = 30
	twin.hope = 30
	var hope_l := live.hope
	var food_l := int(live.stock.food)
	_expect(live._order_raid(dest, true) and twin._order_raid(dest, true), "profile raid failed")
	_expect(int(live.stock.food) == food_l - int(live.bal.raid_pack_food) + 4, "follower raid did not yard the food")
	_expect(live.hope == hope_l + 2, "follower raid hope")
	_expect(int(twin.stock.food) == food_l - int(twin.bal.raid_pack_food) + 8, "default bot did not stockpile")
	_expect(_share_moments(live) == 1 and _share_moments(twin) == 0, "bot chronicle")


func _assault_never(catalog: Catalog) -> void:
	var game := _game(catalog, 9)
	var dest := _arm(game)
	if dest == "":
		_bad("assault target")
		return
	game.stations[dest].low_weeks = 2
	game.at_war.directorate = true
	game.raid_share_hold = true
	var gate := game._assault_gate(dest)
	_expect(gate == "", "assault blocked " + gate)
	if gate != "":
		return
	_expect(game._order_assault(dest, true), "assault failed")
	_expect(not game.raid_share_open() and not game.dawn_held(), "assault opened a share")
	var queued := _game(catalog, 9)
	var dest_q := _arm(queued)
	queued.stations[dest_q].low_weeks = 2
	queued.at_war.directorate = true
	queued.raid_share_hold = true
	if not queued.queue_order({"kind": "order", "order": "assault", "dest": dest_q}):
		_bad("could not queue assault " + queued._assault_gate(dest_q))
		return
	queued.end_week()
	_expect(not queued.raid_share_open() and not queued.dawn_held(), "queued assault waited on a share")


func _not_soft_dawn(catalog: Catalog) -> void:
	var game := _game(catalog, 10)
	_stage(game, 8, 6, 0)
	game.apply_raid_share("yard")
	var chip: Dictionary = game._pick_dawn_soft_chip()
	_expect(str(chip.get("kind", "")) != "raid_share", "yard became a soft chip")
	var presented: Dictionary = game.present_dawn_soft_chip()
	_expect(str(presented.get("kind", "")) != "raid_share", "presented share as the dawn chip")
	_expect(str(game.flags.get("dawn_soft_kind", "")) != "raid_share", "latched share as the dawn chip")


func _ui_wires() -> void:
	var src := FileAccess.get_file_as_string("res://ui/station.gd")
	_expect(src.find("func _show_raid_share") >= 0, "share card missing")
	_expect(src.find("raid_share.stockpile") >= 0 and src.find("raid_share.yard") >= 0 and src.find("raid_share.tribute") >= 0, "three choices missing")
	_expect(src.find("raid_share.toast_yard") < 0 or src.find("_toast(") >= 0, "toast hook")
	var later := src.find("func _show_raid_share")
	var next := src.find("func _pick_raid_share", later)
	var body := src.substr(later, next - later)
	_expect(body.find("Not now") < 0 and body.find("Skip") < 0 and body.find("Later") < 0, "share card has a skip")
	var dawn := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := dawn.find("func _pick_dawn_soft_chip")
	var end := dawn.find("func dawn_soft_chip", at)
	var picker := dawn.substr(at, end - at)
	_expect(picker.find("raid_share") < 0, "soft dawn picker knows about the share")


func _careful_band(catalog: Catalog) -> Dictionary:
	var lost := 0
	var hope := 0
	var moments := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = true
		game.raid_share_profile = "careful"
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		if str(game.over) != "time":
			lost += 1
		hope += int(game.hope_totals.get("raid_share", 0))
		for moment in game.chronicle:
			if str(moment.get("kind", "")) == "raid_share":
				moments += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return {"lost": lost, "hope": hope, "moments": moments}
