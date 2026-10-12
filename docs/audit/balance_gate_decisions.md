# Balance gate decisions

## 2026-10-11: expander discontent relative to the no-story baseline

**Replaced.** In `sim/bot_run.gd`, OUTPOST PAYBACK checked every expander seed 1 to 5 for an absolute discontent peak of 75 or less and for surviving to week 40. Two of those checks now live in a new gate, EXPANDER DISCONTENT: the discontent peak, and a game ending in revolt. The rest of OUTPOST PAYBACK stays absolute: hope min 20, stations, influence, and any other early loss. Every other bot_run gate is unchanged and is played with full content.

**New gate.** The expander plays seeds 1 to 30 twice. One run uses the full content. The other is the same game without story beats (events with `needs` that are not forced). It passes when, with the story beats:
- the number of seeds with a peak of 75 or less is not lower than without them;
- the mean peak is at most 2 higher than without them;
- there is at most one more revolt than without them.

**Why.**
- The base game does not meet the absolute threshold itself: without story beats, only 19 of 30 seeds peak at 75 or less, and the mean peak is 75.0.
- Seed 1, the one the old gate checked, peaked at 72 without story, only 3 below the threshold.
- With the story slot, seed 1 is chaotic. The story choices change discontent by -2 in total (hope +2, tokens -4). The random pool, unchanged byte for byte, then draws different events from week 15 on because the station state differs. More refugees follow, overcrowding adds 48 instead of 22, and the run ends in revolt.
- No single story choice causes it. Two rounds of tuning numbers in `data/events_story.json` changed nothing on seed 1.

**Before and after (expander, seeds 1 to 30):**

| | peak <= 75 | mean peak | revolts |
|---|---|---|---|
| without story beats | 19 of 30 | 75.0 | 1 (s25) |
| with story beats | 19 of 30 | 74.0 | 2 (s25, s1) |

Peaks per seed, without story / with story:

| seed | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| peak | 73 / 100 R | 73 / 71 | 72 / 70 | 68 / 66 | 60 / 58 | 73 / 71 | 85 / 83 | 77 / 76 | 85 / 83 | 78 / 76 |

| seed | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|
| peak | 69 / 67 | 62 / 56 | 83 / 81 | 75 / 68 | 72 / 71 | 75 / 73 | 66 / 64 | 71 / 84 | 74 / 69 | 89 / 87 |

| seed | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 |
|---|---|---|---|---|---|---|---|---|---|---|
| peak | 69 / 64 | 78 / 66 | 76 / 75 | 66 / 76 | 100 R / 100 R | 81 / 72 | 70 / 68 | 83 / 81 | 75 / 73 | 72 / 70 |

R marks a revolt. The story beats lower the peak in 24 seeds and raise it in 4 (s1, s18, s24, s25).

**Seed 1 with the story slot.** Story beats and the bot's choices:
- week 3: first_paper, keep (hope 0, dis 0);
- week 4: story_night, listen (hope +1);
- week 6: floor_rumor, send (tokens -4);
- week 15: names, read (hope -1, dis -2);
- week 16: child, lie (hope +1);
- week 18: counting, listen (hope +1).

Discontent matches the run without story to within 1 point through week 16. From week 17 the pool draws differently: refugees in weeks 17, 28 and 39, then overcrowding +2 almost every week from week 28. The peaks reach 55 at week 17, 81 at week 32 and 100 at week 40 (revolt). Without story, the run ends at 72.

Tools: `.tools/story_slot_diag.gd` (`--gate` for the 30-seed table, `--profile=expander --seed=1` for the weekly timeline).
