class_name BeltGhost
extends Node3D


const RAIL_L:= 1
const RAIL_R:= 2
const LEG:= 3
const FOOT:= 4
const TAIL:= 5
const HEAD:= 6


var _parts: Array [MultiMeshInstance3D] = []


var drawn_length:= 0.0


func _init(capacity:= 24) -> void:

	name = "GhostBelt"
	top_level = true
	var meshes: Array [Mesh] = [ConveyorKit.segment_mesh(), ConveyorKit.rail_mesh(-1),
		ConveyorKit.rail_mesh(1), ConveyorKit.leg_mesh(), ConveyorKit.foot_mesh(),
		ConveyorKit.nose_mesh(false), ConveyorKit.nose_mesh(true)]
	var names:= ["Sections", "RailL", "RailR", "Legs", "Feet", "TailDrums", "HeadDrums"]
	for i in meshes.size():
		var mm:= MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes [i]
		mm.instance_count = capacity
		mm.visible_instance_count = 0
		var mmi:= MultiMeshInstance3D.new()
		mmi.name = names [i]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_parts.append(mmi)


func show_belt(runs: Array, overlap: float, supports: Array = [],
		windows: Array = [], drums: Array = []) -> void:
	global_transform = Transform3D()
	var deck: Array [Transform3D] = []
	var rail_l: Array [Transform3D] = []
	var rail_r: Array [Transform3D] = []
	drawn_length = 0.0
	for i in runs.size():
		var run: PackedVector3Array = runs [i]
		for k in run.size() - 1:
			drawn_length += run [k].distance_to(run [k + 1])
		var open: Array [Dictionary] = []
		if i < windows.size():
			open.assign(windows [i])
		lay(runs [i], overlap, deck, rail_l, rail_r, open)
	_fill(0, deck)
	_fill(1, rail_l)
	_fill(2, rail_r)
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []
	if supports.size() == 2:
		legs.assign(supports [0])
		feet.assign(supports [1])
	_fill(LEG, legs)
	_fill(FOOT, feet)
	var tails: Array [Transform3D] = []
	var heads: Array [Transform3D] = []
	for e: Array in drums:
		(heads if bool(e [0]) else tails).append(Transform3D(e [2] as Basis, e [1] as Vector3))
	_fill(TAIL, tails)
	_fill(HEAD, heads)


func set_material(material: Material) -> void:
	for part in _parts:
		part.material_override = material


func material() -> Material:
	return _parts [0].material_override


func drawn(part: int) -> int:
	return _parts [part].multimesh.visible_instance_count


static func lay(points: PackedVector3Array, overlap: float, deck: Array [Transform3D],
		rail_l: Array [Transform3D], rail_r: Array [Transform3D],
		open: Array [Dictionary] = []) -> void:
	var cum:= 0.0
	for i in points.size() - 1:
		var dir:= points [i + 1] - points [i]
		var nominal:= dir.length()
		if nominal < 0.0001:
			continue
		dir /= nominal
		var p0: Vector3 = points [i] - dir * overlap
		var p1: Vector3 = points [i + 1] + dir * overlap
		var span_len:= p0.distance_to(p1)
		var basis:= BeltPath.run_basis(p0, p1)
		var n:= maxi(1, int(round(span_len / Cfg.BELT_SEGMENT)))
		var scale:= Vector3(1.0, 1.0, span_len / float(n) / Cfg.BELT_SEGMENT)
		for k in n:
			deck.append(Transform3D(basis.scaled_local(scale),
				p0.lerp(p1, (k + 0.5) / float(n))))
		var s_lo:= cum - overlap
		BeltPath.tile_rail(rail_l, open, -1, basis, p0, dir, s_lo, span_len)
		BeltPath.tile_rail(rail_r, open, 1, basis, p0, dir, s_lo, span_len)
		cum += nominal


func _fill(part: int, xforms: Array [Transform3D]) -> void:
	var mm:= _parts [part].multimesh
	var n:= mini(xforms.size(), mm.instance_count)
	for i in n:
		mm.set_instance_transform(i, xforms [i])
	mm.visible_instance_count = n
