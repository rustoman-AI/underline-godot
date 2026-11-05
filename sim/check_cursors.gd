extends SceneTree

## R23 brass cursors. Both shapes are handed to Input.set_custom_mouse_cursor,
## 1x under 125% and @2x from 125% up.
##   godot --headless --path . -s res://sim/check_cursors.gd


func _init() -> void:
	var failed := false
	if not _sizes():
		failed = true
	if not _choice():
		failed = true
	if not _apply():
		failed = true
	if not _wired():
		failed = true
	if failed:
		print("CURSORS FAIL")
		quit(1)
		return
	print("CURSORS OK")
	quit(0)


func _sizes() -> bool:
	var bad: PackedStringArray = []
	var expect := {
		"res://assets/ui/cursor_arrow.png": Vector2i(32, 32),
		"res://assets/ui/cursor_arrow@2x.png": Vector2i(64, 64),
		"res://assets/ui/cursor_hand.png": Vector2i(32, 32),
		"res://assets/ui/cursor_hand@2x.png": Vector2i(64, 64),
	}
	for path in expect:
		var tex: Texture2D = load(str(path))
		var want: Vector2i = expect[path]
		if tex == null or tex.get_width() != want.x or tex.get_height() != want.y:
			var got := "missing" if tex == null else "%sx%s" % [tex.get_width(), tex.get_height()]
			bad.append("%s is %s" % [path, got])
	if bad.is_empty():
		print("Sizes: ok")
		return true
	print("Sizes: FAIL ", ", ".join(bad))
	return false


func _choice() -> bool:
	var bad: PackedStringArray = []
	for scale in [0.9, 1.0, 1.2]:
		_expect_pair(Cursors.shapes_for(scale), false, scale, bad)
	for scale in [1.25, 1.35, 1.5, 2.0]:
		_expect_pair(Cursors.shapes_for(scale), true, scale, bad)
	if bad.is_empty():
		print("Choice: ok")
		return true
	print("Choice: FAIL ", ", ".join(bad))
	return false


func _expect_pair(chosen: Dictionary, hi: bool, scale: float, bad: PackedStringArray) -> void:
	var arrow: Dictionary = chosen.get(Input.CURSOR_ARROW, {})
	var hand: Dictionary = chosen.get(Input.CURSOR_POINTING_HAND, {})
	var arrow_hot := Vector2(4, 4) if hi else Vector2(2, 2)
	var hand_hot := Vector2(20, 4) if hi else Vector2(10, 2)
	var arrow_name := "cursor_arrow@2x.png" if hi else "cursor_arrow.png"
	var hand_name := "cursor_hand@2x.png" if hi else "cursor_hand.png"
	var side := 64 if hi else 32
	if not _row_ok(arrow, arrow_hot, arrow_name, side):
		bad.append("arrow @ %.2f %s" % [scale, arrow])
	if not _row_ok(hand, hand_hot, hand_name, side):
		bad.append("hand @ %.2f %s" % [scale, hand])


func _row_ok(row: Dictionary, hot: Vector2, name: String, side: int) -> bool:
	var tex: Texture2D = row.get("texture")
	if tex == null or tex.get_width() != side or tex.get_height() != side:
		return false
	if not (row.get("hotspot", Vector2.ZERO) as Vector2).is_equal_approx(hot):
		return false
	return str(row.get("path", "")).ends_with(name)


func _apply() -> bool:
	var bad: PackedStringArray = []
	for scale in [1.0, 1.25]:
		var chosen := Cursors.apply_at(scale)
		for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
			var row: Dictionary = chosen.get(shape, {})
			var label := "arrow" if shape == Input.CURSOR_ARROW else "hand"
			if not bool(row.get("applied", false)):
				bad.append("%s did not apply at %.2f" % [label, scale])
				continue
			var tex: Texture2D = row["texture"]
			var hot: Vector2 = row["hotspot"]
			var img := tex.get_image()
			var ink := img.get_pixel(int(hot.x), int(hot.y)) if img != null else Color(0, 0, 0, 0)
			if img == null or ink.a < 0.5:
				bad.append("%s hotspot %s is empty at %.2f" % [label, hot, scale])
				continue
			print("SET %s %s %dx%d hotspot %s alpha %.2f" % [label, row["path"], tex.get_width(), tex.get_height(), hot, ink.a])
	if bad.is_empty():
		print("Apply: ok")
		return true
	print("Apply: FAIL ", ", ".join(bad))
	return false


func _wired() -> bool:
	var src := FileAccess.get_file_as_string("res://ui/station.gd")
	var cursors := FileAccess.get_file_as_string("res://ui/cursors.gd")
	var bad: PackedStringArray = []
	if src.find("func _apply_cursors()") < 0 or src.find("Cursors.apply(get_window())") < 0:
		bad.append("station helper")
	if cursors.find("Input.set_custom_mouse_cursor") < 0:
		bad.append("set_custom_mouse_cursor")
	if cursors.find("Input.CURSOR_ARROW") < 0 or cursors.find("Input.CURSOR_POINTING_HAND") < 0:
		bad.append("shapes")
	for fn in ["func _ready()", "func _pick_window(full: bool)", "func _pick_scale(scale: float)", "func _pick_auto_scale()", "func _rescale()"]:
		var at := src.find(fn)
		var nxt := src.find("\nfunc ", at + 1)
		if at < 0 or nxt < at or src.substr(at, nxt - at).find("_apply_cursors()") < 0:
			bad.append(fn)
	if bad.is_empty():
		print("Wired: ok")
		return true
	print("Wired: FAIL ", ", ".join(bad))
	return false
