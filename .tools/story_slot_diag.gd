extends SceneTree

## Story slot diagnosis: one bot run played twice, without the story slot and with it, printed week by week side
## by side: discontent and its change with the sources behind it, hope, food, air, the season, food or air
## shortages, and the events of the week split into the random pool, leader consequences and story beats.
##   godot --headless --path . -s res://.tools/story_slot_diag.gd -- --profile=expander --seed=1

const WEEKS := 40

## --windows=st1_names:15-19,st1_child:15-19 tries other needs.week windows in memory, data untouched.
var windows := {}


class DiagGame extends Game:
	var slot_off := false
	var rows: Array = []
	var why := {}

	func _offer_story_event() -> void:
		why[week] = _busy_reason()
		if not slot_off:
			super()

	func _busy_reason() -> String:
		var others := 0
		for id in week_event_ids:
			var ev := _event_by_id(str(id))
			if ev.has("needs"):
				if Game.needs_forced(ev):
					return "leader"
				continue
			others += 1
		if not active_season.is_empty():
			return "season"
		if others >= 3:
			return "busy"
		var causes: Array = stats.get("shortage_causes", [])
		if not causes.is_empty() and int(causes[-1].week) == week - 1 and str(causes[-1].cause) != "power":
			return "short"
		if int(stock.food) + output_of("food") < food_need() or int(stock.air) + output_of("air") < air_need():
			return "low"
		return "free"

	func _flush_hope_week() -> void:
		rows.append({"week": week, "dis": discontent, "hope": hope, "food": int(stock.food), "air": int(stock.air),
			"season": str(active_season.get("id", "")), "sources": dis_week.duplicate()})
		super()


func _initialize() -> void:
	var profile := "expander"
	var run_seed := 1
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--windows="):
			for part in str(arg).trim_prefix("--windows=").split(","):
				var bits := part.split(":")
				var span := bits[1].split("-")
				windows[bits[0]] = [int(span[0]), int(span[1])]
	if OS.get_cmdline_user_args().has("--gate"):
		_gate()
		quit(0)
		return
	if OS.get_cmdline_user_args().has("--free"):
		_free_weeks()
		quit(0)
		return
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a.begins_with("--profile="):
			profile = a.trim_prefix("--profile=")
		if a.begins_with("--seed="):
			run_seed = int(a.trim_prefix("--seed="))
	var off := _play(profile, run_seed, true)
	var on := _play(profile, run_seed, false)
	print("Story slot diagnosis, %s seed %d" % [profile, run_seed])
	print("  wk slot | dis   d hope food air season short  pool                     leader         story            discontent sources")
	for i in maxi(off.rows.size(), on.rows.size()):
		var a: Dictionary = off.rows[i] if i < off.rows.size() else {}
		var b: Dictionary = on.rows[i] if i < on.rows.size() else {}
		var w := int(b.get("week", a.get("week", 0)))
		print("  %2d off  | %s" % [w, _cell(off, i)])
		print("     on   | %s" % _cell(on, i))
	print("final dis off %d on %d; dis sources off %s on %s" % [off.game.discontent, on.game.discontent,
		off.game.dis_totals, on.game.dis_totals])
	quit(0)


func _cell(run: Dictionary, i: int) -> String:
	if i >= run.rows.size():
		return ""
	var row: Dictionary = run.rows[i]
	var w := int(row.week)
	var prev := int(run.rows[i - 1].dis) if i > 0 else int(row.dis)
	var kinds: Dictionary = run.kinds.get(w, {"pool": PackedStringArray(), "leader": PackedStringArray(), "story": PackedStringArray()})
	var src: PackedStringArray = []
	for k in row.sources:
		src.append("%s%+d" % [k, int(row.sources[k])])
	return "%3d %+3d %3d %4d %3d %-6s %-6s %-24s %-14s %-16s %s" % [int(row.dis), int(row.dis) - prev, int(row.hope), int(row.food),
		int(row.air), str(row.season), str(run.short.get(w, "")), ",".join(kinds.pool), ",".join(kinds.leader),
		",".join(kinds.story), " ".join(src)]


## The expander's discontent over seeds 1 to 30 without and with the story slot, as the proposed distribution gate
## reads it: share of seeds with dis_max at most 75, mean dis_max, and seeds that revolt only with the slot.
func _gate() -> void:
	var stats := {"off": {"under": 0, "sum": 0, "revolts": 0}, "on": {"under": 0, "sum": 0, "revolts": 0}}
	var story_revolts: PackedStringArray = []
	for s in range(1, 31):
		var row := "  s%02d" % s
		var over := {}
		for mode in ["off", "on"]:
			var rep: Dictionary = _play("expander", s, mode == "off").game.report()
			var dm := int(rep.dis_max)
			stats[mode].sum += dm
			if dm <= 75:
				stats[mode].under += 1
			if str(rep.over) == "revolt":
				stats[mode].revolts += 1
			over[mode] = str(rep.over)
			row += "  %s %3d %-6s" % [mode, dm, str(rep.over)]
		if over.on == "revolt" and over.off != "revolt":
			story_revolts.append("s%d" % s)
		print(row)
	for mode in ["off", "on"]:
		print("  %s: dis_max <= 75 in %d of 30, mean %.1f, revolts %d" % [mode, int(stats[mode].under), float(stats[mode].sum) / 30.0, int(stats[mode].revolts)])
	print("  revolts only with the story slot: %s" % (", ".join(story_revolts) if not story_revolts.is_empty() else "none"))


## Over the bot_run stewards and seeds 1 to 10: per week, how often the story slot is free and what keeps it busy,
## then how often each story beat shows.
func _free_weeks() -> void:
	var table := {}
	var shown := {}
	var runs := 0
	for profile in ["careful", "expander", "follower"]:
		for run_seed in range(1, 11):
			var run := _play(profile, run_seed, false)
			runs += 1
			for w in run.game.why:
				if not table.has(w):
					table[w] = {}
				var r := str(run.game.why[w])
				table[w][r] = int(table[w].get(r, 0)) + 1
			for w in run.kinds:
				for id in run.kinds[w].story:
					shown[id] = int(shown.get(id, 0)) + 1
	print("Story slot by week over %d runs (free / leader / season / busy / short / low):" % runs)
	for w in range(2, 41 if windows.is_empty() else 2):
		var t: Dictionary = table.get(w, {})
		print("  w%02d  %2d / %2d / %2d / %2d / %2d / %2d" % [w, int(t.get("free", 0)), int(t.get("leader", 0)), int(t.get("season", 0)),
			int(t.get("busy", 0)), int(t.get("short", 0)), int(t.get("low", 0))])
	for id in shown:
		print("  %s %d/%d" % [id, int(shown[id]), runs])
	var bits: PackedStringArray = []
	var lower := 0
	for s in range(1, 6):
		var c: Dictionary = _play("careful", s, false).game.report()
		var e: Dictionary = _play("expander", s, false).game.report()
		if float(e.hope_avg) < float(c.hope_avg):
			lower += 1
		bits.append("s%d c%d e%d" % [s, int(c.dis_max), int(e.dis_max)])
	print("  dis_max %s; expander hope lower in %d of 5" % [" ".join(bits), lower])


func _play(profile: String, run_seed: int, slot_off: bool) -> Dictionary:
	var catalog := Catalog.new()
	catalog.load_all()
	for ev in catalog.events:
		if windows.has(str(ev.id)):
			ev.needs.week = windows[str(ev.id)]
	var game := DiagGame.new()
	game.slot_off = slot_off
	game.setup(catalog, run_seed, WEEKS)
	game.audit = profile != "follower"
	var bot := Bot.new()
	bot.profile = profile
	var guard := 0
	while game.over == "" and guard < WEEKS + 2:
		guard += 1
		bot._act(game)
		game.end_week()
	var kind_of := {}
	for ev in catalog.events:
		kind_of[str(ev.id)] = ("leader" if Game.needs_forced(ev) else "story") if ev.has("needs") else "pool"
	var kinds := {}
	for e in game.event_history:
		var w := int(e.week)
		if not kinds.has(w):
			kinds[w] = {"pool": PackedStringArray(), "leader": PackedStringArray(), "story": PackedStringArray()}
		kinds[w][str(kind_of.get(str(e.id), "pool"))].append(str(e.id))
	var short := {}
	for c in game.stats.get("shortage_causes", []):
		short[int(c.week)] = str(c.cause)
	return {"game": game, "rows": game.rows, "kinds": kinds, "short": short}
