class_name HayHold
extends RefCounted


const PULL_GAIN:= 12.0


const PULL_MAX:= 3.0


const SPIN_KEEP:= 0.35


const SETTLE_HEIGHT:= 0.07


static func gravity_on(rb: RigidBody3D) -> Vector3:
	var st:= PhysicsServer3D.body_get_direct_state(rb.get_rid())
	return st.total_gravity if st != null else Vector3.ZERO


static func carry_body(rb: RigidBody3D, moved: Transform3D, centre: Vector3,
		radius: float, delta: float, up: Vector3 = Vector3.UP) -> void:
	if delta <= 0.0 or not is_instance_valid(rb) or not rb.is_inside_tree():
		return
	var p:= rb.global_position
	var v:= (moved * p - p) / delta


	v -= gravity_on(rb) * delta
	var out:= p - centre
	var over:= out.length() - radius
	if over > 0.0:
		v -= out.normalized() * minf(over * PULL_GAIN, PULL_MAX)


	var height:= out.dot(up)
	if height > SETTLE_HEIGHT:
		var own:= rb.linear_velocity
		var down:= minf(own.dot(up), 0.0)


		v = v - up * v.dot(up) + up * down
	rb.linear_velocity = v
	rb.angular_velocity *= SPIN_KEEP


	rb.sleeping = false


	LiveStrandManager.hold(rb)
