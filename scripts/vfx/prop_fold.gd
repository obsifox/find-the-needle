class_name PropFold
extends Node3D


const SWELL:= 0.07
const SWELL_TO:= 1.08
const SHRINK:= 0.27


const TWIST:= deg_to_rad(24.0)


const MIN_SCALE:= 0.002

var _t:= 0.0
var _basis0: Basis


static func play(item: Carryable, parent: Node3D) -> PropFold:
	if item == null or not is_instance_valid(item):
		return null
	if parent == null or not parent.is_inside_tree():
		return null
	var model:= item.detach_model()
	if model == null:
		return null
	var fx:= PropFold.new()
	fx.name = "Fold"
	parent.add_child(fx)


	fx.global_transform = item.global_transform
	fx.add_child(model)


	fx._basis0 = fx.transform.basis
	return fx


func _process(delta: float) -> void:
	_t += delta
	if _t >= SWELL + SHRINK:
		queue_free()
		return
	var s:= SWELL_TO
	var k:= 0.0
	if _t < SWELL:
		s = lerpf(1.0, SWELL_TO, _t / SWELL)
	else:
		k = (_t - SWELL) / SHRINK


		s = SWELL_TO * (1.0 - k * k)


	transform.basis = _basis0.rotated(Vector3.UP, TWIST * k).scaled(Vector3.ONE * maxf(s, MIN_SCALE))
