# Music — Step 1: research (no credits spent)

Researched 2026-10-14. API probed read-only (empty-body POST → 422, no billing).
Pricing and legal terms read from elevenlabs.io on 2026-10-14 ~07:52–08:06 EDT
via live browser; quotes below are verbatim from those pages.

## API: ElevenLabs Music on our plan

- Endpoint `POST /v1/music?output_format=...` — LIVE, our key accepted.
- Params: `prompt` or `composition_plan` (one required); `music_length_ms`
  3,000–600,000 (3 s–10 min); `force_instrumental: true` guarantees no vocals
  (prompt mode); `model_id` music_v1/music_v2; output mp3_44100_128 default
  (mp3_48000_192/240/320, pcm options on higher tiers).
- `/v1/models` does NOT list music models (TTS/STS only) — music lives only
  behind `/v1/music`.
- Loops/seamless ends: NO dedicated loop parameter found in the API reference.
  Loop-friendliness is prompt luck; the brief's fallback (5 s tail for a manual
  crossfade) would apply.

## Price (elevenlabs.io/pricing, read 2026-10-14)

- "Eleven Music 900 credits per minute." (official FAQ line)
- Plan music allowance: Starter 33 min/month (Music Terms Exhibit A says 17 —
  discrepancy between the two pages, reported as-is).
- Overage: $0.18/min on Starter.

## Licence (commercial game on Steam/itch.io)

- Terms of Service (non-EEA), **last updated 09 October 2026**, read 2026-10-14:
  - §4(c)(ii): "Except as expressly set forth herein, as between you and
    ElevenLabs, you retain all rights in and to your Output."
  - §1(c)(ii): a Paid User "may use the Services for commercial purposes"
    (Free users non-commercial only).
  - §4(d): you grant ElevenLabs a "perpetual and irrevocable", "nonexclusive",
    "royalty-free and fully paid", "worldwide", "sub-licensable, through
    multiple tiers" licence over your Content (incl. training); §4(i) lets you
    opt out of training use via the account 'Data use' menu.
- Music Terms, **last updated 09 October 2026**, read 2026-10-14:
  - Exhibit A – Media Rights (paid non-enterprise tiers incl. Starter): "All
    online and offline commercial use permitted, except film, TV, radio, and
    Studio Games".
  - "Indie Game" (§4.8): game revenue < $500,000 since first commercial release
    AND entity's game revenue < $1,000,000 in its most recently completed
    financial year. Underline (unreleased, $0) qualifies → allowed on Starter.
    If it ever stops qualifying, §4.7 gives 60 days to move plans.
  - Attribution: "No Attribution Required" on all paid tiers.
  - Trailers/monetized video: covered by "all online and offline commercial
    use". (Spotify/Apple distribution is NOT on Starter — irrelevant for
    in-game use.)
- Training data: UMG licensing deal announced Sep 2026; docs FAQ:
  "Eleven Music is cleared for nearly all commercial uses, from film and
  television to podcasts and social media videos, and from advertisements
  to gaming."

## VERDICT: НЕЛЬЗЯ (does not fit) — on budget, not on licence or API

Sample round as specified (4× 60–90 s + 1× 30–40 s) at 900 cr/min:
- cheapest possible: 4×60 s + 35 s = 275 s ≈ **4,125 credits**
- spec max: 4×90 s + 40 s = 400 s ≈ **6,000 credits**
- authorised cap: 10% of sound-overhaul spend (3,231) ≈ **323 credits**
- even ONE 60 s track (900 cr) or the short M5 alone (~525 cr) exceeds the cap.

The API works, the licence is clean for our indie game, instrumental can be
forced — but the sample round costs ~13× the authorised budget. Step 3 as
written cannot run.

## Second-best option (per brief): library tracks, $0

Pixabay Music — Pixabay Content License: free commercial use, no attribution,
no standalone redistribution (inside a game = fine). Five dark-ambient
picks curated 2026-10-14 (each track page opened and verified, read-only):

1. M1 menu_theme — "Piano Felt" by leberch, 3:00 (sparse felt-piano solo)
   https://pixabay.com/music/small-drama-piano-felt-609499/
2. M2 station_calm — "Dark Ambient Soundscape Dreamscape" by SolarFLEX, 4:17
   https://pixabay.com/music/ambient-dark-ambient-soundscape-dreamscape-569591/
3. M3 station_tension — "Grief (Dark)" by leberch, 4:44
   https://pixabay.com/music/ambient-grief-dark-609127/
4. M4 station_crisis — "Dark Ambient" by MondaMusic, 4:48 (deep low drone)
   https://pixabay.com/music/ambient-dark-ambient-589187/
5. M5 ending_quiet — "Rolfied (Ambient Piano)" by leberch, 2:30
   https://pixabay.com/music/ambient-rolfied-ambient-piano-615225/

Caveat: Pixabay marks several "Content ID Registered" — their fingerprinting
badge, not an attribution requirement; but gameplay videos on YouTube could
in principle attract a Content ID claim on the music. Worth one check with
the lead before committing.
The lead downloads them in a real browser (scripted downloads are
Cloudflare-blocked) and normalises to -20 LUFS / peak < -1 dBTP, ogg, into
assets/audio/music_new/.
Suno deliberately not proposed: needs a paid subscription (standing rule:
no new subscriptions without the owner's word).
