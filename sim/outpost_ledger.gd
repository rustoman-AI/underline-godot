class_name OutpostLedger
extends RefCounted

## P85 Outpost Ledger. A Visit glance at stock a station record already stores.
## Shipment tables (station_goods), weekly yield, and the capital pile are not holdings.
## This never writes a station, stock, hope, or the soft-dawn stack. No map mark.

const FLAG := "seen_outpost_ledger"
const MATS_KEYS: PackedStringArray = ["mats", "materials"]
const FOOD_KEYS: PackedStringArray = ["food"]
const GOODS_KEYS: PackedStringArray = ["goods"]


static func shows(game, sid: String) -> bool:
	if game == null or str(sid) == "" or not game.stations.has(sid):
		return false
	if str(sid) == str(game.capital_id):
		return false
	var st: Dictionary = game.stations[sid]
	if str(st.get("owner", "")) != str(game.player):
		return false
	if bool(st.get("hidden", false)):
		return false
	return true


static func map_mark() -> bool:
	return false


static func joins_soft_dawn() -> bool:
	return false


static func _numeric(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## A number the station record already has, or 0 when that field is absent.
## Does not create the key and does not read catalog goods or outpost yield.
static func _read_key(st: Dictionary, keys: PackedStringArray) -> Dictionary:
	for key in keys:
		if st.has(key) and _numeric(st[key]):
			return {"n": maxi(0, int(st[key])), "exposed": true, "field": str(key)}
	var stock = st.get("stock", null)
	if stock is Dictionary:
		for key in keys:
			if (stock as Dictionary).has(key) and _numeric((stock as Dictionary)[key]):
				return {"n": maxi(0, int((stock as Dictionary)[key])), "exposed": true, "field": "stock." + str(key)}
	return {"n": 0, "exposed": false, "field": ""}


static func amounts(game, sid: String) -> Dictionary:
	var blank := {
		"mats": 0, "food": 0, "goods": 0,
		"mats_exposed": false, "food_exposed": false, "goods_exposed": false,
		"mats_field": "", "food_field": "", "goods_field": "",
	}
	if not shows(game, sid):
		return blank
	var st: Dictionary = game.stations[sid]
	var mats := _read_key(st, MATS_KEYS)
	var food := _read_key(st, FOOD_KEYS)
	var goods := _read_key(st, GOODS_KEYS)
	return {
		"mats": int(mats.n),
		"food": int(food.n),
		"goods": int(goods.n),
		"mats_exposed": bool(mats.exposed),
		"food_exposed": bool(food.exposed),
		"goods_exposed": bool(goods.exposed),
		"mats_field": str(mats.field),
		"food_field": str(food.field),
		"goods_field": str(goods.field),
	}


static func is_empty(row: Dictionary) -> bool:
	return int(row.get("mats", 0)) == 0 and int(row.get("food", 0)) == 0 and int(row.get("goods", 0)) == 0


static func status_text(row: Dictionary) -> String:
	if is_empty(row):
		return Copy.t("ledger.empty")
	return Copy.fill("ledger.status", {
		"mats": int(row.get("mats", 0)),
		"food": int(row.get("food", 0)),
		"goods": int(row.get("goods", 0)),
	})


static func stack_text(row: Dictionary) -> PackedStringArray:
	return PackedStringArray([
		Copy.fill("ledger.mats", {"n": int(row.get("mats", 0))}),
		Copy.fill("ledger.food", {"n": int(row.get("food", 0))}),
		Copy.fill("ledger.goods", {"n": int(row.get("goods", 0))}),
	])


static func tip() -> String:
	return Copy.t("ledger.tip")


## First Visit that actually shows the ledger this run. Sets flags.seen_outpost_ledger.
static func note(game) -> String:
	if game == null:
		return ""
	if bool(game.flags.get(FLAG, false)):
		return ""
	game.flags[FLAG] = true
	return Copy.t("ledger.first")
