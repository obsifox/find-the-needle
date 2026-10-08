class_name DevFallenFillProbe
extends Node


const FLOOR_AT:= Vector3(13.0, 0.0, -4.0)
const BUCKET_AT:= Vector3(13.0, 0.0, 4.0)

const SCOOP:= 45
const SCOOPS:= 10

const SCOOP_GAP:= 30

const WATCH:= 300

var world: Node3D
var player: Player

var _rng:= RandomNumberGenerator.new()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	_rng.seed = 21
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(9.0, 0.4, 0.0)
	for i in 40:
		await get_tree().physics_frame
	var live: LiveStrandManager = world.live
	print("\n=== hay into a fallen bucket, pin %s ===" % ("on" if Carryable.pin_enabled else "OFF"))

	var floor_ms:= await _fill(live, FLOOR_AT + Vector3(0, 0.25, 0), Vector3.FORWARD, null)
	_report("bare floor", floor_ms, live)
	for b: RigidBody3D in live._active.duplicate():
		live._retire(b, false)
	for i in 60:
		await get_tree().physics_frame

	var props: PropManager = world.props
	var bucket:= props.spawn("bucket", Transform3D(Basis.IDENTITY,
		BUCKET_AT + Vector3(0, 0.05, 0))) as Bucket
	for i in 60:
		await get_tree().physics_frame

	bucket.tumble()
	bucket.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
		BUCKET_AT + Vector3(0, Bucket.R_RIM + 0.02, 0))
	for i in 120:
		await get_tree().physics_frame
	var mouth:= bucket.global_transform * Vector3(0, Bucket.RIM_Y * 0.5, 0)
	var out:= bucket.global_basis.y.normalized()
	print("  bucket on its side: up %.2f, planted and pinned %s, mouth at %s"
		% [bucket.global_basis.y.dot(Vector3.UP), bucket.is_pinned(), mouth])
	var bucket_ms:= await _fill(live, mouth + out * 0.35, - out, bucket)
	_report("fallen bucket", bucket_ms, live)
	print("  the bucket counted %d strands; up %.2f" % [bucket.stored,
		bucket.global_basis.y.dot(Vector3.UP)])
	print("[fallenfill] done")
	get_tree().quit(0)


func _fill(live: LiveStrandManager, from: Vector3, toward: Vector3,
		_bucket: Bucket) -> Array [float]:
	var ms: Array [float] = []
	var last:= Time.get_ticks_usec()
	for tick in SCOOPS * SCOOP_GAP + WATCH:
		if tick % SCOOP_GAP == 0 and tick < SCOOPS * SCOOP_GAP:
			for n in SCOOP:
				var p:= from + Vector3(_rng.randf_range(-0.08, 0.08),
					_rng.randf_range(-0.05, 0.08), _rng.randf_range(-0.08, 0.08))
				var v:= toward * _rng.randf_range(1.2, 2.2) + Vector3(_rng.randfn(0.0, 0.2), _rng.randf_range(0.0, 0.4), _rng.randfn(0.0, 0.2))
				live.spawn(p, StrandFactory.random_strand_basis(_rng), v,
					StrandFactory.random_tint(_rng))
		await get_tree().physics_frame
		var now:= Time.get_ticks_usec()
		ms.append((now - last) / 1000.0)
		last = now
	return ms


func _report(what: String, ms: Array [float], live: LiveStrandManager) -> void:
	var fill:= ms.slice(0, SCOOPS * SCOOP_GAP)
	var after:= ms.slice(SCOOPS * SCOOP_GAP)
	var awake:= 0
	for b: RigidBody3D in live._active:
		if not b.sleeping and not b.freeze:
			awake += 1
	print("  %s: %d live, %d still awake at the end" % [what, live.active_count(), awake])
	_spread("    shovelling", fill)
	_spread("    after", after)


func _spread(what: String, samples: Array) -> void:
	var sorted:= samples.duplicate()
	sorted.sort()
	var total:= 0.0
	for v: float in samples:
		total += v
	var k:= int(float(sorted.size() - 1) * 0.95)
	print("  %-14s %4d ticks   mean %6.2f ms   p95 %6.2f ms   worst %6.2f ms"
		% [what, sorted.size(), total / sorted.size(), sorted [k], sorted [-1]])
