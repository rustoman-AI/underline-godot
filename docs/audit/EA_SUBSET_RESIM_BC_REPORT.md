# release/ea-subset — RE-SIM B and C

**When:** 2026-11-05  
**Branch:** `release/ea-subset` tag `ea-step-12-pr59` (`db23ef6`)  
**Schema:** 16  
**Master:** untouched (`af11b17`). Original PR branches: not rewritten.  
**Balance numbers:** not changed. `growth_rate` stays 0.04. `WALL_HOPE_ONCE` stays 0. `CAPTURE_ONLY` stays false.

Temporary careful band for this tip: **5–35%** (3–21 of 60). A post-launch tension pass is owed. Master careful was 2/60 (3.3%), under the old 15–35% band before this subset.

## RE-SIM B (after step 12)

Careful soak 60×40: **20/60 = 33.3%**. Inside 5–35%. Every loss is `revolt`.

| Seed | Week | End |
|---|---|---|
| 1 | 34 | revolt |
| 8 | 31 | revolt |
| 11 | 38 | revolt |
| 12 | 31 | revolt |
| 13 | 20 | revolt |
| 14 | 32 | revolt |
| 23 | 21 | revolt |
| 27 | 36 | revolt |
| 28 | 30 | revolt |
| 30 | 20 | revolt |
| 33 | 19 | revolt |
| 35 | 31 | revolt |
| 39 | 32 | revolt |
| 40 | 36 | revolt |
| 41 | 33 | revolt |
| 45 | 31 | revolt |
| 51 | 23 | revolt |
| 52 | 33 | revolt |
| 56 | 30 | revolt |
| 57 | 33 | revolt |

The other 40 seeds reached `time`. Soak also recorded `orphan_flag` on all 60. The first flag stored per run is `night_runs` (a dictionary). The checker only treats a bool or a week-int as a known flag, so a dictionary flag is reported even though the name is in the code. That did not stop the runs.

`check_balance` (30 seeds): **FAILED**. Careful seeds passing 20/30 (need 28). Careful losses 10/30, inside 3–11. Expander and follower rows OK.

`bot_run`: **FAILED**. Formulas, run integrity, expander discontent, and network target OK. Careful 20/60 (33%), first loss week 19, outside the old 15–30% gate. Expander 30/60, first loss week 29. Follower 13/60, first loss week 24. Audience: FAIL `stores_turn` banner, `ration_coat` banner. The same miss calls `ArtPack.resolve_event_banner` / `collect_banner_rows` and reports them missing from the loaded script.

Moral-core gates on this tip:

| Gate | Result |
|---|---|
| Named lives | FAIL. Logic OK. Careful 20/60 (33.3%), above the gate's 30% retune line. `growth_rate` left at 0.04. |
| Epilogue | OK |
| Book of laws | OK. Careful 20/60, watch 12/60, chapel 12/60, market 12/60. All inside 9–21. |
| Charges | FAIL. Strings, charges, promise, mandate, ticker, dawn OK. Careful loop 56/60, errors on 45 seeds. First miss seed 1 `W30 decisions 1`. The gate forces `audit`. P72 careful skips every 6th week, and a short night then ends the run as `over=error`. `Bot.play` leaves audit off for careful. |
| Night runs | FAIL. Logic OK. Careful 20/60 (33%), deaths 0, off the preserved 2/60 line. Inside 5–35%. |
| Line wall | FAIL. Strings, wall, plates, epilogue, dawn, art OK. Careful loop 56/60, same audit skip as charges. Wall hope 0. |

## Drift

| Tree | Careful loss |
|---|---|
| Master `af11b17` | 2/60 (3.3%) |
| P62 alone | 9/60 (15%) |
| + P64 | 6/60 (10%) |
| + P66 = RE-SIM A | 5/60 (8.3%) |
| Step 9 Book of Laws | 21/60 (35.0%) |
| RE-SIM B/C tip | 20/60 (33.3%) |

Stacking the life packs made careful easier (9 → 5). Book of Laws made it harder (5 → 21). The tip settled at 20/60. That is inside the temporary band and above the old 15% floor. The tension pass is still owed.

## RE-SIM C

Same tip, same soak / balance / bot numbers as B (the tree did not change between them except the wall-page button handlers, which do not touch the sim). Plus every `sim/check_*.gd`.

Passed, among others: release polish, order why, people chips, station life (careful 20/60, noted against 15–35%, gate OK), raid share (OK; its audited loop measured 56/60 and did not equality-lock it), epilogue, book of laws, save, salvage schema 16, yard clearance, guard, homecoming, join pulse, network, and the other exits listed below.

`check_save`: **SAVE CHECK OK**. Resume sampled `helped` (37 of the compared points). The odd-week help miss from step 4 did not reproduce on this tip. The drive was not edited.

`stores_turn` / `ration_coat`: still FAIL in `bot_run`, `check_audience`, and `check_dilemmas`. Not given a balance fix.

Sibling once-checks, union left intact:

- Tunnel life FAIL. Once: shipped the P62 ids (and later pack ids the solo gate rejects). UI: the event-card opener literal no longer matches, because the named-lives burial card uses an empty kicker.
- Deep life FAIL. Once: shipped P62 and P64 ids. Named: a named-lives system is present. UI: same opener literal.

Other fails, not balance-number edits:

- Salvage: schema 16 OK, schema 14 migration OK. FAIL "Listening Post is not a room on this master" (the catalog has the room) and first-raid blueprint blocked with `Need intel 2`.
- Slice: battle armor upgrade.
- Event VO: three Russian lines whose audio did not load (`evt_toll_next_body`, `evt_knock_last_body`, `evt_loan_next_body`).
- Clarity: opening network view under 90% of the free area, plus visit sheets that no longer list assault / patrol / raid at influence 0.
- Pressure rings: draw needs a renderer. Headless cannot run that shot.

Exit 0: deal marks, event chains, guard, homecoming, join pulse, leader VO, leaflet dust, listening, map alive, map feedback, music, need tick, network, order visibility, order why, party away, people chips, perks, pin warmth, playtest, portraits, push, raid share, rail noise, release polish, save, sick cots, station focus, station life, yard clearance.

Exit 1: audience, clarity, deep life, dilemmas, event VO, pressure rings, salvage, slice, tunnel life, plus the B-gate fails named lives, charges, night runs, line wall, balance, and bot_run.
