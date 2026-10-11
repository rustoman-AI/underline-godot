class_name Voice
extends RefCounted

## Voiceover lines in assets/audio/vo, named <base>_<lang>.ogg (see assets/audio/vo/INDEX.md).
## One line plays at a time; a new line cuts the old one off.

const DIR := "res://assets/audio/vo"

static var now_base := ""
static var now_kind := ""
static var now_caption := ""


static func path(base: String) -> String:
	return "%s/%s_%s.ogg" % [DIR, base, "ru" if Copy.ru() else "en"]


static func has(base: String) -> bool:
	return base != "" and ResourceLoader.exists(path(base))


static func story_base(cast_id: String) -> String:
	return "%s_story" % cast_id


static func radio_base(item_id: String) -> String:
	return "radio_%s" % item_id


## Most specific line that exists for an event choice, or "".
static func event_base(event_id: String, choice_id: String) -> String:
	return _first(["event_%s_%s" % [event_id, choice_id], "event_%s" % event_id])


## Line for a confirmed station action (law, rally, pump...), or "".
static func system_base(kind: String, id: String) -> String:
	var tries: Array = []
	if id != "":
		tries.append("system_%s_%s" % [kind, id])
	tries.append("system_%s" % kind)
	return _first(tries)


## Starts a line. Stories and event lines go through the Voice bus, radio through the Radio bus.
static func play(base: String, kind: String, caption: String, delay := 0.0) -> float:
	if not has(base):
		return 0.0
	var bus := "Radio" if kind == "radio" else "Voice"
	var length := Sound.voice_play(path(base), bus, delay)
	if length <= 0.0:
		return 0.0
	now_base = base
	now_kind = kind
	now_caption = caption
	return length


static func stop() -> void:
	Sound.voice_stop()
	now_base = ""
	now_kind = ""
	now_caption = ""


static func playing(base := "") -> bool:
	if not Sound.voice_busy():
		return false
	return base == "" or base == now_base


static func _first(bases: Array) -> String:
	for base in bases:
		if has(str(base)):
			return str(base)
	return ""
