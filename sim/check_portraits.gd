extends SceneTree

## Resident portraits (data/resident_profiles.json, data/cast_portraits.json): the profiles are valid, the Coney
## cast and the core residents always wear their pins, everyone else a face of their own sex picked when they
## arrive and kept for the run, and nobody ever wears a face of the other sex. Played through real bot runs,
## reading Game.portrait_name, the same call station.gd makes for every portrait it draws.
##   godot --headless --path . -s res://sim/check_portraits.gd

const SEEDS := [1, 2, 3, 4, 5, 6]
const PORTRAITS := 28
const GENERATED := 400


func _init() -> void:
	Copy.set_lang("en")
	var bad: PackedStringArray = []
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("PORTRAIT CHECK FAILED: " + catalog.error)
		quit(1)
		return
	var names: Array = []
	for i in range(1, PORTRAITS + 1):
		var name := "portrait_%02d" % i
		if ResourceLoader.exists("res://assets/portraits/%s.webp" % name):
			names.append(name)
	if names.size() != PORTRAITS:
		bad.append("generic portraits %d of %d" % [names.size(), PORTRAITS])
	var problems := catalog.profile_problems()
	bad.append_array(problems)
	print("Profiles: %d residents, %d problems" % [catalog.profiles.get("residents", {}).size(), problems.size()])
	var faces: Dictionary = catalog.profiles.get("portrait_sex", {})
	var pins: Dictionary = catalog.cast_portraits

	var start := Game.new()
	start.setup(catalog, 1, 40)
	var pinned := start.pinned_faces()
	var free := {"m": 0, "f": 0}
	for face in faces:
		if not pinned.has(face):
			free[str(faces[face])] += 1
	print("Pinned faces %d of %d; free for everyone else: %d men, %d women" % [pinned.size(), faces.size(), free.m, free.f])
	for person in start.residents:
		var id := str(person.id)
		var cast := start.cast_of(id)
		var want := str(pins.get(cast, "")) if cast != "" else str(catalog.profiles.residents.get(id, {}).get("portrait", ""))
		if want != "" and start.portrait_name(id, names) != want:
			bad.append("start: %s (%s) wears %s, pinned %s" % [id, cast, start.portrait_name(id, names), want])

	var seen := 0
	var shared_weeks := 0
	var first_shared := ""
	var most_shared := 0
	for run_seed in SEEDS:
		var bot := Bot.new()
		bot.profile = "careful"
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		var guard := 0
		var keyed := {}
		while game.over == "" and guard < 42:
			guard += 1
			var used := {}
			for person in game.residents:
				var id := str(person.id)
				var face := game.portrait_name(id, names)
				seen += 1
				if str(faces.get(face, "")) != str(person.get("sex", "")):
					bad.append("seed %d W%d: %s (%s) wears %s (%s)" % [run_seed, game.week, id, person.get("sex", "?"), face, faces.get(face, "?")])
				if keyed.has(id) and keyed[id] != face:
					bad.append("seed %d W%d: %s changed face %s to %s" % [run_seed, game.week, id, keyed[id], face])
				keyed[id] = face
				used[face] = used.get(face, []) + [id]
			var shared := 0
			for face in used:
				if used[face].size() > 1:
					shared += used[face].size() - 1
					if first_shared == "":
						first_shared = "seed %d week %d: %s share %s" % [run_seed, game.week, ", ".join(used[face]), face]
			if shared > 0:
				shared_weeks += 1
			most_shared = maxi(most_shared, shared)
			bot._act(game)
			game.end_week()
			if game.week == 20 and game.over == "":
				var copy := Game.new()
				copy.setup(catalog, 99, 40)
				var data := game.export_state()
				data["schema"] = Game.SAVE_SCHEMA
				if not copy.import_state(data):
					bad.append("seed %d: reload failed %s" % [run_seed, copy.load_error])
				else:
					for person in game.residents:
						if copy.portrait_name(str(person.id), names) != game.portrait_name(str(person.id), names):
							bad.append("seed %d: %s changes face across load" % [run_seed, person.id])
	print("Bot runs: %d seeds, %d resident-weeks, every face of the wearer's sex and kept for the run" % [SEEDS.size(), seen])
	print("Weeks with living residents sharing a face: %d of the runs' weeks, at most %d extra wearers in a week" % [shared_weeks, most_shared])
	if first_shared != "":
		print("First shared face: " + first_shared)

	var crowd := Game.new()
	crowd.setup(catalog, 7, 40)
	crowd._hire(GENERATED)
	var sexes := {"m": 0, "f": 0}
	for person in crowd.residents:
		var face := crowd.portrait_name(str(person.id), names)
		sexes[str(person.sex)] = int(sexes.get(str(person.sex), 0)) + 1
		if str(faces.get(face, "")) != str(person.sex):
			bad.append("crowd: %s %s (%s) wears %s" % [person.id, person.name, person.sex, face])
		var first := str(person.name).get_slice(" ", 0)
		if str(person.id).begins_with("n") and str(catalog.profiles.generated_names.get(first, person.sex)) != str(person.sex):
			bad.append("crowd: %s named %s is %s" % [person.id, person.name, person.sex])
	print("Generated crowd: %d newcomers joined the residents (%d men, %d women in all), all in faces of their sex" % [GENERATED, sexes.m, sexes.f])

	var legacy: Dictionary = start.people["kim"].duplicate(true)
	legacy.erase("cast_id")
	legacy.erase("face")
	if start.portrait_pin(legacy) != str(pins.get("bait", "")) or start.sex_of(legacy) != "m":
		bad.append("a save without cast_id loses Bait's portrait or sex")
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
			var face := other.portrait_name(id, names)
			if other.cast_of(id) != "":
				bad.append("%s capital %s: %s is cast" % [plain, other.capital_id, id])
			if str(faces.get(face, "")) != str(person.sex):
				bad.append("capital without the cast: %s (%s) wears %s" % [id, person.sex, face])
			distinct[face] = true
		print("Capital without the cast (%s): %d residents, %d distinct faces" % [other.capital_id, other.residents.size(), distinct.size()])
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
