class_name Formulas
extends RefCounted

## Pure numbers from the GDD. No scene tree, no randomness.

static func room_output(base: float, skills: Array, coef: float, cap: float) -> int:
	var extra := 0.0
	for s in skills:
		var v := float(s)
		if v > 1.0:
			extra += v - 1.0
	var mult := minf(cap, 1.0 + coef * extra)
	return int(round(base * mult))


static func people_for(pop: int, per: int) -> int:
	if pop <= 0 or per <= 0:
		return 0
	return ceili(float(pop) / float(per))


static func need_factor(avg_fill: float) -> float:
	return clampf(0.5 + avg_fill, 0.5, 1.5)


static func lean_mult(player_lean: String, station_lean: String) -> float:
	if player_lean == "" or station_lean == "":
		return 1.0
	if player_lean == station_lean:
		return 2.0
	# Craft opposes trade. Order opposes faith. The cross pairs are neutral.
	if (player_lean == "craft" and station_lean == "trade") or (player_lean == "trade" and station_lean == "craft"):
		return 0.5
	if (player_lean == "order" and station_lean == "faith") or (player_lean == "faith" and station_lean == "order"):
		return 0.5
	return 1.0


static func sympathy_gain(base: float, player_lean: String, station_lean: String, avg_fill: float) -> int:
	return int(round(base * lean_mult(player_lean, station_lean) * need_factor(avg_fill)))


static func self_check() -> PackedStringArray:
	var errs: PackedStringArray = []
	# Tech 5: skill above 1 is 4, multiplier 1.6, output 16 from base 10.
	var tech5 := room_output(10.0, [5], 0.15, 2.5)
	if tech5 != 16:
		errs.append("tech5 output %s" % tech5)
	var tech1 := room_output(10.0, [1], 0.15, 2.5)
	if tech1 != 10:
		errs.append("tech1 output %s" % tech1)
	# Cap at 2.5x.
	var capped := room_output(10.0, [5, 5, 5, 5], 0.15, 2.5)
	if capped != 25:
		errs.append("cap output %s" % capped)
	if people_for(25, 4) != 7:
		errs.append("air people")
	if people_for(25, 3) != 9:
		errs.append("food people")
	if people_for(0, 4) != 0:
		errs.append("zero pop")
	var sym := sympathy_gain(12.0, "craft", "craft", 0.5)
	# factor 1.0, lean 2, gain 24
	if sym != 24:
		errs.append("sympathy %s" % sym)
	var opposed := sympathy_gain(12.0, "craft", "trade", 1.0)
	# factor 1.5, lean 0.5, gain 9
	if opposed != 9:
		errs.append("opposed %s" % opposed)
	return errs
