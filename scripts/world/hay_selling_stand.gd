class_name HaySellingStand
extends Node3D


const MODEL:= "res://assets/models/hay_selling_stand.glb"
const SELL_ANIM:= "SellCycle"


const SPEC:= "res://assets/models/hay_selling_stand_materials.json"
const SHADER:= "res://assets/stand_surface.gdshader"

const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"

const TEX_MAPS:= {
        "albedo": "diff", "normal": "nor_gl", "rough": "rough", "ao": "ao",
}

const N_CATCH:= "Trigger_CatchVolume"
const N_POPUP:= "Payout_Popup"
const N_BOARD_FACE:= "CB_F_Face"
const N_TILL_SCREEN:= "Reg_Screen"
const N_TILL_DIGITS:= "Reg_Digits"
const N_BELT_IN:= "Marker_BeltIn"
const N_BELT_OUT:= "Marker_BeltOut"


const N_SCALE_PLATE:= "Marker_ScalePlate"


const TILL_NODES:= ["Reg_Drawer", "Reg_Knob", "Reg_Bell"]


const WEIGH_NODES:= ["Scale_Platform", "Scale_Needle"]
const N_PLATE:= "Scale_Platform"
const N_NEEDLE:= "Scale_Needle"


const SCALE_MARKS:= [0, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]


const PLATE_SINK:= 0.31


const NEEDLE_SWEEP:= 296.0


const SACK_NOTCHES:= 10


const NOTCH_STRANDS:= 20.0


const SCALE_LCD_DIGIT_H:= 0.72


const NOTCH_TIME:= 0.35


const SACK_PATIENCE:= 5.0


const SACK_MODEL:= "res://assets/models/hay_sack.glb"
const N_SACK:= "HaySack"
const N_STAR:= "Star_Pop"
const SACK_FILL:= "Fill"


const SACK_LIFT:= 0.005


const WIND_UP:= 0.2


const HOLD_SQUASH:= 1.12


const FLY_UP:= 7.0


const FLY_DRIFT:= Vector3(0.55, 0.0, -0.7)


const PUNCH_KICK:= 1.9
const PUNCH_MAX:= 0.075
const PUNCH_STIFF:= 420.0
const PUNCH_DAMP:= 20.0


const SMOKE_SHADER:= "res://assets/smoke_column.gdshader"


const PUFF_R:= 0.52
const PUFF_H:= 0.55


const PUFF_LIFE:= 0.55


const PUFF_ALPHA:= 0.75


const PUFF_GATE:= 0.12
const PUFF_GATE_END:= 0.95

const PUFF_RISE:= 0.3
const KICK_DUST_MAX:= 40
const KICK_DUST_LIFE:= 0.85


const SACK_GROW:= 0.4


const WEIGH_STIFF:= 250.0
const WEIGH_DAMP:= 21.0


const ANIM_LIB:= "stand"
const MACHINE_ANIM:= "machine"
const TILL_ANIM:= "till"


const HIDE_PREFIXES:= ["Grass_Tuft", "Stone_", "Dirt_Patch", "Hay_Falling"]


const PRICE_TEXT_NODES:= ["CB_T1", "CB_T2", "CB_T3"]


const MOUTH_BACK:= 0.2


const MOUTH_REACH:= 1.45
const MOUTH_RISE:= 0.62
const MOUTH_DROP:= 0.52
const MOUTH_HALF_W:= 0.46


const BELT_KNEE_X:= -1.42
const BELT_DECK_Y:= 0.34
const BELT_KNEE_RADIUS:= 0.42
const BELT_INCLINE:= 0.29670597
const BELT_PATH_STEPS:= 8
const BELT_PATH_OVERLAP:= 0.08


const MODEL_BELT_PREFIXES:= ["Belt_Band", "Belt_Cleat_", "Conveyor_Frame",
        "Conveyor_Rollers", "Pulley_"]

const BELT_DRAW_KNEE_STEPS:= 16
const BELT_DRAW_SPAN:= 0.25


const BELT_LEG_X:= [-2.55, -1.05, 0.58]


const BELT_LOOP_DB:= -12.0
const BELT_LOOP_SILENT:= -80.0
const BELT_LOOP_RAMP:= 70.0


const POPUP_UP:= 1.15


const COIN_SPOUT_UP:= 0.14
const POPUP_RISE:= 0.8
const POPUP_LIFE:= 1.55


const POPUP_FONT:= 276
const POPUP_PIXEL:= 0.0010667


const POPUP_OUTLINE:= 66
const COL_PAY:= Color(1.0, 0.86, 0.34)
const COL_NEEDLE:= Color(0.8, 0.94, 1.0)


const COL_SCRAP:= Color(0.86, 0.36, 0.3)
const COL_TILL:= Color(1.0, 0.78, 0.3)


const COL_BEST:= Color(1.0, 0.76, 0.18)


const POPUP_CLOSE_RANGE:= 6.0

const POPUP_CLOSE_MIN:= 0.7
const POPUP_CLOSE_MAX:= 3.0

const BEST_LIFE:= 2.8
const BEST_FADE_AT:= 1.9

const BEST_MAX_WIDTH:= 0.42
const BEST_GLINT_SHADER:= preload("res://assets/best_glint.gdshader")


const COIN_MIN:= 4
const COIN_MAX:= 52
const COIN_REF:= 40.0


const COIN_POOL:= 8


const COIN_COOLDOWN:= 30.0


const COIN_BIG_COOLDOWN:= 30.0


const COIN_RANGE:= 12.0

const COIN_BIG_RATIO:= 3.0


const COIN_AVG_FLOOR:= 1.0

const COIN_AVG_WEIGHT:= 0.08


const COIN_BEST_MARGIN:= 1.1
const COIN_BEST_FLOOR:= 5.0

const POPUP_POOL:= 4


const COIN_RADIUS:= 0.016
const COIN_THICK:= 0.0055


const SPARK_MAX:= 40
const SPARK_LIFE:= 0.55


const MOTE_MAX:= 26
const MOTE_LIFE:= 2.2


const FLASH_RANGE:= 3.2
const FLASH_PEAK:= 4.4
const FLASH_IN:= 0.05
const FLASH_OUT:= 0.42


const PRICE_BOARD_TEXT_WIDTH:= 0.92
const PRICE_BOARD_PIXEL_SIZE:= 0.0028


const LEDGER_NOTE:= "Why can't we go\nbackwards for once?\nBackwards, really fast...\nJust put the pedal to the metal"


const LEDGER_RULE_0:= Vector3(-0.85, 1.1245, 1.17)
const LEDGER_RULE_PITCH:= 0.024
const LEDGER_RULES:= 7

const LEDGER_YAW:= -8.0


const LEDGER_TEXT_WIDTH:= 0.28


const LEDGER_EM:= 0.023


const LEDGER_FONT_PX:= 128

const LEDGER_LIFT:= 0.002


signal sold(strands: int, amount: float)

var live: LiveStrandManager


var props: PropManager

var _model: Node3D
var _anim: AnimationPlayer
var _anim_key:= ""


var _till_anim: AnimationPlayer
var _till_key:= ""
var _belt: BeltPath

var _belt_rubber: ShaderMaterial
var _belt_drum: ShaderMaterial


func intake_path() -> BeltPath:
        return _belt
var _payout_area: Area3D

var _sale_fx: SaleFx


var _coins: GPUParticles3D
var _sparks: GPUParticles3D
var _motes: GPUParticles3D


var _puff: MeshInstance3D
var _puff_rest:= Vector3.ZERO
var _puff_tween: Tween
var _kick_dust: GPUParticles3D


var _flash: OmniLight3D
var _flash_tween: Tween
var _till: Label3D

var _price_board: Label3D
var _popup_at:= Vector3.ZERO


var _coins_at:= Vector3.ZERO


var _coins_face:= Vector3.ZERO

var _coin_pool: Array [ExtraLifeCoin] = []
var _coins_out:= 0


var _coin_ready_at:= 0.0
var _big_ready_at:= 0.0

var _sale_avg:= 0.0

var coins_anywhere:= false

var _popups: Array [Label3D] = []
var _popup_tweens: Array [Tween] = []
var _popup_next:= 0


var _best: Label3D
var _best_white: Label3D
var _best_glints: Array [MeshInstance3D] = []
var _best_tween: Tween

var _belt_head:= Vector3(1.06, 1.08, 3.05)
var _belt_tail:= Vector3(-3.12, 0.34, 3.05)


var _scale_plate:= Vector3(1.66, 0.61, 3.05)


var _footprint:= Rect2()
var _footprint_known:= false


var _pending:= 0.0


var _pending_hay:= 0.0
var _batch_idle:= 0.0
var _batch_age:= 0.0


var _replay_wanted:= false


var _plate: Node3D
var _needle: Node3D
var _scale_lcd: SegmentReadout
var _scale_strands:= 0
var _scale_waiting:= 0
var _scale_angle:= 0.0
var _plate_rest:= Vector3.ZERO
var _needle_rest:= Quaternion.IDENTITY


var _needle_axis:= Vector3.BACK


var _weigh:= 0.0
var _weigh_vel:= 0.0


var _punch:= 0.0
var _punch_vel:= 0.0


var _sack: Node3D
var _sack_body: Node3D
var _sack_mesh: MeshInstance3D
var _sack_anim: AnimationPlayer
var _sack_fill:= -1
var _sack_rest:= Vector3.ZERO
var _sack_body_rest:= Transform3D.IDENTITY


var _flyer: SackFlyer


var _hold:= 0.0


var _hold_at:= 0.0

var _grow: Tween


var _notches:= 0
var _notch_queue:= 0
var _notch_clock:= 0.0


var _strand_bank:= 0.0

var _sack_idle:= 0.0


var _belt_voice:= -1
var _belt_gain:= BELT_LOOP_SILENT
var _belt_mid:= Vector3.ZERO

var _rng:= RandomNumberGenerator.new()


func _ready() -> void:
        _rng.randomize()
        CrashReport.note_doing("standbuild:model")
        _build_model()
        CrashReport.note_doing("standbuild:belt")
        _build_belt()
        CrashReport.note_doing("standbuild:payout")
        _build_payout_area()
        CrashReport.note_doing("standbuild:skin")
        _skin()
        CrashReport.note_doing("standbuild:dress")
        _dress()
        CrashReport.note_doing("standbuild:ledger")
        _build_ledger_note()
        CrashReport.note_doing("standbuild:price_board")
        _build_price_board()
        CrashReport.note_doing("standbuild:till")
        _build_till()
        CrashReport.note_doing("standbuild:coins")
        _build_coins()
        CrashReport.note_doing("standbuild:coin_pool")
        _build_coin_pool()

        CrashReport.note_doing("standbuild:sack")
        _build_sack()
        CrashReport.note_doing("standbuild:kick")
        _build_kick()

        CrashReport.note_doing("standbuild:sale_fx")
        _build_sale_fx()


        Tech.tech_changed.connect(_on_price_tech_changed)
        Tech.tech_reset.connect(_refresh_price_board)


func _build_model() -> void:
        var packed: PackedScene = load(MODEL)
        if packed == null:
                push_error("HaySellingStand: cannot load %s" % MODEL)
                return
        _model = packed.instantiate()
        _model.name = "Model"
        add_child(_model)

        for n in _model.find_children("*", "AnimationPlayer", true, false):
                _anim = n as AnimationPlayer
                break
        if _anim == null:
                push_warning("HaySellingStand: the model has no AnimationPlayer; the stand will still pay, but nothing will move")
                return


        _anim.playback_default_blend_time = 0.0
        _anim.speed_scale = Cfg.SELL_ANIM_SPEED
        _anim.animation_finished.connect(_on_cycle_finished)
        _anim_key = SELL_ANIM if _anim.has_animation(SELL_ANIM) else ""
        if _anim_key == "":
                var list:= _anim.get_animation_list()
                if list.size() > 0:
                        _anim_key = list [0]
                        push_warning("HaySellingStand: no '%s' animation, falling back to '%s'" % [SELL_ANIM, _anim_key])
        _split_till_animation()
        _bind_scale()


func _split_till_animation() -> void:
        if _anim == null or _anim_key == "":
                return
        var src:= _anim.get_animation(_anim_key)
        if src == null:
                return

        var till_tracks: Array [int] = []
        for i in src.get_track_count():
                var path:= src.track_get_path(i)
                var names:= path.get_name_count()
                if names > 0 and TILL_NODES.has(String(path.get_name(names - 1))):
                        till_tracks.append(i)
        if till_tracks.is_empty():
                push_warning("HaySellingStand: '%s' has no till tracks to split; the register will not open" % _anim_key)
                return


        var t0:= src.length
        for i in till_tracks:
                var keys:= src.track_get_key_count(i)
                if keys < 2:
                        continue
                var base: Variant = src.track_get_key_value(i, 0)
                for k in range(1, keys):
                        if not _same_key(base, src.track_get_key_value(i, k)):
                                t0 = minf(t0, src.track_get_key_time(i, k - 1))
                                break

        var till:= Animation.new()
        till.length = maxf(0.05, src.length - t0)
        for i in till_tracks:
                var t:= till.add_track(src.track_get_type(i))
                till.track_set_path(t, src.track_get_path(i))
                till.track_set_interpolation_type(t, src.track_get_interpolation_type(i))


                var rest: Variant = _sample_track(src, i, t0)
                if rest != null:
                        till.track_insert_key(t, 0.0, rest)
                for k in src.track_get_key_count(i):
                        var kt:= src.track_get_key_time(i, k)
                        if kt <= t0:
                                continue
                        till.track_insert_key(t, kt - t0, src.track_get_key_value(i, k))


        var weigh_tracks: Array [int] = []
        for i in src.get_track_count():
                var wp:= src.track_get_path(i)
                var wn:= wp.get_name_count()
                if wn > 0 and WEIGH_NODES.has(String(wp.get_name(wn - 1))):
                        weigh_tracks.append(i)
        _resolve_needle_axis(src, weigh_tracks)

        var machine:= src.duplicate(true) as Animation
        var doomed:= till_tracks.duplicate()
        doomed.append_array(weigh_tracks)
        doomed.sort()
        doomed.reverse()
        for i in doomed:
                machine.remove_track(i)

        var lib:= AnimationLibrary.new()
        lib.add_animation(MACHINE_ANIM, machine)
        _anim.add_animation_library(ANIM_LIB, lib)
        _anim_key = "%s/%s" % [ANIM_LIB, MACHINE_ANIM]

        var till_lib:= AnimationLibrary.new()
        till_lib.add_animation(TILL_ANIM, till)
        _till_anim = AnimationPlayer.new()
        _till_anim.name = "TillPlayer"


        _anim.get_parent().add_child(_till_anim)
        _till_anim.root_node = _anim.root_node
        _till_anim.playback_default_blend_time = 0.0
        _till_anim.speed_scale = Cfg.SELL_ANIM_SPEED
        _till_anim.add_animation_library(ANIM_LIB, till_lib)
        _till_key = "%s/%s" % [ANIM_LIB, TILL_ANIM]


func _same_key(a: Variant, b: Variant) -> bool:
        if a is Vector3 and b is Vector3:
                return (a as Vector3).is_equal_approx(b as Vector3)
        if a is Quaternion and b is Quaternion:
                return (a as Quaternion).is_equal_approx(b as Quaternion)
        if a is float and b is float:
                return is_equal_approx(a as float, b as float)
        return a == b


func _resolve_needle_axis(src: Animation, weigh_tracks: Array [int]) -> void:
        for i in weigh_tracks:
                var path:= src.track_get_path(i)
                if String(path.get_name(path.get_name_count() - 1)) != N_NEEDLE:
                        continue
                if src.track_get_type(i) != Animation.TYPE_ROTATION_3D:
                        continue
                var keys:= src.track_get_key_count(i)
                if keys < 2:
                        continue

                var axis:= Vector3.ZERO
                var run:= 0.0
                var peak:= 0.0
                var prev: Quaternion = src.track_get_key_value(i, 0)
                for k in range(1, keys):
                        var q: Quaternion = src.track_get_key_value(i, k)
                        var step:= q * prev.inverse()
                        prev = q
                        var a:= step.get_angle()


                        if a > PI:
                                a -= TAU
                        if absf(a) < 0.0005:
                                continue
                        var ax:= step.get_axis().normalized()
                        if not ax.is_finite():
                                continue
                        if axis == Vector3.ZERO:
                                axis = ax


                        run += a if ax.dot(axis) >= 0.0 else - a
                        peak = maxf(peak, run)

                if axis == Vector3.ZERO:
                        continue
                _needle_axis = axis


                if absf(rad_to_deg(peak) - NEEDLE_SWEEP) > 30.0:
                        push_warning("HaySellingStand: the authored needle sweeps %.0f deg but NEEDLE_SWEEP is %.0f; check stand.py's NEEDLE_MAX"
                                % [rad_to_deg(peak), NEEDLE_SWEEP])
                return


func _bind_scale() -> void:
        if _model == null:
                return
        _plate = _model.find_child(N_PLATE, true, false) as Node3D
        _needle = _model.find_child(N_NEEDLE, true, false) as Node3D
        if _plate != null:
                _plate_rest = _plate.position
        if _needle != null:
                _needle_rest = _needle.quaternion
        var digits:= _model.find_child("Scale_LCD_Digits", true, false) as Node3D
        if digits != null:
                digits.visible = false
        var screen:= _model.find_child("Scale_LCD", true, false) as MeshInstance3D
        if screen != null and screen.mesh != null:
                _scale_lcd = _mount_scale_lcd(screen)
                _scale_lcd.show_text(scale_digits(_scale_strands))
        else:
                push_warning("HaySellingStand: the model has no Scale_LCD; the scale will not show a strand count")
        if _plate == null and _needle == null:
                push_warning("HaySellingStand: the model has no '%s' or '%s'; the scale will not read the load" % [N_PLATE, N_NEEDLE])


func _mount_scale_lcd(screen: MeshInstance3D) -> SegmentReadout:
        var box:= screen.mesh.get_aabb()
        var gx:= screen.global_transform
        var centre:= gx * box.get_center()
        var sides: Array [Vector3] = [gx.basis.x * box.size.x,
                gx.basis.y * box.size.y, gx.basis.z * box.size.z]
        sides.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.length() < b.length())
        var out:= sides [0].normalized()
        var dial:= _find("Scale_Dial") as VisualInstance3D
        if dial != null:
                var middle:= dial.global_transform * dial.get_aabb().get_center()
                if out.dot(centre - middle) < 0.0:
                        out = - out
        var up:= sides [1].normalized()
        if up.y < 0.0:
                up = - up
        var spec:= _load_spec()
        var shader: Shader = load(SHADER)
        var readout:= SegmentReadout.new()
        readout.name = "ScaleStrandReadout"
        readout.cells = 4
        readout.digit_height = sides [1].length() * SCALE_LCD_DIGIT_H
        readout.dim_offset = sides [0].length() * 0.5 + 0.001
        readout.lit_offset = sides [0].length() * 0.5 + 0.002
        readout.lit_material = _make_surface("M_ScaleLit", spec, shader)
        readout.dim_material = _make_surface("M_ScaleDim", spec, shader)
        add_child(readout)
        readout.global_transform = Transform3D(Basis(up.cross(out), up, out), centre)
        return readout


func _weigh_target() -> float:
        return clampf(float(_notches) / float(SACK_NOTCHES), 0.0, 1.0)


static func scale_fraction(strands: int) -> float:
        var count:= maxi(strands, 0)
        for i in range(1, SCALE_MARKS.size()):
                if count <= SCALE_MARKS [i]:
                        var between:= float(count - SCALE_MARKS [i - 1]) / float(SCALE_MARKS [i] - SCALE_MARKS [i - 1])
                        return (float(i - 1) + between) / float(SCALE_MARKS.size() - 1)
        return 1.0


static func scale_digits(strands: int) -> String:
        return "%04d" % maxi(strands, 0) if strands <= 9999 else "HI"


func _record_scale_strands(strands: int) -> void:
        if _hold > 0.0:
                _scale_waiting += maxi(strands, 0)
        else:
                _scale_strands += maxi(strands, 0)


func _drive_scale(delta: float) -> void:
        if _plate == null and _needle == null:
                return
        var target:= _weigh_target()
        if _hold > 0.0:


                target = maxf(_hold_at, 0.0) * HOLD_SQUASH
        var accel:= (target - _weigh) * WEIGH_STIFF - _weigh_vel * WEIGH_DAMP
        _weigh_vel += accel * delta
        _weigh += _weigh_vel * delta


        _weigh = clampf(_weigh, -0.06, 1.16)


        _punch_vel += (- _punch * PUNCH_STIFF - _punch_vel * PUNCH_DAMP) * delta
        _punch += _punch_vel * delta
        if _punch >= PUNCH_MAX and _punch_vel > 0.0:


                _punch = PUNCH_MAX
                _punch_vel = 0.0
        _punch = clampf(_punch, -0.015, PUNCH_MAX)
        if _plate != null:


                _plate.position = _plate_rest + Vector3.DOWN * (PLATE_SINK * clampf(_weigh, 0.0, 1.0)) + Vector3.UP * _punch
        if _needle != null:


                _scale_angle = lerpf(_scale_angle, scale_fraction(_scale_strands), 1.0 - exp(-12.0 * delta))
                _needle.quaternion = Quaternion(_needle_axis,
                        deg_to_rad(NEEDLE_SWEEP) * _scale_angle) * _needle_rest
        if _scale_lcd != null:
                _scale_lcd.show_text(scale_digits(_scale_strands))


        if _hold <= 0.0:
                var f:= clampf(_weigh, 0.0, 1.0)
                if _sack != null:


                        _sack.position = _sack_rest + Vector3.DOWN * (PLATE_SINK * f) + Vector3.UP * _punch
                _set_sack_fill(f)


func _build_sack() -> void:
        var packed: PackedScene = load(SACK_MODEL)
        if packed == null:
                push_warning("HaySellingStand: cannot load %s; the plate will be bare" % SACK_MODEL)
                return
        _sack = packed.instantiate() as Node3D
        if _sack == null:
                return
        _sack.name = "Sack"
        add_child(_sack)


        _sack_rest = _scale_plate + Vector3.UP * SACK_LIFT
        _sack.position = _sack_rest

        _sack_body = _sack.find_child(N_SACK, true, false) as Node3D
        _sack_mesh = _sack.find_child(N_SACK, true, false) as MeshInstance3D
        if _sack_mesh == null and _sack_body != null:
                for m in _sack_body.find_children("*", "MeshInstance3D", true, false):
                        _sack_mesh = m as MeshInstance3D
                        break
        if _sack_body != null:
                _sack_body_rest = _sack_body.transform


        var star:= _sack.find_child(N_STAR, true, false) as Node3D
        if star != null:
                star.scale = Vector3.ZERO

        for n in _sack.find_children("*", "AnimationPlayer", true, false):
                _sack_anim = n as AnimationPlayer
                break
        if _sack_anim != null:


                _sack_anim.playback_default_blend_time = 0.0
                _sack_anim.stop()

        if _sack_mesh != null and _sack_mesh.mesh != null:
                for i in _sack_mesh.mesh.get_blend_shape_count():
                        if String(_sack_mesh.mesh.get_blend_shape_name(i)) == SACK_FILL:
                                _sack_fill = i
                                break
        if _sack_fill < 0:
                push_warning("HaySellingStand: the sack has no '%s' blend shape; it will not swell" % SACK_FILL)
        _set_sack_fill(0.0)


func _build_sale_fx() -> void:
        _sale_fx = SaleFx.new()
        _sale_fx.name = "SaleFx"
        add_child(_sale_fx)

        _sale_fx.watch(_sack, _sack_mesh, _sack_fill,
                _coins_at - Vector3(0, COIN_SPOUT_UP, 0))


func _set_sack_fill(f: float) -> void:
        if _sack_mesh != null and _sack_fill >= 0:
                _sack_mesh.set_blend_shape_value(_sack_fill, f)


func _launch_sack() -> void:
        if _sack == null or _weigh <= 0.02:
                return
        _flyer = _spawn_flyer()
        if _flyer == null:
                return


        _hold = WIND_UP
        _hold_at = _weigh


        if _sack_body != null:
                _sack_body.scale = Vector3.ZERO


func _release_sack() -> void:
        _scale_strands = _scale_waiting
        _scale_waiting = 0


        var up:= sqrt(2.0 * SackFlyer.GRAVITY * FLY_UP)
        if is_instance_valid(_flyer):
                _flyer.release(FLY_DRIFT + Vector3.UP * up)
                _flyer = null
        _punch_vel = PUNCH_KICK
        _kick_burst()


        Audio.play_3d("machine_clunk", delivery_point(), -4.0)
        Audio.play_3d("rake_throw", delivery_point(), -3.0)


func _spawn_flyer() -> SackFlyer:
        var packed: PackedScene = load(SACK_MODEL)
        if packed == null:
                return null
        var model:= packed.instantiate() as Node3D
        if model == null:
                return null

        var body:= model.find_child(N_SACK, true, false) as MeshInstance3D
        if body != null and _sack_fill >= 0:


                body.set_blend_shape_value(_sack_fill, clampf(_weigh, 0.0, 1.0))

        var flyer:= SackFlyer.new()
        flyer.name = "SackInFlight"
        add_child(flyer)
        flyer.position = _sack.position
        flyer.carry(model, body, model.find_child(N_STAR, true, false) as Node3D, WIND_UP)
        return flyer


func _grow_sack() -> void:
        if _sack_body == null:
                return
        if _grow != null and _grow.is_valid():
                _grow.kill()
        _sack_body.transform = _sack_body_rest
        _sack_body.scale = Vector3.ZERO
        _set_sack_fill(0.0)
        _grow = create_tween()
        _grow.tween_property(_sack_body, "scale", Vector3.ONE * 1.1, SACK_GROW * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        _grow.tween_property(_sack_body, "scale", Vector3.ONE, SACK_GROW * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _sample_track(a: Animation, track: int, t: float) -> Variant:
        match a.track_get_type(track):
                Animation.TYPE_POSITION_3D:
                        return a.position_track_interpolate(track, t)
                Animation.TYPE_ROTATION_3D:
                        return a.rotation_track_interpolate(track, t)
                Animation.TYPE_SCALE_3D:
                        return a.scale_track_interpolate(track, t)
                Animation.TYPE_VALUE:
                        return a.value_track_interpolate(track, t)
        return null


func _build_belt() -> void:
        _belt = BeltPath.new()
        _belt.name = "StandBelt"


        _belt.stand_belt = true


        _belt.gathers_straw = true
        add_child(_belt)

        var tail:= _marker_local(N_BELT_IN, Vector3(-3.12, BELT_DECK_Y, 3.05))
        var head:= _marker_local(N_BELT_OUT, Vector3(1.06, 1.08, 3.05))
        var centre_z:= tail.z
        var points:= PackedVector3Array()
        points.append(tail)
        points.append(Vector3(BELT_KNEE_X, BELT_DECK_Y, centre_z))
        var knee_centre_y:= BELT_DECK_Y + BELT_KNEE_RADIUS
        var a0:= - PI * 0.5
        var a1:= a0 + BELT_INCLINE
        for i in range(1, BELT_PATH_STEPS + 1):
                var a:= lerpf(a0, a1, float(i) / float(BELT_PATH_STEPS))
                points.append(Vector3(
                        BELT_KNEE_X + BELT_KNEE_RADIUS * cos(a),
                        knee_centre_y + BELT_KNEE_RADIUS * sin(a),
                        centre_z))
        points.append(head)


        _belt_mid = to_global((tail + head) * 0.5)


        _belt_head = head
        _belt_tail = tail
        _scale_plate = _marker_local(N_SCALE_PLATE, Vector3(1.66, 0.61, 3.05))

        _draw_belt(points)


        _belt.records_props = true
        _belt.hold_records(_eats_kind)


func _draw_belt(points: PackedVector3Array) -> void:
        _belt_rubber = ConveyorKit.own_belt_material(Tech.stand_belt_speed())
        _belt_drum = ConveyorKit.drum_material().duplicate() as ShaderMaterial
        _retime_belt()
        Tech.tech_changed.connect(_on_belt_tech_changed)
        Tech.tech_reset.connect(_retime_belt)

        if _model != null:
                for prefix: String in MODEL_BELT_PREFIXES:
                        for n in _model.find_children("%s*" % prefix, "Node3D", true, false):
                                (n as Node3D).visible = false


        var curve:= PackedVector3Array()
        var knee_centre:= Vector3(BELT_KNEE_X, BELT_DECK_Y + BELT_KNEE_RADIUS, _belt_tail.z)
        var climb_from:= knee_centre + BELT_KNEE_RADIUS * Vector3(
                cos(- PI * 0.5 + BELT_INCLINE), sin(- PI * 0.5 + BELT_INCLINE), 0.0)
        _append_straight(curve, _belt_tail, points [1])
        for i in range(1, BELT_DRAW_KNEE_STEPS):
                var a:= - PI * 0.5 + BELT_INCLINE * float(i) / float(BELT_DRAW_KNEE_STEPS)
                curve.append(to_global(knee_centre
                        + BELT_KNEE_RADIUS * Vector3(cos(a), sin(a), 0.0)))
        _append_straight(curve, climb_from, _belt_head)
        curve.append(to_global(_belt_head))
        _belt.draw_curve = curve
        var world_points:= PackedVector3Array()
        for point in points:
                world_points.append(to_global(point))
        _belt.build_path(world_points, BELT_PATH_OVERLAP)

        var sections:= _belt.get_node_or_null("Path/Sections") as MeshInstance3D
        if sections != null and sections.mesh is ArrayMesh:

                var mesh:= sections.mesh as ArrayMesh
                for i in mesh.get_surface_count():
                        mesh.surface_set_material(i, _stand_material(mesh.surface_get_material(i)))
                BeltBatch.changed(sections)

        var drums:= Node3D.new()
        drums.name = "BeltDrums"

        drums.top_level = true
        add_child(drums)
        var tail_basis:= BeltPath.run_basis(to_global(_belt_tail), to_global(points [1]))
        var head_basis:= BeltPath.run_basis(to_global(climb_from), to_global(_belt_head))


        for e: Array in [
                        [ConveyorKit.nose_mesh(true), _belt_head, head_basis],
                        [ConveyorKit.nose_mesh(false), _belt_tail, tail_basis.rotated(tail_basis.y, PI)]]:
                var mi:= MeshInstance3D.new()
                mi.mesh = _stand_mesh(e [0] as ArrayMesh)
                drums.add_child(mi)
                mi.global_transform = Transform3D(e [2] as Basis, to_global(e [1] as Vector3))


        var legs: Array [Transform3D] = []
        var feet: Array [Transform3D] = []
        var ground_y:= global_position.y
        for x: float in BELT_LEG_X:
                var on_climb:= x > climb_from.x
                var frame:= head_basis if on_climb else tail_basis
                var deck:= Vector3(x, _deck_y_at(x, curve), _belt_tail.z)
                var centre_top:= to_global(deck) - frame.y * Cfg.BELT_SUPPORT_ATTACH_DEPTH
                for side: float in [-1.0, 1.0]:
                        var top:= centre_top + tail_basis.x * (side * Cfg.BELT_SUPPORT_HALF_WIDTH)
                        var drop:= top.y - ground_y
                        if drop < 0.05:
                                continue
                        legs.append(Transform3D(tail_basis.scaled_local(Vector3(1, drop, 1)), top))
                        feet.append(Transform3D(tail_basis, Vector3(top.x, ground_y, top.z)))
        var supports:= Node3D.new()
        supports.name = "BeltSupports"
        supports.top_level = true
        add_child(supports)
        supports.add_child(Conveyor._support_mm("Legs", ConveyorKit.leg_mesh(), legs))
        supports.add_child(Conveyor._support_mm("Feet", ConveyorKit.foot_mesh(), feet))


func _append_straight(into: PackedVector3Array, from: Vector3, to: Vector3) -> void:
        var n:= maxi(1, int(ceil(from.distance_to(to) / BELT_DRAW_SPAN)))
        for i in n:
                into.append(to_global(from.lerp(to, float(i) / float(n))))


func _deck_y_at(x: float, curve: PackedVector3Array) -> float:
        for i in curve.size() - 1:
                var a:= to_local(curve [i])
                var b:= to_local(curve [i + 1])
                if x >= a.x and x <= b.x:
                        return lerpf(a.y, b.y, inverse_lerp(a.x, b.x, x))
        return to_local(curve [curve.size() - 1]).y if x > _belt_tail.x else BELT_DECK_Y


func _stand_material(m: Material) -> Material:
        if m == ConveyorKit.belt_material():
                return _belt_rubber
        if m == ConveyorKit.drum_material():
                return _belt_drum
        return m


func _stand_mesh(source: ArrayMesh) -> ArrayMesh:
        var out:= ArrayMesh.new()
        for i in source.get_surface_count():
                out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(i))
                out.surface_set_material(i, _stand_material(source.surface_get_material(i)))
        return out


func _on_belt_tech_changed(_id: String, _rank: int) -> void:
        _retime_belt()


func _retime_belt() -> void:
        var v:= Tech.stand_belt_speed()
        if _belt_rubber != null:
                _belt_rubber.set_shader_parameter("speed", v)
        if _belt_drum != null:
                _belt_drum.set_shader_parameter("speed", v)


func intake_speed() -> float:
        return _belt.drive_speed if _belt != null else 0.0


func belt_entry_point() -> Vector3:
        return to_global(_belt_tail)


func intake_forward() -> Vector3:
        var knee:= to_global(Vector3(BELT_KNEE_X, _belt_tail.y, _belt_tail.z))
        var along:= knee - to_global(_belt_tail)
        along.y = 0.0
        return along.normalized() if along.length_squared() > 1e-08 else global_basis.x.normalized()


func footprint() -> Rect2:
        if not _footprint_known:
                _measure_footprint()
        return _footprint


func floor_distance(world_point: Vector3) -> float:
        if not _footprint_known:
                _measure_footprint()
        var p:= to_local(world_point)
        var flat:= Vector2(p.x, p.z)
        if _footprint.size == Vector2.ZERO:
                return flat.length()
        return flat.distance_to(flat.clamp(_footprint.position, _footprint.end))


func _measure_footprint() -> void:
        _footprint_known = true
        if _model == null:
                return
        var inverse:= global_transform.affine_inverse()
        var first:= true
        for n in _model.find_children("*", "MeshInstance3D", true, false):
                var mi:= n as MeshInstance3D
                if mi.mesh == null or mi.name.begins_with(N_CATCH):
                        continue
                var into_stand:= inverse * mi.global_transform
                var box:= mi.mesh.get_aabb()
                for i in 8:
                        var corner:= into_stand * box.get_endpoint(i)
                        var flat:= Vector2(corner.x, corner.z)
                        if first:
                                _footprint = Rect2(flat, Vector2.ZERO)
                                first = false
                        else:
                                _footprint = _footprint.expand(flat)


func mouth_centre() -> Vector3:
        return _payout_area.global_position if _payout_area != null else global_position


func delivery_point() -> Vector3:
        return to_global(_scale_plate)


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
        var marker:= _find(node_name) as Node3D
        if marker == null:
                push_warning("HaySellingStand: %s is missing; using measured belt endpoint" % node_name)
                return fallback
        return to_local(marker.global_position)


func _build_payout_area() -> void:
        _payout_area = Area3D.new()
        _payout_area.name = "ScalePayoutVolume"
        _payout_area.collision_layer = 0


        _payout_area.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
        _payout_area.monitorable = false
        var box:= BoxShape3D.new()
        box.size = Vector3(MOUTH_BACK + MOUTH_REACH, MOUTH_RISE + MOUTH_DROP,
                MOUTH_HALF_W * 2.0)
        var cs:= CollisionShape3D.new()
        cs.shape = box
        _payout_area.add_child(cs)
        add_child(_payout_area)

        _payout_area.position = Vector3(
                _belt_head.x - MOUTH_BACK + (MOUTH_BACK + MOUTH_REACH) * 0.5,
                _belt_head.y + (MOUTH_RISE - MOUTH_DROP) * 0.5,
                _belt_head.z)

        var catch_mesh:= _find(N_CATCH) as MeshInstance3D
        if catch_mesh != null:
                catch_mesh.visible = false
        else:
                push_warning("HaySellingStand: %s is missing from the model; hopper marker cannot be hidden" % N_CATCH)

        _popup_at = _payout_area.global_position + Vector3(0, POPUP_UP, 0)
        _resolve_coin_spout()


func _resolve_coin_spout() -> void:
        var screen:= _find(N_TILL_SCREEN) as Node3D
        if screen == null:
                _coins_at = _popup_at
                return
        _coins_at = screen.global_position + Vector3(0, COIN_SPOUT_UP, 0)


        _coins_face = screen.global_transform.basis.z.normalized()


func _skin() -> void:
        if _model == null:
                return
        var spec:= _load_spec()
        if spec.is_empty():
                push_warning("HaySellingStand: no material table at %s, the model will render untextured" % SPEC)
                return
        var shader: Shader = load(SHADER)
        var built: Dictionary = { }
        var missed: Dictionary = { }
        for n in _model.find_children("*", "MeshInstance3D", true, false):
                var mi:= n as MeshInstance3D
                if mi.mesh == null:
                        continue
                for i in mi.mesh.get_surface_count():
                        var src:= mi.get_active_material(i)
                        if src == null:
                                continue


                        var key:= src.resource_name


                        if key.is_empty():
                                continue
                        if not built.has(key):
                                built [key] = _make_surface(key, spec, shader)
                        if built [key] == null:
                                missed [key] = true
                                continue
                        mi.set_surface_override_material(i, built [key])
        if not missed.is_empty():
                push_warning("HaySellingStand: no table entry for %s" % ", ".join(missed.keys()))


func _load_spec() -> Dictionary:


        var res: JSON = load(SPEC) as JSON
        if res != null and typeof(res.data) == TYPE_DICTIONARY:
                return res.data
        if not FileAccess.file_exists(SPEC):
                return { }
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
        return parsed if typeof(parsed) == TYPE_DICTIONARY else { }


func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
        var surfaces: Dictionary = spec.get("surfaces", { })
        if surfaces.has(key):
                var d: Dictionary = surfaces [key]
                var asset: String = d ["asset"]
                var m:= ShaderMaterial.new()
                m.shader = shader
                m.resource_name = key
                for slot: String in TEX_MAPS:
                        var suffix: String = TEX_MAPS [slot]
                        var path: String = TEX % [asset, asset, suffix]


                        if ResourceLoader.exists(path):
                                m.set_shader_parameter("tex_" + slot, load(path))
                m.set_shader_parameter("per_metre", float(d ["per_metre"]))
                m.set_shader_parameter("tint", _col(d ["tint"]))
                m.set_shader_parameter("saturation", float(d.get("sat", 1.0)))
                var rough: Array = d ["rough"]
                m.set_shader_parameter("rough_min", float(rough [0]))
                m.set_shader_parameter("rough_max", float(rough [1]))
                m.set_shader_parameter("metallic_amount", float(d.get("metal", 0.0)))
                m.set_shader_parameter("normal_strength", float(d.get("nor", 1.0)))
                m.set_shader_parameter("ao_strength", float(d.get("ao", 0.0)))
                return m

        var flats: Dictionary = spec.get("flats", { })
        if flats.has(key):
                var f: Dictionary = flats [key]
                var sm:= StandardMaterial3D.new()
                sm.resource_name = key
                sm.albedo_color = _col(f ["color"])
                sm.roughness = float(f.get("rough", 0.6))
                sm.metallic = float(f.get("metal", 0.0))
                sm.metallic_specular = 0.4


                var emit:= float(f.get("emit", 0.0))
                if emit > 0.0:
                        sm.emission_enabled = true
                        sm.emission = sm.albedo_color
                        sm.emission_energy_multiplier = emit
                return sm
        return null


func _col(a: Variant) -> Color:
        var v: Array = a
        return Color(float(v [0]), float(v [1]), float(v [2]))


func _dress() -> void:
        if _model == null:
                return


        for prefix in HIDE_PREFIXES:
                for n in _model.find_children("%s*" % prefix, "Node3D", true, false):
                        (n as Node3D).visible = false


        var popup:= _find(N_POPUP) as Node3D
        if popup != null:
                popup.visible = false


        for n in _model.find_children("*", "StaticBody3D", true, false):
                var sb:= n as StaticBody3D
                sb.collision_layer = Cfg.L_WORLD
                sb.collision_mask = 0


                if sb.name.begins_with("Col_Belt") or sb.get_parent().name.begins_with("Col_Belt"):
                        sb.collision_layer = 0
                        push_warning("HaySellingStand: model still ships %s; disabled so it cannot brake the belt" % sb.name)


func _build_ledger_note() -> void:
        if _model == null:
                return
        var lines:= LEDGER_NOTE.split("\n")
        if lines.size() > LEDGER_RULES:
                lines.resize(LEDGER_RULES)
        var step:= 2 if lines.size() * 2 - 1 <= LEDGER_RULES else 1


        var first:= int((LEDGER_RULES - 1 + (lines.size() - 1) * step) / 2.0)

        var font:= UiFont.bold()
        var widest:= 0.0
        for line in lines:
                widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT,
                        -1.0, LEDGER_FONT_PX).x)

        var pixel:= LEDGER_EM / LEDGER_FONT_PX
        if widest > 0.0:
                pixel = minf(pixel, LEDGER_TEXT_WIDTH / widest)

        var yaw:= Basis(Vector3.UP, deg_to_rad(LEDGER_YAW))


        var flat:= yaw * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
        for i in lines.size():
                var l:= Label3D.new()
                l.name = "LedgerNote%d" % i
                l.text = lines [i]
                l.font = font
                l.font_size = LEDGER_FONT_PX
                l.pixel_size = pixel
                l.modulate = Color(0.06, 0.06, 0.08)
                l.outline_size = 0
                l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


                l.offset = Vector2(0.0, - font.get_descent(LEDGER_FONT_PX) + LEDGER_LIFT / pixel)
                l.billboard = BaseMaterial3D.BILLBOARD_DISABLED


                l.shaded = false
                l.double_sided = false


                l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
                l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
                var rule:= first - i * step


                var at:= LEDGER_RULE_0 + Vector3(0.0, 0.0, - LEDGER_RULE_PITCH * rule)
                _model.add_child(l)
                l.transform = Transform3D(flat, at)


func _price_text() -> String:


        return tr("$%.4f\nPER STRAND") % Tech.hay_price()


func _on_price_tech_changed(id: String, _rank: int) -> void:
        if id == "hay_price":
                _refresh_price_board()


func _refresh_price_board() -> void:
        if _price_board != null:
                _price_board.text = _price_text()


func board_face() -> Node3D:
        return _find(N_BOARD_FACE) as Node3D


func _build_price_board() -> void:
        for chalk in PRICE_TEXT_NODES:
                var t:= _find(chalk) as Node3D
                if t != null:
                        t.visible = false
        var face:= _find(N_BOARD_FACE) as Node3D
        if face == null:
                return


        var l:= _make_label(_price_text(), Color(0.9, 0.92, 0.86),
                PRICE_BOARD_PIXEL_SIZE, 76)
        l.name = "PriceBoard"
        _price_board = l
        l.outline_size = 0


        var text_width:= l.font.get_multiline_string_size(l.text,
                HORIZONTAL_ALIGNMENT_CENTER, -1.0, l.font_size).x
        if text_width > 0.0:
                l.pixel_size = minf(l.pixel_size, PRICE_BOARD_TEXT_WIDTH / text_width)


        l.alpha_cut = Label3D.ALPHA_CUT_DISCARD


        l.shaded = true
        l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
        add_child(l)
        var gx:= face.global_transform


        l.global_transform = Transform3D(gx.basis.orthonormalized(),
                gx.origin + gx.basis.z.normalized() * 0.031)


func _build_till() -> void:
        var digits:= _find(N_TILL_DIGITS) as Node3D
        if digits != null:
                digits.visible = false
        else:
                push_warning("HaySellingStand: %s is missing; baked till digits cannot be hidden" % N_TILL_DIGITS)
        var screen:= _find(N_TILL_SCREEN) as Node3D
        if screen == null:
                push_warning("HaySellingStand: %s is missing; live till readout is disabled" % N_TILL_SCREEN)
                return
        _till = _make_label("$0.00", COL_TILL, 0.0013, 76)
        _till.name = "TillReadout"
        _till.outline_size = 0
        _till.alpha_cut = Label3D.ALPHA_CUT_DISCARD
        _till.billboard = BaseMaterial3D.BILLBOARD_DISABLED
        add_child(_till)


        var gx:= screen.global_transform
        _till.global_transform = Transform3D(gx.basis.orthonormalized(),
                gx * Vector3(0.0, 0.0, 0.028))


func _build_coins() -> void:


        var lean:= Vector3.ZERO
        if _coins_face != Vector3.ZERO:
                lean = global_transform.basis.orthonormalized().inverse() * _coins_face


        var axis:= (Vector3.UP + lean * 0.45).normalized()
        var dot:= _soft_dot()

        _coins = _build_coin_layer(axis)
        _sparks = _build_spark_layer(axis, dot)
        _motes = _build_mote_layer(axis, dot)

        _flash = OmniLight3D.new()
        _flash.name = "PayoutFlash"
        _flash.light_color = Color(1.0, 0.76, 0.34)
        _flash.omni_range = FLASH_RANGE
        _flash.light_energy = 0.0


        _flash.light_specular = 1.4


        _flash.shadow_enabled = false
        _flash.visible = false
        add_child(_flash)
        _flash.global_position = _coins_at + Vector3(0, 0.12, 0)


func _build_coin_layer(axis: Vector3) -> GPUParticles3D:
        var pm:= ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE

        pm.emission_sphere_radius = 0.05
        pm.direction = axis
        pm.spread = 30.0
        pm.initial_velocity_min = 2.0
        pm.initial_velocity_max = 3.8


        pm.gravity = Vector3(0, -6.8, 0)
        pm.damping_min = 0.1
        pm.damping_max = 0.6


        pm.angle_min = 0.0
        pm.angle_max = 360.0
        pm.angular_velocity_min = -820.0
        pm.angular_velocity_max = 820.0


        pm.particle_flag_rotate_y = true
        pm.scale_min = 0.75
        pm.scale_max = 1.4
        pm.scale_curve = _curve([[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]])
        pm.color_ramp = _ramp([
                [0.0, Color(1, 1, 1, 1)],
                [0.78, Color(1, 1, 1, 1)],
                [1.0, Color(1, 1, 1, 0)]])

        var coins:= _spawn_emitter("PayoutCoins", _coin_mesh(), pm, COIN_MAX, 1.15, 0.88)
        coins.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        return coins


func _build_spark_layer(axis: Vector3, dot: Texture2D) -> GPUParticles3D:


        var quad:= QuadMesh.new()
        quad.size = Vector2(0.01, 0.01)
        var m:= StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD


        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.billboard_keep_scale = true
        m.albedo_texture = dot
        m.albedo_color = Color(1.0, 0.9, 0.58)
        m.vertex_color_use_as_albedo = true
        m.disable_receive_shadows = true
        quad.material = m

        var pm:= ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
        pm.emission_sphere_radius = 0.045
        pm.direction = axis
        pm.spread = 65.0
        pm.initial_velocity_min = 2.8
        pm.initial_velocity_max = 6.2
        pm.gravity = Vector3(0, -2.0, 0)


        pm.damping_min = 4.0
        pm.damping_max = 9.0
        pm.angle_min = 0.0
        pm.angle_max = 360.0
        pm.angular_velocity_min = -300.0
        pm.angular_velocity_max = 300.0
        pm.scale_min = 0.35
        pm.scale_max = 1.1
        pm.scale_curve = _curve([[0.0, 0.25], [0.12, 1.0], [1.0, 0.0]])
        pm.color_ramp = _ramp([
                [0.0, Color(1.0, 0.98, 0.86, 1.0)],
                [0.35, Color(1.0, 0.82, 0.42, 0.9)],
                [1.0, Color(1.0, 0.55, 0.15, 0.0)]])

        return _spawn_emitter("PayoutSparks", quad, pm, SPARK_MAX, SPARK_LIFE, 1.0)


func _build_mote_layer(axis: Vector3, dot: Texture2D) -> GPUParticles3D:
        var quad:= QuadMesh.new()
        quad.size = Vector2(0.007, 0.007)
        var m:= StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.billboard_keep_scale = true
        m.albedo_texture = dot
        m.albedo_color = Color(1.0, 0.84, 0.48)
        m.vertex_color_use_as_albedo = true
        m.disable_receive_shadows = true
        quad.material = m

        var pm:= ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE


        pm.emission_sphere_radius = 0.07
        pm.direction = axis
        pm.spread = 88.0
        pm.initial_velocity_min = 0.35
        pm.initial_velocity_max = 1.4

        pm.gravity = Vector3(0, -0.45, 0)
        pm.damping_min = 0.8
        pm.damping_max = 2.0


        pm.turbulence_enabled = true
        pm.turbulence_noise_strength = 0.32
        pm.turbulence_noise_scale = 2.4
        pm.turbulence_influence_min = 0.08
        pm.turbulence_influence_max = 0.35
        pm.angle_min = 0.0
        pm.angle_max = 360.0
        pm.angular_velocity_min = -140.0
        pm.angular_velocity_max = 140.0
        pm.scale_min = 0.35
        pm.scale_max = 0.95
        pm.scale_curve = _curve([[0.0, 0.2], [0.25, 1.0], [1.0, 0.0]])
        pm.color_ramp = _ramp([
                [0.0, Color(1.0, 0.88, 0.55, 0.0)],
                [0.15, Color(1.0, 0.86, 0.5, 0.75)],
                [1.0, Color(1.0, 0.6, 0.2, 0.0)]])


        return _spawn_emitter("PayoutMotes", quad, pm, MOTE_MAX, MOTE_LIFE, 0.75)


func _build_kick() -> void:
        var at:= to_global(_scale_plate) + Vector3(0, 0.05, 0)
        _puff = _build_puff(at + Vector3(0, 0.1, 0))
        _kick_dust = _build_kick_dust_layer(at)


func _build_puff(at: Vector3) -> MeshInstance3D:
        var ball:= SphereMesh.new()
        ball.radius = PUFF_R
        ball.height = PUFF_H


        ball.radial_segments = 16
        ball.rings = 8

        var mat:= ShaderMaterial.new()
        mat.shader = load(SMOKE_SHADER)


        mat.set_shader_parameter("scale", 5.0)


        mat.set_shader_parameter("tex_speed", Vector3(0.25, -0.55, 0.18))
        mat.set_shader_parameter("smoke_volume", 1.0)
        mat.set_shader_parameter("smoke_aperture", PUFF_GATE)
        mat.set_shader_parameter("edge_falloff", 1.8)
        mat.set_shader_parameter("smoke_softness", 0.45)
        mat.set_shader_parameter("noise_contrast", 2.2)
        mat.set_shader_parameter("warp", 1.3)


        mat.set_shader_parameter("sway", 0.12)


        mat.set_shader_parameter("smoke_color", Color(0.68, 0.63, 0.55, PUFF_ALPHA))
        mat.set_shader_parameter("top_fade", 0.22)
        mat.set_shader_parameter("base_fade", 0.12)

        var puff:= MeshInstance3D.new()
        puff.name = "DeckPuff"
        puff.mesh = ball
        puff.material_override = mat
        puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

        puff.visible = false
        add_child(puff)
        puff.global_position = at
        _puff_rest = puff.position
        return puff


func _build_kick_dust_layer(at: Vector3) -> GPUParticles3D:
        var quad:= QuadMesh.new()
        quad.size = Vector2(0.24, 0.24)
        var m:= StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.billboard_keep_scale = true
        m.albedo_texture = _soft_dot()


        m.albedo_color = Color(0.78, 0.68, 0.46)
        m.vertex_color_use_as_albedo = true
        m.disable_receive_shadows = true
        quad.material = m

        var pm:= ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
        pm.emission_ring_axis = Vector3.UP
        pm.emission_ring_radius = 0.36
        pm.emission_ring_inner_radius = 0.18
        pm.emission_ring_height = 0.02
        pm.direction = Vector3.UP


        pm.spread = 78.0
        pm.initial_velocity_min = 0.8
        pm.initial_velocity_max = 2.1
        pm.gravity = Vector3(0, -0.6, 0)
        pm.damping_min = 2.0
        pm.damping_max = 4.5
        pm.angle_min = 0.0
        pm.angle_max = 360.0
        pm.angular_velocity_min = -90.0
        pm.angular_velocity_max = 90.0
        pm.scale_min = 0.5
        pm.scale_max = 1.3
        pm.scale_curve = _curve([[0.0, 0.35], [0.3, 1.0], [1.0, 0.0]])
        pm.color_ramp = _ramp([
                [0.0, Color(0.92, 0.85, 0.66, 0.0)],
                [0.1, Color(0.94, 0.88, 0.72, 0.42)],
                [1.0, Color(0.7, 0.6, 0.42, 0.0)]])
        return _spawn_emitter("DeckKickDust", quad, pm, KICK_DUST_MAX,
                KICK_DUST_LIFE, 1.0, at)


func _kick_burst() -> void:
        var f:= clampf(_weigh, 0.0, 1.0)
        if _kick_dust != null:
                _kick_dust.amount_ratio = clampf(lerpf(0.55, 1.0, f), 0.05, 1.0)
                _kick_dust.restart()
        _puff_burst(lerpf(0.55, 1.0, f))


func _puff_burst(strength: float) -> void:
        if _puff == null:
                return
        var mat:= _puff.material_override as ShaderMaterial
        if mat == null:
                return
        if _puff_tween != null and _puff_tween.is_valid():
                _puff_tween.kill()
        _puff.visible = true
        _puff.position = _puff_rest


        _puff.scale = Vector3(0.7, 0.45, 0.7)
        mat.set_shader_parameter("smoke_aperture", PUFF_GATE)
        mat.set_shader_parameter("smoke_color",
                Color(0.68, 0.63, 0.55, PUFF_ALPHA * strength))

        _puff_tween = create_tween().set_parallel()
        _puff_tween.tween_property(_puff, "scale", Vector3(1.55, 1.1, 1.55), PUFF_LIFE).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        _puff_tween.tween_property(_puff, "position",
                        _puff_rest + Vector3.UP * PUFF_RISE, PUFF_LIFE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


        _puff_tween.tween_property(mat, "shader_parameter/smoke_aperture",
                        PUFF_GATE_END, PUFF_LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        _puff_tween.chain().tween_callback(func() -> void: _puff.visible = false)


func _spawn_emitter(emitter_name: String, mesh: Mesh, pm: ParticleProcessMaterial,
                count: int, life: float, burstiness: float,
                at:= Vector3.INF) -> GPUParticles3D:
        var p:= GPUParticles3D.new()
        p.name = emitter_name


        p.amount = count
        p.lifetime = life
        p.one_shot = true
        p.explosiveness = burstiness
        p.emitting = false
        p.draw_pass_1 = mesh
        p.process_material = pm


        p.visibility_aabb = AABB(Vector3(-2.5, -3, -2.5), Vector3(5, 6, 5))
        add_child(p)
        p.global_position = _coins_at if at == Vector3.INF else at
        return p


static var _shared_coin_mesh: ArrayMesh
func _coin_mesh() -> ArrayMesh:
        if _shared_coin_mesh != null:
                return _shared_coin_mesh
        var scene: Node = load("res://assets/models/extra_life_coin_particle.glb").instantiate()
        var source: MeshInstance3D = scene.find_child("ExtraLifeCoin", true, false) as MeshInstance3D
        assert (source != null, "Payout coin mesh is missing")
        var mesh:= source.mesh.duplicate() as ArrayMesh
        for i in mesh.get_surface_count():
                var mat:= mesh.surface_get_material(i).duplicate() as StandardMaterial3D
                mat.vertex_color_use_as_albedo = true
                mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
                mat.disable_receive_shadows = true
                mesh.surface_set_material(i, mat)
        scene.free()
        _shared_coin_mesh = mesh
        return _shared_coin_mesh


func _soft_dot() -> GradientTexture2D:
        var g:= Gradient.new()
        g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
        g.colors = PackedColorArray([
                Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
        var t:= GradientTexture2D.new()
        t.gradient = g
        t.fill = GradientTexture2D.FILL_RADIAL
        t.fill_from = Vector2(0.5, 0.5)
        t.fill_to = Vector2(1.0, 0.5)
        t.width = 64
        t.height = 64
        return t


func _ramp(stops: Array) -> GradientTexture1D:
        var offs:= PackedFloat32Array()
        var cols:= PackedColorArray()
        for s in stops:
                offs.append(float(s [0]))
                cols.append(s [1] as Color)
        var g:= Gradient.new()
        g.offsets = offs
        g.colors = cols
        var t:= GradientTexture1D.new()
        t.gradient = g
        return t


func _curve(points: Array) -> CurveTexture:
        var c:= Curve.new()
        for p in points:
                c.add_point(Vector2(float(p [0]), float(p [1])))
        var t:= CurveTexture.new()
        t.curve = c
        return t


func _physics_process(delta: float) -> void:
        _take_record()
        _collect()
        _tick_coins(delta)
        _tick_belt_loop(delta)


        if _belt != null and _belt.has_strands() and _anim != null and not _anim.is_playing():
                _run_cycle()


        _drive_scale(delta)
        _tick_sack(delta)
        if _pending <= 0.0:
                return
        _batch_idle -= delta
        _batch_age += delta
        if _batch_idle <= 0.0 or _batch_age >= Cfg.SELL_BATCH_MAX:
                _commit()


func _tick_sack(delta: float) -> void:
        _sack_idle += delta
        if _hold > 0.0:
                _hold -= delta
                if _hold <= 0.0:


                        _hold = 0.0
                        _release_sack()
                        _grow_sack()
                return
        _notch_clock += delta
        if _notch_queue > 0 and _notch_clock >= NOTCH_TIME:
                _notch_clock = 0.0
                _notch_queue -= 1
                _notches += 1
        if _notches >= SACK_NOTCHES:
                _throw_sack()
        elif _sack_idle >= SACK_PATIENCE and _notch_queue == 0:


                if _notches > 0 and _notch_clock >= NOTCH_TIME:
                        _throw_sack()
                elif _notches == 0 and _strand_bank > 0.0:


                        _strand_bank = 0.0
                        _notch_queue = 1


func _throw_sack() -> void:
        _launch_sack()
        _notches = 0
        _notch_clock = 0.0
        _strand_bank = 0.0


func _earn_notch(strands: float) -> void:
        _sack_idle = 0.0
        _strand_bank += maxf(strands, 0.0)
        var room:= SACK_NOTCHES - _notches - _notch_queue
        while _strand_bank >= NOTCH_STRANDS and room > 0:
                _strand_bank -= NOTCH_STRANDS
                _notch_queue += 1
                room -= 1
        if room <= 0:
                _strand_bank = 0.0


func _tick_belt_loop(delta: float) -> void:
        var running:= _belt != null and _belt.has_strands()
        if running and _belt_voice < 0:
                _belt_voice = Audio.loop_acquire("belt")


                if _belt_voice < 0:
                        return
                _belt_gain = BELT_LOOP_SILENT
        if _belt_voice < 0:
                return
        _belt_gain = move_toward(_belt_gain,
                BELT_LOOP_DB if running else BELT_LOOP_SILENT, BELT_LOOP_RAMP * delta)
        if not running and _belt_gain <= BELT_LOOP_SILENT + 0.5:
                _release_belt_loop()
                return
        Audio.loop_update(_belt_voice, _belt_mid, _belt_gain)


func _release_belt_loop() -> void:
        if _belt_voice < 0:
                return
        Audio.loop_release(_belt_voice)
        _belt_voice = -1
        _belt_gain = BELT_LOOP_SILENT


func _exit_tree() -> void:
        _release_belt_loop()


func _eats_kind(_kind: int, _strands: int) -> bool:
        return true


func _mouth_span() -> Vector2:
        if _belt == null:
                return Vector2(INF, - INF)
        var near:= to_global(Vector3(_belt_head.x - MOUTH_BACK, _belt_head.y, _belt_head.z))
        return Vector2(_belt.s_at(near), _belt.path_length())


static func sale_value_of(kind: int, strands: int, state: Variant) -> float:
        var held:= float(strands)
        match kind:
                BeltRun.Kind.BALE:
                        return held * Tech.bale_value_ratio()
                BeltRun.Kind.FOILED_BALE:
                        return held * Tech.bale_value_ratio() * Tech.foil_value_ratio()
                BeltRun.Kind.BRICK:
                        return held * Tech.brick_value_ratio()
                BeltRun.Kind.PULP:
                        return held * Tech.pulp_value_ratio()
                BeltRun.Kind.ROLL:
                        return held * Tech.pulp_value_ratio() * Tech.paper_value_ratio()
                BeltRun.Kind.DISC:
                        var spec: Dictionary = state if state is Dictionary else { }
                        var bricks:= clampi(int(spec.get("brick_hay",
                                FeedDisc.default_brick_hay())), 0, strands)
                        var worth:= maxf(0.0, float(spec.get("brick_worth",
                                float(bricks) * Cfg.PELLETIZER_BRICK_RATIO)))
                        return float(strands - bricks) * Tech.disc_value_ratio() + worth


        return held


func _take_record() -> void:
        if _belt == null or not _belt.records_props:
                return
        var span:= _mouth_span()
        var rec:= _belt.take_record(Callable(), span.x, span.y)
        if rec.is_empty():
                return
        var held:= int(rec ["strands"])
        var worth:= sale_value_of(int(rec ["kind"]), held, rec.get("state"))
        _record_scale_strands(held)
        _pending += worth
        _pending_hay += float(held)
        _earn_notch(worth)
        _batch_idle = Cfg.SELL_BATCH_WINDOW
        if _sale_fx != null:
                _sale_fx.swallow_record(rec, _belt.run)
        var needle:= int(rec ["needle"])
        if needle >= 0:
                GameState.lose_needle(needle, GameState.type_of(needle), 0.0,
                        GameState.NeedleLoss.SOLD)


func _collect() -> void:
        if live == null or _payout_area == null:
                return
        for body in _payout_area.get_overlapping_bodies():
                var rb:= body as RigidBody3D
                if rb == null or not rb.is_inside_tree():
                        continue


                var thing:= rb as Carryable
                if thing is ToolProp or thing is SandShovel:
                        if not thing.is_held() and (not rb.freeze or BeltPath.is_rider(rb)):
                                _sell_tool(thing)
                        continue
                if thing is HayContainer:


                        if not thing.is_held() and not rb.freeze:
                                _hand_back(thing)
                        continue


                if rb.has_method("sale_strands"):


                        if not rb.freeze or BeltPath.is_rider(rb):
                                BeltPath.release(rb)
                                var worth:= float(rb.call("sale_strands"))


                                var held:= int(rb.call("hay_strands")) if rb.has_method("hay_strands") else int(round(worth))
                                _record_scale_strands(held)
                                _pending += worth
                                _pending_hay += float(held)
                                _earn_notch(worth)
                                _batch_idle = Cfg.SELL_BATCH_WINDOW
                                var item:= rb as Carryable


                                if item != null and item.holds_needle():
                                        GameState.lose_needle(
                                                item.needle_index,
                                                GameState.type_of(item.needle_index), 0.0,
                                                GameState.NeedleLoss.SOLD)

                                if _sale_fx != null and item != null:
                                        _sale_fx.swallow(item, float(held))
                                if props != null and item != null:
                                        props.remove(item)
                                else:
                                        rb.queue_free()
                        continue
                if not (rb.collision_layer & Cfg.L_STRAND):
                        continue


                if rb.freeze and not BeltPath.is_rider(rb) and not LiveStrandManager.is_pinned(rb):
                        continue


                BeltPath.release(rb)
                if rb.has_meta("needle_index"):
                        _scrap_needle(rb)
                        continue

                var seen:= SaleFx.strand_of(rb)
                if sell_loose_strand(rb) and _sale_fx != null:
                        _sale_fx.swallow_strand(seen)


func sell_loose_strand(rb: RigidBody3D) -> bool:
        if live == null or rb.has_meta("needle_index") or not live.consume(rb):
                return false
        _record_scale_strands(1)
        _pending += 1.0
        _pending_hay += 1.0
        _earn_notch(1.0)
        _batch_idle = Cfg.SELL_BATCH_WINDOW
        return true


func _sell_tool(item: Carryable) -> void:
        var id:= item.item_id
        var price:= maxf(ItemDb.price(id), 0.0)
        BeltPath.release(item)
        if _sale_fx != null:
                _sale_fx.to_till(item)
        if props != null:
                props.remove(item)
        else:
                item.queue_free()
        GameState.add_money(price)
        Audio.play_3d("sell_register", global_position + Vector3(0, 1.1, 0), 1.0)


        _payout(price, tr("%s SOLD\n+$%s") % [Cfg.upper(ItemDb.display_name(id)),
                Hud.money_text(price)], COL_PAY)


const HAND_BACK_OUT:= [1.3, 2.0, 2.8]
const HAND_BACK_ALONG:= [0.0, -1.0, 1.0]


const HAND_BACK_FLOOR:= 0.3


func _hand_back(box: Carryable) -> void:
        var space:= get_world_3d().direct_space_state
        var reach:= float(BeltPath.load_shape(box) ["reach"])
        var size:= Vector3(reach * 2.0, 0.8, reach * 2.0)
        var basis:= global_transform.basis.orthonormalized()
        var query:= PhysicsShapeQueryParameters3D.new()
        var probe:= BoxShape3D.new()
        probe.size = size
        query.shape = probe
        query.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_PLAYER
        query.exclude = [box.get_rid()]
        for out: float in HAND_BACK_OUT:
                for along: float in HAND_BACK_ALONG:
                        var spot:= to_global(Vector3(_scale_plate.x + along, 0.0, _belt_head.z + out))
                        var ray:= PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 2.0,
                                spot + Vector3.DOWN * 1.0, Cfg.L_WORLD | Cfg.L_BUILD)
                        var hit:= space.intersect_ray(ray)
                        if hit.is_empty():
                                continue
                        var ground: Vector3 = hit ["position"]
                        if ground.y > global_position.y + HAND_BACK_FLOOR:
                                continue


                        query.transform = Transform3D(basis, ground + Vector3.UP * (size.y * 0.5 + 0.04))
                        if not space.intersect_shape(query, 1).is_empty():
                                continue
                        BeltPath.release(box)
                        box.linear_velocity = Vector3.ZERO
                        box.angular_velocity = Vector3.ZERO
                        box.warp(Transform3D(basis, ground + Vector3.UP * 0.02))
                        Audio.play_3d(box.impact_sfx(), ground, -6.0)
                        return


func _commit() -> void:
        var n:= _pending
        var hay:= _pending_hay
        _pending = 0.0
        _pending_hay = 0.0
        _batch_idle = 0.0
        _batch_age = 0.0


        var prev_best:= GameState.best_sale
        var amount:= GameState.sell_hay(hay, n)


        var best:= amount > prev_best
        _celebrate(amount, _coins_for(amount, prev_best), best)


        sold.emit(int(round(hay)), amount)


func _celebrate(amount: float, coins: int, best:= false) -> void:


        Audio.play_3d("sell_register", global_position + Vector3(0, 1.1, 0), 1.0)
        if best:


                _payout(amount, tr("NEW BEST: $%s") % Hud.money_text(amount), COL_BEST, coins, true)
        else:
                _payout(amount, "+$%s" % Hud.money_text(amount), COL_PAY, coins)


func _scrap_needle(rb: RigidBody3D) -> void:


        var index:= int(rb.get_meta("needle_index", -1))
        var type:= GameState.type_of(index)
        if not live.consume_needle(rb):
                return
        GameState.add_money(Cfg.NEEDLE_SCRAP_PRICE)


        GameState.lose_needle(index, type, Cfg.NEEDLE_SCRAP_PRICE,
                GameState.NeedleLoss.SCRAPPED)


        Audio.play_3d("machine_clunk", global_position + Vector3(0, 1.1, 0), -8.0)


        _popup(tr("%s LOST\n+$%s") % [Cfg.upper(NeedleTypes.name_of(type)),
                Hud.money_text(Cfg.NEEDLE_SCRAP_PRICE)], COL_SCRAP)
        if _till != null:
                _till.text = "$%s" % Hud.money_text(Cfg.NEEDLE_SCRAP_PRICE)
        _open_till()


func ring_up(amount: float, text: String) -> void:

        _payout(amount, text, COL_PAY, COIN_POOL)


func _payout(amount: float, text: String, colour: Color, coins: int = 0,
                best:= false) -> void:
        if best:
                _best_popup(text)
        else:
                _popup(text, colour)
        if _till != null:
                _till.text = "$%s" % Hud.money_text(amount)
        _burst(amount)
        _open_till()
        _run_cycle()
        _drop_coins(coins)


func _coins_for(amount: float, prev_best: float) -> int:
        var norm:= maxf(_sale_avg, COIN_AVG_FLOOR)


        var n:= 1 if amount >= COIN_AVG_FLOOR else 0
        if prev_best >= COIN_BEST_FLOOR and GameState.best_sale >= prev_best * COIN_BEST_MARGIN:
                n = COIN_POOL
        elif amount >= norm * COIN_BIG_RATIO:

                var doublings:= log(amount / (norm * COIN_BIG_RATIO)) / log(2.0)
                n = clampi(3 + int(floor(doublings)), 3, 5)
        _sale_avg = amount if _sale_avg <= 0.0 else lerpf(_sale_avg, amount, COIN_AVG_WEIGHT)
        return n


func _build_coin_pool() -> void:
        for i in COIN_POOL:
                var coin:= ExtraLifeCoin.new()
                coin.name = "ExtraLifeCoin%d" % i


                coin.top_level = true
                add_child(coin)
                coin.park(_coins_at)
                _coin_pool.append(coin)


func _drop_coins(count: int) -> void:
        if count <= 0 or _coin_pool.is_empty():
                return
        var now:= Time.get_ticks_msec() / 1000.0
        var big:= count > 1
        if now < (_big_ready_at if big else _coin_ready_at):
                return
        if not coins_anywhere:
                var cam:= get_viewport().get_camera_3d()
                if cam == null or cam.global_position.distance_to(_coins_at) > COIN_RANGE:
                        return


        var land:= _coin_landing()


        if _coin_land == Vector3.INF:
                return


        _coin_ready_at = now + COIN_COOLDOWN
        if big:
                _big_ready_at = now + COIN_BIG_COOLDOWN
        var across:= _coin_out.cross(Vector3.UP).normalized()
        for i in mini(count, COIN_POOL):
                var coin:= _spare_coin()
                if coin == null:
                        return
                var spot:= land + _coin_out * _rng.randf_range(0.0, COIN_LONG) + across * _rng.randf_range(- COIN_SCATTER, COIN_SCATTER)
                var flat:= Vector3(spot.x - _coins_at.x, 0.0, spot.z - _coins_at.z)
                var velocity:= flat / _coin_flight + Vector3.UP * _coin_vy
                var spin:= Vector3(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-6.0, 6.0),
                        _rng.randf_range(-14.0, 14.0))
                var turn:= Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0.0))
                coin.launch(Transform3D(turn, _coins_at + Vector3(0.0, 0.05, 0.0)), velocity, spin)
                _coins_out += 1


const COIN_LAND_PAST:= 0.7
const COIN_LAND_REACH:= 3.0
const COIN_LONG:= 0.5
const COIN_SCATTER:= 0.45


const COIN_RISE_MIN:= 0.3
const COIN_RISE_MAX:= 1.5
const COIN_CLEAR:= 0.15
const COIN_ROOF_GAP:= 0.25

var _coin_land:= Vector3.INF
var _coin_out:= Vector3.ZERO
var _coin_rise:= 0.0
var _coin_vy:= 0.0
var _coin_flight:= 1.0


func _coin_landing() -> Vector3:
        var frame:= Engine.get_physics_frames()
        if _coin_land != Vector3.INF and frame - _coin_planned_frame < COIN_REPLAN:
                return _coin_land
        _coin_out = Vector3(_coins_face.x, 0.0, _coins_face.z)
        if _coin_out.length() < 0.01:
                _coin_out = global_transform.basis.z
        _coin_out = _coin_out.normalized()
        var across:= _coin_out.cross(Vector3.UP).normalized()
        var floor_y:= global_position.y
        var space:= get_world_3d().direct_space_state
        var mask:= Cfg.L_WORLD | Cfg.L_BUILD
        var far:= COIN_LAND_REACH + COIN_LONG + COIN_LAND_PAST

        var steps: Array [float] = []
        var roofs: Array [float] = []
        var tops: Array [float] = []
        var last_solid:= -1.0
        var d:= 0.25
        while d <= far:
                var roof:= INF
                var top:= - INF
                for side: float in [- COIN_SCATTER, 0.0, COIN_SCATTER]:
                        var p:= _coins_at + _coin_out * d + across * side
                        var up:= space.intersect_ray(_coin_ray(p, p + Vector3.UP * 2.0, mask))
                        if not up.is_empty():
                                roof = minf(roof, (up ["position"] as Vector3).y)


                        var from_y:= minf(_coins_at.y + 0.6, roof - 0.05)
                        var down:= space.intersect_ray(_coin_ray(Vector3(p.x, from_y, p.z),
                                Vector3(p.x, floor_y - 0.5, p.z), mask))
                        if not down.is_empty():
                                var hit_y:= (down ["position"] as Vector3).y
                                if hit_y > floor_y + 0.08:
                                        top = maxf(top, hit_y)
                                        if d <= COIN_LAND_REACH:
                                                last_solid = maxf(last_solid, d)
                steps.append(d)
                roofs.append(roof)
                tops.append(top)
                d += 0.25
        var land:= (last_solid + COIN_LAND_PAST) if last_solid >= 0.0 else 1.5
        var gravity:= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
        var chosen:= -1.0
        var rise:= COIN_RISE_MIN
        while rise <= COIN_RISE_MAX + 0.001 and chosen < 0.0:
                var vy:= sqrt(2.0 * gravity * rise)
                var drop:= _coins_at.y + rise - floor_y
                var flight:= vy / gravity + sqrt(2.0 * maxf(drop, 0.0) / gravity)
                var clear:= true
                for reach: float in [land, land + COIN_LONG]:
                        var vx:= reach / flight
                        for i in steps.size():
                                if steps [i] >= reach:
                                        break
                                var t:= steps [i] / vx
                                var y:= _coins_at.y + vy * t - 0.5 * gravity * t * t
                                if y < tops [i] + COIN_CLEAR or y > roofs [i] - COIN_ROOF_GAP:
                                        clear = false
                                        break
                        if not clear:
                                break
                if clear:
                        chosen = rise
                rise += 0.1

        _coin_rise = chosen if chosen >= 0.0 else clampf(roofs [0] - COIN_ROOF_GAP - _coins_at.y,
                COIN_RISE_MIN, COIN_RISE_MAX)
        _coin_vy = sqrt(2.0 * gravity * _coin_rise)
        _coin_flight = _coin_vy / gravity + sqrt(2.0 * maxf(_coins_at.y + _coin_rise - floor_y, 0.0) / gravity)
        var at:= Vector3(_coins_at.x, floor_y, _coins_at.z) + _coin_out * land
        if _coin_land != Vector3.INF:


                _coin_land = at
                _coin_planned_frame = frame
                return _coin_land
        var same:= _coin_seen != Vector3.INF and _coin_seen.distance_to(at) < 0.05 and absf(_coin_seen_rise - _coin_rise) < 0.01
        if not same:
                _coin_seen = at
                _coin_seen_rise = _coin_rise
                _coin_seen_frame = frame
        elif frame - _coin_seen_frame >= COIN_PLAN_SETTLE:
                _coin_land = at
                _coin_planned_frame = frame
        return at


const COIN_PLAN_SETTLE:= 30
const COIN_REPLAN:= 600


var _coin_seen:= Vector3.INF
var _coin_seen_rise:= 0.0
var _coin_seen_frame:= 0
var _coin_planned_frame:= 0


static var _coin_query: PhysicsRayQueryParameters3D = null


static func _coin_ray(from: Vector3, to: Vector3, mask: int) -> PhysicsRayQueryParameters3D:
        if _coin_query == null:
                _coin_query = PhysicsRayQueryParameters3D.new()
        _coin_query.from = from
        _coin_query.to = to
        _coin_query.collision_mask = mask
        return _coin_query


func _spare_coin() -> ExtraLifeCoin:
        var oldest: ExtraLifeCoin = null
        for coin in _coin_pool:
                if not coin.is_active():
                        return coin
                if coin.is_held():
                        continue
                if oldest == null or coin.launched_at < oldest.launched_at:
                        oldest = coin
        if oldest != null:
                oldest.park(_coins_at)
                _coins_out -= 1
        return oldest


func _tick_coins(delta: float) -> void:
        if _coins_out <= 0:
                return
        for coin in _coin_pool:
                if coin.is_active() and not coin.tick(delta):
                        coin.park(_coins_at)
                        _coins_out -= 1


func _burst(amount: float) -> void:
        var t:= 0.0
        if amount > 0.0:
                t = clampf(log(1.0 + amount) / log(1.0 + COIN_REF), 0.0, 1.0)

        if _coins != null:
                var coins:= lerpf(float(COIN_MIN), float(COIN_MAX), t)
                _coins.amount_ratio = clampf(coins / float(COIN_MAX), 0.02, 1.0)
                _coins.restart()


        if _sparks != null:
                _sparks.amount_ratio = clampf(lerpf(0.25, 1.0, t), 0.02, 1.0)
                _sparks.restart()
        if _motes != null:
                _motes.amount_ratio = clampf(lerpf(0.2, 1.0, t), 0.02, 1.0)
                _motes.restart()
        _flash_at(lerpf(FLASH_PEAK * 0.3, FLASH_PEAK, t))


func _flash_at(energy: float) -> void:
        if _flash == null:
                return
        if _flash_tween != null and _flash_tween.is_valid():
                _flash_tween.kill()
        _flash.light_energy = 0.0
        _flash.visible = true
        _flash_tween = create_tween()
        _flash_tween.tween_property(_flash, "light_energy", energy, FLASH_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        _flash_tween.tween_property(_flash, "light_energy", 0.0, FLASH_OUT).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        _flash_tween.tween_callback(func() -> void: _flash.visible = false)


func _open_till() -> void:
        if _till_anim == null or _till_key == "":
                return


        if _till_anim.is_playing():
                _till_anim.seek(0.0, true)
        else:
                _till_anim.play(_till_key)


func _run_cycle() -> void:
        if _anim == null or _anim_key == "":
                return
        if _anim.is_playing():


                _replay_wanted = true
                return
        _anim.play(_anim_key)


func _on_cycle_finished(_which: StringName) -> void:
        if _belt != null and _belt.has_strands():
                _replay_wanted = false
                _anim.play(_anim_key)
                return
        if not _replay_wanted:
                return
        _replay_wanted = false
        _anim.play(_anim_key)


func _popup(text: String, colour: Color) -> void:
        var slot:= -1
        for i in _popups.size():
                if not _popups [i].visible:
                        slot = i
                        break
        var l: Label3D
        if slot < 0 and _popups.size() < POPUP_POOL:
                l = _make_label(text, colour, POPUP_PIXEL, POPUP_FONT)
                l.name = "Payout%d" % _popups.size()


                l.outline_size = POPUP_OUTLINE
                l.top_level = true
                add_child(l)
                slot = _popups.size()
                _popups.append(l)
                _popup_tweens.append(null)
        else:
                if slot < 0:
                        slot = _popup_next
                        _popup_next = (slot + 1) % POPUP_POOL
                l = _popups [slot]
                var old:= _popup_tweens [slot]
                if old != null and old.is_valid():
                        old.kill()
                l.text = text
                if l.modulate != colour:
                        l.modulate = colour
        l.visible = true
        var place:= _popup_place()
        var size: float = place [2]


        var from: Vector3 = place [0] + Vector3(
                _rng.randf_range(-0.22, 0.22), _rng.randf_range(-0.08, 0.08),
                _rng.randf_range(-0.22, 0.22)) * size
        l.global_position = from
        l.scale = Vector3.ONE * 0.45 * size


        l.transparency = 1.0

        var t:= create_tween()
        t.set_parallel(true)
        t.tween_property(l, "global_position", from + Vector3(0, place [1], 0), POPUP_LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        t.tween_property(l, "scale", Vector3.ONE * size, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        t.tween_property(l, "transparency", 0.0, 0.12)
        t.tween_property(l, "transparency", 1.0, POPUP_LIFE * 0.42).set_delay(POPUP_LIFE * 0.58)
        t.chain().tween_callback(l.hide)
        _popup_tweens [slot] = t


func _popup_place() -> Array:
        var normal:= [_popup_at, POPUP_RISE, 1.0]
        var vp:= get_viewport()
        var cam:= vp.get_camera_3d() if vp != null else null
        if cam == null:
                return normal
        if cam.is_position_in_frustum(_popup_at) and cam.is_position_in_frustum(_popup_at + Vector3(0, POPUP_RISE * 0.5, 0)):
                return normal
        var eye:= cam.global_position
        var plate:= _popup_at - Vector3(0, POPUP_UP, 0)
        var depth:= (plate - eye).dot(- cam.global_transform.basis.z)

        if depth < 0.2 or eye.distance_to(plate) > POPUP_CLOSE_RANGE:
                return normal
        depth = clampf(depth * 0.8, POPUP_CLOSE_MIN, POPUP_CLOSE_MAX)
        var view:= vp.get_visible_rect().size
        var at:= cam.unproject_position(plate)
        at.x = clampf(at.x, view.x * 0.3, view.x * 0.7)
        at.y = clampf(at.y - view.y * 0.25, view.y * 0.18, view.y * 0.34)
        return [cam.project_position(at, depth), depth * 0.12, clampf(depth * 0.55, 0.45, 1.0)]


func _best_popup(text: String) -> void:
        if _best == null:
                _best = _make_label(text, COL_BEST, POPUP_PIXEL, POPUP_FONT)
                _best.name = "BestSale"
                _best.outline_size = POPUP_OUTLINE
                _best.top_level = true
                add_child(_best)

                _best_white = _make_label(text, Color.WHITE, POPUP_PIXEL, POPUP_FONT)
                _best_white.name = "BestSaleFlash"
                _best_white.outline_size = 0
                _best_white.render_priority = 5
                _best.add_child(_best_white)
                for i in 2:
                        var quad:= QuadMesh.new()
                        quad.size = Vector2(0.55, 0.55)
                        var mat:= ShaderMaterial.new()
                        mat.shader = BEST_GLINT_SHADER
                        mat.render_priority = 6
                        var g:= MeshInstance3D.new()
                        g.name = "BestGlint%d" % i
                        g.mesh = quad
                        g.material_override = mat
                        g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                        _best.add_child(g)
                        _best_glints.append(g)
        if _best_tween != null and _best_tween.is_valid():
                _best_tween.kill()
        _best.text = text
        _best_white.text = text

        var place:= _popup_place()
        var size: float = place [2]
        var from: Vector3 = place [0]
        var half:= UiFont.bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
                POPUP_FONT).x * POPUP_PIXEL * 0.5


        var right:= Vector3.RIGHT
        var up:= Vector3.UP
        var cam:= get_viewport().get_camera_3d()
        if cam != null:
                right = cam.global_transform.basis.x.normalized()
                up = cam.global_transform.basis.y.normalized()


                var view:= get_viewport().get_visible_rect().size
                var depth:= maxf((from - cam.global_position).dot(- cam.global_transform.basis.z), 0.1)
                var across:= cam.project_position(Vector2(0.0, view.y * 0.5), depth).distance_to(
                        cam.project_position(Vector2(view.x, view.y * 0.5), depth))
                size = minf(size, BEST_MAX_WIDTH * across / (half * 2.0))

        _best.global_position = from
        _best.scale = Vector3.ONE * 0.3 * size
        _best.transparency = 1.0
        _best_white.transparency = 0.0
        _best.visible = true
        var cap:= POPUP_FONT * POPUP_PIXEL
        _best_glints [0].position = right * half * 0.92 + up * cap * 0.42
        _best_glints [1].position = - right * half * 0.8 - up * cap * 0.3

        var t:= create_tween()
        t.set_parallel(true)
        t.tween_property(_best, "global_position", from + Vector3(0, place [1] * 0.6, 0), BEST_LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        t.tween_property(_best, "scale", Vector3.ONE * 1.15 * size, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        t.tween_property(_best, "scale", Vector3.ONE * size, 0.2).set_delay(0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
        t.tween_property(_best, "transparency", 0.0, 0.1)
        t.tween_property(_best_white, "transparency", 1.0, 0.55).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        for i in _best_glints.size():
                var mat:= _best_glints [i].material_override as ShaderMaterial
                var at:= 0.16 + 0.34 * i
                mat.set_shader_parameter("power", 0.0)
                mat.set_shader_parameter("spin", 0.0)
                t.tween_property(mat, "shader_parameter/power", 1.0, 0.12).set_delay(at).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                t.tween_property(mat, "shader_parameter/power", 0.0, 0.4).set_delay(at + 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
                t.tween_property(mat, "shader_parameter/spin", PI * 0.5, 0.52).set_delay(at)
        t.tween_property(_best, "transparency", 1.0, BEST_LIFE - BEST_FADE_AT).set_delay(BEST_FADE_AT)
        t.chain().tween_callback(_best.hide)
        _best_tween = t


func _make_label(text: String, colour: Color, pixel: float, size: int) -> Label3D:
        var l:= Label3D.new()
        l.text = text
        l.font = UiFont.bold()
        l.font_size = size
        l.pixel_size = pixel
        l.modulate = colour
        l.outline_size = 22
        l.outline_modulate = Color(0, 0, 0, 0.85)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        l.shaded = false
        l.double_sided = true


        l.render_priority = 4
        l.outline_render_priority = 3
        return l


func _find(node_name: String) -> Node:
        if _model == null:
                return null
        return _model.find_child(node_name, true, false)
