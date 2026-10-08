class_name DevYardReference
extends Node


const GEO_PATH:= "res://scenes/dev/yard_reference_geo.scn"


const PARTS:= ["Warehouse", "BayDoor"]

var world: Node3D
var warehouse: Warehouse


func run() -> void:
	if world != null:
		world.block_save = true

	var top:= TechTree.max_rank("yard_space")
	Tech.grant("yard_space", top)
	await get_tree().process_frame
	print("[yardref] yard_space at rank %d, shed half-width %.2f m"
		% [top, warehouse.inner if warehouse != null else -1.0])
	_save()
	Tech.reset()
	get_tree().quit()


func _is_junk(n: Node) -> bool:
	return n is CollisionObject3D or n is CollisionShape3D or n is OccluderInstance3D or n is AudioStreamPlayer3D or n is Camera3D or n is Light3D or n is WorldEnvironment or n is FogVolume or n is GPUParticles3D or n is CPUParticles3D


func _copy_visuals(src: Node, into: Node3D, owner_of: Node3D) -> void:
	for child in src.get_children():
		if _is_junk(child):
			continue
		if child is MeshInstance3D or child is MultiMeshInstance3D:
			var leaf:= (child as Node3D).duplicate(0) as Node3D
			for grand in leaf.get_children():
				grand.free()
			into.add_child(leaf)
			leaf.owner = owner_of
			continue
		if child is Node3D:
			var group:= Node3D.new()
			group.name = child.name
			group.transform = (child as Node3D).transform
			group.visible = (child as Node3D).visible
			into.add_child(group)
			group.owner = owner_of
			_copy_visuals(child, group, owner_of)
			if group.get_child_count() == 0:
				group.free()


func _save() -> void:
	var root:= Node3D.new()
	root.name = "YardReferenceGeo"
	for part: String in PARTS:
		var src:= world.get_node_or_null(NodePath(part))
		if src == null:
			push_warning("yardref: the world has no %s in it" % part)
			continue
		var group:= Node3D.new()
		group.name = part


		if src is Node3D:
			group.transform = (src as Node3D).global_transform
		root.add_child(group)
		group.owner = root
		_copy_visuals(src, group, root)

	var packed:= PackedScene.new()
	packed.pack(root)
	var err:= ResourceSaver.save(packed, GEO_PATH)
	print("[yardref] %s  %s" % [GEO_PATH, error_string(err)])


	for group in root.get_children():
		print("   %-12s %4d nodes, %3d drawn" % [group.name, _count(group),
			_count_drawn(group)])
	root.free()


func _count(n: Node) -> int:
	var total:= 1
	for c in n.get_children():
		total += _count(c)
	return total


func _count_drawn(n: Node) -> int:
	var total:= 1 if n is GeometryInstance3D else 0
	for c in n.get_children():
		total += _count_drawn(c)
	return total
