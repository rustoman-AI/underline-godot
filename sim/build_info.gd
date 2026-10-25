class_name BuildInfo
extends RefCounted

## Version, git build and date of this build from data/build_info.json. .tools/export_playtest.ps1 writes the
## real build and date at export; a run from the editor shows the committed "dev" values.

const PATH := "res://data/build_info.json"

static var _info: Dictionary = {}


static func info() -> Dictionary:
	if not _info.is_empty():
		return _info
	var data = null
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		data = {}
	_info = {
		"version": str(data.get("version", "unknown")),
		"build": str(data.get("build", "unknown")),
		"date": str(data.get("date", "")),
	}
	return _info


static func version() -> String:
	return str(info().version)


static func build() -> String:
	return str(info().build)


## One line for the menu, credits and the copied report: "Version 0.1.0-playtest1, build 1a2b3c4, 2026-10-12".
static func line() -> String:
	var row := info()
	var text := Copy.t("Version %s, build %s") % [str(row.version), str(row.build)]
	if str(row.date) != "":
		text += ", " + str(row.date)
	return text
