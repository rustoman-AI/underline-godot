extends SceneTree

## Installs incoming-art/residents_portraits_v2/portrait_17..28.png (1024) as assets/portraits/*.webp at
## 512x512, lossless like portrait_01..16. The PNG sources stay where they are.
##   godot --headless --path . -s res://.tools/install_portraits_v2.gd


func _init() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var failed := false
	for i in range(17, 29):
		var name := "portrait_%02d" % i
		var img := Image.load_from_file(root + "incoming-art/residents_portraits_v2/%s.png" % name)
		if img == null or img.is_empty():
			print("FAIL ", name)
			failed = true
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		var out := root + "assets/portraits/%s.webp" % name
		var err := img.save_webp(out, false)
		print("%s %dx%d err %d %d KB" % [name, img.get_width(), img.get_height(), err, FileAccess.get_file_as_bytes(out).size() / 1024])
		failed = failed or err != OK
	quit(1 if failed else 0)
