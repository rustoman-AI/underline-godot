extends RefCounted
class_name ArtPack

## Imported textures and fonts. preload() is what puts them in the export.

static var missing := PackedStringArray()
static var _textures: Dictionary = {}
static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}

static func note(path: String) -> void:
	if path == "" or missing.has(path):
		return
	missing.append(path)
	print("Missing art: %s" % path)


static func load_texture(path: String) -> Texture2D:
	var tex: Texture2D = textures().get(path)
	if tex == null and ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res
	if tex != null and tex.get_width() > 0:
		return tex
	note(path)
	return null


static func load_font(path: String, cyrillic: bool = false) -> Font:
	var face: Font = fonts().get(path)
	if face == null and ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Font:
			face = res
	if face == null:
		note(path)
		return null
	if cyrillic and face.get_char_size(0x0410, 32).x <= 1.0:
		note(path)
		return null
	return face


static func has_event_art(event_id: String) -> bool:
	return textures().has("res://assets/events/%s.webp" % event_id)


static func audit() -> void:
	for path in textures().keys():
		load_texture(str(path))
	for path in fonts().keys():
		var cyrillic := str(path).ends_with("Oswald.ttf") or str(path).ends_with("PTMono-Regular.ttf")
		load_font(str(path), cyrillic)


static func textures() -> Dictionary:
	if not _textures.is_empty():
		return _textures
	_textures = {
		"res://assets/rooms/room_hydroponics.webp": preload("res://assets/rooms/room_hydroponics.webp"),
		"res://assets/rooms/room_generator.webp": preload("res://assets/rooms/room_generator.webp"),
		"res://assets/rooms/room_quarters.webp": preload("res://assets/rooms/room_quarters.webp"),
		"res://assets/rooms/room_air_filter.webp": preload("res://assets/rooms/room_air_filter.webp"),
		"res://assets/rooms/room_workshop.webp": preload("res://assets/rooms/room_workshop.webp"),
		"res://assets/rooms/room_infirmary.webp": preload("res://assets/rooms/room_infirmary.webp"),
		"res://assets/rooms/room_meeting_hall.webp": preload("res://assets/rooms/room_meeting_hall.webp"),
		"res://assets/rooms/room_platform.webp": preload("res://assets/rooms/room_platform.webp"),
		"res://assets/rooms/room_radio.webp": preload("res://assets/rooms/room_radio.webp"),
		"res://assets/cells/cell_rock.webp": preload("res://assets/cells/cell_rock.webp"),
		"res://assets/cells/cell_dug.webp": preload("res://assets/cells/cell_dug.webp"),
		"res://assets/cells/cell_construction.webp": preload("res://assets/cells/cell_construction.webp"),
		"res://assets/backdrop_station.webp": preload("res://assets/backdrop_station.webp"),
		"res://assets/hubs/hub_coney_island.webp": preload("res://assets/hubs/hub_coney_island.webp"),
		"res://assets/figures/fig_standing.webp": preload("res://assets/figures/fig_standing.webp"),
		"res://assets/figures/fig_walking.webp": preload("res://assets/figures/fig_walking.webp"),
		"res://assets/figures/fig_working.webp": preload("res://assets/figures/fig_working.webp"),
		"res://assets/figures/fig_carrying.webp": preload("res://assets/figures/fig_carrying.webp"),
		"res://assets/figures/fig_kneeling.webp": preload("res://assets/figures/fig_kneeling.webp"),
		"res://assets/figures/fig_sitting.webp": preload("res://assets/figures/fig_sitting.webp"),
		"res://assets/portraits/portrait_01.webp": preload("res://assets/portraits/portrait_01.webp"),
		"res://assets/portraits/portrait_02.webp": preload("res://assets/portraits/portrait_02.webp"),
		"res://assets/portraits/portrait_03.webp": preload("res://assets/portraits/portrait_03.webp"),
		"res://assets/portraits/portrait_04.webp": preload("res://assets/portraits/portrait_04.webp"),
		"res://assets/portraits/portrait_05.webp": preload("res://assets/portraits/portrait_05.webp"),
		"res://assets/portraits/portrait_06.webp": preload("res://assets/portraits/portrait_06.webp"),
		"res://assets/portraits/portrait_07.webp": preload("res://assets/portraits/portrait_07.webp"),
		"res://assets/portraits/portrait_08.webp": preload("res://assets/portraits/portrait_08.webp"),
		"res://assets/portraits/portrait_09.webp": preload("res://assets/portraits/portrait_09.webp"),
		"res://assets/portraits/portrait_10.webp": preload("res://assets/portraits/portrait_10.webp"),
		"res://assets/portraits/portrait_11.webp": preload("res://assets/portraits/portrait_11.webp"),
		"res://assets/portraits/portrait_12.webp": preload("res://assets/portraits/portrait_12.webp"),
		"res://assets/portraits/portrait_13.webp": preload("res://assets/portraits/portrait_13.webp"),
		"res://assets/portraits/portrait_14.webp": preload("res://assets/portraits/portrait_14.webp"),
		"res://assets/portraits/portrait_15.webp": preload("res://assets/portraits/portrait_15.webp"),
		"res://assets/portraits/portrait_16.webp": preload("res://assets/portraits/portrait_16.webp"),
		"res://assets/events/flood.webp": preload("res://assets/events/flood.webp"),
		"res://assets/events/headphones.webp": preload("res://assets/events/headphones.webp"),
		"res://assets/events/letter.webp": preload("res://assets/events/letter.webp"),
		"res://assets/events/preacher.webp": preload("res://assets/events/preacher.webp"),
		"res://assets/events/rat.webp": preload("res://assets/events/rat.webp"),
		"res://assets/events/refugees.webp": preload("res://assets/events/refugees.webp"),
		"res://assets/events/toll.webp": preload("res://assets/events/toll.webp"),
		"res://assets/events/vote.webp": preload("res://assets/events/vote.webp"),
	}
	return _textures


static func adopt_icons() -> void:
	var src := "res://incoming-art/icons"
	if DirAccess.open(src) == null:
		return
	_copy_tree(src, "res://assets/icons")


static func icon_texture(kind: String, px: float = 64.0) -> Texture2D:
	var small := px <= 32.0
	var key := kind + ("#24" if small else "")
	if _icons.has(key):
		var cached = _icons[key]
		return cached if cached is Texture2D else null
	var found: Texture2D = null
	var names := _icon_names(kind)
	if small:
		for name in names:
			found = _load_icon(name + "_24")
			if found != null:
				break
	if found == null:
		for name in names:
			found = _load_icon(name)
			if found != null:
				break
	_icons[key] = found if found != null else false
	return found


static func _icon_names(kind: String) -> PackedStringArray:
	match kind:
		"lock":
			return PackedStringArray(["locked", "lock"])
		"burn":
			return PackedStringArray(["burn_salvage", "burn"])
		"clock":
			return PackedStringArray(["week", "clock"])
		"buy":
			return PackedStringArray(["propaganda", "buy"])
		"demand":
			return PackedStringArray(["ultimatum", "demand"])
		"secure", "move":
			return PackedStringArray(["squad", kind])
		"expedition":
			return PackedStringArray(["artifact", "expedition"])
		"dig":
			return PackedStringArray(["workshop", "dig"])
		"hold":
			return PackedStringArray(["warning", "hold"])
		_:
			return PackedStringArray([kind])


static func _load_icon(name: String) -> Texture2D:
	var folders := ["", "resources/", "actions/", "rooms/", "status/", "map/", "factions/"]
	for folder in folders:
		for ext in ["webp", "png"]:
			var path := "res://assets/icons/%s%s.%s" % [folder, name, ext]
			if not ResourceLoader.exists(path):
				continue
			var tex := load_texture(path)
			if tex == null:
				continue
			return _with_mipmaps(tex)
	return null


static func _with_mipmaps(tex: Texture2D) -> Texture2D:
	var image := tex.get_image()
	if image == null:
		return tex
	if image.get_width() > 1 and image.get_height() > 1:
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _copy_tree(src: String, dst: String) -> void:
	var dir := DirAccess.open(src)
	if dir == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst))
	for name in dir.get_directories():
		if str(name).begins_with("."):
			continue
		_copy_tree(src.path_join(str(name)), dst.path_join(str(name)))
	for name in dir.get_files():
		if str(name).begins_with("."):
			continue
		var from := ProjectSettings.globalize_path(src.path_join(str(name)))
		var to := ProjectSettings.globalize_path(dst.path_join(str(name)))
		DirAccess.copy_absolute(from, to)


static func fonts() -> Dictionary:
	if not _fonts.is_empty():
		return _fonts
	_fonts = {
		"res://assets/fonts/CourierPrime-Regular.ttf": preload("res://assets/fonts/CourierPrime-Regular.ttf"),
		"res://assets/fonts/BigShouldersDisplay.ttf": preload("res://assets/fonts/BigShouldersDisplay.ttf"),
		"res://assets/fonts/BigShouldersDisplay-700.woff2": preload("res://assets/fonts/BigShouldersDisplay-700.woff2"),
		"res://assets/fonts/Oswald.ttf": preload("res://assets/fonts/Oswald.ttf"),
		"res://assets/fonts/PTMono-Regular.ttf": preload("res://assets/fonts/PTMono-Regular.ttf"),
	}
	return _fonts
