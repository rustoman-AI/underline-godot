# Voiceover index

Every line is `<base>_<lang>.ogg` in this folder, `lang` is `en` or `ru`. The game plays the file for the current language and stays silent when it is missing.

| Base | When it plays | Bus |
| --- | --- | --- |
| `<cast_id>_story` | First time the resident's dossier opens in a playthrough, then on "Replay story". `cast_id` is the resident id (`inez`, `jonah`, `mara`) or the Coney cast id (`salty_maggie`...). | Voice (follows SFX) |
| `radio_<item_id>` | Cable radio item `<item_id>` from `data/radio.json`, one item per week once a radio room is built. | Radio |
| `event_<event_id>_<choice_id>` | Right after that event choice resolves. | Voice (follows SFX) |
| `event_<event_id>` | Any choice of that event, when no choice-specific line exists. | Voice (follows SFX) |
| `system_<kind>_<id>` | Right after a confirmed action, e.g. `system_law_curfew`. | Voice (follows SFX) |
| `system_<kind>` | Any action of that kind: `law`, `repeal`, `pump`, `quarantine`, `rally`, `burn`, `upgrade`, `demolish`. | Voice (follows SFX) |

## Files in the pilot pack

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

`radio_news_001` has no transcript yet, so its radio card shows a generic caption. Put the text in `data/radio.json` under `news_001`.
