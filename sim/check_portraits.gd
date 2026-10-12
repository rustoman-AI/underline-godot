extends SceneTree

## Resident portraits (data/cast_portraits.json): the five Coney cast members always wear their pinned
## portrait, nobody else ever wears a pinned one, and the others take the remaining faces in arrival order, so
## no two share a face while the pool lasts. Played through real bot runs, reading Game.portrait_name, the same
## call station.gd makes for every portrait it draws.
##   godot --headless --path . -s res://sim/check_portraits.gd

const SEEDS := [1, 2, 3, 4, 5, 6]
const SLOTS := {"chris": "old_man_coney", "mina": "salty_maggie", "kim": "bait", "drew": "barnum", "ann": "sylvia"}


func _init() -> void:
	Copy.set_lang("en")
	var bad: PackedStringArray = []
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("PORTRAIT CHECK FAILED: " + catalog.error)
		quit(1)
		return
	var names: Array = []
	for i in range(1, 17):
		var name := "portrait_%02d" % i
		if ResourceLoader.exists("res://assets/portraits/%s.webp" % name):
			names.append(name)
	if names.size() != 16:
		bad.append("generic portraits %d of 16" % names.size())
	var pins: Dictionary = catalog.cast_portraits
	var pinned: Array = pins.values()
	var cast_ids: Array = []
	for row in catalog.coney.get("characters", []):
		cast_ids.append(str(row.get("id", "")))
	for cast in cast_ids:
		if not pins.has(cast):
			bad.append("%s has no pin" % cast)
	for cast in pins:
		if not cast_ids.has(str(cast)):
			bad.append("pin for unknown cast id %s" % cast)
		if not names.has(str(pins[cast])):
			bad.append("%s pinned to missing %s" % [cast, pins[cast]])
		if pinned.count(pins[cast]) > 1:
			bad.append("%s shared by two cast members" % pins[cast])
	var free := names.size() - pinned.size()
	print("Pins: %s; %d faces left for everyone else" % [str(pins), free])

	var start := Game.new()
	start.setup(catalog, 1, 40)
	var others: Array = []
	for person in start.residents:
		if start.cast_of(str(person.id)) == "":
			others.append(str(person.id))
	var faces := {}
	for id in others:
		var face := start.portrait_name(id, names)
		faces[face] = int(faces.get(face, 0)) + 1
	var most := 0
	for face in faces:
		most = maxi(most, int(faces[face]))
	var fair := ceili(float(others.size()) / float(maxi(free, 1)))
	print("Start: %d residents outside the cast, %d distinct faces, at most %d people per face" % [others.size(), faces.size(), most])
	if faces.size() != mini(others.size(), free) or most != fair:
		bad.append("start faces %d distinct, %d per face; the pool allows %d and %d" % [faces.size(), most, mini(others.size(), free), fair])
	if others.size() > free:
		print("NOTE: the pool is short: %d people outside the cast share %d faces from week 1." % [others.size(), free])

	var ranks := {}
	var seen := 0
	var worst_excess := 0
	for run_seed in SEEDS:
		var bot := Bot.new()
		bot.profile = "careful"
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			var used := {}
			var living := 0
			for person in game.residents:
				var id := str(person.id)
				var face := game.portrait_name(id, names)
				var cast := game.cast_of(id)
				seen += 1
				if cast != "":
					if face != str(pins.get(cast, "")):
						bad.append("seed %d W%d: %s (%s) wears %s" % [run_seed, game.week, id, cast, face])
					continue
				if pinned.has(face):
					bad.append("seed %d W%d: %s wears the pinned %s" % [run_seed, game.week, id, face])
				var rank := game.arrival_rank(id)
				if rank < 0:
					bad.append("seed %d: %s has no arrival rank" % [run_seed, id])
				elif ranks.has(rank) and str(ranks[rank]) != face:
					bad.append("rank %d wears %s and %s" % [rank, ranks[rank], face])
				ranks[rank] = face
				used[face] = int(used.get(face, 0)) + 1
				living += 1
			var shared := 0
			for face in used:
				shared += int(used[face]) - 1
			worst_excess = maxi(worst_excess, shared - maxi(0, living - free))
			bot._act(game)
			game.end_week()
	var keys := ranks.keys()
	keys.sort()
	for rank in keys:
		for step in range(1, free):
			if ranks.has(int(rank) + step) and ranks[int(rank) + step] == ranks[rank]:
				bad.append("ranks %d and %d share %s" % [rank, int(rank) + step, ranks[rank]])
	print("Bot runs: %d seeds, %d resident-weeks, %d arrival ranks; any %d arrivals in a row have distinct faces" % [SEEDS.size(), seen, keys.size(), free])
	print("Living residents sharing a face beyond what the pool forces: at most %d in any week" % worst_excess)

	var legacy: Dictionary = start.people["kim"].duplicate(true)
	legacy.erase("cast_id")
	start.people["kim"] = legacy
	if start.portrait_name("kim", names) != str(pins.get("bait", "")):
		bad.append("a save without cast_id loses Bait's portrait")
	for id in ["southdepot", "depot", "", "nobody"]:
		if pinned.has(start.portrait_name(id, names)):
			bad.append("non-resident %s wears a pinned face" % id)

	var plain := _plain_capital(catalog)
	if plain != "":
		var other := Game.new()
		other.catalog = catalog
		other.bal = catalog.balance
		other.player = plain
		other.capital_id = str(catalog.factions[plain].capital)
		other._init_people()
		var distinct := {}
		for person in other.residents:
			var id := str(person.id)
			if other.cast_of(id) != "":
				bad.append("%s capital %s: %s is cast" % [plain, other.capital_id, id])
			distinct[other.portrait_name(id, names)] = true
		print("Capital without the cast (%s): %d residents, all %d faces in use, none pinned" % [other.capital_id, other.residents.size(), distinct.size()])
		if distinct.size() != mini(other.residents.size(), names.size()):
			bad.append("capital without the cast uses %d faces" % distinct.size())
	if bad.is_empty():
		print("PORTRAIT CHECK OK")
		quit(0)
		return
	for line in bad.slice(0, 20):
		print("  " + line)
	print("PORTRAIT CHECK FAILED (%d)" % bad.size())
	quit(1)


func _plain_capital(catalog: Catalog) -> String:
	for fid in catalog.factions:
		var capital := str(catalog.factions[fid].get("capital", ""))
		if capital != "" and capital != "southdepot" and capital != "coney":
			return str(fid)
	return ""
