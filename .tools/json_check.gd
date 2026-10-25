extends SceneTree


func _init() -> void:
	for file in ["ru.json", "backstories.json", "vo/underline_vo.json", "vo/cable_radio.json"]:
		var text := FileAccess.get_file_as_string("res://data/" + file)
		var json := JSON.new()
		var err := json.parse(text)
		print("%s err %d line %d keys %d" % [file, err, json.get_error_line(), (json.data as Dictionary).size() if err == OK else 0])
	quit(0)
