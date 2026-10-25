# Governors for held stations: balance plan (19 October 2026, for the owner's decision)

Item 4 of `docs/MAP_STRATEGY.md`. Idea taken from Crusader Kings (a named person holds land for you, their skills
and traits shape it), fitted to Underline. No code yet: this changes balance, so it waits for the owner's yes.

## 1. What the numbers say today (30 seeds × 40 weeks, current build)
| Bot | Outposts held (w10 / w20 / w40) | Shipped home per run | Influence left at the end |
|---|---|---|---|
| Careful | 1.0 / 0.9 / 1.0 | food 143, materials 48, tokens 24 | 335 |
| Expander | 2.8 / 3.1 / 3.4 | food 267, materials 87, influence 298, tokens 33 | 431 |

What this means:
- An outpost ships about **4–5 food a week**. A resident working a room at home adds only about **0.3–0.6** food a
  week (room output grows 0.15 per skill point above 1). Sending one person away costs almost nothing in labour.
- **Influence piles up unused** (300–430 at the end). It is the right price for a governor and a needed sink.
- Settling in costs 9–19 outpost-weeks per run of upkeep with nothing shipped.

## 2. The rule, as proposed
- **Who:** any resident who is not sick, away, in the guard or already governing. A **councillor may
  govern**, but their seat gives no order while they are away. That is the hard choice: a strong person out there
  or an order at home.
- **How:** on a held station's card (and its chips on the map), "Appoint governor" picks from a short list sorted by
  the skill the station's focus needs. Takes effect at next dawn. Recall is free; they are home the next dawn.
- **Price:** 5 influence to appoint, then **1 influence a week**. At 0 influence the governor comes home.
- **Skill bonus** (the skill that matches the focus: food–Labor, air–Tech, fortify–Fight, spread our name–Talk):
  skill 3–4 gives **+1** of the focus good a week, skill 5 **+2**. Added after the distance penalty, so a governor
  is what makes a far station worth it.
- **Talk 3 or more:** the station's loyalty **+2 a week** (it loses 4 when underfed, 5 when cut off).
- **Labor 3 or more:** settling in takes **3 weeks instead of 4**.
- **Traits:** Veteran: garrison +3 while there. Devout: unrest falls one step faster. Black marketeer: +1 tokens a
  week (the "takes a cut" event comes in a later text batch). Others: no effect for now.
- **Lost station:** if the station falls while governed, the governor walks home **sick for 3 weeks**. No deaths
  in v1.
- **Limit:** one governor per station.

## 3. Expected effect
- Careful (1 outpost, one Labor-3 governor on food): about **+1 food a week, +30–40 food per run** (+25% of what the
  outpost ships), about 40 influence spent of 335 spare.
- Expander (3–4 outposts, three governors): about **+4–5 focus goods a week, +130–160 per run** (+35–40%), about
  110 influence of 431 spare. Settling shortened: about 5 fewer upkeep weeks per run.
- Risk: the expander gets stronger. Check against the corridors in `sim/check_balance.gd`. If it goes out of a
  corridor, the first lever is the weekly price (1 to 2 influence), the second the skill-5 bonus (+2 to +1).

## 4. The look (same package)
- A small round portrait medallion (the resident's existing portrait) hangs on the pin of every governed station,
  like a seal; the yield chip of the boosted good shows the bonus in gold ("+6 ▲1").
- Card: "Governor: Mara Quill, Tech 5, +2 air" with Recall; the appoint list shows each person's bonus before you
  pick.

## 5. Work, if the owner says yes
1. Sim: person field `governs`, station field `governor`, appoint and recall orders, the bonus in
   `Formulas.outpost_flow`, upkeep in `_deliver_outposts`, the councillor-away rule in `order_councillor`, the
   loss rule in `_capture`. Save format version up, with an old-save migration (no governors).
2. Bot: the expander appoints the best matching non-councillor on every settled outpost if influence ≥ 20; careful
   and follower never do (they stay the baseline).
3. Map and card UI, EN and RU text written natively.
4. All 9 gates plus the 30-seed balance check; write the result into `docs/DECISIONS.md`.

## 6. Owner decisions needed
1. Councillors may govern (their order is lost while away): **yes** recommended.
2. Price 5 + 1 influence a week: **yes** recommended (influence has no sink today).
3. A lost station sends the governor home sick, no death in v1: **yes** recommended.
4. Governor events (stealing, a petition, a rival's bribe) as a later text batch, not in this package: **yes**
   recommended.
