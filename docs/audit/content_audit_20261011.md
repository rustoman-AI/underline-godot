# Content audit 20261011

Measured with `.tools/content_audit.gd` on the current data and sim, 30 seeds for each of the bot styles careful, expander, follower (90 runs of 40 weeks), leader forks on seeds 1 to 10. Facts only, no proposals. The bots are not players: they decide instantly, use the same rules each week and never answer an audience.

## 1. Counts

| Item | Count | Detail |
| --- | --- | --- |
| Events, all | 39 | 2 major, 20 minor, 5 check, 12 follow-up only (chain_only) |
| Events with a follow-up | 12 | follow-up text varies by the earlier choice in 12 |
| Events with their own cooldown | 22 | global cooldown 8 weeks, minor events capped at 2 per run (balance.json) |
| Choices per event | 2 / 2.0 / 2 | min / mean / max over all 39 events |
| Laws | 9 | 7 repealable |
| Rooms | 9 | 8 buildable, 13 upgrade tiers in all |
| Seasons | 3 | flood (week 10, 3 weeks), cold (week 20, 3 weeks), cough (week 30, 3 weeks) |
| Artifact kinds | 3 | papers, iron, words declared; with a source in the sim: papers |
| Bunkers | 3 | archive (owner bunker, floor), signal (owner bunker), oldcommand (owner bunker) |
| Run endings (game over states) | 5 | time, collapse, hope, revolt, capital; each has one end card line, there is no epilogue |
| Named residents | 25 | residents.json; 5 in characters_coney.json |
| Backstories | 5 | backstories.json |
| Voiced lines (rows) | 127 | radio 26, story 30, event 8, system 8, leader 55 |
| Voiced audio files | 230 | EN 115, RU 115 |
| Stations | 25 | 15 on the map pins (stations.json); owners at start: directorate 2, neutral 14, depot 1, enemy 1, exchange 1, synod 2, bunker 3, ruin 1 |
| Tunnels | 30 | 16 in tunnels.json |
| Leaders / audience deals | 5 / 5 | one dirty deal per leader |

## 2. Forty-week repeat rate

Per run, then mean / min / max over the 30 seeds of each style. Decisions = event choices (bot and night-resolved) + orders + laws + audiences shown.

| Style | Events shown per week | Distinct events | Events shown 2+ times | Longest gap without an event (weeks) | Weeks with zero decisions | Decisions per week |
| --- | --- | --- | --- | --- | --- | --- |
| careful | 1.61 / 1.55 / 1.70 | 40 / 37 / 42 | 23 / 20 / 26 | 0 / 0 / 0 | 0 / 0 / 0 | 2.89 / 2.48 / 3.27 |
| expander | 1.63 / 1.55 / 1.75 | 40 / 36 / 42 | 23 / 19 / 27 | 0 / 0 / 0 | 0 / 0 / 0 | 4.09 / 3.75 / 4.95 |
| follower | 1.62 / 1.52 / 1.68 | 40 / 38 / 42 | 23 / 16 / 27 | 0 / 0 / 0 | 0 / 0 / 0 | 2.35 / 2.15 / 2.52 |

Decisions per week by type (mean over all runs and weeks):

| Style | Event choices (bot) | Event choices (night) | Orders | Laws | Audiences shown | Build / dig / upgrade |
| --- | --- | --- | --- | --- | --- | --- |
| careful | 1.64 | 0.00 | 0.65 | 0.05 | 0.56 | 0.53 |
| expander | 1.66 | 0.00 | 1.78 | 0.00 | 0.64 | 0.55 |
| follower | 1.64 | 0.00 | 0.16 | 0.02 | 0.53 | 0.50 |

Emptiest and busiest week numbers across all 90 runs (mean decisions and events shown in that week):

| Emptiest week | Decisions | Events | | Busiest week | Decisions | Events |
| --- | --- | --- | --- | --- | --- | --- |
| 3 | 1.42 | 1.07 | | 17 | 4.86 | 1.83 |
| 29 | 1.80 | 1.43 | | 13 | 4.78 | 2.93 |
| 28 | 2.01 | 1.49 | | 14 | 4.27 | 2.22 |
| 36 | 2.04 | 1.58 | | 10 | 4.19 | 2.06 |
| 35 | 2.31 | 1.58 | | 16 | 4.10 | 1.90 |

## 3. Run-time estimate

Assumptions (brief): event choice 25 s, order 12 s, law 30 s, audience 40 s, reading the dawn report 20 s per week, building and assigning 60 s per week. A normal new player takes those times; careful x1.5, fast x0.6. Decision counts are the bots' (section 2), audiences counted when shown. The bots use fewer order seats than a player may: the second line puts every order seat to use (3 per week).

| Counts from | Player | Minutes per week (mean, min..max run) | 40 weeks, hours (mean, min..max run) |
| --- | --- | --- | --- |
| bots | careful | 3.9 (3.4..4.5) | 2.59 (2.30..2.99) |
| bots | normal | 2.6 (2.3..3.0) | 1.73 (1.53..1.99) |
| bots | fast | 1.6 (1.4..1.8) | 1.04 (0.92..1.20) |
| all seats | careful | 4.5 (4.3..4.7) | 3.02 (2.86..3.12) |
| all seats | normal | 3.0 (2.9..3.1) | 2.01 (1.91..2.08) |
| all seats | fast | 1.8 (1.7..1.9) | 1.21 (1.15..1.25) |

Runs that ended before week 40 are scaled to 40 weeks at their own weekly rate. The fixed part (dawn report and building) is 80 s, that is 1.3 minutes a week and 0.9 hours over 40 weeks for a normal player.

## 4. Dead ends

Endings reached:

| Style | Ending (week) counts | Runs with sim errors |
| --- | --- | --- |
| careful | time x30 | 0 |
| expander | time x29, revolt (week 35) x1 | 0 |
| follower | time x29, revolt (week 36) x1 | 0 |

Per seed (careful / expander / follower):

| Seed | careful | expander | follower |
| --- | --- | --- | --- |
| 1 | time | time | time |
| 2 | time | time | time |
| 3 | time | time | time |
| 4 | time | time | time |
| 5 | time | time | time |
| 6 | time | time | time |
| 7 | time | time | time |
| 8 | time | time | time |
| 9 | time | time | time |
| 10 | time | time | time |
| 11 | time | time | time |
| 12 | time | time | time |
| 13 | time | time | time |
| 14 | time | time | revolt w36 |
| 15 | time | time | time |
| 16 | time | time | time |
| 17 | time | time | time |
| 18 | time | time | time |
| 19 | time | time | time |
| 20 | time | time | time |
| 21 | time | time | time |
| 22 | time | time | time |
| 23 | time | time | time |
| 24 | time | time | time |
| 25 | time | revolt w35 | time |
| 26 | time | time | time |
| 27 | time | time | time |
| 28 | time | time | time |
| 29 | time | time | time |
| 30 | time | time | time |

Events that never fired in any run (0 of 39): none

Upkeep events built at run time in `sim/game.gd`, not in events.json (presentations): pantry 66, belt 66, dynamo 42, stacks 24, ducts 48, shopbelt 24

Choices never picked in events that did fire (24): quarrel/shut, preacher/stop, smuggler/refuse, rumble/push, static/ignore, wire/trade, leak/buckets, nightshift/order, ration/hold, tools/drop, scrap/leave, overtime/keep, hymn/quiet, drill/stay, lamps_next/move, refugees_next/names, quarrel_next/split, preacher_next/no, smuggler_next/end, rumble_next/up, static_next/stop, desertion_next/box, cough_next/push, leak_next/move

Choices only ever taken by the night resolve, never by a bot (0): none

Presentations per event over all 90 runs (most to least):

refugees 307, refugees_next 256, quarrel 178, market_food 176, wire 170, preacher 169, tools 169, leak 169, hymn 168, overtime 168, quarrel_next 168, smuggler 168, clog 168, salt 166, ration 165, bunks 164, market_next 161, nightshift 160, scrap 160, cough 158, drill 153, leak_next 149, clog_next 148, preacher_next 146, smuggler_next 142, desertion 133, cough_next 133, static 117, desertion_next 100, moles_vents 90, garden_mold 90, queens_expedition 90, generator_sabotage 90, showtime_betting 90, static_next 87, lamps_next 83, lamps 83, rumble 32, rumble_next 26

## 5. Leader deals

Audiences shown per run (mean / min / max over seeds) and deals accepted by the bot:

| Leader | careful shown | careful accepted | expander shown | expander accepted | follower shown | follower accepted |
| --- | --- | --- | --- | --- | --- | --- |
| depot | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 |
| directorate | 3.8 / 0.0 / 6.0 | 0 of 30 | 5.8 / 5.0 / 6.0 | 0 of 30 | 3.7 / 0.0 / 6.0 | 0 of 30 |
| synod | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 4.0 / 5.0 | 0 of 30 | 5.0 / 4.0 / 5.0 | 0 of 30 |
| exchange | 6.0 / 6.0 / 6.0 | 0 of 30 | 6.0 / 5.0 / 6.0 | 0 of 30 | 5.9 / 5.0 / 6.0 | 0 of 30 |
| black_flag | 2.5 / 2.0 / 3.0 | 0 of 30 | 3.8 / 3.0 / 4.0 | 0 of 30 | 1.6 / 0.0 / 3.0 | 0 of 30 |

None of the three bot styles has audience logic (`sim/bot.gd`): a leader left waiting is turned away by silence at the next dawn, which the game records as a refusal with the deed "silence". The forks below answer for the bot.

Forks: 142 (seeds 1 to 10, all styles, first audience of each leader). Each row compares the accept or refuse branch with the silence branch at the same week: right after the answer (t0), 5 weeks later and 10 weeks later. Counts are forks where the item differs.

| Leader | Branch | Forks | Blocked | When | Flag set | Own standing (mean diff) | Other standings moved | Law | Pop (mean diff) | Hope (mean diff) | Events differ | Journal rows differ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| depot | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | -4.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +25.0 | 30 | 0 | -0.03 | -4.0 | 4 | 30 |
|  |  | 0 | 0 | t10 | 30 | +25.0 | 30 | 12 | -0.33 | +0.0 | 17 | 30 |
| depot | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| directorate | accept | 22 | 0 | t0 | 22 | +30.0 | 22 | 22 | -1.00 | -8.0 | 0 | 22 |
|  |  | 0 | 0 | t5 | 22 | +30.0 | 22 | 22 | -0.86 | -10.1 | 7 | 22 |
|  |  | 0 | 0 | t10 | 22 | +30.0 | 22 | 21 | -1.50 | -10.8 | 19 | 22 |
| directorate | refuse | 22 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 22 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 22 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 22 |
| synod | accept | 30 | 0 | t0 | 30 | +30.0 | 30 | 0 | +0.00 | +12.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +30.0 | 30 | 0 | +0.27 | +11.2 | 12 | 30 |
|  |  | 0 | 0 | t10 | 30 | +30.0 | 30 | 0 | +1.53 | +4.9 | 21 | 30 |
| synod | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| exchange | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +25.0 | 30 | 0 | +3.50 | +2.7 | 29 | 30 |
|  |  | 0 | 0 | t10 | 30 | +25.0 | 30 | 0 | +2.83 | +0.9 | 29 | 30 |
| exchange | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| black_flag | accept | 30 | 0 | t0 | 30 | +20.0 | 30 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +20.0 | 30 | 0 | -0.63 | -0.1 | 10 | 30 |
|  |  | 0 | 0 | t10 | 30 | +20.0 | 30 | 0 | +0.40 | +0.0 | 13 | 30 |
| black_flag | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |

Journal rows that differ from the silence branch by week +10 (row kind:result, number of forks), and event ids shown in one branch only (mean per fork). The sim draws all events from one random stream, so any change of state shifts later draws; none of the 39 events names a leader, deal or deal flag in its conditions:

| Leader | Branch | Journal rows that differ | Event ids in one branch only (mean per fork) |
| --- | --- | --- | --- |
| depot | accept | audience:deal (30), audience:silence (30), born (5), build (6), built (6), dig (9), event (2), find (5), law (12), order (8), papers_burned (30), pump (1), upgrade (3) | 2.2 |
| depot | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| directorate | accept | audience:deal (22), audience:silence (21), born (13), build (11), built (11), deaths (1), dig (9), event (2), find (5), handed_over (22), law (1), order (13), pump (1), repeal (1), station (5) | 4.6 |
| directorate | refuse | audience:refused (22), audience:silence (21) | 0.0 |
| synod | accept | audience:deal (30), audience:silence (30), born (8), build (11), built (11), dig (14), event (7), find (10), law (15), order (5), station (4) | 4.2 |
| synod | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| exchange | accept | audience:deal (30), audience:silence (30), born (23), build (6), built (6), deaths (4), dig (9), event (22), find (6), order (11), station (11) | 10.5 |
| exchange | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| black_flag | accept | audience:deal (30), audience:silence (30), born (5), build (5), built (5), dig (1), event (8), false_way (30), find (1), order (4), rally (1), station (3) | 3.0 |
| black_flag | refuse | audience:refused (30), audience:silence (30) | 0.0 |

Where each deal flag is read after it is set (`flags.has`, `flags.get`, `flags[...]` or `flags.<name>` in `sim/` and `ui/`, and the flag name in any event or data condition):

| Leader | Deal | Flag | Read in |
| --- | --- | --- | --- |
| depot | burn_papers | buried_papers | nowhere |
| directorate | the_list | collaborator | ui/station.gd lines 3696, 3697 |
| synod | stay_down | stayed_down | nowhere |
| exchange | open_books | open_books | nowhere |
| black_flag | lantern_toll | lantern_toll | nowhere |

Readers of the other state a deal changes, from `sim/game.gd`: `audience_deals` stops that leader coming back (`audience_eligible`); `standing` feeds the leader's band, which picks the leader's lines, the audience cooldown and the lantern toll; `standing_memory` is shown on the leader card. Outside the audience code and its tests, nothing in `sim/` reads standing (no map, order, trade or event rule).

Silence branches replayed from an exported state: 142; branches with a load error: 0.

## 6. What looks thin (facts from the tables above)

- Every one of the 39 catalog events has exactly 2 choices; the 6 upkeep events built in `sim/game.gd` are pay or suffer.
- A 40-week run shows 39.6 distinct event ids on average out of 45 possible (39 catalog + 6 upkeep); 22.8 of them come up twice or more. Rumble and its follow-up came up 32 and 26 times in 90 runs.
- No bot style picked 24 of the 78 choices in events that fired.
- Endings: 88 of 90 runs ended on time (week 40); never reached: collapse, hope, capital.
- Artifacts: only papers has a source in the sim; iron, words are declared with no source.
- Backstories: 5 for 25 named residents.
- Every week had at least one event and one decision (longest gap 0 weeks, 0.0 empty weeks per run).
- Leader deals: accepted 0 times over 90 bot runs (the bots have no audience logic). An accepted deal sets its flag, moves standing and changes meters at once; no sim rule reads any of the five deal flags afterwards, and only `collaborator` is read by the UI (one dossier line).
- Refusing and leaving a leader waiting end the same in every fork at +10 weeks except for the audience row's result (refused or silence).

