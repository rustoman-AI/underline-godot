extends SceneTree

## P54 Event Chains Pack. Chains A/B/C and armband use the existing follow / chain_only / by
## card. Every step has a free choice. Deltas are the named chain_scale keys in balance.json.
## Not a soft-dawn chip, and not a second copy of the EA standalones.
##   godot --headless --path . -s res://sim/check_event_chains.gd

const CHAIN_A := ["toll", "toll_next", "toll_last"]
const CHAIN_B := ["knock", "knock_next", "knock_last"]
const CHAIN_C := ["loan", "loan_next"]
const PACK := ["toll", "toll_next", "toll_last", "knock", "knock_next", "knock_last", "loan", "loan_next", "armband"]
const EA_STANDALONE := ["stores_turn", "diesel", "ration_coat"]
const SOFT_FLAGS := ["rumor_dawn", "border_dawn_new", "heard_rail", "home_pending", "home_dawn", "dawn_soft_kind"]


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("EVENT CHAINS FAIL catalog ", catalog.error)
		quit(1)
		return
	var failed := false
	if not _check_once(catalog):
		failed = true
	if not _check_shape(catalog):
		failed = true
	if not _check_copy(catalog):
		failed = true
	if not _check_free(catalog):
		failed = true
	if not _check_scale(catalog):
		failed = true
	if not _check_banners(catalog):
		failed = true
	if not _check_pool(catalog):
		failed = true
	if not _check_follows(catalog):
		failed = true
	if not _check_soft(catalog):
		failed = true
	if failed:
		print("EVENT CHAINS FAIL")
		quit(1)
		return
	print("EVENT CHAINS OK")
	quit(0)


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


func _check_once(catalog: Catalog) -> bool:
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	for id in PACK:
		if index.get(id, []).size() != 1:
			bad.append("%s x%d" % [id, index.get(id, []).size()])
	for id in EA_STANDALONE:
		if index.get(id, []).size() != 1:
			bad.append("ea %s x%d" % [id, index.get(id, []).size()])
	if not bad.is_empty():
		print("Once: FAIL ", ", ".join(bad))
		return false
	print("Once: ok")
	return true


func _check_shape(catalog: Catalog) -> bool:
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	var toll := _one(index, "toll")
	var toll_next := _one(index, "toll_next")
	var toll_last := _one(index, "toll_last")
	var knock := _one(index, "knock")
	var knock_next := _one(index, "knock_next")
	var knock_last := _one(index, "knock_last")
	var loan := _one(index, "loan")
	var loan_next := _one(index, "loan_next")
	var armband := _one(index, "armband")
	_want(bad, str(toll.get("follow", "")) == "toll_next", "toll follow")
	_want(bad, not bool(toll.get("chain_only", false)), "toll drawn")
	_want(bad, int(toll.get("min_week", 0)) == 7, "toll week")
	_want(bad, str(toll.get("who", "")) == "Jonah", "toll who")
	_want(bad, bool(toll.get("major", false)), "toll major")
	_want(bad, int(toll.get("cooldown", 0)) >= 40, "toll once")
	_want(bad, bool(toll_next.get("chain_only", false)) and str(toll_next.get("follow", "")) == "toll_last", "toll_next")
	_want(bad, str(toll_next.get("who", "")) == "Jonah", "toll_next who")
	_want(bad, _same_keys(toll_next.get("by", {}), ["pay", "goods", "detour"]), "toll_next by")
	_want(bad, bool(toll_last.get("chain_only", false)) and str(toll_last.get("follow", "")) == "", "toll_last")
	_want(bad, _same_keys(toll_last.get("by", {}), ["sign", "route", "bar"]), "toll_last by")
	_want(bad, str(knock.get("follow", "")) == "knock_next" and str(knock.get("requires", "")) == "digging", "knock")
	_want(bad, int(knock.get("min_week", 0)) == 8 and str(knock.get("who", "")) == "Leo", "knock week")
	_want(bad, not bool(knock.get("chain_only", false)) and int(knock.get("cooldown", 0)) >= 40, "knock once")
	_want(bad, bool(knock_next.get("chain_only", false)) and str(knock_next.get("follow", "")) == "knock_last", "knock_next")
	_want(bad, str(knock_next.get("who", "")) == "Leo", "knock_next who")
	_want(bad, _same_keys(knock_next.get("by", {}), ["answer", "cut", "fill"]), "knock_next by")
	_want(bad, bool(knock_last.get("chain_only", false)) and str(knock_last.get("follow", "")) == "", "knock_last")
	_want(bad, str(knock_last.get("who", "")) == "Paul", "knock_last who")
	_want(bad, _same_keys(knock_last.get("by", {}), ["feed", "chapel", "back"]), "knock_last by")
	_want(bad, str(loan.get("follow", "")) == "loan_next" and not bool(loan.get("chain_only", false)), "loan")
	_want(bad, int(loan.get("min_week", 0)) == 5 and str(loan.get("who", "")) == "Benny", "loan week")
	_want(bad, int(loan.get("cooldown", 0)) >= 40, "loan once")
	_want(bad, bool(loan_next.get("chain_only", false)) and str(loan_next.get("follow", "")) == "", "loan_next")
	_want(bad, str(loan_next.get("who", "")) == "Benny", "loan_next who")
	_want(bad, _same_keys(loan_next.get("by", {}), ["borrow", "decline"]), "loan_next by")
	_want(bad, str(armband.get("follow", "")) == "" and not bool(armband.get("chain_only", false)), "armband")
	_want(bad, int(armband.get("min_week", 0)) == 9 and str(armband.get("who", "")) == "Owen", "armband week")
	_want(bad, int(armband.get("cooldown", 0)) >= 40, "armband once")
	for id in PACK:
		var ev := _one(index, id)
		if ev.has("trigger") or ev.has("needs"):
			bad.append("%s trigger" % id)
	if not bad.is_empty():
		print("Shape: FAIL ", ", ".join(bad))
		return false
	print("Shape: ok")
	return true


func _want(bad: PackedStringArray, ok: bool, label: String) -> void:
	if not ok:
		bad.append(label)


func _keys(by) -> Array:
	var out: Array = []
	if by is Dictionary:
		for key in by:
			out.append(str(key))
	out.sort()
	return out


func _same_keys(by, want: Array) -> bool:
	var need: Array = []
	for key in want:
		need.append(str(key))
	need.sort()
	return _keys(by) == need


func _check_copy(catalog: Catalog) -> bool:
	var index := _by_id(catalog)
	var vo := _vo_rows()
	var bad: PackedStringArray = []
	for id in PACK:
		var ev := _one(index, id)
		_ru(bad, str(ev.get("title", "")), id + " title")
		var body := str(ev.get("text", ""))
		_ru(bad, body, id + " text")
		var body_vo: Dictionary = vo.get("%s|body" % id, {})
		if not body_vo.is_empty() and str(body_vo.get("en", "")) != body:
			bad.append("%s body != vo" % id)
		elif not body_vo.is_empty() and str(body_vo.get("ru", "")) != "" and _ru_of(body) != str(body_vo.get("ru", "")):
			bad.append("%s body ru != vo" % id)
		var by = ev.get("by", {})
		if by is Dictionary:
			for key in by:
				var line := str(by[key])
				_ru(bad, line, "%s by %s" % [id, str(key)])
				var row: Dictionary = vo.get("%s|after_%s" % [id, str(key)], {})
				if row.is_empty():
					bad.append("%s missing vo after %s" % [id, str(key)])
				elif str(row.get("en", "")) != line:
					bad.append("%s by %s != vo" % [id, str(key)])
				elif str(row.get("ru", "")) != "" and _ru_of(line) != str(row.get("ru", "")):
					bad.append("%s by %s ru != vo" % [id, str(key)])
		for choice in ev.get("choices", []):
			_ru(bad, str(choice.get("label", "")), "%s %s" % [id, str(choice.get("id", ""))])
	if not bad.is_empty():
		print("Copy: FAIL ", ", ".join(bad))
		return false
	print("Copy: ok")
	return true


func _ru_of(en: String) -> String:
	Copy.set_lang("ru")
	var ru := Copy.t(en)
	Copy.set_lang("en")
	return ru


func _ru(bad: PackedStringArray, en: String, label: String) -> void:
	if en == "":
		bad.append("%s blank" % label)
		return
	var ru := _ru_of(en)
	if ru == en or ru == "":
		bad.append("%s no ru" % label)


func _vo_rows() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/vo/event_vo.json"))
	var out := {}
	if not (data is Dictionary):
		return out
	for row in data.get("lines", []):
		if str(row.get("kind", "")) != "event":
			continue
		out["%s|%s" % [str(row.get("event", "")), str(row.get("part", ""))]] = row
	return out


func _check_free(catalog: Catalog) -> bool:
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	for id in PACK:
		var free := false
		for choice in _one(index, id).get("choices", []):
			if _cost_empty(choice.get("cost", {})):
				free = true
		if not free:
			bad.append(id)
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
	var scale: Dictionary = catalog.balance.get("chain_scale", {})
	if scale.is_empty():
		print("Scale: FAIL no chain_scale")
		return false
	var index := _by_id(catalog)
	var bad: PackedStringArray = []
	for id in PACK:
		var spec: Dictionary = _scale_for(id)
		var choices := {}
		for choice in _one(index, id).get("choices", []):
			choices[str(choice.get("id", ""))] = choice
		for cid in spec:
			if not choices.has(cid):
				bad.append("%s missing %s" % [id, cid])
				continue
			_match_choice(bad, scale, id, cid, choices[cid], spec[cid])
	var advance := int(scale.get("tokens_large", 0))
	var repay := int(scale.get("tokens_repay", 0))
	if repay <= advance:
		bad.append("repay %d is not above the advance %d" % [repay, advance])
	var war := int(catalog.balance.get("opinion_war", -50))
	var large := int(scale.get("opinion_large", 0))
	if large <= 0 or large >= absi(war) / 2:
		bad.append("opinion_large %d is not a modest step under the war line %d" % [large, war])
	if not bad.is_empty():
		print("Scale: FAIL ", ", ".join(bad))
		return false
	print("Scale: ok")
	return true


func _match_choice(bad: PackedStringArray, scale: Dictionary, id: String, cid: String, choice: Dictionary, spec: Dictionary) -> void:
	for key in spec:
		if key == "cost" or key == "trait_absent" or key == "trait_hope":
			var nested = choice.get(key, {})
			var want = spec[key]
			if not (nested is Dictionary) or not (want is Dictionary):
				bad.append("%s %s %s shape" % [id, cid, key])
				continue
			for sub in want:
				var got := int(nested.get(sub, 0))
				var name := str(want[sub])
				var signed := _signed(scale, name)
				if got != signed:
					bad.append("%s %s %s.%s %d != %s (%d)" % [id, cid, key, sub, got, name, signed])
			continue
		var got_top := int(choice.get(key, 0))
		var top_name := str(spec[key])
		var top_signed := _signed(scale, top_name)
		if got_top != top_signed:
			bad.append("%s %s %s %d != %s (%d)" % [id, cid, key, got_top, top_name, top_signed])


func _signed(scale: Dictionary, name: String) -> int:
	var neg := name.begins_with("-")
	var key := name.trim_prefix("-")
	var n := int(scale.get(key, 0))
	return -n if neg else n


## effects_words → chain_scale key. A leading '-' is the drop.
func _scale_for(id: String) -> Dictionary:
	match id:
		"toll":
			return {
				"pay": {"cost": {"tokens": "tokens_medium"}, "opinion_directorate": "opinion_small"},
				"goods": {"cost": {"materials": "materials_small_medium"}, "opinion_directorate": "opinion_small", "discontent": "discontent_small"},
				"detour": {"opinion_directorate": "-opinion_medium", "influence": "-influence_small", "hope": "hope_small"},
			}
		"toll_next":
			return {
				"sign": {"cost": {"tokens": "tokens_medium_large"}, "opinion_directorate": "opinion_medium", "discontent": "discontent_small"},
				"route": {"opinion_directorate": "opinion_large", "opinion_exchange": "-opinion_medium", "hope": "-hope_small"},
				"bar": {"opinion_directorate": "-opinion_large", "hope": "hope_small", "discontent": "discontent_small"},
			}
		"toll_last":
			return {
				"settle": {"cost": {"tokens": "tokens_large"}, "opinion_directorate": "opinion_large", "hope": "-hope_medium"},
				"lin": {"cost": {"influence": "influence_medium"}, "opinion_exchange": "opinion_medium", "opinion_directorate": "-opinion_medium"},
				"guard": {"opinion_directorate": "-opinion_large", "hope": "hope_medium", "discontent": "discontent_small"},
			}
		"knock":
			return {
				"answer": {"hope": "hope_small"},
				"cut": {"cost": {"materials": "materials_small"}, "trait_absent": {"Claustrophobic": "trait_absent_short"}},
				"fill": {"hope": "-hope_small", "discontent": "discontent_small"},
			}
		"knock_next":
			return {
				"feed": {"cost": {"food": "food_small_feed"}, "papers": "papers_step", "hope": "hope_small"},
				"chapel": {"synod": "synod_small", "trait_hope": {"Devout": "trait_hope_small"}},
				"back": {"materials": "-materials_small_loss", "hope": "-hope_medium"},
			}
		"knock_last":
			return {
				"stay": {"people": "people_one", "hope": "hope_small"},
				"route": {"cost": {"materials": "materials_medium"}, "papers": "papers_step", "influence": "influence_small"},
				"gate": {"hope": "-hope_small"},
			}
		"loan":
			return {
				"borrow": {"tokens": "tokens_large", "opinion_exchange": "opinion_small"},
				"decline": {"opinion_exchange": "-opinion_small"},
			}
		"loan_next":
			return {
				"repay": {"cost": {"tokens": "tokens_repay"}, "opinion_exchange": "opinion_medium"},
				"stall": {"cost": {"materials": "materials_medium"}, "opinion_exchange": "-opinion_small"},
				"default": {"opinion_exchange": "-opinion_large", "discontent": "discontent_small"},
			}
		"armband":
			return {
				"hide": {"people": "people_one", "opinion_directorate": "-opinion_medium", "hope": "hope_small"},
				"return": {"opinion_directorate": "opinion_medium", "hope": "-hope_medium"},
				"north": {"cost": {"food": "food_small"}, "opinion_directorate": "-opinion_small"},
			}
	return {}


func _check_banners(catalog: Catalog) -> bool:
	var rows: Array = []
	var index := _by_id(catalog)
	for id in PACK:
		rows.append(_one(index, id))
	var missing := ArtPack.banner_faults(rows)
	if not missing.is_empty():
		print("Banners: FAIL ", ", ".join(missing))
		return false
	print("Banners: ok")
	return true


func _check_pool(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 3, 40)
	game.week = 10
	game.flags["dig_done_week"] = game.week
	var bad: PackedStringArray = []
	for id in ["toll_next", "toll_last", "knock_next", "knock_last", "loan_next"]:
		if game._event_ok(game._event_by_id(id)):
			bad.append("%s drawn" % id)
	for id in ["toll", "knock", "loan", "armband"]:
		if not game._event_ok(game._event_by_id(id)):
			bad.append("%s blocked" % id)
	game.week = 4
	for id in ["toll", "knock", "loan", "armband"]:
		if game._event_ok(game._event_by_id(id)):
			bad.append("%s early" % id)
	if not bad.is_empty():
		print("Pool: FAIL ", ", ".join(bad))
		return false
	print("Pool: ok")
	return true


func _check_follows(catalog: Catalog) -> bool:
	var bad: PackedStringArray = []
	_walk(bad, catalog, "toll", CHAIN_A)
	_walk(bad, catalog, "knock", CHAIN_B)
	_walk(bad, catalog, "loan", CHAIN_C)
	var arm := Game.new()
	arm.setup(catalog, 4, 40)
	if not _play(arm, "armband", "hide"):
		bad.append("armband hide")
	elif not arm.follows.is_empty():
		bad.append("armband scheduled a follow")
	if not bad.is_empty():
		print("Follow: FAIL ", ", ".join(bad))
		return false
	print("Follow: ok")
	return true


func _walk(bad: PackedStringArray, catalog: Catalog, start: String, chain: Array) -> void:
	var ev := {}
	for row in catalog.events:
		if str(row.get("id", "")) == start:
			ev = row
	for choice in ev.get("choices", []):
		var game := Game.new()
		game.setup(catalog, 5, 40)
		game.week = 12
		var cid := str(choice.get("id", ""))
		if not _play(game, start, cid):
			bad.append("%s %s" % [start, cid])
			continue
		var step := start
		for nxt in chain:
			if nxt == start:
				continue
			if game.follows.size() != 1:
				bad.append("%s %s follow count %d" % [start, cid, game.follows.size()])
				break
			var item: Dictionary = game.follows[0]
			var gap := int(item.get("due", 0)) - game.week
			if str(item.get("id", "")) != str(nxt) or str(item.get("memory", "")) != cid or gap < 2 or gap > 6:
				bad.append("%s %s -> %s gap %d memory %s" % [step, cid, str(item.get("id", "")), gap, str(item.get("memory", ""))])
				break
			game.week = int(item.due)
			game.pending.clear()
			game.week_event_ids = {}
			game._present_due_follows()
			var front: Dictionary = game.front_event()
			var shown := str(front.get("text", ""))
			var by = game._event_by_id(str(nxt)).get("by", {})
			var want := str(by.get(cid, "")) if by is Dictionary else ""
			if str(front.get("id", "")) != str(nxt) or shown != want or str(front.get("follow_memory", "")) != cid:
				bad.append("%s showed %s" % [nxt, str(front.get("id", ""))])
				break
			if str(game._event_by_id(str(nxt)).get("follow", "")) == "":
				break
			var picked := ""
			for next_choice in front.get("choices", []):
				if _cost_empty(next_choice.get("cost", {})):
					picked = str(next_choice.get("id", ""))
					break
			if picked == "" or not game.apply({"kind": "event", "event_id": str(nxt), "choice_id": picked}):
				bad.append("%s free apply" % nxt)
				break
			cid = picked
			step = str(nxt)


func _play(game: Game, event_id: String, choice_id: String) -> bool:
	var ev := game._event_by_id(event_id)
	game.pending.clear()
	game.week_event_ids = {}
	if not game._present_event(ev):
		return false
	return game.apply({"kind": "event", "event_id": event_id, "choice_id": choice_id})


func _check_soft(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 6, 40)
	game.week = 12
	var before := {}
	for key in SOFT_FLAGS:
		before[key] = game.flags.get(key, null)
	if not _play(game, "toll", "detour"):
		print("Soft: FAIL toll")
		return false
	if not _play(game, "loan", "decline"):
		print("Soft: FAIL loan")
		return false
	game.flags["dig_done_week"] = game.week
	if not _play(game, "knock", "answer"):
		print("Soft: FAIL knock")
		return false
	if not _play(game, "armband", "return"):
		print("Soft: FAIL armband")
		return false
	for key in SOFT_FLAGS:
		if game.flags.get(key, null) != before[key]:
			print("Soft: FAIL %s changed" % key)
			return false
	var chip := game.dawn_soft_chip()
	if str(chip.get("kind", "")) != "" and str(chip.get("kind", "")) != "rail" and str(chip.get("kind", "")) != "rumor" and str(chip.get("kind", "")) != "border_new":
		print("Soft: FAIL chip ", chip)
		return false
	print("Soft: ok")
	return true
