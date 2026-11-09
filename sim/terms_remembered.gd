class_name TermsRemembered
extends RefCounted

## P98 Terms Remembered. Presentation only.
## The offered card already carries follow_memory from the unchanged follow scheduler.
## Labels and the one accepted-action sentence are read from that pair. Choice arrays,
## costs, effects, weights, schedules, and RNG stay untouched. Schema stays 25.
## English in data/terms_remembered.json is interim spec copy, not an approved Texts pack.
## A locale missing any of the six strings for a context keeps the existing labels.

const PACK := "res://data/terms_remembered.json"
const CARDS := {
	"loan_next": ["borrow", "decline"],
	"toll_next": ["pay", "goods", "detour"],
	"knock_next": ["answer", "cut", "fill"],
}
const CHOICES := {
	"loan_next": ["repay", "stall", "default"],
	"toll_next": ["sign", "route", "bar"],
	"knock_next": ["feed", "chapel", "back"],
}

## Presentation switch for the before/after card. Default on. Not saved. Not a balance flag.
static var enabled := true
static var _rows: Dictionary = {}
static var _loaded := false
static var _warned := {}
## Tests only. A non-empty dict replaces the pack for the next lookup. Empty uses the file.
static var rows_override: Dictionary = {}


static func key_for(event_id: String, memory: String, choice_id: String, part: String) -> String:
	return "terms.%s.%s.%s.%s" % [event_id, memory, choice_id, part]


static func all_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for event_id in ["loan_next", "toll_next", "knock_next"]:
		for memory in CARDS[event_id]:
			for choice_id in CHOICES[event_id]:
				out.append(key_for(event_id, str(memory), str(choice_id), "label"))
				out.append(key_for(event_id, str(memory), str(choice_id), "result"))
	return out


static func known(event_id: String, memory: String) -> bool:
	var memories = CARDS.get(event_id, [])
	return memories is Array and memories.has(memory)


static func load_rows() -> Dictionary:
	if not rows_override.is_empty():
		return rows_override
	if _loaded:
		return _rows
	_loaded = true
	_rows = {}
	if not FileAccess.file_exists(PACK):
		return _rows
	var data = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	if data is Dictionary and data.get("by_key", {}) is Dictionary:
		_rows = data.by_key
	return _rows


static func set_rows_for_test(rows: Dictionary) -> void:
	rows_override = rows
	_warned = {}


static func clear_rows_for_test() -> void:
	rows_override = {}
	_warned = {}


## Keys in this context whose active-locale string is missing. Empty when the context is unknown.
static func missing(event_id: String, memory: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not known(event_id, memory):
		return out
	var lang := _lang()
	for choice_id in CHOICES[event_id]:
		for part in ["label", "result"]:
			var key := key_for(event_id, memory, str(choice_id), part)
			if _cell(key, lang) == "":
				out.append("%s:%s" % [key, lang])
	return out


static func context_ready(event_id: String, memory: String) -> bool:
	return known(event_id, memory) and missing(event_id, memory).is_empty()


## The string the button should show before Copy.t. Fallback is the canonical label.
## Observer mirror buttons keep their authored label.
static func visible_label(game, ev: Dictionary, choice: Dictionary) -> String:
	var canonical := _canonical_label(game, choice)
	if not enabled or bool(choice.get("obs_line", false)):
		return canonical
	var event_id := str(ev.get("id", ""))
	var memory := str(ev.get("follow_memory", ""))
	var choice_id := str(choice.get("id", ""))
	if not known(event_id, memory) or not _choice_ok(event_id, choice_id):
		return canonical
	if not context_ready(event_id, memory):
		_warn(event_id, memory)
		return canonical
	return _cell(key_for(event_id, memory, choice_id, "label"), _lang())


## Accepted-action sentence, or "" when this click should stay quiet.
## A mirror acknowledges the canonical choice and does not replace the mirror's label.
static func response_for(ev: Dictionary, choice: Dictionary) -> String:
	if not enabled:
		return ""
	var event_id := str(ev.get("id", ""))
	var memory := str(ev.get("follow_memory", ""))
	var choice_id := action_id(choice)
	if not known(event_id, memory) or not _choice_ok(event_id, choice_id):
		return ""
	if not context_ready(event_id, memory):
		_warn(event_id, memory)
		return ""
	return _cell(key_for(event_id, memory, choice_id, "result"), _lang())


static func action_id(choice: Dictionary) -> String:
	if bool(choice.get("obs_line", false)):
		return str(choice.get("mirror", ""))
	return str(choice.get("id", ""))


static func _choice_ok(event_id: String, choice_id: String) -> bool:
	var ids = CHOICES.get(event_id, [])
	return ids is Array and ids.has(choice_id)


static func _canonical_label(game, choice: Dictionary) -> String:
	if game != null and game.has_method("line_of"):
		return str(game.line_of(choice, "label"))
	var pack = choice.get("label", "")
	if pack is Dictionary:
		return str(pack.get("en", ""))
	return str(pack)


static func _lang() -> String:
	return "ru" if Copy.ru() else "en"


static func _cell(key: String, lang: String) -> String:
	var row = load_rows().get(key, null)
	if not (row is Dictionary):
		return ""
	var text := str(row.get(lang, "")).strip_edges()
	if text == "" or text == key or text.begins_with("terms."):
		return ""
	return text


static func _warn(event_id: String, memory: String) -> void:
	var gaps := missing(event_id, memory)
	if gaps.is_empty():
		return
	var token := "%s|%s|%s" % [event_id, memory, _lang()]
	if _warned.has(token):
		return
	_warned[token] = true
	push_warning("terms: %s/%s missing %s; original labels" % [event_id, memory, ", ".join(gaps)])
