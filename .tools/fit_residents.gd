extends SceneTree

## Fits hand-drawn resident figures to game sprites. It only trims, scales, aligns and recolours an existing
## image; it never draws or composes a pose.
##   godot --headless --path . -s res://.tools/fit_residents.gd
##
## Input: incoming-art/residents_v2/<batch>/<stem>.png (1000x3000 RGBA, one standing figure facing right) for
## every stem in .tools/fit_residents.json "accepted". Output: incoming-art/residents_v2/game/<stem>.webp and
## game/palettes/<name>/<stem>.webp, plus a table: stem / source px / scaled px / baseline fix / warnings.
##
## Fit:
## - Body height runs from the first row of ink to the soles. The soles are the lowest row where at least
##   SOLE_MIN of nominal_src is opaque, so a cane tip, a dangling strap or a bench leg below the shoes does not
##   count. "baseline fix" is how far the lowest pixel sits below the soles (source px).
## - One scale for every standing figure: nominal_src source px -> nominal_px game px, so each person keeps
##   the height they were drawn at relative to the others. Anyone taller than HEIGHT_MAX is scaled down to it;
##   shorter than HEIGHT_MIN is flagged, not stretched. A seated stem ("seated": true in "stems") is scaled
##   so its head-to-floor height is SEATED of nominal_px * standing_ratio.
## - Soles land on BASELINE in a CANVAS_H canvas, so with the EDGE border they sit where the old poses touch the
##   canvas bottom and the game's floor line does not move. Ink below the soles (a cane tip) that reaches the
##   border is trimmed and noted.
## - figures.json in the output folder marks the set for the game (ui/station.gd, _load_incoming_figures):
##   when it is installed with the sprites, those sprites get the lighter tint "tint_mix" from the settings. The torso (ink centroid of the chest band, searched around the
##   head) sits on the canvas centre line. The canvas is CANVAS_W wide unless a prop reaches further, then it is
##   widened symmetrically so the torso stays centred. EDGE px of transparent border all round.
## - Resampling: Lanczos on premultiplied alpha (no dark or light fringe), alpha <= 8/255 cleared. The outline
##   check compares the share of dark pixels on the silhouette edge before and after.
## - "head_y", "sole_y", "torso_x" (source px) in "stems" override the measurement for one stem.
##
## Palettes (recolour of clothing only, applied to the fitted sprite):
## - Kept as drawn: ink and deep shadow (value < INK_V), the head band (top HEAD_BAND of the body: hair, face,
##   hat), the accent (saturation > ACCENT_S and value > ACCENT_V: hi-vis, a bright jacket or scarf), and this
##   person's skin. The skin model is the median hue/saturation/value of the face rows; pixels below the head
##   within SKIN_H / SKIN_S / SKIN_V of it are kept, with a soft edge so hands do not speckle. A covered face
##   (welding mask) falls back to hue 0.02..0.11, saturation 0.18..0.62, value >= 0.40.
## - Everything else is clothing: hue set to the palette hue (a partial pull sends red through magenta),
##   saturation * sat + sat_add, value * val. Mid-value rule: a recoloured pixel never ends below
##   min(original, MID_FLOOR) and never more than MAX_DARKEN darker than it was, so clothes cannot fall toward
##   black. The table prints near-black pixels (value < 0.2) in the base sprite and in the darkest palette.
## - The shipped palettes in assets/figures/poses/palettes came from recolour packs, not a script, and darken
##   clothing toward black (security: value 0.24 -> 0.10), so they break the mid-value rule. The names are
##   kept; the parameters below are new.

const SRC_ROOT := "res://incoming-art/residents_v2"
const OUT_DIR := "res://incoming-art/residents_v2/game"
const SETTINGS := "res://.tools/fit_residents.json"
const CANVAS_W := 212
const CANVAS_H := 660
const BASELINE := 656
const EDGE := 2
const SOLE_MIN := 0.03
const SEATED := 0.78
const HEIGHT_MIN := 520
const HEIGHT_MAX := 600
const WEBP_QUALITY := 0.8
const INK_V := 0.22
const HEAD_BAND := 0.15
const MID_FLOOR := 0.30
const MAX_DARKEN := 0.08
const ACCENT_S := 0.55
const ACCENT_V := 0.55
const SKIN_H := 0.035
const SKIN_S := 0.18
const SKIN_V := 0.22
const PALETTES := {
	"drab": {"hue": 0.22, "sat": 0.55, "sat_add": 0.03, "val": 0.98},
	"ochre": {"hue": 0.10, "sat": 0.85, "sat_add": 0.06, "val": 1.00},
	"security": {"hue": 0.61, "sat": 0.60, "sat_add": 0.04, "val": 0.95},
	"slate": {"hue": 0.57, "sat": 0.40, "sat_add": 0.03, "val": 1.02},
}


func _init() -> void:
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	var nominal_src := float(settings.get("nominal_src", 2400))
	var nominal_px := float(settings.get("nominal_px", 570))
	var overrides: Dictionary = settings.get("stems", {})
	var sources := _find_sources()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for name in PALETTES:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR.path_join("palettes").path_join(str(name))))
	print("%-12s %-8s %-22s %-7s %-22s %-9s %-11s %-11s %s" % ["stem", "batch", "source px (body/bbox)", "ratio", "scaled px (body/canvas)", "baseline", "outline", "near-black", "notes"])
	var failed: PackedStringArray = []
	for stem in settings.get("accepted", []):
		stem = str(stem)
		if not sources.has(stem):
			print("%-12s missing source" % stem)
			failed.append(stem)
			continue
		var row := _fit(stem, str(sources[stem]), nominal_src, nominal_px, overrides.get(stem, {}))
		print(row.line)
		if not row.warnings.is_empty():
			failed.append(stem)
	var manifest := FileAccess.open(ProjectSettings.globalize_path(OUT_DIR.path_join("figures.json")), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"set": "residents_v2", "tint_mix": float(settings.get("tint_mix", 0.0))}, "\t") + "\n")
	manifest.close()
	print("FIT done, %d stems, flagged: %s" % [settings.get("accepted", []).size(), "none" if failed.is_empty() else ", ".join(failed)])
	quit(0)


## stem -> source path, from every batch folder except sources/ and game/.
func _find_sources() -> Dictionary:
	var out := {}
	var batches := Array(DirAccess.get_directories_at(SRC_ROOT))
	batches.sort()
	for batch in batches:
		if str(batch) == "game":
			continue
		for file in DirAccess.get_files_at(SRC_ROOT.path_join(str(batch))):
			if str(file).ends_with(".png") and not str(file).begins_with("contact"):
				out[str(file).get_basename()] = SRC_ROOT.path_join(str(batch)).path_join(str(file))
	return out


func _fit(stem: String, path: String, nominal_src: float, nominal_px: float, over: Dictionary) -> Dictionary:
	var warnings: PackedStringArray = []
	var notes: PackedStringArray = []
	var src := Image.load_from_file(ProjectSettings.globalize_path(path))
	src.convert(Image.FORMAT_RGBA8)
	var sw := src.get_width()
	var sh := src.get_height()
	var data := src.get_data()
	var counts := PackedInt32Array()
	counts.resize(sh)
	for y in sh:
		var n := 0
		var at := y * sw * 4 + 3
		for x in sw:
			if data[at + x * 4] >= 128:
				n += 1
		counts[y] = n
	var used := src.get_used_rect()
	var head_y := int(over.get("head_y", -1))
	if head_y < 0:
		for y in sh:
			if counts[y] >= 3:
				head_y = y
				break
	var sole_y := int(over.get("sole_y", -1))
	if sole_y < 0:
		var need := int(nominal_src * SOLE_MIN)
		for y in range(sh - 1, -1, -1):
			if counts[y] >= need:
				sole_y = y + 1
				break
	var body := float(sole_y - head_y)
	var fix := used.end.y - sole_y
	var seated := bool(over.get("seated", false))
	var target := nominal_px * body / nominal_src
	if seated:
		target = nominal_px * float(over.get("standing_ratio", 1.0)) * SEATED
	if not seated and target > HEIGHT_MAX:
		notes.append("capped from %.0f" % target)
		target = HEIGHT_MAX
	var k := target / body
	var torso := float(over.get("torso_x", -1))
	if torso < 0.0:
		var head_x := _centroid(data, sw, head_y, head_y + int(body * 0.10), 0.0, float(sw))
		torso = _centroid(data, sw, head_y + int(body * 0.20), head_y + int(body * 0.45), head_x - body * 0.13, head_x + body * 0.13)
		torso = _centroid(data, sw, head_y + int(body * 0.20), head_y + int(body * 0.45), torso - body * 0.11, torso + body * 0.11)
	var half := maxf(torso - used.position.x, used.end.x - torso) * k + EDGE + 1.0
	var width := CANVAS_W
	if half * 2.0 > CANVAS_W:
		width = int(ceil(half)) * 2
		notes.append("wide %d" % width)
	# Source window that maps onto the canvas, cut from a padded copy so it may run past the source edges.
	var win_w := int(round(width / k))
	var win_h := int(round(CANVAS_H / k))
	var win_x := int(round(torso - win_w * 0.5))
	var win_y := int(round(sole_y - BASELINE / k))
	var pad := Image.create(sw + win_w * 2, sh + win_h * 2, false, Image.FORMAT_RGBA8)
	pad.blit_rect(src, Rect2i(0, 0, sw, sh), Vector2i(win_w, win_h))
	var window := pad.get_region(Rect2i(win_x + win_w, win_y + win_h, win_w, win_h))
	window.premultiply_alpha()
	window.resize(width, CANVAS_H, Image.INTERPOLATE_LANCZOS)
	var out := _unpremultiply(window)
	var cut := _clear_edge(out)
	if cut.below:
		notes.append("ink under the soles trimmed at the canvas edge")
	if cut.other:
		warnings.append("ink cut by the %d px edge" % EDGE)
	var fitted: Image = out.duplicate()
	out.save_webp(ProjectSettings.globalize_path(OUT_DIR.path_join(stem + ".webp")), true, WEBP_QUALITY)
	# Measure what was written, not what was planned.
	var check := Image.load_from_file(ProjectSettings.globalize_path(OUT_DIR.path_join(stem + ".webp")))
	check.convert(Image.FORMAT_RGBA8)
	var m := _measure(check, int(nominal_px * SOLE_MIN))
	var height: int = m.base - m.top
	if absi(int(m.base) - BASELINE) > 1:
		warnings.append("baseline at %d" % m.base)
	if seated:
		if absf(height - target) > target * 0.03:
			warnings.append("seated height %d, want %.0f" % [height, target])
	elif height < HEIGHT_MIN or height > HEIGHT_MAX:
		warnings.append("height %d outside %d..%d" % [height, HEIGHT_MIN, HEIGHT_MAX])
	var ink_src := _edge_ink(src)
	var ink_out := _edge_ink(check)
	if ink_out < ink_src * 0.8:
		warnings.append("outline thinned (%.0f%% -> %.0f%% dark edge)" % [ink_src * 100.0, ink_out * 100.0])
	var black_base := _near_black(fitted)
	var black_pal := 0
	for name in PALETTES:
		var recoloured := _recolour(fitted, PALETTES[name], int(m.top), height)
		black_pal = maxi(black_pal, _near_black(recoloured))
		recoloured.save_webp(ProjectSettings.globalize_path(OUT_DIR.path_join("palettes").path_join(str(name)).path_join(stem + ".webp")), true, WEBP_QUALITY)
	if black_pal > black_base * 1.05 + 20:
		warnings.append("palette darkens clothing (%d -> %d near-black px)" % [black_base, black_pal])
	var line := "%-12s %-8s %-22s %-7s %-22s %-9s %-11s %-11s %s" % [
		stem, path.get_base_dir().get_file(),
		"%d / %d" % [int(body), used.size.y],
		"%.3f" % (body / nominal_src),
		"%d / %dx%d" % [height, width, CANVAS_H],
		"%+d src" % fix if fix != 0 else "0",
		"%.0f%%->%.0f%%" % [ink_src * 100.0, ink_out * 100.0],
		"%d/%d" % [black_base, black_pal],
		"; ".join((["seated"] if seated else []) + Array(notes) + (Array(warnings) if not warnings.is_empty() else ["ok"])),
	]
	return {"line": line, "warnings": warnings}


## Mean x of opaque pixels in rows [y0, y1) between columns x0 and x1.
func _centroid(data: PackedByteArray, w: int, y0: int, y1: int, x0: float, x1: float) -> float:
	var sum := 0.0
	var n := 0.0
	var a := maxi(int(x0), 0)
	var b := mini(int(x1), w)
	for y in range(y0, y1):
		var row := y * w * 4 + 3
		for x in range(a, b):
			var alpha := data[row + x * 4]
			if alpha >= 128:
				sum += x
				n += 1.0
	return sum / n if n > 0.0 else (x0 + x1) * 0.5


func _unpremultiply(img: Image) -> Image:
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		var a := data[i + 3]
		if a <= 8:
			data[i] = 0
			data[i + 1] = 0
			data[i + 2] = 0
			data[i + 3] = 0
			continue
		if a < 255:
			data[i] = mini(255, int(round(data[i] * 255.0 / a)))
			data[i + 1] = mini(255, int(round(data[i + 1] * 255.0 / a)))
			data[i + 2] = mini(255, int(round(data[i + 2] * 255.0 / a)))
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## Clears the transparent border and says whether visible ink was removed under the soles (a cane tip, a bench
## leg) or anywhere else.
func _clear_edge(img: Image) -> Dictionary:
	var cut := {"below": false, "other": false}
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if x >= EDGE and x < w - EDGE and y >= EDGE and y < h - EDGE:
				continue
			if img.get_pixel(x, y).a > 0.25:
				cut["below" if y >= BASELINE else "other"] = true
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	return cut


## Top row of ink and the row under the soles (lowest row with at least `need` opaque pixels).
func _measure(img: Image, need: int) -> Dictionary:
	var top := -1
	var base := -1
	for y in img.get_height():
		var n := 0
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				n += 1
		if n >= 1 and top < 0:
			top = y
		if n >= need:
			base = y + 1
	return {"top": top, "base": base}


## Share of silhouette edge pixels (opaque, next to transparent) that are dark ink.
func _edge_ink(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var edge := 0
	var dark := 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := (y * w + x) * 4
			if data[i + 3] < 128:
				continue
			if data[i + 3 - 4] >= 128 and data[i + 3 + 4] >= 128 and data[i + 3 - w * 4] >= 128 and data[i + 3 + w * 4] >= 128:
				continue
			edge += 1
			if 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2] < 0.3 * 255.0:
				dark += 1
	return float(dark) / maxf(edge, 1)


func _near_black(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a >= 0.5 and c.v < 0.2:
				n += 1
	return n


## This person's skin: median hue, saturation and value of warm, non-ink pixels in the face rows (lower part
## of the head band). Empty when the face is covered (a welding mask), then the generic skin range applies.
func _skin(img: Image, top: int, height: int) -> Dictionary:
	var hs: Array = []
	var ss: Array = []
	var vs: Array = []
	for y in range(top + int(height * 0.06), top + int(height * 0.13)):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.9 or c.v < INK_V or c.s < 0.15:
				continue
			if c.h > 0.13 and c.h < 0.95:
				continue
			hs.append(fposmod(c.h + 0.5, 1.0))
			ss.append(c.s)
			vs.append(c.v)
	if hs.size() < 40:
		return {}
	hs.sort()
	ss.sort()
	vs.sort()
	var mid := hs.size() / 2
	return {"h": fposmod(float(hs[mid]) - 0.5, 1.0), "s": ss[mid], "v": vs[mid]}


## 1 for pixels to keep as drawn (skin, accent), 0 for clothing, soft in between.
func _keep(c: Color, skin: Dictionary) -> float:
	if c.s > ACCENT_S and c.v > ACCENT_V:
		return 1.0
	if skin.is_empty():
		return 1.0 if c.h >= 0.02 and c.h <= 0.11 and c.s >= 0.18 and c.s <= 0.62 and c.v >= 0.40 else 0.0
	var dh := absf(fposmod(c.h - float(skin.h) + 0.5, 1.0) - 0.5)
	var d := maxf(maxf(dh / SKIN_H, absf(c.s - float(skin.s)) / SKIN_S), absf(c.v - float(skin.v)) / SKIN_V)
	return clampf(1.5 - d, 0.0, 1.0)


func _recolour(img: Image, p: Dictionary, top: int, height: int) -> Image:
	var out: Image = img.duplicate()
	var head_end := top + int(height * HEAD_BAND)
	var skin := _skin(img, top, height)
	for y in range(head_end, out.get_height()):
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a <= 0.0 or c.v < INK_V:
				continue
			var keep := _keep(c, skin)
			if keep >= 1.0:
				continue
			var s := clampf(c.s * float(p.sat) + float(p.sat_add), 0.0, 1.0)
			var v := clampf(c.v * float(p.val), 0.0, 1.0)
			v = maxf(v, minf(c.v, MID_FLOOR))
			v = maxf(v, c.v - MAX_DARKEN)
			var new := Color.from_hsv(float(p.hue), s, v, c.a)
			out.set_pixel(x, y, new.lerp(c, keep))
	return out
