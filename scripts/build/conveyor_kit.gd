class_name ConveyorKit
extends RefCounted


const SOURCE:= "res://assets/blender/compiled/conveyorbelt.scn"


const SOURCE_U:= "res://assets/blender/compiled/conveyor_u.scn"
const SHADER:= "res://assets/conveyor_surface.gdshader"
# MOBILE FIX (the 71-74% stand crash, v2.2.0): touch-first devices -- and any
# run recovering from a load-time crash -- build every conveyor material from
# a minimal twin of the shader (same uniforms, fragment without the fwidth
# detail fade, the high-frequency tread pattern and the hand-rolled cleat
# normals). The belt's first draw is the first compile of this pipeline in the
# whole load, and on the user's Mali-G615 that compile was fatal even after
# the v2.1.0 staging. See assets/conveyor_surface_mobile.gdshader.
const SHADER_MOBILE:= "res://assets/conveyor_surface_mobile.gdshader"
const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"


const CLEAT_PITCH:= 0.25


const ARROW_HALF_WIDTH:= 0.3
const ARROW_DEPTH:= 0.32
const ARROW_THICK:= 0.15

static var _section: ArrayMesh
static var _section_held: ArrayMesh

static var _held_of:= { }
static var _rail_r: ArrayMesh
static var _rail_l: ArrayMesh
static var _leg: ArrayMesh
static var _foot: ArrayMesh
static var _splitter: ArrayMesh
static var _splitter_gate: ArrayMesh
static var _splitter_readout: ArrayMesh
static var _joiner: ArrayMesh
static var _u_splitter: ArrayMesh
static var _u_joiner: ArrayMesh
static var _nose_head: ArrayMesh
static var _nose_tail: ArrayMesh
static var _belt: ShaderMaterial
static var _belt_held: ShaderMaterial
static var _belt_reversed: ShaderMaterial
static var _frame: ShaderMaterial
static var _roller: ShaderMaterial
static var _drum: ShaderMaterial
static var _drum_reversed: ShaderMaterial
static var _belt_fast: ShaderMaterial
static var _belt_fast_reversed: ShaderMaterial
static var _drum_fast: ShaderMaterial
static var _drum_fast_reversed: ShaderMaterial
static var _fast_of:= { }
static var _screen: StandardMaterial3D
static var _frame_std: StandardMaterial3D
static var _ghost_ok: ShaderMaterial
static var _ghost_bad: ShaderMaterial
static var _ghost_shader: Shader
static var _arrow: ArrayMesh
static var _flow: StandardMaterial3D


static func segment_mesh() -> ArrayMesh:
        _load()
        return _section


static func rail_mesh(side: int) -> ArrayMesh:
        _load()
        return _rail_r if side > 0 else _rail_l


static func held_segment_mesh() -> ArrayMesh:
        _load()
        if _section_held == null and _section != null:
                _section_held = ArrayMesh.new()
                var running:= belt_material()
                for i in _section.get_surface_count():
                        _section_held.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
                                _section.surface_get_arrays(i))
                        var m:= _section.surface_get_material(i)
                        _section_held.surface_set_material(i,
                                belt_material_held() if m == running else m)
        return _section_held


static func held_mesh(source: ArrayMesh) -> ArrayMesh:
        if source == null:
                return null
        var key:= source.get_instance_id()
        if _held_of.has(key):
                return _held_of [key]
        var out:= ArrayMesh.new()
        var rubber:= [belt_material(), belt_material_reversed(),
                belt_material_fast(), belt_material_fast_reversed()]
        var turning:= [drum_material(), drum_material_reversed(),
                drum_material_fast(), drum_material_fast_reversed()]
        for i in source.get_surface_count():
                out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
                        source.surface_get_arrays(i))
                var m:= source.surface_get_material(i)
                if m in rubber:
                        m = belt_material_held()
                elif m in turning:
                        m = roller_material()
                out.surface_set_material(i, m)
        _held_of [key] = out
        return out


static func leg_mesh() -> ArrayMesh:
        _load()
        return _leg


static func foot_mesh() -> ArrayMesh:
        _load()
        return _foot


static func splitter_mesh() -> ArrayMesh:
        _load()
        return _splitter


static func splitter_gate_mesh() -> ArrayMesh:
        _load()
        return _splitter_gate


static func splitter_readout_mesh() -> ArrayMesh:
        _load()
        return _splitter_readout


static func joiner_mesh() -> ArrayMesh:
        _load()
        if _joiner == null and _splitter != null:
                _joiner = _reversed_copy(_splitter)
        return _joiner


static func u_splitter_mesh() -> ArrayMesh:
        _load()
        if _u_splitter == null:
                var packed: PackedScene = load(SOURCE_U)
                if packed == null:
                        push_error("ConveyorKit: cannot load %s" % SOURCE_U)
                        return null
                var root:= packed.instantiate()


                _u_splitter = _mesh_of(root, "ConveyorUSplitter", SOURCE_U)
                root.free()
                _dress(_u_splitter, 3)
        return _u_splitter


static func u_joiner_mesh() -> ArrayMesh:
        if _u_joiner == null and u_splitter_mesh() != null:
                _u_joiner = _reversed_copy(_u_splitter)
        return _u_joiner


static func _reversed_copy(source: ArrayMesh) -> ArrayMesh:
        var out:= ArrayMesh.new()
        var running:= belt_material()
        for i in source.get_surface_count():
                out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
                        source.surface_get_arrays(i))
                var m:= source.surface_get_material(i)
                out.surface_set_material(i, belt_material_reversed() if m == running else m)
        return out


static func nose_mesh(head: bool) -> ArrayMesh:
        _load()
        return _nose_head if head else _nose_tail


static func _load() -> void:
        if _section != null:
                return
        var packed: PackedScene = load(SOURCE)
        if packed == null:
                push_error("ConveyorKit: cannot load %s" % SOURCE)
                return
        var root:= packed.instantiate()
        _section = _mesh_of(root, "ConveyorSection")
        _rail_r = _mesh_of(root, "ConveyorRailR")
        _rail_l = _mesh_of(root, "ConveyorRailL")
        _leg = _mesh_of(root, "ConveyorLeg")
        _foot = _mesh_of(root, "ConveyorFoot")
        _splitter = _mesh_of(root, "ConveyorSplitter")
        _splitter_gate = _mesh_of(root, "ConveyorSplitterGate")
        _splitter_readout = _mesh_of(root, "ConveyorSplitterReadout")
        _nose_head = _mesh_of(root, "ConveyorNoseHead")
        _nose_tail = _mesh_of(root, "ConveyorNoseTail")
        root.free()


        _dress(_section, 3)
        _dress(_rail_r, 1)
        _dress(_rail_l, 1)
        _dress(_leg, 1)
        _dress(_foot, 1)


        _dress(_splitter, 3)
        _dress(_splitter_gate, 2)


        _dress(_splitter_readout, 3)


        _dress(_nose_head, 3)
        _dress(_nose_tail, 3)


        if _splitter_gate != null:
                var running:= belt_material()
                for i in _splitter_gate.get_surface_count():
                        if _splitter_gate.surface_get_material(i) == running:
                                _splitter_gate.surface_set_material(i, belt_material_held())


static func _mesh_of(root: Node, node_name: String, source: String = SOURCE) -> ArrayMesh:
        var node:= root.find_child(node_name, true, false)
        var mi:= node as MeshInstance3D
        if mi == null:
                push_error("ConveyorKit: %s has no MeshInstance3D '%s'" % [source, node_name])
                return null


        return mi.mesh as ArrayMesh


static func _dress(mesh: ArrayMesh, expect: int) -> void:
        if mesh == null:
                return
        var n:= mesh.get_surface_count()
        if n != expect:
                push_error("ConveyorKit: expected %d surfaces, got %d: the materials in "
                        % [expect, n] + "assets/blender/conveyorbelt.blend no longer split it")
                return
        for i in n:
                var old:= mesh.surface_get_material(i)
                mesh.surface_set_material(i,
                        _material_named(old.resource_name if old != null else ""))


static func _material_named(id: String) -> Material:
        if id.contains("BeltRubber"):
                return belt_material()


        if id.contains("Drum"):
                return drum_material()
        if id.contains("Roller"):
                return roller_material()
        if id.contains("Screen"):
                return screen_material()
        if not id.contains("Frame"):
                push_warning("ConveyorKit: unrecognised surface '%s', painting as frame" % id)
        return frame_material()


static func belt_material() -> ShaderMaterial:
        if _belt == null:
                _belt = _pbr("rubberized_track", 2.0, Cfg.COL_BELT_RUBBER, 0.1,
                        0.8, 0.98, 0.0, 1.3)


                _belt.set_shader_parameter("speed", Tech.belt_speed())
                _belt.set_shader_parameter("cleat", 1.0)
                _belt.set_shader_parameter("cleat_pitch", CLEAT_PITCH)
        return _belt


static func own_belt_material(speed: float) -> ShaderMaterial:
        var m:= _pbr("rubberized_track", 2.0, Cfg.COL_BELT_RUBBER, 0.1,
                0.8, 0.98, 0.0, 1.3)
        m.set_shader_parameter("speed", speed)
        m.set_shader_parameter("cleat", 1.0)
        m.set_shader_parameter("cleat_pitch", CLEAT_PITCH)
        return m


static func set_belt_speed(v: float) -> void:
        if _belt != null:
                _belt.set_shader_parameter("speed", v)


        if _belt_reversed != null:
                _belt_reversed.set_shader_parameter("speed", - v)


        if _drum != null:
                _drum.set_shader_parameter("speed", v)

        if _drum_reversed != null:
                _drum_reversed.set_shader_parameter("speed", - v)

        var fast:= v * _fast_factor()
        if _belt_fast != null:
                _belt_fast.set_shader_parameter("speed", fast)
        if _belt_fast_reversed != null:
                _belt_fast_reversed.set_shader_parameter("speed", - fast)
        if _drum_fast != null:
                _drum_fast.set_shader_parameter("speed", fast)
        if _drum_fast_reversed != null:
                _drum_fast_reversed.set_shader_parameter("speed", - fast)


static func belt_material_fast() -> ShaderMaterial:
        if _belt_fast == null:
                _belt_fast = belt_material().duplicate() as ShaderMaterial
                _belt_fast.set_shader_parameter("speed", Tech.belt_speed() * _fast_factor())
        return _belt_fast


static func belt_material_fast_reversed() -> ShaderMaterial:
        if _belt_fast_reversed == null:
                _belt_fast_reversed = belt_material_reversed().duplicate() as ShaderMaterial
                _belt_fast_reversed.set_shader_parameter("speed", - Tech.belt_speed() * _fast_factor())
        return _belt_fast_reversed


static func drum_material_fast() -> ShaderMaterial:
        if _drum_fast == null:
                _drum_fast = drum_material().duplicate() as ShaderMaterial
                _drum_fast.set_shader_parameter("speed", Tech.belt_speed() * _fast_factor())
        return _drum_fast


static func drum_material_fast_reversed() -> ShaderMaterial:
        if _drum_fast_reversed == null:
                _drum_fast_reversed = drum_material_reversed().duplicate() as ShaderMaterial
                _drum_fast_reversed.set_shader_parameter("speed", - Tech.belt_speed() * _fast_factor())
        return _drum_fast_reversed


static func _fast_factor() -> float:
        return ConveyorSplitter.route_boost


static func fast_mesh(source: ArrayMesh) -> ArrayMesh:
        if source == null:
                return null
        var key:= source.get_instance_id()
        if _fast_of.has(key):
                return _fast_of [key]
        var swap:= {
                belt_material(): belt_material_fast(),
                belt_material_reversed(): belt_material_fast_reversed(),
                drum_material(): drum_material_fast(),
                drum_material_reversed(): drum_material_fast_reversed(),
        }
        var out:= ArrayMesh.new()
        for i in source.get_surface_count():
                out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
                        source.surface_get_arrays(i))
                var m:= source.surface_get_material(i)
                out.surface_set_material(i, swap.get(m, m))
        _fast_of [key] = out
        return out


static func belt_material_held() -> ShaderMaterial:
        if _belt_held == null:
                _belt_held = _pbr("rubberized_track", 2.0, Cfg.COL_BELT_RUBBER, 0.1,
                        0.8, 0.98, 0.0, 1.3)
                _belt_held.set_shader_parameter("speed", 0.0)
                _belt_held.set_shader_parameter("cleat", 1.0)
                _belt_held.set_shader_parameter("cleat_pitch", CLEAT_PITCH)
        return _belt_held


static func belt_material_reversed() -> ShaderMaterial:
        if _belt_reversed == null:
                _belt_reversed = _pbr("rubberized_track", 2.0, Cfg.COL_BELT_RUBBER, 0.1,
                        0.8, 0.98, 0.0, 1.3)
                _belt_reversed.set_shader_parameter("speed", - Tech.belt_speed())
                _belt_reversed.set_shader_parameter("cleat", 1.0)
                _belt_reversed.set_shader_parameter("cleat_pitch", CLEAT_PITCH)
        return _belt_reversed


static func frame_material() -> ShaderMaterial:
        if _frame == null:
                _frame = _pbr("blue_metal_plate", 1.0, Cfg.COL_BELT_STEEL, 0.3,
                        0.62, 0.92, 0.0, 1.0)
        return _frame


## The frame's look as a plain StandardMaterial3D, for MultiMesh draws that
## must not involve a custom shader at all. Used by the selling stand's legs
## and feet on staged builds: everywhere else on the phone a MultiMesh has
## always carried a StandardMaterial3D (yard ground, landing zone), so a
## MultiMesh + custom-shader pipeline is the one draw combination the
## 71-74% crash window never proved safe. Roughness remap collapses to the
## midpoint of the range, which is invisible on painted steel at gameplay
## distance.
static func frame_material_standard() -> StandardMaterial3D:
        if _frame_std == null:
                _frame_std = _standard("blue_metal_plate", 1.0,
                        Cfg.COL_BELT_STEEL, 0.3, 0.77, 0.0, 1.0)
        return _frame_std


static func _standard(asset: String, per_metre: float, tint: Color,
                saturation: float, roughness: float, metallic: float,
                normal_depth: float) -> StandardMaterial3D:
        var m:= StandardMaterial3D.new()
        m.uv1_scale = Vector3(per_metre, per_metre, 1.0)
        # The full shader pulls the scan toward grey by `saturation` first; a
        # StandardMaterial3D has no desaturate term, and the legs/feet only
        # ever run with the near-black steel tint, which dominates the look.
        m.albedo_color = Color(tint.r, tint.g, tint.b, 1.0)
        m.roughness = roughness
        m.metallic = metallic
        m.normal_enabled = true
        m.normal_scale = normal_depth
        m.ao_enabled = true
        m.ao_light_affect = 0.6
        for param in [["albedo_texture", "diff"], ["normal_texture", "nor_gl"],
                        ["roughness_texture", "rough"], ["ao_texture", "ao"]]:
                var tex: Texture2D = load(TEX % [asset, asset, param [1]])
                if tex == null:
                        push_warning("ConveyorKit: missing %s map for '%s'" % [param [1], asset])
                        continue
                m.set(param [0], tex)
        return m


static func screen_material() -> StandardMaterial3D:
        if _screen == null:
                _screen = StandardMaterial3D.new()
                _screen.albedo_color = Cfg.COL_SPLITTER_SCREEN
                _screen.roughness = 0.16
                _screen.metallic = 0.0
        return _screen


static func roller_material() -> ShaderMaterial:
        if _roller == null:
                _roller = _pbr("rusty_metal_03", 3.0, Cfg.COL_BELT_ROLLER, 0.28,
                        0.3, 0.62, 0.35, 1.0)
        return _roller


static func drum_material() -> ShaderMaterial:
        if _drum == null:
                _drum = _pbr("rusty_metal_03", 3.0, Cfg.COL_BELT_ROLLER, 0.28,
                        0.3, 0.62, 0.35, 1.0)
                _drum.set_shader_parameter("speed", Tech.belt_speed())
        return _drum


static func drum_material_reversed() -> ShaderMaterial:
        if _drum_reversed == null:
                _drum_reversed = _pbr("rusty_metal_03", 3.0, Cfg.COL_BELT_ROLLER, 0.28,
                        0.3, 0.62, 0.35, 1.0)
                _drum_reversed.set_shader_parameter("speed", - Tech.belt_speed())
        return _drum_reversed


static func _pbr(asset: String, per_metre: float, tint: Color, saturation: float,
                rough_min: float, rough_max: float, metallic: float,
                normal_depth: float) -> ShaderMaterial:
        var m:= ShaderMaterial.new()
        # The belt-crash fix: phones and post-crash recovery runs compile the
        # minimal twin pipeline. Desktop keeps the full-shader look.
        m.shader = load(SHADER_MOBILE if (Cfg.is_mobile or CrashReport.safe_load)
                else SHADER)
        m.set_shader_parameter("tex_per_metre", per_metre)


        m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
        m.set_shader_parameter("saturation", saturation)
        m.set_shader_parameter("rough_min", rough_min)
        m.set_shader_parameter("rough_max", rough_max)
        m.set_shader_parameter("metallic", metallic)
        m.set_shader_parameter("normal_depth", normal_depth)
        for param in [["albedo_tex", "diff"], ["normal_tex", "nor_gl"],
                        ["rough_tex", "rough"], ["ao_tex", "ao"]]:
                var tex: Texture2D = load(TEX % [asset, asset, param [1]])
                if tex == null:
                        push_warning("ConveyorKit: missing %s map for '%s'" % [param [1], asset])
                        continue
                m.set_shader_parameter(param [0], tex)
        return m


static func flow_arrow_mesh() -> ArrayMesh:
        if _arrow != null:
                return _arrow
        var w:= ARROW_HALF_WIDTH
        var d:= ARROW_DEPTH
        var t:= ARROW_THICK


        var verts:= PackedVector3Array([
                Vector3(- w, 0.0, 0.0), Vector3(0.0, 0.0, d), Vector3(w, 0.0, 0.0),
                Vector3(- w, 0.0, - t), Vector3(0.0, 0.0, d - t), Vector3(w, 0.0, - t),
        ])
        var normals:= PackedVector3Array()
        for _i in verts.size():
                normals.append(Vector3.UP)
        var arrays:= []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays [Mesh.ARRAY_VERTEX] = verts
        arrays [Mesh.ARRAY_NORMAL] = normals
        arrays [Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 4, 0, 4, 3, 1, 2, 5, 1, 5, 4])
        _arrow = ArrayMesh.new()
        _arrow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        return _arrow


static func flow_material() -> StandardMaterial3D:
        if _flow == null:
                _flow = StandardMaterial3D.new()
                _flow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                _flow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                _flow.albedo_color = Color(2.3, 2.4, 2.3, 1.0)


                _flow.vertex_color_use_as_albedo = true


                _flow.cull_mode = BaseMaterial3D.CULL_DISABLED
                _flow.render_priority = 1
        return _flow


static func ghost_material(ok: bool) -> ShaderMaterial:
        if _ghost_ok == null:
                _ghost_ok = _make_ghost(Cfg.COL_GHOST_OK)
                _ghost_bad = _make_ghost(Cfg.COL_GHOST_BAD)
        return _ghost_ok if ok else _ghost_bad


static func _make_ghost(tint: Color) -> ShaderMaterial:
        if _ghost_shader == null:
                _ghost_shader = Shader.new()
                _ghost_shader.code = "\nshader_type spatial;\nrender_mode unshaded, cull_disabled, world_vertex_coords;\n\nuniform vec4 tint : source_color = vec4(0.28, 1.0, 0.42, 1.0);\nuniform float alpha = 0.34;\nuniform float pull = 0.012;\n\nvoid vertex() {\n\tvec3 to_eye = CAMERA_POSITION_WORLD - VERTEX;\n\tfloat away = length(to_eye);\n\tif (away > 0.001) {\n\t\tVERTEX += to_eye / away * min(pull, away * 0.5);\n\t}\n}\n\nvoid fragment() {\n\tALBEDO = tint.rgb;\n\tEMISSION = tint.rgb * 0.9;\n\tALPHA = alpha;\n}\n"


        var m:= ShaderMaterial.new()
        m.shader = _ghost_shader
        m.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, 1.0))
        m.set_shader_parameter("alpha", 0.34)
        m.set_shader_parameter("pull", 0.012)
        return m
