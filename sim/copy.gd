class_name Copy
extends RefCounted

## Player-facing Russian for the testing export. English stays the source string.

static var lang := "en"
static var map := {}
static var keys := {}
static var ready := false

const NOUNS := {
	"smaller matter": ["дело помельче", "дела помельче", "дел помельче"],
	"week": ["неделю", "недели", "недель"],
	"material": ["материал", "материала", "материалов"],
	"person": ["человек", "человека", "человек"],
	"people": ["человек", "человека", "человек"],
	"worker": ["работник", "работника", "работников"],
	"soldier": ["боец", "бойца", "бойцов"],
	"crew": ["бригада", "бригады", "бригад"],
	"story": ["историю", "истории", "историй"],
	"bed": ["койка", "койки", "коек"],
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


## Fill a Texts key. `{a}` is the Russian feminine ending (empty for masculine). `{ee}` is stripped.
static func fill(key: String, vars: Dictionary = {}) -> String:
	var line := t(key)
	var fem := bool(vars.get("fem", false))
	for token in vars:
		if str(token) == "fem":
			continue
		line = line.replace("{%s}" % str(token), str(vars[token]))
	return line.replace("{a}", "а" if fem else "").replace("{ee}", "")


static func clip(line: String, limit: int = 72) -> String:
	if line.length() <= limit:
		return line
	if limit <= 1:
		return "…"
	return line.substr(0, limit - 1) + "…"


static func pack(key: String) -> Dictionary:
	boot()
	if keys.has(key):
		var row: Dictionary = keys[key]
		var en := str(row.get("en", key))
		var ru := str(row.get("ru", ""))
		if ru == "":
			ru = en
		return {"en": en, "ru": ru}
	return {"en": key, "ru": t(key)}


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
	if line == "":
		return line
	var rival := _rival_line(line) if ru() else ""
	if rival != "":
		return rival
	## Log tags as the player reads them: [tag, Russian, English].
	var tags := [
		["No warning from ", "Нет вести от ", "No warning from "],
		["ULTIMATUM ", "Ультиматум. ", "Ultimatum. "],
		["PRESSURE ", "Давление. ", "Pressure. "],
		["SEASON ", "Сезон. ", "Season. "],
		["SHORT ", "Нехватка. ", "Shortage. "],
		["AGENT ", "", ""],
		["FIND ", "Находка. ", "Find. "],
		["JOIN ", "Пополнение. ", "Joined. "],
		["LOST ", "Потеря. ", "Lost. "],
		["SICK ", "Болезнь. ", "Sickness. "],
		["BACK ", "Возвращение. ", "Back. "],
		["BATTLE ", "Бой. ", "Battle. "],
		["WARN ", "Тревога. ", "Warning. "],
		["DEFECT ", "Уход. ", "Defection. "],
		["REVOLT ", "Бунт. ", "Revolt. "],
		["DEAL ", "Сделка. ", "Deal. "],
		["PREACH ", "Проповедь. ", "Sermon. "],
		["TRUTH ", "Правда. ", "Truth. "],
		["TESTIMONY ", "Свидетельство. ", "Testimony. "],
		["ROT ", "", ""],
		["PUSH ", "", ""],
	]
	for pair in tags:
		var prefix := str(pair[0])
		if line.begins_with(prefix):
			var rest := line.substr(prefix.length())
			if not ru() and rest != "" and str(pair[2]).ends_with(". "):
				rest = rest.substr(0, 1).to_upper() + rest.substr(1)
			return str(pair[1] if ru() else pair[2]) + rest
	return t(line)


## Rival log lines as Game._log writes them in English; ru.json keys them by the template. Most specific first.
const RIVAL_LINES := [
	"BATTLE %s takes %s", "BATTLE %s is thrown back from %s", "DEFECT %s leaves for %s",
	"REVOLT %s throws the garrison out", "PREACH The Synod speaks at %s", "DEAL %s asks to join", "DEAL %s (%d)",
	"%s takes %s",
]
static var _rival_forms: Array = []


## A rival log line in Russian with its station, commander and faction names translated, or "" when the line
## is not one of RIVAL_LINES or a name in it has no Russian.
static func _rival_line(line: String) -> String:
	if _rival_forms.is_empty():
		var spec := RegEx.create_from_string("%[sd]")
		for template in RIVAL_LINES:
			var pattern := "^"
			var kinds: Array = []
			var at := 0
			for hit in spec.search_all(template):
				pattern += _escape(template.substr(at, hit.get_start() - at))
				pattern += "(.+?)" if hit.get_string() == "%s" else "(-?\\d+)"
				kinds.append(hit.get_string())
				at = hit.get_end()
			pattern += _escape(template.substr(at)) + "$"
			_rival_forms.append([template, RegEx.create_from_string(pattern), kinds])
	for form in _rival_forms:
		if not map.has(form[0]):
			continue
		var found: RegExMatch = form[1].search(line)
		if found == null:
			continue
		var args: Array = []
		for i in form[2].size():
			var value := found.get_string(i + 1)
			if form[2][i] == "%d":
				args.append(int(value))
			elif map.has(value):
				args.append(str(map[value]))
			else:
				args = []
				break
		if args.size() == form[2].size():
			return str(map[form[0]]) % args
	return ""


static func _escape(text: String) -> String:
	var out := ""
	for ch in text:
		out += "\\" + ch if "\\^$.|?*+()[]{}".contains(ch) else ch
	return out


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
	if OS.get_locale_language() == "ru":
		return "ru"
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
	_merge_pack("res://data/raid_share.json")
	_merge_pack("res://data/synod_score.json")


## A locked Texts pack. `by_key` wins over ui_strings for the same id. Meta keys are skipped.
static func _merge_pack(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return
	var rows = data.get("by_key", {})
	if not (rows is Dictionary):
		return
	for key in rows:
		var row = rows[key]
		if row is Dictionary and (row.has("en") or row.has("ru")):
			keys[str(key)] = row


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
	for file in ["events_pool.json", "events_leaders.json", "events_story.json"]:
		var extra = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + file))
		if extra is Dictionary and extra.get("ru", null) is Dictionary:
			for en in extra.ru:
				if not map.has(en):
					map[en] = extra.ru[en]
	return true
