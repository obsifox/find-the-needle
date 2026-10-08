class_name SaleFx
extends Node3D


const FLIGHTS:= 12


const STRAND_FLIGHTS:= 48


const FLY_MIN:= 0.24
const FLY_PER_M:= 0.12
const FLY_MAX:= 0.48

const TILL_FLY:= 0.5

const END_SCALE:= 0.12
const TILL_END_SCALE:= 0.06


const SHRINK_POW:= 1.6


const ARC_LIFT:= 0.18
const ARC_PER_M:= 0.22


const TUMBLE:= 1.2

const TILL_TURNS:= 2.0


const SACK_EMPTY_H:= 0.2
const SACK_FULL_H:= 0.752

const MOUTH_DEPTH:= 0.1

const RANGE:= 30.0


const GULP_STIFF:= 320.0
const GULP_DAMP:= 15.0

const GULP_KICK:= 1.5
const GULP_MIN:= -0.14
const GULP_MAX:= 0.1

const GULP_BULGE:= 0.6

const FULL_WEIGHT:= 80.0

const STRAND_WEIGHT:= 0.06

const GULP_STEP:= 1.0 / 120.0


const GULP_GAP:= 0.2


const DUST_EMITTERS:= 3
const DUST_COUNT:= 12
const DUST_LIFE:= 0.7

const DUST_GAP:= 0.1

const SPARKLE_COUNT:= 28
const SPARKLE_LIFE:= 0.6


const MIN_SCALE:= 0.002


class Flight:
        var root: Node3D

        var model: Node3D

        var parts: Array [MeshInstance3D] = []
        var basis:= Basis.IDENTITY


        var centre:= Vector3.ZERO
        var start:= Vector3.ZERO
        var axis:= Vector3.UP
        var turn:= 0.0
        var t:= 0.0
        var life:= 1.0
        var end_scale:= END_SCALE
        var weight:= 1.0
        var till:= false
        var busy:= false


var sack: Node3D
var sack_mesh: MeshInstance3D
var fill_shape:= -1
var till_at:= Vector3.ZERO


var flown:= 0
var landed:= 0
var gulps:= 0

var _flights: Array [Flight] = []
var _rng:= RandomNumberGenerator.new()

var _strand_mm: MultiMesh
var _strand_mmi: MultiMeshInstance3D
var _s_from: Array [Transform3D] = []
var _s_axis: Array [Vector3] = []
var _s_turn:= PackedFloat32Array()
var _s_t:= PackedFloat32Array()
var _s_life:= PackedFloat32Array()
var _s_tint:= PackedColorArray()
var _s_count:= 0

var _gulp:= 0.0
var _gulp_vel:= 0.0


var _gulp_owed:= 0.0
var _gulp_wait:= 0.0


var tick_usec:= 0

var _dust: Array [GPUParticles3D] = []
var _dust_next:= 0
var _dust_wait:= 0.0
var _sparkle: GPUParticles3D

## lean (mobile / safe load): the dust and sparkle particle layers are built
## lazily at first use, so nothing beyond the hay-strand MultiMesh is created
## -- or compiled -- while the loading screen is up.
var lean:= false


func _ready() -> void:
        _rng.randomize()

        top_level = true
        global_transform = Transform3D.IDENTITY
        for i in FLIGHTS:
                var f:= Flight.new()
                f.root = Node3D.new()
                f.root.name = "SaleFlight%d" % i
                f.root.visible = false
                add_child(f.root)
                _flights.append(f)
        _build_strands()
        if not lean:
                _build_dust()
                _build_sparkle()
        set_process(false)


func watch(p_sack: Node3D, p_mesh: MeshInstance3D, p_fill_shape: int, p_till: Vector3) -> void:
        sack = p_sack
        sack_mesh = p_mesh
        fill_shape = p_fill_shape
        till_at = p_till
        if _strand_mmi != null and sack != null:

                _strand_mmi.custom_aabb = AABB(sack.global_position - Vector3(4, 2, 4),
                        Vector3(8, 6, 8))


func swallow(item: Carryable, strands: float) -> void:
        var w:= _weight(strands)
        if item == null or not is_instance_valid(item) or not _near(item.global_position):
                _land_in_bag(w)
                return
        if not _fly_body(item, w, false):
                _land_in_bag(w)


func swallow_record(rec: Dictionary, run: BeltRun) -> void:
        var w:= _weight(float(rec.get("strands", 0)))


        var f:= _free_flight()
        if f == null or run == null:
                _land_in_bag(w)
                return
        var pose:= run.pose_at(float(rec ["s"]), float(rec ["side"]), float(rec ["lift"]))
        if not _near(pose.origin):
                _land_in_bag(w)
                return
        var parts:= BeltRunBatch.picture_of(int(rec ["kind"]), int(rec ["strands"]))
        if parts.is_empty():
                _land_in_bag(w)
                return
        while f.parts.size() < parts.size():
                var mi:= MeshInstance3D.new()
                mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                f.root.add_child(mi)
                f.parts.append(mi)
        var box:= AABB()
        for i in f.parts.size():
                var mi:= f.parts [i]
                if i >= parts.size():
                        mi.visible = false
                        continue
                var part: Dictionary = parts [i]
                mi.mesh = part ["mesh"]
                mi.transform = part ["local"]
                mi.visible = true
                var b: AABB = mi.transform * mi.mesh.get_aabb()
                box = b if i == 0 else box.merge(b)
        _launch(f, pose, box.get_center(), w, false)


static func strand_of(rb: RigidBody3D) -> Array:
        var xf:= rb.global_transform

        xf.basis.z *= float(rb.get_meta(LiveStrandManager.META_LEN, 1.0))
        var tint: Color = rb.get_meta(LiveStrandManager.META_COLOR, Color.WHITE)


        tint.a = 1.0
        return [xf, tint]


func swallow_strand(seen: Array) -> void:
        var xf: Transform3D = seen [0]
        if _s_count >= STRAND_FLIGHTS or not _near(xf.origin):
                _land_in_bag(STRAND_WEIGHT)
                return
        var i:= _s_count
        _s_count += 1
        _s_from [i] = xf
        _s_axis [i] = _random_axis()
        _s_turn [i] = _rng.randf_range(-2.0, 2.0)
        _s_t [i] = 0.0
        _s_life [i] = _flight_time(xf.origin.distance_to(_mouth())) * _rng.randf_range(0.85, 1.15)
        _s_tint [i] = seen [1]
        _strand_mm.set_instance_color(i, _s_tint [i])
        _strand_mm.visible_instance_count = _s_count
        flown += 1
        set_process(true)


func to_till(item: Carryable) -> void:
        if item == null or not is_instance_valid(item) or not _near(item.global_position):
                return
        if not _fly_body(item, 1.0, true):
                _sparkle_at(till_at)


func _fly_body(item: Carryable, w: float, till: bool) -> bool:
        var f:= _free_flight()
        if f == null:
                return false

        var box:= item.ride_box()
        var pose:= item.global_transform
        var model:= item.detach_model()
        if model == null:
                return false
        for mi in f.parts:
                mi.visible = false
        f.model = model
        f.root.add_child(model)
        _launch(f, pose, box.get_center(), w, till)
        return true


func _launch(f: Flight, pose: Transform3D, centre: Vector3, w: float, till: bool) -> void:
        f.basis = pose.basis
        f.centre = centre
        f.start = pose * centre
        f.t = 0.0
        f.weight = w
        f.till = till
        if till:
                f.life = TILL_FLY
                f.axis = Vector3.UP
                f.turn = TAU * TILL_TURNS
                f.end_scale = TILL_END_SCALE
        else:
                f.life = _flight_time(f.start.distance_to(_mouth()))
                f.axis = _random_axis()
                f.turn = _rng.randf_range(- TUMBLE, TUMBLE)
                f.end_scale = END_SCALE
        f.busy = true
        f.root.visible = true
        _pose(f, 0.0)
        flown += 1
        set_process(true)


func _free_flight() -> Flight:
        for f in _flights:
                if not f.busy:
                        return f
        return null


func _flight_time(dist: float) -> float:
        return clampf(FLY_MIN + FLY_PER_M * dist, FLY_MIN, FLY_MAX)


func _pose(f: Flight, k: float) -> void:
        var at:= _arc(f.start, till_at if f.till else _mouth(), k)
        var s:= maxf(lerpf(1.0, f.end_scale, pow(k, SHRINK_POW)), MIN_SCALE)

        var b:= Basis(f.axis, f.turn * k) * f.basis * s
        f.root.transform = Transform3D(b, at - b * f.centre)


func _arc(from: Vector3, to: Vector3, k: float) -> Vector3:
        var mid:= (from + to) * 0.5
        mid.y = maxf(from.y, to.y) + ARC_LIFT + ARC_PER_M * from.distance_to(to)
        var u:= 0.5 * k + 0.5 * k * k
        var a:= 1.0 - u
        return from * (a * a) + mid * (2.0 * a * u) + to * (u * u)


func _arrive(f: Flight) -> void:
        f.busy = false
        f.root.visible = false
        if f.model != null:
                f.model.queue_free()
                f.model = null
        landed += 1
        if f.till:
                _sparkle_at(till_at)
        else:
                _land_in_bag(f.weight)


func _mouth() -> Vector3:
        if sack == null or not sack.is_inside_tree():
                return global_position
        var fill:= 0.5
        if sack_mesh != null and fill_shape >= 0:
                fill = sack_mesh.get_blend_shape_value(fill_shape)
        var h:= lerpf(SACK_EMPTY_H, SACK_FULL_H, clampf(fill, 0.0, 1.0)) - MOUTH_DEPTH
        return sack.global_transform * Vector3(0.0, maxf(h, 0.05), 0.0)


func _near(p: Vector3) -> bool:
        var cam:= get_viewport().get_camera_3d() if is_inside_tree() else null
        return cam == null or cam.global_position.distance_to(p) < RANGE


func _weight(strands: float) -> float:
        return clampf(strands / FULL_WEIGHT, 0.3, 1.0)


func _random_axis() -> Vector3:
        var v:= Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
        return v.normalized() if v.length_squared() > 0.0001 else Vector3.UP


func _process(delta: float) -> void:
        var started:= Time.get_ticks_usec()
        _tick(delta)
        tick_usec = Time.get_ticks_usec() - started


func _tick(delta: float) -> void:
        var busy:= false
        for f in _flights:
                if not f.busy:
                        continue
                f.t += delta
                if f.t >= f.life:
                        _arrive(f)
                        continue
                _pose(f, f.t / f.life)
                busy = true
        if _tick_strands(delta):
                busy = true
        if _tick_gulp(delta):
                busy = true
        _dust_wait = maxf(_dust_wait - delta, 0.0)
        if _dust_wait > 0.0:
                busy = true
        if not busy:
                set_process(false)


func _tick_strands(delta: float) -> bool:
        if _s_count == 0:
                return false
        var mouth:= _mouth()
        var i:= 0
        while i < _s_count:
                _s_t [i] += delta
                var k:= _s_t [i] / _s_life [i]
                if k >= 1.0:


                        _s_count -= 1
                        if i < _s_count:
                                _s_from [i] = _s_from [_s_count]
                                _s_axis [i] = _s_axis [_s_count]
                                _s_turn [i] = _s_turn [_s_count]
                                _s_t [i] = _s_t [_s_count]
                                _s_life [i] = _s_life [_s_count]
                                _s_tint [i] = _s_tint [_s_count]
                                _strand_mm.set_instance_color(i, _s_tint [i])
                        landed += 1
                        _land_in_bag(STRAND_WEIGHT)
                        continue
                var from:= _s_from [i]
                var s:= maxf(lerpf(1.0, END_SCALE, pow(k, SHRINK_POW)), MIN_SCALE)
                var b:= Basis(_s_axis [i], _s_turn [i] * k) * from.basis * s
                _strand_mm.set_instance_transform(i, Transform3D(b, _arc(from.origin, mouth, k)))
                i += 1
        _strand_mm.visible_instance_count = _s_count
        return _s_count > 0


func _land_in_bag(w: float) -> void:
        _gulp_owed += w
        gulps += 1
        if _dust_wait <= 0.0 and sack != null and _near(sack.global_position):
                _dust_wait = DUST_GAP
                if _dust.is_empty() and lean:
                        _build_dust()
                if _dust.size() > 0:
                        var p:= _dust [_dust_next]
                        _dust_next = (_dust_next + 1) % _dust.size()
                        p.global_position = _mouth() + Vector3.UP * MOUTH_DEPTH
                        p.amount_ratio = clampf(lerpf(0.35, 1.0, w), 0.05, 1.0)
                        p.restart()
        set_process(true)


func _tick_gulp(delta: float) -> bool:
        if sack == null or not is_instance_valid(sack):
                return false
        _gulp_wait = maxf(_gulp_wait - delta, 0.0)
        if _gulp_owed > 0.0 and _gulp_wait <= 0.0:
                _gulp_vel -= GULP_KICK * minf(_gulp_owed, 1.0)
                _gulp_owed = 0.0
                _gulp_wait = GULP_GAP
        if _gulp == 0.0 and _gulp_vel == 0.0 and _gulp_owed == 0.0:
                return false
        var left:= delta
        while left > 0.0:
                var dt:= minf(left, GULP_STEP)
                left -= dt
                _gulp_vel += (- _gulp * GULP_STIFF - _gulp_vel * GULP_DAMP) * dt
                _gulp = clampf(_gulp + _gulp_vel * dt, GULP_MIN, GULP_MAX)
        if absf(_gulp) < 0.0001 and absf(_gulp_vel) < 0.001:
                _gulp = 0.0
                _gulp_vel = 0.0
                sack.scale = Vector3.ONE

                return _gulp_owed > 0.0


        var side:= 1.0 - _gulp * GULP_BULGE
        sack.scale = Vector3(side, 1.0 + _gulp, side)
        return true


func _build_strands() -> void:
        _strand_mm = MultiMesh.new()
        _strand_mm.transform_format = MultiMesh.TRANSFORM_3D
        _strand_mm.use_colors = true
        _strand_mm.mesh = StrandFactory.strand_mesh()
        _strand_mm.instance_count = STRAND_FLIGHTS
        _strand_mm.visible_instance_count = 0
        _strand_mmi = MultiMeshInstance3D.new()
        _strand_mmi.name = "SaleStrands"
        _strand_mmi.multimesh = _strand_mm
        _strand_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(_strand_mmi)
        _s_from.resize(STRAND_FLIGHTS)
        _s_axis.resize(STRAND_FLIGHTS)
        _s_turn.resize(STRAND_FLIGHTS)
        _s_t.resize(STRAND_FLIGHTS)
        _s_life.resize(STRAND_FLIGHTS)
        _s_tint.resize(STRAND_FLIGHTS)


func _build_dust() -> void:
        var quad:= QuadMesh.new()
        quad.size = Vector2(0.12, 0.12)
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
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
        pm.emission_sphere_radius = 0.14
        pm.direction = Vector3.UP
        pm.spread = 55.0
        pm.initial_velocity_min = 0.5
        pm.initial_velocity_max = 1.3
        pm.gravity = Vector3(0, -1.6, 0)
        pm.damping_min = 1.5
        pm.damping_max = 3.0
        pm.angle_min = 0.0
        pm.angle_max = 360.0
        pm.scale_min = 0.6
        pm.scale_max = 1.4
        pm.scale_curve = _curve([[0.0, 0.4], [0.25, 1.0], [1.0, 0.2]])
        pm.color_ramp = _ramp([
                [0.0, Color(0.94, 0.86, 0.66, 0.0)],
                [0.12, Color(0.94, 0.88, 0.7, 0.55)],
                [1.0, Color(0.72, 0.62, 0.44, 0.0)]])
        for i in DUST_EMITTERS:
                _dust.append(_emitter("SaleDust%d" % i, quad, pm, DUST_COUNT, DUST_LIFE, 0.9))


func _build_sparkle() -> void:
        var quad:= QuadMesh.new()
        quad.size = Vector2(0.07, 0.07)
        var m:= StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.billboard_keep_scale = true
        m.albedo_texture = _soft_dot()
        m.vertex_color_use_as_albedo = true
        m.disable_receive_shadows = true
        quad.material = m

        var pm:= ParticleProcessMaterial.new()
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
        pm.emission_sphere_radius = 0.06
        pm.direction = Vector3.UP
        pm.spread = 180.0
        pm.initial_velocity_min = 0.9
        pm.initial_velocity_max = 2.2
        pm.gravity = Vector3(0, -2.5, 0)
        pm.damping_min = 2.0
        pm.damping_max = 3.5
        pm.scale_min = 0.5
        pm.scale_max = 1.3
        pm.scale_curve = _curve([[0.0, 1.0], [0.6, 0.7], [1.0, 0.0]])
        pm.color_ramp = _ramp([
                [0.0, Color(1.0, 0.97, 0.85, 1.0)],
                [0.35, Color(1.0, 0.82, 0.35, 0.9)],
                [1.0, Color(0.9, 0.55, 0.15, 0.0)]])
        _sparkle = _emitter("SaleSparkle", quad, pm, SPARKLE_COUNT, SPARKLE_LIFE, 1.0)


func _sparkle_at(at: Vector3) -> void:
        if _sparkle == null and lean:
                _build_sparkle()
        if _sparkle == null or not _near(at):
                return
        _sparkle.global_position = at
        _sparkle.restart()


func _emitter(emitter_name: String, mesh: Mesh, pm: ParticleProcessMaterial,
                count: int, life: float, burstiness: float) -> GPUParticles3D:
        var p:= GPUParticles3D.new()
        p.name = emitter_name
        p.amount = count
        p.lifetime = life
        p.one_shot = true
        p.explosiveness = burstiness
        p.emitting = false
        p.draw_pass_1 = mesh
        p.process_material = pm
        p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        p.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3, 3, 3))
        add_child(p)
        return p


static func _soft_dot() -> GradientTexture2D:
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


static func _ramp(stops: Array) -> GradientTexture1D:
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


static func _curve(points: Array) -> CurveTexture:
        var c:= Curve.new()
        for p in points:
                c.add_point(Vector2(float(p [0]), float(p [1])))
        var t:= CurveTexture.new()
        t.curve = c
        return t
