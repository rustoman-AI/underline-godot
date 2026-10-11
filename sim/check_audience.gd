extends SceneTree

## Headless leader audience checks (scheduling, refusals, deal previews, save). Also run by bot_run.gd.
##   godot --headless --path . -s res://sim/check_audience.gd

const AudienceChecks = preload("res://sim/audience_checks.gd")


func _init() -> void:
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	var result := AudienceChecks.run(catalog)
	for line in result.lines:
		print(line)
	if result.ok:
		print("AUDIENCE CHECK OK")
		quit(0)
	else:
		print("AUDIENCE CHECK FAILED")
		quit(1)
