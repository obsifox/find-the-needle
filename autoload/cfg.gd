extends Node


## Touch-first devices (phones / tablets). Drives the native-ground terrain
## fallback, forced staged loading, the touch control layer, and the mobile
## options panel. A var (not const) so dev probes can override it.
var is_mobile:= OS.get_name() in ["Android", "iOS"]


const STRAND_LENGTH:= 0.18
const STRAND_LEN_MIN:= 0.1
const STRAND_LEN_MAX:= 0.26


const STRAND_LEN_BUCKETS:= 5
const STRAND_THICK:= 0.008
const STRAND_VOLUME:= STRAND_LENGTH * STRAND_THICK * STRAND_THICK


var PILE_RADIUS:= 10.0
var PILE_HEIGHT:= 7.0
const PILE_CENTER:= Vector3(0, 0, 0)


var PILE_PREP_ANGLE_DEG:= 55.0


const CELL:= 0.25


var FIELD_EXTENT:= 15.0
const CHUNK_CELLS:= 10


const PILE_SIZES: Array [Dictionary] = [
        {
                "id": "small",
                "name": "SMALL",
                "blurb": "Designed for weaker computers. A shorter hunt with room to walk around the pile.",
                "radius": 7.0, "height": 5.0, "extent": 15.0, "prep_deg": 55.0,
                "toe": 7.9,
                "listed": true,
        },
        {
                "id": "standard",
                "name": "STANDARD",
                "blurb": "The yard as it comes. The pile the game was built around, under one steel roof.",
                "radius": 10.0, "height": 7.0, "extent": 15.0, "prep_deg": 55.0,
                "toe": 11.2,
        },
        {
                "id": "big",
                "name": "BIG",
                "blurb": "Twice the hay and a crown that stands over the wall plates. Bring a belt.",
                "radius": 12.0, "height": 12.0, "extent": 18.0, "prep_deg": 58.0,
                "toe": 14.1,
                "heavy": true,
        },
        {
                "id": "huge",
                "name": "HUGE",
                "blurb": "Eight storeys of straw. The shed goes out to meet it and the roof still loses. Slow to load.",
                "radius": 15.0, "height": 24.0, "extent": 23.0, "prep_deg": 64.0,
                "toe": 18.4,
                "heavy": true,
        },
        {
                "id": "mountain",
                "name": "THE MOUNTAIN",
                "blurb": "Fifty metres. It does not fit under the roof, it is not supposed to, and you will not finish it. Takes a minute to pour.",
                "radius": 18.0, "height": 50.0, "extent": 30.0, "prep_deg": 72.0,
                "toe": 23.1,
                "heavy": true,


                "start_tech": { "yard_space": 1 },
        },
]


const DEFAULT_PILE_SIZE:= "standard"

var pile_size_id:= DEFAULT_PILE_SIZE


const SHED_LONG_BAYS:= 2


var shed_long_bays:= SHED_LONG_BAYS


const PACKING:= 0.1
const STRANDS_PER_M3:= PACKING / STRAND_VOLUME


const CRUST_DEPTH:= 0.35


const HAY_SHELLS:= 24
const HAY_SHELL_DEPTH:= 1.15


const HAY_SHELL_GRADE:= 1.0


const HAY_SHELL_REACH:= 1.4


const HAY_SHELL_SMOOTH:= 12.0


const HAY_SHELL_CURVE_K:= 0.0


const HAY_SHELL_DIG_DEADBAND:= 0.3


const HAY_SHELL_DIG_K:= 1.4


const HAY_SHELL_DIG_FLOOR:= 0.03


const HAY_SHELL_DIG_CRUST:= 1.7


const HAY_SHELL_STEEP_LO:= 1.4


const HAY_SHELL_STEEP_HI:= 2.5


const HAY_SHELL_STEEP_FLOOR:= 0.06

const CHUNK_REBUILDS_PER_FRAME:= 3
const CELL_UPDATES_PER_FRAME:= 420


const CELL_UPDATE_BUDGET_USEC:= 2200
const CHUNK_REBUILD_BUDGET_USEC:= 1400


const STRAND_MASS:= 0.0022
const STRAND_LINEAR_DAMP:= 0.45
const STRAND_ANGULAR_DAMP:= 0.9
const STRAND_FRICTION:= 0.92
const STRAND_BOUNCE:= 0.0
const STRAND_DESPAWN_DIST:= 26.0
const STRAND_KEEP_DIST:= 9.0


const LIVE_SOFT_CAP:= 500
const STRAND_RECLAIM_REST:= 1.2


const STRAND_SLEEP_AFTER:= 0.2
const STRAND_REST_SPEED:= 0.14
const STRAND_REST_SPIN:= 1.2


const TUFT_MERGE_AT:= 10


const TUFT_MAX:= 100


const TUFT_RADIUS:= 0.25

const TUFT_ABSORB_REACH:= 0.15


const TUFT_STEP:= 0.07

const TUFT_GATHER_SECONDS:= 0.25

const TUFT_SUPPORT_CHECKS:= 3


const TUFT_STRETCH:= Vector2(0.8, 1.3)


const TUFT_COLLIDER_SHRINK:= 0.8


const TUFT_MASS_MIN:= 0.6


const TUFT_FLOOR_CAP:= 10


const BELT_TUFT_SPAN:= 0.25


const ANGLE_OF_REPOSE:= 0.7156
const RELAX_ITERATIONS_PER_FRAME:= 2
const RELAX_RATE:= 0.35
const RELAX_SPAWN_CHANCE:= 0.05


const RELAX_VERTICES_PER_FRAME:= 300

const RELAX_UPDATE_BUDGET_USEC:= 1200


var crust_budget_scale:= 1.0
var cell_update_budget_usec: int = CELL_UPDATE_BUDGET_USEC
var chunk_rebuild_budget_usec: int = CHUNK_REBUILD_BUDGET_USEC
var relax_update_budget_usec: int = RELAX_UPDATE_BUDGET_USEC


const AVALANCHE_PARTICLE_CAP:= 192
const AVALANCHE_PARTICLES_PER_SECOND:= 160.0
const AVALANCHE_PARTICLE_BURST:= 24
const AVALANCHE_PARTICLE_LIFETIME:= 0.75


const SHOVEL_DEPTH_RESISTANCE:= 5.5


const SCOOP_RADIUS:= 0.135
const SCOOP_TARGET:= 50


const SCOOP_MAX:= 54
const SCOOP_REACH:= 3.0


const HAND_CARRY_BASE:= 1


const HAND_HOLD_RANKS: Array [int] = [2, 4, 6, 10, 15]
const HAND_GRAB_RANKS: Array [int] = [1, 2, 2, 3, 5]


const SHOVEL_MAX_SPAWN_PER_DIG:= 200
const SHOVEL_CARVE_RATE:= 5.5
const SHOVEL_FORCE:= 90.0
const SHOVEL_TORQUE:= 26.0


const HAY_PRICE:= 0.0222


const STAND_SNAP_RADIUS:= 1.3


const NEEDLE_DEEP_COLUMN:= 0.35
const NEEDLE_DEEP_RADIUS:= 0.55


const NEEDLE_SHALLOW_DEPTH:= 0.9


const ORDER_HAY_FRACTION:= 0.1


const PILE_CLEAR_STRANDS:= 500.0


const CONSIGNMENT_FEE_SHARES: Array [float] = [0.3, 0.8, 1.8]


const CONSIGNMENT_CREDIT_MARKUP:= 1.2


const CONSIGNMENT_PAYBACK_SHARE:= 0.5


const LANDING_WALL_NEEDLES:= 5


const TECH_LATE_RANK_SCALE:= 1.35


const NEEDLE_SCRAP_PRICE:= 1.0


const SELL_BATCH_WINDOW:= 0.35


const SELL_BATCH_MAX:= 1.6


const SELL_ANIM_SPEED:= 1.6


const MONEY_CENTS_BELOW:= 500.0


const L_WORLD:= 1
const L_PILE:= 2
const L_STRAND:= 4
const L_TOOL:= 8
const L_PLAYER:= 16
const L_BUILD:= 32
const L_PROP:= 64


const L_PEN:= 128


const L_SETTLED:= 256


const L_COIN:= 512


const L_BELT_CATCH:= 1024


const L_KEEPOUT:= 2048


var DEBUG:= (OS.has_feature("debug")
        and not ("--shipped" in OS.get_cmdline_user_args())
        and not ("--cheat" in OS.get_cmdline_user_args()))


var debug_unlocked:= false


func debug_on() -> bool:
        return DEBUG or debug_unlocked


var DEMO:= not (OS.has_feature("full")
        or (OS.has_feature("editor") and "--full" in OS.get_cmdline_user_args()))


const BUILD_TAG:= "V33"


## MOBILE FIX (v2.3.0): the app version rides in the crash report's build
## line. Both previous reports just said "V33 demo", so there was no way to
## tell WHICH apk had crashed -- bump APP_VERSION/APP_CODE together with
## export_presets.cfg version/name and version/code on every release.
const APP_VERSION:= "2.3.0"
const APP_CODE:= 6


func build_string() -> String:
        return "%s %s v%s build %d" % [BUILD_TAG, "demo" if DEMO else "full",
                APP_VERSION, APP_CODE]


const DEMO_LAST_LOT:= 0


var demo_lot_gate:= DEMO


const CROUCH_HEIGHT:= 1.15
const CROUCH_EYE_HEIGHT:= 1.02
const CROUCH_SPEED:= 1.9


const CROUCH_BLEND:= 13.0


const CROUCH_HEADROOM:= 0.05


const CROUCH_STEP_SCALE:= 1.5
const CROUCH_STEP_GAIN:= -7.0


const JOSTLE_AMPLITUDE:= 0.12


const JOSTLE_PUSHED_SCALE:= 0.2


const JOSTLE_WALK_FLOOR:= 1.2
const JOSTLE_SPEED_REF:= 7.0


const JOSTLE_CURVE:= 2.0


const JOSTLE_ROLL_RATIO:= 0.55


const JOSTLE_LAND_KICK:= 0.14
const JOSTLE_LAND_DECAY:= 4.5


const JOSTLE_CROUCH_FACTOR:= 0.06


const CARRY_REACH:= 2.8
const CARRY_FORWARD:= 0.72
const CARRY_DOWN:= 0.36


const CARRY_RIGHT:= 0.14


const CARRY_PITCH_LIMIT:= 0.55
const CARRY_THROW_SPEED:= 5.4
const CARRY_DROP_SPEED:= 0.6


const CARRY_TILT_SENS:= 0.006


const CARRY_TILT_LIMIT:= 1.4


const CARRY_TILT_RETURN:= 9.0


const CARRY_STACK_BASE:= 1


const CARRY_STACK_GAP:= 0.012


const CARRY_STACK_SINK:= 0.5


const CARRY_STACK_SINK_MAX:= 0.55


const CARRY_STACK_LEAN:= 0.2


const CARRY_STACK_SIDE:= 0.32
const CARRY_STACK_SIDE_MAX:= 0.62


const CARRY_STACK_FORWARD:= 0.16
const CARRY_STACK_FORWARD_MAX:= 0.34


const CONTAINER_INTAKE_UP:= 0.72
const BUCKET_CAPACITY:= 600


const BUCKET_POUR_RATE:= 190.0


const BUCKET_TIP_START:= 0.62
const BUCKET_TIP_FULL:= 0.17


const BUCKET_FILL_INSTANCES:= 340

const BARROW_CAPACITY:= 2100


const BARROW_POUR_RATE:= 360.0


const BARROW_TIP_START:= 0.86
const BARROW_TIP_FULL:= 0.42


const BARROW_TILT_LIMIT:= 1.14


const BARROW_FILL_INSTANCES:= 820


const PUSH_DISTANCE:= 0.55


const PUSH_MIN_DISTANCE:= 0.05


const PUSH_PILE_STEP:= 0.3


const PUSH_GROUND_FOLLOW:= 14.0


const PRICE_BUCKET:= 10.0


const PRICE_SAND_SHOVEL:= 0.25


const PRICE_SPADE:= 12.0
const PRICE_PITCHFORK:= 28.0
const PRICE_BROOM:= 9.0


const PRICE_METAL_DETECTOR:= 260.0


const PRICE_WHEELBARROW:= 40.0


const PRICE_YARD_VAC:= 500.0


const PRICE_LIGHTER:= 600.0


const VAC_CAPACITY:= 1500


const VAC_SUCK_RATE:= 100.0


const VAC_POUR_RATE:= 300.0


const VAC_UNLOAD_RATE:= 1200.0


const VAC_UNLOAD_SHOWN:= 90.0


const VAC_UNLOAD_REACH:= 3.0


const VAC_POUR_REACH:= 3.5


const VAC_REACH:= 0.85


const VAC_BITE_RADIUS:= 0.22


const VAC_PULL_RADIUS:= 1.35


const VAC_PULL_SPEED:= 7.0

const VAC_SWALLOW_RADIUS:= 0.3


const VAC_BITE_EVERY:= 0.2


const VAC_STREAM_MAX:= 24


const LIGHTER_LICENCE_COST:= 1000.0


const LIGHTER_REACH:= 2.5


const LIGHTER_COOLDOWN:= 60.0


const LIGHTER_BURN_RATE:= 125.0
const LIGHTER_BURN_STRANDS:= 4000


const LIGHTER_RADIUS_START:= 0.4
const LIGHTER_RADIUS_END:= 1.5


const LIGHTER_TICK:= 0.1


const LIGHTER_CATCH_RADIUS:= 0.45


const LIGHTER_STARVE_SECONDS:= 1.5

const LIGHTER_SCORCH_SECONDS:= 45.0


const LIGHTER_FLAME_SECONDS:= 1.6


const GRIPPY_BOOTS_CARD_COST:= 1200.0


const JETPACK_CARD_COST:= 3000.0


const JETPACK_TANK_SECONDS:= 10.0


const JETPACK_RECHARGE_DELAY:= 1.0
const JETPACK_RECHARGE_SECONDS:= 8.0


const JETPACK_THRUST:= 26.0


const JETPACK_CLIMB_MAX:= 4.0


const JETPACK_AIR_ACCEL:= 6.0

const JETPACK_LOW:= 0.25


const DETECT_RANGE:= 7.0


const DETECT_HAY_COST:= 4.0


const DETECT_BLOCK_MUFFLE:= 0.55


const DETECT_FLOOR:= 0.06


const DETECT_TICK_SLOW:= 0.85
const DETECT_TICK_FAST:= 0.055


const DETECT_TICK_IDLE:= 1.7


const BUILD_REACH:= 6.0
const BUILD_REACH_MIN:= 1.5


const BUILD_REACH_MAX:= 12.0
const BUILD_REACH_STEP:= 0.55


const BUILD_SURFACE_MASK:= L_WORLD | L_PILE | L_BUILD


const BUILD_GRID_STEP:= 1.0


const BUILD_GRID_RADIUS:= 16.0


const BUILD_GRID_LIFT:= 0.02


const BUILD_GRID_PROBE:= 1.5


const BUILD_CLEARANCE_SHRINK:= 0.82
const BUILD_END_SLACK:= 0.35


const BUILD_FOOT_CLEAR:= 0.06


const BUILD_PILE_STEP:= 0.5
const BUILD_PILE_BED:= 0.25


const THIN_HAY:= 0.25


const BELT_WIDTH:= 0.9
const BELT_DECK_THICK:= 0.07
const BELT_RAIL_H:= 0.13
const BELT_RAIL_T:= 0.045
const BELT_SEGMENT:= 1.0


const BELT_COST_PER_M:= 8.0


const ENCLOSED_BELT_COST_PER_M:= 12.0
const BELT_MIN_LENGTH:= 0.8


const ENCLOSED_BELT_MIN_LENGTH:= 1.35
const BELT_MAX_LENGTH:= 24.0


const BELT_MAX_SLOPE:= 0.6109


const BELT_SPEED:= 0.7


const BELT_GRIP:= 9.0


const BELT_RIDE_CATCH_H:= 0.06


const BELT_RIDE_HALF_W:= (BELT_WIDTH - BELT_RAIL_T * 2.0) * 0.5 - STRAND_LEN_MAX * 0.5


const BELT_RIDE_SPACING:= 0.14


const BELT_RIDE_PICKUP:= 6.0


const BELT_DRIVE_H:= 0.24


const BELT_FRAME_DEPTH:= 0.31


const BELT_SUPPORT_ATTACH_DEPTH:= 0.16


const BELT_STAND_CLEAR:= 0.12
const BELT_SUPPORT_SPACING:= 3.2
const BELT_SUPPORT_MAX_DROP:= 12.0


const BELT_SUPPORT_HALF_WIDTH:= 0.34


const BELT_SNAP_RADIUS:= 1.1


const BELT_JOIN_SLACK:= BELT_WIDTH * 0.5 + 0.06


const BELT_STACK_CLEAR:= BELT_WIDTH * 0.9


const BELT_STACK_STEP:= 0.5


const BELT_STACK_HEIGHT:= BELT_FRAME_DEPTH + 0.06


const BELT_JOINT_REACH:= BELT_WIDTH * 0.5 + 0.06


const BELT_JOINT_MIN_SIDE:= 0.17


const BELT_GUIDE_STEP:= PI * 0.25
const BELT_GUIDE_WINDOW:= 0.0


const BELT_CORNER_RADIUS:= 0.85


const BELT_CORNER_MAX_TANGENT:= 2.4


const BELT_CORNER_MIN_STRAIGHT:= 0.15


const BELT_CORNER_STEP:= 0.28


const BELT_CORNER_DRAW_STEP:= 0.045
const BELT_CORNER_DRAW_SPAN:= 0.12


const BELT_CORNER_MIN_TURN:= 0.06


const BELT_JOINT_OVERLAP:= 0.09


const BELT_PORT_STUB:= 0.85


const SPLITTER_PORT_R:= 1.05


const SPLITTER_SPLAY:= 0.7853982


const SPLITTER_GATE_SWING:= 0.530248


const SPLITTER_GATE_PIVOT:= 0.5728
const SPLITTER_GATE_SPEED:= 6.0


const SPLITTER_COST:= 120.0


const SPLITTER_SNAP_RADIUS:= 1.3


const SPLITTER_HALF_WIDTH:= 1.1


const SPLITTER_ARM_CLEAR:= 0.35


const SPLITTER_CONSOLE_REACH:= 3.2


const T_SPLITTER_PORT_R:= 1.5


const T_SPLITTER_PORT_R_V2:= 2.0


const T_SPLITTER_PORT_R_V1:= 1.5


const T_SPLITTER_PORT_R_1M:= 1.0

const T_SPLITTER_SIZES: Array [float] = [T_SPLITTER_PORT_R_1M, T_SPLITTER_PORT_R]


const T_SPLITTER_PIVOT_Z:= 0.39


const T_SPLITTER_SWING:= 0.4711661


const T_SPLITTER_PARK:= 1.53


const T_SPLITTER_ARM_SPEED:= 3.5
const T_SPLITTER_ARM_ACCEL:= 14.0

const T_SPLITTER_COST:= SPLITTER_COST


const COMPACT_SPLITTER_COST:= 450.0
const SMART_SPLITTER_COST:= 1200.0


const JOINER_PORT_R:= SPLITTER_PORT_R
const JOINER_SPLAY:= SPLITTER_SPLAY
const JOINER_SNAP_RADIUS:= SPLITTER_SNAP_RADIUS
const JOINER_HALF_WIDTH:= SPLITTER_HALF_WIDTH


const JOINER_COST:= 120.0


const WYE_MATE_SLACK:= 0.01


const JOINER_ARM_DEAD_ZONE:= 0.3


const COL_BELT_RUBBER:= Color(0.41, 0.401, 0.39)
const COL_BELT_STEEL:= Color(1.74, 1.764, 1.62)
const COL_BELT_ROLLER:= Color(1.07, 1.039, 0.998)


const COL_SPLITTER_SCREEN:= Color(0.021, 0.026, 0.03)


const COL_SPLITTER_LIT:= Color(1.0, 0.64, 0.16)
const COL_GHOST_OK:= Color(0.28, 1.0, 0.42)
const COL_GHOST_BAD:= Color(1.0, 0.24, 0.2)


const COL_GHOST_WARN:= Color(1.0, 0.72, 0.18)


const COL_GHOST_NEUTRAL:= Color(0.86, 0.88, 0.92)


const ROBOT_ARM_DEFAULT_TIER:= 0


const ROBOT_ARM_WORK_SECONDS:= 4.21
const ROBOT_ARM_IDLE_SECONDS:= 0.35


const ROBOT_ARM_CONSOLE_REACH:= 3.2


const ROBOT_ARM_TIERS:= [
        {
                "id": "arm_small", "name": "SMALL ARM", "scale": 0.78,
                "reach": 2.69, "capacity": 60, "cost": 180.0, "cycle_scale": 1.15,
                "draw_kw": 1.5,
        },
        {
                "id": "arm_standard", "name": "STANDARD ARM", "scale": 1.0,
                "reach": 3.45, "capacity": 90, "cost": 350.0, "cycle_scale": 1.0,
                "draw_kw": 2.5,
        },
        {
                "id": "arm_long", "name": "LONG-REACH ARM", "scale": 1.25,
                "reach": 4.31, "capacity": 120, "cost": 600.0, "cycle_scale": 0.88,
                "draw_kw": 4.0,
        },
]


const ARM_COST_FREE:= 1


const ARM_COST_GROWTH:= 1.1


const ARM_LIMIT:= 48


const ARM_PAD_WADS:= 6


const SCANNER_LENGTH:= 2.0 * BELT_SEGMENT


const SCANNER_DEFAULT_TIER:= 0


const CABINET_COST:= 20.0


const CABINET_SIZE:= Vector3(1.33, 1.964, 0.34)


const CABINET_DOOR_CLEAR:= 0.62


const RADAR_TIERS:= [
        { "id": "radar_mk1", "plans": 400.0, "exact": false, "depth": false, "seconds": 15.0 },
        { "id": "radar_mk2", "plans": 900.0, "exact": true, "depth": false, "seconds": 15.0 },
        { "id": "radar_mk3", "plans": 1800.0, "exact": true, "depth": false, "seconds": 30.0 },
        { "id": "radar_mk4", "plans": 3500.0, "exact": true, "depth": true, "seconds": 30.0 },
]

const RADAR_COST:= 1200.0

const RADAR_RANGE:= 45.0


const RADAR_COOLDOWN:= 120.0


const RADAR_AREA_RADIUS:= 1.5
const RADAR_AREA_SPREAD:= 0.8


const RADAR_AREA_SINK:= 0.4
const RADAR_AREA_HEIGHT:= 1.2

const RADAR_MARK_HEIGHT:= 4.0


const RADAR_TURN_DEG:= 36.0

const RADAR_LOCK_SECONDS:= 1.0

const RADAR_BEAM_SECONDS:= 2.4


const RADAR_UPLINK_ELEVATION:= 52.0
const RADAR_UPLINK_LENGTH:= 80.0
const RADAR_UPLINK_RADIUS:= 0.35

const RADAR_DOWNLINK_HEIGHT:= 60.0
const RADAR_DOWNLINK_RADIUS:= 1.2


const RADAR_SIZE:= Vector3(4.7, 5.3, 3.9)

const RADAR_REACH:= 6.0


const PAINT_BOARD_COST:= 35.0


const PAINT_BOARD_SIZE:= Vector3(2.17, 2.41, 0.42)


const WORK_LAMP_COST:= 45.0


const WORK_LAMP_SIZE:= Vector3(0.71, 2.03, 0.65)


const WORK_LAMP_RANGE:= 22.0


const WORK_LAMP_ANGLE:= 62.0


const WORK_LAMP_ENERGY:= 16.0


const WORK_LAMP_FALLOFF:= 0.6


const WORK_LAMP_SPILL_RANGE:= 6.0


const WORK_LAMP_SPILL_ENERGY:= 2.7


const WORK_LAMP_CULL:= 65.0


const WORK_LAMP_FADE:= 12.0


const WORK_LAMP_LIT_DEFAULT:= 8.0


const WORK_LAMP_BRIGHT_DEFAULT:= (WORK_LAMP_LIT_DEFAULT / WORK_LAMP_RANGE) * (WORK_LAMP_LIT_DEFAULT / WORK_LAMP_RANGE)


const WORK_LAMP_BRIGHT_MIN:= 0.1


const WORK_LAMP_CHARGE:= 1.0


const WORK_LAMP_CONSOLE_REACH:= 2.6


const SCANNER_TIERS:= [
        {
                "id": "scanner_mk1", "name": "SCANNER MK I",
                "batch": 60, "scan_seconds": 4.5, "buffer": 120, "cost": 250.0,
                "halt": true,
        },
        {
                "id": "scanner_mk2", "name": "SCANNER MK II",
                "batch": 90, "scan_seconds": 3.0, "buffer": 180, "cost": 500.0,
                "halt": false,
        },
]


const SCANNER_BLOCK_SECONDS:= 6.0


const SCANNER_OUTPUT_SPACING:= BELT_RIDE_SPACING / BELT_SPEED


const SCANNER_BIN_CAPACITY:= 8


const SCANNER_REACH:= 2.0

const SCANNER_FIND_FLASH:= 1.4


const SCANNER_SNAP_RADIUS:= 1.3


const SCANNER_HALF_WIDTH:= 1.25


const SCANNER_HALF_WIDTH_BARE:= 0.72


const SCANNER_ALARM_SECONDS:= 9.0

const SCANNER_ALARM_RPM:= 1.9


const SCANNER_ALARM_RANGE:= 9.0
const SCANNER_ALARM_ENERGY:= 6.0

const COL_SCAN_ALARM_A:= Color(1.0, 0.09, 0.06)
const COL_SCAN_ALARM_B:= Color(0.1, 0.26, 1.0)


const COL_SCAN_BEACON_REST:= Color(0.46, 0.05, 0.04)


const COMPRESSOR_LENGTH:= 2.0 * BELT_SEGMENT
const COMPRESSOR_COST:= 350.0


const COMPRESSOR_BALE_STRANDS:= 60
const COMPRESSOR_BALE_RATIO:= 2.0


const COMPRESSOR_PRESS_SECONDS:= 4.0


const COMPRESSOR_BUFFER:= 240


const COMPRESSOR_BALE_SIZE:= Vector3(0.62, 0.4, 0.52)
const COMPRESSOR_BALE_MASS:= 14.0


const COMPRESSOR_SNAP_RADIUS:= 1.3


const COMPRESSOR_HALF_WIDTH:= 1.1


const COMPRESSOR_HALF_WIDTH_PANEL:= 0.78


const COMPRESSOR_BALE_CLEAR:= 0.7


const WRAPPER_LENGTH:= 2.0 * BELT_SEGMENT


const WRAPPER_COST:= 300.0


const WRAPPER_SECONDS:= 126.0 / 24.0


const WRAPPER_BUFFER:= 3


const WRAPPER_FOILED_SIZE:= Vector3(0.67, 0.44, 0.57)


const WRAPPER_FOILED_MASS:= 15.0


const WRAPPER_FOILED_RATIO:= 1.45


const WRAPPER_SNAP_RADIUS:= 1.3


const WRAPPER_HALF_WIDTH:= 0.99


const WRAPPER_PRODUCT_CLEAR:= 0.75


const SILO_LENGTH:= 2.0 * BELT_SEGMENT


const SILO_COST:= 400.0


const SILO_CAPACITY:= 300


const SILO_CAPACITY_RANKS: Array [int] = [400, 500, 625, 800, 1000]


const SILO_RATE_MIN:= 0.0


const SILO_RATE_BASE_MAX:= 5.0


const SILO_RATE_PER_RANK:= 20.0 / 60.0


const SILO_RATE_STEP_PER_MIN:= 10.0


const SILO_RATE_STEP:= SILO_RATE_STEP_PER_MIN / 60.0


const SILO_RATE_DEFAULT:= 3.0


const SILO_WAD_STRANDS:= 24


const SILO_SNAP_RADIUS:= 1.3


const SILO_HALF_WIDTH:= 1.72


const SILO_PRODUCT_CLEAR:= 0.62


const SILO_CONSOLE_REACH:= 2.6


const SILO_ROTOR_VANES:= 10


const PELLETIZER_BRICK_STRANDS:= 45

const PELLETIZER_BRICK_RATIO:= 2.5


const PELLETIZER_CYCLE_SECONDS:= 3.0


const PELLETIZER_PAD_BRICKS:= 6


const PELLETIZER_PAD_RADIUS:= 0.95


const PELLETIZER_THROW_DISTANCE:= 2.6
const PELLETIZER_THROW_MIN:= 2.0
const PELLETIZER_THROW_MAX:= 4.5


const ECO_BRICK_SIZE:= Vector3(0.22, 0.095, 0.115)
const ECO_BRICK_MASS:= 2.4

const PELLETIZER_COST:= 600.0


const PELLETIZER_BUFFER:= 135


const PELLETIZER_SNAP_RADIUS:= 1.3


const PELLETIZER_KEEPOUT:= Vector4(0.88, 0.88, 0.94, 0.94)


const GENERATOR_COST:= 150.0


const GENERATOR_OUTPUT_KW:= 6.0


const GENERATOR_PILOT_KW:= 0.3


const GENERATOR_FIREBOX_KJ:= 720.0


const GENERATOR_EMBER_SECONDS:= 2.0


const GENERATOR_REFILL_AT:= 0.9


const GENERATOR_KJ_PER_STRAND:= 1.0


const GENERATOR_BURN_LOOSE:= 1.0
const GENERATOR_BURN_BALE:= 1.0
const GENERATOR_BURN_BRICK:= 1.0
const GENERATOR_BURN_FOIL:= 1.0
const GENERATOR_BURN_DISC:= 1.0


const GENERATOR_SNAP_RADIUS:= 1.3


const GENERATOR_KEEPOUT:= Vector4(2.35, 1.52, 0.83, 0.83)


const POWERED_CONSOLE_REACH:= 3.2


const GAS_PLANT_COST:= 4000.0

const GAS_PLANT_CARD_COST:= 2500.0


const GAS_PLANT_KJ_PER_STRAND:= 3.0


const GAS_PLANT_OUTPUT_KW:= 100.0


const GAS_PLANT_LPS_PER_KW:= 0.01


const GAS_PLANT_TANK_SECONDS:= 60.0


const GAS_PLANT_HOPPER_KJ:= 30000.0


const GAS_PLANT_KEEPOUT:= Vector4(3.0, 3.0, 1.5, 1.5)


const POLE_COST:= 45.0


const POLE_SUPPLY_R:= 6.0


const POLE_LINK_R:= 9.0


const POLE_SAG:= 0.0523


const POLE_SAG_STEP:= 0.45


const POLE_HALF_WIDTH:= 0.55


const BOX_COST:= 300.0
const BOX_SUPPLY_R:= 10.0
const BOX_LINK_R:= 18.0


const CABLE_DEPTH:= 0.35


const SCANNER_DRAW_KW:= 0.4


const SCANNER_MK2_DRAW_KW:= 0.6
const LAUNCHER_DRAW_KW:= 1.0

const SILO_DRAW_KW:= 1.2


const WRAPPER_DRAW_KW:= 1.8
const DRONE_DRAW_KW:= 2.5
const COMPRESSOR_DRAW_KW:= 2.6
const PELLETIZER_DRAW_KW:= 3.2


const RAKE_DRAW_KW:= 4.0
const RAKE_DRAW_KW_NARROW:= 2.0


const BOREHOLE_DRAW_KW:= 5.0


const PULPER_DRAW_KW:= 4.2


const BOREHOLE_COST:= 900.0


const BOREHOLE_OUTPUT_LPS:= 12.0


const BOREHOLE_STROKES_PER_MIN:= 12.0


const BOREHOLE_KEEPOUT:= Vector4(2.0, 2.36, 0.77, 0.68)


const PIPE_COST_PER_M:= 14.0


const PIPE_JOIN_TOLERANCE:= 0.01


const PIPE_SUPPORT_SPACING:= 3.0


const PIPE_RUN_HEIGHT:= BELT_FRAME_DEPTH + BELT_STAND_CLEAR


const PIPE_SNAP_RADIUS:= BELT_SNAP_RADIUS


const PIPE_PORT_STUB:= 1.0


const PIPE_JOINT_OVERLAP:= 0.012


const PIPE_SPLITTER_PORT_R:= 0.58


const PIPE_SPLITTER_SPLAY:= SPLITTER_SPLAY


const PIPE_SPLITTER_HALF_WIDTH:= 0.6


const PIPE_SPLITTER_COST:= 90.0


const PULPER_LENGTH:= 4.0 * BELT_SEGMENT


const PULPER_COST:= 780.0


const PULPER_BATCH_STRANDS:= 90


const PULPER_WATER_LITRES:= 32.0


const PULPER_CYCLE_SECONDS:= 121.0 / 30.0


const PULPER_PULP_RATIO:= 3.6


const PULPER_BUFFER:= 360


const PULPER_SLAB_SIZE:= Vector3(0.535, 0.197, 0.503)


const PULPER_SLAB_MASS:= 24.0


const PULPER_SLAB_CLEAR:= 0.78


const PULPER_SNAP_RADIUS:= 1.3


const PULPER_HALF_WIDTH:= 1.25


const PAPER_LENGTH:= 7.0 * BELT_SEGMENT


const PAPER_COST:= 1150.0


const PAPER_DRAW_KW:= 6.0


const PAPER_CYCLE_SECONDS:= 331.0 / 30.0


const PAPER_SLABS_PER_ROLL:= 3


const PAPER_CHARGE_WAIT_GAPS:= 2.0


const PAPER_CHARGE_WAIT_MAX:= 20.0


const PAPER_ROLL_RATIO:= 1.35


const PAPER_BUFFER:= 9


const PAPER_ROLL_SIZE:= Vector3(0.662, 0.561, 0.56)


const PAPER_ROLL_MASS:= 20.0


const PAPER_ROLL_CLEAR:= 0.8


const PAPER_SNAP_RADIUS:= 1.3


const PAPER_HALF_WIDTH:= 1.3


const BRIQUETTE_PORT_UP:= 1.0


const BRIQUETTE_PORT_WAD:= 2.6
const BRIQUETTE_PORT_BRICK:= 3.9
const BRIQUETTE_PORT_DISC:= 1.7


const BRIQUETTE_PORT_WAD_OFFSET:= -0.92


const BRIQUETTE_SNAP_RADIUS:= 1.3


const BRIQUETTE_HALF_WIDTH:= 2.1


const BRIQUETTE_LENGTH:= BRIQUETTE_PORT_BRICK + BRIQUETTE_PORT_DISC


const BRIQUETTE_CYCLE_SECONDS:= 121.0 / 30.0


const BRIQUETTE_SPIN_SECONDS:= 0.8


const BRIQUETTE_BATCH_STRANDS:= 120
const BRIQUETTE_BATCH_BRICKS:= 2


const BRIQUETTE_DISC_RATIO:= 4.2


const BRIQUETTE_BUFFER_STRANDS:= 360
const BRIQUETTE_BUFFER_BRICKS:= 8


const FEED_DISC_SIZE:= Vector3(0.596, 0.198, 0.602)


const FEED_DISC_MASS:= 26.0


const FEED_DISC_CLEAR:= 0.74

const BRIQUETTE_COST:= 1400.0


const BRIQUETTE_DRAW_KW:= 7.5


const LAUNCHER_COST:= 520.0


const LAUNCHER_SNAP_RADIUS:= 1.3


const LAUNCHER_KEEPOUT:= Vector4(1.91, 1.28, 0.94, 0.93)


const DUMP_HATCH_COST:= 40.0


const DUMP_HATCH_HALF_WIDTH:= 1.55


const LAUNCHER_TILT_MIN:= 8.0
const LAUNCHER_TILT_MAX:= 52.0


const LAUNCHER_SPEED_MIN:= 3.0
const LAUNCHER_SPEED_MAX:= 32.0


const LAUNCHER_AIM_DEFAULT:= 0.682
const LAUNCHER_POWER_DEFAULT:= 0.27


const LAUNCHER_YAW_LIMIT:= 90.0


const LAUNCHER_SLEW_SPEED:= 42.0


const LAUNCHER_CYCLE_SECONDS:= 1.3


const LAUNCHER_BUFFER:= 120
const LAUNCHER_WAD_STRANDS:= 24


const LAUNCHER_SPREAD:= 0.12


const LAUNCHER_CONSOLE_REACH:= 2.6


const LAUNCHER_ARC_STEPS:= 52
const LAUNCHER_ARC_MAX_SECONDS:= 6.5


const HAY_STAIRS_COST:= 220.0


const HAY_STAIRS_DECK:= BELT_FRAME_DEPTH + BELT_STAND_CLEAR


const HAY_STAIRS_SNAP_RADIUS:= 1.3


const HAY_STAIRS_HALF_WIDTH:= 1.45


const HAY_STAIRS_MOUTH_RADIUS:= 0.91


const HAY_LIFT_COST:= 480.0


const HAY_LIFT_SECTION_COST:= 70.0


const HAY_LIFT_BASE_RISE:= 2.0


const HAY_LIFT_SECTION:= BELT_SEGMENT


const HAY_LIFT_SECTIONS_MAX:= 10


const HAY_LIFT_DECK:= BELT_FRAME_DEPTH + BELT_STAND_CLEAR


const HAY_LIFT_NIP:= 0.53


const HAY_LIFT_SNAP_RADIUS:= 1.3


const HAY_LIFT_HALF_WIDTH:= 1.6


const HAY_LIFT_SPEED:= BELT_SPEED


const HAY_LIFT_GAP:= 0.88


const MACHINE_STARVED_AFTER:= 1.5


const RAKE_COST:= 120.0


const RAKE_COST_FREE:= 2


const RAKE_COST_GROWTH:= 1.3


const RAKE_LIMIT:= 16


const RAKE_THROW_SECONDS:= 2.4


const RAKE_SMALL_WAD_STRANDS:= 35


const RAKE_BITE_RADIUS:= 0.22
const RAKE_BITE_DROP:= 0.01


const RAKE_NEEDLE_CHANCE:= 0.1


const RAKE_REACH:= 2.55


const RAKE_THROW_DISTANCE:= 5.5
const RAKE_THROW_MIN:= 2.5
const RAKE_THROW_MAX:= 9.0
const RAKE_LAUNCH_ANGLE:= 45.0


const RAKE_LOB_ANGLE:= 65.0
const RAKE_LOB_FROM:= 4.0


const RAKE_THROW_SPREAD:= 0.42


const RAKE_PAD_WADS:= 6


const RAKE_HALF_WIDTH:= 1.15


const RAKE_STAND_CLEAR:= 0.25


const RAKE_SITE_MARGIN:= 0.2


const RAKE_CONSOLE_REACH:= 3.2


const THROW_HOVER_REACH:= 16.0


const RANGE_PIN_SECONDS:= 120.0


const DRONE_COST:= 200.0


const DRONE_COST_GROWTH:= 1.35


const DRONE_COST_FREE:= 1


const DRONE_LIMIT:= 12


const DRONE_RADIUS:= 12.0


const DRONE_RADIUS_STEP:= 3.6
const DRONE_RADIUS_RANKS:= 5


const DRONE_ZONE_R:= 3.0
const DRONE_ZONE_STEP:= 0.5


const DRONE_DIG_STRANDS:= 200
const DRONE_DIG_RADIUS:= 0.6


const DRONE_CRUISE_H:= 4.6
const DRONE_SPEED:= 6.5
const DRONE_CLIMB:= 3.2


const DRONE_ACCEL:= 4.5


const DRONE_CLIMB_ACCEL:= 4.0


const DRONE_TILT_MAX_DEG:= 25.0


const DRONE_TILT_EASE:= 7.0


const DRONE_BOB_HEAVE:= 0.035
const DRONE_BOB_TILT_DEG:= 1.5


const DRONE_BOB_PERIOD:= 3.1
const DRONE_BOB_ROLL_PERIOD:= 2.3
const DRONE_BOB_PITCH_PERIOD:= 1.7


const DRONE_ROTOR_THROTTLE:= 0.3


const DRONE_WINCH_SPEED:= 1.5


const DRONE_WINCH_MAX:= 6.0


const DRONE_HATCH_SECONDS:= 0.53
const DRONE_CLAW_SECONDS:= 0.4


const DRONE_HATCH_OPEN_DEG:= 102.0
const DRONE_CLAW_OPEN_DEG:= 78.0


const DRONE_ROTOR_SPEED:= 22.0


const DRONE_SCAN_INTERVAL:= 0.7


const DRONE_DROP_CLEAR:= 0.3


const DRONE_TILL_CLEAR:= 2.5


const DELIVERY_STOCK_R:= 6.0


const DRONE_CLEAR_RADIUS:= 2.4


const DRONE_RING_BAND:= 0.18
const DRONE_RING_LIFT:= 0.06


const RANGE_PEEK_DIST:= 22.0


const COL_SCAN_IDLE:= Color(0.16, 0.7, 0.95)
const COL_SCAN_FIND:= Color(1.0, 0.72, 0.18)


const WAD_BASE_STRANDS:= 50


const WAD_MIN_STRANDS:= 20


const WAD_MAX_STRANDS:= 200


const WAD_BASE_SIZE:= Vector3(0.511, 0.441, 0.477)


const WAD_COLLIDER_SHRINK:= 0.86


const WAD_PACK:= 0.42


const WAD_MASS_PER_STRAND:= COMPRESSOR_BALE_MASS / float(COMPRESSOR_BALE_STRANDS)
const WAD_MASS_MIN:= 2.5
const WAD_MASS_MAX:= 26.0


const WAD_CLEAR:= 0.62


const PROP_CAP_MIN:= 20
const PROP_CAP_MAX:= 1500


const PROP_KEEP_DIST:= 12.0


const PROP_DRAIN_PER_PASS:= 3


const PROP_SCAN_PERIOD:= 0.5


const PROP_BIRTH_GRACE:= 4.0


const PROP_CAP_DEFAULT:= 150


const PROP_CAP_OLD_SNAPSHOT:= 240
const PROP_DECAY_DEFAULT:= true
var prop_cap: int = PROP_CAP_DEFAULT
var prop_decay: bool = PROP_DECAY_DEFAULT


const AUTO_CLEAN_DEFAULT:= false
const AUTO_CLEAN_SECONDS_DEFAULT:= 60.0
const AUTO_CLEAN_SECONDS_MIN:= 15.0
const AUTO_CLEAN_SECONDS_MAX:= 600.0


const AUTO_CLEAN_MOVE:= 0.05


const AUTO_CLEAN_PER_PASS:= 6
var auto_clean: bool = AUTO_CLEAN_DEFAULT
var auto_clean_seconds: float = AUTO_CLEAN_SECONDS_DEFAULT


const BUILD_FX_DEFAULT:= true
var build_fx: bool = BUILD_FX_DEFAULT


var _prop_cap_user: Variant = null


var _prop_cap_file: Variant = null


const BELT_CAP_MIN:= 20
const BELT_CAP_MAX:= 5000


const BELT_CAP_DEFAULT:= 600


const BELT_CAP_OLD_DEFAULTS: Array [int] = [200, 300]


const BELT_CAP_REV:= 3
const BELT_DECAY_DEFAULT:= true
var belt_cap: int = BELT_CAP_DEFAULT
var belt_decay: bool = BELT_DECAY_DEFAULT


const PLATFORM_TILE:= 2.0


const PLATFORM_THICK:= 0.22


const PLATFORM_FLUSH_LIFT:= 0.005

const PLATFORM_PLATE_THICK:= 0.05
const PLATFORM_COST_PER_M2:= 10.0


const PLATFORM_MIN_SPAN:= PLATFORM_TILE
const PLATFORM_MAX_SPAN:= 16.0


const PLATFORM_LEG_SPACING:= 8.0
const PLATFORM_LEG_MAX_DROP:= 14.0


const PLATFORM_LEG_INSET:= 0.3


const PLATFORM_SNAP_RADIUS:= 1.3

const PLATFORM_RAIL_H:= 1.05
const PLATFORM_RAIL_POST_SPACING:= 1.5


const RAILING_COST_PER_M:= 6.0
const RAILING_MIN_LENGTH:= 0.8
const RAILING_MAX_LENGTH:= 24.0


const RAILING_SNAP_RADIUS:= 1.4


const STAIR_WIDTH:= 1.2


const STAIR_PITCH:= 0.6


const STAIR_PITCH_MIN:= 0.3
const STAIR_PITCH_MAX:= 0.85
const STAIR_RISER:= 0.2
const STAIR_COST_PER_M:= 15.0
const STAIR_MAX_RISE:= 12.0


const WALL_PANEL:= PLATFORM_TILE


const WALL_HEIGHT:= 2.4

const WALL_THICK:= 0.1


const WALL_POST_H:= 2.52


const WALL_COST_PER_M:= 22.0


const WALL_MIN_LENGTH:= WALL_PANEL
const WALL_MAX_LENGTH:= 24.0


const WALL_SNAP_RADIUS:= 1.4


const WALL_COURSE:= WALL_HEIGHT


const WALL_SNAP_RISE:= WALL_COURSE * 0.5


const WALL_WINDOW_WIDTH:= 1.3


const WALL_WINDOW_SILL:= PLATFORM_RAIL_H
const WALL_WINDOW_HEAD:= 2.05


const WALL_DOOR_WIDTH:= 1.1
const WALL_DOOR_HEAD:= 2.05


const WALL_COLLIDER_THICK:= 0.16


const ROOF_BAY:= WALL_PANEL


const ROOF_DEPTH:= PLATFORM_TILE


const ROOF_RISE:= 1.0

const ROOF_SHEET_THICK:= 0.06


const ROOF_COLLIDER_THICK:= 0.14


const ROOF_COST_PER_M:= 28.0
const ROOF_MIN_LENGTH:= ROOF_BAY
const ROOF_MAX_LENGTH:= 24.0


const ROOF_MAX_ROWS:= 8


const ROOF_SNAP_RADIUS:= WALL_SNAP_RADIUS


const ROOF_AIM_RADIUS:= 1.6


const ROOF_AIM_OVERREACH:= 4.0


const ROOF_ENCLOSURE_REACH:= 24.0


const ROOF_HATCH:= 0.9


const ROOF_HATCH_COST:= 60.0


const ROOF_HATCH_MIN_DROP:= 2.0


const LADDER_WIDTH:= 0.52
const LADDER_STILE:= 0.055
const LADDER_RUNG:= 0.04
const LADDER_RUNG_SPACING:= 0.3


const LADDER_MAX_DROP:= PLATFORM_LEG_MAX_DROP

const LADDER_GRAB_H:= 0.95


const CLIMB_SPEED:= 2.2


const CLIMB_FACING:= 0.35


const CLIMB_EXIT_LEAD:= 1.0
const CLIMB_TOP_NUDGE:= 0.6
const CLIMB_PUSH_OFF:= 3.2


const COL_DECK_PLATE:= Color(1.18, 1.205, 1.16)


const COL_DECK_BEAM:= Color(0.615, 0.595, 0.56)


const COL_ROOF_SHEET:= Color(0.9, 0.93, 0.975)


const COL_HAY_DARK:= Color(0.07, 0.04, 0.011)
const COL_HAY_LIGHT:= Color(0.72, 0.478, 0.158)
const COL_WALL:= Color(0.115, 0.125, 0.155)
const COL_SLAB:= Color(0.8, 0.775, 0.715)
const COL_FLOOR:= Color(0.155, 0.16, 0.175)
const COL_NEEDLE:= Color(0.86, 0.88, 0.92)


enum Quality { POTATO, LOW, MEDIUM, HIGH, ULTRA }


const PRESETS:= {


        Quality.POTATO: {
                "name": "Potato",


                "machine_distance": 1,
                "texture_res": 0,
                "strands_per_cell": 190,
                "live_budget": 400,
                "prop_cap": 60,
                "lod_near": 6.0, "lod_far": 18.0, "lod_min": 0.45,
                "shadow_distance": 0.0,
                "yard_shadow_distance": 0.0,
                "detail_strands": 0, "detail_radius": 0.0,
                "msaa": Viewport.MSAA_DISABLED,
                "ssao": false, "glow": false, "shadows": false, "shadow_quality": 0,
                "ssil": false, "vfog": false, "taa": false,
                "fxaa": true,
                "gi": false, "dof": false,
                "render_scale": 0.72,
                "lod_threshold": 8.0,
                "sky_marches": 0,
                "reflect_probe": false, "dust": false,
                "aniso": Viewport.ANISOTROPY_DISABLED,
                "machine_lod": 15.0,
                "crust_budget": 0.5,
                "sign_distance": 25.0,
        },
        Quality.LOW: {
                "name": "Low",
                "machine_distance": 2,
                "texture_res": 0,
                "strands_per_cell": 190,
                "live_budget": 700,
                "prop_cap": 90,
                "lod_near": 8.0, "lod_far": 22.0, "lod_min": 0.55,
                "shadow_distance": 3.0,
                "yard_shadow_distance": 0.0,
                "detail_strands": 0, "detail_radius": 0.0,
                "msaa": Viewport.MSAA_DISABLED,
                "ssao": false, "glow": true, "shadows": false, "shadow_quality": 0,
                "ssil": false, "vfog": false, "taa": false,
                "fxaa": true,
                "gi": false, "dof": false,
                "render_scale": 0.85,
                "lod_threshold": 4.0,
                "sky_marches": 0,
                "reflect_probe": true, "dust": true,
                "aniso": Viewport.ANISOTROPY_2X,
                "machine_lod": 22.0,
                "crust_budget": 0.75,
                "sign_distance": 35.0,
        },
        Quality.MEDIUM: {
                "name": "Medium",
                "machine_distance": 2,
                "texture_res": 0,
                "strands_per_cell": 190,
                "live_budget": 1200,
                "prop_cap": 120,
                "lod_near": 11.0, "lod_far": 28.0, "lod_min": 0.7,
                "shadow_distance": 6.0,
                "yard_shadow_distance": 8.0,
                "detail_strands": 120000, "detail_radius": 6.0,
                "msaa": Viewport.MSAA_DISABLED,
                "ssao": false, "glow": true, "shadows": true, "shadow_quality": 1,
                "ssil": false, "vfog": false, "taa": true,
                "fxaa": false,
                "gi": false, "dof": false,
                "render_scale": 0.92,
                "lod_threshold": 2.0,
                "sky_marches": 16,
                "reflect_probe": true, "dust": true,
        },


        Quality.HIGH: {
                "name": "High",
                "machine_distance": 3,
                "texture_res": 0,
                "strands_per_cell": 190,
                "live_budget": 2000,
                "prop_cap": 150,
                "lod_near": 14.0, "lod_far": 34.0, "lod_min": 0.88,
                "shadow_distance": 9.0,
                "yard_shadow_distance": 12.0,
                "detail_strands": 200000, "detail_radius": 8.0,
                "msaa": Viewport.MSAA_DISABLED,
                "ssao": true, "glow": true, "shadows": true, "shadow_quality": 2,
                "ssil": false, "vfog": true, "taa": true,
                "fxaa": false,
                "gi": false, "dof": false,
                "render_scale": 1.0,
                "lod_threshold": 1.0,
                "sky_marches": 40,
                "reflect_probe": true, "dust": true,
        },
        Quality.ULTRA: {
                "name": "Ultra",
                "machine_distance": 3,
                "texture_res": 0,
                "strands_per_cell": 190,
                "live_budget": 3500,
                "prop_cap": 150,
                "lod_near": 18.0, "lod_far": 44.0, "lod_min": 1.0,
                "shadow_distance": 12.0,
                "yard_shadow_distance": 18.0,
                "detail_strands": 450000, "detail_radius": 10.0,
                "msaa": Viewport.MSAA_4X,
                "ssao": true, "glow": true, "shadows": true, "shadow_quality": 1,
                "ssil": true, "vfog": true, "taa": true,
                "fxaa": false,
                "gi": true, "dof": false,
                "render_scale": 1.0,
                "lod_threshold": 1.0,
                "sky_marches": 64,
                "reflect_probe": true, "dust": true,
        },
}

const QUALITY_DEFAULT:= Quality.HIGH
var quality: Quality = QUALITY_DEFAULT


var crust_strands_per_cell: int = 130
var live_strand_budget: int = 2000
var crust_lod_near: float = 14.0
var crust_lod_far: float = 34.0
var crust_lod_min: float = 0.88
var crust_shadow_distance: float = 9.0


var yard_shadow_distance: float = 12.0


var detail_strands: int = 300000
var detail_radius: float = 8.0


var detail_scale: float = 1.0


var perf_scale: float = 1.0

signal quality_changed(level: Quality)


signal gfx_changed


const RENDERERS:= ["vulkan", "d3d12"]


const RENDERER_NAMES:= ["VULKAN", "DIRECT3D 12"]

const RENDERER_DEFAULT:= "vulkan"
const RENDERER_DRIVER_KEY:= "rendering_device/driver.windows"
const RENDERER_FALLBACK_KEYS:= [
        "rendering_device/fallback_to_vulkan",
        "rendering_device/fallback_to_d3d12",
        "rendering_device/fallback_to_opengl3",
]


var renderer:= RENDERER_DEFAULT


var renderer_picked:= false


const VULKAN_LOST_GPU:= "(?i)\\bRX\\s*5[3-7]\\d\\d(?!\\d)|\\bPro\\s*W5[5-7]00\\b"


func vulkan_lost_gpu(adapter: String = "") -> bool:
        if adapter == "":
                adapter = OS.get_environment("FTN_FAKE_GPU")
        if adapter == "":
                adapter = RenderingServer.get_video_adapter_name()
        var re:= RegEx.create_from_string(VULKAN_LOST_GPU)
        return re.is_valid() and re.search(adapter) != null


func default_renderer() -> String:
        return "d3d12" if vulkan_lost_gpu() else RENDERER_DEFAULT


func _override_path() -> String:
        if override_file != "":
                return override_file
        if OS.has_feature("editor"):
                return "res://override.cfg"
        return OS.get_executable_path().get_base_dir().path_join("override.cfg")


func set_renderer(name: String, picked: bool = true) -> bool:
        if not name in RENDERERS:
                return false
        if not _write_renderer_override(name, _renderer_may_fall_back(name, picked)):
                return false
        renderer = name
        renderer_picked = picked
        save_settings()
        return true


func _write_renderer_override(name: String, fall_back: bool = false) -> bool:
        if not name in RENDERERS:
                return false
        var cf:= ConfigFile.new()
        var path:= _override_path()
        var loaded:= cf.load(path)
        if loaded != OK and loaded != ERR_FILE_NOT_FOUND:
                return false
        cf.set_value("rendering", RENDERER_DRIVER_KEY, name)
        for key: String in RENDERER_FALLBACK_KEYS:
                cf.set_value("rendering", key, false)
        if fall_back:
                cf.set_value("rendering", "rendering_device/fallback_to_vulkan", true)
        return cf.save(path) == OK


func _renderer_may_fall_back(name: String, picked: bool) -> bool:
        return not picked and name != RENDERER_DEFAULT


func sync_renderer() -> bool:
        if override_file == "" and (OS.has_feature("editor") or settings_readonly or DisplayServer.get_name() == "headless"):
                return true
        return _write_renderer_override(renderer,
                _renderer_may_fall_back(renderer, renderer_picked))


func _pick_renderer_for_gpu() -> void:
        if renderer_picked or settings_readonly:
                return
        var want:= default_renderer()
        if want == RENDERER_DEFAULT or renderer == want:
                return
        print("[cfg] %s: renderer %s -> %s" % [RenderingServer.get_video_adapter_name(),
                renderer, want])
        renderer = want


        save_settings()


func running_renderer() -> String:
        var driver:= RenderingServer.get_current_rendering_driver_name()
        if driver == "":
                driver = RENDERER_DEFAULT
        return driver


enum RenderThread { AUTO, ON, OFF }

const RENDER_THREAD_NAMES:= ["AUTO", "ON", "OFF"]
const RENDER_THREAD_DEFAULT:= RenderThread.AUTO


const THREAD_MODEL_SEPARATE:= 2
const THREAD_MODEL_SINGLE:= 1


const THREAD_MODEL_KEY_EXPORT:= "driver/threads/thread_model.template"
const THREAD_MODEL_KEY:= "driver/threads/thread_model"


const RENDER_THREAD_RESTART_ENV:= "FTN_RENDER_THREAD_RESTARTED"

var render_thread: RenderThread = RENDER_THREAD_DEFAULT


var render_thread_suspect:= false


var override_file:= ""


func render_thread_wanted() -> bool:
        match render_thread:
                RenderThread.ON:
                        return true
                RenderThread.OFF:
                        return false
        return render_thread_auto()


func render_thread_auto() -> bool:
        if not OS.has_feature("editor"):
                return true
        var cf:= ConfigFile.new()
        if cf.load(_override_path()) != OK:
                return false
        return int(cf.get_value("rendering", THREAD_MODEL_KEY,
                THREAD_MODEL_SINGLE)) == THREAD_MODEL_SEPARATE


func running_render_thread() -> bool:
        return not RenderingServer.is_on_render_thread()


func set_render_thread(mode: int) -> bool:
        render_thread = clampi(mode, 0, RenderThread.size() - 1) as RenderThread
        save_settings()
        return sync_render_thread()


func sync_render_thread() -> bool:
        if override_file == "" and (settings_readonly or DisplayServer.get_name() == "headless"):
                return true
        if OS.has_feature("editor") and render_thread == RenderThread.AUTO:
                return true
        var cf:= ConfigFile.new()
        var path:= _override_path()
        cf.load(path)
        if OS.has_feature("template"):


                cf.set_value("rendering", THREAD_MODEL_KEY_EXPORT,
                        THREAD_MODEL_SEPARATE if render_thread_wanted() else THREAD_MODEL_SINGLE)
                if cf.has_section_key("rendering", THREAD_MODEL_KEY):
                        cf.erase_section_key("rendering", THREAD_MODEL_KEY)
        elif render_thread_wanted():
                cf.set_value("rendering", THREAD_MODEL_KEY, THREAD_MODEL_SEPARATE)
        elif cf.has_section_key("rendering", THREAD_MODEL_KEY):
                cf.erase_section_key("rendering", THREAD_MODEL_KEY)
        if cf.get_sections().is_empty():
                if FileAccess.file_exists(path):
                        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
                return true
        return cf.save(path) == OK


func _restart_off_the_render_thread() -> bool:
        if OS.has_feature("editor") or not OS.has_feature("template"):
                return false
        if settings_readonly or DisplayServer.get_name() == "headless":
                return false
        if not running_render_thread() or render_thread_wanted():
                return false
        if OS.get_environment(RENDER_THREAD_RESTART_ENV) != "":
                return false
        if FileAccess.file_exists(CrashReport.SENTINEL):
                return false

        var cf:= ConfigFile.new()
        if cf.load(_override_path()) != OK or int(cf.get_value("rendering",
                        THREAD_MODEL_KEY_EXPORT, THREAD_MODEL_SEPARATE)) != THREAD_MODEL_SINGLE:
                return false
        OS.set_environment(RENDER_THREAD_RESTART_ENV, "1")
        print("[cfg] render thread running but not wanted here; restarting once without it")
        restart_game()
        return true


func restart_game() -> void:
        var args:= OS.get_cmdline_args()
        var user:= OS.get_cmdline_user_args()
        if not user.is_empty():
                args.append("--")
                args.append_array(user)
        OS.set_restart_on_exit(true, args)
        get_tree().quit()


var gfx: Dictionary = { }


var _gfx_file: Dictionary = { }


var _gfx_user: Dictionary = { }


const GFX_FROM_PRESET:= {

        "machine_distance": "machine_distance",
        "taa": "taa",
        "msaa": "msaa",


        "fxaa": "fxaa",
        "render_scale": "render_scale",
        "shadows": "shadows",
        "shadow_quality": "shadow_quality",
        "ssao": "ssao",
        "ssil": "ssil",
        "vfog": "vfog",
        "glow": "glow",


        "gi": "gi",


        "dof": "dof",


        "hay_density": "strands_per_cell",


        "hay_lod_min": "lod_min",


        "texture_res": "texture_res",


        "sky_marches": "sky_marches",


        "reflect_probe": "reflect_probe",


        "dust": "dust",
}


const HAY_DENSITY_MIN:= 190


const GFX_EXTRA:= {


        "fog": true,


        "shadow_blur": 3.6,


        "glow_intensity": 0.04,
        "adjustment": true,


        "color_correction": true,


        "tonemap": 4,
        "exposure": 0.89,


        "white": 4.6,


        "ambient_sky": true,


        "sky_contribution": 0.8,
        "reflect_sky": true,


        "auto_exposure": false,
}


const MSAA_NAMES:= ["OFF", "2X", "4X", "8X"]

const TONEMAP_NAMES:= ["LINEAR", "REINHARD", "FILMIC", "ACES", "AGX"]

const SHADOW_QUALITY_NAMES:= ["LOW", "MEDIUM", "HIGH", "ULTRA"]


const SHADOW_ATLAS_SIZES:= [1024, 2048, 4096, 8192]


const SHADOW_FILTER_QUALITIES:= [
        RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
        RenderingServer.SHADOW_QUALITY_SOFT_LOW,
        RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
        RenderingServer.SHADOW_QUALITY_SOFT_ULTRA,
]


const TEXTURE_RES_NAMES:= ["1K", "2K", "4K"]
const TEXTURE_RES_TAGS:= ["1k", "2k", "4k"]


const MACHINE_DISTANCE_NAMES:= ["40 m", "60 m", "80 m", "120 m", "200 m", "400 m", "Unlimited"]
const MACHINE_DISTANCE_METRES:= [40.0, 60.0, 80.0, 120.0, 200.0, 400.0, 0.0]


func sync_gfx_to_preset(keep_user: bool = true) -> void:
        var fresh:= authored_gfx()
        for key: String in fresh:
                gfx [key] = fresh [key]
        if not keep_user:
                _gfx_user.clear()
                sync_msaa_pipelines()
                return


        for key: String in _gfx_user:
                if gfx.has(key):
                        gfx [key] = _gfx_user [key]
        sync_msaa_pipelines()


func sync_msaa_pipelines() -> void:
        if old_laptop:
                return
        const KEY:= "rendering/anti_aliasing/quality/msaa_3d"
        var want:= int(gfx.get("msaa", Viewport.MSAA_DISABLED))
        if int(ProjectSettings.get_setting(KEY, 0)) != want:
                ProjectSettings.set_setting(KEY, want)


func authored_gfx() -> Dictionary:
        var out:= { }
        var p: Dictionary = preset()
        for key: String in GFX_FROM_PRESET:
                out [key] = p [GFX_FROM_PRESET [key]]
        for key: String in GFX_EXTRA:
                out [key] = GFX_EXTRA [key]


        var authored:= _look_defaults()
        for key: String in authored:
                out [key] = authored [key]
        return out


func authored_prop_cap() -> int:
        return clampi(int(PRESETS [quality] ["prop_cap"]), PROP_CAP_MIN, PROP_CAP_MAX)


const LOOK_ENV_PATH:= "res://scenes/look/yard_environment.tres"


var _look_defaults_cache: Dictionary = { }
var _look_read:= false


func _look_defaults() -> Dictionary:
        if _look_read:
                return _look_defaults_cache
        _look_read = true
        var e: Environment = null
        if ResourceLoader.exists(LOOK_ENV_PATH):
                e = ResourceLoader.load(LOOK_ENV_PATH, "",
                        ResourceLoader.CACHE_MODE_IGNORE) as Environment
        if e == null:
                push_warning("[cfg] no look resource at %s, using GFX_EXTRA"
                        % LOOK_ENV_PATH)
                return _look_defaults_cache
        _look_defaults_cache = {
                "fog": e.fog_enabled,
                "glow_intensity": e.glow_intensity,
                "adjustment": e.adjustment_enabled,
                "color_correction": e.adjustment_color_correction != null,
                "tonemap": int(e.tonemap_mode),
                "exposure": e.tonemap_exposure,
                "white": e.tonemap_white,
                "ambient_sky": e.ambient_light_source == Environment.AMBIENT_SOURCE_SKY,
                "sky_contribution": e.ambient_light_sky_contribution,
                "reflect_sky": e.reflected_light_source == Environment.REFLECTION_SOURCE_SKY,
        }
        return _look_defaults_cache


func texture_res() -> String:
        var i: int = clampi(int(gfx.get("texture_res", 0)), 0, TEXTURE_RES_TAGS.size() - 1)
        return TEXTURE_RES_TAGS [i]


func machine_distance_metres() -> float:
        var index:= clampi(int(gfx.get("machine_distance", PRESETS [quality] ["machine_distance"])),
                0, MACHINE_DISTANCE_METRES.size() - 1)
        return MACHINE_DISTANCE_METRES [index]


func set_gfx(key: String, value: Variant) -> void:
        if key == "machine_distance":
                value = clampi(int(value), 0, MACHINE_DISTANCE_METRES.size() - 1)

        if gfx.get(key) == value and (key != "machine_distance" or _gfx_user.has(key)):
                return
        gfx [key] = value
        _gfx_user [key] = value
        if key == "msaa":
                sync_msaa_pipelines()
        save_settings()
        gfx_changed.emit()


func reset_gfx() -> void:
        sync_gfx_to_preset(false)
        save_settings()
        gfx_changed.emit()


const SETTINGS_PATH:= "user://settings.cfg"


const MOUSE_SENS_MIN:= 0.3
const MOUSE_SENS_MAX:= 3.0
const MOUSE_SENS_DEFAULT:= 1.0
var mouse_sensitivity:= MOUSE_SENS_DEFAULT


var invert_look_x:= false
var invert_look_y:= false


const TOOL_MODE_NAMES:= ["Simple", "Advanced"]
const TOOL_SIMPLE:= 0
const TOOL_ADVANCED:= 1
var tool_mode:= TOOL_SIMPLE


const FULLSCREEN_DEFAULT:= true
const VSYNC_DEFAULT:= true
var fullscreen:= FULLSCREEN_DEFAULT
var vsync:= VSYNC_DEFAULT


const FPS_CAPS: Array [int] = [30, 60, 75, 90, 120, 144, 165, 240, 0]
const MAX_FPS_DEFAULT:= 0
var max_fps:= MAX_FPS_DEFAULT


const RESOLUTIONS: Array [Vector2i] = [
        Vector2i(1280, 720),
        Vector2i(1366, 768),
        Vector2i(1600, 900),
        Vector2i(1920, 1080),
        Vector2i(2560, 1440),
        Vector2i(3200, 1800),
        Vector2i(3840, 2160),
]


const WINDOW_SIZE_DEFAULT:= Vector2i(1600, 900)
var window_size:= WINDOW_SIZE_DEFAULT


const DISPLAY_SETTLE_FRAMES:= 2
var _display_target_fullscreen:= false
var _display_target_size:= WINDOW_SIZE_DEFAULT
var _display_target_resize:= true
var _display_pending:= false
var _display_running:= false
var _display_closing:= false
var _display_serial:= 0


const UI_DESIGN_HEIGHT:= 1080.0


var ui_scale:= 1.0


const NO_HUD_DEFAULT:= false
var no_hud:= NO_HUD_DEFAULT
signal no_hud_changed(on: bool)


const SMOOTH_CAMERA_DEFAULT:= false
var smooth_camera:= SMOOTH_CAMERA_DEFAULT


const SMOOTH_CAMERA_AMOUNT_DEFAULT:= 0.05
var smooth_camera_amount:= SMOOTH_CAMERA_AMOUNT_DEFAULT


const SHOW_MISSIONS_DEFAULT:= true
var show_missions:= SHOW_MISSIONS_DEFAULT
signal show_missions_changed(on: bool)


const SHOW_TIPS_DEFAULT:= true
var show_tips:= SHOW_TIPS_DEFAULT


enum HayReadout { PERCENT, AMOUNT }


const HAY_READOUT_NAMES:= ["PERCENT", "AMOUNT"]


const HAY_READOUT_DEFAULT:= HayReadout.AMOUNT
var hay_readout: int = HAY_READOUT_DEFAULT


signal hay_readout_changed(mode: int)


const SHOW_HAY_RATE_DEFAULT:= false
var show_hay_rate: bool = SHOW_HAY_RATE_DEFAULT


signal show_hay_rate_changed(on: bool)


signal hud_style_changed


const HUD_SCALE_MIN:= 0.7
const HUD_SCALE_MAX:= 1.6
const HUD_SCALE_DEFAULT:= 1.0
var hud_scale:= HUD_SCALE_DEFAULT


const TECH_TEXT_SCALE_MIN:= 1.0
const TECH_TEXT_SCALE_MAX:= 2.0
const TECH_TEXT_SCALE_DEFAULT:= 1.0
var tech_text_scale:= TECH_TEXT_SCALE_DEFAULT


const CROSSHAIR_STYLE_NAMES:= ["Ring", "Dot", "Cross", "Off"]
const CROSSHAIR_RING:= 0
const CROSSHAIR_DOT:= 1
const CROSSHAIR_CROSS:= 2
const CROSSHAIR_OFF:= 3
const CROSSHAIR_STYLE_DEFAULT:= CROSSHAIR_RING
var crosshair_style:= CROSSHAIR_STYLE_DEFAULT


const CROSSHAIR_SIZE_MIN:= 0.5
const CROSSHAIR_SIZE_MAX:= 2.5
const CROSSHAIR_SIZE_DEFAULT:= 1.0
var crosshair_size:= CROSSHAIR_SIZE_DEFAULT


const CROSSHAIR_OPACITY_MIN:= 0.2
const CROSSHAIR_OPACITY_DEFAULT:= 1.0
var crosshair_opacity:= CROSSHAIR_OPACITY_DEFAULT


const CROSSHAIR_COLOUR_NAMES:= ["White", "Amber", "Lime", "Cyan", "Red", "Black"]
const CROSSHAIR_COLOURS: Array [Color] = [
        Color(1.0, 1.0, 1.0),
        Color(1.0, 0.78, 0.3),
        Color(0.62, 1.0, 0.36),
        Color(0.4, 0.93, 1.0),
        Color(1.0, 0.36, 0.3),
        Color(0.04, 0.04, 0.05),
]


const CROSSHAIR_BLACK:= 5
const CROSSHAIR_WHITE:= 0
var crosshair_colour:= CROSSHAIR_WHITE


const SHOW_HOTKEY_BAR_DEFAULT:= true
var show_hotkey_bar:= SHOW_HOTKEY_BAR_DEFAULT


const SHOW_CONTROL_HINTS_DEFAULT:= true
var show_control_hints:= SHOW_CONTROL_HINTS_DEFAULT


const TEACH_HINTS_DEFAULT:= true
var teach_hints:= TEACH_HINTS_DEFAULT


var plate_dark:= false


var shop_dark:= true


var keys_used:= { }
var builds_placed:= { }
var techs_seen:= { }
var machines_seen:= { }
var nudges_given:= { }


const CATALOG_GRID_DEFAULT:= true
var catalog_grid:= CATALOG_GRID_DEFAULT


const CATALOG_RECENT_FIRST_DEFAULT:= true
var catalog_recent_first:= CATALOG_RECENT_FIRST_DEFAULT


func crosshair_tint() -> Color:
        var i:= clampi(crosshair_colour, 0, CROSSHAIR_COLOURS.size() - 1)
        return Color(CROSSHAIR_COLOURS [i], crosshair_opacity)


func set_hud_scale(value: float) -> void:
        hud_scale = clampf(value, HUD_SCALE_MIN, HUD_SCALE_MAX)
        hud_style_changed.emit()
        save_settings()


func set_tech_text_scale(value: float) -> void:
        tech_text_scale = clampf(value, TECH_TEXT_SCALE_MIN, TECH_TEXT_SCALE_MAX)
        hud_style_changed.emit()
        save_settings()


func set_crosshair_style(value: int) -> void:
        crosshair_style = clampi(value, 0, CROSSHAIR_STYLE_NAMES.size() - 1)
        hud_style_changed.emit()
        save_settings()


func set_crosshair_size(value: float) -> void:
        crosshair_size = clampf(value, CROSSHAIR_SIZE_MIN, CROSSHAIR_SIZE_MAX)
        hud_style_changed.emit()
        save_settings()


func set_crosshair_opacity(value: float) -> void:
        crosshair_opacity = clampf(value, CROSSHAIR_OPACITY_MIN, 1.0)
        hud_style_changed.emit()
        save_settings()


func set_crosshair_colour(value: int) -> void:
        crosshair_colour = clampi(value, 0, CROSSHAIR_COLOURS.size() - 1)
        hud_style_changed.emit()
        save_settings()


func set_show_hotkey_bar(on: bool) -> void:
        show_hotkey_bar = on
        hud_style_changed.emit()
        save_settings()


func set_show_control_hints(on: bool) -> void:
        show_control_hints = on
        hud_style_changed.emit()
        save_settings()


func set_plate_dark(on: bool) -> void:
        plate_dark = on
        save_settings()


func set_shop_dark(on: bool) -> void:
        shop_dark = on
        save_settings()


func set_teach_hints(on: bool) -> void:
        teach_hints = on
        if on:
                _forget_lessons()
        save_settings()


func restart_lessons() -> void:
        _forget_lessons()
        save_settings()


func _forget_lessons() -> void:
        keys_used.clear()
        builds_placed.clear()
        techs_seen.clear()
        machines_seen.clear()
        nudges_given.clear()


func key_used(action: String) -> bool:
        return keys_used.has(action)


func use_key(action: String) -> void:
        _learn(keys_used, action)


func build_is_new(id: String) -> bool:
        return teach_hints and not builds_placed.has(id)


func place_build(id: String) -> void:
        _learn(builds_placed, id)


func tech_seen(id: String) -> bool:
        return techs_seen.has(id)


func see_tech(id: String) -> void:
        _learn(techs_seen, id)


func machine_seen(id: String) -> bool:
        return machines_seen.has(id)


func see_machine(id: String) -> void:
        _learn(machines_seen, id)


func nudge_given(id: String) -> bool:
        return nudges_given.has(id)


func give_nudge(id: String) -> void:
        _learn(nudges_given, id)


func learn_many(builds: Array, machines: Array) -> void:
        var changed:= false
        for id in builds:
                if id != "" and not builds_placed.has(id):
                        builds_placed [id] = true
                        changed = true
        for id in machines:
                if id != "" and not machines_seen.has(id):
                        machines_seen [id] = true
                        changed = true
        if changed:
                _save_learned()


func _learn(list: Dictionary, id: String) -> void:
        if id == "" or list.has(id):
                return
        list [id] = true
        _save_learned()


func _save_learned() -> void:
        if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().is_empty():
                save_settings()


var t_splitter_port_r:= T_SPLITTER_PORT_R
signal t_splitter_size_changed(port_r: float)


func set_t_splitter_port_r(r: float) -> void:
        r = T_SPLITTER_PORT_R_1M if is_equal_approx(r, T_SPLITTER_PORT_R_1M) else T_SPLITTER_PORT_R
        if is_equal_approx(r, t_splitter_port_r):
                return
        t_splitter_port_r = r
        t_splitter_size_changed.emit(r)
        save_settings()


func set_catalog_grid(on: bool) -> void:
        catalog_grid = on
        save_settings()


func set_catalog_recent_first(on: bool) -> void:
        catalog_recent_first = on
        save_settings()


func _ready() -> void:


        get_window().title = "Find The Needle"

        _apply_ui_scale()
        get_tree().root.size_changed.connect(_apply_ui_scale)
        get_tree().root.tree_exiting.connect(_stop_display_changes)


        var first_launch:= not FileAccess.file_exists(SETTINGS_PATH)
        load_settings()


        apply_locale()


        if first_launch and integrated_gpu():
                quality = Quality.LOW


        elif not igpu_checked and integrated_gpu():
                if quality > Quality.LOW:
                        quality = Quality.LOW
                igpu_checked = true
                save_settings.call_deferred()
        if first_launch:
                igpu_checked = true
        _pick_renderer_for_gpu()


        sync_renderer()
        sync_render_thread()
        _restart_off_the_render_thread()


        var ua:= OS.get_cmdline_user_args()
        var qi:= ua.find("--quality")
        if ("--gpuallocs" in ua or "--yardperf" in ua) and qi >= 0 and qi + 1 < ua.size():
                settings_readonly = true
                quality = clampi(int(ua [qi + 1]), 0, Quality.size() - 1) as Quality


        apply_quality(quality, false)


        for key: String in _gfx_file:

                if not gfx.has(key) or (key != "machine_distance" and gfx [key] == _gfx_file [key]):
                        continue
                gfx [key] = _gfx_file [key]
                _gfx_user [key] = _gfx_file [key]


        if _prop_cap_file != null and int(_prop_cap_file) != prop_cap and int(_prop_cap_file) != PROP_CAP_OLD_SNAPSHOT:
                prop_cap = int(_prop_cap_file)
                _prop_cap_user = prop_cap


        gfx ["hay_density"] = maxi(int(gfx ["hay_density"]), HAY_DENSITY_MIN)
        gfx ["shadow_quality"] = clampi(int(gfx ["shadow_quality"]),
                0, SHADOW_QUALITY_NAMES.size() - 1)
        gfx ["shadow_blur"] = clampf(float(gfx ["shadow_blur"]), 0.0, 10.0)
        gfx ["machine_distance"] = clampi(int(gfx ["machine_distance"]), 0, MACHINE_DISTANCE_METRES.size() - 1)


        if settings_readonly:
                for i in ua.size() - 1:
                        if ua [i] != "--gfx" or not "=" in ua [i + 1]:
                                continue
                        var kv:= ua [i + 1].split("=", true, 1)
                        if not gfx.has(kv [0]):
                                push_warning("Cfg: --gfx names no graphics key: %s" % kv [0])
                                continue
                        match typeof(gfx [kv [0]]):
                                TYPE_BOOL:
                                        gfx [kv [0]] = kv [1] == "true"
                                TYPE_INT:
                                        gfx [kv [0]] = int(kv [1])
                                _:
                                        gfx [kv [0]] = float(kv [1])
                        print("[gfx] %s = %s" % [kv [0], gfx [kv [0]]])


        sync_msaa_pipelines()


        _apply_display(not OS.has_feature("editor"))
        _unfullscreen_harness()


const PLAY_FLAGS:= ["--shipped", "--cheat"]


func _unfullscreen_harness() -> void:
        if not fullscreen:
                return
        var harness:= false
        for arg: String in OS.get_cmdline_user_args():
                if arg.begins_with("--") and not (arg in PLAY_FLAGS):
                        harness = true
                        break
        if not harness:
                return


        var want:= window_size
        var ua:= OS.get_cmdline_user_args()
        var wi:= ua.find("--window")
        if wi >= 0 and wi + 1 < ua.size():
                var parts:= ua [wi + 1].split("x")
                if parts.size() == 2 and parts [0].is_valid_int() and parts [1].is_valid_int():
                        want = Vector2i(int(parts [0]), int(parts [1]))
        _queue_display_state(false, want, true)


func set_mouse_sensitivity(value: float) -> void:
        mouse_sensitivity = clampf(value, MOUSE_SENS_MIN, MOUSE_SENS_MAX)
        save_settings()


func set_invert_look_x(on: bool) -> void:
        invert_look_x = on
        save_settings()


func set_invert_look_y(on: bool) -> void:
        invert_look_y = on
        save_settings()


func set_tool_mode(value: int) -> void:
        tool_mode = clampi(value, 0, TOOL_MODE_NAMES.size() - 1)
        save_settings()


func simple_tools() -> bool:
        return tool_mode == TOOL_SIMPLE


func set_prop_cap(value: int) -> void:
        var want: int = clampi(value, PROP_CAP_MIN, PROP_CAP_MAX)
        _prop_cap_user = want
        if want == prop_cap:
                return
        prop_cap = want
        save_settings()


func set_prop_decay(on: bool) -> void:
        if on == prop_decay:
                return
        prop_decay = on
        save_settings()


func set_belt_cap(value: int) -> void:
        var want: int = clampi(value, BELT_CAP_MIN, BELT_CAP_MAX)
        if want == belt_cap:
                return
        belt_cap = want
        save_settings()


func set_belt_decay(on: bool) -> void:
        if on == belt_decay:
                return
        belt_decay = on
        save_settings()


func set_auto_clean(on: bool) -> void:
        if on == auto_clean:
                return
        auto_clean = on
        save_settings()


func set_build_fx(on: bool) -> void:
        if on == build_fx:
                return
        build_fx = on
        save_settings()


func set_auto_clean_seconds(value: float) -> void:
        var want:= clampf(value, AUTO_CLEAN_SECONDS_MIN, AUTO_CLEAN_SECONDS_MAX)
        if is_equal_approx(want, auto_clean_seconds):
                return
        auto_clean_seconds = want
        save_settings()


func set_fullscreen(on: bool) -> void:
        if on == fullscreen:
                return
        fullscreen = on
        _apply_display()
        save_settings()


func window_sizes() -> Array [Vector2i]:
        var room:= DisplayServer.screen_get_usable_rect(
                DisplayServer.window_get_current_screen()).size
        var out: Array [Vector2i] = []
        for size: Vector2i in RESOLUTIONS:
                if size.x <= room.x and size.y <= room.y:
                        out.append(size)
        if not window_size in out:
                out.append(window_size)
                out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
        return out


func set_window_size(size: Vector2i) -> void:
        if size == window_size:
                return
        window_size = size
        _apply_display()
        save_settings()


func set_no_hud(on: bool) -> void:
        if on == no_hud:
                return
        no_hud = on
        no_hud_changed.emit(on)


func set_show_missions(on: bool) -> void:
        if on == show_missions:
                return
        show_missions = on
        show_missions_changed.emit(on)
        save_settings()


func set_show_tips(on: bool) -> void:
        if on == show_tips:
                return
        show_tips = on
        save_settings()


func set_hay_readout(mode: int) -> void:
        var want: int = clampi(mode, 0, HAY_READOUT_NAMES.size() - 1)
        if want == hay_readout:
                return
        hay_readout = want
        hay_readout_changed.emit(want)
        save_settings()


func set_show_hay_rate(on: bool) -> void:
        if on == show_hay_rate:
                return
        show_hay_rate = on
        show_hay_rate_changed.emit(on)
        save_settings()


func set_smooth_camera(on: bool) -> void:
        smooth_camera = on
        save_settings()


func set_smooth_camera_amount(value: float) -> void:
        smooth_camera_amount = clampf(value, 0.0, 1.0)
        save_settings()


func set_vsync(on: bool) -> void:
        vsync = on
        _apply_display()
        save_settings()


func set_max_fps(cap: int) -> void:
        max_fps = cap if FPS_CAPS.has(cap) else 0
        Engine.max_fps = max_fps
        save_settings()


func set_quality(level: Quality) -> void:
        if level == quality:
                return
        apply_quality(level)
        save_settings()


func reset_controls() -> void:
        mouse_sensitivity = MOUSE_SENS_DEFAULT
        invert_look_x = false
        invert_look_y = false
        tool_mode = TOOL_SIMPLE
        save_settings()


func reset_display() -> void:
        fullscreen = FULLSCREEN_DEFAULT
        vsync = VSYNC_DEFAULT
        max_fps = MAX_FPS_DEFAULT
        window_size = WINDOW_SIZE_DEFAULT
        smooth_camera = SMOOTH_CAMERA_DEFAULT
        smooth_camera_amount = SMOOTH_CAMERA_AMOUNT_DEFAULT
        tech_text_scale = TECH_TEXT_SCALE_DEFAULT

        hud_style_changed.emit()
        set_renderer(default_renderer(), false)
        set_render_thread(RENDER_THREAD_DEFAULT)


        _gfx_user.clear()


        apply_quality(QUALITY_DEFAULT)
        _apply_display()
        save_settings()


func reset_hud() -> void:
        no_hud = NO_HUD_DEFAULT
        hud_scale = HUD_SCALE_DEFAULT
        show_hotkey_bar = SHOW_HOTKEY_BAR_DEFAULT
        show_control_hints = SHOW_CONTROL_HINTS_DEFAULT
        teach_hints = TEACH_HINTS_DEFAULT
        catalog_grid = CATALOG_GRID_DEFAULT
        catalog_recent_first = CATALOG_RECENT_FIRST_DEFAULT
        crosshair_style = CROSSHAIR_STYLE_DEFAULT
        crosshair_size = CROSSHAIR_SIZE_DEFAULT
        crosshair_opacity = CROSSHAIR_OPACITY_DEFAULT
        crosshair_colour = CROSSHAIR_WHITE
        no_hud_changed.emit(no_hud)
        hud_style_changed.emit()
        save_settings()


func reset_gameplay() -> void:


        _prop_cap_user = null
        prop_cap = authored_prop_cap()
        prop_decay = PROP_DECAY_DEFAULT
        belt_cap = BELT_CAP_DEFAULT
        belt_decay = BELT_DECAY_DEFAULT
        auto_clean = AUTO_CLEAN_DEFAULT
        auto_clean_seconds = AUTO_CLEAN_SECONDS_DEFAULT
        build_fx = BUILD_FX_DEFAULT
        show_missions = SHOW_MISSIONS_DEFAULT
        show_tips = SHOW_TIPS_DEFAULT
        hay_readout = HAY_READOUT_DEFAULT
        show_hay_rate = SHOW_HAY_RATE_DEFAULT
        show_missions_changed.emit(show_missions)
        hay_readout_changed.emit(hay_readout)
        show_hay_rate_changed.emit(show_hay_rate)
        save_settings()


func _apply_display(resize: bool = true) -> void:
        _queue_display_state(fullscreen, window_size, resize)


func _queue_display_state(on: bool, size: Vector2i, resize: bool) -> void:
        if _display_closing:
                return
        _display_target_fullscreen = on
        _display_target_size = size
        if _display_pending:
                _display_target_resize = _display_target_resize or resize
        else:
                _display_target_resize = resize
        _display_serial += 1
        var start:= not _display_pending and not _display_running
        _display_pending = true
        if start:
                _drain_display_changes.call_deferred()


func _drain_display_changes() -> void:
        if _display_running or _display_closing or not is_inside_tree():
                return
        _display_running = true
        while _display_pending and not _display_closing and is_inside_tree():
                _display_pending = false
                var serial:= _display_serial
                var want_fullscreen:= _display_target_fullscreen
                var want_size:= _display_target_size
                var resize:= _display_target_resize
                _display_target_resize = false

                DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
                Engine.max_fps = max_fps

                var want_mode:= DisplayServer.WINDOW_MODE_FULLSCREEN if want_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
                var mode_changed:= DisplayServer.window_get_mode() != want_mode
                if mode_changed:
                        DisplayServer.window_set_mode(want_mode)
                        for _frame in DISPLAY_SETTLE_FRAMES:
                                if _display_closing or not is_inside_tree():
                                        break
                                await get_tree().process_frame
                if _display_closing or not is_inside_tree():
                        break
                if serial != _display_serial:
                        continue

                if resize and not want_fullscreen:
                        var size_changed:= DisplayServer.window_get_size() != want_size
                        if size_changed:
                                DisplayServer.window_set_size(want_size)
                                for _frame in DISPLAY_SETTLE_FRAMES:
                                        if _display_closing or not is_inside_tree():
                                                break
                                        await get_tree().process_frame
                        if _display_closing or not is_inside_tree():
                                break
                        if serial != _display_serial:
                                continue
                        if mode_changed or size_changed:
                                var screen:= DisplayServer.window_get_current_screen()
                                var room:= DisplayServer.screen_get_usable_rect(screen)
                                DisplayServer.window_set_position(
                                        room.position + (room.size - want_size) / 2)
        _display_running = false


func wait_for_display() -> void:
        while (_display_pending or _display_running) and not _display_closing:
                await get_tree().process_frame


func _stop_display_changes() -> void:
        _display_closing = true
        _display_pending = false


func _apply_ui_scale() -> void:
        var root:= get_tree().root
        var s:= maxf(1.0, float(root.size.y) / UI_DESIGN_HEIGHT)
        ui_scale = s
        if is_equal_approx(root.content_scale_factor, s):
                return
        root.content_scale_factor = s


const LOCALES:= [
        { "code": "", "name": "System" },
        { "code": "en", "name": "English" },
        { "code": "de", "name": "Deutsch" },
        { "code": "fr", "name": "Français" },
        { "code": "es", "name": "Español" },
        { "code": "pt", "name": "Português (Brasil)", "card": "Português" },
        { "code": "pl", "name": "Polski" },
        { "code": "cs", "name": "Čeština" },
        { "code": "ru", "name": "Русский" },
        { "code": "tr", "name": "Türkçe" },
        { "code": "zh", "name": "简体中文" },
        { "code": "ja", "name": "日本語" },
        { "code": "ko", "name": "한국어" },
]


var locale:= ""


var locale_asked:= false


var menu_static:= -1


var igpu_checked:= false


func integrated_gpu() -> bool:
        return RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU


func menu_backdrop_static() -> bool:
        if menu_static >= 0:
                return menu_static == 1
        return quality <= Quality.MEDIUM


var _running_locale:= ""


static func lower_in_english(text: String) -> String:
        var lang:= TranslationServer.get_locale()
        if lang.begins_with("tr"):
                return _turkish_lower(text)
        for code: String in ["en", "es", "pl", "fr", "cs", "ru", "pt"]:
                if lang.begins_with(code):
                        return text.to_lower()
        return text


static func upper(text: String) -> String:
        if TranslationServer.get_locale().begins_with("tr"):
                return text.replace("i", "İ").to_upper()
        return text.to_upper()


static func percent(number: String) -> String:
        if TranslationServer.get_locale().begins_with("tr"):
                return "%" + number
        return number + "%"


static func _turkish_lower(text: String) -> String:
        return text.replace("I", "ı").replace("İ", "i").to_lower()


func apply_locale() -> void:
        _running_locale = locale
        TranslationServer.set_locale(OS.get_locale() if locale == "" else locale)


        UiFont.relocale()


func choose_locale(code: String) -> bool:
        for entry: Dictionary in LOCALES:
                if entry ["code"] == code:
                        locale = code
                        save_settings()
                        return true
        return false


func running_locale() -> String:
        return _running_locale


func locale_pending() -> bool:
        return _language_of(locale) != _language_of(_running_locale)


func locale_name(code: String) -> String:
        var lang:= _language_of(code)
        for entry: Dictionary in LOCALES:
                if entry ["code"] == lang:
                        return str(entry ["name"])
        return str(LOCALES [0] ["name"])


static func _language_of(code: String) -> String:
        return OS.get_locale_language() if code == "" else code.split("_") [0]


func set_locale(code: String) -> void:
        for entry: Dictionary in LOCALES:
                if entry ["code"] == code:
                        locale = code
                        apply_locale()


                        UiFont.relocale()


                        BuildCatalog.invalidate()
                        ItemDb.invalidate()
                        TechTree.invalidate()
                        save_settings()
                        return


var settings_readonly:= false


func save_settings() -> void:
        if settings_readonly:
                return
        var cf:= ConfigFile.new()
        cf.set_value("game", "mouse_sensitivity", mouse_sensitivity)
        cf.set_value("game", "invert_look_x", invert_look_x)
        cf.set_value("game", "invert_look_y", invert_look_y)
        cf.set_value("game", "show_missions", show_missions)
        cf.set_value("game", "show_tips", show_tips)
        cf.set_value("game", "hay_readout", hay_readout)
        cf.set_value("game", "show_hay_rate", show_hay_rate)
        cf.set_value("game", "tool_mode", tool_mode)
        cf.set_value("game", "locale", locale)
        cf.set_value("game", "locale_asked", locale_asked)
        cf.set_value("display", "menu_static", menu_static)
        cf.set_value("display", "igpu_checked", igpu_checked)
        cf.set_value("display", "quality", int(quality))
        cf.set_value("display", "fullscreen", fullscreen)
        cf.set_value("display", "vsync", vsync)
        cf.set_value("display", "max_fps", max_fps)
        cf.set_value("display", "window_size", window_size)


        cf.set_value("display", "smooth_camera", smooth_camera)
        cf.set_value("display", "smooth_camera_amount", smooth_camera_amount)
        cf.set_value("display", "renderer", renderer)
        cf.set_value("display", "renderer_picked", renderer_picked)
        cf.set_value("display", "render_thread", int(render_thread))


        if _prop_cap_user != null:
                cf.set_value("yard", "prop_cap", prop_cap)
        cf.set_value("yard", "prop_decay", prop_decay)
        cf.set_value("yard", "belt_cap", belt_cap)
        cf.set_value("yard", "belt_cap_rev", BELT_CAP_REV)
        cf.set_value("yard", "belt_decay", belt_decay)
        cf.set_value("yard", "auto_clean", auto_clean)
        cf.set_value("yard", "auto_clean_seconds", auto_clean_seconds)
        cf.set_value("yard", "build_fx", build_fx)
        cf.set_value("hud", "hud_scale", hud_scale)
        cf.set_value("hud", "tech_text_scale", tech_text_scale)
        cf.set_value("hud", "crosshair_style", crosshair_style)
        cf.set_value("hud", "crosshair_size", crosshair_size)
        cf.set_value("hud", "crosshair_opacity", crosshair_opacity)
        cf.set_value("hud", "crosshair_colour", crosshair_colour)
        cf.set_value("hud", "show_hotkey_bar", show_hotkey_bar)
        cf.set_value("hud", "show_control_hints", show_control_hints)
        cf.set_value("hud", "teach_hints", teach_hints)
        cf.set_value("hud", "plate_dark", plate_dark)
        cf.set_value("hud", "shop_dark", shop_dark)
        cf.set_value("hud", "keys_used", PackedStringArray(keys_used.keys()))
        cf.set_value("hud", "builds_placed", PackedStringArray(builds_placed.keys()))
        cf.set_value("hud", "techs_seen", PackedStringArray(techs_seen.keys()))
        cf.set_value("hud", "machines_seen", PackedStringArray(machines_seen.keys()))
        cf.set_value("hud", "nudges_given", PackedStringArray(nudges_given.keys()))
        cf.set_value("hud", "catalog_grid", catalog_grid)
        cf.set_value("hud", "t_splitter_port_r", t_splitter_port_r)
        cf.set_value("hud", "catalog_recent_first", catalog_recent_first)


        for key: String in _gfx_user:
                cf.set_value("graphics", key, _gfx_user [key])
        cf.save(SETTINGS_PATH)


func load_settings() -> void:
        var cf:= ConfigFile.new()
        if cf.load(SETTINGS_PATH) != OK:
                return
        mouse_sensitivity = clampf(float(cf.get_value("game", "mouse_sensitivity", mouse_sensitivity)),
                MOUSE_SENS_MIN, MOUSE_SENS_MAX)
        invert_look_x = bool(cf.get_value("game", "invert_look_x", invert_look_x))
        invert_look_y = bool(cf.get_value("game", "invert_look_y", invert_look_y))
        show_missions = bool(cf.get_value("game", "show_missions", show_missions))
        show_tips = bool(cf.get_value("game", "show_tips", show_tips))


        hay_readout = clampi(int(cf.get_value("game", "hay_readout", hay_readout)),
                0, HAY_READOUT_NAMES.size() - 1)
        show_hay_rate = bool(cf.get_value("game", "show_hay_rate", show_hay_rate))


        tool_mode = clampi(int(cf.get_value("game", "tool_mode", tool_mode)),
                0, TOOL_MODE_NAMES.size() - 1)


        var saved_locale:= str(cf.get_value("game", "locale", locale))
        for entry: Dictionary in LOCALES:
                if entry ["code"] == saved_locale:
                        locale = saved_locale
                        break


        locale_asked = bool(cf.get_value("game", "locale_asked", true))
        menu_static = clampi(int(cf.get_value("display", "menu_static", menu_static)), -1, 1)
        igpu_checked = bool(cf.get_value("display", "igpu_checked", false))


        var saved_level:= int(cf.get_value("display", "quality", int(quality)))
        for level: Quality in Quality.values():
                if int(level) == saved_level:
                        quality = level
                        break
        fullscreen = bool(cf.get_value("display", "fullscreen", fullscreen))
        vsync = bool(cf.get_value("display", "vsync", vsync))

        var saved_cap:= int(cf.get_value("display", "max_fps", max_fps))
        max_fps = saved_cap if FPS_CAPS.has(saved_cap) else 0


        var saved_size:= Vector2i(cf.get_value("display", "window_size", window_size))
        window_size = Vector2i(maxi(saved_size.x, 800), maxi(saved_size.y, 450))


        smooth_camera = bool(cf.get_value("display", "smooth_camera", smooth_camera))
        smooth_camera_amount = clampf(
                float(cf.get_value("display", "smooth_camera_amount", smooth_camera_amount)), 0.0, 1.0)
        var want:= str(cf.get_value("display", "renderer", renderer))
        if want in RENDERERS:
                renderer = want
        renderer_picked = bool(cf.get_value("display", "renderer_picked", false))
        render_thread = clampi(int(cf.get_value("display", "render_thread", render_thread)),
                0, RenderThread.size() - 1) as RenderThread


        if cf.has_section_key("yard", "prop_cap"):
                _prop_cap_file = clampi(int(cf.get_value("yard", "prop_cap", prop_cap)),
                        PROP_CAP_MIN, PROP_CAP_MAX)
        prop_decay = bool(cf.get_value("yard", "prop_decay", prop_decay))


        belt_cap = clampi(int(cf.get_value("yard", "belt_cap", belt_cap)),
                BELT_CAP_MIN, BELT_CAP_MAX)


        var belt_rev:= clampi(int(cf.get_value("yard", "belt_cap_rev", 1)), 1, BELT_CAP_REV)
        if belt_rev < BELT_CAP_REV and belt_cap == BELT_CAP_OLD_DEFAULTS [belt_rev - 1]:
                belt_cap = BELT_CAP_DEFAULT
        belt_decay = bool(cf.get_value("yard", "belt_decay", belt_decay))
        auto_clean = bool(cf.get_value("yard", "auto_clean", auto_clean))

        auto_clean_seconds = clampf(
                float(cf.get_value("yard", "auto_clean_seconds", auto_clean_seconds)),
                AUTO_CLEAN_SECONDS_MIN, AUTO_CLEAN_SECONDS_MAX)
        build_fx = bool(cf.get_value("yard", "build_fx", build_fx))


        hud_scale = clampf(float(cf.get_value("hud", "hud_scale", hud_scale)),
                HUD_SCALE_MIN, HUD_SCALE_MAX)
        tech_text_scale = clampf(float(cf.get_value("hud", "tech_text_scale", tech_text_scale)),
                TECH_TEXT_SCALE_MIN, TECH_TEXT_SCALE_MAX)
        crosshair_style = clampi(int(cf.get_value("hud", "crosshair_style", crosshair_style)),
                0, CROSSHAIR_STYLE_NAMES.size() - 1)
        crosshair_size = clampf(float(cf.get_value("hud", "crosshair_size", crosshair_size)),
                CROSSHAIR_SIZE_MIN, CROSSHAIR_SIZE_MAX)
        crosshair_opacity = clampf(
                float(cf.get_value("hud", "crosshair_opacity", crosshair_opacity)),
                CROSSHAIR_OPACITY_MIN, 1.0)
        crosshair_colour = clampi(int(cf.get_value("hud", "crosshair_colour", crosshair_colour)),
                0, CROSSHAIR_COLOURS.size() - 1)
        show_hotkey_bar = bool(cf.get_value("hud", "show_hotkey_bar", show_hotkey_bar))
        show_control_hints = bool(cf.get_value("hud", "show_control_hints", show_control_hints))
        teach_hints = bool(cf.get_value("hud", "teach_hints", teach_hints))
        plate_dark = bool(cf.get_value("hud", "plate_dark", plate_dark))
        shop_dark = bool(cf.get_value("hud", "shop_dark", shop_dark))
        for pair: Array in [[keys_used, "keys_used"], [builds_placed, "builds_placed"],
                        [techs_seen, "techs_seen"], [machines_seen, "machines_seen"],
                        [nudges_given, "nudges_given"]]:
                var list: Dictionary = pair [0]
                list.clear()
                for a in PackedStringArray(cf.get_value("hud", pair [1], PackedStringArray())):
                        list [a] = true
        catalog_grid = bool(cf.get_value("hud", "catalog_grid", catalog_grid))
        t_splitter_port_r = T_SPLITTER_PORT_R_1M if is_equal_approx(float(cf.get_value("hud", "t_splitter_port_r", T_SPLITTER_PORT_R)),
                        T_SPLITTER_PORT_R_1M) else T_SPLITTER_PORT_R
        catalog_recent_first = bool(cf.get_value("hud", "catalog_recent_first",
                catalog_recent_first))


        _gfx_file.clear()
        if cf.has_section("graphics"):
                for key: String in cf.get_section_keys("graphics"):
                        _gfx_file [key] = cf.get_value("graphics", key)


func preset() -> Dictionary:
        if old_laptop:
                return _old_laptop_row(quality)
        return PRESETS [quality]


static var old_laptop: bool = "--oldlaptop" in OS.get_cmdline_user_args()

const OLD_LAPTOP_ROWS:= {
        Quality.POTATO: { "machine_distance": 2, "glow": true, "reflect_probe": true, "dust": true },
        Quality.LOW: { "machine_distance": 2 },
}

var _old_rows: Dictionary = { }


func _old_laptop_row(level: Quality) -> Dictionary:
        if not _old_rows.has(level):
                var row: Dictionary = (PRESETS [level] as Dictionary).duplicate()
                for key: String in ["aniso", "machine_lod", "crust_budget", "sign_distance"]:
                        row.erase(key)
                row.merge(OLD_LAPTOP_ROWS.get(level, { }), true)
                _old_rows [level] = row
        return _old_rows [level]


func apply_quality(level: Quality, rebuild: bool = true) -> void:
        quality = level
        var p: Dictionary = preset()
        crust_strands_per_cell = p ["strands_per_cell"]
        live_strand_budget = p ["live_budget"]
        crust_lod_near = p ["lod_near"]
        crust_lod_far = p ["lod_far"]
        crust_lod_min = p ["lod_min"]
        crust_shadow_distance = p ["shadow_distance"]
        yard_shadow_distance = p ["yard_shadow_distance"]
        detail_strands = int(p.get("detail_strands", 0))
        detail_radius = float(p.get("detail_radius", 0.0))
        detail_scale = 1.0
        crust_budget_scale = float(p.get("crust_budget", 1.0))
        cell_update_budget_usec = int(CELL_UPDATE_BUDGET_USEC * crust_budget_scale)
        chunk_rebuild_budget_usec = int(CHUNK_REBUILD_BUDGET_USEC * crust_budget_scale)
        relax_update_budget_usec = int(RELAX_UPDATE_BUDGET_USEC * crust_budget_scale)


        prop_cap = authored_prop_cap() if _prop_cap_user == null else clampi(int(_prop_cap_user), PROP_CAP_MIN, PROP_CAP_MAX)
        perf_scale = 1.0


        sync_gfx_to_preset()
        if rebuild:
                gfx_changed.emit()
                quality_changed.emit(level)


func effective_lod_near() -> float:
        return crust_lod_near * perf_scale


func effective_lod_far() -> float:
        return crust_lod_far * perf_scale


func _translated_size(spec: Dictionary) -> Dictionary:
        var out: Dictionary = { }
        out.merge(spec)
        var size_name:= str(spec.get("name", ""))
        if size_name != "":
                out ["name"] = tr(size_name)
        var blurb:= str(spec.get("blurb", ""))
        if blurb != "":
                out ["blurb"] = tr(blurb)
        return out


func listed_pile_sizes() -> Array [Dictionary]:
        var out: Array [Dictionary] = []
        for spec: Dictionary in PILE_SIZES:
                if bool(spec.get("listed", true)):
                        out.append(_translated_size(spec))
        return out


func pile_size_spec(id: String) -> Dictionary:
        for spec: Dictionary in PILE_SIZES:
                if str(spec.get("id", "")) == id:
                        return _translated_size(spec)
        for spec: Dictionary in PILE_SIZES:
                if str(spec.get("id", "")) == DEFAULT_PILE_SIZE:
                        return _translated_size(spec)
        return _translated_size(PILE_SIZES [0])


func apply_pile_size(id: String) -> void:
        var spec:= pile_size_spec(id)
        pile_size_id = str(spec.get("id", DEFAULT_PILE_SIZE))
        PILE_RADIUS = float(spec.get("radius", 10.0))
        PILE_HEIGHT = float(spec.get("height", 7.0))
        FIELD_EXTENT = float(spec.get("extent", 15.0))
        PILE_PREP_ANGLE_DEG = float(spec.get("prep_deg", 55.0))


func pile_start_tech() -> Dictionary:
        return pile_size_spec(pile_size_id).get("start_tech", { })


func pile_volume_estimate(spec: Dictionary) -> float:
        var r: float = float(spec.get("radius", 0.0))
        var h: float = float(spec.get("height", 0.0))
        return 2.267 * r * r * h


func yard_inner_for_pile() -> float:
        return maxf(17.0, settled_footprint() + 3.0)


func yard_seat_scale() -> float:
        return yard_inner_for_pile() / 17.0


func settled_footprint() -> float:
        var skirt: float = PILE_HEIGHT * 0.3 / maxf(0.2, tan(deg_to_rad(PILE_PREP_ANGLE_DEG)))
        return PILE_RADIUS * 1.075 + skirt


func field_verts() -> int:
        return int(round(FIELD_EXTENT * 2.0 / CELL)) + 1


func field_cells() -> int:
        return field_verts() - 1


func chunks_per_edge() -> int:
        return int(ceil(float(field_cells()) / float(CHUNK_CELLS)))
