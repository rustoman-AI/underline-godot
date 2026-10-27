class_name Catalog
extends RefCounted

var balance: Dictionary = {}
var rooms: Dictionary = {}
var laws: Dictionary = {}
var factions: Dictionary = {}
## Leaders who come to the station for an audience (rules in docs/LEADERS.md). Separate from `factions`,
## which describes the rival powers on the map.
var leaders: Dictionary = {}
## What the leaders say (data/leader_lines.json, docs/LEADERS.md); dialogue only, never terms.
var lines: Dictionary = {}
var stations: Array = []
var tunnels: Array = []
var events: Array = []
var check_events: Dictionary = {}
## English -> Russian for the leader consequence events, as written in data/events_leaders.json.
var leader_ru: Dictionary = {}
## English -> Russian for the story events, as written in data/events_story.json.
var story_ru: Dictionary = {}
## English -> Russian for the random pool batches, as written in data/events_pool.json.
var pool_ru: Dictionary = {}
## Truth fragments by id (data/truth.json): title, hint and text, each {en, ru}.
var truth: Dictionary = {}
## Endings and epilogue lines (data/endings.json): "endings", "leaders" by answer, "truth" by proofs.
var endings: Dictionary = {}
## Three-beat epilogue: verdicts, chronicle lines, judgments, and fates (data/epilogues.json).
var epilogues: Dictionary = {}
## Hardship reason and line packs (data/hardship.json). The week's tension math does not read this file.
var hardship: Dictionary = {}
var coney: Dictionary = {}
## Cast id to the resident portrait it keeps, e.g. "bait": "portrait_05" (data/cast_portraits.json).
var cast_portraits: Dictionary = {}
## Resident profiles (data/resident_profiles.json): "residents" by id (sex, portrait pin, title, before,
## keepsake), "cast" sex by Coney cast id, "portrait_sex" by portrait stem, "generated_names" sex by first name.
var profiles: Dictionary = {}
var residents: Array = []
var names: Dictionary = {}
var grid: Dictionary = {}
var communities: Dictionary = {}
## English community, who, conflict and art per station id; the Russian text lives in `communities`.
var communities_en: Dictionary = {}
var geo: Dictionary = {}
var error: String = ""


func load_all() -> bool:
	balance = _obj("balance.json")
	rooms = _index(_arr("rooms.json"), "id")
	laws = _index(_arr("laws.json"), "id")
	factions = _obj("factions.json")
	leaders = _obj("faction_leaders.json")
	lines = _obj("leader_lines.json")
	stations = _arr("stations.json")
	tunnels = _arr("tunnels.json")
	events = _arr("events.json")
	var base_ru := _obj("ru.json")
	pool_ru = add_events(_obj("events_pool.json"), base_ru)
	leader_ru = add_events(_obj("events_leaders.json"), base_ru)
	story_ru = add_events(_obj("events_story.json"), base_ru)
	_install_station_life()
	truth = _index(_obj("truth.json").get("fragments", []), "id")
	endings = _obj("endings.json")
	epilogues = _obj("epilogues.json")
	hardship = _obj("hardship.json")
	check_events = _obj("events_checks.json")
	coney = _obj("characters_coney.json")
	cast_portraits = _obj("cast_portraits.json").get("pins", {})
	profiles = _obj("resident_profiles.json")
	residents = _arr("residents.json")
	names = _obj("names.json")
	grid = _obj("start_grid.json")
	communities = _obj("station_communities.json")
	communities_en = _obj("station_communities_en.json")
	geo = _obj("map_geo.json")
	var bad_goods := goods_problems()
	if error == "" and not bad_goods.is_empty():
		error = "station goods: " + "; ".join(bad_goods)
	return error == ""


const GOODS := ["food", "materials", "tokens", "influence", "air"]
const GOODS_TOTAL := 10


## What a held station ships before distance and focus (docs/STATION_GOODS_PLAN.md). Stations without a table
## ship the old flat base.
func station_goods(sid: String) -> Dictionary:
	var row = communities.get("stations", {}).get(sid, {}).get("goods", {})
	if row is Dictionary and not (row as Dictionary).is_empty():
		return row
	return {"food": 5, "materials": 3, "tokens": 2}


## Every "goods" table: known goods only, positive whole numbers, three of them, summing to GOODS_TOTAL.
func goods_problems() -> PackedStringArray:
	var bad := PackedStringArray()
	var rows: Dictionary = communities.get("stations", {})
	for sid in rows:
		var goods = rows[sid].get("goods", null)
		if goods == null:
			continue
		if not (goods is Dictionary) or goods.size() != 3:
			bad.append("%s needs three goods" % sid)
			continue
		var total := 0
		for key in goods:
			if not GOODS.has(str(key)) or typeof(goods[key]) not in [TYPE_INT, TYPE_FLOAT] or int(goods[key]) < 1:
				bad.append("%s has %s %s" % [sid, str(key), str(goods[key])])
			total += int(goods[key])
		if total != GOODS_TOTAL:
			bad.append("%s sums to %d" % [sid, total])
	return bad


## Random pool batches, leader consequence and story events (data/events_pool.json, data/events_leaders.json,
## data/events_story.json) join the event list.
## Their "ru" map joins the Russian lookup in Copy; where ru.json already words the same English string
## differently, the event keeps its own Russian in "ru_own" (read by Game.line_of) so neither text changes the
## other. Returns the file's "ru" map.
func add_events(data: Dictionary, base_ru: Dictionary) -> Dictionary:
	var own: Dictionary = data.get("ru", {})
	for ev in data.get("events", []):
		if not (ev is Dictionary):
			continue
		_keep_ru(ev, ["title", "text"], own, base_ru)
		for choice in ev.get("choices", []):
			if choice is Dictionary:
				_keep_ru(choice, ["label"], own, base_ru)
		events.append(ev)
	return own


func _keep_ru(node: Dictionary, keys: Array, own: Dictionary, base_ru: Dictionary) -> void:
	for key in keys:
		var en := str(node.get(key, ""))
		if own.has(en) and base_ru.has(en) and str(base_ru[en]) != str(own[en]):
			if not node.has("ru_own"):
				node["ru_own"] = {}
			node.ru_own[key] = str(own[en])


## What is wrong with data/resident_profiles.json against the residents, the cast pins and the portrait files.
func profile_problems() -> PackedStringArray:
	var bad := PackedStringArray()
	var rows: Dictionary = profiles.get("residents", {})
	var faces: Dictionary = profiles.get("portrait_sex", {})
	var owner := {}
	for face in faces:
		if not ["m", "f"].has(str(faces[face])):
			bad.append("portrait %s has sex %s" % [face, faces[face]])
		if not ResourceLoader.exists("res://assets/portraits/%s.webp" % face):
			bad.append("portrait %s has no file" % face)
	for cast in cast_portraits:
		var face := str(cast_portraits[cast])
		if owner.has(face):
			bad.append("%s pinned to %s and %s" % [face, owner[face], cast])
		owner[face] = str(cast)
		var sex := str(profiles.get("cast", {}).get(cast, {}).get("sex", ""))
		if not ["m", "f"].has(sex):
			bad.append("cast %s has no sex" % cast)
		elif faces.get(face, "") != sex:
			bad.append("cast %s (%s) pinned to %s (%s)" % [cast, sex, face, faces.get(face, "missing")])
	for row in residents:
		if not rows.has(str(row.get("id", ""))):
			bad.append("resident %s has no profile" % str(row.get("id", "")))
	for id in rows:
		var row: Dictionary = rows[id]
		var sex := str(row.get("sex", ""))
		if not ["m", "f"].has(sex):
			bad.append("%s has sex %s" % [id, sex])
		if row.has("portrait"):
			var face := str(row.portrait)
			if not faces.has(face):
				bad.append("%s pinned to unknown %s" % [id, face])
			elif str(faces[face]) != sex:
				bad.append("%s (%s) pinned to %s (%s)" % [id, sex, face, faces[face]])
			if owner.has(face):
				bad.append("%s pinned to %s and %s" % [face, owner[face], id])
			owner[face] = str(id)
		for key in ["title", "before", "keepsake"]:
			var pack = row.get(key)
			if not (pack is Dictionary) or str(pack.get("en", "")).strip_edges() == "" or str(pack.get("ru", "")).strip_edges() == "":
				bad.append("%s %s needs en and ru" % [id, key])
				continue
			for lang in ["en", "ru"]:
				if str(pack[lang]).contains("\u2014") or str(pack[lang]).contains("\u2013"):
					bad.append("%s %s %s has a dash" % [id, key, lang])
	for first in names.get("first", []):
		if not ["m", "f"].has(str(profiles.get("generated_names", {}).get(str(first), ""))):
			bad.append("first name %s has no sex" % first)
	return bad


func _read(name: String) -> Variant:
	var path := "res://data/%s" % name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		error = "Cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())]
		return null
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		error = "Bad JSON in %s" % path
		return null
	return data


func _obj(name: String) -> Dictionary:
	var data = _read(name)
	if data is Dictionary:
		return data
	if error == "":
		error = "%s is not an object" % name
	return {}


func _arr(name: String) -> Array:
	var data = _read(name)
	if data is Array:
		return data
	if error == "":
		error = "%s is not a list" % name
	return []


## P62. Five station-life one-shots join the mid-week pool from the locked pack.
## Numbers come from balance.station_life_scale. Text stays the pack's EN+RU.
## effects_words → fields. A leading '-' is the drop. "dawn_flavor" copies the quoted log line.
const STATION_LIFE_MAP := {
	"chalk_marks": {
		"leave": {"hope": "hope_small", "discontent": "discontent_small"},
		"scrub": {"hope": "-hope_small", "discontent": "-discontent_small"},
		"copy": {"cost": {"influence": "influence_small"}, "hope": "hope_small"},
	},
	"silent_car": {
		"follow": {"cost": {"food": "food_small"}, "hope": "hope_small", "dawn_flavor": true},
		"bar": {"discontent": "discontent_small"},
		"ignore": {"hope": "-hope_small", "discontent": "discontent_small"},
	},
	"mold_cart": {
		"replace": {"cost": {"materials": "materials_small"}, "hope": "hope_small"},
		"scrape": {"air": "-air_small", "discontent": "discontent_small"},
		"boil": {"power": "-power_small"},
	},
	"shift_trade": {
		"ban": {"discontent": "discontent_small"},
		"tax": {"tokens": "tokens_small", "hope": "-hope_small", "discontent": "discontent_small"},
		"cover": {"cost": {"tokens": "tokens_small"}, "discontent": "-discontent_small"},
	},
	"pickle_stamp": {
		"eat": {"food": "food_small", "hope": "hope_small", "opinion_directorate": "-opinion_small"},
		"return": {"opinion_directorate": "opinion_small"},
		"hide": {"food": "food_small", "discontent": "discontent_small"},
	},
}


func _install_station_life() -> void:
	if error != "":
		return
	var data = _read("station_life_events.json")
	if not (data is Dictionary):
		if error == "":
			error = "station_life_events.json is not an object"
		return
	var scale: Dictionary = balance.get("station_life_scale", {})
	if scale.is_empty():
		error = "station life: no station_life_scale"
		return
	var have := {}
	for ev in events:
		have[str(ev.get("id", ""))] = true
	for raw in data.get("events", []):
		if not (raw is Dictionary):
			continue
		var id := str(raw.get("id", ""))
		if id == "" or have.has(id):
			error = "station life: duplicate or blank id %s" % id
			return
		var built := _station_life_event(raw, scale)
		if error != "":
			return
		events.append(built)
		have[id] = true


func _station_life_event(raw: Dictionary, scale: Dictionary) -> Dictionary:
	var id := str(raw.get("id", ""))
	var spec: Dictionary = STATION_LIFE_MAP.get(id, {})
	if spec.is_empty():
		error = "station life: no number map for %s" % id
		return {}
	var choices: Array = []
	for raw_choice in raw.get("choices", []):
		if not (raw_choice is Dictionary):
			continue
		var cid := str(raw_choice.get("id", ""))
		if not spec.has(cid):
			error = "station life: %s choice %s has no number map" % [id, cid]
			return {}
		var built := {"id": cid, "label": raw_choice.get("label", {})}
		var fx: Dictionary = spec[cid]
		for key in fx:
			if str(key) == "dawn_flavor":
				var quote := _station_life_quote(str(raw_choice.get("effects_words", "")))
				if quote == "":
					error = "station life: %s %s flavor quote missing" % [id, cid]
					return {}
				built["dawn_flavor"] = {"en": quote}
				continue
			if str(key) == "cost":
				built["cost"] = _station_life_nums(fx.cost, scale, id, cid)
				if error != "":
					return {}
				continue
			var n := _station_life_one(scale, str(fx[key]))
			if n == 0:
				error = "station life: %s %s %s is 0" % [id, cid, str(key)]
				return {}
			built[str(key)] = n
		choices.append(built)
	if choices.is_empty():
		error = "station life: %s has no choices" % id
		return {}
	return {
		"id": id,
		"title": raw.get("title", {}),
		"text": raw.get("text", {}),
		"who": str(raw.get("who", "")),
		"major": false,
		"min_week": int(raw.get("min_week", 1)),
		"weight": int(raw.get("weight", 2)),
		"cooldown": 8,
		"station_life": true,
		"choices": choices,
	}


func _station_life_nums(spec: Dictionary, scale: Dictionary, id: String, cid: String) -> Dictionary:
	var out := {}
	for key in spec:
		var n := _station_life_one(scale, str(spec[key]))
		if n == 0:
			error = "station life: %s %s cost %s is 0" % [id, cid, str(key)]
			return {}
		out[str(key)] = n
	return out


func _station_life_one(scale: Dictionary, name: String) -> int:
	var neg := name.begins_with("-")
	var key := name.trim_prefix("-")
	var n := int(scale.get(key, 0))
	return -n if neg else n


func _station_life_quote(words: String) -> String:
	var open := words.find("\"")
	if open < 0:
		return ""
	var close := words.find("\"", open + 1)
	if close <= open:
		return ""
	return words.substr(open + 1, close - open - 1)


func _index(rows: Array, key: String) -> Dictionary:
	var out := {}
	for row in rows:
		if row is Dictionary and row.has(key):
			out[str(row[key])] = row
	return out
