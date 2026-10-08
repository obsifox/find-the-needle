class_name PileSettle
extends RefCounted


const RELAX_CURRENT:= 1
const RELAX_NEXT:= 2

var nv:= 0
var heights:= PackedFloat32Array()
var dome:= PackedFloat32Array()
var active_list:= PackedInt32Array()
var active_head:= 0
var next_active:= PackedInt32Array()
var active_mark:= PackedByteArray()
var writing_next:= false
var preparing_dome:= false
var settling_restored:= false


var repose_step:= 0.0
var dome_prep_step:= 0.0
var reseed_margin:= 0.0
var play_rate:= 0.0
var prep_rate:= 0.0
var spill_chance:= 0.0
var want_spill:= false
var cell:= 0.0
var extent:= 0.0
var rng:= RandomNumberGenerator.new()


var touched:= PackedInt32Array()
var spill:= PackedVector3Array()
var last_visits:= 0

var last_usec:= 0


func count() -> int:
	return maxi(0, active_list.size() - active_head) + next_active.size()


func clear() -> void:
	active_list = PackedInt32Array()
	active_head = 0
	next_active = PackedInt32Array()
	active_mark.fill(0)
	writing_next = false


func seed_uphill(i: int, j: int) -> void:
	if i < 0 or j < 0 or i >= nv or j >= nv:
		return
	var h:= heights [j * nv + i]
	var idx:= j * nv + i
	for n in 4:
		var ni:= i + (1 if n == 0 else (-1 if n == 1 else 0))
		var nj:= j + (1 if n == 2 else (-1 if n == 3 else 0))
		if ni < 0 or nj < 0 or ni >= nv or nj >= nv:
			continue
		var nidx:= nj * nv + ni
		var mark:= active_mark [nidx]
		if (mark & RELAX_CURRENT) != 0 or (writing_next and (mark & RELAX_NEXT) != 0):
			continue
		var wake:= step_limit(nidx, idx) + reseed_margin
		if heights [nidx] - h > wake:
			seed_relax(ni, nj)


func seed_if_unstable(i: int, j: int) -> void:
	if i < 0 or j < 0 or i >= nv or j >= nv:
		return
	var idx:= j * nv + i
	var mark:= active_mark [idx]
	if (mark & RELAX_CURRENT) != 0 or (writing_next and (mark & RELAX_NEXT) != 0):
		return
	var h:= heights [idx]
	if h <= 0.0:
		return
	for n in 4:
		var ni:= i + (1 if n == 0 else (-1 if n == 1 else 0))
		var nj:= j + (1 if n == 2 else (-1 if n == 3 else 0))
		if ni < 0 or nj < 0 or ni >= nv or nj >= nv:
			continue
		var nidx:= nj * nv + ni
		var wake:= step_limit(idx, nidx) + reseed_margin
		if h - heights [nidx] > wake:
			seed_relax(i, j)
			return


func step_limit(high_idx: int, low_idx: int) -> float:
	if preparing_dome:
		return dome_prep_step
	if dome.size() != heights.size():
		return repose_step
	return maxf(repose_step, dome [high_idx] - dome [low_idx])


func seed_relax(i: int, j: int) -> void:
	if i < 0 or j < 0 or i >= nv or j >= nv:
		return
	var idx:= j * nv + i
	var mark:= active_mark [idx]
	if writing_next:
		if (mark & RELAX_CURRENT) != 0 or (mark & RELAX_NEXT) != 0:
			return
		active_mark [idx] = mark | RELAX_NEXT
		next_active.append(idx)
		return
	if (mark & RELAX_CURRENT) != 0:
		return
	active_mark [idx] = mark | RELAX_CURRENT
	active_list.append(idx)


func relax_once(visit_budget: int, deadline: int = 0) -> Dictionary:
	var out:= { "moved": false, "visits": 0, "complete": false }
	if visit_budget <= 0 or active_head >= active_list.size():
		return out
	var quiet:= preparing_dome or settling_restored
	var rate: float = prep_rate if quiet else play_rate
	var moved:= false
	var visits:= 0
	var marked: Dictionary = { }

	writing_next = true
	while active_head < active_list.size() and visits < visit_budget:
		if deadline > 0 and visits % 8 == 0 and Time.get_ticks_usec() >= deadline:
			break
		var idx:= active_list [active_head]
		active_head += 1
		visits += 1
		active_mark [idx] &= ~ RELAX_CURRENT
		var i:= idx % nv
		var j:= idx / nv
		var h:= heights [idx]
		if h <= 0.0:
			continue
		var changed:= false
		for n in 4:
			var ni:= i + (1 if n == 0 else (-1 if n == 1 else 0))
			var nj:= j + (1 if n == 2 else (-1 if n == 3 else 0))
			if ni < 0 or nj < 0 or ni >= nv or nj >= nv:
				continue
			var nidx:= nj * nv + ni
			var dh:= h - heights [nidx]
			var max_dh:= step_limit(idx, nidx)
			if dh <= max_dh:
				continue
			var move:= (dh - max_dh) * rate
			if move <= 0.0005:
				continue
			h -= move
			heights [idx] = h
			heights [nidx] += move
			moved = true
			changed = true
			seed_if_unstable(ni, nj)
			if not quiet:
				marked [nidx] = true
			if not quiet and want_spill and rng.randf() < spill_chance:
				spill.append(Vector3(- extent + i * cell, h + 0.05, - extent + j * cell))
		if changed:
			seed_if_unstable(i, j)
			seed_uphill(i, j)
			if not quiet:
				marked [idx] = true
	writing_next = false
	for idx: int in marked:
		touched.append(idx)

	if active_head >= active_list.size():
		promote()
		out ["complete"] = true
	out ["moved"] = moved
	out ["visits"] = visits
	return out


func promote() -> void:
	active_list = next_active
	active_head = 0
	next_active = PackedInt32Array()
	for idx in active_list:
		active_mark [idx] = (active_mark [idx] & ~ RELAX_NEXT) | RELAX_CURRENT


func settle_frame(max_visits: int, budget_usec: int, iterations: int) -> void:
	var started:= Time.get_ticks_usec()
	touched = PackedInt32Array()
	spill = PackedVector3Array()
	last_visits = 0
	var remaining:= max_visits
	var deadline:= started + budget_usec
	for _i in iterations:
		if remaining <= 0 or active_head >= active_list.size():
			break
		var result:= relax_once(remaining, deadline)
		var visits:= int(result ["visits"])
		last_visits += visits
		remaining -= visits

		if not bool(result ["complete"]):
			break
		if not bool(result ["moved"]) and active_list.is_empty():
			break
	last_usec = Time.get_ticks_usec() - started
