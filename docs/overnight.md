# Overnight log, 2026-10-11

Nothing pushed. Balance untouched.

## 1. VO Phase 3 and story loudness

**Phase 3.** All 32 files (`event_*_resolve`, `sys_*`, EN+RU) unpacked into `assets/audio/vo/`. Every name matched `data/vo/underline_vo.json`; nothing renamed, no path edits, no playback code changes. 56 of 56 pack lines now have audio in both languages; only the 16 hand-written bulletins in `data/vo/cable_radio.json` stay text.

**Scope of normalization.** The request listed two versions: all voice into `_originals/`, then stories only into `_originals_story/` with radio, events and system untouched "because they are mixed differently". I followed the later one. The other groups are measured below so the decision can be revisited.

**Method.** `.tools/normalize_vo.ps1`: two-pass ffmpeg loudnorm, I = -23 LUFS, LRA 11, linear, re-encoded Vorbis q4 mono 44.1 kHz (sources were mono 44.1 kHz ~80 kbps). Always encodes from the original copy, so reruns do not stack generations. A first run at TP -1.5 left 10 stories at -1.4 to -0.4 dBTP after Vorbis encoding (ada_story_ru worst); rerun with a -2.5 dBTP loudnorm target, after which every story measures at or under -1.7 dBTP.

**Originals.** `assets/audio/vo/_originals_story/` (60 files, with `.gdignore` so Godot skips them), listed in `.gitignore`.

**Measured after** (`.tools/measure_vo.ps1`, ffmpeg ebur128, integrated LUFS):

| Group | n | min | median | max | spread | max true peak |
| --- | --- | --- | --- | --- | --- | --- |
| story | 60 | -23.0 | -22.9 | -22.8 | 0.2 dB | -1.7 dBTP |
| radio | 20 | -22.3 | -21.7 | -20.7 | 1.6 dB | -0.9 dBTP |
| event+system | 32 | -23.3 | -21.8 | -19.0 | 4.3 dB | -0.8 dBTP |

Before: stories ran -28.0 (leo_story_en) to -17.9 (chris_story_en), about 10 dB.

Ada and Leo now: ada_story_en -23.0, ada_story_ru -23.0, leo_story_en -23.0, leo_story_ru -23.0 against a story median of -22.9. All within the 2 dB tolerance.

Not done, by the later instruction: event+system spread is 4.3 dB (event_static_resolve_en -23.3 to sys_morale_high_en -19.0) and both short groups sit about 1 dB above the stories. `.tools/normalize_vo.ps1 -Pattern 'event_*.ogg' -Backup _originals` (and `sys_*`, `radio_*`) would bring them in line if wanted.

Commit: d58ad68 (VO only: the 32 new ogg, the 60 normalized stories, their .import, INDEX.md, .gitignore).

## 2. Figures and palettes

Commit: d342bab.

**Committed.** `assets/figures/poses/` body_01 to body_12 and air_filter_01, webp only (the png twins were byte-for-byte the same pose, so the loader used to draw every pose twice). `fig_standing.webp` (= body_01), `fig_walking.webp` (= body_04) and `fig_carrying.webp` (crate held in both hands) replaced, all three checked whole.

**Rejected, not committed.** generator_01, workshop_01, hydroponics_01, quarters_01: legs detached from the body, a stool or tool fused into the silhouette. The new fig_working, fig_kneeling and fig_sitting had the same faults, so those three were restored to HEAD. All rejected files (plus every pose png) were moved, not deleted, to `incoming-art/poses_rejected/` (untracked, ignored by Godot). Rooms whose work pose was rejected fall back to each spot's own pose: standing/walking spots get the new bodies, working/kneeling/sitting spots keep the old whole figures from HEAD. Only the air filter has its own work pose.

**Palettes.** slate / ochre / drab / security: each pack has all 18 source sheets, same sizes as the base, all real recolors (none identical to the base). Nothing missing. `.tools/pose_palettes.gd` built the 4 x 13 webp for the committed poses only (`poses/palettes/<name>/`). The loader picks pose and palette from a hash of the resident id (`_fig_for`), so a resident keeps the same body and colors every frame and across saves. In a fresh game: 25 residents on 11 distinct bodies, palettes spread base 4, slate 2, ochre 7, drab 6, security 6.

Note: the station draws figures through its amber light tint, so palette differences read as subtle shade changes rather than distinct colors. Left as is (art style, not a bug).

**Not committed:** `assets/figures/residents/`, `incoming-art/` (incl. palette_tests, contact sheets), png/webp duplicates.

**Concurrent edit.** Something else rewrote fig_carrying / fig_standing / fig_walking at 08:51 while I worked. I re-checked the versions on disk (hash match with body_01 / body_04, visual check of all three) before committing them.

## 3. Stories heard counter

Commit: ebcd74e.

- People panel, under Backstories: "Stories heard N/M" / "Истории услышаны: N/M" with a bar. M = residents at the station whose story has audio in the current language, N = those heard.
- Amber dot after the name of everyone not yet heard (people rows, and on the Dossier button of their card).
- Heard means the story played to the end (90% or more). Closing the dossier or pressing Stop early keeps it unheard. The first open still auto-plays once; later opens wait for "Play story".
- No spoiler: until heard, "In their words" shows "Listening. The words appear here once the story ends." while it plays, or "Listen to the story first..." otherwise. The subtitle pill still runs during playback. Stories without audio keep showing their text.
- Saves: `vo_heard` stores "started" during the first listen and true when heard; old saves (true) read as heard.

## 4. Verification

- Bot: BOT RUN OK, Missing banners: none (after each commit's changes).
- `.tools/vo_counter.gd`, RU and EN, real playback:
  - Ada, first dossier open: story plays (ada_story_ru.ogg, 56.6 s; EN 56.4 s), text hidden; closed early: still unheard; reopened: no auto-play, "Play story"; full listen: heard, text shown; counter 0/25 to 1/25, Ada's dot gone.
  - System cue food_critical through the real cue queue: sys_food_critical plays.
  - Event resolve: event_lamps_resolve plays.
- Station with different whole bodies: `shots/figures_station.png`, `shots/figures_station_zoom.png`.
- Screenshots (local only, `shots/` is ignored): `shots/counter/ru/` and `shots/counter/en/` (ada_playing, ada_unheard, ada_heard, counter_people_before/after, counter_system_cue).

## 5. Faction leaders and audiences

**Data.** `Downloads/factions.json` went in unchanged as `data/faction_leaders.json`, and `FACTIONS.md` as `docs/FACTIONS.md`. The old `data/factions.json` stays: it is the map's rival powers (capitals, squads, ambition, lean) and the sim reads it everywhere, so overwriting it would break the map.

**Opinion.** Leader opinion (`standing`) is its own number per leader, -100..100, start from `start_opinion` (Depot +20, Black Flag -10, others 0). Bands come from `opinion_bands`. It is kept apart from the map's `opinions` (Exchange +10, Directorate -10 at start, driving trade, war and drift), so map balance is untouched. Each leader remembers the last `memory_slots` (3) deeds as text. The cooldown between audiences of the same leader is `audience_cooldown_weeks` (6).

**Arrival** (at dawn, read from the `arrival` field; `week_N` takes N from the data):
- Pike: radio room built, or week 6.
- Halloran: a Directorate squad intent aimed at one of our stations or a station bordering ours, or food under one week. Any Directorate squad would bring him in week 1, during the guide, because their squad moves from the start.
- Kato: first season, or week 10.
- Pell: first caravan (first trade order).
- Bird: first sealed tunnel (the sealed door find on the lower level).

At most one leader per dawn, the earliest due. A leader left unanswered until the next dawn counts as a refusal (FACTIONS.md: silence is refusal). Bot runs, never answering: Exchange week 2, Pike 6, Halloran 4-10, Kato 10, Bird 20-29, then each again every 7 weeks.

**Card.** Same NARRATIVE card as the dawn report, shown before it: sign, leader name, title and faction, opinion and band, the one opening line, what they remember, then "Hear them out" / "Not today". Hearing shows the dirty price with every number before the player can agree: hope, discontent, food, each opinion shift, the person to be handed over by name, the Papers clue count, Bird's opinion and whether her way is a lie, the free room tier, the mark. Refusing at either step is journaled and remembered.

**Deals** (numbers from the json only): hope, discontent, food and opinion shifts apply as listed. Flags in the save: `collaborator`, `buried_papers`, `stayed_down`, `open_books`, `lantern_toll`; nothing clears them, and after `collaborator` every later audience says so.
- The list: hands over the least skilled resident outside the council (named on the card), puts Curfew in force, air filter +1 tier.
- Burn the papers: destroys one Papers clue if one was found; otherwise only the mark and the journal row. Workshop +1 tier.
- Lantern toll: costs 8 food (disabled if the stores are short). Below zero opinion (where she starts) the way is false and the journal says so.

**Not done, because the json has no numbers or the mechanics do not exist yet:** the Directorate squad for eight weeks, faster digging, the eight-week ban on surface expeditions, the Synod medic, a dearer Exodus, the Exchange price cut and rival-need race, the volunteer option of the lantern toll and the flooded way itself, Pike turning hostile on publication, the exceptions to the cooldown at hostile and pact. The deal texts on the card still mention them because they are the json text.

**Sign.** `res://assets/factions/<id>_symbol.webp` if the file exists; none do yet, so the card shows the first letter of the faction name on the faction color. No portraits.

**Journal in red:** person handed over, papers burned, Bird's false way. Strings en + ru.

**Checks.** Bot OK, no missing banners. `.tools/audience_probe.gd --accept` (3 seeds, every deal taken): all five flags set, three red rows, no errors. `.tools/audience_shots.gd` RU and EN: Halloran deal takes Lila Voss (25 to 24 residents), Curfew on, Directorate +30, Depot -25 (Pike now -5 and remembers it); Pike turned away, journal lists both. Screenshots in `shots/audience/<lang>/` (aud_halloran, aud_halloran_terms, aud_pike, aud_journal), not committed.

**Again:** something rewrote `assets/figures/` while I worked (broken work poses, png twins and the palettes back on disk). Not touched, not committed.

## 6. poses_fix review: nothing committed

Checked `incoming-art/poses_fix/` (lineup and every file) beside body_01 at full size and at room size (32 px tall). No pose generated, `build_fixed_poses.gd` not run.

None pass. They are not redrawn work poses: each is one of the existing standing bodies, unchanged, with a flat vector prop pasted over it. Arms that "hold" things are plain grey tubes, props are flat untextured rectangles and lines, and the figure keeps the idle stance. That is the blueprint look the check rules out, and at 32 px it reads as a standing body next to a colored box. Legs and floor contact are fine in all of them.

| File | Problem |
| --- | --- |
| hydroponics_01 (= work_hydro_01, byte-identical) | body_01 standing upright, not leaning; a flat tray on a wire stand drawn across her shin; the "secateurs" is a grey bar at the tray edge, not in her hand |
| work_hydro_02 | side body with two grey tube arms; flat brown tray |
| work_hydro_03 | grey tube arm; flat striped box as the canister |
| workshop_01 (= work_shop_01) | hatched brown rectangle pasted as the apron, a single straight line as the cable, no torch in the hand, sparks floating beside the hip, the mask is a black blob at the neck |
| generator_01 (= work_generator_01) | grey tube arm reaching to a flat pipe post; no valve wheel |
| work_generator_02 | body_01 with a flat yellow box and red line pasted at the hip |
| air_filter_01 (= work_filter_01) | radio body with a grey tube arm to a flat column of squares and a white disc |
| work_infirmary_01 | body_01 with a flat clipboard pasted at the hip |
| quarters_01 (= work_infirmary_02) | crouched body on a flat hatched box; box overlaps the legs |

All stay in `incoming-art/poses_fix/`. Nothing was committed: no hydroponics pose, no duplicates, lineup or fixes.txt.

`build_fixed_poses.gd` had already run at 09:25 and left its output in `assets/figures/`: those same poses as webp+png (generator, hydroponics, quarters, workshop, with palettes), and it overwrote air_filter_01.webp, all 52 palette files and four fig_*.webp. The station loader reads that folder, so the game was drawing them locally. All 94 files were copied unchanged to `incoming-art/poses_rejected/build_fixed_0925/` (hashes checked), then the untracked ones removed from assets and the tracked ones restored to HEAD. body_01 to body_12 were never modified. The station now draws what is committed: bodies everywhere, the air filter work pose, and the old whole fig_* for working/kneeling/sitting spots. So hydroponics has no work pose yet; its crew uses the room's spot poses.

## 7. Short lines loudness

Rule: inside a group, more than 2 dB spread gets leveled to -23 LUFS, true peak at or under -1.7 dBTP. Stories untouched.

| Group | n | min | median | max | spread | max true peak | action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| story | 60 | -23.0 | -22.9 | -22.8 | 0.2 dB | -1.7 dBTP | none |
| radio | 20 | -22.3 | -21.7 | -20.7 | 1.6 dB | -0.9 dBTP | none, inside 2 dB |
| event+system before | 32 | -23.3 | -21.8 | -19.0 | 4.3 dB | -0.8 dBTP | leveled |
| event+system after | 32 | -23.0 | -22.9 | -22.5 | 0.5 dB | -2.3 dBTP | |

Same two-pass loudnorm as the stories (`.tools/normalize_vo.ps1 -Pattern 'event_*.ogg'` and `'sys_*.ogg'`, `-Backup _originals_short -Target -23 -Peak -2.5`; the -2.5 loudnorm target leaves room for the Vorbis overshoot). Originals: `assets/audio/vo/_originals_short/` (32 files, `.gdignore`), in `.gitignore`. Godot reimport clean, VO check OK (56 voiced per language). Radio keeps its -0.9 dBTP peak because the group was not leveled.

## 8. Factions, second request

The attached factions.json and FACTIONS.md are byte-identical to what went in with a7b97d8 (`data/faction_leaders.json`, `docs/FACTIONS.md`), so section 5 already covers the request; no code change. That commit came before the poses and loudness commits because it was done in the previous pass.

**Checks after all three:** bot OK, no missing banners. `.tools/audience_shots.gd` RU and EN unchanged (Halloran card, terms, deal, Pike turned away). Station with the committed poses: 25 residents on 11 distinct bodies, hydroponics crew on body poses. Screenshots in `shots/iter3/<lang>/` (aud_halloran, aud_halloran_terms, aud_pike, aud_journal, figures_station, figures_station_zoom), not committed.
