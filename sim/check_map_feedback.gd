extends SceneTree

## P22 feedback gate. Numbers stay on the old formulas; this only checks the report.
##   godot --headless --path . -s res://sim/check_map_feedback.gd


func _init() -> void:
	var failed := false
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_strings():
		failed = true
	if not _check_bands():
		failed = true
	if not _check_propaganda(catalog):
		failed = true
	if not _check_envoy(catalog):
		failed = true
	if not _check_deal(catalog):
		failed = true
	if not _check_join(catalog):
		failed = true
	if not _check_queue(catalog):
		failed = true
	if failed:
		print("MAP FEEDBACK FAIL")
		quit(1)
		return
	print("MAP FEEDBACK OK")
	quit(0)


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("order.strike_deal") != "Strike a deal":
		print("Strings: FAIL strike en ", Copy.t("order.strike_deal"))
		return false
	if Copy.t("order.open_trade_faction") != "Open trade with the Exchange":
		print("Strings: FAIL faction en")
		return false
	var toast := Copy.fill("order.toast_propaganda", {"station": "Jay St", "preview": 12})
	if toast != "Propaganda → Jay St · Sympathy ~+12":
		print("Strings: FAIL toast ", toast)
		return false
	if toast.length() > 72:
		print("Strings: FAIL toast length")
		return false
	var long := Copy.clip("x".repeat(80))
	if long.length() != 72 or not long.ends_with("…"):
		print("Strings: FAIL clip ", long.length())
		return false
	var sympathy := Copy.fill("order.report_sympathy", {"before": 48, "after": 60, "gain": 12})
	if sympathy != "Sympathy 48 → 60 (+12).":
		print("Strings: FAIL sympathy ", sympathy)
		return false
	var need := Copy.fill("order.report_need", {"need": "food", "old": 40, "new": 60})
	if need != "food: 40% → 60%.":
		print("Strings: FAIL need ", need)
		return false
	Copy.set_lang("ru")
	if Copy.t("order.strike_deal") != "Заключить сделку":
		print("Strings: FAIL strike ru ", Copy.t("order.strike_deal"))
		return false
	if Copy.t("order.open_trade_faction") != "Открыть торговлю с Биржей":
		print("Strings: FAIL faction ru")
		return false
	var fem := Copy.fill("order.report_propaganda_body", {"name": "Инес", "fem": true})
	if fem != "Инес провёла неделю на платформе.":
		print("Strings: FAIL fem ", fem)
		return false
	var male := Copy.fill("order.report_deal_body", {"name": "Джона", "n": 2, "fem": false})
	if male != "Джона заключил сделку 2 из 3.":
		print("Strings: FAIL male ", male)
		return false
	if Copy.t("map.passage_open") != "Тоннель во двор открыт.":
		print("Strings: FAIL passage ru")
		return false
	if Copy.t("map.relation_band_warm") != "Тепло":
		print("Strings: FAIL band ru")
		return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_bands() -> bool:
	var view := NetworkView.new()
	var expect := {10: "6f8494", 19: "6f8494", 20: "8c8170", 49: "8c8170", 50: "c4a574", 69: "c4a574", 70: "e2a63a", 99: "e2a63a"}
	for sympathy in expect:
		var got := view._sympathy_band(int(sympathy)).to_html(false)
		if got != str(expect[sympathy]):
			print("Bands: FAIL %s -> %s" % [sympathy, got])
			return false
	if view._sympathy_band(100).to_html(false) != "ff7a2f":
		print("Bands: FAIL join ", view._sympathy_band(100))
		return false
	if view._sympathy_band(80) == NetworkView.ORDER_RED:
		print("Bands: FAIL ready is ORDER_RED")
		return false
	if view._order_title("trade", "library") != "order.strike_deal":
		print("Bands: FAIL station title")
		return false
	if view._order_title("trade", "") != "order.open_trade_faction":
		print("Bands: FAIL faction title")
		return false
	if view._order_title("envoy") != "Send envoy":
		print("Bands: FAIL envoy title")
		return false
	print("Bands: ok")
	return true


func _neighbor(game: Game) -> String:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != "neutral":
			continue
		if str(st.get("bunker", "")) != "" or bool(st.get("hidden", false)):
			continue
		if game.borders_player(str(sid)):
			return str(sid)
	return ""


func _check_propaganda(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Propaganda: FAIL no neighbor")
		return false
	if int(game.bal.propaganda_influence) != 6 or float(game.bal.sympathy_base) != 12.0:
		print("Propaganda: FAIL balance retune")
		return false
	var st: Dictionary = game.stations[sid]
	st.sympathy = 40
	var before_hope := int(game.hope)
	var before_dis := int(game.discontent)
	var before_inf := int(game.stock.influence)
	var preview := game.sympathy_preview(sid)
	if not game._order_propaganda(sid):
		print("Propaganda: FAIL order")
		return false
	var note: Dictionary = game.last_order_note
	if int(note.gain) != preview or int(note.before_sympathy) != 40 or int(note.after_sympathy) != 40 + preview:
		print("Propaganda: FAIL note ", note)
		return false
	if int(st.sympathy) != 40 + preview:
		print("Propaganda: FAIL sympathy ", st.sympathy)
		return false
	if int(game.stock.influence) != before_inf - 6:
		print("Propaganda: FAIL cost ", game.stock.influence)
		return false
	if int(game.hope) != before_hope or int(game.discontent) != before_dis:
		print("Propaganda: FAIL meters moved")
		return false
	var want_chip := int(note.after_sympathy) >= 70
	var chip := int(st.get("leaflet_until", 0)) == int(game.week) + 2
	if chip != want_chip:
		print("Propaganda: FAIL leaflet ", st.get("leaflet_until", 0), " after ", note.after_sympathy)
		return false
	if game.order_cost("propaganda").influence != 6 or game.order_cost("envoy").influence != 3 or game.order_cost("trade").influence != 4:
		print("Propaganda: FAIL order_cost")
		return false
	print("Propaganda: ok +%d" % preview)
	return true


func _check_envoy(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _neighbor(game)
	var st: Dictionary = game.stations[sid]
	st.sympathy = 10
	var need_id := game._lowest_need(st)
	var need_before := game._need_fill(st, need_id)
	var before_inf := int(game.stock.influence)
	if not game._order_envoy(sid):
		print("Envoy: FAIL order")
		return false
	var note: Dictionary = game.last_order_note
	var expect := maxi(2, int(round(float(game.sympathy_preview(sid)) * 0.35)))
	if str(note.kind) != "envoy" or str(note.need_id) != need_id:
		print("Envoy: FAIL kind ", note)
		return false
	if not is_equal_approx(float(note.need_before), need_before):
		print("Envoy: FAIL need before")
		return false
	if not is_equal_approx(float(note.need_after), clampf(need_before + 0.2, 0.0, 1.0)):
		print("Envoy: FAIL need bump ", note.need_before, " ", note.need_after)
		return false
	if int(note.gain) != expect or int(note.after_sympathy) != 10 + expect:
		print("Envoy: FAIL gain ", note.gain, " expected ", expect)
		return false
	if int(game.stock.influence) != before_inf - 3:
		print("Envoy: FAIL cost")
		return false
	var blocks: Array = game.order_report_blocks(note)
	var saw_need := false
	for block in blocks:
		if str(block.role) == "need" and str(block.text).contains("%"):
			saw_need = true
	if not saw_need:
		print("Envoy: FAIL need line ", blocks)
		return false
	print("Envoy: ok +%d" % expect)
	return true


func _check_deal(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _neighbor(game)
	var st: Dictionary = game.stations[sid]
	var before_sym := int(st.sympathy)
	var need_id := game._lowest_need(st)
	var need_before := game._need_fill(st, need_id)
	var before_inf := int(game.stock.influence)
	if not game._order_deal(sid):
		print("Deal: FAIL order")
		return false
	var note: Dictionary = game.last_order_note
	if int(note.gain) != 0 or int(note.deals) != 1 or bool(note.joined):
		print("Deal: FAIL note ", note)
		return false
	if int(st.deals) != 1 or not bool(st.passage) or int(st.sympathy) != before_sym:
		print("Deal: FAIL state ", st.deals, " ", st.passage, " ", st.sympathy)
		return false
	if not is_equal_approx(float(note.need_after), clampf(need_before + 0.25, 0.0, 1.0)):
		print("Deal: FAIL need ", note.need_after)
		return false
	if int(game.stock.influence) != before_inf - 4:
		print("Deal: FAIL cost")
		return false
	var lines := game.order_report_lines(note)
	var joined_text := "\n".join(lines)
	if not joined_text.contains("Passage to the yard is open."):
		print("Deal: FAIL passage line ", joined_text)
		return false
	if joined_text.contains("Sympathy"):
		print("Deal: FAIL sympathy line on a zero gain")
		return false
	print("Deal: ok")
	return true


func _check_join(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _neighbor(game)
	var st: Dictionary = game.stations[sid]
	game.week = 5
	st.deals = 2
	st.sympathy = 30
	var before_hope := int(game.hope)
	if not game._order_deal(sid):
		print("Join: FAIL order")
		return false
	var note: Dictionary = game.last_order_note
	if not bool(note.joined) or int(note.deals) != 3 or int(note.after_sympathy) != 30 or int(note.gain) != 0:
		print("Join: FAIL note ", note)
		return false
	if str(st.owner) != game.player or int(st.sympathy) != 0:
		print("Join: FAIL capture ", st.owner, " ", st.sympathy)
		return false
	if not bool(st.get("join_pulse", false)):
		print("Join: FAIL pulse flag")
		return false
	if int(game.hope) != before_hope + int(game.bal.join_hope):
		print("Join: FAIL hope ", game.hope)
		return false
	var lines := "\n".join(game.order_report_lines(note))
	if not lines.contains("They ask to join."):
		print("Join: FAIL line ", lines)
		return false
	print("Join: ok")
	return true


func _check_queue(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var sid := _neighbor(game)
	var st: Dictionary = game.stations[sid]
	st.sympathy = 20
	var preview := game.sympathy_preview(sid)
	var envoy := game.envoy_preview(sid)
	var nxt := game.deal_preview(sid)
	if int(envoy.gain) != maxi(2, int(round(float(preview) * 0.35))):
		print("Queue: FAIL envoy preview")
		return false
	if nxt != 1:
		print("Queue: FAIL deal preview ", nxt)
		return false
	if not game.queue_order({"kind": "order", "order": "propaganda", "station": sid}):
		print("Queue: FAIL queue ", game.order_block("propaganda", sid))
		return false
	game._resolve_queued()
	if game.order_reports.is_empty():
		print("Queue: FAIL empty report")
		return false
	var row: Dictionary = game.order_reports[0]
	for key in ["before_sympathy", "after_sympathy", "gain", "need_id", "need_before", "need_after", "deals", "joined"]:
		if not row.has(key):
			print("Queue: FAIL missing ", key)
			return false
	if str(row.kind) != "propaganda" or int(row.gain) != preview or int(row.before_sympathy) != 20:
		print("Queue: FAIL payload ", row)
		return false
	if int(row.after_sympathy) != int(row.before_sympathy) + int(row.gain):
		print("Queue: FAIL delta")
		return false
	var title := game.order_report_title(row)
	if not title.begins_with("Leaflets at "):
		print("Queue: FAIL title ", title)
		return false
	if not str(row.text).contains("Sympathy %d → %d (+%d)." % [int(row.before_sympathy), int(row.after_sympathy), int(row.gain)]):
		print("Queue: FAIL text ", row.text)
		return false
	print("Queue: ok")
	return true


func _boot(catalog: Catalog) -> Game:
	Copy.set_lang("en")
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game
