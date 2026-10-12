# Журнал изменений Underline

Генерируется из git командой `node .tools/changelog.js`. Блок «Этапы» правится вручную в этом скрипте.

Коммитов: 165. Первый: 2026-10-02. Последний: 2026-10-12 4283f1b.

## Этапы

- **2026-10-02.** Старт: симуляция станции, разрез, экономика, GDD v2
- **2026-10-10.** Карта сети (стол надзирателя), проверки событий, меню и сохранения, экспорт
- **2026-10-11.** Лидеры и аудиенции, озвучка 112 + 110 строк, сюжетный костяк (осколки, бункеры, 8 концовок), первая закрытая сборка
- **2026-10-12.** Ночной QA, портреты по полу и досье, вторая и третья сборки (0.1.0-playtest2, 3, 4), первый внешний отзыв

## Сборки для плейтеста

- 2026-10-12 `66d0cab` Playtest build: preset, build info, how-to card, local log and report, tester docs
- 2026-10-12 `27b0b52` Playtest build version 0.1.0-playtest2
- 2026-10-12 `6dbc2a5` Playtest build version 0.1.0-playtest3

## По дням (новое сверху)

### 2026-10-12 (46)

- `4283f1b` Map size: network map fills the window
- `4473c26` Docs: Cursor brief for map size
- `12e14d2` Docs: playtest4 build recorded
- `60a4d4a` Docs: park toast layering and workshop storage notes
- `3afc7a4` Numbers clarity: weekly in and out on resource cards
- `191f700` Docs: park intro idea
- `b743898` Docs: F22 map size raised by a second tester
- `41f9414` Docs: numbers clarity brief is go
- `c2641d8` Docs: draft Cursor brief for numbers clarity (F28, F29, F34)
- `1540f29` Docs: log PDF playtest feedback F23-F34
- `cc0387e` Docs: log Taiga card F22 (station map scale) and park it
- `fc31ffe` Docs: park stale quiet-sound hint wording
- `80723b3` Docs: changelog after playtest3 clarity pass
- `5ae2e12` Settings and Credits as framed cards over a dim
- `f039afb` Clarity: explain overcrowding on the people line and ticker
- `0523634` Docs: central index, decisions log, changelog, parking, design frame, feedback log
- `6dbc2a5` Playtest build version 0.1.0-playtest3
- `e81d426` Audio mix: quieter click and hydroponics loop
- `7485f3f` First-run hints and how-to v2
- `f0e115e` Clarity: effects on buttons, end-turn highlight, room switch and help badges
- `fcf5fbf` Fix: double-click empty panel, camera bounds, zoom re-centre
- `0cb04bb` Auto interface scale
- `da26f0b` Contrast fixes
- `522e3cc` Rival log lines in Russian
- `d286652` Russian names for stations and commanders
- `80a9a13` Backstories for the twenty core residents
- `1949d79` check_playtest reads the version from build_info
- `27b0b52` Playtest build version 0.1.0-playtest2
- `7d7dbdc` Resident profiles: sex-aware portraits, professions, before and keepsake in the dossier
- `c9da630` Twelve more resident portraits
- `13e5e0c` Performance tool and overnight QA report
- `83a6824` Figure outlines are prepared in 0.3 s instead of 1.9 s at start
- `047de9d` UI matrix tool and EN/RU report for 7 window sizes
- `5752d9f` English alert chips drop the log tag like the Russian ones
- `383755d` Settings columns narrow to fit a 1024 px window
- `5cb2244` Top bar fits narrow windows by moving the meters to a second row
- `5238f14` Localization audit tools and EN/RU report
- `8947f87` Network map and station sheet show names in the player's language
- `c2d3c9d` Journal names crunch events instead of showing their ids
- `13ea7fc` Soak test and save fuzz tools, soak report
- `8c76a16` Saves with broken records are refused instead of half-loading
- `28f8355` Check events no longer mark the shared catalog as opened
- `622beea` Gates run in English whatever the player's settings say
- `66d0cab` Playtest build: preset, build info, how-to card, local log and report, tester docs
- `04a16d8` Coney cast keeps fitting resident portraits
- `f1c7440` Event pool: 14 new events, balance gate on 30 seeds

### 2026-10-11 (62)

- `326d9db` Balance gates: noise tolerance for expander and follower white checks
- `be2feb0` Bot: storyteller prefers story choices, storyteller_climb
- `1b21021` Story content: gender fixes, epilogue lines, iron sources, Lamplighters arrive by week 14
- `47a67d6` Quarantine order, climb threshold 50
- `8d3eeac` Story engine S2: bunker scenes, final decision, endings and epilogue
- `c7527af` Docs: story, plan, marketing, briefs
- `4b0bfda` Offer help once per six weeks; late Lamplighter window
- `a3b8a7b` Audience: offer help raises a leader's trust honestly
- `371f00a` Story act II: ten truth fragment events, proof marks on the Truth page
- `3925881` Story engine S1: truth fragments, conditions, words and iron sources, journal page
- `7f1263f` Balance gate: expander discontent relative to the no-story baseline
- `5d9cc2f` Docs: story spine, EA plan, briefs
- `a8c92d6` Network map: tags never cover pins
- `6e45ee4` Leader consequences: answers recorded, 10 events, standing effect, bot audience styles
- `6dc1e27` Resident figures: distinct stems per room, builders use drawn set
- `e22bd56` Network map: faction symbols on tags, capitals, sheets and legend
- `063d488` Resident figures v2 installed
- `a406114` Content audit script and report
- `acff235` Resident figures: soles at 656, height 520..600, half tint for the drawn set
- `cde97c1` Resident figures: fit tool
- `241b883` Leader voices: 110 lines EN/RU installed
- `e83f4e1` Leader voice playback (silent until files exist)
- `e9df473` Leader text: one source, first contact without repeated name
- `796af03` Station text: English layer, hub art lines
- `719f34c` Faction hubs: visit panorama capped at 400 px
- `77a17af` Audience card layout: fits 1280x720 with memory
- `149089c` Faction hubs: northgate v2
- `1638336` Faction hubs: style v2
- `9db4198` Faction symbols installed
- `dd816bc` Radio pilot 04: four bulletins voiced EN/RU
- `d947ce0` Leader lines: punctuation
- `b42c9b6` Radio normalized to -23 LUFS
- `c9c6087` check_slice: skip check-only events, crisis demand uses the income floor
- `c98d7e9` Leaders v2: names, lines, portraits, territory and trade lines
- `b91baff` Docs: overnight log, briefs, leaders v2 canon
- `0d81b33` VO index and credits
- `f74e541` Labels: localized upgrade names, Regard on the card, Opinion on the map
- `28af12d` Reject faction art and leader text, keep the mechanism
- `8eede41` Leader opening line under the portrait
- `453e2c1` Audience order: least recently seen first, regression checks
- `4975ffe` Save hardening: staged import, atomic slots, .bak recovery
- `8feb404` Worker tint keeps residents visible on dark rooms
- `6270c4b` Leader portraits and faction symbols from factions_v3
- `50b74b8` Faction symbols and leader portraits on the audience card
- `49e3fcc` Audience card shows only what the deal applies this turn
- `c351e4f` Overnight report: factions status and checks
- `3bc45b7` VO: event and system lines leveled to -23 LUFS (spread was 4.3 dB), originals kept out of git
- `c785a6c` Poses: poses_fix reviewed and rejected, nothing committed (overnight report)
- `a7b97d8` Faction leaders: opinion, audiences, five dirty deals
- `66584ae` Overnight report: figures, stories counter, verification
- `ebcd74e` People: stories heard counter, unheard dot, no story text before listening
- `d342bab` Resident figures: 12 bodies, whole work pose, four palettes
- `d58ad68` VO phase 3 audio, story loudness normalized
- `7255f77` VO phase 2: resident story audio
- `e49ece1` VO phase 1 audio, Russian subtitle rewrites, radio frequency option
- `647f642` Data-driven voiceover from the VO script pack
- `549c52f` Journal: worded, localized milestones and a tray button; lighter saves
- `f334b0a` Richer room loops, softer and rarer drips, Fewer audio cues toggle
- `871049d` Hook up voiceover: dossier stories, weekly cable radio, event and action lines
- `9a98b53` Restore GDD v2 as docs/GDD.md (recovered from the Oct 2 chat)
- `807631e` Station photo on the map sheet, drawer drag and swap, disclaimer
- `5b8896f` Backstories, room audio, cable radio and journal

### 2026-10-10 (41)

- `37c531c` Track export_presets.cfg so the export scripts work from a fresh clone; it holds no credentials.
- `623e1ef` Ignore build/ and shots/, and stop tracking the old screenshots that nothing links to.
- `e85ff7e` Add RU and EN export scripts that build the exe, lang.txt and the playtest zip, and commit the Russian playtest notes.
- `76095e4` Park the unused PT Sans fonts and licence in incoming-art/fonts.
- `fae4f70` Back up the incoming art drops, banners and originals.
- `e7d0e6a` Store art, audio and fonts in Git LFS.
- `67cbc7c` Make icon adoption a manual tool script instead of a copy on every run, and commit the adopted icons.
- `a7f53a4` Keep screenshots and builds out of the Godot import and the export.
- `4aa9270` Desk map: fit the whole map below the HUD at min zoom with a blurred desk behind the edges, set shared line strokes side by side, and load the map art from assets/map as webp with incoming-art excluded from the export.
- `bd5fe44` Keep the desk mockup reference out of the Godot import and the export.
- `0d7804a` Replace the network map with the overseer's desk: the painted city map pinned under the lamp, marker lines, watercolor territory, push pins with paper tags, order flags, an index-card station sheet and council photos.
- `edeaf8e` Visual overhaul: warning chips on event cards, Frostpunk-style room seats with a power switch, construction sites that reveal the future room, larger build menu icons, and incoming room figures.
- `82eae11` Keep near-term warnings on event cards and fold only rival plans and general news.
- `08cbd0e` Add the import settings for the map paper and water textures.
- `f2bbea8` Give room figures the sitting, walking, kneeling and working poses the builds already show.
- `08ce6b2` Commit the check-event data, Coney cast, new banners and dig icon the sim and UI already use.
- `1c4ff15` Playtest UX pass: people filter, bigger build timer, auto-staff, choice deltas, order tooltips, roomier cards.
- `da22648` Add the paper and water textures the map draws.
- `bce3104` Fill the map land with the paper texture and the water with the ripple texture.
- `d12fb2a` Keep white checks at 72% and red checks at 50% for the best resident.
- `5dddf7b` Give owned stations their own panel, label every stop, and open a visit screen.
- `7603bb7` Replace room color washes with a lamp glow, keep the skyline in proportion, and shorten the week-1 guide.
- `f08b6a2` Add Russian lines for owned stations, orders, and the visit screen.
- `73192d3` Let the play window fill the desktop so the resource bar stays at the top.
- `afc32b2` Ease the map fisheye so distant coasts stay at the frame edge.
- `e44a583` Hold each council order until the next dawn.
- `9efb713` Show each check's resident, modifiers, and odds before the roll, and keep a failed white check on a pending list.
- `db4df5a` Add white and red event checks on their own random stream so a failed white check can be retried.
- `3cb8de3` Show the full week-20 map, then the intent close-up.
- `795105c` Capture the loyalty warning and the ultimatum on the dawn card.
- `30ae92b` Add original looping drone and station beds.
- `5c5fcee` Use the icon set for small marks, rooms, status, and map actions.
- `db70a3e` Keep the careful steward in the food, population, and discontent band.
- `f0540e5` Point the week-4 guide at the nearest station and a trade deal.
- `816c889` Let rival ultimatums and station flips follow the board instead of the calendar.
- `efe7dce` Make outposts cost upkeep, then ship surplus back to the capital.
- `b76c6fb` Add the network map, station sheet, and council orders.
- `59b5180` Run supply, loyalty, and rival orders on the 25-station network.
- `a892d2a` Load the 25-station geography and the log-fisheye map projection.
- `dc94ca0` Add a main menu with settings and a weekly save, and draw resource icons in the HUD.
- `8d9b341` Show the Depot on the Coney Island hub.

### 2026-10-06 (1)

- `b13ec8a` Give the yard painted rooms, one waiting card, and type and figures you can read.

### 2026-10-05 (9)

- `6140e00` Lock play to landscape and frame every level at the art's own shape.
- `f2d1aaf` Draw the station as a place you play, not a dashboard.
- `ae51086` Point the yard at the fix that helps before a shortage lands.
- `5d7dd3a` Record the 15-week clip against the new week.
- `45d0fff` Add a follower who only acts on what the yard shows.
- `c32089d` Let one major pressure own a week.
- `9ac93d6` Keep events from repeating and let a choice come back later.
- `f957ecb` Give the yard a way through a power shortage.
- `ca405fb` Show one dawn event at a time so a choice cannot come back.

### 2026-10-04 (1)

- `8d26046` Name the missing resource on a blocked action, and draw the crunch from a pool.

### 2026-10-02 (5)

- `1447814` Let the station grow from births and refugee crowds.
- `e2268e0` Open the station as a cut-away the player can run.
- `c639b41` Add station actions a player can aim at a cell.
- `98e5ec2` Fit opening stocks to the pantries and separate the two stewards' moods.
- `0f0034b` Start the Underline sim and tune the economy so shortages land.

