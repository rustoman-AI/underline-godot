class_name LivingStyle
extends RefCounted

## Every colour and timing for Living Rooms. V2 retheme edits this file.
## LR2 uses the lighting and frontier numbers. Walk numbers stay here for LR4.

const NIGHT := Color(0.10, 0.16, 0.34)
const DAWN := Color(1.0, 0.74, 0.42)
const WARD := Color(0.55, 0.95, 0.68)
const LANTERN := Color(1.0, 0.82, 0.5)
const LANTERN_POOL := Color(1.0, 0.78, 0.42, 0.16)

## Cut rooms. Black overlay alpha. Brightness is 1 - alpha.
const CUT_ALPHA_BASE := 0.50
const CUT_WOBBLE := 0.04
const CUT_ALPHA_MIN := 0.38
const CUT_ALPHA_MAX := 0.62
const CUT_REDUCED_ALPHA := 0.50
const BRIGHT_FLOOR := 0.35

const DIP_N_BASE := 3
const LEAD_S := 0.12
const DIP_S := 0.11
const DIP_B := 0.40
const GAP_B := 0.85
const GAP_MIN := 0.24
const GAP_SPAN := 0.12
const SETTLE_S := 0.35
const EVENT_CAP_S := 2.5
const RELIGHT_S := 0.40
const ENTRY_LIMIT_S := 4.0
const MAX_EVENTS := 6

## Night grade rides the existing veil. Dawn warm-up is 1.5 s.
const NIGHT_ALPHA := 0.14
const NIGHT_IN_S := 0.25
const VEIL_HOLD_S := 0.45
const VEIL_OUT_S := 0.25
const VEIL_S := 0.95
const DAWN_BLEND_S := 0.50
const DAWN_S := 1.50
const DAWN_ALPHA := 0.08
const PAUSE_CAP_S := 20.0

const WARD_ALPHA_LO := 0.03
const WARD_ALPHA_SPAN := 0.04
const WARD_PERIOD_S := 3.2
const WARD_FADE_S := 0.6
const WARD_REDUCED_ALPHA := 0.05

const HIDDEN_NEAR := 0.50
const HIDDEN_D2 := 0.50
const HIDDEN_FAR := 0.82
const UNDUG_ALPHA := 0.42
const LANTERN_INSET := 0.12
const LANTERN_DOWN := 0.40
const LANTERN_DOT := 2.5
const LANTERN_POOL_R := 0.30
const LANTERN_BREATH := 0.02
const LANTERN_HZ := 0.37

const RESYNC_MS := 500

## LR4. Present so one file owns the numbers. Unused by LR2.
const WALK_V := 96.0
const WALK_CAP_S := 3.2
