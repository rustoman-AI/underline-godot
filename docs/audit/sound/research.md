# Sound overhaul — Step 2: research (no credits spent)

Researched 2026-10-13 via web (official docs/terms where reachable, secondary
sources otherwise). All licence claims need the lead's final read of the binding
text before shipping; quotes below are summaries, not legal advice.

## a) ElevenLabs Sound Effects (same account as the voices)

- Endpoint: `POST https://api.elevenlabs.io/v1/sound-generation`, model
  `eleven_text_to_sound_v2`. Fields: `text` (material-first prompt), `duration_seconds`
  0.5–30, `prompt_influence` 0–1 (0.8+ for literal UI sounds), `loop` for beds,
  `output_format` as query param.
- Quality: strong on concrete materials ("good at materials, bad at abstractions" —
  prompt "paper page turn with a metal clip", not "dossier feeling"). One clear
  sound per generation.
- Control: exact duration, literalness slider, seamless-loop mode for beds.
- Licence: paid plan (our Starter counts) → commercial use allowed; you retain
  rights to the output. Caveats from the ToS: ElevenLabs keeps a broad perpetual
  licence to anything generated, and output is not guaranteed unique. Free tier
  would be non-commercial — not our case.
- Cost: API price ~$0.12 per generation. Credit figures differ by source
  (50–200 per generation; ~20 credits/sec when duration is set). Measured live in
  Step 4 and reported per sound — the numbers below are planning figures only.

## b) Free/paid libraries with clear game licences

| Source | Licence | Attribution | Game use | Notes |
|---|---|---|---|---|
| Sonniss GDC bundles | Custom EULA | none | yes, unlimited commercial | Royalty-free, modify allowed, ship inside game. NO standalone resale, NO AI training on the files. Multi-GB WAV; site blocks scripted download (manual/torrent). |
| Kenney | CC0 per asset page | none | yes | Mostly sprites/models; thin on audio. Check the licence line on each asset page. |
| Freesound | per-file; use **CC0 only** | none (for CC0) | yes (for CC0) | CC-BY needs a credit line, CC-BY-NC bans commercial games. Filter to CC0 and record the file URL. |
| Pixabay audio | Pixabay Content License | none | yes | Free commercial use, no attribution. No standalone redistribution (game = fine, sound pack = not). Scripted downloads blocked by Cloudflare Turnstile — download in a real browser. |

Nothing above needs attribution we cannot give; nothing bans games.

## c) Suno / music AI (music bed only, never UI)

- Commercial use needs a paid plan: Pro $10/mo ($8 annual, 2,500 credits, 20
  downloads/mo) or Premier $30/mo ($24 annual, 10k credits, 60 downloads/mo).
  Free plan: no commercial rights, ever (no retroactive grant on upgrade). Under
  the ToS effective 2026-09-03 the commercial right attaches to a permitted
  download on a paid plan.
- Caveats: active major-label litigation (Sony/Universal filed Sep 2026); and we
  have a standing rule against new subscriptions without the owner's word.
- Verdict: no Suno now. If the owner later wants an original bed, it is one
  "go" + a Pro subscription away. Meanwhile the bed comes from Pixabay music
  (Content License, $0) or an ElevenLabs loop (30 s ≈ 450 credits — pricey).

## Recommendation

- **Generate with ElevenLabs:** every UI one-shot — click (3 pitch variants),
  confirm, card open, new week, dossier open, dossier tab, end turn, build done,
  dig, upgrade bought, error, menu/loading tone. Reason: the style rules demand
  specific materials (paper, brass, ledger stamp, rusty metal) at exact lengths;
  generation gives literal control, and one source keeps the set coherent (the
  brief's own note: single-source sets sit together better than a mix).
- **Take from libraries ($0):** room loops, ambient beds, drips, radio static —
  long real-world textures where a recording beats synthesis. Sonniss first,
  Pixabay as backup, Freesound CC0 for gaps.
- **Music bed:** Pixabay, not Suno (no new subscription, no litigation tail).
- **Budget for Step 4:** cap = 25% of the monthly credit budget
  (0.25 × 39,724 ≈ 9,931 credits). At ~20–50 credits per short generation the
  13 samples should land in the low hundreds — far under the cap. Actual
  per-sound credits measured from the dashboard and reported.
