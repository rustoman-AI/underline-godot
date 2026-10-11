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
