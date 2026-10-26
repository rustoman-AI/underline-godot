extends RefCounted
class_name ArtPack

## Imported textures and fonts. preload() is what puts them in the export.

static var missing := PackedStringArray()
static var _textures: Dictionary = {}
static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}

static func note(path: String) -> void:
	if path == "" or missing.has(path):
		return
	missing.append(path)
	print("Missing art: %s" % path)


static func load_texture(path: String) -> Texture2D:
	var tex: Texture2D = textures().get(path)
	if tex == null and ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res
	if tex != null and tex.get_width() > 0:
		return tex
	note(path)
	return null


static func load_font(path: String, cyrillic: bool = false) -> Font:
	var face: Font = fonts().get(path)
	if face == null and ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Font:
			face = res
	if face == null:
		note(path)
		return null
	if cyrillic and face.get_char_size(0x0410, 32).x <= 1.0:
		note(path)
		return null
	return face


## Eight reusable mood plates. event_{hash%8} indexes this pool.
const MOOD_PLATES := ["dark", "quarrel", "hunger", "scrap", "tools", "sleep", "chapel", "labor"]


const DILEMMA_FRAME := "res://assets/overlays/dilemma_frame.webp"


## Brass rim for a major state-dilemma card. The center is transparent.
static func dilemma_frame() -> Texture2D:
	return load_texture(DILEMMA_FRAME)


static func has_event_art(event_id: String) -> bool:
	if event_id == "":
		return false
	return textures().has("res://assets/events/%s.webp" % event_id)


## Own plate (`{id}.webp`) first, then the authored banner, then the tag mood,
## then event_{hash%8} from MOOD_PLATES. A mood alias in `banner` must not hide
## art that was drawn for this event.
static func resolve_event_banner(ev: Dictionary) -> String:
	var id := str(ev.get("id", "")).strip_edges()
	if has_event_art(id):
		return id
	var plate := str(ev.get("banner", "")).strip_edges()
	if plate == "":
		plate = id
	if has_event_art(plate):
		return plate
	var mood := mood_for_tag(str(ev.get("tag", "")).strip_edges())
	if has_event_art(mood):
		return mood
	var hash_id := id if id != "" else plate
	var hashed := event_hash_mood(hash_id)
	if has_event_art(hashed):
		return hashed
	return ""


static func mood_for_tag(tag: String) -> String:
	if tag != "" and MOOD_PLATES.has(tag):
		return tag
	return ""


static func event_hash_mood(id: String) -> String:
	var n := absi(id.hash()) % MOOD_PLATES.size()
	return str(MOOD_PLATES[n])


## Authored banner must name a registered plate. A blank banner still
## passes when the tag mood or event_{hash%8} plate is registered.
static func banner_faults(rows: Array) -> PackedStringArray:
	var missing := PackedStringArray()
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var ev: Dictionary = row
		var id := str(ev.get("id", "")).strip_edges()
		var label := id if id != "" else "?"
		var plate := str(ev.get("banner", "")).strip_edges()
		if plate != "":
			if not has_event_art(plate):
				missing.append("%s -> %s" % [label, plate])
			continue
		if resolve_event_banner(ev) == "":
			missing.append(label)
	return missing


static func collect_banner_rows(weighted: Array, check_root: Dictionary) -> Array:
	var rows: Array = []
	for ev in weighted:
		rows.append(ev)
	var checks = check_root.get("events", [])
	if checks is Array:
		for raw in checks:
			rows.append(raw)
	for id in crunch_ids():
		rows.append(crunch_event_art(id))
	return rows


static func crunch_ids() -> PackedStringArray:
	return PackedStringArray(["pantry", "ducts", "belt", "stacks", "shopbelt", "dynamo"])


## Art for the crunch stand-in cards. Not a balance value.
static func crunch_event_art(id: String) -> Dictionary:
	match id:
		"pantry":
			return {"id": id, "banner": "hunger", "tag": "hunger"}
		"ducts", "belt":
			return {"id": id, "banner": "dark", "tag": "dark"}
		"stacks":
			return {"id": id, "banner": "rat", "tag": "scrap"}
		"shopbelt":
			return {"id": id, "banner": "tools", "tag": "tools"}
		"dynamo":
			return {"id": id, "banner": "brownout", "tag": "dark"}
		_:
			return {"id": id}


static func audit() -> void:
	for path in textures().keys():
		load_texture(str(path))
	for path in fonts().keys():
		var cyrillic := str(path).ends_with("Oswald.ttf") or str(path).ends_with("PTMono-Regular.ttf")
		load_font(str(path), cyrillic)


static func textures() -> Dictionary:
	if not _textures.is_empty():
		return _textures
	_textures = {
		"res://assets/rooms/room_hydroponics.webp": preload("res://assets/rooms/room_hydroponics.webp"),
		"res://assets/rooms/room_generator.webp": preload("res://assets/rooms/room_generator.webp"),
		"res://assets/rooms/room_quarters.webp": preload("res://assets/rooms/room_quarters.webp"),
		"res://assets/rooms/room_air_filter.webp": preload("res://assets/rooms/room_air_filter.webp"),
		"res://assets/rooms/room_workshop.webp": preload("res://assets/rooms/room_workshop.webp"),
		"res://assets/rooms/room_infirmary.webp": preload("res://assets/rooms/room_infirmary.webp"),
		"res://assets/rooms/room_listening_post.webp": preload("res://assets/rooms/room_listening_post.webp"),
		"res://assets/rooms/room_listening_post_alt.webp": preload("res://assets/rooms/room_listening_post_alt.webp"),
		"res://assets/rooms/room_meeting_hall.webp": preload("res://assets/rooms/room_meeting_hall.webp"),
		"res://assets/rooms/room_platform.webp": preload("res://assets/rooms/room_platform.webp"),
		"res://assets/rooms/room_radio.webp": preload("res://assets/rooms/room_radio.webp"),
		"res://assets/cells/cell_rock.webp": preload("res://assets/cells/cell_rock.webp"),
		"res://assets/cells/cell_dug.webp": preload("res://assets/cells/cell_dug.webp"),
		"res://assets/cells/cell_construction.webp": preload("res://assets/cells/cell_construction.webp"),
		"res://assets/backdrop_station.webp": preload("res://assets/backdrop_station.webp"),
		"res://assets/hubs/hub_coney_island.webp": preload("res://assets/hubs/hub_coney_island.webp"),
		"res://assets/hubs/archive.webp": preload("res://assets/hubs/archive.webp"),
		"res://assets/hubs/central.webp": preload("res://assets/hubs/central.webp"),
		"res://assets/hubs/clocktower.webp": preload("res://assets/hubs/clocktower.webp"),
		"res://assets/hubs/dockyard.webp": preload("res://assets/hubs/dockyard.webp"),
		"res://assets/hubs/eastwater.webp": preload("res://assets/hubs/eastwater.webp"),
		"res://assets/hubs/foundry.webp": preload("res://assets/hubs/foundry.webp"),
		"res://assets/hubs/garden.webp": preload("res://assets/hubs/garden.webp"),
		"res://assets/hubs/harbor.webp": preload("res://assets/hubs/harbor.webp"),
		"res://assets/hubs/library.webp": preload("res://assets/hubs/library.webp"),
		"res://assets/hubs/market.webp": preload("res://assets/hubs/market.webp"),
		"res://assets/hubs/mill.webp": preload("res://assets/hubs/mill.webp"),
		"res://assets/hubs/observatory.webp": preload("res://assets/hubs/observatory.webp"),
		"res://assets/hubs/oldcommand.webp": preload("res://assets/hubs/oldcommand.webp"),
		"res://assets/hubs/plaza.webp": preload("res://assets/hubs/plaza.webp"),
		"res://assets/hubs/quarry.webp": preload("res://assets/hubs/quarry.webp"),
		"res://assets/hubs/riverside.webp": preload("res://assets/hubs/riverside.webp"),
		"res://assets/hubs/signal.webp": preload("res://assets/hubs/signal.webp"),
		"res://assets/hubs/vault.webp": preload("res://assets/hubs/vault.webp"),
		"res://assets/hubs/westfield.webp": preload("res://assets/hubs/westfield.webp"),
		"res://assets/figures/fig_standing.webp": preload("res://assets/figures/fig_standing.webp"),
		"res://assets/figures/fig_walking.webp": preload("res://assets/figures/fig_walking.webp"),
		"res://assets/figures/fig_working.webp": preload("res://assets/figures/fig_working.webp"),
		"res://assets/figures/fig_carrying.webp": preload("res://assets/figures/fig_carrying.webp"),
		"res://assets/figures/fig_kneeling.webp": preload("res://assets/figures/fig_kneeling.webp"),
		"res://assets/figures/fig_sitting.webp": preload("res://assets/figures/fig_sitting.webp"),
		"res://assets/portraits/portrait_01.webp": preload("res://assets/portraits/portrait_01.webp"),
		"res://assets/portraits/portrait_02.webp": preload("res://assets/portraits/portrait_02.webp"),
		"res://assets/portraits/portrait_03.webp": preload("res://assets/portraits/portrait_03.webp"),
		"res://assets/portraits/portrait_04.webp": preload("res://assets/portraits/portrait_04.webp"),
		"res://assets/portraits/portrait_05.webp": preload("res://assets/portraits/portrait_05.webp"),
		"res://assets/portraits/portrait_06.webp": preload("res://assets/portraits/portrait_06.webp"),
		"res://assets/portraits/portrait_07.webp": preload("res://assets/portraits/portrait_07.webp"),
		"res://assets/portraits/portrait_08.webp": preload("res://assets/portraits/portrait_08.webp"),
		"res://assets/portraits/portrait_09.webp": preload("res://assets/portraits/portrait_09.webp"),
		"res://assets/portraits/portrait_10.webp": preload("res://assets/portraits/portrait_10.webp"),
		"res://assets/portraits/portrait_11.webp": preload("res://assets/portraits/portrait_11.webp"),
		"res://assets/portraits/portrait_12.webp": preload("res://assets/portraits/portrait_12.webp"),
		"res://assets/portraits/portrait_13.webp": preload("res://assets/portraits/portrait_13.webp"),
		"res://assets/portraits/portrait_14.webp": preload("res://assets/portraits/portrait_14.webp"),
		"res://assets/portraits/portrait_15.webp": preload("res://assets/portraits/portrait_15.webp"),
		"res://assets/portraits/portrait_16.webp": preload("res://assets/portraits/portrait_16.webp"),
		"res://assets/portraits/portrait_17.webp": preload("res://assets/portraits/portrait_17.webp"),
		"res://assets/portraits/portrait_18.webp": preload("res://assets/portraits/portrait_18.webp"),
		"res://assets/portraits/portrait_19.webp": preload("res://assets/portraits/portrait_19.webp"),
		"res://assets/portraits/portrait_20.webp": preload("res://assets/portraits/portrait_20.webp"),
		"res://assets/portraits/portrait_21.webp": preload("res://assets/portraits/portrait_21.webp"),
		"res://assets/portraits/portrait_22.webp": preload("res://assets/portraits/portrait_22.webp"),
		"res://assets/portraits/portrait_23.webp": preload("res://assets/portraits/portrait_23.webp"),
		"res://assets/portraits/portrait_24.webp": preload("res://assets/portraits/portrait_24.webp"),
		"res://assets/portraits/portrait_25.webp": preload("res://assets/portraits/portrait_25.webp"),
		"res://assets/portraits/portrait_26.webp": preload("res://assets/portraits/portrait_26.webp"),
		"res://assets/portraits/portrait_27.webp": preload("res://assets/portraits/portrait_27.webp"),
		"res://assets/portraits/portrait_28.webp": preload("res://assets/portraits/portrait_28.webp"),
		"res://assets/events/brownout.webp": preload("res://assets/events/brownout.webp"),
		"res://assets/events/cough.webp": preload("res://assets/events/cough.webp"),
		"res://assets/events/expedition.webp": preload("res://assets/events/expedition.webp"),
		"res://assets/events/flood.webp": preload("res://assets/events/flood.webp"),
		"res://assets/events/headphones.webp": preload("res://assets/events/headphones.webp"),
		"res://assets/events/letter.webp": preload("res://assets/events/letter.webp"),
		"res://assets/events/moles.webp": preload("res://assets/events/moles.webp"),
		"res://assets/events/preacher.webp": preload("res://assets/events/preacher.webp"),
		"res://assets/events/rat.webp": preload("res://assets/events/rat.webp"),
		"res://assets/events/ration.webp": preload("res://assets/events/ration.webp"),
		"res://assets/events/refugees.webp": preload("res://assets/events/refugees.webp"),
		"res://assets/events/showtime.webp": preload("res://assets/events/showtime.webp"),
		"res://assets/events/toll.webp": preload("res://assets/events/toll.webp"),
		"res://assets/events/vote.webp": preload("res://assets/events/vote.webp"),
		"res://assets/events/chapel.webp": preload("res://assets/events/chapel.webp"),
		"res://assets/events/dark.webp": preload("res://assets/events/dark.webp"),
		"res://assets/events/hunger.webp": preload("res://assets/events/hunger.webp"),
		"res://assets/events/labor.webp": preload("res://assets/events/labor.webp"),
		"res://assets/events/market_next.webp": preload("res://assets/events/market_next.webp"),
		"res://assets/events/quarrel.webp": preload("res://assets/events/quarrel.webp"),
		"res://assets/events/scrap.webp": preload("res://assets/events/scrap.webp"),
		"res://assets/events/sleep.webp": preload("res://assets/events/sleep.webp"),
		"res://assets/events/tools.webp": preload("res://assets/events/tools.webp"),
		"res://assets/events/lamps.webp": preload("res://assets/events/lamps.webp"),
		"res://assets/events/rumble.webp": preload("res://assets/events/rumble.webp"),
		"res://assets/events/static.webp": preload("res://assets/events/static.webp"),
		"res://assets/events/smuggler.webp": preload("res://assets/events/smuggler.webp"),
		"res://assets/events/market_food.webp": preload("res://assets/events/market_food.webp"),
		"res://assets/events/desertion.webp": preload("res://assets/events/desertion.webp"),
		"res://assets/events/clog.webp": preload("res://assets/events/clog.webp"),
		"res://assets/events/knock.webp": preload("res://assets/events/knock.webp"),
		"res://assets/events/loan.webp": preload("res://assets/events/loan.webp"),
		"res://assets/events/diesel.webp": preload("res://assets/events/diesel.webp"),
		"res://assets/events/armband.webp": preload("res://assets/events/armband.webp"),
		"res://assets/events/desertion_next.webp": preload("res://assets/events/desertion_next.webp"),
		"res://assets/events/lamps_next.webp": preload("res://assets/events/lamps_next.webp"),
		"res://assets/events/preacher_next.webp": preload("res://assets/events/preacher_next.webp"),
		"res://assets/events/refugees_next.webp": preload("res://assets/events/refugees_next.webp"),
		"res://assets/events/rumble_next.webp": preload("res://assets/events/rumble_next.webp"),
		"res://assets/events/smuggler_next.webp": preload("res://assets/events/smuggler_next.webp"),
		"res://assets/icons/map/rumor.png": preload("res://assets/icons/map/rumor.png"),
		"res://assets/icons/map/rumor_24.png": preload("res://assets/icons/map/rumor_24.png"),
		"res://assets/icons/map/gift.png": preload("res://assets/icons/map/gift.png"),
		"res://assets/icons/map/gift_24.png": preload("res://assets/icons/map/gift_24.png"),
		"res://assets/icons/map/aid.png": preload("res://assets/icons/map/aid.png"),
		"res://assets/icons/map/aid_24.png": preload("res://assets/icons/map/aid_24.png"),
		"res://assets/icons/map/pay.png": preload("res://assets/icons/map/pay.png"),
		"res://assets/icons/map/pay_24.png": preload("res://assets/icons/map/pay_24.png"),
		"res://assets/icons/status/rumor.png": preload("res://assets/icons/status/rumor.png"),
		"res://assets/icons/status/rumor_24.png": preload("res://assets/icons/status/rumor_24.png"),
		"res://assets/icons/status/away_boots.png": preload("res://assets/icons/status/away_boots.png"),
		"res://assets/icons/status/away_boots_24.png": preload("res://assets/icons/status/away_boots_24.png"),
		"res://assets/icons/map/away_boots.png": preload("res://assets/icons/map/away_boots.png"),
		"res://assets/icons/map/away_boots_24.png": preload("res://assets/icons/map/away_boots_24.png"),
		## P48. Badge size is 22px, so icon_texture loads sick_cot_24 before the 256 plate.
		"res://assets/icons/status/sick_cot.png": preload("res://assets/icons/status/sick_cot.png"),
		"res://assets/icons/status/sick_cot_24.png": preload("res://assets/icons/status/sick_cot_24.png"),
		"res://assets/icons/map/sick_cot.png": preload("res://assets/icons/map/sick_cot.png"),
		"res://assets/icons/map/sick_cot_24.png": preload("res://assets/icons/map/sick_cot_24.png"),
		"res://assets/icons/status/gift.png": preload("res://assets/icons/status/gift.png"),
		"res://assets/icons/status/gift_24.png": preload("res://assets/icons/status/gift_24.png"),
		"res://assets/icons/status/aid.png": preload("res://assets/icons/status/aid.png"),
		"res://assets/icons/status/aid_24.png": preload("res://assets/icons/status/aid_24.png"),
		"res://assets/icons/status/pay.png": preload("res://assets/icons/status/pay.png"),
		"res://assets/icons/status/pay_24.png": preload("res://assets/icons/status/pay_24.png"),
		"res://assets/map/chips/intent_bought.webp": preload("res://assets/map/chips/intent_bought.webp"),
		"res://assets/map/chips/intent_bought_tint.webp": preload("res://assets/map/chips/intent_bought_tint.webp"),
		"res://assets/map/chips/intent_marched.webp": preload("res://assets/map/chips/intent_marched.webp"),
		"res://assets/map/chips/intent_marched_tint.webp": preload("res://assets/map/chips/intent_marched_tint.webp"),
		"res://assets/map/chips/intent_held.webp": preload("res://assets/map/chips/intent_held.webp"),
		"res://assets/map/chips/intent_held_tint.webp": preload("res://assets/map/chips/intent_held_tint.webp"),
		## Spare: no preach verb in the sim. Registered so the plate is in the export.
		"res://assets/map/chips/intent_preached.webp": preload("res://assets/map/chips/intent_preached.webp"),
		"res://assets/map/chips/intent_preached_tint.webp": preload("res://assets/map/chips/intent_preached_tint.webp"),
		"res://assets/map/stamps/stamp_gift.webp": preload("res://assets/map/stamps/stamp_gift.webp"),
		"res://assets/map/stamps/stamp_aid.webp": preload("res://assets/map/stamps/stamp_aid.webp"),
		"res://assets/map/stamps/stamp_pay.webp": preload("res://assets/map/stamps/stamp_pay.webp"),
		"res://assets/events/two_portions.webp": preload("res://assets/events/two_portions.webp"),
		"res://assets/events/breathers_price.webp": preload("res://assets/events/breathers_price.webp"),
		"res://assets/events/the_list.webp": preload("res://assets/events/the_list.webp"),
		"res://assets/overlays/dilemma_frame.webp": preload("res://assets/overlays/dilemma_frame.webp"),
		"res://assets/events/knock_next.webp": preload("res://assets/events/knock_next.webp"),
		"res://assets/events/knock_last.webp": preload("res://assets/events/knock_last.webp"),
		"res://assets/events/loan_next.webp": preload("res://assets/events/loan_next.webp"),
		"res://assets/events/toll_next.webp": preload("res://assets/events/toll_next.webp"),
		"res://assets/events/toll_last.webp": preload("res://assets/events/toll_last.webp"),
		"res://assets/events/stores_turn.webp": preload("res://assets/events/stores_turn.webp"),
		"res://assets/events/ration_coat.webp": preload("res://assets/events/ration_coat.webp"),
		"res://assets/overlays/room_probe.webp": preload("res://assets/overlays/room_probe.webp"),
		"res://assets/overlays/room_offline.webp": preload("res://assets/overlays/room_offline.webp"),
		"res://assets/overlays/room_offline_256.webp": preload("res://assets/overlays/room_offline_256.webp"),
		"res://assets/map/chips/wired.webp": preload("res://assets/map/chips/wired.webp"),
		"res://assets/map/chips/wired_tint.webp": preload("res://assets/map/chips/wired_tint.webp"),
		"res://assets/map/chips/probing.webp": preload("res://assets/map/chips/probing.webp"),
		"res://assets/map/chips/probing_tint.webp": preload("res://assets/map/chips/probing_tint.webp"),
		"res://assets/icons/rooms/listening_post.png": preload("res://assets/icons/rooms/listening_post.png"),
		"res://assets/icons/status/listen.png": preload("res://assets/icons/status/listen.png"),
		"res://assets/icons/status/listen_24.png": preload("res://assets/icons/status/listen_24.png"),
		"res://assets/icons/status/probe.png": preload("res://assets/icons/status/probe.png"),
		"res://assets/icons/status/probe_24.png": preload("res://assets/icons/status/probe_24.png"),
		"res://assets/icons/status/tap.png": preload("res://assets/icons/status/tap.png"),
		"res://assets/icons/status/tap_24.png": preload("res://assets/icons/status/tap_24.png"),
		"res://assets/icons/status/probing.png": preload("res://assets/icons/status/probing.png"),
		"res://assets/icons/status/probing_24.png": preload("res://assets/icons/status/probing_24.png"),
		"res://assets/icons/ui/probing.png": preload("res://assets/icons/ui/probing.png"),
		"res://assets/icons/ui/probing_24.png": preload("res://assets/icons/ui/probing_24.png"),
		"res://assets/icons/status/blown.png": preload("res://assets/icons/status/blown.png"),
		"res://assets/icons/status/blown_24.png": preload("res://assets/icons/status/blown_24.png"),
		"res://assets/icons/map/blown.png": preload("res://assets/icons/map/blown.png"),
		"res://assets/icons/map/blown_24.png": preload("res://assets/icons/map/blown_24.png"),
		"res://assets/overlays/blown_flash.webp": preload("res://assets/overlays/blown_flash.webp"),
		"res://assets/ui/salvage_board_panel.webp": preload("res://assets/ui/salvage_board_panel.webp"),
		"res://assets/ui/salvage_board_empty.webp": preload("res://assets/ui/salvage_board_empty.webp"),
		"res://assets/ui/salvage_board_no_blueprint.webp": preload("res://assets/ui/salvage_board_no_blueprint.webp"),
		"res://assets/overlays/fitted_flash.webp": preload("res://assets/overlays/fitted_flash.webp"),
		"res://assets/icons/ui/salvage.png": preload("res://assets/icons/ui/salvage.png"),
		"res://assets/icons/ui/salvage_24.png": preload("res://assets/icons/ui/salvage_24.png"),
		"res://assets/icons/ui/blueprint.png": preload("res://assets/icons/ui/blueprint.png"),
		"res://assets/icons/ui/blueprint_24.png": preload("res://assets/icons/ui/blueprint_24.png"),
		"res://assets/icons/ui/strip_scrap.png": preload("res://assets/icons/ui/strip_scrap.png"),
		"res://assets/icons/ui/strip_scrap_24.png": preload("res://assets/icons/ui/strip_scrap_24.png"),
		"res://assets/icons/ui/fitted.png": preload("res://assets/icons/ui/fitted.png"),
		"res://assets/icons/ui/locked_blueprint.png": preload("res://assets/icons/ui/locked_blueprint.png"),
		"res://assets/icons/ui/tier0.png": preload("res://assets/icons/ui/tier0.png"),
		"res://assets/icons/ui/tier1.png": preload("res://assets/icons/ui/tier1.png"),
		"res://assets/icons/ui/tier2.png": preload("res://assets/icons/ui/tier2.png"),
		"res://assets/icons/ui/salvage_open.png": preload("res://assets/icons/ui/salvage_open.png"),
		"res://assets/icons/ui/salvage_open_24.png": preload("res://assets/icons/ui/salvage_open_24.png"),
		"res://assets/icons/ui/blueprint_ready.png": preload("res://assets/icons/ui/blueprint_ready.png"),
		"res://assets/icons/ui/blueprint_ready_24.png": preload("res://assets/icons/ui/blueprint_ready_24.png"),
		"res://assets/icons/status/salvage_open.png": preload("res://assets/icons/status/salvage_open.png"),
		"res://assets/icons/status/salvage_open_24.png": preload("res://assets/icons/status/salvage_open_24.png"),
		"res://assets/icons/status/blueprint_ready.png": preload("res://assets/icons/status/blueprint_ready.png"),
		"res://assets/icons/status/blueprint_ready_24.png": preload("res://assets/icons/status/blueprint_ready_24.png"),
		"res://assets/props/pile_rubble.webp": preload("res://assets/props/pile_rubble.webp"),
		"res://assets/props/pile_scrap.webp": preload("res://assets/props/pile_scrap.webp"),
		"res://assets/props/pile_coal.webp": preload("res://assets/props/pile_coal.webp"),
		"res://assets/props/pile_rubble_512.webp": preload("res://assets/props/pile_rubble_512.webp"),
		"res://assets/props/pile_scrap_512.webp": preload("res://assets/props/pile_scrap_512.webp"),
		"res://assets/props/pile_coal_512.webp": preload("res://assets/props/pile_coal_512.webp"),
		"res://assets/overlays/clear_dust.webp": preload("res://assets/overlays/clear_dust.webp"),
		## P42 props. No props/common gameplay hook; preload is the export registration.
		"res://assets/props/common/prop_infirmary_tray.webp": preload("res://assets/props/common/prop_infirmary_tray.webp"),
		"res://assets/props/common/prop_listening_cans.webp": preload("res://assets/props/common/prop_listening_cans.webp"),
		## P49. Draws ask at 24px, so the hand-pixel plate is the one in the export. The 256 is the fallback plate.
		"res://assets/icons/status/need_tick_24.png": preload("res://assets/icons/status/need_tick_24.png"),
		"res://assets/icons/map/need_tick_24.png": preload("res://assets/icons/map/need_tick_24.png"),
		"res://assets/icons/status/need_tick.png": preload("res://assets/icons/status/need_tick.png"),
		"res://assets/icons/map/need_tick.png": preload("res://assets/icons/map/need_tick.png"),

	}
	return _textures


## Cell overlays for yard piles. The 210-wide set is the one drawn on a cell; _512 is the room-scale sit.
const PILE_ART := {
	"rubble": "res://assets/props/pile_rubble.webp",
	"scrap": "res://assets/props/pile_scrap.webp",
	"coal": "res://assets/props/pile_coal.webp",
}
const PILE_ART_LARGE := {
	"rubble": "res://assets/props/pile_rubble_512.webp",
	"scrap": "res://assets/props/pile_scrap_512.webp",
	"coal": "res://assets/props/pile_coal_512.webp",
}
const CLEAR_DUST := "res://assets/overlays/clear_dust.webp"


static func pile_texture(kind: String, large: bool = false) -> Texture2D:
	var path := str((PILE_ART_LARGE if large else PILE_ART).get(kind, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load_texture(path)


static func clear_dust_texture() -> Texture2D:
	if not ResourceLoader.exists(CLEAR_DUST):
		return null
	return load_texture(CLEAR_DUST)


static func adopt_icons() -> void:
	var src := "res://incoming-art/icons"
	if DirAccess.open(src) == null:
		return
	_copy_tree(src, "res://assets/icons")


## Rival result chip. `tinted` is the white plate meant to take a faction colour.
## intent_preached is registered and loadable; nothing in the sim asks for it.
static func map_chip(name: String, tinted: bool = false) -> Texture2D:
	if name == "":
		return null
	var path := "res://assets/map/chips/%s%s.webp" % [name, "_tint" if tinted else ""]
	return load_texture(path)


## Pin stamp for a queued or just-resolved Gift, Aid or Pay.
static func map_stamp(kind: String) -> Texture2D:
	if kind != "gift" and kind != "aid" and kind != "pay":
		return null
	return load_texture("res://assets/map/stamps/stamp_%s.webp" % kind)


static func icon_texture(kind: String, px: float = 64.0) -> Texture2D:
	var small := px <= 32.0
	var key := kind + ("#24" if small else "")
	if _icons.has(key):
		var cached = _icons[key]
		return cached if cached is Texture2D else null
	var found: Texture2D = null
	var names := _icon_names(kind)
	if small:
		for name in names:
			found = _load_icon(name + "_24")
			if found != null:
				break
	if found == null:
		for name in names:
			found = _load_icon(name)
			if found != null:
				break
	_icons[key] = found if found != null else false
	return found


static func _icon_names(kind: String) -> PackedStringArray:
	match kind:
		"lock":
			return PackedStringArray(["locked", "lock"])
		"burn":
			return PackedStringArray(["burn_salvage", "burn"])
		"clock":
			return PackedStringArray(["week", "clock"])
		"buy":
			return PackedStringArray(["propaganda", "buy"])
		"demand":
			return PackedStringArray(["ultimatum", "demand"])
		"secure", "move":
			return PackedStringArray(["squad", kind])
		"expedition":
			return PackedStringArray(["artifact", "expedition"])
		"dig":
			return PackedStringArray(["dig", "workshop"])
		"hold":
			return PackedStringArray(["warning", "hold"])
		"wired", "wired_tint", "probing", "probing_tint":
			return PackedStringArray([kind])
		## P42. _load_icon searches status/ before map/, so the dawn chip takes the status glyph.
		## The _24 pair is preferred at 24px. A missing file still leaves the paper chip as text.
		"noise_rail":
			return PackedStringArray(["noise_rail"])
		## P47. status/ is searched before map/. The hand-pixel _24 is the pin scrap.
		"leaflet_chip":
			return PackedStringArray(["leaflet_chip"])
		## P49. Same search order. Callers pass 24 so the hand-pixel plate wins over the 256.
		"need_tick":
			return PackedStringArray(["need_tick"])
		_:
			return PackedStringArray([kind])


static func _load_icon(name: String) -> Texture2D:
	var folders := ["ui/", "", "resources/", "actions/", "rooms/", "status/", "map/", "factions/"]
	for folder in folders:
		for ext in ["webp", "png"]:
			var path := "res://assets/icons/%s%s.%s" % [folder, name, ext]
			if not ResourceLoader.exists(path):
				continue
			var tex := load_texture(path)
			if tex == null:
				continue
			return _with_mipmaps(tex)
	return null


static func _with_mipmaps(tex: Texture2D) -> Texture2D:
	var image := tex.get_image()
	if image == null:
		return tex
	if image.get_width() > 1 and image.get_height() > 1:
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _copy_tree(src: String, dst: String) -> void:
	var dir := DirAccess.open(src)
	if dir == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst))
	for name in dir.get_directories():
		if str(name).begins_with("."):
			continue
		_copy_tree(src.path_join(str(name)), dst.path_join(str(name)))
	for name in dir.get_files():
		if str(name).begins_with("."):
			continue
		var from := ProjectSettings.globalize_path(src.path_join(str(name)))
		var to := ProjectSettings.globalize_path(dst.path_join(str(name)))
		DirAccess.copy_absolute(from, to)


static func fonts() -> Dictionary:
	if not _fonts.is_empty():
		return _fonts
	_fonts = {
		"res://assets/fonts/CourierPrime-Regular.ttf": preload("res://assets/fonts/CourierPrime-Regular.ttf"),
		"res://assets/fonts/BigShouldersDisplay.ttf": preload("res://assets/fonts/BigShouldersDisplay.ttf"),
		"res://assets/fonts/BigShouldersDisplay-700.woff2": preload("res://assets/fonts/BigShouldersDisplay-700.woff2"),
		"res://assets/fonts/Oswald.ttf": preload("res://assets/fonts/Oswald.ttf"),
		"res://assets/fonts/PTMono-Regular.ttf": preload("res://assets/fonts/PTMono-Regular.ttf"),
	}
	return _fonts
