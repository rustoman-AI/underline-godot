# The network map as a strategy board (19 October 2026)

Owner direction: the map should feel like a finished 4X and grand-strategy game. Take the ideas that work in
Civilization (yields, visible units, caravans, city-states) and Crusader Kings (people with traits who govern,
scheme and hold grudges). We borrow mechanics, not names, art, UI layouts or text. Every idea below is fitted to
Underline: stations in the tunnels, five leader factions, the council, residents with skills.

## Done (view and one-click choices, no balance change)
| Piece | Inspired by | In the game |
|---|---|---|
| Yield chips under every held station | Civ tile and city yields | Next-dawn shipment, focus good ringed gold, clock while settling, red "cut" |
| Focus picker on the map | Civ city focus | Click the chips: four focuses, each with what it would ship |
| Carts on supply lines, materials going out to new stations | Civ trade routes and caravans | Walk the real supply path; still in reduced motion |
| Gold trader carts to deal partners | Civ traders | Out with goods, back with tokens |
| Expedition party in its tunnel | Visible units | Squad token leaves the home pin while away |

## Next, in the order I recommend
Each is one package. The ones marked **balance** change numbers and need the 30-seed gates and a decision record.

1. **Art for map pieces** (handcar pump, idle and trader roll done 20 Oct; remaining art pending owner review; ChatGPT brief `docs/briefs/art_map_units_set_prompts.txt`). Painted miniatures for carts, traders,
   squads, expedition; tinted by owner. The accepted six-frame handcar runs on supply and settle routes, switching to the four-frame idle sheet while waiting. The six-frame trader runs on trade routes with canopy-only tint. Each sheet keys tint on its own neutral grey. Every other kind stays a clean token until accepted. See `docs/audit/map_units_pilot.md` for import and verification.
2. **Rival units and caravans** (done 19 Oct). Rival squads walk tunnel by tunnel when they move; rival stations send their own carts
   to their seat. The map shows a living world, and a player sees a rival build-up before it hits. View only.
3. **Yield preview on stations you do not hold** (done 19 Oct). Hover a known station: faint chips of what it would ship once
   yours. Lets the player choose the next target by need ("we are short on air, take the pump station").
4. **Governors** (Crusader Kings, done 19 Oct, see docs/GOVERNORS_PLAN.md). Put a named council member or resident in charge of a held
   station. Their main skill adds to its yield (Tech to materials, Speech to influence), their traits colour events
   ("the governor of Spring St is stealing"). Opinion of the governor feeds the station's loyalty. **balance**
5. **Each station its own goods** (Civ resources, done 19 Oct, see docs/STATION_GOODS_PLAN.md). Today one formula gives every outpost the same base. Give each
   station a base from data (pump station air, market tokens, farm food) and one special good. Makes the map a
   real choice. **balance**
6. **Neutral stations as small allies** (Civ city-states). Envoys already exist. Add the suzerain idea: the faction
   with the most standing at a neutral station gets its bonus (a guide, cheaper passage, a weekly good). The rivals
   compete for the same stations and the map shows who leads each one. **balance**
7. **Grudges and claims** (Crusader Kings). Taking a station gives its former owner a claim and a grudge; a
   faction with a claim may come back for it, and the map marks claimed stations with a broken seal. Gives
   reasons for wars instead of random strikes. **balance**
8. **Schemes** (Crusader Kings). Slow hidden plots with a progress bar on the target station: sway its people,
   sabotage the pump, plant a spy. Rivals scheme too and you may uncover them. Ties in with the parked espionage
   idea. **balance**, big.
9. **Fog of war as burnt paper edges** instead of "?" circles; known stations brighten as you scout. Visual only.

## Not for Underline
- Tech tree, eras, religion victory, culture victory: too big, not our story.
- Dynasties and marriage politics as in CK: our story is one station over one winter; the council and residents
  already carry the people side.
- Hex tiles: the tunnels are the board. Stations and lines are our "tiles".
