extends SceneTree

## Listening Post gate.
##   godot --headless --path . -s res://sim/check_listening.gd


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("LISTENING CHECK FAILED: " + catalog.error)
		quit(1)
		return
	var bad: PackedStringArray = []
	_mechanics(catalog, bad)
	_art(bad)
	_no_event_intel(catalog, bad)
	if not bad.is_empty():
		for line in bad:
			print("FAIL " + line)
		print("LISTENING CHECK FAILED")
		quit(1)
		return
	var lost := _careful_band(catalog)
	var pct := 100.0 * float(lost) / 60.0
	print("Careful loss: %d/60 (%.1f%%)" % [lost, pct])
	# Careful does not build the post. Seeds 1-60 lost 12 (20%). Gate is the spec band, 15-35%.
	var band_ok := lost >= 9 and lost <= 21
	if not band_ok:
		print("FAIL careful loss %d/60 outside 15-35%%" % lost)
	print("LISTENING CHECK OK" if band_ok else "LISTENING CHECK FAILED")
	quit(0 if band_ok else 1)


func _mechanics(catalog: Catalog, bad: PackedStringArray) -> void:
	var game := Game.new()
	game.setup(catalog, 3, 40)
	if game.listening_build_block() == "":
		bad.append("build gate open with no radio")
	if game.build_possible("listening_post"):
		bad.append("build_possible without a staffed radio")
	var cell := _open_cell(game)
	if cell.x < 0:
		bad.append("no open cell")
		return
	game._place_room("radio", cell.x, cell.y)
	var radio = game._listening_room()
	# radio was placed, not the post
	radio = null
	for room in game.rooms:
		if str(room.type) == "radio":
			radio = room
	if radio == null:
		bad.append("radio was not placed")
		return
	_staff(game, radio)
	if game.listening_build_block() != "":
		bad.append("staffed radio still blocks the post: " + game.listening_build_block())
	game.stock.materials = 40
	if not game.build_possible("listening_post"):
		bad.append("staffed online radio should allow the post")
	var second := _open_cell(game)
	game._place_room("listening_post", second.x, second.y)
	if game.build_possible("listening_post"):
		bad.append("a second post is buildable")
	var preview := game.build_preview("listening_post", second.x, second.y)
	if bool(preview.ok):
		bad.append("preview allows a second post")
	if game.room_can_push("listening_post"):
		bad.append("listening post can push")
	if not game.room_can_push("workshop"):
		bad.append("workshop push default flipped")
	var post = game._listening_room()
	_staff(game, post)
	if not game.listening_active():
		bad.append("staffed post is not active")
	var hidden := 0
	for i in 40:
		if game._intent_hidden("squad"):
			hidden += 1
	if hidden != 0:
		bad.append("intents hid %d times while the post was staffed" % hidden)
	if not is_equal_approx(game.rumor_truth(), 0.95):
		bad.append("rumor truth %.2f with post" % game.rumor_truth())
	post.staff = []
	if not is_equal_approx(game.rumor_truth(), 0.90):
		bad.append("radio-only rumor %.2f" % game.rumor_truth())
	var radio_hides := 0
	for i in 40:
		if game._intent_hidden("squad"):
			radio_hides += 1
	if radio_hides != 0:
		bad.append("radio alone hid %d intents" % radio_hides)
	radio.offline = true
	var bare := 0
	for i in 80:
		if game._intent_hidden("squad"):
			bare += 1
	if bare < 4 or bare > 40:
		bad.append("hide roll without radio or post was %d/80" % bare)
	radio.offline = false
	_staff(game, post)
	var target := _faction_station(game, "exchange")
	if target == "":
		bad.append("no known exchange station")
		return
	game.bal.probe_blown = 0.0
	game.orders_left = 2
	game.stock.tokens = 12
	var before_people := game.residents.size()
	if not game.apply({"kind": "order", "order": "probe", "station": target}):
		bad.append("probe did not apply")
		return
	var st: Dictionary = game.stations[target]
	if int(st.get("intel", 0)) < 2:
		bad.append("probe left intel %s" % str(st.get("intel", 0)))
	if int(st.get("wired_until", 0)) != game.week + 2:
		bad.append("wired_until %s" % str(st.get("wired_until", 0)))
	var reveal := _notice_with(game, "opinion ")
	if reveal == "" or (not reveal.contains("opinion +") and not reveal.contains("opinion -") and not reveal.ends_with("opinion 0.")):
		bad.append("reveal line '%s'" % reveal)
	if game.residents.size() != before_people:
		bad.append("probe changed the headcount")
	game.orders_left = 2
	game.seat_used = {}
	if game.order_block("probe", target) != "One order a week.":
		bad.append("second probe block '%s'" % game.order_block("probe", target))
	game.bal.probe_blown = 0.15
	game.bal.tap_blown = 0.25
	post.upgrade = 1
	if not is_equal_approx(game.listening_blown_chance("probe"), 0.10):
		bad.append("pipe taps cut %.2f" % game.listening_blown_chance("probe"))
	if not is_equal_approx(game.listening_blown_chance("tap"), 0.20):
		bad.append("pipe taps tap cut %.2f" % game.listening_blown_chance("tap"))
	post.upgrade = 2
	if not is_equal_approx(game.listening_blown_chance("probe"), 0.05):
		bad.append("dead drop probe cut %.2f" % game.listening_blown_chance("probe"))
	if not is_equal_approx(game.listening_blown_chance("tap"), 0.15):
		bad.append("dead drop tap cut %.2f" % game.listening_blown_chance("tap"))
	post.upgrade = 0
	game.flags.erase("listening_order_week")
	game.bal.probe_blown = 1.0
	game.orders_left = 2
	game.seat_used = {}
	game.stock.tokens = 12
	game.hope = 40
	var hope_before := game.hope
	var dis_before := game.discontent
	var op_before := int(game.opinions.get("exchange", 0))
	game.notices.clear()
	game.chronicle.clear()
	if not game.apply({"kind": "order", "order": "probe", "station": target}):
		bad.append("blown probe did not apply")
		return
	if int(post.get("disabled", 0)) < 1:
		bad.append("blown left the post up")
	if game.hope != hope_before - 1:
		bad.append("hope %d -> %d" % [hope_before, game.hope])
	if int(game.opinions.get("exchange", 0)) != op_before + int(game.bal.blown_opinion):
		bad.append("opinion %d -> %d" % [op_before, int(game.opinions.exchange)])
	if game.discontent != dis_before + 2:
		bad.append("discontent %d -> %d" % [dis_before, game.discontent])
	if game.residents.size() != before_people:
		bad.append("blown killed someone")
	var weight := 0
	var line := ""
	for moment in game.chronicle:
		if str(moment.get("kind", "")) == "listening_blown":
			weight = int(moment.get("weight", 0))
			line = game.chronicle_line(moment)
	if weight != 2 or not line.contains("They heard the tap"):
		bad.append("chronicle %d '%s'" % [weight, line])
	if _notice_with(game, "They heard the tap") == "":
		bad.append("blown toast missing")
	if int(st.get("intel", 0)) > 2:
		bad.append("blown raised intel")
	game.bal.tap_blown = 0.0
	post.disabled = 0
	game.flags.erase("listening_order_week")
	game.orders_left = 2
	game.seat_used = {}
	game.stock.food = 20
	var op_tap := int(game.opinions.get("exchange", 0))
	if not game.apply({"kind": "order", "order": "tap", "faction": "exchange"}):
		bad.append("tap did not apply")
	elif int(game.opinions.get("exchange", 0)) != op_tap - 4:
		bad.append("tap opinion %d -> %d" % [op_tap, int(game.opinions.exchange)])
	elif _notice_with(game, "Tap ") == "":
		bad.append("tap toast missing")


func _art(bad: PackedStringArray) -> void:
	var tex: Dictionary = ArtPack.textures()
	print("ArtPack textures %d" % tex.size())
	var paths := [
		"res://assets/rooms/room_listening_post.webp",
		"res://assets/rooms/room_listening_post_alt.webp",
		"res://assets/overlays/room_probe.webp",
		"res://assets/map/chips/wired.webp",
		"res://assets/map/chips/probing.webp",
		"res://assets/map/chips/probing_tint.webp",
		"res://assets/icons/rooms/listening_post.png",
		"res://assets/icons/status/probing.png",
		"res://assets/icons/status/probing_24.png",
		"res://assets/icons/ui/probing.png",
		"res://assets/icons/ui/probing_24.png",
		"res://assets/events/knock_last.webp",
		"res://assets/events/stores_turn.webp",
		"res://assets/events/ration_coat.webp",
		"res://assets/icons/status/blown.png",
		"res://assets/icons/status/blown_24.png",
		"res://assets/icons/map/blown.png",
		"res://assets/icons/map/blown_24.png",
		"res://assets/overlays/blown_flash.webp",
	]
	for path in paths:
		if not tex.has(path):
			bad.append("ArtPack missing " + path)
	if ArtPack.icon_texture("listening_post", 48.0) == null:
		bad.append("build icon listening_post did not load")
	if ArtPack.icon_texture("probing", 24.0) == null:
		bad.append("probing_24 did not load")
	if ArtPack.icon_texture("blown", 48.0) == null or ArtPack.icon_texture("blown", 24.0) == null:
		bad.append("blown icon did not load")


func _no_event_intel(catalog: Catalog, bad: PackedStringArray) -> void:
	for ev in catalog.events:
		for choice in ev.get("choices", []):
			if choice is Dictionary and (choice as Dictionary).has("intel"):
				bad.append("event %s sets intel" % str(ev.get("id", "")))


func _careful_band(catalog: Catalog) -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var report: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(report.get("over", "")) != "time":
			lost += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return lost


func _open_cell(game: Game) -> Vector2i:
	for key in game.cells:
		var cell: Dictionary = game.cells[key]
		if game._cell_buildable(cell):
			return Vector2i(int(cell.level), int(cell.cell))
	return Vector2i(-1, -1)


func _staff(game: Game, room) -> void:
	for person in game.residents:
		if int(person.get("sick", 0)) > 0 or str(person.get("post", "")) != "":
			continue
		room.staff.append(str(person.id))
		person["post"] = str(room.uid)
		return


func _faction_station(game: Game, fid: String) -> String:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) == fid and bool(st.get("known", false)):
			return str(sid)
	return ""


func _notice_with(game: Game, needle: String) -> String:
	for line in game.notices:
		if str(line).contains(needle):
			return str(line)
	return ""
