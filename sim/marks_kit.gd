class_name MarksKit
extends RefCounted

## P87 Marks & Kit. Zero balance: mirrored lines, reads, and greetings only.
## No soft-dawn chip. Kit is never called gear.
## The gate turns this off to compare a careful run with the pack quiet.
static var pack_on: bool = false


static func _static_init() -> void:
	pack_on = true

const MARK_ORDER := ["rail_stitch", "ash_hand", "word_knot", "signal_scar", "raid_tally", "open_door"]
const KIT_ORDER := ["oilskin", "barrel_quilt", "linesman_vest", "carbide", "filter_hood", "headset", "dispatcher_brass", "free_mask", "whistle"]
const SLOTS := ["coat", "lamp", "token"]
const BLOCKED_EVENTS := ["two_portions", "breathers_price", "the_list"]
const ARRIVAL_EVENTS := ["refugees", "refugees_next"]
const GUEST_NEED := 5
const BURY_NEED := 3
const WARM := 50
const WARY := 20

const MARK_EVENTS := {
	"rail_stitch": ["rumble", "rumble_next", "clog", "clog_next", "cold_rail", "count_short"],
	"ash_hand": ["hymn", "preacher", "preacher_next", "name_scrubbed", "vent_prayer"],
	"word_knot": ["loan", "loan_next", "market_food", "market_next", "smuggler", "smuggler_next"],
	"signal_scar": ["static", "static_next", "wire"],
	"raid_tally": ["toll", "toll_next", "toll_last", "knock", "knock_next", "knock_last", "armband"],
	"open_door": ["refugees", "refugees_next", "bunks", "side_door", "shoe_gate"],
}
const MARK_NIGHT := {"rail_stitch": true}
const MARK_BURIAL := {"ash_hand": true}
const MARK_EFFECTS := {
	"rail_stitch": ["line", "greet"],
	"ash_hand": ["line"],
	"word_knot": ["line"],
	"signal_scar": ["line", "read"],
	"raid_tally": ["line", "greet"],
	"open_door": ["line", "greet"],
}
const KIT_EVENTS := {
	"oilskin": ["leak", "leak_next", "wet_bunk", "rust_water"],
	"barrel_quilt": ["cold_rail", "frost_glass", "ration_coat"],
	"linesman_vest": ["tools", "scrap", "drill", "belt_squeal"],
	"carbide": ["fever_lamp", "silent_car", "lamps", "lamps_next"],
	"filter_hood": ["cough", "cough_next", "filter_mesh", "mold_cart"],
	"free_mask": ["quarrel", "quarrel_next", "desertion", "armband"],
	"whistle": ["nightshift", "overtime"],
}
const KIT_NIGHT := {"whistle": true}
const KIT_SLOT := {
	"oilskin": "coat",
	"barrel_quilt": "coat",
	"linesman_vest": "coat",
	"carbide": "lamp",
	"filter_hood": "lamp",
	"headset": "lamp",
	"dispatcher_brass": "token",
	"free_mask": "token",
	"whistle": "token",
}
const KIT_EFFECTS := {
	"oilskin": ["line", "greet"],
	"barrel_quilt": ["line", "greet"],
	"linesman_vest": ["line", "read"],
	"carbide": ["line", "read"],
	"filter_hood": ["line", "greet"],
	"headset": ["read"],
	"dispatcher_brass": ["read", "greet"],
	"free_mask": ["line", "greet"],
	"whistle": ["line"],
}
const GIFT_STATION := {
	"oilskin": "dockyard",
	"barrel_quilt": "westfield",
	"carbide": "brickworks",
	"filter_hood": "eastwater",
	"dispatcher_brass": "northgate",
	"free_mask": "central",
}
const GREET_KIT := ["oilskin", "barrel_quilt", "carbide", "filter_hood", "dispatcher_brass", "free_mask"]
const SLOT_RANK := {"coat": 0, "lamp": 1, "token": 2}
const SPOTS := ["forearm", "hand", "chest_neck"]


static func fresh() -> Dictionary:
	return {
		"marks": [],
		"offered": [],
		"earned": {},
		"deeds": {"buried": 0, "guests": 0},
		"kit_owned": [],
		"kit_worn": {"coat": "", "lamp": "", "token": ""},
		"kit_lost": [],
		"card_week": 0,
		"due_ink": [],
		"ink_at": [],
		"wait_kit": [],
		"noroom": [],
		"seen": [],
		"fresh": [],
		"new_flag": false,
		"finds": {},
		"toasts": [],
		"floats": [],
		"float_queue": [],
		"offer_toast_week": 0,
	}


static func normalize(raw) -> Dictionary:
	var base := fresh()
	if not (raw is Dictionary):
		return base
	for key in base:
		if not raw.has(key):
			continue
		var want = base[key]
		var got = raw[key]
		if typeof(want) != typeof(got):
			continue
		base[key] = got.duplicate(true) if got is Array or got is Dictionary else got
	if not (base.kit_worn is Dictionary):
		base.kit_worn = {"coat": "", "lamp": "", "token": ""}
	for slot in SLOTS:
		if not base.kit_worn.has(slot):
			base.kit_worn[slot] = ""
	if not (base.deeds is Dictionary):
		base.deeds = {"buried": 0, "guests": 0}
	if not base.deeds.has("buried"):
		base.deeds["buried"] = 0
	if not base.deeds.has("guests"):
		base.deeds["guests"] = 0
	return base


static func _live(game) -> bool:
	return pack_on and game != null


static func _bag(game) -> Dictionary:
	if not (game.obs is Dictionary) or game.obs.is_empty():
		game.obs = fresh()
	return game.obs


# --- queries ---

static func has_mark(game, id: String) -> bool:
	return _bag(game).marks.has(id)


static func wearing(game, id: String) -> bool:
	var worn: Dictionary = _bag(game).kit_worn
	for slot in SLOTS:
		if str(worn.get(slot, "")) == id:
			return true
	return false


static func owned(game, id: String) -> bool:
	return _bag(game).kit_owned.has(id)


static func is_card(ev) -> bool:
	return ev is Dictionary and str(ev.get("obs_kind", "")) != ""


static func bot_skip(choice) -> bool:
	if not (choice is Dictionary):
		return false
	return bool(choice.get("obs_hidden", false)) or str(choice.get("mirror", "")) != ""


static func line_source(choice: Dictionary) -> Dictionary:
	var src = choice.get("obs_source", {})
	if src is Dictionary:
		return {"kind": str(src.get("kind", "")), "id": str(src.get("id", ""))}
	return {"kind": "", "id": ""}


static func line_met(game, choice: Dictionary) -> bool:
	var src := line_source(choice)
	if src.kind == "mark":
		return has_mark(game, src.id)
	if src.kind == "kit":
		return wearing(game, src.id)
	var req = choice.get("requires", {})
	if req is Dictionary and req.has("obs_mark"):
		return has_mark(game, str(req.obs_mark))
	if req is Dictionary and req.has("obs_kit"):
		return wearing(game, str(req.obs_kit))
	return false


static func line_hidden(game, choice: Dictionary) -> bool:
	if not bool(choice.get("obs_hidden", false)):
		return false
	return not line_met(game, choice)


static func can_swap(game) -> bool:
	if not _live(game) or not game.obs_desk:
		return false
	if game.obs_narrative or game.obs_shelved:
		return false
	for ev in game.pending:
		if ev is Dictionary and bool(ev.get("shelved", false)):
			return false
	return true


static func holds_dawn(game) -> bool:
	for ev in game.pending:
		if is_card(ev):
			return true
	return false


static func effects_of(kind: String, id: String) -> Array:
	if kind == "mark":
		return MARK_EFFECTS.get(id, [])
	return KIT_EFFECTS.get(id, [])


static func slot_of(id: String) -> String:
	return str(KIT_SLOT.get(id, ""))


static func state_of_mark(game, id: String) -> String:
	var bag := _bag(game)
	if bag.marks.has(id):
		return "inked"
	if bag.noroom.has(id):
		return "noroom"
	if bag.offered.has(id):
		return "offered"
	return ""


static func ink_queued(game, id: String) -> bool:
	var bag := _bag(game)
	if bag.ink_at.has(id) or bag.due_ink.has(id):
		return true
	for ev in game.pending:
		if is_card(ev) and str(ev.get("obs_kind", "")) == "ink" and str(ev.get("obs_id", "")) == id:
			return true
	return false


# --- triggers (no rng, no stock) ---

static func note_bury(game) -> void:
	if not _live(game):
		return
	var bag := _bag(game)
	bag.deeds.buried = int(bag.deeds.get("buried", 0)) + 1
	if int(bag.deeds.buried) >= BURY_NEED:
		_offer_mark(game, "ash_hand", "obs.what.ash_hand", "")


static func note_word_kept(game) -> void:
	if not _live(game):
		return
	_offer_mark(game, "word_knot", "obs.what.word_knot", "")


static func note_blown(game) -> void:
	if not _live(game):
		return
	_offer_mark(game, "signal_scar", "obs.what.signal_scar", "")


static func note_raid(game, sid: String) -> void:
	if not _live(game):
		return
	_offer_mark(game, "raid_tally", "obs.what.raid_tally", sid)


static func note_arrival(game, n: int) -> void:
	if not _live(game) or n <= 0:
		return
	var bag := _bag(game)
	bag.deeds.guests = int(bag.deeds.get("guests", 0)) + n
	if int(bag.deeds.guests) >= GUEST_NEED:
		_offer_mark(game, "open_door", "obs.what.open_door", "")


static func note_week_end(game) -> void:
	if not _live(game):
		return
	var far := ""
	for sid in game.stations:
		if str(sid) == game.capital_id:
			continue
		if str(game.stations[sid].get("owner", "")) != game.player:
			continue
		if game._hops(game.capital_id, str(sid)) < 3:
			continue
		far = str(sid)
		break
	if far == "":
		return
	_offer_mark(game, "rail_stitch", "obs.what.rail_stitch", far)


static func note_sympathy(game, sid: String, before: int, after: int) -> void:
	if not _live(game):
		return
	if before >= WARM or after < WARM:
		return
	_gift_station(game, sid)


## A capture never grants Kit. Force marks the station's piece as not given for the run.
## A peaceful join is not a capture; that path can still hand the piece over.
static func note_capture(game, sid: String, force: bool) -> void:
	if not _live(game):
		return
	if force:
		_lose_station(game, sid)
	else:
		_gift_station(game, sid)


static func note_blueprint(game, source: String) -> void:
	if not _live(game):
		return
	if source != "strip" and source != "junk":
		return
	var bag := _bag(game)
	if bool(bag.finds.get("vest", false)):
		return
	bag.finds["vest"] = true
	_queue_find(game, "linesman_vest")


## Clean night-run return. deaths < 0 means the caller did not report a run.
static func note_night_return(game, deaths: int, reached: String) -> void:
	if not _live(game) or deaths < 0:
		return
	if deaths == 0:
		var bag := _bag(game)
		if not bool(bag.finds.get("whistle", false)):
			bag.finds["whistle"] = true
			_queue_find(game, "whistle")
	if reached == "signal":
		note_signal(game, "night")


static func note_signal(game, _how: String) -> void:
	if not _live(game):
		return
	var bag := _bag(game)
	if bool(bag.finds.get("headset", false)):
		return
	bag.finds["headset"] = true
	_queue_find(game, "headset")


static func note_mandate(game) -> void:
	if not _live(game):
		return
	if game._mandate_fulfilled():
		note_word_kept(game)


# --- ink, kit, dawn cards ---

static func queue_ink(game, id: String) -> bool:
	if not _live(game):
		return false
	var bag := _bag(game)
	if not bag.offered.has(id) or bag.marks.has(id) or bag.noroom.has(id):
		return false
	if bag.marks.size() >= 3:
		return false
	if not bag.ink_at.has(id):
		bag.ink_at.append(id)
	return true


static func dawn(game) -> void:
	if not _live(game):
		return
	note_mandate(game)
	_queue_card(game)


static func reseat(game) -> void:
	if not _live(game):
		return
	var deaths: Array = []
	var cards: Array = []
	var rest: Array = []
	for ev in game.pending:
		if not (ev is Dictionary):
			rest.append(ev)
		elif str(ev.get("burial_id", "")) != "":
			deaths.append(ev)
		elif is_card(ev):
			cards.append(ev)
		else:
			rest.append(ev)
	if cards.is_empty():
		return
	if cards.size() > 1:
		cards = [cards[0]]
	game.pending = deaths + cards + rest


static func resolve(game, ev: Dictionary, choice_id: String) -> void:
	var kind := str(ev.get("obs_kind", ""))
	var id := str(ev.get("obs_id", ""))
	if kind == "ink" and choice_id == "yes":
		_ink(game, id)
	elif (kind == "gift" or kind == "find") and choice_id == "take":
		_take(game, id)


static func swap(game, slot: String, kit_id: String) -> String:
	if not can_swap(game) or not SLOTS.has(slot):
		return ""
	var bag := _bag(game)
	var prev := str(bag.kit_worn.get(slot, ""))
	if kit_id == "":
		bag.kit_worn[slot] = ""
		return prev
	if not bag.kit_owned.has(kit_id) or slot_of(kit_id) != slot:
		return prev
	for other in SLOTS:
		if str(bag.kit_worn.get(other, "")) == kit_id:
			bag.kit_worn[other] = ""
	bag.kit_worn[slot] = kit_id
	return prev


static func pull_toasts(game) -> PackedStringArray:
	var out := PackedStringArray()
	var bag := _bag(game)
	for line in bag.toasts:
		out.append(str(line))
	bag.toasts = []
	return out


static func pull_float(game) -> String:
	var bag := _bag(game)
	if bag.floats.is_empty():
		return ""
	var line := str(bag.floats[0])
	bag.floats.pop_front()
	return line


# --- lines ---

static func attach(game, ev: Dictionary) -> void:
	if not _live(game) or is_card(ev) or _blocked(ev):
		return
	for choice in ev.get("choices", []):
		if choice is Dictionary and bool(choice.get("obs_hidden", false)):
			return
	var line := best_line(game, ev)
	if line.is_empty():
		return
	var choices: Array = ev.choices
	var at := choices.size()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var cid := str(choice.get("id", ""))
		if str(choice.get("ending", "")) != "" or cid == "leave" or cid == "later":
			at = i
			break
	choices.insert(at, line)


static func best_line(game, ev: Dictionary) -> Dictionary:
	if not _live(game) or is_card(ev) or _blocked(ev):
		return {}
	var cands: Array = []
	for mark in MARK_ORDER:
		if has_mark(game, mark) and _mark_on(mark, ev):
			cands.append({"kind": "mark", "id": mark, "group": 0, "rank": _bag(game).marks.find(mark)})
	for kit in KIT_ORDER:
		if wearing(game, kit) and _kit_on(kit, ev):
			cands.append({"kind": "kit", "id": kit, "group": 1, "rank": int(SLOT_RANK.get(slot_of(kit), 9))})
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a, b):
		if int(a.group) != int(b.group):
			return int(a.group) < int(b.group)
		return int(a.rank) < int(b.rank)
	)
	var pick: Dictionary = cands[0]
	var mirror := _mirror_choice(game, ev, str(pick.id))
	if mirror.is_empty():
		return {}
	return _mirrored(mirror, pick)


static func read(game, surface: String, sid: String) -> String:
	if not _live(game):
		return ""
	match surface:
		"visit":
			if not wearing(game, "dispatcher_brass"):
				return ""
			if sid == "" or sid == game.capital_id:
				return ""
			if str(game.stations.get(sid, {}).get("owner", "")) == game.player:
				return ""
			return _opinion_reason(game, sid)
		"listening":
			if has_mark(game, "signal_scar"):
				return _join_read(_band_word(game, sid), _opinion_reason(game, sid))
			if wearing(game, "headset"):
				return _opinion_reason(game, sid)
			return ""
		"rumor", "rumored_pin":
			if not wearing(game, "carbide"):
				return ""
			if game.rumor_count() != 1:
				return ""
			return game.rumor_label()
		"salvage":
			if not wearing(game, "linesman_vest"):
				return ""
			return _next_room(game)
		"signal", "signal_chain":
			## P82 Signal Chain is not on this master. No invented link.
			return ""
		_:
			return ""


static func greet(game, sid: String) -> String:
	if not _live(game) or sid == "" or sid == game.capital_id or not game.stations.has(sid):
		return ""
	var sym := int(game.stations[sid].get("sympathy", 0))
	var piece := _worn_from(game, sid)
	if piece != "" and sym >= WARY:
		return Copy.t("obs.greet.%s" % piece)
	if has_mark(game, "raid_tally") and sym >= WARY and _enemy_lean(game, sid):
		return Copy.t("obs.greet.tally")
	if has_mark(game, "rail_stitch") and sym >= WARY and str(game.stations[sid].get("owner", "")) != game.player:
		return Copy.t("obs.greet.line_walker")
	if has_mark(game, "open_door") and sym >= WARM:
		return Copy.t("obs.greet.open_door")
	return ""


static func greet_source(game, sid: String) -> Dictionary:
	if greet(game, sid) == "":
		return {"kind": "", "id": ""}
	var sym := int(game.stations[sid].get("sympathy", 0))
	var piece := _worn_from(game, sid)
	if piece != "" and sym >= WARY:
		return {"kind": "kit", "id": piece}
	if has_mark(game, "raid_tally") and sym >= WARY and _enemy_lean(game, sid):
		return {"kind": "mark", "id": "raid_tally"}
	if has_mark(game, "rail_stitch") and sym >= WARY and str(game.stations[sid].get("owner", "")) != game.player:
		return {"kind": "mark", "id": "rail_stitch"}
	if has_mark(game, "open_door") and sym >= WARM:
		return {"kind": "mark", "id": "open_door"}
	return {"kind": "", "id": ""}


static func icon(kind: String, id: String, px: int) -> Texture2D:
	var stem := "obs_%s_%s" % [kind, id]
	for name in ["%s_%d" % [stem, px], stem]:
		var path := "res://assets/icons/status/%s.png" % name
		if ResourceLoader.exists(path):
			var tex := ArtPack.load_texture(path)
			if tex != null:
				return tex
	return null


static func initial(kind: String, id: String) -> String:
	var name := Copy.t("obs.%s.%s.name" % [kind, id])
	if name == "":
		return ""
	return name.substr(0, 1)


# --- internals ---

static func _offer_mark(game, id: String, what: String, station: String) -> void:
	var bag := _bag(game)
	if bag.marks.has(id) or bag.offered.has(id):
		return
	bag.earned[id] = {"week": game.week, "what": what, "station": station}
	bag.offered.append(id)
	bag.new_flag = true
	var full: bool = bag.marks.size() >= 3
	if full:
		if not bag.noroom.has(id):
			bag.noroom.append(id)
		_one_toast(game, Copy.fill("obs.mark_noroom", {"name": Copy.t("obs.mark.%s.name" % id)}))
		return
	bag.due_ink.append(id)
	_one_toast(game, Copy.fill("obs.mark_offered", {"name": Copy.t("obs.mark.%s.name" % id)}))


static func _one_toast(game, text: String) -> void:
	var bag := _bag(game)
	if int(bag.offer_toast_week) == game.week:
		return
	bag.offer_toast_week = game.week
	bag.toasts.append(text)


static func _gift_station(game, sid: String) -> void:
	var kit_id := ""
	for id in GIFT_STATION:
		if str(GIFT_STATION[id]) == sid:
			kit_id = str(id)
			break
	if kit_id == "":
		return
	var bag := _bag(game)
	if bag.kit_owned.has(kit_id) or bag.kit_lost.has(kit_id) or _waiting(bag, kit_id):
		return
	bag.earned[kit_id] = {"week": game.week, "what": "", "station": sid}
	bag.wait_kit.append({"id": kit_id, "find": false, "station": sid, "week": game.week})
	bag.new_flag = true


static func _lose_station(game, sid: String) -> void:
	var kit_id := ""
	for id in GIFT_STATION:
		if str(GIFT_STATION[id]) == sid:
			kit_id = str(id)
			break
	if kit_id == "":
		return
	var bag := _bag(game)
	if bag.kit_owned.has(kit_id):
		return
	if not bag.kit_lost.has(kit_id):
		bag.kit_lost.append(kit_id)
	var keep: Array = []
	for row in bag.wait_kit:
		if str(row.get("id", "")) == kit_id:
			continue
		keep.append(row)
	bag.wait_kit = keep
	if not bag.earned.has(kit_id):
		bag.earned[kit_id] = {"week": game.week, "what": "", "station": sid}


static func _queue_find(game, kit_id: String) -> void:
	var bag := _bag(game)
	if bag.kit_owned.has(kit_id) or _waiting(bag, kit_id):
		return
	bag.earned[kit_id] = {"week": game.week, "what": "obs.find.title", "station": ""}
	bag.wait_kit.append({"id": kit_id, "find": true, "station": "", "week": game.week})
	bag.new_flag = true


static func _waiting(bag: Dictionary, kit_id: String) -> bool:
	for row in bag.wait_kit:
		if str(row.get("id", "")) == kit_id:
			return true
	return false


static func slots_after(inked: int) -> int:
	return maxi(0, 3 - inked - 1)


static func card_focus(kind: String) -> String:
	return "later" if kind == "ink" else "take"


static func swap_toast_key(taking_off: bool) -> String:
	return "obs.taken_off" if taking_off else "obs.worn"


static func layout_plan(view_w: float, view_h: float) -> Dictionary:
	var width := minf(640.0, maxf(320.0, view_w - 48.0))
	var cap_h := maxf(160.0, view_h - 48.0)
	var side := width >= 536.0
	var bust := 0.75 if (not side or 444.0 > cap_h) else 1.0
	return {
		"width": width,
		"side": side,
		"bust": bust,
		"pane": 360.0 if side else width,
		"scroll": true,
		"hooks_outside": true,
		"cap_h": cap_h,
	}


static func greet_once(game, sid: String, cache: Dictionary) -> String:
	if str(cache.get("sid", "")) == sid and cache.has("line"):
		return str(cache.get("line", ""))
	var line := greet(game, sid)
	cache["sid"] = sid
	cache["line"] = line
	cache["src"] = greet_source(game, sid)
	return line


static func greet_clear(cache: Dictionary) -> void:
	cache.clear()


static var _masks := {}


static func tinted(tex: Texture2D, tint: Color) -> Texture2D:
	if tex == null:
		return null
	var key := "%s:%s" % [tex.resource_path, tint.to_html(false)]
	if _masks.has(key) and _masks[key] is Texture2D:
		return _masks[key]
	var image := tex.get_image()
	if image == null:
		return tex
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var lum := (pixel.r + pixel.g + pixel.b) / 3.0
			var shape := pixel.a * clampf((0.92 - lum) / 0.92, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, shape))
	var out := ImageTexture.create_from_image(image)
	_masks[key] = out
	return out


static func _queue_card(game) -> void:
	var bag := _bag(game)
	if int(bag.card_week) == int(game.week) or holds_dawn(game):
		return
	if bag.marks.size() >= 3:
		var waiting: Array = []
		for id in bag.due_ink:
			waiting.append(id)
		for id in bag.ink_at:
			if not waiting.has(id):
				waiting.append(id)
		var first := str(waiting[0]) if not waiting.is_empty() else ""
		_seal(game)
		if first != "":
			bag.toasts.append(Copy.fill("obs.mark_noroom", {"name": Copy.t("obs.mark.%s.name" % first)}))
	var ink_id := ""
	if bag.marks.size() < 3 and not bag.due_ink.is_empty():
		ink_id = str(bag.due_ink[0])
	elif bag.marks.size() < 3 and not bag.ink_at.is_empty():
		ink_id = str(bag.ink_at[0])
	if ink_id != "":
		_place(game, _ink_card(game, ink_id))
		bag.due_ink.erase(ink_id)
		bag.ink_at.erase(ink_id)
		bag.card_week = game.week
		return
	if bag.wait_kit.is_empty():
		return
	var row: Dictionary = bag.wait_kit[0]
	bag.wait_kit.pop_front()
	_place(game, _kit_card(game, row))
	bag.card_week = game.week


static func _place(game, card: Dictionary) -> void:
	var kept: Array = []
	for ev in game.pending:
		if not is_card(ev):
			kept.append(ev)
	game.pending = kept
	var at := 0
	while at < game.pending.size() and str(game.pending[at].get("burial_id", "")) != "":
		at += 1
	game.pending.insert(at, card)


static func _ink_card(game, id: String) -> Dictionary:
	var body := "%s\n%s" % [Copy.t("obs.ink.body"), Copy.t("obs.mark.%s.flavor" % id)]
	return {
		"id": "obs_ink_%s" % id,
		"obs_kind": "ink",
		"obs_id": id,
		"title": "obs.ink.title",
		"text": body,
		"obs_slots": slots_after(_bag(game).marks.size()),
		"choices": [
			{"id": "yes", "label": "obs.ink.yes"},
			{"id": "later", "label": "obs.ink.later"},
		],
	}


static func _kit_card(game, row: Dictionary) -> Dictionary:
	var id := str(row.get("id", ""))
	var item := Copy.t("obs.kit.%s.name" % id)
	var flavor := Copy.t("obs.kit.%s.flavor" % id)
	var find := bool(row.get("find", false))
	var title := "obs.find.title" if find else Copy.fill("obs.gift.title", {"station": _station_name(game, str(row.get("station", "")))})
	var body := ""
	if find:
		body = "%s\n%s" % [Copy.fill("obs.find.body", {"item": item}), flavor]
	else:
		var station := _station_name(game, str(row.get("station", "")))
		body = "%s\n%s" % [Copy.fill("obs.gift.body", {"station": station, "item": item}), flavor]
	return {
		"id": "obs_%s_%s" % ["find" if find else "gift", id],
		"obs_kind": "find" if find else "gift",
		"obs_id": id,
		"obs_station": str(row.get("station", "")),
		"title": title,
		"text": body,
		"choices": [{"id": "take", "label": "obs.gift.take"}],
	}


static func _ink(game, id: String) -> void:
	var bag := _bag(game)
	if bag.marks.has(id) or not MARK_ORDER.has(id) or bag.marks.size() >= 3:
		return
	bag.marks.append(id)
	bag.offered.erase(id)
	bag.noroom.erase(id)
	bag.due_ink.erase(id)
	bag.ink_at.erase(id)
	if not bag.fresh.has(id):
		bag.fresh.append(id)
	bag.new_flag = true
	_queue_float(game, "mark")
	if bag.marks.size() >= 3:
		_seal(game)


static func _seal(game) -> void:
	var bag := _bag(game)
	for id in bag.offered:
		if not bag.noroom.has(id):
			bag.noroom.append(id)
	bag.due_ink = []
	bag.ink_at = []


static func _take(game, id: String) -> void:
	var bag := _bag(game)
	if bag.kit_owned.has(id) or not KIT_ORDER.has(id):
		return
	bag.kit_owned.append(id)
	bag.kit_lost.erase(id)
	bag.new_flag = true
	_queue_float(game, "kit")


static func _queue_float(game, which: String) -> void:
	var bag := _bag(game)
	var flag := "seen_obs_marks" if which == "mark" else "seen_obs_kit"
	if bool(game.flags.get(flag, false)) or bag.float_queue.has(which):
		return
	bag.float_queue.append(which)


## The yard shows this only after the dawn cards have closed.
static func take_float(game) -> String:
	var bag := _bag(game)
	if bag.float_queue.is_empty():
		return ""
	var which := str(bag.float_queue.pop_front())
	if which == "mark":
		game.flags["seen_obs_marks"] = true
		return Copy.t("obs.first_mark")
	game.flags["seen_obs_kit"] = true
	return Copy.t("obs.first_kit")


static func _blocked(ev: Dictionary) -> bool:
	var id := str(ev.get("id", ""))
	if BLOCKED_EVENTS.has(id):
		return true
	if id.begins_with("creed") or id.find("mandate") >= 0:
		return true
	if bool(ev.get("creed", false)) or bool(ev.get("mandate", false)):
		return true
	for choice in ev.get("choices", []):
		if choice is Dictionary and str(choice.get("ending", "")) != "":
			return true
	return false


static func _mark_on(mark: String, ev: Dictionary) -> bool:
	var id := str(ev.get("id", ""))
	if MARK_EVENTS.get(mark, []).has(id):
		return true
	if bool(MARK_NIGHT.get(mark, false)) and (id == "night_run" or id.begins_with("night_run")):
		return true
	if bool(MARK_BURIAL.get(mark, false)) and str(ev.get("burial_id", "")) != "":
		return true
	return false


static func _kit_on(kit: String, ev: Dictionary) -> bool:
	var id := str(ev.get("id", ""))
	if KIT_EVENTS.get(kit, []).has(id):
		return true
	if bool(KIT_NIGHT.get(kit, false)) and (id == "night_run" or id.begins_with("night_run")):
		return true
	return false


static func _mirror_choice(game, ev: Dictionary, mark_or_kit: String) -> Dictionary:
	var choices: Array = ev.get("choices", [])
	if str(ev.get("burial_id", "")) != "" and mark_or_kit == "ash_hand":
		for choice in choices:
			if str(choice.get("id", "")) == "bury":
				return choice
		return {}
	var catalogued := _catalog_choices(game, str(ev.get("id", "")))
	var pool: Array = catalogued if not catalogued.is_empty() else choices
	return _lowest(pool)


static func _catalog_choices(game, id: String) -> Array:
	if game.catalog == null:
		return []
	for ev in game.catalog.events:
		if str(ev.get("id", "")) == id:
			return ev.get("choices", [])
	return []


static func _lowest(choices: Array) -> Dictionary:
	var best := {}
	var best_cost := 0
	var found := false
	for choice in choices:
		if not (choice is Dictionary):
			continue
		if str(choice.get("ending", "")) != "" or bool(choice.get("obs_hidden", false)):
			continue
		var cost := 0
		var raw = choice.get("cost", {})
		if raw is Dictionary:
			for key in raw:
				cost += absi(int(raw[key]))
		if not found or cost < best_cost:
			found = true
			best_cost = cost
			best = choice
	return best


static func _mirrored(src: Dictionary, pick: Dictionary) -> Dictionary:
	var out := src.duplicate(true)
	for key in ["id", "label", "ru_own", "text"]:
		out.erase(key)
	var kind := str(pick.kind)
	var id := str(pick.id)
	out["id"] = "obs_%s" % id
	out["label"] = "obs.%s.%s.opt" % [kind, id]
	out["mirror"] = str(src.get("id", ""))
	out["obs_hidden"] = true
	out["obs_source"] = {"kind": kind, "id": id}
	if kind == "mark":
		out["requires"] = {"obs_mark": id}
	else:
		out["requires"] = {"obs_kit": id}
	return out


static func _station_name(game, sid: String) -> String:
	if sid == "" or not game.stations.has(sid):
		return sid
	return Copy.t(str(game.stations[sid].get("name", sid)))


static func _enemy_lean(game, sid: String) -> bool:
	var row = game.catalog.communities.get("stations", {}).get(sid, {})
	if row is Dictionary and str(row.get("lean", "")) == "enemy":
		return true
	return str(game.stations[sid].get("lean", "")) == "enemy"


static func _worn_from(game, sid: String) -> String:
	for kit in GREET_KIT:
		if str(GIFT_STATION.get(kit, "")) != sid:
			continue
		if wearing(game, kit):
			return kit
	return ""


static func _band_word(game, sid: String) -> String:
	if sid == "" or not game.stations.has(sid):
		return ""
	var sym := int(game.stations[sid].get("sympathy", 0))
	var key := "map.relation_band_cold"
	if sym >= 100:
		key = "map.relation_band_join"
	elif sym >= 70:
		key = "map.relation_band_ready"
	elif sym >= WARM:
		key = "map.relation_band_warm"
	elif sym >= WARY:
		key = "map.relation_band_wary"
	return Copy.t(key)


static func _opinion_reason(game, sid: String) -> String:
	var owner := ""
	if game.stations.has(sid):
		owner = str(game.stations[sid].get("owner", ""))
	if owner == "" or not game.opinion_memory.has(owner):
		return ""
	var rows: Array = game.opinion_memory[owner]
	if rows.is_empty():
		return ""
	var last: Dictionary = rows[rows.size() - 1]
	return str(last.get("why", ""))


static func _join_read(band: String, why: String) -> String:
	if band == "" and why == "":
		return ""
	if why == "":
		return band
	if band == "":
		return why
	return "%s · %s" % [band, why]


static func _next_room(game) -> String:
	for row in game.salvage_board():
		if bool(row.get("fitted", false)):
			continue
		var type := str(row.get("room", ""))
		if game.catalog != null and game.catalog.rooms.has(type):
			return Copy.t(str(game.catalog.rooms[type].get("name", type)))
		var key := str(row.get("name_key", ""))
		if key != "":
			return Copy.t(key)
	return ""
