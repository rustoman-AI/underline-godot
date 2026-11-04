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


## The playtest log row is dev chrome. A debug run and a playtest export show it. A release export does not.
static func show_log_chrome(debug_build: bool, playtest_feature: bool) -> bool:
	return debug_build or playtest_feature


## A release pack must not ship the editor's "dev" build id. A real id is kept. "dev" and "unknown" become the
## git short hash, or "release" when git is not there.
static func release_build_id(raw: String) -> String:
	var id := raw.strip_edges()
	if id != "" and id != "dev" and id != "unknown":
		return id
	var hash := _git_short()
	return hash if hash != "" else "release"


static func _git_short() -> String:
	var output: Array = []
	var code := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"]), output, true)
	if code != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()


## One line for the menu, credits and the copied report: "Version 0.1.0-playtest1, build 1a2b3c4, 2026-10-12".
static func line() -> String:
	var row := info()
	var text := Copy.t("Version %s, build %s") % [str(row.version), str(row.build)]
	if str(row.date) != "":
		text += ", " + str(row.date)
	return text
