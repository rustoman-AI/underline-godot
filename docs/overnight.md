# Overnight log, 2026-10-11

Nothing pushed. Balance untouched.

## 1. VO Phase 3 and story loudness

**Phase 3.** All 32 files (`event_*_resolve`, `sys_*`, EN+RU) unpacked into `assets/audio/vo/`. Every name matched `data/vo/underline_vo.json`; nothing renamed, no path edits, no playback code changes. 56 of 56 pack lines now have audio in both languages; only the 16 hand-written bulletins in `data/vo/cable_radio.json` stay text.

**Scope of normalization.** The request listed two versions: all voice into `_originals/`, then stories only into `_originals_story/` with radio, events and system untouched "because they are mixed differently". I followed the later one. The other groups are measured below so the decision can be revisited.

**Method.** `.tools/normalize_vo.ps1`: two-pass ffmpeg loudnorm, I = -23 LUFS, LRA 11, linear, re-encoded Vorbis q4 mono 44.1 kHz (sources were mono 44.1 kHz ~80 kbps). Always encodes from the original copy, so reruns do not stack generations. A first run at TP -1.5 left 10 stories at -1.4 to -0.4 dBTP after Vorbis encoding (ada_story_ru worst); rerun with a -2.5 dBTP loudnorm target, after which every story measures at or under -1.7 dBTP.

**Originals.** `assets/audio/vo/_originals_story/` (60 files, with `.gdignore` so Godot skips them), listed in `.gitignore`.

**Measured after** (`.tools/measure_vo.ps1`, ffmpeg ebur128, integrated LUFS):

| Group | n | min | median | max | spread | max true peak |
| --- | --- | --- | --- | --- | --- | --- |
| story | 60 | -23.0 | -22.9 | -22.8 | 0.2 dB | -1.7 dBTP |
| radio | 20 | -22.3 | -21.7 | -20.7 | 1.6 dB | -0.9 dBTP |
| event+system | 32 | -23.3 | -21.8 | -19.0 | 4.3 dB | -0.8 dBTP |

Before: stories ran -28.0 (leo_story_en) to -17.9 (chris_story_en), about 10 dB.

Ada and Leo now: ada_story_en -23.0, ada_story_ru -23.0, leo_story_en -23.0, leo_story_ru -23.0 against a story median of -22.9. All within the 2 dB tolerance.

Not done, by the later instruction: event+system spread is 4.3 dB (event_static_resolve_en -23.3 to sys_morale_high_en -19.0) and both short groups sit about 1 dB above the stories. `.tools/normalize_vo.ps1 -Pattern 'event_*.ogg' -Backup _originals` (and `sys_*`, `radio_*`) would bring them in line if wanted.

Commit: d58ad68 (VO only: the 32 new ogg, the 60 normalized stories, their .import, INDEX.md, .gitignore).

## 2. Figures and palettes

Commit: d342bab.

**Committed.** `assets/figures/poses/` body_01 to body_12 and air_filter_01, webp only (the png twins were byte-for-byte the same pose, so the loader used to draw every pose twice). `fig_standing.webp` (= body_01), `fig_walking.webp` (= body_04) and `fig_carrying.webp` (crate held in both hands) replaced, all three checked whole.

**Rejected, not committed.** generator_01, workshop_01, hydroponics_01, quarters_01: legs detached from the body, a stool or tool fused into the silhouette. The new fig_working, fig_kneeling and fig_sitting had the same faults, so those three were restored to HEAD. All rejected files (plus every pose png) were moved, not deleted, to `incoming-art/poses_rejected/` (untracked, ignored by Godot). Rooms whose work pose was rejected fall back to each spot's own pose: standing/walking spots get the new bodies, working/kneeling/sitting spots keep the old whole figures from HEAD. Only the air filter has its own work pose.

**Palettes.** slate / ochre / drab / security: each pack has all 18 source sheets, same sizes as the base, all real recolors (none identical to the base). Nothing missing. `.tools/pose_palettes.gd` built the 4 x 13 webp for the committed poses only (`poses/palettes/<name>/`). The loader picks pose and palette from a hash of the resident id (`_fig_for`), so a resident keeps the same body and colors every frame and across saves. In a fresh game: 25 residents on 11 distinct bodies, palettes spread base 4, slate 2, ochre 7, drab 6, security 6.

Note: the station draws figures through its amber light tint, so palette differences read as subtle shade changes rather than distinct colors. Left as is (art style, not a bug).

**Not committed:** `assets/figures/residents/`, `incoming-art/` (incl. palette_tests, contact sheets), png/webp duplicates.

**Concurrent edit.** Something else rewrote fig_carrying / fig_standing / fig_walking at 08:51 while I worked. I re-checked the versions on disk (hash match with body_01 / body_04, visual check of all three) before committing them.

## 3. Stories heard counter

Commit: ebcd74e.

- People panel, under Backstories: "Stories heard N/M" / "Истории услышаны: N/M" with a bar. M = residents at the station whose story has audio in the current language, N = those heard.
- Amber dot after the name of everyone not yet heard (people rows, and on the Dossier button of their card).
- Heard means the story played to the end (90% or more). Closing the dossier or pressing Stop early keeps it unheard. The first open still auto-plays once; later opens wait for "Play story".
- No spoiler: until heard, "In their words" shows "Listening. The words appear here once the story ends." while it plays, or "Listen to the story first..." otherwise. The subtitle pill still runs during playback. Stories without audio keep showing their text.
- Saves: `vo_heard` stores "started" during the first listen and true when heard; old saves (true) read as heard.

## 4. Verification

- Bot: BOT RUN OK, Missing banners: none (after each commit's changes).
- `.tools/vo_counter.gd`, RU and EN, real playback:
  - Ada, first dossier open: story plays (ada_story_ru.ogg, 56.6 s; EN 56.4 s), text hidden; closed early: still unheard; reopened: no auto-play, "Play story"; full listen: heard, text shown; counter 0/25 to 1/25, Ada's dot gone.
  - System cue food_critical through the real cue queue: sys_food_critical plays.
  - Event resolve: event_lamps_resolve plays.
- Station with different whole bodies: `shots/figures_station.png`, `shots/figures_station_zoom.png`.
- Screenshots (local only, `shots/` is ignored): `shots/counter/ru/` and `shots/counter/en/` (ada_playing, ada_unheard, ada_heard, counter_people_before/after, counter_system_cue).

## 5. Faction leaders and audiences

**Data.** `Downloads/factions.json` went in unchanged as `data/faction_leaders.json`, and `FACTIONS.md` as `docs/FACTIONS.md`. The old `data/factions.json` stays: it is the map's rival powers (capitals, squads, ambition, lean) and the sim reads it everywhere, so overwriting it would break the map.

**Opinion.** Leader opinion (`standing`) is its own number per leader, -100..100, start from `start_opinion` (Depot +20, Black Flag -10, others 0). Bands come from `opinion_bands`. It is kept apart from the map's `opinions` (Exchange +10, Directorate -10 at start, driving trade, war and drift), so map balance is untouched. Each leader remembers the last `memory_slots` (3) deeds as text. The cooldown between audiences of the same leader is `audience_cooldown_weeks` (6).

**Arrival** (at dawn, read from the `arrival` field; `week_N` takes N from the data):
- Pike: radio room built, or week 6.
- Halloran: a Directorate squad intent aimed at one of our stations or a station bordering ours, or food under one week. Any Directorate squad would bring him in week 1, during the guide, because their squad moves from the start.
- Kato: first season, or week 10.
- Pell: first caravan (first trade order).
- Bird: first sealed tunnel (the sealed door find on the lower level).

At most one leader per dawn, the earliest due. A leader left unanswered until the next dawn counts as a refusal (FACTIONS.md: silence is refusal). Bot runs, never answering: Exchange week 2, Pike 6, Halloran 4-10, Kato 10, Bird 20-29, then each again every 7 weeks.

**Card.** Same NARRATIVE card as the dawn report, shown before it: sign, leader name, title and faction, opinion and band, the one opening line, what they remember, then "Hear them out" / "Not today". Hearing shows the dirty price with every number before the player can agree: hope, discontent, food, each opinion shift, the person to be handed over by name, the Papers clue count, Bird's opinion and whether her way is a lie, the free room tier, the mark. Refusing at either step is journaled and remembered.

**Deals** (numbers from the json only): hope, discontent, food and opinion shifts apply as listed. Flags in the save: `collaborator`, `buried_papers`, `stayed_down`, `open_books`, `lantern_toll`; nothing clears them, and after `collaborator` every later audience says so.
- The list: hands over the least skilled resident outside the council (named on the card), puts Curfew in force, air filter +1 tier.
- Burn the papers: destroys one Papers clue if one was found; otherwise only the mark and the journal row. Workshop +1 tier.
- Lantern toll: costs 8 food (disabled if the stores are short). Below zero opinion (where she starts) the way is false and the journal says so.

**Not done, because the json has no numbers or the mechanics do not exist yet:** the Directorate squad for eight weeks, faster digging, the eight-week ban on surface expeditions, the Synod medic, a dearer Exodus, the Exchange price cut and rival-need race, the volunteer option of the lantern toll and the flooded way itself, Pike turning hostile on publication, the exceptions to the cooldown at hostile and pact. The deal texts on the card still mention them because they are the json text.

**Sign.** `res://assets/factions/<id>_symbol.webp` if the file exists; none do yet, so the card shows the first letter of the faction name on the faction color. No portraits.

**Journal in red:** person handed over, papers burned, Bird's false way. Strings en + ru.

**Checks.** Bot OK, no missing banners. `.tools/audience_probe.gd --accept` (3 seeds, every deal taken): all five flags set, three red rows, no errors. `.tools/audience_shots.gd` RU and EN: Halloran deal takes Lila Voss (25 to 24 residents), Curfew on, Directorate +30, Depot -25 (Pike now -5 and remembers it); Pike turned away, journal lists both. Screenshots in `shots/audience/<lang>/` (aud_halloran, aud_halloran_terms, aud_pike, aud_journal), not committed.

**Again:** something rewrote `assets/figures/` while I worked (broken work poses, png twins and the palettes back on disk). Not touched, not committed.

## 6. poses_fix review: nothing committed

Checked `incoming-art/poses_fix/` (lineup and every file) beside body_01 at full size and at room size (32 px tall). No pose generated, `build_fixed_poses.gd` not run.

None pass. They are not redrawn work poses: each is one of the existing standing bodies, unchanged, with a flat vector prop pasted over it. Arms that "hold" things are plain grey tubes, props are flat untextured rectangles and lines, and the figure keeps the idle stance. That is the blueprint look the check rules out, and at 32 px it reads as a standing body next to a colored box. Legs and floor contact are fine in all of them.

| File | Problem |
| --- | --- |
| hydroponics_01 (= work_hydro_01, byte-identical) | body_01 standing upright, not leaning; a flat tray on a wire stand drawn across her shin; the "secateurs" is a grey bar at the tray edge, not in her hand |
| work_hydro_02 | side body with two grey tube arms; flat brown tray |
| work_hydro_03 | grey tube arm; flat striped box as the canister |
| workshop_01 (= work_shop_01) | hatched brown rectangle pasted as the apron, a single straight line as the cable, no torch in the hand, sparks floating beside the hip, the mask is a black blob at the neck |
| generator_01 (= work_generator_01) | grey tube arm reaching to a flat pipe post; no valve wheel |
| work_generator_02 | body_01 with a flat yellow box and red line pasted at the hip |
| air_filter_01 (= work_filter_01) | radio body with a grey tube arm to a flat column of squares and a white disc |
| work_infirmary_01 | body_01 with a flat clipboard pasted at the hip |
| quarters_01 (= work_infirmary_02) | crouched body on a flat hatched box; box overlaps the legs |

All stay in `incoming-art/poses_fix/`. Nothing was committed: no hydroponics pose, no duplicates, lineup or fixes.txt.

`build_fixed_poses.gd` had already run at 09:25 and left its output in `assets/figures/`: those same poses as webp+png (generator, hydroponics, quarters, workshop, with palettes), and it overwrote air_filter_01.webp, all 52 palette files and four fig_*.webp. The station loader reads that folder, so the game was drawing them locally. All 94 files were copied unchanged to `incoming-art/poses_rejected/build_fixed_0925/` (hashes checked), then the untracked ones removed from assets and the tracked ones restored to HEAD. body_01 to body_12 were never modified. The station now draws what is committed: bodies everywhere, the air filter work pose, and the old whole fig_* for working/kneeling/sitting spots. So hydroponics has no work pose yet; its crew uses the room's spot poses.

## 7. Short lines loudness

Rule: inside a group, more than 2 dB spread gets leveled to -23 LUFS, true peak at or under -1.7 dBTP. Stories untouched.

| Group | n | min | median | max | spread | max true peak | action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| story | 60 | -23.0 | -22.9 | -22.8 | 0.2 dB | -1.7 dBTP | none |
| radio | 20 | -22.3 | -21.7 | -20.7 | 1.6 dB | -0.9 dBTP | none, inside 2 dB |
| event+system before | 32 | -23.3 | -21.8 | -19.0 | 4.3 dB | -0.8 dBTP | leveled |
| event+system after | 32 | -23.0 | -22.9 | -22.5 | 0.5 dB | -2.3 dBTP | |

Same two-pass loudnorm as the stories (`.tools/normalize_vo.ps1 -Pattern 'event_*.ogg'` and `'sys_*.ogg'`, `-Backup _originals_short -Target -23 -Peak -2.5`; the -2.5 loudnorm target leaves room for the Vorbis overshoot). Originals: `assets/audio/vo/_originals_short/` (32 files, `.gdignore`), in `.gitignore`. Godot reimport clean, VO check OK (56 voiced per language). Radio keeps its -0.9 dBTP peak because the group was not leveled.

## 8. Factions, second request

The attached factions.json and FACTIONS.md are byte-identical to what went in with a7b97d8 (`data/faction_leaders.json`, `docs/FACTIONS.md`), so section 5 already covers the request; no code change. That commit came before the poses and loudness commits because it was done in the previous pass.

**Checks after all three:** bot OK, no missing banners. `.tools/audience_shots.gd` RU and EN unchanged (Halloran card, terms, deal, Pike turned away). Station with the committed poses: 25 residents on 11 distinct bodies, hydroponics crew on body poses. Screenshots in `shots/iter3/<lang>/` (aud_halloran, aud_halloran_terms, aud_pike, aud_journal, figures_station, figures_station_zoom), not committed.

## 9. Audience card shows only what the turn applies

The terms card promised things the sim never did. Now `Game.audience_effects()` computes the deal's consequences once, `_apply_audience` applies exactly that dictionary, and the card prints only its lines: Hope, Discontent, Food (after clamping to 0..100 and food at 0 or more), opinion shifts (after clamping to -100..100, zero shifts dropped), who is handed over, the law if it is not already on, the free tier with its name, the Papers clue, the mark. The deal text from json and the leader's opening are no longer on the card: three of the five openings promise things the game does not do (Halloran's free squad, Kato's "next person you send up", Bird's "the expensive way").

What each deal was supposed to connect to, and what was found:

| Deal | Card now | Not shown, why |
| --- | --- | --- |
| the_list | Hope -8, Discontent -6, opinions, hand over the least skilled non-council resident, curfew, free air filter tier | Directorate squad for 8 weeks: map squads are one per faction (`squads[player]`, `squads["directorate"]`); a lent squad would need a second player squad, new orders and combat. Line dropped. |
| burn_papers | Hope -4, opinions, one Papers clue destroyed if you hold one, free workshop tier | Faster digging: dig time is computed in code (`_dig_cost`, 1 + level turns), no number in faction_leaders.json. Line dropped. |
| stay_down | Hope +12 (one time, applied now), opinions | Surface exits ban: there are no surface exits, the only expedition is the South Ferry tunnel. Medic and Exodus cost not promised. |
| open_books | Food +40, opinions | Caravan discount: the trade order is one time (`trade_on` stays on, there is no next visit) and json has no discount number. Loyalty monopoly not built. |
| lantern_toll | Food -8, opinions; below 0 opinion one extra line "she takes the toll and gives nothing back" | Volunteer option and flooded way: neither exists. Below 0 the only extra is a red journal row "Bird took the lantern toll and gave nothing back." No bunker. |

The free tiers and curfew were already real; they are now shown with the actual room and step name ("Air filter: charcoal, free."), or not at all if the room is missing or fully upgraded, or curfew is already on.

**Cooldown:** the 6 week gap is skipped only for leaders in the hostile and pact bands. No Pike revenge: publishing clues does not exist.

**Checks:** `.tools/audience_probe.gd --accept` takes every deal over three seeds (15 deals, all five kinds) and compares each shown value with the measured change: 0 mismatches. `.tools/audience_shots.gd --lang=ru` confirms Halloran's deal through the UI button and prints shown vs changed: Hope -8/-8, Discontent -6/-6, Food 0/0, Directorate +30/+30, Depot -25/-25, Synod -15/-15, Black Flag +5/+5, Exchange 0/0, residents 25 to 24 (Lila Voss), curfew off to on, air filter upgrade 0 to 1 (charcoal), collaborator set. Bot OK, no missing banners. Screenshot `shots/aud_halloran_terms.png` (RU), not committed. Section 5's "Not done" notes about Bird's false way and free tiers are superseded by this section.
## 10. Faction symbols and leader portraits

**Point 1 re-checked.** The audience card no longer prints the json deal text or the openings (section 9, commit 49e3fcc), so no squad, medic, way to a bunker or discount appears. The price lines come from `Game.audience_effects()` and are what `_apply_audience` applies. Cooldown skips only the hostile and pact bands. The RU run below confirms it again.

**Symbols** (`incoming-art/factions/*_symbol.png`, 256 px, single colour each, viewed downscaled to 24 px):

| Symbol | Result | Why |
| --- | --- | --- |
| depot (brake wheel) | committed | rim, hub and spokes read at 24 px |
| directorate (dial, one hand) | committed | ring and hand read; tick marks merge into the rim |
| exchange (scales, two tokens) | committed | beam, post and both rings read |
| synod (ring of lanterns) | left | the thin ring vanishes at 24 px, leaves six separate spots with notches |
| black_flag (flag and lantern) | left | the lantern under the flag turns into a blob next to the pole |

**Portraits** (1024 px), compared with `assets/portraits/portrait_01.webp` (sepia photo, tiled tunnel):

| Leader | Result | Why |
| --- | --- | --- |
| vess_halloran | committed | whole face, one person, clean coat and frame, same style |
| ione_kato | committed | whole face, one person, clean, same style |
| harlan_pike | left | semi-transparent grey shape pasted over the eyes and cheek; cap looks pasted on |
| idris_pell | left | translucent vertical bars like a stamped letter across the chest |
| nessa_bird | left | flat vector lantern stamped on the chest, a second style and colour |

The passed files were copied byte for byte into `assets/factions/` as png (LFS) with mipmaps on. No conversion script was run (the attempt was refused by review as too close to a generator, so plain Copy-Item was used). The card takes the json `.webp` path or the same name as `.png`; missing file gives the letter plate, missing portrait gives no picture.

**Card:** portrait 112 px left of the text when the file exists; symbol at 24 px before the title, letter plate on faction colour when it does not (synod, black flag). No build_factions_art.gd, generate_perfect_symbols.gd or pose generator was run.

**Checks:** bot OK, no missing banners. RU `.tools/audience_shots.gd`: Halloran with face and dial, shown vs changed all match (Hope -8, Discontent -6, Directorate +30, Depot -25, Synod -15, Black Flag +5, Lila Voss handed over, curfew on, air filter charcoal, collaborator). Pike shows the wheel and no portrait. Screenshots in `shots/` (aud_halloran_terms, aud_pike, review_symbols, review_faces), not committed.
## 11. factions_v3 portraits and symbols

**Superseded by section 12.** The user rejected the smiling portraits and this art direction. The acceptance rule below is historical, not current guidance.

`factions_v3.zip` unpacked to `incoming-art/factions_v3/` (not committed). All ten files are 1408 px; portraits are colour photos, symbols are single colour on transparency.

**Portraits.** New rule: reject only for a broken face, a second head or text on the picture; smiling or looking past the camera is fine. All five pass and replace the files in `assets/factions/`: Pike (cap, smiling at camera, engine cab), Halloran (dark coat, looking aside, cold), Kato (grey hair, broad smile, arched tunnel), Pell (scarf, laughing, looking aside), Bird (dark background, faint smile, looking aside). They are colour, not sepia like the resident portraits; under the new rule that is not a reason to reject.

**Symbols.** The game still showed the old flat icons from the first pack (wheel, dial, scales; letters for Synod and Black Flag), so all five v3 symbols replace them: worn brake wheel, dial with one hand, open ring, bar over two tokens, torn pennant. The pennant and the bar-over-tokens are drawn small inside the canvas, so at 24 px they read but are smaller than the others.

Files copied byte for byte (LFS), mipmaps on in the imports. No generator run. Godot was run only for import, the bot and the screenshot script (approved).

**Checks:** bot OK, no missing banners. RU `.tools/audience_shots.gd`: Pike, Bird and Halloran cards with faces and symbols (`shots/aud_pike.png`, `aud_bird.png`, `aud_halloran.png`); Halloran's terms vs change still all match.

## 12. Dark faction art — no smiling

The leader portraits in this section were later rejected. Its monochrome symbol direction was superseded by section 13 at the user's request.

Replaced all five leader portraits and all five faction symbols in `assets/factions/` using new built-in ImageGen outputs. No earlier smiling generation was installed. Source PNGs and the exact prompt set are in `incoming-art/factions_dark/` (`prompts.json`). Existing filenames, PNG fallback loading and mipmapped imports are retained.

Current direction: people responsible for lives at the end of the world. No smiles, smirks, exposed teeth or cheerful expressions. Charisma comes from distinctive features, guarded eyes, exhaustion, conviction and restraint. Pike is a battered driver, Halloran a severe dispatcher, Kato a grave spiritual leader, Pell a calculating broker, Bird a watchful tunnel survivor. Dark charcoal clothing, muted colour, directional light and readable faces replace the pleasant posed photographs. `docs/FACTIONS.md` now states this direction and removes the instruction for Pell to smile.

Symbols: damaged three-spoke brake wheel; octagonal clock seal; broken vigil ring with a joined flame; heavy token scales; broad torn pennant. All five have alpha transparency and were inspected on a dark background at 24 px. The flag now fills its canvas; the Exchange tokens and central support remain distinct. No black background squares or letter fallbacks.

Validation: Godot imported all ten PNGs; `sim/bot_run.gd` returned `BOT RUN OK`, missing banners none. `.tools/dark_faction_cards.gd` checked that all five portraits load and all five symbols return TextureRects, captured every RU audience card, and confirmed Halloran's displayed terms match actual changes. All five screenshots were visually inspected. Review sheet and cards: `shots/factions_dark/`. The sandbox prevented user-data log/cache writes and editor-settings saving; the runtime and screenshot checks completed with exit code 0. Godot also reported resource leaks on screenshot-run shutdown. No gameplay or card layout code changed.

## 13. Faction identities grounded in lore

SUPERSEDED — rejected

The user kept the dark leaders for now but rejected the object icons and supplied a reference sheet of faction insignia, with permission to revise names and lore. Read `docs/GDD.md`, `docs/FACTIONS.md`, the map and audience faction catalogs, station communities, events, and relevant radio/story references before designing the replacements. The reference was used for visual language (political badges, distinct colour fields, symbolic identity), not as instructions or a source of copied emblems.

All five symbols in `assets/factions/` are now new built-in ImageGen outputs: Depot Union's fist and rail spike on rust, Directorate's closed gate on oxblood/black, Synod's buried sun under a vault on night blue, Exchange's split contract token on green, and Black Flag's severed chain over a brick-red diagonal. Full source PNGs and generation/refinement prompts are in `incoming-art/faction_identities/`. Alpha is transparent outside the badges, opaque inside. A Depot field transparency defect was corrected with ImageGen before installation. The audience card uses 32 px insignia; the set was also inspected at 24 and 48 px. The five leader files were verified byte-identical to section 12's sources.

`docs/FACTIONS.md` adds each faction's origin, source of legitimacy, internal conflict, emblem origin, use and motto. Depot Union / Союз Депо is the formal name; Depot remains its short form. The other names and all internal IDs remain. Map/catalog display leaders now agree with audiences (Pike, Halloran, Kato, Pell). Kato's contradictory unseen-preacher story is removed. Black Flag's radical cells and Bird's toll network are reconciled as one loose movement with an internal argument over free passage. Halloran's platform-absence claim is replaced by the ration-list conflict. EN/RU faction names, muted display colours and audience capital metadata are synchronized; PNG symbol paths now point directly to the installed files. Current GDD leader table is synchronized. No balance, faction IDs, saved-state schema or audience effects changed.

The lore explicitly labels unimplemented deal promises as design history rather than current rewards. No borrowed squad, medic, trade discount or bunker route was added by this art pass.

Checks: `BOT RUN OK`, missing banners none; installed asset hashes match the new sources; portraits unchanged; all five catalog identities/capitals/translations agree; badge alpha checks pass. All five EN and RU audience cards captured, all RU cards and the longest EN heading visually inspected; Halloran terms match actual changes in both languages. Review: `shots/faction_identities/identity_review.png`; cards in its `en/` and `ru/` subfolders. Godot returned 0 with the same sandbox user-data/cache warnings and screenshot-run shutdown resource warnings noted in section 12. `.tools` checks and screenshots are local review artifacts.


## 14. Delegated review and next handoffs

SUPERSEDED — rejected

Three parallel reviews covered gameplay/save integrity, UI/art, and lore/audio. Cursor owns implementation, this review owns art and acceptance, and Muse owns ElevenLabs production. Briefs are prepared locally; no external worker has been contacted and no new audio generated.

The working tree contains the dark leaders and coloured faction badges; commit 6270c4b and existing packaged builds predate these changes. Preserve the local work. Existing content includes 112 active EN/RU VO files; the 16 extra cable bulletins remain unvoiced.

Priority findings: an isolated in-memory probe reproduced legacy save import retaining live audience/standing/deal state, and an oldest hostile Exchange audience occupying eight consecutive dawns. See `.tools/review_save_audience_20261011.gd`. Save writes also directly truncate the destination and newest-slot loading has no fallback, confirmed by source inspection. The probe did not read or write player saves. A successful probe exit confirms the reproduction, not a passing regression test. No fresh full bot run was needed for these documentation-only edits.

Cursor handoffs, in order:

1. `docs/briefs/cursor_save_hardening.txt`: staged import, migration defaults, atomic writes and recovery.
2. `docs/briefs/cursor_audience_regressions.txt`: fair audience scheduling and durable regression coverage. Run after the save work because both touch the simulation.
3. `docs/briefs/cursor_worker_visibility.txt`: compare sprite tint in actual gameplay before requesting more poses.
4. `docs/briefs/cursor_leader_dialogue.txt`: reviewed truthful EN/RU openings, then screenshot acceptance. Run UI edits sequentially because both touch station.gd.

Muse can work independently from `docs/briefs/muse_radio_pilot.txt`: four existing scripts, eight EN/RU files, preserving the established announcer. Recover voice/model/settings from Muse history first; these are absent from the repository. Audition before installation or expanding the batch. Leader VO waits for implemented text review.

Next art candidate: the Directorate Grand Central hub (`northgate`). The hub resolver already supports station-specific assets; inspect existing incoming hub art before commissioning anything else. No new hub was generated during this audit. Rejected pose experiments remain excluded from acceptance; export filtering needs its own packaging check.

Review corrected the faction response deadline, VO credits/counts and index loudness/history. Dialogue editorial review removed Pike's premature secret disclosure and Bird's unsupported accusation against the player's guards.

## 15. Faction hub environment art

SUPERSEDED — rejected

Generated with built-in image_gen and visually reviewed: Directorate Grand Central (northgate), Synod Cathedral Parkway (chapel), Free Exchange Wall Street (trampark), and Black Flag Atlantic Avenue transfer camp (brickworks). The Black Flag camp is not a new territorial capital. Existing Coney artwork remains intact.

Runtime WebP files live in assets/hubs/<station-id>.webp. Original PNGs and exact prompts are retained in incoming-art/hubs/. Faction portraits and badges were checked against the pre-hub SHA256 baseline: zero changes.

The visit panel now preserves the full panorama proportions for these four stations instead of cropping to a 220-pixel strip. Remaining content stays accessible through the existing scroll container. No gameplay, faction ownership, audio or leader data changed.

Verification: .tools/faction_hubs_review.gd rendered all three new hubs at 1280x720, asserted texture load and display aspect ratio, and captured visit, scrolled-bottom and station-sheet views. All assertions passed, exit 0. Runtime retains user-directory/cache permission warnings and existing shutdown resource warnings. Screenshots: shots/{chapel,trampark,brickworks}_{visit,visit_bottom,sheet}.png. These are art/layout checks, not a claim of full localization coverage: existing station lore still appears in Russian within the English UI.

Art direction: Synod kitchen and infirmary beneath a blocked exit; Exchange provisions controlled through debt and secured stores; Black Flag mobile camp, assistance and tolls. No new audio or mechanical promises. Nothing committed or pushed.
