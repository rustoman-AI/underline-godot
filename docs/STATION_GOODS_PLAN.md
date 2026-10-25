# Each station its own goods: balance plan (19 October 2026, for the owner's decision)

Item 5 of `docs/MAP_STRATEGY.md`. Idea taken from Civilization's tile resources: what a place gives depends on
what is there. No code yet: this changes balance, so it waits for the owner's yes.

## 1. Today
Every held station ships the same base, whatever it is: **5 food, 3 materials, 2 tokens** a week, minus 1 of each
per tunnel hop from the capital (`Formulas.outpost_flow`). Focus adds on top: food +2, fortify +2 materials, spread
our name +6 influence, air +2. A copper mine and a mushroom farm ship the same food. The "If ours" preview and the
yield chips therefore show the same numbers everywhere, so they do not help choose a target.

What bots take (30 seeds × 40 weeks): careful holds only **Sisters of the Garden** (32 of 40 weeks). The expander
holds Sisters (37 weeks), **the Lamplighters** (27), **the Scholars** (27), **the Breathers** (17) and South Ferry
(2). The other stations matter only for a human player who reaches them.

## 2. The rule, as proposed
- Each station gets a base of **three goods summing to 10** (the same total as today's 5 + 3 + 2), chosen from its
  community's lore. Distance still takes 1 of each good per hop, so three goods keep the distance cost the same as
  today.
- Focus works exactly as today (adds on top), and governors as decided on 19 October.
- The table lives in data (`data/station_communities.json`, a new `"goods"` field per station). It is read from the
  catalog, so **saves do not change**.
- The station card says "Known for: food, materials" (its two biggest goods). The "If ours" preview and the chips
  show the real numbers per station.

## 3. The table
| Station | Community | Lore | Food | Materials | Tokens | Influence | Air |
|---|---|---|---|---|---|---|---|
| Botanic Garden | Sisters of the Garden | seed bank, beds under lamps | 5 | 3 | 2 | | |
| Greenpoint | Swineherds | pigs, smoked meat | 7 | 1 | 2 | | |
| Atlantic Av | The Lamplighters | guides' camp, tolls | 2 | 4 | 4 | | |
| Jay St | The Scholars | engineers, they teach | | 3 | 3 | 4 | |
| High St | Riverfolk | fishermen, water smugglers | 5 | | 3 | | 2 |
| Fulton St | Diggers | copper miners | 1 | 6 | 3 | | |
| Bowling Green | The Breathers | sell air by the ticket | 2 | | 4 | | 4 |
| Canal St | The Hoarders | drag home everything, rich | 1 | 4 | 5 | | |
| Spring St | Keepers of the Spring | the only clean water | 4 | 1 | 5 | | |
| Penn Station | Children of the Machine | old boilers, iron | | 6 | 2 | 2 | |
| Union Sq | Communards | shared storehouses | 5 | 3 | | 2 | |
| Times Sq | Free City | rumours, deals | 2 | | 4 | 4 | |
| Astor Pl | Free Word | the newspaper | 2 | | 2 | 6 | |
| Delancey St | The Guild | market with no receipts | 1 | 3 | 6 | | |
| Chambers St | Last Precinct | order for a fee | | 4 | 4 | 2 | |
| Flushing | Slowwalkers | mushrooms, breathe less | 6 | 2 | | | 2 |
| Cathedral Pkwy | Synod of the Tunnel | kitchens, infirmary, faith | 3 | 2 | | 5 | |
| Aqueduct | The Closed Line | militia, raids | 3 | 5 | 2 | | |
| South Ferry | Quarantine bunker | old garrison stores | 1 | 5 | 4 | | |
| Grand Central | Iron Directorate | tolls, ledgers | | 3 | 4 | 3 | |
| Wall St | Free Exchange | the Rate Council | 2 | 2 | 6 | | |
Coney Island (our capital) and the three sealed bunkers ship nothing, as today.

## 4. Expected effect (same held weeks re-scored, no feedback)
| Bot | Today per run | With the table | Change |
|---|---|---|---|
| Careful | food 143, materials 48, tokens 24 (215) | food 167, materials 24, tokens 24 (215) | same total; +24 food, −24 materials |
| Expander | food 283, materials 87, tokens 33, influence 368 (771) | food 182, materials 76, tokens 76, influence 437 (771) | same total; **−101 food**, +43 tokens, +69 influence |

Risks and levers:
- **Expander food.** The Scholars and the Breathers stop sending food, so the expander gets about 2.5 food a week
  less. Its starvation numbers in `sim/check_balance.gd` may move. First lever: the bot picks focus per station
  (food focus where the station already grows food, influence elsewhere), which a human player would do anyway.
  Second lever: the Breathers food 2 → 3, tokens 4 → 3.
- **Careful materials** −1 a week. If the careful corridor moves, Sisters goes 6/2/2 → 5/3/2.
- Air only shows up at the far stations (High St, Bowling Green, Flushing), so it stays rare: taking a lung is a
  real reason to push far.

## 5. Work, if the owner says yes
1. Data: `"goods"` on every station in `data/station_communities.json`, a catalog check that each sums to 10 and
   uses only food, materials, tokens, influence and air.
2. Sim: `Formulas.outpost_flow` takes the station's base instead of the fixed 5/3/2 (same focus, distance and
   governor rules); `_capture_shipment` sends the station's biggest good.
3. Bot: focus per station (food where it grows food, otherwise the profile's own choice).
4. UI: "Known for" on the card, chips and preview already follow. EN and RU written natively.
5. All 9 gates plus the 30-seed balance check, then the result into `docs/DECISIONS.md`.

## 6. Owner decisions needed
1. Three goods summing to 10 per station, same total as today: **yes** recommended (balance-neutral by design).
2. The table above (lore-based): **yes**, or name stations to change.
3. Bot learns per-station focus as part of this package: **yes** recommended.
4. Separate "special goods" (a rare resource only some stations have, like Civilization's luxuries) parked for later:
   **yes** recommended.

## 7. Result (built 19 October)
Owner said yes to all four. Built as planned with two changes found by the gates:
- **Sisters of the Garden 6/2/2 → 5/3/2** (the fallback lever in section 4). With 6 food the careful bot's food buffer
  median went above the 2–4 week corridor (16 of 30 seeds passing, need 18).
- **"A meeting that never ended" (st1_floor_rumor) draw weight 5 → 7.** The story check needs it seen in 75% of 30
  bot runs; it was at 24 before, one above the bar, and the expander's new focus orders moved one run to a miss.
  Weight 7 brings it back to 24, other story events unchanged.

Final numbers (30 seeds × 40 weeks, shipped home per run):
| Bot | Before | After |
|---|---|---|
| Careful | food 143, materials 48, tokens 24 | food 142, materials 47, tokens 24 (unchanged: Sisters keeps the old mix) |
| Expander | food 283, materials 87, tokens 33, influence 368 | food 243, materials 112, tokens 79, influence 255 |
The expander now keeps food focus on food stations and influence elsewhere; influence left at the end 333 (was 395).
All 9 gates pass.
