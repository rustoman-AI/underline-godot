# Map unit implementation, 19 October 2026

The implementation is ready for the v2 drawing delivery. The checked-in frames are development placeholders, not painted production art. Each sheet's `frames.json` records `placeholder: true`. No balance, simulation, saved-game schema or player-facing strings were changed.

## Import

Place `handcar_pump.png` (8 cells), `handcar_idle.png` (4), `trader_car.png` (8), `squad_walk.png` (8), `squad_stand.png` (4), `expedition_walk.png` (8), and `puff.png` (6) in `incoming-art/map_units/`. Supply a matching `HANDOFF.txt`. Cells must be 384 by 384 with transparent backgrounds, facing right, with the rail or sole anchor at (192, 336). Owner cloth is #C8C8C8.

Run:

```powershell
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/cut_map_units.gd
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import --quit
```

Only the cutter writes imported frames into `assets/map/units/`. It validates grid capacity, reports counts and edge-touching content, and preserves one shared crop and sole anchor per sheet. The explicit `-- --placeholders` option regenerates development source sheets and frames; do not use it over accepted painted art.

## Rendering

Frames, cargo icons and owner materials are cached at map initialization. Sprite nodes are reused. A generated soft shadow texture sits under each unit; attached paper tags draw over the cart. Missing or incomplete sheets retain procedural drawing. Units are 44 px tall at fit zoom, capped at 76 px, with a disc below 30 px. Normal map zoom currently starts at fit, so the disc branch supports future smaller zooms rather than changing camera limits.

Travel uses integrated acceleration and braking per real tunnel, with 0.4 s departure and 0.5 s arrival eases. Distance drives frame cycles at 1.1 rendered sprite widths. Idle runs at 4 fps. Facing passes through a 0.15 s turn, and slope is smoothed within 10 degrees for carts and 4 degrees for people. Supply routes use one representative cart, fade at terminals and unload their tag; trade routes return with tokens. One representative per route avoids queues bunching during dwell. Trade terminals pause 1.2 s before departing. Owner lanes have a canonical orientation so reversed route directions retain their side of a tunnel.

Squad and expedition sprites use the unit layer. Static route dots stay on the ink layer. Intent pulses and capture splashes also use the unit layer, avoiding full map redraws for their animation. Reduced motion preserves fixed route positions and frame zero.

## Verification

- All nine `.tools/gates.ps1` gates passed. The save and playtest logging gates require access to their Godot user-data test folders; sandbox-only execution initially failed those filesystem checks.
- `sim/check_clarity.gd`: 216 failures before, 216 after. The brief's 215 baseline did not match this checkout. Logs: `build/clarity_before_map_units.txt`, `build/clarity_after_map_units.txt`.
- Screenshot pass completed with `-- --network`. Inspected `shots/network_caravans.png`, `shots/network_handcar.png`, `shots/network_squad_walk.png` and enlarged crops in `build/`.
- `.tools/check_map_units.gd` checks monotonic motion, endpoints, seven imported sheets, fixed frame zero, missing-sheet fallback, pooled sprite count and per-colour material reuse. Forty sprite updates averaged 0.229 ms, worst 0.418 ms in the measured run. This is CPU sprite submission on the development desktop, not a mid-range laptop or complete map-frame benchmark.
- `.tools/map_units_clip.gd` prepares week 20 with motion on. `build/clips/map_units.avi` is 300 frames at 30 fps, 10 seconds. `build/clips/map_units.mp4` is a convenient viewing copy. A three-frame movie contact sheet is in `build/map_units_movie_review.png`.

Final production-art acceptance is pending the seven painted sheets. Replace them through the cutter, repeat screenshots and movie inspection, and check anchors, tint selection and silhouettes against the delivery. Placeholder visuals cannot establish painted-art quality.
