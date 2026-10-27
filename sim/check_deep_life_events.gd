extends SceneTree

## P66 Deep Life Events. Nine one-shots join the mid-week pool and use the existing event card.
## synod_sheet may write Game.synod. It does not spend Synod.
## name_scrubbed is a flavor event. It does not ship Named lives.
## side_door watch, twin_marks copy, and warm_smell send log a Listening Post line at the next
## dawn only when the post is staffed. Not a probe, not intel, not Blown, and not a soft-dawn chip.
##   godot --headless --path . -s res://sim/check_deep_life_events.gd

const PACK := ["rust_water", "shoe_gate", "belt_squeal", "synod_sheet", "side_door", "frost_glass", "name_scrubbed", "twin_marks", "warm_smell"]
const P62 := ["chalk_marks", "silent_car", "mold_cart", "shift_trade", "pickle_stamp"]
const P64 := ["wet_bunk", "vent_prayer", "crate_blank", "filter_mesh", "shelf_feud", "fever_lamp", "count_short", "cold_rail"]
const P54 := ["toll", "toll_next", "toll_last", "knock", "knock_next", "knock_last", "loan", "loan_next", "armband"]
const EA := ["stores_turn", "diesel", "ration_coat"]
const SOFT := ["rumor_dawn", "border_dawn_new", "heard_rail", "home_pending", "home_dawn", "dawn_soft_kind", "rail_dawn"]
const SOFT_STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]
const FLAVOR := "Logged at the Listening Post"
const SPEND_KEYS := ["escort", "synod_spend", "spend", "synod_cost"]
const FLAVOR_CHOICES := [["side_door", "watch"], ["twin_marks", "copy"], ["warm_smell", "send"]]


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("DEEP LIFE FAIL catalog ", catalog.error)
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
	if not _check_apply(catalog):
		failed = true
	if not _check_synod(catalog):
		failed = true
	if not _check_named(catalog):
		failed = true
	if not _check_flavor(catalog):
		failed = true
	if not _check_soft(catalog):
		failed = true
	if not _check_cough(catalog):
		failed = true
	if not _check_ui():
		failed = true
	_check_art(catalog)
	if failed:
		print("DEEP LIFE FAIL")
		quit(1)
		return
	var lost := _careful_band()
	var pct := 100.0 * float(lost) / 60.0
	var food_small := int(catalog.balance.get("deep_life_scale", {}).get("food_small", 0))
	print("Careful loss: %d/60 (%.1f percent)" % [lost, pct])
	# Spec band is 15-35% of 60 (9-21). This branch is from master before P62, where careful was 2/60.
	# Open packs from that master can land under the band alone. Do not edit cough to climb.
	# food_small is the only food step. Soften it before any other lever if the run is over the band.
	print("NOTE spec band is 15-35 percent of 60. Measured %d/60 (%.1f percent). Master before the pack was 2/60. P62 alone was about 9/60. P64 alone was about 7/60. food_small is %d. Cough untouched. No soft dawn." % [lost, pct, food_small])
	if lost < 9 or lost > 21:
		print("DEEP LIFE FAIL careful loss %d/60 outside 15-35 percent" % lost)
		quit(1)
		return
	print("DEEP LIFE OK")
	quit(0)


func _pack() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/deep_life_events.json"))
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


func _file_ids(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := {}
	var rows: Array = []
	if data is Array:
		rows = data
	elif data is Dictionary:
		rows = data.get("events", [])
	for ev in rows:
		if ev is Dictionary:
			out[str(ev.get("id", ""))] = true
	return out


func _check_once(catalog: Catalog) -> bool:
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	var in_base := _file_ids("res://data/events.json")
	var in_pool := _file_ids("res://data/events_pool.json")
	var in_leaders := _file_ids("res://data/events_leaders.json")
	var in_story := _file_ids("res://data/events_story.json")
	var forbidden: Array = []
	forbidden.append_array(P62)
	forbidden.append_array(P64)
	forbidden.append_array(P54)
	forbidden.append_array(EA)
	for id in PACK:
		if index.get(id, []).size() != 1:
			bad.append("%s x%d" % [id, index.get(id, []).size()])
		if in_base.has(id) or in_pool.has(id) or in_leaders.has(id) or in_story.has(id):
			bad.append("%s also in an older event file" % id)
		if forbidden.has(id):
			bad.append("%s collides" % id)
	for id in P54 + EA:
		if index.get(id, []).size() != 1:
			bad.append("kept %s x%d" % [id, index.get(id, []).size()])
	for id in P62 + P64:
		if index.get(id, []).size() > 0:
			bad.append("shipped %s" % id)
	if str(_pack().get("_roadmap", "")) != "P66":
		bad.append("roadmap")
	if _rows(_pack()).size() != PACK.size():
		bad.append("pack count")
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
		_want(bad, bool(ev.get("deep_life", false)), "%s mark" % id)
		var want := {}
		for choice in raw.get("choices", []):
			want[str(choice.get("id", ""))] = true
		var got := {}
		for choice in ev.get("choices", []):
			var cid := str(choice.get("id", ""))
			got[cid] = true
			for key in SPEND_KEYS:
				if choice.has(key):
					bad.append("%s %s %s" % [id, cid, key])
			if choice.has("synod") and int(choice.synod) < 0:
				bad.append("%s %s spends synod" % [id, cid])
			var cost = choice.get("cost", {})
			if cost is Dictionary and cost.has("synod"):
				bad.append("%s %s synod cost" % [id, cid])
			if choice.has("intel") or choice.has("probe") or choice.has("people") or choice.has("flag"):
				bad.append("%s %s invent" % [id, cid])
		_want(bad, _same_keys(got, want.keys()), "%s choices" % id)
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
	var scale: Dictionary = catalog.balance.get("deep_life_scale", {})
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	for key in ["hope_small", "discontent_small", "food_small", "materials_small", "influence_small", "power_small", "power_soft", "opinion_small", "synod_small"]:
		if int(scale.get(key, 0)) <= 0:
			bad.append("scale %s" % key)
	if int(scale.get("hope_small", 99)) > 1 or int(scale.get("discontent_small", 99)) > 1:
		bad.append("mood spike")
	if int(scale.get("food_small", 99)) > 2:
		bad.append("food spike")
	if int(scale.get("power_soft", 99)) >= int(scale.get("power_small", 0)):
		bad.append("power_soft not softer than power_small")
	if scale.has("tokens_small"):
		bad.append("token step invented")
	for id in PACK:
		var spec: Dictionary = Catalog.DEEP_LIFE_MAP.get(id, {})
		var choices := {}
		for choice in _one(index, id).get("choices", []):
			choices[str(choice.get("id", ""))] = choice
		for cid in spec:
			if not choices.has(cid):
				bad.append("%s missing %s" % [id, cid])
				continue
			_match_choice(bad, scale, id, cid, choices[cid], spec[cid])
	if _held(index, "shoe_gate", "leave", "hope") or _held(index, "belt_squeal", "replace", "power") or _held(index, "belt_squeal", "watch", "hope"):
		bad.append("held key present")
	if _held(index, "synod_sheet", "burn", "synod") or _held(index, "synod_sheet", "log", "hope") or _held(index, "side_door", "refuse", "hope"):
		bad.append("held synod or hope")
	if _held(index, "frost_glass", "seal", "air") or _held(index, "name_scrubbed", "rewrite", "hope") or _held(index, "twin_marks", "leave", "hope") or _held(index, "warm_smell", "bar", "hope"):
		bad.append("held air or hope")
	if _held(index, "rust_water", "boil", "food") or _held(index, "rust_water", "filter", "food"):
		bad.append("water not held")
	if not bad.is_empty():
		print("Scale: FAIL ", ", ".join(bad))
		return false
	print("Scale: ok")
	return true


func _held(index: Dictionary, id: String, cid: String, key: String) -> bool:
	for choice in _one(index, id).get("choices", []):
		if str(choice.get("id", "")) == cid:
			return choice.has(key)
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
		if game.week >= 1 and game._event_ok(ev):
			bad.append("%s early" % id)
		game.week = int(ev.get("min_week", 1))
		if not game._event_ok(ev):
			bad.append("%s blocked" % id)
		game.event_last[id] = game.week
		if game._event_ok(ev):
			bad.append("%s ignored cooldown" % id)
		game.event_last.erase(id)
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


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 10
	game.stock.food = 40
	game.stock.materials = 30
	game.stock.tokens = 30
	game.stock.power = 30
	game.stock.influence = 10
	game.hope = 50
	game.discontent = 20
	return game


func _play(game: Game, event_id: String, choice_id: String) -> bool:
	var ev := game._event_by_id(event_id)
	game.pending.clear()
	game.week_event_ids = {}
	if not game._present_event(ev):
		return false
	return game.apply({"kind": "event", "event_id": event_id, "choice_id": choice_id})


func _check_apply(catalog: Catalog) -> bool:
	var scale: Dictionary = catalog.balance.get("deep_life_scale", {})
	var bad: PackedStringArray = []
	for id in PACK:
		var game := _fresh(catalog)
		for key in ["food", "materials", "tokens", "power", "influence", "air"]:
			game.stock[key] = 0
		var free_id := ""
		for choice in game._event_by_id(id).get("choices", []):
			if _cost_empty(choice.get("cost", {})):
				free_id = str(choice.get("id", ""))
				break
		if free_id == "" or not _play(game, id, free_id):
			bad.append("%s free did not fire" % id)
	var boil := _fresh(catalog)
	var power := int(boil.stock.power)
	var hope := boil.hope
	var food := int(boil.stock.food)
	if not _play(boil, "rust_water", "boil"):
		bad.append("boil apply")
	elif int(boil.stock.power) != power - int(scale.get("power_small", 0)) or boil.hope != hope + int(scale.get("hope_small", 0)) or int(boil.stock.food) != food:
		bad.append("boil power or hope")
	var take := _fresh(catalog)
	var food_t := int(take.stock.food)
	var hope_t := take.hope
	var dis_t := take.discontent
	if not _play(take, "side_door", "take"):
		bad.append("take apply")
	elif int(take.stock.food) != food_t + int(scale.get("food_small", 0)) or take.hope != hope_t - int(scale.get("hope_small", 0)) or take.discontent != dis_t + int(scale.get("discontent_small", 0)):
		bad.append("take food")
	var refuse := _fresh(catalog)
	var op := int(refuse.opinions.get("exchange", 0))
	var hope_r := refuse.hope
	if not _play(refuse, "side_door", "refuse"):
		bad.append("refuse apply")
	elif int(refuse.opinions.get("exchange", 0)) != op - int(scale.get("opinion_small", 0)) or refuse.hope != hope_r:
		bad.append("refuse opinion")
	if not bad.is_empty():
		print("Apply: FAIL ", ", ".join(bad))
		return false
	print("Apply: ok")
	return true


func _check_synod(catalog: Catalog) -> bool:
	var scale: Dictionary = catalog.balance.get("deep_life_scale", {})
	var step := int(scale.get("synod_small", 0))
	var hope_step := int(scale.get("hope_small", 0))
	var dis_step := int(scale.get("discontent_small", 0))
	var inf_step := int(scale.get("influence_small", 0))
	var read := _fresh(catalog)
	var syn0 := read.synod
	var hope0 := read.hope
	var dis0 := read.discontent
	if not _play(read, "synod_sheet", "read"):
		print("Synod: FAIL read")
		return false
	if read.synod != syn0 + step or read.hope != hope0 + hope_step or read.discontent != dis0 + dis_step:
		print("Synod: FAIL read synod %d hope %d dis %d" % [read.synod - syn0, read.hope - hope0, read.discontent - dis0])
		return false
	if read.synod < 0 or read.flags.has("escort"):
		print("Synod: FAIL spend or escort")
		return false
	var burn := _fresh(catalog)
	var syn_b := burn.synod
	var hope_b := burn.hope
	if not _play(burn, "synod_sheet", "burn"):
		print("Synod: FAIL burn")
		return false
	if burn.synod != syn_b or burn.hope != hope_b - hope_step:
		print("Synod: FAIL burn moved synod or hope")
		return false
	var log := _fresh(catalog)
	var syn_l := log.synod
	var hope_l := log.hope
	var inf := int(log.stock.influence)
	if not _play(log, "synod_sheet", "log"):
		print("Synod: FAIL log")
		return false
	if log.synod != syn_l or log.hope != hope_l or int(log.stock.influence) != inf - inf_step:
		print("Synod: FAIL log synod %d hope %d influence %d" % [log.synod - syn_l, log.hope - hope_l, int(log.stock.influence) - inf])
		return false
	print("Synod: ok")
	return true


func _check_named(catalog: Catalog) -> bool:
	var game_src := FileAccess.get_file_as_string("res://sim/game.gd")
	var station_src := FileAccess.get_file_as_string("res://ui/station.gd")
	if game_src.find("named_lives") >= 0 or game_src.find("func _scrub_name") >= 0 or station_src.find("named_lives") >= 0:
		print("Named: FAIL a Named lives system shipped")
		return false
	var before := _roster(_fresh(catalog))
	for cid in ["rewrite", "blank", "talk"]:
		var game := _fresh(catalog)
		if not _play(game, "name_scrubbed", cid):
			print("Named: FAIL %s" % cid)
			return false
		if _roster(game) != before:
			print("Named: FAIL %s changed a resident" % cid)
			return false
		if game.flags.has("named_life") or game.flags.has("name_scrubbed_person"):
			print("Named: FAIL %s set a life flag" % cid)
			return false
	var talk := _fresh(catalog)
	var scale: Dictionary = catalog.balance.get("deep_life_scale", {})
	var inf := int(talk.stock.influence)
	var hope := talk.hope
	var dis := talk.discontent
	if not _play(talk, "name_scrubbed", "talk"):
		print("Named: FAIL talk apply")
		return false
	if int(talk.stock.influence) != inf - int(scale.get("influence_small", 0)) or talk.hope != hope + int(scale.get("hope_small", 0)) or talk.discontent != dis - int(scale.get("discontent_small", 0)):
		print("Named: FAIL talk deltas")
		return false
	print("Named: ok")
	return true


func _roster(game: Game) -> String:
	var bits: PackedStringArray = []
	for person in game.residents:
		bits.append("%s|%s|%s" % [str(person.get("id", "")), str(person.get("name", "")), str(person.get("name_ru", ""))])
	return "\n".join(bits)


func _check_flavor(catalog: Catalog) -> bool:
	for pair in FLAVOR_CHOICES:
		if not _flavor_one(catalog, str(pair[0]), str(pair[1])):
			return false
	print("Flavor: ok")
	return true


func _flavor_one(catalog: Catalog, event_id: String, choice_id: String) -> bool:
	var bare := Game.new()
	bare.setup(catalog, 8, 40)
	bare.week = 8
	bare.stock.food = 20
	bare.stock.influence = 10
	bare.hope = 40
	var intel_before := _intel(bare)
	var soft_before := _soft(bare)
	if not _play(bare, event_id, choice_id):
		print("Flavor: FAIL unstaffed %s %s" % [event_id, choice_id])
		return false
	if _logged(bare) or str(bare.flags.get("deep_life_listen", "")) != "":
		print("Flavor: FAIL unstaffed logged %s" % event_id)
		return false
	if _intel(bare) != intel_before or bare.flags.has("listening_probe_sid") or _blown(bare):
		print("Flavor: FAIL unstaffed intel or probe %s" % event_id)
		return false
	if not _soft_same(bare, soft_before):
		print("Flavor: FAIL unstaffed soft %s" % event_id)
		return false
	var staffed := Game.new()
	staffed.setup(catalog, 9, 40)
	staffed.week = 8
	staffed.stock.food = 20
	staffed.stock.influence = 10
	staffed.hope = 40
	if not _staff_post(staffed):
		print("Flavor: FAIL could not staff the post")
		return false
	var intel_staffed := _intel(staffed)
	var soft_staffed := _soft(staffed)
	if not _play(staffed, event_id, choice_id):
		print("Flavor: FAIL staffed %s %s" % [event_id, choice_id])
		return false
	if _logged(staffed) or str(staffed.flags.get("deep_life_listen", "")) != FLAVOR:
		print("Flavor: FAIL queued %s '%s'" % [event_id, str(staffed.flags.get("deep_life_listen", ""))])
		return false
	if _intel(staffed) != intel_staffed or staffed.flags.has("listening_probe_sid") or _blown(staffed):
		print("Flavor: FAIL staffed probe %s" % event_id)
		return false
	if not _soft_same(staffed, soft_staffed):
		print("Flavor: FAIL staffed soft %s" % event_id)
		return false
	for id in PACK:
		staffed.event_last[id] = staffed.week
		staffed.event_times[id] = 1
	staffed._dawn_after_orders()
	if not _logged(staffed) or str(staffed.flags.get("deep_life_listen", "")) != "":
		print("Flavor: FAIL dawn log %s" % event_id)
		return false
	if staffed.flags.has("listening_probe_sid") or _blown(staffed):
		print("Flavor: FAIL dawn invented a probe %s" % event_id)
		return false
	if not _soft_same(staffed, soft_staffed):
		print("Flavor: FAIL dawn moved soft flags %s" % event_id)
		return false
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
	var game := _fresh(catalog)
	var before := _soft(game)
	var stack: Array = game.dawn_soft_stack()
	if stack != SOFT_STACK:
		print("Soft: FAIL stack ", stack)
		return false
	for pair in [["rust_water", "scrape"], ["shoe_gate", "leave"], ["belt_squeal", "watch"], ["synod_sheet", "burn"], ["side_door", "refuse"], ["frost_glass", "ignore"], ["name_scrubbed", "rewrite"], ["twin_marks", "leave"], ["warm_smell", "bar"]]:
		if not _play(game, str(pair[0]), str(pair[1])):
			print("Soft: FAIL %s" % str(pair[0]))
			return false
	if not _soft_same(game, before):
		print("Soft: FAIL flags changed")
		return false
	if game.dawn_soft_stack() != SOFT_STACK:
		print("Soft: FAIL stack moved")
		return false
	var chip: Dictionary = game.dawn_soft_chip()
	var kind := str(chip.get("kind", ""))
	if kind != "" and not ["rumor", "border_new", "rail", "homecoming"].has(kind):
		print("Soft: FAIL chip ", chip)
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


func _check_cough(catalog: Catalog) -> bool:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json"))
	var file_cough := {}
	for ev in raw if raw is Array else []:
		if str(ev.get("id", "")) == "cough":
			file_cough = ev
	var live := _one(_by_id(catalog), "cough")
	if file_cough.is_empty() or live.is_empty():
		print("Cough: FAIL missing")
		return false
	if JSON.stringify(file_cough.get("choices", [])) != JSON.stringify(live.get("choices", [])):
		print("Cough: FAIL choices moved")
		return false
	if str(file_cough.get("text", "")) != str(live.get("text", "")) or int(file_cough.get("weight", -1)) != int(live.get("weight", -2)):
		print("Cough: FAIL body or weight")
		return false
	print("Cough: ok")
	return true


func _check_ui() -> bool:
	var station := FileAccess.get_file_as_string("res://ui/station.gd")
	var game := FileAccess.get_file_as_string("res://sim/game.gd")
	var bad: PackedStringArray = []
	if station.find("_open_card(game.line_of(ev, \"title\"), false, \"Event\")") < 0:
		bad.append("event card opener")
	if station.find("func _deep_life_shots") < 0:
		bad.append("shot hook")
	if game.find("const DAWN_SOFT_STACK := [\"rumor\", \"border.dawn_new\", \"rail\", \"homecoming\"]") < 0:
		bad.append("soft stack")
	if game.find("func _deep_life_dawn") >= 0 or station.find("DeepLifeChip") >= 0:
		bad.append("deep dawn chip")
	if game.find("synod_spend") >= 0 or game.find("named_lives") >= 0:
		bad.append("spend or named lives")
	if not bad.is_empty():
		print("UI: FAIL ", ", ".join(bad))
		return false
	print("UI: ok")
	return true


## Mood fallback only. A dedicated P21 plate is optional and never blocks this gate.
func _check_art(catalog: Catalog) -> void:
	var index := _by_id(catalog)
	for id in PACK:
		var ev := _one(index, id)
		if str(ev.get("banner", "")) != "":
			print("Art: %s names a plate (optional)" % id)
			continue
		var plate := ArtPack.resolve_event_banner(ev)
		if plate == "":
			print("Art: %s has no mood plate (optional, not blocking)" % id)
		else:
			print("Art: %s uses mood plate %s (optional, not blocking)" % [id, plate])
	print("Art: ok (optional plates, not blocking)")


func _careful_band() -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var report: Dictionary = Bot.new().play(40, run_seed, "careful")
		if str(report.get("over", "")) != "time":
			lost += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return lost
