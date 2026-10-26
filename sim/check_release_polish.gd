extends SceneTree

## RELEASE_POLISH RP1–RP5. HUD edge, map key, order tip plate, event band.
## Not a soft-dawn chip. No balance change.
##   godot --headless --path . -s res://sim/check_release_polish.gd


func _init() -> void:
	var failed := false
	if not _check_copy():
		failed = true
	if not _check_hud():
		failed = true
	if not _check_legend():
		failed = true
	if not _check_tips():
		failed = true
	if not _check_banner():
		failed = true
	if not _check_soft():
		failed = true
	if failed:
		print("RELEASE POLISH FAIL")
		quit(1)
		return
	print("RELEASE POLISH OK")
	quit(0)


func _check_copy() -> bool:
	Copy.set_lang("en")
	var bad: PackedStringArray = []
	var want := {
		"legend.open": "Map key",
		"legend.title": "Map key",
		"legend.close": "Close",
		"legend.warmth": "Warmth — how they lean",
		"legend.deals": "Deals — handshake steps",
		"legend.pressure": "Pressure — siege heat",
		"legend.goods": "Goods — weekly good flowing",
		"legend.leaflet": "Leaflet — loud propaganda dust",
		"legend.need": "Need — what they lack",
		"legend.focus": "Focus — outpost focus",
		"legend.flow": "Flow — good on the passage",
		"legend.rumor": "Rumor — dawn whisper",
	}
	for key in want:
		if Copy.t(key) != str(want[key]):
			bad.append("%s en '%s'" % [key, Copy.t(key)])
	if Copy.fill("event.chain_part", {"n": 2, "m": 3}) != "Part 2 of 3":
		bad.append("chain en")
	Copy.set_lang("ru")
	var ru := {
		"legend.open": "Условные обозначения",
		"legend.close": "Закрыть",
		"legend.warmth": "Тепло — куда они тянутся",
		"legend.goods": "Товар — что идёт за неделю",
		"legend.need": "Нужда — чего им не хватает",
		"legend.focus": "Фокус — упор заставы",
		"legend.rumor": "Слух — шёпот на рассвете",
	}
	for key in ru:
		if Copy.t(key) != str(ru[key]):
			bad.append("%s ru '%s'" % [key, Copy.t(key)])
	if Copy.fill("event.chain_part", {"n": 1, "m": 3}) != "Часть 1 из 3":
		bad.append("chain ru")
	Copy.set_lang("en")
	if not bad.is_empty():
		print("Copy: FAIL ", ", ".join(bad))
		return false
	print("Copy: ok")
	return true


func _check_hud() -> bool:
	var st = load("res://ui/station.gd").new()
	var panel: PanelContainer = st._top_bar()
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var bad: PackedStringArray = []
	if style == null or style.border_width_bottom != 1 or style.border_width_top != 0:
		bad.append("edge")
	elif not style.border_color.is_equal_approx(Color(st.PAPER_EDGE, 0.7)):
		bad.append("edge color %s" % style.border_color)
	if st.week_label.get_theme_font_size("font_size") != 22:
		bad.append("week")
	var food = st.chips.get("food", {}).get("value", null)
	if food == null or food.get_theme_font_size("font_size") != 20:
		bad.append("stock")
	var delta = st.chips.get("food", {}).get("delta", null)
	if delta == null or delta.get_theme_font_size("font_size") != 12:
		bad.append("delta")
	if st.hope_label == null or st.hope_label.get_theme_font_size("font_size") != 12:
		bad.append("meter label")
	elif not st.hope_label.get_theme_color("font_color").is_equal_approx(st.PAPER_MUTED):
		bad.append("meter ink")
	var track := st.hope_fill.get_parent() as ColorRect
	if track == null or not track.visible or track.custom_minimum_size.y < 5.0 or track.custom_minimum_size.y > 6.0:
		bad.append("track")
	elif not st.hope_fill.color.is_equal_approx(Color("d7a441")):
		bad.append("hope fill")
	if not st.dis_fill.color.is_equal_approx(Color("c4544a")):
		bad.append("discontent fill")
	if bad.is_empty():
		print("HUD: ok")
		return true
	print("HUD: FAIL ", ", ".join(bad))
	return false


func _check_legend() -> bool:
	var net = load("res://ui/network_view.gd").new()
	var keys: PackedStringArray = net.legend_row_keys()
	var bad: PackedStringArray = []
	for key in ["warmth", "deals", "pressure", "goods"]:
		if not keys.has(key):
			bad.append("missing " + key)
	if keys.has("focus") or keys.has("flow"):
		bad.append("hidden mark shown")
	var seen := {}
	for key in keys:
		if seen.has(key):
			bad.append("dup " + key)
		seen[key] = true
	net._build_legend()
	net._open_legend()
	if net.legend_panel == null or not net.legend_panel.visible:
		bad.append("open")
	var rows := 0
	if net.legend_rows != null:
		rows = net.legend_rows.get_child_count()
		for child in net.legend_rows.get_children():
			var mark := str(child.get_meta("legend_row", ""))
			if mark == "" or not keys.has(mark):
				bad.append("row " + mark)
	if rows != keys.size():
		bad.append("rows %d want %d" % [rows, keys.size()])
	if net.legend_button == null or net.legend_button.tooltip_text != Copy.t("legend.open"):
		bad.append("control")
	net._close_legend()
	if net.legend_panel.visible:
		bad.append("close")
	if bad.is_empty():
		print("Legend: ok ", ", ".join(keys))
		return true
	print("Legend: FAIL ", ", ".join(bad))
	return false


func _check_tips() -> bool:
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Tips: FAIL catalog")
		return false
	var game := Game.new()
	game.setup(catalog, 1, 40)
	game.orders_left = 0
	var blocked: String = game.order_block("trade", "")
	var net = load("res://ui/network_view.gd").new()
	var tip: String = net._order_tip(game, "trade", "", blocked)
	var bad: PackedStringArray = []
	if blocked == "" or tip == "":
		bad.append("empty '%s'" % tip)
	game.orders_left = 2
	game.trade_on = false
	game.opinions["exchange"] = 10
	game.stock.influence = 0
	var why: String = game.order_block("trade", "")
	var live: String = net._order_tip(game, "trade", "", why)
	if why.begins_with(Copy.t("Not enough influence.")) and not live.contains("need"):
		bad.append("influence tip '%s'" % live)
	if live == "":
		bad.append("live empty")
	var st = load("res://ui/station.gd").new()
	net.host = st
	var plate: StyleBoxFlat = net._order_tip_plate()
	var family: StyleBoxFlat = st._tip_plate_style()
	if plate == null or family == null or not plate.bg_color.is_equal_approx(family.bg_color):
		bad.append("plate")
	elif plate.bg_color.r > 0.2:
		bad.append("plate not dark")
	if bad.is_empty():
		print("Tips: ok")
		return true
	print("Tips: FAIL ", ", ".join(bad))
	return false


func _check_banner() -> bool:
	var st = load("res://ui/station.gd").new()
	var band: Control = st._event_banner({"id": "rp_bare_band", "rp_skip_art": true})
	var bad: PackedStringArray = []
	if band == null or band.custom_minimum_size.y < 72.0 or not bool(band.get_meta("banner", false)):
		bad.append("band")
	var src := FileAccess.get_file_as_string("res://ui/station.gd")
	var start := src.find("func _paint_dawn")
	var stop := src.find("func _choice_reason")
	if start < 0 or stop < start:
		bad.append("paint slice")
	else:
		var paint := src.substr(start, stop - start)
		if paint.find("_choice_reason") >= 0:
			bad.append("why doubled")
		if paint.find("separation\", 8") < 0 and paint.find("separation\", 8") < 0:
			bad.append("rhythm")
	if bad.is_empty():
		print("Banner: ok")
		return true
	print("Banner: FAIL ", ", ".join(bad))
	return false


func _check_soft() -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/release_polish.json"))
	if not (data is Dictionary):
		print("Soft: FAIL pack")
		return false
	var rows: Dictionary = data.get("by_key", {})
	for key in rows:
		if str(key).contains("dawn"):
			print("Soft: FAIL ", key)
			return false
	print("Soft: ok")
	return true
