@tool
extends EditorPlugin

var stamp: EditorExportPlugin


func _enter_tree() -> void:
	stamp = preload("res://addons/build_stamp/export_plugin.gd").new()
	add_export_plugin(stamp)


func _exit_tree() -> void:
	if stamp != null:
		remove_export_plugin(stamp)
		stamp = null
