class_name MarksKit
extends RefCounted

## P87 Marks & Kit. Reads, greetings, and mirrored choice lines.
## No stock, hope, opinion, or rng. Not a soft dawn chip. Not a map mark.

const PACK := "res://data/obs.json"
const SLOT_ORDER := ["coat", "lamp", "token"]
const MARK_ORDER := ["rail_stitch", "ash_hand", "word_knot", "signal_scar", "raid_tally", "open_door"]
const ARRIVAL_EVENTS := ["refugees", "refugees_next"]
const SIGNAL_STATION := "signal"
const WARM_AT := 50

static var _pack: Dictionary = {}


static func empty() -> Dictionary:
	return {
		"marks": [],
		"offered": [],
		"earned": {},
		"deeds": {"buried": 0, "guests": 0},
		"kit_owned": [],
		"kit_worn": {"coat": "", "lamp": "", "token": ""},
		"kit_lost": [],
		"card_week": 0,
		"ink_queue": [],
		"gift_queue": [],
		"noroom": [],
		"declined": [],
		"viewed": [],
		"fresh": [],
		"anim": [],
		"pip": false,
		"dawn_card": {},
		"toast": "",
		"float_mark": false,
		"float_kit": false,
		"swap_prev": {},
	}


static func joins_soft_dawn() -> bool:
	return false


static func boot(game) -> Dictionary:
	if game == null:
		return empty()
	var row = game.obs
	if not (row is Dictionary):
		game.obs = empty()
		return game.obs
	var base := empty()
	for key in base:
		if not row.has(key):
			row[key] = base[key].duplicate(true) if base[key] is Array or base[key] is Dictionary else base[key]
	if not (row.kit_worn is Dictionary):
		row.kit_worn = {"coat": "", "lamp": "", "token": ""}
	for slot in SLOT_ORDER:
		if not row.kit_worn.has(slot):
			row.kit_worn[slot] = ""
	if not (row.deeds is Dictionary):
		row.deeds = {"buried": 0, "guests": 0}
	game.obs = row
	return row


static func reset(game) -> void:
	game.obs = empty()


static func catalog() -> Dictionary:
	if _pack.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(PACK))
		_pack = data if data is Dictionary else {}
	return _pack


static func mark_ids() -> Array:
	return MARK_ORDER.duplicate()


static func kit_ids() -> Array:
	return catalog().get("kit", {}).keys()


static func kit_row(id: String) -> Dictionary:
	var row = catalog().get("kit", {}).get(id, {})
	return row if row is Dictionary else {}


static func mark_row(id: String) -> Dictionary:
	var row = catalog().get("marks", {}).get(id, {})
	return row if row is Dictionary else {}


static func slot_of(id: String) -> String:
	return str(kit_row(id).get("slot", ""))


static func inked(game, id: String) -> bool:
	return boot(game).marks.has(id)


static func wearing(game, id: String) -> bool:
	var worn: Dictionary = boot(game).kit_worn
	return str(worn.get("coat", "")) == id or str(worn.get("lamp", "")) == id or str(worn.get("token", "")) == id


static func worn_in(game, slot: String) -> String:
	return str(boot(game).kit_worn.get(slot, ""))


static func line_open(game, choice: Dictionary) -> bool:
	if not bool(choice.get("obs_line", false)):
		return true
	var kind := str(choice.get("obs_kind", ""))
	var id := str(choice.get("obs_id", ""))
	if kind == "mark":
		return inked(game, id)
	if kind == "kit":
		return wearing(game, id)
	return false


static func line_source(choice: Dictionary) -> Dictionary:
	if not bool(choice.get("obs_line", false)):
		return {}
	return {"kind": str(choice.get("obs_kind", "")), "id": str(choice.get("obs_id", ""))}


static func can_swap(game) -> bool:
	return game != null and not bool(game.get("obs_ui_block"))


static func pip_on(game) -> bool:
	return bool(boot(game).get("pip", false))


static func clear_pip(game) -> void:
	boot(game).pip = false


static func has_card(game) -> bool:
	var card = boot(game).get("dawn_card", {})
	return card is Dictionary and not card.is_empty()


static func card_waiting(game) -> bool:
	return has_card(game)


static func front_is_burial(game) -> bool:
	if game == null or game.pending.is_empty():
		return false
	return str(game.pending[0].get("burial_id", "")) != ""


## Burial paints first. The Observer card paints before every other pending event.
static func show_card_now(game) -> bool:
	return has_card(game) and not front_is_burial(game)


static func pull_toast(game) -> String:
	var row := boot(game)
	var line := str(row.get("toast", ""))
	row.toast = ""
	return line


static func take_float(game, which: String) -> bool:
	var row := boot(game)
	if which == "mark" and bool(row.get("float_mark", false)) and not bool(game.flags.get("seen_obs_marks", false)):
		row.float_mark = false
		return true
	if which == "kit" and bool(row.get("float_kit", false)) and not bool(game.flags.get("seen_obs_kit", false)):
		row.float_kit = false
		return true
	return false


static func mark_float_shown(game) -> void:
	game.flags["seen_obs_marks"] = true
	boot(game).float_mark = false


static func kit_float_shown(game) -> void:
	game.flags["seen_obs_kit"] = true
	boot(game).float_kit = false


static func note_bury(game) -> void:
	var row := boot(game)
	row.deeds.buried = int(row.deeds.get("buried", 0)) + 1
	if int(row.deeds.buried) >= 3:
		_offer_mark(game, "ash_hand", "")


static func note_charge_done(game) -> void:
	_offer_mark(game, "word_knot", "")


static func note_mandate(game) -> void:
	_offer_mark(game, "word_knot", "")


static func note_blown(game) -> void:
	_offer_mark(game, "signal_scar", "")


static func note_probe(game, sid: String, blown: bool) -> void:
	if blown:
		return
	if sid == SIGNAL_STATION:
		_offer_kit(game, "headset", "", true)


static func note_raid(game, sid: String) -> void:
	_offer_mark(game, "raid_tally", sid)


static func note_arrivals(game, ev: Dictionary, choice: Dictionary) -> void:
	var id := str(ev.get("id", ""))
	if not ARRIVAL_EVENTS.has(id):
		return
	var n := int(choice.get("people", 0))
	if n <= 0 and str(choice.get("mirror", "")) != "":
		n = int(_choice_by_id(ev, str(choice.mirror)).get("people", 0))
	if n <= 0:
		return
	var row := boot(game)
	row.deeds.guests = int(row.deeds.get("guests", 0)) + n
	if int(row.deeds.guests) >= 5:
		_offer_mark(game, "open_door", "")


static func note_sympathy(game, sid: String, before: int, after: int) -> void:
	if after < WARM_AT or before >= WARM_AT:
		return
	var id := _gift_for(sid)
	if id == "":
		return
	_offer_kit(game, id, sid, false)


static func note_capture(game, sid: String, force: bool) -> void:
	var id := _gift_for(sid)
	if id == "":
		return
	var row := boot(game)
	if force:
		if row.kit_owned.has(id):
			return
		if not row.kit_lost.has(id):
			row.kit_lost.append(id)
		_drop_gift(row, id)
		return
	_offer_kit(game, id, sid, false)


static func note_strip(game) -> void:
	_offer_kit(game, "linesman_vest", "", true)


static func note_junk(game) -> void:
	_offer_kit(game, "linesman_vest", "", true)


static func note_night(game, site: Dictionary, dead: Array) -> void:
	var sid := str(site.get("station", ""))
	if sid == SIGNAL_STATION or str(site.get("id", "")) == "signal_outer":
		_offer_kit(game, "headset", sid, true)
	if dead.is_empty():
		_offer_kit(game, "whistle", sid, true)


static func note_week(game) -> void:
	var home := str(game.capital_id)
	var best := ""
	var best_hops := 0
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(st.get("owner", "")) != str(game.player):
			continue
		if str(sid) == home:
			continue
		var hops := int(game._hops(home, str(sid)))
		if hops >= 3 and (best == "" or hops > best_hops):
			best = str(sid)
			best_hops = hops
	if best != "":
		_offer_mark(game, "rail_stitch", best)


static func prepare_dawn(game) -> void:
	var row := boot(game)
	if int(row.marks.size()) >= 3:
		_collapse_full(game, true)
	if has_card(game):
		return
	if int(row.get("card_week", 0)) == int(game.week):
		return
	if not row.ink_queue.is_empty() and int(row.marks.size()) < 3:
		row.dawn_card = {"kind": "ink", "id": str(row.ink_queue[0]), "station": ""}
		return
	if not row.gift_queue.is_empty():
		var id := str(row.gift_queue[0])
		var spec := kit_row(id)
		var kind := "find" if str(spec.get("source", "")) == "find" else "gift"
		row.dawn_card = {"kind": kind, "id": id, "station": str(spec.get("station", ""))}


static func resolve_ink(game, yes: bool) -> void:
	var row := boot(game)
	var card: Dictionary = row.get("dawn_card", {})
	if str(card.get("kind", "")) != "ink":
		return
	var id := str(card.get("id", ""))
	if yes and int(row.marks.size()) < 3 and not row.marks.has(id):
		row.marks.append(id)
		_erase(row.offered, id)
		_erase(row.ink_queue, id)
		_erase(row.declined, id)
		_erase(row.noroom, id)
		if not row.fresh.has(id):
			row.fresh.append(id)
		if not row.anim.has(id):
			row.anim.append(id)
		if int(row.marks.size()) == 1 and not bool(game.flags.get("seen_obs_marks", false)):
			row.float_mark = true
		row.pip = true
		if int(row.marks.size()) >= 3:
			_collapse_full(game, false)
	else:
		_erase(row.ink_queue, id)
		if not row.declined.has(id) and row.offered.has(id):
			row.declined.append(id)
	row.dawn_card = {}
	row.card_week = int(game.week)


static func resolve_gift(game) -> void:
	var row := boot(game)
	var card: Dictionary = row.get("dawn_card", {})
	var kind := str(card.get("kind", ""))
	if kind != "gift" and kind != "find":
		return
	var id := str(card.get("id", ""))
	if not row.kit_owned.has(id):
		row.kit_owned.append(id)
	_erase(row.gift_queue, id)
	_erase(row.kit_lost, id)
	if not row.fresh.has(id):
		row.fresh.append(id)
	if int(row.kit_owned.size()) == 1 and not bool(game.flags.get("seen_obs_kit", false)):
		row.float_kit = true
	row.pip = true
	row.dawn_card = {}
	row.card_week = int(game.week)


static func queue_ink(game, id: String) -> void:
	var row := boot(game)
	if row.marks.has(id) or row.noroom.has(id) or not row.offered.has(id):
		return
	if int(row.marks.size()) >= 3:
		return
	_erase(row.declined, id)
	if not row.ink_queue.has(id):
		row.ink_queue.append(id)


static func ink_button_key(game, id: String) -> String:
	var row := boot(game)
	var at: int = int(row.ink_queue.find(id))
	if at < 0:
		return "obs.ink.queue"
	if at == 0:
		return "obs.ink.queued"
	return "obs.ink.queued_after"


static func slots_after_ink(game) -> int:
	return maxi(0, 3 - int(boot(game).marks.size()) - 1)


static func swap(game, slot: String, id: String) -> Dictionary:
	if not can_swap(game):
		return {}
	if not SLOT_ORDER.has(slot):
		return {}
	var row := boot(game)
	if id != "" and (not row.kit_owned.has(id) or slot_of(id) != slot):
		return {}
	var prev: Dictionary = row.kit_worn.duplicate(true)
	row.swap_prev = prev
	row.kit_worn[slot] = id
	var item := id if id != "" else str(prev.get(slot, ""))
	var key := "obs.worn" if id != "" else "obs.taken_off"
	return {"toast": Copy.fill(key, {"item": _name("kit", item)}), "slot": slot, "id": id}


static func undo_swap(game) -> bool:
	if not can_swap(game):
		return false
	var row := boot(game)
	var prev = row.get("swap_prev", {})
	if not (prev is Dictionary) or prev.is_empty():
		return false
	row.kit_worn = prev.duplicate(true)
	row.swap_prev = {}
	return true


static func clear_undo(game) -> void:
	boot(game).swap_prev = {}


static func mark_viewed(game, id: String) -> void:
	var row := boot(game)
	if not row.viewed.has(id):
		row.viewed.append(id)
	_erase(row.fresh, id)


static func take_anim(game) -> Array:
	var row := boot(game)
	var ids: Array = row.anim.duplicate()
	row.anim = []
	return ids


static func state_of_mark(game, id: String) -> String:
	var row := boot(game)
	if row.marks.has(id):
		return "inked"
	if row.noroom.has(id):
		return "noroom"
	if row.offered.has(id):
		return "offered"
	return ""


static func rows(game) -> Array:
	var row := boot(game)
	var out: Array = []
	for id in row.marks:
		out.append(str(id))
	for id in row.offered:
		if not row.marks.has(id) and not row.noroom.has(id):
			out.append(str(id))
	for id in row.noroom:
		if not out.has(id):
			out.append(str(id))
	return out


static func default_selection(game) -> Dictionary:
	var row := boot(game)
	for id in rows(game):
		if row.fresh.has(id):
			return {"kind": "mark", "id": str(id)}
	if not row.offered.is_empty():
		return {"kind": "mark", "id": str(row.offered[0])}
	if not row.marks.is_empty():
		return {"kind": "mark", "id": str(row.marks[row.marks.size() - 1])}
	return {"kind": "slot", "id": "coat"}


static func earned_line(game, id: String) -> String:
	var got = boot(game).earned.get(id, {})
	if not (got is Dictionary):
		return ""
	var when := Copy.fill("obs.when", {"week": int(got.get("week", 0))})
	var what := ""
	if str(got.get("find", "")) == "1":
		what = Copy.t("obs.find.title")
	elif str(got.get("what", "")).begins_with("obs."):
		what = Copy.fill(str(got.what), {"station": _place(game, str(got.get("station", "")))})
	else:
		what = _place(game, str(got.get("station", "")))
		if what == "":
			what = Copy.t("obs.find.title")
	return Copy.fill("obs.earned_from", {"when": when, "what": what})


static func does_lines(id: String, kind: String) -> PackedStringArray:
	var spec: Dictionary = mark_row(id) if kind == "mark" else kit_row(id)
	var out := PackedStringArray()
	for effect in spec.get("effects", []):
		var key := "obs.does.%s" % str(effect)
		if not out.has(Copy.t(key)):
			out.append(Copy.t(key))
	return out


static func lost_lines(game, slot: String) -> PackedStringArray:
	var out := PackedStringArray()
	var row := boot(game)
	for id in kit_ids():
		if slot_of(str(id)) != slot:
			continue
		if not row.kit_lost.has(id) or row.kit_owned.has(id):
			continue
		var sid := str(kit_row(str(id)).get("station", ""))
		out.append(Copy.fill("obs.kit_lost", {"station": _place(game, sid)}))
	return out


static func owned_in(game, slot: String) -> Array:
	var out: Array = []
	for id in boot(game).kit_owned:
		if slot_of(str(id)) == slot:
			out.append(str(id))
	return out


static func decorate(game, ev: Dictionary) -> void:
	if not (ev is Dictionary):
		return
	var choices: Array = ev.get("choices", [])
	var kept: Array = []
	for choice in choices:
		if not bool(choice.get("obs_line", false)):
			kept.append(choice)
	ev.choices = kept
	if _banned(ev):
		return
	var pick := _best_item(game, ev)
	if pick.is_empty():
		return
	var mirror := _lowest(ev)
	if mirror.is_empty():
		return
	var line := mirror.duplicate(true)
	var kind := str(pick.kind)
	var id := str(pick.id)
	line.id = "obs_%s_%s" % [kind, id]
	line.label = Copy.pack("obs.%s.%s.opt" % [kind, id])
	line.obs_line = true
	line.obs_hidden = true
	line.obs_kind = kind
	line.obs_id = id
	line.mirror = str(mirror.get("id", ""))
	var req = line.get("requires", {})
	req = req.duplicate(true) if req is Dictionary else {}
	if kind == "mark":
		req["obs_mark"] = id
	else:
		req["obs_kit"] = id
	line.requires = req
	var at: int = int(ev.choices.size())
	for i in ev.choices.size():
		var choice: Dictionary = ev.choices[i]
		if str(choice.get("ending", "")) != "" or str(choice.get("id", "")) == "leave":
			at = i
			break
	ev.choices.insert(at, line)


static func choice_skip(choice: Dictionary) -> bool:
	return bool(choice.get("obs_line", false))


static func greet(game, sid: String) -> Dictionary:
	if game == null or not game.stations.has(sid):
		return {}
	var st: Dictionary = game.stations[sid]
	var band := PinWarmth.band_of(st)
	var wary := band == "wary" or band == "warm" or band == "ready" or band == "join"
	var piece := _worn_gift(game, sid)
	if piece != "" and wary:
		return {"kind": "kit", "id": piece, "key": "obs.greet.%s" % piece}
	if inked(game, "raid_tally") and band == "cold":
		return {"kind": "mark", "id": "raid_tally", "key": "obs.greet.tally"}
	if inked(game, "rail_stitch") and str(sid) != str(game.capital_id) and wary:
		return {"kind": "mark", "id": "rail_stitch", "key": "obs.greet.line_walker"}
	if inked(game, "open_door") and (band == "warm" or band == "ready" or band == "join"):
		return {"kind": "mark", "id": "open_door", "key": "obs.greet.open_door"}
	return {}


static func read_line(game, surface: String, sid: String) -> String:
	if game == null:
		return ""
	if surface == "listening":
		return _listen_read(game, sid)
	if surface == "visit":
		return _visit_read(game, sid)
	if surface == "salvage":
		return _salvage_read(game)
	if surface == "rumor":
		return _rumor_read(game, sid)
	if surface == "signal":
		return ""
	return ""


static func why_line(kind: String, id: String) -> String:
	return Copy.fill("obs.line_why", {"name": _name(kind, id)})


static func mirror_block(choice: Dictionary, mirror: Dictionary) -> bool:
	if not bool(choice.get("obs_line", false)):
		return false
	for key in mirror:
		if key in ["id", "label"]:
			continue
		if str(choice.get(key, null)) != str(mirror.get(key, null)) and typeof(choice.get(key, null)) != typeof(mirror.get(key, null)):
			return false
		if not _same(choice.get(key, null), mirror.get(key, null)):
			return false
	return str(choice.get("mirror", "")) == str(mirror.get("id", ""))


static func effect_same(choice: Dictionary, mirror: Dictionary) -> bool:
	var skip := ["id", "label", "obs_line", "obs_hidden", "obs_kind", "obs_id", "mirror", "requires"]
	for key in mirror:
		if skip.has(str(key)):
			continue
		if not _same(choice.get(key, null), mirror[key]):
			return false
	for key in choice:
		if skip.has(str(key)):
			continue
		if not mirror.has(key):
			return false
	var req = choice.get("requires", {})
	var src = mirror.get("requires", {})
	if not (req is Dictionary):
		return not (src is Dictionary) or src.is_empty()
	for key in req:
		if str(key) == "obs_mark" or str(key) == "obs_kit":
			continue
		if not (src is Dictionary) or not _same(req[key], src.get(key, null)):
			return false
	if src is Dictionary:
		for key in src:
			if not req.has(key):
				return false
	return true


static func _same(a, b) -> bool:
	if typeof(a) != typeof(b):
		if (typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_INT) or (typeof(a) == TYPE_INT and typeof(b) == TYPE_FLOAT):
			return is_equal_approx(float(a), float(b))
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


static func _offer_mark(game, id: String, sid: String) -> void:
	var row := boot(game)
	if row.marks.has(id) or row.offered.has(id) or row.noroom.has(id) or row.earned.has(id):
		return
	row.earned[id] = {"week": int(game.week), "what": "obs.what.%s" % id, "station": sid}
	if not row.fresh.has(id):
		row.fresh.append(id)
	row.pip = true
	if int(row.marks.size()) >= 3:
		row.noroom.append(id)
		_toast(game, "obs.mark_noroom", {"name": _name("mark", id)})
		return
	row.offered.append(id)
	if not row.ink_queue.has(id):
		row.ink_queue.append(id)
	_toast(game, "obs.mark_offered", {"name": _name("mark", id)})


static func _offer_kit(game, id: String, sid: String, find: bool) -> void:
	var row := boot(game)
	if kit_row(id).is_empty():
		return
	if row.kit_owned.has(id) or row.kit_lost.has(id) or row.gift_queue.has(id):
		return
	var station := sid if sid != "" else str(kit_row(id).get("station", ""))
	row.earned[id] = {"week": int(game.week), "what": "obs.find.title" if find else "", "station": station, "find": "1" if find else ""}
	row.gift_queue.append(id)
	if not row.fresh.has(id):
		row.fresh.append(id)
	row.pip = true


static func _collapse_full(game, toast_one: bool) -> void:
	var row := boot(game)
	var moved := ""
	var waiting: Array = []
	for id in row.offered:
		waiting.append(str(id))
	for id in row.ink_queue:
		if not waiting.has(id):
			waiting.append(str(id))
	for id in waiting:
		if row.marks.has(id):
			continue
		_erase(row.offered, id)
		_erase(row.ink_queue, id)
		_erase(row.declined, id)
		if not row.noroom.has(id):
			row.noroom.append(id)
		if moved == "":
			moved = id
	row.ink_queue = []
	if toast_one and moved != "":
		_toast(game, "obs.mark_noroom", {"name": _name("mark", moved)})


static func _toast(game, key: String, vars: Dictionary) -> void:
	var row := boot(game)
	if str(row.get("toast", "")) != "":
		return
	row.toast = Copy.fill(key, vars)


static func _drop_gift(row: Dictionary, id: String) -> void:
	_erase(row.gift_queue, id)
	var card = row.get("dawn_card", {})
	if card is Dictionary and str(card.get("id", "")) == id and str(card.get("kind", "")) != "ink":
		row.dawn_card = {}


static func _gift_for(sid: String) -> String:
	for id in catalog().get("kit", {}):
		var row: Dictionary = kit_row(str(id))
		if str(row.get("source", "")) == "station" and str(row.get("station", "")) == sid:
			return str(id)
	return ""


static func _worn_gift(game, sid: String) -> String:
	var id := _gift_for(sid)
	if id != "" and wearing(game, id):
		return id
	return ""


static func _best_item(game, ev: Dictionary) -> Dictionary:
	var id := str(ev.get("id", ""))
	var best: Dictionary = {}
	var best_rank := 99
	var row := boot(game)
	for mark in row.marks:
		var spec := mark_row(str(mark))
		if not _hosts(spec, ev, id):
			continue
		if not _has_opt("mark", str(mark)):
			continue
		var rank := int(row.marks.find(mark))
		if best.is_empty() or rank < best_rank:
			best = {"kind": "mark", "id": str(mark)}
			best_rank = rank
	if not best.is_empty():
		return best
	var slot_rank := {"coat": 0, "lamp": 1, "token": 2}
	var worn_best := 99
	for slot in SLOT_ORDER:
		var kit := str(row.kit_worn.get(slot, ""))
		if kit == "":
			continue
		var spec := kit_row(kit)
		if not _hosts(spec, ev, id):
			continue
		if not _has_opt("kit", kit):
			continue
		var rank := int(slot_rank.get(slot, 9))
		if rank < worn_best:
			worn_best = rank
			best = {"kind": "kit", "id": kit}
	return best


static func _hosts(spec: Dictionary, ev: Dictionary, id: String) -> bool:
	if spec.is_empty():
		return false
	if bool(ev.get("night_run", false)) and bool(spec.get("night_run", false)):
		return true
	if str(ev.get("burial_id", "")) != "" and bool(spec.get("burial", false)):
		return true
	for event_id in spec.get("events", []):
		if str(event_id) == id:
			return true
	return false


static func _has_opt(kind: String, id: String) -> bool:
	var key := "obs.%s.%s.opt" % [kind, id]
	return Copy.t(key) != key


static func _banned(ev: Dictionary) -> bool:
	if str(ev.get("cm", "")) != "":
		return true
	var id := str(ev.get("id", ""))
	for banned in catalog().get("banned", []):
		if str(banned) == id:
			return true
	return false


static func _lowest(ev: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := 0
	for choice in ev.get("choices", []):
		if bool(choice.get("obs_line", false)):
			continue
		if str(choice.get("ending", "")) != "":
			continue
		var cost := _cost(choice)
		if best.is_empty() or cost < best_cost:
			best = choice
			best_cost = cost
	return best


static func _cost(choice: Dictionary) -> int:
	var total := 0
	var cost = choice.get("cost", {})
	if cost is Dictionary:
		for key in cost:
			total += maxi(0, int(cost[key]))
	return total


static func _choice_by_id(ev: Dictionary, id: String) -> Dictionary:
	for choice in ev.get("choices", []):
		if str(choice.get("id", "")) == id:
			return choice
	return {}


static func _listen_read(game, sid: String) -> String:
	var scar := inked(game, "signal_scar")
	var ears := wearing(game, "headset")
	if not scar and not ears:
		return ""
	var bits: PackedStringArray = []
	if scar and game.stations.has(sid):
		var band := PinWarmth.band_of(game.stations[sid])
		bits.append(Copy.t("map.relation_band_%s" % band))
	var why := _opinion_why(game, sid)
	if why != "":
		bits.append(why)
	return " ".join(bits)


static func _visit_read(game, sid: String) -> String:
	if str(sid) == str(game.capital_id) or not wearing(game, "dispatcher_brass"):
		return ""
	return _opinion_why(game, sid)


static func _opinion_why(game, sid: String) -> String:
	if not game.stations.has(sid):
		return ""
	var fid := str(game.stations[sid].get("owner", ""))
	var mem = game.opinion_memory.get(fid, [])
	if not (mem is Array) or mem.is_empty():
		return ""
	var last: Dictionary = mem[mem.size() - 1]
	return str(last.get("why", ""))


static func _salvage_read(game) -> String:
	if not wearing(game, "linesman_vest"):
		return ""
	for row in game.salvage_board():
		if bool(row.get("fitted", false)):
			continue
		var room := str(row.get("room", ""))
		if room == "":
			continue
		var named := room
		if game.catalog != null and game.catalog.rooms.has(room):
			named = str(game.catalog.rooms[room].get("name", room))
		return Copy.t(named) if Copy.t(named) != named else named
	return ""


static func _rumor_read(game, site_id: String) -> String:
	if not wearing(game, "carbide"):
		return ""
	var rumor = game.rumor
	if not (rumor is Dictionary) or rumor.is_empty():
		return ""
	var site := {}
	if game.get("catalog") != null:
		site = NightRuns.site_by_id(site_id)
	var sid := str(site.get("station", site_id))
	if str(rumor.get("station", "")) != sid:
		return ""
	return game.rumor_toast()


static func _name(kind: String, id: String) -> String:
	var key := "obs.%s.%s.name" % [kind, id]
	var named: String = Copy.t(key)
	return named if named != key else id


static func _place(game, sid: String) -> String:
	if sid == "" or game == null or not game.stations.has(sid):
		return sid
	var named: String = str(game.station_text(sid, "community"))
	if named == "":
		named = str(game.stations[sid].get("name", sid))
	return named


static func _erase(list: Array, id: String) -> void:
	var at: int = int(list.find(id))
	if at >= 0:
		list.remove_at(at)
