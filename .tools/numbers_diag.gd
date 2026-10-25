extends SceneTree

## Numbers clarity, step 0: what the screen says about power, food, air and materials against what the night
## applies. Plays the careful bot and, right before each night, reads every number the player can see:
##   bar     the stock in the top bar
##   outlook resource_outlook (chip tooltip): made, used, by dawn
##   source  Brief.source headline (the panel on hover or tap): "+N / week"
##   card    each room card's "+N/wk" (room_detail, 0 when offline) and the yard badge (room_detail, as is)
## then runs the night and compares with the stock change (last_net) and the production the night really used
## (brownout marked, the same _tally flags). Nothing in the game is changed; the week runs as end_week does.
##   godot --headless --path . -s res://.tools/numbers_diag.gd -- --seeds=1,2,3,4,5 --weeks=8

const KEYS := ["power", "food", "air", "materials"]

var lines: PackedStringArray = []
var counts := {}
var profile := "careful"


func _initialize() -> void:
	Copy.set_lang("en")
	var seeds := [1, 2, 3, 4, 5]
	var weeks := 8
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--seeds="):
			seeds = []
			for s in str(arg).trim_prefix("--seeds=").split(","):
				seeds.append(int(s))
		if str(arg).begins_with("--weeks="):
			weeks = int(str(arg).trim_prefix("--weeks="))
		if str(arg).begins_with("--profile="):
			profile = str(arg).trim_prefix("--profile=")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("catalog: " + catalog.error)
		quit(1)
		return
	for run_seed in seeds:
		_play(catalog, int(run_seed), weeks)
	print("\n".join(lines))
	print("")
	print("MISMATCH COUNTS over seeds %s, weeks 1-%d:" % [str(seeds), weeks])
	var names := counts.keys()
	names.sort()
	for name in names:
		print("  %-44s %d" % [name, int(counts[name])])
	quit(0)


func _play(catalog: Catalog, run_seed: int, weeks: int) -> void:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	var bot := Bot.new()
	bot.profile = profile
	while game.over == "" and game.week <= weeks:
		bot._act(game)
		_week(game, run_seed, game.week == 1 or game.week == weeks)


## end_week, step by step, with the screen read between the dawn work and the night.
func _week(game: Game, run_seed: int, verbose: bool) -> void:
	game._resolve_pending()
	game._rival_phase()
	var shown := _read_screen(game)
	var actual := _night_preview(game)
	var before := {}
	for key in KEYS:
		before[key] = int(game.stock[key])
	game._night()
	var head := "seed %d week %d%s" % [run_seed, game.week, _flags(game)]
	if verbose:
		lines.append("== " + head)
	for key in KEYS:
		var s: Dictionary = shown[key]
		var a: Dictionary = actual[key]
		var net := int(game.last_net.get(key, 0))
		var row := "  %-9s bar %3d | outlook made %3d used %3d net %+4d | source +%d | cards %s | night made %3d used %3d | stock change %+4d" % [
			key, int(before[key]), int(s.made), int(s.used), int(s.made) - int(s.used), int(s.source), s.cards, int(a.made), int(a.used), net]
		var notes: PackedStringArray = []
		if int(s.made) != int(a.made):
			notes.append("MADE shown %d, night %d" % [int(s.made), int(a.made)])
			_count("%s: made shown != night made" % key)
		if int(s.used) != int(a.used):
			notes.append("USED shown %d, night %d" % [int(s.used), int(a.used)])
			_count("%s: used shown != night used" % key)
		if int(s.made) - int(s.used) != net:
			notes.append("NET shown %+d, stock moved %+d" % [int(s.made) - int(s.used), net])
			_count("%s: shown net != stock change" % key)
		if int(s.cards_sum) != int(s.made):
			notes.append("CARDS sum %d, outlook made %d" % [int(s.cards_sum), int(s.made)])
			_count("%s: room cards sum != outlook made" % key)
		if int(s.badges_sum) != int(s.cards_sum):
			notes.append("BADGES sum %d, cards %d" % [int(s.badges_sum), int(s.cards_sum)])
			_count("%s: yard badges sum != room cards" % key)
		if int(s.source) != int(s.made):
			_count("%s: source headline != outlook made" % key)
		for note in a.why:
			_count("  cause %s: %s" % [key, str(note).get_slice(":", 0).get_slice(" ", 0) + " " + str(note).get_slice(" ", 1)])
		for note in a.why:
			notes.append(str(note))
		var swing := int(game.bal.get("harvest_swing", 0)) + absi(int(game.bal.get("harvest_bias", 0))) if key == "food" else 0
		if absi(net - int(a.replay)) > swing and not (key == "food" and game.week == game.rot_week):
			notes.append("UNEXPLAINED: replay %+d, stock moved %+d" % [int(a.replay), net])
			_count("%s: night not explained by replay" % key)
		if verbose or not notes.is_empty():
			if not verbose:
				lines.append("-- " + head)
			lines.append(row)
			for note in notes:
				lines.append("      " + note)
	game._finish_checks()
	game.stats.min_decisions = mini(int(game.stats.min_decisions), game.decisions)
	game._invariants()
	if game.over != "":
		return
	game.week += 1
	game.decisions = 0
	game._dawn()
	game._vo_watch()


func _flags(game: Game) -> String:
	var bits: PackedStringArray = []
	if not game.active_season.is_empty():
		bits.append("season " + str(game.active_season.id))
	for name in ["crunch_power", "belt_down", "workshop_down", "gen_down", "quarantine"]:
		if bool(game.get(name)):
			bits.append(name)
	if game.vent_cut > 0:
		bits.append("vent_cut")
	for law in game.laws_on:
		bits.append("law " + str(law))
	return "" if bits.is_empty() else " [" + ", ".join(bits) + "]"


func _read_screen(game: Game) -> Dictionary:
	var out := {}
	for key in KEYS:
		var made := game.output_of(key)
		if key == "power" and game._law_on("engineers_charter"):
			made += int(game.catalog.laws.engineers_charter.get("power", 0))
		var used := game._weekly_draw(key)
		var info: Dictionary = Brief.source(game, key)
		var source := int(str(info.headline).get_slice("(", 1).get_slice(" ", 0).replace("+", ""))
		var cards: PackedStringArray = []
		var cards_sum := 0
		var badges_sum := 0
		for room in game.rooms:
			var detail: Dictionary = game.room_detail(str(room.uid))
			for o in detail.outputs:
				if str(o.key) != key:
					continue
				var card := 0 if bool(detail.offline) else int(o.amount)
				cards.append("%s %+d" % [str(room.type), card])
				cards_sum += card
				badges_sum += int(o.amount)
		out[key] = {"made": made, "used": used, "source": source, "cards": ", ".join(cards) if not cards.is_empty() else "-",
			"cards_sum": cards_sum, "badges_sum": badges_sum}
	return out


## What the night will produce and draw, read the way _night does it, without running it.
func _night_preview(game: Game) -> Dictionary:
	var saved: Array = []
	for room in game.rooms:
		saved.append(bool(room.get("browned", false)))
	var dark := game._brownout_ids()
	for room in game.rooms:
		room.browned = dark.has(str(room.uid))
	var produced: Dictionary = game._tally(game.belt_down, game.workshop_down, game.gen_down)
	var need_power := game._power_need()
	var cold := game._season_is("cold") or game.crunch_power
	if cold:
		need_power *= 2
	for i in game.rooms.size():
		game.rooms[i].browned = saved[i]
	var out := {}
	for key in KEYS:
		out[key] = {"made": int(produced[key]), "used": 0, "why": []}
	if game._law_on("engineers_charter"):
		out.power.made += int(game.catalog.laws.engineers_charter.get("power", 0))
	out.power.used = need_power
	out.food.used = game.food_need()
	out.air.used = game.air_need()
	var filters := 0
	for room in game.rooms:
		if str(room.type) == "air_filter":
			filters += 1
	out.materials.used = int(game.bal.filter_upkeep) * filters
	if not dark.is_empty():
		var names: PackedStringArray = []
		for uid in dark:
			names.append(str(game._room(str(uid)).type))
		out.power.why.append("brownout at night: %s go dark (their output and draw drop)" % ", ".join(names))
	if game.belt_down or game.workshop_down or game.gen_down:
		out.power.why.append("event flag halves or stops a room tonight")
	if int(game.bal.get("harvest_swing", 0)) > 0 or int(game.bal.get("harvest_bias", 0)) != 0:
		out.food.why.append("food harvest swing +-%d, bias %+d (random at night)" % [int(game.bal.get("harvest_swing", 0)), int(game.bal.get("harvest_bias", 0))])
	if game.vent_cut > 0:
		out.air.why.append("vent cut: -2 air at night")
	if filters > 0:
		out.materials.why.append("filter upkeep %d x %d filters = %d materials (spent at night if in store)" % [int(game.bal.filter_upkeep), filters, int(out.materials.used)])
	_replay(game, out, produced, need_power)
	return out


## The night's stock steps in _night's order, harvest swing left out (food is checked against its range).
func _replay(game: Game, out: Dictionary, produced: Dictionary, need_power: int) -> void:
	var s := {}
	for key in KEYS:
		s[key] = int(game.stock[key]) + int(produced[key])
	if game._law_on("engineers_charter"):
		s.power += int(game.catalog.laws.engineers_charter.get("power", 0))
	if game.vent_cut > 0:
		s.air = maxi(0, int(s.air) - 2)
	var outpost := {"materials": 0, "food": 0, "air": 0}
	for sid in game.stations.keys():
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != game.player or sid == game.capital_id:
			continue
		var hops: int = game._supply_hops(str(sid))
		if hops >= 900:
			continue
		var flow: Dictionary = Formulas.outpost_flow(int(st.get("held_weeks", 0)) + 1, hops, str(st.focus))
		s.materials = maxi(0, int(s.materials) - int(flow.upkeep_materials))
		outpost.materials -= int(flow.upkeep_materials)
		for key in ["food", "materials", "air"]:
			s[key] += int(flow.get(key, 0))
			outpost[key] += int(flow.get(key, 0))
	for key in outpost:
		if int(outpost[key]) != 0:
			out[key].why.append("outposts %+d %s" % [int(outpost[key]), key])
	for key in ["food", "air", "materials"]:
		var cap := game.storage_cap(key)
		if int(s[key]) > cap:
			out[key].why.append("storage cap %d: %d over the cap is lost" % [cap, int(s[key]) - cap])
			s[key] = cap
	var cap_food := game.storage_cap("food")
	var spoil_line := int(float(cap_food) * float(game.bal.spoil_line))
	if cap_food > 0 and int(s.food) > spoil_line:
		var loss := int(round(float(int(s.food) - spoil_line) * float(game.bal.spoil_rate)))
		if loss > 0:
			out.food.why.append("spoilage above %d: -%d" % [spoil_line, loss])
			s.food = maxi(0, int(s.food) - loss)
	if game.week == game.rot_week:
		out.food.why.append("rot week: part of the surplus rots")
	s.food = maxi(0, int(s.food) - game.food_need())
	s.air = maxi(0, int(s.air) - game.air_need())
	s.power = maxi(0, int(s.power) - need_power)
	var upkeep := int(game.bal.filter_upkeep)
	for room in game.rooms:
		if str(room.type) == "air_filter" and int(s.materials) >= upkeep:
			s.materials = int(s.materials) - upkeep
	for key in KEYS:
		out[key]["replay"] = int(s[key]) - int(game.stock[key])


func _count(name: String) -> void:
	counts[name] = int(counts.get(name, 0)) + 1
