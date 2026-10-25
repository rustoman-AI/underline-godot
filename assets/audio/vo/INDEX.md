# Voiceover index

Lines are data, not code: every JSON file in `data/vo/` lists lines with `id`, `type`, `trigger`, `en`, `ru`, `audio_en`, `audio_ru`. The game shows the text for the current language and plays that language's audio file when it exists here; a missing file means text only.

`data/vo/underline_vo.json` is generated from the script pack (`tools/import_vo.gd`). `data/vo/cable_radio.json` holds hand-written radio bulletins. To add a line, add a row to either file (or a new JSON file in `data/vo/`) and drop the `.ogg` files here with the names given in `audio_en` / `audio_ru`.

| Type | Extra field | When it plays | Bus |
| --- | --- | --- | --- |
| `story` | `cast`: resident id (`ruth`) or Coney cast id (`salty_maggie`) | First time that resident's dossier opens in a playthrough, then on "Replay story". Fades out when the dossier closes. The story is marked heard and its text revealed after 90% playback; closing early leaves it unheard. Reopening after an interrupted first play offers manual playback. | Voice (follows SFX) |
| `radio` | `mood`: `anxious`, `neutral`, `light`, `funny`, `positive` | One bulletin every 1-2 weeks (Settings) once a radio room is built. No repeats until all have played; anxious ones are likelier under high discontent, low food, low hope or a season. | Radio |
| `event` | `event`: event id; optional `choice` | Right after that event's card resolves. A line with a matching `choice` wins over one without. | Voice (follows SFX) |
| `system` | `condition` | When the sim raises that condition (below), once no card is open. Same condition stays quiet for 6 weeks. | Voice (follows SFX) |

Conditions the sim raises: `food_critical` (food under one week of meals), `power_restored` (power back after a shortfall or generator fault), `resident_joined` (population grew), `resident_lost` (deaths), `caravan_arrived` (Exchange trade or a station deal), `disease_contained` (last sick resident well), `tunnel_warning` (flood season ahead), `morale_high` (hope reaches 75), `season_<id>_soon` and `season_<id>` (flood, cold, cough). Confirmed actions also look up `<kind>_<id>` then `<kind>`, e.g. `law_curfew`, `rally`, `pump`.

## Files present (EN + RU each)

| Batch | Lines |
| --- | --- |
| Pilot | `jonah_story`, `inez_story`, `mara_story`, `radio_news_001` |
| Phase 1 | `old_man_coney_story`, `salty_maggie_story`, `bait_story`, `barnum_story`, `sylvia_story`, `radio_news_002` to `radio_news_010` |
| Phase 2 | resident stories: `ruth`, `benny`, `ellis`, `samira`, `owen`, `lila`, `pete`, `june`, `hal`, `nora`, `vic`, `ada`, `chris`, `mina`, `rob`, `tess`, `paul`, `kim`, `drew`, `ann`, `leo`, `fran` (`<id>_story`) |
| Phase 3 | event resolves `event_<id>_resolve` (lamps, refugees, quarrel, smuggler, rumble, static, desertion, cough) and system lines `sys_<condition>` (all 8) |
| Radio pilot 04 | `radio_flood_watch`, `radio_red_scarf`, `radio_purple_notice`, `radio_knock_twice` (from `data/vo/cable_radio.json`), delivered normalized to -23 LUFS. Not auditioned; ear review deferred until funding. |
| Rewording 01 (17 Oct) | Re-recorded with the new wording of the literal translation pass (`docs/briefs/muse_vo_rewording.txt`): `event_desertion_resolve_ru`, `sys_caravan_arrived_ru`, `radio_news_002_ru` (announcer Daniel `onwK4e9ZLuTAKqWW03F9`) and six leader files (`lead_depot_band_useful_en`, `lead_exchange_band_pact_en`, `lead_exchange_trade_en`, `lead_exchange_trade_ru`, `lead_black_flag_accepted_ru`, `lead_directorate_band_wary_ru`). Take 2 of two installed (stability 0.65, flatter), same voices, eleven_v4. Delivery in `incoming-audio/vo-rewording-01/`; the replaced originals and installed files sit in `replaced_20261017/` inside each `_originals_*` folder. Passed technical QC; not auditioned. |

Radio count: 14 of 26 bulletins voiced (`radio_news_001` to `radio_news_010` and pilot 04); 12 still text only, all in `data/vo/cable_radio.json`.

## Leader lines

Leader lines are voiced EN/RU: 55 lines per language, 110 files, named `lead_<faction>_<key>_<lang>.ogg` with keys `first_contact`, `band_hostile`, `band_cold`, `band_wary`, `band_useful`, `band_pact`, `territory`, `trade`, `pitch`, `accepted`, `declined`. They are not rows in `data/vo/`: the text is `data/leader_lines.json` and the game plays the file whose key matches the line on screen (the audience card's opening or band line, the pitch after Hear them out, the reply after accepting or refusing, and territory and trade lines in order reports), on the Voice bus, one at a time, without subtitles. A missing file plays nothing. Generated with ElevenLabs (eleven_v4), normalized to -23 LUFS. Not auditioned; ear review deferred until funding.

| Leader | Faction | Voice | Voice ID |
| --- | --- | --- | --- |
| Bernie Shaw | depot | Matthew Schmitz | Q4oILuo4P8VeXtE6FMLI |
| Lionel Abelard | directorate | Ryan T | KrzS8SPOhDLAQ1kPsDxL |
| Dorothy Chen | synod | Annabel | tiLGT9eftokjCKvXtgmt |
| Marcel Toussaint | exchange | Adam | mwSotaX4JZvDBLkikIUZ |
| Niki Ortega | black_flag | Oraya | nRQT5qZlz63KgulRymWq |

## Loudness

Stories are normalized to -23 LUFS integrated, true peak under -1.5 dBTP, by `.tools/normalize_vo.ps1` (two-pass ffmpeg loudnorm from the untouched originals in `_originals_story/`, which git and Godot ignore). Event and system lines were also normalized in a later pass, targeting -23 LUFS with a -2.5 dBTP limiter target to allow for Vorbis overshoot; untouched backups are in `_originals_short/`. Radio is normalized the same way to -23 LUFS with a -2.5 dBTP limiter target (radio_news_003_ru and 010_ru at -3.0 to stay under -2.5 after Vorbis); the delivered mix (-22.3 to -20.7 LUFS) is kept in `_originals_radio/`, ignored by git and Godot. Measured after: -23.1 to -22.6 LUFS, true peak at most -2.5 dBTP. `.tools/measure_vo.ps1` prints min/median/max per group. Leader lines use the same two-pass loudnorm to -23 LUFS with a -2.5 dBTP ceiling (`.tools/normalize_leaders.ps1`); a short line that lands outside 0.4 dB of the target or over the ceiling after Vorbis is encoded again from the original with the target moved by the miss. Gain only, no EQ, though the five voices are different people. Delivered files (-31.0 to -17.2 LUFS) are kept in `_originals_leaders/`, ignored by git and Godot. Measured after: -23.3 to -22.6 LUFS (spread 0.7 dB), true peak at most -2.6 dBTP; `.tools/measure_leaders.ps1` prints min/median/max per faction.

Event files may arrive as `event_<id>_resolve_resolve_<lang>.ogg` (the index spreadsheet's spelling); the game accepts that as well as `event_<id>_resolve_<lang>.ogg` from `underline_vo.json`.

Russian subtitles differ from the recorded wording where the script used em dashes; the rewrites live in `tools/vo_ru_fixes.json` and are applied by the importer.
