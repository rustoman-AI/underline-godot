extends SceneTree

## Headless balance gate on 30 seeds (docs/audit/balance_gate_decisions.md): careful, expander and follower play
## seeds 1 to 30 (or 30 seeds from --from). Gates the number of seeds each steward passes its own rules on, the
## seeds where the expander's mean hope is below the careful steward's, the expander's red check rate and the
## follower's white check rate. Each threshold is the worst of HEAD on seeds 1-30 and 31-60, minus 2 seeds.
##   godot --headless --path . -s res://sim/check_balance.gd [-- --from=31]

const SEEDS := 30
const MIN_CAREFUL := 18
const MIN_EXPANDER := 27
const MIN_FOLLOWER := 22
const MIN_HOPE_ORDER := 16
const RED := [45, 70]
const WHITE := [55, 85]


func _init() -> void:
	var first := 1
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--from="):
			first = int(str(arg).trim_prefix("--from="))
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("BALANCE CHECK FAILED: " + catalog.error)
		quit(1)
		return
	var passed := {"careful": 0, "expander": 0, "follower": 0}
	var hope_order := 0
	var red := [0, 0]
	var white := [0, 0]
	var misses: PackedStringArray = []
	for run_seed in range(first, first + SEEDS):
		var c: Dictionary = Bot.new().play(40, run_seed, "careful")
		var e: Dictionary = Bot.new().play(40, run_seed, "expander")
		var f: Dictionary = Bot.new().play(40, run_seed, "follower")
		for pair in [["careful", _careful_seed(c)], ["expander", _expander_seed(e)], ["follower", _follower_seed(f)]]:
			if str(pair[1]) == "":
				passed[pair[0]] += 1
			else:
				misses.append("%s seed %d: %s" % [pair[0], run_seed, pair[1]])
		if float(e.get("hope_avg", 99)) < float(c.get("hope_avg", 0)):
			hope_order += 1
		red[0] += int(e.get("check_red_success", 0))
		red[1] += int(e.get("check_red_rolls", 0))
		white[0] += int(f.get("check_white_success", 0))
		white[1] += int(f.get("check_white_rolls", 0))
	var red_pct: float = 100.0 * red[0] / maxi(red[1], 1)
	var white_pct: float = 100.0 * white[0] / maxi(white[1], 1)
	print("Balance over seeds %d-%d" % [first, first + SEEDS - 1])
	for line in misses:
		print("  " + line)
	var rows := [
		["careful seeds passing", passed.careful >= MIN_CAREFUL, "%d of %d, need %d" % [passed.careful, SEEDS, MIN_CAREFUL]],
		["expander seeds passing", passed.expander >= MIN_EXPANDER, "%d of %d, need %d" % [passed.expander, SEEDS, MIN_EXPANDER]],
		["follower seeds passing", passed.follower >= MIN_FOLLOWER, "%d of %d, need %d" % [passed.follower, SEEDS, MIN_FOLLOWER]],
		["expander hope below careful", hope_order >= MIN_HOPE_ORDER, "%d of %d, need %d" % [hope_order, SEEDS, MIN_HOPE_ORDER]],
		["expander red checks", red[1] > 0 and red_pct >= RED[0] and red_pct <= RED[1], "%d/%d (%.1f%%), need %d-%d%%" % [red[0], red[1], red_pct, RED[0], RED[1]]],
		["follower white checks", white[1] > 0 and white_pct >= WHITE[0] and white_pct <= WHITE[1], "%d/%d (%.1f%%), need %d-%d%%" % [white[0], white[1], white_pct, WHITE[0], WHITE[1]]],
	]
	var ok := true
	for row in rows:
		ok = ok and bool(row[1])
		print("%s: %s (%s)" % [row[0], "ok" if row[1] else "FAIL", row[2]])
	print("BALANCE CHECK OK" if ok else "BALANCE CHECK FAILED")
	quit(0 if ok else 1)


## Careful: lives to week 40 without errors, at most 2 shortage weeks, discontent peak 35 to 55, 45 to 70
## people at week 40, food buffer median 2 to 4.
static func _careful_seed(row: Dictionary) -> String:
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
	return ", ".join(why)


## Expander: ends by time or revolt without errors, at most 5 shortage weeks, hope never below 20. Its
## discontent peak is judged across seeds by bot_run's Expander discontent gate.
static func _expander_seed(row: Dictionary) -> String:
	var why: PackedStringArray = []
	var over := str(row.get("over", ""))
	if not row.get("errors", []).is_empty() or (over != "time" and over != "revolt"):
		why.append(str(row.get("over", "error")))
	if int(row.get("shortage_weeks", 0)) > 5:
		why.append("short %d" % int(row.shortage_weeks))
	if int(row.get("hope_min", 0)) < 20:
		why.append("hope %d" % int(row.hope_min))
	return ", ".join(why)


## Follower: lives to week 40, food buffer median at least 1.5, hope never below 15, discontent peak at most 65,
## at least 45 people at week 40, at most 3 shortage weeks.
static func _follower_seed(row: Dictionary) -> String:
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
	return ", ".join(why)
