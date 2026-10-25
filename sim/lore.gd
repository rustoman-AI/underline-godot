class_name Lore
extends RefCounted

## Resident backstories from data/backstories.json. Read marks live in user://lore.cfg so they carry across saves.

const DATA := "res://data/backstories.json"
const PROGRESS := "user://lore.cfg"
const SECTIONS := ["nostalgia", "regret", "pride", "other", "anecdote"]
const TITLES := {
	"nostalgia": "Nostalgia",
	"regret": "Regret",
	"pride": "Pride",
	"other": "Other",
	"anecdote": "Anecdote",
}

static var entries := {}
static var read := {}
static var loaded := false
## Shot runs read pages without touching the player's progress file.
static var dry := false


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f != null:
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary and data.get("people", null) is Dictionary:
			entries = data.people
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS) == OK and cfg.has_section("read"):
		for key in cfg.get_section_keys("read"):
			read[key] = true


static func has(id: String) -> bool:
	load_all()
	return entries.has(id)


static func sections(id: String) -> Array:
	load_all()
	var out: Array = []
	var entry: Dictionary = entries.get(id, {})
	for section in SECTIONS:
		if entry.has(section):
			out.append(section)
	return out


static func text(id: String, section: String) -> String:
	load_all()
	var pack = entries.get(id, {}).get(section, "")
	if pack is Dictionary:
		var lang := "ru" if Copy.ru() else "en"
		if str(pack.get(lang, "")) != "":
			return str(pack[lang])
		return str(pack.get("en", ""))
	return str(pack)


static func is_read(id: String, section: String) -> bool:
	load_all()
	return read.has(_key(id, section))


static func mark(id: String, section: String) -> void:
	load_all()
	if not entries.get(id, {}).has(section) or is_read(id, section):
		return
	read[_key(id, section)] = true
	if dry:
		return
	var cfg := ConfigFile.new()
	for key in read:
		cfg.set_value("read", str(key), true)
	cfg.save(PROGRESS)


static func read_count(id: String) -> int:
	var n := 0
	for section in sections(id):
		if is_read(id, section):
			n += 1
	return n


static func total() -> int:
	load_all()
	var n := 0
	for id in entries:
		n += sections(str(id)).size()
	return n


static func read_total() -> int:
	load_all()
	var n := 0
	for id in entries:
		n += read_count(str(id))
	return n


static func _key(id: String, section: String) -> String:
	return "%s/%s" % [id, section]
