class_name RoboticArm
extends StaticBody3D


static var MODEL: PackedScene = load("res://compiled/robotic_arm_game_ready.scn")


const SPEC:= "res://assets/models/robotic_arm_materials.json"

const UPPER_ARM:= 1.55
const FOREARM:= 1.4
const TOOL_OFFSET:= 0.6
const SHOULDER_HEIGHT:= 1.07
const TOOL_PITCH:= deg_to_rad(165.0)
const MIN_REACH:= 0.7


const REACH_FRACTION:= 0.98


const RADIUS_SHOW_SECONDS:= 120.0


const COL_RING:= Color(0.4, 0.78, 1.0, 0.55)
const RING_BAND:= 0.06

const RING_LIFT:= 0.03


const FIELD_FLOOR:= 0.03


const FIELD_BASE_CLEAR:= 0.2


const BASE_RADIUS:= 0.76
const BASE_HEIGHT:= 0.92


const BASE_CAP_SLOPE:= deg_to_rad(65.0)
const BASE_CAP_SIDES:= 16


const AIM_HEIGHT:= 4.45
const AIM_RADIUS:= BASE_RADIUS


const BOOM_CEILING:= [
        [1.5, 3.1],
        [1.75, 3.09],
        [2.0, 3.05],
        [2.25, 2.96],
        [2.5, 2.82],
        [2.75, 2.66],
        [3.0, 2.41],
        [3.25, 2.3],
        [3.5, 1.85],
        [3.75, 0.0],
]


const CLAW_OPEN:= deg_to_rad(-10.0)
const CLAW_CLOSED:= deg_to_rad(22.0)

const HOME_TARGET:= Vector3(0.0, 1.35, 2.7)
const PICK_CLEARANCE:= 0.55
const DROP_CLEARANCE:= 0.55
const HAY_CLUSTER_RADIUS:= 0.62
const SCAN_INTERVAL:= 0.45
const RELEASE_COOLDOWN:= 3.0


const ARM_DROP_MUTE:= 1.5


const HOLD_RETRY:= 0.25


const HOLD_CLEAR_SECONDS:= 0.75


const ALERT_TRIES:= 2


const ARM_CYCLE_LEN:= 6.2


const PICK_NEEDLE:= 1 << 0
const PICK_LOOSE:= 1 << 1
const PICK_WAD:= 1 << 2
const PICK_BALE:= 1 << 3
const PICK_BRICK:= 1 << 4
const PICK_FOILED:= 1 << 5
const PICK_PILE:= 1 << 6
const PICK_PULP:= 1 << 7


const PICK_ROLL:= 1 << 8

const PICK_DISC:= 1 << 9
const PICK_ALL:= (1 << 10) - 1


const PICK_LOCKED:= PICK_NEEDLE


const PICK_KINDS: Array [Dictionary] = [
        { "bit": PICK_NEEDLE, "id": "needle", "name": "Needles",
                "note": "always picked up" },
        { "bit": PICK_LOOSE, "id": "loose", "name": "Loose hay",
                "note": "hay on the floor" },
        { "bit": PICK_WAD, "id": "wad", "name": "Hay wads",
                "note": "bundles of loose hay" },
        { "bit": PICK_BALE, "id": "bale", "name": "Hay bales",
                "note": "what the compressor makes" },
        { "bit": PICK_BRICK, "id": "brick", "name": "Eco bricks",
                "note": "what the pelletizer makes" },
        { "bit": PICK_FOILED, "id": "foiled", "name": "Wrapped bales",
                "note": "bales from the wrapper" },
        { "bit": PICK_PILE, "id": "pile", "name": "The pile",
                "note": "digs the haystack" },
        { "bit": PICK_PULP, "id": "pulp", "name": "Wet pulp",
                "note": "from the pulper" },
        { "bit": PICK_ROLL, "id": "roll", "name": "Paper rolls",
                "note": "from the paper mill" },
        { "bit": PICK_DISC, "id": "disc", "name": "Feed discs",
                "note": "from the feed disc press" },
]

const HIDDEN_HELPERS:= [
        "COLLIDER_Base", "COLLIDER_UpperArm", "COLLIDER_Forearm", "COLLIDER_Tool",
        "AREA_HayPickup",
]

enum Phase {
        IDLE,
        APPROACH_PICK,
        DESCEND_PICK,
        CLOSE_CLAWS,
        LIFT,
        SWING_DROP,
        DESCEND_DROP,
        OPEN_CLAWS,
        RETURN_HOME,


        PARK_HOLD,
}

var builds: BuildManager
var live: LiveStrandManager
var field: HayField


var props: PropManager
var tier_index:= Cfg.ROBOT_ARM_DEFAULT_TIER


var paid_cost:= -1.0


var legacy_refit:= false


var _ring: MeshInstance3D

var _ring_mat: StandardMaterial3D
static var _ring_shared: StandardMaterial3D
static var _ring_meshes: Dictionary = { }

var _peek_lit:= false

var _plate_lit:= false

var _radius_left:= 0.0


var _feeds: MeshInstance3D
var _feeds_check:= 0.0
static var _feeds_mat: StandardMaterial3D


var accept_mask:= PICK_ALL
var placement_preview:= false

var _model: Node3D

var _ports: Array [Node3D] = []
var _collider: CollisionShape3D

var _cap: CollisionShape3D


var _aim_shape: CollisionShape3D
var _base_yaw: Node3D
var _shoulder: Node3D
var _elbow: Node3D
var _tool: Node3D
var _socket: Node3D
var _claws: Array [Node3D] = []

var _phase: Phase = Phase.IDLE
var _phase_elapsed:= 0.0
var _phase_duration:= 1.0
var _pose_from:= Vector4.ZERO
var _pose_to:= Vector4.ZERO


var _pose_target:= Vector3.ZERO
var _angles:= Vector4.ZERO


var _payload_pose_valid:= false
var _payload_pose:= Transform3D.IDENTITY
var _payload_visual: MultiMeshInstance3D
static var sample_physics_enabled:= "--legacy-arm-sample-physics" in OS.get_cmdline_user_args() or "--legacy-arm-payload" in OS.get_cmdline_user_args()
var _claw_from:= CLAW_OPEN
var _claw_to:= CLAW_OPEN
var _claw_angle:= CLAW_OPEN


var _pose_stale:= false


static var pose_everywhere:= "--oldarmpose" in OS.get_cmdline_user_args()


static var _sight_frame:= -1
static var _sight_eye:= Vector3.ZERO
static var _sight_metres:= 0.0
var _scan_left:= SCAN_INTERVAL


static var _bid_frame:= -1
static var _bid_id:= 0
static var _bid_left:= 0.0

static var _scan_turn:= 0


var _stall:= ""


var _clear:= false


enum {
        FAULT_NONE = 0,

        FAULT_NO_BELT,

        FAULT_TOO_SHORT,

        FAULT_OUT_OF_REACH,

        FAULT_NO_ROOM,
}


var _drop_fault:= FAULT_NONE

var _pickup_source:= Vector3.ZERO
var _pickup_target:= Vector3.ZERO
var _pickup_from_field:= false


var _pickup_prop: Carryable


var _payload_prop: Carryable


var _pickup_needle: RigidBody3D


var _payload_needle: RigidBody3D
var _drop_target:= Vector3.ZERO


var _next_drop:= 0


var _drop_run: BeltPath
var _drop_velocity:= Vector3.ZERO
var _payload: Array [Dictionary] = []
var completed_cycles:= 0


var delivered_needles:= 0


var _load_times: PackedFloat64Array = []
var _load_counts: PackedInt32Array = []


var _born:= -1.0


var last_record_seq:= -1

signal dropped_record(seq: int)


var last_cycle_needle:= false
var last_payload_count:= 0


var _payload_count:= 0
var last_cycle_from_field:= false
var _harvest_rng:= RandomNumberGenerator.new()


var _hold_since:= 0.0


var _hold_retry_at:= 0.0


var _hold_tries:= 0


var _cycle_sound_until:= 0.0

var _ghost_ok: StandardMaterial3D
var _ghost_bad: StandardMaterial3D
static var _game_materials: Dictionary = { }
static var _spec_cache: Dictionary = { }


func setup(at: Vector3, yaw: float, tier: int = Cfg.ROBOT_ARM_DEFAULT_TIER) -> void:
        tier_index = clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)
        paid_cost = float(tier_data() ["cost"])
        position = at
        rotation.y = yaw


func set_tier(tier: int) -> bool:
        var next:= clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)
        if next == tier_index:
                return false
        tier_index = next
        if _model != null:
                _model.scale = Vector3.ONE * visual_scale()
        if _collider != null:
                var shape:= _collider.shape as CylinderShape3D
                shape.radius = BASE_RADIUS * visual_scale()
                shape.height = BASE_HEIGHT * visual_scale()
                _collider.position.y = shape.height * 0.5
        if _cap != null:
                _shape_cap()
        if _aim_shape != null:
                var aim:= _aim_shape.shape as CylinderShape3D
                aim.radius = AIM_RADIUS * visual_scale()
                aim.height = AIM_HEIGHT * visual_scale()
                _aim_shape.position.y = aim.height * 0.5
        if is_instance_valid(_ring):
                _ring.mesh = _ring_part(ring_radius())


        match _phase:
                Phase.IDLE, Phase.CLOSE_CLAWS, Phase.OPEN_CLAWS:
                        pass
                _:
                        _pose_to = _solve_world_target(_pose_target)
        return true


func _ready() -> void:
        collision_layer = 0 if placement_preview else Cfg.L_BUILD
        collision_mask = 0
        _build_model()
        if placement_preview:
                set_process(false)
                set_physics_process(false)
                set_preview_valid(true)
                _sync_ring()
        else:
                _build_collider()
                _build_aim_volume()
                add_to_group("robotic_arms")


                Wheelbarrow.keep_apart(self)
                _harvest_rng.seed = hash(Vector3(global_position.x, global_position.y, global_position.z))
                _angles = _solve_authored_target(HOME_TARGET)
                _apply_angles(_angles)
                _apply_claw(CLAW_OPEN)
                _born = Time.get_ticks_msec() * 0.001


func _exit_tree() -> void:
        _materialize_payload()


        _credit_the_undrawn()


        for entry in _payload:
                var body:= entry ["body"] as RigidBody3D
                if not is_instance_valid(body):
                        continue
                body.set_meta(LiveStrandManager.META_PROTECTED, false)
                body.collision_layer = int(entry.get("layer", Cfg.L_STRAND))
                body.collision_mask = int(entry.get("mask", LiveStrandManager.STRAND_MASK))
                body.freeze = false
                body.sleeping = false
        _payload.clear()


        if _payload_prop != null and is_instance_valid(_payload_prop):
                _payload_prop.release(Vector3.ZERO)
        _payload_prop = null
        _unclaim_prop()


        if _payload_needle != null and is_instance_valid(_payload_needle):
                _payload_needle.set_meta(LiveStrandManager.META_PROTECTED, false)
                _payload_needle.freeze = false
                _payload_needle.sleeping = false


                _unclaim_needle(_payload_needle)
        _payload_needle = null
        _unclaim_needle()


func _build_model() -> void:
        if MODEL == null:
                # V38: never feed a null PackedScene to instantiate();
                # a null model killed Mali devices at the 82% stage.
                push_error("RoboticArm: model scene missing; continuing without visuals")
                CrashReport.note_doing("robotic_arm:MODEL_MISSING")
                return
        _model = MODEL.instantiate() as Node3D
        _model.name = "Model"
        _model.scale = Vector3.ONE * visual_scale()
        add_child(_model)

        _base_yaw = _model.find_child("RA_BaseYaw", true, false) as Node3D
        _shoulder = _model.find_child("RA_ShoulderPitch", true, false) as Node3D
        _elbow = _model.find_child("RA_ElbowPitch", true, false) as Node3D
        _tool = _model.find_child("RA_ToolLevel", true, false) as Node3D
        _socket = _model.find_child("SOCKET_HayGrip", true, false) as Node3D
        for i in range(1, 5):
                var claw:= _model.find_child("RA_ClawPivot_%d" % i, true, false) as Node3D
                if claw != null:
                        _claws.append(claw)

        var animation:= _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
        if animation != null:
                animation.stop()

        for helper_name in HIDDEN_HELPERS:
                var helper:= _model.find_child(helper_name, true, false) as Node3D
                if helper != null:
                        helper.visible = false


        var orb:= _model.find_child("RA_ReachOrb_Ghost", true, false) as Node3D
        if orb != null:
                orb.visible = false
        var authored:= _model.find_child("RA_ReachGroundRing", true, false) as Node3D
        if authored != null:
                authored.visible = false
        _apply_game_materials()

        if placement_preview:
                _ghost_ok = _ghost_material(Cfg.COL_GHOST_OK)
                _ghost_bad = _ghost_material(Cfg.COL_GHOST_BAD)
                for mesh in _mesh_children(_model):
                        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_collider() -> void:
        var shape:= CylinderShape3D.new()
        shape.radius = BASE_RADIUS * visual_scale()
        shape.height = BASE_HEIGHT * visual_scale()
        _collider = CollisionShape3D.new()
        _collider.name = "BaseCollision"
        _collider.shape = shape
        _collider.position.y = shape.height * 0.5
        add_child(_collider)
        _cap = CollisionShape3D.new()
        _cap.name = "BaseCap"
        _shape_cap()
        add_child(_cap)


static func clear_of_arms(tree: SceneTree, at: Vector3, reach: float,
                toward: Vector3) -> Vector3:
        var out:= at
        for node in tree.get_nodes_in_group("robotic_arms"):
                var arm:= node as RoboticArm
                if arm == null or not arm.is_inside_tree():
                        continue
                var s:= arm.visual_scale()
                var foot:= arm.global_position
                if out.y < foot.y or out.y > foot.y + AIM_HEIGHT * s:
                        continue
                var clear:= AIM_RADIUS * s + reach
                var flat:= Vector2(out.x - foot.x, out.z - foot.z)
                if flat.length() >= clear:
                        continue
                var back:= Vector2(toward.x - out.x, toward.z - out.z)
                if back.length() < 0.001:
                        back = flat if flat.length() > 0.001 else Vector2.RIGHT
                back = back.normalized()


                var b:= flat.dot(back)
                var t:= - b + sqrt(maxf(b * b - (flat.length_squared() - clear * clear), 0.0))
                out.x += back.x * (t + 0.02)
                out.z += back.y * (t + 0.02)
        return out


func _shape_cap() -> void:
        var r:= BASE_RADIUS * visual_scale()
        var points:= PackedVector3Array()
        for i in BASE_CAP_SIDES:
                var a:= TAU * float(i) / float(BASE_CAP_SIDES)
                points.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
        points.append(Vector3(0.0, r * tan(BASE_CAP_SLOPE), 0.0))
        var cone:= ConvexPolygonShape3D.new()
        cone.points = points
        _cap.shape = cone
        _cap.position.y = BASE_HEIGHT * visual_scale()


func _build_aim_volume() -> void:
        var shape:= CylinderShape3D.new()
        shape.radius = AIM_RADIUS * visual_scale()
        shape.height = AIM_HEIGHT * visual_scale()
        _aim_shape = CollisionShape3D.new()
        _aim_shape.name = "AimShape"
        _aim_shape.shape = shape
        _aim_shape.position.y = shape.height * 0.5

        var aim:= Area3D.new()
        aim.name = "AimVolume"
        aim.collision_layer = Cfg.L_BUILD
        aim.collision_mask = 0
        aim.monitoring = false
        aim.add_child(_aim_shape)
        add_child(aim)


func set_preview_valid(valid: bool) -> void:


        if placement_preview and _ring_mat != null:
                var tint: Color = Cfg.COL_GHOST_OK if valid else Cfg.COL_GHOST_BAD
                _ring_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
        if not placement_preview or _model == null:
                return
        var material:= _ghost_ok if valid else _ghost_bad
        for mesh in _mesh_children(_model):
                mesh.material_overlay = material


func _ghost_material(color: Color) -> StandardMaterial3D:
        var material:= StandardMaterial3D.new()
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = Color(color.r, color.g, color.b, 0.42)
        material.no_depth_test = false
        return material


func _apply_game_materials() -> void:
        if (spec_table().get("flats", { }) as Dictionary).is_empty():
                push_warning("RoboticArm: no material table at %s, the arm will render grey" % SPEC)
        for mesh in _mesh_children(_model):
                if mesh.mesh == null:
                        continue
                for surface in mesh.mesh.get_surface_count():
                        var imported:= mesh.mesh.surface_get_material(surface)
                        if imported != null and imported.get_meta("immutable_palette", false):
                                preload("res://assets/models/machine_palette.gd").validate_import(imported, spec_table())
                                continue
                        var material_name:= imported.resource_name if imported != null else ""
                        if material_name == "":
                                material_name = "RA_ReachWire" if "Reach" in mesh.name else "RA_Black_HammerPaint"
                        mesh.set_surface_override_material(surface, _game_material(material_name))


static func spec_table() -> Dictionary:
        if not _spec_cache.is_empty():
                return _spec_cache


        var res: JSON = load(SPEC) as JSON
        if res != null and typeof(res.data) == TYPE_DICTIONARY:
                _spec_cache = res.data
        elif FileAccess.file_exists(SPEC):
                var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
                if typeof(parsed) == TYPE_DICTIONARY:
                        _spec_cache = parsed
        return _spec_cache


func _game_material(material_name: String) -> Material:
        if _game_materials.has(material_name):
                return _game_materials [material_name] as Material
        var flats: Dictionary = spec_table().get("flats", { })
        var row: Dictionary = flats.get(material_name, { })
        var material: Material = (_reach_material(row) if material_name == "RA_ReachWire"
                        else _flat_material(material_name, row))
        _game_materials [material_name] = material
        return material


func _flat_material(material_name: String, row: Dictionary) -> StandardMaterial3D:
        var material:= StandardMaterial3D.new()
        material.resource_name = material_name + "_Godot"
        material.albedo_color = _col(row.get("color", [0.5, 0.5, 0.5]))
        material.metallic = float(row.get("metal", 0.0))
        material.roughness = float(row.get("rough", 0.6))
        material.metallic_specular = float(row.get("spec", 0.5))
        var emit:= float(row.get("emit", 0.0))
        if emit > 0.0:
                material.emission_enabled = true
                material.emission = _col(row.get("glow", row.get("color", [1.0, 1.0, 1.0])))
                material.emission_energy_multiplier = emit


        var coat: Array = row.get("coat", [])
        if coat.size() >= 2:
                material.clearcoat_enabled = true
                material.clearcoat = float(coat [0])
                material.clearcoat_roughness = float(coat [1])
        return material


func _reach_material(row: Dictionary) -> StandardMaterial3D:
        var material:= StandardMaterial3D.new()
        material.resource_name = "RA_ReachWire_Godot"
        var colour:= _col(row.get("glow", [0.02, 0.3, 1.0]))
        material.albedo_color = Color(colour.r, colour.g, colour.b, 0.72)
        material.emission_enabled = true
        material.emission = colour
        material.emission_energy_multiplier = 1.5
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        return material


static func _col(a: Variant) -> Color:
        var arr: Array = a
        if arr.size() < 3:
                return Color.WHITE
        return Color(float(arr [0]), float(arr [1]), float(arr [2])).linear_to_srgb()


func _mesh_children(root: Node) -> Array [MeshInstance3D]:
        var out: Array [MeshInstance3D] = []
        var pending: Array [Node] = [root]
        while not pending.is_empty():
                var node: Node = pending.pop_back()
                if node is MeshInstance3D:
                        out.append(node as MeshInstance3D)
                for child in node.get_children():
                        pending.append(child)
        return out


func tier_data() -> Dictionary:
        return Cfg.ROBOT_ARM_TIERS [clampi(tier_index, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)]


func visual_scale() -> float:
        return float(tier_data() ["scale"])


func reach_m() -> float:
        return float(tier_data() ["reach"])


func work_reach() -> float:
        return reach_m() * REACH_FRACTION


func ring_radius() -> float:
        var r:= work_reach()
        var h:= SHOULDER_HEIGHT * visual_scale()
        return sqrt(maxf(r * r - h * h, 0.0))


static func boom_ceiling(distance: float) -> float:
        var top:= float(BOOM_CEILING [0] [1])
        for row: Array in BOOM_CEILING:
                if float(row [0]) > distance:
                        break
                top = float(row [1])
        return top


func show_range(on: bool) -> void:
        _peek_lit = on
        _sync_ring()


func show_plate(on: bool) -> void:
        _plate_lit = on
        _sync_ring()


func show_radius(on: bool) -> void:
        _radius_left = RADIUS_SHOW_SECONDS if on else 0.0
        _sync_ring()


func toggle_radius() -> bool:
        show_radius(not radius_shown())
        return radius_shown()


func radius_shown() -> bool:
        return _radius_left > 0.0


func radius_seconds_left() -> float:
        return _radius_left


func range_lit() -> bool:
        return is_instance_valid(_ring) and _ring.visible


func _sync_ring() -> void:
        var on:= placement_preview or _peek_lit or _radius_left > 0.0 or _choosing


        _sync_link_marks((on or _plate_lit) and not placement_preview)
        _sync_feeds()
        if not on:
                if is_instance_valid(_ring):
                        _ring.visible = false
                return
        if not is_instance_valid(_ring):
                _build_ring()
        _ring.visible = true


func _build_ring() -> void:
        _ring = MeshInstance3D.new()
        _ring.name = "ReachRing"
        _ring.mesh = _ring_part(ring_radius())
        _ring.position.y = RING_LIFT
        _ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


        if placement_preview:
                _ring_mat = HayDrone._new_ring_mat(COL_RING)
                _ring.material_override = _ring_mat
        else:
                if _ring_shared == null:
                        _ring_shared = HayDrone._new_ring_mat(COL_RING)
                _ring.material_override = _ring_shared
        add_child(_ring)


const FEEDS_CHECK:= 0.5

func _sync_feeds() -> void:
        var on:= _radius_left > 0.0 and not _choosing and not placement_preview and builds != null
        if not on:
                if is_instance_valid(_feeds):
                        _feeds.visible = false
                return
        if not is_instance_valid(_feeds):
                _feeds = MeshInstance3D.new()
                _feeds.name = "ReachFeeds"
                _feeds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                if _feeds_mat == null:
                        var tint:= Cfg.COL_GHOST_OK
                        _feeds_mat = HayDrone._new_ring_mat(Color(tint.r, tint.g, tint.b, 0.45))

                        _feeds_mat.no_depth_test = true
                _feeds.material_override = _feeds_mat
                add_child(_feeds)
                _feeds.top_level = true
                _feeds.global_transform = Transform3D.IDENTITY
        _feeds.visible = true
        _feeds_check = FEEDS_CHECK
        var runs: Array = []
        for pick: Dictionary in builds.conveyor_drops(_shoulder_world(), work_reach()):
                runs.append(pick.get("conveyor"))
        var verts:= RoboticArm.reach_strip(runs, _shoulder_world(), work_reach())
        if verts.is_empty():
                _feeds.mesh = null
                return
        var st:= SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for v in verts:
                st.add_vertex(v)
        _feeds.mesh = st.commit()


static func _ring_part(r: float) -> Mesh:
        var key:= "%.4f" % r
        if not _ring_meshes.has(key):
                _ring_meshes [key] = HayDrone.ring_mesh(r, RING_BAND)
        return _ring_meshes [key]


func upgrade() -> bool:
        return builds != null and builds.upgrade_arm(self)


func upgrade_price() -> float:
        return builds.arm_upgrade_price(self) if builds != null else -1.0


func upgrade_block() -> String:
        return builds.arm_upgrade_block(self) if builds != null else tr("blocked")


func upgrade_detail() -> String:
        return builds.arm_upgrade_detail(self) if builds != null else ""


func build_cost() -> float:
        if paid_cost >= 0.0:
                return paid_cost
        return float(tier_data() ["cost"])


func to_dict() -> Dictionary:


        _credit_the_undrawn()
        var out:= {
                "type": "robotic_arm",
                "off": switched_off,
                "position": global_position,
                "yaw": global_rotation.y,
                "tier": tier_index,
                "paid": build_cost(),
                "refuses": refusals(),
        }


        var links:= links_to_save()
        if not links.is_empty():
                out ["links"] = links
        if pick_order != ORDER_LOOSE:
                out ["order"] = order_id(pick_order)
        return out


func _credit_the_undrawn() -> void:
        if _payload_prop != null:
                return
        var undrawn:= _payload_count - _payload.size()
        if undrawn <= 0:
                return
        GameState.return_hay(float(undrawn))
        _payload_count = _payload.size()


func refusals() -> PackedStringArray:
        var out:= PackedStringArray()
        for kind: Dictionary in PICK_KINDS:
                var bit:= int(kind ["bit"])
                if not accepts(bit) and not locked(bit):
                        out.append(str(kind ["id"]))
        return out


static func mask_from_refusals(list: Variant) -> int:
        var refused:= { }
        for id: Variant in (list if list is Array or list is PackedStringArray else []):
                refused [str(id)] = true
        var mask:= PICK_LOCKED
        for kind: Dictionary in PICK_KINDS:
                if not refused.has(str(kind ["id"])):
                        mask |= int(kind ["bit"])
        return mask


static func mask_from_legacy(value: int) -> int:
        return (value & 31) | PICK_FOILED | PICK_PILE | PICK_PULP | PICK_ROLL | PICK_DISC | PICK_LOCKED


func _process(delta: float) -> void:
        if placement_preview or _base_yaw == null:
                return
        _clock += delta
        if _radius_left > 0.0:
                _radius_left = maxf(0.0, _radius_left - delta)
                if _radius_left <= 0.0:
                        _sync_ring()
                else:
                        _feeds_check -= delta
                        if _feeds_check <= 0.0:
                                _sync_feeds()


        if is_instance_valid(_marks) and _marks.visible:
                _links_check -= delta
                if _links_check <= 0.0:
                        _links_check = LINK_CHECK
                        _resolve_links()
        if _phase == Phase.IDLE:


                _scan_left -= delta * power
                if _scan_left <= 0.0 and _take_scan_turn():
                        _scan_left = SCAN_INTERVAL
                        _try_start_cycle()
                _update_payload()
                return


        _phase_elapsed += delta * power
        var amount:= clampf(_phase_elapsed / maxf(_phase_duration, 0.001), 0.0, 1.0)
        var eased:= amount * amount * (3.0 - 2.0 * amount)


        var unseen:= _out_of_sight() and not _carrying()
        if _phase == Phase.CLOSE_CLAWS or _phase == Phase.OPEN_CLAWS:
                if unseen:
                        _claw_angle = lerpf(_claw_from, _claw_to, eased)
                        _pose_stale = true
                else:
                        _apply_claw(lerpf(_claw_from, _claw_to, eased))
        elif unseen:
                _angles = _lerp_angles(_pose_from, _pose_to, eased)
                _pose_stale = true
        else:
                _apply_angles(_lerp_angles(_pose_from, _pose_to, eased))
        _update_payload()
        if amount >= 1.0:


                if _pose_stale:
                        _snap_pose()
                _finish_phase()


func _out_of_sight() -> bool:
        if pose_everywhere:
                return false
        var frame:= Engine.get_process_frames()
        if _sight_frame != frame:
                _sight_frame = frame
                _sight_metres = 0.0
                var camera:= get_viewport().get_camera_3d() if is_inside_tree() else null
                if camera != null:
                        _sight_eye = camera.global_position
                        _sight_metres = Cfg.machine_distance_metres()
        if _sight_metres <= 0.0:
                return false
        var arm:= (UPPER_ARM + FOREARM + TOOL_OFFSET + BASE_RADIUS) * 2.0
        var past:= _sight_metres + arm * visual_scale() + MachineDrawDistance.MARGIN
        return _sight_eye.distance_squared_to(global_position) > past * past


func _snap_pose() -> void:
        _pose_stale = false
        _apply_angles(_angles)
        _apply_claw(_claw_angle)


func _take_scan_turn() -> bool:
        var frame:= Engine.get_process_frames()
        if _bid_frame != frame:
                _scan_turn = _bid_id if _bid_frame == frame - 1 else 0
                _bid_frame = frame
                _bid_id = 0
                _bid_left = INF
        var me:= get_instance_id()
        if _scan_turn == me:
                _scan_turn = 0
                return true
        if _scan_left < _bid_left:
                _bid_left = _scan_left
                _bid_id = me
        return false


func _try_start_cycle() -> void:
        if builds == null or live == null:
                return
        var shoulder_world:= global_position + Vector3.UP * SHOULDER_HEIGHT * visual_scale()


        _pickup_from_field = false
        _pickup_prop = null
        _pickup_needle = null
        _pickup_run = null
        _pickup_stuck_only = false
        var want:= Tech.arm_capacity(int(tier_data() ["capacity"]))
        _stall = ""
        _clear = false
        _drop_fault = FAULT_NONE
        if accept_mask == 0:


                _stall = tr("SET TO TAKE NOTHING  ·  every kind is switched off")
                return
        var needle: RigidBody3D = null
        if accepts(PICK_NEEDLE):
                needle = live.nearest_available_needle(
                        shoulder_world, work_reach(), MIN_REACH * visual_scale(),
                        get_instance_id())


        var taking:= needle == null and _takes_from_belts()


        var candidate: RigidBody3D = null
        var block: Carryable = null
        var blocks_asked:= false
        if needle == null and not taking:
                var order:= pick_order_now()
                if order == ORDER_BIG:
                        block = _find_prop_pickup(shoulder_world, true)
                        blocks_asked = true
                if block == null and accepts(PICK_LOOSE):
                        candidate = live.nearest_available_hay(
                                shoulder_world, work_reach(), MIN_REACH * visual_scale())
                if order == ORDER_CLOSEST and candidate != null:
                        block = _find_prop_pickup(shoulder_world)
                        blocks_asked = true
                        if block != null and shoulder_world.distance_squared_to(block.global_position) < shoulder_world.distance_squared_to(candidate.global_position):
                                candidate = null
                        else:
                                block = null
        if needle != null:
                _pickup_needle = needle
                _pickup_source = needle.global_position
                _pickup_target = _pickup_source + Vector3.UP * 0.06


                want = 0
        elif taking:
                var off:= _find_belt_pickup()
                if off.is_empty():


                        _clear = true
                        return
                _pickup_run = off ["run"] as BeltPath
                _pickup_stuck_only = bool(off.get("stuck_only", false))
                _pickup_source = off ["point"]
                _pickup_target = _pickup_source
                _take_wait_until = 0.0
                want = int(off ["strands"])
        elif candidate != null:
                _pickup_source = candidate.global_position
                _pickup_target = _pickup_source + Vector3.UP * 0.06
        else:
                if block == null and not blocks_asked:
                        block = _find_prop_pickup(shoulder_world)
                if block != null:
                        _pickup_prop = block
                        _pickup_source = block.global_position
                        _pickup_target = _pickup_source


                        want = block.hay_strands()
                else:
                        var field_pick:= _find_field_pickup(shoulder_world) if accepts(PICK_PILE) else { }
                        if field_pick.is_empty():


                                _clear = true
                                return
                        _pickup_from_field = true
                        _pickup_source = field_pick ["point"]
                        _pickup_target = _pickup_source + (field_pick ["normal"] as Vector3) * 0.08


        var belt:= _choose_drop(want, _pickup_prop)
        if belt.is_empty():
                _stall = drop_fault_text()
                return
        _claim_prop(_pickup_prop)
        _claim_needle(_pickup_needle)
        _drop_target = belt ["point"]
        _drop_run = belt.get("conveyor") as BeltPath


        _drop_velocity = belt ["forward"] * Tech.belt_speed() + Vector3.DOWN * 0.1
        _play_cycle_sound()
        _start_pose(Phase.APPROACH_PICK,
                _pickup_target + Vector3.UP * PICK_CLEARANCE * visual_scale(), 0.75)


func alert_reason() -> String:
        if placement_preview:
                return ""
        if switched_off:
                return ""


        var dead:= MachinePower.fault(power, power_blocked, power_line)
        if dead != "":
                return dead


        if _hold_tries >= ALERT_TRIES:


                if _drop_fault == FAULT_NO_BELT or _drop_fault == FAULT_TOO_SHORT or _drop_fault == FAULT_OUT_OF_REACH:
                        return drop_fault_text()
                return tr("BELT FULL  ·  clear the line it feeds, or lay another belt")
        if _phase != Phase.IDLE:
                return ""
        return _stall


func drop_fault_text() -> String:
        match _drop_fault:
                FAULT_NO_BELT:
                        return no_belt_text(_neighbour())
                FAULT_TOO_SHORT:


                        return tr("BELT TOO SHORT  ·  lay a longer belt here")
                FAULT_OUT_OF_REACH:
                        return tr("BELT OUT OF REACH  ·  move the arm closer to the belt")
        return tr("NOWHERE TO PUT IT  ·  no belt in reach with room")


static func no_belt_text(near: Dictionary) -> String:
        if near.is_empty():
                return Cfg.tr("NO BELT IN REACH  ·  lay a conveyor beside this arm")
        var called:= name_in_sentence(str(near ["name"]))
        match str(near ["kind"]):
                "splitter":
                        return Cfg.tr("ARMS DROP ONTO BELTS, NOT SPLITTERS  ·  run a conveyor from here into the %s") % called
                "joiner":
                        return Cfg.tr("ARMS DROP ONTO BELTS, NOT JOINERS  ·  run a conveyor from here into the %s") % called
        return Cfg.tr("ARMS DROP ONTO BELTS, NOT MACHINES  ·  run a conveyor from here into the %s") % called


static func no_belt_sentence(near: Dictionary) -> String:
        if near.is_empty():
                return Cfg.tr("No belt in its radius. Lay a conveyor beside it.")
        var called:= name_in_sentence(str(near ["name"]))
        match str(near ["kind"]):
                "splitter":
                        return Cfg.tr("It drops onto belts, not splitters. Run a conveyor from here into the %s.") % called
                "joiner":
                        return Cfg.tr("It drops onto belts, not joiners. Run a conveyor from here into the %s.") % called
        return Cfg.tr("It drops onto belts, not machines. Run a conveyor from here into the %s.") % called


static func name_in_sentence(name_text: String) -> String:
        var words:= name_text.split(" ")
        for i in words.size():
                if words [i].length() > 1:
                        words [i] = Cfg.lower_in_english(words [i])
        return " ".join(words)


func _neighbour() -> Dictionary:
        if builds == null:
                return { }
        return builds.arm_neighbour(_shoulder_world(), work_reach())


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
        return float(tier_data() ["draw_kw"])


func draw_kw() -> float:
        return 0.0 if switched_off else rated_kw()


const MAST_FOOT:= Vector3(0.0, 0.202, -0.27)
const MAST_HEIGHT:= 3.0


func power_ports() -> Array [Node3D]:
        if _ports.is_empty():
                var marker: Node3D = null
                if _model != null:
                        marker = _model.find_child("Marker_WirePort", true, false) as Node3D
                if marker != null:
                        _ports.append(marker)
                        MachinePower.strip_leads(_model, _ports)
                        return _ports
                var host: Node3D = _base_yaw if _base_yaw != null else _model
                if host == null:
                        return _ports
                _ports.append(MachinePower.mast(host, MAST_FOOT, MAST_HEIGHT, Vector3.ZERO, "WirePort0"))
        return _ports


func set_power(f: float) -> void:
        line_power = clampf(f, 0.0, 1.0)
        power = 0.0 if switched_off else line_power


func set_switched_off(off: bool) -> void:
        switched_off = off
        set_power(line_power)


func is_switched_off() -> bool:
        return switched_off


func set_power_line(line: int) -> void:
        power_line = line


func set_power_blocked(b: bool) -> void:
        power_blocked = b


func alert_icon() -> String:
        if MachinePower.fault(power, power_blocked, power_line) != "":
                return "power"


        if _hold_tries >= ALERT_TRIES:
                return "jam"
        return ""


func _choose_drop(count: int, prop: Carryable = null,
                only: BeltPath = null, require_room: bool = true,
                skip: BeltPath = null, ahead: float = 0.0,
                empty_only: bool = false) -> Dictionary:
        if builds == null:
                return { }
        if only != null and not (only is Conveyor or only is ConveyorCorner):
                return { }
        var runs:= builds.conveyor_drops(_shoulder_world(), work_reach(), only)
        if runs.is_empty():
                _note_fault(FAULT_NO_BELT)
                return { }
        for i in runs.size():
                var at:= (_next_drop + i) % runs.size()
                var pick: Dictionary = runs [at]
                if skip != null and pick.get("conveyor") == skip:
                        continue


                if only != null and pick.get("conveyor") != only:
                        continue


                var run:= pick.get("conveyor") as BeltPath
                if run == null or not is_instance_valid(run):
                        continue
                if empty_only and not _carries_nothing(run):
                        continue


                if not _may_put_on(run):
                        continue
                var release:= _release_on_run(run, _put_aim(run, pick ["point"]),
                        count, prop, require_room, ahead)
                if release.is_empty():
                        continue
                pick ["point"] = release ["point"]


                if only == null:
                        _next_drop = (at + 1) % runs.size()
                return pick
        return { }


func _release_on_run(run: BeltPath, point: Vector3,
                count: int, prop: Carryable, require_room: bool,
                ahead: float = 0.0) -> Dictionary:


        var record:= _boards_as_record(run, count, prop)
        var speed:= 0.0 if record else Tech.belt_speed()
        var lead:= 0.0 if record else _drop_lead()
        var half:= _footprint(count, prop)


        if not run.fits_load(lead, half):
                _note_fault(FAULT_TOO_SHORT)
                return { }
        var at:= run._nearest(point)
        var s:= float(at ["s"])
        var side:= float(at ["side"])
        var lift:= float(at ["lift"])
        var basis:= run._basis_at(s)
        var origin:= run.usable_release(run._point_at(s) + basis.x * side + basis.y * lift,
                speed, lead, half)
        s = float(run._nearest(origin) ["s"])
        var shoulder:= _shoulder_world()
        var radius:= work_reach()
        var radius2:= radius * radius


        var in_reach:= false
        if origin.distance_squared_to(shoulder) < radius2:
                in_reach = true
                if not require_room or _room_on(run, origin, count, prop, ahead):
                        return { "point": origin }
        if not require_room:
                _note_fault(FAULT_OUT_OF_REACH)
                return { }


        var step:= maxf(0.2, half)
        var seen: Array [Vector3] = [origin]
        for i in range(1, int(ceil(radius * 2.0 / step)) + 1):
                for direction in [1.0, -1.0]:
                        var along:= clampf(s + step * i * direction, 0.0, run.path_length())
                        basis = run._basis_at(along)
                        var candidate:= run.usable_release(
                                run._point_at(along) + basis.x * side + basis.y * lift,
                                speed, lead, half)
                        if seen.any(func(previous: Vector3) -> bool:
                                return previous.is_equal_approx(candidate)):
                                continue
                        seen.append(candidate)
                        if candidate.distance_squared_to(shoulder) >= radius2:
                                continue
                        in_reach = true
                        if _room_on(run, candidate, count, prop, ahead):
                                return { "point": candidate }
        _note_fault(FAULT_NO_ROOM if in_reach else FAULT_OUT_OF_REACH)
        return { }


func _note_fault(fault: int) -> void:
        _drop_fault = maxi(_drop_fault, fault)


func _find_prop_pickup(shoulder_world: Vector3, biggest: bool = false) -> Carryable:
        if props == null:
                return null
        var best: Carryable = null
        var best_d:= INF
        var best_n:= -1
        var max_d:= work_reach()
        var min_d:= MIN_REACH * visual_scale()
        var max_d2:= max_d * max_d
        var min_d2:= min_d * min_d
        var now:= Time.get_ticks_msec() * 0.001
        for item in props.items:
                var wad:= item as Carryable
                if wad == null or not is_instance_valid(wad):
                        continue

                var d:= shoulder_world.distance_squared_to(wad.global_position)
                if d < min_d2 or d > max_d2 or (d >= best_d and not biggest):
                        continue
                if not accepts(_kind_of(wad)):
                        continue


                if float(wad.get_meta(LiveStrandManager.META_ARM_IGNORE_UNTIL, 0.0)) > now:
                        continue
                if wad.is_held():
                        continue


                if BeltPath.is_rider(wad):
                        continue
                if not wad.freeze and not _prop_settled(wad):
                        continue
                if wad.has_meta(PropManager.META_CLAIM) and int(wad.get_meta(PropManager.META_CLAIM)) != get_instance_id():
                        var other:= instance_from_id(int(wad.get_meta(PropManager.META_CLAIM)))
                        if other != null and is_instance_valid(other):
                                continue
                if biggest:
                        var n:= wad.hay_strands()
                        if n < best_n or (n == best_n and d >= best_d):
                                continue
                        best_n = n
                best = wad
                best_d = d
        return best


func _prop_settled(wad: Carryable) -> bool:
        return wad.linear_velocity.length_squared() <= 0.81


static func _kind_of(prop: Carryable) -> int:
        if prop is HayWad:
                return PICK_WAD
        if prop is HayBale:
                return PICK_BALE
        if prop is EcoBrick:
                return PICK_BRICK


        if prop is FoiledBale:
                return PICK_FOILED


        if prop is HayPulp:
                return PICK_PULP


        if prop is PaperRoll:
                return PICK_ROLL


        if prop is FeedDisc:
                return PICK_DISC
        return 0


func accepts(bit: int) -> bool:
        return bit != 0 and (accept_mask & bit) == bit


static func locked(bit: int) -> bool:
        return (PICK_LOCKED & bit) != 0


func set_accepting(bit: int, on: bool) -> void:
        if on:
                accept_mask |= bit
        else:
                accept_mask &= ~ (bit & ~ PICK_LOCKED)


        _stall = ""
        _clear = false
        _scan_left = minf(_scan_left, 0.15)


func accept_label() -> String:
        var names: PackedStringArray = []
        for kind: Dictionary in PICK_KINDS:
                if accepts(int(kind ["bit"])):
                        names.append(Cfg.lower_in_english(tr(str(kind ["name"]))))
        if names.is_empty():
                return tr("nothing")
        if names.size() == PICK_KINDS.size():
                return tr("everything under it")
        return ", ".join(names)


func _claim_prop(wad: Carryable) -> void:
        if wad != null and is_instance_valid(wad):
                wad.set_meta(PropManager.META_CLAIM, get_instance_id())


func _unclaim_prop() -> void:
        var wad:= _pickup_prop
        _pickup_prop = null
        if wad == null or not is_instance_valid(wad):
                return
        if wad.has_meta(PropManager.META_CLAIM) and int(wad.get_meta(PropManager.META_CLAIM)) == get_instance_id():
                wad.remove_meta(PropManager.META_CLAIM)


func _claim_needle(needle: RigidBody3D) -> void:
        if needle != null and is_instance_valid(needle):
                needle.set_meta(LiveStrandManager.META_CLAIM, get_instance_id())


func _unclaim_needle(body: RigidBody3D = null) -> void:
        var needle:= body if body != null else _pickup_needle
        if body == null:
                _pickup_needle = null
        if needle == null or not is_instance_valid(needle):
                return
        if needle.has_meta(LiveStrandManager.META_CLAIM) and int(needle.get_meta(LiveStrandManager.META_CLAIM)) == get_instance_id():
                needle.remove_meta(LiveStrandManager.META_CLAIM)


func _play_cycle_sound() -> void:
        var now:= Time.get_ticks_msec() * 0.001
        if now < _cycle_sound_until:
                return
        _cycle_sound_until = now + ARM_CYCLE_LEN
        Audio.play_3d("arm_cycle", _shoulder_world(), -9.0)


func _find_field_pickup(shoulder_world: Vector3) -> Dictionary:
        if field == null:
                return { }
        var best:= Vector3.INF
        var best_score:= INF
        var max_radius:= work_reach()
        var min_radius:= MIN_REACH * visual_scale()


        var inner:= (BASE_RADIUS + FIELD_BASE_CLEAR) * visual_scale()
        for point in field.points_in_ring(global_position, inner, max_radius, FIELD_FLOOR):
                var distance:= shoulder_world.distance_to(point)
                if distance < min_radius or distance > max_radius:
                        continue
                var score:= distance - minf(point.y, 2.5) * 0.45
                if score >= best_score:
                        continue
                best_score = score
                best = point
        if best == Vector3.INF:
                return { }
        return { "point": best, "normal": field.normal_at(best.x, best.z) }


func _finish_phase() -> void:
        match _phase:
                Phase.APPROACH_PICK:
                        _start_pose(Phase.DESCEND_PICK, _pickup_target, 0.45)
                Phase.DESCEND_PICK:


                        if _pickup_run != null and not _grab_off_belt():
                                return
                        _start_claw(Phase.CLOSE_CLAWS, CLAW_CLOSED, 0.22)
                Phase.CLOSE_CLAWS:
                        _claim_payload()
                        if not _carrying():
                                _start_pose(Phase.RETURN_HOME, _home_world_target(), 0.65)
                        else:
                                _start_pose(Phase.LIFT,
                                        _pickup_target + Vector3.UP * PICK_CLEARANCE * visual_scale(), 0.55)
                Phase.LIFT:
                        _aim_at_coming_gap()
                        _start_pose(Phase.SWING_DROP,
                                _drop_target + Vector3.UP * DROP_CLEARANCE * visual_scale(), DROP_SWING_TIME)
                Phase.SWING_DROP:
                        _start_pose(Phase.DESCEND_DROP, _drop_target, DROP_DESCEND_TIME)
                Phase.DESCEND_DROP:


                        if _carrying() and not _drop_run_clear():
                                var now:= Time.get_ticks_msec() * 0.001
                                if _hold_since == 0.0:
                                        _hold_since = now
                                        _hold_retry_at = now + HOLD_CLEAR_SECONDS


                                if _recommit_drop():
                                        return


                                if now >= _hold_retry_at:
                                        _hold_retry_at = now + HOLD_RETRY


                                        if _waits_for_traffic():
                                                _drop_fault = FAULT_NONE
                                                _move_to_empty_belt()
                                                return


                                        _drop_fault = FAULT_NONE
                                        if _repoint_on_run():
                                                return
                                        if _recommit_drop(false):
                                                return


                                        _hold_tries += 1


                                        if _hold_tries >= ALERT_TRIES:
                                                _start_pose(Phase.PARK_HOLD, _home_world_target(), 0.75)
                                                return


                                return
                        _hold_since = 0.0
                        _hold_tries = 0
                        _release_payload()
                        _start_claw(Phase.OPEN_CLAWS, CLAW_OPEN, 0.22)
                Phase.OPEN_CLAWS:
                        _start_pose(Phase.RETURN_HOME, _home_world_target(), 0.75)
                Phase.RETURN_HOME:
                        _phase = Phase.IDLE
                        _scan_left = Cfg.ROBOT_ARM_IDLE_SECONDS
                Phase.PARK_HOLD:
                        _park_with_load()


static var wait_in_place:= true


func _waits_for_traffic() -> bool:
        if BuildManager.legacy_arm_aim or not wait_in_place:
                return false
        if _drop_run == null or not is_instance_valid(_drop_run):
                return false
        if not _drop_run.is_flowing():
                return false
        var legal:= _release_on_run(_drop_run, _drop_target, _payload_count,
                _payload_prop, false)
        if legal.is_empty():
                return false
        return (legal ["point"] as Vector3).distance_to(_drop_target) < 0.05


static func _carries_nothing(run: BeltPath) -> bool:
        return run._riders.is_empty() and run.run.count() == 0


func _move_to_empty_belt() -> bool:
        var belt:= _choose_drop(_payload_count, _payload_prop, null, true, _drop_run,
                _swing_down_seconds(), true)
        if belt.is_empty():
                return false
        _drop_target = belt ["point"]
        _drop_run = belt.get("conveyor") as BeltPath
        _drop_velocity = (belt ["forward"] as Vector3) * Tech.belt_speed() + Vector3.DOWN * 0.1
        _hold_since = 0.0
        _start_pose(Phase.SWING_DROP,
                _drop_target + Vector3.UP * DROP_CLEARANCE * visual_scale(), 0.85)
        return true


const WAIT_SAY_SECONDS:= 0.3


func waiting_reason() -> String:
        if placement_preview:
                return ""
        if is_clear():
                return tr("ALL CLEAR  ·  nothing left in reach, it waits for more")
        if not _carrying():
                return ""
        if _phase != Phase.DESCEND_DROP or _hold_since == 0.0:
                return ""
        if Time.get_ticks_msec() * 0.001 - _hold_since < WAIT_SAY_SECONDS:
                return ""
        return tr("WAITING FOR A GAP  ·  the belt is too busy to take more right now")


func is_clear() -> bool:
        return _clear and _phase == Phase.IDLE and not switched_off and accept_mask != 0 and MachinePower.fault(power, power_blocked, power_line) == ""


const PLATE_WORKING:= 0
const PLATE_WAITING:= 1
const PLATE_STOPPED:= 2

const RATE_WINDOW:= 60.0


const RATE_MIN_SPAN:= 15.0


func plate_status(sign_up: bool) -> Array:
        if switched_off:
                return [PLATE_STOPPED, tr("Turned off. It will not move until you turn it on.")]
        if power <= 0.0:
                if power_blocked:
                        return [PLATE_STOPPED,
                                tr("No power. A pole is near, but something blocks the cable.")]
                if power_line == MachinePower.LINE_OUT_OF_HAY:
                        return [PLATE_STOPPED, tr("No power. The generator is out of hay.")]
                if power_line == MachinePower.LINE_NO_GENERATOR:
                        return [PLATE_STOPPED, tr("No power. Nothing on its line makes power.")]
                return [PLATE_STOPPED, tr("No power. Put a power pole near it.")]
        if accept_mask == 0:
                return [PLATE_STOPPED, tr("Nothing is ticked, so it picks nothing up.")]


        if (accept_mask & ~ PICK_LOCKED) == 0 and is_clear():
                return [PLATE_WAITING,
                        tr("Only needles are ticked, so it waits for a needle. Tick more below.")]
        if is_clear() and _takes_from_belts() and _only_overflow():
                return [PLATE_WAITING, tr("It leaves its belt alone until the belt gets stuck, then helps out.")]
        if is_clear() and _takes_from_belts():
                return [PLATE_WAITING, tr("Nothing on its belts that it is ticked to take. It waits for the next one.")]
        if is_clear():
                if belts_in_reach() == 0:
                        return [PLATE_WAITING,
                                tr("Nothing to pick up in its radius, and no belt to put it on.")]
                return [PLATE_WAITING,
                        tr("Nothing left to pick up in its radius. It starts again when more arrives.")]
        if _hold_tries >= ALERT_TRIES or (sign_up and _stall != ""):
                return [PLATE_STOPPED, _fault_sentence()]
        if waiting_reason() != "":
                return [PLATE_WAITING, tr("The belt is busy. It holds the load until a gap comes.")]
        if _stall != "":
                return [PLATE_WAITING, tr("Waiting for room on a belt.")]
        var rate:= hay_per_minute()
        var belts:= belts_in_reach()
        if rate <= 0:
                return [PLATE_WORKING, tr_n("Lifting its first load, for %d belt.",
                        "Lifting its first load, for %d belts.", belts) % belts]
        return [PLATE_WORKING, tr_n("Moving %d hay a minute onto %d belt.",
                "Moving %d hay a minute onto %d belts.", belts) % [rate, belts]]


func _fault_sentence() -> String:
        match _drop_fault:
                FAULT_NO_BELT:
                        return no_belt_sentence(_neighbour())
                FAULT_TOO_SHORT:
                        return tr("The belt here is too short for a load. Lay a longer one.")
                FAULT_OUT_OF_REACH:
                        return tr("The belt is just past its reach. Move the arm closer.")
        return tr("Every belt it can reach is full. Clear the line it feeds.")


func hay_per_minute() -> int:
        var now:= Time.get_ticks_msec() * 0.001
        _trim_loads(now)
        var total:= 0
        for n in _load_counts:
                total += n
        if total == 0:
                return 0
        var span:= clampf(now - _born, RATE_MIN_SPAN, RATE_WINDOW) if _born >= 0.0 else RATE_WINDOW
        return int(round(total * RATE_WINDOW / span))


func _note_load(count: int) -> void:
        var now:= Time.get_ticks_msec() * 0.001
        _trim_loads(now)
        _load_times.append(now)
        _load_counts.append(count)


func _trim_loads(now: float) -> void:
        var drop:= 0
        while drop < _load_times.size() and now - _load_times [drop] > RATE_WINDOW:
                drop += 1
        if drop > 0:
                _load_times = _load_times.slice(drop)
                _load_counts = _load_counts.slice(drop)


func belts_in_reach() -> int:
        if builds == null:
                return 0
        var n:= 0
        for pick in builds.conveyor_drops(_shoulder_world(), work_reach()):
                if _may_put_on(pick.get("conveyor") as BeltPath):
                        n += 1
        return n


func _park_with_load() -> void:
        if not _carrying():
                _start_pose(Phase.RETURN_HOME, _home_world_target(), 0.1)
                return
        var now:= Time.get_ticks_msec() * 0.001
        if now < _hold_retry_at:
                return
        _hold_retry_at = now + HOLD_RETRY
        _drop_fault = FAULT_NONE
        var ahead:= _swing_down_seconds()
        var belt:= { }
        if _drop_run != null and is_instance_valid(_drop_run):
                belt = _choose_drop(_payload_count, _payload_prop, _drop_run, true, null, ahead)
        if belt.is_empty():
                belt = _choose_drop(_payload_count, _payload_prop, null, true, null, ahead)
        if belt.is_empty():
                return
        _drop_target = belt ["point"]
        _drop_run = belt.get("conveyor") as BeltPath
        _drop_velocity = (belt ["forward"] as Vector3) * Tech.belt_speed() + Vector3.DOWN * 0.1
        _hold_since = 0.0
        _start_pose(Phase.SWING_DROP,
                _drop_target + Vector3.UP * DROP_CLEARANCE * visual_scale(), DROP_SWING_TIME)


func _room_on(run: BeltPath, point: Vector3, count: int,
                prop: Carryable = null, ahead: float = 0.0) -> bool:
        if run == null or not is_instance_valid(run):
                return false
        var speed:= Tech.belt_speed()
        var half:= _footprint(count, prop)


        var landing:= point
        if _boards_as_record(run, count, prop):
                var kind:= BeltPath.record_kind(prop) if prop != null else BeltRun.Kind.WAD
                var strands:= prop.hay_strands() if prop != null else count
                if not run.has_room_to_board(point, kind, strands, half, speed, ahead):
                        return false
        else:


                if prop == null and HayWad.split(count).is_empty():
                        return run.has_room_to_land(point, speed, _drop_lead(), half, ahead)
                if not run.has_room_to_land(point, speed, _drop_lead(), half, ahead):
                        return false
                landing = run.landing_point(point, speed)


        var box:= _block_box(prop)
        if box != Vector3.ZERO:
                return Carryable.room_for(_space(), landing, Basis(), box,
                        _own_prop_exclusion())
        return HayWad.room_at(_space(), landing, count, _own_prop_exclusion())


func _boards_as_record(run: BeltPath, count: int, prop: Carryable = null) -> bool:
        if run == null or not is_instance_valid(run) or not run.records_props:
                return false
        if prop != null:
                return not run.record_only and BeltPath.record_kind(prop) >= 0
        return not HayWad.split(count).is_empty()


func _block_box(prop: Carryable) -> Vector3:
        if prop == null or not is_instance_valid(prop):
                return Vector3.ZERO
        var size:= prop.clearance_size()
        if size.z <= 0.0:
                return Vector3.ZERO
        var across:= maxf(size.x, size.z)
        return Vector3(across, size.y, across)


func _footprint(count: int, prop: Carryable = null) -> float:
        var box:= _block_box(prop)
        if box != Vector3.ZERO:
                return box.z * 0.5
        if prop == null and HayWad.split(count).is_empty():
                return Cfg.STRAND_THICK
        return Cfg.WAD_CLEAR * 0.5 * HayWad.scale_for(maxi(count, 1))


const DROP_SETTLE_SECONDS:= 0.3


func _drop_lead() -> float:
        return maxf(0.0, Tech.belt_speed() * DROP_SETTLE_SECONDS)


func _own_prop_exclusion() -> Array [RID]:
        var wad:= _payload_prop if _payload_prop != null else _pickup_prop
        if wad == null or not is_instance_valid(wad):
                return []
        return [wad.get_rid()]


func _drop_run_clear() -> bool:
        if _drop_run == null or not is_instance_valid(_drop_run):
                return false
        return _room_on(_drop_run, _drop_target, _payload_count, _payload_prop)


const DROP_SWING_TIME:= 0.85
const DROP_DESCEND_TIME:= 0.42


func _swing_down_seconds() -> float:
        if BuildManager.legacy_arm_aim:
                return 0.0
        return (DROP_SWING_TIME + DROP_DESCEND_TIME) * float(tier_data() ["cycle_scale"]) * Tech.arm_cycle_scale()


func _aim_at_coming_gap() -> void:
        if BuildManager.legacy_arm_aim:
                return
        if not _carrying() or _drop_run == null or not is_instance_valid(_drop_run):
                return
        var belt:= _choose_drop(_payload_count, _payload_prop, _drop_run,
                true, null, _swing_down_seconds())
        if belt.is_empty():
                return
        _drop_target = belt ["point"]
        _drop_velocity = (belt ["forward"] as Vector3) * Tech.belt_speed() + Vector3.DOWN * 0.1


func _repoint_on_run() -> bool:
        if _drop_run == null or not is_instance_valid(_drop_run):
                return false


        var belt:= _choose_drop(_payload_count, _payload_prop, _drop_run,
                true, null, _swing_down_seconds())
        if belt.is_empty():
                return false
        var point:= belt ["point"] as Vector3

        if point.is_equal_approx(_drop_target):
                return false
        _drop_target = point
        _drop_velocity = (belt ["forward"] as Vector3) * Tech.belt_speed() + Vector3.DOWN * 0.1
        _hold_since = 0.0


        _start_pose(Phase.SWING_DROP,
                _drop_target + Vector3.UP * DROP_CLEARANCE * visual_scale(), 0.85)
        return true


func _recommit_drop(gone_only: bool = true) -> bool:
        if gone_only and _drop_run != null and is_instance_valid(_drop_run):
                return false


        var skip: BeltPath = null
        if not gone_only and is_instance_valid(_drop_run):
                skip = _drop_run
        var belt:= _choose_drop(_payload_count, _payload_prop, null, true, skip,
                _swing_down_seconds())
        if belt.is_empty():
                return false
        _drop_target = belt ["point"]
        _drop_run = belt.get("conveyor") as BeltPath


        _hold_since = 0.0


        _drop_velocity = belt ["forward"] * Tech.belt_speed() + Vector3.DOWN * 0.1


        _start_pose(Phase.SWING_DROP,
                _drop_target + Vector3.UP * DROP_CLEARANCE * visual_scale(), 0.85)
        return true


func _space() -> PhysicsDirectSpaceState3D:
        if not is_inside_tree():
                return null
        return get_world_3d().direct_space_state


func _start_pose(next_phase: Phase, world_target: Vector3, base_duration: float) -> void:
        _phase = next_phase
        _phase_elapsed = 0.0
        var cycle:= float(tier_data() ["cycle_scale"]) * Tech.arm_cycle_scale()
        _phase_duration = base_duration * cycle
        _pose_from = _angles
        _pose_target = world_target
        _pose_to = _solve_world_target(world_target)


func _start_claw(next_phase: Phase, target_angle: float, base_duration: float) -> void:
        _phase = next_phase
        _phase_elapsed = 0.0
        var cycle:= float(tier_data() ["cycle_scale"]) * Tech.arm_cycle_scale()
        _phase_duration = base_duration * cycle
        _claw_from = _claw_angle
        _claw_to = target_angle


func _home_world_target() -> Vector3:
        return global_transform * (HOME_TARGET * visual_scale())


func _shoulder_world() -> Vector3:
        return global_position + Vector3.UP * SHOULDER_HEIGHT * visual_scale()


func _solve_world_target(world_target: Vector3) -> Vector4:
        var local:= global_transform.affine_inverse() * world_target
        return _solve_authored_target(local / visual_scale())


func _solve_authored_target(target: Vector3) -> Vector4:
        var yaw:= atan2(target.x, target.z)
        var radial:= Vector2(target.x, target.z).length()
        var wrist_r:= radial - TOOL_OFFSET * sin(TOOL_PITCH)
        var wrist_y:= (target.y - SHOULDER_HEIGHT) - TOOL_OFFSET * cos(TOOL_PITCH)
        var wrist_len:= Vector2(wrist_r, wrist_y).length()
        var min_len:= absf(UPPER_ARM - FOREARM) + 0.02
        var max_len:= UPPER_ARM + FOREARM - 0.02
        if wrist_len < min_len or wrist_len > max_len:
                var clamped_len:= clampf(wrist_len, min_len, max_len)
                var ratio:= clamped_len / maxf(wrist_len, 0.001)
                wrist_r *= ratio
                wrist_y *= ratio
        var cosine:= clampf(
                (wrist_r * wrist_r + wrist_y * wrist_y - UPPER_ARM * UPPER_ARM - FOREARM * FOREARM)
                / (2.0 * UPPER_ARM * FOREARM), -1.0, 1.0)
        var beta:= - acos(cosine)
        var alpha:= atan2(wrist_y, wrist_r) - atan2(
                FOREARM * sin(beta), UPPER_ARM + FOREARM * cos(beta))
        var shoulder_angle:= PI * 0.5 - alpha
        var elbow_angle:= - beta
        var tool_angle:= TOOL_PITCH - shoulder_angle - elbow_angle
        return Vector4(yaw, shoulder_angle, elbow_angle, tool_angle)


func _lerp_angles(from: Vector4, to: Vector4, amount: float) -> Vector4:
        return Vector4(
                lerp_angle(from.x, to.x, amount),
                lerp_angle(from.y, to.y, amount),
                lerp_angle(from.z, to.z, amount),
                lerp_angle(from.w, to.w, amount))


func _apply_angles(value: Vector4) -> void:
        if _model == null:
                return
        _angles = value
        if not is_equal_approx(_base_yaw.rotation.y, value.x):
                _base_yaw.rotation.y = value.x
        if not is_equal_approx(_shoulder.rotation.x, value.y):
                _shoulder.rotation.x = value.y
        if not is_equal_approx(_elbow.rotation.x, value.z):
                _elbow.rotation.x = value.z
        if not is_equal_approx(_tool.rotation.x, value.w):
                _tool.rotation.x = value.w


func _apply_claw(value: float) -> void:
        _claw_angle = value
        for claw in _claws:
                if not is_equal_approx(claw.rotation.z, value):
                        claw.rotation.z = value


func _claim_payload() -> void:


        if _payload_prop != null:
                return
        _payload_pose_valid = false
        _payload.clear()
        _payload_count = 0
        if live == null or _socket == null:
                return
        if _pickup_needle != null:
                _claim_needle_payload()
                return
        if _pickup_prop != null:
                _claim_prop_payload()
                return
        var want:= Tech.arm_capacity(int(tier_data() ["capacity"]))
        var bodies: Array [RigidBody3D]
        if _pickup_from_field:
                bodies = _harvest_field_payload(want)
        else:
                bodies = live.claim_hay_near(
                        _pickup_source, HAY_CLUSTER_RADIUS * visual_scale(), want)
                _payload_count = bodies.size()


                while bodies.size() > Tech.arm_visual_cap():
                        live.consume(bodies.pop_back())
        last_payload_count = _payload_count
        var socket_basis:= _socket.global_basis.orthonormalized()
        for i in bodies.size():
                var body:= bodies [i]
                var angle:= float(i) * 2.399963
                var ring:= 0.035 + 0.018 * float(i % 4)
                var offset:= Vector3(cos(angle) * ring, float((i % 3) - 1) * 0.022, sin(angle) * ring)
                var local_basis:= socket_basis.inverse() * body.global_basis.orthonormalized()
                if not _pickup_from_field or sample_physics_enabled:
                        body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
                        body.freeze = true
                        body.linear_velocity = Vector3.ZERO
                        body.angular_velocity = Vector3.ZERO
                _payload.append({ "body": body, "offset": offset, "basis": local_basis,
                        "layer": Cfg.L_STRAND if _pickup_from_field and not sample_physics_enabled else body.collision_layer,
                        "mask": LiveStrandManager.STRAND_MASK if _pickup_from_field and not sample_physics_enabled else body.collision_mask })


                body.collision_layer = 0
                body.collision_mask = 0
        _build_payload_visual()
        _update_payload()


func _claim_prop_payload() -> void:
        _payload_pose_valid = false
        var wad:= _pickup_prop
        if wad == null or not is_instance_valid(wad) or wad.is_held() or BeltPath.is_rider(wad):
                _unclaim_prop()
                return


        if _shoulder_world().distance_to(wad.global_position) > reach_m():
                _unclaim_prop()
                return


        if not accepts(_kind_of(wad)):
                _unclaim_prop()
                return
        _hold_prop(wad)


func _hold_prop(wad: Carryable) -> void:
        _payload_pose_valid = false
        wad.pick_up()
        _payload_prop = wad
        _payload_count = wad.hay_strands()
        last_payload_count = _payload_count
        _pickup_prop = null
        _update_payload()


func _claim_needle_payload() -> void:
        _payload_pose_valid = false
        var needle:= _pickup_needle
        _pickup_needle = null
        if needle == null or not is_instance_valid(needle):
                return


        if BeltPath.is_rider(needle) or (needle.freeze and not LiveStrandManager.is_pinned(needle)) or needle.get_meta(LiveStrandManager.META_PROTECTED, false):
                _unclaim_needle(needle)
                return


        if _shoulder_world().distance_to(needle.global_position) > reach_m():
                _unclaim_needle(needle)
                return
        LiveStrandManager.unpin(needle)
        BeltPath.release(needle)
        live.set_protected(needle, true)
        live.set_ccd(needle, true)
        needle.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
        needle.freeze = true
        needle.linear_velocity = Vector3.ZERO
        needle.angular_velocity = Vector3.ZERO
        _payload_needle = needle
        _update_payload()


func _harvest_field_payload(want: int) -> Array [RigidBody3D]:
        var bodies: Array [RigidBody3D] = []
        if field == null or live == null:
                return bodies
        var radius:= 0.5 * visual_scale()


        var under:= int(floor(field.strands_under(_pickup_source, radius)))
        var capacity:= mini(mini(want, int(floor(GameState.hay_total))), under)
        if capacity <= 0:
                return bodies
        var bite_started:= Time.get_ticks_usec()


        GameState.remove_hay(float(capacity))
        field.carve_volume(_pickup_source, radius,
                float(capacity) * Cfg.STRAND_VOLUME / Cfg.PACKING)


        var room:= want - capacity
        var rest:= field.strands_under(_pickup_source, radius)
        if room > 0 and rest > 0.0 and rest <= float(room) + 0.5:
                var swept:= int(round(field.sweep_under(_pickup_source, radius, Shovel.SWEEP_HEIGHT)))
                if swept > 0:
                        GameState.remove_hay(float(swept))
                        capacity += swept
        _payload_count = capacity
        for i in mini(capacity, Tech.arm_visual_cap()):
                var body:= live.spawn(_socket.global_position,
                        StrandFactory.random_strand_basis(_harvest_rng),
                        Vector3.ZERO, StrandFactory.random_tint(_harvest_rng), not sample_physics_enabled)
                if body == null:
                        continue
                live.set_protected(body, true)
                bodies.append(body)
        live.reveal_needles_in(_pickup_source, radius)
        Audio.play_3d("hay_rustle", _pickup_source, -3.0)


        field.charge_frame(Time.get_ticks_usec() - bite_started)
        return bodies


func _carrying() -> bool:
        return not _payload.is_empty() or _payload_prop != null or _payload_needle != null or _payload_count > 0


func _build_payload_visual() -> void:
        if _payload.is_empty() or "--legacy-arm-payload" in OS.get_cmdline_user_args():
                return
        var mm:= MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.mesh = StrandFactory.strand_mesh()
        mm.instance_count = _payload.size()
        for i in _payload.size():
                var entry: Dictionary = _payload [i]
                var body:= entry ["body"] as RigidBody3D
                var basis: Basis = entry ["basis"]
                basis.z *= float(body.get_meta(LiveStrandManager.META_LEN, 1.0))
                mm.set_instance_transform(i, Transform3D(basis, entry ["offset"]))
                var tint: Color = body.get_meta(LiveStrandManager.META_COLOR, Color.WHITE)
                tint.a = 0.0
                mm.set_instance_color(i, tint)
                live.set_local_visual(body, true)
        _payload_visual = MultiMeshInstance3D.new()
        _payload_visual.name = "ClawStraw"
        _payload_visual.multimesh = mm
        _payload_visual.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
        _payload_visual.top_level = true
        add_child(_payload_visual)


func _materialize_payload() -> void:
        if _payload_visual == null:
                return
        var pose:= Transform3D(_payload_pose.basis.orthonormalized(), _payload_pose.origin)
        for entry in _payload:
                var body:= entry ["body"] as RigidBody3D
                if not is_instance_valid(body):
                        continue
                var world_pose:= pose * Transform3D(entry ["basis"], entry ["offset"])


                if body.is_inside_tree():
                        body.global_transform = world_pose
                        body.force_update_transform()
                        PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, world_pose)
                        if not PhysicsServer3D.body_get_space(body.get_rid()).is_valid():
                                PhysicsServer3D.body_set_space(body.get_rid(), body.get_world_3d().space)
                        body.reset_physics_interpolation()
                if is_instance_valid(live):
                        live.set_local_visual(body, false)
                else:
                        body.remove_meta(LiveStrandManager.META_LOCAL_VISUAL)
        _clear_payload_visual()


func _clear_payload_visual() -> void:
        if _payload_visual == null:
                return
        _payload_visual.visible = false
        _payload_visual.queue_free()
        _payload_visual = null


func _update_payload() -> void:
        if _socket == null:
                return
        if _payload_needle == null and _payload_prop == null and _payload.is_empty():
                _payload_pose_valid = false
                return
        var socket_pose:= _socket.global_transform
        if _payload_pose_valid and socket_pose.is_equal_approx(_payload_pose):
                return
        _payload_pose = socket_pose
        _payload_pose_valid = true
        if _payload_needle != null:
                if is_instance_valid(_payload_needle):


                        _payload_needle.global_transform = Transform3D(
                                _socket.global_basis.orthonormalized(), _socket.global_position)
                return
        if _payload_prop != null:
                if is_instance_valid(_payload_prop):


                        _payload_prop.global_transform = Transform3D(
                                _socket.global_basis.orthonormalized(), _socket.global_position)
                return
        if _payload.is_empty():
                return
        var socket_basis:= _socket.global_basis.orthonormalized()
        if _payload_visual != null:
                _payload_visual.global_transform = Transform3D(socket_basis, _socket.global_position)
                return
        for entry in _payload:
                var body:= entry ["body"] as RigidBody3D
                if not is_instance_valid(body):
                        continue
                body.global_transform = Transform3D(
                        socket_basis * (entry ["basis"] as Basis),
                        _socket.global_position + socket_basis * (entry ["offset"] as Vector3))


func _release_payload() -> void:
        _payload_pose_valid = false
        _update_payload()
        last_record_seq = -1
        var ignore_until:= Time.get_ticks_msec() * 0.001 + RELEASE_COOLDOWN


        last_cycle_needle = _payload_needle != null
        if last_cycle_needle:
                _release_carried_needle(ignore_until)
        elif _payload_prop != null:
                _release_carried_prop(ignore_until)
        else:
                var wads:= HayWad.split(_payload_count)
                if wads.is_empty():
                        _materialize_payload()
                        _release_as_strands(ignore_until)
                else:
                        _clear_payload_visual()
                        _release_as_wads(wads)
        if _payload_count > 0:


                Audio.play_3d("hay_place", _drop_target, -12.0)
                last_cycle_from_field = _pickup_from_field
                completed_cycles += 1
                _note_load(_payload_count)
        _payload.clear()
        _payload_prop = null
        _payload_needle = null
        _payload_count = 0


func _release_carried_needle(ignore_until: float) -> void:
        var needle:= _payload_needle
        _payload_needle = null
        if needle == null or not is_instance_valid(needle):


                return
        _unclaim_needle(needle)


        needle.set_meta(LiveStrandManager.META_ARM_IGNORE_UNTIL, ignore_until)
        needle.global_position = _drop_target
        live.set_protected(needle, false)


        live.set_ccd(needle, true)
        needle.freeze = false
        needle.sleeping = false
        needle.linear_velocity = _drop_velocity
        needle.angular_velocity = Vector3.ZERO


        LiveStrandManager.hold(needle, 0.6)
        completed_cycles += 1
        delivered_needles += 1


func _release_carried_prop(ignore_until: float) -> void:
        var wad:= _payload_prop
        _payload_prop = null
        if wad == null or not is_instance_valid(wad):


                return
        if wad.has_meta(PropManager.META_CLAIM) and int(wad.get_meta(PropManager.META_CLAIM)) == get_instance_id():
                wad.remove_meta(PropManager.META_CLAIM)


        wad.set_meta(LiveStrandManager.META_ARM_IGNORE_UNTIL, ignore_until)
        wad.global_position = _drop_target


        if _board_dropped(wad, _payload_count):
                return
        wad.release(_drop_velocity)


func _release_as_strands(ignore_until: float) -> void:
        for entry in _payload:
                var body:= entry ["body"] as RigidBody3D
                if not is_instance_valid(body):
                        continue
                body.set_meta(LiveStrandManager.META_ARM_IGNORE_UNTIL, ignore_until)
                live.set_protected(body, false)
                live.set_ccd(body, true)
                body.collision_layer = int(entry.get("layer", Cfg.L_STRAND))
                body.collision_mask = int(entry.get("mask", LiveStrandManager.STRAND_MASK))
                body.freeze = false
                body.sleeping = false
                body.linear_velocity = _drop_velocity
        var unseen:= _payload_count - _payload.size()
        if unseen <= 0 or live == null or _socket == null:
                return
        for _i in unseen:
                if not live.has_headroom():


                        GameState.return_hay(float(unseen - _i))
                        return
                var extra:= live.spawn(_socket.global_position,
                        StrandFactory.random_strand_basis(_harvest_rng),
                        _drop_velocity, StrandFactory.random_tint(_harvest_rng))
                if extra == null:
                        GameState.return_hay(float(unseen - _i))
                        return
                extra.set_meta(LiveStrandManager.META_ARM_IGNORE_UNTIL, ignore_until)


func _release_as_wads(wads: Array [int]) -> void:


        for entry in _payload:
                var body:= entry ["body"] as RigidBody3D
                if is_instance_valid(body):
                        live.set_protected(body, false)
                        live.consume(body)
        if props == null:


                push_warning("RoboticArm: no PropManager; %d strands returned to the pile"
                        % _payload_count)
                GameState.return_hay(float(_payload_count))
                return


        var along:= _drop_velocity
        along.y = 0.0
        along = along.normalized() if along.length_squared() > 0.0001 else global_basis.z
        var basis:= global_basis.orthonormalized()
        for i in wads.size():
                var count: int = wads [i]
                var step:= Cfg.WAD_CLEAR * HayWad.scale_for(count)
                var at:= _drop_target + along * (float(i) - float(wads.size() - 1) * 0.5) * step


                if _push_wad_record(count, at):
                        continue
                var wad:= props.spawn("hay_wad", Transform3D(basis, at),
                        { "strands": count }) as HayWad
                if wad == null:
                        GameState.return_hay(float(count))
                        continue
                wad.linear_velocity = _drop_velocity

                wad.mute_impact(ARM_DROP_MUTE)


func _board_dropped(block: Carryable, count: int) -> bool:
        if _drop_run == null or not is_instance_valid(_drop_run) or not _drop_run.records_props:
                return false
        var seq:= _drop_run.board_body(block, _drop_target, Tech.belt_speed(),
                _footprint(count, block))
        if seq < 0:
                return false
        last_record_seq = seq
        dropped_record.emit(seq)
        return true


func _push_wad_record(count: int, at: Vector3) -> bool:
        if _drop_run == null or not is_instance_valid(_drop_run) or not _drop_run.records_props:
                return false
        var seq:= _drop_run.push_record(BeltRun.Kind.WAD, count, -1, { "strands": count }, at,
                Tech.belt_speed(), _footprint(count))
        if seq < 0:
                return false
        last_record_seq = seq
        dropped_record.emit(seq)
        return true


const LINK_NONE:= 0
const LINK_TAKE:= 1
const LINK_PUT:= 2


const LINK_SNAP:= 0.35

const TAKE_GRAB:= 0.45


const TAKE_UPSTREAM:= 1.2


const TAKE_WAIT:= 4.0


const LINK_CHECK:= 0.5


const STUCK_SECONDS:= 1.5
const STUCK_SPAN:= 1.0


const COL_TAKE:= Color(1.0, 0.52, 0.1)
const COL_PUT:= Color(0.26, 0.6, 1.0)


var _links: Array [Dictionary] = []

var _pickup_run: BeltPath


var _pickup_stuck_only:= false

var _take_wait_until:= 0.0


var _clock:= 0.0

var _choosing:= false

var _marks: Node3D

var _marks_key:= ""
var _links_check:= 0.0
static var _mark_mats: Dictionary = { }


static func links_unlocked() -> bool:
        return Tech.belt_links_unlocked()


static func linkable(run: BeltPath) -> bool:
        if run == null or not is_instance_valid(run):
                return false
        if run is EnclosedConveyor or run is EnclosedConveyorCorner:
                return false
        return run is Conveyor or run is ConveyorCorner


const REACH_STRIP_STEP:= 0.1


static func reach_strip(runs: Array, shoulder: Vector3, reach: float) -> PackedVector3Array:
        var verts:= PackedVector3Array()
        var half:= Cfg.BELT_WIDTH * 0.45
        var reach2:= reach * reach

        var strips: Array [Dictionary] = []
        for item in runs:
                var run:= item as BeltPath
                if run == null or not is_instance_valid(run):
                        continue
                var length:= run.path_length()
                var steps:= maxi(1, ceili(length / REACH_STRIP_STEP))
                var mids:= PackedVector3Array()
                var across:= PackedVector3Array()
                var inside: Array [bool] = []
                for i in steps + 1:
                        var s:= minf(length, float(i) * length / float(steps))
                        var p:= run._point_at(s)
                        var frame:= run._basis_at(s)
                        mids.append(p + frame.y * 0.05)
                        across.append(frame.x * half)
                        inside.append((p + Vector3.UP * 0.26).distance_squared_to(shoulder) < reach2)
                strips.append({ "mid": mids, "across": across, "inside": inside })
        _mitre_strip_ends(strips, half)
        for strip in strips:
                var mids: PackedVector3Array = strip ["mid"]
                var across: PackedVector3Array = strip ["across"]
                var inside: Array [bool] = strip ["inside"]
                for i in range(1, mids.size()):
                        if not (inside [i] and inside [i - 1]):
                                continue
                        var prev_l:= mids [i - 1] - across [i - 1]
                        var prev_r:= mids [i - 1] + across [i - 1]
                        var l:= mids [i] - across [i]
                        var r:= mids [i] + across [i]
                        verts.append_array([prev_l, prev_r, r, prev_l, r, l])
        return verts


const REACH_STRIP_JOIN:= 0.03


static func _mitre_strip_ends(strips: Array [Dictionary], half: float) -> void:

        var ends: Array = []
        for k in strips.size():
                var n: int = (strips [k] ["mid"] as PackedVector3Array).size()
                ends.append([k, 0])
                if n > 1:
                        ends.append([k, n - 1])
        var join2:= REACH_STRIP_JOIN * REACH_STRIP_JOIN
        for a in ends.size():
                for b in range(a + 1, ends.size()):
                        if ends [a] [0] == ends [b] [0]:
                                continue
                        var sa: Dictionary = strips [ends [a] [0]]
                        var sb: Dictionary = strips [ends [b] [0]]
                        var ia: int = ends [a] [1]
                        var ib: int = ends [b] [1]
                        var mid_a: PackedVector3Array = sa ["mid"]
                        var mid_b: PackedVector3Array = sb ["mid"]
                        if mid_a [ia].distance_squared_to(mid_b [ib]) > join2:
                                continue
                        var across_a: PackedVector3Array = sa ["across"]
                        var across_b: PackedVector3Array = sb ["across"]
                        var xa:= across_a [ia].normalized()
                        var xb:= across_b [ib].normalized()

                        var flip:= xa.dot(xb) < 0.0
                        if flip:
                                xb = - xb
                        var bisector:= (xa + xb).normalized()
                        if bisector == Vector3.ZERO:
                                continue


                        var width:= half / maxf(0.5, bisector.dot(xa))
                        var shared:= (mid_a [ia] + mid_b [ib]) * 0.5
                        mid_a [ia] = shared
                        mid_b [ib] = shared
                        across_a [ia] = bisector * width
                        across_b [ib] = (- bisector if flip else bisector) * width

                        sa ["mid"] = mid_a
                        sa ["across"] = across_a
                        sb ["mid"] = mid_b
                        sb ["across"] = across_b


func links() -> Array [Dictionary]:
        _resolve_links()
        return _links


func link_role(run: BeltPath) -> int:
        for link: Dictionary in _links:
                if _link_run(link) == run:
                        return int(link ["role"])
        return LINK_NONE


func link_in_reach(at: Vector3) -> bool:
        var r:= work_reach()
        return (at + Vector3.UP * 0.26).distance_squared_to(_shoulder_world()) < r * r


func set_link(run: BeltPath, at: Vector3, role: int) -> int:
        if not linkable(run) or role == LINK_NONE:
                return link_role(run)
        var point:= run._point_at(run.s_at(at))
        for i in _links.size():
                var link: Dictionary = _links [i]
                if _link_run(link) != run:
                        continue
                if int(link ["role"]) == role:
                        _links.remove_at(i)
                        _links_changed()
                        return LINK_NONE
                if not link_in_reach(point):
                        return int(link ["role"])
                link ["role"] = role
                link ["at"] = point

                link.erase("stuck")
                _links_changed()
                return role
        if not link_in_reach(point):
                return LINK_NONE
        _links.append({ "role": role, "at": point, "run": run })
        _links_changed()
        return role


func unlink(run: BeltPath) -> void:
        for i in _links.size():
                if _link_run(_links [i]) == run:
                        _links.remove_at(i)
                        _links_changed()
                        return


func unlink_all() -> void:
        if _links.is_empty():
                return
        _links.clear()
        _links_changed()


func _links_changed() -> void:
        _stall = ""
        _clear = false
        _scan_left = minf(_scan_left, 0.15)
        _marks_key = ""
        _sync_ring()


func set_choosing(on: bool) -> void:
        _choosing = on
        _marks_key = ""
        _sync_ring()


func _link_run(link: Dictionary) -> BeltPath:
        var run: Variant = link.get("run")
        if run == null or not is_instance_valid(run):
                return null
        return run as BeltPath


func _resolve_links() -> void:
        var dropped:= false
        for i in range(_links.size() - 1, -1, -1):
                var link: Dictionary = _links [i]
                var run:= _link_run(link)
                if run != null and run.is_inside_tree() and not run.is_queued_for_deletion():
                        continue
                var found:= _belt_at(link ["at"])
                if found == null:
                        _links.remove_at(i)
                        dropped = true
                else:
                        link ["run"] = found
        if dropped:
                _links_changed()


func _belt_at(at: Vector3) -> BeltPath:
        if builds == null:
                return null
        var best: BeltPath = null
        var best_d:= LINK_SNAP
        for list: Array in [builds.conveyors, builds.corners]:
                for item: Variant in list:
                        if item == null or not is_instance_valid(item):
                                continue
                        var run:= item as BeltPath
                        if not linkable(run) or not run.is_inside_tree() or run.is_queued_for_deletion() or run.path_length() <= 0.0:
                                continue
                        var d:= run._point_at(run.s_at(at)).distance_to(at)
                        if d <= best_d:
                                best_d = d
                                best = run
        return best


func links_to_save() -> Array:
        _resolve_links()
        var out: Array = []
        for link: Dictionary in _links:
                var row:= { "role": "take" if int(link ["role"]) == LINK_TAKE else "put",
                        "at": link ["at"] }
                if bool(link.get("stuck", false)):
                        row ["stuck"] = true
                out.append(row)
        return out


func load_links(list: Variant) -> void:
        _links.clear()
        _marks_key = ""
        if not list is Array:
                return
        for row: Variant in list:
                if not row is Dictionary:
                        continue
                var d:= row as Dictionary
                var word:= str(d.get("role", ""))
                var role:= LINK_TAKE if word == "take" else (LINK_PUT if word == "put" else LINK_NONE)
                var at: Variant = d.get("at")
                if role == LINK_NONE or not at is Vector3:
                        continue
                var link:= { "role": role, "at": at, "run": null }
                if role == LINK_TAKE and bool(d.get("stuck", false)):
                        link ["stuck"] = true
                _links.append(link)


func takes_when_stuck(run: BeltPath) -> bool:
        for link: Dictionary in _links:
                if _link_run(link) == run and int(link ["role"]) == LINK_TAKE:
                        return bool(link.get("stuck", false))
        return false


func set_take_when_stuck(run: BeltPath, on: bool) -> void:
        for link: Dictionary in _links:
                if _link_run(link) != run or int(link ["role"]) != LINK_TAKE:
                        continue
                if on:
                        link ["stuck"] = true
                else:
                        link.erase("stuck")
                link ["since"] = 0.0
                _links_changed()
                return


static func _stuck_only(link: Dictionary) -> bool:
        return bool(link.get("stuck", false)) and Tech.overflow_arm_unlocked()


func _link_stuck(link: Dictionary, run: BeltPath, link_s: float) -> bool:
        var standing:= false
        var moving:= false
        var belt:= run.run
        var rows:= belt.rows_in(link_s - STUCK_SPAN, link_s + STUCK_SPAN)
        for i in range(rows.x, rows.y):
                if belt.speed_of(i) <= 0.01:
                        standing = true
                else:
                        moving = true
        if not moving:
                var flowing:= run.is_flowing()
                for body in run.riders():
                        if absf(run.s_at(body.global_position) - link_s) > STUCK_SPAN:
                                continue
                        if flowing:
                                moving = true
                        else:
                                standing = true
        if moving or not standing:
                link ["since"] = 0.0
                return false
        var now:= _clock
        if float(link.get("since", 0.0)) <= 0.0:
                link ["since"] = now
        return now - float(link ["since"]) >= STUCK_SECONDS


func _only_overflow() -> bool:
        var any:= false
        for link: Dictionary in _links:
                if int(link ["role"]) != LINK_TAKE:
                        continue
                if not _stuck_only(link):
                        return false
                any = true
        return any


func _takes_from_belts() -> bool:
        if _links.is_empty() or not links_unlocked():
                return false
        _resolve_links()
        for link: Dictionary in _links:
                if int(link ["role"]) == LINK_TAKE:
                        return true
        return false


func _may_put_on(run: BeltPath) -> bool:
        if _links.is_empty() or not links_unlocked():
                return true
        _resolve_links()
        var puts:= false
        for link: Dictionary in _links:
                if int(link ["role"]) == LINK_PUT:
                        puts = true
                        if _link_run(link) == run:
                                return true
                elif _link_run(link) == run:
                        return false
        return not puts


func _put_aim(run: BeltPath, nearest: Vector3) -> Vector3:
        if _links.is_empty() or not links_unlocked():
                return nearest
        for link: Dictionary in _links:
                if int(link ["role"]) != LINK_PUT or _link_run(link) != run:
                        continue
                var at: Vector3 = link ["at"]
                var lift:= float(run._nearest(nearest) ["lift"])
                return at + run._basis_at(run.s_at(at)).y * lift
        return nearest


func _take_upstream() -> float:
        return maxf(TAKE_UPSTREAM, Tech.belt_speed() * 2.0)


func _find_belt_pickup() -> Dictionary:
        var shoulder:= _shoulder_world()
        var reach2:= work_reach() * work_reach()
        var near:= MIN_REACH * visual_scale()
        var near2:= near * near
        var up:= _take_upstream()
        var best:= { }
        var best_score:= INF
        for link: Dictionary in _links:
                if int(link ["role"]) != LINK_TAKE:
                        continue
                var run:= _link_run(link)
                if run == null:
                        continue
                var at: Vector3 = link ["at"]
                var link_s:= run.s_at(at)

                var stuck_only:= _stuck_only(link)
                if stuck_only and not _link_stuck(link, run, link_s):
                        continue
                var belt:= run.run
                var rows:= belt.rows_in(link_s - up, link_s + up)
                for i in range(rows.x, rows.y):
                        var bit:= _record_bit(belt.kind_of(i))
                        if not accepts(bit):
                                continue
                        var s:= belt.s_of(i)
                        var point:= at
                        if stuck_only and belt.speed_of(i) > 0.01:
                                continue
                        if belt.speed_of(i) <= 0.01:
                                point = belt.pose_of(i).origin
                                var d2:= point.distance_squared_to(shoulder)
                                if d2 >= reach2 or d2 < near2:
                                        continue
                        elif s > link_s + TAKE_GRAB:
                                continue
                        var score:= _belt_score(bit, belt.strands_of(i), absf(s - link_s))
                        if score < best_score:
                                best_score = score
                                best = { "run": run, "point": point, "strands": belt.strands_of(i),
                                        "stuck_only": stuck_only }


                var standing:= not run.is_flowing()
                for body in run.riders():
                        var item:= body as Carryable
                        if item == null or item.is_held() or _claimed_by_other(item):
                                continue
                        var bit:= _body_bit(item)
                        if not accepts(bit):
                                continue
                        var s:= run.s_at(item.global_position)
                        if s < link_s - up or s > link_s + up:
                                continue
                        if stuck_only and not standing:
                                continue
                        var point:= at
                        if standing:
                                point = item.global_position
                                var d2:= point.distance_squared_to(shoulder)
                                if d2 >= reach2 or d2 < near2:
                                        continue
                        elif s > link_s + TAKE_GRAB:
                                continue
                        var score:= _belt_score(bit, item.hay_strands(), absf(s - link_s))
                        if score < best_score:
                                best_score = score
                                best = { "run": run, "point": point, "strands": item.hay_strands(),
                                        "stuck_only": stuck_only }
        return best


func _belt_score(bit: int, strands: int, from_link: float) -> float:
        match pick_order_now():
                ORDER_LOOSE:
                        return from_link + (0.0 if bit == PICK_LOOSE else 1000.0)
                ORDER_BIG:
                        return from_link * 0.001 - float(strands)
        return from_link


func _claimed_by_other(item: Carryable) -> bool:
        if not item.has_meta(PropManager.META_CLAIM):
                return false
        var owner_id:= int(item.get_meta(PropManager.META_CLAIM))
        if owner_id == get_instance_id():
                return false
        var other:= instance_from_id(owner_id)
        return other != null and is_instance_valid(other)


static func _record_bit(kind: int) -> int:
        match kind:
                BeltRun.Kind.WAD:
                        return PICK_WAD
                BeltRun.Kind.TUFT:
                        return PICK_LOOSE
                BeltRun.Kind.BALE:
                        return PICK_BALE
                BeltRun.Kind.FOILED_BALE:
                        return PICK_FOILED
                BeltRun.Kind.BRICK:
                        return PICK_BRICK
                BeltRun.Kind.PULP:
                        return PICK_PULP
                BeltRun.Kind.DISC:
                        return PICK_DISC
                BeltRun.Kind.ROLL:
                        return PICK_ROLL
        return 0


static func _body_bit(item: Carryable) -> int:
        if item is HayTuft:
                return PICK_LOOSE
        return _kind_of(item)


func _grab_off_belt() -> bool:
        var now:= _clock
        if _take_wait_until == 0.0:
                _take_wait_until = now + TAKE_WAIT
        var run:= _pickup_run
        var ok:= run != null and is_instance_valid(run) and _socket != null
        var item: Carryable = _belt_load_under_claw(run) if ok else null
        if item == null:


                if not ok or now >= _take_wait_until or _pickup_stuck_only:
                        _pickup_run = null
                        _take_wait_until = 0.0
                        _start_pose(Phase.RETURN_HOME, _home_world_target(), 0.65)
                return false
        _pickup_run = null
        _take_wait_until = 0.0
        _hold_prop(item)
        return true


func _belt_load_under_claw(run: BeltPath) -> Carryable:
        var s:= run.s_at(_socket.global_position)
        var belt:= run.run
        var rows:= belt.rows_in(s - TAKE_GRAB, s + TAKE_GRAB)
        var best_row:= -1
        var best_d:= INF
        for i in range(rows.x, rows.y):
                if not accepts(_record_bit(belt.kind_of(i))):
                        continue
                if _pickup_stuck_only and belt.speed_of(i) > 0.01:
                        continue
                var d:= absf(belt.s_of(i) - s)
                if d < best_d:
                        best_d = d
                        best_row = i
        var best_body: Carryable = null
        var riders: Array [RigidBody3D] = []
        if not (_pickup_stuck_only and run.is_flowing()):
                riders = run.riders()
        for body in riders:
                var item:= body as Carryable
                if item == null or item.is_held() or _claimed_by_other(item) or not accepts(_body_bit(item)):
                        continue
                var d:= absf(run.s_at(item.global_position) - s)
                if d <= TAKE_GRAB and d < best_d:
                        best_d = d
                        best_body = item
        if best_body != null:
                return best_body
        if best_row >= 0:
                return run.materialize_record(best_row)
        return null


func _sync_link_marks(on: bool) -> void:
        if not on or _links.is_empty() or not links_unlocked():
                if is_instance_valid(_marks):
                        _marks.visible = false
                return
        if not is_instance_valid(_marks):
                _marks = Node3D.new()
                _marks.name = "LinkMarks"
                _marks.top_level = true
                add_child(_marks)
                _marks.global_transform = Transform3D.IDENTITY
                _marks_key = ""
        _marks.visible = true
        var key:= ""
        for link: Dictionary in _links:
                var run:= _link_run(link)
                key += "%d %s %d;" % [int(link ["role"]), str(link ["at"]),
                        run.get_instance_id() if run != null else 0]
        if key == _marks_key:
                return
        _marks_key = key
        for child in _marks.get_children():
                child.queue_free()
        for link: Dictionary in _links:
                var run:= _link_run(link)
                if run != null and run.path_length() > 0.0:
                        _marks.add_child(_link_mark(run, link ["at"], int(link ["role"]),
                                link_letter(link)))


func link_letter(link: Dictionary) -> String:
        var n:= 0
        for role: int in [LINK_TAKE, LINK_PUT]:
                for other: Dictionary in _links:
                        if int(other ["role"]) != role:
                                continue
                        if is_same(other, link):
                                return String.chr(65 + n)
                        n += 1
        return ""


func _link_mark(run: BeltPath, at: Vector3, role: int, letter: String) -> Node3D:
        var node:= Node3D.new()
        var colour:= COL_TAKE if role == LINK_TAKE else COL_PUT
        var st:= SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)

        var link_s:= run.s_at(at)
        for k: int in [-1, 0, 1]:
                var s:= clampf(link_s + 0.3 * float(k), 0.0, run.path_length())
                var basis:= run._basis_at(s)
                var p:= run._point_at(s) + basis.y * 0.03
                _chevron(st, p + basis.z * 0.12, basis.z * 0.2, basis.x * 0.18, basis.z * 0.09)


        var foot:= global_position + Vector3.UP * (RING_LIFT + 0.01)
        var flat:= Vector3(at.x, foot.y, at.z)
        var dir:= flat - foot
        if dir.length() > BASE_RADIUS * visual_scale() + Cfg.BELT_WIDTH * 0.5 + 0.4:
                dir = dir.normalized()
                var from:= foot + dir * (BASE_RADIUS * visual_scale() + 0.12)
                var to:= flat - dir * (Cfg.BELT_WIDTH * 0.5 + 0.1)
                if role == LINK_TAKE:
                        var swap:= from
                        from = to
                        to = swap
                var along:= (to - from).normalized()
                var side:= along.cross(Vector3.UP).normalized()
                var head:= to - along * 0.32
                _ribbon(st, from, head, Vector3.UP, 0.07)
                st.add_vertex(to)
                st.add_vertex(head + side * 0.18)
                st.add_vertex(head - side * 0.18)
        var mesh:= MeshInstance3D.new()
        mesh.mesh = st.commit()
        mesh.material_override = _mark_mat(role, colour)
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.add_child(mesh)
        var tag:= Label3D.new()
        tag.text = (tr("TAKE") if role == LINK_TAKE else tr("PUT")) + " " + letter
        tag.font = UiFont.bold()
        tag.font_size = 44
        tag.pixel_size = 0.004
        tag.outline_size = 10
        tag.modulate = colour
        tag.outline_modulate = Color(0.03, 0.04, 0.06, 0.9)
        tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        tag.no_depth_test = true
        tag.position = run._point_at(link_s) + Vector3.UP * 0.75
        node.add_child(tag)
        return node


static func _ribbon(st: SurfaceTool, a: Vector3, b: Vector3, up: Vector3,
                width: float) -> void:
        var across:= (b - a).cross(up).normalized() * width * 0.5
        st.add_vertex(a - across)
        st.add_vertex(b - across)
        st.add_vertex(b + across)
        st.add_vertex(a - across)
        st.add_vertex(b + across)
        st.add_vertex(a + across)


static func _chevron(st: SurfaceTool, tip: Vector3, back: Vector3, half: Vector3,
                thick: Vector3) -> void:
        var left:= tip - back + half
        var right:= tip - back - half
        for arm: Vector3 in [left, right]:
                st.add_vertex(tip)
                st.add_vertex(arm)
                st.add_vertex(arm - thick)
                st.add_vertex(tip)
                st.add_vertex(arm - thick)
                st.add_vertex(tip - thick)


static func _mark_mat(role: int, colour: Color) -> StandardMaterial3D:
        if not _mark_mats.has(role):
                var m:= HayDrone._new_ring_mat(Color(colour, 0.92))
                m.render_priority = 1
                _mark_mats [role] = m
        return _mark_mats [role]


const ORDER_LOOSE:= 0

const ORDER_BIG:= 1

const ORDER_CLOSEST:= 2
const ORDER_IDS:= ["loose", "big", "closest"]


var pick_order:= ORDER_LOOSE


func pick_order_now() -> int:
        if not Tech.pick_order_unlocked():
                return ORDER_LOOSE
        return clampi(pick_order, ORDER_LOOSE, ORDER_CLOSEST)


func set_pick_order(order: int) -> void:
        pick_order = clampi(order, ORDER_LOOSE, ORDER_CLOSEST)
        _stall = ""
        _clear = false
        _scan_left = minf(_scan_left, 0.15)


static func order_id(order: int) -> String:
        return ORDER_IDS [clampi(order, 0, ORDER_IDS.size() - 1)]


static func order_from_id(id: String) -> int:
        var i:= ORDER_IDS.find(id)
        return i if i >= 0 else ORDER_LOOSE
