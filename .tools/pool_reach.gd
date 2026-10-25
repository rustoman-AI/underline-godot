extends SceneTree

## Event pool batch reach (docs/briefs/cursor_event_pool_1.txt): the three stewards over seeds 1 to 30 with the
## given audience style (default silence, as in the content audit). Prints the share of runs each event of
## data/events_pool.json shows in, the choices picked, and the words and papers gained per run from quiet_letter
## and old_diary.
##   godot --headless --path . -s res://.tools/pool_reach.gd [-- --style=storyteller]

const PROFILES := ["careful", "expander", "follower"]
const WEEKS := 40
const CHAINS := ["quiet_letter", "old_diary"]


func _initialize() -> void:
	var style := "silence"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--style="):
			style = str(arg).trim_prefix("--style=")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/events_pool.json"))
	var by_id := {}
	for ev in data.events:
		by_id[str(ev.id)] = ev
	var catalog := Catalog.new()
	catalog.load_all()
	var shown := {}
	var picks := {}
	var gained := {"words": 0, "papers": 0}
	var runs := 0
	for profile in PROFILES:
		for run_seed in range(1, 31):
			var bot := Bot.new()
			bot.audience_style = style
			var game := Game.new()
			game.setup(catalog, run_seed, WEEKS)
			game.audit = profile != "follower"
			bot.profile = profile
			var guard := 0
			while game.over == "" and guard < WEEKS + 2:
				guard += 1
				bot._act(game)
				game.end_week()
			runs += 1
			for id in by_id:
				if game.events_seen.has(id):
					shown[id] = int(shown.get(id, 0)) + 1
			for row in game.journal:
				var id := str(row.get("event_id", ""))
				if str(row.get("kind", "")) != "event" or not by_id.has(id):
					continue
				var key := "%s/%s" % [id, row.get("choice_id", "")]
				picks[key] = int(picks.get(key, 0)) + 1
				if not CHAINS.has(id):
					continue
				for choice in by_id[id].choices:
					if str(choice.id) == str(row.get("choice_id", "")):
						for art in choice.get("artifacts", {}):
							gained[art] = int(gained.get(art, 0)) + int(choice.artifacts[art])
	print("== pool reach, style %s, %d runs" % [style, runs])
	for id in by_id:
		print("  %-13s %2d/%d (%3.0f%%)" % [id, int(shown.get(id, 0)), runs, 100.0 * int(shown.get(id, 0)) / runs])
	var keys: Array = picks.keys()
	keys.sort()
	print("  choices: %s" % ", ".join(keys.map(func(k): return "%s %d" % [k, int(picks[k])])))
	print("  from quiet_letter and old_diary per run: words %.2f, papers %.2f" % [gained.words / float(runs), gained.papers / float(runs)])
	quit(0)
