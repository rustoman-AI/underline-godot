extends Control

func _ready() -> void:
	var report: Dictionary = Bot.new().play(40, 1)
	$Label.text = str(report.summary)
	print(report.summary)
