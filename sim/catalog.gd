class_name Catalog
extends RefCounted

var balance: Dictionary = {}
var rooms: Dictionary = {}
var laws: Dictionary = {}
var factions: Dictionary = {}
var stations: Array = []
var tunnels: Array = []
var events: Array = []
var residents: Array = []
var names: Dictionary = {}
var grid: Dictionary = {}
var error: String = ""


func load_all() -> bool:
	balance = _obj("balance.json")
	rooms = _index(_arr("rooms.json"), "id")
	laws = _index(_arr("laws.json"), "id")
	factions = _obj("factions.json")
	stations = _arr("stations.json")
	tunnels = _arr("tunnels.json")
	events = _arr("events.json")
	residents = _arr("residents.json")
	names = _obj("names.json")
	grid = _obj("start_grid.json")
	return error == ""


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
