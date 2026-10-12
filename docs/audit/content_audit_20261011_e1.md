# Content audit 20261011

Measured with `.tools/content_audit.gd` on the current data and sim, 30 seeds for each of the bot styles careful, expander, follower and each audience style silence, accept_all, refuse_all, mixed (360 runs of 40 weeks), leader forks on seeds 1 to 10. Facts only, no proposals. The bots are not players: they decide instantly and use the same rules each week. Sections 1 to 6 use the silence audience style (the bot never answers, so every leader is turned away by silence, as before audience styles existed): 90 runs. Section 7 compares the audience styles.

## 1. Counts

| Item | Count | Detail |
| --- | --- | --- |
| Events, all | 49 | 2 major, 30 minor, 5 check, 12 follow-up only (chain_only) |
| Events with a follow-up | 12 | follow-up text varies by the earlier choice in 12 |
| Events with their own cooldown | 32 | global cooldown 8 weeks, minor events capped at 2 per run (balance.json) |
| Choices per event | 2 / 2.2 / 3 | min / mean / max over all 49 events |
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
| careful | 1.74 / 1.68 / 1.83 | 44 / 41 / 47 | 23 / 20 / 27 | 0 / 0 / 0 | 0 / 0 / 0 | 3.01 / 2.58 / 3.45 |
| expander | 1.75 / 1.68 / 1.88 | 45 / 41 / 47 | 23 / 19 / 27 | 0 / 0 / 0 | 0 / 0 / 0 | 4.20 / 3.85 / 5.08 |
| follower | 1.72 / 1.63 / 1.77 | 44 / 42 / 46 | 22 / 15 / 25 | 0 / 0 / 0 | 0 / 0 / 0 | 2.46 / 2.23 / 2.60 |

Decisions per week by type (mean over all runs and weeks):

| Style | Event choices (bot) | Event choices (night) | Orders | Laws | Audiences shown | Build / dig / upgrade |
| --- | --- | --- | --- | --- | --- | --- |
| careful | 1.76 | 0.00 | 0.64 | 0.05 | 0.56 | 0.53 |
| expander | 1.78 | 0.00 | 1.77 | 0.00 | 0.64 | 0.55 |
| follower | 1.75 | 0.00 | 0.16 | 0.02 | 0.53 | 0.51 |

Emptiest and busiest week numbers across all 90 runs (mean decisions and events shown in that week):

| Emptiest week | Decisions | Events | | Busiest week | Decisions | Events |
| --- | --- | --- | --- | --- | --- | --- |
| 3 | 1.42 | 1.07 | | 13 | 5.18 | 3.34 |
| 29 | 1.93 | 1.53 | | 14 | 4.89 | 2.84 |
| 36 | 2.02 | 1.56 | | 17 | 4.77 | 1.82 |
| 28 | 2.03 | 1.52 | | 9 | 4.66 | 3.08 |
| 35 | 2.30 | 1.63 | | 10 | 4.62 | 2.49 |

## 3. Run-time estimate

Assumptions (brief): event choice 25 s, order 12 s, law 30 s, audience 40 s, reading the dawn report 20 s per week, building and assigning 60 s per week. A normal new player takes those times; careful x1.5, fast x0.6. Decision counts are the bots' (section 2), audiences counted when shown. The bots use fewer order seats than a player may: the second line puts every order seat to use (3 per week).

| Counts from | Player | Minutes per week (mean, min..max run) | 40 weeks, hours (mean, min..max run) |
| --- | --- | --- | --- |
| bots | careful | 4.0 (3.5..4.6) | 2.64 (2.34..3.04) |
| bots | normal | 2.6 (2.3..3.0) | 1.76 (1.56..2.03) |
| bots | fast | 1.6 (1.4..1.8) | 1.05 (0.93..1.22) |
| all seats | careful | 4.6 (4.4..4.8) | 3.07 (2.91..3.17) |
| all seats | normal | 3.1 (2.9..3.2) | 2.04 (1.94..2.11) |
| all seats | fast | 1.8 (1.7..1.9) | 1.23 (1.16..1.27) |

Runs that ended before week 40 are scaled to 40 weeks at their own weekly rate. The fixed part (dawn report and building) is 80 s, that is 1.3 minutes a week and 0.9 hours over 40 weeks for a normal player.

## 4. Dead ends

Endings reached:

| Style | Ending (week) counts | Runs with sim errors |
| --- | --- | --- |
| careful | time x30 | 0 |
| expander | time x29, revolt (week 35) x1 | 0 |
| follower | time x29, revolt (week 35) x1 | 0 |

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
| 14 | time | time | revolt w35 |
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

Events that never fired in any run (5 of 49): lc_depot_accepted, lc_directorate_accepted, lc_synod_accepted, lc_exchange_accepted, lc_lamp_accepted

Upkeep events built at run time in `sim/game.gd`, not in events.json (presentations): pantry 66, belt 66, dynamo 42, stacks 24, ducts 48, shopbelt 24

Choices never picked in events that did fire (30): quarrel/shut, preacher/stop, smuggler/refuse, rumble/push, static/ignore, wire/trade, leak/buckets, nightshift/order, ration/hold, tools/drop, scrap/leave, overtime/keep, hymn/quiet, drill/stay, lamps_next/move, refugees_next/names, quarrel_next/split, preacher_next/no, smuggler_next/end, rumble_next/up, static_next/stop, desertion_next/box, cough_next/push, leak_next/move, lc_depot_refused/dark, lc_directorate_refused/coin, lc_exchange_refused/refuse, lc_exchange_refused/work, lc_lamp_refused/food, lc_lamp_refused/choice

Choices only ever taken by the night resolve, never by a bot (0): none

Presentations per event over all 90 runs (most to least):

refugees 308, refugees_next 258, market_food 176, quarrel 175, wire 170, clog 169, smuggler 169, hymn 169, salt 168, tools 168, leak 167, ration 167, preacher 167, scrap 167, overtime 166, quarrel_next 164, nightshift 162, market_next 161, bunks 159, cough 154, drill 153, leak_next 149, smuggler_next 147, clog_next 146, preacher_next 145, desertion 142, cough_next 130, static 113, desertion_next 106, lc_exchange_refused 90, lc_synod_refused 90, queens_expedition 90, garden_mold 90, moles_vents 90, generator_sabotage 90, showtime_betting 90, lc_depot_refused 90, lc_lamp_refused 85, lamps_next 83, lamps 83, static_next 81, lc_directorate_refused 75, rumble 28, rumble_next 24, lc_directorate_accepted 0, lc_synod_accepted 0, lc_exchange_accepted 0, lc_depot_accepted 0, lc_lamp_accepted 0

## 5. Leader deals

Audiences shown per run (mean / min / max over seeds) and deals accepted by the bot:

| Leader | careful shown | careful accepted | expander shown | expander accepted | follower shown | follower accepted |
| --- | --- | --- | --- | --- | --- | --- |
| depot | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 |
| directorate | 3.9 / 0.0 / 6.0 | 0 of 30 | 5.8 / 5.0 / 6.0 | 0 of 30 | 3.7 / 0.0 / 6.0 | 0 of 30 |
| synod | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 4.0 / 5.0 | 0 of 30 | 5.0 / 4.0 / 5.0 | 0 of 30 |
| exchange | 6.0 / 6.0 / 6.0 | 0 of 30 | 6.0 / 5.0 / 6.0 | 0 of 30 | 5.9 / 5.0 / 6.0 | 0 of 30 |
| black_flag | 2.4 / 2.0 / 3.0 | 0 of 30 | 3.8 / 3.0 / 4.0 | 0 of 30 | 1.7 / 0.0 / 3.0 | 0 of 30 |

These runs use the silence audience style: a leader left waiting is turned away by silence at the next dawn, which the game records as a refusal with the deed "silence" and which the leader consequence events treat as refused. The forks below answer for the bot.

Forks: 142 (seeds 1 to 10, all styles, first audience of each leader). Each row compares the accept or refuse branch with the silence branch at the same week: right after the answer (t0), 5 weeks later and 10 weeks later. Counts are forks where the item differs.

| Leader | Branch | Forks | Blocked | When | Flag set | Own standing (mean diff) | Other standings moved | Law | Pop (mean diff) | Hope (mean diff) | Events differ | Journal rows differ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| depot | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | -4.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +10.5 | 30 | 0 | -0.03 | -2.1 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +10.0 | 30 | 11 | -0.10 | +0.7 | 30 | 30 |
| depot | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| directorate | accept | 22 | 0 | t0 | 22 | +30.0 | 22 | 22 | -1.00 | -8.0 | 0 | 22 |
|  |  | 0 | 0 | t5 | 22 | +38.7 | 22 | 22 | -0.86 | -10.6 | 21 | 22 |
|  |  | 0 | 0 | t10 | 22 | +39.3 | 22 | 21 | -1.45 | -11.5 | 21 | 22 |
| directorate | refuse | 22 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 22 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 22 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 22 |
| synod | accept | 30 | 0 | t0 | 30 | +30.0 | 30 | 0 | +0.00 | +12.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +30.3 | 30 | 0 | +0.27 | +10.5 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +30.3 | 30 | 0 | +1.63 | +3.8 | 30 | 30 |
| synod | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| exchange | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +17.8 | 30 | 0 | +3.50 | +3.2 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +15.3 | 30 | 0 | +2.83 | +1.6 | 30 | 30 |
| exchange | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| black_flag | accept | 30 | 0 | t0 | 30 | +20.0 | 30 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +21.9 | 30 | 0 | -0.67 | +0.7 | 29 | 30 |
|  |  | 0 | 0 | t10 | 30 | +21.9 | 30 | 0 | +0.87 | +0.8 | 29 | 30 |
| black_flag | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |

Journal rows that differ from the silence branch by week +10 (row kind:result, number of forks), and event ids shown in one branch only (mean per fork). The sim draws all events from one random stream, so any change of state shifts later draws; the leader consequence events (section 7) read the first answer, not the deal flags:

| Leader | Branch | Journal rows that differ | Event ids in one branch only (mean per fork) |
| --- | --- | --- | --- |
| depot | accept | audience:deal (30), audience:silence (30), born (4), build (6), built (6), dig (7), event (3), find (4), law (11), order (5), papers_burned (30), pump (1), upgrade (3) | 4.6 |
| depot | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| directorate | accept | audience:deal (22), audience:silence (21), born (13), build (11), built (11), deaths (1), dig (9), event (2), find (5), handed_over (22), law (1), order (16), pump (1), regard (17), repeal (1), station (5) | 6.4 |
| directorate | refuse | audience:refused (22), audience:silence (21) | 0.0 |
| synod | accept | audience:deal (30), audience:silence (30), born (9), build (11), built (12), dig (14), event (7), find (9), law (18), order (4), regard (10), station (4) | 6.2 |
| synod | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| exchange | accept | audience:deal (30), audience:silence (30), born (23), build (6), built (6), deaths (4), dig (8), event (22), find (6), order (11), regard (10), station (11) | 12.8 |
| exchange | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| black_flag | accept | audience:deal (30), audience:silence (30), born (7), build (9), built (9), dig (1), event (7), false_way (30), find (1), order (5), station (2) | 5.2 |
| black_flag | refuse | audience:refused (30), audience:silence (30) | 0.0 |

Where each deal flag is read after it is set (`flags.has`, `flags.get`, `flags[...]` or `flags.<name>` in `sim/` and `ui/`, and the flag name in any event or data condition):

| Leader | Deal | Flag | Read in |
| --- | --- | --- | --- |
| depot | burn_papers | buried_papers | nowhere |
| directorate | the_list | collaborator | ui/station.gd lines 3704, 3705 |
| synod | stay_down | stayed_down | nowhere |
| exchange | open_books | open_books | nowhere |
| black_flag | lantern_toll | lantern_toll | nowhere |

Readers of the other state a deal changes, from `sim/game.gd`: `audience_deals` stops that leader coming back (`audience_eligible`); `leader_answers` (first answer and its week) opens that leader's consequence event; `standing` feeds the leader's band, which picks the leader's lines, the audience cooldown and the lantern toll; `standing_memory` is shown on the leader card. Outside the audience code, the consequence events and their tests, nothing in `sim/` reads standing (no map, order or trade rule).

Silence branches replayed from an exported state: 142; branches with a load error: 0.

## 7. Leader consequences by audience style

Audience styles (`Bot.audience_style`): silence leaves every leader waiting; accept_all takes every deal it can pay for (a deal it cannot pay for is left waiting, which counts as silence); refuse_all turns everyone away; mixed accepts the Synod and the Exchange and refuses the others. Event choices are the bot style's own (careful, expander, follower), unchanged. 90 runs per audience style.

First answer per leader (`leader_answers`), runs out of 90 per audience style. "none" = the leader never came or was never answered before the run ended:

| Leader | Audience style | accepted | refused | silence | none | Mean answer week |
| --- | --- | --- | --- | --- | --- | --- |
| depot | silence | 0 | 0 | 90 | 0 | 6.0 |
|  | accept_all | 90 | 0 | 0 | 0 | 6.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 6.0 |
|  | mixed | 0 | 90 | 0 | 0 | 6.0 |
| directorate | silence | 0 | 0 | 76 | 14 | 7.6 |
|  | accept_all | 78 | 0 | 0 | 12 | 7.7 |
|  | refuse_all | 0 | 77 | 0 | 13 | 8.0 |
|  | mixed | 0 | 79 | 0 | 11 | 8.1 |
| synod | silence | 0 | 0 | 90 | 0 | 10.0 |
|  | accept_all | 90 | 0 | 0 | 0 | 10.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 10.0 |
|  | mixed | 90 | 0 | 0 | 0 | 10.0 |
| exchange | silence | 0 | 0 | 90 | 0 | 2.7 |
|  | accept_all | 90 | 0 | 0 | 0 | 2.7 |
|  | refuse_all | 0 | 90 | 0 | 0 | 2.7 |
|  | mixed | 90 | 0 | 0 | 0 | 2.7 |
| black_flag | silence | 0 | 0 | 87 | 3 | 25.1 |
|  | accept_all | 88 | 0 | 1 | 1 | 24.5 |
|  | refuse_all | 0 | 88 | 0 | 2 | 25.2 |
|  | mixed | 0 | 89 | 0 | 1 | 25.3 |

How often each consequence fires. Due = runs where the matching answer (refused also matches silence) was given in week 37 or earlier, the brief's "at least 3 weeks before week 40"; cut short = due runs that ended before the window opened. Target: fired in at least 95 percent of due runs. Fired late = shown with fewer weeks left in its window than it had when it opened (held by a major event).

| Event | Needs | Due | Cut short | Fired | Fired of due | Weeks after the answer (mean) | Held at least one dawn |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lc_depot_accepted | depot accepted 3..10 | 90 | 0 | 90 | 100% | 3.3 | 25 |
| lc_depot_refused | depot refused 3..10 | 270 | 0 | 270 | 100% | 3.3 | 76 |
| lc_directorate_accepted | directorate accepted 3..10 | 78 | 0 | 78 | 100% | 3.3 | 21 |
| lc_directorate_refused | directorate refused 3..10 | 229 | 0 | 229 | 100% | 3.3 | 69 |
| lc_synod_accepted | synod accepted 3..10 | 180 | 0 | 180 | 100% | 3.6 | 106 |
| lc_synod_refused | synod refused 3..10 | 180 | 0 | 180 | 100% | 3.6 | 106 |
| lc_exchange_accepted | exchange accepted 3..10 | 180 | 0 | 180 | 100% | 3.6 | 71 |
| lc_exchange_refused | exchange refused 3..10 | 180 | 0 | 180 | 100% | 3.5 | 74 |
| lc_lamp_accepted | black_flag accepted 3..10 | 85 | 0 | 85 | 100% | 3.1 | 6 |
| lc_lamp_refused | black_flag refused 3..10 | 256 | 0 | 255 | 100% | 3.1 | 29 |

All consequences: fired in 1727 of 1728 due runs (99.9%); lowest single event 100%.

What each choice moved when the bot (or the night resolve) took it, mean over all picks in all 360 runs. Standing is the event's own leader; changes are after clamping:

| Event | Choice | Picks | Hope | Discontent | Standing |
| --- | --- | --- | --- | --- | --- |
| lc_depot_accepted | copy | 18 | -1.00 | +0.00 | +5.00 |
|  | truth | 72 | +2.00 | +2.00 | -10.00 |
|  | bernie | 0 | - | - | - |
| lc_depot_refused | ask | 268 | +0.00 | +0.00 | +5.00 |
|  | strip | 2 | +0.00 | +0.00 | +0.00 |
|  | dark | 0 | - | - | - |
| lc_directorate_accepted | silence | 60 | -1.00 | -2.00 | +0.00 |
|  | necessary | 18 | +0.00 | +2.00 | +5.00 |
|  | nothing | 0 | - | - | - |
| lc_directorate_refused | count | 63 | +0.00 | +1.00 | +5.00 |
|  | refuse | 166 | +0.00 | +0.00 | -12.00 |
|  | coin | 0 | - | - | - |
| lc_synod_accepted | let | 46 | -3.00 | +0.00 | +0.00 |
|  | forbid | 14 | +0.00 | +3.00 | +5.00 |
|  | dorothy | 120 | +1.00 | +0.00 | +5.00 |
| lc_synod_refused | soup | 60 | +1.00 | +0.00 | +5.00 |
|  | go | 120 | +0.00 | +1.00 | +2.00 |
| lc_exchange_accepted | accept | 60 | +0.00 | +2.00 | +0.00 |
|  | haggle | 0 | - | - | - |
|  | tear | 120 | +1.00 | +0.00 | -10.00 |
| lc_exchange_refused | pay | 180 | +0.00 | +0.00 | +3.00 |
|  | refuse | 0 | - | - | - |
|  | work | 0 | - | - | - |
| lc_lamp_accepted | give | 85 | +2.00 | +0.00 | +5.00 |
|  | toll | 0 | - | - | - |
|  | look | 0 | - | - | - |
| lc_lamp_refused | search | 255 | +1.00 | +0.00 | +3.00 |
|  | food | 0 | - | - | - |
|  | choice | 0 | - | - | - |

Endings and meters per bot style and audience style (report only, nothing tuned). Hope min and discontent max are the run's extremes at the end of each week, mean over seeds:

| Bot style | Audience style | Endings | Collapse, hope or revolt endings | Hope min (mean) | Discontent max (mean, worst) |
| --- | --- | --- | --- | --- | --- |
| careful | silence | time x30 | 0 | 38.1 | 54.7, 59 |
|  | accept_all | time x30 | 0 | 36.9 | 26.7, 55 |
|  | refuse_all | time x30 | 0 | 38.1 | 54.7, 59 |
|  | mixed | time x30 | 0 | 38.9 | 53.7, 58 |
| expander | silence | time x29, revolt (week 35) x1 | 1 | 38.5 | 75.0, 100 |
|  | accept_all | time x30 | 0 | 24.1 | 21.9, 35 |
|  | refuse_all | time x29, revolt (week 35) x1 | 1 | 38.5 | 75.0, 100 |
|  | mixed | time x28, revolt (week 37) x1, revolt (week 35) x1 | 2 | 48.2 | 80.6, 100 |
| follower | silence | time x29, revolt (week 35) x1 | 1 | 45.3 | 60.4, 100 |
|  | accept_all | time x30 | 0 | 38.5 | 56.5, 68 |
|  | refuse_all | time x29, revolt (week 35) x1 | 1 | 45.3 | 60.4, 100 |
|  | mixed | time x27, revolt (week 40) x2, revolt (week 38) x1 | 3 | 42.6 | 67.7, 100 |

## 6. What looks thin (facts from the tables above)

- Catalog events: 40 with 2 choices, 9 with 3 choices; the 6 upkeep events built in `sim/game.gd` are pay or suffer.
- A 40-week run shows 44.4 distinct event ids on average out of 55 possible (49 catalog + 6 upkeep); 22.7 of them come up twice or more. Rumble and its follow-up came up 28 and 24 times in 90 runs.
- No bot style picked 30 of the 92 choices in events that fired.
- Endings: 88 of 90 runs ended on time (week 40); never reached: collapse, hope, capital.
- Artifacts: only papers has a source in the sim; iron, words are declared with no source.
- Backstories: 5 for 25 named residents.
- Every week had at least one event and one decision (longest gap 0 weeks, 0.0 empty weeks per run).
- Leader deals: accepted 0 times over the 90 silence-style runs. An accepted deal sets its flag, moves standing and changes meters at once; no sim rule reads any of the five deal flags afterwards (`collaborator` is read by the UI for one dossier line); the consequence events read the first answer instead (section 7).
- Refusing and leaving a leader waiting end the same in every fork at +10 weeks except for the audience row's result (refused or silence); the consequence events treat both as refused.

