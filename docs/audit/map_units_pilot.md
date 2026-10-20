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
