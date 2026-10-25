# Numbers clarity, step 0: what the screen says against what the week applies (12 Oct 2026)

Brief: `docs/briefs/cursor_numbers_clarity.txt`. Feedback: F28 (power 20 against 10), F34 (materials per turn), F29.

Tool: `.tools/numbers_diag.gd` (headless). It plays the bot and, right before each night, reads every number the
player can see for power, food, air and materials (top bar stock, the top-bar tooltip `resource_outlook`, the hover
panel headline `Brief.source`, each room card `room_detail`, the yard badges), then runs the night step by step and
compares with the stock change (`last_net`). A replay of the night's order explains every difference; nothing in the
sim is changed. Runs: careful bot 5 seeds x 8 weeks, careful and expander 5 seeds x 40 weeks.
Raw output: `build/numbers_diag.txt`, `build/numbers_diag_40_careful.txt`, `build/numbers_diag_40_expander.txt`.

## Fresh game (seed 1, week 1; Engineers' Charter is in force from the start)

| | stock | tooltip: makes / uses / by dawn | room card | night: stock change |
|---|---|---|---|---|
| power | 30 | 20 / 9 / +11 | Generator +18 | +11 |
| food | 24 | 5 / 9 / -4 | Hydroponics +5 | -7 (harvest bias -1 and swing +-2, spoilage above 20: -1) |
| air | 18 | 11 / 7 / +4 | Air filter +11 | +3 (storage cap 28: 1 lost) |
| materials | 22 | 8 / 0 / +8 | Workshop +8 | +6 (filter upkeep -2) |

## Week 8 (seed 1)

| | stock | tooltip | room card | night |
|---|---|---|---|---|
| power | 88 | 20 / 13 / +7 | Generator +18 | +7 |
| food | 16 | 10 / 7 / +3 | Hydroponics +5, +5 | -7 (rot week, harvest) |
| air | 27 | 11 / 7 / +4 | Air filter +11 | +2 (storage cap 36: 2 lost) |
| materials | 4 | 7 / 0 / +7 | Workshop +7 | +4 (filter upkeep -2, outpost upkeep -1) |

## Display bugs (the sim is right, the screen is wrong)

1. Materials "uses 0". `resource_outlook` (top-bar tooltip and "by dawn") takes `_weekly_draw("materials")`, which is
   always 0, while the night spends `filter_upkeep` (2) per air filter in `_decay_filters`, plus outpost upkeep
   (-1 to -2) in `_deliver_outposts`. Every one of 200 careful weeks. The card says +8, the player gets +4 to +6 (F34).
2. Room cards and yard badges (`room_detail`) skip what `_tally` applies: flood silence on the lowest level, the
   quarantine cut (x0.75 on the total), mold, double shifts, a disabled room. Examples: seed 2 week 11 (flood) the air
   filter card says +11, the night makes 0; seed 1 week 30 (quarantine) cards say filter +10, workshop +9, the night
   makes 8 and 7. 11 to 24 weeks out of 200 per resource.
3. The top bar ignores the event flags. `output_of` calls `_tally()` without `belt_down`, `workshop_down`, `gen_down`,
   which the night passes. Seed 1 week 13: generator card +9 (right), top bar "makes 20", night 11. Seed 2 week 13:
   workshop card 0 (right), top bar +8, night 0. 4 to 5 weeks out of 200.
4. Minor: the hover panel's "filter upkeep" counts a filter still under construction (`room_count` includes the build);
   the night charges built filters only.

## Right numbers, not labelled

- F28: "20 made" is gross: generator 18 plus Engineers' Charter 2 (in force from week 1, named only in the hover
  panel). Rooms then draw 9 to 13, so the stock grows by +7 to +11, which is the "10" the tester saw.
- Storage cap: air hits the cap in 111 of 200 careful weeks; the surplus is lost and no forecast says so.
- Food: random harvest (bias -1, swing +-2), spoilage above 20, the rot week, outpost food.
- Cough season without quarantine: the night first pulls workers out of rooms (`_cough_pull_workers`), then counts
  output. Seed 1 week 31: forecast power +5, the night -13. Not predictable from the day screen.
- Brownout: the forecast ignores rooms that will go dark when power runs short (the day state never has `browned`
  set). Never happened in 400 bot weeks, but it is wrong by code when it does.

## Hope 0 and discontent 100 (`sim/game.gd` `_finish_checks`)

- Hope at 0: every week at 0 the two least skilled residents outside the council leave (`_shed(2)`); three weeks in a
  row at 0 end the run ("hope"). The lead's line "At 0 people start leaving and the end comes close" is right.
- Discontent at 100: the run ends at once in a revolt. "At 100 the platform turns on you" is right but does not say
  the run ends. The lead revised both lines on 12 Oct to name the numbers; the numbers are read from the game.
