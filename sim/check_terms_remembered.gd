extends SceneTree

## P98 Terms Remembered. Overlay on follow_memory. Schema stays 25.
##   godot --headless --path . -s res://sim/check_terms_remembered.gd
## Headless prints TERMS SHOTS SKIP. A real renderer also writes the before/after cards.

const SCRATCH := "user://check_terms_remembered"
const RECORDS := "user://check_terms_records.cfg"
const SHOTS := "/opt/cursor/artifacts"
## Careful seeds 1-60 on master 0a43a462, full export_state. Lost 20/60.
const BASELINE_LOST := 20
const LOST_SEEDS := "1,8,11,12,13,14,23,27,28,30,33,35,39,40,41,45,51,52,56,57"
const MASTER_HASH := [
	1396264772, 1347371159, 220654524, 732840667, 1442243520, 1441876690, 1649746673, 473079119, 1061355793, 1619188803,
	1208547276, 1952560883, 1486275541, 1031602631, 400793929, 1076883704, 1865514417, 234030490, 1453131875, 894632713,
	159696039, 1948917637, 482903206, 399079687, 2083804332, 574433947, 1916329205, 606813208, 2011576170, 785000255,
	1431870509, 1254408340, 1666499131, 2127869649, 524144797, 715363415, 970149526, 1040207160, 1005128800, 758714067,
	2124060934, 1594905657, 1450139760, 1033131903, 1256784552, 1881540794, 253930989, 1851066156, 559077435, 1928794609,
	1898962004, 976391835, 1886852305, 717810835, 1048165102, 1492834888, 803203699, 1394320756, 463245485, 1426999646,
]
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

var _failed := false
var catalog: Catalog
var _balance := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	TermsRemembered.enabled = true
	TermsRemembered.clear_rows_for_test()
	catalog = Catalog.new()
	if not catalog.load_all():
		_bad("catalog")
		_finish()
		return
	_balance = FileAccess.get_file_as_string("res://data/balance.json")
	if Game.SAVE_SCHEMA != 25:
		_bad("schema %d" % Game.SAVE_SCHEMA)
	if not _check_pack():
		_failed = true
	if not _check_matrix():
		_failed = true
	if not _check_legacy():
		_failed = true
	if not _check_partial():
		_failed = true
	if not _check_locale():
		_failed = true
	if not _check_clamps():
		_failed = true
	if not _check_devout():
		_failed = true
	if not _check_mirrors():
		_failed = true
	if not _check_equivalence():
		_failed = true
	if not _check_save():
		_failed = true
	if not await _check_card():
		_failed = true
	if FileAccess.get_file_as_string("res://data/balance.json") != _balance:
		_bad("balance.json changed")
	Copy.set_lang("en")
	TermsRemembered.enabled = true
	TermsRemembered.clear_rows_for_test()
	if _failed:
		print("TERMS FAIL")
		quit(1)
		return
	if not _careful():
		print("TERMS FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != _balance:
		print("TERMS FAIL balance")
		quit(1)
		return
	print("TERMS OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("Terms: FAIL " + msg)


func _check_pack() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/terms_remembered.json"))
	if not (pack is Dictionary):
		_bad("pack")
		return false
	if str(pack.get("_roadmap", "")) != "P98" or str(pack.get("_status", "")) != "INTERIM":
		_bad("pack status")
		return false
	if str(pack.get("_approval", "")) != "NONE" or str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack approval")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	var keys := TermsRemembered.all_keys()
	if keys.size() != 48 or rows.size() != 48:
		_bad("key count %d/%d" % [keys.size(), rows.size()])
		return false
	for key in keys:
		var row = rows.get(key, null)
		if not (row is Dictionary) or str(row.get("en", "")).strip_edges() == "":
			_bad("missing en " + key)
			return false
		if str(row.get("ru", "")).strip_edges() != "":
			_bad("unexpected ru " + key)
			return false
		if str(row.en) == key or str(row.en).begins_with("terms."):
			_bad("raw key " + key)
			return false
	print("Pack: ok 48 interim en, ru omitted")
	return true


func _check_matrix() -> bool:
	var game := _fresh()
	_fund(game)
	var seen := 0
	for event_id in ["loan_next", "toll_next", "knock_next"]:
		for memory in TermsRemembered.CARDS[event_id]:
			var ev := _inject(game, event_id, str(memory))
			var sig := _sig(ev)
			var ids: PackedStringArray = []
			for choice in ev.choices:
				if bool(choice.get("obs_line", false)):
					_bad("unexpected mirror")
					return false
				ids.append(str(choice.get("id", "")))
				var label := TermsRemembered.visible_label(game, ev, choice)
				var again := TermsRemembered.visible_label(game, ev, choice)
				var want := TermsRemembered._cell(TermsRemembered.key_for(event_id, str(memory), str(choice.id), "label"), "en")
				if label != want or again != label or label == "" or label.begins_with("terms."):
					_bad("label %s %s %s" % [event_id, memory, choice.id])
					return false
				if str(choice.get("label", "")) == label:
					_bad("wrote label into choice %s" % choice.id)
					return false
				var response := TermsRemembered.response_for(ev, choice)
				var result := TermsRemembered._cell(TermsRemembered.key_for(event_id, str(memory), str(choice.id), "result"), "en")
				if response != result or response == "":
					_bad("result %s %s" % [event_id, choice.id])
					return false
				seen += 1
			if _sig(ev) != sig:
				_bad("choice mutated " + event_id)
				return false
			var want_ids: Array = TermsRemembered.CHOICES[event_id]
			if ids.size() != want_ids.size():
				_bad("count %s" % event_id)
				return false
			for i in want_ids.size():
				if ids[i] != str(want_ids[i]):
					_bad("order %s" % event_id)
					return false
	if seen != 24:
		_bad("paths %d" % seen)
		return false
	print("Matrix: ok 24")
	return true


func _check_legacy() -> bool:
	var game := _fresh()
	_fund(game)
	for memory in ["", "unknown", "pay", "sign"]:
		var ev := _inject(game, "loan_next", "decline")
		if memory == "":
			ev.erase("follow_memory")
		else:
			ev.follow_memory = memory
		for choice in ev.choices:
			var label := TermsRemembered.visible_label(game, ev, choice)
			if label != game.line_of(choice, "label") or TermsRemembered.response_for(ev, choice) != "":
				_bad("legacy %s %s" % [memory, choice.id])
				return false
	var bare := _inject(game, "toll", "pay")
	bare.erase("follow_memory")
	for choice in bare.choices:
		if TermsRemembered.visible_label(game, bare, choice) != game.line_of(choice, "label"):
			_bad("parent card overlay")
			return false
	print("Legacy: ok")
	return true


func _check_partial() -> bool:
	var rows: Dictionary = TermsRemembered.load_rows().duplicate(true)
	rows.erase("terms.loan_next.decline.default.label")
	TermsRemembered.set_rows_for_test(rows)
	var game := _fresh()
	var ev := _inject(game, "loan_next", "decline")
	var gaps := TermsRemembered.missing("loan_next", "decline")
	if gaps.is_empty() or TermsRemembered.context_ready("loan_next", "decline"):
		_bad("partial still ready")
		TermsRemembered.clear_rows_for_test()
		return false
	for choice in ev.choices:
		if TermsRemembered.visible_label(game, ev, choice) != game.line_of(choice, "label"):
			_bad("partial mixed " + str(choice.id))
			TermsRemembered.clear_rows_for_test()
			return false
		if TermsRemembered.response_for(ev, choice) != "":
			_bad("partial response")
			TermsRemembered.clear_rows_for_test()
			return false
	TermsRemembered.clear_rows_for_test()
	print("Partial: ok")
	return true


func _check_locale() -> bool:
	var game := _fresh()
	_fund(game)
	var ev := _inject(game, "loan_next", "decline")
	var sig := _sig(ev)
	Copy.set_lang("ru")
	if TermsRemembered.context_ready("loan_next", "decline"):
		_bad("ru context ready without strings")
		Copy.set_lang("en")
		return false
	for choice in ev.choices:
		var label := TermsRemembered.visible_label(game, ev, choice)
		if label != game.line_of(choice, "label"):
			_bad("ru label " + str(choice.id))
			Copy.set_lang("en")
			return false
		if TermsRemembered.response_for(ev, choice) != "":
			_bad("ru response")
			Copy.set_lang("en")
			return false
		var translated := Copy.t(label)
		if translated.begins_with("terms.") or translated == "":
			_bad("ru raw")
			Copy.set_lang("en")
			return false
	if _sig(ev) != sig:
		_bad("locale mutated card")
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	var repay := _choice(ev, "repay")
	if TermsRemembered.visible_label(game, ev, repay) != "Pay the demanded goodwill":
		_bad("en did not return")
		return false
	print("Locale: ok")
	return true


func _check_clamps() -> bool:
	if not _clamp_pair("loan_next", "decline", "repay", "exchange", 98, 4, 100):
		return false
	if not _clamp_pair("loan_next", "decline", "default", "exchange", -96, -8, -100):
		return false
	if not _clamp_pair("toll_next", "detour", "sign", "directorate", 97, 4, 100):
		return false
	if not _clamp_pair("toll_next", "pay", "bar", "directorate", -93, -8, -100):
		return false
	var game := _fresh()
	_fund(game)
	game.discontent = 100
	game.hope = 0
	var ev := _inject(game, "loan_next", "borrow")
	var touched := _clone(game)
	_read_card(touched)
	var quiet := _clone(game)
	if not touched.apply({"kind": "event", "event_id": "loan_next", "choice_id": "default"}):
		_bad("clamp default apply")
		return false
	if not quiet.apply({"kind": "event", "event_id": "loan_next", "choice_id": "default"}):
		_bad("clamp default twin")
		return false
	if int(touched.discontent) != 100 or _blob(touched) != _blob(quiet) or _rng(touched) != _rng(quiet):
		_bad("discontent clamp")
		return false
	var low := _fresh()
	_fund(low)
	low.stock.tokens = 0
	low.stock.materials = 0
	low.stock.food = 0
	var poor := _inject(low, "loan_next", "decline")
	var repay := _choice(poor, "repay")
	var stall := _choice(poor, "stall")
	var dry := _choice(poor, "default")
	if low.afford_choice(repay) or low.afford_choice(stall) or not low.afford_choice(dry):
		_bad("afford")
		return false
	var before := _blob(low)
	var rng := _rng(low)
	if low.apply({"kind": "event", "event_id": "loan_next", "choice_id": "repay"}):
		_bad("unpaid apply")
		return false
	if _blob(low) != before or _rng(low) != rng:
		_bad("failed apply moved state")
		return false
	if TermsRemembered.visible_label(low, poor, repay) != "Pay the demanded goodwill":
		_bad("unpaid label")
		return false
	print("Clamps: ok")
	return true


func _clamp_pair(event_id: String, memory: String, choice_id: String, faction: String, start: int, _delta: int, expect: int) -> bool:
	var game := _fresh()
	_fund(game)
	game.opinions[faction] = start
	var ev := _inject(game, event_id, memory)
	var touched := _clone(game)
	_read_card(touched)
	var quiet := _clone(game)
	var action := {"kind": "event", "event_id": event_id, "choice_id": choice_id}
	if not touched.apply(action) or not quiet.apply(action):
		_bad("clamp apply %s" % choice_id)
		return false
	if int(touched.opinions[faction]) != expect or _blob(touched) != _blob(quiet) or _rng(touched) != _rng(quiet):
		_bad("clamp %s %s got %s" % [faction, choice_id, str(touched.opinions[faction])])
		return false
	return true


func _check_devout() -> bool:
	var with_trait := _fresh()
	_fund(with_trait)
	_set_devout(with_trait, true)
	var ev := _inject(with_trait, "knock_next", "cut")
	var chapel := _choice(ev, "chapel")
	var feed := _choice(ev, "feed")
	if int(with_trait.choice_effects(chapel).hope) != 1:
		_bad("devout hope")
		return false
	var label := TermsRemembered.visible_label(with_trait, ev, chapel)
	_set_devout(with_trait, false)
	var bare := _inject(with_trait, "knock_next", "cut")
	if int(with_trait.choice_effects(_choice(bare, "chapel")).hope) != 0:
		_bad("no devout hope")
		return false
	if TermsRemembered.visible_label(with_trait, bare, _choice(bare, "chapel")) != label:
		_bad("devout changed label")
		return false
	if TermsRemembered.visible_label(with_trait, bare, _choice(bare, "feed")) != TermsRemembered.visible_label(with_trait, ev, feed):
		_bad("feed label")
		return false
	_set_devout(with_trait, true)
	var on := _inject(with_trait, "knock_next", "answer")
	var left := _clone(with_trait)
	_read_card(left)
	var right := _clone(with_trait)
	var action := {"kind": "event", "event_id": "knock_next", "choice_id": "chapel"}
	if not left.apply(action) or not right.apply(action):
		_bad("chapel apply")
		return false
	if _blob(left) != _blob(right) or _rng(left) != _rng(right):
		_bad("devout diverged")
		return false
	print("Devout: ok")
	return true


func _check_mirrors() -> bool:
	var cases := [
		["loan_next", "decline", "word_knot", "default"],
		["toll_next", "goods", "raid_tally", "route"],
		["knock_next", "fill", "raid_tally", "chapel"],
	]
	for row in cases:
		if not _mirror(str(row[0]), str(row[1]), str(row[2]), str(row[3])):
			return false
	print("Mirrors: ok")
	return true


func _mirror(event_id: String, memory: String, mark: String, canonical_id: String) -> bool:
	var game := _fresh()
	_fund(game)
	var row: Dictionary = MarksKit.boot(game)
	row.marks = [mark]
	var ev := _inject(game, event_id, memory)
	MarksKit.decorate(game, ev)
	var obs: Dictionary = {}
	var base: Dictionary = {}
	var ids: PackedStringArray = []
	for choice in ev.choices:
		ids.append(str(choice.get("id", "")))
		if bool(choice.get("obs_line", false)):
			obs = choice
		elif str(choice.get("id", "")) == canonical_id:
			base = choice
	if obs.is_empty() or base.is_empty():
		_bad("mirror missing %s" % event_id)
		return false
	if str(obs.get("mirror", "")) != canonical_id:
		_bad("mirror target %s -> %s" % [event_id, str(obs.get("mirror", ""))])
		return false
	var authored := game.line_of(obs, "label")
	if TermsRemembered.visible_label(game, ev, obs) != authored:
		_bad("mirror label replaced " + event_id)
		return false
	if TermsRemembered.response_for(ev, obs) != TermsRemembered.response_for(ev, base):
		_bad("mirror response " + event_id)
		return false
	if TermsRemembered.response_for(ev, obs) == "":
		_bad("mirror silent " + event_id)
		return false
	if not MarksKit.effect_same(obs, base):
		_bad("mirror effects " + event_id)
		return false
	var want: Array = TermsRemembered.CHOICES[event_id]
	for i in want.size():
		if ids[i] != str(want[i]):
			_bad("mirror reorder " + event_id)
			return false
	var left := _clone(game)
	_read_card(left)
	var right := _clone(game)
	var action := {"kind": "event", "event_id": event_id, "choice_id": str(obs.get("id", ""))}
	if not left.apply(action) or not right.apply(action):
		_bad("mirror apply " + event_id)
		return false
	if _blob(left) != _blob(right) or _rng(left) != _rng(right):
		_bad("mirror diverged " + event_id)
		return false
	return true


func _check_equivalence() -> bool:
	var game := _fresh()
	_fund(game)
	for event_id in ["loan_next", "toll_next", "knock_next"]:
		for memory in TermsRemembered.CARDS[event_id]:
			for choice_id in TermsRemembered.CHOICES[event_id]:
				var host := _clone(game)
				_inject(host, event_id, str(memory))
				var left := _clone(host)
				var before := _rng(left)
				_read_card(left)
				if _rng(left) != before:
					_bad("presentation rng " + event_id)
					return false
				var right := _clone(host)
				var action := {"kind": "event", "event_id": event_id, "choice_id": str(choice_id)}
				if not left.apply(action) or not right.apply(action):
					_bad("apply %s %s %s" % [event_id, memory, choice_id])
					return false
				if _blob(left) != _blob(right) or _rng(left) != _rng(right):
					_bad("diverged %s %s %s" % [event_id, memory, choice_id])
					return false
				if str(left.front_event().get("id", "")) == event_id:
					_bad("event stayed " + event_id)
					return false
	print("Equivalence: ok 24")
	return true


func _check_save() -> bool:
	if Game.SAVE_SCHEMA != 25:
		_bad("schema")
		return false
	var game := _fresh()
	_fund(game)
	_inject(game, "toll_next", "detour")
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	if data.has("terms") or data.has("terms_remembered"):
		_bad("new persist key")
		return false
	var fresh := _fresh()
	var fresh_keys: Array = fresh.export_state().keys()
	fresh_keys.sort()
	var got_keys: Array = data.keys()
	got_keys.erase("schema")
	got_keys.sort()
	if fresh_keys != got_keys:
		_bad("persist keys changed")
		return false
	var loaded := Game.new()
	loaded.catalog = catalog
	if not loaded.import_state(data):
		_bad("load %s" % loaded.load_error)
		return false
	if str(loaded.front_event().get("follow_memory", "")) != "detour":
		_bad("memory dropped")
		return false
	Copy.set_lang("en")
	var sign := _choice(loaded.front_event(), "sign")
	if TermsRemembered.visible_label(loaded, loaded.front_event(), sign) != "Sign now that he knows the detour":
		_bad("label after load")
		return false
	var left := _clone(loaded)
	_read_card(left)
	var right := _clone(loaded)
	var action := {"kind": "event", "event_id": "toll_next", "choice_id": "bar"}
	if not left.apply(action) or not right.apply(action) or _blob(left) != _blob(right) or _rng(left) != _rng(right):
		_bad("load apply")
		return false
	var legacy := loaded.front_event().duplicate(true)
	legacy.erase("follow_memory")
	var hold := _fresh()
	hold.pending = [legacy]
	for choice in legacy.choices:
		if TermsRemembered.visible_label(hold, legacy, choice) != hold.line_of(choice, "label"):
			_bad("legacy pending")
			return false
	print("Save: ok schema 25")
	return true


func _check_card() -> bool:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	Settings.language = "en"
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	var renderer := _renderer_live()
	if not renderer:
		print("TERMS SHOTS SKIP no renderer")
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	st.shot_mode = true
	st.at_menu = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	await _view(st, Vector2i(1920, 1080), 1.0)
	if not await _card_case(st, "en", "100", renderer):
		st.free()
		return false
	await _view(st, Vector2i(1536, 864), 1.0)
	if not await _card_case(st, "en", "125", renderer):
		st.free()
		return false
	Copy.set_lang("ru")
	st._load_fonts()
	if st.theme != null:
		st.theme.default_font = st.body_font
	await _view(st, Vector2i(1920, 1080), 1.0)
	if not await _card_case(st, "ru", "100", renderer):
		st.free()
		return false
	Copy.set_lang("en")
	st.free()
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	print("Card: ok")
	return true


func _card_case(st, lang: String, tag: String, renderer: bool) -> bool:
	Copy.set_lang(lang)
	_fund(st.game)
	TermsRemembered.enabled = false
	if not _show_loan(st, "decline"):
		_bad("show before")
		return false
	for _i in 4:
		await process_frame
	if not _buttons_are(st, _original_buttons(lang)):
		_bad("before buttons " + tag + " " + lang)
		return false
	if renderer:
		await _shot(st, "p98_before_loan_decline_%s_%s.png" % [lang, tag])
	TermsRemembered.enabled = true
	if not _show_loan(st, "decline"):
		_bad("show after")
		return false
	for _i in 4:
		await process_frame
	var want: PackedStringArray = _original_buttons(lang) if lang == "ru" else _overlay_buttons()
	if not _buttons_are(st, want):
		_bad("after buttons " + tag + " " + lang)
		return false
	if not _has_cost(st, lang):
		_bad("cost line " + lang)
		return false
	if renderer:
		await _shot(st, "p98_after_loan_decline_%s_%s.png" % [lang, tag])
	if lang == "en" and tag == "100":
		st.game.stock.tokens = 0
		st.game.stock.materials = 0
		if not _show_loan(st, "decline"):
			_bad("poor card")
			return false
		for _i in 3:
			await process_frame
		var repay := _button_text(st, "Pay the demanded goodwill")
		if repay == null or not repay.disabled:
			_bad("repay still paid")
			return false
		st._pick_event("loan_next", "repay")
		for _i in 2:
			await process_frame
		if st.footer.text != Copy.t("That choice did not take."):
			_bad("failed click showed a response")
			return false
		if _terms_plate(st) != null and _terms_plate(st).visible:
			_bad("failed click showed a plate")
			return false
		st.game.stock.tokens = 40
		st.game.stock.materials = 20
		if not _show_loan(st, "decline"):
			_bad("response card")
			return false
		for _i in 2:
			await process_frame
		st.footer.text = ""
		st.footer.visible = false
		st._pick_event("loan_next", "default")
		for _i in 3:
			await process_frame
		if not _plate_shows(st, "You repeat the refusal. You do not pretend a note was signed."):
			_bad("plate missing refusal")
			return false
		if st.footer.text != "":
			_bad("footer still holds the sentence")
			return false
		if str(st.game.front_event().get("id", "")) == "loan_next":
			_bad("card stayed")
			return false
		var widest := _widest_result(st)
		st._show_terms_line(widest)
		if not await _layout_views(st, widest, renderer):
			return false
		st._hide_terms_plate()
	if lang == "ru" and tag == "100":
		if not _show_loan(st, "decline"):
			_bad("ru response card")
			return false
		for _i in 2:
			await process_frame
		st.footer.text = ""
		st.footer.visible = false
		st._pick_event("loan_next", "default")
		for _i in 3:
			await process_frame
		if st.footer.text != "":
			_bad("ru footer sentence")
			return false
		if _terms_plate(st) != null and _terms_plate(st).visible:
			_bad("ru plate without strings")
			return false
		if renderer:
			await _shot(st, "p98_after_response_ru_100.png")
	TermsRemembered.enabled = true
	return true


func _original_buttons(lang: String) -> PackedStringArray:
	var keys := ["Pay Lin in full", "Pay in cable and ask for time", "Tell him the yard is dry"]
	var out := PackedStringArray()
	for key in keys:
		out.append(Copy.t(key) if lang == "ru" else key)
	return out


func _overlay_buttons() -> PackedStringArray:
	return PackedStringArray([
		"Pay the demanded goodwill",
		"Offer cable instead of goodwill tokens",
		"Stand by the refusal",
	])


func _buttons_are(st, want: PackedStringArray) -> bool:
	var got: PackedStringArray = []
	for button in st.card_body.find_children("*", "Button", true, false):
		if not button.visible or not bool(button.get_meta("event_choice", false)):
			continue
		got.append(str(button.text))
	if got.size() < want.size():
		print("Terms: buttons %s" % ",".join(got))
		return false
	for i in want.size():
		if got[i] != want[i]:
			print("Terms: button %d got %s want %s" % [i, got[i], want[i]])
			return false
	for text in got:
		if str(text).begins_with("terms."):
			return false
	return true


func _has_cost(st, lang: String) -> bool:
	var token := "Жетоны" if lang == "ru" else "Tokens"
	for lab in st.card_body.find_children("*", "Label", true, false):
		if str(lab.text).contains(token):
			return true
	return false


func _button_text(st, text: String) -> Button:
	for button in st.card_body.find_children("*", "Button", true, false):
		if str(button.text) == text:
			return button
	return null


func _show_loan(st, memory: String) -> bool:
	var game = st.game
	game.pending.clear()
	game.week_event_ids = {}
	game.week = 12
	if st.dim != null and st.dim.visible:
		st._close_card()
	var src: Dictionary = game._event_by_id("loan_next")
	var copy: Dictionary = src.duplicate(true)
	copy.text = str(src.by[memory])
	copy.follow_memory = memory
	if not game._present_event(copy):
		return false
	st.event_mode = "one"
	st.at_menu = false
	st._show_dawn()
	return str(game.front_event().get("id", "")) == "loan_next"


func _view(st, win_size: Vector2i, scale: float) -> void:
	var win: Window = st.get_window()
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	root.size = win_size
	if absf(scale - 1.0) < 0.01:
		win.content_scale_factor = 1.0
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.content_scale_size = win_size
	else:
		Settings.apply_scale(win)
	for _i in 3:
		await process_frame
	if st.has_method("_layout"):
		st._layout()


func _layout_views(st, line: String, renderer: bool) -> bool:
	if st.hub_button != null:
		st.hub_button.visible = true
	var views: Array = [
		[Vector2i(1920, 1080), 1.0, "100"],
		[Vector2i(1536, 864), 1.0, "125"],
		[Vector2i(1920, 1080), 1.25, "125scale"],
	]
	for row in views:
		var win_size: Vector2i = row[0]
		var scale := float(row[1])
		var tag := str(row[2])
		await _view(st, win_size, scale)
		st._show_terms_line(line)
		for _i in 3:
			await process_frame
		st._layout()
		st._place_terms_plate()
		for _i in 2:
			await process_frame
		var view: Vector2 = st.get_viewport_rect().size
		print("VIEW %s window %s scale %.2f viewport %s" % [tag, win_size, st.get_window().content_scale_factor, view])
		if tag == "125scale" and st.get_window().content_scale_factor < 1.2:
			_bad("125scale factor %s" % st.get_window().content_scale_factor)
			return false
		if not _plate_shows(st, line):
			_bad("plate " + tag)
			return false
		if not _plate_clear(st, line, tag):
			return false
		if renderer and (tag == "100" or tag == "125"):
			await _shot(st, "p98_after_response_en_%s.png" % tag)
	return true


func _widest_result(st) -> String:
	var font: Font = st.body_font if st.body_font != null else ThemeDB.fallback_font
	var best := ""
	var best_w := -1.0
	for key in TermsRemembered.all_keys():
		if not str(key).ends_with(".result"):
			continue
		var text := TermsRemembered._cell(str(key), "en")
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		if width > best_w:
			best_w = width
			best = text
	return best


func _terms_plate(st) -> Control:
	return st.terms_float


func _plate_shows(st, line: String) -> bool:
	var plate := _terms_plate(st)
	if plate == null or not plate.visible or st.terms_float_label == null:
		return false
	return str(st.terms_float_label.text) == line


func _plate_clear(st, line: String, tag: String) -> bool:
	var plate := _terms_plate(st)
	var sentence: Rect2 = st.terms_float_label.get_global_rect()
	if sentence.size.x < 8.0 or sentence.size.y < 8.0:
		_bad("%s sentence size %s" % [tag, sentence])
		return false
	if str(st.footer.text) == line:
		_bad("%s footer holds the sentence" % tag)
		return false
	var blocks: Array = []
	if st.tray != null:
		for child in st.tray.get_children():
			if child is Button and (child as Button).visible:
				blocks.append(child)
	if st.hub_button != null and st.hub_button.visible:
		blocks.append(st.hub_button)
	for node in blocks:
		var button := node as Control
		var rect := button.get_global_rect()
		var name := str(button.name)
		if button is Button:
			name = str((button as Button).text)
		if _overlaps(sentence, rect):
			_bad("%s sentence %s hits %s %s" % [tag, sentence, name, rect])
			return false
		if plate != null and _overlaps(plate.get_global_rect(), rect):
			_bad("%s plate %s hits %s %s" % [tag, plate.get_global_rect(), name, rect])
			return false
	return true


func _overlaps(a: Rect2, b: Rect2) -> bool:
	if a.size.x < 1.0 or a.size.y < 1.0 or b.size.x < 1.0 or b.size.y < 1.0:
		return false
	return a.grow(-0.5).intersects(b.grow(-0.5))


func _renderer_live() -> bool:
	return not OS.has_feature("headless") and DisplayServer.get_name() != "headless"


func _shot(st, name: String) -> void:
	if not _renderer_live():
		print("TERMS SHOT SKIP %s no renderer" % name)
		return
	await process_frame
	RenderingServer.force_draw()
	var tex: ViewportTexture = st.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.get_width() < 2:
		_bad("no image " + name)
		return
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var path := SHOTS.path_join(name)
	var err := img.save_png(path)
	if err != OK:
		_bad("shot %s err %s" % [name, str(err)])
		return
	print("TERMS SHOT %s" % path)


func _careful() -> bool:
	if MASTER_HASH.size() != 60 or MASTER_RNG.size() != 60:
		_bad("baseline length")
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS))
	var clean := Catalog.new()
	if not clean.load_all():
		_bad("careful catalog")
		return false
	var lost := 0
	var lost_seeds := PackedStringArray()
	var matched := 0
	for run_seed in range(1, 61):
		var row := _play(clean, run_seed)
		if int(row.hash) != int(MASTER_HASH[run_seed - 1]) or str(row.rng) != str(MASTER_RNG[run_seed - 1]):
			_bad("seed %d hash %s master %s rng %s" % [run_seed, str(row.hash), str(MASTER_HASH[run_seed - 1]), str(row.rng)])
			return false
		matched += 1
		if str(row.over) != "time":
			lost += 1
			lost_seeds.append(str(run_seed))
		if run_seed % 10 == 0:
			print("Seed %d: %d match" % [run_seed, int(row.hash)])
	print("Careful loss: %d/60 (master %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	print("Seed outcomes: %d/60 match master, rng streams match" % matched)
	if lost != BASELINE_LOST or ",".join(lost_seeds) != LOST_SEEDS:
		_bad("careful loss moved")
		return false
	return true


func _play(clean: Catalog, run_seed: int) -> Dictionary:
	TermsRemembered.enabled = true
	var game := Game.new()
	game.records_path = RECORDS
	game.setup(clean, run_seed, 40)
	game.audit = false
	game.raid_share_profile = "careful"
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while str(game.over) == "" and guard < 42:
		guard += 1
		_read_pending(game)
		bot._act(game)
		game.end_week()
	return {"over": str(game.over), "hash": _hash(_blob(game)), "rng": _rng(game)}


func _read_pending(game) -> void:
	for ev in game.pending:
		if not (ev is Dictionary):
			continue
		for choice in ev.get("choices", []):
			if choice is Dictionary:
				TermsRemembered.visible_label(game, ev, choice)
				TermsRemembered.response_for(ev, choice)


func _read_card(game) -> void:
	var ev: Dictionary = game.front_event()
	_read_pending(game)
	if ev.is_empty():
		return
	for choice in ev.get("choices", []):
		TermsRemembered.visible_label(game, ev, choice)
		TermsRemembered.response_for(ev, choice)


func _fresh() -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 12
	return game


func _fund(game) -> void:
	game.stock.tokens = 40
	game.stock.materials = 30
	game.stock.food = 20
	game.hope = 40
	game.discontent = 20


func _inject(game, event_id: String, memory: String) -> Dictionary:
	var src: Dictionary = game._event_by_id(event_id)
	var copy: Dictionary = src.duplicate(true)
	var by = src.get("by", {})
	if memory != "" and by is Dictionary and by.has(memory):
		copy.text = str(by[memory])
		copy.follow_memory = memory
	elif memory != "":
		copy.follow_memory = memory
	game.pending = [copy]
	game.week_event_ids = {}
	return copy


func _choice(ev: Dictionary, id: String) -> Dictionary:
	for choice in ev.get("choices", []):
		if str(choice.get("id", "")) == id:
			return choice
	return {}


func _set_devout(game, on: bool) -> void:
	for person in game.residents:
		var kept: Array = []
		for trait_name in person.traits:
			if str(trait_name) != "Devout":
				kept.append(trait_name)
		person.traits = kept
	if on and not game.residents.is_empty():
		game.residents[0].traits.append("Devout")


func _clone(game) -> Game:
	var data: Dictionary = game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var copy := Game.new()
	copy.catalog = catalog
	if not copy.import_state(data):
		_bad("clone " + copy.load_error)
	return copy


func _sig(ev: Dictionary) -> String:
	return JSON.stringify(ev.get("choices", []), "", true, true)


func _blob(game) -> String:
	return JSON.stringify(game.export_state(), "", true, true)


func _rng(game) -> String:
	return "%d|%d|%d|%d|%d" % [
		int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state),
		int(game.story_rng.state), int(game.crunch_rng.state),
	]


func _hash(line: String) -> int:
	var h := 5381
	for i in line.length():
		h = ((h << 5) + h) + line.unicode_at(i)
		h = h & 0x7fffffff
	return h


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var sub := path.path_join(name)
		if dir.current_is_dir():
			_wipe(sub)
			dir.remove(name)
		else:
			dir.remove(name)
		name = dir.get_next()


func _finish() -> void:
	print("TERMS FAIL")
	quit(1)
