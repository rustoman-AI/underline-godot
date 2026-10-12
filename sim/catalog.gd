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
## Truth fragments by id (data/truth.json): title, hint and text, each {en, ru}.
var truth: Dictionary = {}
var coney: Dictionary = {}
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
	leader_ru = add_events(_obj("events_leaders.json"), base_ru)
	story_ru = add_events(_obj("events_story.json"), base_ru)
	truth = _index(_obj("truth.json").get("fragments", []), "id")
	check_events = _obj("events_checks.json")
	coney = _obj("characters_coney.json")
	residents = _arr("residents.json")
	names = _obj("names.json")
	grid = _obj("start_grid.json")
	communities = _obj("station_communities.json")
	communities_en = _obj("station_communities_en.json")
	geo = _obj("map_geo.json")
	return error == ""


## Leader consequence and story events (data/events_leaders.json, data/events_story.json) join the event list.
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


func _index(rows: Array, key: String) -> Dictionary:
	var out := {}
	for row in rows:
		if row is Dictionary and row.has(key):
			out[str(row[key])] = row
	return out
