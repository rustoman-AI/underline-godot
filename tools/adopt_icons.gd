extends SceneTree

## Copies incoming-art/icons into assets/icons. Run by hand after new icons land:
## godot --headless --path . -s res://tools/adopt_icons.gd
## then godot --headless --path . --import


func _init() -> void:
	if DirAccess.open("res://incoming-art/icons") == null:
		print("ADOPT ICONS: no incoming-art/icons")
	else:
		ArtPack.adopt_icons()
		print("ADOPT ICONS: copied incoming-art/icons into assets/icons")
	quit()
