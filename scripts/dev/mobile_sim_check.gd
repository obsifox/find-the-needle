extends SceneTree

## Headless dev check for the v2.2.0 belt-crash fix (run with -s).
## Verifies the mobile shader parses, that ConveyorKit picks the right shader
## variant for each device class, and that the touched scripts compile.
## MOBILESIM=1 in the environment flips Cfg.is_mobile first, so the check
## runs against the mobile selection in a fresh engine process.
##
## NOTE: -s main loops do not get global class names or autoloads resolved at
## parse time, so everything is reached through load() and node lookups.

func _initialize() -> void:
        var failures: PackedStringArray = []
        var mobile_sim:= OS.get_environment("MOBILESIM") == "1"

        var sh: Shader = load("res://assets/conveyor_surface_mobile.gdshader")
        if sh == null:
                failures.append("conveyor_surface_mobile.gdshader did not load")
        var full: Shader = load("res://assets/conveyor_surface.gdshader")
        if full == null:
                failures.append("conveyor_surface.gdshader did not load")

        var kit: GDScript = load("res://scripts/build/conveyor_kit.gd")
        if kit == null or not kit.can_instantiate():
                failures.append("conveyor_kit.gd failed to compile")

        var cfg: Node = root.get_node_or_null("Cfg")
        if cfg == null:
                # -s runs do not always instance autoloads; fake what we need.
                cfg = load("res://autoload/cfg.gd").new()
                cfg.is_mobile = false
                root.add_child(cfg)
        if mobile_sim:
                cfg.is_mobile = true

        var belt: ShaderMaterial = kit.own_belt_material(1.0)
        var drum: ShaderMaterial = kit.drum_material()
        var frame: ShaderMaterial = kit.frame_material()
        var roller: ShaderMaterial = kit.roller_material()
        var want:= "conveyor_surface_mobile.gdshader" if mobile_sim \
                else "conveyor_surface.gdshader"
        for m: ShaderMaterial in [belt, drum, frame, roller]:
                var path:= m.shader.resource_path if m.shader != null else ""
                if not path.ends_with(want):
                        failures.append("material got shader %s, wanted %s" % [path, want])

        var std: StandardMaterial3D = kit.frame_material_standard()
        if std == null:
                failures.append("frame_material_standard() returned null")
        else:
                if std.albedo_texture == null:
                        failures.append("frame_material_standard has no albedo texture")
                if not std.normal_enabled:
                        failures.append("frame_material_standard has no normal map")

        for path in ["res://scripts/world/hay_selling_stand.gd",
                        "res://scripts/world/world.gd",
                        "res://scripts/world/delivery_truck.gd",
                        "res://scripts/world/delivery_director.gd",
                        "res://autoload/crash_report.gd",
                        "res://autoload/cfg.gd",
                        "res://scripts/build/belt_path.gd",
                        "res://scripts/build/belt_sweep.gd"]:
                var s: GDScript = load(path)
                if s == null or not s.can_instantiate():
                        failures.append("script failed to compile: %s" % path)

        if failures.is_empty():
                print("[mobile_sim_check] PASS (%s)" % ("mobile" if mobile_sim else "desktop"))
                quit(0)
        else:
                for f in failures:
                        printerr("[mobile_sim_check] FAIL: %s" % f)
                quit(1)
