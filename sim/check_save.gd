extends SceneTree

## Headless save checks: legacy migration, rejection without mutation, resume determinism, slot recovery.
## Writes only under user://check_save_<pid>/ and never touches the player's slots.
##   godot --headless --path . -s res://sim/check_save.gd

const SEEDS := [1, 2]
const WEEKS := 40
const AUDIENCE_KEYS := ["standing", "standing_memory", "audience", "audience_last", "audience_due", "audience_deals"]

var catalog: Catalog
var failed := false


func _init() -> void:
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	var player_slots := _slot_stamp()
	SaveGame.root = "user://check_save_%d" % OS.get_process_id()
	_wipe(SaveGame.root)
	_legacy()
	_rejects()
	_story_saves()
	_shared_catalog()
	_resume()
	_slots()
	_wipe(SaveGame.root)
	SaveGame.root = "user://"
	_expect(_slot_stamp() == player_slots, "Player slots untouched", "player slots changed")
	if failed:
		print("SAVE CHECK FAILED")
		quit(1)
	else:
		print("SAVE CHECK OK")
		quit(0)


func _expect(ok: bool, good: String, bad: String) -> void:
	if ok:
		print(good + ": ok")
	else:
		failed = true
		print("FAIL " + bad)


func _game(run_seed: int) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, WEEKS)
	return game


## A run holding audience state that a legacy save must not inherit.
func _busy_game() -> Game:
	var game := _game(2)
	game.audience_deals["directorate"] = 20
	game.standing["directorate"] = 87
	game.standing_memory["directorate"] = [{"deed": "the_list", "week": 20}]
	game.audience = {"faction": "black_flag", "week": 20, "target": ""}
	game.audience_last["synod"] = 19
	game.audience_due["exchange"] = 3
	game.leader_answers["synod"] = {"answer": "refused", "week": 19}
	game.leader_answers["depot"] = {"answer": "helped", "week": 17}
	game.stats["help_spent"] = {"materials": 6}
	game.help_last["depot"] = 17
	game.fragments["depot_order"] = {"known": true, "how": "dirty", "week": 18}
	game.story_words = 3
	game.story_queue = ["st3_floor"]
	game.proof_extra = 2
	return game


func _start_standing() -> Dictionary:
	var out := {}
	for row in catalog.leaders.factions:
		out[str(row.id)] = int(row.start_opinion)
	return out


func _legacy() -> void:
	var source := _game(1)
	var fixture := source.export_state()
	fixture.erase("schema")
	for key in AUDIENCE_KEYS:
		fixture.erase(key)
	var game := _busy_game()
	var loaded := game.import_state(fixture)
	var empty_memory := true
	for fid in game.standing_memory:
		empty_memory = empty_memory and game.standing_memory[fid].is_empty()
	_expect(loaded and game.audience_deals.is_empty() and game.standing == _start_standing()
		and game.audience.is_empty() and game.audience_last.is_empty() and game.audience_due.is_empty()
		and empty_memory and game.standing_memory.size() == _start_standing().size() and game.seed == 1,
		"Legacy audience fixture loads to defaults",
		"legacy fixture loaded=%s deals=%s standing=%s audience=%s memory=%s" % [loaded, game.audience_deals, game.standing, game.audience, game.standing_memory])
	_expect(loaded and game.leader_answers.is_empty() and game.fragments.is_empty() and game.story_words == 0,
		"Legacy save starts with no leader answers, fragments or testimonies", "legacy answers %s fragments %s" % [game.leader_answers, game.fragments])
	var second := source.export_state()
	second["schema"] = 2
	for key in Game.V2_ADDED:
		second.erase(key)
	game = _busy_game()
	loaded = game.import_state(second)
	_expect(loaded and game.leader_answers.is_empty() and game.seed == 1,
		"Schema 2 save migrates with no leader answers", "schema 2 loaded=%s %s answers=%s" % [loaded, game.load_error, game.leader_answers])
	var third := source.export_state()
	third["schema"] = 3
	for key in Game.V3_ADDED + Game.V3_RNG_ADDED:
		third.erase(key)
	game = _busy_game()
	loaded = game.import_state(third)
	var story_stream := RandomNumberGenerator.new()
	story_stream.seed = 1 * 41 + 5
	_expect(loaded and game.fragments.is_empty() and game.story_words == 0 and game.seed == 1 and game.story_rng.state == story_stream.state,
		"Schema 3 save migrates with no fragments, no testimonies and the story stream from the seed",
		"schema 3 loaded=%s %s fragments=%s words=%d story stream %s" % [loaded, game.load_error, game.fragments, game.story_words, game.story_rng.state == story_stream.state])
	var fourth := source.export_state()
	fourth["schema"] = 4
	for key in Game.V4_ADDED:
		fourth.erase(key)
	game = _busy_game()
	loaded = game.import_state(fourth)
	_expect(loaded and game.help_last.is_empty() and game.seed == 1,
		"Schema 4 save migrates with no help given yet", "schema 4 loaded=%s %s help=%s" % [loaded, game.load_error, game.help_last])
	var fifth := source.export_state()
	fifth["schema"] = 5
	for key in Game.V5_ADDED:
		fifth.erase(key)
	game = _busy_game()
	loaded = game.import_state(fifth)
	_expect(loaded and game.story_queue.is_empty() and game.proof_extra == 0 and game.seed == 1,
		"Schema 5 save migrates with no scene queued and no extra proofs",
		"schema 5 loaded=%s %s queue=%s proofs=%d" % [loaded, game.load_error, game.story_queue, game.proof_extra])
	var oldest := source.export_state()
	oldest.erase("schema")
	for key in Game.V1_ADDED + Game.V1_RNG_ADDED + Game.V2_ADDED + Game.V3_ADDED + Game.V4_ADDED + Game.V5_ADDED:
		oldest.erase(key)
	game = _busy_game()
	loaded = game.import_state(oldest)
	var fresh := _game(1)
	_expect(loaded and game.flags.is_empty() and game.journal.is_empty() and game.queued_orders.is_empty()
		and game.white_pending.is_empty() and game.standing == _start_standing() and game.rng.state == fresh.rng.state,
		"First save format migrates", "first save format loaded=%s %s" % [loaded, game.load_error])
	_expect(loaded and not game.check_schedule.is_empty() and game.check_schedule == fresh.check_schedule
		and game.check_rng.state == fresh.check_rng.state,
		"First save format rebuilds the check schedule from the seed (%d checks)" % game.check_schedule.size(),
		"check schedule %s vs fresh %s, stream %d vs %d" % [game.check_schedule, fresh.check_schedule, game.check_rng.state, fresh.check_rng.state])


func _rejects() -> void:
	var good := _game(1).export_state()
	good["schema"] = Game.SAVE_SCHEMA
	var cases := {
		"week only": {"week": 17},
		"schema 99": _with(good, "schema", 99),
		"schema text": _with(good, "schema", "2"),
		"v2 missing audience": _without(good, "audience"),
		"v2 missing check_state": _without(good, "check_state"),
		"residents not array": _with(good, "residents", {}),
		"rng text": _with(good, "rng_state", "7"),
		"week past end": _with(good, "week", 99),
		"unknown player": _with(good, "player", "nobody"),
		"stranger on staff": _staffed_by(good, "ghost"),
		"resident outside people": _with(good, "people", {}),
		"unknown audience leader": _with(good, "audience", {"faction": "nobody", "week": 1, "target": ""}),
		"v3 missing leader_answers": _without(good, "leader_answers"),
		"leader answer unknown": _with(good, "leader_answers", {"depot": {"answer": "maybe", "week": 1}}),
		"leader answer future week": _with(good, "leader_answers", {"depot": {"answer": "accepted", "week": 39}}),
		"v4 missing fragments": _without(good, "fragments"),
		"v4 missing story_words": _without(good, "story_words"),
		"v4 missing story_state": _without(good, "story_state"),
		"fragment unknown": _with(good, "fragments", {"the_moon": {"known": true, "how": "found", "week": 1}}),
		"fragment learned oddly": _with(good, "fragments", {"depot_order": {"known": true, "how": "stolen", "week": 1}}),
		"fragment future week": _with(good, "fragments", {"depot_order": {"known": true, "how": "honest", "week": 39}}),
		"story_words negative": _with(good, "story_words", -2),
		"story_words text": _with(good, "story_words", "3"),
		"v5 missing help_last": _without(good, "help_last"),
		"help unknown leader": _with(good, "help_last", {"nobody": 1}),
		"help future week": _with(good, "help_last", {"depot": 39}),
		"help week text": _with(good, "help_last", {"depot": "1"}),
		"v6 missing story_queue": _without(good, "story_queue"),
		"v6 missing proof_extra": _without(good, "proof_extra"),
		"queued scene unknown": _with(good, "story_queue", ["st3_moon"]),
		"queued scene not by order": _with(good, "story_queue", ["st3_decision"]),
		"queue not a list": _with(good, "story_queue", "st3_floor"),
		"proof_extra negative": _with(good, "proof_extra", -1),
		"proof_extra text": _with(good, "proof_extra", "2"),
	}
	for name in cases:
		var game := _busy_game()
		var before := var_to_bytes(game.export_state())
		var rng_before := [game.rng.state, game.crunch_rng.state, game.net_rng.state, game.check_rng.state]
		var loaded := game.import_state(cases[name])
		var same := var_to_bytes(game.export_state()) == before
		same = same and rng_before == [game.rng.state, game.crunch_rng.state, game.net_rng.state, game.check_rng.state]
		_expect(not loaded and same and game.load_error != "", "Rejects %s (%s)" % [name, game.load_error],
			"%s loaded=%s unchanged=%s" % [name, loaded, same])


## A save taken with the final decision on the table, and one taken after a story ending, load back the same.
func _story_saves() -> void:
	var game := _game(3)
	game.week = 34
	game.pending = []
	game.proof_extra = 3
	game.flags["floor_published"] = true
	game.story_queue = ["st3_observatory"]
	game._present_event(game._event_by_id("st3_decision"))
	var at_decision := game.export_state()
	at_decision["schema"] = Game.SAVE_SCHEMA
	var copy := _game(1)
	var loaded := copy.import_state(at_decision)
	var same := loaded and var_to_bytes(copy.export_state()) == var_to_bytes(game.export_state())
	var choices: Array = copy.pending.filter(func(ev): return str(ev.id) == "st3_decision")
	var door_open := not choices.is_empty() and not copy.choice_locked(choices[0].choices[0])
	var took := copy.apply({"kind": "event", "event_id": "st3_decision", "choice_id": "door"})
	var after := copy.export_state()
	after["schema"] = Game.SAVE_SCHEMA
	var ended := _game(1)
	var reloaded := ended.import_state(after)
	_expect(same and door_open and took and copy.over == "open_door" and reloaded and ended.over == "open_door"
		and ended.ending_id() == "open_door" and ended.proofs() == 3 and ended.story_queue == ["st3_observatory"],
		"Saves at the final decision and after a story ending load back the same",
		"decision loaded=%s same=%s door=%s took=%s over=%s reloaded=%s %s ending=%s" % [loaded, same, door_open, took, copy.over, reloaded, ended.load_error, ended.ending_id()])


## New Game and Continue reuse the session's catalog, so a run must leave it as it found it: the same seed
## played twice on one catalog ends in the same state, check events' open effects included.
func _shared_catalog() -> void:
	var shared := Catalog.new()
	shared.load_all()
	var runs: Array = []
	var opened := 0
	for i in 2:
		var game := Game.new()
		game.setup(shared, 3, WEEKS)
		var bot := Bot.new()
		while game.over == "":
			bot._act(game)
			game.end_week()
		runs.append(var_to_bytes(game.export_state()))
		if i == 0:
			for item in game.check_schedule:
				if bool(item.done) and not game._event_by_id(str(item.id)).get("effects_on_open", {}).is_empty():
					opened += 1
	var marked := shared.events.filter(func(ev): return ev.has("opened"))
	_expect(opened > 0 and runs[0] == runs[1] and marked.is_empty(),
		"Same seed twice on one catalog plays the same (%d checks with open effects)" % opened,
		"shared catalog: open checks %d, same %s, catalog events marked %d" % [opened, runs[0] == runs[1], marked.size()])


func _with(data: Dictionary, key: String, value) -> Dictionary:
	var out := data.duplicate(true)
	out[key] = value
	return out


func _without(data: Dictionary, key: String) -> Dictionary:
	var out := data.duplicate(true)
	out.erase(key)
	return out


func _staffed_by(data: Dictionary, id: String) -> Dictionary:
	var out := data.duplicate(true)
	out.rooms[0].staff.append(id)
	return out


## Plays a seed through, saving to disk at many points; each save is resumed in a different live run
## and must reach exactly the same states and ending as the uninterrupted run.
func _resume() -> void:
	var covered := {"pending": 0, "white_pending": 0, "queued_orders": 0, "audience": 0, "leader_answers": 0, "fragments": 0, "helped": 0, "after_load_rng": 0}
	var points := 0
	var mismatches: PackedStringArray = []
	for run_seed in SEEDS:
		var ref := _game(run_seed)
		var bot := Bot.new()
		var states: Array = []
		var bots: Array = []
		while true:
			states.append(var_to_bytes(ref.export_state()))
			bots.append(_bot_memory(bot))
			if ref.over != "":
				break
			_drive(ref, bot)
			states.append(var_to_bytes(ref.export_state()))
			bots.append(_bot_memory(bot))
			ref.end_week()
		for at in range(0, states.size() - 1):
			var snap: Dictionary = bytes_to_var(states[at])
			var marked: bool = not snap.pending.is_empty() or not snap.white_pending.is_empty() or not snap.queued_orders.is_empty() or not snap.audience.is_empty()
			if not marked and at % 7 != 0:
				continue
			points += 1
			for key in ["pending", "white_pending", "queued_orders", "audience", "leader_answers", "fragments"]:
				if not snap[key].is_empty():
					covered[key] += 1
			if snap.leader_answers.values().any(func(row): return str(row.answer) == "helped"):
				covered.helped += 1
			var why := _resume_from(snap, bots[at], states, at, run_seed)
			if why != "":
				mismatches.append("seed %d point %d: %s" % [run_seed, at, why])
			else:
				covered.after_load_rng += 1
	_expect(mismatches.is_empty(), "Resume matches uninterrupted run at %d points %s" % [points, str(covered)],
		"resume " + " | ".join(mismatches.slice(0, 5)))
	for key in covered:
		_expect(int(covered[key]) > 0, "Resume exercised " + key, "resume never exercised " + key)


func _resume_from(snap: Dictionary, memory: Dictionary, states: Array, at: int, run_seed: int) -> String:
	var source := _game(run_seed)
	if not source.import_state(snap):
		return "staging " + source.load_error
	if not SaveGame.write_auto(source):
		return "write " + SaveGame.last_error
	var game := _busy_game()
	if not SaveGame.load_latest(game):
		return "load " + SaveGame.last_error
	var bot := Bot.new()
	for key in memory:
		bot.set(key, memory[key])
	var i := at
	if var_to_bytes(game.export_state()) != states[i]:
		return "loaded state differs: " + _first_difference(game.export_state(), bytes_to_var(states[i]))
	while i + 1 < states.size():
		if i % 2 == 0:
			_drive(game, bot)
		else:
			game.end_week()
		i += 1
		if var_to_bytes(game.export_state()) != states[i]:
			return "diverged at point %d: %s" % [i, _first_difference(game.export_state(), bytes_to_var(states[i]))]
	return ""


## The player's half of a week: take every second leader's deal, queue a council order every third
## week the way the UI does, hear a resident story every fourth week and learn a fragment in week 9, then let
## the bot play.
func _drive(game: Game, bot: Bot) -> void:
	if game.week % 4 == 0:
		var stories := Voice.of_type("story")
		game.hear_story(str(stories[(game.week / 4) % stories.size()].id))
	if game.week == 9:
		game.know_fragment("synod_recording", "honest")
	if not game.audience.is_empty() and game.week % 2 == 0 and game.audience_reason() == "":
		game.apply({"kind": "audience", "accept": true})
	elif not game.audience.is_empty() and game.week % 2 == 1 and game.help_reason() == "":
		game.apply({"kind": "audience", "help": true})
	if game.week % 3 == 0:
		var queued := false
		for order in ["envoy", "propaganda"]:
			for sid in game.stations:
				if game.queue_order({"order": order, "station": str(sid)}):
					queued = true
					break
			if queued:
				break
	bot._act(game)


func _bot_memory(bot: Bot) -> Dictionary:
	return {"profile": bot.profile, "_did_aid": bot._did_aid, "_did_talk": bot._did_talk, "_did_ration": bot._did_ration}


func _first_difference(a: Dictionary, b: Dictionary) -> String:
	for key in b:
		if not a.has(key) or var_to_bytes(a[key]) != var_to_bytes(b[key]):
			return str(key)
	return "key order"


func _slots() -> void:
	var older := _game(1)
	older.end_week()
	var newer := _game(2)
	newer.end_week()
	newer.end_week()
	var older_bytes := var_to_bytes(older.export_state())
	_expect(SaveGame.write_auto(older), "Atomic write", "write_auto " + SaveGame.last_error)
	_expect(not FileAccess.file_exists(SaveGame.auto_path() + ".tmp"), "No temp file left", "temp file left behind")

	_write_bytes(SaveGame.auto_path() + ".tmp", PackedByteArray([1, 2, 3]))
	var game := _busy_game()
	_expect(SaveGame.load_latest(game) and var_to_bytes(game.export_state()) == older_bytes and SaveGame.last_path == SaveGame.auto_path(),
		"Half-written temp ignored", "half-written temp broke load: " + SaveGame.last_error)

	DirAccess.remove_absolute(SaveGame.auto_path() + ".tmp")
	DirAccess.make_dir_recursive_absolute(SaveGame.auto_path() + ".tmp")
	var wrote := SaveGame.write_auto(newer)
	DirAccess.remove_absolute(SaveGame.auto_path() + ".tmp")
	game = _busy_game()
	_expect(not wrote and SaveGame.load_latest(game) and var_to_bytes(game.export_state()) == older_bytes,
		"Failed write keeps last slot", "failed write wrote=%s last=%s" % [wrote, SaveGame.last_error])

	OS.delay_msec(1100)
	_expect(SaveGame.write_manual(newer), "Manual write", "write_manual " + SaveGame.last_error)
	OS.delay_msec(1100)
	_write_bytes(SaveGame.manual_path(), PackedByteArray([0, 0, 0, 7, 9, 9]))
	game = _busy_game()
	var loaded := SaveGame.load_latest(game)
	_expect(loaded and SaveGame.last_path == SaveGame.auto_path() and var_to_bytes(game.export_state()) == older_bytes
		and SaveGame.last_error.contains("manual.sav"),
		"Corrupt newest slot falls back to %s (%s)" % [SaveGame.last_path.get_file(), SaveGame.last_error],
		"corrupt newest loaded=%s from %s: %s" % [loaded, SaveGame.last_path, SaveGame.last_error])

	_expect(SaveGame.write_auto(older) and FileAccess.file_exists(SaveGame.auto_path() + ".bak"), "Rewrite keeps a .bak", "no .bak after rewrite")
	_write_bytes(SaveGame.auto_path(), PackedByteArray([5, 5]))
	_expect(SaveGame.write_auto(newer), "Write over a corrupt slot", SaveGame.last_error)
	_write_bytes(SaveGame.auto_path(), PackedByteArray([5, 5]))
	game = _busy_game()
	_expect(SaveGame.load_latest(game) and SaveGame.last_path.ends_with("autosave.sav.bak") and var_to_bytes(game.export_state()) == older_bytes,
		"Corrupt slot never replaces the good .bak", "bak after corrupt rewrite from %s: %s" % [SaveGame.last_path, SaveGame.last_error])
	_write_bytes(SaveGame.auto_path() + ".bak", PackedByteArray([5, 5]))
	game = _busy_game()
	var before := var_to_bytes(game.export_state())
	loaded = SaveGame.load_latest(game)
	_expect(not loaded and var_to_bytes(game.export_state()) == before and SaveGame.last_error.contains("autosave.sav"),
		"All slots corrupt fails cleanly (%s)" % SaveGame.last_error, "all corrupt loaded=%s" % loaded)

	_wipe(SaveGame.root)
	_expect(SaveGame.write_auto(older), "Second write", SaveGame.last_error)
	_expect(SaveGame.write_auto(newer), "Third write", SaveGame.last_error)
	_write_bytes(SaveGame.auto_path(), PackedByteArray([5, 5]))
	game = _busy_game()
	_expect(SaveGame.load_latest(game) and SaveGame.last_path.ends_with("autosave.sav.bak") and var_to_bytes(game.export_state()) == older_bytes,
		"Corrupt slot recovers from its .bak", "bak recovery from %s: %s" % [SaveGame.last_path, SaveGame.last_error])


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _slot_stamp() -> String:
	var parts: PackedStringArray = []
	for path in ["user://autosave.sav", "user://manual.sav", "user://autosave.sav.bak", "user://manual.sav.bak"]:
		parts.append("%s:%s:%s" % [path, FileAccess.file_exists(path), FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""])
	return " ".join(parts)


func _wipe(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	for name in dir.get_directories():
		dir.remove(name)
	DirAccess.remove_absolute(dir_path)
