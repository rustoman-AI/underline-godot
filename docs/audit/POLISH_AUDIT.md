# P67 release polish

Visual and feedback only. No balance numbers, economy, combat, event weights, or map layout.

## Implemented

1. **Station order buttons.** Send envoy, Propaganda, Trade and the other plain orders used the engine button, so they did not match Patrol / Raid / Assault on the same sheet. They now use the same dark brass face: a lighter face on hover, a darker face on press, and a dimmer face, muted caption and arrow cursor when the order is locked. Margins stay fixed, so the button does not jump.
2. **Map pick ring.** The open station was a 1.6px graphite arc that sat on the junction ring. Hover and the open sheet now draw a brass ring outside the pressure arc and inside a claim ring. The open station is thicker and fully opaque; hover is thinner.
3. **Event plates that already had a file.** `resolve_event_banner` preferred the `banner` mood alias, so lamps, smuggler, rumble, desertion, diesel, clog, static and several follow-ups (`toll_next`, `knock_next`, `loan_next`, `refugees_next`, `preacher_next`, …) showed a shared mood plate while `assets/events/{id}.webp` sat unused. The event's own file wins. Events with no file of their own (wire, leak, and the rest) still use the authored plate. Banner fields and weights are unchanged.

## Implemented, round 2

4. **Sheet chrome.** Visit station, Back to your station, Back to the map, Party, Cancel order, Recruit soldier, Release, and the visit sheet's Back to map used the engine button. They now use the same dark brass face as Send envoy, including the dim locked face on Recruit and Release. Captions, tooltips, and costs are unchanged. The Details fold is still the engine button.
5. **Focus chips.** An owned outpost copied one face onto normal, hover, and press, and the selected chip used a thicker border, so a pick could bounce. Every state now shares a 6px margin and a 1px border. Hover and press only change the fill. A light chip darkens; a dark chip lifts. The selected chip stays a different colour from the idle ones.
6. **Yard toast.** The yard line was cream text with a heavy outline. The map line already sat on a paper plate. Both now use that plate. The plate is z 18, under the modal dim (z 20), so an open card covers it instead of the line drawing across Demolish. A toast raised from the main menu still sits above the menu.

## Still open

**P1**

- Metro stations (Greenpoint, High St, Canal, Spring, and the rest of the player line) have no hub file. The visit falls back to a room picture or a name plate. That needs new art, not a wire.
- `market_food.webp` and `market_next.webp` are the same picture. Each card now asks for its own file, and they still match.
- Filled room seats light only the Unassign button. The empty seat already lights on hover.
- Settings still says "No hover ticks or drips…" after hover ticks were removed. Copy only.
- The station sheet's Details fold is still an engine button. Left alone this round; the named chrome was Visit, Back, Party, Cancel, and Recruit.

Checked and left alone: people rows, assign chips, and empty seats already have hover; need ticks, join pulses, and the dawn chip already follow the recent plate-and-float pattern. Held packs P55–P70 and the RELEASE_POLISH RP1–RP5 pack were not started.
