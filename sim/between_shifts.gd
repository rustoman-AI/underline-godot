class_name BetweenShifts
extends RefCounted

## P96 Between Shifts. Narrative only.
## Six original home residents can be asked one question. The chosen branch is
## remembered. A later eligible week can show that branch's callback.
## No rewards and no assignments. Life notes, the public record, and the truth shelf stay untouched.
## Soft dawn NONE. No map mark. Balance ZERO.
##
## Copy in data/between_shifts.json is an interim wiring draft. It is not a
## Texts or canon approval. An empty string in the active locale hides the
## vignette. The key is never shown.
##
## Schema 26 adds shiftword_state. Schema <= 25 may omit it and loads {}.
## A key already stored is kept. Schema 27 and above is rejected.
##
## P81 passage duty is not a shipped seat on this master. A non-empty
## duty_edge_id cannot be shown to be a home seat, so the vignette hides.
## The assignment itself is not changed.
## The ferry expedition dict has no person roster. People who left on it are
## on the squad trip (away / other station) and hide by that test.


const SPEAKERS := ["ruth", "benny", "samira", "owen", "lila", "pete"]
const CHOICES := ["a", "b"]
const PARTS := ["scene", "a", "b", "answer_a", "answer_b", "follow_a", "follow_b"]
const CHROME := ["shiftword.open", "shiftword.archive", "shiftword.back"]
const MIN_WEEK := 4
## Gate and careful runs flip this off. Off skips the read probes only.
## The game leaves it on. Commit still requires an explicit reply().
static var enabled := true
static var _warned := {}


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func map_mark() -> bool:
	return false


static func blank() -> Dictionary:
	return {}


static func person_key(person_id: String, part: String) -> String:
	return "shiftword.%s.%s" % [person_id, part]


## Active-locale string. Empty when the key or that language is missing.
## Does not fall back to the other language or to the raw key.
static func line(key: String) -> String:
	Copy.boot()
	if not Copy.keys.has(key):
		return ""
	var row = Copy.keys[key]
	if not (row is Dictionary):
		return ""
	var field := "ru" if Copy.lang == "ru" else "en"
	return str(row.get(field, "")).strip_edges()


static func pack_ready(person_id: String) -> bool:
	if not SPEAKERS.has(person_id):
		return false
	for part in PARTS:
		if line(person_key(person_id, part)) == "":
			return false
	for key in CHROME:
		if line(key) == "":
			return false
	return true


## "" when shiftword_state is a Dictionary the save can keep.
## A bad row does not reject the save. It only hides that vignette.
static func problem(raw) -> String:
	if not (raw is Dictionary):
		return "shiftword_state"
	return ""


## "talk", "archive", or "hide". Read-only. Does not boot Night Runs.
static func offer(game, person_id: String) -> String:
	if not enabled or game == null:
		return "hide"
	if not _week_ok(game) or not present(game, person_id) or not pack_ready(person_id):
		return "hide"
	var kind := _stored(game, person_id)
	if kind == "bad":
		_warn(person_id, _row_issue(state_of(game).get(person_id, null), int(game.week), person_id))
		return "hide"
	if kind == "row":
		return "archive"
	return "talk"


## Original live adult, healthy, and physically at home. Week is not part of this.
static func present(game, person_id: String) -> bool:
	if game == null or not _original(game, person_id):
		return false
	var person: Dictionary = game.people[person_id]
	if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
		return false
	if str(game.governor_of(person_id)) != "":
		return false
	if bool(person.get("on_run", false)):
		return false
	if _runners(game).has(person_id):
		return false
	if _squad_off_home(game, person_id):
		return false
	if _on_expedition_roster(game, person_id):
		return false
	if _duty_hides(person):
		return false
	return true


static func choice_of(game, person_id: String) -> String:
	if _stored(game, person_id) != "row":
		return ""
	return str(state_of(game)[person_id].get("choice_id", ""))


static func answered_week(game, person_id: String) -> int:
	if _stored(game, person_id) != "row":
		return 0
	return int(state_of(game)[person_id].get("answered_week", 0))


static func follow_due(game, person_id: String) -> bool:
	if _stored(game, person_id) != "row" or game == null:
		return false
	return int(game.week) >= answered_week(game, person_id) + 1


## True when the callback text is on screen. Sets follow_seen only then.
static func reveal_follow(game, person_id: String) -> bool:
	if offer(game, person_id) != "archive" or not follow_due(game, person_id):
		return false
	var choice := choice_of(game, person_id)
	if line(person_key(person_id, "follow_" + choice)) == "":
		return false
	var row: Dictionary = state_of(game)[person_id]
	if not bool(row.get("follow_seen", false)):
		row["follow_seen"] = true
		game.shiftword_state[person_id] = row
	return true


## "ok" writes one row. "closed" / "stale" / "bad" write nothing.
static func reply(game, person_id: String, choice: String) -> String:
	var picked := str(choice)
	if game == null or (picked != "a" and picked != "b"):
		return "stale"
	if not (game.get("shiftword_state") is Dictionary):
		return "stale"
	var kind := _stored(game, person_id)
	if kind == "bad":
		_warn(person_id, _row_issue(state_of(game).get(person_id, null), int(game.week), person_id))
		return "bad"
	if kind == "row":
		return "closed"
	if not _week_ok(game) or not present(game, person_id) or not pack_ready(person_id):
		return "stale"
	game.shiftword_state[person_id] = {
		"vignette_id": person_id,
		"choice_id": picked,
		"answered_week": int(game.week),
		"follow_seen": false,
	}
	return "ok"


static func row_issue(game, person_id: String) -> String:
	if game == null or not (game.get("shiftword_state") is Dictionary):
		return ""
	if not state_of(game).has(person_id):
		return ""
	return _row_issue(state_of(game).get(person_id, null), int(game.week), person_id)


static func state_of(game) -> Dictionary:
	var raw = game.get("shiftword_state")
	if raw is Dictionary:
		return raw
	return {}


static func _week_ok(game) -> bool:
	return int(game.week) >= MIN_WEEK


static func _original(game, person_id: String) -> bool:
	if not SPEAKERS.has(person_id) or not game.people.has(person_id):
		return false
	var person = game.people[person_id]
	if not (person is Dictionary) or str(person.get("id", "")) != person_id:
		return false
	if not _living(game, person_id):
		return false
	if str(game.cast_id_of(person)) != person_id:
		return false
	if bool(person.get("core", false)):
		return false
	if game._is_council(person_id):
		return false
	if game._is_child(person):
		return false
	var dossier = person.get("dossier", null)
	if dossier is Dictionary and not (dossier as Dictionary).is_empty():
		return false
	return true


static func _living(game, person_id: String) -> bool:
	var rows = game.get("residents")
	if not (rows is Array):
		return false
	for person in rows:
		if person is Dictionary and str(person.get("id", "")) == person_id:
			return true
	return false


## Observes flags.night_runs when that block already exists. Does not boot the subsystem.
static func _runners(game) -> Array:
	var flags = game.get("flags")
	if not (flags is Dictionary):
		return []
	var block = flags.get("night_runs", null)
	if not (block is Dictionary):
		return []
	var active = block.get("active", null)
	if not (active is Dictionary):
		return []
	var runners = active.get("runners", [])
	if runners is Array:
		return runners
	return []


## Home roster with no trip stays. Away, or a station other than home, hides.
static func _squad_off_home(game, person_id: String) -> bool:
	var squads = game.get("squads")
	if not (squads is Dictionary):
		return false
	var capital := str(game.get("capital_id"))
	for fid in squads:
		var sq = squads[fid]
		if not (sq is Dictionary):
			continue
		var roster = sq.get("roster", [])
		if not (roster is Array) or not roster.has(person_id):
			continue
		var away := bool(sq.get("away", false))
		var station := str(sq.get("station", ""))
		var home_bound := (not away) and (station == "" or station == capital)
		if not home_bound:
			return true
	return false


static func _on_expedition_roster(game, person_id: String) -> bool:
	var ex = game.get("expedition")
	if not (ex is Dictionary) or (ex as Dictionary).is_empty():
		return false
	for key in ["roster", "runners", "workers", "party"]:
		var rows = ex.get(key, null)
		if rows is Array and rows.has(person_id):
			return true
	return false


static func _duty_hides(person: Dictionary) -> bool:
	return str(person.get("duty_edge_id", "")).strip_edges() != ""


## "none", "row", or "bad".
static func _stored(game, person_id: String) -> String:
	if not (game.get("shiftword_state") is Dictionary):
		return "none"
	if not state_of(game).has(person_id):
		return "none"
	if _row_issue(state_of(game).get(person_id, null), int(game.week), person_id) != "":
		return "bad"
	return "row"


static func _row_issue(raw, week: int, person_id: String) -> String:
	if not (raw is Dictionary):
		return "row type"
	var row: Dictionary = raw
	if str(row.get("vignette_id", "")) != person_id:
		return "vignette"
	var choice := str(row.get("choice_id", ""))
	if not CHOICES.has(choice):
		return "choice"
	var answered = row.get("answered_week", null)
	if typeof(answered) != TYPE_INT or int(answered) < MIN_WEEK or int(answered) > maxi(MIN_WEEK, week):
		return "week"
	if typeof(row.get("follow_seen", null)) != TYPE_BOOL:
		return "follow_seen"
	return ""


static func _warn(person_id: String, why: String) -> void:
	if why == "":
		return
	var key := person_id + ":" + why
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("Between Shifts hid %s (%s)" % [person_id, why])
