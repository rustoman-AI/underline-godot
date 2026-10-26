class_name DealMarks
extends RefCounted

## P45 lasting Network marks. Reads deals / passage only. Never queues a dawn chip.

const BRASS := Color("e2a63a")
const PIP_R := 2.8
const PIP_GAP := 7.0
const PIP_DROP := 8.0
const PASSAGE_DOT := 1.8
const PASSAGE_STEP := 11.0


static func secret(st: Dictionary) -> bool:
	return bool(st.get("hidden", false)) and not bool(st.get("known", false))


## Filled brass pips under a non-player pin. 0 when the station is ours, unknown, or has no deals.
static func pip_count(game, sid: String) -> int:
	if game == null or not game.stations.has(sid):
		return 0
	if str(sid) == str(game.capital_id):
		return 0
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) == str(game.player):
		return 0
	if not bool(st.get("known", false)) or secret(st):
		return 0
	var deals := int(st.get("deals", 0))
	if deals < 1:
		return 0
	return mini(deals, 3)


## Owner flipped to the player with a full ladder, or an explicit joined flag on the station.
static func joined(game, st: Dictionary) -> bool:
	if bool(st.get("joined", false)):
		return true
	if game == null:
		return false
	return str(st.get("owner", "")) == str(game.player) and int(st.get("deals", 0)) >= 3


static func pip_slot(at: Vector2, pin_r: float, index: int) -> Vector2:
	return at + Vector2((float(index) - 1.0) * PIP_GAP, pin_r + PIP_DROP)


## Hover line for the pip row. Compact is the reduce-motion readout.
static func pip_line(game, sid: String, compact: bool) -> String:
	if game == null or not game.stations.has(sid):
		return ""
	var st: Dictionary = game.stations[sid]
	var done := joined(game, st) and int(st.get("deals", 0)) >= 3
	var n := pip_count(game, sid)
	if done and (n >= 1 or str(st.get("owner", "")) == str(game.player)):
		return Copy.t("deal.pips_done")
	if n < 1:
		return ""
	if compact:
		return Copy.fill("deal.reduce", {"n": n})
	return Copy.fill("deal.pips", {"n": n})


## Dashed brass thread home. Clears once the station joins and the pin is ours.
static func shows_thread(game, sid: String) -> bool:
	if game == null or not game.stations.has(sid):
		return false
	if str(sid) == str(game.capital_id):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) == str(game.player):
		return false
	if not bool(st.get("passage", false)) or secret(st) or not bool(st.get("known", false)):
		return false
	return true


static func passage_ink() -> Color:
	var brass := BRASS
	brass.a = 0.85
	return brass


## Pips stay still. Reduce-motion and full motion both skip a pulse.
static func pips_pulse() -> bool:
	return false


static func mark_lines(game, sid: String, compact: bool) -> PackedStringArray:
	var lines: PackedStringArray = []
	var pip := pip_line(game, sid, compact)
	if pip != "":
		lines.append(pip)
		if not compact and pip != Copy.t("deal.pips_done"):
			lines.append(Copy.t("deal.tip"))
	if shows_thread(game, sid):
		lines.append(Copy.t("deal.passage"))
	return lines


## First time this run a deal pip would draw. Sets flags.seen_deal_marks. Does not touch the dawn chip.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get("seen_deal_marks", false)):
		return ""
	var any := false
	for sid in game.stations:
		if pip_count(game, str(sid)) >= 1:
			any = true
			break
	if not any:
		return ""
	game.flags["seen_deal_marks"] = true
	return Copy.t("deal.first")
