extends SceneTree

## P81 Passage Duty. Seat, assign, chip, first float, lost toast. No dawn chip.
## Careful loss is reported against the master baseline of 2/60.
##   godot --path . -s res://sim/check_passage_duty.gd
##   godot --path . -s res://sim/check_passage_duty.gd -- --skip-careful

const BASELINE := 2
const SHOTS := "/opt/cursor/artifacts"


class Host extends Node:
	var game
	var shot_mode := true
	var toasts := PackedStringArray()

	func _toast(line: String) -> void:
		toasts.append(line)

	func _ui_click() -> void:
		pass


var _failed := false
var catalog: Catalog


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("DUTY FAIL catalog")
		quit(1)
		return
	if _strings():
		print("Strings: ok")
	if _duty():
		print("Duty: ok")
	if _chip():
		print("Chip: ok")
	if _dawn():
		print("Dawn: ok")
	if not await _ui():
		_failed = true
	var skip := false
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--skip-careful":
			skip = true
	if skip:
		print("careful loss skipped (master baseline %d/60)" % BASELINE)
	else:
		var lost := _careful()
		print("careful loss %d/60 (master baseline %d/60)" % [lost, BASELINE])
		if lost != BASELINE:
			_bad("careful loss moved off %d/60" % BASELINE)
	if _failed:
		print("DUTY FAIL")
		quit(1)
		return
	print("DUTY OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("Duty: FAIL ", msg)


func _strings() -> bool:
	var rows := {
		"duty.name": ["Passage Duty", "Дозор на проходе"],
		"duty.assign": ["Post Duty", "Поставить дозор"],
		"duty.unassign": ["Clear Duty", "Снять дозор"],
		"duty.tip": ["Duty. Someone watches this passage.", "Дозор. Кто-то стережёт этот проход."],
		"duty.first": ["Someone watches the passage.", "Кто-то стережёт проход."],
		"duty.lost": ["Duty cleared. Passage unwatched.", "Дозор снят. Проход без глаз."],
		"duty.empty": ["No one on Duty.", "На дозоре никого."],
		"duty.need_free": ["No Free hands.", "Нет свободных рук."],
	}
	for key in rows:
		Copy.set_lang("en")
		if Copy.t(str(key)) != str(rows[key][0]):
			_bad("en " + str(key) + " " + Copy.t(str(key)))
			return false
		Copy.set_lang("ru")
		if Copy.t(str(key)) != str(rows[key][1]):
			_bad("ru " + str(key) + " " + Copy.t(str(key)))
			Copy.set_lang("en")
			return false
	Copy.set_lang("en")
	if Copy.t("people.chip_duty") != "Duty":
		_bad("chip en")
		return false
	Copy.set_lang("ru")
	if Copy.t("people.chip_duty") != "Дозор":
		_bad("chip ru " + Copy.t("people.chip_duty"))
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	var pack := FileAccess.get_file_as_string("res://data/passage_duty.json")
	if pack.find("people.chip_duty") >= 0 or pack.find("\"shift.") >= 0 or pack.find("\"salvage.") >= 0 or pack.find("\"flow.") >= 0 or pack.find("\"relay.") >= 0:
		_bad("pack namespace")
		return false
	if pack.find("\"_roadmap\": \"P81\"") < 0:
		_bad("roadmap")
		return false
	return true


func _duty() -> bool:
	if Game.SAVE_SCHEMA != 14:
		_bad("schema " + str(Game.SAVE_SCHEMA))
		return false
	var game := _fresh()
	var sid := _linked(game)
	var other := _linked(game, sid)
	if sid == "" or other == "":
		_bad("no linked outpost")
		return false
	for person in game.residents:
		if str(person.get("duty_edge_id", "")) != "":
			_bad("auto duty at setup")
			return false
	if not PassageDuty.seats(game, sid).is_empty() or not PassageDuty.seats(game, game.capital_id).is_empty():
		_bad("seat before the station is owned")
		return false
	_own(game, sid, false)
	if not PassageDuty.seats(game, sid).is_empty():
		_bad("seat without passage")
		return false
	_own(game, sid, true)
	var edge := PassageDuty.edge_for(game, sid)
	if edge == "" or PassageDuty.seats(game, sid).size() != 1:
		_bad("owned passage seat")
		return false
	var foreign := _linked(game, sid)
	if foreign == "":
		foreign = other
	game.stations[foreign].passage = true
	game.stations[foreign].known = true
	if str(game.stations[foreign].owner) == str(game.player):
		_bad("foreign is owned")
		return false
	if not PassageDuty.seats(game, foreign).is_empty():
		_bad("foreign seat")
		return false
	if PassageDuty.tip_line(game, foreign) != "" or PassageDuty.tip_line(game, sid) != Copy.t("duty.tip"):
		_bad("tip")
		return false
	var free_id := _liberate(game)
	var second := _liberate(game, free_id)
	if free_id == "" or second == "":
		_bad("no free hands")
		return false
	var sick: Dictionary = game.people[second]
	sick.sick = 2
	if bool(PassageDuty.preview(game, second, edge).ok):
		_bad("sick was posted")
		sick.sick = 0
		return false
	sick.sick = 0
	sick.absent = 2
	if bool(PassageDuty.preview(game, second, edge).ok):
		_bad("away was posted")
		sick.absent = 0
		return false
	sick.absent = 0
	sick.soldier = true
	if bool(PassageDuty.preview(game, second, edge).ok):
		_bad("crew was posted")
		sick.soldier = false
		return false
	sick.soldier = false
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var orders0 := int(game.orders_left)
	var stock0 := _stock(game)
	var free0 := game._free_count()
	var info: Dictionary = game.duty_post(free_id, edge)
	if not bool(info.ok) or not bool(info.first) or not bool(game.flags.get("seen_passage_duty", false)):
		_bad("first post")
		return false
	if not PassageDuty.holds(game.people[free_id]) or str(game.people[free_id].get("duty_edge_id", "")) != edge:
		_bad("duty not set")
		return false
	if game._free_count() != free0 - 1:
		_bad("still free")
		return false
	var room := ""
	for candidate in game.rooms:
		if int(candidate.staff.size()) < int(game.catalog.rooms[candidate.type].staff_max):
			room = str(candidate.uid)
			break
	if room == "" or bool(game.assign_preview(free_id, room).ok):
		_bad("duty hand assigned to a room")
		return false
	var listed := false
	for row in game.candidates_for(room):
		if str(row.id) == free_id:
			listed = true
	if listed:
		_bad("duty hand listed as free")
		return false
	if bool(PassageDuty.preview(game, second, edge).ok):
		_bad("second person took the seat")
		return false
	if int(game.hope) != hope0 or int(game.discontent) != dis0 or int(game.orders_left) != orders0 or not _same_stock(game, stock0):
		_bad("post moved a meter")
		return false
	if game.passage_duty_dawn_chip() or str(game.dawn_soft_chip().get("kind", "")) == "duty":
		_bad("post joined the dawn chip")
		return false
	_own(game, other, true)
	var edge2 := PassageDuty.edge_for(game, other)
	var again: Dictionary = game.duty_post(second, edge2)
	if not bool(again.ok) or bool(again.first):
		_bad("second passage %s edge %s reason %s first %s" % [other, edge2, str(again.get("reason", "")), str(again.get("first", false))])
		return false
	if not game.duty_clear(second):
		_bad("clear")
		return false
	if PassageDuty.holds(game.people[second]):
		_bad("clear left the watch")
		return false
	game.people[free_id].sick = 3
	var lost := game.duty_sweep()
	if lost.size() != 1 or str(lost[0]) != Copy.t("duty.lost") or PassageDuty.holds(game.people[free_id]):
		_bad("sick clear")
		return false
	game.people[free_id].sick = 0
	if not bool(game.duty_post(free_id, edge).ok):
		_bad("repost")
		return false
	game.stations[sid].owner = "neutral"
	lost = game.duty_sweep()
	if lost.size() != 1 or PassageDuty.holds(game.people[free_id]) or not PassageDuty.seats(game, sid).is_empty():
		_bad("lost station")
		return false
	_own(game, sid, true)
	if not bool(game.duty_post(free_id, edge).ok):
		_bad("repost after loss")
		return false
	game.stations[sid].passage = false
	lost = game.duty_sweep()
	if lost.is_empty() or PassageDuty.holds(game.people[free_id]):
		_bad("lost passage")
		return false
	game.stations[sid].passage = true
	if not bool(game.duty_post(free_id, PassageDuty.edge_for(game, sid)).ok):
		_bad("repost passage")
		return false
	var tunnel := game._edge(game.capital_id, sid)
	var prev_state := str(tunnel.get("state", ""))
	var prev_dug := bool(tunnel.get("dug", false))
	if tunnel.is_empty():
		_bad("no tunnel to cut")
		return false
	tunnel.state = "collapsed"
	tunnel.dug = false
	tunnel.sealed = false
	if game._supply_hops(sid) < 900:
		tunnel.state = prev_state
		tunnel.dug = prev_dug
		_bad("cut did not offline")
		return false
	lost = game.duty_sweep()
	tunnel.state = prev_state
	tunnel.dug = prev_dug
	if lost.is_empty() or PassageDuty.holds(game.people[free_id]):
		_bad("offline clear")
		return false
	if not bool(game.duty_post(free_id, PassageDuty.edge_for(game, sid)).ok):
		_bad("repost after cut")
		return false
	var snap := game.export_state()
	snap["schema"] = Game.SAVE_SCHEMA
	var loaded := _fresh()
	if not loaded.import_state(snap):
		_bad("save " + loaded.load_error)
		return false
	if not PassageDuty.holds(loaded.people[free_id]) or not bool(loaded.flags.get("seen_passage_duty", false)):
		_bad("load lost duty")
		return false
	if loaded.passage_duty_dawn_chip():
		_bad("load joined dawn")
		return false
	return true


func _chip() -> bool:
	var person := {"id": "p", "name": "Ada Moss", "sick": 0, "absent": 0}
	if PassageDuty.chip_key(person) != "":
		_bad("chip on a free hand")
		return false
	person["duty_edge_id"] = "a|b"
	if PassageDuty.chip_key(person) != "people.chip_duty":
		_bad("chip missing")
		return false
	person.sick = 1
	if PassageDuty.chip_key(person) != "":
		_bad("sick lost priority")
		return false
	person.sick = 0
	person.absent = 1
	if PassageDuty.chip_key(person) != "":
		_bad("away lost priority")
		return false
	person.absent = 0
	if PassageDuty.clip_name("Ada Moss Longer") != "Ada Moss Lon…":
		_bad("clip " + PassageDuty.clip_name("Ada Moss Longer"))
		return false
	var game := _fresh()
	var sid := _linked(game)
	_own(game, sid, true)
	var free_id := _liberate(game)
	if free_id == "" or not bool(game.duty_post(free_id, PassageDuty.edge_for(game, sid)).ok):
		_bad("chip post")
		return false
	var desk = load("res://ui/station.gd").new()
	desk.game = game
	if desk._person_post(free_id) != "duty":
		_bad("post " + desk._person_post(free_id))
		return false
	var row: Control = desk._people_row(game.people[free_id], "")
	var chips := _meta(row, "people_chip")
	if chips.size() != 1 or str(chips[0].text) != "Duty":
		_bad("row chip")
		return false
	game.people[free_id].sick = 2
	if desk._person_post(free_id) != "sick":
		_bad("sick post")
		return false
	row = desk._people_row(game.people[free_id], "")
	if not _meta(row, "people_chip").is_empty():
		_bad("sick row kept Duty")
		return false
	game.people[free_id].sick = 0
	Copy.set_lang("ru")
	row = desk._people_row(game.people[free_id], "")
	chips = _meta(row, "people_chip")
	Copy.set_lang("en")
	if chips.size() != 1 or str(chips[0].text) != "Дозор":
		_bad("row chip ru")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if view.find("duty_mark") >= 0 or view.find("_draw_duty") >= 0:
		_bad("map tick")
		return false
	return true


func _dawn() -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("stack " + str(Game.DAWN_SOFT_STACK))
		return false
	var game := _fresh()
	if game.passage_duty_dawn_chip() or game.dawn_soft_stack().has("duty"):
		_bad("dawn joined")
		return false
	return true


func _ui() -> bool:
	var game := _fresh()
	var sid := _linked(game)
	var foreign := _linked(game, sid)
	if sid == "" or foreign == "":
		_bad("ui stations")
		return false
	_own(game, sid, false)
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var view := NetworkView.new()
	view.host = host
	view.size = Vector2(1280, 720)
	view.custom_minimum_size = Vector2(1280, 720)
	root.add_child(view)
	await process_frame
	view.open_visit(sid)
	await process_frame
	if not _meta(view.visit, "duty_seat").is_empty():
		_bad("before seat")
		return false
	await _save_view(view, "duty_visit_before.png")
	_own(game, sid, true)
	_park_free(game)
	view._fill_visit(sid)
	await process_frame
	if _meta(view.visit, "duty_need_free").is_empty() or not _meta(view.visit, "duty_empty").is_empty():
		_bad("need free")
		return false
	await _reveal(view)
	await _save_view(view, "duty_visit_need_free.png")
	_unpark(game)
	var free_id := _liberate(game)
	if free_id == "":
		_bad("ui free")
		return false
	view._sync_duty(game, sid)
	await process_frame
	var empty := _meta(view.visit, "duty_empty")
	if empty.size() != 1:
		_bad("empty seat " + str(empty.size()))
		return false
	await _reveal(view)
	await _save_view(view, "duty_visit_empty.png")
	empty[0].pressed.emit()
	await process_frame
	var picks := _meta(view.visit, "duty_pick")
	if picks.is_empty() or _meta(view.visit, "duty_assign").is_empty():
		_bad("picker")
		return false
	await _reveal(view)
	await _save_view(view, "duty_visit_picker.png")
	picks[0].pressed.emit()
	await process_frame
	if _meta(view.visit, "duty_named").is_empty():
		_bad("named seat")
		return false
	if view._duty_float == null or not view._duty_float.visible or view._duty_float.text != Copy.t("duty.first"):
		_bad("float")
		return false
	if not _meta(view, "duty_toast").is_empty():
		_bad("second plate")
		return false
	if host.toasts.is_empty() or host.toasts[host.toasts.size() - 1] != Copy.clip(Copy.t("duty.assign"), 72):
		_bad("assign host toast")
		return false
	var y := view._duty_float.position.y
	await process_frame
	await process_frame
	if not is_equal_approx(view._duty_float.position.y, y):
		_bad("float moved")
		return false
	await _reveal(view)
	await _save_view(view, "duty_visit_named.png")
	var posted := ""
	var named_now := _meta(view.visit, "duty_named")
	if not named_now.is_empty():
		posted = str(named_now[0].get_meta("duty_named"))
	if posted == "" or not PassageDuty.holds(game.people[posted]):
		_bad("posted id")
		return false
	var desk = load("res://ui/station.gd").new()
	desk.game = game
	desk.people_box = VBoxContainer.new()
	desk.people_filter = "duty"
	desk._fill_people()
	if _meta(desk.people_box, "people_chip").is_empty():
		_bad("drawer chip")
		return false
	var chip_row: Control = desk._people_row(game.people[posted], "")
	if _meta(chip_row, "people_chip").is_empty() or str(_meta(chip_row, "people_chip")[0].text) != "Duty":
		_bad("chip row text")
		return false
	var quiet: Dictionary = game.people[posted].duplicate()
	quiet.erase("duty_edge_id")
	var bare: Control = desk._people_row(quiet, "")
	if not _meta(bare, "people_chip").is_empty():
		_bad("before chip")
		return false
	await _save_row(bare, "duty_people_before.png")
	await _save_row(chip_row, "duty_people_chip.png")
	view._sync_duty(game, sid)
	var named := _meta(view.visit, "duty_named")
	if named.is_empty():
		_bad("named after chip shot")
		return false
	var n := host.toasts.size()
	named[0].pressed.emit()
	await process_frame
	var cleared: Array = PassageDuty.seats(game, sid)
	if cleared.is_empty() or str(cleared[0].get("person_id", "")) != "":
		_bad("clear seat")
		return false
	if host.toasts.size() != n + 1 or host.toasts[n] != Copy.clip(Copy.t("duty.unassign"), 72):
		_bad("clear toast")
		return false
	if not bool(game.duty_post(free_id, PassageDuty.edge_for(game, sid)).ok):
		_bad("ui repost")
		return false
	game.stations[sid].owner = "neutral"
	view._sync_duty(game, sid)
	await process_frame
	if not _meta(view.visit, "duty_seat").is_empty():
		_bad("lost seat stayed")
		return false
	if host.toasts.is_empty() or host.toasts[host.toasts.size() - 1] != Copy.clip(Copy.t("duty.lost"), 72):
		_bad("lost toast " + str(host.toasts))
		return false
	if not _meta(view, "duty_toast").is_empty():
		_bad("lost second plate")
		return false
	view._hide_duty_float()
	await _save_view(view, "duty_visit_lost.png")
	game.stations[foreign].passage = true
	game.stations[foreign].known = true
	view.open_visit(foreign)
	await process_frame
	if not _meta(view.visit, "duty_seat").is_empty():
		_bad("foreign visit seat")
		return false
	await _save_view(view, "duty_visit_foreign.png")
	if view.find_children("*", "ConfirmationDialog", true, false).size() != 0:
		_bad("confirm")
		return false
	print("Visit: ok")
	return true


func _careful() -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var row: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(row.get("over", "")) != "time":
			lost += 1
			print("  careful seed %d over %s week %s" % [run_seed, row.get("over", ""), row.get("week", "")])
	return lost


func _fresh() -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 4
	return game


func _linked(game: Game, skip: String = "") -> String:
	var queue: Array = [str(game.capital_id)]
	var seen := {str(game.capital_id): true}
	var qi := 0
	while qi < queue.size():
		var cur: String = str(queue[qi])
		qi += 1
		for n in game._neighbors(cur):
			var id := str(n)
			if seen.has(id):
				continue
			seen[id] = true
			queue.append(id)
			if id == skip:
				continue
			var st: Dictionary = game.stations[id]
			if str(st.get("bunker", "")) != "" or str(st.owner) in ["bunker", "ruin"]:
				continue
			return id
	return ""


func _own(game: Game, sid: String, passage: bool) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	st.passage = passage
	if str(st.get("focus", "")) == "":
		st.focus = "food"


func _park_free(game: Game) -> void:
	for person in game.residents:
		var id := str(person.id)
		if game._is_child(person) or int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		if game._locked_ids().has(id) or bool(person.get("soldier", false)) or PassageDuty.holds(person):
			continue
		if game._staff_room_of(id) != "":
			continue
		person["__parked"] = true
		person.sick = 1


func _unpark(game: Game) -> void:
	for person in game.residents:
		if not bool(person.get("__parked", false)):
			continue
		person.sick = 0
		person.erase("__parked")


func _liberate(game: Game, skip: String = "") -> String:
	for person in game.residents:
		var id := str(person.id)
		if id == skip:
			continue
		if game._is_child(person) or int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		if game._locked_ids().has(id) or bool(person.get("soldier", false)) or PassageDuty.holds(person):
			continue
		if game._staff_room_of(id) != "":
			game._unassign(id)
		if person.has("post"):
			person.erase("post")
		if game._staff_room_of(id) != "":
			continue
		return id
	return ""


func _stock(game: Game) -> Dictionary:
	return {
		"food": int(game.stock.food),
		"air": int(game.stock.air),
		"power": int(game.stock.power),
		"materials": int(game.stock.materials),
		"tokens": int(game.stock.tokens),
		"influence": int(game.stock.influence),
	}


func _same_stock(game: Game, stock0: Dictionary) -> bool:
	for key in stock0:
		if int(game.stock[key]) != int(stock0[key]):
			return false
	return true


func _meta(node: Node, key: String) -> Array:
	var found: Array = []
	if node == null:
		return found
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if not is_instance_valid(here) or here.is_queued_for_deletion():
			continue
		if not here.visible:
			continue
		if here.has_meta(key):
			found.append(here)
		for child in here.get_children():
			stack.append(child)
	return found


func _reveal(view: NetworkView) -> void:
	await process_frame
	await process_frame
	var seats := _meta(view.visit, "duty_seat")
	if seats.is_empty():
		return
	var seat: Control = seats[0]
	var here: Node = seat
	var scroll: ScrollContainer = null
	while here != null:
		if here is ScrollContainer:
			scroll = here
			break
		here = here.get_parent()
	if scroll == null:
		return
	var content := scroll.get_child(0)
	var local: Vector2 = content.get_global_transform().affine_inverse() * seat.get_global_position()
	scroll.scroll_vertical = maxi(0, int(local.y) - 24)
	await process_frame


func _save_view(view: NetworkView, name: String) -> void:
	var img := await _grab(view)
	_write(img, name)


func _save_row(row: Control, name: String) -> void:
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(520, 96)
	plate.size = Vector2(520, 96)
	var face := StyleBoxFlat.new()
	face.bg_color = Color("241c14")
	face.set_content_margin_all(12)
	plate.add_theme_stylebox_override("panel", face)
	plate.add_child(row)
	root.add_child(plate)
	var img := await _grab(plate, Vector2i(520, 96))
	_write(img, name)
	plate.queue_free()


func _grab(node: Node, size: Vector2i = Vector2i(1280, 720)) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color("140f0c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if node is Control:
		var ctrl := node as Control
		ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ctrl.position = Vector2.ZERO
		if ctrl.size.x < 100.0 or ctrl.size.y < 40.0:
			ctrl.size = Vector2(1280, 720)
	vp.add_child(node)
	root.add_child(vp)
	for _i in 4:
		await process_frame
	var tex: ViewportTexture = vp.get_texture()
	var img: Image = null
	if tex != null:
		img = tex.get_image()
	vp.remove_child(node)
	if parent != null:
		parent.add_child(node)
	root.remove_child(vp)
	vp.queue_free()
	return img


func _write(img: Image, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var path := SHOTS.path_join(name)
	if img == null:
		_bad("shot " + name)
		return
	img.save_png(path)
	print("shot ", path)
