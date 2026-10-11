# Underline GDD v2: Turn-based Station Strategy

Oct 2, 2026 · @Arthur

## Vision and pillars

Underline is a turn-based strategy game where you run one survivor station in the New York subway after the Silence, and grow it into a power on the network map. You build and staff the station like Fallout Shelter, govern it under pressure like Frostpunk, and play politics with characters and rival factions like Crusader Kings, on a real subway map like Civ.

**Pitch:** One station. Four powers. Air for two months. Find out what really happened to the surface.

### Pillars

1. **Every week is a hard choice.** Air, food and order never all line up. Each turn forces a trade-off with a visible cost.
2. **Rivals are people, and you see them coming.** Faction leaders have names, traits and grudges. Their intentions are shown on the map one turn ahead, so pressure is felt before it hits.
3. **Your station is a place, not a number.** A cut-away you dig, build and staff, with named residents who get sick, quarrel and remember.
4. **Nothing is won in one click.** Stations have needs and loyalties. Winning one over takes several turns of meeting its demands, and keeping it takes more.
5. **A mystery worth surviving for.** Expeditions and artifacts slowly reveal who knew about the Silence, and the endings depend on what you do with the truth.

### What we take from each inspiration

| Game | What we take | What we leave out |
|---|---|---|
| Fallout Shelter | Side-view cut-away, rooms, assigning named residents | Real-time timers, monetized waiting |
| Frostpunk | Survival clock, laws with long-term costs, hope vs discontent | Real-time pacing |
| Crusader Kings | Characters with traits, opinions, agendas, intrigue | Dynasties, huge character counts |
| Civilization | Turn-based map play, research, multiple victory paths | Hex combat, hundreds of units |
| Into the Breach | Rival actions telegraphed one turn ahead | Grid tactics |

**Unique hook:** base building plus subway politics plus a mystery, on a real New York map. The telegraphed rival intents make a turn-based game feel tense instead of passive.

## Turn structure and core loop

One turn is one week, and every turn runs the same five phases. A vertical-slice run lasts about 40 weeks (2 to 3 hours); a full campaign about 80 weeks.

1. **Dawn report.** The week's numbers land: air, food, power, Hope, Discontent. Events fire (2 to 3 per week, at most one major). New rival intents appear on the map as icons over stations and tunnels.
2. **Station phase.** Assign residents to rooms, queue construction and digging, treat the sick, enact or repeal a law. Free actions, limited only by people and materials.
3. **Council phase.** You have one order per council member (3 at start, up to 6). Orders are the scarce resource of the network game: send an envoy, run propaganda, move a squad, start an expedition, open trade, plot against a rival.
4. **Rival phase (watched).** Rivals resolve the intents they showed last week, in a short animated sequence on the map. You see their squads move and their propaganda land.
5. **Night.** Production and consumption are applied, construction advances, residents gain or lose traits, and next week's rival intents are rolled and shown.

**Telegraphed intents (the core tension mechanic).** At night every rival declares what it will do next week, shown on the map: "Directorate squad moving to Times Sq", "Synod preaching at Canal St", "Exchange will demand 30 tokens". During your turn you can respond: reinforce, counter-preach, pay, ally, or let it happen. Some intents are hidden until you have a spy or a radio room, which makes intelligence a real investment.

**Decisions per turn target:** 2 to 4 meaningful ones. If a turn has no real decision, the design has a hole.

## Station layer

Your capital is a side-view cut-away of a real station: a platform level in the middle, service levels above, and rock below that you dig into. Rooms sit on a grid of cells; every cell must be dug before it can be built.

### Grid and digging

- Start: 3 levels x 6 cells, 8 cells already open (platform, two rooms, a filter, quarters).
- Digging a cell takes 1 to 3 turns and 2 to 4 workers. Deeper levels take longer but hold water, old tunnels and finds.
- Some cells hide something: a flooded pocket (pump it or wall it off), an old maintenance room (free materials), a sealed door (a lead in the mystery).

### Rooms (vertical slice: 8 types)

| Room | Produces / does | Staff | Upgrade path |
|---|---|---|---|
| Quarters | Housing: 8 people per room | 0 | Bunks (12), then family rooms (+Hope) |
| Hydroponics | Food | 2 to 4 | Grow lamps, mushroom beds |
| Air filter | Air | 1 to 3 | Charcoal stacks, pressure seals |
| Generator | Power | 2 to 3 | Dynamo, then the old substation |
| Workshop | Materials, repairs, squad gear | 2 to 4 | Drill heads, armor plating |
| Infirmary | Treats sickness and injuries | 1 to 2 | Quarantine ward |
| Meeting hall | Influence, unlocks laws, reduces Discontent | 1 to 2 | Loudspeakers (network reach) |
| Radio room | Reveals hidden rival intents, expedition contact | 1 | Long-range antenna (bunker signals) |

Later content: chapel, market, barracks, school, archive, pump house, armory.

### Residents

- Every resident has a name, 3 skills (Labor, Tech, Care, Talk, Fight; 1 to 5) and 1 to 2 traits (Claustrophobic, Devout, Black marketeer, Veteran, Insomniac, Ex-driver).
- Assigning by skill matters: a Tech 5 in the generator produces about twice a Tech 1.
- Residents react to events and laws: a Devout one loves sermons, a Claustrophobic one breaks down after a dig accident.
- Notable residents can be promoted to the council (see Factions and characters).
- Vertical slice: start with about 25 residents, grow to 60 to 90 in the capital. Outposts are abstract numbers, not individuals, to keep the simulation small.

**Outposts:** stations you win on the network map get a small 1-level layout with 3 to 4 room slots and a governor. You do not micromanage them: you set a focus (food, air, defense, influence) and the governor runs it according to their traits.

## Society layer

The station's mood is two meters, not one: **Hope** (0 to 100) and **Discontent** (0 to 100). Hope at 0 means people stop working and leave. Discontent at 100 means a revolt that can depose you. Most choices push one up and the other down.

**Air is the clock.** Filters lose 2% efficiency per week and need parts from the workshop. Every 8 to 10 weeks a Season of the Silence arrives with a warning 2 turns ahead:

- **The Flood:** water rises on the lowest level; pump or lose rooms.
- **The Cold:** power demand doubles for 3 weeks.
- **The Cough:** sickness spreads by room adjacency; quarantine or lose workers.
- **The Dark:** generators fail at random; Hope drains without light.

Seasons escalate over a run, so a comfortable station in week 10 is in danger by week 30.

### Laws (vertical slice: 8)

Enacted from the meeting hall, one per 3 turns. Each law has a benefit now and a cost later; most cannot be repealed without a Discontent spike.

| Law | Benefit | Cost |
|---|---|---|
| Rationing | -25% food use | -1 Hope per week |
| Double shifts | +40% production in chosen rooms | Sickness and accident risk up |
| Curfew | Discontent -2 per week | Hope -1 per week, influence -10% |
| Sermons | Hope +2 per week | Synod gains sympathy in your station |
| Open market | +tokens, Exchange trade bonus | Smuggling events, Discontent from the poor |
| Conscription | +squad size | -1 worker per room, Discontent +1 per week |
| Tunnel tax | +tokens from passing traders | Rival relations -5 |
| The Ledger of the Dead | Recover materials from the dead | Hope -5 once, unlocks darker laws |

Laws also define your identity: the faction you play starts with one ideology law already in force (Depot: Engineers' Charter, Synod: Sermons, Exchange: Open market, Directorate: Curfew).

## Network layer

Winning a station is a multi-turn project with a price, not three propaganda clicks. Every station has a population, an ideology, a list of needs, and loyalties to whoever controls it.

### Station profile

- **Ideology lean:** Order, Faith, Trade, or Craft (matches the four factions). Propaganda that fits the lean works twice as well; propaganda against it can backfire.
- **Needs (2 to 3 per station):** food, air, protection, medicine, faith, trade access, work. Shown as icons with a fill level.
- **Loyalty:** 0 to 100 toward its current owner. Neutral stations have loyalty to themselves.

### Ways to win a station

| Path | How it works | Typical time | Risk |
|---|---|---|---|
| Persuade | Fill its needs (send food, a doctor, guards) while running propaganda that fits its lean; it joins at 100 sympathy | 4 to 8 turns | Rivals counter-preach; needs shift |
| Trade | Become its main supplier; at 3 trade deals it asks to join | 6 to 10 turns | Exchange undercuts you |
| Force | Move a squad there; battle vs garrison | 2 to 3 turns | Loyalty starts at 20, revolt risk, other factions angry |
| Intrigue | A council member plots a coup with a local leader | 3 to 5 turns | If exposed, war and a Discontent spike |

**After it joins:** a station starts with Unrest for 4 to 6 turns. Unmet needs drain loyalty each week. Below 30 loyalty it may revolt or defect to whichever rival has been courting it. Holding territory costs attention, which is what makes expansion a real decision.

**Supply lines.** Every outpost must connect to the capital through tunnels you control or have passage rights through. Cut off, it stops sending resources and loses 5 loyalty per week. Rivals can cut lines with squads or by closing a tunnel at a station they own.

**Squads and tunnels.** Squads (5 to 20 people, gear from the workshop) move one tunnel segment per turn and are visible on the map as tokens. Tunnels have conditions: flooded (slow), collapsed (dig to open), contested (ambush risk), sealed (the hidden network, opened by digging from the station layer). Expeditions are squads sent to ruins, sealed tunnels or the surface, out of contact for several turns, returning with finds, survivors or bad news.

## Factions and characters

Rivals are led by characters with traits, an agenda and an opinion of you, and they act every week where you can see it. Pressure comes from their intents on the map, their demands in your inbox, and their agents inside your station.

### The four powers

| Faction | Capital | Leader | Agenda (what they push for) | Plays like |
|---|---|---|---|---|
| The Depot | Coney Island | The Senior Driver | Restore power and tunnels; reach the surface by engineering | Builder; best digging, workshops, squads gear |
| Synod of the Tunnel | Cathedral Pkwy | The Preacher of the Last Train | Convert stations; keep people underground | Persuader; propaganda, Hope, faith needs |
| Free Exchange | Wall St | The Rate Council (7 elders) | Control trade routes and prices | Economist; trade deals, buying loyalty, smuggling |
| Iron Directorate | Grand Central | The Traffic Chief | Order, the schedule, control of the sealed archives | Conqueror; strongest squads, curfews, intrigue |

### Leaders and opinion

- Each leader has 2 to 3 traits (Paranoid, Zealous, Greedy, Honorable, Vengeful) that change how they respond.
- Opinion of you (-100 to +100) moves with your actions and remembers them: "You took Spring St from us" stays as a -20 for 20 turns.
- At thresholds they act: below -50 they plan war or sabotage; above +50 they offer pacts, marriages, shared expeditions.

### How pressure is felt every week

- **Intents on the map** (see Turn structure): squads moving, preachers arriving, envoys coming.
- **Demands and ultimatums:** "Pay 30 tokens or the tunnel to Wall St closes", "Hand over the deserter or face the consequences". With a deadline in turns.
- **Agents inside your walls:** rival sympathizers among your residents (from refugees, trade, sermons). They spread propaganda, steal, or open the gates during an attack. Found through the radio room, the infirmary gossip, or a council member with high Talk.
- **Rivals court your outposts:** they fill the needs you neglect. If they do it better, the station leaves.
- **Escalation clock:** each rival has a hidden ambition meter; as it rises their intents get bolder, so ignoring a rival for 15 weeks is dangerous.

### Your council

- 3 seats at start (up to 6): Marshal (squads), Envoy (diplomacy and trade), Steward (station and laws), later Spymaster, Chaplain, Chief Engineer.
- Council members are promoted residents with skills and loyalty. Each one gives you one order per turn.
- A disloyal council member can leak plans, sabotage, or plot against you. Firing one has consequences.
- Vertical slice: 3 seats, 12 to 15 named characters in total (4 leaders, rival lieutenants, your council candidates).

## Story and mystery

The player starts with the public version of the Silence: one day the surface stopped answering, the radios went quiet, and nobody who went up came back. The hidden truth, revealed through artifacts and bunkers, is Sasha's: a gamma-ray burst hit a planet whose magnetic field had already weakened, and some people knew months in advance and saved only themselves.

### Artifact chains

Artifacts are fragments of knowledge, found on digs, expeditions, events and trade. Three chains, each opening one bunker:

| Chain | Found through | Opens | Reveals |
|---|---|---|---|
| Papers (orders, memos, diaries) | Ruins, Exchange trade, City Hall | The Administrative bunker ("The Floor") | The burst was predicted months ahead |
| Iron (dosimeters, devices, hardware) | Digs, flooded tunnels, surface expeditions | The Military bunker ("Quarantine") | How the bunkers were built and who was let in |
| Words (recordings, rumors, testimony) | Synod, events, radio room | The Science bunker ("The Observatory") | The full picture, and a way to repair the surface |

Bunkers are special locations on the map that cannot be won by propaganda. Each has its own people living as if nothing happened (a bureaucracy still holding budget meetings, soldiers guarding nothing, scientists living with guilt), a key character, and 2 to 3 ways to deal with it.

### Endings (full game)

- **Dominion:** you control the network. Order, at a price.
- **Council of Lines:** all surviving powers sign a pact at Times Sq.
- **Exodus:** with the Lift Key and the Science bunker's help, you lead people back to the surface.
- **The Truth:** open the Central bunker under Times Sq and choose: join the people who knew, expose them, bury them, or use their technology to repair the surface.

Factions react to the truth differently: the Depot is furious, the Synod sees a sign, the Exchange wants to sell it, the Directorate wants it buried. Vertical slice: one chain (Papers), one bunker (The Floor), and the Exodus or Dominion ending.

## Economy and numbers

The vertical slice uses six resources plus two meters. All numbers below are first-pass values for tuning in playtests; they live in data files, not code.

| Resource | Start | Made by | Spent on | Weekly use |
|---|---|---|---|---|
| Air | 60 | Air filters | Everyone breathes | 1 per 4 people |
| Food | 50 | Hydroponics, trade | Everyone eats | 1 per 3 people |
| Power | 30 | Generators | Rooms (1 to 3 each), lights | Sum of active rooms |
| Materials | 40 | Workshop, digs, salvage | Building, repairs, gear | Filter upkeep 2 |
| Tokens | 60 | Trade, tunnel tax, markets | Deals, bribes, buying goods | 0 |
| Influence | 20 | Meeting hall, events | Propaganda, envoys, laws | 0 |
| Hope | 60 | Light, sermons, victories, family rooms | Hardship, deaths, harsh laws | -1 baseline drift |
| Discontent | 15 | Hunger, harsh laws, unrest | Curfew, meeting hall, rallies | +0 |

### Key formulas (first pass)

- Room output = base x (1 + 0.15 x sum of staff skill above 1), capped at 2.5 x base.
- Starvation: if food or air is short, Hope -5 and 1 death per 10 people short that week.
- Station sympathy per propaganda order = 12 x lean match (2 if matching, 1 neutral, 0.5 opposed) x need fill (0.5 to 1.5).
- Battle: attacker strength = squad size x gear x (1 + Fight skill of leader / 10); defender adds garrison x fortification x 1.3; random factor 0.8 to 1.2; loser loses 30 to 60% of the force.
- Rival ambition: +2 per week, +5 when you take one of their stations, -10 after a signed pact.

**Target feel:** by week 8 the player should have had at least one shortage; by week 20 at least one rival ultimatum; by week 30 one Season that threatens a room. Playtests check these beats.

## Vertical slice scope

The slice is one complete 40-week run as The Depot at Coney Island against two rivals, on a 15-station map of south Brooklyn and Lower Manhattan. It answers one question: is the station-plus-network loop fun for a full run?

| Area | In the slice | Full game |
|---|---|---|
| Playable factions | 1 (The Depot) | 4 |
| Rival factions | 2 (Exchange at Wall St, Directorate at Grand Central) | 3 |
| Map | 15 stations, 2 sealed tunnels | 25+ stations, 6+ sealed tunnels |
| Room types | 8 | 15 |
| Laws | 8 | 20+ |
| Seasons of the Silence | 3 (Flood, Cold, Cough) | 4+ with escalation tiers |
| Named characters | 12 to 15 | 40+ |
| Events | 30 | 120+ |
| Artifact chains / bunkers | 1 / 1 | 3 / 3 + Central |
| Endings | 2 (Dominion, Exodus) | 4 |
| Platforms | Windows build + Android build | Steam (PC/Mac), Android, iOS |

**Cut from the slice:** marriages, council seats beyond 3, outpost room building (outposts use focus only), save slots beyond one, localization, achievements, sound beyond a basic set.

**Done means:** a stranger can finish a run without help, most playtesters want to start a second run, and every turn has at least two real decisions.

## Tech and production

Build in Godot 4 with GDScript, with all content in JSON data files so designers can add stations, events, rooms and laws without touching code. Rules run in plain scripts separate from scenes, so the whole simulation can be tested headless.

### Architecture

- **sim/:** pure game rules (no nodes): resources, rooms, residents, laws, network, rivals AI, events. Deterministic with a seed, unit-testable, runs a full 40-week bot game in seconds for balance checks.
- **data/:** JSON for stations (NYC names and descriptions reused from the current build), tunnels, rooms, laws, events, characters, factions, artifacts.
- **ui/:** two main scenes, StationView (cut-away) and NetworkView (subway map), plus sheets, modals, council screen, dawn report.
- **platform/:** saves, settings, store purchases (Android via the community GodotX RevenueCat plugin; Steam build has no in-app purchases).

### Art direction

Keep the current painted look for scene art (station portraits, event banners), and add a consistent sprite set for the cut-away. This is the biggest production risk, because AI image models do not produce consistent animated sprites.

- **Cut-away rooms and residents:** a pixel-art or flat-stylized set. Option A: a licensed asset pack plus a small commission for unique rooms. Option B: a deliberately simple silhouette style made in-house.
- **Network map:** keep the transit-map look from the current build.
- **Sound:** a small licensed ambience and UI set; music later.

### Monetization

- **Steam:** premium, $9.99 to $14.99, with the four-faction game in the base price.
- **Mobile:** free with The Depot, one purchase unlocks the other factions and endless mode (the Polytopia model). No ads, no energy timers.
- **Later:** paid scenario packs (new boroughs, new bunkers).

### Milestones

1. **Weeks 1 to 2, sim core:** resources, rooms, residents, turn loop, headless bot run. Gate: a bot plays 40 weeks without errors.
2. **Weeks 3 to 4, StationView:** cut-away, digging, building, assigning. Gate: the station half is fun on its own for 15 weeks.
3. **Weeks 5 to 6, NetworkView and rivals:** map, station needs, telegraphed intents, squads, 2 rival AIs. Gate: rivals create at least one crisis per 10 weeks.
4. **Weeks 7 to 8, content and polish:** 30 events, laws, seasons, one bunker, endings, art pass. Gate: 10 outside playtesters finish a run; most want a second.
5. **After the slice:** Steam page and trailer, wishlist push, then full content.

## Open questions

- Art option A or B, and the budget for a commission.
- Who owns writing (Sasha) and who owns balance and data files.
- Whether the current HTML build stays live on Play during the Godot rebuild.
