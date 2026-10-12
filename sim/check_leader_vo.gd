extends SceneTree

## Leader voice files: all 110 expected names (5 leaders x 11 keys x EN/RU) are in assets/audio/vo, load as
## Ogg Vorbis with a sane length, and no stray lead_* file uses an unknown faction or key.
## Loudness is measured outside Godot: tools/check_leader_vo_loudness.ps1.
##   godot --headless --path . -s res://sim/check_leader_vo.gd

const FACTIONS := ["depot", "directorate", "synod", "exchange", "black_flag"]


func _init() -> void:
	var bad: PackedStringArray = []
	var expected := {}
	var total := 0.0
	var shortest := INF
	var longest := 0.0
	for fid in FACTIONS:
		for key in Voice.LEADER_KEYS:
			for lang in ["en", "ru"]:
				var path := Voice.leader_file(fid, key, lang)
				expected[path.get_file()] = true
				if not ResourceLoader.exists(path):
					bad.append("missing " + path.get_file())
					continue
				var stream = load(path)
				if not stream is AudioStreamOggVorbis:
					bad.append("not Ogg Vorbis: " + path.get_file())
					continue
				var length: float = stream.get_length()
				if length < 1.0 or length > 40.0:
					bad.append("%s is %.1f s" % [path.get_file(), length])
				total += length
				shortest = minf(shortest, length)
				longest = maxf(longest, length)
	for file in DirAccess.get_files_at("res://assets/audio/vo"):
		if str(file).begins_with("lead_") and str(file).ends_with(".ogg") and not expected.has(str(file)):
			bad.append("unexpected " + str(file))
	if bad.is_empty():
		print("Leader voice: %d files decode, %.1f to %.1f s, %.0f s in all" % [expected.size(), shortest, longest, total])
		print("LEADER VO CHECK OK")
		quit(0)
	else:
		for line in bad:
			print("FAIL " + line)
		print("LEADER VO CHECK FAILED")
		quit(1)
