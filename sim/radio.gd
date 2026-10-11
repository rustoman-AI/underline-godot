class_name Radio
extends RefCounted

## Underground cable radio. Items come from data/radio.json in a shuffled bag, so none repeats until all have played.
## An item is voiced when assets/audio/vo/radio_<id>_<lang>.ogg exists.

const DATA := "res://data/radio.json"
const NO_TRANSCRIPT := "A bulletin crackles down the cable."

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
	var out := str(pack)
	if pack is Dictionary:
		var lang := "ru" if Copy.ru() else "en"
		out = str(pack.get(lang, ""))
		if out == "":
			out = str(pack.get("en", ""))
	if out == "":
		return Copy.t(NO_TRANSCRIPT)
	return out


static func voice_base(item: Dictionary) -> String:
	return Voice.radio_base(str(item.get("id", "")))
