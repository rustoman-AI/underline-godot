# Content audit 20261011

Measured with `.tools/content_audit.gd` on the current data and sim, 30 seeds for each of the bot styles careful, expander, follower and each audience style silence, accept_all, refuse_all, mixed, helper, helper_mixed (540 runs of 40 weeks), leader forks on seeds 1 to 10. Facts only, no proposals. The bots are not players: they decide instantly and use the same rules each week. Sections 1 to 6 use the silence audience style (the bot never answers, so every leader is turned away by silence, as before audience styles existed): 90 runs. Section 7 compares the audience styles.

## 1. Counts

| Item | Count | Detail |
| --- | --- | --- |
| Events, all | 65 | 2 major, 46 minor, 5 check, 12 follow-up only (chain_only) |
| Events with a follow-up | 12 | follow-up text varies by the earlier choice in 12 |
| Events with their own cooldown | 48 | global cooldown 8 weeks, minor events capped at 2 per run (balance.json) |
| Choices per event | 2 / 2.2 / 3 | min / mean / max over all 65 events |
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
| careful | 1.90 / 1.80 / 1.98 | 51 / 47 / 54 | 22 / 17 / 26 | 0 / 0 / 1 | 0 / 0 / 0 | 3.16 / 2.88 / 3.52 |
| expander | 1.93 / 1.85 / 2.00 | 52 / 48 / 54 | 23 / 19 / 27 | 0 / 0 / 0 | 0 / 0 / 0 | 4.31 / 3.98 / 5.17 |
| follower | 1.90 / 1.83 / 1.98 | 51 / 48 / 54 | 23 / 20 / 26 | 0 / 0 / 0 | 0 / 0 / 0 | 2.63 / 2.48 / 2.75 |

Decisions per week by type (mean over all runs and weeks):

| Style | Event choices (bot) | Event choices (night) | Orders | Laws | Audiences shown | Build / dig / upgrade |
| --- | --- | --- | --- | --- | --- | --- |
| careful | 1.92 | 0.00 | 0.63 | 0.05 | 0.56 | 0.54 |
| expander | 1.96 | 0.00 | 1.71 | 0.00 | 0.64 | 0.55 |
| follower | 1.93 | 0.00 | 0.14 | 0.02 | 0.53 | 0.51 |

Emptiest and busiest week numbers across all 90 runs (mean decisions and events shown in that week):

| Emptiest week | Decisions | Events | | Busiest week | Decisions | Events |
| --- | --- | --- | --- | --- | --- | --- |
| 29 | 1.82 | 1.47 | | 17 | 5.37 | 2.42 |
| 36 | 1.96 | 1.54 | | 13 | 5.12 | 3.37 |
| 28 | 2.07 | 1.53 | | 14 | 5.02 | 3.04 |
| 35 | 2.14 | 1.56 | | 16 | 4.81 | 2.68 |
| 26 | 2.28 | 1.47 | | 9 | 4.78 | 3.20 |

## 3. Run-time estimate

Assumptions (brief): event choice 25 s, order 12 s, law 30 s, audience 40 s, reading the dawn report 20 s per week, building and assigning 60 s per week. A normal new player takes those times; careful x1.5, fast x0.6. Decision counts are the bots' (section 2), audiences counted when shown. The bots use fewer order seats than a player may: the second line puts every order seat to use (3 per week).

| Counts from | Player | Minutes per week (mean, min..max run) | 40 weeks, hours (mean, min..max run) |
| --- | --- | --- | --- |
| bots | careful | 4.1 (3.7..4.7) | 2.70 (2.44..3.11) |
| bots | normal | 2.7 (2.4..3.1) | 1.80 (1.63..2.07) |
| bots | fast | 1.6 (1.5..1.9) | 1.08 (0.98..1.24) |
| all seats | careful | 4.7 (4.5..4.8) | 3.14 (3.01..3.22) |
| all seats | normal | 3.1 (3.0..3.2) | 2.09 (2.00..2.15) |
| all seats | fast | 1.9 (1.8..1.9) | 1.25 (1.20..1.29) |

Runs that ended before week 40 are scaled to 40 weeks at their own weekly rate. The fixed part (dawn report and building) is 80 s, that is 1.3 minutes a week and 0.9 hours over 40 weeks for a normal player.

## 4. Dead ends

Endings reached:

| Style | Ending (week) counts | Runs with sim errors |
| --- | --- | --- |
| careful | time x30 | 0 |
| expander | time x28, revolt (week 40) x1, revolt (week 36) x1 | 0 |
| follower | time x29, revolt (week 40) x1 | 0 |

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
| 14 | time | time | revolt w40 |
| 15 | time | time | time |
| 16 | time | time | time |
| 17 | time | time | time |
| 18 | time | revolt w40 | time |
| 19 | time | time | time |
| 20 | time | time | time |
| 21 | time | time | time |
| 22 | time | time | time |
| 23 | time | time | time |
| 24 | time | time | time |
| 25 | time | revolt w36 | time |
| 26 | time | time | time |
| 27 | time | time | time |
| 28 | time | time | time |
| 29 | time | time | time |
| 30 | time | time | time |

Events that never fired in any run (14 of 65): lc_depot_accepted, lc_directorate_accepted, lc_synod_accepted, lc_exchange_accepted, lc_lamp_accepted, st2_depot_dirty, st2_dir_honest, st2_dir_dirty, st2_synod_honest, st2_synod_dirty, st2_exchange_honest, st2_exchange_dirty, st2_lamp_honest, st2_lamp_dirty

Upkeep events built at run time in `sim/game.gd`, not in events.json (presentations): pantry 66, belt 66, dynamo 42, stacks 24, ducts 48, shopbelt 24

Choices never picked in events that did fire (39): quarrel/shut, preacher/stop, smuggler/refuse, rumble/push, static/ignore, wire/trade, leak/buckets, nightshift/order, ration/hold, tools/drop, scrap/leave, overtime/keep, hymn/quiet, drill/stay, lamps_next/move, refugees_next/names, quarrel_next/split, preacher_next/no, smuggler_next/end, rumble_next/up, static_next/stop, desertion_next/box, cough_next/push, leak_next/move, lc_depot_refused/dark, lc_directorate_refused/coin, lc_exchange_refused/refuse, lc_exchange_refused/work, lc_lamp_refused/food, lc_lamp_refused/choice, st1_first_paper/burn, st1_counting/trace, st1_counting/forbid, st1_names/private, st1_names/no, st1_floor_rumor/ignore, st1_story_night/short, st1_story_night/skip, st1_child/dorothy

Choices only ever taken by the night resolve, never by a bot (0): none

Presentations per event over all 90 runs (most to least):

refugees 320, refugees_next 257, market_food 180, quarrel 176, bunks 170, clog 169, hymn 169, leak 169, wire 168, scrap 166, salt 166, tools 166, ration 166, market_next 165, overtime 165, smuggler 165, nightshift 162, preacher 162, drill 161, quarrel_next 161, cough 156, clog_next 152, leak_next 148, smuggler_next 146, preacher_next 141, cough_next 133, desertion 125, static 116, desertion_next 95, st1_child 90, st1_story_night 90, st1_floor_rumor 90, st1_names 90, st1_first_paper 90, lc_exchange_refused 90, st2_depot_honest 90, queens_expedition 90, garden_mold 90, moles_vents 90, generator_sabotage 90, showtime_betting 90, lc_synod_refused 90, lc_depot_refused 90, st1_counting 89, lc_lamp_refused 85, static_next 84, lamps 83, lamps_next 83, lc_directorate_refused 74, rumble 24, rumble_next 22, st2_lamp_dirty 0, st2_lamp_honest 0, st2_exchange_dirty 0, st2_exchange_honest 0, st2_synod_dirty 0, st2_synod_honest 0, st2_dir_dirty 0, st2_dir_honest 0, st2_depot_dirty 0, lc_depot_accepted 0, lc_directorate_accepted 0, lc_synod_accepted 0, lc_lamp_accepted 0, lc_exchange_accepted 0

## 5. Leader deals

Audiences shown per run (mean / min / max over seeds) and deals accepted by the bot:

| Leader | careful shown | careful accepted | expander shown | expander accepted | follower shown | follower accepted |
| --- | --- | --- | --- | --- | --- | --- |
| depot | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 |
| directorate | 3.9 / 0.0 / 6.0 | 0 of 30 | 5.8 / 5.0 / 6.0 | 0 of 30 | 3.7 / 0.0 / 6.0 | 0 of 30 |
| synod | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 4.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 |
| exchange | 6.0 / 6.0 / 6.0 | 0 of 30 | 6.0 / 5.0 / 6.0 | 0 of 30 | 5.9 / 5.0 / 6.0 | 0 of 30 |
| black_flag | 2.4 / 2.0 / 3.0 | 0 of 30 | 3.8 / 3.0 / 4.0 | 0 of 30 | 1.8 / 0.0 / 3.0 | 0 of 30 |

These runs use the silence audience style: a leader left waiting is turned away by silence at the next dawn, which the game records as a refusal with the deed "silence" and which the leader consequence events treat as refused. The forks below answer for the bot.

Forks: 143 (seeds 1 to 10, all styles, first audience of each leader). Each row compares the accept or refuse branch with the silence branch at the same week: right after the answer (t0), 5 weeks later and 10 weeks later. Counts are forks where the item differs.

| Leader | Branch | Forks | Blocked | When | Flag set | Own standing (mean diff) | Other standings moved | Law | Pop (mean diff) | Hope (mean diff) | Events differ | Journal rows differ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| depot | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | -4.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +11.5 | 30 | 0 | -0.03 | -2.1 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +10.3 | 30 | 9 | -0.20 | +0.3 | 30 | 30 |
| depot | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| directorate | accept | 23 | 0 | t0 | 23 | +30.0 | 23 | 23 | -1.00 | -8.0 | 0 | 23 |
|  |  | 0 | 0 | t5 | 23 | +38.9 | 23 | 23 | -1.30 | -11.3 | 22 | 23 |
|  |  | 0 | 0 | t10 | 23 | +37.9 | 23 | 21 | -2.17 | -11.7 | 22 | 23 |
| directorate | refuse | 23 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 23 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 23 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 23 |
| synod | accept | 30 | 0 | t0 | 30 | +30.0 | 30 | 0 | +0.00 | +12.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +30.3 | 30 | 0 | +0.17 | +10.9 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +32.4 | 30 | 0 | +1.03 | +3.6 | 30 | 30 |
| synod | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| exchange | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +17.8 | 30 | 0 | +3.50 | +3.1 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +15.3 | 30 | 0 | +2.57 | +1.5 | 30 | 30 |
| exchange | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| black_flag | accept | 30 | 0 | t0 | 30 | +20.0 | 30 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +19.4 | 30 | 0 | -0.20 | +0.8 | 29 | 30 |
|  |  | 0 | 0 | t10 | 30 | +19.2 | 30 | 0 | -0.53 | +1.0 | 29 | 30 |
| black_flag | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |

Journal rows that differ from the silence branch by week +10 (row kind:result, number of forks), and event ids shown in one branch only (mean per fork). The sim draws all events from one random stream, so any change of state shifts later draws; the leader consequence events (section 7) read the first answer, not the deal flags:

| Leader | Branch | Journal rows that differ | Event ids in one branch only (mean per fork) |
| --- | --- | --- | --- |
| depot | accept | audience:deal (30), audience:silence (30), born (3), build (7), built (7), dig (7), event (3), find (3), law (9), order (2), papers_burned (30), pump (1), regard (9), truth (4), upgrade (3) | 5.7 |
| depot | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| directorate | accept | audience:deal (23), audience:silence (22), born (12), build (12), built (12), deaths (1), dig (8), event (2), find (4), handed_over (23), law (2), order (16), pump (1), regard (18), repeal (2), station (4), truth (7) | 6.8 |
| directorate | refuse | audience:refused (23), audience:silence (22) | 0.0 |
| synod | accept | audience:deal (30), audience:silence (30), born (8), build (10), built (9), dig (10), event (26), find (7), law (17), order (6), regard (28), station (2), truth (10) | 7.3 |
| synod | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| exchange | accept | audience:deal (30), audience:silence (30), born (23), build (7), built (7), deaths (4), dig (8), event (23), find (6), order (11), regard (10), station (11) | 13.7 |
| exchange | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| black_flag | accept | audience:deal (30), audience:silence (30), born (8), build (4), built (4), dig (1), event (24), false_way (30), find (1), order (6), rally (1), regard (27), station (2), truth (27) | 5.4 |
| black_flag | refuse | audience:refused (30), audience:silence (30) | 0.0 |

Where each deal flag is read after it is set (`flags.has`, `flags.get`, `flags[...]` or `flags.<name>` in `sim/` and `ui/`, and the flag name in any event or data condition):

| Leader | Deal | Flag | Read in |
| --- | --- | --- | --- |
| depot | burn_papers | buried_papers | data/events_story.json lines 234, 270 |
| directorate | the_list | collaborator | ui/station.gd lines 3822, 3823, data/events_story.json lines 303, 340 |
| synod | stay_down | stayed_down | data/events_story.json lines 378, 415 |
| exchange | open_books | open_books | data/events_story.json lines 452, 499 |
| black_flag | lantern_toll | lantern_toll | data/events_story.json lines 537, 579 |

Readers of the other state a deal changes, from `sim/game.gd`: `audience_deals` stops that leader coming back (`audience_eligible`); `leader_answers` (first answer and its week) opens that leader's consequence event; `standing` feeds the leader's band, which picks the leader's lines, the audience cooldown and the lantern toll; `standing_memory` is shown on the leader card. Outside the audience code, the consequence events and their tests, nothing in `sim/` reads standing (no map, order or trade rule).

Silence branches replayed from an exported state: 143; branches with a load error: 0.

## 7. Leader consequences by audience style

Audience styles (`Bot.audience_style`): silence leaves every leader waiting; accept_all takes every deal it can pay for (a deal it cannot pay for is left waiting, which counts as silence); refuse_all turns everyone away; mixed accepts the Synod and the Exchange and refuses the others; helper offers help whenever it can pay and never takes a deal; helper_mixed offers help to everyone and takes the Synod's and the Exchange's deal after helping them. Event choices are the bot style's own (careful, expander, follower), unchanged. 90 runs per audience style.

First answer per leader (`leader_answers`), runs out of 90 per audience style. "none" = the leader never came or was never answered before the run ended:

| Leader | Audience style | accepted | refused | silence | helped | none | Mean answer week |
| --- | --- | --- | --- | --- | --- | --- | --- |
| depot | silence | 0 | 0 | 90 | 0 | 0 | 6.0 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 6.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 6.0 |
|  | mixed | 0 | 90 | 0 | 0 | 0 | 6.0 |
|  | helper | 0 | 0 | 18 | 72 | 0 | 9.2 |
|  | helper_mixed | 0 | 0 | 11 | 79 | 0 | 8.7 |
| directorate | silence | 0 | 0 | 75 | 0 | 15 | 7.3 |
|  | accept_all | 79 | 0 | 0 | 0 | 11 | 8.1 |
|  | refuse_all | 0 | 76 | 0 | 0 | 14 | 7.7 |
|  | mixed | 0 | 78 | 0 | 0 | 12 | 7.8 |
|  | helper | 0 | 0 | 22 | 61 | 7 | 11.9 |
|  | helper_mixed | 0 | 0 | 22 | 56 | 12 | 14.8 |
| synod | silence | 0 | 0 | 90 | 0 | 0 | 10.0 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 10.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 10.0 |
|  | mixed | 90 | 0 | 0 | 0 | 0 | 10.0 |
|  | helper | 0 | 0 | 27 | 63 | 0 | 12.1 |
|  | helper_mixed | 90 | 0 | 0 | 0 | 0 | 16.0 |
| exchange | silence | 0 | 0 | 90 | 0 | 0 | 2.7 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 2.7 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 2.7 |
|  | mixed | 90 | 0 | 0 | 0 | 0 | 2.7 |
|  | helper | 0 | 0 | 26 | 64 | 0 | 7.2 |
|  | helper_mixed | 90 | 0 | 0 | 0 | 0 | 9.1 |
| black_flag | silence | 0 | 0 | 88 | 0 | 2 | 25.3 |
|  | accept_all | 87 | 0 | 1 | 0 | 2 | 24.3 |
|  | refuse_all | 0 | 89 | 0 | 0 | 1 | 25.4 |
|  | mixed | 0 | 87 | 0 | 0 | 3 | 24.9 |
|  | helper | 0 | 0 | 7 | 82 | 1 | 27.4 |
|  | helper_mixed | 0 | 0 | 6 | 80 | 4 | 27.0 |

How often each consequence fires. Due = runs where the matching answer (refused also matches silence) was given in week 37 or earlier, the brief's "at least 3 weeks before week 40"; cut short = due runs that ended before the window opened. Target: fired in at least 95 percent of due runs. Fired late = shown with fewer weeks left in its window than it had when it opened (held by a major event).

| Event | Needs | Due | Cut short | Fired | Fired of due | Weeks after the answer (mean) | Held at least one dawn |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lc_depot_accepted | depot accepted 3..10 | 90 | 0 | 90 | 100% | 3.3 | 24 |
| lc_depot_refused | depot refused 3..10 | 299 | 0 | 299 | 100% | 3.3 | 78 |
| lc_directorate_accepted | directorate accepted 3..10 | 78 | 0 | 78 | 100% | 3.3 | 19 |
| lc_directorate_refused | directorate refused 3..10 | 268 | 0 | 268 | 100% | 3.3 | 74 |
| lc_synod_accepted | synod accepted 3..10 | 270 | 0 | 270 | 100% | 3.5 | 123 |
| lc_synod_refused | synod refused 3..10 | 203 | 0 | 203 | 100% | 3.6 | 118 |
| lc_exchange_accepted | exchange accepted 3..10 | 270 | 0 | 270 | 100% | 3.4 | 78 |
| lc_exchange_refused | exchange refused 3..10 | 206 | 0 | 206 | 100% | 3.5 | 74 |
| lc_lamp_accepted | black_flag accepted 3..10 | 83 | 0 | 83 | 100% | 3.1 | 9 |
| lc_lamp_refused | black_flag refused 3..10 | 267 | 0 | 264 | 99% | 3.1 | 16 |

All consequences: fired in 2031 of 2034 due runs (99.9%); lowest single event 99%.

What each choice moved when the bot (or the night resolve) took it, mean over all picks in all 540 runs. Standing is the event's own leader; changes are after clamping:

| Event | Choice | Picks | Hope | Discontent | Standing |
| --- | --- | --- | --- | --- | --- |
| lc_depot_accepted | copy | 16 | -1.00 | +0.00 | +5.00 |
|  | truth | 74 | +2.00 | +2.00 | -10.00 |
|  | bernie | 0 | - | - | - |
| lc_depot_refused | ask | 290 | +0.00 | +0.00 | +4.83 |
|  | strip | 4 | +0.00 | +0.00 | +0.00 |
|  | dark | 5 | -1.00 | +3.00 | +0.00 |
| lc_directorate_accepted | silence | 61 | -1.00 | -2.00 | +0.00 |
|  | necessary | 17 | +0.00 | +2.00 | +5.00 |
|  | nothing | 0 | - | - | - |
| lc_directorate_refused | count | 103 | +0.00 | +1.00 | +5.00 |
|  | refuse | 165 | +0.00 | +0.00 | -12.00 |
|  | coin | 0 | - | - | - |
| lc_synod_accepted | let | 76 | -3.00 | +0.00 | +0.00 |
|  | forbid | 14 | +0.00 | +3.00 | +5.00 |
|  | dorothy | 180 | +1.00 | +0.00 | +5.00 |
| lc_synod_refused | soup | 60 | +1.00 | +0.00 | +5.00 |
|  | go | 143 | +0.00 | +1.00 | +2.00 |
| lc_exchange_accepted | accept | 90 | +0.00 | +2.00 | +0.00 |
|  | haggle | 0 | - | - | - |
|  | tear | 180 | +1.00 | +0.00 | -10.00 |
| lc_exchange_refused | pay | 191 | +0.00 | +0.00 | +3.00 |
|  | refuse | 15 | +0.00 | +0.00 | -10.00 |
|  | work | 0 | - | - | - |
| lc_lamp_accepted | give | 83 | +2.00 | +0.00 | +5.00 |
|  | toll | 0 | - | - | - |
|  | look | 0 | - | - | - |
| lc_lamp_refused | search | 264 | +1.00 | +0.00 | +3.00 |
|  | food | 0 | - | - | - |
|  | choice | 0 | - | - | - |

Endings and meters per bot style and audience style (report only, nothing tuned). Hope min and discontent max are the run's extremes at the end of each week, mean over seeds:

| Bot style | Audience style | Endings | Collapse, hope or revolt endings | Hope min (mean) | Discontent max (mean, worst) |
| --- | --- | --- | --- | --- | --- |
| careful | silence | time x30 | 0 | 38.6 | 53.1, 61 |
|  | accept_all | time x30 | 0 | 37.0 | 26.6, 54 |
|  | refuse_all | time x30 | 0 | 38.6 | 53.1, 61 |
|  | mixed | time x30 | 0 | 38.7 | 51.9, 57 |
|  | helper | time x30 | 0 | 39.2 | 57.0, 66 |
|  | helper_mixed | time x30 | 0 | 38.9 | 53.4, 59 |
| expander | silence | time x28, revolt (week 40) x1, revolt (week 36) x1 | 2 | 39.5 | 74.2, 100 |
|  | accept_all | time x30 | 0 | 24.7 | 21.6, 33 |
|  | refuse_all | time x28, revolt (week 40) x1, revolt (week 36) x1 | 2 | 39.5 | 74.2, 100 |
|  | mixed | time x28, revolt (week 37) x1, revolt (week 36) x1 | 2 | 50.8 | 78.9, 100 |
|  | helper | time x30 | 0 | 39.5 | 71.7, 93 |
|  | helper_mixed | time x30 | 0 | 47.7 | 74.2, 99 |
| follower | silence | time x29, revolt (week 40) x1 | 1 | 45.0 | 59.9, 100 |
|  | accept_all | time x30 | 0 | 37.9 | 54.3, 63 |
|  | refuse_all | time x29, revolt (week 40) x1 | 1 | 45.0 | 59.9, 100 |
|  | mixed | time x29, revolt (week 38) x1 | 1 | 42.5 | 63.0, 100 |
|  | helper | time x29, revolt (week 37) x1 | 1 | 40.6 | 62.5, 100 |
|  | helper_mixed | time x30 | 0 | 44.3 | 57.7, 70 |

## 6. What looks thin (facts from the tables above)

- Catalog events: 50 with 2 choices, 15 with 3 choices; the 6 upkeep events built in `sim/game.gd` are pay or suffer.
- A 40-week run shows 51.2 distinct event ids on average out of 71 possible (65 catalog + 6 upkeep); 22.7 of them come up twice or more. Rumble and its follow-up came up 24 and 22 times in 90 runs.
- No bot style picked 39 of the 111 choices in events that fired.
- Endings: 87 of 90 runs ended on time (week 40); never reached: collapse, hope, capital.
- Artifacts: only papers has a source in the sim; iron, words are declared with no source.
- Backstories: 5 for 25 named residents.
- Every week had at least one event and one decision (longest gap 1 weeks, 0.0 empty weeks per run).
- Leader deals: accepted 0 times over the 90 silence-style runs. An accepted deal sets its flag, moves standing and changes meters at once; no sim rule reads any of the five deal flags afterwards (`collaborator` is read by the UI for one dossier line); the consequence events read the first answer instead (section 7).
- Refusing and leaving a leader waiting end the same in every fork at +10 weeks except for the audience row's result (refused or silence); the consequence events treat both as refused.

