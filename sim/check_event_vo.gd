extends SceneTree

## Event VO (data/vo/event_vo.json): every row points at an event, follow-up choice, check option, crunch leg,
## game-over reason, or one of the later panels (law line, mandate, creed tip, rumor, night encounter, judgment,
## verdict, named-life template). Every audio path that is set loads as a stream; a language with no file stays
## silent instead of failing. Then, per language, how many takes still say what the card shows and so play
## (Voice.EVENT_VO_EXACT), and which do not: those need a new recording. A row whose panel is not in this build
## (obs) is printed as NO CARD and does not fail the check. Named lines compare the unfilled template, so
## {name}, {a} and {room} stay in the match.
##   godot --headless --path . -s res://sim/check_event_vo.gd [-- --rerecord=<file.tsv>]
## --rerecord writes the stale takes as a script for the next VO pass: file name, language, the recorded text and
## the text the card shows now.

const ENDINGS := {
	"time": "Forty weeks. The yard is still yours.", "revolt": "The platform turned.", "hope": "Hope ran out.",
	"collapse": "The stores gave out.", "capital": "The capital was lost.",
}

var bad: PackedStringArray = []


func _initialize() -> void:
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("FAIL catalog: " + catalog.error)
		quit(1)
		return
	var game := Game.new()
	game.setup(catalog, 7, 40)
	var rows: Array = Voice.of_type("event_show")
	if rows.is_empty():
		bad.append("no event_show rows")
	var script: PackedStringArray = ["filename\tlanguage\trecorded_text\tcurrent_text"]
	var nocard: PackedStringArray = []
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		var plays := 0
		var stale: PackedStringArray = []
		for row in rows:
			var shown := _shown(game, row)
			var quiet := shown == "<nocard>"
			if shown == "<missing>":
				continue
			if quiet and not nocard.has(str(row.id)):
				nocard.append(str(row.id))
			var path := str(row.get("audio_" + lang, ""))
			if path == "":
				continue
			if not (ResourceLoader.load(path) is AudioStream):
				bad.append("%s %s: audio does not load (%s)" % [row.id, lang, path])
				continue
			if quiet:
				continue
			var hit := Voice.event_show(str(row.kind), str(row.event), str(row.part), shown)
			if hit.is_empty():
				stale.append(str(row.id))
				script.append("\t".join([path.get_file(), lang.to_upper(), str(row.get(lang, "")), shown]))
			else:
				plays += 1
		print("%s: %d of %d takes match the card and play" % [lang.to_upper(), plays, rows.size()])
		for id in stale:
			print("  %s stale: %s" % [lang, id])
	for id in nocard:
		print("NO CARD %s" % id)
	Copy.set_lang("en")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rerecord="):
			var f := FileAccess.open(arg.substr(11), FileAccess.WRITE)
			f.store_string("\n".join(script) + "\n")
			f.close()
			print("Re-record script: %d takes -> %s" % [script.size() - 1, arg.substr(11)])
	if not Voice.event_show("event", "no_such_event", "body", "x").is_empty():
		bad.append("an unknown event returned a take")
	for line in bad:
		print("FAIL " + line)
	print("EVENT VO CHECK OK" if bad.is_empty() else "EVENT VO CHECK FAILED (%d)" % bad.size())
	quit(0 if bad.is_empty() else 1)


## The text the card shows for this row in the current language, or "<missing>" (and a failure) when the row names
## something the game does not have.
func _shown(game: Game, row: Dictionary) -> String:
	var id := str(row.event)
	var part := str(row.part)
	match str(row.kind):
		"event":
			var ev := game._event_by_id(id)
			if ev.is_empty():
				bad.append("%s: no event %s" % [row.id, id])
				return "<missing>"
			if part == "body":
				return Copy.t(game.line_of(ev, "text"))
			var by = ev.get("by", {})
			var key := part.trim_prefix("after_")
			if not (by is Dictionary) or not by.has(key):
				bad.append("%s: %s has no follow-up text for %s" % [row.id, id, key])
				return "<missing>"
			return Copy.t(str(by[key]))
		"check":
			var ev := game._event_by_id(id)
			if ev.is_empty():
				bad.append("%s: no check %s" % [row.id, id])
				return "<missing>"
			if part == "body":
				return game.line_of(ev, "text")
			for choice in ev.choices:
				for result in ["success", "fail"]:
					if part == "%s_%s" % [choice.id, result]:
						var block: Dictionary = choice.get("success" if result == "success" else "failure", {})
						return game.line_of(block, "text")
			bad.append("%s: %s has no option for %s" % [row.id, id, part])
			return "<missing>"
		"crunch":
			var leg := game.crunch_leg(id)
			if leg.is_empty():
				bad.append("%s: no crunch leg %s" % [row.id, id])
				return "<missing>"
			return Copy.t(str(leg.text))
		"end":
			if not ENDINGS.has(part):
				bad.append("%s: no ending %s" % [row.id, part])
				return "<missing>"
			return Copy.t(str(ENDINGS[part]))
		"law":
			return _copy_key(row, "law.line_text." + id, "law line")
		"mandate":
			var mandate_key := "mandate.pick_body" if id == "pick" else ("mandate.missed" if id == "missed" else "")
			return _copy_key(row, mandate_key, "mandate")
		"creed":
			return _copy_key(row, "creed." + id, "creed tip")
		"rumor":
			return _copy_key(row, "run.rumor." + id, "rumor")
		"encounter":
			return _copy_key(row, "run.encounter." + id, "encounter")
		"judgment":
			for item in game.catalog.epilogues.get("judgments", []):
				if str(item.get("id", "")) == id:
					return game.text_pack(item)
			bad.append("%s: no judgment %s" % [row.id, id])
			return "<missing>"
		"verdict":
			var by_end: Dictionary = game.catalog.epilogues.get("verdicts", {}).get(id, {})
			var pack = by_end.get(part, {})
			if not (pack is Dictionary) or (pack as Dictionary).is_empty():
				bad.append("%s: no verdict %s %s" % [row.id, id, part])
				return "<missing>"
			return game.text_pack(pack)
		"named":
			if id == "birth" or id == "seasoned":
				return _copy_key(row, "named." + id, "named line")
			if id.begins_with("death_"):
				var cause := id.trim_prefix("death_")
				for item in game.catalog.names.get("deaths", []):
					if str(item.get("id", "")) == cause:
						return game.text_pack(item)
				bad.append("%s: no death %s" % [row.id, cause])
				return "<missing>"
			bad.append("%s: no named line %s" % [row.id, id])
			return "<missing>"
		"obs":
			return "<nocard>"
	bad.append("%s: unknown kind %s" % [row.id, row.kind])
	return "<missing>"


## A Texts key in the current language, or "<missing>" when this build has no such string.
func _copy_key(row: Dictionary, key: String, label: String) -> String:
	if key == "" or not Copy.keys.has(key):
		bad.append("%s: no %s %s" % [row.id, label, key])
		return "<missing>"
	return Copy.t(key)
