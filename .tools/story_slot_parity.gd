extends SceneTree

## Story slot parity probe: plays the bot_run stewards over ten seeds and prints, per run, the events the random
## pool presented (every event without "needs") with their weeks. Run it on a tree without the story slot and on one
## with it, then diff the two outputs: the old pool's stream and order must not move.
##   godot --headless --path . -s res://.tools/story_slot_parity.gd [-- --neutral] > parity.txt
## --neutral shows every story beat and has the bot answer it, but the answer changes nothing in the run, which
## separates the slot's own draws from what the beats' choices do to the station.

const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const PROFILES := ["careful", "expander", "follower"]
const WEEKS := 40


class ParityGame extends Game:
	var neutral := false
	var beats := {}

	func _apply_event(action: Dictionary) -> bool:
		if neutral and not pending.is_empty() and beats.has(str(pending[0].id)) \
				and str(pending[0].id) == str(action.get("event_id", "")):
			pending.pop_front()
			return true
		return super(action)


func _initialize() -> void:
	var neutral := OS.get_cmdline_user_args().has("--neutral")
	var catalog := Catalog.new()
	catalog.load_all()
	var beats := {}
	for ev in catalog.events:
		if ev.has("needs"):
			beats[str(ev.id)] = true
	for profile in PROFILES:
		for run_seed in SEEDS:
			var game := ParityGame.new()
			game.neutral = neutral
			for ev in catalog.events:
				if ev.has("needs") and not ev.get("needs", {}).has("leader"):
					game.beats[str(ev.id)] = true
			game.setup(catalog, run_seed, WEEKS)
			game.audit = profile != "follower"
			var bot := Bot.new()
			bot.profile = profile
			var guard := 0
			while game.over == "" and guard < WEEKS + 2:
				guard += 1
				bot._act(game)
				game.end_week()
			var pool: PackedStringArray = []
			var story: PackedStringArray = []
			for row in game.event_history:
				if beats.has(str(row.id)):
					story.append("w%d %s" % [int(row.week), str(row.id)])
				else:
					pool.append("w%d %s" % [int(row.week), str(row.id)])
			print("POOL %s seed %d: %s" % [profile, run_seed, ", ".join(pool)])
			print("BEATS %s seed %d: %s" % [profile, run_seed, ", ".join(story)])
	quit(0)
