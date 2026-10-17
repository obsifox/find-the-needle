class_name DevMenuUiProbe
extends Node
## UI-only main menu probe: builds the real MainMenu (no 3D background, no
## crash dialog) and saves a screenshot, for comparing en/fa logo placement.
## Usage:
##   godot --path . res://scenes/dev/menu_ui_probe.tscn -- --menuui [--fa] --out res://captures/menuui.png


func _ready() -> void:
        call_deferred("_run")


func _run() -> void:
        var args:= OS.get_cmdline_user_args()
        var out:= "res://captures/menuui.png"
        var oi:= args.find("--out")
        if oi >= 0 and oi + 1 < args.size():
                out = args [oi + 1]

        # Kill any stale crash sentinel so nothing can overlay the menu.
        var lock:= "user://session.lock"
        if FileAccess.file_exists(lock):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(lock))

        if "--fa" in args:
                TranslationServer.set_locale("fa")
                BuildCatalog.invalidate()
                ItemDb.invalidate()
                TechTree.invalidate()
                Cfg.refresh_rtl()
                UiFont.relocale()

        var layer:= CanvasLayer.new()
        add_child(layer)

        var menu:= MainMenu.new()
        menu.name = "MainMenu"
        layer.add_child(menu)

        # let the fade tween finish and the fonts settle
        await get_tree().create_timer(1.6).timeout
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
        var img:= get_viewport().get_texture().get_image()
        img.save_png(ProjectSettings.globalize_path(out))

        # measure the logo block for layout diagnostics
        var title: Control = menu.find_child("TitleBlock", true, false)
        if title != null:
                print("[menuui] TitleBlock pos=", title.position, " size=", title.size,
                        " global=", title.global_position)
                _dump_tree(title, 0)
        print("[menuui] wrote ", out, " rtl=", Cfg._rtl, " locale=", TranslationServer.get_locale())
        await get_tree().create_timer(0.3).timeout
        get_tree().quit(0)


func _dump_tree(node: Node, depth: int) -> void:
        if depth > 4:
                return
        var indent:= "  ".repeat(depth + 1)
        var info:= node.get_class()
        if node is Control:
                var c: Control = node
                info += " pos=%s size=%s gpos=%s" % [c.position, c.size, c.global_position]
        elif node is Node2D:
                var n2: Node2D = node
                info += " gpos=%s" % n2.global_position
        if node is Label:
                info += " text='" + (node as Label).text + "'"
        print("[menuui]", indent, info)
        for child in node.get_children():
                _dump_tree(child, depth + 1)


func _all_controls(node: Node) -> Array:
        var out:= []
        for child in node.get_children():
                if child is Control:
                        out.append(child)
                        out.append_array(_all_controls(child))
        return out
