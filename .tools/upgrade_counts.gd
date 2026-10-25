extends SceneTree

## Bot upgrade counts and outcomes on 30 seeds per steward, for upgrade cost decisions:
##   godot --headless --path . -s res://.tools/upgrade_counts.gd [-- --from=1]
## Plays like Bot.play (40 weeks) and counts the UPGRADE lines in the game log: all upgrades, second tier
## upgrades. Prints one line per steward and seed, then totals.

const SEEDS := 30


func _init() -> void:
	Copy.set_lang("en")
	var first := 1
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--from="):
			first = int(str(arg).trim_prefix("--from="))
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("UPGRADE COUNTS FAILED: " + catalog.error)
		quit(1)
		return
	for profile in ["careful", "expander", "follower"]:
		var total := {"up": 0, "tier2": 0, "week": 0, "pop": 0, "hope": 0.0, "dis": 0, "short": 0}
		var overs := {}
		for run_seed in range(first, first + SEEDS):
			var bot := Bot.new()
			bot.profile = profile
			var game := Game.new()
			game.setup(catalog, run_seed, 40)
			game.audit = profile != "follower"
			var guard := 0
			while game.over == "" and guard < 42:
				guard += 1
				bot._act(game)
				game.end_week()
			var up := 0
			var tier2 := 0
			for entry in game.log:
				var text := str(entry.text)
				if text.begins_with("UPGRADE "):
					up += 1
					if _second(catalog, text):
						tier2 += 1
			var row := game.report()
			total.up += up
			total.tier2 += tier2
			total.week += int(row.week)
			total.pop += int(row.get("pop40", 0))
			total.hope += float(row.get("hope_avg", 0))
			total.dis += int(row.get("dis_max", 0))
			total.short += int(row.get("shortage_weeks", 0))
			overs[str(row.over)] = int(overs.get(str(row.over), 0)) + 1
			print("%s seed %d: upgrades %d (tier II %d), %s week %d, pop %d, hope avg %.1f, dis max %d, short %d" % [
				profile, run_seed, up, tier2, str(row.over), int(row.week), int(row.get("pop40", 0)),
				float(row.get("hope_avg", 0)), int(row.get("dis_max", 0)), int(row.get("shortage_weeks", 0))])
		print("TOTAL %s: upgrades %d (tier II %d), ends %s, mean week %.1f, mean pop %.1f, mean hope avg %.1f, mean dis max %.1f, shortage weeks %d" % [
			profile, total.up, total.tier2, _overs(overs), total.week / float(SEEDS), total.pop / float(SEEDS),
			total.hope / SEEDS, total.dis / float(SEEDS), total.short])
	print("UPGRADE COUNTS OK")
	quit(0)


## The log line names the upgrade bought: "UPGRADE <room> to <upgrade>". Tier II is the second name in the list.
static func _second(catalog: Catalog, text: String) -> bool:
	var name := text.get_slice(" to ", 1)
	for defin in catalog.rooms.values():
		var steps: Array = defin.get("upgrades", [])
		if steps.size() > 1 and str(steps[1]) == name:
			return true
	return false


static func _overs(overs: Dictionary) -> String:
	var parts: PackedStringArray = []
	var keys := overs.keys()
	keys.sort()
	for key in keys:
		parts.append("%s %d" % [key, overs[key]])
	return ", ".join(parts)
