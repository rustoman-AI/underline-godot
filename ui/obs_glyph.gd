class_name ObsGlyph
extends RefCounted

## P87 ink glyph. Art is an alpha mask tinted to the host label colour.
## A missing texture is a ring and a letter, never a grey box.

const INK := Color("f4efe4")
const MUTED := Color("d9cbb4")


static func texture(kind: String, id: String, px: int) -> Texture2D:
	var name := _file(kind, id)
	var found := _load(name, px)
	if found != null:
		return _mask(found, px)
	return _ring(id, px)


static func apply_button(button: Button, kind: String, id: String, ink: Color, muted: Color) -> void:
	var tex := texture(kind, id, 16)
	button.icon = tex
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 16)
	button.add_theme_constant_override("icon_max_height", 16)
	button.add_theme_color_override("icon_normal_color", ink)
	button.add_theme_color_override("icon_hover_color", ink)
	button.add_theme_color_override("icon_pressed_color", ink)
	button.add_theme_color_override("icon_focus_color", ink)
	button.add_theme_color_override("icon_disabled_color", muted)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := button.get_theme_stylebox(state)
		if box == null:
			continue
		var copy := box.duplicate()
		if copy is StyleBoxFlat:
			copy.content_margin_left = maxf(float(copy.content_margin_left), 34.0)
			button.add_theme_stylebox_override(state, copy)


static func rect(parent: Node, kind: String, id: String, px: int, tint: Color) -> TextureRect:
	var face := TextureRect.new()
	face.texture = texture(kind, id, px)
	face.custom_minimum_size = Vector2(px, px)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.modulate = tint
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(face)
	return face


static func _file(kind: String, id: String) -> String:
	return "obs_mark_%s" % id if kind == "mark" else "obs_kit_%s" % id


static func _load(name: String, px: int) -> Texture2D:
	var suffixes: PackedStringArray = PackedStringArray()
	if px <= 24:
		suffixes = PackedStringArray(["_24", "_32", ""])
	elif px <= 32:
		suffixes = PackedStringArray(["_32", "_24", ""])
	elif px <= 48:
		suffixes = PackedStringArray(["_48", "_64", ""])
	else:
		suffixes = PackedStringArray(["_64", "_48", ""])
	for suffix in suffixes:
		var path := "res://assets/icons/status/%s%s.png" % [name, suffix]
		if ResourceLoader.exists(path):
			var loaded: Texture2D = load(path)
			if loaded != null:
				return loaded
		if FileAccess.file_exists(path):
			var image := Image.new()
			if image.load(path) == OK:
				return ImageTexture.create_from_image(image)
	return null


static func _mask(src: Texture2D, px: int) -> Texture2D:
	var image := src.get_image()
	if image == null:
		return src
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != px or image.get_height() != px:
		image.resize(px, px, Image.INTERPOLATE_LANCZOS)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1, 1, 1, c.a))
	return ImageTexture.create_from_image(image)


const _BITS := {
	"A": "01110,10001,11111,10001,10001",
	"B": "11110,10001,11110,10001,11110",
	"C": "01111,10000,10000,10000,01111",
	"D": "11110,10001,10001,10001,11110",
	"F": "11111,10000,11110,10000,10000",
	"L": "10000,10000,10000,10000,11111",
	"O": "01110,10001,10001,10001,01110",
	"R": "11110,10001,11110,10100,10010",
	"S": "01111,10000,01110,00001,11110",
	"W": "10001,10001,10101,11011,10001",
	"Б": "11110,10000,11110,10001,11110",
	"Ж": "10101,01110,00100,01110,10101",
	"К": "10010,10100,11000,10100,10010",
	"М": "10001,11011,10101,10001,10001",
	"Н": "10001,10001,11111,10001,10001",
	"О": "01110,10001,10001,10001,01110",
	"П": "11111,10001,10001,10001,10001",
	"Р": "11110,10001,11110,10000,10000",
	"С": "01111,10000,10000,10000,01111",
	"Ш": "10101,10101,10101,10101,11111",
}


static func _ring(id: String, px: int) -> Texture2D:
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var mid := float(px) * 0.5
	var rad := mid - 1.0
	var thick := maxf(1.0, float(px) / 12.0)
	for y in px:
		for x in px:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(mid, mid))
			if d <= rad and d >= rad - thick:
				image.set_pixel(x, y, Color(1, 1, 1, 1))
	_stamp(image, _letter(id))
	return ImageTexture.create_from_image(image)


static func _stamp(image: Image, letter: String) -> void:
	if not _BITS.has(letter):
		return
	var rows: PackedStringArray = str(_BITS[letter]).split(",")
	var w := image.get_width()
	var h := image.get_height()
	var gw := 5
	var gh := rows.size()
	var scale := maxi(1, mini(w / 8, h / 8))
	var ox := (w - gw * scale) / 2
	var oy := (h - gh * scale) / 2
	for ry in gh:
		var bits := rows[ry]
		for rx in mini(gw, bits.length()):
			if bits.substr(rx, 1) != "1":
				continue
			for dy in scale:
				for dx in scale:
					var x := ox + rx * scale + dx
					var y := oy + ry * scale + dy
					if x >= 0 and y >= 0 and x < w and y < h:
						image.set_pixel(x, y, Color(1, 1, 1, 1))


static func _letter(id: String) -> String:
	var key := "obs.mark.%s.name" % id
	var named := Copy.t(key)
	if named == key:
		named = Copy.t("obs.kit.%s.name" % id)
	named = named.strip_edges()
	if named == "":
		return ""
	return named.substr(0, 1)
