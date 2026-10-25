# Content audit 20261011

Measured with `.tools/content_audit.gd` on the current data and sim, 30 seeds for each of the bot styles careful, expander, follower and each audience style silence, accept_all, refuse_all, mixed, helper, helper_mixed (540 runs of 40 weeks), leader forks on seeds 1 to 10. Facts only, no proposals. The bots are not players: they decide instantly and use the same rules each week. Sections 1 to 6 use the silence audience style (the bot never answers, so every leader is turned away by silence, as before audience styles existed): 90 runs. Section 7 compares the audience styles.

## 1. Counts

| Item | Count | Detail |
| --- | --- | --- |
| Events, all | 72 | 6 major, 49 minor, 5 check, 12 follow-up only (chain_only) |
| Events with a follow-up | 12 | follow-up text varies by the earlier choice in 12 |
| Events with their own cooldown | 55 | global cooldown 8 weeks, minor events capped at 2 per run (balance.json) |
| Choices per event | 2 / 2.3 / 4 | min / mean / max over all 72 events |
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
| careful | 1.97 / 1.88 / 2.05 | 54 / 51 / 57 | 22 / 20 / 26 | 0 / 0 / 1 | 0 / 0 / 0 | 3.26 / 3.02 / 3.55 |
| expander | 1.99 / 1.90 / 2.10 | 54 / 51 / 56 | 23 / 19 / 27 | 0 / 0 / 0 | 0 / 0 / 0 | 4.38 / 4.00 / 5.25 |
| follower | 1.97 / 1.90 / 2.05 | 54 / 51 / 57 | 22 / 18 / 25 | 0 / 0 / 0 | 0 / 0 / 0 | 2.75 / 2.58 / 2.88 |

Decisions per week by type (mean over all runs and weeks):

| Style | Event choices (bot) | Event choices (night) | Orders | Laws | Audiences shown | Build / dig / upgrade |
| --- | --- | --- | --- | --- | --- | --- |
| careful | 2.00 | 0.00 | 0.62 | 0.05 | 0.59 | 0.54 |
| expander | 2.02 | 0.00 | 1.71 | 0.00 | 0.65 | 0.55 |
| follower | 2.00 | 0.00 | 0.14 | 0.02 | 0.59 | 0.51 |

Emptiest and busiest week numbers across all 90 runs (mean decisions and events shown in that week):

| Emptiest week | Decisions | Events | | Busiest week | Decisions | Events |
| --- | --- | --- | --- | --- | --- | --- |
| 29 | 1.76 | 1.39 | | 14 | 5.84 | 3.04 |
| 36 | 1.93 | 1.53 | | 17 | 5.71 | 2.80 |
| 40 | 2.14 | 1.44 | | 13 | 5.12 | 3.37 |
| 26 | 2.20 | 1.52 | | 16 | 4.86 | 2.70 |
| 32 | 2.24 | 1.46 | | 9 | 4.78 | 3.20 |

## 3. Run-time estimate

Assumptions (brief): event choice 25 s, order 12 s, law 30 s, audience 40 s, reading the dawn report 20 s per week, building and assigning 60 s per week. A normal new player takes those times; careful x1.5, fast x0.6. Decision counts are the bots' (section 2), audiences counted when shown. The bots use fewer order seats than a player may: the second line puts every order seat to use (3 per week).

| Counts from | Player | Minutes per week (mean, min..max run) | 40 weeks, hours (mean, min..max run) |
| --- | --- | --- | --- |
| bots | careful | 4.1 (3.8..4.7) | 2.75 (2.50..3.14) |
| bots | normal | 2.8 (2.5..3.1) | 1.84 (1.67..2.09) |
| bots | fast | 1.7 (1.5..1.9) | 1.10 (1.00..1.25) |
| all seats | careful | 4.8 (4.6..4.9) | 3.19 (3.07..3.25) |
| all seats | normal | 3.2 (3.1..3.3) | 2.13 (2.05..2.17) |
| all seats | fast | 1.9 (1.8..2.0) | 1.28 (1.23..1.30) |

Runs that ended before week 40 are scaled to 40 weeks at their own weekly rate. The fixed part (dawn report and building) is 80 s, that is 1.3 minutes a week and 0.9 hours over 40 weeks for a normal player.

## 4. Dead ends

Endings reached:

| Style | Ending (week) counts | Runs with sim errors |
| --- | --- | --- |
| careful | time x30 | 0 |
| expander | time x29, revolt (week 36) x1 | 0 |
| follower | time x29, revolt (week 37) x1 | 0 |

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
| 14 | time | time | revolt w37 |
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
| 25 | time | revolt w36 | time |
| 26 | time | time | time |
| 27 | time | time | time |
| 28 | time | time | time |
| 29 | time | time | time |
| 30 | time | time | time |

Events that never fired in any run (17 of 72): lc_depot_accepted, lc_directorate_accepted, lc_synod_accepted, lc_exchange_accepted, lc_lamp_accepted, st2_depot_dirty, st2_dir_honest, st2_dir_dirty, st2_synod_honest, st2_synod_dirty, st2_exchange_honest, st2_exchange_dirty, st2_lamp_honest, st2_lamp_dirty, st3_quarantine, st3_observatory, st3_decision

Upkeep events built at run time in `sim/game.gd`, not in events.json (presentations): pantry 66, belt 66, dynamo 42, stacks 24, ducts 48, shopbelt 24

Choices never picked in events that did fire (43): quarrel/shut, preacher/stop, smuggler/refuse, rumble/push, static/ignore, wire/trade, leak/buckets, nightshift/order, ration/hold, tools/drop, scrap/leave, overtime/keep, hymn/quiet, drill/stay, lamps_next/move, refugees_next/names, quarrel_next/split, preacher_next/no, smuggler_next/end, rumble_next/up, static_next/stop, desertion_next/box, cough_next/push, leak_next/move, lc_depot_refused/dark, lc_directorate_refused/coin, lc_exchange_refused/refuse, lc_exchange_refused/work, lc_lamp_refused/choice, st1_first_paper/burn, st1_counting/trace, st1_counting/forbid, st1_names/private, st1_names/no, st1_floor_rumor/ignore, st1_story_night/short, st1_story_night/skip, st1_child/dorothy, st3_floor/publish, st3_floor/hand, st3_floor/leave, st1_dosimeter/leave, st1_substation/no

Choices only ever taken by the night resolve, never by a bot (0): none

Presentations per event over all 90 runs (most to least):

refugees 318, refugees_next 264, market_food 179, quarrel 174, hymn 172, wire 172, tools 170, clog 169, smuggler 169, scrap 166, overtime 165, bunks 165, drill 164, ration 164, leak 164, nightshift 163, salt 163, preacher 161, market_next 160, quarrel_next 158, cough 157, clog_next 152, smuggler_next 149, leak_next 145, preacher_next 135, cough_next 132, desertion 125, static 114, desertion_next 91, lc_synod_refused 90, st2_depot_honest 90, st1_substation 90, st1_child 90, lc_exchange_refused 90, lc_lamp_refused 90, st1_first_paper 90, st1_names 90, st2_scrap_iron 90, lc_depot_refused 90, queens_expedition 90, garden_mold 90, moles_vents 90, generator_sabotage 90, showtime_betting 90, static_next 88, st1_floor_rumor 87, st1_story_night 86, st1_counting 86, lamps 83, lamps_next 83, lc_directorate_refused 72, st1_dosimeter 72, rumble 23, rumble_next 23, st3_floor 5, lc_lamp_accepted 0, lc_exchange_accepted 0, lc_synod_accepted 0, st2_depot_dirty 0, lc_depot_accepted 0, lc_directorate_accepted 0, st2_dir_honest 0, st2_dir_dirty 0, st3_decision 0, st3_observatory 0, st3_quarantine 0, st2_synod_honest 0, st2_lamp_dirty 0, st2_lamp_honest 0, st2_exchange_dirty 0, st2_exchange_honest 0, st2_synod_dirty 0

## 5. Leader deals

Audiences shown per run (mean / min / max over seeds) and deals accepted by the bot:

| Leader | careful shown | careful accepted | expander shown | expander accepted | follower shown | follower accepted |
| --- | --- | --- | --- | --- | --- | --- |
| depot | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 |
| directorate | 3.8 / 0.0 / 6.0 | 0 of 30 | 5.9 / 5.0 / 6.0 | 0 of 30 | 3.7 / 0.0 / 6.0 | 0 of 30 |
| synod | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 4.0 / 5.0 | 0 of 30 | 5.0 / 4.0 / 5.0 | 0 of 30 |
| exchange | 6.0 / 6.0 / 6.0 | 0 of 30 | 6.0 / 5.0 / 6.0 | 0 of 30 | 6.0 / 5.0 / 6.0 | 0 of 30 |
| black_flag | 4.0 / 4.0 / 4.0 | 0 of 30 | 4.0 / 4.0 / 4.0 | 0 of 30 | 4.0 / 4.0 / 4.0 | 0 of 30 |

These runs use the silence audience style: a leader left waiting is turned away by silence at the next dawn, which the game records as a refusal with the deed "silence" and which the leader consequence events treat as refused. The forks below answer for the bot.

Forks: 141 (seeds 1 to 10, all styles, first audience of each leader). Each row compares the accept or refuse branch with the silence branch at the same week: right after the answer (t0), 5 weeks later and 10 weeks later. Counts are forks where the item differs.

| Leader | Branch | Forks | Blocked | When | Flag set | Own standing (mean diff) | Other standings moved | Law | Pop (mean diff) | Hope (mean diff) | Events differ | Journal rows differ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| depot | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | -4.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +11.5 | 30 | 0 | -0.03 | -2.1 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +10.6 | 30 | 9 | -0.23 | +0.4 | 30 | 30 |
| depot | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| directorate | accept | 21 | 0 | t0 | 21 | +30.0 | 21 | 21 | -1.00 | -8.0 | 0 | 21 |
|  |  | 0 | 0 | t5 | 21 | +39.1 | 21 | 21 | -1.33 | -11.5 | 21 | 21 |
|  |  | 0 | 0 | t10 | 21 | +38.3 | 21 | 19 | -2.19 | -11.8 | 21 | 21 |
| directorate | refuse | 21 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 21 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 21 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 21 |
| synod | accept | 30 | 0 | t0 | 30 | +30.0 | 30 | 0 | +0.00 | +12.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +30.3 | 30 | 0 | +0.17 | +10.9 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +31.7 | 30 | 0 | +1.17 | +4.1 | 30 | 30 |
| synod | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| exchange | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +17.8 | 30 | 0 | +3.50 | +3.2 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +15.3 | 30 | 0 | +2.57 | +1.6 | 30 | 30 |
| exchange | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| black_flag | accept | 30 | 2 | t0 | 28 | +18.7 | 28 | 0 | +0.00 | +0.0 | 0 | 28 |
|  |  | 0 | 0 | t5 | 28 | +19.0 | 28 | 2 | +0.10 | +0.7 | 28 | 28 |
|  |  | 0 | 0 | t10 | 28 | +17.9 | 28 | 2 | -0.23 | +1.7 | 28 | 28 |
| black_flag | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |

Journal rows that differ from the silence branch by week +10 (row kind:result, number of forks), and event ids shown in one branch only (mean per fork). The sim draws all events from one random stream, so any change of state shifts later draws; the leader consequence events (section 7) read the first answer, not the deal flags:

| Leader | Branch | Journal rows that differ | Event ids in one branch only (mean per fork) |
| --- | --- | --- | --- |
| depot | accept | audience:deal (30), audience:silence (30), born (2), build (7), built (7), dig (7), event (3), find (3), law (9), order (2), papers_burned (30), pump (1), regard (6), upgrade (3) | 5.5 |
| depot | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| directorate | accept | audience:deal (21), audience:silence (21), born (12), build (11), built (11), deaths (1), dig (7), event (3), find (4), handed_over (21), law (2), order (15), pump (1), regard (16), repeal (2), station (4), truth (6) | 7.3 |
| directorate | refuse | audience:refused (21), audience:silence (21) | 0.0 |
| synod | accept | audience:deal (30), audience:silence (30), born (10), build (9), built (10), dig (12), event (8), find (11), law (15), order (7), regard (20), station (1), truth (9) | 9.8 |
| synod | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| exchange | accept | audience:deal (30), audience:silence (30), born (23), build (7), built (7), deaths (4), dig (8), event (23), find (6), order (11), regard (10), station (11) | 13.9 |
| exchange | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| black_flag | accept | audience:deal (28), audience:silence (28), born (10), build (9), built (9), dig (9), event (12), false_way (28), find (5), law (2), order (9), pump (3), regard (23), station (3), truth (24) | 9.4 |
| black_flag | refuse | audience:refused (30), audience:silence (30) | 0.0 |

Where each deal flag is read after it is set (`flags.has`, `flags.get`, `flags[...]` or `flags.<name>` in `sim/` and `ui/`, and the flag name in any event or data condition):

| Leader | Deal | Flag | Read in |
| --- | --- | --- | --- |
| depot | burn_papers | buried_papers | data/events_story.json lines 234, 270 |
| directorate | the_list | collaborator | ui/station.gd lines 3840, 3841, data/events_story.json lines 303, 340 |
| synod | stay_down | stayed_down | data/events_story.json lines 378, 415 |
| exchange | open_books | open_books | data/events_story.json lines 452, 499 |
| black_flag | lantern_toll | lantern_toll | data/events_story.json lines 537, 579 |

Readers of the other state a deal changes, from `sim/game.gd`: `audience_deals` stops that leader coming back (`audience_eligible`); `leader_answers` (first answer and its week) opens that leader's consequence event; `standing` feeds the leader's band, which picks the leader's lines, the audience cooldown and the lantern toll; `standing_memory` is shown on the leader card. Outside the audience code, the consequence events and their tests, nothing in `sim/` reads standing (no map, order or trade rule).

Silence branches replayed from an exported state: 141; branches with a load error: 0.

## 7. Leader consequences by audience style

Audience styles (`Bot.audience_style`): silence leaves every leader waiting; accept_all takes every deal it can pay for (a deal it cannot pay for is left waiting, which counts as silence); refuse_all turns everyone away; mixed accepts the Synod and the Exchange and refuses the others; helper offers help whenever it can pay and never takes a deal; helper_mixed offers help to everyone and takes the Synod's and the Exchange's deal after helping them. Event choices are the bot style's own (careful, expander, follower), unchanged. 90 runs per audience style.

First answer per leader (`leader_answers`), runs out of 90 per audience style. "none" = the leader never came or was never answered before the run ended:

| Leader | Audience style | accepted | refused | silence | helped | none | Mean answer week |
| --- | --- | --- | --- | --- | --- | --- | --- |
| depot | silence | 0 | 0 | 90 | 0 | 0 | 6.0 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 6.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 6.0 |
|  | mixed | 0 | 90 | 0 | 0 | 0 | 6.0 |
|  | helper | 0 | 0 | 90 | 0 | 0 | 21.3 |
|  | helper_mixed | 0 | 0 | 90 | 0 | 0 | 25.8 |
| directorate | silence | 0 | 0 | 73 | 0 | 17 | 6.5 |
|  | accept_all | 79 | 0 | 0 | 0 | 11 | 7.8 |
|  | refuse_all | 0 | 73 | 0 | 0 | 17 | 6.5 |
|  | mixed | 0 | 79 | 0 | 0 | 11 | 8.2 |
|  | helper | 0 | 0 | 33 | 48 | 9 | 15.2 |
|  | helper_mixed | 0 | 0 | 52 | 28 | 10 | 26.5 |
| synod | silence | 0 | 0 | 90 | 0 | 0 | 10.0 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 10.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 10.0 |
|  | mixed | 90 | 0 | 0 | 0 | 0 | 10.0 |
|  | helper | 0 | 0 | 84 | 6 | 0 | 29.3 |
|  | helper_mixed | 90 | 0 | 0 | 0 | 0 | 16.0 |
| exchange | silence | 0 | 0 | 90 | 0 | 0 | 2.7 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 2.7 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 2.7 |
|  | mixed | 90 | 0 | 0 | 0 | 0 | 2.7 |
|  | helper | 0 | 0 | 90 | 0 | 0 | 26.6 |
|  | helper_mixed | 90 | 0 | 0 | 0 | 0 | 9.1 |
| black_flag | silence | 0 | 0 | 90 | 0 | 0 | 14.0 |
|  | accept_all | 79 | 0 | 11 | 0 | 0 | 14.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 14.0 |
|  | mixed | 0 | 90 | 0 | 0 | 0 | 14.0 |
|  | helper | 0 | 0 | 6 | 84 | 0 | 15.4 |
|  | helper_mixed | 0 | 0 | 6 | 84 | 0 | 15.2 |

How often each consequence fires. Due = runs where the matching answer (refused also matches silence) was given in week 37 or earlier, the brief's "at least 3 weeks before week 40"; cut short = due runs that ended before the window opened. Target: fired in at least 95 percent of due runs. Fired late = shown with fewer weeks left in its window than it had when it opened (held by a major event).

| Event | Needs | Due | Cut short | Fired | Fired of due | Weeks after the answer (mean) | Held at least one dawn |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lc_depot_accepted | depot accepted 3..10 | 90 | 0 | 90 | 100% | 3.3 | 24 |
| lc_depot_refused | depot refused 3..10 | 449 | 0 | 449 | 100% | 3.2 | 101 |
| lc_directorate_accepted | directorate accepted 3..10 | 78 | 0 | 78 | 100% | 3.3 | 18 |
| lc_directorate_refused | directorate refused 3..10 | 306 | 0 | 306 | 100% | 3.3 | 89 |
| lc_synod_accepted | synod accepted 3..10 | 270 | 0 | 270 | 100% | 3.5 | 124 |
| lc_synod_refused | synod refused 3..10 | 241 | 0 | 235 | 98% | 3.5 | 120 |
| lc_exchange_accepted | exchange accepted 3..10 | 270 | 0 | 270 | 100% | 3.4 | 78 |
| lc_exchange_refused | exchange refused 3..10 | 270 | 0 | 270 | 100% | 3.4 | 80 |
| lc_lamp_accepted | black_flag accepted 3..10 | 79 | 0 | 79 | 100% | 3.2 | 16 |
| lc_lamp_refused | black_flag refused 3..10 | 286 | 0 | 286 | 100% | 3.2 | 59 |

All consequences: fired in 2333 of 2339 due runs (99.7%); lowest single event 98%.

What each choice moved when the bot (or the night resolve) took it, mean over all picks in all 540 runs. Standing is the event's own leader; changes are after clamping:

| Event | Choice | Picks | Hope | Discontent | Standing |
| --- | --- | --- | --- | --- | --- |
| lc_depot_accepted | copy | 16 | -1.00 | +0.00 | +5.00 |
|  | truth | 74 | +2.00 | +2.00 | -10.00 |
|  | bernie | 0 | - | - | - |
| lc_depot_refused | ask | 401 | +0.00 | +0.00 | +5.00 |
|  | strip | 44 | +0.00 | +0.00 | +0.00 |
|  | dark | 4 | -1.00 | +3.00 | +0.00 |
| lc_directorate_accepted | silence | 61 | -1.00 | -2.00 | +0.00 |
|  | necessary | 17 | +0.00 | +2.00 | +5.00 |
|  | nothing | 0 | - | - | - |
| lc_directorate_refused | count | 105 | +0.00 | +1.00 | +5.00 |
|  | refuse | 201 | +0.00 | +0.00 | -12.00 |
|  | coin | 0 | - | - | - |
| lc_synod_accepted | let | 74 | -3.00 | +0.00 | +0.00 |
|  | forbid | 16 | +0.00 | +3.00 | +5.00 |
|  | dorothy | 180 | +1.00 | +0.00 | +5.00 |
| lc_synod_refused | soup | 78 | +1.00 | +0.00 | +5.00 |
|  | go | 157 | +0.00 | +1.00 | +2.00 |
| lc_exchange_accepted | accept | 90 | +0.00 | +2.00 | +0.00 |
|  | haggle | 0 | - | - | - |
|  | tear | 180 | +1.00 | +0.00 | -10.00 |
| lc_exchange_refused | pay | 235 | +0.00 | +0.00 | +3.00 |
|  | refuse | 35 | +0.00 | +0.00 | -10.00 |
|  | work | 0 | - | - | - |
| lc_lamp_accepted | give | 79 | +2.00 | +0.00 | +5.00 |
|  | toll | 0 | - | - | - |
|  | look | 0 | - | - | - |
| lc_lamp_refused | search | 281 | +1.00 | +0.00 | +3.00 |
|  | food | 5 | +0.00 | +0.00 | +10.00 |
|  | choice | 0 | - | - | - |

Endings and meters per bot style and audience style (report only, nothing tuned). Hope min and discontent max are the run's extremes at the end of each week, mean over seeds:

| Bot style | Audience style | Endings | Collapse, hope or revolt endings | Hope min (mean) | Discontent max (mean, worst) |
| --- | --- | --- | --- | --- | --- |
| careful | silence | time x30 | 0 | 38.7 | 53.1, 59 |
|  | accept_all | time x30 | 0 | 36.9 | 26.1, 57 |
|  | refuse_all | time x30 | 0 | 38.7 | 53.1, 59 |
|  | mixed | time x30 | 0 | 38.9 | 51.9, 58 |
|  | helper | time x30 | 0 | 39.4 | 56.3, 68 |
|  | helper_mixed | time x30 | 0 | 38.8 | 53.5, 58 |
| expander | silence | time x29, revolt (week 36) x1 | 1 | 39.3 | 74.1, 100 |
|  | accept_all | time x30 | 0 | 24.8 | 21.6, 33 |
|  | refuse_all | time x29, revolt (week 36) x1 | 1 | 39.3 | 74.1, 100 |
|  | mixed | time x28, revolt (week 37) x1, revolt (week 36) x1 | 2 | 50.5 | 78.8, 100 |
|  | helper | time x30 | 0 | 40.2 | 71.3, 91 |
|  | helper_mixed | time x30 | 0 | 47.3 | 73.2, 98 |
| follower | silence | time x29, revolt (week 37) x1 | 1 | 44.0 | 60.1, 100 |
|  | accept_all | time x30 | 0 | 38.4 | 54.1, 62 |
|  | refuse_all | time x29, revolt (week 37) x1 | 1 | 44.0 | 60.1, 100 |
|  | mixed | time x29, revolt (week 40) x1 | 1 | 40.6 | 64.1, 100 |
|  | helper | time x30 | 0 | 41.5 | 58.3, 87 |
|  | helper_mixed | time x30 | 0 | 44.7 | 58.3, 66 |

## 6. What looks thin (facts from the tables above)

- Catalog events: 50 with 2 choices, 20 with 3 choices, 2 with 4 choices; the 6 upkeep events built in `sim/game.gd` are pay or suffer.
- A 40-week run shows 54.0 distinct event ids on average out of 78 possible (72 catalog + 6 upkeep); 22.5 of them come up twice or more. Rumble and its follow-up came up 23 and 23 times in 90 runs.
- No bot style picked 43 of the 124 choices in events that fired.
- Endings: 88 of 90 runs ended on time (week 40); never reached: collapse, hope, capital.
- Artifacts: only papers has a source in the sim; iron, words are declared with no source.
- Backstories: 5 for 25 named residents.
- Every week had at least one event and one decision (longest gap 1 weeks, 0.0 empty weeks per run).
- Leader deals: accepted 0 times over the 90 silence-style runs. An accepted deal sets its flag, moves standing and changes meters at once; no sim rule reads any of the five deal flags afterwards (`collaborator` is read by the UI for one dossier line); the consequence events read the first answer instead (section 7).
- Refusing and leaving a leader waiting end the same in every fork at +10 weeks except for the audience row's result (refused or silence); the consequence events treat both as refused.

