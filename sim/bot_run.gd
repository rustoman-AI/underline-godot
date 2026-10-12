extends SceneTree

## Headless gate: formula checks, then five seeds of each steward (run integrity and the network pacing; the
## balance targets live in sim/check_balance.gd on 30 seeds), the expander's discontent on 30 seeds, then the
## leader audience checks.
##   godot --headless --path . -s res://sim/bot_run.gd

const AudienceChecks = preload("res://sim/audience_checks.gd")


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
	if not _integrity_ok([careful, expander, follower], follower):
		failed = true
		print("RUN INTEGRITY FAIL")
		_print_failures(careful + expander + follower)
	else:
		print("Run integrity: ok")
	if not _expander_discontent_ok():
		failed = true
		print("EXPANDER DISCONTENT FAIL")
	else:
		print("Expander discontent: ok")
	print("")
	_print_network(careful, expander, follower)
	if not _network_ok(careful, expander, follower):
		failed = true
		print("NETWORK TARGET FAIL")
	else:
		print("Network target: ok")
	print("")
	var catalog := Catalog.new()
	var audience: Dictionary = AudienceChecks.run(catalog) if catalog.load_all() else {"ok": false, "lines": ["FAIL catalog " + catalog.error]}
	if audience.ok:
		print("Audience checks: ok")
	else:
		failed = true
		print("AUDIENCE CHECK FAIL")
		for line in audience.lines:
			if str(line).begins_with("FAIL"):
				print("  ", line)
	print("")
	_print_banners()
	print("")
	if failed:
		print("BOT RUN FAILED")
		quit(1)
	else:
		print("BOT RUN OK")
		quit(0)


## Every run ends cleanly (no sim errors, an end state other than an error); the follower never sits at 0 power
## for more than 2 weeks, never meets a dawn it cannot pay for, and sees at least 12 events by week 15.
func _integrity_ok(bundles: Array, follower: Array) -> bool:
	var ok := true
	for rows in bundles:
		for row in rows:
			var over := str(row.get("over", ""))
			if not row.get("errors", []).is_empty() or over == "" or over == "error":
				ok = false
				print("  %s seed %d: over '%s', errors %s" % [str(row.get("profile", "")), int(row.get("seed", 0)), over, str(row.get("errors", []))])
	for row in follower:
		if int(row.get("power_zero_max", 0)) > 2:
			ok = false
			print("  power at 0 for %d weeks, seed %d" % [int(row.power_zero_max), int(row.seed)])
		if int(row.get("unaffordable_dawn", 0)) > 0:
			ok = false
			print("  unaffordable dawn %d, seed %d" % [int(row.unaffordable_dawn), int(row.seed)])
		if int(row.get("events_by_15", 0)) < 12:
			ok = false
			print("  events by week 15 = %d, seed %d" % [int(row.events_by_15), int(row.seed)])
	return ok


## The expander's discontent against the same game without story beats, seeds 1 to 30 (docs/audit/
## balance_gate_decisions.md): at most one seed fewer with a peak of 75 or less, a mean peak at most 2 higher, at
## most one more revolt. The base game itself misses an absolute 75 on a third of the seeds.
func _expander_discontent_ok() -> bool:
	var tally := {"plain": {"under": 0, "sum": 0, "revolts": 0}, "full": {"under": 0, "sum": 0, "revolts": 0}}
	for run_seed in range(1, 31):
		for mode in ["plain", "full"]:
			var cat := Catalog.new()
			if not cat.load_all():
				print("  catalog failed to load")
				return false
			if mode == "plain":
				cat.events = cat.events.filter(func(ev): return not _story_beat(ev))
			var row: Dictionary = Bot.new().play(40, run_seed, "expander", cat)
			var peak := int(row.get("dis_max", 0))
			tally[mode].sum += peak
			if peak <= 75:
				tally[mode].under += 1
			if str(row.get("over", "")) == "revolt":
				tally[mode].revolts += 1
	var a: Dictionary = tally.plain
	var b: Dictionary = tally.full
	var mean_a := float(a.sum) / 30.0
	var mean_b := float(b.sum) / 30.0
	print("  expander over 30 seeds, without story beats / with: peak <= 75 in %d / %d, mean peak %.1f / %.1f, revolts %d / %d" % [
		int(a.under), int(b.under), mean_a, mean_b, int(a.revolts), int(b.revolts)])
	return int(b.under) >= int(a.under) - 1 and mean_b <= mean_a + 2.0 and int(b.revolts) <= int(a.revolts) + 1


## An event with "needs" that is not forced; leader consequences (needs.leader) are forced unless they say otherwise.
static func _story_beat(ev: Dictionary) -> bool:
	var needs = ev.get("needs", null)
	return needs is Dictionary and not bool(ev.get("forced", needs.has("leader")))


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
