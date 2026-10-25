extends SceneTree

## Record precisely 300 map frames after preparation: --write-movie build/clips/map_units.avi --fixed-fps 30 -s res://.tools/map_units_clip.gd.
var station

## Prepare a reproducible week twenty view without writing player saves or changing simulation code.
func _initialize() -> void:
	_run.call_deferred()

## Keep motion enabled for the movie while ordinary screenshot passes remain frozen.
func _run() -> void:
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = false
	Settings.intro_seen = true
	Settings.reduce_motion = false
	station = load("res://ui/station.tscn").instantiate()
	station.shot_mode = true
	station.motion_in_shots = true
	root.add_child(station)
	await process_frame
	station._begin_new_game(false)
	var bot := Bot.new()
	bot.profile = "careful"
	while station.game.week < 20 and station.game.over == "":
		bot._act(station.game)
		station.game.end_week()
	station.game.pending.clear()
	station.game.order_reports.clear()
	station.hold_dawn = true
	station._close_card()
	station.guide_step = -1
	if station.guide_layer != null:
		station.guide_layer.visible = false
	station._refresh()
	station._toggle_network()
	station.network_view._fit()
	station.network_view.refresh()
	for i in 299:
		await process_frame
	quit(0)
