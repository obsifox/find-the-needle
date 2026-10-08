class_name BeltFlipVfx
extends Node3D


const PITCH:= BuildTool.ARROW_PITCH

const LIFT:= BuildTool.ARROW_LIFT


const FADE:= BuildTool.ARROW_FADE

const CAPACITY:= 40


const WAVE_SPEED:= 14.0

const WAVE_WIDTH:= 1.1

const WAVE_GAIN:= 2.2


const WHIP:= 3.0


const IDLE_ALPHA:= 0.5

const HOLD_ALPHA:= 1.0


const HOLD_TINT:= Color(1.0, 0.72, 0.24)


var player: Player

var _mm: MultiMeshInstance3D

var _run: Conveyor


var _phase:= 0.0

var _wave:= 0.0

var _wave_span:= 0.0


var _turns:= -1


func _ready() -> void:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D


	mm.use_colors = true
	mm.mesh = ConveyorKit.flow_arrow_mesh()
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance3D.new()
	_mm.name = "Chevrons"
	_mm.multimesh = mm


	_mm.top_level = true
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.material_override = ConveyorKit.flow_material()
	_mm.visible = false
	add_child(_mm)
	set_process(true)


func _process(delta: float) -> void:
	var tool:= _tool()
	if tool == null:
		_stop()
		return
	var target:= tool.reverse_target()
	var progress:= tool.reverse_progress()


	if target != null and target != _run:
		_run = target


		_phase = 0.0
		_wave = 0.0
	_notice_flip(tool)
	if _wave > 0.0:
		_wave = maxf(0.0, _wave - delta)
	if _run != null and not is_instance_valid(_run):
		_run = null
	if _run == null or (target == null and _wave <= 0.0):
		_stop()
		return
	_phase += delta * _scroll_speed(progress)
	_draw(progress)


func arrow_speed() -> float:
	var tool:= _tool()
	return _scroll_speed(tool.reverse_progress() if tool != null else -1.0)


func _scroll_speed(progress: float) -> float:
	var belt:= Tech.belt_speed()
	if _wave > 0.0 and _wave_span > 0.0:


		return belt * lerpf(1.0, WHIP, _wave / _wave_span)
	if progress < 0.0:
		return belt


	var left:= 1.0 - clampf(progress, 0.0, 1.0)
	return belt * left * left


func _notice_flip(tool: BuildTool) -> void:
	var turns: int = tool.reversed
	if _turns >= 0 and turns > _turns and _run != null and tool.last_reversed == _run:
		_wave_span = maxf(_run.length, 0.5) / WAVE_SPEED
		_wave = _wave_span
	_turns = turns


func _draw(progress: float) -> void:
	var from:= _run.laid_start()
	var to:= _run.laid_end()
	var total:= from.distance_to(to)
	if total < 0.001:
		_stop()
		return
	var basis:= BeltPath.run_basis(from, to)
	var up:= basis.y
	var travel:= basis.z


	var n:= clampi(maxi(1, int(round(total / PITCH))), 1, CAPACITY)
	var pitch:= total / n
	var phase:= fmod(_phase, pitch)


	var crest:= -1.0
	if _wave > 0.0:
		crest = (1.0 - _wave / maxf(_wave_span, 1e-06)) * total
	var lit:= clampf(progress, 0.0, 1.0) if progress >= 0.0 else 0.0
	var alpha:= lerpf(IDLE_ALPHA, HOLD_ALPHA, lit)
	var tint:= Color.WHITE.lerp(HOLD_TINT, lit)
	var mm:= _mm.multimesh
	for i in n:
		var along:= fmod(i * pitch + phase, total)
		mm.set_instance_transform(i,
			Transform3D(basis, from + travel * along + up * LIFT))
		var fade:= (clampf(along / FADE, 0.0, 1.0)
			* clampf((total - along) / FADE, 0.0, 1.0))
		var gain:= 1.0
		if crest >= 0.0:
			var off:= (along - crest) / WAVE_WIDTH
			gain += WAVE_GAIN * exp(- off * off)
		mm.set_instance_color(i, Color(tint.r * gain, tint.g * gain,
			tint.b * gain, alpha * fade))
	mm.visible_instance_count = n
	_mm.visible = true


func _stop() -> void:
	if _mm == null:
		return
	_mm.multimesh.visible_instance_count = 0
	_mm.visible = false


func showing() -> bool:
	return _mm != null and _mm.visible


func travel() -> Vector3:
	if _run == null or not is_instance_valid(_run) or not showing():
		return Vector3.ZERO
	return _run.forward


func _tool() -> BuildTool:
	if player == null or not is_instance_valid(player):
		return null
	return player.build
