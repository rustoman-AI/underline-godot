extends SceneTree

## Headless gate: formula checks, then five seeds of each steward.
##   godot --headless --path . -s res://sim/bot_run.gd


func _init() -> void:
	var failed := false
	var formula_errors := Formulas.self_check()
	if formula_errors.is_empty():
		print("Formulas: ok")
	else:
		failed = true
		print("Formulas: FAIL")
		for err in formula_errors:
			print("  ", err)
	var careful: Array = []
	var expander: Array = []
	var follower: Array = []
	for run_seed in [1, 2, 3, 4, 5]:
		careful.append(Bot.new().play(40, run_seed, "careful"))
		expander.append(Bot.new().play(40, run_seed, "expander"))
		follower.append(Bot.new().play(40, run_seed, "follower"))
	print("")
	_print_table("Careful", careful)
	print("")
	_print_table("Expander", expander)
	print("")
	_print_table("Follower", follower)
	print("")
	_print_causes("Careful", careful)
	_print_causes("Expander", expander)
	_print_causes("Follower", follower)
	print("")
	_print_checks("Careful", careful)
	_print_checks("Expander", expander)
	_print_checks("Follower", follower)
	print("")
	_print_follower(follower)
	print("")
	_print_hope(expander[0])
	print("")
	_print_dis(careful)
	print("")
	if not _careful_ok(careful):
		failed = true
		print("CAREFUL TARGET FAIL")
		_print_failures(careful)
	else:
		print("Careful target: ok")
	if not _hope_ok(careful, expander):
		failed = true
		print("HOPE TARGET FAIL")
	else:
		print("Hope target: ok")
	if not _expander_ok(careful, expander):
		failed = true
		print("EXPANDER TARGET FAIL")
		_print_failures(expander)
	else:
		print("Expander target: ok")
	if not _payback_ok(careful, expander):
		failed = true
		print("OUTPOST PAYBACK FAIL")
	else:
		print("Outpost payback: ok")
	if not _follower_ok(follower):
		failed = true
		print("FOLLOWER TARGET FAIL")
	else:
		print("Follower target: ok")
	print("")
	_print_network(careful, expander, follower)
	if not _network_ok(careful, expander, follower):
		failed = true
		print("NETWORK TARGET FAIL")
	else:
		print("Network target: ok")
	print("")
	_print_seed_gates(careful, expander, follower)
	if not _checks_ok("Careful", careful):
		failed = true
		print("CHECK TARGET FAIL careful")
	if not _checks_ok("Expander", expander):
		failed = true
		print("CHECK TARGET FAIL expander")
	if not _checks_ok("Follower", follower):
		failed = true
		print("CHECK TARGET FAIL follower")
	print("")
	_print_banners()
	print("")
	if failed:
		print("BOT RUN FAILED")
		quit(1)
	else:
		print("BOT RUN OK")
		quit(0)


func _checks_ok(title: String, rows: Array) -> bool:
	var white_rolls := 0
	var white_wins := 0
	var red_rolls := 0
	var red_wins := 0
	var passed := 0
	for row in rows:
		white_rolls += int(row.get("check_white_rolls", 0))
		white_wins += int(row.get("check_white_success", 0))
		red_rolls += int(row.get("check_red_rolls", 0))
		red_wins += int(row.get("check_red_success", 0))
		passed += int(row.get("check_retry_passed", 0))
	var ok := true
	var white_pct := _pct_n(white_wins, white_rolls)
	var red_pct := _pct_n(red_wins, red_rolls)
	if white_rolls <= 0 or white_pct < 55 or white_pct > 80:
		ok = false
		print("  %s white %s outside 55-80" % [title, _pct(white_wins, white_rolls)])
	if red_rolls <= 0 or red_pct < 40 or red_pct > 70:
		ok = false
		print("  %s red %s outside 40-70" % [title, _pct(red_wins, red_rolls)])
	if passed < 3:
		ok = false
		print("  %s white retries passed %d, need 3" % [title, passed])
	if ok:
		print("%s checks: pass" % title)
	return ok


func _pct_n(won: int, rolls: int) -> int:
	if rolls <= 0:
		return -1
	return int(round(float(won) * 100.0 / float(rolls)))


func _print_seed_gates(careful: Array, expander: Array, follower: Array) -> void:
	print("Per seed")
	for row in careful:
		print("  careful   seed %d  %s" % [int(row.seed), _careful_seed(row)])
	for row in expander:
		print("  expander  seed %d  %s" % [int(row.seed), _expander_seed(row)])
	for row in follower:
		print("  follower  seed %d  %s" % [int(row.seed), _follower_seed(row)])
	for bundle in [["careful", careful], ["expander", expander], ["follower", follower]]:
		for row in bundle[1]:
			var ult := int(row.get("first_ultimatum", 0))
			var flip := int(row.get("flip_week", 0))
			var net := "pass"
			var why: PackedStringArray = []
			if ult < 6 or ult > 16:
				why.append("ult %d" % ult)
			if flip < 4:
				why.append("flip %d" % flip)
			if not why.is_empty():
				net = "FAIL " + ", ".join(why)
			print("  network   %s seed %d  %s" % [str(bundle[0]), int(row.seed), net])


func _careful_seed(row: Dictionary) -> String:
	var why: PackedStringArray = []
	if not row.get("errors", []).is_empty() or str(row.get("over", "")) != "time":
		why.append(str(row.get("over", "error")))
	var shorts := int(row.get("shortage_weeks", 0))
	if shorts < 0 or shorts > 2:
		why.append("short %d" % shorts)
	var peak := int(row.get("dis_max", 0))
	if peak < 35 or peak > 55:
		why.append("dis %d" % peak)
	var pop := int(row.get("pop40", 0))
	if pop < 45 or pop > 70:
		why.append("pop %d" % pop)
	var med := float(row.get("food_med", 0))
	if med < 2.0 or med > 4.0:
		why.append("food %.1f" % med)
	if why.is_empty():
		return "pass"
	return "FAIL " + ", ".join(why)


func _expander_seed(row: Dictionary) -> String:
	var why: PackedStringArray = []
	if not row.get("errors", []).is_empty() or str(row.get("over", "")) != "time":
		why.append(str(row.get("over", "error")))
	if int(row.get("shortage_weeks", 0)) > 5:
		why.append("short %d" % int(row.shortage_weeks))
	if int(row.get("hope_min", 0)) < 20:
		why.append("hope %d" % int(row.hope_min))
	if int(row.get("dis_max", 0)) > 75:
		why.append("dis %d" % int(row.dis_max))
	if why.is_empty():
		return "pass"
	return "FAIL " + ", ".join(why)


func _follower_seed(row: Dictionary) -> String:
	var why: PackedStringArray = []
	if int(row.get("week", 0)) < 40 or str(row.get("over", "")) != "time":
		why.append(str(row.get("over", "short")))
	if float(row.get("food_med", 0)) < 1.5:
		why.append("food %.1f" % float(row.food_med))
	if int(row.get("hope_min", 0)) < 15:
		why.append("hope %d" % int(row.hope_min))
	if int(row.get("dis_max", 0)) > 65:
		why.append("dis %d" % int(row.dis_max))
	if int(row.get("pop40", 0)) < 45:
		why.append("pop %d" % int(row.pop40))
	if int(row.get("shortage_weeks", 0)) > 3:
		why.append("short %d" % int(row.shortage_weeks))
	if why.is_empty():
		return "pass"
	return "FAIL " + ", ".join(why)


func _print_banners() -> void:
	var want := ["expedition", "moles", "showtime", "cough", "brownout"]
	var missing: PackedStringArray = []
	for id in want:
		if not FileAccess.file_exists("res://assets/events/%s.webp" % id):
			missing.append(id)
	if missing.is_empty():
		print("Missing banners: none")
	else:
		print("Missing banners: %s" % ", ".join(missing))


func _print_network(careful: Array, expander: Array, follower: Array) -> void:
	print("Network gates")
	print("profile    seed  ult  flip  unrest  stations  influence  over      first flip")
	for row in careful:
		_print_net_row("careful", row)
	for row in expander:
		_print_net_row("expander", row)
	for row in follower:
		_print_net_row("follower", row)


func _print_net_row(profile: String, row: Dictionary) -> void:
	var who := "%s %s -> %s" % [str(row.get("flip_name", "")), str(row.get("flip_from", "")), str(row.get("flip_to", ""))]
	print("%-9s  %4d  %3d  %4d  %6d  %8d  %9d  %-8s  %s" % [
		profile,
		int(row.get("seed", 0)),
		int(row.get("first_ultimatum", 0)),
		int(row.get("flip_week", 0)),
		int(row.get("unrest_weeks", 0)),
		int(row.get("stations", 0)),
		int(row.get("influence", 0)),
		str(row.get("over", "")),
		who,
	])


func _network_ok(careful: Array, expander: Array, follower: Array) -> bool:
	var ok := true
	for bundle in [["careful", careful], ["expander", expander], ["follower", follower]]:
		var rows: Array = bundle[1]
		if _one_week(rows, "first_ultimatum"):
			ok = false
			print("  %s ultimatum week is the same on every seed" % str(bundle[0]))
		if _one_week(rows, "flip_week"):
			ok = false
			print("  %s flip week is the same on every seed" % str(bundle[0]))
		for row in rows:
			var ult := int(row.get("first_ultimatum", 0))
			if ult < 6 or ult > 16:
				ok = false
				print("  ultimatum week %d on %s seed %d" % [ult, str(bundle[0]), int(row.seed)])
			var flip := int(row.get("flip_week", 0))
			if flip < 4:
				ok = false
				print("  flip week %d on %s seed %d" % [flip, str(bundle[0]), int(row.seed)])
	var careful_stations := 0
	var expander_stations := 0
	var careful_unrest := 0
	var expander_unrest := 0
	for row in careful:
		careful_stations += int(row.get("stations", 0))
		careful_unrest += int(row.get("unrest_weeks", 0))
	for row in expander:
		expander_stations += int(row.get("stations", 0))
		expander_unrest += int(row.get("unrest_weeks", 0))
	if expander_stations <= careful_stations:
		ok = false
		print("  expander stations %d, careful %d" % [expander_stations, careful_stations])
	if expander_unrest <= careful_unrest:
		ok = false
		print("  expander unrest %d, careful %d" % [expander_unrest, careful_unrest])
	var lived := 0
	for row in follower:
		if int(row.get("week", 0)) >= 40 and str(row.get("over", "")) == "time":
			lived += 1
	if lived < 4:
		ok = false
		print("  follower reached week 40 on %d of 5" % lived)
	return ok


func _one_week(rows: Array, key: String) -> bool:
	if rows.is_empty():
		return true
	var first := int(rows[0].get(key, 0))
	for row in rows:
		if int(row.get(key, 0)) != first:
			return false
	return true


func _print_follower(rows: Array) -> void:
	print("Follower gates")
	print("seed  over      wk  power0  unafford  events15  deals  st25")
	for row in rows:
		print("%-4d  %-8s  %2d  %6d  %8d  %8d  %5d  %5d" % [
			int(row.get("seed", 0)),
			str(row.get("over", "?")),
			int(row.get("week", 0)),
			int(row.get("power_zero_max", 0)),
			int(row.get("unaffordable_dawn", 0)),
			int(row.get("events_by_15", 0)),
			int(row.get("deals_w10", 0)),
			int(row.get("stations_w25", 0)),
		])


func _follower_ok(rows: Array) -> bool:
	var lived := 0
	var fed := 0
	var hopeful := 0
	var calm := 0
	var dealt := 0
	var widened := 0
	var ok := true
	for row in rows:
		if int(row.get("power_zero_max", 0)) > 2:
			ok = false
			print("  power at 0 for %d weeks, seed %d" % [int(row.power_zero_max), int(row.seed)])
		if int(row.get("unaffordable_dawn", 0)) > 0:
			ok = false
			print("  unaffordable dawn %d, seed %d" % [int(row.unaffordable_dawn), int(row.seed)])
		if int(row.get("events_by_15", 0)) < 12:
			ok = false
			print("  events by week 15 = %d, seed %d" % [int(row.events_by_15), int(row.seed)])
		if int(row.get("week", 0)) >= 40 and str(row.get("over", "")) == "time":
			lived += 1
		if float(row.get("food_med", 0)) >= 1.5:
			fed += 1
		if int(row.get("hope_min", 0)) >= 15:
			hopeful += 1
		if int(row.get("week", 0)) >= 40 and str(row.get("over", "")) == "time" and int(row.get("dis_max", 0)) <= 65:
			calm += 1
		if int(row.get("dis_max", 0)) > 65:
			ok = false
			print("  discontent peak %d, seed %d" % [int(row.dis_max), int(row.seed)])
		if int(row.get("pop40", 0)) < 45:
			ok = false
			print("  population %d at week 40, seed %d" % [int(row.pop40), int(row.seed)])
		if int(row.get("shortage_weeks", 0)) > 3:
			ok = false
			print("  shortage weeks %d, seed %d" % [int(row.shortage_weeks), int(row.seed)])
		if int(row.get("deals_w10", 0)) >= 1:
			dealt += 1
		if int(row.get("stations_w25", 0)) >= 2:
			widened += 1
	if lived < 5:
		ok = false
		print("  reached week 40 on %d of 5 seeds" % lived)
	if fed < 5:
		ok = false
		print("  food buffer median at least 1.5 on %d of 5 seeds" % fed)
	if hopeful < 5:
		ok = false
		print("  hope min at least 15 on %d of 5 seeds" % hopeful)
	if calm < 4:
		ok = false
		print("  discontent peak at most 65 on %d of 5 seeds" % calm)
	if dealt < 4:
		ok = false
		print("  trade deal by week 10 on %d of 5 seeds" % dealt)
	if widened < 4:
		ok = false
		print("  two stations by week 25 on %d of 5 seeds" % widened)
	return ok


func _print_checks(title: String, rows: Array) -> void:
	var white_rolls := 0
	var white_wins := 0
	var red_rolls := 0
	var red_wins := 0
	var retried := 0
	var retry_passed := 0
	for row in rows:
		white_rolls += int(row.get("check_white_rolls", 0))
		white_wins += int(row.get("check_white_success", 0))
		red_rolls += int(row.get("check_red_rolls", 0))
		red_wins += int(row.get("check_red_success", 0))
		retried += int(row.get("check_retried", 0))
		retry_passed += int(row.get("check_retry_passed", 0))
	print("%s checks  white %d/%d (%s)  red %d/%d (%s)  retried %d passed %d" % [
		title, white_wins, white_rolls, _pct(white_wins, white_rolls),
		red_wins, red_rolls, _pct(red_wins, red_rolls), retried, retry_passed,
	])


func _pct(won: int, rolls: int) -> String:
	if rolls <= 0:
		return "n/a"
	return "%d%%" % int(round(float(won) * 100.0 / float(rolls)))


func _print_causes(title: String, rows: Array) -> void:
	print("%s shortages" % title)
	for row in rows:
		var bits: PackedStringArray = []
		for item in row.get("shortage_causes", []):
			bits.append("W%d %s" % [int(item.week), str(item.cause)])
		var line := ", ".join(bits) if bits.size() > 0 else "none"
		print("  seed %d  %s" % [int(row.get("seed", 0)), line])


func _print_table(title: String, rows: Array) -> void:
	print(title)
	print("seed  over      wk  short  first  food min/med/max     hope     dis      pop 10/20/40   unrest  stations")
	for row in rows:
		var first := "none" if int(row.get("first_shortage", 0)) <= 0 else str(int(row.first_shortage))
		print("%-4d  %-8s  %2d  %5d  %5s  %4.1f / %4.1f / %4.1f  %3d/%-3d  %3d/%-3d  %3s/%3s/%3s  %6d  %8d" % [
			int(row.get("seed", 0)) if row.has("seed") else _seed_from(row),
			str(row.get("over", "?")),
			int(row.get("week", 0)),
			int(row.get("shortage_weeks", 0)),
			first,
			float(row.get("food_min", 0)),
			float(row.get("food_med", 0)),
			float(row.get("food_max", 0)),
			int(row.get("hope_min", 0)),
			int(row.get("hope_max", 0)),
			int(row.get("dis_min", 0)),
			int(row.get("dis_max", 0)),
			_pop(row, "pop10"),
			_pop(row, "pop20"),
			_pop(row, "pop40"),
			int(row.get("unrest_weeks", 0)),
			int(row.get("stations", 0)),
		])


func _seed_from(row: Dictionary) -> int:
	var summary := str(row.get("summary", ""))
	if summary.begins_with("Seed "):
		var parts := summary.split(" ")
		if parts.size() > 1:
			return int(parts[1].rstrip(":"))
	return 0


func _pop(row: Dictionary, key: String) -> String:
	var n := int(row.get(key, -1))
	if n < 0:
		return "-"
	return str(n)


func _careful_ok(rows: Array) -> bool:
	for row in rows:
		if not row.get("errors", []).is_empty():
			return false
		if str(row.get("over", "")) != "time":
			return false
		var shorts := int(row.get("shortage_weeks", 0))
		if shorts < 0 or shorts > 2:
			return false
		var peak := int(row.get("dis_max", 0))
		if peak < 35 or peak > 55:
			return false
		var pop := int(row.get("pop40", 0))
		if pop < 45 or pop > 70:
			return false
		var med := float(row.get("food_med", 0))
		if med < 2.0 or med > 4.0:
			return false
	return true


func _payback_ok(careful: Array, expander: Array) -> bool:
	var ok := true
	var careful_stations := 0
	var expander_stations := 0
	var careful_influence := 0
	var expander_influence := 0
	for row in careful:
		careful_stations += int(row.get("stations", 0))
		careful_influence += int(row.get("influence", 0))
	for row in expander:
		expander_stations += int(row.get("stations", 0))
		expander_influence += int(row.get("influence", 0))
		if int(row.get("hope_min", 0)) < 20:
			ok = false
			print("  expander hope min %d, seed %d" % [int(row.hope_min), int(row.seed)])
		if int(row.get("dis_max", 0)) > 75:
			ok = false
			print("  expander discontent peak %d, seed %d" % [int(row.dis_max), int(row.seed)])
		if int(row.get("week", 0)) < 40 or str(row.get("over", "")) != "time":
			ok = false
			print("  expander lost before week 40, seed %d (%s week %d)" % [int(row.seed), str(row.over), int(row.week)])
	if expander_stations <= careful_stations:
		ok = false
		print("  expander stations %d, careful %d" % [expander_stations, careful_stations])
	if expander_influence <= careful_influence:
		ok = false
		print("  expander influence %d, careful %d" % [expander_influence, careful_influence])
	return ok


func _hope_ok(careful: Array, expander: Array) -> bool:
	var lower := 0
	for i in careful.size():
		if float(expander[i].get("hope_avg", 99)) < float(careful[i].get("hope_avg", 0)):
			lower += 1
	return lower >= 4


func _expander_ok(careful: Array, rows: Array) -> bool:
	var alive := 0
	var careful_unrest := 0.0
	var expander_unrest := 0.0
	var careful_dis := 0.0
	var expander_dis := 0.0
	for row in careful:
		careful_unrest += float(row.get("unrest_weeks", 0))
		careful_dis += float(row.get("dis_max", 0))
	for row in rows:
		if not row.get("errors", []).is_empty():
			return false
		if int(row.get("shortage_weeks", 0)) > 5:
			return false
		if int(row.get("week", 0)) >= 25:
			alive += 1
		expander_unrest += float(row.get("unrest_weeks", 0))
		expander_dis += float(row.get("dis_max", 0))
	if alive < 3:
		return false
	var more_unrest: bool = expander_unrest > careful_unrest * 1.25
	var more_discontent: bool = expander_dis > careful_dis + 5.0 * float(rows.size())
	return more_unrest or more_discontent


func _print_hope(row: Dictionary) -> void:
	print("Hope sources, expander seed %d (applied deltas)" % int(row.get("seed", 1)))
	var totals: Dictionary = row.get("hope_sources", {})
	var ranked: Array = []
	for source in totals.keys():
		ranked.append({"source": str(source), "total": int(totals[source])})
	ranked.sort_custom(func(a, b): return absi(int(a.total)) > absi(int(b.total)))
	for item in ranked:
		print("  %-12s %+d" % [str(item.source), int(item.total)])
	print("Per week:")
	for entry in row.get("hope_history", []):
		var bits: PackedStringArray = []
		var deltas: Dictionary = entry.get("deltas", {})
		for source in deltas.keys():
			bits.append("%s %+d" % [str(source), int(deltas[source])])
		if bits.is_empty():
			bits.append("flat")
		print("  W%02d hope %d  %s" % [int(entry.week), int(entry.hope), ", ".join(bits)])


func _print_dis(rows: Array) -> void:
	print("Discontent sources, careful")
	for row in rows:
		var totals: Dictionary = row.get("dis_sources", {})
		var bits: PackedStringArray = []
		for source in totals.keys():
			bits.append("%s %+d" % [str(source), int(totals[source])])
		print("  seed %d peak %d  %s" % [int(row.seed), int(row.dis_max), ", ".join(bits)])


func _print_failures(rows: Array) -> void:
	for row in rows:
		var errors = row.get("errors", [])
		if str(row.get("over", "")) != "time" or not errors.is_empty():
			print(str(row.get("summary", "")))
			print("")
