class_name HayCompressor
extends Node3D


const MODEL:= "res://assets/models/compiled/hay_compressor.scn"


const SPEC:= "res://assets/models/hay_compressor_materials.json"


const SHADER:= "res://assets/stand_surface.gdshader"


const GLASS_SHADER:= "res://assets/glass_pane.gdshader"


const SLURRY_SHADER:= "res://assets/pulp_slurry.gdshader"


const LAMP_SHADER:= "res://assets/machine_lamp.gdshader"

const LAMP_PARAM:= &"lamp_energy"
const LAMP_COLOUR_PARAM:= &"lamp_colour"
const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"
const TEX_MAPS:= {
        "albedo": "diff", "normal": "nor_gl", "rough": "rough", "ao": "ao",
}

const N_BELT_IN:= "Marker_BeltIn"
const N_BELT_OUT:= "Marker_BeltOut"
const N_BALE_OUT:= "Marker_BaleOut"
const N_PANEL:= "Marker_Panel"


const N_WIRE_PORT:= "Marker_WirePort"


const WIRE_PORT_FALLBACK:= Vector3(0.64, 1.614, 0.49)

const CLIP:= "Cycle"
const CYCLE_FRAMES:= 96.0
const CLIP_FPS:= 24.0


const F_RELEASE:= 86.0


const MAT_GO:= "M_HC_LampGo"


const GO_OFF:= 0.0
const GO_IDLE:= 0.2
const GO_RUNNING:= 0.6


const INTAKE_LENGTH:= Cfg.COMPRESSOR_LENGTH * 0.5
const INTAKE_HEIGHT:= 0.5

const SUPPORT_HALF_WIDTH:= Cfg.BELT_SUPPORT_HALF_WIDTH


const ARROW_PITCH:= 0.8
const ARROW_LIFT:= 0.06


const ARROW_FADE:= 0.45
const ARROW_CAPACITY:= 12


const ARROW_SPEED:= 0.9


const PRESS_LOOP_DB:= -13.0
const PRESS_LOOP_SILENT:= -80.0
const PRESS_LOOP_RAMP:= 140.0
const PRESS_LOOP_HEIGHT:= 1.3


signal baled(bale: HayBale)


signal baled_record(seq: int)

var live: LiveStrandManager


var props: PropManager
var placement_preview:= false


var stored:= 0


var pending_needles:= PackedInt32Array()


func held_needles() -> PackedInt32Array:
        return pending_needles


var starved_for:= 0.0


var _batch:= Cfg.COMPRESSOR_BALE_STRANDS
var _cycle:= Cfg.COMPRESSOR_PRESS_SECONDS

var _model: Node3D
var _anim: AnimationPlayer
var _belt: BeltPath
var _intake: Area3D
var _supports: Node3D
var _ghost_belt: BeltGhost
var _ghost_flow: MultiMeshInstance3D
var _flow_phase:= 0.0

var _go_meshes: Array [MeshInstance3D] = []

var _press:= -1.0

var _released:= false


var _room_probe: BoxShape3D
var _room_query: PhysicsShapeQueryParameters3D

var _press_voice:= -1
var _press_gain:= PRESS_LOOP_SILENT
var _press_target:= PRESS_LOOP_SILENT


var _ports: Array [Node3D] = []


func setup(at: Vector3, yaw: float) -> void:
        position = at
        rotation.y = yaw


func _ready() -> void:
        _build_model()
        _skin()
        _build_animation()
        if placement_preview:
                set_physics_process(false)
                _build_ghost_belt()
                set_preview_valid(true)
                return
        set_process(false)


        FactoryClock.join(self)
        _build_belt()
        _build_intake_area()
        add_to_group("hay_compressors")
        _apply_lamp()


        call_deferred("refresh_supports")


func _build_model() -> void:
        var packed: PackedScene = load(MODEL)
        if packed == null:
                push_error("HayCompressor: cannot load %s" % MODEL)
                return
        _model = packed.instantiate() as Node3D
        _model.name = "Model"
        add_child(_model)


        for n in _model.find_children("*", "StaticBody3D", true, false):
                var body:= n as StaticBody3D
                body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
                body.collision_mask = 0


        var shipped:= _find("Compressor_Bale") as Node3D
        if shipped != null and placement_preview:
                shipped.visible = false

        if placement_preview:
                for mesh in _meshes():
                        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skin() -> void:
        if _model == null:
                return
        var spec:= spec_table()
        if spec.is_empty():
                push_warning("HayCompressor: no material table at %s, the model will render untextured" % SPEC)
                return
        var shader: Shader = load(SHADER)
        var built: Dictionary = { }
        var missed: Dictionary = { }
        _go_meshes.clear()
        for mesh in _meshes():
                if mesh.mesh == null:
                        continue
                for i in mesh.mesh.get_surface_count():
                        var src:= mesh.get_active_material(i)
                        if src == null:
                                continue
                        var key:= src.resource_name
                        if src.get_meta("immutable_palette", false):
                                preload("res://assets/models/machine_palette.gd").validate_import(src, spec)
                                continue


                        if key.is_empty():
                                continue
                        if not built.has(key):
                                built [key] = shared_material(MODEL, key,
                                        func() -> Material: return _make_surface(key, spec, shader))
                        if built [key] == null:
                                missed [key] = true
                                continue
                        mesh.set_surface_override_material(i, built [key])
                        if key == MAT_GO and not _go_meshes.has(mesh):
                                _go_meshes.append(mesh)
        if not missed.is_empty():
                push_warning("HayCompressor: no table entry for %s" % ", ".join(missed.keys()))


static func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
        var made:= make_material(key, spec, shader)
        return lamp_material(made) if key == MAT_GO else made


static var _shared_mats: Dictionary = { }

static var _per_machine_mats:= -1


static func shared_material(model: String, key: String, build: Callable) -> Material:
        if _per_machine_mats < 0:
                _per_machine_mats = 1 if "--permachinemats" in OS.get_cmdline_user_args() else 0
        if _per_machine_mats == 1:
                return build.call()
        var table: Dictionary = _shared_mats.get_or_add(model, { })
        if not table.has(key):
                table [key] = build.call()
        return table [key]


static func materials_shared() -> bool:
        if _per_machine_mats < 0:
                _per_machine_mats = 1 if "--permachinemats" in OS.get_cmdline_user_args() else 0
        return _per_machine_mats == 0


static func lamp_material(made: Material) -> Material:
        var flat:= made as StandardMaterial3D
        if flat == null:
                return made
        var defines:= PackedStringArray()
        if flat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
                defines.append("LAMP_ALPHA")
        if flat.cull_mode == BaseMaterial3D.CULL_DISABLED:
                defines.append("LAMP_TWO_SIDED")
        var m:= ShaderMaterial.new()
        m.shader = shader_variant(LAMP_SHADER, defines)
        m.resource_name = flat.resource_name
        m.set_meta(&"lamp", true)
        m.set_shader_parameter("albedo", flat.albedo_color)
        m.set_shader_parameter("roughness", flat.roughness)
        m.set_shader_parameter("metallic", flat.metallic)
        m.set_shader_parameter("specular", flat.metallic_specular)
        m.set_shader_parameter("emission", flat.emission)
        m.set_shader_parameter("emission_energy",
                flat.emission_energy_multiplier if flat.emission_enabled else 0.0)
        return m


static func light_lamps(meshes: Array [MeshInstance3D], energy: float) -> void:
        for mesh in meshes:
                drive_instance(mesh, LAMP_PARAM, energy)


static func tint_lamps(meshes: Array [MeshInstance3D], colour: Color) -> void:
        for mesh in meshes:
                drive_instance(mesh, LAMP_COLOUR_PARAM, Color(colour.r, colour.g, colour.b, 1.0))


static func lamp_energy(meshes: Array [MeshInstance3D]) -> float:
        if meshes.is_empty():
                return -1.0
        return float(driven(meshes [0], LAMP_PARAM, -1.0))


const DRIVEN_META:= &"driven_instance_uniforms"


static func drive_instance(g: GeometryInstance3D, param: StringName, value: Variant) -> void:
        if g == null or not is_instance_valid(g):
                return
        var sent: Dictionary
        if g.has_meta(DRIVEN_META):
                sent = g.get_meta(DRIVEN_META)
        else:
                sent = { }
                g.set_meta(DRIVEN_META, sent)
        var now: Variant = sent.get(param)
        if now != null and typeof(now) == typeof(value) and now == value:
                return
        sent [param] = value
        # MOBILE FIX (Mali device loss at the selling stand): the per-instance
        # values used to ride on Godot's `instance shader uniforms`, whose pipeline
        # the mobile Vulkan drivers choked on -- the stand's puff was the first mesh
        # in the load to compile one, and the game died at 71-74% right there. The
        # shaders carry plain uniforms now, and the per-machine value rides on the
        # machine's own copy of the material instead: same numbers, same look, one
        # material per driven mesh.
        if g.material_override != null:
                if g.material_override is ShaderMaterial:
                        g.material_override = _driven_material(g, g.material_override, param, value)
                return
        var mi:= g as MeshInstance3D
        if mi == null or mi.mesh == null:
                return
        for i in mi.mesh.get_surface_count():
                var src:= mi.get_surface_override_material(i)
                if src == null:
                        src = mi.mesh.surface_get_material(i)
                if src == null or not (src is ShaderMaterial):
                        continue
                mi.set_surface_override_material(i, _driven_material(g, src, param, value))


static func _driven_material(g: GeometryInstance3D, src: Material,
                param: StringName, value: Variant) -> Material:
        var copies: Dictionary
        if g.has_meta(COPIES_META):
                copies = g.get_meta(COPIES_META)
        else:
                copies = { }
                g.set_meta(COPIES_META, copies)
        var key:= src.get_instance_id()
        if copies.has(key) and is_instance_valid(copies [key]):
                var m: ShaderMaterial = copies [key]
                m.set_shader_parameter(param, value)
                return m
        var made: ShaderMaterial = (src as ShaderMaterial).duplicate()
        made.set_shader_parameter(param, value)
        copies [key] = made
        return made


static func driven(g: GeometryInstance3D, param: StringName, fallback: Variant) -> Variant:
        if g == null or not is_instance_valid(g) or not g.has_meta(DRIVEN_META):
                return fallback
        return (g.get_meta(DRIVEN_META) as Dictionary).get(param, fallback)


static func flowing_shader() -> Shader:
        # The pour's flow used to need a FLOW_PER_INSTANCE variant because its
        # `flow_uv` was an instance uniform. The shader carries a plain uniform now,
        # so the base shader is all there is.
        return load(SHADER)


const COPIES_META:= &"driven_material_copies"


static var _variants: Dictionary = { }


static func shader_variant(path: String, defines: PackedStringArray) -> Shader:
        var base: Shader = load(path)
        if defines.is_empty():
                return base
        var key:= path + "#" + ",".join(defines)
        if _variants.has(key):
                return _variants [key]
        var code:= base.code
        var head:= code.find("\n")
        var lines:= ""
        for d in defines:
                lines += "#define %s\n" % d
        var made:= Shader.new()
        made.code = code.substr(0, head + 1) + lines + code.substr(head + 1)
        _variants [key] = made
        return made


static var _spec_cache: Dictionary = { }


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


static func make_material(key: String, spec: Dictionary, shader: Shader) -> Material:
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


                var coat: Array = d.get("coat", [])
                if coat.size() >= 2:
                        m.set_shader_parameter("coat", float(coat [0]))
                        m.set_shader_parameter("coat_rough", float(coat [1]))
                return m

        var flats: Dictionary = spec.get("flats", { })
        if flats.has(key):
                var f: Dictionary = flats [key]


                var fres: Array = f.get("fresnel", [])
                if fres.size() >= 2:
                        var gm:= ShaderMaterial.new()
                        gm.shader = load(GLASS_SHADER)
                        gm.resource_name = key
                        gm.set_shader_parameter("tint", _col(f ["color"]))
                        gm.set_shader_parameter("base_alpha", float(f.get("alpha", 0.16)))
                        gm.set_shader_parameter("edge_power", float(fres [0]))
                        gm.set_shader_parameter("edge_alpha", float(fres [1]))
                        gm.set_shader_parameter("roughness_amount", float(f.get("rough", 0.03)))
                        return gm


                var wav: Array = f.get("waves", [])
                if wav.size() >= 4:
                        var wm:= ShaderMaterial.new()
                        wm.shader = load(SLURRY_SHADER)
                        wm.resource_name = key
                        wm.set_shader_parameter("tint", _col(f ["color"]))
                        wm.set_shader_parameter("base_alpha", float(f.get("alpha", 1.0)))
                        wm.set_shader_parameter("roughness_amount", float(f.get("rough", 0.44)))
                        wm.set_shader_parameter("amplitude", float(wav [0]))
                        wm.set_shader_parameter("wavelength", float(wav [1]))
                        wm.set_shader_parameter("wave_speed", float(wav [2]))
                        wm.set_shader_parameter("fade_depth", float(wav [3]))
                        return wm

                var sm:= StandardMaterial3D.new()
                sm.resource_name = key
                var colour:= _col(f ["color"])
                var alpha:= float(f.get("alpha", 1.0))
                sm.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
                sm.roughness = float(f.get("rough", 0.6))
                sm.metallic = float(f.get("metal", 0.0))
                sm.metallic_specular = 0.4
                var emit:= float(f.get("emit", 0.0))
                if emit > 0.0:
                        sm.emission_enabled = true
                        sm.emission = colour
                        sm.emission_energy_multiplier = emit
                if alpha < 1.0:


                        sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                return sm
        return null


static func _col(a: Variant) -> Color:
        var arr: Array = a
        if arr.size() < 3:
                return Color.WHITE
        return Color(float(arr [0]), float(arr [1]), float(arr [2]))


func _build_animation() -> void:
        if _model == null:
                return
        var src:= _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
        if src == null:
                push_warning("HayCompressor: %s has no AnimationPlayer; the press will not move" % MODEL)
                return
        _anim = src
        var clip:= _find_clip()
        if clip == null:
                push_warning("HayCompressor: %s has no '%s' clip" % [MODEL, CLIP])
                return
        clip.loop_mode = Animation.LOOP_NONE


        _anim.play(_clip_name())
        _anim.seek(0.0, true)
        _anim.pause()


func _find_clip() -> Animation:
        if _anim == null:
                return null
        var name:= _clip_name()
        return _anim.get_animation(name) if name != "" else null


func _clip_name() -> String:
        if _anim == null:
                return ""
        for candidate: String in [CLIP, "global/" + CLIP, "" + CLIP]:
                if _anim.has_animation(candidate):
                        return candidate
        var list:= _anim.get_animation_list()
        if list.size() > 0:
                return list [0]
        return ""


func port_in() -> Vector3:
        return to_global(_marker_local(N_BELT_IN, Vector3(0, 0, - Cfg.COMPRESSOR_LENGTH * 0.5)))


func port_out() -> Vector3:
        return to_global(_marker_local(N_BELT_OUT, Vector3(0, 0, Cfg.COMPRESSOR_LENGTH * 0.5)))


func deck() -> BeltPath:
        return _belt


func forward() -> Vector3:
        var d:= port_out() - port_in()
        return d.normalized() if d.length_squared() > 1e-08 else - global_basis.z


func console_position() -> Vector3:
        return to_global(_marker_local(N_PANEL, Vector3(0.71, 0.92, 0)))


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
        var marker:= _find(node_name) as Node3D
        if marker == null:
                return fallback
        return to_local(marker.global_position)


func _build_belt() -> void:
        _belt = BeltPath.new()
        _belt.name = "ModuleBelt"
        add_child(_belt)


        _belt.build_path(belt_runs() [0], Cfg.BELT_JOINT_OVERLAP)


        _belt.set_hold_back(Cfg.COMPRESSOR_LENGTH - INTAKE_LENGTH * 0.5)


        _belt.records_props = true
        _belt.hold_records(_eats)


func _eats(kind: int, _strands: int) -> bool:
        return kind == BeltRun.Kind.WAD


func _outfeed() -> BeltPath:
        if _belt == null:
                return null
        var out:= _belt.downstream
        if out == null or not is_instance_valid(out) or not out.records_props:
                return null
        return out


func _build_intake_area() -> void:
        _intake = Area3D.new()
        _intake.name = "IntakeMouth"
        _intake.collision_layer = 0


        _intake.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
        _intake.monitorable = false
        var box:= BoxShape3D.new()
        box.size = Vector3(Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0,
                INTAKE_HEIGHT, INTAKE_LENGTH)
        var cs:= CollisionShape3D.new()
        cs.shape = box
        cs.position = Vector3(0, INTAKE_HEIGHT * 0.5, 0)
        _intake.add_child(cs)
        add_child(_intake)
        _intake.position = to_local(port_in() + forward() * (INTAKE_LENGTH * 0.5))


        _intake.position.y = 0.0


func _build_ghost_belt() -> void:
        _ghost_belt = BeltGhost.new()
        add_child(_ghost_belt)


        var fmm:= MultiMesh.new()
        fmm.transform_format = MultiMesh.TRANSFORM_3D
        fmm.use_colors = true
        fmm.mesh = ConveyorKit.flow_arrow_mesh()
        fmm.instance_count = ARROW_CAPACITY
        fmm.visible_instance_count = 0
        _ghost_flow = MultiMeshInstance3D.new()
        _ghost_flow.name = "GhostFlow"
        _ghost_flow.multimesh = fmm
        _ghost_flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


        _ghost_flow.material_override = ConveyorKit.flow_material()
        add_child(_ghost_flow)
        _shape_flow(Cfg.COMPRESSOR_LENGTH)


func belt_runs() -> Array [PackedVector3Array]:
        return [PackedVector3Array([port_in(), port_out()])]


func _process(delta: float) -> void:
        if not placement_preview or _ghost_flow == null or not is_visible_in_tree():
                return
        _flow_phase += delta * ARROW_SPEED
        _shape_flow(Cfg.COMPRESSOR_LENGTH)


        _ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, support_xforms())


func _shape_flow(length: float) -> void:
        var mm:= _ghost_flow.multimesh
        if length < 0.0001:
                mm.visible_instance_count = 0
                return


        var n:= clampi(maxi(1, int(round(length / ARROW_PITCH))), 1, ARROW_CAPACITY)
        var pitch:= length / n
        var phase:= fmod(_flow_phase, pitch)
        for i in n:
                var along:= fmod(i * pitch + phase, length)
                mm.set_instance_transform(i, Transform3D(Basis(),
                        Vector3(0.0, ARROW_LIFT, - length * 0.5 + along)))
                var fade:= (clampf(along / ARROW_FADE, 0.0, 1.0)
                        * clampf((length - along) / ARROW_FADE, 0.0, 1.0))
                mm.set_instance_color(i, Color(1.0, 1.0, 1.0, fade))
        mm.visible_instance_count = n


func _find(node_name: String) -> Node:
        if _model == null:
                return null
        return _model.find_child(node_name, true, false)


func _meshes() -> Array [MeshInstance3D]:
        var out: Array [MeshInstance3D] = []
        if _model == null:
                return out
        for n in _model.find_children("*", "MeshInstance3D", true, false):
                out.append(n as MeshInstance3D)
        return out


func refresh_supports() -> void:
        if not is_inside_tree() or placement_preview:
                return
        if _supports != null:
                remove_child(_supports)
                _supports.queue_free()
                _supports = null
        var both:= support_xforms()
        var legs: Array [Transform3D] = both [0]
        var feet: Array [Transform3D] = both [1]
        _supports = Node3D.new()
        _supports.name = "Supports"
        _supports.top_level = true
        add_child(_supports)
        _supports.add_child(Conveyor._support_mm("Legs", ConveyorKit.leg_mesh(), legs))
        _supports.add_child(Conveyor._support_mm("Feet", ConveyorKit.foot_mesh(), feet))


func support_xforms() -> Array:
        var space:= get_world_3d().direct_space_state
        var own:= _own_bodies()
        var yaw:= global_basis
        var legs: Array [Transform3D] = []
        var feet: Array [Transform3D] = []
        for port: Vector3 in [port_in(), port_out()]:
                var centre_top:= port - Vector3.UP * Cfg.BELT_SUPPORT_ATTACH_DEPTH
                for side: float in [-1.0, 1.0]:
                        var top: Vector3 = centre_top + yaw.x * (side * SUPPORT_HALF_WIDTH)
                        var q:= PhysicsRayQueryParameters3D.create(top,
                                top - Vector3(0, Cfg.BELT_SUPPORT_MAX_DROP, 0))
                        q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
                        q.exclude = own
                        var hit:= space.intersect_ray(q)
                        if hit.is_empty():
                                continue
                        var ground: Vector3 = hit ["position"]
                        var drop: float = top.y - ground.y
                        if drop < 0.05:
                                continue
                        legs.append(Transform3D(yaw.scaled_local(Vector3(1, drop, 1)), top))
                        feet.append(Transform3D(yaw, ground))
        return [legs, feet]


func _own_bodies() -> Array [RID]:
        var out: Array [RID] = []
        for node in find_children("*", "CollisionObject3D", true, false):
                var body:= node as CollisionObject3D
                if body != null:
                        out.append(body.get_rid())
        return out


var power:= 1.0


var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
        return Cfg.COMPRESSOR_DRAW_KW


func draw_kw() -> float:
        return 0.0 if switched_off else rated_kw()


func power_ports() -> Array [Node3D]:
        if _ports.is_empty():
                _ports = MachinePower.terminals(self, _model, 1, [WIRE_PORT_FALLBACK])
        return _ports


func set_power(f: float) -> void:
        line_power = clampf(f, 0.0, 1.0)
        power = 0.0 if switched_off else line_power
        _apply_press_speed()


        _apply_lamp()


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
        return "power" if MachinePower.fault(power, power_blocked, power_line) != "" else ""


func _apply_press_speed() -> void:
        if _anim == null or _cycle <= 0.0:
                return
        _anim.speed_scale = power * Cfg.COMPRESSOR_PRESS_SECONDS / maxf(_cycle, 0.001)


func buffer_capacity() -> int:
        return Tech.compressor_buffer()


func is_full() -> bool:
        return stored >= buffer_capacity()


func straw_room() -> int:
        return maxi(0, buffer_capacity() - stored)


func is_pressing() -> bool:
        return _press >= 0.0


func alert_reason() -> String:
        if placement_preview:
                return ""
        if switched_off:
                return ""


        var dead:= MachinePower.fault(power, power_blocked, power_line)
        if dead != "":
                return dead
        if _press >= 0.0:


                if not _released and _press >= _release_at():
                        return tr("OUTFEED BLOCKED  ·  move the bale off the deck")
                return ""
        if starved_for >= Cfg.MACHINE_STARVED_AFTER:
                return tr("NO HAY  ·  nothing is reaching the intake")
        return ""


func press_progress() -> float:
        if _press < 0.0:
                return 0.0
        return clampf(_press / _cycle, 0.0, 1.0)


func factory_tick(delta: float) -> void:
        var held:= stored
        _intake_hay()


        starved_for = 0.0 if stored > held else starved_for + delta
        _tick_press(delta)
        _sync_backpressure()
        _tick_press_loop(delta)


func _intake_hay() -> void:
        if live == null or _intake == null:
                return


        if _belt != null and not is_full():
                var m:= _belt.s_at(_mouth())
                var rec:= _belt.take_record(Callable(), m - INTAKE_LENGTH * 0.5, m + INTAKE_LENGTH * 0.5)
                if not rec.is_empty():
                        stored += int(rec ["strands"])
                        if int(rec ["needle"]) >= 0:
                                pending_needles.append(int(rec ["needle"]))
                        Audio.play_3d("machine_thud", _mouth(), -9.0)
        for body in _intake.get_overlapping_bodies():
                var rb:= body as RigidBody3D
                if rb == null or not rb.is_inside_tree():
                        continue


                var wad:= rb as HayWad
                if wad != null:
                        if (wad.freeze and not BeltPath.is_rider(wad)) or is_full():
                                continue


                        BeltPath.release(wad)
                        stored += wad.strands


                        if wad.holds_needle():
                                pending_needles.append(wad.needle_index)


                        Audio.play_3d("machine_thud", _mouth(), -9.0)
                        if props != null:
                                props.remove(wad)
                        else:
                                wad.queue_free()
                        continue
                if not (rb.collision_layer & Cfg.L_STRAND):
                        continue


                if rb.freeze and not BeltPath.is_rider(rb):
                        continue


                if rb.has_meta("needle_index"):
                        BeltPath.release(rb)
                        var index:= int(rb.get_meta("needle_index", -1))
                        if live.consume_needle(rb):
                                pending_needles.append(index)
                        continue
                if is_full():
                        continue


                BeltPath.release(rb)
                if live.consume(rb):
                        stored += 1


                        Audio.play_3d("machine_feed", _mouth(), -13.0)


func _mouth() -> Vector3:
        if _intake == null:
                return global_position
        return _intake.global_position


func _tick_press(delta: float) -> void:
        if _press < 0.0:


                if power <= 0.0:
                        return
                if stored >= Tech.compressor_bale_strands():
                        _start_press()
                return


        _press += delta * power
        if not _released and _press >= _release_at():
                _release_bale()
        if _press >= _cycle:
                _finish_press()


func _release_at() -> float:
        return _cycle * (F_RELEASE / CYCLE_FRAMES)


func _start_press() -> void:


        _batch = Tech.compressor_bale_strands()
        _cycle = Tech.compressor_press_seconds()
        stored -= _batch
        _press = 0.0
        _released = false
        if _anim != null and _clip_name() != "":
                _apply_press_speed()
                _anim.play(_clip_name())
                _anim.seek(0.0, true)
        if _press_voice < 0:


                _press_voice = Audio.loop_acquire("motor_b")
                _press_gain = PRESS_LOOP_SILENT
        _press_target = PRESS_LOOP_DB


        Audio.play_3d("machine_clunk", _emitter(), -9.0)
        _apply_lamp()


func _finish_press() -> void:


        if not _released:
                _press = _release_at()
                _release_bale()
                return
        _press = -1.0
        _press_target = PRESS_LOOP_SILENT
        if _anim != null:
                _anim.pause()
        _apply_lamp()


func bale_spot() -> Vector3:
        return to_global(_marker_local(N_BALE_OUT, Vector3(0, 0, 0.98)))


func outfeed_reserve() -> float:
        return Cfg.COMPRESSOR_BALE_CLEAR * 0.5


func _release_bale() -> void:
        if props == null:


                push_warning("HayCompressor: no PropManager; the bale cannot be created")
                _released = true
                return
        var at:= bale_spot()
        if not _bale_room(at):
                return


        var out:= _outfeed()
        if out != null:
                var needle:= pending_needles [0] if not pending_needles.is_empty() else -1
                var state:= { "strands": _batch }
                if needle >= 0:
                        state ["needle"] = needle
                var seq:= out.push_record(BeltRun.Kind.BALE, _batch, needle, state, at)
                if seq < 0:
                        return
                if needle >= 0:
                        pending_needles.remove_at(0)
                _released = true
                Audio.play_3d("machine_vent", at, -7.0)
                Audio.play_3d_delayed("machine_thud", at, 0.12, -5.0)
                baled_record.emit(seq)
                return
        var b:= global_basis
        var bale:= props.spawn("hay_bale",
                Transform3D(b, at + Vector3.UP * (Cfg.COMPRESSOR_BALE_SIZE.y * 0.06))) as HayBale
        if bale == null:
                _released = true
                return
        bale.strands = _batch


        if not pending_needles.is_empty():
                bale.needle_index = pending_needles [0]
                pending_needles.remove_at(0)
        _released = true


        Audio.play_3d("machine_vent", at, -7.0)
        Audio.play_3d_delayed("machine_thud", at, 0.12, -5.0)
        baled.emit(bale)


func _bale_room(at: Vector3) -> bool:
        if not is_inside_tree():
                return false
        if _room_probe == null:
                _room_probe = BoxShape3D.new()
                _room_probe.size = Vector3(Cfg.COMPRESSOR_BALE_SIZE.x,
                        Cfg.COMPRESSOR_BALE_SIZE.y, Cfg.COMPRESSOR_BALE_CLEAR)
                _room_query = PhysicsShapeQueryParameters3D.new()
                _room_query.shape = _room_probe
                _room_query.collision_mask = Cfg.L_PROP
                _room_query.collide_with_areas = false
        _room_query.transform = Transform3D(global_basis,
                at + Vector3.UP * Cfg.COMPRESSOR_BALE_SIZE.y * 0.5)
        return get_world_3d().direct_space_state.intersect_shape(_room_query, 1).is_empty()


func _sync_backpressure() -> void:
        if _belt == null:
                return
        var full:= is_full()
        if _belt.is_blocked() != full:
                _belt.set_blocked(full)
        _belt.set_outlet_held(full)


func _apply_lamp() -> void:
        if power <= 0.0:
                light_lamps(_go_meshes, GO_OFF)
        else:
                light_lamps(_go_meshes, GO_RUNNING if is_pressing() else GO_IDLE)


func go_energy() -> float:
        return lamp_energy(_go_meshes)


func _emitter() -> Vector3:
        return global_position + Vector3(0, PRESS_LOOP_HEIGHT, 0)


func _tick_press_loop(delta: float) -> void:
        if _press_voice < 0:
                return
        _press_gain = move_toward(_press_gain, _press_target, PRESS_LOOP_RAMP * delta)
        if _press_target <= PRESS_LOOP_SILENT and _press_gain <= PRESS_LOOP_SILENT + 0.5:
                _release_press_loop()
                return


        Audio.loop_update(_press_voice, _emitter(), _press_gain,
                MachinePower.loop_pitch(power))


func _release_press_loop() -> void:
        if _press_voice < 0:
                return
        Audio.loop_release(_press_voice)
        _press_voice = -1
        _press_gain = PRESS_LOOP_SILENT
        _press_target = PRESS_LOOP_SILENT


func _exit_tree() -> void:
        _release_press_loop()


func set_preview_valid(valid: bool) -> void:
        if not placement_preview or _model == null:
                return
        var material:= ConveyorKit.ghost_material(valid)
        for mesh in _meshes():
                mesh.material_overlay = material


        if _ghost_belt != null:
                _ghost_belt.set_material(material)


func build_cost() -> float:
        return Cfg.COMPRESSOR_COST


func to_dict() -> Dictionary:
        return {
                "type": "hay_compressor",
                "off": switched_off,
                "position": global_position,
                "yaw": global_rotation.y,


                "stored": stored,

                "needles": pending_needles,
        }
