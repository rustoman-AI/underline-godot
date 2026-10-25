class_name Copy
extends RefCounted

## Player-facing Russian for the testing export. English stays the source string.

static var lang := "en"
static var map := {}
static var keys := {}
static var ready := false

const NOUNS := {
	"week": ["неделю", "недели", "недель"],
	"material": ["материал", "материала", "материалов"],
	"person": ["человек", "человека", "человек"],
	"people": ["человек", "человека", "человек"],
	"worker": ["рабочий", "рабочих", "рабочих"],
	"crew": ["бригада", "бригады", "бригад"],
}
const STOCK := {
	"power": ["энергия", "энергии", "энергий"],
	"air": ["воздух", "воздуха", "воздуха"],
	"food": ["еда", "еды", "еды"],
	"materials": ["материал", "материала", "материалов"],
	"tokens": ["жетон", "жетона", "жетонов"],
	"influence": ["влияние", "влияния", "влияний"],
}
const RES := {
	"air": "Воздух",
	"food": "Еда",
	"power": "Энергия",
	"materials": "Материалы",
	"tokens": "Жетоны",
	"influence": "Влияние",
	"hope": "Надежда",
	"discontent": "Недовольство",
}
const SEASONS := {
	"flood": "паводок",
	"cold": "холод",
	"cough": "кашель",
}
const SKILLS := {
	"care": "уход",
	"fight": "бой",
	"labor": "труд",
	"talk": "речь",
	"tech": "техника",
	"grit": "закалка",
	"wits": "смекалка",
	"voice": "голос",
	"senses": "чутьё",
}


static func boot() -> void:
	if ready:
		return
	ready = true
	_load_keys()
	lang = _detect()
	if lang == "ru" and not _load():
		lang = "en"


static func set_lang(code: String) -> void:
	if code != "ru" and code != "en":
		return
	lang = code
	ready = true
	_load_keys()
	if code == "ru":
		_load()
	else:
		map = {}


static func ru() -> bool:
	boot()
	return lang == "ru"


static func t(s: String) -> String:
	if s == "":
		return s
	boot()
	if keys.has(s):
		var row: Dictionary = keys[s]
		if lang == "ru" and str(row.get("ru", "")) != "":
			return str(row.ru)
		var en := str(row.get("en", ""))
		return en if en != "" else s
	if lang != "ru":
		return s
	return str(map.get(s, s))


## Fill a Texts key. `{a}` is the Russian feminine ending (empty for masculine).
static func fill(key: String, vars: Dictionary = {}) -> String:
	var line := t(key)
	var fem := bool(vars.get("fem", false))
	for token in vars:
		if str(token) == "fem":
			continue
		line = line.replace("{%s}" % str(token), str(vars[token]))
	return line.replace("{a}", "а" if fem else "")


static func clip(line: String, limit: int = 72) -> String:
	if line.length() <= limit:
		return line
	if limit <= 1:
		return "…"
	return line.substr(0, limit - 1) + "…"


static func count_noun(n: int, one: String) -> String:
	if one == "other" or one == "others":
		return str(n)
	var forms = NOUNS.get(one, null)
	if forms == null:
		return "%d %s" % [n, t(one)]
	return "%d %s" % [n, plural(n, forms)]


static func stock(n: int, key: String) -> String:
	if not ru():
		return "%d %s" % [n, key]
	var forms = STOCK.get(key, null)
	if forms == null:
		return "%d %s" % [n, t(key)]
	return "%d %s" % [n, plural(n, forms)]


static func res(key: String) -> String:
	if not ru():
		return key.capitalize()
	return str(RES.get(key, key.capitalize()))


static func season(id: String) -> String:
	if not ru():
		return id
	return str(SEASONS.get(id, id))


static func skill(key: String, cap := true) -> String:
	if not ru():
		return key.capitalize() if cap else key
	var word := str(SKILLS.get(key, key))
	if cap and word.length() > 0:
		return word.substr(0, 1).to_upper() + word.substr(1)
	return word


static func person(name: String) -> String:
	if not ru() or name == "":
		return name
	if map.has(name):
		return str(map[name])
	var bits: PackedStringArray = []
	for part in name.split(" ", false):
		bits.append(t(part))
	return " ".join(bits)


static func trait_list(names: Array) -> String:
	var bits: PackedStringArray = []
	for trait_name in names:
		var raw := str(trait_name)
		bits.append(t(raw) if ru() else raw)
	return ", ".join(bits)


static func gloss(line: String) -> String:
	if not ru() or line == "":
		return line
	var tags := [
		["No warning from ", "Нет вести от "],
		["ULTIMATUM ", "Ультиматум. "],
		["PRESSURE ", "Давление. "],
		["SEASON ", "Сезон. "],
		["SHORT ", "Нехватка. "],
		["AGENT ", ""],
		["FIND ", "Находка. "],
		["JOIN ", "К вам. "],
		["BATTLE ", "Бой. "],
		["WARN ", "Тревога. "],
		["DEFECT ", "Уход. "],
		["REVOLT ", "Бунт. "],
		["DEAL ", "Сделка. "],
		["PREACH ", "Проповедь. "],
		["ROT ", ""],
	]
	for pair in tags:
		var prefix := str(pair[0])
		if line.begins_with(prefix):
			return str(pair[1]) + line.substr(prefix.length())
	return t(line)


static func plural(n: int, forms: Array) -> String:
	var n_abs := absi(n) % 100
	var n1 := n_abs % 10
	if n_abs > 10 and n_abs < 20:
		return str(forms[2])
	if n1 == 1:
		return str(forms[0])
	if n1 >= 2 and n1 <= 4:
		return str(forms[1])
	return str(forms[2])


static func _detect() -> String:
	var picked := _arg_lang()
	if picked == "ru" or picked == "en":
		return picked
	picked = OS.get_environment("UNDERLINE_LANG").strip_edges().to_lower()
	if picked == "ru" or picked == "en":
		return picked
	Settings.load_file()
	if Settings.language == "ru" or Settings.language == "en":
		return Settings.language
	picked = _file_lang(OS.get_executable_path().get_base_dir().path_join("lang.txt"))
	if picked != "ru" and picked != "en" and OS.has_feature("ru"):
		return "ru"
	if picked != "ru" and picked != "en":
		picked = _file_lang(ProjectSettings.globalize_path("res://data/lang.txt"))
	if picked == "ru" or picked == "en":
		return picked
	return "en"


static func _arg_lang() -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var arg := str(args[i])
		if arg == "--lang" and i + 1 < args.size():
			return str(args[i + 1]).strip_edges().to_lower()
		if arg.begins_with("--lang="):
			return arg.trim_prefix("--lang=").strip_edges().to_lower()
	return ""


static func _file_lang(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_line().strip_edges().to_lower()


static func _load_keys() -> void:
	var f := FileAccess.open("res://data/ui_strings.json", FileAccess.READ)
	if f == null:
		keys = {}
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		keys = data
	else:
		keys = {}


static func _load() -> bool:
	var f := FileAccess.open("res://data/ru.json", FileAccess.READ)
	if f == null:
		push_error("Underline: cannot open data/ru.json")
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		push_error("Underline: bad data/ru.json")
		return false
	map = data
	return true
