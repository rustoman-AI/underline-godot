# Overnight QA, 2026-10-12

## Summary

1. All 6 parts ran. 13 commits, all local, every one passed all 8 gates; no fix had to be reverted. Nothing pushed or uploaded.
2. Soak: 1400 runs (7 styles x 200 seeds x 40 weeks), 4200 save/load round trips. Final run on the last commit: 0 failures.
3. Real bug found by the soak: check events marked the shared catalog as opened, so a loaded or second game in a session skipped their open effects. Fixed with a regression test.
4. Save fuzz: 2429 mutated saves from 50 mid-run saves. Before: 211 broke play after loading or failed noisily. After: 0 bad (1715 refused cleanly, 607 loaded and played on, 107 refused with engine noise in the log).
5. Gates were red on this machine because the player's settings say Russian; gates now force English.
6. Localization: EN runtime 0 findings in 14320 lines. RU: 2 mechanical bugs fixed (raw crunch ids in the journal; English names on the map and sheet). 25 remaining RU findings are names and sentences for the lead.
7. UI matrix: 210 shots, 2 languages x 7 sizes. 1024x768 had the Menu button and part of Settings outside the window; fixed. EN alert chips showed a raw log tag; fixed.
8. Performance: time to the first drawn main menu 4.2 s down to 2.6 s (one image filter rewritten, output byte-identical). Frames 2.2 ms on a busy station, 0.7 ms on the zoomed map. No leaks. Save 17 ms, load 5 ms.
9. For the lead: 11 station names and the rival war/sermon log lines have no Russian; 3 low-contrast colours; no automatic UI scale at 1440p; hub art missing in this working copy.
10. Untouched: content text, balance, art, audio, the forbidden data files, and the uncommitted data/backstories.json and data/resident_profiles.json (not mine).

## What ran

| Part | Tool | Result | Report |
|---|---|---|---|
| 1 Soak | .tools/soak.gd | 1400 runs, 0 failures (final code), about 4 min wall clock | soak_20261012.md |
| 2 Save fuzz | .tools/save_fuzz.gd + check_save | 2429 cases, 0 bad | soak_20261012.md, this file |
| 3 Localization | .tools/l10n_audit.js, .tools/l10n_runtime.gd | static 1238 pairs; runtime 14320 lines per language | l10n_20261012.md |
| 4 UI matrix | .tools/ui_matrix.gd | 14 runs, 210 shots in shots/qa/ (not committed), 294 s | ui_matrix_20261012.md |
| 5 Performance | .tools/perf.gd | numbers below | this file |
| Gates | .tools/gates.ps1 | 8 of 8 green after every commit | |

## Fixes (commits, oldest first)

| Commit | What | Found by |
|---|---|---|
| 622beea | Gates run in English whatever the player's settings say; .tools/gates.ps1 runs all 8 | gates red at start |
| 28f8355 | Check events no longer mark the shared catalog as opened (loaded games drifted from the uninterrupted run). Regression test in check_save | soak |
| 8c76a16 | Saves with broken records are refused with a clear load_error instead of half-loading; the slot stays untouched. 19 cases added to check_save | save fuzz |
| 13ea7fc | Soak and fuzz tools, soak report | |
| c2d3c9d | Journal names crunch events instead of showing raw ids (pantry, belt...). Regression in check_slice | l10n runtime |
| 8947f87 | Network map and station sheet show station and councillor names in the player's language | l10n runtime, UI matrix |
| 5238f14 | Localization tools and report | |
| 5cb2244 | Top bar fits narrow windows (Menu and Discontent were outside a 1024 px window) | UI matrix |
| 383755d | Settings columns narrow to fit a 1024 px window | UI matrix |
| 5752d9f | English alert chips drop the raw log tag ("ULTIMATUM ...") | UI matrix |
| 047de9d | UI matrix tool and report | |
| 83a6824 | Figure outline filter 1.9 s to 0.3 s at start, byte-identical output | perf |
| (last) | Performance tool and this report | |

Layout fixes were checked against the old shots at 1280x720: unchanged at 1280 and wider (remaining pixel differences are the time-based glow on empty cells).

## Numbers

### Soak (final code)

1400 runs, 0 failures, 0 runs without an ending. Each style takes about 3.7 min in its own process.

| Style | Endings |
|---|---|
| silence, helper, helper_mixed, accept_all, mixed | winter x200 each |
| storyteller | exodus 60, open_door 136, order 4 |
| storyteller_climb | exodus 170, open_door 26, order 4 |

### Save fuzz

| | Cases | Refused clean | Loaded, played on | Refused, engine noise | Bad |
|---|---|---|---|---|---|
| Before 8c76a16 | 2429 | 1295 | 923 | | 211 (103 broke play after load, 108 decode errors) |
| After | 2429 | 1715 | 607 | 107 | 0 |

### Performance

Machine: AMD Radeon RX 9070 XT (Vulkan 1.4), Godot 4.7.2, windowed, vsync off. Only one machine was available; low-end numbers are still unknown.

| Measure | Before | After |
|---|---|---|
| Engine start to script | 0.82 s | 0.82 s |
| To first drawn main menu | 4.18 s | 2.56 s |
| Scene build part of that | 3.37 s | 1.74 s |
| Busy station, week 25, 14 rooms, 49 residents, 1920x1080 | 2.2 ms avg, p95 2.7 ms, max 3.5 ms | same |
| Same, 3440x1440 window requested (CPU-bound, not size-bound) | | 2.2 ms avg, p95 2.6 ms |
| Network map fitted / zoomed x2.2 | 0.70 / 0.72 ms avg | same |
| Memory week 1 | static 89.0 MB, video 285 MB (textures 245 MB), 429 nodes | |
| Memory after 40 weeks | static 94.8 MB, video 335 MB (textures 295 MB), 684 nodes, 0 orphans | |
| 20 journal + map opens with no play | objects +0, nodes +0 | no leak |
| End of week, sim + UI refresh | 26.6 ms avg | |
| Manual save / load at week 40 | 17.4 ms / 4.8 ms median, file 213 KB | |

Node growth from week 1 to 40 follows the station: more rooms and residents drawn.

The remaining start time: about 1.0 s for the first frame (shader compile and texture upload), 0.25 s loading the resident figure sets, 0.3 s for the figure filter, 0.13 s for the network view. A pipeline cache or smaller textures could cut more, but both change assets or the build; not done.

## Skipped, and why

- **Station names, rival log sentences, squad names (RU)**: they need new Russian names and sentences, which is wording. Listed for the lead in l10n_20261012.md with the code locations.
- **"Myrtle–Willoughby" en dash**: it is in data/station_communities.json, which this run may not touch.
- **Low-contrast colours** (red alert chip 1.9:1, locked approach orders 2.1:1, journal season line 2.0:1): colour choice is design. Listed in ui_matrix_20261012.md.
- **Automatic UI scale for 1440p and up**: design decision. Nothing is cut at those sizes; the UI is just small.
- **Journal titles for pay, gift, address and aid orders**: only the bot gives these orders. The player UI has no buttons for them, so no player sees the missing titles.
- **Save checksum**: corrupt bytes are refused cleanly, but the engine prints its own decode errors. A checksum would silence that; it changes the save format.
- **Custom-drawn text** (yard labels, map canvas) is not a Control. The UI matrix cannot measure it, so it was checked by eye in the shots only.

## Open decisions for the lead

1. Russian names for Penn Station, Union Sq, Times Sq, Aqueduct, Cathedral Pkwy, Flushing, Astor Pl, Delancey St, Greenpoint, Court St, Myrtle–Willoughby. Your texts already use "Корт-стрит" and "Кафедральный парк".
2. Russian sentences for rival log lines (BATTLE, PREACH, DEFECT, REVOLT, rival captures, DEAL) and names for Captain Rhee and Broker Lin.
3. Hyphen or en dash in "Myrtle–Willoughby".
4. Colours for the red alert chip, locked order reasons and muted journal lines.
5. Default UI scale by screen height (for example 125% at 1440p).
6. Hub art: assets/hubs/hub_coney_island.webp is missing in this working copy, so New Game skips the start screen and the menu has no backdrop (the station HUD shows through behind "Settings"). Check that the file ships in the playtest build.
7. Save checksum (format change).
8. EN ultimatum chip says "2 turns left"; the rest of the UI says weeks.

## Reproduce

    powershell -ExecutionPolicy Bypass -File .tools/gates.ps1
    godot --headless --path . -s res://.tools/soak.gd -- --styles=<style> --seeds=200 --weeks=40 --keep=8
    godot --headless --path . -s res://.tools/save_fuzz.gd -- --saves=50
    node .tools/l10n_audit.js
    godot --headless --path . -s res://.tools/l10n_runtime.gd -- --lang=ru
    godot --path . -s res://.tools/ui_matrix.gd -- --lang=ru --size=1024x768
    godot --path . -s res://.tools/perf.gd -- --size=1920x1080
