extends SceneTree

## Noise of two bot_run gates over 30 seeds starting at --from (default 1): the expander's share of seeds with a
## discontent peak of 75 or less, without story beats and with them (as in _expander_discontent_ok), and the
## follower's white check pass rate (as in _checks_ok, which bot_run takes over seeds 1 to 5).
##   godot --headless --path . -s res://.tools/gate_noise.gd -- --from=31


func _initialize() -> void:
	var first := 1
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--from="):
			first = int(str(arg).trim_prefix("--from="))
	var tally := {"plain": {"under": 0, "sum": 0, "revolts": 0}, "full": {"under": 0, "sum": 0, "revolts": 0}}
	var rolls := 0
	var wins := 0
	var rolls5 := 0
	var wins5 := 0
	for run_seed in range(first, first + 30):
		for mode in ["plain", "full"]:
			var cat := Catalog.new()
			cat.load_all()
			if mode == "plain":
				cat.events = cat.events.filter(func(ev): return not _story_beat(ev))
			var row: Dictionary = Bot.new().play(40, run_seed, "expander", cat)
			var peak := int(row.get("dis_max", 0))
			tally[mode].sum += peak
			if peak <= 75:
				tally[mode].under += 1
			if str(row.get("over", "")) == "revolt":
				tally[mode].revolts += 1
		var f: Dictionary = Bot.new().play(40, run_seed, "follower")
		rolls += int(f.get("check_white_rolls", 0))
		wins += int(f.get("check_white_success", 0))
		if run_seed < first + 5:
			rolls5 += int(f.get("check_white_rolls", 0))
			wins5 += int(f.get("check_white_success", 0))
	print("seeds %d-%d" % [first, first + 29])
	print("expander peak <= 75 without / with story: %d / %d of 30 (%.1f%% / %.1f%%), mean peak %.1f / %.1f, revolts %d / %d" % [
		int(tally.plain.under), int(tally.full.under), tally.plain.under * 100.0 / 30.0, tally.full.under * 100.0 / 30.0,
		tally.plain.sum / 30.0, tally.full.sum / 30.0, int(tally.plain.revolts), int(tally.full.revolts)])
	print("follower white %d/%d (%.1f%%); first five seeds %d/%d (%.1f%%)" % [wins, rolls, wins * 100.0 / maxi(rolls, 1),
		wins5, rolls5, wins5 * 100.0 / maxi(rolls5, 1)])
	quit(0)


static func _story_beat(ev: Dictionary) -> bool:
	var needs = ev.get("needs", null)
	return needs is Dictionary and not bool(ev.get("forced", needs.has("leader")))
