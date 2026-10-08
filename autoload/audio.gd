extends Node


const BUS_MASTER:= "Master"
const BUS_MUSIC:= "Music"
const BUS_SFX:= "SFX"
const BUS_AMBIENCE:= "Ambience"
const BUS_UI:= "UI"

const SETTINGS_PATH:= "user://audio.cfg"


const POOL_3D:= 24
const POOL_2D:= 8


const POOL_LOOP:= 16


const SFX_MAX_DIST:= 26.0
const SFX_UNIT_SIZE:= 4.0

const MUSIC_FADE:= 3.5
const MUSIC_GAP:= 6.0
const AMBIENCE_FADE:= 2.5


const SFX_LIB:= {


	"dig": ["res://assets/audio/sfx/dig/dig_01.ogg", "res://assets/audio/sfx/dig/dig_02.ogg", "res://assets/audio/sfx/dig/dig_03.ogg", "res://assets/audio/sfx/dig/dig_04.ogg", "res://assets/audio/sfx/dig/dig_05.ogg", "res://assets/audio/sfx/dig/dig_06.ogg"],
	"hay_rustle": ["res://assets/audio/sfx/hay/rustle_01.ogg", "res://assets/audio/sfx/hay/rustle_02.ogg", "res://assets/audio/sfx/hay/rustle_03.ogg", "res://assets/audio/sfx/hay/rustle_04.ogg"],
	"hay_drop": ["res://assets/audio/sfx/hay/drop_01.ogg", "res://assets/audio/sfx/hay/drop_02.ogg", "res://assets/audio/sfx/hay/drop_03.ogg"],
	"hay_dump": ["res://assets/audio/sfx/hay/dump_01.ogg", "res://assets/audio/sfx/hay/dump_02.ogg", "res://assets/audio/sfx/hay/dump_03.ogg"],


	"hay_shift": ["res://assets/audio/sfx/hay/shift_01.ogg", "res://assets/audio/sfx/hay/shift_02.ogg", "res://assets/audio/sfx/hay/shift_03.ogg"],
	"pluck": ["res://assets/audio/sfx/hay/pluck.ogg"],


	"item_pick": ["res://assets/audio/sfx/item/pick_01.ogg", "res://assets/audio/sfx/item/pick_02.ogg", "res://assets/audio/sfx/item/pick_03.ogg"],
	"item_drop": ["res://assets/audio/sfx/item/drop_01.ogg", "res://assets/audio/sfx/item/drop_02.ogg", "res://assets/audio/sfx/item/drop_03.ogg"],


	"item_throw": ["res://assets/audio/sfx/item/throw_01.ogg", "res://assets/audio/sfx/item/throw_02.ogg", "res://assets/audio/sfx/item/throw_03.ogg"],


	"tool_clang": ["res://assets/audio/sfx/tool/clang_01.ogg", "res://assets/audio/sfx/tool/clang_02.ogg", "res://assets/audio/sfx/tool/clang_03.ogg", "res://assets/audio/sfx/tool/clang_04.ogg"],
	"item_clatter": ["res://assets/audio/sfx/item/clatter_01.ogg", "res://assets/audio/sfx/item/clatter_02.ogg", "res://assets/audio/sfx/item/clatter_03.ogg"],


	"bale_land": ["res://assets/audio/sfx/hay/bale_land_01.ogg", "res://assets/audio/sfx/hay/bale_land_02.ogg", "res://assets/audio/sfx/hay/bale_land_03.ogg"],
	"brick_land": ["res://assets/audio/sfx/item/block_01.ogg", "res://assets/audio/sfx/item/block_02.ogg", "res://assets/audio/sfx/item/block_03.ogg"],
	"plastic_drop": ["res://assets/audio/sfx/item/plastic_01.ogg", "res://assets/audio/sfx/item/plastic_02.ogg", "res://assets/audio/sfx/item/plastic_03.ogg"],


	"paper_tear": ["res://assets/audio/sfx/item/tear_01.ogg", "res://assets/audio/sfx/item/tear_02.ogg", "res://assets/audio/sfx/item/tear_03.ogg", "res://assets/audio/sfx/item/tear_04.ogg"],


	"wad_land": ["res://assets/audio/sfx/hay/dump_01.ogg", "res://assets/audio/sfx/hay/dump_02.ogg", "res://assets/audio/sfx/hay/dump_03.ogg"],


	"hay_place": ["res://assets/audio/sfx/hay/place_01.ogg", "res://assets/audio/sfx/hay/place_02.ogg"],
	"hay_pick": ["res://assets/audio/sfx/hay/pick_01.ogg", "res://assets/audio/sfx/hay/pick_02.ogg", "res://assets/audio/sfx/hay/pick_03.ogg", "res://assets/audio/sfx/hay/pick_04.ogg"],
	"broom_sweep": ["res://assets/audio/sfx/tool/broom_01.ogg", "res://assets/audio/sfx/tool/broom_02.ogg", "res://assets/audio/sfx/tool/broom_03.ogg", "res://assets/audio/sfx/tool/broom_04.ogg"],


	"arm_cycle": ["res://assets/audio/sfx/machine/arm_cycle.mp3"],
	"arm_claw": ["res://assets/audio/sfx/machine/claw_01.ogg", "res://assets/audio/sfx/machine/claw_02.ogg"],
	"arm_hiss": ["res://assets/audio/sfx/machine/hiss_01.ogg"],


	"rake_chunk": ["res://assets/audio/sfx/machine/rake_chunk_01.ogg", "res://assets/audio/sfx/machine/rake_chunk_02.ogg"],
	"rake_clack": ["res://assets/audio/sfx/machine/rake_clack_01.ogg", "res://assets/audio/sfx/machine/rake_clack_02.ogg"],
	"rake_throw": ["res://assets/audio/sfx/machine/rake_throw_01.ogg", "res://assets/audio/sfx/machine/rake_throw_02.ogg"],


	"machine_feed": ["res://assets/audio/sfx/hay/rustle_01.ogg", "res://assets/audio/sfx/hay/rustle_02.ogg", "res://assets/audio/sfx/hay/rustle_03.ogg", "res://assets/audio/sfx/hay/rustle_04.ogg"],
	"machine_thud": ["res://assets/audio/sfx/hay/dump_01.ogg", "res://assets/audio/sfx/hay/dump_02.ogg", "res://assets/audio/sfx/hay/dump_03.ogg"],
	"machine_vent": ["res://assets/audio/sfx/machine/hiss_01.ogg"],
	"machine_clunk": ["res://assets/audio/sfx/build/place_metal.ogg"],


	"pump_stroke": ["res://assets/audio/sfx/machine/pump_stroke_01.ogg", "res://assets/audio/sfx/machine/pump_stroke_02.ogg", "res://assets/audio/sfx/machine/pump_stroke_03.ogg"],


	"launcher_fire": ["res://assets/audio/sfx/machine/launcher_fire.ogg"],
	"launcher_stop": ["res://assets/audio/sfx/machine/launcher_stop.ogg"],


	"radar_stop": ["res://assets/audio/sfx/machine/radar_stop.ogg"],


	"lighter_open": ["res://assets/audio/sfx/tool/lighter_open.ogg"],
	"lighter_close": ["res://assets/audio/sfx/tool/lighter_close.ogg"],
	"lighter_strike": ["res://assets/audio/sfx/tool/lighter_strike.ogg"],


	"fire_catch": ["res://assets/audio/sfx/hay/fire_catch.ogg"],


	"jetpack_start": ["res://assets/audio/sfx/machine/jetpack_start.ogg"],
	"jetpack_stop": ["res://assets/audio/sfx/machine/jetpack_stop.ogg"],


	"jetpack_refuel": ["res://assets/audio/sfx/item/jetpack_refuel.ogg"],


	"truck_brake": ["res://assets/audio/sfx/truck/brake.ogg"],
	"truck_release": ["res://assets/audio/sfx/truck/release.ogg"],
	"truck_gate_down": ["res://assets/audio/sfx/truck/gate_down.ogg"],
	"truck_gate_up": ["res://assets/audio/sfx/truck/gate_up.ogg"],
	"cabinet_open": ["res://assets/audio/sfx/wood/cabinet_open.ogg"],
	"cabinet_close": ["res://assets/audio/sfx/wood/cabinet_close.ogg"],


	"clock_tick": ["res://assets/audio/sfx/clock/tick_01.ogg", "res://assets/audio/sfx/clock/tick_02.ogg", "res://assets/audio/sfx/clock/tick_03.ogg", "res://assets/audio/sfx/clock/tick_04.ogg"],
	"clock_tock": ["res://assets/audio/sfx/clock/tock_01.ogg", "res://assets/audio/sfx/clock/tock_02.ogg", "res://assets/audio/sfx/clock/tock_03.ogg", "res://assets/audio/sfx/clock/tock_04.ogg"],
	"crouch_down": ["res://assets/audio/sfx/foley/crouch_down_01.ogg", "res://assets/audio/sfx/foley/crouch_down_02.ogg"],
	"crouch_up": ["res://assets/audio/sfx/foley/crouch_up_01.ogg", "res://assets/audio/sfx/foley/crouch_up_02.ogg"],
	"step_soft": ["res://assets/audio/sfx/footstep/soft_01.ogg", "res://assets/audio/sfx/footstep/soft_02.ogg", "res://assets/audio/sfx/footstep/soft_03.ogg", "res://assets/audio/sfx/footstep/soft_04.ogg", "res://assets/audio/sfx/footstep/soft_05.ogg"],
	"step_hard": ["res://assets/audio/sfx/footstep/hard_01.ogg", "res://assets/audio/sfx/footstep/hard_02.ogg", "res://assets/audio/sfx/footstep/hard_03.ogg", "res://assets/audio/sfx/footstep/hard_04.ogg", "res://assets/audio/sfx/footstep/hard_05.ogg"],
	"build_place": ["res://assets/audio/sfx/build/place_01.ogg", "res://assets/audio/sfx/build/place_02.ogg", "res://assets/audio/sfx/build/place_03.ogg"],


	"build_place_metal": ["res://assets/audio/sfx/build/place_metal.ogg"],
	"build_place_big": ["res://assets/audio/sfx/build/place_big.ogg"],
	"build_demolish": ["res://assets/audio/sfx/build/demolish_01.ogg", "res://assets/audio/sfx/build/demolish_02.ogg", "res://assets/audio/sfx/build/demolish_03.ogg"],


	"build_dismantle": ["res://assets/audio/sfx/build/dismantle.ogg"],
	"coins": ["res://assets/audio/sfx/money/coins_01.ogg", "res://assets/audio/sfx/money/coins_02.ogg"],


	"coin_charge": ["res://assets/audio/sfx/item/coin_charge.ogg"],


	"coin_eaten": ["res://assets/audio/sfx/item/coin_eaten.ogg"],
	"sell_register": ["res://assets/audio/sfx/money/cash_register.mp3"],


	"needle": ["res://assets/audio/sfx/needle/alert.ogg"],
	"needle_ting": ["res://assets/audio/sfx/needle/ting.ogg"],


	"needle_lost": ["res://assets/audio/sfx/needle/lost.ogg"],


	"needle_collect": ["res://assets/audio/sfx/needle/collect.ogg"],


	"door_open": ["res://assets/audio/sfx/door/open.mp3"],
	"door_slam": ["res://assets/audio/sfx/door/slam.mp3"],
}


const UI_LIB:= {


	"ui_click": ["res://assets/audio/sfx/ui/switch_click_01.ogg", "res://assets/audio/sfx/ui/switch_click_02.ogg", "res://assets/audio/sfx/ui/switch_click_03.ogg"],
	"ui_select": ["res://assets/audio/sfx/ui/switch_select_01.ogg", "res://assets/audio/sfx/ui/switch_select_02.ogg", "res://assets/audio/sfx/ui/switch_select_03.ogg"],
	"ui_toggle": ["res://assets/audio/sfx/ui/switch_toggle_01.ogg", "res://assets/audio/sfx/ui/switch_toggle_02.ogg"],
	"ui_hotbar": ["res://assets/audio/sfx/ui/hotbar_01.ogg", "res://assets/audio/sfx/ui/hotbar_02.ogg", "res://assets/audio/sfx/ui/hotbar_03.ogg"],
	"ui_back": ["res://assets/audio/sfx/ui/switch_back_01.ogg", "res://assets/audio/sfx/ui/switch_back_02.ogg"],


	"ui_open": ["res://assets/audio/sfx/ui/open.ogg"],
	"ui_close": ["res://assets/audio/sfx/ui/switch_close_01.ogg", "res://assets/audio/sfx/ui/switch_close_02.ogg"],
	"ui_tick": ["res://assets/audio/sfx/ui/switch_tick_01.ogg", "res://assets/audio/sfx/ui/switch_tick_02.ogg", "res://assets/audio/sfx/ui/switch_tick_03.ogg"],
	"ui_drop": ["res://assets/audio/sfx/ui/drop.ogg"],
	"ui_error": ["res://assets/audio/sfx/ui/error.ogg"],


	"needle_reveal": ["res://assets/audio/sfx/ui/sparkle_woosh.ogg"],


	"chest_reveal": ["res://assets/audio/sfx/chest/reveal.ogg"],

	"chest_pedal": ["res://assets/audio/sfx/chest/pedal.ogg"],


	"chest_knock": ["res://assets/audio/sfx/chest/knock_01.ogg", "res://assets/audio/sfx/chest/knock_02.ogg", "res://assets/audio/sfx/chest/knock_03.ogg"],
	"chest_open": ["res://assets/audio/sfx/chest/open.ogg"],
	"chest_tick": ["res://assets/audio/sfx/chest/tick_01.ogg", "res://assets/audio/sfx/chest/tick_02.ogg", "res://assets/audio/sfx/chest/tick_03.ogg"],


	"chest_tumble": ["res://assets/audio/sfx/chest/tumble.ogg"],


	"chest_spin": ["res://assets/audio/sfx/chest/spin.ogg"],


	"detector_tick": ["res://assets/audio/sfx/detector/tick_01.ogg", "res://assets/audio/sfx/detector/tick_02.ogg", "res://assets/audio/sfx/detector/tick_03.ogg", "res://assets/audio/sfx/detector/tick_04.ogg"],


	"detector_beep": ["res://assets/audio/sfx/detector/beep_01.ogg"],
	"build_confirm": ["res://assets/audio/sfx/build/confirm.ogg"],


	"tech_buy": ["res://assets/audio/sfx/ui/tech_buy.ogg"],


	"tech_current": ["res://assets/audio/sfx/ui/tech_current.ogg"],
	"build_denied": ["res://assets/audio/sfx/build/denied.ogg"],
	"build_ghost": ["res://assets/audio/sfx/build/ghost_move.ogg"],
}


const NOTE_LIB:= {
	"vibes": {
		71.0: "res://assets/audio/sfx/chest/notes/vibes_b4.ogg",
		74.0: "res://assets/audio/sfx/chest/notes/vibes_d5.ogg",
		77.0: "res://assets/audio/sfx/chest/notes/vibes_f5.ogg",
		81.0: "res://assets/audio/sfx/chest/notes/vibes_a5.ogg",
		84.0: "res://assets/audio/sfx/chest/notes/vibes_c6.ogg",
		88.0: "res://assets/audio/sfx/chest/notes/vibes_e6.ogg",
	},
	"glock": {
		91.12: "res://assets/audio/sfx/chest/notes/glock_g6.ogg",
		96.15: "res://assets/audio/sfx/chest/notes/glock_c7.ogg",
		103.16: "res://assets/audio/sfx/chest/notes/glock_g7.ogg",
		108.24: "res://assets/audio/sfx/chest/notes/glock_c8.ogg",
	},
}


const UI_LOOP_LIB:= {


	"chest_aura": "res://assets/audio/sfx/chest/aura_loop.ogg",
}


const LOOP_LIB:= {
	"belt": "res://assets/audio/sfx/machine/belt_roll.ogg",
	"motor_a": "res://assets/audio/sfx/machine/motor_a.ogg",
	"motor_b": "res://assets/audio/sfx/machine/motor_b.ogg",
	"scanner": "res://assets/audio/sfx/machine/scan_loop.ogg",


	"vac_motor": "res://assets/audio/sfx/machine/vac_loop.ogg",


	"drone": "res://assets/audio/sfx/machine/drone_fly.ogg",


	"rake_engine": "res://assets/audio/sfx/machine/rake_engine.ogg",


	"rake_drive": "res://assets/audio/sfx/machine/rake_drive.ogg",


	"generator": "res://assets/audio/sfx/machine/generator.ogg",


	"launcher_slew": "res://assets/audio/sfx/machine/launcher_slew.ogg",


	"radar_turn": "res://assets/audio/sfx/machine/radar_turn.ogg",


	"fire_crackle": "res://assets/audio/sfx/hay/fire_crackle.ogg",


	"jetpack_thrust": "res://assets/audio/sfx/machine/jetpack_thrust.ogg",


	"pulper_churn": "res://assets/audio/sfx/machine/pulper_churn.ogg",


	"water_flow": "res://assets/audio/sfx/machine/water_flow.ogg",


	"truck_engine": "res://assets/audio/sfx/truck/engine.ogg",


}


const AMB_OUTSIDE:= "res://assets/audio/ambience/countryside.ogg"
const AMB_INSIDE:= "res://assets/audio/ambience/room_tone_a.ogg"


const MUSIC_TRACKS:= [
	"res://assets/audio/music/at_home.ogg",
	"res://assets/audio/music/harvest_season.ogg",
	"res://assets/audio/music/minstrel_dance.ogg",
	"res://assets/audio/music/market_day.ogg",
	"res://assets/audio/music/rejoicing.ogg",
	"res://assets/audio/music/another_august.ogg",
	"res://assets/audio/music/beautiful_forest.ogg",
	"res://assets/audio/music/calm_loop.ogg",
	"res://assets/audio/music/calm_ambient.ogg",
]


const MIN_GAP:= {
	"dig": 0.09,
	"hay_rustle": 0.05,
	"hay_drop": 0.04,


	"hay_dump": 0.45,
	"hay_shift": 0.16,
	"pluck": 0.06,
	"item_pick": 0.08,
	"item_drop": 0.08,


	"tool_clang": 0.05,
	"item_clatter": 0.05,


	"bale_land": 0.05,
	"brick_land": 0.05,
	"plastic_drop": 0.05,


	"wad_land": 0.22,
	"hay_place": 0.12,
	"coins": 0.12,


	"chest_tick": 0.035,
	"hay_pick": 0.06,
	"broom_sweep": 0.07,
	"arm_claw": 0.05,
	"ui_hotbar": 0.03,


	"crouch_down": 0.18,
	"crouch_up": 0.18,


	"sell_register": 0.25,


	"needle": 1.7,


	"needle_lost": 1.0,


	"needle_collect": 0.05,


	"build_place_metal": 0.06,


	"build_place_big": 0.2,
	"build_dismantle": 0.12,


	"tech_buy": 0.3,


	"tech_current": 0.3,


	"machine_feed": 0.18,


	"machine_thud": 0.25,


	"machine_vent": 0.1,
	"machine_clunk": 0.06,


	"detector_tick": 0.035,
	"detector_beep": 0.035,
}
const MIN_GAP_DEFAULT:= 0.02


const PRIORITY:= {
	"sell_register": true,
	"coins": true,
	"needle": true,


	"needle_collect": true,
	"build_confirm": true,


	"build_place_big": true,


	"machine_vent": true,
}


const PITCH_JITTER:= {


	"detector_tick": 0.0,
	"detector_beep": 0.0,
	"dig": 0.14,
	"hay_rustle": 0.16,
	"hay_drop": 0.14,
	"hay_dump": 0.1,
	"hay_shift": 0.17,
	"step_soft": 0.12,
	"step_hard": 0.12,
	"pluck": 0.18,
	"item_pick": 0.11,
	"item_drop": 0.11,
	"item_throw": 0.09,


	"tool_clang": 0.13,
	"item_clatter": 0.11,


	"bale_land": 0.1,
	"brick_land": 0.09,
	"plastic_drop": 0.12,
	"wad_land": 0.15,
	"coins": 0.07,
	"hay_pick": 0.15,
	"broom_sweep": 0.13,


	"arm_cycle": 0.02,
	"arm_claw": 0.1,
	"arm_hiss": 0.08,
	"ui_hotbar": 0.06,
	"crouch_down": 0.09,
	"crouch_up": 0.09,


	"sell_register": 0.02,
	"cabinet_open": 0.03,
	"cabinet_close": 0.03,


	"needle_collect": 0.02,


	"build_place_metal": 0.09,
	"build_dismantle": 0.1,


	"build_place_big": 0.03,

	"tech_buy": 0.02,


	"tech_current": 0.02,


	"machine_feed": 0.16,
	"machine_thud": 0.11,


	"machine_vent": 0.09,
	"machine_clunk": 0.1,


	"clock_tick": 0.0,
	"clock_tock": 0.0,

	"coin_eaten": 0.0,
	"chest_reveal": 0.0,
	"chest_pedal": 0.0,


	"chest_open": 0.0,

	"chest_spin": 0.0,
}

const PITCH_JITTER_DEFAULT:= 0.05

signal music_track_changed(title: String)

var _streams: Dictionary = { }
var _key_bus: Dictionary = { }
var _pool_3d: Array [AudioStreamPlayer3D] = []
var _pool_2d: Array [AudioStreamPlayer] = []
var _loops: Array [AudioStreamPlayer3D] = []
var _loop_free: Array [int] = []
var _last_play: Dictionary = { }
var _rng:= RandomNumberGenerator.new()
var _warned: Dictionary = { }


const POOL_NOTES:= 12
var _notes: Dictionary = { }
var _note_pool: Array [AudioStreamPlayer] = []
var _note_next:= 0


const POOL_CARD:= 6
var _card_pool: Array [AudioStreamPlayer] = []
var _card_next:= 0
var _ui_loops: Dictionary = { }
var _ui_loop_tweens: Dictionary = { }

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_front: AudioStreamPlayer
var _music_bag: Array = []
var _music_gap_left:= 0.0
var _music_pending:= ""
var _music_loading:= false
var _music_enabled:= false

var _duck: AudioEffectAmplify
var _duck_gain:= 1.0
var _duck_tween: Tween

var _amb_out: AudioStreamPlayer
var _amb_in: AudioStreamPlayer
var _indoor:= 0.0


const VOLUME_DEFAULT:= { "master": 0.9, "music": 0.55, "sfx": 1.0, "ambience": 0.8 }
var volume:= VOLUME_DEFAULT.duplicate()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_load_library()
	_build_pools()
	_build_music()
	_build_ambience()
	load_settings()


const DEMO_WITHHELD_SFX:= ["radar_stop", "lighter_open", "lighter_close", "lighter_strike"]


func _load_library() -> void:
	for key: String in SFX_LIB:

		if Cfg.DEMO and key in DEMO_WITHHELD_SFX:
			continue
		_streams [key] = _load_list(SFX_LIB [key])
		_key_bus [key] = BUS_SFX
	for key: String in UI_LIB:
		_streams [key] = _load_list(UI_LIB [key])
		_key_bus [key] = BUS_UI
	for inst: String in NOTE_LIB:
		var table: Array = []
		var notes: Dictionary = NOTE_LIB [inst]
		for pitch: float in notes:
			var got:= _load_list([notes [pitch]])
			if not got.is_empty():
				table.append([pitch, got [0]])
		_notes [inst] = table


func _load_list(paths: Array) -> Array:
	var out: Array = []
	for p: String in paths:
		var s: AudioStream = load(p)
		if s == null:
			push_warning("Audio: missing stream %s" % p)
			continue
		_set_loop(s, false)
		out.append(s)
	return out


func _set_loop(s: AudioStream, on: bool) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = on
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = on
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if on else AudioStreamWAV.LOOP_DISABLED


func _looped(path: String) -> AudioStream:
	var s: AudioStream = load(path)
	if s != null:
		_set_loop(s, true)
	return s


func _build_pools() -> void:
	for i in POOL_3D:
		var p:= AudioStreamPlayer3D.new()
		p.bus = BUS_SFX
		p.max_distance = SFX_MAX_DIST
		p.unit_size = SFX_UNIT_SIZE
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p2:= AudioStreamPlayer.new()
		p2.bus = BUS_UI
		add_child(p2)
		_pool_2d.append(p2)
	for i in POOL_LOOP:
		var l:= AudioStreamPlayer3D.new()
		l.bus = BUS_SFX
		l.max_distance = SFX_MAX_DIST
		l.unit_size = SFX_UNIT_SIZE
		l.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		l.volume_db = -80.0
		add_child(l)
		_loops.append(l)
		_loop_free.append(i)
	for i in POOL_NOTES:
		var n:= AudioStreamPlayer.new()
		n.bus = BUS_UI
		add_child(n)
		_note_pool.append(n)
	for i in POOL_CARD:
		var c:= AudioStreamPlayer.new()
		c.bus = BUS_SFX
		add_child(c)
		_card_pool.append(c)


func _resolve(key: String) -> AudioStream:
	var list: Variant = _streams.get(key)
	if list == null or (list as Array).is_empty():
		if not _warned.has(key):
			_warned [key] = true
			push_warning("Audio: unknown sound key '%s'" % key)
		return null
	var arr:= list as Array
	return arr [_rng.randi_range(0, arr.size() - 1)] as AudioStream


func _gate(key: String) -> bool:
	var now:= Time.get_ticks_msec()
	var gap: float = MIN_GAP.get(key, MIN_GAP_DEFAULT)
	var last: int = _last_play.get(key, -100000)
	if float(now - last) < gap * 1000.0:
		return false
	_last_play [key] = now
	return true


func _jitter(key: String) -> float:
	var j: float = PITCH_JITTER.get(key, PITCH_JITTER_DEFAULT)
	return 1.0 + _rng.randf_range(- j, j)


func play_3d(key: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var s:= _resolve(key)
	if s == null or not _gate(key):
		return
	var voice:= _free_3d()
	if voice == null:
		voice = _steal_3d() if PRIORITY.has(key) else null
	if voice == null:
		return
	voice.stream = s
	voice.global_position = pos
	voice.bus = _key_bus.get(key, BUS_SFX)
	voice.volume_db = vol_db
	voice.pitch_scale = clampf(_jitter(key) * pitch, 0.05, 4.0)
	voice.play()


func play_delayed(key: String, delay: float, vol_db: float = 0.0) -> void:
	if delay <= 0.0:
		play(key, vol_db)
		return


	var t:= get_tree().create_timer(delay, true, false, true)
	t.timeout.connect(play.bind(key, vol_db))


func play_3d_delayed(key: String, pos: Vector3, delay: float, vol_db: float = 0.0) -> void:
	if delay <= 0.0:
		play_3d(key, pos, vol_db)
		return
	var t:= get_tree().create_timer(delay, true, false, true)
	t.timeout.connect(play_3d.bind(key, pos, vol_db))


func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	return null


func _steal_3d() -> AudioStreamPlayer3D:
	var best: AudioStreamPlayer3D = null
	var best_done:= -1.0
	for p in _pool_3d:
		if p.stream == null:
			continue
		var length:= p.stream.get_length()


		var done:= p.get_playback_position() / length if length > 0.0 else 0.0
		if done > best_done:
			best_done = done
			best = p
	return best


func play(key: String, vol_db: float = 0.0) -> void:
	var s:= _resolve(key)
	if s == null or not _gate(key):
		return
	for p in _pool_2d:
		if p.playing:
			continue
		p.stream = s
		p.bus = _key_bus.get(key, BUS_UI)
		p.volume_db = vol_db
		p.pitch_scale = _jitter(key)
		p.play()
		return


func play_card(key: String, vol_db: float = 0.0) -> void:
	var s:= _resolve(key)
	if s == null or not _gate(key):
		return
	var p: AudioStreamPlayer = null
	for c in _card_pool:
		if not c.playing:
			p = c
			break
	if p == null:
		p = _card_pool [_card_next]
		_card_next = (_card_next + 1) % _card_pool.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = _jitter(key)
	p.play()


func stop_card(fade: float = 0.12) -> void:
	for p in _card_pool:
		if not p.playing:
			continue
		var tw:= create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade)
		tw.tween_callback(p.stop)


func play_held(key: String, vol_db: float = 0.0) -> AudioStreamPlayer:
	var s:= _resolve(key)
	if s == null or not _gate(key):
		return null
	for p in _pool_2d:
		if p.playing:
			continue
		p.stream = s
		p.bus = _key_bus.get(key, BUS_UI)
		p.volume_db = vol_db
		p.pitch_scale = _jitter(key)
		p.play()
		return p
	return null


func stop_held(p: AudioStreamPlayer, key: String) -> void:
	if p == null or not p.playing:
		return
	var list: Variant = _streams.get(key)
	if list != null and (list as Array).has(p.stream):
		p.stop()


func play_pitched(key: String, pitch: float, vol_db: float = 0.0) -> void:
	var s:= _resolve(key)
	if s == null or not _gate(key):
		return
	for p in _pool_2d:
		if p.playing:
			continue
		p.stream = s
		p.bus = _key_bus.get(key, BUS_UI)
		p.volume_db = vol_db
		p.pitch_scale = clampf(pitch, 0.05, 4.0)
		p.play()
		return


func play_note(instrument: String, midi: float, vol_db: float = 0.0) -> void:
	var table: Array = _notes.get(instrument, [])
	if table.is_empty():
		if not _warned.has(instrument):
			_warned [instrument] = true
			push_warning("Audio: unknown instrument '%s'" % instrument)
		return
	var best: Array = table [0]
	for row: Array in table:
		if absf(float(row [0]) - midi) < absf(float(best [0]) - midi):
			best = row
	var p:= _note_pool [_note_next]
	_note_next = (_note_next + 1) % _note_pool.size()
	p.stream = best [1]
	p.volume_db = vol_db
	p.pitch_scale = pow(2.0, (midi - float(best [0])) / 12.0)
	p.play()


func ui_loop_start(key: String, vol_db: float = 0.0, fade: float = 1.0) -> void:
	var p: AudioStreamPlayer = _ui_loops.get(key)
	if p == null:
		if not UI_LOOP_LIB.has(key):
			push_warning("Audio: unknown UI loop '%s'" % key)
			return
		var s:= _looped(UI_LOOP_LIB [key])
		if s == null:
			return
		p = AudioStreamPlayer.new()
		p.bus = BUS_UI
		p.stream = s
		add_child(p)
		_ui_loops [key] = p
	if not p.playing:
		p.volume_db = -60.0
		p.play()
	_ui_loop_fade(key, p, vol_db, fade, false)


func ui_loop_stop(key: String, fade: float = 1.0) -> void:
	var p: AudioStreamPlayer = _ui_loops.get(key)
	if p == null or not p.playing:
		return
	_ui_loop_fade(key, p, -60.0, fade, true)


func _ui_loop_fade(key: String, p: AudioStreamPlayer, vol_db: float, fade: float,
		then_stop: bool) -> void:
	var old: Tween = _ui_loop_tweens.get(key)
	if old != null and old.is_valid():
		old.kill()
	if fade <= 0.0:
		p.volume_db = vol_db
		if then_stop:
			p.stop()
		return
	var tw:= create_tween()
	tw.tween_property(p, "volume_db", vol_db, fade)
	if then_stop:
		tw.tween_callback(p.stop)
	_ui_loop_tweens [key] = tw


func loop_acquire(key: String) -> int:
	if _loop_free.is_empty():
		return -1
	var path: Variant = LOOP_LIB.get(key)
	if path == null:
		push_warning("Audio: unknown loop key '%s'" % key)
		return -1
	var h: int = _loop_free.pop_back()
	var p:= _loops [h]
	p.stream = _looped(path as String)
	p.volume_db = -80.0
	p.pitch_scale = 1.0
	p.play()
	return h


func loop_update(handle: int, pos: Vector3, vol_db: float, pitch: float = 1.0) -> void:
	if handle < 0 or handle >= _loops.size():
		return
	var p:= _loops [handle]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch


func loop_release(handle: int) -> void:
	if handle < 0 or handle >= _loops.size() or _loop_free.has(handle):
		return
	_loops [handle].stop()
	_loop_free.append(handle)


func loops_available() -> int:
	return _loop_free.size()


func stop_world_sfx() -> void:
	for h in _loops.size():
		loop_release(h)
	for p in _pool_3d:
		p.stop()
	for p in _pool_2d:
		p.stop()


func _build_music() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = BUS_MUSIC
	_music_a.volume_db = -80.0
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = BUS_MUSIC
	_music_b.volume_db = -80.0
	add_child(_music_b)
	_music_front = _music_a
	var idx:= AudioServer.get_bus_index(BUS_MUSIC)
	if idx >= 0:
		_duck = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(idx, _duck)


func _refill_bag() -> void:
	_music_bag = MUSIC_TRACKS.duplicate()
	for i in range(_music_bag.size() - 1, 0, -1):
		var j:= _rng.randi_range(0, i)
		var t: String = _music_bag [i]
		_music_bag [i] = _music_bag [j]
		_music_bag [j] = t


func music_start() -> void:
	if _music_enabled:
		return
	_music_enabled = true
	_music_gap_left = 1.5


func music_stop(fade: float = MUSIC_FADE) -> void:
	_music_enabled = false
	_fade(_music_a, -80.0, fade)
	_fade(_music_b, -80.0, fade)


func music_next() -> void:
	if not _music_enabled:
		return
	_fade(_music_front, -80.0, 1.0)
	_music_pending = ""
	_music_gap_left = 1.2


func music_duck(gain: float = 0.32, fade: float = 0.4) -> void:
	_duck_to(clampf(gain, 0.0, 1.0), fade)


func music_unduck(fade: float = 1.5) -> void:
	_duck_to(1.0, fade)


func _duck_to(gain: float, fade: float) -> void:
	if _duck == null:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	if fade <= 0.0:
		_set_duck_gain(gain)
		return
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck_gain, _duck_gain, gain, fade)


func _set_duck_gain(gain: float) -> void:
	_duck_gain = gain
	_duck.volume_db = maxf(linear_to_db(gain), -80.0)


func _request_next_track() -> void:
	if _music_bag.is_empty():
		_refill_bag()
	_music_pending = _music_bag.pop_back()


	ResourceLoader.load_threaded_request(_music_pending, "AudioStream")
	_music_loading = true


func _poll_music_load() -> void:
	var st:= ResourceLoader.load_threaded_get_status(_music_pending)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	_music_loading = false
	if st != ResourceLoader.THREAD_LOAD_LOADED:
		push_warning("Audio: could not load track %s" % _music_pending)
		_music_pending = ""
		_music_gap_left = MUSIC_GAP
		return
	var stream: AudioStream = ResourceLoader.load_threaded_get(_music_pending)


	_set_loop(stream, false)
	var back: AudioStreamPlayer = _music_b if _music_front == _music_a else _music_a
	_fade(_music_front, -80.0, MUSIC_FADE)
	back.stream = stream
	back.volume_db = -80.0
	back.play()
	_fade(back, 0.0, MUSIC_FADE)
	_music_front = back
	music_track_changed.emit(_music_pending.get_file().get_basename())
	_music_pending = ""


func _process(delta: float) -> void:
	_tick_music(delta)


func _tick_music(delta: float) -> void:
	if not _music_enabled:
		return
	if _music_loading:
		_poll_music_load()
		return
	if _music_gap_left > 0.0:
		_music_gap_left -= delta
		if _music_gap_left <= 0.0:
			_request_next_track()
		return
	if not _music_front.playing:
		_music_gap_left = MUSIC_GAP
		return


	var s:= _music_front.stream
	if s == null:
		return
	var left:= s.get_length() - _music_front.get_playback_position()
	if left > 0.0 and left <= MUSIC_FADE:
		_music_gap_left = 0.001


func _build_ambience() -> void:
	_amb_out = AudioStreamPlayer.new()
	_amb_out.bus = BUS_AMBIENCE
	_amb_out.stream = _looped(AMB_OUTSIDE)
	_amb_out.volume_db = -80.0
	add_child(_amb_out)

	_amb_in = AudioStreamPlayer.new()
	_amb_in.bus = BUS_AMBIENCE
	_amb_in.stream = _looped(AMB_INSIDE)
	_amb_in.volume_db = -80.0
	add_child(_amb_in)


func ambience_start() -> void:
	if not _amb_out.playing:
		_amb_out.play()
	if not _amb_in.playing:
		_amb_in.play()
	_apply_indoor(AMBIENCE_FADE)


func set_indoor(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if absf(amount - _indoor) < 0.02:
		return
	_indoor = amount
	_apply_indoor(0.6)


func _apply_indoor(time: float) -> void:


	_fade(_amb_out, lerpf(0.0, -11.0, _indoor), time)
	_fade(_amb_in, lerpf(-80.0, -6.0, _indoor), time)


func _fade(p: AudioStreamPlayer, to_db: float, time: float) -> void:
	if p == null:
		return


	if time <= 0.0:
		p.volume_db = to_db
		if to_db <= -79.0:
			p.stop()
		return
	var tw:= create_tween()
	tw.tween_property(p, "volume_db", to_db, time)
	if to_db <= -79.0:
		tw.tween_callback(p.stop)


func set_volume(which: String, linear: float) -> void:
	if not volume.has(which):
		return
	volume [which] = clampf(linear, 0.0, 1.0)
	_apply_volume()
	save_settings()


func reset_volumes() -> void:
	volume = VOLUME_DEFAULT.duplicate()
	_apply_volume()
	save_settings()


func _apply_volume() -> void:
	_set_bus(BUS_MASTER, volume ["master"], 0.0)


	_set_bus(BUS_MUSIC, volume ["music"], -6.0)
	_set_bus(BUS_SFX, volume ["sfx"], 0.0)
	_set_bus(BUS_UI, volume ["sfx"], -3.0)
	_set_bus(BUS_AMBIENCE, volume ["ambience"], -4.0)


func _set_bus(bus_name: String, linear: float, trim_db: float) -> void:
	var idx:= AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return

	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear) + trim_db)


func save_settings() -> void:
	var cf:= ConfigFile.new()
	for k: String in volume:
		cf.set_value("audio", k, volume [k])
	cf.save(SETTINGS_PATH)


func load_settings() -> void:
	var cf:= ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k: String in volume.keys():
			volume [k] = clampf(float(cf.get_value("audio", k, volume [k])), 0.0, 1.0)
	_apply_volume()
