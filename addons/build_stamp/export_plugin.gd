@tool
extends EditorExportPlugin

## Rewrites the packed build_info.json only. The file in the project stays "dev" for editor runs.
func _get_name() -> String:
	return "underline_build_stamp"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path != "res://data/build_info.json":
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return
	var stamped := BuildInfo.release_build_id(str(data.get("build", "")))
	if stamped == str(data.get("build", "")):
		return
	data["build"] = stamped
	if str(data.get("date", "")) == "":
		var dt := Time.get_date_dict_from_system()
		data["date"] = "%04d-%02d-%02d" % [int(dt.year), int(dt.month), int(dt.day)]
	skip()
	add_file(path, (JSON.stringify(data, "\t") + "\n").to_utf8_buffer(), false)
