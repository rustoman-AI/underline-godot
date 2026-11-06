class_name RivalDesk
extends RefCounted

## P92 Rival Desk. Last resolved move of Exchange, Directorate, and Synod.
## Recording only. No rng, no AI, no stock, hope, opinion, or garrison change.
## Soft dawn: none. Map mark: none. `rival.first` is a P61 first-float, not a dawn chip.
## Schema 22 is reserved for unmerged P91 `echoes`. This script never reads it.
## Click opens the logged target station, never the faction capital.

const SEEN := "seen_rival_desk"
const FACTIONS := ["exchange", "directorate", "synod"]
const KINDS := ["bought", "marched", "held", "preached", "took"]

## Gate flips this off to prove the hooks do not move a careful run. The game leaves it on.
static var enabled := true
## Instance id of the run whose first line has not been shown yet. Not saved.
static var pending_id := 0


static func dawn_chip() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func map_mark() -> bool:
	return false


static func kind_of_chip(chip: String) -> String:
	if chip.begins_with("map.chip.bought"):
		return "bought"
	if chip.begins_with("map.chip.marched"):
		return "marched"
	if chip == "map.chip.held":
		return "held"
	if chip.begins_with("map.chip.preach"):
		return "preached"
	return ""


## Visible P28 hop. Kinds with no rival.* line (secured, demanded, …) are skipped.
static func note_chip(game, fid: String, chip: String, target: String) -> void:
	var kind := kind_of_chip(chip)
	if kind == "":
		return
	note(game, fid, kind, target)


## Successful rival capture. Player captures never land here as a row.
static func note_took(game, fid: String, target: String) -> void:
	note(game, fid, "took", target)


static func note(game, fid: String, kind: String, target: String) -> void:
	if not enabled or game == null:
		return
	var id := str(fid)
	if not FACTIONS.has(id) or id == str(game.player) or id == "depot":
		return
	if not KINDS.has(str(kind)):
		return
	if not (game.rival_log is Dictionary):
		game.rival_log = {}
	var cur = game.rival_log.get(id, {})
	if str(kind) != "took" and cur is Dictionary and str(cur.get("kind", "")) == "took" and int(cur.get("week", -1)) == int(game.week):
		return
	game.rival_log[id] = {"kind": str(kind), "target": str(target), "week": int(game.week)}
	_arm(game)


static func has_pending(game) -> bool:
	if game == null:
		return false
	return pending_id == game.get_instance_id()


## First float for this session. The seen flag was set when the line was written.
static func claim(game) -> String:
	if game == null or pending_id != game.get_instance_id():
		return ""
	pending_id = 0
	if not bool(game.flags.get(SEEN, false)):
		return ""
	return Copy.t("rival.first")


## Three fixed seats. A missing target, or a kind with no line, is the quiet row.
static func rows(game) -> Array:
	var out: Array = []
	for fid in FACTIONS:
		out.append(_row(game, fid))
	return out


static func _row(game, fid: String) -> Dictionary:
	var short := fid
	if game != null:
		short = Copy.t(game._fname(fid))
	var entry := {}
	if game != null and game.rival_log is Dictionary:
		var raw = game.rival_log.get(fid, {})
		if raw is Dictionary:
			entry = raw
	var kind := str(entry.get("kind", ""))
	var target := str(entry.get("target", ""))
	var week := int(entry.get("week", 0))
	var station := ""
	if game != null and target != "" and game.stations.has(target):
		station = Copy.t(str(game.stations[target].get("name", target)))
	var quiet := true
	var text := Copy.t("rival.quiet")
	if KINDS.has(kind) and station != "":
		quiet = false
		text = Copy.fill("rival." + kind, {"station": station, "n": week})
	else:
		target = ""
	return {
		"fid": fid,
		"short": short,
		"text": text,
		"line": "%s · %s" % [short, text],
		"target": target if not quiet else "",
		"clickable": not quiet,
		"quiet": quiet,
		"kind": kind if not quiet else "",
	}


static func _arm(game) -> void:
	if bool(game.flags.get(SEEN, false)):
		return
	game.flags[SEEN] = true
	pending_id = game.get_instance_id()
