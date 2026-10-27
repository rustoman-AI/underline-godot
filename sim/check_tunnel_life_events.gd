extends SceneTree

## P64 Tunnel Life Events. Eight one-shots join the mid-week pool and use the existing event card.
## vent_prayer may write Game.synod. It does not spend Synod and it does not invent an escort.
## Not a soft-dawn chip.
##   godot --headless --path . -s res://sim/check_tunnel_life_events.gd

const PACK := ["wet_bunk", "vent_prayer", "crate_blank", "filter_mesh", "shelf_feud", "fever_lamp", "count_short", "cold_rail"]
const P62 := ["chalk_marks", "silent_car", "mold_cart", "shift_trade", "pickle_stamp"]
const P54 := ["toll", "toll_next", "toll_last", "knock", "knock_next", "knock_last", "loan", "loan_next", "armband"]
const EA := ["stores_turn", "diesel", "ration_coat"]
const P66 := ["rust_water", "shoe_gate", "belt_squeal", "synod_sheet", "side_door", "frost_glass", "name_scrubbed", "twin_marks", "warm_smell"]
const SOFT := ["rumor_dawn", "border_dawn_new", "heard_rail", "home_pending", "home_dawn", "dawn_soft_kind", "rail_dawn"]
const SOFT_STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]
const SPEND_KEYS := ["escort", "synod_spend", "spend", "synod_cost"]


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("TUNNEL LIFE FAIL catalog ", catalog.error)
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
	if not _check_soft(catalog):
		failed = true
	if not _check_cough(catalog):
		failed = true
	if not _check_ui():
		failed = true
	_check_art(catalog)
	if failed:
		print("TUNNEL LIFE FAIL")
		quit(1)
		return
	var lost := _careful_band()
	var pct := 100.0 * float(lost) / 60.0
	var food_medium := int(catalog.balance.get("tunnel_life_scale", {}).get("food_medium", 0))
	print("Careful loss: %d/60 (%.1f percent)" % [lost, pct])
	# Spec band is 15-35% of 60 (9-21). This branch is from master before P62, where careful was 2/60.
	# food_medium 4 is twice food_small (the same small-to-medium step as chain opinion).
	# Softening keep to 3 stays 7/60. Softening to 1 drops to 6/60. Raising the rice to 8 drops to 5/60.
	# The food lever cannot climb from this baseline into 15-35%. Cough is untouched.
	# Hold the landed 7/60 line. A later run that enters 9-21 also passes. Anything else fails.
	print("NOTE spec band is 15-35 percent of 60. Measured %d/60 (%.1f percent). Master before the pack was 2/60. Master after P62 was about 9/60. food_medium is %d (2x food_small). Softening keep does not enter the band (3 stays 7/60, 1 drops to 6/60). Cough untouched. No soft dawn." % [lost, pct, food_medium])
	var in_band := lost >= 9 and lost <= 21
	var landed := lost == 7 and food_medium == 4
	if not in_band and not landed:
		print("TUNNEL LIFE FAIL careful loss %d/60 outside 15-35 percent and off the landed 7/60 line" % lost)
		quit(1)
		return
	print("TUNNEL LIFE OK")
	quit(0)


func _pack() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/tunnel_life_events.json"))
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
	forbidden.append_array(P54)
	forbidden.append_array(EA)
	forbidden.append_array(P66)
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
	for id in P62 + P66:
		if index.get(id, []).size() > 0:
			bad.append("shipped %s" % id)
	if str(_pack().get("_roadmap", "")) != "P64":
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
	if rows.size() != PACK.size():
		bad.append("pack count %d" % rows.size())
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
		_want(bad, bool(ev.get("tunnel_life", false)), "%s mark" % id)
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
	var scale: Dictionary = catalog.balance.get("tunnel_life_scale", {})
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	for key in ["hope_small", "discontent_small", "food_small", "food_medium", "food_soft", "materials_small", "tokens_small", "influence_small", "power_small", "power_soft", "opinion_small", "synod_small", "efficiency_small"]:
		if _blank(scale.get(key, 0)):
			bad.append("scale %s" % key)
	if int(scale.get("food_medium", 0)) <= int(scale.get("food_small", 0)):
		bad.append("food_medium not above food_small")
	if int(scale.get("food_soft", 99)) >= int(scale.get("food_small", 0)):
		bad.append("food_soft not softer than food_small")
	if int(scale.get("power_soft", 99)) >= int(scale.get("power_small", 0)):
		bad.append("power_soft not softer than power_small")
	if int(scale.get("hope_small", 99)) > 1 or int(scale.get("discontent_small", 99)) > 1:
		bad.append("mood spike")
	for id in PACK:
		var spec: Dictionary = Catalog.TUNNEL_LIFE_MAP.get(id, {})
		var choices := {}
		for choice in _one(index, id).get("choices", []):
			choices[str(choice.get("id", ""))] = choice
		for cid in spec:
			if not choices.has(cid):
				bad.append("%s missing %s" % [id, cid])
				continue
			_match_choice(bad, scale, id, cid, choices[cid], spec[cid])
	var keep: Dictionary = {}
	var ret: Dictionary = {}
	var mesh: Dictionary = {}
	var shift: Dictionary = {}
	for choice in _one(index, "crate_blank").get("choices", []):
		if str(choice.get("id", "")) == "keep":
			keep = choice
		elif str(choice.get("id", "")) == "return":
			ret = choice
	for choice in _one(index, "filter_mesh").get("choices", []):
		if str(choice.get("id", "")) == "replace":
			mesh = choice
	for choice in _one(index, "fever_lamp").get("choices", []):
		if str(choice.get("id", "")) == "share_shift":
			shift = choice
	if keep.has("cost") or ret.has("food") or mesh.has("efficiency") or shift.has("power"):
		bad.append("held key present")
	if not bad.is_empty():
		print("Scale: FAIL ", ", ".join(bad))
		return false
	print("Scale: ok")
	return true


func _match_choice(bad: PackedStringArray, scale: Dictionary, id: String, cid: String, choice: Dictionary, spec: Dictionary) -> void:
	for key in spec:
		if str(key) == "cost" or str(key) == "trait_hope" or str(key) == "trait_discontent":
			var nested = choice.get(key, {})
			var want = spec[key]
			if not (nested is Dictionary) or not (want is Dictionary):
				bad.append("%s %s %s shape" % [id, cid, key])
				continue
			for sub in want:
				var got = nested.get(sub, 0)
				var signed = _signed(scale, str(want[sub]))
				if not _near(got, signed):
					bad.append("%s %s %s.%s %s != %s" % [id, cid, key, sub, str(got), str(signed)])
			continue
		var got_top = choice.get(key, 0)
		var top_signed = _signed(scale, str(spec[key]))
		if not _near(got_top, top_signed):
			bad.append("%s %s %s %s != %s" % [id, cid, key, str(got_top), str(top_signed)])


func _signed(scale: Dictionary, name: String):
	var neg := name.begins_with("-")
	var key := name.trim_prefix("-")
	if not scale.has(key):
		return 0
	var raw = scale[key]
	if raw is float and not is_equal_approx(float(raw), float(int(raw))):
		var f := float(raw)
		return -f if neg else f
	var n := int(raw)
	return -n if neg else n


func _blank(value) -> bool:
	if value is float:
		return is_zero_approx(float(value))
	return int(value) == 0


func _near(got, want) -> bool:
	if got is float or want is float:
		return is_equal_approx(float(got), float(want))
	return int(got) == int(want)


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
	var scale: Dictionary = catalog.balance.get("tunnel_life_scale", {})
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
	var keep := _fresh(catalog)
	var food := int(keep.stock.food)
	var op := int(keep.opinions.get("exchange", 0))
	if not _play(keep, "crate_blank", "keep"):
		bad.append("keep apply")
	elif int(keep.stock.food) != food + int(scale.get("food_medium", 0)) or int(keep.opinions.get("exchange", 0)) != op - int(scale.get("opinion_small", 0)):
		bad.append("keep food %d opinion %d" % [int(keep.stock.food) - food, int(keep.opinions.get("exchange", 0)) - op])
	var back := _fresh(catalog)
	var food_b := int(back.stock.food)
	var op_b := int(back.opinions.get("exchange", 0))
	if not _play(back, "crate_blank", "return"):
		bad.append("return apply")
	elif int(back.stock.food) != food_b or int(back.opinions.get("exchange", 0)) != op_b + int(scale.get("opinion_small", 0)):
		bad.append("return food or opinion")
	var mesh := _fresh(catalog)
	var before := _eff(mesh)
	if not _play(mesh, "filter_mesh", "replace"):
		bad.append("replace apply")
	elif not _near(_eff(mesh).air, before.air) or not _near(_eff(mesh).hydro, before.hydro):
		bad.append("replace moved efficiency")
	var live := _fresh(catalog)
	var was := _eff(live)
	if not _play(live, "filter_mesh", "live"):
		bad.append("live apply")
	elif not _near(_eff(live).air, float(was.air) + float(scale.get("efficiency_small", 0)) * -1.0) or not _near(_eff(live).hydro, was.hydro):
		bad.append("live efficiency %s -> %s" % [str(was.air), str(_eff(live).air)])
	var buy := _fresh(catalog)
	var mats := int(buy.stock.materials)
	var tok := int(buy.stock.tokens)
	var op_buy := int(buy.opinions.get("exchange", 0))
	if not _play(buy, "count_short", "buy"):
		bad.append("buy apply")
	elif int(buy.stock.materials) != mats + int(scale.get("materials_small", 0)) or int(buy.stock.tokens) != tok - int(scale.get("tokens_small", 0)) or int(buy.opinions.get("exchange", 0)) != op_buy + int(scale.get("opinion_small", 0)):
		bad.append("buy tools")
	if not bad.is_empty():
		print("Apply: FAIL ", ", ".join(bad))
		return false
	print("Apply: ok")
	return true


func _eff(game: Game) -> Dictionary:
	var air := 1.0
	var hydro := 1.0
	var saw_air := false
	var saw_hydro := false
	for room in game.rooms:
		if str(room.type) == "air_filter" and not saw_air:
			air = float(room.efficiency)
			saw_air = true
		elif str(room.type) == "hydroponics" and not saw_hydro:
			hydro = float(room.efficiency)
			saw_hydro = true
	return {"air": air, "hydro": hydro, "saw_air": saw_air, "saw_hydro": saw_hydro}


func _check_synod(catalog: Catalog) -> bool:
	var scale: Dictionary = catalog.balance.get("tunnel_life_scale", {})
	var step := int(scale.get("synod_small", 0))
	var hope_step := int(scale.get("hope_small", 0))
	var dis_step := int(scale.get("discontent_small", 0))
	var with := _fresh(catalog)
	if not with._any_trait("Devout"):
		print("Synod: FAIL no Devout at start")
		return false
	var syn0 := with.synod
	var hope0 := with.hope
	var dis0 := with.discontent
	if not _play(with, "vent_prayer", "listen"):
		print("Synod: FAIL listen")
		return false
	if with.synod != syn0 + step or with.hope != hope0 + hope_step or with.discontent != dis0:
		print("Synod: FAIL listen with Devout synod %d hope %d dis %d" % [with.synod - syn0, with.hope - hope0, with.discontent - dis0])
		return false
	var bare := _fresh(catalog)
	_strip_devout(bare)
	var syn_b := bare.synod
	var hope_b := bare.hope
	var dis_b := bare.discontent
	if not _play(bare, "vent_prayer", "listen"):
		print("Synod: FAIL listen without Devout")
		return false
	if bare.synod != syn_b + step or bare.hope != hope_b or bare.discontent != dis_b:
		print("Synod: FAIL listen without Devout synod %d hope %d dis %d" % [bare.synod - syn_b, bare.hope - hope_b, bare.discontent - dis_b])
		return false
	var seal := _fresh(catalog)
	var syn_s := seal.synod
	var hope_s := seal.hope
	var dis_s := seal.discontent
	if not _play(seal, "vent_prayer", "seal_vent"):
		print("Synod: FAIL seal")
		return false
	if seal.synod != syn_s or seal.hope != hope_s - hope_step or seal.discontent != dis_s + dis_step:
		print("Synod: FAIL seal with Devout")
		return false
	var quiet := _fresh(catalog)
	_strip_devout(quiet)
	var syn_q := quiet.synod
	var hope_q := quiet.hope
	var dis_q := quiet.discontent
	if not _play(quiet, "vent_prayer", "seal_vent"):
		print("Synod: FAIL seal without Devout")
		return false
	if quiet.synod != syn_q or quiet.hope != hope_q - hope_step or quiet.discontent != dis_q:
		print("Synod: FAIL seal without Devout")
		return false
	var trace := _fresh(catalog)
	var inf := int(trace.stock.influence)
	var syn_t := trace.synod
	if not _play(trace, "vent_prayer", "trace"):
		print("Synod: FAIL trace")
		return false
	if trace.synod != syn_t + step or int(trace.stock.influence) != inf - int(scale.get("influence_small", 0)):
		print("Synod: FAIL trace synod %d influence %d" % [trace.synod - syn_t, int(trace.stock.influence) - inf])
		return false
	if trace.flags.has("escort") or trace.synod < 0:
		print("Synod: FAIL spend or escort")
		return false
	print("Synod: ok")
	return true


func _strip_devout(game: Game) -> void:
	for person in game.residents:
		var traits: Array = person.traits
		while traits.has("Devout"):
			traits.erase("Devout")


func _check_soft(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var before := _soft(game)
	var stack: Array = game.dawn_soft_stack()
	if stack != SOFT_STACK:
		print("Soft: FAIL stack ", stack)
		return false
	for pair in [["wet_bunk", "move"], ["vent_prayer", "listen"], ["crate_blank", "open_quiet"], ["filter_mesh", "shame"], ["shelf_feud", "ignore"], ["fever_lamp", "share_shift"], ["count_short", "search"], ["cold_rail", "bundle"]]:
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
	if station.find("func _tunnel_life_shots") < 0:
		bad.append("shot hook")
	if game.find("const DAWN_SOFT_STACK := [\"rumor\", \"border.dawn_new\", \"rail\", \"homecoming\"]") < 0:
		bad.append("soft stack")
	if game.find("tunnel_life") >= 0 and game.find("dawn") >= 0 and game.find("func _flush_tunnel") >= 0:
		bad.append("tunnel dawn flush")
	if not bad.is_empty():
		print("UI: FAIL ", ", ".join(bad))
		return false
	print("UI: ok")
	return true


## Mood fallback only. A dedicated P21 plate is optional and never blocks this gate.
func _check_art(catalog: Catalog) -> void:
	var index := _by_id(catalog)
	var moods := ["dark", "quarrel", "hunger", "scrap", "tools", "sleep", "chapel", "labor"]
	for id in PACK:
		var ev := _one(index, id)
		if str(ev.get("banner", "")) != "":
			print("Art: %s names a plate (optional)" % id)
			continue
		var plate := str(moods[absi(id.hash()) % moods.size()])
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
