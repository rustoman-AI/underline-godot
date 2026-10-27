class_name NightRuns
extends RefCounted

## P74 Night Runs. Dawn resolve is an event card. It does not join the soft-dawn stack.
## Backpack is 6 units per runner. Medkits cost 3. Roll is 2d6 + best Senses or Grit vs 7/9/10.

const PACK_UNITS := 6
const MEDKIT_UNITS := 3
const ENCOUNTER_P := 0.35
const SEEN_P := 0.30
const DEPLETE_WEEKS := 6
const THRESHOLD := {1: 7, 2: 9, 3: 10}
const PRIORITIES := ["food", "materials", "medkits", "intel"]
## SPEC lever: danger-3 miss of 3+ becomes capture-only when careful deaths would pass 35%.
const CAPTURE_ONLY := false
const ART := {
	"ruins": "res://assets/events/site_ruins.webp",
	"dead_platform": "res://assets/events/site_dead_platform.webp",
	"bunker_outer": "res://assets/events/site_bunker_outer.webp",
	"neighbor": "res://assets/events/site_neighbor_steal.webp",
}

static var _sites: Array = []
static var _encounters: Array = []


static func sites() -> Array:
	if _sites.is_empty():
		var data = _read_json("res://data/sites.json")
		if data is Dictionary:
			_sites = data.get("sites", [])
	return _sites


static func encounter_ids() -> Array:
	if _encounters.is_empty():
		var data = _read_json("res://data/night_runs.json")
		if data is Dictionary:
			for row in data.get("encounters", []):
				if row is Dictionary:
					_encounters.append(str(row.get("id", "")))
	return _encounters


static func site_by_id(id: String) -> Dictionary:
	for row in sites():
		if str(row.get("id", "")) == id:
			return row
	return {}


static func boot(game) -> Dictionary:
	var have = game.flags.get("night_runs", null)
	if have is Dictionary and not (have as Dictionary).is_empty() and (have as Dictionary).has("intel"):
		return have
	var intel := {}
	for row in sites():
		intel[str(row.get("id", ""))] = int(row.get("intel", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(game.seed) * 74 + 11
	var st := {
		"intel": intel,
		"recover": {},
		"active": {},
		"rng": rng.state,
		"deaths": 0,
		"runs": 0,
		"hurt": 0,
		"captures": 0,
	}
	game.flags["night_runs"] = st
	return st


static func intel_of(game, id: String) -> int:
	var st := boot(game)
	return clampi(int(st.intel.get(id, 0)), 0, 3)


static func known_sites(game) -> Array:
	var out: Array = []
	for row in sites():
		if intel_of(game, str(row.get("id", ""))) >= 2:
			out.append(row)
	return out


static func rumored_sites(game) -> Array:
	var out: Array = []
	for row in sites():
		if intel_of(game, str(row.get("id", ""))) == 1:
			out.append(row)
	return out


static func runner_cap(game) -> int:
	for room in game.rooms:
		if int(room.get("level", 0)) >= 2 and str(room.get("type", "")) != "":
			return 3
	return 2


static func danger_of(game, site: Dictionary) -> int:
	var danger := int(site.get("danger", 1))
	if bool(site.get("clean_line", false)) and int(game.week) >= 20:
		danger += 1
	return clampi(danger, 1, 3)


static func depleted(game, id: String) -> bool:
	var st := boot(game)
	return int(st.recover.get(id, 0)) > int(game.week)


static func on_run(game, person_id: String) -> bool:
	if not game.people.has(person_id):
		return false
	if bool(game.people[person_id].get("on_run", false)):
		return true
	var active: Dictionary = boot(game).get("active", {})
	return active.get("runners", []).has(person_id)


static func party_blocked(game, person_id: String) -> bool:
	if not game.squads.has(game.player):
		return false
	var roster: Array = game.squads[game.player].get("roster", [])
	return roster.has(person_id)


static func block_reason(game, person_id: String) -> String:
	if not game.people.has(person_id):
		return "away"
	var person: Dictionary = game.people[person_id]
	if game._is_child(person):
		return "child"
	if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0 or bool(person.get("on_run", false)):
		return "away"
	if str(game.governor_of(person_id)) != "":
		return "away"
	if game._locked_ids().has(person_id):
		return "locked"
	if party_blocked(game, person_id):
		return "party"
	return ""


static func site_label(game, site: Dictionary) -> String:
	var sid := str(site.get("station", ""))
	var name := ""
	if game.has_method("station_text"):
		name = game.station_text(sid, "community")
	if name == "" and game.stations.has(sid):
		name = str(game.stations[sid].get("name", sid))
	if name == "":
		name = sid
	return "%s · %s" % [name, Copy.fill("run.danger", {"n": danger_of(game, site)})]


static func send(game, site_id: String, runners: Array, priority: Array) -> String:
	var st := boot(game)
	if not (st.get("active", {}) as Dictionary).is_empty():
		return Copy.t("run.back")
	var site := site_by_id(site_id)
	if site.is_empty() or intel_of(game, site_id) < 2:
		return Copy.t("run.no_site")
	var order := _order(priority)
	if order.is_empty():
		return Copy.t("run.priority_food")
	var cap := runner_cap(game)
	if runners.is_empty() or runners.size() > cap:
		return Copy.fill("run.pick_runners", {"n": cap})
	var seen := {}
	for id in runners:
		var pid := str(id)
		if seen.has(pid):
			return Copy.fill("run.pick_runners", {"n": cap})
		seen[pid] = true
		var why := block_reason(game, pid)
		if why == "party":
			return Copy.t("run.party_block")
		if why != "":
			return Copy.fill("run.pick_runners", {"n": cap})
	for id in runners:
		var pid := str(id)
		game._unassign(pid)
		game.people[pid].absent = maxi(int(game.people[pid].get("absent", 0)), 1)
		game.people[pid]["on_run"] = true
		game._note_night_run(pid)
	st.active = {
		"site": site_id,
		"runners": runners.duplicate(),
		"priority": order,
		"week": int(game.week),
	}
	st.runs = int(st.get("runs", 0)) + 1
	game._log("NIGHT send %s x%d" % [site_id, runners.size()], true)
	return ""


## Dawn of the week after a send. Pushes one event-card. Does not touch soft dawn.
static func dawn(game) -> void:
	var st := boot(game)
	var active: Dictionary = st.get("active", {})
	if active.is_empty():
		return
	var site := site_by_id(str(active.get("site", "")))
	var runners: Array = active.get("runners", [])
	var order: Array = _order(active.get("priority", []))
	st.active = {}
	if site.is_empty() or runners.is_empty():
		_clear_out(game, runners)
		return
	var rng := _rng(game)
	var danger := danger_of(game, site)
	var bonus := best_bonus(game, runners)
	var total := int(st.get("force_total", -1))
	if total < 0:
		total = rng.randi_range(1, 6) + rng.randi_range(1, 6) + bonus
	st.erase("force_total")
	var gap := int(THRESHOLD.get(danger, 10)) - total
	var band := "hit"
	if gap > 0 and gap <= 2:
		band = "soft"
	elif gap >= 3:
		band = "hard"
	var thin := depleted(game, str(site.id))
	var yields: Dictionary = site.get("yield", {}).duplicate()
	if thin:
		for key in yields.keys():
			yields[key] = int(floor(float(yields[key]) * 0.8))
	var slots := PACK_UNITS * runners.size()
	var pack := fill_pack(yields, order, slots)
	if band == "soft":
		pack = half_pack(pack)
	elif band == "hard":
		pack = {"food": 0, "materials": 0, "medkits": 0, "intel": 0}
	var hurt: Array = []
	var dead: Array = []
	var taken: Array = []
	var alive: Array = []
	var named := {}
	for id in runners:
		var pid := str(id)
		if game.people.has(pid):
			alive.append(pid)
			named[pid] = _identity(game, pid)
	if band == "soft" and not alive.is_empty():
		var victim := _weakest(game, alive)
		_injure(game, victim)
		hurt.append(victim)
		st.hurt = int(st.get("hurt", 0)) + 1
	elif band == "hard" and danger >= 3 and not alive.is_empty():
		var victim := _weakest(game, alive)
		var capture := CAPTURE_ONLY or rng.randf() < 0.5
		if capture:
			_capture(game, victim, site)
			taken.append(victim)
			st.captures = int(st.get("captures", 0)) + 1
		else:
			_kill(game, victim, site)
			dead.append(victim)
			st.deaths = int(st.get("deaths", 0)) + 1
		alive.erase(victim)
	elif band == "hard" and not alive.is_empty():
		var victim := _weakest(game, alive)
		_injure(game, victim)
		hurt.append(victim)
		st.hurt = int(st.get("hurt", 0)) + 1
	var rested: Array = []
	for pid in alive:
		if not game.people.has(pid):
			continue
		game.people[pid].absent = maxi(int(game.people[pid].get("absent", 0)), 1)
		game.people[pid]["on_run"] = false
		rested.append(pid)
		var person: Dictionary = game.people[pid]
		game.notices.append(Copy.fill("run.rest", {"name": _name(game, pid), "fem": game.sex_of(person) == "f"}))
	var encounter := ""
	if not alive.is_empty():
		var forced := str(st.get("force_encounter", ""))
		st.erase("force_encounter")
		if forced == "none":
			encounter = ""
		elif forced != "":
			encounter = forced
		elif rng.randf() < ENCOUNTER_P:
			var ids := encounter_ids()
			if not ids.is_empty():
				encounter = str(ids[rng.randi() % ids.size()])
	else:
		st.erase("force_encounter")
	var seen := false
	var owner := ""
	if str(site.get("kind", "")) == "neighbor":
		owner = _owner_faction(game, site)
		if owner != "" and rng.randf() < SEEN_P:
			seen = true
			game._add_opinion(owner, -10, "night_run")
	st.recover[str(site.id)] = int(game.week) + DEPLETE_WEEKS
	_save_rng(game, rng)
	var ev := _card(game, site, pack, encounter, hurt, dead, taken, rested, thin, seen, band, named)
	game.pending.push_front(ev)
	game._log("NIGHT back %s %s" % [str(site.id), band], true)


static func apply_choice(game, ev: Dictionary, choice: Dictionary) -> void:
	if bool(ev.get("granted", false)):
		return
	ev["granted"] = true
	var pick := str(choice.get("id", ""))
	var pack: Dictionary = ev.get("pack", {}).duplicate()
	if pick == "take_half":
		pack = half_pack(pack)
	elif pick == "leave" or pick == "read":
		if pick == "leave":
			pack = {"food": 0, "materials": 0, "medkits": 0, "intel": 0}
			for pid in ev.get("rested", []):
				if game.people.has(str(pid)):
					game._life_note(game.people[str(pid)], "night_run", {})
		# "read" keeps the packed loot. "leave" pays the journal only.
	if pick == "leave":
		return
	_grant(game, ev, pack)


static func fill_pack(yields: Dictionary, order: Array, slots: int) -> Dictionary:
	var left := {
		"food": int(yields.get("food", 0)),
		"materials": int(yields.get("materials", 0)),
		"medkits": int(yields.get("medkits", 0)),
		"intel": int(yields.get("intel", 0)),
	}
	var got := {"food": 0, "materials": 0, "medkits": 0, "intel": 0}
	var room := slots
	for kind in order:
		var cost := MEDKIT_UNITS if str(kind) == "medkits" else 1
		while int(left.get(kind, 0)) > 0 and room >= cost:
			got[kind] = int(got[kind]) + 1
			left[kind] = int(left[kind]) - 1
			room -= cost
	return got


static func half_pack(pack: Dictionary) -> Dictionary:
	return {
		"food": int(pack.get("food", 0)) / 2,
		"materials": int(pack.get("materials", 0)) / 2,
		"medkits": int(pack.get("medkits", 0)) / 2,
		"intel": int(pack.get("intel", 0)) / 2,
	}


static func best_bonus(game, ids: Array) -> int:
	var best := 0
	for id in ids:
		if not game.people.has(str(id)):
			continue
		var person: Dictionary = game.people[str(id)]
		best = maxi(best, int(game.check_value(person, "senses")))
		best = maxi(best, int(game.check_value(person, "grit")))
	return best


static func voice_band(game, ids: Array) -> int:
	var best := 0
	for id in ids:
		if not game.people.has(str(id)):
			continue
		best = maxi(best, int(game.check_value(game.people[str(id)], "voice")))
	return best


static func loot_phrase(pack: Dictionary) -> String:
	var bits: PackedStringArray = []
	for kind in PRIORITIES:
		var n := int(pack.get(kind, 0))
		if n <= 0:
			continue
		bits.append("%s ×%d" % [_good_word(kind), n])
	return ", ".join(bits)


static func art_path(site: Dictionary) -> String:
	return str(ART.get(str(site.get("kind", "")), ""))


static func view(game) -> Dictionary:
	var st := boot(game)
	var active: Dictionary = st.get("active", {})
	return {
		"active": not active.is_empty(),
		"site": str(active.get("site", "")),
		"runners": active.get("runners", []),
		"cap": runner_cap(game),
		"units": PACK_UNITS,
		"known": known_sites(game).size(),
		"rumored": rumored_sites(game).size(),
		"deaths": int(st.get("deaths", 0)),
		"runs": int(st.get("runs", 0)),
	}


## Bots do not send. A starving careful send saved runs and dropped the
## 60-seed loss corridor under 15%. Capture-only is the SPEC lever, and only
## when careful losses pass 35%. The player still sends from the night panel.
static func bot_send(_game, _profile: String) -> void:
	return


static func _card(game, site: Dictionary, pack: Dictionary, encounter: String, hurt: Array, dead: Array, taken: Array, rested: Array, thin: bool, seen: bool, band: String, named: Dictionary) -> Dictionary:
	var lines_en: PackedStringArray = []
	var lines_ru: PackedStringArray = []
	_push_line(lines_en, lines_ru, "run.back", {})
	var phrase_en := ""
	var phrase_ru := ""
	if _pack_empty(pack):
		_push_line(lines_en, lines_ru, "run.empty_handed", {})
	else:
		phrase_en = _phrase_lang(pack, "en")
		phrase_ru = _phrase_lang(pack, "ru")
		_push_line(lines_en, lines_ru, "run.loot", {"loot": phrase_en}, {"loot": phrase_ru})
	for pid in hurt:
		_push_named(lines_en, lines_ru, "run.injured", named.get(str(pid), {}))
	for pid in taken:
		_push_named(lines_en, lines_ru, "run.captured", named.get(str(pid), {}))
	for pid in dead:
		_push_named(lines_en, lines_ru, "run.death", named.get(str(pid), {}))
	for pid in rested:
		_push_named(lines_en, lines_ru, "run.rest", named.get(str(pid), {}))
	if seen:
		_push_line(lines_en, lines_ru, "run.seen", {})
	if thin:
		_push_line(lines_en, lines_ru, "run.depleted", {})
	var title := _both("run.resolve_title")
	var choices: Array = []
	if encounter != "" and not rested.is_empty():
		var full := pack
		var half := half_pack(pack)
		choices.append(_loot_choice("take_all", "run.take_all", full))
		choices.append(_loot_choice("take_half", "run.take_half", half))
		choices.append(_loot_choice("leave", "run.leave_cache", {}))
	else:
		var ack := _loot_choice("read", "", pack)
		ack.label = _both_raw("To the platform")
		choices.append(ack)
	return {
		"id": "night_run_w%d" % int(game.week),
		"major": true,
		"night_run": true,
		"title": title,
		"text": {"en": "\n".join(lines_en), "ru": "\n".join(lines_ru)},
		"site": str(site.get("id", "")),
		"art": art_path(site),
		"encounter": encounter,
		"pack": pack.duplicate(),
		"band": band,
		"hurt": hurt.duplicate(),
		"dead": dead.duplicate(),
		"taken": taken.duplicate(),
		"rested": rested.duplicate(),
		"thin": thin,
		"seen": seen,
		"voice": voice_band(game, rested),
		"choices": choices,
	}


static func _grant(game, ev: Dictionary, pack: Dictionary) -> void:
	game.stock.food = int(game.stock.food) + int(pack.get("food", 0))
	game.stock.materials = int(game.stock.materials) + int(pack.get("materials", 0))
	if int(pack.get("medkits", 0)) > 0:
		game.flags["medkits"] = true
	if int(pack.get("intel", 0)) > 0:
		var site_id := str(ev.get("site", ""))
		var bump := 2 if int(ev.get("voice", 0)) >= 3 else 1
		var st := boot(game)
		st.intel[site_id] = clampi(int(st.intel.get(site_id, 0)) + bump, 0, 3)


static func _loot_choice(id: String, key: String, pack: Dictionary) -> Dictionary:
	var row := {
		"id": id,
		"food": int(pack.get("food", 0)),
		"materials": int(pack.get("materials", 0)),
		"label": _both(key) if key != "" else {"en": "", "ru": ""},
	}
	return row


static func _injure(game, pid: String) -> void:
	if not game.people.has(pid):
		return
	var person: Dictionary = game.people[pid]
	person.sick = maxi(int(person.get("sick", 0)), 2)
	person["on_run"] = false


static func _capture(game, pid: String, site: Dictionary) -> void:
	if not game.people.has(pid):
		return
	var place := ""
	if game.stations.has(str(site.get("station", ""))):
		place = str(game.stations[str(site.station)].get("name", ""))
	game.people[pid]["on_run"] = false
	game._remove_resident(pid, true, "night_run", "left", place)


static func _kill(game, pid: String, site: Dictionary) -> void:
	if not game.people.has(pid):
		return
	var place := ""
	if game.stations.has(str(site.get("station", ""))):
		place = str(game.stations[str(site.station)].get("name", ""))
	game.people[pid]["on_run"] = false
	game._remove_resident(pid, true, "night_run", "died", place)


static func _weakest(game, ids: Array) -> String:
	var best := ""
	var score := 999
	for id in ids:
		var pid := str(id)
		if not game.people.has(pid):
			continue
		var person: Dictionary = game.people[pid]
		var s := int(game.check_value(person, "senses")) + int(game.check_value(person, "grit"))
		if best == "" or s < score or (s == score and pid < best):
			score = s
			best = pid
	return best if best != "" else str(ids[0])


static func _clear_out(game, runners: Array) -> void:
	for id in runners:
		if game.people.has(str(id)):
			game.people[str(id)]["on_run"] = false


static func _owner_faction(game, site: Dictionary) -> String:
	var sid := str(site.get("station", ""))
	if not game.stations.has(sid):
		return ""
	var owner := str(game.stations[sid].get("owner", ""))
	if owner == "" or owner == "neutral" or owner == "ruin" or owner == "bunker" or owner == str(game.player):
		return ""
	if not game.opinions.has(owner):
		return ""
	return owner


static func _order(priority: Array) -> Array:
	var out: Array = []
	var seen := {}
	for kind in priority:
		var key := str(kind)
		if not PRIORITIES.has(key) or seen.has(key):
			continue
		seen[key] = true
		out.append(key)
	for kind in PRIORITIES:
		if not seen.has(kind):
			out.append(kind)
	return out


static func _good_word(kind: String) -> String:
	var keys := {
		"food": "run.priority_food",
		"materials": "run.priority_mats",
		"medkits": "run.priority_medkits",
		"intel": "run.priority_intel",
	}
	var line := Copy.t(str(keys.get(kind, kind)))
	var cut := line.split(":")
	if cut.size() >= 2:
		return cut[1].strip_edges().to_lower()
	return line


static func _phrase_lang(pack: Dictionary, lang: String) -> String:
	var was := Copy.lang
	Copy.set_lang(lang)
	var phrase := loot_phrase(pack)
	Copy.set_lang(was)
	return phrase


static func _both(key: String) -> Dictionary:
	var was := Copy.lang
	Copy.set_lang("en")
	var en := Copy.t(key)
	Copy.set_lang("ru")
	var ru := Copy.t(key)
	Copy.set_lang(was)
	return {"en": en, "ru": ru}


static func _both_raw(text: String) -> Dictionary:
	var was := Copy.lang
	Copy.set_lang("en")
	var en := Copy.t(text)
	Copy.set_lang("ru")
	var ru := Copy.t(text)
	Copy.set_lang(was)
	return {"en": en, "ru": ru}


static func _push_line(en_lines: PackedStringArray, ru_lines: PackedStringArray, key: String, en_vars: Dictionary, ru_vars: Dictionary = {}) -> void:
	var ru_use := ru_vars if not ru_vars.is_empty() else en_vars
	var was := Copy.lang
	Copy.set_lang("en")
	en_lines.append(Copy.fill(key, en_vars))
	Copy.set_lang("ru")
	ru_lines.append(Copy.fill(key, ru_use))
	Copy.set_lang(was)


static func _identity(game, pid: String) -> Dictionary:
	if not game.people.has(pid):
		return {"name": pid, "name_ru": "", "fem": false}
	var person: Dictionary = game.people[pid]
	return {
		"name": str(person.get("name", pid)),
		"name_ru": str(person.get("name_ru", "")),
		"fem": str(game.sex_of(person)) == "f",
	}


static func _push_named(en_lines: PackedStringArray, ru_lines: PackedStringArray, key: String, who: Dictionary) -> void:
	var en_name := str(who.get("name", ""))
	var ru_name := str(who.get("name_ru", ""))
	if ru_name == "":
		ru_name = en_name
	var fem: bool = bool(who.get("fem", false))
	_push_line(en_lines, ru_lines, key, {"name": en_name, "fem": fem}, {"name": ru_name, "fem": fem})


static func _name(game, pid: String) -> String:
	if not game.people.has(pid):
		return pid
	var person: Dictionary = game.people[pid]
	if Copy.ru() and str(person.get("name_ru", "")) != "":
		return str(person.name_ru)
	return str(person.get("name", pid))


static func _pack_empty(pack: Dictionary) -> bool:
	for kind in PRIORITIES:
		if int(pack.get(kind, 0)) > 0:
			return false
	return true


static func _rng(game) -> RandomNumberGenerator:
	var st := boot(game)
	var rng := RandomNumberGenerator.new()
	rng.state = int(st.get("rng", 0))
	return rng


static func _save_rng(game, rng: RandomNumberGenerator) -> void:
	boot(game)["rng"] = rng.state


static func _read_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	return JSON.parse_string(f.get_as_text())
