extends SceneTree

## Act II coverage: the three stewards over seeds 1 to 10 under each audience style, counting the runs each st2_*
## event shows in, the fragments learned by kind, and the flags and standing the honest and dirty paths wait on.
##   godot --headless --path . -s res://.tools/story_act2_cover.gd

const PROFILES := ["careful", "expander", "follower"]
const WEEKS := 40


func _initialize() -> void:
	var probe := Catalog.new()
	probe.load_all()
	var ids: Array = []
	for ev in probe.events:
		if str(ev.id).begins_with("st2_"):
			ids.append(str(ev.id))
	for style in Bot.AUDIENCE_STYLES:
		var shown := {}
		var kinds := {"honest": 0, "dirty": 0, "found": 0}
		var flags := {}
		var peaks := {}
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
				runs += 1
				for id in ids:
					if game.events_seen.has(id):
						shown[id] = int(shown.get(id, 0)) + 1
				for fid in game.fragments:
					if game.fragment_known(str(fid)):
						kinds[str(game.fragments[fid].how)] += 1
				for flag in ["buried_papers", "collaborator", "stayed_down", "open_books", "lantern_toll"]:
					if game.flags.has(flag):
						flags[flag] = int(flags.get(flag, 0)) + 1
				for fid in top:
					peaks[fid] = maxi(int(peaks.get(fid, -100)), int(top[fid]))
		print("== %s, %d runs" % [style, runs])
		for id in ids:
			print("  %-22s %2d/%d" % [id, int(shown.get(id, 0)), runs])
		print("  fragments: honest %d, dirty %d, found %d" % [int(kinds.honest), int(kinds.dirty), int(kinds.found)])
		print("  flags (runs): %s" % str(flags))
		print("  highest standing reached: %s" % str(peaks))
	quit(0)
