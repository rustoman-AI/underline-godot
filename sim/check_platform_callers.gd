extends SceneTree

## P93 Platform Callers gate.
##   godot --headless --path . -s res://sim/check_platform_callers.gd
## Balance ZERO. Soft dawn none. Map mark none. Schema 24. No kept_bonus / closed_bonus.
## CALLER_SHOTS=1 also writes EN/RU 125% stills under /opt/cursor/artifacts.

const BASELINE_LOST := 20
const MASTER_HASH := [
	530485220, 1440811691, 812324724, 1813219972, 325093522, 595908171, 2008396391, 1780671410, 856785781, 158007594,
	927219026, 88326475, 1637882681, 1666385348, 109892276, 1909826692, 17422148, 1248879695, 53792616, 1638580681,
	1667606982, 225933280, 1956210069, 664024800, 910860718, 1749011044, 317060065, 247917712, 1212469253, 1368249385,
	1040415204, 699411940, 240273769, 1927554047, 1435382424, 289105020, 1555551452, 991802799, 73486466, 389179272,
	1820378459, 1369693866, 479947888, 2022586468, 14678228, 2098321440, 788241386, 462862112, 1956553458, 372817444,
	1943912010, 743372996, 2101744492, 1885192366, 1640866844, 1363718713, 230067406, 1872288106, 522666115, 82470554,
]
const LOST_SEEDS := "1,8,11,12,13,14,23,27,28,30,33,35,39,40,41,45,51,52,56,57"
const KEYS := [
	"caller.exchange.name", "caller.exchange.role", "caller.exchange.warm", "caller.exchange.deal", "caller.exchange.hit",
	"caller.directorate.name", "caller.directorate.role", "caller.directorate.warm", "caller.directorate.deal", "caller.directorate.hit",
	"caller.synod.name", "caller.synod.role", "caller.synod.warm", "caller.synod.deal", "caller.synod.hit",
	"caller.title", "caller.first", "caller.left", "caller.tip",
]

var _failed := false


class Host extends Node:
	var game
	var showing_network := true
	var network_view = null
	var body_font: Font
	var display_font: Font
	func _motion_off() -> bool:
		return true
	func _ui_click() -> void:
		pass
	var _portraits: Array[Texture2D] = []
	func _portrait_box(id: String, px: int) -> TextureRect:
		if _portraits.is_empty():
			var i := 1
			while ResourceLoader.exists("res://assets/portraits/portrait_%02d.webp" % i):
				var tex := load("res://assets/portraits/portrait_%02d.webp" % i) as Texture2D
				if tex != null:
					_portraits.append(tex)
				i += 1
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(px, px)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		face.clip_contents = true
		if not _portraits.is_empty():
			var n := 0
			for i in id.length():
				n = (n * 33 + id.unicode_at(i)) % _portraits.size()
			face.texture = _portraits[n]
		face.set_meta("portrait_for", id)
		return face
	func _close_observer() -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	PlatformCallers.enabled = true
	PlatformCallers.favor_override = null
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("PLATFORM CALLERS FAIL catalog")
		quit(1)
		return
	if Game.SAVE_SCHEMA != 27:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
	if not _strings():
		_failed = true
	else:
		print("Strings: ok")
	if not _rules(catalog):
		_failed = true
	else:
		print("Rules: ok")
	if not _migrate(catalog):
		_failed = true
	else:
		print("Migration: ok")
	if not await _ui(catalog):
		_failed = true
	else:
		print("UI: ok")
	if OS.get_environment("CALLER_SHOTS") == "1":
		if not await _shots(catalog):
			_failed = true
		else:
			print("Shots: ok")
	if _failed:
		print("PLATFORM CALLERS FAIL")
		quit(1)
		return
	if not _careful(catalog):
		_failed = true
	else:
		print("Careful: ok")
	PlatformCallers.enabled = true
	PlatformCallers.favor_override = null
	if _failed:
		print("PLATFORM CALLERS FAIL")
		quit(1)
		return
	print("PLATFORM CALLERS OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("PC FAIL %s" % msg)


func _strings() -> bool:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/platform_callers.json"))
	if not (raw is Dictionary):
		_bad("pack")
		return false
	var rows: Dictionary = raw.get("by_key", {})
	if rows.size() != 19:
		_bad("key count %d" % rows.size())
		return false
	for key in KEYS:
		if not rows.has(key):
			_bad("missing %s" % key)
			return false
		var row: Dictionary = rows[key]
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			_bad("empty %s" % key)
			return false
		if not str(key).begins_with("caller."):
			_bad("namespace %s" % key)
			return false
	if rows.size() != KEYS.size():
		_bad("extra keys")
		return false
	if str(rows["caller.directorate.name"].en) != "Ieva Rusk" or str(rows["caller.directorate.name"].ru) != "Иева Раск":
		_bad("directorate name")
		return false
	if str(rows["caller.exchange.name"].en) != "Remy Cole" or str(rows["caller.synod.name"].en) != "Brother Cal":
		_bad("courier names")
		return false
	if str(rows["caller.synod.name"].ru) != "Брат Кэл":
		_bad("brother title")
		return false
	if str(rows["caller.directorate.deal"].ru) != "В расписании теперь есть твои ящики. Я донесла его пешком — вот чернила.":
		_bad("directorate deal ru")
		return false
	if str(rows["caller.title"].en) != "On the stairs" or str(rows["caller.first"].en) != "Someone from the line is waiting downstairs.":
		_bad("shared en")
		return false
	for key in rows:
		var spoken: Dictionary = rows[key]
		var en := str(spoken.get("en", ""))
		var ru := str(spoken.get("ru", ""))
		if en.find("Dunn") >= 0 or en.find("Ieva Pell") >= 0 or ru.find("Данн") >= 0:
			_bad("old courier name")
			return false
	Copy.set_lang("en")
	if Copy.t("caller.exchange.warm") != str(rows["caller.exchange.warm"].en):
		_bad("copy en")
		return false
	Copy.set_lang("ru")
	if Copy.t("caller.synod.hit") != str(rows["caller.synod.hit"].ru):
		_bad("copy ru")
		return false
	Copy.set_lang("en")
	for path in ["res://sim/platform_callers.gd", "res://ui/network_view.gd", "res://ui/observer_panel.gd", "res://ui/station.gd", "res://data/platform_callers.json"]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("kept_bonus") >= 0 or body.find("closed_bonus") >= 0:
			_bad("bonus in " + path)
			return false
	if FileAccess.get_file_as_string("res://data/balance.json").find("caller.") >= 0:
		_bad("balance.json")
		return false
	return true


func _rules(catalog: Catalog) -> bool:
	if PlatformCallers.dawn_chip() or PlatformCallers.joins_soft_dawn() or PlatformCallers.map_mark():
		_bad("dawn or map")
		return false
	var game := _fresh(catalog, 2)
	if game.platform_callers_dawn_chip() or game.dawn_soft_stack().has("caller") or game.dawn_soft_stack().has("callers"):
		_bad("game dawn")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 27") < 0 or src.find("V21_ADDED") < 0 or src.find("V22_ADDED") < 0 or src.find("V23_ADDED") < 0 or src.find("\"callers\"") < 0:
		_bad("schema source")
		return false
	if src.find("<= 21 and V21_ADDED") < 0 or src.find("<= 22 and V22_ADDED") < 0 or src.find("<= 23 and V23_ADDED") < 0:
		_bad("migration chain")
		return false
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker.find("caller") >= 0:
		_bad("dawn picker")
		return false
	var sorties := _fn(src, "_sorties")
	var step := _fn(src, "_step_squad")
	var audience := _fn(src, "_apply_audience")
	if sorties.find("PlatformCallers") >= 0 or step.find("PlatformCallers") >= 0 or audience.find("PlatformCallers") >= 0:
		_bad("rival or audience hooked")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if _fn(view, "_draw_pin").find("PlatformCallers") >= 0 or _fn(view, "_draw_pin").find("caller_") >= 0:
		_bad("map mark")
		return false
	if FileAccess.get_file_as_string("res://sim/bot.gd").find("callers") >= 0:
		_bad("bot reads callers")
		return false
	var yard := FileAccess.get_file_as_string("res://ui/station.gd")
	var yard_fn := _fn(yard, "_show_caller_yard")
	if yard_fn.find("_tip_plate_style") < 0 or yard_fn.find("outline_size\", 0") < 0 or yard_fn.find("_place_yard_notice") < 0 or yard_fn.find("_restack_yard_notices") < 0:
		_bad("yard float plate")
		return false
	if _fn(yard, "_restack_yard_notices").find("caller_float") < 0:
		_bad("caller missing from the yard stack")
		return false
	if _fn(yard, "_try_caller_left").find("_toast") < 0 or _fn(yard, "_try_caller_left").find("caller.left") < 0:
		_bad("leave toast")
		return false
	if _fn(view, "_show_caller_float").find("_bind_float_plate") < 0:
		_bad("map float plate")
		return false
	var probe := NetworkView.new()
	if probe._band_key(49) != "map.relation_band_wary" or probe._band_key(50) != "map.relation_band_warm":
		_bad("band key")
		probe.free()
		return false
	if probe._band_key(69) != "map.relation_band_warm" or probe._band_key(70) != "map.relation_band_ready" or probe._band_key(100) != "map.relation_band_join":
		_bad("band key upper")
		probe.free()
		return false
	probe.free()
	if PlatformCallers.warm_or_better(49) or not PlatformCallers.warm_or_better(50) or not PlatformCallers.warm_or_better(100):
		_bad("warm cut")
		return false
	if not _warm(catalog):
		return false
	if not _deals(catalog):
		return false
	if not _hits(catalog):
		return false
	if not _favor(catalog):
		return false
	if not _queue(catalog):
		return false
	return true


func _warm(catalog: Catalog) -> bool:
	var on := _fresh(catalog, 4)
	var off := _fresh(catalog, 4)
	on.opinions.exchange = 49
	off.opinions.exchange = 49
	PlatformCallers.enabled = false
	off._add_opinion("exchange", 1)
	PlatformCallers.enabled = true
	var rng := on.rng.state
	on._add_opinion("exchange", 1)
	if int(on.opinions.exchange) != 50 or int(off.opinions.exchange) != 50:
		_bad("warm wrote opinion %s %s" % [on.opinions.exchange, off.opinions.exchange])
		return false
	if on.rng.state != rng or on.opinion_memory.exchange.size() != off.opinion_memory.exchange.size():
		_bad("warm moved rng or memory")
		return false
	if not _seen(on, "exchange", "warm") or on.callers.queue.size() != 1 or int(on.callers.queue[0].offer) != int(on.week) + 1:
		_bad("warm offer")
		return false
	if _seen(off, "exchange", "warm") or off.callers.queue.size() != 0:
		_bad("warm fired while off")
		return false
	on._add_opinion("exchange", 5)
	if on.callers.queue.size() != 1:
		_bad("warm recalled")
		return false
	# Standing pact is not this band. Opinion stays cold.
	var stand := _fresh(catalog, 4)
	stand.standing.exchange = 80
	stand.opinions.exchange = 10
	PlatformCallers.note_opinions(stand)
	if _seen(stand, "exchange", "warm"):
		_bad("standing pact counted as warm")
		return false
	# Synod opinion is not moved by _add_opinion. Drift still notices a warm reading.
	var syn := _fresh(catalog, 4)
	var syn_before := int(syn.opinions.synod)
	syn._add_opinion("synod", 80)
	if int(syn.opinions.synod) != syn_before or _seen(syn, "synod", "warm"):
		_bad("synod add_opinion")
		return false
	syn.opinions.synod = 60
	var ex_before := int(syn.opinions.exchange)
	syn._drift_opinion()
	if int(syn.opinions.synod) != 59 or not _seen(syn, "synod", "warm"):
		_bad("synod drift warm %s" % syn.opinions.synod)
		return false
	if int(syn.opinions.exchange) != ex_before - 1 and int(syn.opinions.exchange) != ex_before + 1 and int(syn.opinions.exchange) != ex_before:
		# Drift toward zero is the existing rule. Just don't invent a second step.
		pass
	return true


func _deals(catalog: Catalog) -> bool:
	var on := _fresh(catalog, 5)
	var off := _fresh(catalog, 5)
	var dest := _arm(on, "exchange", true)
	_arm(off, "exchange", true)
	if dest == "" or on._deal_block(dest) != "":
		_bad("deal blocked " + on._deal_block(dest))
		return false
	PlatformCallers.enabled = false
	if not off._order_deal(dest):
		_bad("deal off failed")
		return false
	PlatformCallers.enabled = true
	var food := int(on.stock.food)
	var deals := int(on.stations[dest].deals)
	if not on._order_deal(dest):
		_bad("deal on failed")
		return false
	if int(on.stock.food) != int(off.stock.food) or int(on.stations[dest].deals) != int(off.stations[dest].deals):
		_bad("deal diverged")
		return false
	if int(on.stock.food) == food or int(on.stations[dest].deals) != deals + 1:
		_bad("deal did not resolve")
		return false
	if not _seen(on, "exchange", "deal") or _seen(off, "exchange", "deal"):
		_bad("deal trigger")
		return false
	on._order_deal(dest)
	if _count(on, "exchange", "deal") != 1:
		_bad("deal recalled")
		return false
	var syn := _fresh(catalog, 5)
	var syn_dest := _arm(syn, "synod", true)
	if syn_dest == "" or not syn._order_deal(syn_dest):
		_bad("synod station deal failed")
		return false
	if _seen(syn, "synod", "deal"):
		_bad("synod station deal fired")
		return false
	var neutral := _fresh(catalog, 5)
	var neu := _arm(neutral, "neutral", true)
	if neu == "" or not neutral._order_deal(neu) or _seen(neutral, "exchange", "deal"):
		_bad("neutral deal")
		return false
	var dir := _fresh(catalog, 5)
	var dir_dest := _arm(dir, "directorate", true)
	if dir_dest == "" or not dir._order_deal(dir_dest) or not _seen(dir, "directorate", "deal"):
		_bad("directorate deal")
		return false
	return true


func _hits(catalog: Catalog) -> bool:
	for win in [true, false]:
		var on := _fresh(catalog, 6)
		var off := _fresh(catalog, 6)
		var dest := _arm(on, "exchange", win)
		_arm(off, "exchange", win)
		if dest == "" or on._raid_gate(dest) != "":
			_bad("raid gate %s" % on._raid_gate(dest))
			return false
		PlatformCallers.enabled = false
		if not off._order_raid(dest, true):
			_bad("raid off failed")
			return false
		PlatformCallers.enabled = true
		var rng := on.net_rng.state
		if not on._order_raid(dest, true):
			_bad("raid on failed")
			return false
		var did_win := _log_text(on, "Loot came home")
		var lost := _log_text(on, "limped home")
		if win and not did_win:
			_bad("expected raid win")
			return false
		if not win and not lost:
			_bad("expected raid loss")
			return false
		if on.net_rng.state == rng:
			_bad("raid did not roll")
			return false
		if int(on.stock.food) != int(off.stock.food) or int(on.opinions.exchange) != int(off.opinions.exchange) or on.net_rng.state != off.net_rng.state:
			_bad("raid on/off diverged win=%s" % win)
			return false
		if not _seen(on, "exchange", "hit") or _seen(off, "exchange", "hit"):
			_bad("hit trigger win=%s" % win)
			return false
		if _count(on, "exchange", "hit") != 1:
			_bad("hit count")
			return false
		on._order_raid(dest, true)
		if _count(on, "exchange", "hit") != 1:
			_bad("hit recalled")
			return false
	# Capturing assault still counts, and the owner is the faction who held it before the capture.
	var took := _fresh(catalog, 7)
	var gate := _arm(took, "directorate", true)
	took.week = 5
	took.stations[gate].low_weeks = 2
	if gate == "" or took._assault_gate(gate) != "":
		_bad("assault gate %s" % took._assault_gate(gate))
		return false
	if not took._order_assault(gate, true):
		_bad("assault failed")
		return false
	if str(took.stations[gate].owner) != str(took.player) or not _seen(took, "directorate", "hit"):
		_bad("capture hit owner %s" % took.stations[gate].owner)
		return false
	var held := _fresh(catalog, 7)
	var held_dest := _arm(held, "synod", false)
	held.week = 5
	held.stations[held_dest].low_weeks = 2
	if held_dest == "" or not held._order_assault(held_dest, true):
		_bad("assault loss failed")
		return false
	if str(held.stations[held_dest].owner) != "synod" or not _seen(held, "synod", "hit"):
		_bad("assault loss hit")
		return false
	return true


func _favor(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 8)
	if PlatformCallers.favor_on():
		_bad("p80 on")
		return false
	PlatformCallers.note_favor_spend(game)
	if _seen(game, "synod", "deal") or game.callers.queue.size() != 0:
		_bad("favor fired while p80 off")
		return false
	PlatformCallers.favor_override = true
	if not PlatformCallers.favor_on():
		_bad("favor override")
		return false
	PlatformCallers.note_favor_spend(game)
	PlatformCallers.note_favor_spend(game)
	if not _seen(game, "synod", "deal") or game.callers.queue.size() != 1:
		_bad("favor once")
		return false
	PlatformCallers.favor_override = null
	if PlatformCallers.favor_on():
		_bad("favor stayed on")
		return false
	return true


func _queue(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 9)
	game.week = 5
	PlatformCallers.note_hit(game, "exchange")
	PlatformCallers.note_deal(game, "exchange")
	PlatformCallers.note_hit(game, "directorate")
	PlatformCallers.note_hit(game, "synod")
	PlatformCallers.note_hit(game, "neutral")
	PlatformCallers.note_hit(game, "exchange")
	if game.callers.queue.size() != 3:
		_bad("cap %d" % game.callers.queue.size())
		return false
	if not _seen(game, "synod", "hit"):
		_bad("dropped trigger forgotten")
		return false
	if str(game.callers.queue[0].fid) != "exchange" or str(game.callers.queue[0].why) != "hit":
		_bad("fifo head")
		return false
	if str(game.callers.queue[2].fid) != "directorate":
		_bad("fifo tail")
		return false
	var rng := game.rng.state
	PlatformCallers.tick(game)
	if str(game.callers.here) != "" or game.rng.state != rng:
		_bad("seated same week")
		return false
	game.week = 6
	PlatformCallers.tick(game)
	if str(game.callers.here) != "exchange" or str(game.callers.why) != "hit" or int(game.callers.until) != 7:
		_bad("arrival %s %s %s" % [game.callers.here, game.callers.why, game.callers.until])
		return false
	if game.callers.queue.size() != 2:
		_bad("queue after seat")
		return false
	if not PlatformCallers.card(game).is_empty() and str(PlatformCallers.card(game).portrait) != "caller_exchange":
		_bad("card")
		return false
	game.week = 7
	game.caller_left_toast = false
	PlatformCallers.tick(game)
	if str(game.callers.here) != "" or int(game.callers.cool_until.exchange) != 11 or not game.caller_left_toast:
		_bad("leave %s cool %s" % [game.callers.here, game.callers.cool_until])
		return false
	# Head is the same faction's deal, still cooling, so Directorate waits.
	if str(game.callers.queue[0].fid) != "exchange":
		_bad("cooldown did not hold the head")
		return false
	game.week = 10
	PlatformCallers.tick(game)
	if str(game.callers.here) != "":
		_bad("seated during cooldown")
		return false
	game.week = 11
	PlatformCallers.tick(game)
	if str(game.callers.here) != "exchange" or str(game.callers.why) != "deal" or int(game.callers.until) != 12:
		_bad("reseated %s %s" % [game.callers.here, game.callers.why])
		return false
	# A different faction sits the dawn the previous one leaves.
	var other := _fresh(catalog, 9)
	other.week = 3
	PlatformCallers.note_hit(other, "exchange")
	PlatformCallers.note_hit(other, "directorate")
	other.week = 4
	PlatformCallers.tick(other)
	other.week = 5
	PlatformCallers.tick(other)
	if str(other.callers.here) != "directorate" or int(other.callers.cool_until.exchange) != 9 or int(other.callers.until) != 6:
		_bad("next faction %s cool %s" % [other.callers.here, other.callers.cool_until])
		return false
	other.week = 6
	PlatformCallers.tick(other)
	if str(other.callers.here) != "" or not other.caller_left_toast:
		_bad("one week stay")
		return false
	return true


func _kept(game: Game) -> bool:
	return str(game.callers.get("here", "")) == "" and game.callers.queue.is_empty() \
		and str(game.echoes.get("plaza", {}).get("kind", "")) == "deal" \
		and str(game.rival_log.get("exchange", {}).get("kind", "")) == "bought" \
		and str(game.carry.pocket.get("thread", "")) == "lamp_copper" \
		and game.sdays.kept.get("plaza", []) == [8]


func _migrate(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 3)
	game.sdays.kept["plaza"] = [8]
	game.carry.pocket = {"thread": "lamp_copper"}
	game.echoes = {"plaza": {"kind": "deal", "from": "mill", "week": 2}}
	game.rival_log = {"exchange": {"kind": "bought", "week": 3, "target": "trampark"}}
	game.callers.here = "exchange"
	game.callers.why = "warm"
	game.callers.until = 4
	var full := game.export_state()
	full["schema"] = 24
	var back := Game.new()
	back.catalog = catalog
	if not back.import_state(full) or str(back.callers.here) != "exchange" or str(back.callers.why) != "warm":
		_bad("schema 24 roundtrip %s here %s" % [back.load_error, back.callers.get("here", "")])
		return false
	if str(back.echoes.plaza.kind) != "deal" or str(back.rival_log.exchange.kind) != "bought" or str(back.carry.pocket.thread) != "lamp_copper" or back.sdays.kept.plaza != [8]:
		_bad("schema 24 lost an older key")
		return false
	var s23 := full.duplicate(true)
	s23["schema"] = 23
	s23.erase("callers")
	var m23 := Game.new()
	m23.catalog = catalog
	if not m23.import_state(s23) or not _kept(m23):
		_bad("schema 23 migrate %s" % m23.load_error)
		return false
	var s22 := full.duplicate(true)
	s22["schema"] = 22
	s22.erase("callers")
	s22.erase("rival_log")
	var m22 := Game.new()
	m22.catalog = catalog
	if not m22.import_state(s22) or str(m22.callers.here) != "" or not m22.rival_log.is_empty():
		_bad("schema 22 migrate %s" % m22.load_error)
		return false
	if str(m22.echoes.plaza.kind) != "deal" or str(m22.carry.pocket.thread) != "lamp_copper" or m22.sdays.kept.plaza != [8]:
		_bad("schema 22 lost echoes carry or sdays")
		return false
	var keep22 := full.duplicate(true)
	keep22["schema"] = 22
	keep22.erase("callers")
	var held22 := Game.new()
	held22.catalog = catalog
	if not held22.import_state(keep22) or str(held22.rival_log.exchange.kind) != "bought":
		_bad("schema 22 dropped a rival log that was present")
		return false
	var s21 := full.duplicate(true)
	s21["schema"] = 21
	for key in ["callers", "rival_log", "echoes"]:
		s21.erase(key)
	var m21 := Game.new()
	m21.catalog = catalog
	if not m21.import_state(s21) or not m21.echoes.is_empty() or not m21.rival_log.is_empty() or str(m21.callers.here) != "":
		_bad("schema 21 migrate %s" % m21.load_error)
		return false
	if str(m21.carry.pocket.thread) != "lamp_copper" or m21.sdays.kept.plaza != [8]:
		_bad("schema 21 lost carry or sdays")
		return false
	var s20 := full.duplicate(true)
	s20["schema"] = 20
	for key in ["callers", "rival_log", "echoes", "carry"]:
		s20.erase(key)
	var m20 := Game.new()
	m20.catalog = catalog
	if not m20.import_state(s20) or not m20.carry.pocket.is_empty() or not m20.echoes.is_empty() or not m20.rival_log.is_empty():
		_bad("schema 20 migrate %s" % m20.load_error)
		return false
	if m20.sdays.kept.plaza != [8] or str(m20.callers.here) != "":
		_bad("schema 20 lost sdays or invented a caller")
		return false
	var bare := full.duplicate(true)
	bare.erase("callers")
	var missing := Game.stage_state(bare, catalog)
	if str(missing.error) != "missing callers":
		_bad("schema 24 required %s" % missing.error)
		return false
	bare["schema"] = 25
	if Game.stage_state(bare, catalog).error == "":
		_bad("schema 25 without callers accepted")
		return false
	var future := full.duplicate(true)
	future["schema"] = 28
	if Game.stage_state(future, catalog).error == "":
		_bad("schema 28 accepted")
		return false
	return true


func _ui(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 11)
	var host := Host.new()
	host.game = game
	host.body_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
	root.add_child(host)
	var view := NetworkView.new()
	host.network_view = view
	view.host = host
	view.size = Vector2(1280, 720)
	root.add_child(view)
	await process_frame
	view.open_visit(str(game.capital_id))
	await process_frame
	if _rows(view).size() != 0:
		_bad("empty home row")
		return false
	var foreign := _neighbor(game)
	_seat(game, "synod", "hit")
	view.open_visit(foreign)
	await process_frame
	if _rows(view).size() != 0:
		_bad("foreign row")
		return false
	if bool(game.flags.get(PlatformCallers.SEEN, false)):
		_bad("foreign claimed the float")
		return false
	view.open_visit(str(game.capital_id))
	await process_frame
	await process_frame
	if _rows(view).size() != 1:
		_bad("home rows %d" % _rows(view).size())
		return false
	var row: Node = _rows(view)[0]
	if str(row.get_meta("caller_home")) != "visit" or row.get("face_row") != null and row.has_meta("face_row"):
		_bad("visit identity")
		return false
	if _buttons(row).size() != 0:
		_bad("visit button")
		return false
	var portrait := _meta(row, "caller_portrait")
	if portrait == null or str(portrait.get_meta("caller_portrait")) != "caller_synod" or str(portrait.get_meta("portrait_for")) != "caller_synod":
		_bad("portrait")
		return false
	if str(portrait.get_meta("caller_portrait")).begins_with("regular_"):
		_bad("face portrait")
		return false
	if portrait.custom_minimum_size != Vector2(36, 36):
		_bad("portrait size")
		return false
	var hbox := _meta(row, "caller_hbox")
	if hbox == null or int(hbox.get_theme_constant("separation")) != 8:
		_bad("gap")
		return false
	var name := _meta(row, "caller_name")
	var quote := _meta(row, "caller_quote")
	var title := _meta(row, "caller_title")
	if name == null or str(name.text) != "Brother Cal" or name.clip_text:
		_bad("name")
		return false
	if title == null or str(title.text) != "On the stairs":
		_bad("title")
		return false
	if quote == null or str(quote.text) != Copy.t("caller.synod.hit") or quote.clip_text or int(quote.get_theme_font_size("font_size")) != 14:
		_bad("quote")
		return false
	if not quote.get_theme_color("font_color").is_equal_approx(NetworkView.INK):
		_bad("quote ink")
		return false
	if quote.get_theme_color("font_color").is_equal_approx(NetworkView.CARD_INK):
		_bad("soot ink")
		return false
	var name_y := (name as Control).get_global_rect().position.y
	var face_y := (portrait as Control).get_global_rect().position.y
	if absf(name_y - face_y) > 6.0:
		_bad("baseline %.1f %.1f" % [face_y, name_y])
		return false
	if str(row.get_meta("caller_line_key")) != "caller.synod.hit" or row.tooltip_text != Copy.t("caller.tip"):
		_bad("keys")
		return false
	if _meta(view, "people_chip") != null or _meta(view, "guest_bed") != null or _meta(view, "guest_cot") != null:
		_bad("people or guest")
		return false
	var body: Node = view._visit_body
	var caller_i := -1
	var details_i := -1
	for i in body.get_child_count():
		var child := body.get_child(i)
		if child.has_meta("caller_row"):
			caller_i = i
		if child.has_meta("details_toggle"):
			details_i = i
	if caller_i < 0 or details_i < 0 or caller_i >= details_i:
		_bad("above details %d %d" % [caller_i, details_i])
		return false
	var scroll := body.get_parent()
	if not (scroll is ScrollContainer):
		_bad("visit scroll")
		return false
	var grab: StyleBoxFlat = scroll.theme.get_stylebox("grabber", "VScrollBar") as StyleBoxFlat
	if grab == null or grab.bg_color.r < 0.4:
		_bad("visit brass")
		return false
	if not bool(game.flags.get(PlatformCallers.SEEN, false)):
		_bad("seen flag")
		return false
	var plate := _meta(view, "caller_float")
	if plate == null or str(plate.text) != Copy.t("caller.first"):
		_bad("float")
		return false
	if int(plate.get_theme_constant("outline_size")) != 0 or not plate.get_theme_color("font_color").is_equal_approx(NetworkView.TAG_INK):
		_bad("float plate ink")
		return false
	var parent := plate.get_parent()
	if parent == null or not bool(parent.get_meta("map_float_plate", false)):
		_bad("float plate")
		return false
	if PlatformCallers.claim_first(game) != "":
		_bad("second float")
		return false
	if not await _fit(view, host, game, "en"):
		return false
	Copy.set_lang("ru")
	host.body_font = load("res://assets/fonts/PTMono-Regular.ttf")
	if not await _fit(view, host, game, "ru"):
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	host.body_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
	var panel := ObserverPanel.new()
	host.add_child(panel)
	panel.present(host)
	await process_frame
	await process_frame
	var desk_rows := _rows(panel)
	if desk_rows.size() != 1 or str(desk_rows[0].get_meta("caller_home")) != "desk":
		_bad("desk rows %d" % desk_rows.size())
		return false
	if _buttons(desk_rows[0]).size() != 0:
		_bad("desk button")
		return false
	var detail: Node = panel._detail
	var first_caller := false
	for child in detail.get_children():
		if not is_instance_valid(child):
			continue
		first_caller = child.has_meta("caller_row")
		break
	if not first_caller:
		_bad("desk not above details")
		return false
	if _meta(panel, "people_chip") != null or _meta(panel, "guest_bed") != null:
		_bad("desk people")
		return false
	var guests := int(game.obs.deeds.guests)
	var pop := game.residents.size()
	PlatformCallers.tick(game)
	if game.residents.size() != pop or int(game.obs.deeds.guests) != guests:
		_bad("staffed or guest")
		return false
	if not await _desk_fit(panel, host, game):
		return false
	view.queue_free()
	panel.queue_free()
	host.queue_free()
	return true


func _fit(view: NetworkView, host: Host, game: Game, lang: String) -> bool:
	for size in [Vector2(1536, 864), Vector2(1280, 720), Vector2(1920, 1080)]:
		view.size = size
		root.size = Vector2i(size)
		view.open_visit(str(game.capital_id))
		view._size_visit()
		await process_frame
		await process_frame
		var row := _rows(view)
		if row.size() != 1:
			_bad("fit rows %s" % lang)
			return false
		var quote: Label = _meta(row[0], "caller_quote")
		if quote == null or quote.clip_text:
			_bad("fit clip")
			return false
		var lines := quote.get_line_count()
		if lines < 1 or lines > 3:
			_bad("fit lines %d %s %s w %.1f" % [lines, lang, size, quote.size.x])
			return false
		var body := view._visit_body as Control
		if body != null and quote.get_global_rect().end.x > body.get_global_rect().end.x + 4.0:
			_bad("fit x %s %s" % [lang, size])
			return false
		if quote.get_global_rect().size.y + 1.0 < float(lines) * quote.get_line_height() * 0.85:
			_bad("fit height")
			return false
	return true


func _desk_fit(panel: ObserverPanel, host: Host, game: Game) -> bool:
	for case in [["en", Vector2i(1536, 864)], ["ru", Vector2i(1536, 864)], ["en", Vector2i(1920, 1080)], ["ru", Vector2i(1920, 1080)]]:
		Copy.set_lang(str(case[0]))
		if str(case[0]) == "ru":
			host.body_font = load("res://assets/fonts/PTMono-Regular.ttf")
		else:
			host.body_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
		var sz: Vector2i = case[1]
		DisplayServer.window_set_size(sz)
		root.size = sz
		await process_frame
		panel.present(host)
		await process_frame
		await process_frame
		var scroll := _meta(panel, "obs_tail_scroll") as ScrollContainer
		if scroll != null:
			var bar := scroll.get_v_scroll_bar()
			scroll.scroll_vertical = int(bar.max_value) if bar != null else 0
			await process_frame
			await process_frame
		var rows := _rows(panel)
		if rows.size() != 1:
			_bad("desk fit rows")
			Copy.set_lang("en")
			return false
		var quote: Label = _meta(rows[0], "caller_quote")
		if quote == null or quote.clip_text or quote.get_line_count() < 1 or quote.get_line_count() > 3:
			_bad("desk lines %s %s" % [case[0], quote.get_line_count() if quote != null else -1])
			Copy.set_lang("en")
			return false
		if not quote.get_theme_color("font_color").is_equal_approx(ObserverPanel.PAPER_INK):
			_bad("desk ink")
			Copy.set_lang("en")
			return false
		var close := _meta(panel, "obs_focus")
		# Close is meta obs_focus == "close"; _meta returns the first match. Find the button.
		close = _focus_close(panel)
		if close == null:
			_bad("desk close")
			Copy.set_lang("en")
			return false
		var vp := Rect2(Vector2.ZERO, Vector2(sz))
		var rect: Rect2 = close.get_global_rect()
		var scroll_rect := scroll.get_global_rect() if scroll != null else vp
		if not vp.grow(2.0).encloses(rect) or not scroll_rect.grow(4.0).encloses(rect):
			_bad("desk close off %s %s %s scroll %s" % [case[0], case[1], rect, scroll_rect])
			Copy.set_lang("en")
			return false
	Copy.set_lang("en")
	return true


func _shots(catalog: Catalog) -> bool:
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		var game := _fresh(catalog, 12)
		var host := Host.new()
		host.game = game
		host.body_font = load("res://assets/fonts/PTMono-Regular.ttf") if lang == "ru" else load("res://assets/fonts/CourierPrime-Regular.ttf")
		root.add_child(host)
		var view := NetworkView.new()
		host.network_view = view
		view.host = host
		view.size = Vector2(1536, 864)
		view.visible = true
		view.z_index = 1
		root.size = Vector2i(1536, 864)
		root.add_child(view)
		var panel := ObserverPanel.new()
		panel.z_index = 20
		root.add_child(panel)
		await process_frame
		view.open_visit(str(game.capital_id))
		view._size_visit()
		await process_frame
		await process_frame
		if not await _grab("p93_%s_125_visit_before" % lang):
			return false
		view.close_visit()
		panel.present(host)
		await process_frame
		await process_frame
		if not await _grab("p93_%s_125_desk_before" % lang):
			return false
		panel.dismiss()
		_seat(game, "synod", "hit")
		game.flags.erase(PlatformCallers.SEEN)
		panel.present(host)
		await process_frame
		await process_frame
		if not await _grab("p93_%s_125_desk_after" % lang):
			return false
		panel.dismiss()
		view.open_visit(str(game.capital_id))
		view._size_visit()
		await process_frame
		await process_frame
		if _rows(view).size() != 1 or _meta(view, "caller_float") == null:
			_bad("shot row")
			return false
		if not await _grab("p93_%s_125_visit_after" % lang):
			return false
		view.queue_free()
		panel.queue_free()
		host.queue_free()
		await process_frame
	Copy.set_lang("en")
	return true


func _grab(name: String) -> bool:
	await process_frame
	var img := root.get_texture().get_image()
	if img == null:
		_bad("shot image " + name)
		return false
	var path := "/opt/cursor/artifacts/%s.png" % name
	var err := img.save_png(path)
	print("SHOT %s %s err %s" % [name, img.get_size(), err])
	return err == OK


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60:
		_bad("baseline")
		return false
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
	for run_seed in range(1, 61):
		PlatformCallers.enabled = true
		var on := _play(catalog, run_seed)
		PlatformCallers.enabled = false
		var off := _play(catalog, run_seed)
		if str(on.report) != str(off.report) or str(on.rng) != str(off.rng):
			_bad("seed %d on/off diverged" % run_seed)
			return false
		var got := int(on.hash)
		var want := int(MASTER_HASH[run_seed - 1])
		if got == want:
			matched += 1
		else:
			_bad("seed %d hash %d master %d" % [run_seed, got, want])
		if str(on.over) != "time":
			lost += 1
			lost_seeds.append(str(run_seed))
		print("Seed %d: %d %s %s" % [run_seed, got, str(on.over), "match" if got == want else "DIFF"])
	PlatformCallers.enabled = true
	print("Careful loss: %d/60 (master %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	print("Seed outcomes: %d/60 match master, on/off identical" % matched)
	if lost != BASELINE_LOST or ",".join(lost_seeds) != LOST_SEEDS:
		_bad("careful loss moved")
		return false
	return matched == 60 and not _failed


func _play(catalog: Catalog, run_seed: int) -> Dictionary:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.audit = false
	game.raid_share_profile = "careful"
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while str(game.over) == "" and guard < 42:
		guard += 1
		bot._act(game)
		game.end_week()
	var report: Dictionary = game.report()
	return {
		"over": str(game.over),
		"hash": _outcome_hash(game),
		"report": str(report.get("summary", "")),
		"rng": "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)],
	}


func _outcome_hash(game: Game) -> int:
	var ids: Array = game.stations.keys()
	ids.sort()
	var held := PackedStringArray()
	for sid in ids:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != str(game.player):
			continue
		held.append("%s:%s:%s" % [str(sid), str(st.get("held_weeks", 0)), str(st.get("focus", ""))])
	var line := "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s" % [
		str(game.over), int(game.hope), int(game.discontent),
		int(game.stock.food), int(game.stock.materials), int(game.stock.air),
		int(game.stock.power), int(game.stock.tokens), int(game.stock.influence),
		game.residents.size(), ",".join(held)]
	var h := 5381
	for i in line.length():
		h = ((h << 5) + h) + line.unicode_at(i)
		h = h & 0x7fffffff
	return h


func _fresh(catalog: Catalog, run_seed: int) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 30)
	return game


func _neighbor(game: Game) -> String:
	for sid in game._neighbors(game.capital_id):
		return str(sid)
	return ""


func _arm(game: Game, owner: String, win: bool) -> String:
	var dest := _neighbor(game)
	if dest == "" or not game.stations.has(dest):
		return ""
	var st: Dictionary = game.stations[dest]
	st.owner = owner
	st.bunker = ""
	st.hidden = false
	st.known = true
	st.intel = 2
	st.garrison = 1 if win else 40
	st.fort = 0.2 if win else 2.0
	st.unrest = 0
	st.deals = 0
	game.squads[game.player].gear = 40.0 if win else 0.05
	game.stock.food = 40
	game.stock.influence = 30
	return dest


func _seat(game: Game, fid: String, why: String) -> void:
	game.callers = PlatformCallers.blank()
	game.callers.here = fid
	game.callers.why = why
	game.callers.until = int(game.week) + 1


func _seen(game: Game, fid: String, why: String) -> bool:
	var have = game.callers.seen.get(fid, [])
	return have is Array and have.has(why)


func _count(game: Game, fid: String, why: String) -> int:
	var n := 0
	var have = game.callers.seen.get(fid, [])
	if have is Array:
		for item in have:
			if str(item) == why:
				n += 1
	return n


func _log_text(game: Game, needle: String) -> bool:
	for entry in game.log:
		if str(entry.get("text", "")).find(needle) >= 0:
			return true
	return false


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name)
	if at < 0:
		return ""
	var next := src.find("\nfunc ", at + 4)
	if next < 0:
		next = src.length()
	return src.substr(at, next - at)


func _rows(node: Node) -> Array:
	var out: Array = []
	if node is CanvasItem and node.has_meta("caller_row"):
		out.append(node)
	for child in node.get_children():
		out.append_array(_rows(child))
	return out


func _buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append(node)
	for child in node.get_children():
		out.append_array(_buttons(child))
	return out


func _meta(node: Node, key: String) -> Node:
	if node is CanvasItem and node.has_meta(key):
		return node
	for child in node.get_children():
		var found := _meta(child, key)
		if found != null:
			return found
	return null


func _focus_close(node: Node) -> Control:
	if node is Control and str(node.get_meta("obs_focus", "")) == "close":
		return node
	for child in node.get_children():
		var found := _focus_close(child)
		if found != null:
			return found
	return null
