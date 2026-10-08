shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, shadows_disabled,
	specular_disabled, unshaded, fog_disabled;
// One tongue of flame, drawn on a particle quad. HayGenerator hangs a dozen of
// these on the firebox door; before this the same quads were flat orange
// squares with a hard edge, and a stack of hard-edged squares blending
// additively reads as big pixels, not as a fire.
//
// Three things make it a flame rather than a sprite:
//
//   * the SHAPE is a soft disc, gone to nothing well inside the quad, so no
//     corner or edge of the card is ever visible whatever it overlaps;
//   * the alpha is EATEN by scrolling noise as the particle ages, so a tongue
//     thins and breaks up on its way out instead of shrinking as a square;
//   * the COLOUR is by heat: near white at the core, orange through the body,
//     deep red at the ragged tips, and the whole thing cools as it ages.
//
// The quad is billboarded here rather than by the material so the process
// material's random angle (INSTANCE_CUSTOM.x) can be spent on turning the
// noise rather than the card, which keeps every card square to the camera and
// every flame different. INSTANCE_CUSTOM.y is the particle's age 0..1 and
// INSTANCE_CUSTOM.z is the per particle random the process material writes
// when anim_offset is randomised; it seeds the noise so no two tongues match.

uniform vec3 core_colour : source_color = vec3(1.0, 0.86, 0.48);
uniform vec3 body_colour : source_color = vec3(1.0, 0.50, 0.12);
uniform vec3 tip_colour : source_color = vec3(0.80, 0.10, 0.01);
// Multiplies the output. Additive blend, so this is how far past white the
// overlaps go before the bloom takes them.
uniform float brightness : hint_range(0.2, 4.0) = 1.15;
// Noise cells across one card. Bigger is finer.
uniform float noise_scale : hint_range(1.0, 8.0) = 3.8;
// How fast the noise scrolls up through the card, in cards per second. The
// particle already rises; this is the flicker inside it.
uniform float rise_speed : hint_range(0.0, 4.0) = 1.6;
// How much of the disc the noise has eaten by the end of the particle's life.
uniform float erosion : hint_range(0.0, 1.0) = 0.72;
// Width of the band between nothing and full. Lower is crisper tongues.
uniform float softness : hint_range(0.02, 0.8) = 0.28;
// The card is drawn this much taller than wide.
uniform float stretch : hint_range(0.5, 2.5) = 1.35;

varying float age;
varying float seed;
varying float spin;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * vnoise(p);
		p = p * 2.03 + vec2(3.1, 1.7);
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	spin = INSTANCE_CUSTOM.x;
	age = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.z;
	// Face the camera, keep the particle's own scale, and throw its rotation
	// away: the card stays upright and the spin goes into the noise instead.
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
	mat4 sc = mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz) * stretch, 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb * sc;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV - 0.5;
	// Godot's quad UV runs down the card, so up is negative uv.y.
	float up = -uv.y;
	// A soft disc pinched hard at the top: wide where a tongue leaves the
	// fire, narrow where it is about to break up.
	float pinch = 1.0 + 0.9 * smoothstep(-0.2, 0.5, up);
	float d = length(vec2(uv.x * pinch, up * 0.85));
	float disc = 1.0 - smoothstep(0.0, 0.5, d);

	float c = cos(spin);
	float s = sin(spin);
	vec2 turned = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
	vec2 np = turned * noise_scale + vec2(seed * 23.0, seed * 11.0 + TIME * rise_speed);
	// Stretched away from its own average, for the smoke shader's reason: a
	// fractal sum piles up round 0.5 and cannot cut a ragged edge as it is.
	float n = clamp((fbm(np) - 0.5) * 2.4 + 0.5, 0.0, 1.0);
	float n2 = fbm(np * 1.9 + vec2(7.3, 2.9) - vec2(0.0, TIME * rise_speed * 0.6));

	// The disc carved by the noise from the first frame, eaten further as the
	// tongue ages, and eaten hardest at the top so it frays upward.
	float mask = disc * n * 1.7;
	float cut = mix(0.13, 0.13 + erosion, age)
		+ 0.35 * smoothstep(0.0, 0.5, up) * (0.3 + age);
	float a = smoothstep(cut, cut + softness, mask);
	a *= smoothstep(0.0, 0.10, age);
	a *= 1.0 - smoothstep(0.65, 1.0, age);
	a *= COLOR.a;

	// Heat is how far inside the cut a pixel sits, so the eroded edge is
	// always the cool red and the deep interior the pale core; the second
	// noise puts veins through the body so the middle is not one flat colour.
	float heat = smoothstep(cut, cut + 0.75, mask) * (1.0 - 0.55 * age)
		* (0.6 + 0.4 * n2);
	vec3 col = mix(tip_colour, body_colour, smoothstep(0.08, 0.45, heat));
	col = mix(col, core_colour, smoothstep(0.50, 0.95, heat));

	ALBEDO = col * brightness * a;
	ALPHA = a;
}
