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
