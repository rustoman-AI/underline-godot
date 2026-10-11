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

Still text only: the hand-written bulletins in `data/vo/cable_radio.json`.

## Loudness

Stories are normalized to -23 LUFS integrated, true peak under -1.5 dBTP, by `.tools/normalize_vo.ps1` (two-pass ffmpeg loudnorm from the untouched originals in `_originals_story/`, which git and Godot ignore). Event and system lines were also normalized in a later pass, targeting -23 LUFS with a -2.5 dBTP limiter target to allow for Vorbis overshoot; untouched backups are in `_originals_short/`. Radio keeps its delivered mix (measured -22.3 to -20.7 LUFS). `.tools/measure_vo.ps1` prints min/median/max per group.

Event files may arrive as `event_<id>_resolve_resolve_<lang>.ogg` (the index spreadsheet's spelling); the game accepts that as well as `event_<id>_resolve_<lang>.ogg` from `underline_vo.json`.

Russian subtitles differ from the recorded wording where the script used em dashes; the rewrites live in `tools/vo_ru_fixes.json` and are applied by the importer.
