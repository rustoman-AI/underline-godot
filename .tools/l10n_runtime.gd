extends SceneTree

## Runtime language check, headless: plays bot runs with the station UI in one language and words every journal row,
## every morning line and every waiting event the way the UI does, then flags Latin words in Russian, Cyrillic in
## English, raw ids and dashes.
##   godot --headless --path . -s res://.tools/l10n_runtime.gd -- --lang=ru
## Writes build/l10n/runtime_<lang>.json. Settings and saves go to user://l10n_runtime.

const SCRATCH := "user://l10n_runtime"
const STYLES := ["helper", "accept_all", "mixed", "storyteller", "storyteller_climb"]
const SEEDS := 4
const LATIN_OK := ["OK", "VO", "MTA", "Underline"]

var st
var hits := {}
var lines := 0
var latin := RegEx.create_from_string("[A-Za-z][A-Za-z']{2,}")
var cyrillic := RegEx.create_from_string("[А-Яа-яЁё]")
var raw_id := RegEx.create_from_string("\\b(?:[a-z]+_[a-z0-9_]+|st\\d_\\w*)\\b")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lang := "ru"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			lang = str(arg).trim_prefix("--lang=")
	Copy.set_lang(lang)
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	SaveGame.root = SCRATCH + "/saves/"
	PlaytestLog.dir = SCRATCH.path_join("log")
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	var cat: Catalog = st.game.catalog
	for style in STYLES:
		for run_seed in range(1, SEEDS + 1):
			var game := Game.new()
			game.setup(cat, run_seed, 40)
			st.game = game
			var bot := Bot.new()
			bot.audience_style = style
			while game.over == "":
				for ev in game.pending:
					_check("event title", Copy.t(game.line_of(ev, "title")), str(ev.get("id", "")))
					_check("event text", Copy.t(game.line_of(ev, "text")), str(ev.get("id", "")))
					for choice in ev.get("choices", []):
						_check("choice", Copy.t(game.line_of(choice, "label")), "%s/%s" % [ev.get("id", ""), choice.get("id", "")])
						if game.choice_locked(choice):
							_check("lock reason", Copy.t(game.lock_reason(choice)), "%s/%s" % [ev.get("id", ""), choice.get("id", "")])
				for line in st._morning_lines():
					if line.begins_with("INTENT "):
						_check("intent", line.substr(7), line.left(40))
					else:
						_check("morning", st._alert_text(line) if line.begins_with("WARN") else Copy.gloss(line), line.left(40))
				if not game.audience.is_empty():
					_check("audience reason", Copy.t(game.audience_reason()), str(game.audience.faction))
					_check("help reason", Copy.t(game.help_reason()), str(game.audience.faction))
				bot._act(game)
				game.end_week()
			for row in game.journal:
				_check("journal %s" % str(row.get("kind", "")), Copy.t(st._journal_line(row)), str(row.get("event_id", row.get("kind", ""))))
			if game.over != "":
				_check("ending title", game.ending_text(game.ending_id(), "title"), game.ending_id())
	var rows: Array = []
	for key in hits:
		rows.append(hits[key])
	rows.sort_custom(func(a, b): return int(a.count) > int(b.count))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/l10n"))
	var f := FileAccess.open("res://build/l10n/runtime_%s.json" % lang, FileAccess.WRITE)
	f.store_string(JSON.stringify({"lang": lang, "lines": lines, "findings": rows}, "\t"))
	f.close()
	for row in rows.slice(0, 60):
		print("L10N %s x%d [%s] %s: %s" % [row.kind, int(row.count), row.where, row.source, row.text])
	print("L10N DONE %s lines %d distinct findings %d" % [lang, lines, rows.size()])
	quit(0)


func _check(where: String, text: String, source: String) -> void:
	lines += 1
	if text.strip_edges() == "":
		return
	var kind := ""
	if Copy.ru():
		for m in latin.search_all(text):
			if not LATIN_OK.has(m.get_string()):
				kind = "latin_in_ru"
				break
	elif cyrillic.search(text) != null:
		kind = "cyrillic_in_en"
	if kind == "" and raw_id.search(text) != null:
		kind = "raw_id"
	if kind == "" and (text.contains("—") or text.contains("–")):
		kind = "dash"
	if kind == "":
		return
	var key := kind + "|" + where + "|" + text.left(160)
	if not hits.has(key):
		hits[key] = {"kind": kind, "where": where, "source": source, "text": text.left(160), "count": 0}
	hits[key].count += 1
