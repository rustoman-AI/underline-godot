extends SceneTree

## Headless gate for community perks and goods (DEC-G1…G3).
## Owning Botanic Garden raises hydro food and losing it removes the bonus the same night.
## Seeds, pork, copper and air coupons deliver when the source is held.
## Careful loss stays in 15-35% over seeds 1-60, 40 weeks.
##   godot --headless --path . -s res://sim/check_perks.gd

const SEEDS := 60
const WEEKS := 40
const LOSS_LO := 15.0
const LOSS_HI := 35.0


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("PERKS CHECK FAILED: " + catalog.error)
		quit(1)
		return
	var ok := true
	ok = _hydro(catalog) and ok
	ok = _goods(catalog) and ok
	ok = _rules(catalog) and ok
	ok = _strings() and ok
	var band := _careful(catalog)
	print("Careful loss: %d of %d (%.1f%%), need %.0f-%.0f%%" % [band.lost, SEEDS, band.pct, LOSS_LO, LOSS_HI])
	if not band.ok:
		ok = false
	print("PERKS CHECK OK" if ok else "PERKS CHECK FAILED")
	quit(0 if ok else 1)


func _fresh(catalog: Catalog, run_seed := 1) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, WEEKS)
	return game


func _hydro_food(game: Game) -> int:
	return int(game._tally().get("food", 0))


func _hydro(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var before := _hydro_food(game)
	var rooms := game._live_hydro_rooms()
	if rooms < 1:
		print("Hydro: FAIL no hydroponics room")
		return false
	game.stations.riverside.owner = game.player
	game._sync_perk_notices()
	var held := _hydro_food(game)
	var bonus := held - before
	var want := rooms * 2
	if bonus != want:
		print("Hydro: FAIL food %d -> %d (bonus %d, want %d)" % [before, held, bonus, want])
		return false
	var toast_held := false
	for note in game.notices:
		if str(note).begins_with("Held Botanic Garden:"):
			toast_held = true
	if not toast_held:
		print("Hydro: FAIL held toast ", game.notices)
		return false
	if int(game.perk_float_due.get("food", 0)) != rooms:
		print("Hydro: FAIL float ", game.perk_float_due)
		return false
	game.stations.riverside.owner = "neutral"
	game._sync_perk_notices()
	var lost := _hydro_food(game)
	if lost != before:
		print("Hydro: FAIL lose left food %d, baseline %d" % [lost, before])
		return false
	var toast_lost := false
	for note in game.notices:
		if str(note).begins_with("Lost Botanic Garden:"):
			toast_lost = true
	if not toast_lost:
		print("Hydro: FAIL lost toast ", game.notices)
		return false
	if game.good_flowing("riverside"):
		print("Hydro: FAIL seeds still flowing after the loss")
		return false
	print("Hydro: ok (+%d food while held, gone the same night)" % bonus)
	return true


func _goods(catalog: Catalog) -> bool:
	var ok := true
	ok = _held_good(catalog, "mill", "food", 6, "Pork") and ok
	ok = _held_good(catalog, "quarry", "materials", 3, "Copper") and ok
	ok = _held_good(catalog, "eastwater", "air", 4, "Air coupons") and ok
	ok = _held_good(catalog, "riverside", "food", 0, "Seeds") and ok
	var game := _fresh(catalog)
	var before := int(game.stock.materials)
	game.stations.quarry.passage = true
	game.stations.quarry.deals = 1
	if not game.good_flowing("quarry"):
		print("Goods: FAIL passage did not open copper")
		return false
	game._deliver_goods()
	if int(game.stock.materials) != before + 3:
		print("Goods: FAIL passage copper %d -> %d" % [before, int(game.stock.materials)])
		return false
	print("Goods: passage copper ok")
	return ok


func _held_good(catalog: Catalog, sid: String, key: String, amount: int, label: String) -> bool:
	var game := _fresh(catalog)
	var before := int(game.stock.get(key, 0))
	var food_before := _hydro_food(game)
	game.stations[sid].owner = game.player
	if not game.good_flowing(sid):
		print("Goods: FAIL %s not flowing while held" % label)
		return false
	game._deliver_goods()
	var got := int(game.stock.get(key, 0)) - before
	if amount > 0 and got != amount:
		print("Goods: FAIL %s %s %+d, want %+d" % [label, key, got, amount])
		return false
	if label == "Seeds":
		var bonus := _hydro_food(game) - food_before
		if bonus != game._live_hydro_rooms() * 2:
			print("Goods: FAIL seeds hydro bonus %d" % bonus)
			return false
	if not str(game.good_sheet_line(sid)).contains(label) and label != "Air coupons":
		print("Goods: FAIL sheet missing %s" % label)
		return false
	if label == "Air coupons" and not str(game.good_sheet_line(sid)).contains("Air coupons"):
		print("Goods: FAIL sheet missing air coupons")
		return false
	print("Goods: %s ok" % label)
	return true


func _rules(catalog: Catalog) -> bool:
	var ok := true
	var plain := _fresh(catalog)
	if plain.dig_material_cost() != int(plain.bal.dig_materials):
		print("Rules: FAIL dig base")
		ok = false
	if not is_equal_approx(plain._spoil_mult(), 0.5):
		print("Rules: FAIL salt spoil ", plain._spoil_mult())
		ok = false
	if not plain.good_flowing("southdepot"):
		print("Rules: FAIL salt not flowing at home")
		ok = false
	plain.stations.quarry.owner = plain.player
	if plain.dig_material_cost() != maxi(1, int(plain.bal.dig_materials) - 1):
		print("Rules: FAIL cheap digs ", plain.dig_material_cost())
		ok = false
	var cough := _fresh(catalog)
	if not is_equal_approx(cough._cough_mult(), 1.0):
		print("Rules: FAIL cough base")
		ok = false
	cough.stations.market.owner = cough.player
	if not is_equal_approx(cough._cough_mult(), 0.5):
		print("Rules: FAIL cough floor ", cough._cough_mult())
		ok = false
	var sab := _fresh(catalog)
	sab.stations.brickworks.owner = sab.player
	if not is_equal_approx(sab._sabotage_chance(), 0.1):
		print("Rules: FAIL sabotage ", sab._sabotage_chance())
		ok = false
	var lib := _fresh(catalog)
	lib.stations.library.owner = lib.player
	if lib._static_weight_mult() != 2:
		print("Rules: FAIL static weight")
		ok = false
	var warn := _fresh(catalog)
	var base_warn := warn.flood_warning()
	warn.stations.observatory.owner = warn.player
	if warn.flood_warning() != base_warn + 1:
		print("Rules: FAIL flood warning")
		ok = false
	var foundry := _fresh(catalog)
	foundry.stations.foundry.owner = foundry.player
	var hope := foundry.hope
	foundry._perk_sermons_hope()
	foundry._perk_sermons_hope()
	if foundry.hope != hope - 1:
		print("Rules: FAIL sermons once ", hope, " -> ", foundry.hope)
		ok = false
	var junk := _fresh(catalog)
	junk.stations.clocktower.owner = junk.player
	for _i in 6:
		junk._deliver_goods()
	if int(junk.flags.get("good_week:junk", -1)) != 0:
		print("Rules: FAIL junk counter ", junk.flags.get("good_week:junk", -1))
		ok = false
	if not junk.errors.is_empty():
		print("Rules: FAIL errors ", junk.errors)
		ok = false
	var sheet := _fresh(catalog)
	var perks := 0
	for sid in sheet.stations:
		if str(sheet.perk_sheet_line(sid)) != "":
			perks += 1
	if perks != 10:
		print("Rules: FAIL perk sheets %d" % perks)
		ok = false
	if str(sheet.perk_sheet_line("southdepot")) != "":
		print("Rules: FAIL home has a perk")
		ok = false
	if ok:
		print("Rules: ok")
	return ok


func _strings() -> bool:
	if Copy.t("perk.toast_held") != "Held {name}: {perk}":
		print("Strings: FAIL held toast key")
		return false
	if Copy.t("perk.riverside") == "perk.riverside":
		print("Strings: FAIL perk line missing")
		return false
	Copy.set_lang("ru")
	var ru := Copy.t("perk.riverside")
	var lost := Copy.t("perk.toast_lost")
	Copy.set_lang("en")
	if ru == "perk.riverside" or not ru.contains("гидропоники"):
		print("Strings: FAIL ru perk ", ru)
		return false
	if not lost.contains("больше нет"):
		print("Strings: FAIL ru lost toast ", lost)
		return false
	print("Strings: ok")
	return true


func _careful(catalog: Catalog) -> Dictionary:
	var lost := 0
	var bad := 0
	for run_seed in range(1, SEEDS + 1):
		var row: Dictionary = Bot.new().play(WEEKS, run_seed, "careful", catalog)
		var over := str(row.get("over", ""))
		if not row.get("errors", []).is_empty():
			bad += 1
			print("Careful seed %d errors %s" % [run_seed, str(row.errors)])
		if over != "time":
			lost += 1
			print("Careful seed %d %s" % [run_seed, over])
	var pct := 100.0 * float(lost) / float(SEEDS)
	var in_band := lost * 100 >= int(LOSS_LO * SEEDS) and lost * 100 <= int(LOSS_HI * SEEDS)
	# 15% of 60 is 9, 35% is 21. Integer counts, inclusive.
	in_band = lost >= 9 and lost <= 21
	return {"lost": lost, "pct": pct, "ok": in_band and bad == 0}
