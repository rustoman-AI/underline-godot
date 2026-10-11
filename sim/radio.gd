class_name Radio
extends RefCounted

## Underground cable radio. Items are the "radio" lines in data/vo, drawn from a bag so none repeats until all
## have played. Under threat the draw leans toward anxious items, in calm weeks toward light and positive ones.

const NO_TRANSCRIPT := "A bulletin crackles down the cable."
const CALM_MOODS := ["light", "positive", "funny"]

static var bag: Array = []
static var rng := RandomNumberGenerator.new()
static var seeded := false


## `threat` runs 0 (calm) to 1 (station in trouble).
static func next(threat := 0.0) -> Dictionary:
	if not seeded:
		seeded = true
		rng.randomize()
	var items := Voice.of_type("radio")
	if items.is_empty():
		return {}
	if bag.is_empty():
		for item in items:
			bag.append(str(item.id))
	var weights: Array = []
	var total := 0.0
	for id in bag:
		var w := _weight(Voice.line(str(id)), clampf(threat, 0.0, 1.0))
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	var pick := bag.size() - 1
	for i in bag.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			pick = i
			break
	var id := str(bag[pick])
	bag.remove_at(pick)
	return Voice.line(id)


static func _weight(item: Dictionary, threat: float) -> float:
	var mood := str(item.get("mood", "neutral"))
	if mood == "anxious":
		return 1.0 + 4.0 * threat
	if CALM_MOODS.has(mood):
		return 1.0 + 2.0 * (1.0 - threat)
	return 1.5


## Journal rows from before the data/vo move hold bare ids such as "flood_watch".
static func by_id(id: String) -> Dictionary:
	var item := Voice.line(id)
	if item.is_empty():
		item = Voice.line("radio_" + id)
	return item


static func text(item: Dictionary) -> String:
	var out := Voice.text(item)
	if out == "":
		return Copy.t(NO_TRANSCRIPT)
	return out
