class_name DevGfxReset
extends Node


var world: Node3D


const SETTLE:= 20


func run() -> void:
	for _i in SETTLE:
		await get_tree().process_frame

	var want:= _first_launch()
	print("[gfxreset] quality %s, %d keys" % [
		Cfg.PRESETS [Cfg.quality] ["name"], want.size()])


	for key: String in Cfg.gfx:
		var moved: Variant = _moved(key, Cfg.gfx [key])
		Cfg.gfx [key] = moved
		Cfg._gfx_user [key] = moved
	world._apply_render_settings()
	var env:= (world.get_node("Environment") as WorldEnvironment).environment
	print("[gfxreset] after fiddling: tonemap %d, exposure %.2f, white %.2f"
		% [int(env.tonemap_mode), env.tonemap_exposure, env.tonemap_white])


	Cfg.sync_gfx_to_preset(false)

	var bad:= 0
	for key: String in want:
		var got: Variant = Cfg.gfx.get(key)
		if _same(got, want [key]):
			continue
		bad += 1
		print("  FAIL  %-18s reset to %s, first launch has %s"
			% [key, got, want [key]])
	if not Cfg._gfx_user.is_empty():
		bad += 1
		print("  FAIL  %d hand-set switches survived the reset"
			% Cfg._gfx_user.size())
	if bad == 0:
		print("[gfxreset] PASS: all %d keys back to the shipped values"
			% want.size())
	else:
		print("[gfxreset] FAIL: %d keys" % bad)
	get_tree().quit(0 if bad == 0 else 1)


func _first_launch() -> Dictionary:
	var out:= { }
	var p: Dictionary = Cfg.PRESETS [Cfg.quality]
	for key: String in Cfg.GFX_FROM_PRESET:
		out [key] = p [Cfg.GFX_FROM_PRESET [key]]
	for key: String in Cfg.GFX_EXTRA:
		out [key] = Cfg.GFX_EXTRA [key]


	var e:= ResourceLoader.load(Cfg.LOOK_ENV_PATH, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Environment
	if e == null:
		push_warning("[gfxreset] no look resource, checking the fallbacks only")
		return out
	out ["fog"] = e.fog_enabled
	out ["glow_intensity"] = e.glow_intensity
	out ["adjustment"] = e.adjustment_enabled
	out ["color_correction"] = e.adjustment_color_correction != null
	out ["tonemap"] = int(e.tonemap_mode)
	out ["exposure"] = e.tonemap_exposure
	out ["white"] = e.tonemap_white
	out ["ambient_sky"] = e.ambient_light_source == Environment.AMBIENT_SOURCE_SKY
	out ["sky_contribution"] = e.ambient_light_sky_contribution
	out ["reflect_sky"] = e.reflected_light_source == Environment.REFLECTION_SOURCE_SKY
	return out


func _moved(key: String, v: Variant) -> Variant:
	match key:
		"tonemap":
			return (int(v) + 1) % Cfg.TONEMAP_NAMES.size()
		"msaa":
			return (int(v) + 1) % Cfg.MSAA_NAMES.size()
		"shadow_quality":
			return (int(v) + 1) % Cfg.SHADOW_QUALITY_NAMES.size()
		"texture_res":
			return (int(v) + 1) % Cfg.TEXTURE_RES_NAMES.size()
	if typeof(v) == TYPE_BOOL:
		return not bool(v)
	if typeof(v) == TYPE_INT:
		return int(v) + 1
	return float(v) + 0.1


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	return a == b
