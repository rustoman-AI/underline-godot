# Content audit 20261012

Measured with `.tools/content_audit.gd` on the current data and sim, 30 seeds for each of the bot styles careful, expander, follower and each audience style silence, accept_all, refuse_all, mixed, helper, helper_mixed (540 runs of 40 weeks), leader forks on seeds 1 to 10. Facts only, no proposals. The bots are not players: they decide instantly and use the same rules each week. Sections 1 to 6 use the silence audience style (the bot never answers, so every leader is turned away by silence, as before audience styles existed): 90 runs. Section 7 compares the audience styles.

## 1. Counts

| Item | Count | Detail |
| --- | --- | --- |
| Events, all | 86 | 6 major, 63 minor, 5 check, 12 follow-up only (chain_only) |
| Events with a follow-up | 12 | follow-up text varies by the earlier choice in 12 |
| Events with their own cooldown | 69 | global cooldown 8 weeks, minor events capped at 2 per run (balance.json) |
| Choices per event | 2 / 2.4 / 4 | min / mean / max over all 86 events |
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
| careful | 1.86 / 1.77 / 1.93 | 60 / 56 / 64 | 12 / 10 / 17 | 0 / 0 / 0 | 0 / 0 / 0 | 3.12 / 2.77 / 3.42 |
| expander | 1.87 / 1.77 / 1.98 | 60 / 55 / 66 | 13 / 9 / 17 | 0 / 0 / 0 | 0 / 0 / 0 | 4.21 / 3.90 / 4.83 |
| follower | 1.87 / 1.77 / 1.95 | 60 / 56 / 66 | 12 / 9 / 15 | 0 / 0 / 0 | 0 / 0 / 0 | 2.65 / 2.48 / 2.85 |

Decisions per week by type (mean over all runs and weeks):

| Style | Event choices (bot) | Event choices (night) | Orders | Laws | Audiences shown | Build / dig / upgrade |
| --- | --- | --- | --- | --- | --- | --- |
| careful | 1.88 | 0.00 | 0.61 | 0.05 | 0.58 | 0.53 |
| expander | 1.90 | 0.00 | 1.66 | 0.00 | 0.65 | 0.55 |
| follower | 1.89 | 0.00 | 0.14 | 0.02 | 0.59 | 0.49 |

Emptiest and busiest week numbers across all 90 runs (mean decisions and events shown in that week):

| Emptiest week | Decisions | Events | | Busiest week | Decisions | Events |
| --- | --- | --- | --- | --- | --- | --- |
| 29 | 1.77 | 1.37 | | 14 | 5.63 | 2.84 |
| 36 | 1.77 | 1.38 | | 17 | 5.40 | 2.58 |
| 26 | 1.99 | 1.34 | | 13 | 4.99 | 3.21 |
| 32 | 2.03 | 1.38 | | 16 | 4.69 | 2.53 |
| 40 | 2.12 | 1.49 | | 9 | 4.68 | 3.13 |

## 3. Run-time estimate

Assumptions (brief): event choice 25 s, order 12 s, law 30 s, audience 40 s, reading the dawn report 20 s per week, building and assigning 60 s per week. A normal new player takes those times; careful x1.5, fast x0.6. Decision counts are the bots' (section 2), audiences counted when shown. The bots use fewer order seats than a player may: the second line puts every order seat to use (3 per week).

| Counts from | Player | Minutes per week (mean, min..max run) | 40 weeks, hours (mean, min..max run) |
| --- | --- | --- | --- |
| bots | careful | 4.0 (3.7..4.5) | 2.70 (2.47..3.03) |
| bots | normal | 2.7 (2.5..3.0) | 1.80 (1.65..2.02) |
| bots | fast | 1.6 (1.5..1.8) | 1.08 (0.99..1.21) |
| all seats | careful | 4.7 (4.6..4.8) | 3.14 (3.04..3.21) |
| all seats | normal | 3.1 (3.0..3.2) | 2.09 (2.02..2.14) |
| all seats | fast | 1.9 (1.8..1.9) | 1.26 (1.22..1.28) |

Runs that ended before week 40 are scaled to 40 weeks at their own weekly rate. The fixed part (dawn report and building) is 80 s, that is 1.3 minutes a week and 0.9 hours over 40 weeks for a normal player.

## 4. Dead ends

Endings reached:

| Style | Ending (week) counts | Runs with sim errors |
| --- | --- | --- |
| careful | time x30 | 0 |
| expander | time x30 | 0 |
| follower | time x30 | 0 |

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
| 14 | time | time | time |
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
| 25 | time | time | time |
| 26 | time | time | time |
| 27 | time | time | time |
| 28 | time | time | time |
| 29 | time | time | time |
| 30 | time | time | time |

Events that never fired in any run (17 of 86): lc_depot_accepted, lc_directorate_accepted, lc_synod_accepted, lc_exchange_accepted, lc_lamp_accepted, st2_depot_dirty, st2_dir_honest, st2_dir_dirty, st2_synod_honest, st2_synod_dirty, st2_exchange_honest, st2_exchange_dirty, st2_lamp_honest, st2_lamp_dirty, st3_quarantine, st3_observatory, st3_decision

Upkeep events built at run time in `sim/game.gd`, not in events.json (presentations): pantry 66, belt 66, dynamo 42, stacks 24, ducts 48, shopbelt 24

Choices never picked in events that did fire (55): quarrel/shut, preacher/stop, smuggler/refuse, rumble/push, static/ignore, wire/trade, nightshift/order, ration/hold, tools/drop, bunks/no, scrap/leave, overtime/keep, hymn/quiet, drill/stay, lamps_next/move, refugees_next/names, quarrel_next/split, preacher_next/no, smuggler_next/end, rumble_next/up, static_next/stop, desertion_next/box, cough_next/push, leak_next/move, leo_torch/bed, birth/quiet, birth/ration, graves/seal, ration_card/blind, wet_boots/wait, coney_errand/alone, maggie_salt/refuse, bait_throw/leave, barnum_cabinet/close, sylvia_tide/worst, sylvia_tide/stop, lc_depot_refused/dark, lc_directorate_refused/coin, lc_exchange_refused/refuse, lc_exchange_refused/work, lc_lamp_refused/choice, st1_first_paper/burn, st1_counting/trace, st1_counting/forbid, st1_names/private, st1_names/no, st1_floor_rumor/ignore, st1_story_night/short, st1_story_night/skip, st1_child/dorothy, st3_floor/publish, st3_floor/hand, st3_floor/leave, st1_dosimeter/leave, st1_substation/no

Choices only ever taken by the night resolve, never by a bot (0): none

Presentations per event over all 90 runs (most to least):

refugees 298, refugees_next 249, market_food 152, market_next 137, clog 136, nightshift 133, quarrel 131, wire 127, clog_next 122, ration 119, scrap 118, tools 118, quarrel_next 117, leak 114, smuggler 112, drill 112, overtime 112, hymn 110, salt 107, leak_next 105, preacher 104, bunks 102, smuggler_next 94, lc_synod_refused 90, lc_exchange_refused 90, st1_names 90, lc_lamp_refused 90, st1_first_paper 90, st1_child 90, lc_depot_refused 90, st1_substation 90, st2_scrap_iron 90, queens_expedition 90, garden_mold 90, moles_vents 90, generator_sabotage 90, showtime_betting 90, st1_floor_rumor 89, cough 89, st2_depot_honest 88, preacher_next 85, st1_story_night 85, st1_counting 85, lamps 84, lamps_next 84, desertion 80, sylvia_tide 79, quiet_letter 78, ration_card 77, fran_crate 74, barnum_cabinet 73, birth 73, cough_next 73, maggie_salt 72, lc_directorate_refused 71, bait_throw 71, st1_dosimeter 71, old_diary 70, leo_torch 69, graves 67, wet_boots 65, inez_count 63, static 60, desertion_next 55, static_next 49, coney_errand 48, rumble 13, rumble_next 12, st3_floor 5, lc_depot_accepted 0, lc_directorate_accepted 0, lc_synod_accepted 0, lc_exchange_accepted 0, st3_decision 0, st3_observatory 0, st3_quarantine 0, st2_lamp_dirty 0, st2_lamp_honest 0, st2_exchange_dirty 0, st2_exchange_honest 0, st2_synod_dirty 0, st2_synod_honest 0, st2_dir_dirty 0, st2_dir_honest 0, st2_depot_dirty 0, lc_lamp_accepted 0

## 5. Leader deals

Audiences shown per run (mean / min / max over seeds) and deals accepted by the bot:

| Leader | careful shown | careful accepted | expander shown | expander accepted | follower shown | follower accepted |
| --- | --- | --- | --- | --- | --- | --- |
| depot | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 |
| directorate | 3.4 / 0.0 / 6.0 | 0 of 30 | 5.9 / 5.0 / 6.0 | 0 of 30 | 3.8 / 0.0 / 6.0 | 0 of 30 |
| synod | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 | 5.0 / 5.0 / 5.0 | 0 of 30 |
| exchange | 6.0 / 6.0 / 6.0 | 0 of 30 | 6.0 / 6.0 / 6.0 | 0 of 30 | 6.0 / 6.0 / 6.0 | 0 of 30 |
| black_flag | 4.0 / 4.0 / 4.0 | 0 of 30 | 4.0 / 4.0 / 4.0 | 0 of 30 | 4.0 / 4.0 / 4.0 | 0 of 30 |

These runs use the silence audience style: a leader left waiting is turned away by silence at the next dawn, which the game records as a refusal with the deed "silence" and which the leader consequence events treat as refused. The forks below answer for the bot.

Forks: 144 (seeds 1 to 10, all styles, first audience of each leader). Each row compares the accept or refuse branch with the silence branch at the same week: right after the answer (t0), 5 weeks later and 10 weeks later. Counts are forks where the item differs.

| Leader | Branch | Forks | Blocked | When | Flag set | Own standing (mean diff) | Other standings moved | Law | Pop (mean diff) | Hope (mean diff) | Events differ | Journal rows differ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| depot | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | -4.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +13.0 | 30 | 0 | +0.70 | -1.8 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +10.7 | 30 | 2 | +0.13 | -1.2 | 30 | 30 |
| depot | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| directorate | accept | 24 | 0 | t0 | 24 | +30.0 | 24 | 24 | -1.00 | -8.0 | 0 | 24 |
|  |  | 0 | 0 | t5 | 24 | +39.0 | 24 | 24 | -1.38 | -12.0 | 23 | 24 |
|  |  | 0 | 0 | t10 | 24 | +38.7 | 24 | 21 | -0.88 | -11.8 | 23 | 24 |
| directorate | refuse | 24 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 24 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 24 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 24 |
| synod | accept | 30 | 0 | t0 | 30 | +30.0 | 30 | 0 | +0.00 | +12.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +30.5 | 30 | 0 | +0.20 | +10.0 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +31.7 | 30 | 0 | +1.17 | +4.3 | 30 | 30 |
| synod | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| exchange | accept | 30 | 0 | t0 | 30 | +25.0 | 30 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 30 | +17.8 | 30 | 0 | +3.67 | +3.1 | 30 | 30 |
|  |  | 0 | 0 | t10 | 30 | +15.5 | 30 | 0 | +1.70 | +2.3 | 30 | 30 |
| exchange | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
| black_flag | accept | 30 | 1 | t0 | 29 | +19.3 | 29 | 0 | +0.00 | +0.0 | 0 | 29 |
|  |  | 0 | 0 | t5 | 29 | +20.0 | 29 | 1 | -0.73 | +0.3 | 29 | 29 |
|  |  | 0 | 0 | t10 | 29 | +18.7 | 29 | 2 | -0.80 | +0.9 | 29 | 29 |
| black_flag | refuse | 30 | 0 | t0 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t5 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |
|  |  | 0 | 0 | t10 | 0 | +0.0 | 0 | 0 | +0.00 | +0.0 | 0 | 30 |

Journal rows that differ from the silence branch by week +10 (row kind:result, number of forks), and event ids shown in one branch only (mean per fork). The sim draws all events from one random stream, so any change of state shifts later draws; the leader consequence events (section 7) read the first answer, not the deal flags:

| Leader | Branch | Journal rows that differ | Event ids in one branch only (mean per fork) |
| --- | --- | --- | --- |
| depot | accept | audience:deal (30), audience:silence (30), born (3), build (5), built (4), dig (8), event (6), find (5), law (3), order (1), papers_burned (30), regard (12), station (1), truth (3), upgrade (4) | 6.3 |
| depot | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| directorate | accept | audience:deal (24), audience:silence (24), born (12), build (7), built (7), deaths (1), dig (8), event (5), find (8), handed_over (24), law (6), order (16), pump (1), regard (16), repeal (3), station (6), truth (4) | 8.8 |
| directorate | refuse | audience:refused (24), audience:silence (24) | 0.0 |
| synod | accept | audience:deal (30), audience:silence (30), born (10), build (10), built (8), dig (10), event (7), find (8), law (10), order (6), regard (17), station (1), truth (8), ultimatum (1) | 11.4 |
| synod | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| exchange | accept | audience:deal (30), audience:silence (30), born (22), build (14), built (14), deaths (5), dig (12), event (26), find (13), law (2), order (10), regard (20), station (11) | 16.9 |
| exchange | refuse | audience:refused (30), audience:silence (30) | 0.0 |
| black_flag | accept | audience:deal (29), audience:silence (28), born (11), build (9), built (9), dig (9), event (17), false_way (29), find (7), law (2), order (9), regard (23), station (3), truth (26), ultimatum (1) | 11.1 |
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

Silence branches replayed from an exported state: 144; branches with a load error: 0.

## 7. Leader consequences by audience style

Audience styles (`Bot.audience_style`): silence leaves every leader waiting; accept_all takes every deal it can pay for (a deal it cannot pay for is left waiting, which counts as silence); refuse_all turns everyone away; mixed accepts the Synod and the Exchange and refuses the others; helper offers help whenever it can pay and never takes a deal; helper_mixed offers help to everyone and takes the Synod's and the Exchange's deal after helping them. Event choices are the bot style's own (careful, expander, follower), unchanged. 90 runs per audience style.

First answer per leader (`leader_answers`), runs out of 90 per audience style. "none" = the leader never came or was never answered before the run ended:

| Leader | Audience style | accepted | refused | silence | helped | none | Mean answer week |
| --- | --- | --- | --- | --- | --- | --- | --- |
| depot | silence | 0 | 0 | 90 | 0 | 0 | 6.0 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 6.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 6.0 |
|  | mixed | 0 | 90 | 0 | 0 | 0 | 6.0 |
|  | helper | 0 | 0 | 90 | 0 | 0 | 20.1 |
|  | helper_mixed | 0 | 0 | 90 | 0 | 0 | 24.9 |
| directorate | silence | 0 | 0 | 72 | 0 | 18 | 7.1 |
|  | accept_all | 81 | 0 | 0 | 0 | 9 | 8.5 |
|  | refuse_all | 0 | 73 | 0 | 0 | 17 | 7.6 |
|  | mixed | 0 | 81 | 0 | 0 | 9 | 8.5 |
|  | helper | 0 | 0 | 28 | 54 | 8 | 14.0 |
|  | helper_mixed | 0 | 0 | 31 | 45 | 14 | 18.2 |
| synod | silence | 0 | 0 | 90 | 0 | 0 | 10.0 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 10.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 10.0 |
|  | mixed | 90 | 0 | 0 | 0 | 0 | 10.0 |
|  | helper | 0 | 0 | 84 | 6 | 0 | 30.4 |
|  | helper_mixed | 90 | 0 | 0 | 0 | 0 | 16.0 |
| exchange | silence | 0 | 0 | 90 | 0 | 0 | 2.7 |
|  | accept_all | 90 | 0 | 0 | 0 | 0 | 2.7 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 2.7 |
|  | mixed | 90 | 0 | 0 | 0 | 0 | 2.7 |
|  | helper | 0 | 0 | 90 | 0 | 0 | 27.1 |
|  | helper_mixed | 90 | 0 | 0 | 0 | 0 | 9.1 |
| black_flag | silence | 0 | 0 | 90 | 0 | 0 | 14.0 |
|  | accept_all | 79 | 0 | 11 | 0 | 0 | 14.0 |
|  | refuse_all | 0 | 90 | 0 | 0 | 0 | 14.0 |
|  | mixed | 0 | 90 | 0 | 0 | 0 | 14.0 |
|  | helper | 0 | 0 | 4 | 86 | 0 | 14.8 |
|  | helper_mixed | 0 | 0 | 5 | 85 | 0 | 14.7 |

How often each consequence fires. Due = runs where the matching answer (refused also matches silence) was given in week 37 or earlier, the brief's "at least 3 weeks before week 40"; cut short = due runs that ended before the window opened. Target: fired in at least 95 percent of due runs. Fired late = shown with fewer weeks left in its window than it had when it opened (held by a major event).

| Event | Needs | Due | Cut short | Fired | Fired of due | Weeks after the answer (mean) | Held at least one dawn |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lc_depot_accepted | depot accepted 3..10 | 90 | 0 | 90 | 100% | 3.2 | 20 |
| lc_depot_refused | depot refused 3..10 | 449 | 0 | 449 | 100% | 3.2 | 90 |
| lc_directorate_accepted | directorate accepted 3..10 | 80 | 0 | 80 | 100% | 3.3 | 20 |
| lc_directorate_refused | directorate refused 3..10 | 278 | 0 | 278 | 100% | 3.3 | 86 |
| lc_synod_accepted | synod accepted 3..10 | 270 | 0 | 270 | 100% | 3.4 | 114 |
| lc_synod_refused | synod refused 3..10 | 236 | 0 | 234 | 99% | 3.5 | 113 |
| lc_exchange_accepted | exchange accepted 3..10 | 270 | 0 | 270 | 100% | 3.4 | 80 |
| lc_exchange_refused | exchange refused 3..10 | 270 | 0 | 270 | 100% | 3.4 | 82 |
| lc_lamp_accepted | black_flag accepted 3..10 | 79 | 0 | 79 | 100% | 3.2 | 19 |
| lc_lamp_refused | black_flag refused 3..10 | 286 | 0 | 286 | 100% | 3.2 | 56 |

All consequences: fired in 2306 of 2308 due runs (99.9%); lowest single event 99%.

What each choice moved when the bot (or the night resolve) took it, mean over all picks in all 540 runs. Standing is the event's own leader; changes are after clamping:

| Event | Choice | Picks | Hope | Discontent | Standing |
| --- | --- | --- | --- | --- | --- |
| lc_depot_accepted | copy | 12 | -1.00 | +0.00 | +5.00 |
|  | truth | 78 | +2.00 | +2.00 | -10.00 |
|  | bernie | 0 | - | - | - |
| lc_depot_refused | ask | 406 | +0.00 | +0.00 | +5.00 |
|  | strip | 38 | +0.00 | +0.00 | +0.00 |
|  | dark | 5 | -1.00 | +3.00 | +0.00 |
| lc_directorate_accepted | silence | 64 | -1.00 | -2.00 | +0.00 |
|  | necessary | 16 | +0.00 | +2.00 | +5.00 |
|  | nothing | 0 | - | - | - |
| lc_directorate_refused | count | 102 | +0.00 | +1.00 | +5.00 |
|  | refuse | 176 | +0.00 | +0.00 | -12.00 |
|  | coin | 0 | - | - | - |
| lc_synod_accepted | let | 74 | -3.00 | +0.00 | +0.00 |
|  | forbid | 16 | +0.00 | +3.00 | +5.00 |
|  | dorothy | 180 | +1.00 | +0.00 | +5.00 |
| lc_synod_refused | soup | 81 | +0.98 | +0.00 | +5.00 |
|  | go | 153 | +0.00 | +1.00 | +2.00 |
| lc_exchange_accepted | accept | 90 | +0.00 | +2.00 | +0.00 |
|  | haggle | 0 | - | - | - |
|  | tear | 180 | +1.00 | +0.00 | -10.00 |
| lc_exchange_refused | pay | 234 | +0.00 | +0.00 | +3.00 |
|  | refuse | 36 | +0.00 | +0.00 | -10.00 |
|  | work | 0 | - | - | - |
| lc_lamp_accepted | give | 79 | +2.00 | +0.00 | +5.00 |
|  | toll | 0 | - | - | - |
|  | look | 0 | - | - | - |
| lc_lamp_refused | search | 275 | +1.00 | +0.00 | +3.00 |
|  | food | 11 | +0.00 | +0.00 | +10.00 |
|  | choice | 0 | - | - | - |

Endings and meters per bot style and audience style (report only, nothing tuned). Hope min and discontent max are the run's extremes at the end of each week, mean over seeds:

| Bot style | Audience style | Endings | Collapse, hope or revolt endings | Hope min (mean) | Discontent max (mean, worst) |
| --- | --- | --- | --- | --- | --- |
| careful | silence | time x30 | 0 | 38.7 | 47.9, 56 |
|  | accept_all | time x30 | 0 | 37.2 | 25.6, 49 |
|  | refuse_all | time x30 | 0 | 38.7 | 47.9, 56 |
|  | mixed | time x30 | 0 | 38.8 | 47.3, 58 |
|  | helper | time x30 | 0 | 39.0 | 51.9, 62 |
|  | helper_mixed | time x30 | 0 | 38.6 | 48.3, 54 |
| expander | silence | time x30 | 0 | 43.4 | 68.3, 85 |
|  | accept_all | time x30 | 0 | 28.8 | 21.1, 31 |
|  | refuse_all | time x30 | 0 | 43.4 | 68.3, 85 |
|  | mixed | time x30 | 0 | 55.2 | 70.8, 92 |
|  | helper | time x30 | 0 | 44.5 | 67.5, 94 |
|  | helper_mixed | time x30 | 0 | 52.9 | 67.8, 99 |
| follower | silence | time x30 | 0 | 45.3 | 58.9, 93 |
|  | accept_all | time x30 | 0 | 39.1 | 54.2, 76 |
|  | refuse_all | time x30 | 0 | 45.3 | 58.9, 93 |
|  | mixed | time x28, revolt (week 34) x1, revolt (week 39) x1 | 2 | 44.7 | 62.5, 100 |
|  | helper | time x30 | 0 | 42.4 | 60.9, 97 |
|  | helper_mixed | time x30 | 0 | 43.3 | 60.7, 87 |

## 6. What looks thin (facts from the tables above)

- Catalog events: 50 with 2 choices, 34 with 3 choices, 2 with 4 choices; the 6 upkeep events built in `sim/game.gd` are pay or suffer.
- A 40-week run shows 60.1 distinct event ids on average out of 92 possible (86 catalog + 6 upkeep); 12.5 of them come up twice or more. Rumble and its follow-up came up 13 and 12 times in 90 runs.
- No bot style picked 55 of the 166 choices in events that fired.
- Endings: 90 of 90 runs ended on time (week 40); never reached: collapse, hope, revolt, capital.
- Artifacts: only papers has a source in the sim; iron, words are declared with no source.
- Backstories: 5 for 25 named residents.
- Every week had at least one event and one decision (longest gap 0 weeks, 0.0 empty weeks per run).
- Leader deals: accepted 0 times over the 90 silence-style runs. An accepted deal sets its flag, moves standing and changes meters at once; no sim rule reads any of the five deal flags afterwards (`collaborator` is read by the UI for one dossier line); the consequence events read the first answer instead (section 7).
- Refusing and leaving a leader waiting end the same in every fork at +10 weeks except for the audience row's result (refused or silence); the consequence events treat both as refused.

