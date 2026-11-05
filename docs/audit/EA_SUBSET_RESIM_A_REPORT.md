# release/ea-subset — RE-SIM A report

**When:** 2026-11-04 (America/New_York)  
**Agent:** bc-fe6d00d3 → draft PR [#71](https://github.com/rustoman-AI/underline-godot/pull/71)  
**Branch:** `release/ea-subset` (tags `ea-step-01-pr37` … `ea-step-06-pr48`)  
**Master:** untouched. Original PR branches: not rewritten.

## Outcome

Stopped after **step 6** (through #48 Deep Life). RE-SIM A careful first-run loss **5/60 = 8.3%** — **under** Designer's 15–35% band. No balance numbers tuned. RE-SIM B/C and steps 7–12 (#50…#59) **not run**.

## Careful soak (60 seeds, 40 weeks)

| Seed | Week | End |
|---|---|---|
| 1 | 34 | revolt |
| 13 | 32 | revolt |
| 23 | 32 | revolt |
| 32 | 31 | revolt |
| 33 | 30 | revolt |

55/60 reached `time`. Soak also flagged `home_pos = southdepot` on all 60 (present on master, not introduced by this stack).

### Drift vs solo packs

| Tree | Careful loss |
|---|---|
| P62 alone (#46) | 9/60 (15.0%) |
| + P64 (#47) | 6/60 (10%) |
| + P66 (#48) = tip | 5/60 (8.3%) |

Stacking the three life packs made careful **easier**, not harder.

## Other gates at tip

- `check_balance` (30 seeds): **FAILED** — careful seeds passing 20/30 (need 28); careful losses 3/30 inside 3–11; other rows OK.
- `bot_run`: **FAILED** — careful 5/60 outside the old 15–30% band; also `stores_turn` / `ration_coat` audience banners (same miss from step 1, pre-event packs).
- Schema: still **14**. Read-ahead: #50/#53/#55 need no bump; #54 stays 15; #59 renumbers to 16 after #54.
- `check_save`: fails from step 4 on (odd-week help path never sampled on even-week-only drive) — pre-existing soak/drive shape, not a new PERSIST key.
- Pack gates: TUNNEL LIFE / DEEP LIFE each failed once on "shipped the five P62 ids" (union/id collision signal to inspect before stacking further).

## Holding

Per merge order §5, checkpoint A must land in band before continuing. Next call is Temur's (and Designer's if they want a pack/pool fix). Options Code will **not** take alone: tune balance numbers, merge to master, or stack #50+ while under band.

R2 release polish (`RELEASE_POLISH_R2_PENDING.md`) still waits for re-sim C on the subset tip.


## Master baseline (2026-11-04, af11b17)

Careful soak 60×40: **2/60 (3.3%)**. Lost seeds 20@w30 revolt, 52@w34 revolt. bot_run careful 2/60. `stores_turn` / `ration_coat` audience banners already FAIL on master. SAVE_SCHEMA 14. check_balance careful FAIL (21/30 pass; 1/30 lost).

## Decision (Designer auto-map + Temur executive authority)

Master is **under 9/60**, so path **A**: accept a **temporary careful band of 5–35%** for this EA release-subset tip. A post-launch tension pass is **owed**. No balance-number edits on this path. Continue stacking #50→#59 and run RE-SIM B/C against 5–35%.
