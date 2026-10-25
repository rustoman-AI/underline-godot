extends SceneTree

## Act II coverage: the three stewards over seeds 1 to 10 under each audience style, counting the runs each st2_*
## event shows in, the fragments learned by kind, and the flags and standing the honest and dirty paths wait on.
## Also: mean standing per leader at weeks 14, 20 and 30, the weeks each honest event fired, the stock spent on
## help, and hope, discontent, food and materials at week 40.
##   godot --headless --path . -s res://.tools/story_act2_cover.gd [-- --styles=helper,mixed]

const PROFILES := ["careful", "expander", "follower"]
const WEEKS := 40
const SAMPLE_WEEKS := [14, 20, 30]
const LEADERS := ["depot", "directorate", "synod", "exchange", "black_flag"]
const END_KEYS := ["hope", "discontent", "food", "materials"]


func _initialize() -> void:
	var probe := Catalog.new()
	probe.load_all()
	var ids: Array = []
	for ev in probe.events:
		if str(ev.id).begins_with("st2_"):
			ids.append(str(ev.id))
	var styles: Array = Bot.AUDIENCE_STYLES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--styles="):
			styles = Array(str(arg).trim_prefix("--styles=").split(","))
	var ends := {}
	for style in styles:
		var shown := {}
		var fired_at := {}
		var kinds := {"honest": 0, "dirty": 0, "found": 0}
		var flags := {}
		var peaks := {}
		var sampled := {}
		var spent := {}
		var end_sum := {}
		var runs := 0
		for profile in PROFILES:
			for run_seed in range(1, 11):
				var catalog := Catalog.new()
				catalog.load_all()
				var game := Game.new()
				game.setup(catalog, run_seed, WEEKS)
				game.audit = profile != "follower"
				var bot := Bot.new()
				bot.profile = profile
				bot.audience_style = style
				var top := {}
				var guard := 0
				while game.over == "" and guard < WEEKS + 2:
					guard += 1
					bot._act(game)
					game.end_week()
					for fid in game.standing:
						top[fid] = maxi(int(top.get(fid, -100)), int(game.standing[fid]))
					if SAMPLE_WEEKS.has(game.week):
						for fid in LEADERS:
							var key := "%s@%d" % [fid, game.week]
							sampled[key] = int(sampled.get(key, 0)) + int(game.standing.get(fid, 0))
				runs += 1
				for id in ids:
					if game.events_seen.has(id):
						shown[id] = int(shown.get(id, 0)) + 1
						if id.ends_with("_honest"):
							if not fired_at.has(id):
								fired_at[id] = []
							fired_at[id].append(int(game.events_seen[id]))
				for fid in game.fragments:
					if game.fragment_known(str(fid)):
						kinds[str(game.fragments[fid].how)] += 1
				for flag in ["buried_papers", "collaborator", "stayed_down", "open_books", "lantern_toll"]:
					if game.flags.has(flag):
						flags[flag] = int(flags.get(flag, 0)) + 1
				for fid in top:
					peaks[fid] = maxi(int(peaks.get(fid, -100)), int(top[fid]))
				var paid: Dictionary = game.stats.get("help_spent", {})
				for key in paid:
					spent[key] = int(spent.get(key, 0)) + int(paid[key])
				end_sum.hope = int(end_sum.get("hope", 0)) + game.hope
				end_sum.discontent = int(end_sum.get("discontent", 0)) + game.discontent
				end_sum.food = int(end_sum.get("food", 0)) + int(game.stock.food)
				end_sum.materials = int(end_sum.get("materials", 0)) + int(game.stock.materials)
		print("== %s, %d runs" % [style, runs])
		for id in ids:
			var weeks: Array = fired_at.get(id, [])
			weeks.sort()
			print("  %-22s %2d/%d%s" % [id, int(shown.get(id, 0)), runs, ("  weeks %s" % str(weeks)) if not weeks.is_empty() else ""])
		print("  fragments per run: honest %.2f, dirty %.2f, found %.2f" % [kinds.honest / float(runs), kinds.dirty / float(runs), kinds.found / float(runs)])
		print("  flags (runs): %s" % str(flags))
		print("  highest standing reached: %s" % str(peaks))
		for fid in LEADERS:
			var row: Array = []
			for w in SAMPLE_WEEKS:
				row.append("w%d %.1f" % [w, int(sampled.get("%s@%d" % [fid, w], 0)) / float(runs)])
			print("  standing %-12s %s" % [fid, ", ".join(row)])
		var spend_row: Array = []
		for key in spent:
			spend_row.append("%s %.2f" % [key, int(spent[key]) / float(runs)])
		print("  help spent per run: %s" % (", ".join(spend_row) if not spend_row.is_empty() else "none"))
		var end_row := {}
		for key in END_KEYS:
			end_row[key] = int(end_sum.get(key, 0)) / float(runs)
		ends[style] = end_row
		print("  week 40 means: hope %.1f, discontent %.1f, food %.1f, materials %.1f" % [end_row.hope, end_row.discontent, end_row.food, end_row.materials])
	print("== help against no-help (week 40 mean deltas)")
	for pair in [["helper", "silence"], ["helper", "refuse_all"], ["helper_mixed", "mixed"]]:
		if not ends.has(pair[0]) or not ends.has(pair[1]):
			continue
		var a: Dictionary = ends[pair[0]]
		var b: Dictionary = ends[pair[1]]
		print("  %-12s vs %-10s hope %+.1f, discontent %+.1f, food %+.1f, materials %+.1f" % [pair[0], pair[1],
			a.hope - b.hope, a.discontent - b.discontent, a.food - b.food, a.materials - b.materials])
	quit(0)
