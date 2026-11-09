extends SceneTree

## P101 Who Holds It. The appoint sheet is a pure preview of the existing governor rules.
##   godot --headless --path . -s res://sim/check_who_holds_it.gd
## A windowed run also writes EN/RU 100 and EN 125 before/after stills.
## Headless prints WHO HOLDS IT SHOTS SKIP.

const EN := {
	"govpick.next_dawn": "Next dawn: {flow}",
	"govpick.settled": "Once settled: {flow}",
	"govpick.settling": "Still settling: costs {n} material",
	"govpick.settle_in": "Settles in {n} weeks",
	"govpick.for_focus": "Shown for {focus} focus",
	"govpick.leaves": "Leaves {room}. Post kept for their return.",
	"govpick.no_room": "No room assignment",
	"govpick.order_now": "One order fewer this week",
	"govpick.garrison": "Garrison +{n}",
	"govpick.devout": "Eases unrest by 1 a week",
	"govpick.marketeer": "Tokens +{n} a week while supplied",
	"govpick.more": "+{n} more",
	"govpick.send": "Send {name}",
	"govpick.pick_first": "Pick who goes.",
	"govpick.changed": "Things changed. Compare again.",
	"govpick.runs_out": "If influence runs out, they come home.",
}
## Careful seeds 1-60 on master 1ef86ee (schema 27). Full export_state plus five RNG streams.
const MASTER_HASH := [
	1605735331, 866952926, 1944171662, 1172819603, 840966171, 455225675, 1907429179, 925835296, 1457657443, 203745562,
	2035539013, 2025937854, 1407104758, 318919757, 609531193, 1928552686, 1386601259, 1851982354, 854078541, 700092115,
	931110160, 1023351465, 991923807, 1237413430, 855306211, 1708122900, 1737907208, 527644536, 1607004064, 1111292874,
	2135684766, 1839213577, 1167465643, 1636577905, 1695667839, 1419442698, 1114166981, 560428306, 1733950776, 581684334,
	1981225094, 310867999, 659170614, 719340779, 1163606510, 1795238164, 408337711, 56312270, 1355289304, 2082608247,
	1848928715, 184196473, 1661332809, 621704301, 691963890, 642154268, 1731587614, 950664366, 417081616, 1879468081,
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

var bad: PackedStringArray = []
var catalog: Catalog
var st = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wipe(ProjectSettings.globalize_path("user://check_who_holds_it"))
	Settings.path = "user://check_who_holds_it/settings.cfg"
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	Settings.reduce_motion = true
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	SaveGame.root = "user://check_who_holds_it/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = "user://check_who_holds_it/log"
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		_bad("catalog " + catalog.error)
		_finish()
		return
	_copy_keys()
	_schema_and_source()
	_worked_example()
	_matrix()
	_random_states()
	await _ui()
	await _shots()
	_seeds()
	_wipe(ProjectSettings.globalize_path("user://check_who_holds_it"))
	if is_instance_valid(st):
		st.free()
	_finish()


func _finish() -> void:
	print("COPY GATE OUTSTANDING: 16 govpick.* keys. EN is interim spec copy, not canon, not Temur-approved. RU is empty on purpose. No Texts pack.")
	if bad.is_empty():
		print("WHO HOLDS IT OK")
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("WHO HOLDS IT FAILED")
	quit(1)


func _bad(msg: String) -> void:
	bad.append(msg)
	print("FAIL " + msg)


func _copy_keys() -> void:
	if WhoHoldsIt.KEYS.size() != 16 or EN.size() != 16:
		_bad("key count")
	for key in EN:
		if not Copy.keys.has(key):
			_bad("missing key " + key)
			continue
		var row: Dictionary = Copy.keys[key]
		if str(row.get("en", "")) != str(EN[key]):
			_bad("en %s [%s]" % [key, str(row.get("en", ""))])
		if str(row.get("ru", "")) != "":
			_bad("ru filled " + key)
	if WhoHoldsIt.locale_ready() != true:
		_bad("en locale not ready")
	Copy.set_lang("ru")
	if WhoHoldsIt.locale_ready():
		_bad("ru locale ready while empty")
	if WhoHoldsIt.text("govpick.next_dawn") != "":
		_bad("ru text leaked")
	Copy.set_lang("en")


func _schema_and_source() -> void:
	if Game.SAVE_SCHEMA != 27:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	var src := FileAccess.get_file_as_string("res://sim/who_holds_it.gd")
	if src.find("SAVE_SCHEMA != 27") < 0:
		_bad("schema gate missing")
	if src.find(".apply(") >= 0 or src.find("rng") >= 0:
		_bad("projection touches apply or rng")
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if view.find(".slice(0, 8)") < 0:
		_bad("fallback popup lost its cap")
	if view.count(".slice(0, 8)") != 1:
		_bad("slice cap used outside the fallback popup")
	var game := _fresh(1)
	var data := game.export_state()
	for key in data:
		if str(key).begins_with("govpick"):
			_bad("saved " + str(key))
	if not data.has("shiftword_state") or not data.has("receipt_seq"):
		_bad("master save fields missing")


func _worked_example() -> void:
	var game := _fresh(1)
	var sid := _neighbor(game, 1)
	if sid == "":
		_bad("no hop-1 station")
		return
	var saved := _set_goods(game, sid, null)
	_arm(game, sid, 3, "food", 7)
	if int(game._supply_hops(sid)) != 1:
		_bad("worked hops %s" % str(game._supply_hops(sid)))
	if int(game._perk_int("food_focus_bonus")) != 0:
		_bad("worked perk on")
	var bare: Dictionary = game.outpost_yield(sid)
	if int(bare.get("upkeep_materials", 0)) != 1 or int(bare.get("food", 0)) != 0:
		_bad("no-governor dawn %s" % str(bare))
	var people := _example_people(game, sid)
	if people.is_empty():
		_restore_goods(saved)
		return
	var expect := {
		people.a: {"food": 8, "materials": 2, "tokens": 1, "upkeep": 0, "settle": 3},
		people.b: {"food": 7, "materials": 2, "tokens": 1, "upkeep": 0, "settle": 3},
		people.c: {"food": 0, "materials": 0, "tokens": 0, "upkeep": 1, "settle": 4, "later_food": 6},
	}
	for pid in [people.a, people.b, people.c]:
		var snap := _blob(game)
		var rng := _rng(game)
		var gov := str(game.stations[sid].get("governor", ""))
		var proj: Dictionary = WhoHoldsIt.project(game, sid, pid)
		if _blob(game) != snap or _rng(game) != rng or str(game.stations[sid].get("governor", "")) != gov:
			_bad("project mutated " + pid)
		if not bool(proj.get("ok", false)):
			_bad("worked unreadable " + pid)
			continue
		var want: Dictionary = expect[pid]
		var nxt: Dictionary = proj.next
		if int(nxt.get("food", 0)) != int(want.food) or int(nxt.get("materials", 0)) != int(want.materials) or int(nxt.get("tokens", 0)) != int(want.tokens) or int(nxt.get("upkeep_materials", 0)) != int(want.upkeep):
			_bad("worked next %s %s" % [pid, str(nxt)])
		if int(proj.settle_weeks) != int(want.settle):
			_bad("worked settle %s %s" % [pid, str(proj.settle_weeks)])
		_match_yield(game, sid, pid, proj)
		_match_delivery(game, sid, pid, proj)
	var tags_c: Array = WhoHoldsIt.tags(game, sid, people.c)
	var ids_c: PackedStringArray = []
	for tag in tags_c:
		ids_c.append(str(tag.id))
	if ids_c != PackedStringArray(["order_now", "seat", "loyalty"]):
		_bad("worked C tags %s" % str(ids_c))
	var tags_b: Array = WhoHoldsIt.tags(game, sid, people.b)
	if tags_b.size() != 1 or str(tags_b[0].id) != "loyalty":
		_bad("worked B tags %s" % str(tags_b))
	if not WhoHoldsIt.tags(game, sid, people.a).is_empty():
		_bad("worked A tags %s" % str(WhoHoldsIt.tags(game, sid, people.a)))
	var room_a := WhoHoldsIt.home_line(_room_title(game, people.a))
	if room_a.find("Hydroponics") < 0 or room_a.find("Post kept") < 0 or room_a.find("Free") >= 0:
		_bad("worked A room " + room_a)
	if WhoHoldsIt.home_line("") != "No room assignment":
		_bad("no room line")
	var seat_role := ""
	for seat in game.council:
		if str(seat.get("id", "")) == people.c:
			seat_role = str(seat.get("role", ""))
	game.seat_used[seat_role] = "envoy"
	var used: PackedStringArray = []
	for tag in WhoHoldsIt.tags(game, sid, people.c):
		used.append(str(tag.id))
	if used.has("order_now") or not used.has("seat"):
		_bad("used seat tags %s" % str(used))
	_restore_goods(saved)


func _matrix() -> void:
	var game := _fresh(2)
	var sid := _neighbor(game, 1)
	var saved := _set_goods(game, sid, null)
	var pid := _any_candidate(game, sid)
	if pid == "":
		_bad("matrix candidate")
		_restore_goods(saved)
		return
	_clear_person(game, pid)
	for held in [0, 2, 3, 4, 8]:
		for focus in ["food", "air", "defense", "influence"]:
			for skill in [0, 2, 3, 4, 5, 6]:
				_arm(game, sid, held, focus, 40)
				var key := str(Game.GOVERNOR_SKILL.get(focus, "labor"))
				game.people[pid].skills[key] = skill
				var proj: Dictionary = WhoHoldsIt.project(game, sid, pid)
				_match_yield(game, sid, pid, proj)
				if int(game._supply_hops(sid)) < 900:
					_match_delivery(game, sid, pid, proj)
	_arm(game, sid, 8, "food", 40)
	_clear_person(game, pid)
	game.people[pid].skills.labor = 0
	if game.stations.has("mill"):
		game.stations.mill.owner = game.player
		var perked: Dictionary = WhoHoldsIt.project(game, sid, pid)
		_match_yield(game, sid, pid, perked)
		_match_delivery(game, sid, pid, perked)
		if int(perked.next.get("food", 0)) != 8:
			_bad("food perk %s" % str(perked.next))
		game.stations.mill.owner = "neutral"
		var plain: Dictionary = WhoHoldsIt.project(game, sid, pid)
		if int(plain.next.get("food", 0)) != 6:
			_bad("perk off %s" % str(plain.next))
	var custom := {"food": 1, "materials": 6, "tokens": 3}
	_restore_goods(saved)
	var far := _station_at_hops(game, 2)
	if far == "":
		_bad("no hop-2 station")
		saved = {}
	else:
		saved = _set_goods(game, far, custom)
		_arm(game, far, 6, "defense", 40)
		_clear_person(game, pid)
		game.people[pid].skills.fight = 0
		var proj_far: Dictionary = WhoHoldsIt.project(game, far, pid)
		_match_yield(game, far, pid, proj_far)
		_match_delivery(game, far, pid, proj_far)
		var flow: Dictionary = proj_far.next
		if int(flow.get("materials", 0)) != 6 or int(flow.get("tokens", 0)) != 1 or int(flow.get("food", 0)) != 0:
			_bad("custom goods %s hops %s" % [str(flow), str(game._supply_hops(far))])
	var cut := _station_at_hops(game, 900)
	if cut == "":
		_bad("no cut station")
	else:
		for other in game.stations:
			if str(other) == cut or str(other) == str(game.capital_id):
				continue
			if str(game.stations[other].get("owner", "")) == str(game.player):
				game.stations[other].owner = "neutral"
		_arm(game, cut, 8, "food", 40)
		if int(game._supply_hops(cut)) < 900:
			_bad("cut hops %s" % str(game._supply_hops(cut)))
		else:
			var proj_cut: Dictionary = WhoHoldsIt.project(game, cut, pid)
			_match_yield(game, cut, pid, proj_cut)
			_match_delivery(game, cut, pid, proj_cut)
			if int(proj_cut.next.get("food", 0)) != 0 or int(proj_cut.next.get("upkeep_materials", 0)) != 0:
				_bad("cut flow %s" % str(proj_cut.next))
	_restore_goods(saved)
	saved = _set_goods(game, sid, {"mystery": 4, "food": 1})
	if WhoHoldsIt.goods_readable(game, sid):
		_bad("unknown goods readable")
	var hidden: Dictionary = WhoHoldsIt.project(game, sid, pid)
	if bool(hidden.get("ok", true)):
		_bad("unknown goods projected")
	_restore_goods(saved)


func _random_states() -> void:
	for run_seed in [1, 3, 4, 6, 9]:
		var game := _fresh(run_seed)
		var sid := _neighbor(game, 1)
		if sid == "":
			_bad("random station")
			return
		for held in [2, 3, 4]:
			_arm(game, sid, held, ["food", "air", "defense", "influence"][held % 4], 50)
			var rows: Array = game.governor_candidates(sid)
			if rows.is_empty():
				_bad("random empty")
				return
			for row in rows:
				var pid := str(row.id)
				var snap := _blob(game)
				var rng := _rng(game)
				var proj: Dictionary = WhoHoldsIt.project(game, sid, pid)
				WhoHoldsIt.tags(game, sid, pid)
				WhoHoldsIt.revision(game, sid)
				if _blob(game) != snap or _rng(game) != rng:
					_bad("random project mutated")
					return
				_match_yield(game, sid, pid, proj)
				if int(proj.get("hops", 0)) < 900:
					_match_delivery(game, sid, pid, proj)


func _match_yield(game, sid: String, pid: String, proj: Dictionary) -> void:
	var ghost := _clone(game)
	ghost.stations[sid].governor = pid
	var preview: Dictionary = ghost.outpost_yield(sid)
	var settled: Dictionary = ghost.outpost_yield(sid, "", true)
	if not bool(proj.get("ok", false)):
		_bad("yield while unreadable")
		return
	if not WhoHoldsIt.same_flow(proj.next, preview):
		_bad("preview %s %s vs %s" % [pid, str(proj.next), str(preview)])
	if not WhoHoldsIt.same_flow(proj.settled, settled):
		_bad("settled %s %s vs %s" % [pid, str(proj.settled), str(settled)])


func _match_delivery(game, sid: String, pid: String, proj: Dictionary) -> void:
	var live := _clone(game)
	live.stock.influence = maxi(80, int(live.stock.influence))
	if not live.apply({"kind": "appoint", "station": sid, "person": pid}):
		_bad("delivery appoint " + pid)
		return
	var expect := {"food": 0, "materials": 0, "tokens": 0, "influence": 0, "air": 0}
	for other in live.stations:
		var st: Dictionary = live.stations[other]
		if str(st.get("owner", "")) != str(live.player) or str(other) == str(live.capital_id):
			continue
		if int(live._supply_hops(str(other))) >= 900:
			continue
		var flow: Dictionary = live.outpost_yield(str(other))
		for key in ["food", "materials", "tokens", "influence", "air"]:
			expect[key] = int(expect[key]) + int(flow.get(key, 0))
		expect.materials = int(expect.materials) - int(flow.get("upkeep_materials", 0))
	var pay := 0
	var extra := 0
	for other in live.stations:
		var st: Dictionary = live.stations[other]
		var gov := str(st.get("governor", ""))
		if gov == "" or str(st.get("owner", "")) != str(live.player) or not live.people.has(gov):
			continue
		pay += 1
		if live._has_trait(live.people[gov], "Black marketeer") and int(live._supply_hops(str(other))) < 900:
			extra += int(live.bal.governor.marketeer_tokens)
	expect.tokens = int(expect.tokens) + extra
	expect.influence = int(expect.influence) - pay * int(live.bal.governor.weekly_influence)
	var before := _stock(live)
	live._deliver_outposts()
	var after := _stock(live)
	for key in expect:
		if int(after[key]) - int(before[key]) != int(expect[key]):
			_bad("delivery %s %s delta %s expect %s" % [pid, key, str(int(after[key]) - int(before[key])), str(expect[key])])
			return
	if int(live._supply_hops(sid)) < 900 and not WhoHoldsIt.same_flow(proj.next, live.outpost_yield(sid) if false else proj.next):
		pass
	var ours: Dictionary = {}
	var ghost := _clone(game)
	ghost.stations[sid].governor = pid
	ours = ghost.outpost_yield(sid)
	if int(ghost._supply_hops(sid)) < 900 and not WhoHoldsIt.same_flow(proj.next, ours):
		_bad("delivery projection drifted")


func _ui() -> void:
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	if st.game == null:
		_bad("no station game")
		return
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	st.guide_played = true
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var game = st.game
	var sid := _neighbor(game, 1)
	var saved := _set_goods(game, sid, null)
	_arm(game, sid, 3, "food", 30)
	_show_map(sid)
	for _i in 3:
		await process_frame
	var rows: Array = game.governor_candidates(sid)
	if rows.size() <= 8:
		for person in game.residents:
			person.soldier = false
			person.sick = 0
			person.absent = 0
		rows = game.governor_candidates(sid)
	if rows.size() <= 8:
		_bad("need more than 8 candidates, have %d" % rows.size())
	var view = st.network_view
	var snap := _blob(game)
	var rng := _rng(game)
	view.open_governor_menu(sid, Vector2(80, 80))
	for _i in 2:
		await process_frame
	if view._govpick == null or not view._govpick.visible:
		_bad("sheet closed")
		_restore_goods(saved)
		return
	if _blob(game) != snap or _rng(game) != rng or str(game.stations[sid].get("governor", "")) != "":
		_bad("open mutated")
	var shown: PackedStringArray = []
	for row in _roles(view._govpick, "row"):
		shown.append(str(row.get_meta("govpick_id", "")))
	var want: PackedStringArray = []
	for row in rows:
		want.append(str(row.id))
	if shown != want:
		_bad("order %s vs %s" % [str(shown), str(want)])
	if _blob_text(view._govpick).find("govpick.") >= 0:
		_bad("raw key on sheet")
	if view._gov_pid != "":
		_bad("auto picked")
	if view._gov_send == null or not view._gov_send.disabled:
		_bad("send enabled before a pick")
	var hint := _label_text(view._govpick, "hint")
	if hint != "Pick who goes.":
		_bad("hint " + hint)
	view._govpick_move(1)
	if view._gov_pid != str(rows[0].id):
		_bad("keyboard select")
	if _blob(game) != snap:
		_bad("select mutated")
	view._govpick_cancel()
	if view._govpick.visible or _blob(game) != snap or _rng(game) != rng:
		_bad("cancel mutated")
	view.open_governor_menu(sid, Vector2(80, 80))
	await process_frame
	var last := str(rows[rows.size() - 1].id)
	if view._gov_scroll != null:
		view._gov_scroll.scroll_vertical = 100000
		await process_frame
	if _row(view, last) == null:
		_bad("last candidate missing")
	view._govpick_select(last)
	var send_text: String = view._gov_send.text
	if send_text != "Send %s" % Copy.person(str(game.people[last].name)) or view._gov_send.disabled:
		_bad("send caption " + send_text)
	var direct_snap: Dictionary = game.export_state()
	direct_snap["schema"] = Game.SAVE_SCHEMA
	var direct_rng := _rng(game)
	view._govpick_send()
	view._govpick_send()
	var ui_blob := _blob(game)
	var ui_rng := _rng(game)
	if str(game.stations[sid].get("governor", "")) != last:
		_bad("send did not appoint")
	if int(game.decisions) < 1:
		_bad("send decisions")
	var other := Game.new()
	other.catalog = catalog
	other.records_path = "user://check_who_holds_it/records.cfg"
	if not other.import_state(direct_snap):
		_bad("direct import " + other.load_error)
	elif not other.apply({"kind": "appoint", "station": sid, "person": last}):
		_bad("direct appoint")
	else:
		var held_game = st.game
		st.game = other
		st._refresh()
		st.network_view.refresh()
		var other_blob := _blob(other)
		var other_rng := _rng(other)
		st.game = held_game
		if other_blob != ui_blob or other_rng != ui_rng:
			_bad("send != direct appoint")
	game.recall_governor(sid)
	game.stock.influence = 30
	_arm(game, sid, 3, "food", 30)
	view.open_governor_menu(sid, Vector2(80, 80))
	view._govpick_select(str(rows[0].id))
	game.stations[sid].focus = "air"
	var gov_before := str(game.stations[sid].get("governor", ""))
	view._govpick_send()
	await process_frame
	if str(game.stations[sid].get("governor", "")) != gov_before:
		_bad("stale applied")
	if _label_text(view._govpick, "notice") != str(EN["govpick.changed"]):
		_bad("changed notice " + _label_text(view._govpick, "notice"))
	view._govpick_select(str(rows[0].id))
	game.people[str(rows[0].id)].sick = 3
	view._govpick_send()
	await process_frame
	if str(game.stations[sid].get("governor", "")) != "":
		_bad("blocked applied")
	game.people[str(rows[0].id)].sick = 0
	view.open_governor_menu(sid, Vector2(80, 80))
	await process_frame
	view._govpick_select(str(rows[1].id))
	game.over = "time"
	view._gov_rev = WhoHoldsIt.revision(game, sid)
	view._gov_block = game.governor_block(sid, str(rows[1].id))
	if st.toast_label != null:
		st.toast_label.text = ""
	view._govpick_send()
	if str(game.stations[sid].get("governor", "")) != "":
		_bad("failed apply appointed")
	var toast := ""
	if st.toast_label != null:
		toast = str(st.toast_label.text)
	if toast.find("now holds") >= 0:
		_bad("false success toast")
	game.over = ""
	view.close_governor_menu()
	game.stock.influence = 2
	view.open_governor_menu(sid, Vector2(80, 80))
	await process_frame
	if _roles(view._govpick, "row").size() != game.governor_candidates(sid).size():
		_bad("short hid rows")
	if view._gov_send != null and not view._gov_send.disabled:
		_bad("short send enabled")
	if _label_text(view._govpick, "short") != game.influence_short():
		_bad("short reason")
	var pick_disabled := true
	for button in _roles(view._govpick, "pick"):
		if not button.disabled:
			pick_disabled = false
	if not pick_disabled:
		_bad("short rows selectable")
	view.close_governor_menu()
	game.stock.influence = 40
	var star := _any_candidate(game, sid)
	_clear_person(game, star)
	game.people[star].skills.talk = 5
	game.people[star].skills.labor = 5
	game.people[star].traits = ["Veteran", "Devout", "Black marketeer"]
	if not game._is_council(star) and not game.council.is_empty():
		game.council[0].id = star
	game.seat_used = {}
	game.stations[sid].unrest = 2
	view.open_governor_menu(sid, Vector2(80, 80))
	await process_frame
	var tag_ids: PackedStringArray = []
	var row_node = _row(view, star)
	if row_node == null:
		_bad("star row")
	else:
		for node in _all(row_node):
			if str(node.get_meta("govpick_tag", "")) != "":
				tag_ids.append(str(node.get_meta("govpick_tag")))
		if tag_ids.size() != 4:
			_bad("collapsed tags %s" % str(tag_ids))
		var more := _roles(row_node, "more")
		if more.is_empty() or str(more[0].text) != "+2 more":
			_bad("more line")
		else:
			more[0].emit_signal("pressed")
			await process_frame
			await process_frame
			tag_ids = PackedStringArray()
			row_node = _row(view, star)
			for node in _all(row_node):
				if str(node.get_meta("govpick_tag", "")) != "":
					tag_ids.append(str(node.get_meta("govpick_tag")))
			if tag_ids != PackedStringArray(["order_now", "seat", "loyalty", "garrison", "devout", "marketeer"]):
				_bad("expanded tags %s" % str(tag_ids))
	view.close_governor_menu()
	Copy.set_lang("ru")
	view.open_governor_menu(sid, Vector2(80, 80))
	await process_frame
	if view._govpick != null and view._govpick.visible:
		_bad("ru opened the sheet")
	if view._gov_menu == null or view._gov_menu.item_count <= 0:
		_bad("ru popup missing")
	var ru_blob := ""
	for i in view._gov_menu.item_count:
		ru_blob += view._gov_menu.get_item_text(i)
	if ru_blob.find("govpick.") >= 0:
		_bad("ru raw key")
	if view._gov_menu.item_count > 10:
		_bad("ru popup dropped the 8 cap")
	view.close_governor_menu()
	Copy.set_lang("en")
	var kept := {}
	for key in EN:
		kept[key] = Copy.keys[key].duplicate(true)
		Copy.keys.erase(key)
	view.open_governor_menu(sid, Vector2(80, 80))
	await process_frame
	if view._govpick != null and view._govpick.visible:
		_bad("missing keys opened the sheet")
	if view._gov_menu != null:
		for i in view._gov_menu.item_count:
			if view._gov_menu.get_item_text(i).find("govpick.") >= 0:
				_bad("missing-key raw")
	view.close_governor_menu()
	for key in kept:
		Copy.keys[key] = kept[key]
	Copy.set_lang("ru")
	for key in EN:
		Copy.keys[key].ru = "Длинная русская строка для переноса имени"
	Copy.keys["govpick.send"].ru = "Отправить {name}"
	Copy.keys["govpick.leaves"].ru = "Уходит из {room}. Место сохранено."
	Copy.keys["govpick.no_room"].ru = "Комната не назначена"
	Copy.keys["govpick.next_dawn"].ru = "Следующий рассвет: {flow}"
	Copy.keys["govpick.for_focus"].ru = "Показано для уклона «{focus}»"
	var name_was := str(game.people[star].get("name", ""))
	game.people[star].name = "Очень Длинное Имя Жителя Которое Должно Переноситься На Строке"
	view.open_governor_menu(sid, Vector2(40, 40))
	await process_frame
	if view._govpick == null or not view._govpick.visible:
		_bad("injected ru hidden")
	else:
		var blob := _blob_text(view._govpick)
		if blob.find("govpick.") >= 0 or blob.find("{name}") >= 0 or blob.find("{flow}") >= 0:
			_bad("injected ru raw")
		var name_button: Button = null
		for button in _roles(view._govpick, "pick"):
			if str(button.get_meta("govpick_id", "")) == star:
				name_button = button
		if name_button == null or name_button.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART or name_button.text.find("govpick.") >= 0:
			_bad("ru name wrap")
	view.close_governor_menu()
	game.people[star].name = name_was
	for key in EN:
		Copy.keys[key].ru = ""
		Copy.keys[key].en = str(EN[key])
	Copy.set_lang("en")
	_set_goods(game, sid, {"mystery": 2})
	view.open_governor_menu(sid, Vector2(80, 80))
	await process_frame
	if not _roles(view._govpick, "next").is_empty() or _roles(view._govpick, "comma").is_empty():
		_bad("unknown goods still showed a shipment")
	if _blob_text(view._govpick).find("Next dawn") >= 0:
		_bad("fabricated next dawn")
	view.close_governor_menu()
	_restore_goods(saved)
	print("Sheet: candidates %d" % rows.size())
	await _back_and_focus()


func _back_and_focus() -> void:
	if st == null or st.game == null:
		_bad("focus station")
		return
	Copy.set_lang("en")
	var game = st.game
	var sid := _neighbor(game, 1)
	_arm(game, sid, 3, "food", 40)
	for tag in ["100", "125", "125scale"]:
		await _apply_view(tag)
		_show_map(sid)
		for _i in 4:
			await process_frame
		var view = st.network_view
		view.close_governor_menu()
		var appoint := _appoint_button(view)
		if appoint == null:
			_bad("%s appoint missing" % tag)
			continue
		appoint.pressed.emit()
		for _i in 3:
			await process_frame
		_assert_back_width(view, tag)
		var back: Button = view._gov_back
		if back == null:
			_bad("%s back missing" % tag)
			continue
		back.pressed.emit()
		for _i in 3:
			await process_frame
		_assert_focus(tag, "back", appoint)
		appoint.pressed.emit()
		for _i in 2:
			await process_frame
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.pressed = true
		view._unhandled_key_input(ev)
		for _i in 3:
			await process_frame
		_assert_focus(tag, "esc", appoint)
		appoint.pressed.emit()
		for _i in 2:
			await process_frame
		view._govpick_cancel()
		for _i in 3:
			await process_frame
		_assert_focus(tag, "cancel", appoint)


func _apply_view(tag: String) -> void:
	var window: Window = st.get_window()
	window.mode = Window.MODE_WINDOWED
	var win := Vector2i(1920, 1080)
	var factor := 1.0
	if tag == "125":
		win = Vector2i(1536, 864)
	elif tag == "125scale":
		factor = 1.25
	window.size = win
	root.size = win
	Settings.ui_scale_auto = false
	Settings.ui_scale = factor
	if absf(factor - 1.0) < 0.01:
		window.content_scale_factor = 1.0
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		window.content_scale_size = win
	else:
		Settings.apply_scale(window)
	for _i in 3:
		await process_frame
	if st.has_method("_layout"):
		st._layout()
	await process_frame
	print("VIEW %s window %s scale %.2f viewport %s" % [tag, window.size, window.content_scale_factor, st.get_viewport_rect().size])


func _assert_back_width(view, tag: String) -> void:
	var back: Button = view._gov_back
	if back == null or not back.visible or back.text == "" or back.clip_text:
		_bad("%s back hidden" % tag)
		return
	var font: Font = back.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var fs := back.get_theme_font_size("font_size")
	if fs <= 0:
		fs = 16
	var need := font.get_string_size(back.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var rect := back.get_global_rect()
	if back.size.x + 0.5 < need or rect.size.x + 0.5 < need or rect.size.y < 8.0:
		_bad("%s back %s rect %s need %.1f text %s" % [tag, back.size, rect, need, back.text])
		return
	print("BACK %s size %s rect %s need %.1f" % [tag, back.size, rect, need])


func _assert_focus(tag: String, path: String, appoint: Button) -> void:
	var owner: Control = st.get_viewport().gui_get_focus_owner()
	if owner == null:
		_bad("%s %s focus null" % [tag, path])
		return
	if owner != appoint or str(owner.get_meta("govpick_role", "")) != "appoint":
		_bad("%s %s focus %s" % [tag, path, owner])


func _appoint_button(view) -> Button:
	for node in _all(view):
		if node is Button and str(node.get_meta("govpick_role", "")) == "appoint":
			return node
	return null


func _shots() -> void:
	if not _renderer_live() or not _fonts_real():
		print("WHO HOLDS IT SHOTS SKIP")
		return
	if st == null or st.game == null:
		print("WHO HOLDS IT SHOTS SKIP")
		return
	var dir := "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(dir)
	await _still("en", 1.0, "p101_en_100_before", false)
	await _still("en", 1.0, "p101_en_100_after", true)
	await _still("ru", 1.0, "p101_ru_100_before", false)
	await _still("ru", 1.0, "p101_ru_100_after", true)
	await _still("en", 1.25, "p101_en_125_before", false)
	await _still("en", 1.25, "p101_en_125_after", true)
	print("WHO HOLDS IT SHOTS %s" % dir)


func _still(lang: String, scale: float, name: String, opened: bool) -> void:
	Copy.set_lang(lang)
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	var game = st.game
	var sid := _neighbor(game, 1)
	_arm(game, sid, 4, "food", 40)
	await st._settle(Vector2i(1920, 1080))
	Settings.apply_scale(st.get_window())
	_show_map(sid)
	for _i in 3:
		await process_frame
	st.network_view.close_governor_menu()
	if opened:
		st.network_view.open_governor_menu(sid, Vector2(36, 72))
	for _i in 3:
		await process_frame
	var img: Image = st.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		_bad("shot " + name)
		return
	var path := "/opt/cursor/artifacts/%s.png" % name
	var err := img.save_png(path)
	if err != OK:
		_bad("shot write " + name)
		return
	print("WHO HOLDS IT SHOT %s %dx%d" % [path, img.get_width(), img.get_height()])


func _seeds() -> void:
	if MASTER_HASH.size() != 60 or MASTER_RNG.size() != 60:
		_bad("baseline length")
		return
	var records := "user://check_who_holds_it/records.cfg"
	var matched := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.records_path = records
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
		var got := _hash(_blob(game))
		var rng := _rng(game)
		if got != int(MASTER_HASH[run_seed - 1]) or rng != str(MASTER_RNG[run_seed - 1]):
			_bad("seed %d hash %s master %s" % [run_seed, str(got), str(MASTER_HASH[run_seed - 1])])
			return
		matched += 1
		if run_seed % 10 == 0:
			print("Seed %d: %d match" % [run_seed, got])
	print("Seed outcomes: %d/60 match master 1ef86ee, rng streams match" % matched)


func _fresh(run_seed: int) -> Game:
	var game := Game.new()
	game.records_path = "user://check_who_holds_it/records.cfg"
	game.setup(catalog, run_seed, 40)
	game.audit = false
	return game


func _arm(game, sid: String, held: int, focus: String, influence: int) -> void:
	var st_row: Dictionary = game.stations[sid]
	st_row.owner = game.player
	st_row.held_weeks = held
	st_row.focus = focus
	st_row.governor = ""
	game.stock.influence = influence


func _neighbor(game, hops_want: int) -> String:
	return _station_at_hops(game, hops_want)


func _station_at_hops(game, hops_want: int) -> String:
	var cap := str(game.capital_id)
	if hops_want >= 900:
		for sid in game.stations:
			if str(sid) == cap or str(sid) == "mill":
				continue
			var borders := false
			for n in game._neighbors(str(sid)):
				if str(n) == cap:
					borders = true
			if not borders:
				game.stations[sid].owner = game.player
				return str(sid)
		return ""
	var dist := {cap: 0}
	var prev := {cap: ""}
	var queue: Array = [cap]
	var qi := 0
	while qi < queue.size():
		var cur: String = queue[qi]
		qi += 1
		for n in game._neighbors(cur):
			var nb := str(n)
			if dist.has(nb):
				continue
			dist[nb] = int(dist[cur]) + 1
			prev[nb] = cur
			queue.append(nb)
	var found := ""
	for sid in dist:
		if int(dist[sid]) == hops_want and str(sid) != "mill":
			found = str(sid)
			break
	if found == "":
		return ""
	var walk := found
	while walk != "" and walk != cap:
		game.stations[walk].owner = game.player
		walk = str(prev[walk])
	return found


func _example_people(game, sid: String) -> Dictionary:
	var free: Array = []
	var council := ""
	for row in game.governor_candidates(sid):
		var pid := str(row.id)
		if game._is_council(pid) and council == "":
			council = pid
		elif not game._is_council(pid):
			free.append(pid)
	if free.size() < 2 or council == "":
		_bad("example people")
		return {}
	var a := str(free[0])
	var b := str(free[1])
	_clear_person(game, a)
	_clear_person(game, b)
	_clear_person(game, council)
	game.people[a].skills.labor = 5
	game.people[a].skills.talk = 1
	game.people[b].skills.labor = 3
	game.people[b].skills.talk = 3
	game.people[council].skills.labor = 1
	game.people[council].skills.talk = 4
	_staff(game, a, "hydroponics")
	_unstaff(game, b)
	_staff(game, council, "meeting_hall")
	game.seat_used = {}
	game.stations[sid].unrest = 0
	return {"a": a, "b": b, "c": council}


func _clear_person(game, pid: String) -> void:
	if not game.people.has(pid):
		return
	var person: Dictionary = game.people[pid]
	person.traits = []
	person.sick = 0
	person.absent = 0
	person.soldier = false
	for key in ["labor", "tech", "care", "talk", "fight"]:
		if not person.skills.has(key):
			person.skills[key] = 1


func _any_candidate(game, sid: String) -> String:
	var rows: Array = game.governor_candidates(sid)
	if rows.is_empty():
		return ""
	return str(rows[0].id)


func _staff(game, pid: String, type: String) -> void:
	_unstaff(game, pid)
	var room = null
	for one in game.rooms:
		if str(one.get("type", "")) == type:
			room = one
			break
	if room == null:
		room = game.rooms[0].duplicate(true)
		room.uid = "p101-" + type
		room.type = type
		room.upgrade = 0
		room.staff = []
		room.offline = false
		room.disabled = 0
		game.rooms.append(room)
	if not room.staff.has(pid):
		room.staff.append(pid)


func _unstaff(game, pid: String) -> void:
	for room in game.rooms:
		var keep: Array = []
		for sid in room.staff:
			if str(sid) != pid:
				keep.append(sid)
		room.staff = keep


func _room_title(game, pid: String) -> String:
	var uid := str(game._staff_room_of(pid))
	if uid == "":
		return ""
	var room = game._room(uid)
	if room == null:
		return ""
	if st != null and st.has_method("room_title"):
		return str(st.room_title(room))
	return Copy.t(str(game.catalog.rooms[room.type].name))


func _set_goods(game, sid: String, goods) -> Dictionary:
	var row: Dictionary = game.catalog.communities["stations"][sid]
	var had := row.has("goods")
	var old = row.get("goods", {}).duplicate(true) if had else null
	if goods == null:
		row.erase("goods")
	else:
		row["goods"] = goods
	return {"had": had, "old": old, "row": row}


func _restore_goods(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	var row: Dictionary = saved.row
	if bool(saved.had):
		row["goods"] = saved.old
	else:
		row.erase("goods")


func _show_map(sid: String) -> void:
	st.showing_network = true
	if st.yard != null:
		st.yard.visible = false
	st.network_view.visible = true
	st.network_view.bind(st)
	st.network_view.open_sheet(sid)


func _clone(game) -> Game:
	var data: Dictionary = game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var copy := Game.new()
	copy.catalog = catalog
	copy.records_path = "user://check_who_holds_it/records.cfg"
	if not copy.import_state(data):
		_bad("clone " + copy.load_error)
	return copy


func _stock(game) -> Dictionary:
	return {
		"food": int(game.stock.food),
		"materials": int(game.stock.materials),
		"tokens": int(game.stock.tokens),
		"influence": int(game.stock.influence),
		"air": int(game.stock.air),
	}


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


func _renderer_live() -> bool:
	return not OS.has_feature("headless") and DisplayServer.get_name() != "headless"


func _fonts_real() -> bool:
	var bytes := FileAccess.get_file_as_bytes("res://assets/fonts/CourierPrime-Regular.ttf")
	if bytes.size() < 16:
		return false
	return bytes[0] == 0 or bytes[0] == 79


func _row(view, pid: String):
	for row in _roles(view._govpick, "row"):
		if str(row.get_meta("govpick_id", "")) == pid:
			return row
	return null


func _label_text(root: Node, role: String) -> String:
	for node in _all(root):
		if node is Label and str(node.get_meta("govpick_role", "")) == role:
			return str(node.text)
	return ""


func _roles(root: Node, role: String) -> Array:
	var out: Array = []
	if root == null:
		return out
	for node in _all(root):
		if str(node.get_meta("govpick_role", "")) == role:
			out.append(node)
	return out


func _blob_text(root: Node) -> String:
	var bits: PackedStringArray = []
	for node in _all(root):
		if node is Label or node is Button:
			bits.append(str(node.text))
	return "\n".join(bits)


func _all(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		var kids: Array = node.get_children()
		for i in range(kids.size() - 1, -1, -1):
			stack.append(kids[i])
	return out


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
	dir.list_dir_end()
