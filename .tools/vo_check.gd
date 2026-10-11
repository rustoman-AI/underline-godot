extends SceneTree

## Voiceover data check: every line resolves in both languages, missing audio falls back to text,
## each system line's condition is raised in bot runs, and each event line names a real event.


func _init() -> void:
	var problems: Array = []
	var catalog := Catalog.new()
	catalog.load_all()
	var by_type := {}
	Voice.load_all()
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		var voiced := 0
		var silent := 0
		for id in Voice.lines:
			var row: Dictionary = Voice.lines[id]
			if Voice.text(row) == "":
				problems.append("%s no %s text" % [id, lang])
			if Voice.has_audio(row):
				voiced += 1
			else:
				silent += 1
			by_type[str(row.get("type", ""))] = int(by_type.get(str(row.get("type", "")), 0)) + (1 if lang == "en" else 0)
		print("%s: %d voiced, %d text only" % [lang, voiced, silent])
	Copy.set_lang("en")
	print("types %s" % str(by_type))
	var events := {}
	for e in catalog.events:
		events[str(e.get("id", ""))] = true
	for row in Voice.of_type("event"):
		if not events.has(str(row.get("event", ""))):
			problems.append("event line %s: no event %s" % [row.id, row.get("event", "")])
	var raised := {}
	for run_seed in [1, 2, 3, 4, 5]:
		for profile in ["careful", "expander", "follower"]:
			var bot := Bot.new()
			bot.profile = profile
			var game := Game.new()
			game.setup(catalog, run_seed, 40)
			var guard := 0
			while game.over == "" and guard < 42:
				guard += 1
				bot._act(game)
				game.end_week()
				for cue in game.vo_cues:
					raised[str(cue)] = int(raised.get(str(cue), 0)) + 1
				game.vo_cues.clear()
	print("cues raised over 15 runs: %s" % str(raised))
	for row in Voice.of_type("system"):
		if not raised.has(str(row.get("condition", ""))):
			problems.append("system line %s never raised" % row.id)
	var item := Radio.next(1.0)
	print("radio under threat: %s (%s)" % [item.get("id", ""), item.get("mood", "")])
	print("VO CHECK " + ("OK" if problems.is_empty() else "FAIL\n  " + "\n  ".join(problems)))
	quit(0)
