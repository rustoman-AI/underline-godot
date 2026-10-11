class_name Radio
extends RefCounted

## Underground cable radio. Items come from data/radio.json in a shuffled bag, so none repeats until all have played.

const DATA := "res://data/radio.json"
const VOICE_DIR := "res://assets/voice/radio"

static var items: Array = []
static var bag: Array = []
static var loaded := false
static var rng := RandomNumberGenerator.new()


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	rng.randomize()
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary and data.get("items", null) is Array:
		items = data.items


static func next() -> Dictionary:
	load_all()
	if items.is_empty():
		return {}
	if bag.is_empty():
		bag = range(items.size())
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var keep = bag[i]
			bag[i] = bag[j]
			bag[j] = keep
	return items[int(bag.pop_back())]


static func by_id(id: String) -> Dictionary:
	load_all()
	for item in items:
		if str(item.get("id", "")) == id:
			return item
	return {}


static func text(item: Dictionary) -> String:
	var pack = item.get("text", "")
	if pack is Dictionary:
		var lang := "ru" if Copy.ru() else "en"
		if str(pack.get(lang, "")) != "":
			return str(pack[lang])
		return str(pack.get("en", ""))
	return str(pack)


static func voice_path(item: Dictionary) -> String:
	var lang := "ru" if Copy.ru() else "en"
	var pack = item.get("voice", {})
	if pack is Dictionary and str(pack.get(lang, "")) != "":
		return str(pack[lang])
	return "%s/%s_%s.ogg" % [VOICE_DIR, str(item.get("id", "")), lang]


static func wait_seconds() -> float:
	Settings.load_file()
	load_all()
	return rng.randf_range(Settings.radio_min, maxf(Settings.radio_min, Settings.radio_max))
