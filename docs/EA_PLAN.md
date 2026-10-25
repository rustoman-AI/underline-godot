# Early Access plan (draft v1, project lead)

## Target
- First full run (40 weeks) 3 to 4 hours for a new player. Steam refunds are allowed under 2 hours played, so the first run must clear that comfortably.
- Replay value for 8 to 12 hours total: different endings, different leader deals, different seasons and events, harder modes.
- Price 9.99 to 12.99 USD. Early Access promise: more factions, more stations, more events later; the base game must stand on its own.
- Do not change room balance or the map. Everything below adds content and consequences on top.

## Where we are (counted in the repo, not played yet)
- 40 weeks, 1 playable faction (Depot at Coney), 15 map stations, 9 rooms, 9 laws, 34 events (12 with a follow-up), 5 check events, 2 endings, 1 artifact chain and 1 bunker.
- Now finished: five leaders with audiences and dirty deals, voiced EN/RU; faction art; hubs; 56 voiced stories (the "heard N/M" counter exists); save hardening; fair audience scheduling.
- Slice "done means": a stranger finishes a run without help, wants a second run, and every turn has at least two real decisions. We have not measured any of these.

## Gaps that cost hours
1. Variety: 34 events over 40 weeks repeat. Full game aims at 120+. EA target: about 80.
2. Consequences: leader deals happen once and have no aftermath.
3. Endings and the mystery: 2 endings, 1 chain, 1 bunker. EA target: 3 endings, 2 chains, 2 bunkers.
4. Replay hooks: no difficulty levels, no scenarios, no start modifiers.
5. Onboarding: unknown; a stranger test is needed.
6. Pacing data: nobody has timed a real run.

## Milestones
- E0 Measure (1 week): content audit and run-time estimate (cursor_content_audit.txt), plus 3 to 5 outside playtesters on the current build with local logging (turn times, quit points, choices). Output: real hours per run, repeat rate of events, dull weeks.
- E1 Consequences (2 weeks): each leader deal and each refusal gets 2 delayed events (10 to 12 total). Example: the Directorate comes back for a second name; the burned Depot paper resurfaces; the Exchange sells your books; the Lamplighter toll turns into a debt; the Synod asks you to stop an expedition. Uses the three memory slots that exist.
- E2 Event pool (3 weeks): 34 to about 80. Sources: resident story events built on the 56 voiced backstories, season-linked events, leader-linked events. Each event has at least two real choices with visible costs.
- E3 Second chain and bunker (3 weeks): Words chain, Observatory bunker, third ending. Faction reactions as in GDD (Depot furious, Synod sees a sign, Exchange sells it, Directorate buries it).
- E4 Replay (2 weeks): 3 difficulty levels, 5 start modifiers (for example a flooded cell, a sick council member, a surprise caravan), end-of-run summary with what the leaders remember.
- E5 Onboarding and polish (2 weeks): first-run guidance, tooltips, a short intro that tells the Silence story, settings, achievements, Steam page, trailer.
- E6 Playtest loop: 10 outside players, then fix. Gate: most want a second run.

## Rules
- Text is written by the project lead (docs/LEADERS.md style: gray morality, no em dashes, nobody smiles). Cursor implements. ChatGPT draws only what the events need. Muse voices only leader and story lines the lead approves, with the 0.24 credit per character rate in mind.
- Every new event goes through the bot (no crash, no dead end) and the audience/network/save checks.
