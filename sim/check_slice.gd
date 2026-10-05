extends SceneTree

## Headless checks for the slice: dawn queue, then the later gates as they land.
##   godot --headless --path . -s res://sim/check_slice.gd


func _init() -> void:
	var failed := false
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_queue(catalog):
		failed = true
	if failed:
		print("SLICE FAIL")
		quit(1)
		return
	print("SLICE OK")
	quit(0)


func _check_queue(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	if game.over == "error":
		print("Queue: FAIL setup")
		return false
	if not _ids_once(game, "opening report"):
		return false
	var clog: Dictionary = {}
	for ev in catalog.events:
		if str(ev.id) == "clog":
			clog = ev
	if clog.is_empty():
		print("Queue: FAIL no clog")
		return false
	var before := game.pending.size()
	game._present_event(clog)
	game._present_event(clog)
	if game.pending.size() != before and _count_id(game, "clog") > 1:
		print("Queue: FAIL clog queued twice")
		return false
	if _count_id(game, "clog") > 1:
		print("Queue: FAIL duplicate clog")
		return false
	var guard := 0
	while not game.pending.is_empty() and guard < 8:
		guard += 1
		var front: Dictionary = game.front_event()
		var id := str(front.id)
		var choices: Array = []
		for choice in front.choices:
			choices.append(str(choice.id))
		if not game.dismiss_front():
			print("Queue: FAIL dismiss stuck on %s" % id)
			return false
		if not game.pending.is_empty():
			var nxt: Dictionary = game.front_event()
			if str(nxt.id) == id:
				print("Queue: FAIL close showed %s again" % id)
				return false
			var again := true
			if nxt.choices.size() == choices.size():
				for i in choices.size():
					if str(nxt.choices[i].id) != str(choices[i]):
						again = false
			else:
				again = false
			if again:
				print("Queue: FAIL same choices after close")
				return false
	if not game.pending.is_empty():
		print("Queue: FAIL queue did not empty")
		return false
	print("Queue: ok")
	return true


func _ids_once(game: Game, label: String) -> bool:
	var seen := {}
	for ev in game.pending:
		var id := str(ev.id)
		if seen.has(id):
			print("Queue: FAIL %s lists %s twice" % [label, id])
			return false
		seen[id] = true
	if game.modal_ids().size() != game.pending.size():
		print("Queue: FAIL %s modal ids collapsed a duplicate" % label)
		return false
	return true


func _count_id(game: Game, id: String) -> int:
	var n := 0
	for ev in game.pending:
		if str(ev.id) == id:
			n += 1
	return n
