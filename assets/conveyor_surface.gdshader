shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Every surface of a conveyor: belt rubber, painted frame steel, bare roller.
//
// One shader for all three for two reasons.
//
// The first is roughness. These are Poly Haven scans, and a scan's roughness map
// is a photograph of ONE surface, not a 0-to-1 curve waiting to be scaled --
// blue_metal_plate's sits between 0.19 and 0.63. StandardMaterial3D can only
// MULTIPLY that map, so it can only ever make the paint glossier, and painted
// machine steel comes out looking like wet plastic. `rough_min`/`rough_max`
// remap it instead, which is what lets a scan be used for its texture while its
// absolute gloss is stated here.
//
// The second is the belt's cleats, which have to MOVE. The deck is a static
// MultiMesh -- one 1 m section instanced along the run -- so cleats modelled as
// geometry would sit still while the belt they belong to ran. Drawn as a
// function of TIME they scroll properly, and a bare belt is visibly running.
// Set `cleat` to 0 and the whole cleat term folds away, which is how the frame
// and the roller use this same shader.
//
// UVs arrive in METRES (see assets/blender/_build/conveyor.py), so every length
// below is a real measurement and `tex_per_metre` is literal. Their mirror is
// ConveyorKit, which builds all three materials from these uniforms.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

// Whole number, and not negotiable for anything running the length of the belt:
// V restarts at every 1 m section join, so a tiling that does not fit a whole
// number of times into one metre lays a seam across the run every metre.
uniform float tex_per_metre = 2.0;
// Deliberately NOT hinted source_color. A source_color uniform is converted
// from sRGB on the way in, which is right for a colour someone picked and wrong
// for this: the tint is a multiplier applied to an already-linear scan, and the
// same numbers appear in the Blender build script. Hinting it would silently
// darken every surface here to roughly a quarter of what the .blend shows.
uniform vec3 tint = vec3(1.0, 1.0, 1.0);
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float rough_min : hint_range(0.0, 1.0) = 0.4;
uniform float rough_max : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_depth : hint_range(0.0, 4.0) = 1.0;

uniform float speed = 0.0;          // Cfg.BELT_SPEED on the rubber, 0 elsewhere
uniform float cleat : hint_range(0.0, 1.0) = 0.0;
uniform float cleat_pitch = 0.25;   // must divide Cfg.BELT_SEGMENT exactly
uniform float cleat_width = 0.024;  // metres across the top of the bar
uniform float cleat_shoulder = 0.011;
uniform float cleat_height = 0.004; // metres proud of the belt

varying vec2 v_uv;

// Height of the cleat bar at `y` metres along the run: flat belt, a sloped
// shoulder up, a flat top, a shoulder back down, once per pitch.
float cleat_h(float y) {
	float x = fract(y / cleat_pitch) * cleat_pitch;
	return smoothstep(0.0, cleat_shoulder, x)
		- smoothstep(cleat_width - cleat_shoulder, cleat_width, x);
}

// Eighty embossed squares per metre, matching the approved Blender surface.
// Integer repeats keep both axes continuous at the section boundaries.
float tread_h(vec2 p) {
	vec2 grain = pow(abs(sin(p * 251.327412)), vec2(0.55));
	return grain.x * grain.y;
}

void vertex() {
	// Scrolled here, not in fragment, so the ridge and its shading and its wear
	// are guaranteed to be the same bar.
	//
	// MINUS, and it is not arbitrary. Measured off the exported mesh: V runs
	// dv/dz = +1.00 across the carrying strand, because the model is built along
	// Blender's +Y and the glTF conversion both maps that to Godot's -Z and
	// flips V, and the two cancel. Subtracting therefore walks the cleats toward
	// +Z, which is the direction BeltPath drives the load. Adding runs them
	// backwards under hay that is going forwards.
	//
	// The return strand measures dv/dz = -1.00 -- it is modelled with its V
	// flipped -- so this one expression runs the underside the other way for
	// free, which is what a real belt looping back does.
	v_uv = UV - vec2(0.0, TIME * speed);
}

void fragment() {
	vec2 uv = v_uv * tex_per_metre;

	vec3 base = texture(albedo_tex, uv).rgb;
	// The belt's scan is a brick-red running track, chosen for its grain and its
	// wear and not for its colour, so the colour comes back out here. Done in
	// the shader rather than by baking a grey copy, which would put a second
	// near-identical texture set on disk.
	base = mix(vec3(dot(base, vec3(0.2126, 0.7152, 0.0722))), base, saturation);

	// Scuffed on top where the load rides over it, dirty down at the root.
	float top = cleat_h(v_uv.y);
	ALBEDO = base * tint * mix(1.0, mix(0.86, 1.08, top), cleat);
	ROUGHNESS = mix(rough_min, rough_max, texture(rough_tex, uv).r)
		- top * 0.10 * cleat;
	METALLIC = metallic;
	SPECULAR = 0.35;
	AO = texture(ao_tex, uv).r;
	AO_LIGHT_AFFECT = 0.6;

	// Central difference across the profile: the shoulders are the only part of
	// a cleat that catches light differently from flat belt, and their SLOPE is
	// the whole effect.
	float e = cleat_shoulder * 0.5;
	float slope = (cleat_h(v_uv.y + e) - cleat_h(v_uv.y - e)) / (2.0 * e);

	vec3 rn = texture(normal_tex, uv).rgb * 2.0 - 1.0;
	// Tangent space here is (U across the belt, V along the run, up). A cleat
	// only ever tilts along the run, so it perturbs V alone.
	vec3 n = normalize(vec3(rn.xy * normal_depth
		+ vec2(0.0, -slope * cleat_height * cleat), 1.0));
	if (cleat > 0.0) {
		// Fade the small relief before its cells become smaller than a pixel.
		// The larger ribs remain readable farther down the conveyor.
		vec2 footprint = fwidth(v_uv);
		float detail = 1.0 - smoothstep(0.003, 0.0125,
			max(footprint.x, footprint.y));
		float step_uv = 0.0006;
		vec2 tread_slope = vec2(
			tread_h(v_uv + vec2(step_uv, 0.0)) - tread_h(v_uv - vec2(step_uv, 0.0)),
			tread_h(v_uv + vec2(0.0, step_uv)) - tread_h(v_uv - vec2(0.0, step_uv)))
			/ (2.0 * step_uv);
		float wear = pow(max(cos(v_uv.x * 3.14159265 / 0.84), 0.0), 3.0);
		// The scan supplies restrained variation beneath the manufactured tread.
		// These are linear reflectances, like the approved Blender node values.
		float grain = texture(rough_tex, uv).r;
		float rubber = (0.022 + grain * 0.022 + wear * 0.017) * 0.33;
		ALBEDO = vec3(rubber * (1.0 - top * 0.35));
		ROUGHNESS = 0.76 - wear * 0.17;
		AO = mix(0.92, 1.0, texture(ao_tex, uv).r);
		n = normalize(vec3(rn.xy * 0.08 * detail
			- tread_slope * 0.00065 * 0.9 * detail
			+ vec2(0.0, -slope * cleat_height * 0.9), 1.0));
	}
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
