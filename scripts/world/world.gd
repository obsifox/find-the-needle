extends Node3D


const SPAWN_POS:= Vector3(13.2, 0.4, 5.6)


const WARM_FRAMES:= 4


const WARM_LOAD_BATCH:= 2

const DEV_SEED:= 20260823
const DEV_FLAGS:= [


        "--beltfoot",


        "--poleblock",


        "--pileend",


        "--closeguard",


        "--gridports",


        "--floorhatch",


        "--enclosedbelt",


        "--cabledeck",


        "--proppool",


        "--seamwatch",


        "--seamfall",


        "--seamaudit",


        "--beltfuzz",
        "--beltrunprobe", "--transmission", "--bench", "--stress", "--density",


        "--cheat",


        "--showoverlay",


        "--gfxreset",


        "--laptoppreset",


        "--lookknobs",


        "--ledgerdrift",
        "--scoopbench", "--diag", "--capture", "--props", "--arm", "--crouch", "--noclip",


        "--toolthrow",


        "--input",


        "--radar",


        "--radarshot",
        "--broomtest", "--scanner", "--needles", "--cabinet", "--splitter", "--compactsplitter",


        "--splittercost", "--joiner", "--wyejam",


        "--splitterflow",


        "--wyemate",


        "--wyechain",

        "--wyefull",


        "--wyepacked",


        "--wyeshot",


        "--wyelegshot",


        "--usplitter", "--ujoiner", "--uwyemate", "--uwyeshot",


        "--boltedports",


        "--tsplitter", "--tsplittershot",


        "--splitrate",


        "--smartsort", "--smartoverflow",


        "--yardvac",


        "--plead",


        "--nudge",


        "--yardwatch",


        "--brickjump",


        "--buildhitch",


        "--pipehitch",


        "--beltwhy",


        "--eyesmooth",


        "--yardperf",


        "--physfloor",


        "--selltime",


        "--zonestall",


        "--yarddig",


        "--blobrepro",


        "--farblob",


        "--console",


        "--paintboard",


        "--worklamp",


        "--paintpanelshot",


        "--roof",


        "--delivery",


        "--deliveryshot",


        "--detectorshot",


        "--detector",


        "--specimens",


        "--rail", "--railshot",


        "--plaza",


        "--plazaudit",


        "--tunnelshot",


        "--plazaperf",


        "--forkload",


        "--forkaim",


        "--toyreach",

        "--bladepick",


        "--stamina",


        "--wrapper",


        "--silo",

        "--siloperf",


        "--gen",


        "--gasplant",


        "--genwye",


        "--crossclash",


        "--gentarm",


        "--machineseat",


        "--power",


        "--box",


        "--borehole",


        "--pumpshot",


        "--pumpghost",


        "--pipe",


        "--pipeshot",


        "--water",


        "--pulper",


        "--paper",


        "--jam",


        "--haylift",


        "--dismantlecrash",


        "--briquette",


        "--briquetteshot",


        "--briquettewireshot",


        "--papershot",


        "--shredshot",


        "--pulpershot",


        "--pulperlook",


        "--pulpjelly",


        "--pulpcorner",

        "--pulpshot",


        "--rip",
        "--compressor", "--wad", "--drone", "--dronewatch",


        "--postshot",


        "--droneshot",


        "--reachpeek",


        "--fleet",


        "--dronefleet",


        "--dronescale",


        "--dronepath",
        "--beltpile", "--beltjam", "--bucketdump",


        "--queuebounce",


        "--pourpace",


        "--throwstand",


        "--vacpour",


        "--beltroute",


        "--beltthrough",


        "--dumphatch",


        "--powerline",
        "--beltfan", "--beltqueue",


        "--jointcost",


        "--beltload",


        "--beltrun",


        "--throwbelt",


        "--beltdrain",


        "--beltcap",


        "--beltdrum",


        "--heap",


        "--heapshot",


        "--stairs",


        "--rake",


        "--rakeshot",


        "--alerts",


        "--alertshot",


        "--cueshot",


        "--shedshot", "--beltshot",


        "--lampshot",


        "--slabperf",


        "--poleshot",


        "--genpanelshot",


        "--belt", "--ride", "--keep", "--tools", "--hotbar", "--missions", "--sell", "--carry", "--economy", "--avalanche",


        "--coins",


        "--coinshot",


        "--payoutshot",


        "--settle", "--settleshot",


        "--strandcull",


        "--forkbelt",


        "--beltstuck",


        "--launchland",


        "--tubload",


        "--needlepin",

        "--expose",


        "--pileorder",


        "--demolot",


        "--smoke",


        "--landingzone",


        "--needlepanel",


        "--needleloss",


        "--needleroute",


        "--armneedle", "--gpu", "--endingshot", "--democardshot",


        "--sellup",


        "--clearanceshot",


        "--ordershot",


        "--hotbarshot", "--beltshot", "--shedshot",


        "--lodshot",


        "--beltjoinshot",


        "--splitjoinshot",


        "--standjoin", "--standjoinshot",


        "--pileshot",


        "--shopshot",


        "--shopboard", "--shopboardshot",


        "--boardauth",


        "--firstneedle",


        "--pileclear",


        "--boardperiods",
        "--impact",


        "--upright",


        "--bucketfork",


        "--fallenfill",
        "--avalanche-shot", "--shop", "--clip", "--brick", "--cabinetshot",


        "--pelletland",


        "--gridsnap",


        "--wyedeck",


        "--nosnap",


        "--storey",


        "--launcher", "--launchershot",


        "--genghost",


        "--buildfx",


        "--door", "--doorshot", "--mapcard",


        "--sign",


        "--ledgershot",


        "--yard", "--yardshot",


        "--wheat",


        "--fence", "--fenceshot",


        "--yardref",


        "--yardbake",


        "--lookexport",
        "--discovery", "--discoveryshot", "--crustcheck", "--crustheal", "--shellblame", "--presetsweep", "--gpucost", "--detailcost", "--stair", "--smoothcam",


        "--worldcost",


        "--factoryperf",


        "--buildscale",


        "--armscale",

        "--rakescale",


        "--animcost",


        "--workcost",


        "--throw",


        "--simple",

        "--drawershot",


        "--drawerhitch",


        "--yardvacshot",


        "--sackshot",


        "--salefx",


        "--throwcost",


        "--boothwalk",


        "--standwalk",


        "--standshot",


        "--tech",


        "--cards",


        "--handful",


        "--gifts",


        "--giftshot",


        "--markershot",


        "--techshot",


        "--dig", "--digshot",


        "--digswing",


        "--stubble",


        "--iconshots",


        "--lbshot",


        "--retier",


        "--armmodels",

        "--armrelink",


        "--armheadroom",


        "--armjam",


        "--armstarve",


        "--armblock",


        "--armstale",


        "--armsays",


        "--ccdcost",


        "--armgap",


        "--armwatch",


        "--armfeed",


        "--armpick",


        "--barrowapart",

        "--barrowpile",


        "--armpanelshot",


        "--armlinks",


        "--armoverflow",


        "--armorder",


        "--armshot",


        "--armkeepout",


        "--silopanelshot",


        "--splitterpanelshot",


        "--armreload",


        "--dismantle", "--dismantleshot",


        "--beltreverse",


        "--wall",


        "--decay",


        "--saveguard",


        "--loc",


        "--loclang",


        "--locshots",


        "--stackpick",


        "--armload",


        "--armloadshot",


        "--jetpack",


        "--jetpackshot",


        "--grippyboots",


        "--lighter",


        "--lightershot",


        "--stagedload",


        "--restoreslice",


        "--factoryfull"]


var block_save:= false


const AUTOSAVE_SECONDS:= 120.0
var autosave_enabled:= true


var _autosave_left:= AUTOSAVE_SECONDS


const STAND_POS:= Vector3(12.4, 0.0, -12.4)
const STAND_YAW:= -45.0


const STAND_OUT:= Vector3(0.0, 0.0, -1.0)


const SHOP_POS:= Vector3(12.4, 0.0, 12.4)
const SHOP_YAW:= -135.0


const HDRI_SUN_DIR:= Vector3(0.4313, 0.6817, -0.591)

var field: HayField
var avalanche_vfx: AvalancheVfx


var belt_flip_vfx: BeltFlipVfx
var live: LiveStrandManager

var shadow_lod: ShadowLod

var detail: HayDetail
var player: Player
var hud: Hud
var warehouse: Warehouse
var builds: BuildManager
var props: PropManager
var belt_audio: BeltAudio
var water_audio: WaterAudio
var stand: HaySellingStand
var shop: HayShop

var shop_board: ShopBoard

var rank_board: RankBoard
var bay_door: BayDoor


var floor_hatch: FloorHatch
var terrain: YardTerrain


var wheat_cull: WheatCull


var plaza: BrutalistPlaza
var debug_menu: DebugMenu


var needle_wallhack: NeedleWallhack


var needle_glints: NeedleGlints
var shop_menu: ShopMenu
var map_menu: MapMenu
var needle_panel: NeedlePanel


var landing_zone: LandingZone
var load_panel: LoadPanel
var zone_card: ZoneCard
var catalog_panel: CatalogPanel
var tech_panel: TechPanel
var discovery_card: DiscoveryCard
var gift_card: GiftCard
var needle_inspector: NeedleInspector
var needle_drawer: NeedleDrawer
var rake_panel: RakePanel
var pelletizer_panel: PelletizerPanel
var launcher_panel: LauncherPanel
var lamp_panel: LampPanel
var splitter_panel: SplitterPanel
var silo_panel: SiloPanel
var paint_panel: PaintPanel
var arm_panel: ArmPanel
var arm_links: ArmLinkMode
var drone_panel: DronePanel
var drone_zone: DroneZoneMode
var machine_panel: MachinePanel
var pole_panel: PolePanel
var pause_menu: PauseMenu
var sell_all_dialog: SellAllDialog
var demo_end_dialog: DemoEndDialog
var quests: QuestPanel
var mission_cue: MissionCue
var missions: MissionDirector
var truck: DeliveryTruck
var delivery_board: DeliveryBoard
var contracts: ContractPanel
var deliveries: DeliveryDirector

var intro: IntroSequence
var sun: DirectionalLight3D
var fill: DirectionalLight3D

var room_probe: ReflectionProbe

var dust: DustMotes
var env_node: WorldEnvironment
var _machine_fog_defaults: Dictionary = { }


var _sky_mat: ShaderMaterial
var _cloud_offset:= Vector3.ZERO


var _grade_ramp: GradientTexture1D


var _dev:= false


var _staged:= false


var _warm_paths:= PackedStringArray()

var _load_laps: DevLoadLaps = null

var _built:= false

var _intro_due:= false


func _ready() -> void:
        _dev = _detect_dev_run()
        if "--beltrunprobe" in OS.get_cmdline_user_args():
                block_save = true
                SaveManager.block_save = true
                push_error("The ordinary run prototype is archived. Apply its patch before using this probe.")
                get_tree().quit(1)
                return


        var uargs:= OS.get_cmdline_user_args()
        _staged = not _dev or Cfg.is_mobile or "--stagedload" in uargs or "--drawerhitch" in uargs
        if "--stagedload" in OS.get_cmdline_user_args():
                _load_laps = DevLoadLaps.new()
                _load_laps.watch(self)


        Sketchbook.inert = _dev
        _apply_pile_size_override()
        if _staged:


                if not Loading.is_active():


                        Loading.show_screen("FIND THE NEEDLE", tr("PREPARING THE PILE"))


                get_tree().paused = true
        await _build()
        if _staged:
                await _finish_build()


        if detail != null and player != null:
                detail.fill_now(player.eye_position())
        _built = true

        # BUGFIX (mobile): virtual stick + action buttons for phones.
        if Cfg.is_mobile and get_node_or_null(NodePath("TouchControls")) == null:
                var tc:= TouchControls.new()
                tc.name = "TouchControls"
                add_child(tc)


        Profile.enter_yard()


        if intro != null:


                if plaza != null:
                        plaza.hold_the_doorway(false)
                        intro.finished.connect(plaza.hold_the_doorway.bind(true),
                                CONNECT_ONE_SHOT)
                intro.begin()
        _run_dev_probe()


func _seat(v: Vector3) -> Vector3:
        var k:= Cfg.yard_seat_scale()
        return Vector3(v.x * k, v.y, v.z * k)


var _perf_copy_cache: Variant = null


func _perf_copy() -> Dictionary:
        if _perf_copy_cache != null:
                return _perf_copy_cache
        _perf_copy_cache = { }
        var ua:= OS.get_cmdline_user_args()
        var at:= ua.find("--yardperf")
        if at < 0:
                at = ua.find("--physfloor")
        if at < 0 or at + 1 >= ua.size():
                return _perf_copy_cache
        var f:= SaveManager.open_for_read(ua [at + 1])
        if f == null:
                return _perf_copy_cache
        var payload: Variant = f.get_var(true)
        f.close()
        if payload is Dictionary:
                _perf_copy_cache = payload
        return _perf_copy_cache


func _apply_pile_size_override() -> void:
        var ua:= OS.get_cmdline_user_args()


        if _dev and not _perf_copy().is_empty():
                var copy_meta: Dictionary = _perf_copy().get("meta", { })
                Cfg.shed_long_bays = int(copy_meta.get("shed_bays", 0))
        if _dev and "--savedpile" in ua and not _perf_copy().is_empty():
                var meta: Dictionary = _perf_copy().get("meta", { })
                var size:= str(meta.get("pile_size", Cfg.DEFAULT_PILE_SIZE))
                Cfg.apply_pile_size(size if size != "" else Cfg.DEFAULT_PILE_SIZE)
                print("[world] pile size from the save copy: %s" % Cfg.pile_size_id)
                return
        var i:= ua.find("--pile")
        if i < 0 or i + 1 >= ua.size():
                return
        if not _dev and not ("--intro" in ua or "--introshot" in ua):
                push_warning("World: --pile is for dev runs; ignoring it on a run that owns a slot")
                return
        var id:= ua [i + 1]
        Cfg.apply_pile_size(id)
        print("[world] pile size: %s (r %.1f, h %.1f, extent %.1f)"
                % [Cfg.pile_size_id, Cfg.PILE_RADIUS, Cfg.PILE_HEIGHT, Cfg.FIELD_EXTENT])


func _cull_wheat() -> void:
        wheat_cull = WheatCull.new()
        wheat_cull.terrain = terrain.terrain()
        wheat_cull.warehouse = warehouse
        wheat_cull.pad = warehouse.get_node_or_null(NodePath("YardGround"))
        wheat_cull.cull()
        warehouse.rebuilt.connect(func() -> void:


                wheat_cull.pad = warehouse.get_node_or_null(NodePath("YardGround"))
                wheat_cull.cull()
        )


func _build_site() -> void:
        var site:= SaveManager.current_map


        var ua:= OS.get_cmdline_user_args()
        if "--plaza" in ua or "--plazaudit" in ua or "--plazaperf" in ua or "--tunnelshot" in ua:
                site = "brutalist_plaza"


                SaveManager.current_map = site


        var perf:= ua.find("--yardperf")
        if perf < 0:
                perf = ua.find("--physfloor")
        if perf < 0:
                perf = ua.find("--zonestall")
        if perf < 0:
                perf = ua.find("--beltwhy")
        if perf >= 0 and perf + 1 < ua.size():
                var f:= SaveManager.open_for_read(ua [perf + 1])
                if f != null:
                        var payload: Variant = f.get_var(true)
                        f.close()
                        if typeof(payload) == TYPE_DICTIONARY:
                                var meta: Dictionary = (payload as Dictionary).get("meta", { })
                                site = str(meta.get("map", SaveManager.DEFAULT_MAP))
                                SaveManager.current_map = site
        if site == SaveManager.DEFAULT_MAP:
                return
        if site != "brutalist_plaza":
                push_warning("World: unknown site '%s', standing in the warehouse" % site)
                return

        warehouse.visible = false
        terrain.visible = false
        _unbuild_the_yard()
        plaza = BrutalistPlaza.new()
        plaza.name = "BrutalistPlaza"
        add_child(plaza)
        plaza.build()


        plaza.light_it(sun, env_node.environment if env_node != null else null)
        print("[world] site: the plaza")


func _unbuild_the_yard() -> void:
        print("[world] the plaza: took %d yard colliders out of the physics world"
                % (_unsolid(warehouse) + _unsolid(terrain)))
        warehouse.rebuilt.connect(func() -> void:
                _unsolid(warehouse)
        )


func _unsolid(root: Node) -> int:
        var n:= 0
        var stack: Array [Node] = [root]
        while not stack.is_empty():
                var node: Node = stack.pop_back()
                for kid: Node in node.get_children():
                        stack.append(kid)
                var body:= node as CollisionObject3D
                if body == null or body.collision_layer == 0:
                        continue
                body.collision_layer = 0
                n += 1
        return n


func _detect_dev_run() -> bool:
        var ua:= OS.get_cmdline_user_args()
        if "--usesave" in ua:
                return false
        for f: String in DEV_FLAGS:
                if f in ua:
                        return true
        return false


func _stage(caption: String, progress: float) -> void:
        if not _staged:
                return
        Loading.step(caption, progress)
        if _warm_camera != null:
                _warm_camera.rotate_y(PI * 0.5)
        await get_tree().process_frame


var _warm_camera: Camera3D


func _add_warm_camera() -> void:
        if not _staged:
                return
        _warm_camera = Camera3D.new()
        _warm_camera.name = "WarmCamera"
        _warm_camera.fov = 100.0
        add_child(_warm_camera)
        _warm_camera.position = _seat(SPAWN_POS) + Vector3(0.0, Player.EYE_HEIGHT, 0.0)
        _warm_camera.current = true


func _drop_warm_camera() -> void:
        if _warm_camera == null:
                return
        remove_child(_warm_camera)
        _warm_camera.free()
        _warm_camera = null


const RESTORE_SLICE_USEC:= 50000


func _start_warm_loads() -> void:
        if not _staged:
                return
        var paths:= { LOOK_SCENE: true, YardTerrain.SCENE: true }


        var regions:= DirAccess.open(YardTerrain.DATA_DIR)
        if regions != null:
                for file in regions.get_files():
                        if file.get_extension() == "res":
                                paths [YardTerrain.DATA_DIR.path_join(file)] = true
        var queue:= PackedStringArray()
        for path: String in paths:
                if ResourceLoader.exists(path):
                        queue.append(path)
        print("[load] warming %d critical files, at most %d together"
                % [queue.size(), WARM_LOAD_BATCH])
        var cursor:= 0
        while cursor < queue.size():
                var batch:= PackedStringArray()
                for i in WARM_LOAD_BATCH:
                        if cursor >= queue.size():
                                break
                        var path:= queue [cursor]
                        cursor += 1
                        if ResourceLoader.load_threaded_request(path) == OK:
                                batch.append(path)
                                _warm_paths.append(path)
                var waiting:= true
                while waiting:
                        waiting = false
                        for path in batch:
                                if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                                        waiting = true
                                        break
                        if waiting:
                                await _breathe()


                await _breathe()


func _release_warm_loads() -> void:
        for path in _warm_paths:
                if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                        ResourceLoader.load_threaded_get(path)
        _warm_paths.clear()


func _await_warm_load(path: String) -> void:
        if not _staged:
                return
        while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                await _breathe()


func _breathe() -> void:
        if not _staged:
                return
        if _warm_camera != null:
                _warm_camera.rotate_y(PI * 0.5)
        await get_tree().process_frame


func _finish_build() -> void:
        Loading.step(tr("WARMING UP"), 1.0)


        var needles:= NeedleView.warm_view() if NeedleView.warm_enabled else null
        if needles != null:
                add_child(needles)
        for i in WARM_FRAMES:
                await get_tree().process_frame
                Loading.note_gpu("warm frame %d" % (i + 1))
        if needles != null:
                needles.queue_free()
        get_tree().paused = false
        await get_tree().physics_frame
        Loading.note_gpu("physics frame")
        _release_warm_loads()
        Loading.hide_screen()


func _build() -> void:
        await _stage(tr("RAISING THE SKY"), 0.02)
        await _start_warm_loads()


        await _await_warm_load(LOOK_SCENE)
        _build_look()


        _apply_render_settings()
        _add_warm_camera()
        await _stage(tr("CLEARING THE YARD"), 0.1)

        warehouse = Warehouse.new()
        warehouse.name = "Warehouse"


        warehouse.set_door_void(Warehouse.Wall.X_POS, 0.0,
                BayDoor.OPENING_W, BayDoor.OPENING_H)
        add_child(warehouse)


        await _stage(tr("ROLLING THE FIELDS"), 0.14)
        await _await_warm_load(YardTerrain.SCENE)
        terrain = YardTerrain.new()
        terrain.name = "YardTerrain"
        terrain.track_yaw = Warehouse.wall_yaw(Warehouse.Wall.X_POS)
        add_child(terrain)
        await _breathe()
        _cull_wheat()
        await _breathe()

        _build_site()
        await _breathe()

        builds = BuildManager.new()
        builds.name = "Buildings"
        add_child(builds)


        if _dev and not ("--power" in OS.get_cmdline_user_args()) and not ("--box" in OS.get_cmdline_user_args()) and not ("--borehole" in OS.get_cmdline_user_args()) and not ("--gasplant" in OS.get_cmdline_user_args()):
                builds.grid.unmetered = true


        if _dev and not ("--water" in OS.get_cmdline_user_args()) and not ("--pulper" in OS.get_cmdline_user_args()) and not ("--gasplant" in OS.get_cmdline_user_args()):
                builds.water.unmetered = true


        Cfg.demo_lot_gate = Cfg.DEMO and (not _dev or "--demolot" in OS.get_cmdline_user_args())

        field = HayField.new()
        field.name = "HayField"
        add_child(field)
        builds.field = field
        await _breathe()

        avalanche_vfx = AvalancheVfx.new()
        avalanche_vfx.name = "AvalancheVfx"
        add_child(avalanche_vfx)
        field.avalanche_vfx = avalanche_vfx

        live = LiveStrandManager.new()
        live.name = "LiveStrands"
        add_child(live)
        builds.live = live


        props = PropManager.new()
        props.name = "Props"
        props.live = live


        props.clean_blocked = _dev


        live.props = props
        add_child(props)


        var belt_clock:= FactoryClock.new()
        belt_clock.name = "FactoryClock"
        add_child(belt_clock)


        builds.props = props


        shadow_lod = ShadowLod.new()
        shadow_lod.name = "ShadowLod"
        add_child(shadow_lod)
        shadow_lod.setup(builds, props)
        var machine_draw_distance:= MachineDrawDistance.new()
        machine_draw_distance.name = "MachineDrawDistance"
        add_child(machine_draw_distance)
        machine_draw_distance.setup(builds)


        if "--loadflow" in OS.get_cmdline_user_args() or "--intro" in OS.get_cmdline_user_args() or "--introshot" in OS.get_cmdline_user_args():
                block_save = true


        if "--intro" in OS.get_cmdline_user_args() or "--introshot" in OS.get_cmdline_user_args():


                SaveManager.begin_new_game(SaveManager.current_slot, true,
                        SaveManager.current_map, Cfg.pile_size_id)


        if _dev:
                block_save = true


                ConveyorTSplitter.placed_port_r = Cfg.T_SPLITTER_PORT_R
        var saved:= PackedFloat32Array() if _dev else SaveManager.load_game()
        var seed_value:= DEV_SEED if _dev else (GameState.run_seed if saved.size() > 0 else randi())


        var ua:= OS.get_cmdline_user_args()
        if "--seed" in ua:
                seed_value = int(ua [ua.find("--seed") + 1])
                saved = PackedFloat32Array()


        var saved_dome:= PackedFloat32Array() if _dev else SaveManager.take_dome()


        var copy:= _perf_copy()
        if _dev and "--savedpile" in ua and not copy.is_empty():
                saved = copy.get("heights", PackedFloat32Array())
                seed_value = int((copy.get("state", { }) as Dictionary).get("run_seed", seed_value))
                GameState.run_seed = seed_value
                var dome: Variant = copy.get("dome", null)
                if dome is PackedFloat32Array and int(copy.get("dome_seed", -1)) == seed_value:
                        saved_dome = dome
        if saved.is_empty():
                saved_dome = PackedFloat32Array()
        if "--seed" in OS.get_cmdline_user_args() or _dev:
                print("[world] pile seed=%d  saved_heights=%d" % [seed_value, saved.size()])
        if _staged:
                await _stage(tr("SHAPING THE PILE"), 0.14)
                await field.generate_staged(seed_value, saved,
                        func(f: float) -> void: Loading.step(tr("SETTLING THE PILE"), lerpf(0.3, 0.7, f)),
                        func(f: float) -> void: Loading.step(tr("SHAPING THE PILE"), lerpf(0.14, 0.3, f)),
                        saved_dome)
        else:
                field.generate(seed_value, saved, saved_dome)
        live.field = field


        detail = HayDetail.new()
        detail.name = "HayDetail"
        detail.field = field
        add_child(detail)


        await _stage(tr("OPENING THE STAND"), 0.74)
        CrashReport.note_doing("stand:new")
        stand = HaySellingStand.new()
        stand.name = "SellingStand"
        stand.live = live


        stand.props = props
        stand.position = _seat(STAND_POS) + STAND_OUT * Warehouse.long_for(Cfg.yard_inner_for_pile())
        stand.rotation.y = deg_to_rad(STAND_YAW)
        add_child(stand)
        CrashReport.note_doing("stand:ready")


        builds.stand = stand


        shop_board = ShopBoard.new()
        shop_board.name = "ShopBoard"
        stand.add_child(shop_board)
        CrashReport.note_doing("stand:shop_board")

        await _breathe()
        CrashReport.note_doing("stand:shop")
        shop = HayShop.new()
        shop.name = "SupplyShop"
        shop.position = _seat(SHOP_POS)
        shop.rotation.y = deg_to_rad(SHOP_YAW)
        add_child(shop)


        rank_board = RankBoard.new()
        rank_board.name = "RankBoard"
        shop.add_child(rank_board)
        CrashReport.note_doing("stand:rank_board")


        bay_door = BayDoor.new()
        bay_door.name = "BayDoor"
        bay_door.warehouse = warehouse
        bay_door.wall = BayDoor.Wall.X_POS
        bay_door.along = 0.0
        add_child(bay_door)
        CrashReport.note_doing("stand:bay_door")


        if plaza != null:
                plaza.seat_tunnel(bay_door)
                warehouse.rebuilt.connect(func() -> void:
                        plaza.seat_tunnel(bay_door)
                )


        await _breathe()
        CrashReport.note_doing("stand:truck")
        truck = DeliveryTruck.new()
        truck.name = "DeliveryTruck"
        truck.door = bay_door
        truck.warehouse = warehouse
        add_child(truck)


        if props != null:
                props.truck = truck

        delivery_board = DeliveryBoard.new()
        delivery_board.name = "DeliveryBoard"
        delivery_board.door = bay_door
        delivery_board.warehouse = warehouse
        add_child(delivery_board)
        CrashReport.note_doing("stand:delivery_board")

        await _stage(tr("FINDING YOU A PITCHFORK"), 0.82)
        var body_usec:= Time.get_ticks_usec()
        _drop_warm_camera()
        player = Player.new()
        player.name = "Player"


        player.defer_tools = _staged
        add_child(player)
        if _staged:
                print("[load]   player body: %.0f ms" % ((Time.get_ticks_usec() - body_usec) / 1000.0))
        await _breathe()
        if player.defer_tools:
                for which: String in Player.TOOL_ORDER:
                        var tool_usec:= Time.get_ticks_usec()
                        player.add_tool(which)
                        print("[load]   player tool %s: %.0f ms"
                                % [which, (Time.get_ticks_usec() - tool_usec) / 1000.0])


                        if player.build != null and not player.build.previews_ready:
                                await player.build.previews_built
                        await _breathe()
                player.tools_built()


        _intro_due = _staged and not _dev and (SaveManager.take_intro_due()
                        or "--intro" in OS.get_cmdline_user_args()
                        or "--introshot" in OS.get_cmdline_user_args())
        if _intro_due:


                SaveManager.take_player_transform()


                player.global_position = _seat(SPAWN_POS)
        elif SaveManager.has_pending_player_transform:
                player.global_transform = SaveManager.take_player_transform()


                if plaza != null and plaza.in_the_bore(player.global_position):
                        print("[world] the plaza: the save had the player in the bore, "
                                + "putting them back in the room")
                        player.global_position = _seat(SPAWN_POS)
        else:
                player.global_position = _seat(SPAWN_POS)
                player.look_at_from_position(_seat(SPAWN_POS), Vector3(0, 3.0, 0), Vector3.UP)
                player.rotation = Vector3(0, player.rotation.y, 0)


        await _stage(tr("RESTORING THE YARD"), 0.86)


        if _staged:
                builds.restore_slice_usec = RESTORE_SLICE_USEC
        await builds.from_array(SaveManager.take_buildings())
        builds.restore_slice_usec = 0


        builds.grid.settle_next_rebuild()


        if not _dev:
                builds.grid_rebuilt.connect(_on_first_grid_rebuild, CONNECT_ONE_SHOT)


        props.from_array(SaveManager.take_props())


        _restore_belts()


        _restore_loose_needles()

        live.player_ref = player


        props.player_ref = player


        player.warehouse = warehouse
        player.respawn_fallback = _seat(SPAWN_POS)
        player.build.builds = builds


        var discovery:= DiscoveryDirector.new()
        discovery.name = "DiscoveryDirector"
        discovery.builds = builds
        add_child(discovery)


        needle_glints = NeedleGlints.new()
        needle_glints.name = "NeedleGlints"
        needle_glints.live = live
        needle_glints.player = player


        needle_glints.sun_dir = (sun.global_transform.basis.z.normalized()
                if sun != null else HDRI_SUN_DIR)
        add_child(needle_glints)
        player.hand.field = field
        player.hand.live = live
        player.aim.field = field


        player.shovel.setup(self, field, live, props)
        player.pitchfork.setup(self, field, live, props)
        player.broom.setup(self, field, live)
        player.yard_vac.setup(self, field, live)


        player.lighter.setup(self, field, live, props)


        player.detector.setup(field, props, live)

        await _stage(tr("HANGING THE SIGNS"), 0.92)


        Cfg.set_no_hud(false)
        hud = Hud.new()
        hud.name = "HUD"
        hud.field = field
        hud.live = live
        hud.props = props
        hud.player = player
        var layer:= CanvasLayer.new()
        layer.add_child(hud)
        add_child(layer)


        quests = QuestPanel.new()
        quests.name = "QuestPanel"
        layer.add_child(quests)

        hud.quests = quests


        mission_cue = MissionCue.new()
        mission_cue.name = "MissionCue"
        layer.add_child(mission_cue)
        missions = MissionDirector.new()
        missions.name = "Missions"
        missions.world = self
        missions.player = player
        missions.panel = quests
        missions.cue = mission_cue
        add_child(missions)


        var marker:= ObjectiveMarker.new()
        marker.name = "ObjectiveMarker"
        marker.missions = missions
        marker.player = player
        layer.add_child(marker)


        belt_flip_vfx = BeltFlipVfx.new()
        belt_flip_vfx.name = "BeltFlipVfx"
        belt_flip_vfx.player = player
        add_child(belt_flip_vfx)


        contracts = ContractPanel.new()
        contracts.name = "ContractPanel"
        layer.add_child(contracts)
        deliveries = DeliveryDirector.new()
        deliveries.name = "Deliveries"
        deliveries.truck = truck
        deliveries.board = delivery_board
        deliveries.panel = contracts
        deliveries.props = props
        add_child(deliveries)


        delivery_board.player = player
        delivery_board.live = live
        delivery_board.note_pressed.connect(_open_load_panel)
        delivery_board.chit_pressed.connect(_open_needle_panel)
        player.board = delivery_board


        landing_zone = LandingZone.new()
        landing_zone.name = "LandingZone"
        landing_zone.builds = builds
        add_child(landing_zone)


        if plaza == null and GameState.has_hatch:
                floor_hatch = FloorHatch.new()
                floor_hatch.name = "FloorHatch"
                add_child(floor_hatch)
                player.floor_hatch = floor_hatch


        GameState.needle_lost.connect(_on_needle_lost)

        shop_menu = ShopMenu.new()
        shop_menu.name = "ShopMenu"
        shop_menu.player = player
        shop_menu.props = props
        shop_menu.shop = shop
        shop_menu.hud = hud


        player.carry.hud = hud

        player.yard_vac.hud = hud
        player.lighter.hud = hud
        player.shop = shop_menu
        layer.add_child(shop_menu)
        hud.shop = shop_menu


        var leaderboards:= LeaderboardMenu.new()
        leaderboards.name = "LeaderboardMenu"
        leaderboards.player = player
        leaderboards.board = rank_board
        player.leaderboards = leaderboards
        layer.add_child(leaderboards)


        map_menu = MapMenu.new()
        map_menu.name = "MapMenu"
        map_menu.player = player
        map_menu.door = bay_door


        player.bay_door = bay_door
        layer.add_child(map_menu)
        hud.map = map_menu


        zone_card = ZoneCard.new()
        zone_card.name = "ZoneCard"
        zone_card.zone = landing_zone
        layer.add_child(zone_card)


        load_panel = LoadPanel.new()
        load_panel.name = "LoadPanel"
        load_panel.player = player
        load_panel.zone = landing_zone
        load_panel.order_requested.connect(_deliver_new_pile)
        player.load_panel = load_panel
        layer.add_child(load_panel)


        needle_panel = NeedlePanel.new()
        needle_panel.name = "NeedlePanel"
        needle_panel.player = player
        needle_panel.live = live
        needle_panel.return_requested.connect(_return_loose_needles)
        player.needle_panel = needle_panel
        layer.add_child(needle_panel)


        catalog_panel = CatalogPanel.new()
        catalog_panel.name = "CatalogPanel"
        catalog_panel.player = player
        player.catalog = catalog_panel
        layer.add_child(catalog_panel)
        hud.set_catalog(catalog_panel)


        tech_panel = TechPanel.new()
        tech_panel.name = "TechPanel"
        tech_panel.player = player
        player.tech_panel = tech_panel
        layer.add_child(tech_panel)


        discovery_card = DiscoveryCard.new()
        discovery_card.name = "DiscoveryCard"
        layer.add_child(discovery_card)
        discovery.card = discovery_card


        gift_card = GiftCard.new()
        gift_card.name = "GiftCard"
        gift_card.hud_layer = layer
        var gift_layer:= CanvasLayer.new()
        gift_layer.name = "GiftLayer"
        gift_layer.layer = layer.layer + 1
        gift_layer.add_child(gift_card)
        add_child(gift_layer)
        missions.gift_card = gift_card
        catalog_panel.gift_card = gift_card

        needle_inspector = NeedleInspector.new()
        needle_inspector.name = "NeedleInspector"
        needle_inspector.player = player
        player.inspector = needle_inspector
        layer.add_child(needle_inspector)


        rake_panel = RakePanel.new()
        rake_panel.name = "RakePanel"
        rake_panel.player = player
        player.rake_panel = rake_panel
        layer.add_child(rake_panel)


        pelletizer_panel = PelletizerPanel.new()
        pelletizer_panel.name = "PelletizerPanel"
        pelletizer_panel.player = player
        player.pelletizer_panel = pelletizer_panel
        layer.add_child(pelletizer_panel)


        launcher_panel = LauncherPanel.new()
        launcher_panel.name = "LauncherPanel"
        launcher_panel.player = player
        player.launcher_panel = launcher_panel
        layer.add_child(launcher_panel)


        lamp_panel = LampPanel.new()
        lamp_panel.name = "LampPanel"
        lamp_panel.player = player
        player.lamp_panel = lamp_panel
        layer.add_child(lamp_panel)


        splitter_panel = SplitterPanel.new()
        splitter_panel.name = "SplitterPanel"
        splitter_panel.player = player
        player.splitter_panel = splitter_panel
        layer.add_child(splitter_panel)


        silo_panel = SiloPanel.new()
        silo_panel.name = "SiloPanel"
        silo_panel.player = player
        player.silo_panel = silo_panel
        layer.add_child(silo_panel)


        paint_panel = PaintPanel.new()
        paint_panel.name = "PaintPanel"
        paint_panel.player = player
        player.paint_panel = paint_panel
        layer.add_child(paint_panel)


        arm_panel = ArmPanel.new()
        arm_panel.name = "ArmPanel"
        arm_panel.player = player
        player.arm_panel = arm_panel
        layer.add_child(arm_panel)


        arm_links = ArmLinkMode.new()
        arm_links.name = "ArmLinkMode"
        arm_links.player = player
        arm_links.hint_layer = layer
        player.arm_links = arm_links
        add_child(arm_links)


        drone_panel = DronePanel.new()
        drone_panel.name = "DronePanel"
        drone_panel.player = player
        player.drone_panel = drone_panel
        layer.add_child(drone_panel)
        drone_zone = DroneZoneMode.new()
        drone_zone.name = "DroneZoneMode"
        drone_zone.player = player
        drone_zone.hint_layer = layer
        player.drone_zone = drone_zone
        add_child(drone_zone)


        machine_panel = MachinePanel.new()
        machine_panel.name = "MachinePanel"
        machine_panel.player = player
        machine_panel.hud = hud
        player.machine_panel = machine_panel
        layer.add_child(machine_panel)


        pole_panel = PolePanel.new()
        pole_panel.name = "PolePanel"
        pole_panel.player = player
        player.pole_panel = pole_panel
        layer.add_child(pole_panel)

        needle_drawer = NeedleDrawer.new()
        needle_drawer.name = "NeedleDrawer"
        needle_drawer.player = player
        player.needle_drawer = needle_drawer
        layer.add_child(needle_drawer)


        sell_all_dialog = SellAllDialog.new()
        sell_all_dialog.name = "SellAllDialog"
        sell_all_dialog.player = player
        sell_all_dialog.confirmed.connect(_take_the_yard_sale)
        layer.add_child(sell_all_dialog)
        player.sell_all_dialog = sell_all_dialog
        if delivery_board != null:
                delivery_board.clearance_pressed.connect(_open_the_yard_sale)


        demo_end_dialog = DemoEndDialog.new()
        demo_end_dialog.name = "DemoEndDialog"
        demo_end_dialog.player = player
        demo_end_dialog.save_action = save_now
        demo_end_dialog.menu_requested.connect(_leave_for_the_title)
        layer.add_child(demo_end_dialog)
        player.demo_end_dialog = demo_end_dialog


        for cab in builds.cabinets:
                _watch_for_the_ending(cab)
        builds.cabinet_added.connect(_watch_for_the_ending)
        builds.t_switched.connect(_on_t_switched)


        GameState.needle_discovered.connect(_on_discovered_for_the_demo)

        GameState.pile_emptied.connect(_on_pile_emptied)

        discovery_card.inspect_requested.connect(func(type: int) -> void:


                discovery_card.dismiss()
                needle_inspector.open(type))


        pause_menu = PauseMenu.new()
        pause_menu.name = "PauseMenu"
        pause_menu.player = player
        pause_menu.shop = shop_menu
        pause_menu.map = map_menu
        pause_menu.catalog = catalog_panel
        pause_menu.tech_panel = tech_panel
        pause_menu.hud = hud
        pause_menu.save_action = save_now
        layer.add_child(pause_menu)


        if Cfg.debug_on():
                _build_debug_menu(layer)
        else:


                var debug_unlock:= DebugUnlock.new()
                debug_unlock.name = "DebugUnlock"
                debug_unlock.unlocked.connect(_on_debug_unlocked.bind(layer))
                add_child(debug_unlock)


        if _intro_due:
                intro = IntroSequence.new()
                intro.name = "Intro"
                intro.player = player
                intro.door = bay_door
                intro.hud = hud
                intro.quests = quests
                intro.cue = mission_cue
                intro.contracts = contracts
                intro.missions = missions


                intro.shop = shop
                intro.stand = stand


                intro.field = field
                add_child(intro)
                pause_menu.intro = intro


        if bay_door != null and bay_door.countdown != null:


                bay_door.countdown.player = player
                bay_door.countdown.expired.connect(_on_countdown_expired)
                if intro != null:
                        intro.finished.connect(bay_door.countdown.arm)
                else:
                        bay_door.countdown.arm()


        belt_audio = BeltAudio.new()
        belt_audio.name = "BeltAudio"
        belt_audio.builds = builds
        belt_audio.player = player
        add_child(belt_audio)


        water_audio = WaterAudio.new()
        water_audio.name = "WaterAudio"
        water_audio.builds = builds
        water_audio.player = player
        add_child(water_audio)

        await _stage(tr("TUNING THE RADIO"), 0.98)


        Audio.ambience_start()


        if intro == null:
                Audio.music_start()
        else:


                Audio.music_stop(0.0)
                intro.finished.connect(Audio.music_start, CONNECT_ONE_SHOT)


        _build_room_probe()
        dust = DustMotes.new()
        dust.name = "DustMotes"
        add_child(dust)
        dust.fit_to(warehouse)
        warehouse.rebuilt.connect(func() -> void:
                dust.fit_to(warehouse)
                _fit_room_probe())

        Cfg.quality_changed.connect(_on_quality_changed)
        Cfg.gfx_changed.connect(_apply_render_settings)
        _apply_render_settings()


func _build_debug_menu(layer: CanvasLayer) -> void:
        debug_menu = DebugMenu.new()
        debug_menu.name = "DebugMenu"
        debug_menu.player = player

        debug_menu.world = self
        debug_menu.props = props
        debug_menu.hud = hud


        debug_menu.live = live
        debug_menu.builds = builds
        layer.add_child(debug_menu)


        needle_wallhack = NeedleWallhack.new()
        needle_wallhack.name = "NeedleWallhack"
        needle_wallhack.live = live
        needle_wallhack.player = player
        add_child(needle_wallhack)
        debug_menu.wallhack = needle_wallhack


        pause_menu.debug_menu = debug_menu


const COUNTDOWN_TEXT:= "THE CLOCK IS OUT  ·  what happens next, you find out when the game is released"


func _on_countdown_expired() -> void:
        var slot:= bay_door.countdown.slot()
        if not Cfg.DEMO or Profile.countdown_seen_in(slot):
                return
        Profile.note_countdown_seen(slot)
        if hud != null:
                hud.show_toast(tr(COUNTDOWN_TEXT), 9.0)


func _on_debug_unlocked(layer: CanvasLayer) -> void:
        Cfg.debug_unlocked = true


        InputSetup.apply()
        _build_debug_menu(layer)
        if hud != null:
                hud.show_toast(tr("DEBUG MODE ACTIVATED  ·  F1"))
        Audio.play("ui_open", -4.0)


func _run_dev_probe() -> void:
        var uargs:= OS.get_cmdline_user_args()
        if "--enclosedbelt" in uargs:
                var enclosed:= DevEnclosedBeltProbe.new()
                enclosed.world = self
                add_child(enclosed)
                enclosed.run()
                return


        if "--restoreslice" in uargs:
                var rs:= DevRestoreSliceProbe.new()
                rs.world = self
                add_child(rs)
                rs.run()
                return
        if "--stagedload" in uargs:
                var whole:= player != null and player.carry != null and player.build != null and player.hand != null and player.is_mouse_captured()
                var late:= _first_picks() if whole else ""
                var verdict:= "PASS"
                if not whole:
                        verdict = "FAIL: the player's tools are missing"
                elif not late.is_empty():
                        verdict = "FAIL: " + late
                print("\n[probe] %s" % verdict)
                get_tree().quit(0 if verdict == "PASS" else 1)
                return
        if "--density" in uargs:
                var dt:= DevDensityTest.new()
                dt.world = self
                dt.player = player
                add_child(dt)
                dt.run(int(uargs [uargs.find("--density") + 1]))
                return


        if "--cheat" in uargs:
                var cheat:= DevUnlockProbe.new()
                cheat.world = self
                add_child(cheat)
                cheat.run()
                return


        var plaza_at:= OS.get_cmdline_user_args().find("--plaza")
        if plaza_at >= 0:
                var pargs:= OS.get_cmdline_user_args()
                var pz:= DevPlazaProbe.new()
                pz.world = self
                pz.player = player
                add_child(pz)
                pz.shoot(
                        pargs [plaza_at + 1] if plaza_at + 1 < pargs.size() else DevPlazaProbe.OUT_DEFAULT,
                        float(pargs [plaza_at + 2]) if plaza_at + 2 < pargs.size()
                                else BrutalistPlaza.SCALE)
                return


        var tunnel_at:= OS.get_cmdline_user_args().find("--tunnelshot")
        if tunnel_at >= 0:
                var targs:= OS.get_cmdline_user_args()
                var ts:= DevTunnelShotProbe.new()
                ts.world = self
                ts.player = player
                add_child(ts)
                ts.shoot(targs [tunnel_at + 1] if tunnel_at + 1 < targs.size()
                        else DevTunnelShotProbe.OUT_DEFAULT)
                return


        if "--plazaudit" in OS.get_cmdline_user_args():
                var pa:= DevPlazaAuditProbe.new()
                pa.world = self
                add_child(pa)
                pa.run()
                return


        if "--plazaperf" in OS.get_cmdline_user_args():
                var pp:= DevPlazaPerfProbe.new()
                pp.world = self
                pp.player = player
                add_child(pp)
                pp.run()
                return

        if "--lookknobs" in OS.get_cmdline_user_args():
                var lk:= DevLookKnobsProbe.new()
                lk.world = self
                add_child(lk)
                lk.run()
                return

        if "--gfxreset" in OS.get_cmdline_user_args():
                var gr:= DevGfxReset.new()
                gr.world = self
                add_child(gr)
                gr.run()
                return

        if "--laptoppreset" in OS.get_cmdline_user_args():
                var lp:= DevLaptopPreset.new()
                lp.world = self
                add_child(lp)
                lp.run()
                return

        if "--transmission" in OS.get_cmdline_user_args():
                var tm:= DevTransmission.new()
                tm.world = self
                add_child(tm)
                tm.run()
                return


        var bay_shot_at:= OS.get_cmdline_user_args().find("--deliveryshot")
        if bay_shot_at >= 0:
                var ds:= DevDeliveryShotProbe.new()
                ds.world = self
                ds.player = player
                add_child(ds)
                var dargs:= OS.get_cmdline_user_args()
                ds.shoot(dargs [bay_shot_at + 1] if bay_shot_at + 1 < dargs.size()
                        else DevDeliveryShotProbe.OUT_DEFAULT)
                return

        if "--delivery" in OS.get_cmdline_user_args():
                var dl:= DevDeliveryProbe.new()
                dl.world = self
                dl.player = player
                add_child(dl)
                dl.run()
                return

        if "--stamina" in OS.get_cmdline_user_args():
                var st2:= DevStaminaProbe.new()
                st2.world = self
                st2.player = player
                add_child(st2)
                st2.run()
                return

        if "--forkload" in OS.get_cmdline_user_args():
                var fl:= DevForkLoadProbe.new()
                fl.world = self
                fl.player = player
                add_child(fl)
                fl.run()
                return

        if "--toyreach" in OS.get_cmdline_user_args():
                var tr:= DevToyReachProbe.new()
                tr.world = self
                tr.player = player
                add_child(tr)
                tr.run()
                return

        if "--bladepick" in OS.get_cmdline_user_args():
                var bp:= DevBladePickProbe.new()
                bp.world = self
                bp.player = player
                add_child(bp)
                bp.run()
                return

        if "--forkaim" in OS.get_cmdline_user_args():
                var fa:= DevForkAimProbe.new()
                fa.world = self
                fa.player = player
                add_child(fa)
                fa.run()
                return

        if "--scoopbench" in OS.get_cmdline_user_args():
                var sb:= DevScoopBench.new()
                sb.world = self
                sb.player = player
                add_child(sb)
                sb.run()
                return


        var shot_at:= OS.get_cmdline_user_args().find("--hotbarshot")
        if shot_at >= 0:
                var hs:= DevHotbarProbe.new()
                hs.world = self
                hs.player = player
                hs.catalog = catalog_panel
                add_child(hs)
                var args:= OS.get_cmdline_user_args()
                hs.shoot(args [shot_at + 1] if shot_at + 1 < args.size() else "user://")
                return

        if "--hotbar" in OS.get_cmdline_user_args():
                var hb:= DevHotbarProbe.new()
                hb.world = self
                hb.player = player
                hb.catalog = catalog_panel
                add_child(hb)
                hb.run()
                return

        var disc_at:= OS.get_cmdline_user_args().find("--discoveryshot")
        if disc_at >= 0:
                var ds:= DevDiscoveryProbe.new()
                ds.world = self
                ds.builds = builds
                ds.player = player
                ds.card = discovery_card
                ds.inspector = needle_inspector
                add_child(ds)
                var disc_args:= OS.get_cmdline_user_args()
                ds.shoot(disc_args [disc_at + 1] if disc_at + 1 < disc_args.size() else "user://")
                return

        if "--discovery" in OS.get_cmdline_user_args():
                var dp:= DevDiscoveryProbe.new()
                dp.world = self
                dp.builds = builds
                dp.player = player
                dp.card = discovery_card
                dp.inspector = needle_inspector
                add_child(dp)
                dp.run()
                return


        var case_at:= OS.get_cmdline_user_args().find("--cabinetshot")
        if case_at >= 0:
                var cs:= DevCabinetProbe.new()
                cs.world = self
                cs.builds = builds
                cs.player = player
                add_child(cs)
                var case_args:= OS.get_cmdline_user_args()
                cs.shoot(case_args [case_at + 1] if case_at + 1 < case_args.size() else "user://")
                return


        var demo_at:= OS.get_cmdline_user_args().find("--democardshot")
        if demo_at >= 0:
                var dcs:= DevCabinetProbe.new()
                dcs.world = self
                dcs.builds = builds
                dcs.player = player
                add_child(dcs)
                var demo_args:= OS.get_cmdline_user_args()
                dcs.shoot_card(
                        demo_args [demo_at + 1] if demo_at + 1 < demo_args.size() else "user://")
                return

        var end_at:= OS.get_cmdline_user_args().find("--endingshot")
        if end_at >= 0:
                var es:= DevCabinetProbe.new()
                es.world = self
                es.builds = builds
                es.player = player
                add_child(es)
                var end_args:= OS.get_cmdline_user_args()
                es.shoot_ending(
                        end_args [end_at + 1] if end_at + 1 < end_args.size() else "user://")
                return

        if "--radar" in OS.get_cmdline_user_args():
                var rp:= DevRadarProbe.new()
                rp.world = self
                add_child(rp)
                rp.run()
                return

        if "--cabinet" in OS.get_cmdline_user_args():
                var cp:= DevCabinetProbe.new()
                cp.world = self
                add_child(cp)
                cp.run()
                return

        if "--needlepin" in OS.get_cmdline_user_args():
                var pin:= DevNeedlePinProbe.new()
                pin.world = self
                add_child(pin)
                pin.run()
                return

        if "--needles" in OS.get_cmdline_user_args():
                var np:= DevNeedleTypesProbe.new()
                np.world = self
                add_child(np)
                np.run()
                return

        if "--specimens" in OS.get_cmdline_user_args():
                var sp:= DevSpecimenProbe.new()
                add_child(sp)
                sp.run()
                return


        var det_at:= OS.get_cmdline_user_args().find("--detectorshot")
        if det_at >= 0:
                var dsp:= DevDetectorShotProbe.new()
                dsp.world = self
                dsp.player = player
                add_child(dsp)
                var detargs:= OS.get_cmdline_user_args()
                dsp.shoot(detargs [det_at + 1] if det_at + 1 < detargs.size() else "user://")
                return


        var dig_at:= OS.get_cmdline_user_args().find("--digshot")
        if dig_at >= 0:
                var ds:= DevDigShotProbe.new()
                ds.world = self
                ds.player = player
                ds.props = props
                ds.field = field
                add_child(ds)
                var dargs:= OS.get_cmdline_user_args()
                ds.shoot(dargs [dig_at + 1] if dig_at + 1 < dargs.size() else "user://")
                return


        var swing_at:= OS.get_cmdline_user_args().find("--digswing")
        if swing_at >= 0:
                var sw:= DevDigSwingProbe.new()
                sw.world = self
                sw.player = player
                sw.field = field
                add_child(sw)
                var swargs:= OS.get_cmdline_user_args()
                sw.shoot(swargs [swing_at + 1] if swing_at + 1 < swargs.size() else "user://")
                return


        if "--throw" in OS.get_cmdline_user_args():
                var tp:= DevThrowProbe.new()
                tp.world = self
                tp.player = player
                tp.field = field
                tp.live = live
                add_child(tp)
                tp.run()
                return

        if "--simple" in OS.get_cmdline_user_args():
                var sp:= DevSimpleProbe.new()
                sp.world = self
                sp.player = player
                sp.field = field
                sp.live = live
                add_child(sp)
                sp.run()
                return

        if "--dig" in OS.get_cmdline_user_args():
                var dp:= DevDigProbe.new()
                dp.world = self
                dp.player = player
                dp.props = props
                dp.field = field
                add_child(dp)
                dp.run()
                return

        if "--stubble" in OS.get_cmdline_user_args():
                var st:= DevStubbleProbe.new()
                st.world = self
                st.player = player
                st.field = field
                add_child(st)
                st.run()
                return

        if "--sell" in OS.get_cmdline_user_args():
                var sp:= DevSellProbe.new()
                sp.world = self
                sp.stand = stand
                sp.props = props
                sp.live = live
                add_child(sp)
                sp.run()
                return

        if "--throwcost" in OS.get_cmdline_user_args():
                var tc:= DevThrowCostProbe.new()
                tc.world = self
                tc.stand = stand
                tc.props = props
                tc.live = live
                tc.player = player
                add_child(tc)
                tc.run()
                return

        var salefx_at:= OS.get_cmdline_user_args().find("--salefx")
        if salefx_at >= 0:
                var sf:= DevSaleFxProbe.new()
                sf.world = self
                sf.stand = stand
                sf.props = props
                sf.live = live
                sf.player = player
                var sfargs:= OS.get_cmdline_user_args()
                if salefx_at + 1 < sfargs.size() and not sfargs [salefx_at + 1].begins_with("--"):
                        sf.out_dir = sfargs [salefx_at + 1]
                add_child(sf)
                sf.run()
                return

        if "--coins" in OS.get_cmdline_user_args():
                var cp:= DevCoinProbe.new()
                cp.world = self
                cp.stand = stand
                cp.props = props
                cp.player = player
                add_child(cp)
                cp.run()
                return


        var card_at:= OS.get_cmdline_user_args().find("--mapcard")
        if card_at >= 0:
                var mc:= DevDoorProbe.new()
                mc.world = self
                mc.player = player
                mc.hud = hud
                mc.quests = quests
                add_child(mc)
                var card_args:= OS.get_cmdline_user_args()
                mc.shoot_card(card_args [card_at + 1] if card_at + 1 < card_args.size() else "user://")
                return


        var door_at:= OS.get_cmdline_user_args().find("--doorshot")
        if door_at >= 0:
                var dsh:= DevDoorProbe.new()
                dsh.world = self
                dsh.player = player
                dsh.warehouse = warehouse
                dsh.door = bay_door
                dsh.map = map_menu
                add_child(dsh)
                var door_args:= OS.get_cmdline_user_args()
                dsh.shoot(door_args [door_at + 1] if door_at + 1 < door_args.size() else "user://")
                return


        var intro_at:= OS.get_cmdline_user_args().find("--introshot")
        if intro_at >= 0 and intro != null:
                var ish:= DevIntroProbe.new()
                ish.world = self
                ish.player = player
                ish.door = bay_door
                ish.warehouse = warehouse
                ish.intro = intro
                add_child(ish)
                var ish_args:= OS.get_cmdline_user_args()
                ish.shoot(ish_args [intro_at + 1] if intro_at + 1 < ish_args.size() else "user://")
                return


        if "--intro" in OS.get_cmdline_user_args() and intro != null:
                var ip:= DevIntroProbe.new()
                ip.world = self
                ip.player = player
                ip.door = bay_door
                ip.warehouse = warehouse
                ip.intro = intro
                add_child(ip)
                ip.run()
                return


        if "--yardbake" in OS.get_cmdline_user_args():
                var yb:= DevYardBake.new()
                add_child(yb)
                yb.run("--force" in OS.get_cmdline_user_args())
                return


        var yard_at:= OS.get_cmdline_user_args().find("--yardshot")
        if yard_at >= 0:
                var ysh:= DevYardProbe.new()
                ysh.world = self
                ysh.player = player
                ysh.warehouse = warehouse
                ysh.door = bay_door
                ysh.terrain = terrain
                add_child(ysh)
                var yard_args:= OS.get_cmdline_user_args()
                ysh.shoot(yard_args [yard_at + 1] if yard_at + 1 < yard_args.size() else "user://")
                return


        var fence_at:= OS.get_cmdline_user_args().find("--fenceshot")
        if fence_at >= 0:
                var fsh:= DevFenceProbe.new()
                fsh.world = self
                fsh.player = player
                fsh.warehouse = warehouse
                add_child(fsh)
                var fargs:= OS.get_cmdline_user_args()
                fsh.shoot(fargs [fence_at + 1] if fence_at + 1 < fargs.size() else "user://")
                return

        if "--yardref" in OS.get_cmdline_user_args():
                var yr:= DevYardReference.new()
                yr.world = self
                yr.warehouse = warehouse
                add_child(yr)
                yr.run()
                return

        if "--fence" in OS.get_cmdline_user_args():
                var fp:= DevFenceProbe.new()
                fp.world = self
                fp.warehouse = warehouse
                fp.player = player
                add_child(fp)
                fp.run()
                return

        if "--wheat" in OS.get_cmdline_user_args():
                var wp:= DevWheatProbe.new()
                wp.world = self
                wp.warehouse = warehouse
                wp.terrain = terrain
                add_child(wp)
                wp.run()
                return

        if "--yard" in OS.get_cmdline_user_args():
                var yp:= DevYardProbe.new()
                yp.world = self
                yp.player = player
                yp.warehouse = warehouse
                yp.door = bay_door
                yp.terrain = terrain
                add_child(yp)
                yp.run()
                return


        var ledger_at:= OS.get_cmdline_user_args().find("--ledgershot")
        if ledger_at >= 0:
                var ls:= DevSignProbe.new()
                ls.world = self
                ls.player = player
                ls.warehouse = warehouse
                add_child(ls)
                var ledger_args:= OS.get_cmdline_user_args()
                ls.shoot(ledger_args [ledger_at + 1] if ledger_at + 1 < ledger_args.size() else "user://")
                return

        if "--sign" in OS.get_cmdline_user_args():
                var sg:= DevSignProbe.new()
                sg.world = self
                sg.player = player
                sg.warehouse = warehouse
                sg.door = bay_door
                add_child(sg)
                sg.run()
                return

        if "--door" in OS.get_cmdline_user_args():
                var dr:= DevDoorProbe.new()
                dr.warehouse = warehouse
                dr.door = bay_door
                dr.map = map_menu


                dr.hud = hud


                dr.player = player
                add_child(dr)
                dr.run()
                return

        if "--tech" in OS.get_cmdline_user_args():
                var tp:= DevTechProbe.new()
                tp.warehouse = warehouse
                add_child(tp)
                tp.run()
                return

        if "--cards" in OS.get_cmdline_user_args():
                var cp:= DevCardProbe.new()
                add_child(cp)
                cp.run()
                return

        if "--handful" in OS.get_cmdline_user_args():
                var hp:= DevHandfulProbe.new()
                hp.player = player
                hp.live = live
                add_child(hp)
                hp.run()
                return

        if "--economy" in OS.get_cmdline_user_args():
                var ep:= DevEconomyProbe.new()
                add_child(ep)
                ep.run()
                return

        if "--standwalk" in OS.get_cmdline_user_args():
                var sw: Node = load("res://scripts/dev/stand_walk_probe.gd").new()
                add_child(sw)
                sw.run()
                return


        var belt_at:= OS.get_cmdline_user_args().find("--beltshot")
        if belt_at >= 0:
                var bs:= DevBeltShotProbe.new()
                bs.world = self
                bs.player = player
                add_child(bs)
                var bargs:= OS.get_cmdline_user_args()
                bs.shoot(bargs [belt_at + 1] if belt_at + 1 < bargs.size() else "user://")
                return


        var lod_at:= OS.get_cmdline_user_args().find("--lodshot")
        if lod_at >= 0:
                var ls:= DevLodShotProbe.new()
                ls.world = self
                ls.player = player
                add_child(ls)
                var largs:= OS.get_cmdline_user_args()
                ls.shoot(largs [lod_at + 1] if lod_at + 1 < largs.size() else "user://")
                return


        var join_at:= OS.get_cmdline_user_args().find("--beltjoinshot")
        if join_at >= 0:
                var js:= DevBeltJoinShotProbe.new()
                js.world = self
                js.player = player
                add_child(js)
                var jargs:= OS.get_cmdline_user_args()
                js.shoot(jargs [join_at + 1] if join_at + 1 < jargs.size() else "user://")
                return


        var split_at:= OS.get_cmdline_user_args().find("--splitjoinshot")
        if split_at >= 0:
                var ss:= DevSplitJoinShotProbe.new()
                ss.world = self
                ss.player = player
                add_child(ss)
                var sargs:= OS.get_cmdline_user_args()
                ss.shoot(sargs [split_at + 1] if split_at + 1 < sargs.size() else "user://")
                return


        var rail_at:= OS.get_cmdline_user_args().find("--railshot")
        if rail_at >= 0:
                var rs:= DevRailShotProbe.new()
                rs.world = self
                rs.player = player
                add_child(rs)
                var rargs:= OS.get_cmdline_user_args()
                rs.shoot(rargs [rail_at + 1] if rail_at + 1 < rargs.size() else "user://")
                return


        var rake_shot_at:= OS.get_cmdline_user_args().find("--rakeshot")
        if rake_shot_at >= 0:
                var ks:= DevRakeSmokeShotProbe.new()
                ks.world = self
                ks.player = player
                add_child(ks)
                var kargs:= OS.get_cmdline_user_args()
                ks.shoot(kargs [rake_shot_at + 1] if rake_shot_at + 1 < kargs.size() else "user://")
                return


        var arm_load_shot_at:= OS.get_cmdline_user_args().find("--armloadshot")
        if arm_load_shot_at >= 0:
                var alsp:= DevArmLoadShotProbe.new()
                alsp.world = self
                alsp.player = player
                add_child(alsp)
                var alargs:= OS.get_cmdline_user_args()
                alsp.shoot(alargs [arm_load_shot_at + 1] if arm_load_shot_at + 1 < alargs.size()
                        else "user://")
                return

        var coin_shot_at:= OS.get_cmdline_user_args().find("--coinshot")
        if coin_shot_at >= 0:
                var csp:= DevCoinShotProbe.new()
                csp.world = self
                csp.player = player
                csp.stand = stand
                add_child(csp)
                var cargs:= OS.get_cmdline_user_args()
                csp.shoot(cargs [coin_shot_at + 1] if coin_shot_at + 1 < cargs.size() else "user://")
                return

        var payout_shot_at:= OS.get_cmdline_user_args().find("--payoutshot")
        if payout_shot_at >= 0:
                var psp:= DevPayoutShotProbe.new()
                psp.world = self
                psp.player = player
                psp.stand = stand
                add_child(psp)
                var pargs:= OS.get_cmdline_user_args()
                psp.shoot(pargs [payout_shot_at + 1] if payout_shot_at + 1 < pargs.size() else "user://")
                return

        var radar_shot_at:= OS.get_cmdline_user_args().find("--radarshot")
        if radar_shot_at >= 0:
                var rsp:= DevRadarShotProbe.new()
                rsp.world = self
                rsp.player = player
                add_child(rsp)
                var rargs:= OS.get_cmdline_user_args()
                rsp.shoot(rargs [radar_shot_at + 1] if radar_shot_at + 1 < rargs.size() else "user://")
                return

        var alert_shot_at:= OS.get_cmdline_user_args().find("--alertshot")
        if alert_shot_at >= 0:
                var asp:= DevAlertShotProbe.new()
                asp.world = self
                asp.player = player
                add_child(asp)
                var aargs:= OS.get_cmdline_user_args()
                asp.shoot(aargs [alert_shot_at + 1] if alert_shot_at + 1 < aargs.size() else "user://")
                return


        var cue_shot_at:= OS.get_cmdline_user_args().find("--cueshot")
        if cue_shot_at >= 0:
                var cs:= DevCueShotProbe.new()
                cs.world = self
                cs.player = player
                add_child(cs)
                var cargs:= OS.get_cmdline_user_args()
                cs.shoot(cargs [cue_shot_at + 1] if cue_shot_at + 1 < cargs.size() else "user://")
                return

        var gun_shot_at:= OS.get_cmdline_user_args().find("--launchershot")
        if gun_shot_at >= 0:
                var gs:= DevLauncherShotProbe.new()
                if gs == null:
                        push_error("--launchershot: DevLauncherShotProbe did not compile")
                        get_tree().quit(1)
                        return
                gs.world = self
                gs.player = player
                add_child(gs)
                var gargs:= OS.get_cmdline_user_args()
                gs.shoot(gargs [gun_shot_at + 1] if gun_shot_at + 1 < gargs.size() else "user://")
                return

        var build_fx_at:= OS.get_cmdline_user_args().find("--buildfx")
        if build_fx_at >= 0:
                var bf:= DevBuildFxProbe.new()
                bf.world = self
                bf.player = player
                add_child(bf)
                var bfargs:= OS.get_cmdline_user_args()
                var bf_out:= ""
                if build_fx_at + 1 < bfargs.size() and not bfargs [build_fx_at + 1].begins_with("--"):
                        bf_out = bfargs [build_fx_at + 1]
                bf.run(bf_out)
                return

        var gen_ghost_at:= OS.get_cmdline_user_args().find("--genghost")
        if gen_ghost_at >= 0:
                var gg:= DevGenGhostShotProbe.new()
                gg.world = self
                gg.player = player
                add_child(gg)
                var ggargs:= OS.get_cmdline_user_args()
                gg.shoot(ggargs [gen_ghost_at + 1] if gen_ghost_at + 1 < ggargs.size() else "user://")
                return

        var pile_at:= OS.get_cmdline_user_args().find("--pileshot")
        if pile_at >= 0:
                var ps:= DevPileShotProbe.new()
                ps.world = self
                ps.player = player
                add_child(ps)
                var pargs:= OS.get_cmdline_user_args()
                var pout: String = pargs [pile_at + 1] if pile_at + 1 < pargs.size() else "user://"


                ps.shoot("user://" if pout.begins_with("--") else pout)
                return

        var stand_at:= OS.get_cmdline_user_args().find("--standshot")
        if stand_at >= 0:
                var st: Node = load("res://scripts/dev/stand_shot_probe.gd").new()
                st.world = self
                st.player = player
                add_child(st)
                var targs:= OS.get_cmdline_user_args()
                st.shoot(targs [stand_at + 1] if stand_at + 1 < targs.size() else "user://")
                return

        var shed_at:= OS.get_cmdline_user_args().find("--shedshot")
        if shed_at >= 0:
                var ss:= DevShedShotProbe.new()
                ss.world = self
                ss.player = player
                add_child(ss)
                var sargs:= OS.get_cmdline_user_args()
                ss.shoot(sargs [shed_at + 1] if shed_at + 1 < sargs.size() else "user://")
                return

        var bw_at:= OS.get_cmdline_user_args().find("--boothwalk")
        if bw_at >= 0:
                var bw:= DevBoothWalkProbe.new()
                bw.world = self
                bw.player = player
                add_child(bw)


                var bwargs:= OS.get_cmdline_user_args()
                if bw_at + 1 < bwargs.size() and not bwargs [bw_at + 1].begins_with("--"):
                        bw.shots = bwargs [bw_at + 1]
                bw.run()
                return

        var sack_at:= OS.get_cmdline_user_args().find("--sackshot")
        if sack_at >= 0:
                var kp:= DevSackShotProbe.new()
                kp.world = self
                kp.player = player
                add_child(kp)
                var kargs:= OS.get_cmdline_user_args()
                var kout: String = kargs [sack_at + 1] if sack_at + 1 < kargs.size() else "user://"


                if "--film" in kargs:
                        kp.film(kout)
                else:
                        kp.shoot(kout)
                return

        var vacshot_at:= OS.get_cmdline_user_args().find("--yardvacshot")
        if vacshot_at >= 0:
                var vs:= DevYardVacShotProbe.new()
                vs.world = self
                vs.player = player
                add_child(vs)
                var vargs:= OS.get_cmdline_user_args()
                vs.shoot(vargs [vacshot_at + 1] if vacshot_at + 1 < vargs.size() else "user://")
                return

        var lightershot_at:= OS.get_cmdline_user_args().find("--lightershot")
        if lightershot_at >= 0:
                var ls:= DevLighterShotProbe.new()
                ls.world = self
                ls.player = player
                add_child(ls)
                var largs:= OS.get_cmdline_user_args()
                ls.shoot(largs [lightershot_at + 1] if lightershot_at + 1 < largs.size() else "user://")
                return

        var jetshot_at:= OS.get_cmdline_user_args().find("--jetpackshot")
        if jetshot_at >= 0:
                var js:= DevJetpackShotProbe.new()
                js.world = self
                js.player = player
                add_child(js)
                var jargs:= OS.get_cmdline_user_args()
                js.shoot(jargs [jetshot_at + 1] if jetshot_at + 1 < jargs.size() else "user://")
                return

        var drawer_at:= OS.get_cmdline_user_args().find("--drawershot")
        if drawer_at >= 0:
                var ds:= DevDrawerShotProbe.new()
                ds.world = self
                ds.player = player
                ds.panel = needle_drawer
                add_child(ds)
                var dargs:= OS.get_cmdline_user_args()
                ds.shoot(dargs [drawer_at + 1] if drawer_at + 1 < dargs.size() else "user://")
                return

        if "--drawerhitch" in OS.get_cmdline_user_args():
                var dh:= DevDrawerHitchProbe.new()
                dh.world = self
                dh.player = player
                dh.panel = needle_drawer
                add_child(dh)
                dh.run()
                return

        var tech_at:= OS.get_cmdline_user_args().find("--techshot")
        if tech_at >= 0:
                var ts:= DevTechShotProbe.new()
                ts.world = self
                ts.player = player
                ts.panel = tech_panel
                add_child(ts)
                var targs:= OS.get_cmdline_user_args()
                var tout: String = targs [tech_at + 1] if tech_at + 1 < targs.size() else "user://"


                if "--surge" in targs:
                        ts.shoot_surge(tout)
                elif "--search" in targs:
                        ts.shoot_search(tout)
                elif "--ring" in targs:
                        ts.shoot_ring(tout)
                else:
                        ts.shoot(tout)
                return


        var shop_at:= OS.get_cmdline_user_args().find("--shopshot")
        if shop_at >= 0:
                var ss:= DevShopProbe.new()
                ss.world = self
                ss.player = player
                add_child(ss)
                var sargs:= OS.get_cmdline_user_args()
                ss.shoot(sargs [shop_at + 1] if shop_at + 1 < sargs.size() else "user://")
                return


        var clearance_at:= OS.get_cmdline_user_args().find("--clearanceshot")
        if clearance_at >= 0:
                var cs:= DevClearanceShotProbe.new()
                cs.world = self
                cs.player = player
                add_child(cs)
                var cargs:= OS.get_cmdline_user_args()
                cs.shoot(cargs [clearance_at + 1] if clearance_at + 1 < cargs.size() else "user://")
                return

        if "--sellup" in OS.get_cmdline_user_args():
                var sa:= DevSellAllProbe.new()
                sa.world = self
                sa.player = player
                add_child(sa)
                sa.run()
                return

        if "--boardauth" in OS.get_cmdline_user_args():
                var ba:= DevBoardAuthProbe.new()
                ba.world = self
                ba.player = player
                add_child(ba)
                ba.run()
                return

        if "--firstneedle" in OS.get_cmdline_user_args():
                var fn:= DevFirstNeedleProbe.new()
                fn.world = self
                add_child(fn)
                fn.run()
                return

        if "--pileclear" in OS.get_cmdline_user_args():
                var pile_clear_probe:= DevPileClearProbe.new()
                pile_clear_probe.world = self
                pile_clear_probe.player = player
                add_child(pile_clear_probe)
                pile_clear_probe.run()
                return

        if "--boardperiods" in OS.get_cmdline_user_args():
                var period_probe:= DevBoardPeriodProbe.new()
                period_probe.world = self
                period_probe.player = player
                add_child(period_probe)
                period_probe.run()
                return


        var board_at:= OS.get_cmdline_user_args().find("--shopboardshot")
        if board_at >= 0:
                var bs:= DevShopBoardProbe.new()
                bs.world = self
                bs.player = player
                add_child(bs)
                var bargs:= OS.get_cmdline_user_args()
                bs.shoot(bargs [board_at + 1] if board_at + 1 < bargs.size() else "user://")
                return

        if "--shopboard" in OS.get_cmdline_user_args():
                var bp:= DevShopBoardProbe.new()
                bp.world = self
                bp.player = player
                add_child(bp)
                bp.run()
                return

        if "--shop" in OS.get_cmdline_user_args():
                var sp:= DevShopProbe.new()
                sp.world = self
                sp.player = player
                add_child(sp)
                sp.run()
                return

        if "--decay" in OS.get_cmdline_user_args():
                var dk:= DevDecayProbe.new()
                dk.world = self
                dk.player = player
                add_child(dk)
                dk.run()
                return

        if "--props" in OS.get_cmdline_user_args():
                var pp:= DevPropProbe.new()
                pp.world = self
                pp.player = player
                add_child(pp)
                pp.run()
                return

        if "--toolthrow" in OS.get_cmdline_user_args():
                var tt:= DevToolThrowProbe.new()
                tt.world = self
                tt.player = player
                add_child(tt)
                tt.run()
                return


        if "--beltaudit" in OS.get_cmdline_user_args():
                var ba:= DevBeltAudit.new()
                ba.world = self
                ba.player = player
                add_child(ba)
                ba.run()
                return


        var clip_at:= OS.get_cmdline_user_args().find("--clip")
        if clip_at >= 0:
                var cp:= DevClipProbe.new()
                cp.world = self
                cp.player = player
                add_child(cp)
                var cargs:= OS.get_cmdline_user_args()
                cp.run(cargs [clip_at + 1] if clip_at + 1 < cargs.size() else "")
                return

        var markershot_at:= OS.get_cmdline_user_args().find("--markershot")
        if markershot_at >= 0:
                var ms:= DevMarkerShotProbe.new()
                ms.world = self
                ms.player = player
                var marker_args:= OS.get_cmdline_user_args()
                ms.out_dir = marker_args [markershot_at + 1] if markershot_at + 1 < marker_args.size() else OS.get_user_data_dir().path_join("markershot")
                add_child(ms)
                ms.run()
                return

        var giftshot_at:= OS.get_cmdline_user_args().find("--giftshot")
        if giftshot_at >= 0:
                var gs:= DevGiftShotProbe.new()
                gs.world = self
                var shot_args:= OS.get_cmdline_user_args()
                gs.out_dir = shot_args [giftshot_at + 1] if giftshot_at + 1 < shot_args.size() else OS.get_user_data_dir().path_join("giftshot")
                add_child(gs)
                gs.run()
                return

        if "--gifts" in OS.get_cmdline_user_args():
                var gp:= DevGiftsProbe.new()
                gp.world = self
                gp.player = player
                add_child(gp)
                gp.run()
                return

        if "--missions" in OS.get_cmdline_user_args():
                var mp:= DevMissionsProbe.new()
                mp.world = self
                mp.player = player
                add_child(mp)
                mp.run()
                return

        var plead_at:= OS.get_cmdline_user_args().find("--plead")
        if plead_at >= 0:
                var pp:= DevPleadProbe.new()
                pp.world = self
                pp.player = player
                add_child(pp)
                var pargs:= OS.get_cmdline_user_args()
                pp.run(pargs [plead_at + 1] if plead_at + 1 < pargs.size() else "")
                return

        if "--nudge" in OS.get_cmdline_user_args():
                var np:= DevNudgeProbe.new()
                np.world = self
                np.player = player
                add_child(np)
                np.run()
                return

        if "--stackpick" in OS.get_cmdline_user_args():
                var sp:= DevStackPickProbe.new()
                sp.world = self
                sp.player = player
                add_child(sp)
                sp.run()
                return

        if "--armload" in OS.get_cmdline_user_args():
                var al:= DevArmLoadProbe.new()
                al.world = self
                al.player = player
                add_child(al)
                al.run()
                return

        if "--carry" in OS.get_cmdline_user_args():
                var cp:= DevCarryProbe.new()
                cp.world = self
                cp.player = player
                add_child(cp)
                cp.run()
                return

        if "--impact" in OS.get_cmdline_user_args():
                var ip:= DevImpactProbe.new()
                ip.world = self
                ip.player = player
                add_child(ip)
                ip.run()
                return

        if "--upright" in OS.get_cmdline_user_args():
                var up:= DevUprightProbe.new()
                up.world = self
                up.player = player
                add_child(up)
                up.run()
                return

        if "--bucketfork" in OS.get_cmdline_user_args():
                var bf:= DevBucketForkProbe.new()
                bf.world = self
                bf.player = player
                add_child(bf)
                bf.run()
                return

        if "--fallenfill" in OS.get_cmdline_user_args():
                var ff:= DevFallenFillProbe.new()
                ff.world = self
                ff.player = player
                add_child(ff)
                ff.run()
                return

        if "--tools" in OS.get_cmdline_user_args():
                var tp:= DevToolsProbe.new()
                tp.world = self
                tp.player = player
                add_child(tp)
                tp.run()
                return

        if "--powerline" in OS.get_cmdline_user_args():
                var pl:= DevPowerlineProbe.new()
                pl.world = self
                pl.player = player
                add_child(pl)
                pl.run()
                return

        if "--dumphatch" in OS.get_cmdline_user_args():
                var dh:= DevDumpHatchProbe.new()
                dh.world = self
                dh.player = player
                add_child(dh)
                dh.run()
                return

        if "--bucketdump" in OS.get_cmdline_user_args():
                var bd:= DevBucketDumpProbe.new()
                bd.world = self
                bd.player = player
                add_child(bd)
                bd.run()
                return

        if "--heapshot" in OS.get_cmdline_user_args():
                var hs:= DevHeapShotProbe.new()
                hs.world = self
                hs.player = player
                add_child(hs)
                var ua3:= OS.get_cmdline_user_args()
                var heap_dir:= "user://heapshots"
                var hi:= ua3.find("--heapshot")
                if hi >= 0 and hi + 1 < ua3.size() and not ua3 [hi + 1].begins_with("--"):
                        heap_dir = ua3 [hi + 1]
                hs.shoot(heap_dir)
                return

        if "--heap" in OS.get_cmdline_user_args():
                var hp:= DevHeapProbe.new()
                hp.world = self
                hp.player = player
                add_child(hp)
                hp.run()
                return

        if "--beltdrum" in OS.get_cmdline_user_args():
                var bd:= DevBeltDrumProbe.new()
                bd.world = self
                bd.player = player
                add_child(bd)
                bd.run()
                return

        if "--beltfan" in OS.get_cmdline_user_args():
                var bf:= DevBeltFanProbe.new()
                bf.world = self
                bf.player = player
                add_child(bf)
                bf.run()
                return

        if "--throwbelt" in OS.get_cmdline_user_args():
                var tb:= DevThrowBeltProbe.new()
                tb.world = self
                tb.player = player
                add_child(tb)
                tb.run()
                return

        if "--jointcost" in OS.get_cmdline_user_args():
                var jc:= DevJointCostProbe.new()
                jc.world = self
                jc.player = player
                add_child(jc)
                jc.run()
                return

        if "--beltrun" in OS.get_cmdline_user_args():
                var br:= DevBeltRunProbe.new()
                br.world = self
                br.player = player
                add_child(br)
                br.run()
                return

        if "--beltload" in OS.get_cmdline_user_args():
                var bl:= DevBeltLoadProbe.new()
                bl.world = self
                bl.player = player
                add_child(bl)
                bl.run()
                return

        if "--factoryfull" in OS.get_cmdline_user_args():
                var ff:= DevFactoryFullProbe.new()
                ff.world = self
                ff.player = player
                add_child(ff)
                ff.run()
                return

        if "--beltqueue" in OS.get_cmdline_user_args():
                var bq:= DevBeltQueueProbe.new()
                bq.world = self
                bq.player = player
                add_child(bq)
                bq.run()
                return

        if "--beltjam" in OS.get_cmdline_user_args():
                var bj:= DevBeltJamProbe.new()
                bj.world = self
                bj.player = player
                add_child(bj)
                bj.run()
                return

        if "--queuebounce" in OS.get_cmdline_user_args():
                var qb:= DevQueueBounceProbe.new()
                qb.world = self
                qb.player = player
                add_child(qb)
                qb.run()
                return

        if "--pourpace" in OS.get_cmdline_user_args():
                var pp:= DevPourPaceProbe.new()
                pp.world = self
                pp.player = player
                add_child(pp)
                pp.run()
                return

        if "--throwstand" in OS.get_cmdline_user_args():
                var ts:= DevThrowStandProbe.new()
                ts.world = self
                ts.player = player
                add_child(ts)
                ts.run()
                return

        if "--vacpour" in OS.get_cmdline_user_args():
                var vp:= DevVacPourProbe.new()
                vp.world = self
                vp.player = player
                add_child(vp)
                vp.run()
                return

        if "--beltdrain" in OS.get_cmdline_user_args():
                var bd:= DevBeltDrainProbe.new()
                bd.world = self
                bd.player = player
                add_child(bd)
                bd.run()
                return

        if "--beltcap" in OS.get_cmdline_user_args():
                var bc:= DevBeltCapProbe.new()
                bc.world = self
                bc.player = player
                add_child(bc)
                bc.run()
                return

        if "--smoothcam" in OS.get_cmdline_user_args():
                var scp:= DevSmoothCamProbe.new()
                scp.world = self
                scp.player = player
                add_child(scp)
                scp.run()
                return

        if "--wall" in OS.get_cmdline_user_args():
                var wp:= DevWallProbe.new()
                wp.world = self
                wp.player = player
                add_child(wp)
                wp.run()
                return

        if "--stair" in OS.get_cmdline_user_args():
                var sp:= DevStairProbe.new()
                sp.world = self
                sp.player = player
                add_child(sp)
                sp.run()
                return

        var stand_shot:= OS.get_cmdline_user_args().find("--standjoinshot")
        if stand_shot >= 0 or "--standjoin" in OS.get_cmdline_user_args():
                var sj:= DevStandJoinProbe.new()
                sj.world = self
                sj.player = player
                sj.props = props
                sj.live = live
                add_child(sj)
                if stand_shot >= 0:
                        var sargs:= OS.get_cmdline_user_args()
                        sj.shoot(sargs [stand_shot + 1] if stand_shot + 1 < sargs.size() else "user://")
                else:
                        sj.run()
                return

        if "--beltroute" in OS.get_cmdline_user_args():
                var brp:= DevBeltRouteProbe.new()
                brp.world = self
                brp.player = player
                add_child(brp)
                brp.run()
                return

        if "--beltthrough" in OS.get_cmdline_user_args():
                var btp:= DevBeltThroughProbe.new()
                btp.world = self
                btp.player = player
                add_child(btp)
                btp.run()
                return

        if "--beltpile" in OS.get_cmdline_user_args():
                var bpp:= DevBeltPileProbe.new()
                bpp.world = self
                bpp.player = player
                add_child(bpp)
                bpp.run()
                return

        if "--proppool" in OS.get_cmdline_user_args():
                var pp:= DevPropPoolProbe.new()
                pp.world = self
                pp.player = player
                add_child(pp)
                pp.run()
                return

        if "--seamwatch" in OS.get_cmdline_user_args():
                var sw:= DevSeamWatchProbe.new()
                sw.world = self
                sw.player = player
                add_child(sw)
                sw.run()
                return

        if "--seamfall" in OS.get_cmdline_user_args():
                var sf:= DevSeamFallProbe.new()
                sf.world = self
                sf.player = player
                add_child(sf)
                sf.run()
                return

        if "--belt" in OS.get_cmdline_user_args():
                var bp:= DevBeltProbe.new()
                bp.world = self
                bp.player = player
                add_child(bp)
                bp.run()
                return

        if "--ride" in OS.get_cmdline_user_args():
                var rp:= DevRideProbe.new()
                rp.world = self
                rp.player = player
                add_child(rp)
                rp.run()
                return

        var order_shot_at:= OS.get_cmdline_user_args().find("--ordershot")
        if order_shot_at >= 0:
                var os_probe:= DevOrderNoteShotProbe.new()
                os_probe.world = self
                os_probe.player = player
                add_child(os_probe)
                var oargs:= OS.get_cmdline_user_args()
                os_probe.shoot(oargs [order_shot_at + 1] if order_shot_at + 1 < oargs.size() else "user://")
                return

        if "--pileorder" in OS.get_cmdline_user_args():
                var po:= DevPileOrderProbe.new()
                po.world = self
                po.player = player
                add_child(po)
                po.run()
                return

        if "--demolot" in OS.get_cmdline_user_args():
                var dl:= DevDemoLotProbe.new()
                dl.world = self
                add_child(dl)
                dl.run()
                return

        if "--landingzone" in OS.get_cmdline_user_args():
                var lz:= DevLandingZoneProbe.new()
                lz.world = self
                lz.player = player
                add_child(lz)
                lz.run()
                return

        if "--needlepanel" in OS.get_cmdline_user_args():
                var np:= DevNeedlePanelProbe.new()
                np.world = self
                np.player = player
                add_child(np)
                np.run()
                return

        if "--needleloss" in OS.get_cmdline_user_args():
                var nl:= DevNeedleLossProbe.new()
                nl.world = self
                add_child(nl)
                nl.run()
                return

        if "--needleroute" in OS.get_cmdline_user_args():
                var nr:= DevNeedleRouteProbe.new()
                nr.world = self
                add_child(nr)
                nr.run()
                return

        if "--keep" in OS.get_cmdline_user_args():
                var kp:= DevKeepProbe.new()
                kp.world = self
                kp.player = player
                add_child(kp)
                kp.run()
                return

        var settle_shot_at:= OS.get_cmdline_user_args().find("--settleshot")
        if settle_shot_at >= 0:
                var ss:= DevSettleProbe.new()
                ss.world = self
                ss.player = player
                add_child(ss)
                var sargs:= OS.get_cmdline_user_args()
                ss.shoot(sargs [settle_shot_at + 1] if settle_shot_at + 1 < sargs.size() else "user://")
                return

        if "--tubload" in OS.get_cmdline_user_args():
                var tl:= DevTubLoadProbe.new()
                tl.world = self
                tl.player = player
                add_child(tl)
                tl.run()
                return

        if "--strandcull" in OS.get_cmdline_user_args():
                var scp:= DevStrandCullProbe.new()
                scp.world = self
                scp.player = player
                add_child(scp)
                scp.run()
                return

        if "--forkbelt" in OS.get_cmdline_user_args():
                var fbp:= DevForkBeltProbe.new()
                fbp.world = self
                fbp.player = player
                add_child(fbp)
                fbp.run()
                return

        if "--beltstuck" in OS.get_cmdline_user_args():
                var bsp:= DevBeltStuckProbe.new()
                bsp.world = self
                bsp.player = player
                add_child(bsp)
                bsp.run()
                return


        if "--settle" in OS.get_cmdline_user_args():
                var sp:= DevSettleProbe.new()
                sp.world = self
                sp.player = player
                add_child(sp)
                sp.run()
                return

        if "--launchland" in OS.get_cmdline_user_args():
                var ll: Node = load("res://scripts/dev/launch_land_probe.gd").new()
                ll.set("world", self)
                add_child(ll)
                ll.call("run")
                return

        if "--expose" in OS.get_cmdline_user_args():
                var xp:= DevExposeProbe.new()
                xp.world = self
                xp.player = player
                add_child(xp)
                xp.run()
                return

        if "--detector" in OS.get_cmdline_user_args():
                var dt:= DevDetectorProbe.new()
                dt.world = self
                dt.player = player
                add_child(dt)
                dt.run()
                return

        if "--broomtest" in OS.get_cmdline_user_args():
                var bm:= DevBroomProbe.new()
                bm.world = self
                bm.player = player
                add_child(bm)
                bm.run()
                return

        if "--yardvac" in OS.get_cmdline_user_args():
                var yv:= DevYardVacProbe.new()
                yv.world = self
                yv.player = player
                add_child(yv)
                yv.run()
                return

        if "--grippyboots" in OS.get_cmdline_user_args():
                var gb:= DevGrippyBootsProbe.new()
                gb.world = self
                gb.player = player
                add_child(gb)
                gb.run()
                return

        if "--jetpack" in OS.get_cmdline_user_args():
                var jp:= DevJetpackProbe.new()
                jp.world = self
                jp.player = player
                add_child(jp)
                jp.run()
                return

        if "--lighter" in OS.get_cmdline_user_args():
                var lp:= DevLighterProbe.new()
                lp.world = self
                lp.player = player
                add_child(lp)
                lp.run()
                return

        if "--showoverlay" in OS.get_cmdline_user_args():
                var sov:= DevShowOverlayProbe.new()
                sov.world = self
                add_child(sov)
                sov.run()
                return

        if "--noclip" in OS.get_cmdline_user_args():
                var ncp:= DevNoclipProbe.new()
                ncp.world = self
                add_child(ncp)
                ncp.run()
                return

        if "--input" in OS.get_cmdline_user_args():
                var ip:= DevInputProbe.new()
                ip.world = self
                add_child(ip)
                ip.run()
                return

        if "--crouch" in OS.get_cmdline_user_args():
                var cp:= DevCrouchProbe.new()
                cp.world = self
                add_child(cp)
                cp.run()
                return

        if "--scanner" in OS.get_cmdline_user_args():
                var sp:= DevScannerProbe.new()
                sp.world = self
                sp.player = player
                add_child(sp)
                sp.run()
                return

        if "--rip" in OS.get_cmdline_user_args():
                var rp:= DevRipProbe.new()
                rp.world = self
                rp.player = player
                add_child(rp)
                rp.run()
                return

        if "--wad" in OS.get_cmdline_user_args():
                var wp:= DevWadProbe.new()
                wp.world = self
                wp.player = player
                add_child(wp)
                wp.run()
                return

        if "--drone" in OS.get_cmdline_user_args():
                var dp:= DevDroneProbe.new()
                dp.world = self
                dp.player = player
                add_child(dp)
                dp.run()
                return

        if "--armkeepout" in OS.get_cmdline_user_args():
                var kp:= DevArmKeepOutProbe.new()
                kp.world = self
                add_child(kp)
                kp.run()
                return

        var armshot_at:= OS.get_cmdline_user_args().find("--armshot")
        if armshot_at >= 0:
                var asp:= DevArmShotProbe.new()
                asp.world = self
                asp.player = player
                add_child(asp)
                var aargs:= OS.get_cmdline_user_args()
                asp.shoot(aargs [armshot_at + 1] if armshot_at + 1 < aargs.size() else "user://")
                return

        var postshot_at:= OS.get_cmdline_user_args().find("--postshot")
        if postshot_at >= 0:
                var cps:= DevChargePostShotProbe.new()
                cps.world = self
                cps.player = player
                add_child(cps)
                var pargs:= OS.get_cmdline_user_args()
                cps.shoot(pargs [postshot_at + 1] if postshot_at + 1 < pargs.size() else "user://")
                return

        var droneshot_at:= OS.get_cmdline_user_args().find("--droneshot")
        if droneshot_at >= 0:
                var dsp:= DevDroneShotProbe.new()
                dsp.world = self
                dsp.player = player
                add_child(dsp)
                var dargs:= OS.get_cmdline_user_args()
                dsp.shoot(dargs [droneshot_at + 1] if droneshot_at + 1 < dargs.size() else "user://")
                return

        if "--reachpeek" in OS.get_cmdline_user_args():
                var rp:= DevReachPeekProbe.new()
                rp.world = self
                rp.player = player
                add_child(rp)
                rp.run()
                return

        if "--fleet" in OS.get_cmdline_user_args():
                var df:= DevFleetProbe.new()
                df.world = self
                df.player = player
                add_child(df)
                df.run()
                return

        if "--dronefleet" in OS.get_cmdline_user_args():
                var dfp:= DevDroneFleetProbe.new()
                dfp.world = self
                dfp.player = player
                add_child(dfp)
                dfp.run()
                return

        if "--dronescale" in OS.get_cmdline_user_args():
                var dsp:= DevDroneScaleProbe.new()
                dsp.world = self
                dsp.player = player
                add_child(dsp)
                dsp.run()
                return

        if "--dronepath" in OS.get_cmdline_user_args():
                var dpp:= DevDronePathProbe.new()
                dpp.world = self
                dpp.player = player
                add_child(dpp)
                dpp.run()
                return

        if "--dronewatch" in OS.get_cmdline_user_args():
                var dw:= DevDroneWatch.new()
                dw.world = self
                dw.player = player
                add_child(dw)
                dw.run()
                return

        if "--launcher" in OS.get_cmdline_user_args():


                var lnp:= DevLauncherProbe.new()
                if lnp == null:
                        push_error("--launcher: DevLauncherProbe did not compile")
                        get_tree().quit(1)
                        return
                lnp.world = self
                lnp.player = player
                add_child(lnp)
                lnp.run()
                return

        if "--brick" in OS.get_cmdline_user_args():
                var bkp:= DevBrickProbe.new()
                bkp.world = self
                bkp.player = player
                add_child(bkp)
                bkp.run()
                return

        if "--pelletland" in OS.get_cmdline_user_args():
                var plp:= DevPelletLandProbe.new()
                plp.world = self
                plp.player = player
                add_child(plp)
                plp.run()
                return

        if "--wyedeck" in OS.get_cmdline_user_args():
                var wdp:= DevWyeDeckProbe.new()
                wdp.world = self
                wdp.player = player
                add_child(wdp)
                wdp.run()
                return

        if "--gridsnap" in OS.get_cmdline_user_args():
                var gsp:= DevGridProbe.new()
                gsp.world = self
                gsp.player = player
                add_child(gsp)
                gsp.run()
                return

        if "--storey" in OS.get_cmdline_user_args():
                var stp:= DevStoreyProbe.new()
                stp.world = self
                stp.player = player
                add_child(stp)
                stp.run()
                return

        if "--nosnap" in OS.get_cmdline_user_args():
                var nsp:= DevNoSnapProbe.new()
                nsp.world = self
                nsp.player = player
                add_child(nsp)
                nsp.run()
                return

        if "--rake" in OS.get_cmdline_user_args():
                var rkp:= DevRakeProbe.new()
                rkp.world = self
                rkp.player = player
                add_child(rkp)
                rkp.run()
                return

        if "--stairs" in OS.get_cmdline_user_args():
                var stp:= DevStairsProbe.new()
                stp.world = self
                stp.player = player
                add_child(stp)
                stp.run()
                return

        if "--alerts" in OS.get_cmdline_user_args():
                var ap:= DevAlertProbe.new()
                ap.world = self
                ap.player = player
                add_child(ap)
                ap.run()
                return

        if "--compressor" in OS.get_cmdline_user_args():
                var cop:= DevCompressorProbe.new()
                cop.world = self
                cop.player = player
                add_child(cop)
                cop.run()
                return

        if "--wrapper" in OS.get_cmdline_user_args():
                var wrp:= DevWrapperProbe.new()
                wrp.world = self
                wrp.player = player
                add_child(wrp)
                wrp.run()
                return

        if "--silo" in OS.get_cmdline_user_args():
                var slo:= DevSiloProbe.new()
                slo.world = self
                slo.player = player
                add_child(slo)
                slo.run()
                return

        if "--siloperf" in OS.get_cmdline_user_args():
                var sp:= DevSiloPerfProbe.new()
                sp.world = self
                sp.player = player
                add_child(sp)
                sp.run()
                return

        if "--gen" in OS.get_cmdline_user_args():
                var gen:= DevGeneratorProbe.new()
                gen.world = self
                gen.player = player
                add_child(gen)
                gen.run()
                return

        if "--gasplant" in OS.get_cmdline_user_args():
                var gp:= DevGasPlantProbe.new()
                gp.world = self
                gp.player = player
                add_child(gp)
                gp.run()
                return

        if "--genwye" in OS.get_cmdline_user_args():
                var gwy:= DevGenWyeProbe.new()
                gwy.world = self
                gwy.player = player
                add_child(gwy)
                gwy.run()
                return

        if "--crossclash" in OS.get_cmdline_user_args():
                var ccp:= DevCrossClashProbe.new()
                ccp.world = self
                ccp.player = player
                add_child(ccp)
                ccp.run()
                return

        if "--gentarm" in OS.get_cmdline_user_args():
                var gta:= DevGenTArmProbe.new()
                gta.world = self
                gta.player = player
                add_child(gta)
                gta.run()
                return

        if "--machineseat" in OS.get_cmdline_user_args():
                var seat:= DevMachineSeatProbe.new()
                seat.world = self
                seat.player = player
                add_child(seat)
                seat.run()
                return

        if "--power" in OS.get_cmdline_user_args():
                var pwr:= DevPowerProbe.new()
                pwr.world = self
                pwr.player = player
                add_child(pwr)
                pwr.run()
                return

        if "--borehole" in OS.get_cmdline_user_args():
                var well:= DevBoreholeProbe.new()
                well.world = self
                well.player = player
                add_child(well)
                well.run()
                return

        if "--pipe" in OS.get_cmdline_user_args():
                var pipe:= DevPipeProbe.new()
                pipe.world = self
                pipe.player = player
                add_child(pipe)
                pipe.run()
                return

        if "--water" in OS.get_cmdline_user_args():
                var net:= DevWaterProbe.new()
                net.world = self
                net.player = player
                add_child(net)
                net.run()
                return

        var pump_at:= OS.get_cmdline_user_args().find("--pumpshot")
        if pump_at >= 0:
                var pmp:= DevPumpShotProbe.new()
                pmp.world = self
                pmp.player = player
                add_child(pmp)
                var margs:= OS.get_cmdline_user_args()
                pmp.shoot(margs [pump_at + 1] if pump_at + 1 < margs.size() else "user://")
                return

        var pipeshot_at:= OS.get_cmdline_user_args().find("--pipeshot")
        if pipeshot_at >= 0:
                var pps:= DevPipeShotProbe.new()
                pps.world = self
                pps.player = player
                add_child(pps)
                var ppargs:= OS.get_cmdline_user_args()
                pps.shoot(ppargs [pipeshot_at + 1] if pipeshot_at + 1 < ppargs.size() else "user://")
                return

        var pumpghost_at:= OS.get_cmdline_user_args().find("--pumpghost")
        if pumpghost_at >= 0:
                var pg:= DevPumpGhostProbe.new()
                pg.world = self
                pg.player = player
                add_child(pg)
                var pgargs:= OS.get_cmdline_user_args()
                pg.shoot(pgargs [pumpghost_at + 1] if pumpghost_at + 1 < pgargs.size() else "user://")
                return

        var papershot_at:= OS.get_cmdline_user_args().find("--papershot")
        if papershot_at >= 0:
                var psh:= DevPaperShotProbe.new()
                psh.world = self
                psh.player = player
                add_child(psh)
                var shargs:= OS.get_cmdline_user_args()
                psh.shoot(shargs [papershot_at + 1] if papershot_at + 1 < shargs.size()
                        else "user://")
                return

        var shred_at:= OS.get_cmdline_user_args().find("--shredshot")
        if shred_at >= 0:
                var ssh:= DevShredShotProbe.new()
                ssh.world = self
                ssh.player = player
                add_child(ssh)
                var sargs:= OS.get_cmdline_user_args()
                ssh.shoot(sargs [shred_at + 1] if shred_at + 1 < sargs.size()
                        else "user://")
                return

        var pshot_at:= OS.get_cmdline_user_args().find("--pulpershot")
        if pshot_at >= 0:
                var psp:= DevPulperShotProbe.new()
                psp.world = self
                psp.player = player
                add_child(psp)
                var pargs:= OS.get_cmdline_user_args()
                psp.shoot(pargs [pshot_at + 1] if pshot_at + 1 < pargs.size() else "user://")
                return

        var plook_at:= OS.get_cmdline_user_args().find("--pulperlook")
        if plook_at >= 0:
                var plp:= DevPulperLookProbe.new()
                plp.world = self
                plp.player = player
                add_child(plp)
                var largs:= OS.get_cmdline_user_args()
                plp.shoot(largs [plook_at + 1] if plook_at + 1 < largs.size() else "user://")
                return

        if "--pulper" in OS.get_cmdline_user_args():
                var pulper:= DevPulperProbe.new()
                pulper.world = self
                pulper.player = player
                add_child(pulper)
                pulper.run()
                return

        if "--paper" in OS.get_cmdline_user_args():
                var paper:= DevPaperProbe.new()
                paper.world = self
                paper.player = player
                add_child(paper)
                paper.run()
                return

        var briqshot_at:= OS.get_cmdline_user_args().find("--briquetteshot")
        if briqshot_at >= 0:
                var bsh:= DevBriquetteShotProbe.new()
                bsh.world = self
                bsh.player = player
                add_child(bsh)
                var bargs:= OS.get_cmdline_user_args()
                bsh.shoot(bargs [briqshot_at + 1] if briqshot_at + 1 < bargs.size()
                        else "user://")
                return

        var briqwire_at:= OS.get_cmdline_user_args().find("--briquettewireshot")
        if briqwire_at >= 0:
                var bws:= DevBriquetteWireShotProbe.new()
                bws.world = self
                bws.player = player
                add_child(bws)
                var wargs:= OS.get_cmdline_user_args()
                bws.shoot(wargs [briqwire_at + 1] if briqwire_at + 1 < wargs.size()
                        else "user://")
                return

        if "--briquette" in OS.get_cmdline_user_args():
                var briq:= DevBriquetteProbe.new()
                briq.world = self
                briq.player = player
                add_child(briq)
                briq.run()
                return

        if "--jam" in OS.get_cmdline_user_args():
                var jam:= DevJamProbe.new()
                jam.world = self
                jam.player = player
                add_child(jam)
                jam.run()
                return

        if "--loc" in OS.get_cmdline_user_args():
                var loc:= DevLocProbe.new()
                loc.world = self
                loc.player = player
                add_child(loc)
                loc.run()
                return

        var crash_at:= OS.get_cmdline_user_args().find("--dismantlecrash")
        if crash_at >= 0:
                var dc:= DevDismantleCrashProbe.new()
                dc.world = self
                dc.player = player
                add_child(dc)
                var dcargs:= OS.get_cmdline_user_args()
                var dc_rounds:= 5
                var dc_copy:= ""
                if crash_at + 1 < dcargs.size() and dcargs [crash_at + 1].is_valid_int():
                        dc_rounds = int(dcargs [crash_at + 1])
                elif crash_at + 1 < dcargs.size() and not dcargs [crash_at + 1].begins_with("--"):
                        dc_copy = dcargs [crash_at + 1]
                dc.run(dc_rounds, dc_copy)
                return

        if "--haylift" in OS.get_cmdline_user_args():
                var haylift:= DevHayLiftProbe.new()
                haylift.world = self
                haylift.player = player
                add_child(haylift)
                haylift.run()
                return

        if "--pulpcorner" in OS.get_cmdline_user_args():
                var bend:= DevPulpCornerProbe.new()
                bend.world = self
                bend.player = player
                add_child(bend)
                bend.run()
                return

        if "--box" in OS.get_cmdline_user_args():
                var box:= DevBoxProbe.new()
                box.world = self
                box.player = player
                add_child(box)
                box.run()
                return

        if "--roof" in OS.get_cmdline_user_args():
                var rf:= DevRoofProbe.new()
                rf.world = self
                rf.player = player
                add_child(rf)
                rf.run()
                return

        if "--paintpanelshot" in OS.get_cmdline_user_args():
                var pps:= DevPaintPanelShot.new()
                pps.world = self
                pps.player = player
                add_child(pps)
                pps.run()
                return

        if "--paintboard" in OS.get_cmdline_user_args():
                var pb:= DevPaintProbe.new()
                pb.world = self
                pb.player = player
                add_child(pb)
                pb.run()
                return


        var slab_perf_at:= OS.get_cmdline_user_args().find("--slabperf")
        if slab_perf_at >= 0:
                var spp:= DevSlabPerfProbe.new()
                spp.world = self
                spp.player = player
                add_child(spp)
                var sargs:= OS.get_cmdline_user_args()
                var slab_count:= 1000
                if slab_perf_at + 1 < sargs.size() and sargs [slab_perf_at + 1].is_valid_int():
                        slab_count = sargs [slab_perf_at + 1].to_int()
                spp.run(slab_count)
                return


        if "--lampshot" in OS.get_cmdline_user_args():
                var ls:= DevLampShotProbe.new()
                ls.world = self
                ls.player = player
                add_child(ls)
                var lsdir:= DevLampShotProbe.OUT_DIR
                for a: String in OS.get_cmdline_user_args():
                        if a != "--lampshot" and not a.begins_with("--"):
                                lsdir = a
                ls.shoot(lsdir)
                return

        if "--poleshot" in OS.get_cmdline_user_args():
                var ps:= DevPoleShotProbe.new()
                ps.world = self
                ps.player = player
                add_child(ps)
                var psdir:= DevPoleShotProbe.OUT_DIR
                for a: String in OS.get_cmdline_user_args():
                        if a != "--poleshot" and not a.begins_with("--"):
                                psdir = a
                ps.shoot(psdir)
                return

        if "--genpanelshot" in OS.get_cmdline_user_args():
                var gps:= DevGenPanelShotProbe.new()
                gps.world = self
                gps.player = player
                add_child(gps)
                var gpsdir:= DevGenPanelShotProbe.OUT_DIR
                for a: String in OS.get_cmdline_user_args():
                        if a != "--genpanelshot" and not a.begins_with("--"):
                                gpsdir = a
                gps.shoot(gpsdir)
                return

        if "--worklamp" in OS.get_cmdline_user_args():
                var wl:= DevWorkLampProbe.new()
                wl.world = self
                wl.player = player
                add_child(wl)
                wl.run()
                return

        if "--console" in OS.get_cmdline_user_args():
                var cn:= DevConsoleProbe.new()
                cn.world = self
                cn.player = player
                add_child(cn)
                cn.run()
                return

        if "--wyefull" in OS.get_cmdline_user_args():
                var wf:= DevWyeFullProbe.new()
                wf.world = self
                wf.player = player
                add_child(wf)
                wf.run()
                return

        if "--wyepacked" in OS.get_cmdline_user_args():
                var wp:= DevWyePackedProbe.new()
                wp.world = self
                wp.player = player
                add_child(wp)
                wp.run()
                return

        if "--wyechain" in OS.get_cmdline_user_args():
                var wc:= DevWyeChainProbe.new()
                wc.world = self
                wc.player = player
                add_child(wc)
                wc.run()
                return

        if "--splitter" in OS.get_cmdline_user_args():
                var lp:= DevSplitterProbe.new()
                lp.world = self
                lp.player = player
                add_child(lp)
                lp.run()
                return

        if "--splitterflow" in OS.get_cmdline_user_args():
                var flow_probe:= DevSplitterFlowProbe.new()
                flow_probe.world = self
                flow_probe.player = player
                add_child(flow_probe)
                var flow_args:= OS.get_cmdline_user_args()
                var flow_at:= flow_args.find("--splitterflow")
                flow_probe.run(flow_args [flow_at + 1] if flow_at + 1 < flow_args.size() else "")
                return

        if "--splittercost" in OS.get_cmdline_user_args():
                var cost_probe:= DevSplitterCostProbe.new()
                cost_probe.world = self
                cost_probe.player = player
                add_child(cost_probe)
                cost_probe.run()
                return

        if "--beltfoot" in OS.get_cmdline_user_args():
                var belt_foot:= DevBeltFootProbe.new()
                belt_foot.world = self
                add_child(belt_foot)
                belt_foot.run()
                return

        if "--poleblock" in OS.get_cmdline_user_args():
                var pole_block:= DevPoleBlockProbe.new()
                pole_block.world = self
                add_child(pole_block)
                pole_block.run()
                return

        if "--compactsplitter" in OS.get_cmdline_user_args():
                var compact_probe:= DevCompactSplitterProbe.new()
                compact_probe.world = self
                add_child(compact_probe)
                compact_probe.run()
                return


        var wreck_at:= OS.get_cmdline_user_args().find("--dismantleshot")
        if wreck_at >= 0:
                var ds2:= DevDismantleProbe.new()
                ds2.world = self
                ds2.player = player
                add_child(ds2)
                var wreck_args:= OS.get_cmdline_user_args()
                ds2.shoot(wreck_args [wreck_at + 1] if wreck_at + 1 < wreck_args.size() else "user://")
                return

        if "--dismantle" in OS.get_cmdline_user_args():
                var dm:= DevDismantleProbe.new()
                dm.world = self
                dm.player = player
                add_child(dm)
                dm.run()
                return

        if "--beltreverse" in OS.get_cmdline_user_args():
                var br:= DevBeltReverseProbe.new()
                br.world = self
                br.player = player
                add_child(br)
                br.run()
                return

        if "--rail" in OS.get_cmdline_user_args():
                var rp:= DevRailProbe.new()
                rp.world = self
                rp.player = player
                add_child(rp)
                rp.run()
                return

        if "--wyejam" in OS.get_cmdline_user_args():
                var wj:= DevWyeProbe.new()
                wj.world = self
                wj.player = player
                add_child(wj)
                wj.run()
                return
        if "--yardwatch" in OS.get_cmdline_user_args():
                var yw:= DevYardWatchProbe.new()
                yw.world = self
                yw.player = player
                add_child(yw)
                yw.run()
                return
        if "--seamaudit" in OS.get_cmdline_user_args():
                var sa:= DevSeamAuditProbe.new()
                sa.world = self
                sa.player = player
                add_child(sa)
                sa.run()
                return
        if "--beltfuzz" in OS.get_cmdline_user_args():
                var bf:= DevBeltFuzzProbe.new()
                bf.world = self
                bf.player = player
                add_child(bf)
                bf.run()
                return

        if "--brickjump" in OS.get_cmdline_user_args():
                var bj:= DevBrickJumpProbe.new()
                bj.world = self
                bj.player = player
                add_child(bj)
                bj.run()
                return
        if "--selltime" in OS.get_cmdline_user_args():
                var st:= DevSellTimeProbe.new()
                st.world = self
                st.player = player
                add_child(st)
                st.run()
                return
        if "--beltwhy" in OS.get_cmdline_user_args():
                var bw:= DevBeltWhyProbe.new()
                bw.world = self
                bw.player = player
                add_child(bw)
                bw.run()
                return
        if "--pipehitch" in OS.get_cmdline_user_args():
                var ph:= DevPipeHitchProbe.new()
                ph.world = self
                ph.player = player
                add_child(ph)
                ph.run()
                return
        if "--buildhitch" in OS.get_cmdline_user_args():
                var bh:= DevBuildHitchProbe.new()
                bh.world = self
                bh.player = player
                add_child(bh)
                bh.run()
                return
        if "--eyesmooth" in OS.get_cmdline_user_args():
                var es:= DevEyeSmoothProbe.new()
                es.world = self
                es.player = player
                add_child(es)
                es.run()
                return
        if "--yardperf" in OS.get_cmdline_user_args():
                var yp:= DevYardPerfProbe.new()
                yp.world = self
                yp.player = player
                add_child(yp)
                yp.run()
                return
        if "--zonestall" in OS.get_cmdline_user_args():
                var zs:= DevZoneStallProbe.new()
                zs.world = self
                zs.player = player
                add_child(zs)
                zs.run()
                return
        if "--physfloor" in OS.get_cmdline_user_args():
                var pf:= DevPhysicsFloorProbe.new()
                pf.world = self
                pf.player = player
                add_child(pf)
                pf.run()
                return
        if "--yarddig" in OS.get_cmdline_user_args():
                var yd:= DevYardDigProbe.new()
                yd.world = self
                yd.player = player
                yd.field = field
                add_child(yd)
                yd.run()
                return
        if "--farblob" in OS.get_cmdline_user_args():
                var fb:= DevFarBlobProbe.new()
                fb.world = self
                fb.player = player
                add_child(fb)
                fb.run()
                return
        if "--blobrepro" in OS.get_cmdline_user_args():
                var br:= DevBlobReproProbe.new()
                br.world = self
                br.player = player
                add_child(br)
                br.run()
                return

        if "--joiner" in OS.get_cmdline_user_args():
                var jp:= DevJoinerProbe.new()
                jp.world = self
                jp.player = player
                add_child(jp)
                jp.run()
                return

        if "--wyemate" in OS.get_cmdline_user_args():
                var wm:= DevWyeMateProbe.new()
                wm.world = self
                wm.player = player
                add_child(wm)
                wm.run()
                return

        if "--wyeshot" in OS.get_cmdline_user_args():
                var ws:= DevWyeShotProbe.new()
                ws.world = self
                ws.player = player
                add_child(ws)
                ws.run()
                return

        if "--wyelegshot" in OS.get_cmdline_user_args():
                var wl:= DevWyeLegShotProbe.new()
                wl.world = self
                add_child(wl)
                wl.run()
                return

        if "--tsplitter" in OS.get_cmdline_user_args():
                var ts:= DevTSplitterProbe.new()
                ts.world = self
                ts.player = player
                add_child(ts)
                ts.run()
                return

        if "--splitrate" in OS.get_cmdline_user_args():
                var sr:= DevSplitterRateProbe.new()
                sr.world = self
                sr.player = player
                add_child(sr)
                sr.run()
                return

        if "--smartsort" in OS.get_cmdline_user_args() or "--smartoverflow" in OS.get_cmdline_user_args():
                var ss:= DevSmartSortProbe.new()
                ss.world = self
                ss.player = player
                add_child(ss)
                ss.run()
                return

        if "--tsplittershot" in OS.get_cmdline_user_args():
                var tss:= DevTSplitterShotProbe.new()
                tss.world = self
                tss.player = player
                add_child(tss)
                tss.run()
                return

        if "--gridports" in OS.get_cmdline_user_args():
                var gp:= DevGridPortsProbe.new()
                gp.world = self
                gp.player = player
                add_child(gp)
                gp.run()
                return

        if "--floorhatch" in OS.get_cmdline_user_args():
                var fh:= DevFloorHatchProbe.new()
                fh.world = self
                fh.player = player
                add_child(fh)
                fh.run()
                return

        if "--boltedports" in OS.get_cmdline_user_args():
                var bp:= DevBoltedPortsProbe.new()
                bp.world = self
                bp.player = player
                add_child(bp)
                bp.run()
                return

        if "--usplitter" in OS.get_cmdline_user_args():
                var us:= DevUSplitterProbe.new()
                us.world = self
                us.player = player
                add_child(us)
                us.run()
                return

        if "--ujoiner" in OS.get_cmdline_user_args():
                var uj:= DevUJoinerProbe.new()
                uj.world = self
                uj.player = player
                add_child(uj)
                uj.run()
                return

        if "--uwyemate" in OS.get_cmdline_user_args():
                var um:= DevUWyeMateProbe.new()
                um.world = self
                um.player = player
                add_child(um)
                um.run()
                return

        if "--uwyeshot" in OS.get_cmdline_user_args():
                var ush:= DevUWyeShotProbe.new()
                ush.world = self
                add_child(ush)
                ush.run()
                return

        if "--ledgerdrift" in OS.get_cmdline_user_args():
                var ld:= DevLedgerDriftProbe.new()
                ld.world = self
                ld.player = player
                add_child(ld)
                ld.run()
                return

        if "--arm" in OS.get_cmdline_user_args():
                var ap:= DevRobotArmProbe.new()
                ap.world = self
                add_child(ap)
                ap.run()
                return

        if "--retier" in OS.get_cmdline_user_args():
                var rt:= DevRetierProbe.new()
                rt.world = self
                add_child(rt)
                rt.run()
                return

        if "--armmodels" in OS.get_cmdline_user_args():
                var am:= DevArmModelsProbe.new()
                am.world = self
                am.player = player
                add_child(am)
                am.run()
                return

        if "--cabledeck" in OS.get_cmdline_user_args():
                var cd:= DevCableDeckProbe.new()
                cd.world = self
                add_child(cd)
                cd.run()
                return

        if "--armheadroom" in OS.get_cmdline_user_args():
                var ah:= DevArmHeadroomProbe.new()
                ah.world = self
                ah.player = player
                add_child(ah)
                ah.run()
                return

        if "--armrelink" in OS.get_cmdline_user_args():
                var rl:= DevArmRelinkProbe.new()
                rl.world = self
                add_child(rl)
                rl.run()
                return

        if "--armjam" in OS.get_cmdline_user_args():
                var aj:= DevArmJamProbe.new()
                aj.world = self
                add_child(aj)
                aj.run()
                return

        if "--armstarve" in OS.get_cmdline_user_args():
                var ast:= DevArmStarveProbe.new()
                ast.world = self
                add_child(ast)
                ast.run()
                return

        if "--armblock" in OS.get_cmdline_user_args():
                var ab:= DevArmBlockProbe.new()
                ab.world = self
                add_child(ab)
                ab.run()
                return

        if "--armwatch" in OS.get_cmdline_user_args():
                var aw:= DevArmWatchProbe.new()
                aw.world = self
                add_child(aw)
                aw.run()
                return

        if "--ccdcost" in OS.get_cmdline_user_args():
                var cc:= DevCcdCostProbe.new()
                cc.world = self
                add_child(cc)
                cc.run()
                return

        if "--armsays" in OS.get_cmdline_user_args():
                var asy:= DevArmSaysProbe.new()
                asy.world = self
                add_child(asy)
                asy.run()
                return

        if "--armstale" in OS.get_cmdline_user_args():
                var asd:= DevArmStaleDropProbe.new()
                asd.world = self
                add_child(asd)
                asd.run()
                return

        if "--armgap" in OS.get_cmdline_user_args():
                var ag:= DevArmGapProbe.new()
                ag.world = self
                add_child(ag)
                ag.run()
                return

        if "--armreload" in OS.get_cmdline_user_args():
                var ar:= DevArmReloadProbe.new()
                ar.world = self
                add_child(ar)
                ar.run()
                return

        if "--armfeed" in OS.get_cmdline_user_args():
                var af:= DevArmFeedProbe.new()
                af.world = self
                add_child(af)
                af.run()
                return

        if "--armpanelshot" in OS.get_cmdline_user_args():
                var aps:= DevArmPanelShot.new()
                aps.world = self
                add_child(aps)
                aps.run()
                return

        if "--silopanelshot" in OS.get_cmdline_user_args():
                var sps:= DevSiloPanelShot.new()
                sps.world = self
                add_child(sps)
                sps.run()
                return

        if "--splitterpanelshot" in OS.get_cmdline_user_args():
                var spls:= DevSplitterPanelShot.new()
                spls.world = self
                add_child(spls)
                spls.run()
                return

        if "--barrowapart" in OS.get_cmdline_user_args():
                var ba:= DevBarrowApartProbe.new()
                ba.world = self
                add_child(ba)
                ba.run()
                return

        if "--barrowpile" in OS.get_cmdline_user_args():
                var bp:= DevBarrowPileProbe.new()
                bp.world = self
                add_child(bp)
                bp.run()
                return

        if "--armpick" in OS.get_cmdline_user_args():
                var ap:= DevArmPickProbe.new()
                ap.world = self
                add_child(ap)
                ap.run()
                return

        if "--armlinks" in OS.get_cmdline_user_args():
                var alp:= DevArmLinksProbe.new()
                alp.world = self
                add_child(alp)
                alp.run()
                return

        if "--armoverflow" in OS.get_cmdline_user_args():
                var aop:= DevArmOverflowProbe.new()
                aop.world = self
                add_child(aop)
                aop.run()
                return

        if "--armorder" in OS.get_cmdline_user_args():
                var aor:= DevArmOrderProbe.new()
                aor.world = self
                add_child(aor)
                aor.run()
                return

        if "--armneedle" in OS.get_cmdline_user_args():
                var an:= DevArmNeedleProbe.new()
                an.world = self
                add_child(an)
                an.run()
                return

        if "--avalanche" in OS.get_cmdline_user_args() or "--avalanche-shot" in OS.get_cmdline_user_args():
                var av:= DevAvalancheProbe.new()
                av.world = self
                var avalanche_args:= OS.get_cmdline_user_args()
                var avalanche_shot_at:= avalanche_args.find("--avalanche-shot")
                if avalanche_shot_at >= 0:
                        av.shot_path = (avalanche_args [avalanche_shot_at + 1]
                                if avalanche_shot_at + 1 < avalanche_args.size()
                                else "user://avalanche_particles.png")
                add_child(av)
                av.run()
                return

        if "--stress" in OS.get_cmdline_user_args():
                var st:= DevStress.new()
                st.world = self
                add_child(st)
                st.run()
                return

        if "--bench" in OS.get_cmdline_user_args():
                var b:= DevBench.new()
                b.world = self
                add_child(b)
                b.run()
                return

        if "--lookexport" in OS.get_cmdline_user_args():
                var lx:= DevLookExport.new()
                lx.world = self
                add_child(lx)
                lx.run()
                return

        if "--gpu" in OS.get_cmdline_user_args():
                var gp:= DevGpuProbe.new()
                gp.world = self
                gp.player = player
                add_child(gp)
                gp.run()
                return

        if "--diag" in OS.get_cmdline_user_args():
                var diag:= load("res://scripts/dev/diag.gd")
                diag.dump(field)
                diag.dump_dig_bite(field)
                diag.dump_dig_probe(field)
                get_tree().quit()
                return


        if "--crustcheck" in OS.get_cmdline_user_args():
                var cc:= DevCrustProbe.new()
                cc.world = self
                cc.player = player
                add_child(cc)
                cc.run()
                return


        if "--crustheal" in OS.get_cmdline_user_args():
                var ch:= DevCrustHealProbe.new()
                ch.world = self
                ch.player = player
                ch.field = field
                add_child(ch)
                ch.run()
                return


        if "--shellblame" in OS.get_cmdline_user_args():
                var sb:= DevShellBlameProbe.new()
                sb.world = self
                sb.player = player
                sb.field = field
                add_child(sb)
                sb.run()
                return


        if "--presetsweep" in OS.get_cmdline_user_args():
                var ps:= DevPresetSweepProbe.new()
                ps.world = self
                ps.player = player
                ps.field = field
                add_child(ps)
                ps.run()
                return


        if "--gpucost" in OS.get_cmdline_user_args():
                var gc:= DevGpuCostProbe.new()
                gc.world = self
                gc.player = player
                gc.field = field
                add_child(gc)
                gc.run()
                return


        if "--detailcost" in OS.get_cmdline_user_args():
                var dc:= DevDetailCostProbe.new()
                dc.world = self
                dc.player = player
                dc.field = field
                dc.detail = detail
                add_child(dc)
                dc.run()
                return


        if "--factoryperf" in OS.get_cmdline_user_args():
                var fp:= DevFactoryPerfProbe.new()
                fp.world = self
                fp.player = player
                fp.field = field
                add_child(fp)
                fp.run()
                return


        if "--animcost" in OS.get_cmdline_user_args():
                var ac:= DevAnimCostProbe.new()
                ac.world = self
                ac.player = player
                ac.field = field
                add_child(ac)
                ac.run()
                return


        if "--workcost" in OS.get_cmdline_user_args():
                var wc:= DevWorkCostProbe.new()
                wc.world = self
                wc.player = player
                wc.field = field
                add_child(wc)
                wc.run()
                return


        if "--buildscale" in OS.get_cmdline_user_args():
                var bs:= DevBuildScaleProbe.new()
                bs.world = self
                bs.player = player
                bs.field = field
                add_child(bs)
                bs.run()
                return


        if "--armscale" in OS.get_cmdline_user_args():
                var asp:= DevArmScaleProbe.new()
                asp.world = self
                asp.player = player
                asp.field = field
                add_child(asp)
                asp.run()
                return

        if "--rakescale" in OS.get_cmdline_user_args():
                var rsp:= DevRakeScaleProbe.new()
                rsp.world = self
                rsp.player = player
                rsp.field = field
                add_child(rsp)
                rsp.run()
                return


        if "--worldcost" in OS.get_cmdline_user_args():
                var wc:= DevWorldCostProbe.new()
                wc.world = self
                wc.player = player
                wc.field = field
                wc.terrain = terrain
                wc.warehouse = warehouse
                wc.door = bay_door
                add_child(wc)
                wc.run()
                return


        if "--iconshots" in OS.get_cmdline_user_args():
                var ic:= DevIconShotProbe.new()
                ic.world = self
                ic.player = player
                add_child(ic)
                var ua2:= OS.get_cmdline_user_args()
                var out_dir:= DevIconShotProbe.OUT_DIR
                var only: Array = []
                var seen_only:= false
                for a: String in ua2:
                        if a == "--iconshots":
                                continue
                        if a == "only":
                                seen_only = true
                        elif seen_only:
                                only.append(a)
                        elif not a.begins_with("--"):
                                out_dir = a
                ic.shoot(out_dir, only)
                return


        if "--saveguard" in OS.get_cmdline_user_args():
                var sg:= DevSaveGuardProbe.new()
                sg.world = self
                add_child(sg)
                sg.run()
                return

        if "--capture" in OS.get_cmdline_user_args():
                var cap:= DevCapture.new()
                cap.world = self
                cap.player = player
                add_child(cap)
                cap.run()


func _first_picks() -> String:
        var tool:= player.build
        var late:= [BuildTool.Mode.SCANNER, BuildTool.Mode.PELLETIZER,
                BuildTool.Mode.GENERATOR, BuildTool.Mode.GAS_PLANT, BuildTool.Mode.BOREHOLE,
                BuildTool.Mode.LAUNCHER, BuildTool.Mode.COMPRESSOR, BuildTool.Mode.PULPER,
                BuildTool.Mode.PAPER, BuildTool.Mode.BRIQUETTE, BuildTool.Mode.WRAPPER,
                BuildTool.Mode.SILO, BuildTool.Mode.PISTON_RAKE, BuildTool.Mode.CABINET,
                BuildTool.Mode.NEEDLE_RADAR, BuildTool.Mode.HAY_LIFT]
        var built_late:= 0
        var fault:= ""
        for mode: int in late:
                var before:= tool.get_child_count()
                var compiled:= _pipelines_ahead()
                var t:= Time.get_ticks_usec()
                tool.set_mode(mode)
                var ms:= (Time.get_ticks_usec() - t) / 1000.0
                compiled = _pipelines_ahead() - compiled
                var added:= tool.get_child_count() - before
                var mode_name: String = BuildTool.Mode.keys() [mode]
                if added > 1:
                        fault = "%s built %d holograms on one pick" % [mode_name, added]
                if added == 1:
                        built_late += 1
                        print("[picks] %-14s first pick %6.1f ms, %d pipelines compiled"
                                % [mode_name, ms, compiled])
                tool.set_mode(mode)
                if tool.get_child_count() != before + added:
                        fault = "%s built another hologram on the second pick" % mode_name
        tool.set_mode(BuildTool.Mode.CONVEYOR)
        print("[picks] %d of %d machine holograms were left for the first pick"
                % [built_late, late.size()])
        return fault


func _pipelines_ahead() -> int:
        return RenderingServer.get_rendering_info(
                        RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE) + RenderingServer.get_rendering_info(
                        RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH) + RenderingServer.get_rendering_info(
                        RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)


func _deliver_new_pile(pay_now: bool = false) -> void:


        if not GameState.may_order_pile():
                return
        if landing_zone != null:
                landing_zone.refresh()
                if landing_zone.is_blocked():
                        landing_zone.set_shown(true)
                        return


        var cost:= GameState.next_stack_fee() if pay_now else GameState.credit_stack_fee()
        if not GameState.pay_for_next_stack(pay_now):
                return

        var was:= GameState.lot_tier
        field.refill(LandingZone.next_seed())
        _stand_player_off_the_pile()
        if landing_zone != null:


                landing_zone.lift_loose(props, live, field)
                landing_zone.set_shown(false)
        if hud == null:
                return


        var receipt:= ""
        if cost > 0.0:
                receipt = "  ·  " + ((tr("PAID $%s") if pay_now
                        else tr("$%s ADDED TO WHAT YOU OWE")) % Hud.money_text(cost))
        if GameState.lot_tier != was:
                var lot:= GameState.lot_tier
                hud.show_toast(tr("A NEW LOAD IS IN  ·  SIX NEW KINDS TO FIND  ·  %s")
                        % Cfg.upper(NeedleTypes.lot_name(lot)) + receipt, 6.0)
                Audio.play("ui_open", -2.0)
        else:
                hud.show_toast(tr("A NEW LOAD IS IN") + receipt, 4.0)


func _open_the_yard_sale() -> void:
        if sell_all_dialog == null:
                return
        sell_all_dialog.open(YardSale.tally(builds, props))


func _take_the_yard_sale() -> void:
        var sold:= YardSale.sell(builds, props)
        var paid:= float(sold.get("paid", 0.0))
        GameState.add_money(paid)
        var gone:= int(sold.get("machines", 0)) + int(sold.get("structures", 0)) + int(sold.get("tools", 0))
        if stand != null and paid > 0.0:
                stand.ring_up(paid, "+$%s" % Hud.money_text(paid))
        if hud != null:


                hud.show_toast(tr_n("YARD SOLD  ·  %d THINGS CLEARED  ·  +$%s",
                        "YARD SOLD  ·  %d THINGS CLEARED  ·  +$%s", gone)
                        % [gone, Hud.money_text(paid)], 4.2)


const DEMO_CARD_DELAY:= 3.2


func _on_discovered_for_the_demo(_type: int, _at: Vector3) -> void:
        if demo_end_dialog == null or not GameState.demo_is_over():
                return
        get_tree().create_timer(DEMO_CARD_DELAY).timeout.connect(_show_the_demo_card)


func _show_the_demo_card() -> void:
        if discovery_card != null and discovery_card.is_playing():
                get_tree().create_timer(0.25).timeout.connect(_show_the_demo_card)
                return
        if demo_end_dialog != null and GameState.demo_is_over():
                demo_end_dialog.celebrate()


func _on_pile_emptied() -> void:
        var burst:= PileClearedVfx.new()
        add_child(burst)
        burst.global_position = Cfg.PILE_CENTER
        burst.play(Cfg.PILE_RADIUS)
        Audio.play("needle_reveal")
        if hud == null:
                return
        var line:= tr("YOU CLEARED THE WHOLE PILE!")
        if GameState.first_clear_secs >= 0.0 and is_equal_approx(GameState.first_clear_secs, GameState.run_secs):
                line = tr("YOU CLEARED THE WHOLE PILE IN %s!") % Leaderboard.clock_text(GameState.first_clear_secs)
        hud.show_toast(line, 7.0, Color(1.0, 0.88, 0.45))


func _on_t_switched(_t: Node3D, joining: bool) -> void:
        if hud == null or Loading.is_active():
                return
        hud.show_toast(tr("T JUNCTION  ·  NOW JOINING") if joining
                else tr("T JUNCTION  ·  NOW SPLITTING"))


func _watch_for_the_ending(cab: NeedleCabinet) -> void:
        if demo_end_dialog == null or cab == null:
                return
        if not cab.ending_pressed.is_connected(demo_end_dialog.celebrate):
                cab.ending_pressed.connect(demo_end_dialog.celebrate)


func _leave_for_the_title() -> void:
        get_tree().change_scene_to_file(PauseMenu.MENU_SCENE)


func _open_load_panel() -> void:
        if load_panel != null:
                load_panel.open()


func _open_needle_panel() -> void:
        if needle_panel != null:
                needle_panel.open()


func _return_loose_needles() -> void:
        if live == null:
                return
        var buried:= 0
        var floored:= 0

        for b in live.needles.duplicate():
                if not is_instance_valid(b) or not b.has_meta("needle_index"):
                        continue
                var index:= int(b.get_meta("needle_index"))
                var type:= GameState.type_of(index)
                if GameState.is_discovered(type):
                        continue

                if field != null and field.rebury(type):
                        live.consume_needle(b)
                        buried += 1
                        continue


                live.consume_needle(b)
                if _set_needle_down(type, index):
                        floored += 1
        if needle_panel != null:
                needle_panel.report_return(buried, floored)
        if hud != null and buried > 0:
                hud.show_toast(tr_n("BACK IN THE STACK  ·  %d TO FIND AGAIN",
                        "BACK IN THE STACK  ·  %d TO FIND AGAIN", buried) % buried, 3.4)
        if hud != null and floored > 0:
                hud.show_toast(tr("%d ON THE FLOOR UNDER THE DELIVERY BOARD") % floored, 3.4)


func _set_needle_down(type: int, index: int = -1) -> bool:
        if live == null:
                return false
        var at:= _needle_floor_point()
        if index < 0:
                index = GameState.register_needle(at, null, type)
        GameState.needle_positions [index] = at

        GameState.needle_taken [index] = 1
        return live.reveal_needle(index, at) != null


func _needle_floor_point() -> Vector3:
        if delivery_board == null:
                if player != null:
                        return player.global_position + Vector3.UP * 0.5
                return Cfg.PILE_CENTER + Vector3.UP
        var out:= delivery_board.global_transform.basis * DeliveryBoard.face_normal()
        out.y = 0.0
        return delivery_board.chit_point() + out.normalized() * 0.9


func _on_needle_lost(type: int, amount: float,
                cause: GameState.NeedleLoss) -> void:


        var back:= ""
        if not GameState.is_discovered(type):
                if field != null and field.rebury(type):
                        back = tr("  ·  it is back in the stack")
                elif _set_needle_down(type):
                        back = tr("  ·  the stack is dug out, so it is on the floor under the delivery board")


        if hud != null:
                hud.announce_needle_lost(type, amount, cause, back)


func _stand_player_off_the_pile() -> void:
        if player == null or field == null:
                return
        var p:= player.global_position
        var flat:= Vector2(p.x - Cfg.PILE_CENTER.x, p.z - Cfg.PILE_CENTER.z)
        if flat.length() > Cfg.PILE_RADIUS:
                return
        var surface:= field.height_at(p.x, p.z)
        if p.y >= surface:
                return
        player.global_position = Vector3(p.x, surface + 0.1, p.z)


const LOOK_SCENE:= "res://scenes/look/yard_look.tscn"


func _build_look() -> void:
        var packed:= load(LOOK_SCENE) as PackedScene
        if packed == null:
                push_error("World: %s is missing. Rebuild it with --lookexport." % LOOK_SCENE)
                return
        var look:= packed.instantiate()


        for child in look.get_children():


                if child is LookEditorRoom:
                        continue
                look.remove_child(child)
                add_child(child)
        look.free()

        env_node = get_node("Environment") as WorldEnvironment

        env_node.environment = env_node.environment.duplicate() as Environment
        sun = get_node("Sun") as DirectionalLight3D
        fill = get_node("BounceFill") as DirectionalLight3D

        fill.light_cull_mask &= ~ Carryable.HAY_LAYER


        _grade_ramp = env_node.environment.adjustment_color_correction as GradientTexture1D
        var sky:= env_node.environment.sky
        if sky != null:
                _sky_mat = sky.sky_material as ShaderMaterial


func _apply_render_settings() -> void:
        _restore_machine_distance_fog()
        var g:= Cfg.gfx
        var vp:= get_viewport()
        vp.msaa_3d = g ["msaa"]


        Cfg.sync_msaa_pipelines()
        _set_scaling(vp, float(g ["render_scale"]))
        vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if g ["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED


        vp.use_taa = g ["taa"]
        var e:= env_node.environment
        e.ssao_enabled = g ["ssao"]
        e.ssil_enabled = g ["ssil"]
        e.volumetric_fog_enabled = g ["vfog"]
        e.fog_enabled = g ["fog"]
        sun.shadow_enabled = g ["shadows"]
        _apply_shadow_quality(vp, int(g ["shadow_quality"]), bool(g ["shadows"]))


        var lod_px:= float(Cfg.preset().get("lod_threshold", 1.0))
        vp.mesh_lod_threshold = 1.0 if _lod_px1 else lod_px


        var aniso:= int(Cfg.preset().get("aniso", -1))
        if aniso < 0:
                aniso = int(ProjectSettings.get_setting(
                        "rendering/textures/default_filters/anisotropic_filtering_level", 2))
        vp.anisotropic_filtering_level = aniso as Viewport.AnisotropicFiltering
        sun.light_angular_distance = clampf(float(g ["shadow_blur"]), 0.0, 10.0)

        e.glow_enabled = g ["glow"]
        e.glow_intensity = g ["glow_intensity"]


        e.tonemap_mode = g ["tonemap"]
        e.tonemap_exposure = g ["exposure"]
        e.tonemap_white = g ["white"]
        e.adjustment_enabled = g ["adjustment"]
        e.adjustment_color_correction = _grade_ramp if g ["color_correction"] else null


        e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if g ["ambient_sky"] else Environment.AMBIENT_SOURCE_COLOR
        e.ambient_light_sky_contribution = g ["sky_contribution"]
        e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if g ["reflect_sky"] else Environment.REFLECTION_SOURCE_DISABLED
        _apply_gi(e)
        if room_probe != null:


                var want_probe:= bool(g.get("reflect_probe", true))
                if want_probe and not room_probe.visible:
                        room_probe.update_mode = ReflectionProbe.UPDATE_ONCE
                room_probe.visible = want_probe
        if dust != null:
                dust.set_wanted(bool(g.get("dust", true)))
        _apply_camera_attributes(bool(g.get("auto_exposure", true)), bool(g.get("dof", true)))


        Cfg.crust_lod_min = float(g ["hay_lod_min"])


        var want_density:= int(g ["hay_density"])
        if Cfg.crust_strands_per_cell != want_density:
                Cfg.crust_strands_per_cell = want_density
                if field != null:
                        field.rebuild_density()


        _apply_sky_settings()


        if plaza != null:
                plaza.light_it(sun, env_node.environment)
        _apply_machine_distance_fog(true)


func _apply_machine_distance_fog(capture_defaults: bool = false) -> void:
        if env_node == null:
                return
        if not capture_defaults:
                _restore_machine_distance_fog()
        var e:= env_node.environment
        if capture_defaults or _machine_fog_defaults.is_empty():
                for key: String in ["fog_enabled", "fog_mode", "fog_density", "fog_depth_begin",
                                "fog_depth_end", "fog_depth_curve", "fog_light_color", "fog_light_energy", "fog_sun_scatter",
                                "fog_aerial_perspective", "fog_height_density", "fog_sky_affect"]:
                        _machine_fog_defaults [key] = e.get(key)
        var distance:= Cfg.machine_distance_metres()
        if distance == 0.0 or not bool(Cfg.gfx ["fog"]):
                return
        e.fog_enabled = true
        e.fog_mode = Environment.FOG_MODE_DEPTH
        e.fog_density = 1.0
        e.fog_depth_begin = distance * 0.6

        e.fog_depth_end = distance - MachineDrawDistance.MARGIN
        e.fog_depth_curve = 1.3
        e.fog_light_color = Color(0.88, 0.89, 0.9)
        e.fog_light_energy = 1.5
        e.fog_sun_scatter = 0.0
        e.fog_aerial_perspective = 0.0
        e.fog_height_density = 0.0
        e.fog_sky_affect = 0.0


func _restore_machine_distance_fog() -> void:
        if env_node == null:
                return
        for key: String in _machine_fog_defaults:
                env_node.environment.set(key, _machine_fog_defaults [key])


var _shadow_quality_applied:= -1
var _shadow_atlas_on:= true

var _keep_lamp_shadows:= "--keeplampshadows" in OS.get_cmdline_user_args()
var _lod_px1:= "--lodpx1" in OS.get_cmdline_user_args()


func _apply_shadow_quality(vp: Viewport, requested: int, shadows_on: bool = true) -> void:
        var level:= clampi(requested, 0, Cfg.SHADOW_QUALITY_NAMES.size() - 1)
        var atlas_on:= shadows_on or _keep_lamp_shadows
        if level == _shadow_quality_applied and atlas_on == _shadow_atlas_on:
                return
        _shadow_quality_applied = level
        _shadow_atlas_on = atlas_on
        var atlas_size: int = Cfg.SHADOW_ATLAS_SIZES [level]
        var filter_quality: int = Cfg.SHADOW_FILTER_QUALITIES [level]
        vp.positional_shadow_atlas_size = atlas_size if atlas_on else 0
        RenderingServer.directional_shadow_atlas_set_size(atlas_size, true)
        RenderingServer.directional_soft_shadow_filter_set_quality(filter_quality)
        RenderingServer.positional_soft_shadow_filter_set_quality(filter_quality)


const AUTO_EXPOSURE_MIN:= 90.0
const AUTO_EXPOSURE_MAX:= 320.0

const AUTO_EXPOSURE_SPEED:= 0.45


const DOF_NEAR:= 0.32
const DOF_NEAR_FADE:= 0.2

const DOF_AMOUNT:= 0.06

var _cam_attrs: CameraAttributesPractical


func _apply_camera_attributes(auto_exposure: bool, dof: bool) -> void:
        if env_node == null:
                return
        if _cam_attrs == null:
                _cam_attrs = CameraAttributesPractical.new()
                _cam_attrs.auto_exposure_scale = 0.4
                _cam_attrs.auto_exposure_speed = AUTO_EXPOSURE_SPEED
                _cam_attrs.auto_exposure_min_sensitivity = AUTO_EXPOSURE_MIN
                _cam_attrs.auto_exposure_max_sensitivity = AUTO_EXPOSURE_MAX
                _cam_attrs.dof_blur_near_distance = DOF_NEAR
                _cam_attrs.dof_blur_near_transition = DOF_NEAR_FADE
                _cam_attrs.dof_blur_amount = DOF_AMOUNT
                env_node.camera_attributes = _cam_attrs
        _cam_attrs.auto_exposure_enabled = auto_exposure
        _cam_attrs.dof_blur_near_enabled = dof


        _cam_attrs.dof_blur_far_enabled = false


const PROBE_LIFT:= 8.2

const PROBE_REACH:= 90.0


func _build_room_probe() -> void:
        room_probe = ReflectionProbe.new()
        room_probe.name = "RoomProbe"
        room_probe.update_mode = ReflectionProbe.UPDATE_ONCE
        room_probe.box_projection = true


        room_probe.enable_shadows = true


        room_probe.interior = false


        room_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
        room_probe.max_distance = PROBE_REACH
        add_child(room_probe)
        _fit_room_probe()


func _fit_room_probe() -> void:
        if room_probe == null:
                return
        var half: float = warehouse.inner if warehouse != null else Warehouse.INNER
        var span_z: float = warehouse.span_z() if warehouse != null else half * 2.0
        var mid_z: float = warehouse.z_mid() if warehouse != null else 0.0


        var top:= Warehouse.WALL_H + 3.0
        room_probe.position = Vector3(0.0, top * 0.5, mid_z)
        room_probe.size = Vector3(half * 2.0, top, span_z)
        room_probe.origin_offset = Vector3(0.0, PROBE_LIFT - top * 0.5, 0.0)
        room_probe.update_mode = ReflectionProbe.UPDATE_ONCE


var _gi_said:= -1


func _apply_gi(e: Environment) -> void:
        var on:= bool(Cfg.gfx.get("gi", false))
        e.sdfgi_enabled = on


        if int(on) != _gi_said:
                _gi_said = int(on)
                print("[world] bounced light %s" % ["on" if on else "off"])


func _apply_sky_settings() -> void:
        if _sky_mat == null:
                return
        var marches:= int(Cfg.gfx.get("sky_marches", 40))
        _sky_mat.set_shader_parameter("use_cumulus", marches > 0)


        _sky_mat.set_shader_parameter("cloud_marches", clampi(marches, 4, 64))


        _sky_mat.set_shader_parameter("light_marches", clampi(marches / 8, 4, 8))


        _sky_mat.set_shader_parameter("atmosphere_sample_count", 32 if marches > 0 else 16)


const CLOUD_DRIFT:= Vector3(0.004, 0.0, 0.003)


func _drift_clouds(delta: float) -> void:
        if _sky_mat == null or int(Cfg.gfx.get("sky_marches", 40)) <= 0:
                return
        _cloud_offset += CLOUD_DRIFT * delta
        _sky_mat.set_shader_parameter("cloud_shape_offset", _cloud_offset)
        _sky_mat.set_shader_parameter("cloud_noise_offset", _cloud_offset * 2.0)


func _on_quality_changed(_level: int) -> void:
        _apply_render_settings()


        field.rebuild_density()


        if detail != null:
                detail.reconfigure()
                if player != null:
                        detail.fill_now(player.eye_position())


func _process(delta: float) -> void:


        if not _built:
                return


        GameState.tick_run_clock(delta)
        if player != null:
                var eye:= player.eye_position()
                var t:= Time.get_ticks_usec()
                if HayField.old_lod:
                        field.update_lod(eye)
                else:
                        field.tick_lod(eye)
                HotSpots.add(&"frame pile lod", t)


                if detail != null:
                        t = Time.get_ticks_usec()
                        detail.tick(eye)
                        HotSpots.add(&"frame straw ring", t)


                if shadow_lod != null:
                        t = Time.get_ticks_usec()
                        shadow_lod.tick(eye)
                        HotSpots.add(&"frame shadow lod", t)


                t = Time.get_ticks_usec()
                MachineLod.tick(eye)
                HotSpots.add(&"frame machine lod", t)


                t = Time.get_ticks_usec()
                HayWad.lod_tick(eye)
                HotSpots.add(&"frame wad lod", t)
        var t_rest:= Time.get_ticks_usec()
        _drift_clouds(delta)
        _autosave(delta)
        _warn_belts_full(delta)
        _warn_floor_full(delta)
        HotSpots.add(&"frame world timers", t_rest)


func _physics_process(_delta: float) -> void:
        if not _built:
                return
        if is_instance_valid(player):
                BeltPath.focus = player.global_position
                BeltPath.focus_set = true
        var t:= Time.get_ticks_usec()
        BeltPath.sweep()
        HotSpots.add(&"tick belt sleep sweep", t)


func _autosave(delta: float) -> void:
        if block_save or not autosave_enabled:
                return
        _autosave_left -= delta
        if _autosave_left > 0.0:
                return
        if get_tree().paused:


                _autosave_left = 5.0
                return
        _autosave_left = AUTOSAVE_SECONDS
        save_now()


func _set_scaling(vp: Viewport, scale: float) -> void:
        vp.scaling_3d_scale = scale
        vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if scale >= 0.999 else Viewport.SCALING_3D_MODE_FSR


func _write_repro() -> void:
        var dir:= "user://repro"
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
        var stamp:= Time.get_datetime_string_from_system().replace(":", "-")
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("%s/shot_%s.png" % [dir, stamp])


        hud.show_toast("measuring frames")
        var sampler:= FrameSampler.new()
        add_child(sampler)
        await sampler.finished
        var timing:= sampler.report()
        sampler.queue_free()

        var cam:= player.camera.global_transform
        var lines:= PackedStringArray()
        lines.append("camera_origin   = %v" % cam.origin)
        lines.append("camera_basis    = %s" % str(cam.basis))
        lines.append("player_pos      = %v" % player.global_position)
        lines.append("player_yaw      = %.4f" % player.rotation.y)
        lines.append("head_pitch      = %.4f" % player.head.rotation.x)
        lines.append("run_seed        = %d" % GameState.run_seed)
        lines.append("hay_total       = %.0f" % GameState.hay_total)


        lines.append("renderer        = %s / %s" % [
                ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
                RenderingServer.get_video_adapter_api_version()])
        lines.append("adapter         = %s" % RenderingServer.get_video_adapter_name())
        lines.append("quality         = %s" % Cfg.preset() ["name"])
        lines.append("perf_scale      = %.3f" % Cfg.perf_scale)
        lines.append("lod_near/far    = %.2f / %.2f" % [Cfg.effective_lod_near(), Cfg.effective_lod_far()])
        lines.append("lod_min         = %.3f" % Cfg.crust_lod_min)
        lines.append("strands_per_cell= %d" % Cfg.crust_strands_per_cell)
        lines.append("crust drawn     = %d" % field.drawn_instance_count())
        if detail != null:
                lines.append("ring drawn      = %d  (scale %.2f)" % [detail.drawn_instances(), Cfg.detail_scale])
        lines.append("live strands    = %d" % live.active_count())
        lines.append("fps             = %d" % int(Engine.get_frames_per_second()))
        lines.append_array(timing)


        BeltPath.debug_props = true
        for _i in 3:
                await get_tree().physics_frame
        _repro_belts(lines, cam)


        BeltPath.debug_props = false
        BeltPath.debug_last_refusal.clear()
        var f:= FileAccess.open("%s/shot_%s.txt" % [dir, stamp], FileAccess.WRITE)
        if f != null:
                f.store_string("\n".join(lines))
                f.close()
        hud.show_toast("repro saved")
        print("[repro] %s/shot_%s.png" % [dir, stamp])


func _repro_belts(lines: PackedStringArray, cam: Transform3D) -> void:
        var from:= cam.origin
        var ray:= PhysicsRayQueryParameters3D.create(from, from - cam.basis.z * 8.0)
        var hit:= get_world_3d().direct_space_state.intersect_ray(ray)
        var aim: Vector3 = hit ["position"] if not hit.is_empty() else from - cam.basis.z * 3.0
        var census:= BeltPath.sleep_census()
        lines.append("aim             = %v" % aim)


        var tool:= player.build
        if tool != null and tool.is_active():
                lines.append("build mode      = %s, state %s, anchor %v" % [
                        BuildTool.Mode.keys() [tool._mode], BuildTool.State.keys() [tool._state],
                        tool._anchor])
                lines.append("build verdict   = ok %s, reason '%s', blocker '%s', route %d points"
                        % [tool._eval.get("ok", false), tool._eval.get("reason", ""),
                                tool._run_blocker, tool._route.size()])
        lines.append("tree paused    = %s, physics frames %d" % [get_tree().paused, Engine.get_physics_frames()])
        lines.append("belts           = %d live, %d asleep, sleeping enabled %s"
                % [census [0], census [1], BeltPath.sleeping_enabled])


        if BeltRunBatch.instance != null:
                for line in BeltRunBatch.instance.debug_sweep():
                        lines.append(line)
        for item in BeltPath._live:
                if not is_instance_valid(item) or not (item as Node).is_inside_tree():
                        continue
                var p:= item as BeltPath
                if p._line.size() < 2:
                        continue
                var n:= p._nearest(aim)
                var near_aim:= p._point_at(float(n ["s"])).distance_to(aim) <= 3.0
                if not near_aim and hit.is_empty():


                        var t:= 0.5
                        while t <= 40.0 and not near_aim:
                                var pt:= from - cam.basis.z * t
                                var m:= p._nearest(pt)
                                near_aim = p._point_at(float(m ["s"])).distance_to(pt) <= 1.5
                                t += 0.5
                if not near_aim:
                        continue
                lines.append("belt %s/%s len %.2f speed %.2f asleep %s ticking %s can_process %s catching %s blocked %s outlet_held %s drawn_held %s occupied %s stride %d downstream %s"
                        % [p.get_parent().name, p.name, p.path_length(), p.drive_speed, p._asleep,
                                p.is_physics_processing(), p.can_process(), p._catching, p._blocked,
                                p._outlet_held, p.deck_shows_held(), p._deck_occupied(), p._tick_stride(),
                                p.downstream.name if is_instance_valid(p.downstream) else "-"])


                var wye:= p.get_parent() as ConveyorSplitter
                if wye != null and p == wye.route(ConveyorSplitter.LEFT):
                        lines.append("    blade angle %.3f goal %.3f next %d batching %s batch %d stall %s parked under %d depth +%.3f -%.3f"
                                % [wye._gate_angle, wye._gate_goal, wye.next_side, wye._batching, wye._batch_n,
                                        str(wye._stall), wye._parked_under.size() / 3,
                                        wye._blade_depth(Cfg.SPLITTER_GATE_SWING), wye._blade_depth(- Cfg.SPLITTER_GATE_SWING)])
                for r in p._riders:
                        var b = r.body
                        lines.append("    rider %s s %.3f side %.3f reach %.3f speed %.2f"
                                % [(b as Node).name if is_instance_valid(b) else "freed", r.s, r.side, r.reach, r.speed])
                var groups:= p.run.groups()
                if p.run.count() > 0:
                        lines.append("    records %d (jam %d, free %d, back %d) awake %s head %s"
                                % [p.run.count(), groups.x, groups.y, groups.z, p.run.awake, p.run.has_head()])


                var batch:= BeltRunBatch.instance
                if batch != null and p.run.count() > 0:
                        lines.append("    " + batch.debug_line(p.run))
                for i in range(p.run.first(), p.run.first() + p.run.count()):
                        var drawn: Array = batch.debug_drawn(p.run, p.run.seq_of(i)) if batch != null else [- INF, -1]
                        lines.append("    record %s s %.3f side %.3f reach %.3f speed %.2f strands %d group %d drawn %.3f in group %d%s"
                                % [BeltRun.ITEM_IDS [p.run.kind_of(i)], p.run.s_of(i), p.run.side_of(i),
                                        p.run.reach_of(i), p.run.speed_of(i), p.run.strands_of(i),
                                        p.run.row_group(i), float(drawn [0]), int(drawn [1]),
                                        "  DRAWN OFF" if absf(float(drawn [0]) - p.run.s_of(i)) > 0.25 else ""])
        var seen:= { }
        var bodies: Array = []
        bodies.append_array(props.items)
        bodies.append_array(HayTuft.all)
        for item in bodies:
                var rb:= item as RigidBody3D
                if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree() or seen.has(rb):
                        continue
                seen [rb] = true
                if rb.global_position.distance_to(aim) > 3.0:
                        continue
                var owner_path = rb.get_meta(LiveStrandManager.META_RIDER) if rb.has_meta(LiveStrandManager.META_RIDER) else null
                lines.append("load %s %s at %v v %v freeze %s mode %d sleeping %s layer %d mask %d rider_of %s hold %.1f settled %s refused '%s'"
                        % [rb.name, rb.get_class(), rb.global_position, rb.linear_velocity, rb.freeze,
                                rb.freeze_mode, rb.sleeping, rb.collision_layer, rb.collision_mask,
                                (owner_path as Node).name if is_instance_valid(owner_path) else "-",
                                float(rb.get_meta(LiveStrandManager.META_HOLD_UNTIL, 0.0)) - Time.get_ticks_msec() * 0.001,
                                rb.has_meta(BeltPath.META_SETTLED),
                                BeltPath.debug_last_refusal.get(rb.get_instance_id(), "")])


func _unhandled_input(event: InputEvent) -> void:
        if not _built:
                return
        if event.is_action_pressed("screenshot"):


                if Cfg.debug_on():
                        _write_repro()
                return
        if event.is_action_pressed("quick_save"):
                _quick_save()


var _quick_saving:= false


func _quick_save() -> void:
        if _quick_saving:
                return
        _quick_saving = true
        hud.show_toast(tr("saving..."))
        await get_tree().process_frame
        await get_tree().process_frame
        _quick_saving = false
        if not is_instance_valid(hud):
                return
        if save_now():
                hud.show_toast(tr("saved to slot %d") % (SaveManager.current_slot + 1))
        else:
                hud.show_toast(tr("Could not write the save"))


func save_now() -> bool:
        if block_save or SaveManager.block_save or field == null or player == null:
                return false


        if not _built:
                return false


        if intro != null and intro.is_running():
                return false


        _gather_loose_needles()


        var riding:= float(live.active_count()) if live != null else 0.0


        return SaveManager.save_game(field.heights, player.global_transform,
                builds.to_array(), props.to_array(), riding, _belts_to_dict(),
                field.dome, field.dome_seed)


func _belts_to_dict() -> Dictionary:
        return {
                "paths": BeltPath.belts_to_array(),
                "lifts": HayLift.rows_to_array(),
                "stairs": HayStairs.rows_to_array(),
        }


func _restore_belts() -> void:
        var belts:= SaveManager.take_belts()
        if belts.is_empty():
                return
        var on_paths:= BeltPath.belts_from_array(belts.get("paths", []), props)
        var on_lifts:= HayLift.rows_from_array(belts.get("lifts", []), props)
        var on_stairs:= HayStairs.rows_from_array(belts.get("stairs", []), props)
        var bodied:= int(on_paths ["bodied"]) + int(on_lifts ["bodied"]) + int(on_stairs ["bodied"])
        var lost:= int(on_paths ["lost"]) + int(on_lifts ["lost"]) + int(on_stairs ["lost"])
        if int(on_paths ["boarded"]) + int(on_lifts ["boarded"]) + int(on_stairs ["boarded"]) + bodied + lost == 0:
                return
        print("[load] belts: %d records back on their runs, %d on lift rails, %d on stairs, %d given a body, %d lost"
                % [int(on_paths ["boarded"]), int(on_lifts ["boarded"]), int(on_stairs ["boarded"]),
                        bodied, lost])


func _gather_loose_needles() -> void:


        if not _built:
                return
        var indices:= PackedInt32Array()
        var places:= PackedVector3Array()
        if live != null:
                for b in live.needles:
                        if not is_instance_valid(b) or not b.has_meta("needle_index"):
                                continue
                        indices.append(int(b.get_meta("needle_index")))
                        places.append(b.global_position)
        GameState.needle_loose = indices
        GameState.needle_loose_at = places


func _restore_loose_needles() -> void:
        if live == null:
                return
        var indices:= GameState.needle_loose
        var places:= GameState.needle_loose_at
        GameState.needle_loose = PackedInt32Array()
        GameState.needle_loose_at = PackedVector3Array()
        var back:= 0
        for i in indices.size():
                if live.reveal_needle(indices [i], places [i]) != null:
                        back += 1
        if back > 0:
                print("[world] %d loose needle(s) put back where they were left" % back)


func _notification(what: int) -> void:


        if what == NOTIFICATION_WM_CLOSE_REQUEST and get_tree().auto_accept_quit:
                save_now()


func _exit_tree() -> void:
        Profile.leave_yard()


const BELT_FULL_CHECK_EVERY:= 0.5
const BELT_FULL_REARM:= 0.9
const BELT_FULL_QUIET_SECONDS:= 90.0
var _belt_full_check:= 0.0
var _belt_full_armed:= true
var _belt_full_quiet:= 0.0


func _warn_belts_full(delta: float) -> void:
        _belt_full_quiet = maxf(_belt_full_quiet - delta, 0.0)
        _belt_full_check += delta
        if _belt_full_check < BELT_FULL_CHECK_EVERY:
                return
        _belt_full_check = 0.0
        if hud == null:
                return
        if not Cfg.belt_decay:
                hud.set_belts_full(false, 0)
                return
        var load_now:= BeltPath.belt_load()


        if load_now >= Cfg.belt_cap:
                hud.set_belts_full(true, Cfg.belt_cap)
        elif load_now < int(Cfg.belt_cap * BELT_FULL_REARM) or hud.belts_full_cap() != Cfg.belt_cap:
                hud.set_belts_full(false, 0)
        if not _belt_full_armed:
                if load_now < int(Cfg.belt_cap * BELT_FULL_REARM) and _belt_full_quiet <= 0.0:
                        _belt_full_armed = true
                return
        if load_now < Cfg.belt_cap or hud.toast_up():
                return
        _belt_full_armed = false
        _belt_full_quiet = BELT_FULL_QUIET_SECONDS


        hud.show_toast(tr("THE THINGS ON YOUR BELTS REACHED THE LIMIT OF %d  ·  raise it in %s > %s  ·  or the newest things on your belts will start to disappear")
                % [Cfg.belt_cap, tr("OPTIONS"), tr("GAMEPLAY")],
                12.0, MachineAlert.COL_HAZARD)


var _floor_full_check:= 0.0
var _floor_full_armed:= true
var _floor_full_quiet:= 0.0


func _warn_floor_full(delta: float) -> void:
        _floor_full_quiet = maxf(_floor_full_quiet - delta, 0.0)
        _floor_full_check += delta
        if _floor_full_check < BELT_FULL_CHECK_EVERY:
                return
        _floor_full_check = 0.0
        if hud == null or props == null or not Cfg.prop_decay:
                return
        var load_now: int = props.yard_count()
        if not _floor_full_armed:
                if load_now < int(Cfg.prop_cap * BELT_FULL_REARM) and _floor_full_quiet <= 0.0:
                        _floor_full_armed = true
                return
        if load_now < Cfg.prop_cap or hud.toast_up():
                return
        _floor_full_armed = false
        _floor_full_quiet = BELT_FULL_QUIET_SECONDS
        hud.show_toast(tr("THE THINGS ON YOUR FLOOR REACHED THE LIMIT OF %d  ·  raise it in %s > %s  ·  or the oldest things on your floor will start to go back onto the pile")
                % [Cfg.prop_cap, tr("OPTIONS"), tr("GAMEPLAY")],
                12.0, MachineAlert.COL_HAZARD)


func _on_first_grid_rebuild() -> void:
        if hud == null or builds == null or builds.grid == null:
                return
        var wanting:= 0
        for machine in builds.grid.machines():
                if machine.has_method(PowerGrid.M_DRAW) and machine.has_method(PowerGrid.M_SET):
                        wanting += 1
        if wanting == 0:
                return


        for machine in builds.grid.machines():
                if builds.grid.network_of(machine) >= 0:
                        return
        hud.show_toast(tr("YOUR MACHINES NEED ELECTRICITY NOW  ·  belts still run  ·  buy ELECTRICITY in the tech tree under POWER, then build a generator and a pole"),
                12.0, MachineAlert.COL_HAZARD)
