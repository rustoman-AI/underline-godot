extends SceneTree

## Leader consequence tuning probe: the bot_run seeds and stewards, played with every consequence off, every one on,
## and each one alone, so a failing balance gate can be traced to the events and choices that move it.
##   godot --headless --path . -s res://.tools/lc_tune.gd [-- --solo] [-- --style=accept_all]
## Prints, per configuration, the bot_run balance gates this probe can rebuild (hope, outpost payback, careful
## discontent band) with the numbers behind them, then every consequence pick in the expander runs that failed.

const SEEDS := [1, 2, 3, 4, 5]
const PROFILES := ["careful", "expander", "follower"]
const WEEKS := 40

var style := "silence"


class TuneGame extends Game:
	var only: Array = []
	var off := false
	var picks: Array = []

	func needs_window(ev: Dictionary) -> int:
		if off or (not only.is_empty() and not only.has(str(ev.get("id", "")))):
			return -1
		return super(ev)

	func _apply_event(action: Dictionary) -> bool:
		var front: Dictionary = pending[0] if not pending.is_empty() else {}
		var watch: bool = front.has("needs") and str(front.id) == str(action.get("event_id", ""))
		var h := hope
		var d := discontent
		var ok := super(action)
		if ok and watch:
			picks.append({"event": str(front.id), "choice": str(action.get("choice_id", "")), "week": week,
				"hope": hope - h, "dis": discontent - d})
		return ok


func _initialize() -> void:
	var solo := false
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a == "--solo":
			solo = true
		if a.begins_with("--style="):
			style = a.trim_prefix("--style=")
		if a.begins_with("--trace="):
			var bits := a.trim_prefix("--trace=").split(":")
			_trace(bits[0], int(bits[1]))
			quit(0)
			return
	var catalog := Catalog.new()
	catalog.load_all()
	var ids: Array = []
	for ev in catalog.events:
		if ev.has("needs"):
			ids.append(str(ev.id))
	var base := _config("off", true, [])
	var all := _config("all", false, [])
	if solo:
		for id in ids:
			_config(id, false, [id], base)
	_picks(all)
	quit(0)


func _play(profile: String, run_seed: int, off: bool, only: Array) -> Dictionary:
	var catalog := Catalog.new()
	catalog.load_all()
	var game := TuneGame.new()
	game.off = off
	game.only = only
	game.setup(catalog, run_seed, WEEKS)
	game.audit = profile != "follower"
	var bot := Bot.new()
	bot.profile = profile
	bot.audience_style = style
	var guard := 0
	var trace: PackedStringArray = []
	while game.over == "" and guard < WEEKS + 2:
		guard += 1
		var shown: PackedStringArray = []
		for ev in game.pending:
			shown.append(str(ev.id))
		bot._act(game)
		game.end_week()
		trace.append("w%02d hope %d dis %d food %d tok %d mat %d st %d  %s" % [game.week - 1, game.hope, game.discontent,
			int(game.stock.food), int(game.stock.tokens), int(game.stock.materials), _owned(game), " ".join(shown)])
	var report := game.report()
	report["trace"] = trace
	report["picks"] = game.picks.duplicate(true)
	return report


func _owned(game: Game) -> int:
	var n := 0
	for sid in game.stations:
		if str(game.stations[sid].owner) == str(game.player):
			n += 1
	return n


func _trace(profile: String, run_seed: int) -> void:
	var off := _play(profile, run_seed, true, [])
	var on := _play(profile, run_seed, false, [])
	print("")
	print("Trace %s seed %d: consequences off | on" % [profile, run_seed])
	for i in maxi(off.trace.size(), on.trace.size()):
		var a: String = off.trace[i] if i < off.trace.size() else ""
		var b: String = on.trace[i] if i < on.trace.size() else ""
		print("  %-90s | %s" % [a, b])
	print(str(on.get("dis_sources", {})))
	print(str(off.get("dis_sources", {})))


func _config(name: String, off: bool, only: Array, base: Dictionary = {}) -> Dictionary:
	var runs := {}
	for profile in PROFILES:
		runs[profile] = []
		for s in SEEDS:
			runs[profile].append(_play(profile, s, off, only))
	var lower := 0
	var bits: PackedStringArray = []
	for i in SEEDS.size():
		var c: Dictionary = runs.careful[i]
		var e: Dictionary = runs.expander[i]
		if float(e.get("hope_avg", 99)) < float(c.get("hope_avg", 0)):
			lower += 1
		bits.append("s%d hope c%.1f e%.1f dis c%d e%d f%d hmin e%d over %s/%s/%s" % [SEEDS[i], float(c.hope_avg), float(e.hope_avg),
			int(c.dis_max), int(e.dis_max), int(runs.follower[i].dis_max), int(e.hope_min), str(c.over), str(e.over), str(runs.follower[i].over)])
	var payback := true
	for e in runs.expander:
		if int(e.dis_max) > 75 or int(e.hope_min) < 20 or str(e.over) != "time":
			payback = false
	var careful_band := true
	for c in runs.careful:
		if int(c.dis_max) < 35 or int(c.dis_max) > 55 or str(c.over) != "time":
			careful_band = false
	var verdict := "hope %s (%d of 5 lower), payback %s, careful band %s" % [
		"ok" if lower >= 4 else "FAIL", lower, "ok" if payback else "FAIL", "ok" if careful_band else "FAIL"]
	print("== %s [%s]: %s" % [name, style, verdict])
	for b in bits:
		print("   " + b)
	return runs


func _picks(runs: Dictionary) -> void:
	print("")
	print("Consequence picks with everything on (profile seed week event choice hope dis):")
	var sums := {}
	for profile in PROFILES:
		for row in runs[profile]:
			for p in row.picks:
				print("  %-8s s%d w%02d %-24s %-9s hope %+d dis %+d" % [profile, int(row.seed), int(p.week), str(p.event), str(p.choice), int(p.hope), int(p.dis)])
				var key := "%s/%s" % [p.event, p.choice]
				if not sums.has(key):
					sums[key] = {"n": 0, "hope": 0, "dis": 0}
				sums[key].n += 1
				sums[key].hope += int(p.hope)
				sums[key].dis += int(p.dis)
	print("")
	print("Per choice: picks, mean applied hope, mean applied discontent")
	for key in sums:
		var s: Dictionary = sums[key]
		print("  %-36s %2d  %+.1f  %+.1f" % [key, int(s.n), float(s.hope) / s.n, float(s.dis) / s.n])
