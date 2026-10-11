class_name Voice
extends RefCounted

## Voiceover lines from every JSON file in data/vo (format in data/vo/underline_vo.json).
## A line carries en/ru text and an audio path per language; when the current language's file is missing
## the line still has its text and simply does not play. One line plays at a time; a new one fades the old out.

const DIR := "res://data/vo"

static var lines := {}
static var loaded := false
static var now_id := ""
static var now_kind := ""
static var now_caption := ""
static var now_text := ""
static var now_length := 0.0
static var now_started := 0


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var files := Array(DirAccess.get_files_at(DIR))
	files.sort()
	for file in files:
		if not str(file).ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(str(file))))
		if not data is Dictionary or not data.get("lines", null) is Array:
			continue
		for row in data.lines:
			if row is Dictionary and str(row.get("id", "")) != "":
				lines[str(row.id)] = row


static func line(id: String) -> Dictionary:
	load_all()
	return lines.get(id, {})


static func of_type(type: String) -> Array:
	load_all()
	var out: Array = []
	for id in lines:
		if str(lines[id].get("type", "")) == type:
			out.append(lines[id])
	return out


static func story(cast_id: String) -> Dictionary:
	return _find("story", "cast", cast_id)


## Resolve line for an event; a line naming the exact choice wins over one for the whole event.
static func event_line(event_id: String, choice_id: String) -> Dictionary:
	var whole := {}
	for row in of_type("event"):
		if str(row.get("event", "")) != event_id:
			continue
		var choice := str(row.get("choice", ""))
		if choice == choice_id and choice != "":
			return row
		if choice == "" and whole.is_empty():
			whole = row
	return whole


static func condition(name: String) -> Dictionary:
	return _find("system", "condition", name)


static func text(row: Dictionary) -> String:
	var out := str(row.get("ru" if Copy.ru() else "en", ""))
	if out == "":
		out = str(row.get("en", ""))
	return out


## Audio file for the current language, or "" when it has not been recorded.
## The VO index spreadsheet names event files <id>_resolve_resolve_<lang>.ogg, so that spelling is accepted too.
static func audio(row: Dictionary) -> String:
	var path := str(row.get("audio_ru" if Copy.ru() else "audio_en", ""))
	if path == "":
		return ""
	if ResourceLoader.exists(path):
		return path
	var doubled := path.replace("_resolve_", "_resolve_resolve_")
	if doubled != path and ResourceLoader.exists(doubled):
		return doubled
	return ""


const LEADER_KEYS := ["first_contact", "band_hostile", "band_cold", "band_wary", "band_useful", "band_pact",
	"territory", "trade", "pitch", "accepted", "declined"]


## A leader's recorded line: assets/audio/vo/lead_<faction>_<key>_<lang>.ogg (key from LEADER_KEYS).
static func leader_file(faction: String, key: String, lang: String) -> String:
	return "res://assets/audio/vo/lead_%s_%s_%s.ogg" % [faction, key, lang]


## The same line as a row for play(); the text is already on the card, so the row carries none.
static func leader_row(faction: String, key: String) -> Dictionary:
	return {
		"id": "lead_%s_%s" % [faction, key],
		"type": "leader",
		"audio_en": leader_file(faction, key, "en"),
		"audio_ru": leader_file(faction, key, "ru"),
	}


static func has_audio(row: Dictionary) -> bool:
	return audio(row) != ""


## Starts a line: radio through the Radio bus, everything else through Voice. Returns 0 when there is no audio.
static func play(row: Dictionary, caption: String, delay := 0.0) -> float:
	var path := audio(row)
	if path == "":
		return 0.0
	var kind := str(row.get("type", ""))
	var length := Sound.voice_play(path, "Radio" if kind == "radio" else "Voice", delay)
	if length <= 0.0:
		return 0.0
	now_id = str(row.get("id", ""))
	now_kind = kind
	now_caption = caption
	now_text = text(row)
	now_length = length
	now_started = Time.get_ticks_msec() + int(delay * 1000.0)
	return length


static func stop() -> void:
	Sound.voice_stop()
	_clear()


## Fades the current line out instead of cutting it, for a panel that closes under it.
static func fade(seconds := 0.6) -> void:
	Sound.voice_fade(seconds)
	_clear()


static func playing(id := "") -> bool:
	if not Sound.voice_busy():
		return false
	return id == "" or id == now_id


## 0..1 through the current line, for timing subtitles.
static func progress() -> float:
	if now_length <= 0.0:
		return 0.0
	return clampf(float(Time.get_ticks_msec() - now_started) / (now_length * 1000.0), 0.0, 1.0)


static func _clear() -> void:
	now_id = ""
	now_kind = ""
	now_caption = ""
	now_text = ""
	now_length = 0.0


static func _find(type: String, key: String, value: String) -> Dictionary:
	if value == "":
		return {}
	for row in of_type(type):
		if str(row.get(key, "")) == value:
			return row
	return {}
