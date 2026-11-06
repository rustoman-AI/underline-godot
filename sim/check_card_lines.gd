extends SceneTree

## Headless layout: craft/order chrome and the Listening Post card stay horizontal (EN and RU).
##   godot --headless --path . -s res://sim/check_card_lines.gd

const SCRATCH := "user://check_card_lines"

var bad: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 4:
		await process_frame
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	var cell := _open_cell(st.game)
	if cell.x < 0:
		_bad("no open cell")
		_finish(st)
		return
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		st.game.stock.materials = 80
		await _build_plate(st, cell, lang)
		await _order_plate(st, lang)
	await _listening_room(st, cell)
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	_finish(st)


func _finish(st) -> void:
	if is_instance_valid(st):
		st.free()
	if bad.is_empty():
		print("CARD LINES OK")
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("CARD LINES FAILED")
	quit(1)


func _bad(msg: String) -> void:
	bad.append(msg)


func _build_plate(st, cell: Vector2i, lang: String) -> void:
	st._show_build(cell.x, cell.y)
	for _i in 4:
		await process_frame
	var phrase := Copy.t("why.blocked")
	var found := false
	for lab in _labels(st.card_body):
		if str(lab.text) != phrase:
			continue
		found = true
		_horizontal(lab, "%s build '%s'" % [lang, phrase])
		var plate := _plate(lab)
		if plate == null:
			_bad("%s blocked line has no plate" % lang)
		else:
			var box := _box(plate)
			if box.x <= box.y:
				_bad("%s build plate %s is not wider than tall" % [lang, box])
	if not found:
		_bad("%s build card never showed '%s'" % [lang, phrase])
	_no_columns(st.card_body, lang + " build")
	st._close_card()


func _order_plate(st, lang: String) -> void:
	if not st.showing_network:
		st._toggle_network()
	var net = st.network_view
	net.size = Vector2(1280, 720)
	net._place_panels()
	var sid := _foreign(st.game)
	if sid == "":
		_bad("%s no foreign station" % lang)
		return
	net.open_sheet(sid)
	for _i in 4:
		await process_frame
	var captions := 0
	for button in net.sheet.find_children("*", "Button", true, false):
		if button.is_queued_for_deletion() or not button.has_meta("order_caption"):
			continue
		var caption: Label = button.get_meta("order_caption")
		captions += 1
		_horizontal(caption, "%s order '%s'" % [lang, caption.text.replace("\n", " / ")])
		if str(caption.text) == Copy.t("why.blocked"):
			_bad("%s order button is labeled with the reason" % lang)
	if captions == 0:
		_bad("%s order sheet has no captions" % lang)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 0)
	column.size = Vector2(360, 240)
	root.add_child(column)
	var words := [Copy.t("why.blocked"), Copy.t("why.materials"), Copy.t("why.orders"), Copy.res("materials")]
	for word in words:
		var lab: Label = net._lab(word, 14, false)
		column.add_child(lab)
	for _i in 3:
		await process_frame
	for lab in _labels(column):
		_one_line(lab, "%s order chrome '%s'" % [lang, lab.text])
	_no_columns(net.sheet, lang + " orders")
	column.free()
	net.close_sheet()
	if st.showing_network:
		st._toggle_network()


func _listening_room(st, cell: Vector2i) -> void:
	var game = st.game
	var second := _another_cell(game, cell)
	if second.x < 0:
		_bad("no second cell")
		return
	game.stock.materials = 80
	game._place_room("radio", cell.x, cell.y)
	var radio_uid := str(game.cells["%d:%d" % [cell.x, cell.y]].get("room", ""))
	var radio = game._room(radio_uid)
	if radio == null:
		_bad("radio was not placed")
		return
	_staff(game, radio)
	game._place_room("listening_post", second.x, second.y)
	var post_uid := str(game.cells["%d:%d" % [second.x, second.y]].get("room", ""))
	if game._room(post_uid) == null:
		_bad("listening post was not placed")
		return
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		st._show_room(post_uid)
		for _i in 4:
			await process_frame
		var phrase := Copy.t("why.blocked")
		var verbs := 0
		for button in st.card_body.find_children("*", "Button", true, false):
			if button.is_queued_for_deletion():
				continue
			if str(button.text) == phrase:
				_bad("%s listening button is labeled '%s'" % [lang, phrase])
			if button.has_meta("listening_verb"):
				verbs += 1
				var verb := "listening." + str(button.get_meta("listening_verb"))
				if not str(button.text).begins_with(Copy.t(verb)):
					_bad("%s listening verb '%s'" % [lang, button.text])
				_horizontal(button, "%s listening %s" % [lang, button.text])
		for lab in _labels(st.card_body):
			if not lab.has_meta("listening_why") and str(lab.text) != Copy.t("push.disabled_room"):
				continue
			_one_line(lab, "%s listening line '%s'" % [lang, lab.text])
		var push := _push_row(st.card_body)
		if push == null:
			_bad("%s listening card has no push row" % lang)
		else:
			var state: Label = push.get_child(0)
			var button: Button = push.get_child(1)
			_one_line(state, "%s push status" % lang)
			if button.position.x < state.position.x + 24.0:
				_bad("%s push button is not beside the status (%s vs %s)" % [lang, button.position, state.position])
		_no_columns(st.card_body, lang + " listening")
		if verbs == 0:
			_bad("%s listening card has no probe or tap" % lang)
		st._close_card()
	Copy.set_lang("en")


func _horizontal(node: Control, where: String) -> void:
	var box := _box(node)
	if box.x <= box.y:
		_bad("%s is %s, not wider than tall" % [where, box])
	if node is Label:
		var lab := node as Label
		var text := lab.text.strip_edges()
		if text == Copy.t("why.blocked") and (lab.get_line_count() != 1 or lab.autowrap_mode != TextServer.AUTOWRAP_OFF):
			_bad("%s wraps (%d lines)" % [where, lab.get_line_count()])


func _one_line(lab: Label, where: String) -> void:
	_horizontal(lab, where)
	if lab.get_line_count() != 1:
		_bad("%s is %d lines" % [where, lab.get_line_count()])


func _no_columns(root: Node, where: String) -> void:
	for lab in _labels(root):
		var text := str(lab.text).strip_edges()
		if text.length() < 8 or not lab.visible:
			continue
		var box := _box(lab)
		if lab.get_line_count() >= mini(text.length(), 8) and box.y > box.x:
			_bad("%s letter-stack '%s' %s lines %d" % [where, text.left(40), box, lab.get_line_count()])


func _box(node: Control) -> Vector2:
	var box := node.size
	if box.x < 8.0 or box.y < 8.0:
		box = node.get_combined_minimum_size()
	return box


func _plate(node: Node) -> Control:
	var here := node.get_parent()
	while here != null:
		if here is PanelContainer:
			return here
		here = here.get_parent()
	return null


func _push_row(root: Node) -> HBoxContainer:
	for row in root.find_children("*", "HBoxContainer", true, false):
		if row.is_queued_for_deletion() or row.get_child_count() < 2:
			continue
		if row.get_child(0) is Label and row.get_child(1) is Button:
			if str((row.get_child(0) as Label).text) == Copy.t("push.disabled_room"):
				return row
	return null


func _labels(root: Node) -> Array:
	if root == null:
		return []
	return root.find_children("*", "Label", true, false)


func _open_cell(game) -> Vector2i:
	for key in game.cells:
		var spot: Dictionary = game.cells[key]
		if game._cell_buildable(spot):
			return Vector2i(int(spot.level), int(spot.cell))
	return Vector2i(-1, -1)


func _another_cell(game, skip: Vector2i) -> Vector2i:
	for key in game.cells:
		var spot: Dictionary = game.cells[key]
		if int(spot.level) == skip.x and int(spot.cell) == skip.y:
			continue
		if game._cell_buildable(spot):
			return Vector2i(int(spot.level), int(spot.cell))
	return Vector2i(-1, -1)


func _foreign(game) -> String:
	var any := ""
	for sid in game.stations:
		if str(game.stations[sid].get("owner", "")) == str(game.player):
			continue
		any = str(sid)
		if not game.borders_player(str(sid)):
			return str(sid)
	return any


func _staff(game, room) -> void:
	for person in game.residents:
		if int(person.get("sick", 0)) > 0 or str(person.get("post", "")) != "":
			continue
		room.staff.append(str(person.id))
		person["post"] = str(room.uid)
		return


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var sub := path.path_join(name)
		if dir.current_is_dir():
			_wipe(sub)
			dir.remove(name)
		else:
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
