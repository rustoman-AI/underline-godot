extends RefCounted
class_name Brief

## Display copy for stocks, rooms, and shortages. Does not change the week.


static func source(game, key: String) -> Dictionary:
	var info := {
		"key": key,
		"headline": "",
		"made": "",
		"used": "",
		"build_type": "",
		"rooms": [],
	}
	if key == "hope" or key == "discontent":
		return _meter(game, key, info)
	var have := int(game.stock.get(key, 0))
	var made: int = int(game.output_of(key))
	if key == "power" and game._law_on("engineers_charter"):
		made += int(game.catalog.laws.engineers_charter.get("power", 0))
	info.headline = Copy.t("%s: %d (%+d / week)") % [Copy.res(key), have, made]
	var bits: PackedStringArray = []
	var rooms: Array = []
	for room in game.rooms:
		var defin: Dictionary = game.catalog.rooms[room.type]
		var base: Dictionary = defin.get("base", {})
		if not base.has(key):
			continue
		var amount := 0
		var detail: Dictionary = game.room_detail(str(room.uid))
		for out in detail.get("outputs", []):
			if str(out.key) == key:
				amount = int(out.amount)
		rooms.append(str(room.uid))
		var crew := ""
		if int(defin.get("staff_max", 0)) > 0:
			crew = Copy.t("%d of %d crew") % [room.staff.size(), int(defin.staff_max)]
			bits.append(Copy.t("%s (+%d, %s)") % [Copy.t(str(defin.name)), amount, crew])
		else:
			bits.append("%s (+%d)" % [Copy.t(str(defin.name)), amount])
	if key == "power" and game._law_on("engineers_charter"):
		bits.append(Copy.t("%s (+%d)") % [Copy.t("Engineers' Charter"), int(game.catalog.laws.engineers_charter.get("power", 0))])
	if key == "tokens":
		for law_id in game.laws_on:
			var defin: Dictionary = game.catalog.laws[law_id]
			if defin.has("tokens_week"):
				bits.append(Copy.t("%s (+%d)") % [Copy.t(str(defin.name)), int(defin.tokens_week)])
	if key == "materials":
		bits.append(Copy.t("digging rock cells"))
		bits.append(Copy.t("salvage events"))
	var producer := _producer(key)
	if rooms.is_empty() and key != "materials" and key != "tokens":
		info.made = Copy.t("Nothing makes this right now.")
		info.build_type = producer
	elif rooms.is_empty() and key == "tokens" and bits.is_empty():
		info.made = Copy.t("Nothing makes this on a schedule. Trade and laws can add tokens.")
	elif rooms.is_empty() and key == "materials":
		info.made = Copy.t("Made by: %s") % " · ".join(bits)
		info.made = Copy.t("Nothing makes this right now.") + " " + info.made
		info.build_type = producer
	else:
		info.made = Copy.t("Made by: %s") % " · ".join(bits)
	info.used = _used(game, key)
	info.rooms = rooms
	return info


static func offer(game, type: String) -> String:
	var defin: Dictionary = game.catalog.rooms[type]
	var name := Copy.t(str(defin.name))
	var head := name
	var base: Dictionary = defin.get("base", {})
	if not base.is_empty():
		var key := str(base.keys()[0])
		var span := _span(game, defin, key)
		head = Copy.t("%s: makes %s. +%d / week empty crew, up to +%d with a skilled crew.") % [name, _res_makes(key), span.x, span.y]
	elif type == "quarters":
		head = Copy.t("%s: beds for %d.") % [name, int(defin.get("housing", 0))]
	elif type == "infirmary":
		head = Copy.t("%s: a medic on duty clears a sickness.") % name
	elif type == "radio":
		head = Copy.t("%s: a staffed set hears warnings from the line.") % name
	elif type == "meeting_hall":
		head = Copy.t("%s: a hall for laws and rallies.") % name
	var tail: PackedStringArray = []
	if int(defin.get("staff_max", 0)) > 0:
		tail.append(Copy.t("Crew %d") % int(defin.staff_max))
	var draw := int(defin.get("power", 0))
	if draw > 0:
		tail.append(Copy.t("uses %d power") % draw)
	var stored: PackedStringArray = []
	var store: Dictionary = defin.get("store", {})
	for skey in ["food", "air", "materials"]:
		var n := int(store.get(skey, 0))
		if n > 0:
			stored.append(Copy.stock(n, str(skey)))
	if not stored.is_empty():
		tail.append(Copy.t("stores %s") % ", ".join(stored))
	tail.append(Words.count(int(defin.get("materials", 0)), "material"))
	tail.append(Words.count(maxi(int(defin.get("build_turns", 0)), 1), "week"))
	return head + "\n" + " · ".join(tail)


static func output_span(game, type: String) -> Vector2i:
	var defin: Dictionary = game.catalog.rooms.get(type, {})
	var base: Dictionary = defin.get("base", {})
	if base.is_empty():
		return Vector2i.ZERO
	return _span(game, defin, str(base.keys()[0]))


static func upgrade_changes(game, uid: String) -> Array:
	var room = game._room(uid)
	if room == null:
		return []
	var defin: Dictionary = game.catalog.rooms[room.type]
	var detail: Dictionary = game.room_detail(uid)
	var rows: Array = []
	for out in detail.get("outputs", []):
		var now_n := int(out.amount)
		var next_n := _live(game, room, defin, int(room.upgrade) + 1, str(out.key))
		if now_n == next_n:
			continue
		var key := str(out.key)
		rows.append({"key": key, "before": now_n, "after": next_n, "gain": next_n > now_n})
	return rows


static func marginal(game, uid: String, person_id: String) -> Dictionary:
	var empty := {"key": "", "delta": 0, "note": ""}
	var room = game._room(uid)
	if room == null:
		return empty
	var defin: Dictionary = game.catalog.rooms[room.type]
	var note := ""
	match str(room.type):
		"infirmary":
			note = "clears sickness"
		"radio":
			note = "reveals intents"
	var base: Dictionary = defin.get("base", {})
	if base.is_empty():
		empty.note = note
		return empty
	var key := str(base.keys()[0])
	var now_ids: Array = []
	for id in room.staff:
		now_ids.append(str(id))
	var next_ids: Array = now_ids.duplicate()
	if not next_ids.has(person_id):
		next_ids.append(person_id)
	var now_n := _amount(game, room, defin, now_ids, key)
	var next_n := _amount(game, room, defin, next_ids, key)
	return {"key": key, "delta": next_n - now_n, "note": note}


static func upgrade_line(game, uid: String) -> String:
	var info: Dictionary = game.upgrade_preview(uid)
	if str(info.get("name", "")) == "":
		return ""
	var room = game._room(uid)
	if room == null:
		return ""
	var defin: Dictionary = game.catalog.rooms[room.type]
	var label := Copy.t(str(info.name).replace("_", " "))
	var parts: PackedStringArray = []
	var detail: Dictionary = game.room_detail(uid)
	for out in detail.get("outputs", []):
		var now_n := int(out.amount)
		var next_n := _live(game, room, defin, int(room.upgrade) + 1, str(out.key))
		if now_n != next_n:
			parts.append(Copy.t("%s +%d -> +%d / week") % [_res_lower(str(out.key)), now_n, next_n])
	if parts.is_empty():
		parts.append(Copy.t("the weekly numbers stay"))
	parts.append(Words.count(int(info.get("materials", 0)), "material"))
	return "%s: %s" % [label, " · ".join(parts)]


static func demolish_line(game, uid: String) -> String:
	var info: Dictionary = game.demolish_preview(uid)
	var detail: Dictionary = game.room_detail(uid)
	var parts: PackedStringArray = []
	for out in detail.get("outputs", []):
		if int(out.amount) == 0:
			continue
		parts.append(Copy.t("%s +%d -> 0 / week") % [_res_lower(str(out.key)), int(out.amount)])
	parts.append(Copy.t("returns %s") % Words.count(int(info.get("refund", 0)), "material"))
	return Copy.t("Demolish: %s") % " · ".join(parts)


static func where_for(game, key: String) -> String:
	var producer := _producer(key)
	var made: int = int(game.output_of(key))
	if producer != "" and game.room_count(producer) > 0:
		var name := Copy.t(str(game.catalog.rooms[producer].name))
		if key == "materials":
			return Copy.t("%s makes %d / week; digging rock can turn up salvage.") % [name, made]
		return Copy.t("%s makes %d / week.") % [name, made]
	if producer != "":
		var name := Copy.t(str(game.catalog.rooms[producer].name))
		return Copy.t("Nothing makes %s this week. Build a %s.") % [Copy.res(key), name]
	if key == "tokens":
		return Copy.t("Trade and laws can add tokens.")
	return ""


static func _meter(game, key: String, info: Dictionary) -> Dictionary:
	var have := int(game.hope) if key == "hope" else int(game.discontent)
	var delta := int(game.bal.get("hope_drift", 0)) if key == "hope" else 0
	for law_id in game.laws_on:
		var defin: Dictionary = game.catalog.laws[law_id]
		if key == "hope" and defin.has("hope_week"):
			delta += int(defin.hope_week)
		if key == "discontent" and defin.has("discontent_week"):
			delta += int(defin.discontent_week)
	info.headline = Copy.t("%s: %d (%+d / week)") % [Copy.res(key), have, delta]
	if key == "hope":
		info.made = Copy.t("Made by: the weekly slide (%+d), plus laws and choices.") % int(game.bal.get("hope_drift", 0))
		info.used = Copy.t("Used by: shortages, a hard week, and some laws")
	else:
		info.made = Copy.t("Made by: crowding, shortages, and some laws")
		info.used = Copy.t("Used by: a staffed hall, rallies, and some laws")
	return info


static func _used(game, key: String) -> String:
	match key:
		"food":
			return Copy.t("Used by: meals (%d / week)") % game.food_need()
		"air":
			return Copy.t("Used by: breathing (%d / week)") % game.air_need()
		"power":
			return Copy.t("Used by: the rooms (%d / week)") % game._weekly_draw("power")
		"materials":
			var up: int = int(game.bal.filter_upkeep) * int(game.room_count("air_filter"))
			return Copy.t("Used by: building, upgrades, filter upkeep (%d / week)") % up
		"tokens":
			return Copy.t("Used by: trade and gifts")
		"influence":
			return Copy.t("Used by: laws and the hall")
	return ""


static func _producer(key: String) -> String:
	match key:
		"food":
			return "hydroponics"
		"air":
			return "air_filter"
		"power":
			return "generator"
		"materials":
			return "workshop"
		"influence":
			return "meeting_hall"
	return ""


static func _span(game, defin: Dictionary, key: String) -> Vector2i:
	var low_n := int(defin.get("staff_min", 0))
	var high_n := maxi(int(defin.get("staff_max", 0)), low_n)
	return Vector2i(_rated(game, defin, key, 1, low_n), _rated(game, defin, key, 5, high_n))


static func _rated(game, defin: Dictionary, key: String, skill: int, count: int) -> int:
	var amount := float(defin.base[key])
	var skills: Array = []
	for _i in count:
		skills.append(skill)
	var fake := {"type": str(defin.get("id", "")), "staff": []}
	for _i in count:
		fake.staff.append("x")
	var factor: float = game._output_factor(fake, defin)
	if factor <= 0.0:
		return 0
	var n := Formulas.room_output(amount, skills, float(game.bal.skill_coef), float(game.bal.output_cap))
	return int(round(float(n) * factor))


static func _amount(game, room: Dictionary, defin: Dictionary, ids: Array, key: String) -> int:
	var skill := str(defin.get("skill", ""))
	var skills: Array = []
	for id in ids:
		if not game.people.has(str(id)):
			continue
		var person: Dictionary = game.people[str(id)]
		var value := 0 if skill == "" else int(person.skills.get(skill, 1))
		if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			value = 0
		skills.append(value)
	var base: Dictionary = defin.get("base", {})
	if not base.has(key):
		return 0
	var fake := {"type": str(room.type), "staff": ids}
	var amount := float(base[key]) * (1.0 + 0.25 * float(room.upgrade))
	var factor: float = game._output_factor(fake, defin)
	var n := 0
	if factor > 0.0:
		n = Formulas.room_output(amount, skills, float(game.bal.skill_coef), float(game.bal.output_cap))
		n = int(round(float(n) * factor))
	if bool(defin.get("decays", false)):
		n = int(round(float(n) * float(room.get("efficiency", 1.0))))
	if game.belt_down and str(room.type) == "hydroponics" and key == "food":
		n = int(n / 2.0)
	if game.workshop_down and str(room.type) == "workshop" and key == "materials":
		n = 0
	if game.gen_down and str(room.type) == "generator" and key == "power":
		n = int(n / 2.0)
	return n


static func _live(game, room: Dictionary, defin: Dictionary, upgrade: int, key: String) -> int:
	var skill := str(defin.get("skill", ""))
	var skills: Array = []
	for id in room.staff:
		var person: Dictionary = game.people[str(id)]
		var value := 0 if skill == "" else int(person.skills.get(skill, 1))
		if int(person.sick) > 0 or int(person.absent) > 0:
			value = 0
		skills.append(value)
	var base: Dictionary = defin.get("base", {})
	if not base.has(key):
		return 0
	var amount := float(base[key]) * (1.0 + 0.25 * float(upgrade))
	var factor: float = game._output_factor(room, defin)
	var n := 0
	if factor > 0.0:
		n = Formulas.room_output(amount, skills, float(game.bal.skill_coef), float(game.bal.output_cap))
		n = int(round(float(n) * factor))
	if bool(defin.get("decays", false)):
		n = int(round(float(n) * float(room.efficiency)))
	if game.belt_down and str(room.type) == "hydroponics" and key == "food":
		n = int(n / 2.0)
	if game.workshop_down and str(room.type) == "workshop" and key == "materials":
		n = 0
	if game.gen_down and str(room.type) == "generator" and key == "power":
		n = int(n / 2.0)
	return n


static func _res_lower(key: String) -> String:
	var word := Copy.res(key)
	if word == "":
		return word
	return word.substr(0, 1).to_lower() + word.substr(1)


static func _res_makes(key: String) -> String:
	if not Copy.ru():
		return _res_lower(key)
	match key:
		"food":
			return "еду"
		"air":
			return "воздух"
		"power":
			return "энергию"
		"materials":
			return "материалы"
		"influence":
			return "влияние"
		"tokens":
			return "жетоны"
	return _res_lower(key)
