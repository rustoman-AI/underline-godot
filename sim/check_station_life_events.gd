extends SceneTree

## P62 Station Life Events. Five one-shots join the mid-week pool and use the existing event card.
## silent_car follow logs a Listening Post flavor line at the next dawn only when the post is staffed.
## Not a probe, not intel, not Blown, and not a soft-dawn chip.
##   godot --headless --path . -s res://sim/check_station_life_events.gd

const PACK := ["chalk_marks", "silent_car", "mold_cart", "shift_trade", "pickle_stamp"]
const P54 := ["toll", "toll_next", "toll_last", "knock", "knock_next", "knock_last", "loan", "loan_next", "armband"]
const EA := ["stores_turn", "diesel", "ration_coat"]
const SOFT := ["rumor_dawn", "border_dawn_new", "heard_rail", "home_pending", "home_dawn", "dawn_soft_kind", "rail_dawn"]
const FLAVOR := "Logged at the Listening Post"
const SOFT_STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("STATION LIFE FAIL catalog ", catalog.error)
		quit(1)
		return
	var pack := _pack()
	var failed := false
	if not _check_once(catalog):
		failed = true
	if not _check_shape(catalog, pack):
		failed = true
	if not _check_copy(catalog, pack):
		failed = true
	if not _check_free(catalog, pack):
		failed = true
	if not _check_scale(catalog):
		failed = true
	if not _check_pool(catalog):
		failed = true
	if not _check_flavor(catalog):
		failed = true
	if not _check_soft(catalog):
		failed = true
	if not _check_art(catalog):
		failed = true
	if failed:
		print("STATION LIFE FAIL")
		quit(1)
		return
	var lost := _careful_band()
	var pct := 100.0 * float(lost) / 60.0
	print("Careful loss: %d/60 (%.1f percent)" % [lost, pct])
	# Spec band is 15-35% of 60 (9-21). Master careful before this pack was 2/60.
	# The five one-shots land on the floor: 9/60. shift_trade tax stays tokens_small 2 and
	# hope_small -1. Cutting that step drops under the floor. Cough is untouched.
	print("NOTE spec band is 15-35 percent of 60. Measured %d/60 (%.1f percent). Master before the pack was 2/60. Tax and hope stay on the small step; cough untouched." % [lost, pct])
	if lost < 9 or lost > 21:
		print("STATION LIFE FAIL careful loss %d/60 outside 15-35 percent" % lost)
		quit(1)
		return
	print("STATION LIFE OK")
	quit(0)


func _pack() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/station_life_events.json"))
	if not (data is Dictionary):
		return {}
	return data


func _by_id(catalog: Catalog) -> Dictionary:
	var out := {}
	for ev in catalog.events:
		var id := str(ev.get("id", ""))
		if not out.has(id):
			out[id] = []
		out[id].append(ev)
	return out


func _one(index: Dictionary, id: String) -> Dictionary:
	var rows: Array = index.get(id, [])
	if rows.size() != 1:
		return {}
	return rows[0]


func _rows(pack: Dictionary) -> Dictionary:
	var out := {}
	for raw in pack.get("events", []):
		if raw is Dictionary:
			out[str(raw.get("id", ""))] = raw
	return out


func _check_once(catalog: Catalog) -> bool:
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json"))
	var in_base := {}
	for ev in raw if raw is Array else []:
		in_base[str(ev.get("id", ""))] = true
	for id in PACK:
		if index.get(id, []).size() != 1:
			bad.append("%s x%d" % [id, index.get(id, []).size()])
		if in_base.has(id):
			bad.append("%s also in events.json" % id)
		if P54.has(id) or EA.has(id):
			bad.append("%s collides" % id)
	for id in P54 + EA:
		if index.get(id, []).size() != 1:
			bad.append("kept %s x%d" % [id, index.get(id, []).size()])
	if str(_pack().get("_roadmap", "")) != "P62":
		bad.append("roadmap")
	if not bad.is_empty():
		print("Once: FAIL ", ", ".join(bad))
		return false
	print("Once: ok")
	return true


func _check_shape(catalog: Catalog, pack: Dictionary) -> bool:
	var index := _by_id(catalog)
	var rows := _rows(pack)
	var bad: PackedStringArray = []
	for id in PACK:
		var ev := _one(index, id)
		var raw: Dictionary = rows.get(id, {})
		_want(bad, not ev.is_empty() and not raw.is_empty(), id)
		_want(bad, str(ev.get("who", "")) == str(raw.get("who", "")), "%s who" % id)
		_want(bad, int(ev.get("min_week", 0)) == int(raw.get("min_week", -1)), "%s week" % id)
		_want(bad, int(ev.get("weight", 0)) == int(raw.get("weight", -1)) and int(ev.get("weight", 0)) > 0, "%s weight" % id)
		_want(bad, not bool(ev.get("major", false)), "%s major" % id)
		_want(bad, str(ev.get("follow", "")) == "" and not bool(ev.get("chain_only", false)), "%s chain" % id)
		_want(bad, not ev.has("trigger") and not ev.has("needs") and not ev.has("banner"), "%s extra" % id)
		_want(bad, bool(ev.get("station_life", false)), "%s mark" % id)
		var want := {}
		for choice in raw.get("choices", []):
			want[str(choice.get("id", ""))] = true
		var got := {}
		for choice in ev.get("choices", []):
			var cid := str(choice.get("id", ""))
			got[cid] = true
			if choice.has("map") or choice.has("intel") or choice.has("probe"):
				bad.append("%s %s invent" % [id, cid])
		_want(bad, got.keys() == want.keys() or _same_keys(got, want.keys()), "%s choices" % id)
	if not bad.is_empty():
		print("Shape: FAIL ", ", ".join(bad))
		return false
	print("Shape: ok")
	return true


func _want(bad: PackedStringArray, ok: bool, label: String) -> void:
	if not ok:
		bad.append(label)


func _same_keys(got: Dictionary, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for key in want:
		if not got.has(str(key)):
			return false
	return true


func _check_copy(catalog: Catalog, pack: Dictionary) -> bool:
	var index := _by_id(catalog)
	var rows := _rows(pack)
	var bad: PackedStringArray = []
	var game := Game.new()
	game.catalog = catalog
	for id in PACK:
		var ev := _one(index, id)
		var raw: Dictionary = rows.get(id, {})
		for key in ["title", "text"]:
			for lang in ["en", "ru"]:
				Copy.set_lang(lang)
				var shown := game.line_of(ev, key)
				var cite := str(raw.get(key, {}).get(lang, ""))
				if shown == "" or shown != cite:
					bad.append("%s %s %s" % [id, key, lang])
		var by_id := {}
		for choice in raw.get("choices", []):
			by_id[str(choice.get("id", ""))] = choice
		for choice in ev.get("choices", []):
			var cid := str(choice.get("id", ""))
			var src: Dictionary = by_id.get(cid, {})
			for lang in ["en", "ru"]:
				Copy.set_lang(lang)
				var shown := game.line_of(choice, "label")
				var cite := str(src.get("label", {}).get(lang, ""))
				if shown == "" or shown != cite:
					bad.append("%s %s %s" % [id, cid, lang])
	Copy.set_lang("en")
	if not bad.is_empty():
		print("Copy: FAIL ", ", ".join(bad))
		return false
	print("Copy: ok")
	return true


func _check_free(catalog: Catalog, pack: Dictionary) -> bool:
	var index := _by_id(catalog)
	var rows := _rows(pack)
	var bad: PackedStringArray = []
	for id in PACK:
		var ev := _one(index, id)
		var raw: Dictionary = rows.get(id, {})
		var free := false
		var by_id := {}
		for choice in ev.get("choices", []):
			by_id[str(choice.get("id", ""))] = choice
			if _cost_empty(choice.get("cost", {})):
				free = true
		if not free:
			bad.append(id)
		for choice in raw.get("choices", []):
			var cid := str(choice.get("id", ""))
			var empty := _cost_empty(by_id.get(cid, {}).get("cost", {}))
			if bool(choice.get("free", false)) != empty:
				bad.append("%s %s free" % [id, cid])
	if not bad.is_empty():
		print("Free: FAIL ", ", ".join(bad))
		return false
	print("Free: ok")
	return true


func _cost_empty(cost) -> bool:
	if not (cost is Dictionary):
		return true
	for key in cost:
		if int(cost[key]) > 0:
			return false
	return true


func _check_scale(catalog: Catalog) -> bool:
	var scale: Dictionary = catalog.balance.get("station_life_scale", {})
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	for key in ["hope_small", "discontent_small", "food_small", "materials_small", "tokens_small", "influence_small", "power_small", "air_small", "opinion_small"]:
		if int(scale.get(key, 0)) <= 0:
			bad.append("scale %s" % key)
	if int(scale.get("tokens_small", 99)) > 4 or int(scale.get("hope_small", 99)) > 1:
		bad.append("tax spike")
	for id in PACK:
		var spec: Dictionary = Catalog.STATION_LIFE_MAP.get(id, {})
		var choices := {}
		for choice in _one(index, id).get("choices", []):
			choices[str(choice.get("id", ""))] = choice
		for cid in spec:
			if not choices.has(cid):
				bad.append("%s missing %s" % [id, cid])
				continue
			_match_choice(bad, scale, id, cid, choices[cid], spec[cid])
	if not bad.is_empty():
		print("Scale: FAIL ", ", ".join(bad))
		return false
	print("Scale: ok")
	return true


func _match_choice(bad: PackedStringArray, scale: Dictionary, id: String, cid: String, choice: Dictionary, spec: Dictionary) -> void:
	for key in spec:
		if str(key) == "dawn_flavor":
			var quote := str(choice.get("dawn_flavor", {}).get("en", ""))
			if quote != FLAVOR:
				bad.append("%s %s flavor %s" % [id, cid, quote])
			continue
		if str(key) == "cost":
			var cost: Dictionary = choice.get("cost", {})
			var want: Dictionary = spec[key]
			for sub in want:
				var got := int(cost.get(sub, 0))
				var signed := _signed(scale, str(want[sub]))
				if got != signed:
					bad.append("%s %s cost %s %d != %d" % [id, cid, sub, got, signed])
			continue
		var got_top := int(choice.get(key, 0))
		var top_signed := _signed(scale, str(spec[key]))
		if got_top != top_signed:
			bad.append("%s %s %s %d != %d" % [id, cid, key, got_top, top_signed])
	if str(id) == "silent_car" and str(cid) == "bar" and choice.has("hope"):
		bad.append("bar hope not held")
	if str(id) == "pickle_stamp" and str(cid) == "return" and choice.has("food"):
		bad.append("return food")
	if str(id) == "mold_cart" and (str(cid) == "replace" or str(cid) == "boil") and choice.has("air"):
		bad.append("%s air not held" % cid)


func _signed(scale: Dictionary, name: String) -> int:
	var neg := name.begins_with("-")
	var key := name.trim_prefix("-")
	var n := int(scale.get(key, 0))
	return -n if neg else n


func _check_pool(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 3, 40)
	var bad: PackedStringArray = []
	for id in PACK:
		var ev := game._event_by_id(id)
		game.week = int(ev.get("min_week", 1)) - 1
		if game._event_ok(ev):
			bad.append("%s early" % id)
		game.week = int(ev.get("min_week", 1))
		if not game._event_ok(ev):
			bad.append("%s blocked" % id)
	game.week = 10
	var pool := {}
	for ev in game._event_pool(false):
		pool[str(ev.get("id", ""))] = true
	for id in PACK:
		if not pool.has(id):
			bad.append("%s not in pool" % id)
	for id in ["toll_next", "toll_last", "knock_next", "knock_last", "loan_next"]:
		if pool.has(id):
			bad.append("%s chain in pool" % id)
	if not bad.is_empty():
		print("Pool: FAIL ", ", ".join(bad))
		return false
	print("Pool: ok")
	return true


func _check_flavor(catalog: Catalog) -> bool:
	var bare := Game.new()
	bare.setup(catalog, 8, 40)
	bare.week = 6
	bare.stock.food = 20
	bare.hope = 40
	var intel_before := _intel(bare)
	var op_before := int(bare.opinions.get("directorate", 0))
	var soft_before := _soft(bare)
	if not _play(bare, "silent_car", "follow"):
		print("Flavor: FAIL unstaffed apply")
		return false
	if _logged(bare) or str(bare.flags.get("station_life_listen", "")) != "":
		print("Flavor: FAIL unstaffed logged")
		return false
	if _intel(bare) != intel_before or int(bare.opinions.get("directorate", 0)) != op_before:
		print("Flavor: FAIL unstaffed intel or opinion")
		return false
	if bare.flags.has("listening_probe_sid") or _blown(bare):
		print("Flavor: FAIL unstaffed probe")
		return false
	if not _soft_same(bare, soft_before):
		print("Flavor: FAIL unstaffed soft")
		return false
	var staffed := Game.new()
	staffed.setup(catalog, 9, 40)
	staffed.week = 6
	staffed.stock.food = 20
	staffed.hope = 40
	if not _staff_post(staffed):
		print("Flavor: FAIL could not staff the post")
		return false
	var food := int(staffed.stock.food)
	var hope := staffed.hope
	var intel_staffed := _intel(staffed)
	var op_staffed := int(staffed.opinions.get("directorate", 0))
	var soft_staffed := _soft(staffed)
	if not _play(staffed, "silent_car", "follow"):
		print("Flavor: FAIL staffed apply")
		return false
	var scale: Dictionary = staffed.catalog.balance.get("station_life_scale", {})
	if int(staffed.stock.food) != food - int(scale.get("food_small", 0)):
		print("Flavor: FAIL food %d -> %d" % [food, int(staffed.stock.food)])
		return false
	if staffed.hope != hope + int(scale.get("hope_small", 0)):
		print("Flavor: FAIL hope %d -> %d" % [hope, staffed.hope])
		return false
	if _logged(staffed) or str(staffed.flags.get("station_life_listen", "")) != FLAVOR:
		print("Flavor: FAIL queued '%s'" % str(staffed.flags.get("station_life_listen", "")))
		return false
	if _intel(staffed) != intel_staffed or int(staffed.opinions.get("directorate", 0)) != op_staffed:
		print("Flavor: FAIL staffed intel or opinion")
		return false
	if staffed.flags.has("listening_probe_sid") or _blown(staffed):
		print("Flavor: FAIL staffed probe or blown")
		return false
	if not _soft_same(staffed, soft_staffed):
		print("Flavor: FAIL staffed soft changed during the choice")
		return false
	staffed._dawn_after_orders()
	if not _logged(staffed) or str(staffed.flags.get("station_life_listen", "")) != "":
		print("Flavor: FAIL dawn log")
		return false
	if staffed.flags.has("listening_probe_sid") or _blown(staffed):
		print("Flavor: FAIL dawn invented a probe")
		return false
	print("Flavor: ok")
	return true


func _logged(game: Game) -> bool:
	var n := 0
	for entry in game.log:
		if str(entry.get("text", "")) == FLAVOR:
			n += 1
	return n == 1


func _intel(game: Game) -> int:
	var n := 0
	for sid in game.stations:
		n += game.station_intel(str(sid))
	return n


func _blown(game: Game) -> bool:
	for moment in game.chronicle:
		if str(moment.get("kind", "")) == "listening_blown":
			return true
	for room in game.rooms:
		if str(room.get("type", "")) == "listening_post" and int(room.get("disabled", 0)) > 0:
			return true
	return false


func _staff_post(game: Game) -> bool:
	var cell := _open_cell(game)
	if cell.x < 0:
		return false
	game._place_room("listening_post", cell.x, cell.y)
	var room = game._listening_room()
	if room == null:
		return false
	for person in game.residents:
		if int(person.get("sick", 0)) > 0 or str(person.get("post", "")) != "":
			continue
		room.staff.append(str(person.id))
		person["post"] = str(room.uid)
		return game.listening_active()
	return false


func _open_cell(game: Game) -> Vector2i:
	for key in game.cells:
		var cell: Dictionary = game.cells[key]
		if game._cell_buildable(cell):
			return Vector2i(int(cell.level), int(cell.cell))
	return Vector2i(-1, -1)


func _check_soft(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 10
	game.stock.food = 30
	game.stock.materials = 30
	game.stock.tokens = 30
	game.stock.influence = 10
	game.hope = 50
	var before := _soft(game)
	var stack: Array = game.dawn_soft_stack()
	if stack != SOFT_STACK:
		print("Soft: FAIL stack ", stack)
		return false
	for pair in [["chalk_marks", "leave"], ["silent_car", "bar"], ["mold_cart", "scrape"], ["shift_trade", "ban"], ["pickle_stamp", "hide"]]:
		if not _play(game, str(pair[0]), str(pair[1])):
			print("Soft: FAIL %s" % str(pair[0]))
			return false
	if not _soft_same(game, before):
		print("Soft: FAIL flags changed")
		return false
	if game.dawn_soft_stack() != SOFT_STACK:
		print("Soft: FAIL stack moved")
		return false
	print("Soft: ok")
	return true


func _soft(game: Game) -> Dictionary:
	var out := {}
	for key in SOFT:
		out[key] = game.flags.get(key, null)
	return out


func _soft_same(game: Game, before: Dictionary) -> bool:
	for key in SOFT:
		if game.flags.get(key, null) != before[key]:
			return false
	return true


func _play(game: Game, event_id: String, choice_id: String) -> bool:
	var ev := game._event_by_id(event_id)
	game.pending.clear()
	game.week_event_ids = {}
	if not game._present_event(ev):
		return false
	return game.apply({"kind": "event", "event_id": event_id, "choice_id": choice_id})


func _check_art(catalog: Catalog) -> bool:
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	for id in PACK:
		var ev := _one(index, id)
		if str(ev.get("banner", "")) != "":
			bad.append("%s dedicated plate" % id)
			continue
		var plate := ArtPack.resolve_event_banner(ev)
		if plate == "":
			bad.append("%s no mood" % id)
		else:
			print("Art: %s uses mood plate %s" % [id, plate])
	if not bad.is_empty():
		print("Art: FAIL ", ", ".join(bad))
		return false
	print("Art: ok (mood plates only, not blocking)")
	return true


func _careful_band() -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var report: Dictionary = Bot.new().play(40, run_seed, "careful")
		if str(report.get("over", "")) != "time":
			lost += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return lost
