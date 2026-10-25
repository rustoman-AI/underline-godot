# Old file -> new file mapping (for the lead / Cursor integration)

"Current file" assignments marked (?) come from the audit's filename inference —
verify against ui/station.gd and sim audio code before switching.

| Current file (assets/audio/) | New file(s) (assets/audio/new/) | Notes |
|---|---|---|
| click.ogg | click_01.ogg, click_02.ogg, click_03.ogg | 3 pitch/material variants; pick randomly per click |
| confirm.ogg | confirm.ogg | 1:1 |
| card.ogg | card_open.ogg, card_open_02.ogg, card_open_03.ogg | 3 variants; use for event card open and new-week card |
| built.ogg | build_done.ogg | rename on integration |
| error.ogg | error.ogg | 1:1 |
| thud.ogg (?) | end_turn.ogg | audit guess: thud was End turn; dig has its own file now |
| thud.ogg (?) | dig.ogg | if thud was shared, split: end_turn for End turn, dig for digging |
| whoosh.ogg (?) | dossier_open.ogg, audience_open.ogg | whoosh was wrong for both; dossier = paper, audience = heavy door |
| drip.ogg | drip.ogg | 1:1 (sparse drops; integrated -25 LUFS by design, drops peak -2.4 dBTP) |
| ambient.ogg | ambient.ogg | 1:1, 30 s seamless loop |
| radio.ogg | radio.ogg | 1:1, 10 s static bed |
| drone.ogg (?) | menu_tone.ogg | audit guess: drone was the menu/loading bed; 20 s seamless loop |
| rooms/*.ogg | room_platform/quarters/hydroponics/air_filter/generator/workshop/infirmary/meeting_hall/radio.ogg | 9 loops, 20 s each, -23 LUFS |
| hover.ogg (muted) | — | stays muted; no replacement |

New concepts with no current file: dossier_tab.ogg, new_week.ogg, upgrade.ogg, map_click.ogg.
