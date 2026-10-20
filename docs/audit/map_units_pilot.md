# Handcar pilot integration, 19 October 2026

The owner-selected six-frame pump sheet is integrated on supply and settle routes. Every other kind uses the clean owner token. The old generated figure assets and procedural handcar renderer were removed. No simulation or balance files changed.

## Import and normalization

Source: `incoming-art/map_units/pilot/handcar_pump_attempt3.png`, 2172 by 724. Run:

```powershell
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/cut_map_units.gd
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import --quit
```

The cutter finds six occupied column runs using alpha greater than 60: 30..324, 404..693, 757..1039, 1119..1412, 1490..1772, 1843..2126. A different count exits with an error before writing assets. A negative test using the single Step A reference reported one frame and failed as intended.

Alpha below 40 is discarded. Eight-connected islands smaller than 30 pixels are removed. The wheel search excludes the long drawn rail and measures the symmetry centres of the two lower circular silhouettes. Source wheelbases are 163, 160.5, 157.5, 162.5, 158.5 and 159 pixels. Each frame scales around its hub midpoint and wheel-bottom rail anchor to a 163-pixel wheelbase. The union canvas preserves changing crew poses without using those poses to set scale. Landmarks are recorded in `assets/map/units/handcar_pump/frames.json`.

## Rendering and motion

Only sheets explicitly marked accepted and non-placeholder load; currently that is `handcar_pump` only. Waiting and reduced-motion cars hold frame zero. Cruise movement advances one frame per 4.25 fit-zoom pixels, scaled with camera zoom: approximately 8 fps at the 34 px/s cruise speed, slower while easing. Wheel spokes stay as drawn.

The owner shader selects pixels with RGB channel spread at most 6 and maximum channel within 16 of #B5B5B5. It preserves luminance relative to that neutral. The shader now applies vertex modulation once, fixing the earlier multiplication that darkened all painted colours. Actual GPU renders in all five map faction colours confirm the plate changes and the sampled trouser and sack regions do not. Review image: `build/map_units_pilot_five_tints.png`.

Routes enter side bays outside station pins through short approach segments, avoiding a position jump at the start of waiting. Long routes use multiple staggered departures. Headway includes 1.6 rendered car widths, station dwell and easing time; a phase sweep checks the minimum gap on a long route. Static map layers do not redraw for car animation.

## Verification and review

- All nine `.tools/gates.ps1` gates pass; log `build/pilot_gates.txt`.
- Clarity: 216 failures before and after; `build/pilot_clarity_before.txt` and `build/pilot_clarity_after.txt`.
- Standard `-- --network` screenshot pass completed; `build/pilot_shots.txt`.
- `.tools/check_map_units_pilot.gd` renders the shader in five colours, checks the protected clothing/cargo regions, tests multiple-car headway and bay clearance, and saves full fit/max views in `shots/network_pilot_fit.png` and `shots/network_pilot_max.png`. Enlarged review crops are `build/network_pilot_fit_crop.png` and `build/network_pilot_max_crop.png`.
- `.tools/check_map_units.gd` checks accepted-only loading, six frames, monotonic distance timing, still frame zero, missing-sheet rejection and material/sprite reuse.
- Movie Maker records `build/clips/map_units_pilot.avi`; the H.264 viewing copy is `build/clips/map_units_pilot.mp4`, 300 frames at 30 fps, exactly 10 seconds. Review contact sheet: `build/map_units_pilot_movie_review.png`.

No new playtest build or push was made. The remaining unit types stay tokens until their art is accepted.

## 20 Oct: accepted idle integration

The owner accepted `incoming-art/map_units/set/handcar_idle_v3.png` and `trader_reference_v3.png` in `ACCEPTED.txt`. Clearly empty frame gaps and a neutral grey without colour cast are sufficient; exact hex and quarter-width gaps are not acceptance requirements.

The cutter imports four idle frames with source column spans 26..485, 581..1039, 1131..1590 and 1669..2130. It normalizes wheelbases to the pump sheet's 163 pixels and reuses its 303 by 262 canvas and (153, 253) rail anchor. This keeps the car aligned and the same scale across movement and waiting. Only accepted handcar sheets are supported by this import path.

Each sheet records its sampled neutral owner key in `frames.json`: pump 184/255 and idle 185/255. Materials are cached by sheet and owner colour. The shader still requires RGB channel spread at most 6, preserves relative luminance, and supports an optional normalized tint region for future canopy-only trader tinting. Trader art is not imported yet.

Waiting cars select `handcar_idle` at 4 fps. Reduced-motion views use its frame zero. If the idle sheet is missing, cars keep the accepted pump frame-zero fallback. Focused checks cover all four idle poses, matching canvas/anchors, separate sheet materials, cache reuse and missing-idle fallback. Forty moving sprites measured 0.181 ms average and 0.356 ms worst CPU submission in this pass.

The real waiting capture holds the first supply car at elapsed 0.6 seconds and route distance zero. It asserts both bay clearance and use of an idle texture. See `build/network_pilot_fit_waiting_crop.png` and `build/idle_wait_tints_review.txt`. GPU tint checks pass for both sheets in five faction colours, preserving sampled trousers and sacks. Outputs: `build/map_units_handcar_pump_five_tints.png` and `build/map_units_handcar_idle_five_tints.png`.

All nine gates passed. Clarity remains 215 before and after (`build/idle_clarity_before.txt`, `build/idle_clarity_after.txt`). The earlier pilot count above is historical.

New art candidates: `trader_roll_v1.png` and `squad_reference_v1.png`, with exact submitted prompts beside them. Every generation attached both pilot images; trader additionally used the accepted trader still, and squad used bodies 07 and 11. Neither new candidate is imported. Art generation stops at the squad reference for owner review; expedition and dust are queued.
