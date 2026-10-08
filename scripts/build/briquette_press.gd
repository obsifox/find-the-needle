class_name BriquettePress
extends Node3D


const MODEL:= "res://assets/models/briquette_press.glb"


const SPEC:= "res://assets/models/briquette_press_materials.json"


const N_PORT_WAD:= "Port_Bale"
const N_PORT_BRICK:= "Port_Hay"
const N_PORT_DISC:= "Port_Output"
const N_CLIP_SPOUT:= "Mill_SpoutRun"
const N_CLIP_FALL:= "Mill_PelletFall"
const N_CLIP_MILL_BED:= "Mill_BedRun"
const N_CLIP_CHAFF:= "Grind_ChaffFall"
const N_CLIP_GRIND_BED:= "Grind_BedRun"
const N_CLIP_GRIND_TURN:= "Grind_BedTurn"
const N_CLIP_CHARGE:= "Press_Charge"
const N_CLIP_DISC:= "Press_Disc"


const N_MILL_FLOW: Array [String] = [N_CLIP_SPOUT, N_CLIP_FALL, N_CLIP_MILL_BED]
const N_GRIND_FLOW: Array [String] = [N_CLIP_CHAFF, N_CLIP_GRIND_BED,
	N_CLIP_GRIND_TURN]

const N_RAM:= "Press_Ram"


const SIDE_GRIND:= 0
const SIDE_MILL:= 1


const ROAD_PIECES: Array [Array] = [
	[N_CLIP_FALL, SIDE_MILL, Vector3(0.0, 1.91, -2.33), Vector3(0.0, -1.0, 0.0), 0.0],
	[N_CLIP_SPOUT, SIDE_MILL, Vector3(0.0, 1.335, -2.15), Vector3(0.0, -0.652, 0.758), 0.5],
	[N_CLIP_MILL_BED, SIDE_MILL, Vector3(0.0, 1.0, -1.8), Vector3(0.0, 0.0, 1.0), 0.96],
	[N_CLIP_CHAFF, SIDE_GRIND, Vector3(-1.16, 1.0, -1.0), Vector3(1.0, 0.0, 0.0), 0.0],
	[N_CLIP_GRIND_BED, SIDE_GRIND, Vector3(-1.16, 1.0, -1.0), Vector3(1.0, 0.0, 0.0), 0.0],
	[N_CLIP_GRIND_TURN, SIDE_GRIND, Vector3(0.0, 1.0, -0.86), Vector3(0.0, 0.0, 1.0), 1.3],
]


const ROAD_END: Array [float] = [1.72, 2.32]


const ROAD_OVERRUN:= 0.45


const ROAD_SPEED:= Cfg.BELT_SPEED


const ROAD_SOURCE_SPIN:= 0.5


const ROAD_OPEN:= 10.0

const ROAD_SEGMENTS:= 2

const ROAD_NONE:= Vector2(1000.0, -1000.0)
const ROAD_SHADER:= "res://assets/flow_road.gdshader"


const CLIP_GRIND:= "Grind"
const CLIP_MILL:= "Mill"
const CLIP_PRESS:= "PressCycle"


const CYCLE_FRAMES:= 121.0
const CLIP_FPS:= 30.0


const F_RELEASE:= 119.0


const F_FORMED:= 78.0


const WAD_IN_X:= -1.73
const BRICK_IN_Z:= -1.39
const DISC_HEAD_Z:= 0.58


const WAD_MOUTH_X:= -1.8
const BRICK_MOUTH_Z:= -3.35


const DISC_SPOT_Z:= 0.98


const WAD_MOUTH_LENGTH:= 1.1
const BRICK_MOUTH_LENGTH:= 0.85


const PORT_REACH:= [0.4, 0.1, 0.3]
const REACH_WAD:= 0
const REACH_BRICK:= 1
const REACH_DISC:= 2
const MOUTH_HEIGHT:= 0.6

const ARROW_PITCH:= 0.8
const ARROW_LIFT:= 0.06
const ARROW_FADE:= 0.45
const ARROW_CAPACITY:= 8
const ARROW_SPEED:= 0.9

const SUPPORT_HALF_WIDTH:= Cfg.BELT_SUPPORT_HALF_WIDTH


const GRIND_LOOP:= "motor_b"
const MILL_LOOP:= "motor_a"
const LOOP_DB:= -14.0
const LOOP_SILENT:= -80.0
const LOOP_RAMP:= 140.0
const LOOP_HEIGHT:= 1.4


signal pressed(disc: FeedDisc)


signal pressed_record(seq: int)


var props: PropManager


var live: LiveStrandManager
var placement_preview:= false


var stored_strands:= 0
var stored_bricks:= 0


var brick_hay:= PackedInt32Array()


var brick_worth:= PackedFloat32Array()


var pending_needles:= PackedInt32Array()


var port_reach: Array = PORT_REACH.duplicate()

var starved_for:= 0.0


func held_needles() -> PackedInt32Array:
	return pending_needles


var _model: Node3D

var _bed_surfaces: Array = []
var _bed_held:= false
var _body: StaticBody3D

var _grind_anim: AnimationPlayer
var _mill_anim: AnimationPlayer
var _press_anim: AnimationPlayer


var _flow: Dictionary = { }

var _wad_belt: BeltPath
var _brick_belt: BeltPath
var _out_belt: BeltPath
var _wad_mouth: Area3D
var _brick_mouth: Area3D
var _supports: Node3D
var _drums: Node3D
var _ghost_belt: BeltGhost
var _ghost_flow: MultiMeshInstance3D
var _flow_phase:= 0.0
var _ports: Array [Node3D] = []


var _run:= -1.0
var _released:= false


var _cracked:= false


var _batch_strands:= 0
var _batch_bricks:= 0

var _batch_brick_hay:= 0

var _batch_brick_worth:= 0.0
var _cycle:= Cfg.BRIQUETTE_CYCLE_SECONDS


var _charge_drawn:= 0.0

var _hay_share:= 0.0
var _pellet_share:= 0.0


var _stroke_lump:= 0.0


var _stroke_low:= INF


var _roads: Array = [[], []]

var _road_xform:= Transform3D()


var _grind_spin:= 0.0
var _mill_spin:= 0.0

var _grind_voice:= -1
var _grind_gain:= LOOP_SILENT
var _grind_target:= LOOP_SILENT
var _mill_voice:= -1
var _mill_gain:= LOOP_SILENT
var _mill_target:= LOOP_SILENT

var _room_probe: BoxShape3D
var _room_query: PhysicsShapeQueryParameters3D

static var _spec_cache: Dictionary = { }


static var _clip_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_build_collider()
	_skin()
	_build_animation()
	if placement_preview:
		set_physics_process(false)
		_build_ghost_belt()
		set_preview_valid(true)
		return
	set_process(false)


	FactoryClock.join(self)
	_build_belts()
	_refresh_drums()
	_build_mouths()
	_skin_roads()
	_place_roads()
	add_to_group("briquette_presses")


	call_deferred("refresh_supports")


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_error("BriquettePress: cannot load %s" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)


	for n in _model.find_children("*", "StaticBody3D", true, false):
		var body:= n as StaticBody3D
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0
	if placement_preview:
		for mesh in _meshes():
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wear_feed_disc()
	_hide_all_flow()
	_sink_feed_bed()


const FEED_BED_SINK:= 0.005


func _sink_feed_bed() -> void:
	var bed:= _model.find_child("Assembly_ContinuousFeedBed_Mesh", true, false) as Node3D
	if bed != null:
		bed.position.y -= FEED_BED_SINK


func _wear_feed_disc() -> void:
	var mesh:= FeedDisc.shared_mesh()
	if mesh == null:
		return
	var node:= _flow_node(N_CLIP_DISC) as MeshInstance3D
	if node != null:
		node.mesh = mesh
	var heap:= _flow_node(N_CLIP_CHARGE) as MeshInstance3D
	if heap == null or heap.mesh == null:
		return
	for i in heap.mesh.get_surface_count():
		var over:= _charge_material(heap.mesh.surface_get_material(i))
		if over != null:
			heap.set_surface_override_material(i, over)


const CHARGE_WEARS:= {
	"BP_FeedPelletCore": "res://assets/models/feed_charge_core.tres",
	"BP_FeedPellet": "res://assets/models/feed_charge_pellet.tres",
	"BP_FeedPelletPale": "res://assets/models/feed_charge_pellet.tres",
	"BP_FeedPelletDark": "res://assets/models/feed_charge_pellet.tres",
}


const CHARGE_TILE_M:= 0.41


static func _charge_material(src: Material) -> Material:
	if src == null or not CHARGE_WEARS.has(src.resource_name):
		return null
	var key:= src.resource_name
	return HayCompressor.shared_material(MODEL, "charge:" + key,
		_make_charge.bind(key))


static func _make_charge(key: String) -> Material:
	var source: BaseMaterial3D = load(CHARGE_WEARS [key])
	var made:= source.duplicate() as BaseMaterial3D
	made.resource_name = key + "_Grain"
	made.uv1_triplanar = true
	made.uv1_world_triplanar = true
	made.uv1_scale = Vector3.ONE / CHARGE_TILE_M
	made.uv1_triplanar_sharpness = 8.0
	return made


func _build_collider() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
	_body.collision_mask = 0
	add_child(_body)
	for spec: Array in [


			[Vector3(2.87, 1.13, 2.38), Vector3(-0.895, 0.565, -0.67)],


			[Vector3(1.22, 1.35, 1.35), Vector3(-1.17, 1.15, -0.8)],

			[Vector3(0.38, 1.6, 1.4), Vector3(-2.01, 0.8, -0.85)],


			[Vector3(2.05, 2.55, 1.6), Vector3(0.3, 2.725, 0.0)],


			[Vector3(0.85, 1.75, 1.05), Vector3(1.37, 0.875, 0.15)],


			[Vector3(2.3, 1.95, 1.6), Vector3(-0.15, 2.28, -2.72)],

			[Vector3(0.45, 1.35, 1.9), Vector3(-0.9, 0.675, -2.8)],
			[Vector3(0.45, 1.35, 1.9), Vector3(0.85, 0.675, -2.8)],


			[Vector3(0.55, 0.5, 5.83), Vector3(0.52, 0.767, -1.1)]]:
		var box:= BoxShape3D.new()
		box.size = spec [0]
		var cs:= CollisionShape3D.new()
		cs.shape = box
		cs.position = spec [1]
		_body.add_child(cs)


const TABLE_FLATS: Array [String] = ["BP_DetailRolledSteel", "BP_DetailSafetyYellow"]


func _skin() -> void:
	if _model == null:
		return
	for mesh in _meshes():
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var over:= _override_for(src.resource_name)
			if over != null:
				mesh.set_surface_override_material(i, over)
			if src.resource_name in ["M_BeltRubber", "M_ConveyorDrum"]:
				_bed_surfaces.append([mesh, i, src.resource_name])


func _follow_bed() -> void:
	var held:= power <= 0.0 or (_wad_belt != null and _wad_belt.deck_shows_held())
	if held == _bed_held:
		return
	_bed_held = held
	for s in _bed_surfaces:
		var mesh:= s [0] as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		var rubber: bool = s [2] == "M_BeltRubber"
		var m: Material
		if rubber:
			m = ConveyorKit.belt_material_held() if held else ConveyorKit.belt_material()
		else:
			m = ConveyorKit.roller_material() if held else ConveyorKit.drum_material()
		mesh.set_surface_override_material(int(s [1]), m)


static func _override_for(key: String) -> Material:
	match key:
		"M_BeltRubber":
			return ConveyorKit.belt_material()
		"M_ConveyorFrame":
			return ConveyorKit.frame_material()
		"M_ConveyorDrum":
			return ConveyorKit.drum_material()
		"M_EB_Brick", "M_EB_Stamp":
			return EcoBrick._material(key)
	if not TABLE_FLATS.has(key):
		return null
	return HayCompressor.shared_material(MODEL, key, _make_flat.bind(key))


static func _make_flat(key: String) -> Material:
	var flats: Dictionary = spec_table().get("flats", { })
	if not flats.has(key):
		push_warning("BriquettePress: no table row for %s, it will render white" % key)
		return null
	return _flat(key, flats [key])


static func _flat(key: String, row: Dictionary) -> StandardMaterial3D:
	var m:= StandardMaterial3D.new()
	m.resource_name = key
	var c: Array = row ["color"]
	m.albedo_color = Color(float(c [0]), float(c [1]), float(c [2])).linear_to_srgb()
	m.metallic = float(row.get("metal", 0.0))
	m.metallic_specular = 0.4
	m.roughness = float(row.get("rough", 0.6))
	return m


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


func _build_animation() -> void:
	if _model == null:
		return
	var src:= _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null:
		push_warning("BriquettePress: %s has no AnimationPlayer; nothing will move" % MODEL)
		return
	_grind_anim = src
	var grind:= _driving_clip(_grind_anim, CLIP_GRIND)
	var mill:= _driving_clip(_grind_anim, CLIP_MILL)
	var press:= _driving_clip(_grind_anim, CLIP_PRESS)


	for library_name: StringName in _grind_anim.get_animation_library_list():
		_grind_anim.remove_animation_library(library_name)

	if grind != null:
		grind.loop_mode = Animation.LOOP_LINEAR
		var grind_lib:= AnimationLibrary.new()
		grind_lib.add_animation(CLIP_GRIND, grind)
		_grind_anim.add_animation_library("", grind_lib)
		_grind_anim.play(CLIP_GRIND)


		_grind_anim.speed_scale = 0.0
	else:
		push_warning("BriquettePress: %s has no '%s' clip; the grinder will not turn"
			% [MODEL, CLIP_GRIND])

	if mill != null:


		mill.loop_mode = Animation.LOOP_LINEAR
		_mill_anim = _second_player("MillPlayer", mill, CLIP_MILL)
	else:
		push_warning("BriquettePress: %s has no '%s' clip, so the mill and the grinder cannot stop separately. Split the Grind track in Blender and re-export with briquette_export.py."
			% [MODEL, CLIP_MILL])

	if press != null:
		press.loop_mode = Animation.LOOP_NONE
		_press_anim = _second_player("PressPlayer", press, CLIP_PRESS)


		_press_anim.play(CLIP_PRESS)
		_press_anim.seek(0.0, true)
		_press_anim.pause()
	else:
		push_warning("BriquettePress: %s has no '%s' clip; the ram will not move"
			% [MODEL, CLIP_PRESS])


func _second_player(node_name: String, clip: Animation, clip_name: String) -> AnimationPlayer:
	var player:= AnimationPlayer.new()
	player.name = node_name
	var host:= _grind_anim.get_parent()
	if host == null:
		host = _model
	host.add_child(player)
	player.root_node = player.get_path_to(_grind_anim.get_node(_grind_anim.root_node))
	var lib:= AnimationLibrary.new()
	lib.add_animation(clip_name, clip)
	player.add_animation_library("", lib)
	if clip.loop_mode == Animation.LOOP_LINEAR:
		player.play(clip_name)
		player.speed_scale = 0.0
	return player


static func _driving_clip(player: AnimationPlayer, want: String) -> Animation:
	if _clip_cache.has(want):
		return _clip_cache [want]
	var found:= _clip_name(player, want)
	if found == "":
		return null
	var src:= player.get_animation(found)
	if src == null:
		return null
	var out:= src.duplicate(true) as Animation
	for i in range(out.get_track_count() - 1, -1, -1):
		if out.track_get_key_count(i) < 2 or _game_owned_track(out, i):
			out.remove_track(i)
	if out.get_track_count() == 0:
		out = src
	_clip_cache [want] = out
	return out


static func _game_owned_track(clip: Animation, i: int) -> bool:
	var path:= clip.track_get_path(i)
	var names:= path.get_name_count()
	if names == 0 or path.get_name(names - 1) != N_CLIP_CHARGE:
		return false
	return clip.track_get_type(i) == Animation.TYPE_SCALE_3D or path.get_concatenated_subnames() == "scale"


static func _clip_name(player: AnimationPlayer, want: String) -> String:
	if player == null:
		return ""
	if player.has_animation(want):
		return want
	for n in player.get_animation_list():
		if n.ends_with(want):
			return n
	return ""


func clip_seconds() -> float:
	if _press_anim == null:
		return 0.0
	var found:= _clip_name(_press_anim, CLIP_PRESS)
	if found == "":
		return 0.0
	var clip:= _press_anim.get_animation(found)
	return 0.0 if clip == null else clip.length


func mill_has_own_clip() -> bool:
	return _mill_anim != null


func _flow_node(node_name: String) -> Node3D:
	if not _flow.has(node_name):
		_flow [node_name] = _find(node_name) as Node3D
	return _flow [node_name] as Node3D


func _show_flow(node_name: String, on: bool) -> void:
	var node:= _flow_node(node_name)
	if node != null and node.visible != on:
		node.visible = on


func _show_flow_set(names: Array [String], on: bool) -> void:
	for node_name in names:
		_show_flow(node_name, on)


func _hide_all_flow() -> void:
	_show_flow_set(N_MILL_FLOW, false)
	_show_flow_set(N_GRIND_FLOW, false)
	_show_flow(N_CLIP_CHARGE, false)
	_show_flow(N_CLIP_DISC, false)


func cycle_frame() -> float:
	if _run < 0.0:
		return 0.0
	return CYCLE_FRAMES * clampf(_run / maxf(_cycle, 0.001), 0.0, 1.0)


func charge_fill() -> float:
	var hay:= float(stored_strands) / maxf(1.0, float(Tech.briquette_batch_strands()))
	var brick:= float(stored_bricks) / maxf(1.0, float(Tech.briquette_batch_bricks()))
	return 0.5 * (minf(hay, 1.0) + minf(brick, 1.0))


const CHARGE_SHOW_AT:= 0.02


const CHARGE_FLOOR:= 0.06


const CHARGE_GROW:= 0.7


const STROKE_GROW:= CHARGE_GROW * 3.0


const LUMP_SIZE:= Vector3(0.62, 0.6, 0.62)


const CHARGE_H:= 0.42
const PLATEN_DROP:= 0.11

const DISC_FLOOR:= (Cfg.FEED_DISC_SIZE.y - 0.004) / CHARGE_H


const DISC_SPREAD:= 0.9


func _tick_press_flow(delta: float) -> void:
	var frame:= cycle_frame()
	var running:= _run >= 0.0
	if running:


		_stroke_lump = move_toward(_stroke_lump, 1.0, STROKE_GROW * delta)
		var crushing:= frame < F_FORMED
		_show_flow(N_CLIP_CHARGE, crushing)
		if crushing:
			_stroke_low = _shape_heap(_stroke_lump, _stroke_low)
	else:
		_hay_share = _credit(_hay_share, stored_strands,
			Tech.briquette_batch_strands(), SIDE_GRIND, delta)
		_pellet_share = _credit(_pellet_share, stored_bricks,
			Tech.briquette_batch_bricks(), SIDE_MILL, delta)
		_charge_drawn = 0.5 * (_hay_share + _pellet_share)
		_show_flow(N_CLIP_CHARGE, _charge_drawn > CHARGE_SHOW_AT)
		_shape_heap(_charge_drawn)
	_show_flow(N_CLIP_DISC, running and frame >= F_FORMED and not _released)


func _credit(share: float, stored: int, batch: int, side: int, delta: float) -> float:
	var want:= minf(float(stored) / maxf(1.0, float(batch)), 1.0)
	if want <= share:
		return want
	if not road_arrived(side):
		return share
	return move_toward(share, want, CHARGE_GROW * delta)


func _shape_heap(fill: float, lowest:= INF) -> float:
	var heap:= _flow_node(N_CLIP_CHARGE)
	if heap == null:
		return lowest
	var size:= LUMP_SIZE * maxf(fill, CHARGE_FLOOR)
	var tall:= minf(size.y, lowest)
	var ram:= _flow_node(N_RAM)
	if ram != null:
		var room:= (ram.position.y - PLATEN_DROP - Cfg.BRIQUETTE_PORT_UP) / CHARGE_H
		if room < size.y:
			tall = minf(tall, maxf(room, DISC_FLOOR))
			lowest = tall
	if tall < size.y:
		var t:= 1.0
		if size.y > DISC_FLOOR:
			t = clampf((size.y - tall) / (size.y - DISC_FLOOR), 0.0, 1.0)
		var across:= lerpf(size.x, maxf(size.x, DISC_SPREAD), t)
		size = Vector3(across, tall, across)
	heap.scale = size
	return lowest


func _tick_roads(delta: float) -> void:
	if placement_preview:
		return
	if global_transform != _road_xform:
		_place_roads()
	var step:= ROAD_SPEED * power * delta
	_advance_road(SIDE_GRIND, _grind_spin > ROAD_SOURCE_SPIN, step)
	_advance_road(SIDE_MILL, _mill_spin > ROAD_SOURCE_SPIN, step)


func _advance_road(side: int, pouring: bool, step: float) -> void:
	var segs: Array = _roads [side]
	var was:= segs.duplicate()
	var open:= not segs.is_empty() and (segs [-1] as Vector2).x < 0.0
	if pouring and not open:
		if segs.size() >= ROAD_SEGMENTS:


			segs [-1] = Vector2(- ROAD_OPEN, (segs [-1] as Vector2).y)
		else:
			segs.append(Vector2(- ROAD_OPEN, 0.0))
	elif not pouring and open:
		segs [-1] = Vector2(0.0, (segs [-1] as Vector2).y)
	var end:= ROAD_END [side] + ROAD_OVERRUN
	for i in range(segs.size() - 1, -1, -1):
		var seg: Vector2 = segs [i]
		seg.y = minf(seg.y + step, end)
		if seg.x >= 0.0:
			seg.x += step
		if seg.x >= seg.y:
			segs.remove_at(i)
		else:
			segs [i] = seg
	if segs != was:
		_push_road(side)


func _push_road(side: int) -> void:
	var segs: Array = _roads [side]
	var a: Vector2 = segs [0] if segs.size() > 0 else ROAD_NONE
	var b: Vector2 = segs [1] if segs.size() > 1 else ROAD_NONE
	for piece: Array in ROAD_PIECES:
		if int(piece [1]) != side:
			continue
		var mesh:= _road_mesh(str(piece [0]))
		if mesh == null:
			continue
		HayCompressor.drive_instance(mesh, &"road_seg_a", a)
		HayCompressor.drive_instance(mesh, &"road_seg_b", b)
		_show_flow(str(piece [0]), not segs.is_empty())


func _place_roads() -> void:
	_road_xform = global_transform
	for piece: Array in ROAD_PIECES:
		var mesh:= _road_mesh(str(piece [0]))
		if mesh == null:
			continue
		HayCompressor.drive_instance(mesh, &"road_origin", to_global(piece [2] as Vector3))
		HayCompressor.drive_instance(mesh, &"road_dir",
			(global_basis * (piece [3] as Vector3)).normalized())
		HayCompressor.drive_instance(mesh, &"road_offset", float(piece [4]))
	_push_road(SIDE_GRIND)
	_push_road(SIDE_MILL)


func _road_mesh(node_name: String) -> MeshInstance3D:
	return _flow_node(node_name) as MeshInstance3D


func _skin_roads() -> void:
	for piece: Array in ROAD_PIECES:
		var mesh:= _road_mesh(str(piece [0]))
		if mesh == null or mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var over:= _road_material(mesh.get_active_material(i))
			if over != null:
				mesh.set_surface_override_material(i, over)


static func _road_material(src: Material) -> Material:
	var base:= src as BaseMaterial3D
	if base == null:
		return null
	return HayCompressor.shared_material(MODEL, "road:" + base.resource_name,
		_make_road.bind(base))


static func _make_road(base: BaseMaterial3D) -> Material:
	var m:= ShaderMaterial.new()
	m.resource_name = base.resource_name + "_Road"
	m.shader = load(ROAD_SHADER) as Shader
	m.set_shader_parameter("albedo", base.albedo_color)
	m.set_shader_parameter("roughness", base.roughness)
	m.set_shader_parameter("metallic", base.metallic)
	m.set_shader_parameter("specular", base.metallic_specular)
	return m


const SHOT_FRAME:= 60.0


func pose_for_shot(frame: float = SHOT_FRAME) -> void:


	set_physics_process(false)
	for side: int in [SIDE_GRIND, SIDE_MILL]:
		_roads [side] = [Vector2(- ROAD_OPEN, ROAD_END [side] + ROAD_OVERRUN)]
	_place_roads()


	_show_flow(N_CLIP_CHARGE, frame < F_FORMED)
	_show_flow(N_CLIP_DISC, frame >= F_FORMED)
	if _press_anim != null and _press_anim.has_animation(CLIP_PRESS):
		_press_anim.play(CLIP_PRESS)
		_press_anim.seek(frame / CLIP_FPS, true)
		_press_anim.pause()
	for player: AnimationPlayer in [_grind_anim, _mill_anim]:
		if player == null:
			continue
		player.speed_scale = 1.0
		player.advance(frame / CLIP_FPS)
		player.speed_scale = 0.0

	_shape_heap(1.0)


func port_wad() -> Vector3:
	return to_global(_marker_local(N_PORT_WAD, Vector3(
		- Cfg.BRIQUETTE_PORT_WAD, Cfg.BRIQUETTE_PORT_UP,
		Cfg.BRIQUETTE_PORT_WAD_OFFSET)) - Vector3(_reach(REACH_WAD), 0.0, 0.0))


func port_brick() -> Vector3:
	return to_global(_marker_local(N_PORT_BRICK, Vector3(
		0.0, Cfg.BRIQUETTE_PORT_UP, - Cfg.BRIQUETTE_PORT_BRICK))
		- Vector3(0.0, 0.0, _reach(REACH_BRICK)))


func port_out() -> Vector3:
	return to_global(_marker_local(N_PORT_DISC, Vector3(
		0.0, Cfg.BRIQUETTE_PORT_UP, Cfg.BRIQUETTE_PORT_DISC))
		+ Vector3(0.0, 0.0, _reach(REACH_DISC)))


func _reach(which: int) -> float:
	return float(port_reach [which]) if which < port_reach.size() else 0.0


func _wad_mouth_length() -> float:
	return WAD_MOUTH_LENGTH + _reach(REACH_WAD)


func _brick_mouth_length() -> float:
	return BRICK_MOUTH_LENGTH + _reach(REACH_BRICK)


func ports() -> Array [Vector3]:
	return [port_wad(), port_brick(), port_out()]


func bearing_at(point: Vector3) -> Vector3:
	if PointIndex.joins(port_wad(), point):
		return global_basis.x.normalized()
	if PointIndex.joins(port_brick(), point) or PointIndex.joins(port_out(), point):
		return global_basis.z.normalized()
	return Vector3.ZERO


func forward() -> Vector3:
	var d:= port_out() - port_brick()
	d.y = 0.0
	return d.normalized() if d.length_squared() > 1e-08 else global_basis.z.normalized()


func deck() -> BeltPath:
	return _wad_belt


func wad_deck() -> BeltPath:
	return _wad_belt


func brick_deck() -> BeltPath:
	return _brick_belt


func outfeed_deck() -> BeltPath:
	return _out_belt


func disc_spot() -> Vector3:
	return to_global(Vector3(0.0, Cfg.BRIQUETTE_PORT_UP, DISC_SPOT_Z))


func outfeed_reserve() -> float:
	return Cfg.FEED_DISC_CLEAR * 0.5


func console_position() -> Vector3:
	return to_global(Vector3(1.9, 0.95, 0.15))


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


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


func _build_belts() -> void:
	_wad_belt = BeltPath.new()
	_wad_belt.name = "WadArm"
	add_child(_wad_belt)
	var runs:= belt_runs()
	_wad_belt.build_path(runs [0], Cfg.BELT_JOINT_OVERLAP)
	_wad_belt.set_outlet_held(true)
	_wad_belt.set_hold_filter(func(b: Object) -> bool:
		return wad_full() or _blocks_wad(b))


	_wad_belt.records_props = true
	_wad_belt.hold_records(_eats_wad_kind)

	_brick_belt = BeltPath.new()
	_brick_belt.name = "BrickArm"
	add_child(_brick_belt)
	_brick_belt.build_path(runs [1], Cfg.BELT_JOINT_OVERLAP)
	_brick_belt.set_outlet_held(true)

	_brick_belt.set_hold_back(
		port_brick().distance_to(_brick_end()) - _brick_mouth_run())
	_brick_belt.set_hold_filter(func(b: Object) -> bool:
		return brick_full() or _blocks_brick(b))
	_brick_belt.records_props = true
	_brick_belt.hold_records(_eats_brick_kind)

	_out_belt = BeltPath.new()
	_out_belt.name = "DiscArm"
	add_child(_out_belt)
	_out_belt.build_path(runs [2], Cfg.BELT_JOINT_OVERLAP)


	_out_belt.reserve_head(disc_spot(), outfeed_reserve())


	_out_belt.records_props = true


func belt_runs() -> Array [PackedVector3Array]:
	return [PackedVector3Array([port_wad(), _wad_end()]),
		PackedVector3Array([port_brick(), _brick_end()]),
		PackedVector3Array([_disc_head(), port_out()])]


func _wad_end() -> Vector3:
	return to_global(Vector3(WAD_IN_X, Cfg.BRIQUETTE_PORT_UP,
		Cfg.BRIQUETTE_PORT_WAD_OFFSET))


func _brick_end() -> Vector3:
	return to_global(Vector3(0.0, Cfg.BRIQUETTE_PORT_UP, BRICK_IN_Z))


func _disc_head() -> Vector3:
	return to_global(Vector3(0.0, Cfg.BRIQUETTE_PORT_UP, DISC_HEAD_Z))


func _brick_mouth_run() -> float:
	return Cfg.BRIQUETTE_PORT_BRICK + _reach(REACH_BRICK) + BRICK_MOUTH_Z


func _build_mouths() -> void:
	var width:= Cfg.BELT_WIDTH - Cfg.BELT_RAIL_T * 2.0
	_wad_mouth = _mouth_area("WadMouth",
		Vector3(width, MOUTH_HEIGHT, _wad_mouth_length()),
		Vector3(WAD_MOUTH_X - _wad_mouth_length() * 0.5,
			Cfg.BRIQUETTE_PORT_UP + MOUTH_HEIGHT * 0.5,
			Cfg.BRIQUETTE_PORT_WAD_OFFSET),
		PI * 0.5)
	_brick_mouth = _mouth_area("BrickMouth",
		Vector3(width, MOUTH_HEIGHT, _brick_mouth_length()),
		Vector3(0.0, Cfg.BRIQUETTE_PORT_UP + MOUTH_HEIGHT * 0.5,
			BRICK_MOUTH_Z - _brick_mouth_length() * 0.5),
		0.0)


func _mouth_area(node_name: String, size: Vector3, at: Vector3,
		yaw: float) -> Area3D:
	var area:= Area3D.new()
	area.name = node_name
	area.collision_layer = 0


	area.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	area.monitorable = false
	var box:= BoxShape3D.new()
	box.size = size
	var cs:= CollisionShape3D.new()
	cs.shape = box
	area.add_child(cs)
	add_child(area)
	area.position = at
	area.rotation.y = yaw
	return area


func _build_ghost_belt() -> void:
	_ghost_belt = BeltGhost.new()
	add_child(_ghost_belt)


	var fmm:= MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	fmm.use_colors = true
	fmm.mesh = ConveyorKit.flow_arrow_mesh()
	fmm.instance_count = ARROW_CAPACITY * 3
	fmm.visible_instance_count = 0
	_ghost_flow = MultiMeshInstance3D.new()
	_ghost_flow.name = "GhostFlow"
	_ghost_flow.multimesh = fmm
	_ghost_flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_flow.material_override = ConveyorKit.flow_material()
	add_child(_ghost_flow)
	_shape_flow()


func _ghost_arms() -> Array [Array]:
	var arms: Array [Array] = []
	for run: PackedVector3Array in belt_runs():
		arms.append([to_local(run [0]), to_local(run [run.size() - 1])])
	return arms


static func chevron_basis(from: Vector3, to: Vector3) -> Basis:
	return BeltPath.run_basis(from, to)


func _process(delta: float) -> void:
	if not placement_preview or _ghost_flow == null or not is_visible_in_tree():
		return
	_flow_phase += delta * ARROW_SPEED
	_shape_flow()


	_ghost_belt.show_belt(belt_runs(), Cfg.BELT_JOINT_OVERLAP, support_xforms(), [],
		drum_ends())


func _shape_flow() -> void:
	var mm:= _ghost_flow.multimesh
	var at:= 0
	for arm: Array in _ghost_arms():
		var from: Vector3 = arm [0]
		var to: Vector3 = arm [1]
		var length:= from.distance_to(to)
		var dir:= (to - from).normalized()
		var basis:= chevron_basis(from, to)
		var n:= clampi(maxi(1, int(round(length / ARROW_PITCH))), 1, ARROW_CAPACITY)
		var pitch:= length / n
		var phase:= fmod(_flow_phase, pitch)
		for i in n:
			var along:= fmod(i * pitch + phase, length)
			mm.set_instance_transform(at, Transform3D(basis,
				from + dir * along + Vector3.UP * ARROW_LIFT))
			var fade:= (clampf(along / ARROW_FADE, 0.0, 1.0)
				* clampf((length - along) / ARROW_FADE, 0.0, 1.0))
			mm.set_instance_color(at, Color(1.0, 1.0, 1.0, fade))
			at += 1
	mm.visible_instance_count = at


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
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []
	for arm: Array in [[port_wad(), global_basis.z], [port_brick(), global_basis.x],
			[port_out(), global_basis.x]]:
		var port: Vector3 = arm [0]
		var across: Vector3 = (arm [1] as Vector3).normalized()
		var centre_top:= port - Vector3.UP * Cfg.BELT_SUPPORT_ATTACH_DEPTH
		for side: float in [-1.0, 1.0]:
			var top:= centre_top + across * (side * SUPPORT_HALF_WIDTH)
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
			legs.append(Transform3D(global_basis.scaled_local(Vector3(1, drop, 1)), top))
			feet.append(Transform3D(global_basis, ground))
	return [legs, feet]


func _refresh_drums() -> void:
	if _drums != null:
		remove_child(_drums)
		_drums.queue_free()
		_drums = null
	if placement_preview:
		return
	_drums = Node3D.new()
	_drums.name = "Drums"


	_drums.top_level = true
	add_child(_drums)
	for e: Array in drum_ends():
		var mi:= MeshInstance3D.new()
		mi.mesh = ConveyorKit.nose_mesh(bool(e [0]))
		_drums.add_child(mi)
		mi.global_transform = Transform3D(e [2] as Basis, e [1] as Vector3)


		BeltBatch.adopt(mi)


func drum_ends() -> Array:
	var wad_basis:= BeltPath.run_basis(port_wad(), _wad_end())
	var brick_basis:= BeltPath.run_basis(port_brick(), _brick_end())
	var out_basis:= BeltPath.run_basis(_disc_head(), port_out())
	return [[true, port_out(), out_basis],
		[false, port_wad(), wad_basis.rotated(wad_basis.y, PI)],
		[false, port_brick(), brick_basis.rotated(brick_basis.y, PI)]]


func _own_bodies() -> Array [RID]:
	var out: Array [RID] = []
	for node in find_children("*", "CollisionObject3D", true, false):
		var body:= node as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


func strand_capacity() -> int:
	return Tech.briquette_buffer_strands()


func brick_capacity() -> int:
	return Tech.briquette_buffer_bricks()


func wad_full() -> bool:
	return stored_strands >= strand_capacity()


func straw_room() -> int:
	return maxi(0, strand_capacity() - stored_strands)


func brick_full() -> bool:
	return stored_bricks >= brick_capacity()


func is_running() -> bool:
	return _run >= 0.0


func grinder_wants_to_turn() -> bool:
	return power > 0.0 and stored_strands > 0


func mill_wants_to_turn() -> bool:
	return power > 0.0 and stored_bricks > 0


func grinder_spin() -> float:
	return _grind_spin


func mill_spin() -> float:
	return _mill_spin


func charge_drawn() -> float:
	return _stroke_lump if _run >= 0.0 else _charge_drawn


func road_front(side: int) -> float:
	var segs: Array = _roads [side]
	return -1.0 if segs.is_empty() else (segs [-1] as Vector2).y


func road_busy(side: int) -> bool:
	return not (_roads [side] as Array).is_empty()


func road_arrived(side: int) -> bool:
	for seg: Vector2 in _roads [side]:
		if seg.y >= ROAD_END [side] and seg.x < ROAD_END [side]:
			return true
	return false


func road_seconds(side: int, whole:= false) -> float:
	return (ROAD_END [side] + (ROAD_OVERRUN if whole else 0.0)) / ROAD_SPEED


func cycle_seconds() -> float:
	return maxf(Tech.briquette_cycle_seconds(), 0.001)


func run_progress() -> float:
	if _run < 0.0:
		return 0.0
	return clampf(_run / maxf(_cycle, 0.001), 0.0, 1.0)


func alert_reason() -> String:
	if placement_preview:
		return ""
	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead


	if _run < 0.0 and not _disc_room(disc_spot()):
		return tr("OUTFEED BLOCKED  ·  clear the disc off the belt")


	var stuck:= _jammed_load()
	if stuck != "":
		return stuck
	if _run >= 0.0:
		return ""
	if starved_for < Cfg.MACHINE_STARVED_AFTER:
		return ""


	var hay_short:= stored_strands < Tech.briquette_batch_strands()
	var brick_short:= stored_bricks < Tech.briquette_batch_bricks()
	if hay_short and brick_short:
		return tr("NOT FED  ·  it needs hay on one belt and eco bricks on the other")
	if hay_short:
		return tr("NO HAY  ·  the wad belt has run dry")
	if brick_short:
		return tr("NO BRICKS  ·  the eco brick belt has run dry")
	return ""


func _jammed_load() -> String:
	for on_wad: bool in [true, false]:
		var belt: BeltPath = _wad_belt if on_wad else _brick_belt
		if belt == null:
			continue
		var rb:= belt.waiting_rider()
		if rb == null:
			continue
		var eaten_here:= _eats_wad(rb) if on_wad else _eats_brick(rb)
		if eaten_here:
			continue
		var item:= rb as Carryable
		var named: String = Cfg.lower_in_english(item.display_name) if item != null else tr("load")


		var wanted_elsewhere:= _eats_brick(rb) if on_wad else _eats_wad(rb)
		if wanted_elsewhere:
			return tr("WRONG BELT  ·  the %s goes on the other belt") % named
		if on_wad:
			return tr("WRONG LOAD  ·  take the %s off the hay input") % named
		return tr("WRONG LOAD  ·  take the %s off the brick input") % named
	return ""


func full_rate() -> bool:
	return true


func factory_tick(delta: float) -> void:
	var held:= stored_strands + stored_bricks
	_intake_wads()
	_intake_bricks()


	starved_for = 0.0 if stored_strands + stored_bricks > held else starved_for + delta
	_tick_run(delta)
	_tick_spin(delta)
	_tick_press_flow(delta)
	_sync_backpressure()
	_follow_bed()
	_tick_loops(delta)


func _eats_wad(body: Object) -> bool:
	var rb:= body as RigidBody3D
	if rb == null:
		return false


	if rb is FeedDisc or rb is EcoBrick or rb is HayBale:
		return false


	if rb is HayWad:
		return true
	return bool(rb.collision_layer & Cfg.L_STRAND)


func _eats_brick(body: Object) -> bool:
	var rb:= body as RigidBody3D
	if rb == null:
		return false
	if rb is EcoBrick:
		return true
	return rb.has_meta("needle_index") and bool(rb.collision_layer & Cfg.L_STRAND)


func _eats_wad_kind(kind: int, _strands: int) -> bool:
	return kind == BeltRun.Kind.WAD


func _eats_brick_kind(kind: int, _strands: int) -> bool:
	return kind == BeltRun.Kind.BRICK


func _blocks_wad(body: Object) -> bool:
	var rb:= body as RigidBody3D
	return rb != null and bool(rb.collision_layer & Cfg.L_PROP) and not _eats_wad(rb)


func _blocks_brick(body: Object) -> bool:
	var rb:= body as RigidBody3D
	return rb != null and bool(rb.collision_layer & Cfg.L_PROP) and not _eats_brick(rb)


func _intake_wads() -> void:
	if _wad_mouth == null:
		return


	if _wad_belt != null and not wad_full():
		var m:= _wad_belt.s_at(_wad_mouth.global_position)
		var rec:= _wad_belt.take_record(Callable(),
			m - _wad_mouth_length() * 0.5, m + _wad_mouth_length() * 0.5)
		if not rec.is_empty():
			stored_strands += int(rec ["strands"])
			if int(rec ["needle"]) >= 0:
				pending_needles.append(int(rec ["needle"]))
			Audio.play_3d("machine_thud", _wad_mouth.global_position, -9.0)
	for body in _wad_mouth.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		if not _eats_wad(rb):
			continue
		var wad:= rb as HayWad
		if wad != null:
			if (wad.freeze and not BeltPath.is_rider(wad)) or wad_full():
				continue


			BeltPath.release(wad)
			stored_strands += wad.strands


			if wad.holds_needle():
				pending_needles.append(wad.needle_index)

			Audio.play_3d("machine_thud", _wad_mouth.global_position, -9.0)
			if props != null:
				props.remove(wad)
			else:
				wad.queue_free()
			continue
		if rb.has_meta("needle_index"):
			_swallow_needle(rb, _wad_mouth.global_position)
			continue
		if wad_full():
			continue
		if rb.freeze and not BeltPath.is_rider(rb):
			continue
		if live == null:
			continue
		BeltPath.release(rb)
		if live.consume(rb):
			stored_strands += 1


			Audio.play_3d("machine_feed", _wad_mouth.global_position, -13.0)


func _intake_bricks() -> void:
	if _brick_mouth == null:
		return


	if _brick_belt != null and not brick_full():
		var m:= _brick_belt.s_at(_brick_mouth.global_position)
		var rec:= _brick_belt.take_record(Callable(),
			m - _brick_mouth_length() * 0.5, m + _brick_mouth_length() * 0.5)
		if not rec.is_empty():
			var strands:= int(rec ["strands"])
			stored_bricks += 1
			brick_hay.append(strands)
			brick_worth.append(float(strands) * Tech.brick_value_ratio())
			if int(rec ["needle"]) >= 0:
				pending_needles.append(int(rec ["needle"]))
			Audio.play_3d("machine_thud", _brick_mouth.global_position, -9.0)
	for body in _brick_mouth.get_overlapping_bodies():
		var rb:= body as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		if not _eats_brick(rb):
			continue
		var brick:= rb as EcoBrick
		if brick == null:
			_swallow_needle(rb, _brick_mouth.global_position)
			continue
		if brick_full():
			continue
		if brick.freeze and not BeltPath.is_rider(brick):
			continue
		BeltPath.release(brick)
		stored_bricks += 1
		brick_hay.append(brick.hay_strands())
		brick_worth.append(brick.sale_strands())


		if brick.holds_needle():
			pending_needles.append(brick.needle_index)
		Audio.play_3d("machine_thud", _brick_mouth.global_position, -9.0)
		if props != null:
			props.remove(brick)
		else:
			brick.queue_free()


func _swallow_needle(rb: RigidBody3D, at: Vector3) -> void:
	if live == null or not rb.has_meta("needle_index"):
		return
	if not (rb.collision_layer & Cfg.L_STRAND):
		return


	if rb.freeze and not BeltPath.is_rider(rb) and not LiveStrandManager.is_pinned(rb):
		return
	BeltPath.release(rb)
	var index:= int(rb.get_meta("needle_index", -1))
	if not live.consume_needle(rb):
		return
	pending_needles.append(index)


	Audio.play_3d("machine_feed", at, -13.0)


func _tick_run(delta: float) -> void:
	if _run < 0.0:


		if power <= 0.0:
			return
		if stored_strands >= Tech.briquette_batch_strands() and stored_bricks >= Tech.briquette_batch_bricks() and _disc_room(disc_spot()):
			_start_run()
		return


	_run += delta * power


	if not _cracked and _run >= _at_frame(F_FORMED):
		_cracked = true
		Audio.play_3d("machine_clunk", _emitter(), -12.0)
		Audio.play_3d_delayed("machine_vent", _emitter(), 0.1, -8.0)
	if not _released and _run >= _release_at():
		_release_disc()
	if _run >= _cycle:
		_finish_run()


func _at_frame(frame: float) -> float:
	return _cycle * (frame / CYCLE_FRAMES)


func _release_at() -> float:
	return _at_frame(F_RELEASE)


func _take_brick_hay(count: int) -> int:
	_sync_brick_worth()
	while brick_hay.size() > stored_bricks:
		brick_hay.remove_at(0)
		brick_worth.remove_at(0)
	var unknown:= stored_bricks - brick_hay.size()
	var hay:= 0
	_batch_brick_worth = 0.0
	for i in count:
		if unknown > 0 or brick_hay.is_empty():
			unknown -= 1
			hay += Tech.pellet_brick_strands()
			_batch_brick_worth += float(Tech.pellet_brick_strands()) * Tech.brick_value_ratio()
		else:
			hay += brick_hay [0]
			_batch_brick_worth += brick_worth [0]
			brick_hay.remove_at(0)
			brick_worth.remove_at(0)
	return hay


func _sync_brick_worth() -> void:
	while brick_worth.size() > brick_hay.size():
		brick_worth.remove_at(brick_worth.size() - 1)
	while brick_worth.size() < brick_hay.size():
		brick_worth.append(float(brick_hay [brick_worth.size()]) * Tech.brick_value_ratio())


func _start_run() -> void:


	_batch_strands = Tech.briquette_batch_strands()
	_batch_bricks = Tech.briquette_batch_bricks()
	_cycle = cycle_seconds()
	_batch_brick_hay = _take_brick_hay(_batch_bricks)
	stored_strands -= _batch_strands
	stored_bricks -= _batch_bricks
	_run = 0.0
	_released = false
	_cracked = false


	_stroke_lump = _charge_drawn
	_stroke_low = INF
	_hay_share = 0.0
	_pellet_share = 0.0
	_charge_drawn = 0.0
	if _press_anim != null and _press_anim.has_animation(CLIP_PRESS):
		_apply_cycle_speed()
		_press_anim.play(CLIP_PRESS)
		_press_anim.seek(0.0, true)


	Audio.play_3d("machine_clunk", _emitter(), -8.0)


func _finish_run() -> void:


	if not _released:
		_run = _release_at()
		_release_disc()
		return
	_run = -1.0
	if _press_anim != null:
		_press_anim.pause()
		_press_anim.seek(0.0, true)


func _release_disc() -> void:
	if props == null:


		push_warning("BriquettePress: no PropManager; the disc cannot be created")
		_released = true
		return
	var at:= disc_spot()
	if not _disc_room(at):
		return


	if _out_belt != null and _out_belt.records_props:
		var strands:= _batch_strands + _batch_brick_hay
		var needle:= pending_needles [0] if not pending_needles.is_empty() else -1
		var state:= { "strands": strands, "brick_hay": _batch_brick_hay,
			"brick_worth": _batch_brick_worth }
		if needle >= 0:
			state ["needle"] = needle
		var seq:= _out_belt.push_record(BeltRun.Kind.DISC, strands, needle, state, at)
		if seq < 0:
			return
		if needle >= 0:
			pending_needles.remove_at(0)
		_released = true
		Audio.play_3d("machine_thud", at, -6.0)
		pressed_record.emit(seq)
		return


	var disc:= props.spawn("feed_disc",
		Transform3D(global_basis, at + Vector3.UP * (Cfg.FEED_DISC_SIZE.y * 0.04))) as FeedDisc
	if disc == null:
		_released = true
		return


	disc.strands = _batch_strands + _batch_brick_hay
	disc.brick_hay = _batch_brick_hay
	disc.brick_worth = _batch_brick_worth


	if not pending_needles.is_empty():
		disc.needle_index = pending_needles [0]
		pending_needles.remove_at(0)
	_released = true


	Audio.play_3d("machine_thud", at, -6.0)
	pressed.emit(disc)


func _disc_room(at: Vector3) -> bool:
	if not is_inside_tree():
		return false
	if _room_probe == null:
		_room_probe = BoxShape3D.new()
		_room_probe.size = Vector3(Cfg.FEED_DISC_SIZE.x, Cfg.FEED_DISC_SIZE.y,
			Cfg.FEED_DISC_CLEAR)
		_room_query = PhysicsShapeQueryParameters3D.new()
		_room_query.shape = _room_probe
		_room_query.collision_mask = Cfg.L_PROP
		_room_query.collide_with_areas = false
	_room_query.transform = Transform3D(global_basis,
		at + Vector3.UP * Cfg.FEED_DISC_SIZE.y * 0.5)
	return get_world_3d().direct_space_state.intersect_shape(_room_query, 1).is_empty()


func _tick_spin(delta: float) -> void:
	var step:= delta / maxf(Cfg.BRIQUETTE_SPIN_SECONDS, 0.001)
	_grind_spin = move_toward(_grind_spin,
		1.0 if grinder_wants_to_turn() else 0.0, step)


	var mill_want:= mill_wants_to_turn() if _mill_anim != null else grinder_wants_to_turn()
	_mill_spin = move_toward(_mill_spin, 1.0 if mill_want else 0.0, step)
	_apply_spin()


	_tick_roads(delta)
	_grind_target = LOOP_DB if _grind_spin > 0.02 else LOOP_SILENT
	_mill_target = LOOP_DB if _mill_spin > 0.02 else LOOP_SILENT
	if _grind_voice < 0 and _grind_spin > 0.02:
		_grind_voice = Audio.loop_acquire(GRIND_LOOP)
		_grind_gain = LOOP_SILENT
	if _mill_voice < 0 and _mill_spin > 0.02:
		_mill_voice = Audio.loop_acquire(MILL_LOOP)
		_mill_gain = LOOP_SILENT


func _apply_spin() -> void:
	if _grind_anim != null:
		_grind_anim.speed_scale = _grind_spin * power
	if _mill_anim != null:
		_mill_anim.speed_scale = _mill_spin * power


func _apply_cycle_speed() -> void:
	if _press_anim != null:
		_press_anim.speed_scale = power * Cfg.BRIQUETTE_CYCLE_SECONDS / maxf(_cycle, 0.001)


func _sync_backpressure() -> void:
	if _wad_belt != null and _wad_belt.is_blocked() != wad_full():
		_wad_belt.set_blocked(wad_full())
	if _brick_belt != null and _brick_belt.is_blocked() != brick_full():
		_brick_belt.set_blocked(brick_full())


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Cfg.BRIQUETTE_DRAW_KW


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


const WIRE_PORT_FALLBACKS: Array [Vector3] = [
	Vector3(1.48, 1.47, -0.04), Vector3(-1.39, 1.51, 0.44)]


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 2, WIRE_PORT_FALLBACKS,
			_fitting_materials())
	return _ports


static func _fitting_materials() -> Dictionary:
	var flats: Dictionary = spec_table().get("flats", { })
	var out:= { }
	for pair in [["steel", "BP_GalvanizedSteel"], ["porcelain", "BP_GaugeWhite"],
			["copper", "BP_CouplingBrass"]]:
		var key: String = pair [1]
		if flats.has(key):
			out [pair [0]] = HayCompressor.shared_material(MODEL, "fitting:" + key,
				_flat.bind(key, flats [key]))
	return out


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power
	_apply_spin()
	_apply_cycle_speed()


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


func _emitter() -> Vector3:
	return global_position + Vector3(0, LOOP_HEIGHT, 0)


func _grind_emitter() -> Vector3:
	return to_global(Vector3(-1.25, LOOP_HEIGHT, -0.8))


func _mill_emitter() -> Vector3:
	return to_global(Vector3(0.0, LOOP_HEIGHT + 0.6, -2.72))


func _tick_loops(delta: float) -> void:
	_grind_voice = _tick_one_loop(delta, _grind_voice, _grind_emitter(),
		_grind_target)
	_mill_voice = _tick_one_loop(delta, _mill_voice, _mill_emitter(),
		_mill_target)


func _tick_one_loop(delta: float, voice: int, at: Vector3, target: float) -> int:
	if voice < 0:
		return voice
	var gain:= _grind_gain if voice == _grind_voice else _mill_gain
	gain = move_toward(gain, target, LOOP_RAMP * delta)
	if voice == _grind_voice:
		_grind_gain = gain
	else:
		_mill_gain = gain
	if target <= LOOP_SILENT and gain <= LOOP_SILENT + 0.5:
		Audio.loop_release(voice)
		return -1


	var spin:= _grind_spin if voice == _grind_voice else _mill_spin
	Audio.loop_update(voice, at, gain,
		MachinePower.loop_pitch(power * maxf(spin, 0.35)))
	return voice


func _exit_tree() -> void:
	if _grind_voice >= 0:
		Audio.loop_release(_grind_voice)
		_grind_voice = -1
	if _mill_voice >= 0:
		Audio.loop_release(_mill_voice)
		_mill_voice = -1


func set_preview_valid(valid: bool) -> void:
	if not placement_preview or _model == null:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = material


	if _ghost_belt != null:
		_ghost_belt.set_material(material)


func build_cost() -> float:
	return Cfg.BRIQUETTE_COST


func to_dict() -> Dictionary:
	return {
		"type": "briquette_press",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,


		"strands": stored_strands,
		"bricks": stored_bricks,


		"brick_hay": brick_hay,
		"brick_worth": brick_worth,

		"needles": pending_needles,


		"port_reach": port_reach.duplicate(),
	}


func from_dict(d: Dictionary) -> void:


	port_reach = [0.0, 0.0, 0.0]
	var saved: Variant = d.get("port_reach", [])
	if saved is Array:
		for i in mini(saved.size(), port_reach.size()):
			port_reach [i] = float(saved [i])
	stored_strands = int(d.get("strands", 0))
	stored_bricks = int(d.get("bricks", 0))


	stored_strands = clampi(stored_strands, 0,
		strand_capacity() + Cfg.WAD_MAX_STRANDS)
	stored_bricks = clampi(stored_bricks, 0, brick_capacity())


	brick_hay = PackedInt32Array()
	for n: Variant in d.get("brick_hay", []):
		brick_hay.append(int(n))
	brick_worth = PackedFloat32Array()
	for n: Variant in d.get("brick_worth", []):
		brick_worth.append(float(n))
	_sync_brick_worth()
	while brick_hay.size() > stored_bricks:
		brick_hay.remove_at(0)
		brick_worth.remove_at(0)
	pending_needles = PackedInt32Array()
	for n: Variant in d.get("needles", []):
		pending_needles.append(int(n))
