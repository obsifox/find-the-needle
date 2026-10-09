class_name DeliveryTruck
extends Node3D


const MODEL:= "res://assets/models/compiled/delivery_truck.scn"


const SPEC:= "res://assets/models/delivery_truck_materials.json"

const N_GATE:= "Marker_Gate"
const N_DUMPER:= "Dumper"
const A_DRIVE:= "Drive"
const A_GATE:= "TailgateDrop"


const MODEL_YAW:= PI


const PARK_IN:= -2.02


const STAGE_OUT:= 13.0


const ROAD_SPEED:= 2.2
const CLIP_SPEED:= 5.72 / 2.042


const AWAY_SPEED:= 7.0
const RAMP_OVER:= 8.0


const VANISH_PAST:= 22.0


const ARRIVE_FROM_PAST:= 16.0


const FADE_FROM_PAST:= 8.0
const FADE_GONE_PAST:= VANISH_PAST


const BRAKE_DISTANCE:= 2.2


const CREEP_SPEED:= 0.45


const T_ROLL_IN:= 1.6
const T_ROLL_OUT:= 1.9


const T_GATE_AFTER_STOP:= 0.55


const T_READY_GIVE_UP:= 6.0


const REAR_REACH:= 2.0


const TOP_REACH:= 0.35


const SIDE_INSET:= 0.06


const STACK_MAX:= 30
const STACK_ACROSS:= 3
const STACK_DEEP:= 2


const HEAD_CLEAR:= 0.104


const REST_SPEED:= 0.55


const ENGINE_GAIN:= -6.0


const ENGINE_PITCH_IDLE:= 0.8
const ENGINE_PITCH_ROAD:= 1.05


const ENGINE_PITCH_REVERSE:= 0.1

enum State { AWAY, ARRIVING, PARKED, LEAVING }


signal parked

signal departed

var door: BayDoor
var warehouse: Warehouse

## MOBILE FIX (v2.3.0, the 74% stand crash): staged builds mount only the
## model in _ready(); the world calls build_staged_steps() AFTER the loading
## screen is gone, one sub-step per rendered frame, each with its own
## crash-report breadcrumb. The v2.2.0 report named stand:truck -- the
## truck's first GPU resources (compiled model upload, skin buffers, skin
## materials) killed the Mali Vulkan driver the same way the belt's first
## draws did in v2.1.0.
var staged_build:= false

var state: State = State.AWAY

var _model: Node3D
var _anim: AnimationPlayer
var _hull: StaticBody3D
var _bed_area: Area3D
var _stack: Node3D


var _engine_voice:= -1

var _reversing:= false


var _ground_drop:= 0.0
var _bed:= AABB()


var _deck_y:= 0.0


var _travel:= - STAGE_OUT
var _target:= - STAGE_OUT
var _clock:= 0.0


var _fired:= 0


var _gate_down:= false


var _drawables: Array [GeometryInstance3D] = []


func _ready() -> void:
        if staged_build:
                # Staged build: the truck must not draw a single pixel while
                # it is being assembled, so it stays hidden until the last
                # step places it (it is parked away from the yard anyway).
                visible = false
                CrashReport.note_doing("truck:model")
                _build_model()
                return
        _build_model()
        _skin()
        _measure()
        _build_hull()
        _build_bed_area()
        _build_stack()
        _place(_travel)


        visible = state != State.AWAY
        set_physics_process(true)
        if warehouse != null:


                warehouse.rebuilt.connect(_on_shed_rebuilt)


## One sub-build per rendered frame (staged builds only), mirroring the
## stand's build_staged_steps(): between steps the render thread gets a
## frame in which whatever the step above just added is actually drawn (or
## in the truck's case, uploaded), so a resource or pipeline the mobile
## driver cannot digest is blamed on the exact step that added it. The
## truck sits hidden at its away-position the whole time; nothing here
## draws it -- its first real draws happen at the first delivery, whose
## path carries its own breadcrumbs (truck:arrive, truck:roll).
func build_staged_steps() -> void:
        var steps: Array = [
                ["truck:skin", _skin],
                ["truck:measure", _measure],
                ["truck:hull", _build_hull],
                ["truck:bed", _build_bed_area],
                ["truck:stack", _build_stack],
        ]
        for step: Array in steps:
                CrashReport.note_doing(str(step [0]))
                (step [1] as Callable).call()
                await get_tree().process_frame
        CrashReport.note_doing("truck:place")
        _place(_travel)
        visible = state != State.AWAY
        set_physics_process(true)
        if warehouse != null:
                warehouse.rebuilt.connect(_on_shed_rebuilt)
        CrashReport.note_doing("truck:done")


func _build_model() -> void:
        var packed: PackedScene = load(MODEL)
        if packed == null:
                push_error("DeliveryTruck: cannot load %s" % MODEL)
                return
        _model = packed.instantiate()
        _model.name = "Model"
        (_model as Node3D).rotation.y = MODEL_YAW
        add_child(_model)
        var players:= _model.find_children("*", "AnimationPlayer", true, false)
        _anim = (players [0] if not players.is_empty() else null) as AnimationPlayer
        if _anim == null:
                push_warning("DeliveryTruck: model has no AnimationPlayer, the truck will slide on locked wheels")
        else:
                _loop(A_DRIVE)
                _anim.animation_finished.connect(_on_clip_finished)


        if _model.find_child(N_GATE, true, false) == null:
                push_warning("DeliveryTruck: model has no %s, the tailgate will not open" % N_GATE)
        for mi: Node in _model.find_children("*", "GeometryInstance3D", true, false):
                _drawables.append(mi as GeometryInstance3D)


func _on_clip_finished(clip: StringName) -> void:
        if clip == A_GATE and state == State.ARRIVING:
                _gate_down = true


func _loop(clip: String) -> void:
        if _anim == null or not _anim.has_animation(clip):
                return
        _anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


func _skin() -> void:
        if _model == null:
                return
        var spec:= _load_spec()
        if spec.is_empty():
                push_warning("DeliveryTruck: no material table at %s, the truck will render untextured" % SPEC)
                return
        var shader: Shader = load(HayCompressor.SHADER)
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
                                built [key] = HayCompressor.make_material(key, spec, shader)
                        if built [key] == null:
                                missed [key] = true
                                continue
                        mi.set_surface_override_material(i, built [key])
        if not missed.is_empty():
                push_warning("DeliveryTruck: no table entry for %s" % ", ".join(missed.keys()))


static func _load_spec() -> Dictionary:
        var res: JSON = load(SPEC) as JSON
        if res != null and typeof(res.data) == TYPE_DICTIONARY:
                return res.data
        if not FileAccess.file_exists(SPEC):
                return { }
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
        return parsed if typeof(parsed) == TYPE_DICTIONARY else { }


func _measure() -> void:
        if _model == null:
                return
        var whole:= _mesh_bounds(_model)
        _ground_drop = - whole.position.y
        var dumper:= _model.find_child(N_DUMPER, true, false) as Node3D
        if dumper == null:
                push_warning("DeliveryTruck: model has no %s, the bed cannot be measured" % N_DUMPER)
                _bed = AABB(Vector3(-1.19, -0.53, -2.34), Vector3(2.38, 1.12, 4.36))
                return
        _bed = _mesh_bounds(dumper)
        var gate:= _model.find_child(N_GATE, true, false) as Node3D


        _deck_y = to_local(gate.global_position).y if gate != null else _bed.position.y + _bed.size.y * 0.28


func _mesh_bounds(from: Node) -> AABB:
        var out:= AABB()
        var first:= true
        var to_local_xform:= global_transform.affine_inverse()
        var list: Array [Node] = from.find_children("*", "MeshInstance3D", true, false)
        if from is MeshInstance3D:
                list.append(from)
        for n in list:
                var mi:= n as MeshInstance3D
                if mi.mesh == null:
                        continue
                var box:= to_local_xform * mi.global_transform * mi.mesh.get_aabb()
                out = box if first else out.merge(box)
                first = false
        return out


func _build_hull() -> void:
        _hull = StaticBody3D.new()
        _hull.name = "Hull"
        _hull.collision_layer = Cfg.L_WORLD
        _hull.collision_mask = 0
        _hull.add_to_group(PowerGrid.CABLE_TRANSPARENT)
        add_child(_hull)

        var floor_y:= - _ground_drop
        var bed_floor:= _deck_y
        var bed_top:= _bed.position.y + _bed.size.y
        var half_w:= _bed.size.x * 0.5
        var z0:= _bed.position.z
        var z1:= _bed.end.z
        var wall_t:= 0.1


        _hull_box("Bed_Floor", Vector3(_bed.size.x, 0.12, z1 - z0),
                Vector3(_bed.get_center().x, bed_floor - 0.06, (z0 + z1) * 0.5))
        for s in [-1.0, 1.0]:
                _hull_box("Bed_Side", Vector3(wall_t, bed_top - bed_floor, z1 - z0),
                        Vector3(_bed.get_center().x + s * half_w, (bed_floor + bed_top) * 0.5,
                                (z0 + z1) * 0.5))
        _hull_box("Bed_Head", Vector3(_bed.size.x, bed_top - bed_floor, wall_t),
                Vector3(_bed.get_center().x, (bed_floor + bed_top) * 0.5, z0))

        _hull_box("Underframe", Vector3(_bed.size.x * 0.86, bed_floor - floor_y, z1 - z0),
                Vector3(_bed.get_center().x, (floor_y + bed_floor) * 0.5, (z0 + z1) * 0.5))

        var nose:= _mesh_bounds(_model).position.z
        _hull_box("Cab", Vector3(_bed.size.x * 0.92, bed_top - floor_y, z0 - nose),
                Vector3(_bed.get_center().x, (floor_y + bed_top) * 0.5, (nose + z0) * 0.5))
        _set_hull(false)


func _hull_box(box_name: String, size: Vector3, at: Vector3) -> void:
        if size.x <= 0.01 or size.y <= 0.01 or size.z <= 0.01:
                return
        var shape:= BoxShape3D.new()
        shape.size = size
        var cs:= CollisionShape3D.new()
        cs.name = box_name
        cs.shape = shape
        cs.position = at
        _hull.add_child(cs)


func _set_hull(on: bool) -> void:
        if _hull == null:
                return
        _hull.collision_layer = Cfg.L_WORLD if on else 0
        for c in _hull.get_children():
                var cs:= c as CollisionShape3D
                if cs != null:
                        cs.disabled = not on
        if not on:


                _wake_sleepers()


func _wake_sleepers() -> void:
        if not is_inside_tree() or _hull == null:
                return
        var box:= AABB()
        var first:= true
        for c in _hull.get_children():
                var cs:= c as CollisionShape3D
                if cs == null:
                        continue
                var shape:= cs.shape as BoxShape3D
                if shape == null:
                        continue
                var one:= AABB(cs.position - shape.size * 0.5, shape.size)
                box = one if first else box.merge(one)
                first = false
        if first:
                return


        box = box.grow(0.15)
        var query:= PhysicsShapeQueryParameters3D.new()
        var probe:= BoxShape3D.new()
        probe.size = box.size
        query.shape = probe
        query.transform = global_transform * Transform3D(Basis(), box.get_center())
        query.collision_mask = Cfg.L_PROP | Cfg.L_STRAND
        query.collide_with_areas = false
        for hit in get_world_3d().direct_space_state.intersect_shape(query, 64):
                var rb:= hit.get("collider") as RigidBody3D
                if rb != null:
                        Carryable.lost_floor(rb)


func _build_bed_area() -> void:
        _bed_area = Area3D.new()
        _bed_area.name = "BedVolume"
        _bed_area.collision_layer = 0
        _bed_area.collision_mask = Cfg.L_PROP
        _bed_area.monitorable = false
        _bed_area.monitoring = false


        _bed_box("Bed",
                Vector3(_bed.position.x + SIDE_INSET, _deck_y - 0.05, _bed.position.z),
                Vector3(_bed.end.x - SIDE_INSET,
                        _bed.position.y + _bed.size.y + TOP_REACH, _bed.end.z))


        _bed_box("Doorway",
                Vector3(_bed.position.x + SIDE_INSET, - _ground_drop + 0.02, _bed.end.z),
                Vector3(_bed.end.x - SIDE_INSET, _deck_y + 0.55,
                        _bed.end.z + REAR_REACH))
        add_child(_bed_area)


func _bed_box(box_name: String, lo: Vector3, hi: Vector3) -> void:
        var box:= BoxShape3D.new()
        box.size = hi - lo
        var cs:= CollisionShape3D.new()
        cs.name = box_name
        cs.shape = box
        cs.position = (lo + hi) * 0.5
        _bed_area.add_child(cs)


func _build_stack() -> void:
        _stack = Node3D.new()
        _stack.name = "Load"
        add_child(_stack)


func _place(at: float) -> void:
        _travel = at
        _fade(at)
        if door == null:
                position = Vector3(0.0, _ground_drop, at)
                return
        var p:= door.inboard_point(at)
        p.y += _ground_drop
        position = p
        rotation.y = door.rotation.y


func _on_shed_rebuilt() -> void:
        _place(_travel)


func deck_height() -> float:
        return _deck_y


func loading_point() -> Vector3:
        return to_global(Vector3(_bed.get_center().x, - _ground_drop,
                _bed.end.z + REAR_REACH * 0.55))


func bay_point() -> Vector3:
        var inboard:= PARK_IN + _bed.end.z + REAR_REACH * 0.55
        if door == null:
                return Vector3(0.0, 0.0, inboard)
        return door.inboard_point(inboard)


func is_parked() -> bool:
        return state == State.PARKED


func is_away() -> bool:
        return state == State.AWAY


func arrive() -> void:
        if state != State.AWAY:
                return


        # Breadcrumbs for the truck's first real draws (staged builds: the
        # loading window never drew the truck). If the driver ever faults on
        # them, the report will say so instead of pointing at gameplay.
        CrashReport.note_doing("truck:arrive")
        _place(_gate_out(- ARRIVE_FROM_PAST))
        _target = PARK_IN
        _clock = 0.0
        _fired = 0
        state = State.ARRIVING
        visible = true
        _open_yard_gate(true)
        if door != null:


                door.held = true
                door.open()


func depart() -> void:
        if state != State.PARKED:
                return
        _target = _gate_out(- VANISH_PAST)
        _clock = 0.0
        _fired = 0
        state = State.LEAVING
        _set_hull(false)
        _bed_area.monitoring = false
        _gate_down = false


        Audio.play_3d("truck_gate_up", global_position, -3.0)
        Audio.play_3d("truck_release", global_position, -5.0)
        if _anim != null and _anim.has_animation(A_GATE):
                _anim.play_backwards(A_GATE)


        _open_yard_gate(true)


func snap_parked() -> void:
        _place(PARK_IN)
        _target = PARK_IN
        state = State.PARKED
        visible = true
        _clock = 0.0
        _fired = 0
        _set_hull(true)
        _bed_area.monitoring = true
        _gate_down = true
        if door != null:


                door.held = true
                door.set_open_amount(1.0)
        if _anim != null and _anim.has_animation(A_GATE):
                _anim.play(A_GATE)
                _anim.seek(_anim.get_animation(A_GATE).length, true)
                _anim.pause()


func _physics_process(delta: float) -> void:
        match state:
                State.ARRIVING:
                        _run_arriving(delta)
                State.LEAVING:
                        _run_leaving(delta)
                _:
                        pass


func _run_arriving(delta: float) -> void:
        _clock += delta
        if _clock < T_ROLL_IN:
                return
        if _fired < 1:
                _fired = 1
                _roll(true)
        if _drive(delta):
                return


        if _fired < 2:
                _fired = 2
                _clock = 0.0
                _roll_stop()


                Audio.play_3d("truck_brake", global_position, -4.0)
                _set_hull(true)
                return
        if _fired < 3 and _clock >= T_GATE_AFTER_STOP:
                _fired = 3
                _gate_down = false
                if _anim != null and _anim.has_animation(A_GATE):
                        _anim.play(A_GATE)
                else:


                        _gate_down = true


                Audio.play_3d("truck_gate_down", global_position, -3.0)
                Audio.play_3d("machine_clunk", global_position, 1.0)
        if _fired < 4 and (_gate_down or _clock >= T_READY_GIVE_UP):
                _fired = 4
                _bed_area.monitoring = true
                state = State.PARKED
                _open_yard_gate(false)
                parked.emit()


func _run_leaving(delta: float) -> void:
        _clock += delta
        if _clock < T_ROLL_OUT:
                return
        if _fired < 1:
                _fired = 1
                _roll(false)
        if _drive(delta):
                return
        if _fired < 3:
                _fired = 3
                _roll_stop()


                visible = false
                _open_yard_gate(false)


                if door != null:
                        door.held = false
                state = State.AWAY
                _clear_stack()
                departed.emit()


func _drive(delta: float) -> bool:
        var gap:= _target - _travel
        if absf(gap) <= 0.02:
                _place(_target)
                return false
        var speed:= _road_speed()
        if absf(gap) < BRAKE_DISTANCE:
                speed = maxf(CREEP_SPEED, speed * absf(gap) / BRAKE_DISTANCE)
        var step:= minf(speed * delta, absf(gap))
        _place(_travel + step * signf(gap))
        _engine(speed)
        if _anim != null:
                _anim.speed_scale = (speed / CLIP_SPEED) * (-1.0 if gap > 0.0 else 1.0)
        return true


func _fade(at: float) -> void:
        if _drawables.is_empty():
                return
        var fence:= _yard_gate()
        if fence == null:
                return
        var out:= absf(at)
        var t:= clampf(inverse_lerp(fence.reach_out + FADE_FROM_PAST,
                fence.reach_out + FADE_GONE_PAST, out), 0.0, 1.0)
        for mi in _drawables:
                mi.transparency = t


func _road_speed() -> float:
        var out:= absf(_travel)
        if out <= STAGE_OUT:
                return ROAD_SPEED
        return lerpf(ROAD_SPEED, AWAY_SPEED,
                clampf((out - STAGE_OUT) / RAMP_OVER, 0.0, 1.0))


func _gate_out(past: float) -> float:
        var fence:= _yard_gate()
        if fence == null:
                return - STAGE_OUT
        return - fence.reach_out + past


func away_point() -> Vector3:
        var at:= _gate_out(- VANISH_PAST)
        if door == null:
                return Vector3(0.0, _ground_drop, at)
        return door.inboard_point(at)


func _yard_gate() -> YardFence:
        if warehouse == null:
                return null
        return warehouse.yard_fence()


func _open_yard_gate(open: bool) -> void:
        var fence:= _yard_gate()
        if fence != null:
                fence.set_open(open)


func _roll(reversing: bool) -> void:
        _reversing = reversing
        CrashReport.note_doing("truck:roll")
        if _engine_voice < 0:
                _engine_voice = Audio.loop_acquire("truck_engine")
        _engine(ROAD_SPEED)
        if _anim == null or not _anim.has_animation(A_DRIVE):
                return
        _anim.speed_scale = (ROAD_SPEED / CLIP_SPEED) * (-1.0 if reversing else 1.0)
        _anim.play(A_DRIVE)


func _roll_stop() -> void:
        _engine_off()
        if _anim == null:
                return
        _anim.speed_scale = 1.0
        if _anim.current_animation == A_DRIVE:
                _anim.stop()


func _engine(speed: float) -> void:
        if _engine_voice < 0:
                return
        var t: float = clampf(speed / ROAD_SPEED, 0.0, 1.0)
        var pitch:= lerpf(ENGINE_PITCH_IDLE, ENGINE_PITCH_ROAD, t)
        if _reversing:
                pitch += ENGINE_PITCH_REVERSE
        Audio.loop_update(_engine_voice, global_position, ENGINE_GAIN, pitch)


func _engine_off() -> void:
        if _engine_voice >= 0:
                Audio.loop_release(_engine_voice)
                _engine_voice = -1


func _exit_tree() -> void:


        _engine_off()


func settled_items() -> Array [Carryable]:
        var out: Array [Carryable] = []
        if _bed_area == null or not _bed_area.monitoring:
                return out
        for b in _bed_area.get_overlapping_bodies():
                var item:= b as Carryable
                if item == null or item.is_held():
                        continue
                if item.linear_velocity.length() > REST_SPEED:
                        continue
                out.append(item)
        return out


func stack_one(item_id: String) -> void:
        if _stack == null or _stack.get_child_count() >= STACK_MAX:
                return
        var mesh:= load_mesh(item_id)
        if mesh == null:
                return
        var mi:= MeshInstance3D.new()
        mi.mesh = mesh


        _skin_load(item_id, mi)
        var i:= _stack.get_child_count()
        var size:= _item_size(item_id)
        var per_course:= STACK_ACROSS * STACK_DEEP
        var course:= i / per_course
        var within:= i % per_course
        var col:= within % STACK_ACROSS
        var row:= within / STACK_ACROSS


        mi.position = Vector3(
                _bed.get_center().x + (float(col) - float(STACK_ACROSS - 1) * 0.5) * size.x,
                _deck_y + float(course) * size.y,
                _bed.position.z + HEAD_CLEAR + size.z * (0.5 + float(row)))


        mi.rotation.y = deg_to_rad(float((i * 37) % 13) - 6.0) * 0.5
        _stack.add_child(mi)


func _clear_stack() -> void:
        if _stack == null:
                return
        for c in _stack.get_children():
                c.queue_free()


static func load_mesh(item_id: String) -> Mesh:
        match item_id:
                "foiled_bale":
                        return FoiledBale.shared_mesh()
                "eco_brick":
                        return EcoBrick.shared_mesh()
                "hay_pulp":
                        return HayPulp.shared_mesh()
                "paper_roll":
                        return PaperRoll.shared_mesh()
                "feed_disc":
                        return FeedDisc.shared_mesh()
                _:
                        return HayBale.shared_mesh()


static func can_draw(item_id: String) -> bool:
        return item_id in ["hay_bale", "foiled_bale", "eco_brick", "hay_pulp",
                "paper_roll", "feed_disc"]


static func _skin_load(item_id: String, mi: MeshInstance3D) -> void:
        match item_id:
                "foiled_bale":
                        FoiledBale.skin(mi)
                "eco_brick":
                        EcoBrick.skin(mi)
                "hay_pulp":
                        HayPulp.skin(mi)
                "paper_roll":
                        PaperRoll.skin(mi)
                "feed_disc":

                        pass
                _:
                        HayBale.skin(mi)


static func _item_size(item_id: String) -> Vector3:
        match item_id:
                "foiled_bale":
                        return Cfg.WRAPPER_FOILED_SIZE
                "eco_brick":
                        return Cfg.ECO_BRICK_SIZE + Vector3(0.012, 0.0, 0.012)
                "hay_pulp":
                        return Cfg.PULPER_SLAB_SIZE
                "paper_roll":
                        return Cfg.PAPER_ROLL_SIZE
                "feed_disc":
                        return Cfg.FEED_DISC_SIZE
                _:
                        return Cfg.COMPRESSOR_BALE_SIZE
