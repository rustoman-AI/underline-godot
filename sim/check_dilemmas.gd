extends SceneTree

## Headless dilemma checks. Also run from sim/audience_checks.gd and sim/bot_run.gd.
##   godot --headless --path . -s res://sim/check_dilemmas.gd

const DilemmaChecks = preload("res://sim/dilemma_checks.gd")


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	var result: Dictionary = DilemmaChecks.run(catalog)
	for line in result.lines:
		print(line)
	if result.ok:
		print("DILEMMA CHECK OK")
		quit(0)
	else:
		print("DILEMMA CHECK FAILED")
		quit(1)
