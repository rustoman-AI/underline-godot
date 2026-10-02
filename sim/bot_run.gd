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
	for run_seed in [1, 2, 3, 4, 5]:
		careful.append(Bot.new().play(40, run_seed, "careful"))
		expander.append(Bot.new().play(40, run_seed, "expander"))
	print("")
	_print_table("Careful", careful)
	print("")
	_print_table("Expander", expander)
	print("")
	if not _careful_ok(careful):
		failed = true
		print("CAREFUL TARGET FAIL")
		_print_failures(careful)
	else:
		print("Careful target: ok")
	if not _expander_ok(careful, expander):
		failed = true
		print("EXPANDER TARGET FAIL")
		_print_failures(expander)
	else:
		print("Expander target: ok")
	print("")
	if failed:
		print("BOT RUN FAILED")
		quit(1)
	else:
		print("BOT RUN OK")
		quit(0)


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
	var early := 0
	for row in rows:
		if not row.get("errors", []).is_empty():
			return false
		if str(row.get("over", "")) != "time":
			return false
		var med := float(row.get("food_med", 0))
		if med < 2.0 or med > 4.0:
			return false
		if int(row.get("first_shortage", 0)) > 0 and int(row.first_shortage) <= 8:
			early += 1
	return early >= 3


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
		if int(row.get("shortage_weeks", 0)) < 3:
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


func _print_failures(rows: Array) -> void:
	for row in rows:
		var errors = row.get("errors", [])
		if str(row.get("over", "")) != "time" or not errors.is_empty():
			print(str(row.get("summary", "")))
			print("")
