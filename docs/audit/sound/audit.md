# Sound overhaul — Step 1: audit (no credits spent)

Built 2026-10-13 from the brief's file/event inventory plus owner feedback F35.
The game repo (ui/station.gd, sim/audio code, assets/audio/*.ogg) is NOT on this
machine, so: file lengths, exact trigger mapping and waveform character are marked
UNVERIFIED and need one pass inside the repo (or the audio folder + the two .gd files
uploaded here). "Sounds like / what's wrong" below is the owner's F35 verdict
("almost all sounds feel weird and annoying, like Game Boy") applied per file by
name/function — not a listening review (I cannot audition audio).

| # | Game event (trigger) | Current file (assets/audio/) | Length | What it sounds like (per F35) | What is wrong |
|---|---|---|---|---|---|
| 1 | UI click (buttons, tabs) | click.ogg | UNVERIFIED | thin synth tick, "Game Boy" | no material body; single sample repeated -> fatigue |
| 2 | Button confirm | confirm.ogg | UNVERIFIED | bright blip | chip-tone, too bright for a tired post-apocalypse UI |
| 3 | End turn | thud.ogg (?) | UNVERIFIED | weak / wrong (flagged in F35) | needs calm, low, heavy close — ledger/lever/deep thud with short room tail; currently not that |
| 4 | New week card appears | card.ogg | UNVERIFIED | synthy swipe | "card" should be paper on wood, not a digital whoosh |
| 5 | Event card open | card.ogg (shared?) | UNVERIFIED | same as above | if shared with new-week, the two moments are indistinguishable |
| 6 | Dossier open | whoosh.ogg (?) | UNVERIFIED | digital whoosh (flagged in F35) | dossier = paper + clip + page turn + small stamp, quiet; a whoosh is the opposite |
| 7 | Dossier tab switch | click.ogg (shared?) | UNVERIFIED | same thin tick as every button | tab switch wants a softer paper tick, distinct from UI click |
| 8 | Audience open | whoosh.ogg (?) | UNVERIFIED | digital whoosh | a heavy door / room tone shift, not a swoosh |
| 9 | Build finished | built.ogg | UNVERIFIED | synthy "done" cue | should be wood/tools, soft; no reward arpeggio |
| 10 | Dig action | thud.ogg (?) | UNVERIFIED | generic thud | should be shovel in dirt/rubble, specific material |
| 11 | Upgrade bought | confirm.ogg (shared?) | UNVERIFIED | bright blip | purchase = stamp on ledger, quiet; never a cheerful chime |
| 12 | Error / invalid action | error.ogg | UNVERIFIED | harsh buzz (?) | should be low, muted, non-punishing |
| 13 | Map click | click.ogg (shared?) | UNVERIFIED | same tick | map wants a duller, lower variant |
| 14 | Menu / loading screen | drone.ogg / ambient.ogg | UNVERIFIED | grating loop (flagged in F35) | low room tone + distant ticks; must survive 30 s without grating |
| 15 | Hover | hover.ogg (muted) | — | muted already | keep muted; no sample needed |
| 16 | Room loops | rooms/*.ogg | UNVERIFIED | unknown | keep or replace per room; not in sample scope |
| 17 | Ambient bed | ambient.ogg | UNVERIFIED | unknown | candidate for library texture, not synthesis |
| 18 | Water drips | drip.ogg | UNVERIFIED | unknown | real recording beats synthesis; library candidate |
| 19 | Radio static bed | radio.ogg | UNVERIFIED | unknown | real static texture; library or filtered noise |

Open questions for the repo pass (lead/Cursor): which file each trigger actually
plays (the (?) rows), exact durations, whether card/confirm/click files are shared
across events, and the hover-mute flag location in settings.gd.

## Decision: where the work is done

The game repo is not on this machine and voices (assets/audio/vo) must not be
touched. So all work happens here in ~/workspace/underline/sound_overhaul/:
audit + research docs, samples generated and normalized locally, delivered as a
zip whose top-level `new/` folder drops straight into the game's assets/audio/
(the lead copies it in; nothing in assets/audio is replaced). Integration
(switching the game to the new files) stays the lead's lane via Cursor, as the
brief itself prescribes. If the lead later uploads assets/audio/ + ui/station.gd
+ sim audio code, the UNVERIFIED columns get filled in one pass.
