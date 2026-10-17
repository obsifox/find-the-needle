class_name DevTechUiProbe
extends Node
## UI-only tech tree probe: builds a bare TechPanel (no 3D world) and saves
## screenshots, for comparing en/fa board layout without booting the world.
## Usage:
##   godot --path . res://scenes/dev/tech_ui_probe.tscn -- --techui [--fa] [out.png]


func _ready() -> void:
        call_deferred("_run")


func _run() -> void:
        var args:= OS.get_cmdline_user_args()
        var out:= "res://captures/techui.png"
        var oi:= args.find("--out")
        if oi >= 0 and oi + 1 < args.size():
                out = args [oi + 1]

        if "--fa" in args:
                TranslationServer.set_locale("fa")
                BuildCatalog.invalidate()
                ItemDb.invalidate()
                TechTree.invalidate()
                Cfg.refresh_rtl()
                UiFont.relocale()

        Tech.reset()
        GameState.money = 2400.0

        var panel:= TechPanel.new()
        panel.name = "TechPanel"
        panel.player = null
        var layer:= CanvasLayer.new()
        add_child(layer)
        layer.add_child(panel)

        Tech.grant("hands", 1)
        Tech.grant("spade", 1)
        Tech.grant("broom", 1)
        Tech.grant("bucket", 1)
        Tech.grant("belt", 1)
        Tech.grant("belt_speed", 2)
        GameState.money = 2400.0

        panel.set_open(true)
        panel._select("belt_speed")
        for i in 8:
                await get_tree().process_frame
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
        var img:= get_viewport().get_texture().get_image()
        img.save_png(ProjectSettings.globalize_path(out))
        _dump(panel, out)
        print("[techui] wrote ", out, " rtl=", Cfg._rtl, " locale=", TranslationServer.get_locale())
        await get_tree().create_timer(0.3).timeout
        get_tree().quit(0)


func _dump(panel: TechPanel, out: String) -> void:
        var id:= "belt_speed"
        var card: Control = panel._cards.get(id)
        print("[dump] out=", out)
        print("[dump] _root.scale=", panel._root.scale, " _root.size=", panel._root.size)
        print("[dump] _zoom=", panel._zoom, " _layout_scale=", panel._layout_scale)
        print("[dump] _world.position=", panel._world.position, " _world.size=", panel._world.size)
        print("[dump] _world_size=", panel._world_size, " _viewport.size=", panel._viewport.size)
        print("[dump] Cfg.tech_text_scale=", Cfg.tech_text_scale)
        if card != null:
                print("[dump] card ", id, " pos=", card.position, " size=", card.size,
                        " scale=", card.scale, " min=", card.custom_minimum_size)
                var parts: Dictionary = panel._parts.get(id, {})
                var name_lbl: Label = parts.get("name")
                if name_lbl != null:
                        print("[dump] name text='", name_lbl.text, "' size=", name_lbl.size,
                                " visible=", name_lbl.is_visible_in_tree())
                var icon: Control = parts.get("icon")
                if icon != null:
                        print("[dump] icon size=", icon.size, " min=", icon.custom_minimum_size,
                                " visible=", icon.is_visible_in_tree())
        var kids:= panel._world.get_children()
        print("[dump] world children=", kids.size())
        var full: Control = panel._cards.get("hands")
        if full != null:
                print("[dump] card 'hands' pos=", full.position, " size=", full.size, " scale=", full.scale)
