# P85 Outpost Ledger — Texts READY at design-gate (awaiting Designer stamp)

**Roadmap:** **P85** (NEW invent — DEC-OL1…OL3)  
**Spec:** `/workspace/OUTPOST_LEDGER_P85_SPEC.md`  
**Files:** `outpost_ledger.json`, `outpost_ledger_ru_fragment.json`  
**Status:** Texts READY at design-gate (authored 2026-10-27). Soft dawn: **NONE**.  
**Namespace:** **`ledger.*`** — HARD NO reopen `wall.*` (P77 Line Wall `plate_ledger` is different).  
**Cite (unreopened):** **P52** Station Focus · **P55** Community Perks · **P57** Focus Pip · **P41** Yard Clearance.  
**P81–P83:** unreopened.

Tone: dry metro grit. One thin glance on the Visit sheet — not a second warehouse UI or Civ city screen.

**Key count:** **8** (`ledger.*`) — SPEC STRING checklist exact. Placeholders: `{mats}`, `{food}`, `{goods}`, `{n}`.

## Keys

| Key | EN | RU |
|---|---|---|
| `ledger.name` | Outpost Ledger | Книга форпоста |
| `ledger.tip` | Outpost Ledger. What this station shipped last week. | Книга форпоста. Что ушло с этой станции за прошлую неделю. |
| `ledger.first` | The outpost keeps a ledger. | Форпост ведёт книгу. |
| `ledger.status` | Last week: {mats} mats · {food} food · {goods} goods | За прошлую неделю: {mats} матер. · {food} еды · {goods} товара |
| `ledger.empty` | Holds nothing counted. | Ничего не учтено. |
| `ledger.mats` | {n} mats | {n} матер. |
| `ledger.food` | {n} food | {n} еды |
| `ledger.goods` | {n} goods | {n} товара |

## Notes for Code

- Visit owned **non-capital** only: thin Ledger line bound to **existing** Code mats/food/goods fields. Capital omit MVP. Foreign/unowned/hidden: never show.
- Tip = `ledger.tip`. Full glance = `ledger.status`. Empty/zero = `ledger.empty`. Token chips = `ledger.mats` / `ledger.food` / `ledger.goods`.
- First Visit float once = `ledger.first` (`seen_outpost_ledger`). Soft dawn **NONE**.
- Never invent economy numbers, haul verbs, or new stockpile fields. No map mark MVP.
- Do **not** reopen `wall.*` / Line Wall plates. Art none required.

## HARD NOs honored

Soft dawn chip invent; invent economy / new stockpile fields / haul verbs; invent goods or hope from Ledger; reopen `wall.*` / Line Wall plates; balance edits; map mark that steals crowded slots; capital Ledger invent in MVP; invent numbers not in Code; reopen P81–P83; Art required.
