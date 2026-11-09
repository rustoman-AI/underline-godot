extends SceneTree

## P97 Decision Receipts.
##   godot --headless --path . -s res://sim/check_decision_receipts.gd
## Headless logic must pass. Screenshots are SKIP without a renderer. They are not a pass.
##   UNDERLINE_SHOTS_DIR=/tmp/receipts godot --rendering-driver opengl3 --path . -s res://sim/check_decision_receipts.gd

const EN := {
	"receipt.details": "Details",
	"receipt.title": "Decision record",
	"receipt.week": "Week {n}",
	"receipt.chosen": "Chosen: {choice}",
	"receipt.changes": "Tracked immediate changes",
	"receipt.none": "No tracked immediate changes.",
	"receipt.result.success": "Check succeeded.",
	"receipt.result.failure": "Check failed.",
	"receipt.result.unrecorded": "Result not recorded.",
	"receipt.result.bet_success": "The bet paid out.",
	"receipt.result.bet_failure": "The bet did not pay out.",
	"receipt.previous": "Earlier decision · Week {n}",
	"receipt.pruned": "Earlier entry no longer retained.",
	"receipt.event_missing": "Recorded event",
	"receipt.choice_missing": "Recorded choice",
	"receipt.locale_fallback": "Original language",
	"receipt.back": "Back",
	"receipt.opinion": "Faction opinion",
	"receipt.regard": "Leader regard",
	"receipt.scope": "Selected numeric changes only; health and other effects are not summarized.",
}
## Baseline captured on master 0a43a462 before this pack. Five streams: rng|net|check|story|crunch.
const MASTER_HASH := [530485220, 1440811691, 812324724, 1813219972, 325093522, 595908171, 2008396391, 1780671410, 856785781, 158007594, 927219026, 88326475, 1637882681, 1666385348, 109892276, 1909826692, 17422148, 1248879695, 53792616, 1638580681, 1667606982, 225933280, 1956210069, 664024800, 910860718, 1749011044, 317060065, 247917712, 1212469253, 1368249385, 1040415204, 699411940, 240273769, 1927554047, 1435382424, 289105020, 1555551452, 991802799, 73486466, 389179272, 1820378459, 1369693866, 479947888, 2022586468, 14678228, 2098321440, 788241386, 462862112, 1956553458, 372817444, 1943912010, 743372996, 2101744492, 1885192366, 1640866844, 1363718713, 230067406, 1872288106, 522666115, 82470554]
const MASTER_RNG := [
	"-1585339728350562702|6676566666903880397|6129313785023254715|8081095023476173026|5780948062496209201",
	"2263128410926310566|-7835076549422186616|-5526112971273438746|905056632411351231|2552966713760380601",
	"1373931732943921289|1783748984437365361|483231718630489227|-6270981758653470564|-675014634975447999",
	"3685080405321119105|-5690720446655041510|-5521547936187064338|4999723923991259257|-3902995983711276599",
	"-4336775713744499766|22243446652669659|5451583589870007663|-7754271433806960909|-7130977332447105199",
	"-5425830539872008847|-5376419702908897001|-4992828016903685464|9094391215571167283|8087785392526617817",
	"-8813835764021641168|4796676548153823597|6073866404536649503|1918352824506345488|4859804043790789217",
	"-3397987660684092215|1996351798327209185|7653542855634069368|-5257685566558476307|1631822695054960617",
	"-7854417423588077164|7784414614281815516|4773853394716760611|-7501749976870586591|-1596158653680867983",
	"8855678461241032628|5392349805890692337|-3935388178336927716|-1163018274978568281|-4824140002416696583",
	"-3027304067663931945|9111716650904331335|-6782242983266741837|-8339056666043390076|-8052121351152525183",
	"1123355943627227282|-892698324522160909|-772898293362813864|6717474375486488842|7166641373821197833",
	"4162124271067477832|-3299147274498462739|4096123199563513559|-4214975842922741974|3938660025085369233",
	"1906176367185268939|3248394225091854551|-8866768486987269834|7026316308181247771|710678676349540633",
	"5118093409014124457|-1035433048572371034|3757258101986890033|-149722082883574024|-2517302672386287967",
	"5618013846302999256|1182074478704289420|-2349228420486791094|-7325760473948395819|-5745284021122116567",
	"6449494343882219025|-2933333349064248250|-2084868460845101657|3944945208696334002|-8973265369857945167",
	"-8894798977015712223|-2881414409911311060|-1820508501203412220|-3231093182368487793|6245497355115777849",
	"7657923954511408657|1256315374422460943|-1556148541561722783|8039612500276242028|3017516006379949249",
	"-3139762463667362484|8886652360415899567|-6940335755899057420|863574109211420233|-210465342355879351",
	"-3868976949746688221|-8139715214848352397|5678565748422012393|-6312464281853401562|-3438446691091707951",
	"5312672055697625829|54872047395972552|3980316384547811018|4958241400791328259|-6666428039827536551",
	"-2563709367878448925|-5846646993921969686|-5977119390354951213|8296609859377732012|8552334685146186465",
	"5789803820446606626|5079693697942768619|-234348743353275598|9052908692371236285|5324353336410357865",
	"-7658883018147384993|-9047597772066875656|2062932614103772403|1970583894957949895|2096371987674529265",
	"-3474716156043320440|-8102418466356661731|-8875793003255580322|-5299168089758407305|-1131609361061299335",
	"1019986837254261418|-3105262969631398202|1724067516527148877|5971537592886322516|-4359590709797127935",
	"526918837833821428|-8790042407477786641|3142896376552275624|-1204500798178499279|-7587572058532956535",
	"5857470338908465293|1821561900907946956|9152241066456203597|-8380539189243321074|7631190666440766481",
	"411807272956517718|118376195865363389|-3285158317349420046|-5081373037463398137|4403209317704937881",
	"-1017268945313840124|-2778259205674329089|1616170974138550461|-4285871897663413048|1175227968969109281",
	"-9096448536366469118|-3302674076214173651|1880530933780239898|8035123902234005152|-2052753379766719319",
	"-4654531867933292830|5012160505097674272|2144890893421929335|6161705566307518763|-5280734728502547919",
	"1006106534871290463|5809473685777199358|2409250853063618772|-7367242997148326817|-8508716077238376519",
	"541265964446034954|1505139920635553316|-2124253928178526385|6833011559340405297|6710046647735346497",
	"2284983904068117553|917602496745865007|199174577432343010|3629905511036740514|3482065298999517897",
	"-5059225912319661127|1606661762870611959|29742028644031247|426799462733075731|254083950263689297",
	"-1027430215061216389|-2615643042225614003|3466690691630376520|822091586011489235|-2973897398472139303",
	"9027875049845338052|567209531563476284|-309123068932592279|-6353946805053332560|-6201878747207967903",
	"872952385318148321|5940477407453112181|1468056360561204836|4916758877591397261|9016883977765755113",
	"9096932331346532624|2723615892091147242|7477401050465132809|-2259279513473424534|5788902629029926513",
	"7797378451090511854|-5804038551664980842|4524130530197134268|9011426169171305287|2560921280294097913",
	"-3036338326907633774|6459563837000417296|4788490489838823705|1835387778106483492|-667060068441730687",
	"4949430033756694024|2072459486767249440|5052850449480513142|-5340650612958338303|-3895041417177559287",
	"-2019168584709080260|1282391732359727005|-1325718361662462857|-6751304849986690917|-7123022765913387887",
	"-5186624417967415972|-7825016513288773100|630636352565669442|-1245983321378430277|8095739959060335129",
	"7156820901573135049|-4304451151624789226|-1664583459239086383|-8422021712443252072|4867758610324506529",
	"6366839790701817344|834329403296293954|6110290288047270890|2848683970201477749|1639777261588677929",
	"-4221477108375557664|-1765322114409524459|6374650247688960327|-4327354420863344046|-1588204087147150671",
	"8981781019010509843|-2689338466276120039|6639010207330649764|6943351261781385775|-4816185435882979271",
	"9060652993388935187|-5053588108098227325|-6216128345333793925|-7523197066099127999|-8044166784618807871",
	"-1817310050751158020|-3016119884983836796|-2511746203180645198|-7408725520348257815|7174595940354915145",
	"-1155597687575506850|-2256735384589913627|5802561034474062021|3861980162296472006|3946614591619086545",
	"4875287771243847255|-3075356966730348861|-2172798304302370946|-3314058228768349789|718633242883257945",
	"-2095823026771778390|-3650076661896787513|7960810005539096949|7956647453876380032|-2509348105852570655",
	"8528069930467022403|-5848558247384345519|5383851030476294324|-5091983233907900298|-5737329454588399255",
	"5546719287336099822|-8182815181943281506|-3358908947122204013|-6395429328253263558|-8965310803324227855",
	"-3952308445513158667|2343462382223927542|-1044203663425401346|4875276354391466263|6253451921649495161",
	"1701846859226185487|1925394724690256451|9018249844105854697|-2300762036673355532|3025470572913666561",
	"5764398353765017958|-7166396343776656311|-9164134269962007482|8969943645971374289|-202510775822162039",
]

var catalog: Catalog
var failed := false
var _shots_skipped := false
var _shots_saved := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("RECEIPT FAIL catalog")
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	_strings()
	_schema()
	_groups()
	_clamps()
	_checks()
	_stale_and_repeat()
	_rejected()
	_excluded()
	_provenance()
	_locale_and_load()
	_nested_and_ending()
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		_bad("balance.json changed")
	if not failed:
		_careful()
	await _ui()
	Copy.set_lang("en")
	if failed:
		print("RECEIPT FAIL")
		quit(1)
		return
	print("RECEIPT OK")
	if _shots_skipped:
		print("RECEIPT SHOTS SKIP")
	elif _shots_saved > 0:
		print("RECEIPT SHOTS OK %d" % _shots_saved)
	else:
		_bad("screenshots neither saved nor skipped")
		print("RECEIPT FAIL")
		quit(1)
		return
	quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_bad(msg)


func _rng(game: Game) -> String:
	return "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)]


func _game(run_seed := 4) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.pending.clear()
	game.week_event_ids = {}
	return game


func _put(game: Game, id: String) -> Dictionary:
	var copy: Dictionary = game._copy(game._event_by_id(id))
	game.pending = [copy]
	return copy


func _choice(ev: Dictionary, id: String) -> Dictionary:
	for choice in ev.get("choices", []):
		if str(choice.get("id", "")) == id:
			return choice
	return {}


func _take(game: Game, ev: Dictionary, id: String, person := "") -> bool:
	return game.apply({"kind": "event", "event_id": str(ev.get("id", "")), "choice_id": id, "person": person})


func _event_rows(game: Game) -> Array:
	var rows: Array = []
	for row in game.journal:
		if row is Dictionary and str(row.get("kind", "")) == "event":
			rows.append(row)
	return rows


func _strings() -> void:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/decision_receipts.json"))
	_ok(pack is Dictionary, "pack")
	if not (pack is Dictionary):
		return
	var status := str(pack.get("_status", ""))
	_ok(status.find("INTERIM") >= 0 and status.find("not Texts-approved") >= 0, "interim status")
	_ok(str(pack.get("_soft_dawn", "")) == "NONE", "soft dawn")
	var rows: Dictionary = pack.get("by_key", {})
	_ok(rows.size() == 20 and EN.size() == 20, "20 keys %d" % rows.size())
	Copy.set_lang("en")
	for key in EN:
		_ok(rows.has(key), "missing " + key)
		if not rows.has(key):
			continue
		_ok(str(rows[key].get("en", "")) == str(EN[key]), "EN drift " + key)
		_ok(Copy.t(key) == str(EN[key]), "Copy EN " + key)
		var ru := str(rows[key].get("ru", ""))
		_ok(ru != "" and ru != key and ru.find("TODO") < 0 and ru.find("lorem") < 0, "RU interim " + key)
	Copy.set_lang("ru")
	for key in EN:
		var shown := Copy.t(key)
		_ok(shown != key and shown.find("receipt.") < 0, "RU raw " + key)
	Copy.set_lang("en")
	var src := FileAccess.get_file_as_string("res://sim/copy.gd")
	_ok(src.find("decision_receipts.json") >= 0, "pack not merged")
	print("Strings: interim 20")


func _schema() -> void:
	_ok(Game.SAVE_SCHEMA == 27, "schema %s" % str(Game.SAVE_SCHEMA))
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	_ok(src.find("const SAVE_SCHEMA := 27") >= 0, "schema const")
	_ok(src.find("const SAVE_SCHEMA := 26") < 0, "schema 26 claimed")
	_ok(src.find("var shiftword_state") < 0, "shiftword imported")
	_ok(src.find("V26_ADDED") >= 0 and src.find("receipt_seq") >= 0, "migration")
	var game := _game()
	var old := game.export_state()
	old["schema"] = 25
	old.erase("receipt_seq")
	var host := _game(9)
	host.receipt_seq = 44
	_ok(host.import_state(old), "schema 25 load " + host.load_error)
	_ok(host.receipt_seq == 0, "legacy seq %s" % str(host.receipt_seq))
	var bare := game.export_state()
	bare["schema"] = 27
	bare.erase("receipt_seq")
	var refuse := Game.new()
	refuse.catalog = catalog
	_ok(not refuse.import_state(bare), "schema 27 without seq should fail")
	var gap := game.export_state()
	gap["schema"] = 26
	gap.erase("receipt_seq")
	gap["shiftword_state"] = {"ruth": 1}
	var row: Dictionary = {"kind": "event", "week": 2, "event_id": "stores_turn", "choice_id": "feast", "receipt": {
		"v": 1, "instance": 6, "event_id": "stores_turn", "choice_id": "feast",
		"title": {"en": "Kept"}, "label": {"en": "Kept choice"}, "original_lang": "en",
	}}
	gap.journal = [row]
	var loaded := _game(8)
	_ok(loaded.import_state(gap), "schema 26 with stray shiftword " + loaded.load_error)
	_ok(loaded.receipt_seq == 6, "seq raised to existing id %s" % str(loaded.receipt_seq))
	_ok(loaded.get("shiftword_state") == null, "shiftword survived import")
	_ok(loaded.journal.size() == 1 and loaded.journal[0].receipt.instance == 6, "schema 26 kept receipt")
	var bad := game.export_state()
	bad["schema"] = 27
	bad.journal.append({"kind": "event", "week": 1, "event_id": "x", "choice_id": "y", "receipt": {"v": 9, "instance": "no"}})
	var healed := _game(7)
	_ok(healed.import_state(bad), "malformed receipt blocked load " + healed.load_error)
	var last = healed.journal[healed.journal.size() - 1]
	_ok(not last.has("receipt"), "malformed receipt still visible")
	print("Schema: 27, 26 reserved")


func _groups() -> void:
	var game := _game()
	var before := _rng(game)
	var ev := _put(game, "stores_turn")
	_ok(_take(game, ev, "feast"), "feast")
	_ok(_rng(game) == before, "plain choice moved rng")
	var row: Dictionary = _event_rows(game)[-1]
	var receipt: Dictionary = row.get("receipt", {})
	_ok(int(receipt.get("instance", 0)) == 1 and game.receipt_seq == 1, "instance")
	_ok(str(row.get("kind", "")) == "event" and str(row.get("choice_id", "")) == "feast", "row identity")
	var deltas: Dictionary = receipt.get("deltas", {})
	_ok(int(deltas.get("stock", {}).get("food", 0)) == -6, "food %s" % str(deltas))
	_ok(int(deltas.get("hope", 0)) == 2, "hope")
	_ok(int(deltas.get("discontent", 0)) == -1, "discontent")
	_ok(not receipt.has("result"), "plain result")
	var mix := {
		"id": "fixture_mix",
		"title": {"en": "Mix", "ru": "Смесь"},
		"choices": [{
			"id": "take",
			"label": {"en": "Take the lot", "ru": "Взять всё"},
			"cost": {"tokens": 2, "blueprints": 1},
			"food": 3,
			"hope": 1,
			"discontent": 1,
			"opinion_exchange": 2,
			"standing": {"directorate": 3},
			"synod": 4,
			"papers": 1,
		}],
	}
	game.stock.tokens = 30
	game.stock.blueprints = 4
	game.pending = [mix]
	var lang := Copy.lang
	_ok(_take(game, mix, "take"), "mix")
	_ok(Copy.lang == lang, "lang switched during apply")
	row = _event_rows(game)[-1]
	_ok(str(row.get("choice_id", "")) == "take", "mix row")
	deltas = row.receipt.deltas
	_ok(int(deltas.stock.tokens) == -2 and int(deltas.stock.blueprints) == -1 and int(deltas.stock.food) == 3, "stock net %s" % str(deltas.stock))
	_ok(int(deltas.hope) == 1 and int(deltas.discontent) == 1, "meters")
	_ok(int(deltas.opinions.exchange) == 2, "opinion")
	_ok(int(deltas.standing.directorate) == 3, "regard")
	_ok(not deltas.opinions.has("directorate") and not deltas.standing.has("exchange"), "merged dictionaries")
	_ok(int(deltas.synod) == 4 and int(deltas.papers) == 1, "synod papers")
	var lines = game.receipt_view(row).changes
	var joined := ""
	for line in lines:
		joined += str(line) + "\n"
	_ok(joined.find("Faction opinion") >= 0 and joined.find("Leader regard") >= 0, "labels %s" % joined)
	_ok(joined.find("receipt.") < 0, "raw key in changes")
	print("Groups: seven")


func _clamps() -> void:
	var game := _game()
	game.hope = 100
	var ev := _put(game, "stores_turn")
	_ok(_take(game, ev, "feast"), "clamped feast")
	var deltas: Dictionary = _event_rows(game)[-1].receipt.deltas
	_ok(not deltas.has("hope"), "authored hope copied %s" % str(deltas))
	_ok(int(deltas.stock.food) == -6 and int(deltas.discontent) == -1, "other deltas kept")
	game = _game()
	game.stock.tokens = 40
	game.opinions.exchange = 99
	ev = _put(game, "loan_next")
	_ok(_take(game, ev, "repay"), "repay")
	deltas = _event_rows(game)[-1].receipt.deltas
	_ok(int(deltas.stock.tokens) == -18, "tokens %s" % str(deltas))
	_ok(int(deltas.opinions.exchange) == 1, "clamped opinion %s" % str(deltas.opinions))
	_ok(not deltas.has("standing"), "regard invented")
	_ok(int(game.opinions.exchange) == 100, "opinion state")
	print("Clamps: hope and opinion")


func _force(game: Game, difficulty: int) -> Dictionary:
	var ev := _put(game, "queens_expedition")
	var choice := _choice(ev, "force")
	var check: Dictionary = choice.get("check", {}).duplicate(true)
	check.difficulty = difficulty
	choice.check = check
	return ev


func _checks() -> void:
	var game := _game()
	var streams := _rng(game)
	var ev := _force(game, 1)
	_ok(_take(game, ev, "force"), "white success")
	var row: Dictionary = _event_rows(game)[-1]
	var result: Dictionary = row.receipt.result
	_ok(str(result.kind) == "check" and str(result.tag) == "success", "success tag %s" % str(result))
	_ok(str(result.get("person_id", "")) != "" and game.people.has(str(result.person_id)), "person")
	_ok(str(result.get("name_en", "")) != "", "name")
	_ok(game.white_pending.is_empty(), "success parked")
	var parts := _rng(game).split("|")
	var was := streams.split("|")
	# Main rng moves inside the existing check life-note. Net, story and crunch must stay put.
	_ok(parts[1] == was[1] and parts[3] == was[3] and parts[4] == was[4], "check moved net/story/crunch")
	_ok(parts[2] != was[2], "check rng idle")
	game = _game()
	ev = _force(game, 99)
	var seq := game.receipt_seq
	_ok(_take(game, ev, "force"), "white fail")
	_ok(game.receipt_seq == seq + 1, "fail seq")
	row = _event_rows(game)[-1]
	var first: Dictionary = row.receipt.duplicate(true)
	_ok(str(first.result.tag) == "failure", "failure tag")
	_ok(not first.has("deltas") or first.deltas.is_empty(), "injury invented as numbers %s" % str(first.get("deltas", {})))
	_ok(game.white_pending.size() == 1 and game.pending.is_empty(), "white_pending")
	_ok(bool(_choice(game.white_pending[0], "force").get("locked", false)), "locked for retry")
	var view := game.receipt_view(row)
	_ok(bool(view.none) and str(view.result) == "Check failed.", "failure copy %s" % str(view.result))
	_ok(str(view.scope).find("health") >= 0, "scope")
	_ok(_place(game, "workshop"), "workshop")
	game._release_white_checks()
	_ok(not game.pending.is_empty() and bool(_choice(game.pending[0], "force").get("retry_open", false)), "retry reopened")
	var again: Dictionary = game.pending[0]
	var check: Dictionary = _choice(again, "force").get("check", {}).duplicate(true)
	check.difficulty = 99
	_choice(again, "force").check = check
	_ok(_take(game, again, "force"), "failed retry")
	var rows := _event_rows(game)
	_ok(rows.size() >= 2, "two receipts")
	_ok(int(rows[-2].receipt.instance) == int(first.instance) and str(rows[-2].receipt.result.tag) == "failure", "first rewritten")
	_ok(int(rows[-1].receipt.instance) != int(first.instance) and str(rows[-1].receipt.result.tag) == "failure", "second receipt")
	_ok(bool(_choice(game.pending[0], "force").get("spent", false)), "retry not spent")
	var bet := {
		"id": "fixture_bet",
		"title": {"en": "A side bet", "ru": "Ставка сбоку"},
		"choices": [{
			"id": "stake",
			"label": {"en": "Put the tokens down", "ru": "Поставить жетоны"},
			"cost": {"tokens": 4},
			"bet": {"target": 13, "win": 9},
		}],
	}
	game = _game()
	game.stock.tokens = 20
	game.pending = [bet]
	_ok(_take(game, bet, "stake"), "bet loss")
	result = _event_rows(game)[-1].receipt.result
	_ok(str(result.kind) == "bet" and str(result.tag) == "failure", "bet fail %s" % str(result))
	_ok(int(_event_rows(game)[-1].receipt.deltas.stock.tokens) == -4, "stake kept")
	_ok(str(game.receipt_view(_event_rows(game)[-1]).result) == "The bet did not pay out.", "bet copy")
	bet = bet.duplicate(true)
	bet.choices[0].bet.target = 2
	game.pending = [bet]
	var tokens := int(game.stock.tokens)
	_ok(_take(game, bet, "stake"), "bet win")
	result = _event_rows(game)[-1].receipt.result
	_ok(str(result.tag) == "success", "bet success")
	_ok(int(game.stock.tokens) == tokens - 4 + 9, "payout")
	_ok(str(game.receipt_view(_event_rows(game)[-1]).result) == "The bet paid out.", "bet win copy")
	print("Checks: white fail, retry, bet")


func _stale_and_repeat() -> void:
	var game := _game()
	var ev := _force(game, 1)
	_ok(_take(game, ev, "force"), "seed check")
	_ok(not game.last_check.is_empty(), "last_check empty")
	ev = _put(game, "stores_turn")
	_ok(_take(game, ev, "pick"), "plain after check")
	var receipt: Dictionary = _event_rows(game)[-1].receipt
	_ok(not receipt.has("result"), "stale last_check decorated a plain choice")
	var week := game.week
	ev = _put(game, "stores_turn")
	_ok(_take(game, ev, "salt"), "repeat")
	var rows := _event_rows(game)
	_ok(str(rows[-1].event_id) == str(rows[-2].event_id) and int(rows[-1].week) == week and int(rows[-2].week) == week, "same week")
	_ok(int(rows[-1].receipt.instance) != int(rows[-2].receipt.instance), "instances collided")
	print("Stale check and repeat: ok")


func _rejected() -> void:
	var game := _game()
	var ev := _put(game, "stores_turn")
	var seq := game.receipt_seq
	var n := game.journal.size()
	var streams := _rng(game)
	_ok(not _take(game, ev, "missing"), "missing choice accepted")
	_choice(ev, "feast").locked = true
	_ok(not _take(game, ev, "feast"), "locked accepted")
	_choice(ev, "feast").locked = false
	game.stock.tokens = 0
	_ok(not _take(game, ev, "salt"), "unpaid accepted")
	_ok(game.receipt_seq == seq and game.journal.size() == n and _rng(game) == streams, "rejected mutated")
	_ok(_event_rows(game).is_empty(), "rejected journaled")
	print("Rejected: no receipt")


func _excluded() -> void:
	var game := _game()
	var seq := game.receipt_seq
	var streams := _rng(game)
	game.pending = [{
		"id": "promise_offer", "cm": "promise",
		"title": {"en": "A promise", "ru": "Обещание"},
		"choices": [{"id": "decline", "label": {"en": "Not now", "ru": "Не сейчас"}}],
	}]
	_ok(_take(game, game.pending[0], "decline"), "cm")
	_ok(game.receipt_seq == seq and not _event_rows(game)[-1].has("receipt"), "cm receipt")
	seq = game.receipt_seq
	var night := {
		"id": "night_run_w3", "night_run": true,
		"title": {"en": "Night", "ru": "Ночь"},
		"pack": {},
		"choices": [{"id": "leave", "label": {"en": "Leave it", "ru": "Оставить"}}],
	}
	game.pending = [night]
	var food := int(game.stock.food)
	_ok(_take(game, night, "leave"), "night")
	_ok(game.receipt_seq == seq and not _event_rows(game)[-1].has("receipt"), "night receipt")
	_ok(int(game.stock.food) == food and _rng(game) == streams, "night sim drift")
	seq = game.receipt_seq
	var person: Dictionary = game.residents[0]
	game.burials = [{"id": str(person.id), "name": str(person.name), "cause": "sickness"}]
	var burial := {
		"id": "burial_%s" % str(person.id),
		"burial_id": str(person.id),
		"title": {"en": str(person.name), "ru": str(person.get("name_ru", person.name))},
		"choices": [{"id": "bury", "label": {"en": "Bury", "ru": "Похоронить"}, "hope": 1}],
	}
	game.pending = [burial]
	var hope := game.hope
	_ok(_take(game, burial, "bury"), "burial")
	_ok(game.receipt_seq == seq and not _event_rows(game)[-1].has("receipt"), "burial receipt")
	_ok(game.hope == hope + 1, "burial hope changed by the receipt")
	seq = game.receipt_seq
	game.audience = {"faction": "exchange", "week": game.week}
	_ok(game.apply({"kind": "audience", "accept": false}), "audience")
	_ok(game.receipt_seq == seq, "audience seq")
	for row in game.journal:
		if str(row.get("kind", "")) == "audience":
			_ok(not row.has("receipt"), "audience receipt")
	seq = game.receipt_seq
	_ok(not game.apply({"kind": "law", "law": "no_such_law"}), "bad law accepted")
	game.orders_left = 0
	_ok(not game.apply({"kind": "order", "order": "gift", "faction": "exchange"}), "order with no orders")
	_ok(game.receipt_seq == seq, "law or order seq")
	game.raid_share = {"food": 1, "mats": 0, "good": 0, "faction": "exchange"}
	game.apply_raid_share("stockpile")
	_ok(game.receipt_seq == seq, "raid share seq")
	print("Excluded: no receipts")


func _provenance() -> void:
	var game := _game()
	game.stock.tokens = 30
	var toll := _put(game, "toll")
	_ok(_take(game, toll, "pay"), "toll")
	var parent: Dictionary = _event_rows(game)[-1].receipt
	var follow := {}
	for item in game.follows:
		if str(item.get("id", "")) == "toll_next":
			follow = item
	_ok(not follow.is_empty() and int(follow.get("receipt_from", 0)) == int(parent.instance), "toll provenance %s" % str(follow))
	follow.due = game.week
	game.pending = []
	game.week_event_ids = {}
	game._present_due_follows()
	_ok(not game.pending.is_empty() and str(game.pending[0].get("id", "")) == "toll_next", "presented")
	_ok(int(game.pending[0].get("receipt_from", 0)) == int(parent.instance), "card provenance")
	var child_ev: Dictionary = game.pending[0]
	_ok(_take(game, child_ev, "bar"), "toll next")
	var child: Dictionary = _event_rows(game)[-1]
	_ok(int(child.receipt.get("previous_instance", 0)) == int(parent.instance), "backward id")
	var view := game.receipt_view(child)
	_ok(int(view.previous_instance) == int(parent.instance) and str(view.previous_title).find("chain") >= 0, "link %s" % str(view.previous_title))
	_ok(str(view.previous_button).find(str(int(child.week))) >= 0 or str(view.previous_button).find("Week") >= 0, "link week")
	var saved_child: Dictionary = child.duplicate(true)
	var saved_parent: Dictionary = _event_rows(game)[0].duplicate(true)
	game.journal = [saved_parent, saved_child]
	for i in range(Game.JOURNAL_MAX - 1):
		game._journal("news", {"text": "pad %d" % i})
	_ok(game.receipt_find(int(parent.instance)).is_empty(), "parent kept after prune")
	_ok(not game.receipt_find(int(child.receipt.instance)).is_empty(), "child pruned")
	view = game.receipt_view(game.receipt_find(int(child.receipt.instance)))
	_ok(bool(view.pruned) and str(view.previous_button) == "", "pruned copy")
	game = _game()
	game.event_last["toll_next"] = game.week
	game.stock.tokens = 30
	toll = _put(game, "toll")
	_ok(_take(game, toll, "pay"), "blocked toll")
	_ok(game.follows.is_empty(), "scheduler still enqueued")
	_ok(_event_rows(game)[-1].has("receipt"), "blocked parent lost receipt")
	game = _game()
	var smuggler := _put(game, "smuggler")
	_ok(_take(game, smuggler, "take"), "smuggler")
	for item in game.follows:
		_ok(not item.has("receipt_from"), "non-chain provenance")
	print("Provenance: toll chain")


func _locale_and_load() -> void:
	Copy.set_lang("en")
	var game := _game()
	var ev := _put(game, "stores_turn")
	_ok(Copy.lang == "en", "lang preset")
	_ok(_take(game, ev, "feast"), "locale feast")
	_ok(Copy.lang == "en", "lang flipped")
	var receipt: Dictionary = _event_rows(game)[-1].receipt
	_ok(str(receipt.original_lang) == "en", "original")
	_ok(str(receipt.title.get("en", "")) == "The stores are sweating", "en title")
	_ok(str(receipt.title.get("ru", "")) == "Склад потеет", "ru title")
	_ok(str(receipt.label.get("ru", "")).find("Сварить") >= 0, "ru label")
	Copy.set_lang("ru")
	var view := game.receipt_view(_event_rows(game)[-1])
	_ok(str(view.title) == "Склад потеет", "ru display %s" % str(view.title))
	_ok(str(view.chosen).find("Сварить") >= 0, "ru chosen")
	Copy.set_lang("en")
	var dyn := _put(game, "stores_turn")
	_choice(dyn, "feast").label = "Pay the signed note"
	_ok(_take(game, dyn, "feast"), "dynamic")
	receipt = _event_rows(game)[-1].receipt
	_ok(str(receipt.label.get("en", "")) == "Pay the signed note" and not receipt.label.has("ru"), "dynamic pair %s" % str(receipt.label))
	Copy.set_lang("ru")
	view = game.receipt_view(_event_rows(game)[-1])
	_ok(str(view.chosen).find("Pay the signed note") >= 0 and str(view.chosen).find("Язык оригинала") >= 0, "fallback %s" % str(view.chosen))
	Copy.set_lang("en")
	var mirror := _put(game, "stores_turn")
	MarksKit.boot(game).marks.append("rail_stitch")
	mirror.choices.append({
		"id": "obs_mark_rail_stitch",
		"label": {"en": "Read the stitch aloud", "ru": "Прочесть шов вслух"},
		"obs_line": true, "obs_kind": "mark", "obs_id": "rail_stitch", "mirror": "feast",
		"hope": 1,
	})
	_ok(_take(game, mirror, "obs_mark_rail_stitch"), "mirror")
	receipt = _event_rows(game)[-1].receipt
	_ok(str(receipt.choice_id) == "obs_mark_rail_stitch" and str(receipt.get("mirror", "")) == "feast", "mirror id")
	_ok(str(receipt.label.get("en", "")) == "Read the stitch aloud", "mirror label")
	_ok(str(game.receipt_view(_event_rows(game)[-1]).chosen).find("Cook all") < 0, "reworded mirror")
	var renamed := str(game._event_by_id("stores_turn").title.en)
	game._event_by_id("stores_turn").title.en = "Renamed later"
	view = game.receipt_view(_event_rows(game)[0])
	_ok(str(view.title) == "The stores are sweating", "catalog rename replaced snapshot")
	game._event_by_id("stores_turn").title.en = renamed
	var blank: Dictionary = (_event_rows(game)[0] as Dictionary).duplicate(true)
	blank.receipt.title = {}
	blank.receipt.label = {}
	view = game.receipt_view(blank)
	_ok(str(view.title) == "Recorded event" and str(view.chosen).find("Recorded choice") >= 0, "missing both")
	var hand: Dictionary = (_event_rows(game)[0] as Dictionary).duplicate(true)
	hand.receipt.result = {"kind": "check", "tag": "unrecorded"}
	_ok(str(game.receipt_view(hand).result) == "Result not recorded.", "unrecorded")
	hand.receipt.result = {"kind": "check", "tag": "other", "key": "not.a.real.key"}
	var other := str(game.receipt_view(hand).result)
	_ok(other == "Result not recorded." and other.find("not.a.real.key") < 0, "raw other key")
	var blob := game.export_state()
	blob["schema"] = Game.SAVE_SCHEMA
	var again := _game(11)
	_ok(again.import_state(blob), "roundtrip " + again.load_error)
	_ok(again.receipt_seq == game.receipt_seq, "seq roundtrip")
	_ok(again.journal.size() == game.journal.size(), "journal duplicated on load")
	var loaded: Dictionary = {}
	for row in again.journal:
		if str(row.get("kind", "")) == "event" and str(row.get("choice_id", "")) == "feast" and str(row.receipt.label.get("en", "")) == "Pay the signed note":
			loaded = row.receipt
	_ok(str(loaded.get("label", {}).get("en", "")) == "Pay the signed note", "snapshot load")
	game.setup(catalog, 4, 40)
	_ok(game.receipt_seq == 0 and game.follows.is_empty(), "new run")
	Copy.set_lang("en")
	print("Locale and load: ok")


func _nested_and_ending() -> void:
	var game := _game()
	var ev := {
		"id": "fixture_end",
		"title": {"en": "The door", "ru": "Дверь"},
		"choices": [{
			"id": "open",
			"label": {"en": "Open it", "ru": "Открыть"},
			"hope": 1,
			"proof": 1,
			"standing": {"exchange": 2},
			"ending": "open_door",
		}],
	}
	game.pending = [ev]
	_ok(_take(game, ev, "open"), "ending")
	var saw_event := 0
	var saw_receipt_elsewhere := 0
	for row in game.journal:
		var kind := str(row.get("kind", ""))
		if kind == "event" and str(row.get("choice_id", "")) == "open":
			saw_event += 1
			_ok(row.has("receipt") and int(row.receipt.deltas.hope) == 1, "ending receipt")
		elif row.has("receipt"):
			saw_receipt_elsewhere += 1
	_ok(saw_event == 1 and saw_receipt_elsewhere == 0, "receipt on nested row events=%d else=%d" % [saw_event, saw_receipt_elsewhere])
	_ok(game.over == "open_door", "ending over")
	print("Nested journal and ending: ok")


func _careful() -> void:
	var lost := 0
	var matched := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = false
		game.raid_share_profile = "careful"
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while str(game.over) == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		var got := _outcome_hash(game)
		if got == int(MASTER_HASH[run_seed - 1]) and _rng(game) == str(MASTER_RNG[run_seed - 1]):
			matched += 1
		else:
			_bad("seed %d hash %d rng %s" % [run_seed, got, _rng(game)])
		if str(game.over) != "time":
			lost += 1
		for row in game.journal:
			if not (row is Dictionary):
				continue
			var kind := str(row.get("kind", ""))
			if kind != "event":
				if row.has("receipt"):
					_bad("receipt on %s" % kind)
				continue
			var id := str(row.get("event_id", ""))
			var excluded := id.begins_with("night_run") or id.begins_with("burial_") or id == "promise_offer" or id == "mandate_pick"
			if excluded and row.has("receipt"):
				_bad("excluded receipt " + id)
			elif not excluded and not row.has("receipt"):
				_bad("ordinary event without receipt " + id)
			elif row.has("receipt") and Game._receipt_clean(row.receipt).is_empty():
				_bad("unclean receipt " + id)
	_ok(matched == 60, "careful match %d/60" % matched)
	_ok(lost == 20, "careful lost %d" % lost)
	print("Careful 1-60: %d match, lost %d" % [matched, lost])


func _outcome_hash(game: Game) -> int:
	var ids: Array = game.stations.keys()
	ids.sort()
	var held := PackedStringArray()
	for sid in ids:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != str(game.player):
			continue
		held.append("%s:%s:%s" % [str(sid), str(st.get("held_weeks", 0)), str(st.get("focus", ""))])
	var line := "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s" % [
		str(game.over), int(game.hope), int(game.discontent),
		int(game.stock.food), int(game.stock.materials), int(game.stock.air),
		int(game.stock.power), int(game.stock.tokens), int(game.stock.influence),
		game.residents.size(), ",".join(held)]
	var h := 5381
	for i in line.length():
		h = ((h << 5) + h) + line.unicode_at(i)
		h = h & 0x7fffffff
	return h


func _place(game: Game, type: String) -> bool:
	for key in game.cells:
		var spot: Dictionary = game.cells[key]
		if game._cell_buildable(spot):
			game._place_room(type, int(spot.level), int(spot.cell))
			return true
	return false


func _ui() -> void:
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	if st.game == null:
		_bad("station had no game")
		return
	st._close_card()
	Copy.set_lang("en")
	st.game.pending.clear()
	st.game.week_event_ids = {}
	var ev: Dictionary = st.game._copy(st.game._event_by_id("loan_next"))
	st.game.stock.tokens = 40
	st.game.opinions.exchange = 99
	st.game.pending = [ev]
	var before: Dictionary = st.game.export_state()
	_ok(st.game.apply({"kind": "event", "event_id": "loan_next", "choice_id": "repay"}), "ui repay")
	var seq: int = int(st.game.receipt_seq)
	var journals: int = st.game.journal.size()
	st.journal_filter = "decisions"
	st._show_journal()
	await process_frame
	_ok(st.game.receipt_seq == seq and st.game.journal.size() == journals, "ui minted a second receipt")
	_ok(st.game.export_state().receipt_seq == seq, "ui rewrote seq")
	var details := _find_button(st.card_body, "Details")
	_ok(details != null, "details button missing")
	if details != null:
		_ok(details.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART or details.autowrap_mode == TextServer.AUTOWRAP_OFF, "details focus")
		_ok(details.focus_mode == Control.FOCUS_ALL, "details not focusable")
	var raw := _texts(st.card_body)
	_ok(raw.find("receipt.") < 0, "raw key on list")
	if details != null:
		st.card_click_guard = 0
		details.pressed.emit()
		await process_frame
	_ok(st.journal_detail > 0, "detail did not open")
	var body := _texts(st.card_body)
	_ok(body.find("Faction opinion") >= 0 and body.find("Tracked immediate changes") >= 0, "detail copy %s" % body)
	_ok(body.find("health") >= 0 and body.find("receipt.") < 0, "detail scope or raw key")
	var back := _find_button(st.card_body, "Back")
	_ok(back != null and back.focus_mode == Control.FOCUS_ALL, "back missing")
	if back != null:
		st.card_click_guard = 0
		back.pressed.emit()
		await process_frame
	_ok(st.journal_detail == 0 and st.journal_filter == "decisions", "back lost filter")
	_ok(st.game.receipt_seq == seq and st.game.journal.size() == journals, "back mutated sim")
	if not _renderer_live():
		_shots_skipped = true
		for lang in ["en", "ru"]:
			for scale in ["100", "125"]:
				for phase in ["before", "after"]:
					print("RECEIPT SHOT SKIP %s %s %s no renderer" % [lang, scale, phase])
	else:
		await _shoot_pair(st, "en", "100")
		await _shoot_pair(st, "en", "125")
		await _shoot_pair(st, "ru", "100")
		await _shoot_pair(st, "ru", "125")
	_ok(int(before.get("receipt_seq", 0)) == 0, "ui game was not a fresh capture base")
	if is_instance_valid(st):
		st.free()
	print("UI: list and detail")


func _shoot_pair(st, lang: String, scale: String) -> void:
	Copy.set_lang(lang)
	st.journal_detail = 0
	st.journal_back = []
	st._show_journal()
	await process_frame
	await _shoot(st, lang, scale, false)
	var word := "Details" if lang == "en" else "Подробнее"
	var details := _find_button(st.card_body, word)
	if details == null:
		_bad("no details for " + lang)
		return
	st.card_click_guard = 0
	details.pressed.emit()
	await process_frame
	var body := _texts(st.card_body)
	_ok(body.find("receipt.") < 0, "raw key " + lang)
	if lang == "ru":
		_ok(body.find("Мнение фракции") >= 0, "ru opinion line")
		for lab in _labels(st.card_body):
			if lab.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART and str(lab.text).length() > 24:
				_bad("ru label does not wrap: " + str(lab.text))
				break
	await _shoot(st, lang, scale, true)


func _shoot(st, lang: String, scale: String, opened: bool) -> void:
	if not _renderer_live():
		_shots_skipped = true
		print("RECEIPT SHOT SKIP %s %s %s no renderer" % [lang, scale, "after" if opened else "before"])
		return
	var win := Vector2i(1920, 1080) if scale == "100" else Vector2i(1536, 864)
	var window: Window = st.get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = win
	root.size = win
	for _i in 2:
		await process_frame
	if st.has_method("_layout"):
		st._layout()
	await process_frame
	RenderingServer.force_draw()
	var tex: ViewportTexture = st.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	var name := "receipt_%s_%s_%s" % [lang, scale, "after" if opened else "before"]
	if img == null or img.get_width() < 2:
		_bad("no image " + name)
		return
	var dir := _shot_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(dir.path_join(name + ".png"))
	if err != OK:
		_bad("shot %s %s" % [name, str(err)])
		return
	_shots_saved += 1
	print("RECEIPT SHOT %s" % dir.path_join(name + ".png"))


func _renderer_live() -> bool:
	return not OS.has_feature("headless") and DisplayServer.get_name() != "headless"


func _shot_dir() -> String:
	var dir := OS.get_environment("UNDERLINE_SHOTS_DIR")
	if dir == "":
		dir = "/opt/cursor/artifacts/receipts"
	if dir.begins_with("user://") or dir.begins_with("res://"):
		dir = ProjectSettings.globalize_path(dir)
	return dir


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Button and str((here as Button).text) == text:
			return here
		for child in here.get_children():
			stack.append(child)
	return null


func _texts(node: Node) -> String:
	var bits: PackedStringArray = []
	if node == null:
		return ""
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Label:
			bits.append(str((here as Label).text))
		elif here is Button:
			bits.append(str((here as Button).text))
		for child in here.get_children():
			stack.append(child)
	return "\n".join(bits)


func _labels(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Label:
			out.append(here)
		for child in here.get_children():
			stack.append(child)
	return out
