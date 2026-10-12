extends SceneTree

## Story S2 reach (docs/briefs/cursor_story_engine_s2.txt): the three stewards over seeds 1 to 10 under each
## audience style, every bot taking an ending at the final decision when one is open (door, climb, order, hold).
## Counts the endings, the runs each bunker scene and the decision showed in, the choices picked in them, the
## fragments learned honest and dirty, and the proofs. Then the acceptance: each story ending is reached by some
## style in some seed, and none takes more than 90% of the storyteller's runs.
##   godot --headless --path . -s res://.tools/story_s2_cover.gd [-- --styles=storyteller,helper]

const PROFILES := ["careful", "expander", "follower"]
const WEEKS := 40
const STYLES := ["silence", "helper", "helper_mixed", "accept_all", "mixed", "storyteller"]
const SCENES := ["st3_floor", "st3_quarantine", "st3_observatory", "st3_decision"]
const STORYTELLER_CAP := 90


func _initialize() -> void:
	var styles: Array = STYLES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--styles="):
			styles = Array(str(arg).trim_prefix("--styles=").split(","))
	var reached := {}
	var teller := {}
	var teller_runs := 0
	for style in styles:
		var catalog := Catalog.new()
		catalog.load_all()
		var endings := {}
		var shown := {}
		var picks := {}
		var flags := {}
		var gate := {"path": 0, "open": 0, "weeks": []}
		var at_decision := {}
		var honest := 0
		var dirty := 0
		var proofs := 0
		var proof_runs := {}
		var errors := 0
		var runs := 0
		for profile in PROFILES:
			for run_seed in range(1, 11):
				var game := Game.new()
				game.setup(catalog, run_seed, WEEKS)
				game.audit = profile != "follower"
				var bot := Bot.new()
				bot.profile = profile
				bot.audience_style = style
				bot.take_endings = true
				var guard := 0
				var opened := false
				var path_week := 0
				var decided := false
				while game.over == "" and guard < WEEKS + 2:
					guard += 1
					for ev in game.pending:
						if decided or str(ev.id) != "st3_decision":
							continue
						decided = true
						var open: Array = []
						for choice in ev.choices:
							if str(choice.get("ending", "")) != "" and not game.choice_locked(choice):
								open.append(str(choice.id))
						var key := "+".join(open) if not open.is_empty() else "none"
						at_decision[key] = int(at_decision.get(key, 0)) + 1
						if game.can_approach_quarantine():
							at_decision["quarantine order still open"] = int(at_decision.get("quarantine order still open", 0)) + 1
					bot._act(game)
					game.end_week()
					if path_week == 0 and game.fragment_known("quarantine_path"):
						path_week = game.week
					if not opened and game.quarantine_block() == "":
						opened = true
						gate.open += 1
				if path_week > 0:
					gate.path += 1
					gate.weeks.append(path_week)
				runs += 1
				errors += game.errors.filter(func(e): return not str(e).contains("decisions")).size()
				var end := game.ending_id() if game.ending_id() != "" else "running"
				endings[end] = int(endings.get(end, 0)) + 1
				if Game.STORY_ENDINGS.has(end):
					reached[end] = int(reached.get(end, 0)) + 1
				if style == "storyteller":
					teller[end] = int(teller.get(end, 0)) + 1
				for id in SCENES:
					if game.events_seen.has(id):
						shown[id] = int(shown.get(id, 0)) + 1
				for row in game.journal:
					if str(row.get("kind", "")) == "event" and SCENES.has(str(row.get("event_id", ""))):
						var key := "%s/%s" % [row.event_id, row.get("choice_id", "")]
						picks[key] = int(picks.get(key, 0)) + 1
				for flag in game.flags:
					if Game.FLAG_TEXT.has(str(flag)) or str(flag).begins_with("quarantine_"):
						flags[str(flag)] = int(flags.get(str(flag), 0)) + 1
				honest += game.honest_fragments()
				for fid in game.fragments:
					if game.fragment_known(str(fid)) and str(game.fragments[fid].how) == "dirty":
						dirty += 1
				proofs += game.proofs()
				var band := mini(game.proofs(), 3)
				proof_runs[band] = int(proof_runs.get(band, 0)) + 1
		if style == "storyteller":
			teller_runs = runs
		print("== %s, %d runs%s" % [style, runs, ", sim errors %d" % errors if errors > 0 else ""])
		print("  endings: %s" % _row(endings, runs))
		var scene_row: Array = []
		for id in SCENES:
			scene_row.append("%s %d/%d" % [id, int(shown.get(id, 0)), runs])
		print("  scenes: %s" % ", ".join(scene_row))
		var keys: Array = picks.keys()
		keys.sort()
		print("  choices (journal): %s" % ", ".join(keys.map(func(k): return "%s %d" % [k, int(picks[k])])) if not keys.is_empty() else "  choices (journal): none")
		print("  scene flags (runs): %s" % (_row(flags, runs) if not flags.is_empty() else "none"))
		print("  endings open at the decision: %s" % (_row(at_decision, runs) if not at_decision.is_empty() else "no decision"))
		gate.weeks.sort()
		print("  quarantine path learned in %d runs (weeks %s); Quarantine order open in %d" % [gate.path, str(gate.weeks), gate.open])
		print("  fragments per run: honest %.2f, dirty %.2f; proofs per run %.2f; runs with 0/1/2/3+ proofs %d/%d/%d/%d" % [
			honest / float(runs), dirty / float(runs), proofs / float(runs),
			int(proof_runs.get(0, 0)), int(proof_runs.get(1, 0)), int(proof_runs.get(2, 0)), int(proof_runs.get(3, 0))])
	print("== acceptance")
	var ok := true
	for end in Game.STORY_ENDINGS:
		var share := 0.0 if teller_runs == 0 else 100.0 * int(teller.get(end, 0)) / teller_runs
		var hit := int(reached.get(end, 0)) > 0
		var capped := share <= STORYTELLER_CAP
		ok = ok and hit and capped
		print("  %-10s reached in %d runs (any style); storyteller %d/%d (%.0f%%)%s%s" % [end, int(reached.get(end, 0)),
			int(teller.get(end, 0)), teller_runs, share, "" if hit else "  UNREACHED", "" if capped else "  OVER %d%%" % STORYTELLER_CAP])
	print("S2 REACH %s" % ("OK" if ok else "SHORT"))
	quit(0)


func _row(counts: Dictionary, runs: int) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	return ", ".join(keys.map(func(k): return "%s %d/%d" % [k, int(counts[k]), runs]))
