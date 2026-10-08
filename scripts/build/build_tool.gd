class_name BuildTool
extends Node3D


const STUB_LENGTH:= 1.6


const ROUTABLE: Array [String] = ["blocked", "turn further off the belt", "in the hay",
	"on a belt"]


const ROUTE_REFRESH:= 0.25


const SCANNER_FLOW_REACH:= Cfg.BELT_SEGMENT * 2.0


const WYE_FLOW_REACH:= 0.8

const T_SHOW_SECONDS:= 1.6


const WYE_ARROW_PITCH:= ARROW_PITCH * 0.55


const DISMANTLE_REACH:= Cfg.BUILD_REACH_MAX


var dismantled:= 0


var reversed:= 0


var last_reversed: Conveyor


var placed:= 0
var placed_on_grid:= 0
var placed_turned:= 0
var placed_copied:= 0


var copied:= 0


var turns:= 0


var grids:= 0


var _turned_since_place:= false
var _copied_since_place:= false


const DISMANTLE_HOLD:= 0.5


const DISMANTLE_RATCHET:= 0.66


const REVERSE_HOLD:= DISMANTLE_HOLD


const REVERSE_RATCHET:= DISMANTLE_RATCHET


const GHOST_CAPACITY:= 128

const GHOST_DRUMS:= 16


const ARROW_PITCH:= 0.8


const ARROW_CAPACITY:= 96


const ARROW_LIFT:= 0.06


const ARROW_FADE:= 0.45


const ENCLOSED_HINT_REFRESH:= 0.08


const ENCLOSED_HINT_FADE:= 0.14


const ENCLOSED_HINT_LIFT:= 1.1


const ENCLOSED_HINT_CAPACITY:= 128


const ENCLOSED_HINT_TINT:= Color(0.26, 0.8, 1.0)


const WYE_HINT_SPILL:= 0.35


const WYE_HINT_ROOF_CLEAR:= 0.4


const DECK_HEADROOM:= 0.5


const DECK_EDGE_INSET:= 0.15


const LIFT_EDGE_CLEAR:= 0.05


const LIFT_PORT_GAP:= 0.2


const FLOOR_PROBE_DROP:= 1000.0


const RAKE_DRIVE_INSET:= 0.1


const RAKE_DRIVE_STEP_UP:= 0.08


const FLUSH_FLAT:= 0.02

enum State { AIMING, RUNNING }
enum Mode { CONVEYOR, ROBOTIC_ARM, PLATFORM, STAIR, RAILING, SCANNER, CABINET,
	SPLITTER, COMPRESSOR, PELLETIZER, HAY_DRONE, JOINER, WALL, WALL_WINDOW,
	WALL_DOOR, HAY_STAIRS, PISTON_RAKE, WRAPPER, LAUNCHER, DUMP_HATCH, ROOF, ROOF_PITCH,
	ROOF_HATCH, SILO, GENERATOR, POWER_POLE, POWER_BOX, PAINT_BOARD, BOREHOLE,
	WATER_PIPE, WATER_SPLITTER, PULPER, PAPER, BRIQUETTE, HAY_LIFT, WORK_LAMP,
	U_SPLITTER, U_JOINER, NEEDLE_RADAR, T_SPLITTER, COMPACT_SPLITTER, SMART_SPLITTER,
	ENCLOSED_CONVEYOR, GAS_PLANT }


const TURNABLE: Array [Mode] = [Mode.SCANNER, Mode.CABINET, Mode.SPLITTER,
	Mode.COMPRESSOR, Mode.PELLETIZER, Mode.HAY_DRONE, Mode.JOINER,
	Mode.HAY_STAIRS, Mode.PISTON_RAKE, Mode.WRAPPER, Mode.LAUNCHER,
	Mode.DUMP_HATCH, Mode.SILO, Mode.GENERATOR, Mode.POWER_POLE,
	Mode.PAINT_BOARD, Mode.BOREHOLE, Mode.PULPER, Mode.PAPER, Mode.BRIQUETTE,
	Mode.HAY_LIFT, Mode.WATER_SPLITTER, Mode.WORK_LAMP, Mode.U_SPLITTER,
	Mode.U_JOINER, Mode.NEEDLE_RADAR, Mode.T_SPLITTER, Mode.COMPACT_SPLITTER,
	Mode.SMART_SPLITTER, Mode.GAS_PLANT]


const GRIDDED: Array [Mode] = [Mode.CONVEYOR, Mode.ENCLOSED_CONVEYOR, Mode.SCANNER, Mode.SPLITTER,
	Mode.JOINER, Mode.COMPRESSOR, Mode.WRAPPER, Mode.SILO, Mode.PELLETIZER,
	Mode.GENERATOR, Mode.LAUNCHER, Mode.DUMP_HATCH, Mode.HAY_STAIRS,
	Mode.PISTON_RAKE, Mode.HAY_DRONE, Mode.POWER_POLE, Mode.BOREHOLE,
	Mode.WATER_PIPE, Mode.WATER_SPLITTER, Mode.PULPER, Mode.PAPER,
	Mode.BRIQUETTE, Mode.HAY_LIFT, Mode.WORK_LAMP, Mode.U_SPLITTER, Mode.U_JOINER,
	Mode.NEEDLE_RADAR, Mode.T_SPLITTER, Mode.ROBOTIC_ARM, Mode.CABINET,
	Mode.PAINT_BOARD, Mode.COMPACT_SPLITTER, Mode.SMART_SPLITTER, Mode.GAS_PLANT]


const LEVELLED: Array [Mode] = [Mode.PLATFORM, Mode.STAIR]


const PELLETIZER_PORT_BACK:= 0.8 + HayPelletizer.STUB + HayPelletizer.STUB_REACH
const PELLETIZER_PORT_UP:= 0.94


const LAUNCHER_PORT_BACK:= TubeLauncher.PORT_BACK + TubeLauncher.STUB + TubeLauncher.STUB_REACH
const LAUNCHER_PORT_UP:= TubeLauncher.PORT_UP


const GENERATOR_PORT_BACK:= HayGenerator.PORT_BACK
const GENERATOR_PORT_UP:= HayGenerator.PORT_UP

var player: Player
var builds: BuildManager


var previews_ready:= false
signal previews_built()


var _preview_usec:= 0

var _active:= false


var _variant_family:= -1
var _variant_from:= ""


var _wreck: Node3D

var _wreck_time:= 0.0
var _wreck_noise:= 0.0


var _wreck_chain:= false


var _wreck_chain_kind:= ""


var _wreck_tile_on:= false
var _wreck_tile:= Rect2()

var _wreck_aim:= Vector3.ZERO


var _tile_glow: MeshInstance3D


var _flip: Conveyor

var _flip_time:= 0.0
var _flip_noise:= 0.0
var _state: State = State.AIMING
var _mode: Mode = Mode.CONVEYOR


var _anchor_dir:= Vector3.BACK
var _anchor_side:= 1


var _roof_turn:= 0


var _hatch_deck: Platform
var _hatch_tile:= Rect2()
var _hatch_from:= Vector3.ZERO
var _hatch_to:= Vector3.ZERO
var _hatch_side:= 1


var _hatch_gap:= false


var _ghost_turn:= 0


var _t_turn:= 0


var _grid_on:= false


var _snap_off:= false


var _grid_mesh: MeshInstance3D
var _grid_mat: ShaderMaterial
var _arm_tier:= Cfg.ROBOT_ARM_DEFAULT_TIER
var _scanner_tier:= Cfg.SCANNER_DEFAULT_TIER


var _anchor:= Vector3.ZERO


var _upstream:= false
var _anchor_span:= Vector2(Cfg.PLATFORM_TILE, Cfg.PLATFORM_TILE)


var _stair_outward:= Vector3.BACK
var _reach:= Cfg.BUILD_REACH


var _peek:= false
var _peek_at:= Vector3.INF


var _peek_kind:= ""
var _ghost: MultiMeshInstance3D


var _ghost_rails: Array [MultiMeshInstance3D] = []


var _ghost_drums: Array [MultiMeshInstance3D] = []
var _ghost_drum_ends: Array = []
var _flow: MultiMeshInstance3D


var _flow_phase:= 0.0


var _hint_flow: MultiMeshInstance3D


var _hint_runs: Array [Conveyor] = []

var _hint_wye: Node3D


var _hint_level:= 0.0
var _hint_since:= 0.0
var _arm_ghost: RoboticArm


var arm_feeds: Array [Dictionary] = []


var arm_feed_near: Dictionary = { }


var _arm_feed_at:= Vector3.INF
var _arm_feed_tier:= -1
var _arm_feed_msec:= 0


var _arm_feed_mesh: MeshInstance3D
var _arm_feed_draw: ImmediateMesh
var _arm_feed_mat: StandardMaterial3D


var _arm_keep_rings: Array [MeshInstance3D] = []
var _arm_keep_ok_mat: StandardMaterial3D
var _arm_keep_bad_mat: StandardMaterial3D


var _arm_blockers: Array [Node3D] = []
var _deck_ghost: Platform
var _stair_ghost: Stair
var _rail_ghost: Railing
var _wall_ghost: YardWall
var _roof_ghost: Roof
var _scanner_ghost: HaystackScanner
var _compressor_ghost: HayCompressor
var _pulper_ghost: HayPulper
var _paper_ghost: PaperMachine
var _briquette_ghost: BriquettePress
var _wrapper_ghost: HayWrapper
var _silo_ghost: HaySilo
var _pelletizer_ghost: HayPelletizer
var _generator_ghost: HayGenerator
var _plant_ghost: GasPlant


var _generator_ramp:= PackedVector3Array()


var _seat_stub:= PackedVector3Array()


var _t_stub:= PackedVector3Array()

var _t_stub_lane:= ConveyorTSplitter.STEM
var _t_stub_into:= true

var _seat_intake:= true


var _seat_far:= PackedVector3Array()
var _seat_far_intake:= false


var _port_belts: Array = []
var _borehole_ghost: BoreholePump
var _pole_ghost: PowerPole


var _box_ghost: PowerBox


var _pole_trace_mesh: MeshInstance3D


var _pole_ring_r:= 0.0


var _pole_wire_mesh: MeshInstance3D


var _pole_drawn: Array = []

var _pole_ring: MeshInstance3D
var _pole_ring_mat: StandardMaterial3D


var _pole_tinted: Array [Node3D] = []


var _pole_eval: Dictionary = { }


var _pole_probe: BoxShape3D
var _pole_probe_query: PhysicsShapeQueryParameters3D
var _launcher_ghost: TubeLauncher
var _hatch_ghost: DumpHatch
var _drone_ghost: HayDrone
var _rake_ghost: PistonRake
var _splitter_ghost: ConveyorSplitter
var _compact_splitter_ghost: ConveyorCompactSplitter


var _enclosed_section: Mesh
var _smart_splitter_ghost: ConveyorCompactSplitter
var _joiner_ghost: ConveyorJoiner
var _u_splitter_ghost: ConveyorUSplitter
var _u_joiner_ghost: ConveyorUJoiner
var _t_splitter_ghost: ConveyorTSplitter
var _cabinet_ghost: NeedleCabinet
var _radar_ghost: NeedleRadar
var _paintboard_ghost: PaintBoard
var _worklamp_ghost: WorkLamp
var _stairs_ghost: HayStairs
var _lift_ghost: HayLift
var _eval:= { "ok": false, "reason": "", "length": 0.0, "cost": 0.0 }


var shed_refusals:= 0

var _shed_hit:= false


var _joined:= false


var _finished_at:= Vector3.INF


var _route:= PackedVector3Array()


var _run_blocker:= ""


var _bare_knees:= PackedVector3Array()
var _router: BeltRouter

var _route_picks: Array [Dictionary] = []


var _route_sig:= ""
var _route_pinned:= false

var _route_from:= Vector3.INF
var _route_to:= Vector3.INF
var _route_yard:= -1

var _route_age:= INF


var _pipe_ghost: MultiMeshInstance3D


var _pipe_bend_ghost: MultiMeshInstance3D


var _pipe_preview_bend:= PackedByteArray()


var _wye_ghost: WaterSplitter
var _wye_probe: BoxShape3D
var _wye_probe_query: PhysicsShapeQueryParameters3D


var _guide_turn:= NAN
var _probe: BoxShape3D
var _probe_query: PhysicsShapeQueryParameters3D
var _arm_probe: CylinderShape3D
var _arm_probe_query: PhysicsShapeQueryParameters3D
var _deck_probe: BoxShape3D
var _deck_probe_query: PhysicsShapeQueryParameters3D
var _cabinet_probe: BoxShape3D
var _cabinet_probe_query: PhysicsShapeQueryParameters3D
var _radar_probe: BoxShape3D
var _radar_probe_query: PhysicsShapeQueryParameters3D
var _board_probe: BoxShape3D
var _board_probe_query: PhysicsShapeQueryParameters3D
var _stairs_probe: BoxShape3D
var _stairs_probe_query: PhysicsShapeQueryParameters3D
var _lift_probe: BoxShape3D
var _lift_probe_query: PhysicsShapeQueryParameters3D
var _scanner_probe: BoxShape3D
var _scanner_probe_query: PhysicsShapeQueryParameters3D
var _compressor_probe: BoxShape3D
var _pulper_probe: BoxShape3D
var _paper_probe: BoxShape3D


var _briquette_probe: BoxShape3D
var _briquette_arm_probe: BoxShape3D
var _pelletizer_probe: BoxShape3D
var _pelletizer_probe_query: PhysicsShapeQueryParameters3D
var _generator_probe: BoxShape3D
var _generator_probe_query: PhysicsShapeQueryParameters3D
var _borehole_probe: BoxShape3D
var _borehole_probe_query: PhysicsShapeQueryParameters3D
var _launcher_probe: BoxShape3D
var _launcher_probe_query: PhysicsShapeQueryParameters3D
var _hatch_probe: BoxShape3D
var _hatch_probe_query: PhysicsShapeQueryParameters3D
var _compressor_probe_query: PhysicsShapeQueryParameters3D
var _pulper_probe_query: PhysicsShapeQueryParameters3D
var _paper_probe_query: PhysicsShapeQueryParameters3D
var _briquette_probe_query: PhysicsShapeQueryParameters3D
var _briquette_arm_query: PhysicsShapeQueryParameters3D
var _wrapper_probe: BoxShape3D
var _wrapper_probe_query: PhysicsShapeQueryParameters3D
var _silo_probe: BoxShape3D
var _silo_probe_query: PhysicsShapeQueryParameters3D
var _drone_probe: BoxShape3D
var _drone_probe_query: PhysicsShapeQueryParameters3D
var _rake_probe: BoxShape3D
var _rake_probe_query: PhysicsShapeQueryParameters3D

var _rake_drive_probe: BoxShape3D
var _rake_drive_query: PhysicsShapeQueryParameters3D
var _splitter_probe: BoxShape3D
var _splitter_probe_query: PhysicsShapeQueryParameters3D
var _joiner_probe: BoxShape3D
var _joiner_probe_query: PhysicsShapeQueryParameters3D


func _ready() -> void:


	_preview_usec = Time.get_ticks_usec()
	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_follow_tech)
	_follow_tech()
	_reset_reach()
	_probe = BoxShape3D.new()
	_probe_query = PhysicsShapeQueryParameters3D.new()
	_probe_query.shape = _probe


	_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_probe_query.collide_with_areas = false

	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ConveyorKit.segment_mesh()


	mm.instance_count = GHOST_CAPACITY
	mm.visible_instance_count = 0
	_ghost = MultiMeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.multimesh = mm
	_ghost.top_level = true
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	for side: int in [-1, 1]:
		var rail_mm:= MultiMesh.new()
		rail_mm.transform_format = MultiMesh.TRANSFORM_3D
		rail_mm.mesh = ConveyorKit.rail_mesh(side)
		rail_mm.instance_count = GHOST_CAPACITY
		rail_mm.visible_instance_count = 0
		var rail:= MultiMeshInstance3D.new()
		rail.name = "GhostRail%s" % ("R" if side > 0 else "L")
		rail.multimesh = rail_mm
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.add_child(rail)
		_ghost_rails.append(rail)
	for head: bool in [false, true]:
		var drum_mm:= MultiMesh.new()
		drum_mm.transform_format = MultiMesh.TRANSFORM_3D
		drum_mm.mesh = ConveyorKit.nose_mesh(head)
		drum_mm.instance_count = GHOST_DRUMS
		drum_mm.visible_instance_count = 0
		var drum:= MultiMeshInstance3D.new()
		drum.name = "GhostHeadDrums" if head else "GhostTailDrums"
		drum.multimesh = drum_mm
		drum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.add_child(drum)
		_ghost_drums.append(drum)


	var flow_mm:= MultiMesh.new()
	flow_mm.transform_format = MultiMesh.TRANSFORM_3D
	flow_mm.use_colors = true
	flow_mm.mesh = ConveyorKit.flow_arrow_mesh()
	flow_mm.instance_count = ARROW_CAPACITY
	flow_mm.visible_instance_count = 0
	_flow = MultiMeshInstance3D.new()
	_flow.name = "Flow"
	_flow.multimesh = flow_mm
	_flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	_flow.material_override = ConveyorKit.flow_material()


	_ghost.add_child(_flow)


	var hint_mm:= MultiMesh.new()
	hint_mm.transform_format = MultiMesh.TRANSFORM_3D
	hint_mm.use_colors = true
	hint_mm.mesh = ConveyorKit.flow_arrow_mesh()
	hint_mm.instance_count = ENCLOSED_HINT_CAPACITY
	hint_mm.visible_instance_count = 0
	_hint_flow = MultiMeshInstance3D.new()
	_hint_flow.name = "EnclosedHint"
	_hint_flow.multimesh = hint_mm
	_hint_flow.top_level = true
	_hint_flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hint_flow.material_override = ConveyorKit.flow_material()
	_hint_flow.visible = false
	add_child(_hint_flow)


	var pipe_mm:= MultiMesh.new()
	pipe_mm.transform_format = MultiMesh.TRANSFORM_3D
	pipe_mm.mesh = PipeKit.section_mesh()
	pipe_mm.instance_count = GHOST_CAPACITY
	pipe_mm.visible_instance_count = 0
	_pipe_ghost = MultiMeshInstance3D.new()
	_pipe_ghost.name = "PipeGhost"
	_pipe_ghost.multimesh = pipe_mm
	_pipe_ghost.top_level = true
	_pipe_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pipe_ghost.visible = false
	add_child(_pipe_ghost)
	var bend_mm:= MultiMesh.new()
	bend_mm.transform_format = MultiMesh.TRANSFORM_3D
	bend_mm.mesh = PipeKit.bend_mesh()
	bend_mm.instance_count = GHOST_CAPACITY
	bend_mm.visible_instance_count = 0
	_pipe_bend_ghost = MultiMeshInstance3D.new()
	_pipe_bend_ghost.name = "PipeBendGhost"
	_pipe_bend_ghost.multimesh = bend_mm
	_pipe_bend_ghost.top_level = true
	_pipe_bend_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pipe_bend_ghost.visible = false
	add_child(_pipe_bend_ghost)
	await _between_previews()

	_wye_probe = BoxShape3D.new()
	_wye_probe_query = PhysicsShapeQueryParameters3D.new()
	_wye_probe_query.shape = _wye_probe
	_wye_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_wye_probe_query.collide_with_areas = false

	_wye_ghost = WaterSplitter.new()
	_wye_ghost.name = "WaterSplitterGhost"
	_wye_ghost.placement_preview = true
	add_child(_wye_ghost)
	_wye_ghost.top_level = true
	_wye_ghost.visible = false
	await _between_previews()

	_arm_probe = CylinderShape3D.new()
	_arm_probe_query = PhysicsShapeQueryParameters3D.new()
	_arm_probe_query.shape = _arm_probe
	_arm_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_arm_probe_query.collide_with_areas = false

	_deck_probe = BoxShape3D.new()
	_deck_probe_query = PhysicsShapeQueryParameters3D.new()
	_deck_probe_query.shape = _deck_probe
	_deck_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_deck_probe_query.collide_with_areas = false

	_rebuild_arm_ghost()
	await _between_previews()


	_grid_mesh = MeshInstance3D.new()
	_grid_mesh.name = "BuildGrid"
	var plate:= PlaneMesh.new()
	var across:= Cfg.BUILD_GRID_RADIUS * 2.0
	plate.size = Vector2(across, across)
	_grid_mesh.mesh = plate
	_grid_mat = ShaderMaterial.new()
	_grid_mat.shader = load("res://assets/build_grid.gdshader")
	_grid_mat.set_shader_parameter("step_size", Cfg.BUILD_GRID_STEP)
	_grid_mesh.material_override = _grid_mat
	_grid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


	_grid_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_grid_mesh.top_level = true
	_grid_mesh.visible = false
	add_child(_grid_mesh)


	_deck_ghost = Platform.new()
	_deck_ghost.name = "PlatformGhost"
	_deck_ghost.placement_preview = true
	add_child(_deck_ghost)
	_deck_ghost.top_level = true
	_deck_ghost.visible = false
	await _between_previews()

	_stair_ghost = Stair.new()
	_stair_ghost.name = "StairGhost"
	_stair_ghost.placement_preview = true
	add_child(_stair_ghost)
	_stair_ghost.top_level = true
	_stair_ghost.visible = false
	await _between_previews()

	_rail_ghost = Railing.new()
	_rail_ghost.name = "RailingGhost"
	_rail_ghost.placement_preview = true
	add_child(_rail_ghost)
	_rail_ghost.top_level = true
	_rail_ghost.visible = false
	await _between_previews()


	_wall_ghost = YardWall.new()
	_wall_ghost.name = "WallGhost"
	_wall_ghost.placement_preview = true
	add_child(_wall_ghost)
	_wall_ghost.top_level = true
	_wall_ghost.visible = false
	await _between_previews()


	_roof_ghost = Roof.new()
	_roof_ghost.name = "RoofGhost"
	_roof_ghost.placement_preview = true
	add_child(_roof_ghost)
	_roof_ghost.top_level = true
	_roof_ghost.visible = false
	await _between_previews()

	_cabinet_probe = BoxShape3D.new()
	_cabinet_probe_query = PhysicsShapeQueryParameters3D.new()
	_cabinet_probe_query.shape = _cabinet_probe
	_cabinet_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_cabinet_probe_query.collide_with_areas = false
	_radar_probe = BoxShape3D.new()
	_radar_probe_query = PhysicsShapeQueryParameters3D.new()
	_radar_probe_query.shape = _radar_probe
	_radar_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_radar_probe_query.collide_with_areas = false
	_board_probe = BoxShape3D.new()
	_board_probe_query = PhysicsShapeQueryParameters3D.new()
	_board_probe_query.shape = _board_probe
	_board_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_board_probe_query.collide_with_areas = false
	_stairs_probe = BoxShape3D.new()
	_stairs_probe_query = PhysicsShapeQueryParameters3D.new()
	_stairs_probe_query.shape = _stairs_probe
	_stairs_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_stairs_probe_query.collide_with_areas = false
	_lift_probe = BoxShape3D.new()
	_lift_probe_query = PhysicsShapeQueryParameters3D.new()
	_lift_probe_query.shape = _lift_probe
	_lift_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_lift_probe_query.collide_with_areas = false
	_scanner_probe = BoxShape3D.new()
	_scanner_probe_query = PhysicsShapeQueryParameters3D.new()
	_scanner_probe_query.shape = _scanner_probe
	_scanner_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_scanner_probe_query.collide_with_areas = false

	await _preview_at_load(Mode.SCANNER)

	_pelletizer_probe = BoxShape3D.new()
	_pelletizer_probe_query = PhysicsShapeQueryParameters3D.new()
	_pelletizer_probe_query.shape = _pelletizer_probe
	_pelletizer_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_pelletizer_probe_query.collide_with_areas = false

	_borehole_probe = BoxShape3D.new()
	_borehole_probe_query = PhysicsShapeQueryParameters3D.new()
	_borehole_probe_query.shape = _borehole_probe
	_borehole_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_borehole_probe_query.collide_with_areas = false

	_generator_probe = BoxShape3D.new()
	_generator_probe_query = PhysicsShapeQueryParameters3D.new()
	_generator_probe_query.shape = _generator_probe
	_generator_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_generator_probe_query.collide_with_areas = false

	_launcher_probe = BoxShape3D.new()
	_launcher_probe_query = PhysicsShapeQueryParameters3D.new()
	_launcher_probe_query.shape = _launcher_probe
	_launcher_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_launcher_probe_query.collide_with_areas = false
	_hatch_probe = BoxShape3D.new()
	_hatch_probe_query = PhysicsShapeQueryParameters3D.new()
	_hatch_probe_query.shape = _hatch_probe


	_hatch_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_hatch_probe_query.collide_with_areas = false
	_pulper_probe = BoxShape3D.new()
	_pulper_probe_query = PhysicsShapeQueryParameters3D.new()
	_pulper_probe_query.shape = _pulper_probe
	_pulper_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_pulper_probe_query.collide_with_areas = false
	_paper_probe = BoxShape3D.new()
	_paper_probe_query = PhysicsShapeQueryParameters3D.new()
	_paper_probe_query.shape = _paper_probe
	_paper_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_paper_probe_query.collide_with_areas = false
	_briquette_probe = BoxShape3D.new()
	_briquette_probe_query = PhysicsShapeQueryParameters3D.new()
	_briquette_probe_query.shape = _briquette_probe
	_briquette_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_briquette_probe_query.collide_with_areas = false
	_briquette_arm_probe = BoxShape3D.new()
	_briquette_arm_query = PhysicsShapeQueryParameters3D.new()
	_briquette_arm_query.shape = _briquette_arm_probe
	_briquette_arm_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_briquette_arm_query.collide_with_areas = false
	_compressor_probe = BoxShape3D.new()
	_compressor_probe_query = PhysicsShapeQueryParameters3D.new()
	_compressor_probe_query.shape = _compressor_probe
	_compressor_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_compressor_probe_query.collide_with_areas = false
	_wrapper_probe = BoxShape3D.new()
	_wrapper_probe_query = PhysicsShapeQueryParameters3D.new()
	_wrapper_probe_query.shape = _wrapper_probe
	_wrapper_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_wrapper_probe_query.collide_with_areas = false

	await _preview_at_load(Mode.PELLETIZER)
	await _preview_at_load(Mode.GENERATOR)
	await _preview_at_load(Mode.GAS_PLANT)
	await _preview_at_load(Mode.BOREHOLE)


	_pole_ghost = PowerPole.new()
	_pole_ghost.name = "PowerPoleGhost"
	_pole_ghost.placement_preview = true
	add_child(_pole_ghost)
	_pole_ghost.top_level = true
	_pole_ghost.visible = false
	await _between_previews()


	_pole_wire_mesh = MeshInstance3D.new()
	_pole_wire_mesh.name = "PowerPoleGhostWires"
	_pole_wire_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pole_wire_mesh.top_level = true
	_pole_wire_mesh.visible = false
	add_child(_pole_wire_mesh)


	_pole_ring = MeshInstance3D.new()
	_pole_ring.name = "PowerPoleGhostRing"
	_pole_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pole_ring.mesh = HayDrone.ring_mesh(Cfg.POLE_SUPPLY_R, RakeRange.BAND, 96)
	_pole_ring_mat = StandardMaterial3D.new()
	_pole_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pole_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


	_pole_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pole_ring_mat.no_depth_test = true
	_pole_ring_mat.render_priority = 4
	_pole_ring.material_override = _pole_ring_mat
	_pole_ring.top_level = true
	_pole_ring.visible = false
	add_child(_pole_ring)
	_pole_ring_r = Cfg.POLE_SUPPLY_R


	_pole_probe = BoxShape3D.new()
	_pole_probe_query = PhysicsShapeQueryParameters3D.new()
	_pole_probe_query.shape = _pole_probe
	_pole_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_pole_probe_query.collide_with_areas = false

	_box_ghost = PowerBox.new()
	_box_ghost.name = "PowerBoxGhost"
	_box_ghost.placement_preview = true
	add_child(_box_ghost)
	_box_ghost.top_level = true
	_box_ghost.visible = false
	await _between_previews()

	_pole_trace_mesh = MeshInstance3D.new()
	_pole_trace_mesh.name = "PowerBoxGhostTraces"
	_pole_trace_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pole_trace_mesh.material_override = CableTrace.x_ray_material()
	_pole_trace_mesh.top_level = true
	_pole_trace_mesh.visible = false
	add_child(_pole_trace_mesh)

	await _preview_at_load(Mode.LAUNCHER)
	_hatch_ghost = DumpHatch.new()
	_hatch_ghost.name = "DumpHatchGhost"
	_hatch_ghost.placement_preview = true
	add_child(_hatch_ghost)
	_hatch_ghost.top_level = true
	_hatch_ghost.visible = false
	await _between_previews()

	await _preview_at_load(Mode.COMPRESSOR)
	await _preview_at_load(Mode.PULPER)
	await _preview_at_load(Mode.PAPER)
	await _preview_at_load(Mode.BRIQUETTE)
	await _preview_at_load(Mode.WRAPPER)

	_silo_probe = BoxShape3D.new()
	_silo_probe_query = PhysicsShapeQueryParameters3D.new()
	_silo_probe_query.shape = _silo_probe
	_silo_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_silo_probe_query.collide_with_areas = false

	await _preview_at_load(Mode.SILO)

	_splitter_probe = BoxShape3D.new()
	_splitter_probe_query = PhysicsShapeQueryParameters3D.new()
	_splitter_probe_query.shape = _splitter_probe
	_splitter_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_splitter_probe_query.collide_with_areas = false


	_splitter_ghost = ConveyorSplitter.new()
	_splitter_ghost.name = "SplitterGhost"
	_splitter_ghost.placement_preview = true
	add_child(_splitter_ghost)
	_splitter_ghost.top_level = true
	_splitter_ghost.visible = false
	await _between_previews()

	_compact_splitter_ghost = ConveyorCompactSplitter.new()
	_compact_splitter_ghost.name = "CompactSplitterGhost"
	_compact_splitter_ghost.placement_preview = true
	add_child(_compact_splitter_ghost)
	_compact_splitter_ghost.top_level = true
	_compact_splitter_ghost.visible = false
	await _between_previews()

	_smart_splitter_ghost = ConveyorCompactSplitter.new()
	_smart_splitter_ghost.name = "SmartSplitterGhost"
	_smart_splitter_ghost.smart = true
	_smart_splitter_ghost.placement_preview = true
	add_child(_smart_splitter_ghost)
	_smart_splitter_ghost.top_level = true
	_smart_splitter_ghost.visible = false
	await _between_previews()

	_joiner_probe = BoxShape3D.new()
	_joiner_probe_query = PhysicsShapeQueryParameters3D.new()
	_joiner_probe_query.shape = _joiner_probe
	_joiner_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_PLAYER | Cfg.L_KEEPOUT
	_joiner_probe_query.collide_with_areas = false


	_joiner_ghost = ConveyorJoiner.new()
	_joiner_ghost.name = "JoinerGhost"
	_joiner_ghost.placement_preview = true
	add_child(_joiner_ghost)
	_joiner_ghost.top_level = true
	_joiner_ghost.visible = false
	await _between_previews()


	_u_splitter_ghost = ConveyorUSplitter.new()
	_u_splitter_ghost.name = "USplitterGhost"
	_u_splitter_ghost.placement_preview = true
	add_child(_u_splitter_ghost)
	_u_splitter_ghost.top_level = true
	_u_splitter_ghost.visible = false
	await _between_previews()

	_u_joiner_ghost = ConveyorUJoiner.new()
	_u_joiner_ghost.name = "UJoinerGhost"
	_u_joiner_ghost.placement_preview = true
	add_child(_u_joiner_ghost)
	_u_joiner_ghost.top_level = true
	_u_joiner_ghost.visible = false
	await _between_previews()


	_make_t_splitter_ghost()
	await _between_previews()

	_drone_probe = BoxShape3D.new()
	_drone_probe_query = PhysicsShapeQueryParameters3D.new()
	_drone_probe_query.shape = _drone_probe
	_drone_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_KEEPOUT
	_drone_probe_query.collide_with_areas = false


	_drone_ghost = HayDrone.new()
	_drone_ghost.name = "DroneGhost"
	_drone_ghost.placement_preview = true
	add_child(_drone_ghost)
	_drone_ghost.top_level = true
	_drone_ghost.visible = false
	await _between_previews()


	_rake_probe = BoxShape3D.new()
	_rake_probe_query = PhysicsShapeQueryParameters3D.new()
	_rake_probe_query.shape = _rake_probe
	_rake_probe_query.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_KEEPOUT
	_rake_probe_query.collide_with_areas = false

	await _preview_at_load(Mode.PISTON_RAKE)
	await _preview_at_load(Mode.CABINET)
	await _preview_at_load(Mode.NEEDLE_RADAR)


	_paintboard_ghost = PaintBoard.new()
	_paintboard_ghost.name = "PaintBoardGhost"
	_paintboard_ghost.placement_preview = true
	add_child(_paintboard_ghost)
	_paintboard_ghost.top_level = true
	_paintboard_ghost.visible = false
	await _between_previews()


	_worklamp_ghost = WorkLamp.new()
	_worklamp_ghost.name = "WorkLampGhost"
	_worklamp_ghost.placement_preview = true
	add_child(_worklamp_ghost)
	_worklamp_ghost.top_level = true
	_worklamp_ghost.visible = false
	await _between_previews()

	_stairs_ghost = HayStairs.new()
	_stairs_ghost.name = "HayStairsGhost"
	_stairs_ghost.placement_preview = true
	add_child(_stairs_ghost)
	_stairs_ghost.top_level = true
	_stairs_ghost.visible = false
	await _between_previews()

	await _preview_at_load(Mode.HAY_LIFT)

	previews_ready = true
	previews_built.emit()


func _preview_at_load(mode: Mode) -> void:
	if player != null and player.defer_tools and not _mode_unlocked(mode):
		return


	if _mode_withheld(mode):
		return
	_make_preview(mode)
	await _between_previews()


static func _mode_withheld(mode: Mode) -> bool:
	var found:= false
	for id: String in BuildCatalog.ids():
		if int(BuildCatalog.spec(id).get("mode", -1)) != mode:
			continue
		if not BuildCatalog.is_withheld(id):
			return false
		found = true
	return found


static func _mode_unlocked(mode: Mode) -> bool:
	for id: String in BuildCatalog.ids():
		if int(BuildCatalog.spec(id).get("mode", -1)) == mode and BuildCatalog.is_unlocked(id):
			return true
	return false


func _make_preview(mode: Mode) -> void:
	match mode:
		Mode.SCANNER:


			if _scanner_ghost == null:
				_scanner_ghost = HaystackScanner.new()
				_scanner_ghost.tier_index = _scanner_tier
				_park_preview(_scanner_ghost, "ScannerGhost")
		Mode.PELLETIZER:


			if _pelletizer_ghost == null:
				_pelletizer_ghost = HayPelletizer.new()
				_park_preview(_pelletizer_ghost, "PelletizerGhost")
		Mode.GENERATOR:


			if _generator_ghost == null:
				_generator_ghost = HayGenerator.new()
				_park_preview(_generator_ghost, "GeneratorGhost")
		Mode.GAS_PLANT:

			if _plant_ghost == null:
				_plant_ghost = GasPlant.new()
				_park_preview(_plant_ghost, "GasPlantGhost")
		Mode.BOREHOLE:


			if _borehole_ghost == null:
				_borehole_ghost = BoreholePump.new()
				_park_preview(_borehole_ghost, "BoreholeGhost")
		Mode.LAUNCHER:
			if _launcher_ghost == null:
				_launcher_ghost = TubeLauncher.new()
				_park_preview(_launcher_ghost, "LauncherGhost")
		Mode.COMPRESSOR:
			if _compressor_ghost == null:
				_compressor_ghost = HayCompressor.new()
				_park_preview(_compressor_ghost, "CompressorGhost")
		Mode.PULPER:
			if _pulper_ghost == null:
				_pulper_ghost = HayPulper.new()
				_park_preview(_pulper_ghost, "PulperGhost")
		Mode.PAPER:
			if _paper_ghost == null:
				_paper_ghost = PaperMachine.new()
				_park_preview(_paper_ghost, "PaperGhost")
		Mode.BRIQUETTE:
			if _briquette_ghost == null:
				_briquette_ghost = BriquettePress.new()
				_park_preview(_briquette_ghost, "BriquetteGhost")
		Mode.WRAPPER:
			if _wrapper_ghost == null:
				_wrapper_ghost = HayWrapper.new()
				_park_preview(_wrapper_ghost, "WrapperGhost")
		Mode.SILO:
			if _silo_ghost == null:
				_silo_ghost = HaySilo.new()
				_park_preview(_silo_ghost, "SiloGhost")
		Mode.PISTON_RAKE:
			if _rake_ghost == null:
				_rake_ghost = PistonRake.new()
				_park_preview(_rake_ghost, "RakeGhost")
		Mode.CABINET:


			if _cabinet_ghost == null:
				_cabinet_ghost = NeedleCabinet.new()
				_park_preview(_cabinet_ghost, "CabinetGhost")
		Mode.NEEDLE_RADAR:


			if _radar_ghost == null:
				_radar_ghost = NeedleRadar.new()
				_park_preview(_radar_ghost, "RadarGhost")
		Mode.HAY_LIFT:


			if _lift_ghost == null:
				_lift_ghost = HayLift.new()
				_lift_ghost.sections = 0
				_park_preview(_lift_ghost, "HayLiftGhost")


func _park_preview(ghost: Node3D, ghost_name: String) -> void:
	ghost.name = ghost_name
	ghost.set("placement_preview", true)
	add_child(ghost)
	ghost.top_level = true
	ghost.visible = false


func _between_previews() -> void:
	if player == null or not player.defer_tools:
		return
	var now:= Time.get_ticks_usec()
	if _preview_usec > 0 and now - _preview_usec >= 50000:
		print("[load]   preview %s: %.0f ms" % [get_child(get_child_count() - 1).name,
			(now - _preview_usec) / 1000.0])
	await get_tree().process_frame
	_preview_usec = Time.get_ticks_usec()


func _rebuild_arm_ghost() -> void:
	if _arm_ghost != null:
		remove_child(_arm_ghost)
		_arm_ghost.queue_free()
	_arm_ghost = RoboticArm.new()
	_arm_ghost.name = "RoboticArmGhost"
	_arm_ghost.placement_preview = true
	_arm_ghost.tier_index = _arm_tier
	add_child(_arm_ghost)
	_arm_ghost.top_level = true
	_arm_ghost.visible = _active and _mode == Mode.ROBOTIC_ARM


static func _run_group(mode: Mode) -> int:
	match mode:
		Mode.CONVEYOR, Mode.ENCLOSED_CONVEYOR:
			return 0
		Mode.WALL, Mode.WALL_WINDOW, Mode.WALL_DOOR:
			return 1
		Mode.ROOF, Mode.ROOF_PITCH:
			return 2
	return -1


func set_mode(mode: Mode) -> void:
	_mode = mode


	_make_preview(mode)
	_state = State.AIMING
	_finished_at = Vector3.INF


	_roof_turn = 0
	_ghost_turn = 0
	_t_turn = 0


	_grid_on = false
	_snap_off = false


	_reset_reach()
	if mode == Mode.ROBOTIC_ARM:
		set_arm_tier(_hand_arm_tier())
	_sync_ghosts()


func _reset_reach() -> void:
	_reach = Cfg.BUILD_REACH + Tech.build_reach_bonus()


func _on_tech_changed(_id: String, _rank: int) -> void:
	_follow_tech()


func _follow_tech() -> void:
	set_arm_tier(_hand_arm_tier())
	set_scanner_tier(Tech.max_scanner_tier())


func _hand_arm_tier() -> int:
	var tier:= BuildCatalog.arm_tier_of(player.build_id) if player != null else -1
	return tier if tier >= 0 else Tech.max_arm_tier()


func set_arm_tier(tier: int) -> void:
	var next:= clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)
	if next == _arm_tier:
		return
	_arm_tier = next
	_rebuild_arm_ghost()


func set_scanner_tier(tier: int) -> void:
	_scanner_tier = clampi(tier, 0, Cfg.SCANNER_TIERS.size() - 1)
	if _scanner_ghost != null:
		_scanner_ghost.tier_index = _scanner_tier


func _scanner_cost() -> float:
	return float(Cfg.SCANNER_TIERS [_scanner_tier] ["cost"])


func set_active(on: bool) -> void:


	var raised:= on and not _active
	_active = on
	if raised:
		_reset_reach()
	_sync_ghosts()
	if not on:
		_state = State.AIMING


func is_active() -> bool:
	return _active


func _sync_ghosts() -> void:


	if not _borrows_flow(_mode) or not _active:
		_ghost.visible = _active and _is_conveyor_mode()
	_fit_run_ghost_mesh()
	if _arm_ghost != null:
		_arm_ghost.visible = _active and _mode == Mode.ROBOTIC_ARM
	if _deck_ghost != null:
		_deck_ghost.visible = _active and _mode == Mode.PLATFORM
	if _stair_ghost != null:
		_stair_ghost.visible = _active and _mode == Mode.STAIR
	if _rail_ghost != null:
		_rail_ghost.visible = _active and _mode == Mode.RAILING
	if _wall_ghost != null:
		_wall_ghost.visible = _active and _is_wall(_mode)
	if _roof_ghost != null:
		_roof_ghost.visible = _active and _is_roof(_mode)
	if _scanner_ghost != null:
		_scanner_ghost.visible = _active and _mode == Mode.SCANNER
	if _compressor_ghost != null:
		_compressor_ghost.visible = _active and _mode == Mode.COMPRESSOR
	if _pulper_ghost != null:
		_pulper_ghost.visible = _active and _mode == Mode.PULPER
	if _paper_ghost != null:
		_paper_ghost.visible = _active and _mode == Mode.PAPER
	if _briquette_ghost != null:
		_briquette_ghost.visible = _active and _mode == Mode.BRIQUETTE
	if _wrapper_ghost != null:
		_wrapper_ghost.visible = _active and _mode == Mode.WRAPPER
	if _silo_ghost != null:
		_silo_ghost.visible = _active and _mode == Mode.SILO
	if _pelletizer_ghost != null:
		_pelletizer_ghost.visible = _active and _mode == Mode.PELLETIZER
	if _generator_ghost != null:
		_generator_ghost.visible = _active and _mode == Mode.GENERATOR
	if _plant_ghost != null:
		_plant_ghost.visible = _active and _mode == Mode.GAS_PLANT
	if _borehole_ghost != null:
		_borehole_ghost.visible = _active and _mode == Mode.BOREHOLE
	if _pipe_ghost != null:
		_pipe_ghost.visible = _active and _mode == Mode.WATER_PIPE
		_pipe_bend_ghost.visible = _pipe_ghost.visible
	if _wye_ghost != null:
		_wye_ghost.visible = _active and _mode == Mode.WATER_SPLITTER
	var poling:= _active and _is_post(_mode)
	if _pole_ghost != null:
		_pole_ghost.visible = _active and _mode == Mode.POWER_POLE
	if _box_ghost != null:
		_box_ghost.visible = _active and _mode == Mode.POWER_BOX
	if _pole_ring != null:
		_pole_ring.visible = poling
	if _pole_wire_mesh != null:
		_pole_wire_mesh.visible = poling and _pole_wire_mesh.mesh != null
	if _pole_trace_mesh != null:
		_pole_trace_mesh.visible = poling and _pole_trace_mesh.mesh != null


	CableTrace.reveal(get_tree(), "held", _active and _mode == Mode.POWER_BOX)


	if not poling:
		_clear_pole_tint()

	if not (_active and _mode == Mode.ROBOTIC_ARM):
		_tint_arm_blockers([] as Array [Node3D])
	if _launcher_ghost != null:
		_launcher_ghost.visible = _active and _mode == Mode.LAUNCHER
	if _hatch_ghost != null:
		_hatch_ghost.visible = _active and _mode == Mode.DUMP_HATCH
	if _splitter_ghost != null:
		_splitter_ghost.visible = _active and _mode == Mode.SPLITTER
	if _compact_splitter_ghost != null:
		_compact_splitter_ghost.visible = _active and _mode == Mode.COMPACT_SPLITTER
	if _smart_splitter_ghost != null:
		_smart_splitter_ghost.visible = _active and _mode == Mode.SMART_SPLITTER
	if _joiner_ghost != null:
		_joiner_ghost.visible = _active and _mode == Mode.JOINER
	if _u_splitter_ghost != null:
		_u_splitter_ghost.visible = _active and _mode == Mode.U_SPLITTER
	if _u_joiner_ghost != null:
		_u_joiner_ghost.visible = _active and _mode == Mode.U_JOINER
	if _t_splitter_ghost != null:
		_t_splitter_ghost.visible = _active and _mode == Mode.T_SPLITTER
	if _cabinet_ghost != null:
		_cabinet_ghost.visible = _active and _mode == Mode.CABINET
	if _radar_ghost != null:
		_radar_ghost.visible = _active and _mode == Mode.NEEDLE_RADAR
	if _paintboard_ghost != null:
		_paintboard_ghost.visible = _active and _mode == Mode.PAINT_BOARD
	if _worklamp_ghost != null:
		_worklamp_ghost.visible = _active and _mode == Mode.WORK_LAMP
	if _stairs_ghost != null:
		_stairs_ghost.visible = _active and _mode == Mode.HAY_STAIRS
	if _lift_ghost != null:
		_lift_ghost.visible = _active and _mode == Mode.HAY_LIFT
	if _drone_ghost != null:
		_drone_ghost.visible = _active and _mode == Mode.HAY_DRONE
	if _rake_ghost != null:
		_rake_ghost.visible = _active and _mode == Mode.PISTON_RAKE


	if _grid_mesh != null and not (_active and (_gridding() or _levelling())):
		_grid_mesh.visible = false


static func _borrows_flow(mode: Mode) -> bool:
	return mode == Mode.SCANNER or mode == Mode.SPLITTER or mode == Mode.JOINER or mode == Mode.U_SPLITTER or mode == Mode.U_JOINER or mode == Mode.GENERATOR or mode == Mode.GAS_PLANT or mode == Mode.T_SPLITTER or mode == Mode.COMPACT_SPLITTER or mode == Mode.SMART_SPLITTER


static func _is_post(mode: Mode) -> bool:
	return mode == Mode.POWER_POLE or mode == Mode.POWER_BOX


func _post_ghost() -> PowerPole:
	return _box_ghost if _mode == Mode.POWER_BOX else _pole_ghost


func status() -> Dictionary:
	if _mode == Mode.PISTON_RAKE:
		return {
			"kind": "piston_rake",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"gift": _eval.get("gift", false),
			"reach": _reach,


			"count": builds.piston_rakes.size(),
			"limit": Cfg.RAKE_LIMIT,
			"free": Cfg.RAKE_COST_FREE,
		}
	if _mode == Mode.HAY_DRONE:
		return {
			"kind": "hay_drone",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"reach": _reach,
			"radius": Cfg.DRONE_RADIUS,


			"count": builds.hay_drones.size(),
			"limit": Cfg.DRONE_LIMIT,
			"free": Cfg.DRONE_COST_FREE,
		}
	if _mode == Mode.HAY_STAIRS:
		return {
			"kind": "haystairs",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.HAY_LIFT:


		return {
			"kind": "haylift",
			"placing": _state == State.RUNNING,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval.get("length", Cfg.HAY_LIFT_BASE_RISE),
			"sections": _eval.get("sections", 0),
			"cost": _eval ["cost"],
			"reach": _reach,


			"deck_gap": _eval.get("deck_gap", NAN),


			"deck_snap": _eval.get("deck_snap", false),
		}
	if _mode == Mode.NEEDLE_RADAR:
		return {
			"kind": "radar",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.CABINET:
		return {
			"kind": "cabinet",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"cost": _eval ["cost"],
			"gift": _eval.get("gift", false),
			"reach": _reach,
		}


	if _mode == Mode.PAINT_BOARD:
		return {
			"kind": "paintboard",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.WORK_LAMP:
		return {
			"kind": "worklamp",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.U_JOINER:
		return {
			"kind": "u_joiner",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.T_SPLITTER:
		return {
			"kind": "t_splitter",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
			"snapped": _eval.get("snapped", false),
			"straight": _eval.get("straight", false),
		}
	if _mode == Mode.COMPACT_SPLITTER or _mode == Mode.SMART_SPLITTER:
		return {
			"kind": "smart_splitter" if _mode == Mode.SMART_SPLITTER else "compact_splitter",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.U_SPLITTER:
		return {
			"kind": "u_splitter",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.JOINER:
		return {
			"kind": "joiner",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.SPLITTER:
		return {
			"kind": "splitter",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.PELLETIZER:
		var pellet_rate:= float(Tech.pellet_brick_strands()) / maxf(Tech.pellet_cycle_seconds(), 0.001)
		return {
			"kind": "pelletizer",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"reach": _reach,


			"rate": 3600.0 / maxf(Tech.pellet_cycle_seconds(), 0.001),
			"hay_rate": pellet_rate,
			"ratio": Tech.brick_value_ratio(),
			"income_min": Tech.income_per_minute(pellet_rate, Tech.brick_value_ratio()),
		}
	if _mode == Mode.BOREHOLE:


		return {
			"kind": "borehole",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"reach": _reach,
			"water_lps": Tech.borehole_output(),
			"draw_kw": Cfg.BOREHOLE_DRAW_KW,
		}
	if _mode == Mode.GAS_PLANT:


		return {
			"kind": "gas_plant",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"reach": _reach,
			"output_kw": Tech.gas_plant_output(),
			"water_lps": Tech.gas_plant_output() * Cfg.GAS_PLANT_LPS_PER_KW,
		}
	if _mode == Mode.GENERATOR:


		return {
			"kind": "generator",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"reach": _reach,
			"output_kw": Tech.generator_output(),
			"burn_min": Tech.generator_firebox_kj()
				/ maxf(Tech.generator_output(), 0.001) / 60.0,
		}
	if _is_post(_mode):
		return _pole_status()
	if _mode == Mode.DUMP_HATCH:


		return {
			"kind": "dump_hatch",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.LAUNCHER:


		return {
			"kind": "launcher",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"reach": _reach,
			"range": _launcher_ghost.range_metres() if _launcher_ghost != null else 0.0,
			"power": _launcher_ghost.power if _launcher_ghost != null else 0.0,
		}
	if _mode == Mode.COMPRESSOR:
		var press_rate:= float(Tech.compressor_bale_strands()) / maxf(Tech.compressor_press_seconds(), 0.001)
		return {
			"kind": "compressor",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": Cfg.COMPRESSOR_LENGTH,
			"cost": _eval ["cost"],
			"reach": _reach,


			"rate": 3600.0 / maxf(Tech.compressor_press_seconds(), 0.001),
			"hay_rate": press_rate,
			"ratio": Tech.bale_value_ratio(),
			"income_min": Tech.income_per_minute(press_rate, Tech.bale_value_ratio()),
		}
	if _mode == Mode.PULPER:
		var pulp_rate:= float(Tech.pulper_batch_strands()) / maxf(Tech.pulper_cycle_seconds(), 0.001)
		return {
			"kind": "pulper",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": Cfg.PULPER_LENGTH,
			"cost": _eval ["cost"],
			"reach": _reach,


			"hay_rate": pulp_rate,
			"water_lps": Cfg.PULPER_WATER_LITRES
				/ maxf(Tech.pulper_cycle_seconds(), 0.001),
			"ratio": Tech.pulp_value_ratio(),
			"income_min": Tech.income_per_minute(pulp_rate, Tech.pulp_value_ratio()),
		}
	if _mode == Mode.BRIQUETTE:


		var disc_strands:= float(Tech.briquette_batch_strands()
			+ Tech.briquette_batch_bricks() * Tech.pellet_brick_strands())
		var disc_rate:= disc_strands / maxf(Tech.briquette_cycle_seconds(), 0.001)
		return {
			"kind": "briquette",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": Cfg.BRIQUETTE_LENGTH,
			"cost": _eval ["cost"],
			"reach": _reach,
			"rate": 3600.0 / maxf(Tech.briquette_cycle_seconds(), 0.001),
			"hay_rate": disc_rate,


			"bricks": Tech.briquette_batch_bricks(),
			"strands": Tech.briquette_batch_strands(),
			"ratio": Tech.disc_value_ratio(),
			"income_min": Tech.income_per_minute(disc_rate, Tech.disc_value_ratio()),
		}
	if _mode == Mode.PAPER:


		var paper_ratio:= Tech.pulp_value_ratio() * Tech.paper_value_ratio()
		var paper_rate:= float(Tech.pulper_batch_strands()) / maxf(Tech.paper_cycle_seconds(), 0.001)
		return {
			"kind": "paper",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": Cfg.PAPER_LENGTH,
			"cost": _eval ["cost"],
			"reach": _reach,
			"rate": 3600.0 / maxf(Tech.paper_cycle_seconds(), 0.001),
			"hay_rate": paper_rate,
			"ratio": paper_ratio,
			"income_min": Tech.income_per_minute(paper_rate, paper_ratio),
		}
	if _mode == Mode.WRAPPER:


		var foil_ratio:= Tech.bale_value_ratio() * Cfg.WRAPPER_FOILED_RATIO
		var foil_rate:= float(Tech.compressor_bale_strands()) / maxf(Cfg.WRAPPER_SECONDS, 0.001)
		return {
			"kind": "wrapper",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": Cfg.WRAPPER_LENGTH,
			"cost": _eval ["cost"],
			"reach": _reach,
			"rate": 3600.0 / maxf(Tech.wrapper_seconds(), 0.001),
			"hay_rate": foil_rate,
			"ratio": foil_ratio,
			"income_min": Tech.income_per_minute(foil_rate, foil_ratio),
		}
	if _mode == Mode.SILO:


		return {
			"kind": "silo",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": Cfg.SILO_LENGTH,
			"cost": _eval ["cost"],
			"reach": _reach,
			"capacity": Tech.silo_capacity(),


			"rate_min": Cfg.SILO_RATE_MIN * 60.0,
			"rate_max": HaySilo.ceiling() * 60.0,
		}
	if _mode == Mode.SCANNER:
		var scanner_tier: Dictionary = Cfg.SCANNER_TIERS [_scanner_tier]
		var scan_rate:= float(Tech.scan_batch(int(scanner_tier ["batch"]))) / maxf(Tech.scan_seconds(float(scanner_tier ["scan_seconds"])), 0.001)
		var arm_rate:= Tech.arm_throughput(Tech.max_arm_tier()) if Tech.arm_unlocked() else 0.0
		return {
			"kind": "scanner",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": Cfg.SCANNER_LENGTH,
			"cost": _eval ["cost"],
			"reach": _reach,
			"tier_name": tr(str(scanner_tier ["name"])),


			"rate": scan_rate,
			"bottleneck": arm_rate > scan_rate,
			"arm_rate": arm_rate,
		}
	if _mode == Mode.ROBOTIC_ARM:
		var tier: Dictionary = Cfg.ROBOT_ARM_TIERS [_arm_tier]
		var arm_rate:= Tech.arm_throughput(_arm_tier)
		return {
			"kind": "robotic_arm",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": 0.0,
			"cost": _eval ["cost"],
			"reach": tier ["reach"],
			"tier_name": tr(str(tier ["name"])),
			"rate": arm_rate,
			"income_min": Tech.income_per_minute(arm_rate),
			"count": builds.robotic_arms.size(),
			"limit": Cfg.ARM_LIMIT,
			"free": Cfg.ARM_COST_FREE,


			"draw_kw": float(tier ["draw_kw"]),
			"spare_kw": _spare_kw(),


			"belts": arm_feeds.size(),
			"near": arm_feed_near,
			"tone": "good" if not arm_feeds.is_empty() else "warn",
		}
	if _is_wall(_mode):
		return {
			"kind": "wall",
			"placing": _state == State.RUNNING,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _is_roof(_mode):
		return {
			"kind": "roof",


			"placing": _state == State.RUNNING and _mode != Mode.ROOF_HATCH,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
			"rows": _roof_ghost.rows if _roof_ghost != null else 1,
		}
	if _mode == Mode.RAILING:
		return {
			"kind": "railing",
			"placing": _state == State.RUNNING,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	if _mode == Mode.STAIR:
		return {
			"kind": "stair",
			"placing": _state == State.RUNNING,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"angle": _eval.get("angle", 0.0),
			"reach": _reach,
		}
	if _mode == Mode.PLATFORM:
		return {
			"kind": "platform",
			"placing": _state == State.RUNNING,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
			"span": _deck_ghost.span if _deck_ghost != null else Vector2.ZERO,


			"up": _eval.get("up", NAN),
			"lift": _eval.get("lift", -1),
			"grid": _grid_on,
		}
	if _mode == Mode.WATER_PIPE:


		return {
			"kind": "water_pipe",
			"placing": _state == State.RUNNING,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,

			"done": _eval.get("done", false),
		}
	if _mode == Mode.WATER_SPLITTER:


		return {
			"kind": "water_splitter",
			"placing": false,
			"ok": _eval ["ok"],
			"reason": _eval ["reason"],
			"length": _eval ["length"],
			"cost": _eval ["cost"],
			"reach": _reach,
		}
	return {
		"kind": "conveyor",
		"placing": _state == State.RUNNING,
		"ok": _eval ["ok"],
		"reason": _eval ["reason"],
		"length": _eval ["length"],
		"cost": _eval ["cost"],
		"reach": _reach,
		"turn": _guide_turn,

		"bends": _eval.get("bends", 0),

		"done": _eval.get("done", false),


		"need": _eval.get("need", NAN),
	}


func _unhandled_input(event: InputEvent) -> void:


	if player != null and player.menu_is_up():
		return


	if event.is_action_pressed("dismantle"):
		_begin_dismantle()
		return


	if event.is_action_pressed("pick_build"):
		_copy_target()
		return
	if not _active:
		return
	if event.is_action_pressed("build_variant"):


		if player == null:
			return


		if _variant_from != player.build_id:
			_variant_family = -1
		_variant_family = BuildCatalog.family_of(player.build_id, _variant_family)
		var next:= BuildCatalog.next_variant(player.build_id, _variant_family)
		if next == "":
			return
		_variant_from = next


		var was:= _mode
		var keep:= _state == State.RUNNING and _run_group(was) >= 0 and _run_group(was) == _run_group(BuildCatalog.mode_of(next))
		var kept_turn:= _roof_turn
		var kept_grid:= _grid_on
		var kept_snap:= _snap_off
		var kept_reach:= _reach
		player.equip_build(next)
		if keep:
			_state = State.RUNNING
			_roof_turn = kept_turn
			_grid_on = kept_grid
			_snap_off = kept_snap
			_reach = kept_reach
			_sync_ghosts()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build_rotate"):


		if _is_roof(_mode):
			_roof_turn += 1
		elif can_turn():
			_ghost_turn = (_ghost_turn + 1) % 4
			if _mode == Mode.T_SPLITTER:
				_t_turn = (_t_turn + 1) % T_LEAVING_LAYOUTS.size()
		elif not next_route():


			return
		_turned_since_place = true
		turns += 1
		Audio.play("build_ghost")
		return
	if event.is_action_pressed("build_grid"):


		if not snaps_to_grid():
			return
		_grid_on = not _grid_on
		grids += 1
		Audio.play("build_ghost")
		return
	if event.is_action_pressed("build_no_snap"):


		if not can_stop_snapping():
			return
		_snap_off = not _snap_off
		Audio.play("build_ghost")


		get_viewport().set_input_as_handled()
		return


	if event.is_action_pressed("build_further", true):
		_reach = minf(Cfg.BUILD_REACH_MAX + Tech.build_reach_bonus(),
			_reach + Cfg.BUILD_REACH_STEP)
	elif event.is_action_pressed("build_closer", true):
		_reach = maxf(Cfg.BUILD_REACH_MIN, _reach - Cfg.BUILD_REACH_STEP)
	elif event.is_action_pressed("build_cancel"):
		back_out()


		get_viewport().set_input_as_handled()


func _pay(amount: float) -> bool:
	if not GameState.spend_money(amount):
		return false
	Profile.note_structure_built()


	if player != null:
		GameState.note_build_used(player.build_id)


	GameState.note_purchase("gift" if _placing_gift else "build",
		player.build_id if player != null else "", 0, amount)
	return true


var _placing_gift:= false


func _gift_for(id: String) -> bool:
	return GameState.gift_waiting(id) > 0


func _pay_gift(id: String) -> bool:
	if not GameState.take_gift(id):
		return false
	_placing_gift = true
	_pay(0.0)
	_placing_gift = false
	return true


func primary() -> void:
	if not _active:
		return


	if player != null:
		CrashReport.note_doing("build click, %s" % player.build_id)
	if builds == null:
		_primary()
		return


	var st:= status()
	var refused:= not bool(st.get("ok", true)) and not bool(st.get("done", false))
	var was:= _state


	var caught: Array [Node] = []
	var catch:= func(n: Node) -> void: caught.append(n)
	builds.child_entered_tree.connect(catch)
	_primary()
	builds.child_entered_tree.disconnect(catch)


	if refused and caught.is_empty() and _state == was and player != null and player.carry != null and player.carry.hud != null:
		player.carry.hud.nudge_build()
	if _adds_a_building(caught):
		_count_placement()
	if Cfg.build_fx:
		show_built(caught)


func _adds_a_building(caught: Array [Node]) -> bool:
	if caught.is_empty():
		return false
	var listed:= { }
	for b in builds.all_buildings():
		listed [b] = true
	for n in caught:
		if is_instance_valid(n) and listed.has(n) and not n.has_meta(BuildManager.META_SWAPPED_IN):
			return true
	return false


func _count_placement() -> void:
	placed += 1

	if player != null:
		Cfg.place_build(player.build_id)
	if _grid_on and snaps_to_grid():
		placed_on_grid += 1
	if _turned_since_place:
		placed_turned += 1
	if _copied_since_place:
		placed_copied += 1
	_turned_since_place = false
	_copied_since_place = false


func show_built(caught: Array [Node]) -> BuildFx:
	if caught.is_empty() or player == null or builds == null:
		return null
	var listed:= { }
	for b in builds.all_buildings():
		listed [b] = true
	var pieces: Array [Node3D] = []
	for n in caught:


		if is_instance_valid(n) and listed.has(n) and not n.has_meta(BuildManager.META_SWAPPED_IN):
			pieces.append(n as Node3D)
	pieces.append_array(_bends_at(pieces, caught))
	if pieces.is_empty():
		return null


	var apart:= builds.show_enclosed_apart(pieces)
	var fx:= BuildFx.build(builds.get_parent(), pieces, player.camera)
	if not apart.is_empty():
		fx.tree_exiting.connect(builds.end_enclosed_show.bind(apart), CONNECT_ONE_SHOT)
	return fx


func _bends_at(pieces: Array [Node3D], from: Array) -> Array [Node3D]:
	var out: Array [Node3D] = []
	var heads: Array [Vector3] = []
	for p in pieces:
		var run:= p as Conveyor
		if run != null:
			heads.append(run.a)
			heads.append(run.b)
	if heads.is_empty():
		return out
	for n in from:
		if not is_instance_valid(n) or not n is ConveyorCorner:
			continue
		var corner:= n as ConveyorCorner
		if corner.is_queued_for_deletion():
			continue
		for head in heads:
			if corner.apex.is_equal_approx(head):
				out.append(corner)
				break
	return out


func _pieces_of(target: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	var run:= target as Conveyor
	if run != null and run.line_id != 0 and builds.conveyors.has(run):
		for piece in builds.line_of(run):
			out.append(piece)
	else:
		out.append(target)

		out.append_array(builds.machine_belts_of(target))
	out.append_array(_bends_at(out, builds.get_children()))
	return out


func _primary() -> void:
	if _mode == Mode.ROBOTIC_ARM:
		_place_robotic_arm()
		return
	if _mode == Mode.PLATFORM:
		_platform_primary()
		return
	if _mode == Mode.STAIR:
		_stair_primary()
		return
	if _mode == Mode.RAILING:
		_railing_primary()
		return
	if _is_wall(_mode):
		_wall_primary()
		return
	if _is_roof(_mode):
		_roof_primary()
		return
	if _mode == Mode.HAY_STAIRS:
		_place_stairs()
		return
	if _mode == Mode.HAY_LIFT:
		_lift_primary()
		return
	if _mode == Mode.CABINET:
		_place_cabinet()
		return
	if _mode == Mode.NEEDLE_RADAR:
		_place_radar()
		return
	if _mode == Mode.PAINT_BOARD:
		_place_paintboard()
		return
	if _mode == Mode.WORK_LAMP:
		_place_worklamp()
		return
	if _mode == Mode.SCANNER:
		_place_scanner()
		return
	if _mode == Mode.HAY_DRONE:
		_place_drone()
		return
	if _mode == Mode.PISTON_RAKE:
		_place_rake()
		return
	if _mode == Mode.PELLETIZER:
		_place_pelletizer()
		return
	if _mode == Mode.GENERATOR or _mode == Mode.GAS_PLANT:
		_place_generator()
		return
	if _mode == Mode.BOREHOLE:
		_place_borehole()
		return
	if _mode == Mode.WATER_PIPE:
		_place_water_pipe()
		return
	if _mode == Mode.WATER_SPLITTER:
		_place_water_splitter()
		return
	if _is_post(_mode):
		_place_power_pole()
		return
	if _mode == Mode.DUMP_HATCH:
		_place_dump_hatch()
		return
	if _mode == Mode.LAUNCHER:
		_place_launcher()
		return
	if _mode == Mode.COMPRESSOR:
		_place_compressor()
		return
	if _mode == Mode.PULPER:
		_place_pulper()
		return
	if _mode == Mode.PAPER:
		_place_paper()
		return
	if _mode == Mode.BRIQUETTE:
		_place_briquette()
		return
	if _mode == Mode.WRAPPER:
		_place_wrapper()
		return
	if _mode == Mode.SILO:
		_place_silo()
		return
	if _mode == Mode.SPLITTER:
		_place_splitter()
		return
	if _mode == Mode.COMPACT_SPLITTER or _mode == Mode.SMART_SPLITTER:
		_place_compact_splitter()
		return
	if _mode == Mode.JOINER:
		_place_joiner()
		return
	if _mode == Mode.U_SPLITTER:
		_place_u_splitter()
		return
	if _mode == Mode.T_SPLITTER:
		_place_t_splitter()
		return
	if _mode == Mode.U_JOINER:
		_place_u_joiner()
		return


	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if _state == State.AIMING:
		_anchor = _aim_point()
		_upstream = _starts_upstream(_anchor)
		_state = State.RUNNING
		Audio.play("build_ghost")
		return
	if _route.size() > 2:
		_lay_route()
		return


	var end:= _aim_point() if _upstream else _guided(_anchor, _aim_point())


	_eval = _evaluate(end, _anchor, true) if _upstream else _evaluate(_anchor, end, true)
	if not _eval ["ok"] or not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return


	Audio.play_3d("build_place", end)
	if _upstream:
		_lay_run(end, _anchor)
	else:
		_lay_run(_anchor, end)


	_chain_on(end, _joined)


func _chain_on(end: Vector3, joined: bool) -> void:
	if not joined:
		_anchor = end
		return
	_state = State.AIMING
	_upstream = false
	_finished_at = end


func _free_tail(at: Vector3) -> bool:
	if builds == null or builds.wye_mated_at(at):
		return false

	if not builds.runs_ending_at(at).is_empty():
		return false
	var tails:= builds.runs_starting_at(at)
	return tails.size() == 1 and not builds._end_is_joined(tails [0], at)


func _free_intake(at: Vector3) -> bool:
	if builds == null or builds.wye_mated_at(at) or builds.t_mouth_out(at) != Vector3.ZERO:
		return false
	return builds.intake_at(at) and builds.feed_run_into(at) == null


func _starts_upstream(at: Vector3) -> bool:
	return _free_tail(at) or _free_intake(at)


func _finished_here(from: Vector3) -> bool:
	if _state == State.AIMING and not _eval ["ok"] and from.is_equal_approx(_finished_at):
		return true
	_finished_at = Vector3.INF
	return false


static func _finished_eval(reason: String) -> Dictionary:
	return { "ok": false, "reason": reason, "length": 0.0, "cost": 0.0, "done": true }


func _lay_run(from: Vector3, to: Vector3, line_id:= 0) -> void:
	var points:= _port_knees(from, to)
	var pieces:= 0
	for i in points.size() - 1:
		if points [i] != points [i + 1]:
			pieces += 1
	if line_id == 0 and pieces > 1:
		line_id = builds.new_line_id()
	for i in points.size() - 1:
		if points [i] != points [i + 1]:
			if _mode == Mode.ENCLOSED_CONVEYOR:
				builds.add_enclosed_conveyor(points [i], points [i + 1], line_id)
			else:
				builds.add_conveyor(points [i], points [i + 1], line_id)


func _port_knees(from: Vector3, to: Vector3) -> PackedVector3Array:
	var far:= to
	var head:= builds.port_bearing_at(to)


	var t_out:= builds.t_mouth_out(to)
	if t_out != Vector3.ZERO:
		head = - t_out


	var piece:= Cfg.ENCLOSED_BELT_MIN_LENGTH if _mode == Mode.ENCLOSED_CONVEYOR else Cfg.BELT_MIN_LENGTH * 0.5
	var head_stub:= _port_stub(head, to - from, piece)
	if head_stub > 0.0:
		far = to - head * head_stub
	var near:= from
	var tail:= builds.port_bearing_at(from)
	t_out = builds.t_mouth_out(from)
	if t_out != Vector3.ZERO:
		tail = t_out
	var tail_stub:= _port_stub(tail, far - from, piece)
	if tail_stub > 0.0:
		near = from + tail * tail_stub
	return PackedVector3Array([from, near, far, to])


static func _port_stub(bearing: Vector3, run: Vector3, floor_piece: float) -> float:
	if bearing == Vector3.ZERO:
		return 0.0
	var length:= run.length()
	if length < 0.0001 or bearing.angle_to(run / length) <= Cfg.BELT_CORNER_MIN_TURN:
		return 0.0
	for stub: float in [Cfg.BELT_PORT_STUB, length * 0.5]:
		if stub > 0.0 and minf(stub, (run - bearing * stub).length()) >= floor_piece:
			return stub
	return 0.0


func _run_cost(from: Vector3, to: Vector3) -> float:
	if builds == null:
		return _belt_cost_for(from, to)
	var points:= _port_knees(from, to)
	var cost:= 0.0
	for i in points.size() - 1:
		if points [i] != points [i + 1]:
			cost += _belt_cost_for(points [i], points [i + 1])
	return cost


func _belt_cost_for(from: Vector3, to: Vector3) -> float:
	return (EnclosedConveyor.cost_for(from, to) if _mode == Mode.ENCLOSED_CONVEYOR
		else Conveyor.cost_for(from, to))


func _lay_route() -> void:
	var route:= _route
	if not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return


	var end:= route [0] if _upstream else route [route.size() - 1]
	Audio.play_3d("build_place", end)

	var line_id:= builds.new_line_id()
	for i in route.size() - 1:
		_lay_run(route [i], route [i + 1], line_id)


	_chain_on(end, _joined)
	_drop_route()


func _update_run(from: Vector3, to: Vector3, delta: float) -> void:
	var running:= _state == State.RUNNING
	_eval = _evaluate(from, to, running)
	if _finished_here(from):
		_eval = _finished_eval(tr("belt connected"))
		_drop_route()
		_ghost.multimesh.visible_instance_count = 0
		_flow.multimesh.visible_instance_count = 0
		return

	if running and ROUTABLE.any(func(r: String) -> bool: return tr(r) == str(_eval ["reason"])):
		_update_route(from, to, delta)
	else:
		_drop_route()


	if str(_eval ["reason"]) == tr("blocked") and _run_blocker != "":
		_eval ["reason"] = tr("%s is in the way") % _run_blocker
	if _route.size() > 2:
		_shape_route_ghost()
	else:
		_shape_ghost(from, to)


func _update_route(from: Vector3, to: Vector3, delta: float) -> void:
	if _router == null:
		_router = BeltRouter.new(self)
	_route_age += delta
	var due:= _route_age >= ROUTE_REFRESH
	var moved:= not (from.is_equal_approx(_route_from) and to.is_equal_approx(_route_to)
		and builds.conveyors.size() == _route_yard)
	if not moved and not due:
		_apply_route()
		return
	_route_from = from
	_route_to = to
	_route_yard = builds.conveyors.size()
	var pick: Dictionary = { }
	if not due and _route_sig != "":
		pick = _router.recheck(from, to, _route_sig)


	if pick.is_empty() and (due or _route_sig != ""):
		_route_picks = _router.find(from, to)
		_route_age = 0.0
		pick = BeltRouter.choose(_route_picks, _route_sig, _route_pinned)
	if pick.is_empty():
		_route = PackedVector3Array()
		_route_sig = ""
		_route_pinned = false
		return
	if pick ["sig"] != _route_sig:
		_route_pinned = false
	_route_sig = pick ["sig"]
	_route = pick ["points"]
	_apply_route()


func _apply_route() -> void:
	if _route.size() < 3:
		return
	var length:= 0.0
	var cost:= 0.0
	for i in _route.size() - 1:
		length += _route [i].distance_to(_route [i + 1])

		cost += _run_cost(_route [i], _route [i + 1])
	var ok:= GameState.can_afford(cost)
	_eval = { "ok": ok, "reason": "" if ok else tr("need %s") % _price(cost),
		"length": length, "cost": cost, "bends": _route.size() - 2 }


func _drop_route() -> void:
	_route = PackedVector3Array()
	_route_picks.clear()
	_route_sig = ""
	_route_pinned = false
	_route_from = Vector3.INF
	_route_to = Vector3.INF
	_route_age = INF


func route_choices() -> int:
	if not _is_conveyor_mode() or _state != State.RUNNING or _route.size() < 3:
		return 0
	return _route_picks.size()


func next_route() -> bool:
	if route_choices() < 2 or _router == null:
		return false
	var at:= 0
	for i in _route_picks.size():
		if _route_picks [i] ["sig"] == _route_sig:
			at = i
	for step in range(1, _route_picks.size()):
		var sig: String = _route_picks [(at + step) % _route_picks.size()] ["sig"]
		var pick:= _router.recheck(_route_from, _route_to, sig)
		if pick.is_empty():
			continue
		_route_sig = sig
		_route_pinned = true
		_route = pick ["points"]
		_apply_route()
		return true
	return false


func _shape_route_ghost() -> void:
	var points:= _route_preview_points(_route)
	_ghost.global_transform = Transform3D()
	_ghost.multimesh.visible_instance_count = _lay_ghost(points)
	_drop_ghost_drums(points, _route [0], _route [_route.size() - 1])
	_ghost.material_override = ConveyorKit.ghost_material(_eval ["ok"])
	_shape_flow(points)


func _route_preview_points(route: PackedVector3Array) -> PackedVector3Array:
	var out:= PackedVector3Array()
	var legs:= route.size() - 1
	var incoming: Conveyor = builds.feed_run_into(route [0])
	if incoming != null:
		var first:= (route [1] - route [0]).normalized()
		var t:= BuildManager.corner_tangent(incoming.forward, incoming.length,
			first, route [0].distance_to(route [1]))
		if t > 0.0:
			out.append_array(_bend(route [0] - incoming.forward * t, route [0],
				route [0] + first * t, incoming.forward.angle_to(first)))
	if out.is_empty():
		out.append(route [0])
	for i in range(1, legs):
		var p:= route [i]
		var len_in:= route [i - 1].distance_to(p)
		var len_out:= p.distance_to(route [i + 1])
		var dir_in:= (p - route [i - 1]) / len_in
		var dir_out:= (route [i + 1] - p) / len_out
		var t:= BuildManager.corner_tangent(dir_in, len_in, dir_out, len_out)
		if t > 0.0:
			out.append_array(_bend(p - dir_in * t, p, p + dir_out * t,
				dir_in.angle_to(dir_out)))
		else:
			out.append(p)


	var outgoing: Conveyor = builds.run_out_of(route [legs])
	if outgoing != null:
		var tail_len:= route [legs - 1].distance_to(route [legs])
		var tail_dir:= (route [legs] - route [legs - 1]) / maxf(tail_len, 1e-06)
		var ht:= BuildManager.corner_tangent(tail_dir, tail_len,
			outgoing.forward, outgoing.length)
		if ht > 0.0:
			out.append_array(_bend(route [legs] - tail_dir * ht, route [legs],
				route [legs] + outgoing.forward * ht,
				tail_dir.angle_to(outgoing.forward)))
			return out
	out.append(route [legs])
	return out


func _place_robotic_arm() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return


	var cost:= float(_eval ["cost"])
	if not _pay(cost):
		Audio.play("build_denied")
		return
	var at:= _arm_ghost.global_position
	var yaw:= _arm_ghost.global_rotation.y
	builds.add_robotic_arm(at, yaw, _arm_tier, cost)


	Audio.play_3d("build_place_big", at, -3.0)
	Audio.play_3d_delayed("arm_hiss", at, 0.3, -13.0)


func _platform_primary() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if _state == State.AIMING:
		_anchor_span = _deck_ghost.span
		_anchor = _deck_ghost.global_position - Vector3(_anchor_span.x, 0.0, _anchor_span.y) * 0.5
		_state = State.RUNNING
		Audio.play("build_ghost")
		return
	if not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return
	var at:= _deck_ghost.global_position
	var span:= _deck_ghost.span
	Audio.play_3d("build_place_metal", at)
	builds.add_platform(at, span)


	_state = State.AIMING


func _stair_primary() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if _state == State.AIMING:


		_anchor = _stair_ghost.global_position
		_state = State.RUNNING
		Audio.play("build_ghost")
		return
	if not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return
	var at:= _stair_ghost.global_position
	builds.add_stair(at, _stair_ghost.global_rotation.y, _stair_ghost.rise,
		_stair_ghost.pitch)
	Audio.play_3d("build_place_metal", at)
	_state = State.AIMING


func _railing_primary() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if _state == State.AIMING:
		_anchor = _rail_point()
		_state = State.RUNNING
		Audio.play("build_ghost")
		return
	var end:= _rail_point()


	_eval = _evaluate_railing(_anchor, end, true)
	if not _eval ["ok"] or not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return
	Audio.play_3d("build_place_metal", end)
	builds.add_railing(_anchor, end)
	_anchor = end


func _rail_point() -> Vector3:
	return builds.snap_railing_point(_surface_point(0.0))


func _update_rail_ghost() -> void:
	var point:= _rail_point()
	var from: Vector3
	var to: Vector3
	if _state == State.RUNNING:
		from = _anchor
		to = point
	else:


		from = point
		to = point
	_rail_ghost.set_aim_marker(_state != State.RUNNING)
	_rail_ghost.set_shape(from, to)
	_eval = _evaluate_railing(from, to, _state == State.RUNNING)
	_rail_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_railing(from: Vector3, to: Vector3, priced: bool) -> Dictionary:
	var length:= Vector2(to.x - from.x, to.z - from.z).length()


	var cost:= Railing.cost_for(from, to)
	var r:= { "ok": false, "reason": "", "length": length, "cost": cost }
	if not priced:
		if not GameState.can_afford(Railing.cost_for(Vector3.ZERO,
				Vector3(Cfg.RAILING_MIN_LENGTH, 0.0, 0.0))):
			r ["reason"] = tr("no funds")
			return r


		if builds.railing_unsupported(from, from):
			r ["reason"] = tr("nothing under it")
			return r
		r ["ok"] = true
		return r
	if length < Cfg.RAILING_MIN_LENGTH:
		r ["reason"] = tr("too short")
		return r
	if length > Cfg.RAILING_MAX_LENGTH:
		r ["reason"] = tr("too long")
		return r
	if not GameState.can_afford(cost):
		r ["reason"] = tr("need %s") % _price(cost)
		return r
	if builds.railing_unsupported(from, to):
		r ["reason"] = tr("nothing under it")
		return r
	if builds.railing_overlap(from, to):
		r ["reason"] = tr("already railed")
		return r


	if builds.wall_along(from, to):
		r ["reason"] = tr("already walled")
		return r
	if builds.railing_blocked(from, to):
		r ["reason"] = tr("blocked")
		return r
	r ["ok"] = true
	return r


static func _is_wall(mode: Mode) -> bool:
	return mode == Mode.WALL or mode == Mode.WALL_WINDOW or mode == Mode.WALL_DOOR


static func _wall_bay(mode: Mode) -> YardWall.Bay:
	match mode:
		Mode.WALL_WINDOW:
			return YardWall.Bay.WINDOW
		Mode.WALL_DOOR:
			return YardWall.Bay.DOOR
	return YardWall.Bay.SOLID


static func _is_roof(mode: Mode) -> bool:
	return mode == Mode.ROOF or mode == Mode.ROOF_PITCH or mode == Mode.ROOF_HATCH


static func _roof_kind(mode: Mode) -> Roof.Kind:
	match mode:
		Mode.ROOF_PITCH:
			return Roof.Kind.PITCHED
		Mode.ROOF_HATCH:
			return Roof.Kind.HATCH
		_:
			return Roof.Kind.FLAT


func _roof_primary() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	var kind:= _roof_kind(_mode)
	if kind == Roof.Kind.HATCH:
		if not _pay(_eval ["cost"]):
			Audio.play("build_denied")
			return
		Audio.play_3d("build_place_metal", _roof_ghost.global_position)
		if _hatch_deck != null and is_instance_valid(_hatch_deck):
			builds.hatch_into_deck(_hatch_deck, _hatch_tile, _hatch_from,
				_hatch_to, _hatch_side)

			_hatch_deck = null
			return
		if _hatch_gap:


			builds.add_roof(_hatch_from, _hatch_to, kind, _hatch_side, 1)
			_hatch_gap = false
			return
		builds.add_roof(_roof_ghost.a, _roof_ghost.b, kind, _roof_ghost.side,
			_roof_ghost.rows)
		return
	if _state == State.AIMING:


		_anchor = _roof_ghost.a
		var laid:= _roof_ghost.b - _roof_ghost.a
		laid.y = 0.0
		_anchor_dir = laid.normalized() if laid.length_squared() > 1e-06 else Vector3.BACK
		_anchor_side = _roof_ghost.side


		_roof_turn = 0
		_state = State.RUNNING
		Audio.play("build_ghost")
		return
	if not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return


	var from:= _roof_ghost.a
	var end:= _roof_ghost.b
	Audio.play_3d("build_place_metal", end)
	builds.add_roof(from, end, kind, _roof_ghost.side, _roof_ghost.rows)


	_state = State.AIMING


	_roof_turn = 0


func _roof_point() -> Vector3:


	if _state == State.RUNNING:
		var on_plane: Variant = _plane_point(_anchor.y)
		if on_plane != null:
			return on_plane
	var socket: Variant = builds.aimed_roof_socket(player.eye_position(),
		player.look_direction(), _reach)
	if socket != null:
		return socket
	return builds.snap_roof_point(_surface_point(0.0))


func _plane_point(height: float) -> Variant:
	var eye:= player.eye_position()
	var look:= player.look_direction()
	if absf(look.y) < 0.02:
		return null
	var t:= (height - eye.y) / look.y
	if t <= 0.0:
		return null
	return eye + look * minf(t, Cfg.ROOF_MAX_LENGTH * 2.0)


func _roof_heading(at: Vector3) -> Vector3:
	var look:= player.look_direction()
	look.y = 0.0
	look = look.normalized() if look.length_squared() > 1e-06 else Vector3.BACK
	var along:= Vector3.ZERO


	var span_a:= Vector3.INF
	var span_b:= Vector3.INF
	for lid in builds.roofs:
		if not is_instance_valid(lid) or lid.length < 1e-06:
			continue
		if lid.a.distance_to(at) < Cfg.ROOF_SNAP_RADIUS or lid.b.distance_to(at) < Cfg.ROOF_SNAP_RADIUS:
			along = (lid.b - lid.a).normalized()
			span_a = lid.a
			span_b = lid.b
			break
	if along == Vector3.ZERO:
		for wall in builds.walls:
			if not is_instance_valid(wall) or wall.length < 1e-06:
				continue
			for post: Vector3 in wall.post_points():
				if Vector2(at.x - post.x, at.z - post.z).length() < Cfg.ROOF_SNAP_RADIUS:
					along = (wall.b - wall.a).normalized()
					span_a = wall.a
					span_b = wall.b
					break
			if along != Vector3.ZERO:
				break
	if along == Vector3.ZERO:
		along = Vector3.RIGHT if absf(look.x) > absf(look.z) else Vector3.BACK


	if span_a.x < INF:
		var reach:= span_a.distance_to(span_b)
		var here:= (at - span_a).dot(along)
		var forward:= here + Cfg.ROOF_BAY <= reach + 0.01
		var backward:= here - Cfg.ROOF_BAY >= -0.01
		if forward != backward:
			return along if forward else - along


	return along if along.dot(look) >= 0.0 else - along


func _roof_side(from: Vector3, to: Vector3) -> int:
	var dir:= to - from
	dir.y = 0.0
	if dir.length_squared() < 1e-06:
		return 1
	dir = dir.normalized()

	var right:= Vector3(dir.z, 0.0, - dir.x)


	var here:= player.eye_position() - from
	here.y = 0.0
	var across:= here.dot(right)
	if absf(across) > 0.3:
		return 1 if across > 0.0 else -1


	var indoors:= builds.enclosed_side(from, right)
	return indoors if indoors != 0 else 1


func _turn_in_cell(a: Vector3, b: Vector3, side: int) -> Dictionary:
	var quarters:= _roof_turn % 4
	if quarters == 0:
		return { "a": a, "b": b, "side": side }
	var dir:= b - a
	dir.y = 0.0
	if dir.length_squared() < 1e-06:
		return { "a": a, "b": b, "side": side }
	dir = dir.normalized()
	var right:= Vector3(dir.z, 0.0, - dir.x)
	var centre:= (a + b) * 0.5 + right * (float(side) * Cfg.ROOF_DEPTH * 0.5)
	var angle:= PI * 0.5 * float(quarters)
	return {
		"a": centre + (a - centre).rotated(Vector3.UP, angle),
		"b": centre + (b - centre).rotated(Vector3.UP, angle),
		"side": side,
	}


static func _roof_extent(reach: float, module: float, most: int) -> Vector2:
	var lo:= 0.0
	var hi:= module
	if reach > hi:
		hi = roundf(reach / module) * module
	elif reach < lo:
		lo = hi - roundf((hi - reach) / module) * module
	var span:= int(round((hi - lo) / module))
	if span > most:


		if lo < 0.0:
			lo = hi - float(most) * module
		else:
			hi = lo + float(most) * module
	return Vector2(lo, hi)


func _update_roof_ghost() -> void:
	var kind:= _roof_kind(_mode)
	_hatch_deck = null
	_hatch_gap = false
	if kind == Roof.Kind.HATCH and (_aim_hatch_into_deck() or _aim_hatch_into_gap()):
		return
	var point:= _roof_point()
	var anchored:= _state == State.RUNNING and kind != Roof.Kind.HATCH


	var heading:= _roof_heading(point)
	var from:= point
	var to:= point + heading * Cfg.ROOF_BAY
	var side:= 0
	var rows:= 1
	if anchored:


		from = _anchor
		side = _anchor_side
		if _roof_turn % 2 == 1:
			side = - side
		var delta:= Vector3(point.x - from.x, 0.0, point.z - from.z)
		var right:= Vector3(_anchor_dir.z, 0.0, - _anchor_dir.x)
		var span:= _roof_extent(delta.dot(_anchor_dir), Cfg.ROOF_BAY,
			int(Cfg.ROOF_MAX_LENGTH / Cfg.ROOF_BAY))
		from = _anchor + _anchor_dir * span.x
		to = _anchor + _anchor_dir * span.y
		var deep:= _roof_extent(delta.dot(right) * float(side), Cfg.ROOF_DEPTH,
			Cfg.ROOF_MAX_ROWS)


		rows = maxi(1, int(round(deep.y / Cfg.ROOF_DEPTH)))
	else:
		var end:= Roof.end_for(from, to, kind)
		side = _roof_side(from, end)
		var turned:= _turn_in_cell(from, end, side)
		from = turned ["a"]
		to = turned ["b"]
		side = int(turned ["side"])
	_roof_ghost.set_kind(kind)
	_roof_ghost.set_side(side)
	_roof_ghost.set_rows(rows)
	_roof_ghost.set_shape(from, to)
	_eval = _evaluate_roof(from, to, kind, side, _roof_ghost.rows,
		_state == State.RUNNING)
	_roof_ghost.set_preview_valid(_eval ["ok"])


func _aim_hatch_into_deck() -> bool:
	var hit:= _raw_surface_hit()
	if hit.is_empty() or absf((hit ["normal"] as Vector3).y) < 0.7:
		return false
	var deck:= builds.owner_of(hit.get("collider") as Node) as Platform
	if deck == null:
		return false
	var at:= hit ["position"] as Vector3
	var eye:= player.eye_position()

	var from_below:= (hit ["normal"] as Vector3).y < 0.0
	var socket: Variant = null if from_below else builds.aimed_roof_socket(eye, player.look_direction(), _reach)
	if socket != null and eye.distance_to(socket as Vector3) < eye.distance_to(at) - 0.5:
		return false
	var tile:= BuildManager.deck_tile_at(deck, at)


	var beside:= _hole_beside(deck, tile, at)
	if beside.has_area():
		_aim_hatch_at_gap(beside, deck.top_y())
		return true
	_shape_hatch_in_cell(tile, deck.top_y())
	_hatch_deck = deck
	_eval = _evaluate_deck_hatch(deck, tile)
	_roof_ghost.set_preview_valid(_eval ["ok"])
	return true


func _aim_hatch_into_gap() -> bool:
	var eye:= player.eye_position()
	var look:= player.look_direction()
	if absf(look.y) < 0.02:
		return false
	var best:= INF
	var cell:= Rect2()
	var top:= 0.0
	for deck in builds.platforms:
		if not is_instance_valid(deck):
			continue
		var y:= deck.top_y()
		var t:= (y - eye.y) / look.y
		if t <= 0.0 or t > _reach or t >= best:
			continue
		var at:= eye + look * t
		var rect:= deck.footprint()


		var near:= rect.grow(Cfg.PLATFORM_TILE)
		if not near.has_point(Vector2(at.x, at.z)):
			continue
		var i:= int(floor((at.x - rect.position.x) / Cfg.PLATFORM_TILE))
		var j:= int(floor((at.z - rect.position.y) / Cfg.PLATFORM_TILE))
		var candidate:= Rect2(rect.position + Vector2(float(i), float(j)) * Cfg.PLATFORM_TILE,
			Vector2.ONE * Cfg.PLATFORM_TILE)
		if not _is_deck_hole(candidate, y):
			continue
		best = t
		cell = candidate
		top = y
	if not cell.has_area():
		return false
	_aim_hatch_at_gap(cell, top)
	return true


func _aim_hatch_at_gap(cell: Rect2, top: float) -> void:
	_shape_hatch_in_cell(cell, top)
	_hatch_deck = null
	_hatch_gap = true
	_eval = _evaluate_gap_hatch()
	_roof_ghost.set_preview_valid(_eval ["ok"])


func _shape_hatch_in_cell(cell: Rect2, top: float) -> void:
	var eye:= player.eye_position()
	var centre:= Vector3(cell.get_center().x, top, cell.get_center().y)


	var look:= player.look_direction()
	var dir:= Vector3.RIGHT if absf(look.x) > absf(look.z) else Vector3.BACK
	var right:= Vector3(dir.z, 0.0, - dir.x)
	var half:= Cfg.PLATFORM_TILE * 0.5


	var near:= 1.0 if (eye - centre).dot(right) >= 0.0 else -1.0
	var eave:= centre + right * (near * half)
	var turned:= _turn_in_cell(eave - dir * half, eave + dir * half, - int(near))
	_hatch_tile = cell
	_hatch_from = turned ["a"]
	_hatch_to = turned ["b"]
	_hatch_side = int(turned ["side"])
	_roof_ghost.set_kind(Roof.Kind.HATCH)
	_roof_ghost.set_side(_hatch_side)
	_roof_ghost.set_rows(1)
	var lift:= Vector3(0.0, 0.02, 0.0)
	_roof_ghost.set_shape(_hatch_from + lift, _hatch_to + lift)


func _is_deck_hole(cell: Rect2, top: float) -> bool:
	var centre:= Vector3(cell.get_center().x, top, cell.get_center().y)
	if builds.deck_under(centre) != null:
		return false
	if builds.roof_lying_at(centre) != null:
		return false
	var ringed:= 0
	for step: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		if builds.deck_under(centre + step * Cfg.PLATFORM_TILE) != null:
			ringed += 1
	return ringed >= 2


func _hole_beside(deck: Platform, tile: Rect2, at: Vector3) -> Rect2:
	const EDGE:= 0.5
	var top:= deck.top_y()
	var p:= Vector2(at.x, at.z)
	var dx:= 0.0
	if p.x - tile.position.x < EDGE:
		dx = - Cfg.PLATFORM_TILE
	elif tile.end.x - p.x < EDGE:
		dx = Cfg.PLATFORM_TILE
	var dz:= 0.0
	if p.y - tile.position.y < EDGE:
		dz = - Cfg.PLATFORM_TILE
	elif tile.end.y - p.y < EDGE:
		dz = Cfg.PLATFORM_TILE
	var shifts: Array [Vector2] = []
	if dx != 0.0:
		shifts.append(Vector2(dx, 0.0))
	if dz != 0.0:
		shifts.append(Vector2(0.0, dz))
	if dx != 0.0 and dz != 0.0:
		shifts.append(Vector2(dx, dz))
	for shift in shifts:
		var cell:= Rect2(tile.position + shift, tile.size)
		if _is_deck_hole(cell, top):
			return cell
	return Rect2()


func _evaluate_gap_hatch() -> Dictionary:
	var cost:= Roof.cost_for(_hatch_from, _hatch_to, Roof.Kind.HATCH)
	var r:= { "ok": false, "reason": "", "length": Cfg.ROOF_BAY, "cost": cost }
	if builds.hatch_drop(_hatch_from, _hatch_to, _hatch_side) < Cfg.ROOF_HATCH_MIN_DROP:
		r ["reason"] = tr("no room under it")
		return r
	if builds.roof_overlap(_hatch_from, _hatch_to, Roof.Kind.HATCH):
		r ["reason"] = tr("already roofed")
		return r
	if not GameState.can_afford(cost):
		r ["reason"] = tr("need %s") % _price(cost)
		return r
	r ["ok"] = true
	return r


func _evaluate_deck_hatch(deck: Platform, tile: Rect2) -> Dictionary:
	var cost:= maxf(0.0, Roof.cost_for(_hatch_from, _hatch_to, Roof.Kind.HATCH)
		- builds.deck_tile_share(deck))
	var r:= { "ok": false, "reason": "", "length": Cfg.ROOF_BAY, "cost": cost }


	if deck.span.x * deck.span.y <= Cfg.PLATFORM_TILE * Cfg.PLATFORM_TILE + 0.01:
		r ["reason"] = tr("deck too small")
		return r
	var load_count:= builds.standing_on_tile(deck, tile).size()
	if load_count > 0:
		r ["reason"] = tr("clear %d from the deck first") % load_count
		return r
	if builds.hatch_drop(_hatch_from, _hatch_to, _hatch_side, deck) < Cfg.ROOF_HATCH_MIN_DROP:
		r ["reason"] = tr("no room under it")
		return r
	if not GameState.can_afford(cost):
		r ["reason"] = tr("need %s") % _price(cost)
		return r
	r ["ok"] = true
	return r


func _evaluate_roof(from: Vector3, to: Vector3, kind: Roof.Kind, side: int,
		rows: int, priced: bool) -> Dictionary:
	var end:= Roof.end_for(from, to, kind)
	var length:= from.distance_to(end)
	var cost:= Roof.cost_for(from, to, kind, rows)
	var r:= { "ok": false, "reason": "", "length": length, "cost": cost }
	if not priced and kind != Roof.Kind.HATCH:
		if not GameState.can_afford(Cfg.ROOF_MIN_LENGTH * Cfg.ROOF_COST_PER_M
				* Tech.build_cost_scale()):
			r ["reason"] = tr("no funds")
			return r


		if builds.roof_unsupported(from, from, kind, side, rows):
			r ["reason"] = tr("nothing under the eave")
			return r
		if builds.roof_through_deck(from, to, kind, side, rows):
			r ["reason"] = tr("a deck is in the way")
			return r
		if builds.roof_blocked(from, to, kind, side, rows):
			r ["reason"] = tr("blocked")
			return r
		r ["ok"] = true
		return r


	if length > Cfg.ROOF_MAX_LENGTH + 0.01:
		r ["reason"] = tr("too long")
		return r
	if not GameState.can_afford(cost):
		r ["reason"] = tr("need %s") % _price(cost)
		return r
	if builds.roof_unsupported(from, to, kind, side, rows):
		r ["reason"] = tr("nothing under the eave")
		return r
	if kind == Roof.Kind.HATCH and builds.hatch_drop(from, to, side) < Cfg.ROOF_HATCH_MIN_DROP:
		r ["reason"] = tr("no room under it")
		return r
	if builds.roof_overlap(from, to, kind):
		r ["reason"] = tr("already roofed")
		return r
	if builds.roof_through_deck(from, to, kind, side, rows):
		r ["reason"] = tr("a deck is in the way")
		return r
	if builds.roof_blocked(from, to, kind, side, rows):
		r ["reason"] = tr("blocked")
		return r
	r ["ok"] = true
	return r


func _wall_primary() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if _state == State.AIMING:
		_anchor = _wall_point()
		_state = State.RUNNING
		Audio.play("build_ghost")
		return
	var bay:= _wall_bay(_mode)
	var aim:= _wall_point()
	var end:= YardWall.end_for(_anchor, aim, bay)


	_eval = _evaluate_wall(_anchor, aim, true)
	if not _eval ["ok"] or not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return
	Audio.play_3d("build_place_metal", end)
	builds.add_wall(_anchor, end, bay)
	_anchor = end


func _wall_point() -> Vector3:
	return builds.snap_wall_point(_surface_point(0.0))


func _update_wall_ghost() -> void:
	var point:= _wall_point()
	var from: Vector3
	var to: Vector3
	if _state == State.RUNNING:
		from = _anchor
		to = point
	else:


		from = point
		to = point
	_wall_ghost.set_kind(_wall_bay(_mode))
	_wall_ghost.set_aim_marker(_state != State.RUNNING)
	_wall_ghost.set_shape(from, to)
	_eval = _evaluate_wall(from, to, _state == State.RUNNING)
	_wall_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_wall(from: Vector3, to: Vector3, priced: bool) -> Dictionary:
	var bay:= _wall_bay(_mode)
	var end:= YardWall.end_for(from, to, bay)
	var length:= from.distance_to(end)


	var cost:= YardWall.cost_for(from, to, bay)
	var r:= { "ok": false, "reason": "", "length": length, "cost": cost }
	if not priced:
		if not GameState.can_afford(Cfg.WALL_MIN_LENGTH * Cfg.WALL_COST_PER_M
				* Tech.build_cost_scale()):
			r ["reason"] = tr("no funds")
			return r


		if builds.wall_unsupported(from, from, bay):
			r ["reason"] = tr("nothing under it")
			return r
		r ["ok"] = true
		return r


	if length < 1e-06:
		r ["reason"] = tr("no length")
		return r


	if length > Cfg.WALL_MAX_LENGTH + 0.01:
		r ["reason"] = tr("too long")
		return r
	if not GameState.can_afford(cost):
		r ["reason"] = tr("need %s") % _price(cost)
		return r
	if builds.wall_unsupported(from, to, bay):
		r ["reason"] = tr("nothing under it")
		return r
	if builds.wall_overlap(from, to, bay):
		r ["reason"] = tr("already walled")
		return r
	if builds.railing_along(from, YardWall.end_for(from, to, bay)):
		r ["reason"] = tr("already railed")
		return r
	if builds.wall_blocked(from, to, bay):
		r ["reason"] = tr("blocked")
		return r
	r ["ok"] = true
	return r


func cancel() -> void:
	_state = State.AIMING
	_finished_at = Vector3.INF
	_drop_route()


func back_out() -> void:
	var running:= _state == State.RUNNING
	cancel()
	if not running and player != null:
		player.put_away_build()


func stuck() -> bool:
	return bool(_eval.get("stuck", false))


func copy_id() -> String:
	if player == null or builds == null:
		return ""
	var target:= dismantle_target()
	var id:= builds.id_of(target)
	if id != "" and player.current_tool == Player.Tool.BUILD and player.build_id == id:

		var r:= _t_size_of(target)
		if is_nan(r) or is_equal_approx(r, ConveyorTSplitter.size_in_hand()):
			return ""
	return id


static func _t_size_of(node: Node3D) -> float:
	if not (node is ConveyorTSplitter or node is ConveyorTJoiner):
		return NAN
	var r: float = node.get("port_r")
	for size: float in Cfg.T_SPLITTER_SIZES:
		if is_equal_approx(r, size):
			return size
	return NAN


func _copy_target() -> void:
	if player == null or not player.is_mouse_captured():
		return
	var id:= copy_id()
	if id == "":
		return
	get_viewport().set_input_as_handled()
	if not BuildCatalog.is_unlocked(id):
		Audio.play("build_denied")
		var hud: Hud = player.carry.hud if player.carry != null else null
		if hud != null:
			hud.show_toast(tr("CAN'T COPY  ·  %s") % Cfg.upper(tr("not unlocked yet")),
				3.0, Hud.LOST_TOAST_COLOR)
		return


	var r:= _t_size_of(dismantle_target())
	if not is_nan(r):
		Cfg.set_t_splitter_port_r(r)
	player.equip_build(id)
	_copied_since_place = true
	copied += 1


func dismantle_reach() -> float:
	return DISMANTLE_REACH + Tech.build_reach_bonus()


func dismantle_target() -> Node3D:
	if player == null or builds == null:
		return null
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * dismantle_reach())
	q.collision_mask = Cfg.L_BUILD


	q.collide_with_areas = true
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null


	_wreck_aim = (hit ["position"] as Vector3) - (hit ["normal"] as Vector3) * 0.05
	var owner_node:= builds.owner_of(hit.get("collider") as Node)


	if owner_node is Platform:
		var lid:= builds.roof_lying_at(hit ["position"] as Vector3)
		if lid != null:
			return lid
	return owner_node


func dismantle_progress() -> float:
	if _wreck == null:
		return -1.0
	return clampf(_wreck_time / DISMANTLE_HOLD, 0.0, 1.0)


func dismantle_name() -> String:
	if _wreck == null or builds == null:
		return ""
	if _wreck_tile_on:
		return tr("Deck tile")
	return builds.name_of(_wreck)


func _begin_dismantle(loud:= true) -> void:


	if player == null or builds == null or not player.is_mouse_captured():
		return


	if player.carry != null and player.carry.rip_target() != null:
		return
	var target:= dismantle_target()
	if target == null:
		if loud:
			_refuse_dismantle(dismantle_miss_reason())
		return


	var deck:= target as Platform

	var tile_on:= deck != null and Input.is_key_pressed(KEY_SHIFT) and _tiles_of(deck) > 1
	var tile:= BuildManager.deck_tile_at(deck, _wreck_aim) if tile_on else Rect2()


	var feet:= player.global_position
	var under_feet:= deck != null and deck.supports_point(feet)
	if under_feet and tile_on:
		under_feet = tile.grow(0.3).has_point(Vector2(feet.x, feet.z))
	if not loud and (builds.id_of(target) != _wreck_chain_kind or under_feet):
		return


	var why:= builds.tile_blocked_reason(deck, tile) if tile_on else builds.demolish_blocked_reason(target)
	if why != "":
		if loud:
			_refuse_dismantle(why)
		return
	_wreck = target
	_wreck_tile_on = tile_on
	_wreck_tile = tile
	_wreck_time = 0.0


	_wreck_noise = 0.0
	Audio.play_3d("build_dismantle", target.global_position, -3.0)


func _tick_dismantle(delta: float) -> void:


	if not Input.is_action_pressed("dismantle") or not player.is_mouse_captured():
		_wreck = null
		_wreck_chain = false
		return
	if _wreck == null:


		if _wreck_chain:
			_begin_dismantle(false)
		return


	if not is_instance_valid(_wreck) or not builds.same_building(dismantle_target(), _wreck):
		_wreck = null
		return

	if _wreck_tile_on and BuildManager.deck_tile_at(_wreck as Platform, _wreck_aim) != _wreck_tile:
		_wreck = null
		return


	var why:= builds.tile_blocked_reason(_wreck as Platform, _wreck_tile) if _wreck_tile_on else builds.demolish_blocked_reason(_wreck)
	if why != "":
		_wreck = null
		_refuse_dismantle(why)
		return
	_wreck_time += delta


	if _wreck_time - _wreck_noise >= DISMANTLE_RATCHET and _wreck_time < DISMANTLE_HOLD - DISMANTLE_RATCHET * 0.5:
		_wreck_noise = _wreck_time
		Audio.play_3d("build_dismantle", _wreck.global_position, -3.0)
	if _wreck_time < DISMANTLE_HOLD:
		return


	_wreck_chain_kind = builds.id_of(_wreck)
	if _wreck_tile_on:
		dismantle_tile(_wreck as Platform, _wreck_tile)
	else:
		dismantle(_wreck)
	_wreck = null


	_wreck_chain = true


var _glow_id:= 0
var _glow_mat: ShaderMaterial
var _glow_prev: Dictionary = { }


var _glow_apart: Array [Node3D] = []


var _glow_lent: Array [GeometryInstance3D] = []


func _tick_wreck_glow() -> void:
	_tick_tile_glow()


	var want: Node3D = _wreck if is_instance_valid(_wreck) and Cfg.build_fx and not _wreck_tile_on else null
	var want_id:= want.get_instance_id() if want != null else 0
	if want_id != _glow_id:
		_clear_wreck_glow()
		_glow_id = want_id
		if want != null:
			if _glow_mat == null:
				_glow_mat = BuildFx.glow_material()
			var pieces:= _pieces_of(want)
			if builds != null and is_instance_valid(builds):
				_glow_apart = builds.show_enclosed_apart(pieces)
			for piece in pieces:
				for g in BuildFx.meshes_of(piece):
					if BeltBatch.instance != null and BeltBatch.instance.holds(g):
						BeltBatch.instance.drop(g)
						_glow_lent.append(g)
					_glow_prev [g] = g.material_overlay
					g.material_overlay = _glow_mat
	if _glow_id != 0:
		BuildFx.set_glow(_glow_mat, dismantle_progress())


func _tick_tile_glow() -> void:
	var on:= is_instance_valid(_wreck) and _wreck_tile_on and Cfg.build_fx
	if not on:
		if _tile_glow != null:
			_tile_glow.visible = false
		return
	if _glow_mat == null:
		_glow_mat = BuildFx.glow_material()
	if _tile_glow == null:
		_tile_glow = MeshInstance3D.new()
		_tile_glow.mesh = BoxMesh.new()
		_tile_glow.material_override = _glow_mat
		_tile_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tile_glow.top_level = true
		add_child(_tile_glow)
	var deck:= _wreck as Platform
	var box:= _tile_glow.mesh as BoxMesh
	box.size = Vector3(_wreck_tile.size.x + 0.02, Cfg.PLATFORM_THICK + 0.02,
		_wreck_tile.size.y + 0.02)
	var c:= _wreck_tile.get_center()
	_tile_glow.global_position = Vector3(c.x, deck.top_y() - Cfg.PLATFORM_THICK * 0.5, c.y)
	_tile_glow.visible = true
	BuildFx.set_glow(_glow_mat, dismantle_progress())


static func _tiles_of(deck: Platform) -> int:
	return Platform.tiles_across(deck.span.x) * Platform.tiles_across(deck.span.y)


func dismantle_tile(deck: Platform, tile: Rect2) -> void:
	if builds == null or deck == null or not is_instance_valid(deck):
		return
	CrashReport.note_doing("dismantling a tile of %s" % _report_name(deck))
	var c:= tile.get_center()
	var gone_at:= Vector3(c.x, deck.top_y(), c.y)
	Audio.play_3d("build_demolish", gone_at, -5.0)
	Audio.play("coins", -6.0)
	if _glow_id != 0 and _glowing_on(deck):
		_clear_wreck_glow()
	GameState.add_money(builds.remove_deck_tile(deck, tile))
	if deck.is_queued_for_deletion():
		dismantled += 1


static func _report_name(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return "nothing"
	var s:= n.get_script() as Script
	if s == null or s.resource_path == "":
		return n.get_class()
	return s.resource_path.get_file().get_basename()


func _glowing_on(target: Node3D) -> bool:
	if _glow_id == 0 or target == null or builds == null:
		return false
	for piece in _pieces_of(target):
		if piece != null and piece.get_instance_id() == _glow_id:
			return true
	return false


func _clear_wreck_glow() -> void:
	for k in _glow_prev:
		if not is_instance_valid(k):
			continue
		var g:= k as GeometryInstance3D
		if g.material_overlay == _glow_mat:
			g.material_overlay = _glow_prev [k]
	_glow_prev.clear()
	_glow_id = 0


	for g in _glow_lent:
		if is_instance_valid(g) and g.is_inside_tree() and not g.is_queued_for_deletion():
			BeltBatch.adopt(g)
	_glow_lent.clear()
	if not _glow_apart.is_empty():


		var apart:= _glow_apart
		_glow_apart = []
		if builds != null and is_instance_valid(builds):
			builds.end_enclosed_show(apart)


const DISMANTLE_TOO_FAR:= 40.0


const DISMANTLE_YARD_HINT:= 8.0


func dismantle_miss_reason() -> String:
	if player == null or builds == null:
		return ""
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * DISMANTLE_TOO_FAR)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD

	q.collide_with_areas = true
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	var collider:= hit.get("collider") as CollisionObject3D
	var dist:= from.distance_to(hit.get("position"))
	if builds.owner_of(collider) != null:
		return tr("get closer") if dist > dismantle_reach() else ""


	if dist > DISMANTLE_YARD_HINT or collider == null or collider.collision_layer & Cfg.L_PILE:
		return ""
	return tr("you can only take down things you built")


func _refuse_dismantle(why: String) -> void:
	if why == "":
		return
	Audio.play("build_denied")
	var hud: Hud = player.carry.hud if player.carry != null else null
	if hud != null:
		hud.show_toast(tr("CAN'T DISMANTLE  ·  %s") % Cfg.upper(why), 3.0,
			Hud.LOST_TOAST_COLOR)


func dismantle(target: Node3D) -> void:
	if builds == null or target == null or not is_instance_valid(target):
		return


	CrashReport.note_doing("dismantling %s" % _report_name(target))
	var gone_at:= target.global_position


	var lost:= builds.hay_inside(target) if builds.demolish_blocked_reason(target) == "" else ""
	var hud: Hud = player.carry.hud if player != null and player.carry != null else null
	if lost != "" and hud != null:
		hud.show_toast(tr("%s LOST") % Cfg.upper(lost), 3.0, Hud.LOST_TOAST_COLOR)
	Audio.play_3d("build_demolish", gone_at, -5.0)
	Audio.play("coins", -6.0)


	if _glow_id != 0 and _glowing_on(target):
		_wreck = null
		_clear_wreck_glow()

	var fx: BuildFx = null
	var apart: Array [Node3D] = []
	if player != null and Cfg.build_fx:
		var pieces:= _pieces_of(target)


		apart = builds.show_enclosed_apart(pieces)
		fx = BuildFx.wreck(builds.get_parent(), pieces, player.camera)
	var before:= hud.toast_text() if hud != null else ""
	var refund:= builds.demolish(target)
	GameState.add_money(refund)


	if refund > 0.0 and hud != null and hud.toast_text() == before:
		if lost != "":
			hud.show_toast(tr("MONEY BACK  ·  +$%s  ·  %s LOST") % [
				Hud.money_text(refund), Cfg.upper(lost)], 3.0, Hud.LOST_TOAST_COLOR)
		else:
			hud.show_toast(tr("MONEY BACK  ·  +$%s") % Hud.money_text(refund))


	if not apart.is_empty():
		builds.end_enclosed_show(apart)


	if target.is_queued_for_deletion():
		dismantled += 1
	elif fx != null:
		fx.abandon()


func reverse_target() -> Conveyor:
	return dismantle_target() as Conveyor


func reverse_progress() -> float:
	if _flip == null:
		return -1.0
	return clampf(_flip_time / REVERSE_HOLD, 0.0, 1.0)


func begin_reverse() -> bool:
	if player == null or builds == null or not player.is_mouse_captured():
		return false
	var target:= reverse_target()
	if target == null:
		return false
	_flip = target
	_flip_time = 0.0


	_flip_noise = 0.0
	Audio.play_3d("build_dismantle", target.global_position, -6.0)
	return true


func _tick_reverse(delta: float) -> void:
	if _flip == null:
		return
	if not Input.is_action_pressed("interact") or not player.is_mouse_captured():
		_flip = null
		return


	if not is_instance_valid(_flip) or not builds.same_building(reverse_target(), _flip):
		_flip = null
		return
	_flip_time += delta
	if _flip_time - _flip_noise >= REVERSE_RATCHET and _flip_time < REVERSE_HOLD - REVERSE_RATCHET * 0.5:
		_flip_noise = _flip_time
		Audio.play_3d("build_dismantle", _flip.global_position, -6.0)
	if _flip_time < REVERSE_HOLD:
		return
	reverse(_flip)
	_flip = null


func reverse(target: Conveyor) -> void:
	if builds == null or target == null or not is_instance_valid(target):
		return
	var at:= target.global_position
	if not builds.reverse_conveyor(target):
		return
	reversed += 1
	last_reversed = target
	Audio.play_3d("machine_clunk", at, -4.0)


func _tick_peek() -> void:
	var kind:= reach_kind()


	var want:= _active and kind != "" and player.is_mouse_captured() and not player.free_move
	if not want:
		if _peek:
			_peek = false
			_peek_kind = ""
			_peek_at = Vector3.INF
			_end_peek()
		return
	var at:= player.global_position


	if _peek and kind == _peek_kind and _peek_at.distance_to(at) < 1.0:
		return


	if kind != _peek_kind:
		_end_peek()
	_peek = true
	_peek_kind = kind
	_peek_at = at
	builds.show_reach(at, Cfg.RANGE_PEEK_DIST, kind)


func reach_kind() -> String:
	match _mode:
		Mode.HAY_DRONE: return "drone"
		Mode.PISTON_RAKE: return "rake"
		Mode.ROBOTIC_ARM: return "arm"


		Mode.PELLETIZER: return "pelletizer"
	return ""


func _end_peek() -> void:
	for kind: String in BuildManager.REACH_KINDS:
		builds.show_reach(Vector3.ZERO, -1.0, kind)
	var panel:= player.rake_panel
	if panel != null and panel.is_open():
		builds.show_rake_range(panel.rake())


	var mill_panel:= player.pelletizer_panel
	if mill_panel != null and mill_panel.is_open():
		builds.show_mill_range(mill_panel.mill())


func is_peeking() -> bool:
	return _peek


func _tick_enclosed_hint(delta: float) -> void:
	if _hint_flow == null:
		return
	_hint_since += delta
	if _hint_since >= ENCLOSED_HINT_REFRESH:
		_hint_since = 0.0
		_aim_enclosed_hint()
	var fade:= delta / ENCLOSED_HINT_FADE
	if _hint_wye != null and not is_instance_valid(_hint_wye):
		_hint_wye = null
	var wanted:= not _hint_runs.is_empty() or _hint_wye != null
	_hint_level = move_toward(_hint_level, 1.0 if wanted else 0.0, fade)
	if _hint_level <= 0.0:
		if _hint_flow.visible:
			_hint_flow.visible = false
			_hint_flow.multimesh.visible_instance_count = 0
		return


	if not _active:
		_flow_phase = fmod(_flow_phase + delta * Tech.belt_speed(), 1024.0)
	if _hint_wye != null:
		_draw_wye_hint()
		return
	var chains: Array = []
	for run: Conveyor in _hint_runs:
		if not is_instance_valid(run):
			continue
		var from:= run.laid_start()
		var to:= run.laid_end()
		if from.distance_to(to) < 0.05:
			continue
		chains.append(PackedVector3Array([from, to]))
	if chains.is_empty():
		_hint_flow.visible = false
		_hint_flow.multimesh.visible_instance_count = 0
		return
	_hint_flow.visible = true
	var tint:= ENCLOSED_HINT_TINT
	tint.a = _hint_level
	_fill_flow(_hint_flow.multimesh, chains, ARROW_PITCH, ENCLOSED_HINT_LIFT, tint,
		player.eye_position())


func enclosed_hint_runs() -> Array [Conveyor]:
	return _hint_runs


func _aim_enclosed_hint() -> void:
	_hint_runs.clear()
	_hint_wye = null
	if player == null or builds == null or not is_instance_valid(builds):
		return
	if not player.is_mouse_captured():
		return
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * dismantle_reach())
	q.collision_mask = Cfg.L_BUILD
	q.collide_with_areas = true
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var owner_node:= builds.owner_of(hit.get("collider") as Node)

	if owner_node is ConveyorSplitter or owner_node is ConveyorJoiner:
		_hint_wye = owner_node
		return
	var found:= owner_node as EnclosedConveyor
	if found == null:
		return
	for piece: Conveyor in builds.line_of(found):
		if piece is EnclosedConveyor and is_instance_valid(piece):
			_hint_runs.append(piece)


func wye_hint_target() -> Node3D:
	return _hint_wye


func _draw_wye_hint() -> void:
	var hint:= wye_hint_chains(_hint_wye)
	var chains: Array = hint ["chains"]
	if chains.is_empty():
		_hint_flow.visible = false
		_hint_flow.multimesh.visible_instance_count = 0
		return
	_hint_flow.visible = true
	var alphas: PackedFloat32Array = hint ["alphas"]
	if _hint_wye is ConveyorCompactSplitter:
		var tint:= ENCLOSED_HINT_TINT
		tint.a = _hint_level
		var box:= (_hint_wye as ConveyorCompactSplitter).model_box()
		var lift:= (box.end.y if box.size != Vector3.ZERO else 0.0) + WYE_HINT_ROOF_CLEAR
		_fill_flow(_hint_flow.multimesh, chains, WYE_ARROW_PITCH, lift, tint,
			player.eye_position(), alphas)
		return
	_fill_flow(_hint_flow.multimesh, chains, WYE_ARROW_PITCH, ARROW_LIFT,
		Color(1.0, 1.0, 1.0, BeltFlipVfx.IDLE_ALPHA * _hint_level), Vector3.INF, alphas)


static func wye_hint_chains(node: Node3D) -> Dictionary:
	var out:= { "chains": [], "alphas": PackedFloat32Array() }

	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return out
	var centre:= node.global_position
	if node is ConveyorCompactSplitter:
		var box:= node as ConveyorCompactSplitter
		var live:= 0.0
		var doors: Array = []
		var shades: Array = []
		for side: int in ConveyorCompactSplitter.OUTPUTS:
			var path:= box.route(side)
			if path == null or not is_instance_valid(path.downstream):
				continue
			var rule:= box.filter_for(side)
			if box.smart and rule == ConveyorCompactSplitter.RULE_NONE:
				continue
			var shade:= WYE_HINT_SPILL if box.smart and rule == ConveyorCompactSplitter.RULE_OVERFLOW else 1.0
			live = maxf(live, shade)
			doors.append(PackedVector3Array([centre,
				box.port(side) + box.arm_travel(side) * WYE_FLOW_REACH]))
			shades.append(shade)
		_hint_chain(out, PackedVector3Array([box.port_in() - box.forward() * WYE_FLOW_REACH,
			centre]), live if live > 0.0 else WYE_HINT_SPILL)
		for i in doors.size():
			_hint_chain(out, doors [i], shades [i])
		return out
	if node is ConveyorTSplitter:
		var t:= node as ConveyorTSplitter


		var shown:= t.shown_setup()
		if not shown.is_empty():
			var ins: Array = shown ["ins"]
			for lane: int in ConveyorTSplitter.LANES:
				var tip:= _t_lane_tip(t, lane)
				_hint_chain(out, PackedVector3Array([tip, centre] if ins.has(lane)
					else [centre, tip]), 1.0)
			return out
		var lanes:= ConveyorTSplitter.exits_of(t.entry)
		var fed:= 1.0 if t.fed else WYE_HINT_SPILL
		_hint_chain(out, PackedVector3Array([_t_lane_tip(t, t.entry), centre]), fed)
		for side: int in ConveyorSplitter.SIDES:
			_hint_chain(out, PackedVector3Array([centre, _t_lane_tip(t, lanes [side])]),
				minf(fed, _arm_shade(t, side)))
		return out
	if node is ConveyorSplitter:
		var wye:= node as ConveyorSplitter
		var forward:= wye.forward()
		_hint_chain(out, PackedVector3Array([wye.port_in() - forward * WYE_FLOW_REACH,
			centre]), 1.0)
		for side: int in ConveyorSplitter.SIDES:
			var line: PackedVector3Array
			if wye is ConveyorUSplitter:
				line = (wye as ConveyorUSplitter).arm_line(side)
				line.append(wye.port(side) + forward * WYE_FLOW_REACH)
			else:
				var mouth:= wye.port(side)
				line = PackedVector3Array([centre,
					mouth + (mouth - centre).normalized() * WYE_FLOW_REACH])
			_hint_chain(out, line, _arm_shade(wye, side))
		return out
	if node is ConveyorJoiner:
		var joiner:= node as ConveyorJoiner
		for side: int in ConveyorJoiner.SIDES:
			var line: PackedVector3Array
			if joiner is ConveyorUJoiner:
				line = PackedVector3Array([joiner.port(side)
					- joiner.forward() * WYE_FLOW_REACH])
				line.append_array((joiner as ConveyorUJoiner).arm_line(side))
			else:
				line = PackedVector3Array([joiner.port(side)
					- joiner.arm_travel(side) * WYE_FLOW_REACH, centre])
			_hint_chain(out, line, 1.0)
		_hint_chain(out, PackedVector3Array([centre,
			joiner.port_out() + joiner.forward() * WYE_FLOW_REACH]), 1.0)
	return out


static func _arm_shade(wye: ConveyorSplitter, side: int) -> float:
	if wye.forced_side >= 0:
		return 1.0 if side == wye.forced_side else 0.0
	if wye.priority_side >= 0 and side != wye.priority_side:
		return WYE_HINT_SPILL
	return 1.0


static func _hint_chain(out: Dictionary, points: PackedVector3Array, shade: float) -> void:
	if shade <= 0.0:
		return
	(out ["chains"] as Array).append(points)
	var alphas: PackedFloat32Array = out ["alphas"]
	alphas.append(shade)
	out ["alphas"] = alphas


func _process(delta: float) -> void:
	if player == null or builds == null:
		return


	_tick_dismantle(delta)
	_tick_wreck_glow()
	_tick_reverse(delta)


	_tick_peek()


	_tick_enclosed_hint(delta)
	if not _active:
		return


	builds.ghost_reading = true
	_shed_hit = false
	_update_ghost(delta)
	if _shed_hit and not bool(_eval.get("ok", true)):
		shed_refusals += 1
	builds.ghost_reading = false
	_sync_ghost_rails()


func _sync_ghost_rails() -> void:
	var n:= 0
	if _ghost.multimesh.mesh == ConveyorKit.segment_mesh():
		n = _ghost.multimesh.visible_instance_count
	for rail in _ghost_rails:
		rail.multimesh.visible_instance_count = n
		rail.material_override = _ghost.material_override
	var counts:= [0, 0]
	if n > 0:
		for e: Array in _ghost_drum_ends:
			var kind:= 1 if bool(e [0]) else 0
			if counts [kind] >= GHOST_DRUMS:
				continue
			_ghost_drums [kind].multimesh.set_instance_transform(counts [kind],
				Transform3D(e [2] as Basis, e [1] as Vector3))
			counts [kind] += 1
	for kind in 2:
		_ghost_drums [kind].multimesh.visible_instance_count = counts [kind]
		_ghost_drums [kind].material_override = _ghost.material_override


func _drop_ghost_drums(points: PackedVector3Array, from: Vector3, to: Vector3) -> void:
	if points.is_empty():
		return
	var keep: Array = []
	for e: Array in _ghost_drum_ends:
		var at: Vector3 = e [1]
		if bool(e [0]) and at == points [points.size() - 1] and at.distance_to(to) > 0.001:
			continue
		if not bool(e [0]) and at == points [0] and at.distance_to(from) > 0.001:
			continue
		keep.append(e)
	_ghost_drum_ends = keep


func _update_ghost(delta: float) -> void:


	_flow_phase = fmod(_flow_phase + delta * Tech.belt_speed(), 1024.0)

	_update_grid()
	if _mode == Mode.ROBOTIC_ARM:
		_update_arm_ghost()
		return
	if _mode == Mode.PLATFORM:
		_update_deck_ghost()
		return
	if _mode == Mode.STAIR:
		_update_stair_ghost()
		return
	if _mode == Mode.RAILING:
		_update_rail_ghost()
		return
	if _is_wall(_mode):
		_update_wall_ghost()
		return
	if _is_roof(_mode):
		_update_roof_ghost()
		return
	if _mode == Mode.HAY_STAIRS:
		_update_stairs_ghost()
		return
	if _mode == Mode.CABINET:
		_update_cabinet_ghost()
		return
	if _mode == Mode.NEEDLE_RADAR:
		_update_radar_ghost()
		return
	if _mode == Mode.PAINT_BOARD:
		_update_paintboard_ghost()
		return
	if _mode == Mode.WORK_LAMP:
		_update_worklamp_ghost()
		return
	if _mode == Mode.SCANNER:
		_update_scanner_ghost()
		return
	if _mode == Mode.HAY_DRONE:
		_update_drone_ghost()
		return
	if _mode == Mode.PISTON_RAKE:
		_update_rake_ghost()
		return
	if _mode == Mode.PELLETIZER:
		_update_pelletizer_ghost()
		return
	if _mode == Mode.GENERATOR or _mode == Mode.GAS_PLANT:
		_update_generator_ghost()
		return
	if _mode == Mode.BOREHOLE:
		_update_borehole_ghost()
		return
	if _mode == Mode.WATER_PIPE:
		_update_pipe_ghost()
		return
	if _mode == Mode.WATER_SPLITTER:
		_update_water_splitter_ghost()
		return
	if _is_post(_mode):
		_update_pole_ghost()
		return
	if _mode == Mode.DUMP_HATCH:
		_update_dump_hatch_ghost()
		return
	if _mode == Mode.LAUNCHER:
		_update_launcher_ghost()
		return
	if _mode == Mode.COMPRESSOR:
		_update_compressor_ghost()
		return
	if _mode == Mode.PULPER:
		_update_pulper_ghost()
		return
	if _mode == Mode.PAPER:
		_update_paper_ghost()
		return
	if _mode == Mode.BRIQUETTE:
		_update_briquette_ghost()
		return
	if _mode == Mode.HAY_LIFT:
		_update_lift_ghost()
		return
	if _mode == Mode.WRAPPER:
		_update_wrapper_ghost()
		return
	if _mode == Mode.SILO:
		_update_silo_ghost()
		return
	if _mode == Mode.SPLITTER:
		_update_splitter_ghost()
		return
	if _mode == Mode.COMPACT_SPLITTER or _mode == Mode.SMART_SPLITTER:
		_update_compact_splitter_ghost()
		return
	if _mode == Mode.JOINER:
		_update_joiner_ghost()
		return
	if _mode == Mode.U_SPLITTER:
		_update_u_splitter_ghost()
		return
	if _mode == Mode.T_SPLITTER:
		_update_t_splitter_ghost()
		return
	if _mode == Mode.U_JOINER:
		_update_u_joiner_ghost()
		return
	var point:= _aim_point()
	var from: Vector3
	var to: Vector3
	if _state == State.RUNNING and _upstream:
		_guide_turn = NAN
		from = point
		to = _anchor
	elif _state == State.RUNNING:
		from = _anchor
		to = _guided(_anchor, point)
	else:


		var dir:= player.look_direction()
		dir.y = 0.0
		dir = dir.normalized() if dir.length_squared() > 1e-06 else Vector3.BACK
		from = point
		to = point + dir * STUB_LENGTH


		if _starts_upstream(point):
			from = point - dir * STUB_LENGTH
			to = point
	_update_run(from, to, delta)


func _update_grid() -> void:
	if _grid_mesh == null:
		return


	if _levelling():
		_grid_mesh.visible = false
		return
	if not _gridding():
		_grid_mesh.visible = false
		return
	var hit:= _raw_surface_hit()
	var at: Vector3
	var mark: Vector3
	if hit.is_empty():


		var air:= player.eye_position() + player.look_direction() * _reach
		mark = air.snapped(Vector3.ONE * Cfg.BUILD_GRID_STEP)
		at = Vector3(air.x, mark.y, air.z)
	else:
		at = hit ["position"]
		mark = _grid_hit(hit) ["position"]
	_park_grid(at, mark)


func _park_grid(at: Vector3, mark: Vector3) -> void:
	_grid_mesh.visible = true
	_grid_mesh.global_position = Vector3(at.x, at.y + Cfg.BUILD_GRID_LIFT, at.z)
	_grid_mat.set_shader_parameter("mark", Vector2(mark.x, mark.z))


func _update_arm_ghost() -> void:
	var hit:= _surface_hit()
	var tier: Dictionary = Cfg.ROBOT_ARM_TIERS [_arm_tier]


	var cost:= builds.arm_price(_arm_tier)
	if hit.is_empty():


		var blocked:= _crowded_reason("arm", builds.arms_left(), Cfg.ARM_LIMIT)
		_eval = { "ok": false, "length": 0.0, "cost": cost,
			"reason": blocked if blocked != "" else tr("aim at ground") }
		var fallback:= player.eye_position() + player.look_direction() * _reach
		_arm_ghost.global_position = fallback
		_arm_ghost.set_preview_valid(false)
		_clear_arm_feeds()
		_hide_arm_neighbours()
		return
	var point: Vector3 = hit ["position"]
	var normal: Vector3 = hit ["normal"]
	_arm_ghost.global_position = point + normal * 0.015


	var yaw:= player.global_rotation.y + PI
	if _gridding():
		var forward:= _aim_forward()
		yaw = atan2(forward.x, forward.z)
	_arm_ghost.global_rotation = Vector3(0.0, yaw, 0.0)
	_eval = _evaluate_arm(point, normal, cost, float(tier ["scale"]), hit.get("collider"))
	_arm_ghost.set_preview_valid(_eval ["ok"])
	_update_arm_feeds(_arm_ghost.global_position)
	_tint_arm_feeds(_eval ["ok"])
	_update_arm_neighbours(_arm_ghost.global_position)


const ARM_KEEP_MARGIN:= 2.0


func _update_arm_neighbours(at: Vector3) -> void:
	var near:= builds.arm_reach_neighbours(at, _arm_tier, ARM_KEEP_MARGIN)
	if _arm_keep_ok_mat == null:
		var calm:= RoboticArm.COL_RING
		_arm_keep_ok_mat = HayDrone._new_ring_mat(Color(calm.r, calm.g, calm.b, 0.35))
		var bad:= Cfg.COL_GHOST_BAD
		_arm_keep_bad_mat = HayDrone._new_ring_mat(Color(bad.r, bad.g, bad.b, 0.7))

	if not _arm_keep_rings.is_empty() and (not is_instance_valid(_arm_keep_rings [0])
			or _arm_keep_rings [0].get_parent() != _arm_ghost):
		_arm_keep_rings.clear()
	var blockers: Array [Node3D] = []
	for i in near.size():
		var n: Dictionary = near [i]
		var arm:= n ["arm"] as RoboticArm
		var blocking:= bool(n ["blocking"])
		if blocking:
			blockers.append(arm)
		var ring:= _arm_keep_ring(i)


		ring.mesh = RoboticArm._ring_part(snappedf(float(n ["radius"]), 0.01))
		ring.material_override = _arm_keep_bad_mat if blocking else _arm_keep_ok_mat
		ring.global_position = Vector3(arm.global_position.x,
			at.y + RoboticArm.RING_LIFT, arm.global_position.z)
		ring.visible = true
	for i in range(near.size(), _arm_keep_rings.size()):
		_arm_keep_rings [i].visible = false
	_tint_arm_blockers(blockers)


func _arm_keep_ring(i: int) -> MeshInstance3D:
	if i < _arm_keep_rings.size():
		return _arm_keep_rings [i]
	var ring:= MeshInstance3D.new()
	ring.name = "ArmKeepOut%d" % i
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arm_ghost.add_child(ring)
	ring.top_level = true
	_arm_keep_rings.append(ring)
	return ring


func _hide_arm_neighbours() -> void:
	for ring in _arm_keep_rings:
		if is_instance_valid(ring):
			ring.visible = false
	_tint_arm_blockers([] as Array [Node3D])


func _tint_arm_blockers(arms: Array [Node3D]) -> void:
	if arms == _arm_blockers:
		return
	var overlay:= ConveyorKit.ghost_material(false)
	for arm in _arm_blockers:
		if arms.has(arm) or not is_instance_valid(arm):
			continue
		for node in arm.find_children("*", "MeshInstance3D", true, false):
			var mesh:= node as MeshInstance3D
			if mesh.material_overlay == overlay:
				mesh.material_overlay = null
	for arm in arms:
		if not _arm_blockers.has(arm):
			_set_overlay(arm, overlay)
	_arm_blockers = arms.duplicate()


func _tint_arm_feeds(ok: bool) -> void:
	if _arm_feed_mat == null:
		return
	var tint: Color = Cfg.COL_GHOST_OK if ok else Color(0.72, 0.72, 0.72)
	_arm_feed_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.45 if ok else 0.22)


const ARM_FEED_MOVE:= 0.02
const ARM_FEED_MSEC:= 250


func _update_arm_feeds(at: Vector3) -> void:
	var now:= Time.get_ticks_msec()
	if _arm_feed_tier == _arm_tier and _arm_feed_at.distance_to(at) < ARM_FEED_MOVE and now - _arm_feed_msec < ARM_FEED_MSEC and is_instance_valid(_arm_feed_mesh):
		return
	_arm_feed_at = at
	_arm_feed_tier = _arm_tier
	_arm_feed_msec = now
	var tier: Dictionary = Cfg.ROBOT_ARM_TIERS [_arm_tier]
	var shoulder:= at + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * float(tier ["scale"])
	var reach:= float(tier ["reach"]) * RoboticArm.REACH_FRACTION
	arm_feeds = builds.conveyor_drops(shoulder, reach)
	arm_feed_near = builds.arm_neighbour(shoulder, reach) if arm_feeds.is_empty() else { }
	_draw_arm_feeds(shoulder, reach)


func _clear_arm_feeds() -> void:
	arm_feeds.clear()
	arm_feed_near = { }
	_arm_feed_at = Vector3.INF
	if _arm_feed_draw != null:
		_arm_feed_draw.clear_surfaces()


func _draw_arm_feeds(shoulder: Vector3, reach: float) -> void:
	if not is_instance_valid(_arm_feed_mesh):
		_arm_feed_draw = ImmediateMesh.new()
		_arm_feed_mesh = MeshInstance3D.new()
		_arm_feed_mesh.name = "ArmFeeds"
		_arm_feed_mesh.mesh = _arm_feed_draw
		_arm_feed_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat:= StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED


		mat.no_depth_test = true
		var tint:= Cfg.COL_GHOST_OK
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.45)
		_arm_feed_mesh.material_override = mat
		_arm_feed_mat = mat
		_arm_ghost.add_child(_arm_feed_mesh)
		_arm_feed_mesh.top_level = true
		_arm_feed_mesh.global_transform = Transform3D.IDENTITY
	_arm_feed_draw.clear_surfaces()
	if arm_feeds.is_empty():
		return
	var runs: Array = []
	for feed: Dictionary in arm_feeds:
		runs.append(feed.get("conveyor"))


	var verts:= RoboticArm.reach_strip(runs, shoulder, reach)
	if verts.is_empty():
		return
	_arm_feed_draw.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		_arm_feed_draw.surface_add_vertex(v)
	_arm_feed_draw.surface_end()


func _update_deck_ghost() -> void:
	var hit:= _surface_hit()


	var point: Vector3
	var height: Variant = null
	if hit.is_empty():
		point = player.eye_position() + player.look_direction() * _reach
	else:
		height = builds.deck_height_at(hit.get("collider") as Node)
		point = _deck_rest_point(hit)
	if height != null:
		point.y = height
	else:


		var raw:= point.y
		point.y = builds.snap_deck_height(point)


		if _levelling() and _state == State.AIMING and point.y == raw:
			point.y = _deck_level(point)
			point.y = builds.snap_deck_height(point)

	var centre: Vector3
	var span: Vector2
	if _state == State.RUNNING:


		var across_x:= Vector2(_anchor.z, _anchor.z + _anchor_span.y)
		var across_z:= Vector2(_anchor.x, _anchor.x + _anchor_span.x)
		var x:= builds.deck_extent(point.x, _anchor.x, _anchor_span.x, 0,
			_anchor.y, across_x)
		var z:= builds.deck_extent(point.z, _anchor.z, _anchor_span.y, 1,
			_anchor.y, across_z)
		span = Vector2(x.y - x.x, z.y - z.x)
		centre = Vector3((x.x + x.y) * 0.5, _anchor.y, (z.x + z.y) * 0.5)
	else:
		span = Vector2(Cfg.PLATFORM_TILE, Cfg.PLATFORM_TILE)
		centre = _snap_tile(point, span)
	_deck_ghost.set_shape(centre, span)
	_eval = _evaluate_deck(centre, span)
	_deck_ghost.set_preview_valid(_eval ["ok"])


	_eval ["up"] = NAN
	_eval ["lift"] = -1
	var base_y:= _storey_base_y(centre)
	if not is_nan(base_y) and centre.y - base_y > Cfg.PLATFORM_THICK + 0.05:
		_eval ["up"] = centre.y - base_y
		_eval ["lift"] = HayLift.sections_to_deck(base_y, centre.y)
	if _levelling():


		_park_grid(centre, centre)


func _deck_level(at: Vector3) -> float:
	var floor_y:= _world_floor_y(at)
	if is_nan(floor_y):
		return at.y
	var first:= HayLift.deck_top_for(floor_y, 0)
	var n:= maxi(0, int(roundf((at.y - first) / Cfg.HAY_LIFT_SECTION)))
	var level:= first + Cfg.HAY_LIFT_SECTION * float(n)
	if not is_nan(_storey_under_y(at)):
		return level
	var ground:= _ground_rest_y(at)
	return ground if absf(at.y - ground) < absf(at.y - level) else level


func _storey_base_y(at: Vector3) -> float:
	var under:= _storey_under_y(at)
	return under if not is_nan(under) else _world_floor_y(at)


func _storey_under_y(at: Vector3) -> float:
	var under:= builds.deck_below(at)
	if under == null:
		return NAN
	var floor_y:= _world_floor_y(at)
	if not is_nan(floor_y) and under.top_y() - floor_y <= Cfg.PLATFORM_THICK + 0.05:
		return NAN
	return under.top_y()


func _ground_rest_y(at: Vector3) -> float:
	var floor_y:= _world_floor_y(at)
	if is_nan(floor_y):
		return at.y
	var half:= Cfg.PLATFORM_TILE * 0.5
	for corner: Vector2 in [Vector2(- half, - half), Vector2(half, - half),
			Vector2(- half, half), Vector2(half, half)]:
		var y:= _world_floor_y(Vector3(at.x + corner.x, floor_y, at.z + corner.y))
		if is_nan(y) or absf(y - floor_y) > FLUSH_FLAT:
			return floor_y + Cfg.PLATFORM_THICK
	return floor_y + Cfg.PLATFORM_FLUSH_LIFT


func _deck_rest_point(hit: Dictionary) -> Vector3:
	var p: Vector3 = hit ["position"]
	var normal: Vector3 = hit ["normal"]
	var floor_y:= _world_floor_y(p)
	if normal.y > 0.99 and not is_nan(floor_y) and absf(p.y - floor_y) <= FLUSH_FLAT:
		return Vector3(p.x, _ground_rest_y(p), p.z)
	return p + normal * Cfg.PLATFORM_THICK


func _world_floor_y(at: Vector3) -> float:
	var from:= at + Vector3.UP * 0.25
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_PROBE_DROP)
	q.collision_mask = Cfg.L_WORLD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return NAN
	return (hit ["position"] as Vector3).y


func _snap_tile(centre: Vector3, span: Vector2) -> Vector3:
	var out:= centre
	for axis in 2:
		var here: float = centre.x if axis == 0 else centre.z
		var half: float = (span.x if axis == 0 else span.y) * 0.5


		var mid: float = centre.z if axis == 0 else centre.x
		var other_half: float = (span.y if axis == 0 else span.x) * 0.5
		var across:= Vector2(mid - other_half, mid + other_half)
		var shift:= 0.0
		var best:= INF
		for side: float in [-1.0, 1.0]:
			var lip:= here + half * side


			var edge:= builds.deck_edge_near(lip, axis, centre.y,
				1 if side < 0.0 else -1, across)
			if is_nan(edge):
				continue


			var delta:= edge - lip
			if absf(delta) >= best:
				continue
			best = absf(delta)
			shift = delta
		if is_inf(best):
			var lo:= here - half
			shift = snappedf(lo, Cfg.PLATFORM_TILE) - lo
		if axis == 0:
			out.x += shift
		else:
			out.z += shift
	return out


func _evaluate_deck(centre: Vector3, span: Vector2) -> Dictionary:
	var cost:= Platform.cost_for(span)
	var r:= { "ok": false, "reason": "", "length": span.x * span.y, "cost": cost }
	if not GameState.can_afford(cost):
		r ["reason"] = tr("need %s") % _price(cost)
		return r
	var rect:= Rect2(Vector2(centre.x - span.x * 0.5, centre.z - span.y * 0.5), span)
	if builds.deck_overlap(rect, centre.y):
		r ["reason"] = tr("overlaps a deck")
		return r


	if is_nan(_solid_floor_y(centre)):
		r ["reason"] = tr("no ground under it")
		return r
	var hay_y:= _hay_top_y(centre)


	var bare_y:= _world_floor_y(centre)
	if not is_nan(hay_y) and hay_y > centre.y - Cfg.PLATFORM_THICK * 0.5 and (is_nan(bare_y) or hay_y > bare_y + FLUSH_FLAT):
		r ["reason"] = tr("in the hay")
		return r


	if builds.arm_through_deck(rect, centre.y) != null:
		r ["reason"] = tr("an arm is in the way")
		return r


	if builds.hatch_through_deck(rect, centre.y) != null:
		r ["reason"] = tr("blocked")
		return r


	_deck_probe.size = Vector3(
		maxf(0.1, span.x - DECK_EDGE_INSET * 2.0),
		DECK_HEADROOM,
		maxf(0.1, span.y - DECK_EDGE_INSET * 2.0))
	_deck_probe_query.transform = Transform3D(Basis(),
		centre + Vector3.UP * (Cfg.BUILD_FOOT_CLEAR + DECK_HEADROOM * 0.5))
	if _deck_room_blocked(_deck_probe_query, centre.y):
		r ["reason"] = tr("blocked")
		return r
	r ["ok"] = true
	return r


func _update_stair_ghost() -> void:
	if _state == State.RUNNING:
		_aim_stair_foot()
		return
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * _reach)
	q.collision_mask = Cfg.BUILD_SURFACE_MASK
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	var deck: Platform = null
	if not hit.is_empty():
		deck = builds.owner_of(hit.get("collider") as Node) as Platform

	if deck == null:
		_eval = _stair_eval(false, tr("aim at a deck"), 0.0, 0.0, 0.0)
		_stair_ghost.set_shape(from + player.look_direction() * _reach, 0.0, 1.0)
		_stair_ghost.set_preview_valid(false)
		return

	var edge: Dictionary = deck.nearest_edge(hit ["position"])
	_stair_outward = edge ["outward"]
	var head: Vector3 = edge ["point"]
	if _levelling():


		var rect:= deck.footprint()
		var half:= Cfg.STAIR_WIDTH * 0.5
		if absf(_stair_outward.x) > 0.5:
			head.z = clampf(snappedf(head.z, Cfg.BUILD_GRID_STEP),
				ceilf(rect.position.y + half), floorf(rect.end.y - half))
		else:
			head.x = clampf(snappedf(head.x, Cfg.BUILD_GRID_STEP),
				ceilf(rect.position.x + half), floorf(rect.end.x - half))
		_park_grid(head, head)


	_stair_ghost.set_shape(head,
		atan2(- _stair_outward.x, - _stair_outward.z), Cfg.STAIR_RISER)
	_eval = _stair_eval(true, "", 0.0, 0.0, Cfg.STAIR_PITCH)
	_stair_ghost.set_preview_valid(true)


func _aim_stair_foot() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = _stair_eval(false, tr("aim at the ground"), 0.0, 0.0, 0.0)
		_stair_ghost.set_preview_valid(false)
		return
	var land: Vector3 = hit ["position"]
	if _levelling():


		var out:= Vector3(land.x - _anchor.x, 0.0, land.z - _anchor.z).dot(_stair_outward)
		var metres:= maxf(Cfg.BUILD_GRID_STEP, snappedf(out, Cfg.BUILD_GRID_STEP))
		var on:= _anchor + _stair_outward * metres
		on.y = land.y
		land = _column_hit(hit, on) ["position"]
		_park_grid(land, land)
	var flat:= Vector3(land.x - _anchor.x, 0.0, land.z - _anchor.z)
	var run:= flat.length()
	var rise:= _anchor.y - land.y
	if run < 0.05:
		_eval = _stair_eval(false, tr("land it further out"), rise, 0.0, 0.0)
		_stair_ghost.set_preview_valid(false)
		return


	var pitch:= rise / run
	_stair_ghost.set_shape(_anchor, atan2(- flat.x, - flat.z),
		maxf(rise, Cfg.STAIR_RISER), pitch)
	_eval = _evaluate_stair(rise, pitch, flat / run)
	_stair_ghost.set_preview_valid(_eval ["ok"])


func _stair_eval(ok: bool, reason: String, rise: float, cost: float,
		pitch: float) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"length": rise,
		"cost": cost,
		"angle": rad_to_deg(atan(pitch)),
	}


func _evaluate_stair(rise: float, pitch: float, heading: Vector3) -> Dictionary:
	var shape_pitch:= clampf(pitch, Cfg.STAIR_PITCH_MIN, Cfg.STAIR_PITCH_MAX)
	var cost:= Stair.cost_for(
		clampf(rise, Cfg.STAIR_RISER, Cfg.STAIR_MAX_RISE), shape_pitch)
	if rise < Cfg.STAIR_RISER:
		return _stair_eval(false, tr("nothing to descend to"), rise, cost, shape_pitch)
	if rise > Cfg.STAIR_MAX_RISE:
		return _stair_eval(false, tr("too high to reach"), rise, cost, shape_pitch)


	if heading.dot(_stair_outward) < 0.05:
		return _stair_eval(false, tr("aim away from the deck"), rise, cost, shape_pitch)
	if pitch > Cfg.STAIR_PITCH_MAX:
		return _stair_eval(false, tr("too steep, land it further out"), rise, cost,
			shape_pitch)
	if pitch < Cfg.STAIR_PITCH_MIN:
		return _stair_eval(false, tr("too shallow, land it closer in"), rise, cost,
			shape_pitch)
	if not GameState.can_afford(cost):
		return _stair_eval(false, tr("need %s") % _price(cost), rise, cost, shape_pitch)
	if _stair_blocked(rise, shape_pitch):
		return _stair_eval(false, tr("blocked"), rise, cost, shape_pitch)
	return _stair_eval(true, "", rise, cost, shape_pitch)


func _stair_blocked(rise: float, pitch: float) -> bool:
	var run:= Stair.run_for(rise, pitch)
	var slope:= sqrt(run * run + rise * rise)
	_deck_probe.size = Vector3(
		Cfg.STAIR_WIDTH * Cfg.BUILD_CLEARANCE_SHRINK,
		DECK_HEADROOM,
		maxf(0.15, slope - Cfg.BUILD_END_SLACK * 2.0))
	var basis:= _stair_ghost.global_transform.basis * Basis(Vector3.RIGHT, - atan2(rise, run))
	var mid:= _stair_ghost.global_position + (_stair_ghost.foot() - _stair_ghost.global_position) * 0.5
	_deck_probe_query.transform = Transform3D(basis,
		mid + Vector3.UP * (Cfg.BUILD_FOOT_CLEAR + DECK_HEADROOM * 0.5))
	return _probe_hits(_deck_probe_query)


func _evaluate_arm(point: Vector3, normal: Vector3, cost: float, scale: float,
		surface: Object = null) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": 0.0, "cost": cost }


	var crowded:= _crowded_reason("arm", builds.arms_left(), Cfg.ARM_LIMIT)
	if crowded != "":
		result ["reason"] = crowded
		return result
	if normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result


	var footing:= _footing_reason(point)
	if footing != "":
		result ["reason"] = footing
		return result


	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result
	if not GameState.can_afford(cost):
		result ["reason"] = tr("need %s") % _price(cost)
		return result
	if builds.arm_reach_conflict(point, _arm_tier):
		result ["reason"] = tr("another arm in reach")
		return result


	if builds.deck_through_arm(point, _arm_tier) != null:
		result ["reason"] = tr("a deck is in the way")
		return result
	_arm_probe.radius = 0.78 * scale
	_arm_probe.height = 0.86 * scale
	_arm_probe_query.transform = Transform3D(Basis(),
		point + Vector3.UP * (_arm_probe.height * 0.5 + 0.055))
	if _probe_hits(_arm_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _update_cabinet_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		var gift:= _gift_for("cabinet")
		_eval = { "ok": false, "reason": tr("aim at ground"),
			"cost": 0.0 if gift else Cfg.CABINET_COST, "gift": gift }
		_cabinet_ghost.global_position = (player.eye_position()
			+ player.look_direction() * _reach)
		_cabinet_ghost.set_preview_valid(false)
		return
	var floor_at: Vector3 = hit ["position"]


	var forward:= - _aim_forward(- Vector3.BACK)
	_cabinet_ghost.global_position = floor_at
	_cabinet_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_cabinet(floor_at, forward, hit ["normal"], hit.get("collider"))
	_cabinet_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_cabinet(at: Vector3, forward: Vector3, normal: Vector3,
		surface: Object = null) -> Dictionary:


	var gift:= _gift_for("cabinet")
	var cost:= 0.0 if gift else Cfg.CABINET_COST
	var result:= { "ok": false, "reason": "", "cost": cost, "gift": gift }


	if normal.dot(Vector3.UP) < 0.86:
		result ["reason"] = tr("needs level ground")
		return result


	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result


	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result


	if builds.has_cabinet():
		result ["reason"] = tr("you already have a cabinet")

		result ["stuck"] = true
		return result
	if not GameState.can_afford(cost):
		result ["reason"] = tr("need %s") % _price(cost)
		return result


	var size:= Cfg.CABINET_SIZE
	var depth:= size.z + Cfg.CABINET_DOOR_CLEAR
	_cabinet_probe.size = Vector3(size.x * Cfg.BUILD_CLEARANCE_SHRINK,
		size.y - 0.12, depth * Cfg.BUILD_CLEARANCE_SHRINK)
	var basis:= Basis(Vector3.UP, atan2(forward.x, forward.z))


	var centre:= at + Vector3(0, size.y * 0.5, 0) + forward * (Cfg.CABINET_DOOR_CLEAR * 0.5)
	_cabinet_probe_query.transform = Transform3D(basis, centre)
	if _probe_hits(_cabinet_probe_query):
		result ["reason"] = tr("no room for the doors")
		return result
	result ["ok"] = true
	return result


func _place_cabinet() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	var gift:= bool(_eval.get("gift", false))
	if gift:
		if not _pay_gift("cabinet"):
			Audio.play("build_denied")
			return
	elif not _pay(Cfg.CABINET_COST):
		Audio.play("build_denied")
		return
	var at:= _cabinet_ghost.global_position
	var yaw:= _cabinet_ghost.global_rotation.y
	builds.add_cabinet(at, yaw, gift)
	Audio.play_3d("build_place", at)


func _update_radar_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "cost": Cfg.RADAR_COST }
		_radar_ghost.global_position = (player.eye_position()
			+ player.look_direction() * _reach)
		_radar_ghost.set_preview_valid(false)
		return
	var floor_at: Vector3 = hit ["position"]
	var forward:= - _aim_forward(- Vector3.BACK)
	_radar_ghost.global_position = floor_at
	_radar_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_radar(floor_at, forward, hit ["normal"], hit.get("collider"))
	_radar_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_radar(at: Vector3, forward: Vector3, normal: Vector3,
		surface: Object = null) -> Dictionary:
	var result:= { "ok": false, "reason": "", "cost": Cfg.RADAR_COST }


	if normal.dot(Vector3.UP) < 0.86:
		result ["reason"] = tr("needs level ground")
		return result
	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result


	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result


	if builds.has_needle_radar():
		result ["reason"] = tr("you already have a satellite dish")
		result ["stuck"] = true
		return result
	if not GameState.can_afford(Cfg.RADAR_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.RADAR_COST)
		return result


	var size:= Cfg.RADAR_SIZE
	_radar_probe.size = Vector3(size.x * Cfg.BUILD_CLEARANCE_SHRINK,
		size.y - 0.12, size.z * Cfg.BUILD_CLEARANCE_SHRINK)
	var basis:= Basis(Vector3.UP, atan2(forward.x, forward.z))
	_radar_probe_query.transform = Transform3D(basis, at + Vector3(0, size.y * 0.5, 0))
	if _probe_hits(_radar_probe_query):
		result ["reason"] = tr("no room for the dish")
		return result
	result ["ok"] = true
	return result


func _place_radar() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.RADAR_COST):
		Audio.play("build_denied")
		return
	var at:= _radar_ghost.global_position
	var yaw:= _radar_ghost.global_rotation.y
	builds.add_needle_radar(at, yaw)
	Audio.play_3d("build_place_big", at, -3.0)


func _update_paintboard_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "cost": Cfg.PAINT_BOARD_COST }
		_paintboard_ghost.global_position = (player.eye_position()
			+ player.look_direction() * _reach)
		_paintboard_ghost.set_preview_valid(false)
		return
	var floor_at: Vector3 = hit ["position"]


	var forward:= - _aim_forward(- Vector3.BACK)
	_paintboard_ghost.global_position = floor_at
	_paintboard_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_paintboard(floor_at, forward, hit ["normal"], hit.get("collider"))
	_paintboard_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_paintboard(at: Vector3, forward: Vector3, normal: Vector3,
		surface: Object = null) -> Dictionary:
	var result:= { "ok": false, "reason": "", "cost": Cfg.PAINT_BOARD_COST }


	if normal.dot(Vector3.UP) < 0.86:
		result ["reason"] = tr("needs level ground")
		return result


	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result
	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result
	if not GameState.can_afford(Cfg.PAINT_BOARD_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.PAINT_BOARD_COST)
		return result


	var size:= Cfg.PAINT_BOARD_SIZE
	_board_probe.size = Vector3(size.x * Cfg.BUILD_CLEARANCE_SHRINK,
		size.y - 0.12, size.z * Cfg.BUILD_CLEARANCE_SHRINK)
	var basis:= Basis(Vector3.UP, atan2(forward.x, forward.z))
	_board_probe_query.transform = Transform3D(basis,
		at + Vector3(0, size.y * 0.5, 0))
	if _probe_hits(_board_probe_query):
		result ["reason"] = tr("no room for the board")
		return result
	result ["ok"] = true
	return result


func _place_paintboard() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.PAINT_BOARD_COST):
		Audio.play("build_denied")
		return
	var at:= _paintboard_ghost.global_position
	var yaw:= _paintboard_ghost.global_rotation.y
	builds.add_paint_board(at, yaw)
	Audio.play_3d("build_place", at)


func _update_worklamp_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "cost": Cfg.WORK_LAMP_COST }
		_worklamp_ghost.global_position = (player.eye_position()
			+ player.look_direction() * _reach)
		_worklamp_ghost.set_preview_valid(false)
		return
	var floor_at: Vector3 = hit ["position"]
	var forward:= _aim_forward(- Vector3.BACK)
	_worklamp_ghost.global_position = floor_at
	_worklamp_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_worklamp(floor_at, forward, hit ["normal"], hit.get("collider"))
	_worklamp_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_worklamp(at: Vector3, forward: Vector3, normal: Vector3,
		surface: Object = null) -> Dictionary:
	var result:= { "ok": false, "reason": "", "cost": Cfg.WORK_LAMP_COST }


	if normal.dot(Vector3.UP) < 0.86:
		result ["reason"] = tr("needs level ground")
		return result

	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result
	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result
	if not GameState.can_afford(Cfg.WORK_LAMP_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.WORK_LAMP_COST)
		return result


	var size:= Cfg.WORK_LAMP_SIZE
	_board_probe.size = Vector3(size.x * Cfg.BUILD_CLEARANCE_SHRINK,
		size.y - 0.12, size.z * Cfg.BUILD_CLEARANCE_SHRINK)
	var basis:= Basis(Vector3.UP, atan2(forward.x, forward.z))
	_board_probe_query.transform = Transform3D(basis,
		at + Vector3(0, size.y * 0.5, 0))
	if _probe_hits(_board_probe_query):
		result ["reason"] = tr("no room for the lamp")
		return result
	result ["ok"] = true
	return result


func _place_worklamp() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.WORK_LAMP_COST):
		Audio.play("build_denied")
		return
	var at:= _worklamp_ghost.global_position
	var yaw:= _worklamp_ghost.global_rotation.y
	builds.add_work_lamp(at, yaw)
	Audio.play_3d("build_place", at)


func _update_stairs_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "cost": Cfg.HAY_STAIRS_COST }
		_stairs_ghost.global_position = (player.eye_position()
			+ player.look_direction() * _reach)
		_stairs_ghost.set_preview_valid(false)
		return
	var floor_at: Vector3 = hit ["position"]
	var forward:= - _aim_forward(Vector3.BACK)
	_stairs_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_stairs_ghost.global_position = floor_at


	if _gridding():
		var port:= _stairs_ghost.outfeed_port()
		var shift:= Vector3(snappedf(port.x, Cfg.BUILD_GRID_STEP) - port.x, 0.0,
			snappedf(port.z, Cfg.BUILD_GRID_STEP) - port.z)
		if not shift.is_zero_approx():
			hit = _column_hit(hit, floor_at + shift)
			floor_at = hit ["position"]
			_stairs_ghost.global_position = floor_at
	_eval = _evaluate_stairs(floor_at, forward, hit ["normal"], hit.get("collider"))
	_stairs_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_stairs(at: Vector3, forward: Vector3, normal: Vector3,
		surface: Object = null) -> Dictionary:
	var result:= { "ok": false, "reason": "", "cost": Cfg.HAY_STAIRS_COST }


	if normal.dot(Vector3.UP) < 0.86:
		result ["reason"] = tr("needs level ground")
		return result


	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result
	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result
	if builds.stairs_overlap(at):
		result ["reason"] = tr("too close to another one")
		return result
	if not GameState.can_afford(Cfg.HAY_STAIRS_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.HAY_STAIRS_COST)
		return result


	_stairs_probe.size = Vector3(2.04 * Cfg.BUILD_CLEARANCE_SHRINK, 3.0,
		1.3 * Cfg.BUILD_CLEARANCE_SHRINK)
	var basis:= Basis(Vector3.UP, atan2(forward.x, forward.z))
	_stairs_probe_query.transform = Transform3D(basis, at + Vector3(0, 1.55, 0))
	if _probe_hits(_stairs_probe_query):
		result ["reason"] = tr("no room")
		return result
	result ["ok"] = true
	return result


func _place_stairs() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.HAY_STAIRS_COST):
		Audio.play("build_denied")
		return
	var at:= _stairs_ghost.global_position
	var yaw:= _stairs_ghost.global_rotation.y
	builds.add_hay_stairs(at, yaw)
	Audio.play_3d("build_place", at)


func _update_lift_ghost() -> void:
	if _state == State.RUNNING:
		_aim_lift_top()
		return


	var raw:= _raw_surface_hit()
	if not raw.is_empty() and (raw ["normal"] as Vector3).y < 0.7:
		var above:= builds.owner_of(raw.get("collider") as Node) as Platform
		if above != null:
			_aim_lift_at_deck(above, raw ["position"])
			return
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = _lift_eval(false, "aim at ground", 0)
		_lift_ghost.global_position = (player.eye_position()
			+ player.look_direction() * _reach)
		_lift_ghost.set_preview_valid(false)
		_port_belts = []
		_draw_port_belts()
		return


	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * Cfg.HAY_LIFT_DECK
	var forward:= _aim_forward()
	var snapped:= false


	var joint:= builds.nearest_belt_end(deck, Cfg.HAY_LIFT_SNAP_RADIUS)
	if not joint.is_empty() and not bool(joint ["start"]):
		var port: Vector3 = joint ["point"]
		forward = joint ["forward"]


		deck = port - _lift_mouth_back(forward)
		snapped = true

	_lift_ghost.global_position = deck
	_lift_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)


	_lift_ghost.set_sections(0)
	_lift_ghost.set_riser(HayLift.SPACER)
	_eval = _evaluate_lift(deck, forward, hit ["normal"], 0, snapped)


	_port_belts = _judge_port_mouths([[_lift_ghost.port_in(), forward, true]])
	_ports_unjoined([[_lift_ghost.port_in(), forward, true]])
	_lift_ghost.set_preview_valid(_eval ["ok"])
	_draw_port_belts()


func _aim_lift_at_deck(deck: Platform, at: Vector3) -> void:
	var edge: Dictionary = deck.nearest_edge(at)
	var outward: Vector3 = edge ["outward"]
	var point: Vector3 = edge ["point"]
	var rect:= deck.footprint()
	var half:= HayLift.CASING * 0.5
	if absf(outward.x) > 0.5:
		var along:= snappedf(point.z, Cfg.BUILD_GRID_STEP) if _grid_on else point.z
		point.z = clampf(along, rect.position.y + half, rect.end.y - half)
	else:
		var along:= snappedf(point.x, Cfg.BUILD_GRID_STEP) if _grid_on else point.x
		point.x = clampf(along, rect.position.x + half, rect.end.x - half)
	var axis:= point + outward * (HayLift.HEAD_REACH + LIFT_EDGE_CLEAR)
	var forward:= - outward
	_lift_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)


	var from:= Vector3(axis.x, deck.top_y() - Cfg.PLATFORM_THICK - 0.05, axis.z)
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_PROBE_DROP)
	q.collision_mask = Cfg.BUILD_SURFACE_MASK
	q.collide_with_areas = false
	var ground:= get_world_3d().direct_space_state.intersect_ray(q)
	if ground.is_empty():
		_lift_ghost.global_position = axis
		_lift_ghost.set_sections(0)
		_lift_ghost.set_riser(HayLift.SPACER)
		_eval = _lift_eval(false, tr("no ground under it"), 0)
		_lift_ghost.set_preview_valid(false)
		return
	var base: Vector3 = (ground ["position"] as Vector3) + (ground ["normal"] as Vector3) * Cfg.HAY_LIFT_DECK
	var climb:= deck.top_y() + Cfg.HAY_LIFT_DECK - base.y

	var r:= HayLift.riser_for_climb(climb)
	var n:= HayLift.sections_reaching(climb, r)
	_lift_ghost.global_position = base
	_lift_ghost.set_riser(r)
	_lift_ghost.set_sections(mini(n, Cfg.HAY_LIFT_SECTIONS_MAX))
	if n > Cfg.HAY_LIFT_SECTIONS_MAX:
		_eval = _lift_eval(false, tr("too high for one lift"), Cfg.HAY_LIFT_SECTIONS_MAX)
	else:
		_eval = _evaluate_lift(base, forward, ground ["normal"], n, false)
		_eval ["deck_gap"] = base.y + HayLift.rise_for(n, r) - (deck.top_y() + Cfg.HAY_LIFT_DECK)
	_eval ["deck_snap"] = true

	_port_belts = _judge_port_mouths([[_lift_ghost.port_in(), forward, true]])
	_ports_unjoined([[_lift_ghost.port_in(), forward, true]])
	_lift_ghost.set_preview_valid(_eval ["ok"])
	_draw_port_belts()


func _aim_lift_top() -> void:


	var top:= _surface_point(Cfg.HAY_LIFT_DECK)


	var deck:= builds.owner_of(_surface_hit().get("collider") as Node) as Platform
	var r:= HayLift.SPACER
	var n:= HayLift.sections_for(top.y - _anchor.y, r)
	if deck != null:
		top.y = deck.top_y() + Cfg.HAY_LIFT_DECK
		r = HayLift.riser_for_climb(top.y - _anchor.y)


		n = mini(HayLift.sections_reaching(top.y - _anchor.y, r),
			Cfg.HAY_LIFT_SECTIONS_MAX)
	_lift_ghost.set_riser(r)
	_lift_ghost.set_sections(n)
	_eval = _evaluate_lift(_anchor, _lift_ghost.global_basis.z, Vector3.UP, n, true)

	if not _port_belts.is_empty():
		_eval ["cost"] = float(_eval ["cost"]) + _port_belts_cost()
		if _eval ["ok"] and not GameState.can_afford(float(_eval ["cost"])):
			_eval ["ok"] = false
			_eval ["reason"] = tr("need %s") % _price(float(_eval ["cost"]))
	_lift_ghost.set_preview_valid(_eval ["ok"])
	_draw_port_belts()


	_eval ["deck_gap"] = NAN
	if deck != null:
		_eval ["deck_gap"] = (_anchor.y + HayLift.rise_for(n, r)) - (deck.top_y() + Cfg.HAY_LIFT_DECK)


func _lift_primary() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if _state == State.AIMING and _eval.get("deck_snap", false):


		if not _pay(_eval ["cost"]):
			Audio.play("build_denied")
			return
		_lay_port_belts(builds.add_hay_lift(_lift_ghost.global_position,
			_lift_ghost.global_rotation.y, _lift_ghost.sections, _lift_ghost.riser))
		Audio.play_3d("build_place_big", _lift_ghost.global_position, -3.0)
		return
	if _state == State.AIMING:


		_anchor = _lift_ghost.global_position
		_state = State.RUNNING
		Audio.play("build_ghost")
		return
	if not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return
	var yaw:= _lift_ghost.global_rotation.y
	_lay_port_belts(builds.add_hay_lift(_anchor, yaw, _lift_ghost.sections,
		_lift_ghost.riser))
	Audio.play_3d("build_place_big", _anchor, -3.0)
	_state = State.AIMING


func _lift_mouth_back(forward: Vector3) -> Vector3:
	return forward * (absf(HayLift.MOUTH_Z) + 0.22)


func _lift_eval(ok: bool, reason: String, n: int) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"length": HayLift.rise_for(n, _ghost_riser()),
		"sections": n,
		"cost": HayLift.cost_for(n),
	}


func _ghost_riser() -> float:
	return _lift_ghost.riser if _lift_ghost != null else HayLift.SPACER


func _evaluate_lift(at: Vector3, forward: Vector3, normal: Vector3, n: int,
		snapped: bool) -> Dictionary:
	var cost:= HayLift.cost_for(n)


	if not snapped and normal.dot(Vector3.UP) < 0.86:
		return _lift_eval(false, tr("needs level ground"), n)
	if builds.lift_overlap(at, null, forward):
		return _lift_eval(false, tr("too close to another one"), n)
	if not GameState.can_afford(cost):
		return _lift_eval(false, tr("need %s") % _price(cost), n)
	if _lift_blocked(at, forward, n):
		return _lift_eval(false, tr("no room"), n)
	return _lift_eval(true, "", n)


func _lift_blocked(at: Vector3, forward: Vector3, n: int) -> bool:
	var basis:= Basis(Vector3.UP, atan2(forward.x, forward.z))

	var r:= _ghost_riser()
	var tall:= HayLift.BOOT_FLANGE + Cfg.HAY_LIFT_SECTION * float(n) + r + HayLift.MODEL_DECK
	_lift_probe.size = Vector3(1.1 * Cfg.BUILD_CLEARANCE_SHRINK, tall,
		1.1 * Cfg.BUILD_CLEARANCE_SHRINK)
	_lift_probe_query.transform = Transform3D(basis,
		at + Vector3.UP * (tall * 0.5 - HayLift.MODEL_DECK))
	if _probe_hits(_lift_probe_query):
		return true


	var belt:= HayLift.rise_for(n, r)
	var flange:= HayLift.BOOT_FLANGE + Cfg.HAY_LIFT_SECTION * float(n) + r
	var head_high:= flange + HayLift.HEAD_TOP
	for part: Vector3 in [
			Vector3(flange, - HayLift.CASING * 0.5, HayLift.HEAD_BEND_CLEAR),
			Vector3(belt - HayLift.HEAD_UNDER, HayLift.HEAD_BEND_CLEAR, HayLift.HEAD_REACH)]:
		var low:= part.x
		var long:= part.z - part.y
		_lift_probe.size = Vector3(HayLift.CASING * Cfg.BUILD_CLEARANCE_SHRINK,
			head_high - low, long * Cfg.BUILD_CLEARANCE_SHRINK)
		_lift_probe_query.transform = Transform3D(basis, at
			+ Vector3.UP * (low + head_high) * 0.5
			+ basis.z * (part.y + long * 0.5))
		if _probe_hits(_lift_probe_query):
			return true


	var near:= -0.55
	var far:= minf(HayLift.MOUTH_Z,
		_lift_ghost.to_local(_lift_ghost.port_in()).z + LIFT_PORT_GAP)
	var run:= near - far
	_lift_probe.size = Vector3(1.1 * Cfg.BUILD_CLEARANCE_SHRINK,
		HayLift.MODEL_DECK, run)
	var mid:= at + basis.z * (far + run * 0.5) - Vector3.UP * HayLift.MODEL_DECK * 0.5
	_lift_probe_query.transform = Transform3D(basis, mid)
	var mask:= _lift_probe_query.collision_mask
	_lift_probe_query.collision_mask = mask & ~ Cfg.L_PLAYER
	var hit:= _probe_hits(_lift_probe_query)
	_lift_probe_query.collision_mask = mask
	return hit


func _update_scanner_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": Cfg.SCANNER_LENGTH,
			"cost": _scanner_cost() }
		var far:= player.eye_position() + player.look_direction() * _reach
		_scanner_ghost.global_position = far
		_scanner_ghost.set_preview_valid(false)
		_ghost.visible = false
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false


	var spec:= _seat_spec(Mode.SCANNER)
	var seat:= _seat_on_line(hit ["position"], Cfg.SCANNER_SNAP_RADIUS, spec)
	if not seat.is_empty():
		forward = seat ["forward"]
		centre = seat ["origin"]
		snapped = true

	_scanner_ghost.global_position = centre


	_scanner_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	centre = _seat_exact(_scanner_ghost, seat, centre)
	_eval = _evaluate_scanner(centre, forward, hit ["normal"], snapped)
	_seat_judge(seat, centre, spec)
	_scanner_ghost.set_preview_valid(_eval ["ok"])
	_show_scanner_flow(centre, forward)
	_seat_draw(true)


func _show_scanner_flow(centre: Vector3, forward: Vector3) -> void:
	var reach:= Cfg.SCANNER_LENGTH * 0.5 + SCANNER_FLOW_REACH
	var from:= centre - forward * reach
	var to:= centre + forward * reach
	_ghost.multimesh.visible_instance_count = 0


	_ghost.global_transform = Transform3D()
	_ghost.material_override = ConveyorKit.ghost_material(_eval ["ok"])
	_ghost.visible = true
	_shape_flow(PackedVector3Array([from, to]))


func _show_wye_flow(chains: Array) -> void:
	_ghost.multimesh.visible_instance_count = 0

	_ghost.global_transform = Transform3D()
	_ghost.material_override = ConveyorKit.ghost_material(_eval ["ok"])
	_ghost.visible = true
	_shape_flow_many(chains, WYE_ARROW_PITCH)


func _evaluate_scanner(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.SCANNER_LENGTH,
		"cost": _scanner_cost() }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(_scanner_cost()):
		result ["reason"] = tr("need %s") % _price(_scanner_cost())
		return result
	if builds.scanner_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	_scanner_probe.size = Vector3(1.5, 1.8, Cfg.SCANNER_LENGTH - 0.36)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_scanner_probe_query.transform = Transform3D(basis, centre + basis.y * 0.55)
	if _probe_hits(_scanner_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_scanner() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(_scanner_cost() + _seat_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _scanner_ghost.global_position
	var yaw:= _scanner_ghost.global_rotation.y


	_lay_seat_stub(builds.add_scanner(at, yaw, _scanner_tier))
	Audio.play_3d("build_place_big", at, -3.0)


func _update_pelletizer_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": 0.0,
			"cost": Cfg.PELLETIZER_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_pelletizer_ghost.global_position = far
		_pelletizer_ghost.set_preview_valid(false)
		_seat_clear()
		return

	var ground: Vector3 = hit ["position"]


	var forward:= HayPelletizer.default_forward(_aim_forward())
	var centre:= ground
	var snapped:= false


	var spec:= _seat_spec(Mode.PELLETIZER)
	var seat:= _seat_on_line(ground, Cfg.PELLETIZER_SNAP_RADIUS, spec)
	if not seat.is_empty():
		forward = seat ["forward"]
		centre = seat ["origin"]
		snapped = true

	_pelletizer_ghost.global_position = centre
	_pelletizer_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	centre = _seat_exact(_pelletizer_ghost, seat, centre)
	_eval = _evaluate_pelletizer(centre, forward, hit ["normal"], snapped)
	_seat_judge(seat, centre, spec)
	_pelletizer_ghost.set_preview_valid(_eval ["ok"])
	_seat_draw()


func _evaluate_pelletizer(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": 0.0,
		"cost": Cfg.PELLETIZER_COST }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.PELLETIZER_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.PELLETIZER_COST)
		return result
	if builds.pelletizer_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	_pelletizer_probe.size = Vector3(1.5, 2.3, 1.4)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_pelletizer_probe_query.transform = Transform3D(basis, centre + basis.y * 1.2)
	if _probe_hits(_pelletizer_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_pelletizer() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.PELLETIZER_COST + _seat_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _pelletizer_ghost.global_position
	var yaw:= _pelletizer_ghost.global_rotation.y
	_lay_seat_stub(builds.add_pelletizer(at, yaw))
	Audio.play_3d("build_place_big", at, -3.0)


func _update_generator_ghost() -> void:
	var gen_ghost:= _gen_ghost()
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": 0.0,
			"cost": _gen_price() }
		var far:= player.eye_position() + player.look_direction() * _reach
		gen_ghost.global_position = far
		gen_ghost.set_preview_valid(false)
		_generator_ramp = PackedVector3Array()
		_ghost.visible = false
		return

	var ground: Vector3 = hit ["position"]


	var forward:= HayGenerator.broadside_forward(_aim_forward())
	var centre:= ground
	var snapped:= false
	_generator_ramp = PackedVector3Array()


	var joint:= builds.nearest_belt_end(ground + Vector3.UP * GENERATOR_PORT_UP,
		Cfg.GENERATOR_SNAP_RADIUS)
	if joint.is_empty() or bool(joint ["start"]):
		joint = builds.nearest_belt_end(ground, Cfg.GENERATOR_SNAP_RADIUS)

	if _snap_off or (not joint.is_empty() and bool(joint ["start"])):
		joint = { }


	var lane: Dictionary = { }
	if joint.is_empty() and not _snap_off:
		var spec:= _seat_spec(_mode)
		var mouths: Array [Dictionary] = []
		for j in builds.free_line_joints(ground + Vector3.UP * GENERATOR_PORT_UP,
				MachineSeat.MOUTH_BELT_REACH + GENERATOR_PORT_BACK + 0.5):
			if bool(j ["wye"]) and not bool(j ["start"]):
				mouths.append(j)
		lane = MachineSeat.choose(get_world_3d().direct_space_state, mouths, ground, spec)
	if not lane.is_empty():
		forward = lane ["forward"]
		centre = lane ["origin"]
		_generator_ramp = lane ["stub"]
		snapped = true
	if not joint.is_empty():
		var port: Vector3 = joint ["point"]


		forward = joint ["forward"]


		centre = port + forward * GENERATOR_PORT_BACK - Vector3.UP * GENERATOR_PORT_UP
		snapped = true

	gen_ghost.global_position = centre
	gen_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)


	if snapped and not joint.is_empty():
		centre += (joint ["point"] as Vector3) - gen_ghost.intake_port()
		gen_ghost.global_position = centre
	elif _generator_ramp.size() == 2:
		_generator_ramp [1] = gen_ghost.intake_port()
	_eval = _evaluate_generator(centre, forward, hit ["normal"], snapped, _generator_ramp)


	if not snapped and _eval ["ok"] and not builds.unjoined_near(
			gen_ghost.intake_port(), forward, false).is_empty():
		_eval ["ok"] = false
		_eval ["reason"] = tr("belt end not joined")
	if snapped and _eval ["ok"]:
		var why:= _seat_floor_reason(centre, forward, _seat_spec(_mode))
		if why != "":
			_eval ["ok"] = false
			_eval ["reason"] = why
	gen_ghost.set_preview_valid(_eval ["ok"])

	if _generator_ramp.is_empty():
		_ghost.visible = false
	else:
		_ghost.global_transform = Transform3D()
		_ghost.multimesh.visible_instance_count = _lay_ghost(_generator_ramp)
		_ghost.material_override = ConveyorKit.ghost_material(_eval ["ok"])
		_ghost.visible = true
		_shape_flow(_generator_ramp)


func _seat_spec(mode: Mode) -> Dictionary:
	match mode:
		Mode.SCANNER:
			return _module_seat(Cfg.SCANNER_LENGTH)
		Mode.COMPRESSOR:
			return _module_seat(Cfg.COMPRESSOR_LENGTH)
		Mode.PULPER:
			return _module_seat(Cfg.PULPER_LENGTH)
		Mode.PAPER:
			var paper:= _module_seat(Cfg.PAPER_LENGTH)
			paper ["in"] = float(paper ["in"]) + PaperMachine.PORT_REACH
			return paper
		Mode.WRAPPER:
			return _module_seat(Cfg.WRAPPER_LENGTH)
		Mode.PELLETIZER:
			return { "in": PELLETIZER_PORT_BACK, "rise": PELLETIZER_PORT_UP,
				"feet": 0.0, "grounded": true, "half": 0.7 }
		Mode.LAUNCHER:
			return { "in": LAUNCHER_PORT_BACK, "rise": LAUNCHER_PORT_UP,
				"feet": 0.0, "grounded": true, "half": 1.2 }
		Mode.BRIQUETTE:
			return { "in": Cfg.BRIQUETTE_PORT_BRICK
					+ BriquettePress.PORT_REACH [BriquettePress.REACH_BRICK],
				"out": Cfg.BRIQUETTE_PORT_DISC
					+ BriquettePress.PORT_REACH [BriquettePress.REACH_DISC],
				"rise": Cfg.BRIQUETTE_PORT_UP, "feet": 0.0, "grounded": true,
				"half": Cfg.BRIQUETTE_LENGTH * 0.5 }
		Mode.GENERATOR:
			return { "in": GENERATOR_PORT_BACK, "rise": GENERATOR_PORT_UP,
				"feet": 0.0, "grounded": true, "half": 1.8 }


		Mode.GAS_PLANT:
			return { "in": GENERATOR_PORT_BACK, "rise": GENERATOR_PORT_UP,
				"feet": 0.0, "grounded": true, "half": 3.0 }
	return { }


static func _module_seat(length: float) -> Dictionary:
	return { "in": length * 0.5, "out": length * 0.5, "rise": 0.0,
		"feet": Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, "grounded": false,
		"half": length * 0.5 }


func _seat_on_line(feet: Vector3, radius: float, spec: Dictionary) -> Dictionary:

	if _snap_off:
		return { }
	var high:= feet + Vector3.UP * (float(spec ["feet"]) + float(spec ["rise"]))
	var ends: Array [Dictionary] = []
	for joint in builds.free_line_joints(high, radius) + builds.free_line_joints(feet, radius):
		if not bool(joint ["wye"]):
			_add_joint(ends, joint)
	var space:= get_world_3d().direct_space_state
	var seat:= MachineSeat.choose(space, ends, feet, spec)
	if not seat.is_empty():
		return seat


	var body:= maxf(float(spec.get("in", 0.0)), float(spec.get("out", 0.0)))
	var mouths: Array [Dictionary] = []
	for joint in builds.free_line_joints(high, MachineSeat.MOUTH_BELT_REACH + body + 0.5):
		if bool(joint ["wye"]):
			mouths.append(joint)
	return MachineSeat.choose(space, mouths, feet, spec)


func _mouths_unjoined(mouths: Array) -> String:
	for m: Array in mouths:
		var point: Vector3 = m [0]
		var out: Vector3 = m [1]
		if not builds.unjoined_near(point, out, true).is_empty() or not builds.unjoined_near(point, - out, false).is_empty():
			return tr("arm not joined")
	return ""


func _judge_wye_mouths(mouths: Array) -> void:
	if not bool(_eval ["ok"]):
		return
	var rest: Array = []
	var why:= ""
	for m: Array in mouths:
		var point: Vector3 = m [0]
		var out: Vector3 = m [1]
		if builds.feed_run_into(point) != null or builds.run_out_of(point) != null or builds.mouth_at(point):
			continue
		var port:= builds.machine_port_on_lane(point, out, MachineSeat.MOUTH_BELT_REACH)
		if not port.is_empty() and float(port ["along"]) < Cfg.BELT_MIN_LENGTH:
			why = tr("too close to the machine")
			break
		rest.append(m)
	if why == "":
		why = _mouths_unjoined(rest)
	if why != "":
		_eval ["ok"] = false
		_eval ["reason"] = why


func _port_mouth_belt(port: Vector3, forward: Vector3, intake: bool) -> Dictionary:
	if _snap_off:
		return { }
	var f:= Vector3(forward.x, 0.0, forward.z)
	if f.length_squared() < 1e-06:
		return { }
	f = f.normalized()
	var best: Dictionary = { }
	var best_d:= INF
	for joint in builds.free_line_joints(port,
			MachineSeat.MOUTH_BELT_REACH + BuildManager.PORT_NEAR_ACROSS):

		if not bool(joint ["wye"]) or bool(joint ["start"]) == intake:
			continue
		if (joint ["forward"] as Vector3).dot(f) < 0.98:
			continue
		var mouth: Vector3 = joint ["point"]
		var d:= port - mouth
		var gap:= d.dot(f) if intake else - d.dot(f)
		var across:= d - f * d.dot(f)
		if Vector2(across.x, across.z).length() > BuildManager.PORT_NEAR_ACROSS or absf(across.y) > BuildManager.LANE_PORT_RISE or absf(gap) > MachineSeat.MOUTH_BELT_REACH:
			continue
		if absf(gap) < best_d:
			best_d = absf(gap)
			var close:= gap < Cfg.BELT_MIN_LENGTH
			var belt:= PackedVector3Array()
			if not close:
				belt = PackedVector3Array([mouth, port]) if intake else PackedVector3Array([port, mouth])
			best = { "belt": belt, "close": close }
	return best


func _judge_port_mouths(ports: Array) -> Array:
	var out: Array = []
	if not bool(_eval ["ok"]):
		return out
	var why:= ""
	var cost:= 0.0
	for p: Array in ports:
		var found:= _port_mouth_belt(p [0], p [1], p [2])
		if found.is_empty():
			continue
		if bool(found ["close"]):
			why = tr("too close to the machine")
			break
		var belt: PackedVector3Array = found ["belt"]
		var length:= belt [0].distance_to(belt [1])
		why = _leg_shape_reason(belt [0], belt [1], length)
		if why == "":
			why = _leg_clear_reason(belt [0], belt [1], length)
		if why != "":
			break
		out.append({ "belt": belt, "intake": p [2] })
		cost += Conveyor.cost_for(belt [0], belt [1])
	if why == "" and not out.is_empty():
		var total:= float(_eval ["cost"]) + cost
		if not GameState.can_afford(total):
			why = tr("need %s") % _price(total)
		_eval ["cost"] = total
	if why != "":
		_eval ["ok"] = false
		_eval ["reason"] = why
		return []
	return out


func _ports_unjoined(ports: Array) -> void:
	if not bool(_eval ["ok"]):
		return
	for p: Array in ports:
		if not builds.unjoined_near(p [0], p [1], not bool(p [2])).is_empty():
			_eval ["ok"] = false
			_eval ["reason"] = tr("belt end not joined")
			return


func _port_belts_cost() -> float:
	var cost:= 0.0
	for e: Dictionary in _port_belts:
		var belt: PackedVector3Array = e ["belt"]
		cost += Conveyor.cost_for(belt [0], belt [1])
	return cost


func _draw_port_belts() -> void:
	if _port_belts.is_empty():
		_ghost.visible = false
		return
	var n:= 0
	for e: Dictionary in _port_belts:
		n = _lay_ghost(e ["belt"], n)
	_ghost.global_transform = Transform3D()
	_ghost.multimesh.visible_instance_count = n
	_ghost.material_override = ConveyorKit.ghost_material(_eval ["ok"])
	_ghost.visible = true
	_shape_flow((_port_belts [0] as Dictionary) ["belt"])


func _lay_port_belts(machine: Node3D) -> void:
	if machine != null:
		for e: Dictionary in _port_belts:
			var belt: PackedVector3Array = e ["belt"]
			var port:= _seat_port(machine, bool(e ["intake"]))
			if bool(e ["intake"]):
				builds.mark_machine_belt(builds.add_conveyor(belt [0], port), port)
			else:
				builds.mark_machine_belt(builds.add_conveyor(port, belt [1]), port)
	_port_belts = []


static func _add_joint(joints: Array [Dictionary], joint: Dictionary) -> void:
	for other in joints:
		if (other ["point"] as Vector3).is_equal_approx(joint ["point"]):
			return
	joints.append(joint)


static func _seat_port(machine: Node3D, intake: bool) -> Vector3:
	if not intake:
		return machine.call("port_out")
	if machine is BriquettePress:
		return (machine as BriquettePress).port_brick()
	if machine.has_method("intake_port"):
		return machine.call("intake_port")
	return machine.call("port_in")


func _seat_exact(ghost: Node3D, seat: Dictionary, centre: Vector3) -> Vector3:
	if seat.is_empty():
		return centre
	var shift: Vector3 = (seat ["port"] as Vector3) - _seat_port(ghost, seat ["intake"])
	if shift.length() > 0.05:
		return centre
	ghost.global_position = centre + shift
	return ghost.global_position


func _seat_judge(seat: Dictionary, centre: Vector3, spec: Dictionary) -> void:
	_seat_stub = PackedVector3Array() if seat.is_empty() else seat ["stub"]
	_seat_far = PackedVector3Array()
	if seat.is_empty():


		if bool(_eval ["ok"]):
			var fwd:= _aim_forward()
			var high:= centre + Vector3.UP * float(spec ["rise"])
			var loose:= false
			if spec.has("in"):
				loose = not builds.unjoined_near(high - fwd * float(spec ["in"]), fwd, false).is_empty()
			if not loose and spec.has("out"):
				loose = not builds.unjoined_near(high + fwd * float(spec ["out"]), fwd, true).is_empty()
			if loose:
				_eval ["ok"] = false
				_eval ["reason"] = tr("belt end not joined")
		return
	_seat_intake = bool(seat ["intake"])
	if _seat_stub.size() == 2:
		_eval ["cost"] = float(_eval ["cost"]) + Conveyor.cost_for(_seat_stub [0], _seat_stub [1])


	var why:= _seat_floor_reason(centre, seat ["forward"], spec)
	if why != "":
		_eval ["ok"] = false
		_eval ["reason"] = why
		return
	if not _eval ["ok"]:
		return
	if _seat_stub.size() == 2:
		var mouth: Vector3 = seat ["joint"] ["point"]
		var length:= _seat_stub [0].distance_to(_seat_stub [1])
		why = _joint_taken(mouth, bool(seat ["intake"]))
		if why == "":
			why = _leg_shape_reason(_seat_stub [0], _seat_stub [1], length)
		if why == "":
			why = _leg_clear_reason(_seat_stub [0], _seat_stub [1], length)
	if why == "":
		why = _seat_far_reason(centre, seat ["forward"], not _seat_intake, spec)
	if why == "" and not GameState.can_afford(float(_eval ["cost"])):
		why = tr("need %s") % _price(float(_eval ["cost"]))
	if why != "":
		_seat_far = PackedVector3Array()
		_eval ["ok"] = false
		_eval ["reason"] = why


func _seat_far_reason(centre: Vector3, forward: Vector3, intake: bool,
		spec: Dictionary) -> String:
	if not spec.has("in" if intake else "out"):
		return ""
	var high:= centre + Vector3.UP * float(spec ["rise"])
	var port:= high - forward * float(spec ["in"]) if intake else high + forward * float(spec ["out"])
	var found:= _port_mouth_belt(port, forward, intake)
	if found.is_empty():
		return ""
	if bool(found ["close"]):
		return tr("too close to the machine")
	var belt: PackedVector3Array = found ["belt"]
	var length:= belt [0].distance_to(belt [1])
	var why:= _leg_shape_reason(belt [0], belt [1], length)
	if why == "":
		why = _leg_clear_reason(belt [0], belt [1], length)
	if why != "":
		return why
	_seat_far = belt
	_seat_far_intake = intake
	_eval ["cost"] = float(_eval ["cost"]) + Conveyor.cost_for(belt [0], belt [1])
	return ""


func _seat_floor_reason(centre: Vector3, forward: Vector3, spec: Dictionary) -> String:
	match MachineSeat.floor_fault(get_world_3d().direct_space_state, centre, forward, spec):
		"low":
			return tr("belt end too low")
		"high":
			return tr("belt end too high")
	return ""


func _seat_draw(keeps_flow:= false) -> void:
	if _seat_stub.size() != 2 and _seat_far.size() != 2:
		if not keeps_flow:
			_ghost.visible = false
		return
	_ghost.global_transform = Transform3D()
	var n:= 0
	if _seat_stub.size() == 2:
		n = _lay_ghost(_seat_stub)
	if _seat_far.size() == 2:
		n = _lay_ghost(_seat_far, n)
	_ghost.multimesh.visible_instance_count = n
	_ghost.material_override = ConveyorKit.ghost_material(_eval ["ok"])
	_ghost.visible = true
	if not keeps_flow:
		_shape_flow(_seat_stub if _seat_stub.size() == 2 else _seat_far)


func _seat_clear() -> void:
	_seat_stub = PackedVector3Array()
	_seat_far = PackedVector3Array()
	_seat_draw()


func _seat_stub_cost() -> float:
	var cost:= 0.0
	if _seat_stub.size() == 2:
		cost += Conveyor.cost_for(_seat_stub [0], _seat_stub [1])
	if _seat_far.size() == 2:
		cost += Conveyor.cost_for(_seat_far [0], _seat_far [1])
	return cost


func _lay_seat_stub(machine: Node3D) -> void:
	if machine == null:
		return
	if _seat_stub.size() == 2:
		var port:= _seat_port(machine, _seat_intake)

		if _seat_intake:
			builds.mark_machine_belt(builds.add_conveyor(_seat_stub [0], port), port)
		else:
			builds.mark_machine_belt(builds.add_conveyor(port, _seat_stub [1]), port)
	if _seat_far.size() == 2:
		var far:= _seat_port(machine, _seat_far_intake)
		if _seat_far_intake:
			builds.mark_machine_belt(builds.add_conveyor(_seat_far [0], far), far)
		else:
			builds.mark_machine_belt(builds.add_conveyor(far, _seat_far [1]), far)
	_seat_stub = PackedVector3Array()
	_seat_far = PackedVector3Array()


func _gen_ghost() -> HayGenerator:
	return _plant_ghost if _mode == Mode.GAS_PLANT else _generator_ghost


func _gen_price() -> float:
	return builds.gas_plant_price() if _mode == Mode.GAS_PLANT else builds.generator_price()


func _evaluate_generator(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool, ramp:= PackedVector3Array()) -> Dictionary:


	var price:= _gen_price()
	if ramp.size() == 2:
		price += Conveyor.cost_for(ramp [0], ramp [1])
	var result:= { "ok": false, "reason": "", "length": 0.0, "cost": price }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(price):
		result ["reason"] = tr("need %s") % _price(price)
		return result
	var plant:= _mode == Mode.GAS_PLANT
	if builds.generator_overlap(centre, forward, null, plant):
		result ["reason"] = tr("too close to another machine")
		return result


	var basis:= BeltPath.run_basis(centre, centre + forward)
	if plant:


		_generator_probe.size = Vector3(2.85, 4.3, 5.8)
		_generator_probe_query.transform = Transform3D(basis,
			centre + basis.y * 2.25)
	else:
		_generator_probe.size = Vector3(1.5, 2.1, 3.6)
		_generator_probe_query.transform = Transform3D(basis,
			centre + basis.y * 1.1 + basis.z * 0.415)
	if _probe_hits(_generator_probe_query):
		result ["reason"] = tr("blocked")
		return result

	if ramp.size() == 2:
		var length:= ramp [0].distance_to(ramp [1])
		var why:= _joint_taken(ramp [0], true)
		if why == "":
			why = _leg_shape_reason(ramp [0], ramp [1], length)
		if why == "":
			why = _leg_clear_reason(ramp [0], ramp [1], length)
		if why != "":
			result ["reason"] = why
			return result
	result ["ok"] = true
	return result


func _place_generator() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return

	var price:= _gen_price()


	var ramp:= _generator_ramp
	var bill:= price
	if ramp.size() == 2:
		bill += Conveyor.cost_for(ramp [0], ramp [1])
	if not _pay(bill):
		Audio.play("build_denied")
		return
	var at:= _gen_ghost().global_position
	var yaw:= _gen_ghost().global_rotation.y
	var gen: HayGenerator
	if _mode == Mode.GAS_PLANT:
		gen = builds.add_gas_plant(at, yaw, price)
	else:
		gen = builds.add_generator(at, yaw, price)


	if ramp.size() == 2:
		builds.mark_machine_belt(builds.add_conveyor(ramp [0], gen.intake_port()),
			gen.intake_port())
	Audio.play_3d("build_place_big", at, -3.0)


func _update_borehole_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": 0.0,
			"cost": Cfg.BOREHOLE_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_borehole_ghost.global_position = far
		_borehole_ghost.set_preview_valid(false)
		return

	var ground: Vector3 = hit ["position"]
	var forward:= HayGenerator.broadside_forward(_aim_forward())
	_borehole_ghost.global_position = ground
	_borehole_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_borehole(ground, forward, hit ["normal"])
	_borehole_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_borehole(centre: Vector3, forward: Vector3,
		normal: Vector3) -> Dictionary:


	var price:= Cfg.BOREHOLE_COST
	var result:= { "ok": false, "reason": "", "length": 0.0, "cost": price }


	if normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(price):
		result ["reason"] = tr("need %s") % _price(price)
		return result
	if builds.borehole_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	var tall:= 2.0 - Cfg.BUILD_FOOT_CLEAR
	_borehole_probe.size = Vector3(1.5, tall, 4.1)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_borehole_probe_query.transform = Transform3D(basis,
		centre + basis.y * (Cfg.BUILD_FOOT_CLEAR + tall * 0.5)
		+ basis.z * -0.18 + basis.x * 0.16)
	if _probe_hits(_borehole_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_borehole() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.BOREHOLE_COST):
		Audio.play("build_denied")
		return
	var at:= _borehole_ghost.global_position
	var yaw:= _borehole_ghost.global_rotation.y
	builds.add_borehole(at, yaw)
	Audio.play_3d("build_place_big", at, -3.0)


func _pipe_aim_point() -> Vector3:
	var raw:= _surface_point(Cfg.PIPE_RUN_HEIGHT)
	var snapped:= builds.snap_water_endpoint(raw)
	_joined = not snapped.is_equal_approx(raw)
	return snapped


func _update_pipe_ghost() -> void:
	if _pipe_ghost == null:
		return
	var point:= _pipe_aim_point()
	var from: Vector3
	var to: Vector3
	if _state == State.RUNNING:
		from = _anchor
		to = point
	else:


		var dir:= player.look_direction()
		dir.y = 0.0
		dir = dir.normalized() if dir.length_squared() > 1e-06 else Vector3.BACK


		var bearing:= builds.water_port_bearing_at(point)
		if bearing != Vector3.ZERO:
			dir = bearing
		from = point
		to = point + dir * STUB_LENGTH
	_eval = _evaluate_pipe(from, to, _state == State.RUNNING)
	if _finished_here(from):
		_eval = _finished_eval(tr("pipe connected"))
		_pipe_ghost.multimesh.visible_instance_count = 0
		_pipe_bend_ghost.multimesh.visible_instance_count = 0
		return
	var points:= _pipe_preview_points(from, _pipe_drawn_end(from, to))
	_pipe_ghost.global_transform = Transform3D()
	_pipe_bend_ghost.global_transform = Transform3D()
	_lay_pipe_ghost(points)
	_pipe_ghost.material_override = ConveyorKit.ghost_material(_eval ["ok"])
	_pipe_bend_ghost.material_override = _pipe_ghost.material_override


func _pipe_drawn_end(from: Vector3, to: Vector3) -> Vector3:
	if _state != State.RUNNING or from.distance_to(to) >= Cfg.BELT_MIN_LENGTH:
		return to
	var dir:= to - from
	if dir.length_squared() < 0.0001:


		dir = _surface_point(Cfg.PIPE_RUN_HEIGHT) - from
	if dir.length_squared() < 0.0001:
		dir = player.look_direction()
	return from + dir.normalized() * Cfg.BELT_MIN_LENGTH


func _pipe_preview_points(from: Vector3, to: Vector3) -> PackedVector3Array:
	var straight:= PackedVector3Array([from, to])
	var mask:= PackedByteArray()
	_pipe_preview_bend = mask
	if builds == null or _state != State.RUNNING or from.distance_to(to) < 0.0001:
		return straight


	var legs:= PackedVector3Array()
	for p in _pipe_knees(from, to):
		if legs.is_empty() or not legs [legs.size() - 1].is_equal_approx(p):
			legs.append(p)


	var in_forward:= Vector3.ZERO
	var in_length:= 0.0
	var incoming: WaterMain = builds.water_run_into(from)
	if incoming != null:
		in_forward = incoming.forward
		in_length = incoming.length
	var out:= PackedVector3Array([legs [0]])
	for i in legs.size() - 1:
		var leg:= legs [i + 1] - legs [i]
		var length:= leg.length()
		var forward:= leg / length
		if in_forward != Vector3.ZERO:
			var t:= BuildManager.corner_tangent(in_forward, in_length, forward, length)
			if t > 0.0:


				out.remove_at(out.size() - 1)
				if not mask.is_empty():
					mask.remove_at(mask.size() - 1)
				var curve:= _bend(legs [i] - in_forward * t, legs [i],
					legs [i] + forward * t, in_forward.angle_to(forward))
				for j in curve.size():


					if not out.is_empty():
						mask.append(1 if j > 0 else 0)
					out.append(curve [j])
		out.append(legs [i + 1])
		mask.append(0)
		in_forward = forward
		in_length = length
	_pipe_preview_bend = mask
	return out


func _lay_pipe_ghost(points: PackedVector3Array) -> void:
	var mm:= _pipe_ghost.multimesh
	var bend_mm:= _pipe_bend_ghost.multimesh
	var mask:= _pipe_preview_bend
	var n:= 0
	var nb:= 0
	for i in points.size() - 1:
		var from:= points [i]
		var to:= points [i + 1]
		var span:= from.distance_to(to)
		if span < 0.0001:
			continue
		var bent:= i < mask.size() and mask [i] != 0
		var pieces:= clampi(maxi(1, int(round(span / Cfg.BELT_SEGMENT))),
			1, GHOST_CAPACITY)
		var seg:= span / pieces
		var basis:= BeltPath.run_basis(from, to)
		var scale:= Vector3(1.0, 1.0, seg / Cfg.BELT_SEGMENT)
		for k in pieces:
			var xf:= Transform3D(basis.scaled_local(scale),
				from.lerp(to, (seg * (k + 0.5)) / span))
			if bent:
				if nb >= GHOST_CAPACITY:
					continue
				bend_mm.set_instance_transform(nb, xf)
				nb += 1
			else:
				if n >= GHOST_CAPACITY:
					continue
				mm.set_instance_transform(n, xf)
				n += 1
	mm.visible_instance_count = n
	bend_mm.visible_instance_count = nb


func _evaluate_pipe(from: Vector3, to: Vector3, priced: bool) -> Dictionary:
	var length:= from.distance_to(to)


	var cost:= WaterMain.cost_for(from, to)
	if priced and builds != null:
		cost = 0.0
		var legs:= _pipe_knees(from, to)
		for i in legs.size() - 1:
			cost += WaterMain.cost_for(legs [i], legs [i + 1])
	var r:= { "ok": false, "reason": "", "length": length, "cost": cost }


	if builds != null and builds.water_port_taken(from):
		r ["reason"] = tr("that flange already has a pipe on it")
		return r
	if priced and builds != null and builds.water_port_taken(to):
		r ["reason"] = tr("that flange already has a pipe on it")
		return r


	if priced and builds != null:
		var fitting: Node3D = builds.flange_owner(from)
		if fitting != null and fitting == builds.flange_owner(to):
			r ["reason"] = tr("both ends on the same piece")
			return r
	if not priced:
		if not GameState.can_afford(WaterMain.cost_for(Vector3.ZERO,
				Vector3(Cfg.BELT_MIN_LENGTH, 0.0, 0.0))):
			r ["reason"] = tr("no funds")
			return r


		r ["ok"] = true
		return r
	if length < Cfg.BELT_MIN_LENGTH:
		r ["reason"] = tr("too short")
		return r
	if length > Cfg.BELT_MAX_LENGTH:
		r ["reason"] = tr("too long")
		return r


	var legs:= _pipe_knees(from, to) if builds != null else PackedVector3Array([from, to])
	for i in legs.size() - 1:
		var leg:= legs [i + 1] - legs [i]
		var span:= leg.length()
		if span > 0.0001 and asin(clampf(absf(leg.y) / span, 0.0, 1.0)) > Cfg.BELT_MAX_SLOPE:
			r ["reason"] = tr("too steep")
			return r
	if _pipe_doubles_back(legs):
		r ["reason"] = tr("turn further off the pipe")
		return r
	if not GameState.can_afford(cost):
		r ["reason"] = tr("need %s") % _price(cost)
		return r
	if _pipe_blocked(from, to, length):
		r ["reason"] = tr("blocked")
		return r


	if _in_pile(from, to, length):
		r ["reason"] = tr("in the hay")
		return r
	r ["ok"] = true
	return r


func _pipe_doubles_back(pts: PackedVector3Array) -> bool:
	if builds == null or pts.size() < 2:
		return false
	var legs: Array [Vector2] = []
	for i in pts.size() - 1:
		var leg:= Vector2(pts [i + 1].x - pts [i].x, pts [i + 1].z - pts [i].z)
		if leg.length_squared() > 1e-08:
			legs.append(leg.normalized())
	if legs.is_empty():
		return false
	for i in legs.size() - 1:
		if legs [i].dot(legs [i + 1]) < MAX_TURN_COS:
			return true


	for end: Array in [[pts [0], legs [0]], [pts [pts.size() - 1], - legs [legs.size() - 1]]]:
		var at: Vector3 = end [0]
		var leaving: Vector2 = end [1]
		for run: WaterMain in builds.water_mains:
			if not is_instance_valid(run):
				continue
			var away:= Vector3.ZERO
			if run.a.distance_to(at) <= Cfg.PIPE_JOIN_TOLERANCE:
				away = run.forward
			elif run.b.distance_to(at) <= Cfg.PIPE_JOIN_TOLERANCE:
				away = - run.forward
			else:
				continue
			var plan:= Vector2(away.x, away.z)
			if plan.length_squared() > 1e-08 and plan.normalized().dot(leaving) > - MAX_TURN_COS:
				return true
	return false


func _pipe_blocked(from: Vector3, to: Vector3, length: float) -> bool:
	var dir:= (to - from) / maxf(length, 1e-06)
	var slack:= minf(Cfg.BUILD_END_SLACK, length * 0.4)
	var span:= length - slack * 2.0
	if span < 0.15:
		return false
	var across:= PipeKit.PIPE_R * 2.0 * Cfg.BUILD_CLEARANCE_SHRINK
	_probe.size = Vector3(across, across, span)
	var basis:= BeltPath.run_basis(from, to)
	_probe_query.transform = Transform3D(basis, from + dir * (slack + span * 0.5))
	return _probe_hits(_probe_query)


func _place_water_pipe() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if _state == State.AIMING:
		_anchor = _pipe_aim_point()
		_state = State.RUNNING
		Audio.play("build_ghost")
		return
	var end:= _pipe_aim_point()


	_eval = _evaluate_pipe(_anchor, end, true)
	if not _eval ["ok"] or not _pay(_eval ["cost"]):
		Audio.play("build_denied")
		return
	Audio.play_3d("build_place", end)
	_lay_pipe(_anchor, end)


	_chain_on(end, _joined)


func _lay_pipe(from: Vector3, to: Vector3) -> void:
	var points:= _pipe_knees(from, to)
	for i in points.size() - 1:
		if not points [i].is_equal_approx(points [i + 1]):
			builds.add_water_main(points [i], points [i + 1])


func _pipe_knees(from: Vector3, to: Vector3) -> PackedVector3Array:
	var stub:= Cfg.PIPE_PORT_STUB
	var far:= to
	var head:= builds.water_port_bearing_at(to)
	if _needs_pipe_knee(- head, to - from):
		far = to + head * stub
	var near:= from
	var tail:= builds.water_port_bearing_at(from)
	if _needs_pipe_knee(tail, far - from):
		near = from + tail * stub
	return PackedVector3Array([from, near, far, to])


static func _needs_pipe_knee(bearing: Vector3, run: Vector3) -> bool:
	var length:= run.length()
	return bearing != Vector3.ZERO and length > Cfg.PIPE_PORT_STUB + Cfg.BELT_MIN_LENGTH and bearing.angle_to(run / length) > Cfg.BELT_CORNER_MIN_TURN


func _update_water_splitter_ghost() -> void:
	if _wye_ghost == null:
		return
	var price:= WaterSplitter.cost_for()
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": 0.0,
			"cost": price }
		var far:= player.eye_position() + player.look_direction() * _reach
		_wye_ghost.global_position = far
		_wye_ghost.set_preview_valid(false)
		return

	var forward:= _aim_forward()
	var centre: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * Cfg.PIPE_RUN_HEIGHT
	var snapped:= false


	var joint:= builds.nearest_water_run_end(centre)


	var flange:= builds.nearest_free_wye_flange(centre)
	var mated: WaterSplitter = null
	if not flange.is_empty() and (joint.is_empty()
			or centre.distance_to(flange ["point"]) < centre.distance_to(joint ["point"])):
		joint = flange
		mated = flange ["wye"]
	if not joint.is_empty():
		forward = joint ["away"]
		centre = (joint ["point"] as Vector3) + forward * Cfg.PIPE_SPLITTER_PORT_R
		snapped = true

	_wye_ghost.global_position = centre


	_wye_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_water_splitter(centre, forward, hit ["normal"], price,
		snapped, mated)
	_wye_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_water_splitter(centre: Vector3, forward: Vector3,
		normal: Vector3, price: float, snapped: bool,
		mated: WaterSplitter = null) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": 0.0, "cost": price }


	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(price):
		result ["reason"] = tr("need %s") % _price(price)
		return result
	if builds.water_splitter_overlap(centre, null, mated):
		result ["reason"] = tr("too close to another fitting")
		return result


	_wye_probe.size = Vector3(0.86, 0.42, 0.86)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_wye_probe_query.transform = Transform3D(basis, centre)


	_wye_probe_query.exclude = mated.body_rids() if mated != null else []
	var hit:= _probe_hits(_wye_probe_query)
	_wye_probe_query.exclude = []
	if hit:
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_water_splitter() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return


	var price:= float(_eval ["cost"])
	if not _pay(price):
		Audio.play("build_denied")
		return
	var at:= _wye_ghost.global_position
	var yaw:= _wye_ghost.global_rotation.y
	builds.add_water_splitter(at, yaw, price)
	Audio.play_3d("build_place", at)


func _pole_status() -> Dictionary:
	var links: Array = _pole_eval.get("links", [])
	var reaches: Array = _pole_eval.get("reaches", [])
	var blocked: Array = _pole_eval.get("blocked", [])
	var yard:= 0
	if builds != null:
		yard = builds.power_poles.size()
	var ghost:= _post_ghost()
	var box:= ghost != null and ghost.buried()

	var tone:= "good"
	var line:= ""
	if links.is_empty() and yard == 0:
		tone = "neutral"
		line = tr("FIRST BOX  ·  nothing to link to yet") if box else tr("FIRST POLE  ·  nothing to link to yet")
	elif links.is_empty():
		tone = "bad"
		line = tr("NO POLE OR BOX IN REACH  ·  it will not connect to anything")
	else:

		var posts: String = tr_n("LINKS %d POST", "LINKS %d POSTS",
			links.size()) % links.size()
		var machines: String = tr_n("REACHES %d MACHINE", "REACHES %d MACHINES",
			reaches.size()) % reaches.size()
		line = "%s  ·  %s" % [posts, machines]


	if not blocked.is_empty():
		tone = "warn"
		line = tr_n("%d MACHINE OUT OF CABLE REACH  ·  it needs a pole it can see",
			"%d MACHINES OUT OF CABLE REACH  ·  they need a pole they can see",
			blocked.size()) % blocked.size()
	return {
		"kind": "pole",
		"placing": false,
		"ok": _eval.get("ok", false),
		"reason": _eval.get("reason", ""),
		"length": 0.0,
		"cost": _eval.get("cost", ghost.build_cost() if ghost != null else Cfg.POLE_COST),
		"gift": _eval.get("gift", false),
		"reach": _reach,
		"tone": tone,
		"note": line,
		"links": links.size(),
		"reaches": reaches.size(),
		"blocked": blocked.size(),
	}


func pole_survey() -> Dictionary:
	return _pole_eval


func _update_pole_ghost() -> void:
	var ghost:= _post_ghost()
	var hit:= _surface_hit()
	if hit.is_empty():
		_pole_eval = _empty_pole_eval()
		var gift:= _pole_gift()
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": 0.0,
			"cost": 0.0 if gift else ghost.build_cost(), "gift": gift }
		var far:= player.eye_position() + player.look_direction() * _reach
		ghost.global_position = far
		ghost.set_preview_valid(false)
		_pole_wire_mesh.mesh = null
		_pole_wire_mesh.visible = false
		_pole_trace_mesh.mesh = null
		_pole_trace_mesh.visible = false
		_pole_drawn = []
		_pole_ring.visible = false
		_clear_pole_tint()
		return


	var at: Vector3 = hit ["position"]
	var forward:= _aim_forward()
	ghost.global_position = at

	ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)


	ghost.set_on_deck(builds != null and builds.deck_under(at) != null)
	_eval = _evaluate_pole(at, hit ["normal"], hit.get("collider"))
	ghost.set_preview_valid(_eval ["ok"])
	_set_ring_radius(ghost.supply_reach())
	_pole_ring.global_position = at + Vector3.UP * RakeRange.LIFT
	_pole_ring.visible = true
	_pole_eval = _survey_pole(at)
	_draw_pole_ghost_wires()


func _set_ring_radius(r: float) -> void:
	if is_equal_approx(r, _pole_ring_r):
		return
	_pole_ring_r = r
	_pole_ring.mesh = HayDrone.ring_mesh(r, RakeRange.BAND, 96)


func _spare_kw() -> float:
	if builds == null or builds.grid == null:
		return 0.0
	var spare:= 0.0
	for net: Dictionary in builds.grid.networks():
		if float(net.get("supply", 0.0)) <= 0.0:
			continue
		spare += maxf(0.0, float(net ["supply"]) - float(net ["demand"]))
	return spare


func _survey_pole(at: Vector3) -> Dictionary:
	var links: Array [PowerPole] = []
	var reaches: Array [Node3D] = []
	var blocked: Array [Node3D] = []
	var spans: Array = []
	var traces: Array = []
	var ghost:= _post_ghost()
	if builds == null or builds.grid == null or ghost == null:
		return { "links": links, "reaches": reaches, "blocked": blocked,
			"spans": spans, "traces": traces }

	var crown:= ghost.wire_point()
	var buried:= ghost.buried()


	for pole in builds.poles_to_string_to(at, ghost.link_reach(), null, ghost):
		links.append(pole)
		if buried and pole.buried():
			traces.append(CableTrace.path(at, pole.global_position))
		else:
			spans.append([crown, pole.wire_point()])


	var candidates: Array [PowerPole] = []
	for pole in builds.power_poles:
		if is_instance_valid(pole):
			candidates.append(pole)
	candidates.append(ghost)


	var near: Array [Node3D] = []
	for machine in builds.grid.machines():
		if PowerGrid.in_reach(ghost, machine.global_position):
			near.append(machine)
	var survey: Dictionary = builds.grid.attach(candidates, near)


	for record: Dictionary in (survey ["found"] as Dictionary).values():
		if record ["pole"] != ghost:
			continue
		reaches.append(record ["machine"])
		var port: Vector3 = record ["at"]
		if buried:
			traces.append(CableTrace.path(at, Vector3(port.x, at.y, port.z), port))
		else:
			spans.append([crown, port])


	for machine in survey ["unreachable"] as Array [Node3D]:
		if PowerGrid.in_reach(ghost, machine.global_position):
			blocked.append(machine)
	return { "links": links, "reaches": reaches, "blocked": blocked,
		"spans": spans, "traces": traces }


func _draw_pole_ghost_wires() -> void:
	var spans: Array = _pole_eval.get("spans", [])
	var traces: Array = _pole_eval.get("traces", [])


	var drawn:= [spans, traces]
	if BuildManager.yard_memo_enabled and drawn == _pole_drawn:
		_tint_pole_blocked(_pole_eval.get("blocked", [] as Array [Node3D]))
		return
	_pole_drawn = drawn
	_pole_wire_mesh.mesh = PowerLine.ghost_mesh(spans)
	_pole_wire_mesh.visible = _pole_wire_mesh.mesh != null


	_pole_trace_mesh.mesh = CableTrace.ghost_mesh(traces)
	_pole_trace_mesh.visible = _pole_trace_mesh.mesh != null
	if _pole_wire_mesh.mesh != null:


		_pole_wire_mesh.material_override = ConveyorKit.ghost_material(true)
	var want: Array [Node3D] = _pole_eval.get("blocked", [] as Array [Node3D])
	_tint_pole_blocked(want)


func _tint_pole_blocked(machines: Array [Node3D]) -> void:
	for machine in _pole_tinted:
		if not machines.has(machine):
			_set_overlay(machine, null)
	var overlay:= ConveyorKit.ghost_material(false)
	for machine in machines:
		if not _pole_tinted.has(machine):
			_set_overlay(machine, overlay)
	_pole_tinted = machines.duplicate()


func _clear_pole_tint() -> void:
	for machine in _pole_tinted:
		_set_overlay(machine, null)
	_pole_tinted.clear()


static func _set_overlay(machine: Node3D, overlay: Material) -> void:
	if machine == null or not is_instance_valid(machine):
		return
	for node in machine.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = overlay


static func _empty_pole_eval() -> Dictionary:
	return { "links": [] as Array [PowerPole], "reaches": [] as Array [Node3D],
		"blocked": [] as Array [Node3D], "spans": [], "traces": [] }


func _pole_gift() -> bool:
	return _mode != Mode.POWER_BOX and _gift_for("pole")


func _evaluate_pole(at: Vector3, normal: Vector3, surface: Object = null) -> Dictionary:
	var gift:= _pole_gift()
	var cost:= 0.0 if gift else _post_ghost().build_cost()
	var result:= { "ok": false, "reason": "", "length": 0.0, "cost": cost, "gift": gift }
	if normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result


	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result
	var stand:= _pole_stand_reason(at, surface)
	if stand != "":
		result ["reason"] = stand
		return result
	if not GameState.can_afford(cost):
		result ["reason"] = tr("need %s") % _price(cost)
		return result
	if builds.pole_overlap(at):
		result ["reason"] = tr("too close to another post")
		return result
	var clear:= _pole_clear_reason(at)
	if clear != "":
		result ["reason"] = clear
		return result
	result ["ok"] = true
	return result


const POLE_PERCH_REACH:= 0.2


const POLE_PERCH_DROP:= 0.35


func _pole_stand_reason(at: Vector3, surface: Object) -> String:
	var ground:= _ground_reason(surface)
	if ground != "":
		return ground
	var body:= surface as CollisionObject3D
	var on_deck:= body != null and bool(body.collision_layer & Cfg.L_BUILD)
	var ghost:= _post_ghost()
	var half:= ghost.footprint() * 0.5
	var reach:= Vector2(maxf(half.x, POLE_PERCH_REACH), maxf(half.y, POLE_PERCH_REACH))
	var basis:= ghost.global_transform.basis
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner:= at + basis * Vector3(reach.x * sx, 0.0, reach.y * sz)
			var floor_y:= _solid_floor_y(corner)
			if is_nan(floor_y) or at.y - floor_y > POLE_PERCH_DROP:
				return tr("too near the edge") if on_deck else tr("stand it on the floor")
	return ""


func _ground_reason(surface: Object) -> String:
	var body:= surface as CollisionObject3D
	if body == null or not (body.collision_layer & Cfg.L_BUILD):
		return ""
	var building: Node3D = builds.owner_of(body) if builds != null else null
	if building is Platform or building is Roof:
		return ""
	return tr("on a belt") if _is_belt_body(body) else tr("stand it on the floor")


static func _is_belt_body(node: Node) -> bool:
	while node != null:
		if node is BeltPath:
			return true
		node = node.get_parent()
	return false


func _pole_clear_reason(at: Vector3) -> String:
	var ghost:= _post_ghost()
	var foot:= ghost.footprint() * Cfg.BUILD_CLEARANCE_SHRINK
	var height:= maxf(ghost.wire_point().y - ghost.global_position.y, 0.3) - Cfg.BUILD_FOOT_CLEAR
	_pole_probe.size = Vector3(foot.x, height, foot.y)
	_pole_probe_query.transform = Transform3D(ghost.global_transform.basis,
		at + Vector3.UP * (Cfg.BUILD_FOOT_CLEAR + height * 0.5))
	var hit:= _probe_obstruction(_pole_probe_query)
	if hit == null:
		return ""
	if hit is Player:
		return tr("you are in the way")
	return tr("blocked")


func _place_power_pole() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	var ghost:= _post_ghost()

	var gift:= bool(_eval.get("gift", false))
	if gift:
		if not _pay_gift("pole"):
			Audio.play("build_denied")
			return
	elif not _pay(ghost.build_cost()):
		Audio.play("build_denied")
		return
	var at:= ghost.global_position
	var yaw:= ghost.global_rotation.y


	_clear_pole_tint()
	builds.add_power_pole(at, yaw, ghost.buried(), gift)
	Audio.play_3d("build_place", at, -4.0)


func _update_dump_hatch_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": 0.0,
			"cost": Cfg.DUMP_HATCH_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_hatch_ghost.global_position = far
		_hatch_ghost.set_preview_valid(false)
		return
	var ground: Vector3 = hit ["position"]
	var forward:= _aim_forward()
	_hatch_ghost.global_position = ground


	_hatch_ghost.global_rotation = Vector3(0.0, atan2(- forward.x, - forward.z), 0.0)
	_eval = _evaluate_dump_hatch(ground, hit.get("collider"))
	_hatch_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_dump_hatch(at: Vector3, surface: Object = null) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": 0.0,
		"cost": Cfg.DUMP_HATCH_COST }


	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result
	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result
	var basis:= Basis(Vector3.UP, _hatch_ghost.global_rotation.y)
	var edge:= _hatch_edge_reason(at, basis, surface)
	if edge != "":
		result ["reason"] = edge
		return result
	var frame:= _hatch_frame_reason(at, basis)
	if frame != "":
		result ["reason"] = frame
		return result
	if not GameState.can_afford(Cfg.DUMP_HATCH_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.DUMP_HATCH_COST)
		return result
	if builds.dump_hatch_overlap(at):
		result ["reason"] = tr("too close to another hatch")
		return result


	if builds.deck_through_hatch(at, _hatch_ghost.global_rotation.y) != null:
		result ["reason"] = tr("not enough room")
		return result


	_hatch_probe.size = Vector3(1.22, 0.7, 1.66)
	_hatch_probe_query.transform = Transform3D(basis,
		at + basis.y * 0.36 + basis.z * 0.7)
	if _probe_hits(_hatch_probe_query):
		result ["reason"] = tr("not enough room")
		return result
	result ["ok"] = true
	return result


const HATCH_FRAME_HX:= 0.61
const HATCH_FRAME_Z0:= -0.13
const HATCH_FRAME_Z1:= 1.53


const HATCH_FRAME_TOP:= 1.1


const HATCH_PERCH_DROP:= 0.2


func _hatch_edge_reason(at: Vector3, basis: Basis, surface: Object) -> String:
	var body:= surface as CollisionObject3D
	var on_deck:= body != null and bool(body.collision_layer & Cfg.L_BUILD)
	for sx: float in [-1.0, 1.0]:
		for z: float in [HATCH_FRAME_Z0, HATCH_FRAME_Z1]:
			var corner:= at + basis * Vector3(HATCH_FRAME_HX * sx, 0.0, z)
			var floor_y:= _solid_floor_y(corner)
			if is_nan(floor_y) or at.y - floor_y > HATCH_PERCH_DROP:
				return tr("too near the edge") if on_deck else tr("stand it on the floor")
	return ""


func _hatch_frame_reason(at: Vector3, basis: Basis) -> String:
	var box:= BoxShape3D.new()
	var h:= HATCH_FRAME_TOP - 0.01
	box.size = Vector3(HATCH_FRAME_HX * 2.0, h, HATCH_FRAME_Z1 - HATCH_FRAME_Z0)
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = Cfg.L_BUILD
	q.collide_with_areas = false
	q.transform = Transform3D(basis, at + basis.y * (0.01 + h * 0.5)
		+ basis.z * ((HATCH_FRAME_Z0 + HATCH_FRAME_Z1) * 0.5))
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var body:= hit.get("collider") as Node
		if body == null:
			continue
		if _is_belt_body(body):
			return tr("on a belt")
		var building: Node3D = builds.owner_of(body) if builds != null else null
		if building is Platform or building is Roof or building == _hatch_ghost:
			continue
		return tr("not enough room")
	return ""


func _place_dump_hatch() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.DUMP_HATCH_COST):
		Audio.play("build_denied")
		return
	var at:= _hatch_ghost.global_position
	builds.add_dump_hatch(at, _hatch_ghost.global_rotation.y)
	Audio.play_3d("build_place_big", at, -3.0)


func _update_launcher_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": 0.0,
			"cost": Cfg.LAUNCHER_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_launcher_ghost.global_position = far
		_launcher_ghost.set_preview_valid(false)
		_seat_clear()
		return

	var ground: Vector3 = hit ["position"]
	var forward:= _aim_forward()
	var centre:= ground
	var snapped:= false


	var spec:= _seat_spec(Mode.LAUNCHER)
	var seat:= _seat_on_line(ground, Cfg.LAUNCHER_SNAP_RADIUS, spec)
	if not seat.is_empty():
		forward = seat ["forward"]
		centre = seat ["origin"]
		snapped = true

	_launcher_ghost.global_position = centre
	_launcher_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	centre = _seat_exact(_launcher_ghost, seat, centre)
	_eval = _evaluate_launcher(centre, forward, snapped)
	_seat_judge(seat, centre, spec)
	_launcher_ghost.set_preview_valid(_eval ["ok"])
	_seat_draw()


func _floor_reason(centre: Vector3) -> String:
	var reason:= _floor_reason_at(centre)
	if reason == "":
		return ""
	for off: Vector3 in [Vector3(0.004, 0.0, 0.004), Vector3(-0.004, 0.0, 0.004),
			Vector3(0.004, 0.0, -0.004), Vector3(-0.004, 0.0, -0.004)]:
		if _floor_reason_at(centre + off) == "":
			return ""
	return reason


func _floor_reason_at(centre: Vector3) -> String:
	var probe:= PhysicsRayQueryParameters3D.create(
		centre + Vector3.UP * 1.2, centre - Vector3.UP * 1.2)
	probe.collision_mask = Cfg.BUILD_SURFACE_MASK
	var floor_hit:= get_world_3d().direct_space_state.intersect_ray(probe)
	if floor_hit.is_empty():
		return tr("nothing to stand on")
	if floor_hit.get("collider") is Platform:
		return ""
	if (floor_hit ["normal"] as Vector3).dot(Vector3.UP) < 0.72:
		return tr("surface too steep")
	return ""


func _evaluate_launcher(centre: Vector3, forward: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": 0.0,
		"cost": Cfg.LAUNCHER_COST }


	if not snapped:
		var floor_reason:= _floor_reason(centre)
		if floor_reason != "":
			result ["reason"] = floor_reason
			return result
	if not GameState.can_afford(Cfg.LAUNCHER_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.LAUNCHER_COST)
		return result
	if builds.launcher_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	_launcher_probe.size = Vector3(1.7, 2.05, 2.4)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_launcher_probe_query.transform = Transform3D(basis, centre + basis.y * 1.05)
	if _probe_hits(_launcher_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_launcher() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.LAUNCHER_COST + _seat_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _launcher_ghost.global_position
	var yaw:= _launcher_ghost.global_rotation.y


	var gun:= builds.add_tube_launcher(at, yaw)
	_lay_seat_stub(gun)
	if gun != null:
		gun.aim = _launcher_ghost.aim
		gun.power = _launcher_ghost.power
	Audio.play_3d("build_place_big", at, -3.0)


func _update_compressor_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"),
			"length": Cfg.COMPRESSOR_LENGTH, "cost": Cfg.COMPRESSOR_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_compressor_ghost.global_position = far
		_compressor_ghost.set_preview_valid(false)
		_seat_clear()
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false


	var spec:= _seat_spec(Mode.COMPRESSOR)
	var seat:= _seat_on_line(hit ["position"], Cfg.COMPRESSOR_SNAP_RADIUS, spec)
	if not seat.is_empty():
		forward = seat ["forward"]
		centre = seat ["origin"]
		snapped = true

	_compressor_ghost.global_position = centre


	_compressor_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	centre = _seat_exact(_compressor_ghost, seat, centre)
	_eval = _evaluate_compressor(centre, forward, hit ["normal"], snapped)
	_seat_judge(seat, centre, spec)
	_compressor_ghost.set_preview_valid(_eval ["ok"])
	_seat_draw()


func _evaluate_compressor(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.COMPRESSOR_LENGTH,
		"cost": Cfg.COMPRESSOR_COST }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.COMPRESSOR_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.COMPRESSOR_COST)
		return result
	if builds.compressor_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	_compressor_probe.size = Vector3(1.3, 2.4, Cfg.COMPRESSOR_LENGTH - 0.3)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_compressor_probe_query.transform = Transform3D(basis, centre + basis.y * 0.85)
	if _probe_hits(_compressor_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_compressor() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.COMPRESSOR_COST + _seat_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _compressor_ghost.global_position
	var yaw:= _compressor_ghost.global_rotation.y
	_lay_seat_stub(builds.add_compressor(at, yaw))
	Audio.play_3d("build_place_big", at, -3.0)


func _update_pulper_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"),
			"length": Cfg.PULPER_LENGTH, "cost": Cfg.PULPER_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_pulper_ghost.global_position = far
		_pulper_ghost.set_preview_valid(false)
		_seat_clear()
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false


	var spec:= _seat_spec(Mode.PULPER)
	var seat:= _seat_on_line(hit ["position"], Cfg.PULPER_SNAP_RADIUS, spec)
	if not seat.is_empty():
		forward = seat ["forward"]
		centre = seat ["origin"]
		snapped = true

	_pulper_ghost.global_position = centre


	_pulper_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	centre = _seat_exact(_pulper_ghost, seat, centre)
	_eval = _evaluate_pulper(centre, forward, hit ["normal"], snapped)
	_seat_judge(seat, centre, spec)
	_pulper_ghost.set_preview_valid(_eval ["ok"])
	_seat_draw()


func _evaluate_pulper(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.PULPER_LENGTH,
		"cost": Cfg.PULPER_COST }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.PULPER_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.PULPER_COST)
		return result
	if builds.pulper_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	_pulper_probe.size = Vector3(1.3, 2.4, Cfg.PULPER_LENGTH - 0.3)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_pulper_probe_query.transform = Transform3D(basis, centre + basis.y * 0.85)
	if _probe_hits(_pulper_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_pulper() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.PULPER_COST + _seat_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _pulper_ghost.global_position
	var yaw:= _pulper_ghost.global_rotation.y
	_lay_seat_stub(builds.add_pulper(at, yaw))
	Audio.play_3d("build_place_big", at, -3.0)


func _update_paper_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"),
			"length": Cfg.PAPER_LENGTH, "cost": Cfg.PAPER_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_paper_ghost.global_position = far
		_paper_ghost.set_preview_valid(false)
		_seat_clear()
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false


	var spec:= _seat_spec(Mode.PAPER)
	var seat:= _seat_on_line(hit ["position"], Cfg.PAPER_SNAP_RADIUS, spec)
	if not seat.is_empty():
		forward = seat ["forward"]
		centre = seat ["origin"]
		snapped = true

	_paper_ghost.global_position = centre


	_paper_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	centre = _seat_exact(_paper_ghost, seat, centre)
	_eval = _evaluate_paper(centre, forward, hit ["normal"], snapped)
	_seat_judge(seat, centre, spec)
	_paper_ghost.set_preview_valid(_eval ["ok"])
	_seat_draw()


func _evaluate_paper(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.PAPER_LENGTH,
		"cost": Cfg.PAPER_COST }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.PAPER_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.PAPER_COST)
		return result
	if builds.paper_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	_paper_probe.size = Vector3(1.3, 2.6, Cfg.PAPER_LENGTH - 0.3)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_paper_probe_query.transform = Transform3D(basis, centre + basis.y * 0.95)
	if _probe_hits(_paper_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_paper() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.PAPER_COST + _seat_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _paper_ghost.global_position
	var yaw:= _paper_ghost.global_rotation.y
	_lay_seat_stub(builds.add_paper(at, yaw))
	Audio.play_3d("build_place_big", at, -3.0)


func _update_briquette_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"),
			"length": Cfg.BRIQUETTE_LENGTH, "cost": Cfg.BRIQUETTE_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_briquette_ghost.global_position = far
		_briquette_ghost.set_preview_valid(false)
		_seat_clear()
		return


	var ground: Vector3 = hit ["position"]
	var forward:= _aim_forward()
	var origin:= ground
	var snapped:= false


	var spec:= _seat_spec(Mode.BRIQUETTE)
	var seat:= _seat_on_line(ground, Cfg.BRIQUETTE_SNAP_RADIUS, spec)
	if not seat.is_empty():
		forward = seat ["forward"]
		origin = seat ["origin"]
		snapped = true

	_briquette_ghost.global_position = origin


	_briquette_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	origin = _seat_exact(_briquette_ghost, seat, origin)
	_eval = _evaluate_briquette(origin, forward, hit ["normal"], snapped)
	_seat_judge(seat, origin, spec)
	_briquette_ghost.set_preview_valid(_eval ["ok"])
	_seat_draw()


func _evaluate_briquette(origin: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.BRIQUETTE_LENGTH,
		"cost": Cfg.BRIQUETTE_COST }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.BRIQUETTE_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.BRIQUETTE_COST)
		return result
	if builds.briquette_overlap(origin, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	var basis:= BeltPath.run_basis(origin, origin + forward)
	var tall:= Cfg.BRIQUETTE_PORT_UP + 1.6 - Cfg.BUILD_FOOT_CLEAR
	var lift:= basis.y * (Cfg.BUILD_FOOT_CLEAR + tall * 0.5)
	var spine:= Cfg.BRIQUETTE_LENGTH - 0.3
	_briquette_probe.size = Vector3(1.2, tall, spine)


	var mid:= (Cfg.BRIQUETTE_PORT_DISC - Cfg.BRIQUETTE_PORT_BRICK) * 0.5
	_briquette_probe_query.transform = Transform3D(basis, origin + lift + basis.z * mid)
	if _probe_hits(_briquette_probe_query):
		result ["reason"] = tr("blocked")
		return result
	var arm:= Cfg.BRIQUETTE_PORT_WAD - 1.73 - 0.15
	_briquette_arm_probe.size = Vector3(1.2, tall, arm)


	var arm_basis:= Basis(basis.z, basis.y, - basis.x)
	_briquette_arm_query.transform = Transform3D(arm_basis, origin + lift
		- basis.x * (Cfg.BRIQUETTE_PORT_WAD - arm * 0.5 - 0.15)
		+ basis.z * Cfg.BRIQUETTE_PORT_WAD_OFFSET)
	if _probe_hits(_briquette_arm_query):
		result ["reason"] = tr("the side input is blocked")
		return result
	result ["ok"] = true
	return result


func _place_briquette() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.BRIQUETTE_COST + _seat_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _briquette_ghost.global_position
	var yaw:= _briquette_ghost.global_rotation.y
	_lay_seat_stub(builds.add_briquette(at, yaw))
	Audio.play_3d("build_place_big", at, -3.0)


func _update_wrapper_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"),
			"length": Cfg.WRAPPER_LENGTH, "cost": Cfg.WRAPPER_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_wrapper_ghost.global_position = far
		_wrapper_ghost.set_preview_valid(false)
		_seat_clear()
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false


	var spec:= _seat_spec(Mode.WRAPPER)
	var seat:= _seat_on_line(hit ["position"], Cfg.WRAPPER_SNAP_RADIUS, spec)
	if not seat.is_empty():
		forward = seat ["forward"]
		centre = seat ["origin"]
		snapped = true

	_wrapper_ghost.global_position = centre


	_wrapper_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	centre = _seat_exact(_wrapper_ghost, seat, centre)
	_eval = _evaluate_wrapper(centre, forward, hit ["normal"], snapped)
	_seat_judge(seat, centre, spec)
	_wrapper_ghost.set_preview_valid(_eval ["ok"])
	_seat_draw()


func _evaluate_wrapper(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.WRAPPER_LENGTH,
		"cost": Cfg.WRAPPER_COST }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.WRAPPER_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.WRAPPER_COST)
		return result
	if builds.wrapper_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	_wrapper_probe.size = Vector3(1.3, 1.5, Cfg.WRAPPER_LENGTH - 0.3)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_wrapper_probe_query.transform = Transform3D(basis, centre + basis.y * 0.6)
	if _probe_hits(_wrapper_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_wrapper() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.WRAPPER_COST + _seat_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _wrapper_ghost.global_position
	var yaw:= _wrapper_ghost.global_rotation.y
	_lay_seat_stub(builds.add_wrapper(at, yaw))
	Audio.play_3d("build_place_big", at, -3.0)


const SILO_FEED_TOLERANCE:= Cfg.BELT_FRAME_DEPTH * 0.5


func _update_silo_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"),
			"length": Cfg.SILO_LENGTH, "cost": Cfg.SILO_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_silo_ghost.global_position = far
		_silo_ghost.set_preview_valid(false)
		_port_belts = []
		_draw_port_belts()
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false
	var refusal:= ""

	var joint:= builds.nearest_belt_end(deck, Cfg.SILO_SNAP_RADIUS)
	if not joint.is_empty():
		var port: Vector3 = joint ["point"]
		if bool(joint ["start"]):


			forward = joint ["forward"]
			centre = port - forward * (Cfg.SILO_LENGTH * 0.5)
			snapped = true
		else:


			refusal = tr("fed from the top: run the belt up to the top opening")

	if not snapped:


		var basis:= BeltPath.run_basis(centre, centre + forward)
		var guess:= centre + basis * HaySilo.F_BELT_IN
		var high:= builds.nearest_belt_end(guess, Cfg.SILO_SNAP_RADIUS)
		if not high.is_empty() and not bool(high ["start"]):
			var feed: Vector3 = high ["point"]
			var aligned:= BeltPath.run_basis(centre, centre + (high ["forward"] as Vector3))
			var stood:= feed - aligned * HaySilo.F_BELT_IN


			if absf(stood.y - deck.y) <= SILO_FEED_TOLERANCE:
				forward = high ["forward"]
				centre = Vector3(stood.x, deck.y, stood.z)
				snapped = true
				refusal = ""

	_silo_ghost.global_position = centre


	_silo_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_silo(centre, forward, hit ["normal"], snapped, refusal)


	_port_belts = _judge_port_mouths([
		[_silo_ghost.port_in(), forward, true],
		[_silo_ghost.port_out(), forward, false]])
	_ports_unjoined([[_silo_ghost.port_in(), forward, true],
		[_silo_ghost.port_out(), forward, false]])
	_silo_ghost.set_preview_valid(_eval ["ok"])
	_draw_port_belts()


func _evaluate_silo(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool, refusal: String) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.SILO_LENGTH,
		"cost": Cfg.SILO_COST }
	if refusal != "":
		result ["reason"] = refusal
		return result
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.SILO_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.SILO_COST)
		return result
	if builds.silo_overlap(centre, forward):
		result ["reason"] = tr("too close to another machine")
		return result


	_silo_probe.size = Vector3(1.3, 4.4, Cfg.SILO_LENGTH - 0.3)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_silo_probe_query.transform = Transform3D(basis, centre + basis.y * 2.05)
	if _probe_hits(_silo_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_silo() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.SILO_COST + _port_belts_cost()):
		Audio.play("build_denied")
		return
	var at:= _silo_ghost.global_position
	var yaw:= _silo_ghost.global_rotation.y
	_lay_port_belts(builds.add_silo(at, yaw))
	Audio.play_3d("build_place_big", at, -3.0)


func _update_drone_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():


		var blocked:= _crowded_reason("drone", builds.drones_left(), Cfg.DRONE_LIMIT)
		_eval = { "ok": false, "length": 0.0, "cost": builds.drone_price(),
			"reason": blocked if blocked != "" else tr("aim at ground") }
		var far:= player.eye_position() + player.look_direction() * _reach
		_drone_ghost.global_position = far
		_drone_ghost.set_preview_valid(false)
		return


	var at: Vector3 = hit ["position"]
	var forward:= _aim_forward()
	_drone_ghost.global_position = at
	_drone_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_drone(at, hit ["normal"], hit.get("collider"))
	_drone_ghost.set_preview_valid(_eval ["ok"])


func _crowded_reason(what: String, left: int, limit: int) -> String:
	if left > 0:
		return ""

	match what:
		"arm":
			return tr("arm limit reached (%d)") % limit
		"drone":
			return tr("drone limit reached (%d)") % limit
		"rake":
			return tr("rake limit reached (%d)") % limit
	return "%s limit reached (%d)" % [what, limit]


func _evaluate_drone(at: Vector3, normal: Vector3, surface: Object = null) -> Dictionary:
	var price:= builds.drone_price()
	var result:= { "ok": false, "reason": "", "length": 0.0, "cost": price }


	var blocked:= _crowded_reason("drone", builds.drones_left(), Cfg.DRONE_LIMIT)
	if blocked != "":
		result ["reason"] = blocked
		return result


	if normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result


	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result


	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result
	if not GameState.can_afford(price):
		result ["reason"] = tr("need %s") % _price(price)
		return result
	if builds.drone_overlap(at, Cfg.DRONE_CLEAR_RADIUS):
		result ["reason"] = tr("too close to another drone")
		return result


	_drone_probe.size = Vector3(3.1, 1.1, 3.1)
	_drone_probe_query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.62)
	if _probe_hits(_drone_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _update_rake_ghost() -> void:
	var hit:= _surface_hit()
	if hit.is_empty():


		var blocked:= _crowded_reason("rake", builds.rakes_left(), Cfg.RAKE_LIMIT)
		var gift:= _gift_for("rake")
		_eval = { "ok": false, "length": 0.0,
			"cost": 0.0 if gift else builds.rake_price(), "gift": gift,
			"reason": blocked if blocked != "" else tr("aim at ground") }
		var far:= player.eye_position() + player.look_direction() * _reach
		_rake_ghost.global_position = far
		_rake_ghost.set_preview_valid(false)
		return
	var at: Vector3 = hit ["position"]
	var forward:= _aim_forward()
	_rake_ghost.global_position = at
	_rake_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_rake(at, hit ["normal"], forward, hit.get("collider"))
	_rake_ghost.set_preview_valid(_eval ["ok"])


func _evaluate_rake(at: Vector3, normal: Vector3, forward: Vector3,
		surface: Object = null) -> Dictionary:

	var gift:= _gift_for("rake")
	var price:= 0.0 if gift else builds.rake_price()
	var result:= { "ok": false, "reason": "", "length": 0.0, "cost": price, "gift": gift }


	var crowded:= _crowded_reason("rake", builds.rakes_left(), Cfg.RAKE_LIMIT)
	if crowded != "":
		result ["reason"] = crowded
		return result
	if normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result


	var footing:= _footing_reason(at)
	if footing != "":
		result ["reason"] = footing
		return result


	var ground:= _ground_reason(surface)
	if ground != "":
		result ["reason"] = ground
		return result
	if not GameState.can_afford(price):
		result ["reason"] = tr("need %s") % _price(price)
		return result
	var fld: HayField = builds.field if builds != null else null
	if fld != null:


		if _rake_hay_over_chassis(at, forward, fld) > Cfg.RAKE_STAND_CLEAR:
			result ["reason"] = tr("too close to the hay")
			return result


		var face:= at + forward * Cfg.RAKE_REACH
		if fld.height_at(face.x, face.z) <= at.y + 0.06:
			result ["reason"] = tr("must face the hay")
			return result
	for rake in builds.piston_rakes:
		if is_instance_valid(rake) and rake.global_position.distance_to(at) < Cfg.RAKE_HALF_WIDTH * 2.0:
			result ["reason"] = tr("too close to another rake")
			return result


	var margin:= Cfg.RAKE_SITE_MARGIN * 2.0
	_rake_probe.size = Vector3(PistonRake.BODY_W + margin, PistonRake.BODY_H - 0.2,
		PistonRake.BODY_L + margin)
	var basis:= Basis(Vector3.UP, atan2(forward.x, forward.z))
	_rake_probe_query.transform = Transform3D(basis,
		at + basis * Vector3(0.0, PistonRake.BODY_H * 0.5, PistonRake.BODY_Z))
	if _probe_hits(_rake_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _rake_hay_over_chassis(at: Vector3, forward: Vector3, fld: HayField) -> float:
	var basis:= Basis(Vector3.UP, atan2(forward.x, forward.z))
	var half_w: float = PistonRake.BODY_W * 0.5
	var half_l: float = PistonRake.BODY_L * 0.5
	var deepest:= 0.0
	var steps: int = maxi(2, int(ceil(maxf(PistonRake.BODY_W, PistonRake.BODY_L) / Cfg.CELL)))
	for a in steps + 1:
		for b in steps + 1:
			var local:= Vector3(
				lerpf(- half_w, half_w, float(a) / float(steps)),
				0.0,
				PistonRake.BODY_Z + lerpf(- half_l, half_l, float(b) / float(steps)))
			var p:= at + basis * local
			deepest = maxf(deepest, fld.height_at(p.x, p.z) - at.y)
	return deepest


func rake_drive_reason(rake: PistonRake, to: Vector3) -> String:
	if not is_instance_valid(rake) or not rake.is_inside_tree():
		return tr("blocked")
	var from:= rake.global_position
	var basis:= Basis(Vector3.UP, rake.global_rotation.y)
	var ahead:= signf((basis.inverse() * (to - from)).z)


	var half_w:= PistonRake.BODY_W * 0.5 - RAKE_DRIVE_INSET
	var half_l:= PistonRake.BODY_L * 0.5 - RAKE_DRIVE_INSET
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var local:= Vector3(c.x * half_w, 0.0, PistonRake.BODY_Z + c.y * half_l)
		if _rake_stands_on(from + basis * local, from.y) and not _rake_stands_on(to + basis * local, from.y):
			return tr("no ground under it")


	var fld: HayField = builds.field if builds != null else null
	if fld != null:
		var then:= _rake_hay_over_chassis(to, basis.z, fld)
		if then > Cfg.RAKE_STAND_CLEAR and then > _rake_hay_over_chassis(from, basis.z, fld) + 0.001:
			return tr("too close to the hay")


	if _rake_drive_query == null:
		_rake_drive_probe = BoxShape3D.new()
		_rake_drive_query = PhysicsShapeQueryParameters3D.new()
		_rake_drive_query.shape = _rake_drive_probe
		_rake_drive_query.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_KEEPOUT | Cfg.L_PLAYER
		_rake_drive_query.collide_with_areas = false
	var depth:= Cfg.RAKE_SITE_MARGIN
	var lead:= PistonRake.BODY_Z + ahead * (PistonRake.BODY_L * 0.5 + 0.01 + depth * 0.5)
	_rake_drive_probe.size = Vector3(PistonRake.BODY_W, PistonRake.BODY_H - 0.2, depth)
	_rake_drive_query.transform = Transform3D(basis,
		to + basis * Vector3(0.0, PistonRake.BODY_H * 0.5, lead))
	var own: Array [RID] = []
	for child in rake.get_children():
		if child is CollisionObject3D:
			own.append((child as CollisionObject3D).get_rid())
	_rake_drive_query.exclude = own
	if _probe_hits(_rake_drive_query):
		return tr("blocked")
	return ""


func _rake_stands_on(at: Vector3, y: float) -> bool:
	var floor_y:= _solid_floor_y(Vector3(at.x, y, at.z))
	return not is_nan(floor_y) and absf(floor_y - y) <= RAKE_DRIVE_STEP_UP


func _solid_floor_y(at: Vector3) -> float:
	var from:= at + Vector3.UP * 0.25
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_PROBE_DROP)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return NAN
	return (hit ["position"] as Vector3).y


func _hay_top_y(at: Vector3) -> float:
	var from:= at + Vector3.UP * 0.25
	var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_PROBE_DROP)
	q.collision_mask = Cfg.L_PILE
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return NAN
	return (hit ["position"] as Vector3).y


func _footing_reason(at: Vector3) -> String:
	var floor_y:= _solid_floor_y(at)
	if is_nan(floor_y):
		return tr("no ground under it")
	var hay_y:= _hay_top_y(at)
	if not is_nan(hay_y) and hay_y - floor_y > Cfg.RAKE_STAND_CLEAR:
		return tr("stand it on the floor")
	return ""


func _place_rake() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return


	var price:= float(_eval ["cost"])
	var gift:= bool(_eval.get("gift", false))
	if gift:
		if not _pay_gift("rake"):
			Audio.play("build_denied")
			return
	elif not _pay(price):
		Audio.play("build_denied")
		return
	var at:= _rake_ghost.global_position
	var yaw:= _rake_ghost.global_rotation.y
	builds.add_piston_rake(at, yaw, 0.0 if gift else price, gift)
	Audio.play_3d("build_place_big", at, -3.0)


func _place_drone() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return


	var price:= float(_eval ["cost"])
	if not _pay(price):
		Audio.play("build_denied")
		return
	var at:= _drone_ghost.global_position
	var yaw:= _drone_ghost.global_rotation.y
	builds.add_hay_drone(at, yaw, price)
	Audio.play_3d("build_place_big", at, -3.0)


const COMPACT_MOUTH_GAP:= 0.3


func compact_mouth_on_compact(ghost: ConveyorCompactSplitter) -> bool:
	var ours:= ghost.ports()
	for other in builds.splitters:
		if other == ghost or not is_instance_valid(other) or not other is ConveyorCompactSplitter:
			continue
		if other.global_position.distance_to(ghost.global_position) > ConveyorCompactSplitter.PORT_R * 2.0 + COMPACT_MOUTH_GAP:
			continue
		for theirs: Vector3 in other.ports():
			for mouth: Vector3 in ours:
				if mouth.distance_to(theirs) < COMPACT_MOUTH_GAP:
					return true
	return false


func compact_seat(near: Vector3, aim: Vector3) -> Dictionary:
	var joint:= builds.nearest_wye_joint(near, Cfg.SPLITTER_SNAP_RADIUS)
	if joint.is_empty():
		return { }
	var r:= ConveyorCompactSplitter.PORT_R
	var along: Vector3 = joint ["forward"]
	if not bool(joint ["start"]):
		return { "centre": (joint ["point"] as Vector3) + along * r, "forward": along }

	var right:= Vector3(- along.z, 0.0, along.x)
	var facing:= along
	for option: Vector3 in [right, - right]:
		if option.dot(aim) > facing.dot(aim):
			facing = option
	return { "centre": (joint ["point"] as Vector3) - along * r, "forward": facing }


func _compact_ghost() -> ConveyorCompactSplitter:
	return _smart_splitter_ghost if _mode == Mode.SMART_SPLITTER else _compact_splitter_ghost


func _update_compact_splitter_ghost() -> void:
	var ghost:= _compact_ghost()
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": 1.84,
			"cost": ghost.build_cost() }
		ghost.global_position = player.eye_position() + player.look_direction() * _reach
		ghost.set_preview_valid(false)
		_ghost.visible = false
		return
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var centre: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var snapped:= false
	var seat:= compact_seat(centre, forward)
	if not seat.is_empty():
		centre = seat ["centre"]
		forward = seat ["forward"]
		snapped = true
	ghost.global_rotation = Vector3(0.0, atan2(- forward.x, - forward.z), 0.0)
	ghost.global_position = centre


	_eval = _evaluate_u_wye(ghost, forward, hit ["normal"], snapped, ghost.build_cost(),
		ConveyorCompactSplitter.PORT_R * 2.0, ConveyorCompactSplitter.PORT_R)
	if _eval ["ok"] and compact_mouth_on_compact(ghost):
		_eval ["ok"] = false
		_eval ["reason"] = tr("put a belt between two splitter boxes")

	var mouths: Array = [[ghost.port_in(), - forward]]
	for side: int in [ConveyorCompactSplitter.OUT_LEFT, ConveyorCompactSplitter.OUT_FORWARD,
			ConveyorCompactSplitter.OUT_RIGHT]:
		mouths.append([ghost.port(side), ghost.arm_travel(side)])
	_judge_wye_mouths(mouths)
	ghost.set_preview_valid(_eval ["ok"])
	_show_wye_flow([
		PackedVector3Array([ghost.port_in() - forward * WYE_FLOW_REACH, centre]),
		PackedVector3Array([centre, ghost.port(ConveyorCompactSplitter.OUT_LEFT)
			+ ghost.arm_travel(ConveyorCompactSplitter.OUT_LEFT) * WYE_FLOW_REACH]),
		PackedVector3Array([centre, ghost.port(ConveyorCompactSplitter.OUT_FORWARD)
			+ ghost.arm_travel(ConveyorCompactSplitter.OUT_FORWARD) * WYE_FLOW_REACH]),
		PackedVector3Array([centre, ghost.port(ConveyorCompactSplitter.OUT_RIGHT)
			+ ghost.arm_travel(ConveyorCompactSplitter.OUT_RIGHT) * WYE_FLOW_REACH]),
	])


func _place_compact_splitter() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	var ghost:= _compact_ghost()
	var cost:= ghost.build_cost()
	if not _pay(cost):
		Audio.play("build_denied")
		return
	var at:= ghost.global_position
	builds.add_compact_splitter(at, ghost.global_rotation.y, _mode == Mode.SMART_SPLITTER)
	Audio.play_3d("build_place", at)

func _update_splitter_ghost() -> void:
	var span:= Cfg.SPLITTER_PORT_R * 2.0
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": span,
			"cost": Cfg.SPLITTER_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_splitter_ghost.global_position = far
		_splitter_ghost.set_preview_valid(false)
		_ghost.visible = false
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false


	var joint:= builds.nearest_wye_joint(deck, Cfg.SPLITTER_SNAP_RADIUS)
	if not joint.is_empty() and not bool(joint ["start"]):


		forward = joint ["forward"]
		centre = (joint ["point"] as Vector3) + forward * Cfg.SPLITTER_PORT_R
		snapped = true
	elif not joint.is_empty():


		var leaving: Vector3 = joint ["forward"]
		var as_left:= leaving.rotated(Vector3.UP, - Cfg.SPLITTER_SPLAY)
		var as_right:= leaving.rotated(Vector3.UP, Cfg.SPLITTER_SPLAY)
		var hand:= 1.0 if as_left.dot(forward) >= as_right.dot(forward) else -1.0
		forward = as_left if hand > 0.0 else as_right
		_splitter_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)


		centre = ((joint ["point"] as Vector3)
			- _splitter_ghost.global_basis * ConveyorSplitter._arm_local(hand))
		snapped = true

	_splitter_ghost.global_position = centre


	_splitter_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_splitter(centre, forward, hit ["normal"], snapped)


	_judge_wye_mouths([
		[_splitter_ghost.port_in(), - forward],
		[_splitter_ghost.port_left(), _splitter_ghost.arm_travel(ConveyorSplitter.LEFT)],
		[_splitter_ghost.port_right(), _splitter_ghost.arm_travel(ConveyorSplitter.RIGHT)]])
	_splitter_ghost.set_preview_valid(_eval ["ok"])


	var left_out:= (_splitter_ghost.port_left() - centre).normalized()
	var right_out:= (_splitter_ghost.port_right() - centre).normalized()
	_show_wye_flow([
		PackedVector3Array([_splitter_ghost.port_in() - forward * WYE_FLOW_REACH,
			centre]),
		PackedVector3Array([centre,
			_splitter_ghost.port_left() + left_out * WYE_FLOW_REACH]),
		PackedVector3Array([centre,
			_splitter_ghost.port_right() + right_out * WYE_FLOW_REACH]),
	])


func _evaluate_splitter(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.SPLITTER_PORT_R * 2.0,
		"cost": Cfg.SPLITTER_COST }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.SPLITTER_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.SPLITTER_COST)
		return result
	if builds.splitter_overlap(centre):
		result ["reason"] = tr("too close to another module")
		return result


	_splitter_probe.size = Vector3(Cfg.BELT_WIDTH + 0.1, 1.3,
		Cfg.SPLITTER_PORT_R * 1.6)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_splitter_probe_query.transform = Transform3D(basis, centre + basis.y * 0.3)
	if _probe_hits(_splitter_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_splitter() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.SPLITTER_COST):
		Audio.play("build_denied")
		return
	var at:= _splitter_ghost.global_position
	var yaw:= _splitter_ghost.global_rotation.y
	builds.add_splitter(at, yaw)
	Audio.play_3d("build_place", at)


func _update_joiner_ghost() -> void:
	var span:= Cfg.JOINER_PORT_R * 2.0
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": span,
			"cost": Cfg.JOINER_COST }
		var far:= player.eye_position() + player.look_direction() * _reach
		_joiner_ghost.global_position = far
		_joiner_ghost.set_preview_valid(false)
		_ghost.visible = false
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false


	var joint:= builds.nearest_wye_joint(deck, Cfg.JOINER_SNAP_RADIUS)
	if not joint.is_empty() and not bool(joint ["start"]):
		var arriving: Vector3 = joint ["forward"]


		var as_left:= arriving.rotated(Vector3.UP, Cfg.JOINER_SPLAY)
		var as_right:= arriving.rotated(Vector3.UP, - Cfg.JOINER_SPLAY)
		var hand:= 1.0 if as_left.dot(forward) >= as_right.dot(forward) else -1.0
		forward = as_left if hand > 0.0 else as_right
		_joiner_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)


		centre = ((joint ["point"] as Vector3)
			- _joiner_ghost.global_basis * ConveyorJoiner._arm_local(hand))
		snapped = true
	elif not joint.is_empty():


		forward = joint ["forward"]
		_joiner_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
		centre = (joint ["point"] as Vector3) - forward * Cfg.JOINER_PORT_R
		snapped = true
	else:
		_joiner_ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)

	_joiner_ghost.global_position = centre
	_eval = _evaluate_joiner(centre, forward, hit ["normal"], snapped)

	_judge_wye_mouths([
		[_joiner_ghost.port_left(), - _joiner_ghost.arm_travel(ConveyorJoiner.LEFT)],
		[_joiner_ghost.port_right(), - _joiner_ghost.arm_travel(ConveyorJoiner.RIGHT)],
		[_joiner_ghost.port_out(), forward]])
	_joiner_ghost.set_preview_valid(_eval ["ok"])


	var in_left:= _joiner_ghost.arm_travel(ConveyorJoiner.LEFT)
	var in_right:= _joiner_ghost.arm_travel(ConveyorJoiner.RIGHT)
	_show_wye_flow([
		PackedVector3Array([_joiner_ghost.port_left() - in_left * WYE_FLOW_REACH,
			centre]),
		PackedVector3Array([_joiner_ghost.port_right() - in_right * WYE_FLOW_REACH,
			centre]),
		PackedVector3Array([centre,
			_joiner_ghost.port_out() + forward * WYE_FLOW_REACH]),
	])


func _evaluate_joiner(centre: Vector3, forward: Vector3, normal: Vector3,
		snapped: bool) -> Dictionary:
	var result:= { "ok": false, "reason": "", "length": Cfg.JOINER_PORT_R * 2.0,
		"cost": Cfg.JOINER_COST }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(Cfg.JOINER_COST):
		result ["reason"] = tr("need %s") % _price(Cfg.JOINER_COST)
		return result
	if builds.joiner_overlap(centre):
		result ["reason"] = tr("too close to another module")
		return result


	_joiner_probe.size = Vector3(Cfg.BELT_WIDTH + 0.1, 1.3,
		Cfg.JOINER_PORT_R * 1.6)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_joiner_probe_query.transform = Transform3D(basis, centre + basis.y * 0.3)
	if _probe_hits(_joiner_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_joiner() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.JOINER_COST):
		Audio.play("build_denied")
		return
	var at:= _joiner_ghost.global_position
	var yaw:= _joiner_ghost.global_rotation.y
	builds.add_joiner(at, yaw)
	Audio.play_3d("build_place", at)


func _update_u_splitter_ghost() -> void:
	var ghost:= _u_splitter_ghost
	var span:= Cfg.SPLITTER_PORT_R + ConveyorUSplitter.OUT_Z
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": span,
			"cost": Cfg.SPLITTER_COST }
		ghost.global_position = player.eye_position() + player.look_direction() * _reach
		ghost.set_preview_valid(false)
		_ghost.visible = false
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false

	var joint:= builds.nearest_wye_joint(deck, Cfg.SPLITTER_SNAP_RADIUS)
	if not joint.is_empty() and not bool(joint ["start"]):

		forward = joint ["forward"]
		centre = (joint ["point"] as Vector3) + forward * Cfg.SPLITTER_PORT_R
		snapped = true
	elif not joint.is_empty():

		forward = joint ["forward"]
		var hand:= _u_hand(joint ["point"], forward, deck)
		ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)


		centre = ((joint ["point"] as Vector3)
			- ghost.global_basis * ConveyorUSplitter.mouth_local(hand))
		snapped = true

	ghost.global_position = centre
	ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_u_wye(ghost, forward, hit ["normal"], snapped, Cfg.SPLITTER_COST, span)
	ghost.set_preview_valid(_eval ["ok"])


	var chains: Array = [PackedVector3Array([ghost.port_in() - forward * WYE_FLOW_REACH,
		centre])]
	for side: int in ConveyorSplitter.SIDES:
		var line:= ghost.arm_line(side)
		line.append(ghost.port(side) + forward * WYE_FLOW_REACH)
		chains.append(line)
	_show_wye_flow(chains)


func _update_u_joiner_ghost() -> void:
	var ghost:= _u_joiner_ghost
	var span:= Cfg.JOINER_PORT_R + ConveyorUSplitter.OUT_Z
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": span,
			"cost": Cfg.JOINER_COST }
		ghost.global_position = player.eye_position() + player.look_direction() * _reach
		ghost.set_preview_valid(false)
		_ghost.visible = false
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var forward:= _aim_forward()
	var centre:= deck
	var snapped:= false

	var joint:= builds.nearest_wye_joint(deck, Cfg.JOINER_SNAP_RADIUS)
	if not joint.is_empty() and not bool(joint ["start"]):


		forward = joint ["forward"]
		var hand:= _u_hand(joint ["point"], forward, deck)
		ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
		centre = ((joint ["point"] as Vector3)
			- ghost.global_basis * ConveyorUJoiner.mouth_local(hand))
		snapped = true
	elif not joint.is_empty():

		forward = joint ["forward"]
		centre = (joint ["point"] as Vector3) - forward * Cfg.JOINER_PORT_R
		snapped = true

	ghost.global_position = centre
	ghost.global_rotation = Vector3(0.0, atan2(forward.x, forward.z), 0.0)
	_eval = _evaluate_u_wye(ghost, forward, hit ["normal"], snapped, Cfg.JOINER_COST, span)
	ghost.set_preview_valid(_eval ["ok"])
	var chains: Array = []
	for side: int in ConveyorJoiner.SIDES:
		var line:= PackedVector3Array([ghost.port(side) - forward * WYE_FLOW_REACH])
		line.append_array(ghost.arm_line(side))
		chains.append(line)
	chains.append(PackedVector3Array([centre, ghost.port_out() + forward * WYE_FLOW_REACH]))
	_show_wye_flow(chains)


func _u_hand(joint: Vector3, forward: Vector3, aim: Vector3) -> float:
	const ON_THE_LINE:= 0.25
	var left:= Vector3.UP.cross(forward).normalized()
	var side:= (aim - joint).dot(left)
	if absf(side) < ON_THE_LINE:
		side = _aim_forward().dot(left)
	return 1.0 if side <= 0.0 else -1.0


func _evaluate_u_wye(ghost: Node3D, forward: Vector3, _normal: Vector3, snapped: bool,
		cost: float, span: float, port_r: float = Cfg.SPLITTER_PORT_R) -> Dictionary:
	var centre:= ghost.global_position
	var result:= { "ok": false, "reason": "", "length": span, "cost": cost }


	if not snapped:
		var floor_reason:= _floor_reason(centre)
		if floor_reason != "":
			result ["reason"] = floor_reason
			return result
	if not GameState.can_afford(cost):
		result ["reason"] = tr("need %s") % _price(cost)
		return result
	if builds.wye_overlap(ghost.call("footprint"), ghost):
		result ["reason"] = tr("too close to another module")
		return result
	_splitter_probe.size = Vector3(Cfg.BELT_WIDTH + 0.1, 1.3, port_r * 1.6)
	var basis:= BeltPath.run_basis(centre, centre + forward)
	_splitter_probe_query.transform = Transform3D(basis, centre + basis.y * 0.3)
	if _probe_hits(_splitter_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_u_splitter() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.SPLITTER_COST):
		Audio.play("build_denied")
		return
	var at:= _u_splitter_ghost.global_position
	var yaw:= _u_splitter_ghost.global_rotation.y
	builds.add_u_splitter(at, yaw)
	Audio.play_3d("build_place", at)


func _place_u_joiner() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.JOINER_COST):
		Audio.play("build_denied")
		return
	var at:= _u_joiner_ghost.global_position
	var yaw:= _u_joiner_ghost.global_rotation.y
	builds.add_u_joiner(at, yaw)
	Audio.play_3d("build_place", at)


func _update_t_splitter_ghost() -> void:


	if _t_splitter_ghost == null:
		return
	if not is_equal_approx(_t_splitter_ghost.port_r, ConveyorTSplitter.size_in_hand()):
		_make_t_splitter_ghost()
	var ghost:= _t_splitter_ghost
	var r:= ghost.port_r
	var span:= r * 2.0
	var hit:= _surface_hit()
	if hit.is_empty():
		_eval = { "ok": false, "reason": tr("aim at ground"), "length": span,
			"cost": Cfg.T_SPLITTER_COST }
		ghost.global_position = player.eye_position() + player.look_direction() * _reach
		ghost.set_preview_valid(false)
		_ghost.visible = false
		return

	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var deck: Vector3 = (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift
	var aim:= _aim_forward()
	var centre:= deck
	var snapped:= false
	var feed:= ConveyorTSplitter.STEM

	var leaving_lane:= -1
	var yaw:= _t_yaw(aim, - ConveyorTSplitter.lane_out(feed))

	_t_stub = PackedVector3Array()
	var joint:= builds.nearest_wye_joint(deck, Cfg.SPLITTER_SNAP_RADIUS)
	if not joint.is_empty() and not bool(joint ["start"]):
		var travel: Vector3 = joint ["forward"]
		var left:= Vector3(travel.z, 0.0, - travel.x)
		var across:= aim.dot(left)
		if absf(across) > absf(aim.dot(travel)):

			feed = ConveyorTSplitter.BAR_NEG if across > 0.0 else ConveyorTSplitter.BAR_POS
		yaw = _t_yaw(travel, - ConveyorTSplitter.lane_out(feed))
		centre = (joint ["point"] as Vector3) + travel * r
		snapped = true
		if _gridding():
			var on_grid:= _grid_slide(centre, travel)
			if not on_grid.is_equal_approx(centre):
				centre = on_grid
				_t_stub = PackedVector3Array([joint ["point"], centre - travel * r])
				_t_stub_lane = feed
				_t_stub_into = true
	elif not joint.is_empty():
		var leaving: Vector3 = joint ["forward"]
		var layout:= _t_leaving_layout(leaving,
			aim.rotated(Vector3.UP, - PI * 0.5 * float(_ghost_turn)), _t_turn)
		feed = layout [0]
		var arm: int = layout [1]
		leaving_lane = arm
		yaw = _t_yaw(leaving, ConveyorTSplitter.lane_out(arm))
		centre = (joint ["point"] as Vector3) - leaving * r
		snapped = true
		if _gridding():
			var on_grid:= _grid_slide(centre, - leaving)
			if not on_grid.is_equal_approx(centre):
				centre = on_grid
				_t_stub = PackedVector3Array([centre + leaving * r,
					joint ["point"]])
				_t_stub_lane = arm
				_t_stub_into = false

	ghost.global_rotation = Vector3(0.0, yaw, 0.0)
	ghost.global_position = centre
	ghost.set_entry(feed)
	_eval = _evaluate_t_splitter(ghost, hit ["normal"], snapped)


	var mouths: Array = []
	for lane: int in ConveyorTSplitter.LANES:
		if _t_stub.size() == 2 and lane == _t_stub_lane:
			continue
		mouths.append([ghost.to_global(ghost.mouth_of(lane)),
			(ghost.global_basis * ConveyorTSplitter.lane_out(lane)).normalized()])
	_judge_wye_mouths(mouths)
	ghost.set_preview_valid(_eval ["ok"])


	var shows:= _t_flow_shows(feed, leaving_lane, not snapped)
	var show: Dictionary = shows [int(Time.get_ticks_msec() / (T_SHOW_SECONDS * 1000.0)) % shows.size()]


	_eval ["snapped"] = snapped
	_eval ["straight"] = ghost.straight_side() >= 0
	var chains: Array = []
	for lane: int in show ["in"]:
		chains.append(PackedVector3Array([_t_lane_tip(ghost, lane), centre]))
	for lane: int in show ["out"]:
		chains.append(PackedVector3Array([centre, _t_lane_tip(ghost, lane)]))
	_show_wye_flow(chains)

	if _t_stub.size() == 2:
		_ghost.multimesh.visible_instance_count = _lay_ghost(_t_stub)


const T_LEAVING_LAYOUTS: Array = [
	[ConveyorTSplitter.BAR_NEG, ConveyorTSplitter.BAR_POS],
	[ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_POS],
	[ConveyorTSplitter.BAR_POS, ConveyorTSplitter.STEM],
	[ConveyorTSplitter.BAR_POS, ConveyorTSplitter.BAR_NEG],
	[ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_NEG],
	[ConveyorTSplitter.BAR_NEG, ConveyorTSplitter.STEM],
]


static func _t_leaving_layout(leaving: Vector3, look: Vector3, turns: int) -> Array:
	var left:= Vector3(leaving.z, 0.0, - leaving.x)
	var across:= look.dot(left)
	var along:= look.dot(leaving)
	var first:= 0
	if absf(across) > absf(along):
		first = 1 if across > 0.0 else 4
	elif along < 0.0:
		first = 3
	return T_LEAVING_LAYOUTS [(first + turns) % T_LEAVING_LAYOUTS.size()]


func _make_t_splitter_ghost() -> void:
	var shown:= false
	if _t_splitter_ghost != null:
		shown = _t_splitter_ghost.visible
		_t_splitter_ghost.queue_free()
	_t_splitter_ghost = ConveyorTSplitter.new()
	_t_splitter_ghost.name = "TSplitterGhost%d" % roundi(ConveyorTSplitter.size_in_hand() * 100.0)
	_t_splitter_ghost.port_r = ConveyorTSplitter.size_in_hand()
	_t_splitter_ghost.placement_preview = true
	add_child(_t_splitter_ghost)
	_t_splitter_ghost.top_level = true
	_t_splitter_ghost.visible = shown


static func _t_flow_shows(feed: int, leaving: int, loose: bool = false) -> Array:
	var others:= func(lane: int) -> Array:
		return ConveyorTSplitter.LANES.filter(func(l: int) -> bool: return l != lane)
	var shows: Array = [{ "in": [feed], "out": others.call(feed) }]
	if loose:
		for lane: int in ConveyorTSplitter.LANES:
			shows.append({ "in": others.call(lane), "out": [lane] })
		for lane: int in others.call(feed):
			shows.append({ "in": [lane], "out": others.call(lane) })
	elif leaving < 0:
		for lane: int in others.call(feed):
			shows.append({ "in": [feed, 3 - feed - lane], "out": [lane] })
	else:
		var spare:= 3 - feed - leaving
		shows.append({ "in": [spare], "out": others.call(spare) })
		shows.append({ "in": others.call(leaving), "out": [leaving] })
	return shows


static func _t_lane_tip(t: ConveyorTSplitter, lane: int) -> Vector3:
	var out:= t.global_basis * ConveyorTSplitter.lane_out(lane)
	return t.to_global(ConveyorTSplitter.lane_mouth(lane, t.port_r)) + out * WYE_FLOW_REACH


static func _grid_slide(centre: Vector3, along: Vector3) -> Vector3:
	var axis:= Vector3.ZERO
	if absf(along.x) > 0.999:
		axis = Vector3(signf(along.x), 0.0, 0.0)
	elif absf(along.z) > 0.999:
		axis = Vector3(0.0, 0.0, signf(along.z))
	else:
		return centre
	var on_x:= absf(axis.x) > 0.5
	var w: float = centre.x if on_x else centre.z
	var dir: float = axis.x if on_x else axis.z
	var step:= Cfg.BUILD_GRID_STEP


	var across: float = centre.z if on_x else centre.x
	if absf(snappedf(across, step) - across) > 0.001:
		return centre
	if absf(snappedf(w, step) - w) < 0.001:
		return centre
	var target:= (ceilf(w / step - 0.0001) if dir > 0.0 else floorf(w / step + 0.0001)) * step
	return centre + axis * absf(target - w)


func _t_stub_cost() -> float:
	return Conveyor.cost_for(_t_stub [0], _t_stub [1]) if _t_stub.size() == 2 else 0.0


func _lay_t_stub(t: ConveyorTSplitter) -> void:
	if _t_stub.size() != 2 or t == null:
		return
	var mouth:= t.to_global(t.mouth_of(_t_stub_lane))
	if _t_stub_into:
		builds.add_conveyor(_t_stub [0], mouth)
	else:
		builds.add_conveyor(mouth, _t_stub [1])
	_t_stub = PackedVector3Array()


static func _t_yaw(world_dir: Vector3, local_dir: Vector3) -> float:
	return atan2(world_dir.x, world_dir.z) - atan2(local_dir.x, local_dir.z)


func _evaluate_t_splitter(ghost: ConveyorTSplitter, normal: Vector3,
		snapped: bool) -> Dictionary:
	var centre:= ghost.global_position


	var cost:= Cfg.T_SPLITTER_COST + _t_stub_cost()
	var result:= { "ok": false, "reason": "", "length": ghost.port_r * 2.0,
		"cost": cost }
	if not snapped and normal.dot(Vector3.UP) < 0.72:
		result ["reason"] = tr("surface too steep")
		return result
	if not GameState.can_afford(cost):
		result ["reason"] = tr("need %s") % _price(cost)
		return result
	if builds.wye_overlap(ghost.footprint(), ghost):
		result ["reason"] = tr("too close to another module")
		return result
	var forward:= ghost.forward()


	const MOUTH_GAP:= 0.3
	const HEIGHT:= 1.2
	var near:= ghost.port_r - MOUTH_GAP
	var reach:= near + ConveyorTSplitter.JUNCTION_HALF
	_splitter_probe.size = Vector3(Cfg.BELT_WIDTH + 0.1, HEIGHT, reach)
	var mid:= centre - forward * ((near - ConveyorTSplitter.JUNCTION_HALF) * 0.5)
	var basis:= BeltPath.run_basis(mid, mid + forward)
	_splitter_probe_query.transform = Transform3D(basis,
		mid + basis.y * (Cfg.BUILD_FOOT_CLEAR + HEIGHT * 0.5))
	if _probe_hits(_splitter_probe_query):
		result ["reason"] = tr("blocked")
		return result
	result ["ok"] = true
	return result


func _place_t_splitter() -> void:
	if not _eval ["ok"]:
		Audio.play("build_denied")
		return
	if not _pay(Cfg.T_SPLITTER_COST + _t_stub_cost()):
		Audio.play("build_denied")
		return
	var at:= _t_splitter_ghost.global_position
	var yaw:= _t_splitter_ghost.global_rotation.y
	_lay_t_stub(builds.add_t_splitter(at, yaw, _t_splitter_ghost.entry,
		_t_splitter_ghost.port_r))
	Audio.play_3d("build_place", at)


func _aim_point() -> Vector3:
	var raw:= _surface_point(Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR)


	if _snap_off:
		_joined = false
		return raw

	var snapped:= builds.snap_endpoint(raw, null,
		_anchor if _state == State.RUNNING else Vector3.INF)
	_joined = not snapped.is_equal_approx(raw)
	return snapped


func _guided(anchor: Vector3, point: Vector3) -> Vector3:
	_guide_turn = NAN
	if _joined:
		return point
	var flat:= Vector2(point.x - anchor.x, point.z - anchor.z)
	var run:= flat.length()


	if run < Cfg.BELT_MIN_LENGTH * 0.5:
		return point


	var incoming:= builds.feed_run_into(anchor)
	if incoming == null:
		return point
	var heading:= atan2(flat.x, flat.y)
	var origin:= atan2(incoming.forward.x, incoming.forward.z)
	var best: float = origin + roundf((heading - origin) / Cfg.BELT_GUIDE_STEP) * Cfg.BELT_GUIDE_STEP
	if absf(angle_difference(heading, best)) > Cfg.BELT_GUIDE_WINDOW:
		return point
	_guide_turn = angle_difference(origin, best)


	return Vector3(anchor.x + sin(best) * run, point.y, anchor.z + cos(best) * run)


func _surface_point(lift: float) -> Vector3:
	var hit:= _surface_hit()
	if hit.is_empty():
		var air:= player.eye_position() + player.look_direction() * _reach


		if not _gridding():
			return air


		var snapped:= air.snapped(Vector3.ONE * Cfg.BUILD_GRID_STEP)
		snapped.y = snappedf(air.y - lift, Cfg.BUILD_GRID_STEP) + lift
		return snapped
	return (hit ["position"] as Vector3) + (hit ["normal"] as Vector3) * lift


func can_turn() -> bool:
	return _is_roof(_mode) or _mode in TURNABLE


func _aim_forward(fallback: Vector3 = Vector3.BACK) -> Vector3:
	var look:= player.look_direction()
	look.y = 0.0
	var forward:= look.normalized() if look.length_squared() > 1e-06 else fallback


	if _gridding():
		var yaw:= roundf(atan2(forward.x, forward.z) / (PI * 0.5)) * PI * 0.5
		forward = Vector3(sin(yaw), 0.0, cos(yaw))
	if _ghost_turn == 0:
		return forward
	return forward.rotated(Vector3.UP, PI * 0.5 * float(_ghost_turn)).normalized()


func _surface_hit() -> Dictionary:
	var hit:= _raw_surface_hit()
	if hit.is_empty() or not _gridding():
		return hit
	return _grid_hit(hit)


func _raw_surface_hit() -> Dictionary:
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * _reach)
	q.collision_mask = Cfg.BUILD_SURFACE_MASK
	q.collide_with_areas = false
	var hit:= get_world_3d().direct_space_state.intersect_ray(q)


	var body:= hit.get("collider") as Node
	if body != null and body.get_parent() is DeliveryTruck:
		return { }
	return hit


func _gridding() -> bool:
	return _grid_on and _mode in GRIDDED


func _levelling() -> bool:
	return _grid_on and _mode in LEVELLED


func snaps_to_grid() -> bool:
	return _mode in GRIDDED or _mode in LEVELLED


func grid_snapping() -> bool:
	return _grid_on


func can_stop_snapping() -> bool:
	return _is_conveyor_mode() or not _seat_spec(_mode).is_empty()


func belt_in_hand() -> bool:
	return _is_conveyor_mode()


func _is_conveyor_mode() -> bool:
	return _mode == Mode.CONVEYOR or _mode == Mode.ENCLOSED_CONVEYOR


func _fit_run_ghost_mesh() -> void:
	if _ghost == null or _ghost.multimesh == null:
		return
	var want: Mesh = ConveyorKit.segment_mesh()
	if _mode == Mode.ENCLOSED_CONVEYOR:
		if _enclosed_section == null:
			_enclosed_section = EnclosedConveyorKit.new().mesh("Section")
		if _enclosed_section != null:
			want = _enclosed_section
	if _ghost.multimesh.mesh != want:
		_ghost.multimesh.mesh = want


func snap_stopped() -> bool:
	return _snap_off and can_stop_snapping()


func _grid_hit(hit: Dictionary) -> Dictionary:
	var at: Vector3 = hit ["position"]
	var on:= Vector3(snappedf(at.x, Cfg.BUILD_GRID_STEP), at.y,
		snappedf(at.z, Cfg.BUILD_GRID_STEP))
	if on.is_equal_approx(at):
		return hit
	return _column_hit(hit, on)


func _column_hit(hit: Dictionary, on: Vector3) -> Dictionary:
	var at: Vector3 = hit ["position"]
	var off:= Vector3(at.x - on.x, 0.0, at.z - on.z)
	var cast:= on
	if off.length_squared() > 1e-08:
		cast += off.normalized() * minf(0.003, off.length())
	var q:= PhysicsRayQueryParameters3D.create(
		cast + Vector3.UP * Cfg.BUILD_GRID_PROBE,
		cast + Vector3.DOWN * Cfg.BUILD_GRID_PROBE)
	q.collision_mask = Cfg.BUILD_SURFACE_MASK
	q.collide_with_areas = false
	var under:= get_world_3d().direct_space_state.intersect_ray(q)
	if not under.is_empty():
		var p: Vector3 = under ["position"]
		under ["position"] = Vector3(on.x, p.y, on.z)
		if under.get("collider") is Platform:
			under ["normal"] = Vector3.UP
		return under
	var out:= hit.duplicate()
	out ["position"] = on
	return out


func _evaluate(from: Vector3, to: Vector3, priced: bool) -> Dictionary:
	var length:= from.distance_to(to)


	var cost:= _run_cost(from, to)
	var r:= { "ok": false, "reason": "", "length": length, "cost": cost }


	var taken:= _joint_taken(from, true)
	if taken == "" and priced:
		taken = _joint_taken(to, false)
	if taken != "":
		r ["reason"] = taken
		return r
	if priced:


		var wrong_door:= _wrong_side_reason(from, to)
		if wrong_door != "":
			r ["reason"] = wrong_door
			return r
		var shape:= _leg_shape_reason(from, to, length)
		if shape != "":
			r ["reason"] = shape
			if shape == tr("too short"):
				r ["need"] = _shortest_leg(from, to)
			return r
		if _doubles_back(_port_knees(from, to)):
			var side:= _wrong_side_reason(from, to)
			r ["reason"] = side if side != "" else tr("turn further off the belt")
			return r
		if _mode == Mode.ENCLOSED_CONVEYOR and _bends_short_piece(_port_knees(from, to)):
			r ["reason"] = tr("too short")
			return r
		if not GameState.can_afford(cost):
			r ["reason"] = tr("need %s") % _price(cost)
			return r
	elif not GameState.can_afford(_belt_cost_for(Vector3.ZERO,
			Vector3(Cfg.BELT_MIN_LENGTH, 0.0, 0.0))):
		r ["reason"] = tr("no funds")
		return r
	else:


		r ["ok"] = true
		return r
	var clear:= _run_clear_reason(from, to)
	if clear != "":
		r ["reason"] = clear
		return r
	r ["ok"] = true
	return r


func _run_clear_reason(from: Vector3, to: Vector3) -> String:
	_run_blocker = ""
	var pts:= _port_knees(from, to)
	var why:= _legs_clear_reason(pts)
	if why == tr("blocked"):
		for i in pts.size() - 1:
			var length:= pts [i].distance_to(pts [i + 1])
			if length < 0.01:
				continue
			_bare_knees = _knees_of(pts)
			var hit:= _obstruction(pts [i], pts [i + 1], length)
			_bare_knees = PackedVector3Array()
			if hit is Node:
				_run_blocker = builds.name_of(builds.owner_of(hit as Node))
				break
	return why


func _legs_clear_reason(pts: PackedVector3Array) -> String:
	_bare_knees = _knees_of(pts)
	var out:= ""
	for i in pts.size() - 1:
		var length:= pts [i].distance_to(pts [i + 1])
		if length < 0.01:
			continue
		out = _leg_clear_reason(pts [i], pts [i + 1], length)
		if out != "":
			break
	_bare_knees = PackedVector3Array()
	return out


static func _knees_of(pts: PackedVector3Array) -> PackedVector3Array:
	var out:= PackedVector3Array()
	var first:= pts [0]
	var last:= pts [pts.size() - 1]
	for i in range(1, pts.size() - 1):
		if not pts [i].is_equal_approx(first) and not pts [i].is_equal_approx(last):
			out.append(pts [i])
	return out


func _leg_shape_reason(from: Vector3, to: Vector3, length: float) -> String:
	if length < _shortest_leg(from, to):
		return tr("too short")
	if length > Cfg.BELT_MAX_LENGTH:
		return tr("too long")
	if asin(clampf(absf(to.y - from.y) / maxf(length, 1e-06), 0.0, 1.0)) > Cfg.BELT_MAX_SLOPE:
		return tr("too steep")
	return ""


func _shortest_leg(from: Vector3, to: Vector3) -> float:
	if _mode == Mode.ENCLOSED_CONVEYOR and not _door_bridge(from, to):
		return Cfg.ENCLOSED_BELT_MIN_LENGTH
	return Cfg.BELT_MIN_LENGTH


func _door_bridge(from: Vector3, to: Vector3) -> bool:
	if builds == null or from.distance_to(to) < 0.0001:
		return false
	var along:= (to - from).normalized()
	for bearing: Vector3 in [builds.port_bearing_at(from), builds.port_bearing_at(to)]:
		if bearing == Vector3.ZERO or bearing.angle_to(along) > Cfg.BELT_CORNER_MIN_TURN:
			return false
	return true


func _bends_short_piece(pts: PackedVector3Array) -> bool:
	if builds == null or pts.size() < 2:
		return false
	var first:= pts [0]
	var last:= pts [pts.size() - 1]
	var leaving:= Vector3.ZERO
	var arriving:= Vector3.ZERO
	for i in pts.size() - 1:
		if pts [i].distance_to(pts [i + 1]) > 0.0001:
			if leaving == Vector3.ZERO:
				leaving = (pts [i + 1] - pts [i]).normalized()
			arriving = (pts [i + 1] - pts [i]).normalized()
	if leaving == Vector3.ZERO:
		return false
	for c in builds.conveyors:
		if not (c is EnclosedConveyor) or not is_instance_valid(c) or c.a.distance_to(c.b) >= Cfg.ENCLOSED_BELT_MIN_LENGTH - 0.001:
			continue
		var its:= (c.b - c.a).normalized()
		if PointIndex.joins(c.b, first) and its.angle_to(leaving) > Cfg.BELT_CORNER_MIN_TURN:
			return true
		if PointIndex.joins(c.a, last) and its.angle_to(arriving) > Cfg.BELT_CORNER_MIN_TURN:
			return true
	return false


func _leg_clear_reason(from: Vector3, to: Vector3, length: float) -> String:


	var wall:= _obstruction(from, to, length)
	if wall != null:
		return tr("turn further off the belt") if _joint_neighbour(wall, from, to) else tr("blocked")


	if _in_pile(from, to, length):
		return tr("in the hay")
	if _on_belt(from, to, length):
		return tr("on a belt")
	return ""


static func _price(v: float) -> String:
	return "$%s" % Hud.money_text(v)


func _blocked(from: Vector3, to: Vector3, length: float) -> bool:
	return _obstruction(from, to, length) != null


func _obstruction(from: Vector3, to: Vector3, length: float) -> Object:
	var h:= Cfg.BELT_RAIL_H
	var dir:= (to - from) / maxf(length, 1e-06)
	var near:= from + dir * _end_slack(from)
	var far:= to - dir * _end_slack(to)
	var span:= (far - near).dot(dir)


	if span < 0.15:
		near = (from + to) * 0.5 - dir * 0.075
		span = 0.15
	_probe.size = Vector3(Cfg.BELT_WIDTH * Cfg.BUILD_CLEARANCE_SHRINK, h, span)
	var basis:= BeltPath.run_basis(from, to)
	var mid:= near + dir * (span * 0.5) + basis.y * (Cfg.BUILD_FOOT_CLEAR + h * 0.5)
	_probe_query.transform = Transform3D(basis, mid)
	return _probe_obstruction(_probe_query)


const PROBE_MAX_HITS:= 32


func _probe_obstruction(query: PhysicsShapeQueryParameters3D) -> Object:
	var hits:= get_world_3d().direct_space_state.intersect_shape(query, PROBE_MAX_HITS)
	var hay: Object = null
	for hit in hits:
		var col: Object = hit ["collider"]
		if col is Node and (col as Node).has_meta("hay_chunk"):
			if hay == null:
				hay = col
			continue
		if col is Node and (col as Node).has_meta(Warehouse.SHELL_META):
			_shed_hit = true
		return col
	if hay != null and _hay_under_probe(query) > Cfg.THIN_HAY:
		return hay
	return null


func _probe_hits(query: PhysicsShapeQueryParameters3D) -> bool:
	return _probe_obstruction(query) != null


func _deck_room_blocked(query: PhysicsShapeQueryParameters3D, top_y: float) -> bool:
	var skip: Array [RID] = []
	var blocked:= true
	for _i in 8:
		query.exclude = skip
		var hit:= _probe_obstruction(query)
		if hit == null:
			blocked = false
			break
		var body:= hit as CollisionObject3D


		var lift: HayLift = null
		var up: Node = body.get_parent() if body != null else null
		while up != null and lift == null:
			lift = up as HayLift
			up = up.get_parent()
		if lift == null or not lift.hull_over(body, top_y):
			break
		skip.append(body.get_rid())
	query.exclude = []
	return blocked


func _hay_under_probe(query: PhysicsShapeQueryParameters3D) -> float:
	var field: HayField = builds.field if builds != null else null
	if field == null:
		return 0.0
	var shape:= query.shape
	var half:= Vector2.ZERO
	var round_footprint:= false
	if shape is BoxShape3D:
		var size:= (shape as BoxShape3D).size
		half = Vector2(size.x, size.z) * 0.5
	elif shape is CylinderShape3D:
		var r:= (shape as CylinderShape3D).radius
		half = Vector2(r, r)
		round_footprint = true
	else:
		return INF
	var xf:= query.transform
	var nx:= maxi(2, int(ceil(half.x * 2.0 / Cfg.CELL)) + 1)
	var nz:= maxi(2, int(ceil(half.y * 2.0 / Cfg.CELL)) + 1)
	var tallest:= 0.0
	for a in nx:
		for b in nz:
			var local:= Vector3(
				lerpf(- half.x, half.x, float(a) / float(nx - 1)), 0.0,
				lerpf(- half.y, half.y, float(b) / float(nz - 1)))
			if round_footprint and Vector2(local.x, local.z).length() > half.x:
				continue
			var p:= xf * local
			tallest = maxf(tallest, field.height_at(p.x, p.z))
	return tallest


func _end_slack(at: Vector3) -> float:


	for knee in _bare_knees:
		if knee.is_equal_approx(at):
			return 0.0
	if builds != null and (builds.feed_run_into(at) != null
			or builds.run_out_of(at) != null):
		return Cfg.BELT_JOIN_SLACK


	if builds != null and builds.t_mouth_out(at) != Vector3.ZERO:
		return Cfg.BELT_JOIN_SLACK
	return Cfg.BUILD_END_SLACK


func _joint_taken(at: Vector3, leaving: bool) -> String:
	if builds == null:
		return ""


	if builds.wye_mated_at(at):
		return tr("already joined here  ·  use a splitter to branch") if leaving else tr("already joined here  ·  use a joiner to merge")


	var feeds:= builds.runs_ending_at(at).size()
	var outs:= builds.runs_starting_at(at).size()
	if leaving and (outs > 0 or feeds > 1):
		return tr("already joined here  ·  use a splitter to branch")
	if not leaving and (feeds > 0 or outs > 1):
		return tr("already joined here  ·  use a joiner to merge")
	return ""


func _joint_neighbour(hit: Object, from: Vector3, to: Vector3) -> bool:
	var node:= hit as Node
	while node != null:
		var run:= node as Conveyor
		if run != null:
			return run.a.is_equal_approx(from) or run.a.is_equal_approx(to) or run.b.is_equal_approx(from) or run.b.is_equal_approx(to)
		var bend:= node as ConveyorCorner
		if bend != null:
			return bend.apex.is_equal_approx(from) or bend.apex.is_equal_approx(to)
		node = node.get_parent()
	return false


const MAX_TURN_COS:= -0.17


func _wrong_side_reason(from: Vector3, to: Vector3) -> String:
	if builds == null:
		return ""
	var dir:= Vector2(to.x - from.x, to.z - from.z)
	if dir.length_squared() < 1e-08:
		return ""
	dir = dir.normalized()
	for at: Vector3 in [to, from]:
		if builds.t_mouth_out(at) != Vector3.ZERO:
			continue
		var bearing:= builds.port_bearing_at(at)
		var plan:= Vector2(bearing.x, bearing.z)
		if plan.length_squared() > 1e-08 and plan.normalized().dot(dir) < MAX_TURN_COS:
			return tr("wrong side  ·  hay goes the other way here")
	return ""


func _doubles_back(pts: PackedVector3Array) -> bool:
	if builds == null or pts.size() < 2:
		return false
	var dirs: Array [Vector3] = []
	var feed:= builds.feed_run_into(pts [0])
	if feed != null:
		dirs.append(feed.forward)
	for i in pts.size() - 1:
		if not pts [i].is_equal_approx(pts [i + 1]):
			dirs.append(pts [i + 1] - pts [i])
	var out:= builds.run_out_of(pts [pts.size() - 1])
	if out != null:
		dirs.append(out.forward)
	for i in dirs.size() - 1:
		var a:= Vector2(dirs [i].x, dirs [i].z)
		var b:= Vector2(dirs [i + 1].x, dirs [i + 1].z)
		if a.length_squared() < 1e-08 or b.length_squared() < 1e-08:
			continue
		if a.normalized().dot(b.normalized()) < MAX_TURN_COS:
			return true
	return false


func _on_belt(from: Vector3, to: Vector3, length: float) -> bool:
	if builds == null:
		return false
	var dir:= (to - from) / maxf(length, 1e-06)
	var near:= from + dir * _end_slack(from)
	var span:= (to - dir * _end_slack(to) - near).dot(dir)
	if span <= 0.0:
		return false
	var mid:= near + dir * (span * 0.5)
	var steps:= maxi(2, int(ceil(span / Cfg.BELT_STACK_STEP)))
	for c in builds.conveyors:
		if not is_instance_valid(c) or c.length < 0.0001:
			continue


		var reach:= (c.length + span) * 0.5 + Cfg.BELT_STACK_CLEAR
		if ((c.a + c.b) * 0.5).distance_to(mid) > reach:
			continue


		var a:= c.a
		var b:= c.b
		if a.is_equal_approx(from) or a.is_equal_approx(to):
			a += c.forward * Cfg.BELT_JOIN_SLACK
		if b.is_equal_approx(from) or b.is_equal_approx(to):
			b -= c.forward * Cfg.BELT_JOIN_SLACK
		if _over_deck(near, dir, span, steps, a, b, c.forward):
			return true


	return _on_machine_deck(from, to, near, dir, span, steps, mid)


func _on_machine_deck(from: Vector3, to: Vector3, near: Vector3, dir: Vector3,
		span: float, steps: int, mid: Vector3) -> bool:
	for deck in BeltPath.machine_decks():
		if not is_instance_valid(deck):
			continue
		var line:= deck.centre_line()
		for i in line.size() - 1:
			var a:= line [i]
			var b:= line [i + 1]
			var seg:= b - a
			var seg_len:= seg.length()
			if seg_len < 0.0001:
				continue


			var reach:= (seg_len + span) * 0.5 + Cfg.BELT_STACK_CLEAR
			if ((a + b) * 0.5).distance_to(mid) > reach:
				continue
			var fwd:= seg / seg_len
			if i == 0 and (a.is_equal_approx(from) or a.is_equal_approx(to)):
				a += fwd * Cfg.BELT_JOIN_SLACK
			if i == line.size() - 2 and (b.is_equal_approx(from) or b.is_equal_approx(to)):
				b -= fwd * Cfg.BELT_JOIN_SLACK
			if _over_deck(near, dir, span, steps, a, b, fwd):
				return true
	return false


func _over_deck(near: Vector3, dir: Vector3, span: float, steps: int,
		a: Vector3, b: Vector3, fwd: Vector3) -> bool:
	var half:= (b - a).dot(fwd) * 0.5
	if half <= 0.0:
		return false
	var centre:= (a + b) * 0.5
	for i in steps + 1:
		var p:= near + dir * (span * float(i) / float(steps))
		var off:= p - centre
		var along:= off.dot(fwd)


		if absf(along) > half:
			continue
		if absf(off.y - fwd.y * along) >= Cfg.BELT_STACK_HEIGHT:
			continue
		var lateral:= off - fwd * along
		if Vector2(lateral.x, lateral.z).length() < Cfg.BELT_STACK_CLEAR:
			return true
	return false


func _in_pile(from: Vector3, to: Vector3, length: float) -> bool:
	var field: HayField = builds.field if builds != null else null
	if field == null:
		return false
	var slack:= minf(Cfg.BUILD_END_SLACK, length * 0.4)
	var span:= length - slack * 2.0
	if span <= 0.0:
		return false
	var dir:= (to - from) / maxf(length, 1e-06)
	var steps:= maxi(2, int(ceil(span / Cfg.BUILD_PILE_STEP)))
	for i in steps + 1:
		var p:= from + dir * (slack + span * float(i) / float(steps))
		if field.height_at(p.x, p.z) - p.y > Cfg.BUILD_PILE_BED:
			return true
	return false


func _shape_ghost(from: Vector3, to: Vector3) -> void:
	var points:= _preview_points(from, to)


	_ghost.global_transform = Transform3D()
	_ghost.multimesh.visible_instance_count = _lay_ghost(points)
	_drop_ghost_drums(points, from, to)
	_ghost.material_override = ConveyorKit.ghost_material(_eval ["ok"])
	_shape_flow(points)


func _preview_points(from: Vector3, to: Vector3) -> PackedVector3Array:
	var straight:= PackedVector3Array([from, to])
	if builds == null:
		return straight
	var length:= from.distance_to(to)
	if length < 0.0001:
		return straight


	var knees:= _port_knees(from, to)
	var near:= knees [1]
	var far:= knees [2]


	var near_stub:= from.distance_to(near)
	var far_stub:= to.distance_to(far)
	length = near.distance_to(far)
	if length < 0.0001:
		return straight
	var forward:= (far - near) / length

	var out:= PackedVector3Array()
	var used:= 0.0

	var incoming: Conveyor = builds.feed_run_into(from) if _state == State.RUNNING and near == from else null
	if near != from:
		var tail:= (near - from) / near_stub
		out.append(from)
		var nt:= BuildManager.corner_tangent(tail, near_stub, forward, length)
		if nt > 0.0:
			out.append_array(_bend(near - tail * nt, near, near + forward * nt,
				tail.angle_to(forward)))
			used = nt
		else:
			out.append(near)

	elif incoming != null:
		var t:= BuildManager.corner_tangent(incoming.forward, incoming.length,
			forward, length)
		if t > 0.0:
			out.append_array(_bend(from - incoming.forward * t, from,
				from + forward * t, incoming.forward.angle_to(forward)))
			used = t
	if out.is_empty():
		out.append(from)

	var outgoing: Conveyor = builds.run_out_of(to) if _state == State.RUNNING and far == to else null
	var rounded_head:= false
	if far != to:


		var head:= (to - far) / far_stub
		var ft:= BuildManager.corner_tangent(forward, maxf(length - used, 0.01),
			head, far_stub)
		if ft > 0.0:
			out.append_array(_bend(far - forward * ft, far, far + head * ft,
				forward.angle_to(head)))
		else:
			out.append(far)


	elif outgoing != null:
		var ht:= BuildManager.corner_tangent(forward, maxf(length - used, 0.01),
			outgoing.forward, outgoing.length)
		if ht > 0.0:
			out.append_array(_bend(to - forward * ht, to,
				to + outgoing.forward * ht, forward.angle_to(outgoing.forward)))
			rounded_head = true
	if not rounded_head:
		out.append(to)
	return out


func _bend(tail: Vector3, apex: Vector3, head: Vector3, turn: float) -> PackedVector3Array:
	var steps:= clampi(int(ceil(turn / Cfg.BELT_CORNER_STEP)), 2, 12)
	var out:= ConveyorCorner.arc_points(
		ConveyorCorner.arc_of(tail, apex, head), tail, head, steps)
	return out


func _lay_ghost(points: PackedVector3Array, from:= 0) -> int:
	var mm:= _ghost.multimesh
	var n:= from
	if from == 0:
		_ghost_drum_ends.clear()
	if points.size() >= 2:
		var last:= points.size() - 1
		var tail:= BeltPath.run_basis(points [0], points [1])
		_ghost_drum_ends.append([false, points [0], tail.rotated(tail.y, PI)])
		_ghost_drum_ends.append([true, points [last],
			BeltPath.run_basis(points [last - 1], points [last])])
	for i in points.size() - 1:
		var a:= points [i]
		var b:= points [i + 1]
		var span:= a.distance_to(b)
		if span < 0.0001:
			continue
		var pieces:= clampi(maxi(1, int(round(span / Cfg.BELT_SEGMENT))),
			1, GHOST_CAPACITY)
		var seg:= span / pieces
		var basis:= BeltPath.run_basis(a, b)
		var scale:= Vector3(1.0, 1.0, seg / Cfg.BELT_SEGMENT)


		var railed:= span >= BeltPath.RAIL_MIN_PIECE
		for k in pieces:
			if n >= GHOST_CAPACITY:
				return n
			var xf:= Transform3D(basis.scaled_local(scale),
				a.lerp(b, (seg * (k + 0.5)) / span))
			mm.set_instance_transform(n, xf)
			var rail_xf:= xf if railed else Transform3D(Basis().scaled(Vector3.ZERO), xf.origin)
			for rail in _ghost_rails:
				rail.multimesh.set_instance_transform(n, rail_xf)
			n += 1
	return n


func _shape_flow(points: PackedVector3Array) -> void:
	_shape_flow_many([points], ARROW_PITCH)


func _shape_flow_many(chains: Array, pitch_nominal: float) -> void:
	_fill_flow(_flow.multimesh, chains, pitch_nominal, ARROW_LIFT, Color(1, 1, 1, 1))


func _fill_flow(mm: MultiMesh, chains: Array, pitch_nominal: float, lift: float,
		tint: Color, face_from: Vector3 = Vector3.INF,
		alphas: PackedFloat32Array = PackedFloat32Array()) -> void:
	var capacity:= mm.instance_count
	var used:= 0
	for c in chains.size():
		var points: PackedVector3Array = chains [c]
		var alpha:= tint.a * (alphas [c] if c < alphas.size() else 1.0)
		var total:= 0.0
		for i in points.size() - 1:
			total += points [i].distance_to(points [i + 1])
		if total < 0.0001:
			continue


		var room:= capacity - used
		if room <= 0:
			break
		var n:= clampi(maxi(1, int(round(total / pitch_nominal))), 1, room)
		var pitch:= total / n
		var phase:= fmod(_flow_phase, pitch)
		for i in n:


			var along:= fmod(i * pitch + phase, total)
			var at:= _walk(points, along)
			var basis: Basis = at ["basis"]
			var centre:= (at ["point"] as Vector3) + basis.y * lift
			if face_from.is_finite():
				basis = _roll_to_face(basis, centre, face_from)
			mm.set_instance_transform(used + i, Transform3D(basis, centre))
			var fade:= (clampf(along / ARROW_FADE, 0.0, 1.0)
				* clampf((total - along) / ARROW_FADE, 0.0, 1.0))
			mm.set_instance_color(used + i, Color(tint.r, tint.g, tint.b, alpha * fade))
		used += n
	mm.visible_instance_count = used


static func _roll_to_face(basis: Basis, at: Vector3, eye: Vector3) -> Basis:
	var fwd:= basis.z
	var to_eye:= eye - at
	var up:= to_eye - fwd * to_eye.dot(fwd)
	if up.length_squared() < 1e-06:
		return basis
	up = up.normalized()
	return Basis(up.cross(fwd), up, fwd)


func _walk(points: PackedVector3Array, along: float) -> Dictionary:
	var left:= maxf(along, 0.0)
	for i in points.size() - 1:
		var a:= points [i]
		var b:= points [i + 1]
		var span:= a.distance_to(b)
		if span < 0.0001:
			continue
		if left <= span or i == points.size() - 2:
			return { "point": a.lerp(b, clampf(left / span, 0.0, 1.0)),
				"basis": BeltPath.run_basis(a, b) }
		left -= span
	return { "point": points [0], "basis": Basis() }
