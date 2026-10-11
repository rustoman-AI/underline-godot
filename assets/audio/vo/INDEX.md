# Voiceover index

Lines are data, not code: every JSON file in `data/vo/` lists lines with `id`, `type`, `trigger`, `en`, `ru`, `audio_en`, `audio_ru`. The game shows the text for the current language and plays that language's audio file when it exists here; a missing file means text only.

`data/vo/underline_vo.json` is generated from the script pack (`tools/import_vo.gd`). `data/vo/cable_radio.json` holds hand-written radio bulletins. To add a line, add a row to either file (or a new JSON file in `data/vo/`) and drop the `.ogg` files here with the names given in `audio_en` / `audio_ru`.

| Type | Extra field | When it plays | Bus |
| --- | --- | --- | --- |
| `story` | `cast`: resident id (`ruth`) or Coney cast id (`salty_maggie`) | First time that resident's dossier opens in a playthrough, then on "Replay story". Fades out when the dossier closes. The text is shown in the dossier. | Voice (follows SFX) |
| `radio` | `mood`: `anxious`, `neutral`, `light`, `funny`, `positive` | One bulletin every 1-2 weeks (Settings) once a radio room is built. No repeats until all have played; anxious ones are likelier under high discontent, low food, low hope or a season. | Radio |
| `event` | `event`: event id; optional `choice` | Right after that event's card resolves. A line with a matching `choice` wins over one without. | Voice (follows SFX) |
| `system` | `condition` | When the sim raises that condition (below), once no card is open. Same condition stays quiet for 6 weeks. | Voice (follows SFX) |

Conditions the sim raises: `food_critical` (food under one week of meals), `power_restored` (power back after a shortfall or generator fault), `resident_joined` (population grew), `resident_lost` (deaths), `caravan_arrived` (Exchange trade or a station deal), `disease_contained` (last sick resident well), `tunnel_warning` (flood season ahead), `morale_high` (hope reaches 75), `season_<id>_soon` and `season_<id>` (flood, cold, cough). Confirmed actions also look up `<kind>_<id>` then `<kind>`, e.g. `law_curfew`, `rally`, `pump`.

## Files present

| File | Length |
| --- | --- |
| `inez_story_en.ogg` | 72.8 s |
| `inez_story_ru.ogg` | 77.5 s |
| `jonah_story_en.ogg` | 63.2 s |
| `jonah_story_ru.ogg` | 64.2 s |
| `mara_story_en.ogg` | 66.5 s |
| `mara_story_ru.ogg` | 63.2 s |
| `radio_news_001_en.ogg` | 19.2 s |
| `radio_news_001_ru.ogg` | 19.0 s |

The index spreadsheet names event files `event_<id>_resolve_resolve_<lang>.ogg`; the game expects `event_<id>_resolve_<lang>.ogg` as in `underline_vo.json`.
