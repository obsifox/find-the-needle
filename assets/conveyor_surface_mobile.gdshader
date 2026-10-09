shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The mobile twin of conveyor_surface.gdshader -- SAME UNIFORMS, minimal
// fragment.
//
// Why this file exists. The 71-74% loading crash on the user's phone
// (Mali-G615 MC6, Vulkan 1.3.247) survived the staged-build fix of v2.1.0,
// and the breadcrumb finally named the step: standbuild:belt. The belt's
// first draw is the first time in the whole load that the conveyor
// pipeline is compiled, and the full shader's fragment does three things
// a weak mobile compiler can get wrong: a derivative (fwidth) inside a
// conditional block, a very high frequency pow(abs(sin()), vec2) tread
// pattern, and a hand-rolled normal built from central differences of
// both. None of that is load-bearing for how the game plays, so on
// phones the belt draws with THIS shader instead:
//
//   kept -- the four scans, the tint/saturation pull, the roughness
//   remap, the metallic term, the AO, the normal map, and the UV scroll
//   (TIME * speed in vertex, exactly as the desktop shader does it, so
//   the belt still visibly runs).
//
//   dropped -- the modelled cleat relief, the 80/m tread embossing, the
//   wear gradient and the fwidth detail fade. At gameplay distance the
//   rubber reads the same; the lost relief was visible only up close.
//
// ConveyorKit._pbr() picks this file on touch-first devices and on any
// run recovering from a load-time crash. Every set_shader_parameter()
// call site keeps working unchanged, because the uniform list is
// identical -- including the cleat ones, which are simply unused here.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float tex_per_metre = 2.0;
uniform vec3 tint = vec3(1.0, 1.0, 1.0);
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float rough_min : hint_range(0.0, 1.0) = 0.4;
uniform float rough_max : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_depth : hint_range(0.0, 4.0) = 1.0;

uniform float speed = 0.0;
uniform float cleat : hint_range(0.0, 1.0) = 0.0;
uniform float cleat_pitch = 0.25;
uniform float cleat_width = 0.024;
uniform float cleat_shoulder = 0.011;
uniform float cleat_height = 0.004;

varying vec2 v_uv;

void vertex() {
	v_uv = UV - vec2(0.0, TIME * speed);
}

void fragment() {
	vec2 uv = v_uv * tex_per_metre;

	vec3 base = texture(albedo_tex, uv).rgb;
	base = mix(vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))), base, saturation);

	ALBEDO = base * tint;
	ROUGHNESS = mix(rough_min, rough_max, texture(rough_tex, uv).r);
	METALLIC = metallic;
	SPECULAR = 0.35;
	AO = texture(ao_tex, uv).r;
	AO_LIGHT_AFFECT = 0.6;

	vec3 rn = texture(normal_tex, uv).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3(rn.xy * normal_depth, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
