class_name FocusPip
extends RefCounted

## P57 focus letter on a player-owned outpost pin. Reads st.focus only.
## Does not set focus, does not queue a soft chip, and does not touch outpost flow.

const FOCI := ["food", "air", "defense", "influence"]
const GLYPHS := {"food": "F", "air": "A", "defense": "D", "influence": "I"}
## Upper-inner, left of center on the pin head. Not the goods corner and not the leaflet corner.
const SLOT := Vector2(-0.35, -0.20)
const DISC_PX := 13.0
const DISC_TINY_PX := 10.0
const LETTER_PX := 12
const LETTER_TINY_PX := 10
const TINY_R := 10.0


static func shows(game, sid: String) -> bool:
	if game == null or sid == "" or not game.stations.has(sid):
		return false
	if str(sid) == str(game.capital_id):
		return false
	var st: Dictionary = game.stations[sid]
	if bool(st.get("capital", false)):
		return false
	if str(st.get("owner", "")) != str(game.player):
		return false
	if not bool(st.get("known", false)):
		return false
	if bool(st.get("hidden", false)) and not bool(st.get("known", false)):
		return false
	return FOCI.has(str(st.get("focus", "")))


static func glyph(focus: String) -> String:
	return str(GLYPHS.get(focus, ""))


static func slot(at: Vector2, pin_r: float) -> Vector2:
	return at + Vector2(SLOT.x * pin_r, SLOT.y * pin_r)


static func disc_px(pin_r: float) -> float:
	if pin_r < TINY_R:
		return DISC_TINY_PX
	return DISC_PX


static func letter_px(pin_r: float) -> int:
	if pin_r < TINY_R:
		return LETTER_TINY_PX
	return LETTER_PX


## The letter is type. It does not bounce, pulse, or slide in either motion setting.
static func bounces() -> bool:
	return false


static func lines(game, sid: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not shows(game, sid):
		return out
	var focus := str(game.stations[sid].get("focus", ""))
	var name := Copy.t("focus." + focus)
	out.append(Copy.fill("focus.current", {"name": name}))
	out.append(Copy.t("focus.tip"))
	return out
