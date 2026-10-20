extends RefCounted

## Cached frames and pooled sprites keep texture loading and material allocation outside drawing.
const TINT := preload("res://ui/shaders/owner_tint.gdshader")
const KINDS := ["handcar_pump"]
var distance_per_frame := 4.25
var frames := {}
var anchors := {}
var materials := {}
var sprites := {}
var used := {}
var shadow: Texture2D
var icons := {}
var paper: Texture2D
var parent: CanvasItem

## Load every frame once when the map opens; incomplete sheets deliberately keep the old drawing available.
func setup(layer: CanvasItem) -> void:
	parent = layer
	for kind in KINDS:
		var path: String = "res://assets/map/units/" + kind
		if not FileAccess.file_exists(path.path_join("frames.json")):
			continue
		var meta = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("frames.json")))
		if not meta is Dictionary or bool(meta.get("placeholder", true)) or not bool(meta.get("accepted", false)):
			continue
		var list: Array[Texture2D] = []
		for i in int(meta.count):
			var file := path.path_join("f%d.png" % i)
			if ResourceLoader.exists(file):
				list.append(load(file))
		if list.size() == int(meta.count):
			frames[kind] = list
			anchors[kind] = Vector2(meta.anchor[0], meta.anchor[1])
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var radius := Vector2((x - 31.5) / 28.0, (y - 15.5) / 12.0).length_squared()
			image.set_pixel(x, y, Color(0, 0, 0, exp(-radius * 3.0) * 0.55))
	shadow = ImageTexture.create_from_image(image)
	var tag := Image.create(24, 34, false, Image.FORMAT_RGBA8)
	tag.fill_rect(Rect2i(11, 0, 2, 12), Color("78634b"))
	tag.fill_rect(Rect2i(1, 11, 22, 22), Color("8a7455"))
	tag.fill_rect(Rect2i(2, 12, 20, 20), Color("efe4c8"))
	paper = ImageTexture.create_from_image(tag)
	for good in ["food", "materials", "air", "influence", "tokens", "trade", "squad"]:
		icons[good] = preload("res://ui/art_pack.gd").icon_texture(good, 14)

## Mark sprites for reuse; hidden entries retain their facing state across frames.
func begin() -> void:
	used.clear()

## Hide pooled objects whose routes disappeared without retaining obsolete visible units.
func finish() -> void:
	for key in sprites:
		(sprites[key] as Sprite2D).visible = used.has(key)

## Attach the cargo label above the cart's draw order so its paper and icon remain legible beside the wheel.
func tag(key: String, at: Vector2, good: String, swing: float, alpha: float) -> void:
	used[key] = true
	if not sprites.has(key):
		var node := Sprite2D.new()
		node.texture = paper
		node.offset = Vector2(0, 12)
		node.z_index = 2
		var icon := Sprite2D.new()
		icon.name = "Good"
		icon.position = Vector2(0, 17)
		node.add_child(icon)
		parent.add_child(node)
		sprites[key] = node
	var node: Sprite2D = sprites[key]
	node.position = at
	node.rotation = swing
	node.scale = Vector2.ONE * 0.65
	node.modulate = Color(1, 1, 1, alpha)
	node.visible = true
	var icon: Sprite2D = node.get_node("Good")
	icon.texture = icons.get(good)
	if icon.texture != null:
		icon.scale = Vector2.ONE * 16.0 / maxf(icon.texture.get_width(), icon.texture.get_height())

## Cache one shader material per owner colour so each sprite has an independent faction tint.
func _material(col: Color) -> ShaderMaterial:
	var key := col.to_html()
	if not materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = TINT
		material.set_shader_parameter("owner_color", col)
		materials[key] = material
	return materials[key]

## Draw a sprite anchored to its original rail or sole line, with a softened turn and restrained slope.
func paint(key: String, kind: String, at: Vector2, direction: Vector2, col: Color, height: float, distance: float, time: float, still: bool, idle: bool, alpha: float = 1.0) -> bool:
	if not frames.has(kind):
		return false
	used[key] = true
	var fresh := not sprites.has(key)
	if fresh:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		parent.add_child(sprite)
		sprites[key] = sprite
	var node: Sprite2D = sprites[key]
	var list: Array = frames[kind]
	var size: Vector2 = (list[0] as Texture2D).get_size()
	var factor := height / size.y
	var index := 0 if still or idle else int(distance / maxf(0.01, distance_per_frame)) % list.size()
	node.texture = list[index]
	node.offset = -Vector2(anchors[kind])
	node.position = at
	node.material = _material(col)
	node.modulate = Color(1, 1, 1, alpha)
	node.visible = true
	var facing := -1.0 if direction.x < 0 else 1.0
	var people := kind.begins_with("squad") or kind == "expedition_walk"
	var limit := deg_to_rad(4.0 if people else 6.0)
	var angle := clampf(atan2(direction.y * facing, absf(direction.x)), -limit, limit)
	var dt := clampf(time - float(node.get_meta("time", time)), 0.0, 0.1)
	var face_now := facing if fresh or still else move_toward(float(node.get_meta("face", facing)), facing, dt * 2.0 / 0.15)
	node.set_meta("face", face_now)
	node.set_meta("time", time)
	node.rotation = angle if fresh or still else lerp_angle(node.rotation, angle, 1.0 - exp(-dt / 0.15))
	node.scale = Vector2(face_now * factor, factor)
	return true

## Integrate a trapezoidal velocity curve, preserving constant cruise speed between short station eases.
static func travel(time: float, duration: float) -> float:
	var t := clampf(time, 0.0, duration)
	var start := minf(0.4, duration * 0.3)
	var stop := minf(0.5, duration * 0.3)
	var area := duration - (start + stop) * 0.5
	if t < start:
		return t * t / (2.0 * start * area)
	if t > duration - stop:
		return 1.0 - pow(duration - t, 2.0) / (2.0 * stop * area)
	return (t - start * 0.5) / area
