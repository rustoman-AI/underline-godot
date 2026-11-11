class_name FeelStyle
extends Object

## Presentation constants for the feel layer. V2 retints this file only.
## Colours match the station HUD: gain DELTA_UP, loss DELTA_DOWN, SUCCESS amber, FAILED rust.

const DELTA_UP := Color("b6e38a")
const DELTA_DOWN := Color("ff9b8a")
const BRASS := Color("c9a050")
const AMBER := Color("e8b04a")
const RUST := Color("c4544a")
const INK := Color("efe6d2")
const INK_DARK := Color("24180e")
const PAPER := Color("241c14")

const ROLL_SEC := 0.4
const POP_SEC := 0.18
const POP_SCALE := 1.25
const FLASH_SEC := 0.25
const CHIP_RISE := 18.0
const CHIP_SEC := 0.6
const CHIP_FADE := 0.25
const CHIP_MERGE_SEC := 0.25
const CHIP_FONT := 16
const CHIP_OUTLINE := 4
const CHIP_POOL := 12
const CHIP_JITTER := 4.0

const Z_VIGNETTE := 59
const Z_LAYER := 60
const Z_CHIPS := 60
const Z_DAWN := 61
const Z_CHECK := 62

## Full check reveal: banner, 0.7 s beat, stamp, hold, fade. About 2.13 s, under the 2.6 s cap.
const CHECK_BANNER_SEC := 0.20
const CHECK_BEAT_SEC := 0.70
const CHECK_STAMP_SEC := 0.18
const CHECK_HOLD_SEC := 0.90
const CHECK_FADE_SEC := 0.15
const CHECK_CAP_SEC := 2.6
const CHECK_PUNCH := 1.6
const CHECK_PUNCH_BOX := 1.8
## White / likely: banner then stamp, no beat. The four steps sum to 0.60 s.
const CHECK_SHORT_BANNER_SEC := 0.18
const CHECK_SHORT_STAMP_SEC := 0.16
const CHECK_SHORT_HOLD_SEC := 0.14
const CHECK_SHORT_FADE_SEC := 0.12
const CHECK_REDUCED_SEC := 1.5
const CHECK_TOP := 0.30
const CHECK_STAMP_FONT := 64
