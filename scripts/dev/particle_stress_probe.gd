class_name DevParticleStressProbe
extends Node3D


const COPIES_PER_SOURCE:= 3
const RESTART_EVERY:= 20
const MIN_FRAMES:= 120

var world: Node3D
var player: Player

var _holder: Node3D
var _eye: Node3D
var _scoop: ScoopVfx
var _avalanche: AvalancheVfx
var _vac: VacVfx
var _emitters: Array [GPUParticles3D] = []
var _manual_points:= PackedVector3Array()


func run(requested_frames: int) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("particle stress needs a real rendering window")
		get_tree().quit(1)
		return

	var frames:= maxi(requested_frames, MIN_FRAMES)
	print("[particlestress] backend %s, adapter %s"
		% [RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name()])

	_holder = Node3D.new()
	_holder.name = "ParticleStressEffects"
	add_child(_holder)
	_eye = Node3D.new()
	_eye.position = Vector3(0.0, 3.0, 10.0)
	_holder.add_child(_eye)
	_make_camera()
	_make_standalone_effects()


	for _frame in 3:
		await get_tree().process_frame
	var sources:= _find_emitters()
	_make_stress_copies(sources)
	_emitters = _find_emitters()
	_restart_all()

	var names: Array [String] = []
	var capacity:= 0
	for p: GPUParticles3D in _emitters:
		capacity += p.amount
		if not p.name.begins_with("@") and not p.name.ends_with("StressCopy") and not names.has(p.name):
			names.append(p.name)
	names.sort()
	print("[particlestress] %d source emitters, %d active emitters, %d particle slots"
		% [sources.size(), _emitters.size(), capacity])
	print("[particlestress] systems: %s" % ", ".join(names))

	for frame in frames:
		_emit_manual_bursts(frame)
		if frame % RESTART_EVERY == 0:
			_restart_all()
		await get_tree().process_frame

	print("[particlestress] PASS, %d frames, %d emitters, %d particle slots"
		% [frames, _emitters.size(), capacity])
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for p: GPUParticles3D in _emitters:
		if is_instance_valid(p):
			p.emitting = false
			p.queue_free()
	_vac.stop()
	sources.clear()
	_emitters.clear()
	_holder.queue_free()
	_scoop = null
	_avalanche = null
	_vac = null
	_eye = null
	_holder = null
	for _frame in 10:
		await get_tree().process_frame
	print("[particlestress] cleanup left %d GPU emitters" % _find_emitters().size())


func _make_camera() -> void:
	var cam:= Camera3D.new()
	cam.name = "ParticleStressCamera"
	cam.fov = 78.0
	cam.near = 0.05
	cam.far = 180.0
	_holder.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 5.0, 16.0), Vector3(0.0, 2.0, 0.0),
		Vector3.UP)
	cam.current = true


func _make_standalone_effects() -> void:
	var builds:= world.get("builds") as BuildManager
	if builds != null:
		builds.add_pelletizer(Vector3(-7.0, 0.0, 26.0), 0.0)
		builds.add_generator(Vector3(0.0, 0.0, 26.0), 0.0)
		builds.add_cabinet(Vector3(7.0, 0.0, 26.0), 0.0)

	_scoop = ScoopVfx.new()
	_scoop.name = "StressScoop"
	_holder.add_child(_scoop)

	_avalanche = AvalancheVfx.new()
	_avalanche.name = "StressAvalanche"
	_holder.add_child(_avalanche)
	for z in 8:
		for x in 8:
			var px:= -2.8 + float(x) * 0.8
			var pz:= -2.8 + float(z) * 0.8
			_manual_points.append(Vector3(px, world.field.height_at(px, pz), pz))

	_vac = VacVfx.new()
	_vac.name = "StressVac"
	_holder.add_child(_vac)
	_vac.set_intake(true, Vector3(-3.0, 1.0, 0.0), Vector3(-0.8, 1.8, 0.0))
	_vac.set_pour(true, Vector3(0.8, 1.8, 0.0), Vector3(1.0, -0.2, 0.0))

	var dust:= DustMotes.new()
	dust.name = "StressDust"
	_holder.add_child(dust)
	dust.set_wanted(true)

	var jet:= JetpackVfx.new()
	jet.name = "StressJetpack"
	_holder.add_child(jet)
	for p: GPUParticles3D in jet.flames:
		p.emitting = true
	jet.smoke.emitting = true

	var fire:= HayFire.new()
	fire.name = "StressFire"
	_holder.add_child(fire)
	fire.ignite(world.field, world.live, world.props, Vector3(2.5, 0.05, 1.5))

	for i in 6:
		var a:= TAU * float(i) / 6.0
		var at:= Vector3(cos(a) * 3.0, 0.1, sin(a) * 3.0)
		var confetti:= PileClearedVfx.new()
		confetti.name = "StressConfetti%d" % i
		confetti.position = at
		_holder.add_child(confetti)
		confetti.play(2.5)
		ShredBurst.play(at + Vector3.UP, Basis.IDENTITY, Vector3(0.5, 0.4, 0.8),
			_holder)
		DiscoveryFlight.spawn(_holder, i, at + Vector3.UP,
			Vector3(- at.x, 3.0, - at.z), Color.from_hsv(float(i) / 6.0, 0.65, 1.0))
		_make_build_effect(i, at + Vector3(0.0, 0.4, 0.0))


func _make_build_effect(index: int, at: Vector3) -> void:
	var box:= MeshInstance3D.new()
	box.name = "StressBuildTarget%d" % index
	var mesh:= BoxMesh.new()
	mesh.size = Vector3(0.7, 0.8 + float(index) * 0.12, 0.7)
	box.mesh = mesh
	box.position = at
	_holder.add_child(box)
	BuildFx.build(_holder, [box], _eye)


func _find_emitters() -> Array [GPUParticles3D]:
	var out: Array [GPUParticles3D] = []
	for node: Node in get_tree().root.find_children("*", "GPUParticles3D", true, false):
		var p:= node as GPUParticles3D
		if p != null and p.process_material != null and p.draw_pass_1 != null:
			out.append(p)
	return out


func _make_stress_copies(sources: Array [GPUParticles3D]) -> void:
	var copy_index:= 0
	for source: GPUParticles3D in sources:
		for _copy in COPIES_PER_SOURCE:
			var p:= GPUParticles3D.new()
			p.name = "%sStressCopy" % source.name
			p.amount = source.amount
			p.lifetime = maxf(source.lifetime, 0.1)
			p.fixed_fps = source.fixed_fps
			p.randomness = source.randomness
			p.explosiveness = source.explosiveness
			p.local_coords = true
			p.one_shot = false
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.visibility_aabb = AABB(Vector3(-8.0, -8.0, -8.0), Vector3(16.0, 16.0, 16.0))
			p.process_material = source.process_material.duplicate(true) as Material
			p.draw_pass_1 = source.draw_pass_1.duplicate(true) as Mesh
			var column:= copy_index % 12
			var row:= copy_index / 12
			p.position = Vector3(-5.5 + float(column), 0.8 + float(row) * 0.65, 0.0)
			_holder.add_child(p)
			p.emitting = true
			copy_index += 1


func _emit_manual_bursts(frame: int) -> void:
	if frame % 4 == 0:
		_scoop.burst(Vector3(-1.0, 1.2, 0.0), Vector3(0.4, 0.8, 0.2), 1.0)
		_scoop.bite(Vector3(1.0, 0.8, 0.0), 0.65, 1.0)
		_avalanche.emit_spill(_manual_points, world.field)
	_vac.set_intake(true, Vector3(-3.0, 1.0, 0.0), Vector3(-0.8, 1.8, 0.0))
	_vac.set_pour(true, Vector3(0.8, 1.8, 0.0), Vector3(1.0, -0.2, 0.0))


func _restart_all() -> void:
	for p: GPUParticles3D in _emitters:
		if not is_instance_valid(p) or not p.is_inside_tree():
			continue
		p.amount_ratio = 1.0
		p.restart()
		p.emitting = true
